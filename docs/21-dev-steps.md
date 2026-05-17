# 21 开发步骤（详细版）

本文档把路线图中的阶段 1-5 拆成可执行的最小步骤。每一步都应该能跑、能 commit、能在 git 历史里回滚。

阅读约定：
- 「📁」开头的是要创建的文件
- 「✏️」开头的是要编辑的现有文件
- 「✅」是验证步骤
- 代码块是建议的最小实现，不是抄写式答案

---

## 阶段 1 — 数据模型

### 1.1 创建目录骨架

📁 在项目根创建以下空目录：

```
scripts/
  cards/
    effects/
  status_effects/
    behaviors/
  relics/
    behaviors/
  enemies/
    ai/
  battle/
  autoloads/
  debug/
resources/
  cards/warrior/{basic,common,uncommon,rare}/
  status/
  relics/{warrior,common,uncommon,rare,boss,shop}/
  enemies/act1/
  encounters/act1/
  events/
  potions/
assets/
  sprites/
  audio/
  fonts/
```

PowerShell 一行搞定：

```powershell
"scripts/cards/effects","scripts/status_effects/behaviors","scripts/relics/behaviors","scripts/enemies/ai","scripts/battle","scripts/autoloads","scripts/debug","resources/cards/warrior/basic","resources/cards/warrior/common","resources/cards/warrior/uncommon","resources/cards/warrior/rare","resources/status","resources/relics/warrior","resources/relics/common","resources/relics/uncommon","resources/relics/rare","resources/relics/boss","resources/relics/shop","resources/enemies/act1","resources/encounters/act1","resources/events","resources/potions","assets/sprites","assets/audio","assets/fonts" | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
```

### 1.2 定义 `Card` 资源类

📁 `scripts/cards/card.gd`

```gdscript
class_name Card extends Resource

enum Type { ATTACK, SKILL, POWER, STATUS, CURSE }
enum Rarity { BASIC, COMMON, UNCOMMON, RARE, SPECIAL }
enum Target { ENEMY, ALL_ENEMIES, SELF, NONE, RANDOM_ENEMY }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var cost: int = 1            # -1 = X 费
@export var type: Type
@export var rarity: Rarity
@export var target: Target = Target.ENEMY
@export var effects: Array[CardEffect]
@export var icon: Texture2D
@export var exhaust: bool = false
@export var ethereal: bool = false
@export var innate: bool = false
@export var retain: bool = false

@export_group("Upgrade")
@export var upgraded: bool = false
@export var upgrade_overrides: Dictionary  # 字段名 -> 升级后的值
```

### 1.3 定义 `CardEffect` 基类与几个子类

📁 `scripts/cards/effects/card_effect.gd`

```gdscript
class_name CardEffect extends Resource

func apply(context: CardPlayContext) -> void:
    push_error("CardEffect.apply() must be overridden")
```

📁 `scripts/cards/effects/deal_damage.gd`

```gdscript
class_name DealDamage extends CardEffect

@export var amount: int
@export var times: int = 1
@export var hits_all: bool = false

func apply(ctx: CardPlayContext) -> void:
    var targets := ctx.targets if not hits_all else ctx.all_enemies
    for _i in range(times):
        for t in targets:
            BattleManager.deal_damage(ctx.source, t, amount, true)  # is_attack=true
```

📁 `scripts/cards/effects/gain_block.gd`

```gdscript
class_name GainBlock extends CardEffect

@export var amount: int

func apply(ctx: CardPlayContext) -> void:
    BattleManager.add_block(ctx.source, amount)
```

📁 `scripts/cards/effects/apply_status.gd`

```gdscript
class_name ApplyStatusEffect extends CardEffect

@export var status_id: StringName
@export var stacks: int = 1
@export var to_self: bool = false

func apply(ctx: CardPlayContext) -> void:
    var target := ctx.source if to_self else ctx.targets[0]
    BattleManager.apply_status(ctx.source, target, status_id, stacks)
```

📁 `scripts/cards/effects/draw_cards.gd`

```gdscript
class_name DrawCards extends CardEffect

@export var count: int = 1

func apply(ctx: CardPlayContext) -> void:
    BattleManager.draw_cards(count)
```

### 1.4 定义 `CardPlayContext`

📁 `scripts/cards/card_play_context.gd`

```gdscript
class_name CardPlayContext extends RefCounted

var card: Card
var source: Actor           # 通常是 Player
var targets: Array[Actor]   # 玩家选的目标（可能为空，如 Target.NONE）
var all_enemies: Array[Enemy]
```

### 1.5 定义 `EnemyData` / `EnemyMove`

📁 `scripts/enemies/enemy_data.gd`

```gdscript
class_name EnemyData extends Resource

enum Tier { NORMAL, ELITE, BOSS }

@export var id: StringName
@export var display_name: String
@export var hp_min: int
@export var hp_max: int
@export var sprite: Texture2D
@export var tier: Tier
@export var act: int = 1
@export var move_set: Array[EnemyMove]
@export var move_ai_script: GDScript    # null 时用默认加权随机
```

📁 `scripts/enemies/enemy_move.gd`

```gdscript
class_name EnemyMove extends Resource

enum Intent { ATTACK, DEFEND, ATTACK_DEFEND, BUFF, DEBUFF, SPECIAL, STUNNED, UNKNOWN }

@export var id: StringName
@export var intent: Intent
@export var damage: int = 0
@export var multi_hits: int = 1
@export var block: int = 0
@export var status_to_apply: StringName  # &"" 表示无
@export var status_stacks: int = 0
@export var weight: float = 1.0
@export var max_uses_in_a_row: int = -1  # -1 = 无限
```

### 1.6 创建首张测试卡 + 首个测试敌人

✏️ 在 Godot 编辑器里：
- 新建资源 `resources/cards/warrior/basic/basic_strike.tres`，类型 `Card`，填字段：id=`basic_strike`, name=`Strike`, cost=1, type=ATTACK, rarity=BASIC, target=ENEMY, effects=[DealDamage(amount=6)]
- 新建资源 `resources/enemies/act1/training_dummy.tres`，类型 `EnemyData`，填字段：id=`training_dummy`, name=`Training Dummy`, hp_min=20, hp_max=20, tier=NORMAL, move_set=[一个攻击 5 伤害的 move]

### 1.7 提交

```
git add scripts/ resources/
git commit -m "Phase 1: Card / Enemy / Effect resource classes + first test data"
git tag v0.1-data-model
```

✅ **完成判据**：在编辑器里能打开 `basic_strike.tres`，所有字段正确显示，能保存退出再打开仍然一致。

---

## 阶段 2 — 战斗核心（控制台）

### 2.1 事件总线

📁 `scripts/autoloads/battle_events.gd`

```gdscript
extends Node

signal battle_started
signal turn_started(actor)
signal turn_ended(actor)
signal card_drawn(card)
signal card_played(card, targets)
signal card_resolved(card)
signal card_discarded(card)
signal card_exhausted(card)
signal damage_intent(ctx)      # ctx 是可修改的 DamageContext
signal damage_dealt(source, target, amount, blocked)
signal block_gained(target, amount)
signal status_applied(target, status_id, stacks)
signal enemy_intent_changed(enemy, intent)
signal battle_won
signal battle_lost
```

✏️ 在 Project Settings → Autoload 注册：`BattleEvents` → `res://scripts/autoloads/battle_events.gd`

### 2.2 `Actor` 基类

📁 `scripts/battle/actor.gd`

```gdscript
class_name Actor extends Node

@export var max_hp: int
var hp: int
var block: int = 0
var status_holder: StatusHolder

func take_damage(amount: int) -> int:
    var blocked := min(block, amount)
    block -= blocked
    var actual := amount - blocked
    hp = max(hp - actual, 0)
    return actual

func add_block(amount: int) -> void:
    block += amount
    BattleEvents.block_gained.emit(self, amount)

func is_dead() -> bool:
    return hp <= 0
```

### 2.3 `Player` / `Enemy` 运行时

📁 `scripts/battle/player.gd`

```gdscript
class_name Player extends Actor

var deck: Array[Card]                # 副本（战斗内可修改）
var draw_pile: Array[Card]
var hand: Array[Card]
var discard_pile: Array[Card]
var exhaust_pile: Array[Card]
var energy: int = 0
var max_energy: int = 3
```

📁 `scripts/battle/enemy.gd`

```gdscript
class_name Enemy extends Actor

var data: EnemyData
var next_move: EnemyMove
var move_history: Array[EnemyMove]   # 用于约束 max_uses_in_a_row

func roll_next_move() -> EnemyMove:
    # 默认 AI：加权随机 + max_uses_in_a_row 过滤
    var candidates := data.move_set.filter(func(m): return _can_use(m))
    var total := candidates.reduce(func(acc, m): return acc + m.weight, 0.0)
    var pick := randf() * total
    var cum := 0.0
    for m in candidates:
        cum += m.weight
        if pick <= cum:
            return m
    return candidates[0]
```

### 2.4 `BattleManager`

📁 `scripts/autoloads/battle_manager.gd`

```gdscript
extends Node

var player: Player
var enemies: Array[Enemy]
var rng: RandomNumberGenerator

func start_battle(deck: Array[Card], encounter: Encounter) -> void:
    player = Player.new()
    player.deck = deck.duplicate()
    player.draw_pile = deck.duplicate()
    player.draw_pile.shuffle()
    player.hand = []
    player.discard_pile = []
    enemies = encounter.enemies.map(func(d): return _spawn_enemy(d))
    BattleEvents.battle_started.emit()
    _start_player_turn()

func _start_player_turn() -> void:
    player.energy = player.max_energy
    player.block = 0
    draw_cards(5)
    for e in enemies:
        e.next_move = e.roll_next_move()
        BattleEvents.enemy_intent_changed.emit(e, e.next_move.intent)
    BattleEvents.turn_started.emit(player)

func play_card(card: Card, targets: Array[Actor]) -> bool:
    if card.cost > player.energy: return false
    player.energy -= card.cost
    var ctx := CardPlayContext.new()
    ctx.card = card
    ctx.source = player
    ctx.targets = targets
    ctx.all_enemies = enemies.filter(func(e): return not e.is_dead())
    BattleEvents.card_played.emit(card, targets)
    for eff in card.effects:
        eff.apply(ctx)
    player.hand.erase(card)
    if card.exhaust:
        player.exhaust_pile.append(card)
        BattleEvents.card_exhausted.emit(card)
    else:
        player.discard_pile.append(card)
        BattleEvents.card_discarded.emit(card)
    BattleEvents.card_resolved.emit(card)
    _check_battle_end()
    return true

func end_player_turn() -> void:
    BattleEvents.turn_ended.emit(player)
    for c in player.hand.duplicate():
        player.discard_pile.append(c)
    player.hand.clear()
    player.block = 0
    _enemy_turn()

func _enemy_turn() -> void:
    for e in enemies:
        if e.is_dead(): continue
        BattleEvents.turn_started.emit(e)
        _execute_move(e, e.next_move)
        BattleEvents.turn_ended.emit(e)
    _check_battle_end()
    if not _is_over():
        _start_player_turn()

func deal_damage(source, target, amount: int, is_attack: bool) -> void:
    var ctx := DamageContext.new()
    ctx.source = source
    ctx.target = target
    ctx.amount = amount
    ctx.is_attack = is_attack
    BattleEvents.damage_intent.emit(ctx)  # 状态/遗物在这里修改 ctx.amount
    var blocked := min(target.block, ctx.amount)
    var actual := target.take_damage(ctx.amount)
    BattleEvents.damage_dealt.emit(source, target, actual, blocked)

func add_block(actor, amount: int) -> void:
    actor.add_block(amount)

func apply_status(source, target, status_id: StringName, stacks: int) -> void:
    target.status_holder.apply(status_id, stacks)

func draw_cards(count: int) -> void:
    for _i in count:
        if player.hand.size() >= 10: return
        if player.draw_pile.is_empty():
            if player.discard_pile.is_empty(): return
            player.draw_pile = player.discard_pile.duplicate()
            player.draw_pile.shuffle()
            player.discard_pile.clear()
        var c: Card = player.draw_pile.pop_back()
        player.hand.append(c)
        BattleEvents.card_drawn.emit(c)
```

注册 autoload：`BattleManager`。

### 2.5 调试入口（控制台战斗）

📁 `scripts/debug/test_battle.gd`

```gdscript
extends Node

func _ready() -> void:
    var deck: Array[Card] = []
    for _i in 5:
        deck.append(preload("res://resources/cards/warrior/basic/basic_strike.tres"))
    for _i in 5:
        deck.append(preload("res://resources/cards/warrior/basic/basic_block.tres"))
    var encounter := preload("res://resources/encounters/act1/training.tres")

    _wire_console_log()
    BattleManager.start_battle(deck, encounter)

    # 模拟玩家：能出就出，直到结束回合
    await _player_turn_auto()
    BattleManager.end_player_turn()
    # ...
```

### 2.6 验证 + 提交

✅ 在编辑器中把临时主场景设为 `test_battle.tscn`（一个 Node + 上面的脚本），运行后控制台应该打印完整一回合的事件。

```
git add scripts/
git commit -m "Phase 2: Battle core with event bus + console-only flow"
git tag v0.2-battle-core
```

---

## 阶段 3 — 状态效果

### 3.1 `StatusHolder` 节点

📁 `scripts/status_effects/status_holder.gd`

```gdscript
class_name StatusHolder extends Node

var stacks: Dictionary[StringName, int] = {}
var behaviors: Dictionary[StringName, Node] = {}

func apply(status_id: StringName, amount: int) -> void:
    if not stacks.has(status_id):
        stacks[status_id] = 0
        var data: StatusEffect = StatusRegistry.get(status_id)
        var b := data.behavior_script.new()
        b.owner_actor = get_parent()
        add_child(b)
        behaviors[status_id] = b
    stacks[status_id] += amount
    BattleEvents.status_applied.emit(get_parent(), status_id, stacks[status_id])

func get_stacks(id: StringName) -> int:
    return stacks.get(id, 0)

func on_turn_end_decay() -> void:
    for id in stacks.keys().duplicate():
        var data: StatusEffect = StatusRegistry.get(id)
        if data.decay_rule == StatusEffect.DecayRule.TURN_END_DECREMENT:
            stacks[id] -= 1
            if stacks[id] <= 0:
                _remove(id)
```

### 3.2 `DamageContext`（伤害修饰链）

📁 `scripts/battle/damage_context.gd`

```gdscript
class_name DamageContext extends RefCounted

var source: Actor
var target: Actor
var amount: int
var is_attack: bool
var is_blocked: bool = true
```

✏️ `battle_manager.gd` `deal_damage`：用 `damage_intent` emit，让监听者修改 `ctx.amount`，再用 `ctx.amount` 实际结算。

### 3.3 行为脚本：力量

📁 `scripts/status_effects/behaviors/strength_behavior.gd`

```gdscript
class_name StrengthBehavior extends Node

var owner_actor: Actor
var status_id: StringName = &"strength"

func _ready() -> void:
    BattleEvents.damage_intent.connect(_on_damage_intent)

func _on_damage_intent(ctx: DamageContext) -> void:
    if ctx.source == owner_actor and ctx.is_attack:
        ctx.amount += owner_actor.status_holder.get_stacks(status_id)
```

### 3.4 行为脚本：易伤、虚弱、虚空

同样的套路。易伤是 `ctx.target == owner_actor` 且 `ctx.amount = int(ctx.amount * 1.5)`。

### 3.5 状态注册表

📁 `scripts/autoloads/status_registry.gd`

```gdscript
extends Node

var _registry: Dictionary[StringName, StatusEffect]

func _ready() -> void:
    _load_all()

func _load_all() -> void:
    var dir := DirAccess.open("res://resources/status/")
    for f in dir.get_files():
        if f.ends_with(".tres"):
            var s: StatusEffect = load("res://resources/status/" + f)
            _registry[s.id] = s

func get(id: StringName) -> StatusEffect:
    return _registry[id]
```

注册 autoload：`StatusRegistry`。

### 3.6 测试 + 提交

写一个单元测试场景：手动给 player 加力量 3，对一个易伤敌人出基础攻击（6 伤害），期望伤害 = (6+3)×1.5 = 13。

```
git commit -m "Phase 3: Status effect system + strength/vulnerable/weak/frail"
git tag v0.3-status
```

---

## 阶段 4 — 敌人 AI

### 4.1 默认 AI（已在 enemy.gd 实现）

加上 `max_uses_in_a_row` 约束。

### 4.2 自定义 AI 接口

📁 `scripts/enemies/ai/enemy_ai.gd`

```gdscript
class_name EnemyAI extends RefCounted

func pick_move(enemy: Enemy) -> EnemyMove:
    push_error("EnemyAI.pick_move must be overridden")
    return null
```

### 4.3 示例：固定循环 AI

📁 `scripts/enemies/ai/fixed_loop_ai.gd`

```gdscript
class_name FixedLoopAI extends EnemyAI

func pick_move(enemy: Enemy) -> EnemyMove:
    var i := enemy.move_history.size() % enemy.data.move_set.size()
    return enemy.data.move_set[i]
```

### 4.4 示例：蓄力 + 强制释放 AI

蓄力模式：上一招是「Charge」时，下一招必须是「Charged Strike」。用脚本判断 last_move。

### 4.5 提交

```
git commit -m "Phase 4: Enemy AI variants + intent rolling"
git tag v0.4-ai
```

---

## 阶段 5 — 战斗 UI（关键）

这一阶段工作量最大。建议子步骤：

### 5.1 战斗场景骨架

📁 `scenes/battle/battle.tscn`

```
Battle (Node2D)
├── Background (ColorRect 或 TextureRect)
├── EnemyContainer (HBoxContainer，敌人横排)
├── PlayerPanel (左下角)
│   ├── HPBar
│   ├── BlockIcon
│   └── StatusBar
├── HandContainer (底部居中，自定义 Control 实现扇形)
├── EnergyDisplay (左下圆形)
├── PileIndicators (Draw / Discard / Exhaust 计数)
├── EndTurnButton (右下)
└── UILayer (CanvasLayer：tooltip、飘字、奖励界面入口)
```

### 5.2 卡牌视觉节点

📁 `scenes/battle/card_view.tscn` + `scripts/battle/card_view.gd`

- 输入：Card 资源
- 显示：费用、名字、描述、插图、底框颜色
- 状态：normal / hover / dragging / disabled
- 动画：hover 时上浮 20px、放大 1.1x

### 5.3 手牌容器（扇形布局）

`HandContainer` 自定义 `_process` 计算每张卡的位置/旋转，按总数自动调整扇形角度。

### 5.4 拖动出牌

`CardView` 接 `_gui_input`：按下 → 进入 drag 模式 → 鼠标释放时根据释放位置决定：
- 在敌人上：触发 `play_card(self, [enemy])`
- 在屏幕中部（非目标卡）：触发 `play_card(self, [])`
- 在手牌位置：取消

### 5.5 敌人视图

📁 `scenes/battle/enemy_view.tscn`

- HP 条
- Block 图标 + 数字（无 block 时隐藏）
- 意图图标 + 数字（不同 intent 不同图标）
- 状态条

### 5.6 反馈动画

- 受击红闪 + 抖动
- 飘字（伤害数字、护甲数字、状态数字）
- 抽牌弧线动画（从 draw_pile 飞到手牌）
- 出牌动画（卡飞到目标上爆掉）

### 5.7 提交

```
git commit -m "Phase 5: Battle UI - playable visual combat"
git tag v0.5-battle-ui
```

---

## 后续阶段速写

之后的阶段在 [20-dev-roadmap.md](20-dev-roadmap.md) 里有大纲。每个阶段开始前，先回这份文档对应阶段补充详细步骤，再开工。

不要试图一次性写完所有阶段的步骤——边做边写，因为前面的实现常常会改变后面的设计。

---

## 通用规则

1. **每个阶段结束前必须能跑**。不能跑就是没完成。
2. **每个阶段结束 commit + tag**。tag 命名 `v0.{编号}-{简称}`。
3. **新功能写最简实现先跑通，再优化**。例如手牌扇形，先用直线排列，跑通后再做扇形。
4. **遇到不确定的设计先看 docs/，没写的话先写设计文档再写代码**。
5. **拒绝 over-engineering**：MVP 阶段不要做事件分阶段优先级、不要做卡牌动画缓动曲线，先把功能跑通。

---

## 第一次提交建议

完成 1.1（目录骨架）后立即 commit。让所有空目录用 `.gitkeep` 占位（Godot 自己会为有内容的目录生成 `.gdignore`）：

```powershell
Get-ChildItem -Directory -Recurse | Where-Object { $_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0 } | ForEach-Object { New-Item -ItemType File -Path "$($_.FullName)\.gitkeep" -Force | Out-Null }
```

```
git add .
git commit -m "Phase 1.1: Directory scaffold"
```
