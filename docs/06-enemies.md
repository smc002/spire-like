# 06 敌人

## 敌人结构

```gdscript
class_name EnemyData extends Resource

@export var id: StringName
@export var display_name: String
@export var hp_min: int
@export var hp_max: int   # 实际 HP 在范围内随机
@export var sprite: Texture2D
@export var tier: Tier    # NORMAL / ELITE / BOSS
@export var act: int      # 在哪一幕出现

# 意图序列（AI 决策树）
@export var move_set: Array[EnemyMove]
@export var move_ai_script: GDScript  # 自定义 AI 行为
```

## 意图系统

每个敌人在自己回合结束时决定下回合的「意图」。意图必须在玩家行动前公开显示，给玩家计算应对的依据。

意图类型：

| 类型 | 显示 | 玩家可见信息 |
|------|------|------------|
| 攻击 | 拳头图标 + 伤害数字 | 具体伤害值（已计入虚弱/易伤等） |
| 多段攻击 | 拳头 + "× N" | 单次伤害 + 段数 |
| 防御 | 盾牌图标 | 不显示具体护甲值 |
| 攻击+防御 | 拳头+盾牌 | 同上 |
| 增益 | 上升箭头 | 不显示具体 buff |
| Debuff | 向下箭头 | 不显示具体内容 |
| 特殊 | 问号 | 完全未知 |
| 蓄力 | 沙漏 | 暗示「下次攻击会很强」 |

```gdscript
class_name EnemyMove extends Resource

@export var id: StringName
@export var intent: IntentType
@export var damage: int = 0
@export var multi_hits: int = 1
@export var block: int = 0
@export var effects: Array[MoveEffect] = []  # 施加状态、召唤等
@export var weight: float = 1.0              # 在 AI 中的选择权重
@export var min_uses: int = 0                # 最少使用次数（如蓄力）
@export var max_uses_in_a_row: int = -1      # 最多连续使用次数（-1 = 无限）
```

## AI 决策

默认 AI 用「**带约束的加权随机**」：

```
candidates = all moves
filter: 移除超过 max_uses_in_a_row 的招
filter: 移除蓄力中应该出招的强制项
若有强制项 → 必选
否则 → 按 weight 加权随机
```

部分敌人需要自定义 AI（脚本式状态机），例如：

- **Boss A**：前 3 回合按固定脚本（攻击/防御/AOE 循环），第 4 回合后切换为加权随机
- **小怪 B**：HP < 50% 后必定召唤增援

## Act 1 敌人原型（MVP）

### 普通敌人（4-5 种）

| 原型 | HP 范围 | 主意图 | 行为特点 |
|------|--------|-------|---------|
| 小型生物-单体 | 12-15 | 攻击为主 | 偶尔施加易伤 |
| 小型生物-群体（2-3） | 各 8-10 | 攻击为主 | 数量压制 |
| 中型生物-蓄力 | 28-32 | 蓄力 + 重击循环 | 给玩家窗口反制 |
| 防御型 | 35-40 | 攻击/防御交替 | 教学护甲与穿透 |
| 状态师 | 18-22 | 施加虚弱/易伤 + 弱攻击 | 教学 debuff 应对 |

### 精英敌人（2 种）

| 原型 | HP | 难点 | 奖励 |
|------|----|----|------|
| 单体大型 | 70-80 | 高伤蓄力 + 阶段切换 | 1 遗物 + 25-35 金 |
| 双体配合 | 各 40-45 | 一攻一辅，分工杀手 | 1 遗物 + 25-35 金 |

### Boss（1-3 种）

| 原型 | HP | 难点 | 奖励 |
|------|----|----|------|
| 复合 Boss（多部位） | 80-100/部位 | 多部位独立 HP/意图 | 1 稀有遗物 + 大量金 + Boss 卡选项 |

## 敌人组合（Encounter）

普通战斗不是单个敌人而是「敌人组合」：

```gdscript
class_name Encounter extends Resource

@export var id: StringName
@export var enemies: Array[EnemyData]
@export var act: int
@export var tier: Encounter.Tier  # EASY / NORMAL / ELITE / BOSS
@export var min_floor: int        # 最早出现层
@export var max_floor: int        # 最晚出现层
```

Act 1 设计约 8-12 个普通组合：

| 组合类型 | 数量 |
|---------|-----|
| 单体大怪 | 2-3 |
| 双体小怪 | 3-4 |
| 三体小怪 | 2 |
| 1 大 + 1 小 | 1-2 |

层数约束：
- Layer 1 只能从「Easy」组合池里抽
- Layer 2-4 从「Normal Early」抽
- Layer 5-8 从「Normal Late」抽
- Layer 9-14 接近 Boss，强度递增

## 敌人意图模型（伪代码示例）

```gdscript
# scripts/enemies/enemy.gd
class_name Enemy extends Node2D

var data: EnemyData
var hp: int
var status_holder: StatusHolder
var next_move: EnemyMove

func roll_next_move() -> void:
    next_move = _pick_move()
    BattleEvents.enemy_intent_changed.emit(self, next_move.intent)

func execute_turn() -> void:
    for i in range(next_move.multi_hits):
        BattleManager.attempt_damage(self, BattleManager.player, next_move.damage)
    if next_move.block > 0:
        BattleManager.add_block(self, next_move.block)
    for effect in next_move.effects:
        effect.apply(self)
    roll_next_move()  # 决定下回合
```
