dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local processed_entities = {}
local debug_frame_count = 0
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

function debug_get_mouse_pos()
    return DEBUG_GetMouseWorld()
end

function debug_summary()
    if not IsDebugEnabled() then
        return
    end

    local count = 0
    for _ in pairs(processed_entities) do
        count = count + 1
    end

    log_debug("[SlowEnemies] ===== Debug Stats =====")
    log_debug(string.format("  Frames: %d", debug_frame_count))
    log_debug(string.format("  Slowed entities: %d", debug_entity_count))
    log_debug(string.format("  Slowed projectiles: %d", debug_projectile_count))
    log_debug(string.format("  Queue size: %d", count))
    log_debug("[SlowEnemies] =========================")
end

function reduce_enemy_velocity(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "Velocity")
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

    if IsDebugEnabled() then
        log_debug(string.format("[SlowEnemies] Slowed entity %d: (%.2f, %.2f) -> (%.2f, %.2f)",
            entity_id, vx, vy, vx * mult, vy * mult))
        debug_mark_entity(entity_id, "slow", 0, 1, 1)
    end
end

function reduce_projectile_speed(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "Projectile")
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

    if IsDebugEnabled() then
        log_debug(string.format("[SlowEnemies] Slowed projectile %d: [%.1f-%.1f] -> [%.1f-%.1f]",
            entity_id, speed_min, speed_max, speed_min * mult, speed_max * mult))
        debug_mark_entity(entity_id, "slow", 0, 1, 1)
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

    local comp = EntityGetFirstComponent(entity_id, "Projectile")
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

function process_entity(entity_id)
    if not IsEnabled() then
        return
    end

    if processed_entities[entity_id] then
        return
    end

    if is_enemy_entity(entity_id) then
        reduce_enemy_velocity(entity_id)
        processed_entities[entity_id] = true
    elseif is_enemy_projectile(entity_id) then
        reduce_projectile_speed(entity_id)
        processed_entities[entity_id] = true
    end
end

function debug_update_screen()
    if not IsDebugEnabled() then
        return
    end

    debug_frame_count = debug_frame_count + 1

    if debug_print_cooldown > 0 then
        debug_print_cooldown = debug_print_cooldown - 1
        return
    end

    if debug_frame_count % 60 == 0 then
        local mx, my = debug_get_mouse_pos()

        local count = 0
        for _ in pairs(processed_entities) do
            count = count + 1
        end

        local status = string.format(
            "[SlowEnemies] frm:%d m:(%.0f,%.0f) e:%d p:%d q:%d",
            debug_frame_count, mx or 0, my or 0,
            debug_entity_count, debug_projectile_count, count
        )
        screen_debug(status)
        debug_print_cooldown = 60
    end
end

function OnEntityCreated(entity_id)
    GameScheduleFunction(function()
        if EntityExists(entity_id) then
            process_entity(entity_id)
        end
    end, {}, 1)
end

function OnEntityDestroyed(entity_id)
    processed_entities[entity_id] = nil
end

function Update()
    if not IsEnabled() then
        return
    end

    local entities = EntityGetAll()
    for _, entity_id in ipairs(entities) do
        process_entity(entity_id)
    end

    if GameGetFrameNum() % 300 == 0 then
        cleanup_processed_list()
    end

    debug_update_screen()
end

function cleanup_processed_list()
    local to_remove = {}
    for entity_id, _ in pairs(processed_entities) do
        if not EntityExists(entity_id) then
            table.insert(to_remove, entity_id)
        end
    end
    for _, entity_id in ipairs(to_remove) do
        processed_entities[entity_id] = nil
    end
end

function ModMain()
    LoadConfig()

    if GameHasFlagRun(MOD_INIT_FLAG) then
        return
    end
    GameAddFlagRun(MOD_INIT_FLAG)

    print("[SlowEnemies] Mod loaded")
    print(string.format("  Enemy speed: %.2f", GetEnemySpeedMultiplier()))
    print(string.format("  Projectile speed: %.2f", GetProjectileSpeedMultiplier()))

    if IsDebugEnabled() then
        print("[SlowEnemies] Debug mode enabled")
        print("  - Console: detailed logs")
        print("  - Screen: status every 60 frames")
        print("  - World: slowed entities marked cyan")
    end
end
