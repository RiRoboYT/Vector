class_name Character
extends Node3D
## A simple, original low-poly "bean" character built from primitives.
## The right arm is driven by two-bone IK toward a target computed from the
## controller's yaw/pitch; the remote in the hand follows the full rotation.

const UPPER := 0.30
const FORE := 0.29
const SKIN := Color(1.0, 0.84, 0.7)
const SHIRT := Color(0.18, 0.55, 0.98)
const PANTS := Color(0.22, 0.25, 0.36)

var aim_yaw := 0.0
var aim_pitch := 0.0
var aim_roll := 0.0
var swing := 0.0

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
	# torso
	var torso := _mesh(_capsule(0.25, 0.78), SHIRT)
	torso.position = Vector3(0, 1.08, 0)
	_body.add_child(torso)
	var belt := _mesh(_cylinder(0.252, 0.06), Color(0.12, 0.38, 0.85))
	belt.position = Vector3(0, 0.8, 0)
	_body.add_child(belt)
	# head
	_head = Node3D.new()
	_head.position = Vector3(0, 1.66, 0)
	_body.add_child(_head)
	var skull := _mesh(_sphere(0.24), SKIN)
	_head.add_child(skull)
	var hair := _mesh(_sphere(0.245), Color(0.33, 0.2, 0.12))
	hair.scale = Vector3(1.0, 0.62, 1.0)
	hair.position = Vector3(0, 0.08, 0.02)
	_head.add_child(hair)
	for side in [-1.0, 1.0]:
		var eye := _mesh(_capsule(0.022, 0.07), Color(0.08, 0.08, 0.1))
		eye.position = Vector3(0.085 * side, 0.0, -0.215)
		_head.add_child(eye)
		var cheek := _mesh(_sphere(0.035), Color(1.0, 0.62, 0.6))
		cheek.scale = Vector3(1.0, 0.6, 0.4)
		cheek.position = Vector3(0.14 * side, -0.07, -0.18)
		_head.add_child(cheek)
		var ear := _mesh(_sphere(0.05), SKIN)
		ear.position = Vector3(0.235 * side, -0.01, 0.0)
		_head.add_child(ear)
	var smile := _mesh(_torus(0.035, 0.045), Color(0.5, 0.15, 0.15))
	smile.rotation = Vector3(deg_to_rad(90), 0, 0)
	smile.scale = Vector3(1.0, 1.0, 0.45)
	smile.position = Vector3(0, -0.1, -0.215)
	_head.add_child(smile)

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


func _solve_arm(target: Vector3) -> void:
	var s := _shoulder_r + _body.position
	var to_t := target - s
	var d := clampf(to_t.length(), 0.05, UPPER + FORE - 0.001)
	var axis := to_t.normalized()
	var cos_a := (UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var pole := Vector3(0.6, -1.0, 0.35)
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
