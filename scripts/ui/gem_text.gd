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

## What each effect is tinted with, so a build reads by colour before it reads by word.
const TONES := {
	"damage": "RED", "block": "BLUE", "heal": "GREEN", "gold": "GOLD",
	"poison": "VIOLET", "stun": "VIOLET", "strip": "AMBER", "revive": "GREEN"}
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
	if not Catalog.SKILLS.has(key):
		return []
	var c: int = clampi(int(gem.get("carat", 1)), 1, 24)
	var k: int = clampi(int(gem.get("cut", 1)), 1, 5)
	var stored: int = clampi(int(gem.get("clarity", 1)), 1, 5)
	var l: int = clampi(effective_clarity, 1, 5) if effective_clarity > 0 else stored
	var flat: Dictionary = _clarity(stored, l)
	var cut_name: String = Catalog.cut_name(k)
	var built: Array = []
	match key:
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
	return built

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
