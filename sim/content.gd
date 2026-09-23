class_name DeepContent
extends RefCounted
## The content pack: every skill, inclusion, die, character, creature, mine and oddity, as data.
##
## The pack is one JSON file. It is loaded once and read everywhere through the accessors
## here, and `validate()` is the same check the studio runs as an author types. A rule the
## build does not know is a validation error, never a crash at the table.

const PATH: String = "res://content/deep_cut.json"
const color_KEYS: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]
const SOCKET_ANY: String = "ANY"
## Opal is the seventh color, and the only one no socket is ever cut for. An opal skill
## counts as every color at once, so it sits in any socket and rings in harmony with
## whatever fired before it. Nothing in the rock offers one: they come out of a hoard.
const OPAL: String = "OPAL"
## The colors a skill may wear. Sockets and mine leanings still speak only of the six.
const SKILL_COLORS: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE", "OPAL"]
## The cuts a Birthstone may wear. Each is drawn as its own solid, outside the six colors.
const BIRTHSTONE_STYLES: Array = ["shield", "marquise", "step", "briolette", "checkerboard", "heptagon"]
const INCLUSION_CLASSES: Array = ["PINPOINT", "LENS", "FEATHER", "FRACTURE", "STAR"]
const RARITIES: Array = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY", "MYTHIC"]
const CHAMBER_KINDS: Array = ["fight", "elite", "vein", "oddity", "merchant", "smithy", "carver", "well"]
const PASSIVE_KINDS: Array = ["none", "extra_reroll", "first_gem_cut_step", "heal_on_fizzle", "first_fizzle_free",
	"heal_per_unused_reroll", "block_per_hit", "heal_on_poison_tick", "free_flip", "free_reroll_value"]
const GIMMICKS: Array = ["", "steal_high_die", "block_from_high", "reflect_zero_resonance", "cloud_socket", "split_on_big_hit",
	"steal_gold", "gift_rerolls", "poison_immune", "bury_socket", "mirror_last_gem", "roll_for_you", "regrow"]

static var _pack: Dictionary = {}
static var _path: String = PATH

static func pack() -> Dictionary:
	if _pack.is_empty():
		_pack = load_file(_path)
	return _pack

static func set_pack(loaded: Dictionary) -> void:
	_pack = loaded

static func use_path(path: String) -> void:
	_path = path
	_pack = {}

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("content pack missing: " + path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("content pack is not a JSON object: " + path)
		return {}
	return parsed

static func section(name: String) -> Dictionary:
	var found: Variant = pack().get(name, {})
	return found if found is Dictionary else {}

static func entry(section_name: String, key: String) -> Dictionary:
	var found: Variant = section(section_name).get(key, {})
	return found if found is Dictionary else {}

static func skill(key: String) -> Dictionary: return entry("skills", key)
static func inclusion(key: String) -> Dictionary: return entry("inclusions", key)
static func die(key: String) -> Dictionary: return entry("dice", key)
static func engraving(key: String) -> Dictionary: return entry("engravings", key)
static func character(key: String) -> Dictionary: return entry("characters", key)
static func creature(key: String) -> Dictionary: return entry("creatures", key)
static func mine(key: String) -> Dictionary: return entry("mines", key)
static func oddity(key: String) -> Dictionary: return entry("oddities", key)
static func boon(key: String) -> Dictionary: return entry("boons", key)
static func color(key: String) -> Dictionary: return entry("colors", key)

static func constant(name: String, fallback: Variant) -> Variant:
	var constants: Variant = pack().get("constants", {})
	if constants is Dictionary and constants.has(name):
		return constants[name]
	return fallback

static func cuts() -> Array:
	var found: Variant = pack().get("cuts", [])
	return found if found is Array else []

static func clarities() -> Array:
	var found: Variant = pack().get("clarities", [])
	return found if found is Array else []

static func cut_name(cut: int) -> String:
	var list: Array = cuts()
	if list.is_empty():
		return str(cut)
	return str(list[clampi(cut, 0, list.size() - 1)].get("name", cut))

static func clarity_name(clarity: int) -> String:
	var list: Array = clarities()
	if list.is_empty():
		return str(clarity)
	return str(list[clampi(clarity, 0, list.size() - 1)].get("name", clarity))

static func clarity_entry(clarity: int) -> Dictionary:
	var list: Array = clarities()
	if list.is_empty():
		return {}
	return list[clampi(clarity, 0, list.size() - 1)]

static func clarity_index(key: String) -> int:
	var list: Array = clarities()
	for index in range(list.size()):
		if str(list[index].get("key", "")) == key:
			return index
	return -1

static func clear_index() -> int:
	## Clear is the middle of the clarity ladder: no inclusions and no bonus.
	var found: int = clarity_index("CLEAR")
	return found if found >= 0 else int(clarities().size() / 2)

static func rarity_weight(rarity: String) -> float:
	return float(entry("rarities", rarity).get("weight", 1))

static func rarity_score(rarity: String) -> float:
	return float(entry("rarities", rarity).get("score", 0))

static func starter_mine() -> String:
	for key in section("mines"):
		if bool(section("mines")[key].get("starter", false)):
			return str(key)
	var keys: Array = section("mines").keys()
	keys.sort()
	return str(keys[0]) if not keys.is_empty() else ""

static func starter_character() -> String:
	for key in section("characters"):
		if bool(section("characters")[key].get("starter", false)):
			return str(key)
	var order: Array = characters_in_unlock_order()
	return str(order[0]) if not order.is_empty() else ""

static func characters_in_unlock_order() -> Array:
	## Every character key, the starter first, then by unlock_order, then by name.
	var keys: Array = section("characters").keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ca: Dictionary = character(a)
		var cb: Dictionary = character(b)
		if bool(ca.get("starter", false)) != bool(cb.get("starter", false)):
			return bool(ca.get("starter", false))
		if int(ca.get("unlock_order", 99)) != int(cb.get("unlock_order", 99)):
			return int(ca.get("unlock_order", 99)) < int(cb.get("unlock_order", 99))
		return a < b)
	return keys

static func character_title(key: String) -> String:
	## "Ardor, the Knight".
	var def: Dictionary = character(key)
	var title: String = str(def.get("title", ""))
	return str(def.get("name", key)) + (", " + title if not title.is_empty() else "")

# --- validation ------------------------------------------------------------------------

static func validate(p: Dictionary = {}) -> Array:
	## Everything wrong with a pack, in the order an author would fix it.
	if p.is_empty():
		p = pack()
	var errors: Array = []
	for required in ["colors", "cuts", "clarities", "rarities", "skills", "inclusions", "dice", "characters", "creatures", "mines"]:
		if not p.has(required):
			errors.append("pack is missing its %s section" % required)
	if not errors.is_empty():
		return errors
	if not p.cuts is Array or p.cuts.size() != DeepPatterns.STEPS:
		errors.append("cuts must list exactly %d grades" % DeepPatterns.STEPS)
	if not p.clarities is Array or p.clarities.size() < 3:
		errors.append("clarities must list at least three grades")
	for key in p.skills:
		errors.append_array(DeepRules.validate_skill(p.skills[key], p).map(func(e: String) -> String: return "skill %s: %s" % [key, e]))
	for key in p.inclusions:
		errors.append_array(DeepRules.validate_inclusion(p.inclusions[key], p).map(func(e: String) -> String: return "inclusion %s: %s" % [key, e]))
	for key in p.dice:
		errors.append_array(_validate_die(p.dice[key]).map(func(e: String) -> String: return "die %s: %s" % [key, e]))
	for key in p.get("engravings", {}):
		if not str(p.engravings[key].get("key", "")) in DeepDice.ENGRAVINGS:
			errors.append("engraving %s: unknown key %s" % [key, str(p.engravings[key].get("key", ""))])
	var starters: int = 0
	for key in p.characters:
		errors.append_array(_validate_character(p.characters[key], p).map(func(e: String) -> String: return "character %s: %s" % [key, e]))
		if p.characters[key] is Dictionary and bool(p.characters[key].get("starter", false)):
			starters += 1
	if starters != 1:
		errors.append("exactly one character is the starter")
	for key in p.creatures:
		errors.append_array(_validate_creature(p.creatures[key], p).map(func(e: String) -> String: return "creature %s: %s" % [key, e]))
	for key in p.mines:
		errors.append_array(_validate_mine(p.mines[key], p).map(func(e: String) -> String: return "mine %s: %s" % [key, e]))
	for key in p.get("oddities", {}):
		errors.append_array(DeepOddities.validate(p.oddities[key]).map(func(e: String) -> String: return "oddity %s: %s" % [key, e]))
	for key in p.get("boons", {}):
		errors.append_array(DeepBoons.validate(p.boons[key], p).map(func(e: String) -> String: return "boon %s: %s" % [key, e]))
	if p.has("boons"):
		for group in ["stone", "kit", "cost", "reward", "long_shot"]:
			if p.boons.values().filter(func(b: Variant) -> bool: return b is Dictionary and str(b.get("group", "")) == group).is_empty():
				errors.append("boons: no %s stake to offer" % group)
	return errors

static func _validate_die(def: Variant) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if not DeepDice.SHAPES.has(str(def.get("shape", ""))):
		errors.append("unknown shape " + str(def.get("shape", "")))
	var faces: Variant = def.get("faces", null)
	if not faces is Array or faces.is_empty():
		errors.append("needs a faces list")
	else:
		for f in faces:
			if f is Dictionary:
				if not str(f.get("kind", "plain")) in DeepDice.FACE_KINDS:
					errors.append("unknown face kind " + str(f.get("kind", "")))
				if int(f.get("value", 0)) < 0 or int(f.get("value", 0)) > DeepDice.VALUE_CAP:
					errors.append("face values run 0 to %d" % DeepDice.VALUE_CAP)
			elif not (f is int or f is float) or int(f) < 0 or int(f) > DeepDice.VALUE_CAP:
				errors.append("face values run 0 to %d" % DeepDice.VALUE_CAP)
	if def.has("engraving") and not str(def.engraving).is_empty() and not str(def.engraving) in DeepDice.ENGRAVINGS:
		errors.append("unknown engraving " + str(def.engraving))
	if def.has("top") and (not (def.top is int or def.top is float) or int(def.top) < 1 or int(def.top) > DeepDice.VALUE_CAP):
		errors.append("top runs 1 to %d" % DeepDice.VALUE_CAP)
	return errors

static func _validate_character(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	var sockets: Variant = def.get("sockets", null)
	if not sockets is Array or sockets.size() < 1:
		errors.append("needs at least one socket")
	else:
		var reds: int = 0
		for socket in sockets:
			var s: String = str(socket)
			if not (s in color_KEYS or s == SOCKET_ANY):
				errors.append("unknown socket color " + s)
			if s == "RED":
				reds += 1
		if reds == 0:
			errors.append("every character has at least one Red socket")
	if int(def.get("hp", 0)) <= 0:
		errors.append("needs hp")
	var dice: Variant = def.get("dice", null)
	if not dice is Array or dice.size() != 5:
		errors.append("needs exactly five starting dice")
	else:
		for key in dice:
			if not p.dice.has(str(key)):
				errors.append("unknown die " + str(key))
	var passive: Variant = def.get("passive", {"kind": "none"})
	if not passive is Dictionary or not str(passive.get("kind", "none")) in PASSIVE_KINDS:
		errors.append("unknown passive")
	errors.append_array(validate_birthstone(def.get("birthstone", null)).map(func(e: String) -> String: return "birthstone: " + e))
	return errors

static func validate_birthstone(def: Variant) -> Array:
	## A Birthstone is a name, a look, and a ladder of tiers, each a trigger and effects in
	## the rule language. Every satisfied tier fires unless one marked exclusive does. One
	## marked penalty costs its owner (High Roller's Bust), and the views light it as a loss.
	if not def is Dictionary:
		return ["every character needs a birthstone"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	if not str(def.get("style", "")) in BIRTHSTONE_STYLES:
		errors.append("unknown style " + str(def.get("style", "")))
	if not str(def.get("hue", "")).is_valid_html_color():
		errors.append("needs a hue")
	var tiers: Variant = def.get("tiers", null)
	if not tiers is Array or tiers.is_empty():
		errors.append("needs at least one tier")
		return errors
	for index in range(tiers.size()):
		var tier: Variant = tiers[index]
		var where: String = "tier %d" % (index + 1)
		if not tier is Dictionary:
			errors.append(where + ": must be an object")
			continue
		if str(tier.get("name", "")).is_empty():
			errors.append(where + ": needs a name")
		errors.append_array(DeepPatterns.validate(tier.get("trigger", null)).map(func(e: String) -> String: return where + ": " + e))
		var effects: Variant = tier.get("effects", null)
		if not effects is Array or effects.is_empty():
			errors.append(where + ": needs at least one effect")
		else:
			for e in range(effects.size()):
				errors.append_array(DeepRules.validate_effect(effects[e], "%s effect %d" % [where, e + 1]))
	return errors

static func _validate_creature(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if int(def.get("hp", 0)) <= 0:
		errors.append("needs hp")
	if int(def.get("threat", 0)) <= 0:
		errors.append("needs a threat cost")
	for key in def.get("dice", []):
		if not p.dice.has(str(key)):
			errors.append("unknown die " + str(key))
	if def.has("policy"):
		errors.append("enemy moves all fire when eligible; remove the old policy")
	if def.get("dice", []).is_empty() or def.get("dice", []).size() > 4:
		errors.append("needs one to four ordered dice")
	if not str(def.get("gimmick", "")) in GIMMICKS:
		errors.append("unknown gimmick " + str(def.get("gimmick", "")))
	var moves: Variant = def.get("moves", null)
	if not moves is Array or moves.is_empty():
		errors.append("needs at least one move")
	else:
		for index in range(moves.size()):
			errors.append_array(DeepRules.validate_move(moves[index], p).map(func(e: String) -> String: return "move %d: %s" % [index + 1, e]))
	for phase in def.get("phases", []):
		if not phase is Dictionary or not phase.get("moves", null) is Array:
			errors.append("each phase needs a moves list")
			continue
		for index in range(phase.moves.size()):
			errors.append_array(DeepRules.validate_move(phase.moves[index], p).map(func(e: String) -> String: return "phase move %d: %s" % [index + 1, e]))
	return errors

static func _validate_mine(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	for key in def.get("skills", []):
		if not p.skills.has(str(key)):
			errors.append("unknown skill " + str(key))
	for key in def.get("inclusions", []):
		if not p.inclusions.has(str(key)):
			errors.append("unknown inclusion " + str(key))
	for key in def.get("dice", []):
		if not p.dice.has(str(key)):
			errors.append("unknown die " + str(key))
	for key in def.get("wardens", []):
		if not p.creatures.has(str(key)):
			errors.append("unknown warden " + str(key))
		elif not bool(p.creatures[str(key)].get("warden", false)):
			errors.append("%s is not a warden" % str(key))
	if def.get("wardens", []).is_empty():
		errors.append("needs at least one warden")
	var bands: Variant = def.get("bands", null)
	if not bands is Array or bands.is_empty():
		errors.append("needs at least one creature band")
	else:
		for band in bands:
			if not band is Dictionary or not band.get("creatures", null) is Dictionary or band.creatures.is_empty():
				errors.append("each band needs creatures")
				continue
			for key in band.creatures:
				if not p.creatures.has(str(key)):
					errors.append("unknown creature " + str(key))
	for kind in def.get("chambers", {}):
		if not str(kind) in CHAMBER_KINDS:
			errors.append("unknown chamber kind " + str(kind))
	for key in def.get("unlocks", []):
		if not p.mines.has(str(key)):
			errors.append("unknown mine to unlock " + str(key))
	for color_key in def.get("color_weights", {}):
		if not str(color_key) in color_KEYS:
			errors.append("unknown color " + str(color_key))
	return errors
