class_name EnergyOrb extends Panel

# Circular energy display. Bright orange when energy > 0, dim when empty.


const ORB_SIZE: int = 54

var _label: Label
var _style: StyleBoxFlat
var _current: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ORB_SIZE, ORB_SIZE)
	size = Vector2(ORB_SIZE, ORB_SIZE)

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.85, 0.50, 0.18)
	_style.set_corner_radius_all(ORB_SIZE / 2)
	_style.set_border_width_all(3)
	_style.border_color = Color(0.40, 0.22, 0.06)
	add_theme_stylebox_override("panel", _style)

	_label = Label.new()
	_label.position = Vector2(0, 0)
	_label.size = Vector2(ORB_SIZE, ORB_SIZE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func set_energy(current: int, max_: int) -> void:
	_current = current
	_label.text = "%d/%d" % [current, max_]
	if current <= 0:
		_style.bg_color = Color(0.35, 0.25, 0.18)
	else:
		_style.bg_color = Color(0.85, 0.50, 0.18)
