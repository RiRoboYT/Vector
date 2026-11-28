class_name CricketPlay
extends Node3D
## Everything that happens once the ball is hit or passes the batter:
## fielders chase, catch, gather and throw; the keeper and bowler receive;
## the two batters decide on and run their runs; run-outs and boundaries.
## Emits `finished(kind, runs, detail)` once the ball is dead.
##   kind: "runs" | "four" | "six" | "caught" | "runout" | "dot"

signal finished(kind: String, runs: int, detail: String)
signal message(text: String)

const FIELD_SPEED := 7.2 # m/s top speed
const FIELD_ACCEL := 6.5
const RUN_SPEED := 6.3
const RUN_ACCEL := 5.0
const REACH := 1.1
const CATCH_REACH := 1.6
const THROW_SPEED := 27.0

var field: CricketField
var ball: CricketBall
var catch_skill := 0.85 # fielding team's catching
var risk := 0.6 # batters' safety margin in seconds (lower = riskier)

var fielders: Array[Mover] = [] # 9 outfielders
var keeper: Mover
var bowler: Mover
var runners: Array[Runner] = [] # [0] = at striker's end at the start
var active := false

var _chaser: Mover
var _holder: Mover
var _replan_t := 0.0
var _hold_t := 0.0
var _runs := 0
var _ended := false
var _receiver: Mover
var _throw_end := 0
var _dead_t := -1.0
var _boundary_kind := ""
var _wait_after := 0.0
var _fielded := false # a fielder has touched the ball since it was hit
var _keeper_collect := false
var _collect_t := 0.0


class Mover:
	var ch: Character
	var home := Vector3.ZERO
	var target := Vector3.ZERO
	var vel := Vector3.ZERO
	var max_speed := FIELD_SPEED
	var catching := 0.0 # pose amount
	var name := ""
	var frozen := false # animated by someone else (bowler's run-up)

	func pos() -> Vector3:
		return ch.global_position

	func step(dt: float, accel: float) -> void:
		if frozen:
			return
		var to := target - ch.global_position
		to.y = 0
		var dist := to.length()
		var want := Vector3.ZERO
		if dist > 0.05:
			# slow down to arrive
			var spd := minf(max_speed, sqrt(2.0 * accel * dist))
			want = to / dist * spd
		var dv := want - vel
		var max_dv := accel * dt
		if dv.length() > max_dv:
			dv = dv.normalized() * max_dv
		vel += dv
		ch.global_position += vel * dt
		var sp := vel.length()
		if sp > 0.3:
			var yaw := atan2(-vel.x, -vel.z)
			ch.rotation.y = lerp_angle(ch.rotation.y, yaw, 1.0 - exp(-dt * 10.0))
		ch.step_phase += sp * dt / 0.85 * PI
		ch.walk_amount = clampf(sp / 4.0, 0.0, 1.0)
		ch.lean = lerpf(ch.lean, clampf(sp / max_speed, 0.0, 1.0) * 0.25 + catching * 0.35, 1.0 - exp(-dt * 8.0))
		ch.crouch = lerpf(ch.crouch, catching * 0.18, 1.0 - exp(-dt * 8.0))

	func face(p: Vector3, dt: float) -> void:
		var d := p - ch.global_position
		if Vector2(d.x, d.z).length() > 0.1:
			ch.rotation.y = lerp_angle(ch.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-dt * 6.0))

	func hand_pos() -> Vector3:
		return ch.global_position + Vector3(0, 1.25, 0) + ch.global_basis * Vector3(0.25, 0, -0.35)


class Runner:
	var ch: Character
	var bat: CricketBat
	var name := ""
	var end := 0 # 0 = striker's end, 1 = bowler's end
	var running := false
	var target_end := 0
	var vel := 0.0
	var lane_x := -0.9

	func pos() -> Vector3:
		return ch.global_position

	## Safe ("in the ground") if behind the popping crease at the end it's at/near.
	func grounded_at(e: int) -> bool:
		var z := ch.global_position.z
		if e == 0:
			return z > -CricketField.CREASE + 0.15
		return z < CricketField.BOWL_Z + CricketField.CREASE - 0.15


func all_movers() -> Array[Mover]:
	var out: Array[Mover] = fielders.duplicate()
	if keeper:
		out.append(keeper)
	if bowler:
		out.append(bowler)
	return out


func _ready() -> void:
	ball.hit_stumps.connect(_on_hit_stumps)
	ball.boundary.connect(_on_boundary)


# ----------------------------------------------------------------- setup

func make_mover(name: String, shirt: Color, home: Vector3, shadows := true) -> Mover:
	var m := Mover.new()
	m.ch = Character.new()
	m.ch.shirt = shirt
	m.ch.pants = Color(0.95, 0.95, 0.95)
	m.ch.outfit = "cricket"
	m.ch.hand_targets = true
	m.ch.shadows = shadows
	add_child(m.ch)
	m.ch.global_position = home
	m.home = home
	m.target = home
	m.name = name
	return m


func make_runner(name: String, shirt: Color, end: int) -> Runner:
	var r := Runner.new()
	r.ch = Character.new()
	r.ch.shirt = shirt
	r.ch.pants = Color(0.95, 0.95, 0.95)
	r.ch.outfit = "cricket"
	r.ch.hand_targets = true
	add_child(r.ch)
	r.bat = CricketBat.new()
	r.bat.enabled = false
	r.bat.top_level = true
	add_child(r.bat)
	r.name = name
	r.end = end
	return r


## Put everyone back for the next ball.
func reset_positions(fast_bowler: bool, striker_rig: BatterRig) -> void:
	active = false
	_ended = false
	_holder = null
	_chaser = null
	_receiver = null
	_runs = 0
	_dead_t = -1.0
	_boundary_kind = ""
	for f in fielders:
		f.target = f.home
		f.catching = 0.0
	# keepers stand well back for pace, right up to the stumps for spin
	keeper.home = Vector3(0.3, 0, 9.0 if fast_bowler else 0.9)
	keeper.target = keeper.home
	keeper.catching = 0.4
	bowler.home = Vector3(0.6, 0, CricketField.BOWL_Z + 4.0)
	for r in runners:
		r.running = false
		r.vel = 0.0
	# striker is drawn by the rig while facing; hide the striker's runner
	runners[0].ch.visible = false
	runners[0].bat.visible = false
	runners[1].ch.visible = true
	runners[1].bat.visible = true
	var lefty := striker_rig.left_handed if striker_rig else false
	# non-striker backs up on the side away from the bowler's arm, facing the batter
	runners[1].ch.global_position = Vector3(-1.3, 0, CricketField.BOWL_Z + 1.0)
	runners[1].ch.rotation.y = PI
	runners[1].lane_x = -0.9
	runners[0].lane_x = 0.9


## Teleport the fielders home (between overs / start).
func snap_home() -> void:
	for f in all_movers():
		f.ch.global_position = f.home
		f.vel = Vector3.ZERO
		f.target = f.home


# ------------------------------------------------------------ the play

## Ball has been hit (or got past the bat): start fielding and running.
func start(hit: bool, striker_rig: BatterRig) -> void:
	active = true
	_ended = false
	_runs = 0
	_fielded = false
	_keeper_collect = false
	_replan_t = 0.0
	if hit:
		# striker drops the stance and becomes a runner
		var r0 := runners[0]
		r0.ch.visible = true
		r0.bat.visible = true
		r0.ch.global_position = striker_rig.body_pos()
		striker_rig.visible = false
		_plan_chase()
		_decide_runs()
	else:
		_chaser = keeper


func _plan_chase() -> void:
	var pts := ball.predict(9.0, 0.05)
	var best_t := 1e9
	var best: Mover = null
	var best_p := ball.global_position
	for f in all_movers():
		for i in pts.size():
			var t := (i + 1) * 0.05
			var p := pts[i]
			if CricketField.dist_from_center(p) > CricketField.BOUNDARY - 0.5:
				break
			var reach := CATCH_REACH if p.y > 0.3 else REACH
			if p.y > 2.8:
				continue
			var d := Vector2(p.x - f.pos().x, p.z - f.pos().z).length() - reach
			if d <= _run_dist(maxf(0.0, t - 0.3), f.max_speed):
				if t < best_t:
					best_t = t
					best = f
					best_p = p
				break
	if best == null:
		# nobody gets there before the rope: nearest chases anyway
		var last := pts[pts.size() - 1] if pts.size() > 0 else ball.global_position
		for f in fielders:
			if best == null or f.pos().distance_to(last) < best.pos().distance_to(last):
				best = f
		best_p = last
		best_t = 9.0
	_chaser = best
	_chaser.target = Vector3(best_p.x, 0, best_p.z)
	set_meta("eta", best_t)


static func _run_dist(t: float, vmax: float) -> float:
	var t_acc := vmax / FIELD_ACCEL
	if t < t_acc:
		return 0.5 * FIELD_ACCEL * t * t
	return 0.5 * FIELD_ACCEL * t_acc * t_acc + vmax * (t - t_acc)


## How many runs the batters will go for (re-checked at each crease).
func _decide_runs() -> void:
	var eta: float = get_meta("eta", 9.0)
	var pts := ball.predict(9.0, 0.1)
	var to_rope := false
	if eta >= 9.0: # nobody cuts it off before the rope
		for p in pts:
			if CricketField.dist_from_center(p) >= CricketField.BOUNDARY - 0.5:
				to_rope = true
				break
	var throw_t := 0.0
	if _chaser:
		var danger := Vector3(0, 0, CricketField.BOWL_Z) if _chaser.pos().z < -10.0 else Vector3.ZERO
		throw_t = _chaser.target.distance_to(danger) / THROW_SPEED + 0.45
	var ball_back := eta + throw_t
	if to_rope:
		ball_back = 99.0
	var first := 3.4
	var each := 3.7
	var k := 0
	while k < 3 and first + k * each + risk < ball_back:
		k += 1
	set_meta("plan", k)
	if OS.has_environment("VS_DEBUG"):
		print("[play] chaser=%s eta=%.2f ball_back=%.2f to_rope=%s plan=%d ball v=%s" % [_chaser.name if _chaser else "-", eta, ball_back, to_rope, k, ball.vel])
	if k > 0:
		for r in runners:
			_go(r)


func _go(r: Runner) -> void:
	r.running = true
	r.target_end = 1 - r.end


func _process(delta: float) -> void:
	if fielders.is_empty():
		return
	for f in all_movers():
		if f != _holder:
			f.step(delta, FIELD_ACCEL)
	_update_hands()
	for r in runners:
		_update_runner(r, delta)
	if not active:
		return
	if _dead_t >= 0.0:
		_dead_t += delta
		if _dead_t > _wait_after and not _ended:
			_end_play()
		return
	_update_play(delta)


func _update_play(delta: float) -> void:
	if _keeper_collect:
		_update_keeper_collect(delta)
		return
	var bp := ball.global_position
	# keeper / bowler stand at the stumps when a throw is coming
	if _holder == null:
		_replan_t -= delta
		if _chaser and _replan_t <= 0.0 and ball.mode == CricketBall.Mode.FLYING:
			_replan_t = 0.25
			if _chaser != keeper:
				_plan_chase()
		if _chaser:
			var hp := _chaser.hand_pos()
			var hor := Vector2(bp.x - _chaser.pos().x, bp.z - _chaser.pos().z).length()
			var near := hor < (CATCH_REACH if bp.y > 0.4 else REACH) and bp.y < 2.8
			_chaser.catching = clampf(1.0 - hor / 4.0, 0.0, 1.0)
			if near and ball.mode == CricketBall.Mode.FLYING:
				_try_take(_chaser)
		# receivers take throws
		for rcv: Mover in [keeper, bowler]:
			if rcv == _chaser or _receiver != rcv:
				continue
			if ball.mode == CricketBall.Mode.FLYING and bp.distance_to(rcv.hand_pos()) < 1.3:
				_receive(rcv)
		if ball.mode == CricketBall.Mode.FLYING and ball.vel.length() < 0.05 and _chaser == null:
			_plan_chase()
	else:
		_hold_t += delta
		ball.hold(_holder.hand_pos())
		_holder.face(Vector3(0, 0, CricketField.BOWL_Z * _throw_end), delta)
		if _hold_t > 0.35:
			_throw_from(_holder)
	# keeper / bowler go to the stumps to receive (unless they are chasing)
	if _holder != keeper and _chaser != keeper:
		keeper.target = Vector3(0.0, 0, 0.45)
	if _holder != bowler and _chaser != bowler and not bowler.frozen:
		bowler.target = Vector3(0.4, 0, CricketField.BOWL_Z - 0.45)


func _try_take(f: Mover) -> void:
	var airborne := ball.off_bat and not ball.grounded_after_bat
	if airborne:
		# catch: harder when diving (arrived late / at full stretch)
		var stretch := clampf(Vector2(ball.global_position.x - f.pos().x, ball.global_position.z - f.pos().z).length() / CATCH_REACH, 0.0, 1.0)
		var pace := clampf(ball.vel.length() / 35.0, 0.0, 1.0)
		var p := catch_skill * (1.0 - 0.35 * stretch) * (1.0 - 0.25 * pace)
		if randf() < p:
			f.catching = 1.0
			ball.hold(f.hand_pos())
			_holder = null
			for r in runners:
				r.running = false
			message.emit("CAUGHT!")
			_finish_after("caught", 0, "caught by " + f.name, 1.6)
			return
		_fielded = true
		# dropped: ball pops off the hands
		ball.set_velocity(ball.vel * Vector3(0.3, 0.2, 0.3) + Vector3(randf_range(-2, 2), 1.5, randf_range(-2, 2)))
		ball.grounded_after_bat = true
		message.emit("Dropped!")
		_replan_t = 0.4
		return
	if f == bowler and ball.vel.length() > 16.0 and randf() < 0.7:
		# off-balance in the follow-through: a firm hit gets past the bowler
		_fielded = true
		ball.set_velocity(ball.vel * 0.8 + Vector3(randf_range(-2, 2), 0, 0))
		ball.grounded_after_bat = true
		_replan_t = 0.3
		bowler.target = bowler.pos()
		return
	if ball.vel.length() > 26.0 and randf() < 0.5:
		# too hot to hold: fumble
		_fielded = true
		ball.set_velocity(ball.vel * 0.35)
		ball.grounded_after_bat = true
		_replan_t = 0.3
		return
	_holder = f
	_fielded = true
	_hold_t = 0.0
	ball.hold(f.hand_pos())
	f.vel *= 0.3
	_choose_throw_end()


func _choose_throw_end() -> void:
	# throw where a runner is in most danger; otherwise to the keeper
	_throw_end = 0
	var best := 99.0
	for r in runners:
		if r.running:
			var end_z := 0.0 if r.target_end == 0 else CricketField.BOWL_Z
			var left := absf(r.pos().z - end_z) / RUN_SPEED
			if left < best:
				best = left
				_throw_end = r.target_end


func _throw_from(f: Mover) -> void:
	var end_z := 0.0 if _throw_end == 0 else CricketField.BOWL_Z
	var rcv := keeper if _throw_end == 0 else bowler
	var from := f.hand_pos()
	var dist := Vector2(from.x, from.z - end_z).length()
	var runner_out := false
	for r in runners:
		if r.running and r.target_end == _throw_end and not r.grounded_at(_throw_end):
			runner_out = true
	var target := rcv.hand_pos()
	if runner_out and dist < 22.0:
		# have a shy at the stumps
		target = Vector3(randf_range(-0.25, 0.25), 0.35, end_z)
	var speed := clampf(dist * 1.4, 14.0, THROW_SPEED)
	var v := _solve_throw(from, target, speed)
	_holder = null
	_receiver = rcv
	ball.global_position = from
	ball.set_velocity(v)
	ball.off_bat = true
	ball.grounded_after_bat = true # a throw can't be "caught out"
	_chaser = null


static func _solve_throw(from: Vector3, target: Vector3, speed: float) -> Vector3:
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	var dist := flat.length()
	var dir := flat / maxf(dist, 0.001)
	var lo := deg_to_rad(-10.0)
	var hi := deg_to_rad(45.0)
	var v := dir * speed
	for k in 24:
		var mid := (lo + hi) * 0.5
		v = (dir * cos(mid) + Vector3.UP * sin(mid)) * speed
		var p := from
		var vv := v
		var h := 1.0 / 240.0
		var y_at := -100.0
		for i in 1200:
			vv += (CricketBall.G - vv * vv.length() * CricketBall.DRAG_K) * h
			p += vv * h
			if Vector2(p.x - from.x, p.z - from.z).length() >= dist:
				y_at = p.y
				break
			if p.y < 0.0:
				break
		if y_at < target.y:
			lo = mid
		else:
			hi = mid
	return v


func _receive(rcv: Mover) -> void:
	ball.hold(rcv.hand_pos())
	rcv.catching = 0.8
	var end := 0 if rcv == keeper else 1
	for r in runners:
		if r.running and r.target_end == end and not r.grounded_at(end):
			var st := field.striker_stumps if end == 0 else field.bowler_stumps
			st.break_wicket(st.global_position + Vector3(0, 0.6, 0), Vector3(0, 0, 4.0 if end == 0 else -4.0), 0.5)
			_run_out(r)
			return
	for r in runners:
		r.running = false
	_finish_after("runs" if _runs > 0 else "dot", _runs, "", 0.9)


func _on_hit_stumps(st: Stumps, _p: Vector3, _v: Vector3) -> void:
	# a straight hit onto the non-striker's stumps is only a run out if a
	# fielder (or the bowler) touched the ball first
	if not active or not _fielded:
		return
	var end := 0 if st == field.striker_stumps else 1
	for r in runners:
		if r.running and r.target_end == end and not r.grounded_at(end):
			_run_out(r)
			return


func _run_out(r: Runner) -> void:
	if OS.has_environment("VS_DEBUG"):
		print("[play] run out %s at z=%.2f target_end=%d running=%s holder=%s receiver=%s" % [r.name, r.pos().z, r.target_end, r.running, _holder.name if _holder else "-", _receiver.name if _receiver else "-"])
	for q in runners:
		q.running = false
	message.emit("RUN OUT!")
	set_meta("out_runner", r.name)
	_finish_after("runout", _runs, r.name, 1.8)


func _on_boundary(six: bool) -> void:
	if not active or _ended:
		return
	for r in runners:
		r.running = false
	message.emit("SIX!" if six else "FOUR!")
	_finish_after("six" if six else "four", 6 if six else 4, "", 2.2)


func _finish_after(kind: String, runs: int, detail: String, wait: float) -> void:
	if _dead_t >= 0.0:
		return
	set_meta("result", [kind, runs, detail])
	_dead_t = 0.0
	_wait_after = wait


func _end_play() -> void:
	_ended = true
	active = false
	var res: Array = get_meta("result", ["dot", 0, ""])
	finished.emit(res[0], res[1], res[2])


## Called by the game when the ball beats the bat: the keeper takes it.
func keeper_takes() -> void:
	active = true
	_keeper_collect = true
	_collect_t = 0.0
	_chaser = null


func _update_keeper_collect(delta: float) -> void:
	_collect_t += delta
	var bp := ball.global_position
	# move across to the line of the ball
	var pts := ball.predict(1.5, 0.02)
	for q in pts:
		if q.z >= keeper.pos().z - 0.3:
			keeper.target = Vector3(q.x, 0, keeper.home.z)
			break
	keeper.catching = 1.0
	if ball.mode == CricketBall.Mode.HELD or bp.distance_to(keeper.hand_pos()) < 1.4 or bp.z > keeper.pos().z + 0.5 or _collect_t > 3.0:
		_keeper_collect = false
		ball.hold(keeper.hand_pos())
		_finish_after("dot", 0, "", 0.7)


# ------------------------------------------------------------ runners

func _update_runner(r: Runner, dt: float) -> void:
	var c := r.ch
	if r.running:
		var end_z := -0.5 if r.target_end == 0 else CricketField.BOWL_Z + 0.5
		var tz := end_z
		var dz := tz - c.global_position.z
		var dir := signf(dz)
		var brake_dist := r.vel * r.vel / (2.0 * RUN_ACCEL * 1.4)
		if absf(dz) <= brake_dist + 0.3:
			r.vel = maxf(0.0, r.vel - RUN_ACCEL * 1.4 * dt)
		else:
			r.vel = minf(RUN_SPEED, r.vel + RUN_ACCEL * dt)
		c.global_position.z += dir * r.vel * dt
		c.global_position.x = lerpf(c.global_position.x, r.lane_x, 1.0 - exp(-dt * 3.0))
		c.rotation.y = 0.0 if dir < 0.0 else PI
		c.step_phase += r.vel * dt / 0.9 * PI
		c.walk_amount = clampf(r.vel / 3.0, 0.0, 1.0)
		c.lean = 0.2 * clampf(r.vel / RUN_SPEED, 0.0, 1.0)
		if absf(dz) < 0.45 or (r.vel < 0.2 and absf(dz) < 1.0):
			# made it to the other end
			r.running = false
			r.end = r.target_end
			r.vel = 0.0
			if r == runners[0] or not runners[0].running:
				_completed_run()
	else:
		c.walk_amount = lerpf(c.walk_amount, 0.0, 1.0 - exp(-dt * 6.0))
		c.lean = lerpf(c.lean, 0.05, 1.0 - exp(-dt * 4.0))
	# carry the bat in the right hand, blade down and back
	var hand := c.global_position + c.global_basis * Vector3(0.32, 0.85, 0.05)
	c.hand_r_world = hand
	c.hand_l_world = c.global_position + c.global_basis * Vector3(-0.3, 0.8, 0.0)
	r.bat.global_transform = Transform3D(c.global_basis * Basis(Vector3.RIGHT, -0.5), hand)


func _completed_run() -> void:
	if not active or _dead_t >= 0.0:
		return
	_runs += 1
	message.emit(str(_runs))
	var plan: int = get_meta("plan", 0)
	if _runs < plan:
		# re-check: still safe to turn for another?
		var safe := _holder == null and _receiver == null
		if safe:
			for r in runners:
				_go(r)


func _update_hands() -> void:
	for f in all_movers():
		var c := f.ch
		var ready := c.global_position + c.global_basis * Vector3(0.0, 0.95 + f.catching * 0.2, -0.35)
		c.hand_r_world = ready + c.global_basis * Vector3(0.15, 0, 0)
		c.hand_l_world = ready + c.global_basis * Vector3(-0.15, 0, 0)
		c.head_turn = 0.0
