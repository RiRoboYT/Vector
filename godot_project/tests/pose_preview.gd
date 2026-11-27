extends SceneTree
# Renders bowling poses for a visual check: aim, backswing, release.
func _init():
	var out: String = OS.get_cmdline_user_args()[0]
	root.add_child(BowlingLane.new())
	for i in 10:
		root.add_child(BowlingPin.new(i + 1, BowlingLane.PIN_SPOTS[i]))
	var c := Character.new(); c.bowling = true; root.add_child(c)
	var ball := BowlingBall.new(); root.add_child(ball)
	var cam := Camera3D.new(); cam.fov = 56; root.add_child(cam); cam.current = true
	var poses := {
		"aim": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true],
		"back": [-80.0, 0.55, 0.15, 0.04, 0.0, 0.6, 0.5, false],
		"release": [20.0, 1.0, 0.38, 0.11, 1.0, 1.0, 1.0, false],
	}
	for name in poses:
		var v: Array = poses[name]
		var start := Vector3(-0.33, 0, BowlingGame.START_Z)
		c.position = start + Vector3.FORWARD * (BowlingGame.START_Z - BowlingGame.FOUL_Z) * v[1]
		c.swing_angle = deg_to_rad(v[0]); c.lean = v[2]; c.crouch = v[3]; c.slide = v[4]
		c.balance_arm = v[5]; c.step_phase = v[6] * 3.0 * PI; c.walk_amount = 0.0 if v[1] >= 1.0 else 1.0
		await process_frame
		c.set_ghost(1.0 if v[7] else 0.0)
		for i in 6: await process_frame
		ball.hold(c.hand_world + Vector3(0, -0.05, 0))
		if name == "aim":
			cam.look_at_from_position(Vector3(0.1, 1.9, BowlingGame.START_Z + 2.5), Vector3(0, 0.2, -17))
		else: # side view to judge the body motion
			cam.look_at_from_position(Vector3(2.6, 1.3, c.position.z - 0.2), c.position + Vector3(0, 0.9, 0))
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/pose_" + name + ".png")
	quit()
