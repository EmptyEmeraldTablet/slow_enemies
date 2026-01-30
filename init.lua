dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local world_initialized = false
local player_entity = nil
local slow_field_entity = nil

function is_player(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end
    return EntityHasTag(entity_id, "player_unit")
end

function ModMain()
    LoadConfig()

    print("========================================")
    print(string.format("[%s] Mod initializing...", MOD_NAME))
    print(string.format("  Enemy speed: %.2f", GetEnemySpeedMultiplier()))
    print(string.format("  Projectile speed: %.2f", GetProjectileSpeedMultiplier()))
    print("  Mode: Slow Field around player")
    print("========================================")
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

    print(string.format("[%s] Created slow field at (%.0f, %.0f)", MOD_NAME, x, y))
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
