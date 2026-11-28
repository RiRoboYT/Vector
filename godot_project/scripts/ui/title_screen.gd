class_name TitleScreen
extends Screen
## White title screen with the logo over faint sports silhouettes.

func _init() -> void:
	super()
	wants_pointer = false
	phone_hint = "Press A to start"


func _process(delta: float) -> void:
	super(delta)
	if _t > 0.4 and Pad.just_pressed(Pad.A):
		Sfx.click()
		done.emit("start")


func _draw() -> void:
	# frosted wash over the 3D island so the logo pops
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.0 if Screen.backdrop else 1.0))
	var glass := Rect2(Vector2(size.x * 0.5 - 360, size.y * 0.26 - 110), Vector2(720, 210))
	var intro := clampf(_t / 0.8, 0.0, 1.0)
	var x := intro - 1.0
	var pop := 1.0 + 2.7 * x * x * x + 1.7 * x * x # ease out back
	draw_set_transform(glass.get_center(), 0.0, Vector2.ONE * maxf(pop, 0.01))
	var gr := Rect2(-glass.size * 0.5, glass.size)
	draw_style_box(UI.panel_style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 60, 0), gr.grow(10).grow_side(SIDE_BOTTOM, 10))
	draw_style_box(UI.panel_style(Color(1, 1, 1, 0.9), Color(UI.BLUE, 0.5), 56, 3), gr)
	var bob := sin(_t * 1.6) * 4.0
	UI.draw_logo(self, Vector2(0, 24 + bob), 1.05)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# floating sport icons orbiting the logo
	var icons := 6
	for i in icons:
		var a := _t * 0.35 + TAU * i / icons
		var p := glass.get_center() + Vector2(cos(a) * 450.0, sin(a) * 150.0)
		var k := clampf((_t - 0.3 - i * 0.08) / 0.4, 0.0, 1.0)
		if k <= 0.0:
			continue
		draw_circle(p + Vector2(0, 6), 34 * k, Color(0, 0, 0, 0.08))
		draw_circle(p, 34 * k, UI.WHITE)
		match i % 3:
			0: # bowling pin
				draw_circle(p + Vector2(0, -10) * k, 8 * k, UI.INK_DARK)
				draw_circle(p + Vector2(0, 8) * k, 13 * k, UI.INK_DARK)
				draw_rect(Rect2(p + Vector2(-9, -2) * k, Vector2(18, 4) * k), Color("e23d3d"))
			1: # tennis ball
				draw_circle(p, 22 * k, Color("d9f23c"))
				draw_arc(p + Vector2(-26, 0) * k, 20 * k, -0.9, 0.9, 16, UI.WHITE, 3.0 * k, true)
				draw_arc(p + Vector2(26, 0) * k, 20 * k, PI - 0.9, PI + 0.9, 16, UI.WHITE, 3.0 * k, true)
			2: # cricket ball
				draw_circle(p, 22 * k, Color("c0392b"))
				draw_line(p + Vector2(-16, -14) * k, p + Vector2(16, 14) * k, Color("f2e3c0"), 3.0 * k, true)
	var a2 := 0.5 + 0.5 * sin(_t * 3.5)
	if _t > 0.9:
		var pill := Rect2(Vector2(size.x * 0.5 - 220, size.y * 0.86 - 46), Vector2(440, 66))
		draw_style_box(UI.panel_style(Color(1, 1, 1, 0.92), Color(UI.BLUE, 0.6), 33, 3), pill)
		draw_press_a(size.y * 0.86, "to start", 0.45 + a2 * 0.55)
	var f := UI.regular()
	var cr := "VectorSports — a phone motion game"
	var cw := f.get_string_size(cr, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2(size.x * 0.5 - cw * 0.5, size.y - 22), cr, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.WHITE)
