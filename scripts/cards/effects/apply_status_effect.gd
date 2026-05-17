class_name ApplyStatusEffect extends CardEffect

@export var status_id: StringName
@export var stacks: int = 1
@export var to_self: bool = false


func apply(ctx: CardPlayContext) -> void:
	var target: Actor
	if to_self:
		target = ctx.source
	elif ctx.targets.size() > 0:
		target = ctx.targets[0]
	else:
		return
	if target.is_dead():
		return
	BattleManager.apply_status(ctx.source, target, status_id, stacks)
