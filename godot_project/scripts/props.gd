class_name Props
extends RefCounted
## Small shared set pieces for the venues: sponsor boards with text (made-up
## brands), glowing signs and live scoreboards.

const BRANDS := ["VECTOR SPORTS", "ACE COLA", "SMASH!", "RALLY TEA", "TOPSPIN", "COURTSIDE", "SKYLINE AIR", "BOUNCE", "FRESHCUT", "GOLDEN HOUR"]


static func label(text: String, size: int, col: Color, outline := Color(0, 0, 0, 0), bold := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UI.bold() if bold else UI.regular()
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_modulate = outline
	l.outline_size = 0 if outline.a == 0.0 else maxi(4, size / 10)
	l.double_sided = false
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return l


## A coloured board with a brand name on its front (-Z of `basis` faces the field).
static func board(parent: Node, xf: Transform3D, size: Vector3, bg: Color, text: String, fg := Color.WHITE) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Character.material(bg, 0.45)
	mi.transform = xf
	parent.add_child(mi)
	var l := label(text, 96, fg)
	l.pixel_size = minf(size.y * 0.55 / 96.0, size.x * 0.8 / (96.0 * 0.62 * maxf(1.0, text.length())))
	l.position = Vector3(0, 0, -size.z * 0.5 - 0.01)
	l.rotation.y = PI
	mi.add_child(l)


## Glowing neon-style sign text.
static func neon(parent: Node, text: String, pos: Vector3, yaw: float, col: Color, px := 0.012) -> Label3D:
	var l := label(text, 128, col.lightened(0.3), col)
	l.pixel_size = px
	l.outline_size = 18
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l


## Scoreboard: dark screen in a frame on two legs; returns the text label.
static func scoreboard(parent: Node, pos: Vector3, yaw: float, size := Vector2(6, 3), title := "VECTOR OPEN", legs := true) -> Label3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(size.x + 0.4, size.y + 0.4, 0.3)
	frame.mesh = fm
	frame.material_override = Character.material(Color("2f3a46"), 0.4)
	root.add_child(frame)
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	screen.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("0d1b2e")
	sm.emission_enabled = true
	sm.emission = Color("0d1b2e")
	sm.emission_energy_multiplier = 0.6
	screen.material_override = sm
	screen.position = Vector3(0, 0, 0.16)
	root.add_child(screen)
	for side: float in ([-1.0, 1.0] if legs else []):
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.3, pos.y, 0.3)
		leg.mesh = lm
		leg.material_override = Character.material(Color("c9ced4"))
		leg.position = Vector3(side * size.x * 0.35, -pos.y * 0.5, 0)
		root.add_child(leg)
	var t := label(title, 64, Color("31b8e8"))
	t.pixel_size = size.y * 0.16 / 64.0
	t.position = Vector3(0, size.y * 0.36, 0.17)
	root.add_child(t)
	var body := label("", 64, Color(1, 0.95, 0.7))
	body.pixel_size = size.y * 0.22 / 64.0
	body.position = Vector3(0, -size.y * 0.08, 0.17)
	body.line_spacing = 4
	root.add_child(body)
	return body


## A standing official (line judge / steward) with hands behind the back.
static func official(parent: Node, pos: Vector3, face: Vector3, shirt := Color("1f3a5f"), seed := -1, scale := 1.0) -> Character:
	var c := Character.new()
	c.shirt = shirt
	c.pants = Color("e8e8ea")
	c.outfit = "umpire"
	c.look_seed = seed
	c.shadows = false
	c.hand_targets = true
	parent.add_child(c)
	c.scale = Vector3.ONE * scale
	c.position = pos
	c.look_at(Vector3(face.x, pos.y, face.z), Vector3.UP)
	var back := c.global_basis.z.normalized()
	var right := c.global_basis.x.normalized()
	c.hand_r_world = c.global_position + (Vector3(0, 0.95, 0) + back * 0.22 + right * 0.08) * scale
	c.hand_l_world = c.global_position + (Vector3(0, 0.95, 0) + back * 0.22 - right * 0.08) * scale
	return c
