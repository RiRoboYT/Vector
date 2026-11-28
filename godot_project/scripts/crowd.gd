class_name Crowd
extends RefCounted
## Seated spectators for stadiums: shirt-coloured body, head and hair per
## seat, three MultiMeshes in total so thousands stay cheap. They bob gently,
## and `Crowd.cheer()` makes the whole stand jump and wave for a moment.

const SHIRTS := [Color("e8574a"), Color("2b8fd6"), Color("f2f2f2"), Color("f0a020"), Color("3fae5d"), Color("2b2f36"), Color("8d6fd6"), Color("e86fa3"), Color("31b8e8"), Color("f5d33b")]
const SKINS := [Color(1.0, 0.84, 0.7), Color(0.94, 0.74, 0.58), Color(0.78, 0.56, 0.4), Color(0.55, 0.38, 0.26), Color(1.0, 0.88, 0.78)]
const HAIRS := [Color("2a2220"), Color("4a3328"), Color("7a5232"), Color("c8a060"), Color("1a1a1a"), Color("9a9a9a")]

const SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap;
global uniform float crowd_excite;
varying float shade;
void vertex() {
	float id = INSTANCE_CUSTOM.x;
	float cheer = step(0.82, fract(id * 7.31));
	float e = clamp(crowd_excite, 0.0, 1.0);
	float speed = 2.0 + cheer * 4.0 + e * 5.0;
	float amp = 0.015 + cheer * 0.05 + e * (0.12 + fract(id * 3.1) * 0.1);
	float hop = sin(TIME * speed + id * 31.0) * amp;
	VERTEX.y += max(hop, -0.01) / max(length(MODEL_MATRIX[1].xyz), 0.001);
	shade = 0.88 + fract(id * 3.7) * 0.12;
}
void fragment() {
	ALBEDO = COLOR.rgb * shade;
	ROUGHNESS = 0.85;
}
"""

static var _mat: ShaderMaterial
static var _excite := 0.0
static var _ticker: Ticker


## Each seat: position on the step (feet level) and the yaw that faces the field.
static func build(parent: Node, seats: Array[Vector3], yaws: PackedFloat32Array, seed := 1, scale := 1.0) -> void:
	_ensure_global()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 0.62
	body.radial_segments = 8
	body.rings = 2
	var head := SphereMesh.new()
	head.radius = 0.135
	head.height = 0.27
	head.radial_segments = 10
	head.rings = 6
	var hair := SphereMesh.new()
	hair.radius = 0.145
	hair.height = 0.17
	hair.is_hemisphere = true
	hair.radial_segments = 10
	hair.rings = 4
	var mms: Array[MultiMesh] = []
	for mesh: Mesh in [body, head, hair]:
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_colors = true
		m.use_custom_data = true
		m.mesh = mesh
		m.instance_count = seats.size()
		mms.append(m)
	for i in seats.size():
		var p := seats[i]
		var face := Basis(Vector3.UP, yaws[i]).scaled(Vector3.ONE * scale)
		var lean := Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08))
		var id := Color(rng.randf() * 100.0, 0, 0, 0)
		mms[0].set_instance_transform(i, Transform3D(face * lean, p + Vector3(0, 0.36, 0) * scale))
		mms[0].set_instance_color(i, SHIRTS[rng.randi() % SHIRTS.size()])
		mms[1].set_instance_transform(i, Transform3D(face, p + Vector3(0, 0.82, 0) * scale))
		mms[1].set_instance_color(i, SKINS[rng.randi() % SKINS.size()])
		mms[2].set_instance_transform(i, Transform3D(face, p + Vector3(0, 0.86, 0) * scale))
		mms[2].set_instance_color(i, HAIRS[rng.randi() % HAIRS.size()])
		for m in mms:
			m.set_instance_custom_data(i, id)
	for m in mms:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = m
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	if _ticker == null or not is_instance_valid(_ticker):
		_ticker = Ticker.new()
		parent.add_child(_ticker)


## Big moment: the crowd jumps up and cheers, then settles over ~3 s.
static func cheer(amount := 1.0) -> void:
	_excite = maxf(_excite, amount)


static func _ensure_global() -> void:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh


class Ticker:
	extends Node
	func _process(delta: float) -> void:
		Crowd._excite = maxf(0.0, Crowd._excite - delta * 0.35)
		RenderingServer.global_shader_parameter_set("crowd_excite", Crowd._excite)
