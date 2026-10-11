extends SceneTree
## Content, rules, stones and the forge.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_pack()
	_test_evaluation()
	_test_inclusions()
	_test_grade_and_names()
	_test_birthstones_and_references()
	_test_forge()
	_test_oddities()
	print("Stones/rules/forge: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func hand(numbers: Array, tops: int = 6) -> Array:
	var out: Array = []
	for index in range(numbers.size()):
		out.append({"die_id": "d%d" % index, "key": "D6", "shape": "D6", "value": int(numbers[index]), "face": 0, "kind": "plain",
			"top": tops, "held": false, "rerolls": 0, "locked": false, "explosions": 0, "engraving": "", "phantom": false})
	return out

func stone(skill: String, carat: int = 1, cut: int = 0, clarity: int = 3, inclusions: Array = []) -> Dictionary:
	return DeepStone.make(skill, carat, cut, clarity, inclusions, {}, skill.to_lower())

func read(made: Dictionary) -> Dictionary:
	## The same stone, already under the loupe: what a wheel or an oven will work on.
	made.appraised = true
	made.inclusions_revealed = true
	return made

func amount_of(evaluation: Dictionary, kind: String, index: int = 0) -> int:
	var seen: int = 0
	for effect in evaluation.get("effects", []):
		if str(effect.kind) == kind:
			if seen == index:
				return int(effect.amount)
			seen += 1
	return -1

func _test_pack() -> void:
	var errors: Array = DeepContent.validate()
	check(errors.is_empty(), "the shipped pack validates: " + str(errors))
	check(DeepContent.skill("STRIKE").name == "Strike", "skills load")
	check(DeepContent.clear_index() == 3, "Clear is the middle of the clarity ladder")
	check(DeepContent.clarity_name(5) == "Flawless" and DeepContent.clarity_name(0) == "Intricate", "clarity names")
	check(DeepContent.cut_name(4) == "Perfect", "cut names")
	check(DeepContent.starter_mine() == "QUARRY" and DeepContent.starter_character() == "ARDOR", "starters")
	check(DeepContent.characters_in_unlock_order() == ["ARDOR", "VESPER", "CADENCE", "RUE", "PUCK", "FLORIN"], "characters unlock in the pack's order: %s" % str(DeepContent.characters_in_unlock_order()))
	check(DeepContent.character_title("VESPER") == "Vesper, the Rogue", "a character is named with their title")
	for key in DeepContent.section("characters"):
		check(DeepContent.character(str(key)).sockets.has("RED"), "%s has a Red socket" % str(key))
	var birth: Dictionary = DeepStone.birthstone("FLORIN")
	check(DeepStone.is_birthstone(birth) and DeepStone.name(birth) == "High Roller" and birth.tiers.size() == 4, "a Birthstone is a stone the views can draw and name")
	check(DeepContent.validate_birthstone({"name": "x", "style": "orb", "hue": "ffffff", "tiers": []}).size() == 2, "an unknown style and an empty ladder are both errors")
	var broken: Dictionary = DeepContent.pack().duplicate(true)
	broken.skills.BAD = {"name": "Bad", "color": "PINK", "rarity": "COMMON", "trigger": {"kind": "pair", "ladder": [1, 2]}, "effects": [ {"kind": "explode"}]}
	check(DeepContent.validate(broken).size() >= 3, "a bad skill is refused for each thing wrong with it")

func _test_evaluation() -> void:
	var a: Array = hand([3, 3, 5, 5, 5])
	var strike_poor: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0), a)
	check(strike_poor.active and amount_of(strike_poor, "damage") == 3, "Poor Strike squints at the lowest die: 3 × 1 = 3 (%d)" % amount_of(strike_poor, "damage"))
	var strike_steps: Array = []
	for step in range(5):
		strike_steps.append(amount_of(DeepStone.evaluate(stone("STRIKE", 1, step), a), "damage"))
	check(strike_steps == [3, 6, 10, 15, 18], "every Cut step reads a different hand: %s" % str(strike_steps))
	var strike_perfect: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 4), a)
	check(amount_of(strike_perfect, "damage") == 18, "Perfect Strike reads four dice: 5 + 5 + 5 + 3 = 18 (%d)" % amount_of(strike_perfect, "damage"))
	var strike_big: Dictionary = DeepStone.evaluate(stone("STRIKE", 12, 0), a)
	check(amount_of(strike_big, "damage") == 11, "Carat 12 is ×3.75: 3 × 3.75 = 11.25, floored to 11 (%d)" % amount_of(strike_big, "damage"))
	var cleave_poor: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 0), hand([2, 2, 4, 5, 6]))
	check(not cleave_poor.active, "Poor Cleave wants a pair of fives")
	var cleave_perfect: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 4), hand([2, 2, 4, 5, 6]))
	check(cleave_perfect.active and amount_of(cleave_perfect, "damage") == 4 and int(cleave_perfect.effects[0].splash) == 50, "Perfect Cleave takes any pair: 4 × 1 = 4 with half splash")
	var cleave_flawless: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 1, 5), hand([4, 4, 2, 5, 6]))
	check(cleave_flawless.active, "a Fair Flawless Cleave takes a pair of fours")
	check(int(cleave_flawless.effects[0].splash) == 100, "the Flawless line changes the splash")
	check(amount_of(cleave_flawless, "damage") == int(floor(8 * 1.0 * 1.5)), "Flawless multiplies magnitude by 1.5 (%d)" % amount_of(cleave_flawless, "damage"))
	check(cleave_flawless.resonance_gain == 3 and DeepStone.evaluate(stone("CLEAVE", 1, 1, 4), hand([4, 4, 2, 5, 6])).resonance_gain == 2,
		"Pristine rings twice and Flawless three times (%d)" % int(cleave_flawless.resonance_gain))
	check(not DeepStone.evaluate(stone("CLEAVE", 1, 0, 5), hand([4, 4, 2, 5, 6])).active, "clarity no longer loosens the rung: a Poor Flawless Cleave still wants fives")
	var barrage: Dictionary = DeepStone.evaluate(stone("BARRAGE", 1, 4), hand([1, 2, 3, 6, 6]))
	check(barrage.active and barrage.effects[0].repeat == 3 and amount_of(barrage, "damage") == 6, "Barrage repeats once per die in the run, for 6 at Perfect")
	var barrage_flawless: Dictionary = DeepStone.evaluate(stone("BARRAGE", 1, 4, 5), hand([1, 2, 3, 6, 6]))
	check(str(barrage_flawless.effects[0].target) == "enemy" and int(barrage_flawless.effects[0].repeat) == 4, "Flawless Barrage adds one hit")
	var glimmer: Dictionary = DeepStone.evaluate(stone("GLIMMER", 1, 2), hand([1, 2, 3, 4, 5]))
	check(amount_of(glimmer, "upgrade_faces") == 1 and not bool(glimmer.effects[0].scaled), "Glimmer raises a matched face by one, never by a fraction")
	var heavy_glimmer: Dictionary = DeepStone.evaluate(stone("GLIMMER", 24, 2), hand([1, 2, 3, 4, 5]))
	check(amount_of(heavy_glimmer, "upgrade_faces") == 1 and int(heavy_glimmer.effects[0].procs) == 4, "a 24-carat Glimmer raises it four times over instead")
	var mend: Dictionary = DeepStone.evaluate(stone("MEND", 1, 4), hand([1, 2, 3, 4, 5]))
	check(amount_of(mend, "heal") == 1, "Perfect Mend heals only the lowest die: 1 (%d)" % amount_of(mend, "heal"))
	var spall: Dictionary = DeepStone.evaluate(stone("SPALL", 1, 0), hand([1, 2, 3, 4, 5]))
	check(amount_of(spall, "damage") == 6, "Spall doubles the two lowest: 6 × 1 = 6 (%d)" % amount_of(spall, "damage"))
	var context: Dictionary = {"unit": {"block": 10, "block_lost": 7}}
	check(amount_of(DeepStone.evaluate(stone("RIPOSTE", 1, 2), a, context), "damage") == 7, "a Good Riposte reads all the block lost")
	check(amount_of(DeepStone.evaluate(stone("RIPOSTE", 1, 0), a, context), "damage") == 4, "a Poor Riposte reads 60% of it")
	check(amount_of(DeepStone.evaluate(stone("THRIVE", 1, 2), hand([10, 2, 3, 4, 5], 12), context), "heal") == 5, "a Good Thrive heals half its block")
	var seven: Dictionary = DeepStone.evaluate(stone("LUCKY_SEVEN", 1, 2), hand([7, 7, 1, 2, 3], 8))
	check(seven.active and seven.effects[0].repeat == 2 and amount_of(seven, "gold") == 3, "two sevens: two hits and two payouts")
	var fizzle: Dictionary = DeepStone.evaluate(stone("CRUSH", 1, 0), hand([1, 2, 3, 4, 5]))
	check(not fizzle.active and not fizzle.reason.is_empty(), "a fizzle explains itself: " + fizzle.reason)
	check(DeepStone.total_amount(strike_perfect) == 18 and DeepStone.total_amount(barrage) == 18, "total_amount sums repeats")
	_test_procs()
	_test_cut_steps()

func _test_procs() -> void:
	## Carat on an effect that cannot be a fraction: (multiplier - 1) / 3, the whole part
	## certain and the remainder a chance. The table the design is written from.
	var wanted: Array = [[1, 1, 0], [6, 1, 42], [13, 2, 0], [22, 3, 33], [24, 4, 0]]
	for row in wanted:
		var p: Dictionary = DeepStone.procs(stone("CASCADE", int(row[0])))
		check(int(p.procs) == int(row[1]) and int(p.chance) == int(row[2]),
			"carat %d procs %d with a %d%% chance of one more (got %s)" % [int(row[0]), int(row[1]), int(row[2]), str(p)])
	var cascade: Dictionary = DeepStone.evaluate(stone("CASCADE", 22, 4), hand([4, 4, 2, 5, 6]))
	check(int(cascade.effects[0].amount) == 1 and int(cascade.effects[0].procs) == 3 and int(cascade.effects[0].proc_chance) == 33,
		"a 22-carat Cascade grants one reroll three times over, a third of the way to a fourth (%s)" % str(cascade.effects[0]))
	var strike: Dictionary = DeepStone.evaluate(stone("STRIKE", 22, 4), hand([3, 3, 5, 5, 5]))
	check(int(strike.effects[0].procs) == 1, "a scaled effect swells instead of procing")
	check(DeepStone.proc_lines(stone("CASCADE", 6)).size() == 1 and DeepStone.proc_lines(stone("CASCADE", 1)).is_empty(),
		"a light stone says nothing; a 6-carat one says only what is likely")
	var heavy: Array = DeepStone.proc_lines(stone("CASCADE", 22))
	check(heavy.size() == 2 and str(heavy[0].text) == "Three times over, for its weight." and str(heavy[1].text) == "33% chance of a fourth.",
		"a 22-carat stone says both halves: %s" % str(heavy))
	check(DeepStone.proc_lines(stone("STRIKE", 22)).is_empty(), "a Strike is never told it procs")
	var rider: Dictionary = DeepStone.evaluate(stone("STRIKE", 22, 4, 2, ["PINPOINT_GOLD"]), hand([3, 3, 5, 5, 5]))
	for effect in rider.effects:
		if str(effect.kind) == "gold":
			check(int(effect.procs) == 1, "an inclusion's rider was written flat on purpose and stays flat")

func _test_cut_steps() -> void:
	## Every skill must do something different at each of the five Cut steps: no two rungs
	## of a ladder may leave a stone behaving exactly as it did one step worse.
	var same: Array = []
	for key in DeepContent.section("skills"):
		var seen: Array = []
		## Certainty fires on any hand and does the same at every Cut: its makers' design, made
		## at an altar where a Transcendent's worth lies in what it is rather than how it is cut.
		if str(key) == "CERTAINTY":
			continue
		for step in range(DeepPatterns.STEPS):
			var one: Dictionary = DeepStone.effective(stone(str(key), 1, step))
			var described: Dictionary = DeepPatterns.describe(DeepContent.skill(str(key)).get("trigger", {"kind": "always"}), step)
			var signature: String = "%s|%s|%s" % [str(described.need), str(described.words), DeepStone.text(stone(str(key), 1, step))]
			for effect in DeepContent.skill(str(key)).get("effects", []):
				signature += "|" + str(DeepRules.resolve_effect(effect, {"cut": step}, float(one.magnitude)))
			if seen.has(signature):
				same.append(str(key) + " at " + DeepContent.cut_name(step))
			seen.append(signature)
	check(same.is_empty(), "no skill repeats itself across its Cut ladder: " + str(same))

func _test_inclusions() -> void:
	var a: Array = hand([3, 3, 5, 5, 5])
	var needle: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 4, 2, ["NEEDLE"]), a)
	check(amount_of(needle, "damage") == 18 + 4, "Needle adds one damage for each of the four dice a Perfect Strike reads (%d)" % amount_of(needle, "damage"))
	var fracture_hit: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["FRACTURE"]), a)
	check(amount_of(fracture_hit, "damage") == 6, "Fracture doubles: 3 × 1 × 2 = 6 (%d)" % amount_of(fracture_hit, "damage"))
	var fracture_miss: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["FRACTURE"]), hand([1, 3, 5, 5, 5]))
	check(not fracture_miss.active and fracture_miss.reason.begins_with("Fracture"), "Fracture fizzles on a 1: " + fracture_miss.reason)
	var chip: Dictionary = DeepStone.effective(stone("STRIKE", 2, 1, 2, ["CHIP"]))
	check(chip.carat == 5 and chip.cut_step == 0, "Chip: +3 carats, one Cut step worse")
	var cavity: Dictionary = DeepStone.effective(stone("STRIKE", 4, 4, 2, ["CAVITY"]))
	check(cavity.cut_step == 0 and is_equal_approx(cavity.magnitude, 2.75), "Cavity: carats count double, cut is Poor (%s)" % str(cavity))
	var star: Dictionary = DeepStone.evaluate(stone("CRUSH", 1, 0, 2, ["STAR"]), hand([1, 2, 3, 4, 5]))
	check(star.active and bool(star.trigger.get("forced", false)), "a Star fires on any hand")
	var chatoyance: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["CHATOYANCE"]), a)
	check(chatoyance.fires == 2, "Chatoyance fires twice")
	check(DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["CHATOYANCE"]), a, {"retrigger": true}).fires == 1, "a retrigger does not retrigger again")
	var wisp_cold: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["TWINNING_WISP"]), a, {"previous_fired": false})
	var wisp_warm: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["TWINNING_WISP"]), a, {"previous_fired": true})
	check(wisp_cold.fires == 1 and wisp_warm.fires == 2, "Twinning Wisp fires again after a fire")
	var veil: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 0, 2, ["VEIL"]), hand([1, 6, 2, 3, 4]))
	check(veil.active and veil.trigger.value == 6, "Veil reads the lowest die as the highest, making a pair of sixes")
	var cats_eye: Dictionary = DeepStone.evaluate(stone("CRUSH", 1, 4, 2, ["CATS_EYE"]), hand([1, 1, 5, 2, 3]))
	check(cats_eye.active and cats_eye.trigger.value == 5, "Cat's Eye makes ones wild: a triple of fives (%s)" % str(cats_eye.trigger))
	var bruise: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["BRUISE"]), a)
	check(bruise.hp_cost == 2 and amount_of(bruise, "damage") == 4, "Bruise costs 2 HP and adds half again: 3 × 1.5 = 4 (%d)" % amount_of(bruise, "damage"))
	var rider: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["PINPOINT_GOLD", "SPARK"]), a)
	check(amount_of(rider, "gold") == 2 and rider.resonance_gain == 2, "a Pinpoint rides along and a Spark adds Resonance")
	check(DeepStone.colors(stone("STRIKE", 1, 0, 2, ["ZONING_BLUE"])) == ["RED", "BLUE"], "color Zoning adds a color")
	check(DeepStone.colors(stone("STRIKE", 1, 0, 2, ["ALEXANDRITE"]), "GREEN") == ["RED", "GREEN"], "Alexandrite takes the socket's color")
	check(DeepStone.fits(stone("STRIKE"), "RED") and not DeepStone.fits(stone("STRIKE"), "BLUE") and DeepStone.fits(stone("STRIKE"), "ANY"), "sockets take their color or anything")
	check(DeepStone.is_locked(stone("STRIKE", 1, 0, 2, ["KNOT"])), "a Knot is locked in")
	var flu: Dictionary = DeepStone.effective(stone("STRIKE", 1, 0, 2, ["FLUORESCENCE"]), {"depth": 14})
	check(flu.carat == 5, "Fluorescence adds a carat per depth below 10")
	var feather: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["FEATHER"]), a)
	check(feather.next_cut_step == 1, "a Feather passes a Cut step forward")
	var bonus: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 0), hand([4, 4, 1, 2, 3]), {"cut_step_bonus": 1})
	check(bonus.active, "a passed Cut step loosens the rung")

func _test_birthstones_and_references() -> void:
	## A Birthstone is nobody's find: it wears the heaviest rank there is, and its weight
	## buys it nothing in a fight, which is why it is safe to hand every one of them the
	## same. A reference is the opposite: a skill at its very plainest, for the vault page of
	## a gem the player has seen and does not own.
	for key in DeepContent.section("characters"):
		var born: Dictionary = DeepStone.birthstone(str(key))
		if born.is_empty():
			continue
		check(int(born.carat) == DeepStone.carat_max(), "%s's Birthstone is the heaviest a stone can be (%d ct)" % [str(key), int(born.carat)])
		check(DeepStone.is_birthstone(born) and DeepStone.proc_lines(born).is_empty(), "and its weight is never read out as procs")
	var page: Dictionary = DeepStone.reference_stone("CASCADE")
	check(bool(page.appraised) and int(page.carat) == 1 and int(page.cut) == 0, "a reference is read, one carat and the poorest cut")
	check(is_equal_approx(float(DeepStone.effective(page).magnitude), 1.0), "so every number on its page is the one the pack wrote")
	## Only a skill with something scaled by weight has a multiplier worth printing.
	check(DeepStone.magnitude_matters(DeepStone.make("STRIKE", 9, 2, 3, [], {}, "m1")), "Strike swells with weight")
	check(not DeepStone.magnitude_matters(DeepStone.make("CASCADE", 9, 2, 3, [], {}, "m2")), "Cascade cannot, and takes procs instead")
	check(DeepStone.procs_matter(DeepStone.make("CASCADE", 9, 2, 3, [], {}, "m3")) and not DeepStone.procs_matter(DeepStone.make("STRIKE", 9, 2, 3, [], {}, "m4")),
		"and the two are the other way round for procs")
	## Nothing a gem does is deaf to its weight: every effect, Flawless lines included, swells
	## with the multiplier or procs more often. The exceptions read a result that already
	## swelled (a from_result rider, or an of_status share of what the gem just gave), so
	## weighing it again would square the carat curve, or are a cost the gem makes its own
	## owner pay (Hemlock's Poison), which is a price and stays exact. A priced effect never
	## procs (it would pay again), so it has to take the multiplier.
	for key in DeepContent.section("skills"):
		var skill: Dictionary = DeepContent.skill(str(key))
		var defs: Array = skill.get("effects", []).duplicate(true)
		if skill.get("flawless", null) is Dictionary:
			defs = DeepStone.apply_flawless(defs, skill.flawless)
		for def in defs:
			var kind: String = str(def.get("kind", "damage"))
			var scale: String = str(def.get("scale", "carat" if kind in DeepRules.SCALED_BY_DEFAULT else "procs"))
			## A Transcendent counts exactly what it was designed to: one fire for every pair, five
			## carats, every gem after it. Its weight swells everything else it does.
			var exact: bool = DeepContent.is_transcendent(str(key)) and kind in ["fire_neighbours", "force_after", "absorbed", "gem_rank"]
			var cost: bool = kind in DeepRules.HOSTILE and str(def.get("target", "")) == "self"
			check(scale != "none" or def.has("from_result") or def.has("of_status") or exact or cost, "%s's %s answers to carat" % [str(key), kind])
			check(not def.has("cost") or scale == "carat", "%s's priced %s swells with carat, since it cannot proc" % [str(key), kind])

func _test_grade_and_names() -> void:
	check(DeepStone.name(stone("BARRAGE", 14, 4, 5)) == "Perfect Flawless 14-carat Barrage", "the jeweller's name: " + DeepStone.name(stone("BARRAGE", 14, 4, 5)))
	check(DeepStone.raw_name(stone("BARRAGE", 14)) == "Medium red stone", "a raw stone is a size class and a color: " + DeepStone.raw_name(stone("BARRAGE", 14)))
	check(not DeepStone.raw_name(stone("BARRAGE", 14)).contains("14"), "a raw stone's name never says its carat")
	var classes: Array = []
	for carat in [1, 4, 5, 9, 10, 14, 15, 19, 20]:
		classes.append(DeepStone.size_name(carat))
	check(classes == ["Tiny", "Tiny", "Small", "Small", "Medium", "Medium", "Large", "Large", "Huge"], "carats fall in Tiny 1-4, Small 5-9, Medium 10-14, Large 15-19, Huge 20+ (%s)" % str(classes))
	var raw_small: Dictionary = stone("STRIKE", 5)
	var raw_smaller: Dictionary = stone("STRIKE", 8)
	check(DeepStone.shown_carat(raw_small) == DeepStone.shown_carat(raw_smaller), "two raw stones of one class are drawn the same size")
	raw_small.appraised = true
	check(DeepStone.shown_carat(raw_small) == 5, "an appraised stone is drawn at its own carat")
	var rough: Dictionary = DeepStone.grade(stone("STRIKE", 1, 0, 3))
	var peerless: Dictionary = DeepStone.grade(stone("STRIKE", 24, 4, 5))
	var chaos: Dictionary = DeepStone.grade(stone("STRIKE", 12, 2, 0, ["STAR", "FRACTURE", "FEATHER"]))
	check(rough.tier == "ROUGH", "a small poor clear common stone is Rough (%s)" % str(rough))
	check(peerless.tier == "PEERLESS", "a perfect flawless 24-carat stone is Peerless whatever its skill (%s)" % str(peerless))
	check(DeepStone.grade(stone("STRIKE", 18, 4, 5)).tier == "EXQUISITE", "an 18-carat perfect flawless stone is only Exquisite")
	check(DeepStone.grade(stone("STRIKE", 17, 4, 0, ["STAR", "FRACTURE", "FEATHER"])).tier == "PEERLESS", "the chaos route reaches Peerless too (%s)" % str(DeepStone.grade(stone("STRIKE", 17, 4, 0, ["STAR", "FRACTURE", "FEATHER"]))))
	check(chaos.index >= 2, "an Intricate stone with a Star grades well (%s)" % str(chaos))
	check(DeepStone.value(stone("STRIKE", 1, 0, 3)) < DeepStone.value(stone("STRIKE", 8, 2, 4)), "bigger stones are worth more")
	var sealed: Dictionary = DeepStone.sealed(stone("STRIKE", 5, 4, 5, ["STAR"]))
	check(sealed.cut == -1 and sealed.inclusions.is_empty() and sealed.carat == 5, "a sealed stone hides everything but size and color")

func _test_forge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	## The luck curve itself, on a copy of the Quarry with its carat band taken off.
	var mine: Dictionary = DeepContent.mine("QUARRY").duplicate(true)
	mine.erase("carat")
	var shallow: Dictionary = _histogram(rng, mine, 1, 4000)
	var deep: Dictionary = _histogram(rng, mine, 24, 4000)
	var banded: Dictionary = _histogram(rng, DeepContent.mine("QUARRY"), 16, 4000)
	check(banded.carat_max <= 7 and banded.carat_mean > shallow.carat_mean, "the Quarry itself still grows with depth inside its band: mean %.2f, heaviest %d" % [banded.carat_mean, banded.carat_max])
	check(shallow.clarity[3] > shallow.clarity[2] and shallow.clarity[3] > shallow.clarity[4], "Clear is the most common clarity: %s" % str(shallow.clarity))
	check(absi(shallow.clarity[1] - shallow.clarity[5]) < 60, "Etched and Flawless are about as rare as each other: %s" % str(shallow.clarity))
	check(shallow.clarity[0] < shallow.clarity[1], "Intricate is the rarest: %s" % str(shallow.clarity))
	## Luck runs out at LUCK_DEPTH_CAP, so the bottom of a mine is not worth more than the
	## mine under it: the climb is real but it levels off.
	check(deep.carat_mean > shallow.carat_mean + 3.5, "carats grow with depth: %.2f shallow, %.2f deep" % [shallow.carat_mean, deep.carat_mean])
	check(shallow.carat_max <= DeepStone.carat_max() and shallow.carat_min >= 1, "carats stay in range")
	check(deep.cut[4] > shallow.cut[4], "deeper stones lean toward Perfect: %s vs %s" % [str(shallow.cut), str(deep.cut)])
	check(deep.clarity[5] > shallow.clarity[5] and deep.clarity[1] > shallow.clarity[1], "depth widens both clarity tails: %s vs %s" % [str(shallow.clarity), str(deep.clarity)])
	check(float(shallow.tiers.get("PEERLESS", 0)) / 4000.0 < 0.01, "Peerless is under one percent near the surface: %s" % str(shallow.tiers))
	check(float(deep.tiers.get("PEERLESS", 0)) / 4000.0 < 0.06, "Peerless stays rare even deep: %s" % str(deep.tiers))
	check(deep.tiers.get("ROUGH", 0) < shallow.tiers.get("ROUGH", 0), "fewer Rough stones deep")
	check(shallow.stars > 0 and shallow.stars < 60, "a Star turns up, rarely: %d in 4000" % shallow.stars)
	check(shallow.inclusion_ok, "inclusion counts match clarity slots and never repeat")
	var solo: int = 0
	var party: int = 0
	for _i in range(200):
		solo += DeepForge.encounter(rng, mine, 6, 1).size()
		party += DeepForge.encounter(rng, mine, 6, 4).size()
	check(party > solo, "a party of four meets more creatures: %d vs %d" % [party, solo])
	check(DeepForge.encounter(rng, mine, 1, 1).size() >= 1, "there is always at least one creature")
	var band: Dictionary = DeepForge.band_for(mine, 12)
	check(int(band.from_depth) == 9, "the band for depth 12 starts at 9")
	var die: Dictionary = DeepForge.roll_die(rng, mine, 5)
	check(DeepDice.SHAPES.has(str(die.shape)) and not die.faces.is_empty(), "the forge rolls a real die")
	## A Zoning lends a stone a second colour, so one of the stone's own colour is a dead
	## inclusion in a slot that could have held something. The rock never grows one.
	var own_zoning: int = 0
	var any_zoning: int = 0
	for _i in range(3000):
		var grown: Dictionary = DeepForge.roll_stone(rng, mine, 20, 6, {}, "z%d" % _i)
		var colour: String = DeepStone.color(grown)
		for key in grown.get("inclusions", []):
			var lends: String = DeepForge.zoning_color(DeepContent.inclusion(str(key)))
			if lends.is_empty():
				continue
			any_zoning += 1
			if lends == colour:
				own_zoning += 1
	check(any_zoning > 20 and own_zoning == 0, "no stone is grown with a Zoning of its own colour (%d zonings, %d of their own)" % [any_zoning, own_zoning])
	var red: Dictionary = DeepStone.make("STRIKE", 8, 2, 0, [], {}, "zred")
	var forced: Array = DeepForge.roll_inclusions(rng, 3, mine, "LENS", DeepStone.color(red))
	check(not forced.has("ZONING_RED"), "and a lens asked for by name is drawn from the rest: %s" % str(forced))

func _histogram(rng: RandomNumberGenerator, mine: Dictionary, depth: int, count: int) -> Dictionary:
	var clarity: Array = [0, 0, 0, 0, 0, 0]
	var cut: Array = [0, 0, 0, 0, 0]
	var tiers: Dictionary = {}
	var carat_sum: float = 0.0
	var carat_max: int = 0
	var carat_min: int = 99
	var stars: int = 0
	var inclusion_ok: bool = true
	for _i in range(count):
		var s: Dictionary = DeepForge.roll_stone(rng, mine, depth)
		clarity[s.clarity] += 1
		cut[s.cut] += 1
		carat_sum += float(s.carat)
		carat_max = maxi(carat_max, int(s.carat))
		carat_min = mini(carat_min, int(s.carat))
		var tier: String = DeepStone.grade(s).tier
		tiers[tier] = int(tiers.get(tier, 0)) + 1
		if s.inclusions.size() != DeepStone.inclusion_slots(s.clarity):
			inclusion_ok = false
		var seen: Dictionary = {}
		for key in s.inclusions:
			if seen.has(key):
				inclusion_ok = false
			seen[key] = true
			if str(DeepContent.inclusion(key).get("class", "")) == "STAR":
				stars += 1
	return {"clarity": clarity, "cut": cut, "tiers": tiers, "carat_mean": carat_sum / float(count), "carat_max": carat_max,
		"carat_min": carat_min, "stars": stars, "inclusion_ok": inclusion_ok}

func _test_oddities() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mine: Dictionary = DeepContent.mine("QUARRY")
	var ctx: Dictionary = {"mine": mine, "depth": 6, "run": "r1"}
	var player: Dictionary = {"haul": [stone("STRIKE", 3, 2, 3), stone("GUARD", 4, 1, 2, ["SILK"])], "rail": [null, null], "dice": [DeepDice.make("D6", "a")], "bag_dice": [], "ore": 0, "hp": 40, "max_hp": 80}
	## The wheel never lifts a cut for the asking: it draws a new one from this depth's table,
	## so every rung shows up and the stone can come off worse than it went on.
	var seen_cuts: Dictionary = {}
	var gone: int = 0
	var worse: int = 0
	for _i in range(300):
		var p: Dictionary = {"haul": [read(stone("STRIKE", 3, 2, 3))], "rail": []}
		var result: Dictionary = DeepOddities.apply({"kind": "reroll_cut", "shatter": 4}, p, {"stone_id": "strike"}, rng, ctx)
		check(result.ok, "a cut reroll resolves")
		if p.haul.is_empty():
			gone += 1
			continue
		seen_cuts[int(p.haul[0].cut)] = true
		if int(p.haul[0].cut) < 2:
			worse += 1
	check(seen_cuts.size() >= 4 and worse > 0 and gone > 0, "a cut reroll lands anywhere on the ladder and can go down: %s, %d worse, %d lost" % [str(seen_cuts.keys()), worse, gone])
	check(not DeepOddities.apply({"kind": "reroll_cut"}, player, {"stone_id": "nope"}, rng, ctx).ok, "a cut reroll needs a stone")
	check(not DeepOddities.apply({"kind": "reroll_cut"}, {"haul": [stone("STRIKE", 3, 2, 3)], "rail": []}, {"stone_id": "strike"}, rng, ctx).ok,
		"a stone nobody has read yet has no cut to draw again")
	## Clarity is drawn again with whatever is frozen inside it.
	var seen_clarity: Dictionary = {}
	var slots_match: bool = true
	for _i in range(200):
		var p: Dictionary = {"haul": [read(stone("GUARD", 6, 2, 2, ["SILK"]))], "rail": []}
		var result: Dictionary = DeepOddities.apply({"kind": "reroll_clarity", "shatter": 0}, p, {"stone_id": "guard"}, rng, ctx)
		check(result.ok, "a clarity reroll resolves")
		if p.haul.is_empty():
			continue
		seen_clarity[int(p.haul[0].clarity)] = true
		if p.haul[0].inclusions.size() != DeepStone.inclusion_slots(int(p.haul[0].clarity)):
			slots_match = false
	check(seen_clarity.size() >= 4 and slots_match, "a clarity reroll lands anywhere and refills what is frozen inside: %s" % str(seen_clarity.keys()))
	var removed: Dictionary = DeepOddities.apply({"kind": "remove_inclusion"}, player, {"stone_id": "guard", "inclusion": "SILK"}, rng, ctx)
	check(removed.ok and player.haul[1].inclusions.is_empty(), "the acid bath removes an inclusion")
	## The crucible: the heavier stone survives and takes up to a third of the lighter one.
	var fused: Dictionary = DeepOddities.apply({"kind": "fuse", "carry": 30}, player, {"keep_id": "strike", "feed_id": "guard"}, rng, ctx)
	check(fused.ok and player.haul.size() == 1, "fusing gives back one stone and eats the other")
	check(int(player.haul[0].carat) >= 4 and int(player.haul[0].carat) <= 4 + int(3 * 30 / 100), "and it weighs the heavier stone plus a share of the lighter: %d" % int(player.haul[0].carat))
	check(str(player.haul[0].skill) in ["STRIKE", "GUARD"], "its skill is one of the two")
	_test_fuse(rng, ctx)
	var geode: Dictionary = DeepOddities.apply({"kind": "geode", "three": 100, "one": 0}, player, {}, rng, ctx)
	check(geode.ok and geode.made.size() == 3 and player.haul.size() == 4, "a geode can give three stones")
	_test_workshop_oddities(rng, ctx)
	check(DeepOddities.apply({"kind": "heal", "pct": 25}, player, {}, rng, ctx).ok and player.hp == 60, "the medic heals a quarter")
	var before: int = player.haul.size()
	var worth: int = DeepStone.value(player.haul[0])
	var sold: Dictionary = DeepOddities.apply({"kind": "collector_sell", "mult": 2}, player, {"stone_id": str(player.haul[0].id)}, rng, ctx)
	check(sold.ok and player.ore == worth * 2 and player.haul.size() == before - 1, "the collector pays double")
	var case: Dictionary = DeepOddities.offer_for(DeepContent.oddity("COLLECTOR"), rng, mine, 6, "r1")
	check(case.has("stone") and int(case.price) == DeepStone.value(case.stone) * 2 and bool(case.stone.appraised), "and has one read stone in her case at twice its worth")
	player.ore = int(case.price)
	var bought: Dictionary = DeepOddities.apply({"kind": "collector_buy", "price_mult": 2}, player, {}, rng,
		{"mine": mine, "depth": 6, "run": "r1", "offer": case})
	check(bought.ok and player.ore == 0 and bought.made.size() == 1, "buying it empties the purse and fills the haul")
	check(not DeepOddities.apply({"kind": "collector_buy"}, player, {}, rng, {"mine": mine, "depth": 6, "run": "r1", "offer": case}).ok, "and cannot be done twice on an empty purse")
	_test_idol(rng, ctx)
	_test_well(rng, ctx)
	_test_echo(rng, ctx)
	_test_acid(rng, ctx)
	_test_clarity_push(rng, ctx)
	var shrine: Dictionary = DeepOddities.apply({"kind": "shrine"}, player, {"pattern": "pair"}, rng, ctx)
	check(shrine.ok and player.run_mods.shrine == "pair", "the shrine remembers a pattern")
	check(DeepOddities.validate(DeepContent.oddity("CUTTERS_WHEEL")).is_empty(), "the wheel validates")
	check(not DeepOddities.validate({"name": "x", "choices": [ {"id": "a", "action": {"kind": "explode"}}, {"id": "b", "action": {"kind": "none"}}]}).is_empty(), "an unknown action is refused")

func _test_fuse(rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	## Two colors in means the colour that lost comes out frozen in as a Zoning, so a fused
	## stone always says what was burned to make it.
	var zoned: int = 0
	var clarities: Dictionary = {}
	var top: int = DeepContent.clarity_index("INCLUDED")
	var bottom: int = DeepContent.clarity_index("INTRICATE")
	for _i in range(200):
		var p: Dictionary = {"haul": [read(stone("STRIKE", 10, 4, 3)), read(stone("GUARD", 4, 0, 3))], "rail": []}
		var out: Dictionary = DeepOddities.apply({"kind": "fuse", "carry": 30}, p, {"keep_id": "strike", "feed_id": "guard"}, rng, ctx)
		check(out.ok and p.haul.size() == 1, "a fusion resolves")
		var made: Dictionary = p.haul[0]
		check(int(made.carat) >= 10 and int(made.carat) <= 11, "the heavier carat survives and carries some of the lighter: %d" % int(made.carat))
		check(int(made.cut) == 2, "the cut is the average of the two: %d" % int(made.cut))
		clarities[int(made.clarity)] = true
		check(int(made.clarity) >= mini(bottom, top) and int(made.clarity) <= maxi(bottom, top), "the clarity lands between Included and Intricate")
		var want: String = DeepOddities.zoning_key("BLUE" if str(made.skill) == "STRIKE" else "RED")
		if made.inclusions.has(want):
			zoned += 1
	check(zoned == 200, "and the colour that lost is always frozen in as a Zoning (%d of 200)" % zoned)
	check(clarities.size() >= 2, "the crucible draws its clarity rather than keeping one")

func _test_idol(rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	## The eye takes between one and five pulls, each dearer than the last, and what comes out
	## is sized to the depth rather than promised flat.
	var action: Dictionary = {"kind": "idol", "hp": 3, "hp_step": 2, "tries_max": 5}
	var pulls: Dictionary = {}
	for _i in range(120):
		var p: Dictionary = {"haul": [], "rail": [], "hp": 400, "max_hp": 400}
		var tries: Dictionary = {}
		var got: Dictionary = {}
		for _pull in range(6):
			var was: int = int(p.hp)
			var out: Dictionary = DeepOddities.apply(action, p, {}, rng, {"mine": ctx.mine, "depth": ctx.depth, "run": "r1", "tries": tries})
			check(out.ok, "a pull at the idol resolves")
			tries = out.tries
			var cost: int = was - int(p.hp)
			check(cost == 3 + 2 * (int(tries.done) - 1), "each pull costs more than the last: %d on pull %d" % [cost, int(tries.done)])
			if not bool(out.get("again", false)):
				got = out
				break
		pulls[int(tries.done)] = true
		check(not got.is_empty() and got.made.size() == 1, "the eye comes out inside five pulls")
		var eye: Dictionary = got.made[0]
		var least: int = int(round(3.0 + DeepForge.luck(ctx.mine, int(ctx.depth))))
		check(int(eye.carat) >= least and int(eye.carat) <= least + 3, "its size is the depth, not a flat sixteen: %d" % int(eye.carat))
		check(eye.inclusions.size() == 2 and bool(eye.appraised), "and it is appraised and cracked twice")
	check(pulls.size() >= 3, "how many pulls it takes varies: %s" % str(pulls.keys()))

func _test_well(rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	## Everything down the well is weighed into pyrite, and that number picks a rung. A
	## pittance is nearly always nothing; a thousand of it reaches the top of the ladder.
	var poor: int = 0
	var rich_top: int = 0
	for _i in range(2000):
		if DeepOddities.well_rung(rng, 8.0) == 0:
			poor += 1
		if DeepOddities.well_rung(rng, 1000.0) >= DeepOddities.WELL_PRIZES.size() - 3:
			rich_top += 1
	check(poor > 1650 and poor < 1950, "a pittance comes back as nothing about nine times in ten (%d of 2000)" % poor)
	check(rich_top > 300, "a thousand of it reaches the top of the ladder often (%d of 2000)" % rich_top)
	## A read stone is worth three times what the same stone in its rock is worth.
	var raw: Dictionary = stone("STRIKE", 10, 3, 3)
	var known: Dictionary = read(stone("STRIKE", 10, 3, 3))
	check(is_equal_approx(DeepOddities.well_worth(known, 0.5, 1.5), DeepOddities.well_worth(raw, 0.5, 1.5) * 3.0),
		"reading a stone first trebles what the well counts it at")
	## Every rung gives back what it says it does.
	for rung in range(DeepOddities.WELL_PRIZES.size()):
		var p: Dictionary = {"haul": [], "rail": [], "ore": 0, "hp": 5, "max_hp": 40}
		var prize: Dictionary = DeepOddities.well_prize(rng, rung, p, ctx.mine, int(ctx.depth), "r1")
		var entry: Dictionary = DeepOddities.WELL_PRIZES[rung]
		match str(entry.kind):
			"none":
				check(p.haul.is_empty() and int(p.ore) == 0, "the bottom rung gives nothing")
			"ore":
				check(int(p.ore) == int(entry.amount) and p.haul.is_empty(), "a pyrite rung pays %d" % int(entry.amount))
			"raw":
				check(p.haul.size() == 1 and not bool(p.haul[0].appraised), "a stone rung gives one still in its rock")
				if bool(entry.get("opal", false)):
					check(DeepStone.is_opal(p.haul[0]), "and an opal rung gives an opal")
			"heal":
				check(int(p.hp) == 40 and p.haul.is_empty() and int(p.ore) == 0, "the heal rung closes every wound")
			"gem":
				check(p.haul.size() == 1 and bool(p.haul[0].appraised), "a gem rung gives one already read")
			"perfect":
				check(p.haul.size() == 1 and int(p.haul[0].cut) == DeepPatterns.STEPS - 1
					and int(p.haul[0].clarity) == DeepContent.clarity_index("FLAWLESS") and p.haul[0].inclusions.is_empty(),
					"the top rung gives a gem cut perfect and left flawless")
		check(int(prize.tier) >= 0 and int(prize.tier) <= 4, "every rung names how loud it is")

func _test_echo(rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	var p: Dictionary = {"haul": [read(stone("STRIKE", 5, 3, 3))], "rail": []}
	var out: Dictionary = DeepOddities.apply({"kind": "echo_stone", "bonus": 2}, p, {"stone_id": "strike"}, rng, ctx)
	check(out.ok and p.haul.size() == 2 and str(p.haul[1].skill) == "STRIKE", "the echo gives back another of the same skill")
	check(not bool(p.haul[1].appraised) and str(p.haul[1].id) != "strike", "and it comes still in its rock, its own stone")
	check(bool(p.haul[0].appraised) and int(p.haul[0].carat) == 5, "the stone held up is untouched")

func _test_acid(rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	var p: Dictionary = {"haul": [stone("STRIKE", 3, 2, 3), stone("GUARD", 4, 1, 2), stone("VENOM", 2, 0, 3)], "rail": [], "hp": 40, "max_hp": 60}
	var out: Dictionary = DeepOddities.apply({"kind": "acid_appraise", "most": 3, "hp": 6}, p, {"stone_ids": ["strike", "guard"]}, rng, ctx)
	check(out.ok and bool(p.haul[0].appraised) and bool(p.haul[1].appraised) and not bool(p.haul[2].appraised),
		"the racks read the stones set in them and no others")
	check(int(p.hp) == 28 and out.revealed.size() == 2, "and the acid takes six health for each")
	check(not DeepOddities.apply({"kind": "acid_appraise", "most": 3, "hp": 6}, p, {"stone_ids": []}, rng, ctx).ok, "an empty rack does nothing")
	check(not DeepOddities.apply({"kind": "acid_appraise", "most": 3, "hp": 6}, p, {"stone_ids": ["strike"]}, rng, ctx).ok, "a stone already read cannot go in")
	var four: Dictionary = {"haul": [stone("STRIKE", 1), stone("GUARD", 1), stone("VENOM", 1), stone("CLEAVE", 1)], "rail": [], "hp": 40, "max_hp": 60}
	check(not DeepOddities.apply({"kind": "acid_appraise", "most": 3, "hp": 6}, four, {"stone_ids": ["strike", "guard", "venom", "cleave"]}, rng, ctx).ok,
		"and the racks hold three")

func _test_clarity_push(rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	## The oven drives clarity further from Clear along whichever side it already leans.
	var clear: int = DeepContent.clear_index()
	var pristine: int = DeepContent.clarity_index("PRISTINE")
	var included: int = DeepContent.clarity_index("INCLUDED")
	var up: Dictionary = {"haul": [read(stone("STRIKE", 3, 2, pristine))], "rail": []}
	check(DeepOddities.apply({"kind": "push_clarity", "shatter": 0}, up, {"stone_id": "strike"}, rng, ctx).ok
		and int(up.haul[0].clarity) == DeepContent.clarity_index("FLAWLESS"), "a Pristine stone is driven to Flawless")
	var down: Dictionary = {"haul": [read(stone("GUARD", 3, 2, included, ["SILK"]))], "rail": []}
	check(DeepOddities.apply({"kind": "push_clarity", "shatter": 0}, down, {"stone_id": "guard"}, rng, ctx).ok
		and int(down.haul[0].clarity) == DeepContent.clarity_index("ETCHED"), "an Included stone is driven to Etched")
	check(down.haul[0].inclusions.size() == DeepStone.inclusion_slots(int(down.haul[0].clarity)) and down.haul[0].inclusions.has("SILK"),
		"and the new room inside it is filled without losing what was there")
	var flat: Dictionary = {"haul": [read(stone("VENOM", 3, 2, clear))], "rail": []}
	check(DeepOddities.apply({"kind": "push_clarity", "shatter": 0}, flat, {"stone_id": "venom"}, rng, ctx).ok
		and int(flat.haul[0].clarity) == pristine, "a Clear stone leans toward Pristine")
	var done: Dictionary = {"haul": [read(stone("VENOM", 3, 2, DeepContent.clarity_index("FLAWLESS")))], "rail": []}
	check(not DeepOddities.apply({"kind": "push_clarity", "shatter": 0}, done, {"stone_id": "venom"}, rng, ctx).ok,
		"a Flawless stone has nowhere left to go")

func _test_workshop_oddities(rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	## The oddities that change dice and stones in place: the lens, the drum, the seam, and
	## the smithy and the carver, the only places a die changes at all.
	var die_of: Callable = func(key: String, id: String) -> Dictionary: return DeepDice.make(key, id)
	var hollow_of: Callable = func(id: String) -> Dictionary: return DeepDice.make("D10", id, {"etches": [{"face": 0, "kind": "blank"}]})
	var raw: Dictionary = stone("VENOM", 3, 2, 3)
	var set_guard: Dictionary = stone("GUARD", 2, 2, 3)
	set_guard.appraised = true
	var p: Dictionary = {"haul": [raw], "rail": [set_guard, null], "dice": [die_of.call("D4", "d4"), hollow_of.call("hollow"), die_of.call("D20", "d20")],
		"bag_dice": [DeepDice.make("D6", "phial", {"pattern": "shallow"})], "ore": 20, "hp": 40, "max_hp": 80}
	var looked: Dictionary = DeepOddities.apply({"kind": "appraise"}, p, {"stone_id": "venom"}, rng, ctx)
	check(looked.ok and bool(raw.appraised) and looked.changed.size() == 1, "the cabinet's lens appraises a raw stone")
	check(not DeepOddities.apply({"kind": "appraise"}, p, {"stone_id": "venom"}, rng, ctx).ok, "but not one already appraised")
	var color: String = DeepStone.color(raw)
	var tumbled: Dictionary = DeepOddities.apply({"kind": "tumble"}, p, {"stone_id": "venom"}, rng, ctx)
	check(tumbled.ok and str(raw.skill) != "VENOM" and DeepStone.color(raw) == color, "the drum turns out another skill of the same color (%s)" % str(raw.skill))
	check(int(raw.carat) == 3 and int(raw.cut) == 2, "and keeps the stone's carats and cut")
	var socketed: Dictionary = DeepOddities.apply({"kind": "tumble"}, p, {"stone_id": "guard"}, rng, ctx)
	check(socketed.ok and DeepStone.color(set_guard) == "BLUE" and str(set_guard.skill) != "GUARD", "a set stone tumbles in its socket (%s)" % str(set_guard.skill))
	var hammered: Dictionary = DeepOddities.apply({"kind": "upsize"}, p, {"die_id": "d4"}, rng, ctx)
	check(hammered.ok and str(p.dice[0].shape) == "D6" and str(p.dice[0].id) == "d4" and p.dice[0].faces.size() == 6, "the anvil hammers a d4 into a d6 that keeps its id")
	check(not DeepOddities.resize_refusal(die_of.call("D100", "biggest"), 1).is_empty(), "a d100 is as big as dice come")
	var tempered: Dictionary = DeepOddities.apply({"kind": "temper", "amount": 2}, p, {"die_id": "hollow"}, rng, ctx)
	check(tempered.ok and str(p.dice[1].faces[0].kind) == "plain" and int(p.dice[1].faces[0].value) == 2, "tempering turns a blank face into a 2")
	var phial: Dictionary = DeepOddities.apply({"kind": "temper", "amount": 2}, p, {"die_id": "phial"}, rng, ctx)
	check(phial.ok and int(p.bag_dice[0].faces[0].value) == 3, "and lifts the lowest face of a bagged die by two")
	check(int(DeepDice.top(p.bag_dice[0])) == 6, "a Shallow die is still judged against the size it is")
	var filed: Dictionary = DeepOddities.apply({"kind": "downsize"}, p, {"die_id": "d20"}, rng, ctx)
	check(filed.ok and str(p.dice[2].shape) == "D16" and str(p.dice[2].id) == "d20" and p.dice[2].faces.size() == 16 and filed.dice.size() == 1, "the smithy files a d20 down to a d16 that keeps its id")
	check(DeepOddities.apply({"kind": "downsize"}, p, {"die_id": "d4"}, rng, ctx).ok and str(p.dice[0].shape) == "D4", "a hammered die files back down")
	check(DeepOddities.resize_refusal(p.dice[0], -1).is_empty(), "a d4 can now be filed down to a d3")
	var keen: Dictionary = DeepDice.make("D12", "keen", {"material": "iron", "etches": [{"face": 0, "kind": "shiny"}]})
	check(DeepOddities.resize(keen, -2).is_empty() and str(keen.shape) == "D8" and str(keen.material) == "iron" and str(keen.faces[0].kind) == "shiny",
		"resizing keeps the material and the etchings, two sizes at once if asked")
	check(DeepOddities.resize_refusal(die_of.call("D20", "big"), 1).is_empty() and DeepOddities.resize_refusal(die_of.call("D20", "big"), -5).is_empty(), "a d20 can grow as well as shrink")
	var raised: Dictionary = DeepOddities.apply({"kind": "raise_face", "amount": 1}, p, {"die_id": "d4", "face": 2}, rng, ctx)
	check(raised.ok and int(p.dice[0].faces[2].value) == 4 and raised.dice.size() == 1, "the carver raises a chosen face by one")
	check(DeepOddities.apply({"kind": "raise_face", "amount": 1}, p, {"die_id": "d4", "face": 3}, rng, ctx).ok and int(p.dice[0].faces[3].value) == 5,
		"and past the die's own highest face: the chisel has no ceiling")
	p.dice.append(keen)
	check(DeepOddities.apply({"kind": "raise_face", "amount": 1}, p, {"die_id": "keen", "face": 7}, rng, ctx).ok and int(p.dice[3].faces[7].value) == 9,
		"the top face of a die comes up too")
	p.dice.append(hollow_of.call("blankie"))
	check(not DeepOddities.apply({"kind": "lower_face", "amount": 1}, p, {"die_id": "blankie", "face": 0}, rng, ctx).ok, "a blank face has no number to lower")
	var filled: Dictionary = DeepOddities.apply({"kind": "raise_face", "amount": 1}, p, {"die_id": "blankie", "face": 0}, rng, ctx)
	check(filled.ok and str(p.dice[4].faces[0].kind) == "plain" and int(p.dice[4].faces[0].value) == 1, "a raised blank face becomes a 1")
	check(not DeepOddities.apply({"kind": "lower_face", "amount": 1}, p, {"die_id": "blankie", "face": 0}, rng, ctx).ok, "a 1 cannot be lowered")
	var lowered: Dictionary = DeepOddities.apply({"kind": "lower_face", "amount": 1}, p, {"die_id": "blankie", "face": 9}, rng, ctx)
	check(lowered.ok and int(p.dice[4].faces[9].value) == 9 and lowered.dice.size() == 1, "the carver lowers a chosen face by one")
	p.dice.append(DeepDice.make("D6", "wild", {"etches": [{"face": 5, "kind": "wild"}]}))
	var tamed: Dictionary = DeepOddities.apply({"kind": "lower_face", "amount": 1}, p, {"die_id": "wild", "face": 5}, rng, ctx)
	check(tamed.ok and int(p.dice[5].faces[5].value) == 5 and str(p.dice[5].faces[5].kind) == "wild", "a lowered face keeps its etching")
	check(p.dice.size() == 6 and p.bag_dice.size() == 1, "nothing here adds a die")
	var pried: Dictionary = DeepOddities.apply({"kind": "pry", "bonus": 4, "hp": 8}, p, {}, rng, ctx)
	check(pried.ok and pried.made.size() == 1 and int(p.hp) == 32, "prying a stone loose costs eight health")
	var chips: Dictionary = DeepOddities.apply({"kind": "chips", "count": 2, "bonus": - 2}, p, {}, rng, ctx)
	check(chips.ok and chips.made.size() == 2 and p.haul.size() == 4, "the chips are two small stones")
	for key in ["SMITHY", "CARVER", "TUMBLER", "SEAM", "LOUPE_CABINET", "ACID_BATH", "COLLECTOR", "ECHO_CHAMBER", "WISHING_WELL"]:
		check(DeepOddities.validate(DeepContent.oddity(key)).is_empty(), "%s validates" % key)
	for kind in ["buy_die", "trade_die", "dice_swap", "grind", "vug", "copy_inclusion", "reveal_inclusions"]:
		check(not DeepOddities.validate({"name": "x", "choices": [ {"id": "a", "action": {"kind": kind}}, {"id": "b", "action": {"kind": "none"}}]}).is_empty(), "no card can %s any more" % kind)
	check(not DeepOddities.validate({"name": "x", "room": "stall", "choices": [ {"id": "a", "action": {"kind": "none"}}, {"id": "b", "action": {"kind": "none"}}]}).is_empty(), "a card's room is a smithy or a carver")
	check(str(DeepContent.oddity("SMITHY").room) == "smithy" and str(DeepContent.oddity("CARVER").room) == "carver", "the smithy and the carver each have their card")
