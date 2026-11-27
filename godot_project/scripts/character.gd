class_name Character
extends Node3D
## A simple, original low-poly "bean" character built from primitives.
## The right arm is driven by two-bone IK toward a target computed from the
## controller's yaw/pitch; the remote in the hand follows the full rotation.

const UPPER := 0.30
const FORE := 0.29
const SKIN := Color(1.0, 0.84, 0.7)
const SHIRT := Color(0.16, 0.62, 0.9)
## Set before adding to the tree to dress the character in team colours.
var shirt := SHIRT
var pants := Color(0.22, 0.25, 0.36)
## Cast shadows (turn off for distant crowd-like figures to save GPU).
var shadows := true
const PANTS := Color(0.22, 0.25, 0.36)

var aim_yaw := 0.0
var aim_pitch := 0.0
var aim_roll := 0.0
var swing := 0.0

## Bowling mode: arm swings in the vertical plane, no remote, no head follow.
var bowling := false
var swing_angle := 0.0 # radians: 0 = arm hanging, >0 forward, <0 back
var hand_world := Vector3.ZERO
## Body animation (bowling approach), set by the game each frame.
var step_phase := 0.0 # advances while walking (radians)
var walk_amount := 0.0 # 0 = standing, 1 = full stride
var lean := 0.0 # forward lean of the upper body (radians)
var crouch := 0.0 # metres the body drops (knee bend)
var slide := 0.0 # 0..1 release pose: front leg slides, back leg kicks back
var balance_arm := 0.0 # 0..1 left arm swings out for balance
## Two-handed holding (cricket bat, catching): hands reach these world points.
var hand_targets := false
var hand_r_world := Vector3.ZERO
var hand_l_world := Vector3.ZERO
var head_turn := 0.0 # head yaw (radians), e.g. to watch the ball
var head_tilt := 0.0

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
var _legs: Array[Node3D] = [] # hip pivots: [left, right]
var _upper_l: MeshInstance3D
var _fore_l: MeshInstance3D
var _elbow_l: MeshInstance3D
var _hand_l: Node3D
const HIP_Y := 0.70
var _time := 0.0
var _face: Array[Node3D] = []


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	# legs hang from hip pivots so they can step
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.11 * side, HIP_Y, 0.0)
		add_child(hip)
		_legs.append(hip)
		var leg := _mesh(_capsule(0.085, 0.64), pants)
		leg.position = Vector3(0, -0.32, 0)
		hip.add_child(leg)
		var shoe := _mesh(_sphere(0.1), Color(0.95, 0.95, 0.97))
		shoe.scale = Vector3(1.0, 0.55, 1.45)
		shoe.position = Vector3(0, -0.64, -0.04)
		hip.add_child(shoe)
	# torso: slim, sporty polo
	var torso := _mesh(_capsule(0.215, 0.74), shirt)
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

	# left arm (IK too, for balance poses)
	var shoulder_l := _mesh(_sphere(0.08), shirt)
	shoulder_l.position = _shoulder_l
	_body.add_child(shoulder_l)
	_upper_l = _mesh(_capsule(0.065, UPPER + 0.1), shirt)
	_fore_l = _mesh(_capsule(0.055, FORE + 0.08), SKIN)
	_elbow_l = _mesh(_sphere(0.064), SKIN)
	_body.add_child(_upper_l)
	_body.add_child(_fore_l)
	_body.add_child(_elbow_l)
	_hand_l = Node3D.new()
	_body.add_child(_hand_l)
	_hand_l.add_child(_mesh(_sphere(0.07), SKIN))

	# right (controlled) arm
	var shoulder_ball := _mesh(_sphere(0.08), shirt)
	shoulder_ball.position = _shoulder_r
	_body.add_child(shoulder_ball)
	_upper_r = _mesh(_capsule(0.065, UPPER + 0.1), shirt)
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
	if not shadows:
		for mi in find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_time += delta
	# upper body: breathing, walking bob, knee bend and forward lean around the hips
	var bob := sin(_time * 2.2) * 0.008 + absf(sin(step_phase)) * 0.035 * walk_amount
	var pivot := Vector3(0, HIP_Y, 0)
	var lb := Basis(Vector3.RIGHT, -lean)
	_body.transform = Transform3D(lb, pivot - lb * pivot + Vector3(0, bob - crouch, 0))
	# legs: alternate steps, then slide / kick-back pose at release
	var stride := sin(step_phase) * 0.5 * walk_amount
	_legs[0].rotation.x = stride + slide * 0.55 # left leg forward
	_legs[1].rotation.x = -stride - slide * 0.75 # right leg back
	for leg in _legs:
		leg.position.y = HIP_Y + bob - crouch
	_legs[0].position.z = -crouch * 0.6
	_legs[1].position.z = -crouch * 0.6

	# left arm: hangs, swings with the steps, reaches out for balance
	var rest_l := _shoulder_l + Vector3(-0.08, -0.55, 0.03 + sin(step_phase) * 0.12 * walk_amount)
	var out_l := _shoulder_l + Vector3(-0.5, -0.22, -0.12)
	_solve_limb(_body.transform * rest_l.lerp(out_l, balance_arm), _shoulder_l, _upper_l, _fore_l, _elbow_l, _hand_l, Vector3(-1.0, 0.0, 0.2))

	if hand_targets:
		_solve_limb(to_local(hand_r_world), _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(1.0, -0.6, 0.6))
		_solve_limb(to_local(hand_l_world), _shoulder_l, _upper_l, _fore_l, _elbow_l, _hand_l, Vector3(-1.0, -0.6, 0.6))
		_remote.visible = false
		_head.rotation = Vector3(head_tilt + lean * 0.3, head_turn, 0)
		hand_world = _hand_r.global_position
		return

	if bowling:
		# swing angle is relative to gravity, so it stays true while leaning
		var dir_b := Basis(Vector3.RIGHT, swing_angle - PI * 0.5) * Vector3.FORWARD
		var sh := _body.transform * _shoulder_r
		_solve_limb(sh + Vector3(0.06, 0.0, 0.0) + dir_b * (UPPER + FORE) * 0.97, _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(1.0, 0.0, 0.15))
		_remote.visible = false
		_head.rotation = Vector3(0.12 + lean * 0.4, 0, 0)
		hand_world = _hand_r.global_position
		return
	_remote.visible = true
	var aim := Basis(Vector3.UP, -aim_yaw) * Basis(Vector3.RIGHT, aim_pitch)
	var dir := aim * Vector3.FORWARD
	var target := _body.transform * _shoulder_r + Vector3(0.04, 0.0, 0.0) + dir * (UPPER + FORE) * 0.9
	_solve_limb(target, _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(0.6, -1.0, 0.35))

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
uniform float base_alpha = 0.05;
uniform float rim_alpha = 0.42;
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


## Two-bone IK. `target` is in character space; the limb lives in _body
## space (so it follows the lean). Shoulder is given in _body space.
func _solve_limb(target: Vector3, shoulder: Vector3, upper: MeshInstance3D, fore: MeshInstance3D,
		elbow_mi: MeshInstance3D, hand_node: Node3D, pole_hint: Vector3) -> void:
	var inv := _body.transform.affine_inverse()
	var t := inv * target
	var to_t := t - shoulder
	var d := clampf(to_t.length(), 0.05, UPPER + FORE - 0.001)
	var axis := to_t.normalized()
	var cos_a := (UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var pole := inv.basis * pole_hint
	pole = pole - axis * pole.dot(axis)
	pole = pole.normalized() if pole.length() > 0.001 else Vector3.RIGHT
	var elbow := shoulder + axis * UPPER * cos_a + pole * UPPER * sin_a
	var hand := shoulder + axis * d
	_place(upper, shoulder, elbow)
	_place(fore, elbow, hand)
	elbow_mi.position = elbow
	hand_node.position = hand


# Positions a Y-aligned capsule between two points (in its parent's space).
func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)


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
