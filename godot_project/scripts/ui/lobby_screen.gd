class_name LobbyScreen
extends Screen
## Players join by scanning the same QR code; each phone becomes a player.
## "Add guest" adds another player who shares the phone that pressed it.

var roster: Players
var qr: Texture2D
var url := ""
var start_btn: PillButton
var guest_btn: PillButton
var back_btn: PillButton
var sport := "Bowling"


func _init() -> void:
	super()
	phone_hint = "Type your name above · press A on Start when everyone has joined"
	start_btn = PillButton.new("Start", Vector2(260, 84))
	start_btn.font_size = 36
	start_btn.pressed.connect(func(): done.emit("start"))
	add_child(start_btn)
	guest_btn = PillButton.new("+ Add guest", Vector2(250, 70))
	guest_btn.font_size = 26
	guest_btn.pressed.connect(func(): roster.add_guest(roster.active_pid))
	add_child(guest_btn)
	back_btn = PillButton.new("Back", Vector2(170, 66))
	back_btn.font_size = 26
	back_btn.pressed.connect(func(): done.emit("back"))
	add_child(back_btn)


func _process(delta: float) -> void:
	super(delta)
	back_btn.position = Vector2(50, size.y - 96)
	start_btn.position = Vector2(size.x - 310, size.y - 104)
	guest_btn.position = Vector2(size.x - 590, size.y - 97)
	guest_btn.enabled = roster.any_connected() and roster.players.size() < Players.MAX_PLAYERS
	start_btn.enabled = not roster.players.is_empty() or not roster.any_connected()


func _draw() -> void:
	draw_stripes()
	var f := UI.bold()
	var reg := UI.regular()
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 100)), UI.WHITE)
	draw_rect(Rect2(Vector2(0, 100), Vector2(size.x, 5)), UI.BLUE)
	draw_string(f, Vector2(50, 66), sport + " · Players", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.INK)
	UI.draw_logo(self, Vector2(size.x - 200, 62), 0.4)

	# join card
	var jc := Rect2(Vector2(50, 130), Vector2(360, 470))
	draw_style_box(UI.panel_style(UI.WHITE, UI.BLUE, 28, 4), jc)
	var t1 := "Join the game"
	draw_string(f, Vector2(jc.get_center().x - f.get_string_size(t1, 0, -1, 30).x * 0.5, jc.position.y + 50), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.INK_DARK)
	if qr:
		draw_texture_rect(qr, Rect2(Vector2(jc.get_center().x - 130, jc.position.y + 70), Vector2(260, 260)), false)
	draw_string(f, Vector2(jc.get_center().x - f.get_string_size(url, 0, -1, 18).x * 0.5, jc.position.y + 360), url, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.BLUE_DARK)
	var lines := ["Everyone scans this same code", "Same Wi-Fi as this computer", "Up to %d players" % Players.MAX_PLAYERS]
	for i in lines.size():
		var l: String = lines[i]
		draw_string(reg, Vector2(jc.get_center().x - reg.get_string_size(l, 0, -1, 19).x * 0.5, jc.position.y + 396 + i * 26), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.INK)

	# player slots 2 x 4
	var gx := 450.0
	var gy := 130.0
	var sw := (size.x - gx - 50 - 20) * 0.5
	var sh := 104.0
	for i in Players.MAX_PLAYERS:
		var col := i % 2
		var row := i / 2
		var r := Rect2(Vector2(gx + col * (sw + 20), gy + row * (sh + 14)), Vector2(sw, sh))
		if i < roster.players.size():
			var p: Players.Player = roster.players[i]
			var on := p.pid == "keyboard" or roster.is_phone_connected(p.pid)
			draw_style_box(UI.panel_style(UI.WHITE, p.color if on else UI.BORDER, 24, 4), r)
			var cc := r.position + Vector2(48, sh * 0.5)
			draw_circle(cc, 30, p.color if on else UI.BORDER)
			var num := str(i + 1)
			draw_string(f, cc + Vector2(-f.get_string_size(num, 0, -1, 30).x * 0.5, 11), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.WHITE)
			draw_string(f, r.position + Vector2(94, 46), p.name, HORIZONTAL_ALIGNMENT_LEFT, sw - 110, 30, UI.INK_DARK)
			var sub := "Keyboard"
			if p.pid != "keyboard":
				if not on:
					sub = "Phone disconnected"
				elif p.guest:
					sub = "Shares %s's phone" % roster.players_of(p.pid)[0].name
				else:
					sub = "Own phone"
				if p.pid == roster.active_pid and roster.any_connected():
					sub += "  ·  controlling"
			draw_string(reg, r.position + Vector2(94, 80), sub, HORIZONTAL_ALIGNMENT_LEFT, sw - 110, 19, UI.INK)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.35)
			sb.border_color = Color("d6d6d6")
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(24)
			draw_style_box(sb, r)
			var wait := "Waiting for player %d…" % (i + 1)
			var a := 0.45 + 0.25 * sin(_t * 2.5 + i * 0.5) if i == roster.players.size() else 0.45
			draw_string(reg, r.position + Vector2((sw - reg.get_string_size(wait, 0, -1, 22).x) * 0.5, sh * 0.5 + 8), wait, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UI.INK_SOFT, a + 0.3))
