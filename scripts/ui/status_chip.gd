class_name StatusChip extends Panel

# Single status effect chip: short abbreviation + count, colored by buff/debuff,
# tooltip on hover shows full name + description.


const CHIP_W: int = 38
const CHIP_H: int = 22

var _label: Label
var _style: StyleBoxFlat


func setup(id: StringName, count: int) -> void:
	custom_minimum_size = Vector2(CHIP_W, CHIP_H)
	size = Vector2(CHIP_W, CHIP_H)
	mouse_filter = Control.MOUSE_FILTER_STOP   # enable tooltip

	var data: StatusEffect = StatusRegistry.get_status(id)

	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(4)
	_style.set_border_width_all(1)
	if data != null and data.is_debuff:
		_style.bg_color = Color(0.55, 0.18, 0.18)
		_style.border_color = Color(0.85, 0.35, 0.35)
	else:
		_style.bg_color = Color(0.16, 0.45, 0.28)
		_style.border_color = Color(0.30, 0.75, 0.45)
	add_theme_stylebox_override("panel", _style)

	_label = Label.new()
	_label.position = Vector2(0, 0)
	_label.size = Vector2(CHIP_W, CHIP_H)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.text = "%s %d" % [_abbrev(id), count]
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	if data != null:
		tooltip_text = "%s (%d)\n%s" % [data.display_name, count, data.description]


func update_count(count: int) -> void:
	var parts: PackedStringArray = _label.text.split(" ", false, 1)
	if parts.size() > 0:
		_label.text = "%s %d" % [parts[0], count]
	var data: StatusEffect = null
	if tooltip_text != "":
		# Re-derive id from current label prefix (lossy but ok)
		pass
	_label.text = _label.text
	if data:
		tooltip_text = "%s (%d)\n%s" % [data.display_name, count, data.description]


static func _abbrev(id: StringName) -> String:
	match id:
		&"strength": return "STR"
		&"dexterity": return "DEX"
		&"vulnerable": return "VLN"
		&"weak": return "WEAK"
		&"frail": return "FRL"
		&"poison": return "PSN"
		&"metallicize": return "MET"
		&"thorns": return "THN"
		_: return String(id).substr(0, 3).to_upper()
