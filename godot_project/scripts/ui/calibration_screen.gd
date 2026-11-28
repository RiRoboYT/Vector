class_name CalibrationScreen
extends Screen
## Compulsory calibration for one phone: hold it like a remote, point at the
## target, press A on THAT phone. Shown when a phone connects and for every
## phone before each game. With no phone at all, Enter continues (keyboard).

var roster: Players
var phone: Players.Phone # null = keyboard mode
var _done_t := -1.0


func _init() -> void:
	super()
	wants_pointer = false
	phone_hint = "Point at the target on screen and press A"
	process_priority = -50


func _ready() -> void:
	roster.phone_button.connect(_on_button)


func _on_button(pid: String, id: String, down: bool) -> void:
	if _done_t >= 0.0 or not down or id != Pad.A or phone == null or pid != phone.pid:
		return
	if not phone.motion.has_data:
		return
	phone.motion.calibrate()
	phone.calibrated = true
	Sfx.click(1.0, 1.4)
	roster.send_to_phone(phone.pid, {"type": "haptic", "p": "double"})
	_done_t = _t


func _process(delta: float) -> void:
	super(delta)
	if _done_t >= 0.0:
		if _t - _done_t > 0.6:
			done.emit("ok")
		return
	if phone == null:
		if Pad.raw_just_pressed(Pad.A) and Pad.last_a_from_keyboard:
			_done_t = _t
		elif roster.any_connected():
			done.emit("phone") # a phone arrived: calibrate that instead
	elif not phone.connected():
		done.emit("gone")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.97))
	var c := size * 0.5 + Vector2(0, -10)
	var f := UI.bold()
	var reg := UI.regular()
	var ok := _done_t >= 0.0
	var who := "" if phone == null else roster.label_for_phone(phone.pid)
	var col := UI.BLUE
	if phone != null and not roster.players_of(phone.pid).is_empty():
		col = roster.players_of(phone.pid)[0].color
	var pulse := 1.0 + 0.06 * sin(_t * 4.0)
	for i in 4:
		draw_circle(c, (120 - i * 30) * pulse, col if i % 2 == 0 else UI.WHITE)
	draw_circle(c, 18, Color("2fbf5b") if ok else Color("ffb020"))
	var title := "Calibrated!" if ok else ("Calibration" + ("  ·  " + who if who != "" else ""))
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
	draw_string(f, Vector2(size.x * 0.5 - tw * 0.5, 100), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, col.darkened(0.1))
	var line := "Hold your phone like a remote, top edge towards the screen." if phone != null else "No phone connected — scan the QR code, or press Enter to use the keyboard."
	var w1 := reg.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(reg, Vector2(size.x * 0.5 - w1 * 0.5, 156), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK_DARK)
	if phone != null and not ok:
		draw_press_a(size.y - 90, "on %s's phone while pointing at the target" % (who.get_slice(",", 0) if who != "" else "your"), 0.6 + 0.4 * sin(_t * 3.5))
