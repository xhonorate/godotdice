extends SceneTree

const Codec = preload("res://scripts/services/packet_codec.gd")
const Store = preload("res://scripts/services/save_store.gd")
const Session = preload("res://scripts/services/session.gd")
var assertions := 0
var failures: Array[String] = []
var accepted: Array = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--peer-role="):
			_run_process_peer.call_deferred(argument.trim_prefix("--peer-role="))
			return
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_codec()
	_test_persistence()
	await _test_enet()
	await _test_separate_processes()
	print("Services: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_codec() -> void:
	var packet := {"kind": "snapshot", "steam_id": "76561198012345678", "state": {"revision": 1, "value": 2.5}}
	var roundtrip := Codec.decode(Codec.encode(packet))
	check(roundtrip.ok and roundtrip.packet.steam_id == packet.steam_id, "Steam IDs retain all decimal digits")
	check(Codec.snapshot_hash(packet) == Codec.snapshot_hash(roundtrip.packet), "Snapshot checksum survives JSON number roundtrip")
	check(not Codec.decode("{bad}".to_utf8_buffer()).ok, "Malformed JSON rejected")
	check(not Codec.decode("[]".to_utf8_buffer()).ok, "Non-dictionary packet rejected")
	check(not Codec.decode(Codec.encode({"state": {}})).ok, "Missing packet kind rejected")
	var large := PackedByteArray()
	large.resize(Codec.MAX_PACKET_BYTES + 1)
	check(not Codec.decode(large).ok, "Oversized packet rejected")
	check(not Codec.decode(Codec.encode({"kind": "command", "payload": "a".repeat(Codec.MAX_COMMAND_BYTES)})).ok, "Oversized command rejected")
	check(Codec.encode({"kind": "bad", "value": NAN}).is_empty(), "Non-finite number rejected")
	var tree := {"kind": "snapshot"}
	var cursor := tree
	for index in 40:
		cursor["child"] = {}
		cursor = cursor.child
	check(Codec.encode(tree).is_empty(), "Excessively nested packet rejected")
	check(not Codec.versions_match({"protocol_version": 999, "build_version": "1.0.0", "content_version": "1.0.0"}), "Incompatible protocol rejected")

func _fixture() -> Dictionary:
	return {"schema_version": 1, "rules_version": "2.0.0", "content_version": "1.0.0", "run_id": "test-run",
		"revision": 1, "phase_id": 2, "phase": "planning", "session_id": "session", "host_epoch": 1,
		"heroes": [{"id": "lan-host", "key": "ARDOR", "hp": 88, "max_hp": 100, "block": 7, "ore": 15}],
		"rng_states": {"dice": "9223372036854775806", "loot": "76561198012345678"}}

func _test_persistence() -> void:
	var directory := "user://service-tests-%d" % Time.get_ticks_usec()
	var saves := Store.new(directory)
	var state := _fixture()
	check(saves.save_checkpoint(state, {"purchase-1": {"ok": true, "revision": 1}}).ok, "Initial checkpoint written")
	state.revision = 2
	state.heroes[0].ore = 5
	check(saves.save_checkpoint(state, {"purchase-1": {"ok": true, "revision": 2}}).ok, "Next checkpoint atomically replaces initial")
	var loaded := saves.load_checkpoint()
	check(loaded.ok and loaded.state.heroes[0].ore == 5 and loaded.state.revision == 2, "Purchase resources and revision survive reload")
	check(loaded.command_history.has("purchase-1"), "Command result history survives reload")
	check(loaded.state.rng_states == state.rng_states, "RNG state retains exact 64-bit strings")
	var file := FileAccess.open(directory.path_join("active_run.json"), FileAccess.WRITE)
	file.store_string("broken checkpoint")
	file.close()
	loaded = saves.load_checkpoint()
	check(loaded.ok and loaded.get("recovered_backup", false) and loaded.state.revision == 1, "Damaged checkpoint recovers previous valid save")
	state.schema_version = 999
	check(not saves.save_checkpoint(state).ok, "Unknown schema rejected")
	state.schema_version = 1
	state.heroes[0].key = "UNKNOWN_HERO"
	check(not saves.save_checkpoint(state).ok, "Unknown hero content rejected")
	state.heroes[0].key = "ARDOR"
	state.heroes.append(state.heroes[0].duplicate(true))
	check(not saves.save_checkpoint(state).ok, "Duplicate seat IDs rejected")
	check(saves.save_settings({"master_volume": 0.4, "reduced_motion": true, "idle_motion": false}).ok, "Settings saved separately")
	check(saves.load_settings().idle_motion == false, "Idle motion is remembered between sessions")
	check(saves.load_settings().reduced_motion and is_equal_approx(saves.load_settings().master_volume, 0.4), "Settings roundtrip")
	check(saves.record_summary({"run_id": "test-run", "outcome": "victory"}).ok, "Summary persisted separately")
	check(saves.record_summary({"run_id": "test-run", "outcome": "victory"}).get("duplicate", false), "Completed summary cannot duplicate")
	check(saves.load_history().size() == 1, "History remains independent from checkpoint")
	saves.clear_checkpoint()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

func _wait_for(predicate: Callable, timeout_seconds: float = 4.0) -> bool:
	var started := Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - started < timeout_seconds * 1000:
		await process_frame
	return bool(predicate.call())

func _test_enet() -> void:
	var host := Session.new()
	root.add_child(host)
	var port := 26000 + (OS.get_process_id() % 2000)
	check(host.host_enet("Host", port).ok, "Development host starts")
	var clients: Array = []
	for index in 3:
		var client := Session.new()
		client.reconnect_token = Crypto.new().generate_random_bytes(32).hex_encode()
		root.add_child(client)
		clients.append(client)
		check(client.join_enet("127.0.0.1", "Guest %d" % index, port).ok, "Guest starts connection")
	check(await _wait_for(func(): return host.lobby.get("members", []).size() == 4 and clients.all(func(client): return client.status == "lobby")), "Four ENet peers complete version handshake and seat assignment")
	if host.lobby.get("members", []).size() != 4:
		for client in clients:
			client.queue_free()
		host.queue_free()
		return
	check(host.host_player_id == "lan-host" and clients.all(func(client): return client.host_player_id == "lan-host"), "Host identity is explicit on every client")
	host.choose_hero("ARDOR")
	host.set_lobby_ready(true)
	for client in clients:
		client.choose_hero("ARDOR")
		client.set_lobby_ready(true)
	check(await _wait_for(func(): return host.can_start()), "Independent readiness commands preserve all seats")
	check(host.lobby.members.all(func(member): return member.hero_id == "ARDOR"), "Duplicate hero choices remain allowed")
	var party: Array = host.start_run()
	check(party.size() == 4 and host.start_run().is_empty(), "Host starts exactly once")
	var state := _fixture()
	state.session_id = host.session_id
	state.heroes = []
	for member in party:
		state.heroes.append({"id": member.id, "key": member.hero_id, "hp": 100, "max_hp": 100, "ore": 20, "block": 0})
	host.broadcast_snapshot(state)
	check(await _wait_for(func(): return clients.all(func(client): return client.last_snapshot.get("revision") == 1)), "Full authoritative snapshot reaches all three clients")
	host.command_received.connect(func(player_id: String, command: Dictionary):
		accepted.append({"sender": player_id, "command": command})
		host.reply_command(player_id, {"ok": true, "revision": state.revision}))
	for client in clients:
		client.send_command({"command_type": "SetReady", "payload": {"player_id": "lan-host", "ready": true}})
	check(await _wait_for(func(): return accepted.size() == 3), "Concurrent commands are delivered reliably")
	check(accepted.all(func(record): return record.sender.begins_with("lan:") and record.sender != record.command.payload.player_id), "Authenticated transport identity overrides spoofed payload ownership")
	var prior_count := accepted.size()
	var peer_id: String = host._player_to_peer[clients[0].local_player_id]
	host._on_packet(peer_id, Codec.encode({"kind": "command", "command": {"protocol_version": 1, "session_id": "old", "host_epoch": 1}}))
	check(accepted.size() == prior_count, "Old-session command never reaches authority")
	state["large_payload"] = "snapshot-body|".repeat(120000)
	state.revision = 2
	host.broadcast_snapshot(state)
	check(await _wait_for(func(): return clients.all(func(client): return client.last_snapshot.get("revision") == 2), 10.0), "Snapshot larger than one MiB reassembles bounded reliable chunks")
	check(clients.all(func(client): return client.last_snapshot.get("large_payload", "") == state.large_payload), "Every snapshot chunk is preserved and hash verified")
	check(clients.all(func(client): return client._assemblies.is_empty()), "Completed snapshot assembly buffers are released")
	var malformed: Dictionary = {"host_epoch": 1, "transfer_id": "bad", "hash": "a".repeat(64), "index": 0, "count": 999999, "total_bytes": 999999999, "data": "AAAA"}
	clients[0]._receive_snapshot_chunk(malformed)
	check(clients[0]._assemblies.is_empty(), "Oversized snapshot assembly request rejected before allocation")
	var reconnect_id: String = clients[0].local_player_id
	clients[0].leave()
	check(await _wait_for(func(): return host.status == "paused"), "Controller disconnect pauses active run")
	check(not host.resume_disconnected(reconnect_id).ok, "Fallback is unavailable before 60-second grace")
	var member: Dictionary = host._find_member(reconnect_id)
	member.disconnected_at = Time.get_ticks_msec() - 61000
	check(host.resume_disconnected(reconnect_id).ok and host.status == "in_run", "Explicit fallback resumes after grace")
	check(clients[0].reconnect().ok, "Client reconnect begins with retained identity")
	check(await _wait_for(func(): return host._find_member(reconnect_id).connected and clients[0].status == "in_run"), "Reconnect restores the same reserved seat")
	check(not host._find_member(reconnect_id).fallback and host.lobby.members.size() == 4, "Reconnect replaces fallback without adding a hero")
	check(await _wait_for(func(): return clients[0].last_snapshot.get("revision") == state.revision), "Reconnect receives canonical snapshot")
	host.leave()
	check(await _wait_for(func(): return clients.all(func(client): return client.status == "recovery")), "Host departure sends all peers to recovery without promotion")
	check(clients.all(func(client): return client.last_snapshot.get("run_id") == "test-run"), "Host recovery retains last authoritative snapshot")
	for client in clients:
		client.queue_free()
	host.queue_free()
	await process_frame

func _test_separate_processes() -> void:
	var prefix := "user://enet-process-test-%d" % Time.get_ticks_usec()
	var port := 28500 + OS.get_process_id() % 1000
	var processes: Array = []
	var result_paths: Array = []
	for index in 4:
		var result_path := "%s-%d.json" % [prefix, index]
		result_paths.append(result_path)
		var role := "host" if index == 0 else "client"
		var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/test_services.gd", "--", "--peer-role=" + role, "--peer-port=" + str(port), "--peer-result=" + result_path]
		processes.append(OS.create_process(OS.get_executable_path(), args))
		if index == 0:
			await create_timer(0.2).timeout
	var completed := await _wait_for(func(): return result_paths.all(func(path): return FileAccess.file_exists(path)), 15.0)
	check(completed, "Four separate Godot processes complete network command/snapshot exchange")
	for index in result_paths.size():
		var path: String = result_paths[index]
		if FileAccess.file_exists(path):
			var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			check(result is Dictionary and result.get("ok", false), "Separate process %d converges to revision 4" % index)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		elif OS.is_process_running(processes[index]):
			OS.kill(processes[index])

func _run_process_peer(role: String) -> void:
	var port := 28500
	var result_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--peer-port="):
			port = int(argument.trim_prefix("--peer-port="))
		if argument.begins_with("--peer-result="):
			result_path = argument.trim_prefix("--peer-result=")
	var session := Session.new()
	root.add_child(session)
	var succeeded := false
	if role == "host":
		session.host_enet("Process host", port)
		session.set_lobby_ready(true)
		if await _wait_for(func(): return session.lobby.get("members", []).size() == 4 and session.can_start(), 8.0):
			session.start_run()
			var state := _fixture()
			state.session_id = session.session_id
			session.command_received.connect(func(player_id: String, _command: Dictionary):
				if player_id.begins_with("lan:"):
					state.revision += 1
					session.broadcast_snapshot(state))
			session.broadcast_snapshot(state)
			succeeded = await _wait_for(func(): return state.revision == 4, 6.0)
			await create_timer(0.3).timeout
	else:
		session.reconnect_token = Crypto.new().generate_random_bytes(32).hex_encode()
		session.join_enet("127.0.0.1", "Process guest", port)
		if await _wait_for(func(): return session.status == "lobby", 8.0):
			session.set_lobby_ready(true)
			if await _wait_for(func(): return session.last_snapshot.get("revision", 0) >= 1, 6.0):
				session.send_command({"command_type": "SetReady", "payload": {"ready": true}})
				succeeded = await _wait_for(func(): return session.last_snapshot.get("revision", 0) == 4, 6.0)
	var result := FileAccess.open(result_path, FileAccess.WRITE)
	if result != null:
		result.store_string(JSON.stringify({"ok": succeeded, "role": role}))
		result.close()
	session.queue_free()
	await process_frame
	quit(0 if succeeded else 1)
