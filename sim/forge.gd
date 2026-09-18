class_name DeepForge
extends RefCounted
## Where stones, dice and encounters come out of the rock.
##
## Everything here draws from one RNG handed in, so the same seed and the same depth give
## the same stone on every machine. Quality is `depth * 0.5 + mine quality + source bonus`,
## and it moves the distributions the way the design asks: Carat's mean rises, Cut leans
## toward Perfect, and Clarity's tails widen without moving its centre.

const DEFAULT_CLASS_WEIGHTS: Dictionary = {"PINPOINT": 10.0, "LENS": 6.0, "FEATHER": 4.0, "FRACTURE": 3.0, "STAR": 0.3}
const JACKPOT_PERCENT: float = 2.0

static func quality(depth: int, bonus: int = 0) -> float:
	return float(depth) * 0.5 + float(bonus)

static func roll_carat(rng: RandomNumberGenerator, q: float) -> int:
	var mean: float = 1.5 + q * 0.5
	var deviation: float = 1.6 + q * 0.08
	var carat: int = int(round(DeepRng.normal(rng, mean, deviation)))
	if DeepRng.chance(rng, JACKPOT_PERCENT):
		carat += rng.randi_range(3, 8)
	return clampi(carat, 1, DeepStone.carat_max())

static func roll_cut(rng: RandomNumberGenerator, q: float) -> int:
	var weights: Array = []
	var cuts: Array = DeepContent.cuts()
	for index in range(cuts.size()):
		var lean: float = 1.0 + q * 0.04 * float(index - 2)
		weights.append(float(cuts[index].get("weight", 1)) * maxf(0.1, lean))
	return maxi(0, DeepRng.weighted_index(rng, weights))

static func roll_clarity(rng: RandomNumberGenerator, q: float) -> int:
	var weights: Array = []
	var clarities: Array = DeepContent.clarities()
	var clear: int = DeepContent.clear_index()
	for index in range(clarities.size()):
		var distance: int = absi(index - clear)
		var widen: float = 1.0 + q * 0.02 * float(distance * distance)
		weights.append(float(clarities[index].get("weight", 1)) * widen)
	return maxi(0, DeepRng.weighted_index(rng, weights))

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
	var colour_weights: Dictionary = mine.get("colour_weights", {})
	var table: Dictionary = {}
	for key in keys:
		var skill: Dictionary = DeepContent.skill(str(key))
		if skill.is_empty():
			continue
		var weight: float = DeepContent.rarity_weight(str(skill.get("rarity", "COMMON")))
		weight *= float(colour_weights.get(str(skill.get("colour", "")), 100)) / 100.0
		table[str(key)] = weight
	return DeepRng.weighted_key(rng, table)

static func roll_inclusions(rng: RandomNumberGenerator, count: int, mine: Dictionary, forced_class: String = "") -> Array:
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
			var weight: float = float(def.get("weight", DEFAULT_CLASS_WEIGHTS.get(cls, 1.0)))
			table[str(key)] = weight
		var picked: String = DeepRng.weighted_key(rng, table)
		if picked.is_empty():
			break
		out.append(picked)
	return out

static func roll_stone(rng: RandomNumberGenerator, mine: Dictionary, depth: int, bonus: int = 0, provenance: Dictionary = {}, id: String = "") -> Dictionary:
	var q: float = quality(depth, int(mine.get("quality", 0)) + bonus)
	var skill: String = roll_skill(rng, mine)
	var carat: int = roll_carat(rng, q)
	var cut: int = roll_cut(rng, q)
	var clarity: int = roll_clarity(rng, q)
	var inclusions: Array = roll_inclusions(rng, DeepStone.inclusion_slots(clarity), mine)
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
	if DeepRng.chance(rng, 6.0 + quality(depth, int(mine.get("quality", 0))) * 0.5):
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
