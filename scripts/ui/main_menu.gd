extends Control

# Simple main menu: title + Start / Settings / Quit.


var _bg: ColorRect
var _vignette: TextureRect
var _settings_panel: Panel
var _settings_visible: bool = false


func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(1280, 720)
	_build()
	SFX.play_bgm(&"menu")


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.05, 0.10)
	_bg.anchor_right = 1
	_bg.anchor_bottom = 1
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_vignette = _make_vignette()
	add_child(_vignette)

	var title := Label.new()
	title.text = "Spire-like"
	title.position = Vector2(0, 140)
	title.size = Vector2(1280, 80)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.50))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A deckbuilder roguelike study project"
	subtitle.position = Vector2(0, 220)
	subtitle.size = Vector2(1280, 30)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.70, 0.80))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)

	_add_button("Start New Run", Vector2(540, 320), _on_start_pressed)
	_add_button("Settings", Vector2(540, 390), _on_settings_pressed)
	_add_button("Quit", Vector2(540, 460), _on_quit_pressed)

	var hint := Label.new()
	hint.text = "Drag a card up onto an enemy to play it."
	hint.position = Vector2(0, 660)
	hint.size = Vector2(1280, 30)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	_build_settings_panel()


func _add_button(text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 50)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	add_child(b)


func _make_vignette() -> TextureRect:
	var tr := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.55))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 1280
	gt.height = 720
	tr.texture = gt
	tr.size = Vector2(1280, 720)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _build_settings_panel() -> void:
	_settings_panel = Panel.new()
	_settings_panel.position = Vector2(440, 240)
	_settings_panel.size = Vector2(400, 240)
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.10, 0.18, 0.97)
	st.set_corner_radius_all(10)
	st.set_border_width_all(2)
	st.border_color = Color(0.55, 0.55, 0.7)
	_settings_panel.add_theme_stylebox_override("panel", st)

	var title := Label.new()
	title.text = "Settings"
	title.position = Vector2(0, 16)
	title.size = Vector2(400, 30)
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_panel.add_child(title)

	var vol_label := Label.new()
	vol_label.text = "Master Volume"
	vol_label.position = Vector2(40, 70)
	vol_label.size = Vector2(320, 22)
	_settings_panel.add_child(vol_label)

	var slider := HSlider.new()
	slider.position = Vector2(40, 100)
	slider.size = Vector2(320, 24)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = SFX.get_master_volume()
	slider.value_changed.connect(func(v): SFX.set_master_volume(v))
	_settings_panel.add_child(slider)

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(150, 180)
	close.size = Vector2(100, 36)
	close.pressed.connect(_on_settings_close)
	_settings_panel.add_child(close)

	_settings_panel.visible = false
	add_child(_settings_panel)


func _on_start_pressed() -> void:
	SFX.play(&"ui_click")
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")


func _on_settings_pressed() -> void:
	SFX.play(&"ui_click")
	_settings_panel.visible = true


func _on_settings_close() -> void:
	SFX.play(&"ui_click")
	_settings_panel.visible = false


func _on_quit_pressed() -> void:
	SFX.play(&"ui_click")
	get_tree().quit()
