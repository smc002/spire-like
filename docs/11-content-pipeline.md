# 11 内容流水线

## 设计原则

所有内容（卡、遗物、敌人、事件、状态）都用 Godot 的 `Resource` 系统配置，**数据与代码分离**：

- 数据 = `.tres` 文件，在编辑器里可视化编辑
- 行为 = `.gd` 脚本，通过订阅事件总线驱动
- 一个新卡 = 1 个数据文件（必要时 1 个行为脚本）

## 目录约定

```
resources/
  cards/
    warrior/
      basic/
        basic_attack.tres
        basic_block.tres
      common/
      uncommon/
      rare/
  status/
    strength.tres
    vulnerable.tres
    ...
  relics/
    warrior/
    common/
    ...
  enemies/
    act1/
  encounters/
    act1/
  events/
  potions/

scripts/
  cards/
    card.gd                  # Card 资源类定义
    effects/                 # 卡牌效果（伤害、护甲、施加状态…）
      effect.gd
      deal_damage.gd
      gain_block.gd
      apply_status.gd
      draw_cards.gd
      ...
  status_effects/
    status_effect.gd
    behaviors/
      strength_behavior.gd
      ...
  relics/
    relic.gd
    behaviors/
  enemies/
    enemy.gd
    enemy_move.gd
    ai/
```

## 如何添加一张卡

**Step 1 — 决定效果是否已有现成「Effect」实现**

如果是「造成伤害」「获得护甲」「抽牌」「施加状态」「能量增益」这类常见效果，已存在的 `Effect` 资源类应该足够。新卡只需配置数据。

**Step 2 — 在编辑器创建 `.tres`**

```
路径：resources/cards/warrior/common/heavy_strike.tres
类型：Card.tres
字段：
  id = "heavy_strike"
  display_name = "Heavy Strike"
  cost = 2
  type = ATTACK
  rarity = COMMON
  target = ENEMY
  effects = [
    DealDamage(amount=14)
  ]
```

升级版另开一个 `.tres`：

```
路径：resources/cards/warrior/common/heavy_strike_plus.tres
type = HEAVY_STRIKE 的复制 + amount=18
```

或者用 `upgrade_overrides: Dictionary` 字段在同一份资源中描述升级差异，避免文件膨胀（推荐）。

**Step 3 — 注册到牌池**

在 `resources/pools/warrior_pool.tres` 把新卡加进对应稀有度数组：

```
common_cards = [
  preload("res://resources/cards/warrior/common/heavy_strike.tres"),
  ...
]
```

或更优雅：用 `EditorPlugin` 自动扫描目录注册（这是 polish 阶段的事）。

**Step 4 — 验证**

- 启动游戏，进入战斗（debug 命令直接给自己这张卡）
- 出卡，确认伤害数值、消耗等行为正确

## 如何添加一种敌人

**Step 1 — 设计 moveset（草稿在文档里）**

| 回合 | 招式 | 效果 |
|-----|------|------|
| 1 | 攻击 | 8 伤害 |
| 2 | 防御 | 6 护甲 |
| 3 | 蓄力 | 下回合 +20 攻击 |
| 4 | 重击 | 22 伤害 |

**Step 2 — 创建 EnemyMove `.tres`** （每个招式一个文件）

**Step 3 — 创建 EnemyData `.tres`**

```
id = "shielded_brute"
hp_min = 32, hp_max = 38
tier = NORMAL
act = 1
move_set = [攻击, 防御, 蓄力, 重击]
move_ai_script = scripts/enemies/ai/shielded_brute.gd  # 自定义循环 1→2→3→4
```

**Step 4 — 加入 encounter 池**

```
resources/encounters/act1/normal_shielded_brute.tres
  enemies = [shielded_brute]
  tier = NORMAL
  min_floor = 4, max_floor = 8
```

## 如何添加一个状态效果

需要写行为脚本（通常）。

**Step 1 — `status_effect.tres`**

填基础数据（id、name、decay_rule、icon）。

**Step 2 — `behaviors/xxx_behavior.gd`**

订阅事件总线，实现修饰逻辑。

**Step 3 — 注册到 `status_registry`**

加一行：

```gdscript
&"new_status": preload("res://resources/status/new_status.tres"),
```

## 如何添加一个遗物

类似状态，多数都要写一个行为脚本。

**Step 1 — `relic.tres`**

**Step 2 — `behaviors/xxx_relic.gd`**

**Step 3 — 加入对应 pool（普通/不普通/稀有/Boss/商店）**

## 如何添加一个事件

通常只需 `event.tres` + 一两个 `consequence_script.gd`。简单事件可用通用 `consequence` 节点配置（例如「失去 HP X」「获得 Y 金」）。

## 调试工具（dev only）

`scripts/debug/dev_console.gd`：

| 命令 | 说明 |
|------|------|
| `give_card <id>` | 把指定卡放入手牌 |
| `give_relic <id>` | 立即获得遗物 |
| `set_hp <n>` | 修改 HP |
| `set_gold <n>` | 修改金币 |
| `set_energy <n>` | 当前能量 |
| `kill_all` | 当前战斗杀光所有敌人 |
| `apply <status> <stacks>` | 给自己施加状态 |
| `next_floor` | 跳到下一层 |
| `seed <n>` | 用指定 seed 重启跑团 |

按 `~` 打开，仅 debug 构建启用。
