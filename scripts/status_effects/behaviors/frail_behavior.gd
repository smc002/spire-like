class_name FrailBehavior extends StatusBehavior

const MULTIPLIER: float = 0.75


func _ready() -> void:
	BattleEvents.block_intent.connect(_on_block_intent)


func _on_block_intent(ctx: BlockContext) -> void:
	if ctx.target != owner_actor:
		return
	if get_stacks() <= 0:
		return
	ctx.amount = int(floor(ctx.amount * MULTIPLIER))
