class_name OneEuroFilter
extends RefCounted
## One Euro filter (Casiez et al. 2012): heavy smoothing when the signal is
## slow (kills jitter), almost none when it moves fast (kills lag).

var min_cutoff: float
var beta: float
var d_cutoff: float

var _x := 0.0
var _dx := 0.0
var _has := false


func _init(p_min_cutoff := 1.0, p_beta := 0.05, p_d_cutoff := 1.0) -> void:
	min_cutoff = p_min_cutoff
	beta = p_beta
	d_cutoff = p_d_cutoff


static func _alpha(cutoff: float, dt: float) -> float:
	var tau := 1.0 / (TAU * cutoff)
	return 1.0 / (1.0 + tau / dt)


func reset(value: float) -> void:
	_x = value
	_dx = 0.0
	_has = true


func filter(value: float, dt: float) -> float:
	if not _has:
		reset(value)
		return value
	dt = clampf(dt, 0.001, 0.25)
	var dx := (value - _x) / dt
	_dx = lerpf(_dx, dx, _alpha(d_cutoff, dt))
	var cutoff := min_cutoff + beta * absf(_dx)
	_x = lerpf(_x, value, _alpha(cutoff, dt))
	return _x


func value() -> float:
	return _x
