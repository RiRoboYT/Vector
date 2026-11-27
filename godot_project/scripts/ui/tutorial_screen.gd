class_name TutorialScreen
extends Screen
## How to bowl, one step per page. A = next.

const PAGES := [
	["Line up your shot", "Use ◀ ▶ to move left and right.\nPress A to switch to Turn and change the angle.", "arrows"],
	["Hold B", "Hold the big B button and swing your arm back,\nlike rolling a real bowling ball.", "B"],
	["Swing and let go of B", "Swing forward and let go of B to release the ball.\nA faster swing rolls a faster ball. Keep holding your phone!", "B"],
	["Add spin", "Twist your wrist left or right as you let go\nto curve the ball. Swing straight for a straight ball.", "twist"],
]

var page := 0


func _init() -> void:
	super()
	wants_pointer = false
	phone_hint = "Press A for next"


func _process(delta: float) -> void:
	super(delta)
	if _t > 0.3 and Pad.just_pressed(Pad.A):
		Sfx.click()
		page += 1
		_t = 0.0
		if page >= PAGES.size():
			done.emit("ok")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.WHITE)
	var p: Array = PAGES[mini(page, PAGES.size() - 1)]
	var f := UI.bold()
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 100)), Color("f6f6f6"))
	draw_rect(Rect2(Vector2(0, 100), Vector2(size.x, 5)), UI.BLUE)
	draw_string(f, Vector2(60, 66), "How to bowl", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK)
	# page dots
	for i in PAGES.size():
		var dc := Vector2(size.x - 60 - (PAGES.size() - 1 - i) * 30, 52)
		draw_circle(dc, 9, UI.BLUE if i == page else UI.BORDER)
	# illustration
	var pc := Vector2(size.x * 0.27, size.y * 0.53)
	var hl: String = p[2]
	if hl == "twist":
		var ang := sin(_t * 3.0) * 0.35
		draw_set_transform(pc, ang, Vector2.ONE)
		draw_phone(Vector2.ZERO, 330, "B")
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_arc(pc, 200, -PI * 0.75, -PI * 0.25, 24, Color("ffb020"), 8.0, true)
	elif page == 1 or page == 2:
		var swing := sin(_t * 2.4) * 0.6 * (1.0 if page == 1 else -1.0)
		draw_set_transform(pc + Vector2(0, -150), swing, Vector2.ONE)
		draw_phone(Vector2(0, 150), 330, "B")
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_arc(pc + Vector2(0, -150), 330, PI * 0.25, PI * 0.75, 24, Color("ffb020"), 8.0, true)
	else:
		draw_phone(pc, 330, "arrows" if fmod(_t, 2.0) < 1.0 else "A")
	# text
	var tx := size.x * 0.5
	draw_string(f, Vector2(tx, size.y * 0.38), str(page + 1) + ".  " + p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 50, UI.BLUE)
	draw_multiline_string(UI.regular(), Vector2(tx, size.y * 0.38 + 70), p[1], HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.46, 30, -1, UI.INK_DARK)
	var a := 0.5 + 0.5 * sin(_t * 3.5)
	draw_press_a(size.y - 50, "Next" if page < PAGES.size() - 1 else "Let's bowl!", 0.4 + a * 0.6)
