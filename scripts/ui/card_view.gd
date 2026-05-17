class_name CardView extends PanelContainer

# Drag-and-drop card.
# Press LMB on a playable card → enter DRAG, card follows cursor.
# Release LMB → emit drag_released(self, release_global_pos).
# Parent decides what to do (play on enemy / play self / cancel).
# On cancel the card automatically snaps back to its slot position.


signal drag_started(card_view: CardView)
signal drag_released(card_view: CardView, release_global_pos: Vector2)

const CARD_W: int = 130
const CARD_H: int = 180

enum State { IDLE, DRAG }

var card: Card
var playable: bool = true

var _state: State = State.IDLE
var _drag_offset: Vector2 = Vector2.ZERO
var _rest_position: Vector2 = Vector2.ZERO

var _name_label: Label
var _cost_label: Label
var _desc_label: Label
var _type_label: Label
var _style: StyleBoxFlat


func setup(p_card: Card) -> void:
	card = p_card
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_paint()


# ─────────────────────────────────────────────────────────────────────
# Visuals
# ─────────────────────────────────────────────────────────────────────

func _build() -> void:
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(8)
	_style.set_border_width_all(2)
	_style.content_margin_left = 8
	_style.content_margin_right = 8
	_style.content_margin_top = 6
	_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", _style)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE   # don't eat clicks meant for us
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 4)
	_cost_label = Label.new()
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.add_theme_font_size_override("font_size", 22)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_cost_label.custom_minimum_size = Vector2(24, 0)
	header.add_child(_cost_label)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_name_label)
	vb.add_child(header)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sep)

	_desc_label = Label.new()
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_desc_label)

	_type_label = Label.new()
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_label.add_theme_font_size_override("font_size", 10)
	_type_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_type_label)


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
	_rest_position = position                 # parent-local slot
	var cur_global := global_position         # before top_level changes semantics
	_state = State.DRAG
	top_level = true                          # transform now viewport-independent
	z_index = 100
	_drag_offset = click_global_pos - cur_global
	position = cur_global
	drag_started.emit(self)


func _end_drag(release_global_pos: Vector2) -> void:
	_state = State.IDLE
	top_level = false
	z_index = 0
	position = _rest_position                 # snap back; refresh frees us if played
	drag_released.emit(self, release_global_pos)


func is_dragging() -> bool:
	return _state == State.DRAG
