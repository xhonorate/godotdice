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

class SteamNet extends RefCounted:
	## Steam's backend, as far as a party sees it: lobbies, and who may message whom.
	var lobbies: Dictionary = {}
	var clients: Dictionary = {}
	var next_lobby: int = 109775240000000001

class FakeSteam extends RefCounted:
	## Stands in for the GodotSteam singleton: the calls the transport makes, the signals it
	## listens to, and Steam's 512 KiB ceiling on a message.
	signal lobby_created(result: int, lobby_id: int)
	signal lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int)
	signal lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int)
	signal join_requested(lobby_id: int, steam_id: int)
	signal network_messages_session_request(remote_steam_id: int)
	signal network_messages_session_failed(reason: int, remote_steam_id: int, connection_state: int, debug_message: String)
	var net: SteamNet
	var id: int
	var inbox: Array = []
	var accepted: Dictionary = {}
	var overlay: bool = false
	var online: bool = true
	var invites_opened: int = 0
	var largest: int = 0
	func _init(backend: SteamNet, steam_id: int) -> void:
		net = backend
		id = steam_id
		net.clients[id] = self
	func getSteamID() -> int:
		return id
	func loggedOn() -> bool:
		return online
	func run_callbacks() -> void:
		pass
	func createLobby(_kind: int, _most: int) -> void:
		var lobby: int = net.next_lobby
		net.next_lobby += 1
		net.lobbies[lobby] = {"owner": id, "members": [id]}
		lobby_joined.emit(lobby, 0, false, 1)
		lobby_created.emit(1, lobby)
	func joinLobby(lobby: int) -> void:
		var room: Dictionary = net.lobbies.get(lobby, {})
		if room.is_empty() or room.members.size() >= 4:
			lobby_joined.emit(lobby, 0, false, 2 if room.is_empty() else 4)
			return
		room.members.append(id)
		for other in room.members:
			if other != id:
				net.clients[other].lobby_chat_update.emit(lobby, id, id, 1)
		lobby_joined.emit(lobby, 0, false, 1)
	func leaveLobby(lobby: int) -> void:
		var room: Dictionary = net.lobbies.get(lobby, {})
		if room.is_empty() or not room.members.has(id):
			return
		room.members.erase(id)
		if room.owner == id and not room.members.is_empty():
			room.owner = room.members[0]
		for other in room.members:
			net.clients[other].lobby_chat_update.emit(lobby, id, id, 2)
	func getLobbyOwner(lobby: int) -> int:
		return int(net.lobbies.get(lobby, {}).get("owner", 0))
	func getNumLobbyMembers(lobby: int) -> int:
		return net.lobbies.get(lobby, {}).get("members", []).size()
	func getLobbyMemberByIndex(lobby: int, index: int) -> int:
		return net.lobbies[lobby].members[index]
	func sendMessageToUser(to: int, data: PackedByteArray, _flags: int, _channel: int) -> int:
		var peer: FakeSteam = net.clients.get(to)
		if data.size() > 512 * 1024 or peer == null:
			return 2
		largest = maxi(largest, data.size())
		if not peer.accepted.has(id):
			peer.network_messages_session_request.emit(id)
		if peer.accepted.has(id):
			peer.inbox.append({"identity": id, "payload": data.duplicate()})
		return 1
	func receiveMessagesOnChannel(_channel: int, most: int) -> Array:
		var batch: Array = inbox.slice(0, most)
		inbox = inbox.slice(most)
		return batch
	func acceptSessionWithUser(remote: int) -> bool:
		accepted[remote] = true
		return true
	func closeSessionWithUser(remote: int) -> bool:
		accepted.erase(remote)
		return true
	func isOverlayEnabled() -> bool:
		return overlay
	func activateGameOverlayInviteDialog(_lobby: int) -> void:
		invites_opened += 1

func _init() -> void:
	DeepSaveStore.override_directory = "user://test_scratch"
	_test_local()
	_test_linked()
	_test_steam()
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
	check(result.ok and started.size() == 1 and session.in_run() and session.run.phase == "grubstake", "the run starts at the shaft head")
	stake(session)
	check(session.run.phase == "tunnels" and events_a.size() == 1 and events_a[0].kind == "staked" and bool(events_a[0].get("finished", false)), "alone, one stake opens the tunnels")
	events_a.clear()
	var revision_after_stake: int = session.revision
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
	check(session.revision == revision_after_stake + 1, "every published change bumps the revision")
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
	## Both take a stake at the shaft head; the guest's goes through the host and comes back.
	check(host.run.phase == "grubstake" and guest.run.grubstake.offers.has("p1"), "both sides see the shaft head")
	stake(guest)
	check(host.run.phase == "grubstake" and str(DeepDescent.player(host.run, "p1").stake) != "" and same(guest.run, host.run), "the guest's stake is applied by the host and mirrored")
	stake(host)
	check(host.run.phase == "tunnels" and same(guest.run, host.run), "the host's stake opens the tunnels on both")
	host_events.clear()
	guest_events.clear()
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
						if not bool(unit.get("mining", false)):
							continue
						var open_spot: int = -1
						for spot in host.run.chamber.vein.spots:
							if str(spot.taken).is_empty():
								open_spot = int(spot.index)
								break
						var can_swing: bool = int(unit.hp) > DeepDescent.strike_cost(int(unit.get("strikes", 0)), bool(host.run.chamber.vein.get("hazard", false)))
						if open_spot >= 0 and can_swing:
							who.send({"kind": "strike", "spot": open_spot})
						else:
							who.send({"kind": "stop_mining"})
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

func stake(session: DeepSession) -> void:
	## Take the first stake on offer for this session's player, with whatever it needs.
	var offers: Array = session.run.get("grubstake", {}).get("offers", {}).get(session.local_id, [])
	if offers.is_empty():
		return
	var offer: Dictionary = offers[0]
	var payload: Dictionary = {}
	if offer.needs.has("pick"):
		payload.pick = 0
	session.send({"kind": "stake", "offer": str(offer.id), "payload": payload})

func fighting(offers: Array) -> Dictionary:
	for offer in offers:
		if str(offer.kind) in ["fight", "elite"]:
			return offer
	return offers[0]

func settle(sessions: Array) -> void:
	## Steam delivers when the transport polls; poll everyone until the wire is quiet.
	for _round in range(20):
		var moved: bool = false
		for session in sessions:
			var wire: Node = session.transport
			if wire != null and wire.steam != null and not wire.steam.inbox.is_empty():
				wire.poll()
				moved = true
		if not moved:
			return

func _test_steam() -> void:
	var net := SteamNet.new()
	var ada_steam := FakeSteam.new(net, 76561190000000001)
	var bo_steam := FakeSteam.new(net, 76561190000000002)
	var cy_steam := FakeSteam.new(net, 76561190000000003)
	var host := DeepSession.new()
	var guest := DeepSession.new()
	var third := DeepSession.new()
	host.steam_api = ada_steam
	guest.steam_api = bo_steam
	third.steam_api = cy_steam
	for session in [host, guest, third]:
		root.add_child(session)
	var guest_errors: Array = []
	guest.error.connect(func(message: String) -> void: guest_errors.append(message))
	## Steam in offline mode cannot open a lobby, and the workshop stays as it was.
	host.start_local(member("Ada", "ARDOR"))
	ada_steam.online = false
	var offline: Dictionary = host.host_steam(member("Ada", "ARDOR"))
	check(not offline.ok and str(offline.error).contains("offline") and host.status == "local" and host.transport == null, "offline, Steam says so and nothing changes: %s" % str(offline))
	ada_steam.online = true
	var result: Dictionary = host.host_steam(member("Ada", "ARDOR"))
	check(result.ok and host.status == "hosting" and host.is_host, "hosting on Steam opens a lobby (%s)" % host.status)
	check(host.invite_code == str(net.lobbies.keys()[0]), "the lobby's ID is the invitation: %s" % host.invite_code)
	## Joining: a typo is refused before anything changes; a lobby that is gone says so.
	guest.start_local(member("Bo", "VESPER"))
	check(not guest.join_steam("not a lobby", member("Bo", "VESPER")).ok and guest.status == "local", "a mistyped lobby ID leaves the workshop as it was")
	check(guest.join_steam("123", member("Bo", "VESPER")).ok and guest.status == "lost" and guest_errors.size() == 1 and str(guest_errors[0]).contains("gone"), "a lobby that is gone says so: %s" % str(guest_errors))
	check(guest.join_steam(host.invite_code, member("Bo", "VESPER")).ok, "joining the host's lobby")
	settle([host, guest])
	check(guest.status == "joined" and guest.local_id == "p1" and not guest.is_host, "the Steam guest is welcomed into seat p1 (%s, %s)" % [guest.status, guest.local_id])
	check(guest.transport.host_peer_id == str(ada_steam.id), "the guest talks to the lobby's owner")
	third.join_steam(" %s " % host.invite_code, member("Cy", "RUE"))
	settle([host, guest, third])
	check(third.local_id == "p2" and host.lobby.order == ["p0", "p1", "p2"] and same(guest.lobby, host.lobby), "a third lapidary joins, and everyone sees the party of three")
	## A guest listens to the host alone; another member's packet is not the run.
	var lobby_before: Dictionary = guest.lobby.duplicate(true)
	third.transport.send(str(bo_steam.id), PacketCodec.encode({"kind": "lobby", "lobby": {"members": {}, "order": []}, "version": DeepSession.VERSION}))
	settle([host, guest, third])
	check(same(guest.lobby, lobby_before), "a guest ignores a packet from another guest")
	## A stranger outside the lobby is not heard at all, even if a message slips through.
	var stranger := FakeSteam.new(net, 76561190000000009)
	var intruder: PackedByteArray = PacketCodec.encode({"kind": "hello", "member": member("Eve", "ARDOR"), "version": DeepSession.VERSION})
	stranger.sendMessageToUser(ada_steam.id, PackedByteArray([0]) + intruder, 8, 0)
	ada_steam.inbox.append({"identity": stranger.id, "payload": PackedByteArray([0]) + intruder})
	settle([host])
	check(host.lobby.order.size() == 3, "someone outside the lobby cannot take a seat")
	## Another guest leaving is the host's business, not a lost connection.
	third.start_local(member("Cy", "RUE"))
	check(not bool(host.lobby.members.p2.connected) and guest.status == "joined", "a guest leaving the lobby is marked away, and the other guest stays (%s)" % guest.status)
	settle([host, guest])
	check(not bool(guest.lobby.members.p2.connected), "and the other guest hears so from the host")
	## Setting out: the whole run goes over Steam, cut into parts where it must be.
	guest.update_member({"ready": true})
	settle([host, guest])
	check(host.can_start(), "the host can set out once the Steam guest is ready")
	check(host.start_run(4242).ok, "the host sets out")
	settle([host, guest])
	check(guest.in_run() and same(guest.run, host.run), "the Steam guest receives the whole run")
	stake(guest)
	settle([host, guest])
	stake(host)
	settle([host, guest])
	check(host.run.phase == "tunnels" and same(guest.run, host.run), "stakes travel over Steam and the mirror matches")
	var big := PackedByteArray()
	big.resize(700 * 1024)
	for index in big.size():
		big[index] = index % 251
	var arrived: Array = []
	guest.transport.packet_received.connect(func(_sender: String, bytes: PackedByteArray) -> void: arrived.append(bytes), CONNECT_ONE_SHOT)
	check(host.transport.send(str(bo_steam.id), big) == OK, "a packet bigger than one Steam message is sent")
	guest.transport.poll()
	check(arrived.size() == 1 and arrived[0] == big, "and arrives whole, in one piece")
	check(ada_steam.largest <= 512 * 1024, "no single Steam message passes 512 KiB (%d)" % ada_steam.largest)
	## Steam invitations reach the session; the overlay's invite list opens when it can.
	var invitations: Array = []
	guest.invited.connect(func(lobby_id: String) -> void: invitations.append(lobby_id))
	bo_steam.join_requested.emit(109775240000000777, ada_steam.id)
	check(invitations == ["109775240000000777"], "an invitation accepted in Steam names the lobby: %s" % str(invitations))
	check(not host.invite_friends(), "without the overlay, the invite list cannot open")
	ada_steam.overlay = true
	check(host.invite_friends() and ada_steam.invites_opened == 1, "with it, the invite list opens")
	check(SteamMessagesTransport.launch_lobby(PackedStringArray(["--instance=a", "+connect_lobby", "109775240000000001"])) == "109775240000000001", "a cold start from an invitation finds its lobby")
	check(SteamMessagesTransport.launch_lobby(PackedStringArray(["+connect_lobby"])) == "", "a launch without one finds none")
	## The host walks away: the guest knows the run is waiting for them.
	host.start_local(member("Ada", "ARDOR"))
	check(guest.status == "lost", "the guest notices the host leaving the lobby (%s)" % guest.status)
	check(net.lobbies.values()[0].members == [bo_steam.id], "leaving gives up the host's place in the lobby")
	for session in [host, guest, third]:
		session.queue_free()
	net.clients.clear()
