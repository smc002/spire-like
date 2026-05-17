class_name EnemyView extends PanelContainer

# Mouse filter is PASS — clicks fall through to the dragging CardView's _input.
# (Hit-test for drop-on-enemy happens in BattleScene via get_global_rect.)


const VIEW_W: int = 200
const VIEW_H: int = 260

var enemy: Enemy

var _name_label: Label
var _intent_label: Label
var _hp_label: Label
var _block_label: Label
var _status_label: Label
var _style: StyleBoxFlat


func setup(p_enemy: Enemy) -> void:
	enemy = p_enemy
	custom_minimum_size = Vector2(VIEW_W, VIEW_H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	refresh()


func _build() -> void:
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(8)
	_style.bg_color = Color(0.28, 0.20, 0.20)
	_style.set_border_width_all(2)
	_style.border_color = Color(0.55, 0.40, 0.25)
	_style.content_margin_left = 10
	_style.content_margin_right = 10
	_style.content_margin_top = 8
	_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", _style)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	vb.add_child(_name_label)

	_intent_label = Label.new()
	_intent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.add_theme_font_size_override("font_size", 18)
	_intent_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	vb.add_child(_intent_label)

	var sprite_box := PanelContainer.new()
	sprite_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_box.custom_minimum_size = Vector2(0, 90)
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color(0.20, 0.14, 0.14)
	sbs.set_corner_radius_all(4)
	sprite_box.add_theme_stylebox_override("panel", sbs)
	var sprite_label := Label.new()
	sprite_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sprite_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sprite_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_label.text = "(sprite)"
	sprite_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	sprite_box.add_child(sprite_label)
	vb.add_child(sprite_box)

	var hpbox := HBoxContainer.new()
	hpbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label = Label.new()
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_label.add_theme_font_size_override("font_size", 14)
	hpbox.add_child(_hp_label)
	_block_label = Label.new()
	_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_block_label.add_theme_font_size_override("font_size", 14)
	hpbox.add_child(_block_label)
	vb.add_child(hpbox)

	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	vb.add_child(_status_label)


func refresh() -> void:
	if not is_instance_valid(enemy):
		return
	_name_label.text = enemy.data.display_name
	_hp_label.text = "HP %d/%d" % [enemy.hp, enemy.max_hp]
	_block_label.text = ("BLK %d" % enemy.block) if enemy.block > 0 else ""
	_intent_label.text = _intent_text()
	_status_label.text = _status_text()
	modulate = Color(0.35, 0.35, 0.35) if enemy.is_dead() else Color.WHITE


func _intent_text() -> String:
	if enemy.next_move == null:
		return "..."
	var m := enemy.next_move
	match m.intent:
		EnemyMove.Intent.ATTACK:
			if m.multi_hits > 1:
				return "Atk %d x %d" % [m.damage, m.multi_hits]
			return "Atk %d" % m.damage
		EnemyMove.Intent.DEFEND:
			return "Def %d" % m.block
		EnemyMove.Intent.ATTACK_DEFEND:
			return "Atk %d / Def %d" % [m.damage, m.block]
		EnemyMove.Intent.DEBUFF:
			return "Debuff: %s" % str(m.status_to_apply)
		EnemyMove.Intent.BUFF:
			return "Buff: %s" % str(m.status_to_apply)
		_:
			return "???"


func _status_text() -> String:
	if enemy.status_holder == null or enemy.status_holder.stacks.is_empty():
		return ""
	var parts: Array[String] = []
	for id in enemy.status_holder.stacks.keys():
		parts.append("%s:%d" % [str(id), enemy.status_holder.stacks[id]])
	return ", ".join(parts)
