# Open Street Map Import

Following our standard Xweather approach - how can we make data work and make sense at each processing step?

## Motivation

We have some specific needs for when various data sets are shown to users. Those are:

1. Roads at a lower zoom (more zoomed out) - Vaisala Xweather provides best in the world road weather modeling and having
an overview available in a map is beneficial
1. Electrical Infrastructure - We help protect and model various parts of energy infrastructure and we need to show this
information in a visual way.

## Tools

There are a lot of tools, we have found:

1. **osm2pgsql** - Seemingly recommended by Open Street Maps group, imports data to a postgres database
1. planetiler - A large java project that dumps directly to pmtiles.
1. imposm3 - Dies during large global imports, has Go segfaults

Additional tools

1. [Shortbread Layer Standard v1](https://shortbread-tiles.org/schema/1.0/)
    1. This is a published spec of how the data is separated and layered, a spec is better than no spec.

1. Tegola - Query for layers from a postgis database and organize layers


## TODO

* Make a gen for larger buildings
* Make a gen for sites
* Move terminal to buildings
* Move aerodrome pavements and stuff to "land", taxiways and stuff
