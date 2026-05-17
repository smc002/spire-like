# 07 遗物

## 概念

遗物是跑团内永久生效的被动效果，无槽位上限。来源：起手、战斗奖励、商店、事件、宝箱。

## 稀有度

| 稀有度 | 来源 | 强度 |
|--------|------|------|
| 起手（Starter） | 每职业固定 1 个 | 中等且与职业强耦合 |
| 普通（Common） | 普通战斗奖励、商店 | 持续小增益 |
| 不普通（Uncommon） | 精英战斗、事件、商店 | 条件触发的中等增益 |
| 稀有（Rare） | 精英战斗、事件、商店 | 强力 |
| Boss | Boss 击杀后三选一 | 极强但常有负面 |
| 特殊（Special） | 仅事件 | 多样化 |
| 商店 | 仅商店 | 与稀有度无关 |

## 触发器

每个遗物在某些事件发生时生效。MVP 实现这些触发类：

| 触发器 | 时机 |
|--------|------|
| `OnCombatStart` | 战斗开始 |
| `OnTurnStart` | 玩家回合开始 |
| `OnTurnEnd` | 玩家回合结束 |
| `OnCardPlayed` | 任意卡牌出牌 |
| `OnAttackCardPlayed` | 攻击牌出牌 |
| `OnDamageDealt` | 玩家造成伤害 |
| `OnDamageTaken` | 玩家受伤 |
| `OnHPLow` | HP 跌至 ≤50% |
| `OnRestSite` | 抵达篝火 |
| `OnMapTraversal` | 每完成一节点 |
| `OnCardObtained` | 获得新卡 |
| `OnGoldGained` | 获得金币 |
| `OnFloorEntered` | 进入新层 |
| `Passive` | 全局被动（数值修饰） |

## 战士相关遗物（MVP ~12 种）

具体名字与图标实现时再起；这里列设计原型：

### 起手（必有 1 个）

| 原型 | 效果 |
|------|------|
| 战士起手 | 战斗结束回 6 HP |

### 普通（~5 种）

| 原型 | 效果 |
|------|------|
| 战斗后小回血 | 战斗胜利后回 X HP |
| 受击护甲增益 | 受到 ≥ 5 伤害时，本回合获得 3 护甲 |
| 首回合护甲 | 战斗开始获得 X 护甲 |
| 弃牌奖励 | 每弃 1 张牌触发 X 伤害（或抽 1） |
| 抽牌增加 | 战斗开始多抽 X 张 |

### 不普通（~3 种）

| 原型 | 效果 |
|------|------|
| 力量减衰反制 | 力量被减时不触发 |
| 精英奖励增强 | 精英战斗多 1 张卡选项 |
| 商店折扣 | 商店打 9 折 |

### 稀有（~2 种）

| 原型 | 效果 |
|------|------|
| 能量上限 +1 | 每回合多 1 能量（强但 Boss 池常见） |
| 每回合首伤无效 | 每回合第一次受到伤害归零 |

### 特殊（事件用，~1 种）

| 原型 | 效果 |
|------|------|
| 诅咒承载 | 携带时可承受 1 张诅咒不进卡组 |

## 数据结构

```gdscript
class_name RelicData extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var rarity: Rarity
@export var trigger: TriggerType
@export var icon: Texture2D
@export var behavior_script: GDScript  # 实际行为
@export var class_restricted: StringName = &""  # 仅特定职业可获得，&"" = 通用
@export var pool: Pool                 # COMBAT / SHOP / BOSS / SPECIAL（决定能从哪个池里出）
```

行为脚本类似状态效果，订阅事件总线：

```gdscript
# scripts/relics/behaviors/start_combat_block.gd
class_name StartCombatBlockRelic extends Node

var amount: int = 3

func _ready() -> void:
    BattleEvents.battle_started.connect(_on_battle_started)

func _on_battle_started() -> void:
    BattleManager.add_block(BattleManager.player, amount)
```

## 显示

- 遗物图标横排显示在屏幕顶部
- 鼠标悬停 → tooltip（名称、稀有度、效果描述）
- 战斗中触发时遗物图标闪烁/抖动 + 飘字

## 池子管理

`RelicPool` 单例维护：

```gdscript
var common_pool: Array[RelicData]
var uncommon_pool: Array[RelicData]
var rare_pool: Array[RelicData]
var boss_pool: Array[RelicData]
var shop_pool: Array[RelicData]
var special_pool: Array[RelicData]

# 已获得的从池中移除，避免重复
func draw(rarity: Rarity) -> RelicData:
    var pool := _get_pool(rarity)
    if pool.is_empty():
        return null
    return pool.pick_random()  # 用 seeded RNG
```
