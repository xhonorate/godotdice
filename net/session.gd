class_name DeepSession
extends Node
## One party, hosted or joined. There is one code path for playing alone and for four.
##
## The host owns the run and is the only machine that runs the rules. Every player action
## arrives as a command; the host applies it, diffs the state, and broadcasts
## `{event, patch, revision}`. While a fight resolves the host advances the simulation on
## a timer paced by each event's duration and broadcasts every step the same way. A guest
## applies patches to its mirror and animates the events. Solo play is the host with no
## transport, so a screen never learns which it is talking to.
##
## Transports are nodes with `send(peer_id, bytes)` and the signals below; ENet for
## development, Steam for release, and whatever a mobile build needs later.

signal lobby_changed(lobby: Dictionary)
signal run_started(state: Dictionary)
signal run_event(event: Dictionary)
signal run_ended(results: Dictionary)
signal status_changed(status: String)
signal refused(error: String)
signal error(message: String)

const Codec = preload("res://net/packet_codec.gd")
const Enet = preload("res://net/enet_transport.gd")
const VERSION: String = "0.1.0"
const DEFAULT_PORT: int = 24567
const MAX_PLAYERS: int = 4
const STEP_FLOOR: float = 0.15

var is_host: bool = true
var local_id: String = "p0"
var status: String = "offline"
var lobby: Dictionary = {"members": {}, "order": [], "mine": "", "host": "p0", "started": false}
var run: Dictionary = {}
var revision: int = 0
var speed: float = 1.0
var paused: bool = false
var transport: Node = null
var saves: DeepSaveStore = null

var _peer_of: Dictionary = {}
var _player_of: Dictionary = {}
var _next_seat: int = 1
var _wait: float = 0.0
var _ended: bool = false

# --- starting out ---------------------------------------------------------------------------

func start_local(member: Dictionary) -> void:
	## Alone: host with nobody to talk to.
	_reset()
	is_host = true
	local_id = "p0"
	lobby.host = local_id
	_add_member(local_id, member)
	_set_status("local")

func host_lan(member: Dictionary, port: int = DEFAULT_PORT) -> Dictionary:
	_reset()
	is_host = true
	local_id = "p0"
	lobby.host = local_id
	_add_member(local_id, member)
	var enet: Node = Enet.new()
	var result: Error = enet.host(port)
	if result != OK:
		enet.queue_free()
		return {"ok": false, "error": "Could not open UDP port %d." % port}
	attach_transport(enet)
	_set_status("hosting")
	return {"ok": true}

func join_lan(address: String, member: Dictionary, port: int = DEFAULT_PORT) -> Dictionary:
	_reset()
	is_host = false
	local_id = ""
	var enet: Node = Enet.new()
	var result: Error = enet.join(address, port)
	if result != OK:
		enet.queue_free()
		return {"ok": false, "error": "Could not reach %s:%d." % [address, port]}
	attach_transport(enet)
	_pending_hello = member.duplicate(true)
	_set_status("connecting")
	return {"ok": true}

var _pending_hello: Dictionary = {}

func attach_transport(node: Node) -> void:
	## Wires any transport that speaks the interface. Tests hand in a loopback.
	if transport != null and is_instance_valid(transport):
		transport.queue_free()
	transport = node
	if node.get_parent() == null:
		add_child(node)
	node.packet_received.connect(_on_packet)
	node.peer_connected.connect(_on_peer_connected)
	node.peer_disconnected.connect(_on_peer_disconnected)
	if node.has_signal("connected"):
		node.connected.connect(_on_connected)
	if node.has_signal("failed"):
		node.failed.connect(func(message: String) -> void:
			error.emit(message)
			_set_status("lost"))

func hello(member: Dictionary) -> void:
	## A guest introduces itself once the transport is up.
	_pending_hello = member.duplicate(true)
	_on_connected()

func _reset() -> void:
	lobby = {"members": {}, "order": [], "mine": DeepContent.starter_mine(), "host": "p0", "started": false}
	run = {}
	revision = 0
	_peer_of = {}
	_player_of = {}
	_next_seat = 1
	_wait = 0.0
	_ended = false
	if transport != null and is_instance_valid(transport):
		transport.queue_free()
	transport = null

func _set_status(value: String) -> void:
	status = value
	status_changed.emit(value)

# --- the lobby ------------------------------------------------------------------------------

func _add_member(id: String, member: Dictionary) -> void:
	var record: Dictionary = {"id": id, "name": str(member.get("name", "Lapidary")), "character": str(member.get("character", DeepContent.starter_character())),
		"rail": member.get("rail", []), "dice": member.get("dice", []), "ready": bool(member.get("ready", false)), "connected": true}
	lobby.members[id] = record
	if not lobby.order.has(id):
		lobby.order.append(id)
	lobby_changed.emit(lobby)

func local_member() -> Dictionary:
	return lobby.members.get(local_id, {})

func update_member(fields: Dictionary) -> void:
	## Character, loadout, name or readiness. Changing anything but readiness clears it.
	if is_host:
		_apply_member(local_id, fields)
	else:
		_send_host({"kind": "member", "fields": fields})

func _apply_member(id: String, fields: Dictionary) -> void:
	var record: Dictionary = lobby.members.get(id, {})
	if record.is_empty():
		return
	for key in ["name", "character", "rail", "dice", "ready"]:
		if fields.has(key):
			record[key] = fields[key]
	if fields.has("character") or fields.has("rail") or fields.has("dice"):
		if not fields.has("ready"):
			record.ready = false
	_broadcast({"kind": "lobby", "lobby": lobby})
	lobby_changed.emit(lobby)

func choose_mine(mine_key: String) -> void:
	if not is_host or DeepContent.mine(mine_key).is_empty():
		return
	lobby.mine = mine_key
	for id in lobby.members:
		lobby.members[id].ready = false
	_broadcast({"kind": "lobby", "lobby": lobby})
	lobby_changed.emit(lobby)

func can_start() -> bool:
	if not is_host or lobby.get("started", false):
		return false
	if lobby.order.is_empty():
		return false
	for id in lobby.order:
		var member: Dictionary = lobby.members[id]
		if bool(member.get("connected", true)) and not bool(member.get("ready", false)) and id != local_id:
			return false
	return true

func start_run(seed_value: int = 0) -> Dictionary:
	if not is_host:
		return {"ok": false, "error": "only the host sets out"}
	if not can_start():
		return {"ok": false, "error": "not everyone is ready"}
	var players: Array = []
	for id in lobby.order:
		var member: Dictionary = lobby.members[id]
		if not bool(member.get("connected", true)):
			continue
		players.append({"id": id, "name": member.name, "character": member.character, "rail": member.get("rail", []), "dice": member.get("dice", [])})
	var config: Dictionary = {"seed": seed_value if seed_value != 0 else randi(), "mine": str(lobby.get("mine", DeepContent.starter_mine())), "players": players}
	run = DeepDescent.new_run(config)
	revision = 1
	_ended = false
	lobby.started = true
	_broadcast({"kind": "start", "state": run, "revision": revision, "lobby": lobby})
	run_started.emit(run)
	_checkpoint()
	return {"ok": true}

func resume_run(saved_run: Dictionary, saved_lobby: Dictionary) -> void:
	## The host reopens a checkpoint. Guests rejoin with hello and receive it whole.
	run = saved_run
	lobby = saved_lobby
	lobby.host = local_id
	revision += 1
	_ended = false
	_broadcast({"kind": "start", "state": run, "revision": revision, "lobby": lobby})
	run_started.emit(run)

func leave_run() -> void:
	run = {}
	lobby.started = false
	for id in lobby.members:
		lobby.members[id].ready = false
	if is_host:
		_broadcast({"kind": "lobby", "lobby": lobby})
	lobby_changed.emit(lobby)

# --- the run ---------------------------------------------------------------------------------

func in_run() -> bool:
	return not run.is_empty()

func local_player() -> Dictionary:
	return DeepDescent.player(run, local_id) if in_run() else {}

func battle() -> Dictionary:
	return DeepDescent.battle(run) if in_run() else {}

func forecast() -> Dictionary:
	var b: Dictionary = battle()
	return DeepBattle.forecast(b, local_id) if not b.is_empty() else {}

func send(cmd: Dictionary) -> void:
	## A command from the local player.
	if not in_run():
		return
	if is_host:
		_apply_command(local_id, cmd)
	else:
		_send_host({"kind": "command", "cmd": cmd})

func _apply_command(player_id: String, cmd: Dictionary) -> void:
	var before: Dictionary = run.duplicate(true)
	var result: Dictionary = {"ok": false, "error": "only the host can abandon the dig"}
	## Only whoever holds the run can call the whole party up.
	if str(cmd.get("kind", "")) != "abandon" or player_id == local_id:
		result = DeepDescent.command(run, player_id, cmd)
	if not bool(result.get("ok", false)):
		var message: String = str(result.get("error", "refused"))
		if player_id == local_id:
			refused.emit(message)
		else:
			_send_peer(str(_peer_of.get(player_id, "")), {"kind": "refused", "error": message})
		return
	_publish(before, result.get("event", {}))
	_wait = 0.0

func _publish(before: Dictionary, event: Dictionary) -> void:
	revision += 1
	var patch: Variant = DeepPatch.diff(before, run)
	_broadcast({"kind": "step", "event": event, "patch": patch, "revision": revision})
	run_event.emit(event)
	_after_change()

func _after_change() -> void:
	if str(run.get("phase", "")) == "over" and not _ended:
		_ended = true
		if saves != null:
			saves.clear_checkpoint()
		run_ended.emit(DeepDescent.results(run))
	elif str(run.get("phase", "")) in ["landing", "tunnels"]:
		_checkpoint()

func _checkpoint() -> void:
	if is_host and saves != null and in_run():
		saves.save_checkpoint(run, lobby)

func tick(delta: float) -> void:
	## The host's clock: one battle step each time the previous event has had its moment.
	if not is_host or paused or not in_run():
		return
	if not DeepDescent.in_battle(run):
		return
	var b: Dictionary = DeepDescent.battle(run)
	if not DeepBattle.has_steps(b):
		return
	_wait -= delta * maxf(0.1, speed)
	if _wait > 0.0:
		return
	var before: Dictionary = run.duplicate(true)
	var event: Dictionary = DeepDescent.step(run)
	if event.is_empty():
		return
	var duration: float = float(event.get("battle", {}).get("duration", 0.4))
	_wait = maxf(STEP_FLOOR, duration)
	_publish(before, event)

func _process(delta: float) -> void:
	tick(delta)

# --- wire ------------------------------------------------------------------------------------

func _broadcast(packet: Dictionary) -> void:
	if transport == null:
		return
	for peer_id in _player_of:
		_send_peer(str(peer_id), packet)

func _send_peer(peer_id: String, packet: Dictionary) -> void:
	if transport == null or peer_id.is_empty():
		return
	var stamped: Dictionary = packet.duplicate()
	stamped.version = VERSION
	var bytes: PackedByteArray = Codec.encode(stamped)
	if bytes.is_empty():
		error.emit("a packet could not be encoded")
		return
	transport.send(peer_id, bytes)

func _send_host(packet: Dictionary) -> void:
	_send_peer(str(_peer_of.get(lobby.get("host", "p0"), "1")), packet)

func _on_connected() -> void:
	if is_host or _pending_hello.is_empty():
		return
	_send_peer("1", {"kind": "hello", "member": _pending_hello})

func _on_peer_connected(peer_id: String) -> void:
	if not is_host:
		_peer_of["p0"] = peer_id

func _on_peer_disconnected(peer_id: String) -> void:
	if is_host:
		var player_id: String = str(_player_of.get(peer_id, ""))
		_player_of.erase(peer_id)
		if not player_id.is_empty():
			_peer_of.erase(player_id)
			if lobby.members.has(player_id):
				lobby.members[player_id].connected = false
			if in_run():
				var before: Dictionary = run.duplicate(true)
				DeepDescent.set_connected(run, player_id, false)
				var b: Dictionary = DeepDescent.battle(run)
				if not b.is_empty() and str(b.phase) == "planning" and DeepBattle.ready_to_resolve(b):
					var opened: Dictionary = DeepBattle.start_resolution(b)
					_publish(before, {"kind": "battle", "battle": opened, "phase": str(run.phase), "depth": int(run.depth)})
			_broadcast({"kind": "lobby", "lobby": lobby})
			lobby_changed.emit(lobby)
	else:
		_set_status("lost")
		error.emit("The host is gone. The run waits at its last landing for the host to reopen it.")

func _on_packet(peer_id: String, bytes: PackedByteArray) -> void:
	var decoded: Dictionary = Codec.decode(bytes)
	if not bool(decoded.get("ok", false)):
		return
	var packet: Dictionary = decoded.packet
	if str(packet.get("version", "")) != VERSION:
		_send_peer(peer_id, {"kind": "refused", "error": "Your build (%s) does not match the host's (%s)." % [str(packet.get("version", "?")), VERSION]})
		return
	if is_host:
		_host_packet(peer_id, packet)
	else:
		_guest_packet(packet)

func _host_packet(peer_id: String, packet: Dictionary) -> void:
	var kind: String = str(packet.get("kind", ""))
	match kind:
		"hello":
			var member: Dictionary = packet.get("member", {})
			var player_id: String = str(member.get("id", ""))
			## A player coming back keeps their seat; a new one takes the next.
			if player_id.is_empty() or not lobby.members.has(player_id) or bool(lobby.members[player_id].get("connected", true)):
				if lobby.order.size() >= MAX_PLAYERS or bool(lobby.get("started", false)):
					_send_peer(peer_id, {"kind": "refused", "error": "The party is full or already underground."})
					return
				player_id = "p%d" % _next_seat
				_next_seat += 1
				_add_member(player_id, member)
			else:
				lobby.members[player_id].connected = true
			_peer_of[player_id] = peer_id
			_player_of[peer_id] = player_id
			if in_run():
				DeepDescent.set_connected(run, player_id, true)
			_send_peer(peer_id, {"kind": "welcome", "player_id": player_id, "lobby": lobby, "state": run, "revision": revision})
			_broadcast({"kind": "lobby", "lobby": lobby})
			lobby_changed.emit(lobby)
		"member":
			var player_id: String = str(_player_of.get(peer_id, ""))
			if not player_id.is_empty():
				_apply_member(player_id, packet.get("fields", {}))
		"command":
			var player_id: String = str(_player_of.get(peer_id, ""))
			if not player_id.is_empty() and in_run():
				_apply_command(player_id, packet.get("cmd", {}))
		"snapshot_please":
			_send_peer(peer_id, {"kind": "snapshot", "state": run, "revision": revision, "lobby": lobby})

func _guest_packet(packet: Dictionary) -> void:
	var kind: String = str(packet.get("kind", ""))
	match kind:
		"welcome":
			local_id = str(packet.get("player_id", ""))
			lobby = packet.get("lobby", lobby)
			_peer_of[str(lobby.get("host", "p0"))] = "1"
			revision = int(packet.get("revision", 0))
			var state: Variant = packet.get("state", {})
			_set_status("joined")
			lobby_changed.emit(lobby)
			if state is Dictionary and not state.is_empty():
				run = state
				_ended = str(run.get("phase", "")) == "over"
				run_started.emit(run)
		"lobby":
			lobby = packet.get("lobby", lobby)
			lobby_changed.emit(lobby)
		"start":
			run = packet.get("state", {})
			lobby = packet.get("lobby", lobby)
			revision = int(packet.get("revision", 0))
			_ended = false
			run_started.emit(run)
		"step":
			var incoming: int = int(packet.get("revision", 0))
			if incoming != revision + 1 and revision != 0:
				## A gap: ask for the whole state rather than guess.
				_send_host({"kind": "snapshot_please"})
			run = DeepPatch.apply(run, packet.get("patch", null))
			revision = incoming
			run_event.emit(packet.get("event", {}))
			if str(run.get("phase", "")) == "over" and not _ended:
				_ended = true
				run_ended.emit(DeepDescent.results(run))
		"snapshot":
			run = packet.get("state", {})
			revision = int(packet.get("revision", 0))
			lobby = packet.get("lobby", lobby)
			run_started.emit(run)
		"refused":
			refused.emit(str(packet.get("error", "refused")))
