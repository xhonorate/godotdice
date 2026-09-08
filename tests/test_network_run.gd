extends SceneTree
## Full authority + independent ENet peers; scenes and playback are absent.
const Session = preload("res://scripts/services/session.gd")
const Authority = preload("res://scripts/core/run_engine.gd")
const Codec = preload("res://scripts/services/packet_codec.gd")
var checks := 0
var failures: Array = []
var replies: Array = []

func _initialize() -> void:
 run.call_deferred()

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures.append(message)
  push_error(message)

func until(predicate: Callable, seconds: float = 5.0) -> bool:
 var start := Time.get_ticks_msec()
 while not predicate.call() and Time.get_ticks_msec() - start < seconds * 1000:
  await process_frame
 return bool(predicate.call())

func run() -> void:
 var host := Session.new()
 root.add_child(host)
 var port := 30500 + OS.get_process_id() % 1000
 check(host.host_enet("Host", port).ok, "Real-run host starts")
 var peers: Array = [host]
 for index in 3:
  var client := Session.new()
  client.reconnect_token = Crypto.new().generate_random_bytes(32).hex_encode()
  root.add_child(client)
  peers.append(client)
  client.join_enet("127.0.0.1", "Hero %d" % index, port)
 check(await until(func(): return host.lobby.members.size() == 4 and peers.all(func(peer): return peer.status == "lobby")), "Party authenticates before run")
 for index in peers.size():
  peers[index].choose_hero(["ARDOR", "KAIT", "MAX", "ARDOR"][index])
  peers[index].set_lobby_ready(true)
 check(await until(func(): return host.can_start()), "Four distinct controllers become ready")
 var engine := Authority.new()
 engine.changed.connect(host.broadcast_snapshot)
 host.command_received.connect(func(player_id: String, command: Dictionary):
  var result := engine.execute(player_id, command)
  replies.append(result)
  host.reply_command(player_id, result))
 host.controller_connection_changed.connect(func(player_id: String, connected: bool):
  if not engine.state.is_empty(): engine.set_controller_connected(player_id, connected))
 var seats: Array = host.start_run()
 var state: Dictionary = engine.new_run({"heroes":seats,"seed":87261,"session_id":host.session_id,"host_id":host.host_player_id,"autosave":false})
 check(not state.is_empty() and state.get("phase") == "route", "Authority initializes from authenticated seats")
 check(await until(func(): return peers.all(func(peer): return peer.last_snapshot.get("phase") == "route")), "Initial complete run snapshot reaches every peer")
 var route_id: String = engine.state.offers[0].id
 for peer in peers:
  peer.send_command({"command_type":"VoteRoom","payload":{"offer_id":route_id}})
 check(await until(func(): return engine.state.phase == "planning" and peers.all(func(peer): return peer.last_snapshot.get("phase") == "planning")), "Transport votes enter actual combat and publish intents")
 check(replies.size() == 4 and replies.all(func(reply): return reply.ok), "Independent route commands all accepted")
 var roundtrip := Codec.decode(Codec.encode({"kind":"snapshot","state":engine.state}))
 check(roundtrip.ok and Codec.snapshot_hash(roundtrip.packet.state) == Codec.snapshot_hash(engine.state), "Full battle metadata/events/intents pass bounded JSON hash roundtrip")
 check(Authority.validate_state(roundtrip.packet.state).is_empty(), "Transport snapshot passes authority save validator")
 var bad: Dictionary = engine.state.duplicate(true)
 bad.heroes[0].gems = [42]
 check(not Authority.validate_state(bad).is_empty(), "Malformed nested gem safely rejected")
 bad = engine.state.duplicate(true)
 bad.heroes[0].dice[0].faces = [42]
 check(not Authority.validate_state(bad).is_empty(), "Malformed nested face safely rejected")
 bad = engine.state.duplicate(true)
 bad.heroes[0].gems[0].equipped = false
 check(not Authority.validate_state(bad).is_empty(), "Attackless loadout rejected on restore")
 bad = engine.state.duplicate(true)
 bad.heroes[0].gold = 1.5
 check(not Authority.validate_state(bad).is_empty(), "Fractional resource rejected on restore")
 var before_rng: Dictionary = engine._rng_snapshot()
 peers[1].send_command({"command_type":"RerollDice","payload":{"die_ids":[engine.state.heroes[0].dice[0].id]}})
 check(await until(func(): return replies.size() == 5), "Invalid ownership command returns a result")
 check(not replies.back().ok and engine._rng_snapshot() == before_rng, "Another hero's die cannot consume RNG or reroll budget")
 for index in peers.size():
  peers[index].send_command({"command_type":"RerollDice","payload":{"die_ids":[engine._hero(peers[index].local_player_id).dice[0].id]}})
 check(await until(func(): return engine.state.statistics.rerolls == 4), "Four concurrent owned rerolls commit independently")
 check(await until(func(): return peers.all(func(peer): return peer.last_snapshot.get("revision", -1) == engine.state.revision)), "All clients converge after independent rerolls")
 check(engine.state.heroes.all(func(hero): return hero.rerolls == 0), "Every reroll budget is consumed exactly once")
 for peer in peers:
  peer.send_command({"command_type":"SetReady","payload":{"ready":true}})
 check(await until(func(): return engine.state.revision >= 12), "Four lock-ins resolve through authority")
 check(await until(func(): return peers.all(func(peer): return Codec.snapshot_hash(peer.last_snapshot) == Codec.snapshot_hash(engine.state))), "All clients converge on actual resolved combat without animation")
 check(engine.state.turn >= 2 or engine.state.phase in ["reward", "summary"], "Actual combat advances after complete party lock-in")
 var ping_records: Array = []
 peers[2].party_ping.connect(func(player_id: String, subject_id: String, label: String): ping_records.append([player_id, subject_id, label]))
 var before_ping: int = engine.state.revision
 peers[1].send_ping("example", "Inspect this gem")
 check(await until(func(): return ping_records.size() == 1), "Authenticated party ping reaches another client")
 check(ping_records[0][0] == peers[1].local_player_id and engine.state.revision == before_ping, "Ping identifies transport sender without changing game state")
 for peer in peers:
  peer.leave()
  peer.queue_free()
 await process_frame
 print("Network authority: %d checks, %d failures" % [checks, failures.size()])
 quit(0 if failures.is_empty() else 1)
