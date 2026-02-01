# Noita 减速投射物模组实现规划

## 一、功能概述

本模组旨在降低敌人发射的投射物的飞行速度。模组不会对玩家自身或玩家发射的投射物产生任何影响。

核心设计原则是识别并区分玩家实体与非玩家实体，仅对后者应用速度修改。

## 二、技术可行性

### 2.1 降低敌人投射物速度：✅ 可行

投射物通过 ProjectileComponent 管理，该组件包含 `speed_min` 和 `speed_max` 两个关键属性。直接修改这些值和 VelocityComponent 不会每帧被重置，投射物减速**可行**。

### 2.2 降低敌人移动速度：❌ 不可行

直接修改 `VelocityComponent.mVelocity` 或 `CharacterPlatformingComponent.run_velocity` **不可行**，因为 Noita 的 AI 系统会在每帧重置这些值，导致修改被覆盖或引发无限循环。

游戏内置的 `GameEffectComponent` 效果（如 `MOVEMENT_SLOWER`）也无法在此模组的慢速场机制中正常工作。

### 2.3 排除玩家影响：✅ 可行

Noita 实体系统支持标签（Tags）机制。玩家实体带有 "player_unit" 标签，可以通过 `EntityHasTag(entity_id, "player_unit")` 函数识别。

## 三、实现方案

**投射物减速场（Projectile Slow Field）方案**：
1. 创建一个跟随玩家的"减速场"实体
2. 每4帧检测范围内的投射物
3. 对敌人投射物直接修改 ProjectileComponent 和 VelocityComponent
4. 使用距离衰减算法：中心减速更强，边缘减速较弱

## 四、目录结构

```
slow_enemies/
├── mod.xml                    # 模组配置文件
├── init.lua                   # 模组初始化脚本
├── IMPLEMENTATION_PLAN.md     # 实现文档
├── DEVELOPMENT_REFERENCE.md   # 开发参考
└── files/
    ├── entities/
    │   └── slow_field.xml     # 减速场实体定义
    └── scripts/
        ├── slow_field.lua     # 减速场主逻辑
        └── config.lua         # 配置管理脚本
```

## 五、核心实现

### 5.1 slow_field.lua

```lua
dofile_once("mods/slow_enemies/files/scripts/config.lua")

local field_entity_id = GetUpdatedEntityID()
local field_x, field_y = EntityGetTransform(field_entity_id)

local config = {
    radius = 128,
    projectile_slow_mult = 0.4
}

function is_enemy_projectile(entity_id)
    local proj_comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if proj_comp == nil then return false end
    local shooter = ComponentGetValue2(proj_comp, "mWhoShot")
    if shooter ~= nil and shooter ~= 0 and EntityHasTag(shooter, "player_unit") then
        return false
    end
    return true
end

function slow_projectile(entity_id, slow_mult)
    local proj_comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if proj_comp == nil then return end

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

local projectiles = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "projectile")
for _, proj_id in ipairs(projectiles) do
    if is_enemy_projectile(proj_id) then
        local px, py = EntityGetTransform(proj_id)
        local dist = get_distance(field_x, field_y, px, py)
        if dist < config.radius then
            local dist_factor = 1.0 - (dist / config.radius)
            local slow_mult = 1.0 - (dist_factor * (1.0 - config.projectile_slow_mult))
            slow_projectile(proj_id, slow_mult)
        end
    end
end
```

### 5.2 slow_field.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<Entity tags="slow_field">
    <InheritTransformComponent>
    </InheritTransformComponent>

    <ParticleEmitterComponent
        emitted_material_name="air"
        count_min="1"
        count_max="3"
        lifetime_min="0.5"
        lifetime_max="1.0"
        is_emitting="1">
    </ParticleEmitterComponent>

    <Base file="data/entities/projectiles/deck/base_field.xml">
        <ProjectileComponent
            penetrate_entities="1"
            collide_with_world="0"
            lifetime="-1"
            speed_min="0"
            speed_max="0"
            damage="0">
        </ProjectileComponent>
    </Base>

    <LuaComponent
        execute_every_n_frame="4"
        script_source_file="mods/slow_enemies/files/scripts/slow_field.lua">
    </LuaComponent>
</Entity>
```

### 5.3 init.lua

```lua
dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowProjectiles"
local world_initialized = false
local player_entity = nil
local slow_field_entity = nil

function ModMain()
    LoadConfig()
    print(string.format("[%s] Mod initialized", MOD_NAME))
end

function OnModPreInit()
    ModMain()
end

function OnPlayerSpawned(p_entity)
    player_entity = p_entity
    local x, y = EntityGetTransform(p_entity)
    slow_field_entity = EntityLoad("mods/slow_enemies/files/entities/slow_field.xml", x, y)
end

function OnWorldInitialized()
    world_initialized = true
end

function OnWorldPreUpdate()
    if not world_initialized then return end
    if slow_field_entity and player_entity and EntityGetIsAlive(player_entity) then
        local px, py = EntityGetTransform(player_entity)
        EntitySetTransform(slow_field_entity, px, py)
    end
end
```

## 六、总结

### ❌ 不可行的方法

1. **直接修改生物 VelocityComponent**
   - Noita 的 AI 系统会在每帧重置速度值
   - 导致修改被覆盖

2. **使用 GameEffectComponent（INTERNAL_ICE / MOVEMENT_SLOWER）**
   - 在模组创建的慢速场中无法正常工作
   - GameAreaEffectComponent 不按预期触发效果

### ✅ 可行的方法

**投射物减速**：
- 直接修改 ProjectileComponent 的 speed_min / speed_max
- 直接修改 VelocityComponent 的 mVelocity
- 使用距离衰减算法增强减速效果

### API 参考

```lua
-- 实体检测
EntityGetInRadiusWithTag(x, y, radius, tag)

-- 组件读写
ComponentGetValue2(comp, "speed_min")
ComponentSetValue2(comp, "speed_min", value)
ComponentGetValue2(comp, "mVelocity")
ComponentSetValue2(comp, "mVelocity", vx, vy)
```
