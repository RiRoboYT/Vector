extends SceneTree
# Swings the bat at real deliveries with different timing / face angles and
# reports what the physics does with the ball.
var field: CricketField
var ball: CricketBall
var rig: BatterRig

func _init():
	field = CricketField.new(); root.add_child(field)
	ball = CricketBall.new(); ball.field = field; root.add_child(ball)
	rig = BatterRig.new(); root.add_child(rig)
	rig.setup(Color.BLUE, false)
	await process_frame
	var cases := [
		["on time, straight", 0.0, 0.0],
		["40 ms early", -0.04, 0.0],
		["40 ms late", 0.04, 0.0],
		["on time, face to leg (pull/flick)", 0.0, 0.7],
		["on time, face to off (cut/drive)", 0.0, -0.7],
		["100 ms early (miss?)", -0.10, 0.0],
	]
	for c in cases:
		await _run(c[0], c[1], c[2])
	quit()

func _run(name: String, timing: float, psi: float) -> void:
	field.striker_stumps.reset()
	rig.bat.reset_motion()
	rig.bat.dbg_min = 99.0
	var from := Vector3(0.25, 2.2, -19.0)
	var line_x := rig.stance_hands().x
	# aim so the ball arrives on the bat's line at the batter
	var tx := line_x
	var v := Vector3.ZERO
	for it in 4:
		v = CricketBall.solve_delivery(from, Vector3(tx, 0, -5.5), 130.0 / 3.6, 0.0)
		ball.release(from, v)
		var pp := ball.predict(1.5, 0.005)
		for q in pp:
			if q.z >= rig.stance_hands().z:
				tx += line_x - q.x
				break
	ball.release(from, v)
	rig.lift = 0.0
	for q in ball.predict(1.5, 0.005):
		if q.z >= rig.stance_hands().z:
			rig.lift = BatterRig.lift_for_ball(q.y)
			break
	# when will the ball reach the bat's swing plane (z of the hands)?
	var t_arrive := 0.0
	var pts := ball.predict(1.5, 0.005)
	for i in pts.size():
		if pts[i].z >= rig.stance_hands().z:
			t_arrive = i * 0.005
			break
	var omega := 15.0 # rad/s ~ 860 deg/s, a firm swing
	var phi_contact := 0.12
	var t := 0.0
	var hit := {"q": -1.0, "edge": false}
	var cb := func(_p, q, e): hit.q = q; hit.edge = e
	rig.bat.contact.connect(cb)
	var dt := 1.0 / 120.0
	while t < 1.4:
		var phi := clampf(phi_contact + (t - (t_arrive + timing)) * omega, -2.2, 1.4)
		rig.apply_rotation(BatterRig.swing_rotation(phi, psi))
		await physics_frame
		rig.bat.physics_check(ball, dt)
		t += dt
		if hit.q >= 0.0 and t > t_arrive + 0.3:
			break
	rig.bat.contact.disconnect(cb)
	if hit.q < 0.0:
		print("%-34s MISS  (stumps broken: %s) closest %.3f m, ball in bat space %s, t_arrive %.2f" % [name, field.striker_stumps.broken, rig.bat.dbg_min, rig.bat.dbg_local, t_arrive])
		return
	var vv := ball.vel
	var hdir := rad_to_deg(atan2(-vv.x, -vv.z))
	var elev := rad_to_deg(atan2(vv.y, Vector2(vv.x, vv.z).length()))
	print("%-34s exit %3.0f km/h, direction %+4.0f deg (0 = straight, + = leg side), elevation %+3.0f deg, quality %.2f%s" % [name, vv.length() * 3.6, hdir, elev, hit.q, "  EDGE" if hit.edge else ""])
