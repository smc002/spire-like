class_name EnemyMove extends Resource

enum Intent { ATTACK, DEFEND, ATTACK_DEFEND, BUFF, DEBUFF, SPECIAL, STUNNED, UNKNOWN }

@export var id: StringName
@export var display_name: String = ""
@export var intent: Intent = Intent.ATTACK
@export var damage: int = 0
@export var multi_hits: int = 1
@export var block: int = 0
@export var status_to_apply: StringName = &""
@export var status_stacks: int = 0
@export var weight: float = 1.0
@export var max_uses_in_a_row: int = -1   # -1 = unlimited
