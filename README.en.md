# OSM Road Extractor/Simplifier

This extracts major roads from OSM and simplify them in order to smoothly visualize road networks using QGIS etc.

# Emviroment

Python 3.*

# Functions

- Extracts road links belonging to specific classes (fclass)
- Simplify road links.
"Simplify" means that it merges neighboring polylines with the same name or ref attributes.
It does not change visual shape of road networks.

# How to use

1. Obtain road shape files of OSM (e.g., http://download.geofabrik.de/ )

2. Put `osm_extract_simplify.py` and `shapefile.py` ([`pyshp`](https://github.com/GeospatialPython/pyshp)) to an appropriate location.

3. Run codes like below
```python
from osm_extract_simplify import osm_extract_simplify

osm_extract_simplify(
    "./shp/osm_tokyo_major",  #input shape file
    "./shp/out",              #output shape file
    ["motorway", "primary", "secondary", "trunk"],    #target class of extraction. The corresponding "*_link" are automatically extracted as well
    encoding="sjis",          #if Japanese
    max_iter=3                #Maximum number of iteration for simplification
)
```

4. You can draw a map like below by labeling name and ref.
You can also extract specific roads by filtering by ref.

<img src="https://toruseo.github.io/misc/osm_ext_simp.jpg" width="480pt">

# License

MIT License
