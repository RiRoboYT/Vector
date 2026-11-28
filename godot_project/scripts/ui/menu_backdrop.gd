class_name MenuBackdrop
extends Node3D
## Live 3D scene behind the menus: a little floating island in the sky with
## a mini tennis court, a bowling lane and a cricket pitch, trees, drifting
## clouds and a few people who wave and cheer. The camera orbits slowly.

var _cam: Camera3D
var _t := 0.0
var _people: Array[Character] = []
var _clouds: Array[Node3D] = []
var _next_cheer := 2.0


func _ready() -> void:
	Look.setup(self, "menu", 40.0)
	_island()
	_tennis(Vector3(-4.5, 0, -1.5))
	_bowling(Vector3(4.6, 0, -2.0))
	_cricket(Vector3(0.5, 0, 4.6))
	_trees()
	_sky_clouds()
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.far = 400.0
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	var a := _t * 0.06 + 0.6
	var pos := Vector3(sin(a) * 37.0, 17.0 + sin(_t * 0.2) * 0.8, cos(a) * 37.0)
	_cam.look_at_from_position(pos, Vector3(0, 5.0, 0))
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += delta * (0.4 + i * 0.05)
		if c.position.x > 60.0:
			c.position.x = -60.0
	_next_cheer -= delta
	if _next_cheer <= 0.0 and not _people.is_empty():
		_people[randi() % _people.size()].react("cheer", 1.6)
		_next_cheer = randf_range(1.5, 3.5)


func _mat(c: Color, rough := 0.7) -> StandardMaterial3D:
	return Character.material(c, rough)


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


const ISLAND_R := 14.0


func _edge_r(a: float) -> float:
	return ISLAND_R + sin(a * 3.0) * 0.6 + sin(a * 7.0 + 1.3) * 0.35 + sin(a * 13.0) * 0.15


func _on_island(x: float, z: float, margin := 0.6) -> bool:
	var a := atan2(z, x)
	return Vector2(x, z).length() < _edge_r(a) - margin and Vector2(x - POND.x, z - POND.z).length() > 2.3


const POND := Vector3(-3.5, 0, 7.2)


func _island() -> void:
	# grassy top with a wavy natural edge
	var seg := 96
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		top.set_uv(Vector2(0.5, 0.5))
		top.add_vertex(Vector3.ZERO)
		top.add_vertex(Vector3(cos(a0) * _edge_r(a0), 0, sin(a0) * _edge_r(a0)))
		top.add_vertex(Vector3(cos(a1) * _edge_r(a1), 0, sin(a1) * _edge_r(a1)))
	top.generate_normals()
	var grass := MeshInstance3D.new()
	grass.mesh = top.commit()
	grass.material_override = CricketField._shader_mat("""
shader_type spatial;
render_mode diffuse_lambert_wrap;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = noise(wp.xz * 0.35) * 0.6 + noise(wp.xz * 1.7) * 0.3 + noise(wp.xz * 9.0) * 0.1;
	ALBEDO = mix(vec3(0.24, 0.52, 0.17), vec3(0.42, 0.7, 0.25), n);
	ROUGHNESS = 0.9;
}
""")
	add_child(grass)
	# rocky cliff: earth lip, then layered stone tapering to a point
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 0.25
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [[0.0, 1.0], [-0.5, 1.0], [-1.6, 0.97], [-3.2, 0.86], [-5.5, 0.66], [-8.0, 0.42], [-10.5, 0.2], [-12.5, 0.04]]
	var cols := [Color("5b8a3a"), Color("7a5a3c"), Color("8a6b4e"), Color("9b8470"), Color("7f6a58"), Color("8d7a69"), Color("6e5c4e"), Color("6e5c4e")]
	for r in rings.size() - 1:
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var q := []
			for pair in [[a0, r], [a1, r], [a1, r + 1], [a0, r + 1]]:
				var ang: float = pair[0]
				var ri: int = pair[1]
				var y: float = rings[ri][0]
				var k: float = rings[ri][1]
				var jag := 1.0 + (noise.get_noise_2d(ang * 8.0, y) * 0.22 if ri > 1 else 0.0)
				var rad := _edge_r(ang) * k * jag
				q.append(Vector3(cos(ang) * rad, y + (noise.get_noise_2d(ang * 20.0, y * 3.0) * 0.4 if ri > 1 else 0.0), sin(ang) * rad))
			for idx in [0, 1, 2, 0, 2, 3]:
				var ri2: int = r if idx < 2 else r + 1
				st_col(cliff, cols[ri2].darkened(0.08 * float((i * 7 + r) % 3)))
				cliff.add_vertex(q[idx])
	cliff.generate_normals()
	var cmi := MeshInstance3D.new()
	cmi.mesh = cliff.commit()
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.95
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	cmi.material_override = cm
	add_child(cmi)
	# a little pond
	var pond := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 2.2
	pm.bottom_radius = 2.2
	pm.height = 0.02
	pm.radial_segments = 48
	pond.mesh = pm
	pond.material_override = CricketField._shader_mat("""
shader_type spatial;
render_mode specular_schlick_ggx;
void fragment() {
	vec2 p = UV * 14.0;
	float rip = sin(p.x * 3.0 + TIME * 1.5) * sin(p.y * 2.6 - TIME * 1.2);
	NORMAL = normalize(NORMAL + vec3(rip * 0.06, 0.0, rip * 0.05));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(vec3(0.12, 0.42, 0.62), vec3(0.6, 0.85, 1.0), fres);
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
}
""")
	pond.position = POND + Vector3(0, 0.012, 0)
	add_child(pond)
	for i in 9:
		var a := TAU * i / 9.0
		Nature.rock(self, POND + Vector3(cos(a) * 2.35, 0.0, sin(a) * 2.35), randf_range(0.18, 0.32), i)
	# grass blades all over the island
	add_child(CricketField.blades_node(Rect2(-14, -14, 28, 28), func(x: float, z: float) -> bool: return _on_island(x, z, 0.3)))


func st_col(st: SurfaceTool, c: Color) -> void:
	st.set_color(c)


func _person(pos: Vector3, shirt: Color, outfit: String, face: Vector3, seed: int) -> Character:
	var c := Character.new()
	c.shirt = shirt
	c.outfit = outfit
	c.look_seed = seed
	c.pants = Color(0.95, 0.95, 0.95) if outfit != "bowling" else Color("2b2f45")
	add_child(c)
	c.position = pos
	c.look_at(Vector3(face.x, pos.y, face.z), Vector3.UP)
	_people.append(c)
	return c


func _tennis(o: Vector3) -> void:
	var root := Node3D.new()
	root.position = o
	root.rotation.y = 0.5
	add_child(root)
	_box(Vector3(5.6, 0.04, 9.0), Vector3(0, 0.02, 0), Color("2e8b57"), root)
	_box(Vector3(4.2, 0.05, 7.6), Vector3(0, 0.03, 0), Color("2f6fc4"), root)
	for z: float in [-3.78, 0.0, 3.78]:
		_box(Vector3(4.2, 0.06, 0.05) if z != 0.0 else Vector3(0.05, 0.06, 4.2), Vector3(0, 0.035, z if z != 0.0 else 0.0), Color.WHITE, root)
	for x: float in [-2.08, 2.08]:
		_box(Vector3(0.05, 0.06, 7.6), Vector3(x, 0.035, 0), Color.WHITE, root)
	_box(Vector3(4.6, 0.5, 0.03), Vector3(0, 0.3, 0), Color("1d2430"), root)
	_box(Vector3(4.6, 0.05, 0.05), Vector3(0, 0.56, 0), Color.WHITE, root)
	var p1 := _person(o + Basis(Vector3.UP, 0.5) * Vector3(0.8, 0, 2.6), Color("2f8fe0"), "tennis", o, 11)
	var p2 := _person(o + Basis(Vector3.UP, 0.5) * Vector3(-0.6, 0, -2.8), Color("ff7a3d"), "tennis", o, 12)
	for p in [p1, p2]:
		p.hand_targets = true
		p.hand_r_world = p.global_position + Vector3(0.3, 1.0, 0.0)
		p.hand_l_world = p.global_position + Vector3(-0.3, 1.0, 0.0)


func _bowling(o: Vector3) -> void:
	var root := Node3D.new()
	root.position = o
	root.rotation.y = -0.45
	add_child(root)
	_box(Vector3(1.4, 0.12, 8.0), Vector3(0, 0.06, 0), Color("e8c88f"), root)
	_box(Vector3(0.25, 0.1, 8.0), Vector3(-0.82, 0.05, 0), Color("8d949e"), root)
	_box(Vector3(0.25, 0.1, 8.0), Vector3(0.82, 0.05, 0), Color("8d949e"), root)
	var spots := [Vector2(0, 0), Vector2(-0.15, -0.26), Vector2(0.15, -0.26), Vector2(-0.3, -0.52), Vector2(0, -0.52), Vector2(0.3, -0.52), Vector2(-0.45, -0.78), Vector2(-0.15, -0.78), Vector2(0.15, -0.78), Vector2(0.45, -0.78)]
	for s: Vector2 in spots:
		var pin := MeshInstance3D.new()
		pin.mesh = BowlingPin.mesh()
		pin.material_override = BowlingPin.material()
		pin.position = Vector3(s.x, 0.12, -2.6 + s.y)
		root.add_child(pin)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	ball.mesh = sm
	ball.material_override = _mat(Color("2b6cb0"), 0.15)
	ball.position = Vector3(0.1, 0.23, 1.2)
	root.add_child(ball)
	var b := _person(o + Basis(Vector3.UP, -0.45) * Vector3(0.2, 0.12, 3.4), Color("e8574a"), "bowling", o + Basis(Vector3.UP, -0.45) * Vector3(0, 0, -4), 21)
	b.bowling = true
	b.swing_angle = 0.5


func _cricket(o: Vector3) -> void:
	_box(Vector3(1.6, 0.03, 8.0), o + Vector3(0, 0.015, 0), Color("d8c597"))
	for z: float in [-3.6, 3.6]:
		for x: float in [-0.1, 0.0, 0.1]:
			_box(Vector3(0.035, 0.7, 0.035), o + Vector3(x, 0.35, z), Color("f2e3c0"))
	var bat := _person(o + Vector3(0.45, 0, 3.0), Color("2f8fe0"), "cricket", o + Vector3(0.45, 0, -3), 31)
	bat.hand_targets = true
	bat.hand_r_world = bat.global_position + Vector3(-0.25, 0.9, -0.2)
	bat.hand_l_world = bat.global_position + Vector3(-0.2, 1.0, -0.2)
	_person(o + Vector3(-0.3, 0, -4.8), Color("ff7a3d"), "cricket", o, 32)


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# a ring of mixed trees round the edge, a few inside, bushes and rocks
	for i in 26:
		var a := TAU * i / 26.0 + rng.randf_range(-0.08, 0.08)
		var r := _edge_r(a) - rng.randf_range(1.0, 2.6)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if Vector2(p.x - POND.x, p.z - POND.z).length() < 3.0:
			continue
		if rng.randf() < 0.35:
			Nature.pine(self, p, rng.randf_range(0.75, 1.05), i)
		else:
			Nature.tree(self, p, rng.randf_range(0.75, 1.1), i)
	for i in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, 12.5)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if not _on_island(p.x, p.z, 1.0) or _busy(p):
			continue
		if i % 3 == 0:
			Nature.rock(self, p, rng.randf_range(0.2, 0.45), i)
		else:
			Nature.bush(self, p, rng.randf_range(0.55, 0.9), i)
	Nature.flowers(self, Vector3.ZERO, 13.0, 900, 7, func(x: float, z: float) -> bool: return _on_island(x, z, 0.8) and not _busy(Vector3(x, 0, z)))


## Keep props off the mini courts.
func _busy(p: Vector3) -> bool:
	for c: Vector3 in [Vector3(-4.5, 0, -1.5), Vector3(4.6, 0, -2.0), Vector3(0.5, 0, 4.6)]:
		if Vector2(p.x - c.x, p.z - c.z).length() < 4.2:
			return true
	return false


func _sky_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var white := _mat(Color(1, 1, 1), 1.0)
	for i in 10:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-60, 60), rng.randf_range(-10, 8), rng.randf_range(-50, 50))
		if Vector2(c.position.x, c.position.z).length() < 20.0:
			c.position.z += 30.0
		add_child(c)
		for k in 4:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var s := rng.randf_range(1.5, 3.2)
			sm.radius = s
			sm.height = s * 1.6
			puff.mesh = sm
			puff.material_override = white
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puff.position = Vector3(k * 2.2 - 3.0, rng.randf_range(-0.4, 0.6), rng.randf_range(-1, 1))
			c.add_child(puff)
		_clouds.append(c)
