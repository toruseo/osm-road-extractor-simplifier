#!/usr/bin/env julia
# OSM PBF から主要道路を抽出・結合し GeoJSON で出力する

using OpenStreetMapPBF
using JSON

# ─── データ構造 ───────────────────────────────────────────────

mutable struct RoadSegment
    fclass::String        # "motorway", "trunk", "primary", "secondary"
    name::String          # 道路名（""=未設定）
    ref::String           # 路線番号（""=未設定）
    points::Vector{Tuple{Float64,Float64}}  # [(lon, lat), ...]
end

const DEFAULT_CLASSES = ["motorway", "trunk", "primary", "secondary"]

# ─── PBF 読み込み（2パス） ────────────────────────────────────

struct RawWay
    fclass::String
    name::String
    ref::String
    node_ids::Vector{Int64}
end

function read_pbf(path::String, target_classes::Vector{String})
    targets = Set(target_classes)
    link_targets = Set(c * "_link" for c in target_classes)
    link_base = Dict(c * "_link" => c for c in target_classes)

    # Pass 1: Way を収集し、必要な node ID を集める
    raw_ways = RawWay[]
    needed_nodes = Set{Int64}()

    scan_ways(path) do way
        hw = get(way.tags, "highway", "")
        if hw in targets
            fclass = hw
        elseif hw in link_targets
            fclass = link_base[hw]
        else
            return
        end
        length(way.nodes) < 2 && return
        push!(raw_ways, RawWay(fclass,
                               get(way.tags, "name", ""),
                               get(way.tags, "ref", ""),
                               copy(way.nodes)))
        union!(needed_nodes, way.nodes)
    end

    # Pass 2: Node 座標を収集
    node_coords = Dict{Int64, Tuple{Float64,Float64}}()

    scan_nodes(path) do node
        if node.id in needed_nodes
            node_coords[node.id] = (node.lon, node.lat)
        end
    end

    # RoadSegment に変換
    segments = RoadSegment[]
    for rw in raw_ways
        pts = Tuple{Float64,Float64}[]
        valid = true
        for nid in rw.node_ids
            if haskey(node_coords, nid)
                push!(pts, node_coords[nid])
            else
                valid = false
                break
            end
        end
        if valid && length(pts) >= 2
            push!(segments, RoadSegment(rw.fclass, rw.name, rw.ref, pts))
        end
    end

    return segments
end

# ─── 属性補完 ─────────────────────────────────────────────────

function interpolate_attributes!(seg_i::RoadSegment, seg_j::RoadSegment)
    for (src, dst) in ((seg_i, seg_j), (seg_j, seg_i))
        if src.name != "" && src.name == dst.name
            if dst.ref == "" && src.ref != ""
                dst.ref = src.ref
            end
        end
        if src.ref != "" && src.ref == dst.ref
            if dst.name == "" && src.name != ""
                dst.name = src.name
            end
        end
    end
end

# ─── 隣接判定 ─────────────────────────────────────────────────

function are_adjacent(seg_a::RoadSegment, seg_b::RoadSegment)::Bool
    return seg_a.points[end] == seg_b.points[1] ||
           seg_a.points[1] == seg_b.points[end]
end

# ─── セグメント結合 ───────────────────────────────────────────

function combine_segments(segments::Vector{RoadSegment}, max_iter::Int=3)
    for iteration in 0:max_iter-1
        println("iteration $iteration")

        n = length(segments)
        removed = falses(n)
        new_segments = RoadSegment[]

        for i in 1:n
            removed[i] && continue

            seg = RoadSegment(segments[i].fclass, segments[i].name,
                              segments[i].ref, copy(segments[i].points))

            for j in i+1:n
                removed[j] && continue
                seg.fclass != segments[j].fclass && continue

                # 隣接チェック後に属性補完を実行
                are_adjacent(seg, segments[j]) || continue

                interpolate_attributes!(seg, segments[j])

                if seg.name == segments[j].name && seg.ref == segments[j].ref
                    # 結合（接続点の重複を除去）
                    if seg.points[end] == segments[j].points[1]
                        append!(seg.points, @view segments[j].points[2:end])
                    else
                        seg.points = vcat(segments[j].points, @view seg.points[2:end])
                    end
                    println("combined $i $j $(seg.fclass) $(seg.ref) $(seg.name)")
                    removed[j] = true
                end
            end

            push!(new_segments, seg)
        end

        println("#"^80)
        println("$(length(new_segments))/$(length(segments))")
        println("#"^80)

        if length(new_segments) == length(segments)
            break
        end

        segments = new_segments
    end

    return segments
end

# ─── Haversine ────────────────────────────────────────────────

function haversine(lon1::Float64, lat1::Float64, lon2::Float64, lat2::Float64)::Float64
    R = 6_371_000.0
    dlat = deg2rad(lat2 - lat1)
    dlon = deg2rad(lon2 - lon1)
    a = sin(dlat / 2)^2 + cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dlon / 2)^2
    return R * 2 * atan(sqrt(a), sqrt(1 - a))
end

# ─── 近接点省略 ───────────────────────────────────────────────

function thin_points!(segments::Vector{RoadSegment}, min_dist::Float64=10.0)
    total_before = 0
    total_after = 0

    for seg in segments
        total_before += length(seg.points)
        if length(seg.points) <= 2
            total_after += length(seg.points)
            continue
        end

        kept = [seg.points[1]]
        for k in 2:length(seg.points)-1
            pt = seg.points[k]
            last_kept = kept[end]
            if haversine(last_kept[1], last_kept[2], pt[1], pt[2]) > min_dist
                push!(kept, pt)
            end
        end
        push!(kept, seg.points[end])

        seg.points = kept
        total_after += length(kept)
    end

    removed = total_before - total_after
    println("thinned points: $total_before -> $total_after ($removed removed)")
    return segments
end

# ─── GeoJSON 出力 ─────────────────────────────────────────────

function write_geojson(segments::Vector{RoadSegment}, output_dir::String)
    mkpath(output_dir)

    grouped = Dict{String, Vector{RoadSegment}}()
    for seg in segments
        push!(get!(grouped, seg.fclass, RoadSegment[]), seg)
    end

    for fclass in sort(collect(keys(grouped)))
        segs = grouped[fclass]
        features = Vector{Dict{String,Any}}(undef, length(segs))

        for (idx, seg) in enumerate(segs)
            features[idx] = Dict{String,Any}(
                "type" => "Feature",
                "properties" => Dict{String,Any}(
                    "fclass" => seg.fclass,
                    "name" => seg.name,
                    "ref" => seg.ref,
                ),
                "geometry" => Dict{String,Any}(
                    "type" => "LineString",
                    "coordinates" => [collect(pt) for pt in seg.points],
                ),
            )
        end

        geojson = Dict{String,Any}(
            "type" => "FeatureCollection",
            "features" => features,
        )

        filepath = joinpath(output_dir, "osm_$(fclass).geojson")
        open(filepath, "w") do f
            JSON.print(f, geojson)
        end

        println("wrote $filepath ($(length(features)) features)")
    end
end

# ─── メイン ───────────────────────────────────────────────────

function main()
    if length(ARGS) < 1
        println(stderr, "Usage: julia osm_extract_simplify.jl INPUT.osm.pbf [-o DIR] [-c CLASS...] [-i N]")
        exit(1)
    end

    # 引数パース
    input_file = ""
    output_dir = "."
    classes = copy(DEFAULT_CLASSES)
    max_iter = 3

    i = 1
    while i <= length(ARGS)
        arg = ARGS[i]
        if arg == "-o" || arg == "--output"
            i += 1
            output_dir = ARGS[i]
        elseif arg == "-c" || arg == "--classes"
            classes = String[]
            i += 1
            while i <= length(ARGS) && !startswith(ARGS[i], "-")
                push!(classes, ARGS[i])
                i += 1
            end
            continue  # i は既に次の引数を指している
        elseif arg == "-i" || arg == "--max-iter"
            i += 1
            max_iter = parse(Int, ARGS[i])
        else
            input_file = arg
        end
        i += 1
    end

    if input_file == ""
        println(stderr, "Error: input file is required")
        exit(1)
    end

    println("READING AND EXTRACTING...")
    segments = read_pbf(input_file, classes)
    println("extracted size: $(length(segments))")

    println("COMBINING...")
    segments = combine_segments(segments, max_iter)

    println("THINNING...")
    thin_points!(segments, 10.0)

    println("WRITING...")
    write_geojson(segments, output_dir)

    println("COMPLETED")
end

main()
