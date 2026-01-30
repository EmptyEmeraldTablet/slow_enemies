# Noita 模组开发参考

## 常用文件路径

### 游戏内置脚本路径

| 用途 | 路径 | 说明 |
|------|------|------|
| 工具库 | `data/scripts/lib/utilities.lua` | 包含 `get_players()`, `edit_component()` 等常用函数 |
| Perk系统 | `data/scripts/perks/perk.lua` | Perk相关功能 |
| Perk列表 | `data/scripts/perks/perk_list.lua` | 可用Perk列表 |
| 导演助手 | `data/scripts/director_helpers.lua` | 游戏生成相关 |
| 物品脚本 | `data/scripts/items/...` | 物品相关脚本 |

### 模组内部路径

| 用途 | 路径模式 | 示例 |
|------|----------|------|
| 配置文件 | `mods/<mod_name>/files/...` | `mods/slow_enemies/files/scripts/main.lua` |
| 资源文件 | `mods/<mod_name>/files/...` | `mods/slow_enemies/files/gfx/image.png` |

## API 使用规范

### 文件加载

```lua
-- 使用 dofile_once 避免重复加载
dofile_once("mods/slow_enemies/files/scripts/config.lua")

-- 游戏内置脚本（如果需要）
dofile_once("data/scripts/lib/utilities.lua")
```

### 实体操作

```lua
-- 获取玩家实体（使用标签）
local players = EntityGetWithTag("player_unit")  -- 返回表

-- 获取单个实体
local entity_id = EntityGetWithName("name")

-- 获取位置（返回多个值）
local x, y, rotation, scale_x, scale_y = EntityGetTransform(entity_id)

-- 检查实体是否存在
if EntityExists(entity_id) then ... end

-- 获取第一个组件
local comp = EntityGetFirstComponent(entity_id, "Velocity")
```

### 组件读写

```lua
-- 读取值（V2 API）
local vx, vy = ComponentGetValue2(comp, "mVelocity")
local speed = ComponentGetValue2(comp, "speed_min")

-- 写入值
ComponentSetValue2(comp, "mVelocity", vx * mult, vy * mult)
ComponentSetValue2(comp, "speed_min", speed * mult)
```

### 游戏状态

```lua
-- 单次执行标志（防止重复初始化）
if GameHasFlagRun("my_mod_init") then return end
GameAddFlagRun("my_mod_init")

-- 延迟执行
GameScheduleFunction(function()
    -- 1帧后执行的代码
end, {}, 1)

-- 获取帧数
local frame = GameGetFrameNum()
```

### 调试函数

```lua
-- 控制台输出
print("message")
GamePrint("message")  -- 屏幕显示
GamePrintImportant("title", "description")

-- 调试标记
DEBUG_MARK(x, y, "message", r, g, b)  -- r,g,b ∈ [0,1]

-- 鼠标位置
local mx, my = DEBUG_GetMouseWorld()
```

## 常用标签 (Tags)

| 标签 | 含义 |
|------|------|
| `player_unit` | 玩家实体 |
| `enemy` | 敌人 |
| `mortal` | 可死亡的生物 |
| `character` | 角色 |
| `projectile` | 投射物 |

## 组件字段参考

### VelocityComponent

| 字段 | 类型 | 说明 |
|------|------|------|
| `mVelocity` | vec2 | 速度向量 (x, y) |

### ProjectileComponent

| 字段 | 类型 | 说明 |
|------|------|------|
| `speed_min` | float | 最小速度 |
| `speed_max` | float | 最大速度 |
| `mWhoShot` | EntityID | 发射者实体ID |

## 模组结构规范

```
mods/
└── <mod_name>/
    ├── mod.xml              # 模组元数据
    ├── init.lua             # 入口脚本（定义On*钩子）
    ├── config.txt           # 用户配置（可选）
    └── files/
        └── scripts/
            ├── main.lua     # 主逻辑
            ├── config.lua   # 配置加载
            └── util.lua     # 工具函数
```

### mod.xml 示例

```xml
<?xml version="1.0" encoding="utf-8"?>
<mod format="1" name="Mod Name" description="Description">
    <load_order>50</load_order>
    <tags>gameplay, tweaks</tags>
</mod>
```

### init.lua 模板

```lua
dofile_once("mods/<mod_name>/files/scripts/main.lua")

function OnModPreInit()
    -- 游戏启动前
end

function OnModInit()
    -- 模组初始化
end

function OnModPostInit()
    -- 模组初始化后
end

function OnWorldInitialized()
    -- 世界生成
end

function OnPlayerSpawned(player_entity)
    -- 玩家生成
end

function OnEntityCreated(entity_id)
    -- 实体创建
end

function OnEntityDestroyed(entity_id)
    -- 实体销毁
end

function Update()
    -- 每帧更新
end
```

## 调试方法

### 1. 控制台输出
```lua
print("debug message")
```

### 2. 屏幕显示
```lua
GamePrint("on screen")
```

### 3. 视觉标记
```lua
DEBUG_MARK(x, y, "text", 0, 1, 1)  -- 青色标记
```

### 4. 启动参数
```
noita.exe -debug_lua
```

> ⚠️ `-debug_lua` 参数会启用 Lua 沙盒逃逸漏洞，不要在启用未知模组时使用。

## 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `file doesn't exist` | 路径错误 | 使用 `data/scripts/lib/` 前缀 |
| 重复执行 | 缺少初始化标志 | 使用 `GameHasFlagRun()` |
| 组件为nil | 时序问题 | 使用 `GameScheduleFunction()` 延迟 |
| 玩家检测失败 | 标签错误 | 使用 `player_unit` 而非 `player` |

## 资源链接

- [Noita Wiki - Modding](https://noita.wiki.gg/wiki/Modding)
- [Noita Lua API](https://noita.wiki.gg/wiki/Modding:_Lua_API)
- [社区 Discord](https://discord.gg/noita)
