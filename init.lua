dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local debug_count = 0
local debug_print_cooldown = 0
local world_initialized = false

-- Track entities that have been successfully modified
local modified_entities = {}

function get_players()
    return EntityGetWithTag("player_unit")
end

function is_player_entity(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end
    local players = get_players()
    if players ~= nil then
        for _, pid in ipairs(players) do
            if pid == entity_id then
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
    if EntityHasTag(entity_id, "mortal") and not EntityHasTag(entity_id, "item") then
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

function get_component_fields(comp, fields)
    local results = {}
    for _, field in ipairs(fields) do
        local val = ComponentGetValue2(comp, field)
        results[field] = val
    end
    return results
end

function modify_enemy_platforming(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "CharacterPlatformingComponent")
    if comp == nil then
        return false
    end

    local speed_mult = GetEnemySpeedMultiplier()
    local accel_mult = GetEnemyAccelMultiplier()

    local modified = false

    -- Get current values
    local run_vel = ComponentGetValue2(comp, "run_velocity")
    local max_vel_x = ComponentGetValue2(comp, "velocity_max_x")
    local accel_x = ComponentGetValue2(comp, "accel_x")
    local fly_vel_x = ComponentGetValue2(comp, "fly_velocity_x")

    -- Only modify if values are reasonable (not 0)
    if run_vel and run_vel > 1 then
        ComponentSetValue2(comp, "run_velocity", run_vel * speed_mult)
        modified = true
    end

    if max_vel_x and math.abs(max_vel_x) > 1 then
        ComponentSetValue2(comp, "velocity_max_x", max_vel_x * speed_mult)
        modified = true
    end

    if accel_x and accel_x > 0.01 then
        ComponentSetValue2(comp, "accel_x", accel_x * accel_mult)
        modified = true
    end

    if fly_vel_x and fly_vel_x > 1 then
        ComponentSetValue2(comp, "fly_velocity_x", fly_vel_x * speed_mult)
        modified = true
    end

    if modified then
        local new_run = ComponentGetValue2(comp, "run_velocity")
        if IsDebugEnabled() then
            print(string.format("[SlowEnemies] Slowed enemy %d: run=%.1f->%.1f",
                entity_id, run_vel or 0, new_run or 0))
        end
    end

    return modified
end

function modify_enemy_ai(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "AnimalAIComponent")
    if comp == nil then
        return false
    end

    local speed_mult = GetEnemySpeedMultiplier()
    local dash_speed = ComponentGetValue2(comp, "attack_dash_speed")

    if dash_speed and dash_speed > 1 then
        ComponentSetValue2(comp, "attack_dash_speed", dash_speed * speed_mult)
        return true
    end

    return false
end

function modify_projectile(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if comp == nil then
        return false
    end

    local speed_mult = GetProjectileSpeedMultiplier()
    local speed_min = ComponentGetValue2(comp, "speed_min")
    local speed_max = ComponentGetValue2(comp, "speed_max")

    if speed_min and speed_max then
        ComponentSetValue2(comp, "speed_min", speed_min * speed_mult)
        ComponentSetValue2(comp, "speed_max", speed_max * speed_mult)
        if IsDebugEnabled() then
            print(string.format("[SlowEnemies] Slowed projectile %d: [%.1f-%.1f] -> [%.1f-%.1f]",
                entity_id, speed_min, speed_max, speed_min * speed_mult, speed_max * speed_mult))
        end
        return true
    end

    return false
end

function process_entity(entity_id)
    if not IsEnabled() then
        return
    end
    if not EntityGetIsAlive(entity_id) then
        return
    end
    if modified_entities[entity_id] then
        return
    end

    if is_enemy_entity(entity_id) then
        local mod1 = modify_enemy_platforming(entity_id)
        local mod2 = modify_enemy_ai(entity_id)
        if mod1 or mod2 then
            modified_entities[entity_id] = true
            debug_count = debug_count + 1
        end
    elseif is_enemy_projectile(entity_id) then
        if modify_projectile(entity_id) then
            modified_entities[entity_id] = true
            debug_count = debug_count + 1
        end
    end
end

function cleanup_modified()
    local to_remove = {}
    for eid, _ in pairs(modified_entities) do
        if not EntityGetIsAlive(eid) then
            table.insert(to_remove, eid)
        end
    end
    for _, eid in ipairs(to_remove) do
        modified_entities[eid] = nil
    end
end

function process_all_entities()
    if not IsEnabled() then
        return
    end

    -- Process enemies
    local enemies = EntityGetWithTag("enemy")
    if enemies ~= nil then
        for _, eid in ipairs(enemies) do
            process_entity(eid)
        end
    end

    -- Process mortals
    local mortals = EntityGetWithTag("mortal")
    if mortals ~= nil then
        for _, eid in ipairs(mortals) do
            if not is_player_entity(eid)
               and not EntityHasTag(eid, "item")
               and not EntityHasTag(eid, "corpse")
               and not EntityHasTag(eid, "dead") then
                process_entity(eid)
            end
        end
    end

    -- Process projectiles
    local projectiles = EntityGetWithTag("projectile")
    if projectiles ~= nil then
        for _, eid in ipairs(projectiles) do
            process_entity(eid)
        end
    end
end

function debug_output()
    debug_print_cooldown = debug_print_cooldown + 1

    if debug_print_cooldown >= 120 then
        debug_print_cooldown = 0

        local mx, my = DEBUG_GetMouseWorld()

        local enemies = EntityGetWithTag("enemy")
        local enemy_count = enemies and #enemies or 0

        local projectiles = EntityGetWithTag("projectile")
        local projectile_count = projectiles and #projectiles or 0

        local status = string.format(
            "[SlowEnemies] slowed=%d active_e=%d active_p=%d m=(%.0f,%.0f)",
            debug_count, enemy_count, projectile_count, mx or 0, my or 0
        )
        GamePrint(status)
    end
end

function ModMain()
    LoadConfig()

    print("========================================")
    print(string.format("[%s] Mod initializing...", MOD_NAME))
    print(string.format("  Enemy speed: %.2f", GetEnemySpeedMultiplier()))
    print(string.format("  Enemy accel: %.2f", GetEnemyAccelMultiplier()))
    print(string.format("  Projectile speed: %.2f", GetProjectileSpeedMultiplier()))
    print("========================================")
end

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
    world_initialized = true
    print("[SlowEnemies] World initialized - processing enemies once")
end

function OnWorldPreUpdate()
    if not world_initialized then
        return
    end

    -- Only process ONCE per entity, not every frame
    -- This prevents the infinite loop and lag
    process_all_entities()

    -- Cleanup every 300 frames (5 seconds)
    if GameGetFrameNum() % 300 == 0 then
        cleanup_modified()
        debug_output()
    end
end

function OnWorldPostUpdate()

end
