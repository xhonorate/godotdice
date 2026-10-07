class_name DeepDice
extends RefCounted
## Dice as items, and the rolls they make.
##
## A die is a shape, at most one pattern, any number of etched faces and at most one
## material. See docs/DICE.md. The four axes are orthogonal: a Ruby Split d12 with a
## Shiny face is all three at once, and every one of them is legal on any size.
##
##   shape      how many faces: d2 through d100.
##   pattern    which numbers sit on those faces. Baked into the face list when the die
##              is made; nothing reads it at roll time.
##   etching    one face's behaviour, stored as the face's `kind`:
##                plain      the ordinary face.
##                wild       counts as any value for patterns, and as the die's top.
##                exploding  rolls again and adds, up to MAX_EXPLOSIONS times.
##                shiny      +1 Resonance for every gem it helps activate.
##                golden     pyrite whenever it is rolled.
##                tally      climbs by one, permanently, every time it is landed on.
##                sticky     carries into the next turn instead of being rerolled.
##                twin       counts as two dice in every set.
##                doubled    its value counts double.
##                locked     once shown, the die cannot be rerolled this fight.
##                blank      nothing at all: no value, no pattern.
##   material   the whole die, every face, every roll. Colour comes from it and nothing
##              else. See MATERIALS.
##
## A roll is the record of one die's result this turn. Nothing here reads content except
## for a die's display name: the definitions are handed in.

## One shared progression for the smithy, enemy buffs and Dread. Unusual dice are
## reached by working through the ladder; starting bowls and encounters stay modest.
const TIERS: Array = ["D2", "D3", "D4", "D6", "D8", "D10", "D12", "D16", "D20", "D24", "D30", "D40", "D50", "D60", "D100"]
const SHAPES: Dictionary = {"D2": 2, "D3": 3, "D4": 4, "D6": 6, "D8": 8, "D10": 10, "D12": 12,
	"D16": 16, "D20": 20, "D24": 24, "D30": 30, "D40": 40, "D50": 50, "D60": 60, "D100": 100}

const FACE_KINDS: Array = ["plain", "wild", "exploding", "shiny", "golden", "tally", "sticky", "twin", "doubled", "locked", "blank"]
## Etchings worth paying for, and etchings an enemy leaves behind. `plain` is neither.
const BOON_FACES: Array = ["wild", "exploding", "shiny", "golden", "tally", "sticky", "twin", "doubled"]
const BANE_FACES: Array = ["locked", "blank"]

const PATTERNS: Array = ["even", "odd", "split", "gamblers", "paired", "stretched", "shallow"]
const MATERIALS: Array = ["ruby", "sapphire", "emerald", "amethyst", "citrine", "diamond",
	"opal", "glass", "crystal", "iron", "fools_gold", "granite", "blood"]
## The materials that answer to one colour, and the ones that answer to all of them.
const MATERIAL_COLORS: Dictionary = {"ruby": "RED", "sapphire": "BLUE", "emerald": "GREEN",
	"amethyst": "VIOLET", "citrine": "GOLD", "diamond": "WHITE"}
const ANY_COLOR_MATERIALS: Array = ["opal", "glass"]

const MAX_EXPLOSIONS: int = 3
const VALUE_CAP: int = 100
## Each matching material multiplies the gem it helps fire. Multiplicative: two Rubies on
## a red gem is 2.25x, five is 7.59x. Five of one colour is a run spent building it.
const STRENGTH_STEP: float = 1.5
const GLASS_SHATTER_PCT: float = 10.0
const CRYSTAL_RESONANCE: int = 1
const FOOLS_GOLD_PYRITE: int = 2
const GOLDEN_FACE_PYRITE: int = 2
const BLOOD_HP: int = 2
const IRON_FLOOR_DIVISOR: int = 4

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

static func size_of(shape: String) -> int:
	return int(SHAPES.get(shape, 6))

# --- patterns ---------------------------------------------------------------------------

static func pattern_allows(pattern: String, shape: String) -> bool:
	## Whether this pattern can be cut into this shape. A pattern is never offered for a die
	## that cannot take it.
	var n: int = size_of(shape)
	match pattern:
		"": return true
		"even", "odd": return n >= 4 and n % 2 == 0
		"split", "paired", "shallow": return n >= 6
		"gamblers": return n >= 6 and n <= 12
		"stretched": return n >= 4 and n * 2 <= VALUE_CAP
	return false

static func split_doublings(n: int) -> int:
	## How many extra copies of the lowest and highest a Split cuts: one up to a d16, two
	## to a d30, three beyond. A d20 shows three 1s and three 20s.
	if n < 20:
		return 1
	return 2 if n < 40 else 3

static func paired_values(n: int, rng: RandomNumberGenerator = null) -> Array:
	## The n/2 values a Paired die shows twice each. Without an RNG they come out evenly
	## spaced, so a die made outside a run is still the same die every time.
	var half: int = maxi(1, n / 2)
	var pool: Array = []
	for value in range(1, n + 1):
		pool.append(value)
	var picked: Array = []
	if rng == null:
		for index in range(half):
			picked.append(pool[mini(pool.size() - 1, index * 2)])
		return picked
	for _i in range(half):
		var at: int = rng.randi_range(0, pool.size() - 1)
		picked.append(int(pool[at]))
		pool.remove_at(at)
	picked.sort()
	return picked

static func pattern_faces(shape: String, pattern: String = "", rng: RandomNumberGenerator = null) -> Array:
	## The numbers a shape shows under a pattern, as faces. Etchings and materials are not
	## here: a pattern only ever moves numbers.
	var n: int = size_of(shape)
	var values: Array = []
	match pattern:
		"even":
			for i in range(1, n / 2 + 1):
				values.append(i * 2)
				values.append(i * 2)
		"odd":
			for i in range(1, n / 2 + 1):
				values.append(i * 2 - 1)
				values.append(i * 2 - 1)
		"split":
			var t: int = split_doublings(n)
			var gone_from: int = n / 2 - t + 1
			var gone_to: int = n / 2 + t
			for _extra in range(t):
				values.append(1)
			for value in range(1, n + 1):
				if value < gone_from or value > gone_to:
					values.append(value)
			for _extra in range(t):
				values.append(n)
		"gamblers":
			for value in range(1, n + 1):
				values.append(7 if value == 6 or value == 8 else value)
		"paired":
			for value in paired_values(n, rng):
				values.append(value)
				values.append(value)
		"stretched":
			for value in range(1, n + 1):
				values.append(mini(VALUE_CAP, value * 2))
		"shallow":
			for value in range(1, n + 1):
				values.append(int(ceil(float(value) / 2.0)))
		_:
			for value in range(1, n + 1):
				values.append(mini(VALUE_CAP, value))
	var faces: Array = []
	for value in values:
		faces.append(face(int(value)))
	return faces

static func pattern_top(shape: String, pattern: String) -> int:
	## A pattern may insist on a top its faces never reach. A Shallow die is judged against
	## the size it still is, which is what makes every face of the Phial a low one.
	return size_of(shape) if pattern == "shallow" else 0

# --- materials --------------------------------------------------------------------------

static func material_color(material: String) -> String:
	return str(MATERIAL_COLORS.get(material, ""))

static func material_matches(material: String, colors: Array) -> bool:
	## Whether this material answers to a gem of these colours. Opal and Glass answer to all.
	if material.is_empty():
		return false
	if material in ANY_COLOR_MATERIALS:
		return true
	var wanted: String = material_color(material)
	return not wanted.is_empty() and colors.has(wanted)

static func strength(rolls: Array, colors: Array) -> float:
	## What the dice that fired a gem multiply it by: STRENGTH_STEP for each material that
	## answers to its colour, multiplied together.
	var boost: float = 1.0
	for roll in rolls:
		if material_matches(str(roll.get("material", "")), colors):
			boost *= STRENGTH_STEP
	return boost

static func matching_materials(rolls: Array, colors: Array) -> Array:
	## Which materials among these dice answered to a gem of these colours, so a view can
	## say what made it hit that hard.
	var out: Array = []
	for roll in rolls:
		var material: String = str(roll.get("material", ""))
		if material_matches(material, colors):
			out.append(material)
	return out

static func shiny_count(rolls: Array) -> int:
	var count: int = 0
	for roll in rolls:
		if str(roll.get("kind", "plain")) == "shiny":
			count += 1
	return count

static func preference(roll: Dictionary, colors: Array = []) -> int:
	## How badly this die wants to be one of the dice that fires a gem. A material that
	## answers to the gem's colour first, then an etching worth having, then any material
	## at all: three sixes and a Shiny six should spend the Shiny one.
	var score: int = 0
	var material: String = str(roll.get("material", ""))
	if material_matches(material, colors):
		score += 4
	if str(roll.get("kind", "plain")) in BOON_FACES:
		score += 2
	if not material.is_empty():
		score += 1
	return score

# --- making a die -----------------------------------------------------------------------

static func make(shape: String, id: String, opts: Dictionary = {}) -> Dictionary:
	## A die from its four axes. `opts` may carry pattern, material, etches (a map of face
	## index to kind, or an array of {face, kind}), faces (already rolled, which wins over
	## the pattern), name and top.
	var key: String = shape if SHAPES.has(shape) else "D6"
	var pattern: String = str(opts.get("pattern", ""))
	if not pattern.is_empty() and not pattern_allows(pattern, key):
		pattern = ""
	var faces: Array = opts.get("faces", []) if opts.get("faces", []) is Array and not opts.get("faces", []).is_empty() else pattern_faces(key, pattern, opts.get("rng", null))
	var die: Dictionary = {"id": id, "shape": key, "pattern": pattern, "faces": faces.duplicate(true),
		"material": str(opts.get("material", "")), "name": str(opts.get("name", ""))}
	for entry in _etch_list(opts.get("etches", [])):
		etch(die, int(entry.get("face", -1)), str(entry.get("kind", "plain")))
	var top_override: int = int(opts.get("top", pattern_top(key, pattern)))
	if top_override > 0:
		## A die may be judged against a face it cannot show: the Phial is a d6 that never
		## rolls past 3, so every face of it is low and none of them is a crown.
		die.top = mini(VALUE_CAP, top_override)
	return die

static func _etch_list(etches: Variant) -> Array:
	var out: Array = []
	if etches is Array:
		for entry in etches:
			if entry is Dictionary:
				out.append(entry)
	elif etches is Dictionary:
		for at in etches:
			out.append({"face": int(at), "kind": str(etches[at])})
	return out

static func etch(die: Dictionary, index: int, kind: String) -> bool:
	## Cut one etching into one face. Returns false if there is no such face or no such
	## etching; a face only ever carries one.
	var faces: Array = die.get("faces", [])
	if index < 0 or index >= faces.size() or not kind in FACE_KINDS:
		return false
	faces[index] = face(int(faces[index].get("value", 0)), kind)
	return true

static func etchings(die: Dictionary) -> Array:
	## Every etched face of this die, as {face, kind}, in face order.
	var out: Array = []
	var faces: Array = die.get("faces", [])
	for index in range(faces.size()):
		var kind: String = str(faces[index].get("kind", "plain"))
		if kind != "plain":
			out.append({"face": index, "kind": kind})
	return out

static func reset(die: Dictionary) -> void:
	## Back to the plain numbers of its size: no pattern, no etchings. The material is not a
	## face and stays, and so does the die's id.
	die.pattern = ""
	die.faces = pattern_faces(str(die.get("shape", "D6")))
	die.erase("top")

static func face_value(f: Dictionary) -> int:
	## What a face is worth before the die's material speaks: nothing at all when it is
	## blank, twice its number when it is doubled.
	var kind: String = str(f.get("kind", "plain"))
	if kind == "blank":
		return 0
	var value: int = int(f.get("value", 0))
	return mini(VALUE_CAP, value * 2 if kind == "doubled" else value)

static func top(die: Dictionary) -> int:
	## The most this die can show on one face: what totals measure themselves against.
	if int(die.get("top", 0)) > 0:
		return mini(VALUE_CAP, int(die.top))
	var best: int = 0
	for f in die.get("faces", []):
		best = maxi(best, face_value(f))
	return mini(VALUE_CAP, best)

static func iron_floor(die_top: int) -> int:
	return int(ceil(float(die_top) / float(IRON_FLOOR_DIVISOR)))

# --- rolling ----------------------------------------------------------------------------

static func roll_one(die: Dictionary, rng: RandomNumberGenerator, times_rerolled: int = 0) -> Dictionary:
	## One throw. A Tally face climbs as it is landed on, which writes to the die itself, and
	## Glass decides here whether this was the throw that broke it: both are reported on the
	## roll so the fight can pay them out and the view can play them.
	var faces: Array = die.get("faces", [])
	if faces.is_empty():
		faces = [face(1)]
	var index: int = rng.randi_range(0, faces.size() - 1)
	var chosen: Dictionary = faces[index]
	var kind: String = str(chosen.get("kind", "plain"))
	var material: String = str(die.get("material", ""))
	var climbed: bool = false
	if kind == "tally":
		chosen.value = mini(VALUE_CAP, int(chosen.get("value", 0)) + 1)
		climbed = true
	var value: int = face_value(chosen)
	var explosions: int = 0
	var chain: Array = []
	if kind == "exploding":
		while explosions < MAX_EXPLOSIONS:
			var again: int = rng.randi_range(0, faces.size() - 1)
			var extra: Dictionary = faces[again]
			value += face_value(extra)
			chain.append({"face": again, "value": face_value(extra)})
			explosions += 1
			if str(extra.get("kind", "plain")) != "exploding":
				break
	var die_top: int = top(die)
	if kind != "blank" and material == "iron":
		value = maxi(value, iron_floor(die_top))
	var shattered: bool = material == "glass" and DeepRng.chance(rng, GLASS_SHATTER_PCT)
	var thrown: Dictionary = {"die_id": str(die.get("id", "")), "shape": str(die.get("shape", "D6")), "material": material,
		"value": mini(value, VALUE_CAP), "face": index, "kind": kind, "top": die_top,
		"held": false, "rerolls": times_rerolled, "locked": kind == "locked", "explosions": explosions,
		"climbed": climbed, "shattered": shattered, "phantom": false}
	## The number printed on the face it landed on, when what it counts for is something else:
	## an Iron floor, a Doubled face, a face that went off and threw again. A trigger that asks
	## for dice showing a number reads this; everything that adds up reads `value`. `counted`
	## is what `value` was when it was thrown, so a roll a gem has since changed is known.
	if kind != "blank" and int(chosen.get("value", 0)) != int(thrown.value):
		thrown.shown = int(chosen.get("value", 0))
		thrown.counted = int(thrown.value)
	if kind == "exploding":
		## What the face itself says, before anything it threw again was added: the number an
		## upgrade changes, and the one a gem that asks for low dice should be judging.
		thrown.base = face_value(chosen)
		## Each throw after it, in order, so the die can be seen to land on them one by one.
		thrown.chain = chain
	return thrown

static func roll_hand(dice: Array, rng: RandomNumberGenerator, previous: Array = []) -> Array:
	## A fresh hand. A Sticky face that was showing at the end of the last turn is not thrown
	## again: the die keeps it while the rest of the bowl comes up new.
	## A die a creature locked (`lock_next`) is carried the same way, and comes up locked: it
	## shows what it showed and refuses to be thrown again this turn.
	var kept: Dictionary = {}
	for roll in previous:
		if (str(roll.get("kind", "plain")) == "sticky" or bool(roll.get("lock_next", false))) and not bool(roll.get("phantom", false)):
			kept[str(roll.get("die_id", ""))] = roll
	var hand: Array = []
	for die in dice:
		var id: String = str(die.get("id", ""))
		if kept.has(id):
			var carried: Dictionary = kept[id].duplicate(true)
			carried.held = true
			carried.rerolls = 0
			carried.phantom = false
			carried.climbed = false
			carried.shattered = false
			carried.carried = true
			if bool(carried.get("lock_next", false)):
				carried.locked = true
				carried.lock_next = false
				carried.locked_by_foe = true
			hand.append(carried)
		else:
			hand.append(roll_one(die, rng))
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
			kept.climbed = false
			kept.shattered = false
			out.append(kept)
	return out

static func rerollable(hand: Array) -> Array:
	var ids: Array = []
	for roll in hand:
		if not bool(roll.get("locked", false)) and not bool(roll.get("phantom", false)):
			ids.append(str(roll.get("die_id", "")))
	return ids

static func throw_dues(rolls: Array) -> Dictionary:
	## What a throw owes the table, read off the dice that were actually thrown: Crystal's
	## Resonance, the pyrite a Fool's Gold die and a Golden face pay out, the blood a Blood
	## die takes for being thrown again, the Tally faces that climbed and the Glass that
	## broke. Shiny is not here: it is paid when a gem fires, not when the die lands.
	var out: Dictionary = {"resonance": 0, "pyrite": 0, "hp": 0, "climbed": [], "shattered": []}
	for roll in rolls:
		if bool(roll.get("phantom", false)) or bool(roll.get("carried", false)):
			continue
		var material: String = str(roll.get("material", ""))
		var kind: String = str(roll.get("kind", "plain"))
		var id: String = str(roll.get("die_id", ""))
		if material == "crystal":
			out.resonance += CRYSTAL_RESONANCE
		if material == "fools_gold":
			out.pyrite += FOOLS_GOLD_PYRITE
		if kind == "golden":
			out.pyrite += GOLDEN_FACE_PYRITE
		if material == "blood" and int(roll.get("rerolls", 0)) > 0:
			out.hp += BLOOD_HP
		if bool(roll.get("climbed", false)):
			out.climbed.append({"die": id, "value": int(roll.get("value", 0))})
		if bool(roll.get("shattered", false)):
			out.shattered.append(id)
	return out

static func phantom(source: Dictionary, id: String) -> Dictionary:
	## A copy of a roll that exists only for the gems after the one that made it.
	var ghost: Dictionary = source.duplicate(true)
	ghost.die_id = id
	ghost.phantom = true
	ghost.held = false
	ghost.rerolls = 0
	ghost.locked = false
	ghost.climbed = false
	ghost.shattered = false
	return ghost

static func held_for_patterns(roll: Dictionary) -> bool:
	## A die is held when it was not rerolled this turn. `held` is only set as a reroll
	## passes a die by, so a hand locked in untouched counts every real die as held too;
	## an Anchor that only worked once something else had been rerolled was this. A Sticky
	## face carried in from last turn was never thrown at all, so it counts as well.
	if bool(roll.get("held", false)):
		return true
	return int(roll.get("rerolls", 0)) == 0 and not bool(roll.get("phantom", false))

static func values(hand: Array) -> Array:
	var out: Array = []
	for roll in hand:
		out.append(int(roll.get("value", 0)))
	return out

# --- saying what a die is -----------------------------------------------------------------

static func pattern_name(pattern: String) -> String:
	if pattern.is_empty():
		return ""
	var named: Dictionary = DeepContent.entry("patterns", pattern.to_upper())
	return str(named.get("name", pattern.capitalize()))

static func material_name(material: String) -> String:
	if material.is_empty():
		return ""
	var named: Dictionary = DeepContent.entry("materials", material.to_upper())
	return str(named.get("name", material.capitalize().replace("_", " ")))

static func etching_name(kind: String) -> String:
	if kind == "plain" or kind.is_empty():
		return ""
	var named: Dictionary = DeepContent.entry("etchings", kind.to_upper())
	return str(named.get("name", kind.capitalize()))

static func given_name(die: Dictionary) -> String:
	## The name a character gave this die, or "". Older saves wrote a stock name onto every
	## die ("D20", "Gambler's Die") that only ever said what it was when it was made: a d20
	## hammered into a d24 must not go on calling itself a d20, so those are not names.
	var own: String = str(die.get("name", ""))
	if own.is_empty() or SHAPES.has(own.to_upper()):
		return ""
	if die.has("key"):
		for key in DeepContent.section("characters"):
			for ref in DeepContent.character(str(key)).get("dice", []):
				if ref is Dictionary and str(ref.get("name", "")) == own:
					return own
		return ""
	return own

static func describe(die: Dictionary) -> String:
	## "d12", "Ruby d12", "Split d12", "Ruby Split d12 · shiny": the way a die is named in a
	## list. A die given its own name by a character keeps it.
	var own: String = given_name(die)
	if not own.is_empty():
		return own
	var shape: String = str(die.get("shape", "D6")).to_lower()
	var words: Array = []
	var material: String = material_name(str(die.get("material", "")))
	if not material.is_empty():
		words.append(material)
	var pattern: String = pattern_name(str(die.get("pattern", "")))
	if not pattern.is_empty():
		words.append(pattern)
	words.append(shape)
	var marks: Array = []
	for entry in etchings(die):
		var name: String = etching_name(str(entry.kind))
		if not marks.has(name):
			marks.append(name)
	var text: String = " ".join(words)
	return text if marks.is_empty() else text + " · " + ", ".join(marks).to_lower()
