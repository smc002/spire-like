extends Node

# A console-only auto-playing battle for verifying the core combat loop.
# Strategy: dumb greedy — play any affordable card on the first living enemy
# until no card is playable, then end turn.

func run_test() -> void:
	_wire_logger()

	var p := Player.new()
	add_child(p)
	p.setup_run(80, _build_test_deck())

	var encounter := _build_test_encounter()
	BattleManager.start_battle(p, encounter, 12345)   # fixed seed for reproducibility

	await _drive_battle()
	print("== Test complete ==")


# ──────────────────────────────────────────────────────────────────────────────
# Auto-player loop
# ──────────────────────────────────────────────────────────────────────────────

func _drive_battle() -> void:
	while BattleManager.battle_active:
		if BattleManager.is_player_turn:
			await _player_turn_step()
		else:
			# enemy turn is synchronous in BattleManager; pace the log
			await get_tree().create_timer(0.4).timeout


func _player_turn_step() -> void:
	_print_state()
	await get_tree().create_timer(0.3).timeout
	if _try_play_one_card():
		return
	print("[Player] -> end turn")
	BattleManager.end_player_turn()
	await get_tree().create_timer(0.4).timeout


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
			targets.append(alive[0])
		print("[Player] play %s (cost %d)" % [card.display_name, card.cost])
		BattleManager.play_card(card, targets)
		return true
	return false


# ──────────────────────────────────────────────────────────────────────────────
# Console reporting
# ──────────────────────────────────────────────────────────────────────────────

func _print_state() -> void:
	var p := BattleManager.player
	print("--- Turn %d ---" % BattleManager.turn)
	print("Player HP %d/%d  Block %d  Energy %d/%d  %s"
		% [p.hp, p.max_hp, p.block, p.energy, p.max_energy, _statuses_str(p)])
	for e in BattleManager.enemies:
		var intent_str := _intent_str(e.next_move) if e.next_move else "??"
		print("  %s HP %d/%d  Block %d  Intent: %s  %s"
			% [e.data.display_name, e.hp, e.max_hp, e.block, intent_str, _statuses_str(e)])
	var hand_names := []
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
	var parts := []
	for id in a.status_holder.stacks.keys():
		parts.append("%s:%d" % [str(id), a.status_holder.stacks[id]])
	return "{" + ", ".join(parts) + "}"


func _wire_logger() -> void:
	BattleEvents.battle_started.connect(func(): print("\n== Battle Start =="))
	BattleEvents.battle_won.connect(func(): print("\n== Player Wins =="))
	BattleEvents.battle_lost.connect(func(): print("\n== Player Defeated =="))
	BattleEvents.damage_dealt.connect(func(src, tgt, actual, blocked):
		print("    %s -> %s: -%d HP (%d blocked)" % [_name(src), _name(tgt), actual, blocked]))
	BattleEvents.block_gained.connect(func(tgt, amount):
		print("    %s +%d block" % [_name(tgt), amount]))
	BattleEvents.status_applied.connect(func(tgt, id, total):
		print("    %s now %s=%d" % [_name(tgt), str(id), total]))
	BattleEvents.actor_died.connect(func(a):
		print("    %s defeated." % _name(a)))


func _name(a: Actor) -> String:
	if a is Player:
		return "Player"
	if a is Enemy:
		return (a as Enemy).data.display_name
	return "?"


# ──────────────────────────────────────────────────────────────────────────────
# Test content (programmatic — to be replaced by .tres later)
# ──────────────────────────────────────────────────────────────────────────────

func _build_test_deck() -> Array[Card]:
	var deck: Array[Card] = []
	for _i in 5:
		deck.append(_make_basic_attack())
	for _i in 4:
		deck.append(_make_basic_block())
	deck.append(_make_heavy_swing())
	return deck


func _make_basic_attack() -> Card:
	var c := Card.new()
	c.id = &"basic_attack"
	c.display_name = "Basic Attack"
	c.description = "Deal 6 damage."
	c.cost = 1
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.BASIC
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 6
	c.effects = [dmg]
	return c


func _make_basic_block() -> Card:
	var c := Card.new()
	c.id = &"basic_block"
	c.display_name = "Basic Block"
	c.description = "Gain 5 Block."
	c.cost = 1
	c.type = Card.Type.SKILL
	c.rarity = Card.Rarity.BASIC
	c.target = Card.Target.SELF
	var blk := GainBlock.new()
	blk.amount = 5
	c.effects = [blk]
	return c


func _make_heavy_swing() -> Card:
	var c := Card.new()
	c.id = &"heavy_swing"
	c.display_name = "Heavy Swing"
	c.description = "Deal 8 damage. Apply 2 Vulnerable."
	c.cost = 2
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.BASIC
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 8
	var vuln := ApplyStatusEffect.new()
	vuln.status_id = &"vulnerable"
	vuln.stacks = 2
	c.effects = [dmg, vuln]
	return c


func _build_test_encounter() -> Encounter:
	var enc := Encounter.new()
	enc.id = &"test_dummy"
	enc.enemies = [_make_training_dummy()]
	return enc


func _make_training_dummy() -> EnemyData:
	var d := EnemyData.new()
	d.id = &"training_dummy"
	d.display_name = "Training Dummy"
	d.hp_min = 32
	d.hp_max = 32
	d.tier = EnemyData.Tier.NORMAL

	var atk := EnemyMove.new()
	atk.id = &"swing"
	atk.intent = EnemyMove.Intent.ATTACK
	atk.damage = 6
	atk.weight = 1.0
	atk.max_uses_in_a_row = 2

	var brace := EnemyMove.new()
	brace.id = &"brace"
	brace.intent = EnemyMove.Intent.DEFEND
	brace.block = 5
	brace.weight = 0.6
	brace.max_uses_in_a_row = 1

	var taunt := EnemyMove.new()
	taunt.id = &"taunt"
	taunt.intent = EnemyMove.Intent.DEBUFF
	taunt.status_to_apply = &"weak"
	taunt.status_stacks = 1
	taunt.weight = 0.4
	taunt.max_uses_in_a_row = 1

	d.move_set = [atk, brace, taunt]
	return d
