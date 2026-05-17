class_name ApplyStatusEffect extends CardEffect

@export var status_id: StringName
@export var stacks: int = 1
@export var to_self: bool = false
@export var to_all_enemies: bool = false


func apply(ctx: CardPlayContext) -> void:
	if to_self:
		if not ctx.source.is_dead():
			BattleManager.apply_status(ctx.source, ctx.source, status_id, stacks)
		return
	if to_all_enemies:
		for e in ctx.all_enemies:
			if not e.is_dead():
				BattleManager.apply_status(ctx.source, e, status_id, stacks)
		return
	if ctx.targets.size() > 0 and not ctx.targets[0].is_dead():
		BattleManager.apply_status(ctx.source, ctx.targets[0], status_id, stacks)
