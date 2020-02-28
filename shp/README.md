# Simplified Japanese road network from OSM

## 内容

OpenStreetMapの道路ネットワークデータ（2019年12月時点）から主要道路（motorway, trunk, primary, secondary, それぞれの_link）を抽出し，断片化したリンクを集約し軽量化したデータです．

## ファイル構成

- `osm_*_major_roads.*`: [スクリプト](https://github.com/toruseo/osm-road-extractor-simplifier)により縮約した各地域の主要道路シェープファイル．

- `japan_road_network.qgz`: 全シェープを閲覧できるQGISプロジェクトファイル．以下のような見た目になる．

<img src="https://toruseo.github.io/misc/osm_ext_simp.jpg" width="480pt">

## ライセンス

[Open Data Commons Open Database License](https://www.openstreetmap.org/copyright/)