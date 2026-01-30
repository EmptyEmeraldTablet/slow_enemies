-- Configuration (hardcoded)
local MOD_CONFIG = {
    enabled = true,
    enemy_speed_multiplier = 0.7,
    projectile_speed_multiplier = 0.6,
    debug = true  -- Enable debug for troubleshooting
}

function LoadConfig()
    -- Config is hardcoded
end

function IsEnabled()
    return MOD_CONFIG.enabled
end

function GetEnemySpeedMultiplier()
    return MOD_CONFIG.enemy_speed_multiplier
end

function GetProjectileSpeedMultiplier()
    return MOD_CONFIG.projectile_speed_multiplier
end

function IsDebugEnabled()
    return MOD_CONFIG.debug
end
