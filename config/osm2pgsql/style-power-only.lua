-- ---------------------------------------------------------------------------
--
-- Shortbread theme with generalization
--
-- Configuration for the osm2pgsql Themepark framework
--
-- ---------------------------------------------------------------------------

-- Set these to true in order to create a config file
-- If you are creating a tilekiln config you must also create
-- the 'shortbread_config' directory.
local TREX = false
local BBOX = false
local TILEKILN = false
local TAGINFO = false

local themepark = require('themepark')

-- For debug mode set this or the environment variable THEMEPARK_DEBUG.
themepark.debug = true

-- Add JSONB column `tags` with original OSM tags in debug mode
themepark:set_option('tags', 'all_tags')

-- Set this to add a column 'id' with unique IDs (and corresponding unique
-- index). This is needed for instance when you want to edit the data in QGIS.
themepark:set_option('unique_id', 'id')

themepark:set_option('prefix', 'osm_')

-- ---------------------------------------------------------------------------
-- Choose which names from which languages to use in the map.
-- See 'themes/core/README.md' for details.

-- themepark:add_topic('core/name-single', { column = 'name' })
-- themepark:add_topic('core/name-list', { keys = {'name', 'name:de', 'name:en'} })

themepark:add_topic('core/name-with-fallback', {
    keys = {
        name = { 'name', 'name:en', 'name:de' },
        name_de = { 'name:de', 'name', 'name:en' },
        name_en = { 'name:en', 'name', 'name:de' },
    }
})

-- --------------------------------------------------------------------------

themepark:add_topic('core/layer')

themepark:add_topic('xweather_shortbread_v1/power')
