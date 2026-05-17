class_name VulnerableBehavior extends StatusBehavior

const MULTIPLIER: float = 1.5


func _ready() -> void:
	BattleEvents.damage_intent.connect(_on_damage_intent)


func _on_damage_intent(ctx: DamageContext) -> void:
	if ctx.target != owner_actor:
		return
	if not ctx.is_attack:
		return
	if get_stacks() <= 0:
		return
	ctx.amount = int(floor(ctx.amount * MULTIPLIER))
