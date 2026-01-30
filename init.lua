dofile_once("mods/slow_enemies/files/scripts/main.lua")

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

end

function OnEntityCreated(entity_id)
    _OnEntityCreated(entity_id)
end

function OnEntityDestroyed(entity_id)
    _OnEntityDestroyed(entity_id)
end

function OnWorldPreUpdate()
    _Update()
end

function OnWorldPostUpdate()

end
