class_name HPBar extends Panel

# HP progress bar with text overlay. Color shifts as HP drops:
#   >50% green  ·  25-50% amber  ·  <25% red


@export var bar_height: int = 22

var _fill: ColorRect
var _label: Label
var _bg_style: StyleBoxFlat
var _max_value: int = 1
var _value: int = 1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(width: int) -> void:
	custom_minimum_size = Vector2(width, bar_height)
	size = Vector2(width, bar_height)

	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = Color(0.10, 0.08, 0.08)
	_bg_style.set_corner_radius_all(4)
	_bg_style.set_border_width_all(1)
	_bg_style.border_color = Color(0.5, 0.4, 0.4)
	add_theme_stylebox_override("panel", _bg_style)

	_fill = ColorRect.new()
	_fill.position = Vector2(2, 2)
	_fill.size = Vector2(width - 4, bar_height - 4)
	_fill.color = Color(0.30, 0.75, 0.30)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	_label = Label.new()
	_label.position = Vector2(0, 0)
	_label.size = Vector2(width, bar_height)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func set_hp(current: int, max_: int) -> void:
	_value = current
	_max_value = max_
	_label.text = "%d / %d" % [current, max_]
	var ratio: float = 0.0 if max_ <= 0 else clampf(float(current) / float(max_), 0.0, 1.0)
	var fw: float = max(0.0, (size.x - 4) * ratio)
	_fill.size.x = fw
	_fill.color = _color_for(ratio)


func _color_for(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.30, 0.75, 0.30)
	elif ratio > 0.25:
		return Color(0.85, 0.70, 0.20)
	else:
		return Color(0.80, 0.25, 0.20)
