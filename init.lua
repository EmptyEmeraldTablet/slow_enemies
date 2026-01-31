dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local world_initialized = false
local player_entity = nil
local slow_field_entity = nil

function ModMain()
    LoadConfig()
    print(string.format("[%s] Mod initialized", MOD_NAME))
end

function OnModPreInit()
    ModMain()
end

function OnModInit()
end

function OnModPostInit()
end

function OnPlayerSpawned(p_entity)
    player_entity = p_entity

    local x, y = EntityGetTransform(p_entity)
    slow_field_entity = EntityLoad("mods/slow_enemies/files/entities/slow_field.xml", x, y)
end

function OnWorldInitialized()
    world_initialized = true
end

function OnWorldPreUpdate()
    if not world_initialized then
        return
    end

    if slow_field_entity and player_entity and EntityGetIsAlive(player_entity) then
        local px, py = EntityGetTransform(player_entity)
        EntitySetTransform(slow_field_entity, px, py)
    end
end

function OnWorldPostUpdate()
end
