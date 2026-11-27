class_name ControllerServer
extends Node
## One-port HTTPS + secure WebSocket server.
##
## Phones must load the controller over HTTPS (iOS/Android only expose motion
## sensors to secure pages) and an HTTPS page may only open wss:// sockets.
## Serving both on the same port means the phone accepts the certificate
## warning once and the socket just works. A tiny plain-HTTP listener on
## HTTP_PORT redirects anyone who types the address without https://.

## Several phones can be connected at once; each socket has an id (cid).
signal message_received(cid: int, data: Dictionary)
signal client_connected(cid: int)
signal client_disconnected(cid: int)

const HTTPS_PORT := 8443
const HTTP_PORT := 8080
const WS_GUID := "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const PAGE_PATH := "res://web/controller.html"
const HANDSHAKE_TIMEOUT_MS := 10000
const MAX_PHONES := 12

var tls_options: TLSOptions
var page_bytes := PackedByteArray()
var redirect_host := ""
var listening := false
var error_text := ""

var _thread: Thread
var _running := false
var _mutex := Mutex.new()
var _inbox: Array = [] # [cid, Dictionary]
var _events: Array = [] # [cid, "connected" | "disconnected"]
var _outbox: Array = [] # [cid (-1 = everyone), text]
var _connected := {} # cid -> true (main thread view)

var _tls_server := TCPServer.new()
var _http_server := TCPServer.new()
var _clients: Array[Client] = []
var _ws := {} # cid -> Client (network thread)
var _next_cid := 1


class Client:
	var tcp: StreamPeerTCP
	var stream: StreamPeer # StreamPeerTLS or the TCP peer itself
	var tls: StreamPeerTLS
	var buf := PackedByteArray()
	var is_ws := false
	var cid := 0
	var closing := false
	var closing_ms := 0
	var created_ms := 0
	var last_rx_ms := 0


func start(key: CryptoKey, cert: X509Certificate) -> void:
	tls_options = TLSOptions.server(key, cert)
	if FileAccess.file_exists(PAGE_PATH):
		page_bytes = FileAccess.get_file_as_bytes(PAGE_PATH)
	else:
		page_bytes = "<h1>controller.html missing from build</h1>".to_utf8_buffer()
	var err := _tls_server.listen(HTTPS_PORT, "*")
	if err != OK:
		error_text = "Port %d is busy (is Vector already running?)" % HTTPS_PORT
		push_error(error_text)
		return
	listening = true
	_http_server.listen(HTTP_PORT, "*") # optional; ignore failure
	_running = true
	_thread = Thread.new()
	_thread.start(_net_loop)


func _exit_tree() -> void:
	_running = false
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func is_connected_cid(cid: int) -> bool:
	return _connected.has(cid)


func connected_count() -> int:
	return _connected.size()


## Thread-safe: queued and sent by the network thread. cid -1 = all phones.
func send_to(cid: int, data: Dictionary) -> void:
	_mutex.lock()
	_outbox.append([cid, JSON.stringify(data)])
	_mutex.unlock()


func broadcast(data: Dictionary) -> void:
	send_to(-1, data)


## Main thread: deliver everything the network thread received.
func _process(_delta: float) -> void:
	_mutex.lock()
	var events := _events.duplicate()
	var inbox := _inbox.duplicate()
	_events.clear()
	_inbox.clear()
	_mutex.unlock()
	for e in events:
		if e[1] == "connected":
			_connected[e[0]] = true
			client_connected.emit(e[0])
		else:
			_connected.erase(e[0])
			client_disconnected.emit(e[0])
	for m in inbox:
		message_received.emit(m[0], m[1])


# ------------------------------------------------------- network thread
# Runs independently of the frame rate (polls every ~1 ms), so a slow
# frame never delays reading sensor packets or answering latency pings.

func _net_loop() -> void:
	while _running:
		_net_step()
		OS.delay_usec(1000)


func _push_event(cid: int, e: String) -> void:
	_mutex.lock()
	_events.append([cid, e])
	_mutex.unlock()


func _net_step() -> void:
	_mutex.lock()
	var out := _outbox.duplicate()
	_outbox.clear()
	_mutex.unlock()
	for o in out:
		if o[0] == -1:
			for c in _ws.values():
				_ws_send(c, o[1])
		elif _ws.has(o[0]):
			_ws_send(_ws[o[0]], o[1])
	while _tls_server.is_connection_available():
		var tcp := _tls_server.take_connection()
		tcp.set_no_delay(true) # no Nagle: every sensor frame goes out at once
		var c := Client.new()
		c.tcp = tcp
		c.tls = StreamPeerTLS.new()
		c.created_ms = Time.get_ticks_msec()
		if c.tls.accept_stream(tcp, tls_options) == OK:
			c.stream = c.tls
			_clients.append(c)
	while _http_server.is_connection_available():
		var tcp := _http_server.take_connection()
		var c := Client.new()
		c.tcp = tcp
		c.stream = tcp
		c.created_ms = Time.get_ticks_msec()
		_clients.append(c)

	var now := Time.get_ticks_msec()
	for c in _clients.duplicate():
		if not _poll(c, now):
			_drop(c)


func _poll(c: Client, now: int) -> bool:
	if c.tls:
		c.tls.poll()
		var st := c.tls.get_status()
		if st == StreamPeerTLS.STATUS_HANDSHAKING:
			return now - c.created_ms < HANDSHAKE_TIMEOUT_MS
		if st != StreamPeerTLS.STATUS_CONNECTED:
			return false
	else:
		c.tcp.poll()
		if c.tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return false

	var avail := c.stream.get_available_bytes()
	if avail > 0:
		var res := c.stream.get_partial_data(avail)
		if res[0] != OK:
			return false
		c.buf.append_array(res[1])
		c.last_rx_ms = now

	if c.closing:
		# let the browser close first so the response is fully delivered
		return now - c.closing_ms < 3000
	if c.is_ws:
		return _ws_read(c)
	if not c.is_ws and now - c.created_ms > HANDSHAKE_TIMEOUT_MS:
		return false
	return _http_read(c)


func _drop(c: Client) -> void:
	if c.tls:
		c.tls.disconnect_from_stream()
	c.tcp.disconnect_from_host()
	_clients.erase(c)
	if c.is_ws and _ws.get(c.cid) == c:
		_ws.erase(c.cid)
		_push_event(c.cid, "disconnected")


# ------------------------------------------------------------------- HTTP

func _http_read(c: Client) -> bool:
	var text := c.buf.get_string_from_ascii()
	var end := text.find("\r\n\r\n")
	if end == -1:
		return c.buf.size() < 16384
	var lines := text.substr(0, end).split("\r\n")
	var request := lines[0].split(" ")
	var headers := {}
	for i in range(1, lines.size()):
		var idx := lines[i].find(":")
		if idx > 0:
			headers[lines[i].substr(0, idx).strip_edges().to_lower()] = lines[i].substr(idx + 1).strip_edges()
	c.buf = c.buf.slice(end + 4)
	var path := request[1] if request.size() > 1 else "/"

	if c.tls == null: # plain HTTP: send them to the secure page
		var host := str(headers.get("host", redirect_host)).split(":")[0]
		_http_respond(c, "301 Moved Permanently", "text/plain", PackedByteArray(),
			"Location: https://%s:%d/\r\n" % [host, HTTPS_PORT])
		c.closing = true
		c.closing_ms = Time.get_ticks_msec()
		return true

	if str(headers.get("upgrade", "")).to_lower() == "websocket":
		var key := str(headers.get("sec-websocket-key", ""))
		var hc := HashingContext.new()
		hc.start(HashingContext.HASH_SHA1)
		hc.update((key + WS_GUID).to_ascii_buffer())
		var accept := Marshalls.raw_to_base64(hc.finish())
		var resp := "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n" % accept
		if _ws.size() >= MAX_PHONES:
			c.stream.put_data("HTTP/1.1 503 Busy\r\nContent-Length: 0\r\n\r\n".to_ascii_buffer())
			return false
		c.stream.put_data(resp.to_ascii_buffer())
		c.is_ws = true
		c.cid = _next_cid
		_next_cid += 1
		_ws[c.cid] = c
		_push_event(c.cid, "connected")
		return _ws_read(c)

	if path == "/" or path.begins_with("/?") or path == "/index.html":
		_http_respond(c, "200 OK", "text/html; charset=utf-8", page_bytes, "Cache-Control: no-store\r\n")
	elif path == "/favicon.ico":
		_http_respond(c, "204 No Content", "text/plain", PackedByteArray())
	else:
		_http_respond(c, "404 Not Found", "text/plain", "Not found".to_utf8_buffer())
	c.closing = true
	c.closing_ms = Time.get_ticks_msec()
	return true


func _http_respond(c: Client, status: String, ctype: String, body: PackedByteArray, extra := "") -> void:
	var head := "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n%s\r\n" % [status, ctype, body.size(), extra]
	var out := head.to_ascii_buffer()
	out.append_array(body)
	c.stream.put_data(out)
	if c.tls:
		c.tls.poll()


# -------------------------------------------------------------- WebSocket

func _ws_read(c: Client) -> bool:
	while c.buf.size() >= 2:
		var b0: int = c.buf[0]
		var b1: int = c.buf[1]
		var opcode := b0 & 0x0F
		var masked := (b1 & 0x80) != 0
		var length := b1 & 0x7F
		var pos := 2
		if length == 126:
			if c.buf.size() < 4:
				return true
			length = (c.buf[2] << 8) | c.buf[3]
			pos = 4
		elif length == 127:
			if c.buf.size() < 10:
				return true
			length = 0
			for i in 8:
				length = (length << 8) | c.buf[2 + i]
			pos = 10
		if length > 1 << 20:
			return false
		var mask := PackedByteArray()
		if masked:
			if c.buf.size() < pos + 4:
				return true
			mask = c.buf.slice(pos, pos + 4)
			pos += 4
		if c.buf.size() < pos + length:
			return true
		var payload := c.buf.slice(pos, pos + length)
		c.buf = c.buf.slice(pos + length)
		if masked:
			for i in payload.size():
				payload[i] = payload[i] ^ mask[i & 3]
		match opcode:
			0x1, 0x0:
				var parsed = JSON.parse_string(payload.get_string_from_utf8())
				if parsed is Dictionary:
					if parsed.get("type") == "ping":
						# answered right here for an honest network measurement
						_ws_send(c, JSON.stringify({"type": "pong", "t": parsed.get("t", 0)}))
					else:
						_mutex.lock()
						_inbox.append([c.cid, parsed])
						_mutex.unlock()
			0x8:
				_ws_frame(c, 0x8, PackedByteArray())
				return false
			0x9:
				_ws_frame(c, 0xA, payload)
	return true


func _ws_send(c: Client, text: String) -> void:
	_ws_frame(c, 0x1, text.to_utf8_buffer())


func _ws_frame(c: Client, opcode: int, payload: PackedByteArray) -> void:
	var out := PackedByteArray([0x80 | opcode])
	var n := payload.size()
	if n < 126:
		out.append(n)
	elif n < 65536:
		out.append_array([126, n >> 8, n & 0xFF])
	else:
		out.append(127)
		for i in range(7, -1, -1):
			out.append((n >> (i * 8)) & 0xFF)
	out.append_array(payload)
	c.stream.put_data(out)
	if c.tls:
		c.tls.poll()
