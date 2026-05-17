class_name GainBlock extends CardEffect

@export var amount: int = 5


func apply(ctx: CardPlayContext) -> void:
	BattleManager.add_block(ctx.source, amount)
