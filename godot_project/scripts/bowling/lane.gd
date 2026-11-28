class_name BowlingLane
extends Node3D
## Builds the alley: playable lane with physics, decorative neighbour lanes,
## pin deck, pit, masking panel and lighting. Lane runs along -Z, foul line
## at z = 0, head pin at z = -18.29 (60 ft). Units are metres.

const LANE_HALF := 0.525 # 41.5 in wide lane
const GUTTER_W := 0.24
const LANE_LEN := 18.29
const DECK_END := 19.15
const PIN_SPACING := 0.3048
const LANE_PITCH := 2.1 # distance between neighbouring lanes

static var PIN_SPOTS: Array[Vector3] = _pin_spots()

var lane_mat: StandardMaterial3D
static var _tex_cache := {}


static func _pin_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var row_dz := PIN_SPACING * 0.866
	var rows := [[0.0], [-0.5, 0.5], [-1.0, 0.0, 1.0], [-1.5, -0.5, 0.5, 1.5]]
	for r in rows.size():
		for xi in rows[r]:
			out.append(Vector3(xi * PIN_SPACING, 0.0, -LANE_LEN - r * row_dz))
	return out # index 0 = pin 1 (head pin), 1-2 = pins 2-3, ...


func _ready() -> void:
	lane_mat = StandardMaterial3D.new()
	lane_mat.albedo_texture = _cached("lane", _lane_texture)
	lane_mat.roughness = 0.12 # freshly oiled: glossy, reflects the pins and lights
	lane_mat.metallic_specular = 0.75
	lane_mat.clearcoat_enabled = true
	lane_mat.clearcoat = 0.6
	lane_mat.clearcoat_roughness = 0.08
	lane_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	_build_environment()
	_build_physics()
	for k in [-2, -1, 1, 2]:
		_build_lane_visual(k * LANE_PITCH, true)
	_build_lane_visual(0.0, false)
	_build_hall()
	_build_extras()


# ---------------------------------------------------------------- physics

func _build_physics() -> void:
	var oily := PhysicsMaterial.new()
	oily.friction = 0.04
	oily.bounce = 0.05
	var wall := PhysicsMaterial.new()
	wall.friction = 0.4
	wall.bounce = 0.35
	var cushion := PhysicsMaterial.new()
	cushion.friction = 1.0
	cushion.bounce = 0.0
	cushion.absorbent = true

	# approach + lane (oiled) and pin deck (dry)
	_static_box(Vector3(LANE_HALF * 2 + 2 * GUTTER_W + 0.2, 0.2, 6.0), Vector3(0, -0.1, 3.0 + 0.001), oily)
	# one continuous surface: a seam would make the ball hop over the pins
	_static_box(Vector3(LANE_HALF * 2, 0.2, DECK_END), Vector3(0, -0.1, -DECK_END * 0.5), oily)
	# gutters (lower than the lane) + outer walls
	for side in [-1.0, 1.0]:
		var gx: float = side * (LANE_HALF + GUTTER_W * 0.5)
		_static_box(Vector3(GUTTER_W, 0.1, DECK_END), Vector3(gx, -0.13, -DECK_END * 0.5), wall)
		_static_box(Vector3(0.1, 0.9, DECK_END), Vector3(side * (LANE_HALF + GUTTER_W + 0.05), 0.35, -DECK_END * 0.5), wall)
		# kickbacks beside the pin deck
		_static_box(Vector3(0.06, 1.0, 3.5), Vector3(side * (LANE_HALF + GUTTER_W + 0.03), 0.4, -LANE_LEN - 1.2), wall)
	# pit + back cushion
	_static_box(Vector3(3.0, 0.2, 2.5), Vector3(0, -0.5, -DECK_END - 1.25), cushion)
	_static_box(Vector3(3.0, 1.6, 0.2), Vector3(0, 0.3, -DECK_END - 1.6), cushion)


func _static_box(size: Vector3, pos: Vector3, mat: PhysicsMaterial) -> void:
	var sb := StaticBody3D.new()
	sb.physics_material_override = mat
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)


# ---------------------------------------------------------------- visuals

func _build_lane_visual(x: float, with_pins: bool) -> void:
	var root := Node3D.new()
	root.position.x = x
	add_child(root)
	var total := DECK_END + 0.0
	# lane surface (foul line to end of deck)
	var lane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(LANE_HALF * 2, total)
	lane.mesh = pm
	lane.material_override = lane_mat
	lane.position = Vector3(0, 0.001, -total * 0.5)
	root.add_child(lane)
	# approach
	var app := MeshInstance3D.new()
	var am := PlaneMesh.new()
	am.size = Vector2(LANE_HALF * 2 + GUTTER_W * 2, 6.0)
	app.mesh = am
	app.material_override = _mat(Color("e3c48e"), 0.35)
	app.position = Vector3(0, 0.0, 3.0)
	root.add_child(app)
	# foul line
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(LANE_HALF * 2 + GUTTER_W * 2, 0.004, 0.025)
	fl.mesh = fm
	fl.material_override = _mat(Color("3a3a3a"), 0.6)
	fl.position = Vector3(0, 0.002, 0)
	root.add_child(fl)
	# gutters: rounded channels
	for side in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = GUTTER_W * 0.5
		cm.bottom_radius = GUTTER_W * 0.5
		cm.height = total
		cm.radial_segments = 24
		g.mesh = cm
		g.material_override = _mat(Color("8d949e"), 0.35, 0.4)
		g.rotation.x = PI * 0.5
		g.position = Vector3(side * (LANE_HALF + GUTTER_W * 0.5), -0.03, -total * 0.5)
		g.scale = Vector3(1, 1, 0.45)
		root.add_child(g)
	# capping between lanes
	for side in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.36, 0.06, total + 6.0)
		cap.mesh = cb
		cap.material_override = _mat(Color("7b5236"), 0.4)
		cap.position = Vector3(side * (LANE_PITCH * 0.5), 0.03, -total * 0.5 + 3.0)
		root.add_child(cap)
	# side walls by the deck
	for side in [-1.0, 1.0]:
		var kb := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.05, 0.9, 3.4)
		kb.mesh = km
		kb.material_override = _mat(Color("2c3a52"), 0.5)
		kb.position = Vector3(side * (LANE_HALF + GUTTER_W + 0.03), 0.45, -LANE_LEN - 1.2)
		root.add_child(kb)
	# dark pit
	var pit := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(LANE_HALF * 2 + GUTTER_W * 2, 1.2, 0.05)
	pit.mesh = pb
	pit.material_override = _mat(Color("1d2433"), 0.9)
	pit.position = Vector3(0, 0.45, -DECK_END - 1.55)
	root.add_child(pit)
	if with_pins:
		for p in PIN_SPOTS:
			var mi := MeshInstance3D.new()
			mi.mesh = BowlingPin.mesh()
			mi.material_override = BowlingPin.material()
			mi.position = p
			root.add_child(mi)


func _build_hall() -> void:
	# masking panel above the pins across all lanes
	var mask := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(LANE_PITCH * 5 + 0.4, 1.3, 0.12)
	mask.mesh = mb
	mask.material_override = _mat(Color("2f9fd6"), 0.5)
	mask.position = Vector3(0, 1.75, -LANE_LEN - 1.0)
	add_child(mask)
	var trim := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(LANE_PITCH * 5 + 0.4, 0.1, 0.16)
	trim.mesh = tb
	trim.material_override = _mat(Color("f4f6f8"), 0.4)
	trim.position = Vector3(0, 1.08, -LANE_LEN - 0.98)
	add_child(trim)
	for k in [-2, -1, 0, 1, 2]:
		# a round white light badge per lane
		var badge := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.22
		cm.height = 0.02
		badge.mesh = cm
		var bm := _mat(Color.WHITE, 0.3)
		bm.emission_enabled = true
		bm.emission = Color("fff6d8")
		bm.emission_energy_multiplier = 0.6
		badge.material_override = bm
		badge.rotation.x = PI * 0.5
		badge.position = Vector3(k * LANE_PITCH, 1.85, -LANE_LEN - 0.93)
		add_child(badge)
	# back wall, side walls, ceiling
	var back := MeshInstance3D.new()
	var bk := BoxMesh.new()
	bk.size = Vector3(30, 8, 0.2)
	back.mesh = bk
	back.material_override = _mat(Color("e9dcc2"), 0.9)
	back.position = Vector3(0, 4, -DECK_END - 1.9)
	add_child(back)
	var ceil := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(30, 0.2, 40)
	ceil.mesh = cbm
	ceil.material_override = _mat(Color("f7f3ea"), 0.9)
	ceil.position = Vector3(0, 4.2, -8)
	add_child(ceil)
	for i in 7:
		var lp := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(9, 0.04, 0.5)
		lp.mesh = lb
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color.WHITE
		lm.emission_enabled = true
		lm.emission = Color("fffaf0")
		lm.emission_energy_multiplier = 1.4
		lp.material_override = lm
		lp.position = Vector3(0, 4.08, 2.0 - i * 3.2)
		add_child(lp)
	# side walls: panelled, textured
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = _cached("wall", _wall_texture)
	wall_mat.roughness = 0.85
	wall_mat.uv1_scale = Vector3(10, 1, 1)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for side in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(40, 4.4)
		wall.mesh = q
		wall.material_override = wall_mat
		wall.position = Vector3(side * 5.8, 2.0, -8)
		wall.rotation.y = -side * PI * 0.5
		add_child(wall)
	# back wall above the pinsetters, same panels
	var back_mat := wall_mat.duplicate() as StandardMaterial3D
	back_mat.uv1_scale = Vector3(3, 1, 1)
	var bw := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(12, 4.4)
	bw.mesh = bq
	bw.material_override = back_mat
	bw.position = Vector3(0, 2.0, -DECK_END - 1.75)
	add_child(bw)
	# floor around
	var floor := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(30, 12)
	floor.mesh = fm
	var carpet := StandardMaterial3D.new()
	carpet.albedo_texture = _cached("carpet", _carpet_texture)
	carpet.roughness = 1.0
	carpet.uv1_scale = Vector3(15, 20, 1)
	floor.material_override = carpet
	floor.position = Vector3(0, -0.01, 6.0)
	carpet.uv1_scale = Vector3(15, 6, 1)
	# plain dark base under the lanes (fills gaps around gutters)
	var base := MeshInstance3D.new()
	var bpm := PlaneMesh.new()
	bpm.size = Vector2(30, 28)
	base.mesh = bpm
	base.material_override = _mat(Color("39404c"), 0.9)
	base.position = Vector3(0, -0.06, -14.0)
	add_child(base)
	add_child(floor)


var monitor: Label3D
var monitor_l: Label3D


## Reflections, neon, score monitors, ball returns and other bowlers.
func _build_extras() -> void:
	# reflection probe so the glossy lane mirrors the pins and ceiling lights
	if Look.get_quality() >= Look.MEDIUM:
		var probe := ReflectionProbe.new()
		probe.size = Vector3(LANE_PITCH * 5, 4.4, 26.0)
		probe.position = Vector3(0, 2.0, -9.5)
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		add_child(probe)
	# neon name across the masking panel, lane numbers per lane
	Props.neon(self, "VECTOR BOWL", Vector3(0, 2.18, -LANE_LEN - 0.93), 0.0, Color("31d8ff"), 0.0024)
	for k in [-2, -1, 0, 1, 2]:
		var n := Props.neon(self, str(5 + k), Vector3(k * LANE_PITCH + 0.5, 1.3, -LANE_LEN - 0.93), 0.0, Color("ff4fa3"), 0.0016)
		n.outline_size = 10
	# glowing strips along both side walls
	for side: float in [-1.0, 1.0]:
		for col: Color in [Color("ff4fa3"), Color("31d8ff")]:
			var strip := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.04, 0.05, 30.0)
			strip.mesh = sb
			var sm := StandardMaterial3D.new()
			sm.albedo_color = col
			sm.emission_enabled = true
			sm.emission = col
			sm.emission_energy_multiplier = 2.2
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			strip.material_override = sm
			strip.position = Vector3(side * 5.76, 3.3 if col == Color("ff4fa3") else 3.42, -7.0)
			add_child(strip)
		Props.neon(self, "STRIKE!" if side < 0 else "SPARE?", Vector3(side * 5.74, 2.85, -9.0), -side * PI * 0.5, Color("ffd23f") if side < 0 else Color("31d8ff"), 0.008)
	# big score screens on the side walls
	for side: float in [-1.0, 1.0]:
		var scr := Props.scoreboard(self, Vector3(side * 5.55, 2.3, -4.0), -side * PI * 0.5, Vector2(2.6, 1.4), "LANE 5", false)
		scr.text = "VECTOR BOWL"
		if side > 0.0:
			monitor = scr
		else:
			scr.set_meta("mirror", true)
			monitor_l = scr
	# ball returns between the lanes, with a rack of colourful balls
	for side: float in [-1.0, 1.0]:
		var x := side * LANE_PITCH * 1.5
		var hood := MeshInstance3D.new()
		var hm := CapsuleMesh.new()
		hm.radius = 0.32
		hm.height = 1.4
		hood.mesh = hm
		hood.material_override = Character.material(Color("2b6cb0"), 0.3)
		hood.rotation.x = PI * 0.5
		hood.scale = Vector3(1.0, 1.0, 0.75)
		hood.position = Vector3(x, 0.3, 1.6)
		add_child(hood)
		var rack := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.42, 0.08, 1.3)
		rack.mesh = rb
		rack.material_override = Character.material(Color("c9ced4"), 0.3)
		rack.position = Vector3(x, 0.55, 2.9)
		add_child(rack)
		var cols := [Color("e23d3d"), Color("7a3fd6"), Color("1fa36b"), Color("f0a020")]
		for i in 4:
			var b := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.108
			bs.height = 0.216
			b.mesh = bs
			var bmat := Character.material(cols[(i + int(side + 1.0)) % 4], 0.15)
			b.material_override = bmat
			b.position = Vector3(x, 0.7, 2.4 + i * 0.28)
			add_child(b)
	# other people bowling on the neighbouring lanes
	var spots := [Vector3(-LANE_PITCH * 2, 0, 2.2), Vector3(LANE_PITCH, 0, 3.4), Vector3(LANE_PITCH * 2 + 0.4, 0, 4.0)]
	for i in spots.size():
		var c := Character.new()
		c.outfit = "bowling"
		c.look_seed = 900 + i
		c.shirt = [Color("e8574a"), Color("3fae5d"), Color("8d6fd6")][i]
		c.bowling = true
		c.shadows = false
		add_child(c)
		c.position = spots[i]
		c.rotation.y = [0.0, 0.4, PI * 0.85][i]
		c.swing_angle = [0.3, -0.1, 0.0][i]


func _build_environment() -> void:
	var key := Look.setup(self, "indoor", 30.0)
	key.light_energy = 0.75
	var pin_light := SpotLight3D.new()
	pin_light.light_energy = 1.6
	pin_light.spot_range = 5.0
	pin_light.spot_angle = 35.0
	pin_light.shadow_enabled = true
	pin_light.position = Vector3(0, 2.4, -LANE_LEN + 1.2)
	pin_light.rotation = Vector3(deg_to_rad(-70), 0, 0)
	add_child(pin_light)


## Maple boards, arrows at 15 ft and dots at 7 ft.
func _lane_texture() -> ImageTexture:
	var w := 78
	var h := 2048
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for b in 39:
		var tone := Color("f0d7a4").darkened(rng.randf_range(0.0, 0.07))
		for x in range(b * 2, b * 2 + 2):
			for y in h:
				var grain := sin(y * 0.09 + b * 3.1) * 0.012
				img.set_pixel(x, y, tone.darkened(grain + (0.06 if x == b * 2 else 0.0)))
	var px_per_m := float(h) / DECK_END
	# arrows (V shape) around 15 ft, every 5th board
	for k in 7:
		var board := 4 + k * 5
		var center_offset := absi(k - 3)
		var tip_m := 4.57 + (3 - center_offset) * 0.3
		var tip_y := h - int(tip_m * px_per_m)
		for dy in 26:
			var half := int(dy / 10.0)
			for dx in range(-half, half + 1):
				var x := board * 2 + dx
				if x >= 0 and x < w:
					img.set_pixel(x, tip_y + dy, Color("6b4a2b"))
	# dots at 7 ft
	for board in [3, 5, 8, 11, 14, 24, 27, 30, 33, 35]:
		var y := h - int(2.13 * px_per_m)
		for dy in 4:
			img.set_pixel(board * 2, y + dy, Color("6b4a2b"))
			img.set_pixel(board * 2 + 1, y + dy, Color("6b4a2b"))
	# pin spot marks
	for p in PIN_SPOTS:
		var cx := int((p.x + LANE_HALF) / (LANE_HALF * 2) * w)
		var cy := h - int(-p.z * px_per_m)
		for dy in range(-2, 3):
			for dx in range(-1, 2):
				if cx + dx >= 0 and cx + dx < w and cy + dy >= 0 and cy + dy < h:
					img.set_pixel(cx + dx, cy + dy, Color("c9a36a"))
	# PlaneMesh UV v=0 is the far (-Z) end, so flip to have the foul line at v=1
	img.flip_y()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Cream panels with seams, white trim and a blue lower band (tiles every 4 m).
func _wall_texture() -> ImageTexture:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var band := int(h * 0.30)
	for y in h:
		var shade := 1.0 - float(y) / h * 0.06
		for x in w:
			var c: Color
			if y >= h - band:
				# blue band with soft diagonal stripes
				var d := (x + y) % 48
				c = Color("2f9fd6") if d < 30 else Color("3aaee3")
			else:
				c = Color("f1e6cf") * shade
				if x % 256 < 3: # panel seams
					c = Color("d9c9a8")
			c.a = 1.0
			img.set_pixel(x, y, c)
	# white trim between band and panels
	for y in range(h - band - 10, h - band):
		for x in w:
			img.set_pixel(x, y, Color("fafafa") if y < h - band - 3 else Color("c9d6df"))
	# a picture-rail line near the top
	for y in range(40, 46):
		for x in w:
			img.set_pixel(x, y, Color("31b8e8"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Classic alley carpet: deep navy with colourful confetti shapes.
func _carpet_texture() -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color("1e2a4a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var cols := [Color("31b8e8"), Color("ffb020"), Color("e0533d"), Color("7ed957"), Color("b07cf0")]
	for i in 70:
		var c: Color = cols[i % cols.size()]
		var cx := rng.randi_range(0, n - 1)
		var cy := rng.randi_range(0, n - 1)
		var r := rng.randi_range(3, 7)
		var kind := i % 3
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var inside := false
				match kind:
					0: inside = dx * dx + dy * dy <= r * r
					1: inside = absi(dx) + absi(dy) <= r and absi(dx) + absi(dy) >= r - 2
					2: inside = dy >= -r / 2 and dy <= r / 2 and absi(dx) <= r - absi(dy)
				if inside:
					img.set_pixel(posmod(cx + dx, n), posmod(cy + dy, n), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _cached(key: String, make: Callable) -> Texture2D:
	if not _tex_cache.has(key):
		_tex_cache[key] = make.call()
	return _tex_cache[key]


static func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m
