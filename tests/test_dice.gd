extends SceneTree
## Dice, hands and patterns: the foundation every gem stands on.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_rolls()
	_test_analysis()
	_test_wilds_and_faces()
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

func die(key: String, faces: Array, id: String, engraving: String = "") -> Dictionary:
	return DeepDice.make(key, {"shape": key, "faces": faces}, id, engraving)

func d6(id: String, engraving: String = "") -> Dictionary:
	return die("D6", [1, 2, 3, 4, 5, 6], id, engraving)

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
		out.append({"die_id": "d%d" % index, "key": "D6", "shape": "D6", "value": value, "face": 0, "kind": kind,
			"top": tops, "held": false, "rerolls": 0, "locked": false, "explosions": 0, "engraving": "", "phantom": false})
	return out

func _test_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dice: Array = [d6("a"), d6("b"), die("D20", range(1, 21), "c"), d6("k", "keen"), d6("s", "steady")]
	for _i in range(200):
		var rolled: Array = DeepDice.roll_hand(dice, rng)
		check(rolled.size() == 5, "five dice roll five results")
		check(rolled[0].value >= 1 and rolled[0].value <= 6, "a d6 shows 1 to 6")
		check(rolled[2].value >= 1 and rolled[2].value <= 20, "a d20 shows 1 to 20")
		check(rolled[3].value >= 2 and rolled[3].value <= 7, "a keen d6 shows 2 to 7")
		check(rolled[4].value >= 2, "a steady d6 never shows a 1")
		check(int(rolled[2].top) == 20 and int(rolled[3].top) == 7, "top reads the die's best face, keen included")
	var first: Array = DeepDice.roll_hand(dice, rng)
	var again: Array = DeepDice.reroll(first, dice, ["a", "c"], rng)
	check(again[1].held and again[3].held and not again[0].held and not again[2].held, "unselected dice are held, selected dice are not")
	check(int(again[0].rerolls) == 1 and int(again[1].rerolls) == 0, "rerolled dice count their rerolls")
	var exploding: Dictionary = die("D6", [1, 2, 3, 4, 5, {"value": 6, "kind": "exploding"}], "x")
	var biggest: int = 0
	for _i in range(400):
		var roll: Dictionary = DeepDice.roll_one(exploding, rng)
		biggest = maxi(biggest, int(roll.value))
		check(int(roll.value) <= DeepDice.VALUE_CAP, "an exploding die is capped")
	check(biggest > 6, "an exploding die can pass its own top")
	var locked: Dictionary = die("D6", [{"value": 6, "kind": "locked"}, 1, 1, 1, 1, 1], "l")
	var lock_hand: Array = [DeepDice.roll_one(locked, rng)]
	for _i in range(40):
		lock_hand = DeepDice.reroll(lock_hand, [locked], ["l"], rng)
		if bool(lock_hand[0].locked):
			break
	check(bool(lock_hand[0].locked) and int(lock_hand[0].value) == 6, "a locked face eventually shows and then locks")
	var after: Array = DeepDice.reroll(lock_hand, [locked], ["l"], rng)
	check(int(after[0].value) == 6 and bool(after[0].held), "a locked die refuses to reroll")
	var mirror: Dictionary = die("D6", [{"value": 0, "kind": "mirror"}], "m")
	var mirrored: Array = DeepDice.roll_hand([die("D6", [4], "four"), mirror], rng)
	check(int(mirrored[1].value) == 4, "a mirror face copies the highest other die")

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
	twin_hand[0].engraving = "twin"
	var twin: Dictionary = DeepHand.analyze(twin_hand)
	check(twin.best_set.value == 4 and twin.best_set.count == 3, "a twin die counts twice in its set: %s" % str(twin.best_set))
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
	var gem: Dictionary = DeepHand.analyze(hand([1, 2, "gem", 4, 6]))
	check(gem.gem_face, "a gem face is noticed")
	var fired: Dictionary = DeepPatterns.evaluate({"kind": "quint", "ladder": [1, 1, 1, 1, 1]}, 0, gem)
	check(fired.active and fired.get("gem_face", false), "a gem face fires a trigger the hand could never meet")

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
