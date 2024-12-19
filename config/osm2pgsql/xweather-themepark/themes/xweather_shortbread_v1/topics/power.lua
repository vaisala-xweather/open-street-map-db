-- ---------------------------------------------------------------------------
--
-- Theme: experimental
-- Topic: power
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

themepark:add_table{
    name = 'power_generators',
    ids_type = 'node',
    geom = 'point',
    columns = themepark:columns('core/name', {
        { column = 'energy_source', type = 'text' },
        { column = 'solar_tracking', type = 'text' },
    })
}

themepark:add_table{
    name = 'power_lines',
    ids_type = 'way',
    geom = 'linestring',
    columns = themepark:columns({
        { column = 'voltage', type = 'int' },
        { column = 'frequency', type = 'int' },
        { column = 'cables', type = 'int' },
        { column = 'operator', type = 'text' },
        { column = 'operator_wikidata', type = 'text' },
    })
}

themepark:add_table{
    name = 'power_plants',
    ids_type = 'area',
    geom = 'multipolygon',
    columns = themepark:columns('core/name', {
        { column = 'energy_source', type = 'text' },
        { column = 'operator', type = 'text' },
        { column = 'method', type = 'text' },
        { column = 'output_power', type = 'text' },
    })
}

themepark:add_proc('node', function(object, data)
    if object.tags.power == 'generator' then
        local a = {
            geom = object:as_point()
        }

        themepark.themes.core.add_name(a, object)

        local source = object.tags['generator:source']
        if source ~= nil and source:find(';') then
            source = nil
        end
        a.energy_source = source

        a.solar_tracking = object.tags['generator:solar:tracking']

        themepark:insert('power_generators', a, object.tags)
    end
end)

themepark:add_proc('way', function(object, data)
    if object.tags.power == 'line' then
        local a = {
            geom = object:as_linestring(),
            voltage = object.tags.voltage,
            frequency = object.tags.frequency,
            cables = object.tags.cables,
            operator = object.tags.operator,
            operator_wikidata = object.tags['operator:wikidata'],
        }
        themepark:insert('power_lines', a, object.tags)
    end
end)

themepark:add_proc('area', function(object, data)
    if object.tags.power == 'plant' then
        local a = {
            geom = object:as_area()
        }

        themepark.themes.core.add_name(a, object)

        local source = object.tags['plant:source']
        if source ~= nil and source:find(';') then
            source = nil
        end
        a.energy_source = source
        a.operator = object.tags.operator
        a.method = object.tags['plant:method']
        a.output_power = object.tags['plant:output:electricity']

        themepark:insert('power_plants', a, object.tags)
    end
end)

