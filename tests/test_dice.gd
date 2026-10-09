extends SceneTree
## Dice, hands and patterns: the foundation every gem stands on.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_rolls()
	_test_analysis()
	_test_wilds_and_faces()
	_test_cut_patterns()
	_test_materials()
	_test_patterns()
	_test_ladders_and_words()
	print("Dice/hands/patterns: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func die(shape: String, faces: Array, id: String, opts: Dictionary = {}) -> Dictionary:
	var made: Dictionary = opts.duplicate()
	made.faces = faces.map(func(f: Variant) -> Dictionary: return f if f is Dictionary else DeepDice.face(int(f)))
	return DeepDice.make(shape, id, made)

func d6(id: String, opts: Dictionary = {}) -> Dictionary:
	return DeepDice.make("D6", id, opts)

func hand(numbers: Array, tops: int = 6) -> Array:
	var out: Array = []
	for index in range(numbers.size()):
		var entry: Variant = numbers[index]
		var kind: String = "plain"
		var value: int = 0
		if entry is String:
			kind = entry
			value = tops if kind == "wild" else 0
		else:
			value = int(entry)
		out.append({"die_id": "d%d" % index, "shape": "D6", "material": "", "value": value, "face": 0, "kind": kind,
			"top": tops, "held": false, "rerolls": 0, "locked": false, "explosions": 0, "phantom": false})
	return out

func _test_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dice: Array = [d6("a"), d6("b"), DeepDice.make("D20", "c"), d6("i", {"material": "iron"}),
		die("D6", [1, 2, 3, 4, 5, DeepDice.face(6, "doubled")], "x")]
	for _i in range(200):
		var rolled: Array = DeepDice.roll_hand(dice, rng)
		check(rolled.size() == 5, "five dice roll five results")
		check(rolled[0].value >= 1 and rolled[0].value <= 6, "a d6 shows 1 to 6")
		check(rolled[2].value >= 1 and rolled[2].value <= 20, "a d20 shows 1 to 20")
		check(rolled[3].value >= 1 and rolled[3].value <= 6 and int(rolled[3].face) == int(rolled[3].value) - 1, "an iron d6 shows one of its own faces, at what it says")
		check(rolled[4].value != 6 or int(rolled[4].face) != 5, "a doubled six reads as twelve, never as six")
		check(int(rolled[2].top) == 20 and int(rolled[4].top) == 12, "top reads the best face a die can show, doubling included")
	var first: Array = DeepDice.roll_hand(dice, rng)
	var again: Array = DeepDice.reroll(first, dice, ["a", "c"], rng)
	check(again[1].held and again[3].held and not again[0].held and not again[2].held, "unselected dice are held, selected dice are not")
	check(int(again[0].rerolls) == 1 and int(again[1].rerolls) == 0, "rerolled dice count their rerolls")
	var exploding: Dictionary = die("D6", [1, 2, 3, 4, 5, DeepDice.face(6, "exploding")], "boom")
	var biggest: int = 0
	for _i in range(400):
		var roll: Dictionary = DeepDice.roll_one(exploding, rng)
		biggest = maxi(biggest, int(roll.value))
	check(biggest > 6, "an exploding die can pass its own top")
	## A face has no ceiling: one worked past a hundred counts for all of it.
	var tall: Dictionary = die("D6", [150, 150, 150, 150, 150, 150], "tall")
	check(int(DeepDice.roll_one(tall, rng).value) == 150 and DeepDice.top(tall) == 150, "a face past a hundred counts for all of it")
	var climbing: Dictionary = die("D6", [DeepDice.face(100, "tally"), DeepDice.face(100, "tally"), DeepDice.face(100, "tally"), DeepDice.face(100, "tally"), DeepDice.face(100, "tally"), DeepDice.face(100, "tally")], "climb")
	check(int(DeepDice.roll_one(climbing, rng).value) == 101, "a Tally face climbs past a hundred")
	var locked: Dictionary = die("D6", [DeepDice.face(6, "locked"), 1, 1, 1, 1, 1], "l")
	var lock_hand: Array = [DeepDice.roll_one(locked, rng)]
	for _i in range(40):
		lock_hand = DeepDice.reroll(lock_hand, [locked], ["l"], rng)
		if bool(lock_hand[0].locked):
			break
	check(bool(lock_hand[0].locked) and int(lock_hand[0].value) == 6, "a locked face eventually shows and then locks")
	var after: Array = DeepDice.reroll(lock_hand, [locked], ["l"], rng)
	check(int(after[0].value) == 6 and bool(after[0].held), "a locked die refuses to reroll")
	## A Tally face climbs as it is landed on, and takes the die's top up with it.
	var tally: Dictionary = die("D6", [DeepDice.face(6, "tally")], "t")
	var climbed: Dictionary = DeepDice.roll_one(tally, rng)
	check(int(climbed.value) == 7 and bool(climbed.climbed) and int(tally.faces[0].value) == 7, "a Tally face climbs as it lands")
	check(int(DeepDice.roll_one(tally, rng).value) == 8 and int(DeepDice.top(tally)) == 8, "and again, for good")
	## A Sticky face is not thrown with the rest of the bowl next turn.
	var sticky: Dictionary = die("D6", [DeepDice.face(4, "sticky")], "s")
	var plain: Dictionary = d6("p")
	var was: Array = DeepDice.roll_hand([sticky, plain], rng)
	var now: Array = DeepDice.roll_hand([sticky, plain], rng, was)
	check(int(now[0].value) == 4 and bool(now[0].held) and bool(now[0].carried), "a Sticky face carries into the next turn, held")
	check(DeepDice.held_for_patterns(now[0]), "and a carried face counts as held")

func _test_analysis() -> void:
	var a: Dictionary = DeepHand.analyze(hand([3, 3, 5, 5, 5]))
	check(a.best_set.value == 5 and a.best_set.count == 3, "the largest set leads: %s" % str(a.best_set))
	check(a.pairs.size() == 2, "two groups of two or more")
	check(a.total == 21 and a.max_total == 30, "total and maximum total")
	check(a.high == 5 and a.low == 3, "high and low")
	check(a.odd == 5 and a.even == 0 and a.distinct == 2, "parity and distinct counts")
	var run: Dictionary = DeepHand.analyze(hand([2, 3, 4, 6, 6])).straight
	check(run.length == 3 and run.high == 4 and run.low == 2, "a straight of 3 from 2-3-4: %s" % str(run))
	var run5: Dictionary = DeepHand.analyze(hand([5, 1, 4, 2, 3])).straight
	check(run5.length == 5 and run5.high == 5, "a straight of 5 in any order")
	var read_high: Dictionary = DeepHand.read(DeepHand.analyze(hand([1, 6, 4, 2, 5])), 2, true)
	check(read_high.sum == 11 and read_high.dice.size() == 2, "reading the two highest dice sums 6 and 5")
	var read_low: Dictionary = DeepHand.read(DeepHand.analyze(hand([1, 6, 4, 2, 5])), 3, false)
	check(read_low.sum == 7, "reading the three lowest dice sums 1, 2 and 4")
	var twin_hand: Array = hand([4, 4, 2, 1, 6])
	twin_hand[0].kind = "twin"
	var twin: Dictionary = DeepHand.analyze(twin_hand)
	check(twin.best_set.value == 4 and twin.best_set.count == 3, "a Twin face counts twice in its set: %s" % str(twin.best_set))
	check(twin.distinct == 4, "a twin die is still one value for distinct")
	var pct: Dictionary = DeepHand.analyze(hand([6, 6, 6, 6, 6]))
	check(pct.total == 30 and pct.high_pct == 100, "a perfect hand is 100 percent")

func _test_wilds_and_faces() -> void:
	var w: Dictionary = DeepHand.analyze(hand([2, 2, 5, "wild", 1]))
	check(w.best_set.value == 2 and w.best_set.count == 3, "a wild joins the largest set: %s" % str(w.best_set))
	check(w.total == 2 + 2 + 5 + 6 + 1, "a wild counts as its top for totals")
	check(w.odd == 3 and w.even == 3, "a wild is both odd and even")
	var s: Dictionary = DeepHand.analyze(hand([2, 3, 5, 6, "wild"])).straight
	check(s.length == 5 and s.high == 6, "a wild fills the gap in a straight: %s" % str(s))
	var tie: Dictionary = DeepHand.analyze(hand([1, 1, 6, 6, "wild"]))
	check(tie.best_set.value == 6 and tie.best_set.count == 3, "a wild breaks a tie toward the higher value")
	var only: Dictionary = DeepHand.analyze(hand(["wild", "wild"]))
	check(only.best_set.count == 2 and only.best_set.value == 6, "wilds alone make a set of their top")
	var blank: Dictionary = DeepHand.analyze(hand([4, "blank", 4]))
	check(blank.values.size() == 2 and blank.total == 8 and blank.best_set.count == 2, "a blank is not there")

func _test_cut_patterns() -> void:
	## What a pattern does to the numbers, and what it refuses to be cut into.
	var values: Callable = func(shape: String, pattern: String) -> Array:
		return DeepDice.pattern_faces(shape, pattern).map(func(f: Dictionary) -> int: return int(f.value))
	check(values.call("D6", "") == [1, 2, 3, 4, 5, 6], "no pattern is the plain numbers of the size")
	check(values.call("D6", "even") == [2, 2, 4, 4, 6, 6], "Even: each even number twice")
	check(values.call("D6", "odd") == [1, 1, 3, 3, 5, 5], "Odd: each odd number twice")
	check(values.call("D6", "split") == [1, 1, 2, 5, 6, 6], "Split on a d6 drops the middle two")
	check(values.call("D12", "split") == [1, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 12], "Split on a d12 drops 6 and 7")
	var split20: Array = values.call("D20", "split")
	check(split20.count(1) == 3 and split20.count(20) == 3 and split20.size() == 20 and not split20.has(10), "Split on a d20 doubles twice: three 1s, three 20s")
	var split40: Array = values.call("D40", "split")
	check(split40.count(1) == 4 and split40.count(40) == 4 and split40.size() == 40, "and three times from a d40")
	check(values.call("D8", "gamblers") == [1, 2, 3, 4, 5, 7, 7, 7], "Gambler's turns every 6 and 8 into a 7")
	check(values.call("D6", "stretched") == [2, 4, 6, 8, 10, 12], "Stretched doubles every face")
	check(values.call("D6", "shallow") == [1, 1, 2, 2, 3, 3], "Shallow squeezes the numbers into the bottom half")
	var paired: Array = values.call("D12", "paired")
	var seen: Dictionary = {}
	for value in paired:
		seen[value] = int(seen.get(value, 0)) + 1
	check(paired.size() == 12 and seen.size() == 6 and seen.values().all(func(n: int) -> bool: return n == 2), "Paired shows half as many numbers, each of them twice")
	var shallow: Dictionary = DeepDice.make("D6", "phial", {"pattern": "shallow"})
	check(int(DeepDice.top(shallow)) == 6, "a Shallow die is still judged against the size it is")
	check(DeepHand.analyze([DeepDice.roll_one(shallow, RandomNumberGenerator.new())]).low_dice == 1, "so every face of it is a low die")
	check(not DeepDice.pattern_allows("split", "D4") and DeepDice.pattern_allows("even", "D4"), "Split wants a d6, Even does not")
	check(not DeepDice.pattern_allows("gamblers", "D20") and DeepDice.pattern_allows("gamblers", "D12"), "Gambler's stops at a d12")
	check(DeepDice.pattern_allows("stretched", "D60") and DeepDice.top(DeepDice.make("D100", "s", {"pattern": "stretched"})) == 200, "with no ceiling on a face, Stretched reaches every size: a d100 reads 200")
	check(str(DeepDice.make("D20", "no", {"pattern": "gamblers"}).pattern).is_empty(), "a die refuses a pattern it cannot take")

func _test_materials() -> void:
	## Materials, what they are worth to a gem, and which die a gem reaches for.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var red: Array = ["RED"]
	check(is_equal_approx(DeepDice.strength([{"material": "ruby"}], red), 1.5), "one Ruby is half again as strong on a red gem")
	check(is_equal_approx(DeepDice.strength([{"material": "ruby"}, {"material": "ruby"}], red), 2.25), "and two multiply")
	check(is_equal_approx(DeepDice.strength([{"material": "ruby"}], ["BLUE"]), 1.0), "a Ruby is nothing to a blue gem")
	check(is_equal_approx(DeepDice.strength([{"material": "opal"}, {"material": "glass"}], ["GREEN"]), 2.25), "Opal and Glass answer to every colour")
	check(is_equal_approx(DeepDice.strength([{"material": "iron"}], red), 1.0), "Iron is not a colour")
	var plain_roll: Dictionary = {"die_id": "p", "kind": "plain", "material": ""}
	var ruby_roll: Dictionary = {"die_id": "r", "kind": "plain", "material": "ruby"}
	var shiny_roll: Dictionary = {"die_id": "s", "kind": "shiny", "material": ""}
	var iron_roll: Dictionary = {"die_id": "i", "kind": "plain", "material": "iron"}
	check(DeepDice.preference(ruby_roll, red) > DeepDice.preference(shiny_roll, red), "a gem reaches for its own colour first")
	check(DeepDice.preference(shiny_roll, red) > DeepDice.preference(iron_roll, red), "then for an etching worth having")
	check(DeepDice.preference(iron_roll, red) > DeepDice.preference(plain_roll, red), "then for any material at all")
	## Three sixes and a Shiny six: the set names the Shiny one first.
	var three: Array = hand([6, 6, 6])
	three[2].kind = "shiny"
	var picked: Dictionary = DeepPatterns.evaluate({"kind": "triple", "ladder": [1, 1, 1, 1, 1]}, 0, DeepHand.analyze(three, red))
	check(str(picked.dice[0]) == "d2", "the dice a gem fires on are the ones it wants: %s" % str(picked.dice))
	check(DeepDice.shiny_count([shiny_roll, plain_roll]) == 1, "a Shiny face is counted for the Resonance it rings")
	## What a throw owes the table.
	var dues: Dictionary = DeepDice.throw_dues([{"die_id": "c", "kind": "plain", "material": "crystal", "rerolls": 0},
		{"die_id": "g", "kind": "plain", "material": "fools_gold", "rerolls": 0},
		{"die_id": "f", "kind": "golden", "material": "", "rerolls": 0},
		{"die_id": "b", "kind": "plain", "material": "blood", "rerolls": 1}])
	check(int(dues.resonance) == DeepDice.CRYSTAL_RESONANCE, "Crystal rings once a throw")
	check(int(dues.pyrite) == DeepDice.FOOLS_GOLD_PYRITE + DeepDice.GOLDEN_FACE_PYRITE, "Fool's Gold and a Golden face both pay")
	check(int(dues.hp) == DeepDice.BLOOD_HP, "Blood takes its price for being thrown again")
	var opening: Dictionary = DeepDice.throw_dues([{"die_id": "b", "kind": "plain", "material": "blood", "rerolls": 0}])
	check(int(opening.hp) == 0, "but never on the opening roll")
	## Glass breaks, and says so on the roll that broke it.
	var glass: Dictionary = d6("glass", {"material": "glass"})
	var broke: int = 0
	for _i in range(2000):
		if bool(DeepDice.roll_one(glass, rng).shattered):
			broke += 1
	check(broke > 120 and broke < 280, "Glass breaks about one throw in ten: %d in 2000" % broke)
	## Iron is thrown twice and keeps the higher face, Cloud the lower: on a d6 they average
	## 161/36 (4.47) and 91/36 (2.53), against 3.5 for a plain one.
	var sums: Dictionary = {"": 0, "iron": 0, "cloud": 0}
	for material in sums:
		var thrown: Dictionary = d6("t_" + material, {"material": material})
		for _i in range(6000):
			sums[material] += int(DeepDice.roll_one(thrown, rng).value)
	check(absf(float(sums["iron"]) / 6000.0 - 4.47) < 0.1, "an Iron d6 averages about 4.47: %.2f" % (float(sums["iron"]) / 6000.0))
	check(absf(float(sums["cloud"]) / 6000.0 - 2.53) < 0.1, "a Cloud d6 averages about 2.53: %.2f" % (float(sums["cloud"]) / 6000.0))
	check(absf(float(sums[""]) / 6000.0 - 3.5) < 0.1, "and a plain one about 3.5")
	check(DeepDice.describe(DeepDice.make("D12", "x", {"material": "ruby", "pattern": "split"})) == "Ruby Split d12", "a die says what it is")

func _test_patterns() -> void:
	var a: Dictionary = DeepHand.analyze(hand([3, 3, 5, 5, 5]))
	check(DeepPatterns.evaluate({"kind": "pair", "ladder": [5, 4, 3, 2, 1]}, 0, a).active, "a pair of fives satisfies a Poor pair trigger")
	check(not DeepPatterns.evaluate({"kind": "pair", "ladder": [6, 6, 6, 6, 6]}, 4, a).active, "a pair of fives fails a pair-of-sixes rung")
	var pair: Dictionary = DeepPatterns.evaluate({"kind": "pair", "ladder": [1, 1, 1, 1, 1]}, 0, a)
	check(pair.value == 5 and pair.dice.size() == 3, "the pair trigger reads the best set, which may be larger")
	check(DeepPatterns.evaluate({"kind": "triple", "ladder": [1, 1, 1, 1, 1]}, 0, a).active, "a triple")
	check(not DeepPatterns.evaluate({"kind": "quad", "ladder": [1, 1, 1, 1, 1]}, 0, a).active, "no quad")
	var fh: Dictionary = DeepPatterns.evaluate({"kind": "full_house", "ladder": [1, 1, 1, 1, 1]}, 0, a)
	check(fh.active and fh.value == 5 and fh.second == 3 and fh.dice.size() == 5, "a full house names both values")
	var tp: Dictionary = DeepPatterns.evaluate({"kind": "two_pair", "ladder": [1, 1, 1, 1, 1]}, 0, a)
	check(tp.active and tp.value == 5 and tp.second == 3, "two pairs from a full house")
	var run: Dictionary = DeepHand.analyze(hand([2, 3, 4, 6, 6]))
	check(DeepPatterns.evaluate({"kind": "straight", "ladder": [5, 5, 4, 4, 3]}, 4, run).active, "a Perfect straight trigger takes a run of three")
	check(not DeepPatterns.evaluate({"kind": "straight", "ladder": [5, 5, 4, 4, 3]}, 2, run).active, "a Good straight trigger wants four")
	check(DeepPatterns.evaluate({"kind": "odd", "ladder": [5, 4, 4, 3, 3]}, 4, a).active, "five odd dice")
	check(not DeepPatterns.evaluate({"kind": "even", "ladder": [5, 4, 4, 3, 3]}, 4, a).active, "no even dice")
	var distinct: Dictionary = DeepHand.analyze(hand([1, 2, 3, 5, 6]))
	check(DeepPatterns.evaluate({"kind": "distinct", "ladder": [5, 5, 4, 4, 3]}, 0, distinct).active, "five distinct")
	check(DeepPatterns.evaluate({"kind": "value", "values": [7], "ladder": [1, 1, 1, 1, 1]}, 0, DeepHand.analyze(hand([7, 1, 1, 1, 1], 8))).active, "a seven")
	## "Showing 1" reads the face a die landed on: a Doubled 1 counts for 2 but shows a 1. A
	## gem that has since changed the roll changes what it shows.
	var ones: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var doubled: Dictionary = DeepDice.make("D6", "dbl", {"faces": [DeepDice.face(1, "doubled")], "top": 6})
	var doubled_too: Dictionary = DeepDice.make("D6", "dbl2", {"faces": [DeepDice.face(1, "doubled")], "top": 6})
	ones.append(DeepDice.roll_one(doubled_too, rng))
	ones.append(DeepDice.roll_one(doubled, rng))
	for index in range(3):
		ones.append(DeepDice.roll_one(DeepDice.make("D6", "p%d" % index, {"faces": [DeepDice.face(1)], "top": 6}), rng))
	check(int(ones[0].value) == 2 and int(ones[1].value) == 2, "two Doubled faces both land on a 1 and count for 2")
	var five_ones: Dictionary = {"kind": "value", "values": [1], "amount": 5}
	check(DeepPatterns.evaluate(five_ones, 0, DeepHand.analyze(ones)).active, "and both are still showing a 1")
	check(int(DeepHand.analyze(ones).total) == 7, "while every sum counts what they are worth")
	ones[0].value = 3
	check(not DeepPatterns.evaluate(five_ones, 0, DeepHand.analyze(ones)).active, "a die a gem has raised shows what it was raised to")
	check(DeepPatterns.evaluate({"kind": "at_most", "ladder": [1, 1, 2, 2, 3]}, 0, distinct).active, "a one for Ember")
	check(not DeepPatterns.evaluate({"kind": "at_most", "ladder": [1, 1, 2, 2, 3]}, 0, DeepHand.analyze(hand([4, 4, 4, 4, 4]))).active, "no low dice")
	check(DeepPatterns.evaluate({"kind": "at_least", "ladder": [6, 6, 6, 5, 5]}, 0, a).active == false, "highest die 5 fails at least 6")
	check(DeepPatterns.evaluate({"kind": "total_pct_at_least", "ladder": [90, 85, 80, 75, 70]}, 4, a).active, "21 of 30 is 70 percent")
	check(not DeepPatterns.evaluate({"kind": "total_pct_at_least", "ladder": [90, 85, 80, 75, 70]}, 3, a).active, "21 of 30 is not 75 percent")
	check(DeepPatterns.evaluate({"kind": "total_pct_at_most", "ladder": [40, 45, 50, 55, 60]}, 0, DeepHand.analyze(hand([1, 1, 2, 3, 5]))).active, "12 of 30 is a low total")
	check(DeepPatterns.evaluate({"kind": "high_pct_at_least", "ladder": [95, 90, 85, 80, 70]}, 0, DeepHand.analyze(hand([6, 1, 1, 1, 1]))).active, "a six on a d6 is 100 percent")
	var held_hand: Array = hand([1, 2, 3, 4, 5])
	held_hand[0].held = true
	held_hand[1].held = true
	held_hand[2].rerolls = 1
	var held: Dictionary = DeepHand.analyze(held_hand)
	check(DeepPatterns.evaluate({"kind": "held", "ladder": [5, 4, 4, 3, 2]}, 4, held).active, "two held dice")
	check(DeepPatterns.evaluate({"kind": "rerolled", "ladder": [4, 3, 3, 2, 1]}, 4, held).active, "one rerolled die")
	check(DeepPatterns.evaluate({"kind": "resonance", "ladder": [5, 4, 4, 3, 3]}, 4, a, {"resonance": 3}).active, "resonance three")
	var always: Dictionary = DeepPatterns.evaluate({"kind": "always", "ladder": [1, 1, 2, 2, 3], "read": "high"}, 4, a)
	check(always.active and always.value == 15 and always.count == 3, "Strike at Perfect reads the three highest: %s" % str(always))
	var low: Dictionary = DeepPatterns.evaluate({"kind": "always", "ladder": [1, 1, 2, 2, 3], "read": "low"}, 0, a)
	check(low.value == 3, "Mend at Poor reads the lowest die")

func _test_ladders_and_words() -> void:
	var trigger: Dictionary = {"kind": "straight", "ladder": [5, 5, 4, 4, 3]}
	check(DeepPatterns.rung(trigger, 0) == 5 and DeepPatterns.rung(trigger, 4) == 3 and DeepPatterns.rung(trigger, 9) == 3, "rungs clamp to the ladder")
	var described: Dictionary = DeepPatterns.describe(trigger, 4)
	check(described.mark == "straight" and described.label == "×3", "a described straight: %s" % str(described))
	check(DeepPatterns.describe({"kind": "total_pct_at_most", "ladder": [40, 45, 50, 55, 60]}, 0).label == "≤40%", "percent labels")
	check(DeepPatterns.describe({"kind": "always", "ladder": [1, 1, 2, 2, 3]}, 4).mark == "read_high", "an always trigger shows what it reads")
	check(DeepPatterns.words({"kind": "pair", "ladder": [5, 4, 3, 2, 1]}, 0).contains("5s or higher"), "words name the rung")
	check(DeepPatterns.validate({"kind": "pair", "ladder": [5, 4, 3, 2, 1]}).is_empty(), "a good trigger validates")
	check(not DeepPatterns.validate({"kind": "pair", "ladder": [5, 4]}).is_empty(), "a short ladder is refused")
	check(not DeepPatterns.validate({"kind": "nonsense"}).is_empty(), "an unknown kind is refused")
	check(not DeepPatterns.validate({"kind": "value", "ladder": [1, 1, 1, 1, 1]}).is_empty(), "a value trigger needs values")
