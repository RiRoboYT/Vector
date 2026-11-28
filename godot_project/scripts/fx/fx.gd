class_name Fx
extends RefCounted
## Small one-shot 3D effects and slow motion for big moments.

static var _mats := {}


## Soft puff of dust / chalk where a ball lands.
static func puff(parent: Node, pos: Vector3, col: Color, amount := 14, size := 0.12, speed := 1.2) -> void:
	if Look.get_quality() == Look.LOW and amount > 6:
		amount = 6
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -2.0, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	p.mesh = q
	p.material_override = _soft(col)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Bright little sparks (impacts).
static func sparks(parent: Node, pos: Vector3, col := Color(1, 0.95, 0.7), amount := 16) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -6, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.material_override = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.8).timeout.connect(p.queue_free)


static func _soft(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if _mats.has(key):
		return _mats[key]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = col
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	_mats[key] = m
	return m


static var _slow_token := 0


## Slow the whole game down for a dramatic moment (real seconds).
static func slowmo(tree: SceneTree, scale := 0.35, seconds := 0.8) -> void:
	if OS.get_cmdline_user_args().has("--no-slowmo"):
		return
	_slow_token += 1
	var token := _slow_token
	Engine.time_scale = scale
	tree.create_timer(seconds, true, false, true).timeout.connect(func():
		if token == _slow_token:
			Engine.time_scale = 1.0)
