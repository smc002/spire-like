class_name AutoBattler extends Node

# Drives a single battle to completion using greedy auto-play.
# Designed for console-only verification — to be replaced by real UI later.
#
# Safety: bails after `max_turns` to prevent runaway loops.
# Cleanup: disconnects all signal callbacks on exit.

@export var max_turns: int = 100
@export var step_delay: float = 0.25
@export var verbose: bool = true

# Each entry is [signal, callable] so we can disconnect on teardown
var _connections: Array = []


func run_battle(p_player: Player, encounter: Encounter, seed: int = 0) -> void:
	_wire_logger()
	BattleManager.start_battle(p_player, encounter, seed)
	await _drive()
	_disconnect_logger()


# ─────────────────────────────────────────────────────────────────────
# Drive loop
# ─────────────────────────────────────────────────────────────────────

func _drive() -> void:
	while BattleManager.battle_active:
		if BattleManager.turn > max_turns:
			push_warning("[AutoBattler] turn cap %d hit; ending battle" % max_turns)
			BattleManager.force_end_battle(false)
			break
		if BattleManager.is_player_turn:
			await _player_turn_step()
		else:
			# Enemy turn is synchronous inside end_player_turn(); this branch
			# is rarely reached, but yield to avoid a hot loop just in case.
			await get_tree().create_timer(step_delay).timeout


func _player_turn_step() -> void:
	if verbose:
		_print_state()
	await get_tree().create_timer(step_delay).timeout
	if _try_play_one_card():
		return
	if verbose:
		print("[Player] -> end turn")
	BattleManager.end_player_turn()
	await get_tree().create_timer(step_delay).timeout


func _try_play_one_card() -> bool:
	var p := BattleManager.player
	for card in p.hand.duplicate():
		if not card.is_playable(p.energy):
			continue
		var targets: Array[Actor] = []
		if card.requires_target():
			var alive := BattleManager.living_enemies()
			if alive.is_empty():
				return false
			# Prefer lowest HP enemy (greedy)
			var pick: Enemy = alive[0]
			for e in alive:
				if e.hp < pick.hp:
					pick = e
			targets.append(pick)
		if verbose:
			print("[Player] play %s (cost %d)" % [card.display_name, card.cost])
		if not BattleManager.play_card(card, targets):
			# Defensive: should not happen, but skip if it does
			continue
		return true
	return false


# ─────────────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────────────

func _print_state() -> void:
	var p := BattleManager.player
	print("--- Turn %d ---" % BattleManager.turn)
	print("Player HP %d/%d  Block %d  Energy %d/%d  %s"
		% [p.hp, p.max_hp, p.block, p.energy, p.max_energy, _statuses_str(p)])
	for e in BattleManager.enemies:
		var intent_str := _intent_str(e.next_move) if e.next_move else "??"
		print("  %s HP %d/%d  Block %d  Intent: %s  %s"
			% [e.data.display_name, e.hp, e.max_hp, e.block, intent_str, _statuses_str(e)])
	var hand_names: Array[String] = []
	for c in p.hand:
		hand_names.append("%s(%d)" % [c.display_name, c.cost])
	print("Hand: [%s]   Draw:%d  Discard:%d  Exhaust:%d"
		% [", ".join(hand_names), p.draw_pile.size(), p.discard_pile.size(), p.exhaust_pile.size()])


func _intent_str(move: EnemyMove) -> String:
	match move.intent:
		EnemyMove.Intent.ATTACK:
			if move.multi_hits > 1:
				return "Attack %dx%d" % [move.damage, move.multi_hits]
			return "Attack %d" % move.damage
		EnemyMove.Intent.DEFEND:
			return "Block %d" % move.block
		EnemyMove.Intent.ATTACK_DEFEND:
			return "Atk %d / Blk %d" % [move.damage, move.block]
		EnemyMove.Intent.DEBUFF:
			return "Debuff(%s+%d)" % [str(move.status_to_apply), move.status_stacks]
		EnemyMove.Intent.BUFF:
			return "Buff(%s+%d)" % [str(move.status_to_apply), move.status_stacks]
		_:
			return "Special"


func _statuses_str(a: Actor) -> String:
	if a.status_holder == null or a.status_holder.stacks.is_empty():
		return ""
	var parts: Array[String] = []
	for id in a.status_holder.stacks.keys():
		parts.append("%s:%d" % [str(id), a.status_holder.stacks[id]])
	return "{" + ", ".join(parts) + "}"


func _name_of(a: Actor) -> String:
	if a is Player:
		return "Player"
	if a is Enemy:
		return (a as Enemy).data.display_name
	return "?"


func _wire_logger() -> void:
	_connect(BattleEvents.battle_started, func(): print("\n== Battle Start =="))
	_connect(BattleEvents.battle_won, func(): print("\n== Player Wins ==\n"))
	_connect(BattleEvents.battle_lost, func(): print("\n== Player Defeated ==\n"))
	_connect(BattleEvents.damage_dealt, func(src, tgt, actual, blocked):
		print("    %s -> %s: -%d HP (%d blocked)"
			% [_name_of(src), _name_of(tgt), actual, blocked]))
	_connect(BattleEvents.block_gained, func(tgt, amount):
		if amount > 0:
			print("    %s +%d block" % [_name_of(tgt), amount]))
	_connect(BattleEvents.status_applied, func(tgt, id, total):
		print("    %s now %s=%d" % [_name_of(tgt), str(id), total]))
	_connect(BattleEvents.actor_died, func(a):
		print("    %s defeated." % _name_of(a)))


func _connect(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_connections.append([sig, cb])


func _disconnect_logger() -> void:
	for pair in _connections:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_connections.clear()
