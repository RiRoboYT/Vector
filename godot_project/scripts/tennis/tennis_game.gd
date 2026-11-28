class_name TennisGame
extends Node3D
## Doubles tennis, Wii-style: players run to the ball automatically; you swing
## the phone like a racket.
##   Serve: tap B to toss, swing as the ball reaches the top.
##   Rally: swing as the ball reaches you. Early = cross-court, late = down the
##   line, faster swing = harder shot, low-to-high = topspin, high-to-low = slice,
##   slow upward flick = lob, slow downward chop = drop shot.
## Team 0 = near side (z > 0), team 1 = far side.

signal finished(action: String)
signal phone_message(data: Dictionary)

enum Phase { INTRO, SERVE, TOSS, RALLY, POINT_OVER, OVER }

const TEAM_COLORS := [Color("2f8fe0"), Color("ff7a3d")]
const HIT_WINDOW := 0.25 # s either side of the perfect moment
const SWING_START := 260.0 # deg/s
const CPU_NAMES := ["Aria", "Ben", "Cleo", "Dax"]

var roster: Players
var total_games := 1
var difficulty := 1

var court: TennisCourt
var ball: TennisBall
var players: Array[TennisPlayer] = [] # [team0 slot0, team0 slot1, team1 slot0, team1 slot1]
var hud: TennisHud
var score := TennisScore.new()
var camera: Camera3D
var team_names := ["Blue", "Orange"]

var phase := Phase.INTRO
var _t := 0.0
var _clock := 0.0
var _sweet_spot := false
var server: TennisPlayer
var serve_fault := 0 # faults this point
var hitter_team := 0 # team that hit the ball last
var _first_bounce_ok := false
var _is_serve := false
var receiver_player: TennisPlayer # assigned to hit the incoming ball
var hit_point := Vector3.ZERO
var hit_time := 0.0 # seconds from now until the ball reaches hit_point
var _hit_due_ms := 0
var _toss_t := 0.0
var _swings := {} # pid -> swing measurement in progress
var _last_msg := ""
var _point_reason := ""
var _cam_pos := Vector3(0, 6, 22)
var _cam_look := Vector3(0, 0, 0)
# split screen
var _split_layer: CanvasLayer
var _split_cams: Array[Camera3D] = []
var _split_state: Array = [[Vector3(0, 5, 20), Vector3.ZERO], [Vector3(0, 5, -20), Vector3.ZERO]]
var _split_on := false


func _ready() -> void:
	court = TennisCourt.new()
	add_child(court)
	ball = TennisBall.new()
	add_child(ball)
	ball.bounced.connect(_on_bounce)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 600.0
	add_child(camera)
	camera.current = true
	hud = TennisHud.new()
	hud.game = self
	add_child(hud)
	hud.play_again.connect(func(): finished.emit("again"))
	hud.to_menu.connect(func(): finished.emit("menu"))
	_make_players()
	if roster:
		roster.phone_button.connect(_on_button)
		for ph: Players.Phone in roster.phones.values():
			var pid := ph.pid
			ph.motion.gyro_sample.connect(func(t, rx, ry, rz): _on_gyro(pid, t, rx, ry, rz))
	score.setup(total_games, randi() % 2)
	_setup_split.call_deferred()
	phase = Phase.INTRO
	hud.big_message("First to %d game%s" % [score.games_to_win, "" if score.games_to_win == 1 else "s"], false)


# --------------------------------------------------------------- players

func _make_players() -> void:
	var humans: Array = roster.players.duplicate() if roster else []
	if OS.get_cmdline_user_args().has("--cpu-vs-cpu"):
		humans.clear()
	# who controls each of the four (team0 s0, team0 s1, team1 s0, team1 s1)
	var ctl: Array = ["", "", "", ""]
	var names: Array = CPU_NAMES.duplicate()
	match humans.size():
		1:
			ctl = [humans[0].pid, humans[0].pid, "", ""]
			names[0] = humans[0].name
			names[1] = humans[0].name
		2:
			ctl = [humans[0].pid, humans[0].pid, humans[1].pid, humans[1].pid]
			names = [humans[0].name, humans[0].name, humans[1].name, humans[1].name]
		3:
			ctl = [humans[0].pid, humans[1].pid, humans[2].pid, humans[2].pid]
			names = [humans[0].name, humans[1].name, humans[2].name, humans[2].name]
		4:
			ctl = [humans[0].pid, humans[1].pid, humans[2].pid, humans[3].pid]
			names = [humans[0].name, humans[1].name, humans[2].name, humans[3].name]
	for i in 4:
		var p := TennisPlayer.new()
		var team := i / 2
		p.setup(team, i % 2, TEAM_COLORS[team], names[i])
		p.pid = ctl[i]
		add_child(p)
		players.append(p)
	for team in 2:
		var a := players[team * 2]
		var b := players[team * 2 + 1]
		var nm := a.name_ if a.name_ == b.name_ else a.name_ + " & " + b.name_
		team_names[team] = nm if (a.pid != "" or b.pid != "") else "CPU"


func team_players(team: int) -> Array[TennisPlayer]:
	return [players[team * 2], players[team * 2 + 1]]


func is_human(p: TennisPlayer) -> bool:
	return p.pid != ""


func team_human(team: int) -> bool:
	return is_human(players[team * 2]) or is_human(players[team * 2 + 1])


# ------------------------------------------------------------------ points

func _setup_point() -> void:
	ball.kill()
	_place_for_serve()
	phase = Phase.SERVE
	_t = 0.0
	hud.set_call(score.call_text(team_names))
	if is_human(server):
		_msg(server.pid, {"type": "hint", "text": "Tap B to toss, then swing!"})
		_msg(server.pid, {"type": "haptic", "p": "tick"})
	for p in players:
		if is_human(p) and p != server:
			_msg(p.pid, {"type": "hint", "text": "Get ready to return!"})


func _place_for_serve() -> void:
	var st := score.server_team
	# the server rotates within the team each time that team serves
	var team_serves := (score.game_count / 2)
	server = team_players(st)[team_serves % 2]
	var deuce := score.is_deuce_court()
	var f := 1.0 if st == 0 else -1.0 # +z for the near team
	# server's right-hand side: +x for the near team, -x for the far team
	var side := (1.0 if deuce else -1.0) * f
	var receiving := 1 - st
	for p in players:
		var pos: Vector3
		var pf := 1.0 if p.team == 0 else -1.0
		if p == server:
			pos = Vector3(side * 1.0, 0, pf * (TennisCourt.HALF_L + 0.4))
		elif p.team == st:
			pos = Vector3(-side * 2.6, 0, pf * 3.2) # partner at the net
		else:
			var rec := team_players(receiving)[0 if deuce else 1]
			if p == rec:
				pos = Vector3(-side * 2.6, 0, pf * (TennisCourt.HALF_L + 0.3))
			else:
				pos = Vector3(side * 2.4, 0, pf * 3.6)
		p.target = pos
		p.global_position = pos
		p.vel = Vector3.ZERO
	ball.hold(server.global_position + Vector3(0.0, 1.0, 0.0))


## Game clock (ms). Follows frame time so simulations at fixed fps stay in step.
func _now_ms() -> int:
	return int(_clock * 1000.0)


func _process(delta: float) -> void:
	_clock += delta
	_t += delta
	match phase:
		Phase.INTRO:
			if _t > 2.0:
				_setup_point()
		Phase.SERVE:
			ball.hold(server.character.hand_l_world + Vector3(0, 0.05, 0))
			if not is_human(server) and _t > 1.2:
				_toss()
		Phase.TOSS:
			_update_toss(delta)
		Phase.RALLY:
			_update_rally(delta)
		Phase.POINT_OVER:
			if _t > 2.3:
				_after_point()
	_update_camera(delta)
	_update_split(delta)
	if Input.is_key_pressed(KEY_ESCAPE) and phase != Phase.OVER:
		finished.emit("menu")
	# keyboard: Space = B / swing for the near team's first player
	if not roster or roster.players.is_empty() or roster.players[0].pid == "keyboard":
		_keyboard()


func _keyboard() -> void:
	var near := players[0]
	if Input.is_key_pressed(KEY_SPACE) and not get_meta("kb_down", false):
		set_meta("kb_down", true)
		if phase == Phase.SERVE and server.team == 0:
			_toss()
		else:
			_human_swing(near.pid, 650.0, 0.0)
	elif not Input.is_key_pressed(KEY_SPACE):
		set_meta("kb_down", false)


func _on_button(pid: String, id: String, down: bool) -> void:
	if not down or id != Pad.B:
		return
	if phase == Phase.SERVE and server.pid == pid and _t > 0.3:
		_toss()


# ------------------------------------------------------------------- serve

func _toss() -> void:
	phase = Phase.TOSS
	_t = 0.0
	_toss_t = 0.0
	server.serve_toss = 1.0
	var start := server.global_position + Vector3(0.15 * (1.0 if server.team == 0 else -1.0), 1.6, -0.3 * server.facing() * -1.0)
	ball.launch(start, Vector3(0, 5.2, 0), 0.0, 0)
	ball.mode = TennisBall.Mode.FLYING
	if is_human(server):
		_msg(server.pid, {"type": "hint", "text": "Swing when the ball is at the top!"})
		_haptic(server, "tap")


func _update_toss(delta: float) -> void:
	_toss_t += delta
	server.serve_toss = maxf(0.0, server.serve_toss - delta * 2.0)
	# the ball goes up and comes down; apex after ~0.53 s
	if not is_human(server) and _toss_t >= 0.5 and not has_meta("cpu_served"):
		set_meta("cpu_served", true)
		var err: float = randf_range(-0.12, 0.12) * [1.6, 1.0, 0.6][difficulty]
		_serve(randf_range(0.55, 0.95), err)
	if ball.global_position.y < 1.2 and _toss_t > 0.6 and phase == Phase.TOSS:
		# let it drop: toss again
		hud.flash("Toss again")
		_haptic(server, "tick")
		remove_meta("cpu_served")
		_setup_point()


## power 0..1, timing error in seconds (0 = hit at the top of the toss).
func _serve(power: float, timing: float) -> void:
	remove_meta("cpu_served")
	_is_serve = true
	server.start_swing("serve", 3.2)
	var deuce := score.is_deuce_court()
	var st := server.team
	var f := 1.0 if st == 0 else -1.0
	var box_x := -(1.0 if deuce else -1.0) * f # diagonal box
	# early = out wide, late = down the T, perfect = in the box with pace
	var tx := box_x * clampf(2.0 + timing * 6.0 * f * box_x, 0.4, 3.8)
	var tz := -f * (TennisCourt.SERVICE_Z - 0.8 - (1.0 - power) * 1.8)
	var speed := lerpf(32.0, 54.0, power)
	# errors: big timing misses or flat-out power with poor timing
	var miss := absf(timing) / 0.25
	var fault_chance := clampf((miss - 0.45) * 0.9 + power * miss * 0.4, 0.0, 0.95)
	if randf() < fault_chance:
		if randf() < 0.5:
			tz = -f * (TennisCourt.SERVICE_Z + randf_range(0.3, 1.5)) # long
		else:
			tx = box_x * (TennisCourt.HALF_W_SINGLES + randf_range(0.2, 0.9)) # wide
	var from := server.global_position + Vector3(0.1 * f, 2.65, -0.25 * f)
	var res := TennisBall.solve_shot(from, Vector3(tx, 0, tz), speed, 8.0)
	ball.launch(from, res.v, 8.0, st)
	hitter_team = st
	_first_bounce_ok = false
	phase = Phase.RALLY
	_t = 0.0
	Sfx.pin_hit(0.9)
	_haptic(server, "hit")
	hud.speed_info("%d km/h" % roundi(speed * 3.6))
	_assign_receiver()


# ------------------------------------------------------------------- rally

func _assign_receiver() -> void:
	receiver_player = null
	var team := 1 - hitter_team
	var pts := ball.predict(3.0, 0.01)
	var best_t := 1e9
	var best: TennisPlayer = null
	var best_p := Vector3.ZERO
	var best_score := 1e9
	var fallback_d := 1e9
	var fb: TennisPlayer = null
	var fb_p := Vector3.ZERO
	var fb_t := 9.0
	var bounces := 0
	for i in pts.size():
		var p := pts[i]
		# bounce = the height stops falling and starts rising near the ground
		if i >= 2 and pts[i - 1].y < 0.35 and pts[i - 1].y <= pts[i - 2].y and p.y > pts[i - 1].y:
			bounces += 1
			if bounces >= 2:
				break
		var on_their_side := signf(p.z) == (1.0 if team == 0 else -1.0)
		if not on_their_side or absf(p.z) > 15.5:
			continue
		# hittable after the bounce (or a volley near the net before it)
		var volley := bounces == 0 and absf(p.z) < 6.0 and not _is_serve
		if not (bounces == 1 or volley):
			continue
		if p.y < 0.3 or p.y > 1.9:
			continue
		var t := (i + 1) * 0.01
		for pl in team_players(team):
			var stand := _stand_point(pl, p)
			var dist := Vector2(stand.x - pl.global_position.x, stand.z - pl.global_position.z).length()
			var need := dist / TennisPlayer.RUN_SPEED + 0.15
			if need <= t:
				# prefer waist height, then earlier
				var sc := absf(p.y - 1.0) * 1.5 + t * 0.35 + (0.25 if volley and absf(pl.global_position.z) > 7.0 else 0.0)
				if sc < best_score:
					best_score = sc
					best_t = t
					best = pl
					best_p = p
			elif need - t < fallback_d:
				fallback_d = need - t
				fb = pl
				fb_p = p
				fb_t = t
	if best != null:
		_stand_point(best, best_p) # remember forehand / backhand side
	else:
		# unreachable: the closest player still lunges for it
		best = fb if fb != null else team_players(team)[0]
		best_t = fb_t
		best_p = fb_p if fb != null else pts[pts.size() - 1]
	if OS.get_environment("VS_DEBUG") != "":
		var hs := []
		for i in range(0, pts.size(), 10):
			if signf(pts[i].z) == (1.0 if team == 0 else -1.0):
				hs.append("%.1f@%.1f" % [pts[i].y, pts[i].z])
		print("    assign t%d -> s%d at (%.1f,%.2f,%.1f) in %.2fs   path %s" % [team, best.slot, best_p.x, best_p.y, best_p.z, best_t, " ".join(hs.slice(0, 14))])
	receiver_player = best
	hit_point = best_p
	hit_time = best_t
	_hit_due_ms = _now_ms() + int(best_t * 1000.0)
	var tg := _stand_point(best, best_p)
	best.target = Vector3(clampf(tg.x, -8.0, 8.0), 0, clampf(tg.z, -16.0, 16.0))
	# partner covers their half
	for pl in team_players(team):
		if pl != best:
			var f := 1.0 if team == 0 else -1.0
			pl.target = Vector3(clampf(-best_p.x * 0.6, -3.5, 3.5), 0, f * (4.0 if pl.slot == 1 else 10.5))
	if is_human(best):
		_msg(best.pid, {"type": "hint", "text": "Swing!"})


## Where the player stands so the ball is at their forehand (or backhand).
func _stand_point(pl: TennisPlayer, ball_p: Vector3) -> Vector3:
	var right := Vector3(1, 0, 0) if pl.team == 0 else Vector3(-1, 0, 0)
	var rel := (ball_p.x - pl.global_position.x) * right.x
	var side := 1.0 if rel > -0.3 else -1.0 # forehand unless clearly on the backhand
	pl.set_meta("side", side)
	return Vector3(ball_p.x, 0, ball_p.z) - right * side * 0.75 + Vector3(0, 0, 0.35 if pl.team == 0 else -0.35)


func _update_rally(_delta: float) -> void:
	var now := _now_ms()
	if receiver_player != null:
		# computer players hit automatically
		if not is_human(receiver_player):
			if now >= _hit_due_ms and not has_meta("cpu_hit"):
				set_meta("cpu_hit", true)
				_cpu_hit(receiver_player)
		elif now > _hit_due_ms + int(HIT_WINDOW * 1000.0) + 80:
			receiver_player = null # too late: the ball plays on
	if phase != Phase.RALLY:
		return
	# ball out of the stadium, or stopped
	var bp := ball.global_position
	if ball.mode == TennisBall.Mode.FLYING and (absf(bp.z) > 30.0 or absf(bp.x) > 20.0 or (ball.vel.length() < 0.3 and _t > 0.5)):
		_point_to(hitter_team if _first_bounce_ok else 1 - hitter_team, "Winner!" if _first_bounce_ok else "Out!")


## Can this player reach the ball right now?
func _in_reach(p: TennisPlayer) -> bool:
	var b := ball.global_position
	var d := Vector2(b.x - p.global_position.x, b.z - p.global_position.z).length()
	return ball.mode == TennisBall.Mode.FLYING and d < 1.7 and b.y < 2.6


func _cpu_hit(p: TennisPlayer) -> void:
	remove_meta("cpu_hit")
	if not _in_reach(p):
		p.start_swing("fh" if p.get_meta("side", 1.0) > 0.0 else "bh", 3.4)
		receiver_player = null
		return
	var skill: float = [0.66, 0.78, 0.88][difficulty]
	var run_far: float = p.global_position.distance_to(_stand_point(p, hit_point)) / 4.0
	var ok := randf() < skill - run_far * 0.1
	if not ok:
		# mis-hit: framed off the racket, usually long or into the net
		_strike(p, randf_range(0.6, 1.0), randf_range(-1.0, 1.0), randf_range(-1, 1) * 0.0, true)
		return
	_strike(p, randf_range(0.35, 0.85), randf_range(-0.8, 0.8), 1.0 if randf() < 0.7 else -0.6, false)


## A hit: power 0..1, aim -1 (cross-court) .. 1 (down the line), spin_dir
## +1 topspin / -1 slice, wild = framed shot.
func _strike(p: TennisPlayer, power: float, aim: float, spin_dir: float, wild: bool, kind := "") -> void:
	var side: float = p.get_meta("side", 1.0)
	p.start_swing("fh" if side > 0.0 else "bh", 3.4)
	var f := -1.0 if p.team == 0 else 1.0 # direction to the opponents along z
	var from := ball.global_position if ball.global_position.distance_to(hit_point) < 0.8 else hit_point
	# right-hand side of this player is +x for the near team
	var right := 1.0 if p.team == 0 else -1.0
	# down the line keeps the ball on the hitting side; cross-court sends it over
	var line_x := clampf(from.x, -4.2, 4.2)
	var cross_x := -signf(from.x if absf(from.x) > 0.3 else side * right) * 3.8
	var tx := lerpf(cross_x, line_x, (aim + 1.0) * 0.5)
	var depth := lerpf(5.5, 10.2, power)
	var speed := lerpf(17.0, 33.0, power)
	var spin := 32.0 * spin_dir if spin_dir > 0.0 else 24.0 * spin_dir
	match kind:
		"lob":
			speed = 15.0
			depth = 10.0
			spin = 10.0
		"drop":
			speed = 10.0
			depth = 2.6
			spin = -30.0
	var tz := f * depth
	if wild:
		tx += randf_range(-3.2, 3.2)
		tz += f * randf_range(-1.5, 4.5)
	var res := TennisBall.solve_shot(from, Vector3(clampf(tx, -6.5, 6.5), 0, tz), speed, spin)
	# like a real player: take pace off (and add net clearance) until it clears the net
	var tries := 0
	while not res.ok and not wild and tries < 8:
		tries += 1
		speed *= 0.9
		if spin < 0.0:
			spin *= 0.6
		tz = f * minf(absf(tz) + 0.3, 10.8)
		res = TennisBall.solve_shot(from, Vector3(clampf(tx, -6.5, 6.5), 0, tz), speed, spin)
	if OS.get_environment("VS_DEBUG") != "":
		print("  hit t%d s%d from (%.1f,%.2f,%.1f) -> (%.1f,%.1f) %.0fkm/h spin %.0f %s%s" % [p.team, p.slot, from.x, from.y, from.z, tx, tz, speed * 3.6, spin, kind, " WILD" if wild else ""])
	ball.launch(from, res.v, spin, p.team)
	hitter_team = p.team
	_is_serve = false
	_first_bounce_ok = false
	Sfx.pin_hit(clampf(0.4 + power * 0.6, 0.4, 1.0))
	# feel: framed = dull tap, sweet spot = double kick, else by power
	var feel := "strong" if power > 0.75 else "hit"
	if wild:
		feel = "tap"
	elif _sweet_spot:
		feel = "double"
	_sweet_spot = false
	_haptic(p, feel)
	receiver_player = null
	_assign_receiver()


# --------------------------------------------------------------- swings

func _on_gyro(pid: String, _t: float, rx: float, ry: float, rz: float) -> void:
	var mag := Vector3(rx, ry, rz).length()
	var ph: Players.Phone = roster.phones.get(pid)
	if ph == null:
		return
	var sw: Dictionary = _swings.get(pid, {})
	if sw.is_empty():
		if mag > SWING_START:
			_swings[pid] = {"peak": mag, "peak_ms": _now_ms(), "pitch0": ph.motion.raw_pitch}
		return
	if mag > sw.peak:
		sw.peak = mag
		sw.peak_ms = _now_ms()
	if mag < sw.peak * 0.35 or _now_ms() - int(sw.peak_ms) > 400:
		var dpitch := rad_to_deg(ph.motion.raw_pitch - float(sw.pitch0))
		_swings.erase(pid)
		_human_swing(pid, sw.peak, dpitch, int(sw.peak_ms))


## A completed phone swing: peak rate (deg/s), change of pitch (deg, + = finished higher).
func _human_swing(pid: String, peak: float, dpitch: float, peak_ms := -1) -> void:
	if peak_ms < 0:
		peak_ms = _now_ms()
	if phase == Phase.TOSS and server.pid == pid:
		var apex_ms := 530
		var timing := (_toss_t * 1000.0 - apex_ms) / 1000.0
		_serve(clampf((peak - 250.0) / 700.0, 0.2, 1.0), timing)
		return
	if phase != Phase.RALLY:
		return
	# which of this phone's players is due to hit?
	var p := receiver_player
	if p == null or p.pid != pid:
		for q in players:
			if q.pid == pid:
				q.start_swing("fh", 3.4) # an air swing
				break
		return
	var dt := float(peak_ms - _hit_due_ms) / 1000.0 # + = late
	if OS.get_environment("VS_DEBUG") != "":
		var b := ball.global_position
		print("  swing %s dt %+.3f peak %.0f dpitch %.0f reach %s (ball %.1f,%.1f,%.1f player %.1f,%.1f)" % [pid, dt, peak, dpitch, _in_reach(p), b.x, b.y, b.z, p.global_position.x, p.global_position.z])
	if absf(dt) > HIT_WINDOW:
		p.start_swing("fh" if p.get_meta("side", 1.0) > 0.0 else "bh", 3.4)
		hud.flash("Too early!" if dt < 0.0 else "Too late!")
		_haptic(p, "tick")
		return
	# Wii-style assist: a swing inside the timing window connects as long as
	# the player got to the ball's path (the ball is still near the hit point)
	var near_path := ball.mode == TennisBall.Mode.FLYING and ball.global_position.distance_to(hit_point) < 4.5 and ball.global_position.y < 2.8
	if not (_in_reach(p) or near_path):
		p.start_swing("fh" if p.get_meta("side", 1.0) > 0.0 else "bh", 3.4)
		hud.flash("Missed!")
		_haptic(p, "tick")
		receiver_player = null
		return
	var power := clampf((peak - 250.0) / 750.0, 0.1, 1.0)
	var aim := clampf(dt / HIT_WINDOW, -1.0, 1.0) # early = cross-court, late = down the line
	var spin_dir := 1.0 if dpitch > -12.0 else -1.0
	var kind := ""
	if power < 0.3 and dpitch > 30.0:
		kind = "lob"
	elif power < 0.3 and dpitch < -25.0:
		kind = "drop"
	# mistimed or over-hit swings can fly off the frame
	var risk := clampf((absf(dt) / HIT_WINDOW - 0.45) * 1.1 + maxf(power - 0.85, 0.0) * 1.2, 0.0, 0.8)
	var wild := randf() < risk
	_sweet_spot = absf(dt) < 0.06
	_strike(p, power, aim, spin_dir, wild, kind)


# ----------------------------------------------------------- line calls

func _on_bounce(pos: Vector3) -> void:
	if phase != Phase.RALLY:
		return
	if OS.get_environment("VS_DEBUG") != "":
		print("    bounce %d at (%.1f, %.1f) hitter t%d serve=%s" % [ball.bounces, pos.x, pos.z, hitter_team, _is_serve])
	var side := 0 if pos.z > 0.0 else 1 # team whose half it bounced in
	if ball.bounces == 1:
		if side == hitter_team:
			_fault_or_point("Net!" if absf(pos.z) < 3.0 else "Out!")
			return
		var inside := TennisCourt.in_service_box(pos, 1 if hitter_team == 0 else -1, score.is_deuce_court()) if _is_serve else TennisCourt.in_doubles(pos)
		if not inside:
			_fault_or_point("Out!" if not _is_serve else "Fault")
			return
		_first_bounce_ok = true
	elif ball.bounces >= 2 and _first_bounce_ok:
		# not returned: the hitter wins the point
		_point_to(hitter_team, "Ace!" if _is_serve else "Winner!")


func _fault_or_point(call: String) -> void:
	if _is_serve:
		serve_fault += 1
		if serve_fault >= 2:
			_point_to(1 - hitter_team, "Double fault")
		else:
			hud.big_message("Fault", false)
			_haptic(server, "long")
			ball.kill()
			phase = Phase.POINT_OVER
			_t = 1.3 # quicker restart
			set_meta("second_serve", true)
		return
	_point_to(1 - hitter_team, call)


func _point_to(team: int, call: String) -> void:
	if phase != Phase.RALLY:
		return
	phase = Phase.POINT_OVER
	_t = 0.0
	ball.kill()
	var res := score.point_to(team)
	print("[tennis] %s -> point %s (%s)  games %d-%d" % [call, team_names[team], res, score.games[0], score.games[1]])
	var msg := call
	if res == "game":
		msg += "  ·  Game " + team_names[team]
	elif res == "match":
		msg = "Game, set and match!"
	hud.big_message(msg, team == 0 or res == "match")
	var buzzed := {}
	for p in players:
		if is_human(p) and not buzzed.has(p.pid):
			buzzed[p.pid] = true
			var won := p.team == team
			var feel := "double" if won else "tick"
			if res == "game":
				feel = "strong" if won else "tick"
			elif res == "match":
				feel = "long" if won else "out"
			elif call == "Double fault" and p.pid == server.pid:
				feel = "out"
			_msg(p.pid, {"type": "haptic", "p": feel})
	set_meta("result", res)


func _after_point() -> void:
	var res: String = get_meta("result", "point")
	if has_meta("second_serve"):
		remove_meta("second_serve")
		# second serve, same point
		_place_for_serve()
		phase = Phase.SERVE
		_t = 0.0
		return
	remove_meta("result")
	serve_fault = 0
	if res == "match":
		phase = Phase.OVER
		Pad.pointer_visible = true
		hud.show_results()
		phone_message.emit({"to": "*", "type": "hint", "text": "Point and press A"})
		return
	_setup_point()


# -------------------------------------------------------------- helpers

func _msg(pid: String, data: Dictionary) -> void:
	if pid == "" or pid == "keyboard":
		return
	var d := data.duplicate()
	d["to"] = pid
	phone_message.emit(d)


func _haptic(p: TennisPlayer, kind: String) -> void:
	if is_human(p):
		_msg(p.pid, {"type": "haptic", "p": kind})


# --------------------------------------------------------------- camera

func _cam_for(team: int) -> Array:
	var f := 1.0 if team == 0 else -1.0
	var bx := ball.global_position.x if ball.mode == TennisBall.Mode.FLYING else 0.0
	return [Vector3(bx * 0.3, 7.4, f * 23.5), Vector3(bx * 0.2, 0.0, -f * 2.0)]


func _update_camera(delta: float) -> void:
	var c := _cam_for(0)
	var k := 1.0 - exp(-delta * 3.0)
	_cam_pos = _cam_pos.lerp(c[0], k)
	_cam_look = _cam_look.lerp(c[1], k)
	camera.look_at_from_position(_cam_pos, _cam_look)


func _setup_split() -> void:
	if not (team_human(0) and team_human(1)):
		return
	_split_layer = CanvasLayer.new()
	_split_layer.layer = 0
	add_child(_split_layer)
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split_layer.add_child(bg)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	_split_layer.add_child(box)
	var world := get_viewport().find_world_3d()
	for i in 2:
		var c := SubViewportContainer.new()
		c.stretch = true
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(c)
		var vp := SubViewport.new()
		vp.world_3d = world
		vp.msaa_3d = Viewport.MSAA_2X
		c.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 55.0
		cam.far = 600.0
		vp.add_child(cam)
		cam.current = true
		_split_cams.append(cam)
	_split_on = true
	get_viewport().disable_3d = true


func _update_split(delta: float) -> void:
	if not _split_on:
		return
	var k := 1.0 - exp(-delta * 3.0)
	for i in 2:
		var c := _cam_for(i)
		_split_state[i][0] = (_split_state[i][0] as Vector3).lerp(c[0], k)
		_split_state[i][1] = (_split_state[i][1] as Vector3).lerp(c[1], k)
		_split_cams[i].look_at_from_position(_split_state[i][0], _split_state[i][1])


func _exit_tree() -> void:
	get_viewport().disable_3d = false
