class_name CricketScore
extends RefCounted
## Match state and rules for limited-overs cricket.
##   - 6 legal balls an over; a wide is +1 run and is bowled again
##   - innings ends on overs used up, all wickets lost, or target passed
##   - powerplay: first 30% of the overs (not in a Super Over):
##     max 2 fielders outside the 30-yard circle; otherwise max 5

class Innings:
	var team := 0 # index of the batting team
	var runs := 0
	var wickets := 0
	var balls := 0 # legal balls
	var extras := 0
	var this_over: Array[String] = [] # "0", "1", "4", "6", "W", "Wd"
	var batter_runs := {} # name -> runs
	var batter_balls := {} # name -> balls
	var bowler_runs := {} # name -> runs conceded
	var bowler_wkts := {} # name -> wickets
	var bowler_balls := {} # name -> legal balls

var overs := 1
var max_wickets := 2
var super_over := true
var innings: Array[Innings] = []
var team_names := ["Team A", "Team B"]


func setup(p_overs: int, p_super: bool, first_batting: int) -> void:
	overs = p_overs
	super_over = p_super
	max_wickets = 2 if p_super else (3 if p_overs <= 2 else 5)
	innings.clear()
	var a := Innings.new()
	a.team = first_batting
	innings.append(a)


func cur() -> Innings:
	return innings[innings.size() - 1]


func is_second_innings() -> bool:
	return innings.size() == 2


func target() -> int:
	return innings[0].runs + 1 if is_second_innings() else -1


func powerplay_overs() -> int:
	return 0 if super_over else maxi(1, int(ceil(overs * 0.3)))


func in_powerplay() -> bool:
	return cur().balls / 6 < powerplay_overs()


## Real fielding restriction for the current over.
func max_outside_circle() -> int:
	return 2 if in_powerplay() else 5


func over_text(inn: Innings = null) -> String:
	if inn == null:
		inn = cur()
	return "%d.%d" % [inn.balls / 6, inn.balls % 6]


## Record one delivery. kind: "runs", "wide", "out". Returns true if the over ended.
func record(kind: String, runs: int, batter: String, bowler: String, how := "") -> bool:
	var inn := cur()
	if kind == "noball":
		inn.runs += 1 + runs
		inn.extras += 1
		inn.batter_runs[batter] = inn.batter_runs.get(batter, 0) + runs
		inn.this_over.append("Nb")
		inn.bowler_runs[bowler] = inn.bowler_runs.get(bowler, 0) + 1 + runs
		return false
	if kind == "wide":
		inn.runs += 1 + runs
		inn.extras += 1 + runs
		inn.this_over.append("Wd")
		inn.bowler_runs[bowler] = inn.bowler_runs.get(bowler, 0) + 1 + runs
		return false
	inn.balls += 1
	inn.batter_balls[batter] = inn.batter_balls.get(batter, 0) + 1
	inn.bowler_balls[bowler] = inn.bowler_balls.get(bowler, 0) + 1
	inn.runs += runs
	inn.batter_runs[batter] = inn.batter_runs.get(batter, 0) + runs
	inn.bowler_runs[bowler] = inn.bowler_runs.get(bowler, 0) + runs
	if kind == "out":
		inn.wickets += 1
		if how != "run out":
			inn.bowler_wkts[bowler] = inn.bowler_wkts.get(bowler, 0) + 1
		inn.this_over.append("W")
	else:
		inn.this_over.append(str(runs))
	if inn.balls % 6 == 0:
		return true
	return false


func start_over() -> void:
	cur().this_over.clear()


func innings_over() -> bool:
	var inn := cur()
	if inn.wickets >= max_wickets or inn.balls >= overs * 6:
		return true
	return is_second_innings() and inn.runs >= target()


func start_second_innings() -> void:
	var b := Innings.new()
	b.team = 1 - innings[0].team
	innings.append(b)


func match_over() -> bool:
	return is_second_innings() and innings_over()


## -1 = tie, otherwise winning team index
func winner() -> int:
	var a := innings[0]
	var b := innings[1]
	if b.runs > a.runs:
		return b.team
	if b.runs < a.runs:
		return a.team
	return -1


func result_text() -> String:
	var w := winner()
	if w == -1:
		return "It's a tie!"
	var b := innings[1]
	if w == b.team:
		var left := max_wickets - b.wickets
		return "%s win by %d wicket%s" % [team_names[w], left, "" if left == 1 else "s"]
	var margin := innings[0].runs - b.runs
	return "%s win by %d run%s" % [team_names[w], margin, "" if margin == 1 else "s"]


## "Need 8 from 9 balls"
func chase_text() -> String:
	if not is_second_innings():
		return ""
	var need := target() - cur().runs
	var left := overs * 6 - cur().balls
	return "Need %d from %d ball%s" % [maxi(need, 0), left, "" if left == 1 else "s"]
