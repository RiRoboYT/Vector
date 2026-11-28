class_name ReadyScreen
extends Screen
## Before every match: each player holds A on their phone for HOLD_TIME to
## register. Players sharing a phone ready up one after another. The keyboard
## player holds Enter. Continues once everyone is ready.

const HOLD_TIME := 1.0

var roster: Players
var sport := "Bowling"
var _ready_flags: Array[bool] = []
var _holding := {} # pid -> seconds held
var _done_t := -1.0
var _emitted := false


func _init() -> void:
	super()
	wants_pointer = false
	phone_hint = "Hold A to get ready!"


func _ready() -> void:
	_ready_flags.resize(roster.players.size())
	_ready_flags.fill(false)
	roster.phone_button.connect(_on_button)


func _on_button(pid: String, id: String, down: bool) -> void:
	if id != Pad.A:
		return
	if down:
		if _next_unready(pid) >= 0:
			_holding[pid] = 0.0
	else:
		_holding.erase(pid)


func _next_unready(pid: String) -> int:
	for i in roster.players.size():
		if roster.players[i].pid == pid and not _ready_flags[i]:
			return i
	return -1


func _process(delta: float) -> void:
	super(delta)
	# keyboard player: hold Enter
	if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
		if _next_unready("keyboard") >= 0:
			_holding["keyboard"] = float(_holding.get("keyboard", 0.0))
	elif _holding.has("keyboard"):
		_holding.erase("keyboard")
	for pid in _holding.keys():
		_holding[pid] = float(_holding[pid]) + delta
		if float(_holding[pid]) >= HOLD_TIME:
			var i := _next_unready(pid)
			if i >= 0:
				_ready_flags[i] = true
				Sfx.click(1.0, 1.5)
				roster.send_to_phone(pid, {"type": "haptic", "p": "double"})
			_holding.erase(pid) # let go and hold again for the next player on this phone
	if _done_t < 0.0 and not _ready_flags.is_empty() and not _ready_flags.has(false):
		_done_t = _t
		roster.server.broadcast({"type": "hint", "text": "Everyone's ready!"})
	if _done_t >= 0.0 and _t - _done_t > 0.8 and not _emitted:
		_emitted = true
		done.emit("ok")


func _draw() -> void:
	draw_stripes()
	var f := UI.bold()
	var reg := UI.regular()
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 100)), UI.WHITE)
	draw_rect(Rect2(Vector2(0, 100), Vector2(size.x, 5)), UI.BLUE)
	draw_string(f, Vector2(50, 66), sport + " · Get ready", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK)
	UI.draw_logo(self, Vector2(size.x - 200, 62), 0.4)
	var all := _done_t >= 0.0
	var title := "Everyone's ready!" if all else "Everyone: hold A on your phone"
	var tw := f.get_string_size(title, 0, -1, 40).x
	draw_string(f, Vector2(size.x * 0.5 - tw * 0.5, 170), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.BLUE if not all else Color("2fbf5b"))
	var n := roster.players.size()
	var cols := mini(4, maxi(1, n))
	var cw := 260.0
	var ch := 210.0
	var gap := 24.0
	var rows := int(ceil(float(n) / cols))
	var total_w := cols * cw + (cols - 1) * gap
	var x0 := size.x * 0.5 - total_w * 0.5
	var y0 := 220.0 + maxf(0.0, (size.y - 330.0 - rows * (ch + gap)) * 0.5)
	for i in n:
		var p: Players.Player = roster.players[i]
		var r := Rect2(Vector2(x0 + (i % cols) * (cw + gap), y0 + (i / cols) * (ch + gap)), Vector2(cw, ch))
		var ok := i < _ready_flags.size() and _ready_flags[i]
		draw_style_box(UI.panel_style(UI.WHITE, Color("2fbf5b") if ok else p.color, 26, 4), r)
		var c := r.position + Vector2(cw * 0.5, 78)
		# hold progress ring
		var prog := 0.0
		if not ok and _holding.has(p.pid) and _next_unready(p.pid) == i:
			prog = clampf(float(_holding[p.pid]) / HOLD_TIME, 0.0, 1.0)
		draw_circle(c, 44, Color("2fbf5b") if ok else p.color)
		draw_arc(c, 54, 0, TAU, 48, Color(0, 0, 0, 0.08), 8.0, true)
		if prog > 0.0:
			draw_arc(c, 54, -PI * 0.5, -PI * 0.5 + TAU * prog, 48, Color("ffb020"), 8.0, true)
		var mark := "✓" if ok else "A"
		var mw := f.get_string_size(mark, 0, -1, 40).x
		draw_string(f, c + Vector2(-mw * 0.5, 14), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.WHITE)
		var nw := f.get_string_size(p.name, 0, -1, 26).x
		draw_string(f, Vector2(c.x - minf(nw, cw - 30) * 0.5, r.position.y + 162), p.name, HORIZONTAL_ALIGNMENT_LEFT, cw - 30, 26, UI.INK_DARK)
		var sub := "READY" if ok else ("Hold Enter" if p.pid == "keyboard" else "Hold A")
		var sw := reg.get_string_size(sub, 0, -1, 20).x
		draw_string(reg, Vector2(c.x - sw * 0.5, r.position.y + 192), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("2fbf5b") if ok else UI.INK)
