class_name DeepAltar
extends RefCounted
## The altar: five gems given up on a pentagram for one that is better than any of them.
##
## What the five make is decided here and nowhere else, and nothing a player can read says
## how. The circle lights for a set it knows and stays cold for anything else; the rules are
## tried in order and the first that fits wins:
##
##   1. Five named gems, the recipe a Transcendent lists as `altar.from` (five distinct skills
##      out of that list): that Transcendent. Rainbow Seam's list is the six Seams.
##   2. Five gems of one of the six colors, repeats allowed: that color's Seam.
##   3. Five gems of five different colors, Opal counting as one: an opal drawn at random from
##      the ordinary ones. Never a Transcendent.
##
## The new gem's Carat, Cut and Clarity are the averages of the five, each raised by a random
## share (constant `altar_raise_pct`, 20 to 30) and then nudged: Carat by up to
## `altar_carat_nudge` either way, Cut and Clarity a grade up or down `altar_nudge_pct` of the
## time. Cut and Clarity are averaged as grades counted from one, so a Poor gem pulls the
## average down rather than counting for nothing. Its inclusion slots are filled first from
## what the five carried, then from the rock. Every roll comes from the RNG it is handed.

const SOCKETS: int = 5

static func refusal(stone: Dictionary) -> String:
	## Why this stone can never go on an altar, or "" when it can.
	if stone.is_empty():
		return "there is no such stone"
	if not bool(stone.get("appraised", false)):
		return "a stone still in its rock has to be read first"
	if DeepStone.is_birthstone(stone):
		return "a Birthstone is never given up"
	if bool(stone.get("temporary", false)):
		return "a temporary stone is only lent for the run"
	if DeepStone.is_transcendent(stone):
		return "a Transcendent is never given up"
	if DeepStone.is_locked(stone):
		return "it cannot leave its socket"
	return ""

static func recipe_for(stones: Array) -> Dictionary:
	## What five stones make: {kind: "transcendent" | "seam" | "opal", skill} with an empty
	## skill for an opal still to be drawn, or {} when the circle stays cold.
	if stones.size() != SOCKETS:
		return {}
	var skills: Array = []
	var colors: Array = []
	for stone in stones:
		if not stone is Dictionary or not refusal(stone).is_empty():
			return {}
		skills.append(str(stone.get("skill", "")))
		colors.append(DeepStone.color(stone))
	for key in DeepContent.transcendents():
		if _distinct_within(skills, DeepContent.skill(key).get("altar", {}).get("from", [])):
			return {"kind": "transcendent", "skill": key}
	var first: String = str(colors[0])
	if first in DeepContent.color_KEYS and colors.all(func(c: Variant) -> bool: return str(c) == first):
		var seam: String = "SEAM_" + first
		if DeepContent.section("skills").has(seam):
			return {"kind": "seam", "skill": seam}
	var distinct: Array = []
	for c in colors:
		if not distinct.has(c):
			distinct.append(c)
	if distinct.size() == SOCKETS and not DeepForge.opal_pool().is_empty():
		return {"kind": "opal", "skill": ""}
	return {}

static func _distinct_within(skills: Array, from: Array) -> bool:
	## Five different skills, every one of them on the list.
	var seen: Array = []
	for key in skills:
		if seen.has(key) or not from.has(key):
			return false
		seen.append(key)
	return true

static func lit(stones: Array) -> bool:
	return not recipe_for(stones).is_empty()

static func make(rng: RandomNumberGenerator, stones: Array, recipe: Dictionary, mine: Dictionary, provenance: Dictionary, id: String) -> Dictionary:
	## The gem the circle gives back for these five. Pure but for the rolls.
	var skill: String = str(recipe.get("skill", ""))
	if skill.is_empty():
		skill = str(DeepRng.pick(rng, DeepForge.opal_pool()))
	var carats: Array = []
	var cuts: Array = []
	var clarities: Array = []
	for stone in stones:
		carats.append(float(int(stone.get("carat", 1))))
		cuts.append(float(int(stone.get("cut", 0)) + 1))
		clarities.append(float(int(stone.get("clarity", 0)) + 1))
	var nudge: int = int(DeepContent.constant("altar_carat_nudge", 1))
	var carat: int = clampi(roundi(_mean(carats) * _raise(rng)) + rng.randi_range(-nudge, nudge), 1, DeepStone.carat_max())
	var cut: int = clampi(roundi(_mean(cuts) * _raise(rng)) + _step(rng), 1, DeepPatterns.STEPS) - 1
	var clarity: int = clampi(roundi(_mean(clarities) * _raise(rng)) + _step(rng), 1, DeepContent.clarities().size()) - 1
	var def: Dictionary = DeepContent.skill(skill)
	var own: Array = [str(def.get("color", ""))]
	for c in def.get("colors", []):
		if not own.has(str(c)):
			own.append(str(c))
	var inclusions: Array = inherited(rng, stones, DeepStone.inclusion_slots(clarity), own)
	var missing: int = DeepStone.inclusion_slots(clarity) - inclusions.size()
	if missing > 0:
		for key in DeepForge.roll_inclusions(rng, missing + own.size(), mine, "", str(own[0])):
			if inclusions.size() >= DeepStone.inclusion_slots(clarity):
				break
			if not inclusions.has(str(key)) and not own.has(DeepForge.zoning_color(DeepContent.inclusion(str(key)))):
				inclusions.append(str(key))
	var where: Dictionary = provenance.duplicate()
	where.source = "altar"
	var made: Dictionary = DeepStone.make(skill, carat, cut, clarity, inclusions, where, id)
	made.appraised = true
	made.inclusions_revealed = true
	return made

static func inherited(rng: RandomNumberGenerator, stones: Array, slots: int, own_colors: Array) -> Array:
	## Inclusions the new gem keeps from the five it was made of, drawn at random from all they
	## carried. A Zoning of a color the new gem already is would say nothing, so it is left.
	var carried: Array = []
	for stone in stones:
		for key in stone.get("inclusions", []):
			var zone: String = DeepForge.zoning_color(DeepContent.inclusion(str(key)))
			if not carried.has(str(key)) and not own_colors.has(zone):
				carried.append(str(key))
	carried.sort()
	var out: Array = []
	while out.size() < slots and not carried.is_empty():
		var drawn: String = str(carried[rng.randi_range(0, carried.size() - 1)])
		carried.erase(drawn)
		out.append(drawn)
	return out

static func _mean(values: Array) -> float:
	var total: float = 0.0
	for v in values:
		total += float(v)
	return total / float(maxi(1, values.size()))

static func _raise(rng: RandomNumberGenerator) -> float:
	## How much better than the average the new gem comes out: a random share in the range.
	var band: Variant = DeepContent.constant("altar_raise_pct", [20, 30])
	var low: float = float(band[0]) if band is Array and band.size() > 1 else 20.0
	var high: float = float(band[1]) if band is Array and band.size() > 1 else 30.0
	return 1.0 + rng.randf_range(low, high) / 100.0

static func _step(rng: RandomNumberGenerator) -> int:
	## A grade either way now and then, so two altars fed the same five do not always agree.
	if not DeepRng.chance(rng, float(DeepContent.constant("altar_nudge_pct", 17))):
		return 0
	return 1 if rng.randf() < 0.5 else -1
