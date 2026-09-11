class_name RogueGemRules
extends RefCounted
## A gem's rule, written as data instead of code.
##
## A skill the build ships names its behaviour in `combat.gd`. A skill authored in the
## content studio can instead carry a `rule`: a trigger that says when it fires and a list
## of effects whose amounts are arithmetic over the hand. This file is the interpreter for
## that little language, and it is deliberately small — a fixed vocabulary of terms, a
## fixed set of operators, integers only, no loops, no names it did not define itself, and
## no way to reach anything outside the hand it was handed. A pack is still data: the worst
## a malformed rule can do is fail validation.
##
## The vocabulary is the one the shipped formulas already speak, so an authored rule reads
## the same quantities the hand-written ones do:
##
##   {"trigger": {"kind": "pair"},
##    "effects": [{"kind": "block", "target": "self", "scale": "carat",
##                 "amount": {"op": "+", "args": [{"op": "*", "args": [
##                     {"term": "pair_value"}, {"rank": "cut"}]}, {"rank": "clarity_bonus"}]}}]}
##
## …is Block, exactly as `combat.gd` resolves it. `evaluate()` returns the same shape the
## match statement in `preview()` produces, so neither the resolver nor the interface can
## tell an authored rule from a compiled one.
##
## Every amount floors exactly once, in `_scaled()`, which is the same contract the
## compiled rules keep: the Carat multiplier is applied last, to the whole term.

## What a trigger may test. Each one also decides which dice the panel highlights.
const TRIGGERS: Array = ["always", "pair", "two_pairs", "triple", "full_house", "straight",
	"parity", "distinct", "value", "total_at_least", "total_at_most", "high_at_least"]
## What a rule may read off the hand.
const TERMS: Array = ["high", "low", "total", "pair_value", "triple_value", "run_high",
	"highest_sum", "lowest_sum", "lowest_odd", "count_even", "count_odd", "count_distinct",
	"count_value", "block"]
## The three rolled properties, as numbers a rule may use.
const RANKS: Array = ["carat", "cut", "clarity", "clarity_bonus"]
const OPERATORS: Array = ["+", "-", "*", "floor_div", "min", "max", "by_cut"]
## What an effect may do. These are the kinds `combat.gd` already knows how to apply.
const EFFECT_KINDS: Array = ["damage", "block", "heal", "gold", "poison", "stun", "remove_block"]
const EFFECT_TARGETS: Array = ["self", "enemy", "enemies", "ally", "other_allies"]
## Bounds. A rule is a sentence, not a program: these keep it one.
const MAX_EFFECTS: int = 6
const MAX_DEPTH: int = 6
const MAX_NODES: int = 60
const MAX_REPEAT: int = 8
const VALUE_LIMIT: int = 9999

static func has_rule(definition: Dictionary) -> bool:
	var rule: Variant = definition.get("rule", null)
	return rule is Dictionary and not rule.is_empty()

# --- validation ---------------------------------------------------------------

static func validate(rule: Variant) -> Array:
	## Everything wrong with a rule, in the order an author would fix it.
	if not rule is Dictionary:
		return ["rule must be an object"]
	var errors: Array = []
	for field in rule:
		if not str(field) in ["trigger", "effects"]:
			errors.append("unknown rule field: " + str(field))
	errors.append_array(_validate_trigger(rule.get("trigger", {})))
	var effects: Variant = rule.get("effects", null)
	if not effects is Array or effects.is_empty():
		errors.append("a rule needs at least one effect")
		return errors
	if effects.size() > MAX_EFFECTS:
		errors.append("a rule may carry at most %d effects" % MAX_EFFECTS)
	for index in range(mini(effects.size(), MAX_EFFECTS)):
		errors.append_array(_validate_effect(effects[index], index))
	return errors

static func _validate_trigger(trigger: Variant) -> Array:
	if not trigger is Dictionary:
		return ["trigger must be an object"]
	var kind: String = str(trigger.get("kind", ""))
	if not kind in TRIGGERS:
		return ["unknown trigger: " + (kind if not kind.is_empty() else "(none)")]
	var errors: Array = []
	match kind:
		"straight":
			if not _by_clarity(trigger.get("length", null)):
				errors.append_array(_validate_expression(trigger.get("length", {}), "trigger length", 1))
		"parity":
			if not str(trigger.get("parity", "")) in ["even", "odd"]:
				errors.append("trigger parity must be even or odd")
			errors.append_array(_validate_expression(trigger.get("at_least", {}), "trigger count", 1))
		"distinct":
			errors.append_array(_validate_expression(trigger.get("at_least", {}), "trigger count", 1))
		"value":
			var value: Variant = trigger.get("value", null)
			if not _whole(value) or int(value) < 1 or int(value) > 20:
				errors.append("trigger value must be a die value from 1 to 20")
		"total_at_least", "total_at_most", "high_at_least":
			errors.append_array(_validate_expression(trigger.get("amount", {}), "trigger threshold", 1))
	return errors

static func _validate_effect(effect: Variant, index: int) -> Array:
	var where: String = "effect %d" % (index + 1)
	if not effect is Dictionary:
		return [where + " must be an object"]
	var errors: Array = []
	for field in effect:
		if not str(field) in ["kind", "target", "amount", "scale", "repeat", "target_limit"]:
			errors.append(where + ": unknown field " + str(field))
	if not str(effect.get("kind", "")) in EFFECT_KINDS:
		errors.append(where + ": unknown effect kind " + str(effect.get("kind", "(none)")))
	if not str(effect.get("target", "self")) in EFFECT_TARGETS:
		errors.append(where + ": unknown target " + str(effect.get("target", "")))
	if not str(effect.get("scale", "carat")) in ["carat", "none"]:
		errors.append(where + ": scale must be carat or none")
	errors.append_array(_validate_expression(effect.get("amount", {}), where + " amount", 1))
	if effect.has("repeat"):
		errors.append_array(_validate_expression(effect.repeat, where + " repeat", 1))
	if effect.has("target_limit"):
		errors.append_array(_validate_expression(effect.target_limit, where + " target limit", 1))
	return errors

static func _validate_expression(expression: Variant, where: String, depth: int) -> Array:
	if depth > MAX_DEPTH:
		return [where + ": nested too deeply (limit %d)" % MAX_DEPTH]
	if not expression is Dictionary or expression.is_empty():
		return [where + ": must be a number, a term, a rank or an operation"]
	if expression.has("const"):
		if not _whole(expression["const"]) or absi(int(expression["const"])) > VALUE_LIMIT:
			return [where + ": a constant must be a whole number within ±%d" % VALUE_LIMIT]
		return []
	if expression.has("rank"):
		return [] if str(expression.rank) in RANKS else [where + ": unknown rank " + str(expression.rank)]
	if expression.has("term"):
		var term: String = str(expression.term)
		if not term in TERMS:
			return [where + ": unknown term " + term]
		if term in ["highest_sum", "lowest_sum"]:
			return _validate_expression(expression.get("count", {}), where + " count", depth + 1)
		if term == "count_value":
			var value: Variant = expression.get("value", null)
			return [] if _whole(value) and int(value) >= 1 and int(value) <= 20 else [where + ": count_value needs a die value from 1 to 20"]
		return []
	if expression.has("op"):
		var operator: String = str(expression.op)
		if not operator in OPERATORS:
			return [where + ": unknown operator " + operator]
		var args: Variant = expression.get("args", null)
		if not args is Array or args.is_empty() or args.size() > 4:
			return [where + ": " + operator + " needs one to four arguments"]
		if operator == "by_cut" and args.size() != 1:
			return [where + ": by_cut takes exactly one argument"]
		if operator in ["-", "floor_div"] and args.size() != 2:
			return [where + ": " + operator + " takes exactly two arguments"]
		var errors: Array = []
		for argument in args:
			errors.append_array(_validate_expression(argument, where, depth + 1))
		return errors
	return [where + ": must be a number, a term, a rank or an operation"]

static func _by_clarity(length: Variant) -> bool:
	## The one non-numeric length: the straight each Clarity rank shortens by itself. Kept
	## as its own test because comparing a Dictionary to a String is an error, not a false.
	return length is String and str(length) == "by_clarity"

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))

static func node_count(expression: Variant) -> int:
	if not expression is Dictionary:
		return 0
	var count: int = 1
	for argument in expression.get("args", []):
		count += node_count(argument)
	if expression.has("count"):
		count += node_count(expression.count)
	return count

# --- evaluation ---------------------------------------------------------------

static func evaluate(rule: Dictionary, context: Dictionary) -> Dictionary:
	## Runs the rule against one hand. `context` is what `combat.gd` has already worked out
	## about that hand; the returned shape is what its match statement produces.
	var trigger: Dictionary = _fire(rule.get("trigger", {}), context)
	var output: Dictionary = {"active": trigger.active, "selected": trigger.selected.duplicate(), "effects": []}
	if not trigger.active:
		return output
	var working: Dictionary = context.duplicate()
	working.run = trigger.get("run", [])
	working.selected = output.selected
	for effect in rule.get("effects", []):
		var repeat: int = clampi(_value(effect.get("repeat", {"const": 1}), working), 0, MAX_REPEAT)
		for _hit in range(repeat):
			var amount: int = _scaled(_value(effect.get("amount", {"const": 0}), working),
				str(effect.get("scale", "carat")), int(working.get("carat", 1)))
			var built: Dictionary = {"kind": str(effect.kind), "amount": maxi(0, amount),
				"target": str(effect.get("target", "self"))}
			if effect.has("target_limit"):
				built.target_limit = maxi(1, _value(effect.target_limit, working))
			output.effects.append(built)
	output.selected = working.selected
	return output

static func threshold(expression: Variant, carat: int, cut: int, clarity: int) -> int:
	## An amount that depends only on the gem's ranks — a trigger's cut-off, a target limit —
	## worked out with no hand behind it, for the parts of the interface drawn before a roll.
	return _value(expression, {"carat": carat, "cut": cut, "clarity": clarity,
		"hand": [], "groups": {}, "total": 0, "high": 0, "block": 0, "selected": [], "run": []})

static func _scaled(amount: int, scale: String, carat: int) -> int:
	## The one place an authored amount is rounded, so it floors exactly once like the rest.
	if scale == "none":
		return amount
	return floori(float(amount) * float(clampi(carat, 1, 24) + 7) / 8.0)

static func _fire(trigger: Dictionary, context: Dictionary) -> Dictionary:
	var groups: Dictionary = context.get("groups", {})
	var kind: String = str(trigger.get("kind", "always"))
	match kind:
		"always":
			return {"active": true, "selected": []}
		"pair", "triple":
			var wanted: int = 2 if kind == "pair" else 3
			var matches: Array = _matching(groups, wanted)
			if matches.is_empty():
				return {"active": false, "selected": []}
			return {"active": true, "selected": groups[matches.back()].slice(0, wanted)}
		"two_pairs":
			var pairs: Array = _matching(groups, 2)
			if pairs.size() < 2:
				return {"active": false, "selected": []}
			return {"active": true, "selected": groups[pairs[pairs.size() - 1]].slice(0, 2) + groups[pairs[pairs.size() - 2]].slice(0, 2)}
		"full_house":
			var triples: Array = _matching(groups, 3)
			if triples.is_empty():
				return {"active": false, "selected": []}
			for value in _matching(groups, 2):
				if value != triples.back():
					return {"active": true, "selected": groups[triples.back()].slice(0, 3) + groups[value].slice(0, 2)}
			return {"active": false, "selected": []}
		"straight":
			var length: int = int(context.get("straight_length", 3)) if _by_clarity(trigger.get("length", null)) else _value(trigger.get("length", {"const": 3}), context)
			var run: Array = _straight(groups, clampi(length, 1, 5))
			if run.is_empty():
				return {"active": false, "selected": []}
			var chosen: Array = []
			for value in run:
				chosen.append(groups[value][0])
			return {"active": true, "selected": chosen, "run": run}
		"parity":
			var wanted_odd: bool = str(trigger.get("parity", "even")) == "odd"
			var chosen: Array = []
			for roll in context.get("hand", []):
				if (int(roll.value) % 2 == 1) == wanted_odd:
					chosen.append(roll.die_id)
			return {"active": chosen.size() >= _value(trigger.get("at_least", {"const": 3}), context), "selected": chosen}
		"distinct":
			var chosen: Array = []
			for value in groups:
				chosen.append(groups[value][0])
			return {"active": groups.size() >= _value(trigger.get("at_least", {"const": 5}), context), "selected": chosen}
		"value":
			var wanted_value: int = int(trigger.get("value", 7))
			var found: Array = groups.get(wanted_value, [])
			return {"active": not found.is_empty(), "selected": found.duplicate()}
		"total_at_least":
			return {"active": int(context.get("total", 0)) >= _value(trigger.get("amount", {"const": 0}), context), "selected": _all(context)}
		"total_at_most":
			return {"active": int(context.get("total", 0)) <= _value(trigger.get("amount", {"const": 0}), context), "selected": _all(context)}
		"high_at_least":
			var threshold: int = _value(trigger.get("amount", {"const": 0}), context)
			var high: int = int(context.get("high", 0))
			return {"active": high >= threshold, "selected": groups.get(high, []).slice(0, 1)}
	return {"active": false, "selected": []}

static func _all(context: Dictionary) -> Array:
	var chosen: Array = []
	for roll in context.get("hand", []):
		chosen.append(roll.die_id)
	return chosen

static func _value(expression: Variant, context: Dictionary, depth: int = 0) -> int:
	if depth > MAX_DEPTH or not expression is Dictionary:
		return 0
	if expression.has("const"):
		return clampi(int(expression["const"]), -VALUE_LIMIT, VALUE_LIMIT)
	if expression.has("rank"):
		match str(expression.rank):
			"carat": return int(context.get("carat", 1))
			"cut": return int(context.get("cut", 1))
			"clarity": return int(context.get("clarity", 1))
			"clarity_bonus": return 2 * int(context.get("clarity", 1))
		return 0
	if expression.has("term"):
		return _term(expression, context, depth)
	if expression.has("op"):
		var args: Array = expression.get("args", [])
		var values: Array = []
		for argument in args:
			values.append(_value(argument, context, depth + 1))
		if values.is_empty():
			return 0
		match str(expression.op):
			"+":
				var sum: int = 0
				for value in values:
					sum += value
				return clampi(sum, -VALUE_LIMIT, VALUE_LIMIT)
			"-":
				return clampi(values[0] - values[1], -VALUE_LIMIT, VALUE_LIMIT)
			"*":
				var product: int = 1
				for value in values:
					product = clampi(product * value, -VALUE_LIMIT, VALUE_LIMIT)
				return product
			"floor_div":
				return 0 if values[1] == 0 else floori(float(values[0]) / float(values[1]))
			"min":
				return values.min()
			"max":
				return values.max()
			"by_cut":
				return floori(float(values[0]) * float(clampi(int(context.get("cut", 1)), 1, 5) + 3) / 4.0)
	return 0

static func _term(expression: Dictionary, context: Dictionary, depth: int) -> int:
	var hand: Array = context.get("hand", [])
	var groups: Dictionary = context.get("groups", {})
	var selected: Array = context.get("selected", [])
	match str(expression.term):
		"high":
			return int(context.get("high", 0))
		"low":
			return int(hand[0].value) if not hand.is_empty() else 0
		"total":
			return int(context.get("total", 0))
		"pair_value":
			var pairs: Array = _matching(groups, 2)
			return int(pairs.back()) if not pairs.is_empty() else 0
		"triple_value":
			var triples: Array = _matching(groups, 3)
			return int(triples.back()) if not triples.is_empty() else 0
		"run_high":
			var run: Array = context.get("run", [])
			return int(run.back()) if not run.is_empty() else 0
		"highest_sum", "lowest_sum":
			var count: int = clampi(_value(expression.get("count", {"const": 1}), context, depth + 1), 0, hand.size())
			var slice: Array = hand.slice(hand.size() - count) if str(expression.term) == "highest_sum" else hand.slice(0, count)
			var sum: int = 0
			for roll in slice:
				sum += int(roll.value)
				if not roll.die_id in selected:
					selected.append(roll.die_id)
			return sum
		"lowest_odd":
			for roll in hand:
				if int(roll.value) % 2 == 1:
					return int(roll.value)
			return 0
		"count_even", "count_odd":
			var wanted_odd: bool = str(expression.term) == "count_odd"
			var counted: int = 0
			for roll in hand:
				if (int(roll.value) % 2 == 1) == wanted_odd:
					counted += 1
			return counted
		"count_distinct":
			return groups.size()
		"count_value":
			return groups.get(int(expression.get("value", 7)), []).size()
		"block":
			return int(context.get("block", 0))
	return 0

static func _matching(groups: Dictionary, count: int) -> Array:
	var matches: Array = []
	for value in groups:
		if groups[value].size() >= count:
			matches.append(value)
	matches.sort()
	return matches

static func _straight(groups: Dictionary, length: int) -> Array:
	var distinct: Array = groups.keys()
	distinct.sort()
	var chosen: Array = []
	for value in distinct:
		var candidate: Array = []
		for offset in range(length):
			if groups.has(value + offset):
				candidate.append(value + offset)
		if candidate.size() == length:
			chosen = candidate
	return chosen

# --- saying it in words -------------------------------------------------------

const VERBS: Dictionary = {"damage": "Damage", "block": "Block", "heal": "Heal", "gold": "Gain",
	"poison": "Apply", "stun": "Apply", "remove_block": "Remove"}
const NOUNS: Dictionary = {"gold": " gold", "poison": " Poison", "stun": " stun", "remove_block": " block"}
const WHERE: Dictionary = {"self": "self", "enemy": "target", "enemies": "all enemies",
	"ally": "every living hero", "other_allies": "your allies"}

static func describe(rule: Dictionary) -> String:
	## The formula sentence for an authored rule, in the wording the shipped ones use.
	var sentences: PackedStringArray = []
	for effect in rule.get("effects", []):
		if not effect is Dictionary:
			continue
		var amount: String = _say(effect.get("amount", {}))
		if str(effect.get("scale", "carat")) == "carat":
			amount = ("(" + amount + ")" if _compound(effect.get("amount", {})) else amount) + " × M(C)"
		var repeat: String = ", " + _say(effect.repeat) + " times" if effect.has("repeat") else ""
		var limit: String = ""
		if effect.has("target_limit"):
			limit = ", up to " + _say(effect.target_limit) + " of them"
		var verb: String = str(VERBS.get(str(effect.get("kind", "")), "Apply"))
		var noun: String = str(NOUNS.get(str(effect.get("kind", "")), ""))
		## "to self" is how the rule reads, not how anyone says it: a self effect just stops.
		var target: String = str(effect.get("target", "self"))
		var where: String = "" if target == "self" else " to " + str(WHERE.get(target, target))
		sentences.append("%s %s%s%s%s%s." % [verb, amount, noun, where, limit, repeat])
	return " ".join(sentences)

static func describe_trigger(trigger: Variant) -> String:
	if not trigger is Dictionary:
		return "Always"
	match str(trigger.get("kind", "always")):
		"always": return "Always"
		"pair": return "Any pair"
		"two_pairs": return "Two distinct pairs"
		"triple": return "At least three matching values"
		"full_house": return "Three of one value and two of another"
		"straight":
			return "Straight: 5 at L1–2; 4 at L3–4; 3 at L5" if _by_clarity(trigger.get("length", null)) \
				else "Straight of " + _say(trigger.get("length", {"const": 3}))
		"parity": return "At least %s %s results" % [_say(trigger.get("at_least", {"const": 3})), str(trigger.get("parity", "even"))]
		"distinct": return "At least %s distinct results" % _say(trigger.get("at_least", {"const": 5}))
		"value": return "At least one %d" % int(trigger.get("value", 7))
		"total_at_least": return "Total ≥ " + _say(trigger.get("amount", {"const": 0}))
		"total_at_most": return "Total ≤ " + _say(trigger.get("amount", {"const": 0}))
		"high_at_least": return "Highest die ≥ " + _say(trigger.get("amount", {"const": 0}))
	return "Always"

const TERM_WORDS: Dictionary = {"high": "H", "low": "the lowest die", "total": "the total",
	"pair_value": "the pair value", "triple_value": "the triple value", "run_high": "the run's highest value",
	"lowest_odd": "the lowest odd die", "count_even": "the even count", "count_odd": "the odd count",
	"count_distinct": "the distinct count", "block": "current block"}

static func _say(expression: Variant) -> String:
	if not expression is Dictionary:
		return "0"
	if expression.has("const"):
		return str(int(expression["const"]))
	if expression.has("rank"):
		match str(expression.rank):
			"carat": return "C"
			"cut": return "K"
			"clarity": return "L"
			"clarity_bonus": return "F(L)"
	if expression.has("term"):
		var term: String = str(expression.term)
		if term in ["highest_sum", "lowest_sum"]:
			return "the %s %s dice" % ["highest" if term == "highest_sum" else "lowest", _say(expression.get("count", {"const": 1}))]
		if term == "count_value":
			return "how many %ds" % int(expression.get("value", 7))
		return str(TERM_WORDS.get(term, term))
	if expression.has("op"):
		var parts: PackedStringArray = []
		for argument in expression.get("args", []):
			parts.append(("(" + _say(argument) + ")") if _compound(argument) and str(expression.op) != "+" else _say(argument))
		match str(expression.op):
			"+": return " + ".join(parts)
			"-": return " − ".join(parts)
			"*": return " × ".join(parts)
			"floor_div": return "floor(%s / %s)" % [parts[0], parts[1]] if parts.size() > 1 else parts[0]
			"min": return "the lower of " + " and ".join(parts)
			"max": return "the higher of " + " and ".join(parts)
			"by_cut": return parts[0] + " × M(K)"
	return "0"

static func _compound(expression: Variant) -> bool:
	return expression is Dictionary and expression.has("op") and expression.get("args", []).size() > 1
