extends Control

# Human-playable battle UI with full feedback layer.
#
# Drag a playable card and release:
#   • target card → release over an enemy to play; elsewhere cancels (tweens back)
#   • no-target card → release above the hand row to play; otherwise cancels
#
# Feedback this scene now provides:
#   • Card hover (CardView), drop-zone hint, damage preview (CardView + EnemyView)
#   • Per-card draw / discard / exhaust / play animations
#   • Floating damage / block / status numbers
#   • Hit flash on damage targets
#   • Battle end fade-in
#   • Pile click → modal showing piles' card lists
# Combat pacing comes from BattleManager (async enemy turn).


# ─────────────────────────────────────────────────────────────────────
# UI refs
# ─────────────────────────────────────────────────────────────────────

var _bg: ColorRect
var _turn_label: Label
var _action_log: Label
var _enemy_container: HBoxContainer

var _player_panel: Panel
var _player_name_label: Label
var _player_hp_bar: HPBar
var _player_block_label: Label
var _player_energy_orb: EnergyOrb
var _player_status_row: HBoxContainer

var _hand_root: Control
var _drop_zone_hint: ColorRect

var _draw_btn: Button
var _discard_btn: Button
var _exhaust_btn: Button

var _end_turn_btn: Button

var _fx_layer: Control          # floats, hit overlays — top of stack

var _result_panel: PanelContainer
var _result_label: Label
var _result_button: Button

var _pile_modal: Panel          # popup for pile viewer
var _pile_modal_title: Label
var _pile_modal_list: Label
var _pile_modal_close: Button


# ─────────────────────────────────────────────────────────────────────
# Layout constants
# ─────────────────────────────────────────────────────────────────────

const HAND_AREA_X: int = 240
const HAND_AREA_Y: int = 540
const HAND_AREA_W: int = 800
const HAND_AREA_H: int = 180
const HAND_CARD_GAP: int = 8

const DRAW_PILE_POS: Vector2 = Vector2(1095, 568)
const DISCARD_PILE_POS: Vector2 = Vector2(1095, 605)
const EXHAUST_PILE_POS: Vector2 = Vector2(1095, 642)


# ─────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────

var _player: Player
var _enemy_views: Array[EnemyView] = []
var _connections: Array = []
var _dragging_card: CardView = null

# Card -> CardView, only for cards currently in hand. Views being animated
# away (discard/exhaust/play) are tracked in _flying_views instead.
var _card_views: Dictionary = {}
var _flying_views: Array = []


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
	_enemy_container.size = Vector2(1280, 290)
	_enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_container.add_theme_constant_override("separation", 40)
	_enemy_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_enemy_container)

	_build_player_panel()

	# Drop-zone hint banner
	_drop_zone_hint = ColorRect.new()
	_drop_zone_hint.position = Vector2(HAND_AREA_X, HAND_AREA_Y - 40)
	_drop_zone_hint.size = Vector2(HAND_AREA_W, 40)
	_drop_zone_hint.color = Color(0.6, 0.85, 0.4, 0.20)
	_drop_zone_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone_hint.visible = false
	add_child(_drop_zone_hint)

	_hand_root = Control.new()
	_hand_root.position = Vector2(HAND_AREA_X, HAND_AREA_Y)
	_hand_root.size = Vector2(HAND_AREA_W, HAND_AREA_H)
	_hand_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_hand_root)

	# Pile buttons (right side)
	_draw_btn = _make_pile_button("Draw: 0", DRAW_PILE_POS, _on_draw_pile_clicked)
	add_child(_draw_btn)
	_discard_btn = _make_pile_button("Discard: 0", DISCARD_PILE_POS, _on_discard_pile_clicked)
	add_child(_discard_btn)
	_exhaust_btn = _make_pile_button("Exhaust: 0", EXHAUST_PILE_POS, _on_exhaust_pile_clicked)
	add_child(_exhaust_btn)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.position = Vector2(1060, 680)
	_end_turn_btn.size = Vector2(200, 32)
	_end_turn_btn.add_theme_font_size_override("font_size", 16)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	add_child(_end_turn_btn)

	# FX layer (always on top so floats / overlays don't get covered)
	_fx_layer = Control.new()
	_fx_layer.anchor_right = 1
	_fx_layer.anchor_bottom = 1
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	_build_result_panel()
	_build_pile_modal()


func _build_player_panel() -> void:
	_player_panel = Panel.new()
	_player_panel.position = Vector2(20, 380)
	_player_panel.size = Vector2(200, 220)
	_player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.15, 0.20, 0.30)
	pstyle.set_corner_radius_all(8)
	pstyle.set_border_width_all(1)
	pstyle.border_color = Color(0.35, 0.45, 0.60)
	_player_panel.add_theme_stylebox_override("panel", pstyle)
	add_child(_player_panel)

	_player_name_label = Label.new()
	_player_name_label.position = Vector2(12, 10)
	_player_name_label.size = Vector2(176, 22)
	_player_name_label.text = "Player"
	_player_name_label.add_theme_font_size_override("font_size", 16)
	_player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_panel.add_child(_player_name_label)

	_player_hp_bar = HPBar.new()
	_player_hp_bar.position = Vector2(12, 38)
	_player_hp_bar.setup(176)
	_player_panel.add_child(_player_hp_bar)

	_player_block_label = Label.new()
	_player_block_label.position = Vector2(12, 66)
	_player_block_label.size = Vector2(176, 22)
	_player_block_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_player_block_label.add_theme_font_size_override("font_size", 14)
	_player_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_panel.add_child(_player_block_label)

	_player_energy_orb = EnergyOrb.new()
	_player_energy_orb.position = Vector2(12, 92)
	_player_panel.add_child(_player_energy_orb)

	_player_status_row = HBoxContainer.new()
	_player_status_row.position = Vector2(12, 154)
	_player_status_row.size = Vector2(176, 32)
	_player_status_row.add_theme_constant_override("separation", 4)
	_player_status_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_player_panel.add_child(_player_status_row)


func _make_pile_button(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(150, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	return b


func _build_result_panel() -> void:
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


func _build_pile_modal() -> void:
	_pile_modal = Panel.new()
	_pile_modal.position = Vector2(340, 100)
	_pile_modal.size = Vector2(600, 520)
	_pile_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var mstyle := StyleBoxFlat.new()
	mstyle.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	mstyle.set_corner_radius_all(10)
	mstyle.set_border_width_all(2)
	mstyle.border_color = Color(0.5, 0.5, 0.65)
	_pile_modal.add_theme_stylebox_override("panel", mstyle)

	_pile_modal_title = Label.new()
	_pile_modal_title.position = Vector2(20, 14)
	_pile_modal_title.size = Vector2(560, 30)
	_pile_modal_title.add_theme_font_size_override("font_size", 22)
	_pile_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pile_modal.add_child(_pile_modal_title)

	_pile_modal_list = Label.new()
	_pile_modal_list.position = Vector2(30, 58)
	_pile_modal_list.size = Vector2(540, 410)
	_pile_modal_list.add_theme_font_size_override("font_size", 14)
	_pile_modal_list.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_pile_modal_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pile_modal.add_child(_pile_modal_list)

	_pile_modal_close = Button.new()
	_pile_modal_close.text = "Close"
	_pile_modal_close.position = Vector2(250, 478)
	_pile_modal_close.size = Vector2(100, 30)
	_pile_modal_close.pressed.connect(_on_pile_modal_close)
	_pile_modal.add_child(_pile_modal_close)

	_pile_modal.visible = false
	add_child(_pile_modal)


# ─────────────────────────────────────────────────────────────────────
# Events
# ─────────────────────────────────────────────────────────────────────

func _wire_events() -> void:
	_connect(BattleEvents.battle_started, _on_battle_started)
	_connect(BattleEvents.battle_won, _on_battle_won)
	_connect(BattleEvents.battle_lost, _on_battle_lost)
	_connect(BattleEvents.turn_started, _on_turn_started)
	_connect(BattleEvents.card_drawn, _on_card_drawn)
	_connect(BattleEvents.card_discarded, _on_card_discarded)
	_connect(BattleEvents.card_exhausted, _on_card_exhausted)
	_connect(BattleEvents.card_resolved, _on_card_resolved)
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
	_clear_hand_state()
	_player = Player.new()
	add_child(_player)
	_player.setup_run(RunState.max_hp, RunState.hp, RunState.deck)
	_result_panel.visible = false
	_result_panel.modulate.a = 1
	_end_turn_btn.disabled = false
	BattleManager.start_battle(_player, encounter, RunState.rng.randi())


func _clear_hand_state() -> void:
	for cv in _card_views.values():
		if is_instance_valid(cv):
			cv.queue_free()
	_card_views.clear()
	for cv in _flying_views.duplicate():
		if is_instance_valid(cv):
			cv.queue_free()
	_flying_views.clear()
	_dragging_card = null


# ─────────────────────────────────────────────────────────────────────
# Battle event handlers
# ─────────────────────────────────────────────────────────────────────

func _on_battle_started() -> void:
	_build_enemy_views()
	_set_log("Battle start")
	_layout_hand(false)
	_refresh_static()


func _on_battle_won() -> void:
	if BattleManager.player:
		RunState.hp = BattleManager.player.hp
	_show_result("Victory!", "Restart Run", Color(0.65, 1.0, 0.7))


func _on_battle_lost() -> void:
	_show_result("Defeated", "Restart Run", Color(1.0, 0.45, 0.45))


func _on_turn_started(actor: Actor) -> void:
	if actor is Player:
		_end_turn_btn.disabled = false
		_set_log("Your turn")
	else:
		_end_turn_btn.disabled = true
	_refresh_card_playability()
	_refresh_static()


func _on_card_drawn(card: Card) -> void:
	# Spawn a CardView for the new card, animate from draw pile to its slot.
	if _card_views.has(card):
		return
	var cv := CardView.new()
	_hand_root.add_child(cv)
	cv.setup(card)
	cv.drag_started.connect(_on_card_drag_started)
	cv.drag_released.connect(_on_card_drag_released)
	_card_views[card] = cv

	# Start position in _hand_root-local coords (draw pile is in scene-local)
	var start := _to_hand_local(DRAW_PILE_POS)
	# Slot will be computed after layout.
	cv.slide_in_from(start, start)
	_layout_hand(false)
	_refresh_card_playability()
	_refresh_static()


func _on_card_discarded(card: Card) -> void:
	_fly_card_to_pile(card, DISCARD_PILE_POS, Color(0.7, 0.75, 0.85))
	_layout_hand(true)
	_refresh_static()


func _on_card_exhausted(card: Card) -> void:
	_fly_card_to_pile(card, EXHAUST_PILE_POS, Color(0.85, 0.45, 0.45))
	_layout_hand(true)
	_refresh_static()


func _on_card_resolved(_card: Card) -> void:
	_refresh_card_playability()
	_refresh_static()


func _on_damage_dealt(_src: Actor, tgt: Actor, actual: int, blocked: int) -> void:
	if blocked > 0:
		_set_log("%s -%d HP (%d blocked)" % [_name_of(tgt), actual, blocked])
	else:
		_set_log("%s -%d HP" % [_name_of(tgt), actual])
	var pos := _actor_center(tgt)
	if actual > 0:
		FloatingNumber.spawn(_fx_layer, "-%d" % actual, Color(1.0, 0.35, 0.35), pos)
	if blocked > 0:
		FloatingNumber.spawn(_fx_layer, "%d" % blocked, Color(0.6, 0.85, 1.0),
				pos + Vector2(35, 14))
	_flash_actor(tgt)
	_refresh_static()


func _on_block_gained(tgt: Actor, amount: int) -> void:
	if amount <= 0:
		return
	_set_log("%s +%d block" % [_name_of(tgt), amount])
	FloatingNumber.spawn(_fx_layer, "+%d Blk" % amount, Color(0.55, 0.85, 1.0),
			_actor_center(tgt))
	_refresh_static()


func _on_status_applied(tgt: Actor, id: StringName, total: int) -> void:
	_set_log("%s: %s -> %d" % [_name_of(tgt), str(id), total])
	var data := StatusRegistry.get_status(id)
	var color := Color(0.85, 0.55, 0.95) if (data and data.is_debuff) \
			else Color(0.55, 0.95, 0.65)
	FloatingNumber.spawn(_fx_layer, "%s %d" % [str(id), total], color,
			_actor_center(tgt) + Vector2(0, -22))
	_refresh_static()


func _on_enemy_intent_changed(_enemy: Enemy, _move: EnemyMove) -> void:
	_refresh_enemies()


# ─────────────────────────────────────────────────────────────────────
# Drag handlers + per-frame damage preview
# ─────────────────────────────────────────────────────────────────────

func _on_card_drag_started(cv: CardView) -> void:
	_dragging_card = cv
	_end_turn_btn.disabled = true
	if not cv.card.requires_target():
		_drop_zone_hint.visible = true


func _on_card_drag_released(cv: CardView, release_global_pos: Vector2) -> void:
	_dragging_card = null
	_drop_zone_hint.visible = false
	_clear_all_damage_previews()
	_end_turn_btn.disabled = not BattleManager.is_player_turn

	if not BattleManager.is_player_turn or not BattleManager.battle_active:
		cv.cancel_drag()
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
					_set_log("Played %s on %s"
							% [card.display_name, ev.enemy.data.display_name])
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

	if not played:
		cv.cancel_drag()
	# If played, _on_card_discarded / _on_card_exhausted will fly it away.


func _process(_delta: float) -> void:
	if _dragging_card == null or not is_instance_valid(_dragging_card):
		return
	var card := _dragging_card.card
	if not _card_deals_damage(card):
		return

	var mouse_pos := get_global_mouse_position()
	var hits_all := _card_hits_all(card)

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
		var show_preview: bool = false
		if hits_all and mouse_pos.y < HAND_AREA_Y:
			show_preview = true
		elif ev == hovered:
			show_preview = true
		if show_preview:
			ev.show_damage_preview(_preview_card_damage(card, ev.enemy))
		else:
			ev.clear_damage_preview()


func _clear_all_damage_previews() -> void:
	for ev in _enemy_views:
		if is_instance_valid(ev):
			ev.clear_damage_preview()


func _preview_card_damage(card: Card, target: Enemy) -> int:
	var total: int = 0
	for eff in card.effects:
		if eff is DealDamage:
			var dd := eff as DealDamage
			var per_hit: int = dd.amount
			per_hit += _player.status_holder.get_stacks(&"strength")
			if _player.status_holder.get_stacks(&"weak") > 0:
				per_hit = int(floor(per_hit * 0.75))
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


# ─────────────────────────────────────────────────────────────────────
# Card animations
# ─────────────────────────────────────────────────────────────────────

func _fly_card_to_pile(card: Card, pile_world: Vector2, tint: Color) -> void:
	if not _card_views.has(card):
		return
	var cv: CardView = _card_views[card]
	_card_views.erase(card)
	if not is_instance_valid(cv):
		return
	_flying_views.append(cv)

	# Move under the fx layer so the card flies on top of everything.
	var current_global := cv.global_position
	cv.get_parent().remove_child(cv)
	_fx_layer.add_child(cv)
	cv.global_position = current_global
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var target_local := pile_world - Vector2(CardView.CARD_W / 2.0,
			CardView.CARD_H / 2.0)
	var t := cv.create_tween().set_parallel(true)
	t.tween_property(cv, "global_position", target_local, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(cv, "scale", Vector2(0.35, 0.35), 0.30)
	t.tween_property(cv, "modulate", tint, 0.10)
	t.chain().tween_property(cv, "modulate:a", 0.0, 0.12)
	t.chain().tween_callback(func():
		_flying_views.erase(cv)
		cv.queue_free())


# ─────────────────────────────────────────────────────────────────────
# Hand layout
# ─────────────────────────────────────────────────────────────────────

func _layout_hand(animated: bool) -> void:
	if BattleManager.player == null:
		return
	var hand := BattleManager.player.hand
	var n := hand.size()
	for i in n:
		var card: Card = hand[i]
		if not _card_views.has(card):
			continue
		var cv: CardView = _card_views[card]
		if not is_instance_valid(cv):
			continue
		if cv == _dragging_card:
			continue
		var slot := _hand_slot(i, n)
		if animated:
			cv.glide_to_slot(slot)
		else:
			cv.snap_to_slot(slot)


func _hand_slot(index: int, total: int) -> Vector2:
	var card_w: int = CardView.CARD_W
	var card_h: int = CardView.CARD_H
	var total_w: int = total * card_w + maxi(0, total - 1) * HAND_CARD_GAP
	var area_w: float = _hand_root.size.x
	var area_h: float = _hand_root.size.y
	var start_x: float = (area_w - float(total_w)) / 2.0
	var y: float = (area_h - float(card_h)) / 2.0
	return Vector2(start_x + float(index * (card_w + HAND_CARD_GAP)), y)


func _refresh_card_playability() -> void:
	if BattleManager.player == null:
		return
	var energy := BattleManager.player.energy if BattleManager.is_player_turn else 0
	for entry in _card_views.values():
		var cv: CardView = entry
		if is_instance_valid(cv):
			cv.set_playable(BattleManager.is_player_turn and cv.card.is_playable(energy))


# ─────────────────────────────────────────────────────────────────────
# Static UI (player panel, piles, enemy refresh, turn label)
# ─────────────────────────────────────────────────────────────────────

func _refresh_static() -> void:
	_update_player_panel()
	_update_pile_buttons()
	_update_turn_label()


func _refresh_enemies() -> void:
	for ev in _enemy_views:
		if is_instance_valid(ev):
			ev.refresh()


func _build_enemy_views() -> void:
	for child in _enemy_container.get_children():
		child.queue_free()
	_enemy_views.clear()
	for e in BattleManager.enemies:
		var ev := EnemyView.new()
		_enemy_container.add_child(ev)
		ev.setup(e)
		_enemy_views.append(ev)


func _update_player_panel() -> void:
	if BattleManager.player == null:
		return
	var p := BattleManager.player
	_player_hp_bar.set_hp(p.hp, p.max_hp)
	_player_block_label.text = ("Block %d" % p.block) if p.block > 0 else ""
	_player_energy_orb.set_energy(p.energy, p.max_energy)
	_rebuild_player_status_row()


func _rebuild_player_status_row() -> void:
	for c in _player_status_row.get_children():
		c.queue_free()
	var p := BattleManager.player
	if p == null or p.status_holder == null:
		return
	for id in p.status_holder.stacks.keys():
		var chip := StatusChip.new()
		_player_status_row.add_child(chip)
		chip.setup(id, p.status_holder.stacks[id])


func _update_pile_buttons() -> void:
	if BattleManager.player == null:
		_draw_btn.text = "Draw: 0"
		_discard_btn.text = "Discard: 0"
		_exhaust_btn.text = "Exhaust: 0"
		return
	var p := BattleManager.player
	_draw_btn.text = "Draw: %d" % p.draw_pile.size()
	_discard_btn.text = "Discard: %d" % p.discard_pile.size()
	_exhaust_btn.text = "Exhaust: %d" % p.exhaust_pile.size()


func _update_turn_label() -> void:
	_turn_label.text = "Floor %d   Turn %d" % [RunState.current_floor, BattleManager.turn]


func _set_log(msg: String) -> void:
	_action_log.text = msg


# ─────────────────────────────────────────────────────────────────────
# Hit flash
# ─────────────────────────────────────────────────────────────────────

func _flash_actor(actor: Actor) -> void:
	if actor is Enemy:
		for ev in _enemy_views:
			if is_instance_valid(ev) and ev.enemy == actor:
				ev.flash_hit()
				return
	elif actor is Player and is_instance_valid(_player_panel):
		_player_panel.modulate = Color(1.6, 0.45, 0.45)
		var t := _player_panel.create_tween()
		t.tween_property(_player_panel, "modulate", Color.WHITE, 0.30)


# ─────────────────────────────────────────────────────────────────────
# Pile viewer modal
# ─────────────────────────────────────────────────────────────────────

func _on_draw_pile_clicked() -> void:
	_show_pile_modal("Draw Pile (shuffled)", BattleManager.player.draw_pile if BattleManager.player else [])


func _on_discard_pile_clicked() -> void:
	_show_pile_modal("Discard Pile", BattleManager.player.discard_pile if BattleManager.player else [])


func _on_exhaust_pile_clicked() -> void:
	_show_pile_modal("Exhaust Pile", BattleManager.player.exhaust_pile if BattleManager.player else [])


func _show_pile_modal(title: String, cards: Array) -> void:
	_pile_modal_title.text = "%s (%d)" % [title, cards.size()]
	if cards.is_empty():
		_pile_modal_list.text = "(empty)"
	else:
		var counts: Dictionary = {}
		for c in cards:
			counts[c.display_name] = counts.get(c.display_name, 0) + 1
		var lines: Array[String] = []
		for name in counts.keys():
			lines.append("  %s   x%d" % [name, counts[name]])
		_pile_modal_list.text = "\n".join(lines)
	_pile_modal.visible = true


func _on_pile_modal_close() -> void:
	_pile_modal.visible = false


# ─────────────────────────────────────────────────────────────────────
# Result panel
# ─────────────────────────────────────────────────────────────────────

func _show_result(text: String, btn_text: String, color: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)
	_result_button.text = btn_text
	_result_panel.visible = true
	_result_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_result_panel, "modulate:a", 1.0, 0.4)
	_end_turn_btn.disabled = true


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
# Geometry helpers
# ─────────────────────────────────────────────────────────────────────

func _to_hand_local(global_pos: Vector2) -> Vector2:
	return global_pos - _hand_root.global_position


func _actor_center(actor: Actor) -> Vector2:
	if actor is Player and is_instance_valid(_player_panel):
		return _player_panel.position + _player_panel.size / 2.0
	if actor is Enemy:
		for ev in _enemy_views:
			if is_instance_valid(ev) and ev.enemy == actor:
				return ev.global_position + ev.size / 2.0
	return Vector2(640, 360)


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
