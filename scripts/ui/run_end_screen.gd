extends Control

# End-of-run summary. Shows stats tracked by RunState and offers
# "Run Again" / "Main Menu".


var _bg: ColorRect
var _title_label: Label
var _stats_label: Label
var _deck_grid: GridContainer


func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(1280, 720)
	_build()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.05, 0.10)
	_bg.anchor_right = 1
	_bg.anchor_bottom = 1
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_title_label = Label.new()
	_title_label.position = Vector2(0, 40)
	_title_label.size = Vector2(1280, 60)
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "Run Complete" if RunState.hp > 0 else "Run Failed"
	_title_label.add_theme_color_override("font_color",
		Color(0.7, 1.0, 0.7) if RunState.hp > 0 else Color(1.0, 0.5, 0.5))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.position = Vector2(360, 130)
	_stats_label.size = Vector2(560, 160)
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.text = _stats_text()
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_label)

	# Deck composition title
	var deck_label := Label.new()
	deck_label.position = Vector2(0, 300)
	deck_label.size = Vector2(1280, 26)
	deck_label.text = "Final Deck (%d cards)" % RunState.deck.size()
	deck_label.add_theme_font_size_override("font_size", 18)
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deck_label)

	_deck_grid = GridContainer.new()
	_deck_grid.columns = 7
	_deck_grid.position = Vector2(90, 340)
	_deck_grid.size = Vector2(1100, 260)
	_deck_grid.add_theme_constant_override("h_separation", 12)
	_deck_grid.add_theme_constant_override("v_separation", 12)
	_deck_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_deck_grid)
	for card in RunState.deck:
		var mini := _mini_card(card)
		_deck_grid.add_child(mini)

	var run_again := Button.new()
	run_again.text = "Run Again"
	run_again.position = Vector2(420, 640)
	run_again.size = Vector2(180, 50)
	run_again.add_theme_font_size_override("font_size", 18)
	run_again.pressed.connect(_on_run_again)
	add_child(run_again)

	var to_menu := Button.new()
	to_menu.text = "Main Menu"
	to_menu.position = Vector2(680, 640)
	to_menu.size = Vector2(180, 50)
	to_menu.add_theme_font_size_override("font_size", 18)
	to_menu.pressed.connect(_on_main_menu)
	add_child(to_menu)


func _stats_text() -> String:
	var rs := RunState
	return "Floor reached:     %d
Battles won:       %d
Turns played:      %d
Damage dealt:      %d
Damage taken:      %d
Gold:              %d
HP:                %d / %d" % [
		rs.current_floor, rs.battles_won, rs.turns_played,
		rs.total_damage_dealt, rs.total_damage_taken,
		rs.gold, rs.hp, rs.max_hp]


func _mini_card(card: Card) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(130, 100)
	p.size = Vector2(130, 100)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.bg_color = _bg_for_type(card.type)
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
	name_l.size = Vector2(94, 22)
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(name_l)

	var desc := Label.new()
	desc.text = card.description
	desc.position = Vector2(6, 30)
	desc.size = Vector2(118, 66)
	desc.add_theme_font_size_override("font_size", 10)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(desc)
	return p


func _bg_for_type(t: int) -> Color:
	match t:
		Card.Type.ATTACK: return Color(0.55, 0.18, 0.18)
		Card.Type.SKILL: return Color(0.17, 0.32, 0.48)
		Card.Type.POWER: return Color(0.42, 0.22, 0.50)
		Card.Type.CURSE: return Color(0.18, 0.10, 0.18)
		_: return Color(0.30, 0.30, 0.30)


func _on_run_again() -> void:
	SFX.play(&"ui_click")
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")


func _on_main_menu() -> void:
	SFX.play(&"ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
