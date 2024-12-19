#!/bin/bash
set -euo pipefail

# Initialize the database for OSM
# via: https://imposm.org/docs/imposm3/latest/tutorial.html#create-database

createuser --no-superuser --no-createrole --createdb osm
createdb -E UTF8 -O osm osm
psql -d osm -c "CREATE EXTENSION postgis;"
psql -d osm -c "CREATE EXTENSION hstore;" # only required for hstore support
echo "ALTER USER osm WITH PASSWORD 'osm';" |psql -d osm

# Increase maximum write ahead log size for larger imports
psql -d osm -c "ALTER SYSTEM SET shared_buffers = '1GB';"
psql -d osm -c "ALTER SYSTEM SET work_mem = '50MB';"
psql -d osm -c "ALTER SYSTEM SET maintenance_work_mem = '10GB';"
psql -d osm -c "ALTER SYSTEM SET autovacuum_work_mem = '2GB';"
psql -d osm -c "ALTER SYSTEM SET wal_level = 'minimal';"
psql -d osm -c "ALTER SYSTEM SET checkpoint_timeout = '60min';"
psql -d osm -c "ALTER SYSTEM SET max_wal_size = '10GB';"
psql -d osm -c "ALTER SYSTEM SET checkpoint_completion_target = 0.9;"
psql -d osm -c "ALTER SYSTEM SET max_wal_senders = 0;"
psql -d osm -c "ALTER SYSTEM SET random_page_cost = 1.0;"
pg_ctl reload
