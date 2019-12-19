# OSM Road Extractor Simplifier

OSMから主要道路だけを抜き出しQGISなどで素早く描画できるように縮約する．

# 使い方

1. OSMの道路シェープファイルを入手（例：http://download.geofabrik.de/ ）

2. 同梱スクリプト`osm_extract_simplify.py`を適当な場所に置く．
さらに，`pyshp`（ https://github.com/GeospatialPython/pyshp ）をインストールするか，同梱スクリプト`shapefile.py`を同じ場所に置く．

3. 以下を実行

```python
import osm_extract_simplify

osm_extract_simplify.osm_extract_simplify(
    "./shp/osm_tokyo_major",  # 入力シェープファイル
    "./shp/out",              # 出力シェープファイル
    ["motorway", "primary", "secondary", "trunk"],    # 抽出対象道路種別．対応する*_linkは自動的に抽出される
    encoding="sjis",          # 日本語の場合 
    max_iter=3                # 縮約度合い
)
```

4. QGSIでnameとrefをラベルにすると以下のような地図が描ける．
refでフィルタリングすると道路番号から大まかに道路を抽出できる．

![QGIS可視化](https://toruseo.github.io/misc/osm_ext_simp.jpg)

# 環境

Python 3.*

# License

MIT License
