extends Node
## VectorSports app: owns the phone connections and moves between screens.
## Flow: Safety -> Home -> Title -> Sports menu -> Lobby (players join) ->
## Tutorial (first time) -> Calibration of every phone (compulsory) -> Bowling.
## A phone that connects at any time is asked to calibrate too.

var server: ControllerServer
var roster: Players
var pad: Pad
var sfx: Sfx

var _ui: CanvasLayer
var _overlay: CanvasLayer
var _top: CanvasLayer
var _screen: Node
var _calib: CalibrationScreen
var _calib_then: Callable
var _keyboard_ok := false
var _fade: ColorRect
var _cursor: CursorView
var _connect: ConnectCard
var _toast: Label
var _toast_t := 0.0

var _ips: PackedStringArray = []
var _ip_index := 0
var _qr_tex: Texture2D
var _url := ""
var _tutorial_seen := false
var _cricket_tutorial_seen := false
var _screen_hint := ""


func _ready() -> void:
	_setup_display_scaling()
	sfx = Sfx.new()
	add_child(sfx)
	pad = Pad.new()
	add_child(pad)
	server = ControllerServer.new()
	server.process_priority = -200
	add_child(server)
	roster = Players.new()
	roster.server = server
	add_child(roster)
	server.message_received.connect(_on_message)
	roster.phone_joined.connect(_on_phone_joined)
	roster.phone_left.connect(_on_phone_left)

	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	add_child(_overlay)
	_top = CanvasLayer.new()
	_top.layer = 100
	add_child(_top)
	_connect = ConnectCard.new()
	_top.add_child(_connect)
	_toast = UI.label("", 30, UI.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_color_override("font_outline_color", UI.BLUE_DARK)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 24
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_top.add_child(_toast)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_fade)
	_cursor = CursorView.new()
	_top.add_child(_cursor)

	_ips = NetUtil.lan_addresses()
	var cert_ips := _ips.duplicate()
	cert_ips.append("127.0.0.1")
	var made := CertUtil.load_or_create(cert_ips)
	server.start(made[0], made[1])
	if server.error_text != "":
		toast(server.error_text, 8.0)
	elif _ips.is_empty():
		toast("No Wi-Fi connection found. Connect to Wi-Fi and restart.", 8.0)
	_update_qr()

	var start := "safety"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start="):
			start = arg.get_slice("=", 1)
	match start:
		"home": go_home()
		"sports": go_sports()
		"lobby": go_lobby()
		"tutorial": go_tutorial()
		"cricket":
			roster.lobby_open = false
			go_cricket()
		"bowling":
			roster.lobby_open = false
			for arg in OS.get_cmdline_user_args(): # test helper: --test-players=A,B,C
				if arg.begins_with("--test-players="):
					for n in arg.get_slice("=", 1).split(","):
						var tp := Players.Player.new()
						tp.pid = "keyboard"
						tp.name = n
						tp.color = Players.COLORS[roster.players.size() % Players.COLORS.size()]
						roster.players.append(tp)
			roster.ensure_keyboard_player()
			go_bowling()
		_: go_safety()
	_maybe_screenshot()


func _setup_display_scaling() -> void:
	# UI scales cleanly (canvas_items); for 1440p / 4K render 3D a little lower
	# and upscale with FSR so it stays smooth on modest laptops.
	var h := DisplayServer.screen_get_size().y
	var vp := get_viewport()
	if h >= 2000:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.6
	elif h >= 1400:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.77


# ------------------------------------------------------------------ flow

func go_safety() -> void:
	var s := SafetyScreen.new()
	s.done.connect(func(_a): go_home())
	_switch(s)


func go_home() -> void:
	_open_lobby_state()
	var s := HomeScreen.new()
	s.done.connect(func(a):
		if a == "exit":
			get_tree().quit()
		else:
			go_title())
	_switch(s)


func go_title() -> void:
	var s := TitleScreen.new()
	s.done.connect(func(_a): go_sports())
	_switch(s)


func go_sports() -> void:
	_open_lobby_state()
	var s := SportsMenu.new()
	s.done.connect(func(a):
		if a == "back":
			go_home()
		else:
			go_lobby(a))
	_switch(s)


func go_lobby(sport := "bowling") -> void:
	_open_lobby_state()
	roster.prune_disconnected()
	var s := LobbyScreen.new()
	s.roster = roster
	s.qr = _qr_tex
	s.url = _url
	s.sport = sport.capitalize()
	s.done.connect(func(a):
		if a == "back":
			go_sports()
		elif sport == "cricket":
			roster.lobby_open = false
			roster.ensure_keyboard_player()
			roster.refresh()
			go_cricket_options()
		else:
			_start_from_lobby())
	_switch(s)


func go_cricket_options() -> void:
	var s := CricketOptions.new()
	s.roster = roster
	s.done.connect(func(a):
		if a == "back":
			go_lobby("cricket")
			return
		var o: int = s.overs
		var so: bool = s.super_over
		var d: int = s.difficulty
		var start := func(): calibrate_all(func(): go_cricket(o, so, d))
		if _cricket_tutorial_seen:
			start.call()
		else:
			var t := TutorialScreen.new()
			t.pages = TutorialScreen.CRICKET
			t.title = "How to play cricket"
			t.finish_text = "Let's play!"
			t.done.connect(func(_x):
				_cricket_tutorial_seen = true
				start.call())
			_switch(t))
	_switch(s)


func _open_lobby_state() -> void:
	roster.lock_to("")
	if not roster.lobby_open:
		roster.lobby_open = true
		roster.refresh()


func _start_from_lobby() -> void:
	roster.lobby_open = false
	roster.ensure_keyboard_player()
	roster.refresh()
	if _tutorial_seen:
		calibrate_all(go_bowling)
	else:
		go_tutorial()


func go_tutorial() -> void:
	var s := TutorialScreen.new()
	s.done.connect(func(_a):
		_tutorial_seen = true
		calibrate_all(go_bowling))
	_switch(s)


func go_bowling() -> void:
	var g := BowlingGame.new()
	g.roster = roster
	g.finished.connect(func(a):
		if a == "again":
			calibrate_all(go_bowling)
		else:
			go_sports())
	g.phone_message.connect(_route_game_message)
	_switch(g)


func go_cricket(overs := 1, super_over := true, difficulty := 1) -> void:
	var g := CricketGame.new()
	g.roster = roster
	g.overs = overs
	g.super_over = super_over
	g.difficulty = difficulty
	for arg in OS.get_cmdline_user_args(): # test helpers
		if arg.begins_with("--overs="):
			g.overs = int(arg.get_slice("=", 1))
			g.super_over = false
	g.finished.connect(func(a):
		if a == "again":
			calibrate_all(func(): go_cricket(overs, super_over, difficulty))
		else:
			go_sports())
	g.phone_message.connect(_route_game_message)
	_switch(g)


func _route_game_message(m: Dictionary) -> void:
	var to := str(m.get("to", "*"))
	var data := m.duplicate()
	data.erase("to")
	if to == "*":
		server.broadcast(data)
	else:
		roster.send_to_phone(to, data)


# ------------------------------------------------------------ calibration

## Compulsory before every game: every connected phone calibrates in turn.
func calibrate_all(then: Callable) -> void:
	roster.reset_calibration()
	_keyboard_ok = false
	_calib_then = then
	_next_calibration()


func _next_calibration() -> void:
	if _calib:
		return
	var queue := roster.phones_needing_calibration()
	if not queue.is_empty():
		_show_calibration(queue[0])
		return
	if _calib_then.is_valid() and not roster.any_connected() and not _keyboard_ok:
		_show_calibration(null) # keyboard players confirm with Enter
		return
	var then := _calib_then
	_calib_then = Callable()
	Pad.blocked = false
	if then.is_valid():
		then.call()
	else:
		server.broadcast({"type": "hint", "text": _screen_hint})


func _show_calibration(phone: Players.Phone) -> void:
	_calib = CalibrationScreen.new()
	_calib.roster = roster
	_calib.phone = phone
	_calib.done.connect(_on_calibrated)
	_overlay.add_child(_calib)
	Pad.blocked = true
	if phone:
		roster.set_active(phone.pid)
		for ph in roster.connected_phones():
			var mine := ph == phone
			server.send_to(ph.cid, {"type": "turn", "mine": mine,
				"text": "" if mine else "Waiting for %s to calibrate…" % roster.label_for_phone(phone.pid)})
		roster.send_to_phone(phone.pid, {"type": "hint", "text": "Point at the target on screen and press A"})


func _on_calibrated(action: String) -> void:
	if _calib and _calib.phone == null and action == "ok":
		_keyboard_ok = true
	if _calib:
		_calib.queue_free()
		_calib = null
	server.broadcast({"type": "turn", "mine": true, "text": ""})
	_next_calibration()


# ----------------------------------------------------------------- phones

func _on_phone_joined(pid: String) -> void:
	var mine := roster.players_of(pid)
	toast(("%s joined!" % mine[0].name) if not mine.is_empty() else "Phone connected (game in progress)")
	server.broadcast({"type": "hint", "text": _screen_hint})
	_next_calibration()


func _on_phone_left(pid: String) -> void:
	var who := roster.label_for_phone(pid)
	toast("%s's phone disconnected" % who)
	if _screen is LobbyScreen:
		roster.prune_disconnected()


func _on_message(cid: int, msg: Dictionary) -> void:
	roster.handle(cid, msg)


func _switch(node: Node) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.15 if _screen else 0.0)
	tw.tween_callback(func():
		if _screen:
			_screen.queue_free()
		_screen = node
		if node is Control:
			_ui.add_child(node)
		else:
			add_child(node)
		if node is Screen:
			_screen_hint = (node as Screen).phone_hint
			if _calib == null:
				server.broadcast({"type": "turn", "mine": true, "text": ""})
				server.broadcast({"type": "hint", "text": _screen_hint}))
	tw.tween_property(_fade, "color:a", 0.0, 0.25)


func toast(text: String, secs := 2.0) -> void:
	_toast.text = text
	_toast_t = secs


func _update_qr() -> void:
	var ip := "127.0.0.1" if _ips.is_empty() else _ips[_ip_index]
	_url = "https://%s:%d/" % [ip, ControllerServer.HTTPS_PORT]
	server.redirect_host = ip
	var others := PackedStringArray()
	for i in _ips.size():
		if i != _ip_index:
			others.append(_ips[i])
	var img := QRCode.encode(_url).to_image(8, 2)
	_qr_tex = ImageTexture.create_from_image(img)
	_connect.set_qr(img, _url, others)
	if _screen is LobbyScreen:
		(_screen as LobbyScreen).qr = _qr_tex
		(_screen as LobbyScreen).url = _url


func _process(delta: float) -> void:
	var connected := roster.any_connected()
	var on_bowling := _screen is BowlingGame
	if _calib:
		Pad.pointer_visible = false
	elif _screen is Screen:
		Pad.pointer_visible = (_screen as Screen).wants_pointer
	elif on_bowling:
		Pad.pointer_visible = (_screen as BowlingGame).state == BowlingGame.State.OVER
	elif _screen is CricketGame:
		Pad.pointer_visible = (_screen as CricketGame).phase == CricketGame.Phase.OVER
	_cursor.visible = Pad.pointer_visible
	_connect.want_visible = not connected and not (_screen is LobbyScreen)
	_connect.compact = not (_calib != null or _screen is SafetyScreen or _screen is HomeScreen)
	if _screen is HomeScreen:
		(_screen as HomeScreen).connected = connected
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_Q:
				_connect.user_hidden = not _connect.user_hidden
			KEY_TAB:
				if _ips.size() > 1:
					_ip_index = (_ip_index + 1) % _ips.size()
					_update_qr()


## Test helper: `-- --screenshot=out.png --delay=5 [--wait-phone]`.
func _maybe_screenshot() -> void:
	var path := ""
	var delay := 5.0
	var wait_phone := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--delay="):
			delay = float(arg.get_slice("=", 1))
		elif arg == "--wait-phone":
			wait_phone = true
	if path == "":
		return
	if wait_phone:
		while not roster.any_connected():
			await get_tree().process_frame
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


# ------------------------------------------------------------ small views

class CursorView:
	extends Control

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	var _tilt := 0.0
	var _last := Vector2.ZERO

	func _process(delta: float) -> void:
		# lean a little in the direction of movement
		var vx := (Pad.pointer.x - _last.x) / maxf(delta, 0.001)
		_last = Pad.pointer
		_tilt = lerpf(_tilt, clampf(vx / 4000.0, -0.25, 0.25), 1.0 - exp(-delta * 10.0))
		queue_redraw()

	## Pointing hand; the fingertip is the hotspot.
	func _draw() -> void:
		var p := Pad.pointer
		var s := 1.15
		draw_set_transform(p + Vector2(5, 7), -0.35 + _tilt, Vector2.ONE * s)
		_hand(Color(0, 0, 0, 0.18), 3.5)
		draw_set_transform(p, -0.35 + _tilt, Vector2.ONE * s)
		_hand(UI.BLUE_DARK, 3.5) # outline
		_hand(Color.WHITE, 0.0) # fill
		# knuckle creases + cuff
		draw_line(Vector2(6, 33), Vector2(6, 40), Color("c5d3dc"), 2.0, true)
		draw_line(Vector2(13, 35), Vector2(13, 42), Color("c5d3dc"), 2.0, true)
		draw_line(Vector2(-6, 58), Vector2(22, 58), UI.BLUE, 5.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _hand(c: Color, grow: float) -> void:
		var cap := func(a: Vector2, b: Vector2, r: float):
			draw_line(a, b, c, (r + grow) * 2.0, true)
			draw_circle(a, r + grow, c)
			draw_circle(b, r + grow, c)
		cap.call(Vector2(0, 6), Vector2(0, 30), 6.5) # index finger
		cap.call(Vector2(7, 32), Vector2(7, 40), 5.8) # folded fingers
		cap.call(Vector2(13.5, 34), Vector2(13.5, 42), 5.6)
		cap.call(Vector2(19.5, 37), Vector2(19.5, 44), 5.2)
		cap.call(Vector2(-9, 44), Vector2(-14, 33), 5.5) # thumb
		var palm := StyleBoxFlat.new()
		palm.bg_color = c
		palm.set_corner_radius_all(int(9 + grow))
		draw_style_box(palm, Rect2(Vector2(-11 - grow, 30 - grow), Vector2(36 + grow * 2, 28 + grow * 2)))


class ConnectCard:
	extends PanelContainer
	var want_visible := true
	var user_hidden := false
	var compact := false
	var _full: VBoxContainer
	var _pill: Label
	var _qr: TextureRect
	var _url: Label
	var _others: Label

	func _init() -> void:
		add_theme_stylebox_override("panel", UI.panel_style(UI.WHITE, UI.BLUE, 24, 3))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		add_child(v)
		_full = v
		_pill = UI.label("●  Phone not connected (press Q for QR code)", 18, Color("d9822b"), true)
		add_child(_pill)
		v.add_child(UI.label("Connect your phone", 20, UI.INK_DARK, true, HORIZONTAL_ALIGNMENT_CENTER))
		_qr = TextureRect.new()
		_qr.custom_minimum_size = Vector2(190, 190)
		_qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(_qr)
		_url = UI.label("", 17, UI.BLUE_DARK, true, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(_url)
		v.add_child(UI.label("Same Wi-Fi · scan with camera\nOn the warning page: Show Details →\nvisit this website", 14, UI.INK, false, HORIZONTAL_ALIGNMENT_CENTER))
		_others = UI.label("", 13, UI.INK_SOFT, false, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(_others)

	func set_qr(img: Image, url: String, others: PackedStringArray) -> void:
		_qr.texture = ImageTexture.create_from_image(img)
		_url.text = url
		_others.text = "" if others.is_empty() else "Not working? Tab: " + ", ".join(others)

	func _process(_d: float) -> void:
		visible = want_visible and (not user_hidden or compact)
		_full.visible = not compact
		_pill.visible = compact
		if compact and user_hidden:
			_full.visible = true
			_pill.visible = false
		reset_size()
		var vs := get_viewport().get_visible_rect().size
		position = Vector2(vs.x - size.x - 24, vs.y - size.y - 24)
