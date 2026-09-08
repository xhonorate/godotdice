extends SceneTree
const EngineCore = preload("res://scripts/core/run_engine.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Store = preload("res://scripts/services/save_store.gd")
var checks: int = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func fresh(count: int = 1, profile: String = "short_9", seed_value: int = 927) -> RefCounted:
	var engine = EngineCore.new()
	var heroes: Array = []
	for i in count:
		heroes.append({"id":"p%s" % (i+1), "hero_id":["ARDOR", "KAIT", "MAX", "ARDOR"][i]})
	engine.new_run({"heroes":heroes, "profile":profile, "seed":seed_value, "run_id":"test-run", "autosave":false})
	return engine

func command(engine: RefCounted, player_id: String, kind: String, payload: Dictionary = {}) -> Dictionary:
	return engine.execute(player_id, engine.make_envelope(player_id, kind, payload))

func enter(engine: RefCounted, kind: String) -> void:
	engine._events = []
	engine._enter_room(kind)

func run() -> void:
	var engine = fresh()
	check(engine.state.phase == "route" and engine.state.offers.size() == 1, "run starts at required battle route")
	check(command(engine, "p1", "VoteRoom", {"offer_id":engine.state.offers[0].id}).ok, "required battle can enter")
	check(engine.state.phase == "planning" and engine.state.turn == 1, "turn begins once")
	var first: Array = engine.state.heroes[0].hand.duplicate(true)
	var reroll: Dictionary = engine.make_envelope("p1", "RerollDice", {"die_ids":[first[1].die_id]})
	check(engine.execute("p1", reroll).ok, "valid selective reroll accepted")
	var post: Array = engine.state.heroes[0].hand.duplicate(true)
	check(engine.state.heroes[0].rerolls == 0 and post[0] == first[0] and post[2] == first[2], "reroll spends once and preserves other dice")
	var rng: Dictionary = engine._rng_snapshot()
	check(engine.execute("p1", reroll).get("duplicate", false), "duplicate command returns cached outcome")
	check(engine._rng_snapshot() == rng and engine.state.heroes[0].hand == post, "duplicate consumes no random result")
	check(not command(engine,"p1","RerollDice",{"die_ids":[first[0].die_id]}).ok, "exhausted reroll rejected")
	check(engine._rng_snapshot() == rng, "rejection leaves every RNG stream unchanged")
	check(not command(engine,"p1","EquipGem",{"gem_id":"p1-g1"}).ok, "combat freezes gems")
	check(not command(engine,"intruder","SetReady",{}).ok, "wrong-owner command rejected")
	var stale: Dictionary = engine.make_envelope("p1", "SetReady", {"ready":true})
	stale.phase_id -= 1
	check(not engine.execute("p1",stale).ok, "stale phase rejected")
	stale = engine.make_envelope("p1", "SetReady", {"ready":true})
	stale.base_revision = "malformed"
	check(not engine.execute("p1",stale).ok, "malformed envelope rejected")

	engine = fresh(2)
	var id: String = engine.state.offers[0].id
	var c1: Dictionary = engine.make_envelope("p1", "VoteRoom", {"offer_id":id})
	var c2: Dictionary = engine.make_envelope("p2", "VoteRoom", {"offer_id":id})
	check(engine.execute("p1",c1).ok and engine.execute("p2",c2).ok, "independent votes tolerate advancing revisions")
	check(command(engine,"p1","SetReady",{"ready":true}).ok and engine.state.phase == "planning", "first ready waits for teammate")
	check(command(engine,"p1","SetReady",{"ready":false}).ok and not engine.state.heroes[0].ready, "ready can unlock before commitment")

	test_shop_and_services()
	test_events_and_mining()
	test_rewards_and_save()
	test_recovery_and_disconnect()
	test_schedules()
	test_campaigns()
	print("Run authority: %s checks, %s failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_shop_and_services() -> void:
	var engine = fresh(2)
	enter(engine,"shop")
	engine.state.heroes[0].gold = 200
	engine.state.heroes[1].gold = 200
	var offers: Dictionary = engine.state.shop.duplicate(true)
	var first: Dictionary = engine.make_envelope("p1","BuyGem",{"offer_id":offers.p1.gems[0].id})
	var second: Dictionary = engine.make_envelope("p2","BuyGem",{"offer_id":offers.p2.gems[0].id})
	check(engine.execute("p1",first).ok and engine.execute("p2",second).ok, "concurrent personal purchases preserve both inventories")
	check(engine.state.heroes[0].gems.size() == 4 and engine.state.heroes[1].gems.size() == 4, "purchases grant one owned item")
	check(not command(engine,"p1","BuyGem",{"offer_id":offers.p2.gems[1].id}).ok, "cannot buy someone else's offer")
	var gold: int = engine.state.heroes[0].gold
	engine.execute("p1",first)
	check(engine.state.heroes[0].gold == gold, "replayed purchase cannot spend twice")
	check(not command(engine,"p1","SellGem",{"gem_id":"p1-g0"}).ok, "last Strike cannot be sold")
	var replacement: Dictionary = Catalog.gem("STRIKE","replacement",8,2,2)
	engine.state.heroes[0].gems.append(replacement)
	check(command(engine,"p1","EquipGem",{"gem_id":"replacement"}).ok, "better Strike replaces starting Strike atomically")
	check(command(engine,"p1","SellGem",{"gem_id":"p1-g0"}).ok, "old reserve Strike may be sold")
	check(command(engine,"p1","BuyDie",{"offer_id":offers.p1.dice[0].id}).ok, "featured die purchases into reserve")
	var reserve_id: String = engine.state.heroes[0].reserve_dice[0].id
	check(command(engine,"p1","SwapDie",{"active_id":"p1-d0","reserve_id":reserve_id}).ok and engine.state.heroes[0].dice.size() == 5, "die swap preserves five active slots")
	engine.state.heroes[0].relics = [{"id":"belt", "key":"TINKERS_BELT", "equipped":true}]
	enter(engine,"workshop")
	gold = engine.state.heroes[0].gold
	var die: Dictionary = engine.state.heroes[0].dice[1]
	check(command(engine,"p1","ModifyDie",{"die_id":die.id,"service":"face","face_index":0,"value":6}).ok, "engraving permits repeated face values")
	check(engine.state.heroes[0].gold == gold and engine.state.heroes[0].tinker_used_acts == [1], "Tinker free act charge spent once")
	check(not command(engine,"p1","ModifyDie",{"die_id":die.id,"service":"face","face_index":1,"value":6}).ok, "Workshop one-service limit")
	enter(engine,"workshop")
	check(command(engine,"p1","ModifyDie",{"die_id":die.id,"service":"shape","shape":"D8"}).ok, "adjacent shape replacement accepted")
	check(engine.state.heroes[0].gold == gold-5, "Tinker charge stays consumed across visits")
	check(engine.state.heroes[0].dice[1].faces[0].value == 1, "shape replacement discards engraving")
	enter(engine,"lapidary")
	gold = engine.state.heroes[0].gold
	check(command(engine,"p1","UpgradeGem",{"gem_id":"replacement","property":"clarity"}).ok, "Lapidary upgrades owned gem")
	check(engine.state.heroes[0].gold == gold-15, "Lapidary uses new rank cost")
	check(not command(engine,"p1","UpgradeGem",{"gem_id":"replacement","property":"cut"}).ok, "Lapidary one-service limit")

func test_events_and_mining() -> void:
	var engine = fresh(2,"expedition_18")
	enter(engine,"event")
	engine.state.event.key = "ABANDONED_CACHE"
	engine.state.heroes[0].hp = 8
	var before: Dictionary = engine.state.duplicate(true)
	check(not command(engine,"p1","EventChoice",{"option":"b"}).ok and engine.state.heroes[0].hp == 8, "cache at exactly 8 HP rejects cost")
	check(engine.state.heroes[0].gems.size() == before.heroes[0].gems.size(), "failed event grants no gem")
	check(command(engine,"p1","EventChoice",{"option":"a"}).ok and engine.state.heroes[0].gold == 6, "safe event reward")
	check(not command(engine,"p1","EventChoice",{"option":"a"}).ok, "event transaction settles once")
	enter(engine,"mine")
	check(command(engine,"p1","VoteVein",{"vein":"crystal"}).ok, "mine awaits party vein vote")
	var last: Dictionary = engine.make_envelope("p2","VoteVein",{"vein":"crystal"})
	check(engine.execute("p2",last).ok, "mine vein commits")
	var rocks: Array = engine.state.mine.rocks.duplicate(true)
	var mine_gold: int = engine.state.mine.gold
	check(rocks.size() == 12 and engine.state.mine.events.size() <= 20, "mine generates six rocks and ten energy per hero")
	check(engine.execute("p2",last).get("duplicate", false) and engine.state.mine.rocks == rocks, "mine retry cannot regenerate rocks")
	check(engine.state.heroes[0].gold+engine.state.heroes[1].gold == mine_gold+6, "mined gold pooled and fully allocated")
	if engine.state.phase == "mine_draft":
		var claim: String = engine.state.mine.pool[0].claim_id
		var picker: String = engine.state.mine.picker_id
		check(not command(engine,"p2" if picker == "p1" else "p1","DraftGem",{"claim_id":claim}).ok, "only current picker can draft")
		check(command(engine,picker,"DraftGem",{"claim_id":claim}).ok, "current picker receives gem")
		check(not command(engine,picker,"DraftGem",{"claim_id":claim}).ok, "mine claim cannot be replayed with new ID")
	while engine.state.phase == "mine_draft":
		command(engine,engine.state.mine.picker_id,"DraftGem",{"claim_id":engine.state.mine.pool[0].claim_id})
	check(engine.state.phase == "support", "empty draft exposes Done")
	enter(engine,"rest")
	check(engine.state.heroes[0].hp == 41, "rest heals floor(maxHP/3)")

func test_rewards_and_save() -> void:
	var engine = fresh(2)
	enter(engine,"battle")
	engine.state.heroes[1].hp = 0
	engine.state.heroes[0].block = 20
	engine.state.heroes[0].relics.append({"id":"aegis", "key":"LASTING_AEGIS", "equipped":true, "stored_block":0})
	engine._battle_rewards()
	check(engine.state.heroes[1].hp == 7 and engine.state.heroes[1].gold == 10, "downed Kait rallies and retains reward entitlement")
	check(engine.state.heroes[0].block == 0 and engine.state.heroes[0].relics[0].stored_block == 6, "Aegis captures before cleanup")
	var gold: int = engine.state.heroes[0].gold
	engine._battle_rewards()
	check(engine.state.heroes[0].gold == gold, "room reward cannot settle twice")
	check(not command(engine,"p1","SetReady",{"ready":true}).ok, "mandatory reward requires choice or decline")
	check(command(engine,"p1","ChooseReward",{"kind":"gem","offer_id":""}).ok and engine.state.heroes[0].gold == gold+3, "declined gem grants 3 separate reward gold")
	engine._checkpoint()
	var snapshot: Dictionary = engine.state.duplicate(true)
	var restored = EngineCore.new()
	restored.autosave = false
	check(restored.restore(snapshot,engine.command_history).ok, "checkpoint schema accepted")
	check(restored._rng_snapshot() == engine._rng_snapshot(), "RNG streams roundtrip losslessly")
	var a: Array = engine._generate_gems(3)
	var b: Array = restored._generate_gems(3)
	check(a == b, "save reload preserves future loot sequence")
	var saved = Store.new("user://tests/authority-save")
	check(saved.save_checkpoint(snapshot,engine.command_history).ok, "real JSON checkpoint writes atomically")
	var loaded: Dictionary = saved.load_checkpoint()
	check(loaded.ok and EngineCore.validate_state(loaded.state).is_empty(), "real JSON checkpoint passes full validation")
	check(restored.restore(loaded.state,loaded.command_history).ok, "JSON checkpoint can resume authority")
	saved.clear_checkpoint()
	enter(engine,"battle")
	check(engine.state.heroes[0].block == 6 and engine.state.heroes[0].relics[0].stored_block == 0, "stored block consumed once next encounter")

func test_recovery_and_disconnect() -> void:
	var engine = fresh(2)
	enter(engine,"battle")
	var good: Dictionary = engine.make_envelope("p1","SetPreferredTarget",{"unit_id":engine.state.enemies[0].id})
	check(engine.execute("p1",good).ok, "target command accepted before resume")
	var original: Dictionary = engine.state.duplicate(true)
	var history: Dictionary = engine.command_history.duplicate(true)
	var restored = EngineCore.new()
	restored.autosave = false
	check(restored.restore(original,history,"new-session").ok, "canonical checkpoint opens under new session")
	check(not restored.execute("p1",good).ok, "cached command from prior session rejected after resume")
	check(restored.state.paused and not restored.state.heroes[1].connected, "resumed network run reserves and pauses absent seats")
	check(not command(restored,"p1","ResumeDisconnected",{"player_id":"p2"}).ok, "fallback forbidden during grace period")
	restored.state.heroes[1].disconnect_time = Time.get_unix_time_from_system()-61
	check(command(restored,"p1","ResumeDisconnected",{"player_id":"p2"}).ok, "host explicitly enables fallback after grace")
	check(not restored.state.paused and restored.state.heroes[1].fallback, "fallback resumes authority")
	check(restored.set_controller_connected("p2",true).ok and not restored.state.heroes[1].fallback, "reconnect restores same controller seat")
	var corrupted: Dictionary = original.duplicate(true)
	corrupted.heroes[0].gems = "broken"
	check(not EngineCore.validate_state(corrupted).is_empty(), "corrupt nested inventory rejected without crashing")
	corrupted = original.duplicate(true)
	corrupted.heroes[0].dice[0].faces[0] = null
	check(not EngineCore.validate_state(corrupted).is_empty(), "corrupt face object rejected without crashing")
	var same_a = fresh()
	var same_b = fresh()
	var route: Dictionary = same_a.make_envelope("p1","VoteRoom",{"offer_id":same_a.state.offers[0].id})
	check(same_a.execute("p1",route).ok and same_b.execute("p1",route).ok, "same seeded command accepted by independent authorities")
	check(same_a.state == same_b.state, "same seed and accepted sequence produce identical complete state")
	var roll: Dictionary = same_a.make_envelope("p1","RerollDice",{"die_ids":[same_a.state.heroes[0].dice[0].id]})
	same_a.execute("p1",roll)
	same_b.execute("p1",roll)
	check(same_a.state == same_b.state, "deterministic reroll events and RNG states match")

func test_schedules() -> void:
	for profile in ["short_9", "expedition_18"]:
		var engine = fresh(1,profile)
		for room in range(1,10 if profile == "short_9" else 19):
			engine.state.room_index = room
			engine._route_offers()
			var offers: Array = engine.state.offers
			var keys: Array = []
			for offer in offers: keys.append(offer.kind)
			check(keys.size() == 1 or keys.size() == 3, "route offers have required one or distinct three")
			check(keys.size() == 1 or (keys[0] in ["battle","elite"] and keys[0] != keys[1] and keys[1] != keys[2] and keys[0] != keys[2]), "variable route distinct and contains combat")
			if profile == "expedition_18" and (room-1)%6+1 == 4:
				check("shop" in keys, "unseen shop guaranteed in act room four")

func test_campaigns() -> void:
	# A deterministic overpowering fixture exercises every phase through final settlement;
	# it is deliberately separate from balance tests with unmodified starting heroes.
	for profile in ["short_9", "expedition_18"]:
		for count in range(1,5):
			var engine = fresh(count,profile,12345)
			for hero in engine.state.heroes:
				hero.max_hp = 10000
				hero.hp = 10000
				hero.gems[0].carat = 24
				hero.gems[0].cut = 5
				hero.gems[0].clarity = 5
			var decisions: int = 0
			while engine.state.phase != "summary" and decisions < 1600:
				decisions += 1
				match engine.state.phase:
					"route":
						var offer_id: String = engine.state.offers[0].id
						for hero in engine.state.heroes:
							if engine.state.phase == "route": command(engine,hero.id,"VoteRoom",{"offer_id":offer_id})
					"planning":
						var phase: int = engine.state.phase_id
						for hero in engine.state.heroes:
							if engine.state.phase_id == phase and hero.hp > 0: command(engine,hero.id,"SetReady",{"ready":true})
					"reward":
						for hero in engine.state.heroes:
							if engine.state.phase != "reward": break
							var reward: Dictionary = engine.state.reward_offers[hero.id]
							for kind in ["gem","relic"]:
								if not reward[kind+"_done"]: command(engine,hero.id,"ChooseReward",{"kind":kind,"offer_id":""})
							command(engine,hero.id,"SetReady",{"ready":true})
					"support":
						for hero in engine.state.heroes:
							if engine.state.phase == "support": command(engine,hero.id,"SetReady",{"ready":true})
					_: break
			check(engine.state.phase == "summary" and engine.state.outcome == "victory", "%s completes with %s heroes" % [profile,count])
			check(engine.state.room_index == (9 if profile == "short_9" else 18), "campaign ends at named profile's final boss")
			var total: int = engine.state.heroes[0].gold
			engine._battle_rewards()
			check(engine.state.heroes[0].gold == total, "final boss reward settles once")
