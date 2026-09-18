class_name DeepHand
extends RefCounted
## What a hand of rolls contains, worked out once and read by every trigger and term.
##
## Wild dice join the largest set (ties go to the higher value) and fill the gaps in the
## longest straight. Blank dice are not there. Twin engravings count twice for sets. The
## analysis is a plain dictionary so the rules, the forecast and the tests all read the
## same fields:
##
##   values, total, max_total, high, low, high_pct, held, rerolled, phantoms, dice_count
##   groups        [{value, count, dice}] sorted by count then value, wilds included
##   best_set      the first group
##   pairs         the groups with count >= 2
##   straight      {length, high, low, dice}
##   odd, even     counts (wilds count for both)
##   distinct      number of different values (wilds each count as a new one)
##   wilds         die ids of wild rolls;  gem_face  true if any die shows its gem face
##   ids_by_value  {value: [die ids]}

static func analyze(hand: Array) -> Dictionary:
	var values: Array = []
	var ids_by_value: Dictionary = {}
	var counts: Dictionary = {}
	var wilds: Array = []
	var wild_top: int = 0
	var gem_face: bool = false
	var total: int = 0
	var max_total: int = 0
	var held: int = 0
	var rerolled: int = 0
	var phantoms: int = 0
	var high: int = 0
	var low: int = 0
	var high_pct: int = 0
	var odd: int = 0
	var even: int = 0
	for roll in hand:
		var kind: String = str(roll.get("kind", "plain"))
		var value: int = int(roll.get("value", 0))
		var top: int = maxi(1, int(roll.get("top", value)))
		var id: String = str(roll.get("die_id", ""))
		max_total += top
		if bool(roll.get("phantom", false)):
			phantoms += 1
		if DeepDice.held_for_patterns(roll):
			held += 1
		if int(roll.get("rerolls", 0)) > 0:
			rerolled += 1
		if kind == "gem":
			gem_face = true
		if kind == "wild":
			wilds.append(id)
			wild_top = maxi(wild_top, top)
			total += top
			high_pct = 100
			continue
		if kind == "blank":
			continue
		total += value
		values.append(value)
		high = maxi(high, value)
		low = value if low == 0 else mini(low, value)
		high_pct = maxi(high_pct, int(value * 100 / top))
		if value % 2 == 1:
			odd += 1
		else:
			even += 1
		counts[value] = int(counts.get(value, 0)) + (2 if str(roll.get("engraving", "")) == "twin" else 1)
		if not ids_by_value.has(value):
			ids_by_value[value] = []
		ids_by_value[value].append(id)
	# Sets. The wilds go to the largest group, or make one of their own.
	var best_value: int = 0
	var best_count: int = 0
	for v in counts:
		var c: int = int(counts[v])
		if c > best_count or (c == best_count and int(v) > best_value):
			best_value = int(v)
			best_count = c
	var sets: Dictionary = counts.duplicate()
	if wilds.size() > 0:
		if best_count == 0:
			best_value = wild_top
			sets[wild_top] = wilds.size()
		else:
			sets[best_value] = best_count + wilds.size()
	var groups: Array = []
	for v in sets:
		var value: int = int(v)
		var dice: Array = ids_by_value.get(value, []).duplicate()
		if value == best_value and wilds.size() > 0:
			dice.append_array(wilds)
		groups.append({"value": value, "count": int(sets[v]), "dice": dice})
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.count != b.count:
			return a.count > b.count
		return a.value > b.value)
	var pairs: Array = groups.filter(func(g: Dictionary) -> bool: return int(g.count) >= 2)
	return {"values": values, "wilds": wilds, "gem_face": gem_face, "total": total, "max_total": maxi(1, max_total),
		"high": high if high > 0 else wild_top, "low": low if low > 0 else wild_top, "high_pct": high_pct,
		"held": held, "rerolled": rerolled, "phantoms": phantoms, "dice_count": hand.size(),
		"groups": groups, "best_set": groups[0] if groups.size() > 0 else {"value": 0, "count": 0, "dice": []},
		"pairs": pairs, "straight": _straight(counts.keys(), wilds, ids_by_value, hand.size()),
		"odd": odd + wilds.size(), "even": even + wilds.size(), "distinct": counts.size() + wilds.size(),
		"ids_by_value": ids_by_value}

static func _straight(present_values: Array, wilds: Array, ids_by_value: Dictionary, dice_total: int) -> Dictionary:
	## The longest run of consecutive values, wilds filling gaps, preferring the highest run
	## of that length. Straights count each value once, so twins do not help here.
	var present: Dictionary = {}
	for v in present_values:
		present[int(v)] = true
	var best: Dictionary = {"length": 0, "high": 0, "low": 0, "dice": []}
	var longest: int = mini(dice_total, present.size() + wilds.size())
	for length in range(longest, 0, -1):
		var found_low: int = -1
		for low in range(1, DeepDice.VALUE_CAP - length + 2):
			var missing: int = 0
			for v in range(low, low + length):
				if not present.has(v):
					missing += 1
			if missing <= wilds.size():
				found_low = low
		if found_low > 0:
			var dice: Array = []
			var used_wilds: int = 0
			for v in range(found_low, found_low + length):
				if present.has(v):
					dice.append(str(ids_by_value[v][0]))
				else:
					dice.append(str(wilds[used_wilds]))
					used_wilds += 1
			best = {"length": length, "high": found_low + length - 1, "low": found_low, "dice": dice}
			break
	return best

static func read(analysis: Dictionary, count: int, from_high: bool) -> Dictionary:
	## The N highest (or lowest) dice, as {sum, dice}. Wilds read as the die's top.
	var entries: Array = []
	for v in analysis.get("ids_by_value", {}):
		for id in analysis.ids_by_value[v]:
			entries.append({"value": int(v), "id": str(id)})
	for id in analysis.get("wilds", []):
		entries.append({"value": int(analysis.get("high", 0)), "id": str(id)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.value > b.value if from_high else a.value < b.value)
	var sum: int = 0
	var dice: Array = []
	for index in range(mini(count, entries.size())):
		sum += int(entries[index].value)
		dice.append(str(entries[index].id))
	return {"sum": sum, "dice": dice}

static func matching(analysis: Dictionary, predicate: Callable) -> Array:
	## Die ids whose value satisfies the predicate, plus every wild.
	var dice: Array = []
	for v in analysis.get("ids_by_value", {}):
		if predicate.call(int(v)):
			dice.append_array(analysis.ids_by_value[v])
	dice.append_array(analysis.get("wilds", []))
	return dice
