class_name Nature
extends RefCounted
## Stylised but detailed nature props, generated once and shared:
##  - broadleaf trees: tapered, slightly bent trunk with branches and a crown
##    of lumpy leaf clusters (darker underneath, sunlit on top)
##  - pines: layered, jagged tiers
##  - bushes, rocks and flower patches
## Leaves sway gently in the wind (vertex shader), so the scenes feel alive.

const LEAF_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, cull_disabled;
uniform float sway = 1.0;
varying float shade;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() {
	vec3 o = NODE_POSITION_WORLD;
	float h = max(VERTEX.y, 0.0);
	float phase = TIME * 1.3 + o.x * 0.35 + o.z * 0.27;
	float w = sway * 0.03 * h * (sin(phase) + 0.4 * sin(phase * 2.7 + VERTEX.x * 3.0));
	VERTEX.x += w;
	VERTEX.z += w * 0.6;
	shade = 0.9 + 0.2 * hash(floor(VERTEX * 9.0));
}
void fragment() {
	ALBEDO = COLOR.rgb * shade;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
"""

const BARK_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec3 bark : source_color = vec3(0.42, 0.29, 0.18);
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	// vertical bark grooves
	float a = atan(lp.x, lp.z);
	float g = 0.82 + 0.18 * smoothstep(0.2, 0.8, abs(sin(a * 9.0 + hash(vec2(floor(lp.y * 3.0), 1.0)) * 2.0)));
	ALBEDO = bark * g;
	ROUGHNESS = 0.95;
}
"""

const GREENS := [Color(0.2, 0.48, 0.14), Color(0.26, 0.54, 0.16), Color(0.33, 0.58, 0.17), Color(0.17, 0.43, 0.18), Color(0.4, 0.6, 0.18)]

static var _cache := {}
static var _leaf_mat: ShaderMaterial
static var _bark_mat: ShaderMaterial


static func _mats() -> void:
	if _leaf_mat == null:
		_leaf_mat = CricketField._shader_mat(LEAF_SHADER)
		_bark_mat = CricketField._shader_mat(BARK_SHADER)


## A broadleaf tree at `pos` (ground level). `variant` picks one of a few shapes.
static func tree(parent: Node, pos: Vector3, size := 1.0, variant := 0, shadows := true) -> MeshInstance3D:
	_mats()
	var key := "tree%d" % (variant % 5)
	if not _cache.has(key):
		_cache[key] = _make_tree(variant % 5)
	return _place(parent, _cache[key], pos, size, shadows)


static func pine(parent: Node, pos: Vector3, size := 1.0, variant := 0, shadows := true) -> MeshInstance3D:
	_mats()
	var key := "pine%d" % (variant % 3)
	if not _cache.has(key):
		_cache[key] = _make_pine(variant % 3)
	return _place(parent, _cache[key], pos, size, shadows)


static func bush(parent: Node, pos: Vector3, size := 1.0, variant := 0) -> MeshInstance3D:
	_mats()
	var key := "bush%d" % (variant % 3)
	if not _cache.has(key):
		_cache[key] = _make_bush(variant % 3)
	return _place(parent, _cache[key], pos, size, false)


static func rock(parent: Node, pos: Vector3, size := 1.0, variant := 0) -> MeshInstance3D:
	var key := "rock%d" % (variant % 4)
	if not _cache.has(key):
		_cache[key] = _make_rock(variant % 4)
	var mi := _place(parent, _cache[key], pos, size, true)
	mi.material_override = Character.material(Color(0.62, 0.6, 0.57), 0.95)
	return mi


## Scattered flowers (one MultiMesh) inside a circle.
static func flowers(parent: Node, center: Vector3, radius: float, count: int, seed := 1, keep := Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var head := SphereMesh.new()
	head.radius = 0.045
	head.height = 0.07
	head.radial_segments = 8
	head.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = head
	var cols := [Color(1, 1, 1), Color(1.0, 0.85, 0.2), Color(0.95, 0.45, 0.65), Color(0.6, 0.5, 0.95), Color(1.0, 0.55, 0.3)]
	var xf: Array[Transform3D] = []
	var cs: Array[Color] = []
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var p := center + Vector3(cos(a) * r, rng.randf_range(0.05, 0.12), sin(a) * r)
		if keep.is_valid() and not keep.call(p.x, p.z):
			continue
		xf.append(Transform3D(Basis.IDENTITY, p))
		cs.append(cols[rng.randi() % cols.size()])
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.7
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ------------------------------------------------------------ builders

static func _place(parent: Node, mesh: Mesh, pos: Vector3, size: float, shadows: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = Vector3.ONE * size
	mi.rotation.y = fposmod(pos.x * 1.7 + pos.z * 2.3, TAU)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _noise(seed: int, freq := 1.6) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n


## Adds a lumpy leaf blob (displaced sphere) with sunlit/shaded vertex colours.
static func _blob(st: SurfaceTool, center: Vector3, radius: Vector3, base: Color, noise: FastNoiseLite, crown_c: Vector3, crown_r: float) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 8
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out_v := PackedVector3Array()
	out_v.resize(verts.size())
	var out_c := PackedColorArray()
	out_c.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + noise.get_noise_3dv(v * 1.3 + center) * 0.35
		var p := center + v * radius * d
		out_v[i] = p
		# light from above, darker towards the inside / bottom of the crown
		var up := clampf(norms[i].y * 0.5 + 0.5, 0.0, 1.0)
		var outward := clampf((p - crown_c).length() / maxf(crown_r, 0.01), 0.0, 1.0)
		var k := 0.55 + 0.3 * up + 0.2 * outward
		out_c[i] = Color(base.r * k, base.g * k, base.b * k)
	for i in range(0, idx.size(), 3):
		for j in 3:
			var vi := idx[i + j]
			st.set_color(out_c[vi])
			st.add_vertex(out_v[vi])


static func _trunk(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, segs := 8) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := axis.cross(ref).normalized()
	var z := axis.cross(x).normalized()
	for i in segs:
		var t0 := TAU * i / segs
		var t1 := TAU * (i + 1) / segs
		var d0 := x * cos(t0) + z * sin(t0)
		var d1 := x * cos(t1) + z * sin(t1)
		var q := [a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1]
		for k in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(q[k])


static func _make_tree(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + variant * 31
	var noise := _noise(variant * 7 + 3)
	var h := rng.randf_range(2.6, 3.4)
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	# bark
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid := Vector3(0, h * 0.55, 0) + lean * 0.5
	var top := Vector3(0, h, 0) + lean
	_trunk(bark, Vector3.ZERO, mid, 0.2, 0.15)
	_trunk(bark, mid, top, 0.15, 0.08)
	# root flare
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		_trunk(bark, Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.32), Vector3(0, 0.45, 0), 0.07, 0.05, 5)
	var branch_tips: Array[Vector3] = [top]
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		var start := Vector3(0, h * rng.randf_range(0.55, 0.75), 0) + lean * 0.6
		var tip := start + Vector3(cos(a) * 1.0, rng.randf_range(0.6, 1.0), sin(a) * 1.0)
		_trunk(bark, start, tip, 0.08, 0.04, 6)
		branch_tips.append(tip)
	bark.generate_normals()
	# crown: clusters around the branch tips and the top
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown_c := top + Vector3(0, 0.3, 0)
	var crown_r := 2.0
	var base: Color = GREENS[variant % GREENS.size()]
	for tip in branch_tips:
		var r := rng.randf_range(0.85, 1.15) * (1.25 if tip == top else 1.0)
		_blob(leaves, tip + Vector3(0, 0.3, 0), Vector3(r, r * 0.85, r), base.lightened(rng.randf_range(-0.05, 0.08)), noise, crown_c, crown_r)
	for i in 5:
		var a := rng.randf() * TAU
		var p := crown_c + Vector3(cos(a) * rng.randf_range(0.4, 1.1), rng.randf_range(-0.3, 0.8), sin(a) * rng.randf_range(0.4, 1.1))
		var r2 := rng.randf_range(0.6, 0.9)
		_blob(leaves, p, Vector3(r2, r2 * 0.85, r2), base.lightened(rng.randf_range(-0.04, 0.1)), noise, crown_c, crown_r)
	leaves.generate_normals()
	var mesh := bark.commit()
	leaves.commit(mesh)
	mesh.surface_set_material(0, _bark_mat)
	mesh.surface_set_material(1, _leaf_mat)
	return mesh


static func _make_pine(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 400 + variant * 17
	var noise := _noise(variant * 5 + 11, 2.4)
	var h := rng.randf_range(3.6, 4.6)
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(bark, Vector3.ZERO, Vector3(0, h * 0.5, 0), 0.16, 0.1)
	bark.generate_normals()
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := 5
	var base := Color(0.17, 0.4, 0.24).lightened(variant * 0.04)
	for t in tiers:
		var k := float(t) / tiers
		var y0 := h * (0.25 + k * 0.62)
		var r := lerpf(1.35, 0.35, k)
		var tier_h := lerpf(1.3, 0.8, k)
		var segs := 12
		var apex := Vector3(0, y0 + tier_h, 0)
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			# jagged skirt: alternate long and short points
			var r0 := r * (1.0 + (0.18 if i % 2 == 0 else -0.08) + noise.get_noise_2d(t * 10.0, i) * 0.15)
			var r1 := r * (1.0 + (0.18 if (i + 1) % 2 == 0 else -0.08) + noise.get_noise_2d(t * 10.0, i + 1) * 0.15)
			var p0 := Vector3(cos(a0) * r0, y0 - 0.12, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r1, y0 - 0.12, sin(a1) * r1)
			var lit := base.lightened(0.12 + k * 0.1)
			var dark := base.darkened(0.25)
			leaves.set_color(dark)
			leaves.add_vertex(p0)
			leaves.set_color(lit)
			leaves.add_vertex(apex)
			leaves.set_color(dark)
			leaves.add_vertex(p1)
			# underside
			var inner := Vector3(0, y0 + 0.1, 0)
			leaves.set_color(dark.darkened(0.3))
			leaves.add_vertex(p0)
			leaves.add_vertex(p1)
			leaves.add_vertex(inner)
	leaves.generate_normals()
	var mesh := bark.commit()
	leaves.commit(mesh)
	mesh.surface_set_material(0, _bark_mat)
	mesh.surface_set_material(1, _leaf_mat)
	return mesh


static func _make_bush(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant
	var noise := _noise(variant + 21, 2.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base: Color = GREENS[(variant + 2) % GREENS.size()]
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf()
		var p := Vector3(cos(a) * 0.35, 0.35, sin(a) * 0.35)
		var r := rng.randf_range(0.38, 0.55)
		_blob(st, p, Vector3(r, r * 0.8, r), base.lightened(rng.randf_range(-0.05, 0.08)), noise, Vector3(0, 0.4, 0), 0.9)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _leaf_mat)
	return mesh


static func _make_rock(variant: int) -> ArrayMesh:
	var noise := _noise(variant * 13 + 5, 1.2)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 7
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in idx:
		var v := verts[i]
		var d := 1.0 + noise.get_noise_3dv(v * 1.5) * 0.45
		var p := v * d * Vector3(1.0, 0.6, 0.85)
		p.y = maxf(p.y, -0.15)
		st.add_vertex(p)
	st.generate_normals()
	return st.commit()
