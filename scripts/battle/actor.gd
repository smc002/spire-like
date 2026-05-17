class_name Actor extends Node

var max_hp: int = 1
var hp: int = 1
var block: int = 0
var status_holder: StatusHolder


func setup(p_max_hp: int) -> void:
	max_hp = p_max_hp
	hp = max_hp
	if status_holder == null:
		status_holder = StatusHolder.new()
		status_holder.actor = self
		add_child(status_holder)


# Returns { "actual": int, "blocked": int }
func take_damage(amount: int) -> Dictionary:
	var blocked: int = min(block, amount)
	block -= blocked
	var actual: int = amount - blocked
	hp = max(hp - actual, 0)
	return { "actual": actual, "blocked": blocked }


func is_dead() -> bool:
	return hp <= 0
