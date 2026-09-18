class_name GameSession
extends Node

const Codec = preload("res://scripts/services/packet_codec.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Seam = preload("res://scripts/core/seam.gd")
const Enet = preload("res://scripts/services/enet_transport.gd")
const SteamTransport = preload("res://scripts/services/steam_transport.gd")
const RECONNECT_GRACE_SECONDS := 60
const HEARTBEAT_SECONDS := 5
const PEER_TIMEOUT_SECONDS := 20
const SNAPSHOT_CHUNK_BYTES := 32 * 1024
const DIRECT_SNAPSHOT_BYTES := 64 * 1024
const MAX_SNAPSHOT_BYTES := 8 * 1024 * 1024
const ASSEMBLY_TIMEOUT_SECONDS := 15

signal command_received(player_id: String, envelope: Dictionary)
signal command_result(result: Dictionary)
signal snapshot_received(state: Dictionary)
signal lobby_changed(lobby: Dictionary)
signal connection_changed(status: String)
signal error_received(message: String)
signal recovery_required(snapshot: Dictionary)
signal fallback_requested(player_id: String)
signal controller_connection_changed(player_id: String, connected: bool)
signal invite_received(lobby_id: String)
signal party_ping(player_id: String, subject_id: String, label: String)

var local_player_id := "local"
var host_player_id := "local"
var is_host := false
var lobby: Dictionary = {}
var last_snapshot: Dictionary = {}
var session_id := ""
var host_epoch := 1
var status := "idle"
var transport_kind := "offline"
var transport: Node
var reconnect_token := ""
var display_name := "Adventurer"
var _peer_to_player := {}
var _player_to_peer := {}
var _loaded_peers := {}
var _last_seen := {}
var _snapshot_requests := {}
var _rates := {}
var _ping_times := {}
var _assemblies := {}
var _base64_pattern := RegEx.new()
var _sequence := 0
var _heartbeat_elapsed := 0.0
var _connection_started := 0
var _host_peer := "1"
var _last_address := "127.0.0.1"
var _last_port := 24567
var _last_steam_lobby := ""
var _steam: Object
var _steam_ready := false

func _init() -> void:
	_base64_pattern.compile("^[A-Za-z0-9+/]*={0,2}$")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watch_steam_invitations()
	_check_steam_launch.call_deferred()

func _check_steam_launch() -> void:
	var arguments := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == "+connect_lobby" and index + 1 < arguments.size():
			var id := str(arguments[index + 1])
			if id.is_valid_int() and int(id) > 0:
				invite_received.emit(id)
				return

## Invitations accepted in Steam (overlay or friends list) must reach the shop before any
## Steam lobby is opened, and during offline or LAN play, so they bypass the transport.
func _watch_steam_invitations() -> void:
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	if not _steam.has_method("get_steam_init_result") or not _steam.has_signal("join_requested"):
		_steam = null
		return
	_steam_ready = int(_steam.call("get_steam_init_result").get("status", -1)) == 0
	if not _steam.is_connected("join_requested", _on_steam_join_requested):
		_steam.connect("join_requested", _on_steam_join_requested)

func _on_steam_join_requested(lobby_id: int, _friend_id: int) -> void:
	invite_received.emit(str(lobby_id))

func start_offline(player_name: String = "Adventurer", hero_id: String = "ardor") -> void:
	leave()
	transport_kind = "offline"
	is_host = true
	local_player_id = "local"
	host_player_id = local_player_id
	display_name = _safe_name(player_name)
	_open_lobby(hero_id)

func host_enet(player_name: String = "Adventurer", port: int = 24567) -> Dictionary:
	leave()
	transport_kind = "enet"
	is_host = true
	local_player_id = "lan-host"
	host_player_id = local_player_id
	display_name = _safe_name(player_name)
	transport = Enet.new()
	_bind_transport()
	var result: Error = transport.host(port)
	if result != OK:
		return _failure("Could not host LAN game on UDP port %d (error %d)." % [port, result])
	_last_port = port
	_open_lobby()
	return {"ok": true, "port": port}

func join_enet(address: String, player_name: String = "Adventurer", port: int = 24567) -> Dictionary:
	leave()
	transport_kind = "enet"
	is_host = false
	display_name = _safe_name(player_name)
	_last_address = address.strip_edges()
	_last_port = port
	if reconnect_token.is_empty():
		reconnect_token = _load_reconnect_token()
	transport = Enet.new()
	_bind_transport()
	var result: Error = transport.join(_last_address, port)
	if result != OK:
		return _failure("Could not start LAN connection (error %d)." % result)
	_host_peer = "1"
	_connection_started = Time.get_ticks_msec()
	_set_status("connecting")
	return {"ok": true}

func host_steam(player_name: String = "Adventurer") -> Dictionary:
	leave()
	transport_kind = "steam"
	is_host = true
	display_name = _safe_name(player_name)
	var initialized := _create_steam_transport()
	if not initialized.ok:
		return initialized
	local_player_id = transport.local_id
	host_player_id = local_player_id
	_set_status("connecting")
	transport.host()
	return {"ok": true}

func join_steam(id: String, player_name: String = "Adventurer") -> Dictionary:
	leave()
	transport_kind = "steam"
	is_host = false
	display_name = _safe_name(player_name)
	var initialized := _create_steam_transport()
	if not initialized.ok:
		return initialized
	_last_steam_lobby = id
	local_player_id = transport.local_id
	_connection_started = Time.get_ticks_msec()
	_set_status("connecting")
	transport.join(id)
	return {"ok": true}

func _create_steam_transport() -> Dictionary:
	transport = SteamTransport.new()
	_bind_transport()
	var initialized: Dictionary = transport.initialize()
	if not initialized.ok:
		return _failure(initialized.error)
	_steam_ready = _steam != null
	transport.lobby_created.connect(func(id: String):
		_last_steam_lobby = id
		_open_lobby()
		lobby["steam_lobby_id"] = id
		_update_steam_metadata()
		_publish_lobby())
	transport.lobby_entered.connect(func(id: String, host_id: String):
		_last_steam_lobby = id
		_host_peer = host_id
		host_player_id = host_id)
	return initialized

func _bind_transport() -> void:
	add_child(transport)
	transport.packet_received.connect(_on_packet)
	transport.peer_connected.connect(_on_peer_connected)
	transport.peer_disconnected.connect(_on_peer_disconnected)
	transport.connected.connect(_on_connected)
	transport.failed.connect(func(message: String): _failure(message))

func _open_lobby(hero_id: String = "ardor") -> void:
	session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	host_epoch = 1
	lobby = {"session_id": session_id, "host_player_id": host_player_id, "state": "lobby", "transport": transport_kind,
		"members": [_member(local_player_id, display_name, hero_id, 0)], "max_players": 4,
		"mine_id": "", "special_id": "", "modifier": "",
		"protocol_version": Codec.PROTOCOL_VERSION, "build_version": Codec.BUILD_VERSION, "content_version": Codec.CONTENT_VERSION}
	_set_status("lobby")
	_publish_lobby()

func _member(id: String, player_name: String, hero_id: String, seat: int) -> Dictionary:
	return {"id": id, "player_id": id, "name": player_name, "hero_id": hero_id.to_upper(), "seat": seat, "loadout": [],
		"ready": false, "connected": true, "fallback": false, "disconnected_at": 0, "grace_remaining": 0}

func choose_hero(hero_id: String) -> void:
	_lobby_command("ChooseHero", {"hero_id": hero_id})

func set_lobby_ready(ready: bool) -> void:
	_lobby_command("SetLobbyReady", {"ready": ready})

func set_loadout(loadout: Array) -> void:
	## The gems this player socketed at home, so the host can start the run with them.
	_lobby_command("SetLoadout", {"loadout": loadout})

func choose_mine(mine_id: String, special_id: String = "", modifier: String = "") -> void:
	_lobby_command("ChooseMine", {"mine_id": mine_id, "special_id": special_id, "modifier": modifier})

func return_to_lobby() -> void:
	## The host brings a finished expedition's party back to the shop. Nobody is ready yet:
	## everyone has a haul to sort before the next descent.
	if not is_host:
		return
	lobby.state = "lobby"
	for member in lobby.get("members", []):
		member.ready = false
	_set_status("lobby")
	_update_steam_metadata()
	_publish_lobby()

func _lobby_command(type: String, payload: Dictionary) -> void:
	if is_host:
		_apply_lobby_command(local_player_id, type, payload)
	else:
		_send(_host_peer, {"kind": "lobby_command", "session_id": session_id, "command_type": type, "payload": payload})

func _apply_lobby_command(player_id: String, type: String, payload: Dictionary) -> void:
	if lobby.get("state") != "lobby":
		return
	var member := _find_member(player_id)
	if member.is_empty():
		return
	if type == "ChooseHero" and Catalog.definitions("heroes").has(str(payload.get("hero_id", "")).to_upper()):
		member.hero_id = str(payload.hero_id).to_upper()
		member.ready = false
	elif type == "SetLoadout" and payload.get("loadout") is Array:
		# The host checks the shape here and again when the run starts; a bad loadout is ignored.
		if (load("res://scripts/core/run_engine.gd") as GDScript).loadout_error(payload.loadout, str(member.get("hero_id", ""))).is_empty():
			member.loadout = payload.loadout.duplicate(true)
			member.ready = false
	elif type == "ChooseMine" and player_id == host_player_id and not Catalog.mine_definition(str(payload.get("mine_id", ""))).is_empty() and str(payload.get("modifier", "")) in [""] + Seam.MODIFIERS:
		lobby.mine_id = str(payload.mine_id)
		lobby.special_id = str(payload.get("special_id", "")).left(64)
		lobby.modifier = str(payload.get("modifier", ""))
		# The party agreed to a different mine; everyone confirms again.
		for other in lobby.get("members", []):
			other.ready = false
	elif type == "SetLobbyReady" and payload.get("ready") is bool:
		member.ready = payload.ready
	_publish_lobby()

func can_start() -> bool:
	if not is_host or lobby.get("state") != "lobby" or lobby.get("members", []).is_empty():
		return false
	for member in lobby.members:
		if not member.connected or not member.ready:
			return false
	return true

func start_run() -> Array:
	if not can_start():
		error_received.emit("All players must be connected and ready before starting.")
		return []
	lobby.state = "in_run"
	_set_status("in_run")
	_update_steam_metadata()
	_publish_lobby()
	return lobby.members.duplicate(true)

## Called by the original host after loading its canonical checkpoint into a new session.
func restore_party(state: Dictionary) -> Dictionary:
	if not is_host or state.get("host_id", host_player_id) != host_player_id:
		return {"ok": false, "error": "Only the original host can reopen this checkpoint."}
	lobby.members = []
	for hero in state.get("heroes", []):
		var member := _member(str(hero.id), str(hero.get("player_name", hero.get("name", "Adventurer"))), str(hero.get("hero_id", hero.get("key", "ARDOR"))), lobby.members.size())
		member.connected = hero.id == local_player_id
		member.ready = member.connected
		if not member.connected:
			member.disconnected_at = Time.get_ticks_msec()
			member.grace_remaining = RECONNECT_GRACE_SECONDS
		lobby.members.append(member)
		if transport_kind == "steam" and transport != null:
			transport.reserved_members[hero.id] = true
	lobby.state = "in_run"
	host_epoch = int(state.get("host_epoch", 1)) + 1
	last_snapshot = state.duplicate(true)
	_update_pause()
	_publish_lobby()
	return {"ok": true, "session_id": session_id, "host_epoch": host_epoch}

func send_command(envelope: Dictionary) -> void:
	var command := envelope.duplicate(true)
	_sequence = maxi(_sequence, int(last_snapshot.get("accepted_sequences", {}).get(local_player_id, 0)))
	_sequence += 1
	command["protocol_version"] = Codec.PROTOCOL_VERSION
	command["session_id"] = session_id
	command["host_epoch"] = host_epoch
	if not command.has("run_id"):
		command["run_id"] = last_snapshot.get("run_id", "")
	if not command.has("phase_id"):
		command["phase_id"] = last_snapshot.get("phase_id", "")
	if not command.has("base_revision"):
		command["base_revision"] = last_snapshot.get("revision", 0)
	if not command.has("player_sequence"):
		command["player_sequence"] = _sequence
	if not command.has("command_id"):
		command["command_id"] = "%s:%s:%d" % [session_id, local_player_id, _sequence]
	if is_host:
		_accept_command(local_player_id, command)
	else:
		_send(_host_peer, {"kind": "command", "command": command})

func _accept_command(player_id: String, command: Dictionary) -> void:
	if status == "paused" and command.get("command_type") != "ResumeDisconnected":
		reply_command(player_id, {"ok": false, "error": "Waiting for reconnect. After 60 seconds the host can explicitly continue with a fallback."})
		return
	if command.get("session_id") != session_id or command.get("host_epoch", -1) != host_epoch or command.get("protocol_version", -1) != Codec.PROTOCOL_VERSION:
		reply_command(player_id, {"ok": false, "error": "This command belongs to an old or incompatible session."})
		return
	command_received.emit(player_id, command)

func broadcast_snapshot(state: Dictionary) -> void:
	if not is_host:
		return
	last_snapshot = state.duplicate(true)
	_sequence = maxi(_sequence, int(last_snapshot.get("accepted_sequences", {}).get(local_player_id, 0)))
	for peer_id in _peer_to_player:
		_send_snapshot(peer_id)

func _send_snapshot(peer_id: String) -> void:
	if last_snapshot.is_empty():
		return
	var packet := {"kind": "snapshot", "session_id": session_id, "host_epoch": host_epoch,
		"state": last_snapshot, "revision": last_snapshot.get("revision", 0), "hash": Codec.snapshot_hash(last_snapshot)}
	var serialized := JSON.stringify(packet)
	var bytes := serialized.to_utf8_buffer()
	if bytes.size() <= DIRECT_SNAPSHOT_BYTES:
		_send(peer_id, packet)
		return
	if bytes.size() > MAX_SNAPSHOT_BYTES or not Codec._valid_tree(packet, 0, [0]):
		error_received.emit("The run snapshot exceeds the supported size or structure.")
		return
	var digest := serialized.sha256_text()
	var count := ceili(float(bytes.size()) / SNAPSHOT_CHUNK_BYTES)
	var transfer_id := "%s:%s" % [last_snapshot.get("revision", 0), digest.left(24)]
	for index in count:
		var part := bytes.slice(index * SNAPSHOT_CHUNK_BYTES, mini(bytes.size(), (index + 1) * SNAPSHOT_CHUNK_BYTES))
		_send(peer_id, {"kind": "snapshot_chunk", "session_id": session_id, "host_epoch": host_epoch,
			"transfer_id": transfer_id, "index": index, "count": count, "total_bytes": bytes.size(),
			"hash": digest, "data": Marshalls.raw_to_base64(part)})

func reply_command(player_id: String, result: Dictionary) -> void:
	if player_id == local_player_id:
		command_result.emit(result)
	elif _player_to_peer.has(player_id):
		var receipt := result.duplicate(true)
		receipt.erase("state")
		receipt.erase("events")
		_send(_player_to_peer[player_id], {"kind": "result", "session_id": session_id, "result": receipt})

func request_snapshot() -> void:
	if not is_host:
		_send(_host_peer, {"kind": "request_snapshot", "session_id": session_id, "last_revision": last_snapshot.get("revision", -1)})

func send_ping(subject_id: String, label: String) -> void:
	if is_host:
		_relay_ping(local_player_id, subject_id, label)
	else:
		_send(_host_peer, {"kind": "party_ping", "session_id": session_id, "subject_id": subject_id.left(128), "label": label.left(140)})

func _relay_ping(player_id: String, subject_id: String, label: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_ping_times.get(player_id, -1000)) < 750:
		return
	_ping_times[player_id] = now
	var subject := subject_id.left(128)
	var message := label.replace("\n", " ").replace("\r", " ").left(140)
	party_ping.emit(player_id, subject, message)
	for peer_id in _peer_to_player:
		_send(peer_id, {"kind": "party_ping", "session_id": session_id, "player_id": player_id, "subject_id": subject, "label": message})

func _on_connected() -> void:
	if is_host:
		return
	_send(_host_peer, {"kind": "hello", "protocol_version": Codec.PROTOCOL_VERSION,
		"build_version": Codec.BUILD_VERSION, "content_version": Codec.CONTENT_VERSION,
		"name": display_name, "reconnect_token": reconnect_token, "last_revision": last_snapshot.get("revision", -1)})
	_last_seen[_host_peer] = Time.get_ticks_msec()

func _on_peer_connected(peer_id: String) -> void:
	_last_seen[peer_id] = Time.get_ticks_msec()

func _on_packet(peer_id: String, bytes: PackedByteArray) -> void:
	if not _rate_allowed(peer_id):
		return
	var decoded := Codec.decode(bytes)
	if not decoded.ok:
		_reject_peer(peer_id, decoded.error)
		return
	var packet: Dictionary = decoded.packet
	_last_seen[peer_id] = Time.get_ticks_msec()
	if is_host:
		if packet.kind == "hello":
			_handshake(peer_id, packet)
			return
		if not _peer_to_player.has(peer_id):
			return
		var player_id: String = _peer_to_player[peer_id]
		if packet.kind == "command":
			if packet.get("command") is Dictionary and _loaded_peers.get(peer_id, false):
				_accept_command(player_id, packet.command)
		elif packet.get("session_id") != session_id:
			return
		elif packet.kind == "lobby_command" and packet.get("payload") is Dictionary:
			_apply_lobby_command(player_id, str(packet.get("command_type", "")), packet.payload)
		elif packet.kind == "snapshot_ack":
			_loaded_peers[peer_id] = true
		elif packet.kind == "request_snapshot":
			var now := Time.get_ticks_msec()
			if now - int(_snapshot_requests.get(peer_id, -1000)) >= 1000:
				_snapshot_requests[peer_id] = now
				_send_snapshot(peer_id)
		elif packet.kind == "leave":
			_on_peer_disconnected(peer_id)
		elif packet.kind == "party_ping" and packet.get("subject_id") is String and packet.get("label") is String:
			_relay_ping(player_id, packet.subject_id, packet.label)
		elif packet.kind == "ping":
			_send(peer_id, {"kind": "pong", "session_id": session_id})
	else:
		if peer_id != _host_peer:
			return
		if packet.kind == "reject":
			_failure(str(packet.get("error", "Connection rejected.")))
			return
		if packet.kind == "welcome":
			if not packet.get("lobby") is Dictionary or not packet.get("player_id") is String or not packet.get("session_id") is String:
				return
			if not (packet.get("host_epoch") is int or packet.get("host_epoch") is float) or not packet.lobby.get("host_player_id") is String or not packet.lobby.get("state") is String:
				return
			session_id = str(packet.session_id)
			host_epoch = int(packet.host_epoch)
			local_player_id = packet.player_id
			host_player_id = str(packet.lobby.host_player_id)
			lobby = packet.lobby
			_set_status(str(lobby.state))
			lobby_changed.emit(lobby.duplicate(true))
			_send(_host_peer, {"kind": "snapshot_ack", "session_id": session_id, "revision": -1})
			return
		if packet.get("session_id") != session_id:
			return
		match packet.kind:
			"lobby":
				if packet.get("lobby") is Dictionary:
					lobby = packet.lobby
					_set_status(str(packet.get("status", lobby.state)))
					lobby_changed.emit(lobby.duplicate(true))
			"snapshot":
				_receive_snapshot(packet)
			"snapshot_chunk":
				_receive_snapshot_chunk(packet)
			"result":
				if packet.get("result") is Dictionary:
					command_result.emit(packet.result)
			"host_departed":
				_host_lost()
			"party_ping":
				if packet.get("player_id") is String and packet.get("subject_id") is String and packet.get("label") is String and not _find_member(packet.player_id).is_empty():
					party_ping.emit(packet.player_id, packet.subject_id, packet.label)
			"ping":
				_send(_host_peer, {"kind": "pong", "session_id": session_id})

func _handshake(peer_id: String, packet: Dictionary) -> void:
	if not Codec.versions_match(packet):
		_reject_peer(peer_id, "Your build, protocol, or content version does not match the host.")
		return
	var player_id := peer_id
	if transport_kind == "enet":
		var token: String = str(packet.get("reconnect_token", ""))
		if token.length() != 64 or not token.is_valid_hex_number(false):
			_reject_peer(peer_id, "Invalid reconnect identity.")
			return
		player_id = "lan:" + token.sha256_text().left(24)
	var member := _find_member(player_id)
	if member.is_empty():
		if lobby.get("state") != "lobby":
			_reject_peer(peer_id, "This run only accepts reconnecting party members.")
			return
		if lobby.get("members", []).size() >= 4:
			_reject_peer(peer_id, "This party already has four players.")
			return
		member = _member(player_id, _safe_name(str(packet.get("name", "Adventurer"))), "ardor", lobby.members.size())
		lobby.members.append(member)
	elif member.connected and _player_to_peer.has(player_id) and _player_to_peer[player_id] != peer_id:
		_reject_peer(peer_id, "This player already has an active connection.")
		return
	member.connected = true
	member.fallback = false
	member.disconnected_at = 0
	member.grace_remaining = 0
	_peer_to_player[peer_id] = player_id
	_player_to_peer[player_id] = peer_id
	_loaded_peers[peer_id] = false
	if transport_kind == "steam":
		transport.reserved_members[player_id] = true
	_send(peer_id, {"kind": "welcome", "session_id": session_id, "host_epoch": host_epoch, "player_id": player_id, "lobby": lobby})
	_send_snapshot(peer_id)
	controller_connection_changed.emit(player_id, true)
	_update_pause()
	_publish_lobby()

func _receive_snapshot(packet: Dictionary) -> void:
	if not packet.get("state") is Dictionary or packet.get("host_epoch", -1) != host_epoch:
		return
	var state: Dictionary = packet.state
	if not (state.get("revision") is int or state.get("revision") is float) or not state.get("run_id") is String:
		return
	if int(state.get("revision", -1)) < int(last_snapshot.get("revision", -1)) and state.get("run_id") == last_snapshot.get("run_id"):
		return
	if Codec.snapshot_hash(state) != packet.get("hash", ""):
		error_received.emit("Snapshot verification failed. Requesting a fresh copy.")
		request_snapshot()
		return
	last_snapshot = state.duplicate(true)
	_sequence = maxi(_sequence, int(last_snapshot.get("accepted_sequences", {}).get(local_player_id, 0)))
	snapshot_received.emit(last_snapshot.duplicate(true))
	_send(_host_peer, {"kind": "snapshot_ack", "session_id": session_id, "revision": state.get("revision", 0)})

func _receive_snapshot_chunk(packet: Dictionary) -> void:
	if packet.get("host_epoch") != host_epoch or not packet.get("transfer_id") is String or packet.transfer_id.length() > 80:
		return
	if not packet.get("hash") is String or packet.hash.length() != 64 or not packet.get("data") is String:
		return
	for field in ["index", "count", "total_bytes"]:
		var value: Variant = packet.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)):
			return
	var count := int(packet.count)
	var total_bytes := int(packet.total_bytes)
	var index := int(packet.index)
	if total_bytes < 1 or total_bytes > MAX_SNAPSHOT_BYTES or count != ceili(float(total_bytes) / SNAPSHOT_CHUNK_BYTES) or index < 0 or index >= count:
		return
	if packet.data.length() > 4 * ceili(float(SNAPSHOT_CHUNK_BYTES) / 3) or packet.data.length() % 4 != 0 or _base64_pattern.search(packet.data) == null:
		return
	var part := Marshalls.base64_to_raw(packet.data)
	var expected := mini(SNAPSHOT_CHUNK_BYTES, total_bytes - index * SNAPSHOT_CHUNK_BYTES)
	if part.size() != expected:
		return
	var id: String = packet.transfer_id
	if not _assemblies.has(id):
		if _assemblies.size() >= 2:
			_assemblies.erase(_assemblies.keys()[0])
		_assemblies[id] = {"started": Time.get_ticks_msec(), "count": count, "total_bytes": total_bytes, "hash": packet.hash, "parts": {}}
	var assembly: Dictionary = _assemblies[id]
	if assembly.count != count or assembly.total_bytes != total_bytes or assembly.hash != packet.hash:
		_assemblies.erase(id)
		return
	if assembly.parts.has(index):
		if assembly.parts[index] != part:
			_assemblies.erase(id)
		return
	assembly.parts[index] = part
	if assembly.parts.size() != count:
		return
	var bytes := PackedByteArray()
	for part_index in count:
		bytes.append_array(assembly.parts[part_index])
	_assemblies.erase(id)
	if bytes.get_string_from_utf8().sha256_text() != assembly.hash:
		error_received.emit("Snapshot transfer verification failed. Requesting a fresh copy.")
		request_snapshot()
		return
	var decoded := Codec.decode(bytes, MAX_SNAPSHOT_BYTES)
	if decoded.ok and decoded.packet.kind == "snapshot" and decoded.packet.get("session_id") == session_id:
		_receive_snapshot(decoded.packet)

func _on_peer_disconnected(peer_id: String) -> void:
	_last_seen.erase(peer_id)
	_loaded_peers.erase(peer_id)
	if not is_host:
		if peer_id == _host_peer:
			_host_lost()
		return
	if not _peer_to_player.has(peer_id):
		return
	var player_id: String = _peer_to_player[peer_id]
	_peer_to_player.erase(peer_id)
	_player_to_peer.erase(player_id)
	var member := _find_member(player_id)
	if member.is_empty():
		return
	if lobby.get("state") == "lobby":
		lobby.members.erase(member)
	else:
		member.connected = false
		member.disconnected_at = Time.get_ticks_msec()
		member.grace_remaining = RECONNECT_GRACE_SECONDS
		member.fallback = false
		controller_connection_changed.emit(player_id, false)
	_update_pause()
	_publish_lobby()

func resume_disconnected(player_id: String) -> Dictionary:
	if not is_host:
		return {"ok": false, "error": "Only the host may resume with a fallback."}
	var member := _find_member(player_id)
	if member.is_empty() or member.connected:
		return {"ok": false, "error": "That player is connected."}
	if Time.get_ticks_msec() - int(member.disconnected_at) < RECONNECT_GRACE_SECONDS * 1000:
		return {"ok": false, "error": "The 60-second reconnect grace period is still active."}
	member.fallback = true
	_update_pause()
	_publish_lobby()
	return {"ok": true}

func reconnect() -> Dictionary:
	if transport_kind == "enet":
		return join_enet(_last_address, display_name, _last_port)
	if transport_kind == "steam":
		return join_steam(_last_steam_lobby, display_name)
	return {"ok": false, "error": "There is no online session to reconnect to."}

func _update_pause() -> void:
	if lobby.get("state") != "in_run":
		return
	for member in lobby.members:
		if not member.connected and not member.fallback:
			_set_status("paused")
			return
	_set_status("in_run")

func _host_lost() -> void:
	if status == "recovery":
		return
	_set_status("recovery")
	error_received.emit("The host disconnected. Progress is stopped. The original host can reopen the checkpoint and invite the party to resume.")
	recovery_required.emit(last_snapshot.duplicate(true))

func _process(delta: float) -> void:
	if _steam_ready and not (transport is SteamTransport):
		_steam.call("run_callbacks") # a Steam transport pumps callbacks itself
	if transport == null or status in ["idle", "error", "recovery"]:
		return
	_heartbeat_elapsed += delta
	if _heartbeat_elapsed < HEARTBEAT_SECONDS:
		return
	_heartbeat_elapsed = 0.0
	var now := Time.get_ticks_msec()
	for id in _assemblies.keys():
		if now - int(_assemblies[id].started) > ASSEMBLY_TIMEOUT_SECONDS * 1000:
			_assemblies.erase(id)
			request_snapshot()
	if status == "connecting" and now - _connection_started > 20000 and not is_host:
		_failure("The host did not complete the connection handshake.")
		return
	for peer_id in _last_seen.keys():
		if now - int(_last_seen[peer_id]) > PEER_TIMEOUT_SECONDS * 1000:
			_on_peer_disconnected(peer_id)
		else:
			_send(peer_id, {"kind": "ping", "session_id": session_id})
	if is_host and lobby.get("state") == "in_run":
		var changed := false
		for member in lobby.members:
			if not member.connected and not member.fallback:
				member.grace_remaining = maxi(0, RECONNECT_GRACE_SECONDS - (now - int(member.disconnected_at)) / 1000)
				changed = true
		if changed:
			_publish_lobby()

func invite_friends() -> void:
	if transport_kind == "steam" and transport != null and not transport.invite_friends():
		error_received.emit("The Steam overlay is unavailable, so the invite dialog cannot open. Invite from your Steam friends list (right-click a friend, Invite to Lobby), or restart the game while Steam is running.")

func _publish_lobby() -> void:
	lobby_changed.emit(lobby.duplicate(true))
	if is_host:
		for peer_id in _peer_to_player:
			_send(peer_id, {"kind": "lobby", "session_id": session_id, "lobby": lobby, "status": status})

func _update_steam_metadata() -> void:
	if transport_kind != "steam" or transport == null:
		return
	transport.set_metadata({"protocol_version": Codec.PROTOCOL_VERSION, "build_version": Codec.BUILD_VERSION,
		"content_version": Codec.CONTENT_VERSION, "state": lobby.get("state", "lobby"),
		"host_id": host_player_id, "session_id": session_id, "max_players": 4})
	# Existing seats must be able to rejoin the lobby. The authority's verified
	# handshake rejects new identities after start; Steam membership grants no seat.
	transport.set_joinable(true)

func _send(peer_id: String, packet: Dictionary) -> void:
	if transport == null:
		return
	var bytes := Codec.encode(packet)
	if bytes.is_empty():
		error_received.emit("A network message exceeded the supported size or shape.")
		return
	var result: Error = transport.send(peer_id, bytes)
	if result != OK and status not in ["idle", "recovery"]:
		error_received.emit("A message could not be sent; waiting for connection recovery.")

func _reject_peer(peer_id: String, reason: String) -> void:
	if is_host:
		_send(peer_id, {"kind": "reject", "error": reason})
	else:
		error_received.emit(reason)

func _rate_allowed(peer_id: String) -> bool:
	var second := Time.get_ticks_msec() / 1000
	var rate: Array = _rates.get(peer_id, [second, 0])
	if rate[0] != second:
		rate = [second, 0]
	rate[1] += 1
	_rates[peer_id] = rate
	return rate[1] <= (120 if is_host else 2048)

func _find_member(player_id: String) -> Dictionary:
	for member in lobby.get("members", []):
		if member.player_id == player_id:
			return member
	return {}

func _set_status(value: String) -> void:
	if status != value:
		status = value
		connection_changed.emit(status)

func _failure(message: String) -> Dictionary:
	_set_status("error")
	error_received.emit(message)
	return {"ok": false, "error": message}

func _safe_name(value: String) -> String:
	var cleaned := value.strip_edges().replace("\n", " ").replace("\r", " ").left(32)
	return "Adventurer" if cleaned.is_empty() else cleaned

func _load_reconnect_token() -> String:
	# A client restart must recover its reserved seat. --instance=guest2 provides
	# independent identities for development clients sharing this computer.
	var profile := "default"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--instance="):
			profile = argument.trim_prefix("--instance=").validate_filename().left(48)
	var path := "user://lan_identity_%s.json" % profile
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() <= 1024:
			var saved: Variant = JSON.parse_string(file.get_as_text())
			if saved is Dictionary:
				var value := str(saved.get("token", ""))
				if value.length() == 64 and value.is_valid_hex_number(false):
					return value
	var token := Crypto.new().generate_random_bytes(32).hex_encode()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"token": token}))
		file.flush()
		file.close()
	return token

func leave() -> void:
	if transport != null:
		if is_host:
			for peer_id in _peer_to_player:
				_send(peer_id, {"kind": "host_departed", "session_id": session_id})
		elif not session_id.is_empty():
			_send(_host_peer, {"kind": "leave", "session_id": session_id})
		transport.close()
		transport.queue_free()
		transport = null
	_peer_to_player.clear()
	_player_to_peer.clear()
	_loaded_peers.clear()
	_last_seen.clear()
	_snapshot_requests.clear()
	_rates.clear()
	_ping_times.clear()
	_assemblies.clear()
	lobby.clear()
	session_id = ""
	is_host = false
	_sequence = 0
	_set_status("idle")

func _exit_tree() -> void:
	leave()
	if _steam != null and _steam.is_connected("join_requested", _on_steam_join_requested):
		_steam.disconnect("join_requested", _on_steam_join_requested)
