extends SceneTree
## Content, rules, stones and the forge.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_pack()
	_test_evaluation()
	_test_inclusions()
	_test_grade_and_names()
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
	check(DeepContent.clarity_name(5) == "Flawless" and DeepContent.clarity_name(0) == "Riddled", "clarity names")
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
	broken.skills.BAD = {"name": "Bad", "colour": "PINK", "rarity": "COMMON", "trigger": {"kind": "pair", "ladder": [1, 2]}, "effects": [{"kind": "explode"}]}
	check(DeepContent.validate(broken).size() >= 3, "a bad skill is refused for each thing wrong with it")

func _test_evaluation() -> void:
	var a: Array = hand([3, 3, 5, 5, 5])
	var strike_poor: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0), a)
	check(strike_poor.active and amount_of(strike_poor, "damage") == 6, "Poor Strike reads the highest die: 5 × 1.25 = 6 (%d)" % amount_of(strike_poor, "damage"))
	var strike_perfect: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 4), a)
	check(amount_of(strike_perfect, "damage") == 18, "Perfect Strike reads three dice: 15 × 1.25 = 18 (%d)" % amount_of(strike_perfect, "damage"))
	var strike_big: Dictionary = DeepStone.evaluate(stone("STRIKE", 12, 0), a)
	check(amount_of(strike_big, "damage") == 20, "Carat 12 is ×4: 5 × 4 = 20 (%d)" % amount_of(strike_big, "damage"))
	var cleave_poor: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 0), hand([2, 2, 4, 5, 6]))
	check(not cleave_poor.active, "Poor Cleave wants a pair of fives")
	var cleave_perfect: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 4), hand([2, 2, 4, 5, 6]))
	check(cleave_perfect.active and amount_of(cleave_perfect, "damage") == 5 and int(cleave_perfect.effects[0].splash) == 50, "Perfect Cleave takes any pair: 4 × 1.25 = 5 with half splash")
	var cleave_flawless: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 0, 5), hand([4, 4, 2, 5, 6]))
	check(cleave_flawless.active, "a Flawless stone is judged a Cut step better, so Poor + 1 takes a pair of fours")
	check(int(cleave_flawless.effects[0].splash) == 100, "the Flawless line changes the splash")
	check(amount_of(cleave_flawless, "damage") == int(floor(8 * 1.25 * 1.5)), "Flawless multiplies magnitude by 1.5 (%d)" % amount_of(cleave_flawless, "damage"))
	var barrage: Dictionary = DeepStone.evaluate(stone("BARRAGE", 1, 4), hand([1, 2, 3, 6, 6]))
	check(barrage.active and barrage.effects[0].repeat == 3 and amount_of(barrage, "damage") == 5, "Barrage repeats once per die in the run")
	var barrage_flawless: Dictionary = DeepStone.evaluate(stone("BARRAGE", 1, 4, 5), hand([1, 2, 3, 6, 6]))
	check(str(barrage_flawless.effects[0].target) == "spread", "Flawless Barrage spreads")
	var glimmer: Dictionary = DeepStone.evaluate(stone("GLIMMER", 1, 2), hand([1, 2, 3, 4, 5]))
	check(amount_of(glimmer, "raise_low") == 2 and not bool(glimmer.effects[0].scaled), "Glimmer's amount comes from its ladder and is not scaled")
	var mend: Dictionary = DeepStone.evaluate(stone("MEND", 1, 4), hand([1, 2, 3, 4, 5]))
	check(amount_of(mend, "heal") == 7, "Perfect Mend reads the three lowest: 6 × 1.25 = 7 (%d)" % amount_of(mend, "heal"))
	var spall: Dictionary = DeepStone.evaluate(stone("SPALL", 1, 0), hand([1, 2, 3, 4, 5]))
	check(amount_of(spall, "damage") == 7, "Spall doubles the two lowest: 6 × 1.25 = 7 (%d)" % amount_of(spall, "damage"))
	var context: Dictionary = {"unit": {"block": 10, "block_lost": 7}}
	check(amount_of(DeepStone.evaluate(stone("RIPOSTE", 1, 0), a, context), "damage") == 8, "Riposte reads block lost")
	check(amount_of(DeepStone.evaluate(stone("THRIVE", 1, 0), a, context), "heal") == 6, "Thrive reads block")
	var seven: Dictionary = DeepStone.evaluate(stone("LUCKY_SEVEN", 1, 0), hand([7, 7, 1, 2, 3], 8))
	check(seven.active and seven.effects[0].repeat == 2 and amount_of(seven, "gold") == 8, "two sevens: two hits and two payouts")
	var fizzle: Dictionary = DeepStone.evaluate(stone("CRUSH", 1, 0), hand([1, 2, 3, 4, 5]))
	check(not fizzle.active and not fizzle.reason.is_empty(), "a fizzle explains itself: " + fizzle.reason)
	check(DeepStone.total_amount(strike_perfect) == 18 and DeepStone.total_amount(barrage) == 15, "total_amount sums repeats")

func _test_inclusions() -> void:
	var a: Array = hand([3, 3, 5, 5, 5])
	var needle: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 4, 2, ["NEEDLE"]), a)
	check(amount_of(needle, "damage") == 18 + 3, "Needle adds one damage per die read")
	var fracture_hit: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["FRACTURE"]), a)
	check(amount_of(fracture_hit, "damage") == 12, "Fracture doubles: 5 × 1.25 × 2 = 12 (%d)" % amount_of(fracture_hit, "damage"))
	var fracture_miss: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["FRACTURE"]), hand([1, 3, 5, 5, 5]))
	check(not fracture_miss.active and fracture_miss.reason.begins_with("Fracture"), "Fracture fizzles on a 1: " + fracture_miss.reason)
	var chip: Dictionary = DeepStone.effective(stone("STRIKE", 2, 1, 2, ["CHIP"]))
	check(chip.carat == 5 and chip.cut_step == 0, "Chip: +3 carats, one Cut step worse")
	var cavity: Dictionary = DeepStone.effective(stone("STRIKE", 4, 4, 2, ["CAVITY"]))
	check(cavity.cut_step == 0 and is_equal_approx(cavity.magnitude, 3.0), "Cavity: carats count double, cut is Poor (%s)" % str(cavity))
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
	check(bruise.hp_cost == 2 and amount_of(bruise, "damage") == 9, "Bruise costs 2 HP and adds half again")
	var rider: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["PINPOINT_GOLD", "SPARK"]), a)
	check(amount_of(rider, "gold") == 2 and rider.resonance_gain == 2, "a Pinpoint rides along and a Spark adds Resonance")
	check(DeepStone.colours(stone("STRIKE", 1, 0, 2, ["ZONING_BLUE"])) == ["RED", "BLUE"], "Colour Zoning adds a colour")
	check(DeepStone.colours(stone("STRIKE", 1, 0, 2, ["ALEXANDRITE"]), "GREEN") == ["RED", "GREEN"], "Alexandrite takes the socket's colour")
	check(DeepStone.fits(stone("STRIKE"), "RED") and not DeepStone.fits(stone("STRIKE"), "BLUE") and DeepStone.fits(stone("STRIKE"), "ANY"), "sockets take their colour or anything")
	check(DeepStone.is_locked(stone("STRIKE", 1, 0, 2, ["KNOT"])), "a Knot is locked in")
	var flu: Dictionary = DeepStone.effective(stone("STRIKE", 1, 0, 2, ["FLUORESCENCE"]), {"depth": 14})
	check(flu.carat == 5, "Fluorescence adds a carat per depth below 10")
	var feather: Dictionary = DeepStone.evaluate(stone("STRIKE", 1, 0, 2, ["FEATHER"]), a)
	check(feather.next_cut_step == 1, "a Feather passes a Cut step forward")
	var bonus: Dictionary = DeepStone.evaluate(stone("CLEAVE", 1, 0), hand([4, 4, 1, 2, 3]), {"cut_step_bonus": 1})
	check(bonus.active, "a passed Cut step loosens the rung")

func _test_grade_and_names() -> void:
	check(DeepStone.name(stone("BARRAGE", 14, 4, 5)) == "Perfect Flawless 14-carat Barrage", "the jeweller's name: " + DeepStone.name(stone("BARRAGE", 14, 4, 5)))
	check(DeepStone.raw_name(stone("BARRAGE", 14)) == "14-carat Red stone", "a raw stone is size and colour: " + DeepStone.raw_name(stone("BARRAGE", 14)))
	var rough: Dictionary = DeepStone.grade(stone("STRIKE", 1, 0, 3))
	var peerless: Dictionary = DeepStone.grade(stone("STRIKE", 20, 4, 5))
	var chaos: Dictionary = DeepStone.grade(stone("STRIKE", 12, 2, 0, ["STAR", "FRACTURE", "FEATHER"]))
	check(rough.tier == "ROUGH", "a small poor clear common stone is Rough (%s)" % str(rough))
	check(peerless.tier == "PEERLESS", "a perfect flawless 20-carat stone is Peerless whatever its skill (%s)" % str(peerless))
	check(DeepStone.grade(stone("STRIKE", 18, 4, 5)).tier == "EXQUISITE", "an 18-carat perfect flawless stone is only Exquisite")
	check(DeepStone.grade(stone("STRIKE", 14, 4, 0, ["STAR", "FRACTURE", "FEATHER"])).tier == "PEERLESS", "the chaos route reaches Peerless too (%s)" % str(DeepStone.grade(stone("STRIKE", 14, 4, 0, ["STAR", "FRACTURE", "FEATHER"]))))
	check(chaos.index >= 2, "a Riddled stone with a Star grades well (%s)" % str(chaos))
	check(DeepStone.value(stone("STRIKE", 1, 0, 3)) < DeepStone.value(stone("STRIKE", 8, 2, 4)), "bigger stones are worth more")
	var sealed: Dictionary = DeepStone.sealed(stone("STRIKE", 5, 4, 5, ["STAR"]))
	check(sealed.cut == -1 and sealed.inclusions.is_empty() and sealed.carat == 5, "a sealed stone hides everything but size and colour")

func _test_forge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var mine: Dictionary = DeepContent.mine("QUARRY")
	var shallow: Dictionary = _histogram(rng, mine, 1, 4000)
	var deep: Dictionary = _histogram(rng, mine, 24, 4000)
	check(shallow.clarity[3] > shallow.clarity[2] and shallow.clarity[3] > shallow.clarity[4], "Clear is the most common clarity: %s" % str(shallow.clarity))
	check(absi(shallow.clarity[1] - shallow.clarity[5]) < 60, "Veined and Flawless are about as rare as each other: %s" % str(shallow.clarity))
	check(shallow.clarity[0] < shallow.clarity[1], "Riddled is the rarest: %s" % str(shallow.clarity))
	check(deep.carat_mean > shallow.carat_mean + 5.0, "carats grow with depth: %.2f shallow, %.2f deep" % [shallow.carat_mean, deep.carat_mean])
	check(shallow.carat_max <= 20 and shallow.carat_min >= 1, "carats stay in range")
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
	var player: Dictionary = {"haul": [stone("STRIKE", 3, 2, 3), stone("GUARD", 4, 1, 2, ["SILK"])], "rail": [null, null], "dice": [DeepDice.make("D6", DeepContent.die("D6"), "a")], "bag_dice": [], "ore": 0, "loupes": 0, "hp": 40, "max_hp": 80}
	var ups: int = 0
	var downs: int = 0
	var gone: int = 0
	for _i in range(300):
		var p: Dictionary = {"haul": [stone("STRIKE", 3, 2, 3)], "rail": []}
		var result: Dictionary = DeepOddities.apply({"kind": "recut", "up": 60, "down": 30, "shatter": 10}, p, {"stone_id": "strike"}, rng, ctx)
		check(result.ok, "a recut resolves")
		if p.haul.is_empty():
			gone += 1
		elif int(p.haul[0].cut) == 3:
			ups += 1
		elif int(p.haul[0].cut) == 1:
			downs += 1
	check(ups > downs and downs > gone and gone > 0, "recut odds land near 60/30/10: %d/%d/%d" % [ups, downs, gone])
	check(not DeepOddities.apply({"kind": "recut"}, player, {"stone_id": "nope"}, rng, ctx).ok, "a recut needs a stone")
	var removed: Dictionary = DeepOddities.apply({"kind": "remove_inclusion"}, player, {"stone_id": "guard", "inclusion": "SILK"}, rng, ctx)
	check(removed.ok and player.haul[1].inclusions.is_empty(), "the acid bath removes an inclusion")
	var fused: Dictionary = DeepOddities.apply({"kind": "fuse", "survive": 50}, player, {"keep_id": "strike", "feed_id": "guard"}, rng, ctx)
	check(fused.ok and player.haul.size() == 1 and int(player.haul[0].carat) == 7, "fusing sums the carats and eats the other stone")
	var geode: Dictionary = DeepOddities.apply({"kind": "geode", "three": 100, "one": 0}, player, {}, rng, ctx)
	check(geode.ok and geode.made.size() == 3 and player.haul.size() == 4, "a geode can give three stones")
	check(DeepOddities.apply({"kind": "loupes", "amount": 2}, player, {}, rng, ctx).ok and player.loupes == 2, "loupes are pocketed")
	check(DeepOddities.apply({"kind": "heal", "pct": 25}, player, {}, rng, ctx).ok and player.hp == 60, "the medic heals a quarter")
	var before: int = player.haul.size()
	var sold: Dictionary = DeepOddities.apply({"kind": "collector_sell", "mult": 3}, player, {"stone_id": "strike"}, rng, ctx)
	check(sold.ok and player.ore == DeepStone.value(stone("STRIKE", 7, 2, 3)) * 3 and player.haul.size() == before - 1, "the collector pays triple")
	var idol: Dictionary = DeepOddities.apply({"kind": "idol", "carat_min": 16}, player, {}, rng, ctx)
	check(idol.ok and int(idol.made[0].carat) >= 16 and idol.made[0].inclusions.size() == 2 and bool(idol.made[0].appraised), "the idol's eye is heavy, cracked and appraised")
	var ground: Dictionary = DeepOddities.apply({"kind": "grind"}, player, {"die_id": "a", "face": 0}, rng, ctx)
	check(ground.ok and int(player.dice[0].faces[0].value) == 2, "grinding replaces a face with its neighbour")
	var shrine: Dictionary = DeepOddities.apply({"kind": "shrine"}, player, {"pattern": "pair"}, rng, ctx)
	check(shrine.ok and player.run_mods.shrine == "pair", "the shrine remembers a pattern")
	check(DeepOddities.validate(DeepContent.oddity("CUTTERS_WHEEL")).is_empty(), "the wheel validates")
	check(not DeepOddities.validate({"name": "x", "choices": [{"id": "a", "action": {"kind": "explode"}}, {"id": "b", "action": {"kind": "none"}}]}).is_empty(), "an unknown action is refused")
