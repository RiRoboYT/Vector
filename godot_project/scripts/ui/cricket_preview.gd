class_name CricketPreview
extends SubViewport
## Live 3D attract loop for menus: the stadium with players in place and a
## slow camera sweep around the square.

var _cam: Camera3D
var _t := 0.0


func _init(px := Vector2i(960, 540)) -> void:
	size = px
	own_world_3d = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	add_child(CricketField.new())
	var rig := BatterRig.new()
	add_child(rig)
	rig.setup(CricketGame.TEAM_COLORS[0], false)
	rig.apply_rotation(BatterRig.swing_rotation(-0.9, 0.0))
	var spots := [Vector3(0.0, 0, 1.9), Vector3(1.8, 0, 3.4), Vector3(16, 0, -1), Vector3(-16, 0, -10), Vector3(8, 0, -20), Vector3(0.9, 0, CricketField.BOWL_Z - 6.0)]
	for p in spots:
		var c := Character.new()
		c.shirt = CricketGame.TEAM_COLORS[1]
		c.pants = Color(0.95, 0.95, 0.95)
		c.outfit = "cricket"
		c.hand_targets = true
		add_child(c)
		c.position = p
		c.rotation.y = atan2(p.x, p.z) + PI
		c.hand_r_world = p + Vector3(0.2, 0.9, -0.3)
		c.hand_l_world = p + Vector3(-0.2, 0.9, -0.3)
	_cam = Camera3D.new()
	_cam.fov = 50
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	var a := _t * 0.12
	var center := Vector3(0, 0.8, -6.0)
	var pos := center + Vector3(sin(a) * 13.0, 3.4 + sin(_t * 0.3) * 0.6, cos(a) * 13.0 + 4.0)
	_cam.look_at_from_position(pos, center)
