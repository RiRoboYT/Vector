class_name BowlingHud
extends CanvasLayer
## Pin diagram (top-left), scorecard (top-right), control hints, big
## messages and the final score panel.

signal play_again
signal to_menu

var _canvas: HudCanvas
var _msg: Label
var _msg_t := 0.0
var _flash: Label
var _flash_t := 0.0
var _speed: Label
var _speed_t := 0.0
var _hints: Control
var _mode_lbl: Label
var _final: Control
var _results_view: ResultsView
var _again: PillButton
var _menu: PillButton
var _banner: Control
var _banner_view: BannerView
var _compact_target := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_canvas = HudCanvas.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_canvas)

	# control hints (bottom-left)
	_hints = VBoxContainer.new()
	_hints.add_theme_constant_override("separation", 6)
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hints.position = Vector2(30, -150)
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_hints)
	_mode_lbl = _hint_label("◀ ▶  Move")
	_hints.add_child(_mode_lbl)
	_hints.add_child(_hint_label("Ⓐ  Switch to Turn"))
	_hints.add_child(_hint_label("Hold Ⓑ  and swing"))

	_msg = UI.label("", 96, UI.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_msg.add_theme_color_override("font_outline_color", UI.BLUE_DARK)
	_msg.add_theme_constant_override("outline_size", 22)
	_msg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	_msg.add_theme_constant_override("shadow_offset_y", 6)
	_msg.set_anchors_preset(Control.PRESET_CENTER)
	_msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_msg.grow_vertical = Control.GROW_DIRECTION_BOTH
	_msg.modulate.a = 0.0
	root.add_child(_msg)

	_flash = UI.label("", 34, UI.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_flash.add_theme_color_override("font_outline_color", Color("e0533d"))
	_flash.add_theme_constant_override("outline_size", 12)
	_flash.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_flash.position.y = -230
	_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_flash)

	_speed = UI.label("", 30, UI.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_speed.add_theme_color_override("font_outline_color", UI.INK_DARK)
	_speed.add_theme_constant_override("outline_size", 10)
	_speed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed.position = Vector2(-260, -130)
	_speed.custom_minimum_size = Vector2(230, 40)
	root.add_child(_speed)

	# turn banner
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	root.add_child(_banner)
	_banner_view = BannerView.new()
	_banner_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.add_child(_banner_view)

	# results panel
	_final = Control.new()
	_final.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final.visible = false
	root.add_child(_final)
	_results_view = ResultsView.new()
	_results_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final.add_child(_results_view)
	_again = PillButton.new("Play Again", Vector2(240, 78))
	_again.pressed.connect(func(): play_again.emit())
	_final.add_child(_again)
	_menu = PillButton.new("Menu", Vector2(240, 78))
	_menu.pressed.connect(func(): to_menu.emit())
	_final.add_child(_menu)


func _hint_label(t: String) -> Label:
	var l := UI.label(t, 26, UI.WHITE, true)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.35, 0.55, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	return l


func set_pins(mask: Array[bool]) -> void:
	_canvas.pins = mask


func set_scores(scores: Array[BowlingScore], players: Array[Players.Player], cur: int) -> void:
	_canvas.scores = scores
	_canvas.players = players
	_canvas.cur = cur


## Small single-row scorecard while aiming / rolling; full card otherwise.
func set_compact(on: bool) -> void:
	_compact_target = 1.0 if on else 0.0


func turn_banner(name: String, color: Color, sub: String) -> void:
	_banner_view.title = name.to_upper() + "'S TURN"
	_banner_view.color = color
	_banner_view.sub = sub
	_banner_view.t = 0.0
	_banner.visible = true


func hide_banner() -> void:
	_banner.visible = false


func set_mode(turn: bool) -> void:
	_mode_lbl.text = "◀ ▶  Turn" if turn else "◀ ▶  Move"
	(_hints.get_child(1) as Label).text = "Ⓐ  Switch to Move" if turn else "Ⓐ  Switch to Turn"


func show_hints(on: bool) -> void:
	_hints.visible = on


func show_speed(mps: float) -> void:
	_speed.text = "%d km/h" % roundi(mps * 3.6)
	_speed_t = 3.0


func flash(t: String) -> void:
	_flash.text = t
	_flash_t = 1.8


func big_message(t: String, celebrate: bool) -> void:
	_msg.text = t
	_msg_t = 1.8
	_msg.add_theme_color_override("font_outline_color", UI.BLUE_DARK if celebrate else Color("7a8696"))


func show_results(scores: Array[BowlingScore], players: Array[Players.Player]) -> void:
	var rows: Array = []
	for i in players.size():
		rows.append({"name": players[i].name, "color": players[i].color, "score": scores[i].total(),
			"strikes": _count(scores[i], "X")})
	rows.sort_custom(func(x, y): return x.score > y.score)
	_results_view.rows = rows
	_banner.visible = false
	_final.visible = true


static func _count(s: BowlingScore, mark: String) -> int:
	var n := 0
	for f in s.marks():
		for m in f:
			if m == mark:
				n += 1
	return n


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t / 0.3, 0.0, 1.0)
		var pop := clampf((1.8 - _msg_t) / 0.18, 0.0, 1.0)
		_msg.pivot_offset = _msg.size * 0.5
		_msg.scale = Vector2.ONE * lerpf(1.5, 1.0, ease(pop, 0.4))
	else:
		_msg.modulate.a = 0.0
	_flash_t -= delta
	_flash.modulate.a = clampf(_flash_t / 0.3, 0.0, 1.0)
	_speed_t -= delta
	_speed.modulate.a = clampf(_speed_t / 0.5, 0.0, 1.0)
	_canvas.compact = move_toward(_canvas.compact, _compact_target, delta * 4.0)
	_canvas.queue_redraw()
	if _banner.visible:
		_banner_view.t += delta
		_banner_view.queue_redraw()
	if _final.visible:
		var vs := _final.size
		var n: int = _results_view.rows.size()
		var by := _results_view.buttons_y()
		_again.position = Vector2(vs.x * 0.5 - 260, by)
		_menu.position = Vector2(vs.x * 0.5 + 20, by)
		_results_view.queue_redraw()


class HudCanvas:
	extends Control
	var pins: Array[bool] = []
	var scores: Array[BowlingScore] = []
	var players: Array[Players.Player] = []
	var cur := 0
	var compact := 0.0 # 0 = full card, 1 = small single row

	func _draw() -> void:
		_draw_pins(Vector2(34, 28))
		_draw_card()

	func _draw_pins(o: Vector2) -> void:
		var bg := UI.panel_style(Color(1, 1, 1, 0.85), UI.BORDER, 22, 2)
		draw_style_box(bg, Rect2(o, Vector2(196, 172)))
		var rows := [[6, 7, 8, 9], [3, 4, 5], [1, 2], [0]]
		var f := UI.bold()
		for r in rows.size():
			var row: Array = rows[r]
			for k in row.size():
				var idx: int = row[k]
				var c := o + Vector2(98 + (k - (row.size() - 1) * 0.5) * 42, 32 + r * 37)
				var up := pins.size() > idx and pins[idx]
				draw_circle(c, 17, UI.WHITE if up else Color(0.85, 0.87, 0.9, 0.6))
				draw_arc(c, 17, 0, TAU, 32, UI.BLUE if up else Color(0.75, 0.78, 0.82, 0.6), 3.0, true)
				var s := str(idx + 1)
				var ts := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
				draw_string(f, c + Vector2(-ts.x * 0.5, 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.INK_DARK if up else Color(0.6, 0.62, 0.66, 0.6))

	## One row per player (current player first when there are more than 4).
	func _draw_card() -> void:
		if scores.is_empty():
			return
		var f := UI.bold()
		var name_w := 130.0
		var fw := 46.0
		var tenth := 66.0
		var tot_w := 66.0
		var row_h := 46.0
		var w := name_w + fw * 9 + tenth + tot_w
		var n := scores.size()
		var shown: Array[int] = []
		var small := compact > 0.5
		if small:
			shown.append(cur)
		else:
			for k in mini(n, 4):
				shown.append((cur + k) % n if n > 4 else k)
		var h := 26.0 + row_h * shown.size() + (22.0 if n > 4 and not small else 0.0)
		var o := Vector2(size.x - w - 30, 26)
		# shrink towards the top-right corner
		var sc := lerpf(1.0, 0.7, ease(compact, -2.0))
		var anchor := Vector2(size.x - 30 + 8, 26 - 8)
		draw_set_transform(anchor * (1.0 - sc), 0.0, Vector2(sc, sc))
		draw_style_box(UI.panel_style(Color(1, 1, 1, 0.92), UI.BORDER, 16, 2), Rect2(o - Vector2(8, 8), Vector2(w + 16, h + 16)))
		# header
		for f_i in 11:
			var x := _col_x(o.x, f_i, name_w, fw, tenth)
			var bw := fw if f_i < 9 else (tenth if f_i == 9 else tot_w)
			var hs := StyleBoxFlat.new()
			hs.bg_color = UI.BLUE if f_i < 10 else UI.INK
			if f_i < 10 and f_i == scores[cur].current_frame() and not scores[cur].is_over():
				hs.bg_color = Color("ffb020")
			hs.corner_radius_top_left = 7
			hs.corner_radius_top_right = 7
			draw_style_box(hs, Rect2(Vector2(x, o.y), Vector2(bw - 3, 24)))
			var label := str(f_i + 1) if f_i < 10 else "Total"
			var ls := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			draw_string(f, Vector2(x + (bw - 3 - ls.x) * 0.5, o.y + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.WHITE)
		# rows
		for r in shown.size():
			var pi := shown[r]
			var y := o.y + 26 + r * row_h
			var s: BowlingScore = scores[pi]
			var p: Players.Player = players[pi]
			var is_cur := pi == cur
			if is_cur:
				# soft tinted row + accent bar, kept inside the card
				var hl := StyleBoxFlat.new()
				hl.bg_color = Color(p.color, 0.18)
				hl.set_corner_radius_all(8)
				draw_style_box(hl, Rect2(Vector2(o.x - 2, y - 1), Vector2(w - 1, row_h - 2)))
				var bar := StyleBoxFlat.new()
				bar.bg_color = p.color
				bar.set_corner_radius_all(3)
				draw_style_box(bar, Rect2(Vector2(o.x - 2, y + 4), Vector2(5, row_h - 12)))
			draw_circle(Vector2(o.x + 12, y + row_h * 0.5 - 1), 8, p.color)
			draw_string(f, Vector2(o.x + 26, y + row_h * 0.5 + 6), p.name.left(9), HORIZONTAL_ALIGNMENT_LEFT, name_w - 30, 18, UI.INK_DARK)
			var marks := s.marks()
			var totals := s.totals()
			for f_i in 11:
				var x := _col_x(o.x, f_i, name_w, fw, tenth)
				var bw := fw if f_i < 9 else (tenth if f_i == 9 else tot_w)
				var body := Rect2(Vector2(x, y), Vector2(bw - 3, row_h - 4))
				draw_rect(body, Color(1, 1, 1, 0.95))
				draw_rect(body, UI.BORDER, false, 1.2)
				if f_i < 10 and f_i < marks.size():
					var m: Array = marks[f_i]
					var cells := 3 if f_i == 9 else 2
					var cw := 20.0
					for k in m.size():
						var cx := x + bw - 3 - (cells - k) * cw
						draw_rect(Rect2(Vector2(cx, y), Vector2(cw, 20)), UI.BORDER, false, 1.0)
						var t: String = m[k]
						var col := Color("e0533d") if t == "X" or t == "/" else UI.INK_DARK
						var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
						draw_string(f, Vector2(cx + (cw - ts.x) * 0.5, y + 16), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
				var txt := ""
				if f_i < 10 and f_i < totals.size() and totals[f_i] >= 0:
					txt = str(totals[f_i])
				elif f_i == 10:
					txt = str(s.total())
				if txt != "":
					var fs := 22 if f_i == 10 else 17
					var ts2 := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
					draw_string(f, Vector2(x + (bw - 3 - ts2.x) * 0.5, y + row_h - 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK_DARK)
		if n > 4 and not small:
			var more := "+%d more players" % (n - 4)
			draw_string(UI.regular(), Vector2(o.x + 4, o.y + h - 4), more, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _col_x(x0: float, f_i: int, name_w: float, fw: float, tenth: float) -> float:
		if f_i < 10:
			return x0 + name_w + f_i * fw
		return x0 + name_w + 9 * fw + tenth


class BannerView:
	extends Control
	var title := ""
	var sub := ""
	var color := Color.WHITE
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var slide := ease(clampf(t / 0.35, 0.0, 1.0), 0.3)
		var y := size.y * 0.56
		var band := Rect2(Vector2(lerpf(-size.x, 0.0, slide), y - 70), Vector2(size.x, 140))
		draw_rect(band, Color(1, 1, 1, 0.93))
		draw_rect(Rect2(band.position, Vector2(size.x, 8)), color)
		draw_rect(Rect2(band.position + Vector2(0, 132), Vector2(size.x, 8)), color)
		var f := UI.bold()
		var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
		draw_string(f, Vector2(band.position.x + (size.x - ts.x) * 0.5, y + 14), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, color.darkened(0.15))
		var line := sub if sub != "" else "Press A when ready"
		if sub != "":
			line += "  ·  Press A when ready"
		var a := 0.55 + 0.45 * sin(t * 4.0)
		var ls := UI.regular().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		draw_string(UI.regular(), Vector2(band.position.x + (size.x - ls.x) * 0.5, y + 54), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(UI.INK_DARK, a))


class ResultsView:
	extends Control
	var rows: Array = []
	const MEDALS := [Color("f2c230"), Color("b9c2cc"), Color("d08a4e")]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func panel_rect() -> Rect2:
		var h := 150.0 + rows.size() * 54.0 + 110.0
		return Rect2(Vector2(size.x * 0.5 - 330, maxf(30.0, size.y * 0.5 - h * 0.5)), Vector2(660, h))

	func buttons_y() -> float:
		var r := panel_rect()
		return r.end.y - 100

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.55))
		var r := panel_rect()
		draw_style_box(UI.panel_style(UI.WHITE, UI.BLUE, 36, 5), r)
		var f := UI.bold()
		var title := "Final Scores" if rows.size() > 1 else "Final Score"
		var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
		draw_string(f, Vector2(r.get_center().x - ts.x * 0.5, r.position.y + 70), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK)
		var rank := 0
		var prev := -1
		for i in rows.size():
			var row: Dictionary = rows[i]
			if row.score != prev:
				rank = i
				prev = row.score
			var y := r.position.y + 110 + i * 54
			var rr := Rect2(Vector2(r.position.x + 40, y), Vector2(r.size.x - 80, 46))
			draw_style_box(UI.panel_style(Color(row.color, 0.13), Color(row.color, 0.7), 23, 2), rr)
			var mc := Vector2(rr.position.x + 30, y + 23)
			draw_circle(mc, 17, MEDALS[rank] if rank < 3 else UI.BORDER)
			var rs := str(rank + 1)
			var rsz := f.get_string_size(rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			draw_string(f, mc + Vector2(-rsz.x * 0.5, 7), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.WHITE)
			draw_circle(Vector2(rr.position.x + 70, y + 23), 8, row.color)
			draw_string(f, Vector2(rr.position.x + 88, y + 32), str(row.name), HORIZONTAL_ALIGNMENT_LEFT, 260, 26, UI.INK_DARK)
			var st := "%d strike%s" % [row.strikes, "" if row.strikes == 1 else "s"]
			draw_string(UI.regular(), Vector2(rr.position.x + 330, y + 31), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.INK)
			var sc := str(row.score)
			var scs := f.get_string_size(sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
			draw_string(f, Vector2(rr.end.x - 24 - scs.x, y + 35), sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UI.BLUE_DARK)
