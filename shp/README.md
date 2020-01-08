# Simplified Japanese road network from OSM

## 内容

OpenStreetMapの道路ネットワークデータ（2019年12月時点）から主要道路（motorway, trunk, primary, secondary, それぞれの_link）を抽出し，断片化したリンクを集約し軽量化したデータです．
[Open Data Commons Open Database License](https://www.openstreetmap.org/copyright/)の下で公開されるデータですので，使用の際は当該ライセンスに従ってください．

## ファイル構成

- `osm_*_major_roads.*`: [スクリプト](https://github.com/toruseo/osm-road-extractor-simplifier)により縮約した各地域の主要道路シェープファイル．

- `osm_japan_major_roads.zip`：上シェープをマージして圧縮したファイル．非圧縮状態だと100MBを超えてgithubにアップロードできないため．

- `japan_road_network.qgz`: 全シェープを閲覧できるQGISプロジェクトファイル


