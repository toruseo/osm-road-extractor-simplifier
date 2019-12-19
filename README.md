# OSM Road Extractor Simplifier

OSMから主要道路だけを抜き出しQGISなどで素早く描画できるように簡略化する．

# 使い方

1. OSMの道路シェープファイルを入手（例：http://download.geofabrik.de/）

2. 同梱スクリプト`osm_extract_simplify.py`を適当な場所に置く．
さらに，`pyshp`をインストールするか，同梱スクリプト`shapefile.py`を同じ場所に置く．

2. 以下を実行

```
import osm_extract_simplify

osm_extract_simplify.osm_extract_simplify("./shp/osm_tokyo_major", "./shp/out", ["motorway", "primary", "secondary", "trunk"], encoding="sjis", max_iter=3)
```

# 環境

Python 3.*

# License

MIT License