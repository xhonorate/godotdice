class_name DeepStone
extends RefCounted
## A stone: one instance of a skill with its four C's, its inclusions and its history.
##
##   {id, skill, carat, cut, clarity, inclusions: [keys], appraised, inclusions_revealed,
##    provenance: {mine, depth, run, date}, favourite}
##
## Cut is an index 0..4 (Poor to Perfect) and clarity an index into the pack's clarity
## ladder (Riddled to Flawless). Colour is never stored: it is the skill's, plus whatever
## an inclusion adds. `evaluate()` is the whole of what a stone does to a hand, used by the
## battle, the forecast and the tests alike.

const COLOURS: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]
const TIERS: Array = ["ROUGH", "FINE", "PRECIOUS", "EXQUISITE", "PEERLESS"]
const TIER_NAMES: Dictionary = {"ROUGH": "Rough", "FINE": "Fine", "PRECIOUS": "Precious", "EXQUISITE": "Exquisite", "PEERLESS": "Peerless"}
const INCLUSION_SCORE: Dictionary = {"COMMON": 2.0, "UNCOMMON": 4.0, "RARE": 7.0, "LEGENDARY": 15.0}
const RARITY_VALUE: Dictionary = {"COMMON": 1.0, "UNCOMMON": 1.5, "RARE": 2.5, "LEGENDARY": 4.0}

static func make(skill: String, carat: int, cut: int, clarity: int, inclusions: Array = [], provenance: Dictionary = {}, id: String = "") -> Dictionary:
	return {"id": id, "skill": skill, "carat": carat, "cut": cut, "clarity": clarity, "inclusions": inclusions.duplicate(),
		"appraised": false, "inclusions_revealed": false, "provenance": provenance.duplicate(), "favourite": false}

static func skill_of(stone: Dictionary) -> Dictionary:
	return DeepContent.skill(str(stone.get("skill", "")))

static func carat_max() -> int:
	return int(DeepContent.constant("carat_max", 20))

static func is_flawless(stone: Dictionary) -> bool:
	return bool(DeepContent.clarity_entry(int(stone.get("clarity", 0))).get("flawless_line", false))

static func inclusion_slots(clarity: int) -> int:
	return int(DeepContent.clarity_entry(clarity).get("inclusions", 0))

static func colour(stone: Dictionary) -> String:
	return str(skill_of(stone).get("colour", "WHITE"))

static func colours(stone: Dictionary, socket: String = "") -> Array:
	## Every colour the stone counts as: its skill's, any Colour Zoning, and the socket's
	## own colour for an Alexandrite.
	var out: Array = [colour(stone)]
	for m in modifiers(stone):
		match str(m.get("kind", "")):
			"colour_also":
				if not out.has(str(m.colour)):
					out.append(str(m.colour))
			"alexandrite":
				if socket in COLOURS and not out.has(socket):
					out.append(socket)
	return out

static func fits(stone: Dictionary, socket: String) -> bool:
	if socket == DeepContent.SOCKET_ANY:
		return true
	return colours(stone, socket).has(socket)

static func modifiers(stone: Dictionary) -> Array:
	## Every modifier of every inclusion, each tagged with the inclusion it came from.
	var out: Array = []
	for key in stone.get("inclusions", []):
		var def: Dictionary = DeepContent.inclusion(str(key))
		for m in def.get("modifiers", []):
			if m is Dictionary:
				var tagged: Dictionary = m.duplicate(true)
				tagged.inclusion = str(key)
				out.append(tagged)
	return out

static func has_modifier(mods: Array, kind: String) -> bool:
	for m in mods:
		if str(m.get("kind", "")) == kind:
			return true
	return false

static func modifier_sum(mods: Array, kind: String, field: String = "amount") -> int:
	var sum: int = 0
	for m in mods:
		if str(m.get("kind", "")) == kind:
			sum += int(m.get(field, 0))
	return sum

static func is_locked(stone: Dictionary) -> bool:
	return has_modifier(modifiers(stone), "locked")

# --- the Birthstone -------------------------------------------------------------------------

static func birthstone(character_key: String) -> Dictionary:
	## A character's Birthstone as a stone the views can draw and name: fixed ranks, its own
	## cut, tint and emblem, no skill and no inclusions. Never socketed, never in a vault.
	var character: Dictionary = DeepContent.character(character_key)
	var def: Dictionary = character.get("birthstone", {})
	if def.is_empty():
		return {}
	return {"id": "birthstone_" + character_key, "birthstone": true, "character": character_key, "skill": "",
		"name": str(def.get("name", "Birthstone")), "style": str(def.get("style", "shield")), "hue": str(def.get("hue", "ffffff")),
		"emblem": str(def.get("emblem", "gem")), "carat": 10, "cut": 4, "clarity": 4, "inclusions": [], "appraised": true,
		"text": str(def.get("text", "")), "tiers": def.get("tiers", []).duplicate(true)}

static func is_birthstone(stone: Dictionary) -> bool:
	return bool(stone.get("birthstone", false))

# --- names and worth -------------------------------------------------------------------

static func name(stone: Dictionary) -> String:
	## "Perfect Flawless 14-carat Barrage": the way a jeweller says it.
	if is_birthstone(stone):
		return str(stone.get("name", "Birthstone"))
	var skill: Dictionary = skill_of(stone)
	return "%s %s %d-carat %s" % [DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 0))),
		int(stone.get("carat", 1)), str(skill.get("name", stone.get("skill", "stone")))]

static func raw_name(stone: Dictionary) -> String:
	## What an unappraised stone is called: its size and colour, nothing more.
	var colour_name: String = str(DeepContent.colour(colour(stone)).get("name", colour(stone)))
	return "%d-carat %s stone" % [int(stone.get("carat", 1)), colour_name]

static func grade(stone: Dictionary) -> Dictionary:
	## The number the slot machine shows. 0 to 100, in five tiers.
	var carat_pts: float = float(int(stone.get("carat", 1))) / float(carat_max()) * 45.0
	var cut_pts: float = float(int(stone.get("cut", 0))) / float(DeepPatterns.STEPS - 1) * 20.0
	## Clarity is scored by how far it sits from Clear on its own side of the ladder, so a
	## Flawless and a Riddled stone both earn the full 20: a perfect-stats stone and a
	## perfect-chaos stone are both jackpots.
	var clear: int = DeepContent.clear_index()
	var clarity_index: int = int(stone.get("clarity", clear))
	var reach: int = maxi(1, (DeepContent.clarities().size() - 1 - clear) if clarity_index > clear else clear)
	var clarity_pts: float = float(absi(clarity_index - clear)) / float(reach) * 20.0
	var inclusion_pts: float = 0.0
	for key in stone.get("inclusions", []):
		inclusion_pts += float(INCLUSION_SCORE.get(str(DeepContent.inclusion(str(key)).get("rarity", "COMMON")), 2.0))
	inclusion_pts = minf(15.0, inclusion_pts)
	var skill_pts: float = DeepContent.rarity_score(str(skill_of(stone).get("rarity", "COMMON"))) / 28.0 * 8.0
	var score: int = clampi(int(round(carat_pts + cut_pts + clarity_pts + inclusion_pts + skill_pts)), 0, 100)
	var thresholds: Dictionary = DeepContent.constant("grade_thresholds", {"FINE": 30, "PRECIOUS": 55, "EXQUISITE": 72, "PEERLESS": 85})
	var tier: String = "ROUGH"
	for candidate in ["FINE", "PRECIOUS", "EXQUISITE", "PEERLESS"]:
		if score >= int(thresholds.get(candidate, 999)):
			tier = candidate
	return {"score": score, "tier": tier, "name": TIER_NAMES[tier], "index": TIERS.find(tier)}

static func value(stone: Dictionary) -> int:
	## Sell price in gold.
	var clear: int = DeepContent.clear_index()
	var base: float = 10.0 + float(int(stone.get("carat", 1))) * 4.0
	base *= 1.0 + float(int(stone.get("cut", 0))) * 0.25
	base *= 1.0 + 0.3 * float(absi(int(stone.get("clarity", clear)) - clear))
	base *= float(RARITY_VALUE.get(str(skill_of(stone).get("rarity", "COMMON")), 1.0))
	for key in stone.get("inclusions", []):
		base *= 1.0 + float(INCLUSION_SCORE.get(str(DeepContent.inclusion(str(key)).get("rarity", "COMMON")), 2.0)) / 20.0
	return maxi(1, int(round(base)))

static func inclusion_names(stone: Dictionary) -> Array:
	var out: Array = []
	for key in stone.get("inclusions", []):
		out.append(str(DeepContent.inclusion(str(key)).get("name", key)))
	return out

# --- what the stone does ---------------------------------------------------------------

static func effective(stone: Dictionary, c: Dictionary = {}) -> Dictionary:
	## The ranks the stone really has once its inclusions and its place in the rail speak.
	## `c` may carry carat_bonus (Capstone, Halo), cut_step_bonus (Feather, passives),
	## amplify (Double Down, amplify_next) and depth (Fluorescence).
	var mods: Array = modifiers(stone)
	var clarity_entry: Dictionary = DeepContent.clarity_entry(int(stone.get("clarity", 0)))
	var carat: int = int(stone.get("carat", 1)) + modifier_sum(mods, "carat") + int(c.get("carat_bonus", 0))
	var depth: int = int(c.get("depth", 0))
	var carat_mult: float = 1.0
	var magnitude_mult: float = 1.0
	var cut_step: int = int(stone.get("cut", 0))
	for m in mods:
		match str(m.get("kind", "")):
			"carat_per_depth":
				if depth > int(m.get("below", 0)):
					carat += (depth - int(m.get("below", 0))) * int(m.get("amount", 1))
			"carat_mult":
				carat_mult *= float(m.get("amount", 1.0))
			"magnitude":
				magnitude_mult *= float(m.get("amount", 1.0))
			"cut_override":
				cut_step = int(m.get("value", 0))
	cut_step += int(clarity_entry.get("cut_step", 0)) + modifier_sum(mods, "cut_step") + int(c.get("cut_step_bonus", 0))
	var per_carat: float = float(DeepContent.constant("magnitude_per_carat", 0.25))
	var magnitude: float = (1.0 + float(carat) * carat_mult * per_carat) * float(clarity_entry.get("magnitude", 1.0)) * magnitude_mult * float(c.get("amplify", 1.0))
	return {"carat": carat, "cut_step": maxi(0, cut_step), "magnitude": magnitude, "modifiers": mods}

static func apply_lens(hand: Array, mode: String) -> Array:
	var out: Array = hand.duplicate(true)
	match mode:
		"low_as_high":
			var low_index: int = -1
			var high: int = 0
			for index in range(out.size()):
				var roll: Dictionary = out[index]
				if str(roll.get("kind", "plain")) in ["wild", "blank"]:
					continue
				high = maxi(high, int(roll.value))
				if low_index < 0 or int(roll.value) < int(out[low_index].value):
					low_index = index
			if low_index >= 0:
				out[low_index].value = high
		"ones_wild":
			for roll in out:
				if int(roll.get("value", 0)) == 1 and str(roll.get("kind", "plain")) == "plain":
					roll.kind = "wild"
		"held_twice":
			for roll in out:
				if DeepDice.held_for_patterns(roll):
					roll.engraving = "twin"
	return out

static func apply_flawless(defs: Array, flawless: Dictionary) -> Array:
	var out: Array = defs.duplicate(true)
	for change in flawless.get("modify", []):
		if not change is Dictionary:
			continue
		var index: int = int(change.get("effect", 0))
		if index < 0 or index >= out.size():
			continue
		var def: Dictionary = out[index]
		if change.has("target"):
			def.target = str(change.target)
		if change.has("kind"):
			def.kind = str(change.kind)
		if change.has("scale"):
			def.scale = str(change.scale)
		if change.has("mult"):
			def.amount = {"op": "*", "args": [def.get("amount", {"const": 0}), {"const": int(change.mult)}]}
		if change.has("add"):
			def.amount = {"op": "+", "args": [def.get("amount", {"const": 0}), {"const": int(change.add)}]}
		if change.has("repeat_add"):
			def.repeat = {"op": "+", "args": [def.get("repeat", {"const": 1}), {"const": int(change.repeat_add)}]}
		if change.has("splash"):
			def.splash = int(change.splash)
	for extra in flawless.get("effects", []):
		if extra is Dictionary:
			out.append(extra.duplicate(true))
	return out

static func evaluate(stone: Dictionary, hand: Array, c: Dictionary = {}) -> Dictionary:
	## What this stone does to this hand. `c` is the rail context: unit, resonance,
	## previous_fired, previous_amount, amplify, cut_step_bonus, carat_bonus, depth, turn,
	## party, socket, retrigger, force_fire. Pure: nothing is changed.
	var skill: Dictionary = skill_of(stone)
	if skill.is_empty():
		return {"active": false, "reason": "unknown skill", "dice": [], "effects": [], "fires": 0}
	var eff: Dictionary = effective(stone, c)
	var mods: Array = eff.modifiers
	var working: Array = hand
	for m in mods:
		if str(m.get("kind", "")) == "lens":
			working = apply_lens(working, str(m.get("mode", "")))
	var a: Dictionary = DeepHand.analyze(working)
	var trigger: Dictionary = skill.get("trigger", {"kind": "always"})
	var trig: Dictionary = DeepPatterns.evaluate(trigger, eff.cut_step, a, {"resonance": int(c.get("resonance", 0))})
	if not trig.active and (has_modifier(mods, "always_fires") or bool(c.get("force_fire", false))):
		trig.active = true
		trig.forced = true
		trig.dice = DeepHand.matching(a, func(_v: int) -> bool: return true)
		trig.value = int(a.get("best_set", {}).get("value", a.get("high", 0)))
		trig.count = maxi(1, int(a.get("best_set", {}).get("count", 1)))
		trig.erase("reason")
	for m in mods:
		if str(m.get("kind", "")) == "fizzle_on_value" and trig.active:
			var forbidden: int = int(m.get("value", 1))
			if not DeepHand.matching(a, func(v: int) -> bool: return v == forbidden).is_empty() and a.get("ids_by_value", {}).has(forbidden):
				trig.active = false
				trig.reason = "%s: a %d showed." % [str(DeepContent.inclusion(str(m.inclusion)).get("name", "Fracture")), forbidden]
	var result: Dictionary = {"active": bool(trig.active), "reason": str(trig.get("reason", "")), "dice": trig.get("dice", []),
		"trigger": trig, "cut_step": eff.cut_step, "carat": eff.carat, "magnitude": eff.magnitude, "analysis": a,
		"effects": [], "fires": 1 if trig.active else 0, "hp_cost": 0, "resonance_gain": 0,
		"next_cut_step": modifier_sum(mods, "next_cut_step"), "no_reset": has_modifier(mods, "no_resonance_reset"),
		"colours": colours(stone, str(c.get("socket", ""))), "skill": str(stone.get("skill", "")), "stone_id": str(stone.get("id", ""))}
	if not trig.active:
		return result
	var tc: Dictionary = {"a": a, "trig": trig, "unit": c.get("unit", {}), "resonance": int(c.get("resonance", 0)),
		"previous_amount": int(c.get("previous_amount", 0)), "carat": eff.carat, "cut": eff.cut_step,
		"clarity": int(stone.get("clarity", 0)), "depth": int(c.get("depth", 0)), "turn": int(c.get("turn", 0)), "party": int(c.get("party", 1))}
	var defs: Array = skill.get("effects", []).duplicate(true)
	if is_flawless(stone) and skill.get("flawless", null) is Dictionary:
		defs = apply_flawless(defs, skill.flawless)
	for def in defs:
		if def is Dictionary:
			result.effects.append(DeepRules.resolve_effect(def, tc, eff.magnitude))
	var per_die: int = modifier_sum(mods, "per_die_damage")
	if per_die > 0:
		for effect in result.effects:
			if str(effect.kind) == "damage":
				effect.amount += per_die * trig.get("dice", []).size()
	for m in mods:
		if str(m.get("kind", "")) == "rider":
			for def in m.get("effects", []):
				if def is Dictionary:
					var rider: Dictionary = DeepRules.resolve_effect(def, tc, eff.magnitude)
					rider.inclusion = str(m.inclusion)
					result.effects.append(rider)
	result.hp_cost = modifier_sum(mods, "hp_cost")
	result.resonance_gain = 1 + modifier_sum(mods, "resonance_bonus")
	if not bool(c.get("retrigger", false)):
		if has_modifier(mods, "fires_twice"):
			result.fires += 1
		if has_modifier(mods, "retrigger_if_previous_fired") and bool(c.get("previous_fired", false)):
			result.fires += 1
	return result

static func total_amount(evaluation: Dictionary, kinds: Array = ["damage", "block", "heal"]) -> int:
	## The headline number of an evaluation: what Echo repeats and the forecast sums.
	var total: int = 0
	for effect in evaluation.get("effects", []):
		if str(effect.kind) in kinds:
			total += int(effect.amount) * maxi(1, int(effect.get("repeat", 1)))
	return total

static func sealed(stone: Dictionary) -> Dictionary:
	## A raw stone as a guest sees it: size and colour, nothing that a loupe would tell.
	var copy: Dictionary = stone.duplicate(true)
	if not bool(copy.get("appraised", false)):
		copy.cut = -1
		copy.clarity = -1
		if not bool(copy.get("inclusions_revealed", false)):
			copy.inclusions = []
	return copy
