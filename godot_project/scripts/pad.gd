class_name Pad
extends Node
## One place for "controller" input: phone buttons (A, B, Left, Right) and
## the on-screen pointer, with keyboard/mouse as a fallback.
##   Keyboard: Enter/Z = A, Space = B, Arrow keys = Left/Right, mouse = pointer.

const A := "A"
const B := "B"
const LEFT := "L"
const RIGHT := "R"

static var pointer := Vector2(640, 360)
static var pointer_visible := true
static var phone_pointer := false # true when the pointer comes from the phone
## While true (calibration overlay) normal queries see no input.
static var blocked := false
static var last_a_from_keyboard := false

static var _down := {}
static var _pressed_pending := {}
static var _released_pending := {}
static var _pressed := {}
static var _released := {}
static var _key_down := {}
static var _mouse_ms := -100000

## Motion of the phone currently in control (set by Players).
static var instance_motion: MotionInput


func _init() -> void:
	process_priority = -100 # run before every screen


## Phone button event (from the WebSocket).
static func phone_button(id: String, down: bool) -> void:
	if id == A and down:
		last_a_from_keyboard = false
	_set_state(id, down)


static func release_all() -> void:
	for id in _down.keys():
		if _down[id]:
			_set_state(id, false)


static func _set_state(id: String, down: bool) -> void:
	var was: bool = _down.get(id, false)
	if down == was:
		return
	_down[id] = down
	if down:
		_pressed_pending[id] = true
	else:
		_released_pending[id] = true


static func is_down(id: String) -> bool:
	return not blocked and _down.get(id, false)


static func just_pressed(id: String) -> bool:
	return not blocked and _pressed.get(id, false)


static func just_released(id: String) -> bool:
	return not blocked and _released.get(id, false)


static func raw_just_pressed(id: String) -> bool:
	return _pressed.get(id, false)


func _process(_delta: float) -> void:
	if _pressed_pending.has(A) and OS.has_environment("VS_DEBUG"):
		print("[pad] A pressed at pointer ", pointer, " phone_pointer=", phone_pointer, " blocked=", blocked)
	_pressed = _pressed_pending
	_released = _released_pending
	_pressed_pending = {}
	_released_pending = {}

	var vp := get_viewport()
	var vs := vp.get_visible_rect().size
	var motion := instance_motion
	if Time.get_ticks_msec() - _mouse_ms < 1500 or motion == null or not motion.has_data or not motion.is_calibrated:
		pointer = vp.get_mouse_position()
		phone_pointer = false
	else:
		# point straight at the screen = centre; about +-24 deg spans the width
		var px := vs.x * 0.5 + tan(clampf(motion.yaw, -1.2, 1.2)) / tan(deg_to_rad(24.0)) * vs.x * 0.5
		var py := vs.y * 0.5 - tan(clampf(motion.pitch, -1.2, 1.2)) / tan(deg_to_rad(16.0)) * vs.y * 0.5
		pointer = Vector2(clampf(px, 0, vs.x), clampf(py, 0, vs.y))
		phone_pointer = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_ms = Time.get_ticks_msec()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_ms = Time.get_ticks_msec()
		if event.pressed:
			last_a_from_keyboard = true
		_set_state(A, event.pressed)
	elif event is InputEventKey and not event.echo:
		var id := ""
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_Z:
				id = A
			KEY_SPACE:
				id = B
			KEY_LEFT:
				id = LEFT
			KEY_RIGHT:
				id = RIGHT
		if id != "":
			if id == A and event.pressed:
				last_a_from_keyboard = true
			_set_state(id, event.pressed)
