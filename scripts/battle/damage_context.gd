class_name DamageContext extends RefCounted

var source: Actor
var target: Actor
var amount: int = 0
var is_attack: bool = true   # false for non-attack damage (poison, burn, lose-HP)
