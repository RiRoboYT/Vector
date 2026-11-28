class_name TennisOptions
extends Screen
## Match options: 1 / 3 / 5 games and computer difficulty, with the teams shown.

var roster: Players
var games := 1
var difficulty := 1

var _game_btns: Array[PillButton] = []
var _diff_btns: Array[PillButton] = []
var _start: PillButton
var _back: PillButton
const GAMES := [["1 Game", 1], ["3 Games", 3], ["5 Games", 5]]
const LEVELS := ["Easy", "Medium", "Hard"]


func _init() -> void:
	super()
	phone_hint = "Point and press A"
	for i in GAMES.size():
		var b := PillButton.new(GAMES[i][0], Vector2(210, 74))
		b.font_size = 28
		b.pressed.connect(func(): games = GAMES[i][1])
		add_child(b)
		_game_btns.append(b)
	for i in LEVELS.size():
		var b := PillButton.new(LEVELS[i], Vector2(200, 70))
		b.font_size = 26
		b.pressed.connect(func(): difficulty = i)
		add_child(b)
		_diff_btns.append(b)
	_start = PillButton.new("Start", Vector2(260, 84))
	_start.font_size = 36
	_start.pressed.connect(func(): done.emit("start"))
	add_child(_start)
	_back = PillButton.new("Back", Vector2(170, 66))
	_back.font_size = 26
	_back.pressed.connect(func(): done.emit("back"))
	add_child(_back)


func humans() -> Array[String]:
	var out: Array[String] = []
	for p in roster.players:
		out.append(p.name)
	if out.is_empty():
		out.append("Keyboard")
	return out.slice(0, 4)


func vs_cpu() -> bool:
	return humans().size() < 2


func _process(delta: float) -> void:
	super(delta)
	for i in _game_btns.size():
		_game_btns[i].position = Vector2(60 + i * 230, 200)
	for i in _diff_btns.size():
		_diff_btns[i].position = Vector2(60 + i * 230, 370)
		_diff_btns[i].visible = vs_cpu()
	_start.position = Vector2(size.x - 310, size.y - 104)
	_back.position = Vector2(50, size.y - 96)


func _draw() -> void:
	draw_stripes()
	var f := UI.bold()
	var reg := UI.regular()
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 100)), UI.WHITE)
	draw_rect(Rect2(Vector2(0, 100), Vector2(size.x, 5)), UI.BLUE)
	draw_string(f, Vector2(50, 66), "Tennis · Doubles", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK)
	UI.draw_logo(self, Vector2(size.x - 200, 62), 0.4)
	draw_string(f, Vector2(62, 180), "Match length", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK)
	for i in _game_btns.size():
		if GAMES[i][1] == games:
			_tick(_game_btns[i])
	var note := "Win the game to win the match" if games == 1 else "First to %d games wins" % (games / 2 + 1)
	draw_string(reg, Vector2(62, 312), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.INK)
	if vs_cpu():
		draw_string(f, Vector2(62, 350), "Computer", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK)
		_tick(_diff_btns[difficulty])
	# teams (same mapping as TennisGame)
	var h := humans()
	var a: Array = []
	var b: Array = []
	match h.size():
		1:
			a = [h[0] + " (both players)"]
			b = ["Computer"]
		2:
			a = [h[0] + " (both players)"]
			b = [h[1] + " (both players)"]
		3:
			a = [h[0], h[1]]
			b = [h[2] + " (both players)"]
		_:
			a = [h[0], h[1]]
			b = [h[2], h[3]]
	var tr := Rect2(Vector2(size.x - 490, 150), Vector2(440, 300))
	draw_style_box(UI.panel_style(UI.WHITE, UI.BLUE, 26, 3), tr)
	draw_string(f, tr.position + Vector2(24, 44), "Teams", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.INK_DARK)
	var lines := [["Blue", TennisGame.TEAM_COLORS[0], a], ["Orange", TennisGame.TEAM_COLORS[1], b]]
	for k in 2:
		var y := tr.position.y + 90 + k * 100
		draw_circle(Vector2(tr.position.x + 40, y), 14, lines[k][1])
		draw_string(f, Vector2(tr.position.x + 64, y + 9), lines[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.INK_DARK)
		draw_string(reg, Vector2(tr.position.x + 64, y + 40), " & ".join(lines[k][2]), HORIZONTAL_ALIGNMENT_LEFT, 350, 19, UI.INK)
	if roster.players.size() > 4:
		draw_string(reg, Vector2(tr.position.x, tr.end.y + 34), "Tennis is played by up to 4 players.", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.WHITE)


func _tick(b: PillButton) -> void:
	var r := Rect2(b.position, b.size).grow(7)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color("ffb020")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(sb, r)
