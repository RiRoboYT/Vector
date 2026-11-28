class_name CricketField
extends Node3D
## The ground. Striker's stumps at z = 0, bowler's stumps at z = -20.12
## (22 yards). The batter faces -Z. Real dimensions in metres.

const PITCH_LEN := 20.12
const PITCH_HALF_W := 1.525
const CREASE := 1.22 # popping crease in front of the stumps
const BOWL_Z := -20.12
const CENTER := Vector3(0, 0, -10.06)
const BOUNDARY := 62.0
const CIRCLE := 27.43 # 30 yards from each middle stump
const STUMP_X := [-0.0968, 0.0, 0.0968]
const STUMP_H := 0.711

const GRASS_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 base_col : source_color = vec3(0.29, 0.47, 0.19);
uniform vec3 warm_col : source_color = vec3(0.42, 0.52, 0.22);
uniform vec3 cool_col : source_color = vec3(0.22, 0.42, 0.20);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec2 p = wpos.xz;
	// natural colour drift across the ground
	float n = fbm(p * 0.06);
	vec3 c = mix(cool_col, warm_col, smoothstep(0.3, 0.75, n));
	c = mix(c, base_col, 0.55);
	c *= 0.9 + 0.2 * fbm(p * 0.45);
	// mowing stripes: blades lie one way in each lane, so a lane looks light
	// when you look along the grain and dark against it (view dependent)
	float lane = floor(p.x / 6.0);
	float grain = mod(lane, 2.0) * 2.0 - 1.0;
	float edge = smoothstep(0.0, 0.35, min(fract(p.x / 6.0), 1.0 - fract(p.x / 6.0)) * 6.0);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float sheen = grain * v.z * edge;
	c *= 1.0 + sheen * 0.12;
	// fine texture, faded with distance so it never shimmers
	float aa = clamp(1.0 - length(fwidth(p)) * 25.0, 0.0, 1.0);
	float blades = noise(p * vec2(140.0, 55.0)) * 0.6 + noise(p * 35.0) * 0.4;
	c *= 1.0 + (blades - 0.5) * 0.28 * aa;
	// the odd darker clump
	c *= 1.0 - smoothstep(0.78, 0.95, noise(p * 3.1)) * 0.05 * aa;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3 + max(sheen, 0.0) * 0.3;
	float h = noise(p * 60.0);
	NORMAL_MAP = vec3(0.5 + (noise(p * 60.0 + vec2(0.3, 0.0)) - h) * 1.1 * aa, 0.5 + (noise(p * 60.0 + vec2(0.0, 0.3)) - h) * 1.1 * aa, 1.0);
}
"""

const PITCH_SHADER := """
shader_type spatial;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; } return v; }
void fragment() {
	vec2 p = wpos.xz;
	vec3 clay = vec3(0.70, 0.62, 0.45) * (0.85 + 0.25 * fbm(p * 1.7));
	// a thin covering of grass, thicker towards the edges of the strip
	float cover = 0.25 + 0.5 * smoothstep(0.7, 1.5, abs(p.x));
	cover *= 0.7 + 0.6 * fbm(p * 3.0);
	clay = mix(clay, vec3(0.46, 0.54, 0.30), clamp(cover, 0.0, 0.85));
	// dry, scuffed, lighter ends where the bowlers land and the batters stand
	float wear = (1.0 - smoothstep(0.0, 3.0, abs(p.y + 1.4))) + (1.0 - smoothstep(0.0, 3.0, abs(p.y + 18.7)));
	wear *= 1.0 - smoothstep(0.4, 1.2, abs(p.x));
	clay = mix(clay, vec3(0.78, 0.70, 0.54), clamp(wear, 0.0, 1.0) * 0.6 * (0.6 + 0.6 * fbm(p * 4.0)));
	// hairline cracks
	float aa = clamp(1.0 - length(fwidth(p)) * 30.0, 0.0, 1.0);
	float k = abs(noise(p * vec2(22.0, 14.0)) - 0.5);
	clay *= 1.0 - (1.0 - smoothstep(0.0, 0.018, k)) * 0.12 * aa;
	ALBEDO = clay;
	ROUGHNESS = 0.97;
	SPECULAR = 0.15;
}
"""

const BLADE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying float tip;
void vertex() {
	tip = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.8 + w.x * 0.9 + w.z * 0.7) * 0.012 * tip;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}
void fragment() {
	vec3 base = COLOR.rgb * 0.8;
	ALBEDO = mix(base, COLOR.rgb * 1.08, tip);
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.25, 0.4, 0.1);
}
"""

var striker_stumps: Stumps
var bowler_stumps: Stumps


static func inside_circle(p: Vector3) -> bool:
	var z := clampf(p.z, BOWL_Z, 0.0)
	return Vector2(p.x, p.z - z).length() <= CIRCLE


static func dist_from_center(p: Vector3) -> float:
	return Vector2(p.x - CENTER.x, p.z - CENTER.z).length()


static func on_pitch(p: Vector3) -> bool:
	return absf(p.x) <= PITCH_HALF_W and p.z <= 1.3 and p.z >= BOWL_Z - 1.3


func _ready() -> void:
	_environment()
	_ground()
	_pitch()
	_circle_and_rope()
	_stands()
	striker_stumps = Stumps.new()
	add_child(striker_stumps)
	bowler_stumps = Stumps.new()
	bowler_stumps.position.z = BOWL_Z
	add_child(bowler_stumps)


func _environment() -> void:
	Look.setup(self, "evening", 70.0)


func _ground() -> void:
	# physics floor for stumps / bails
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	sb.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.2
	sb.physics_material_override = pm
	add_child(sb)
	# mown outfield (stripes ~5 m)
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150, 150)
	grass.mesh = plane
	grass.material_override = _shader_mat(GRASS_SHADER)
	grass.position = CENTER
	add_child(grass)
	# real blades close to where the cameras sit: around the batter and the run-up
	var off_pitch := func(x: float, z: float) -> bool:
		return not (absf(x) < PITCH_HALF_W + 0.05 and z < 2.0 and z > BOWL_Z - 2.0)
	add_child(blades_node(Rect2(-9.0, -7.0, 18.0, 12.0), off_pitch))
	add_child(blades_node(Rect2(-6.0, BOWL_Z - 13.0, 12.0, 12.0), off_pitch))


func _pitch() -> void:
	var pitch := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(PITCH_HALF_W * 2, PITCH_LEN + 4.0)
	pitch.mesh = pm
	pitch.material_override = _shader_mat(PITCH_SHADER)
	pitch.position = Vector3(0, 0.004, CENTER.z)
	add_child(pitch)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.97, 0.95)
	white.roughness = 0.8
	for end_z in [0.0, BOWL_Z]:
		var toward := -1.0 if end_z == 0.0 else 1.0 # direction to the other end
		_line(Vector3(0, 0.006, end_z + toward * CREASE), Vector3(3.66, 0.002, 0.05), white) # popping crease
		_line(Vector3(0, 0.006, end_z), Vector3(2.64, 0.002, 0.05), white) # bowling crease
		for side in [-1.0, 1.0]: # return creases
			_line(Vector3(side * 1.32, 0.006, end_z + toward * CREASE * 0.5 - toward * 0.6), Vector3(0.05, 0.002, 2.44 + 1.2), white)


static func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Short, dense outfield blades (a few cm tall) as one MultiMesh.
## `keep(x, z)` decides where blades may grow.
static func blades_node(area: Rect2, keep: Callable) -> MultiMeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.004, 0, 0))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(0.004, 0, 0))
	st.set_uv(Vector2(0.5, 1))
	st.add_vertex(Vector3(0.001, 1, 0.002))
	st.generate_normals()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = st.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(area.position.y * 10.0) + 3
	var pts: Array[Transform3D] = []
	var cols: Array[Color] = []
	var density := 260.0
	var n := int(area.size.x * area.size.y * density)
	for i in n:
		var x := area.position.x + rng.randf() * area.size.x
		var z := area.position.y + rng.randf() * area.size.y
		if not keep.call(x, z):
			continue
		# thin out towards the edges of the patch so it blends into the turf
		var ex := minf(x - area.position.x, area.end.x - x)
		var ez := minf(z - area.position.y, area.end.y - z)
		if rng.randf() > clampf(minf(ex, ez) / 2.5, 0.0, 1.0):
			continue
		var h := rng.randf_range(0.025, 0.06)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		pts.append(Transform3D(b.scaled(Vector3(1, h, 1)), Vector3(x, 0, z)))
		var sw := clampf((absf(fmod(x / 7.0 + 100.0, 1.0) - 0.5) * 2.0 - 0.42) / 0.16, 0.0, 1.0)
		var turf := Color(0.27, 0.45, 0.19).lerp(Color(0.36, 0.52, 0.22), sw * 0.5 + rng.randf() * 0.3)
		cols.append(turf.darkened(rng.randf_range(-0.05, 0.12)))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := _shader_mat(BLADE_SHADER)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _line(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _circle_and_rope() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.97, 0.95)
	# inner circle: dashes around the oval
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dash := BoxMesh.new()
	dash.size = Vector3(0.6, 0.004, 0.12)
	mm.mesh = dash
	var pts: Array[Transform3D] = []
	var arc_steps := 40
	for end in [0, 1]:
		var cz := 0.0 if end == 0 else BOWL_Z
		var a0 := 0.0 if end == 0 else PI
		for i in arc_steps + 1:
			var a := a0 + PI * i / arc_steps
			var p := Vector3(cos(a) * CIRCLE, 0.007, cz + sin(a) * CIRCLE)
			pts.append(Transform3D(Basis(Vector3.UP, -a), p))
	for side in [-1.0, 1.0]:
		for k in 10:
			var z := lerpf(0.0, BOWL_Z, (k + 0.5) / 10.0)
			pts.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side * CIRCLE, 0.007, z)))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = white
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# boundary rope
	var rope := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = BOUNDARY - 0.07
	tm.outer_radius = BOUNDARY + 0.07
	tm.rings = 160
	tm.ring_segments = 8
	rope.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("2b7fe0")
	rope.material_override = rm
	rope.position = CENTER + Vector3(0, 0.07, 0)
	add_child(rope)
	# advertising boards just outside the rope
	var boards := MultiMesh.new()
	boards.transform_format = MultiMesh.TRANSFORM_3D
	boards.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 0.9, 0.15)
	boards.mesh = bm
	var n := 100
	boards.instance_count = n
	var cols := [Color("31b8e8"), Color("ffffff"), Color("ffb020"), Color("1a98c9")]
	for i in n:
		var a := TAU * i / n
		var p := CENTER + Vector3(cos(a) * (BOUNDARY + 4.0), 0.45, sin(a) * (BOUNDARY + 4.0))
		boards.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p))
		boards.set_instance_color(i, cols[i % cols.size()])
	# brand names on every other board (the rest stay plain colours)
	for i in range(0, n, 2):
		var a2 := TAU * i / n
		var p2 := CENTER + Vector3(cos(a2) * (BOUNDARY + 3.92), 0.45, sin(a2) * (BOUNDARY + 3.92))
		var l := Props.label(Props.BRANDS[(i / 2) % Props.BRANDS.size()], 96, Color.WHITE if i % 4 != 2 else Color("1f5fae"))
		l.pixel_size = 0.0045
		l.position = p2
		l.look_at_from_position(p2, CENTER + Vector3(0, 0.45, 0), Vector3.UP)
		l.rotate_object_local(Vector3.UP, PI) # Label3D reads from +Z
		add_child(l)
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = boards
	var bmat := StandardMaterial3D.new()
	bmat.vertex_color_use_as_albedo = true
	bmat.roughness = 0.5
	bmi.material_override = bmat
	add_child(bmi)
	# sight screens behind each end
	for z in [CENTER.z + BOUNDARY + 5.0, CENTER.z - BOUNDARY - 5.0]:
		var ss := MeshInstance3D.new()
		var sbm := BoxMesh.new()
		sbm.size = Vector3(16, 7, 0.3)
		ss.mesh = sbm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.96, 0.96, 0.96)
		ss.material_override = sm
		ss.position = Vector3(0, 3.5, z)
		add_child(ss)


## Stepped terraces all round with a coloured crowd (one MultiMesh, cheap).
func _stands() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r0 := BOUNDARY + 7.0
	var steps := 14
	var prof: Array[Vector2] = [Vector2(r0, 0.0)]
	for i in steps:
		var r := r0 + i * 1.6
		var y := 1.0 + i * 0.9
		prof.append(Vector2(r, y))
		prof.append(Vector2(r + 1.6, y))
	prof.append(Vector2(r0 + steps * 1.6 + 2.0, 1.0 + steps * 0.9 + 3.0))
	var seg := 96
	for j in prof.size() - 1:
		var a := prof[j]
		var b := prof[j + 1]
		var col := Color("24324a") if j % 2 == 0 else Color("8e99a6") # seat rows / concrete risers
		if j == 0:
			col = Color("2f9fd6")
		if j == prof.size() - 2:
			col = Color("e9edf1")
		for k in seg:
			var t0 := TAU * k / seg
			var t1 := TAU * (k + 1) / seg
			var v := [
				CENTER + Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x), CENTER + Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x),
				CENTER + Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x), CENTER + Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x),
			]
			st.set_color(col)
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(v[idx])
	st.generate_normals()
	var stands := MeshInstance3D.new()
	stands.mesh = st.commit()
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.roughness = 0.9
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	stands.material_override = sm
	add_child(stands)
	# crowd: real seats on each step, facing the middle
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var seats: Array[Vector3] = []
	var yaws := PackedFloat32Array()
	for row in steps - 1:
		var r := r0 + row * 1.6 + 0.8
		var y := 1.0 + row * 0.9
		var n := int(TAU * r / 0.74)
		for k in n:
			if rng.randf() < 0.72:
				var ang := TAU * (k + rng.randf_range(-0.1, 0.1)) / n
				seats.append(CENTER + Vector3(cos(ang) * r, y, sin(ang) * r))
				yaws.append(PI * 0.5 - ang) # -Z towards the centre
	Crowd.build(self, seats, yaws, 33, 1.2)
	# roof canopy over the stands (casts shade on the crowd)
	var roof_st := SurfaceTool.new()
	roof_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r_in := r0 + 4.0
	var r_out := r0 + steps * 1.6 + 3.0
	var y_in := 1.0 + steps * 0.9 + 9.0
	var y_out := 1.0 + steps * 0.9 + 6.0
	for k in seg:
		var t0 := TAU * k / seg
		var t1 := TAU * (k + 1) / seg
		var v := [
			CENTER + Vector3(cos(t0) * r_in, y_in, sin(t0) * r_in), CENTER + Vector3(cos(t1) * r_in, y_in, sin(t1) * r_in),
			CENTER + Vector3(cos(t1) * r_out, y_out, sin(t1) * r_out), CENTER + Vector3(cos(t0) * r_out, y_out, sin(t0) * r_out),
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			roof_st.add_vertex(v[idx])
	roof_st.generate_normals()
	var roof := MeshInstance3D.new()
	roof.mesh = roof_st.commit()
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("eef1f4")
	rmat.roughness = 0.6
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof.material_override = rmat
	add_child(roof)
	var edge := MeshInstance3D.new()
	var et := TorusMesh.new()
	et.inner_radius = r_in - 0.4
	et.outer_radius = r_in + 0.4
	et.rings = 128
	edge.mesh = et
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color("2f9fd6")
	edge.material_override = emat
	edge.position = CENTER + Vector3(0, y_in, 0)
	add_child(edge)
	for k in 24:
		var a := TAU * k / 24.0
		var col := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.25
		cc.bottom_radius = 0.35
		cc.height = y_out
		col.mesh = cc
		col.material_override = _mat(Color("c9ced4"))
		col.position = CENTER + Vector3(cos(a) * (r_out - 1.0), y_out * 0.5, sin(a) * (r_out - 1.0))
		add_child(col)
	# floodlight towers
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var base := CENTER + Vector3(cos(a), 0, sin(a)) * (r0 + steps * 1.6 + 4.0)
		var pole := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.5
		pc.bottom_radius = 0.9
		pc.height = 38.0
		pole.mesh = pc
		pole.material_override = _mat(Color("c9ced4"))
		pole.position = base + Vector3(0, 19, 0)
		add_child(pole)
		var head := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(7, 4, 0.6)
		head.mesh = hb
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color.WHITE
		hm.emission_enabled = true
		hm.emission = Color("fffbe8")
		hm.emission_energy_multiplier = 1.5
		head.material_override = hm
		head.position = base + Vector3(0, 39, 0)
		head.look_at_from_position(head.position, CENTER + Vector3(0, 10, 0))
		add_child(head)


static var _tex := {}


func _cached(key: String, make: Callable) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = make.call()
	return _tex[key]


func _grass_texture() -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := Color("4a9a3a")
	var b := Color("3f8a31")
	for y in n:
		for x in n:
			var c := a if (x / 64) % 2 == 0 else b
			c = c.darkened(rng.randf_range(0.0, 0.06)).lightened(rng.randf_range(0.0, 0.03))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _pitch_texture() -> ImageTexture:
	var w := 64
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for y in h:
		for x in w:
			var edge := minf(x, w - 1 - x) / 8.0
			var c := Color("c9b17e").lerp(Color("a9a062"), clampf(1.0 - edge, 0.0, 1.0) * 0.5)
			# worn patches where bowlers land the ball
			var yy := float(y) / h
			if absf(yy - 0.3) < 0.08 or absf(yy - 0.7) < 0.08:
				c = c.darkened(0.06)
			img.set_pixel(x, y, c.darkened(rng.randf_range(0.0, 0.05)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _mat(c: Color, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
