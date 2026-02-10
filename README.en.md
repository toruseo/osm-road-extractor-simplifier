# OSM Road Extractor/Simplifier

This extracts major roads from OSM and simplifies them in order to smoothly visualize road networks using QGIS etc.

# Functions

- Extracts road links belonging to specific classes (`highway` tag) from `.osm.pbf` files.
- Simplifies road links.
"Simplify" means that it merges neighboring polylines with the same `name` or `ref` attributes.
It does not change the visual shape of road networks.
- Outputs GeoJSON files per road class (motorway, trunk, primary, secondary).

Based on output GeoJSON files, you can draw a map like below by labeling `name` and `ref`.
You can also choose specific roads by filtering by `ref`.

<img src="https://toruseo.github.io/misc/osm_ext_simp.jpg" width="480pt">

# Processed data

Processed data (Japanese road map) is available from the [release](https://github.com/toruseo/osm-road-extractor-simplifier/releases) of this repo.

# Requirements

- Python 3.*
- [pyosmium](https://osmcode.org/pyosmium/) (`pip install osmium`)

```
pip install -r requirements.txt
```

# How to use

1. Obtain `.osm.pbf` files from OSM (e.g., http://download.geofabrik.de/ )

2. Install dependencies
```
pip install -r requirements.txt
```

3. Run from command line
```bash
python osm_extract_simplify.py input.osm.pbf -o ./output
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-o`, `--output` | Output directory | `.` (current directory) |
| `-c`, `--classes` | Road classes to extract | `motorway trunk primary secondary` |
| `-i`, `--max-iter` | Number of simplification iterations | `3` |

### Examples

```bash
# Extract all classes
python osm_extract_simplify.py japan-latest.osm.pbf -o ./output

# Extract only primary and secondary
python osm_extract_simplify.py japan-latest.osm.pbf -o ./output -c primary secondary

# Increase simplification iterations
python osm_extract_simplify.py japan-latest.osm.pbf -o ./output -i 5
```

Output files:
- `osm_motorway.geojson`
- `osm_trunk.geojson`
- `osm_primary.geojson`
- `osm_secondary.geojson`

# License

MIT License
