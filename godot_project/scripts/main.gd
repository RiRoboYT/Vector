extends Node3D
## Entry point: picks the LAN address, creates the TLS certificate, starts the
## controller server and connects phone input -> calibration -> character.

var world: World
var server: ControllerServer
var motion: MotionInput
var hud: Hud

var _ips: PackedStringArray = []
var _ip_index := 0
var _manual := false
var _status_timer := 0.0


func _ready() -> void:
	world = World.new()
	add_child(world)
	motion = MotionInput.new()
	add_child(motion)
	hud = Hud.new()
	add_child(hud)
	server = ControllerServer.new()
	add_child(server)
	server.message_received.connect(_on_message)
	server.controller_connected.connect(_on_connected)
	server.controller_disconnected.connect(_on_disconnected)
	motion.calibrated_changed.connect(func(_c): _send_status())

	_ips = NetUtil.lan_addresses()
	var cert_ips := _ips.duplicate()
	if cert_ips.is_empty():
		hud.set_error("No Wi-Fi / network connection found. Connect to Wi-Fi and restart Vector.")
	cert_ips.append("127.0.0.1")
	var made := CertUtil.load_or_create(cert_ips)
	server.start(made[0], made[1])
	if server.error_text != "":
		hud.set_error(server.error_text)
	_show_qr()
	_maybe_screenshot()


## Test helper: `Vector.exe -- --screenshot=path.png --delay=8` saves a frame.
func _maybe_screenshot() -> void:
	var path := ""
	var delay := 6.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--delay="):
			delay = float(arg.get_slice("=", 1))
		elif arg == "--debug-panel":
			hud.debug_visible = true
	if path == "":
		return
	if OS.get_cmdline_user_args().has("--wait-phone"):
		while not (server.is_controller_connected() and motion.is_calibrated and motion.has_data):
			await get_tree().process_frame
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _show_qr() -> void:
	var ip := "127.0.0.1" if _ips.is_empty() else _ips[_ip_index]
	var url := "https://%s:%d/" % [ip, ControllerServer.HTTPS_PORT]
	server.redirect_host = ip
	var others := PackedStringArray()
	for i in _ips.size():
		if i != _ip_index:
			others.append(_ips[i])
	hud.set_qr(QRCode.encode(url).to_image(8, 2), url, others)


func _on_connected() -> void:
	motion.reset_connection()
	hud.toast("Phone connected!")
	_send_status()


func _on_disconnected() -> void:
	motion.reset_connection()
	hud.toast("Phone disconnected")
	hud.qr_visible = true


func _send_status() -> void:
	server.send_json({"type": "status", "calibrated": motion.is_calibrated,
		"grip": "camera" if motion.grip == MotionInput.Grip.CAMERA else "remote"})


func _on_message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"sensor":
			motion.handle_sensor(msg)
		"calibrate":
			_calibrate()
		"recenter":
			motion.recenter()
			hud.toast("Recentered")


func _calibrate() -> void:
	if not motion.has_data:
		hud.toast("No sensor data yet")
		return
	motion.calibrate()
	hud.qr_visible = false
	hud.toast("Calibrated!")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_calibrate()
			KEY_R:
				motion.recenter()
				hud.toast("Recentered")
			KEY_Q:
				hud.qr_visible = not hud.qr_visible
			KEY_D:
				hud.debug_visible = not hud.debug_visible
			KEY_TAB:
				if _ips.size() > 1:
					_ip_index = (_ip_index + 1) % _ips.size()
					_show_qr()
					hud.qr_visible = true
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_ESCAPE:
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _process(delta: float) -> void:
	var connected := server.is_controller_connected() and motion.has_data
	_manual = not connected
	if _manual:
		var vp := get_viewport()
		var m := vp.get_mouse_position() / vp.get_visible_rect().size
		motion.feed_manual((m.x - 0.5) * 2.0 * deg_to_rad(70.0), -(m.y - 0.5) * 2.0 * deg_to_rad(55.0), delta)

	var ch := world.character
	ch.aim_yaw = motion.yaw
	ch.aim_pitch = motion.pitch
	ch.aim_roll = motion.roll
	ch.swing = motion.swing

	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.1
		var frame_ms := 1000.0 / maxf(1.0, Engine.get_frames_per_second())
		hud.set_status(connected, motion.is_calibrated, motion.latency_ms, frame_ms, motion.packets_per_sec, _manual)
		hud.set_debug(_debug_text(connected))


func _debug_text(connected: bool) -> String:
	var o := motion.raw_orientation
	var a := motion.raw_accel
	return "\n".join([
		"source    %s" % ("phone" if connected else "mouse"),
		"grip      %s" % ("camera (upright)" if motion.grip == MotionInput.Grip.CAMERA else "remote (flat)"),
		"alpha     %7.1f°" % o.x,
		"beta      %7.1f°" % o.y,
		"gamma     %7.1f°" % o.z,
		"accel     %5.2f %5.2f %5.2f m/s²" % [a.x, a.y, a.z],
		"yaw       %7.1f°" % rad_to_deg(motion.yaw),
		"pitch     %7.1f°" % rad_to_deg(motion.pitch),
		"roll      %7.1f°" % rad_to_deg(motion.roll),
		"swing     %5.2f" % motion.swing,
		"fps       %d" % Engine.get_frames_per_second(),
	])
