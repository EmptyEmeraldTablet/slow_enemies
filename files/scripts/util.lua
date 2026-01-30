dofile("data/scripts/utilities.lua")

function IsPlayerEntity(entity_id)
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
