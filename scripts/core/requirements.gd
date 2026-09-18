extends RefCounted
## What a hand has to show before something fires, as data a screen can draw.
##
## Every gem trigger, hero passive and signature reduces to one of a small set of kinds —
## a pair, a straight of some length, a total over a line — plus the number that kind needs,
## resolved against the ranks of the thing asking. The interface turns a kind into its own
## pictograph and the number into a short label beside it; the words here are the sentence a
## tooltip and a "Needs …" line use, and they never name a rank by a letter.
##
## A trigger that always fires still has something to say: what it grows with. Strike reads
## your highest dice, so its requirement is "highest die", not "always".
##
## Nothing here evaluates a hand. The branches mirror `combat.gd`; if they ever disagree,
## combat is right and this is the bug.

const Catalog = preload("res://scripts/core/catalog.gd")
const GemRules = preload("res://scripts/core/gem_rules.gd")

## Every kind a requirement can be. Each one has a pictograph of its own in `dice_icons.gd`.
const KINDS: Array = ["scale", "pair", "two_pairs", "triple", "quad", "full_house", "straight",
	"odd", "even", "distinct", "value", "total_at_least", "total_at_most", "high_at_least",
	"climb", "once"]

static func straight_length(clarity: int) -> int:
	return 5 - int((clampi(clarity, 1, 5) - 1) / 2)

static func make(kind: String, amount: int = 0, scale: String = "", label: String = "") -> Dictionary:
	## `amount` is the count or threshold the kind needs; `scale` names what an always-firing
	## effect grows with, and `label` the short phrase drawn beside the mark.
	var built := {"kind": kind, "amount": amount, "scale": scale, "label": label}
	built.label = label if not label.is_empty() else _label(built)
	built.need = _need(built)
	built.words = _words(built)
	return built

static func skill(key: String, clarity: int = 1, cut: int = 1, carat: int = 1) -> Dictionary:
	## A gem's requirement at the Clarity it is resolved with. Cut and Carat matter only to a
	## rule written as data, whose thresholds may be built from any rank.
	key = Catalog.canonical_key(key)
	var l: int = clampi(clarity, 1, 5)
	var k: int = clampi(cut, 1, 5)
	var definition: Dictionary = Catalog.definitions("skills").get(key, {})
	if GemRules.has_rule(definition):
		return _authored(definition.rule, l, k, clampi(carat, 1, 24))
	var rule: String = Catalog.canonical_key(str(definition.get("evaluator_id", key)))
	match rule:
		"STRIKE":
			return make("scale", k, "high", "highest die" if k == 1 else "highest %d dice" % k)
		"HEAL":
			return make("scale", k, "low", "lowest die" if k == 1 else "lowest %d dice" % k)
		"GLIMMER":
			return make("scale", 1, "low", "lowest die")
		"REFRACT":
			return make("scale", 1, "high", "highest die")
		"SECOND_SIGHT":
			return make("scale", 0, "carat", "Carat")
		"BLOCK", "INTERPOSE", "TITHE", "ECHO":
			return make("pair")
		"HEAVYSTRIKE", "ENERVATE":
			return make("triple")
		"QUARTET":
			return make("triple" if l == 5 else "quad")
		"SHIELDBASH":
			return make("full_house")
		"SUNDER", "GRAFT":
			return make("two_pairs")
		"MULTISTRIKE", "LIFELINE":
			return make("straight", straight_length(l))
		"BLESSING", "ARC_BURST":
			return make("straight", 3)
		"LUCKYSTRIKE":
			return make("value", 7)
		"MEND", "HEXBOLT":
			return make("odd", 3)
		"EVEN_TEMPO", "PURGE", "MIASMA":
			return make("even", 3)
		"PRECISION":
			return make("distinct", 5)
		"FACET", "MINT":
			return make("distinct", straight_length(l))
		"STUN":
			return make("high_at_least", 21 - l)
		"VENOM":
			return make("high_at_least", 13 - l)
		"BULWARK", "BASTION", "WAGER":
			return make("total_at_most", 18 + 2 * l)
		"DRAINSTRIKE":
			return make("total_at_least", 45 - 5 * l)
	return make("scale", 0, "carat", "every hand")

static func passive(trait_id: String) -> Dictionary:
	match trait_id:
		"STAND_FIRM":
			return make("pair")
		"CALCULATED_RISK":
			return make("climb", 4)
		"SECOND_THOUGHT":
			return make("once", 1)
	return make("scale", 0, "carat", "every hand")

static func signature(signature_id: String) -> Dictionary:
	match signature_id:
		"UNBREAKABLE_VOW":
			return make("quad")
		"LONG_ODDS":
			return make("total_at_least", 33)
		"MASTER_PLAN":
			return make("straight", 5)
	return {}

static func _authored(rule: Dictionary, l: int, k: int, c: int) -> Dictionary:
	var trigger: Variant = rule.get("trigger", {})
	if not trigger is Dictionary:
		return make("scale", 0, "carat", "every hand")
	var count := func(expression: Variant, fallback: int) -> int:
		return GemRules.threshold(expression, c, k, l) if expression is Dictionary else fallback
	match str(trigger.get("kind", "always")):
		"pair": return make("pair")
		"two_pairs": return make("two_pairs")
		"triple": return make("triple")
		"full_house": return make("full_house")
		"straight":
			var length: int = straight_length(l) if trigger.get("length", null) is String else int(count.call(trigger.get("length", null), 3))
			return make("straight", clampi(length, 1, 5))
		"parity":
			var wanted: int = clampi(int(count.call(trigger.get("at_least", null), 3)), 1, 5)
			return make("odd" if str(trigger.get("parity", "even")) == "odd" else "even", wanted)
		"distinct":
			return make("distinct", clampi(int(count.call(trigger.get("at_least", null), 5)), 1, 5))
		"value":
			return make("value", int(trigger.get("value", 7)))
		"total_at_least":
			return make("total_at_least", int(count.call(trigger.get("amount", null), 0)))
		"total_at_most":
			return make("total_at_most", int(count.call(trigger.get("amount", null), 0)))
		"high_at_least":
			return make("high_at_least", int(count.call(trigger.get("amount", null), 0)))
	## An always-firing rule is described by the first part of the hand its first effect reads.
	for effect in rule.get("effects", []):
		if effect is Dictionary:
			var found: String = _first_term(effect.get("amount", {}))
			match found:
				"high", "highest_sum", "run_high": return make("scale", 1, "high", "highest die")
				"low", "lowest_sum", "lowest_odd": return make("scale", 1, "low", "lowest die")
				"total": return make("scale", 1, "sum", "your total")
				"count_even", "count_odd", "count_distinct", "count_value": return make("scale", 1, "count", "matching dice")
				"block": return make("scale", 1, "shield", "your block")
			break
	return make("scale", 0, "carat", "every hand")

static func _first_term(expression: Variant) -> String:
	if not expression is Dictionary:
		return ""
	if expression.has("term"):
		return str(expression.term)
	for argument in expression.get("args", []):
		var found: String = _first_term(argument)
		if not found.is_empty():
			return found
	return ""

static func _label(requirement: Dictionary) -> String:
	## The few characters drawn beside the mark. A mark that says everything gets none.
	var amount: int = int(requirement.get("amount", 0))
	match str(requirement.get("kind", "")):
		"odd", "even", "distinct": return "×%d" % amount
		"value": return str(amount)
		"total_at_least", "high_at_least": return "≥%d" % amount
		"total_at_most": return "≤%d" % amount
		"climb": return "+%d" % amount
		"once": return "once"
	return ""

static func _need(requirement: Dictionary) -> String:
	## The requirement as the object of "Needs …".
	var amount: int = int(requirement.get("amount", 0))
	match str(requirement.get("kind", "")):
		"scale": return "nothing — it fires on every hand"
		"pair": return "a pair"
		"two_pairs": return "two pairs"
		"triple": return "three of a kind"
		"quad": return "four of a kind"
		"full_house": return "a full house"
		"straight": return "a straight of %d" % amount
		"odd": return "at least %d odd dice" % amount
		"even": return "at least %d even dice" % amount
		"distinct": return "at least %d different values" % amount
		"value": return "a %d" % amount
		"total_at_least": return "a total of %d or more" % amount
		"total_at_most": return "a total of %d or less" % amount
		"high_at_least": return "a die showing %d or more" % amount
		"climb": return "a die rerolled at least %d higher" % amount
		"once": return "its one use this battle"
	return "its trigger"

static func _words(requirement: Dictionary) -> String:
	## The full sentence for a tooltip or a sheet.
	var amount: int = int(requirement.get("amount", 0))
	match str(requirement.get("kind", "")):
		"scale":
			match str(requirement.get("scale", "")):
				"high": return "Fires on every hand. It grows with your %s." % str(requirement.label)
				"low": return "Fires on every hand. It grows with your %s." % str(requirement.label)
				"sum": return "Fires on every hand. It grows with your total."
				"count": return "Fires on every hand. It grows with how many dice qualify."
				"shield": return "Fires on every hand. It grows with your block."
			return "Fires on every hand. It grows with the gem's Carat."
		"pair": return "Pair: any two dice showing the same value."
		"two_pairs": return "Two pairs: two dice of one value and two of another."
		"triple": return "Three of a kind: any three dice showing the same value."
		"quad": return "Four of a kind: any four dice showing the same value."
		"full_house": return "Full house: three dice of one value and two of another."
		"straight": return "Straight of %d: %d consecutive values, in any order." % [amount, amount]
		"odd": return "At least %d dice showing odd values." % amount
		"even": return "At least %d dice showing even values." % amount
		"distinct": return "At least %d dice with no two alike." % amount
		"value": return "At least one die showing %d." % amount
		"total_at_least": return "All five dice add up to %d or more." % amount
		"total_at_most": return "All five dice add up to %d or less." % amount
		"high_at_least": return "Your highest die shows %d or more." % amount
		"climb": return "A die you rerolled finishes at least %d higher than it started this turn." % amount
		"once": return "Once per battle, whenever you choose."
	return ""
