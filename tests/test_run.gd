extends SceneTree
const EngineCore = preload("res://scripts/core/run_engine.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Seam = preload("res://scripts/core/seam.gd")
const Profile = preload("res://scripts/core/profile.gd")
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

func fresh(count: int = 1, mine_id: String = "QUARRY", seed_value: int = 927, extra: Dictionary = {}) -> RefCounted:
	var engine = EngineCore.new()
	var heroes: Array = []
	for i in count:
		heroes.append({"id":"p%s" % (i+1), "hero_id":["ARDOR", "KAIT", "MAX", "ARDOR"][i]})
	var config: Dictionary = {"heroes":heroes, "mine_id":mine_id, "seed":seed_value, "run_id":"test-run", "autosave":false}
	config.merge(extra, true)
	engine.new_run(config)
	return engine

func command(engine: RefCounted, player_id: String, kind: String, payload: Dictionary = {}) -> Dictionary:
	return engine.execute(player_id, engine.make_envelope(player_id, kind, payload))

func enter(engine: RefCounted, kind: String) -> void:
	engine._events = []
	engine._enter_room(kind)

func at_depth(engine: RefCounted, depth: int) -> void:
	## Stands the party in the first chamber of a layer, the way a walk down would.
	Seam.ensure_layers(engine.state.seam, engine.state.seed, engine.state.mine_id, "", depth + Seam.LOOKAHEAD)
	engine.state.depth = depth
	engine.state.deepest = maxi(int(engine.state.deepest), depth)
	engine.state.position = engine.state.seam.layers[str(depth)][0].id if depth > 0 else Seam.SURFACE

func found_gem(engine: RefCounted, seat: int, key: String, id: String, appraised: bool) -> Dictionary:
	var gem: Dictionary = Catalog.gem(key, id, 6, 2, 2)
	gem.found = true
	gem.appraised = appraised
	gem.owner_id = engine.state.heroes[seat].id
	if appraised: engine.state.heroes[seat].gems.append(gem)
	else: engine.state.heroes[seat].haul.append(gem)
	return gem

func run() -> void:
	var engine = fresh()
	check(engine.state.phase == "route" and engine.state.position == Seam.SURFACE and engine.state.depth == 0, "an expedition starts at the mine mouth")
	check(engine.state.offers.size() >= 3 and engine.state.offers.all(func(offer: Dictionary) -> bool: return offer.kind in ["battle", "mine", "lift"] and offer.depth == 1), "the first layer offers only fights and rock")
	check(int(engine.state.seam.deepest) == Seam.LOOKAHEAD, "the seam is generated a lantern's worth ahead")
	var battle_offer: Dictionary = {}
	for offer in engine.state.offers:
		if offer.kind == "battle" and battle_offer.is_empty(): battle_offer = offer
	if battle_offer.is_empty():
		engine.state.seam.layers["1"][0].kind = "battle"
		engine._route_offers()
		battle_offer = engine.state.offers[0]
	check(command(engine, "p1", "VoteRoom", {"offer_id":battle_offer.id}).ok, "a tunnel can be taken")
	check(engine.state.phase == "planning" and engine.state.turn == 1 and engine.state.depth == 1 and engine.state.position == battle_offer.id, "the party stands in the chamber it chose")
	check(int(engine.state.tremor) > 0, "walking down a tunnel stirs the tremor meter")
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
	check(not command(engine,"p1","VoteRoom",{"offer_id":"d9c9"}).ok, "a chamber that is not open from here is refused")

	test_seam()
	test_loadouts()
	test_shop_and_services()
	test_appraisal()
	test_events_and_mining()
	test_rewards_and_save()
	test_tremor_and_boss()
	test_lift()
	test_salvage()
	test_recovery_and_disconnect()
	test_wager_hall()
	test_crucible()
	test_descriptions()
	test_expeditions()
	print("Run authority: %s checks, %s failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_seam() -> void:
	var near: Dictionary = {}
	Seam.ensure_layers(near, "seed", "QUARRY", "", 12)
	var far: Dictionary = {}
	Seam.ensure_layers(far, "seed", "QUARRY", "", 4)
	Seam.ensure_layers(far, "seed", "QUARRY", "", 12)
	check(near == far, "a seam comes out the same however far ahead it was dug")
	var other: Dictionary = {}
	Seam.ensure_layers(other, "other seed", "QUARRY", "", 12)
	check(other != near, "a different seed digs a different seam")
	for depth in range(1, 12):
		var upper: Array = near.layers[str(depth)]
		var lower: Array = near.layers[str(depth + 1)]
		check(upper.size() >= 3 and upper.size() <= 5, "a layer holds three to five chambers")
		var entered: Dictionary = {}
		var edges: Array = []
		for a in range(upper.size()):
			check(not upper[a].links.is_empty(), "every chamber has a way down")
			for link in upper[a].links:
				entered[link] = true
				var b: int = lower.map(func(node: Dictionary) -> String: return node.id).find(link)
				check(b >= 0, "a tunnel leads to the next layer")
				edges.append([a, b])
		check(entered.size() == lower.size(), "every chamber has a way in")
		var crossing: bool = false
		for e in edges:
			for f in edges:
				if (e[0] < f[0] and e[1] > f[1]): crossing = true
		check(not crossing, "tunnels never cross")
	check(near.layers["1"].all(func(node: Dictionary) -> bool: return node.kind in ["battle", "mine"]), "the first layer is only fights and rock")
	var quarry: Dictionary = Catalog.mine_definition("QUARRY")
	check(Seam.lift_layers(quarry, 25) == [2, 5, 8, 12, 17, 23], "the Quarry's lifts widen with depth")
	check(Seam.lift_layers(Catalog.mine_definition("RIFT_HOLLOW"), 25).size() < 6, "a mine with a low lift rate has fewer guaranteed lifts")
	for depth in Seam.lift_layers(quarry, 12):
		check(near.layers[str(depth)].any(func(node: Dictionary) -> bool: return node.kind == "lift"), "a guaranteed lift appears at depth %d" % depth)
	check(not Seam.room_weights(quarry, 5, "no_camps").has("rest"), "No Camps removes camps")
	check(int(Seam.room_weights(quarry, 5, "elite_depths").elite) == 2 * int(quarry.rooms.elite), "Elite Depths doubles elites")
	check(not Seam.room_weights(quarry, 2, "").has("elite"), "elites wait for the third layer")
	check(Seam.silhouette("elite") == "hostile" and Seam.silhouette("treasure") == "glint" and Seam.silhouette("lift") == "lift", "rooms read as silhouettes beyond the lantern")
	check(Seam.sight("", true) == 3 and Seam.sight("dim_lanterns", false) == 1, "the lantern and dim lanterns change sight")
	check(Seam.tremor_for_move(Catalog.mine_definition("RIFT_HOLLOW"), 5, "") > Seam.tremor_for_move(quarry, 5, ""), "a faster mine shakes harder")
	check(Seam.tremor_for_move(quarry, 10, "") > Seam.tremor_for_move(quarry, 1, ""), "deeper steps shake harder")
	check(Profile.SPECIAL_MODIFIERS.size() == Seam.MODIFIERS.size(), "the profile and engine agree on special conditions")
	for key in Seam.MODIFIERS:
		check(Profile.SPECIAL_MODIFIERS.has(key), "the profile describes %s" % key)
	check(fresh(1, "QUARRY", 1, {"special":{"id":"s", "modifier":"nonsense"}}).state.is_empty(), "unknown special conditions are refused")
	check(fresh(1, "NOWHERE").state.is_empty(), "an unknown mine is refused")

func test_loadouts() -> void:
	var loadout: Array = [{"key":"STRIKE", "carat":12, "cut":4, "clarity":3}, {"key":"VENOM", "carat":5, "cut":2, "clarity":2}]
	var engine = fresh(1, "QUARRY", 3, {"heroes":[{"id":"p1", "hero_id":"MAX", "loadout":loadout}]})
	var hero: Dictionary = engine.state.heroes[0]
	check(hero.gems.size() == 2 and int(hero.gems[0].carat) == 12 and hero.gems[1].key == "VENOM", "a profile loadout replaces the starting gems")
	check(hero.gems.all(func(gem: Dictionary) -> bool: return gem.loadout and gem.equipped and gem.owner_id == "p1"), "loadout gems arrive equipped and marked")
	check(EngineCore.validate_state(engine.state).is_empty(), "a loadout expedition is a valid saved state")
	check(fresh(1, "QUARRY", 3, {"heroes":[{"id":"p1", "hero_id":"MAX", "loadout":[]}]}).state.heroes[0].gems.size() == Catalog.definitions("heroes").MAX.starting_gems.size(), "an empty loadout falls back to the hero's starting gems")
	for broken in [[{"key":"VENOM", "carat":5}], [{"key":"STRIKE", "carat":30}], [{"key":"STRIKE"}, {"key":"STRIKE"}], "not a list"]:
		check(fresh(1, "QUARRY", 3, {"heroes":[{"id":"p1", "hero_id":"MAX", "loadout":broken}]}).state.is_empty(), "an invalid loadout is refused: %s" % str(broken))

func test_shop_and_services() -> void:
	var engine = fresh(2)
	at_depth(engine, 6)
	enter(engine,"shop")
	engine.state.heroes[0].ore = 200
	engine.state.heroes[1].ore = 200
	var offers: Dictionary = engine.state.shop.duplicate(true)
	check(offers.p1.gems.all(func(offer: Dictionary) -> bool: return offer.gem.appraised and offer.gem.found), "merchant gems are appraised finds")
	check(offers.p1.gems.all(func(offer: Dictionary) -> bool: return offer.gem.key in engine.state.seen_gems.p1), "seeing a merchant's gem counts as seeing it")
	check(not offers.p1.dice.is_empty(), "a merchant at depth 6 stocks a die")
	var first: Dictionary = engine.make_envelope("p1","BuyGem",{"offer_id":offers.p1.gems[0].id})
	var second: Dictionary = engine.make_envelope("p2","BuyGem",{"offer_id":offers.p2.gems[0].id})
	check(engine.execute("p1",first).ok and engine.execute("p2",second).ok, "concurrent personal purchases preserve both inventories")
	check(engine.state.heroes[0].gems.size() == 4 and engine.state.heroes[1].gems.size() == 4, "purchases grant one owned item")
	check(not command(engine,"p1","BuyGem",{"offer_id":offers.p2.gems[1].id}).ok, "cannot buy someone else's offer")
	var ore: int = engine.state.heroes[0].ore
	engine.execute("p1",first)
	check(engine.state.heroes[0].ore == ore, "replayed purchase cannot spend twice")
	check(command(engine,"p1","BuyLoupe",{}).ok and engine.state.heroes[0].loupes == 1, "a loupe can be bought")
	check(not command(engine,"p1","BuyLoupe",{}).ok, "one loupe per visit")
	check(not command(engine,"p1","SellGem",{"gem_id":"p1-g1"}).ok, "a loadout gem cannot be sold")
	var bought_id: String = str(engine.state.heroes[0].gems[3].id)
	check(engine.state.heroes[0].gems[3].equipped, "a bought gem drops into an open socket by itself")
	ore = engine.state.heroes[0].ore
	check(command(engine,"p1","SellGem",{"gem_id":bought_id}).ok and engine.state.heroes[0].ore > ore, "a found gem sells for ore")
	check(command(engine,"p1","BuyDie",{"offer_id":offers.p1.dice[0].id}).ok, "featured die purchases into reserve")
	var reserve_id: String = engine.state.heroes[0].reserve_dice[0].id
	check(command(engine,"p1","SwapDie",{"active_id":"p1-d0","reserve_id":reserve_id}).ok and engine.state.heroes[0].dice.size() == 5, "die swap preserves five active slots")
	engine.state.heroes[0].relics = [{"id":"belt", "key":"TINKERS_BELT", "equipped":true}]
	enter(engine,"workshop")
	ore = engine.state.heroes[0].ore
	var die: Dictionary = engine.state.heroes[0].dice[1]
	check(command(engine,"p1","ModifyDie",{"die_id":die.id,"service":"face","face_index":0,"value":6}).ok, "engraving permits repeated face values")
	check(engine.state.heroes[0].ore == ore and engine.state.heroes[0].tinker_used, "Tinker's free service is spent once")
	check(not command(engine,"p1","ModifyDie",{"die_id":die.id,"service":"face","face_index":1,"value":6}).ok, "Workshop one-service limit")
	enter(engine,"workshop")
	check(command(engine,"p1","ModifyDie",{"die_id":die.id,"service":"shape","shape":"D8"}).ok, "adjacent shape replacement accepted")
	check(engine.state.heroes[0].ore == ore-5, "Tinker's charge stays consumed across visits")
	check(engine.state.heroes[0].dice[1].faces[0].value == 1, "shape replacement discards engraving")
	enter(engine,"lapidary")
	ore = engine.state.heroes[0].ore
	check(command(engine,"p1","UpgradeGem",{"gem_id":"p1-g0","property":"clarity"}).ok, "Lapidary upgrades an owned gem")
	check(engine.state.heroes[0].ore == ore-10, "Lapidary uses new rank cost")
	check(not command(engine,"p1","UpgradeGem",{"gem_id":"p1-g0","property":"cut"}).ok, "Lapidary one-service limit")

func test_appraisal() -> void:
	var engine = fresh(1)
	at_depth(engine, 4)
	enter(engine, "rest")
	var stone: Dictionary = found_gem(engine, 0, "VENOM", "stone-1", false)
	check(not command(engine,"p1","EquipGem",{"gem_id":"stone-1"}).ok, "an unappraised stone cannot be equipped")
	check(not command(engine,"p1","AppraiseGem",{"gem_id":"stone-1","method":"loupe"}).ok, "appraising needs a loupe")
	engine.state.heroes[0].loupes = 1
	check(command(engine,"p1","AppraiseGem",{"gem_id":"stone-1","method":"loupe"}).ok, "a loupe appraises a stone")
	var hero: Dictionary = engine.state.heroes[0]
	check(hero.haul.is_empty() and hero.loupes == 0 and gem_of(engine, 0, "stone-1").appraised, "the stone moves from the haul to the gem bag, appraised")
	check("VENOM" in engine.state.seen_gems.p1, "an appraised stone is seen")
	check(gem_of(engine, 0, "stone-1").equipped, "an appraised find takes an open socket at once")
	enter(engine, "lapidary")
	found_gem(engine, 0, "HEAL", "stone-2", false)
	engine.state.heroes[0].ore = 4
	check(not command(engine,"p1","AppraiseGem",{"gem_id":"stone-2","method":"lapidary"}).ok, "Lapidary appraisal costs ore")
	engine.state.heroes[0].ore = 20
	check(command(engine,"p1","AppraiseGem",{"gem_id":"stone-2","method":"lapidary"}).ok and engine.state.heroes[0].ore == 20 - EngineCore.APPRAISE_PRICE, "Lapidary appraisal is paid")
	found_gem(engine, 0, "MEND", "stone-3", false)
	engine.state.heroes[0].ore = 20
	check(command(engine,"p1","AppraiseGem",{"gem_id":"stone-3","method":"lapidary"}).ok, "appraisal does not use up the Lapidary's one service")
	check(EngineCore.validate_state(engine.state).is_empty(), "appraised finds are a valid saved state")
	var broken: Dictionary = engine.state.duplicate(true)
	var bad: Dictionary = Catalog.gem("HEAL", "bad", 1, 1, 1)
	bad.found = true
	bad.appraised = true
	broken.heroes[0].haul.append(bad)
	check(not EngineCore.validate_state(broken).is_empty(), "an appraised stone in the haul is refused")

func test_events_and_mining() -> void:
	var engine = fresh(2)
	at_depth(engine, 3)
	enter(engine,"event")
	engine.state.event.key = "ABANDONED_CACHE"
	engine.state.heroes[0].hp = 8
	var before: Dictionary = engine.state.duplicate(true)
	check(not command(engine,"p1","EventChoice",{"option":"b"}).ok and engine.state.heroes[0].hp == 8, "cache at exactly 8 HP rejects cost")
	check(engine.state.heroes[0].gems.size() == before.heroes[0].gems.size(), "failed event grants no gem")
	check(command(engine,"p1","EventChoice",{"option":"a"}).ok and engine.state.heroes[0].ore == 6, "safe event reward")
	check(not command(engine,"p1","EventChoice",{"option":"a"}).ok, "event transaction settles once")
	enter(engine,"event")
	engine.state.event.key = "STILL_POOL"
	engine.state.tremor = 600
	check(command(engine,"p1","EventChoice",{"option":"b"}).ok and engine.state.tremor == 600 - EngineCore.STILL_POOL_CALM, "the still pool calms the tremors")
	check(not command(engine,"p2","EventChoice",{"option":"b"}).ok and engine.state.tremor == 600 - EngineCore.STILL_POOL_CALM, "the pool only calms once a visit")
	enter(engine,"event")
	engine.state.event.key = "JEWEL_BROKER"
	engine.state.event.offers.p1 = engine._roll_gems(3, 0, true)
	check(not command(engine,"p1","EventChoice",{"option":"b","gem_id":"p1-g1","offer_id":engine.state.event.offers.p1[0].id}).ok, "the broker never takes a loadout gem")
	found_gem(engine, 0, "HEAL", "blind-stone", false)
	check(command(engine,"p1","EventChoice",{"option":"b","gem_id":"blind-stone","offer_id":engine.state.event.offers.p1[0].id}).ok, "the broker trades an unappraised stone")
	check(engine.state.heroes[0].haul.is_empty() and engine.state.heroes[0].gems[-1].appraised, "the traded stone is replaced by an appraised gem")
	enter(engine,"mine")
	check(command(engine,"p1","VoteVein",{"vein":"crystal"}).ok, "mine awaits party vein vote")
	var last: Dictionary = engine.make_envelope("p2","VoteVein",{"vein":"crystal"})
	var ore_before: int = engine.state.heroes[0].ore + engine.state.heroes[1].ore
	check(engine.execute("p2",last).ok, "mine vein commits")
	var rocks: Array = engine.state.mine.rocks.duplicate(true)
	var mine_ore: int = engine.state.mine.ore
	check(rocks.size() == 12 and engine.state.mine.events.size() <= 20, "mine generates six rocks and ten energy per hero")
	check(engine.execute("p2",last).get("duplicate", false) and engine.state.mine.rocks == rocks, "mine retry cannot regenerate rocks")
	check(engine.state.heroes[0].ore + engine.state.heroes[1].ore == mine_ore + ore_before, "mined ore pooled and fully allocated")
	if engine.state.phase == "mine_draft":
		var claim: String = engine.state.mine.pool[0].claim_id
		var picker: String = engine.state.mine.picker_id
		check(not command(engine,"p2" if picker == "p1" else "p1","DraftGem",{"claim_id":claim}).ok, "only current picker can draft")
		var haul_before: int = engine._hero(picker).haul.size()
		check(command(engine,picker,"DraftGem",{"claim_id":claim}).ok and engine._hero(picker).haul.size() == haul_before + 1, "a drafted stone goes to the haul, unappraised")
		check(not command(engine,picker,"DraftGem",{"claim_id":claim}).ok, "mine claim cannot be replayed with new ID")
	while engine.state.phase == "mine_draft":
		command(engine,engine.state.mine.picker_id,"DraftGem",{"claim_id":engine.state.mine.pool[0].claim_id})
	check(engine.state.phase == "support", "empty draft exposes Done")
	enter(engine,"rest")
	check(engine.state.heroes[0].hp == 41, "rest heals floor(maxHP/3)")
	enter(engine,"treasure")
	var cache: Dictionary = engine.state.room.treasure.p1
	check(cache.gems.size() == 1 and cache.gems[0].appraised and engine.state.heroes[0].gems[-1].id == cache.gems[0].id, "a treasure cache gives an appraised gem straight to the bag")
	check(EngineCore.validate_state(engine.state).is_empty(), "rooms leave a valid saved state")

func test_rewards_and_save() -> void:
	var engine = fresh(2)
	at_depth(engine, 2)
	enter(engine,"battle")
	engine.state.heroes[1].hp = 0
	engine.state.heroes[0].block = 20
	engine.state.heroes[0].relics.append({"id":"aegis", "key":"LASTING_AEGIS", "equipped":true, "stored_block":0})
	engine._battle_rewards()
	check(engine.state.heroes[1].hp == 7 and engine.state.heroes[1].ore == EngineCore.ORE_PER_BATTLE + 2, "downed Kait rallies and keeps her ore")
	check(engine.state.heroes[0].block == 0 and engine.state.heroes[0].relics[0].stored_block == 6, "Aegis captures before cleanup")
	var ore: int = engine.state.heroes[0].ore
	engine._battle_rewards()
	check(engine.state.heroes[0].ore == ore, "room reward cannot settle twice")
	for found in engine.state.reward_offers.p1.found:
		check(not found.appraised and engine.state.heroes[0].haul.any(func(gem: Dictionary) -> bool: return gem.id == found.id), "battle drops go to the haul unappraised")
	check(command(engine,"p1","SetReady",{"ready":true}).ok, "an ordinary reward needs no choice")
	enter(engine,"elite")
	at_depth(engine, 5)
	engine._battle_rewards()
	var elite: Dictionary = engine.state.reward_offers.p1
	check(not elite.found.is_empty() and not elite.relic_done, "an elite drops stones and offers a relic")
	check(not command(engine,"p1","SetReady",{"ready":true}).ok, "a relic choice must be made or declined")
	check(command(engine,"p1","ChooseReward",{"kind":"relic","offer_id":elite.relics[0].id}).ok, "relic claimed")
	engine._checkpoint()
	var snapshot: Dictionary = engine.state.duplicate(true)
	var restored = EngineCore.new()
	restored.autosave = false
	check(restored.restore(snapshot,engine.command_history).ok, "checkpoint schema accepted")
	check(restored._rng_snapshot() == engine._rng_snapshot(), "RNG streams roundtrip losslessly")
	var a: Array = engine._roll_gems(3, 0, false)
	var b: Array = restored._roll_gems(3, 0, false)
	check(a.map(func(gem: Dictionary) -> Array: return [gem.key, gem.carat, gem.cut, gem.clarity]) == b.map(func(gem: Dictionary) -> Array: return [gem.key, gem.carat, gem.cut, gem.clarity]), "save reload preserves future loot sequence")
	var saved = Store.new("user://tests/authority-save")
	check(saved.save_checkpoint(snapshot,engine.command_history).ok, "real JSON checkpoint writes atomically")
	var loaded: Dictionary = saved.load_checkpoint()
	check(loaded.ok and EngineCore.validate_state(loaded.state).is_empty(), "real JSON checkpoint passes full validation: " + str(loaded.get("error", "")))
	check(restored.restore(loaded.state,loaded.command_history).ok, "JSON checkpoint can resume authority")
	saved.clear_checkpoint()
	enter(engine,"battle")
	check(engine.state.heroes[0].block == 6 and engine.state.heroes[0].relics[0].stored_block == 0, "stored block consumed once next encounter")

func test_tremor_and_boss() -> void:
	var engine = fresh(2)
	at_depth(engine, 3)
	enter(engine, "battle")
	engine.state.tremor = 400
	for step in range(3):
		if engine.state.phase != "planning": break
		command(engine, "p1", "SetReady", {"ready":true})
		command(engine, "p2", "SetReady", {"ready":true})
	check(int(engine.state.tremor) == 400, "fighting never moves the tremor meter")
	for enemy in engine.state.enemies: enemy.hp = 0
	engine.state.battle_outcome = "victory"
	engine.state.settled_rooms.erase(engine.state.room.id)
	engine._battle_rewards()
	check(int(engine.state.reward_offers.p1.ore) == EngineCore.ORE_PER_BATTLE + 3, "the victory offer records the ore it paid")
	engine = fresh(2)
	engine.state.tremor = Seam.TREMOR_FULL - 1
	engine._route_offers()
	check(engine.state.offers.all(func(offer: Dictionary) -> bool: return offer.wakes_boss), "the route warns when the next step wakes the boss")
	var target: Dictionary = engine.state.offers[0]
	command(engine, "p1", "VoteRoom", {"offer_id":target.id})
	command(engine, "p2", "VoteRoom", {"offer_id":target.id})
	check(engine.state.room.kind == "boss" and engine.state.enemies.size() == 1 and engine.state.enemies[0].key == "SLIME_KING", "a full meter turns the next chamber into the boss lair")
	check(Seam.find_node(engine.state.seam, target.id).kind == "boss" and Seam.find_node(engine.state.seam, target.id).was == target.kind, "the seam remembers what the lair used to be")
	check("SLIME_KING" in engine.state.encountered.bosses, "the boss is recorded as encountered")
	check(int(engine.state.enemies[0].max_hp) == 120, "the boss scales with the party")
	for enemy in engine.state.enemies: enemy.hp = 0
	engine.state.battle_outcome = "victory"
	engine._battle_rewards()
	var chest: Dictionary = engine.state.reward_offers.p1
	check(chest.gems.size() == 3 and chest.gems.all(func(gem: Dictionary) -> bool: return gem.appraised) and not chest.gem_done, "the boss chest offers three appraised gems")
	check(command(engine,"p1","ChooseReward",{"kind":"gem","offer_id":chest.gems[1].id}).ok, "a chest gem is chosen")
	check(command(engine,"p2","ChooseReward",{"kind":"gem","offer_id":""}).ok, "a chest may be left shut")
	command(engine,"p1","SetReady",{"ready":true})
	command(engine,"p2","SetReady",{"ready":true})
	check(engine.state.phase == "summary" and engine.state.outcome == "conquered", "killing the boss ends the expedition conquered")
	var result: Dictionary = engine.state.results.p1
	check(result.haul.any(func(gem: Dictionary) -> bool: return gem.id == chest.gems[1].id and gem.appraised), "the chest gem is in the haul that comes home")
	check(result.result_id == "test-run:p1" and result.mine_id == "QUARRY" and result.depth == 1, "the result names its run, mine and depth")
	var profile: Dictionary = Profile.create("host")
	var applied: Dictionary = Profile.apply_result(profile, result)
	check(applied.ok and profile.mines.MIRROR_GROTTO.unlocked, "a profile accepts the engine's result and unlocks the next mines: " + str(applied.get("error", "")))

func test_lift() -> void:
	var engine = fresh(2)
	at_depth(engine, 2)
	enter(engine, "lift")
	check(engine.state.phase == "lift", "a lift asks the party")
	check(not command(engine,"p1","VoteLift",{"choice":"jump"}).ok, "a lift knows only up and on")
	found_gem(engine, 0, "HEAL", "carried", false)
	check(command(engine,"p1","VoteLift",{"choice":"ride"}).ok and engine.state.phase == "lift", "one vote waits for the party")
	check(command(engine,"p2","VoteLift",{"choice":"ride"}).ok and engine.state.phase == "summary" and engine.state.outcome == "extracted", "the party rides up")
	check(engine.state.results.p1.haul.size() == 1 and not engine.state.results.p1.haul[0].appraised, "everything carried comes home, appraised or not")
	engine = fresh(1)
	at_depth(engine, 2)
	enter(engine, "lift")
	check(command(engine,"p1","VoteLift",{"choice":"dig"}).ok and engine.state.phase == "route", "digging on leaves the lift behind")
	check(not engine.state.offers.is_empty() and engine.state.offers[0].depth == 3, "the lift's tunnels lead down")

func test_salvage() -> void:
	var engine = fresh(2)
	at_depth(engine, 4)
	enter(engine, "battle")
	found_gem(engine, 0, "STRIKE", "common", false)
	found_gem(engine, 0, "STUN", "legendary", true)
	found_gem(engine, 1, "SUNDER", "uncommon", false)
	for hero in engine.state.heroes: hero.hp = 0
	engine._start_salvage()
	check(engine.state.phase == "salvage", "a wiped party rolls for its haul")
	var rolls: Dictionary = {}
	for entry in engine.state.salvage.p1 + engine.state.salvage.p2:
		rolls[entry.gem_id] = entry
	check(rolls.common.sides == 6 and rolls.legendary.sides == 20 and rolls.uncommon.sides == 8, "the salvage die is set by rarity")
	check(rolls.values().all(func(entry: Dictionary) -> bool: return entry.kept == (entry.roll == entry.sides) and not entry.revealed), "only the top face keeps a gem, and nothing is shown yet")
	check(engine.state.salvage.p1.size() == 2, "found gems in the bag are rolled too; loadout gems are not")
	check(not command(engine,"p1","RevealSalvage",{"gem_id":"uncommon"}).ok, "a hero reveals only their own rolls")
	check(command(engine,"p1","RevealSalvage",{"gem_id":"common"}).ok and rolls.common.revealed == false and engine.state.salvage.p1[0].revealed, "a roll is revealed")
	check(EngineCore.validate_state(engine.state).is_empty(), "a salvage in progress is a valid saved state")
	command(engine,"p1","SetReady",{"ready":true})
	command(engine,"p2","SetReady",{"ready":true})
	check(engine.state.phase == "summary" and engine.state.outcome == "fallen", "the fallen party goes home after salvage")
	var kept: Array = []
	for entry in rolls.values():
		if entry.kept: kept.append(entry.gem_id)
	var came_home: Array = []
	for gem in engine.state.results.p1.haul + engine.state.results.p2.haul: came_home.append(gem.id)
	came_home.sort()
	kept.sort()
	check(came_home == kept, "exactly the gems that rolled their top face come home")
	var empty = fresh(1)
	enter(empty, "battle")
	empty._start_salvage()
	check(empty.state.phase == "summary" and empty.state.outcome == "fallen", "a party with nothing to salvage goes straight home")

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
	corrupted = original.duplicate(true)
	corrupted.seam.layers["2"][0].links = ["d9c9"]
	check(not EngineCore.validate_state(corrupted).is_empty(), "a tunnel to nowhere is rejected")
	corrupted = original.duplicate(true)
	corrupted.tremor = 5000
	check(not EngineCore.validate_state(corrupted).is_empty(), "an overfull tremor meter is rejected")
	var same_a = fresh()
	var same_b = fresh()
	var route: Dictionary = same_a.make_envelope("p1","VoteRoom",{"offer_id":same_a.state.offers[0].id})
	check(same_a.execute("p1",route).ok and same_b.execute("p1",route).ok, "same seeded command accepted by independent authorities")
	check(same_a.state == same_b.state, "same seed and accepted sequence produce identical complete state")

func test_wager_hall() -> void:
	## The table is pure arithmetic over a hand, so the pattern reader is checked directly
	## before any ore moves, then the room is played through its guards.
	var cases: Array = [
		[[3,3,3,3,3],"five"], [[1,2,3,4,5],"straight5"], [[6,5,4,3,2],"straight5"],
		[[2,2,2,2,6],"four"], [[4,4,4,1,1],"full_house"], [[1,2,3,4,6],"straight4"],
		[[5,5,5,1,2],"three"], [[2,2,3,3,6],"two_pair"], [[6,6,1,2,4],"pair"], [[1,3,5,2,6],"nothing"]]
	for case in cases:
		check(EngineCore.wager_pattern(case[0]) == case[1], "wager reads %s as %s" % [case[0], case[1]])
	check(EngineCore.wager_entry("five").multiplier > EngineCore.wager_entry("pair").multiplier, "rarer patterns pay more")
	check(EngineCore.wager_entry("nonsense").key == "nothing", "an unknown pattern falls to the losing row")
	var engine = fresh(2)
	enter(engine,"wager")
	check(engine.state.phase == "support" and engine.state.room.wager.size() == 2, "every hero gets a private table")
	engine.state.heroes[0].ore = 40
	check(not command(engine,"p1","PlaceWager",{"stake":7}).ok, "the table refuses a stake it does not offer")
	check(not command(engine,"p1","WagerReroll",{"die_ids":["x"]}).ok, "no reroll before a stake")
	check(not command(engine,"p1","SettleWager",{}).ok, "no settlement before a stake")
	var ore: int = engine.state.heroes[0].ore
	check(command(engine,"p1","PlaceWager",{"stake":8}).ok, "a covered stake is accepted")
	var seat: Dictionary = engine.state.room.wager["p1"]
	check(engine.state.heroes[0].ore == ore-8, "the stake leaves the purse when it is placed")
	check(seat.hand.size() == EngineCore.WAGER_DICE_COUNT and seat.dice.size() == EngineCore.WAGER_DICE_COUNT, "the stake deals the house's five dice")
	var staked: Array = []
	for roll in seat.hand: staked.append(str(roll.die_id))
	for die in seat.dice:
		check(str(die.shape) == EngineCore.WAGER_DIE, "every house die is the same shape")
	check(not command(engine,"p1","PlaceWager",{"stake":4}).ok, "one stake per visit")
	check(not command(engine,"p1","WagerReroll",{"die_ids":[staked[0],staked[0]]}).ok, "a die cannot be rerolled twice in one throw")
	check(command(engine,"p1","WagerReroll",{"die_ids":[staked[0]]}).ok, "the single reroll is accepted")
	check(not command(engine,"p1","WagerReroll",{"die_ids":[staked[1]]}).ok, "only one reroll per stake")
	ore = engine.state.heroes[0].ore
	check(command(engine,"p1","SettleWager",{}).ok, "a staked hand settles")
	seat = engine.state.room.wager["p1"]
	var entry: Dictionary = EngineCore.wager_entry(str(seat.pattern))
	check(seat.settled and seat.payout == 8*int(entry.multiplier), "the payout is the stake times the pattern it showed")
	check(engine.state.heroes[0].ore == ore+seat.payout, "the payout reaches the purse")
	check(EngineCore.validate_state(engine.state).is_empty(), "a settled table is a valid saved state")
	var store = Store.new("user://tests/wager-save")
	check(store.save_checkpoint(engine.state,engine.command_history).ok, "a wager room checkpoints")
	var loaded: Dictionary = store.load_checkpoint()
	check(loaded.ok and EngineCore.validate_state(loaded.state).is_empty(), "a reloaded wager room validates")
	store.clear_checkpoint()
	var broken: Dictionary = engine.state.duplicate(true)
	broken.room.wager["p1"].stake = 9999
	check(not EngineCore.validate_state(broken).is_empty(), "a stake beyond the table is rejected")
	engine.state.heroes[1].ore = 20
	check(command(engine,"p2","PlaceWager",{"stake":4}).ok, "the second hero stakes too")
	ore = engine.state.heroes[1].ore
	check(command(engine,"p2","SetReady",{"ready":true}).ok, "readying with a live stake is allowed")
	var left: Dictionary = engine.state.room.wager["p2"]
	check(left.settled and engine.state.heroes[1].ore == ore+int(left.payout), "walking away still pays the hand out")

func test_crucible() -> void:
	var engine = fresh(2)
	enter(engine,"crucible")
	check(engine.state.phase == "support", "the crucible is a service room")
	var target_id: String = str(engine.state.heroes[0].gems[0].id)
	gem_of(engine,0,target_id).carat = 6
	var hp: int = int(engine.state.heroes[0].hp)
	check(not command(engine,"p1","TemperGem",{"gem_id":target_id,"method":"melt"}).ok, "the fire knows only Temper and Fuse")
	check(command(engine,"p1","TemperGem",{"gem_id":target_id,"method":"temper"}).ok, "tempering is accepted")
	check(int(gem_of(engine,0,target_id).carat) == 6+EngineCore.CRUCIBLE_CARAT_GAIN, "tempering raises Carat by the fixed gain")
	check(int(engine.state.heroes[0].hp) == hp-7, "tempering is paid in HP that rises with the gem")
	check(not command(engine,"p1","TemperGem",{"gem_id":target_id,"method":"temper"}).ok, "one offering per visit")
	enter(engine,"crucible")
	var loadout_fuel: Dictionary = engine.state.heroes[0].gems[2]
	loadout_fuel.equipped = false
	check(not command(engine,"p1","TemperGem",{"gem_id":target_id,"method":"fuse","fuel_id":loadout_fuel.id}).ok, "a loadout gem cannot be burned for Carat")
	var fuel: Dictionary = found_gem(engine, 0, "HEAL", "crucible-fuel", true)
	fuel.carat = 12
	var before: int = int(gem_of(engine,0,target_id).carat)
	var owned: int = engine.state.heroes[0].gems.size()
	check(command(engine,"p1","TemperGem",{"gem_id":target_id,"method":"fuse","fuel_id":"crucible-fuel"}).ok, "a found gem can be fused")
	check(int(gem_of(engine,0,target_id).carat) == before+EngineCore.CRUCIBLE_CARAT_GAIN+3, "a richer gem feeds more Carat")
	check(engine.state.heroes[0].gems.size() == owned-1 and gem_of(engine,0,"crucible-fuel").is_empty(), "fusing destroys the consumed gem")
	enter(engine,"crucible")
	var low_id: String = str(engine.state.heroes[1].gems[0].id)
	gem_of(engine,1,low_id).carat = 6
	engine.state.heroes[1].hp = 7
	check(not command(engine,"p2","TemperGem",{"gem_id":low_id,"method":"temper"}).ok, "tempering never costs a hero its life")
	check(EngineCore.validate_state(engine.state).is_empty(), "the crucible leaves a valid saved state")

func gem_of(engine: RefCounted, seat: int, id: String) -> Dictionary:
	for gem in engine.state.heroes[seat].gems:
		if str(gem.id) == id: return gem
	return {}

func test_descriptions() -> void:
	var engine = fresh(1)
	for kind in EngineCore.ROOM_NAMES:
		check(not str(engine._room_description(kind)).is_empty(), "every room kind describes itself: " + str(kind))
	var seen: Dictionary = {}
	for seed_value in range(30):
		var probe: Dictionary = {}
		Seam.ensure_layers(probe, str(seed_value), "QUARRY", "", 14)
		for depth in probe.layers:
			for node in probe.layers[depth]: seen[node.kind] = true
	for kind in ["battle", "elite", "mine", "rest", "treasure", "shop", "lapidary", "crucible", "workshop", "wager", "event", "lift"]:
		check(seen.has(kind), "the Quarry's seam reaches %s rooms" % kind)

func test_expeditions() -> void:
	# A deterministic overpowering fixture exercises every phase through each ending;
	# it is deliberately separate from balance tests with unmodified starting heroes.
	for mine_id in ["QUARRY", "RIFT_HOLLOW"]:
		for count in range(1, 5):
			for plan in ["conquer", "extract"]:
				var engine = fresh(count, mine_id, 12345 + count)
				for hero in engine.state.heroes:
					hero.max_hp = 10000
					hero.hp = 10000
					hero.gems[0].carat = 24
					hero.gems[0].cut = 5
					hero.gems[0].clarity = 5
				var decisions: int = 0
				while engine.state.phase != "summary" and decisions < 4000:
					decisions += 1
					match engine.state.phase:
						"route":
							var offer_id: String = engine.state.offers[0].id
							for offer in engine.state.offers:
								if plan == "extract" and offer.kind == "lift": offer_id = offer.id
							for hero in engine.state.heroes:
								if engine.state.phase == "route": command(engine,hero.id,"VoteRoom",{"offer_id":offer_id})
						"lift":
							for hero in engine.state.heroes:
								if engine.state.phase == "lift": command(engine,hero.id,"VoteLift",{"choice":"ride" if plan == "extract" else "dig"})
						"planning":
							var phase: int = engine.state.phase_id
							for hero in engine.state.heroes:
								if engine.state.phase_id == phase and hero.hp > 0: command(engine,hero.id,"SetReady",{"ready":true})
						"reward":
							for hero in engine.state.heroes:
								if engine.state.phase != "reward": break
								var reward: Dictionary = engine.state.reward_offers[hero.id]
								for kind in ["gem","relic"]:
									if not reward[kind+"_done"]: command(engine,hero.id,"ChooseReward",{"kind":kind,"offer_id":reward.gems[0].id if kind == "gem" and not reward.gems.is_empty() else ""})
								command(engine,hero.id,"SetReady",{"ready":true})
						"mine_vote":
							for hero in engine.state.heroes:
								if engine.state.phase == "mine_vote": command(engine,hero.id,"VoteVein",{"vein":"crystal"})
						"mine_draft":
							command(engine,engine.state.mine.picker_id,"DraftGem",{"claim_id":engine.state.mine.pool[0].claim_id})
						"support":
							for hero in engine.state.heroes:
								if engine.state.phase == "support": command(engine,hero.id,"SetReady",{"ready":true})
						_: break
				var expected: String = "conquered" if plan == "conquer" else "extracted"
				check(engine.state.phase == "summary" and engine.state.outcome == expected, "%s with %s heroes ends %s (got %s at depth %s after %s decisions)" % [mine_id, count, expected, engine.state.outcome, engine.state.depth, decisions])
				check(engine.state.results.size() == count, "every hero gets a result record")
				check(EngineCore.validate_state(engine.state).is_empty(), "a finished expedition is a valid saved state: " + EngineCore.validate_state(engine.state))
				if plan == "conquer":
					check(int(engine.state.deepest) >= 8, "the boss arrives only after some digging (depth %s)" % engine.state.deepest)
					for result in engine.state.results.values():
						check(Profile.apply_result(Profile.create("p"), result).ok, "a profile accepts every hero's result")
