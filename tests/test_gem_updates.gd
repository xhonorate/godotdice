extends SceneTree
## Gem overhaul: real activations, ordering, spending, persistence and forecast isolation.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	triggers()
	attacks()
	status_gems()
	lifeline()
	fortune()
	upgrades()
	edge_cases()
	persistence()
	print("Gem updates: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func setup(foes: int = 3, allies: int = 2) -> Dictionary:
	var party: Array = []
	for p in range(allies):
		var bowl: Array = []
		for i in range(5):
			bowl.append(DeepDice.make("D20", DeepContent.die("D20"), "p%d_d%d" % [p, i]))
		var unit: Dictionary = DeepBattle.make_player("p%d" % p, "Player", "ARDOR", [], bowl)
		unit.passive = {}
		unit.birthstone = {}
		unit.hp = 1000
		unit.max_hp = 1000
		unit.ore = 100
		unit.haul = []
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(19, ["dice", "creatures"])
	var keys: Array = []
	keys.resize(foes)
	keys.fill("CAVE_TICK")
	var state: Dictionary = DeepBattle.begin(party, keys, {"depth": 1}, rng.dice, rng.creatures)
	for foe in state.enemies:
		foe.hp = 1000
		foe.max_hp = 1000
		foe.block = 0
	return {"state": state, "player": state.players[0], "foe": state.enemies[0], "rng": rng}

func rolls(f: Dictionary, values: Array) -> void:
	for i in range(f.player.hand.size()):
		var roll: Dictionary = f.player.hand[i]
		roll.value = int(values[i])
		roll.face = int(values[i]) - 1
		roll.kind = "plain"
		roll.top = 20
		roll.held = false
		roll.rerolls = 1

func equip(f: Dictionary, key: String, flawless: bool = false, cut: int = 4, at: int = 0) -> void:
	f.player.sockets[at] = "ANY"
	f.player.rail[at] = DeepStone.make(key, 1, cut, 5 if flawless else 3, [], {}, "gem%d" % at)

func cast(f: Dictionary, key: String, values: Array = [5, 5, 5, 2, 2], flawless: bool = false, cut: int = 4) -> Dictionary:
	equip(f, key, flawless, cut)
	rolls(f, values)
	f.player.firing_target = f.player.target
	return DeepBattle.resolve_gem(f.state, f.player, 0, {"dry": true}, f.rng.dice)

func hit(f: Dictionary, target: Dictionary, amount: int) -> Dictionary:
	return DeepBattle._damage(f.state, f.foe, target, amount, f.rng.dice)

func triggers() -> void:
	var f: Dictionary = setup()
	for cut in range(5):
		for spec in [["MEND", 3 + cut, false], ["THRIVE", 12 - cut, true], ["APEX", 20 - cut, true], ["GLIMMER", 7 - cut, false]]:
			var key: String = spec[0]
			var threshold: int = int(spec[1])
			equip(f, key, false, cut)
			var accepted: int = threshold - 1 if key == "GLIMMER" else threshold
			rolls(f, [accepted, accepted, accepted, accepted, accepted])
			check(DeepStone.evaluate(f.player.rail[0], f.player.hand).active, "%s Cut %d accepts its boundary" % [key, cut])
			var rejected: int = threshold - 1 if bool(spec[2]) else threshold + (0 if key == "GLIMMER" else 1)
			rolls(f, [rejected, rejected, rejected, rejected, rejected])
			check(not DeepStone.evaluate(f.player.rail[0], f.player.hand).active, "%s Cut %d rejects outside its boundary" % [key, cut])
	check(cast(f, "SAP", [1, 2, 3, 4, 5]).kind == "gem_fizzle", "Sap needs a triple")
	check(cast(f, "DOUBLE_DOWN", [1, 2, 3, 4, 5]).kind == "gem_fizzle", "Double Down needs two ones")
	check(cast(f, "DOUBLE_DOWN", [1, 1, 3, 4, 5]).kind == "gem_fire", "Double Down accepts two ones")
	check(DeepContent.skill("SPALL").rarity == "COMMON" and DeepContent.skill("ANCHOR").rarity == "COMMON", "rarities updated")
	check(DeepContent.section("skills").size() == 66, "all 66 skills are present")
	for key in ["CROSSCUT", "DETONATE", "SHELTER", "MORTAR", "SIPHON", "STAKE", "APEX", "ENRICH", "APPRAISE", "GILDED_ARMOR"]:
		check(DeepForge.skill_pool(DeepContent.mine("QUARRY")).has(key), key + " is in the standard pool")
	for key in ["POULTICE", "UNDERTOW", "SILENCE", "LEVEL", "INVERT", "MYCELIUM"]:
		check(DeepContent.skill(key).is_empty(), key + " was not added")

func attacks() -> void:
	var f: Dictionary = setup()
	f.player.target = f.state.enemies[2].id
	f.state.enemies[2].hp = 1
	cast(f, "STRIKE", [6, 6, 6, 6, 6], true)
	check(int(f.state.enemies[1].hp) == 964 and int(f.foe.hp) == 1000, "Strike finds the left adjacent enemy even after killing the last enemy")
	f = setup()
	f.player.target = f.state.enemies[1].id
	f.state.enemies[1].hp = 1
	cast(f, "CLEAVE")
	check(int(f.foe.hp) == 995 and int(f.state.enemies[2].hp) == 995, "Cleave splashes both neighbors after a lethal main hit")
	f = setup()
	for foe in f.state.enemies:
		foe.hp = 10
	var event: Dictionary = cast(f, "OVERKILL", [20, 20, 20, 20, 20], true)
	check(event.effects.size() == 3 and f.state.outcome == "victory", "Overkill can kill the whole enemy row")
	f = setup()
	f.foe.hp = 10
	event = cast(f, "OVERKILL", [20, 20, 20, 20, 20], true)
	check(event.effects.size() == 2 and int(f.state.enemies[2].hp) == 1000, "Overkill stops chaining when a target survives")
	f = setup()
	f.player.hp = 500
	cast(f, "FURY", [1, 2, 3, 4, 5], true)
	check(int(f.foe.hp) == 955, "Fury applies 50% missing HP after the Flawless magnitude: 20 × 1.5 × 1.5")
	f = setup()
	f.player.block_lost = 40
	f.foe.block = 10
	cast(f, "RIPOSTE", [1, 2, 3, 4, 5], true)
	check(int(f.player.block) == 20, "Riposte gives a quarter of the 80 HP actually lost")
	f = setup()
	f.foe.block = 4
	cast(f, "SHATTER")
	check(int(f.foe.hp) == 996 and int(f.foe.block) == 0, "Shatter deals actual Block removed")
	f = setup()
	f.foe.block = 150
	cast(f, "SHATTER", [5, 5, 5, 2, 2], true)
	check(int(f.foe.hp) == 850 and int(f.foe.block) == 0, "Flawless Shatter strips every point, then deals exactly that amount")
	for value in [19, 20, 21]:
		f = setup()
		cast(f, "APEX", [value, 1, 2, 3, 4], true)
		check(int(f.foe.hp) == 1000 - int(value * 1.5 * (2 if value == 20 else 1)), "Apex doubles only an exact 20")
	f = setup()
	f.foe.statuses.poison = 9
	f.state.enemies[1].statuses.ward = 1
	event = cast(f, "DETONATE", [5, 5, 3, 2, 2], true)
	check(int(f.foe.statuses.poison) == 0 and int(f.foe.hp) == 946, "Detonate consumes all nine Poison for one scaled hit")
	check(int(f.state.enemies[1].statuses.ward) == 0 and int(f.state.enemies[1].statuses.get("poison", 0)) == 0, "Ward intercepts poison spread")
	f = setup()
	f.player.target = f.state.enemies[1].id
	f.state.enemies[1].statuses.poison = 9
	f.state.enemies[1].hp = 1
	cast(f, "DETONATE", [5, 5, 3, 2, 2], true)
	check(int(f.foe.statuses.poison) == 4 and int(f.state.enemies[2].statuses.poison) == 4 and int(f.foe.hp) == 1000, "Detonate reapplies half consumed Poison to both neighbors after a kill")

func status_gems() -> void:
	var f: Dictionary = setup()
	cast(f, "BULWARK", [1, 2, 3, 4, 5], true)
	check(int(f.player.block) == 22 and int(f.player.statuses.retain) == 11, "Bulwark reads total and retains half of actual Block gained")
	cast(f, "MORTAR")
	check(int(f.player.statuses.retain) == 17, "Mortar converts current Block into Retain")
	f = setup()
	cast(f, "BLOOM", [1, 3, 5, 2, 2], true)
	check(f.state.players.all(func(p: Dictionary) -> bool: return int(p.statuses.charged) == 3), "Bloom gives Charged per odd die to the party")
	cast(f, "RENEWAL", [1, 2, 3, 4, 5], true)
	check(int(f.player.statuses.ward) == 1, "Renewal grants Ward")
	cast(f, "HEX", [20, 2, 3, 4, 5], true)
	check(int(f.foe.stolen_dice) == 1 and int(f.foe.statuses.clouded) == 1 and int(f.foe.statuses.get("stun", 0)) == 0, "Hex applies Bound and Clouded")
	cast(f, "MIASMA", [2, 4, 6, 1, 1])
	check(f.state.enemies.all(func(e: Dictionary) -> bool: return int(e.statuses.poison) == 6), "Miasma gives two Poison per even die to every enemy")
	f.player.hp = 800
	cast(f, "SIPHON")
	check(int(f.player.hp) == 810, "Siphon heals 60% of the 18 enemy Poison, floored")
	f = setup()
	cast(f, "CURSE", [1, 1, 2, 3, 4], true)
	check(int(f.foe.statuses.curse) == 2 and int(f.foe.max_hp) == 992 and int(f.foe.hp) == 990, "Curse stacks per one, lowers max HP per one, then deals stack damage")
	f = setup()
	f.foe.statuses.ward = 2
	cast(f, "CURSE", [1, 1, 2, 3, 4])
	check(int(f.foe.statuses.ward) == 0 and int(f.foe.max_hp) == 1000 and int(f.foe.statuses.get("curse", 0)) == 0, "Curse and max HP loss are separate wardable applications")
	cast(f, "MIST", [5, 5, 2, 3, 4], true)
	check(f.state.enemies.all(func(e: Dictionary) -> bool: return int(e.statuses.clouded) == 1), "Flawless Mist clouds all enemies")
	f.state.players[1].hp = 100
	cast(f, "SHELTER")
	check(int(f.state.players[1].block) == 10 and int(f.player.block) == 0, "Shelter protects the lowest HP percentage ally")

func lifeline() -> void:
	var f: Dictionary = setup()
	cast(f, "LIFELINE", [5, 5, 5, 2, 2])
	check(f.state.players.all(func(p: Dictionary) -> bool: return int(p.statuses.lifeline) == 5), "Lifeline protects each living ally")
	cast(f, "LIFELINE", [5, 5, 5, 2, 2])
	var event: Dictionary = hit(f, f.player, 2000)
	check(int(f.player.hp) == 10 and not f.player.downed and int(event.lifeline) == 10 and not f.player.statuses.has("lifeline"), "lethal damage consumes every Lifeline stack and restores that HP")
	hit(f, f.player, 20)
	check(f.player.downed, "Lifeline is one use")
	cast(f, "LIFELINE")
	check(not f.player.statuses.has("lifeline"), "Lifeline does not grant stacks to an already downed ally")
	f = setup()
	cast(f, "LIFELINE", [5, 5, 5, 2, 2], true)
	f.player.statuses.poison = 1100
	event = DeepBattle._poison_tick(f.state, f.player)
	check(int(f.player.hp) == 7 and int(f.player.block) == 7 and event.has("lifeline"), "Flawless Lifeline rescues lethal Poison and restores Block")
	f = setup()
	cast(f, "LIFELINE")
	f.player.hp = 1
	f.foe.statuses.spikes = 20
	DeepBattle._damage(f.state, f.player, f.foe, 10, f.rng.dice)
	check(int(f.player.hp) == 5 and not f.player.downed, "Lifeline rescues lethal retaliation")

func fortune() -> void:
	var f: Dictionary = setup()
	cast(f, "TITHE", [4, 4, 1, 2, 3], true)
	check(int(f.player.gold) == 6 and int(f.foe.hp) == 994, "Tithe deals exactly Pyrite gained")
	f = setup()
	cast(f, "JACKPOT", [5, 5, 5, 5, 5])
	check(int(f.player.gold) == 25, "normal Jackpot has no five-kind bonus")
	f = setup()
	cast(f, "JACKPOT", [5, 5, 5, 5, 5], true)
	check(int(f.player.gold) == 187, "Flawless five-kind Jackpot pays 25 × 5 × 1.5, floored")
	f = setup()
	cast(f, "JACKPOT", [5, 5, 5, 1, 2], true)
	check(int(f.player.gold) == 22, "Flawless triple does not receive the five-kind multiplier")
	f = setup()
	var event: Dictionary = cast(f, "LUCKY_SEVEN", [7, 7, 7, 7, 1], true)
	check(event.effects.size() == 14 and int(f.player.gold) == 49 and int(f.foe.hp) == 930, "four sevens become seven hits and seven payouts, each with normal Flawless magnitude")
	f = setup()
	cast(f, "WAGER", [20, 1, 2, 3, 4])
	check(DeepRules.pyrite(f.player) == 70 and int(f.foe.hp) == 980, "Wager pays once and deals high-roll damage")
	f.foe.hp = 10
	cast(f, "WAGER", [20, 1, 2, 3, 4])
	check(DeepRules.pyrite(f.player) == 100, "Wager kill refunds twice the exact stake")
	f.player.ore = 0
	f.player.gold = 29
	f.player.pyrite_delta = 0
	event = cast(f, "WAGER")
	check(event.kind == "gem_fizzle" and int(f.player.pyrite_delta) == 0, "insufficient funds cannot partially pay")
	event = DeepBattle.resolve_gem(f.state, f.player, 0, {"force": true}, f.rng.dice)
	check(event.kind == "gem_fizzle", "forced activation cannot bypass payment")
	f.player.gold = 30
	cast(f, "WAGER")
	check(DeepRules.pyrite(f.player) == 0, "combat earnings can fund Wager")
	check(DeepBattle.resolve_gem(f.state, f.player, 0, {"retrigger": true}, f.rng.dice).kind == "gem_fizzle", "repeat needs its own payment")
	f = setup()
	cast(f, "STAKE", [1, 2, 3, 4, 5], true)
	check(DeepRules.pyrite(f.player) == 95 and is_equal_approx(float(f.player.amplify), 1.75), "Flawless Stake spends five for exactly 75% amplification")
	cast(f, "GILDED_ARMOR")
	check(int(f.player.block) == 49, "Gilded Armor uses remaining available Pyrite and preceding amplification")

func upgrades() -> void:
	var f: Dictionary = setup()
	cast(f, "GLIMMER", [1, 2, 3, 4, 5])
	check(int(f.player.dice[0].faces[0].value) == 2 and int(f.player.dice[1].faces[1].value) == 3 and int(f.player.dice[2].faces[2].value) == 3, "Glimmer changes only faces on dice below the threshold")
	check(int(f.player.hand[0].value) == 2 and int(f.player.dice[0].faces[19].value) == 20, "face upgrade affects later gems without changing other faces")
	cast(f, "GLIMMER", [1, 2, 3, 4, 5], true)
	check(int(f.player.dice[0].faces[19].value) == 21 and int(f.player.dice[2].faces[19].value) == 20, "Flawless Glimmer upgrades every face of matched dice only")
	f = setup()
	f.player.dice[0].top = 20
	cast(f, "GLIMMER", [1, 3, 4, 5, 6])
	check(int(f.player.hand[0].top) == 20, "raising a low face does not inflate an explicit maximum")
	f = setup()
	equip(f, "POLISH", false, 4, 1)
	equip(f, "STRIKE", false, 4, 0)
	equip(f, "STRIKE", false, 4, 2)
	f.player.rail[2].clarity = 4
	equip(f, "GUARD", false, 4, 3)
	rolls(f, [1, 2, 3, 4, 5])
	var stored: String = JSON.stringify(f.player.rail)
	DeepBattle.resolve_gem(f.state, f.player, 1, {"dry": true}, f.rng.dice)
	check(f.player.gem_buffs.has("gem0") and f.player.gem_buffs.has("gem2") and not f.player.gem_buffs.has("gem3") and not f.player.gem_buffs.has("gem1"), "Polish affects adjacent occupied sockets")
	var ev: Dictionary = DeepStone.evaluate(f.player.rail[2], f.player.hand, DeepBattle.rail_context(f.state, f.player, 2))
	check(ev.effects.size() == 2 and int(ev.resonance_gain) == 3, "temporary Clarity enables Flawless line and Resonance")
	check(JSON.stringify(f.player.rail) == stored, "temporary rank upgrades never mutate stored gems")
	equip(f, "FACET", true, 4, 1)
	rolls(f, [20, 2, 3, 4, 5])
	DeepBattle.resolve_gem(f.state, f.player, 1, {"dry": true}, f.rng.dice)
	check(int(f.player.gem_buffs.gem3.cut) == 1 and int(f.player.gem_buffs.gem1.cut) == 1, "Flawless Facet affects the entire rail including itself")
	equip(f, "ENRICH", true, 4, 1)
	DeepBattle.resolve_gem(f.state, f.player, 1, {"dry": true}, f.rng.dice)
	check(int(f.player.gem_buffs.gem3.carat) == 2 and not f.player.gem_buffs.gem1.has("carat"), "Enrich upgrades all other gems")
	f = setup()
	f.player.haul = [DeepStone.make("STRIKE", 1, 0, 3, [], {}, "raw0"), DeepStone.make("GUARD", 1, 0, 3, [], {}, "raw1")]
	equip(f, "APPRAISE", true)
	rolls(f, [5, 5, 2, 3, 4])
	var before: String = JSON.stringify(f.state)
	DeepBattle.forecast(f.state, "p0")
	check(JSON.stringify(f.state) == before, "forecast never appraises live stones or consumes currency")
	var worth: int = DeepStone.value(f.player.haul[0]) + DeepStone.value(f.player.haul[1])
	cast(f, "APPRAISE", [5, 5, 2, 3, 4], true)
	check(f.player.haul.all(func(s: Dictionary) -> bool: return s.appraised and s.inclusions_revealed) and int(f.foe.hp) == 1000 - worth, "Appraise identifies stones and deals their combined value")
	cast(f, "APPRAISE")
	check(int(f.foe.hp) == 1000 - worth, "already identified stones cannot pay again")

func persistence() -> void:
	for spec in [[0, 50, -30, false, "victory", 27], [100, 0, -30, false, "victory", 77], [100, 0, 30, true, "victory", 144], [0, 50, -30, true, "victory", 84], [100, 0, -30, false, "defeat", 70], [0, 50, -30, false, "defeat", 0]]:
		var f: Dictionary = setup(1, 1)
		var state: Dictionary = DeepDescent.new_run({"seed": 11, "mine": "QUARRY", "boons": false, "players": [{"id": "p0", "name": "Player", "character": "ARDOR", "rail": [], "dice": f.player.dice}]})
		state.players[0].ore = int(spec[0])
		state.depth = 1
		state.phase = "chamber"
		DeepDescent._start_fight(state, DeepDescent.streams_of(state), bool(spec[3]), "")
		var fighter: Dictionary = state.chamber.battle.players[0]
		fighter.gold = int(spec[1])
		fighter.pyrite_delta = int(spec[2])
		fighter.quality_bonus = -1000
		fighter.max_hp += 1
		fighter.dice[0].faces[0].value += 1
		fighter.haul = [DeepStone.make("STRIKE", 1, 1, 3, [], {}, "found")]
		fighter.haul[0].appraised = true
		fighter.gem_buffs = {"test": {"cut": 2}}
		DeepDescent._settle_fight(state, str(spec[4]))
		check(int(state.players[0].ore) == int(spec[5]), "Pyrite settlement %s expected %d got %d" % [str(spec), int(spec[5]), int(state.players[0].ore)])
		check(int(state.players[0].max_hp) == int(fighter.max_hp) and int(state.players[0].dice[0].faces[0].value) == 2 and state.players[0].haul[0].appraised, "HP, die upgrades and appraisal persist to run")
		var before: String = JSON.stringify(state)
		DeepDescent.step(state)
		check(JSON.stringify(state) == before, "replaying a settled step cannot settle spending twice")
		if str(spec[4]) == "victory":
			state.phase = "chamber"
			DeepDescent._start_fight(state, DeepDescent.streams_of(state), false, "")
			check(state.chamber.battle.players[0].gem_buffs.is_empty() and int(state.chamber.battle.players[0].pyrite_delta) == 0, "temporary ranks and spending ledger reset at next fight")

func edge_cases() -> void:
	var f: Dictionary = setup(1)
	f.foe.hp = 1
	cast(f, "LUCKY_SEVEN", [7, 7, 7, 7, 1], true)
	check(int(f.player.gold) == 49 and f.state.outcome == "victory", "Lucky Seven pays its full reward even on the final killing hit")
	f = setup()
	equip(f, "GLIMMER")
	rolls(f, [1, 3, 4, 5, 6])
	var ghost: Dictionary = DeepDice.phantom(f.player.hand[0], "ghost")
	f.player.hand.append(ghost)
	var event: Dictionary = DeepBattle.resolve_gem(f.state, f.player, 0, {"dry": true}, f.rng.dice)
	check(int(ghost.value) == 1 and not event.effects[0].dice.has("ghost"), "Glimmer cannot upgrade a phantom die")
	f = setup()
	equip(f, "STAKE")
	equip(f, "WAGER", false, 4, 1)
	rolls(f, [20, 1, 2, 3, 4])
	f.player.ore = 30
	var before: String = JSON.stringify(f.state)
	var prediction: Dictionary = DeepBattle.forecast(f.state, "p0")
	check(prediction.sockets[0].active and not prediction.sockets[1].active and int(prediction.totals.gold) == -5, "forecast accounts for spending before a later paid gem")
	check(JSON.stringify(f.state) == before, "paid forecast leaves the live balance and amplification unchanged")
	f = setup()
	equip(f, "ENRICH")
	equip(f, "STRIKE", false, 4, 1)
	rolls(f, [1, 2, 3, 4, 5])
	before = JSON.stringify(f.state)
	prediction = DeepBattle.forecast(f.state, "p0")
	check(JSON.stringify(f.state) == before and int(prediction.sockets[1].effects[0].amount) == 17, "forecast uses temporary Carat growth on its copy for later gems")
	f = setup()
	equip(f, "APPRAISE")
	rolls(f, [5, 5, 2, 3, 4])
	f.player.haul = [DeepStone.make("STRIKE", 1, 0, 3, [], {}, "raw")]
	prediction = DeepBattle.forecast(f.state, "p0")
	check(int(prediction.totals.damage) == DeepStone.value(f.player.haul[0]), "forecast counts appraisal damage")
	f = setup()
	var maximum: int = int(f.player.max_hp)
	cast(f, "THRIVE", [8, 1, 2, 3, 4], true)
	check(int(f.player.max_hp) == maximum + 1, "Flawless Thrive grants exactly one permanent max HP")
	cast(f, "CROSSCUT", [1, 3, 5, 2, 2], true)
	check(int(f.foe.hp) == 987 and int(f.player.block) == 4, "Crosscut deals odd-die damage and its Flawless Block rider")
	f = setup()
	cast(f, "MIRROR", [1, 4, 4, 5, 6])
	check(int(f.player.hand[0].value) == 4, "Mirror inherits Polish’s matching effect")
	for cut in range(5):
		f = setup()
		f.player.ore = 50 - 5 * cut
		var old_pyrite: int = DeepRules.pyrite(f.player)
		cast(f, "WAGER", [20, 1, 2, 3, 4], false, cut)
		check(DeepRules.pyrite(f.player) == 0 and int(f.player.pyrite_delta) == -old_pyrite, "Wager pays its exact price at Cut %d" % cut)
		f = setup()
		f.player.ore = 25 - 5 * cut
		cast(f, "STAKE", [1, 2, 3, 4, 5], false, cut)
		check(DeepRules.pyrite(f.player) == 0 and is_equal_approx(float(f.player.amplify), 1.5), "Stake always amplifies 50%% at Cut %d" % cut)
