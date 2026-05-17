class_name StrengthBehavior extends StatusBehavior

func _ready() -> void:
	BattleEvents.damage_intent.connect(_on_damage_intent)


func _on_damage_intent(ctx: DamageContext) -> void:
	if ctx.source != owner_actor:
		return
	if not ctx.is_attack:
		return
	ctx.amount += get_stacks()
