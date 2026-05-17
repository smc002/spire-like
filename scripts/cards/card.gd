class_name Card extends Resource

enum Type { ATTACK, SKILL, POWER, STATUS, CURSE }
enum Rarity { BASIC, COMMON, UNCOMMON, RARE, SPECIAL }
enum Target { ENEMY, ALL_ENEMIES, SELF, NONE, RANDOM_ENEMY }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 1
@export var type: Type = Type.ATTACK
@export var rarity: Rarity = Rarity.BASIC
@export var target: Target = Target.ENEMY
@export var effects: Array[CardEffect] = []
@export var exhaust: bool = false
@export var ethereal: bool = false
@export var innate: bool = false
@export var retain: bool = false

@export_group("Upgrade")
@export var upgraded: bool = false


func requires_target() -> bool:
	return target == Target.ENEMY or target == Target.RANDOM_ENEMY


func is_playable(energy: int) -> bool:
	return cost == -1 or cost <= energy
