dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local debug_entity_count = 0
local debug_projectile_count = 0
local debug_print_cooldown = 0
local world_initialized = false

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
    if not IsEnabled() then
        return false
    end

    if is_player_entity(entity_id) then
        return false
    end

    local mult = GetEnemySpeedMultiplier()
    if mult >= 1.0 then
        return false
    end

    local modified = false

    -- Method 1: Modify PhysicsAIComponent force
    local physics_ai = EntityGetFirstComponent(entity_id, "PhysicsAIComponent")
    if physics_ai ~= nil then
        local force_coeff = ComponentGetValue2(physics_ai, "force_coeff")
        if force_coeff ~= nil then
            ComponentSetValue2(physics_ai, "force_coeff", force_coeff * mult)
            modified = true
        end
    end

    -- Method 2: Modify VelocityComponent (if exists and moving)
    local velocity = EntityGetFirstComponent(entity_id, "VelocityComponent")
    if velocity ~= nil then
        local vx, vy = ComponentGetValue2(velocity, "mVelocity")
        if vx ~= nil and vy ~= nil then
            local speed = math.sqrt(vx * vx + vy * vy)
            if speed > 1 then
                ComponentSetValue2(velocity, "mVelocity", vx * mult, vy * mult)
                modified = true
            end
        end
    end

    -- Method 3: Modify CharacterPlatformingComponent max_speed
    local char_platform = EntityGetFirstComponent(entity_id, "CharacterPlatformingComponent")
    if char_platform ~= nil then
        local max_speed = ComponentGetValue2(char_platform, "max_speed")
        if max_speed ~= nil then
            ComponentSetValue2(char_platform, "max_speed", max_speed * mult)
            modified = true
        end
    end

    if modified then
        debug_entity_count = debug_entity_count + 1
    end

    return modified
end

function slow_projectile(entity_id)
    if not IsEnabled() then
        return false
    end

    if is_player_projectile(entity_id) then
        return false
    end

    local comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if comp == nil then
        return false
    end

    local mult = GetProjectileSpeedMultiplier()
    if mult >= 1.0 then
        return false
    end

    local speed_min = ComponentGetValue2(comp, "speed_min")
    local speed_max = ComponentGetValue2(comp, "speed_max")

    if speed_min == nil or speed_max == nil then
        return false
    end

    ComponentSetValue2(comp, "speed_min", speed_min * mult)
    ComponentSetValue2(comp, "speed_max", speed_max * mult)

    debug_projectile_count = debug_projectile_count + 1
    return true
end

function process_enemies()
    if not IsEnabled() then
        return
    end

    local enemies = EntityGetWithTag("enemy")
    if enemies ~= nil then
        for _, entity_id in ipairs(enemies) do
            slow_enemy(entity_id)
        end
    end

    local mortals = EntityGetWithTag("mortal")
    if mortals ~= nil then
        for _, entity_id in ipairs(mortals) do
            if not is_player_entity(entity_id)
               and not EntityHasTag(entity_id, "item")
               and not EntityHasTag(entity_id, "corpse")
               and not EntityHasTag(entity_id, "dead") then
                slow_enemy(entity_id)
            end
        end
    end
end

function process_projectiles()
    if not IsEnabled() then
        return
    end

    local projectiles = EntityGetWithTag("projectile")
    if projectiles ~= nil then
        for _, entity_id in ipairs(projectiles) do
            slow_projectile(entity_id)
        end
    end
end

function ModMain()
    LoadConfig()

    print("========================================")
    print("[SlowEnemies] Mod initializing...")
    print(string.format("  Enemy speed: %.2f", GetEnemySpeedMultiplier()))
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

    process_enemies()
    process_projectiles()

    debug_print_cooldown = debug_print_cooldown + 1
    if debug_print_cooldown >= 60 then
        debug_print_cooldown = 0

        local mx, my = DEBUG_GetMouseWorld()

        local status = string.format(
            "[SlowEnemies] e=%d p=%d m=(%.0f,%.0f)",
            debug_entity_count, debug_projectile_count, mx or 0, my or 0
        )
        GamePrint(status)
    end
end

function OnWorldPostUpdate()

end
