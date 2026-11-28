extends SceneTree
# Plays a Super Over as a human with a simulated phone:
#  - batting: taps B when ready, then swings the phone like a bat (the bat
#    copies the phone orientation) timed to the incoming ball
#  - bowling: sets field (B), aims (B held), runs in and lets go of B
# Results are printed by the game's [cricket] log lines.
var game: CricketGame
var motion: MotionInput
var t_ms := 0.0
var beta := 90.0 # phone upright = bat in stance
var swinging := -1.0
var hits := 0
var tapped := false
var swing_t := -1.0

func _init():
	var pad := Pad.new(); root.add_child(pad)
	motion = MotionInput.new(); root.add_child(motion)
	Pad.instance_motion = motion
	root.add_child(Sfx.new())
	var roster := Players.new()
	var p := Players.Player.new(); p.pid = "sim"; p.name = "Tester"; p.color = Color.BLUE
	roster.players.append(p)
	if OS.get_environment("VS_PVP") != "":
		var p2 := Players.Player.new(); p2.pid = "sim2"; p2.name = "Leo"; p2.color = Color.ORANGE
		roster.players.append(p2)
	game = CricketGame.new()
	game.roster = roster
	game.overs = 1
	game.super_over = true
	game.difficulty = 1
	root.add_child(game)
	await process_frame
	motion.gyro_sample.connect(game._on_gyro)
	game.rig.bat.contact.connect(func(_p, q, e): hits += 1; print("  [test] bat contact quality %.2f%s" % [q, " edge" if e else ""]))
	var last_phase := -1
	var b_hold := 0.0
	var elapsed := 0.0
	while elapsed < 150.0 and game.phase != CricketGame.Phase.OVER:
		await process_frame
		var dt := root.get_process_delta_time()
		elapsed += dt
		t_ms = Time.get_ticks_msec()
		_feed()
		if game.phase != last_phase:
			last_phase = game.phase
			_shot(game.phase)
			match game.phase:
				CricketGame.Phase.BAT_SETUP:
					beta = -90.0 # phone pointing at the floor
					_press_b_later(2.5 if OS.get_environment("VS_SHOTS") != "" else 0.6)
				CricketGame.Phase.FIELD_SET:
					_press_b_later(4.0 if OS.get_environment("VS_SHOTS") != "" else 0.6)
				CricketGame.Phase.AIM:
					b_hold = 0.0
					_press_b_later(0.6) # tap B to run in
				CricketGame.Phase.DELIVERY:
					swinging = -1.0
		if game.phase == CricketGame.Phase.DELIVERY and not game._is_cpu(game.bat_team):
			_bat(dt)
		if game.phase == CricketGame.Phase.RUNUP and not game._is_cpu(game.field_team()):
			if not game.meter_locked and absf(game.meter) < 0.08 and not tapped:
				tapped = true
				_press_b_later(0.0)
				swing_t = 0.0
			if game.meter_locked:
				swing_t += dt
		else:
			tapped = false
	print("[test] finished: phase=%s bat contacts=%d result=%s" % [game.phase, hits, game.score.result_text() if game.score.innings.size() == 2 else "-"])
	quit()

var _shots := {}
func _shot(ph: int) -> void:
	var dir := OS.get_environment("VS_SHOTS")
	if dir == "" or _shots.has(ph):
		return
	_shots[ph] = true
	await create_timer(1.6 if ph in [CricketGame.Phase.BAT_SETUP, CricketGame.Phase.FIELD_SET] else (1.6 if ph == CricketGame.Phase.PLAY else (0.35 if ph == CricketGame.Phase.RUNUP else 0.9))).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/cs_%d.png" % [dir, ph])


func _feed() -> void:
	# after the meter lock: a short, slightly angled half swing with a wrist twist
	var swinging_arm := game.phase == CricketGame.Phase.RUNUP and game.meter_locked and swing_t < 0.3
	var g := {"alpha": 120.0 if swinging_arm else 0.0, "beta": 500.0 if swinging_arm else 0.0, "gamma": -150.0 if swinging_arm else 0.0}
	motion.handle_sensor({"type": "sensor", "orientation": {"alpha": 0.0, "beta": beta, "gamma": 0.0}, "gyro": g, "t": t_ms})

func _press_b_later(s: float) -> void:
	await create_timer(s).timeout
	Pad.phone_button(Pad.B, true)
	await process_frame
	await process_frame
	Pad.phone_button(Pad.B, false)

func _hold_b(after: float, hold: float) -> void:
	await create_timer(after).timeout
	Pad.phone_button(Pad.B, true)
	await create_timer(hold).timeout
	Pad.phone_button(Pad.B, false)

func _bat(dt: float) -> void:
	# start the swing so the bat comes through as the ball reaches the batter
	var pts := game.ball.predict(1.5, 0.01)
	var t_arrive := -1.0
	for i in pts.size():
		if pts[i].z >= game.rig.stance_hands().z:
			t_arrive = i * 0.01
			break
	# phone pointing down in stance: bat angle phi = beta + 90 deg
	var phi := -103.0
	if swinging < 0.0:
		if t_arrive >= 0.0 and t_arrive < 0.16:
			swinging = 0.0
	else:
		swinging += dt
		phi = minf(-103.0 + swinging * 650.0, 60.0) # ~650 deg/s through the ball
	beta = phi - 90.0
	if beta < -180.0:
		beta += 360.0
