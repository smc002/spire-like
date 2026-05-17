class_name StatusHolder extends Node

var actor: Actor
var stacks: Dictionary = {}      # StringName -> int
var behaviors: Dictionary = {}   # StringName -> StatusBehavior


func apply(id: StringName, amount: int) -> void:
	if not stacks.has(id):
		var data := StatusRegistry.get_status(id)
		if data == null:
			push_error("Unknown status: " + str(id))
			return
		var b: StatusBehavior = data.behavior_class.new()
		b.owner_actor = actor
		b.status_id = id
		add_child(b)
		behaviors[id] = b
		stacks[id] = 0
	stacks[id] += amount
	if stacks[id] <= 0:
		_remove(id)


func get_stacks(id: StringName) -> int:
	return stacks.get(id, 0)


func decay_turn_end() -> void:
	for id in stacks.keys().duplicate():
		var data := StatusRegistry.get_status(id)
		if data == null:
			continue
		match data.decay_rule:
			StatusEffect.DecayRule.TURN_END_DECREMENT:
				stacks[id] -= 1
				if stacks[id] <= 0:
					_remove(id)
			StatusEffect.DecayRule.TURN_END_RESET:
				_remove(id)


func _remove(id: StringName) -> void:
	if behaviors.has(id):
		behaviors[id].queue_free()
		behaviors.erase(id)
	stacks.erase(id)


# Called at end of battle to wipe everything immediately, so a new battle
# starts with a clean slate even when the actor is reused.
func clear_all() -> void:
	for id in stacks.keys().duplicate():
		if behaviors.has(id):
			behaviors[id].free()   # immediate, no signal leakage
			behaviors.erase(id)
	stacks.clear()
