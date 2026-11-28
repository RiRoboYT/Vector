extends SceneTree
# Renders tennis menu pieces for a visual check.
func _init():
	var out: String = OS.get_cmdline_user_args()[0]
	root.add_child(Pad.new())
	root.add_child(Sfx.new())
	var layer := CanvasLayer.new(); root.add_child(layer)
	var card := PreviewCard.new(false, "Tennis  ·  1–4 players  ·  Doubles  ·  1 / 3 / 5 games", "tennis")
	layer.add_child(card)
	card.position = Vector2(140, 80); card.size = Vector2(1000, 560)
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/m_tennis_card.png")
	card.queue_free()
	var roster := Players.new()
	for n in ["Maya", "Arjun", "Sam"]:
		var p := Players.Player.new(); p.name = n; roster.players.append(p)
	var opt := TennisOptions.new(); opt.roster = roster; layer.add_child(opt)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/m_tennis_opts.png")
	opt.queue_free()
	var t := TutorialScreen.new(); t.pages = TutorialScreen.TENNIS; t.title = "How to play tennis"; t.page = 3
	layer.add_child(t)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/m_tennis_tut.png")
	quit()
