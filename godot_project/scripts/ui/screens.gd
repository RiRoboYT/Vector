class_name Screen
extends Control
## Base for full-screen menus. Emits `done` with an action name.

signal done(action: String)

var wants_pointer := true
var phone_hint := "Point at the screen and press A"
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


static var _stripes: Texture2D
## True while the live 3D menu backdrop is showing behind the screens.
static var backdrop := false


func draw_stripes() -> void:
	if _stripes == null:
		_stripes = UI.stripes_texture()
	if backdrop:
		# frosted pinstripe glass over the 3D island
		draw_texture_rect(_stripes, Rect2(Vector2.ZERO, size), true, Color(1, 1, 1, 0.5))
	else:
		draw_texture_rect(_stripes, Rect2(Vector2.ZERO, size), true)


## "Press (A) to ..." line with a drawn A badge, centred at y.
func draw_press_a(y: float, text: String, alpha := 1.0) -> void:
	var f := UI.bold()
	var size_px := 30
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var pre := "Press"
	var pw := f.get_string_size(pre, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var total := pw + 16 + 40 + 16 + tw
	var x := size.x * 0.5 - total * 0.5
	var col := Color(UI.INK, alpha)
	draw_string(f, Vector2(x, y), pre, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
	draw_a_badge(Vector2(x + pw + 16 + 20, y - 10), 20, alpha)
	draw_string(f, Vector2(x + pw + 16 + 40 + 16, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func draw_a_badge(c: Vector2, r: float, alpha := 1.0) -> void:
	draw_circle(c, r, Color(UI.WHITE, alpha))
	draw_arc(c, r, 0, TAU, 40, Color(UI.BLUE, alpha), 3.0, true)
	var f := UI.bold()
	var fs := int(r * 1.2)
	var ts := f.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(f, c + Vector2(-ts.x * 0.5, fs * 0.36), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.BLUE_DARK, alpha))


## A simple phone with the controller layout; highlight: "arrows", "A", "B".
func draw_phone(c: Vector2, h: float, highlight := "") -> void:
	var w := h * 0.5
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2b2f36")
	sb.set_corner_radius_all(int(w * 0.16))
	draw_style_box(sb, r)
	var scr := r.grow(-w * 0.06)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color("eaf3ff")
	ss.set_corner_radius_all(int(w * 0.11))
	draw_style_box(ss, scr)
	var u := scr.size.x / 10.0
	var hl := Color("ffb020")
	# arrows
	for k in 2:
		var ar := Rect2(scr.position + Vector2(u * (0.6 + k * 4.6), u * 1.2), Vector2(u * 4.2, u * 2.2))
		var ab := StyleBoxFlat.new()
		ab.bg_color = hl if highlight == "arrows" else UI.WHITE
		ab.set_corner_radius_all(int(u))
		ab.border_color = UI.BLUE_SOFT
		ab.set_border_width_all(2)
		draw_style_box(ab, ar)
		var mc := ar.get_center()
		var d := -1.0 if k == 0 else 1.0
		draw_colored_polygon(PackedVector2Array([mc + Vector2(u * 0.7 * d, 0), mc + Vector2(-u * 0.5 * d, -u * 0.6), mc + Vector2(-u * 0.5 * d, u * 0.6)]), UI.BLUE_DARK)
	# A
	var ac := scr.position + Vector2(scr.size.x * 0.5, u * 5.6)
	draw_circle(ac, u * 1.3, hl if highlight == "A" else UI.WHITE)
	draw_arc(ac, u * 1.3, 0, TAU, 32, UI.BLUE, 2.0, true)
	var f := UI.bold()
	draw_string(f, ac + Vector2(-u * 0.45, u * 0.5), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, int(u * 1.4), UI.BLUE_DARK)
	# B
	var br := Rect2(scr.position + Vector2(u * 0.6, u * 8.0), Vector2(scr.size.x - u * 1.2, scr.size.y - u * 9.0))
	var bb := StyleBoxFlat.new()
	bb.bg_color = hl if highlight == "B" else UI.BLUE
	bb.set_corner_radius_all(int(u * 1.6))
	draw_style_box(bb, br)
	draw_string(f, br.get_center() + Vector2(-u * 0.9, u * 1.0), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, int(u * 3.0), UI.WHITE)
