extends Control

# Human-playable battle UI with full feedback layer.
#
# Drag a playable card and release:
#   • target card → over an enemy plays; elsewhere cancels (tweens back)
#   • no-target card → above hand plays; otherwise cancels
#
# Feedback this scene provides:
#   • Card hover (CardView), drop-zone hint, damage preview
#   • Per-card draw / discard / exhaust / play animations
#   • Floating damage / block / status numbers
#   • Hit flash + particle burst + screen shake on damage
#   • Battle end fade-in then transition to run end screen
#   • Pause overlay (Pause button), deck viewer (Deck button)
#   • Vignette overlay for atmosphere


# ─────────────────────────────────────────────────────────────────────
# UI refs
# ─────────────────────────────────────────────────────────────────────

var _shake_root: Control        # Wraps everything that shakes
var _bg: ColorRect
var _vignette: TextureRect
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
var _deck_btn: Button
var _pause_btn: Button

var _fx_layer: Control

var _result_panel: PanelContainer
var _result_label: Label
var _result_button: Button
var _result_menu_button: Button
var _result_is_win: bool = false

var _pile_modal: Panel
var _pile_modal_title: Label
var _pile_modal_list: Label
var _pile_modal_close: Button

var _deck_modal: Panel
var _deck_modal_title: Label
var _deck_modal_grid: GridContainer
var _deck_modal_close: Button

var _pause_panel: Panel


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

const BIG_HIT_THRESHOLD: int = 8


# ─────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────

var _player: Player
var _enemy_views: Array[EnemyView] = []
var _connections: Array = []
var _dragging_card: CardView = null
var _card_views: Dictionary = {}
var _flying_views: Array = []


func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(1280, 720)
	_build_ui()
	_wire_events()
	SFX.play_bgm(&"battle")
	_start_new_run_battle()


func _exit_tree() -> void:
	for pair in _connections:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_connections.clear()
	get_tree().paused = false


# ─────────────────────────────────────────────────────────────────────
# UI build
# ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_shake_root = Control.new()
	_shake_root.anchor_right = 1
	_shake_root.anchor_bottom = 1
	_shake_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_shake_root)

	_bg = ColorRect.new()
	_bg.color = Color(0.06, 0.06, 0.10)
	_bg.anchor_right = 1
	_bg.anchor_bottom = 1
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.add_child(_bg)

	_vignette = _make_vignette()
	_shake_root.add_child(_vignette)

	_turn_label = Label.new()
	_turn_label.position = Vector2(20, 12)
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.text = "—"
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.add_child(_turn_label)

	_action_log = Label.new()
	_action_log.position = Vector2(550, 18)
	_action_log.size = Vector2(550, 30)
	_action_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_action_log.add_theme_font_size_override("font_size", 14)
	_action_log.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	_action_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.add_child(_action_log)

	# Top right buttons: Deck + Pause
	_deck_btn = Button.new()
	_deck_btn.text = "Deck"
	_deck_btn.position = Vector2(1110, 12)
	_deck_btn.size = Vector2(70, 32)
	_deck_btn.add_theme_font_size_override("font_size", 13)
	_deck_btn.pressed.connect(_on_deck_pressed)
	_shake_root.add_child(_deck_btn)

	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.position = Vector2(1190, 12)
	_pause_btn.size = Vector2(70, 32)
	_pause_btn.add_theme_font_size_override("font_size", 13)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_shake_root.add_child(_pause_btn)

	_enemy_container = HBoxContainer.new()
	_enemy_container.position = Vector2(0, 60)
	_enemy_container.size = Vector2(1280, 290)
	_enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_container.add_theme_constant_override("separation", 40)
	_enemy_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_shake_root.add_child(_enemy_container)

	_build_player_panel()

	_drop_zone_hint = ColorRect.new()
	_drop_zone_hint.position = Vector2(HAND_AREA_X, HAND_AREA_Y - 40)
	_drop_zone_hint.size = Vector2(HAND_AREA_W, 40)
	_drop_zone_hint.color = Color(0.6, 0.85, 0.4, 0.20)
	_drop_zone_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone_hint.visible = false
	_shake_root.add_child(_drop_zone_hint)

	_hand_root = Control.new()
	_hand_root.position = Vector2(HAND_AREA_X, HAND_AREA_Y)
	_hand_root.size = Vector2(HAND_AREA_W, HAND_AREA_H)
	_hand_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_shake_root.add_child(_hand_root)

	_draw_btn = _make_pile_button("Draw: 0", DRAW_PILE_POS, _on_draw_pile_clicked)
	_shake_root.add_child(_draw_btn)
	_discard_btn = _make_pile_button("Discard: 0", DISCARD_PILE_POS, _on_discard_pile_clicked)
	_shake_root.add_child(_discard_btn)
	_exhaust_btn = _make_pile_button("Exhaust: 0", EXHAUST_PILE_POS, _on_exhaust_pile_clicked)
	_shake_root.add_child(_exhaust_btn)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.position = Vector2(1060, 680)
	_end_turn_btn.size = Vector2(200, 32)
	_end_turn_btn.add_theme_font_size_override("font_size", 16)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_shake_root.add_child(_end_turn_btn)

	_fx_layer = Control.new()
	_fx_layer.anchor_right = 1
	_fx_layer.anchor_bottom = 1
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.add_child(_fx_layer)

	_build_result_panel()
	_build_pile_modal()
	_build_deck_modal()
	_build_pause_panel()


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
	_shake_root.add_child(_player_panel)

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


func _make_vignette() -> TextureRect:
	var tr := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.55))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 1280
	gt.height = 720
	tr.texture = gt
	tr.size = Vector2(1280, 720)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.position = Vector2(440, 240)
	_result_panel.size = Vector2(400, 260)
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
	rvb.add_theme_constant_override("separation", 18)
	_result_panel.add_child(rvb)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 32)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rvb.add_child(_result_label)
	_result_button = Button.new()
	_result_button.text = "Continue"
	_result_button.add_theme_font_size_override("font_size", 18)
	_result_button.custom_minimum_size = Vector2(200, 50)
	_result_button.pressed.connect(_on_result_continue)
	var btn_center := CenterContainer.new()
	btn_center.add_child(_result_button)
	rvb.add_child(btn_center)
	_result_menu_button = Button.new()
	_result_menu_button.text = "Main Menu"
	_result_menu_button.add_theme_font_size_override("font_size", 14)
	_result_menu_button.custom_minimum_size = Vector2(140, 36)
	_result_menu_button.pressed.connect(_on_result_menu)
	var btn_center2 := CenterContainer.new()
	btn_center2.add_child(_result_menu_button)
	rvb.add_child(btn_center2)
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


func _build_deck_modal() -> void:
	_deck_modal = Panel.new()
	_deck_modal.position = Vector2(90, 60)
	_deck_modal.size = Vector2(1100, 600)
	_deck_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var mstyle := StyleBoxFlat.new()
	mstyle.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	mstyle.set_corner_radius_all(10)
	mstyle.set_border_width_all(2)
	mstyle.border_color = Color(0.5, 0.5, 0.65)
	_deck_modal.add_theme_stylebox_override("panel", mstyle)

	_deck_modal_title = Label.new()
	_deck_modal_title.position = Vector2(0, 14)
	_deck_modal_title.size = Vector2(1100, 30)
	_deck_modal_title.add_theme_font_size_override("font_size", 22)
	_deck_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_modal.add_child(_deck_modal_title)

	_deck_modal_grid = GridContainer.new()
	_deck_modal_grid.columns = 7
	_deck_modal_grid.position = Vector2(20, 60)
	_deck_modal_grid.size = Vector2(1060, 480)
	_deck_modal_grid.add_theme_constant_override("h_separation", 12)
	_deck_modal_grid.add_theme_constant_override("v_separation", 12)
	_deck_modal_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_deck_modal.add_child(_deck_modal_grid)

	_deck_modal_close = Button.new()
	_deck_modal_close.text = "Close"
	_deck_modal_close.position = Vector2(500, 555)
	_deck_modal_close.size = Vector2(100, 30)
	_deck_modal_close.pressed.connect(_on_deck_modal_close)
	_deck_modal.add_child(_deck_modal_close)

	_deck_modal.visible = false
	add_child(_deck_modal)


func _build_pause_panel() -> void:
	_pause_panel = Panel.new()
	_pause_panel.position = Vector2(440, 220)
	_pause_panel.size = Vector2(400, 280)
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.10, 0.18, 0.97)
	ps.set_corner_radius_all(12)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.6, 0.6, 0.7)
	_pause_panel.add_theme_stylebox_override("panel", ps)

	var title := Label.new()
	title.text = "Paused"
	title.position = Vector2(0, 24)
	title.size = Vector2(400, 40)
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_panel.add_child(title)

	var resume := Button.new()
	resume.text = "Resume"
	resume.position = Vector2(100, 90)
	resume.size = Vector2(200, 44)
	resume.add_theme_font_size_override("font_size", 16)
	resume.process_mode = Node.PROCESS_MODE_ALWAYS
	resume.pressed.connect(_on_resume_pressed)
	_pause_panel.add_child(resume)

	var menu := Button.new()
	menu.text = "Quit to Main Menu"
	menu.position = Vector2(100, 150)
	menu.size = Vector2(200, 44)
	menu.add_theme_font_size_override("font_size", 16)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.pressed.connect(_on_pause_quit_pressed)
	_pause_panel.add_child(menu)

	var hint := Label.new()
	hint.text = "Game paused — battle resumes when you click Resume."
	hint.position = Vector2(20, 220)
	hint.size = Vector2(360, 40)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_panel.add_child(hint)

	_pause_panel.visible = false
	add_child(_pause_panel)


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
	_connect(BattleEvents.actor_died, _on_actor_died)


func _connect(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_connections.append([sig, cb])


# ─────────────────────────────────────────────────────────────────────
# Run / battle lifecycle
# ─────────────────────────────────────────────────────────────────────

func _start_new_run_battle() -> void:
	if not RunState.run_active:
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
	_result_is_win = true
	_show_result("Victory!", Color(0.65, 1.0, 0.7))


func _on_battle_lost() -> void:
	_result_is_win = false
	_show_result("Defeated", Color(1.0, 0.45, 0.45))
	_red_flash()


func _on_turn_started(actor: Actor) -> void:
	if actor is Player:
		_end_turn_btn.disabled = false
		_set_log("Your turn")
	else:
		_end_turn_btn.disabled = true
	_refresh_card_playability()
	_refresh_static()


func _on_card_drawn(card: Card) -> void:
	if _card_views.has(card):
		return
	var cv := CardView.new()
	_hand_root.add_child(cv)
	cv.setup(card)
	cv.drag_started.connect(_on_card_drag_started)
	cv.drag_released.connect(_on_card_drag_released)
	_card_views[card] = cv
	var start := _to_hand_local(DRAW_PILE_POS)
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
		ParticleBurst.spawn_hit(_fx_layer, pos)
		_flash_actor(tgt)
		if actual >= BIG_HIT_THRESHOLD:
			ScreenShake.shake(_shake_root, 7.0, 0.22)
		else:
			ScreenShake.shake(_shake_root, 3.0, 0.14)
	if blocked > 0:
		FloatingNumber.spawn(_fx_layer, "%d" % blocked, Color(0.6, 0.85, 1.0),
				pos + Vector2(35, 14))
		if actual == 0:
			ParticleBurst.spawn_block(_fx_layer, pos)
	_refresh_static()


func _on_block_gained(tgt: Actor, amount: int) -> void:
	if amount <= 0:
		return
	_set_log("%s +%d block" % [_name_of(tgt), amount])
	FloatingNumber.spawn(_fx_layer, "+%d Blk" % amount, Color(0.55, 0.85, 1.0),
			_actor_center(tgt))
	ParticleBurst.spawn_block(_fx_layer, _actor_center(tgt))
	_refresh_static()


func _on_status_applied(tgt: Actor, id: StringName, total: int) -> void:
	_set_log("%s: %s -> %d" % [_name_of(tgt), str(id), total])
	var data := StatusRegistry.get_status(id)
	var debuff := data != null and data.is_debuff
	var color := Color(0.85, 0.55, 0.95) if debuff else Color(0.55, 0.95, 0.65)
	FloatingNumber.spawn(_fx_layer, "%s %d" % [str(id), total], color,
			_actor_center(tgt) + Vector2(0, -22))
	if not debuff:
		ParticleBurst.spawn_buff(_fx_layer, _actor_center(tgt))
	_refresh_static()


func _on_enemy_intent_changed(_enemy: Enemy, _move: EnemyMove) -> void:
	_refresh_enemies()


func _on_actor_died(actor: Actor) -> void:
	ParticleBurst.spawn_death(_fx_layer, _actor_center(actor))


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
# Static UI
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
# Hit feedback
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


func _red_flash() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.8, 0.2, 0.2, 0.0)
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(overlay)
	var t := overlay.create_tween()
	t.tween_property(overlay, "color:a", 0.4, 0.10)
	t.tween_property(overlay, "color:a", 0.0, 0.30)
	t.tween_callback(overlay.queue_free)


# ─────────────────────────────────────────────────────────────────────
# Pile / deck / pause modals
# ─────────────────────────────────────────────────────────────────────

func _on_draw_pile_clicked() -> void:
	SFX.play(&"ui_click")
	_show_pile_modal("Draw Pile (shuffled)",
			BattleManager.player.draw_pile if BattleManager.player else [])


func _on_discard_pile_clicked() -> void:
	SFX.play(&"ui_click")
	_show_pile_modal("Discard Pile",
			BattleManager.player.discard_pile if BattleManager.player else [])


func _on_exhaust_pile_clicked() -> void:
	SFX.play(&"ui_click")
	_show_pile_modal("Exhaust Pile",
			BattleManager.player.exhaust_pile if BattleManager.player else [])


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
	SFX.play(&"ui_click")
	_pile_modal.visible = false


func _on_deck_pressed() -> void:
	SFX.play(&"ui_click")
	_deck_modal_title.text = "Your Deck (%d cards)" % RunState.deck.size()
	for c in _deck_modal_grid.get_children():
		c.queue_free()
	for card in RunState.deck:
		_deck_modal_grid.add_child(_mini_card(card))
	_deck_modal.visible = true


func _on_deck_modal_close() -> void:
	SFX.play(&"ui_click")
	_deck_modal.visible = false


func _mini_card(card: Card) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(140, 100)
	p.size = Vector2(140, 100)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.bg_color = _bg_for_card_type(card.type)
	s.border_color = Color(0.18, 0.14, 0.08)
	p.add_theme_stylebox_override("panel", s)

	var cost := Label.new()
	cost.text = "X" if card.cost == -1 else str(card.cost)
	cost.position = Vector2(8, 4)
	cost.size = Vector2(20, 22)
	cost.add_theme_font_size_override("font_size", 16)
	cost.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cost)

	var name_l := Label.new()
	name_l.text = card.display_name
	name_l.position = Vector2(32, 4)
	name_l.size = Vector2(102, 22)
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(name_l)

	var desc := Label.new()
	desc.text = card.description
	desc.position = Vector2(6, 30)
	desc.size = Vector2(128, 66)
	desc.add_theme_font_size_override("font_size", 10)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(desc)
	return p


func _bg_for_card_type(t: int) -> Color:
	match t:
		Card.Type.ATTACK: return Color(0.55, 0.18, 0.18)
		Card.Type.SKILL: return Color(0.17, 0.32, 0.48)
		Card.Type.POWER: return Color(0.42, 0.22, 0.50)
		Card.Type.CURSE: return Color(0.18, 0.10, 0.18)
		_: return Color(0.30, 0.30, 0.30)


# ─────────────────────────────────────────────────────────────────────
# Pause
# ─────────────────────────────────────────────────────────────────────

func _on_pause_pressed() -> void:
	SFX.play(&"ui_click")
	get_tree().paused = true
	_pause_panel.visible = true


func _on_resume_pressed() -> void:
	SFX.play(&"ui_click")
	get_tree().paused = false
	_pause_panel.visible = false


func _on_pause_quit_pressed() -> void:
	SFX.play(&"ui_click")
	get_tree().paused = false
	_pause_panel.visible = false
	RunState.end_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ─────────────────────────────────────────────────────────────────────
# Result panel
# ─────────────────────────────────────────────────────────────────────

func _show_result(text: String, color: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)
	_result_button.text = "Continue" if _result_is_win else "View Stats"
	_result_panel.visible = true
	_result_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_result_panel, "modulate:a", 1.0, 0.5)
	_end_turn_btn.disabled = true


func _on_end_turn_pressed() -> void:
	if not BattleManager.is_player_turn:
		return
	if _dragging_card != null:
		return
	SFX.play(&"end_turn")
	_end_turn_btn.disabled = true
	BattleManager.end_player_turn()


func _on_result_continue() -> void:
	SFX.play(&"ui_click")
	get_tree().change_scene_to_file("res://scenes/run_end_screen.tscn")


func _on_result_menu() -> void:
	SFX.play(&"ui_click")
	RunState.end_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
