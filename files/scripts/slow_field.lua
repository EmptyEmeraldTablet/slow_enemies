dofile_once("mods/slow_enemies/files/scripts/config.lua")

local field_entity_id = GetUpdatedEntityID()
local field_x, field_y = EntityGetTransform(field_entity_id)
local frame = GameGetFrameNum()

local config = {
    radius = 1500,  -- 覆盖玩家可视范围（约10倍）
    enemy_slow_mult = 0.1,
    projectile_slow_mult = 0.1
}

function is_player(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end
    return EntityHasTag(entity_id, "player_unit")
end

function is_enemy(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end
    if is_player(entity_id) then
        return false
    end
    if EntityHasTag(entity_id, "enemy") then
        return true
    end
    if EntityHasTag(entity_id, "mortal") and not EntityHasTag(entity_id, "item") then
        return true
    end
    return false
end

function is_enemy_projectile(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end

    local proj_comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if proj_comp == nil then
        return false
    end

    local shooter = ComponentGetValue2(proj_comp, "mWhoShot")
    if shooter ~= nil and shooter ~= 0 then
        if is_player(shooter) then
            return false
        end
    end

    return true
end

function get_distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function slow_enemy(entity_id, slow_mult)
    local vel_comp = EntityGetFirstComponent(entity_id, "VelocityComponent")
    if vel_comp ~= nil then
        local vx, vy = ComponentGetValue2(vel_comp, "mVelocity")
        if vx ~= nil and vy ~= nil then
            local speed = math.sqrt(vx * vx + vy * vy)
            if speed > 1 then
                local new_speed = speed * slow_mult
                local new_vx = (vx / speed) * new_speed
                local new_vy = (vy / speed) * new_speed
                ComponentSetValue2(vel_comp, "mVelocity", new_vx, new_vy)
            end
        end
    end

    local char_comp = EntityGetFirstComponent(entity_id, "CharacterPlatformingComponent")
    if char_comp ~= nil then
        local run_vel = ComponentGetValue2(char_comp, "run_velocity")
        if run_vel ~= nil then
            ComponentSetValue2(char_comp, "run_velocity", run_vel * slow_mult)
        end

        local fly_speed = ComponentGetValue2(char_comp, "fly_speed_max_up")
        if fly_speed ~= nil then
            ComponentSetValue2(char_comp, "fly_speed_max_up", fly_speed * slow_mult)
            ComponentSetValue2(char_comp, "fly_speed_max_down", fly_speed * slow_mult)
        end

        local fly_mult = ComponentGetValue2(char_comp, "fly_speed_mult")
        if fly_mult ~= nil then
            ComponentSetValue2(char_comp, "fly_speed_mult", fly_mult * slow_mult)
        end
    end
end

function slow_projectile(entity_id, slow_mult)
    local proj_comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if proj_comp == nil then
        return
    end

    local speed_min = ComponentGetValue2(proj_comp, "speed_min")
    local speed_max = ComponentGetValue2(proj_comp, "speed_max")

    if speed_min and speed_max then
        ComponentSetValue2(proj_comp, "speed_min", speed_min * slow_mult)
        ComponentSetValue2(proj_comp, "speed_max", speed_max * slow_mult)
    end

    local vel_comp = EntityGetFirstComponent(entity_id, "VelocityComponent")
    if vel_comp ~= nil then
        local vx, vy = ComponentGetValue2(vel_comp, "mVelocity")
        if vx ~= nil and vy ~= nil then
            local speed = math.sqrt(vx * vx + vy * vy)
            if speed > 0 then
                local new_speed = speed * slow_mult
                ComponentSetValue2(vel_comp, "mVelocity", (vx / speed) * new_speed, (vy / speed) * new_speed)
            end
        end
    end
end

if config.radius > 0 then
    local enemies = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "enemy")

    for _, enemy_id in ipairs(enemies) do
        if not is_player(enemy_id) then
            local ex, ey = EntityGetTransform(enemy_id)
            local dist = get_distance(field_x, field_y, ex, ey)

            if dist < config.radius then
                local dist_factor = 1.0 - (dist / config.radius)
                dist_factor = math.max(dist_factor, 0.01)

                local slow_mult = 1.0 - (dist_factor * (1.0 - config.enemy_slow_mult))
                slow_mult = math.max(slow_mult, 0.1)

                slow_enemy(enemy_id, slow_mult)
            end
        end
    end

    local mortals = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "mortal")
    for _, enemy_id in ipairs(mortals) do
        if not is_player(enemy_id)
           and not EntityHasTag(enemy_id, "item")
           and not EntityHasTag(enemy_id, "corpse")
           and not EntityHasTag(enemy_id, "dead") then
            local ex, ey = EntityGetTransform(enemy_id)
            local dist = get_distance(field_x, field_y, ex, ey)

            if dist < config.radius then
                local dist_factor = 1.0 - (dist / config.radius)
                dist_factor = math.max(dist_factor, 0.01)

                local slow_mult = 1.0 - (dist_factor * (1.0 - config.enemy_slow_mult))
                slow_mult = math.max(slow_mult, 0.1)

                slow_enemy(enemy_id, slow_mult)
            end
        end
    end

    local projectiles = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "projectile")
    for _, proj_id in ipairs(projectiles) do
        if is_enemy_projectile(proj_id) then
            local px, py = EntityGetTransform(proj_id)
            local dist = get_distance(field_x, field_y, px, py)

            if dist < config.radius then
                local dist_factor = 1.0 - (dist / config.radius)
                dist_factor = math.max(dist_factor, 0.01)

                local slow_mult = 1.0 - (dist_factor * (1.0 - config.projectile_slow_mult))
                slow_mult = math.max(slow_mult, 0.1)

                slow_projectile(proj_id, slow_mult)
            end
        end
    end
end
