dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local debug_entity_count = 0
local debug_projectile_count = 0
local debug_print_cooldown = 0
local processed_entities = {}

function get_players()
    return EntityGetWithTag("player_unit")
end

function is_player_entity(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end

    local players = get_players()
    if players ~= nil then
        for _, player_id in ipairs(players) do
            if player_id == entity_id then
                return true
            end
        end
    end

    return false
end

function is_player_projectile(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if comp == nil then
        return false
    end

    local shooter = ComponentGetValue2(comp, "mWhoShot")
    if shooter ~= nil and shooter ~= 0 then
        return is_player_entity(shooter)
    end

    return false
end

function slow_enemy(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "VelocityComponent")
    if comp == nil then
        return
    end

    local mult = GetEnemySpeedMultiplier()
    if mult >= 1.0 then
        return
    end

    local vx, vy = ComponentGetValue2(comp, "mVelocity")
    if vx == nil or vy == nil then
        return
    end

    ComponentSetValue2(comp, "mVelocity", vx * mult, vy * mult)

    if not processed_entities[entity_id] then
        processed_entities[entity_id] = true
        debug_entity_count = debug_entity_count + 1
        print(string.format("[SlowEnemies] Slowed enemy %d", entity_id))
    end
end

function slow_projectile(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if comp == nil then
        return
    end

    local mult = GetProjectileSpeedMultiplier()
    if mult >= 1.0 then
        return
    end

    local speed_min = ComponentGetValue2(comp, "speed_min")
    local speed_max = ComponentGetValue2(comp, "speed_max")

    if speed_min == nil or speed_max == nil then
        return
    end

    ComponentSetValue2(comp, "speed_min", speed_min * mult)
    ComponentSetValue2(comp, "speed_max", speed_max * mult)

    if not processed_entities[entity_id] then
        processed_entities[entity_id] = true
        debug_projectile_count = debug_projectile_count + 1
        print(string.format("[SlowEnemies] Slowed projectile %d", entity_id))
    end
end

function process_enemies()
    if not IsEnabled() then
        return
    end

    -- Get all enemies
    local enemies = EntityGetWithTag("enemy")
    if enemies ~= nil then
        for _, entity_id in ipairs(enemies) do
            if not is_player_entity(entity_id) then
                slow_enemy(entity_id)
            end
        end
    end

    -- Also check mortal tagged entities (many enemies have this)
    local mortals = EntityGetWithTag("mortal")
    if mortals ~= nil then
        for _, entity_id in ipairs(mortals) do
            if not is_player_entity(entity_id) and not EntityHasTag(entity_id, "item") then
                slow_enemy(entity_id)
            end
        end
    end
end

function process_projectiles()
    if not IsEnabled() then
        return
    end

    -- Get all projectiles
    local projectiles = EntityGetWithTag("projectile")
    if projectiles ~= nil then
        for _, entity_id in ipairs(projectiles) do
            if not is_player_projectile(entity_id) then
                slow_projectile(entity_id)
            end
        end
    end
end

function debug_update_screen()
    debug_print_cooldown = debug_print_cooldown + 1

    if debug_print_cooldown >= 60 then
        debug_print_cooldown = 0

        local mx, my = DEBUG_GetMouseWorld()
        local players = get_players()
        local px, py = 0, 0
        if players and #players > 0 then
            local ppos = EntityGetTransform(players[1])
            if ppos then
                px, py = ppos, ppos
            end
        end

        local status = string.format(
            "[SlowEnemies] e:%d p:%d m:(%.0f,%.0f)",
            debug_entity_count, debug_projectile_count, mx or 0, my or 0
        )
        GamePrint(status)
    end
end

function ModMain()
    LoadConfig()

    print("[SlowEnemies] Mod initializing...")

    if GameHasFlagRun(MOD_INIT_FLAG) then
        print("[SlowEnemies] Already initialized, skipping")
        return
    end
    GameAddFlagRun(MOD_INIT_FLAG)

    print("[SlowEnemies] Mod loaded successfully")
    print(string.format("  Enemy speed: %.2f", GetEnemySpeedMultiplier()))
    print(string.format("  Projectile speed: %.2f", GetProjectileSpeedMultiplier()))
    print(string.format("  Enabled: %s", tostring(IsEnabled())))
end

-- Hook functions
function OnModPreInit()
    ModMain()
end

function OnModInit()

end

function OnModPostInit()

end

function OnPlayerSpawned(player_entity)

end

function OnWorldInitialized()

end

function OnWorldPreUpdate()
    process_enemies()
    process_projectiles()
    debug_update_screen()
end

function OnWorldPostUpdate()

end
