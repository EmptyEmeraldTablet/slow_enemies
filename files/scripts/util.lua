dofile("data/scripts/utilities.lua")

function IsPlayerEntity(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end
    if EntityGetName(entity_id) == "player" then
        return true
    end
    if EntityHasTag(entity_id, "player") then
        return true
    end
    return false
end

function IsEnemyEntity(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end
    if IsPlayerEntity(entity_id) then
        return false
    end
    if EntityHasTag(entity_id, "enemy") then
        return true
    end
    if EntityHasTag(entity_id, "mortal") then
        return true
    end
    if EntityHasTag(entity_id, "character") then
        local player = get_player_entity()
        if player ~= nil and entity_id ~= player then
            return true
        end
    end
    return false
end

function GetProjectileShooter(entity_id)
    local projectile_component = EntityGetFirstComponent(entity_id, "Projectile")
    if projectile_component == nil then
        return nil
    end
    local shooter = ComponentGetValue2(projectile_component, "mWhoShot")
    return shooter
end

function IsPlayerProjectile(entity_id)
    local shooter = GetProjectileShooter(entity_id)
    if shooter == nil or shooter == 0 then
        return false
    end
    return IsPlayerEntity(shooter)
end

function IsEnemyProjectile(entity_id)
    if IsPlayerProjectile(entity_id) then
        return false
    end
    if EntityGetFirstComponent(entity_id, "Projectile") == nil then
        return false
    end
    return true
end

function get_player_entity()
    local player_id = EntityGetWithName("player")
    if player_id ~= nil and player_id ~= 0 then
        return player_id
    end
    return nil
end
