class_name CertUtil
extends RefCounted
## Builds an iOS-compatible self-signed TLS certificate.
##
## Godot's Crypto.generate_self_signed_certificate() does not add a
## subjectAltName or extendedKeyUsage, which Apple requires (iOS 13+), so the
## X.509 structure is assembled here by hand (DER) and signed with Crypto.sign().
## Apple rules honoured: RSA >= 2048, SHA-256, SAN with the IPs, EKU serverAuth,
## validity <= 825 days.

const KEY_PATH := "user://vector_tls.key"
const CERT_PATH := "user://vector_tls.crt"
const META_PATH := "user://vector_tls.meta"


## Returns [CryptoKey, X509Certificate]. Re-uses the stored cert when the set of
## IPs has not changed, so the phone does not need to accept a new warning.
static func load_or_create(ips: PackedStringArray) -> Array:
	var meta := ",".join(ips)
	if FileAccess.file_exists(KEY_PATH) and FileAccess.file_exists(CERT_PATH) and FileAccess.file_exists(META_PATH):
		var stored := FileAccess.get_file_as_string(META_PATH)
		var key := CryptoKey.new()
		var cert := X509Certificate.new()
		if stored == meta and key.load(KEY_PATH) == OK and cert.load(CERT_PATH) == OK:
			return [key, cert]
	var made := create(ips)
	(made[0] as CryptoKey).save(KEY_PATH)
	(made[1] as X509Certificate).save(CERT_PATH)
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(meta)
	return made


static func create(ips: PackedStringArray) -> Array:
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var spki := Marshalls.base64_to_raw(_der_pem_body(key.save_to_string(true)))

	var name := _der_seq([_der_set([_der_seq([_der_oid([2, 5, 4, 3]), _der_utf8("Vector Motion Controller")])])])
	var now := int(Time.get_unix_time_from_system())
	var validity := _der_seq([_der_utc(now - 86400), _der_utc(now + 397 * 86400)])
	var alg := _der_seq([_der_oid([1, 2, 840, 113549, 1, 1, 11]), PackedByteArray([0x05, 0x00])])

	var serial := crypto.generate_random_bytes(16)
	serial[0] = (serial[0] & 0x7F) | 0x01

	var san_items: Array[PackedByteArray] = []
	for ip in ips:
		var parts := ip.split(".")
		if parts.size() == 4:
			var raw := PackedByteArray()
			for p in parts:
				raw.append(int(p))
			san_items.append(_der_tlv(0x87, raw)) # [7] iPAddress
	san_items.append(_der_tlv(0x82, "localhost".to_ascii_buffer())) # [2] dNSName

	var exts := _der_seq([
		_der_ext([2, 5, 29, 19], true, _der_seq([])), # basicConstraints CA:FALSE
		_der_ext([2, 5, 29, 15], true, PackedByteArray([0x03, 0x02, 0x05, 0xA0])), # keyUsage digSig+keyEnc
		_der_ext([2, 5, 29, 37], false, _der_seq([_der_oid([1, 3, 6, 1, 5, 5, 7, 3, 1])])), # EKU serverAuth
		_der_ext([2, 5, 29, 17], false, _der_seq(san_items)), # subjectAltName
	])

	var tbs := _der_seq([
		_der_tlv(0xA0, _der_int(PackedByteArray([2]))), # version v3
		_der_int(serial),
		alg,
		name,
		validity,
		name,
		spki,
		_der_tlv(0xA3, exts),
	])

	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(tbs)
	var sig := crypto.sign(HashingContext.HASH_SHA256, hc.finish(), key)
	var bits := PackedByteArray([0])
	bits.append_array(sig)
	var der := _der_seq([tbs, alg, _der_tlv(0x03, bits)])

	var b64 := Marshalls.raw_to_base64(der)
	var pem := "-----BEGIN CERTIFICATE-----\n"
	for i in range(0, b64.length(), 64):
		pem += b64.substr(i, 64) + "\n"
	pem += "-----END CERTIFICATE-----\n"
	var cert := X509Certificate.new()
	var err := cert.load_from_string(pem)
	if err != OK:
		push_error("Certificate build failed: %d" % err)
	return [key, cert]


# ---------------------------------------------------------------- DER helpers

static func _der_pem_body(pem: String) -> String:
	var out := ""
	for line in pem.split("\n"):
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("-----"):
			continue
		out += line
	return out


static func _der_len(n: int) -> PackedByteArray:
	if n < 0x80:
		return PackedByteArray([n])
	var bytes := PackedByteArray()
	while n > 0:
		bytes.insert(0, n & 0xFF)
		n >>= 8
	bytes.insert(0, 0x80 | bytes.size())
	return bytes


static func _der_tlv(tag: int, content: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([tag])
	out.append_array(_der_len(content.size()))
	out.append_array(content)
	return out


static func _der_seq(items: Array) -> PackedByteArray:
	var body := PackedByteArray()
	for it in items:
		body.append_array(it)
	return _der_tlv(0x30, body)


static func _der_set(items: Array) -> PackedByteArray:
	var body := PackedByteArray()
	for it in items:
		body.append_array(it)
	return _der_tlv(0x31, body)


static func _der_int(raw: PackedByteArray) -> PackedByteArray:
	var b := raw.duplicate()
	if b.size() > 0 and (b[0] & 0x80) != 0:
		b.insert(0, 0)
	return _der_tlv(0x02, b)


static func _der_utf8(s: String) -> PackedByteArray:
	return _der_tlv(0x0C, s.to_utf8_buffer())


static func _der_oid(arcs: Array) -> PackedByteArray:
	var body := PackedByteArray([arcs[0] * 40 + arcs[1]])
	for i in range(2, arcs.size()):
		var v: int = arcs[i]
		var chunk := PackedByteArray([v & 0x7F])
		v >>= 7
		while v > 0:
			chunk.insert(0, 0x80 | (v & 0x7F))
			v >>= 7
		body.append_array(chunk)
	return _der_tlv(0x06, body)


static func _der_utc(unix: int) -> PackedByteArray:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	var s := "%02d%02d%02d%02d%02d%02dZ" % [d.year % 100, d.month, d.day, d.hour, d.minute, d.second]
	return _der_tlv(0x17, s.to_ascii_buffer())


static func _der_ext(oid: Array, critical: bool, value: PackedByteArray) -> PackedByteArray:
	var items := [_der_oid(oid)]
	if critical:
		items.append(PackedByteArray([0x01, 0x01, 0xFF]))
	items.append(_der_tlv(0x04, value))
	return _der_seq(items)
