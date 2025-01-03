#!/bin/bash
#
#  download-and-import.sh DIR DB DATASET TABLE
#
#  DIR     - Download directory
#  DB      - Database (database name or postgres: URI)
#  DATASET - Dataset to download and import
#  TABLE   - Table name
#
#  Available datasets are:
#  * coastlines
#  * continents
#  * oceans
#
#  Download and import OSM data from https://osmdata.openstreetmap.de/
#

set -euo pipefail
set -x

# if [ "$#" -lt 4 ]; then
#     echo "Usage: download-and-import.sh DIR DB DATASET TABLE"
#     echo "Datasets: coastlines continents oceans"
#     exit 2
# fi

DIR="$1"
DATASET="$2"

download-osm-de() {
    local layer="$1"
    wget --quiet "https://osmdata.openstreetmap.de/download/$layer.zip"
}

process_dataset() {
    local dataset="$1"

    case "$dataset" in
        oceans)
            db="osm"
            table="oceans"
            download-osm-de water-polygons-split-3857
            download-osm-de simplified-water-polygons-split-3857
            import "$db" "${table}_low" /vsizip/simplified-water-polygons-split-3857.zip/simplified-water-polygons-split-3857 simplified_water_polygons
            import "$db" "${table}" /vsizip/water-polygons-split-3857.zip/water-polygons-split-3857 water_polygons
            ;;
        continents)
            db="osm"
            table="continents"
            download-osm-de land-polygons-split-3857
            download-osm-de simplified-land-polygons-complete-3857
            import "$db" "${table}_low" /vsizip/simplified-land-polygons-complete-3857.zip/simplified-land-polygons-complete-3857 simplified_land_polygons
            import "$db" "${table}" /vsizip/land-polygons-split-3857.zip/land-polygons-split-3857 land_polygons
            ;;
        coastlines)
            db="osm"
            table="coastlines"
            download-osm-de coastlines-split-3857
            import "$db" "${table}" /vsizip/coastlines-split-3857.zip/coastlines-split-3857 lines
            ;;
        wind-us)
            db="osm"
            table="power_wind_generators"
            wget --quiet 'https://energy.usgs.gov/uswtdb/assets/data/uswtdbSHP.zip'
            shapefile_name="$(unzip -l uswtdbSHP.zip | grep -o '[^/]*\.shp' | awk '{print $4}')"
            shapefile_base="${shapefile_name%.*}"
            # "_ogr_geometry_" MUST BE IN DOUBLE QUOTES
            import "$db" "${table}" "/vsizip/uswtdbSHP.zip/$shapefile_name" "$shapefile_base" \
                "case_id as id, p_name as project_name, p_year as year_online, p_cap as capacity_mw, t_hh as hub_height_m, t_rd as rotor_diameter_m, t_ttlh as total_height_m, t_manu as manufacturer, t_model as model, \"_ogr_geometry_\""
            # Set manufacturer "missing" to null
            psql --quiet -d "$db" -c "UPDATE $table SET manufacturer = NULL WHERE manufacturer = 'missing';"
            ;;

        *)
            echo "Unknown dataset ${dataset}"
            exit 1
            ;;
    esac
}

import() {
    local db="$1"
    local layer="$2"
    local file="$3"
    local inlayer="$4"
    local fields="${5:-\"_ogr_geometry_\"}"

    # Spatial index is created manually after import, because otherwise
    # the index names generated by ogr2ogr clash with the preexisting index.

    echo "Importing $file to $db.$layer..."

    sql_statement="SELECT $fields FROM $inlayer"

    ogr2ogr -f PostgreSQL "PG:dbname=$db" -overwrite -nln "${layer}_new" \
        -lco GEOMETRY_NAME=geom \
        -lco FID=id \
        -lco SPATIAL_INDEX=NONE \
        -t_srs EPSG:3857 \
        -sql "$sql_statement" \
        "$file"

    psql --quiet -d "$db" -c "ANALYZE ${layer}_new;"
    psql --quiet -d "$db" -c "CREATE INDEX ON ${layer}_new USING GIST (geom);"
    psql --quiet -d "$db" -c "BEGIN; DROP TABLE IF EXISTS $layer; ALTER TABLE ${layer}_new RENAME TO $layer; COMMIT;"
}

cd "$DIR"
echo "Downloading files to $PWD..."
process_dataset "$DATASET"

echo "Done."

