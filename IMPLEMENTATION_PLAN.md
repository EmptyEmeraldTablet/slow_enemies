# Noita 减速敌人模组实现规划

> ⚠️ **重要提示**：本文档记录了开发过程中的探索过程。某些方法已被标记为"不可行"，请参考最终实现方案。

## 一、功能概述

本模组旨在降低游戏中除玩家外的所有生物（敌人）的移动速度，以及这些生物发射的投射物的飞行速度。模组不会对玩家自身或玩家发射的投射物产生任何影响。此功能可以降低游戏难度，为追求更轻松游戏体验的玩家提供选择。

核心设计原则是识别并区分玩家实体与非玩家实体，仅对后者应用速度修改。通过利用 Noita 的实体组件系统（ECS）和 Lua 脚本挂载机制，实现减速效果。

## 二、可行性分析

### 2.1 技术可行性评估

**降低敌人移动速度：✅ 使用游戏内置减速效果（可行）**

直接修改 `VelocityComponent.mVelocity` 或 `CharacterPlatformingComponent.run_velocity` **不可行**，因为 Noita 的 AI 系统会在每帧重置这些值，导致修改被覆盖或引发无限循环。

✅ **正确方案**：使用游戏内置的 `GameEffectComponent` 效果：
- `INTERNAL_ICE` - 内部结冰减速效果
- `MOVEMENT_SLOWER` - 直接减速效果

通过向范围内的敌人添加这些效果，可以实现稳定的减速。

**降低敌人投射物速度：✅ 直接修改速度（可行）**

投射物通过 ProjectileComponent 管理，该组件包含 `speed_min` 和 `speed_max` 两个关键属性。直接修改这些值和 VelocityComponent 不会每帧被重置，投射物减速**可行**。

**排除玩家影响：✅ 使用标签识别（可行）**

Noita 实体系统支持标签（Tags）机制。玩家实体带有 "player_unit" 标签，可以通过 `EntityHasTag(entity_id, "player_unit")` 函数识别。

### 2.2 实现方案对比

| 方案 | 状态 | 说明 |
|------|------|------|
| OnEntityCreated 挂接 + 直接修改速度 | ❌ 不可行 | AI 系统每帧重置速度值 |
| Update 循环直接修改速度 | ❌ 不可行 | 性能开销大且仍会被重置 |
| 脚本挂载游戏核心脚本 | ❌ 不可行 | 兼容性风险高且复杂 |
| **慢速场 + 游戏效果** | ✅ **可行** | 当前实现方案 |

### 2.3 最终实现方案

**慢速场（Slow Field）方案**：
1. 创建一个跟随玩家的"慢速场"实体
2. 每4帧检测范围内的敌人和投射物
3. 对敌人应用 `INTERNAL_ICE` + `MOVEMENT_SLOWER` 游戏效果
4. 对投射物直接修改速度和 VelocityComponent
5. 持续刷新效果以保持减速

## 三、技术架构

### 3.1 模组目录结构

```
slow_enemies/
├── mod.xml                    # 模组配置文件
├── init.lua                   # 模组初始化脚本
├── config.txt                 # 用户配置文件
└── files/
    ├── entities/
    │   └── slow_field.xml     # 慢速场实体定义
    └── scripts/
        ├── slow_field.lua     # 慢速场主逻辑
        └── config.lua         # 配置管理脚本
```

### 3.2 核心模块设计

**config.lua - 配置管理模块**

负责加载和保存用户配置，提供减速比例等参数的访问接口。

**slow_field.lua - 主逻辑模块**

实现慢速场的核心逻辑，包括实体检测、游戏效果应用、投射物减速。

## 三、技术架构

### 3.1 模组目录结构

```
slow_enemies/
├── mod.xml                    # 模组配置文件
├── init.lua                   # 模├── config.txt                组初始化脚本
 # 用户配置文件
└── files/
    └── scripts/
        ├── main.lua           # 主逻辑脚本
        ├── util.lua           # 工具函数库
        └── config.lua         # 配置管理脚本
```

### 3.2 核心模块设计

**config.lua - 配置管理模块**

负责加载和保存用户配置，提供减速比例等参数的访问接口。配置项包括：全局启用开关、敌人移动速度倍率、敌人投射物速度倍率、排除特定敌人类型（可选）。

**util.lua - 工具函数模块**

提供实体识别、标签检查、组件访问等通用功能。核心函数包括：is_player_entity（判断是否为玩家实体）、is_enemy_entity（判断是否为敌人实体）、is_player_projectile（判断是否为玩家投射物）、get_shooter_entity（获取投射物发射者）。

**main.lua - 主逻辑模块**

实现模组的核心里，包括 OnEntityCreated 挂接函数、Update 循环函数、速度修改逻辑。速度修改逻辑需要区分生物移动速度和投射物飞行速度，分别应用不同的修改策略。

### 3.3 数据流程

```
实体创建事件触发
        ↓
    OnEntityCreated 调用
        ↓
    实体类型判断（玩家/敌人/投射物）
        ↓
    是否需要减速？ ──否──→ 不处理
        ↓是
    获取组件（Velocity / Projectile）
        ↓
    应用减速倍率
        ↓
    完成处理
```

## 四、详细实现步骤

### 4.1 mod.xml 配置

```xml
<?xml version="1.0" encoding="utf-8"?>
<mod format="1" name="Slow Enemies" description="降低敌人及其投射物的移动速度，对玩家无影响">
    <load_order>50</load_order>
    <tags>gameplay, tweaks</tags>
</mod>
```

load_order 设置为 50 确保模组在大多数其他模组之后加载，减少兼容性问题。tags 标注模组类型为游戏性调整类。

### 4.2 config.txt 默认配置

```
# 是否启用模组功能
enabled=true

# 敌人移动速度倍率（0.1-1.0，值越小越慢）
enemy_speed_multiplier=0.7

# 敌人投射物速度倍率（0.1-1.0）
projectile_speed_multiplier=0.6

# 是否在游戏内打印调试信息
debug=false
```

### 4.3 config.lua 配置管理脚本

```lua
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
```

### 4.4 slow_field.lua 主逻辑脚本（最终实现）

```lua
dofile_once("mods/slow_enemies/files/scripts/config.lua")

local field_entity_id = GetUpdatedEntityID()
local field_x, field_y = EntityGetTransform(field_entity_id)

local config = {
    radius = 512,
    enemy_slow_mult = 0.4,
    projectile_slow_mult = 0.4
}

function is_player(entity_id)
    return EntityHasTag(entity_id, "player_unit")
end

function is_enemy_projectile(entity_id)
    local proj_comp = EntityGetFirstComponent(entity_id, "ProjectileComponent")
    if proj_comp == nil then return false end
    local shooter = ComponentGetValue2(proj_comp, "mWhoShot")
    if shooter ~= nil and shooter ~= 0 and is_player(shooter) then
        return false
    end
    return true
end

function apply_slow_effect(entity_id)
    local has_internal_ice = false
    local has_movement_slower = false

    local children = EntityGetAllChildren(entity_id)
    if children ~= nil then
        for _, child_id in ipairs(children) do
            local effect_comp = EntityGetFirstComponent(child_id, "GameEffectComponent")
            if effect_comp ~= nil then
                local effect_type = ComponentGetValue2(effect_comp, "effect")
                if effect_type == "INTERNAL_ICE" then
                    has_internal_ice = true
                    ComponentSetValue2(effect_comp, "frames", 600)
                elseif effect_type == "MOVEMENT_SLOWER" or effect_type == "MOVEMENT_SLOWER_2X" then
                    has_movement_slower = true
                    ComponentSetValue2(effect_comp, "frames", 600)
                end
            end
        end
    end

    if not has_internal_ice then
        local effect_entity = EntityLoad("data/entities/misc/effect_internal_ice.xml")
        if effect_entity ~= nil and effect_entity ~= 0 then
            EntityAddChild(entity_id, effect_entity)
        end
    end

    if not has_movement_slower then
        local effect_entity = EntityLoad("data/entities/misc/effect_movement_slower.xml")
        if effect_entity ~= nil and effect_entity ~= 0 then
            EntityAddChild(entity_id, effect_entity)
        end
    end
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

if config.radius > 0 then
    local enemies = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "enemy")
    for _, enemy_id in ipairs(enemies) do
        if not is_player(enemy_id) then
            apply_slow_effect(enemy_id)
        end
    end

    local mortals = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "mortal")
    for _, enemy_id in ipairs(mortals) do
        if not is_player(enemy_id)
           and not EntityHasTag(enemy_id, "item")
           and not EntityHasTag(enemy_id, "corpse")
           and not EntityHasTag(enemy_id, "dead") then
            apply_slow_effect(enemy_id)
        end
    end

    local projectiles = EntityGetInRadiusWithTag(field_x, field_y, config.radius, "projectile")
    for _, proj_id in ipairs(projectiles) do
        if is_enemy_projectile(proj_id) then
            slow_projectile(proj_id, config.projectile_slow_mult)
        end
    end
end
```

### 4.5 slow_field.xml 实体定义

```xml
<?xml version="1.0" encoding="utf-8"?>
<Entity tags="slow_field">
    <InheritTransformComponent>
    </InheritTransformComponent>

    <LuaComponent
        execute_every_n_frame="4"
        script_source_file="mods/slow_enemies/files/scripts/slow_field.lua">
    </LuaComponent>

    <ParticleEmitterComponent
        emitted_material_name="air"
        count_min="1"
        count_max="3"
        lifetime_min="0.5"
        lifetime_max="1.0"
        is_emitting="1">
    </ParticleEmitterComponent>
</Entity>
```

### 4.6 init.lua 入口脚本

```lua
dofile_once("mods/slow_enemies/files/scripts/config.lua")

local MOD_NAME = "SlowEnemies"
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
    print(string.format("[%s] Created slow field at (%.0f, %.0f)", MOD_NAME, x, y))
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

## 五、测试计划

### 5.1 单元测试

**配置模块测试**：验证配置加载和保存功能，确保配置文件格式正确时被正确解析，格式错误时不会崩溃。

**实体识别测试**：验证 is_player_entity 和 is_enemy_entity 函数能够正确识别各类实体，包括玩家本体、玩家召唤物、敌人生物、环境物体。

**速度修改测试**：验证 reduce_enemy_velocity 和 reduce_projectile_speed 函数能够正确修改目标实体的速度属性，且不会影响非目标实体。

### 5.2 集成测试

**基础功能测试**：在游戏中新开一局，验证敌人移动速度确实降低，敌人发射的投射物速度确实降低，玩家自身移动和投射物速度不受影响。

**边界情况测试**：测试减速倍率为 1.0 和 0.0 的极端情况，测试大量敌人同时存在时的性能表现，测试存档继承后的配置保持。

**兼容性测试**：测试与其他常见模组（如随机化模组、难度调整模组）的共存情况，测试在创意工坊版本和本地版本下的表现。

### 5.3 测试用例

| 用例编号 | 测试场景 | 预期结果 |
|----------|----------|----------|
| TC001 | 玩家移动 | 速度不受影响 |
| TC002 | 玩家发射火球 | 投射物速度正常 |
| TC003 | 敌人移动 | 速度降低至配置的倍率 |
| TC004 | 敌人发射投射物 | 投射物速度降低至配置的倍率 |
| TC005 | 玩家召唤物移动 | 速度不受影响 |
| TC006 | 玩家召唤物发射投射物 | 投射物速度不受影响 |
| TC007 | 存档加载后配置保持 | 配置正确恢复 |
| TC008 | 配置禁用模组 | 不产生任何减速效果 |

## 六、优化建议

### 6.1 性能优化

**减少 Update 循环频率**：当前方案在每帧遍历所有实体，可以考虑改为每 N 帧执行一次，或者仅在 OnEntityCreated 中处理，移除 Update 循环。

**使用标签过滤**：通过 EntityGetWithTag 获取特定标签的实体，而非遍历所有实体，减少不必要的检查。

**懒加载配置**：配置只在需要时加载，避免在 Update 循环中重复访问配置变量。

### 6.2 功能扩展

**动态减速**：根据游戏进程（如玩家死亡次数、当前关卡）自动调整减速倍率，增加游戏策略深度。

**敌人类型细分**：允许玩家为不同类型的敌人设置不同的减速倍率，例如对精英怪减少减速效果。

**速度显示**：在 UI 上显示当前的速度倍率，让玩家直观了解模组效果。

### 6.3 用户体验优化

**配置界面**：添加游戏内配置界面，无需修改文件即可调整参数。

**预设方案**：提供"简单"、"普通"、"困难"等预设方案，方便玩家快速选择。

**兼容模式**：当检测到可能冲突的模组时，自动调整行为或提示用户。

## 七、发布计划

### 7.1 版本规划

**v1.0.0（首发版本）**：实现核心减速功能，默认配置提供适度的减速效果（敌人速度 70%，投射物速度 60%），仅包含必要的文件，文档齐全。

**v1.1.0**：添加游戏内配置界面，提供更多配置选项，优化性能表现，修复已知问题。

**v1.2.0**：支持敌人类型细分配置，添加动态减速功能，增加性能监控显示。

### 7.2 发布渠道

**Steam 创意工坊**：主要发布渠道，利用 Noita 内置的发布工具上传，需要准备宣传图片、详细说明、更新日志。

**GitHub 发布**：提供源码下载，供技术用户查看和二次开发，需要维护 README 和 ISSUE 页面。

### 7.3 文档准备

**README.md**：模组简介、功能说明、安装指南、配置说明、常见问题。

**CHANGELOG.md**：版本更新日志，记录每次更新的内容变化。

**LICENSE**：选择适当的开源许可证，建议使用 MIT License。

## 八、参考资源

**官方文档**：https://noita.wiki.gg/wiki/Modding

**社区 Wiki**：https://noita.fandom.com/wiki/Modding

**Lua API 参考**：https://noita.wiki.gg/wiki/Modding:_Lua_API

**组件文档**：参考 refer 目录下的 component_documentation.txt

**API 文档**：参考 refer 目录下的 lua_api_documentation.txt

## 九、官方API参考

### 核心API函数

```lua
-- 实体操作
EntityGetWithName(name:string) -> entity_id:int
EntityGetWithTag(tag:string) -> {entity_id:int}
EntityHasTag(entity_id:int, tag:string) -> bool
EntityExists(entity_id:int) -> bool
EntityGetName(entity_id:int) -> name:string

-- 组件操作
EntityGetFirstComponent(entity_id:int, component_type_name:string, tag:string = "") -> component_id|nil
ComponentGetValue2(component_id:int, field_name:string) -> multiple_types|nil
ComponentSetValue2(component_id:int, field_name:string, value_or_values:multiple_types)

-- 游戏状态
GameScheduleFunction(function_to_call:function, args:table, delay_frames:int)
GameGetFrameNum() -> int
```

### 组件字段说明

**VelocityComponent**
- `mVelocity` (vec2): 速度向量，包含 x 和 y 分量

**ProjectileComponent**
- `speed_min` (float): 最小速度
- `speed_max` (float): 最大速度
- `mWhoShot` (EntityID): 发射者实体ID（私有成员）

## 十、总结

### ❌ 不可行的方法

以下方法在实践中被发现**不可行**：

1. **直接修改 VelocityComponent.mVelocity**
   - Noita 的 AI 系统会在每帧重置速度值
   - 导致修改被覆盖或无限循环

2. **直接修改 CharacterPlatformingComponent.run_velocity**
   - 同样会被 AI 系统每帧重置
   - 无法实现持续减速

3. **OnEntityCreated + 一次性修改**
   - 实体创建时的修改会在后续帧被覆盖
   - 需要持续维护但性能开销大

### ✅ 最终实现方案

**慢速场（Slow Field）方案**：

1. 创建跟随玩家的慢速场实体
2. 每4帧检测范围内敌人和投射物
3. 对敌人应用游戏内置减速效果：
   - `INTERNAL_ICE` - 内部结冰减速
   - `MOVEMENT_SLOWER` - 直接减速
4. 对投射物直接修改 ProjectileComponent 和 VelocityComponent
5. 持续刷新效果保持减速

### 使用的游戏效果

| 效果 | 实体文件 | 描述 |
|------|----------|------|
| INTERNAL_ICE | effect_internal_ice.xml | 内部结冰，中等减速 |
| MOVEMENT_SLOWER | effect_movement_slower.xml | 直接减速 |

### 关键API

```lua
-- 实体检测
EntityGetInRadiusWithTag(x, y, radius, tag)

-- 效果应用
EntityLoad("data/entities/misc/effect_internal_ice.xml")
EntityAddChild(entity_id, effect_entity)

-- 效果刷新
ComponentGetValue2(effect_comp, "effect")
ComponentSetValue2(effect_comp, "frames", 600)
```

预计开发周期为 2-3 周，包括功能实现、测试优化和文档编写。首发版本可以提供稳定的核心功能，后续版本根据用户反馈逐步添加新特性。
