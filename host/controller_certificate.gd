class_name ControllerCertificate
extends RefCounted
## Read only validity and SubjectPublicKeyInfo from a leaf already parsed by Godot.
## Bounds-checked DER traversal avoids an external certificate parser at runtime.

static func _element(bytes: PackedByteArray, offset: int) -> Dictionary:
	if offset < 0 or offset + 2 > bytes.size():
		return {}
	var tag := int(bytes[offset])
	var length := int(bytes[offset + 1])
	var begin := offset + 2
	if length >= 128:
		var count := length & 127
		if count < 1 or count > 4 or begin + count > bytes.size():
			return {}
		length = 0
		for index: int in range(count):
			length = (length << 8) | bytes[begin + index]
		begin += count
	if begin + length > bytes.size():
		return {}
	return {"tag": tag, "start": offset, "begin": begin, "end": begin + length}

static func _time(bytes: PackedByteArray, entry: Dictionary) -> float:
	var text := bytes.slice(entry.begin, entry.end).get_string_from_ascii()
	if entry.tag == 23 and text.length() == 13:
		var year := int(text.left(2))
		text = ("20" if year < 50 else "19") + text
	if text.length() != 15 or not text.ends_with("Z") or not text.left(14).is_valid_int():
		return -1.0
	var stamp := "%s-%s-%sT%s:%s:%s" % [text.substr(0, 4), text.substr(4, 2), text.substr(6, 2), text.substr(8, 2), text.substr(10, 2), text.substr(12, 2)]
	return float(Time.get_unix_time_from_datetime_string(stamp))

static func inspect(pem: String, key: CryptoKey) -> String:
	var armored := pem.get_slice("-----BEGIN CERTIFICATE-----", 1).get_slice("-----END CERTIFICATE-----", 0)
	var encoded := armored.replace("\n", "").replace("\r", "")
	var der := Marshalls.base64_to_raw(encoded)
	var outer := _element(der, 0)
	if outer.is_empty():
		return "Could not inspect certificate DER"
	var body := _element(der, outer.begin)
	if body.is_empty():
		return "Could not inspect certificate body"
	var fields: Array[Dictionary] = []
	var cursor: int = body.begin
	while cursor < body.end and fields.size() < 8:
		var entry := _element(der, cursor)
		if entry.is_empty() or entry.end > body.end:
			return "Invalid certificate field bounds"
		fields.append(entry)
		cursor = entry.end
	var version_offset := 1 if not fields.is_empty() and fields[0].tag == 160 else 0
	if fields.size() < 6 + version_offset:
		return "Missing certificate validity/public key"
	var validity: Dictionary = fields[3 + version_offset]
	var start := _element(der, validity.begin)
	var finish := _element(der, int(start.get("end", -1)))
	if start.is_empty() or finish.is_empty() or finish.end > validity.end:
		return "Invalid certificate validity"
	var before := _time(der, start)
	var after := _time(der, finish)
	var now := Time.get_unix_time_from_system()
	if before < 0.0 or after < 0.0 or now < before or now >= after:
		return "Certificate is expired, not yet valid, or has unsupported validity; regenerate it and check the host clock"
	var public_info: Dictionary = fields[5 + version_offset]
	var public_key := CryptoKey.new()
	var public_pem := "-----BEGIN PUBLIC KEY-----\n%s\n-----END PUBLIC KEY-----\n" % Marshalls.raw_to_base64(der.slice(public_info.start, public_info.end))
	if public_key.load_from_string(public_pem, true) != OK:
		return "Could not read certificate public key"
	var crypto := Crypto.new()
	var hash := crypto.generate_random_bytes(32)
	var signature := crypto.sign(HashingContext.HASH_SHA256, hash, key)
	if signature.is_empty() or not crypto.verify(HashingContext.HASH_SHA256, hash, signature, public_key):
		return "Certificate and private key do not match"
	return ""
