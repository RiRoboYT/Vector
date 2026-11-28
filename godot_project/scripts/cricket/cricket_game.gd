class_name CricketGame
extends Node3D
## A cricket match: Super Over / 2 overs / 5 overs, players vs players or
## players vs computer. One delivery at a time:
##   BAT_SETUP  batter shuffles with ◀ ▶ and taps B when ready (bat calibrated)
##   FIELD_SET  bowler moves fielders on the minimap (▲ ▼ ◀ ▶, A pick/drop,
##              B done); real limits on fielders outside the 30-yard circle
##   AIM        bowler sets line (◀ ▶) and length (▲ ▼), A = Fast/Medium/Spin;
##              hold B to start the run-up
##   RUNUP      bowler runs in; letting go of B releases (arm speed = pace,
##              wrist twist = swing / spin)
##   DELIVERY   ball in flight; the bat follows the batter's phone 1:1
##   PLAY       fielding / running (CricketPlay) until the ball is dead

signal finished(action: String)
signal phone_message(data: Dictionary)

enum Phase { INTRO, BAT_SETUP, FIELD_SET, AIM, RUNUP, DELIVERY, PLAY, RESULT, BREAK, OVER }
enum Kind { FAST, MEDIUM, SPIN }

const KIND_NAMES := ["Fast", "Medium", "Spin"]
const SPEED_RANGE := [[125.0, 150.0], [105.0, 125.0], [72.0, 92.0]] # km/h
const TEAM_COLORS := [Color("2f8fe0"), Color("ff7a3d")]
const CPU_NAMES := ["Arjun", "Kabir", "Rohan", "Dev", "Ishan", "Neel", "Aarav", "Veer", "Kian", "Omar", "Leo"]

var roster: Players
var overs := 1
var super_over := true
var difficulty := 1 # 0 easy, 1 medium, 2 hard (CPU skill + batting assist)

var field: CricketField
var ball: CricketBall
var play: CricketPlay
var rig: BatterRig
var camera: Camera3D
var hud: CricketHud
var score := CricketScore.new()

var teams: Array = [] # [{name, color, cpu, players: Array[Players.Player], names: Array[String]}]
var phase := Phase.INTRO
var _t := 0.0
var bat_team := 0
var batter_names := ["", ""] # [striker, non-striker]
var _next_batter := 0
var bowler_name := ""
var _bowler_idx := 0
var field_pos: Array[Vector3] = [] # 9 outfielders, right-hander layout
var _sel := 0
var _holding := false
var aim := Vector2(0.15, -5.5) # x line, z where it should pitch
var kind := Kind.FAST
var _release := {}
var _hit := false
var _passed := false
var _r_cal := Basis.IDENTITY
var _cam_pos := Vector3(0, 20, -50)
var _cam_look := Vector3(0, 0, -10)
var _runup_t := 0.0
var _released := false
var _cpu_shot := {}
var _ball_kind := Kind.FAST
var _wide_checked := false
var _marker: MeshInstance3D
# bowling timing meter: marker sweeps -1..1; tap B to lock it
const METER_PERFECT := 0.12
const METER_RED := 0.88
const METER_FREQ := [1.1, 0.9, 0.75] # sweeps per second (Fast, Medium, Spin)
var meter := 0.0
var meter_locked := false
var meter_result := "" # "perfect" | "good" | "noball" | "wide"
var _meter_t := 0.0
var _lock_t := 0.0
var _sw := {} # half-swing measurement
var _noball := false
var free_hit := false
# split screen (player vs player): [0] = bowler view (left), [1] = batter view (right)
var _split_layer: CanvasLayer
var _split_cams: Array[Camera3D] = []
var _split_labels: Array[Label] = []
var _split_cam_state: Array = [[Vector3(0, 3, -30), Vector3(0, 0, 0)], [Vector3(0, 2, 2), Vector3(0, 0, -20)]]
var _split_on := false


func _ready() -> void:
	field = CricketField.new()
	add_child(field)
	ball = CricketBall.new()
	ball.field = field
	add_child(ball)
	rig = BatterRig.new()
	add_child(rig)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.05
	camera.far = 600.0
	add_child(camera)
	camera.current = true
	hud = CricketHud.new()
	add_child(hud)
	hud.play_again.connect(func(): finished.emit("again"))
	hud.to_menu.connect(func(): finished.emit("menu"))
	play = CricketPlay.new()
	play.field = field
	play.ball = ball
	add_child(play)
	play.finished.connect(_on_play_finished)
	play.message.connect(func(t): hud.big_message(t, t.ends_with("!")))
	ball.hit_stumps.connect(_on_ball_hit_stumps)
	if roster:
		roster.gyro_sample.connect(_on_gyro)
	# where the bowler is aiming to pitch the ball
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.22
	tm.rings = 32
	_marker.mesh = tm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color("ffb020")
	mm.emission_enabled = true
	mm.emission = Color("ffb020")
	mm.emission_energy_multiplier = 0.6
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mm
	_marker.scale = Vector3(1, 0.2, 1)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_setup_split.call_deferred()
	rig.setup(TEAM_COLORS[0], false)
	rig.bat.contact.connect(_on_bat_contact)
	_make_teams()
	var toss := randi() % 2
	if OS.get_environment("VS_TOSS") != "": # test helper
		toss = int(OS.get_environment("VS_TOSS"))
	score.team_names = [teams[0].name, teams[1].name]
	score.setup(overs, super_over, toss)
	bat_team = toss
	_build_sides()
	hud.big_message("%s bat first" % teams[toss].name, false)
	phase = Phase.INTRO
	_t = 0.0


# ----------------------------------------------------------------- teams

func _make_teams() -> void:
	var humans := roster.players.duplicate()
	var a: Array[Players.Player] = []
	var b: Array[Players.Player] = []
	var cpu_only := OS.get_cmdline_user_args().has("--cpu-vs-cpu")
	if not cpu_only:
		for i in humans.size():
			(a if i % 2 == 0 else b).append(humans[i])
	teams = [
		{"name": "Blue", "color": TEAM_COLORS[0], "cpu": a.is_empty(), "players": a, "names": []},
		{"name": "Orange", "color": TEAM_COLORS[1], "cpu": b.is_empty(), "players": b, "names": []},
	]
	for t in teams:
		var names: Array[String] = []
		for p in t.players:
			names.append(p.name)
		var k := 0
		while names.size() < 11:
			var n: String = CPU_NAMES[(k + (0 if t == teams[0] else 5)) % CPU_NAMES.size()]
			if not names.has(n):
				names.append(n)
			k += 1
		t.names = names
		if t.cpu:
			t.name = "CPU " + t.name


func _team_human(team: int, name: String) -> Players.Player:
	for p in teams[team].players:
		if p.name == name:
			return p
	# filler batters/bowlers are controlled by the team's first human
	return teams[team].players[0] if not teams[team].players.is_empty() else null


func _is_cpu(team: int) -> bool:
	return teams[team].cpu


func field_team() -> int:
	return 1 - bat_team


func _build_sides() -> void:
	# (re)create fielders for the fielding side and runners for the batting side
	for c in play.get_children():
		c.queue_free()
	play.fielders.clear()
	play.runners.clear()
	var fcol: Color = teams[field_team()].color
	var bcol: Color = teams[bat_team].color
	_next_batter = 0
	batter_names = [teams[bat_team].names[0], teams[bat_team].names[1]]
	_next_batter = 2
	_bowler_idx = 0
	field_pos = _preset(score.max_outside_circle())
	for i in 9:
		play.fielders.append(play.make_mover(teams[field_team()].names[i + 2], fcol, field_pos[i], i < 5))
	play.keeper = play.make_mover(teams[field_team()].names[1], fcol.darkened(0.2), Vector3(0.3, 0, 9.0))
	play.bowler = play.make_mover(teams[field_team()].names[0], fcol, Vector3(0.6, 0, CricketField.BOWL_Z - 10))
	play.runners.append(play.make_runner(batter_names[0], bcol, 0))
	play.runners.append(play.make_runner(batter_names[1], bcol, 1))
	play.snap_home()
	rig.setup(bcol, _lefty(batter_names[0]))
	if not rig.bat.contact.is_connected(_on_bat_contact):
		rig.bat.contact.connect(_on_bat_contact)
	play.catch_skill = [0.72, 0.84, 0.93][difficulty] if _is_cpu(field_team()) else 0.86
	play.risk = 0.7


func _lefty(name: String) -> bool:
	var p := _team_human(bat_team, name)
	return p != null and p.name == name and p.get_meta("left", false)


# ---------------------------------------------------------- field setting

## Right-hander layouts (off side = +X, behind the wicket = +Z).
func _preset(max_out: int) -> Array[Vector3]:
	var inside := [Vector3(1.8, 0, 3.4), Vector3(7, 0, 1.0), Vector3(16, 0, -1), Vector3(16, 0, -11),
		Vector3(8, 0, -20), Vector3(-8, 0, -20), Vector3(-16, 0, -10), Vector3(-16, 0, -1), Vector3(-9, 0, 9)]
	var outside := [Vector3(-30, 0, 40), Vector3(28, 0, -62), Vector3(-28, 0, -62), Vector3(40, 0, 32), Vector3(-50, 0, -8)]
	var out: Array[Vector3] = []
	var n_out := mini(max_out, 4 if max_out >= 5 else max_out)
	for i in n_out:
		out.append(outside[i])
	var i2 := 0
	while out.size() < 9:
		out.append(inside[i2])
		i2 += 1
	return out


func outside_count(positions: Array[Vector3]) -> int:
	var n := 0
	for p in positions:
		if not CricketField.inside_circle(p):
			n += 1
	return n


func _mirror() -> float:
	return -1.0 if rig.left_handed else 1.0


func _apply_field() -> void:
	for i in 9:
		var p := field_pos[i]
		play.fielders[i].home = Vector3(p.x * _mirror(), 0, p.z)
		play.fielders[i].target = play.fielders[i].home


# ------------------------------------------------------------------ ball

func _begin_ball() -> void:
	_hit = false
	_passed = false
	_released = false
	_wide_checked = false
	_cpu_shot = {}
	field.striker_stumps.reset()
	field.bowler_stumps.reset()
	rig.visible = true
	rig.lift = 0.0
	rig.stance_x = 0.0
	rig.reach_x = 0.0
	rig.setup(teams[bat_team].color, _lefty(batter_names[0]))
	if not rig.bat.contact.is_connected(_on_bat_contact):
		rig.bat.contact.connect(_on_bat_contact)
	rig.apply_rotation(Basis.IDENTITY)
	rig.bat.reset_motion()
	var ab: float = [0.8, 0.55, 0.25][difficulty]
	rig.bat.assist_width = float([0.035, 0.02, 0.0][difficulty])
	set_meta("assist", ab)
	play.runners[0].name = batter_names[0]
	play.runners[1].name = batter_names[1]
	play.reset_positions(kind != Kind.SPIN, rig)
	_apply_field()
	bowler_name = teams[field_team()].names[_bowler_idx % teams[field_team()].names.size()]
	play.bowler.name = bowler_name
	var bc := play.bowler.ch
	bc.hand_targets = false
	bc.bowling = true
	bc.global_position = Vector3(0.9, 0, CricketField.BOWL_Z - 11.0)
	bc.rotation.y = PI
	play.bowler.frozen = true
	play.bowler.vel = Vector3.ZERO
	ball.hold(bc.global_position + Vector3(0, 1.0, 0))
	hud.set_state(self)
	_send_turn_messages()
	if _is_cpu(bat_team):
		_enter(Phase.FIELD_SET if not _is_cpu(field_team()) else Phase.RUNUP)
		if _is_cpu(field_team()):
			_cpu_choose_delivery()
	else:
		_enter(Phase.BAT_SETUP)


func _enter(p: Phase) -> void:
	phase = p
	_t = 0.0
	hud.set_phase(self)
	match p:
		Phase.BAT_SETUP:
			var h := _team_human(bat_team, batter_names[0])
			if h:
				roster.lock_to(h.pid)
				_msg(h.pid, {"type": "layout", "dpad": false})
				_msg(h.pid, {"type": "hint", "text": "◀ ▶ move · point the phone at the floor like a grounded bat, tap B"})
		Phase.FIELD_SET:
			if _is_cpu(field_team()):
				_cpu_choose_delivery()
				_enter(Phase.RUNUP)
				return
			var h := _team_human(field_team(), bowler_name)
			if h:
				roster.lock_to(h.pid)
				_msg(h.pid, {"type": "layout", "dpad": true})
				_msg(h.pid, {"type": "hint", "text": "▲ ▼ ◀ ▶ select · A pick up / drop · B done"})
			_sel = 0
			_holding = false
		Phase.AIM:
			aim = Vector2(0.15 * _mirror(), -5.5) # start on a good length
			var h := _team_human(field_team(), bowler_name)
			if h:
				_msg(h.pid, {"type": "layout", "dpad": true})
				_msg(h.pid, {"type": "hint", "text": "◀ ▶ line · ▲ ▼ length · A type · tap B to run in"})
		Phase.RUNUP:
			_runup_t = 0.0
			_released = false
			_release = {}
			meter_locked = false
			meter_result = ""
			_meter_t = randf() * 2.0
			_noball = false
			var hb := _team_human(field_team(), bowler_name)
			if hb and not _is_cpu(field_team()):
				_msg(hb.pid, {"type": "hint", "text": "Tap B when the marker is in the green!"})
		Phase.DELIVERY:
			var h := _team_human(bat_team, batter_names[0])
			if h and not _is_cpu(bat_team):
				roster.lock_to(h.pid)
				_msg(h.pid, {"type": "hint", "text": "Swing!"})


func _haptic_batter(p: String) -> void:
	if not _is_cpu(bat_team):
		var h := _team_human(bat_team, batter_names[0])
		if h:
			_msg(h.pid, {"type": "haptic", "p": p})


func _haptic_bowler(p: String) -> void:
	if not _is_cpu(field_team()):
		var h := _team_human(field_team(), bowler_name)
		if h:
			_msg(h.pid, {"type": "haptic", "p": p})


func _msg(pid: String, data: Dictionary) -> void:
	var d := data.duplicate()
	d["to"] = pid
	phone_message.emit(d)


func _send_turn_messages() -> void:
	var bat_h := _team_human(bat_team, batter_names[0])
	var bowl_h := _team_human(field_team(), bowler_name)
	for p in roster.players:
		var mine := (bat_h != null and p.pid == bat_h.pid) or (bowl_h != null and p.pid == bowl_h.pid)
		var text := "" if mine else "%s is batting, %s is bowling" % [batter_names[0], bowler_name]
		phone_message.emit({"to": p.pid, "type": "turn", "mine": mine, "text": text})


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	_t += delta
	match phase:
		Phase.INTRO:
			if _t > 2.0:
				_begin_ball()
		Phase.BAT_SETUP:
			_update_bat_setup(delta)
		Phase.FIELD_SET:
			_update_field_set(delta)
		Phase.AIM:
			_update_aim(delta)
		Phase.RUNUP:
			_update_runup(delta)
		Phase.DELIVERY:
			_update_delivery(delta)
		Phase.RESULT:
			if _t > 2.2:
				_next()
		Phase.BREAK:
			if _t > 3.5:
				_start_second_innings()
	_update_camera(delta)
	_update_split(delta)
	_marker.visible = (phase == Phase.AIM or phase == Phase.RUNUP) and not _is_cpu(field_team())
	_marker.position = Vector3(aim.x, 0.02, aim.y)
	hud.set_state(self)
	if Input.is_key_pressed(KEY_ESCAPE) and phase != Phase.OVER:
		finished.emit("menu")


func _physics_process(delta: float) -> void:
	# bat follows the phone at physics rate during the delivery
	if phase == Phase.DELIVERY or phase == Phase.BAT_SETUP:
		if not _is_cpu(bat_team):
			_pose_bat_from_phone()
		if phase == Phase.DELIVERY:
			_assist(delta)
			if _is_cpu(bat_team):
				_cpu_bat(delta)
			else:
				rig.bat.physics_check(ball, delta)


func _phone_motion() -> MotionInput:
	return Pad.instance_motion


func _pose_bat_from_phone() -> void:
	var m := _phone_motion()
	if m == null or not m.has_data:
		# keyboard: Space swings the bat
		var phi := -0.3
		if Input.is_key_pressed(KEY_SPACE):
			phi = clampf(get_meta("kb_phi", -1.8) + 0.22, -1.8, 1.3)
		else:
			phi = maxf(get_meta("kb_phi", -0.3) - 0.08, -0.3)
		set_meta("kb_phi", phi)
		var psi := (0.5 if Input.is_key_pressed(KEY_LEFT) else 0.0) - (0.5 if Input.is_key_pressed(KEY_RIGHT) else 0.0)
		rig.apply_rotation(BatterRig.swing_rotation(phi, psi * _mirror()))
		return
	# stance pose = phone pointing at the floor (top down), screen to the TV:
	# bat "up" is the phone's bottom edge, so turn the phone frame 180° about Z
	var d := _r_cal.transposed() * m.device_basis()
	var map := Basis(Vector3(0, 0, 1), PI)
	var delta := map * d * map.transposed()
	var st := rig.stance_transform().basis
	rig.apply_rotation(st * delta * st.transposed())


func _update_bat_setup(delta: float) -> void:
	var dir := (1.0 if Pad.is_down(Pad.RIGHT) else 0.0) - (1.0 if Pad.is_down(Pad.LEFT) else 0.0)
	rig.stance_x = clampf(rig.stance_x + dir * 0.8 * delta, -0.5, 0.25)
	if Pad.just_pressed(Pad.B) and _t > 0.3:
		var m := _phone_motion()
		if m and m.has_data:
			_r_cal = m.device_basis()
		rig.bat.reset_motion()
		Sfx.click(0.9, 1.2)
		_enter(Phase.FIELD_SET)


func _update_field_set(delta: float) -> void:
	var max_out := score.max_outside_circle()
	var mv := Vector2((1.0 if Pad.is_down(Pad.RIGHT) else 0.0) - (1.0 if Pad.is_down(Pad.LEFT) else 0.0),
		(1.0 if Pad.is_down(Pad.DOWN) else 0.0) - (1.0 if Pad.is_down(Pad.UP) else 0.0))
	if _holding:
		var p := field_pos[_sel]
		p += Vector3(mv.x * _mirror(), 0, mv.y) * 18.0 * delta
		# stay on the field and off the pitch
		var c := p - CricketField.CENTER
		if Vector2(c.x, c.z).length() > CricketField.BOUNDARY - 3.0:
			var n := Vector2(c.x, c.z).normalized() * (CricketField.BOUNDARY - 3.0)
			p = CricketField.CENTER + Vector3(n.x, 0, n.y)
		if absf(p.x) < 3.0 and p.z < 3.0 and p.z > CricketField.BOWL_Z - 2.0:
			p.x = 3.0 * signf(p.x if p.x != 0.0 else 1.0)
		field_pos[_sel] = p
		_apply_field()
	else:
		for d in [[Pad.UP, Vector2(0, -1)], [Pad.DOWN, Vector2(0, 1)], [Pad.LEFT, Vector2(-1, 0)], [Pad.RIGHT, Vector2(1, 0)]]:
			if Pad.just_pressed(d[0]):
				_sel = _nearest_in_dir(_sel, d[1])
				Sfx.click(0.4, 1.3)
	if Pad.just_pressed(Pad.A):
		if _holding:
			if outside_count(field_pos) > max_out:
				hud.flash("Max %d fielders outside the circle%s!" % [max_out, " in the powerplay" if score.in_powerplay() else ""])
				return
			_holding = false
		else:
			_holding = true
		Sfx.click()
	if Pad.just_pressed(Pad.B) and _t > 0.3:
		if outside_count(field_pos) > max_out:
			hud.flash("Max %d fielders outside the circle!" % max_out)
		else:
			_holding = false
			_enter(Phase.AIM)


func _nearest_in_dir(from: int, dir: Vector2) -> int:
	var a := field_pos[from]
	var best := from
	var best_s := 1e9
	for i in field_pos.size():
		if i == from:
			continue
		var d := Vector2((field_pos[i].x - a.x) * _mirror(), field_pos[i].z - a.z)
		var along := d.dot(dir)
		if along <= 0.5:
			continue
		var s := along + absf(d.cross(dir)) * 2.0
		if s < best_s:
			best_s = s
			best = i
	return best


func _update_aim(delta: float) -> void:
	var mx := (1.0 if Pad.is_down(Pad.RIGHT) else 0.0) - (1.0 if Pad.is_down(Pad.LEFT) else 0.0)
	var mz := (1.0 if Pad.is_down(Pad.DOWN) else 0.0) - (1.0 if Pad.is_down(Pad.UP) else 0.0)
	aim.x = clampf(aim.x + mx * 0.6 * delta, -1.2, 1.2)
	aim.y = clampf(aim.y + mz * 4.0 * delta, -12.0, -0.6)
	if Pad.just_pressed(Pad.A):
		kind = ((kind + 1) % 3) as Kind
		Sfx.click(0.8, 1.1)
	if Pad.just_pressed(Pad.B) and _t > 0.3:
		_enter(Phase.RUNUP)


func _cpu_choose_delivery() -> void:
	var r := randf()
	kind = Kind.SPIN if r < 0.3 else (Kind.MEDIUM if r < 0.55 else Kind.FAST)
	var mirror := _mirror()
	var lengths := [-5.5, -6.0, -4.5, -7.0]
	var z: float = lengths[randi() % lengths.size()]
	if randf() < 0.12:
		z = -1.4 # yorker
	elif randf() < 0.1:
		z = -10.5 # bouncer
	aim = Vector2((0.15 + randf_range(-0.2, 0.25)) * mirror, z)
	var effort := randf_range(0.45, 0.95)
	var twist: float = randf_range(-1.0, 1.0) * [0.4, 0.7, 1.0][difficulty]
	set_meta("cpu_release", [effort, twist])
	# the CPU's field is always legal
	field_pos = _preset(score.max_outside_circle())
	_apply_field()


func _update_runup(delta: float) -> void:
	_runup_t += delta
	var human := not _is_cpu(field_team())
	var bc := play.bowler.ch
	var run_time := 1.7
	var p := clampf(_runup_t / run_time, 0.0, 1.0)
	var start_z := CricketField.BOWL_Z - 11.0
	var crease_z := CricketField.BOWL_Z + 0.9
	bc.global_position = Vector3(lerpf(0.9, 0.35, p), 0, lerpf(start_z, crease_z, ease(p, 1.2)))
	bc.step_phase += delta * (5.0 + p * 7.0)
	bc.walk_amount = 1.0 if p < 1.0 else 0.0
	bc.lean = 0.15 + p * 0.1
	if human:
		_update_meter(delta, run_time)
		if phase != Phase.RUNUP:
			return
	elif _release.is_empty():
		var cr: Array = get_meta("cpu_release", [0.7, 0.0])
		_release = {"effort": cr[0], "swing": cr[1], "twist": cr[1], "err": 0.08}
	# arm pumps during the run, then comes over the top when the release is ready
	if p < 0.82:
		bc.swing_angle = sin(_runup_t * 9.0) * 0.5
	else:
		var q := clampf((p - 0.82) / 0.18 + maxf(0.0, _runup_t - run_time) * 4.0, 0.0, 1.6)
		if _release.is_empty():
			q = minf(q, 0.85) # gathered, waiting for the half swing
		bc.swing_angle = -q * PI * 1.25
		if q >= 1.0 and not _released and not _release.is_empty():
			_bowl()
	if _released and _runup_t > run_time + 0.5:
		# follow through then become a fielder again
		bc.bowling = false
		bc.hand_targets = true
		play.bowler.frozen = false
		play.bowler.target = Vector3(0.8, 0, CricketField.BOWL_Z + 4.0)


## Timing meter, then the half swing.
func _update_meter(delta: float, run_time: float) -> void:
	if not meter_locked:
		_meter_t += delta * METER_FREQ[kind]
		var x := fmod(_meter_t, 2.0)
		meter = (x if x < 1.0 else 2.0 - x) * 2.0 - 1.0
		if Pad.just_pressed(Pad.B):
			_lock_meter()
		elif _runup_t > run_time + 0.6:
			_dead_ball()
		return
	_lock_t += delta
	if _release.is_empty():
		var m := _phone_motion()
		if m == null or not m.has_data:
			# keyboard: no half swing to read
			_finish_swing(0.0, (0.6 if Input.is_key_pressed(KEY_E) else 0.0) - (0.6 if Input.is_key_pressed(KEY_Q) else 0.0))
		elif _lock_t > 1.3:
			_finish_swing(0.0, 0.0) # no swing made: bowl it straight
		elif _sw.get("started", false) and (_sw.get("ended", false) or _lock_t - float(_sw.get("t0", 0.0)) > 0.7):
			var w: float = maxf(_sw.get("w", 0.0), 0.001)
			_finish_swing(float(_sw.get("ang", 0.0)) / w, float(_sw.get("twist", 0.0)))


func _lock_meter() -> void:
	meter_locked = true
	_lock_t = 0.0
	_sw = {}
	var a := absf(meter)
	if a <= METER_PERFECT:
		meter_result = "perfect"
	elif a < METER_RED:
		meter_result = "good"
	else:
		meter_result = "noball" if meter > 0.0 else "wide"
	Sfx.click(1.0, 1.5 if meter_result == "perfect" else 1.0)
	_haptic_bowler("double" if meter_result == "perfect" else "tap")
	hud.flash({"perfect": "PERFECT!", "good": "Good", "noball": "Overstepped!", "wide": "Lost it…"}[meter_result])
	var hb := _team_human(field_team(), bowler_name)
	if hb:
		_msg(hb.pid, {"type": "hint", "text": "Now a half swing! Angle it to swing, twist to spin"})


## Gyro from the bowler's phone: measures the half swing after the meter lock.
## Direction of the swing comes from the rotation axis in the room: a straight
## swing towards the TV turns about the left-right axis; an angled one is
## tilted. Wrist twist = rotation about the phone's own long axis.
func _on_gyro(_t: float, rx: float, ry: float, rz: float) -> void:
	if phase != Phase.RUNUP or not meter_locked or not _release.is_empty():
		return
	var m := _phone_motion()
	if m == null:
		return
	var w_dev := Vector3(rx, ry, rz)
	var mag := w_dev.length()
	var dt := 1.0 / 60.0
	if not _sw.get("started", false):
		if mag > 140.0:
			_sw = {"started": true, "t0": _lock_t, "peak": mag, "ang": 0.0, "w": 0.0, "twist": 0.0}
		else:
			return
	_sw.peak = maxf(_sw.peak, mag)
	var w := m.device_basis() * w_dev # into the room (East-North-Up)
	var y0 := m.facing_yaw()
	var fwd := Vector2(sin(y0), cos(y0))
	var right := Vector2(cos(y0), -sin(y0))
	var wh := Vector2(w.x, w.y)
	if wh.length() > 60.0:
		var ang := rad_to_deg(atan2(wh.dot(fwd), wh.dot(right)))
		if ang > 90.0:
			ang -= 180.0
		elif ang < -90.0:
			ang += 180.0
		_sw.ang += ang * mag
		_sw.w += mag
	_sw.twist += ry * dt
	if mag < _sw.peak * 0.4 and _lock_t - float(_sw.t0) > 0.12:
		_sw["ended"] = true


func _finish_swing(swing_deg: float, twist: float) -> void:
	var a := absf(meter)
	var effort := 1.0
	var err := 0.03
	match meter_result:
		"good":
			var f := (a - METER_PERFECT) / (METER_RED - METER_PERFECT)
			effort = 1.0 - f * 0.45
			err = 0.04 + f * 0.12
		"wide":
			effort = 0.45
			err = 0.1
		"noball":
			effort = 0.85
			err = 0.08
	var swing_amt := clampf(swing_deg / 25.0, -1.0, 1.0) if absf(swing_deg) > 5.0 else 0.0
	var twist_amt := clampf(twist / 45.0, -1.0, 1.0) if absf(twist) > 8.0 else 0.0
	_release = {"effort": effort, "swing": swing_amt, "twist": twist_amt, "err": err}
	_noball = meter_result == "noball"
	if meter_result == "wide":
		# sprays down the leg side or way outside off
		aim.x += (1.25 if randf() < 0.5 else -1.15) * _mirror()


func _dead_ball() -> void:
	hud.big_message("Dead ball", false)
	meter_locked = false
	_release = {}
	var bc := play.bowler.ch
	bc.global_position = Vector3(0.9, 0, CricketField.BOWL_Z - 11.0)
	_enter(Phase.AIM)


func _bowl() -> void:
	_released = true
	var effort: float = _release.get("effort", 0.7)
	var swing_amt: float = _release.get("swing", 0.0)
	var twist: float = _release.get("twist", 0.0)
	var rng: Array = SPEED_RANGE[kind]
	var kmh: float = lerpf(rng[0], rng[1], effort)
	var speed := kmh / 3.6
	# angled half swing -> swing in the air; wrist twist -> spin off the pitch
	var swing := 0.0
	if kind != Kind.SPIN:
		swing = swing_amt * (5.0 if kind == Kind.FAST else 4.0) * _mirror()
	var turn := twist * (0.075 if kind == Kind.SPIN else 0.025) * _mirror()
	var err := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(_release.get("err", 0.08))
	var target := Vector3(aim.x + err.x, 0, aim.y + err.y * 3.0)
	var from := play.bowler.ch.global_position + Vector3(-0.15, 2.15, 0.4)
	var v := CricketBall.solve_delivery(from, target, speed, swing)
	ball.release(from, v, swing, turn)
	_haptic_bowler("tick")
	_ball_kind = kind
	set_meta("kmh", kmh)
	var tag := ""
	if absf(swing) > 0.5:
		tag = "  · swing " + ("→" if swing > 0.0 else "←")
	if absf(turn) > 0.005:
		tag += "  · spin " + ("→" if turn > 0.0 else "←")
	hud.delivery_info("%s · %d km/h%s" % [KIND_NAMES[kind], roundi(kmh), tag])
	if _noball:
		hud.big_message("NO BALL", false)
	_enter(Phase.DELIVERY)
	if _is_cpu(bat_team):
		_cpu_plan_shot()


# --------------------------------------------------------------- batting

## Batting assists: footwork across the crease and up/down to the ball.
func _assist(delta: float) -> void:
	var a: float = get_meta("assist", 0.55)
	var hz := rig.stance_hands().z
	var pts := ball.predict(1.2, 0.01)
	for q in pts:
		if q.z >= hz:
			var want_x := rig.reach_x + (q.x - rig.stance_hands().x) * a
			rig.reach_x = move_toward(rig.reach_x, clampf(want_x, -0.6, 0.6), 2.2 * delta)
			rig.lift = move_toward(rig.lift, BatterRig.lift_for_ball(q.y), 2.5 * delta)
			break


func _on_bat_contact(_p: Vector3, quality: float, edge: bool) -> void:
	if phase != Phase.DELIVERY:
		return
	_hit = true
	_haptic_batter("double" if edge else ("strong" if quality > 0.8 else "hit"))
	if edge:
		hud.flash("Edge!")
	elif quality > 0.8:
		hud.flash("Middled!")
	await get_tree().create_timer(0.12).timeout
	_start_play(true)


func _cpu_plan_shot() -> void:
	# decide what the CPU batter does with this ball
	var pts := ball.predict(1.5, 0.005)
	var hz := rig.stance_hands().z
	var arrive := Vector3.ZERO
	var t_arr := 0.0
	for i in pts.size():
		if pts[i].z >= hz:
			arrive = pts[i]
			t_arr = i * 0.005
			break
	var skill: float = [0.55, 0.7, 0.85][difficulty]
	var good_ball := absf(arrive.x - 0.12 * _mirror()) < 0.25 and aim.y < -4.0 and aim.y > -7.5
	var r := randf()
	var shot := "drive"
	if r > skill + (0.0 if not good_ball else -0.12):
		shot = "miss" if randf() < 0.55 else "edge"
	elif randf() < 0.28:
		shot = "defend"
	elif randf() < 0.18 + 0.1 * difficulty:
		shot = "loft"
	_cpu_shot = {"shot": shot, "t": t_arr, "at": arrive, "done": false, "elapsed": 0.0}


func _cpu_bat(delta: float) -> void:
	if _cpu_shot.is_empty():
		return
	_cpu_shot.elapsed += delta
	var t_to := float(_cpu_shot.t) - float(_cpu_shot.elapsed)
	var shot: String = _cpu_shot.shot
	# animate the swing so the bat comes through as the ball arrives
	var phi := clampf(0.1 - t_to * 9.0, -1.9, 1.2) if shot != "defend" else clampf(0.05 - t_to * 4.0, -0.6, 0.2)
	var psi: float = get_meta("cpu_psi", 0.0)
	rig.apply_rotation(BatterRig.swing_rotation(phi, psi))
	if _cpu_shot.done or t_to > 0.0:
		return
	_cpu_shot.done = true
	if shot == "miss":
		return
	var dir_angle := _find_gap(shot)
	set_meta("cpu_psi", dir_angle * 0.4)
	var spd := 0.0
	var elev := 0.0
	match shot:
		"defend":
			spd = randf_range(4.0, 8.0)
			elev = -2.0
		"drive":
			spd = randf_range(22.0, 34.0)
			elev = randf_range(-3.0, 6.0)
		"loft":
			spd = randf_range(30.0, 40.0)
			elev = randf_range(22.0, 38.0)
		"edge":
			spd = randf_range(12.0, 22.0)
			elev = randf_range(-2.0, 14.0)
			dir_angle = (randf_range(150.0, 175.0)) * -_mirror()
	var a := deg_to_rad(dir_angle)
	var dir := Vector3(-sin(a), 0, -cos(a))
	var v := (dir * cos(deg_to_rad(elev)) + Vector3.UP * sin(deg_to_rad(elev))) * spd
	ball.set_velocity(v, true)
	_hit = true
	Sfx.pin_hit(0.8)
	_start_play(true)


## Direction (deg, 0 = straight back past the bowler, + = leg side) with the
## most room between fielders.
func _find_gap(shot: String) -> float:
	var best := 0.0
	var best_s := -1e9
	var lim := 75.0 if shot != "loft" else 60.0
	var a := -lim
	while a <= lim:
		var dir := Vector2(-sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
		var s := 0.0
		var nearest := 1e9
		for f in play.fielders:
			var fp := Vector2(f.home.x, f.home.z + 0.85)
			var along := fp.dot(dir)
			if along <= 0.0:
				continue
			var side := absf(fp.cross(dir))
			nearest = minf(nearest, side / maxf(along, 1.0) * 30.0 + (along if shot == "loft" else 0.0) * 0.2)
		s = nearest + randf_range(0.0, 3.0)
		if s > best_s:
			best_s = s
			best = a
		a += 5.0
	return best


func _update_delivery(_delta: float) -> void:
	var bp := ball.global_position
	# wide: past the batter, not hit, well wide of the stumps
	if not _hit and not _wide_checked and bp.z > -CricketField.CREASE + 0.2:
		_wide_checked = true
		if absf(bp.x) > 0.95 and not field.striker_stumps.broken:
			set_meta("wide", true)
	if not _hit and not _passed and bp.z > 0.6:
		_passed = true
		_start_play(false)
	if _t > 4.0 and not _hit and not _passed:
		_passed = true
		_start_play(false)


func _start_play(hit: bool) -> void:
	if phase != Phase.DELIVERY:
		return
	_enter(Phase.PLAY)
	play.start(hit, rig)
	if not hit:
		play.keeper_takes()


func _on_ball_hit_stumps(st: Stumps, _p: Vector3, _v: Vector3) -> void:
	if st == field.striker_stumps and phase == Phase.DELIVERY:
		# bowled (also "played on" after an inside edge)
		set_meta("bowled", true)
		hud.big_message("BOWLED!", true)
		_enter(Phase.PLAY)
		play.active = true
		play._finish_after("bowled", 0, "", 1.8)


# ---------------------------------------------------------------- result

func _on_play_finished(kind_s: String, runs: int, detail: String) -> void:
	var striker: String = batter_names[0]
	var out := false
	var how := ""
	var is_wide: bool = get_meta("wide", false)
	remove_meta("wide")
	var was_noball := _noball
	var was_free_hit := free_hit
	_noball = false
	if has_meta("bowled"):
		remove_meta("bowled")
		kind_s = "bowled"
	match kind_s:
		"caught", "bowled":
			out = not (was_noball or was_free_hit) # can't be bowled / caught off a no-ball or free hit
			how = kind_s
			is_wide = false
		"runout":
			out = true
			how = "run out"
	var over_done := false
	var text := ""
	if was_noball and not out:
		score.record("noball", runs, striker, bowler_name)
		text = "NO BALL" + ("  +%d" % runs if runs > 0 else "") + " · FREE HIT next"
		free_hit = true
	elif is_wide and not out:
		score.record("wide", runs, striker, bowler_name)
		text = "WIDE" + ("  +%d" % runs if runs > 0 else "")
	elif out:
		var dismissed: String = striker if how != "run out" else detail
		over_done = score.record("out", runs, striker, bowler_name, how)
		free_hit = false
		text = "%s OUT – %s" % [dismissed, how.to_upper()]
		_new_batter(dismissed)
	else:
		over_done = score.record("runs", runs, striker, bowler_name)
		free_hit = false
		match kind_s:
			"four":
				text = "FOUR!"
			"six":
				text = "SIX!"
			_:
				text = "%d run%s" % [runs, "" if runs == 1 else "s"] if runs > 0 else "Dot ball"
	print("[cricket] %s %s  ->  %s  (%d/%d, %s ov)" % [teams[bat_team].name, striker, text, score.cur().runs, score.cur().wickets, score.over_text()])
	hud.big_message(text, kind_s in ["four", "six", "caught", "bowled", "runout"])
	if out:
		_haptic_batter("out")
		_haptic_bowler("strong")
	elif kind_s == "six":
		_haptic_batter("long")
	elif kind_s == "four":
		_haptic_batter("strong")
	# strike rotation: odd runs swap ends; end of over swaps again
	if (kind_s in ["caught", "bowled"]) and not out:
		text = "Not out – " + ("free hit" if was_free_hit else "no ball") + ("" if runs == 0 else "  +%d" % runs)
	if not out and runs % 2 == 1:
		batter_names = [batter_names[1], batter_names[0]]
	if over_done:
		batter_names = [batter_names[1], batter_names[0]]
		_bowler_idx += 1
		score.start_over()
		field_pos = _preset(score.max_outside_circle())
	set_meta("over_done", over_done)
	_enter(Phase.RESULT)


func _new_batter(out_name: String) -> void:
	var idx := batter_names.find(out_name)
	if idx < 0:
		idx = 0
	var names: Array = teams[bat_team].names
	batter_names[idx] = names[_next_batter % names.size()]
	_next_batter += 1


func _next() -> void:
	if score.match_over():
		_finish_match()
		return
	if score.innings_over():
		phase = Phase.BREAK
		_t = 0.0
		hud.big_message("Innings break – target %d" % (score.cur().runs + 1), false)
		hud.set_phase(self)
		return
	_begin_ball()


func _start_second_innings() -> void:
	score.start_second_innings()
	bat_team = 1 - bat_team
	_build_sides()
	_begin_ball()


func _finish_match() -> void:
	phase = Phase.OVER
	roster.lock_to("")
	Pad.pointer_visible = true
	hud.show_results(self)
	phone_message.emit({"to": "*", "type": "turn", "mine": true, "text": ""})
	phone_message.emit({"to": "*", "type": "layout", "dpad": false})
	phone_message.emit({"to": "*", "type": "hint", "text": "Point and press A"})
	print("[cricket] RESULT: %s" % score.result_text())


# ---------------------------------------------------------------- camera

func _update_camera(delta: float) -> void:
	var tp: Vector3
	var tl: Vector3
	var k := 4.0
	var fov := 50.0
	var human_bats := not _is_cpu(bat_team)
	match phase:
		Phase.FIELD_SET:
			tp = CricketField.CENTER + Vector3(0, 115, 1)
			tl = CricketField.CENTER
			fov = 58.0
			k = 3.0
		Phase.AIM:
			tp = Vector3(0.6, 2.8, CricketField.BOWL_Z - 6.5)
			tl = Vector3(aim.x, 0.2, aim.y)
			k = 5.0
		Phase.RUNUP, Phase.DELIVERY, Phase.BAT_SETUP:
			if human_bats or phase == Phase.BAT_SETUP:
				# over the batter's shoulder, down the pitch (in front of the keeper)
				tp = _bat_cam_pos()
				tl = _bat_cam_look()
				fov = 40.0
			else:
				var bz := play.bowler.ch.global_position.z
				tp = Vector3(0.7, 2.5, minf(bz, CricketField.BOWL_Z + 0.5) - 5.0)
				tl = Vector3(0, 0.6, 0)
				fov = 45.0
			k = 7.0
		Phase.PLAY, Phase.RESULT:
			var b := ball.global_position
			# broadcast view from high behind the bowler's end, following the ball
			tp = Vector3(b.x * 0.35, 18.0 + absf(b.x) * 0.15, CricketField.BOWL_Z - 34.0 + clampf(b.z, -20.0, 40.0) * 0.3)
			tl = b + Vector3(0, 0.5, 0)
			fov = 38.0
			k = 3.5
		_:
			tp = CricketField.CENTER + Vector3(30, 22, 40)
			tl = CricketField.CENTER
			k = 1.5
	var f := 1.0 - exp(-delta * k)
	_cam_pos = _cam_pos.lerp(tp, f)
	_cam_look = _cam_look.lerp(tl, f)
	camera.fov = lerpf(camera.fov, fov, f)
	camera.look_at_from_position(_cam_pos, _cam_look)



func _setup_split() -> void:
	_split_layer = CanvasLayer.new()
	_split_layer.layer = 0
	_split_layer.visible = false
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
		cam.near = 0.05
		cam.far = 600.0
		vp.add_child(cam)
		cam.current = true
		_split_cams.append(cam)
		var tag := UI.label("", 26, UI.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
		tag.add_theme_color_override("font_outline_color", UI.BLUE_DARK if i == 1 else Color("d9822b"))
		tag.add_theme_constant_override("outline_size", 10)
		tag.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		tag.position.y = -150
		tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
		c.add_child(tag)
		_split_labels.append(tag)


## Both sides human: show the bowler and the batter their own views.
func _update_split(delta: float) -> void:
	if _split_layer == null:
		return
	var want := not _is_cpu(bat_team) and not _is_cpu(field_team()) \
		and phase in [Phase.BAT_SETUP, Phase.AIM, Phase.RUNUP, Phase.DELIVERY]
	if want != _split_on:
		_split_on = want
		_split_layer.visible = want
		get_viewport().disable_3d = want
	if not want:
		return
	_split_labels[0].text = "BOWLING · " + bowler_name
	_split_labels[1].text = "BATTING · " + str(batter_names[0])
	var targets := [
		[Vector3(0.6, 2.8, CricketField.BOWL_Z - 6.5), Vector3(aim.x, 0.2, aim.y)] if phase == Phase.AIM else [_bowl_cam_pos(), Vector3(0, 0.6, 0)],
		[_bat_cam_pos(), _bat_cam_look()],
	]
	var f := 1.0 - exp(-delta * 7.0)
	for i in 2:
		var st: Array = _split_cam_state[i]
		st[0] = (st[0] as Vector3).lerp(targets[i][0], f)
		st[1] = (st[1] as Vector3).lerp(targets[i][1], f)
		_split_cams[i].look_at_from_position(st[0], st[1])


func _exit_tree() -> void:
	get_viewport().disable_3d = false


## Behind the keeper, high enough to see over him: batter, bat and bowler in view.
func _bat_cam_pos() -> Vector3:
	return Vector3(0.3 * _mirror(), 3.3, 5.5)


func _bat_cam_look() -> Vector3:
	return Vector3(-0.15 * _mirror(), 0.45, CricketField.BOWL_Z)


func _bowl_cam_pos() -> Vector3:
	var bz := play.bowler.ch.global_position.z
	return Vector3(0.7, 2.5, minf(bz, CricketField.BOWL_Z + 0.5) - 5.0)
