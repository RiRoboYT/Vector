class_name SafetyScreen
extends Screen
## Start-up safety reminder. Continue with A (or click / Enter).

const POINTS := [
	["Clear the area", "Make sure nobody, no pets and nothing breakable is within arm's reach before you swing."],
	["Hold on to your phone", "Grip your phone firmly. Only let go of the B button on the screen — never the phone itself."],
	["Use a case or strap", "A grippy case or wrist strap helps keep your phone safe during fast swings."],
]


func _init() -> void:
	super()
	wants_pointer = false
	phone_hint = "Press A to continue"


func _process(delta: float) -> void:
	super(delta)
	if _t > 0.6 and Pad.just_pressed(Pad.A):
		Sfx.click()
		done.emit("ok")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.WHITE)
	var cx := size.x * 0.42
	# warning badge
	var c := Vector2(cx - 210, 108)
	var tri := PackedVector2Array([c + Vector2(0, -40), c + Vector2(44, 34), c + Vector2(-44, 34)])
	draw_colored_polygon(tri, Color("ffc233"))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("e09a00"), 5.0, true)
	draw_rect(Rect2(c + Vector2(-4, -14), Vector2(8, 28)), UI.INK_DARK)
	draw_circle(c + Vector2(0, 24), 5, UI.INK_DARK)
	var f := UI.bold()
	draw_string(f, Vector2(cx - 150, 128), "SAFETY FIRST", HORIZONTAL_ALIGNMENT_LEFT, -1, 58, UI.BLUE)
	draw_line(Vector2(cx - 420, 175), Vector2(cx + 420, 175), UI.BORDER, 3.0)
	var reg := UI.regular()
	for i in POINTS.size():
		var y := 240.0 + i * 118.0
		draw_circle(Vector2(cx - 390, y - 10), 26, UI.BLUE)
		var n := str(i + 1)
		draw_string(f, Vector2(cx - 398, y), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.WHITE)
		draw_string(f, Vector2(cx - 340, y - 4), POINTS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UI.INK_DARK)
		draw_multiline_string(reg, Vector2(cx - 340, y + 34), POINTS[i][1], HORIZONTAL_ALIGNMENT_LEFT, 760, 24, 2, UI.INK)
	var a := 0.55 + 0.45 * sin(_t * 3.5)
	draw_press_a(size.y - 60, "to continue", a)

