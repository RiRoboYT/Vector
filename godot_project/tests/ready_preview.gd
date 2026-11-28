extends SceneTree
# Renders the ready-check screen with a few players.
func _init():
	var out: String = OS.get_cmdline_user_args()[0]
	root.add_child(Pad.new()); root.add_child(Sfx.new())
	var layer := CanvasLayer.new(); root.add_child(layer)
	var roster := Players.new()
	var names := ["Maya", "Sam", "Leo", "Priya", "Ben"]
	for i in names.size():
		var p := Players.Player.new(); p.name = names[i]; p.pid = "p%d" % i; p.color = Players.COLORS[i]
		roster.players.append(p)
	var srv := ControllerServer.new(); roster.server = srv
	var s := ReadyScreen.new(); s.roster = roster; s.sport = "Cricket"; layer.add_child(s)
	await process_frame
	s._ready_flags[0] = true; s._ready_flags[2] = true
	s._holding["p1"] = 0.6
	for i in 6: await process_frame
	s._holding["p1"] = 0.6
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/ready.png")
	quit()
