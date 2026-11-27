class_name Players
extends Node
## Phones and players.
##
## Every phone scans the same QR code. On connect the page sends "hello" with
## a persistent id (kept in the phone's browser), so a phone that drops out
## and reconnects gets its own slot back. Each phone has its own MotionInput
## (its own calibration). A phone can host extra "guest" players who share it.
##
## Input routing: in menus any phone can drive the pointer (the last one that
## pressed a button takes over). During a turn input is locked to the current
## player's phone.

signal changed
signal phone_button(pid: String, id: String, down: bool)
signal gyro_sample(t_ms: float, rate_x: float, rate_y: float) # active phone only
signal phone_joined(pid: String)
signal phone_left(pid: String)

const MAX_PLAYERS := 8
const COLORS := [
	Color("31b8e8"), Color("ff6b5a"), Color("4cc76a"), Color("ffb020"),
	Color("a77cf0"), Color("ff7fb5"), Color("2fc4b2"), Color("8a6a4f"),
]

var server: ControllerServer
var phones := {} # pid -> Phone
var players: Array[Player] = []
var active_pid := ""
var locked := false
var lobby_open := true # new phones become players while true

var _cid_to_pid := {}


class Phone:
	var pid := ""
	var cid := -1
	var motion: MotionInput
	var calibrated := false

	func connected() -> bool:
		return cid >= 0


class Player:
	var name := ""
	var pid := ""
	var color := Color.WHITE
	var guest := false


func _ready() -> void:
	server.client_connected.connect(func(_cid): pass) # wait for "hello"
	server.client_disconnected.connect(_on_disconnect)


# ------------------------------------------------------------- messages

## Returns true if the message was handled here.
func handle(cid: int, msg: Dictionary) -> bool:
	var t := str(msg.get("type", ""))
	if t == "hello":
		_on_hello(cid, msg)
		return true
	var pid: String = _cid_to_pid.get(cid, "")
	if pid == "":
		return true # ignore phones that have not said hello
	var ph: Phone = phones[pid]
	match t:
		"sensor":
			ph.motion.handle_sensor(msg)
		"btn":
			var id := str(msg.get("id", ""))
			var down := bool(msg.get("down", false))
			phone_button.emit(pid, id, down)
			if not locked and down:
				set_active(pid)
			if pid == active_pid:
				Pad.phone_button(id, down)
		"names":
			var names: Array = msg.get("names", [])
			var mine := players_of(pid)
			for i in mine.size():
				if i < names.size():
					var n := str(names[i]).strip_edges().left(14)
					mine[i].name = n if n != "" else _default_name(mine[i])
			_after_change()
		"hands":
			var left: Array = msg.get("left", [])
			var mine2 := players_of(pid)
			for i in mine2.size():
				if i < left.size():
					mine2[i].set_meta("left", bool(left[i]))
			_after_change()
		"add_guest":
			add_guest(pid)
		"remove_guest":
			remove_player_at(int(msg.get("index", -1)), pid)
		"calibrate":
			if ph.motion.has_data:
				ph.motion.calibrate()
		_:
			return false
	return true


func _on_hello(cid: int, msg: Dictionary) -> void:
	var pid := str(msg.get("pid", "")).left(40)
	if pid == "":
		pid = "cid%d" % cid
	var ph: Phone = phones.get(pid)
	var is_new := ph == null
	if is_new:
		ph = Phone.new()
		ph.pid = pid
		ph.motion = MotionInput.new()
		add_child(ph.motion)
		ph.motion.gyro_sample.connect(func(t, rx, ry):
			if pid == active_pid:
				gyro_sample.emit(t, rx, ry))
		phones[pid] = ph
	elif ph.cid >= 0:
		_cid_to_pid.erase(ph.cid)
	ph.cid = cid
	ph.calibrated = false # every (re)connect must calibrate again
	ph.motion.reset_connection()
	_cid_to_pid[cid] = pid
	if players_of(pid).is_empty() and lobby_open and players.size() < MAX_PLAYERS:
		var p := Player.new()
		p.pid = pid
		p.color = _free_color()
		players.append(p)
		var wanted := str(msg.get("name", "")).strip_edges().left(14)
		p.name = wanted if wanted != "" else _default_name(p)
	if active_pid == "" or not is_phone_connected(active_pid):
		set_active(pid)
	phone_joined.emit(pid)
	_after_change()


func _on_disconnect(cid: int) -> void:
	var pid: String = _cid_to_pid.get(cid, "")
	_cid_to_pid.erase(cid)
	if pid == "" or not phones.has(pid):
		return
	var ph: Phone = phones[pid]
	if ph.cid == cid:
		ph.cid = -1
		ph.motion.reset_connection()
		if pid == active_pid:
			Pad.release_all()
			if not locked:
				var other := first_connected_pid()
				if other != "":
					set_active(other)
		phone_left.emit(pid)
		_after_change()


# --------------------------------------------------------------- players

func add_guest(pid: String) -> void:
	if not lobby_open or players.size() >= MAX_PLAYERS or not phones.has(pid):
		return
	var p := Player.new()
	p.pid = pid
	p.guest = true
	p.color = _free_color()
	# keep a phone's players next to each other
	var insert_at := players.size()
	for i in players.size():
		if players[i].pid == pid:
			insert_at = i + 1
	players.insert(insert_at, p)
	p.name = "Guest %d" % (insert_at + 1)
	_after_change()


func remove_player_at(index: int, pid: String) -> void:
	if not lobby_open:
		return
	var mine := players_of(pid)
	if index <= 0 or index >= mine.size(): # the phone's own player stays
		return
	players.erase(mine[index])
	_after_change()


## Keyboard / mouse play when no phone is connected.
## In the lobby, a phone that leaves takes its players with it.
func prune_disconnected() -> void:
	var keep: Array[Player] = []
	for p in players:
		if p.pid == "keyboard" or is_phone_connected(p.pid):
			keep.append(p)
	if keep.size() != players.size():
		players = keep
		_after_change()


func ensure_keyboard_player() -> void:
	if players.is_empty():
		var p := Player.new()
		p.pid = "keyboard"
		p.color = COLORS[0]
		p.name = "Player 1"
		players.append(p)
		_after_change()


func players_of(pid: String) -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if p.pid == pid:
			out.append(p)
	return out


func index_of(p: Player) -> int:
	return players.find(p)


func is_phone_connected(pid: String) -> bool:
	return phones.has(pid) and (phones[pid] as Phone).connected()


func connected_phones() -> Array[Phone]:
	var out: Array[Phone] = []
	for ph in phones.values():
		if ph.connected():
			out.append(ph)
	return out


func first_connected_pid() -> String:
	# prefer the phone of the first player (the host)
	for p in players:
		if is_phone_connected(p.pid):
			return p.pid
	for ph in phones.values():
		if ph.connected():
			return ph.pid
	return ""


func any_connected() -> bool:
	return first_connected_pid() != ""


func active_motion() -> MotionInput:
	var ph: Phone = phones.get(active_pid)
	return ph.motion if ph else null


func set_active(pid: String) -> void:
	if pid == active_pid:
		return
	Pad.release_all()
	active_pid = pid
	var ph: Phone = phones.get(pid)
	Pad.instance_motion = ph.motion if ph else null


## During a turn only `pid` controls the game (falls back to the host's
## phone if that player's phone is not connected). "" unlocks.
func lock_to(pid: String) -> void:
	if pid == "":
		locked = false
		return
	var target := pid if is_phone_connected(pid) else first_connected_pid()
	if target != "":
		set_active(target)
	locked = true


## Phones that still need the compulsory calibration (players' phones first).
func phones_needing_calibration() -> Array[Phone]:
	var out: Array[Phone] = []
	for p in players:
		var ph: Phone = phones.get(p.pid)
		if ph and ph.connected() and not ph.calibrated and not out.has(ph):
			out.append(ph)
	for ph in phones.values():
		if ph.connected() and not ph.calibrated and not out.has(ph):
			out.append(ph)
	return out


func reset_calibration() -> void:
	for ph in phones.values():
		ph.calibrated = false


func label_for_phone(pid: String) -> String:
	var mine := players_of(pid)
	if mine.is_empty():
		return "Spectator"
	var names: Array[String] = []
	for p in mine:
		names.append(p.name)
	return ", ".join(names)


func send_to_phone(pid: String, data: Dictionary) -> void:
	var ph: Phone = phones.get(pid)
	if ph and ph.connected():
		server.send_to(ph.cid, data)


func refresh() -> void:
	_after_change()


func _after_change() -> void:
	# tell every phone who it is
	for ph in phones.values():
		if not ph.connected():
			continue
		var slots: Array = []
		for p in players_of(ph.pid):
			slots.append({"name": p.name, "num": index_of(p) + 1, "color": p.color.to_html(false), "guest": p.guest,
				"left": p.get_meta("left", false)})
		server.send_to(ph.cid, {"type": "you", "slots": slots, "lobby": lobby_open,
			"can_add": lobby_open and players.size() < MAX_PLAYERS})
	changed.emit()


func _default_name(p: Player) -> String:
	return "Player %d" % (index_of(p) + 1) if index_of(p) >= 0 else "Player %d" % (players.size() + 1)


func _free_color() -> Color:
	for c in COLORS:
		var used := false
		for p in players:
			if p.color == c:
				used = true
		if not used:
			return c
	return COLORS[players.size() % COLORS.size()]
