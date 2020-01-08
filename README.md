# OSM Road Extractor/Simplifier

OSMから主要道路だけを抜き出し，QGISなどで素早く描画できるように軽量化する．
[readme in English](README.en.md)


# 機能

- 特定の種別（`fclass`）を持つ道路リンクのみ抽出する．
- 道路リンクを縮約し，軽量化する．
ここで，縮約とは，同じ`name`もしくは`ref`属性を持つ隣接しあったpolylineを一つのpolylineにすることを意味する．
見た目の形状は変化しない．

# 環境

Python 3.*

# 使い方

1. OSMの道路シェープファイルを入手（例：http://download.geofabrik.de/ ）

2. 同梱スクリプト`osm_extract_simplify.py`と`shapefile.py`（[pyshp](https://github.com/GeospatialPython/pyshp)）を適当な場所に置く．

3. 以下のようなPythonコードを実行
```python
from osm_extract_simplify import osm_extract_simplify

osm_extract_simplify(
    "./shp/osm_tokyo_major",  #入力シェープファイル
    "./shp/out",              #出力シェープファイル
    ["motorway", "primary", "secondary", "trunk"],    #抽出対象道路種別．対応する*_linkは自動的に抽出される
    encoding="utf8",          #シェープファイルの文字コード
    max_iter=3                #縮約操作繰り返し回数．
)
```
もしくは以下のようなコマンドを実行
```
python osm_extract_simplify ./sample/shapefile1 utf8
```

4. QGISで`name`と`ref`をラベルにすると以下のような地図が描ける．
`ref`でフィルタリングすると道路番号から大まかに道路を選択できる．

<img src="https://toruseo.github.io/misc/osm_ext_simp.jpg" width="480pt">

# 軽量化済みデータ

日本の軽量化済みデータを[shp](https://github.com/toruseo/osm-road-extractor-simplifier/tree/master/shp)フォルダ内に置いてある．

# License

MIT License
