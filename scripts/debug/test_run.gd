extends Node

# Drives a full short run: start_new_run → 3 sequential battles → rewards
# between each. Auto-plays greedy AI on the player side.
# Verifies that RunState (deck, hp, gold) correctly carries across battles.


const FLOORS_TO_PLAY: int = 3


func run() -> void:
	print("\n############ NEW RUN ############")
	RunState.start_new_run(&"warrior", 12345)
	_print_run_state("Start")

	for floor_num in range(1, FLOORS_TO_PLAY + 1):
		RunState.current_floor = floor_num
		print("\n>>> FLOOR %d <<<" % floor_num)

		var encounter := _encounter_for_floor(floor_num)
		await _play_battle(encounter)

		if RunState.hp <= 0:
			print("\n############ RUN FAILED ############")
			_print_run_state("Final")
			RunState.end_run()
			return

		var rewards := RewardGenerator.for_encounter(encounter, RunState.rng)
		_apply_rewards(rewards)
		_print_run_state("After floor %d" % floor_num)

	print("\n############ RUN COMPLETE ############")
	_print_run_state("Final")
	RunState.end_run()


# ─────────────────────────────────────────────────────────────────────
# Battle driver
# ─────────────────────────────────────────────────────────────────────

func _play_battle(encounter: Encounter) -> void:
	# Fresh player per battle, fed from RunState
	var p := Player.new()
	add_child(p)
	p.setup_run(RunState.max_hp, RunState.hp, RunState.deck)

	var battler := AutoBattler.new()
	battler.name = "AutoBattler_F%d" % RunState.current_floor
	add_child(battler)
	await battler.run_battle(p, encounter, RunState.rng.randi())

	# Write back HP after battle
	RunState.hp = p.hp

	# Cleanup
	battler.queue_free()
	p.queue_free()


# ─────────────────────────────────────────────────────────────────────
# Rewards
# ─────────────────────────────────────────────────────────────────────

func _apply_rewards(rewards: RewardPackage) -> void:
	print("\nReward: +%d gold" % rewards.gold)
	RunState.gold += rewards.gold

	if rewards.card_choices.is_empty():
		print("(no card choices available)")
		return
	print("Card choices:")
	for i in rewards.card_choices.size():
		var c := rewards.card_choices[i]
		print("  [%d] %s  cost %d  rarity %s  — %s"
			% [i + 1, c.display_name, c.cost, _rarity_str(c.rarity), c.description])

	var pick := _auto_pick(rewards.card_choices)
	if pick == null:
		print("> skipped")
	else:
		RunState.add_card(pick)
		print("> picked: %s" % pick.display_name)


# Greedy: pick highest rarity. Tie-breaker: first one.
func _auto_pick(choices: Array[Card]) -> Card:
	var best: Card = null
	for c in choices:
		if best == null or c.rarity > best.rarity:
			best = c
	return best


# ─────────────────────────────────────────────────────────────────────
# Test encounters (placeholders until proper enemy data lands)
# ─────────────────────────────────────────────────────────────────────

func _encounter_for_floor(floor_num: int) -> Encounter:
	match floor_num:
		1:
			return _enc_single_dummy(&"dummy_easy", "Training Dummy", 25, 5,
				Encounter.Tier.NORMAL)
		2:
			return _enc_single_dummy(&"dummy_mid", "Sturdy Dummy", 38, 7,
				Encounter.Tier.NORMAL)
		3:
			return _enc_two_dummies()
		_:
			return _enc_single_dummy(&"dummy_easy", "Training Dummy", 25, 5,
				Encounter.Tier.NORMAL)


func _enc_single_dummy(id: StringName, name: String, hp: int, dmg: int, tier: int) -> Encounter:
	var d := _make_dummy(id, name, hp, dmg)
	var enc := Encounter.new()
	enc.id = id
	enc.display_name = name
	enc.tier = tier
	enc.enemies.append(d)
	return enc


func _enc_two_dummies() -> Encounter:
	var enc := Encounter.new()
	enc.id = &"two_dummies"
	enc.display_name = "Pair of Dummies"
	enc.tier = Encounter.Tier.NORMAL
	enc.enemies.append(_make_dummy(&"dummy_left", "Left Dummy", 22, 4))
	enc.enemies.append(_make_dummy(&"dummy_right", "Right Dummy", 22, 4))
	return enc


func _make_dummy(id: StringName, name: String, hp: int, attack_dmg: int) -> EnemyData:
	var d := EnemyData.new()
	d.id = id
	d.display_name = name
	d.hp_min = hp
	d.hp_max = hp
	d.tier = EnemyData.Tier.NORMAL

	var atk := EnemyMove.new()
	atk.id = &"swing"
	atk.intent = EnemyMove.Intent.ATTACK
	atk.damage = attack_dmg
	atk.weight = 1.2
	atk.max_uses_in_a_row = 2

	var brace := EnemyMove.new()
	brace.id = &"brace"
	brace.intent = EnemyMove.Intent.DEFEND
	brace.block = 4
	brace.weight = 0.5
	brace.max_uses_in_a_row = 1

	var taunt := EnemyMove.new()
	taunt.id = &"taunt"
	taunt.intent = EnemyMove.Intent.DEBUFF
	taunt.status_to_apply = &"weak"
	taunt.status_stacks = 1
	taunt.weight = 0.4
	taunt.max_uses_in_a_row = 1

	d.move_set.append(atk)
	d.move_set.append(brace)
	d.move_set.append(taunt)
	return d


# ─────────────────────────────────────────────────────────────────────
# Reporting
# ─────────────────────────────────────────────────────────────────────

func _print_run_state(label: String) -> void:
	print("[RunState %s] HP %d/%d  Gold %d  Deck %d cards"
		% [label, RunState.hp, RunState.max_hp, RunState.gold, RunState.deck.size()])
	var by_id: Dictionary = {}
	for c in RunState.deck:
		by_id[c.id] = by_id.get(c.id, 0) + 1
	var parts: Array[String] = []
	for id in by_id.keys():
		parts.append("%s×%d" % [str(id), by_id[id]])
	print("    " + ", ".join(parts))


func _rarity_str(r: int) -> String:
	match r:
		Card.Rarity.BASIC: return "Basic"
		Card.Rarity.COMMON: return "Common"
		Card.Rarity.UNCOMMON: return "Uncommon"
		Card.Rarity.RARE: return "Rare"
		Card.Rarity.SPECIAL: return "Special"
		_: return "?"
