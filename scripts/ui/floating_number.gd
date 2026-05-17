class_name FloatingNumber extends Label

# Damage / block / status floater. Spawn one with .spawn() and forget;
# it tweens upward and fades, then frees itself.


const DURATION: float = 0.7
const RISE: float = -55.0
const FADE_START_AT: float = 0.30


# Spawn a floater under `parent`, centered horizontally at `pos`, drifting up.
static func spawn(parent: Node, text: String, color: Color, pos: Vector2) -> void:
	var fn := FloatingNumber.new()
	fn.text = text
	fn.add_theme_color_override("font_color", color)
	fn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	fn.add_theme_constant_override("outline_size", 4)
	fn.add_theme_font_size_override("font_size", 26)
	fn.size = Vector2(120, 32)
	fn.position = pos - Vector2(60, 16)
	fn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fn.z_index = 300
	parent.add_child(fn)
	var t := fn.create_tween().set_parallel(true)
	t.tween_property(fn, "position:y", fn.position.y + RISE, DURATION).set_trans(Tween.TRANS_QUAD)
	t.tween_property(fn, "modulate:a", 0.0, DURATION - FADE_START_AT).set_delay(FADE_START_AT)
	t.chain().tween_callback(fn.queue_free)
