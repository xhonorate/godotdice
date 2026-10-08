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
## development, Steam for release, and whatever a mobile build needs later. A transport that
## knows who the host is says so in `host_peer_id` (a Steam lobby's owner); otherwise the
## host is peer "1", as ENet numbers it.

signal lobby_changed(lobby: Dictionary)
signal run_started(state: Dictionary)
signal run_event(event: Dictionary)
signal run_ended(results: Dictionary)
signal status_changed(status: String)
signal refused(error: String)
signal error(message: String)
## A Steam invitation accepted in the overlay or the friends list: the lobby to join.
signal invited(lobby_id: String)
## A guest put out of the party: kicked by the host, or the host closed it.
signal removed(message: String)
## A share of a run this lapidary dropped out of and was not back for the end of, held by the
## host until they said hello to it again: the results, and the seat they had in that run.
signal claimed(results: Dictionary, player_id: String)

const Codec = preload("res://net/packet_codec.gd")
const Enet = preload("res://net/enet_transport.gd")
const SteamWire = preload("res://net/steam_transport.gd")
## A party plays one release. The host runs the rules, but every guest draws its own forecast
## and pages from its own copy of the content, and an event or a field one build does not know
## would quietly mean something else to the other. The release is `config/version`, which every
## deploy bumps (docs/RELEASES.md), so two different releases always refuse each other.
static var VERSION: String = str(ProjectSettings.get_setting("application/config/version", "dev"))
const DEFAULT_PORT: int = 24567
const MAX_PLAYERS: int = 4
const STEP_FLOOR: float = 0.15

var is_host: bool = true
var local_id: String = "p0"
var status: String = "offline"
var lobby: Dictionary = {"members": {}, "order": [], "mine": "", "host": "p0", "started": false}
var run: Dictionary = {}
var revision: int = 0
## The fight speed the player chose. The app plays a resolving turn at this time scale, so
## the host's clock (which runs on scaled time) and every animation speed up together.
var speed: float = 1.0
## The host's fight speed, which a guest plays every turn at: the host's clock paces the
## steps, so a guest animating at a speed of its own would run ahead of them or fall behind.
var host_speed: float = 1.0
var paused: bool = false
var transport: Node = null
var saves: DeepSaveStore = null:
	set(value):
		saves = value
		## The shares this host is keeping for absent lapidaries come with the store they are in.
		_held = value.load_held() if value != null else {}
## The Steam lobby's ID while hosting over Steam: what a friend types into Join.
var invite_code: String = ""
## Tests hand in a stand-in for the GodotSteam singleton.
var steam_api: Object = null

var _peer_of: Dictionary = {}
var _player_of: Dictionary = {}
var _next_seat: int = 1
var _wait: float = 0.0
var _ended: bool = false
var _host_peer: String = "1"
## When a guest last asked for the whole state (ticks, ms), or 0 when it is not waiting on one.
var _snapshot_asked: int = 0
const SNAPSHOT_RETRY_MS: int = 3000
## Shares of finished runs kept for lapidaries who were not there for the end, by profile id;
## and which profile each line was last handed its share on, so only that line can say
## it arrived. See `_hold_for_absent`.
var _held: Dictionary = {}
var _handed: Dictionary = {}
const HELD_PER_PROFILE: int = 8

func _ready() -> void:
	_listen_for_invites()

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
		## The workshop is put back as it was rather than left half torn down.
		start_local(member)
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
		## A mistyped address must not leave a workshop with nobody in it.
		start_local(member)
		return {"ok": false, "error": "Could not reach %s:%d." % [address, port]}
	attach_transport(enet)
	_pending_hello = member.duplicate(true)
	_set_status("connecting")
	return {"ok": true}

func host_steam(member: Dictionary) -> Dictionary:
	## A friends-only Steam lobby; the session is hosting once Steam has opened it.
	var wire: Node = SteamWire.new()
	var started: Dictionary = wire.initialize(steam_api)
	if not bool(started.get("ok", false)):
		wire.free()
		return started
	_reset()
	is_host = true
	local_id = "p0"
	lobby.host = local_id
	_add_member(local_id, member)
	attach_transport(wire)
	wire.lobby_created.connect(func(id: String) -> void:
		invite_code = id
		_set_status("hosting"))
	_listen_for_invites()
	_set_status("opening")
	wire.host()
	return {"ok": true}

func join_steam(lobby_id: String, member: Dictionary) -> Dictionary:
	lobby_id = lobby_id.strip_edges()
	if not lobby_id.is_valid_int() or int(lobby_id) <= 0:
		return {"ok": false, "error": "That is not a Steam lobby ID."}
	var wire: Node = SteamWire.new()
	var started: Dictionary = wire.initialize(steam_api)
	if not bool(started.get("ok", false)):
		wire.free()
		return started
	_reset()
	is_host = false
	local_id = ""
	attach_transport(wire)
	_pending_hello = member.duplicate(true)
	_listen_for_invites()
	_set_status("connecting")
	wire.join(lobby_id)
	return {"ok": true}

func reopen(kind: String, port: int = DEFAULT_PORT) -> Dictionary:
	## The host of a party run picked up again from its checkpoint opens a line for the party
	## to come back on. Unlike hosting from the workshop nothing is reset: the run and its seats
	## stay as they are, each lapidary who says hello with their own profile takes their seat
	## again, and nobody new can join a run under way.
	if not is_host or not in_run():
		return {"ok": false, "error": "Only the host of a run can open it to the party."}
	if transport != null:
		return {"ok": false, "error": "The party is already open."}
	if kind == "steam":
		var wire: Node = SteamWire.new()
		var started: Dictionary = wire.initialize(steam_api)
		if not bool(started.get("ok", false)):
			wire.free()
			return started
		attach_transport(wire)
		wire.lobby_created.connect(func(id: String) -> void:
			invite_code = id
			_set_status("hosting"))
		_listen_for_invites()
		_set_status("opening")
		wire.host()
		return {"ok": true}
	var enet: Node = Enet.new()
	if enet.host(port) != OK:
		enet.queue_free()
		return {"ok": false, "error": "Could not open UDP port %d." % port}
	attach_transport(enet)
	_set_status("hosting")
	return {"ok": true}

func away() -> Array:
	## The names of everyone in the run who is not on the line.
	return run.get("players", []).filter(func(p: Dictionary) -> bool: return str(p.get("id", "")) != local_id and not bool(p.get("connected", true))) \
		.map(func(p: Dictionary) -> String: return str(p.get("name", "")))

static func lan_address() -> String:
	## This machine's address on a home or office network: what a friend types into Join.
	for address in IP.get_local_addresses():
		var ip: String = str(address)
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			return ip
		if ip.begins_with("172.") and int(ip.get_slice(".", 1)) >= 16 and int(ip.get_slice(".", 1)) <= 31:
			return ip
	return ""

func invite_friends() -> bool:
	## Steam's invite list, if the overlay is up.
	return transport != null and transport.has_method("invite_friends") and bool(transport.invite_friends())

func _listen_for_invites() -> void:
	var steam: Object = steam_api if steam_api != null else SteamWire.live()
	if steam != null and steam.has_signal("join_requested") and not steam.is_connected("join_requested", _on_steam_invite):
		steam.connect("join_requested", _on_steam_invite)

func _on_steam_invite(lobby_id: int, _friend_id: int) -> void:
	invited.emit(str(lobby_id))

var _pending_hello: Dictionary = {}

func attach_transport(node: Node) -> void:
	## Wires any transport that speaks the interface. Tests hand in a loopback.
	_drop_transport()
	transport = node
	if node.get_parent() == null:
		add_child(node)
	node.packet_received.connect(_on_packet)
	node.peer_connected.connect(_on_peer_connected)
	node.peer_disconnected.connect(_on_peer_disconnected)
	if node.has_signal("connected"):
		node.connected.connect(_on_connected)
	if node.has_signal("failed"):
		## A party that could not be opened or reached: there is nothing to wait in, so the
		## player is put back in a workshop of their own with the reason. A host opening a
		## run it is in keeps the run: only the line is let go.
		node.failed.connect(func(message: String) -> void:
			if is_host and in_run():
				_drop_transport()
				_set_status("local")
				error.emit(message)
				return
			_set_status("lost")
			removed.emit(message))

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
	_host_peer = "1"
	_snapshot_asked = 0
	host_speed = 1.0
	_handed = {}
	invite_code = ""
	_drop_transport()

func _drop_transport() -> void:
	## Closed now, freed later: an old transport must not read the new one's packets.
	if transport != null and is_instance_valid(transport):
		if transport.has_method("close"):
			transport.close()
		transport.queue_free()
	transport = null

func _set_status(value: String) -> void:
	status = value
	status_changed.emit(value)

# --- the lobby ------------------------------------------------------------------------------

func _add_member(id: String, member: Dictionary) -> void:
	## `profile` is the lapidary's own profile id, which is how a player who drops out is
	## known again when they come back: seats are numbered by the host, profiles are not.
	var said: Dictionary = clean_member_fields(member)
	var profile_id: Variant = member.get("id", "")
	var record: Dictionary = {"id": id, "profile": str(profile_id).left(64) if profile_id is String else "", "name": str(said.get("name", DeepProfile.DEFAULT_NAME)),
		"character": str(said.get("character", DeepContent.starter_character())), "rail": said.get("rail", []), "dice": said.get("dice", []),
		"ready": bool(said.get("ready", false)), "connected": true, "last_depth": int(said.get("last_depth", 0)), "last_outcome": str(said.get("last_outcome", "")),
		"gold": int(said.get("gold", 0)), "insured": bool(said.get("insured", false)), "sockets": int(said.get("sockets", DeepProfile.starting_rail_cap()))}
	lobby.members[id] = record
	if not lobby.order.has(id):
		lobby.order.append(id)
	lobby_changed.emit(lobby)

func local_member() -> Dictionary:
	return lobby.members.get(local_id, {})

func _away_seat(profile_id: String) -> String:
	## The seat of a member who plays this profile and is away, or "" for someone new.
	if profile_id.is_empty():
		return ""
	for id in lobby.get("order", []):
		var record: Dictionary = lobby.members.get(id, {})
		if str(record.get("profile", "")) == profile_id and not bool(record.get("connected", true)):
			return str(id)
	return ""

func _forget_member(player_id: String) -> void:
	## Out of the lobby for good: a guest who left, or one who dropped before the party set out.
	var peer_id: String = str(_peer_of.get(player_id, ""))
	_peer_of.erase(player_id)
	if not peer_id.is_empty():
		_player_of.erase(peer_id)
	lobby.members.erase(player_id)
	lobby.order.erase(player_id)

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
	var said: Dictionary = clean_member_fields(fields)
	for key in said:
		record[key] = said[key]
	if said.has("character") or said.has("rail") or said.has("dice"):
		if not said.has("ready"):
			record.ready = false
	_broadcast({"kind": "lobby", "lobby": lobby})
	lobby_changed.emit(lobby)

static func clean_member_fields(fields: Dictionary) -> Dictionary:
	## What a member may say about themselves, in the shapes the lobby keeps it in. A guest's
	## packet is only data: a field of the wrong kind, an unknown lapidary or a stone of no
	## known skill is dropped rather than handed to the rules, where it would fail far from
	## here. Numbers come through JSON as floats and are kept as whole numbers.
	var out: Dictionary = {}
	for key in fields:
		var value: Variant = fields[key]
		match str(key):
			"name":
				if value is String and not value.strip_edges().is_empty():
					out.name = value.strip_edges().left(DeepProfile.NAME_LIMIT)
			"character":
				if value is String and DeepContent.section("characters").has(value):
					out.character = value
			"last_outcome":
				if value is String:
					out.last_outcome = value.left(32)
			"rail":
				if value is Array and value.size() <= 12 and value.all(func(s: Variant) -> bool:
						return s == null or (s is Dictionary and s.get("skill") is String and DeepContent.section("skills").has(s.skill))):
					out.rail = value
			"dice":
				if value is Array and value.size() <= 8 and value.all(func(d: Variant) -> bool:
						return d is Dictionary and d.get("shape") is String and d.get("faces", []) is Array):
					out.dice = value
			"ready", "insured":
				if value is bool:
					out[key] = value
			"last_depth", "gold", "sockets":
				if (value is int or value is float) and is_finite(float(value)):
					out[key] = maxi(0, int(value))
	return out

func choose_mine(mine_key: String) -> void:
	if not is_host or DeepContent.mine(mine_key).is_empty():
		return
	lobby.mine = mine_key
	for id in lobby.members:
		lobby.members[id].ready = false
	_broadcast({"kind": "lobby", "lobby": lobby})
	lobby_changed.emit(lobby)

func kick(player_id: String) -> bool:
	## The host sends a guest home. Only in the workshop: a run underground keeps its party.
	if not is_host or player_id == local_id or in_run() or not lobby.members.has(player_id):
		return false
	var peer_id: String = str(_peer_of.get(player_id, ""))
	_send_peer(peer_id, {"kind": "kicked"})
	_forget_member(player_id)
	if transport != null and transport.has_method("disconnect_peer") and not peer_id.is_empty() and is_inside_tree():
		## A moment's grace so the word that they were kicked reaches them first.
		var wire: Node = transport
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(wire) and wire == transport:
				wire.disconnect_peer(peer_id))
	_broadcast({"kind": "lobby", "lobby": lobby})
	lobby_changed.emit(lobby)
	return true

func in_party() -> bool:
	## Whether there is anyone else at the other end of the wire, or a wire at all.
	return transport != null

func leave_party() -> void:
	## Walking away. A host closing the party tells every guest first, so nobody is left
	## waiting on a host who is not coming back.
	if is_host and transport != null:
		_broadcast({"kind": "closed"})
	elif not is_host and transport != null:
		_send_host({"kind": "leaving"})

func can_start() -> bool:
	if not is_host or lobby.get("started", false):
		return false
	if lobby.order.is_empty():
		return false
	for id in lobby.order:
		var member: Dictionary = lobby.members[id]
		if bool(member.get("connected", true)) and not bool(member.get("ready", false)) and id != local_id:
			return false
	return short_members().is_empty()

func departure_cost(member: Dictionary) -> int:
	## What this member pays at the shaft head for the mine the party is set to go down.
	return DeepEconomy.departure(str(lobby.get("mine", DeepContent.starter_mine())), bool(member.get("insured", false)))

func short_members() -> Array:
	## Everyone going down who cannot pay their own way: each pays from their own purse.
	var out: Array = []
	for id in lobby.order:
		var member: Dictionary = lobby.members.get(id, {})
		if bool(member.get("connected", true)) and int(member.get("gold", 0)) < departure_cost(member):
			out.append(str(id))
	return out

func start_run(seed_value: int = 0) -> Dictionary:
	if not is_host:
		return {"ok": false, "error": "only the host sets out"}
	if not can_start():
		if not short_members().is_empty():
			return {"ok": false, "error": "not everyone can pay the way down"}
		return {"ok": false, "error": "not everyone is ready"}
	var players: Array = []
	for id in lobby.order:
		var member: Dictionary = lobby.members[id]
		if not bool(member.get("connected", true)):
			continue
		players.append({"id": id, "name": member.name, "character": member.character, "rail": member.get("rail", []), "dice": member.get("dice", []),
			"last_depth": int(member.get("last_depth", 0)), "last_outcome": str(member.get("last_outcome", "")),
			"sockets": int(member.get("sockets", DeepProfile.starting_rail_cap())), "insured": bool(member.get("insured", false))})
	var chosen_seed: int = seed_value if seed_value != 0 else randi()
	## Every run its own id, whatever its seed: the fare is charged once per run id and a
	## share of a run is handed over once per run id, so a seed typed in again must not make
	## the second run look like the first (it went down free).
	var run_id: String = "run%08x%06x" % [absi(chosen_seed) & 0xffffffff, randi() & 0xffffff]
	var config: Dictionary = {"seed": chosen_seed, "run_id": run_id, "mine": str(lobby.get("mine", DeepContent.starter_mine())), "players": players}
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
	## Nobody else is on the line yet. Everyone but the host is away until they say hello, so
	## a vote or a stake the checkpoint was waiting on them for goes ahead without them.
	for id in lobby.get("members", {}).keys():
		if str(id) != local_id:
			lobby.members[id].connected = false
			DeepDescent.set_connected(run, str(id), false)
	DeepDescent.settle_absent(run)
	## Seats are numbered on from the ones the run already has, so nobody seated after it can
	## be handed one of theirs.
	for id in lobby.get("order", []):
		var number: String = str(id).trim_prefix("p")
		if number.is_valid_int():
			_next_seat = maxi(_next_seat, int(number) + 1)
	revision += 1
	_ended = false
	_broadcast({"kind": "start", "state": run, "revision": revision, "lobby": lobby})
	run_started.emit(run)

func leave_run() -> void:
	run = {}
	lobby.started = false
	if is_host:
		## A seat was only kept for someone who dropped out so they could come back to the run.
		## The run is over: back in the workshop it would be a seat nobody is sitting in.
		for id in lobby.get("order", []).duplicate():
			if str(id) != local_id and not bool(lobby.members.get(id, {}).get("connected", true)):
				_forget_member(str(id))
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
	var before: Dictionary = run.duplicate(true) if _listening() else {}
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
	if _listening():
		var patch: Variant = DeepPatch.diff(before, run)
		_broadcast({"kind": "step", "event": event, "patch": patch, "revision": revision, "speed": clampf(speed, 1.0, 8.0)})
	run_event.emit(event)
	_after_change()

func _after_change() -> void:
	if str(run.get("phase", "")) == "over" and not _ended:
		_ended = true
		if saves != null:
			saves.clear_checkpoint()
		var results: Dictionary = DeepDescent.results(run)
		_hold_for_absent(results)
		run_ended.emit(results)
	elif str(run.get("phase", "")) in ["landing", "tunnels"]:
		_checkpoint()

func _hold_for_absent(results: Dictionary) -> void:
	## Whoever dropped out and was not back for the end still went through the run with the
	## party, and how it ended is theirs as much as anyone's: the stones they carried (or what
	## salvage left of them), the mines' records, the pocket for the assayer. Their share is
	## kept here, by the profile they play with, and handed over the next time that profile
	## says hello to this host, in the workshop or in another run.
	if not is_host:
		return
	var changed: bool = false
	for unit in run.get("players", []):
		var seat: String = str(unit.get("id", ""))
		if seat == local_id or bool(unit.get("connected", true)):
			continue
		var profile_id: String = str(lobby.get("members", {}).get(seat, {}).get("profile", ""))
		if profile_id.is_empty():
			continue
		var share: Dictionary = results.duplicate(true)
		share.players = {seat: results.get("players", {}).get(seat, {}).duplicate(true)}
		var held: Array = _held.get(profile_id, [])
		held.append({"player_id": seat, "results": share})
		_held[profile_id] = held.slice(maxi(0, held.size() - HELD_PER_PROFILE))
		changed = true
	if changed and saves != null:
		saves.save_held(_held)

func _hand_over(peer_id: String, profile_id: String) -> void:
	## A lapidary the host has been keeping shares for has said hello: hand them over. They
	## stay held until that line says they arrived, in case this one goes astray.
	if profile_id.is_empty() or _held.get(profile_id, []).is_empty():
		return
	_handed[peer_id] = profile_id
	_send_peer(peer_id, {"kind": "claim", "held": _held[profile_id]})

func _handed_over(peer_id: String, run_ids: Array) -> void:
	var profile_id: String = str(_handed.get(peer_id, ""))
	if profile_id.is_empty():
		return
	var arrived: Array = run_ids.map(func(r: Variant) -> String: return str(r))
	var left: Array = _held.get(profile_id, []).filter(func(h: Dictionary) -> bool:
		return not arrived.has(str(h.get("results", {}).get("run_id", ""))))
	if left.is_empty():
		_held.erase(profile_id)
	else:
		_held[profile_id] = left
	_handed.erase(peer_id)
	if saves != null:
		saves.save_held(_held)

func holding_for(profile_id: String) -> int:
	## How many runs' shares are waiting for this profile.
	return _held.get(profile_id, []).size()

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
	_wait -= delta
	if _wait > 0.0:
		return
	var before: Dictionary = run.duplicate(true) if _listening() else {}
	var event: Dictionary = DeepDescent.step(run)
	if event.is_empty():
		return
	var duration: float = float(event.get("battle", {}).get("duration", 0.4))
	_wait = maxf(STEP_FLOOR, duration)
	_publish(before, event)

func _process(delta: float) -> void:
	SteamWire.pump()
	tick(delta)

func _listening() -> bool:
	## Whether anyone is seated at the other end of the wire to be sent a change. Alone, or
	## hosting a lobby nobody has joined yet, the copy of the run and the diff that would make
	## a patch out of it are skipped: every step of a fight paid for both, for nobody.
	return transport != null and not _player_of.is_empty()

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
	_send_peer(_host_peer, packet)

func _ask_snapshot() -> void:
	## Once, and again only if the answer is slow in coming: every step after a gap is a gap
	## too, and asking at each of them would bury the host in copies of the whole run.
	var now: int = maxi(1, Time.get_ticks_msec())
	if _snapshot_asked > 0 and now - _snapshot_asked < SNAPSHOT_RETRY_MS:
		return
	_snapshot_asked = now
	_send_host({"kind": "snapshot_please"})

func _on_connected() -> void:
	if is_host or _pending_hello.is_empty():
		return
	var known: Variant = transport.get("host_peer_id") if transport != null else null
	if known != null and not str(known).is_empty():
		_host_peer = str(known)
	_send_peer(_host_peer, {"kind": "hello", "member": _pending_hello})

func _on_peer_connected(_peer_id: String) -> void:
	## Nobody is seated until they say hello.
	pass

func _on_peer_disconnected(peer_id: String) -> void:
	if is_host:
		var player_id: String = str(_player_of.get(peer_id, ""))
		if player_id.is_empty():
			return
		if not in_run():
			## Nothing is kept for anyone in the workshop: a guest who drops out of the lobby
			## gives up their seat, as one who said goodbye does, rather than holding it empty.
			_forget_member(player_id)
		else:
			_player_of.erase(peer_id)
			_peer_of.erase(player_id)
			if lobby.members.has(player_id):
				lobby.members[player_id].connected = false
			_absent(player_id)
		_broadcast({"kind": "lobby", "lobby": lobby})
		lobby_changed.emit(lobby)
	elif peer_id == _host_peer and status not in ["lost", "local"]:
		## Another guest leaving is the host's business; only the host going is ours.
		_set_status("lost")
		if in_run():
			error.emit("The host is gone. The run waits at its last landing for the host to reopen it.")
		else:
			removed.emit("The host closed the party.")

func _absent(player_id: String) -> void:
	## A player has dropped out of the run. The rest of the party hears so, and whatever was
	## waiting only on them goes ahead without them: a fight whose other hands are all locked
	## starts resolving, and any other gate whose other players have all acted opens.
	var before: Dictionary = run.duplicate(true) if _listening() else {}
	DeepDescent.set_connected(run, player_id, false)
	var event: Dictionary = {"kind": "presence", "unit": player_id, "connected": false}
	var b: Dictionary = DeepDescent.battle(run)
	if not b.is_empty():
		if str(b.phase) == "planning" and DeepBattle.ready_to_resolve(b):
			event = {"kind": "battle", "battle": DeepBattle.start_resolution(b), "phase": str(run.phase), "depth": int(run.depth)}
			_wait = 0.0
	else:
		var moved: Dictionary = DeepDescent.settle_absent(run)
		if not moved.is_empty():
			event = moved
	event.absent = player_id
	_publish(before, event)

func _on_packet(peer_id: String, bytes: PackedByteArray) -> void:
	var decoded: Dictionary = Codec.decode(bytes)
	if not bool(decoded.get("ok", false)):
		return
	var packet: Dictionary = decoded.packet
	if not is_host and peer_id != _host_peer:
		## A guest takes the run from the host alone, never from another guest.
		return
	if str(packet.get("version", "")) != VERSION:
		if is_host:
			## Said once. A refusal is never answered, or two builds that disagree would go on
			## refusing each other for as long as the line stayed up.
			if str(packet.get("kind", "")) != "refused":
				_send_peer(peer_id, {"kind": "refused", "error": "Your build (%s) does not match the host's (%s)." % [str(packet.get("version", "?")), VERSION]})
		elif status not in ["lost", "local"]:
			## A host on another build: nothing it sends can be mirrored, so say why and go home.
			var said: String = str(packet.get("error", "")) if str(packet.get("kind", "")) == "refused" else ""
			_set_status("lost")
			removed.emit(said if not said.is_empty() else "The host's build (%s) does not match yours (%s)." % [str(packet.get("version", "?")), VERSION])
		return
	if is_host:
		_host_packet(peer_id, packet)
	else:
		_guest_packet(packet)

func _host_packet(peer_id: String, packet: Dictionary) -> void:
	var kind: String = str(packet.get("kind", ""))
	match kind:
		"hello":
			if _player_of.has(peer_id):
				## Already seated: a second hello from the same line takes no second seat, and is
				## answered with the welcome again in case the first went astray.
				_send_peer(peer_id, {"kind": "welcome", "player_id": str(_player_of[peer_id]), "lobby": lobby, "state": run, "revision": revision})
				return
			var member: Dictionary = packet.get("member", {})
			## Whatever this host kept for them from a run they dropped out of goes first, so it
			## reaches them even if there is no seat for them this time.
			_hand_over(peer_id, str(member.get("id", "")).left(64))
			## A player coming back keeps their seat; a new one takes the next. The seat is
			## found by the profile they play with, since the seat ids are the host's own.
			var player_id: String = _away_seat(str(member.get("id", "")))
			if player_id.is_empty():
				if lobby.order.size() >= MAX_PLAYERS or bool(lobby.get("started", false)):
					_send_peer(peer_id, {"kind": "refused", "error": "The party is full or already underground."})
					return
				player_id = "p%d" % _next_seat
				_next_seat += 1
				_add_member(player_id, member)
			else:
				lobby.members[player_id].connected = true
				if in_run():
					## The rest of the party hears they are back before the line to them is
					## opened, so the state the newcomer is handed already says so.
					var before: Dictionary = run.duplicate(true) if _listening() else {}
					DeepDescent.set_connected(run, player_id, true)
					_publish(before, {"kind": "presence", "unit": player_id, "connected": true})
			_peer_of[player_id] = peer_id
			_player_of[peer_id] = player_id
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
		"claimed":
			var runs: Variant = packet.get("runs", [])
			if runs is Array:
				_handed_over(peer_id, runs)
		"leaving":
			## A guest who said goodbye is gone for good from the lobby, not merely away.
			var player_id: String = str(_player_of.get(peer_id, ""))
			if not player_id.is_empty() and not in_run():
				_forget_member(player_id)
				_broadcast({"kind": "lobby", "lobby": lobby})
				lobby_changed.emit(lobby)

func _guest_packet(packet: Dictionary) -> void:
	var kind: String = str(packet.get("kind", ""))
	match kind:
		"welcome":
			local_id = str(packet.get("player_id", ""))
			lobby = packet.get("lobby", lobby)
			revision = int(packet.get("revision", 0))
			_snapshot_asked = 0
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
			_snapshot_asked = 0
			_ended = false
			run_started.emit(run)
		"step":
			var incoming: int = int(packet.get("revision", 0))
			host_speed = clampf(float(packet.get("speed", host_speed)), 1.0, 8.0)
			if incoming <= revision:
				## Already in hand: a snapshot overtook it.
				return
			if incoming != revision + 1 or run.is_empty():
				## A gap. The patch was made against a state this mirror never saw, and applying
				## it would only corrupt the mirror: ask for the whole state and wait for it.
				_ask_snapshot()
				return
			run = DeepPatch.apply(run, packet.get("patch", null))
			revision = incoming
			run_event.emit(packet.get("event", {}))
			if str(run.get("phase", "")) == "over" and not _ended:
				_ended = true
				run_ended.emit(DeepDescent.results(run))
		"snapshot":
			var fresh: bool = run.is_empty()
			var state: Variant = packet.get("state", {})
			_snapshot_asked = 0
			if not state is Dictionary or state.is_empty():
				return
			run = state
			revision = int(packet.get("revision", 0))
			lobby = packet.get("lobby", lobby)
			if fresh:
				run_started.emit(run)
			else:
				## Caught up: the screens show where the party is now, without starting over.
				run_event.emit({"kind": "resync"})
			if str(run.get("phase", "")) == "over" and not _ended:
				_ended = true
				run_ended.emit(DeepDescent.results(run))
		"claim":
			## Shares of runs this lapidary was not back for the end of. Each is applied by the
			## app (which keeps it from being applied twice), and the host is told they arrived.
			var arrived: Array = []
			for entry in packet.get("held", []):
				if entry is Dictionary and entry.get("results", null) is Dictionary:
					claimed.emit(entry.results, str(entry.get("player_id", "")))
					arrived.append(str(entry.results.get("run_id", "")))
			if not arrived.is_empty():
				_send_host({"kind": "claimed", "runs": arrived})
		"refused":
			var message: String = str(packet.get("error", "refused"))
			if status == "connecting":
				## The hello itself was turned away: there is no party here to wait in.
				_set_status("lost")
				removed.emit(message)
			else:
				refused.emit(message)
		"kicked":
			_set_status("lost")
			removed.emit("The host sent you back to your own workshop.")
		"closed":
			_set_status("lost")
			removed.emit("The host closed the party.")
