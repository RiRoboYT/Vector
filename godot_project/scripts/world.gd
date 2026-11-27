class_name World
extends Node3D
## Bright, soft, sporty environment + pointer target board + motion trail.

const BOARD_Z := -7.0
const TRAIL_LEN := 28

var character: Character
var camera: Camera3D
var _reticle: Node3D
var _reticle_mat: StandardMaterial3D
var _trail: MeshInstance3D
var _trail_mesh := ImmediateMesh.new()
var _trail_pts: Array[Vector3] = []
var _trail_dirs: Array[Vector3] = []


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_board()
	character = Character.new()
	add_child(character)

	camera = Camera3D.new()
	camera.fov = 52.0
	add_child(camera)
	camera.look_at_from_position(Vector3(1.25, 2.1, 3.1), Vector3(-0.35, 1.55, -5.0))
	camera.current = true

	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.vertex_color_use_as_albedo = true
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = tm
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


func _process(_delta: float) -> void:
	if character == null:
		return
	# pointer ray from the remote tip to the board
	var o := character.tip_world
	var d := character.tip_forward
	if d.z < -0.05:
		var t := (BOARD_Z + 0.06 - o.z) / d.z
		var hit := o + d * t
		_reticle.visible = true
		_reticle.position = Vector3(clampf(hit.x, -6.5, 6.5), clampf(hit.y, 0.2, 5.6), BOARD_Z + 0.06)
	else:
		_reticle.visible = false
	_reticle_mat.emission_energy_multiplier = 1.2 + character.swing * 3.0
	_reticle.scale = Vector3.ONE * (1.0 + character.swing * 0.5)
	_update_trail()


func _update_trail() -> void:
	_trail_pts.push_front(character.tip_world)
	_trail_dirs.push_front(character.tip_forward)
	while _trail_pts.size() > TRAIL_LEN:
		_trail_pts.pop_back()
		_trail_dirs.pop_back()
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	var cam_pos := camera.global_position
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail_pts.size():
		var p := _trail_pts[i]
		var seg := (_trail_pts[maxi(i - 1, 0)] - _trail_pts[mini(i + 1, _trail_pts.size() - 1)])
		var side := seg.cross(cam_pos - p).normalized() if seg.length() > 0.0001 else Vector3.UP
		var k := 1.0 - float(i) / float(TRAIL_LEN)
		var w := 0.03 * k * (0.4 + character.swing * 1.6)
		var col := Color(0.45, 0.85, 1.0, k * (0.25 + character.swing * 0.6))
		_trail_mesh.surface_set_color(col)
		_trail_mesh.surface_add_vertex(p + side * w)
		_trail_mesh.surface_set_color(col)
		_trail_mesh.surface_add_vertex(p - side * w)
	_trail_mesh.surface_end()


func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.62, 0.98)
	sky_mat.sky_horizon_color = Color(0.72, 0.86, 0.98)
	sky_mat.ground_horizon_color = Color(0.78, 0.9, 1.0)
	sky_mat.ground_bottom_color = Color(0.45, 0.7, 0.4)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.tonemap_white = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.2
	env.fog_enabled = false
	env.fog_light_color = Color(0.8, 0.9, 1.0)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 25.0
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(28), 0)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	ground.material_override = Character.material(Color(0.47, 0.78, 0.36), 0.95)
	add_child(ground)

	var pad := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.04
	cm.radial_segments = 64
	pad.mesh = cm
	pad.material_override = Character.material(Color(0.96, 0.96, 0.92), 0.8)
	pad.position = Vector3(0, 0.02, 0)
	add_child(pad)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.08
	tm.outer_radius = 1.16
	tm.rings = 64
	ring.mesh = tm
	ring.material_override = Character.material(Color(0.2, 0.55, 1.0), 0.6)
	ring.position = Vector3(0, 0.035, 0)
	ring.scale = Vector3(1, 0.3, 1)
	add_child(ring)

	# rolling hills + round trees in the distance
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := rng.randf_range(6.0, 11.0)
		sm.radius = r
		sm.height = r * 2.0
		hill.mesh = sm
		hill.material_override = Character.material(Color(0.4, 0.72, 0.34).lightened(rng.randf_range(0.0, 0.15)), 1.0)
		hill.position = Vector3(rng.randf_range(-40, 40), -r * 0.6, rng.randf_range(-45, -22))
		add_child(hill)
	for i in 16:
		var x := rng.randf_range(-22, 22)
		if absf(x) < 8.0:
			x += signf(x if x != 0.0 else 1.0) * 8.0
		var z := rng.randf_range(-20, 4)
		var s := rng.randf_range(0.8, 1.4)
		var trunk := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.12 * s
		tc.bottom_radius = 0.16 * s
		tc.height = 1.2 * s
		trunk.mesh = tc
		trunk.material_override = Character.material(Color(0.55, 0.38, 0.24))
		trunk.position = Vector3(x, 0.6 * s, z)
		add_child(trunk)
		var crown := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.85 * s
		cs.height = 1.7 * s
		crown.mesh = cs
		crown.material_override = Character.material(Color(0.28, 0.66, 0.3).lightened(rng.randf_range(0.0, 0.2)))
		crown.position = Vector3(x, 1.75 * s, z)
		add_child(crown)


func _build_board() -> void:
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(14, 6.2, 0.1)
	board.mesh = bm
	board.material_override = Character.material(Color(0.93, 0.95, 0.99), 0.7)
	board.position = Vector3(0, 3.0, BOARD_Z)
	add_child(board)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(14.4, 6.6, 0.06)
	frame.mesh = fm
	frame.material_override = Character.material(Color(0.2, 0.55, 1.0), 0.5)
	frame.position = Vector3(0, 3.0, BOARD_Z - 0.06)
	add_child(frame)
	# concentric target rings
	var colors := [Color(1.0, 0.36, 0.36), Color(1, 1, 1), Color(1.0, 0.36, 0.36), Color(1, 1, 1), Color(1.0, 0.82, 0.2)]
	for i in colors.size():
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := 1.6 - i * 0.32
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.02
		cm.radial_segments = 64
		disc.mesh = cm
		disc.material_override = Character.material(colors[i], 0.6)
		disc.rotation = Vector3(deg_to_rad(90), 0, 0)
		disc.position = Vector3(0, 2.6, BOARD_Z + 0.06 + i * 0.004)
		add_child(disc)

	_reticle = Node3D.new()
	add_child(_reticle)
	var dot := MeshInstance3D.new()
	var ds := SphereMesh.new()
	ds.radius = 0.16
	ds.height = 0.06
	dot.mesh = ds
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.albedo_color = Color(0.3, 0.8, 1.0)
	_reticle_mat.emission_enabled = true
	_reticle_mat.emission = Color(0.25, 0.75, 1.0)
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material_override = _reticle_mat
	dot.rotation = Vector3(deg_to_rad(90), 0, 0)
	dot.position = Vector3(0, 0, 0.04)
	_reticle.add_child(dot)
	var halo := MeshInstance3D.new()
	var ht := TorusMesh.new()
	ht.inner_radius = 0.24
	ht.outer_radius = 0.3
	halo.mesh = ht
	halo.material_override = _reticle_mat
	halo.rotation = Vector3(deg_to_rad(90), 0, 0)
	halo.position = Vector3(0, 0, 0.04)
	_reticle.add_child(halo)
