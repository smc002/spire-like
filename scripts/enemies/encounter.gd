class_name Encounter extends Resource

enum Tier { EASY, NORMAL, ELITE, BOSS }

@export var id: StringName
@export var display_name: String = ""
@export var enemies: Array[EnemyData] = []
@export var tier: Tier = Tier.NORMAL
@export var act: int = 1
@export var min_floor: int = 1
@export var max_floor: int = 99
