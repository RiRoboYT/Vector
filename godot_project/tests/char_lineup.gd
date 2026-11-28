extends SceneTree
# Close-up line-up of characters (looks, outfits, reactions) for a visual check.
func _init():
	var out: String = OS.get_cmdline_user_args()[0]
	var w := Node3D.new(); root.add_child(w)
	Look.setup(w, "day", 20.0)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = Character.material(Color("2f6fc4"), 0.8); w.add_child(g)
	var outfits := ["tennis", "bowling", "cricket", "casual", "tennis", "umpire"]
	var shirts := [Color("2f8fe0"), Color("e8574a"), Color("2f8fe0"), Color("3fae5d"), Color("ff7a3d"), Color("1f3a5f")]
	for i in 6:
		var c := Character.new()
		c.outfit = outfits[i]; c.shirt = shirts[i]; c.look_seed = 100 + i * 13
		c.pants = Color(0.95, 0.95, 0.95) if outfits[i] != "bowling" else Color("2b2f45")
		w.add_child(c)
		c.position = Vector3(-3.0 + i * 1.2, 0, 0)
		c.rotation.y = PI + (i - 2.5) * 0.12
		if i == 1: c.react("cheer", 99)
		if i == 4: c.react("sad", 99)
	var cam := Camera3D.new(); cam.fov = 38; w.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(0, 1.6, 6.5), Vector3(0, 1.05, 0))
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
