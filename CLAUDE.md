# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

OSMの`.osm.pbf`ファイルから主要道路（motorway, trunk, primary, secondary）を抽出し、同名・同番号の隣接セグメントを結合して軽量なGeoJSONとして出力するCLIツール。ソースは`osm_extract_simplify.py`の単一ファイル構成。

## コマンド

```bash
# 依存パッケージインストール
pip install -r requirements.txt

# 基本実行
python osm_extract_simplify.py input.osm.pbf -o ./output

# 道路種別を指定して抽出
python osm_extract_simplify.py input.osm.pbf -o ./output -c primary secondary

# 結合イテレーション回数を変更（デフォルト: 3）
python osm_extract_simplify.py input.osm.pbf -o ./output -i 5
```

テストスイート・リンター・ビルドシステムは未整備。

## アーキテクチャ

単一ファイルのETLパイプライン（Extract → Transform → Load）:

1. **Extract** (`RoadHandler` / `read_pbf`): pyosmiumで`.osm.pbf`を読み、`highway`タグでフィルタ。`_link`サフィックスは親クラスに正規化。結果は`RoadSegment`データクラスのリスト。
2. **Transform** (`combine_segments`): 同一`fclass`・隣接・同一`name`/`ref`のセグメントを反復的にマージ。マージ前に`interpolate_attributes`で隣接セグメント間の欠損属性を補完。早期終了あり。
3. **Load** (`write_geojson`): 道路種別ごとにGeoJSON FeatureCollection（LineString）を出力。

### 重要な設計判断

- **隣接判定**（`are_adjacent`）は端点の完全一致のみ（距離閾値なし）
- **属性補完**（`interpolate_attributes`）は隣接チェック後に実行（103行目のバグ修正コメント参照）
- **結合方向**: `seg.points[-1] == other.points[0]`で末尾→先頭接続か先頭→末尾接続かを判定し、座標配列を連結
- Windows環境でのUTF-8出力を`sys.stdout.reconfigure`で対応

## 入出力フォーマット

- **入力**: OpenStreetMap PBF（Protocol Buffer Format）。Geofabrik等から取得
- **出力**: `osm_{fclass}.geojson`（FeatureCollection、プロパティ: fclass, name, ref）
- データファイル（`.osm.pbf`, `.geojson`）は`.gitignore`で除外済み
