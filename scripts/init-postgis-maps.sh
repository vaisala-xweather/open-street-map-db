#!/bin/bash
set -euo pipefail

# Initialize the database for OSM
# via: https://imposm.org/docs/imposm3/latest/tutorial.html#create-database

createuser --no-superuser --no-createrole "$POSTGRES_MAPS_USER"
createdb -E UTF8 -O "${POSTGRES_MAPS_USER}" "${POSTGRES_MAPS_DB}"
psql -d "${POSTGRES_MAPS_DB}" -c "CREATE EXTENSION postgis;"
psql -d "${POSTGRES_MAPS_DB}" -c "CREATE EXTENSION hstore;" # only required for hstore support
echo "ALTER USER \"${POSTGRES_MAPS_USER}\" WITH PASSWORD '${POSTGRES_MAPS_PASSWORD}';" |psql -d $POSTGRES_MAPS_DB

# Increase maximum write ahead log size for larger imports
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET shared_buffers = '1GB';"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET work_mem = '50MB';"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET maintenance_work_mem = '10GB';"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET autovacuum_work_mem = '2GB';"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET wal_level = 'minimal';"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET checkpoint_timeout = '60min';"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET max_wal_size = '10GB';"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET checkpoint_completion_target = 0.9;"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET max_wal_senders = 0;"
psql -d $POSTGRES_MAPS_DB -c "ALTER SYSTEM SET random_page_cost = 1.0;"
pg_ctl reload
