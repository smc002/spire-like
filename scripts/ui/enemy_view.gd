class_name EnemyView extends Panel

# Enemy visual. Panel (not PanelContainer) for predictable sizing.
# Renders name / intent / HP / block / statuses with absolute positioning.
# Damage preview shown while the player drags an attack card over this enemy.


const VIEW_W: int = 200
const VIEW_H: int = 260

var enemy: Enemy

var _name_label: Label
var _intent_label: Label
var _sprite_box: Panel
var _sprite_label: Label
var _hp_label: Label
var _block_label: Label
var _status_label: Label
var _preview_label: Label
var _style: StyleBoxFlat


func setup(p_enemy: Enemy) -> void:
	enemy = p_enemy
	custom_minimum_size = Vector2(VIEW_W, VIEW_H)
	size = Vector2(VIEW_W, VIEW_H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	refresh()


func _build() -> void:
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(8)
	_style.bg_color = Color(0.28, 0.20, 0.20)
	_style.set_border_width_all(2)
	_style.border_color = Color(0.55, 0.40, 0.25)
	add_theme_stylebox_override("panel", _style)

	_name_label = Label.new()
	_name_label.position = Vector2(8, 8)
	_name_label.size = Vector2(VIEW_W - 16, 22)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	add_child(_name_label)

	_intent_label = Label.new()
	_intent_label.position = Vector2(8, 32)
	_intent_label.size = Vector2(VIEW_W - 16, 26)
	_intent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.add_theme_font_size_override("font_size", 18)
	_intent_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	add_child(_intent_label)

	_sprite_box = Panel.new()
	_sprite_box.position = Vector2(20, 65)
	_sprite_box.size = Vector2(VIEW_W - 40, 100)
	_sprite_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color(0.20, 0.14, 0.14)
	sbs.set_corner_radius_all(4)
	_sprite_box.add_theme_stylebox_override("panel", sbs)
	add_child(_sprite_box)

	_sprite_label = Label.new()
	_sprite_label.position = Vector2(0, 0)
	_sprite_label.size = _sprite_box.size
	_sprite_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sprite_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sprite_label.text = "(sprite)"
	_sprite_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	_sprite_box.add_child(_sprite_label)

	# Damage preview overlay (centered over sprite, red)
	_preview_label = Label.new()
	_preview_label.position = Vector2(0, 90)
	_preview_label.size = Vector2(VIEW_W, 50)
	_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_label.add_theme_font_size_override("font_size", 36)
	_preview_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
	_preview_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_preview_label.add_theme_constant_override("outline_size", 4)
	_preview_label.visible = false
	add_child(_preview_label)

	_hp_label = Label.new()
	_hp_label.position = Vector2(8, 180)
	_hp_label.size = Vector2(VIEW_W - 64, 22)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.add_theme_font_size_override("font_size", 14)
	add_child(_hp_label)

	_block_label = Label.new()
	_block_label.position = Vector2(VIEW_W - 60, 180)
	_block_label.size = Vector2(52, 22)
	_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_block_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_block_label.add_theme_font_size_override("font_size", 14)
	add_child(_block_label)

	_status_label = Label.new()
	_status_label.position = Vector2(8, 206)
	_status_label.size = Vector2(VIEW_W - 16, 46)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)


func refresh() -> void:
	if not is_instance_valid(enemy):
		return
	_name_label.text = enemy.data.display_name
	_hp_label.text = "HP %d/%d" % [enemy.hp, enemy.max_hp]
	_block_label.text = ("BLK %d" % enemy.block) if enemy.block > 0 else ""
	_intent_label.text = _intent_text()
	_status_label.text = _status_text()
	modulate = Color(0.35, 0.35, 0.35) if enemy.is_dead() else Color.WHITE


# ─────────────────────────────────────────────────────────────────────
# Damage preview (called by BattleScene while a card is being dragged)
# ─────────────────────────────────────────────────────────────────────

func show_damage_preview(predicted: int) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead():
		clear_damage_preview()
		return
	var actual_loss: int = max(0, predicted - enemy.block)
	_preview_label.text = "-%d" % actual_loss
	_preview_label.visible = true
	_style.border_color = Color(1.0, 0.3, 0.3)


func clear_damage_preview() -> void:
	_preview_label.visible = false
	_style.border_color = Color(0.55, 0.40, 0.25)


# ─────────────────────────────────────────────────────────────────────
# Text helpers
# ─────────────────────────────────────────────────────────────────────

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
