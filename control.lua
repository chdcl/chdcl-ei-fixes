if not script.active_mods["exotic-industries"] then
    return
end

-- EI expects only induction-matrix-core:0 to be placed
-- Replace any other core "tiers" with core:0 in blueprints and copy / paste
local matrix_core_pattern = "^ei_induction%-matrix%-core:"
local matrix_core_0 = "ei_induction-matrix-core:0"
script.on_event(defines.events.on_player_setup_blueprint, function(event)
    local blueprint_setup = game.get_player(event.player_index).blueprint_to_setup
    local cursor_stack = game.get_player(event.player_index).cursor_stack
    local blueprint = nil
    if blueprint_setup and blueprint_setup.valid_for_read then
        -- When player shift-copies
        blueprint = blueprint_setup
    elseif cursor_stack and cursor_stack.valid_for_read then
        -- When player copies without shift
        blueprint = cursor_stack
    else
        return
    end
    local entities = blueprint.get_blueprint_entities()
    if not entities then return end
    for _, entity in pairs(entities) do
        if string.match(entity.name, matrix_core_pattern) and entity.name ~= matrix_core_0 then
            entity.name = matrix_core_0
        end
    end
    blueprint.set_blueprint_entities(entities)
end)

local matrix_tile = "ei_induction-matrix-tile"
-- If a matrix core is built not on top of induction tile, deconstruct it
-- Otherwise it will get stuck in a non-functioning state 
-- Ideally there would be a construction request to rebuild it, but I don't know how
script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity
    if entity.name == matrix_core_0 then
        local missing_tile = false
        for x_offset = 0, 1 do
            for y_offset = 0, 1 do
                local tile_pos = {entity.position.x - x_offset, entity.position.y - y_offset}
                local tile = event.created_entity.surface.get_tile(tile_pos)
                missing_tile = missing_tile or tile.name ~= matrix_tile
            end            
        end
        if missing_tile then
            entity.order_deconstruction(entity.force)
        end        
    end    
end, {
    {filter = "name", name = matrix_core_0}
})
