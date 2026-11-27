extends SceneTree
# Close-up render of the bowling ball for a look check.
func _init():
	var out: String = OS.get_cmdline_user_args()[0]
	root.add_child(BowlingLane.new())
	var ball := BowlingBall.new(); root.add_child(ball)
	ball.hold(Vector3(0, 0.3, 1.0))
	ball.rotation = Vector3(0.5, 0.4, 0)
	var cam := Camera3D.new(); cam.fov = 30; root.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(0.25, 0.55, 1.65), Vector3(0, 0.3, 1.0))
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/ball.png")
	quit()
