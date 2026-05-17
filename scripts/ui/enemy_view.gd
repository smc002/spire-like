class_name EnemyView extends Panel

# Enemy visual: name + colored intent chip + sprite placeholder + HP bar
# + block badge + status chip row. Plus damage-preview overlay during drag,
# and a hit-flash on damage_dealt.


const VIEW_W: int = 200
const VIEW_H: int = 270

var enemy: Enemy

var _name_label: Label
var _intent_panel: Panel
var _intent_label: Label
var _intent_style: StyleBoxFlat
var _sprite_box: Panel
var _sprite_label: Label
var _hp_bar: HPBar
var _block_label: Label
var _status_row: HBoxContainer
var _preview_label: Label
var _style: StyleBoxFlat
var _flash_tween: Tween


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

	# Colored intent chip
	_intent_panel = Panel.new()
	_intent_panel.position = Vector2(20, 32)
	_intent_panel.size = Vector2(VIEW_W - 40, 28)
	_intent_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_intent_style = StyleBoxFlat.new()
	_intent_style.set_corner_radius_all(4)
	_intent_style.bg_color = Color(0.30, 0.25, 0.15)
	_intent_style.set_border_width_all(1)
	_intent_style.border_color = Color(0.7, 0.6, 0.3)
	_intent_panel.add_theme_stylebox_override("panel", _intent_style)
	add_child(_intent_panel)

	_intent_label = Label.new()
	_intent_label.position = Vector2(0, 0)
	_intent_label.size = _intent_panel.size
	_intent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intent_label.add_theme_font_size_override("font_size", 15)
	_intent_panel.add_child(_intent_label)

	_sprite_box = Panel.new()
	_sprite_box.position = Vector2(30, 68)
	_sprite_box.size = Vector2(VIEW_W - 60, 90)
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

	# Damage preview overlay
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

	# HP bar with block badge to the right
	_hp_bar = HPBar.new()
	_hp_bar.position = Vector2(8, 168)
	_hp_bar.setup(VIEW_W - 64)
	add_child(_hp_bar)

	_block_label = Label.new()
	_block_label.position = Vector2(VIEW_W - 52, 168)
	_block_label.size = Vector2(44, 22)
	_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_block_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_block_label.add_theme_font_size_override("font_size", 14)
	add_child(_block_label)

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(8, 200)
	_status_row.size = Vector2(VIEW_W - 16, 28)
	_status_row.add_theme_constant_override("separation", 4)
	_status_row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_status_row)


func refresh() -> void:
	if not is_instance_valid(enemy):
		return
	_name_label.text = enemy.data.display_name
	_hp_bar.set_hp(enemy.hp, enemy.max_hp)
	_block_label.text = ("BLK %d" % enemy.block) if enemy.block > 0 else ""
	_intent_label.text = _intent_text()
	_intent_style.bg_color = _intent_bg_color()
	_intent_style.border_color = _intent_border_color()
	_rebuild_status_row()
	modulate = Color(0.35, 0.35, 0.35) if enemy.is_dead() else Color.WHITE


# ─────────────────────────────────────────────────────────────────────
# Damage preview (driven by BattleScene during drag)
# ─────────────────────────────────────────────────────────────────────

func show_damage_preview(predicted: int) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead():
		clear_damage_preview()
		return
	var loss: int = max(0, predicted - enemy.block)
	_preview_label.text = "-%d" % loss
	_preview_label.visible = true
	_style.border_color = Color(1.0, 0.3, 0.3)


func clear_damage_preview() -> void:
	_preview_label.visible = false
	_style.border_color = Color(0.55, 0.40, 0.25)


# ─────────────────────────────────────────────────────────────────────
# Hit flash
# ─────────────────────────────────────────────────────────────────────

func flash_hit() -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate = Color(1.6, 0.45, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.30).set_trans(Tween.TRANS_QUAD)


# ─────────────────────────────────────────────────────────────────────
# Helpers
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


func _intent_bg_color() -> Color:
	if enemy.next_move == null:
		return Color(0.30, 0.25, 0.15)
	match enemy.next_move.intent:
		EnemyMove.Intent.ATTACK: return Color(0.50, 0.15, 0.15)
		EnemyMove.Intent.DEFEND: return Color(0.15, 0.30, 0.50)
		EnemyMove.Intent.ATTACK_DEFEND: return Color(0.45, 0.25, 0.30)
		EnemyMove.Intent.DEBUFF: return Color(0.45, 0.20, 0.45)
		EnemyMove.Intent.BUFF: return Color(0.20, 0.40, 0.25)
		_: return Color(0.30, 0.25, 0.15)


func _intent_border_color() -> Color:
	if enemy.next_move == null:
		return Color(0.7, 0.6, 0.3)
	match enemy.next_move.intent:
		EnemyMove.Intent.ATTACK: return Color(0.95, 0.40, 0.40)
		EnemyMove.Intent.DEFEND: return Color(0.50, 0.75, 1.0)
		EnemyMove.Intent.ATTACK_DEFEND: return Color(0.85, 0.55, 0.55)
		EnemyMove.Intent.DEBUFF: return Color(0.85, 0.55, 0.95)
		EnemyMove.Intent.BUFF: return Color(0.55, 0.95, 0.65)
		_: return Color(0.7, 0.6, 0.3)


func _rebuild_status_row() -> void:
	for c in _status_row.get_children():
		c.queue_free()
	if enemy.status_holder == null:
		return
	for id in enemy.status_holder.stacks.keys():
		var chip := StatusChip.new()
		_status_row.add_child(chip)
		chip.setup(id, enemy.status_holder.stacks[id])
