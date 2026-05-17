class_name StatusBehavior extends Node

var owner_actor: Actor
var status_id: StringName


func get_stacks() -> int:
	return owner_actor.status_holder.get_stacks(status_id)
