extends Node

var _registry: Dictionary = {}   # StringName -> StatusEffect


func _ready() -> void:
	_register(&"strength",
		"Strength",
		"Each Attack deals additional damage equal to stacks.",
		false, StatusEffect.DecayRule.NONE, StrengthBehavior)
	_register(&"vulnerable",
		"Vulnerable",
		"Takes 50% more Attack damage. Decreases by 1 each turn.",
		true, StatusEffect.DecayRule.TURN_END_DECREMENT, VulnerableBehavior)
	_register(&"weak",
		"Weak",
		"Deals 25% less Attack damage. Decreases by 1 each turn.",
		true, StatusEffect.DecayRule.TURN_END_DECREMENT, WeakBehavior)
	_register(&"frail",
		"Frail",
		"Gains 25% less Block. Decreases by 1 each turn.",
		true, StatusEffect.DecayRule.TURN_END_DECREMENT, FrailBehavior)


func _register(id: StringName, display_name: String, description: String,
		is_debuff: bool, decay: StatusEffect.DecayRule, behavior_cls: Script) -> void:
	var s := StatusEffect.new()
	s.id = id
	s.display_name = display_name
	s.description = description
	s.is_debuff = is_debuff
	s.decay_rule = decay
	s.behavior_class = behavior_cls
	_registry[id] = s


func get_status(id: StringName) -> StatusEffect:
	return _registry.get(id)


func all_ids() -> Array:
	return _registry.keys()
