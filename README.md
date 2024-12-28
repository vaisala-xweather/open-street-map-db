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
1. Importing OSM data into Postgres

Under the hood, this is a Postgres database. Features with different values we want to keep, need to go into different
tables. When querying features back out, we can transform that data further, only selecting what we want at each step.

## Tools

There are a lot of tools, we have found:

1. **osm2pgsql** - Seemingly recommended by Open Street Maps group, imports data to a postgres database
1. planetiler - A large java project that dumps directly to pmtiles. It's fast, goes right into tiles
    1. pmtiles uses this for their generation https://github.com/protomaps/basemaps
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
    1. An example Tegola file: https://github.com/dechristopher/tegola-omt/blob/master/config.toml
    1. Seth's Opinion
        1. things they do well:
            1. Water stuff - putting together oceans + lakes, separating out streams into waterway
            1. landcover and landuse
            1. aeroway is everything airports/heliports
            1. globallandcover is a nice zoomed out representation of forest, scrub, farmland
            1. mountainpeak - Ridges and points identifying mountain features
            1. Names for busy layers, like transportation, are separated into a different layer
        1. sillythings
            1. housenumber is a bad name, it's addresses
            1. aerowaydromes (airport areas) are really landuse aeren't they?
            1. parks should be landuse

1. [Tilezen Vector Tile Format](https://tilezen.readthedocs.io/en/latest/layers/)
    1. This is a popular format like on [Pmtiles' Demo Page](https://pmtiles.io/?url=https%3A%2F%2Fdata.source.coop%2Fprotomaps%2Fopenstreetmap%2Fv4.pmtiles#map=10.38/44.8707/-93.2188)

1. [Shortbread Layer Standard v1](https://shortbread-tiles.org/schema/1.0/)
    1. This is a published spec of how the data is separated and layered, a spec is better than no spec.
    1. Seth's Opinion - These guys split things in kind of weird ways...

### Additional tools

1. Tegola - Query for layers from a postgis database and organize layers


## TODO

* Make a gen for larger buildings
* Make a gen for sites
* Move terminal to buildings
* Move aerodrome pavements and stuff to "land", taxiways and stuff
