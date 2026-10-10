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

static func quality(depth: int, bonus: float = 0.0) -> float:
	## Depth's share of luck, capped, plus everything else that has been added to it.
	return minf(float(depth) * LUCK_PER_DEPTH, LUCK_DEPTH_CAP) + bonus

static func mine_luck(mine: Dictionary) -> int:
	## What a mine is worth on its own. Older packs wrote it as `quality`.
	return int(mine.get("luck", mine.get("quality", 0)))

static func luck(mine: Dictionary, depth: int, bonus: float = 0.0) -> float:
	## The whole of it: where the party is, how deep, and what is handing the stone over.
	## `bonus` is a float because Sparkle is counted in fractions of a point.
	return quality(depth, float(mine_luck(mine)) + bonus)

## Each mine keeps its stones inside a band. Luck still raises the average, but the average
## levels off below the band's usual top, however much luck is piled on: past that line each
## further carat has only BAND_KEEP_PERCENT to hold, and nothing ever comes out over the cap.
## That is what keeps a full stack of Sparkle on an elite at the bottom of the Quarry from
## pulling a twelve-carat stone out of a mine that should give up nothing past seven.
const BAND_SPREAD: float = 1.2
const BAND_LUCK_SPAN: float = 8.0
const BAND_KEEP_PERCENT: float = 35.0

static func carat_band(mine: Dictionary, depth: int) -> Dictionary:
	## {soft, cap} for a mine at a depth, or {} for a mine that writes no band. An endless
	## mine's band climbs a carat with every Warden it has stationed above this depth.
	var band: Dictionary = mine.get("carat", {})
	if band.is_empty():
		return {}
	var soft: int = int(band.get("soft", DeepStone.carat_max()))
	var cap: int = int(band.get("cap", DeepStone.carat_max()))
	if bool(mine.get("endless", false)):
		var every: int = maxi(1, int(mine.get("warden_every", 8)))
		var climbed: int = maxi(0, depth - 1) / every * int(mine.get("carat_per_warden", 0))
		soft += climbed
		cap += climbed
	cap = clampi(cap, 1, DeepStone.carat_max())
	return {"soft": clampi(soft, 1, cap), "cap": cap}

static func carat_cap(mine: Dictionary, depth: int) -> int:
	## The heaviest stone this mine will ever give up at this depth.
	return int(carat_band(mine, depth).get("cap", DeepStone.carat_max()))

static func roll_carat(rng: RandomNumberGenerator, q: float, band: Dictionary = {}) -> int:
	if band.is_empty():
		var mean: float = maxf(1.0, 1.5 + q * 0.5)
		var deviation: float = maxf(1.0, 1.6 + q * 0.08)
		var carat: int = int(round(DeepRng.normal(rng, mean, deviation)))
		if DeepRng.chance(rng, JACKPOT_PERCENT):
			carat += rng.randi_range(1, 2)
		return clampi(carat, 1, DeepStone.carat_max())
	var soft: int = int(band.soft)
	var cap: int = int(band.cap)
	var top: float = maxf(1.5, float(soft) - 0.5)
	var banded_mean: float = 1.5 + (top - 1.5) * (1.0 - exp(-maxf(q, 0.0) / BAND_LUCK_SPAN))
	var drawn: int = int(round(DeepRng.normal(rng, banded_mean, BAND_SPREAD)))
	if DeepRng.chance(rng, JACKPOT_PERCENT):
		drawn += rng.randi_range(1, 2)
	if drawn > soft:
		var held: int = soft
		while held < drawn and DeepRng.chance(rng, BAND_KEEP_PERCENT):
			held += 1
		drawn = held
	return clampi(drawn, 1, cap)

static func roll_cut(rng: RandomNumberGenerator, q: float, without: int = -1) -> int:
	## Poor and Fair near the surface, Fine and Perfect further down: the ladder tilts about
	## its middle rung, so a bad-luck roll is as much worse as a good-luck one is better.
	## `without` strikes one rung off the table: a stone put back on a wheel is being worked
	## on, and work that gives back exactly what it took is not work.
	var weights: Array = []
	var cuts: Array = DeepContent.cuts()
	for index in range(cuts.size()):
		var lean: float = 1.0 + q * 0.06 * float(index - 2)
		weights.append(0.0 if index == without else float(cuts[index].get("weight", 1)) * maxf(0.08, lean))
	return maxi(0, DeepRng.weighted_index(rng, weights))

static func roll_clarity(rng: RandomNumberGenerator, q: float, without: int = -1) -> int:
	## Clear near the surface, and both ends of the ladder further down: Pristine and
	## Flawless one way, Etched and Intricate the other, all four of them high rolls.
	## `without` strikes one rung off the table, the way `roll_cut` does.
	var weights: Array = []
	var clarities: Array = DeepContent.clarities()
	var clear: int = DeepContent.clear_index()
	for index in range(clarities.size()):
		var distance: int = absi(index - clear)
		var widen: float = 1.0 + q * 0.025 * float(distance * distance)
		weights.append(0.0 if index == without else float(clarities[index].get("weight", 1)) * maxf(0.06, widen))
	return maxi(0, DeepRng.weighted_index(rng, weights))

static func reroll_cut(rng: RandomNumberGenerator, stone: Dictionary, mine: Dictionary, depth: int, bonus: float = 0.0) -> int:
	## The stone goes back to the wheel and comes off it cut again: a fresh draw from the
	## table this stage rolls on, better or worse, never a step up for the asking. Nothing
	## anywhere may raise a Cut on purpose — that is what would make a stone farmable. The
	## rung it went on at is struck off the table, so an hour at the wheel always shows.
	stone.cut = roll_cut(rng, luck(mine, depth, bonus), int(stone.get("cut", -1)))
	return int(stone.cut)

static func reroll_clarity(rng: RandomNumberGenerator, stone: Dictionary, mine: Dictionary, depth: int, bonus: float = 0.0) -> Dictionary:
	## The same for Clarity, and because clarity is what a stone carries frozen inside it,
	## whatever is in there is drawn again too. Returns {clarity, inclusions, was, had}.
	var was: int = int(stone.get("clarity", 0))
	var had: Array = stone.get("inclusions", []).duplicate()
	stone.clarity = roll_clarity(rng, luck(mine, depth, bonus), was)
	stone.inclusions = roll_inclusions(rng, DeepStone.inclusion_slots(int(stone.clarity)), mine, "", DeepStone.color(stone))
	stone.inclusions_revealed = true
	return {"clarity": int(stone.clarity), "inclusions": stone.inclusions.duplicate(), "was": was, "had": had}

static func clarity_side(clarity: int) -> int:
	## Which way off Clear a stone leans: -1 toward Intricate, +1 toward Flawless, 0 at Clear.
	return signi(clarity - DeepContent.clear_index())

static func step_clarity(rng: RandomNumberGenerator, stone: Dictionary, mine: Dictionary, steps: int = 1, up: int = 0) -> Dictionary:
	## Clarity driven `steps` rungs further from Clear along the side it already leans (a Clear
	## stone takes the side `up` names, or Pristine's when it names none), and whatever the
	## new clarity has room for frozen inside it. What was already in there is kept as far as
	## the slots allow. Returns {clarity, was, inclusions, had, moved}.
	var was: int = int(stone.get("clarity", DeepContent.clear_index()))
	var had: Array = stone.get("inclusions", []).duplicate()
	var side: int = clarity_side(was)
	if side == 0:
		side = 1 if up >= 0 else -1
	var top: int = DeepContent.clarities().size() - 1
	var now: int = clampi(was + side * maxi(1, steps), 0, top)
	stone.clarity = now
	var slots: int = DeepStone.inclusion_slots(now)
	var kept: Array = had.slice(0, slots)
	if kept.size() < slots:
		for key in roll_inclusions(rng, slots - kept.size(), mine, "", DeepStone.color(stone)):
			if not kept.has(str(key)):
				kept.append(str(key))
	stone.inclusions = kept
	stone.inclusions_revealed = true
	return {"clarity": now, "was": was, "inclusions": kept.duplicate(), "had": had, "moved": now != was}

## A mine's own batch of skills comes out of its rock this many times as often as the
## batches of the mines above it, so a new mine is where its new stones are found.
const HOME_BATCH_WEIGHT: float = 2.0

static func skill_pool(mine: Dictionary) -> Array:
	## What the rock here can hold: a list the mine writes out in full, or else its own batch
	## and the batches of every mine above it. A skill no mine has taken into its batch is in
	## every pool, so nothing new is ever unfindable while it waits to be placed.
	## A Transcendent is in no pool at all: it is made at an altar, never found.
	var listed: Array = mine.get("skills", [])
	if not listed.is_empty():
		return listed.map(func(k: Variant) -> String: return str(k)).filter(func(k: String) -> bool: return not DeepContent.is_transcendent(k))
	var keys: Array = DeepContent.section("skills").keys().filter(func(k: Variant) -> bool: return not DeepContent.is_transcendent(str(k)))
	keys.sort()
	var batched: Dictionary = batch_tiers()
	if batched.is_empty():
		return keys
	var tier: int = int(mine.get("tier", 1))
	return keys.filter(func(k: Variant) -> bool: return not batched.has(str(k)) or int(batched[str(k)]) <= tier)

static func batch_tiers() -> Dictionary:
	## skill -> the tier of the mine whose batch it is in.
	var out: Dictionary = {}
	for key in DeepContent.section("mines"):
		var def: Dictionary = DeepContent.mine(str(key))
		for skill in def.get("batch", []):
			out[str(skill)] = int(def.get("tier", 1))
	return out

static func home_batch(mine: Dictionary) -> Array:
	return mine.get("batch", [])

static func inclusion_pool(mine: Dictionary) -> Array:
	var listed: Array = mine.get("inclusions", [])
	if not listed.is_empty():
		return listed.map(func(k: Variant) -> String: return str(k))
	var keys: Array = DeepContent.section("inclusions").keys()
	keys.sort()
	return keys

static func roll_skill(rng: RandomNumberGenerator, mine: Dictionary, pool: Array = []) -> String:
	return DeepRng.weighted_key(rng, skill_table(mine, pool))

static func skill_table(mine: Dictionary, pool: Array = []) -> Dictionary:
	## How likely each skill is to come out of this rock: its rarity, the mine's leaning toward
	## its color, and twice as likely again in the mine whose own batch it is. What `roll_skill`
	## draws from, and what a Geode prints as its odds.
	var keys: Array = pool if not pool.is_empty() else skill_pool(mine)
	var color_weights: Dictionary = mine.get("color_weights", {})
	var home: Array = home_batch(mine)
	var table: Dictionary = {}
	for key in keys:
		var skill: Dictionary = DeepContent.skill(str(key))
		if skill.is_empty():
			continue
		var weight: float = DeepContent.rarity_weight(str(skill.get("rarity", "COMMON")))
		weight *= float(color_weights.get(str(skill.get("color", "")), 100)) / 100.0
		if home.has(str(key)):
			weight *= HOME_BATCH_WEIGHT
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
	return table

static func opal_pool() -> Array:
	## Every opal in the pack, sorted, so the same seed reaches for the same one. The two
	## Transcendent opals are not among them: nothing reaches for one, not even a hoard.
	var out: Array = []
	for key in DeepContent.section("skills"):
		if str(DeepContent.skill(str(key)).get("color", "")) == DeepContent.OPAL and not DeepContent.is_transcendent(str(key)):
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
			weight *= float(mine.get("inclusion_bias", {}).get(str(key), 1.0))
			table[str(key)] = weight
		var picked: String = DeepRng.weighted_key(rng, table)
		if picked.is_empty():
			break
		out.append(picked)
	return out

static func roll_stone(rng: RandomNumberGenerator, mine: Dictionary, depth: int, bonus: float = 0.0, provenance: Dictionary = {}, id: String = "", pool: Array = []) -> Dictionary:
	## `pool` narrows which skills may come out of the rock. Everything else about the
	## stone — its carat, its cut, its clarity, what is frozen inside it — is rolled the
	## way it always is, which is what makes an opal from a hoard a real gamble.
	var q: float = luck(mine, depth, bonus)
	var skill: String = roll_skill(rng, mine, pool)
	var carat: int = roll_carat(rng, q, carat_band(mine, depth))
	var cut: int = roll_cut(rng, q)
	var clarity: int = roll_clarity(rng, q)
	## A daily dig's rock may keep every stone clear, or give none that are.
	match str(mine.get("clarity_rule", "")):
		"clear":
			clarity = maxi(clarity, DeepContent.clear_index())
		"flawed":
			clarity = mini(clarity, DeepContent.clear_index() - 1)
	var inclusions: Array = roll_inclusions(rng, DeepStone.inclusion_slots(clarity), mine, "", str(DeepContent.skill(skill).get("color", "")))
	var where: Dictionary = provenance.duplicate()
	where.depth = depth
	if not where.has("mine"):
		where.mine = str(mine.get("key", mine.get("name", "")))
	var stone_id: String = id if not id.is_empty() else "st%08x" % rng.randi()
	var made: Dictionary = DeepStone.make(skill, carat, cut, clarity, inclusions, where, stone_id)
	if bool(mine.get("read_on_find", false)):
		made.appraised = true
		made.inclusions_revealed = true
	return made

static func die_from(ref: Variant, id: String) -> Dictionary:
	## The die a character or a creature is written down as: a shape on its own ("D6"), or
	## an object carrying the variations it was born with. This is also what a broken die
	## grows back as, so it must never depend on the run.
	if ref is Dictionary:
		var shape: String = str(ref.get("shape", "D6"))
		return DeepDice.make(shape, id, {"pattern": str(ref.get("pattern", "")), "material": str(ref.get("material", "")),
			"etches": ref.get("etches", []), "name": str(ref.get("name", "")), "top": int(ref.get("top", 0))})
	return DeepDice.make(str(ref), id)

# --- dice out of the rock -----------------------------------------------------------------
##
## A die is a shape and up to three variations: a pattern, an etching or two, and a
## material. Nothing is offered that the shape cannot take, and the rarer the variation the
## less often the rock gives it up. Luck makes a second variation likelier.

## How often a die carries one variation rather than two. It never carries none, and it
## never carries all three.
const ONE_AXIS_PERCENT: float = 60.0
const AXIS_WEIGHTS: Dictionary = {"pattern": 45.0, "etching": 35.0, "material": 20.0}
## What each variation does to the price of a die. An etching nobody wants takes money off.
const PATTERN_MULT: float = 1.25
const ETCH_MULT: float = 1.5
const BANE_MULT: float = 0.6
const MATERIAL_MULT: float = 2.0
const PATTERN_PRICE: Dictionary = {"stretched": 1.4}
const MATERIAL_PRICE: Dictionary = {"glass": 1.75, "opal": 3.0}

static func _rarity_table(section: String, allow: Callable = Callable()) -> Dictionary:
	var table: Dictionary = {}
	for key in DeepContent.section(section):
		var def: Dictionary = DeepContent.entry(section, str(key))
		var written: String = str(def.get("key", ""))
		if written.is_empty() or (allow.is_valid() and not allow.call(written, def)):
			continue
		table[written] = DeepContent.rarity_weight(str(def.get("rarity", "COMMON")))
	return table

static func roll_pattern(rng: RandomNumberGenerator, shape: String) -> String:
	var table: Dictionary = _rarity_table("patterns", func(key: String, _def: Dictionary) -> bool:
		return DeepDice.pattern_allows(key, shape))
	return DeepRng.weighted_key(rng, table) if not table.is_empty() else ""

static func roll_etching(rng: RandomNumberGenerator, bane: bool = false) -> String:
	var table: Dictionary = _rarity_table("etchings", func(_key: String, def: Dictionary) -> bool:
		return bool(def.get("bane", false)) == bane)
	return DeepRng.weighted_key(rng, table) if not table.is_empty() else ""

static func roll_material(rng: RandomNumberGenerator) -> String:
	var table: Dictionary = _rarity_table("materials")
	return DeepRng.weighted_key(rng, table) if not table.is_empty() else ""

static func vary(die: Dictionary, axes: Array, rng: RandomNumberGenerator) -> Dictionary:
	## Cut the named variations into a die that is already made.
	for axis in axes:
		match str(axis):
			"pattern":
				var pattern: String = roll_pattern(rng, str(die.get("shape", "D6")))
				if not pattern.is_empty():
					var made: Dictionary = DeepDice.make(str(die.shape), str(die.id), {"pattern": pattern, "rng": rng,
						"material": str(die.get("material", "")), "etches": DeepDice.etchings(die)})
					die.clear()
					die.merge(made)
			"etching":
				var kind: String = roll_etching(rng)
				if not kind.is_empty() and not die.get("faces", []).is_empty():
					DeepDice.etch(die, rng.randi_range(0, die.faces.size() - 1), kind)
			"material":
				die.material = roll_material(rng)
	return die

static func roll_axes(rng: RandomNumberGenerator) -> Array:
	## One variation or two, never none and never all three.
	var wanted: int = 1 if DeepRng.chance(rng, ONE_AXIS_PERCENT) else 2
	var table: Dictionary = AXIS_WEIGHTS.duplicate()
	var picked: Array = []
	while picked.size() < wanted and not table.is_empty():
		var axis: String = DeepRng.weighted_key(rng, table)
		picked.append(axis)
		table.erase(axis)
	return picked

static func shape_pool(mine: Dictionary) -> Array:
	var pool: Array = mine.get("dice", []).filter(func(k: Variant) -> bool: return DeepDice.SHAPES.has(str(k)))
	if pool.is_empty():
		pool = DeepDice.TIERS.duplicate()
	return pool

static func roll_die(rng: RandomNumberGenerator, mine: Dictionary, depth: int, id: String = "", shapes: Array = []) -> Dictionary:
	## A die out of the rock. `shapes` narrows it to the sizes somebody already carries: a
	## die is never offered in a size its finder has no use for.
	var pool: Array = shapes.filter(func(k: Variant) -> bool: return DeepDice.SHAPES.has(str(k)))
	if pool.is_empty():
		pool = shape_pool(mine)
	var table: Dictionary = {}
	for key in pool:
		var def: Dictionary = DeepContent.die(str(key))
		table[str(key)] = DeepContent.rarity_weight(str(def.get("rarity", "COMMON"))) if not def.is_empty() else 1.0
	var shape: String = DeepRng.weighted_key(rng, table)
	var die_id: String = id if not id.is_empty() else "die%08x" % rng.randi()
	var die: Dictionary = DeepDice.make(shape, die_id, {"rng": rng})
	var axes: Array = roll_axes(rng)
	## Deeper down, a die is likelier to carry a second thing worth carrying.
	if axes.size() == 1 and DeepRng.chance(rng, luck(mine, depth)):
		for extra in roll_axes(rng):
			if not axes.has(extra):
				axes.append(extra)
				break
	return vary(die, axes, rng)

static func die_price(die: Dictionary) -> int:
	## What a die is worth at a stall: its size, then what has been done to it. A pattern
	## costs a little, an etching more, a material doubles it.
	var base: float = float(DeepContent.die(str(die.get("shape", "D6"))).get("price", 10))
	var pattern: String = str(die.get("pattern", ""))
	if not pattern.is_empty():
		base *= float(PATTERN_PRICE.get(pattern, PATTERN_MULT))
	for entry in DeepDice.etchings(die):
		base *= BANE_MULT if str(entry.kind) in DeepDice.BANE_FACES else ETCH_MULT
	var material: String = str(die.get("material", ""))
	if not material.is_empty():
		base *= float(MATERIAL_PRICE.get(material, MATERIAL_MULT))
	return maxi(1, int(round(base)))

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
