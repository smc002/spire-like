class_name ScreenShake extends RefCounted

# Static helper. Shakes a Control by tweening its position briefly.
# Use a wrapper Control around content that can absorb the offset.


static func shake(target: Control, magnitude: float = 6.0, duration: float = 0.22) -> void:
	if not is_instance_valid(target):
		return
	var original := target.position
	var steps: int = 6
	var step_time: float = duration / float(steps)
	# Kill previous shake on this node by tagging via metadata
	target.set_meta(&"_shake_origin", original)
	var t := target.create_tween()
	for i in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var off := Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * magnitude * falloff
		t.tween_property(target, "position", original + off, step_time)
	t.tween_property(target, "position", original, step_time)
