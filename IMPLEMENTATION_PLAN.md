# Noita 减速敌人模组实现规划

## 一、功能概述

本模组旨在降低游戏中除玩家外的所有生物（敌人）的移动速度，以及这些生物发射的投射物的飞行速度。模组不会对玩家自身或玩家发射的投射物产生任何影响。此功能可以降低游戏难度，为追求更轻松游戏体验的玩家提供选择。

核心设计原则是识别并区分玩家实体与非玩家实体，仅对后者应用速度修改。通过利用 Noita 的实体组件系统（ECS）和 Lua 脚本挂载机制，可以在实体创建时动态调整其速度相关组件的值。

## 二、可行性分析

### 2.1 技术可行性评估

**降低敌人移动速度：完全可行**

Noita 中的实体通过 VelocityComponent 控制移动速度。VelocityComponent 包含私有成员 `mVelocity`（vec2 类型，存储 x 和 y 分量）。实体创建时挂载 Lua 脚本，检测到敌人实体后，通过以下步骤修改速度：
1. 使用 `EntityGetFirstComponent` 获取 VelocityComponent
2. 使用 `ComponentGetValue2(comp, "mVelocity")` 获取当前速度向量
3. 使用 `ComponentSetValue2(comp, "mVelocity", vx * mult, vy * mult)` 设置减速后的速度

此方法基于官方 Lua API 实现，技术风险较低。

**降低敌人投射物速度：完全可行**

投射物通过 ProjectileComponent 管理，该组件包含 `speed_min` 和 `speed_max` 两个关键属性，分别定义投射物的最小和最大速度。在 OnEntityCreated 挂接函数中，识别敌人发射的投射物后：
1. 使用 `EntityGetFirstComponent` 获取 ProjectileComponent
2. 使用 `ComponentGetValue2(comp, "speed_min"/"speed_max")` 获取速度值
3. 使用 `ComponentSetValue2(comp, "speed_min"/"speed_max", value)` 设置减速后的速度

**排除玩家影响：完全可行**

Noita 实体系统支持标签（Tags）机制。玩家实体通常带有 "player" 标签，可以通过 `EntityGetWithTag` 或 `EntityHasTag` 函数识别。此外，ProjectileComponent 的私有成员 `mWhoShot`（类型为 EntityID）存储了投射物的发射者，可以追溯投射物的发射者，从而判断是否为玩家发射。通过多重验证机制，可以准确排除玩家相关实体。

### 2.2 实现方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| OnEntityCreated 挂接 | 实时处理，资源消耗低 | 需处理组件加载时序 |
| Update 循环批量处理 | 可处理遗漏实体 | 每帧遍历所有实体，性能开销大 |
| 脚本挂载游戏核心脚本 | 修改彻底，影响范围广 | 兼容性风险高 |

综合考虑性能和兼容性，推荐采用 OnEntityCreated 挂接为主、Update 循环为辅的混合方案。

### 2.3 风险评估

**组件加载时序风险**：EntityCreate 之后组件可能尚未完全初始化。解决方案是使用 `GameScheduleFunction` 延迟一帧处理，确保组件已加载完成。

**修改被覆盖风险**：游戏某些系统可能在后续帧重新设置组件值。解决方案是在 Update 循环中持续检查并应用修改，或提高修改的优先级。

**兼容性风险**：与其他修改敌人行为的模组可能存在冲突。解决方案是提供配置选项，允许玩家调整减速强度，并明确标注兼容性问题。

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

### 4.4 util.lua 工具函数脚本

```lua
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
    local player = EntityGetWithName("player")
    if player and #player > 0 then
        return player[1]
    end
    return nil
end
```

### 4.5 main.lua 主逻辑脚本

```lua
dofile("mods/slow_enemies/files/scripts/config.lua")
dofile("mods/slow_enemies/files/scripts/util.lua")

local processed_entities = {}

function reduce_enemy_velocity(entity_id)
    local velocity_component = EntityGetFirstComponent(entity_id, "Velocity")
    if velocity_component == nil then
        return
    end

    local mult = GetEnemySpeedMultiplier()
    if mult >= 1.0 then
        return
    end

    local vx, vy = ComponentGetValue2(velocity_component, "mVelocity")
    ComponentSetValue2(velocity_component, "mVelocity", vx * mult, vy * mult)

    if IsDebugEnabled() then
        print(string.format("[SlowEnemies] 减速实体 %d: (%.2f, %.2f) -> (%.2f, %.2f)",
            entity_id, vx, vy, vx * mult, vy * mult))
    end
end

function reduce_projectile_speed(entity_id)
    local projectile_component = EntityGetFirstComponent(entity_id, "Projectile")
    if projectile_component == nil then
        return
    end

    local mult = GetProjectileSpeedMultiplier()
    if mult >= 1.0 then
        return
    end

    local speed_min = ComponentGetValue2(projectile_component, "speed_min")
    local speed_max = ComponentGetValue2(projectile_component, "speed_max")
    ComponentSetValue2(projectile_component, "speed_min", speed_min * mult)
    ComponentSetValue2(projectile_component, "speed_max", speed_max * mult)

    if IsDebugEnabled() then
        print(string.format("[SlowEnemies] 减速投射物 %d: [%d-%d] -> [%d-%d]",
            entity_id, speed_min, speed_max, speed_min * mult, speed_max * mult))
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
    print(string.format("[SlowEnemies] 敌人速度倍率: %.2f", GetEnemySpeedMultiplier()))
    print(string.format("[SlowEnemies] 投射物速度倍率: %.2f", GetProjectileSpeedMultiplier()))
end
```

### 4.6 init.lua 入口脚本

```lua
dofile("mods/slow_enemies/files/scripts/main.lua")

function OnModPreInit()

end

function OnModInit()

end

function OnModPostInit()

end

function OnPlayerSpawned(player_entity)

end

function OnWorldInitialized()

end

function OnWorldPreUpdate()

end

function OnWorldPostUpdate()

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

本模组的技术实现基于 Noita 成熟的实体组件系统和 Lua 脚本挂载机制，核心功能完全可行。主要技术要点包括：

1. 使用 `OnEntityCreated` 挂接函数监听实体创建事件
2. 使用 `EntityGetFirstComponent` 获取目标组件
3. 使用 `ComponentGetValue2` 和 `ComponentSetValue2` 读取/修改组件值
4. 通过标签和 `mWhoShot` 属性区分玩家与敌人实体
5. 混合使用立即处理和 Update 循环确保修改生效

**关键API更正**：
- 不存在 `EntityModify` 函数
- 不存在 `EntitySetComponentValue` 函数
- 使用 `ComponentGetValue2(component_id, field_name)` 而非 `ComponentGetValue2(entity_id, component_name, field_name)`
- 投射物发射者字段为 `mWhoShot` 而非 `m_shooter_entity_id`
- 速度向量字段为 `mVelocity`（vec2 类型）

预计开发周期为 2-3 周，包括功能实现、测试优化和文档编写。首发版本可以提供稳定的核心功能，后续版本根据用户反馈逐步添加新特性。
