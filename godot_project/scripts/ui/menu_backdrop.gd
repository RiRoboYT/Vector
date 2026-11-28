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
	var pos := Vector3(sin(a) * 36.0, 15.0 + sin(_t * 0.2) * 0.8, cos(a) * 36.0)
	_cam.look_at_from_position(pos, Vector3(0, 2.5, 0))
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


func _island() -> void:
	# grassy top
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 14.0
	cm.bottom_radius = 13.2
	cm.height = 1.2
	cm.radial_segments = 64
	top.mesh = cm
	top.material_override = CricketField._shader_mat(CricketField.GRASS_SHADER)
	top.position.y = -0.6
	add_child(top)
	# rocky underside tapering into the sky
	for i in 3:
		var rock := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 13.2 - i * 3.6
		rm.bottom_radius = 9.6 - i * 3.6
		rm.height = 3.0
		rm.radial_segments = 24
		rock.mesh = rm
		rock.material_override = _mat([Color("8a6b4e"), Color("7a5e45"), Color("6b513b")][i], 0.95)
		rock.position.y = -2.7 - i * 3.0
		add_child(rock)


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
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(10.5, 12.8)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.12
		tm.bottom_radius = 0.18
		tm.height = 1.4
		trunk.mesh = tm
		trunk.material_override = _mat(Color("7a5232"))
		trunk.position = p + Vector3(0, 0.7, 0)
		add_child(trunk)
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var s := rng.randf_range(0.9, 1.5)
		sm.radius = s
		sm.height = s * 2.0
		crown.mesh = sm
		crown.material_override = _mat(Color("4f9e3e").lerp(Color("7cc25a"), rng.randf()))
		crown.position = p + Vector3(0, 1.4 + s * 0.8, 0)
		add_child(crown)


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
