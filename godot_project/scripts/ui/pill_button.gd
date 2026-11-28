class_name PillButton
extends Control
## Glossy rounded button. Lights up when the pointer is over it; pressing A
## (phone), Enter/Z (keyboard) or clicking activates it.

signal pressed

@export var text := ""
@export var enabled := true
@export var badge := "" # small tag like "Soon"
@export var font_size := 30
@export var round := false # circular button

var hovered := false
var _scale := 1.0
var _life := 0.0
var _delay := 0.0
var _press := 0.0
## Buttons pop in one after another when a screen opens.
static var _stagger := 0.0


static func reset_stagger() -> void:
	_stagger = 0.08


func _init(p_text := "", p_size := Vector2(300, 80)) -> void:
	text = p_text
	custom_minimum_size = p_size
	size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_delay = _stagger
	_stagger = minf(_stagger + 0.05, 0.6)


func _process(delta: float) -> void:
	_life += delta
	_press = maxf(0.0, _press - delta * 4.0)
	var was := hovered
	hovered = is_visible_in_tree() and Pad.pointer_visible and get_global_rect().has_point(Pad.pointer)
	if hovered and not was and enabled:
		Sfx.click(0.45, 1.25)
	if hovered and enabled and Pad.just_pressed(Pad.A):
		Sfx.click(1.0, 1.0)
		_press = 1.0
		pressed.emit()
	var target := 1.06 if hovered and enabled else 1.0
	_scale = lerpf(_scale, target, 1.0 - exp(-delta * 18.0))
	pivot_offset = size * 0.5
	# pop-in (ease out back) and a little squash when pressed
	var k := clampf((_life - _delay) / 0.32, 0.0, 1.0)
	var x := k - 1.0
	var pop := 1.0 + 2.7 * x * x * x + 1.7 * x * x
	modulate.a = k
	scale = Vector2.ONE * _scale * pop * (1.0 - sin(_press * PI) * 0.06)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := size.y * 0.5 if round else minf(size.y * 0.5, 34.0)
	# drop shadow
	_rounded(r.grow(2).grow_side(SIDE_BOTTOM, 4), radius + 2, Color(0, 0, 0, 0.10))
	# body: white top fading to light grey (glossy)
	var top := UI.WHITE if enabled else Color("f1f1f1")
	var bottom := Color("e4e7ea") if enabled else Color("e2e2e2")
	_rounded(r, radius, bottom)
	_rounded(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.55)), radius - 3, top)
	# border
	var bw := 5.0 if hovered and enabled else 3.0
	var bc := UI.BLUE if enabled else Color("cdcdcd")
	if hovered and enabled:
		_rounded_outline(r.grow(5), radius + 5, Color(UI.BLUE, 0.25), 6.0)
	_rounded_outline(r, radius, bc, bw)
	# label
	var f := UI.bold()
	var col := UI.INK_DARK if enabled else UI.INK_SOFT
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2((size.x - ts.x) * 0.5, (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	if badge != "":
		var bs := 16
		var bt := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs)
		var br := Rect2(Vector2(size.x - bt.x - 34, (size.y - 26) * 0.5), Vector2(bt.x + 18, 26))
		_rounded(br, 13, Color("d9d9d9"))
		draw_string(f, br.position + Vector2(9, 19), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, UI.WHITE)


func _rounded(r: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(maxf(radius, 0)))
	sb.anti_aliasing_size = 1.0
	draw_style_box(sb, r)


func _rounded_outline(r: Rect2, radius: float, c: Color, w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = c
	sb.set_border_width_all(int(w))
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing_size = 1.0
	draw_style_box(sb, r)
