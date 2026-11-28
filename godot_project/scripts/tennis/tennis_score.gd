class_name TennisScore
extends RefCounted
## Real tennis scoring: 0/15/30/40, deuce, advantage, games.
## Match: first to win the majority of `games` (1, 3 or 5) games.

var games_to_win := 1
var points := [0, 0] # raw points this game, team 0 = near side, team 1 = far side
var games := [0, 0]
var server_team := 0
var game_count := 0 # games played (decides who serves)


func setup(total_games: int, first_server: int) -> void:
	games_to_win = total_games / 2 + 1
	points = [0, 0]
	games = [0, 0]
	server_team = first_server
	game_count = 0


## Returns "point", "game" or "match".
func point_to(team: int) -> String:
	points[team] += 1
	var a: int = points[team]
	var b: int = points[1 - team]
	if a >= 4 and a - b >= 2:
		games[team] += 1
		points = [0, 0]
		game_count += 1
		server_team = 1 - server_team
		if games[team] >= games_to_win:
			return "match"
		return "game"
	return "point"


func is_deuce_court() -> bool:
	# serve from the right (deuce) court when an even number of points played
	return (points[0] + points[1]) % 2 == 0


## Call text from the server's point of view, e.g. "30–15", "Deuce", "Advantage Blue".
func call_text(names: Array) -> String:
	var a: int = points[server_team]
	var b: int = points[1 - server_team]
	if a >= 3 and b >= 3:
		if a == b:
			return "Deuce"
		var lead := server_team if a > b else 1 - server_team
		return "Advantage " + str(names[lead])
	var words := ["Love", "15", "30", "40"]
	if a == b:
		return words[a] + "–All" if a < 3 else "Deuce"
	return "%s–%s" % [words[mini(a, 3)], words[mini(b, 3)]]


func point_label(team: int) -> String:
	var a: int = points[team]
	var b: int = points[1 - team]
	if a >= 3 and b >= 3:
		return "AD" if a > b else "40"
	return ["0", "15", "30", "40"][mini(a, 3)]


func winner() -> int:
	return 0 if games[0] > games[1] else 1
