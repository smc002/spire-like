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

# ─── Stats (for run-end screen) ───
var battles_won: int = 0
var turns_played: int = 0
var total_damage_dealt: int = 0
var total_damage_taken: int = 0


func _ready() -> void:
	BattleEvents.battle_won.connect(_on_battle_won)
	BattleEvents.turn_started.connect(_on_turn_started)
	BattleEvents.damage_dealt.connect(_on_damage_dealt)


func start_new_run(class_id: StringName = &"warrior", p_seed: int = 0) -> void:
	run_seed = p_seed if p_seed != 0 else (randi() | 1)
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed

	current_floor = 0
	current_act = 1
	battles_won = 0
	turns_played = 0
	total_damage_dealt = 0
	total_damage_taken = 0

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


# ─────────────────────────────────────────────────────────────────────
# Stats hooks
# ─────────────────────────────────────────────────────────────────────

func _on_battle_won() -> void:
	battles_won += 1


func _on_turn_started(actor: Actor) -> void:
	if actor is Player:
		turns_played += 1


func _on_damage_dealt(source: Actor, target: Actor, actual: int, _blocked: int) -> void:
	if actual <= 0:
		return
	if source is Player:
		total_damage_dealt += actual
	if target is Player:
		total_damage_taken += actual
