-- ---------------------------------------------------------------------------
--
-- Theme: shortbread_v1
-- Topic: bridges
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

themepark:add_table{
    name = 'bridges',
    ids_type = 'area',
    geom = 'polygon',
    columns = themepark:columns('core/name', {
        { column = 'kind', type = 'text', not_null = true },
        { column = 'layer', type = 'int2', tiles = false },
    }),
    tags = {
        { key = 'man_made', value = 'bridge', on = 'a' },
    },
    tiles = {
        minzoom = 12,
    },
}

-- ---------------------------------------------------------------------------

themepark:add_proc('area', function(object, data)
    local t = object.tags

    if t.man_made == 'bridge' then
        local a = {
            kind = 'bridge',
            layer = data.core.layer
        }

        for sgeom in object:as_area():geometries() do
            a.geom = sgeom
            themepark:insert('bridges', a, t)
        end
    end
end)

-- ---------------------------------------------------------------------------
