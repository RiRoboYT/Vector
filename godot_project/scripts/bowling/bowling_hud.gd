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
var _final_score: Label


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

	# final panel
	_final = Control.new()
	_final.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final.visible = false
	root.add_child(_final)
	var dim := ColorRect.new()
	dim.color = Color(1, 1, 1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.panel_style(UI.WHITE, UI.BLUE, 36, 5))
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(560, 380)
	card.position = Vector2(-280, -150)
	_final.add_child(card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(UI.label("Final Score", 34, UI.INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	_final_score = UI.label("0", 110, UI.BLUE, true, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_final_score)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	var again := PillButton.new("Play Again", Vector2(230, 78))
	again.pressed.connect(func(): play_again.emit())
	row.add_child(again)
	var menu := PillButton.new("Menu", Vector2(230, 78))
	menu.pressed.connect(func(): to_menu.emit())
	row.add_child(menu)


func _hint_label(t: String) -> Label:
	var l := UI.label(t, 26, UI.WHITE, true)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.35, 0.55, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	return l


func set_pins(mask: Array[bool]) -> void:
	_canvas.pins = mask


func set_score(s: BowlingScore) -> void:
	_canvas.marks = s.marks()
	_canvas.totals = s.totals()
	_canvas.current = s.current_frame() if not s.is_over() else -1


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


func show_final(total: int) -> void:
	_final_score.text = str(total)
	_final.visible = true


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
	_canvas.queue_redraw()


class HudCanvas:
	extends Control
	var pins: Array[bool] = []
	var marks: Array = []
	var totals: Array[int] = []
	var current := 0

	func _draw() -> void:
		_draw_pins(Vector2(34, 28))
		_draw_card()

	func _draw_pins(o: Vector2) -> void:
		var bg := UI.panel_style(Color(1, 1, 1, 0.85), UI.BORDER, 22, 2)
		draw_style_box(bg, Rect2(o, Vector2(196, 172)))
		# rows from the back: 7-10, 4-6, 2-3, 1
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

	func _draw_card() -> void:
		var f := UI.bold()
		var fw := 54.0
		var w := fw * 9 + 78 + 80
		var o := Vector2(size.x - w - 30, 28)
		draw_style_box(UI.panel_style(Color(1, 1, 1, 0.9), UI.BORDER, 16, 2), Rect2(o - Vector2(8, 8), Vector2(w + 16, 106)))
		for f_i in 11:
			var x := o.x + f_i * fw
			var bw := fw if f_i < 9 else (78.0 if f_i == 9 else 80.0)
			if f_i == 10:
				x = o.x + fw * 9 + 78
			var head := Rect2(Vector2(x, o.y), Vector2(bw - 3, 26))
			var hl := f_i == current
			var hs := StyleBoxFlat.new()
			hs.bg_color = UI.BLUE if f_i < 10 else UI.INK
			if hl:
				hs.bg_color = Color("ffb020")
			hs.corner_radius_top_left = 8
			hs.corner_radius_top_right = 8
			draw_style_box(hs, head)
			var label := str(f_i + 1) if f_i < 10 else "Total"
			var ls := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string(f, Vector2(x + (bw - 3 - ls.x) * 0.5, o.y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.WHITE)
			var body := Rect2(Vector2(x, o.y + 26), Vector2(bw - 3, 64))
			draw_rect(body, Color("fbfbfb"))
			draw_rect(body, UI.BORDER, false, 1.5)
			if f_i < 10 and f_i < marks.size():
				var m: Array = marks[f_i]
				var cells := 3 if f_i == 9 else 2
				var cw := 24.0
				for k in m.size():
					var cx := x + bw - 3 - (cells - k) * cw
					var cell := Rect2(Vector2(cx, o.y + 26), Vector2(cw, 26))
					draw_rect(cell, UI.BORDER, false, 1.0)
					var t: String = m[k]
					var tcol := Color("e0533d") if t == "X" or t == "/" else UI.INK_DARK
					var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
					draw_string(f, Vector2(cx + (cw - ts.x) * 0.5, o.y + 46), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tcol)
			var total_text := ""
			if f_i < 10 and f_i < totals.size() and totals[f_i] >= 0:
				total_text = str(totals[f_i])
			elif f_i == 10:
				var best := 0
				for t in totals:
					if t >= 0:
						best = t
				total_text = str(best)
			if total_text != "":
				var ts2 := f.get_string_size(total_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
				draw_string(f, Vector2(x + (bw - 3 - ts2.x) * 0.5, o.y + 82), total_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.INK_DARK)
