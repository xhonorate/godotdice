class_name DeepDice
extends RefCounted
## Dice as items, and the rolls they make.
##
## A die is a definition (shape, faces, engraving) made into an instance with an id. A face
## has a value and a kind:
##   plain      the ordinary face.
##   wild       counts as any value for patterns and as the die's top for totals.
##   gem        every gem in the rail fires this turn, whatever the hand shows.
##   exploding  rolls the die again and adds the result, up to MAX_EXPLOSIONS times.
##   locked     once shown, the die cannot be rerolled for the rest of the fight.
##   mirror     copies the highest other die in the hand.
##   blank      nothing at all: no value, no pattern.
## An engraving is one permanent trait on the die:
##   always_held  counts as held even when it was rerolled.
##   twin         counts as two dice for set patterns (pairs, triples, ...).
##   keen         +1 to every face that shows a value.
##   steady       never shows less than 2.
## A roll is the record of one die's result this turn. Nothing here reads content: the
## definitions are handed in.

const SHAPES: Dictionary = {"D4": 4, "D6": 6, "D8": 8, "D10": 10, "D12": 12, "D20": 20}
const FACE_KINDS: Array = ["plain", "wild", "gem", "exploding", "locked", "mirror", "blank"]
const ENGRAVINGS: Array = ["always_held", "twin", "keen", "steady"]
const MAX_EXPLOSIONS: int = 3
const VALUE_CAP: int = 20

static func face(value: int, kind: String = "plain") -> Dictionary:
	return {"value": value, "kind": kind}

static func faces_of(definition: Dictionary) -> Array:
	var out: Array = []
	for entry in definition.get("faces", []):
		if entry is Dictionary:
			out.append(face(int(entry.get("value", 0)), str(entry.get("kind", "plain"))))
		else:
			out.append(face(int(entry)))
	return out

static func make(key: String, definition: Dictionary, id: String, engraving: String = "") -> Dictionary:
	var chosen: String = engraving if not engraving.is_empty() else str(definition.get("engraving", ""))
	var die: Dictionary = {"id": id, "key": key, "name": str(definition.get("name", key)),
		"shape": str(definition.get("shape", "D6")), "faces": faces_of(definition), "engraving": chosen}
	if int(definition.get("top", 0)) > 0:
		## A die may be judged against a face it cannot show: the Phial is a d6 that never
		## rolls past 3, so every face of it is low and none of them is a crown.
		die.top = int(definition.top)
	return die

static func top(die: Dictionary) -> int:
	## The most this die can show on one face: what totals measure themselves against.
	if int(die.get("top", 0)) > 0:
		return mini(VALUE_CAP, int(die.top))
	var best: int = 0
	for f in die.get("faces", []):
		if str(f.get("kind", "plain")) != "blank":
			best = maxi(best, int(f.get("value", 0)))
	if str(die.get("engraving", "")) == "keen":
		best += 1
	return mini(VALUE_CAP, best)

static func roll_one(die: Dictionary, rng: RandomNumberGenerator, times_rerolled: int = 0) -> Dictionary:
	var faces: Array = die.get("faces", [])
	if faces.is_empty():
		faces = [face(1)]
	var index: int = rng.randi_range(0, faces.size() - 1)
	var chosen: Dictionary = faces[index]
	var kind: String = str(chosen.get("kind", "plain"))
	var value: int = int(chosen.get("value", 0))
	var explosions: int = 0
	if kind == "exploding":
		while explosions < MAX_EXPLOSIONS:
			var extra: Dictionary = faces[rng.randi_range(0, faces.size() - 1)]
			value += int(extra.get("value", 0))
			explosions += 1
			if str(extra.get("kind", "plain")) != "exploding":
				break
	var engraving: String = str(die.get("engraving", ""))
	if kind == "blank":
		value = 0
	else:
		if engraving == "keen":
			value += 1
		if engraving == "steady":
			value = maxi(value, 2)
	return {"die_id": str(die.get("id", "")), "key": str(die.get("key", "")), "shape": str(die.get("shape", "D6")),
		"value": mini(value, VALUE_CAP), "face": index, "kind": kind, "top": top(die),
		"held": false, "rerolls": times_rerolled, "locked": kind == "locked", "explosions": explosions,
		"engraving": engraving, "phantom": false}

static func roll_hand(dice: Array, rng: RandomNumberGenerator) -> Array:
	var hand: Array = []
	for die in dice:
		hand.append(roll_one(die, rng))
	_resolve_mirrors(hand)
	return hand

static func reroll(hand: Array, dice: Array, die_ids: Array, rng: RandomNumberGenerator) -> Array:
	## Selected means reroll. Everything else is held. A locked die refuses.
	var by_id: Dictionary = {}
	for die in dice:
		by_id[str(die.get("id", ""))] = die
	var out: Array = []
	for roll in hand:
		if bool(roll.get("phantom", false)):
			continue
		var id: String = str(roll.get("die_id", ""))
		if id in die_ids and not bool(roll.get("locked", false)) and by_id.has(id):
			out.append(roll_one(by_id[id], rng, int(roll.get("rerolls", 0)) + 1))
		else:
			var kept: Dictionary = roll.duplicate(true)
			kept.held = true
			out.append(kept)
	_resolve_mirrors(out)
	return out

static func rerollable(hand: Array) -> Array:
	var ids: Array = []
	for roll in hand:
		if not bool(roll.get("locked", false)) and not bool(roll.get("phantom", false)):
			ids.append(str(roll.get("die_id", "")))
	return ids

static func phantom(source: Dictionary, id: String) -> Dictionary:
	## A copy of a roll that exists only for the gems after the one that made it.
	var ghost: Dictionary = source.duplicate(true)
	ghost.die_id = id
	ghost.phantom = true
	ghost.held = false
	ghost.rerolls = 0
	ghost.locked = false
	if str(ghost.get("kind", "plain")) == "mirror":
		ghost.kind = "plain"
	return ghost

static func held_for_patterns(roll: Dictionary) -> bool:
	return bool(roll.get("held", false)) or str(roll.get("engraving", "")) == "always_held"

static func resolve_mirrors(hand: Array) -> void:
	## Public for the battle, which re-throws single dice (a Gambler's ones, a Harlequin's flip).
	_resolve_mirrors(hand)

static func _resolve_mirrors(hand: Array) -> void:
	var best: int = 0
	for roll in hand:
		if str(roll.get("kind", "plain")) != "mirror":
			best = maxi(best, int(roll.get("value", 0)))
	for roll in hand:
		if str(roll.get("kind", "plain")) == "mirror":
			roll.value = mini(best, VALUE_CAP)

static func values(hand: Array) -> Array:
	var out: Array = []
	for roll in hand:
		out.append(int(roll.get("value", 0)))
	return out

static func describe(die: Dictionary) -> String:
	## "D6" or "D6 · keen", the way a die is named in a list.
	var name: String = str(die.get("name", die.get("key", "die")))
	var engraving: String = str(die.get("engraving", ""))
	return name if engraving.is_empty() else name + " · " + engraving.replace("_", " ")
