# 05 地图与跑团

## Act 1 结构

一幕由 ~15 层组成，第 1 层是入口（玩家从底向上爬），最后一层是 Boss。中间层包含若干节点，节点之间用路径连接。

```
Layer 15 ─────── BOSS
Layer 14 ─────── 宝箱（强遗物）
Layer 13 ─────── 篝火（休息/升级）
Layer 12 ─────── 多个节点（精英/事件/普通/商店）
...
Layer 1  ─────── 入口（固定为普通战斗）
```

## 节点类型与分布

| 节点类型 | 标识 | Act 1 出现频率 | 说明 |
|---------|------|--------------|------|
| 普通战斗 | M | ~45% | 1-3 个普通敌人 |
| 精英战斗 | E | ~7% | 单个强力敌人，奖励含遗物 |
| 篝火 | R | ~12% | 回血 30% 或升级一张卡 |
| 商店 | $ | ~5% | 用金币买卡/遗物/药水/移卡 |
| 未知 | ? | ~22% | 触发随机事件（部分变成战斗/财宝） |
| 宝箱 | T | ~8% | 必出现，固定在某一层（如倒数第二层） |
| Boss | B | 末层 1 个 | 跑团目标 |

层数约束：
- Layer 1 始终是普通战斗
- 倒数第二层是宝箱
- 末层是 Boss
- Boss 前一层（倒数第三）固定篝火
- 精英不能出现在 Layer 1-4（让玩家先发育）
- 篝火不能出现在 Layer 1-5（同理）

## 地图生成算法（高层）

```
1. 在每层随机选 1-4 个节点位置（用列表示宽度）
2. 从入口出发，画 6 条向上的路径
   - 每步只能向上、左上、右上 移动一格
   - 路径不能交叉（两条路径不能在同一层共享一个节点然后又分叉）
3. 用前面的频率表给每个节点分配类型
   - 应用层数约束
   - 应用「同一玩家路径上不能连续 2 个相同类型」规则
4. 每个节点根据类型从对应池子里随机出具体战斗/事件
   - 普通战斗按层数从相应难度池抽
   - 精英从精英池抽
   - 事件从未出现过的事件池抽
```

详细的生成算法参考公开的 STS 地图分析（如 GitHub 上的 sts-mapgen）。MVP 实现一个简化版本即可：保证可达性、约束节点类型分布。

## 跑团状态

跑团数据用一个 `RunState` 单例持有，战斗、地图、事件、商店都从它读写：

```gdscript
class_name RunState extends Node  # autoload

@export var seed: int
@export var current_act: int = 1
@export var current_floor: int = 1
@export var hp: int = 80
@export var max_hp: int = 80
@export var gold: int = 99
@export var deck: Array[Card] = []
@export var relics: Array[Relic] = []
@export var potions: Array[Potion] = []
@export var potion_slots: int = 3
@export var map: MapData
@export var visited_nodes: Array[NodeRef] = []
@export var current_node: NodeRef
```

**重要**：所有随机性都从 `seed` 派生。同一 seed 应该产生完全相同的跑团（用于调试/分享）。

## 跑团事件流

```gdscript
# 简化伪代码
func start_run(class_id: StringName) -> void:
    RunState.seed = randi()
    RunState.deck = ClassData.get(class_id).starting_deck
    RunState.relics = [ClassData.get(class_id).starting_relic]
    RunState.map = MapGen.generate(RunState.seed, current_act)
    enter_node(RunState.map.entry)

func enter_node(node: NodeRef) -> void:
    match node.type:
        NodeType.MONSTER:   scene_changer.go_to_combat(pick_encounter(node))
        NodeType.ELITE:     scene_changer.go_to_combat(pick_elite(node))
        NodeType.REST:      scene_changer.go_to_rest()
        NodeType.SHOP:      scene_changer.go_to_shop()
        NodeType.UNKNOWN:   scene_changer.go_to_event(roll_event())
        NodeType.TREASURE:  scene_changer.go_to_treasure()
        NodeType.BOSS:      scene_changer.go_to_combat(BOSS_ENCOUNTER)
```

## 节点完成后的下一步

战斗、事件、商店、休息等场景结束时，都返回地图场景，让玩家选择下一节点。地图场景只显示当前可达的节点（即「上一层中与已访问节点直接相连的节点」）。

## 跑团结束

- **胜利**：击败 Boss → 显示统计页（最终卡组、遗物、击杀数、用时）→ 主菜单
- **失败**：HP 归零 → 跑团统计页 → 主菜单
- 跑团结束后 `RunState` 清空
