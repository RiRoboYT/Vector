class_name CricketOptions
extends Screen
## Match options: format and computer difficulty, with the two teams shown.

var roster: Players
var overs := 1
var super_over := true
var difficulty := 1

var _format_btns: Array[PillButton] = []
var _diff_btns: Array[PillButton] = []
var _start: PillButton
var _back: PillButton
const FORMATS := [["Super Over", 1, true], ["2 Overs", 2, false], ["5 Overs", 5, false]]
const LEVELS := ["Easy", "Medium", "Hard"]


func _init() -> void:
	super()
	phone_hint = "Point and press A"
	for i in FORMATS.size():
		var b := PillButton.new(FORMATS[i][0], Vector2(220, 74))
		b.font_size = 28
		b.pressed.connect(func():
			overs = FORMATS[i][1]
			super_over = FORMATS[i][2])
		add_child(b)
		_format_btns.append(b)
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


func vs_cpu() -> bool:
	return roster.players.size() < 2


func _process(delta: float) -> void:
	super(delta)
	for i in _format_btns.size():
		_format_btns[i].position = Vector2(60 + i * 240, 200)
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
	draw_string(f, Vector2(50, 66), "Cricket · Match", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK)
	UI.draw_logo(self, Vector2(size.x - 200, 62), 0.4)
	draw_string(f, Vector2(62, 180), "Format", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK)
	for i in _format_btns.size():
		if FORMATS[i][1] == overs and FORMATS[i][2] == super_over:
			_tick(_format_btns[i])
	var fmt_note := "6 balls each, 2 wickets" if super_over else "%d overs a side, %d wickets · powerplay first %d over%s" % [overs, 3 if overs <= 2 else 5, maxi(1, int(ceil(overs * 0.3))), "" if maxi(1, int(ceil(overs * 0.3))) == 1 else "s"]
	draw_string(reg, Vector2(62, 312), fmt_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.INK)
	if vs_cpu():
		draw_string(f, Vector2(62, 350), "Computer", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK)
		_tick(_diff_btns[difficulty])
	# teams
	var tr := Rect2(Vector2(size.x - 470, 150), Vector2(420, 300))
	draw_style_box(UI.panel_style(UI.WHITE, UI.BLUE, 26, 3), tr)
	draw_string(f, tr.position + Vector2(24, 44), "Teams", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.INK_DARK)
	var a: Array[String] = []
	var b: Array[String] = []
	for i in roster.players.size():
		(a if i % 2 == 0 else b).append(roster.players[i].name)
	if a.is_empty():
		a.append("Keyboard")
	var lines := [["Blue", CricketGame.TEAM_COLORS[0], a], ["Orange", CricketGame.TEAM_COLORS[1], b if not b.is_empty() else ["Computer"]]]
	for k in 2:
		var y := tr.position.y + 90 + k * 100
		draw_circle(Vector2(tr.position.x + 40, y), 14, lines[k][1])
		draw_string(f, Vector2(tr.position.x + 64, y + 9), lines[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.INK_DARK)
		draw_string(reg, Vector2(tr.position.x + 64, y + 40), ", ".join(lines[k][2]), HORIZONTAL_ALIGNMENT_LEFT, 330, 19, UI.INK)


func _tick(b: PillButton) -> void:
	var r := Rect2(b.position, b.size).grow(7)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color("ffb020")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(sb, r)
