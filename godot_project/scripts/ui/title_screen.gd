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
	draw_rect(Rect2(Vector2.ZERO, size), UI.WHITE)
	var faint := Color("efefef")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		var p := Vector2(rng.randf_range(60, size.x - 60), rng.randf_range(40, size.y - 200))
		var bob := sin(_t * 0.8 + i) * 6.0
		match i % 3:
			0: # bowling pin
				var s := rng.randf_range(0.8, 1.3)
				draw_circle(p + Vector2(0, bob), 14 * s, faint)
				draw_circle(p + Vector2(0, 40 * s + bob), 24 * s, faint)
				draw_rect(Rect2(p + Vector2(-8 * s, 8 * s + bob), Vector2(16 * s, 24 * s)), faint)
			1: # ball
				draw_circle(p + Vector2(0, bob), rng.randf_range(22, 36), faint)
			2: # racket
				draw_arc(p + Vector2(0, bob), 26, 0, TAU, 24, faint, 9.0)
				draw_line(p + Vector2(0, 26 + bob), p + Vector2(0, 74 + bob), faint, 9.0)
	UI.draw_logo(self, Vector2(size.x * 0.5, size.y * 0.42), 1.25)
	# two-tone band
	var by := size.y * 0.62
	draw_rect(Rect2(Vector2(0, by), Vector2(size.x, 6)), UI.BLUE)
	draw_rect(Rect2(Vector2(0, by + 10), Vector2(size.x, 3)), UI.BORDER)
	var a := 0.5 + 0.5 * sin(_t * 3.5)
	draw_press_a(size.y * 0.78, "to start", 0.35 + a * 0.65)
	var f := UI.regular()
	var cr := "VectorSports — a phone motion game"
	var cw := f.get_string_size(cr, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2(size.x * 0.5 - cw * 0.5, size.y - 30), cr, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.INK_SOFT)
