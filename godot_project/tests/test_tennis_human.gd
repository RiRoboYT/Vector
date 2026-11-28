extends SceneTree
# One human (simulated phone) + partner vs two CPUs. The phone serves with
# B + a swing at the top of the toss, and swings at incoming balls with a
# random timing error. VS_PVP=1: two humans (split screen).
var game: TennisGame
var ph: Players.Phone
var ph2: Players.Phone
var swings := 0
var err_sd := 0.08

func _init():
	root.add_child(Pad.new())
	root.add_child(Sfx.new())
	var roster := Players.new()
	ph = _phone(roster, "sim", "Tester")
	if OS.get_environment("VS_PVP") != "":
		ph2 = _phone(roster, "sim2", "Leo")
	game = TennisGame.new()
	game.roster = roster
	game.total_games = 1
	game.difficulty = 1
	root.add_child(game)
	await process_frame
	var elapsed := 0.0
	var pending := {} # pid -> due time
	var last_phase := -1
	while elapsed < 400.0 and game.phase != TennisGame.Phase.OVER:
		await process_frame
		elapsed += root.get_process_delta_time()
		var now := game._now_ms()
		# serve
		if game.phase == TennisGame.Phase.SERVE and game.is_human(game.server) and game._t > 0.6:
			roster.phone_button.emit(game.server.pid, Pad.B, true)
		if game.phase == TennisGame.Phase.TOSS and game.is_human(game.server) and game._toss_t > 0.5 + randf_range(-0.05, 0.05) and not pending.has("serve"):
			pending["serve"] = true
			_swing(game.server.pid, 900.0)
		if game.phase != TennisGame.Phase.TOSS:
			pending.erase("serve")
		# rally
		var r := game.receiver_player
		if game.phase == TennisGame.Phase.RALLY and r != null and game.is_human(r):
			var key := "%s@%d" % [r.pid, game._hit_due_ms]
			if not pending.has(key):
				pending[key] = game._hit_due_ms + int(randfn(0.0, err_sd) * 1000.0)
			elif int(pending[key]) > 0 and now >= int(pending[key]) - 40:
				pending[key] = 0
				_swing(r.pid, randf_range(500.0, 1100.0))
	print("[test] human swings %d, games %d-%d, phase %d after %.0fs" % [swings, game.score.games[0], game.score.games[1], game.phase, elapsed])
	quit()

func _phone(roster: Players, pid: String, nm: String) -> Players.Phone:
	var p := Players.Player.new(); p.pid = pid; p.name = nm
	roster.players.append(p)
	var f := Players.Phone.new(); f.pid = pid; f.cid = 1
	f.motion = MotionInput.new(); root.add_child(f.motion)
	roster.phones[pid] = f
	return f

## Feed a swing: gyro rate ramps up to `peak` over 40 ms then drops.
func _swing(pid: String, peak: float) -> void:
	swings += 1
	var f: Players.Phone = game.roster.phones[pid]
	for k in 6:
		var m: float = peak * [0.4, 0.8, 1.0, 0.7, 0.3, 0.1][k]
		f.motion.gyro_sample.emit(0.0, m, 0.0, 0.0)
		await process_frame
