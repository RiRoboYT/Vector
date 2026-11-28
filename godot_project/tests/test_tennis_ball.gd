extends SceneTree
# Checks tennis ball physics: shots land where aimed, spin changes the arc
# and bounce, the net stops low balls, serves are realistic.
func _init():
	var from := Vector3(0.5, 1.0, 11.5)
	var target := Vector3(-3.0, 0, -8.0)
	for s in [30.0, 0.0, -25.0]:
		var r := TennisBall.solve_shot(from, target, 30.0, s)
		var land := TennisBall.simulate_landing(from, r.v, s)
		print("groundstroke 108 km/h spin %+3.0f rev/s: launch %4.1f deg, lands (%.2f, %.2f), flight %.2f s, clears net: %s" % [s, rad_to_deg(asin(r.v.normalized().y)), land.pos.x, land.pos.z, land.t, r.ok])
	# serve from 2.7 m contact height into the deuce box
	var sv := TennisBall.solve_shot(Vector3(0.6, 2.7, 12.0), Vector3(-2.2, 0, -5.6), 50.0, 5.0)
	var sl := TennisBall.simulate_landing(Vector3(0.6, 2.7, 12.0), sv.v, 5.0)
	print("serve 180 km/h: lands (%.2f, %.2f) in box: %s, clears net: %s, flight %.2f s" % [sl.pos.x, sl.pos.z, TennisCourt.in_service_box(sl.pos, 1, true), sv.ok, sl.t])
	# a flat shot hit too low: should hit the net
	var low := TennisBall.simulate_landing(Vector3(0, 0.5, 8.0), Vector3(0, 0.3, -25.0), 0.0)
	print("low flat ball into the net: clears net: %s" % low.net_ok)
	# bounce: topspin kicks higher than slice
	root.add_child(TennisCourt.new())
	var ball := TennisBall.new(); root.add_child(ball)
	await process_frame
	for s in [35.0, -25.0]:
		ball.launch(Vector3(0, 1.0, -2.0), Vector3(0, 2.0, -20.0), s, 1)
		var peak := 0.0
		var bounced := {"n": 0}
		var cb := func(_p): bounced.n += 1
		ball.bounced.connect(cb)
		var t := 0.0
		while t < 2.0:
			await physics_frame
			t += 1.0 / 120.0
			if bounced.n == 1:
				peak = maxf(peak, ball.global_position.y)
			if bounced.n >= 2: break
		ball.bounced.disconnect(cb)
		print("after the bounce, spin %+3.0f: rises to %.2f m" % [s, peak])
	quit()
