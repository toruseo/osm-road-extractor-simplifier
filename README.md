# OSM Road Extractor/Simplifier

OSMから主要道路だけを抜き出し，QGISなどで素早く描画できるように軽量化する．
[readme in English](README.en.md)

これにより処理した日本道路地図をウェブブラウザで簡易に閲覧できるようにしました：https://toruseo.jp/road-viewer-finder/

# 機能

- `.osm.pbf`ファイルから特定の種別（`highway`タグ）を持つ道路リンクのみ抽出する．
- 道路リンクを縮約し，軽量化する．
ここで，縮約とは，同じ`name`もしくは`ref`属性を持つ隣接しあったpolylineを一つのpolylineにすることを意味する．
見た目の形状は変化しない．
- 道路種別ごと（motorway, trunk, primary, secondary）にGeoJSONファイルとして出力する．

軽量化したデータをQGISで`name`と`ref`をラベルにして描画すると以下のような見た目になる．
`ref`でフィルタリングすると道路番号から大まかに道路を選択できる．

<img src="https://toruseo.github.io/misc/osm_ext_simp.jpg" width="480pt">

# 軽量化済みデータ

本スクリプトによる日本の軽量化済みデータを本レポジトリの[release内](https://github.com/toruseo/osm-road-extractor-simplifier/releases/download/v2019.0.1/shp.zip)に置いてある．TODO: 要更新

# 環境

- Python 3.*
- [pyosmium](https://osmcode.org/pyosmium/) (`pip install osmium`)

```
pip install -r requirements.txt
```

# 使い方

1. OSMの`.osm.pbf`ファイルを入手（例：http://download.geofabrik.de/ ）

2. 依存パッケージをインストール
```
pip install -r requirements.txt
```

3. コマンドラインから実行
```bash
python osm_extract_simplify.py input.osm.pbf -o ./output
```

### オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `-o`, `--output` | 出力ディレクトリ | `.`（カレントディレクトリ） |
| `-c`, `--classes` | 抽出対象道路種別 | `motorway trunk primary secondary` |
| `-i`, `--max-iter` | 縮約操作繰り返し回数 | `3` |

### 例

```bash
# 全種別を抽出
python osm_extract_simplify.py japan-latest.osm.pbf -o ./output

# primaryとsecondaryのみ抽出
python osm_extract_simplify.py japan-latest.osm.pbf -o ./output -c primary secondary

# 縮約回数を増やす
python osm_extract_simplify.py japan-latest.osm.pbf -o ./output -i 5
```

出力ファイル：
- `osm_motorway.geojson`
- `osm_trunk.geojson`
- `osm_primary.geojson`
- `osm_secondary.geojson`

# 製作者

瀬尾亨

# License

MIT License
