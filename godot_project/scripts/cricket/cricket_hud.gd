class_name CricketHud
extends CanvasLayer
## Scoreboard, prompts, field-setting minimap, delivery chips, big messages
## and the result screen.

signal play_again
signal to_menu

var _view: HudView
var _msg: Label
var _msg_t := 0.0
var _flash: Label
var _flash_t := 0.0
var _info: Label
var _info_t := 0.0
var _final: Control
var _again: PillButton
var _menu: PillButton


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_view = HudView.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_view)

	_msg = UI.label("", 84, UI.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_msg.add_theme_color_override("font_outline_color", UI.BLUE_DARK)
	_msg.add_theme_constant_override("outline_size", 20)
	_msg.set_anchors_preset(Control.PRESET_CENTER)
	_msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_msg.grow_vertical = Control.GROW_DIRECTION_BOTH
	_msg.modulate.a = 0.0
	root.add_child(_msg)
	_flash = UI.label("", 34, UI.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_flash.add_theme_color_override("font_outline_color", Color("e0533d"))
	_flash.add_theme_constant_override("outline_size", 12)
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.position.y = 150
	_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_flash)
	_info = UI.label("", 30, UI.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_info.add_theme_color_override("font_outline_color", UI.INK_DARK)
	_info.add_theme_constant_override("outline_size", 10)
	_info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info.position = Vector2(-420, 30)
	_info.custom_minimum_size = Vector2(390, 40)
	root.add_child(_info)

	_final = Control.new()
	_final.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final.visible = false
	root.add_child(_final)
	_again = PillButton.new("Play Again", Vector2(240, 78))
	_again.pressed.connect(func(): play_again.emit())
	_final.add_child(_again)
	_menu = PillButton.new("Menu", Vector2(240, 78))
	_menu.pressed.connect(func(): to_menu.emit())
	_final.add_child(_menu)


func set_state(g: CricketGame) -> void:
	_view.g = g


func set_phase(g: CricketGame) -> void:
	_view.g = g


func big_message(t: String, celebrate: bool) -> void:
	_msg.text = t
	_msg_t = 1.8
	_msg.add_theme_color_override("font_outline_color", UI.BLUE_DARK if celebrate else Color("7a8696"))


func flash(t: String) -> void:
	_flash.text = t
	_flash_t = 1.8


func delivery_info(t: String) -> void:
	_info.text = t
	_info_t = 3.0


func show_results(g: CricketGame) -> void:
	_view.results = true
	_final.visible = true


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t / 0.3, 0.0, 1.0)
		var pop := clampf((1.8 - _msg_t) / 0.18, 0.0, 1.0)
		_msg.pivot_offset = _msg.size * 0.5
		_msg.scale = Vector2.ONE * lerpf(1.4, 1.0, ease(pop, 0.4))
	else:
		_msg.modulate.a = 0.0
	_flash_t -= delta
	_flash.modulate.a = clampf(_flash_t / 0.3, 0.0, 1.0)
	_info_t -= delta
	_info.modulate.a = clampf(_info_t / 0.5, 0.0, 1.0)
	if _final.visible:
		var vs := _final.size
		_again.position = Vector2(vs.x * 0.5 - 260, vs.y * 0.5 + 120)
		_menu.position = Vector2(vs.x * 0.5 + 20, vs.y * 0.5 + 120)
	_view.queue_redraw()


class HudView:
	extends Control
	var g: CricketGame
	var results := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if g == null or g.score.innings.is_empty():
			return
		if results:
			_draw_results()
			return
		_draw_scoreboard()
		_draw_prompt()
		if g.phase == CricketGame.Phase.FIELD_SET:
			_draw_minimap()
		if g.phase == CricketGame.Phase.AIM:
			_draw_aim()

	func _panel(r: Rect2, border := UI.BORDER, alpha := 0.93) -> void:
		draw_style_box(UI.panel_style(Color(1, 1, 1, alpha), border, 18, 2), r)

	func _draw_scoreboard() -> void:
		var s := g.score
		var inn := s.cur()
		var f := UI.bold()
		var reg := UI.regular()
		var r := Rect2(Vector2(26, 22), Vector2(430, 170))
		_panel(r)
		var team: Dictionary = g.teams[inn.team]
		var band := StyleBoxFlat.new()
		band.bg_color = team.color
		band.corner_radius_top_left = 18
		band.corner_radius_top_right = 18
		draw_style_box(band, Rect2(r.position, Vector2(r.size.x, 52)))
		draw_string(f, r.position + Vector2(18, 37), str(team.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 200, 24, UI.WHITE)
		var sc := "%d/%d" % [inn.runs, inn.wickets]
		draw_string(f, r.position + Vector2(r.size.x - 20 - f.get_string_size(sc, 0, -1, 36).x, 40), sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, UI.WHITE)
		var ov := "Overs %s / %d" % [s.over_text(), s.overs]
		draw_string(reg, r.position + Vector2(18, 80), ov, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.INK)
		if s.in_powerplay():
			var pp := Rect2(r.position + Vector2(200, 62), Vector2(52, 24))
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color("ffb020")
			ps.set_corner_radius_all(12)
			draw_style_box(ps, pp)
			draw_string(f, pp.position + Vector2(12, 18), "PP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.WHITE)
		# batters
		for k in 2:
			var nm: String = g.batter_names[k]
			var line := "%s%s  %d (%d)" % [nm, "*" if k == 0 else "", inn.batter_runs.get(nm, 0), inn.batter_balls.get(nm, 0)]
			draw_string(f if k == 0 else reg, r.position + Vector2(18, 108 + k * 24), line, HORIZONTAL_ALIGNMENT_LEFT, 250, 18, UI.INK_DARK)
		var bl := "%s  %d-%d" % [g.bowler_name, inn.bowler_wkts.get(g.bowler_name, 0), inn.bowler_runs.get(g.bowler_name, 0)]
		draw_string(reg, r.position + Vector2(260, 108), "Bowling", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.INK_SOFT)
		draw_string(f, r.position + Vector2(260, 130), bl, HORIZONTAL_ALIGNMENT_LEFT, 160, 18, UI.INK_DARK)
		# this over
		var cx := r.position.x + 18
		var cy := r.end.y + 26
		for i in 6:
			var t := inn.this_over[i] if i < inn.this_over.size() else ""
			var col := UI.WHITE
			match t:
				"4", "6":
					col = UI.BLUE
				"W":
					col = Color("e0533d")
				"Wd":
					col = Color("ffb020")
			draw_circle(Vector2(cx + i * 40 + 16, cy), 16, Color(col, 0.95))
			draw_arc(Vector2(cx + i * 40 + 16, cy), 16, 0, TAU, 24, UI.BORDER, 2.0, true)
			var tc := UI.WHITE if t in ["4", "6", "W", "Wd"] else UI.INK_DARK
			var tw := f.get_string_size(t, 0, -1, 15).x
			draw_string(f, Vector2(cx + i * 40 + 16 - tw * 0.5, cy + 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tc)
		# chase
		var chase := s.chase_text()
		if chase != "":
			var cw := f.get_string_size(chase, 0, -1, 26).x
			var cr := Rect2(Vector2(size.x * 0.5 - cw * 0.5 - 24, 22), Vector2(cw + 48, 46))
			_panel(cr, UI.BLUE)
			draw_string(f, cr.position + Vector2(24, 32), chase, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK_DARK)

	func _draw_prompt() -> void:
		var t := ""
		var human_bat := not g._is_cpu(g.bat_team)
		var human_bowl := not g._is_cpu(g.field_team())
		match g.phase:
			CricketGame.Phase.BAT_SETUP:
				t = "%s: ◀ ▶ to move · hold the phone like a bat · tap B when ready" % g.batter_names[0]
			CricketGame.Phase.FIELD_SET:
				t = "%s: set your field · ▲ ▼ ◀ ▶ select · A pick up / drop · B done" % g.bowler_name
			CricketGame.Phase.AIM:
				t = "%s: ◀ ▶ line · ▲ ▼ length · A change type · hold B to run in" % g.bowler_name
			CricketGame.Phase.RUNUP:
				if human_bowl:
					t = "Swing your arm over and let go of B to bowl!"
				elif human_bat:
					t = "Get ready…"
			CricketGame.Phase.DELIVERY:
				if human_bat:
					t = "Swing!"
		if t == "":
			return
		var f := UI.bold()
		var tw := f.get_string_size(t, 0, -1, 24).x
		var r := Rect2(Vector2(size.x * 0.5 - tw * 0.5 - 26, size.y - 84), Vector2(tw + 52, 52))
		_panel(r, UI.BLUE)
		draw_string(f, r.position + Vector2(26, 35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.INK_DARK)

	func _draw_minimap() -> void:
		# soft white veil over the 3D view so the map is the focus
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.95, 0.97, 0.82))
		var rad := minf(size.y * 0.33, 240.0)
		var c := Vector2(size.x * 0.5 + 150, size.y * 0.48)
		var sc := rad / CricketField.BOUNDARY
		draw_circle(c, rad + 16, Color(1, 1, 1, 0.92))
		draw_circle(c, rad, Color("4f9e3e"))
		draw_arc(c, rad, 0, TAU, 96, Color("2b7fe0"), 4.0, true)
		var m := g._mirror()
		var to_map := func(p: Vector3) -> Vector2:
			return c + Vector2(p.x * m - CricketField.CENTER.x, p.z - CricketField.CENTER.z) * sc
		# 30-yard circle (oval)
		var pts := PackedVector2Array()
		for i in 49:
			var a := PI + PI * i / 48.0
			pts.append(to_map.call(Vector3(cos(a) * CricketField.CIRCLE, 0, CricketField.BOWL_Z + sin(a) * CricketField.CIRCLE)))
		for i in 49:
			var a := PI * i / 48.0
			pts.append(to_map.call(Vector3(cos(a) * CricketField.CIRCLE, 0, sin(a) * CricketField.CIRCLE)))
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.85), 2.5, true)
		# pitch
		var p0: Vector2 = to_map.call(Vector3(-1.5, 0, 0))
		var p1: Vector2 = to_map.call(Vector3(1.5, 0, CricketField.BOWL_Z))
		draw_rect(Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs()), Color("d8c597"))
		draw_circle(to_map.call(Vector3(0, 0, 0.0)), 5, UI.INK_DARK) # batter
		# fielders
		var f := UI.bold()
		for i in g.field_pos.size():
			var mp: Vector2 = to_map.call(g.field_pos[i])
			var sel := i == g._sel
			var inside := CricketField.inside_circle(g.field_pos[i])
			draw_circle(mp, 15 if sel else 11, Color("ffb020") if sel else (UI.WHITE if inside else Color("ffe08a")))
			draw_arc(mp, 15 if sel else 11, 0, TAU, 24, UI.INK_DARK, 2.0, true)
			if sel and g._holding:
				draw_arc(mp, 22, 0, TAU, 24, Color("ffb020"), 3.0, true)
			var n := str(i + 1)
			draw_string(f, mp + Vector2(-f.get_string_size(n, 0, -1, 13).x * 0.5, 5), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK_DARK)
		draw_circle(to_map.call(g.play.keeper.home if g.play.keeper else Vector3(0, 0, 9)), 8, UI.BORDER) # keeper
		# rule panel
		var out := g.outside_count(g.field_pos)
		var mx := g.score.max_outside_circle()
		var rule := "%s · outside the circle: %d / %d" % ["Powerplay" if g.score.in_powerplay() else "Field restriction", out, mx]
		var rw := f.get_string_size(rule, 0, -1, 20).x
		var rr := Rect2(Vector2(c.x - rw * 0.5 - 18, c.y - rad - 66), Vector2(rw + 36, 40))
		# legend
		var lx := c.x - rad - 330
		var ly := c.y - 40
		draw_circle(Vector2(lx, ly), 11, UI.WHITE)
		draw_arc(Vector2(lx, ly), 11, 0, TAU, 20, UI.INK_DARK, 2.0, true)
		draw_string(UI.regular(), Vector2(lx + 22, ly + 7), "Inside the circle", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.INK_DARK)
		draw_circle(Vector2(lx, ly + 36), 11, Color("ffe08a"))
		draw_arc(Vector2(lx, ly + 36), 11, 0, TAU, 20, UI.INK_DARK, 2.0, true)
		draw_string(UI.regular(), Vector2(lx + 22, ly + 43), "Outside the circle", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.INK_DARK)
		draw_circle(Vector2(lx, ly + 72), 13, Color("ffb020"))
		draw_string(UI.regular(), Vector2(lx + 22, ly + 79), "Selected", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.INK_DARK)
		_panel(rr, Color("e0533d") if out > mx else UI.BLUE)
		draw_string(f, rr.position + Vector2(18, 27), rule, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e0533d") if out > mx else UI.INK_DARK)

	func _draw_aim() -> void:
		var f := UI.bold()
		var base := Vector2(size.x - 420, 110)
		_panel(Rect2(base, Vector2(390, 120)))
		for i in 3:
			var r := Rect2(base + Vector2(16 + i * 122, 16), Vector2(112, 44))
			var on := i == g.kind
			var sb := StyleBoxFlat.new()
			sb.bg_color = UI.BLUE if on else Color("eef1f4")
			sb.set_corner_radius_all(22)
			draw_style_box(sb, r)
			var t: String = CricketGame.KIND_NAMES[i]
			draw_string(f, r.position + Vector2((r.size.x - f.get_string_size(t, 0, -1, 20).x) * 0.5, 30), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.WHITE if on else UI.INK)
		var z := -g.aim.y
		var length := "Yorker" if z < 2.2 else ("Full" if z < 4.5 else ("Good length" if z < 7.0 else ("Short" if z < 9.5 else "Bouncer")))
		draw_string(f, base + Vector2(18, 100), "Length: " + length, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.INK_DARK)

	func _draw_results() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.55))
		var r := Rect2(Vector2(size.x * 0.5 - 360, size.y * 0.5 - 220), Vector2(720, 430))
		draw_style_box(UI.panel_style(UI.WHITE, UI.BLUE, 36, 5), r)
		var f := UI.bold()
		var t := g.score.result_text()
		draw_string(f, Vector2(r.get_center().x - f.get_string_size(t, 0, -1, 40).x * 0.5, r.position.y + 70), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK_DARK)
		for k in g.score.innings.size():
			var inn: CricketScore.Innings = g.score.innings[k]
			var team: Dictionary = g.teams[inn.team]
			var y := r.position.y + 130 + k * 90
			var row := Rect2(Vector2(r.position.x + 40, y), Vector2(r.size.x - 80, 70))
			draw_style_box(UI.panel_style(Color(team.color, 0.14), team.color, 24, 3), row)
			draw_string(f, row.position + Vector2(24, 45), str(team.name), HORIZONTAL_ALIGNMENT_LEFT, 300, 30, UI.INK_DARK)
			var sc := "%d/%d  (%s ov)" % [inn.runs, inn.wickets, g.score.over_text(inn)]
			draw_string(f, Vector2(row.end.x - 24 - f.get_string_size(sc, 0, -1, 30).x, row.position.y + 45), sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.BLUE_DARK)
