# Open Street Map Import

Creating base maps for Weather data visualization

## Motivation

We have some specific needs for when various data sets are shown to users. Those are:

1. Roads at a lower zoom (more zoomed out) - Vaisala Xweather provides best in the world road weather modeling and having
an overview available in a map is beneficial
1. Electrical Infrastructure - We help protect and model various parts of energy infrastructure and we need to show this
information in a visual way.
1. Provide a way to create high-resolution spatial subsets of data. For example, from zoom 8 to 14 for a specific area.
1. Import other data sets with different licensing, like Natural Earth

## Key Concepts

Following our standard Xweather approach - how can we make data make sense at each processing step?

1. Importing data into Postgres
    1. Prefix data with source ID like `osm_`, `natearth_`, etc
    1. Analyze data - use the `THEMEPARK_DEBUG=on` flag to import all properties into the DB into an `HSTORE` [type hash column](https://www.postgresql.org/docs/current/hstore.html) (all keys and values are strings! Value can be NULL)
        1. For each database, iterate over each key/value pair in the tags HSTORE column and run stats on it - # of unique values, number of nulls, top 10 frequent values
    1. Iterate and decide which values to store directly in the DB for this application
1. Create QGIS viewing style to view all layers and properties
1. Create Tegola views for each use case
1. Run pmtiles import to pull from Tegola and create an output pmtiles for the map.

Under the hood, this is a relational Postgres database. Features with different values we want to keep, need to go into
different tables. When querying features back out, we can transform that data further, only selecting what we want at
each step.

## Tools

There are a lot of tools, we have found:

1. **osm2pgsql** - Seemingly recommended by Open Street Maps group, imports data to a postgres database. This is great because it separates data import and tile generation steps.
1. planetiler - A large java project that dumps directly to pmtiles. It's fast, goes right into tiles
    1. pmtiles uses this for their generation <https://github.com/protomaps/basemaps>
1. imposm3 - Dies during large global imports, has Go segfaults

### Tile Schemas

OpenStreetMap data can be presented in any way, it's just polygons, lines, and points with metadata. There are some existing
conventions on how to present that data, however:

1. [OpenMapTiles Layer Schema (OMT)](https://openmaptiles.org/schema/)
    1. Layer list:
        1. `aerodrome_label`
        1. `aeroway`
        1. `boundary`
        1. `building`
        1. `globallandcover`
        1. `housenumber`
        1. `landcover`
        1. `landuse`
        1. `mountain_peak`
        1. `park`
        1. `place`
        1. `poi`
        1. `transportation`
        1. `transportation_name`
        1. `water`
        1. `water_name`
        1. `waterway`
    1. An example Tegola file: <https://github.com/dechristopher/tegola-omt/blob/master/config.toml>
    1. Seth's Opinion
        1. things they do well:
            1. Water stuff - putting together oceans + lakes, separating out streams into waterway
            1. landcover and landuse - see https://oceanservice.noaa.gov/facts/lclu.html
            1. aeroway is everything airports/heliports
            1. globallandcover is a nice zoomed out representation of forest, scrub, farmland
            1. mountainpeak - Ridges and points identifying mountain features
            1. Names for busy layers, like transportation, are separated into a different layer
        1. sillythings
            1. housenumber is a bad name, it's addresses
            1. aerowaydromes (airport areas) are really landuse aeren't they?
            1. parks should be landuse
            1. mountain_peak could be a sub type in poi
            1. Place vs poi is confusing

1. [Tilezen Vector Tile Format](https://tilezen.readthedocs.io/en/latest/layers/)
    1. This is a popular format like on [Pmtiles' Demo Page](https://pmtiles.io/?url=https%3A%2F%2Fdata.source.coop%2Fprotomaps%2Fopenstreetmap%2Fv4.pmtiles#map=10.38/44.8707/-93.2188)

1. [Shortbread Layer Standard v1](https://shortbread-tiles.org/schema/1.0/)
    1. This is a published spec of how the data is separated and layered, a spec is better than no spec.
    1. Seth's Opinion - These guys split all sorts of things in kind of weird ways...

1. [Mapbox Streets](https://github.com/mapbox/mapbox-gl-styles/blob/master/styles/streets-v12.json)
    1. Layer List:
        1. admin
        1. aeroway
        1. airport_label
        1. building
        1. depth
        1. hillshade
        1. housenum_label
        1. landcover
        1. landuse
        1. landuse_overlay - Just national-park
        1. motorway_junction
        1. natural_label
        1. place_label
        1. poi_label
        1. road
        1. structure
        1. transit_stop_label
        1. water
        1. waterway

### Additional tools

1. Tegola - Query for layers from a postgis database and organize layers


## Running/Importing/Generating Data

`docker compose` is used heavily to run these steps.

> [!WARNING]
> You probably want ~1TB of disk space free to do a full planet import

1. `./util/import` runs the import of OSM data (and friends) into Postgres using osm2pgsql
    1. START ON A NON-GLOBAL EXTRACT TO TEST EVERYTHING FIRST
    1. Imports all the secondary data sets for borders and oceans (import-extra)
         1. Import extra may get stuck sometimes and we need to just delete the source zip files and try again. For some reason they   have state.
    1. Imports main OSM data set into Postgres
    1. Use `--help` to see options to skip if you want to do only parts of the import
    1. It will block on `Storing properties to table '"public"."osm2pgsql_properties"'.` for HOURS.
        1. As this runs, you can use `./util/import-status` to see progress.
1. `./util/generate-tiles` runs Tegola to generate pmtiles from the Postgres data
    1. This uses a `tegola` tile server to pull data from Postgres using SQL queries for different layers
    1. This also uses a file cache for the tiles - we query all the tiles we want and let the tile cache store them
    1. Then we take all the files in the tile cache and turn it into a mbtiles sqlite file
    1. Finally we convert that to pmtiles


## TODO

* Make a gen for larger buildings
* Make a gen for sites
* Move terminal to buildings
* Move aerodrome pavements and stuff to "land", taxiways and stuff
