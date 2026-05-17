extends Control

# Human-playable battle UI.
# Drag a playable card and release:
#   • target card → release over an enemy to play on it; elsewhere cancels
#   • no-target card → release above the hand row to play; otherwise cancels
#
# Drag-time affordances:
#   • Card hover: scale + lift in CardView
#   • Damage preview: enemies show "-N" when an attack card is dragged over
#   • Drop-zone hint: faint band above hand for self/AOE cards


# ─────────────────────────────────────────────────────────────────────
# UI refs (built procedurally)
# ─────────────────────────────────────────────────────────────────────

var _bg: ColorRect
var _turn_label: Label
var _action_log: Label
var _enemy_container: HBoxContainer
var _player_panel: PanelContainer
var _player_label: Label
var _hand_root: Control
var _drop_zone_hint: ColorRect
var _pile_label: Label
var _end_turn_btn: Button
var _result_panel: PanelContainer
var _result_label: Label
var _result_button: Button

# ─────────────────────────────────────────────────────────────────────
# Layout constants
# ─────────────────────────────────────────────────────────────────────

const HAND_AREA_X: int = 240
const HAND_AREA_Y: int = 540
const HAND_AREA_W: int = 800
const HAND_AREA_H: int = 180
const HAND_CARD_GAP: int = 8

# ─────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────

var _player: Player
var _enemy_views: Array[EnemyView] = []
var _connections: Array = []
var _refresh_queued: bool = false
var _dragging_card: CardView = null


func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(1280, 720)
	_build_ui()
	_wire_events()
	_start_new_run_battle()


func _exit_tree() -> void:
	for pair in _connections:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_connections.clear()


# ─────────────────────────────────────────────────────────────────────
# UI build
# ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.06, 0.06, 0.10)
	_bg.anchor_right = 1
	_bg.anchor_bottom = 1
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_turn_label = Label.new()
	_turn_label.position = Vector2(20, 12)
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.text = "—"
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_turn_label)

	_action_log = Label.new()
	_action_log.position = Vector2(750, 18)
	_action_log.size = Vector2(510, 30)
	_action_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_action_log.add_theme_font_size_override("font_size", 14)
	_action_log.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	_action_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_action_log)

	_enemy_container = HBoxContainer.new()
	_enemy_container.position = Vector2(0, 60)
	_enemy_container.size = Vector2(1280, 280)
	_enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_container.add_theme_constant_override("separation", 40)
	_enemy_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_enemy_container)

	_player_panel = PanelContainer.new()
	_player_panel.position = Vector2(20, 380)
	_player_panel.size = Vector2(200, 180)
	_player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.15, 0.20, 0.30)
	pstyle.set_corner_radius_all(8)
	pstyle.content_margin_left = 14
	pstyle.content_margin_right = 14
	pstyle.content_margin_top = 12
	pstyle.content_margin_bottom = 12
	_player_panel.add_theme_stylebox_override("panel", pstyle)
	_player_label = Label.new()
	_player_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_label.add_theme_font_size_override("font_size", 15)
	_player_panel.add_child(_player_label)
	add_child(_player_panel)

	# Drop-zone hint banner — shown while dragging a self/AOE card
	_drop_zone_hint = ColorRect.new()
	_drop_zone_hint.position = Vector2(HAND_AREA_X, HAND_AREA_Y - 40)
	_drop_zone_hint.size = Vector2(HAND_AREA_W, 40)
	_drop_zone_hint.color = Color(0.6, 0.85, 0.4, 0.20)
	_drop_zone_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone_hint.visible = false
	add_child(_drop_zone_hint)

	# Hand uses absolute positioning so cards can be dragged freely.
	_hand_root = Control.new()
	_hand_root.position = Vector2(HAND_AREA_X, HAND_AREA_Y)
	_hand_root.size = Vector2(HAND_AREA_W, HAND_AREA_H)
	_hand_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_hand_root)

	_pile_label = Label.new()
	_pile_label.position = Vector2(1060, 540)
	_pile_label.size = Vector2(200, 80)
	_pile_label.add_theme_font_size_override("font_size", 14)
	_pile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pile_label)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.position = Vector2(1060, 630)
	_end_turn_btn.size = Vector2(200, 70)
	_end_turn_btn.add_theme_font_size_override("font_size", 18)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	add_child(_end_turn_btn)

	_result_panel = PanelContainer.new()
	_result_panel.position = Vector2(440, 240)
	_result_panel.size = Vector2(400, 240)
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.10, 0.10, 0.18, 0.96)
	rstyle.set_corner_radius_all(12)
	rstyle.set_border_width_all(2)
	rstyle.border_color = Color(0.6, 0.6, 0.7)
	rstyle.content_margin_left = 30
	rstyle.content_margin_right = 30
	rstyle.content_margin_top = 30
	rstyle.content_margin_bottom = 30
	_result_panel.add_theme_stylebox_override("panel", rstyle)
	var rvb := VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 24)
	_result_panel.add_child(rvb)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 32)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rvb.add_child(_result_label)
	_result_button = Button.new()
	_result_button.text = "Restart"
	_result_button.add_theme_font_size_override("font_size", 18)
	_result_button.custom_minimum_size = Vector2(180, 50)
	_result_button.pressed.connect(_on_result_button_pressed)
	var btn_center := CenterContainer.new()
	btn_center.add_child(_result_button)
	rvb.add_child(btn_center)
	_result_panel.visible = false
	add_child(_result_panel)


# ─────────────────────────────────────────────────────────────────────
# Event wiring
# ─────────────────────────────────────────────────────────────────────

func _wire_events() -> void:
	_connect(BattleEvents.battle_started, _on_battle_started)
	_connect(BattleEvents.battle_won, _on_battle_won)
	_connect(BattleEvents.battle_lost, _on_battle_lost)
	_connect(BattleEvents.turn_started, _on_turn_started)
	_connect(BattleEvents.card_drawn, _on_state_changed_arg)
	_connect(BattleEvents.card_discarded, _on_state_changed_arg)
	_connect(BattleEvents.card_exhausted, _on_state_changed_arg)
	_connect(BattleEvents.card_resolved, _on_state_changed_arg)
	_connect(BattleEvents.damage_dealt, _on_damage_dealt)
	_connect(BattleEvents.block_gained, _on_block_gained)
	_connect(BattleEvents.status_applied, _on_status_applied)
	_connect(BattleEvents.enemy_intent_changed, _on_enemy_intent_changed)


func _connect(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_connections.append([sig, cb])


# ─────────────────────────────────────────────────────────────────────
# Run / battle lifecycle
# ─────────────────────────────────────────────────────────────────────

func _start_new_run_battle() -> void:
	RunState.start_new_run(&"warrior")
	RunState.current_floor = 1
	_start_battle(_floor1_encounter())


func _start_battle(encounter: Encounter) -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
	_player = Player.new()
	add_child(_player)
	_player.setup_run(RunState.max_hp, RunState.hp, RunState.deck)
	_result_panel.visible = false
	BattleManager.start_battle(_player, encounter, RunState.rng.randi())


# ─────────────────────────────────────────────────────────────────────
# Event handlers
# ─────────────────────────────────────────────────────────────────────

func _on_battle_started() -> void:
	_build_enemy_views()
	_set_log("Battle start")
	_request_refresh()


func _on_battle_won() -> void:
	if BattleManager.player:
		RunState.hp = BattleManager.player.hp
	_result_label.text = "Victory!"
	_result_button.text = "Restart Run"
	_result_panel.visible = true
	_end_turn_btn.disabled = true


func _on_battle_lost() -> void:
	_result_label.text = "Defeated"
	_result_button.text = "Restart Run"
	_result_panel.visible = true
	_end_turn_btn.disabled = true


func _on_turn_started(actor: Actor) -> void:
	if actor is Player:
		_end_turn_btn.disabled = false
		_set_log("Your turn")
	else:
		_end_turn_btn.disabled = true
	_request_refresh()


func _on_state_changed_arg(_arg = null) -> void:
	_request_refresh()


func _on_damage_dealt(_src: Actor, tgt: Actor, actual: int, blocked: int) -> void:
	if blocked > 0:
		_set_log("%s -%d HP (%d blocked)" % [_name_of(tgt), actual, blocked])
	else:
		_set_log("%s -%d HP" % [_name_of(tgt), actual])
	_request_refresh()


func _on_block_gained(tgt: Actor, amount: int) -> void:
	if amount > 0:
		_set_log("%s +%d block" % [_name_of(tgt), amount])
	_request_refresh()


func _on_status_applied(tgt: Actor, id: StringName, total: int) -> void:
	_set_log("%s: %s -> %d" % [_name_of(tgt), str(id), total])
	_request_refresh()


func _on_enemy_intent_changed(_enemy: Enemy, _move: EnemyMove) -> void:
	_request_refresh()


# ─────────────────────────────────────────────────────────────────────
# Drag handlers + per-frame damage preview
# ─────────────────────────────────────────────────────────────────────

func _on_card_drag_started(cv: CardView) -> void:
	_dragging_card = cv
	_end_turn_btn.disabled = true
	# Show drop-zone hint for self/AOE cards
	if not cv.card.requires_target():
		_drop_zone_hint.visible = true


func _on_card_drag_released(cv: CardView, release_global_pos: Vector2) -> void:
	_dragging_card = null
	_drop_zone_hint.visible = false
	_clear_all_damage_previews()
	_end_turn_btn.disabled = not BattleManager.is_player_turn

	if not BattleManager.is_player_turn or not BattleManager.battle_active:
		return

	var card := cv.card
	var played := false

	if card.requires_target():
		for ev in _enemy_views:
			if not is_instance_valid(ev) or ev.enemy == null or ev.enemy.is_dead():
				continue
			if ev.get_global_rect().has_point(release_global_pos):
				var targets: Array[Actor] = [ev.enemy as Actor]
				played = BattleManager.play_card(card, targets)
				if played:
					_set_log("Played %s on %s" % [card.display_name, ev.enemy.data.display_name])
				break
		if not played:
			_set_log("Drop on an enemy to play %s" % card.display_name)
	else:
		if release_global_pos.y < HAND_AREA_Y:
			var no_targets: Array[Actor] = []
			played = BattleManager.play_card(card, no_targets)
			if played:
				_set_log("Played %s" % card.display_name)
			else:
				_set_log("Could not play %s" % card.display_name)
		else:
			_set_log("Drag above the hand to play %s" % card.display_name)


func _process(_delta: float) -> void:
	if _dragging_card == null or not is_instance_valid(_dragging_card):
		return
	var card := _dragging_card.card
	if not _card_deals_damage(card):
		return

	var mouse_pos := get_global_mouse_position()
	var hits_all := _card_hits_all(card)

	# Find single hovered enemy (for target cards)
	var hovered: EnemyView = null
	if card.requires_target():
		for ev in _enemy_views:
			if not is_instance_valid(ev) or ev.enemy == null or ev.enemy.is_dead():
				continue
			if ev.get_global_rect().has_point(mouse_pos):
				hovered = ev
				break

	for ev in _enemy_views:
		if not is_instance_valid(ev) or ev.enemy == null or ev.enemy.is_dead():
			continue
		var should_preview: bool = false
		if hits_all and mouse_pos.y < HAND_AREA_Y:
			should_preview = true            # any-position preview for AOE
		elif ev == hovered:
			should_preview = true
		if should_preview:
			ev.show_damage_preview(_preview_card_damage(card, ev.enemy))
		else:
			ev.clear_damage_preview()


func _clear_all_damage_previews() -> void:
	for ev in _enemy_views:
		if is_instance_valid(ev):
			ev.clear_damage_preview()


# Replicates the damage modifier chain (strength → weak → vulnerable → multi-hit)
# without firing real events. Mirrors logic in:
#   - strength_behavior.gd
#   - weak_behavior.gd
#   - vulnerable_behavior.gd
func _preview_card_damage(card: Card, target: Enemy) -> int:
	var total: int = 0
	for eff in card.effects:
		if eff is DealDamage:
			var dd := eff as DealDamage
			var per_hit: int = dd.amount
			# Strength (additive)
			per_hit += _player.status_holder.get_stacks(&"strength")
			# Weak on source (×0.75)
			if _player.status_holder.get_stacks(&"weak") > 0:
				per_hit = int(floor(per_hit * 0.75))
			# Vulnerable on target (×1.5)
			if is_instance_valid(target) and target.status_holder \
					and target.status_holder.get_stacks(&"vulnerable") > 0:
				per_hit = int(floor(per_hit * 1.5))
			per_hit = maxi(per_hit, 0)
			total += per_hit * dd.times
	return total


func _card_deals_damage(card: Card) -> bool:
	for eff in card.effects:
		if eff is DealDamage:
			return true
	return false


func _card_hits_all(card: Card) -> bool:
	for eff in card.effects:
		if eff is DealDamage and (eff as DealDamage).hits_all:
			return true
	return false


func _on_end_turn_pressed() -> void:
	if not BattleManager.is_player_turn:
		return
	if _dragging_card != null:
		return
	_end_turn_btn.disabled = true
	BattleManager.end_player_turn()


func _on_result_button_pressed() -> void:
	_result_panel.visible = false
	_start_new_run_battle()


# ─────────────────────────────────────────────────────────────────────
# Refresh (batched per-frame)
# ─────────────────────────────────────────────────────────────────────

func _request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_do_refresh")


func _do_refresh() -> void:
	_refresh_queued = false
	_refresh_hand()
	for ev in _enemy_views:
		if is_instance_valid(ev):
			ev.refresh()
	_update_player_label()
	_update_pile_label()
	_update_turn_label()


func _build_enemy_views() -> void:
	for child in _enemy_container.get_children():
		child.queue_free()
	_enemy_views.clear()
	for e in BattleManager.enemies:
		var ev := EnemyView.new()
		_enemy_container.add_child(ev)
		ev.setup(e)
		_enemy_views.append(ev)


func _refresh_hand() -> void:
	if _dragging_card != null and is_instance_valid(_dragging_card):
		return   # don't rebuild while a card is mid-drag

	for child in _hand_root.get_children():
		child.queue_free()

	if BattleManager.player == null:
		return
	var hand := BattleManager.player.hand
	var n := hand.size()
	for i in n:
		var card: Card = hand[i]
		var cv := CardView.new()
		_hand_root.add_child(cv)
		cv.setup(card)
		cv.set_playable(card.is_playable(BattleManager.player.energy))
		cv.snap_to_slot(_hand_slot(i, n))
		cv.drag_started.connect(_on_card_drag_started)
		cv.drag_released.connect(_on_card_drag_released)


func _hand_slot(index: int, total: int) -> Vector2:
	var card_w: int = CardView.CARD_W
	var card_h: int = CardView.CARD_H
	var total_w: int = total * card_w + maxi(0, total - 1) * HAND_CARD_GAP
	var area_w: float = _hand_root.size.x
	var area_h: float = _hand_root.size.y
	var start_x: float = (area_w - float(total_w)) / 2.0
	var y: float = (area_h - float(card_h)) / 2.0
	return Vector2(start_x + float(index * (card_w + HAND_CARD_GAP)), y)


func _update_player_label() -> void:
	if BattleManager.player == null:
		_player_label.text = "—"
		return
	var p := BattleManager.player
	var lines: Array[String] = []
	lines.append("[Player]")
	lines.append("HP     %d/%d" % [p.hp, p.max_hp])
	lines.append("Block  %d" % p.block)
	lines.append("Energy %d/%d" % [p.energy, p.max_energy])
	if p.status_holder and not p.status_holder.stacks.is_empty():
		var parts: Array[String] = []
		for id in p.status_holder.stacks.keys():
			parts.append("%s:%d" % [str(id), p.status_holder.stacks[id]])
		lines.append(", ".join(parts))
	_player_label.text = "\n".join(lines)


func _update_pile_label() -> void:
	if BattleManager.player == null:
		_pile_label.text = ""
		return
	var p := BattleManager.player
	_pile_label.text = "Draw:    %d\nDiscard: %d\nExhaust: %d" % [
		p.draw_pile.size(), p.discard_pile.size(), p.exhaust_pile.size()
	]


func _update_turn_label() -> void:
	_turn_label.text = "Floor %d   Turn %d" % [RunState.current_floor, BattleManager.turn]


func _set_log(msg: String) -> void:
	_action_log.text = msg


# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

func _name_of(a: Actor) -> String:
	if a == null:
		return "?"
	if a is Player:
		return "Player"
	if a is Enemy:
		return (a as Enemy).data.display_name
	return "?"


# ─────────────────────────────────────────────────────────────────────
# Encounter builder (placeholder until proper pool exists)
# ─────────────────────────────────────────────────────────────────────

func _floor1_encounter() -> Encounter:
	var enc := Encounter.new()
	enc.id = &"test_dummy_1"
	enc.display_name = "Training Dummy"
	enc.tier = Encounter.Tier.NORMAL
	enc.enemies.append(_make_dummy(&"training_dummy", "Training Dummy", 32, 6))
	return enc


func _make_dummy(id: StringName, dname: String, hp: int, atk_dmg: int) -> EnemyData:
	var d := EnemyData.new()
	d.id = id
	d.display_name = dname
	d.hp_min = hp
	d.hp_max = hp
	d.tier = EnemyData.Tier.NORMAL

	var atk := EnemyMove.new()
	atk.id = &"swing"
	atk.intent = EnemyMove.Intent.ATTACK
	atk.damage = atk_dmg
	atk.weight = 1.2
	atk.max_uses_in_a_row = 2
	d.move_set.append(atk)

	var brace := EnemyMove.new()
	brace.id = &"brace"
	brace.intent = EnemyMove.Intent.DEFEND
	brace.block = 5
	brace.weight = 0.6
	brace.max_uses_in_a_row = 1
	d.move_set.append(brace)

	var taunt := EnemyMove.new()
	taunt.id = &"taunt"
	taunt.intent = EnemyMove.Intent.DEBUFF
	taunt.status_to_apply = &"weak"
	taunt.status_stacks = 1
	taunt.weight = 0.4
	taunt.max_uses_in_a_row = 1
	d.move_set.append(taunt)

	return d
