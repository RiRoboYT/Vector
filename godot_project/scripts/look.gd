class_name Look
extends RefCounted
## Shared graphics look for every sport and the menus:
##  - Quality presets (Low / Medium / High), picked automatically on the first
##    launch from the graphics card and changeable in the menu.
##  - Cartoon sky with soft drifting clouds and a sun.
##  - One environment recipe (tonemap, colour grade, glow, ambient occlusion,
##    fog) with a colour grade per venue.
## Low:    no AO / glow, hard shadows, FXAA, 3D at 75 % on 1080p.
## Medium: glow, soft shadows, MSAA 2x.
## High:   + ambient occlusion and screen-space indirect light, MSAA 4x,
##         sharper 4096 shadow map. Tuned for a GTX 1050 class GPU at 1080p.

enum { LOW, MEDIUM, HIGH }
const NAMES := ["Low", "Medium", "High"]
const SETTINGS := "user://settings.cfg"

static var quality := -1
static var _envs: Array[Environment] = []
static var _suns: Array[DirectionalLight3D] = []


static func get_quality() -> int:
	if quality < 0 and OS.get_environment("VS_QUALITY") != "": # test override
		quality = clampi(int(OS.get_environment("VS_QUALITY")), LOW, HIGH)
	if quality < 0:
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS) == OK and cfg.has_section_key("graphics", "quality"):
			quality = clampi(int(cfg.get_value("graphics", "quality")), LOW, HIGH)
		else:
			quality = auto_detect()
	return quality


static func set_quality(q: int) -> void:
	quality = clampi(q, LOW, HIGH)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("graphics", "quality", quality)
	cfg.save(SETTINGS)
	for e in _envs.duplicate():
		if is_instance_valid(e):
			_apply_env(e)
	for s in _suns.duplicate():
		if is_instance_valid(s):
			_apply_sun(s)
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		apply_viewport(tree.root)


## Guess a preset from the GPU name.
static func auto_detect() -> int:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return LOW
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	if gpu.contains("llvmpipe") or gpu.contains("swiftshader") or gpu.contains("microsoft basic"):
		return LOW
	if vendor.contains("intel") or gpu.contains("intel"):
		return MEDIUM if (gpu.contains("arc") or gpu.contains("iris xe")) else LOW
	if gpu.contains("vega") and not gpu.contains("rx"):
		return MEDIUM # AMD integrated
	return HIGH


## Render scale and anti-aliasing for the main window (or a SubViewport).
static func apply_viewport(vp: Viewport) -> void:
	var q := get_quality()
	var h := DisplayServer.screen_get_size().y if vp is Window else 1080
	var scale := 1.0
	if h >= 2000:
		scale = [0.5, 0.58, 0.67][q]
	elif h >= 1400:
		scale = [0.66, 0.75, 0.85][q]
	elif q == LOW:
		scale = 0.8
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])


# ------------------------------------------------------------ environment

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.24, 0.5, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.86, 0.97);
uniform vec3 ground_color : source_color = vec3(0.36, 0.45, 0.34);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.78, 0.84, 0.93);
uniform float cloud_cover = 0.5;
uniform vec2 cloud_offset = vec2(0.0);
uniform float sun_glow = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.55;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	// sun: small bright disc with a wide warm halo
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * (pow(s, 900.0) * 6.0 + pow(s, 12.0) * 0.18 * sun_glow);
	}
	// soft cartoon clouds on a dome
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.55 + cloud_offset;
		float n = fbm(uv);
		float edge = 1.0 - cloud_cover;
		float c = smoothstep(edge, edge + 0.18, n) * smoothstep(0.0, 0.12, h);
		vec3 cc = mix(cloud_shade, cloud_color, smoothstep(edge, edge + 0.35, fbm(uv + vec2(0.04, 0.06))));
		col = mix(col, cc, c * 0.92);
	}
	COLOR = col;
}
"""

## Venue presets: sky colours, light and grading.
const PRESETS := {
	"day": {"top": Color(0.22, 0.5, 0.9), "horizon": Color(0.74, 0.86, 0.98), "ground": Color(0.36, 0.46, 0.32),
		"sun": Color(1.0, 0.95, 0.86), "sun_energy": 1.4, "sun_rot": Vector3(-46, 30, 0),
		"ambient": 0.6, "sat": 1.16, "contrast": 1.05, "bright": 1.0, "clouds": 0.48, "fog": Color(0.78, 0.86, 0.96)},
	"evening": {"top": Color(0.28, 0.42, 0.78), "horizon": Color(1.0, 0.8, 0.62), "ground": Color(0.34, 0.38, 0.3),
		"sun": Color(1.0, 0.84, 0.66), "sun_energy": 1.35, "sun_rot": Vector3(-34, 40, 0),
		"ambient": 0.55, "sat": 1.18, "contrast": 1.06, "bright": 1.0, "clouds": 0.45, "fog": Color(0.92, 0.84, 0.78)},
	"indoor": {"top": Color(0.95, 0.92, 0.86), "horizon": Color(0.95, 0.92, 0.86), "ground": Color(0.3, 0.28, 0.3),
		"sun": Color(1.0, 0.95, 0.88), "sun_energy": 0.75, "sun_rot": Vector3(-62, 12, 0),
		"ambient": 0.75, "sat": 1.12, "contrast": 1.06, "bright": 1.0, "clouds": 0.0, "fog": Color(0.95, 0.9, 0.84)},
	"menu": {"top": Color(0.4, 0.66, 0.96), "horizon": Color(0.86, 0.94, 1.0), "ground": Color(0.7, 0.84, 0.98),
		"sun": Color(1.0, 0.97, 0.9), "sun_energy": 1.25, "sun_rot": Vector3(-50, 35, 0),
		"ambient": 0.7, "sat": 1.12, "contrast": 1.02, "bright": 1.03, "clouds": 0.42, "fog": Color(0.86, 0.92, 1.0)},
}


## Builds WorldEnvironment + sun (+ drifting clouds) under `parent`.
## Returns the sun so the venue can tweak its shadow distance.
static func setup(parent: Node, preset := "day", shadow_distance := 60.0) -> DirectionalLight3D:
	var p: Dictionary = PRESETS[preset]
	var env := Environment.new()
	env.set_meta("preset", preset)
	if preset == "indoor":
		env.background_mode = Environment.BG_COLOR
		env.background_color = p.horizon
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("fff3e0")
	else:
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SKY_SHADER
		sm.shader = sh
		sm.set_shader_parameter("top_color", p.top)
		sm.set_shader_parameter("horizon_color", p.horizon)
		sm.set_shader_parameter("ground_color", p.ground)
		sm.set_shader_parameter("cloud_cover", p.clouds)
		var sky := Sky.new()
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.85
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		var drift := CloudDrift.new()
		drift.mat = sm
		parent.add_child(drift)
	env.ambient_light_energy = p.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = p.sat
	env.adjustment_contrast = p.contrast
	env.adjustment_brightness = p.bright
	env.glow_intensity = 0.3
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = preset != "indoor"
	env.fog_light_color = p.fog
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.0
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.6
	_apply_env(env)
	_envs.append(env)
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = p.sun_energy
	sun.light_color = p.sun
	sun.light_angular_distance = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = shadow_distance
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var r: Vector3 = p.sun_rot
	sun.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
	parent.add_child(sun)
	_apply_sun(sun)
	_suns.append(sun)
	return sun


static func _apply_env(env: Environment) -> void:
	var q := get_quality()
	var compat := RenderingServer.get_current_rendering_method() != "forward_plus"
	env.glow_enabled = q >= MEDIUM
	env.ssao_enabled = q == HIGH and not compat
	env.ssil_enabled = q == HIGH and not compat
	env.fog_enabled = env.get_meta("preset", "day") != "indoor"


static func _apply_sun(sun: DirectionalLight3D) -> void:
	var q := get_quality()
	sun.shadow_blur = [0.6, 1.1, 1.3][q]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == LOW else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


## Moves the cloud layer very slowly.
class CloudDrift:
	extends Node
	var mat: ShaderMaterial
	var _o := Vector2.ZERO

	func _process(delta: float) -> void:
		_o += Vector2(0.006, 0.0025) * delta
		mat.set_shader_parameter("cloud_offset", _o)
