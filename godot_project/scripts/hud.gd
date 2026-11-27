class_name Hud
extends CanvasLayer
## Clean, rounded, Wii-menu-like overlay: status, QR connect card, debug.

const GOOD := Color(0.2, 0.75, 0.35)
const WARN := Color(0.95, 0.65, 0.1)
const BAD := Color(0.9, 0.3, 0.3)
const INK := Color(0.15, 0.18, 0.25)
const SUB := Color(0.4, 0.45, 0.55)

var _conn_dot: Panel
var _conn_lbl: Label
var _cal_dot: Panel
var _cal_lbl: Label
var _lat_lbl: Label
var _rate_lbl: Label
var _qr_card: PanelContainer
var _qr_rect: TextureRect
var _url_lbl: Label
var _other_lbl: Label
var _steps_lbl: Label
var _debug_panel: PanelContainer
var _debug_lbl: Label
var _toast: Label
var _toast_t := 0.0
var _error_lbl: Label

var qr_visible := true
var debug_visible := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- status panel (top-left)
	var status := _card()
	status.position = Vector2(24, 24)
	root.add_child(status)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	status.add_child(sv)
	var title := _label("VECTOR", 30, Color(0.18, 0.5, 1.0))
	sv.add_child(title)
	var r1 := _row()
	_conn_dot = r1[0]
	_conn_lbl = r1[1]
	sv.add_child(r1[2])
	var r2 := _row()
	_cal_dot = r2[0]
	_cal_lbl = r2[1]
	sv.add_child(r2[2])
	_lat_lbl = _label("Latency: –", 16, SUB)
	sv.add_child(_lat_lbl)
	_rate_lbl = _label("Rate: –", 16, SUB)
	sv.add_child(_rate_lbl)

	# ---- QR card (right)
	_qr_card = _card()
	_qr_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.add_child(_qr_card)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 8)
	qv.alignment = BoxContainer.ALIGNMENT_CENTER
	_qr_card.add_child(qv)
	qv.add_child(_label("Connect your phone", 22, INK, true))
	_qr_rect = TextureRect.new()
	_qr_rect.custom_minimum_size = Vector2(230, 230)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qv.add_child(_qr_rect)
	_url_lbl = _label("", 18, Color(0.18, 0.5, 1.0), true)
	qv.add_child(_url_lbl)
	_steps_lbl = _label(
		"1. Phone on the same Wi-Fi\n" +
		"2. Scan with the camera\n" +
		"3. Warning page → Show Details →\n    visit this website (safe, it's your PC)\n" +
		"4. Tap Enable Motion, then Calibrate", 14, SUB)
	qv.add_child(_steps_lbl)
	_other_lbl = _label("", 13, SUB, true)
	qv.add_child(_other_lbl)

	# ---- debug panel (bottom-left)
	_debug_panel = _card()
	_debug_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.add_child(_debug_panel)
	_debug_lbl = _label("", 14, INK)
	_debug_lbl.add_theme_font_override("font", _mono())
	_debug_panel.add_child(_debug_lbl)
	_debug_panel.visible = debug_visible

	# ---- hints (bottom-center)
	var hint := _label("C  calibrate     R  recenter     Q  QR code     D  debug     Tab  network     F11  fullscreen", 14, Color(1, 1, 1, 0.9), true)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 34
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(hint)

	# ---- toast (center)
	_toast = _label("", 40, Color.WHITE, true)
	_toast.add_theme_color_override("font_outline_color", Color(0.15, 0.4, 0.9))
	_toast.add_theme_constant_override("outline_size", 12)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 90
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_error_lbl = _label("", 18, BAD, true)
	_error_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_error_lbl.position.y = 24
	_error_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_error_lbl)

	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_qr_card.reset_size()
	_qr_card.position = Vector2(vs.x - _qr_card.size.x - 24, 24)
	_debug_panel.reset_size()
	_debug_panel.position = Vector2(24, vs.y - _debug_panel.size.y - 70)


func set_qr(img: Image, url: String, others: PackedStringArray) -> void:
	_qr_rect.texture = ImageTexture.create_from_image(img)
	_url_lbl.text = url
	_other_lbl.text = "" if others.is_empty() else "Not working? Press Tab to try: " + ", ".join(others)
	_layout.call_deferred()


func set_error(text: String) -> void:
	_error_lbl.text = text


## latency_ms = network one-way estimate, frame_ms = time until it is drawn.
func set_status(connected: bool, calibrated: bool, latency_ms: float, frame_ms: float, rate: float, manual: bool) -> void:
	_dot(_conn_dot, GOOD if connected else (WARN if manual else BAD))
	_conn_lbl.text = "Phone connected" if connected else ("Mouse mode (no phone)" if manual else "Waiting for phone…")
	_dot(_cal_dot, GOOD if calibrated else WARN)
	_cal_lbl.text = "Calibrated" if calibrated else "Not calibrated"
	if connected and latency_ms >= 0.0:
		var total := latency_ms + frame_ms
		_lat_lbl.text = "Latency: %d ms  (Wi-Fi %d + frame %d)" % [roundi(total), roundi(latency_ms), roundi(frame_ms)]
		_lat_lbl.add_theme_color_override("font_color", GOOD if total < 40.0 else (WARN if total < 80.0 else BAD))
	else:
		_lat_lbl.text = "Latency: –"
		_lat_lbl.add_theme_color_override("font_color", SUB)
	_rate_lbl.text = "Rate: %d Hz" % roundi(rate) if connected else "Rate: –"
	_qr_card.visible = qr_visible


func set_debug(text: String) -> void:
	_debug_panel.visible = debug_visible
	if debug_visible:
		_debug_lbl.text = text
		_layout()


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 1.6


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
		_toast.scale = Vector2.ONE * (1.0 + maxf(0.0, _toast_t - 1.4) * 0.6)


# ---------------------------------------------------------------- widgets

func _card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.93)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0.1, 0.2, 0.4, 0.18)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	sb.border_color = Color(0.75, 0.85, 1.0)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _row() -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var l := _label("", 18, INK)
	h.add_child(l)
	return [dot, l, h]


func _dot(p: Panel, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(7)
	p.add_theme_stylebox_override("panel", sb)


func _mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "monospace"])
	return f
