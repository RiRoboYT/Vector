class_name TennisCourt
extends Node3D
## Outdoor hard court in a small, sunny stadium. Real dimensions (metres):
## 23.77 x 10.97 doubles court, net along z = 0, near baseline at z = +11.885.

const HALF_L := 11.885
const HALF_W_DOUBLES := 5.485
const HALF_W_SINGLES := 4.115
const SERVICE_Z := 6.40
const NET_CENTER := 0.914
const NET_POST := 1.07


static func net_height(x: float) -> float:
	return lerpf(NET_CENTER, NET_POST, clampf(absf(x) / (HALF_W_DOUBLES + 0.9), 0.0, 1.0))


static func in_doubles(p: Vector3) -> bool:
	return absf(p.x) <= HALF_W_DOUBLES + 0.03 and absf(p.z) <= HALF_L + 0.03


## Service box the serve must land in. server_side: +1 near (z > 0) serving to
## the far court; deuce = right-hand court from the server's view.
static func in_service_box(p: Vector3, server_side: int, deuce: bool) -> bool:
	var to_z := -server_side # landing half
	if signf(p.z) != to_z or absf(p.z) > SERVICE_Z + 0.03:
		return false
	# server at +z facing -z: their right is +x; the target box is diagonal
	var box_x := -1.0 if deuce else 1.0
	box_x *= float(server_side)
	return signf(p.x) == box_x and absf(p.x) <= HALF_W_SINGLES + 0.03


const COURT_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 inner : source_color = vec3(0.19, 0.44, 0.74);
uniform vec3 outer : source_color = vec3(0.21, 0.53, 0.38);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec2 p = wpos.xz;
	bool in_court = abs(p.x) < 5.485 && abs(p.y) < 11.885;
	vec3 c = in_court ? inner : outer;
	// acrylic surface: fine sandy grain + slightly worn behind the baselines
	float aa = clamp(1.0 - length(fwidth(p)) * 30.0, 0.0, 1.0);
	c *= 1.0 + (noise(p * 90.0) - 0.5) * 0.1 * aa + (noise(p * 2.0) - 0.5) * 0.05;
	// scuffed, faded patches where players stand: behind the baselines and at the T
	float wear = (1.0 - smoothstep(0.0, 2.2, abs(abs(p.y) - 12.6))) * (1.0 - smoothstep(0.5, 3.5, abs(p.x)));
	wear += (1.0 - smoothstep(0.0, 1.2, length(vec2(p.x, abs(p.y) - 6.4)))) * 0.5;
	wear *= 0.6 + noise(p * 3.0) * 0.8;
	c = mix(c, mix(c, vec3(dot(c, vec3(0.33))), 0.35) * 1.18, clamp(wear, 0.0, 1.0) * 0.55);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
}
"""

const NET_SHADER := """
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_always;
void fragment() {
	vec2 g = abs(fract(UV * vec2(260.0, 26.0)) - 0.5);
	float line = 1.0 - smoothstep(0.32, 0.46, min(g.x, g.y));
	ALBEDO = vec3(0.08, 0.09, 0.1);
	ALPHA = line * 0.85;
	ROUGHNESS = 0.9;
}
"""


func _ready() -> void:
	_environment()
	_ground()
	_lines()
	_net()
	_surroundings()
	_extras()


func _environment() -> void:
	Look.setup(self, "day", 60.0)


func _ground() -> void:
	# lush lawn around the stadium (same natural grass as the cricket ground)
	var lawn := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(220, 220)
	lawn.mesh = pm
	lawn.material_override = CricketField._shader_mat(CricketField.GRASS_SHADER)
	lawn.position.y = -0.02
	add_child(lawn)
	# court + run-off area (acrylic)
	var court := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(HALF_W_DOUBLES * 2 + 7.4, HALF_L * 2 + 13.0)
	court.mesh = cm
	court.material_override = CricketField._shader_mat(COURT_SHADER)
	court.position.y = 0.001
	add_child(court)
	# real grass blades on the lawn just outside the walls behind each baseline
	var rx := HALF_W_DOUBLES + 4.3
	var rz := HALF_L + 7.1
	var outside := func(x: float, z: float) -> bool:
		return absf(x) > rx or absf(z) > rz
	for end: float in [-1.0, 1.0]:
		add_child(CricketField.blades_node(Rect2(-rx - 3.0, (rz if end > 0 else -rz - 8.0), rx * 2.0 + 6.0, 8.0), outside))


func _lines() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.97, 0.97)
	white.roughness = 0.6
	var w := 0.05
	var y := 0.004
	for side: float in [-1.0, 1.0]:
		_box(Vector3(HALF_W_DOUBLES * 2 + w, 0.002, w * 2), Vector3(0, y, side * HALF_L), white) # baselines
		_box(Vector3(w, 0.002, HALF_L * 2), Vector3(side * HALF_W_DOUBLES, y, 0), white) # doubles sidelines
		_box(Vector3(w, 0.002, HALF_L * 2), Vector3(side * HALF_W_SINGLES, y, 0), white) # singles sidelines
		_box(Vector3(HALF_W_SINGLES * 2, 0.002, w), Vector3(0, y, side * SERVICE_Z), white) # service lines
		_box(Vector3(w, 0.002, 0.2), Vector3(0, y, side * (HALF_L - 0.1)), white) # centre marks
	_box(Vector3(w, 0.002, SERVICE_Z * 2), Vector3(0, y, 0), white) # centre service line


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _net() -> void:
	var span := HALF_W_DOUBLES + 0.914
	# mesh: a strip sagging from post height to the centre
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	for i in seg:
		var x0 := lerpf(-span, span, float(i) / seg)
		var x1 := lerpf(-span, span, float(i + 1) / seg)
		var h0 := net_height(x0)
		var h1 := net_height(x1)
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var quad := [[Vector3(x0, 0, 0), Vector2(u0, 1)], [Vector3(x1, 0, 0), Vector2(u1, 1)], [Vector3(x1, h1, 0), Vector2(u1, 1.0 - h1)], [Vector3(x0, h0, 0), Vector2(u0, 1.0 - h0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	st.generate_normals()
	var net := MeshInstance3D.new()
	net.mesh = st.commit()
	net.material_override = CricketField._shader_mat(NET_SHADER)
	add_child(net)
	# white tape along the top
	var tape_mat := StandardMaterial3D.new()
	tape_mat.albedo_color = Color(0.98, 0.98, 0.98)
	for i in seg:
		var x0 := lerpf(-span, span, float(i) / seg)
		var x1 := lerpf(-span, span, float(i + 1) / seg)
		var a := Vector3(x0, net_height(x0), 0)
		var b := Vector3(x1, net_height(x1), 0)
		var t := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(a.distance_to(b) + 0.01, 0.06, 0.02)
		t.mesh = bm
		t.material_override = tape_mat
		t.position = (a + b) * 0.5 - Vector3(0, 0.03, 0)
		t.rotation.z = atan2(b.y - a.y, b.x - a.x)
		add_child(t)
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.04
		pc.bottom_radius = 0.04
		pc.height = NET_POST
		post.mesh = pc
		post.material_override = CricketField._mat(Color("2f3a46"))
		post.position = Vector3(side * span, NET_POST * 0.5, 0)
		add_child(post)


func _surroundings() -> void:
	# low walls round the run-off with sponsor-style panels in our colours
	var wall_cols := [Color("2b6cb0"), Color("31b8e8"), Color("2b6cb0"), Color("1f5fae")]
	var rx := HALF_W_DOUBLES + 4.2
	var rz := HALF_L + 7.0
	var k := 0
	for z: float in [-rz, rz]:
		for i in 6:
			var x := lerpf(-rx, rx, (i + 0.5) / 6.0)
			_panel(Vector3(x, 0.5, z), Vector3(rx * 2.0 / 6.0 - 0.1, 1.0, 0.2), wall_cols[k % 4])
			k += 1
	for x: float in [-rx, rx]:
		for i in 8:
			var z := lerpf(-rz, rz, (i + 0.5) / 8.0)
			_panel(Vector3(x, 0.5, z), Vector3(0.2, 1.0, rz * 2.0 / 8.0 - 0.1), wall_cols[k % 4])
			k += 1
	# stands on the long sides, open ends with trees
	for side: float in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in 9:
			var x0 := side * (rx + 1.0 + row * 1.2)
			var y0 := 0.6 + row * 0.75
			var col := Color("24324a") if row % 2 == 0 else Color("8e99a6")
			var v := [Vector3(x0, y0, -rz), Vector3(x0, y0, rz), Vector3(x0 + side * 1.2, y0, rz), Vector3(x0 + side * 1.2, y0, -rz),
				Vector3(x0 + side * 1.2, y0 + 0.75, rz), Vector3(x0 + side * 1.2, y0 + 0.75, -rz)]
			st.set_color(col)
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(v[idx])
			st.set_color(Color("8e99a6"))
			for idx in [3, 2, 4, 3, 4, 5]:
				st.add_vertex(v[idx])
		st.generate_normals()
		var stand := MeshInstance3D.new()
		stand.mesh = st.commit()
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.roughness = 0.9
		stand.material_override = sm
		add_child(stand)
		_crowd(side, rx, rz)
	# umpire's chair at the net post
	var chair := Node3D.new()
	chair.position = Vector3(-(HALF_W_DOUBLES + 1.8), 0, 0)
	add_child(chair)
	for lx: float in [-0.3, 0.3]:
		for lz: float in [-0.3, 0.3]:
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.03
			lm.bottom_radius = 0.04
			lm.height = 1.8
			leg.mesh = lm
			leg.material_override = CricketField._mat(Color("e9edf1"))
			leg.position = Vector3(lx, 0.9, lz)
			chair.add_child(leg)
	var seat := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(0.8, 0.12, 0.8)
	seat.mesh = sbm
	seat.material_override = CricketField._mat(Color("2b6cb0"))
	seat.position = Vector3(0, 1.85, 0)
	chair.add_child(seat)
	var ump := Character.new()
	ump.shirt = Color("f2f2f2")
	ump.pants = Color("2b2f36")
	ump.outfit = "umpire"
	ump.hand_targets = true
	chair.add_child(ump)
	ump.position = Vector3(0, 1.0, 0)
	ump.rotation.y = -PI * 0.5
	ump.hand_r_world = chair.position + Vector3(0.3, 2.3, 0.3)
	ump.hand_l_world = chair.position + Vector3(0.3, 2.3, -0.3)
	# trees and hills beyond the ends
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 8
	for i in 26:
		var end := -1.0 if i % 2 == 0 else 1.0
		var x := rng2.randf_range(-40, 40)
		var z := end * rng2.randf_range(rz + 8, rz + 40)
		var s := rng2.randf_range(1.2, 2.4)
		var trunk := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.15 * s
		tc.bottom_radius = 0.22 * s
		tc.height = 2.2 * s
		trunk.mesh = tc
		trunk.material_override = CricketField._mat(Color("6b4a2b"))
		trunk.position = Vector3(x, 1.1 * s, z)
		add_child(trunk)
		var crown := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 1.6 * s
		cs.height = 3.0 * s
		crown.mesh = cs
		crown.material_override = CricketField._mat(Color(0.25, 0.52, 0.22).lightened(rng2.randf_range(0.0, 0.18)), 0.95)
		crown.position = Vector3(x, 3.2 * s, z)
		add_child(crown)
	for i in 7:
		var hill := MeshInstance3D.new()
		var hm := SphereMesh.new()
		var r := rng2.randf_range(18.0, 30.0)
		hm.radius = r
		hm.height = r * 2.0
		hill.mesh = hm
		hill.material_override = CricketField._mat(Color(0.33, 0.55, 0.28).lightened(rng2.randf_range(0.0, 0.1)), 1.0)
		hill.position = Vector3(rng2.randf_range(-90, 90), -r * 0.7, (-1.0 if i % 2 == 0 else 1.0) * rng2.randf_range(70, 100))
		add_child(hill)


func _panel(pos: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = CricketField._mat(c, 0.5)
	mi.position = pos
	add_child(mi)


## Seated spectators on one long side (shared Crowd builder).
func _crowd(side: float, rx: float, rz: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41 + int(side)
	var seats: Array[Vector3] = []
	var yaws := PackedFloat32Array()
	for row in 9:
		var x := side * (rx + 1.55 + row * 1.2)
		var y := 0.6 + row * 0.75
		var z := -rz + 0.5
		while z < rz - 0.5:
			if rng.randf() < 0.88:
				seats.append(Vector3(x, y, z + rng.randf_range(-0.06, 0.06)))
				yaws.append(side * PI * 0.5)
			z += 0.62
	Crowd.build(self, seats, yaws, 41 + int(side))


## Officials, ball kids, sponsor boards and the scoreboard.
var scoreboard: Label3D


func _extras() -> void:
	var rx := HALF_W_DOUBLES + 4.2
	var rz := HALF_L + 7.0
	# sponsor names on the end walls (facing the court)
	for zs: float in [-1.0, 1.0]:
		for i in 3:
			var x := lerpf(-rx, rx, (i * 2 + 1) / 6.0)
			var xf := Transform3D(Basis(Vector3.UP, PI if zs < 0 else 0.0), Vector3(x, 0.5, zs * (rz - 0.12)))
			Props.board(self, xf, Vector3(rx * 2.0 / 3.0 - 0.3, 0.8, 0.06), Color("1f5fae") if i != 1 else Color("31b8e8"), Props.BRANDS[(i + (3 if zs > 0 else 0)) % Props.BRANDS.size()])
	# line judges: by the sidelines near each baseline, and behind the baselines
	var seed := 300
	for zs: float in [-1.0, 1.0]:
		for xs: float in [-1.0, 1.0]:
			Props.official(self, Vector3(xs * (HALF_W_DOUBLES + 2.6), 0, zs * (HALF_L - 2.0)), Vector3(0, 0, zs * (HALF_L - 2.0)), Color("1f3a5f"), seed)
			seed += 1
		Props.official(self, Vector3(3.2, 0, zs * (HALF_L + 5.8)), Vector3(3.2, 0, 0), Color("1f3a5f"), seed)
		seed += 1
	# ball kids crouched at the net posts
	for xs: float in [-1.0, 1.0]:
		var kid := Props.official(self, Vector3(xs * (HALF_W_DOUBLES + 1.3), 0, 0.9 * xs), Vector3(0, 0, 0.9 * xs), Color("8d6fd6"), seed, 0.72)
		kid.crouch = 0.12
		seed += 1
	# scoreboard behind the far baseline
	scoreboard = Props.scoreboard(self, Vector3(-rx + 3.5, 4.2, -rz - 2.5), 0.0, Vector2(6.0, 2.6))


func set_scoreboard(text: String) -> void:
	if scoreboard:
		scoreboard.text = text
