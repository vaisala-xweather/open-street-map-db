-- ---------------------------------------------------------------------------
--
-- Theme: shortbread_v1
-- Topic: streets
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

themepark:add_table{
    name = 'aeroways',
    ids_type = 'way',
    geom = 'linestring',
    columns = themepark:columns('core/name', {
        { column = 'kind', type = 'text', not_null = true },
        -- Aeroway specific
        { column = 'length', type = 'real'},
        { column = 'width', type = 'real'},
        -- Common
        { column = 'layer', type = 'int', not_null = true },
        { column = 'ref', type = 'text' },
        { column = 'z_order', type = 'int' },
        { column = 'minzoom', type = 'int', tiles = 'minzoom' },
    }),
    tags = {

    },
    tiles = {
        minzoom = 10,
        order_by = 'z_order',
        order_dir = 'asc',
    },
}

themepark:add_table{
    name = 'aeroways_polygons',
    ids_type = 'area',
    geom = 'polygon',
    columns = themepark:columns('core/name', {
        { column = 'kind', type = 'text', not_null = true },
        -- Aeroway specific
        { column = 'length', type = 'real'},
        { column = 'width', type = 'real'},
        -- Common
        { column = 'layer', type = 'int', not_null = true },
        { column = 'ref', type = 'text' },
        { column = 'z_order', type = 'int' },
        { column = 'minzoom', type = 'int', tiles = 'minzoom' },
    }),
    tags = {

    },
    tiles = {
        minzoom = 10,
        order_by = 'z_order',
        order_dir = 'asc',
    },
}


-- XXX There is some duplication here, because many of the entries in 'streets'
--     are also in this table.
themepark:add_table{
    name = 'aeroways_labels',
    ids_type = 'way',
    geom = 'linestring',
    columns = themepark:columns('core/name', {
        { column = 'kind', type = 'text', not_null = true },
        { column = 'layer', type = 'int', not_null = true },
        { column = 'ref', type = 'text' },
        { column = 'z_order', type = 'int' },
        { column = 'minzoom', type = 'int', tiles = 'minzoom' },
    }),
    tiles = {
        minzoom = 10,
        order_by = 'z_order',
        order_dir = 'asc',
    },
}

-- Sites: Aerodromes
-- A specific site for airports and airfields.
themepark:add_table{
    name = 'sites_aerodromes',
    ids_type = 'area',
    geom = 'geometry',
    columns = themepark:columns('core/name', {
        { column = 'kind', type = 'text', not_null = true },
        -- Aerodrome specific
        { column = 'closest_town', type = 'text'},
        { column = 'elevation', type = 'real'},
        { column = 'iata', type = 'text'},
        { column = 'icao', type = 'text'},
        { column = 'operator', type = 'text'},
        -- Common
        { column = 'layer', type = 'int', not_null = true },
        { column = 'minzoom', type = 'int', tiles = 'minzoom' },

    }),
    tags = {
    },
    tiles = {
        minzoom = 12,
        simplify = false,
    },
}

-- ---------------------------------------------------------------------------

local Z_STEP_PER_LAYER = 100

local aeroway_lookup = {
    runway  = 11,
    taxiway = 13,
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
themepark:add_proc('area', function(object, data)
    local t = object.tags
    if not t.aeroway == 'aerodrome' then
        return
    end
    local a = {
        geom = object:as_area(),
        layer = data.core.layer,
        minzoom = 10,
    }
    a.kind = t.aeroway
    a.closest_town = t.closest_town
    a.elevation = t.ele or t.elevation
    a.iata = t.iata
    a.icao = t.icao
    a.operator = t.operator

    if a.kind then
        themepark:insert('sites_aerodromes', a, t)
    end
end)

local process_as_area = function(object, data)
    if not object.is_closed then
        return
    end

    local t = object.tags
    local a = {
        layer = data.core.layer,
    }
    a.z_order = Z_STEP_PER_LAYER * a.layer

    if t.highway == 'pedestrian' or t.highway == 'service' then
        a.kind = t.highway
    elseif t.aeroway == 'runway' or t.aeroway == 'taxiway' then
        a.kind = t.aeroway
    else
        return
    end

    a.surface = t.surface

    a.tunnel = as_bool(t.tunnel) or t.tunnel == 'building_passage' or t.covered == 'yes'
    a.bridge = as_bool(t.bridge)

    a.geom = object:as_polygon():transform(3857)
    local has_name = themepark.themes.core.add_name(a, object)
    themepark:insert('aeroways_polygons', a, t)

    -- if has_name then
    --     a.geom = a.geom:pole_of_inaccessibility()
    --     themepark:insert('streets_polygons_labels', a, t)
    -- end
end

themepark:add_proc('way', function(object, data)
    local t = object.tags
    if not t.aeroway then
        return
    end
    if t.area == 'yes' then
        process_as_area(object, data)
        return
    end

    local a = {
        layer = data.core.layer,
    }

    local awinfo = aeroway_lookup[t.aeroway]
    if not awinfo then
        return
    end
    a.kind = t.aeroway
    a.length = t.length
    a.width = t.width
    a.z_order = Z_STEP_PER_LAYER * a.layer
    a.minzoom = awinfo

    set_ref_attributes(a, t)

    a.geom = object:as_linestring()

    themepark.themes.core.add_name(a, object)
    themepark:insert('aeroways', a, t)

    if a.name or a.ref then
        themepark:insert('aeroways_labels', a, t)
    end
end)

-- ---------------------------------------------------------------------------
