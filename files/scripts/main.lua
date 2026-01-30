dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local processed_entities = {}
local debug_entity_count = 0
local debug_projectile_count = 0
local debug_print_cooldown = 0

function log_debug(message)
    if IsDebugEnabled() then
        print(message)
    end
end

function screen_debug(message)
    if IsDebugEnabled() then
        GamePrint(message)
    end
end

function debug_mark_entity(entity_id, message, r, g, b)
    if IsDebugEnabled() then
        local x, y = EntityGetTransform(entity_id)
        if x ~= nil and y ~= nil then
            DEBUG_MARK(x, y, message, r or 0, g or 1, b or 1)
        end
    end
end

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

function is_enemy_entity(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end

    if is_player_entity(entity_id) then
        return false
    end

    if EntityHasTag(entity_id, "enemy") then
        return true
    end
    if EntityHasTag(entity_id, "mortal") then
        return true
    end
    if EntityHasTag(entity_id, "character") then
        return true
    end

    return false
end

function is_enemy_projectile(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end

    local comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if comp == nil then
        return false
    end

    local shooter = ComponentGetValue2(comp, "mWhoShot")
    if shooter ~= nil and shooter ~= 0 then
        if is_player_entity(shooter) then
            return false
        end
    end

    return true
end

function reduce_enemy_velocity(entity_id)
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

    debug_entity_count = debug_entity_count + 1
end

function reduce_projectile_speed(entity_id)
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

    debug_projectile_count = debug_projectile_count + 1
end

function process_entity(entity_id)
    if not IsEnabled() then
        return
    end

    if is_enemy_entity(entity_id) then
        reduce_enemy_velocity(entity_id)
    elseif is_enemy_projectile(entity_id) then
        reduce_projectile_speed(entity_id)
    end
end

function debug_update_screen()
    if not IsDebugEnabled() then
        return
    end

    debug_print_cooldown = debug_print_cooldown + 1

    if debug_print_cooldown >= 60 then
        debug_print_cooldown = 0

        local mx, my = DEBUG_GetMouseWorld()

        local status = string.format(
            "[SlowEnemies] e:%d p:%d m:(%.0f,%.0f)",
            debug_entity_count, debug_projectile_count, mx or 0, my or 0
        )
        screen_debug(status)
    end
end

-- Public hook functions (called from init.lua)
function _OnEntityCreated(entity_id)
    process_entity(entity_id)
end

function _OnEntityDestroyed(entity_id)
    processed_entities[entity_id] = nil
end

function _Update()
    if not IsEnabled() then
        return
    end

    debug_update_screen()

    if GameGetFrameNum() % 300 == 0 then
        if IsDebugEnabled() then
            print(string.format("[SlowEnemies] Frame %d: processed %d entities, %d projectiles",
                GameGetFrameNum(), debug_entity_count, debug_projectile_count))
        end
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

    if IsDebugEnabled() then
        print("[SlowEnemies] Debug mode enabled")
    end
end
