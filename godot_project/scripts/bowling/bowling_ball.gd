class_name BowlingBall
extends RigidBody3D
## 7 kg ball. Hook comes from `spin` (-1..1): a sideways push that grows on
## the dry back end of the lane, like a real ball biting after the oil.

const RADIUS := 0.109
const HOOK_ACCEL := 0.75 # m/s^2 at full spin on the dry part

var spin := 0.0
var rolling := false


func _init() -> void:
	mass = 7.0
	continuous_cd = true
	can_sleep = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.012 # a real ball loses only ~10% speed down the lane
	angular_damp = 0.0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.2
	pm.bounce = 0.05
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = RADIUS
	cs.shape = sp
	add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2
	sm.radial_segments = 72
	sm.rings = 36
	mi.mesh = sm
	mi.material_override = _marble_material()
	add_child(mi)
	# finger holes: dark recessed discs sitting flush with the surface
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color = Color("0b0f1a")
	hole_mat.roughness = 0.9
	for d in [Vector3(0.0, 0.93, 0.37), Vector3(-0.13, 0.975, -0.18), Vector3(0.13, 0.975, -0.18)]:
		var n: Vector3 = d.normalized()
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		var r := 0.0125 if d.z > 0.0 else 0.0105
		hm.top_radius = r
		hm.bottom_radius = r
		hm.height = 0.004
		hm.radial_segments = 32
		h.mesh = hm
		h.material_override = hole_mat
		var x := n.cross(Vector3.FORWARD).normalized()
		h.transform = Transform3D(Basis(x, n, x.cross(n)), n * (RADIUS - 0.0012))
		add_child(h)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC


func hold(at: Vector3) -> void:
	freeze = true
	rolling = false
	spin = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = at


func launch(from: Vector3, velocity: Vector3) -> void:
	global_position = from
	freeze = false
	linear_velocity = velocity
	# start rolling (no skid) so the line is predictable
	angular_velocity = Vector3.UP.cross(velocity) / RADIUS
	rolling = true


func _physics_process(_delta: float) -> void:
	if freeze or not rolling:
		return
	var p := global_position
	var on_lane := absf(p.x) < BowlingLane.LANE_HALF and p.y > RADIUS * 0.5 and p.z < -1.0 and p.z > -BowlingLane.LANE_LEN + 0.3
	if on_lane and absf(spin) > 0.01:
		# oil on the first ~10 m: little hook; dry back end: full hook
		var dry := clampf((-p.z - 8.0) / 6.0, 0.0, 1.0)
		var push := spin * HOOK_ACCEL * (0.15 + 0.85 * dry)
		apply_central_force(Vector3(push * mass, 0, 0))


const MARBLE_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.05, 0.22, 0.62);
uniform vec3 mid : source_color = vec3(0.16, 0.55, 0.95);
uniform vec3 light : source_color = vec3(0.62, 0.88, 1.0);
varying vec3 opos;

void vertex() {
	opos = VERTEX * 19.0; // object space: swirl turns with the ball
}

float swirl(vec3 p) {
	p += 0.9 * vec3(sin(p.y * 0.9 + p.z * 0.5), sin(p.z * 1.1 + p.x * 0.6), sin(p.x * 0.8 + p.y * 0.4));
	p += 0.45 * vec3(sin(p.y * 2.1 + 1.3), sin(p.z * 1.9 + 2.1), sin(p.x * 2.3 + 0.7));
	return sin(p.x * 1.2 + p.y * 0.8 + p.z * 1.0);
}

void fragment() {
	float a = swirl(opos);
	float b = swirl(opos * 1.6 + vec3(3.1, 1.7, 0.4));
	float fine = swirl(opos * 3.3 + vec3(0.7, 2.2, 1.1));
	vec3 c = mix(deep, mid, smoothstep(-0.5, 0.5, a));
	c = mix(c, light, smoothstep(0.6, 0.92, b) * 0.85);
	c = mix(c, deep * 0.7, smoothstep(0.75, 0.98, fine) * 0.5); // thin dark veins
	ALBEDO = c;
	// polished shell: soft reflection of the ceiling lights + edge sheen
	vec3 r = reflect(-VIEW, NORMAL);
	float lights = smoothstep(0.45, 0.85, r.y) * (0.6 + 0.4 * smoothstep(0.2, 0.5, abs(sin(r.x * 6.0))));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(1.0, 0.98, 0.94) * lights * 0.22 + light * fres * 0.25;
	ROUGHNESS = 0.07;
	SPECULAR = 0.75;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;
	RIM = 0.15;
	RIM_TINT = 0.6;
}
"""

static var _marble: ShaderMaterial


static func _marble_material() -> ShaderMaterial:
	if _marble == null:
		var sh := Shader.new()
		sh.code = MARBLE_SHADER
		_marble = ShaderMaterial.new()
		_marble.shader = sh
	return _marble
