# OSM Road Extractor/Simplifier

This extracts major roads from OSM and simplify them in order to smoothly visualize road networks using QGIS etc.

# Functions

- Extracts road links belonging to specific classes (`fclass`)
- Simplify road links.
"Simplify" means that it merges neighboring polylines with the same `name` or `ref` attributes.
It does not change visual shape of road networks.

Based on output shapfiles, you can draw a map like below by labeling `name` and `ref`.
You can also choose specific roads by filtering by `ref`.

<img src="https://toruseo.github.io/misc/osm_ext_simp.jpg" width="480pt">

# Processed data

Processed data (Japanese road map) is available from the [release](https://github.com/toruseo/osm-road-extractor-simplifier/releases) of this repo.

# Requirement

Python 3.*

# How to use

1. Obtain road shapefiles of OSM (e.g., http://download.geofabrik.de/ )

2. Put `osm_extract_simplify.py` and `shapefile.py` ([`pyshp`](https://github.com/GeospatialPython/pyshp)) to an appropriate location.

3. Run codes like below
```python
from osm_extract_simplify import osm_extract_simplify

osm_extract_simplify(
    "./shp/osm_tokyo_major",  #input shapefile
    "./shp/out",              #output shapefile
    ["motorway", "primary", "secondary", "trunk"],    #extraction class. The corresponding "*_link" will be automatically extracted as well
    encoding="sjis",          #encoding
    max_iter=3                #Maximum number of iterations for simplification
)
```

# License

MIT License
