# 03 状态效果

## 衰减规则分类

| 衰减规则 | 行为 | 示例 |
|---------|------|------|
| `NONE` | 战斗结束才移除 | 力量、敏捷 |
| `TURN_END_DECREMENT` | 拥有者回合结束 -1，归零移除 | 易伤、虚弱 |
| `TURN_END_RESET` | 回合结束直接归零 | 护甲（特殊情况） |
| `ON_TRIGGER_DECREMENT` | 每次触发 -1 | 重击充能、X 次反伤 |
| `END_OF_BATTLE` | 战斗结束清除 | 多数 buff |

## 战士相关状态（MVP）

### 玩家可获得的正向

| 状态 | 效果 | 衰减 | 来源 |
|------|------|------|------|
| 力量（Strength） | 每点使攻击伤害 +1 | NONE | 力量类技能/能力 |
| 敏捷（Dexterity） | 每点使获得护甲 +1 | NONE | 部分稀有卡/遗物 |
| 暴怒（Rage） | 本回合每出 1 张攻击牌获 X 护甲 | 回合结束清除 | 暴怒类卡 |
| 金属化（Metallicize） | 回合结束自动 +X 护甲 | NONE | 金属化能力 |
| 荆棘（Thorns） | 被攻击时反伤 X | NONE | 荆棘卡/遗物 |
| 蓄能（Energized） | 下回合开始 +X 能量 | 触发后归零 | 部分卡/药水 |
| 屏障（Barricade） | 护甲不在回合结束清零 | NONE（能力） | 屏障能力 |

### 玩家可承受的负向

| 状态 | 效果 | 衰减 |
|------|------|------|
| 虚弱（Weak） | 造成攻击伤害 ×0.75 | TURN_END_DECREMENT |
| 易伤（Vulnerable） | 受到攻击伤害 ×1.5 | TURN_END_DECREMENT |
| 虚空（Frail） | 获得护甲 ×0.75 | TURN_END_DECREMENT |
| 中毒（Poison） | 回合开始受 X 伤害，然后 X -1 | 每次触发 -1 |
| 燃烧（Burn，源自手牌） | 回合结束若在手中受 2 伤害 | 见卡牌区 |
| 失能（Entangled） | 本回合不能出攻击牌 | 回合结束移除 |

### 数值平衡的关键规则

- **乘性 buff 互不叠加**：易伤 + 虚弱 = `0.75 × 1.5 = 1.125` 倍，不是 `+25%` 抵消
- **力量是加性**：力量 5 + 攻击牌写"造成 6 伤害" = 11 伤害
- **状态在伤害链中的顺序**：见 02 文档「优先级与拦截」

## 数据结构

```gdscript
# scripts/status_effects/status_effect.gd
class_name StatusEffect extends Resource

enum DecayRule { NONE, TURN_END_DECREMENT, TURN_END_RESET, ON_TRIGGER_DECREMENT, END_OF_BATTLE }
enum StackRule { ADD, REPLACE, MAX }

@export var id: StringName
@export var display_name: String
@export var description: String
@export var is_debuff: bool
@export var decay_rule: DecayRule
@export var stack_rule: StackRule = StackRule.ADD
@export var icon: Texture2D
@export var behavior_script: GDScript   # 实际行为脚本，订阅事件总线
```

每个状态有一个 **行为脚本**，构造时挂载到所属角色身上，订阅相关事件。例如：

```gdscript
# scripts/status_effects/behaviors/strength_behavior.gd
class_name StrengthBehavior extends Node

var owner_actor: Actor
var stacks: int

func _ready() -> void:
    BattleEvents.damage_intent.connect(_on_damage_intent)

func _on_damage_intent(ctx: DamageContext) -> void:
    if ctx.source == owner_actor and ctx.is_attack:
        ctx.amount += stacks
```

## 显示约定

- 每个状态在角色头像下显示图标 + 层数
- 鼠标悬停弹 tooltip：名称 + 描述 + 当前层数含义
- 负向用红色边框，正向用绿/金色
- 力量等核心 buff 显示靠左，临时回合状态显示靠右

## 状态注册表

为了让卡牌、遗物、敌人能用 `StringName` 引用状态而不直接 import，所有状态在 `autoloads/status_registry.gd` 中注册：

```gdscript
@onready var registry: Dictionary[StringName, StatusEffect] = {
    &"strength": preload("res://resources/status/strength.tres"),
    &"vulnerable": preload("res://resources/status/vulnerable.tres"),
    ...
}
```
