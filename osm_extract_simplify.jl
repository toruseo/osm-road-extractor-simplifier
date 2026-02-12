#!/usr/bin/env julia
# OSM PBF から主要道路を抽出・結合し GeoJSON で出力する

using OpenStreetMapPBF
using JSON
using CodecZlib

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

        # 端点からセグメントインデックスへの辞書を構築（O(n)）
        start_map = Dict{Tuple{String,Tuple{Float64,Float64}}, Set{Int}}()
        end_map   = Dict{Tuple{String,Tuple{Float64,Float64}}, Set{Int}}()
        for idx in 1:n
            seg = segments[idx]
            sk = (seg.fclass, seg.points[1])
            ek = (seg.fclass, seg.points[end])
            push!(get!(start_map, sk, Set{Int}()), idx)
            push!(get!(end_map,   ek, Set{Int}()), idx)
        end

        removed = Set{Int}()
        new_segments = RoadSegment[]

        for i in 1:n
            i in removed && continue

            seg = RoadSegment(segments[i].fclass, segments[i].name,
                              segments[i].ref, copy(segments[i].points))

            # 端点辞書で隣接セグメントを探索し結合（結合後は端点が変わるので再探索）
            merged = true
            while merged
                merged = false

                # 候補収集: seg の終点 == 候補の始点、または seg の始点 == 候補の終点
                candidates = Set{Int}()
                for j in get(start_map, (seg.fclass, seg.points[end]), ())
                    if j > i && !(j in removed)
                        push!(candidates, j)
                    end
                end
                for j in get(end_map, (seg.fclass, seg.points[1]), ())
                    if j > i && !(j in removed)
                        push!(candidates, j)
                    end
                end

                for j in sort!(collect(candidates))
                    j in removed && continue
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
                        push!(removed, j)
                        merged = true
                        break  # 端点が変わったので再探索
                    end
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
                    "coordinates" => [[round(pt[1], digits=5), round(pt[2], digits=5)] for pt in seg.points],
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

        gz_filepath = filepath * ".gz"
        open(gz_filepath, "w") do f
            gzf = GzipCompressorStream(f)
            JSON.print(gzf, geojson)
            close(gzf)
        end

        println("wrote $filepath + .gz ($(length(features)) features)")
    end
end

# ─── メイン ───────────────────────────────────────────────────

# コマンドライン例：
# julia osm_extract_simplify.jl japan-260209.osm.pbf -o output -i 10

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

    println("WRITING...")
    write_geojson(segments, output_dir)

    println("COMPLETED")
end

main()
