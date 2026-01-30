local MOD_CONFIG = {
    enabled = true,
    enemy_speed_multiplier = 0.7,
    projectile_speed_multiplier = 0.6,
    debug = false
}

function LoadConfig()
    local config_path = "mods/slow_enemies/config.txt"
    if FileExists(config_path) then
        local content = LoadFileContent(config_path)
        for key, val in string.gmatch(content, "(%w+)=([^\r\n]+)") do
            if val == "true" then MOD_CONFIG[key] = true
            elseif val == "false" then MOD_CONFIG[key] = false
            else MOD_CONFIG[key] = tonumber(val) or val end
        end
    end
end

function SaveConfig()
    local content = ""
    for k, v in pairs(MOD_CONFIG) do
        content = content .. k .. "=" .. tostring(v) .. "\n"
    end
    SaveFileContent(content, "mods/slow_enemies/config.txt")
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
