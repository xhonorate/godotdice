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
##   distinct            at least the rung many different values; `high_crown` asks the highest die
##                       to be a crown as well (Clean Kill)
##   value               at least the rung many dice showing one of `values`
##   at_most             at least one die showing the rung or less (Ember reads ones)
##   at_least            the highest die shows the rung or more, as an absolute value
##   total_pct_at_least / total_pct_at_most   the total against the hand's maximum, in percent
##   high_pct_at_least   the best die against its die's size, in percent (a 6 on a d6 is 100)
##   held / rerolled     at least the rung many dice held (or rerolled) this turn
##   resonance           the rail's Resonance is at least the rung
##   low_count           at least the rung many dice in the low half of their size (a wild is low)
##   crowns              at least the rung many dice on their own top face
##   crowns_at_most      no more than the rung many crowns (Bust reads zero)
##   skip_straight       the rung many different values all of one parity, like 2-4-6-8-10
##   distinct_dominant   the rung many different values and the top die outrolling the rest combined
##   kills               at least the rung many creatures have died this turn (the fight says how many)
##   high_count          at least the rung many dice showing `value` or more (Renown reads sixes and up)
##   total_at_most       the total is the rung or less, as a number and not a share (a wild reads as 1)
##   total_window        the total is the rung or more and no more than `max`; with no `max`, the rung or more
##   scale               a climb at least the rung long across the dice from the smallest die to the
##                       largest, each showing more than the one before it (see DeepHand)
##   all_faces           every die on its own top face or on a 1 (Highs and Lows), two dice at the least
##   colors              at least the rung many of the six colors have fired on this rail this turn
##                       (the fight says how many)
##   set                 a set at least the rung big and no bigger than `max`: every such set is read
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
##   countdown           on the first die of the action its countdown from the rung reaches 0;
##                       then it starts again (the fight keeps the count, `DeepCreatures.countdown_in`)
## A creature's trigger may also name `die`, the index of the one die it reads.
##
## `describe` turns a trigger into the pictograph the interface draws and the sentence a
## tooltip says. Nothing here evaluates content by name.

const KINDS: Array = ["all_odd", "all_even", "always", "pair", "two_pair", "triple", "full_house", "quad", "quint", "straight",
	"odd", "even", "distinct", "value", "at_most", "at_least", "total_pct_at_least", "total_pct_at_most",
	"high_pct_at_least", "held", "rerolled", "resonance", "low_count", "crowns", "crowns_at_most", "skip_straight", "distinct_dominant", "pyrite", "fizzles", "below", "kills",
	"high_count", "total_at_most", "total_window", "scale", "all_faces", "colors", "set",
	"each_turn", "every_nth_turn", "emerge", "on_death", "hp_below", "action_begin", "countdown",
	## A creature's action dice: a move fires when its own face lands (`face`), or when the
	## faces it names have landed together in one action (`match`). See creatures.gd.
	"face", "match"]
## The kinds a creature reads from the turn rather than from a die.
const TURN_KINDS: Array = ["each_turn", "every_nth_turn", "emerge", "on_death", "hp_below", "action_begin", "countdown"]
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
			"countdown": result.active = first and bool(context.get("countdown_due", false))
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
			if not result.active:
				## The wilds went to the largest set, which was too low: they may lift another.
				var lifted: Dictionary = _wild_set(a, int(SET_SIZES[kind]), need)
				if not lifted.is_empty():
					result.active = true
					result.dice = lifted.dice
					result.value = int(lifted.value)
					result.count = int(lifted.count)
		"two_pair":
			## `high_pair`: only the higher of the two pairs has to clear the rung (Mirror's).
			var qualifying: Array = a.get("pairs", []).filter(func(g: Dictionary) -> bool: return int(g.value) >= need)
			if bool(trigger.get("high_pair", false)):
				qualifying = a.get("pairs", []).duplicate()
				qualifying.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.value) > int(y.value))
				if qualifying.size() >= 2 and int(qualifying[0].value) < need:
					qualifying = []
			if qualifying.size() >= 2:
				result.active = true
				result.dice = qualifying[0].dice + qualifying[1].dice
				result.value = int(qualifying[0].value)
				result.second = int(qualifying[1].value)
				result.count = 4
			else:
				## All the wilds joined one set; split between two they may make both.
				var both: Dictionary = _wild_sets(a, 2, 2, need, bool(trigger.get("high_pair", false)))
				if not both.is_empty():
					result.active = true
					result.dice = both.dice
					result.value = int(both.value)
					result.second = int(both.second)
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
			if not result.active:
				var house: Dictionary = _wild_sets(a, 3, 2, need, false)
				if not house.is_empty():
					result.active = true
					result.dice = house.dice
					result.value = int(house.value)
					result.second = int(house.second)
					result.count = 5
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
			## `high_crown`: the highest die has to be on its top face as well (Clean Kill's).
			if int(a.get("distinct", 0)) >= need and (not bool(trigger.get("high_crown", false)) or int(a.get("high_crown", 0)) > 0):
				result.active = true
				var dice: Array = []
				for v in a.get("ids_by_value", {}):
					dice.append(str(a.ids_by_value[v][0]))
				dice.append_array(a.get("wilds", []))
				result.dice = dice
				result.count = int(a.distinct)
				result.value = int(a.distinct)
		"value":
			## Read off the faces: "showing 1" is a die that landed on its 1, Doubled or not.
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
			## A wild is any value, so a gem that wants a low total reads it as a 1.
			var low_total: int = int(a.get("total", 0)) - int(a.get("wild_total", 0)) + a.get("wilds", []).size()
			if low_total * 100 <= int(a.get("max_total", 1)) * need:
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
		"kills":
			## Creatures fallen this turn, before this gem: the fight counts them, not the dice.
			result.active = int(context.get("kills", 0)) >= maxi(1, need)
			result.count = int(context.get("kills", 0))
			result.value = int(context.get("kills", 0))
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
		"high_count":
			var floor_value: int = int(trigger.get("value", 6))
			var dice: Array = DeepHand.matching(a, func(v: int) -> bool: return v >= floor_value)
			if dice.size() >= maxi(1, need):
				result.active = true
				result.dice = dice
				result.count = dice.size()
				result.value = floor_value
		"total_at_most":
			var quiet: int = int(a.get("total", 0)) - int(a.get("wild_total", 0)) + a.get("wilds", []).size()
			if int(a.get("dice_count", 0)) > 0 and quiet <= need:
				result.active = true
				result.dice = _all_dice(a)
				result.value = quiet
				result.count = result.dice.size()
		"total_window":
			var most: int = int(trigger.get("max", -1))
			if int(a.get("dice_count", 0)) > 0 and int(a.get("total", 0)) >= need and (most < 0 or int(a.get("total", 0)) <= most):
				result.active = true
				result.dice = _all_dice(a)
				result.value = int(a.get("total", 0))
				result.count = result.dice.size()
		"scale":
			var climb: Dictionary = a.get("scale", {})
			if int(climb.get("length", 0)) >= maxi(1, need):
				result.active = true
				result.dice = climb.get("dice", []).duplicate()
				result.count = int(climb.get("length", 0))
				result.value = int(climb.get("total", 0))
		"all_faces":
			var faced: Array = a.get("crown_ids", []).duplicate()
			for id in a.get("one_ids", []):
				if not faced.has(id):
					faced.append(id)
			if int(a.get("dice_count", 0)) >= maxi(2, need) and faced.size() >= int(a.get("dice_count", 0)):
				result.active = true
				result.dice = faced
				result.count = faced.size()
				result.value = faced.size()
		"colors":
			result.active = int(context.get("colors", 0)) >= maxi(1, need)
			result.count = int(context.get("colors", 0))
			result.value = int(context.get("colors", 0))
		"set":
			var biggest: int = int(trigger.get("max", 0))
			var found: Array = []
			for group in a.get("groups", []):
				if int(group.count) >= maxi(2, need) and (biggest <= 0 or int(group.count) <= biggest):
					found.append({"value": int(group.value), "count": int(group.count), "dice": group.dice.duplicate()})
			if not found.is_empty():
				result.active = true
				result.sets = found
				var dice: Array = []
				for group in found:
					dice.append_array(group.dice)
				result.dice = dice
				result.value = int(found[0].value)
				result.count = int(found[0].count)
	if not result.active:
		result.reason = words(trigger, cut_step)
	return result

static func _wild_set(a: Dictionary, size: int, need: int) -> Dictionary:
	## A set of `size` at or above `need` with every wild joining it, the most dice and then
	## the highest value first; the wilds alone make one at their top. Empty when none can.
	var wilds: Array = a.get("wilds", [])
	if wilds.is_empty():
		return {}
	var best: Dictionary = {}
	for group in a.get("plain_groups", []):
		var count: int = int(group.count) + wilds.size()
		if int(group.value) >= need and count >= size and (best.is_empty() or count > int(best.count) or (count == int(best.count) and int(group.value) > int(best.value))):
			best = {"value": int(group.value), "count": count, "dice": group.dice + wilds}
	var top: int = _wild_top(a)
	if best.is_empty() and wilds.size() >= size and top >= need:
		best = {"value": top, "count": wilds.size(), "dice": wilds.duplicate()}
	return best

static func _wild_sets(a: Dictionary, first: int, second: int, need: int, high_only: bool) -> Dictionary:
	## Two sets of different values, `first` and `second` dice big, with the wilds placed where
	## they complete them; the highest values first. The first must reach `need`, and so must
	## the second unless `high_only` (two pairs: the higher; a full house: its three).
	var wilds: Array = a.get("wilds", [])
	if wilds.is_empty():
		return {}
	var counts: Dictionary = {}
	var dice_of: Dictionary = {}
	for group in a.get("plain_groups", []):
		counts[int(group.value)] = int(group.count)
		dice_of[int(group.value)] = group.dice
	## A value no die shows can be made of wilds alone: the two highest under their top will do.
	var values: Array = counts.keys()
	var top: int = _wild_top(a)
	var spare: int = 0
	for v in range(top, 0, -1):
		if spare >= 2:
			break
		if not counts.has(v):
			values.append(v)
			spare += 1
	var symmetric: bool = first == second
	var best: Dictionary = {}
	for x in values:
		for y in values:
			if x == y or (symmetric and x < y):
				continue
			var cost: int = maxi(0, first - int(counts.get(x, 0))) + maxi(0, second - int(counts.get(y, 0)))
			if cost > wilds.size():
				continue
			if int(x) < need or (symmetric and not high_only and int(y) < need):
				continue
			if not best.is_empty() and (x < int(best.value) or (x == int(best.value) and y <= int(best.second))):
				continue
			var used_x: int = maxi(0, first - int(counts.get(x, 0)))
			var dice: Array = dice_of.get(x, []).duplicate() + wilds.slice(0, used_x) + dice_of.get(y, []) + wilds.slice(used_x, cost)
			best = {"value": x, "second": y, "dice": dice}
	return best

static func _wild_top(a: Dictionary) -> int:
	var top: int = 0
	var tops: Dictionary = a.get("wild_tops", {})
	for id in a.get("wilds", []):
		top = maxi(top, int(tops.get(str(id), 0)))
	return top

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
		"countdown":
			mark = "hourglass"
			label = "%d…0" % need
		"on_death":
			mark = "skull"
		"kills":
			mark = "skull"
			label = "×%d" % need if need > 1 else ""
		"hp_below":
			mark = "skull"
			label = "≤%d%%" % need
		"action_begin":
			mark = "hourglass"
		"at_most":
			label = "≤%d" % need
		"at_least":
			label = "≥%d" % need
		"high_count":
			label = "%d+ ×%d" % [int(trigger.get("value", 6)), maxi(1, need)]
		"total_at_most":
			label = "≤%d" % need
		"total_window":
			var most: int = int(trigger.get("max", -1))
			label = "≥%d" % need if most < 0 else ("=%d" % need if most == need else "%d-%d" % [need, most])
		"scale", "colors":
			label = "×%d" % maxi(1, need)
		"set":
			var biggest: int = int(trigger.get("max", 0))
			label = "×%d" % maxi(2, need) if biggest == maxi(2, need) else ("×%d+" % maxi(2, need) if biggest <= 0 else "×%d-%d" % [maxi(2, need), biggest])
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
		"two_pair":
			if bool(trigger.get("high_pair", false)) and need > 1:
				return "Two pairs, the higher one %d or more." % need
			return "Two pairs" + _of_at_least(need) + "."
		"full_house": return "A full house: three of one value and two of another" + (", the three %d or higher" % need if need > 1 else "") + "."
		"straight": return "A straight of %d: %d consecutive values in any order." % [need, need]
		"odd": return "At least %s showing odd values." % _dice(need)
		"even": return "At least %s showing even values." % _dice(need)
		"distinct":
			if bool(trigger.get("high_crown", false)):
				return "At least %s with no two alike, the highest a crown." % _dice(need)
			return "At least %s with no two alike." % _dice(need)
		"value":
			var wanted: Array = trigger.get("values", [7])
			var names: String = " or ".join(wanted.map(func(v: Variant) -> String: return str(int(v))))
			return "At least %d %s showing a %s." % [need, "die" if need == 1 else "dice", names]
		"pyrite": return "At least %d Pyrite." % need
		"fizzles": return "At least %d %s fizzled earlier this turn." % [need, "gem" if need == 1 else "gems"]
		"kills": return "At least %d %s died this turn." % [maxi(1, need), "creature has" if maxi(1, need) == 1 else "creatures have"]
		"below": return "At least one die showing less than %d." % need
		"at_most": return "At least one die showing %d or less." % need
		"at_least": return "Your highest die shows %d or more." % need
		"total_pct_at_least": return "Your total is at least %d%% of the most your dice could roll." % need
		"total_pct_at_most": return "Your total is at most %d%% of the most your dice could roll." % need
		"high_pct_at_least": return "One die showing at least %d%% of its size (a 6 on a d6 is 100%%)." % need
		"held": return "At least %s you did not reroll." % _dice(need)
		"rerolled": return "At least %s you rerolled this turn." % _dice(need)
		"resonance": return "Resonance of %d or more when this gem is reached." % need
		"low_count": return "At least one die in the low half of its size (1-3 on a d6)." if need == 1 else "At least %s in the low half of their size (1-3 on a d6)." % _dice(need)
		"crowns": return "At least %d %s: %s on %s own top face." % [need, "crown" if need == 1 else "crowns", "a die" if need == 1 else "dice", "its" if need == 1 else "their"]
		"crowns_at_most": return "No crowns: no die on its top face." if need == 0 else "No more than %d %s." % [need, "crown" if need == 1 else "crowns"]
		"skip_straight": return "%d different values, all odd or all even, like 2-4-6-8-10." % need
		"distinct_dominant": return "%d different values, the highest die outrolling the other %d combined." % [need, need - 1]
		"high_count":
			return "At least %s showing %d or more." % [_dice(maxi(1, need)), int(trigger.get("value", 6))]
		"total_at_most": return "Your total is %d or less." % need
		"total_window":
			var most: int = int(trigger.get("max", -1))
			if most < 0:
				return "Your total is %d or more." % need
			return "Your total is exactly %d." % need if most == need else "Your total is from %d to %d." % [need, most]
		"scale": return "A scale of %d: dice that climb from your smallest die to your largest, each showing more than the last." % maxi(1, need)
		"all_faces": return "Every die on its own top face or on a 1."
		"colors": return "At least %d different colors have fired this turn." % maxi(1, need)
		"set":
			var biggest: int = int(trigger.get("max", 0))
			var least: int = maxi(2, need)
			if biggest == least:
				return "A set of exactly %d matching dice." % least
			return "A set of %d or more matching dice." % least if biggest <= 0 else "A set of %d to %d matching dice." % [least, biggest]
		"each_turn": return "Every action, once, before its dice."
		"every_nth_turn": return "Every %s action, once, before its dice." % _ordinal(need)
		"countdown": return "When its countdown from %d reaches 0, once, before its dice." % need
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
	elif kind != "always" and kind != "resonance" and not kind in ["each_turn", "emerge", "on_death", "action_begin", "face", "match"] and not trigger.has("amount"):
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
