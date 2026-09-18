class_name DeepPatterns
extends RefCounted
## What a hand has to show before a gem fires.
##
## A trigger is a kind and a ladder of five thresholds indexed by Cut step, Poor to Perfect.
## The ladder is what Cut means: a Perfect stone stands on the loosest rung. Thresholds on
## totals and high dice are percentages of the hand's own maximum, so a d20 bowl and a d4
## bowl are judged against themselves.
##
##   always              fires on every hand; the rung says how many dice it reads (read: high|low)
##   pair/triple/quad/quint   a set of that size; the rung is the lowest value that counts
##   two_pair            two sets of two or more with distinct values at or above the rung
##   full_house          a set of three and a set of two, the triple at or above the rung
##   straight            a run at least the rung long
##   odd / even          at least the rung many dice of that parity
##   distinct            at least the rung many different values
##   value               at least the rung many dice showing one of `values`
##   at_most             at least one die showing the rung or less (Ember reads ones)
##   at_least            the highest die shows the rung or more, as an absolute value
##   total_pct_at_least / total_pct_at_most   the total against the hand's maximum, in percent
##   high_pct_at_least   the best die against its own top, in percent
##   held / rerolled     at least the rung many dice held (or rerolled) this turn
##   resonance           the rail's Resonance is at least the rung
##
## `describe` turns a trigger into the pictograph the interface draws and the sentence a
## tooltip says. Nothing here evaluates content by name.

const KINDS: Array = ["always", "pair", "two_pair", "triple", "full_house", "quad", "quint", "straight",
	"odd", "even", "distinct", "value", "at_most", "at_least", "total_pct_at_least", "total_pct_at_most",
	"high_pct_at_least", "held", "rerolled", "resonance"]
const SET_SIZES: Dictionary = {"pair": 2, "triple": 3, "quad": 4, "quint": 5}
const STEPS: int = 5

static func rung(trigger: Dictionary, cut_step: int) -> int:
	var ladder: Array = trigger.get("ladder", [])
	if ladder.is_empty():
		return int(trigger.get("amount", 0))
	return int(ladder[clampi(cut_step, 0, ladder.size() - 1)])

static func evaluate(trigger: Dictionary, cut_step: int, a: Dictionary, context: Dictionary = {}) -> Dictionary:
	var kind: String = str(trigger.get("kind", "always"))
	var need: int = rung(trigger, cut_step)
	var result: Dictionary = {"active": false, "dice": [], "kind": kind, "need": need, "value": 0, "count": 0}
	if kind == "always":
		var picked: Dictionary = DeepHand.read(a, maxi(1, need), str(trigger.get("read", "high")) != "low")
		result.active = true
		result.dice = picked.dice
		result.value = picked.sum
		result.count = picked.dice.size()
		return result
	if bool(a.get("gem_face", false)):
		## A gem face lights the whole rail. The pattern still reports what it would have
		## read, so amounts that depend on it have something to stand on.
		result.active = true
		result.gem_face = true
		result.dice = _all_dice(a)
		result.value = int(a.get("best_set", {}).get("value", a.get("high", 0)))
		result.count = maxi(1, int(a.get("best_set", {}).get("count", 1)))
		return result
	match kind:
		"pair", "triple", "quad", "quint":
			for group in a.get("groups", []):
				if int(group.count) >= int(SET_SIZES[kind]) and int(group.value) >= need:
					result.active = true
					result.dice = group.dice.duplicate()
					result.value = int(group.value)
					result.count = int(group.count)
					break
		"two_pair":
			var qualifying: Array = a.get("pairs", []).filter(func(g: Dictionary) -> bool: return int(g.value) >= need)
			if qualifying.size() >= 2:
				result.active = true
				result.dice = qualifying[0].dice + qualifying[1].dice
				result.value = int(qualifying[0].value)
				result.second = int(qualifying[1].value)
				result.count = 4
		"full_house":
			var triple: Dictionary = {}
			for group in a.get("groups", []):
				if int(group.count) >= 3 and int(group.value) >= need:
					triple = group
					break
			if not triple.is_empty():
				for group in a.get("groups", []):
					if int(group.value) != int(triple.value) and int(group.count) >= 2:
						result.active = true
						result.dice = triple.dice + group.dice
						result.value = int(triple.value)
						result.second = int(group.value)
						result.count = 5
						break
		"straight":
			var run: Dictionary = a.get("straight", {})
			if int(run.get("length", 0)) >= need:
				result.active = true
				result.dice = run.get("dice", []).duplicate()
				result.value = int(run.get("high", 0))
				result.count = int(run.get("length", 0))
		"odd", "even":
			var wanted_odd: bool = kind == "odd"
			var have: int = int(a.get("odd" if wanted_odd else "even", 0))
			if have >= need:
				result.active = true
				result.dice = DeepHand.matching(a, func(v: int) -> bool: return (v % 2 == 1) == wanted_odd)
				result.count = have
				result.value = have
		"distinct":
			if int(a.get("distinct", 0)) >= need:
				result.active = true
				var dice: Array = []
				for v in a.get("ids_by_value", {}):
					dice.append(str(a.ids_by_value[v][0]))
				dice.append_array(a.get("wilds", []))
				result.dice = dice
				result.count = int(a.distinct)
				result.value = int(a.distinct)
		"value":
			var wanted: Array = trigger.get("values", [7])
			var dice: Array = DeepHand.matching(a, func(v: int) -> bool: return wanted.has(v) or wanted.has(float(v)))
			if dice.size() >= maxi(1, need):
				result.active = true
				result.dice = dice
				result.count = dice.size()
				result.value = int(wanted[0]) if not wanted.is_empty() else 0
		"at_most":
			var dice: Array = DeepHand.matching(a, func(v: int) -> bool: return v <= need)
			if dice.size() >= 1:
				result.active = true
				result.dice = dice
				result.count = dice.size()
				result.value = need
		"at_least":
			if int(a.get("high", 0)) >= need:
				result.active = true
				result.dice = DeepHand.matching(a, func(v: int) -> bool: return v >= need)
				result.value = int(a.high)
				result.count = result.dice.size()
		"total_pct_at_least":
			if int(a.get("total", 0)) * 100 >= int(a.get("max_total", 1)) * need:
				result.active = true
				result.dice = _all_dice(a)
				result.value = int(a.total)
		"total_pct_at_most":
			if int(a.get("total", 0)) * 100 <= int(a.get("max_total", 1)) * need:
				result.active = true
				result.dice = _all_dice(a)
				result.value = int(a.total)
		"high_pct_at_least":
			if int(a.get("high_pct", 0)) >= need:
				result.active = true
				result.dice = DeepHand.matching(a, func(v: int) -> bool: return v >= int(a.get("high", 0)))
				result.value = int(a.get("high", 0))
		"held":
			if int(a.get("held", 0)) >= need:
				result.active = true
				result.count = int(a.held)
				result.value = int(a.held)
		"rerolled":
			if int(a.get("rerolled", 0)) >= need:
				result.active = true
				result.count = int(a.rerolled)
				result.value = int(a.rerolled)
		"resonance":
			if int(context.get("resonance", 0)) >= need:
				result.active = true
				result.value = int(context.get("resonance", 0))
	if not result.active:
		result.reason = words(trigger, cut_step)
	return result

static func _all_dice(a: Dictionary) -> Array:
	var dice: Array = []
	for v in a.get("ids_by_value", {}):
		dice.append_array(a.ids_by_value[v])
	dice.append_array(a.get("wilds", []))
	return dice

static func describe(trigger: Dictionary, cut_step: int) -> Dictionary:
	## The mark the interface draws, the short label beside it, and the sentence it says.
	var kind: String = str(trigger.get("kind", "always"))
	var need: int = rung(trigger, cut_step)
	var mark: String = kind
	var label: String = ""
	match kind:
		"always":
			mark = "read_high" if str(trigger.get("read", "high")) != "low" else "read_low"
			label = "×%d" % maxi(1, need) if need > 1 else ""
		"pair", "triple", "quad", "quint", "full_house":
			label = "%d+" % need if need > 1 else ""
		"two_pair":
			label = "%d+" % need if need > 1 else ""
		"straight", "odd", "even", "distinct", "held", "rerolled", "resonance":
			label = "×%d" % need
		"value":
			var wanted: Array = trigger.get("values", [7])
			label = "/".join(wanted.map(func(v: Variant) -> String: return str(int(v))))
			if need > 1:
				label += " ×%d" % need
		"at_most":
			label = "≤%d" % need
		"at_least":
			label = "≥%d" % need
		"total_pct_at_least":
			label = "≥%d%%" % need
		"total_pct_at_most":
			label = "≤%d%%" % need
		"high_pct_at_least":
			label = "≥%d%%" % need
	return {"mark": mark, "kind": kind, "need": need, "label": label, "words": words(trigger, cut_step)}

static func words(trigger: Dictionary, cut_step: int) -> String:
	var kind: String = str(trigger.get("kind", "always"))
	var need: int = rung(trigger, cut_step)
	match kind:
		"always":
			var count: int = maxi(1, need)
			var side: String = "lowest" if str(trigger.get("read", "high")) == "low" else "highest"
			return "Fires on every hand and reads your %s die." % side if count == 1 else "Fires on every hand and reads your %s %d dice." % [side, count]
		"pair": return "A pair" + _of_at_least(need) + "."
		"triple": return "Three of a kind" + _of_at_least(need) + "."
		"quad": return "Four of a kind" + _of_at_least(need) + "."
		"quint": return "Five of a kind" + _of_at_least(need) + "."
		"two_pair": return "Two pairs" + _of_at_least(need) + "."
		"full_house": return "A full house: three of one value and two of another" + (", the three %d or higher" % need if need > 1 else "") + "."
		"straight": return "A straight of %d: %d consecutive values in any order." % [need, need]
		"odd": return "At least %d dice showing odd values." % need
		"even": return "At least %d dice showing even values." % need
		"distinct": return "At least %d dice with no two alike." % need
		"value":
			var wanted: Array = trigger.get("values", [7])
			var names: String = " or ".join(wanted.map(func(v: Variant) -> String: return str(int(v))))
			return "At least %d %s showing a %s." % [need, "die" if need == 1 else "dice", names]
		"at_most": return "At least one die showing %d or less." % need
		"at_least": return "Your highest die shows %d or more." % need
		"total_pct_at_least": return "Your total is at least %d%% of the most your dice could roll." % need
		"total_pct_at_most": return "Your total is at most %d%% of the most your dice could roll." % need
		"high_pct_at_least": return "One die shows at least %d%% of its own top face." % need
		"held": return "At least %d dice you did not reroll." % need
		"rerolled": return "At least %d dice you rerolled this turn." % need
		"resonance": return "Resonance of %d or more when this gem is reached." % need
	return "Its trigger."

static func _of_at_least(need: int) -> String:
	return " of %ds or higher" % need if need > 1 else ""

static func validate(trigger: Variant) -> Array:
	if not trigger is Dictionary:
		return ["trigger must be an object"]
	var errors: Array = []
	var kind: String = str(trigger.get("kind", ""))
	if not kind in KINDS:
		errors.append("unknown trigger kind: " + (kind if not kind.is_empty() else "(none)"))
	var ladder: Variant = trigger.get("ladder", null)
	if ladder != null:
		if not ladder is Array or ladder.size() != STEPS:
			errors.append("trigger ladder must list exactly %d rungs, Poor to Perfect" % STEPS)
		else:
			for step in ladder:
				if not (step is int or step is float) or int(step) != float(step):
					errors.append("trigger ladder rungs must be whole numbers")
					break
	elif kind != "always" and kind != "resonance" and not trigger.has("amount"):
		errors.append("trigger needs a ladder or an amount")
	if kind == "value":
		var wanted: Variant = trigger.get("values", null)
		if not wanted is Array or wanted.is_empty():
			errors.append("a value trigger needs a non-empty values list")
	if trigger.has("read") and not str(trigger.read) in ["high", "low"]:
		errors.append("trigger read must be high or low")
	return errors
