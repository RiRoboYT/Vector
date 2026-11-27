class_name BowlingBall
extends RigidBody3D
## 7 kg ball. Hook comes from `spin` (-1..1): a sideways push that grows on
## the dry back end of the lane, like a real ball biting after the oil.

const RADIUS := 0.109
const HOOK_ACCEL := 0.75 # m/s^2 at full spin on the dry part

var spin := 0.0
var rolling := false


func _init() -> void:
	mass = 7.0
	continuous_cd = true
	can_sleep = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.012 # a real ball loses only ~10% speed down the lane
	angular_damp = 0.0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.2
	pm.bounce = 0.05
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = RADIUS
	cs.shape = sp
	add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2
	sm.radial_segments = 48
	sm.rings = 24
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _swirl_texture()
	m.roughness = 0.12
	m.metallic_specular = 0.9
	m.clearcoat_enabled = true
	mi.material_override = m
	add_child(mi)
	# finger holes
	for off in [Vector3(-0.022, 0.1, -0.03), Vector3(0.022, 0.1, -0.03), Vector3(0, 0.1, 0.04)]:
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.012
		hm.bottom_radius = 0.012
		hm.height = 0.02
		h.mesh = hm
		h.material_override = BowlingLane._mat(Color("101420"), 0.8)
		h.position = off
		add_child(h)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC


func hold(at: Vector3) -> void:
	freeze = true
	rolling = false
	spin = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = at


func launch(from: Vector3, velocity: Vector3) -> void:
	global_position = from
	freeze = false
	linear_velocity = velocity
	# start rolling (no skid) so the line is predictable
	angular_velocity = Vector3.UP.cross(velocity) / RADIUS
	rolling = true


func _physics_process(_delta: float) -> void:
	if freeze or not rolling:
		return
	var p := global_position
	var on_lane := absf(p.x) < BowlingLane.LANE_HALF and p.y > RADIUS * 0.5 and p.z < -1.0 and p.z > -BowlingLane.LANE_LEN + 0.3
	if on_lane and absf(spin) > 0.01:
		# oil on the first ~10 m: little hook; dry back end: full hook
		var dry := clampf((-p.z - 8.0) / 6.0, 0.0, 1.0)
		var push := spin * HOOK_ACCEL * (0.15 + 0.85 * dry)
		apply_central_force(Vector3(push * mass, 0, 0))


func _swirl_texture() -> ImageTexture:
	var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 128:
			var u := x / 128.0 * TAU
			var v := y / 64.0 * PI
			var swirl := sin(u * 3.0 + sin(v * 4.0) * 2.0 + cos(u) * 1.5)
			var c := Color("1f6fd6").lerp(Color("57c3f2"), 0.5 + 0.5 * swirl)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
