extends Node

# Run-wide state shared across battles, events, rewards.
# Source of truth for the player's deck/HP/gold/etc. between scenes.

var run_seed: int = 0
var rng: RandomNumberGenerator

var current_floor: int = 0
var current_act: int = 1

var max_hp: int = 80
var hp: int = 80
var gold: int = 99

var deck: Array[Card] = []

var run_active: bool = false


func start_new_run(class_id: StringName = &"warrior", p_seed: int = 0) -> void:
	run_seed = p_seed if p_seed != 0 else (randi() | 1)
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed

	current_floor = 0
	current_act = 1

	match class_id:
		&"warrior":
			max_hp = 80
			hp = max_hp
			gold = 99
			deck = WarriorCards.starter_deck()
		_:
			push_error("Unknown class id: " + str(class_id))
			return

	run_active = true


func end_run() -> void:
	run_active = false
	deck.clear()


func add_card(card: Card) -> void:
	deck.append(card)


func change_hp(delta: int) -> void:
	hp = clamp(hp + delta, 0, max_hp)
