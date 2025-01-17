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
    # This server kind of sucks and doesn't support range requests for finishing downloads. Just re-download it each time.
    local filename="$1"
    wget -N -c "https://osmdata.openstreetmap.de/download/$filename.zip" 1>&2
    chmod 444 "$filename.zip"
}

process_dataset() {
    local dataset="$1"

    case "$dataset" in
        osm-oceans)
            table="osm_oceans"
            download-osm-de water-polygons-split-3857
            download-osm-de simplified-water-polygons-split-3857
            import "${table}_low" /vsizip/simplified-water-polygons-split-3857.zip/simplified-water-polygons-split-3857 simplified_water_polygons
            import "${table}" /vsizip/water-polygons-split-3857.zip/water-polygons-split-3857 water_polygons
            ;;
        osm-continents)
            table="osm_continents"
            download-osm-de land-polygons-split-3857
            download-osm-de simplified-land-polygons-complete-3857
            import "${table}_low" /vsizip/simplified-land-polygons-complete-3857.zip/simplified-land-polygons-complete-3857 simplified_land_polygons
            import "${table}" /vsizip/land-polygons-split-3857.zip/land-polygons-split-3857 land_polygons
            ;;
        osm-coastlines)
            table="osm_coastlines"
            download-osm-de coastlines-split-3857
            import "${table}" /vsizip/coastlines-split-3857.zip/coastlines-split-3857 lines
            ;;
        usgs-wind-us)
            # Many EIA datasets are available at https://www.eia.gov/maps/maps.htm just point back to USGS
            table="usgs_power_wind_generators"
            wget -N -c 'https://energy.usgs.gov/uswtdb/assets/data/uswtdbSHP.zip'
            shapefile_name="$(unzip -l uswtdbSHP.zip | grep -o '[^/]*\.shp' | awk '{print $4}')"
            shapefile_base="${shapefile_name%.*}"
            # "_ogr_geometry_" MUST BE IN DOUBLE QUOTES
            import "${table}" "/vsizip/uswtdbSHP.zip/$shapefile_name" "$shapefile_base"   \
                "case_id as id, p_name as project_name, p_year as year_online, p_cap as capacity_mw, t_hh as hub_height_m, t_rd as rotor_diameter_m, t_ttlh as total_height_m, t_manu as manufacturer, t_model as model, \"_ogr_geometry_\""
            # Set manufacturer "missing" to null
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "UPDATE $table SET manufacturer = NULL WHERE manufacturer = 'missing';"
            # Generate bounds
            centroid_query=$(cat <<-EOF
            WITH clusters AS (
                SELECT
                    project_name,
                    capacity_mw,
                    ST_ClusterDBSCAN(geom, eps => 10000, minpoints => 1) OVER (PARTITION BY project_name) AS cluster_id,
                    geom
                FROM
                    public.usgs_power_wind_generators
                WHERE
                    project_name IS NOT NULL
            ),
            bounds as (
                SELECT
                    cluster_id,
                    project_name,
                    SUM(capacity_mw) as est_capacity_mw,
                    ST_Buffer(ST_ConvexHull(ST_Collect(geom)), 250) AS geom
                FROM
                    clusters
                GROUP BY
                    cluster_id, project_name
            )
            SELECT
				row_number() OVER(ORDER BY project_name) AS id,
                project_name,
                SUM(est_capacity_mw) as est_capacity_mw,
                ST_Collect(geom) AS geom
            INTO {{dst_table}}
            FROM
                bounds
            GROUP BY
                project_name;
EOF
)
            gen "${table}_bounds" "${centroid_query}"

            # Generate centroid
            centroid_query=$(cat <<-EOF
            SELECT
				row_number() OVER(ORDER BY project_name) AS id,
                project_name,
				MAX(est_capacity_mw) as est_capacity_mw,
                ST_Centroid(ST_Collect(geom)) AS geom
            INTO {{dst_table}}
            FROM
                ${table}_bounds
			GROUP BY project_name;
EOF
)
            gen "${table}_centroids" "${centroid_query}"
            ;;
        usgs-solar-us)
            table="usgs_power_solar_generators"
            wget -N -c 'https://energy.usgs.gov/uspvdb/assets/data/uspvdbSHP.zip'
            shapefile_name="$(unzip -l uspvdbSHP.zip | grep -o '[^/]*\.shp' | awk '{print $4}')"
            shapefile_base="${shapefile_name%.*}"
            # "_ogr_geometry_" MUST BE IN DOUBLE QUOTES
            import "${table}" "/vsizip/uspvdbSHP.zip/$shapefile_name" "$shapefile_base"   \
                "case_id as id, p_name as project_name, p_type as type, p_year as year_online, p_cap_ac as capacity_ac_mw, p_cap_dc as capacity_dc_mw, p_area as area_m2, p_pwr_reg as regional_power_authority, p_tech_pri as tech_primary, p_tech_sec as tech_secondary, p_axis as axis_type, p_azimuth as azimuth, p_tilt as tilt, p_battery as has_battery, p_agrivolt as agrivolt_type, \"_ogr_geometry_\"" \
                "MULTIPOLYGON"
            # Tweak some fields
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "UPDATE $table SET has_battery = 'false' WHERE has_battery = 'missing';"
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "UPDATE $table SET agrivolt_type = NULL WHERE agrivolt_type = 'non-agrivoltaic';"
            # Generate centroids
            centroid_query=$(cat <<-EOF
                SELECT
                    id, project_name, type, year_online, capacity_ac_mw, capacity_dc_mw, area_m2, regional_power_authority, tech_primary, tech_secondary, axis_type, azimuth, tilt, has_battery, agrivolt_type,
                    ST_Centroid(geom) AS geom
                INTO {{dst_table}}
                FROM
                    $table
EOF
)
            gen "${table}_centroids" "${centroid_query}"
            ;;
        us-hifld-transmission-lines)
            # US High Voltage Transmission Lines
            # https://hub.arcgis.com/api/v3/datasets/bd24d1a282c54428b024988d32578e59_0/downloads/data?format=shp&spatialRefId=3857&where=1%3D1
            table="us_hifld_transmission_lines"
            # The gov website links diretly to Arc. Thanks for hosting this data I guess?
            wget -L -N -c -O 'Electric_Power_Transmission_Lines.zip' 'https://hub.arcgis.com/api/v3/datasets/bd24d1a282c54428b024988d32578e59_0/downloads/data?format=shp&spatialRefId=3857&where=1%3D1'
            shapefile_name="$(unzip -l Electric_Power_Transmission_Lines.zip | grep -o '[^/]*\.shp' | awk '{print $4}')"
            shapefile_base="${shapefile_name%.*}"
            # "_ogr_geometry_" MUST BE IN DOUBLE QUOTES
            import "${table}" "/vsizip/Electric_Power_Transmission_Lines.zip/$shapefile_name" "$shapefile_base"   \
                "ID as id, TYPE as type, STATUS as status, OWNER as owner, VOLTAGE as voltage_kv, VOLT_CLASS as voltage_class, \"_ogr_geometry_\"" \
                "MULTILINESTRING"

            # If OVERHEAD is in the type field, set the overhead flag to true, false otherwise
            # Creat a new boolean column overhead
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "ALTER TABLE $table ADD COLUMN overhead BOOLEAN;"
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "UPDATE $table SET overhead = TRUE WHERE type ILIKE '%OVERHEAD%';"
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "UPDATE $table SET overhead = FALSE WHERE type ILIKE '%UNDERGROUND%';"
            # Strip out the overhead/underground from the type field
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "UPDATE $table SET type = regexp_replace(type, '(; )?OVERHEAD|(; )?UNDERGROUND', '');"
            # If type is empty string or NOT AVAILABLE set it to NULL
            psql --quiet -d "$POSTGRES_MAPS_DB" -c "UPDATE $table SET type = NULL WHERE type = '' OR type = 'NOT AVAILABLE';"
            ;;
        *)
            echo "Unknown dataset ${dataset}"
            exit 1
            ;;
    esac
}

import() {
    local layer="$1"
    local file="$2"
    local inlayer="$3"
    local fields="${4:-\"_ogr_geometry_\"}"
    local force_geometry="${5:-false}"

    # Spatial index is created manually after import, because otherwise
    # the index names generated by ogr2ogr clash with the preexisting index.

    echo "Importing $file to ${POSTGRES_MAPS_DB}.$layer..."

    sql_statement="SELECT $fields FROM $inlayer"

    force_geometry_flag=""
    if [ "$force_geometry" != "false" ]; then
        force_geometry_flag="-nlt $force_geometry"
    fi

    ogr2ogr -f PostgreSQL "PG:dbname=${POSTGRES_MAPS_DB}" -overwrite -nln "${layer}_new" \
        -lco GEOMETRY_NAME=geom \
        -lco FID=id \
        -lco SPATIAL_INDEX=NONE \
        -t_srs EPSG:3857 \
        $force_geometry_flag \
        -sql "$sql_statement" \
        "$file"

    psql --quiet -d "$POSTGRES_MAPS_DB" -c "ANALYZE ${layer}_new;"
    psql --quiet -d "$POSTGRES_MAPS_DB" -c "CREATE INDEX index_${layer}_new_geom ON ${layer}_new USING GIST (geom);"
    psql --quiet -d "$POSTGRES_MAPS_DB" -c "CLUSTER ${layer}_new USING index_${layer}_new_geom;"
    psql --quiet -d "$POSTGRES_MAPS_DB" -c "BEGIN; DROP TABLE IF EXISTS $layer; ALTER TABLE ${layer}_new RENAME TO $layer; ALTER INDEX index_${layer}_new_geom RENAME TO index_${layer}_geom; COMMIT;"
}

gen() {
    # Run an aggregation query against an existing table to derive features
    # Use SELECT ... INTO {{dst_table}} FROM ... syntax to generate a new table
    local dst_table="$1"
    local query="$2"

    psql --quiet -d "$POSTGRES_MAPS_DB" -c "DROP TABLE IF EXISTS ${dst_table}_new;"

    query="${query//\{\{dst_table\}\}/${dst_table}_new}"
    psql --quiet -d "$POSTGRES_MAPS_DB" -c "${query}"

    psql --quiet -d "$POSTGRES_MAPS_DB" -c "ANALYZE ${dst_table}_new;"
    psql --quiet -d "$POSTGRES_MAPS_DB" -c "CREATE INDEX index_${dst_table}_new_geom ON ${dst_table}_new USING GIST (geom);"
    psql --quiet -d "$POSTGRES_MAPS_DB" -c "CLUSTER ${dst_table}_new USING index_${dst_table}_new_geom;"
    psql --quiet -d "$POSTGRES_MAPS_DB" -c "BEGIN; DROP TABLE IF EXISTS $dst_table; ALTER TABLE ${dst_table}_new RENAME TO $dst_table; ALTER INDEX index_${dst_table}_new_geom RENAME TO index_${dst_table}_geom; COMMIT;"
}

cd "$DIR"
echo "Downloading files to $PWD..."
process_dataset "$DATASET"

echo "Done."

