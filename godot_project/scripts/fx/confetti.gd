class_name Confetti
extends Control
## Burst of colourful paper confetti over the whole screen; frees itself.

const COLS := [Color("31b8e8"), Color("ff7a3d"), Color("ffd23f"), Color("3fae5d"), Color("e86fa3"), Color("8d6fd6"), Color.WHITE]
var amount := 180
var _p: Array = [] # [pos, vel, rot, spin, size, col, wobble]
var _t := 0.0


func _init(p_amount := 180) -> void:
	amount = p_amount
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var w := get_viewport_rect().size.x
	for i in amount:
		# two cannons from the bottom corners plus a shower from the top
		var kind := i % 3
		var pos: Vector2
		var vel: Vector2
		if kind == 0:
			pos = Vector2(-10, get_viewport_rect().size.y * 0.75)
			vel = Vector2(randf_range(250, 700), randf_range(-950, -550))
		elif kind == 1:
			pos = Vector2(w + 10, get_viewport_rect().size.y * 0.75)
			vel = Vector2(randf_range(-700, -250), randf_range(-950, -550))
		else:
			pos = Vector2(randf_range(0, w), randf_range(-300, -20))
			vel = Vector2(randf_range(-40, 40), randf_range(40, 160))
		_p.append([pos, vel, randf() * TAU, randf_range(-9, 9), Vector2(randf_range(8, 14), randf_range(4, 8)), COLS[randi() % COLS.size()], randf() * TAU])


func _process(delta: float) -> void:
	_t += delta
	for q in _p:
		var v: Vector2 = q[1]
		v.y += 700.0 * delta
		v *= 1.0 - 1.6 * delta # air drag: paper floats
		v.y = minf(v.y, 220.0)
		q[1] = v
		q[0] = (q[0] as Vector2) + v * delta + Vector2(sin(_t * 4.0 + q[6]) * 30.0 * delta, 0)
		q[2] = float(q[2]) + float(q[3]) * delta
	queue_redraw()
	if _t > 5.0:
		queue_free()


func _draw() -> void:
	var fade := clampf((5.0 - _t) / 1.0, 0.0, 1.0)
	for q in _p:
		var s: Vector2 = q[4]
		var flip := absf(sin(float(q[2]) * 1.7)) # paper flipping in the air
		draw_set_transform(q[0], q[2], Vector2(1.0, maxf(flip, 0.15)))
		var c: Color = q[5]
		draw_rect(Rect2(-s * 0.5, s), Color(c, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
