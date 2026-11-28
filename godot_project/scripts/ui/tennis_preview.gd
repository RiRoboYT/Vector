class_name TennisPreview
extends SubViewport
## Live 3D attract loop for menus: the court with four players and a slow sweep.

var _cam: Camera3D
var _t := 0.0
var _players: Array[TennisPlayer] = []


func _init(px := Vector2i(960, 540)) -> void:
	size = px
	own_world_3d = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	add_child(TennisCourt.new())
	var spots := [Vector3(1.5, 0, 11.6), Vector3(-2.5, 0, 3.4), Vector3(-1.8, 0, -11.4), Vector3(2.4, 0, -3.8)]
	for i in 4:
		var p := TennisPlayer.new()
		p.setup(i / 2, i % 2, TennisGame.TEAM_COLORS[i / 2], "")
		add_child(p)
		p.global_position = spots[i]
		p.target = spots[i]
		_players.append(p)
	_cam = Camera3D.new()
	_cam.fov = 50
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	if fmod(_t, 2.4) < delta:
		var p := _players[int(_t / 2.4) % 4]
		p.start_swing("fh" if randf() < 0.6 else "bh", 2.6)
	var a := sin(_t * 0.15) * 0.6
	var center := Vector3(0, 0.6, -1.0)
	var pos := Vector3(sin(a) * 22.0, 7.5 + sin(_t * 0.3) * 0.6, cos(a) * 22.0)
	_cam.look_at_from_position(pos, center)
