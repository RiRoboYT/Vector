class_name QRCode
extends RefCounted
## Minimal QR Code encoder (byte mode, error correction level M, versions 1-10).
## Algorithm follows the ISO/IEC 18004 reference structure (as in Nayuki's
## public-domain implementation). Enough for "https://192.168.x.x:8443/".

const ECC_PER_BLOCK_M := [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26]
const BLOCKS_M := [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5]
const MASK := 0
const ECL_FORMAT_M := 0

var size := 0
var modules: Array = [] # modules[y][x] -> bool (true = dark)
var _func: Array = []


## Returns a QRCode or null if the text is too long.
static func encode(text: String) -> QRCode:
	var data := text.to_utf8_buffer()
	for ver in range(1, 11):
		var cap := _data_codewords(ver)
		if 4 + 8 + data.size() * 8 <= cap * 8:
			var q := QRCode.new()
			q._build(ver, data)
			return q
	return null


## Renders to an Image with a quiet zone, `scale` pixels per module.
func to_image(scale: int = 8, border: int = 4) -> Image:
	var px := (size + border * 2) * scale
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in size:
		for x in size:
			if modules[y][x]:
				img.fill_rect(Rect2i((x + border) * scale, (y + border) * scale, scale, scale), Color(0.08, 0.1, 0.16))
	return img


func _build(ver: int, data: PackedByteArray) -> void:
	size = ver * 4 + 17
	modules = []
	_func = []
	for y in size:
		var row := []
		var frow := []
		row.resize(size)
		frow.resize(size)
		row.fill(false)
		frow.fill(false)
		modules.append(row)
		_func.append(frow)

	# --- function patterns
	for i in size:
		_set_func(6, i, i % 2 == 0)
		_set_func(i, 6, i % 2 == 0)
	_finder(3, 3)
	_finder(size - 4, 3)
	_finder(3, size - 4)
	var align := _alignment_positions(ver)
	var n := align.size()
	for i in n:
		for j in n:
			if (i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0):
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					_set_func(align[i] + dx, align[j] + dy, maxi(absi(dx), absi(dy)) != 1)
	_format_bits()
	_version_bits(ver)

	# --- data bits
	var bits: Array[int] = []
	_append_bits(bits, 0x4, 4)
	_append_bits(bits, data.size(), 8 if ver <= 9 else 16)
	for b in data:
		_append_bits(bits, b, 8)
	var cap_bits := _data_codewords(ver) * 8
	_append_bits(bits, 0, mini(4, cap_bits - bits.size()))
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var pad := 0xEC
	while bits.size() < cap_bits:
		_append_bits(bits, pad, 8)
		pad = 0x11 if pad == 0xEC else 0xEC
	var codewords := PackedByteArray()
	codewords.resize(bits.size() / 8)
	for i in bits.size():
		codewords[i >> 3] |= bits[i] << (7 - (i & 7))

	# --- error correction + interleave
	var all := _add_ecc(ver, codewords)

	# --- place codewords (zig-zag)
	var idx := 0
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := size - 1 - vert if upward else vert
				if not _func[y][x] and idx < all.size() * 8:
					modules[y][x] = ((all[idx >> 3] >> (7 - (idx & 7))) & 1) == 1
					idx += 1
		right -= 2

	# --- mask
	for y in size:
		for x in size:
			if not _func[y][x] and (x + y) % 2 == 0:
				modules[y][x] = not modules[y][x]
	_format_bits()


func _set_func(x: int, y: int, dark: bool) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	modules[y][x] = dark
	_func[y][x] = true


func _finder(cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var d := maxi(absi(dx), absi(dy))
			_set_func(cx + dx, cy + dy, d != 2 and d != 4)


func _format_bits() -> void:
	var data := (ECL_FORMAT_M << 3) | MASK
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in range(0, 6):
		_set_func(8, i, _bit(bits, i))
	_set_func(8, 7, _bit(bits, 6))
	_set_func(8, 8, _bit(bits, 7))
	_set_func(7, 8, _bit(bits, 8))
	for i in range(9, 15):
		_set_func(14 - i, 8, _bit(bits, i))
	for i in range(0, 8):
		_set_func(size - 1 - i, 8, _bit(bits, i))
	for i in range(8, 15):
		_set_func(8, size - 15 + i, _bit(bits, i))
	_set_func(8, size - 8, true)


func _version_bits(ver: int) -> void:
	if ver < 7:
		return
	var rem := ver
	for i in 12:
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	var bits := (ver << 12) | rem
	for i in 18:
		var b := _bit(bits, i)
		var a := size - 11 + i % 3
		var c := i / 3
		_set_func(a, c, b)
		_set_func(c, a, b)


static func _bit(v: int, i: int) -> bool:
	return ((v >> i) & 1) != 0


static func _append_bits(bits: Array[int], val: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((val >> i) & 1)


static func _alignment_positions(ver: int) -> Array[int]:
	var out: Array[int] = []
	if ver == 1:
		return out
	var num := ver / 7 + 2
	var sz := ver * 4 + 17
	var step := (ver * 8 + num * 3 + 5) / (num * 4 - 4) * 2
	var pos := sz - 7
	for i in num - 1:
		out.insert(0, pos)
		pos -= step
	out.insert(0, 6)
	return out


static func _raw_modules(ver: int) -> int:
	var r := (16 * ver + 128) * ver + 64
	if ver >= 2:
		var na := ver / 7 + 2
		r -= (25 * na - 10) * na - 55
		if ver >= 7:
			r -= 36
	return r


static func _data_codewords(ver: int) -> int:
	return _raw_modules(ver) / 8 - ECC_PER_BLOCK_M[ver] * BLOCKS_M[ver]


static func _add_ecc(ver: int, data: PackedByteArray) -> PackedByteArray:
	var num_blocks: int = BLOCKS_M[ver]
	var ecc_len: int = ECC_PER_BLOCK_M[ver]
	var raw := _raw_modules(ver) / 8
	var num_short := num_blocks - raw % num_blocks
	var short_len := raw / num_blocks
	var div := _rs_divisor(ecc_len)
	var blocks: Array[PackedByteArray] = []
	var k := 0
	for i in num_blocks:
		var dlen := short_len - ecc_len + (0 if i < num_short else 1)
		var dat := data.slice(k, k + dlen)
		k += dlen
		var ecc := _rs_remainder(dat, div)
		if i < num_short:
			dat.append(0)
		dat.append_array(ecc)
		blocks.append(dat)
	var out := PackedByteArray()
	for i in blocks[0].size():
		for j in blocks.size():
			if i != short_len - ecc_len or j >= num_short:
				out.append(blocks[j][i])
	return out


static func _rs_mul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = ((z << 1) ^ ((z >> 7) * 0x11D)) & 0xFF
		z ^= ((y >> i) & 1) * x
	return z


static func _rs_divisor(degree: int) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(degree)
	r[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			r[j] = _rs_mul(r[j], root)
			if j + 1 < degree:
				r[j] ^= r[j + 1]
		root = _rs_mul(root, 0x02)
	return r


static func _rs_remainder(data: PackedByteArray, div: PackedByteArray) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(div.size())
	for b in data:
		var factor := b ^ r[0]
		r = r.slice(1)
		r.append(0)
		for i in div.size():
			r[i] ^= _rs_mul(div[i], factor)
	return r
