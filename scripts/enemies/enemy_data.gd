class_name EnemyData extends Resource

enum Tier { NORMAL, ELITE, BOSS }

@export var id: StringName
@export var display_name: String = ""
@export var hp_min: int = 10
@export var hp_max: int = 10
@export var sprite: Texture2D
@export var tier: Tier = Tier.NORMAL
@export var act: int = 1
@export var move_set: Array[EnemyMove] = []
