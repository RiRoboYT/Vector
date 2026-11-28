class_name CricketBat
extends Node3D
## A cricket bat (96.5 cm, blade 10.8 cm wide) with real bat-ball impact.
##
## Bat-local frame: origin at the top of the handle (top hand), -Y runs down
## to the toe, +Z is the hitting face, X across the blade.
## Each physics tick the controller sets the new pose; contact is tested along
## the swept motion (CCD) and resolved as a 1-D collision along the contact
## normal with the bat's effective mass and restitution at that point of the
## blade (sweet spot ~ 15 cm from the toe; edges and handle are dead).

signal contact(point: Vector3, quality: float, edge: bool)

const BLADE_TOP := -0.33
const BLADE_TOE := -0.965
const HALF_W := 0.054
const FACE_Z := 0.012
const BACK_Z := -0.05
const SWEET_Y := -0.80
const SUBSTEPS := 8

var assist_width := 0.0 # extra half-width for easier contact (Easy mode)
var enabled := true
var last_hit_ms := -10000
var dbg_min := 99.0
var dbg_local := Vector3.ZERO

var _prev := Transform3D()
var _have_prev := false


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("ead2a0")
	wood.roughness = 0.55
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color("1a98c9")
	grip.roughness = 0.9
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.018
	hm.bottom_radius = 0.018
	hm.height = 0.34
	handle.mesh = hm
	handle.material_override = grip
	handle.position.y = -0.16
	add_child(handle)
	# blade: flat face, rounded spine
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(HALF_W * 2, BLADE_TOP - BLADE_TOE, 0.035)
	blade.mesh = bm
	blade.material_override = wood
	blade.position = Vector3(0, (BLADE_TOP + BLADE_TOE) * 0.5, -0.006)
	add_child(blade)
	var spine := MeshInstance3D.new()
	var sm := CapsuleMesh.new()
	sm.radius = 0.03
	sm.height = (BLADE_TOP - BLADE_TOE) * 0.9
	spine.mesh = sm
	spine.material_override = wood
	spine.position = Vector3(0, (BLADE_TOP + BLADE_TOE) * 0.5 - 0.03, -0.025)
	spine.scale = Vector3(1.3, 1.0, 0.8)
	add_child(spine)
	var sticker := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(HALF_W * 1.6, 0.16, 0.002)
	sticker.mesh = stm
	var stmat := StandardMaterial3D.new()
	stmat.albedo_color = Color("31b8e8")
	sticker.material_override = stmat
	sticker.position = Vector3(0, BLADE_TOP - 0.14, 0.0125)
	add_child(sticker)


func reset_motion() -> void:
	_have_prev = false


## Call once per physics tick after setting global_transform.
## Tests the swept bat against the ball and applies the impact.
func physics_check(ball: CricketBall, dt: float) -> void:
	var now := global_transform
	if not _have_prev:
		_prev = now
		_have_prev = true
		return
	if not enabled or ball.mode != CricketBall.Mode.FLYING or ball.off_bat:
		_prev = now
		return
	if Time.get_ticks_msec() - last_hit_ms < 300:
		_prev = now
		return
	# the ball moved this tick too: walk both back along the step
	var bp1 := ball.global_position
	var bp0 := bp1 - ball.vel * dt
	for i in range(1, SUBSTEPS + 1):
		var f := float(i) / SUBSTEPS
		var t := _interp(_prev, now, f)
		var bp := bp0.lerp(bp1, f)
		var local := t.affine_inverse() * bp
		var hw := HALF_W + assist_width
		var closest := Vector3(clampf(local.x, -hw, hw), clampf(local.y, BLADE_TOE, BLADE_TOP), clampf(local.z, BACK_Z, FACE_Z))
		var d := local - closest
		if d.length() < dbg_min:
			dbg_min = d.length()
			dbg_local = local
		if d.length() <= CricketBall.RADIUS:
			_resolve(ball, t, _interp(_prev, now, maxf(0.0, f - 1.0 / SUBSTEPS)), closest, d, bp, dt / SUBSTEPS)
			break
	_prev = now


func _resolve(ball: CricketBall, t: Transform3D, t_before: Transform3D, closest: Vector3, d: Vector3, bp: Vector3, h: float) -> void:
	var n_local := d.normalized() if d.length() > 0.0001 else Vector3(0, 0, 1)
	if local_is_face(closest) and n_local.z < 0.2:
		n_local = Vector3(0, 0, 1)
	var n := (t.basis * n_local).normalized()
	var p_world := t * closest
	var v_bat := (p_world - t_before * closest) / maxf(h, 0.0001)
	var v_ball := ball.vel
	var v_rel := v_ball - v_bat
	var vn := v_rel.dot(n)
	if vn >= 0.0:
		return # already separating
	# quality falls off away from the sweet spot and towards the edges
	var along := absf(closest.y - SWEET_Y) / 0.28
	var edge := absf(closest.x) > HALF_W * 0.75 or n_local.z < 0.5
	var quality := clampf(1.0 - along, 0.0, 1.0) * (0.45 if edge else 1.0)
	var m_eff := lerpf(0.35, 1.05, quality) # kg, effective bat mass at the point
	var e := lerpf(0.28, 0.52, quality) # coefficient of restitution
	var j := -(1.0 + e) * vn / (1.0 / CricketBall.MASS + 1.0 / m_eff)
	var v_new := v_ball + n * (j / CricketBall.MASS)
	# friction on the face drags the ball a little with the bat
	var vt := v_rel - n * vn
	v_new -= vt * 0.18
	ball.global_position = p_world + n * (CricketBall.RADIUS + 0.003)
	ball.set_velocity(v_new, true)
	last_hit_ms = Time.get_ticks_msec()
	contact.emit(p_world, quality, edge)
	Sfx.pin_hit(clampf(0.3 + quality * 0.7, 0.3, 1.0))


static func local_is_face(p: Vector3) -> bool:
	return p.z >= FACE_Z - 0.001


static func _interp(a: Transform3D, b: Transform3D, f: float) -> Transform3D:
	return Transform3D(a.basis.slerp(b.basis, f), a.origin.lerp(b.origin, f))
