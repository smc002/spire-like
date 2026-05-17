class_name DealDamage extends CardEffect

@export var amount: int = 6
@export var times: int = 1
@export var hits_all: bool = false


func apply(ctx: CardPlayContext) -> void:
	var targets: Array[Actor] = []
	if hits_all:
		for e in ctx.all_enemies:
			targets.append(e)
	else:
		targets = ctx.targets
	for _i in range(times):
		for t in targets:
			if t.is_dead():
				continue
			BattleManager.deal_damage(ctx.source, t, amount, true)
