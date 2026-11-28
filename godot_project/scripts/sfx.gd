class_name Sfx
extends Node
## The three sounds, synthesised at start-up (no audio files needed):
##   click()    - soft menu "pip"
##   roll       - looping ball rumble, volume/pitch follow ball speed
##   pin_hit()  - hollow wooden "tok", layered for pin crashes

const RATE := 44100

static var _inst: Sfx
var _click: AudioStreamWAV
var _tok: Array[AudioStreamWAV] = []
var _roll: AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _roll_player: AudioStreamPlayer
var _next := 0
var _last_hit_ms := 0
var _hits_this_frame := 0


func _ready() -> void:
	_inst = self
	_click = _make_click()
	for i in 4:
		_tok.append(_make_tok(i))
	_roll = _make_roll()
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_roll_player = AudioStreamPlayer.new()
	_roll_player.stream = _roll
	_roll_player.volume_db = -80
	add_child(_roll_player)


func _process(_d: float) -> void:
	_hits_this_frame = 0


static func click(volume := 1.0, pitch := 1.0) -> void:
	if _inst:
		_inst._play(_inst._click, volume * 0.55, pitch)


## strength: 0..1 (impact speed based)
static func pin_hit(strength: float) -> void:
	if _inst == null or strength < 0.03:
		return
	if _inst._hits_this_frame > 5:
		return
	_inst._hits_this_frame += 1
	var s := _inst._tok[randi() % _inst._tok.size()]
	_inst._play(s, clampf(strength, 0.05, 1.0), randf_range(0.85, 1.2))


## speed in m/s; 0 stops the rumble.
static func roll(speed: float) -> void:
	if _inst == null:
		return
	var p := _inst._roll_player
	if speed <= 0.05:
		p.volume_db = move_toward(p.volume_db, -80, 6)
		if p.volume_db <= -60 and p.playing:
			p.stop()
		return
	if not p.playing:
		p.play()
	p.volume_db = linear_to_db(clampf(speed / 9.0, 0.15, 1.0) * 0.9)
	p.pitch_scale = 0.75 + clampf(speed / 10.0, 0, 1) * 0.45


func _play(s: AudioStream, vol: float, pitch: float) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = linear_to_db(maxf(vol, 0.001))
	p.pitch_scale = pitch
	p.play()


# ------------------------------------------------------------- synthesis

static func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _make_click() -> AudioStreamWAV:
	var n := int(RATE * 0.07)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(2100.0, 1500.0, t / 0.07)
		ph += TAU * f / RATE
		var env := minf(1.0, t / 0.002) * exp(-t * 70.0)
		out[i] = (sin(ph) * 0.8 + sin(ph * 2.0) * 0.15) * env * 0.8
	return _to_wav(out)


static func _make_tok(variant: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + variant
	var n := int(RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	# hollow maple pin: a few inharmonic resonances + a sharp noise click
	var freqs := [rng.randf_range(620, 760), rng.randf_range(1350, 1600), rng.randf_range(2400, 2900), rng.randf_range(3900, 4500)]
	var decays := [28.0, 40.0, 60.0, 90.0]
	var amps := [0.55, 0.35, 0.2, 0.1]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * amps[k] * exp(-t * decays[k])
		v += rng.randf_range(-1, 1) * exp(-t * 300.0) * 0.6
		out[i] = v * minf(1.0, t / 0.0008) * 0.9
	return _to_wav(out)


static func _make_roll() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := RATE # 1 second loop
	var out := PackedFloat32Array()
	out.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1, 1)
		lp1 += (w - lp1) * 0.035 # low rumble
		lp2 += (lp1 - lp2) * 0.08
		var thump := sin(TAU * 52.0 * t) * 0.25 + sin(TAU * 31.0 * t) * 0.15
		var board := 0.5 + 0.5 * sin(TAU * 9.0 * t) # board seams
		out[i] = (lp2 * 9.0 + thump * (0.7 + 0.3 * board))
	# crossfade ends so the loop is seamless
	var fade := 2000
	for i in fade:
		var a := float(i) / fade
		out[i] = out[i] * a + out[n - fade + i] * (1.0 - a)
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	for i in n:
		out[i] = out[i] / peak * 0.8
	return _to_wav(out.slice(0, n - fade), true)
