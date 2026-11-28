class_name TennisBall
extends Node3D
## Tennis ball with its own physics (480 Hz):
##   gravity, quadratic drag, Magnus force from spin (topspin dips, slice
##   floats), hard-court bounce where topspin kicks forward/up and slice skids
##   low, and a real net (tape height 0.914 m in the middle, 1.07 m at the posts).
## Court: net along z = 0, baselines at z = +-11.885, doubles sidelines x = +-5.485.

signal bounced(pos: Vector3)
signal hit_net(pos: Vector3)

const RADIUS := 0.0335
const G := Vector3(0, -9.81, 0)
const DRAG_K := 0.0105 # 0.5*rho*Cd*A/m for a 57 g ball, Cd ~0.55
const MAGNUS_K := 0.0062 # lift per (m/s) per rev/s (CL ~0.2 at 30 rev/s)
const SUBSTEPS := 4

enum Mode { HELD, FLYING, DEAD }

var mode := Mode.HELD
var vel := Vector3.ZERO
var spin := 0.0 # rev/s; + topspin (dips), - slice/backspin (floats)
var bounces := 0 # since the last hit
var last_hitter_side := 0 # +1 near team (z > 0) hit it, -1 far team
var trail: CricketBall.Trail
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	# drawn a bit larger than life so it reads on a TV from the sofa
	sm.radius = RADIUS * 1.7
	sm.height = RADIUS * 3.4
	sm.radial_segments = 24
	sm.rings = 12
	_mesh.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("d9f23c") # optic yellow
	m.roughness = 0.85
	m.emission_enabled = true
	m.emission = Color("d9f23c")
	m.emission_energy_multiplier = 0.15
	_mesh.material_override = m
	add_child(_mesh)
	var seam := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS * 1.7 - 0.002
	tm.outer_radius = RADIUS * 1.7 + 0.0015
	seam.mesh = tm
	var sw := StandardMaterial3D.new()
	sw.albedo_color = Color(0.95, 0.97, 0.9)
	seam.material_override = sw
	seam.rotation = Vector3(0.6, 0, 0.4)
	_mesh.add_child(seam)
	trail = CricketBall.Trail.new()
	add_child(trail)
	# soft blob shadow on the court, so height is easy to judge
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.24)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	_shadow.material_override = CricketField._shader_mat("""
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.0, 0.05, 0.15);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * 0.45;
}
""")
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func hold(at: Vector3) -> void:
	mode = Mode.HELD
	global_position = at
	vel = Vector3.ZERO


func launch(from: Vector3, v: Vector3, p_spin: float, side: int) -> void:
	global_position = from
	vel = v
	spin = p_spin
	bounces = 0
	last_hitter_side = side
	mode = Mode.FLYING
	trail.clear()


func kill() -> void:
	mode = Mode.DEAD


func _process(_d: float) -> void:
	var p := global_position
	_shadow.visible = mode != Mode.DEAD and visible
	_shadow.global_position = Vector3(p.x, 0.012, p.z)
	var k := clampf(1.0 - p.y / 6.0, 0.4, 1.0)
	_shadow.scale = Vector3(k, 1, k)


func _physics_process(delta: float) -> void:
	if mode != Mode.FLYING:
		return
	var h := delta / SUBSTEPS
	for i in SUBSTEPS:
		var st := step(global_position, vel, spin, h, true)
		global_position = st[0]
		vel = st[1]
		spin = st[2]
		if mode != Mode.FLYING:
			break
	if vel.length() > 0.2:
		var axis := Vector3.UP.cross(vel).normalized()
		if axis.length() > 0.1:
			_mesh.rotate(axis, (vel.length() / RADIUS * 0.2 + spin * 2.0) * delta)
	trail.add_point(global_position, vel.length())


static func accel(v: Vector3, s: float) -> Vector3:
	var a := G - v * v.length() * DRAG_K
	# Magnus: topspin pushes the ball down along its path (perpendicular to v)
	var hv := Vector3(v.x, 0, v.z)
	if hv.length() > 0.1:
		var side := Vector3.UP.cross(hv.normalized()) # horizontal, perpendicular
		var lift_dir := hv.normalized().cross(side) # up-ish, perpendicular to path
		lift_dir = (lift_dir - v.normalized() * lift_dir.dot(v.normalized())).normalized()
		a -= lift_dir * s * v.length() * MAGNUS_K
	return a


## One integration step; `live` = emit events / bounce counting.
func step(p: Vector3, v: Vector3, s: float, h: float, live: bool) -> Array:
	var p0 := p
	v += accel(v, s) * h
	p += v * h
	# net: crossing z = 0 below the tape
	if signf(p0.z) != signf(p.z) and absf(p.x) < TennisCourt.HALF_W_DOUBLES + 0.9:
		var tape := TennisCourt.net_height(p.x)
		var t := p0.z / (p0.z - p.z)
		var y_cross := lerpf(p0.y, p.y, t)
		if y_cross < tape + RADIUS * 0.5:
			if y_cross > tape - RADIUS * 1.5 and v.y > -6.0:
				# clipped the tape: loses pace, pops up, may trickle over
				v = Vector3(v.x * 0.35, absf(v.y) * 0.3 + 1.2, v.z * (0.25 if randf() < 0.5 else -0.15))
				p = Vector3(p.x, tape + RADIUS + 0.01, p0.z * 0.0 + signf(v.z) * 0.02)
			else:
				# into the net
				v = Vector3(v.x * 0.15, 0.0, -v.z * 0.08)
				p = Vector3(p.x, y_cross, signf(p0.z) * 0.05)
				if live:
					hit_net.emit(p)
	if p.y < RADIUS and v.y < 0.0:
		p.y = RADIUS
		var vin := v
		# hard court: COR ~0.75 vertical; spin changes the kick
		var e := 0.76 + clampf(s, -40.0, 40.0) * 0.0012
		var keep := 0.62 + clampf(s, -40.0, 40.0) * 0.003
		v = Vector3(v.x * keep, -v.y * e, v.z * keep)
		s *= 0.5
		if live:
			bounces += 1
			bounced.emit(p)
		if absf(v.y) < 0.4:
			v.y = 0.0
		var _unused := vin
	if p.y <= RADIUS + 0.0005 and absf(v.y) < 0.01:
		v *= maxf(0.0, 1.0 - 1.5 * h) # rolling
	return [p, v, s]


## Predicted positions every dt for t_max seconds (no events).
func predict(t_max: float, dt := 0.02) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var p := global_position
	var v := vel
	var s := spin
	var t := 0.0
	var n := 4
	while t < t_max:
		for i in n:
			var st := step(p, v, s, dt / n, false)
			p = st[0]
			v = st[1]
			s = st[2]
		t += dt
		out.append(p)
	return out


## Where a shot first lands (y = radius), or the net-crossing failure point.
static func simulate_landing(from: Vector3, v: Vector3, s: float) -> Dictionary:
	var p := from
	var h := 1.0 / 480.0
	var crossed_ok := true
	for i in 3000:
		var p0 := p
		v += accel(v, s) * h
		p += v * h
		if signf(p0.z) != signf(p.z) and absf(p.x) < TennisCourt.HALF_W_DOUBLES + 0.9:
			var t := p0.z / (p0.z - p.z)
			if lerpf(p0.y, p.y, t) < TennisCourt.net_height(p.x) + RADIUS:
				crossed_ok = false
		if p.y <= RADIUS:
			return {"pos": p, "net_ok": crossed_ok, "t": i * h}
	return {"pos": p, "net_ok": crossed_ok, "t": 3000 * h}


## Velocity for a shot from `from` landing on `target` at `speed` m/s with spin.
## Returns {v, ok}: ok = clears the net.
static func solve_shot(from: Vector3, target: Vector3, speed: float, s: float) -> Dictionary:
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	var want := flat.length()
	var dir := flat / maxf(want, 0.001)
	var lo := deg_to_rad(-12.0)
	var hi := deg_to_rad(55.0)
	var v := dir * speed
	var res := {}
	for k in 28:
		var mid := (lo + hi) * 0.5
		v = (dir * cos(mid) + Vector3.UP * sin(mid)) * speed
		res = simulate_landing(from, v, s)
		var got: float = Vector3(res.pos.x - from.x, 0, res.pos.z - from.z).dot(dir)
		if got < want:
			lo = mid
		else:
			hi = mid
	return {"v": v, "ok": res.get("net_ok", true)}
