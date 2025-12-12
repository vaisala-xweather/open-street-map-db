#!/bin/bash
#
#  download-import-natural-earth.sh DIR
#
#  DIR - Download directory
#
#  Download and import Natural Earth data from https://www.naturalearthdata.com/
#
#  Cultural Vectors (10m):
#  - Admin 0 Countries
#  - Admin 0 Boundary Lines
#  - Admin 1 States/Provinces
#  - Admin 2 Counties
#  - Populated Places
#  - Roads
#  - Railroads
#  - Airports
#  - Ports
#  - Urban Areas
#
#  Physical Vectors (10m):
#  - Coastline
#  - Land
#  - Minor Islands
#  - Reefs
#  - Ocean
#  - Rivers + Lake Centerlines
#  - Lakes and Reservoirs
#  - Physical Labels
#  - Playas
#  - Bathymetry
#  - Geographic Lines
#

set -euo pipefail
set -x

DIR="$1"

download-ne() {
	# Download Natural Earth dataset
	# Add browser headers to avoid 500 errors from server

	# Example usage:
	#  download-ne cultural/ne_10m_admin_0_countries
	#  download-ne physical/ne_10m_lakes
	local filename="$1"

	# Split filename into directory and base filename
	local category=$(dirname "$filename")  # e.g., "cultural" or "physical"
	local basename=$(basename "$filename") # e.g., "ne_10m_admin_0_countries"

	# Create natural_earth/category directory structure
	mkdir -p "natural_earth/${category}"

	# Download to the appropriate subdirectory
	local output_file="natural_earth/${category}/${basename}.zip"

	# Yes, the actual URL is doubled up like that with http// in it again.
	wget -N -c \
		--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
		--header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8" \
		--header="Accept-Language: en-US,en;q=0.9" \
		--header="Accept-Encoding: gzip, deflate" \
		--header="Referer: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/" \
		--header="Connection: keep-alive" \
		--header="Upgrade-Insecure-Requests: 1" \
		-O "${output_file}" \
		"https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/${filename}.zip" 1>&2
	chmod 444 "${output_file}"
}

import() {
	local table="$1"
	local file="$2"
	local inlayer="$3"
	local force_geometry="${4:-false}"
	local wrapdateline="${5:-false}"

	echo "Importing $file to ${POSTGRES_MAPS_DB}.$table..."

	force_geometry_flag=""
	if [ "$force_geometry" != "false" ]; then
		force_geometry_flag="-nlt $force_geometry"
	fi

	wrapdateline_flag=""
	if [ "$wrapdateline" != "false" ]; then
		wrapdateline_flag="-wrapdateline"
	fi

	if ! ogr2ogr -f PostgreSQL "PG:dbname=${POSTGRES_MAPS_DB}" -overwrite -nln "${table}_new" \
		-lco GEOMETRY_NAME=geom \
		-lco FID=id \
		-lco SPATIAL_INDEX=NONE \
		-lco LAUNDER=NO \
		-lco PRECISION=NO \
		-lco OVERWRITE=YES \
		-nlt PROMOTE_TO_MULTI \
		-t_srs EPSG:3857 \
		$force_geometry_flag \
		$wrapdateline_flag \
		"$file" \
		"$inlayer"; then
		echo "Error: ogr2ogr failed for $file"
		return 1
	fi

	if ! psql --quiet -d "$POSTGRES_MAPS_DB" -c "ANALYZE ${table}_new;"; then
		echo "Error: ANALYZE failed"
		return 1
	fi

	if ! psql --quiet -d "$POSTGRES_MAPS_DB" -c "CREATE INDEX index_${table}_new_geom ON ${table}_new USING GIST (geom);"; then
		echo "Error: CREATE INDEX failed"
		return 1
	fi

	if ! psql --quiet -d "$POSTGRES_MAPS_DB" -c "CLUSTER ${table}_new USING index_${table}_new_geom;"; then
		echo "Error: CLUSTER failed"
		return 1
	fi

	# Drop old table and rename new one atomically
	# Use 2>/dev/null to suppress NOTICE messages about non-existent tables
	if ! psql --quiet -d "$POSTGRES_MAPS_DB" 2>/dev/null <<-EOF
		BEGIN;
		DROP TABLE IF EXISTS $table;
		ALTER TABLE ${table}_new RENAME TO $table;
		ALTER INDEX index_${table}_new_geom RENAME TO index_${table}_geom;
		COMMIT;
	EOF
	then
		echo "Error: Table rename transaction failed"
		return 1
	fi

	return 0
}

cd "$DIR"
echo "Downloading Natural Earth files to $PWD..."

# ============================================================================
# CULTURAL VECTORS (10m)
# ============================================================================

echo "=== Downloading Cultural Vectors ==="

# Admin 0 - Countries
echo "--- Admin 0 Countries ---"
download-ne "cultural/ne_10m_admin_0_countries"
import "ne_admin_0_countries" \
	"/vsizip/natural_earth/cultural/ne_10m_admin_0_countries.zip/ne_10m_admin_0_countries.shp" \
	"ne_10m_admin_0_countries"

# Admin 0 - Boundary Lines (Land)
echo "--- Admin 0 Boundary Lines ---"
download-ne "cultural/ne_10m_admin_0_boundary_lines_land"
import "ne_admin_0_boundary_lines_land" \
	"/vsizip/natural_earth/cultural/ne_10m_admin_0_boundary_lines_land.zip/ne_10m_admin_0_boundary_lines_land.shp" \
	"ne_10m_admin_0_boundary_lines_land"

# Admin 1 - States, Provinces
echo "--- Admin 1 States/Provinces ---"
download-ne "cultural/ne_10m_admin_1_states_provinces"
import "ne_admin_1_states_provinces" \
	"/vsizip/natural_earth/cultural/ne_10m_admin_1_states_provinces.zip/ne_10m_admin_1_states_provinces.shp" \
	"ne_10m_admin_1_states_provinces"

# Admin 2 - Counties
echo "--- Admin 2 Counties ---"
download-ne "cultural/ne_10m_admin_2_counties"
import "ne_admin_2_counties" \
	"/vsizip/natural_earth/cultural/ne_10m_admin_2_counties.zip/ne_10m_admin_2_counties.shp" \
	"ne_10m_admin_2_counties"

# Populated Places
echo "--- Populated Places ---"
download-ne "cultural/ne_10m_populated_places"
import "ne_populated_places" \
	"/vsizip/natural_earth/cultural/ne_10m_populated_places.zip/ne_10m_populated_places.shp" \
	"ne_10m_populated_places"

# Roads
echo "--- Roads ---"
download-ne "cultural/ne_10m_roads"
import "ne_roads" \
	"/vsizip/natural_earth/cultural/ne_10m_roads.zip/ne_10m_roads.shp" \
	"ne_10m_roads"

# Roads - North America Supplement
echo "--- Roads North America ---"
download-ne "cultural/ne_10m_roads_north_america"
import "ne_roads_north_america" \
	"/vsizip/natural_earth/cultural/ne_10m_roads_north_america.zip/ne_10m_roads_north_america.shp" \
	"ne_10m_roads_north_america"

# Railroads
echo "--- Railroads ---"
download-ne "cultural/ne_10m_railroads"
import "ne_railroads" \
	"/vsizip/natural_earth/cultural/ne_10m_railroads.zip/ne_10m_railroads.shp" \
	"ne_10m_railroads"

# Railroads - North America Supplement
echo "--- Railroads North America ---"
download-ne "cultural/ne_10m_railroads_north_america"
import "ne_railroads_north_america" \
	"/vsizip/natural_earth/cultural/ne_10m_railroads_north_america.zip/ne_10m_railroads_north_america.shp" \
	"ne_10m_railroads_north_america"

# Airports
echo "--- Airports ---"
download-ne "cultural/ne_10m_airports"
import "ne_airports" \
	"/vsizip/natural_earth/cultural/ne_10m_airports.zip/ne_10m_airports.shp" \
	"ne_10m_airports"

# Ports
echo "--- Ports ---"
download-ne "cultural/ne_10m_ports"
import "ne_ports" \
	"/vsizip/natural_earth/cultural/ne_10m_ports.zip/ne_10m_ports.shp" \
	"ne_10m_ports"

# Urban Areas
echo "--- Urban Areas ---"
download-ne "cultural/ne_10m_urban_areas"
import "ne_urban_areas" \
	"/vsizip/natural_earth/cultural/ne_10m_urban_areas.zip/ne_10m_urban_areas.shp" \
	"ne_10m_urban_areas"

# ============================================================================
# PHYSICAL VECTORS (10m)
# ============================================================================

echo "=== Downloading Physical Vectors ==="

# Coastline
echo "--- Coastline ---"
download-ne "physical/ne_10m_coastline"
import "ne_coastline" \
	"/vsizip/natural_earth/physical/ne_10m_coastline.zip/ne_10m_coastline.shp" \
	"ne_10m_coastline"

# Land
echo "--- Land ---"
download-ne "physical/ne_10m_land"
import "ne_land" \
	"/vsizip/natural_earth/physical/ne_10m_land.zip/ne_10m_land.shp" \
	"ne_10m_land"

# Minor Islands
echo "--- Minor Islands ---"
download-ne "physical/ne_10m_minor_islands"
import "ne_minor_islands" \
	"/vsizip/natural_earth/physical/ne_10m_minor_islands.zip/ne_10m_minor_islands.shp" \
	"ne_10m_minor_islands"

# Reefs
echo "--- Reefs ---"
download-ne "physical/ne_10m_reefs"
import "ne_reefs" \
	"/vsizip/natural_earth/physical/ne_10m_reefs.zip/ne_10m_reefs.shp" \
	"ne_10m_reefs"

# Ocean
echo "--- Ocean ---"
download-ne "physical/ne_10m_ocean"
import "ne_ocean" \
	"/vsizip/natural_earth/physical/ne_10m_ocean.zip/ne_10m_ocean.shp" \
	"ne_10m_ocean"

# Rivers + Lake Centerlines
echo "--- Rivers + Lake Centerlines ---"
download-ne "physical/ne_10m_rivers_lake_centerlines"
import "ne_rivers_lake_centerlines" \
	"/vsizip/natural_earth/physical/ne_10m_rivers_lake_centerlines.zip/ne_10m_rivers_lake_centerlines.shp" \
	"ne_10m_rivers_lake_centerlines"

# Lakes and Reservoirs
echo "--- Lakes and Reservoirs ---"
download-ne "physical/ne_10m_lakes"
import "ne_lakes" \
	"/vsizip/natural_earth/physical/ne_10m_lakes.zip/ne_10m_lakes.shp" \
	"ne_10m_lakes"

# Physical Labels - Geography Regions Polygons
echo "--- Physical Labels (Areas) ---"
download-ne "physical/ne_10m_geography_regions_polys"
import "ne_geography_regions_polys" \
	"/vsizip/natural_earth/physical/ne_10m_geography_regions_polys.zip/ne_10m_geography_regions_polys.shp" \
	"ne_10m_geography_regions_polys"

# Physical Labels - Geography Regions Points
echo "--- Physical Labels (Points) ---"
download-ne "physical/ne_10m_geography_regions_points"
import "ne_geography_regions_points" \
	"/vsizip/natural_earth/physical/ne_10m_geography_regions_points.zip/ne_10m_geography_regions_points.shp" \
	"ne_10m_geography_regions_points"

# Playas
echo "--- Playas ---"
download-ne "physical/ne_10m_playas"
import "ne_playas" \
	"/vsizip/natural_earth/physical/ne_10m_playas.zip/ne_10m_playas.shp" \
	"ne_10m_playas"

# Bathymetry - Individual depth layers
echo "--- Bathymetry ---"

# Download and import each bathymetry layer individually
# 0m (L_0)
echo "--- Bathymetry 0m ---"
download-ne "physical/ne_10m_bathymetry_L_0"
import "ne_bathymetry_l_0" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_L_0.zip/ne_10m_bathymetry_L_0.shp" \
	"ne_10m_bathymetry_L_0"

# 200m (K_200)
echo "--- Bathymetry 200m ---"
download-ne "physical/ne_10m_bathymetry_K_200"
import "ne_bathymetry_k_200" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_K_200.zip/ne_10m_bathymetry_K_200.shp" \
	"ne_10m_bathymetry_K_200"

# 1,000m (J_1000)
echo "--- Bathymetry 1,000m ---"
download-ne "physical/ne_10m_bathymetry_J_1000"
import "ne_bathymetry_j_1000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_J_1000.zip/ne_10m_bathymetry_J_1000.shp" \
	"ne_10m_bathymetry_J_1000"

# 2,000m (I_2000)
echo "--- Bathymetry 2,000m ---"
download-ne "physical/ne_10m_bathymetry_I_2000"
import "ne_bathymetry_i_2000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_I_2000.zip/ne_10m_bathymetry_I_2000.shp" \
	"ne_10m_bathymetry_I_2000"

# 3,000m (H_3000)
echo "--- Bathymetry 3,000m ---"
download-ne "physical/ne_10m_bathymetry_H_3000"
import "ne_bathymetry_h_3000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_H_3000.zip/ne_10m_bathymetry_H_3000.shp" \
	"ne_10m_bathymetry_H_3000"

# 4,000m (G_4000)
echo "--- Bathymetry 4,000m ---"
download-ne "physical/ne_10m_bathymetry_G_4000"
import "ne_bathymetry_g_4000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_G_4000.zip/ne_10m_bathymetry_G_4000.shp" \
	"ne_10m_bathymetry_G_4000"

# 5,000m (F_5000)
echo "--- Bathymetry 5,000m ---"
download-ne "physical/ne_10m_bathymetry_F_5000"
import "ne_bathymetry_f_5000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_F_5000.zip/ne_10m_bathymetry_F_5000.shp" \
	"ne_10m_bathymetry_F_5000"

# 6,000m (E_6000)
echo "--- Bathymetry 6,000m ---"
download-ne "physical/ne_10m_bathymetry_E_6000"
import "ne_bathymetry_e_6000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_E_6000.zip/ne_10m_bathymetry_E_6000.shp" \
	"ne_10m_bathymetry_E_6000"

# 7,000m (D_7000)
echo "--- Bathymetry 7,000m ---"
download-ne "physical/ne_10m_bathymetry_D_7000"
import "ne_bathymetry_d_7000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_D_7000.zip/ne_10m_bathymetry_D_7000.shp" \
	"ne_10m_bathymetry_D_7000"

# 8,000m (C_8000)
echo "--- Bathymetry 8,000m ---"
download-ne "physical/ne_10m_bathymetry_C_8000"
import "ne_bathymetry_c_8000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_C_8000.zip/ne_10m_bathymetry_C_8000.shp" \
	"ne_10m_bathymetry_C_8000"

# 9,000m (B_9000)
echo "--- Bathymetry 9,000m ---"
download-ne "physical/ne_10m_bathymetry_B_9000"
import "ne_bathymetry_b_9000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_B_9000.zip/ne_10m_bathymetry_B_9000.shp" \
	"ne_10m_bathymetry_B_9000"

# 10,000m (A_10000)
echo "--- Bathymetry 10,000m ---"
download-ne "physical/ne_10m_bathymetry_A_10000"
import "ne_bathymetry_a_10000" \
	"/vsizip/natural_earth/physical/ne_10m_bathymetry_A_10000.zip/ne_10m_bathymetry_A_10000.shp" \
	"ne_10m_bathymetry_A_10000"

# Geographic Lines
echo "--- Geographic Lines ---"
download-ne "physical/ne_10m_geographic_lines"
import "ne_geographic_lines" \
	"/vsizip/natural_earth/physical/ne_10m_geographic_lines.zip/ne_10m_geographic_lines.shp" \
	"ne_10m_geographic_lines" \
	"false" \
	"true"

# ============================================================================
# POST-PROCESSING: Merge North America supplements with global datasets
# ============================================================================

echo "=== Post-Processing: Merging North America datasets ==="

# Merge Roads: Remove North America from global roads, then add detailed North America roads
echo "--- Merging Roads (Global + North America supplement) ---"
psql --quiet -d "$POSTGRES_MAPS_DB" <<-EOF
	-- Add any missing columns from North America supplement to base table
	DO \$\$
	DECLARE
		r RECORD;
	BEGIN
		FOR r IN
			SELECT column_name, data_type
			FROM information_schema.columns
			WHERE table_name = 'ne_roads_north_america'
			  AND column_name NOT IN (
				  SELECT column_name
				  FROM information_schema.columns
				  WHERE table_name = 'ne_roads'
			  )
		LOOP
			EXECUTE format('ALTER TABLE ne_roads ADD COLUMN IF NOT EXISTS %I %s', r.column_name, r.data_type);
		END LOOP;
	END \$\$;

	-- Delete North America roads from global dataset using continent field
	DELETE FROM ne_roads WHERE continent = 'North America';

	-- Insert North America roads with all columns (NULL for missing ones)
	DO \$\$
	DECLARE
		all_cols text;
		na_cols text;
	BEGIN
		-- Get all columns from the merged table (excluding id)
		SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
		INTO all_cols
		FROM information_schema.columns
		WHERE table_name = 'ne_roads'
		  AND column_name != 'id';

		-- Build SELECT with COALESCE for columns that might not exist in source
		SELECT string_agg(
			CASE
				WHEN column_name IN (SELECT column_name FROM information_schema.columns WHERE table_name = 'ne_roads_north_america')
				THEN column_name
				ELSE 'NULL AS ' || column_name
			END,
			', '
			ORDER BY ordinal_position
		)
		INTO na_cols
		FROM information_schema.columns
		WHERE table_name = 'ne_roads'
		  AND column_name != 'id';

		EXECUTE format('INSERT INTO ne_roads (%s) SELECT %s FROM ne_roads_north_america', all_cols, na_cols);
	END \$\$;

	-- Drop the North America supplement table as it's now merged
	DROP TABLE ne_roads_north_america;

	-- Reindex for optimal performance
	REINDEX TABLE ne_roads;
	ANALYZE ne_roads;
EOF

# Merge Railroads: Remove North America from global railroads, then add detailed North America railroads
echo "--- Merging Railroads (Global + North America supplement) ---"
psql --quiet -d "$POSTGRES_MAPS_DB" <<-EOF
	-- Add any missing columns from North America supplement to base table
	DO \$\$
	DECLARE
		r RECORD;
	BEGIN
		FOR r IN
			SELECT column_name, data_type
			FROM information_schema.columns
			WHERE table_name = 'ne_railroads_north_america'
			  AND column_name NOT IN (
				  SELECT column_name
				  FROM information_schema.columns
				  WHERE table_name = 'ne_railroads'
			  )
		LOOP
			EXECUTE format('ALTER TABLE ne_railroads ADD COLUMN IF NOT EXISTS %I %s', r.column_name, r.data_type);
		END LOOP;
	END \$\$;

	-- Delete North America railroads from global dataset using continent field
	DELETE FROM ne_railroads WHERE continent = 'North America';

	-- Insert North America railroads with all columns (NULL for missing ones)
	DO \$\$
	DECLARE
		all_cols text;
		na_cols text;
	BEGIN
		-- Get all columns from the merged table (excluding id)
		SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
		INTO all_cols
		FROM information_schema.columns
		WHERE table_name = 'ne_railroads'
		  AND column_name != 'id';

		-- Build SELECT with COALESCE for columns that might not exist in source
		SELECT string_agg(
			CASE
				WHEN column_name IN (SELECT column_name FROM information_schema.columns WHERE table_name = 'ne_railroads_north_america')
				THEN column_name
				ELSE 'NULL AS ' || column_name
			END,
			', '
			ORDER BY ordinal_position
		)
		INTO na_cols
		FROM information_schema.columns
		WHERE table_name = 'ne_railroads'
		  AND column_name != 'id';

		EXECUTE format('INSERT INTO ne_railroads (%s) SELECT %s FROM ne_railroads_north_america', all_cols, na_cols);
	END \$\$;

	-- Drop the North America supplement table as it's now merged
	DROP TABLE ne_railroads_north_america;

	-- Reindex for optimal performance
	REINDEX TABLE ne_railroads;
	ANALYZE ne_railroads;
EOF

echo "Done importing Natural Earth data."
