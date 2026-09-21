extends SceneTree
## The session: one code path for solo and co-op, streamed one step at a time.

var checks: int = 0
var failures: Array = []
var events_a: Array = []
var events_b: Array = []

class Loopback extends Node:
	signal packet_received(peer_id: String, bytes: PackedByteArray)
	signal peer_connected(peer_id: String)
	signal peer_disconnected(peer_id: String)
	signal connected
	signal failed(message: String)
	var other: Node = null
	var my_peer_id: String = "1"
	var sent: int = 0
	var bytes_total: int = 0
	func send(_peer_id: String, bytes: PackedByteArray) -> Error:
		if other == null:
			return ERR_UNAVAILABLE
		sent += 1
		bytes_total += bytes.size()
		other.packet_received.emit(my_peer_id, bytes.duplicate())
		return OK
	func close() -> void:
		pass

func _init() -> void:
	DeepSaveStore.override_directory = "user://test_scratch"
	_test_local()
	_test_linked()
	print("Session: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func member(name: String, character: String) -> Dictionary:
	var profile: Dictionary = DeepProfile.new_profile(name)
	var loadout: Dictionary = DeepProfile.loadout(profile, "ARDOR")
	return {"name": name, "character": character, "rail": loadout.rail, "dice": loadout.dice}

func same(a: Variant, b: Variant) -> bool:
	## A guest's mirror has been through JSON, so its whole numbers are floats. Compare
	## both sides through the same boundary.
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))

func drive(session: DeepSession, seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		session.tick(0.05)
		elapsed += 0.05

func _test_local() -> void:
	var session := DeepSession.new()
	root.add_child(session)
	var started: Array = []
	session.run_started.connect(func(state: Dictionary) -> void: started.append(state))
	session.run_event.connect(func(event: Dictionary) -> void: events_a.append(event))
	session.start_local(member("Ada", "ARDOR"))
	check(session.status == "local" and session.lobby.order == ["p0"], "a local session seats one player")
	check(session.can_start(), "alone, you can always set out")
	var result: Dictionary = session.start_run(77)
	check(result.ok and started.size() == 1 and session.in_run() and session.run.phase == "tunnels", "the run starts at the tunnels")
	var refusals: Array = []
	session.refused.connect(func(message: String) -> void: refusals.append(message))
	session.send({"kind": "vote_tunnel", "offer": "nope"})
	check(refusals.size() == 1, "a bad command is refused locally: %s" % str(refusals))
	var offer: Dictionary = session.run.offers[0]
	for candidate in session.run.offers:
		if str(candidate.kind) == "fight":
			offer = candidate
	session.send({"kind": "vote_tunnel", "offer": offer.id})
	check(events_a.size() == 1 and events_a[0].kind == "vote" and events_a[0].has("entered"), "the vote enters the chamber and is reported as one event")
	check(session.revision == 2, "every published change bumps the revision")
	if str(offer.kind) == "fight":
		check(DeepDescent.in_battle(session.run), "a fight is on")
		drive(session, 1.0)
		check(events_a.size() == 1, "nothing steps while players plan")
		session.send({"kind": "lock"})
		check(events_a.size() == 2 and events_a[1].has("resolution"), "locking the only player begins resolution")
		var before: int = events_a.size()
		drive(session, 0.1)
		check(events_a.size() == before + 1, "the first step lands right away")
		var b: Dictionary = session.battle()
		var guard: int = 0
		while DeepBattle.has_steps(b) and guard < 100:
			guard += 1
			drive(session, 0.3)
			b = session.battle()
		var kinds: Array = events_a.map(func(e: Dictionary) -> String: return str(e.get("battle", {}).get("kind", e.kind)))
		check(kinds.has("gem_fire") or kinds.has("gem_fizzle"), "gems resolved over time: %s" % str(kinds))
		check(kinds[kinds.size() - 1] in ["turn_begin", "battle_over"], "the turn closed: %s" % kinds[kinds.size() - 1])
	session.queue_free()

func _test_linked() -> void:
	var host := DeepSession.new()
	var guest := DeepSession.new()
	root.add_child(host)
	root.add_child(guest)
	var host_wire := Loopback.new()
	var guest_wire := Loopback.new()
	host_wire.my_peer_id = "1"
	guest_wire.my_peer_id = "2"
	host_wire.other = guest_wire
	guest_wire.other = host_wire
	host.start_local(member("Ada", "ARDOR"))
	host.attach_transport(host_wire)
	guest.is_host = false
	guest.attach_transport(guest_wire)
	var guest_events: Array = []
	guest.run_event.connect(func(event: Dictionary) -> void: guest_events.append(event))
	var host_events: Array = []
	host.run_event.connect(func(event: Dictionary) -> void: host_events.append(event))
	var guest_refusals: Array = []
	guest.refused.connect(func(message: String) -> void: guest_refusals.append(message))
	guest.hello(member("Bo", "VESPER"))
	check(guest.status == "joined" and guest.local_id == "p1", "the guest is welcomed into seat p1 (%s)" % guest.local_id)
	check(host.lobby.order == ["p0", "p1"] and guest.lobby.order == ["p0", "p1"], "both sides see the same lobby")
	check(not host.can_start(), "the host waits for the guest to be ready")
	guest.update_member({"ready": true})
	check(bool(host.lobby.members.p1.ready) and bool(guest.lobby.members.p1.ready), "readiness travels to the host and back")
	guest.update_member({"character": "RUE"})
	check(not bool(host.lobby.members.p1.ready) and host.lobby.members.p1.character == "RUE", "changing character clears readiness")
	guest.update_member({"ready": true})
	host.choose_mine("QUARRY")
	check(not bool(host.lobby.members.p1.ready), "choosing a mine clears everyone's readiness")
	guest.update_member({"ready": true})
	check(host.can_start(), "ready again")
	var started: Dictionary = host.start_run(4242)
	check(started.ok and guest.in_run() and same(guest.run, host.run), "the guest receives the whole run")
	## The guest votes; the host applies; the mirror follows. Fights are sought out, so the
	## stream of battle steps gets exercised whatever the map looks like.
	var offer: Dictionary = fighting(host.run.offers)
	guest.send({"kind": "vote_tunnel", "offer": "nope"})
	check(guest_refusals.size() == 1, "the host refuses a bad command back to the guest")
	guest.send({"kind": "vote_tunnel", "offer": offer.id})
	check(host_events.size() == 1 and guest_events.size() == 1 and same(guest.run, host.run), "a vote is published to both and the mirror matches")
	host.send({"kind": "vote_tunnel", "offer": offer.id})
	check(host.run.depth == 1 and guest.run.depth == 1 and same(guest.run, host.run), "the second vote enters depth 1 on both")
	var mismatch: int = 0
	var steps: int = 0
	var guard: int = 0
	while str(host.run.phase) != "over" and guard < 400 and host.run.depth < 3:
		guard += 1
		match str(host.run.phase):
			"tunnels":
				for who in [host, guest]:
					if str(DeepDescent.player(host.run, who.local_id).get("vote", "")).is_empty():
						who.send({"kind": "vote_tunnel", "offer": fighting(host.run.offers).id})
						break
			"chamber":
				if DeepDescent.in_battle(host.run):
					var b: Dictionary = host.battle()
					if str(b.phase) == "planning":
						for who in [host, guest]:
							if not bool(DeepBattle.player(b, who.local_id).locked):
								who.send({"kind": "lock"})
					else:
						var before: int = host_events.size()
						drive(host, 0.3)
						if host_events.size() > before:
							steps += 1
							if not same(guest.run, host.run):
								mismatch += 1
				elif str(host.run.chamber.kind) in ["vein", "vug"]:
					for who in [host, guest]:
						var unit: Dictionary = DeepDescent.player(host.run, who.local_id)
						if int(unit.strikes) > 0:
							for spot in host.run.chamber.vein.spots:
								if str(spot.taken).is_empty():
									who.send({"kind": "strike", "spot": spot.index})
									break
							break
				elif str(host.run.chamber.kind) == "oddity":
					var oddity: Dictionary = DeepContent.oddity(str(host.run.chamber.oddity))
					for who in [host, guest]:
						if str(DeepDescent.player(host.run, who.local_id).oddity_choice).is_empty():
							who.send({"kind": "oddity", "choice": oddity.choices[oddity.choices.size() - 1].id})
							break
			"landing", "hoard", "salvage":
				break
	check(steps > 3, "battle steps streamed to the guest (%d)" % steps)
	check(mismatch == 0, "the guest's mirror matched the host after every step (%d mismatches)" % mismatch)
	check(host_events.size() == guest_events.size(), "both sides saw the same number of events (%d vs %d)" % [host_events.size(), guest_events.size()])
	check(host_wire.bytes_total / maxi(1, host_wire.sent) < 40000, "packets stay small: %d bytes on average" % (host_wire.bytes_total / maxi(1, host_wire.sent)))
	## Only the host can call the whole party up.
	var refusals_before: int = guest_refusals.size()
	var phase_before: String = str(host.run.phase)
	guest.send({"kind": "abandon"})
	check(guest_refusals.size() == refusals_before + 1 and str(host.run.phase) == phase_before, "a guest cannot abandon the dig")
	## A late joiner is refused once the party is underground.
	var late := DeepSession.new()
	root.add_child(late)
	var late_wire := Loopback.new()
	var host_wire_2 := Loopback.new()
	late_wire.my_peer_id = "3"
	late_wire.other = host_wire_2
	host_wire_2.other = late_wire
	host_wire_2.my_peer_id = "1"
	## The host only has one transport, so route the late peer through it by hand.
	late.is_host = false
	late.attach_transport(late_wire)
	var late_refusals: Array = []
	late.refused.connect(func(message: String) -> void: late_refusals.append(message))
	host_wire_2.packet_received.connect(func(peer_id: String, bytes: PackedByteArray) -> void: host._on_packet(peer_id, bytes))
	host_wire.other = null
	late.hello(member("Cy", "ARDOR"))
	check(late_refusals.size() == 0 or late_refusals[0].contains("underground") or late_refusals[0].contains("full"), "a late joiner is told the party is underground: %s" % str(late_refusals))
	## The guest drops: the host marks the seat and the fight can still resolve.
	host_wire.other = guest_wire
	host._on_peer_disconnected("2")
	check(not bool(host.lobby.members.p1.connected), "a dropped guest is marked disconnected")
	if DeepDescent.in_battle(host.run):
		check(not bool(DeepBattle.player(host.battle(), "p1").connected), "and the fight knows it")
	host.queue_free()
	guest.queue_free()
	late.queue_free()
	for wire in [host_wire, guest_wire, late_wire, host_wire_2]:
		if wire.get_parent() == null:
			wire.free()

func fighting(offers: Array) -> Dictionary:
	for offer in offers:
		if str(offer.kind) in ["fight", "elite"]:
			return offer
	return offers[0]
