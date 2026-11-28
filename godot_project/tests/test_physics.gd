extends SceneTree
# Rolls balls with various lines and reports pins knocked down.
var lane; var pins = []; var ball; var cases; var idx = -1; var t = 0.0
var x_at_pins = 0.0
func _init():
	cases = [
		["straight head-on 8m/s", 0.0, 0.0, 8.0, 0.0],
		["right pocket 8m/s", 0.06, 0.0, 8.0, 0.0],
		["hook -0.5 from x=0.30", 0.30, -0.5, 7.5, 0.0],
		["hook -1.0 from x=0.40", 0.40, -1.0, 7.5, 0.0],
		["hook +0.5 from x=-0.30", -0.30, 0.5, 7.5, 0.0],
		["slow 3.5m/s center", 0.0, 0.0, 3.5, 0.0],
		["edge (10 pin side)", 0.38, 0.0, 8.0, 0.0],
		["gutter", 0.0, 0.0, 8.0, 0.06],
	]
	lane = BowlingLane.new(); root.add_child(lane)
	for i in 10:
		var p = BowlingPin.new(i + 1, BowlingLane.PIN_SPOTS[i]); root.add_child(p); pins.append(p)
	ball = BowlingBall.new(); root.add_child(ball)
	physics_frame.connect(_step)
func _next():
	idx += 1
	if idx >= cases.size(): quit(); return
	for p in pins: p.reset_to_spot()
	var c = cases[idx]
	ball.spin = c[2]
	var dir = Basis(Vector3.UP, -c[4]) * Vector3.FORWARD
	ball.launch(Vector3(c[1], BowlingBall.RADIUS + 0.002, -0.2), dir * c[3])
	ball.spin = c[2]
	t = 0.0
func _step():
	if idx == -1:
		t += 1.0/120.0
		if t > 0.5: _next()
		return
	t += 1.0/120.0
	if ball.global_position.z > -18.0: x_at_pins = ball.global_position.x
	if t > 9.0:
		var down = 0
		for p in pins: if not p.is_standing(): down += 1
		print("%-24s pins down: %2d   ball x at pins=%.2f" % [cases[idx][0], down, x_at_pins])
		_next()
