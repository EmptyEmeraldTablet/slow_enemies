dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local debug_count = 0
local debug_print_cooldown = 0
local world_initialized = false
local update_frame_counter = 0

-- Track processed entities and what components were modified
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

function modify_enemy_platforming(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "CharacterPlatformingComponent")
    if comp == nil then
        return false
    end

    local speed_mult = GetEnemySpeedMultiplier()
    local accel_mult = GetEnemyAccelMultiplier()

    -- Modify run_velocity
    local run_vel = ComponentGetValue2(comp, "run_velocity")
    if run_vel and run_vel > 0 then
        ComponentSetValue2(comp, "run_velocity", run_vel * speed_mult)
    end

    -- Modify velocity_max_x
    local max_vel_x = ComponentGetValue2(comp, "velocity_max_x")
    if max_vel_x then
        ComponentSetValue2(comp, "velocity_max_x", max_vel_x * speed_mult)
    end

    -- Modify accel_x
    local accel_x = ComponentGetValue2(comp, "accel_x")
    if accel_x and accel_x > 0 then
        ComponentSetValue2(comp, "accel_x", accel_x * accel_mult)
    end

    -- Modify fly_velocity_x (for flying enemies)
    local fly_vel_x = ComponentGetValue2(comp, "fly_velocity_x")
    if fly_vel_x and fly_vel_x > 0 then
        ComponentSetValue2(comp, "fly_velocity_x", fly_vel_x * speed_mult)
    end

    return true
end

function modify_enemy_ai(entity_id)
    local comp = EntityGetFirstComponent(entity_id, "AnimalAIComponent")
    if comp == nil then
        return false
    end

    local speed_mult = GetEnemySpeedMultiplier()

    -- Modify attack_dash_speed
    local dash_speed = ComponentGetValue2(comp, "attack_dash_speed")
    if dash_speed and dash_speed > 0 then
        ComponentSetValue2(comp, "attack_dash_speed", dash_speed * speed_mult)
    end

    return true
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
    end

    return true
end

function process_entity(entity_id)
    if not IsEnabled() then
        return
    end
    if not EntityExists(entity_id) then
        return
    end

    if is_enemy_entity(entity_id) then
        local mod_platforming = modify_enemy_platforming(entity_id)
        local mod_ai = modify_enemy_ai(entity_id)

        if mod_platforming or mod_ai then
            if not processed_entities[entity_id] then
                processed_entities[entity_id] = { platforming = mod_platforming, ai = mod_ai }
                debug_count = debug_count + 1
                if IsDebugEnabled() then
                    print(string.format("[SlowEnemies] Slowed enemy %d", entity_id))
                end
            else
                -- Re-apply to counteract game resets
                if mod_platforming then
                    modify_enemy_platforming(entity_id)
                end
                if mod_ai then
                    modify_enemy_ai(entity_id)
                end
            end
        end
    elseif is_enemy_projectile(entity_id) then
        if not processed_entities[entity_id] then
            if modify_projectile(entity_id) then
                processed_entities[entity_id] = { projectile = true }
                if IsDebugEnabled() then
                    print(string.format("[SlowEnemies] Slowed projectile %d", entity_id))
                end
            end
        else
            -- Re-apply
            modify_projectile(entity_id)
        end
    end
end

function cleanup_processed()
    for eid, _ in pairs(processed_entities) do
        if not EntityExists(eid) then
            processed_entities[eid] = nil
        end
    end
end

function process_all_entities()
    if not IsEnabled() then
        return
    end

    -- Process enemies with "enemy" tag
    local enemies = EntityGetWithTag("enemy")
    if enemies ~= nil then
        for _, eid in ipairs(enemies) do
            process_entity(eid)
        end
    end

    -- Process mortals (excluding items and corpses)
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

    if debug_print_cooldown >= 60 then
        debug_print_cooldown = 0

        local mx, my = DEBUG_GetMouseWorld()

        -- Count current enemies
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
    print(string.format("  Enabled: %s", tostring(IsEnabled())))
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
    print("[SlowEnemies] World initialized")
end

function OnWorldPreUpdate()
    if not world_initialized then
        return
    end

    update_frame_counter = update_frame_counter + 1

    -- Process all entities
    process_all_entities()

    -- Cleanup every 60 frames
    if update_frame_counter % 60 == 0 then
        cleanup_processed()
    end

    -- Debug output
    if IsDebugEnabled() then
        debug_output()
    end
end

function OnWorldPostUpdate()

end
