extends SceneTree
## The variant Birthstones: what each of the twelve reads off the hand and what each does,
## and the reading of the hand they need (the scale, Faces, sets by size, a total in a window).

var checks: int = 0
var failures: Array = []

## A socket color no stone has, so nothing set in it is lit and Resonance is the gems' alone.
const UNLIT: String = "UNLIT"

func _init() -> void:
	_test_content()
	_test_reading()
	_test_rampart()
	_test_renown()
	_test_ill_omen()
	_test_fan_of_knives()
	_test_nocturne()
	_test_arpeggio()
	_test_mithridate()
	_test_bloodroot()
	_test_highs_and_lows()
	_test_patchwork()
	_test_bandit()
	_test_blackjack()
	_test_forecast()
	_test_buying()
	_test_run()
	_test_daily()
	print("Birthstones: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func rngs(seed_value: int) -> Dictionary:
	return DeepRng.streams(seed_value, ["dice", "creatures"])

func stone(skill: String, carat: int = 1, cut: int = 4, clarity: int = 3) -> Dictionary:
	return DeepStone.make(skill, carat, cut, clarity, [], {}, skill.to_lower())

func dice(keys: Array, prefix: String) -> Array:
	var out: Array = []
	for index in range(keys.size()):
		out.append(DeepForge.die_from(keys[index], "%s%d" % [prefix, index]))
	return out

func hand(unit: Dictionary, numbers: Array) -> void:
	## Puts a chosen hand in a player's tray, on their own dice, as if rolled.
	var out: Array = []
	for index in range(numbers.size()):
		var die: Dictionary = unit.dice[index % unit.dice.size()]
		out.append({"die_id": str(die.id), "shape": str(die.shape), "material": str(die.get("material", "")), "value": int(numbers[index]), "face": 0, "kind": "plain",
			"top": DeepDice.top(die), "held": false, "rerolls": 0, "locked": false, "explosions": 0, "phantom": false})
	unit.hand = out

func fight(character: String, worn: String, numbers: Array, resonance: int = 10, foes: Array = ["CAVE_TICK"], rail: Array = [], seed_value: int = 5) -> Dictionary:
	## A fight on its first turn with the hand chosen, the rail opening on `resonance`, and
	## creatures with health to spare that sit their action out (a stun), so what the
	## Birthstone does is all that happens.
	var r: Dictionary = rngs(seed_value)
	var unit: Dictionary = DeepBattle.make_player("a", "A", character, rail, dice(DeepContent.character(character).dice, "a"), -1, [], worn)
	unit.sockets = unit.sockets.map(func(_socket: Variant) -> String: return UNLIT)
	var state: Dictionary = DeepBattle.begin([unit], foes, {"depth": 1}, r.dice, r.creatures)
	for foe in state.enemies:
		foe.hp = 1000
		foe.max_hp = 1000
		foe.block = 0
		foe.statuses.stun = 9
	var a: Dictionary = DeepBattle.player(state, "a")
	hand(a, numbers)
	a.initial_resonance = resonance
	return {"state": state, "unit": a, "r": r}

func run_turn(f: Dictionary) -> Array:
	## Locks everyone, resolves the turn and returns every event it produced.
	var state: Dictionary = f.state
	for unit in state.players:
		unit.locked = true
	var events: Array = [DeepBattle.start_resolution(state)]
	var guard: int = 0
	while DeepBattle.has_steps(state) and guard < 400:
		guard += 1
		var event: Dictionary = DeepBattle.step(state, f.r.dice, f.r.creatures)
		if not event.is_empty():
			events.append(event)
	return events

func fired(events: Array) -> Dictionary:
	## The Birthstone's first firing this turn.
	for event in events:
		if str(event.kind) == "birthstone":
			return event
	return {}

func tier(event: Dictionary, name: String) -> Dictionary:
	for entry in event.get("tiers", []):
		if str(entry.get("name", "")) == name:
			return entry
	return {}

func lit(event: Dictionary) -> Array:
	## The names of the tiers that fired.
	var names: Array = []
	for entry in event.get("tiers", []):
		if bool(entry.get("active", false)):
			names.append(str(entry.name))
	return names

func hits(entry: Dictionary, kind: String = "damage") -> Array:
	return entry.get("effects", []).filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == kind)

func foe(f: Dictionary, id: String = "e0") -> Dictionary:
	return DeepBattle.enemy(f.state, id)

# --- the pack -------------------------------------------------------------------------------

func _test_content() -> void:
	check(DeepContent.validate().is_empty(), "the pack validates with the variants in it: %s" % str(DeepContent.validate().slice(0, 3)))
	var emblems: Dictionary = {}
	var styles: Dictionary = {}
	var names: Dictionary = {}
	var count: int = 0
	for pair in DeepContent.all_birthstones():
		var def: Dictionary = DeepContent.birthstone_def(str(pair[0]), str(pair[1]))
		count += 1
		emblems[str(def.get("emblem", ""))] = true
		styles[str(def.get("style", ""))] = true
		names[str(def.get("name", ""))] = true
	check(count == 18 and emblems.size() == 18 and styles.size() == 18 and names.size() == 18, "eighteen Birthstones, no two sharing a name, a cut or an emblem (%d, %d emblems, %d cuts)" % [count, emblems.size(), styles.size()])
	for key in DeepContent.section("characters"):
		var keys: Array = DeepContent.birthstone_keys(str(key))
		check(keys.size() == 3 and str(keys[0]) == "", "%s has a first stone and two variants" % str(key))
		check(DeepContent.birthstone_price(str(key), str(keys[1])) == 1000 and DeepContent.birthstone_price(str(key), str(keys[2])) == 2500 and DeepContent.birthstone_price(str(key), "") == 0,
			"%s's variants cost 1,000 and 2,500 gold, and the first stone nothing" % str(key))
	check(DeepContent.birthstone_owner("BLOODROOT") == "RUE" and DeepContent.birthstone_owner("NOPE") == "" and DeepContent.birthstone_owner("") == "", "a variant knows its delver")
	check(DeepContent.birthstone_key("ARDOR", "BLOODROOT") == "" and DeepContent.birthstone_key("ARDOR", "RENOWN") == "RENOWN", "a delver wears only their own stones")
	var rally: Dictionary = DeepStone.birthstone("ARDOR")
	var rampart: Dictionary = DeepStone.birthstone("ARDOR", "RAMPART")
	check(str(rally.name) == "Rally" and str(rampart.name) == "Rampart" and str(rally.id) != str(rampart.id) and int(rampart.price) == 1000 and str(rampart.variant) == "RAMPART",
		"a variant is a stone of its own for the views")
	check(str(DeepStone.birthstone("ARDOR", "BLOODROOT").name) == "Rally", "a stone that is not theirs reads as their first")
	var unit: Dictionary = DeepBattle.make_player("a", "A", "ARDOR", [], dice(DeepContent.character("ARDOR").dice, "a"), -1, [], "RENOWN")
	check(str(unit.birthstone.name) == "Renown" and str(unit.birthstone_key) == "RENOWN" and str(DeepStone.birthstone_for(unit).name) == "Renown", "a unit wears the variant it was made with")
	DeepBattle.wear(unit, "RUE", "MITHRIDATE")
	check(str(unit.birthstone.name) == "Mithridate" and str(unit.birthstone_of) == "RUE" and str(DeepStone.birthstone_for(unit).name) == "Mithridate", "and can be lent another delver's")
	DeepBattle.wear(unit, "ARDOR")
	check(str(unit.birthstone.name) == "Rally" and not unit.has("birthstone_of") and str(unit.birthstone_key) == "", "or put back in its own first stone")

# --- what the hand shows them ---------------------------------------------------------------

func _roll(shape: String, value: int, id: String) -> Dictionary:
	return {"die_id": id, "shape": shape, "value": value, "kind": "plain", "top": DeepDice.size_of(shape), "held": false, "rerolls": 0}

func _test_reading() -> void:
	var cadence: Array = ["D4", "D6", "D8", "D10", "D12"]
	var scale: Callable = func(values: Array) -> Dictionary:
		var rolls: Array = []
		for index in range(values.size()):
			rolls.append(_roll(str(cadence[index]), int(values[index]), "d%d" % index))
		return DeepHand.analyze(rolls).scale
	var four: Dictionary = scale.call([2, 3, 5, 4, 11])
	check(int(four.length) == 4 and four.dice == ["d0", "d1", "d2", "d4"] and four.values == [2, 3, 5, 11] and int(four.total) == 21, "2 3 5 4 11 climbs four dice, the d10 left out (%s)" % str(four))
	check(int(scale.call([1, 2, 3, 4, 5]).length) == 5, "five rising is a whole scale")
	check(int(scale.call([4, 4, 4, 4, 4]).length) == 1, "nothing climbs through five 4s")
	var tied: Dictionary = scale.call([4, 1, 2, 3, 12])
	check(int(tied.length) == 4 and tied.values == [1, 2, 3, 12], "a high d4 is stepped over: 1 2 3 12 (%s)" % str(tied.values))
	check(scale.call([1, 5, 2, 9, 3]).values == [1, 5, 9], "between two climbs as long, the one that adds up to more (%s)" % str(scale.call([1, 5, 2, 9, 3]).values))
	## The scale goes by the dice's sizes, not where they sit in the tray.
	var shuffled: Dictionary = DeepHand.analyze([_roll("D12", 9, "big"), _roll("D4", 2, "small"), _roll("D8", 5, "mid")]).scale
	check(shuffled.dice == ["small", "mid", "big"], "the scale runs from the smallest die to the largest wherever they lie (%s)" % str(shuffled.dice))
	var a: Dictionary = DeepHand.analyze([_roll("D6", 6, "a"), _roll("D6", 1, "b"), _roll("D8", 8, "c"), _roll("D8", 3, "d"), _roll("D10", 10, "e")])
	check(a.one_ids == ["b"] and DeepHand.size_steps(a, a.crown_ids) == 6 and DeepHand.size_steps(a, a.one_ids) == 1, "a crown on a d6, a d8 and a d10 is six sizes over a d4; a 1 on a d6 is one")
	check(DeepHand.size_steps(DeepHand.analyze([_roll("D4", 4, "a")]), ["a"]) == 0, "a d4 is no size over a d4")
	var eval: Callable = func(trigger: Dictionary, analysis: Dictionary, context: Dictionary = {}) -> Dictionary:
		return DeepPatterns.evaluate(trigger, 0, analysis, context)
	check(bool(eval.call({"kind": "all_faces", "amount": 2}, a).active) == false, "a 3 among them: not every die is a Face")
	var faces: Dictionary = DeepHand.analyze([_roll("D6", 6, "a"), _roll("D6", 1, "b"), _roll("D8", 8, "c"), _roll("D8", 1, "d"), _roll("D10", 10, "e")])
	check(bool(eval.call({"kind": "all_faces", "amount": 2}, faces).active), "crowns and 1s on all five: every die a Face")
	var sixes: Dictionary = eval.call({"kind": "high_count", "value": 6, "amount": 2}, a)
	check(bool(sixes.active) and int(sixes.count) == 3, "three dice showing 6 or more are counted (%d)" % int(sixes.get("count", 0)))
	check(not bool(eval.call({"kind": "high_count", "value": 6, "amount": 4}, a).active), "and four are not there")
	check(bool(eval.call({"kind": "total_at_most", "amount": 28}, a).active) and not bool(eval.call({"kind": "total_at_most", "amount": 27}, a).active), "a total of 28 is at most 28 and not at most 27")
	check(bool(eval.call({"kind": "total_window", "amount": 17, "max": 28}, a).active) and not bool(eval.call({"kind": "total_window", "amount": 17, "max": 20}, a).active)
		and bool(eval.call({"kind": "total_window", "amount": 22}, a).active) and bool(eval.call({"kind": "total_window", "amount": 28, "max": 28}, a).active), "a total sits in a window, on a number, or past a floor")
	check(bool(eval.call({"kind": "colors", "amount": 3}, a, {"colors": 3}).active) and not bool(eval.call({"kind": "colors", "amount": 4}, a, {"colors": 3}).active), "the fight says how many colors have fired")
	var house: Dictionary = DeepHand.analyze([_roll("D6", 5, "a"), _roll("D6", 5, "b"), _roll("D6", 5, "c"), _roll("D6", 2, "d"), _roll("D6", 2, "e")])
	var pairs: Dictionary = eval.call({"kind": "set", "amount": 2, "max": 2}, house)
	var threes: Dictionary = eval.call({"kind": "set", "amount": 3, "max": 4}, house)
	check(bool(pairs.active) and pairs.sets.size() == 1 and int(pairs.sets[0].value) == 2 and bool(threes.active) and int(threes.sets[0].value) == 5 and not bool(eval.call({"kind": "set", "amount": 5}, house).active),
		"a full house is one set of exactly two and one of three, and no set of five")
	for kind in ["high_count", "total_at_most", "total_window", "scale", "all_faces", "colors", "set"]:
		var described: Dictionary = DeepPatterns.describe({"kind": kind, "amount": 3, "value": 6, "max": 4}, 0)
		check(not str(described.words).is_empty() and str(described.words) != "Its trigger." and DeepPatterns.validate({"kind": kind, "amount": 3}).is_empty(), "%s says what it asks for" % kind)

# --- Ardor ----------------------------------------------------------------------------------

func _test_rampart() -> void:
	var f: Dictionary = fight("ARDOR", "RAMPART", [2, 4, 1, 3, 5])
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Parapet"], "two even dice raise the Parapet alone (%s)" % str(lit(e)))
	check(int(hits(tier(e, "Parapet"), "block")[0].amount) == 10 and int(hits(tier(e, "Parapet"), "retain")[0].retain_after) == 10, "Parapet: Resonance block, and as much kept")
	check(int(f.unit.block) == 10, "the Parapet's block is still standing as the next turn opens (%d)" % int(f.unit.block))
	## Thornwork: Spikes until his next turn, and gone when it opens.
	f = fight("ARDOR", "RAMPART", [2, 4, 6, 3, 5])
	var tick: Dictionary = foe(f)
	tick.statuses.erase("stun")
	var bite: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(tick), "Bite")
	for die in tick.dice:
		for face in die.faces:
			DeepCreatures.dress_face(face, bite)
	e = fired(run_turn(f))
	var thorn: Dictionary = hits(tier(e, "Thornwork"), "spikes")[0]
	check(lit(e) == ["Parapet", "Thornwork"] and int(thorn.spikes_after) == 10 and int(thorn.timed) == 10, "three even dice: Thornwork holds up Resonance Spikes")
	check(int(tick.hp) == 990, "the creature that bit him took Resonance back (%d)" % int(tick.hp))
	check(not f.unit.statuses.has("spikes") and not f.unit.has("timed"), "and the Spikes came down as his next turn opened")
	## Spikes he already had stay: only Thornwork's come off.
	f = fight("ARDOR", "RAMPART", [2, 4, 6, 3, 5])
	f.unit.statuses.spikes = 4
	run_turn(f)
	check(int(f.unit.statuses.get("spikes", 0)) == 4, "Spikes he had from elsewhere are left alone (%d)" % int(f.unit.statuses.get("spikes", 0)))
	## Ram: one blow for every 10 block he holds.
	f = fight("ARDOR", "RAMPART", [2, 4, 6, 2, 5], 30)
	e = fired(run_turn(f))
	check(lit(e) == ["Parapet", "Thornwork", "Ram"] and hits(tier(e, "Ram")).size() == 3 and int(hits(tier(e, "Ram"))[0].amount) == 30, "four even dice: 30 block is three Rams of Resonance (%d)" % hits(tier(e, "Ram")).size())
	check(int(tier(e, "Ram").count.get("repeat", 0)) == 3, "and the count says three")
	f = fight("ARDOR", "RAMPART", [2, 4, 6, 2, 5], 9)
	e = fired(run_turn(f))
	check(hits(tier(e, "Ram")).is_empty(), "under 10 block the Ram has nothing to swing")
	## Keep: none of it falls away this turn, and the turn after it does again.
	f = fight("ARDOR", "RAMPART", [2, 4, 6, 2, 8], 10, ["CAVE_TICK"], [stone("TEMPO")])
	e = fired(run_turn(f))
	var held: int = int(f.unit.block)
	check(lit(e) == ["Parapet", "Thornwork", "Ram", "Keep"] and held > int(e.resonance), "all five even: the Keep holds every point, Tempo's too (%d block on %d Resonance)" % [held, int(e.resonance)])
	hand(f.unit, [1, 3, 5, 1, 3])
	run_turn(f)
	check(int(f.unit.block) == 0, "with no Keep the next turn, the wall falls as it always did (%d)" % int(f.unit.block))

func _test_renown() -> void:
	var f: Dictionary = fight("ARDOR", "RENOWN", [6, 1, 2, 3, 4])
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Lance"] and hits(tier(e, "Lance")).size() == 1 and int(hits(tier(e, "Lance"))[0].amount) == 10, "a die showing 6: one Lance of Resonance")
	check(DeepBattle.trophies(f.unit) == 0, "no kill, no Trophy")
	## A kill is a Trophy, and every Trophy is a point on the Lance.
	f = fight("ARDOR", "RENOWN", [6, 1, 2, 3, 4])
	foe(f).hp = 5
	e = fired(run_turn(f))
	check(DeepBattle.trophies(f.unit) == 1 and int(hits(tier(e, "Lance"))[0].get("trophy", 0)) == 1, "a kill with the Lance is a Trophy")
	f = fight("ARDOR", "RENOWN", [6, 1, 2, 3, 4])
	f.unit.run_counts = {DeepBattle.TROPHIES: 4}
	e = fired(run_turn(f))
	check(int(hits(tier(e, "Lance"))[0].amount) == 14, "four Trophies: the Lance deals Resonance and four")
	## Tourney: every other die showing 6 or more is another Lance, at the weakest.
	f = fight("ARDOR", "RENOWN", [6, 6, 6, 7, 1], 10, ["CAVE_TICK", "RAIL_RAT"])
	foe(f, "e1").hp = 50
	e = fired(run_turn(f))
	var passes: Array = hits(tier(e, "Tourney"))
	check(lit(e) == ["Lance", "Tourney"] and passes.size() == 3 and passes.all(func(h: Dictionary) -> bool: return str(h.target) == "e1"), "four dice at 6 or more: three more Lances, at the creature with the least health")
	check(int(foe(f, "e1").hp) == 20 and str(hits(tier(e, "Lance"))[0].target) == "e0", "the first Lance still goes where he aimed")
	## A kill in the Tourney is a Trophy too, and the next Lance already carries it.
	f = fight("ARDOR", "RENOWN", [6, 6, 6, 7, 1], 10, ["CAVE_TICK", "RAIL_RAT"])
	foe(f, "e1").hp = 8
	e = fired(run_turn(f))
	passes = hits(tier(e, "Tourney"))
	check(DeepBattle.trophies(f.unit) == 1 and bool(passes[0].get("killed", false)) and str(passes[1].target) == "e0", "the Tourney's kill is a Trophy, and the next pass finds who is left")
	## Grand Melee: every Lance lands twice.
	f = fight("ARDOR", "RENOWN", [6, 6, 6, 7, 8], 10, ["CAVE_TICK", "RAIL_RAT"])
	e = fired(run_turn(f))
	var total: int = hits(tier(e, "Lance")).size() + hits(tier(e, "Tourney")).size() + hits(tier(e, "Grand Melee")).size()
	check(lit(e) == ["Lance", "Tourney", "Grand Melee"] and total == 10, "all five at 6 or more: ten Lances (%d)" % total)

# --- Vesper ---------------------------------------------------------------------------------

func _test_ill_omen() -> void:
	var f: Dictionary = fight("VESPER", "ILL_OMEN", [1, 2, 3, 4, 7])
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Omen"] and int(hits(tier(e, "Omen"), "curse")[0].curse_after) == 1, "a 1 showing: one Curse on the target")
	f = fight("VESPER", "ILL_OMEN", [1, 1, 1, 2, 7], 10, ["CAVE_TICK", "RAIL_RAT"])
	e = fired(run_turn(f))
	check(lit(e) == ["Jinx"] and bool(tier(e, "Omen").get("eclipsed", false)) and str(tier(e, "Omen").reason) == "Jinx takes its place.", "three 1s: Jinx takes Omen's place")
	check(hits(tier(e, "Jinx"), "curse").size() == 2 and hits(tier(e, "Jinx"), "curse").all(func(h: Dictionary) -> bool: return int(h.curse_after) == 3), "and curses every creature three times")
	f = fight("VESPER", "ILL_OMEN", [1, 1, 1, 1, 7], 10, ["CAVE_TICK", "RAIL_RAT"])
	e = fired(run_turn(f))
	check(lit(e) == ["Jinx", "Reckoning"] and hits(tier(e, "Reckoning")).size() == 4 and hits(tier(e, "Reckoning")).all(func(h: Dictionary) -> bool: return str(h.target) == "e0" and int(h.amount) == 10),
		"four 1s: Reckoning deals Resonance once for each of the target's four Curses (%d)" % hits(tier(e, "Reckoning")).size())
	f = fight("VESPER", "ILL_OMEN", [1, 1, 1, 1, 1], 10, ["CAVE_TICK", "RAIL_RAT"])
	e = fired(run_turn(f))
	check(lit(e) == ["Jinx", "Snake Eyes"] and bool(tier(e, "Reckoning").get("eclipsed", false)), "five 1s: Snake Eyes takes Reckoning's place")
	check(int(hits(tier(e, "Snake Eyes"), "curse")[0].curse_after) == 10 and hits(tier(e, "Snake Eyes")).size() == 20, "the Curses count double, to the ten a creature can carry, and Reckoning lands twice for each (%d)" % hits(tier(e, "Snake Eyes")).size())
	f = fight("VESPER", "ILL_OMEN", [2, 2, 3, 4, 7])
	check(not bool(fired(run_turn(f)).get("fired", true)), "no 1s, no omen")

func _test_fan_of_knives() -> void:
	var f: Dictionary = fight("VESPER", "FAN_OF_KNIVES", [3, 3, 1, 2, 9])
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Fan"] and hits(tier(e, "Fan")).size() == 2 and int(hits(tier(e, "Fan"))[0].amount) == 10, "a pair: two knives of Resonance")
	f = fight("VESPER", "FAN_OF_KNIVES", [3, 3, 2, 2, 9])
	check(hits(tier(fired(run_turn(f)), "Fan")).size() == 4, "two pairs: four knives")
	f = fight("VESPER", "FAN_OF_KNIVES", [1, 2, 3, 4, 9])
	check(not bool(fired(run_turn(f)).get("fired", true)), "no two alike: no knives")
	## A knife that kills is thrown again.
	f = fight("VESPER", "FAN_OF_KNIVES", [3, 3, 3, 2, 9], 10, ["CAVE_TICK", "RAIL_RAT", "RAIL_RAT"])
	foe(f, "e0").hp = 5
	foe(f, "e1").hp = 5
	e = fired(run_turn(f))
	var thrown: Array = hits(tier(e, "Fan"))
	var kills: int = thrown.filter(func(h: Dictionary) -> bool: return bool(h.get("killed", false))).size()
	var again: int = thrown.filter(func(h: Dictionary) -> bool: return bool(h.get("chained", false))).size()
	check(thrown.size() == 3 + again and again == kills and kills >= 1, "three knives among three creatures, and one more for every kill (%d thrown, %d kills)" % [thrown.size(), kills])
	check(thrown.map(func(h: Dictionary) -> String: return str(h.target)).any(func(t: String) -> bool: return t != str(thrown[0].target)), "the knives scatter: not all at one creature")
	## Flourish: every knife carries her highest die and hits every creature.
	f = fight("VESPER", "FAN_OF_KNIVES", [3, 3, 3, 3, 9], 10, ["CAVE_TICK", "RAIL_RAT"])
	e = fired(run_turn(f))
	var flourish: Array = hits(tier(e, "Flourish"))
	check(lit(e) == ["Flourish"] and bool(tier(e, "Fan").get("eclipsed", false)) and flourish.size() == 8 and flourish.all(func(h: Dictionary) -> bool: return int(h.amount) == 19),
		"four of a kind: four knives, each Resonance and her 9, each at both creatures (%d)" % flourish.size())
	check(int(hits(tier(e, "Flourish"))[0].get("riposte", 0)) > 0, "every knife is a hit for Riposte")

# --- Cadence --------------------------------------------------------------------------------

func _forced(events: Array) -> Array:
	return events.filter(func(ev: Dictionary) -> bool: return str(ev.kind) == "gem_fire" and bool(ev.get("forced", false))).map(func(ev: Dictionary) -> String: return str(ev.skill))

func _test_nocturne() -> void:
	var rail: Array = [stone("HEARTWOOD"), stone("PETRIFY")]
	var f: Dictionary = fight("CADENCE", "NOCTURNE", [1, 2, 3, 4, 5], 10, ["CAVE_TICK"], rail)
	var events: Array = run_turn(f)
	var e: Dictionary = fired(events)
	check(lit(e) == ["Hush"] and _forced(events) == ["HEARTWOOD"], "a total of 15: Hush wakes the first gem that stayed dark (%s)" % str(_forced(events)))
	f = fight("CADENCE", "NOCTURNE", [1, 2, 3, 1, 4], 10, ["CAVE_TICK"], rail)
	events = run_turn(f)
	e = fired(events)
	check(lit(e) == ["Nocturne"] and bool(tier(e, "Hush").get("eclipsed", false)) and _forced(events) == ["HEARTWOOD", "PETRIFY"], "a total of 11: Nocturne wakes them all (%s)" % str(_forced(events)))
	f = fight("CADENCE", "NOCTURNE", [1, 1, 2, 2, 3], 10, ["CAVE_TICK"], rail)
	events = run_turn(f)
	e = fired(events)
	check(lit(e) == ["Small Hours"] and _forced(events) == ["HEARTWOOD", "HEARTWOOD", "PETRIFY", "PETRIFY"], "a total of 9: Small Hours wakes each of them twice (%s)" % str(_forced(events)))
	f = fight("CADENCE", "NOCTURNE", [2, 3, 4, 5, 6], 10, ["CAVE_TICK"], rail)
	check(not bool(fired(run_turn(f)).get("fired", true)), "a total of 20 is not a quiet hand")
	## A gem that fired is not woken, and with nothing dark the tier fires on nothing.
	f = fight("CADENCE", "NOCTURNE", [1, 2, 3, 4, 5], 10, ["CAVE_TICK"], [stone("STRIKE"), stone("PETRIFY")])
	events = run_turn(f)
	check(_forced(events) == ["PETRIFY"], "only what stayed dark is woken (%s)" % str(_forced(events)))

func _test_arpeggio() -> void:
	var f: Dictionary = fight("CADENCE", "ARPEGGIO", [2, 3, 5, 4, 11], 10, ["CAVE_TICK", "RAIL_RAT"])
	var e: Dictionary = fired(run_turn(f))
	var played: Dictionary = tier(e, "Arpeggio").effects[0]
	check(lit(e) == ["Arpeggio"] and played.notes.size() == 4 and played.notes.map(func(n: Dictionary) -> int: return int(n.value)) == [2, 3, 5, 11], "a scale of four is played a note at a time")
	check(played.notes.map(func(n: Dictionary) -> int: return int(n.resonance)) == [12, 15, 20, 31] and played.notes.map(func(n: Dictionary) -> int: return int(n.amount)) == [6, 7, 10, 15],
		"each note adds its number to the Resonance, then half the Resonance lands (%s)" % str(played.notes.map(func(n: Dictionary) -> int: return int(n.amount))))
	check(played.notes.all(func(n: Dictionary) -> bool: return n.hits.size() == 2) and int(played.gained) == 21, "on every creature")
	## A Perfect Scale plays it again, from where the first pass left the Resonance.
	f = fight("CADENCE", "ARPEGGIO", [1, 2, 3, 4, 5], 10)
	e = fired(run_turn(f))
	var second: Dictionary = tier(e, "Perfect Scale").effects[0]
	check(lit(e) == ["Arpeggio", "Perfect Scale"] and int(second.notes[0].resonance) == 26 and int(second.resonance_after) == 40, "all five in the scale: it is played again and the Resonance keeps climbing (to %d)" % int(second.get("resonance_after", 0)))
	check(int(e.resonance) == 10 and DeepBattle.blows(tier(e, "Arpeggio").effects) == 5, "the count's blows are the notes'")
	f = fight("CADENCE", "ARPEGGIO", [4, 3, 2, 1, 2])
	check(not bool(fired(run_turn(f)).get("fired", true)), "two dice climbing are no scale")
	## The Resonance it adds stays on the rail: Second Wind or a Chainmail after it would read it.
	f = fight("CADENCE", "ARPEGGIO", [2, 3, 5, 4, 11], 10)
	var rail_end: Dictionary = run_turn(f).filter(func(ev: Dictionary) -> bool: return str(ev.kind) == "rail_end")[0]
	check(int(rail_end.resonance) == 31, "the rail closes on the Resonance the scale left (%d)" % int(rail_end.resonance))

# --- Rue ------------------------------------------------------------------------------------

func _test_mithridate() -> void:
	var f: Dictionary = fight("RUE", "MITHRIDATE", [1, 2, 3, 1, 1])
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Coat"] and int(f.unit.statuses.get("envenom", 0)) == 1, "three in a row: one Envenomed")
	f = fight("RUE", "MITHRIDATE", [1, 2, 3, 4, 1])
	e = fired(run_turn(f))
	check(lit(e) == ["Coat", "Double Dose"] and int(f.unit.statuses.get("envenom", 0)) == 3, "four in a row: one more for every 5 Resonance (%d)" % int(f.unit.statuses.get("envenom", 0)))
	f = fight("RUE", "MITHRIDATE", [2, 3, 4, 5, 1])
	e = fired(run_turn(f))
	var stabs: Array = hits(tier(e, "Mithridate"))
	check(lit(e) == ["Coat", "Double Dose", "Mithridate"] and stabs.size() == 3 and int(stabs[0].amount) == 10, "five in a row: a stab of Resonance for each Envenomed she carries (%d)" % stabs.size())
	check(stabs.all(func(h: Dictionary) -> bool: return int(h.get("envenom", {}).get("amount", 0)) == 3), "and every stab leaves her Envenomed as Poison")
	f = fight("RUE", "MITHRIDATE", [1, 1, 3, 3, 1])
	check(not bool(fired(run_turn(f)).get("fired", true)), "no run of three, no coat")

func _test_bloodroot() -> void:
	## Tap: the 1s she has been shown this fight are what every firing costs.
	var f: Dictionary = fight("RUE", "BLOODROOT", [1, 1, 2, 3, 4])
	var e: Dictionary = fired(run_turn(f))
	var tap: Dictionary = tier(e, "Tap")
	check(lit(e) == ["Tap"] and int(tap.effects[0].total) == 2 and int(hits(tap)[0].hp_loss) == 2 and int(hits(tap, "poison")[0].poison_after) == 2, "two 1s: 2 health and 2 Poison")
	check(int(hits(tap, "max_hp")[0].max_hp_after) == 72 and int(hits(tap, "max_hp")[0].hp_after) == 68, "and 2 max health, which does not fill itself (%s)" % str(hits(tap, "max_hp")[0]))
	hand(f.unit, [1, 2, 2, 3, 4])
	var before: int = int(f.unit.hp)
	e = fired(run_turn(f))
	tap = tier(e, "Tap")
	check(int(tap.effects[0].total) == 3 and int(hits(tap)[0].hp_loss) == 3 and int(hits(tap, "max_hp")[0].max_hp_after) == 73, "a third 1 the turn after: 3 health this time, and 1 more max health (%d lost from %d)" % [int(hits(tap)[0].hp_loss), before])
	## It can kill her.
	f = fight("RUE", "BLOODROOT", [1, 2, 3, 4, 2])
	f.unit.hp = 1
	run_turn(f)
	check(bool(f.unit.downed) and str(f.state.outcome) == "defeat", "a Tap she cannot pay for downs her")
	## Take Root: max health for the fight, with nothing in it, and the missing health as a blow.
	f = fight("RUE", "BLOODROOT", [2, 2, 2, 3, 4])
	e = fired(run_turn(f))
	var root: Dictionary = tier(e, "Take Root")
	check(lit(e) == ["Take Root"] and int(hits(root, "max_hp")[0].max_hp_after) == 80 and int(hits(root, "max_hp")[0].hp_after) == 70 and int(hits(root)[0].amount) == 10,
		"three of a kind: Resonance max health for the fight, and the health she is missing as damage")
	check(int(f.unit.fight_max_hp) == 10, "the fight will take that max health back")
	## Transfusion: what the heal restored goes to every creature.
	f = fight("RUE", "BLOODROOT", [2, 2, 2, 2, 3], 10, ["CAVE_TICK", "RAIL_RAT"])
	f.unit.hp = 64
	e = fired(run_turn(f))
	var flow: Dictionary = tier(e, "Transfusion")
	check(lit(e) == ["Take Root", "Transfusion"] and int(hits(flow, "heal")[0].healed) == 10 and hits(flow).size() == 2 and hits(flow).all(func(h: Dictionary) -> bool: return int(h.amount) == 10),
		"four of a kind: heal Resonance, and deal what it restored to every creature")
	f = fight("RUE", "BLOODROOT", [3, 3, 3, 3, 2], 10, ["CAVE_TICK", "RAIL_RAT"])
	f.unit.max_hp = 60
	f.unit.hp = 60
	e = fired(run_turn(f))
	flow = tier(e, "Transfusion")
	check(int(hits(flow, "heal")[0].healed) == 10 and int(hits(flow)[0].amount) == 10, "Take Root has made the room the heal fills")
	## Heartsblood: max health, once for every point in the set.
	f = fight("RUE", "BLOODROOT", [2, 2, 2, 2, 2], 10, ["CAVE_TICK", "RAIL_RAT"])
	e = fired(run_turn(f))
	var heart: Array = hits(tier(e, "Heartsblood"))
	check(lit(e) == ["Take Root", "Transfusion", "Heartsblood"] and heart.size() == 10 and int(heart[0].amount) == 80, "five 2s: ten blows of her max health (%d of %d)" % [heart.size(), int(heart[0].get("amount", 0)) if not heart.is_empty() else 0])

# --- Puck -----------------------------------------------------------------------------------

func _test_highs_and_lows() -> void:
	var f: Dictionary = fight("PUCK", "HIGHS_AND_LOWS", [6, 2, 3, 4, 5])
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Comedy"] and hits(tier(e, "Comedy")).size() == 1 and int(hits(tier(e, "Comedy"))[0].amount) == 10, "a crown on a d6: one strike of Resonance")
	f = fight("PUCK", "HIGHS_AND_LOWS", [6, 1, 8, 3, 10])
	e = fired(run_turn(f))
	check(lit(e) == ["Comedy", "Tragedy"] and hits(tier(e, "Comedy")).size() == 6, "crowns on a d6, a d8 and a d10: one, two and three strikes (%d)" % hits(tier(e, "Comedy")).size())
	check(int(hits(tier(e, "Tragedy"), "block")[0].amount) == 10, "a 1 on a d6: Resonance block, once")
	f = fight("PUCK", "HIGHS_AND_LOWS", [2, 3, 1, 5, 1])
	e = fired(run_turn(f))
	check(lit(e) == ["Tragedy"] and int(hits(tier(e, "Tragedy"), "block")[0].amount) == 50, "a 1 on a d8 and one on the d10: five times Resonance block")
	## Standing Ovation: every die a Face, and the bowl grows for the fight.
	f = fight("PUCK", "HIGHS_AND_LOWS", [6, 1, 8, 1, 10])
	e = fired(run_turn(f))
	check(lit(e) == ["Comedy", "Tragedy", "Standing Ovation"] and f.unit.dice.map(func(d: Dictionary) -> String: return str(d.shape)) == ["D8", "D8", "D10", "D10", "D12"], "every die a Face: the dice grow a size (%s)" % str(f.unit.dice.map(func(d: Dictionary) -> String: return str(d.shape))))
	check(DeepBattle.dice_after_fight(f.unit).map(func(d: Dictionary) -> String: return str(d.shape)) == ["D6", "D6", "D8", "D8", "D10"], "and the fight gives them back as they were")
	check(f.unit.hand.size() == 5 and f.unit.hand.all(func(r: Dictionary) -> bool: return int(r.top) >= 8), "the next hand is thrown on the bigger dice")
	## A face raised for good after the Ovation is still raised when the fight hands the bowl
	## back: the sizes are filed off the die, a copy from before is not put in its place.
	var worked: Dictionary = f.unit.dice[0]
	for index in range(worked.faces.size()):
		if DeepDice.face_value(worked.faces[index]) == 1:
			if worked.faces[index] is Dictionary:
				worked.faces[index].value = 3
			else:
				worked.faces[index] = 3
			break
	var back: Dictionary = DeepBattle.dice_after_fight(f.unit)[0]
	var shown: Array = back.faces.map(func(face: Variant) -> int: return DeepDice.face_value(face))
	check(str(back.shape) == "D6" and shown.size() == 6 and not shown.has(1) and shown.count(3) == 2, "a face worked after the Ovation keeps its work (%s)" % str(shown))

func _test_patchwork() -> void:
	## Six gems that fire on any hand with a pair in it, one a color.
	var six: Array = [stone("STRIKE"), stone("RIPOSTE"), stone("THIRST"), stone("MIASMA"), stone("TITHE"), stone("PRISM")]
	var f: Dictionary = fight("PUCK", "PATCHWORK", [2, 2, 3, 5, 7], 10, ["CAVE_TICK"], six.slice(0, 3))
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Scraps"] and hits(tier(e, "Scraps")).size() == 3, "three colors fired: three blows of Resonance (%s, %d)" % [str(lit(e)), hits(tier(e, "Scraps")).size()])
	f = fight("PUCK", "PATCHWORK", [2, 2, 3, 5, 7], 10, ["CAVE_TICK"], [six[0], six[1], six[2], six[4]])
	f.unit.hp = 40
	e = fired(run_turn(f))
	var quilt: Dictionary = tier(e, "Quilt").effects[0]
	check(lit(e) == ["Scraps", "Quilt"] and quilt.colors == ["RED", "BLUE", "GREEN", "GOLD"], "four colors: each gives its gift (%s)" % str(quilt.get("colors", [])))
	check(quilt.hits.map(func(h: Dictionary) -> String: return str(h.kind)) == ["damage", "block", "heal", "gold"] and quilt.hits.all(func(h: Dictionary) -> bool: return int(h.amount) == int(e.resonance)),
		"damage, block, healing and pyrite, each worth Resonance")
	check(int(f.unit.gold) >= int(e.resonance), "the pyrite is in his purse")
	## Whole Cloth: the dice go again, the rail goes again, and the Birthstone after it, once.
	f = fight("PUCK", "PATCHWORK", [2, 2, 3, 5, 7], 10, ["CAVE_TICK"], six)
	var events: Array = run_turn(f)
	var stones: Array = events.filter(func(ev: Dictionary) -> bool: return str(ev.kind) == "birthstone")
	check(stones.size() == 2 and lit(stones[0]) == ["Scraps", "Quilt", "Whole Cloth"] and tier(stones[0], "Whole Cloth").effects[0].thrown.size() == 5, "all six colors: every die is thrown again")
	check(bool(stones[1].replay) and not bool(tier(stones[1], "Whole Cloth").active) and str(tier(stones[1], "Whole Cloth").reason) == "Once a turn.", "the Birthstone's second go leaves Whole Cloth dark")
	var first_at: int = events.find(stones[0])
	var second_at: int = events.find(stones[1])
	var between: Array = events.slice(first_at + 1, second_at).filter(func(ev: Dictionary) -> bool: return str(ev.kind) in ["gem_fire", "gem_fizzle"])
	check(between.size() == 6, "every gem has its second act between them (%d)" % between.size())
	var gifts: Array = tier(stones[0], "Quilt").effects[0].hits
	check(tier(stones[0], "Quilt").effects[0].colors.size() == 6 and gifts.filter(func(h: Dictionary) -> bool: return str(h.kind) == "charged").size() == 1,
		"all six pay, and White's gift is Charged for next turn")
	## White's gift is a point a color, not the Resonance: worth the Resonance it fed itself.
	var charged: Array = gifts.filter(func(h: Dictionary) -> bool: return str(h.kind) == "charged")
	check(not charged.is_empty() and int(charged[0].amount) == 6 and int(stones[0].resonance) > 6, "a point for each color sewn (%s of %d Resonance)" % [str(charged[0].get("amount", "?")) if not charged.is_empty() else "none", int(stones[0].resonance)])
	var opens: int = int(f.unit.get("initial_resonance", 0)) + int(f.unit.statuses.get("charged", 0))
	check(opens >= 6 and opens <= 12, "which opens her next rail a little higher, twice over at the most (%d)" % opens)

# --- Florin ---------------------------------------------------------------------------------

func _test_bandit() -> void:
	var f: Dictionary = fight("FLORIN", "ONE_ARMED_BANDIT", [5, 5, 5, 2, 2])
	var e: Dictionary = fired(run_turn(f))
	var res: int = int(e.resonance)
	var pair: Dictionary = tier(e, "Two of a kind").effects[0]
	var triple: Dictionary = tier(e, "Three of a kind").effects[0]
	check(lit(e) == ["Two of a kind", "Three of a kind"] and pair.paid.size() == 1 and int(pair.paid[0].value) == 2 and str(pair.paid[0].prize) == "block" and int(pair.paid[0].amount) == res,
		"a pair of 2s: the Block prize, once (%s)" % str(pair.get("paid", [])))
	check(int(triple.paid[0].value) == 5 and str(triple.paid[0].prize) == "damage" and int(triple.paid[0].amount) == 2 * res and triple.hits.size() == 3, "three 5s: the damage prize, twice Resonance, three times")
	f = fight("FLORIN", "ONE_ARMED_BANDIT", [1, 1, 3, 4, 7])
	f.unit.hp = 30
	e = fired(run_turn(f))
	check(lit(e) == ["Two of a kind"] and str(tier(e, "Two of a kind").effects[0].paid[0].prize) == "heal" and int(tier(e, "Two of a kind").effects[0].hits[0].healed) == int(e.resonance), "a pair of 1s heals Resonance")
	f = fight("FLORIN", "ONE_ARMED_BANDIT", [3, 3, 4, 4, 7])
	e = fired(run_turn(f))
	var both: Array = tier(e, "Two of a kind").effects[0].paid
	check(both.size() == 2 and both.map(func(p: Dictionary) -> String: return str(p.prize)) == ["gold", "poison"], "two pairs pay two prizes: pyrite for the 4s, Poison for the 3s (%s)" % str(both.map(func(p: Dictionary) -> String: return str(p.prize))))
	f = fight("FLORIN", "ONE_ARMED_BANDIT", [4, 4, 4, 4, 7])
	e = fired(run_turn(f))
	check(lit(e) == ["Three of a kind"] and tier(e, "Three of a kind").effects[0].hits.size() == 3, "four of a kind pays as three")
	f = fight("FLORIN", "ONE_ARMED_BANDIT", [7, 7, 7, 7, 7])
	e = fired(run_turn(f))
	var jackpot: Dictionary = tier(e, "Jackpot")
	check(lit(e) == ["Jackpot"] and jackpot.effects[0].hits.size() == 7 and int(jackpot.effects[0].paid[0].amount) == 4 * int(e.resonance) and int(hits(jackpot, "gold")[0].amount) == 7 * int(e.resonance),
		"five 7s: the 7s' prize seven times, and seven times Resonance in pyrite")
	f = fight("FLORIN", "ONE_ARMED_BANDIT", [6, 6, 1, 2, 3])
	e = fired(run_turn(f))
	check(int(tier(e, "Two of a kind").effects[0].paid[0].amount) == 3 * int(e.resonance), "a number with no prize of its own pays damage, a point more for every point over 3")
	f = fight("FLORIN", "ONE_ARMED_BANDIT", [1, 2, 3, 4, 5])
	check(not bool(fired(run_turn(f)).get("fired", true)), "nothing matching pays nothing, and costs nothing")

func _test_blackjack() -> void:
	var f: Dictionary = fight("FLORIN", "BLACKJACK", [5, 4, 3, 7, 1])
	var e: Dictionary = fired(run_turn(f))
	check(lit(e) == ["Stand"] and int(hits(tier(e, "Stand"))[0].amount) == 4 * int(e.resonance), "a total of 20: Resonance for each of the four points over 16")
	f = fight("FLORIN", "BLACKJACK", [5, 4, 3, 4, 1])
	e = fired(run_turn(f))
	check(lit(e) == ["Stand"] and int(hits(tier(e, "Stand"))[0].amount) == int(e.resonance), "a total of 17: Resonance once")
	f = fight("FLORIN", "BLACKJACK", [5, 5, 3, 7, 1])
	e = fired(run_turn(f))
	var blackjack: Dictionary = tier(e, "Twenty-One")
	check(lit(e) == ["Twenty-One"] and hits(blackjack).size() == 3 and int(hits(blackjack)[0].amount) == 7 * int(e.resonance) and int(hits(blackjack, "gold")[0].amount) == 21, "exactly 21: seven times Resonance three times, and 21 pyrite")
	f = fight("FLORIN", "BLACKJACK", [7, 7, 5, 2, 1])
	var hp: int = int(f.unit.hp)
	e = fired(run_turn(f))
	check(lit(e) == ["Bust"] and str(hits(tier(e, "Bust"))[0].target) == "a" and int(f.unit.hp) == hp - int(e.resonance), "22: a Bust, and he takes Resonance himself")
	f = fight("FLORIN", "BLACKJACK", [1, 2, 3, 4, 5])
	check(not bool(fired(run_turn(f)).get("fired", true)), "16 or less: the stone stays dark")
	check(bool(DeepContent.birthstone_def("FLORIN", "BLACKJACK").tiers[2].get("penalty", false)), "Bust is marked as a loss for the screens")

# --- the forecast ---------------------------------------------------------------------------

func _test_forecast() -> void:
	## What the dock promises before the rail closes is what the stone then does, and looking
	## ahead changes nothing: no Trophy taken, no 1s counted, no dice grown.
	for case in [["ARDOR", "RAMPART", [2, 4, 6, 2, 5]], ["ARDOR", "RENOWN", [6, 6, 6, 7, 1]], ["VESPER", "ILL_OMEN", [1, 1, 1, 1, 7]],
			["VESPER", "FAN_OF_KNIVES", [3, 3, 2, 2, 9]], ["CADENCE", "ARPEGGIO", [1, 2, 3, 4, 5]], ["RUE", "MITHRIDATE", [2, 3, 4, 5, 1]],
			["RUE", "BLOODROOT", [1, 1, 1, 3, 4]], ["PUCK", "HIGHS_AND_LOWS", [6, 1, 8, 1, 10]], ["FLORIN", "ONE_ARMED_BANDIT", [5, 5, 5, 2, 2]], ["FLORIN", "BLACKJACK", [5, 4, 3, 7, 1]]]:
		## With a creature a blow would kill, so a Trophy or a thrown-again knife is there to be taken.
		var weak: Dictionary = fight(str(case[0]), str(case[1]), case[2])
		foe(weak).hp = 3
		var before: Dictionary = weak.unit.duplicate(true)
		DeepBattle.forecast(weak.state, "a")
		check(weak.unit.hash() == before.hash() and int(foe(weak).hp) == 3, "%s: a forecast leaves the fight as it was" % str(case[1]))
		var f: Dictionary = fight(str(case[0]), str(case[1]), case[2])
		var seen: Dictionary = DeepBattle.forecast(f.state, "a").birthstone
		var promised: Array = seen.tiers.filter(func(t: Dictionary) -> bool: return bool(t.active)).map(func(t: Dictionary) -> String: return str(t.name))
		var e: Dictionary = fired(run_turn(f))
		check(promised == lit(e) and not promised.is_empty(), "%s: the tiers the forecast lights are the ones that fire (%s / %s)" % [str(case[1]), str(promised), str(lit(e))])

# --- at home: buying one, wearing one ----------------------------------------------------------

func _test_buying() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Stones")
	check(DeepProfile.owned_birthstones(profile, "ARDOR").is_empty() and DeepProfile.worn_birthstone(profile, "ARDOR") == "" and DeepProfile.owns_birthstone(profile, "ARDOR", ""),
		"a delver starts with their first stone and wears it")
	check(not DeepEconomy.unlock_birthstone(profile, "ARDOR", "RAMPART").ok, "an empty purse buys no stone")
	profile.gold = 1000 + 2500 + 7
	check(not DeepEconomy.unlock_birthstone(profile, "ARDOR", "BLOODROOT").ok and not DeepEconomy.unlock_birthstone(profile, "ARDOR", "").ok and not DeepEconomy.unlock_birthstone(profile, "RUE", "BLOODROOT").ok,
		"nor another delver's stone, the first stone, or a stone for a delver who has not joined")
	var bought: Dictionary = DeepEconomy.unlock_birthstone(profile, "ARDOR", "RAMPART")
	check(bought.ok and int(bought.paid) == 1000 and int(profile.gold) == 2507 and DeepProfile.owned_birthstones(profile, "ARDOR") == ["RAMPART"], "Rampart is bought for 1,000 gold")
	check(DeepProfile.worn_birthstone(profile, "ARDOR") == "", "buying a stone does not put it on")
	check(not DeepEconomy.unlock_birthstone(profile, "ARDOR", "RAMPART").ok and int(profile.gold) == 2507, "and it is not sold twice")
	check(DeepProfile.wear_birthstone(profile, "ARDOR", "RENOWN") != "" and DeepProfile.worn_birthstone(profile, "ARDOR") == "", "a stone not yet bought cannot be worn")
	check(DeepProfile.wear_birthstone(profile, "ARDOR", "RAMPART") == "" and DeepProfile.worn_birthstone(profile, "ARDOR") == "RAMPART", "a stone that is theirs can")
	check(DeepEconomy.unlock_birthstone(profile, "ARDOR", "RENOWN").ok and int(profile.gold) == 7 and DeepProfile.owned_birthstones(profile, "ARDOR") == ["RAMPART", "RENOWN"], "Renown is bought for 2,500")
	check(DeepProfile.wear_birthstone(profile, "ARDOR", "") == "" and DeepProfile.worn_birthstone(profile, "ARDOR") == "", "and the first stone can always be put back on")
	check(DeepProfile.wear_birthstone(profile, "ARDOR", "MITHRIDATE") != "" and DeepProfile.wear_birthstone(profile, "RUE", "") != "", "a stone that is not theirs, or a delver not yet met, wears nothing")
	## A save from before the variants reads as owning none; one that names a stone it does not own wears the first.
	var old: Dictionary = DeepProfile.new_profile("Old")
	old.characters.ARDOR.birthstone = "RENOWN"
	check(DeepProfile.worn_birthstone(old, "ARDOR") == "" and not DeepProfile.upgrade(old), "an old save wears each delver's first stone and needs nothing added")
	## What the lobby will take from a member.
	check(DeepSession.clean_member_fields({"birthstone": "RAMPART"}).get("birthstone", "x") == "RAMPART" and DeepSession.clean_member_fields({"birthstone": ""}).get("birthstone", "x") == "", "a member may say which stone they wear")
	check(not DeepSession.clean_member_fields({"birthstone": "NOPE"}).has("birthstone") and not DeepSession.clean_member_fields({"birthstone": 5}).has("birthstone"), "but not one nobody has")

# --- down the mine ---------------------------------------------------------------------------

func _run(character: String, worn: String, mine_key: String = "", seed_value: int = 11) -> Dictionary:
	var config: Dictionary = {"seed": seed_value, "mine": mine_key if not mine_key.is_empty() else DeepContent.starter_mine(), "boons": false,
		"players": [{"id": "a", "name": "A", "character": character, "rail": [], "dice": dice(DeepContent.character(character).dice, "a"), "birthstone": worn}]}
	return DeepDescent.new_run(config)

func _test_run() -> void:
	var run: Dictionary = _run("ARDOR", "RENOWN")
	var unit: Dictionary = run.players[0]
	check(str(unit.birthstone.name) == "Renown" and str(unit.birthstone_key) == "RENOWN" and not unit.has("head_start"), "a run goes down in the stone its player wears, with no head start in the first mine")
	check(str(_run("ARDOR", "BLOODROOT").players[0].birthstone.name) == "Rally" and str(_run("ARDOR", "").players[0].birthstone.name) == "Rally", "a stone that is not theirs goes down as their first")
	## A deep start opens with what the mines above would have grown.
	var order: Array = DeepContent.mines_in_order()
	var floors: int = DeepContent.mine_bottom(str(order[0])) + DeepContent.mine_bottom(str(order[1]))
	run = _run("ARDOR", "RENOWN", str(order[2]))
	unit = run.players[0]
	check(DeepBattle.trophies(unit) == floors * 40 / 100 and int(unit.head_start.trophies) == DeepBattle.trophies(unit) and DeepBattle.trophies(unit) > 0,
		"a Renown that starts two mines down opens with the Trophies of the floors above (%d for %d floors)" % [DeepBattle.trophies(unit), floors])
	check(DeepBattle.trophies(_run("ARDOR", "RAMPART", str(order[2])).players[0]) == 0 and not _run("ARDOR", "", str(order[2])).players[0].has("head_start"), "no other stone of his does")
	run = _run("RUE", "BLOODROOT", str(order[2]))
	unit = run.players[0]
	var base: int = int(DeepContent.character("RUE").hp)
	check(int(unit.max_hp) == base + floors * 350 / 100 and int(unit.hp) == int(unit.max_hp), "a Bloodroot opens with the max health they would have grown (%d)" % int(unit.max_hp))
	## The Trophies come out of a fight with the fighter and go into the next.
	var fighter: Dictionary = unit.duplicate(true)
	fighter.run_counts = {DeepBattle.TROPHIES: 3}
	run.chamber = {"battle": {"players": [fighter], "enemies": []}}
	DeepDescent._sync_fighters(run)
	check(DeepBattle.trophies(DeepDescent.player(run, "a")) == 3, "what a fight took, the run keeps")
	## The profile counts a conquest under the stone that was worn.
	var profile: Dictionary = DeepProfile.new_profile("Records")
	var mine: String = DeepContent.starter_mine()
	var result: Dictionary = {"run_id": "r1", "mine": mine, "outcome": "conquered", "depth": 16, "mines": [{"mine": mine, "deepest": 16, "wardens": [], "boss": true}],
		"players": {"a": {"character": "ARDOR", "birthstone": "RAMPART", "birthstone_of": "", "seen": [], "haul": []}}}
	DeepProfile.apply_result(profile, result, "a")
	check(DeepProfile.stone_conquests(profile, "ARDOR", "RAMPART") == [mine] and DeepProfile.stone_conquests(profile, "ARDOR", "").is_empty(), "a mine beaten in Rampart is Rampart's conquest, not Rally's")
	check(str(profile.history.back().get("birthstone", "")) == "RAMPART", "and the run's line in the ledger names the stone")
	result.players.a.birthstone = ""
	result.run_id = "r2"
	DeepProfile.apply_result(profile, result, "a")
	check(DeepProfile.stone_conquests(profile, "ARDOR", "") == [mine] and not profile.history.back().has("birthstone"), "the first stone keeps its own")

# --- the daily dig ---------------------------------------------------------------------------

func _test_daily() -> void:
	## Every day lends one of the day's delver's three stones; a Borrowed Birthstone day lends
	## one of another delver's three.
	var seen_worn: Dictionary = {}
	var borrowed: Dictionary = {}
	for day in range(1, 400):
		var date: String = "2027-%02d-%02d" % [1 + (day / 28) % 12, 1 + day % 28]
		var plan: Dictionary = DeepEconomy.daily_plan(date)
		var keys: Array = DeepContent.birthstone_keys(str(plan.lapidary))
		if not keys.has(str(plan.get("worn", "?"))):
			check(false, "%s: the day's stone is one of the day's delver's (%s)" % [date, str(plan.get("worn", "?"))])
			return
		seen_worn[str(plan.worn)] = true
		if plan.has("birthstone"):
			if str(plan.birthstone) == str(plan.lapidary) or not DeepContent.birthstone_keys(str(plan.birthstone)).has(str(plan.get("birthstone_key", "?"))):
				check(false, "%s: a borrowed stone is one of another delver's" % date)
				return
			if borrowed.is_empty() or (str(borrowed.get("birthstone_key", "")).is_empty() and not str(plan.birthstone_key).is_empty()):
				borrowed = plan
	check(seen_worn.size() >= 10, "over a year the days lend first stones and variants alike (%d different)" % seen_worn.size())
	check(not borrowed.is_empty() and not str(borrowed.get("birthstone_key", "")).is_empty(), "and a Borrowed Birthstone day can lend a variant")
	check(DeepEconomy.daily_plan("2027-03-03").hash() == DeepEconomy.daily_plan("2027-03-03").hash(), "a day's plan is the same every time it is asked for")
	var config: Dictionary = DeepEconomy.daily_config(str(borrowed.date), [{"id": "a", "name": "A"}], "daily_test")
	config.boons = false
	var unit: Dictionary = DeepDescent.new_run(config).players[0]
	check(str(unit.get("birthstone_of", "")) == str(borrowed.birthstone) and str(unit.birthstone.name) == str(DeepContent.birthstone_def(str(borrowed.birthstone), str(borrowed.birthstone_key)).name)
		and str(DeepStone.birthstone_for(unit).name) == str(unit.birthstone.name), "the borrowed day's seat fires and shows the lent stone (%s)" % str(unit.birthstone.name))
	var plain_day: String = ""
	for day in range(1, 60):
		var date: String = "2027-07-%02d" % (1 + day % 28)
		var plan: Dictionary = DeepEconomy.daily_plan(date)
		if not plan.has("birthstone") and not str(plan.worn).is_empty():
			plain_day = date
			break
	if not plain_day.is_empty():
		var plan: Dictionary = DeepEconomy.daily_plan(plain_day)
		config = DeepEconomy.daily_config(plain_day, [{"id": "a", "name": "A"}], "daily_test2")
		config.boons = false
		unit = DeepDescent.new_run(config).players[0]
		check(str(unit.birthstone_key) == str(plan.worn) and not unit.has("birthstone_of"), "an ordinary day's seat goes down in the day's variant (%s)" % str(unit.birthstone.name))
