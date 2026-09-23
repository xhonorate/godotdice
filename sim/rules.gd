class_name DeepRules
extends RefCounted
## The rule language: how every skill, inclusion and creature move is written.
##
## A skill is a trigger (see `patterns.gd`) and a list of effects whose amounts are
## arithmetic over the hand. The vocabulary is fixed and small, integers only, no loops,
## nothing it did not define itself. Inclusions use the same effects for their riders and a
## fixed list of modifier kinds for everything else. Creature moves are skills without
## stones. The worst a malformed rule can do is fail validation.
##
## Amount expressions:
##   {"const": 4}   {"term": "value"}   {"rank": "carat"}   {"ladder": [1, 1, 2, 2, 3]}
##   {"op": "+", "args": [...]}   ops: + - * min max floor_div pct
##
## Terms read the trigger's result and the hand:
##   value    what the trigger matched: the pair value, the run's top, the total, the read sum
##   second   the second value of a two pair or full house
##   count    how many dice the trigger matched (run length, set size, parity count)
##   high low total max_total missing odd even distinct held rerolled dice
##   count_value / count_at_most / count_at_least  with "value": n
##   run_high run_length set_value set_count   sum_low / sum_high with "value": n dice
##   block block_lost healed dealt hp max_hp hp_missing gold
##   resonance previous_amount carat cut clarity depth turn party
##   crowns (dice on their top face)  low_dice (dice at or below half their top)
##
## A skill may carry `numbers`: named amount expressions written into its `text` and its
## Flawless line wherever a `{token}` appears, so a Cut ladder never leaves the card lying.
##
## Effects (default target in brackets; * means the amount is scaled by the stone's magnitude,
## and everything else is a whole number that procs more often on a heavier stone instead):
##   damage*(enemy) block*(self) heal*(self) gold*(self) poison*(enemy) remove_block*(enemy)
##   stun(enemy) cleanse(self) revive(downed_ally) curse(enemy: +pct damage taken this turn)
##   amplify_next(pct) cut_step_next raise_low raise_high set_match flip_high flip_low phantom_high
##   grant_reroll retrigger_previous(pct) intent_downgrade(enemy) die_steal(enemy)
##   quality_bonus(pct) sparkle coin_flip(win_mult, lose_mult) resonance
##   Opal-only, and every one of them refuses to touch another opal, which is the whole of
##   why two opals can never call each other for ever:
##     replay_color(color: every gem of that color that has already fired plays again)
##     replay_fizzled(every gem that stayed dark this turn fires anyway)
##     rank_buff(rank: carat or cut, added to every gem in the rail for the rest of the fight)
##     repeat_next(the next gem to resolve, the Birthstone included, fires that many times more)
##   Birthstone-only: replay_rail  tick_poison(times: every poison on every creature ticks)
##   stone_drop(count: a raw stone, Exquisite or better, into the haul when the fight is won)
## Targets: self ally_low allies enemy enemies spread enemy_behind downed_ally, and for
## creatures hero heroes.

const OPS: Array = ["+", "-", "*", "min", "max", "floor_div", "pct"]
const TERMS: Array = ["value", "second", "count", "high", "low", "total", "max_total", "missing", "odd", "even",
	"distinct", "held", "rerolled", "dice", "count_value", "count_at_most", "count_at_least", "run_high", "run_length",
	"set_value", "set_count", "sum_low", "sum_high", "block", "block_lost", "healed", "dealt", "hp", "max_hp", "hp_missing", "gold",
	"resonance", "previous_amount", "carat", "cut", "clarity", "depth", "turn", "party", "crowns", "low_dice"]
const RANKS: Array = ["carat", "cut", "clarity"]
const EFFECT_KINDS: Array = ["damage", "block", "heal", "gold", "poison", "stun", "remove_block", "cleanse", "revive",
	"curse", "amplify_next", "cut_step_next", "raise_low", "raise_high", "set_match", "flip_high", "flip_low",
	"phantom_high", "grant_reroll", "retrigger_previous", "intent_downgrade", "die_steal", "quality_bonus",
	"sparkle", "coin_flip", "resonance", "replay_color", "replay_fizzled", "rank_buff", "repeat_next",
	"replay_rail", "tick_poison", "stone_drop"]
const SCALED_BY_DEFAULT: Array = ["damage", "block", "heal", "gold", "poison", "remove_block"]
const HOSTILE: Array = ["damage", "poison", "stun", "remove_block", "curse", "intent_downgrade", "die_steal"]
const TARGETS: Array = ["self", "ally_low", "allies", "enemy", "enemies", "spread", "enemy_behind", "downed_ally", "hero", "heroes"]
const MODIFIER_KINDS: Array = ["rider", "per_die_damage", "magnitude", "fizzle_on_value", "hp_cost", "carat", "carat_mult",
	"cut_step", "cut_override", "locked", "lens", "color_also", "next_cut_step", "retrigger_if_previous_fired",
	"copy_previous_inclusion", "adjacent_carat", "always_fires", "fires_twice", "carat_per_depth", "alexandrite",
	"resonance_bonus"]
const LENSES: Array = ["low_as_high", "ones_wild", "held_twice"]
## The ranks a `rank_buff` may raise. Clarity is not among them: it decides how many
## inclusions a stone holds and whether its Flawless line reads, and neither of those can
## be handed out mid-fight without rewriting the stone.
const RANK_BUFFS: Array = ["carat", "cut"]
const MODIFY_FIELDS: Array = ["effect", "target", "mult", "add", "repeat_add", "splash", "kind", "scale"]
const MAX_EFFECTS: int = 6
const MAX_DEPTH: int = 6
const MAX_NODES: int = 60
## A Rogue's d20 can ask for twenty hits, so a repeat runs as high as a die face.
const MAX_REPEAT: int = 20
const VALUE_LIMIT: int = 9999
## An effect whose amount cannot be a fraction — a reroll, a phantom die, a stun — grows by
## happening more often instead. No stone happens more than this many times.
const MAX_PROCS: int = 10
## A coin flip reads its own proc count (a heavier stone stakes more on one toss) instead of
## being tossed again, because a second toss could only lose what the first one won.
const PROC_IN_PLACE: Array = ["coin_flip"]

# --- amounts -------------------------------------------------------------------------

static func amount(expr: Variant, c: Dictionary) -> int:
	if expr is int or expr is float:
		return int(expr)
	if not expr is Dictionary:
		return 0
	if expr.has("const"):
		return int(expr.const )
	if expr.has("term"):
		return term(str(expr.term), expr, c)
	if expr.has("rank"):
		return int(c.get(str(expr.rank), 0))
	if expr.has("ladder"):
		var ladder: Array = expr.ladder
		if ladder.is_empty():
			return 0
		return int(ladder[clampi(int(c.get("cut", 0)), 0, ladder.size() - 1)])
	var op: String = str(expr.get("op", "+"))
	var values: Array = []
	for argument in expr.get("args", []):
		values.append(amount(argument, c))
	if values.is_empty():
		return 0
	match op:
		"+":
			var sum: int = 0
			for v in values:
				sum += int(v)
			return sum
		"-":
			var left: int = int(values[0])
			for index in range(1, values.size()):
				left -= int(values[index])
			return left
		"*":
			var product: int = 1
			for v in values:
				product *= int(v)
			return product
		"min":
			var lowest: int = int(values[0])
			for v in values:
				lowest = mini(lowest, int(v))
			return lowest
		"max":
			var highest: int = int(values[0])
			for v in values:
				highest = maxi(highest, int(v))
			return highest
		"floor_div":
			return int(values[0]) / maxi(1, int(values[1])) if values.size() > 1 else int(values[0])
		"pct":
			return int(floor(float(values[0]) * float(values[1]) / 100.0)) if values.size() > 1 else int(values[0])
	return 0

static func term(name: String, node: Dictionary, c: Dictionary) -> int:
	var a: Dictionary = c.get("a", {})
	var trig: Dictionary = c.get("trig", {})
	var unit: Dictionary = c.get("unit", {})
	match name:
		"value": return int(trig.get("value", 0))
		"second": return int(trig.get("second", 0))
		"count": return int(trig.get("count", 0))
		"high", "low", "total", "max_total", "odd", "even", "distinct", "held", "rerolled", "crowns", "low_dice":
			return int(a.get(name, 0))
		"missing": return maxi(0, int(a.get("max_total", 0)) - int(a.get("total", 0)))
		"dice": return int(a.get("dice_count", 0))
		"count_value":
			var wanted: int = int(node.get("value", 0))
			return DeepHand.matching(a, func(v: int) -> bool: return v == wanted).size()
		"count_at_most":
			var ceiling: int = int(node.get("value", 0))
			return DeepHand.matching(a, func(v: int) -> bool: return v <= ceiling).size()
		"count_at_least":
			var floor_value: int = int(node.get("value", 0))
			return DeepHand.matching(a, func(v: int) -> bool: return v >= floor_value).size()
		"run_high": return int(a.get("straight", {}).get("high", 0))
		"run_length": return int(a.get("straight", {}).get("length", 0))
		"set_value": return int(a.get("best_set", {}).get("value", 0))
		"set_count": return int(a.get("best_set", {}).get("count", 0))
		"sum_low": return int(DeepHand.read(a, maxi(1, int(node.get("value", 1))), false).sum)
		"sum_high": return int(DeepHand.read(a, maxi(1, int(node.get("value", 1))), true).sum)
		"block": return int(unit.get("block", 0))
		"block_lost": return int(unit.get("block_lost", 0))
		"healed": return int(unit.get("healed", 0))
		"dealt": return int(unit.get("dealt", 0))
		"hp": return int(unit.get("hp", 0))
		"max_hp": return int(unit.get("max_hp", 0))
		"hp_missing": return maxi(0, int(unit.get("max_hp", 0)) - int(unit.get("hp", 0)))
		"gold": return int(unit.get("gold", 0))
		"resonance": return int(c.get("resonance", 0))
		"previous_amount": return int(c.get("previous_amount", 0))
		"carat", "cut", "clarity", "depth", "turn", "party":
			return int(c.get(name, 0))
	return 0

static func fill(text: String, numbers: Dictionary, cut_step: int) -> String:
	## A skill's card text with its Cut-dependent numbers written in. `{token}` in the text
	## names an entry in the skill's `numbers`, so a ladder reads the same on the card as it
	## does in the fight and no line of rules text can quietly go stale.
	if numbers.is_empty() or not text.contains("{"):
		return text
	var c: Dictionary = {"cut": cut_step}
	for key in numbers:
		var n: int = amount(numbers[key], c)
		## `{key#noun}` writes the number and its noun, so a ladder that reads 1 at one Cut
		## and 3 at another never says "1 afflictions".
		var marker: String = "{%s#" % str(key)
		while text.contains(marker):
			var start: int = text.find(marker)
			var stop: int = text.find("}", start)
			if stop < 0:
				break
			var noun: String = text.substr(start + marker.length(), stop - start - marker.length())
			text = text.substr(0, start) + ("%d %s" % [n, noun if n == 1 else noun + "s"]) + text.substr(stop + 1)
		text = text.replace("{%s}" % str(key), str(n))
	return text

static func tokens(text: String) -> Array:
	## Every `{token}` a piece of rules text asks for, with any `#noun` tail dropped.
	var out: Array = []
	var rest: String = text
	while true:
		var open: int = rest.find("{")
		var close: int = rest.find("}", open + 1)
		if open < 0 or close < 0:
			break
		var key: String = rest.substr(open + 1, close - open - 1).split("#")[0]
		if not key.is_empty() and not out.has(key):
			out.append(key)
		rest = rest.substr(close + 1)
	return out

# --- effects -------------------------------------------------------------------------

static func carat_procs(magnitude: float) -> Dictionary:
	## How a whole-number effect answers to weight. It cannot swell by a fraction, so it
	## happens more often instead: the carat curve less its first step, divided by three.
	## The whole part is how many times over it is certain to happen; what is left is the
	## chance of one more. A one-carat stone gets exactly one go, as it always did.
	var steps: float = maxf(0.0, (magnitude - 1.0) / 3.0)
	var whole: int = int(floor(steps))
	var chance: int = int(round((steps - float(whole)) * 100.0))
	if chance >= 100:
		whole += 1
		chance = 0
	var procs: int = clampi(1 + whole, 1, MAX_PROCS)
	return {"procs": procs, "chance": 0 if procs >= MAX_PROCS else chance}

static func default_target(kind: String, hostile_side: String = "enemy") -> String:
	if kind in HOSTILE:
		return hostile_side
	if kind == "revive":
		return "downed_ally"
	return "self"

static func resolve_effect(def: Dictionary, c: Dictionary, magnitude: float, hostile_side: String = "enemy") -> Dictionary:
	## One effect with its numbers filled in. `magnitude` is the stone's multiplier (1.0 for
	## a creature). The amount is floored exactly once, here.
	var kind: String = str(def.get("kind", "damage"))
	var raw: int = amount(def.get("amount", {"const": 0}), c)
	var scale: String = str(def.get("scale", "carat" if kind in SCALED_BY_DEFAULT else "none"))
	var final: int = int(floor(float(raw) * magnitude)) if scale == "carat" else raw
	var repeat: int = clampi(amount(def.get("repeat", {"const": 1}), c), 0, MAX_REPEAT)
	## An effect that cannot take a multiplier takes procs instead, unless its author wrote
	## `scale: "none"` on it, which is how an inclusion's rider asks to stay flat.
	var proc: Dictionary = {"procs": 1, "chance": 0} if scale == "carat" or def.has("scale") else carat_procs(magnitude)
	var out: Dictionary = {"kind": kind, "target": str(def.get("target", default_target(kind, hostile_side))),
		"amount": clampi(final, -VALUE_LIMIT, VALUE_LIMIT), "raw": raw, "repeat": repeat, "scaled": scale == "carat",
		"procs": int(proc.procs), "proc_chance": int(proc.chance)}
	for field in ["splash", "once", "win_mult", "lose_mult", "text", "color", "rank"]:
		if def.has(field):
			out[field] = def[field]
	return out

# --- validation ----------------------------------------------------------------------

static func validate_expression(expr: Variant, where: String, depth: int = 1) -> Array:
	if depth > MAX_DEPTH:
		return [where + ": expression nests too deep"]
	if expr is int or expr is float:
		if int(expr) != float(expr):
			return [where + ": whole numbers only"]
		return []
	if not expr is Dictionary:
		return [where + ": must be a number or an object"]
	if expr.has("const"):
		if not (expr.const is int or expr.const is float) or int(expr.const ) != float(expr.const ):
			return [where + ": const must be a whole number"]
		return []
	if expr.has("term"):
		if not str(expr.term) in TERMS:
			return [where + ": unknown term " + str(expr.term)]
		if (str(expr.term).begins_with("count_") or str(expr.term).begins_with("sum_")) and not expr.has("value"):
			return [where + ": " + str(expr.term) + " needs a value"]
		return []
	if expr.has("rank"):
		return [] if str(expr.rank) in RANKS else [where + ": unknown rank " + str(expr.rank)]
	if expr.has("ladder"):
		if not expr.ladder is Array or expr.ladder.size() != DeepPatterns.STEPS:
			return [where + ": a ladder lists exactly %d values" % DeepPatterns.STEPS]
		return []
	if not str(expr.get("op", "")) in OPS:
		return [where + ": unknown op " + str(expr.get("op", "(none)"))]
	var args: Variant = expr.get("args", null)
	if not args is Array or args.is_empty():
		return [where + ": op needs args"]
	var errors: Array = []
	for argument in args:
		errors.append_array(validate_expression(argument, where, depth + 1))
	return errors

static func validate_effect(effect: Variant, where: String, hostile_side: String = "enemy") -> Array:
	if not effect is Dictionary:
		return [where + ": must be an object"]
	var errors: Array = []
	for field in effect:
		if not str(field) in ["kind", "target", "amount", "scale", "repeat", "splash", "once", "win_mult", "lose_mult", "text", "color", "rank"]:
			errors.append(where + ": unknown field " + str(field))
	var kind: String = str(effect.get("kind", ""))
	if not kind in EFFECT_KINDS:
		errors.append(where + ": unknown effect kind " + (kind if not kind.is_empty() else "(none)"))
	var target: String = str(effect.get("target", default_target(kind, hostile_side)))
	if not target in TARGETS:
		errors.append(where + ": unknown target " + target)
	if effect.has("scale") and not str(effect.scale) in ["carat", "none"]:
		errors.append(where + ": scale must be carat or none")
	if kind == "replay_color" and not str(effect.get("color", "")) in DeepContent.color_KEYS:
		errors.append(where + ": replay_color names one of the six colors")
	if kind == "rank_buff" and not str(effect.get("rank", "")) in RANK_BUFFS:
		errors.append(where + ": rank_buff raises " + " or ".join(RANK_BUFFS))
	if effect.has("amount"):
		errors.append_array(validate_expression(effect.amount, where + " amount"))
	if effect.has("repeat"):
		errors.append_array(validate_expression(effect.repeat, where + " repeat"))
	return errors

static func validate_skill(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	if not str(def.get("color", "")) in DeepContent.SKILL_COLORS:
		errors.append("unknown color " + str(def.get("color", "")))
	## A Doublet wears no skill of its own: it takes the next gem's. Nothing else may.
	if not str(def.get("wears", "")) in ["", "next"]:
		errors.append("wears must be next, or be left out")
	if not str(def.get("rarity", "")) in DeepContent.RARITIES:
		errors.append("unknown rarity " + str(def.get("rarity", "")))
	errors.append_array(DeepPatterns.validate(def.get("trigger", null)))
	var effects: Variant = def.get("effects", null)
	if not effects is Array or effects.is_empty():
		errors.append("needs at least one effect")
	else:
		if effects.size() > MAX_EFFECTS:
			errors.append("at most %d effects" % MAX_EFFECTS)
		for index in range(effects.size()):
			errors.append_array(validate_effect(effects[index], "effect %d" % (index + 1)))
	var numbers: Variant = def.get("numbers", {})
	if not numbers is Dictionary:
		errors.append("numbers must be an object")
		numbers = {}
	else:
		for key in numbers:
			errors.append_array(validate_expression(numbers[key], "number " + str(key)))
	var texts: Array = [str(def.get("text", ""))]
	if def.get("flawless", null) is Dictionary:
		texts.append(str(def.flawless.get("text", "")))
	for text in texts:
		for key in tokens(text):
			if not numbers.has(key):
				errors.append("text asks for {%s} but no number of that name is given" % key)
	var flawless: Variant = def.get("flawless", null)
	if flawless != null:
		if not flawless is Dictionary:
			errors.append("flawless must be an object")
		else:
			for index in range(flawless.get("effects", []).size()):
				errors.append_array(validate_effect(flawless.effects[index], "flawless effect %d" % (index + 1)))
			for change in flawless.get("modify", []):
				if not change is Dictionary:
					errors.append("flawless modify entries must be objects")
					continue
				for field in change:
					if not str(field) in MODIFY_FIELDS:
						errors.append("flawless modify: unknown field " + str(field))
				if effects is Array and (int(change.get("effect", 0)) < 0 or int(change.get("effect", 0)) >= effects.size()):
					errors.append("flawless modify points past the effects list")
				if change.has("target") and not str(change.target) in TARGETS:
					errors.append("flawless modify: unknown target " + str(change.target))
				if change.has("kind") and not str(change.kind) in EFFECT_KINDS:
					errors.append("flawless modify: unknown kind " + str(change.kind))
	return errors

static func validate_inclusion(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	if not str(def.get("class", "")) in DeepContent.INCLUSION_CLASSES:
		errors.append("unknown class " + str(def.get("class", "")))
	if not str(def.get("rarity", "COMMON")) in DeepContent.RARITIES:
		errors.append("unknown rarity " + str(def.get("rarity", "")))
	var modifiers: Variant = def.get("modifiers", null)
	if not modifiers is Array or modifiers.is_empty():
		errors.append("needs at least one modifier")
		return errors
	for index in range(modifiers.size()):
		var m: Variant = modifiers[index]
		var where: String = "modifier %d" % (index + 1)
		if not m is Dictionary:
			errors.append(where + ": must be an object")
			continue
		var kind: String = str(m.get("kind", ""))
		if not kind in MODIFIER_KINDS:
			errors.append(where + ": unknown modifier " + (kind if not kind.is_empty() else "(none)"))
			continue
		match kind:
			"rider":
				var effects: Variant = m.get("effects", null)
				if not effects is Array or effects.is_empty():
					errors.append(where + ": a rider needs effects")
				else:
					for e in range(effects.size()):
						errors.append_array(validate_effect(effects[e], where + " effect %d" % (e + 1)))
			"lens":
				if not str(m.get("mode", "")) in LENSES:
					errors.append(where + ": unknown lens " + str(m.get("mode", "")))
			"color_also":
				if not str(m.get("color", "")) in DeepContent.color_KEYS:
					errors.append(where + ": unknown color " + str(m.get("color", "")))
			"per_die_damage", "magnitude", "hp_cost", "carat", "carat_mult", "cut_step", "next_cut_step", "adjacent_carat", "resonance_bonus":
				if not (m.get("amount", null) is int or m.get("amount", null) is float):
					errors.append(where + ": needs an amount")
			"fizzle_on_value", "cut_override":
				if not (m.get("value", null) is int or m.get("value", null) is float):
					errors.append(where + ": needs a value")
			"carat_per_depth":
				if not (m.get("below", null) is int or m.get("below", null) is float) or not (m.get("amount", null) is int or m.get("amount", null) is float):
					errors.append(where + ": needs below and amount")
	return errors

static func validate_move(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	errors.append_array(DeepPatterns.validate(def.get("trigger", {"kind": "always"})))
	var effects: Variant = def.get("effects", null)
	if not effects is Array or effects.is_empty():
		errors.append("needs at least one effect")
	else:
		for index in range(effects.size()):
			errors.append_array(validate_effect(effects[index], "effect %d" % (index + 1), "hero"))
	return errors
