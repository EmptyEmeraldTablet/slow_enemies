dofile_once("mods/slow_enemies/files/scripts/config.lua")

local field_entity_id = GetUpdatedEntityID()
local field_x, field_y = EntityGetTransform(field_entity_id)

local config = {
    radius = 200,
    projectile_slow_mult = 0.75
}

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
        if EntityHasTag(shooter, "player_unit") then
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

function slow_projectile(entity_id, slow_mult)
    local vel_comp = EntityGetFirstComponent(entity_id, "VelocityComponent")
    if vel_comp == nil then
        return
    end

    local vx, vy = ComponentGetValue2(vel_comp, "mVelocity")
    if vx == nil or vy == nil then
        return
    end

    local speed = math.sqrt(vx * vx + vy * vy)
    if speed > 0 then
        local new_speed = speed * slow_mult
        ComponentSetValue2(vel_comp, "mVelocity", (vx / speed) * new_speed, (vy / speed) * new_speed)
    end
end

local projectiles = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "projectile")
for _, proj_id in ipairs(projectiles) do
    if is_enemy_projectile(proj_id) then
        local px, py = EntityGetTransform(proj_id)
        local dist = get_distance(field_x, field_y, px, py)

        if dist < config.radius then
            slow_projectile(proj_id, config.projectile_slow_mult)
        end
    end
end
