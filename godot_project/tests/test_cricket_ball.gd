extends SceneTree
# Checks the cricket ball physics against real-world numbers.
func _init():
	var field := CricketField.new(); root.add_child(field)
	var ball := CricketBall.new(); ball.field = field; root.add_child(ball)
	await process_frame
	var from := Vector3(0.25, 2.2, -19.0)
	# 1) a 140 km/h delivery landing on a good length (6 m in front of the batter)
	var target := Vector3(0.1, 0, -6.0)
	var v := CricketBall.solve_delivery(from, target, 140.0 / 3.6, 0.0)
	var land := CricketBall.simulate_to_bounce(from, v, 0.0)
	print("fast ball: elevation %.1f deg, lands at (%.2f, %.2f) aimed (%.2f, %.2f)" % [rad_to_deg(asin(v.normalized().y)), land.x, land.z, target.x, target.z])
	ball.release(from, v)
	var t := 0.0
	var reached := false
	while t < 2.0:
		await physics_frame
		t += 1.0 / 120.0
		if not reached and ball.global_position.z > -1.0:
			reached = true
			print("  reaches batter in %.2f s at height %.2f m, speed %.0f km/h (drag + bounce losses)" % [t, ball.global_position.y, ball.vel.length() * 3.6])
	# 2) swing: 1.2 m/s^2 out-swing should move the ball ~0.3-0.5 m before it pitches
	var v2 := CricketBall.solve_delivery(from, target, 130.0 / 3.6, 0.0)
	var straight := CricketBall.simulate_to_bounce(from, v2, 0.0)
	var swung := CricketBall.simulate_to_bounce(from, v2, 5.0)
	print("swing (5 m/s^2, full swing): lateral movement before pitching %.2f m" % (swung.x - straight.x))
	# 3) a lofted hit at 35 m/s, 35 deg: does it clear a 62 m boundary on the full?
	ball.global_position = Vector3(0, 1.0, -1.0)
	ball.set_velocity((Vector3(0, 0, -1) * cos(deg_to_rad(35)) + Vector3.UP * sin(deg_to_rad(35))) * 38.0, true)
	var res := {"b": "", "hit": false}
	ball.boundary.connect(func(six): res.b = "SIX" if six else "FOUR")
	t = 0.0
	while t < 8.0 and res.b == "":
		await physics_frame
		t += 1.0 / 120.0
	print("lofted 38 m/s @35deg -> %s after %.1f s (carried %.0f m)" % [res.b if res.b != "" else "no boundary", t, Vector2(ball.global_position.x, ball.global_position.z + 1.0).length()])
	# 4) a ground drive at 25 m/s: rolls to the rope?
	ball.global_position = Vector3(0, CricketBall.RADIUS, -1.0)
	ball.set_velocity(Vector3(0.3, 0, -1).normalized() * 25.0, true)
	ball.grounded_after_bat = true
	ball.rolling = true
	res.b = ""
	t = 0.0
	while t < 12.0 and res.b == "" and ball.mode == CricketBall.Mode.FLYING:
		await physics_frame
		t += 1.0 / 120.0
	print("ground drive 25 m/s -> %s (ended at %.0f m from centre after %.1f s)" % [res.b if res.b != "" else "stopped", CricketField.dist_from_center(ball.global_position), t])
	# 5) bowled: aim at the stumps
	field.striker_stumps.reset()
	var v3 := CricketBall.solve_delivery(from, Vector3(0.0, 0, -2.0), 135.0 / 3.6, 0.0)
	ball.release(from, v3)
	ball.hit_stumps.connect(func(_s, _p, _v): res.hit = true)
	t = 0.0
	while t < 2.0 and not res.hit:
		await physics_frame
		t += 1.0 / 120.0
	print("straight full ball at the stumps -> stumps hit: %s, wicket broken: %s" % [res.hit, field.striker_stumps.broken])
	quit()
