class_name LanePreview
extends SubViewport
## Live 3D attract loop for menus: the real alley, a ball hooking into the
## pocket and a physics strike, with a camera that follows the ball and then
## settles on the pins. Restarts every few seconds.

const LOOP := 6.5

var _ball: BowlingBall
var _pins: Array[BowlingPin] = []
var _cam: Camera3D
var _t := 0.0
var _cam_pos := Vector3(0.4, 0.55, 2.0)
var _cam_look := Vector3(0, 0.2, -10)


func _init(px := Vector2i(960, 540)) -> void:
	size = px
	own_world_3d = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	add_child(BowlingLane.new())
	for i in 10:
		var p := BowlingPin.new(i + 1, BowlingLane.PIN_SPOTS[i])
		p.contact_monitor = false # no sounds from the menu preview
		add_child(p)
		_pins.append(p)
	_ball = BowlingBall.new()
	add_child(_ball)
	_cam = Camera3D.new()
	_cam.fov = 48.0
	add_child(_cam)
	_cam.current = true
	_restart()


func _restart() -> void:
	_t = 0.0
	for p in _pins:
		p.reset_to_spot()
	_ball.launch(Vector3(0.3, BowlingBall.RADIUS + 0.004, -0.4), Vector3(0, 0, -7.6))
	_ball.spin = -0.5
	_cam_pos = Vector3(0.75, 0.5, 1.6)
	_cam_look = Vector3(0.1, 0.25, -10)


func _process(delta: float) -> void:
	_t += delta
	if _t > LOOP:
		_restart()
	var b := _ball.global_position
	var tp: Vector3
	var tl: Vector3
	if b.z > -12.5 and _t < 3.0:
		tp = Vector3(b.x * 0.6 + 0.35, 0.42, b.z + 1.5)
		tl = Vector3(b.x * 0.5, 0.18, b.z - 6.0)
	else:
		# low three-quarter view of the pin deck
		tp = Vector3(0.28, 0.75, -15.6)
		tl = Vector3(-0.05, 0.15, -18.7)
	var f := 1.0 - exp(-delta * 3.5)
	_cam_pos = _cam_pos.lerp(tp, f)
	_cam_look = _cam_look.lerp(tl, f)
	_cam.look_at_from_position(_cam_pos, _cam_look)
