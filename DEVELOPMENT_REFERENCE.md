# Noita 模组开发参考

## 常用文件路径

### 游戏内置脚本路径

| 用途 | 路径 | 说明 |
|------|------|------|
| 工具库 | `data/scripts/lib/utilities.lua` | 包含 `get_players()`, `edit_component()` 等常用函数 |

### 模组内部路径

| 用途 | 路径模式 | 示例 |
|------|----------|------|
| 配置文件 | `mods/<mod_name>/files/...` | `mods/slow_enemies/files/scripts/slow_field.lua` |

## API 使用规范

### 文件加载

```lua
-- 使用 dofile_once 避免重复加载
dofile_once("mods/slow_enemies/files/scripts/config.lua")
```

### 实体操作

```lua
-- 获取玩家实体（使用标签）
local players = EntityGetWithTag("player_unit")

-- 获取位置
local x, y = EntityGetTransform(entity_id)

-- 检查实体是否存在
if EntityExists(entity_id) then ... end
```

### 组件读写

```lua
-- 读取值
local vx, vy = ComponentGetValue2(comp, "mVelocity")
local speed = ComponentGetValue2(comp, "speed_min")

-- 写入值
ComponentSetValue2(comp, "mVelocity", vx * mult, vy * mult)
ComponentSetValue2(comp, "speed_min", speed * mult)
```

## 常用标签 (Tags)

| 标签 | 含义 |
|------|------|
| `player_unit` | 玩家实体 |
| `enemy` | 敌人 |
| `mortal` | 可死亡的生物 |
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
    ├── init.lua             # 入口脚本
    └── files/
        ├── entities/
        │   └── field.xml    # 场实体
        └── scripts/
            └── main.lua     # 主逻辑
```

### mod.xml 示例

```xml
<?xml version="1.0" encoding="utf-8"?>
<mod format="1" name="Mod Name" description="Description">
    <load_order>50</load_order>
    <tags>gameplay, tweaks</tags>
</mod>
```

## 调试方法

```lua
-- 控制台输出
print("debug message")

-- 屏幕显示
GamePrint("on screen")

-- 视觉标记
DEBUG_MARK(x, y, "text", 0, 1, 1)
```

## 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `file doesn't exist` | 路径错误 | 检查文件路径 |
| 组件为nil | 时序问题 | 使用 `GameScheduleFunction()` 延迟 |

## 资源链接

- [Noita Wiki - Modding](https://noita.wiki.gg/wiki/Modding)
- [Noita Lua API](https://noita.wiki.gg/wiki/Modding:_Lua_API)
