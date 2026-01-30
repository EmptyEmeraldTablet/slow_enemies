dofile("mods/slow_enemies/files/scripts/config.lua")
dofile("mods/slow_enemies/files/scripts/util.lua")

local processed_entities = {}
local debug_frame_count = 0
local debug_entity_count = 0
local debug_projectile_count = 0
local debug_print_cooldown = 0

function log_debug(message)
    if IsDebugEnabled() then
        print(message)
    end
end

function screen_debug(message)
    if IsDebugEnabled() then
        GamePrint(message)
    end
end

function debug_mark_entity(entity_id, message, r, g, b)
    if IsDebugEnabled() then
        local x, y = EntityGetPosition(entity_id)
        if x ~= nil and y ~= nil then
            DEBUG_MARK(x, y, message, r or 0, g or 1, b or 1)
        end
    end
end

function debug_get_mouse_pos()
    return DEBUG_GetMouseWorld()
end

function debug_summary()
    if not IsDebugEnabled() then
        return
    end

    local count = 0
    for _ in pairs(processed_entities) do
        count = count + 1
    end

    log_debug("[SlowEnemies] ===== 调试统计 =====")
    log_debug(string.format("[SlowEnemies] 总帧数: %d", debug_frame_count))
    log_debug(string.format("[SlowEnemies] 减速实体数: %d", debug_entity_count))
    log_debug(string.format("[SlowEnemies] 减速投射物数: %d", debug_projectile_count))
    log_debug(string.format("[SlowEnemies] 待处理实体数: %d", count))
    log_debug("[SlowEnemies] ====================")
end

function reduce_enemy_velocity(entity_id)
    local velocity_comp = EntityGetFirstComponent(entity_id, "Velocity")
    if velocity_comp == nil then
        return
    end

    local mult = GetEnemySpeedMultiplier()
    if mult >= 1.0 then
        return
    end

    local vx, vy = ComponentGetValue2(velocity_comp, "mVelocity")
    if vx == nil or vy == nil then
        return
    end

    local new_vx = vx * mult
    local new_vy = vy * mult
    ComponentSetValue2(velocity_comp, "mVelocity", new_vx, new_vy)

    debug_entity_count = debug_entity_count + 1

    if IsDebugEnabled() then
        log_debug(string.format("[SlowEnemies] 减速实体 %d: (%.2f, %.2f) -> (%.2f, %.2f)",
            entity_id, vx, vy, new_vx, new_vy))
        debug_mark_entity(entity_id, "slow", 0, 1, 1)
    end
end

function reduce_projectile_speed(entity_id)
    local projectile_comp = EntityGetFirstComponent(entity_id, "Projectile")
    if projectile_comp == nil then
        return
    end

    local mult = GetProjectileSpeedMultiplier()
    if mult >= 1.0 then
        return
    end

    local speed_min = ComponentGetValue2(projectile_comp, "speed_min")
    local speed_max = ComponentGetValue2(projectile_comp, "speed_max")

    if speed_min == nil or speed_max == nil then
        return
    end

    ComponentSetValue2(projectile_comp, "speed_min", speed_min * mult)
    ComponentSetValue2(projectile_comp, "speed_max", speed_max * mult)

    debug_projectile_count = debug_projectile_count + 1

    if IsDebugEnabled() then
        log_debug(string.format("[SlowEnemies] 减速投射物 %d: [%.1f-%.1f] -> [%.1f-%.1f]",
            entity_id, speed_min, speed_max, speed_min * mult, speed_max * mult))
        debug_mark_entity(entity_id, "slow", 0, 1, 1)
    end
end

function process_entity(entity_id)
    if not IsEnabled() then
        return
    end

    if processed_entities[entity_id] then
        return
    end

    if IsEnemyEntity(entity_id) then
        reduce_enemy_velocity(entity_id)
        processed_entities[entity_id] = true
    elseif IsEnemyProjectile(entity_id) then
        reduce_projectile_speed(entity_id)
        processed_entities[entity_id] = true
    end
end

function debug_update_screen()
    if not IsDebugEnabled() then
        return
    end

    debug_frame_count = debug_frame_count + 1

    if debug_print_cooldown > 0 then
        debug_print_cooldown = debug_print_cooldown - 1
        return
    end

    if debug_frame_count % 60 == 0 then
        local mx, my = debug_get_mouse_pos()
        local player = get_player_entity()
        local player_x, player_y = 0, 0
        if player then
            local ppos = EntityGetPosition(player)
            if ppos then
                player_x, player_y = ppos, ppos
            end
        end

        local count = 0
        for _ in pairs(processed_entities) do
            count = count + 1
        end

        local status = string.format(
            "[SlowEnemies] frm:%d m:(%.0f,%.0f) e:%d p:%d q:%d",
            debug_frame_count, mx or 0, my or 0,
            debug_entity_count, debug_projectile_count, count
        )
        screen_debug(status)
        debug_print_cooldown = 60
    end
end

function OnEntityCreated(entity_id)
    GameScheduleFunction(function()
        if EntityExists(entity_id) then
            process_entity(entity_id)
        end
    end, {}, 1)
end

function OnEntityDestroyed(entity_id)
    processed_entities[entity_id] = nil
end

function Update()
    if not IsEnabled() then
        return
    end

    local entities = EntityGetAll()
    for _, entity_id in ipairs(entities) do
        process_entity(entity_id)
    end

    if GameGetFrameNum() % 300 == 0 then
        cleanup_processed_list()
    end

    debug_update_screen()
end

function cleanup_processed_list()
    local to_remove = {}
    for entity_id, _ in pairs(processed_entities) do
        if not EntityExists(entity_id) then
            table.insert(to_remove, entity_id)
        end
    end
    for _, entity_id in ipairs(to_remove) do
        processed_entities[entity_id] = nil
    end
end

function ModMain()
    LoadConfig()

    print("[SlowEnemies] 模组已加载")
    print(string.format("  敌人速度倍率: %.2f", GetEnemySpeedMultiplier()))
    print(string.format("  投射物速度倍率: %.2f", GetProjectileSpeedMultiplier()))

    if IsDebugEnabled() then
        print("[SlowEnemies] 调试模式已启用")
        print("  - 控制台: 查看详细日志输出")
        print("  - 屏幕: 每60帧显示状态信息")
        print("  - 世界: 被减速实体有青色标记")
    end
end
