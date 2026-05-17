class_name CardView extends PanelContainer

signal clicked(card_view: CardView)

const CARD_W: int = 130
const CARD_H: int = 180

var card: Card
var selected: bool = false
var playable: bool = true

var _name_label: Label
var _cost_label: Label
var _desc_label: Label
var _type_label: Label
var _style: StyleBoxFlat


func setup(p_card: Card) -> void:
	card = p_card
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_paint()


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
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 22)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_cost_label.custom_minimum_size = Vector2(24, 0)
	header.add_child(_cost_label)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_name_label)
	vb.add_child(header)

	vb.add_child(HSeparator.new())

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_desc_label)

	_type_label = Label.new()
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
	_style.border_color = Color(1.0, 0.92, 0.20) if selected else Color(0.18, 0.14, 0.08)


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


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	_paint()


func set_playable(value: bool) -> void:
	playable = value
	modulate = Color.WHITE if playable else Color(0.55, 0.55, 0.55)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)
			accept_event()
