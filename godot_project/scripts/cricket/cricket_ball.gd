class_name CricketBall
extends Node3D
## Cricket ball with its own physics (stepped at 480 Hz for accuracy):
##   gravity, quadratic air drag, swing (sideways force before it pitches),
##   bounce with different restitution/friction on the pitch and outfield,
##   spin "turn" off the pitch, rolling friction on grass, stump hits and
##   boundary detection. The same integrator drives predictions for fielders.

signal bounced(pos: Vector3, on_pitch: bool)
signal hit_stumps(stumps: Stumps, pos: Vector3, vel: Vector3)
signal boundary(six: bool)

const RADIUS := 0.036
const MASS := 0.16
const G := Vector3(0, -9.81, 0)
const DRAG_K := 0.0056 # 0.5 * rho * Cd * A / m  (Cd ~0.37)
const SUBSTEPS := 4
const ROLL_DECEL_GRASS := 1.9 # m/s^2
const ROLL_DECEL_PITCH := 3.0

enum Mode { HELD, FLYING, DEAD }

var mode := Mode.HELD
var vel := Vector3.ZERO
var swing := 0.0 # sideways accel (m/s^2) until it pitches; + = towards +X
var turn := 0.0 # sideways speed added at the first bounce (spin), fraction of speed
var pitched := false # bounced at least once since the bowler released it
var off_bat := false # has been hit by the bat
var grounded_after_bat := false # touched the ground after the bat (FOUR vs SIX)
var rolling := false
var field: CricketField
var trail: Trail

var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2
	sm.radial_segments = 32
	sm.rings = 16
	_mesh.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("f4f1ea") # white ball (limited-overs)
	m.roughness = 0.35
	m.rim_enabled = true
	m.rim = 0.3
	_mesh.material_override = m
	add_child(_mesh)
	var seam := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS - 0.0015
	tm.outer_radius = RADIUS + 0.0012
	seam.mesh = tm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color("3a7bd5")
	seam.material_override = smat
	seam.rotation.x = PI * 0.5
	_mesh.add_child(seam)
	trail = Trail.new()
	add_child(trail)


func hold(at: Vector3) -> void:
	mode = Mode.HELD
	global_position = at
	vel = Vector3.ZERO
	rolling = false


func release(from: Vector3, v: Vector3, p_swing := 0.0, p_turn := 0.0) -> void:
	global_position = from
	vel = v
	swing = p_swing
	turn = p_turn
	pitched = false
	off_bat = false
	grounded_after_bat = false
	rolling = false
	mode = Mode.FLYING
	trail.clear()


## After a bat or throw: new velocity, no more swing.
func set_velocity(v: Vector3, from_bat := false) -> void:
	vel = v
	swing = 0.0
	turn = 0.0
	rolling = false
	if from_bat:
		off_bat = true
		grounded_after_bat = false
	mode = Mode.FLYING


func kill() -> void:
	mode = Mode.DEAD
	vel = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if mode != Mode.FLYING:
		return
	var h := delta / SUBSTEPS
	for i in SUBSTEPS:
		var p := global_position
		var state := step_state(p, vel, h, true)
		global_position = state[0]
		vel = state[1]
		if mode != Mode.FLYING:
			break
		_check_stumps()
		_check_boundary()
	# spin the mesh visually
	if vel.length() > 0.1:
		var axis := Vector3.UP.cross(vel).normalized()
		if axis.length() > 0.1:
			_mesh.rotate(axis, vel.length() / RADIUS * delta * 0.3)
	trail.add_point(global_position, vel.length())


## One integration step. `live` = fire events / mutate flags (false for predictions).
func step_state(p: Vector3, v: Vector3, h: float, live: bool) -> Array:
	var on_ground := p.y <= RADIUS + 0.0005 and absf(v.y) < 0.8
	if on_ground and (rolling or not live):
		# rolling: friction slows it, no bounce
		var hv := Vector3(v.x, 0, v.z)
		var sp := hv.length()
		var dec := (ROLL_DECEL_PITCH if CricketField.on_pitch(p) else ROLL_DECEL_GRASS) * h
		if sp <= dec:
			hv = Vector3.ZERO
		else:
			hv = hv * ((sp - dec) / sp)
		v = hv
		p += v * h
		p.y = RADIUS
		return [p, v]
	var a := G - v * v.length() * DRAG_K
	if live and not pitched and not off_bat:
		a.x += swing
	v += a * h
	p += v * h
	if p.y < RADIUS and v.y < 0.0:
		p.y = RADIUS
		var pitch_surface := CricketField.on_pitch(p)
		var e := 0.52 if pitch_surface else 0.38 # vertical restitution
		var keep := 0.9 if pitch_surface else 0.74 # horizontal speed kept
		var vin := v
		v = Vector3(v.x * keep, -v.y * e, v.z * keep)
		if live:
			if not pitched and not off_bat and turn != 0.0:
				v.x += turn * Vector2(vin.x, vin.z).length()
			if not pitched:
				pitched = true
			if off_bat:
				grounded_after_bat = true
			bounced.emit(p, pitch_surface)
		if absf(v.y) < 0.9:
			v.y = 0.0
			if live:
				rolling = true
	return [p, v]


## Where a ball released with velocity v first touches the ground (with drag + swing).
static func simulate_to_bounce(from: Vector3, v: Vector3, p_swing: float) -> Vector3:
	var p := from
	var h := 1.0 / 480.0
	for i in 4000:
		var a := G - v * v.length() * DRAG_K
		a.x += p_swing
		v += a * h
		p += v * h
		if p.y <= RADIUS:
			return p
	return p


## Launch velocity for a delivery: `speed` (m/s) from `from` landing on `target`
## (y ignored) with the given swing. Solves elevation and sideways aim.
static func solve_delivery(from: Vector3, target: Vector3, speed: float, p_swing: float) -> Vector3:
	var yaw_dir := Vector3(target.x - from.x, 0, target.z - from.z).normalized()
	var aim_x_offset := 0.0
	var v := Vector3.ZERO
	for iter in 4:
		var aim := Vector3(target.x + aim_x_offset - from.x, 0, target.z - from.z).normalized()
		var lo := deg_to_rad(-30.0)
		var hi := deg_to_rad(25.0)
		for k in 30: # bisection on elevation: further landing with higher angle
			var mid := (lo + hi) * 0.5
			v = (aim * cos(mid) + Vector3.UP * sin(mid)) * speed
			var land := simulate_to_bounce(from, v, p_swing)
			var along := (land - from).dot(yaw_dir)
			var want := (target - from).dot(yaw_dir)
			if along < want:
				lo = mid
			else:
				hi = mid
		var land2 := simulate_to_bounce(from, v, p_swing)
		aim_x_offset += target.x - land2.x
	return v


## Predicted positions every `dt` seconds for `t_max` seconds (no events).
func predict(t_max: float, dt := 0.05) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var p := global_position
	var v := vel
	var t := 0.0
	var h := dt / 6.0
	while t < t_max:
		for i in 6:
			var st := step_state(p, v, h, false)
			p = st[0]
			v = st[1]
		t += dt
		out.append(p)
		if v.length() < 0.05 and p.y <= RADIUS + 0.001:
			break
	return out


func _check_stumps() -> void:
	if field == null:
		return
	var p := global_position
	if p.y > CricketField.STUMP_H + RADIUS:
		return
	for st in [field.striker_stumps, field.bowler_stumps]:
		if st.broken or absf(p.z - st.global_position.z) > 0.1:
			continue
		for sp in st.stump_points():
			if Vector2(p.x - sp.x, p.z - sp.z).length() < RADIUS + Stumps.STUMP_R:
				var v_hit := vel
				# deflect off the stump (it is much heavier than the ball)
				var n := Vector3(p.x - sp.x, 0, p.z - sp.z).normalized()
				vel = (vel - 1.6 * n * vel.dot(n)) * 0.45
				global_position = Vector3(sp.x, p.y, sp.z) + n * (RADIUS + Stumps.STUMP_R + 0.002)
				st.break_wicket(p, v_hit)
				hit_stumps.emit(st, p, v_hit)
				return


func _check_boundary() -> void:
	if not off_bat:
		return
	if CricketField.dist_from_center(global_position) >= CricketField.BOUNDARY:
		var six := not grounded_after_bat
		boundary.emit(six)
		mode = Mode.DEAD


class Trail:
	extends MeshInstance3D
	var _pts: Array[Vector3] = []
	var _im := ImmediateMesh.new()

	func _ready() -> void:
		mesh = _im
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		material_override = m

	func clear() -> void:
		_pts.clear()
		_im.clear_surfaces()

	func add_point(p: Vector3, speed: float) -> void:
		_pts.push_front(p)
		while _pts.size() > 18:
			_pts.pop_back()
		_im.clear_surfaces()
		if _pts.size() < 2 or speed < 4.0:
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in _pts.size():
			var a := _pts[i]
			var b := _pts[mini(i + 1, _pts.size() - 1)]
			var d := (a - b)
			var side := d.cross(cam.global_position - a).normalized() if d.length() > 0.0001 else Vector3.UP
			var k := 1.0 - float(i) / _pts.size()
			var c := Color(1, 1, 1, 0.45 * k)
			_im.surface_set_color(c)
			_im.surface_add_vertex(a + side * 0.022 * k)
			_im.surface_set_color(c)
			_im.surface_add_vertex(a - side * 0.022 * k)
		_im.surface_end()
