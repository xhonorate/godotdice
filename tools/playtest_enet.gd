extends SceneTree
## Real ENet process worker for tools/playtest_enet.py. No player profile is read or saved.

var session: DeepSession
var seat := 0
var count := 2
var port := 25800
var run_seed := 4242
var folder := ""
var mine := "QUARRY"
var mode := "new"
var started_ms := 0
var last_action_ms := 0
var ended_ms := 0
var hashes: Dictionary = {}
var coverage: Dictionary = {}
var refusals: Array = []
var errors: Array = []
var commands := 0
var last_command := ""
var recorded := false
var returning := false
var did_disconnect := false
var reconnect_at := 0
var member: Dictionary = {}
var last_heartbeat := 0
var waiting_for_command := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	seat = int(args[0])
	count = int(args[1])
	port = int(args[2])
	run_seed = int(args[3])
	folder = args[4]
	if args.size() > 5:
		mine = args[5]
	if args.size() > 6:
		mode = args[6]
	DeepSaveStore.override_directory = folder.path_join("scratch%d" % seat)
	Engine.max_fps = 240
	started_ms = Time.get_ticks_msec()
	call_deferred("_begin")

func _begin() -> void:
	var profile := DeepProfile.new_profile("Audit %d" % seat)
	var characters := ["ARDOR", "VESPER", "RUE", "ARDOR"]
	var character: String = characters[seat]
	var outfit := DeepProfile.loadout(profile, character)
	var sockets := 3
	if mode == "traversal":
		# Deliberately boosted fixture: exercise late-run transport without measuring balance.
		var skills := {"RED": "STRIKE", "BLUE": "GUARD", "GREEN": "MEND", "VIOLET": "VENOM", "GOLD": "TITHE", "WHITE": "CASCADE"}
		outfit.rail = []
		for socket in DeepContent.character(character).sockets:
			var skill: String = str(skills.get(str(socket), ["CLEAVE", "MEND", "GUARD"][outfit.rail.size() % 3]))
			var stone := DeepStone.make(skill, 150, 4, 3, [], {}, "fixture%d-%d" % [seat, outfit.rail.size()])
			stone.appraised = true
			outfit.rail.append(stone)
		sockets = outfit.rail.size()
	member = {"id": "enet-audit-%d" % seat, "name": "Audit %d" % seat, "character": character,
		"rail": outfit.rail, "dice": outfit.dice, "gold": 100000, "sockets": sockets}
	session = DeepSession.new()
	root.add_child(session)
	session.set_process(false)
	session.run_started.connect(_record)
	session.run_event.connect(_record)
	session.refused.connect(func(message: String) -> void:
		refusals.append({"message": message, "command": last_command, "revision": session.revision})
		_write("refusal%d" % refusals.size(), {"run": session.run, "command": last_command, "message": message})
		last_command = ""
		waiting_for_command = false)
	session.error.connect(func(message: String) -> void: errors.append(message))
	session.removed.connect(func(message: String) -> void: errors.append(message))
	var opened: Dictionary
	if seat == 0:
		opened = session.host_lan(member, port)
		session.choose_mine(mine)
	else:
		opened = session.join_lan("127.0.0.1", member, port)
	if not opened.ok:
		errors.append(opened.error)
		_finish(1)
	elif seat == 0:
		session.transport.packet_received.connect(func(_peer: String, bytes: PackedByteArray) -> void:
			var decoded := DeepSession.Codec.decode(bytes)
			if bool(decoded.get("ok", false)) and str(decoded.packet.get("kind", "")) == "command" and str(decoded.packet.get("cmd", {}).get("kind", "")) == "trade_offer":
				_write("last-trade", {"run": session.run, "packet": decoded.packet, "revision": session.revision}))

func _record(event: Dictionary) -> void:
	if str(event.get("unit", "")) == session.local_id or str(event.get("battle", {}).get("unit", "")) == session.local_id or event.get("units", []).has(session.local_id):
		waiting_for_command = false
	# Normalize numeric values just as the JSON wire does before comparing mirrors.
	var normalized: Variant = JSON.parse_string(JSON.stringify(session.run))
	hashes[str(session.revision)] = JSON.stringify(normalized).sha256_text()
	var phase: String = str(session.run.get("phase", ""))
	coverage[phase] = int(coverage.get(phase, 0)) + 1
	var room: String = str(session.run.get("chamber", {}).get("kind", ""))
	if not room.is_empty():
		coverage["room:" + room] = int(coverage.get("room:" + room, 0)) + 1
	var kind: String = str(event.get("battle", {}).get("kind", event.get("kind", "start")))
	coverage["event:" + kind] = int(coverage.get("event:" + kind, 0)) + 1

func _process(_delta: float) -> bool:
	if session == null:
		return false
	var now := Time.get_ticks_msec()
	if now - last_heartbeat > 5000:
		last_heartbeat = now
		_write("status", {"phase": session.run.get("phase", ""), "depth": session.run.get("depth", 0),
			"revision": session.revision, "last_command": last_command, "player": session.local_player(), "battle_phase": session.battle().get("phase", ""), "errors": errors, "refusals": refusals})
	if now - started_ms > 180000:
		errors.append("180-second watchdog: " + str(session.run.get("phase", session.status)))
		_finish(1)
		return false
	if reconnect_at > 0:
		if now >= reconnect_at:
			reconnect_at = 0
			session.join_lan("127.0.0.1", member, port)
		return false
	if not session.in_run():
		if returning:
			if now - ended_ms > 500:
				_finish(0)
		elif seat == 0 and session.lobby.order.size() == count and session.can_start():
			session.start_run(run_seed)
		elif seat > 0 and session.status == "joined" and not bool(session.local_member().get("ready", false)):
			session.update_member({"ready": true})
		return false
	if str(session.run.phase) == "over":
		if not recorded:
			recorded = true
			ended_ms = now
			_write("run", _summary())
		if seat == 0:
			var all_done := true
			for other in range(1, count):
				all_done = all_done and FileAccess.file_exists(folder.path_join("seat%d-run.json" % other))
			if all_done:
				session.leave_run()
				returning = true
		elif not bool(session.lobby.get("started", true)):
			session.leave_run()
			returning = true
		return false
	# Rejoin once during a real planning turn, using the same profile identity.
	if mode == "rejoin" and seat == count - 1 and not did_disconnect and DeepDescent.in_battle(session.run) and str(session.battle().phase) == "planning":
		did_disconnect = true
		session._drop_transport()
		reconnect_at = now + 500
		last_command = ""
		return false
	if seat == 0:
		session.tick(100.0)
	if waiting_for_command:
		return false
	if now - last_action_ms < 35:
		return false
	last_action_ms = now
	var cmd := _next_command()
	if cmd.is_empty():
		return false
	var unit := session.local_player()
	var key := "%s:%s:%s:%s:%s:%s:%s" % [session.run.phase, session.run.depth, session.battle().get("turn", 0), unit.get("strikes", 0), DeepBattle.player(session.battle(), session.local_id).get("rerolls", 0), unit.get("ore", 0), JSON.stringify(cmd)]
	if key == last_command:
		return false
	last_command = key
	commands += 1
	waiting_for_command = true
	session.send(cmd)
	return false

func _next_command() -> Dictionary:
	var run := session.run
	var unit := session.local_player()
	if unit.is_empty():
		return {}
	var down := bool(unit.get("downed", false))
	match str(run.phase):
		"grubstake":
			for offer in unit.get("temps", []):
				if int(offer.get("chosen", -1)) < 0:
					return {"kind": "temporary", "index": offer.index, "pick": 0}
			for offer in unit.get("dice_offers", []):
				if not bool(offer.get("kept", false)) and int(offer.get("chosen", -1)) < 0:
					return {"kind": "dice_offer", "index": offer.index, "pick": -1}
			if str(unit.get("stake", "")).is_empty():
				var offers: Array = run.grubstake.offers[session.local_id]
				for offer in offers:
					if offer.needs.is_empty():
						return {"kind": "stake", "offer": offer.id, "payload": {}}
				return {"kind": "stake", "offer": offers[0].id, "payload": {"pick": 0}}
		"tunnels":
			if not down and str(unit.get("vote", "")).is_empty():
				var offer: Dictionary = run.offers[0]
				var wanted := ["vein", "merchant", "oddity", "carver", "smithy", "landing"] if run_seed % 2 == 0 else ["fight", "elite", "landing"]
				for candidate in run.offers:
					if str(candidate.kind) in wanted:
						offer = candidate
				return {"kind": "vote_tunnel", "offer": offer.id}
		"chamber":
			if down:
				return {}
			if DeepDescent.in_battle(run):
				var battle := session.battle()
				var fighter := DeepBattle.player(battle, session.local_id)
				if str(battle.phase) != "planning" or bool(fighter.get("locked", false)) or bool(fighter.get("downed", false)):
					return {}
				if int(fighter.get("rerolls", 0)) > 0:
					var dice: Array = []
					for roll in fighter.hand:
						if int(roll.get("value", 0)) < 4 and not bool(roll.get("locked", false)):
							dice.append(str(roll.get("die_id", "")))
					if not dice.is_empty():
						return {"kind": "reroll", "dice": dice}
				return {"kind": "lock"}
			var room: String = str(run.chamber.kind)
			if room in DeepDescent.ROCK_ROOMS and bool(unit.get("mining", false)):
				if int(unit.get("strikes", 0)) < 4 and int(unit.hp) > DeepDescent.swing_cost(run, unit) + int(unit.max_hp) / 2:
					for spot in run.chamber.vein.spots:
						if str(spot.taken).is_empty() and str(spot.get("owner", unit.id)) == str(unit.id) and (spot.has("owner") or int(spot.index) % count == seat):
							return {"kind": "strike", "spot": spot.index}
				return {"kind": "stop_mining"}
			if room == "merchant" and not bool(unit.get("ready", false)):
				return {"kind": "leave"}
			if room == "altar" and str(unit.get("altar_done", "")) != "left":
				return {"kind": "altar_leave"}
			if room in ["oddity"] + DeepDescent.CARD_ROOMS and str(unit.get("oddity_choice", "")).is_empty():
				var oddity := DeepContent.oddity(str(run.chamber.oddity))
				return {"kind": "oddity", "choice": oddity.choices[-1].id}
		"landing":
			# Two players trade naturally collected stones; other seats wait for that table.
			if DeepDescent.can_trade(run) and not DeepDescent.has_traded(run, "p0"):
				var first := DeepDescent.player(run, "p0")
				var second := DeepDescent.player(run, "p1")
				var first_stones: Array = first.get("haul", []).filter(func(s: Dictionary) -> bool: return not DeepDescent.is_lent(run, s))
				var second_stones: Array = second.get("haul", []).filter(func(s: Dictionary) -> bool: return not DeepDescent.is_lent(run, s))
				if not first_stones.is_empty() and not second_stones.is_empty():
					var table := DeepDescent.trade_table(run)
					if session.local_id in ["p0", "p1"] and not table.offers.has(session.local_id):
						return {"kind": "trade_offer", "stone_id": (first_stones if session.local_id == "p0" else second_stones)[0].id}
					if session.local_id in ["p0", "p1"] and table.offers.size() == 2 and not table.accepted.has(session.local_id):
						return {"kind": "trade_accept"}
					return {}
			var pooled := 0
			for other in run.players:
				pooled += int(other.get("ore", 0))
			var extract: bool = int(run.depth) >= (4 if run_seed % 2 == 0 else 12) and pooled >= DeepDescent.lift_cost(run) and not bool(run.landing.get("cleared", false))
			if mode == "traversal":
				extract = DeepDescent.in_boss_hall(run) and pooled >= DeepDescent.lift_cost(run)
			if str(unit.get("choice", "")).is_empty():
				if extract:
					return {"kind": "choose", "choice": "lift"}
				if str(unit.get("respite", "")).is_empty() and not bool(run.landing.get("cleared", false)):
					return {"kind": "respite", "choice": "rest"}
				return {"kind": "choose", "choice": "descend"}
		"hoard":
			var pile: Dictionary = run.hoard.get(session.local_id, {})
			if not pile.is_empty() and str(pile.get("chosen", "")).is_empty():
				return {"kind": "pick_hoard", "stone_id": pile.offers[0].id}
		"salvage":
			if not bool(unit.get("ready", false)):
				return {"kind": "ready"}
	return {}

func _summary() -> Dictionary:
	return {"seat": seat, "seed": run_seed, "players": count, "mine": mine, "mode": mode,
		"depth": int(session.run.get("depth", 0)), "outcome": str(session.run.get("outcome", "")),
		"revision": session.revision, "hashes": hashes, "coverage": coverage, "commands": commands,
		"refusals": refusals, "errors": errors, "rejoined": did_disconnect, "elapsed_ms": Time.get_ticks_msec() - started_ms}

func _write(suffix: String, value: Dictionary) -> void:
	var output := FileAccess.open(folder.path_join("seat%d-%s.json" % [seat, suffix]), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(value))

func _finish(code: int) -> void:
	_write("done", {"exit": code, "returned": returning, "errors": errors, "refusals": refusals})
	if code != 0:
		_write("run", _summary())
	if session != null:
		session._drop_transport()
	quit(code)
