extends SceneTree
## The edges of a fight's numbers: every count stops at DeepRules.CEILING instead of wrapping
## round to a huge negative one, and a rail that would fire for ever is spent at RAIL_CAP.

var checks: int = 0
var failures: Array = []
const CEIL: int = DeepRules.CEILING

func _init() -> void:
	_test_arithmetic()
	_test_effects()
	_test_blows()
	_test_creature_health()
	_test_rail_cap()
	_test_view()
	_test_steps()
	_test_one_of_each()
	print("Limits: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func gem(skill: String, carat: int = 1, cut: int = 4, clarity: int = 3, id: String = "") -> Dictionary:
	var s: Dictionary = DeepStone.make(skill, carat, cut, clarity, [], {}, id if not id.is_empty() else "%s_%d" % [skill.to_lower(), randi()])
	s.appraised = true
	s.inclusions_revealed = true
	return s

func rngs(seed_value: int) -> Dictionary:
	return DeepRng.streams(seed_value, ["dice", "creatures"])

func player(id: String, rail: Array) -> Dictionary:
	var dice: Array = []
	var keys: Array = DeepContent.character("ARDOR").dice
	for index in range(keys.size()):
		dice.append(DeepForge.die_from(keys[index], "%s%d" % [id, index]))
	return DeepBattle.make_player(id, id.capitalize(), "ARDOR", rail, dice)

func hand(unit: Dictionary, numbers: Array) -> void:
	var out: Array = []
	for index in range(numbers.size()):
		var die: Dictionary = unit.dice[index % unit.dice.size()]
		out.append({"die_id": str(die.id), "shape": str(die.shape), "material": "", "value": int(numbers[index]), "face": 0, "kind": "plain",
			"top": DeepDice.top(die), "held": false, "rerolls": 0, "locked": false, "explosions": 0, "phantom": false})
	unit.hand = out

func fight(rail: Array, seed_value: int = 3) -> Dictionary:
	var r: Dictionary = rngs(seed_value)
	var state: Dictionary = DeepBattle.begin([player("a", rail)], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	return {"state": state, "r": r}

func _test_arithmetic() -> void:
	check(DeepRules.sat_add(CEIL, 5) == CEIL, "a sum past the ceiling stops there")
	check(DeepRules.sat_add(-CEIL, -5) == -CEIL, "and so does one below the floor")
	check(DeepRules.sat_add(40, 2) == 42, "a small sum is a sum")
	check(DeepRules.sat_mul(100000000, 100000000) == CEIL, "a product past the ceiling stops there")
	check(DeepRules.sat_mul(-100000000, 100000000) == -CEIL, "with its sign")
	check(DeepRules.sat_mul(9223372036854775807, 2) == CEIL, "even one that would wrap a whole number")
	check(DeepRules.sat_mul(6, 7) == 42, "a small product is a product")
	check(DeepRules.sat_floor(INF) == CEIL, "infinity is the ceiling, not a huge negative number")
	check(DeepRules.sat_floor(-INF) == -CEIL, "and minus infinity the floor")
	check(DeepRules.sat_floor(NAN) == 0, "nothing at all is nought")
	check(DeepRules.sat_floor(1e30) == CEIL, "a float too big for a whole number stops at the ceiling")
	check(DeepRules.sat_floor(-2.5) == -3, "below the ceiling it rounds down as before")
	check(DeepRules.sat_scale(7, 110, 125, 10000) == 7 * 110 * 125 / 10000, "a scaled blow is worked in whole numbers")
	check(DeepRules.sat_muldiv(-7, 3, 2) == -10, "and cut toward nought")
	check(DeepRules.sat_scale(CEIL, 200, 125, 10000) == CEIL, "a scaled ceiling stays the ceiling")
	check(DeepRules.infinite(CEIL) and not DeepRules.infinite(CEIL - 1), "only the ceiling itself reads as Infinite")

func _test_effects() -> void:
	var resolved: Dictionary = DeepRules.resolve_effect({"kind": "damage", "amount": {"const": 5}}, {}, INF)
	check(int(resolved.amount) == DeepRules.VALUE_LIMIT, "an infinitely heavy stone still lands its most, not its least")
	var shared: Dictionary = DeepRules.resolve_effect({"kind": "damage", "amount": {"const": 5}, "share": {"const": 50}}, {}, 1e40)
	check(int(shared.amount) == DeepRules.VALUE_LIMIT, "so does a share of one")
	check(DeepRules.amount({"op": "*", "args": [{"const": 100000000}, {"const": 100000000}, {"const": 100000000}]}, {}) == CEIL, "a rule's product stops at the ceiling")
	check(DeepRules.amount({"op": "+", "args": [{"const": CEIL}, {"const": CEIL}]}, {}) == CEIL, "and its sum")

func _test_blows() -> void:
	var f: Dictionary = fight([gem("STRIKE")])
	var state: Dictionary = f.state
	var me: Dictionary = state.players[0]
	var foe: Dictionary = state.enemies[0]
	## A Ferment on a creature already carrying nearly everything (its Ward taken off first).
	foe.statuses.erase("ward")
	foe.statuses.poison = CEIL - 10
	DeepBattle._apply_one(state, me, foe, "grow_poison", 300, {}, f.r.dice)
	check(int(foe.statuses.poison) == CEIL, "Poison grown past the ceiling stops there instead of wrapping")
	DeepBattle._apply_one(state, me, foe, "poison", DeepRules.VALUE_LIMIT, {}, f.r.dice)
	check(int(foe.statuses.poison) == CEIL, "and more on top changes nothing")
	## A Detonate on all of it: a blow of the ceiling, which fells it.
	var hit: Dictionary = DeepBattle._apply_one(state, me, foe, "detonate", 4, {}, f.r.dice)
	check(int(hit.get("raw", 0)) == CEIL, "a Detonate of the ceiling hits for the ceiling")
	check(bool(hit.get("killed", false)) and int(foe.hp) == 0, "and the creature falls, not heals")
	## Block, gold and Resonance stop there too.
	me.block = CEIL - 1
	DeepBattle._apply_one(state, me, me, "block", DeepRules.VALUE_LIMIT, {}, f.r.dice)
	check(int(me.block) == CEIL, "block stops at the ceiling")
	me.gold = CEIL
	DeepBattle._apply_one(state, me, me, "gold", 50, {}, f.r.dice)
	check(int(me.gold) == CEIL, "and pyrite won")
	me.resonance = CEIL - 1
	DeepBattle._self_effect(state, me, {"kind": "resonance", "amount": 9999}, 0, -1, false, f.r.dice)
	check(int(me.resonance) == CEIL, "and Resonance")
	## A Marked blow on top of a huge one.
	var g: Dictionary = fight([gem("STRIKE")])
	var other: Dictionary = g.state.enemies[0]
	other.statuses.marked = 3
	other.statuses.curse = 10
	var blow: Dictionary = DeepBattle._damage(g.state, g.state.players[0], other, CEIL / 2, g.r.dice)
	check(int(blow.raw) == CEIL, "a Marked, Cursed blow past the ceiling lands as the ceiling")

func _test_creature_health() -> void:
	var deep: Dictionary = DeepCreatures.make("THE_REGENT", "deep", 100000, 4, {"hp": 1.0e14})
	check(int(deep.hp) == CEIL and int(deep.max_hp) == CEIL, "a creature too big to count has the ceiling's health, not one")

func _test_rail_cap() -> void:
	## Two Geminis side by side wake each other for ever while the hand holds a pair.
	var f: Dictionary = fight([gem("STRIKE", 1, 4, 3, "s0"), gem("GEMINI", 1, 4, 3, "g1"), gem("GEMINI", 1, 4, 3, "g2"), gem("STRIKE", 1, 4, 3, "s3")])
	var state: Dictionary = f.state
	hand(state.players[0], [4, 4, 4, 4, 4])
	state.players[0].locked = true
	var events: Array = [DeepBattle.start_resolution(state)]
	var guard: int = 0
	while DeepBattle.has_steps(state) and str(state.get("phase", "")) == "resolving" and guard < 5000:
		guard += 1
		var event: Dictionary = DeepBattle.step(state, f.r.dice, f.r.creatures)
		if not event.is_empty():
			events.append(event)
	var plays: Array = events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) in ["gem_fire", "gem_fizzle", "birthstone"] and str(e.get("unit", "")) == "a")
	var spent: Array = events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "rail_spent")
	check(guard < 5000, "a rail that would fire for ever ends its turn")
	check(plays.size() == DeepBattle.RAIL_CAP, "after exactly %d plays (played %d)" % [DeepBattle.RAIL_CAP, plays.size()])
	check(spent.size() == 1 and int(spent[0].get("dropped", 0)) > 0, "with one rail_spent, saying what was dropped")
	check(events.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "rail_end"), "and its close still plays")
	check(str(state.get("phase", "")) in ["planning", "over"], "and the turn goes on to the next")
	check(DeepBattle.rail_plays(state) == 0, "and once the rail has closed it hurries nothing")
	## A rail that keeps firing plays faster and faster.
	check(is_equal_approx(DeepBattle.rush(0), 1.0) and is_equal_approx(DeepBattle.rush(DeepBattle.RUSH_FROM), 1.0), "an ordinary rail plays at the fight speed")
	check(DeepBattle.rush(DeepBattle.RUSH_FROM + 4) > 1.5 and DeepBattle.rush(50) > DeepBattle.rush(30), "a long one faster with every gem")
	check(DeepBattle.rush(DeepBattle.RAIL_CAP) > 8.0, "past the fight speed's own top by the cap")
	check(is_equal_approx(DeepBattle.rush(100000), DeepBattle.RUSH_MOST), "and never past its most")
	## An ordinary rail never comes near it.
	var g: Dictionary = fight([gem("STRIKE"), gem("GEMINI"), gem("STRIKE")])
	hand(g.state.players[0], [4, 4, 6, 6, 1])
	g.state.players[0].locked = true
	var ordinary: Array = [DeepBattle.start_resolution(g.state)]
	var steps: int = 0
	while DeepBattle.has_steps(g.state) and str(g.state.get("phase", "")) == "resolving" and steps < 400:
		steps += 1
		var e: Dictionary = DeepBattle.step(g.state, g.r.dice, g.r.creatures)
		if not e.is_empty():
			ordinary.append(e)
	check(not ordinary.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "rail_spent"), "an ordinary rail is never spent")

func _test_steps() -> void:
	## A multiplier grows with carat the way a whole-number effect's procs do: the owner's table.
	var table: Dictionary = {1: 0.0, 2: 0.083, 7: 0.5, 13: 1.0, 19: 1.5, 20: 1.667, 21: 2.0, 23: 2.667, 24: 3.0}
	for carat in table:
		var steps: float = DeepRules.carat_steps(DeepStone.carat_multiplier(float(carat)))
		check(absf(steps - float(table[carat])) < 0.001, "carat %d reads %.3f steps (got %.3f)" % [carat, table[carat], steps])
	var def: Dictionary = {"kind": "amplify_next", "amount": 50, "scale": "steps"}
	check(int(DeepRules.resolve_effect(def, {}, DeepStone.carat_multiplier(1.0)).amount) == 50, "a 1-carat multiplier is its own number")
	check(int(DeepRules.resolve_effect(def, {}, DeepStone.carat_multiplier(13.0)).amount) == 100, "twice it at 13 carats")
	check(int(DeepRules.resolve_effect(def, {}, DeepStone.carat_multiplier(24.0)).amount) == 200, "four times it at 24")
	check(int(DeepRules.resolve_effect(def, {}, DeepStone.carat_multiplier(24.0)).procs) == 1, "and never fires more often for it")
	var clear: int = DeepContent.clear_index()
	check(DeepStone.text(DeepStone.make("BLOODLETTING", 1, 2, clear, [], {}, "b1")).contains("amplified by 50%"), "the card says what a light stone does")
	check(DeepStone.text(DeepStone.make("BLOODLETTING", 24, 2, clear, [], {}, "b24")).contains("amplified by 200%"), "and what a heavy one does")
	check(DeepStone.text(DeepStone.make("HEMLOCK", 13, 2, clear, [], {}, "h13")).contains("400% of your Poison"), "Hemlock's share is written with its weight")
	check(DeepStone.text(DeepStone.make("PINFIRE", 24, 2, clear, [], {}, "p24")).contains("400% of the Resonance"), "and Pinfire's")

func _test_one_of_each() -> void:
	## A rail holds one stone of each skill, riders included; a stone already on it only moves.
	var clear: int = DeepContent.clear_index()
	var strike: Dictionary = DeepStone.make("STRIKE", 4, 2, clear, [], {}, "s1")
	var other: Dictionary = DeepStone.make("STRIKE", 9, 3, clear, [], {}, "s2")
	var guard: Dictionary = DeepStone.make("GUARD", 4, 2, clear, [], {}, "g1")
	for s in [strike, other, guard]:
		s.appraised = true
		s.inclusions_revealed = true
	var unit: Dictionary = {"id": "a", "character": "ARDOR", "rail": [strike, null, null], "sockets": ["ANY", "ANY", "ANY"], "riders": [[], [], []], "haul": [other, guard]}
	check(not DeepDescent.socket_refusal(unit, other, 1).is_empty(), "a second Strike from the bag is refused")
	check(DeepDescent.socket_refusal(unit, other, 1).contains("Strike"), "and the refusal names it")
	check(DeepDescent.socket_refusal(unit, other, 0).is_empty(), "but it may take the first one's place")
	check(DeepDescent.socket_refusal(unit, strike, 2).is_empty(), "the one on the rail moves freely")
	check(DeepDescent.socket_refusal(unit, guard, 1).is_empty(), "another skill is welcome")
	var ghost: Dictionary = other.duplicate(true)
	ghost.id = "s3"
	ghost.inclusions = ["VOID"]
	check(not DeepDescent.socket_refusal(unit, ghost, 1).is_empty(), "a Void Strike may not ride beside a Strike either")
	check(not DeepOddities.hollow_refusal(other, unit).is_empty(), "nor may the Hollow put one there")
	check(DeepOddities.hollow_refusal(guard, unit).is_empty(), "but it may put another skill there")
	## A rail laid before the rule keeps its pair, and may still be rearranged.
	var twins: Dictionary = {"id": "b", "character": "ARDOR", "rail": [strike, other, null], "sockets": ["ANY", "ANY", "ANY"], "riders": [[], [], []], "haul": []}
	check(DeepDescent.socket_refusal(twins, other, 2).is_empty(), "a rail that already has two may move them about")

func _test_view() -> void:
	check(DeepUi.number(999999) == "999999", "a count under a million is written out")
	check(DeepUi.number(1234567) == "1.23M", "a million and more is shortened")
	check(DeepUi.number(12345678) == "12.3M" and DeepUi.number(123456789) == "123M", "to three figures")
	check(DeepUi.number(1000000000) == "1B" and DeepUi.number(5600000000000) == "5.6T", "with no trailing nought")
	check(DeepUi.number(-2500000) == "−2.5M", "and its sign")
	check(DeepUi.number(CEIL) == DeepUi.INFINITY_MARK, "the ceiling is written as Infinite")
	check(DeepUi.number(-CEIL) == "−" + DeepUi.INFINITY_MARK, "and so is the floor")
	var screen: Script = load("res://view/battle/battle_screen.gd")
	check(screen.reaches_infinity({"effects": [{"kind": "damage", "raw": CEIL, "hp_loss": 900}]}), "a blow of the ceiling is the player reaching Infinite")
	check(screen.reaches_infinity({"effects": [{"kind": "poison", "poison_after": CEIL}]}), "so is Poison stacked to it")
	check(not screen.reaches_infinity({"effects": [{"kind": "damage", "raw": 40, "hp_after": CEIL, "max_hp": CEIL}]}), "a creature born at the ceiling is not")
	check(not screen.reaches_infinity({"effects": [{"kind": "damage", "raw": CEIL - 1}]}), "nor anything short of it")
