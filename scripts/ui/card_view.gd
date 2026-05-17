class_name CardView extends Panel

# Card visual + drag state machine + hover affordance.
#
# Sizing: Panel (not PanelContainer) so we control size explicitly and
# don't get squashed/stretched by Container auto-layout. All children are
# positioned absolutely.
#
# Hover: scale 1.08 + lift 20px upward via Tween while in IDLE state.
# Drag: top_level + z_index 100, follows cursor, snaps back on cancel.


signal drag_started(card_view: CardView)
signal drag_released(card_view: CardView, release_global_pos: Vector2)

const CARD_W: int = 130
const CARD_H: int = 180

const HOVER_SCALE: Vector2 = Vector2(1.08, 1.08)
const HOVER_LIFT: float = 20.0
const HOVER_TIME: float = 0.12

enum State { IDLE, DRAG }

var card: Card
var playable: bool = true

var _state: State = State.IDLE
var _slot_position: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO

var _name_label: Label
var _cost_label: Label
var _desc_label: Label
var _type_label: Label
var _style: StyleBoxFlat
var _hover_tween: Tween


func setup(p_card: Card) -> void:
	card = p_card
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Pivot at bottom-center so hover lift + scale looks like the card grows up
	pivot_offset = Vector2(CARD_W / 2.0, CARD_H)
	_build()
	_paint()


# Caller sets both visual position and the rest target in one call so hover
# tweens always restore to the correct slot.
func snap_to_slot(pos: Vector2) -> void:
	_slot_position = pos
	position = pos


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# ─────────────────────────────────────────────────────────────────────
# Build (absolute layout — Panel is a plain Control with a stylebox)
# ─────────────────────────────────────────────────────────────────────

func _build() -> void:
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(8)
	_style.set_border_width_all(2)
	add_theme_stylebox_override("panel", _style)

	_cost_label = Label.new()
	_cost_label.position = Vector2(8, 4)
	_cost_label.size = Vector2(28, 30)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.add_theme_font_size_override("font_size", 22)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_cost_label)

	_name_label = Label.new()
	_name_label.position = Vector2(38, 8)
	_name_label.size = Vector2(CARD_W - 46, 22)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	add_child(_name_label)

	var sep := ColorRect.new()
	sep.position = Vector2(8, 36)
	sep.size = Vector2(CARD_W - 16, 1)
	sep.color = Color(1, 1, 1, 0.25)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)

	_desc_label = Label.new()
	_desc_label.position = Vector2(8, 44)
	_desc_label.size = Vector2(CARD_W - 16, CARD_H - 70)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desc_label)

	_type_label = Label.new()
	_type_label.position = Vector2(8, CARD_H - 22)
	_type_label.size = Vector2(CARD_W - 16, 16)
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_label.add_theme_font_size_override("font_size", 10)
	_type_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_type_label)


func _paint() -> void:
	_name_label.text = card.display_name
	_cost_label.text = "X" if card.cost == -1 else str(card.cost)
	_desc_label.text = card.description
	_type_label.text = _type_name()
	_style.bg_color = _bg_for_type()
	_style.border_color = Color(0.18, 0.14, 0.08)


func _type_name() -> String:
	match card.type:
		Card.Type.ATTACK: return "ATTACK"
		Card.Type.SKILL: return "SKILL"
		Card.Type.POWER: return "POWER"
		Card.Type.STATUS: return "STATUS"
		Card.Type.CURSE: return "CURSE"
		_: return ""


func _bg_for_type() -> Color:
	match card.type:
		Card.Type.ATTACK: return Color(0.55, 0.18, 0.18)
		Card.Type.SKILL: return Color(0.17, 0.32, 0.48)
		Card.Type.POWER: return Color(0.42, 0.22, 0.50)
		Card.Type.CURSE: return Color(0.18, 0.10, 0.18)
		Card.Type.STATUS: return Color(0.30, 0.30, 0.30)
		_: return Color(0.30, 0.30, 0.30)


func set_playable(value: bool) -> void:
	playable = value
	modulate = Color.WHITE if playable else Color(0.55, 0.55, 0.55)


# ─────────────────────────────────────────────────────────────────────
# Hover affordance
# ─────────────────────────────────────────────────────────────────────

func _on_mouse_entered() -> void:
	if _state != State.IDLE:
		return
	if not playable:
		return
	_tween_to(_slot_position + Vector2(0, -HOVER_LIFT), HOVER_SCALE)


func _on_mouse_exited() -> void:
	if _state != State.IDLE:
		return
	_tween_to(_slot_position, Vector2.ONE)


func _tween_to(target_pos: Vector2, target_scale: Vector2) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(self, "position", target_pos, HOVER_TIME).set_trans(Tween.TRANS_QUAD)
	_hover_tween.tween_property(self, "scale", target_scale, HOVER_TIME).set_trans(Tween.TRANS_QUAD)


# ─────────────────────────────────────────────────────────────────────
# Drag state machine
# ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if _state != State.IDLE:
		return
	if not playable:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_start_drag(mb.global_position)
			accept_event()


func _input(event: InputEvent) -> void:
	if _state != State.DRAG:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		position = mm.global_position - _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_end_drag(mb.global_position)
			get_viewport().set_input_as_handled()


func _start_drag(click_global_pos: Vector2) -> void:
	# Cancel hover so the card snaps to its slot before going top-level
	if _hover_tween:
		_hover_tween.kill()
		_hover_tween = null
	scale = Vector2.ONE
	position = _slot_position

	var cur_global := global_position
	_state = State.DRAG
	top_level = true
	z_index = 100
	_drag_offset = click_global_pos - cur_global
	position = cur_global   # now in viewport coords
	drag_started.emit(self)


func _end_drag(release_global_pos: Vector2) -> void:
	_state = State.IDLE
	top_level = false
	z_index = 0
	position = _slot_position
	scale = Vector2.ONE
	drag_released.emit(self, release_global_pos)


func is_dragging() -> bool:
	return _state == State.DRAG
