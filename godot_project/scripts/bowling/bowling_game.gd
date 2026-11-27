class_name BowlingGame
extends Node3D
## A 10-frame game for 1-8 players. Each player bowls a full frame, then
## the next player is up; input is locked to the current player's phone.
##
## Controls (phone):  Left/Right = move or turn, A = switch Move/Turn,
## hold B -> swing arm back -> swing forward -> let go of B to release.
## Ball speed comes from how fast the phone is rotating forward at release
## (gyro), spin from twisting the wrist around the phone's long axis.
## Keyboard fallback: arrows, Enter = A, hold Space = B (longer = faster),
## hold Q / E while releasing for left / right spin.

signal finished(action: String) # "again" or "menu"
## data["to"] = a phone id, or "*" for every phone
signal phone_message(data: Dictionary)

enum State { TURN_INTRO, AIM, SWING, ROLL, SETTLE, RESULT, OVER }
enum Mode { MOVE, TURN }

const MOVE_SPEED := 0.55 # m/s
const TURN_SPEED := deg_to_rad(5.0) # rad/s
const MAX_X := 0.42
const MAX_ANGLE := deg_to_rad(5.0)
const MIN_FORWARD_RATE := 50.0 # deg/s: slower than this is not a throw

var roster: Players
var lane: BowlingLane
var ball: BowlingBall
var pins: Array[BowlingPin] = []
var bowler: Character
var camera: Camera3D
var hud: BowlingHud
var scores: Array[BowlingScore] = []
var cur := 0 # current player index
var score: BowlingScore:
	get:
		return scores[cur]
var _aims: Array[Vector2] = [] # per-player (ball_x, angle)
var _frame_before := 0

var state := State.AIM
var mode := Mode.MOVE
var ball_x := 0.0 # where the ball will be released across the lane
var angle := 0.0 # aim angle, + = right

var _guides: Node3D
var _move_arrows: Node3D
var _turn_arrows: Node3D
var _state_t := 0.0
var _standing_before := 10
var _gutter := false
var _swing_angle := 0.0 # deg, phone rotation since B was pressed
var _back_sign := 0.0
var _hist: Array = [] # [t_ms, rate_x, rate_y]
var _last_gyro_t := -1.0
var _keyboard_swing := false
var _spin_pending := false
var _spin_release_t := 0.0
var _spin_accum := 0.0
var _arm := 0.0 # displayed arm angle (rad)
var _follow_through := 0.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO


func _ready() -> void:
	lane = BowlingLane.new()
	add_child(lane)
	for i in 10:
		var p := BowlingPin.new(i + 1, BowlingLane.PIN_SPOTS[i])
		add_child(p)
		pins.append(p)
	ball = BowlingBall.new()
	add_child(ball)
	bowler = Character.new()
	bowler.bowling = true
	add_child(bowler)
	camera = Camera3D.new()
	camera.fov = 56.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	_build_guides()
	hud = BowlingHud.new()
	add_child(hud)
	hud.play_again.connect(func(): finished.emit("again"))
	hud.to_menu.connect(func(): finished.emit("menu"))
	roster.gyro_sample.connect(_on_gyro)
	_new_game()
	if OS.get_cmdline_user_args().has("--test-results"): # test helper
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for sc in scores:
			while not sc.is_over():
				sc.add(rng.randi_range(maxi(0, sc.pins_standing() - 4), sc.pins_standing()))
		cur = 1
		_refresh_hud()
		if OS.get_cmdline_user_args().has("--show-final"):
			hud.show_results(scores, roster.players)
			Pad.pointer_visible = true
			state = State.OVER
		return
	if OS.get_cmdline_user_args().has("--autothrow"): # test helper
		await get_tree().create_timer(2.0).timeout
		Pad.phone_button(Pad.B, true)
		await get_tree().create_timer(0.5).timeout
		Pad.phone_button(Pad.B, false)


func _new_game() -> void:
	scores.clear()
	_aims.clear()
	for p in roster.players:
		scores.append(BowlingScore.new())
		_aims.append(Vector2.ZERO)
	cur = 0
	_cam_pos = _aim_cam_pos()
	_cam_look = _aim_cam_look()
	bowler.set_ghost.call_deferred(1.0)
	_start_turn.call_deferred()


func player() -> Players.Player:
	return roster.players[cur]


func _start_turn() -> void:
	state = State.TURN_INTRO
	_state_t = 0.0
	_full_rack()
	ball_x = _aims[cur].x
	angle = _aims[cur].y
	mode = Mode.MOVE
	ball.rolling = false
	ball.hold(bowler.hand_world)
	_guides.visible = false
	hud.show_hints(false)
	var p := player()
	print("[bowling] turn: %s (frame %d)" % [p.name, score.current_frame() + 1])
	bowler.set_ghost_tint(p.color)
	roster.lock_to(p.pid)
	var shared := roster.players_of(p.pid).size() > 1
	var solo := roster.players.size() == 1
	if not solo:
		hud.turn_banner(p.name, p.color, "Pass the phone to %s" % p.name if shared else "")
	_refresh_hud()
	for q in roster.players:
		if q.pid != p.pid:
			phone_message.emit({"to": q.pid, "type": "turn", "mine": false, "text": "%s is bowling…" % p.name})
	phone_message.emit({"to": p.pid, "type": "turn", "mine": true, "text": "Your turn, %s! Press A when ready" % p.name if not solo else ""})
	phone_message.emit({"to": p.pid, "type": "vibrate", "ms": 120})


func _update_intro() -> void:
	var solo := roster.players.size() == 1
	if (solo and _state_t > 0.3) or (_state_t > 0.6 and Pad.just_pressed(Pad.A)):
		hud.hide_banner()
		_enter_aim()


func _refresh_hud() -> void:
	hud.set_scores(scores, roster.players, cur)


func _full_rack() -> void:
	for p in pins:
		p.reset_to_spot()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	_state_t += delta
	match state:
		State.TURN_INTRO:
			_update_intro()
		State.AIM:
			_update_aim(delta)
		State.SWING:
			_update_swing(delta)
		State.ROLL:
			_update_roll()
		State.SETTLE:
			_update_settle()
		State.RESULT:
			if _state_t > 1.9:
				_next_roll()
	_update_spin()
	_update_bowler(delta)
	_update_camera(delta)
	Sfx.roll(ball.linear_velocity.length() if ball.rolling and ball.global_position.y > -0.15 and ball.global_position.z > -BowlingLane.DECK_END else 0.0)
	hud.set_pins(_standing_mask())
	_refresh_hud()
	if Input.is_key_pressed(KEY_ESCAPE) and state != State.SWING:
		finished.emit("menu")


func _update_aim(delta: float) -> void:
	if Pad.just_pressed(Pad.A):
		mode = Mode.TURN if mode == Mode.MOVE else Mode.MOVE
		Sfx.click(0.8, 1.1 if mode == Mode.TURN else 0.95)
		hud.set_mode(mode == Mode.TURN)
	var dir := (1.0 if Pad.is_down(Pad.RIGHT) else 0.0) - (1.0 if Pad.is_down(Pad.LEFT) else 0.0)
	if mode == Mode.MOVE:
		ball_x = clampf(ball_x + dir * MOVE_SPEED * delta, -MAX_X, MAX_X)
	else:
		angle = clampf(angle + dir * TURN_SPEED * delta, -MAX_ANGLE, MAX_ANGLE)
	_aims[cur] = Vector2(ball_x, angle)
	_place_guides()
	if Pad.just_pressed(Pad.B):
		_start_swing()


func _enter_aim() -> void:
	state = State.AIM
	_state_t = 0.0
	ball.hold(bowler.hand_world)
	_guides.visible = true
	_follow_through = 0.0
	hud.set_mode(mode == Mode.TURN)
	hud.show_hints(true)
	phone_message.emit({"to": player().pid, "type": "hint", "text": "◀ ▶ move/turn · A switch · hold B and swing"})


# ----------------------------------------------------------------- swing

func _start_swing() -> void:
	state = State.SWING
	_state_t = 0.0
	_swing_angle = 0.0
	_back_sign = 0.0
	_keyboard_swing = Pad.instance_motion == null or not Pad.instance_motion.has_data
	_guides.visible = false
	hud.show_hints(false)


func _on_gyro(t: float, rx: float, ry: float) -> void:
	var dt := 1.0 / 60.0 if _last_gyro_t < 0.0 else clampf((t - _last_gyro_t) / 1000.0, 0.0, 0.05)
	_last_gyro_t = t
	_hist.append([t, rx, ry])
	while _hist.size() > 0 and t - float(_hist[0][0]) > 700.0:
		_hist.pop_front()
	if state == State.SWING and not _keyboard_swing:
		_swing_angle += rx * dt
		if _back_sign == 0.0 and absf(_swing_angle) > 12.0:
			_back_sign = signf(_swing_angle) # first big rotation = back swing
	if _spin_pending:
		_spin_accum += ry * dt


func _update_swing(_delta: float) -> void:
	if _keyboard_swing:
		_swing_angle = -minf(_state_t * 190.0, 95.0)
		_back_sign = 1.0
	if Pad.just_released(Pad.B) or (not Pad.is_down(Pad.B) and _state_t > 0.05):
		_release()


func _release() -> void:
	var speed := 0.0
	var spin := 0.0
	if _keyboard_swing:
		speed = remap(clampf(_state_t, 0.15, 0.7), 0.15, 0.7, 4.0, 9.5)
		spin = (0.6 if Input.is_key_pressed(KEY_E) else 0.0) - (0.6 if Input.is_key_pressed(KEY_Q) else 0.0)
		if _state_t < 0.12:
			_cancel_swing()
			return
	else:
		var now_t := _last_gyro_t
		var fwd := 0.0
		for h in _hist:
			if now_t - float(h[0]) <= 130.0:
				var r: float = -_back_sign * float(h[1]) if _back_sign != 0.0 else absf(float(h[1]))
				fwd = maxf(fwd, r)
		if fwd < MIN_FORWARD_RATE:
			_cancel_swing()
			return
		speed = remap(clampf(fwd, 60.0, 650.0), 60.0, 650.0, 3.2, 10.0)
		# wrist twist just before release (continues to be measured a moment after)
		_spin_accum = 0.0
		for h in _hist:
			if now_t - float(h[0]) <= 250.0:
				_spin_accum += float(h[2]) / 60.0
		_spin_pending = true
		_spin_release_t = Time.get_ticks_msec()
	var from := Vector3(bowler.hand_world.x, BowlingBall.RADIUS + 0.004, -0.12)
	var dir := Basis(Vector3.UP, -angle) * Vector3.FORWARD
	ball.launch(from, dir * speed)
	ball.spin = spin
	_follow_through = 1.0
	_standing_before = _count_standing()
	_frame_before = score.current_frame()
	_gutter = false
	state = State.ROLL
	_state_t = 0.0
	hud.show_speed(speed)
	print("[bowling] release speed=%.1f m/s x=%.2f angle=%.1f deg" % [speed, from.x, rad_to_deg(angle)])
	phone_message.emit({"to": player().pid, "type": "hint", "text": "Nice throw!"})


func _cancel_swing() -> void:
	print("[bowling] swing cancelled (too slow)")
	hud.flash("Swing your arm to throw!")
	_enter_aim()


func _update_spin() -> void:
	if not _spin_pending:
		return
	if Time.get_ticks_msec() - _spin_release_t > 140:
		_spin_pending = false
		var twist := _spin_accum
		ball.spin = 0.0 if absf(twist) < 8.0 else clampf(signf(twist) * (absf(twist) - 8.0) / 50.0, -1.0, 1.0)
		print("[bowling] wrist twist=%.0f deg -> spin=%.2f" % [twist, ball.spin])


# -------------------------------------------------------- roll and settle

func _update_roll() -> void:
	var p := ball.global_position
	if absf(p.x) > BowlingLane.LANE_HALF + 0.02 and p.z > -BowlingLane.LANE_LEN + 0.4:
		_gutter = true
	var stalled := ball.linear_velocity.length() < 0.25 and _state_t > 1.0
	if p.z < -BowlingLane.LANE_LEN + 0.7 or p.y < -0.2 or stalled or _state_t > 9.0:
		state = State.SETTLE
		_state_t = 0.0


func _update_settle() -> void:
	var calm := true
	for p in pins:
		if p.visible and (p.linear_velocity.length() > 0.06 or p.angular_velocity.length() > 0.4):
			calm = false
	if (_state_t > 1.6 and calm) or _state_t > 5.0:
		_count_result()


func _count_result() -> void:
	var standing := _count_standing()
	var knocked := maxi(0, _standing_before - standing)
	var text := ""
	if _standing_before == 10 and knocked == 10:
		text = "STRIKE!"
		phone_message.emit({"to": player().pid, "type": "vibrate", "ms": 250})
	elif _standing_before < 10 and standing == 0:
		text = "SPARE!"
		phone_message.emit({"to": player().pid, "type": "vibrate", "ms": 150})
	elif knocked == 0:
		text = "GUTTER" if _gutter else "MISS"
	else:
		text = "%d PIN%s" % [knocked, "" if knocked == 1 else "S"]
	score.add(knocked)
	print("[bowling] %s: %s  (knocked %d, total %d)" % [player().name, text, knocked, score.total()])
	hud.big_message(text, text.ends_with("!"))
	state = State.RESULT
	_state_t = 0.0


func _next_roll() -> void:
	if score.is_over() or score.current_frame() != _frame_before:
		_next_player()
		return
	if score.pins_standing() == 10:
		_full_rack()
	else:
		for p in pins:
			if p.is_standing():
				p.reset_to_spot()
			else:
				p.remove()
	ball.rolling = false
	_enter_aim()


func _next_player() -> void:
	for k in range(1, roster.players.size() + 1):
		var i := (cur + k) % roster.players.size()
		if not scores[i].is_over():
			cur = i
			_start_turn()
			return
	# everyone has finished
	state = State.OVER
	roster.lock_to("")
	Pad.pointer_visible = true
	hud.show_results(scores, roster.players)
	phone_message.emit({"to": "*", "type": "turn", "mine": true, "text": ""})
	phone_message.emit({"to": "*", "type": "hint", "text": "Point and press A"})


func _count_standing() -> int:
	var n := 0
	for p in pins:
		if p.is_standing():
			n += 1
	return n


func _standing_mask() -> Array[bool]:
	var out: Array[bool] = []
	for p in pins:
		out.append(p.is_standing())
	return out


# ---------------------------------------------------------------- visuals

func _update_bowler(delta: float) -> void:
	var base := Vector3(ball_x - 0.33, 0.0, 0.62)
	bowler.position = base
	bowler.rotation.y = -angle
	var target := 0.0
	if state == State.SWING:
		target = deg_to_rad(clampf(-_back_sign * _swing_angle if _back_sign != 0.0 else -absf(_swing_angle) * 0.5, -100.0, 110.0))
	elif _follow_through > 0.0:
		_follow_through = maxf(0.0, _follow_through - delta * 0.7)
		target = deg_to_rad(95.0) * minf(1.0, _follow_through * 2.0)
	_arm = lerpf(_arm, target, 1.0 - exp(-delta * 25.0))
	bowler.swing_angle = _arm
	if state == State.AIM or state == State.SWING or state == State.TURN_INTRO:
		ball.hold(bowler.hand_world + Vector3(0, -0.05, 0))


func _aim_cam_pos() -> Vector3:
	# low and close behind the bowler, lane running up the middle
	return Vector3(ball_x - 0.12, 1.72, 2.75)


func _aim_cam_look() -> Vector3:
	return Vector3(ball_x - 0.12 + sin(angle) * 6.0, 0.55, -16.0)


func _update_camera(delta: float) -> void:
	var tp: Vector3
	var tl: Vector3
	var k := 4.0
	match state:
		State.TURN_INTRO, State.AIM, State.SWING, State.OVER:
			tp = _aim_cam_pos()
			tl = _aim_cam_look()
			k = 6.0
		State.ROLL:
			var b := ball.global_position
			var z := maxf(b.z, -13.5)
			tp = Vector3(b.x * 0.5, 0.75, z + 2.3)
			tl = Vector3(b.x * 0.5, 0.15, z - 6.0)
			k = 8.0
			if b.z < -12.0:
				tp = Vector3(0, 1.0, -14.9)
				tl = Vector3(0, 0.15, -18.8)
				k = 3.0
		_:
			tp = Vector3(0, 1.0, -14.9)
			tl = Vector3(0, 0.15, -18.8)
			k = 3.0
	var f := 1.0 - exp(-delta * k)
	_cam_pos = _cam_pos.lerp(tp, f)
	_cam_look = _cam_look.lerp(tl, f)
	camera.look_at_from_position(_cam_pos, _cam_look)


func _build_guides() -> void:
	_guides = Node3D.new()
	add_child(_guides)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.27, 0.2, 0.85)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var line := Node3D.new()
	line.name = "Line"
	_guides.add_child(line)
	for i in 20:
		var d := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.002, 0.22)
		d.mesh = bm
		d.material_override = red
		d.position = Vector3(0, 0.004, -0.2 - i * 0.42)
		line.add_child(d)
	# straight arrows (Move mode)
	_move_arrows = Node3D.new()
	_guides.add_child(_move_arrows)
	for side in [-1.0, 1.0]:
		var a := MeshInstance3D.new()
		a.mesh = _arrow_mesh(side)
		a.material_override = red
		a.position = Vector3(side * 0.42, 0.005, 0.15)
		_move_arrows.add_child(a)
	# curved arrows (Turn mode)
	_turn_arrows = Node3D.new()
	_guides.add_child(_turn_arrows)
	for side in [-1.0, 1.0]:
		var a := MeshInstance3D.new()
		a.mesh = _arc_arrow_mesh(side)
		a.material_override = red
		a.position = Vector3(0, 0.005, -0.4)
		_turn_arrows.add_child(a)


func _place_guides() -> void:
	var hx := ball_x
	_guides.position = Vector3(hx, 0, 0)
	(_guides.get_node("Line") as Node3D).rotation.y = -angle
	_move_arrows.visible = mode == Mode.MOVE
	_turn_arrows.visible = mode == Mode.TURN


func _arrow_mesh(side: float) -> ArrayMesh:
	var poly := PackedVector2Array([
		Vector2(0.0, -0.035), Vector2(0.22, -0.035), Vector2(0.22, -0.08), Vector2(0.34, 0.0),
		Vector2(0.22, 0.08), Vector2(0.22, 0.035), Vector2(0.0, 0.035)])
	for i in poly.size():
		poly[i].x *= side
	return _flat(poly)


func _arc_arrow_mesh(side: float) -> ArrayMesh:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var r := 0.55
	for i in 13:
		var a := deg_to_rad(8.0 + i * 2.5) * side
		outer.append(Vector2(sin(a) * (r + 0.03), -cos(a) * (r + 0.03)))
		inner.append(Vector2(sin(a) * (r - 0.03), -cos(a) * (r - 0.03)))
	var ae := deg_to_rad(38.0) * side
	var tip := Vector2(sin(ae + 0.12 * side) * r, -cos(ae + 0.12 * side) * r)
	var poly := outer.duplicate()
	poly.append(Vector2(sin(ae) * (r + 0.08), -cos(ae) * (r + 0.08)))
	poly.append(tip)
	poly.append(Vector2(sin(ae) * (r - 0.08), -cos(ae) * (r - 0.08)))
	inner.reverse()
	poly.append_array(inner)
	if side < 0:
		poly.reverse()
	return _flat(poly)


func _flat(poly: PackedVector2Array) -> ArrayMesh:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		poly.reverse()
		idx = Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in idx:
		st.add_vertex(Vector3(poly[i].x, 0, poly[i].y))
	return st.commit()
