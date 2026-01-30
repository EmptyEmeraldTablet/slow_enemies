dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
local MOD_INIT_FLAG = MOD_NAME .. "_init_done"
local debug_entity_count = 0
local debug_projectile_count = 0
local debug_print_cooldown = 0
local processed_entities = {}
local world_initialized = false
local last_debug_frame = 0

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

function slow_entity(entity_id, is_enemy)
    if not IsEnabled() then
        return
    end

    if processed_entities[entity_id] then
        return
    end

    if is_enemy then
        local comp = EntityGetFirstComponent(entity_id, "VelocityComponent")
        if comp ~= nil then
            local mult = GetEnemySpeedMultiplier()
            if mult < 1.0 then
                local vx, vy = ComponentGetValue2(comp, "mVelocity")
                if vx ~= nil and vy ~= nil then
                    ComponentSetValue2(comp, "mVelocity", vx * mult, vy * mult)
                    processed_entities[entity_id] = true
                    debug_entity_count = debug_entity_count + 1
                    print(string.format("[SlowEnemies] Slowed enemy %d vel=(%.1f,%.1f)",
                        entity_id, vx, vy))
                end
            end
        end
    else
        local comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
        if comp ~= nil then
            local mult = GetProjectileSpeedMultiplier()
            if mult < 1.0 then
                local speed_min = ComponentGetValue2(comp, "speed_min")
                local speed_max = ComponentGetValue2(comp, "speed_max")
                if speed_min ~= nil and speed_max ~= nil then
                    ComponentSetValue2(comp, "speed_min", speed_min * mult)
                    ComponentSetValue2(comp, "speed_max", speed_max * mult)
                    processed_entities[entity_id] = true
                    debug_projectile_count = debug_projectile_count + 1
                    print(string.format("[SlowEnemies] Slowed projectile %d speed=[%.1f-%.1f]",
                        entity_id, speed_min, speed_max))
                end
            end
        end
    end
end

function process_all()
    if not IsEnabled() then
        return
    end

    -- Process enemies with "enemy" tag
    local enemies = EntityGetWithTag("enemy")
    if enemies ~= nil then
        for _, entity_id in ipairs(enemies) do
            if not is_player_entity(entity_id) then
                slow_entity(entity_id, true)
            end
        end
    end

    -- Process enemies with "mortal" tag (but not items or player)
    local mortals = EntityGetWithTag("mortal")
    if mortals ~= nil then
        for _, entity_id in ipairs(mortals) do
            if not is_player_entity(entity_id)
               and not EntityHasTag(entity_id, "item")
               and not EntityHasTag(entity_id, "corpse") then
                slow_entity(entity_id, true)
            end
        end
    end

    -- Process projectiles
    local projectiles = EntityGetWithTag("projectile")
    if projectiles ~= nil then
        for _, entity_id in ipairs(projectiles) do
            if not is_player_projectile(entity_id) then
                slow_entity(entity_id, false)
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
    print("[SlowEnemies] Player spawned")
end

function OnWorldInitialized()
    world_initialized = true
    print("[SlowEnemies] World initialized")
end

function OnWorldPreUpdate()
    if not world_initialized then
        return
    end

    process_all()

    debug_print_cooldown = debug_print_cooldown + 1
    if debug_print_cooldown >= 60 then
        debug_print_cooldown = 0

        local frame = GameGetFrameNum()
        local mx, my = DEBUG_GetMouseWorld()
        local players = get_players()
        local player_count = 0
        if players ~= nil then
            player_count = #players
        end

        local enemies = EntityGetWithTag("enemy")
        local enemy_count = 0
        if enemies ~= nil then
            enemy_count = #enemies
        end

        local mortals = EntityGetWithTag("mortal")
        local mortal_count = 0
        if mortals ~= nil then
            mortal_count = #mortals
        end

        local projectiles = EntityGetWithTag("projectile")
        local projectile_count = 0
        if projectiles ~= nil then
            projectile_count = #projectiles
        end

        local status = string.format(
            "[SlowEnemies] frame=%d enemies=%d mortals=%d projs=%d slowed=%d/%d m=(%.0f,%.0f)",
            frame, enemy_count, mortal_count, projectile_count,
            debug_entity_count, debug_projectile_count, mx or 0, my or 0
        )
        GamePrint(status)

        if enemy_count == 0 and mortal_count == 0 and frame > last_debug_frame + 300 then
            last_debug_frame = frame
            print(string.format("[SlowEnemies] WARNING: No enemies found! Tags may be different."))
            print(string.format("[SlowEnemies] Checking for other tags..."))

            -- Try to find any entity with character tag
            local characters = EntityGetWithTag("character")
            if characters ~= nil and #characters > 0 then
                print(string.format("[SlowEnemies] Found %d entities with 'character' tag", #characters))
                for i, e in ipairs(characters) do
                    if i <= 5 then
                        local tags = EntityGetTags(e)
                        print(string.format("  Entity %d: tags=%s", e, tags or "none"))
                    end
                end
            end
        end
    end
end

function OnWorldPostUpdate()

end
