extends RefCounted
## Turns one gem instance into the picture of its rule, not the algebra of it.
##
## The catalogue stores a formula as a sentence with `C`, `K` and `L` in it, which is
## exact and unreadable. This resolves that sentence against the gem a player actually
## owns: a Cut of 3 becomes the number 3 beside the Cut mark, a Carat of 1 multiplies
## by one and therefore disappears, and a term worth nothing is not shown at all. What
## survives is a short chain of marked parts, added together and then multiplied once.
##
## A block is one effect: a verb, the parts that add up, the single Carat multiplier,
## and the word for what it does. `main.gd` lays that out as chips; `sentence()` says
## the same thing in words for tooltips.
##
## Every branch mirrors `combat.gd`. This file never evaluates a hand and never decides
## an outcome; if the two ever disagree, `combat.gd` is right and this is the bug.

const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const GemRules = preload("res://scripts/core/gem_rules.gd")

## What each effect is tinted with, so a build reads by colour before it reads by word.
const TONES := {
	"damage": "RED", "block": "BLUE", "heal": "GREEN", "gold": "GOLD",
	"poison": "VIOLET", "stun": "VIOLET", "strip": "AMBER", "revive": "GREEN",
	"reroll": "WHITE", "amplify": "WHITE", "echo": "WHITE", "upgrade": "WHITE",
	"cleanse": "GREEN"}
## The property a bare number came from, named for the tooltip and the spoken sentence.
const SOURCES := {"carat": "Carat", "cut": "Cut", "clarity": "Clarity"}

# --- small parts --------------------------------------------------------------

static func number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return String.num(value, 3)

static func _count(amount: int, word: String, plural: String = "") -> String:
	if amount == 1:
		return "%d %s" % [amount, word]
	return "%d %s" % [amount, plural if not plural.is_empty() else word + "s"]

static func _part(glyph: String, text: String, tip: String, factor: Dictionary = {}) -> Dictionary:
	return {"glyph": glyph, "text": text, "tip": tip, "factor": factor}

static func _cut_factor(cut: int) -> Dictionary:
	## A Cut of 1 multiplies by one, so it is left out rather than written as "× 1".
	if cut <= 1:
		return {}
	return {"glyph": "cut", "text": "×" + str(cut),
		"tip": "Cut %d (%s) multiplies the dice this reads." % [cut, Catalog.cut_name(cut)]}

static func _cut_ratio(cut: int, value: float, note: String) -> Dictionary:
	if is_equal_approx(value, 1.0):
		return {}
	return {"glyph": "cut", "text": "×" + number(value),
		"tip": "Cut %d (%s) %s." % [cut, Catalog.cut_name(cut), note]}

static func _cut_flat(cut: int, value: int, note: String) -> Dictionary:
	## Cut appearing as an addend rather than a multiplier. Worth nothing means absent.
	if value <= 0:
		return {}
	return _part("cut", str(value), "Cut %d (%s) %s." % [cut, Catalog.cut_name(cut), note])

static func _clarity(clarity: int, effective: int) -> Dictionary:
	var bonus: int = Combat.clarity_bonus(effective)
	var tip := "Clarity %d (%s) adds a flat %d, whatever you roll." % [effective, Catalog.clarity_name(effective), bonus]
	if effective != clarity:
		tip += " A Focusing Prism is raising this gem from Clarity %d." % clarity
	return _part("clarity", str(bonus), tip)

static func _carat(carat: int) -> Dictionary:
	## Carat 1 multiplies by one. Showing "× 1" would be noise, so it is dropped.
	if carat <= 1:
		return {}
	var multiplier: float = Combat.carat_multiplier(carat)
	return {"glyph": "carat", "text": "×" + number(multiplier),
		"tip": "Carat %d multiplies everything above by %s." % [carat, number(multiplier)]}

static func _block(verb: String, kind: String, label: String, parts: Array, carat: int, suffix: String = "") -> Dictionary:
	var kept: Array = []
	for part in parts:
		if not part.is_empty():
			kept.append(part)
	return {"verb": verb, "kind": kind, "label": label, "tone": str(TONES.get(kind, "PAPER")),
		"parts": kept, "mult": _carat(carat), "suffix": suffix, "repeat": {}, "note": ""}

static func _fixed(verb: String, kind: String, label: String, text: String, tip: String, glyph: String = "", suffix: String = "") -> Dictionary:
	## An amount no property scales: it is stated, not built up from parts.
	return {"verb": verb, "kind": kind, "label": label, "tone": str(TONES.get(kind, "PAPER")),
		"parts": [_part(glyph, text, tip)], "mult": {}, "suffix": suffix, "repeat": {}, "note": ""}

# --- the rules ----------------------------------------------------------------

static func blocks(gem: Dictionary, effective_clarity: int = -1) -> Array:
	## One entry per effect the gem produces, in the order `combat.gd` resolves them.
	var key: String = Catalog.canonical_key(str(gem.get("key", "")))
	var definition: Dictionary = Catalog.definitions("skills").get(key, {})
	if definition.is_empty():
		return []
	var c: int = clampi(int(gem.get("carat", 1)), 1, 24)
	var k: int = clampi(int(gem.get("cut", 1)), 1, 5)
	var stored: int = clampi(int(gem.get("clarity", 1)), 1, 5)
	var l: int = clampi(effective_clarity, 1, 5) if effective_clarity > 0 else stored
	var flat: Dictionary = _clarity(stored, l)
	var cut_name: String = Catalog.cut_name(k)
	var built: Array = []
	if GemRules.has_rule(definition):
		return _authored(definition.rule, c, k, stored, l)
	match Combat.rule_of(key):
		"STRIKE":
			built.append(_block("Deal", "damage", "damage", [
				_part("high", "highest die" if k == 1 else "highest %d dice" % k,
					"Your single highest die." if k == 1 else "Your %d highest dice, added together." % k),
				flat], c, "to your target"))
		"BLOCK":
			built.append(_block("Gain", "block", "block", [
				_part("pair", "pair value", GemIcons.hint("pair"), _cut_factor(k)), flat], c))
		"INTERPOSE":
			built.append(_block("Give every living hero", "block", "block", [
				_part("pair", "pair value", GemIcons.hint("pair")),
				_cut_flat(k, k - 1, "adds a little here: this gem reads one pair whatever its Cut"),
				flat], c))
		"HEAL":
			built.append(_block("Heal yourself for", "heal", "health", [
				_part("low", "lowest die" if k == 1 else "lowest %d dice" % k,
					"Your single lowest die." if k == 1 else "Your %d lowest dice, added together." % k),
				flat], c))
		"MEND":
			built.append(_block("Heal every living hero for", "heal", "health", [
				_part("low", "lowest odd die", "The lowest odd result in your hand."),
				_cut_flat(k, 2 * (k - 1), "adds a flat bonus here"),
				flat], c))
		"MULTISTRIKE":
			var multi: Dictionary = _block("Deal", "damage", "damage", [
				_part("", str(Combat.MULTISTRIKE_HIT), "Every hit starts from a fixed %d." % Combat.MULTISTRIKE_HIT)],
				c, "" if k == 1 else "per hit")
			multi.repeat = {"glyph": "hit", "text": _count(k, "hit"),
				"tip": "Cut %d (%s) sets how many hits land. They all strike one fixed target." % [k, cut_name]}
			multi.note = "Clarity shortens the run this needs instead of adding a flat bonus."
			built.append(multi)
		"LUCKYSTRIKE":
			built.append(_block("Deal", "damage", "damage", [
				_part("", "7", "Every 7 in your hand strikes separately.",
					_cut_ratio(k, Combat.cut_multiplier(k), "multiplies each seven"))],
				c, "for every 7 you rolled"))
			var jackpot: int = 7 if l == 5 else l + 1
			var gold: Dictionary = _fixed("Gain", "gold", "gold", str(c),
				"Carat %d sets the gold each 7 pays." % c, "carat", "for every 7 you rolled")
			gold.note = "Three or more sevens multiply the gold by %d at Clarity %d (%s). The damage is unaffected." % [
				jackpot, l, Catalog.clarity_name(l)]
			built.append(gold)
		"HEAVYSTRIKE":
			built.append(_block("Deal", "damage", "damage", [
				_part("triple", "match value", GemIcons.hint("triple"), _cut_factor(k)), flat], c, "to your target"))
		"BLESSING":
			built.append(_block("Gain", "gold", "gold", [
				_part("", str(Combat.BLESSING_GOLD), "A fixed %d before Carat." % Combat.BLESSING_GOLD)], c))
			built.append(_block("Heal yourself for", "heal", "health", [
				_cut_flat(k, k, "adds its rank straight into this heal"), flat], c))
		"SHIELDBASH":
			built.append(_block("First gain", "block", "block", [flat], c))
			var bash: Dictionary = _block("Then deal", "damage", "damage", [
				_part("shield", "your block", GemIcons.hint("shield"),
					_cut_ratio(k, float(k + 1) / 2.0, "multiplies the block you are standing behind"))],
				1, "to your target")
			bash.note = "Carat already grew the block above, so it is not applied a second time."
			built.append(bash)
			if l == 5:
				built.append(_fixed("Apply", "stun", "stun", "1",
					"Flawless Clarity adds a stun this gem does not otherwise have.", "clarity"))
		"STUN":
			built.append(_block("Deal", "damage", "damage", [
				_part("high", "highest die", GemIcons.hint("high")), flat], c, "to your target"))
			built.append(_fixed("Apply", "stun", "stun", "2" if k == 5 else "1",
				"Only a Perfect Cut lengthens this to two slots." if k < 5 else "A Perfect Cut doubles the skip.", "cut"))
		"BULWARK":
			var table: int = Catalog.BULWARK_BLOCK[c - 1]
			var wall: Dictionary = _fixed("Gain", "block", "block", str(table),
				"Bulwark reads a fixed Carat table instead of the usual multiplier. Carat %d grants %d." % [c, table], "carat")
			wall.note = "Clarity only widens the low total this needs; it adds nothing to the block."
			built.append(wall)
			var self_stun: int = Catalog.BULWARK_STUN[k - 1]
			if self_stun > 0:
				built.append(_fixed("Then stun yourself for", "stun", "turn" if self_stun == 1 else "turns",
					str(self_stun), "Cut %d (%s) buys this down. A Perfect Cut removes it entirely." % [k, cut_name], "cut"))
		"DRAINSTRIKE":
			built.append(_block("Deal", "damage", "damage", [
				_part("high", "highest die", GemIcons.hint("high"),
					_cut_ratio(k, float(k + 1) / 2.0, "multiplies the high die")), flat], c, "to your target"))
			built.append(_block("Heal yourself for", "heal", "health", [flat], c))
		"SUNDER":
			built.append(_block("Strip", "strip", "block", [
				_cut_flat(k, 2 * k, "doubles into the block you tear off"), flat], c, "from your target"))
			built.append(_block("Then deal", "damage", "damage", [
				_part("pair", "pair value", GemIcons.hint("pair")), flat], c, "to your target"))
		"ARC_BURST":
			var arc: Dictionary = _block("Deal", "damage", "damage", [
				_part("run", "top of the run", GemIcons.hint("run")), flat], c, "each")
			arc.repeat = {"glyph": "target", "text": "to %s" % _count(k + 1, "enemy", "enemies"),
				"tip": "Cut %d (%s) buys reach, not damage. Against a lone boss the extra targets are wasted." % [k, cut_name]}
			built.append(arc)
		"VENOM":
			built.append(_block("Deal", "damage", "damage", [
				_part("high", "half the highest die", "Half your highest die, rounded down."), flat], c, "to your target"))
			built.append(_fixed("Apply", "poison", "poison", str(k + ceili(float(c) / 4.0)),
				"Cut %d (%s) plus a quarter of Carat %d. Poison bypasses block and caps at 12 stacks." % [k, cut_name, c], "cut"))
		"EVEN_TEMPO":
			built.append(_block("Gain", "block", "block", [
				_part("count", "even dice", "How many of your five dice came up even.", _cut_factor(k)), flat], c))
			built.append(_block("Then deal", "damage", "damage", [
				_cut_flat(k, k, "adds its rank straight into this hit"), flat], c, "to your target"))
		"PRECISION":
			built.append(_block("Deal", "damage", "damage", [
				_part("low", "lowest two dice", "Your two lowest dice, added together."),
				_cut_flat(k, 2 * k, "doubles into this hit"), flat], c, "to your target"))
		"LIFELINE":
			built.append(_block("Revive a downed hero at", "revive", "health", [
				_cut_flat(k, 3 * k, "triples into the health a revival restores"), flat], c, "once per battle"))
			built.append(_block("Otherwise heal every living hero for", "heal", "health", [
				_cut_flat(k, k, "adds its rank straight into this heal"), flat], c))
		"QUARTET":
			var wanted: int = 3 if l == 5 else 4
			var quad: Dictionary = _block("Deal", "damage", "damage", [
				_part("triple", "match value", "The value shown by your %d matching dice." % wanted,
					_cut_ratio(k, float(2 * k), "doubles into the matched value")), flat], c, "to your target")
			quad.note = "Clarity buys this trigger down to a triple at Flawless instead of adding more to the hit."
			built.append(quad)
		"BASTION":
			built.append(_block("Give every living hero", "block", "block", [
				_cut_flat(k, 3 * k, "triples into the wall this raises"), flat], c))
			built.append(_fixed("Then clear", "cleanse", "stun from every living hero", "2" if l == 5 else "1",
				"Only Flawless Clarity clears a second slot of stun." if l < 5 else "Flawless Clarity clears both slots of a doubled stun.",
				"clarity"))
		"PURGE":
			built.append(_fixed("Clear", "cleanse", "Poison from every living hero",
				str(k + ceili(float(c) / 8.0)),
				"Cut %d (%s) plus an eighth of Carat %d. Poison is the one status that bypasses block." % [k, cut_name, c], "cut"))
			built.append(_block("Then heal every living hero for", "heal", "health", [flat], c))
		"GRAFT":
			built.append(_block("Heal yourself for", "heal", "health", [
				_part("pair", "both pair values", "Your two highest pairs, added together — the values, not the four dice."),
				_cut_flat(k, 2 * (k - 1), "adds a flat bonus here"), flat], c))
		"HEXBOLT":
			built.append(_block("Deal", "damage", "damage", [
				_part("count", "odd dice", "How many of your five dice came up odd.", _cut_factor(k)),
				flat], c, "to your target"))
			if l == 5:
				built.append(_fixed("Apply", "stun", "stun", "1",
					"Flawless Clarity adds a stun this gem does not otherwise have.", "clarity"))
		"MIASMA":
			var fumes: Dictionary = _fixed("Apply", "poison", "Poison", str(k + ceili(float(c) / 6.0)),
				"Cut %d (%s) plus a sixth of Carat %d. Poison bypasses block and caps at 12 stacks." % [k, cut_name, c], "cut")
			fumes.repeat = {"glyph": "target", "text": "to %s" % _count(k + 1, "enemy", "enemies"),
				"tip": "Cut %d (%s) buys reach here as well as stacks." % [k, cut_name]}
			built.append(fumes)
			built.append(_block("Then deal", "damage", "damage", [flat], c, "to the same enemies"))
		"ENERVATE":
			built.append(_block("Strip", "strip", "block", [
				_cut_flat(k, 2 * k, "doubles into the block you tear off"), flat], c, "from your target"))
			built.append(_fixed("Then apply", "poison", "Poison",
				str(k), "Cut %d (%s), plus half the matched value your triple showed. Caps at 12 stacks." % [k, cut_name], "cut",
				"plus half the match value"))
		"TITHE":
			built.append(_block("Gain", "gold", "gold", [
				_cut_flat(k, k, "adds its rank straight into the take"), flat], c))
		"MINT":
			built.append(_block("Gain", "gold", "gold", [
				_cut_flat(k, 2 * k, "doubles into the take"), flat], c))
			built.append(_block("Then gain", "block", "block", [
				_cut_flat(k, k, "adds its rank straight into this block"), flat], c))
		"WAGER":
			built.append(_block("Gain", "gold", "gold", [
				_part("", str(Combat.BLESSING_GOLD), "A fixed %d before Carat." % Combat.BLESSING_GOLD)], c))
			var bet: Dictionary = _block("Then deal", "damage", "damage", [
				_part("sum", "%d − your total" % Combat.WAGER_CEILING,
					"What the hand did not give you: %d less the five dice added up." % Combat.WAGER_CEILING),
				_cut_flat(k, 2 * k, "doubles into this hit"), flat], c, "to your target")
			bet.note = "Clarity widens the low total this needs as well as adding its flat bonus, so a Flawless Wager fires on quiet hands a Fractured one would miss."
			built.append(bet)
		"GLIMMER":
			var polish: Dictionary = _block("Raise your lowest die by", "amplify", "pips", [
				_cut_flat(k, k, "adds its rank straight into the lift"), flat], c, "to a maximum of 20")
			polish.note = "The hand itself changes, so every gem equipped after this one reads the raised die."
			built.append(polish)
		"REFRACT":
			var lift: Dictionary = _block("Raise your highest die by", "amplify", "pips", [
				_part("high", "highest die", GemIcons.hint("high")),
				_cut_flat(k, 2 * (k - 1), "doubles into the lift"), flat], c, "to a maximum of 20")
			lift.note = "Adding the die to itself is what doubles it. Every gem equipped after this one reads the raised hand."
			built.append(lift)
		"SECOND_SIGHT":
			var allowance: int = Combat.reroll_allowance(c, k)
			var sight: Dictionary = _fixed("Reroll up to", "reroll", "times a turn", str(allowance),
				"Carat %d sets the allowance%s." % [c, ", and a Perfect Cut adds one" if k == 5 else ""],
				"reroll", "for the rest of this battle")
			sight.note = "It sets the allowance rather than adding to it, so casting it twice in one battle is no better than once."
			built.append(sight)
			built.append(_block("Gain", "block", "block", [flat], c))
		"ECHO":
			var repeat: Dictionary = _block("Repeat the last gem that landed an amount at", "echo", "per cent of it", [
				_part("", "25", "A quarter of it before your ranks are counted."),
				_cut_flat(k, 5 * (k - 1), "adds five points of repeat a rank"), flat], c, "up to 200%")
			repeat.note = "It repeats damage, block, healing, gold and statuses. A gem that only changed your dice is skipped over rather than repeated."
			built.append(repeat)
		"FACET":
			var recut: Dictionary = _fixed("Permanently add", "upgrade", "Carat to another gem",
				str(ceili(float(k) / 2.0)),
				"Cut %d (%s) sets how many ranks this cuts into the other stone." % [k, cut_name],
				"cut", "once per battle")
			recut.note = "It takes your lowest-Carat other equipped gem, and never lifts it past Carat %d — this gem's own size." % c
			built.append(recut)
	return built

## A rule written as data, drawn as the same chain of marked parts a compiled one gets.
## The amount is split at its top-level additions, because that is what the chain is: the
## things that add up, then the one Carat multiplier over all of them.
static func _authored(rule: Dictionary, carat: int, cut: int, clarity: int, effective: int) -> Array:
	var built: Array = []
	for effect in rule.get("effects", []):
		if not effect is Dictionary:
			continue
		var kind: String = str(effect.get("kind", "damage"))
		var scaled: bool = str(effect.get("scale", "carat")) == "carat"
		var parts: Array = []
		for addend in _addends(effect.get("amount", {})):
			var drawn: Dictionary = _authored_part(addend, cut, clarity, effective)
			if not drawn.is_empty():
				parts.append(drawn)
		var suffix: String = str(GemRules.WHERE.get(str(effect.get("target", "self")), "self"))
		suffix = "" if suffix == "self" else "to " + suffix
		if effect.has("target_limit"):
			suffix += " (up to %s of them)" % GemRules._say(effect.target_limit)
		var entry: Dictionary = _block(str(GemRules.VERBS.get(kind, "Apply")), _tone_kind(kind),
			_label_for(kind), parts, carat if scaled else 1, suffix)
		if effect.has("repeat"):
			entry.repeat = _part("hit", "×" + GemRules._say(effect.repeat), "Separate hits against one fixed target.")
		built.append(entry)
	return built

static func _tone_kind(kind: String) -> String:
	return "strip" if kind == "remove_block" else kind

static func _label_for(kind: String) -> String:
	match kind:
		"damage": return "damage"
		"block", "remove_block": return "block"
		"heal": return "health"
		"gold": return "gold"
		"poison": return "Poison"
		"stun": return "stun"
	return kind

static func _addends(expression: Variant) -> Array:
	if expression is Dictionary and str(expression.get("op", "")) == "+":
		var flattened: Array = []
		for argument in expression.get("args", []):
			flattened.append_array(_addends(argument))
		return flattened
	return [expression]

## Which pictograph a term deserves. `gem_icons.gd` owns the drawings and the hover text.
const RULE_GLYPHS := {"high": "high", "highest_sum": "high", "low": "low", "lowest_sum": "low",
	"lowest_odd": "low", "total": "sum", "pair_value": "pair", "triple_value": "triple",
	"run_high": "run", "count_even": "count", "count_odd": "count", "count_distinct": "count",
	"count_value": "count", "block": "shield"}

static func _authored_part(expression: Variant, cut: int, clarity: int, effective: int) -> Dictionary:
	if not expression is Dictionary:
		return {}
	if expression.has("rank"):
		match str(expression.rank):
			"clarity_bonus": return _clarity(clarity, effective)
			"cut": return _cut_flat(cut, cut, "adds its rank straight into this")
			"clarity": return _part("clarity", str(effective), "Clarity %d (%s)." % [effective, Catalog.clarity_name(effective)])
			"carat": return _part("carat", str(""), "Carat.")
	if expression.has("const"):
		var value: int = int(expression["const"])
		return {} if value == 0 else _part("", str(value), "A flat %d, whatever you roll." % value)
	if expression.has("term"):
		var term: String = str(expression.term)
		return _part(str(RULE_GLYPHS.get(term, "")), GemRules._say(expression), GemIcons.hint(str(RULE_GLYPHS.get(term, ""))))
	if expression.has("op"):
		## A product of a term and the Cut is the shape the shipped gems use, so it is drawn
		## the way they are: the term, with the Cut hanging off it as a multiplier.
		var args: Array = expression.get("args", [])
		if str(expression.op) == "*" and args.size() == 2:
			for order in [[0, 1], [1, 0]]:
				if args[order[1]] is Dictionary and str(args[order[1]].get("rank", "")) == "cut" and args[order[0]] is Dictionary and args[order[0]].has("term"):
					var term_part: Dictionary = _authored_part(args[order[0]], cut, clarity, effective)
					term_part.factor = _cut_factor(cut)
					return term_part
		return _part("", GemRules._say(expression), "This part of the rule, worked out from your hand.")
	return {}

# --- the refinement chain -----------------------------------------------------

static func _literal(text: String) -> Variant:
	## A part worth a plain number, as opposed to one worth whatever the hand gave.
	if text.is_empty():
		return null
	var body := text.substr(1) if text.begins_with("×") else text
	return float(body) if body.is_valid_float() else null

static func chain(gem: Dictionary, kind: String, amount: int, effective_clarity: int = -1) -> Dictionary:
	## The refinement one amount went through, for the battlefield to count out: where the
	## dice term landed, and every rank that moved it, in the order the rule applies them.
	##
	## The steps come from the same authored decomposition the gem sheet prints, so the
	## field never shows a multiplication the rule does not perform — Strike's Cut chooses
	## how many dice are read and so contributes no factor, while Block's multiplies the
	## pair it found and so does. The dice term itself is recovered by running that chain
	## backwards from the amount the log recorded and checking it forwards again. When the
	## two do not agree the chain is returned inexact, and the caller states no intermediate
	## value it cannot stand behind.
	for block in blocks(gem, effective_clarity):
		if str(block.get("kind", "")) != kind:
			continue
		var multiplier: float = 1.0
		var carat_text := str(block.get("mult", {}).get("text", ""))
		if not carat_text.is_empty():
			multiplier = float(_literal(carat_text)) if _literal(carat_text) != null else 1.0
		var known := 0.0
		var dice_factor := 1.0
		var addends: Array = []
		var found_term := false
		for part in block.get("parts", []):
			var factor_value: Variant = _literal(str(part.get("factor", {}).get("text", "")))
			var scale: float = float(factor_value) if factor_value != null else 1.0
			var literal: Variant = _literal(str(part.get("text", "")))
			if literal == null:
				if found_term:
					return {}
				found_term = true
				dice_factor = scale
				continue
			known += float(literal) * scale
			addends.append({"glyph": str(part.get("glyph", "")), "value": float(literal) * scale,
				"text": "+%s" % number(float(literal) * scale)})
		if not found_term or multiplier <= 0.0 or dice_factor <= 0.0:
			return {}
		var term: int = int(round((float(amount) / multiplier - known) / dice_factor))
		if term < 0 or floori((float(term) * dice_factor + known) * multiplier) != amount:
			return {}
		var steps: Array = []
		var running := float(term)
		if not is_equal_approx(dice_factor, 1.0):
			running *= dice_factor
			steps.append({"glyph": "cut", "text": _factor_text(block, dice_factor), "value": running})
		for addend in addends:
			running += float(addend.value)
			steps.append({"glyph": str(addend.glyph), "text": str(addend.text), "value": running})
		if not is_equal_approx(multiplier, 1.0):
			steps.append({"glyph": "carat", "text": "×%s" % number(multiplier), "value": float(amount)})
		return {"base": term, "steps": steps}
	return {}

static func _factor_text(block: Dictionary, scale: float) -> String:
	for part in block.get("parts", []):
		var factor: Dictionary = part.get("factor", {})
		if not factor.is_empty() and is_equal_approx(float(_literal(str(factor.text))), scale):
			return str(factor.text)
	return "×%s" % number(scale)

# --- the name line ------------------------------------------------------------

static func title_parts(gem: Dictionary) -> Array:
	## "Good ✦ Flawless ✧ 12 ⚖ Multistrike" as pieces a row can lay out: the rank a
	## player says out loud, then the mark that says which rank it was.
	var key: String = Catalog.canonical_key(str(gem.get("key", "")))
	var c: int = clampi(int(gem.get("carat", 1)), 1, 24)
	var k: int = clampi(int(gem.get("cut", 1)), 1, 5)
	var l: int = clampi(int(gem.get("clarity", 1)), 1, 5)
	return [
		{"glyph": "cut", "text": Catalog.cut_name(k),
			"tip": "Cut %d of 5 — %s. %s" % [k, Catalog.cut_name(k), GemIcons.hint("cut")]},
		{"glyph": "clarity", "text": Catalog.clarity_name(l),
			"tip": "Clarity %d of 5 — %s. %s" % [l, Catalog.clarity_name(l), GemIcons.hint("clarity")]},
		{"glyph": "carat", "text": str(c),
			"tip": "Carat %d of 24 — multiplies this gem by %s. %s" % [c, number(Combat.carat_multiplier(c)), GemIcons.hint("carat")]},
		{"glyph": "", "text": str(Catalog.SKILLS.get(key, {}).get("name", key)),
			"tip": "%s gem — %s." % [Catalog.color_definition(key).get("name", "Red"), Catalog.color_definition(key).get("role", "Damage")]}]

static func title(gem: Dictionary) -> String:
	## The same line in plain words, for tooltips and anywhere a row will not fit.
	var pieces: PackedStringArray = []
	for part in title_parts(gem):
		pieces.append(str(part.text))
	return " ".join(pieces)

static func sentence(gem: Dictionary, effective_clarity: int = -1) -> String:
	## The resolved rule as words. Bare numbers name the property behind them, because
	## a tooltip has no marks to carry that meaning.
	var lines: PackedStringArray = []
	for block in blocks(gem, effective_clarity):
		var terms: PackedStringArray = []
		for part in block.parts:
			var term := str(part.text)
			if SOURCES.has(str(part.glyph)) and term.is_valid_int():
				term += " (%s)" % SOURCES[str(part.glyph)]
			if not part.factor.is_empty():
				term += " " + str(part.factor.text)
			terms.append(term)
		var line := "%s %s" % [block.verb, " + ".join(terms)]
		if not block.mult.is_empty():
			line += " " + str(block.mult.text)
		if not str(block.label).is_empty():
			line += " " + str(block.label)
		if not str(block.suffix).is_empty():
			line += " " + str(block.suffix)
		if not block.repeat.is_empty():
			line += ", " + str(block.repeat.text)
		lines.append(line + ".")
	return " ".join(lines)
