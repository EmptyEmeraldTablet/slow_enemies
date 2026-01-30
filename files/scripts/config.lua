-- Configuration (hardcoded, no file I/O)
local MOD_CONFIG = {
    enabled = true,
    enemy_speed_multiplier = 0.7,
    projectile_speed_multiplier = 0.6,
    debug = false
}

function LoadConfig()
    -- Config is hardcoded above
end

function SaveConfig()
    -- Not implemented (would require file I/O)
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
