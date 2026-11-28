extends SceneTree
# CPU vs CPU doubles match; prints every point.
func _init():
	var pad := Pad.new(); root.add_child(pad)
	root.add_child(Sfx.new())
	var roster := Players.new()
	var game := TennisGame.new()
	game.roster = roster
	game.total_games = int(OS.get_environment("VS_GAMES")) if OS.get_environment("VS_GAMES") != "" else 3
	game.difficulty = 1
	root.add_child(game)
	var elapsed := 0.0
	var hits := 0
	while elapsed < 900.0 and game.phase != TennisGame.Phase.OVER:
		await process_frame
		elapsed += root.get_process_delta_time()
	print("[test] done after %.0fs  games %d-%d  phase %d" % [elapsed, game.score.games[0], game.score.games[1], game.phase])
	quit()
