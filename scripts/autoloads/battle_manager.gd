extends Node

const HAND_MAX: int = 10

# Pacing for enemy turn (read by tests; UI catches the events as they fire)
const ENEMY_INTENT_PAUSE: float = 0.35
const ENEMY_HIT_GAP: float = 0.18
const ENEMY_ACTION_GAP: float = 0.20
const ENEMY_BETWEEN_GAP: float = 0.22

var player: Player
var enemies: Array[Enemy] = []
var rng: RandomNumberGenerator

var turn: int = 0
var is_player_turn: bool = false
var battle_active: bool = false


# ──────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ──────────────────────────────────────────────────────────────────────────────

func start_battle(p_player: Player, encounter: Encounter, seed: int = 0) -> void:
	player = p_player
	rng = RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()

	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()

	for d in encounter.enemies:
		var e := Enemy.new()
		add_child(e)
		e.setup_from_data(d, rng)
		enemies.append(e)

	player.setup_combat()
	turn = 0
	battle_active = true
	BattleEvents.battle_started.emit()

	for e in enemies:
		e.roll_next_move(rng)
		BattleEvents.enemy_intent_changed.emit(e, e.next_move)

	_start_player_turn()


# ──────────────────────────────────────────────────────────────────────────────
# Turn control
# ──────────────────────────────────────────────────────────────────────────────

func _start_player_turn() -> void:
	turn += 1
	is_player_turn = true
	player.energy = player.max_energy
	player.block = 0
	BattleEvents.turn_started.emit(player)
	draw_cards(player.draw_count)


func end_player_turn() -> void:
	if not is_player_turn or not battle_active:
		return
	is_player_turn = false
	BattleEvents.turn_ended.emit(player)

	var retained: Array[Card] = []
	for c in player.hand:
		if c.retain:
			retained.append(c)
		else:
			player.discard_pile.append(c)
			BattleEvents.card_discarded.emit(c)
	player.hand = retained

	player.status_holder.decay_turn_end()
	player.block = 0

	await _enemy_turn()


func _enemy_turn() -> void:
	for e in enemies:
		if e.is_dead():
			continue
		BattleEvents.turn_started.emit(e)
		await get_tree().create_timer(ENEMY_INTENT_PAUSE).timeout
		await _execute_move(e, e.next_move)
		e.move_history.append(e.next_move)
		BattleEvents.turn_ended.emit(e)
		e.status_holder.decay_turn_end()
		e.block = 0
		if not battle_active:
			return
		# Roll next intent immediately so UI shows the new intent during the gap
		e.roll_next_move(rng)
		BattleEvents.enemy_intent_changed.emit(e, e.next_move)
		await get_tree().create_timer(ENEMY_BETWEEN_GAP).timeout

	if battle_active:
		_start_player_turn()


func _execute_move(enemy: Enemy, move: EnemyMove) -> void:
	if move.damage > 0:
		for _i in range(move.multi_hits):
			if player.is_dead():
				break
			deal_damage(enemy, player, move.damage, true)
			await get_tree().create_timer(ENEMY_HIT_GAP).timeout
	if move.block > 0:
		add_block(enemy, move.block)
		await get_tree().create_timer(ENEMY_ACTION_GAP).timeout
	if move.status_to_apply != &"":
		var target: Actor = player
		if move.intent == EnemyMove.Intent.BUFF:
			target = enemy
		apply_status(enemy, target, move.status_to_apply, move.status_stacks)
		await get_tree().create_timer(ENEMY_ACTION_GAP).timeout


# ──────────────────────────────────────────────────────────────────────────────
# Card play (player-driven, synchronous)
# ──────────────────────────────────────────────────────────────────────────────

func play_card(card: Card, targets: Array[Actor]) -> bool:
	if not is_player_turn or not battle_active:
		return false
	if not (card in player.hand):
		return false
	if not card.is_playable(player.energy):
		return false
	if card.requires_target() and targets.is_empty():
		return false

	var cost: int = card.cost
	if cost == -1:
		cost = player.energy
	player.energy -= cost

	var ctx := CardPlayContext.new()
	ctx.card = card
	ctx.source = player
	ctx.targets = targets
	ctx.all_enemies = living_enemies()
	BattleEvents.card_played.emit(card, targets)
	for eff in card.effects:
		eff.apply(ctx)

	player.hand.erase(card)
	if card.exhaust:
		player.exhaust_pile.append(card)
		BattleEvents.card_exhausted.emit(card)
	else:
		player.discard_pile.append(card)
		BattleEvents.card_discarded.emit(card)
	BattleEvents.card_resolved.emit(card)

	_check_battle_end()
	return true


# ──────────────────────────────────────────────────────────────────────────────
# Damage / block / status / draw (called by effects + AI)
# ──────────────────────────────────────────────────────────────────────────────

func deal_damage(source: Actor, target: Actor, amount: int, is_attack: bool) -> void:
	if target.is_dead():
		return
	var ctx := DamageContext.new()
	ctx.source = source
	ctx.target = target
	ctx.amount = amount
	ctx.is_attack = is_attack
	BattleEvents.damage_intent.emit(ctx)
	ctx.amount = max(ctx.amount, 0)
	var result := target.take_damage(ctx.amount)
	BattleEvents.damage_dealt.emit(source, target, result.actual, result.blocked)
	if target.is_dead():
		BattleEvents.actor_died.emit(target)
		_check_battle_end()


func add_block(actor: Actor, amount: int) -> void:
	var ctx := BlockContext.new()
	ctx.target = actor
	ctx.amount = amount
	BattleEvents.block_intent.emit(ctx)
	ctx.amount = max(ctx.amount, 0)
	actor.block += ctx.amount
	BattleEvents.block_gained.emit(actor, ctx.amount)


func apply_status(_source: Actor, target: Actor, id: StringName, stacks: int) -> void:
	if target.is_dead():
		return
	target.status_holder.apply(id, stacks)
	BattleEvents.status_applied.emit(target, id, target.status_holder.get_stacks(id))


func draw_cards(count: int) -> void:
	for _i in range(count):
		if player.hand.size() >= HAND_MAX:
			return
		if player.draw_pile.is_empty():
			if player.discard_pile.is_empty():
				return
			player.draw_pile = player.discard_pile.duplicate()
			player.draw_pile.shuffle()
			player.discard_pile.clear()
		var c: Card = player.draw_pile.pop_back()
		player.hand.append(c)
		BattleEvents.card_drawn.emit(c)


# ──────────────────────────────────────────────────────────────────────────────
# Queries / end of battle
# ──────────────────────────────────────────────────────────────────────────────

func living_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for e in enemies:
		if not e.is_dead():
			result.append(e)
	return result


func _check_battle_end() -> void:
	if not battle_active:
		return
	if player.is_dead():
		battle_active = false
		_cleanup_battle()
		BattleEvents.battle_lost.emit()
	elif living_enemies().is_empty():
		battle_active = false
		_cleanup_battle()
		BattleEvents.battle_won.emit()


func force_end_battle(won: bool) -> void:
	if not battle_active:
		return
	battle_active = false
	_cleanup_battle()
	if won:
		BattleEvents.battle_won.emit()
	else:
		BattleEvents.battle_lost.emit()


func _cleanup_battle() -> void:
	if player and player.status_holder:
		player.status_holder.clear_all()
		player.block = 0
	for e in enemies:
		if is_instance_valid(e) and e.status_holder:
			e.status_holder.clear_all()
