class_name Character
extends Node3D
## A simple, original low-poly "bean" character built from primitives.
## The right arm is driven by two-bone IK toward a target computed from the
## controller's yaw/pitch; the remote in the hand follows the full rotation.

const UPPER := 0.30
const FORE := 0.29
const SKIN := Color(1.0, 0.84, 0.7)
const SHIRT := Color(0.16, 0.62, 0.9)
const PANTS := Color(0.22, 0.25, 0.36)

var aim_yaw := 0.0
var aim_pitch := 0.0
var aim_roll := 0.0
var swing := 0.0

## Bowling mode: arm swings in the vertical plane, no remote, no head follow.
var bowling := false
var swing_angle := 0.0 # radians: 0 = arm hanging, >0 forward, <0 back
var hand_world := Vector3.ZERO

var tip_world := Vector3.ZERO
var tip_forward := Vector3.FORWARD

var _shoulder_r := Vector3(0.27, 1.38, 0.0)
var _shoulder_l := Vector3(-0.27, 1.38, 0.0)
var _upper_r: MeshInstance3D
var _fore_r: MeshInstance3D
var _elbow_r: MeshInstance3D
var _hand_r: Node3D
var _remote: Node3D
var _tip_mat: StandardMaterial3D
var _head: Node3D
var _body: Node3D
var _time := 0.0
var _face: Array[Node3D] = []


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	# legs
	for side in [-1.0, 1.0]:
		var leg := _mesh(_capsule(0.085, 0.62), PANTS)
		leg.position = Vector3(0.11 * side, 0.36, 0.0)
		_body.add_child(leg)
		var shoe := _mesh(_sphere(0.1), Color(0.95, 0.95, 0.97))
		shoe.scale = Vector3(1.0, 0.55, 1.45)
		shoe.position = Vector3(0.11 * side, 0.06, -0.04)
		_body.add_child(shoe)
	# torso: slim, sporty polo
	var torso := _mesh(_capsule(0.215, 0.74), SHIRT)
	torso.scale = Vector3(1.08, 1.0, 0.82)
	torso.position = Vector3(0, 1.08, 0)
	_body.add_child(torso)
	var collar := _mesh(_torus(0.07, 0.1), Color(0.96, 0.97, 1.0))
	collar.position = Vector3(0, 1.43, 0)
	collar.scale = Vector3(1.0, 0.6, 0.9)
	_body.add_child(collar)
	var belt := _mesh(_cylinder(0.215, 0.05), Color(0.12, 0.14, 0.2))
	belt.scale = Vector3(1.08, 1.0, 0.82)
	belt.position = Vector3(0, 0.79, 0)
	_body.add_child(belt)
	var neck := _mesh(_cylinder(0.065, 0.12), SKIN)
	neck.position = Vector3(0, 1.47, 0)
	_body.add_child(neck)
	# head
	_head = Node3D.new()
	_head.position = Vector3(0, 1.67, 0)
	_body.add_child(_head)
	var skull := _mesh(_sphere(0.21), SKIN)
	skull.scale = Vector3(0.95, 1.08, 1.0)
	_head.add_child(skull)
	# full, swept hair: crown, back/nape and a fringe swept to one side
	var hair_col := Color(0.2, 0.13, 0.08)
	var crown := _mesh(_sphere(0.225), hair_col)
	crown.scale = Vector3(1.0, 0.8, 1.06)
	crown.position = Vector3(0, 0.075, 0.015)
	_head.add_child(crown)
	var back := _mesh(_sphere(0.215), hair_col)
	back.scale = Vector3(0.98, 0.85, 0.85)
	back.position = Vector3(0, -0.005, 0.055)
	_head.add_child(back)
	for i in 4:
		var tuft := _mesh(_capsule(0.045, 0.2), hair_col)
		tuft.rotation = Vector3(deg_to_rad(70), deg_to_rad(-25 + i * 14), deg_to_rad(65))
		tuft.position = Vector3(-0.09 + i * 0.06, 0.15 + i * 0.008, -0.125 + absf(i - 1.5) * 0.012)
		_head.add_child(tuft)
	for side in [-1.0, 1.0]:
		var burn := _mesh(_capsule(0.03, 0.12), hair_col)
		burn.position = Vector3(0.19 * side, 0.02, -0.03)
		_head.add_child(burn)
		var eye := _mesh(_capsule(0.02, 0.06), Color(0.08, 0.08, 0.1))
		eye.position = Vector3(0.075 * side, 0.0, -0.195)
		_head.add_child(eye)
		_face.append(eye)
		var brow := _mesh(_capsule(0.011, 0.07), hair_col)
		brow.rotation = Vector3(0, 0, deg_to_rad(90 + 8 * side))
		brow.position = Vector3(0.075 * side, 0.065, -0.195)
		_head.add_child(brow)
		_face.append(brow)
		var ear := _mesh(_sphere(0.042), SKIN)
		ear.scale = Vector3(0.6, 1.0, 0.8)
		ear.position = Vector3(0.2 * side, -0.01, 0.0)
		_head.add_child(ear)
	var smile := _mesh(_torus(0.03, 0.04), Color(0.55, 0.2, 0.18))
	smile.rotation = Vector3(deg_to_rad(90), 0, 0)
	smile.scale = Vector3(1.0, 1.0, 0.4)
	smile.position = Vector3(0, -0.095, -0.192)
	_head.add_child(smile)
	_face.append(smile)

	# resting left arm
	var la_end := _shoulder_l + Vector3(-0.08, -0.55, 0.03)
	var la_mid := _shoulder_l + Vector3(-0.07, -0.29, 0.06)
	_body.add_child(_segment(_shoulder_l, la_mid, 0.065, SHIRT))
	_body.add_child(_segment(la_mid, la_end, 0.055, SKIN))
	var lh := _mesh(_sphere(0.07), SKIN)
	lh.position = la_end
	_body.add_child(lh)

	# right (controlled) arm
	var shoulder_ball := _mesh(_sphere(0.08), SHIRT)
	shoulder_ball.position = _shoulder_r
	_body.add_child(shoulder_ball)
	_upper_r = _mesh(_capsule(0.065, UPPER + 0.1), SHIRT)
	_fore_r = _mesh(_capsule(0.055, FORE + 0.08), SKIN)
	_elbow_r = _mesh(_sphere(0.064), SKIN)
	_body.add_child(_upper_r)
	_body.add_child(_fore_r)
	_body.add_child(_elbow_r)
	_hand_r = Node3D.new()
	_body.add_child(_hand_r)
	_hand_r.add_child(_mesh(_sphere(0.075), SKIN))

	# remote held in the hand (long axis = local -Z, buttons = +Y)
	_remote = Node3D.new()
	_hand_r.add_child(_remote)
	var shell := _mesh(_box(Vector3(0.055, 0.035, 0.24)), Color(0.22, 0.25, 0.32))
	shell.position = Vector3(0, 0.02, -0.07)
	_remote.add_child(shell)
	var btn := _mesh(_cylinder(0.014, 0.012), Color(0.2, 0.55, 1.0))
	btn.position = Vector3(0, 0.042, -0.13)
	_remote.add_child(btn)
	var tip := _mesh(_sphere(0.026), Color(0.4, 0.85, 1.0))
	_tip_mat = tip.material_override
	_tip_mat.emission_enabled = true
	_tip_mat.emission = Color(0.3, 0.8, 1.0)
	_tip_mat.emission_energy_multiplier = 1.0
	tip.position = Vector3(0, 0.02, -0.195)
	_remote.add_child(tip)


func _process(delta: float) -> void:
	_time += delta
	# breathing idle
	_body.position.y = sin(_time * 2.2) * 0.008

	if bowling:
		var dir_b := Basis(Vector3.RIGHT, swing_angle - PI * 0.5) * Vector3.FORWARD
		_solve_arm(_shoulder_r + Vector3(0.06, 0.0, 0.0) + dir_b * (UPPER + FORE) * 0.97, Vector3(1.0, 0.0, 0.15))
		_remote.visible = false
		_head.rotation = Vector3(0.12, 0, 0)
		hand_world = _hand_r.global_position
		return
	_remote.visible = true
	var aim := Basis(Vector3.UP, -aim_yaw) * Basis(Vector3.RIGHT, aim_pitch)
	var dir := aim * Vector3.FORWARD
	var target := _shoulder_r + Vector3(0.04, 0.0, 0.0) + dir * (UPPER + FORE) * 0.9
	_solve_arm(target)

	# remote follows the full calibrated phone rotation
	var full := aim * Basis(Vector3.BACK, -aim_roll)
	_remote.global_basis = global_basis * full
	tip_world = _remote.global_transform * Vector3(0, 0.02, -0.2)
	tip_forward = (global_basis * full * Vector3.FORWARD).normalized()

	# head follows the aim a little
	_head.rotation = Vector3(clampf(aim_pitch, -0.8, 0.8) * 0.3, -clampf(aim_yaw, -1.2, 1.2) * 0.45, 0)

	_tip_mat.emission_energy_multiplier = 1.0 + swing * 6.0


const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.82, 0.93, 1.0);
uniform float base_alpha = 0.10;
uniform float rim_alpha = 0.6;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(tint, vec3(1.0), rim);
	ALPHA = base_alpha + rim * rim_alpha;
}
"""

static var _ghost_mat: ShaderMaterial
var _solid_mats := {}


## Glassy see-through look while aiming so the lane stays visible:
## mostly clear with a soft white outline. strength 0 = solid.
## Tint the glass bowler with the current player's colour.
func set_ghost_tint(c: Color) -> void:
	if _ghost_mat:
		_ghost_mat.set_shader_parameter("tint", c.lerp(Color.WHITE, 0.45))


func set_ghost(strength: float) -> void:
	if _ghost_mat == null:
		var sh := Shader.new()
		sh.code = GHOST_SHADER
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = sh
	var on := strength > 0.0
	for f in _face: # the face would show through the back of the head
		f.visible = not on
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.get_parent() == _remote or m.get_parent().get_parent() == _remote:
			continue
		if not _solid_mats.has(m):
			_solid_mats[m] = m.material_override
		m.material_override = _ghost_mat if on else _solid_mats[m]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _solve_arm(target: Vector3, pole_hint := Vector3(0.6, -1.0, 0.35)) -> void:
	var s := _shoulder_r + _body.position
	var to_t := target - s
	var d := clampf(to_t.length(), 0.05, UPPER + FORE - 0.001)
	var axis := to_t.normalized()
	var cos_a := (UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var pole := pole_hint
	pole = (pole - axis * pole.dot(axis)).normalized()
	var elbow := s + axis * UPPER * cos_a + pole * UPPER * sin_a
	var hand := s + axis * d
	_place(_upper_r, s, elbow)
	_place(_fore_r, elbow, hand)
	_elbow_r.position = elbow - _body.position
	_hand_r.position = hand - _body.position


# Positions a Y-aligned capsule between two points (local to _body).
func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5 - _body.position)


func _segment(a: Vector3, b: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := _mesh(_capsule(r, a.distance_to(b) + r * 2.0), c)
	_place(mi, a, b)
	return mi


# ------------------------------------------------------------- primitives

static func material(c: Color, rough := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


static func _mesh(mesh: Mesh, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(c)
	return mi


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 24
	m.rings = 8
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 32
	m.rings = 16
	return m


static func _cylinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 32
	return m


static func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m
