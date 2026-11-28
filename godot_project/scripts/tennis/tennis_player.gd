class_name TennisPlayer
extends Node3D
## One doubles player: a Character with a racket. Moves on its own (Wii-style)
## and plays forehand / backhand / serve swing animations.
## team 0 = near side (z > 0, faces -Z), team 1 = far side (faces +Z).

const RUN_SPEED := 6.0
const ACCEL := 14.0
const SHOULDER_H := 1.38

var team := 0
var slot := 0
var name_ := ""
var pid := "" # controlling phone ("" = computer)
var character: Character
var racket: Node3D
var target := Vector3.ZERO
var vel := Vector3.ZERO

# swing animation
var swing_kind := "" # "fh", "bh", "serve", ""
var swing_t := 0.0 # 0..1 progress
var swing_speed := 2.6 # 1/s
var serve_toss := 0.0 # 0..1 tossing arm pose

var _strings_mat: ShaderMaterial


func setup(p_team: int, p_slot: int, shirt: Color, p_name: String) -> void:
	team = p_team
	slot = p_slot
	name_ = p_name
	character = Character.new()
	character.shirt = shirt
	character.pants = Color(0.96, 0.96, 0.96)
	character.outfit = "tennis"
	character.look_seed = Character.seed_for(p_name) if p_name != "" else -1
	character.hand_targets = true
	add_child(character)
	racket = _make_racket()
	add_child(racket)
	racket.top_level = true


func facing() -> float:
	return -1.0 if team == 0 else 1.0 # direction of the net along z


## Point on the racket face (world) — where the ball is struck.
func contact_point() -> Vector3:
	return racket.global_transform * Vector3(0, 0, -0.55)


func _make_racket() -> Node3D:
	var r := Node3D.new()
	var grip := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.016
	gm.bottom_radius = 0.018
	gm.height = 0.3
	grip.mesh = gm
	grip.material_override = CricketField._mat(Color("2f3a46"))
	grip.rotation.x = PI * 0.5
	grip.position.z = -0.12
	r.add_child(grip)
	var frame := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.122
	tm.outer_radius = 0.146
	tm.rings = 32
	frame.mesh = tm
	var fm := CricketField._mat(Color("e23d3d") if team == 1 else Color("2a6fd6"), 0.3)
	fm.metallic = 0.3
	frame.material_override = fm
	frame.scale = Vector3(0.82, 1.0, 1.08)
	frame.rotation.z = PI * 0.5
	frame.position.z = -0.55
	r.add_child(frame)
	var strings := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.2, 0.26)
	strings.mesh = qm
	_strings_mat = CricketField._shader_mat("""
shader_type spatial;
render_mode cull_disabled, blend_mix;
void fragment() {
	vec2 g = abs(fract(UV * vec2(14.0, 18.0)) - 0.5);
	float line = 1.0 - smoothstep(0.3, 0.45, min(g.x, g.y));
	vec2 c = (UV - 0.5) * 2.0;
	float inside = 1.0 - smoothstep(0.92, 1.0, length(c));
	ALBEDO = vec3(0.95);
	ALPHA = max(line * 0.95, 0.18) * inside;
}
""")
	strings.material_override = _strings_mat
	strings.rotation = Vector3(0, PI * 0.5, 0)
	strings.position.z = -0.55
	r.add_child(strings)
	return r


func start_swing(kind: String, speed := 2.6) -> void:
	swing_kind = kind
	swing_t = 0.0
	swing_speed = speed


func _process(delta: float) -> void:
	# --- movement (auto run to target)
	var to := target - global_position
	to.y = 0
	var d := to.length()
	var want := Vector3.ZERO
	if d > 0.04:
		want = to / d * minf(RUN_SPEED, sqrt(2.0 * ACCEL * d))
	var dv := want - vel
	if dv.length() > ACCEL * delta:
		dv = dv.normalized() * ACCEL * delta
	vel += dv
	global_position += vel * delta
	var sp := vel.length()
	var c := character
	c.global_position = global_position
	c.rotation.y = 0.0 if team == 0 else PI
	c.step_phase += sp * delta / 0.75 * PI
	c.walk_amount = clampf(sp / 3.0, 0.0, 1.0)
	c.crouch = lerpf(c.crouch, 0.07 if swing_kind == "" else 0.12, 1.0 - exp(-delta * 8.0))
	c.lean = lerpf(c.lean, 0.12 + clampf(sp / RUN_SPEED, 0.0, 1.0) * 0.15, 1.0 - exp(-delta * 8.0))

	# --- swing animation
	if swing_kind != "":
		swing_t += delta * swing_speed
		if swing_t >= 1.0:
			swing_kind = ""
			swing_t = 0.0
	var basis := c.global_basis
	var sh := global_position + basis * Vector3(0.27, SHOULDER_H, 0)
	var hand_r: Vector3
	var hand_l: Vector3
	var head_dir: Vector3 # direction the racket points from the hand
	match swing_kind:
		"fh", "bh":
			var side := 1.0 if swing_kind == "fh" else -1.0
			# angle around the body: back (behind the hitting side) -> across the front
			var e := ease(swing_t, -1.8)
			var ang := lerpf(deg_to_rad(-120.0), deg_to_rad(80.0), e) # 0 = straight ahead
			var h := lerpf(0.95, 1.3, e) # low to high (topspin brush)
			var dir := basis * Vector3(sin(ang) * side, 0, -cos(ang)).normalized()
			hand_r = global_position + Vector3(0, h, 0) + dir * 0.62 + basis * Vector3(0.2 * side, 0, 0)
			head_dir = (dir + Vector3(0, 0.1, 0)).normalized()
			hand_l = hand_r + basis * Vector3(-0.12, -0.05, 0.05) if swing_kind == "bh" else global_position + basis * Vector3(-0.35, 1.05, -0.35)
			c.lean = 0.2
		"serve":
			var e2 := ease(swing_t, -1.6)
			var a := lerpf(deg_to_rad(-200.0), deg_to_rad(40.0), e2) # behind the back -> over the top -> down
			var up := Vector3(0, cos(a), 0) * -1.0
			var fwd := basis * Vector3(0, 0, -1) * sin(a) * -1.0
			hand_r = sh + (up + fwd).normalized() * 0.6
			head_dir = (hand_r - sh).normalized()
			hand_l = global_position + basis * Vector3(-0.3, 1.1, -0.3)
		_:
			# ready position, or the toss before a serve
			hand_r = global_position + basis * Vector3(0.42, 0.98 - c.crouch, -0.3)
			head_dir = (basis * Vector3(0.55, 0.75, -0.35)).normalized()
			hand_l = global_position + basis * Vector3(-0.15, 1.0 + serve_toss * 1.0, -0.4 - serve_toss * 0.1)
	if c.reaction != "":
		hand_r = c.right_hand()
		head_dir = Vector3(0, 1, 0)
	c.hand_r_world = hand_r
	c.hand_l_world = hand_l
	# racket: grip in the hand, head pointing along head_dir (local -Z)
	var z := -head_dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = basis * Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	racket.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * 1.25), hand_r) # chunky, readable on a TV
