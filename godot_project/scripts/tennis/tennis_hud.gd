class_name TennisHud
extends CanvasLayer
## Tennis scoreboard (games + points), umpire calls, swing feedback and results.

signal play_again
signal to_menu

var game: TennisGame
var _view: HudView
var _msg: Label
var _msg_t := 0.0
var _flash: Label
var _flash_t := 0.0
var _info: Label
var _info_t := 0.0
var _call := ""
var _call_t := 0.0
var _final: Control
var _again: PillButton
var _menu: PillButton


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_view = HudView.new()
	_view.hud = self
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


func big_message(t: String, celebrate: bool) -> void:
	_msg.text = t
	_msg_t = 1.9
	_msg.add_theme_color_override("font_outline_color", UI.BLUE_DARK if celebrate else Color("7a8696"))


func flash(t: String) -> void:
	_flash.text = t
	_flash_t = 1.4


func speed_info(t: String) -> void:
	_info.text = t
	_info_t = 2.5


func set_call(t: String) -> void:
	_call = t
	_call_t = 2.6


func show_results() -> void:
	add_child(Confetti.new())
	_view.results = true
	_final.visible = true


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t / 0.3, 0.0, 1.0)
		var pop := clampf((1.9 - _msg_t) / 0.18, 0.0, 1.0)
		_msg.pivot_offset = _msg.size * 0.5
		_msg.scale = Vector2.ONE * lerpf(1.4, 1.0, ease(pop, 0.4))
	else:
		_msg.modulate.a = 0.0
	_flash_t -= delta
	_flash.modulate.a = clampf(_flash_t / 0.3, 0.0, 1.0)
	_info_t -= delta
	_info.modulate.a = clampf(_info_t / 0.5, 0.0, 1.0)
	_call_t -= delta
	if _final.visible:
		var vs := _final.size
		_again.position = Vector2(vs.x * 0.5 - 260, vs.y * 0.5 + 130)
		_menu.position = Vector2(vs.x * 0.5 + 20, vs.y * 0.5 + 130)
	_view.queue_redraw()


class HudView:
	extends Control
	var hud: TennisHud
	var results := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var g := hud.game
		if g == null:
			return
		if results:
			_draw_results(g)
			return
		_draw_board(g)
		if hud._call_t > 0.0 and hud._call != "":
			_draw_call(g)
		_draw_prompt(g)

	func _draw_board(g: TennisGame) -> void:
		var f := UI.bold()
		var r := Rect2(Vector2(26, 22), Vector2(470, 132))
		draw_style_box(UI.panel_style(Color(1, 1, 1, 0.93), UI.BORDER, 18, 2), r)
		for team in 2:
			var y := r.position.y + 14 + team * 56
			var row := Rect2(Vector2(r.position.x + 12, y), Vector2(r.size.x - 24, 48))
			var col: Color = TennisGame.TEAM_COLORS[team]
			var band := StyleBoxFlat.new()
			band.bg_color = col
			band.set_corner_radius_all(12)
			draw_style_box(band, Rect2(row.position, Vector2(14, 48)))
			draw_string(f, row.position + Vector2(28, 33), str(g.team_names[team]), HORIZONTAL_ALIGNMENT_LEFT, 230, 24, UI.INK_DARK)
			if g.score.server_team == team and g.phase != TennisGame.Phase.OVER:
				draw_circle(row.position + Vector2(row.size.x - 168, 24), 8.0, Color("d9f23c"))
				draw_arc(row.position + Vector2(row.size.x - 168, 24), 8.0, 0, TAU, 20, Color("8aa020"), 2.0, true)
			# games box
			var gb := Rect2(row.position + Vector2(row.size.x - 146, 4), Vector2(58, 40))
			var gs := StyleBoxFlat.new()
			gs.bg_color = Color("eef3f8")
			gs.set_corner_radius_all(10)
			draw_style_box(gs, gb)
			var gt := str(g.score.games[team])
			draw_string(f, Vector2(gb.get_center().x - f.get_string_size(gt, 0, -1, 28).x * 0.5, gb.position.y + 31), gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.INK_DARK)
			# points box
			var pb := Rect2(row.position + Vector2(row.size.x - 80, 4), Vector2(76, 40))
			var ps := StyleBoxFlat.new()
			ps.bg_color = col
			ps.set_corner_radius_all(10)
			draw_style_box(ps, pb)
			var pt := g.score.point_label(team)
			draw_string(f, Vector2(pb.get_center().x - f.get_string_size(pt, 0, -1, 28).x * 0.5, pb.position.y + 31), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.WHITE)

	func _draw_call(g: TennisGame) -> void:
		var f := UI.bold()
		var t := hud._call
		var w := f.get_string_size(t, 0, -1, 34).x + 60
		var a := clampf(hud._call_t / 0.4, 0.0, 1.0)
		var r := Rect2(Vector2(size.x * 0.5 - w * 0.5, 30), Vector2(w, 60))
		draw_style_box(UI.panel_style(Color(1, 1, 1, 0.92 * a), Color(UI.BLUE, a), 30, 3), r)
		draw_string(f, Vector2(r.get_center().x - (w - 60) * 0.5, r.position.y + 42), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(UI.INK_DARK, a))

	func _draw_prompt(g: TennisGame) -> void:
		var t := ""
		if g.phase == TennisGame.Phase.SERVE and g.is_human(g.server):
			t = "%s: tap B to toss" % g.server.name_
		elif g.phase == TennisGame.Phase.TOSS and g.is_human(g.server):
			t = "Swing!"
		if t == "":
			return
		var f := UI.bold()
		var w := f.get_string_size(t, 0, -1, 30).x + 56
		var r := Rect2(Vector2(size.x * 0.5 - w * 0.5, size.y - 110), Vector2(w, 58))
		draw_style_box(UI.panel_style(Color(1, 1, 1, 0.92), UI.BLUE, 29, 3), r)
		draw_string(f, Vector2(r.position.x + 28, r.position.y + 40), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.INK_DARK)

	func _draw_results(g: TennisGame) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.55))
		var r := Rect2(Vector2(size.x * 0.5 - 360, size.y * 0.5 - 220), Vector2(720, 430))
		draw_style_box(UI.panel_style(UI.WHITE, UI.BLUE, 36, 5), r)
		var f := UI.bold()
		var w := g.score.winner()
		var t := "%s win!" % g.team_names[w]
		draw_string(f, Vector2(r.get_center().x - f.get_string_size(t, 0, -1, 44).x * 0.5, r.position.y + 76), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UI.INK_DARK)
		for team in 2:
			var col: Color = TennisGame.TEAM_COLORS[team]
			var y := r.position.y + 130 + team * 90
			var row := Rect2(Vector2(r.position.x + 40, y), Vector2(r.size.x - 80, 70))
			draw_style_box(UI.panel_style(Color(col, 0.14), col, 24, 3), row)
			draw_string(f, row.position + Vector2(24, 45), str(g.team_names[team]), HORIZONTAL_ALIGNMENT_LEFT, 420, 30, UI.INK_DARK)
			var sc := "%d game%s" % [g.score.games[team], "" if g.score.games[team] == 1 else "s"]
			draw_string(f, Vector2(row.end.x - 24 - f.get_string_size(sc, 0, -1, 30).x, row.position.y + 45), sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.BLUE_DARK)
