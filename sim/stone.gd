class_name DeepStone
extends RefCounted
## A stone: one instance of a skill with its four C's, its inclusions and its history.
##
##   {id, skill, carat, cut, clarity, inclusions: [keys], appraised, inclusions_revealed,
##    provenance: {mine, depth, run, date}, favourite}
##
## Cut is an index 0..4 (Poor to Perfect) and clarity an index into the pack's clarity
## ladder (Intricate to Flawless). color is never stored: it is the skill's, plus whatever
## an inclusion adds. `evaluate()` is the whole of what a stone does to a hand, used by the
## battle, the forecast and the tests alike.

const colorS: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]
const TIERS: Array = ["ROUGH", "FINE", "PRECIOUS", "EXQUISITE", "PEERLESS"]
const TIER_NAMES: Dictionary = {"ROUGH": "Rough", "FINE": "Fine", "PRECIOUS": "Precious", "EXQUISITE": "Exquisite", "PEERLESS": "Peerless"}
const INCLUSION_SCORE: Dictionary = {"COMMON": 2.0, "UNCOMMON": 4.0, "RARE": 7.0, "LEGENDARY": 15.0}
const RARITY_VALUE: Dictionary = {"COMMON": 1.0, "UNCOMMON": 1.5, "RARE": 2.5, "LEGENDARY": 4.0, "MYTHIC": 8.0}

static func make(skill: String, carat: int, cut: int, clarity: int, inclusions: Array = [], provenance: Dictionary = {}, id: String = "") -> Dictionary:
	return {"id": id, "skill": skill, "carat": carat, "cut": cut, "clarity": clarity, "inclusions": inclusions.duplicate(),
		"appraised": false, "inclusions_revealed": false, "provenance": provenance.duplicate(), "favourite": false}

static func skill_of(stone: Dictionary) -> Dictionary:
	return DeepContent.skill(str(stone.get("skill", "")))

static func carat_max() -> int:
	return int(DeepContent.constant("carat_max", 24))

static func carat_multiplier(carat: float) -> float:
	## The magnitude multiplier for a carat count: 1x at the smallest stone (no bonus), then
	## +0.25x per carat up to 19, then the ramp steepens to +1x per carat from 20 on, so the
	## biggest stones spike. Extends past the table for carat_mult and carat_bonus effects
	## that can push the effective carat past carat_max().
	if carat < 20.0:
		return 1.0 + (carat - 1.0) * 0.25
	return carat - 14.0

static func is_flawless(stone: Dictionary) -> bool:
	return bool(DeepContent.clarity_entry(int(stone.get("clarity", 0))).get("flawless_line", false))

static func inclusion_slots(clarity: int) -> int:
	return int(DeepContent.clarity_entry(clarity).get("inclusions", 0))

static func color(stone: Dictionary) -> String:
	return str(skill_of(stone).get("color", "WHITE"))

static func is_opal(stone: Dictionary) -> bool:
	## An opal: the seventh color, which is no color and all six at once. Only a hoard
	## offers one, and no socket is cut for one because every socket takes one.
	return color(stone) == DeepContent.OPAL

static func colors(stone: Dictionary, socket: String = "") -> Array:
	## Every color the stone counts as: its skill's, any color Zoning, and the socket's
	## own color for an Alexandrite. An opal answers to all six, so it fits any socket and
	## rings in harmony with whatever fired before it.
	if is_opal(stone):
		return colorS.duplicate()
	var out: Array = [color(stone)]
	for m in modifiers(stone):
		match str(m.get("kind", "")):
			"color_also":
				if not out.has(str(m.color)):
					out.append(str(m.color))
			"alexandrite":
				if socket in colorS and not out.has(socket):
					out.append(socket)
	return out

static func fits(stone: Dictionary, socket: String) -> bool:
	if socket == DeepContent.SOCKET_ANY:
		return true
	return colors(stone, socket).has(socket)

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
	## It is always the heaviest a stone can be, because it is the one stone nobody found:
	## its weight buys it nothing in a fight (a tier resolves at magnitude 1.0) and is there
	## so it sits in the rail at the size the character's own stone ought to be.
	var character: Dictionary = DeepContent.character(character_key)
	var def: Dictionary = character.get("birthstone", {})
	if def.is_empty():
		return {}
	return {"id": "birthstone_" + character_key, "birthstone": true, "character": character_key, "skill": "",
		"name": str(def.get("name", "Birthstone")), "style": str(def.get("style", "shield")), "hue": str(def.get("hue", "ffffff")), "hue2": str(def.get("hue2", "")),
		"emblem": str(def.get("emblem", "gem")), "carat": carat_max(), "cut": 4, "clarity": 4, "inclusions": [], "appraised": true,
		"text": str(def.get("text", "")), "tiers": def.get("tiers", []).duplicate(true)}

static func wearing(stone: Dictionary, other: Dictionary) -> Dictionary:
	## This stone with another's skill on it: what a Doublet is. The four C's, the
	## inclusions and the id stay the stone's own, so a heavy Doublet fires a light gem's
	## skill at its own weight — and a Flawless one reads that skill's Flawless line.
	var copy: Dictionary = stone.duplicate(true)
	copy.skill = str(other.get("skill", ""))
	copy.worn_from = str(other.get("id", ""))
	return copy

static func reference_stone(skill: String) -> Dictionary:
	## A skill as a stone with nothing added: one carat, the poorest cut, perfectly clear and
	## with nothing frozen inside it. Its magnitude is exactly 1.0 and it fires on the bottom
	## rung of its ladder, so every number on its page is the number the pack wrote. It is
	## what the vault shows for a gem the player has seen and does not own — a page about the
	## skill, never a stone anybody has.
	var out: Dictionary = make(skill, 1, 0, DeepContent.clear_index(), [], {"source": "reference"}, "reference_" + skill)
	out.appraised = true
	out.inclusions_revealed = true
	return out

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
	## What an unappraised stone is called: roughly how big and what color, nothing more.
	## Its carat is never said exactly until a loupe has been put to it.
	var color_name: String = str(DeepContent.color(color(stone)).get("name", color(stone)))
	return "%s %s stone" % [size_name(int(stone.get("carat", 1))), color_name.to_lower()]

## How big a raw stone looks, half-buried in its rock: a class, never the carat itself.
## `low` is the smallest carat in the class; each class runs up to the next one's `low`.
const SIZE_CLASSES: Array = [
	{"key": "TINY", "name": "Tiny", "low": 1, "shown": 3},
	{"key": "SMALL", "name": "Small", "low": 5, "shown": 7},
	{"key": "MEDIUM", "name": "Medium", "low": 10, "shown": 12},
	{"key": "LARGE", "name": "Large", "low": 15, "shown": 17},
	{"key": "HUGE", "name": "Huge", "low": 20, "shown": 24}]

static func size_class(carat: int) -> Dictionary:
	## The class a carat falls in, with `index` into SIZE_CLASSES and a readable `range`.
	var found: int = 0
	for index in range(SIZE_CLASSES.size()):
		if carat >= int(SIZE_CLASSES[index].low):
			found = index
	var entry: Dictionary = SIZE_CLASSES[found].duplicate()
	entry.index = found
	var high: int = int(SIZE_CLASSES[found + 1].low) - 1 if found + 1 < SIZE_CLASSES.size() else -1
	entry.range = ("%d to %d carats" % [int(entry.low), high]) if high > 0 else ("%d carats or more" % int(entry.low))
	return entry

static func size_name(carat: int) -> String:
	return str(size_class(carat).name)

static func shown_carat(stone: Dictionary) -> int:
	## The carat a stone is drawn at. A raw stone is drawn at its class's size, so two stones
	## of one class look alike and the picture never says more than the name does.
	var carat: int = int(stone.get("carat", 1))
	if stone.has("appraised") and not bool(stone.appraised):
		return mini(int(size_class(carat).shown), carat_max())
	return carat

static func grade_breakdown(stone: Dictionary) -> Dictionary:
	## What each of the four C's (and what is frozen inside, and the skill's own rarity)
	## contributes to the grade, out of 45/20/20/15/8. `grade()` sums these to its score.
	var carat_pts: float = float(int(stone.get("carat", 1))) / float(carat_max()) * 45.0
	var cut_pts: float = float(int(stone.get("cut", 0))) / float(DeepPatterns.STEPS - 1) * 20.0
	## Clarity is scored by how far it sits from Clear on its own side of the ladder, so a
	## Flawless and an Intricate stone both earn the full 20: a perfect-stats stone and a
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
	return {"carat_pts": carat_pts, "cut_pts": cut_pts, "clarity_pts": clarity_pts, "inclusion_pts": inclusion_pts,
		"skill_pts": skill_pts, "total": carat_pts + cut_pts + clarity_pts + inclusion_pts + skill_pts}

static func grade(stone: Dictionary) -> Dictionary:
	## The number the slot machine shows. 0 to 100, in five tiers.
	var breakdown: Dictionary = grade_breakdown(stone)
	var score: int = clampi(int(round(float(breakdown.total))), 0, 100)
	var thresholds: Dictionary = DeepContent.constant("grade_thresholds", {"FINE": 30, "PRECIOUS": 55, "EXQUISITE": 72, "PEERLESS": 85})
	var tier: String = "ROUGH"
	for candidate in ["FINE", "PRECIOUS", "EXQUISITE", "PEERLESS"]:
		if score >= int(thresholds.get(candidate, 999)):
			tier = candidate
	return {"score": score, "tier": tier, "name": TIER_NAMES[tier], "index": TIERS.find(tier), "breakdown": breakdown}

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

static func rough_value(stone: Dictionary) -> int:
	## What a buyer gives for a stone nobody has read: he can see its colour and judge its
	## size class through the rock, and nothing else, so he pays for the class and takes the
	## rest of the risk. Always well under what the same stone is worth once it is known.
	var entry: Dictionary = size_class(int(stone.get("carat", 1)))
	var by_size: float = 6.0 + float(entry.low) * 2.2
	return maxi(1, int(round(by_size)))

static func sell_value(stone: Dictionary) -> int:
	## What the merchant's scales pay for it: half its worth once it has been read, and only
	## what its size class is worth while it is still in its rock. The one place that price
	## is worked out, so the number the scales promise is the number the sale pays.
	return value(stone) / 2 if bool(stone.get("appraised", false)) else rough_value(stone)

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
	var magnitude: float = carat_multiplier(float(carat) * carat_mult) * float(clarity_entry.get("magnitude", 1.0)) * magnitude_mult * float(c.get("amplify", 1.0))
	return {"carat": carat, "cut_step": maxi(0, cut_step), "magnitude": magnitude, "modifiers": mods,
		"resonance_mult": float(clarity_entry.get("resonance_mult", 1.0))}

## How a number of goes is said out loud, and what the next one after it is called.
const TIMES_OVER: Array = ["once", "twice", "three times", "four times", "five times", "six times",
	"seven times", "eight times", "nine times", "ten times"]
const NEXT_TIME: Array = ["", "a second", "a third", "a fourth", "a fifth", "a sixth", "a seventh",
	"an eighth", "a ninth", "a tenth", "an eleventh"]

static func procs(stone: Dictionary, c: Dictionary = {}) -> Dictionary:
	## How many times over a whole-number effect of this stone happens, and the chance of
	## one more: the carat curve read as procs. Only the effects that cannot take a
	## multiplier use it, so a Cascade on a heavy stone grants more rerolls rather than a
	## fraction of one. See `DeepRules.carat_procs`.
	return DeepRules.carat_procs(float(effective(stone, c).magnitude))

static func procs_matter(stone: Dictionary) -> bool:
	## Whether this skill has anything procs could apply to: an effect that takes no
	## multiplier and was not written flat on purpose. A Strike swells with weight instead
	## and must never be told it fires twice.
	var skill: Dictionary = skill_of(stone)
	var defs: Array = skill.get("effects", []).duplicate(true)
	if is_flawless(stone) and skill.get("flawless", null) is Dictionary:
		defs.append_array(skill.flawless.get("effects", []))
	for def in defs:
		if def is Dictionary and not def.has("scale") and not str(def.get("kind", "damage")) in DeepRules.SCALED_BY_DEFAULT:
			return true
	return false

static func magnitude_matters(stone: Dictionary) -> bool:
	## Whether the carat multiplier is worth saying out loud: something this skill does is
	## scaled by it. A skill made only of whole-number effects takes procs instead, and a
	## "x3.4" written next to its text would be a number that touches nothing.
	if is_birthstone(stone):
		return false
	var skill: Dictionary = skill_of(stone)
	var defs: Array = skill.get("effects", []).duplicate(true)
	if is_flawless(stone) and skill.get("flawless", null) is Dictionary:
		defs.append_array(skill.flawless.get("effects", []))
	for def in defs:
		if not def is Dictionary:
			continue
		var kind: String = str(def.get("kind", "damage"))
		if str(def.get("scale", "carat" if kind in DeepRules.SCALED_BY_DEFAULT else "none")) == "carat":
			return true
	return false

static func proc_lines(stone: Dictionary, c: Dictionary = {}) -> Array:
	## What weight buys a stone whose effect cannot be a fraction, in words: one line for
	## what is certain, one for what is only likely. A stone light enough to do its one
	## thing once says nothing at all.
	if is_birthstone(stone) or not procs_matter(stone):
		return []
	var p: Dictionary = procs(stone, c)
	var times: int = int(p.procs)
	var chance: int = int(p.chance)
	var out: Array = []
	if times > 1:
		var spoken: String = str(TIMES_OVER[mini(times - 1, TIMES_OVER.size() - 1)])
		out.append({"sure": true, "text": "%s%s over, for its weight." % [spoken.substr(0, 1).to_upper(), spoken.substr(1)]})
	if chance > 0:
		out.append({"sure": false, "text": "%d%% chance of %s." % [chance, "twice over" if times == 1 else str(NEXT_TIME[mini(times, NEXT_TIME.size() - 1)])]})
	return out

static func text(stone: Dictionary, c: Dictionary = {}) -> String:
	## The skill's card text with this stone's Cut written into it.
	var skill: Dictionary = skill_of(stone)
	return DeepRules.fill(str(skill.get("text", "")), skill.get("numbers", {}), int(effective(stone, c).cut_step))

static func flawless_text(stone: Dictionary, c: Dictionary = {}) -> String:
	var skill: Dictionary = skill_of(stone)
	if not skill.get("flawless", null) is Dictionary:
		return ""
	return DeepRules.fill(str(skill.flawless.get("text", "")), skill.get("numbers", {}), int(effective(stone, c).cut_step))

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
		"next_cut_step": modifier_sum(mods, "next_cut_step"),
		"colors": colors(stone, str(c.get("socket", ""))), "skill": str(stone.get("skill", "")), "stone_id": str(stone.get("id", ""))}
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
	## Clarity is what a stone gives back to the rail: a Pristine stone rings twice as loud
	## as it fires, a Flawless one three times.
	result.resonance_gain = int(round(float(1 + modifier_sum(mods, "resonance_bonus")) * float(eff.resonance_mult)))
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
	## A raw stone as a guest sees it: size and color, nothing that a loupe would tell.
	var copy: Dictionary = stone.duplicate(true)
	if not bool(copy.get("appraised", false)):
		copy.cut = -1
		copy.clarity = -1
		if not bool(copy.get("inclusions_revealed", false)):
			copy.inclusions = []
	return copy
