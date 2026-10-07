class_name DeepPatterns
extends RefCounted
## What a hand has to show before a gem fires.
##
## A trigger is a kind and a ladder of five thresholds indexed by Cut step, Poor to Perfect.
## The ladder is what Cut means: a Perfect stone stands on the loosest rung. Thresholds on
## totals and high dice are percentages of the hand's own maximum, so a d20 bowl and a d4
## bowl are judged against themselves.
##
##   always              fires on every hand; the rung says how many dice it reads. `read` is
##                       high or low, or a five-entry ladder so a Poor cut reads the wrong end
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
##   low_count           at least the rung many dice at or below half their own top
##   crowns              at least the rung many dice on their own top face
##   crowns_at_most      no more than the rung many crowns (Bust reads zero)
##   skip_straight       the rung many different values all of one parity, like 2-4-6-8-10
##   distinct_dominant   the rung many different values and the top die outrolling the rest combined
##
## Creature-only kinds, read from the fight rather than the dice (the context a creature's
## action passes in), each firing at most once an action:
##   each_turn           on the first die of every action
##   every_nth_turn      on the first die of the rung-th action, the 2·rung-th, and so on
##   emerge              on the first die of the action after it burrowed
##   on_death            never during an action: its move fires when the creature dies
##   hp_below            never during an action: fires once, the moment its health first falls
##                       to the rung percent of its most
##   action_begin        as its action opens, before any die is thrown
## A creature's trigger may also name `die`, the index of the one die it reads.
##
## `describe` turns a trigger into the pictograph the interface draws and the sentence a
## tooltip says. Nothing here evaluates content by name.

const KINDS: Array = ["all_odd", "all_even", "always", "pair", "two_pair", "triple", "full_house", "quad", "quint", "straight",
	"odd", "even", "distinct", "value", "at_most", "at_least", "total_pct_at_least", "total_pct_at_most",
	"high_pct_at_least", "held", "rerolled", "resonance", "low_count", "crowns", "crowns_at_most", "skip_straight", "distinct_dominant", "pyrite", "fizzles", "below",
	"each_turn", "every_nth_turn", "emerge", "on_death", "hp_below", "action_begin"]
## The kinds a creature reads from the turn rather than from a die.
const TURN_KINDS: Array = ["each_turn", "every_nth_turn", "emerge", "on_death", "hp_below", "action_begin"]
## The turn kinds that never fire on a die the creature throws: the fight calls them itself.
const CALLED_KINDS: Array = ["on_death", "hp_below", "action_begin"]
const SET_SIZES: Dictionary = {"pair": 2, "triple": 3, "quad": 4, "quint": 5}
const STEPS: int = 5

static func rung(trigger: Dictionary, cut_step: int) -> int:
	var ladder: Array = trigger.get("ladder", [])
	if ladder.is_empty():
		return int(trigger.get("amount", 0))
	return int(ladder[clampi(cut_step, 0, ladder.size() - 1)])

static func read_side(trigger: Dictionary, cut_step: int) -> String:
	## Which end of the hand an `always` trigger reads. A plain "high" or "low" reads the
	## same at every Cut; a five-entry ladder lets a badly cut stone read the wrong end,
	## so a Poor Strike squints at your worst die while a Perfect one takes your best.
	var read: Variant = trigger.get("read", "high")
	if read is Array and not read.is_empty():
		return str(read[clampi(cut_step, 0, read.size() - 1)])
	return str(read)

static func unconditional(kind: String, need: int) -> bool:
	## True when a rung is so low that the trigger asks nothing of the hand. The loosest
	## rung of a gate is how a Perfect stone earns its "fires on every hand".
	match kind:
		"always": return true
		"high_pct_at_least", "total_pct_at_least", "low_count", "held", "rerolled", "crowns", "resonance": return need <= 0
		"distinct": return need <= 1
		"total_pct_at_most": return need >= 100
	return false

static func evaluate(trigger: Dictionary, cut_step: int, a: Dictionary, context: Dictionary = {}) -> Dictionary:
	var kind: String = str(trigger.get("kind", "always"))
	var need: int = rung(trigger, cut_step)
	var result: Dictionary = {"active": false, "dice": [], "kind": kind, "need": need, "value": 0, "count": 0}
	if kind == "always":
		var picked: Dictionary = DeepHand.read(a, maxi(1, need), read_side(trigger, cut_step) != "low")
		result.active = true
		result.dice = picked.dice
		result.value = picked.sum
		result.count = picked.dice.size()
		return result
	if kind in TURN_KINDS:
		## The fight tells a creature which action this is; nothing on the dice does.
		var first: bool = bool(context.get("first_roll", false))
		var acted: int = int(context.get("turns_acted", 0))
		match kind:
			"each_turn": result.active = first
			"every_nth_turn": result.active = first and need > 0 and acted % need == 0
			"emerge": result.active = first and bool(context.get("emerging", false))
			"on_death": result.active = bool(context.get("dying", false))
			"hp_below": result.active = bool(context.get("crossing", false))
			"action_begin": result.active = bool(context.get("action_begin", false))
		result.value = int(a.get("total", 0))
		if result.active:
			result.dice = _all_dice(a)
		else:
			result.reason = {"on_death": "Only when it dies.", "hp_below": "Only as its health falls that far.", "action_begin": "Only as its action opens."}.get(kind, "Not this action.")
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
		"all_odd", "all_even":
			var parity: int = int(a.get("odd" if kind == "all_odd" else "even", 0))
			result.active = int(a.get("dice_count", 0)) >= maxi(2, need) and parity == int(a.get("dice_count", 0))
			result.dice = _all_dice(a)
			result.value = int(a.get("total", 0))
			result.count = parity
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
			## Read off the faces: "showing 1" is a die that landed on its 1, Iron, Doubled or not.
			var wanted: Array = trigger.get("values", [7])
			var dice: Array = DeepHand.matching_shown(a, func(v: int) -> bool: return wanted.has(v) or wanted.has(float(v)))
			if dice.size() >= maxi(1, need):
				result.active = true
				result.dice = dice
				result.count = dice.size()
				result.value = int(wanted[0]) if not wanted.is_empty() else 0
		"at_most", "below":
			var judge: Callable = func(v: int) -> bool: return v < need if kind == "below" else v <= need
			var dice: Array = DeepHand.matching_faces(a, judge) if kind == "below" else DeepHand.matching(a, judge)
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
		"pyrite":
			result.active = int(context.get("pyrite", 0)) >= need
			result.value = int(context.get("pyrite", 0))
		"fizzles":
			## Gems that stayed dark earlier this turn and have not yet paid this stone.
			result.active = int(context.get("fizzles", 0)) >= need
			result.count = int(context.get("fizzles", 0))
			result.value = int(context.get("fizzles", 0))
		"resonance":
			if int(context.get("resonance", 0)) >= need:
				result.active = true
				result.value = int(context.get("resonance", 0))
		"low_count":
			if int(a.get("low_dice", 0)) >= need:
				result.active = true
				result.dice = a.get("low_ids", []).duplicate()
				result.count = int(a.low_dice)
				result.value = int(a.low_dice)
		"crowns":
			if int(a.get("crowns", 0)) >= need:
				result.active = true
				result.dice = a.get("crown_ids", []).duplicate()
				result.count = int(a.crowns)
				result.value = int(a.crowns)
		"crowns_at_most":
			if int(a.get("crowns", 0)) <= need:
				result.active = true
				result.count = int(a.get("crowns", 0))
				result.value = int(a.get("crowns", 0))
		"skip_straight":
			var odd_values: int = int(a.get("odd_values", 0))
			var even_values: int = int(a.get("even_values", 0))
			if maxi(odd_values, even_values) >= need:
				result.active = true
				var want_odd: bool = odd_values >= even_values
				var dice: Array = []
				for v in a.get("ids_by_value", {}):
					if (int(v) % 2 == 1) == want_odd:
						dice.append(str(a.ids_by_value[v][0]))
				dice.append_array(a.get("wilds", []))
				result.dice = dice
				result.count = maxi(odd_values, even_values)
				result.value = int(a.get("high", 0))
				result.odd = want_odd
		"distinct_dominant":
			if int(a.get("distinct", 0)) >= need and int(a.get("high", 0)) * 2 > int(a.get("total", 0)):
				result.active = true
				var dice: Array = []
				for v in a.get("ids_by_value", {}):
					dice.append(str(a.ids_by_value[v][0]))
				dice.append_array(a.get("wilds", []))
				result.dice = dice
				result.count = int(a.distinct)
				result.value = int(a.high)
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
	if kind != "always" and unconditional(kind, need):
		## A rung this loose is no rung at all: the stone is drawn as one that always fires.
		return {"mark": "read_high", "kind": kind, "need": need, "label": "", "words": words(trigger, cut_step)}
	match kind:
		"always":
			mark = "read_high" if read_side(trigger, cut_step) != "low" else "read_low"
			label = "×%d" % maxi(1, need) if need > 1 else ""
		"pair", "triple", "quad", "quint", "full_house":
			label = "%d+" % need if need > 1 else ""
		"two_pair":
			label = "%d+" % need if need > 1 else ""
		"straight", "odd", "even", "distinct", "held", "rerolled", "resonance", "low_count", "crowns", "skip_straight", "distinct_dominant":
			label = "×%d" % need
		"crowns_at_most":
			label = "≤%d" % need
		"value":
			var wanted: Array = trigger.get("values", [7])
			label = "/".join(wanted.map(func(v: Variant) -> String: return str(int(v))))
			if need > 1:
				label += " ×%d" % need
		"pyrite":
			label = "≥%d Pyrite" % need
		"fizzles":
			label = "×%d" % need if need > 1 else ""
		"below":
			label = "<%d" % need
		"each_turn", "emerge":
			mark = "hourglass"
		"every_nth_turn":
			mark = "hourglass"
			label = "÷%d" % need
		"on_death":
			mark = "skull"
		"hp_below":
			mark = "skull"
			label = "≤%d%%" % need
		"action_begin":
			mark = "hourglass"
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
	if kind != "always" and unconditional(kind, need):
		return "Fires on every hand."
	match kind:
		"always":
			var count: int = maxi(1, need)
			var side: String = "lowest" if read_side(trigger, cut_step) == "low" else "highest"
			return "Fires on every hand and reads your %s die." % side if count == 1 else "Fires on every hand and reads your %s %d dice." % [side, count]
		"all_odd": return "All dice odd (%d or more)." % maxi(2, need)
		"all_even": return "All dice even (%d or more)." % maxi(2, need)
		"pair": return "A pair" + _of_at_least(need) + "."
		"triple": return "Three of a kind" + _of_at_least(need) + "."
		"quad": return "Four of a kind" + _of_at_least(need) + "."
		"quint": return "Five of a kind" + _of_at_least(need) + "."
		"two_pair": return "Two pairs" + _of_at_least(need) + "."
		"full_house": return "A full house: three of one value and two of another" + (", the three %d or higher" % need if need > 1 else "") + "."
		"straight": return "A straight of %d: %d consecutive values in any order." % [need, need]
		"odd": return "At least %s showing odd values." % _dice(need)
		"even": return "At least %s showing even values." % _dice(need)
		"distinct": return "At least %s with no two alike." % _dice(need)
		"value":
			var wanted: Array = trigger.get("values", [7])
			var names: String = " or ".join(wanted.map(func(v: Variant) -> String: return str(int(v))))
			return "At least %d %s showing a %s." % [need, "die" if need == 1 else "dice", names]
		"pyrite": return "At least %d Pyrite." % need
		"fizzles": return "At least %d %s fizzled earlier this turn." % [need, "gem" if need == 1 else "gems"]
		"below": return "At least one die showing less than %d." % need
		"at_most": return "At least one die showing %d or less." % need
		"at_least": return "Your highest die shows %d or more." % need
		"total_pct_at_least": return "Your total is at least %d%% of the most your dice could roll." % need
		"total_pct_at_most": return "Your total is at most %d%% of the most your dice could roll." % need
		"high_pct_at_least": return "One die shows at least %d%% of its own top face." % need
		"held": return "At least %s you did not reroll." % _dice(need)
		"rerolled": return "At least %s you rerolled this turn." % _dice(need)
		"resonance": return "Resonance of %d or more when this gem is reached." % need
		"low_count": return "At least %s at or below half its own top face." % _dice(need) if need == 1 else "At least %s at or below half their own top face." % _dice(need)
		"crowns": return "At least %d %s showing %s own top face." % [need, "die" if need == 1 else "dice", "its" if need == 1 else "their"]
		"crowns_at_most": return "No die on its top face." if need == 0 else "No more than %d dice on their top face." % need
		"skip_straight": return "%d different values, all odd or all even, like 2-4-6-8-10." % need
		"distinct_dominant": return "%d different values, the highest die outrolling the other %d combined." % [need, need - 1]
		"each_turn": return "Every action, once, before its dice."
		"every_nth_turn": return "Every %s action, once, before its dice." % _ordinal(need)
		"emerge": return "The action after it burrowed, once, before its dice."
		"on_death": return "When it dies."
		"hp_below": return "Once, the moment its health falls to %d%%." % need
		"action_begin": return "Every action, as it opens, before any die is thrown."
	return "Its trigger."

static func _ordinal(n: int) -> String:
	match n:
		1: return "first"
		2: return "second"
		3: return "third"
		4: return "fourth"
		5: return "fifth"
	return "%dth" % n

static func _dice(need: int) -> String:
	return "%d %s" % [need, "die" if need == 1 else "dice"]

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
	elif kind != "always" and kind != "resonance" and not kind in ["each_turn", "emerge", "on_death", "action_begin"] and not trigger.has("amount"):
		errors.append("trigger needs a ladder or an amount")
	if kind == "every_nth_turn" and int(trigger.get("amount", 0)) < 2:
		errors.append("every_nth_turn needs an amount of 2 or more")
	if trigger.has("die") and (not (trigger.die is int or trigger.die is float) or int(trigger.die) < 0):
		errors.append("a trigger's die is the index of the die it reads, 0 or more")
	if kind == "value":
		var wanted: Variant = trigger.get("values", null)
		if not wanted is Array or wanted.is_empty():
			errors.append("a value trigger needs a non-empty values list")
	if trigger.has("read"):
		var read: Variant = trigger.read
		if read is Array:
			if read.size() != STEPS:
				errors.append("a trigger read ladder lists exactly %d sides, Poor to Perfect" % STEPS)
			for side in read:
				if not str(side) in ["high", "low"]:
					errors.append("trigger read must be high or low")
					break
		elif not str(read) in ["high", "low"]:
			errors.append("trigger read must be high or low")
	return errors
