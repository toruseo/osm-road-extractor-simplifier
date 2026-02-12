# coding: utf-8

import argparse
import copy
import gzip
import json
import os
import sys
from collections import defaultdict
from dataclasses import dataclass, field

import osmium

if sys.stdout.encoding and sys.stdout.encoding.lower().replace("-", "") != "utf8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


@dataclass
class RoadSegment:
    fclass: str       # "motorway", "trunk", "primary", "secondary"
    name: str         # 道路名（""=未設定）
    ref: str          # 路線番号（""=未設定）
    points: list = field(default_factory=list)  # [(lon, lat), ...]


TARGET_CLASSES = ["motorway", "trunk", "primary", "secondary"]


class RoadHandler(osmium.SimpleHandler):
    def __init__(self, target_classes):
        super().__init__()
        self.segments = []
        self._targets = set(target_classes)
        self._link_targets = {c + "_link" for c in target_classes}

    def way(self, w):
        highway = w.tags.get("highway", "")
        if highway in self._targets:
            fclass = highway
        elif highway in self._link_targets:
            fclass = highway[:-5]  # strip "_link"
        else:
            return

        try:
            points = [(n.lon, n.lat) for n in w.nodes]
        except osmium.InvalidLocationError:
            return

        if len(points) < 2:
            return

        self.segments.append(RoadSegment(
            fclass=fclass,
            name=w.tags.get("name", ""),
            ref=w.tags.get("ref", ""),
            points=points,
        ))


def read_pbf(path, target_classes):
    handler = RoadHandler(target_classes)
    handler.apply_file(path, locations=True, idx="flex_mem")
    return handler.segments


def interpolate_attributes(seg_i, seg_j):
    """隣接するセグメント間で name/ref を補完する。"""
    for src, dst in [(seg_i, seg_j), (seg_j, seg_i)]:
        if src.name != "" and src.name == dst.name:
            if dst.ref == "" and src.ref != "":
                dst.ref = src.ref
        if src.ref != "" and src.ref == dst.ref:
            if dst.name == "" and src.name != "":
                dst.name = src.name


def are_adjacent(seg_a, seg_b):
    """2つのセグメントの端点が接続しているか判定する。"""
    return (seg_a.points[-1] == seg_b.points[0] or
            seg_a.points[0] == seg_b.points[-1])


def combine_segments(segments, max_iter=3):
    for iteration in range(max_iter):
        print(f"iteration {iteration}")

        # 端点からセグメントインデックスへの辞書を構築（O(n)）
        start_map = defaultdict(set)  # (fclass, 始点座標) -> {index, ...}
        end_map = defaultdict(set)    # (fclass, 終点座標) -> {index, ...}
        for idx, seg in enumerate(segments):
            start_map[(seg.fclass, seg.points[0])].add(idx)
            end_map[(seg.fclass, seg.points[-1])].add(idx)

        new_segments = []
        removed = set()

        for i in range(len(segments)):
            if i in removed:
                continue

            seg = copy.copy(segments[i])
            seg.points = list(seg.points)

            # 端点辞書で隣接セグメントを探索し結合（結合後は端点が変わるので再探索）
            merged = True
            while merged:
                merged = False

                # 候補収集: seg の終点 == 候補の始点、または seg の始点 == 候補の終点
                candidates = set()
                for j in start_map.get((seg.fclass, seg.points[-1]), ()):
                    if j > i and j not in removed:
                        candidates.add(j)
                for j in end_map.get((seg.fclass, seg.points[0]), ()):
                    if j > i and j not in removed:
                        candidates.add(j)

                for j in sorted(candidates):
                    if j in removed:
                        continue
                    if not are_adjacent(seg, segments[j]):
                        continue

                    interpolate_attributes(seg, segments[j])

                    if seg.name == segments[j].name and seg.ref == segments[j].ref:
                        # 結合
                        if seg.points[-1] == segments[j].points[0]:
                            seg.points = seg.points + segments[j].points
                        else:
                            seg.points = segments[j].points + seg.points
                        print(f"combined {i} {j} {seg.fclass} {seg.ref} {seg.name}")
                        removed.add(j)
                        merged = True
                        break  # 端点が変わったので再探索

            new_segments.append(seg)

        print(f"{'#' * 80}\n{len(new_segments)}/{len(segments)}\n{'#' * 80}")
        if len(new_segments) == len(segments):
            break

        segments = new_segments

    return segments


def write_geojson(segments, output_dir):
    os.makedirs(output_dir, exist_ok=True)

    grouped = defaultdict(list)
    for seg in segments:
        grouped[seg.fclass].append(seg)

    written = []
    for fclass, segs in sorted(grouped.items()):
        features = []
        for seg in segs:
            features.append({
                "type": "Feature",
                "properties": {
                    "fclass": seg.fclass,
                    "name": seg.name,
                    "ref": seg.ref,
                },
                "geometry": {
                    "type": "LineString",
                    "coordinates": seg.points,
                },
            })

        geojson = {
            "type": "FeatureCollection",
            "features": features,
        }

        filename = f"osm_{fclass}.geojson"
        filepath = os.path.join(output_dir, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(geojson, f, ensure_ascii=False)

        gz_filepath = filepath + ".gz"
        with gzip.open(gz_filepath, "wt", encoding="utf-8") as f:
            json.dump(geojson, f, ensure_ascii=False)

        print(f"wrote {filepath} + .gz ({len(features)} features)")
        written.append(filepath)

    return written


def main():
	"""
	コマンドライン例：
	python .\osm_extract_simplify.py japan-260209.osm.pbf -o output -i 10
	"""
	
    parser = argparse.ArgumentParser(
        description="OSM PBF から主要道路を抽出・結合し GeoJSON で出力する")
    parser.add_argument("input", help="入力 .osm.pbf ファイル")
    parser.add_argument("-o", "--output", default=".", help="出力ディレクトリ (default: .)")
    parser.add_argument("-c", "--classes", nargs="+", default=TARGET_CLASSES,
                        help="対象道路種別 (default: motorway trunk primary secondary)")
    parser.add_argument("-i", "--max-iter", type=int, default=3,
                        help="結合イテレーション回数 (default: 3)")
    args = parser.parse_args()

    print("READING AND EXTRACTING...")
    segments = read_pbf(args.input, args.classes)
    print(f"extracted size: {len(segments)}")

    print("COMBINING...")
    segments = combine_segments(segments, max_iter=args.max_iter)

    print("WRITING...")
    write_geojson(segments, args.output)

    print("COMPLETED")


if __name__ == "__main__":
    main()
