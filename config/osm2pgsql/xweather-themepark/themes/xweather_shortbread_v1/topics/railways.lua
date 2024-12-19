-- ---------------------------------------------------------------------------
--
-- Theme: shortbread_v1
-- Topic: streets
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

themepark:add_table{
    name = 'railways',
    ids_type = 'way',
    geom = 'linestring',
    columns = themepark:columns('core/name', {
        { column = 'kind', type = 'text', not_null = true },
        -- Railway specific
        { column = 'bridge', type = 'bool', not_null = true },
        { column = 'electrified', type = 'text' },
        { column = 'gauge', type = 'int' },
        { column = 'max_speed', type = 'text' },
        { column = 'oneway_reverse', type = 'bool' },
        { column = 'oneway', type = 'bool' },
        { column = 'operator', type = 'text' },
        { column = 'service', type = 'text' },
        { column = 'tunnel', type = 'bool', not_null = true },
        { column = 'usage', type = 'text' },
        { column = 'voltage', type = 'int' },
        -- Common
        { column = 'layer', type = 'int', not_null = true },
        { column = 'ref', type = 'text' },
        { column = 'z_order', type = 'int' },
        { column = 'minzoom', type = 'int', tiles = 'minzoom' },
    }),
    tags = {
        { key = 'bridge', value = 'yes', on = 'w' },
        { key = 'layer', on = 'w' },
        { key = 'railway', on = 'w' },
        { key = 'ref', on = 'w' },
        { key = 'service', on = 'w' },
        { key = 'tracktype', on = 'w' },
        { key = 'tunnel', values = { 'yes', 'building_passage' } , on = 'w' },
    },
    tiles = {
        minzoom = 14,
        order_by = 'z_order',
        order_dir = 'asc',
    },
}

-- XXX There is some duplication here, because many of the entries in 'streets'
--     are also in this table.
themepark:add_table{
    name = 'railway_labels',
    ids_type = 'way',
    geom = 'linestring',
    columns = themepark:columns('core/name', {
        { column = 'kind', type = 'text', not_null = true },
        { column = 'layer', type = 'int', not_null = true },
        { column = 'z_order', type = 'int' },
        { column = 'minzoom', type = 'int', tiles = 'minzoom' },
    }),
    tiles = {
        minzoom = 14,
        order_by = 'z_order',
        order_dir = 'asc',
    },
}

themepark:add_table{
    name = 'railways_low',
    ids_type = 'way',
    geom = 'linestring',
    columns = themepark:columns({
        { column = 'kind', type = 'text', not_null = true },
        { column = 'ref', type = 'text' },
        { column = 'rail', type = 'bool' },
        { column = 'z_order', type = 'int' },
        { column = 'minzoom', type = 'int', tiles = 'minzoom' },
    }),
    tiles = {
        minzoom = 5,
        maxzoom = 10,
        group = 'railways',
        order_by = 'z_order',
        order_dir = 'asc',
    },
}

-- ---------------------------------------------------------------------------

local Z_STEP_PER_LAYER = 100

local railway_lookup = {
    rail            = { 52,  8 },
    narrow_gauge    = { 51,  8 },
    tram            = { 51, 10 },
    light_rail      = { 51, 10 },
    funicular       = { 51, 10 },
    subway          = { 51, 10 },
    monorail        = { 51, 10 },
}

local as_bool = function(value)
    return value == 'yes' or value == 'true' or value == '1'
end

local set_ref_attributes = function(a, t)
    if not t.ref then
        return
    end

    local refs = {}
    local rows = 0
    local cols = 0

    for word in string.gmatch(t.ref, "([^;]+);?") do
        word = word:gsub('^[%s]+', '', 1):gsub('[%s]+$', '', 1)
        rows = rows + 1
        cols = math.max(cols, string.len(word))
        table.insert(refs, word)
    end

    a.ref = table.concat(refs, '\n')
    a.ref_rows = rows
    a.ref_cols = cols
end

-- ---------------------------------------------------------------------------

themepark:add_proc('way', function(object, data)
    local t = object.tags
    -- Exit if not a railway
    if not t.railway then
        return
    end

    local a = {
        oneway = false,
        oneway_reverse = false,
        layer = data.core.layer
    }

    local rwinfo = railway_lookup[t.railway]
    if not rwinfo then
        return
    end
    a.kind = t.railway
    -- Railway specific
    a.bridge = as_bool(t.bridge)
    a.electrified = t.electrified
    a.gauge = t.gauge
    a.max_speed = t.maxspeed
    a.oneway = as_bool(t.oneway)
    a.oneway_reverse = as_bool(t.oneway_reverse)
    a.operator = t.operator
    a.service = t.service
    a.tunnel = as_bool(t.tunnel) or t.tunnel == 'building_passage' or t.covered == 'yes'
    a.voltage = t.voltage
    -- Common
    a.z_order = Z_STEP_PER_LAYER * a.layer + rwinfo[1]
    a.minzoom = rwinfo[2]
    if a.minzoom == 8 and t.service then
        a.minzoom = 10
        a.z_order = a.z_order - 2
    end


    set_ref_attributes(a, t)

    a.geom = object:as_linestring()

    themepark.themes.core.add_name(a, object)
    themepark:insert('railways', a, t)

    if a.name or a.ref then
        themepark:insert('railway_labels', a, t)
    end

    if a.minzoom < 10 then -- XXX TODO some kind of off-by-one error here?
        themepark:insert('railways_low', a, t)
    end
end)

-- ---------------------------------------------------------------------------
