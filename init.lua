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
    local comp = EntityGetFirstComponent(entity_id, "VelocityComponent")
    if comp == nil then
        return false
    end

    local mult = GetEnemySpeedMultiplier()
    if mult >= 1.0 then
        return false
    end

    local vx, vy = ComponentGetValue2(comp, "mVelocity")
    if vx == nil or vy == nil then
        return false
    end

    -- Calculate target velocity (apply multiplier)
    local new_vx = vx * mult
    local new_vy = vy * mult

    -- Set the modified velocity
    ComponentSetValue2(comp, "mVelocity", new_vx, new_vy)

    return true
end

function slow_projectile(entity_id)
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

    return true
end

function process_enemies()
    if not IsEnabled() then
        return
    end

    local enemies = EntityGetWithTag("enemy")
    if enemies ~= nil then
        for _, entity_id in ipairs(enemies) do
            if not is_player_entity(entity_id) then
                if slow_enemy(entity_id) then
                    debug_entity_count = debug_entity_count + 1
                end
            end
        end
    end

    -- Also process mortals (excluding items and corpses)
    local mortals = EntityGetWithTag("mortal")
    if mortals ~= nil then
        for _, entity_id in ipairs(mortals) do
            if not is_player_entity(entity_id)
               and not EntityHasTag(entity_id, "item")
               and not EntityHasTag(entity_id, "corpse")
               and not EntityHasTag(entity_id, "dead") then
                if slow_enemy(entity_id) then
                    debug_entity_count = debug_entity_count + 1
                end
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
            if not is_player_projectile(entity_id) then
                if slow_projectile(entity_id) then
                    debug_projectile_count = debug_projectile_count + 1
                end
            end
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

    -- Process every frame for continuous application
    process_enemies()
    process_projectiles()

    debug_print_cooldown = debug_print_cooldown + 1
    if debug_print_cooldown >= 60 then
        debug_print_cooldown = 0

        local frame = GameGetFrameNum()
        local mx, my = DEBUG_GetMouseWorld()

        local enemies = EntityGetWithTag("enemy")
        local enemy_count = enemies and #enemies or 0

        local projectiles = EntityGetWithTag("projectile")
        local projectile_count = projectiles and #projectiles or 0

        local status = string.format(
            "[SlowEnemies] e=%d p=%d m=(%.0f,%.0f)",
            debug_entity_count, debug_projectile_count, mx or 0, my or 0
        )
        GamePrint(status)
    end
end

function OnWorldPostUpdate()

end
