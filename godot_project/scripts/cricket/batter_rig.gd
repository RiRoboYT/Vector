class_name BatterRig
extends Node3D
## The striker: a character holding a CricketBat.
##
## The whole bat rotates rigidly about the batter's chest (`pivot`) by a
## world rotation R. With a phone, R is the phone's rotation since "ready"
## (so the bat copies the phone 1:1). The CPU builds R from a swing angle.
## Stance: bat hanging vertically by the back toe, face towards the bowler.

var character: Character
var bat: CricketBat
var left_handed := false
var stance_x := 0.0 # sideways shuffle across the crease (◀ ▶)
var reach_x := 0.0 # hands / bat reaching across to the line of the ball (assist)
var R := Basis.IDENTITY
## Footwork: raise/lower the hands so the middle of the bat meets the ball
## height (back foot for short balls, bending low for full ones).
var lift := 0.0

const BODY_Z := -0.85
const CHEST_Y := 1.25


func setup(team_shirt: Color, lefty: bool) -> void:
	left_handed = lefty
	if character:
		character.queue_free()
	character = Character.new()
	character.shirt = team_shirt
	character.pants = Color(0.95, 0.95, 0.95) # cricket whites
	character.hand_targets = true
	add_child(character)
	if bat == null:
		bat = CricketBat.new()
		add_child(bat)
		bat.top_level = true


func side() -> float:
	return -1.0 if left_handed else 1.0


## Where the body stands: leg side of the stumps, chest facing the off side.
func body_pos() -> Vector3:
	# feet stay planted on the leg side of the stumps
	var x := -0.42 * side() + stance_x
	x = minf(x, -0.18) if not left_handed else maxf(x, 0.18)
	return Vector3(x, 0, BODY_Z)


func pivot() -> Vector3:
	return body_pos() + Vector3(0.1 * side() + reach_x * 0.5, CHEST_Y + lift, 0)


func stance_hands() -> Vector3:
	return body_pos() + Vector3(0.34 * side() + reach_x, 0.96 + lift, -0.08)


func stance_transform() -> Transform3D:
	# bat-local +Y up (handle), +Z face -> towards the bowler (-Z world)
	return Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), stance_hands())


## Pose the bat by rotating the stance about the chest.
func apply_rotation(rot: Basis) -> void:
	R = rot.orthonormalized()
	var pv := pivot()
	var st := stance_transform()
	bat.global_transform = Transform3D(R * st.basis, pv + R * (st.origin - pv))


## Footwork target for a ball arriving at height `h`: middle of the bat
## (sweet spot, 0.80 m below the hands) meets it with the bat upright.
static func lift_for_ball(h: float) -> float:
	return clampf(h + 0.80 - 0.96, -0.3, 0.55)


## CPU / test swing: phi = swing angle about the horizontal axis (0 = bat
## vertical, -2 = high backlift, +1 = follow-through), psi = aim of the face
## (+ = towards the leg side for a right-hander), tilt = loft.
static func swing_rotation(phi: float, psi: float) -> Basis:
	return Basis(Vector3.UP, psi) * Basis(Vector3.RIGHT, phi)


func _process(_delta: float) -> void:
	if character == null or bat == null:
		return
	var bp := body_pos()
	character.position = bp
	# chest faces the off side; turn the shoulders with the bat
	var yaw_from_bat := (R * Vector3.FORWARD)
	var twist := atan2(-yaw_from_bat.x, -yaw_from_bat.z) * 0.35
	character.rotation.y = -PI * 0.5 * side() + twist
	var top := bat.global_transform * Vector3.ZERO
	var low := bat.global_transform * Vector3(0, -0.11, 0)
	# right-hander: left hand on top of the handle
	character.hand_l_world = top if not left_handed else low
	character.hand_r_world = low if not left_handed else top
	# eyes on the bowler
	character.head_turn = PI * 0.5 * side() * 0.8 - twist
	character.head_tilt = 0.15
	# bend for full balls, stand tall for short ones (feet stay on the ground)
	character.crouch = clampf(0.08 - lift * 0.6, 0.0, 0.25)
	character.lean = 0.18 + clampf(-lift, 0.0, 0.3) * 0.6 + absf(reach_x) * 0.3
	character.position.y = 0.0
	character.walk_amount = 0.0
	character.slide = clampf(absf(reach_x) * 1.2, 0.0, 0.5) # front foot stride towards the ball
