#!/bin/bash
set -euo pipefail

TILE_SET="mvt_power"

rm -rf ./data/${TILE_SET}.mbtiles ./data/${TILE_SET}.pmtiles || true
/scripts/generate_metadata.py --name ${TILE_SET} /data/tile-cache/${TILE_SET}/ /data/tile-cache/${TILE_SET}/metadata.json
mb-util --scheme xyz --image_format pbf /data/tile-cache/${TILE_SET} /data/${TILE_SET}.mbtiles
# sqlite3 /data/${TILE_SET}.mbtiles "INSERT INTO metadata (name, value) VALUES ('format', 'pbf')"
pmtiles convert /data/${TILE_SET}.mbtiles /data/${TILE_SET}.pmtiles
du -hs ./data/${TILE_SET}.*tiles
ogrinfo /data/${TILE_SET}.mbtiles
echo "Verifying pmtiles..." >&2
pmtiles verify /data/${TILE_SET}.pmtiles
