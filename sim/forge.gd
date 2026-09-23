class_name DeepForge
extends RefCounted
## Where stones, dice and encounters come out of the rock.
##
## Everything here draws from one RNG handed in, so the same seed and the same depth give
## the same stone on every machine.
##
## Luck is the one number every distribution reads: how kindly the rock is rolling right
## now. It is the mine the party is in, plus how far down it they have gone (up to a cap, so
## the bottom of a stretch is not worth more than the mine below it), plus whatever the
## thing handing out the stone is worth. The Quarry rolls a little below the pack's written
## weights; every mine under it rolls further above them. Luck moves the distributions the
## way the design asks: Carat's mean rises, Cut leans toward Perfect, and Clarity's tails
## widen without moving its centre — both tails, because an Intricate stone is as much a
## prize as a Flawless one and both should be rare near the surface.

const DEFAULT_CLASS_WEIGHTS: Dictionary = {"PINPOINT": 10.0, "LENS": 6.0, "FEATHER": 4.0, "FRACTURE": 3.0, "STAR": 0.3}
const JACKPOT_PERCENT: float = 2.0
## What one depth is worth, and how much of a mine's depth counts at all.
const LUCK_PER_DEPTH: float = 0.5
const LUCK_DEPTH_CAP: float = 10.0

static func quality(depth: int, bonus: int = 0) -> float:
	## Depth's share of luck, capped, plus everything else that has been added to it.
	return minf(float(depth) * LUCK_PER_DEPTH, LUCK_DEPTH_CAP) + float(bonus)

static func mine_luck(mine: Dictionary) -> int:
	## What a mine is worth on its own. Older packs wrote it as `quality`.
	return int(mine.get("luck", mine.get("quality", 0)))

static func luck(mine: Dictionary, depth: int, bonus: int = 0) -> float:
	## The whole of it: where the party is, how deep, and what is handing the stone over.
	return quality(depth, mine_luck(mine) + bonus)

static func roll_carat(rng: RandomNumberGenerator, q: float) -> int:
	var mean: float = maxf(1.0, 1.5 + q * 0.5)
	var deviation: float = maxf(1.0, 1.6 + q * 0.08)
	var carat: int = int(round(DeepRng.normal(rng, mean, deviation)))
	if DeepRng.chance(rng, JACKPOT_PERCENT):
		carat += rng.randi_range(3, 8)
	return clampi(carat, 1, DeepStone.carat_max())

static func roll_cut(rng: RandomNumberGenerator, q: float) -> int:
	## Poor and Fair near the surface, Fine and Perfect further down: the ladder tilts about
	## its middle rung, so a bad-luck roll is as much worse as a good-luck one is better.
	var weights: Array = []
	var cuts: Array = DeepContent.cuts()
	for index in range(cuts.size()):
		var lean: float = 1.0 + q * 0.06 * float(index - 2)
		weights.append(float(cuts[index].get("weight", 1)) * maxf(0.08, lean))
	return maxi(0, DeepRng.weighted_index(rng, weights))

static func roll_clarity(rng: RandomNumberGenerator, q: float) -> int:
	## Clear near the surface, and both ends of the ladder further down: Pristine and
	## Flawless one way, Etched and Intricate the other, all four of them high rolls.
	var weights: Array = []
	var clarities: Array = DeepContent.clarities()
	var clear: int = DeepContent.clear_index()
	for index in range(clarities.size()):
		var distance: int = absi(index - clear)
		var widen: float = 1.0 + q * 0.025 * float(distance * distance)
		weights.append(float(clarities[index].get("weight", 1)) * maxf(0.06, widen))
	return maxi(0, DeepRng.weighted_index(rng, weights))

static func reroll_cut(rng: RandomNumberGenerator, stone: Dictionary, mine: Dictionary, depth: int, bonus: int = 0) -> int:
	## The stone goes back to the wheel and comes off it cut again: a fresh draw from the
	## table this stage rolls on, better or worse, never a step up for the asking. Nothing
	## anywhere may raise a Cut on purpose — that is what would make a stone farmable.
	stone.cut = roll_cut(rng, luck(mine, depth, bonus))
	return int(stone.cut)

static func reroll_clarity(rng: RandomNumberGenerator, stone: Dictionary, mine: Dictionary, depth: int, bonus: int = 0) -> Dictionary:
	## The same for Clarity, and because clarity is what a stone carries frozen inside it,
	## whatever is in there is drawn again too. Returns {clarity, inclusions, was, had}.
	var was: int = int(stone.get("clarity", 0))
	var had: Array = stone.get("inclusions", []).duplicate()
	stone.clarity = roll_clarity(rng, luck(mine, depth, bonus))
	stone.inclusions = roll_inclusions(rng, DeepStone.inclusion_slots(int(stone.clarity)), mine, "", DeepStone.color(stone))
	stone.inclusions_revealed = true
	return {"clarity": int(stone.clarity), "inclusions": stone.inclusions.duplicate(), "was": was, "had": had}

static func skill_pool(mine: Dictionary) -> Array:
	var listed: Array = mine.get("skills", [])
	if not listed.is_empty():
		return listed.map(func(k: Variant) -> String: return str(k))
	var keys: Array = DeepContent.section("skills").keys()
	keys.sort()
	return keys

static func inclusion_pool(mine: Dictionary) -> Array:
	var listed: Array = mine.get("inclusions", [])
	if not listed.is_empty():
		return listed.map(func(k: Variant) -> String: return str(k))
	var keys: Array = DeepContent.section("inclusions").keys()
	keys.sort()
	return keys

static func roll_skill(rng: RandomNumberGenerator, mine: Dictionary, pool: Array = []) -> String:
	var keys: Array = pool if not pool.is_empty() else skill_pool(mine)
	var color_weights: Dictionary = mine.get("color_weights", {})
	var table: Dictionary = {}
	for key in keys:
		var skill: Dictionary = DeepContent.skill(str(key))
		if skill.is_empty():
			continue
		var weight: float = DeepContent.rarity_weight(str(skill.get("rarity", "COMMON")))
		weight *= float(color_weights.get(str(skill.get("color", "")), 100)) / 100.0
		table[str(key)] = weight
	## A pool the rock never offers is still a pool once something asks for it by name: an
	## opal weighs nothing at all in the ordinary table, which is how it stays out of every
	## vein and every drop, and a hoard reaching for one would otherwise come back empty.
	var total: float = 0.0
	for key in table:
		total += float(table[key])
	if total <= 0.0:
		for key in table:
			table[key] = 1.0
	return DeepRng.weighted_key(rng, table)

static func opal_pool() -> Array:
	## Every opal in the pack, sorted, so the same seed reaches for the same one.
	var out: Array = []
	for key in DeepContent.section("skills"):
		if str(DeepContent.skill(str(key)).get("color", "")) == DeepContent.OPAL:
			out.append(str(key))
	out.sort()
	return out

static func zoning_color(def: Dictionary) -> String:
	## The color a Zoning lens lends a stone, or "" for an inclusion that lends none.
	for m in def.get("modifiers", []):
		if m is Dictionary and str(m.get("kind", "")) == "color_also":
			return str(m.get("color", ""))
	return ""

static func roll_inclusions(rng: RandomNumberGenerator, count: int, mine: Dictionary, forced_class: String = "", own_color: String = "") -> Array:
	## `own_color` is the color of the stone these are forming in, and the rock never grows a
	## Zoning of a stone's own color in it: "counts as Red as well as its own color" says
	## nothing at all on a red stone, and a dead inclusion in a slot is worse than none.
	var out: Array = []
	var pool: Array = inclusion_pool(mine)
	for _slot in range(count):
		var table: Dictionary = {}
		for key in pool:
			if out.has(str(key)):
				continue
			var def: Dictionary = DeepContent.inclusion(str(key))
			if def.is_empty():
				continue
			var cls: String = str(def.get("class", "PINPOINT"))
			if not forced_class.is_empty() and cls != forced_class:
				continue
			if not own_color.is_empty() and zoning_color(def) == own_color:
				continue
			var weight: float = float(def.get("weight", DEFAULT_CLASS_WEIGHTS.get(cls, 1.0)))
			table[str(key)] = weight
		var picked: String = DeepRng.weighted_key(rng, table)
		if picked.is_empty():
			break
		out.append(picked)
	return out

static func roll_stone(rng: RandomNumberGenerator, mine: Dictionary, depth: int, bonus: int = 0, provenance: Dictionary = {}, id: String = "", pool: Array = []) -> Dictionary:
	## `pool` narrows which skills may come out of the rock. Everything else about the
	## stone — its carat, its cut, its clarity, what is frozen inside it — is rolled the
	## way it always is, which is what makes an opal from a hoard a real gamble.
	var q: float = luck(mine, depth, bonus)
	var skill: String = roll_skill(rng, mine, pool)
	var carat: int = roll_carat(rng, q)
	var cut: int = roll_cut(rng, q)
	var clarity: int = roll_clarity(rng, q)
	var inclusions: Array = roll_inclusions(rng, DeepStone.inclusion_slots(clarity), mine, "", str(DeepContent.skill(skill).get("color", "")))
	var where: Dictionary = provenance.duplicate()
	where.depth = depth
	if not where.has("mine"):
		where.mine = str(mine.get("key", mine.get("name", "")))
	var stone_id: String = id if not id.is_empty() else "st%08x" % rng.randi()
	return DeepStone.make(skill, carat, cut, clarity, inclusions, where, stone_id)

static func roll_die(rng: RandomNumberGenerator, mine: Dictionary, depth: int, id: String = "") -> Dictionary:
	var pool: Array = mine.get("dice", [])
	if pool.is_empty():
		pool = DeepContent.section("dice").keys()
		pool.sort()
	var table: Dictionary = {}
	for key in pool:
		var def: Dictionary = DeepContent.die(str(key))
		if not def.is_empty():
			table[str(key)] = DeepContent.rarity_weight(str(def.get("rarity", "COMMON")))
	var key: String = DeepRng.weighted_key(rng, table)
	var engraving: String = ""
	if DeepRng.chance(rng, 6.0 + luck(mine, depth) * 0.5):
		var engravings: Array = DeepContent.section("engravings").keys()
		engravings.sort()
		if not engravings.is_empty():
			engraving = str(DeepContent.engraving(str(DeepRng.pick(rng, engravings))).get("key", ""))
	var die_id: String = id if not id.is_empty() else "die%08x" % rng.randi()
	return DeepDice.make(key, DeepContent.die(key), die_id, engraving)

static func band_for(mine: Dictionary, depth: int) -> Dictionary:
	var chosen: Dictionary = {}
	for band in mine.get("bands", []):
		if int(band.get("from_depth", 1)) <= depth:
			chosen = band
	if chosen.is_empty() and not mine.get("bands", []).is_empty():
		chosen = mine.bands[0]
	return chosen

static func encounter(rng: RandomNumberGenerator, mine: Dictionary, depth: int, party: int, elite: bool = false) -> Array:
	## Creature keys for a fight, bought against a threat budget that grows with depth and
	## with the size of the party. An elite fight has half again the budget.
	var band: Dictionary = band_for(mine, depth)
	var table: Dictionary = {}
	for key in band.get("creatures", {}):
		table[str(key)] = float(band.creatures[key])
	if table.is_empty():
		return []
	var budget: float = (3.0 + float(depth) * 0.6) * (0.55 + 0.45 * float(clampi(party, 1, 4)))
	if elite:
		budget *= 1.5
	var most: int = 2 + clampi(party, 1, 4)
	var picked: Array = []
	var guard: int = 0
	while picked.size() < most and guard < 20:
		guard += 1
		var key: String = DeepRng.weighted_key(rng, table)
		var threat: float = float(DeepContent.creature(key).get("threat", 1))
		if picked.is_empty() or threat <= budget:
			picked.append(key)
			budget -= threat
		else:
			break
	return picked
