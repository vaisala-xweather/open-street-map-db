#!/bin/bash
set -euo pipefail

rm -rf ./data/mvt_world.mbtiles ./data/mvt_world.pmtiles || true
/scripts/generate_metadata.py --name mvt_world /data/tile-cache/mvt_world/ /data/tile-cache/mvt_world/metadata.json
mb-util --scheme xyz --image_format pbf /data/tile-cache/mvt_world /data/mvt_world.mbtiles
# sqlite3 /data/mvt_world.mbtiles "INSERT INTO metadata (name, value) VALUES ('format', 'pbf')"
pmtiles convert /data/mvt_world.mbtiles /data/mvt_world.pmtiles
du -hs ./data/mvt_world.*tiles
ogrinfo /data/mvt_world.mbtiles
echo "Verifying pmtiles..." >&2
pmtiles verify /data/mvt_world.pmtiles
