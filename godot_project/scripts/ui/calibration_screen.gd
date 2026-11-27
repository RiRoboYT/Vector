class_name CalibrationScreen
extends Screen
## Compulsory: hold the phone like a remote, point at the target, press A.
## Shown whenever a phone connects and before every game. Without a phone it
## waits for one (Enter continues in keyboard mode for testing).

var motion: MotionInput
var server: ControllerServer
var _done_t := -1.0


func _init() -> void:
	super()
	wants_pointer = false
	phone_hint = "Point at the target on screen and press A"
	process_priority = -50 # before other screens so it can block input


func _process(delta: float) -> void:
	super(delta)
	if _done_t >= 0.0:
		if _t - _done_t > 0.7:
			done.emit("ok")
		return
	var a_pressed := Pad.raw_just_pressed(Pad.A)
	var phone := server != null and server.is_controller_connected() and motion.has_data
	if a_pressed and phone:
		motion.calibrate()
		Sfx.click(1.0, 1.4)
		_done_t = _t
	elif a_pressed and not phone and Pad.last_a_from_keyboard:
		_done_t = _t # keyboard / mouse testing without a phone


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.97))
	var c := size * 0.5 + Vector2(0, -20)
	var f := UI.bold()
	var phone := server != null and server.is_controller_connected() and motion != null and motion.has_data
	var ok := _done_t >= 0.0
	# target
	var pulse := 1.0 + 0.06 * sin(_t * 4.0)
	for i in 4:
		var r := (120 - i * 30) * pulse
		draw_circle(c, r, UI.BLUE if i % 2 == 0 else UI.WHITE)
	draw_circle(c, 18, Color("ffb020") if not ok else Color("2fbf5b"))
	var title := "Calibrated!" if ok else "Calibration"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	draw_string(f, Vector2(size.x * 0.5 - tw * 0.5, 110), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UI.BLUE)
	var line1 := "Hold your phone like a remote, top edge towards the screen." if phone else "Connect your phone to continue — scan the QR code."
	var w1 := UI.regular().get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(UI.regular(), Vector2(size.x * 0.5 - w1 * 0.5, 170), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.INK_DARK)
	if phone and not ok:
		draw_press_a(size.y - 90, "while pointing at the target", 0.6 + 0.4 * sin(_t * 3.5))
	elif not phone:
		var l2 := "(No phone? Press Enter to use the keyboard.)"
		var w2 := UI.regular().get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(UI.regular(), Vector2(size.x * 0.5 - w2 * 0.5, size.y - 50), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.INK_SOFT)
