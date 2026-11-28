class_name Character
extends Node3D
## Original, polished cartoon person built from primitives.
##  - Look: skin tone, hairstyle and hair colour come from `look_seed`
##    (same seed = same person in every sport; -1 = random).
##  - Outfit per sport: "casual", "bowling", "cricket", "tennis", "umpire".
##  - Face: big eyes that blink, eyebrows, nose, cheeks and a mouth that
##    follows `mood` (1 happy, 0 neutral, -1 sad).
##  - Reactions: set `reaction` to "cheer" or "sad" for a short celebration
##    or a disappointed slump (overrides the arms).
## The arms use two-bone IK, driven by the game (bowling swing, hand targets
## for bats / rackets, or the remote aim).

const UPPER := 0.30
const FORE := 0.29
const SKIN := Color(1.0, 0.84, 0.7)
const SHIRT := Color(0.16, 0.62, 0.9)
const PANTS := Color(0.22, 0.25, 0.36)
const SKINS := [Color(1.0, 0.86, 0.73), Color(0.98, 0.8, 0.66), Color(0.9, 0.7, 0.54), Color(0.76, 0.55, 0.4), Color(0.58, 0.4, 0.28), Color(0.44, 0.3, 0.21)]
const HAIRS := [Color(0.1, 0.08, 0.07), Color(0.2, 0.13, 0.08), Color(0.36, 0.22, 0.12), Color(0.55, 0.3, 0.15), Color(0.82, 0.64, 0.36), Color(0.62, 0.6, 0.58)]

## Set these before adding to the tree.
var shirt := SHIRT
var pants := PANTS
var outfit := "casual"
var look_seed := -1
## Cast shadows (turn off for distant figures to save GPU).
var shadows := true

var aim_yaw := 0.0
var aim_pitch := 0.0
var aim_roll := 0.0
var swing := 0.0

## Bowling mode: arm swings in the vertical plane, no remote, no head follow.
var bowling := false
var swing_angle := 0.0 # radians: 0 = arm hanging, >0 forward, <0 back
var hand_world := Vector3.ZERO
## Body animation, set by the game each frame.
var step_phase := 0.0 # advances while walking (radians)
var walk_amount := 0.0 # 0 = standing, 1 = full stride
var lean := 0.0 # forward lean of the upper body (radians)
var crouch := 0.0 # metres the body drops (knee bend)
var slide := 0.0 # 0..1 release pose: front leg slides, back leg kicks back
var balance_arm := 0.0 # 0..1 left arm swings out for balance
## Two-handed holding (cricket bat, racket, catching): hands reach these points.
var hand_targets := false
var hand_r_world := Vector3.ZERO
var hand_l_world := Vector3.ZERO
var head_turn := 0.0 # head yaw (radians), e.g. to watch the ball
var head_tilt := 0.0
## Expression and reactions.
var mood := 0.0 # -1 sad .. 1 happy
var reaction := "" # "", "cheer", "sad"
var _react_left := -1.0

var tip_world := Vector3.ZERO
var tip_forward := Vector3.FORWARD

var skin := SKIN
var hair_color := HAIRS[1]
var hair_style := 0

var _shoulder_r := Vector3(0.27, 1.38, 0.0)
var _shoulder_l := Vector3(-0.27, 1.38, 0.0)
var _upper_r: MeshInstance3D
var _fore_r: MeshInstance3D
var _elbow_r: MeshInstance3D
var _hand_r: Node3D
var _remote: Node3D
var _tip_mat: StandardMaterial3D
var _head: Node3D
var _body: Node3D
var _legs: Array[Node3D] = [] # hip pivots: [left, right]
var _upper_l: MeshInstance3D
var _fore_l: MeshInstance3D
var _elbow_l: MeshInstance3D
var _hand_l: Node3D
const HIP_Y := 0.70
var _time := 0.0
var _face: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _pupils: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _mouth_smile: Node3D
var _mouth_open: Node3D
var _mouth_frown: Node3D
var _blink_t := 0.0
var _next_blink := 2.0
var _react_t := 0.0
var _built := false


func _ready() -> void:
	_build()


## Rebuild with a different person / colours (e.g. the next bowler).
func set_look(seed: int, p_shirt: Color) -> void:
	if seed == look_seed and p_shirt == shirt and _built:
		return
	look_seed = seed
	shirt = p_shirt
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_legs.clear()
	_face.clear()
	_eyes.clear()
	_pupils.clear()
	_brows.clear()
	_solid_mats.clear()
	_build()


## Stable look for a player name (same person in every sport).
static func seed_for(p_name: String) -> int:
	return absi(hash(p_name.to_lower().strip_edges())) % 100000


func _build() -> void:
	_built = true
	var rng := RandomNumberGenerator.new()
	if look_seed >= 0:
		rng.seed = look_seed * 7919 + 17
	else:
		rng.randomize()
	skin = SKINS[rng.randi() % SKINS.size()]
	hair_color = HAIRS[rng.randi() % HAIRS.size()]
	if rng.randf() < 0.08:
		hair_color = HAIRS[5] # a few grey heads
	hair_style = rng.randi() % 6
	_next_blink = rng.randf_range(1.0, 4.0)

	var shorts := outfit == "tennis"
	var shoe_col := Color(0.96, 0.96, 0.98)
	var accent := shirt.lerp(Color.WHITE, 0.15)
	match outfit:
		"bowling":
			shoe_col = Color(0.85, 0.2, 0.2) if rng.randf() < 0.5 else Color(0.25, 0.35, 0.8)
		"umpire":
			shoe_col = Color(0.15, 0.15, 0.18)

	_body = Node3D.new()
	add_child(_body)
	# legs hang from hip pivots so they can step
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.11 * side, HIP_Y, 0.0)
		add_child(hip)
		_legs.append(hip)
		if shorts:
			var short_leg := _mesh(_capsule(0.1, 0.34), pants)
			short_leg.position = Vector3(0, -0.12, 0)
			hip.add_child(short_leg)
			var shin := _mesh(_capsule(0.072, 0.46), skin)
			shin.position = Vector3(0, -0.4, 0)
			hip.add_child(shin)
			var sock := _mesh(_cylinder(0.075, 0.1), Color(0.98, 0.98, 1.0))
			sock.position = Vector3(0, -0.56, 0)
			hip.add_child(sock)
		else:
			var leg := _mesh(_capsule(0.088, 0.64), pants)
			leg.position = Vector3(0, -0.32, 0)
			hip.add_child(leg)
		# trainers: coloured upper on a white sole
		var sole := _mesh(_sphere(0.1), Color(0.97, 0.97, 0.98))
		sole.scale = Vector3(1.02, 0.32, 1.5)
		sole.position = Vector3(0, -0.665, -0.045)
		hip.add_child(sole)
		var upper := _mesh(_sphere(0.095), shoe_col)
		upper.scale = Vector3(0.98, 0.6, 1.4)
		upper.position = Vector3(0, -0.635, -0.035)
		hip.add_child(upper)

	# torso: slim, sporty, slightly tapered (chest + waist)
	var torso := _mesh(_capsule(0.215, 0.74), shirt)
	torso.scale = Vector3(1.08, 1.0, 0.82)
	torso.position = Vector3(0, 1.08, 0)
	_body.add_child(torso)
	var hips := _mesh(_capsule(0.17, 0.28), pants)
	hips.scale = Vector3(1.15, 1.0, 0.85)
	hips.position = Vector3(0, 0.78, 0)
	_body.add_child(hips)
	match outfit:
		"bowling":
			# two-tone retro bowling shirt: contrast chest yoke and a big collar
			var yoke := _mesh(_torus(0.2, 0.23), Color(0.97, 0.95, 0.9))
			yoke.scale = Vector3(1.08, 2.2, 0.84)
			yoke.position = Vector3(0, 1.27, 0)
			_body.add_child(yoke)
			var collar_b := _mesh(_torus(0.075, 0.12), Color(0.97, 0.95, 0.9))
			collar_b.position = Vector3(0, 1.43, 0)
			collar_b.scale = Vector3(1.0, 0.5, 0.92)
			_body.add_child(collar_b)
		"cricket":
			var vneck := _mesh(_box(Vector3(0.12, 0.12, 0.02)), accent.darkened(0.25))
			vneck.rotation.z = PI * 0.25
			vneck.position = Vector3(0, 1.4, -0.168)
			_body.add_child(vneck)
			var collar_c := _mesh(_torus(0.07, 0.1), accent.darkened(0.25))
			collar_c.position = Vector3(0, 1.43, 0)
			collar_c.scale = Vector3(1.0, 0.6, 0.9)
			_body.add_child(collar_c)
		_:
			var collar := _mesh(_torus(0.07, 0.1), Color(0.96, 0.97, 1.0) if outfit != "umpire" else Color(0.15, 0.15, 0.2))
			collar.position = Vector3(0, 1.43, 0)
			collar.scale = Vector3(1.0, 0.6, 0.9)
			_body.add_child(collar)
			if outfit == "tennis":
				# a white band round the chest of the polo
				var band_t := _mesh(_torus(0.205, 0.228), Color(0.98, 0.98, 1.0))
				band_t.scale = Vector3(1.08, 1.6, 0.84)
				band_t.position = Vector3(0, 1.2, 0)
				_body.add_child(band_t)
	var belt := _mesh(_cylinder(0.215, 0.04), Color(0.12, 0.14, 0.2) if not shorts else pants.darkened(0.15))
	belt.scale = Vector3(1.08, 1.0, 0.82)
	belt.position = Vector3(0, 0.79, 0)
	_body.add_child(belt)
	var neck := _mesh(_cylinder(0.065, 0.12), skin)
	neck.position = Vector3(0, 1.47, 0)
	_body.add_child(neck)

	_build_head()
	if outfit == "tennis":
		var band := _mesh(_torus(0.2, 0.235), shirt.lerp(Color.WHITE, 0.6))
		band.scale = Vector3(0.98, 0.9, 1.02)
		band.rotation.x = -0.12
		band.position = Vector3(0, 0.07, 0.0)
		_head.add_child(band)
	elif outfit == "umpire":
		var cap := _mesh(_sphere(0.228), Color(0.96, 0.96, 0.98))
		cap.scale = Vector3(1.0, 0.62, 1.05)
		cap.position = Vector3(0, 0.1, 0.0)
		_head.add_child(cap)
		var peak := _mesh(_cylinder(0.14, 0.015), Color(0.96, 0.96, 0.98))
		peak.scale = Vector3(1.0, 1.0, 0.8)
		peak.position = Vector3(0, 0.06, -0.2)
		_head.add_child(peak)

	# arms (both IK)
	for right: bool in [false, true]:
		var sh_pos := _shoulder_r if right else _shoulder_l
		var shoulder := _mesh(_sphere(0.082), shirt)
		shoulder.position = sh_pos
		_body.add_child(shoulder)
		var upper_m := _mesh(_capsule(0.066, UPPER + 0.1), shirt)
		var fore_m := _mesh(_capsule(0.055, FORE + 0.08), skin)
		var elbow_m := _mesh(_sphere(0.06), skin)
		_body.add_child(upper_m)
		_body.add_child(fore_m)
		_body.add_child(elbow_m)
		var hand := Node3D.new()
		_body.add_child(hand)
		# mitten hand with a thumb
		var palm := _mesh(_sphere(0.068), skin)
		palm.scale = Vector3(0.85, 0.8, 1.05)
		hand.add_child(palm)
		var thumb := _mesh(_capsule(0.024, 0.08), skin)
		thumb.rotation = Vector3(0.6, 0, 0.9 * (1.0 if right else -1.0))
		thumb.position = Vector3(0.045 * (-1.0 if right else 1.0), 0.02, -0.035)
		hand.add_child(thumb)
		if outfit == "tennis" and right:
			var wb := _mesh(_cylinder(0.062, 0.06), shirt.lerp(Color.WHITE, 0.6))
			wb.position = Vector3(0, 0.07, 0)
			fore_m.add_child(wb)
		if right:
			_upper_r = upper_m
			_fore_r = fore_m
			_elbow_r = elbow_m
			_hand_r = hand
		else:
			_upper_l = upper_m
			_fore_l = fore_m
			_elbow_l = elbow_m
			_hand_l = hand

	# remote held in the hand (long axis = local -Z, buttons = +Y)
	_remote = Node3D.new()
	_hand_r.add_child(_remote)
	var shell := _mesh(_box(Vector3(0.055, 0.035, 0.24)), Color(0.22, 0.25, 0.32))
	shell.position = Vector3(0, 0.02, -0.07)
	_remote.add_child(shell)
	var btn := _mesh(_cylinder(0.014, 0.012), Color(0.2, 0.55, 1.0))
	btn.position = Vector3(0, 0.042, -0.13)
	_remote.add_child(btn)
	var tip := MeshInstance3D.new()
	tip.mesh = _sphere(0.026)
	_tip_mat = material(Color(0.4, 0.85, 1.0)).duplicate()
	_tip_mat.emission_enabled = true
	_tip_mat.emission = Color(0.3, 0.8, 1.0)
	_tip_mat.emission_energy_multiplier = 1.0
	tip.material_override = _tip_mat
	tip.position = Vector3(0, 0.02, -0.195)
	_remote.add_child(tip)
	if not shadows:
		for mi in find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_head() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0, 1.67, 0)
	_body.add_child(_head)
	var skull := _mesh(_sphere(0.21), skin)
	skull.scale = Vector3(0.95, 1.08, 1.0)
	_head.add_child(skull)
	var hc := hair_color
	match hair_style:
		0: # short, swept fringe
			var crown := _mesh(_sphere(0.225), hc)
			crown.scale = Vector3(1.0, 0.8, 1.06)
			crown.position = Vector3(0, 0.075, 0.015)
			_head.add_child(crown)
			var back := _mesh(_sphere(0.215), hc)
			back.scale = Vector3(0.98, 0.85, 0.85)
			back.position = Vector3(0, -0.005, 0.055)
			_head.add_child(back)
			for i in 4:
				var tuft := _mesh(_capsule(0.045, 0.2), hc)
				tuft.rotation = Vector3(deg_to_rad(70), deg_to_rad(-25 + i * 14), deg_to_rad(65))
				tuft.position = Vector3(-0.09 + i * 0.06, 0.15 + i * 0.008, -0.125 + absf(i - 1.5) * 0.012)
				_head.add_child(tuft)
		1: # neat crop
			var cap := _mesh(_sphere(0.218), hc)
			cap.scale = Vector3(1.0, 0.78, 1.04)
			cap.position = Vector3(0, 0.07, 0.02)
			_head.add_child(cap)
			var back2 := _mesh(_sphere(0.208), hc)
			back2.scale = Vector3(0.98, 0.8, 0.82)
			back2.position = Vector3(0, 0.0, 0.06)
			_head.add_child(back2)
		2: # spiky
			var base := _mesh(_sphere(0.22), hc)
			base.scale = Vector3(1.0, 0.78, 1.04)
			base.position = Vector3(0, 0.07, 0.02)
			_head.add_child(base)
			for i in 7:
				var a := -1.1 + i * 0.37
				var spike := _mesh(_cone(0.05, 0.14), hc)
				spike.position = Vector3(sin(a) * 0.12, 0.2, cos(a) * 0.06 - 0.02)
				spike.rotation = Vector3(-0.5 + cos(a) * 0.3, 0, -sin(a) * 0.7)
				_head.add_child(spike)
		3: # ponytail
			var cap3 := _mesh(_sphere(0.224), hc)
			cap3.scale = Vector3(1.0, 0.82, 1.05)
			cap3.position = Vector3(0, 0.07, 0.015)
			_head.add_child(cap3)
			var tie := _mesh(_sphere(0.06), hc)
			tie.position = Vector3(0, 0.08, 0.22)
			_head.add_child(tie)
			var tail := _mesh(_capsule(0.055, 0.3), hc)
			tail.rotation.x = 0.5
			tail.position = Vector3(0, -0.04, 0.27)
			_head.add_child(tail)
		4: # bob / longer hair
			var cap4 := _mesh(_sphere(0.228), hc)
			cap4.scale = Vector3(1.04, 0.86, 1.06)
			cap4.position = Vector3(0, 0.06, 0.02)
			_head.add_child(cap4)
			var hang := _mesh(_sphere(0.23), hc)
			hang.scale = Vector3(1.08, 1.0, 0.85)
			hang.position = Vector3(0, -0.06, 0.07)
			_head.add_child(hang)
			var fringe := _mesh(_capsule(0.05, 0.3), hc)
			fringe.rotation.z = PI * 0.5
			fringe.position = Vector3(0, 0.13, -0.16)
			_head.add_child(fringe)
		_: # curly
			var core := _mesh(_sphere(0.218), hc)
			core.scale = Vector3(1.0, 0.8, 1.04)
			core.position = Vector3(0, 0.07, 0.02)
			_head.add_child(core)
			for i in 12:
				var a := float(i) / 12.0 * TAU
				var curl := _mesh(_sphere(0.075), hc)
				curl.position = Vector3(sin(a) * 0.17, 0.14 + sin(a * 3.0) * 0.02, cos(a) * 0.15 + 0.02)
				_head.add_child(curl)
	# ears
	for side: float in [-1.0, 1.0]:
		var ear := _mesh(_sphere(0.042), skin)
		ear.scale = Vector3(0.6, 1.0, 0.8)
		ear.position = Vector3(0.2 * side, -0.01, 0.0)
		_head.add_child(ear)
	# big friendly eyes: white, iris, pupil and a highlight; they blink
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.072 * side, 0.005, -0.178)
		_head.add_child(eye)
		var white := _mesh(_sphere(0.04), Color(0.98, 0.98, 1.0))
		white.scale = Vector3(0.9, 1.15, 0.5)
		eye.add_child(white)
		var pupil := _mesh(_sphere(0.024), Color(0.12, 0.1, 0.1))
		pupil.scale = Vector3(1.0, 1.15, 0.5)
		pupil.position = Vector3(0, -0.004, -0.015)
		eye.add_child(pupil)
		var glint := _mesh(_sphere(0.008), Color(1, 1, 1))
		glint.position = Vector3(0.008, 0.01, -0.028)
		pupil.add_child(glint)
		_eyes.append(eye)
		_pupils.append(pupil)
		_face.append(eye)
		var brow := _mesh(_capsule(0.012, 0.075), hair_color.darkened(0.2))
		brow.rotation = Vector3(0, 0, deg_to_rad(90 + 8 * side))
		brow.position = Vector3(0.075 * side, 0.072, -0.19)
		_head.add_child(brow)
		_brows.append(brow)
		_face.append(brow)
		var cheek := _mesh(_sphere(0.03), skin.lerp(Color(1.0, 0.5, 0.5), 0.35))
		cheek.scale = Vector3(1.0, 0.6, 0.3)
		cheek.position = Vector3(0.115 * side, -0.055, -0.168)
		_head.add_child(cheek)
		_face.append(cheek)
	var nose := _mesh(_sphere(0.026), skin.darkened(0.04))
	nose.scale = Vector3(1.0, 0.9, 1.0)
	nose.position = Vector3(0, -0.035, -0.205)
	_head.add_child(nose)
	_face.append(nose)
	# mouths: smile (default), open (happy), frown (sad)
	_mouth_smile = _mesh(_torus(0.028, 0.038), Color(0.55, 0.2, 0.18))
	_mouth_smile.rotation = Vector3(deg_to_rad(90), 0, 0)
	_mouth_smile.scale = Vector3(1.0, 1.0, 0.35)
	_mouth_smile.position = Vector3(0, -0.098, -0.19)
	_head.add_child(_mouth_smile)
	_face.append(_mouth_smile)
	_mouth_open = _mesh(_sphere(0.034), Color(0.45, 0.12, 0.14))
	_mouth_open.scale = Vector3(1.1, 0.85, 0.4)
	_mouth_open.position = Vector3(0, -0.1, -0.188)
	_head.add_child(_mouth_open)
	_face.append(_mouth_open)
	_mouth_frown = _mesh(_capsule(0.01, 0.06), Color(0.55, 0.2, 0.18))
	_mouth_frown.rotation = Vector3(0, 0, PI * 0.5)
	_mouth_frown.position = Vector3(0, -0.105, -0.195)
	_head.add_child(_mouth_frown)
	_face.append(_mouth_frown)


## Play a reaction for a few seconds, then go back to normal.
func react(kind: String, seconds := 2.5) -> void:
	reaction = kind
	_react_left = seconds


func _process(delta: float) -> void:
	_time += delta
	if _react_left > 0.0:
		_react_left -= delta
		if _react_left <= 0.0:
			reaction = ""
	_update_face(delta)
	# upper body: breathing, walking bob, knee bend and forward lean around the hips
	var bob := sin(_time * 2.2) * 0.008 + absf(sin(step_phase)) * 0.035 * walk_amount
	var lean_now := lean
	if reaction == "cheer":
		_react_t += delta
		bob += absf(sin(_react_t * 7.0)) * 0.12 # little hops
		lean_now = -0.05
	elif reaction == "sad":
		_react_t += delta
		lean_now = 0.22
	else:
		_react_t = 0.0
	var pivot := Vector3(0, HIP_Y, 0)
	var lb := Basis(Vector3.RIGHT, -lean_now)
	_body.transform = Transform3D(lb, pivot - lb * pivot + Vector3(0, bob - crouch, 0))
	# legs: alternate steps, then slide / kick-back pose at release
	var stride := sin(step_phase) * 0.5 * walk_amount
	_legs[0].rotation.x = stride + slide * 0.55 # left leg forward
	_legs[1].rotation.x = -stride - slide * 0.75 # right leg back
	for leg in _legs:
		leg.position.y = HIP_Y + bob - crouch
	_legs[0].position.z = -crouch * 0.6
	_legs[1].position.z = -crouch * 0.6

	if reaction != "":
		_react_arms()
		_remote.visible = false
		hand_world = _hand_r.global_position
		return

	# left arm: hangs, swings with the steps, reaches out for balance
	var rest_l := _shoulder_l + Vector3(-0.08, -0.55, 0.03 + sin(step_phase) * 0.12 * walk_amount)
	var out_l := _shoulder_l + Vector3(-0.5, -0.22, -0.12)
	_solve_limb(_body.transform * rest_l.lerp(out_l, balance_arm), _shoulder_l, _upper_l, _fore_l, _elbow_l, _hand_l, Vector3(-1.0, 0.0, 0.2))

	if hand_targets:
		_solve_limb(to_local(hand_r_world), _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(1.0, -0.6, 0.6))
		_solve_limb(to_local(hand_l_world), _shoulder_l, _upper_l, _fore_l, _elbow_l, _hand_l, Vector3(-1.0, -0.6, 0.6))
		_remote.visible = false
		_head.rotation = Vector3(head_tilt + lean * 0.3, head_turn, 0)
		hand_world = _hand_r.global_position
		return

	if bowling:
		# swing angle is relative to gravity, so it stays true while leaning
		var dir_b := Basis(Vector3.RIGHT, swing_angle - PI * 0.5) * Vector3.FORWARD
		var sh := _body.transform * _shoulder_r
		_solve_limb(sh + Vector3(0.06, 0.0, 0.0) + dir_b * (UPPER + FORE) * 0.97, _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(1.0, 0.0, 0.15))
		_remote.visible = false
		_head.rotation = Vector3(0.12 + lean * 0.4, 0, 0)
		hand_world = _hand_r.global_position
		return
	_remote.visible = true
	var aim := Basis(Vector3.UP, -aim_yaw) * Basis(Vector3.RIGHT, aim_pitch)
	var dir := aim * Vector3.FORWARD
	var target := _body.transform * _shoulder_r + Vector3(0.04, 0.0, 0.0) + dir * (UPPER + FORE) * 0.9
	_solve_limb(target, _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(0.6, -1.0, 0.35))

	# remote follows the full calibrated phone rotation
	var full := aim * Basis(Vector3.BACK, -aim_roll)
	_remote.global_basis = global_basis * full
	tip_world = _remote.global_transform * Vector3(0, 0.02, -0.2)
	tip_forward = (global_basis * full * Vector3.FORWARD).normalized()

	# head follows the aim a little
	_head.rotation = Vector3(clampf(aim_pitch, -0.8, 0.8) * 0.3, -clampf(aim_yaw, -1.2, 1.2) * 0.45, 0)

	_tip_mat.emission_energy_multiplier = 1.0 + swing * 6.0


## World position of the right hand (for props such as a racket).
func right_hand() -> Vector3:
	return _hand_r.global_position


func _react_arms() -> void:
	var t := _react_t
	if reaction == "cheer":
		# fists up in a V, pumping
		var pump := sin(t * 7.0) * 0.08
		var r := _shoulder_r + Vector3(0.26, 0.5 + pump, -0.08)
		var l := _shoulder_l + Vector3(-0.26, 0.5 - pump, -0.08)
		_solve_limb(_body.transform * r, _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(1.0, 0.0, 0.3))
		_solve_limb(_body.transform * l, _shoulder_l, _upper_l, _fore_l, _elbow_l, _hand_l, Vector3(-1.0, 0.0, 0.3))
		_head.rotation = Vector3(-0.25, sin(t * 3.0) * 0.15, 0)
	else:
		# shoulders slump, hands on the knees-ish, head shakes slowly
		var r2 := _shoulder_r + Vector3(0.04, -0.56, -0.12)
		var l2 := _shoulder_l + Vector3(-0.04, -0.56, -0.12)
		_solve_limb(_body.transform * r2, _shoulder_r, _upper_r, _fore_r, _elbow_r, _hand_r, Vector3(1.0, 0.0, 0.2))
		_solve_limb(_body.transform * l2, _shoulder_l, _upper_l, _fore_l, _elbow_l, _hand_l, Vector3(-1.0, 0.0, 0.2))
		_head.rotation = Vector3(0.35, sin(t * 2.2) * 0.25, 0)


func _update_face(delta: float) -> void:
	if _eyes.is_empty():
		return
	# blink every few seconds
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_t = 0.14
		_next_blink = randf_range(1.8, 4.5)
	var open := 1.0
	if _blink_t > 0.0:
		_blink_t -= delta
		open = clampf(absf(_blink_t - 0.07) / 0.07, 0.08, 1.0)
	var m := mood
	if reaction == "cheer":
		m = 1.0
	elif reaction == "sad":
		m = -1.0
	for e in _eyes:
		e.scale = Vector3(1.0, open * (0.75 if m > 0.5 else 1.0), 1.0)
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		var b := _brows[i]
		b.position.y = 0.072 + (0.012 if m > 0.5 else 0.0)
		b.rotation.z = deg_to_rad(90 + 8 * side - (18.0 * side if m < -0.5 else 0.0))
	if _mouth_smile:
		var happy := m > 0.5
		var sad := m < -0.5
		_mouth_open.visible = happy and _ghost_off
		_mouth_frown.visible = sad and _ghost_off
		_mouth_smile.visible = not happy and not sad and _ghost_off


const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.82, 0.93, 1.0);
uniform float base_alpha = 0.05;
uniform float rim_alpha = 0.42;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(tint, vec3(1.0), rim);
	ALPHA = base_alpha + rim * rim_alpha;
}
"""

static var _ghost_mat: ShaderMaterial
var _solid_mats := {}
var _ghost_off := true


## Glassy see-through look while aiming so the lane stays visible:
## mostly clear with a soft white outline. strength 0 = solid.
## Tint the glass bowler with the current player's colour.
func set_ghost_tint(c: Color) -> void:
	if _ghost_mat:
		_ghost_mat.set_shader_parameter("tint", c.lerp(Color.WHITE, 0.45))


func set_ghost(strength: float) -> void:
	if _ghost_mat == null:
		var sh := Shader.new()
		sh.code = GHOST_SHADER
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = sh
	var on := strength > 0.0
	_ghost_off = not on
	for f in _face: # the face would show through the back of the head
		f.visible = not on
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.get_parent() == _remote or m.get_parent().get_parent() == _remote:
			continue
		if not _solid_mats.has(m):
			_solid_mats[m] = m.material_override
		m.material_override = _ghost_mat if on else _solid_mats[m]
	_update_face(0.0)


## Two-bone IK. `target` is in character space; the limb lives in _body
## space (so it follows the lean). Shoulder is given in _body space.
func _solve_limb(target: Vector3, shoulder: Vector3, upper: MeshInstance3D, fore: MeshInstance3D,
		elbow_mi: MeshInstance3D, hand_node: Node3D, pole_hint: Vector3) -> void:
	var inv := _body.transform.affine_inverse()
	var t := inv * target
	var to_t := t - shoulder
	var d := clampf(to_t.length(), 0.05, UPPER + FORE - 0.001)
	var axis := to_t.normalized()
	var cos_a := (UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var pole := inv.basis * pole_hint
	pole = pole - axis * pole.dot(axis)
	pole = pole.normalized() if pole.length() > 0.001 else Vector3.RIGHT
	var elbow := shoulder + axis * UPPER * cos_a + pole * UPPER * sin_a
	var hand := shoulder + axis * d
	_place(upper, shoulder, elbow)
	_place(fore, elbow, hand)
	elbow_mi.position = elbow
	hand_node.position = hand
	# hand points along the forearm
	var fy := (hand - elbow).normalized()
	var ref := Vector3.FORWARD if absf(fy.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var fx := ref.cross(fy).normalized()
	hand_node.basis = Basis(fx, fy, fx.cross(fy))


# Positions a Y-aligned capsule between two points (in its parent's space).
func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)


func _segment(a: Vector3, b: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := _mesh(_capsule(r, a.distance_to(b) + r * 2.0), c)
	_place(mi, a, b)
	return mi


# ------------------------------------------------------------- primitives

static var _mat_cache := {}
static var _mesh_cache := {}


## Soft cartoon material (wrapped diffuse + gentle rim). Shared per colour.
static func material(c: Color, rough := 0.55) -> StandardMaterial3D:
	var key := "%s/%.2f" % [c.to_html(), rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.6
	_mat_cache[key] = m
	return m


static func _mesh(mesh: Mesh, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(c)
	return mi


static func _cached(key: String, make: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = make.call()
	return _mesh_cache[key]


static func _capsule(r: float, h: float) -> CapsuleMesh:
	return _cached("cap%.3f/%.3f" % [r, h], func():
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 24
		m.rings = 8
		return m)


static func _sphere(r: float) -> SphereMesh:
	return _cached("sph%.3f" % r, func():
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 32 if r > 0.05 else 16
		m.rings = 16 if r > 0.05 else 8
		return m)


static func _cylinder(r: float, h: float) -> CylinderMesh:
	return _cached("cyl%.3f/%.3f" % [r, h], func():
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 32
		return m)


static func _cone(r: float, h: float) -> CylinderMesh:
	return _cached("cone%.3f/%.3f" % [r, h], func():
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 12
		return m)


static func _box(s: Vector3) -> BoxMesh:
	return _cached("box%s" % s, func():
		var m := BoxMesh.new()
		m.size = s
		return m)


static func _torus(inner: float, outer: float) -> TorusMesh:
	return _cached("tor%.3f/%.3f" % [inner, outer], func():
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		return m)
