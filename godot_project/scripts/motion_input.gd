class_name MotionInput
extends Node
## Turns raw phone orientation into calibrated yaw / pitch / roll.
##
## Phone sends W3C DeviceOrientation angles (alpha, beta, gamma). These are
## converted to a rotation matrix (Z-X'-Y'' intrinsic), then to gravity-
## referenced pointing angles. Calibration stores the angles of the user's
## neutral grip and everything is reported relative to that, so drift-free
## pitch/roll come from gravity and only yaw can drift (fixed by Recenter).
##
## Two grips are supported and chosen automatically when calibrating:
##   * "Remote":  phone flat-ish, screen up, top edge points at the laptop.
##   * "Camera":  phone upright, back camera points at the laptop.

signal calibrated_changed(is_calibrated: bool)
## Raw gyro sample in deg/s around the phone's own axes:
## x = across the screen (arm swing), y = along the phone (wrist twist).
signal gyro_sample(t_ms: float, rate_x: float, rate_y: float, rate_z: float)

enum Grip { REMOTE, CAMERA }

## Filtered, calibrated angles in radians. yaw > 0 = pointing right,
## pitch > 0 = pointing up, roll > 0 = rolled clockwise (right edge down).
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var swing := 0.0 # 0..1 intensity from linear acceleration

var is_calibrated := false
var grip := Grip.REMOTE
var has_data := false

# raw values for the debug panel
var raw_orientation := Vector3.ZERO # alpha, beta, gamma (degrees)
var raw_accel := Vector3.ZERO # m/s^2, gravity removed
var raw_gyro := Vector3.ZERO # deg/s around device x, y, z
var raw_yaw := 0.0
var raw_pitch := 0.0
var raw_roll := 0.0
var packets_per_sec := 0.0
var latency_ms := -1.0 # phone -> game estimate (half round-trip)

var _cal := Vector3.ZERO # yaw0, pitch0, roll0
var _f_yaw := OneEuroFilter.new(2.5, 4.0)
var _f_pitch := OneEuroFilter.new(2.5, 4.0)
var _f_roll := OneEuroFilter.new(2.5, 4.0)
var _last_t := -1.0
var _pkt_count := 0
var _pkt_window_ms := 0


func handle_sensor(msg: Dictionary) -> void:
	var o = msg.get("orientation")
	if not (o is Dictionary) or o.get("alpha") == null or o.get("beta") == null or o.get("gamma") == null:
		return
	raw_orientation = Vector3(float(o.alpha), float(o.beta), float(o.gamma))
	var a = msg.get("accel")
	if a is Dictionary:
		raw_accel = Vector3(float(a.get("x", 0.0)), float(a.get("y", 0.0)), float(a.get("z", 0.0)))
	var g = msg.get("gyro")
	if g is Dictionary and g.get("beta") != null:
		raw_gyro = Vector3(float(g.get("beta", 0.0)), float(g.get("gamma", 0.0)), float(g.get("alpha", 0.0)))
	if msg.has("rtt"):
		latency_ms = float(msg.rtt) * 0.5

	var t := float(msg.get("t", Time.get_ticks_msec()))
	var dt := 1.0 / 60.0 if _last_t < 0.0 else (t - _last_t) / 1000.0
	_last_t = t
	_pkt_count += 1

	_compute_raw()
	if not has_data:
		has_data = true
	_apply(dt)
	if g is Dictionary:
		gyro_sample.emit(t, raw_gyro.x, raw_gyro.y, raw_gyro.z)


## Calibrate everything to the current grip (call while user holds neutral).
func calibrate() -> void:
	if not has_data:
		return
	# pick the grip from how the phone is held right now
	var flat_pitch := _angles_for(Grip.REMOTE).y
	grip = Grip.CAMERA if absf(flat_pitch) > deg_to_rad(55.0) else Grip.REMOTE
	_compute_raw()
	_cal = Vector3(raw_yaw, raw_pitch, raw_roll)
	is_calibrated = true
	_reset_filters()
	calibrated_changed.emit(true)


## Re-center left/right only (fixes slow gyro drift).
func recenter() -> void:
	if not has_data:
		return
	if not is_calibrated:
		calibrate()
		return
	_cal.x = raw_yaw
	_reset_filters()


## Mouse / keyboard fallback when no phone is connected.
func feed_manual(p_yaw: float, p_pitch: float, dt: float) -> void:
	yaw = _f_yaw.filter(p_yaw, dt)
	pitch = _f_pitch.filter(p_pitch, dt)
	roll = _f_roll.filter(0.0, dt)
	swing = maxf(0.0, swing - dt * 2.0)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _pkt_window_ms >= 1000:
		packets_per_sec = _pkt_count * 1000.0 / maxf(1.0, float(now - _pkt_window_ms))
		_pkt_count = 0
		_pkt_window_ms = now
	swing = maxf(0.0, swing - delta * 1.6)


func reset_connection() -> void:
	has_data = false
	_last_t = -1.0
	latency_ms = -1.0


func _apply(dt: float) -> void:
	var y := wrapf(raw_yaw - _cal.x, -PI, PI)
	var p := raw_pitch - _cal.y
	var r := wrapf(raw_roll - _cal.z, -PI, PI)
	yaw = _f_yaw.filter(y, dt)
	pitch = _f_pitch.filter(p, dt)
	roll = _f_roll.filter(r, dt)
	var mag := raw_accel.length()
	swing = maxf(swing, clampf((mag - 4.0) / 16.0, 0.0, 1.0))


func _reset_filters() -> void:
	_f_yaw.reset(wrapf(raw_yaw - _cal.x, -PI, PI))
	_f_pitch.reset(raw_pitch - _cal.y)
	_f_roll.reset(wrapf(raw_roll - _cal.z, -PI, PI))


func _compute_raw() -> void:
	var v := _angles_for(grip)
	raw_yaw = v.x
	raw_pitch = v.y
	raw_roll = v.z


## Compass direction (radians, East-North-Up) the player faced when calibrating:
## that is "towards the TV".
func facing_yaw() -> float:
	return _cal.x


## Full phone orientation as a rotation matrix (device -> East-North-Up world).
func device_basis() -> Basis:
	var al := deg_to_rad(raw_orientation.x)
	var be := deg_to_rad(raw_orientation.y)
	var ga := deg_to_rad(raw_orientation.z)
	return Basis(Vector3(0, 0, 1), al) * Basis(Vector3(1, 0, 0), be) * Basis(Vector3(0, 1, 0), ga)


## Returns (yaw, pitch, roll) in radians for a grip, in an East-North-Up world.
func _angles_for(g: Grip) -> Vector3:
	var al := deg_to_rad(raw_orientation.x)
	var be := deg_to_rad(raw_orientation.y)
	var ga := deg_to_rad(raw_orientation.z)
	var rot := Basis(Vector3(0, 0, 1), al) * Basis(Vector3(1, 0, 0), be) * Basis(Vector3(0, 1, 0), ga)
	var fwd: Vector3 = rot * (Vector3(0, 1, 0) if g == Grip.REMOTE else Vector3(0, 0, -1))
	var right: Vector3 = rot * Vector3(1, 0, 0)
	var y := atan2(fwd.x, fwd.y)
	var p := asin(clampf(fwd.z, -1.0, 1.0))
	var h := Vector3(cos(y), -sin(y), 0.0)
	var up := h.cross(fwd).normalized()
	var r := atan2(-right.dot(up), right.dot(h))
	return Vector3(y, p, r)
