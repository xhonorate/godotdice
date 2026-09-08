class_name PacketCodec
extends RefCounted

## All gameplay uses bounded UTF-8 JSON. No object deserialization is allowed.
const PROTOCOL_VERSION := 1
const BUILD_VERSION := "1.0.0"
const CONTENT_VERSION := "1.0.0"
const MAX_PACKET_BYTES := 1024 * 1024
const MAX_COMMAND_BYTES := 16 * 1024
const MAX_DEPTH := 32
const MAX_NODES := 100000

static func encode(packet: Dictionary) -> PackedByteArray:
	if not _valid_tree(packet, 0, [0]):
		return PackedByteArray()
	var bytes := JSON.stringify(packet).to_utf8_buffer()
	return bytes if bytes.size() <= MAX_PACKET_BYTES else PackedByteArray()

static func decode(bytes: PackedByteArray, max_bytes: int = MAX_PACKET_BYTES) -> Dictionary:
	if bytes.is_empty() or bytes.size() > max_bytes:
		return {"ok": false, "error": "Packet exceeds the allowed size."}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "Malformed JSON packet."}
	var packet: Dictionary = parser.data
	if not _valid_tree(packet, 0, [0]) or not packet.get("kind", null) is String:
		return {"ok": false, "error": "Invalid packet structure."}
	if packet.kind == "command" and bytes.size() > MAX_COMMAND_BYTES:
		return {"ok": false, "error": "Command exceeds the allowed size."}
	return {"ok": true, "packet": packet}

static func versions_match(packet: Dictionary) -> bool:
	return packet.get("protocol_version") == PROTOCOL_VERSION and packet.get("build_version") == BUILD_VERSION and packet.get("content_version") == CONTENT_VERSION

static func snapshot_hash(state: Dictionary) -> String:
	# JSON parsing represents numbers as floats. Normalize the host's integers
	# through the same JSON boundary before hashing, preserving string IDs/RNGs.
	return JSON.stringify(JSON.parse_string(JSON.stringify(state))).sha256_text()

static func _valid_tree(value: Variant, depth: int, count: Array) -> bool:
	count[0] += 1
	if depth > MAX_DEPTH or count[0] > MAX_NODES:
		return false
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _valid_tree(value[key], depth + 1, count):
				return false
	elif value is Array:
		for item in value:
			if not _valid_tree(item, depth + 1, count):
				return false
	elif value is float:
		return is_finite(value)
	elif not (value == null or value is String or value is StringName or value is bool or value is int):
		return false
	return true
