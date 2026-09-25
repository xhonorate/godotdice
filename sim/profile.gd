class_name DeepProfile
extends RefCounted
## The player's own record: gold, the vault (one stone per skill), the bowl of dice, the
## characters they have unlocked and how each is loaded, and what they have done.
##
## Only stones and dice cross from a run into a profile, and only through the tray on the
## Appraise tab: every stone that comes home waits there until the player keeps it (into the
## vault, selling any stone of the same skill it replaces) or sells it.

const SCHEMA: int = 2

static func new_profile(name: String = "Lapidary") -> Dictionary:
	var profile: Dictionary = {"schema": SCHEMA, "id": "pf%08x" % randi(), "name": name, "gold": 0, "vault": {}, "seen": [],
		"bowl": [], "characters": {}, "current_character": DeepContent.starter_character(), "mines": {}, "tray": [],
		"records": {"runs": 0, "extractions": 0, "falls": 0, "conquests": 0, "stones_kept": 0, "best": {}}, "history": [], "next_id": 1}
	for key in DeepContent.section("characters"):
		var character: Dictionary = DeepContent.character(str(key))
		var unlocked: bool = bool(character.get("starter", false))
		profile.characters[str(key)] = {"unlocked": unlocked, "rail": [], "dice": []}
		if unlocked:
			_fit_default(profile, str(key))
	for key in DeepContent.section("mines"):
		profile.mines[str(key)] = {"unlocked": bool(DeepContent.mine(str(key)).get("starter", false)), "deepest": 0, "wardens": [], "runs": 0}
	## Everyone starts with a Strike and a Guard, ordinary stones, so the first rail is never empty.
	keep(profile, DeepStone.make("STRIKE", 2, 1, 3, [], {"source": "starter"}, _id(profile, "st")))
	keep(profile, DeepStone.make("GUARD", 1, 1, 3, [], {"source": "starter"}, _id(profile, "st")))
	keep(profile, DeepStone.make("MEND", 1, 0, 3, [], {"source": "starter"}, _id(profile, "st")))
	var starter: Dictionary = profile.characters[str(profile.current_character)]
	starter.rail = []
	for socket in DeepContent.character(str(profile.current_character)).get("sockets", []):
		starter.rail.append(null)
	for skill in ["STRIKE", "GUARD", "MEND"]:
		for index in range(starter.rail.size()):
			if starter.rail[index] == null and set_rail(profile, str(profile.current_character), index, skill).is_empty():
				break
	return profile

static func migrate(profile: Dictionary) -> Dictionary:
	## An older profile wore settings. It keeps its vault, bowl and records, and its unlocks
	## carry over by count: the starter plus one character for every setting it had earned.
	if profile.has("characters") and not profile.has("settings"):
		return profile
	var earned: int = -1
	for key in profile.get("settings", {}):
		if bool(profile.settings[key].get("unlocked", false)):
			earned += 1
	profile.characters = {}
	for key in DeepContent.section("characters"):
		profile.characters[str(key)] = {"unlocked": bool(DeepContent.character(str(key)).get("starter", false)), "rail": [], "dice": []}
	profile.current_character = DeepContent.starter_character()
	_fit_default(profile, str(profile.current_character))
	for key in DeepContent.characters_in_unlock_order():
		if earned <= 0:
			break
		if unlock_character(profile, str(key)):
			earned -= 1
	var starter: Dictionary = profile.characters[str(profile.current_character)]
	for skill in profile.get("vault", {}).keys():
		for index in range(starter.rail.size()):
			if starter.rail[index] == null and set_rail(profile, str(profile.current_character), index, str(skill)).is_empty():
				break
	profile.erase("settings")
	profile.erase("current_setting")
	profile.schema = SCHEMA
	return profile

static func _id(profile: Dictionary, prefix: String) -> String:
	profile.next_id = int(profile.get("next_id", 1)) + 1
	return "%s_%s%d" % [prefix, str(profile.get("id", "")).right(4), profile.next_id]

static func _fit_default(profile: Dictionary, character_key: String) -> void:
	## A newly unlocked character brings their own five dice into the bowl, already loaded.
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters[character_key]
	record.dice = []
	for die_key in character.get("dice", []):
		var die: Dictionary = DeepDice.make(str(die_key), DeepContent.die(str(die_key)), _id(profile, "die"))
		profile.bowl.append(die)
		record.dice.append(str(die.id))
	if record.rail.is_empty():
		for _socket in character.get("sockets", []):
			record.rail.append(null)

static func unlock_character(profile: Dictionary, character_key: String) -> bool:
	var record: Dictionary = profile.characters.get(character_key, {})
	if record.is_empty() or bool(record.get("unlocked", false)):
		return false
	record.unlocked = true
	record.fresh = true
	_fit_default(profile, character_key)
	return true

static func next_locked_character(profile: Dictionary) -> String:
	## The next character a Warden would unlock, in the pack's unlock order.
	for key in DeepContent.characters_in_unlock_order():
		if not bool(profile.get("characters", {}).get(str(key), {}).get("unlocked", false)):
			return str(key)
	return ""

static func unlocked_characters(profile: Dictionary) -> Array:
	var out: Array = []
	for key in DeepContent.characters_in_unlock_order():
		if bool(profile.get("characters", {}).get(str(key), {}).get("unlocked", false)):
			out.append(str(key))
	return out

# --- the vault -----------------------------------------------------------------------------

static func owned(profile: Dictionary, skill: String) -> Dictionary:
	return profile.vault.get(skill, {})

static func keep(profile: Dictionary, stone: Dictionary) -> Dictionary:
	## Puts a stone in the vault. Any stone of the same skill already there is sold.
	if DeepStone.is_fragile(stone):
		shatter(profile, stone)
		return {"replaced": {}, "paid": 0, "shattered": true}
	var skill: String = str(stone.get("skill", ""))
	var replaced: Dictionary = owned(profile, skill)
	var paid: int = 0
	if not replaced.is_empty():
		paid = DeepStone.value(replaced)
		profile.gold = int(profile.gold) + paid
	var kept: Dictionary = stone.duplicate(true)
	kept.appraised = true
	kept.inclusions_revealed = true
	profile.vault[skill] = kept
	saw(profile, skill)
	profile.records.stones_kept = int(profile.records.stones_kept) + 1
	var grade: Dictionary = DeepStone.grade(kept)
	if int(grade.score) > int(profile.records.best.get("score", -1)):
		profile.records.best = {"score": grade.score, "tier": grade.tier, "stone": kept.duplicate(true)}
	return {"replaced": replaced, "paid": paid}

static func first_of_skill(profile: Dictionary, stone: Dictionary) -> bool:
	## Whether this is the first stone of its skill to come home: the vault has none of that
	## skill yet, so there is nothing to weigh it against and nothing to decide. It is kept,
	## and it is never offered to a buyer.
	if DeepStone.is_birthstone(stone) or DeepStone.is_fragile(stone) or str(stone.get("skill", "")).is_empty():
		return false
	## A stone nobody has read is nobody's first: its skill is not known yet, and forcing it
	## into the vault would be a free appraisal for anyone who asked to sell it rough.
	if not bool(stone.get("appraised", false)):
		return false
	return owned(profile, str(stone.get("skill", ""))).is_empty()

static func auto_keep(profile: Dictionary) -> Array:
	## Every known stone on the tray that is the first of its skill goes straight into the
	## vault. Returns what was kept, newest first in the order it was found.
	var kept: Array = []
	for stone in profile.get("tray", []).duplicate():
		if DeepStone.known_fragile(stone):
			shatter(profile, stone)
			continue
		if not bool(stone.get("appraised", false)) or not first_of_skill(profile, stone):
			continue
		decide_tray(profile, str(stone.get("id", "")), true)
		kept.append(stone)
	return kept

static func sell(profile: Dictionary, stone: Dictionary) -> int:
	## A buyer pays what a stone is worth once it is known, and only the size class when it
	## is not: selling a stone rough is the cheap way off the tray, and it teaches the vault
	## nothing, because nobody ever found out what was in it.
	if DeepStone.is_fragile(stone):
		shatter(profile, stone)
		return 0
	var known: bool = bool(stone.get("appraised", false))
	var paid: int = DeepStone.value(stone) if known else DeepStone.rough_value(stone)
	profile.gold = int(profile.gold) + paid
	if known:
		saw(profile, str(stone.get("skill", "")))
	return paid

static func saw(profile: Dictionary, skill: String) -> bool:
	## Writes a skill into the vault's record of what the player has laid eyes on. True the
	## first time. Being seen is not owning: the vault draws the emblem in grey and the page
	## says what it does, which is the whole of what a player who lost it keeps.
	if skill.is_empty() or not DeepContent.section("skills").has(skill):
		return false
	if not profile.has("seen"):
		profile.seen = []
	if profile.seen.has(skill):
		return false
	profile.seen.append(skill)
	return true

static func appraisal_fee(stone: Dictionary) -> int:
	## What the loupe costs at the workshop. Reading a stone is work, and the bigger it is
	## the longer it takes, so the fee rides the same size class a rough buyer pays on —
	## always well above what that buyer offers, which is what makes it a decision.
	return maxi(int(DeepContent.constant("appraise_gold_min", 12)),
		int(round(float(DeepStone.rough_value(stone)) * float(DeepContent.constant("appraise_gold_mult", 2.0)))))

static func appraise(profile: Dictionary, stone: Dictionary) -> bool:
	## Puts a tray stone under the loupe for gold. False if the purse is short.
	if bool(stone.get("appraised", false)):
		return false
	var fee: int = appraisal_fee(stone)
	if int(profile.get("gold", 0)) < fee:
		return false
	profile.gold = int(profile.gold) - fee
	stone.appraised = true
	stone.inclusions_revealed = true
	saw(profile, str(stone.get("skill", "")))
	if DeepStone.is_fragile(stone):
		shatter(profile, stone)
	return true

static func shatter(profile: Dictionary, stone: Dictionary) -> void:
	## Commit the loss before any animation: skipping or quitting cannot rescue the gem.
	stone.appraised = true
	stone.inclusions_revealed = true
	saw(profile, str(stone.get("skill", "")))
	for index in range(profile.get("tray", []).size() - 1, -1, -1):
		if str(profile.tray[index].get("id", "")) == str(stone.get("id", "")):
			profile.tray.remove_at(index)

static func _color_place(color: String) -> int:
	## Where a color sits in the vault. The six come in their own order; an opal is none of
	## them and goes last, where the rarest things belong, rather than first, which is where
	## a colour the list has never heard of would otherwise land.
	var found: int = DeepStone.colorS.find(color)
	return found if found >= 0 else DeepStone.colorS.size()

static func vault_grid(profile: Dictionary) -> Array:
	## Every skill in the pack, in color order, as unseen, seen or owned.
	var out: Array = []
	var keys: Array = DeepContent.section("skills").keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = _color_place(str(DeepContent.skill(a).color))
		var cb: int = _color_place(str(DeepContent.skill(b).color))
		return ca < cb if ca != cb else a < b)
	for key in keys:
		var state: String = "owned" if profile.vault.has(key) else ("seen" if profile.seen.has(key) else "unseen")
		out.append({"skill": key, "state": state, "stone": profile.vault.get(key, {})})
	return out

# --- loadouts ------------------------------------------------------------------------------

static func loadout(profile: Dictionary, character_key: String) -> Dictionary:
	## The rail and dice a character takes down the mine: stone instances from the vault in
	## the sockets a loadout fills (the rest go down empty, to be filled in the mine), and the
	## character's own five dice, which are never swapped.
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters.get(character_key, {"rail": [], "dice": []})
	var rail: Array = []
	var sockets: Array = character.get("sockets", [])
	for index in range(sockets.size()):
		var skill: Variant = record.rail[index] if loadout_socket(index) and index < record.rail.size() else null
		var stone: Dictionary = owned(profile, str(skill)) if skill is String else {}
		rail.append(stone.duplicate(true) if not stone.is_empty() and DeepStone.fits(stone, str(sockets[index])) else null)
	## The dice they were unlocked with, in the bowl; a save from when dice could be swapped
	## gets a fresh one of the right kind wherever another die took a slot.
	var dice: Array = []
	var own: Array = record.get("dice", [])
	var defaults: Array = character.get("dice", [])
	for index in range(mini(defaults.size(), 5)):
		var die: Dictionary = bowl_die(profile, str(own[index])) if index < own.size() else {}
		if die.is_empty() or str(die.get("key", "")) != str(defaults[index]):
			die = DeepDice.make(str(defaults[index]), DeepContent.die(str(defaults[index])), "fallback%d" % index)
		dice.append(die.duplicate(true))
	return {"rail": rail, "dice": dice}

static func bowl_die(profile: Dictionary, die_id: String) -> Dictionary:
	for die in profile.bowl:
		if str(die.id) == die_id:
			return die
	return {}

static func starting_rail_cap() -> int:
	## How many sockets a loadout fills: the first few on the rail.
	return int(DeepContent.constant("starting_rail_cap", 3))

static func loadout_socket(index: int) -> bool:
	## Whether a socket is filled from the vault before a run. The rest of the rail is only
	## ever filled in the mine, with stones found on the way down.
	return index >= 0 and index < starting_rail_cap()

static func rail_refusal(profile: Dictionary, character_key: String, index: int, skill: String) -> String:
	## Why an owned stone (by skill) cannot go into a socket of a loadout, or "".
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters.get(character_key, {})
	if record.is_empty() or not bool(record.get("unlocked", false)):
		return "that character is locked"
	var sockets: Array = character.get("sockets", [])
	if index < 0 or index >= sockets.size():
		return "no such socket"
	if not loadout_socket(index):
		return "that socket is only filled in the mine"
	var stone: Dictionary = owned(profile, skill)
	if stone.is_empty():
		return "you do not own that stone"
	if not DeepStone.fits(stone, str(sockets[index])):
		return "that socket takes a different color"
	var cap: int = int(character.get("carat_max", 0))
	if cap > 0 and int(stone.carat) > cap:
		return "%s takes nothing heavier than %d carats" % [str(character.get("name", "this character")), cap]
	return ""

static func set_rail(profile: Dictionary, character_key: String, index: int, skill: Variant) -> String:
	## Puts an owned stone (by skill) in a socket of the loadout, or clears it with null.
	## Returns an error or "". A stone already set elsewhere on the rail moves, and the stone
	## it lands on takes its old socket if it fits there, or comes out.
	var record: Dictionary = profile.characters.get(character_key, {})
	var sockets: Array = DeepContent.character(character_key).get("sockets", [])
	if skill == null:
		if record.is_empty() or not bool(record.get("unlocked", false)):
			return "that character is locked"
		if index < 0 or index >= sockets.size():
			return "no such socket"
		while record.rail.size() < sockets.size():
			record.rail.append(null)
		record.rail[index] = null
		return ""
	var refusal: String = rail_refusal(profile, character_key, index, str(skill))
	if not refusal.is_empty():
		return refusal
	while record.rail.size() < sockets.size():
		record.rail.append(null)
	var from: int = record.rail.find(str(skill))
	var displaced: Variant = record.rail[index]
	for i in range(record.rail.size()):
		if i != index and record.rail[i] == str(skill):
			record.rail[i] = null
	record.rail[index] = str(skill)
	if from >= 0 and from != index and displaced is String and rail_refusal(profile, character_key, from, str(displaced)).is_empty():
		record.rail[from] = displaced
	return ""

static func tidy(profile: Dictionary) -> bool:
	## A save from when any socket could be filled before a run: a stone sitting in a socket
	## the loadout no longer fills moves to an empty one it fits, or comes out. True if
	## anything moved.
	var moved: bool = false
	for key in profile.get("characters", {}):
		var record: Dictionary = profile.characters[key]
		var rail: Array = record.get("rail", [])
		for index in range(rail.size()):
			if loadout_socket(index) or rail[index] == null:
				continue
			var skill: String = str(rail[index])
			rail[index] = null
			moved = true
			for slot in range(starting_rail_cap()):
				if slot < rail.size() and rail[slot] == null and set_rail(profile, str(key), slot, skill).is_empty():
					break
	return moved

# --- what comes home -----------------------------------------------------------------------

static func apply_result(profile: Dictionary, result: Dictionary, player_id: String) -> Dictionary:
	## Hauls go to the tray, dice to the bowl, records are written, unlocks granted.
	var mine_key: String = str(result.get("mine", ""))
	var mine_record: Dictionary = profile.mines.get(mine_key, {"unlocked": true, "deepest": 0, "wardens": [], "runs": 0})
	mine_record.runs = int(mine_record.get("runs", 0)) + 1
	mine_record.deepest = maxi(int(mine_record.get("deepest", 0)), int(result.get("deepest", 0)))
	var unlocked: Array = []
	for depth in result.get("wardens", []):
		if not mine_record.wardens.has(int(depth)):
			mine_record.wardens.append(int(depth))
			for next_mine in DeepContent.mine(mine_key).get("unlocks", []):
				var record: Dictionary = profile.mines.get(str(next_mine), {})
				if not record.is_empty() and not bool(record.get("unlocked", false)):
					record.unlocked = true
					unlocked.append({"mine": str(next_mine)})
			var next_character: String = next_locked_character(profile)
			if not next_character.is_empty() and unlock_character(profile, next_character):
				unlocked.append({"character": next_character})
	profile.mines[mine_key] = mine_record
	profile.records.runs = int(profile.records.runs) + 1
	match str(result.get("outcome", "")):
		"extracted": profile.records.extractions = int(profile.records.extractions) + 1
		"conquered":
			profile.records.conquests = int(profile.records.conquests) + 1
			profile.records.extractions = int(profile.records.extractions) + 1
		"fallen": profile.records.falls = int(profile.records.falls) + 1
	var mine_result: Dictionary = result.get("players", {}).get(player_id, {})
	## What the run taught, whatever came of the stones themselves: a gem read under a lens
	## down there is in the vault's record even if the party never came back up with it.
	for skill in mine_result.get("seen", []):
		saw(profile, str(skill))
	var brought: Array = []
	var shattered: Array = mine_result.get("shattered", []).duplicate(true)
	for stone in mine_result.get("haul", []):
		if DeepStone.known_fragile(stone):
			shattered.append(stone.duplicate(true))
			if bool(stone.get("appraised", false)):
				saw(profile, str(stone.get("skill", "")))
			continue
		var home: Dictionary = stone.duplicate(true)
		home.provenance.date = Time.get_date_string_from_system()
		profile.tray.append(home)
		brought.append(home)
	for die in mine_result.get("dice", []):
		profile.bowl.append(die.duplicate(true))
	profile.history.append({"run_id": str(result.get("run_id", "")), "mine": mine_key, "outcome": str(result.get("outcome", "")),
		"depth": int(result.get("depth", 0)), "stones": brought.size(), "date": Time.get_date_string_from_system()})
	## Anything that came home already read and is the first of its skill is kept without
	## being asked about. What came home raw is kept the moment the loupe says what it is.
	var claimed: Array = auto_keep(profile)
	return {"tray": brought, "unlocked": unlocked, "kept": claimed, "shattered": shattered}

static func decide_tray(profile: Dictionary, stone_id: String, keep_it: bool) -> Dictionary:
	for index in range(profile.tray.size()):
		var stone: Dictionary = profile.tray[index]
		if str(stone.id) != stone_id:
			continue
		if DeepStone.is_fragile(stone):
			shatter(profile, stone)
			return {"ok": true, "kept": false, "paid": 0, "shattered": true}
		var forced: bool = first_of_skill(profile, stone)
		profile.tray.remove_at(index)
		if keep_it or forced:
			var kept: Dictionary = keep(profile, stone)
			return {"ok": true, "kept": true, "replaced": kept.replaced, "paid": kept.paid, "forced": forced}
		return {"ok": true, "kept": false, "paid": sell(profile, stone)}
	return {"ok": false, "error": "no such stone in the tray"}
