class_name TutorialScreen
extends Screen
## Step-by-step how-to pages with an animated phone. A = next.
## Each page: [title, text, visual] where visual is one of
## "arrows", "A", "B", "back", "forward", "twist", "bat", "overarm", "field".

const BOWLING := [
	["Line up your shot", "Use ◀ ▶ to move left and right.\nPress A to switch to Turn and change the angle.", "arrows"],
	["Hold B", "Hold the big B button and swing your arm back,\nlike rolling a real bowling ball.", "back"],
	["Swing and let go of B", "Swing forward and let go of B to release the ball.\nA faster swing rolls a faster ball. Keep holding your phone!", "forward"],
	["Add spin", "Twist your wrist left or right as you let go\nto curve the ball. Swing straight for a straight ball.", "twist"],
]

const CRICKET := [
	["Batting: take guard", "Use ◀ ▶ to move across the crease.\nPoint your phone at the floor like a grounded bat,\nscreen facing the TV, then tap B.", "stance"],
	["Batting: swing the bat", "Your phone IS the bat – the bat copies every move.\nSwing as the ball arrives and hit it with the middle\nof the bat!", "bat"],
	["Batting: timing", "On time = hard along the ground. Too early pops it up,\ntoo late is slow or an edge. Turn the bat face to aim.\nRunning between the wickets is automatic.", "bat"],
	["Bowling: set your field", "▲ ▼ ◀ ▶ choose a fielder, A picks up / drops, then\nmove them. B when done. Powerplay: max 2 outside the\ncircle – otherwise max 5.", "field"],
	["Bowling: aim", "◀ ▶ line and ▲ ▼ length (the ring on the pitch).\nA switches Fast / Medium / Spin. Tap B to run in.", "arrows"],
	["Bowling: timing meter", "Tap B when the marker is in the green. Gold = perfect\npace and line. Top red = no-ball (free hit next),\nbottom red = wide. Miss it = dead ball.", "meter"],
	["Bowling: half swing", "Grip the phone and make a short bowling swing.\nStraight = no swing. Angle it left or right to swing\nthe ball that way. Twist your wrist to spin it.", "halfswing"],
]

var pages: Array = BOWLING
var title := "How to bowl"
var finish_text := "Let's bowl!"
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
		if page >= pages.size():
			done.emit("ok")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.WHITE)
	var p: Array = pages[mini(page, pages.size() - 1)]
	var f := UI.bold()
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 100)), Color("f6f6f6"))
	draw_rect(Rect2(Vector2(0, 100), Vector2(size.x, 5)), UI.BLUE)
	draw_string(f, Vector2(60, 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK)
	for i in pages.size():
		var dc := Vector2(size.x - 60 - (pages.size() - 1 - i) * 30, 52)
		draw_circle(dc, 9, UI.BLUE if i == page else UI.BORDER)
	var pc := Vector2(size.x * 0.25, size.y * 0.55)
	var hl: String = p[2]
	var orange := Color("ffb020")
	match hl:
		"twist":
			draw_set_transform(pc, sin(_t * 3.0) * 0.35, Vector2.ONE)
			draw_phone(Vector2.ZERO, 330, "B")
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_arc(pc, 200, -PI * 0.75, -PI * 0.25, 24, orange, 8.0, true)
		"back", "forward":
			var swing := sin(_t * 2.4) * 0.6 * (1.0 if hl == "back" else -1.0)
			draw_set_transform(pc + Vector2(0, -150), swing, Vector2.ONE)
			draw_phone(Vector2(0, 150), 330, "B")
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_arc(pc + Vector2(0, -150), 330, PI * 0.25, PI * 0.75, 24, orange, 8.0, true)
		"bat":
			# phone as the handle, bat blade below, swinging through
			var a := sin(_t * 2.6) * 1.1
			var pivot := pc + Vector2(0, -170)
			draw_set_transform(pivot, a, Vector2.ONE)
			draw_rect(Rect2(Vector2(-26, 120), Vector2(52, 190)), Color("ead2a0"))
			draw_rect(Rect2(Vector2(-26, 120), Vector2(52, 190)), Color("c9a86a"), false, 3.0)
			draw_phone(Vector2(0, 40), 200, "")
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_arc(pivot, 330, PI * 0.15, PI * 0.85, 32, orange, 8.0, true)
			var ball_x := pc.x + 220.0 - fmod(_t * 160.0, 300.0)
			draw_circle(Vector2(ball_x, pc.y + 130), 14, Color("f4f1ea"))
			draw_arc(Vector2(ball_x, pc.y + 130), 14, 0, TAU, 20, Color("3a7bd5"), 2.0)
		"overarm":
			var a2 := fmod(_t * 3.0, TAU)
			var piv := pc + Vector2(0, 30)
			draw_set_transform(piv, a2, Vector2.ONE)
			draw_phone(Vector2(0, -150), 200, "B")
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_arc(piv, 160, 0, TAU, 48, Color(orange, 0.6), 6.0, true)
		"field":
			var c := pc
			draw_circle(c, 190, Color("4f9e3e"))
			draw_arc(c, 190, 0, TAU, 64, Color("2b7fe0"), 5.0, true)
			draw_arc(c, 95, 0, TAU, 48, Color(1, 1, 1, 0.8), 3.0, true)
			draw_rect(Rect2(c + Vector2(-8, -34), Vector2(16, 68)), Color("d8c597"))
			var spots := [Vector2(60, -40), Vector2(-70, -20), Vector2(30, 70), Vector2(-40, 60), Vector2(140, -60), Vector2(-120, 110)]
			for i in spots.size():
				var sp: Vector2 = spots[i]
				if i == 0:
					sp += Vector2(sin(_t * 1.5) * 60.0, cos(_t * 1.5) * 30.0)
				draw_circle(c + sp, 13 if i == 0 else 10, orange if i == 0 else UI.WHITE)
		"stance":
			# phone pointing at the floor like a grounded bat, tap B
			draw_set_transform(pc + Vector2(0, -30), PI, Vector2.ONE)
			draw_phone(Vector2.ZERO, 260, "B")
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_rect(Rect2(pc + Vector2(-24, 100), Vector2(48, 150)), Color("ead2a0"))
			draw_line(pc + Vector2(-160, 252), pc + Vector2(160, 252), Color("4f9e3e"), 6.0)
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_arc(pc + Vector2(0, -30), 150 + pulse * 10.0, 0, TAU, 48, Color(orange, 0.5), 4.0, true)
		"meter":
			var h := 360.0
			var r := Rect2(pc + Vector2(-34, -h * 0.5), Vector2(68, h))
			draw_rect(r, Color("e0533d"))
			draw_rect(Rect2(r.position + Vector2(0, h * 0.06), Vector2(68, h * 0.88)), Color("4cc76a"))
			draw_rect(Rect2(r.position + Vector2(0, h * 0.44), Vector2(68, h * 0.12)), Color("ffc233"))
			var x := fmod(_t * 0.9, 2.0)
			var m := (x if x < 1.0 else 2.0 - x) * 2.0 - 1.0
			var my := r.position.y + (1.0 - (m + 1.0) * 0.5) * h
			draw_rect(Rect2(Vector2(r.position.x - 14, my - 3), Vector2(96, 6)), UI.INK_DARK)
			draw_string(UI.bold(), r.position + Vector2(-6, -14), "NO BALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e0533d"))
			draw_string(UI.bold(), r.end + Vector2(-58, 26), "WIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e0533d"))
			draw_phone(pc + Vector2(190, 40), 220, "B")
		"halfswing":
			var k := fmod(_t, 3.0)
			var side := 0.0 if k < 1.0 else (-1.0 if k < 2.0 else 1.0)
			var sw := sin(fmod(_t, 1.0) * PI) * 0.9
			var piv := pc + Vector2(0, 60)
			draw_set_transform(piv, -sw + side * 0.0, Vector2.ONE)
			draw_phone(Vector2(0, -130), 200, "")
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			var dir := Vector2(side * 0.6, -1.0).normalized()
			draw_line(piv + Vector2(0, -40), piv + Vector2(0, -40) + dir * 170.0, orange, 8.0, true)
			var lab := "straight: no swing" if side == 0.0 else ("angled left: swings left" if side < 0.0 else "angled right: swings right")
			draw_string(UI.bold(), pc + Vector2(-150, 250), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.INK)
		_:
			draw_phone(pc, 330, hl if hl in ["arrows", "A", "B"] else "")
	var tx := size.x * 0.48
	draw_string(f, Vector2(tx, size.y * 0.33), str(page + 1) + ".  " + p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 46, UI.BLUE)
	draw_multiline_string(UI.regular(), Vector2(tx, size.y * 0.33 + 64), p[1], HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.49, 28, -1, UI.INK_DARK)
	var al := 0.5 + 0.5 * sin(_t * 3.5)
	draw_press_a(size.y - 50, "Next" if page < pages.size() - 1 else finish_text, 0.4 + al * 0.6)
