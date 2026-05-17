class_name ParticleBurst extends RefCounted

# Static helpers for CPU particle bursts. No texture needed — CPUParticles2D
# defaults to small white squares which we color via the `color` property.


static func spawn_hit(parent: Node, pos: Vector2) -> void:
	var p := _make(parent, pos)
	p.amount = 18
	p.lifetime = 0.45
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 180.0
	p.gravity = Vector2(0, 240)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.45, 0.30)
	p.emitting = true
	_auto_free(p)


static func spawn_block(parent: Node, pos: Vector2) -> void:
	var p := _make(parent, pos)
	p.amount = 10
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color(0.55, 0.85, 1.0)
	p.emitting = true
	_auto_free(p)


static func spawn_death(parent: Node, pos: Vector2) -> void:
	var p := _make(parent, pos)
	p.amount = 30
	p.lifetime = 0.85
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 200.0
	p.gravity = Vector2(0, -60)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(0.55, 0.55, 0.55, 0.85)
	p.emitting = true
	_auto_free(p)


static func spawn_buff(parent: Node, pos: Vector2) -> void:
	var p := _make(parent, pos)
	p.amount = 14
	p.lifetime = 0.6
	p.spread = 30.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.5
	p.scale_amount_max = 4.0
	p.color = Color(0.65, 1.0, 0.65)
	p.emitting = true
	_auto_free(p)


static func _make(parent: Node, pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.z_index = 250
	parent.add_child(p)
	return p


static func _auto_free(p: CPUParticles2D) -> void:
	var lifetime: float = p.lifetime + 0.1
	var timer := p.get_tree().create_timer(lifetime)
	timer.timeout.connect(p.queue_free)
