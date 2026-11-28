class_name BowlingPin
extends RigidBody3D
## Regulation-size pin (15 in tall, 1.5 kg) with a lathe-turned mesh, red neck
## stripes and a two-part convex collision (body + head) so it tips, wobbles
## and topples realistically. Origin is at the base.

const HEIGHT := 0.381
const MASS := 1.53
const COM_HEIGHT := 0.145

# (height, radius) profile in metres
const PROFILE := [
	Vector2(0.000, 0.026), Vector2(0.012, 0.036), Vector2(0.040, 0.050), Vector2(0.080, 0.058),
	Vector2(0.114, 0.0605), Vector2(0.150, 0.058), Vector2(0.190, 0.048), Vector2(0.225, 0.034),
	Vector2(0.254, 0.0228), Vector2(0.285, 0.025), Vector2(0.320, 0.031), Vector2(0.340, 0.0322),
	Vector2(0.358, 0.029), Vector2(0.372, 0.020), Vector2(0.381, 0.0),
]

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D

var spot := Vector3.ZERO
var number := 1
var _last_sound_ms := 0


static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build_mesh(28)
	return _mesh


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.18
		_mat.metallic_specular = 0.8
		_mat.clearcoat_enabled = true
		_mat.clearcoat = 0.6
	return _mat


func _init(p_number := 1, p_spot := Vector3.ZERO) -> void:
	number = p_number
	spot = p_spot
	mass = MASS
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, COM_HEIGHT, 0)
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 4
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	pm.bounce = 0.4
	physics_material_override = pm
	linear_damp = 0.05
	angular_damp = 0.1

	var mi := MeshInstance3D.new()
	mi.mesh = mesh()
	mi.material_override = material()
	add_child(mi)
	var body := CollisionShape3D.new()
	body.shape = _hull(0.0, 0.235)
	add_child(body)
	var head := CollisionShape3D.new()
	head.shape = _hull(0.235, HEIGHT)
	add_child(head)
	body_entered.connect(_on_hit)


func reset_to_spot() -> void:
	freeze = false
	visible = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis.IDENTITY, spot + Vector3(0, 0.002, 0))
	process_mode = Node.PROCESS_MODE_INHERIT
	sleeping = true


func remove() -> void:
	visible = false
	freeze = true
	global_position = Vector3(0, -10, -30 - number)
	process_mode = Node.PROCESS_MODE_DISABLED


func is_standing() -> bool:
	if not visible:
		return false
	var p := global_position
	var up := global_basis.y.normalized()
	return up.y > 0.86 and p.y > -0.05 and absf(p.x) < BowlingLane.LANE_HALF + 0.05 and p.z < -17.5 and p.z > -BowlingLane.DECK_END


func _on_hit(other: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sound_ms < 70:
		return
	_last_sound_ms = now
	var rel := linear_velocity
	if other is RigidBody3D:
		rel -= (other as RigidBody3D).linear_velocity
	var strength := clampf(rel.length() / 6.0, 0.0, 1.0)
	if other is BowlingBall:
		strength = clampf(strength * 1.6 + 0.3, 0.0, 1.0)
		if strength > 0.6:
			Fx.sparks(get_parent(), global_position + Vector3(0, 0.15, 0), Color(1, 0.97, 0.85), 12)
	Sfx.pin_hit(strength)


static func _hull(h0: float, h1: float) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	var seg := 12
	for p in _sampled(h0, h1):
		for i in seg:
			var a := TAU * i / seg
			if p.y < 0.001:
				pts.append(Vector3(0, p.x, 0))
				break
			pts.append(Vector3(cos(a) * p.y, p.x, sin(a) * p.y))
	var s := ConvexPolygonShape3D.new()
	s.points = pts
	return s


static func _radius_at(h: float) -> float:
	for i in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		if h >= a.x and h <= b.x:
			return lerpf(a.y, b.y, (h - a.x) / maxf(b.x - a.x, 0.0001))
	return 0.0


static func _sampled(h0: float, h1: float) -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(h0, _radius_at(h0))]
	for p in PROFILE:
		if p.x > h0 and p.x < h1:
			out.append(p)
	out.append(Vector2(h1, _radius_at(h1)))
	return out


static func _build_mesh(seg: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# densify the profile so stripes are crisp
	var prof: Array[Vector2] = []
	for i in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		for k in 4:
			prof.append(a.lerp(b, k / 4.0))
	prof.append(PROFILE[PROFILE.size() - 1])
	for i in prof.size() - 1:
		var a := prof[i]
		var b := prof[i + 1]
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var v := [
				Vector3(cos(a0) * a.y, a.x, sin(a0) * a.y), Vector3(cos(a1) * a.y, a.x, sin(a1) * a.y),
				Vector3(cos(a1) * b.y, b.x, sin(a1) * b.y), Vector3(cos(a0) * b.y, b.x, sin(a0) * b.y),
			]
			var hm := (a.x + b.x) * 0.5
			var col := Color("d8262c") if (hm > 0.246 and hm < 0.262) or (hm > 0.272 and hm < 0.282) else Color("fbfbf8")
			st.set_color(col)
			for idx in [0, 2, 1, 0, 3, 2]:
				st.add_vertex(v[idx])
	st.generate_normals()
	return st.commit()
