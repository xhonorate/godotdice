class_name DeepProfile
extends RefCounted
## The player's own record: gold, the vault (one stone per skill), the bowl of dice, the
## settings they have unlocked and how each is loaded, and what they have done.
##
## Only stones and dice cross from a run into a profile, and only through the tray on the
## Appraise tab: every stone that comes home waits there until the player keeps it (into the
## vault, selling any stone of the same skill it replaces) or sells it.

const SCHEMA: int = 1

static func new_profile(name: String = "Lapidary") -> Dictionary:
	var profile: Dictionary = {"schema": SCHEMA, "id": "pf%08x" % randi(), "name": name, "gold": 0, "vault": {}, "seen": [],
		"bowl": [], "settings": {}, "current_setting": DeepContent.starter_setting(), "mines": {}, "tray": [],
		"records": {"runs": 0, "extractions": 0, "falls": 0, "conquests": 0, "stones_kept": 0, "best": {}}, "history": [], "next_id": 1}
	for key in DeepContent.section("settings"):
		var setting: Dictionary = DeepContent.setting(str(key))
		var unlocked: bool = bool(setting.get("starter", false))
		profile.settings[str(key)] = {"unlocked": unlocked, "rail": [], "dice": []}
		if unlocked:
			_fit_default(profile, str(key))
	for key in DeepContent.section("mines"):
		profile.mines[str(key)] = {"unlocked": bool(DeepContent.mine(str(key)).get("starter", false)), "deepest": 0, "wardens": [], "runs": 0}
	## Everyone starts with a Strike and a Guard, ordinary stones, so the first rail is never empty.
	keep(profile, DeepStone.make("STRIKE", 2, 1, 3, [], {"source": "starter"}, _id(profile, "st")))
	keep(profile, DeepStone.make("GUARD", 1, 1, 3, [], {"source": "starter"}, _id(profile, "st")))
	keep(profile, DeepStone.make("MEND", 1, 0, 3, [], {"source": "starter"}, _id(profile, "st")))
	var starter: Dictionary = profile.settings[str(profile.current_setting)]
	starter.rail = ["STRIKE", "GUARD", "MEND", null]
	while starter.rail.size() < DeepContent.setting(str(profile.current_setting)).sockets.size():
		starter.rail.append(null)
	return profile

static func _id(profile: Dictionary, prefix: String) -> String:
	profile.next_id = int(profile.get("next_id", 1)) + 1
	return "%s_%s%d" % [prefix, str(profile.get("id", "")).right(4), profile.next_id]

static func _fit_default(profile: Dictionary, setting_key: String) -> void:
	## A newly unlocked setting gets its own five dice added to the bowl and loaded.
	var setting: Dictionary = DeepContent.setting(setting_key)
	var record: Dictionary = profile.settings[setting_key]
	record.dice = []
	for die_key in setting.get("dice", []):
		var die: Dictionary = DeepDice.make(str(die_key), DeepContent.die(str(die_key)), _id(profile, "die"))
		profile.bowl.append(die)
		record.dice.append(str(die.id))
	if record.rail.is_empty():
		for _socket in setting.get("sockets", []):
			record.rail.append(null)

static func unlock_setting(profile: Dictionary, setting_key: String) -> bool:
	var record: Dictionary = profile.settings.get(setting_key, {})
	if record.is_empty() or bool(record.get("unlocked", false)):
		return false
	record.unlocked = true
	_fit_default(profile, setting_key)
	return true

# --- the vault -----------------------------------------------------------------------------

static func owned(profile: Dictionary, skill: String) -> Dictionary:
	return profile.vault.get(skill, {})

static func keep(profile: Dictionary, stone: Dictionary) -> Dictionary:
	## Puts a stone in the vault. Any stone of the same skill already there is sold.
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
	if not profile.seen.has(skill):
		profile.seen.append(skill)
	profile.records.stones_kept = int(profile.records.stones_kept) + 1
	var grade: Dictionary = DeepStone.grade(kept)
	if int(grade.score) > int(profile.records.best.get("score", -1)):
		profile.records.best = {"score": grade.score, "tier": grade.tier, "stone": kept.duplicate(true)}
	return {"replaced": replaced, "paid": paid}

static func sell(profile: Dictionary, stone: Dictionary) -> int:
	var paid: int = DeepStone.value(stone)
	profile.gold = int(profile.gold) + paid
	var skill: String = str(stone.get("skill", ""))
	if not profile.seen.has(skill):
		profile.seen.append(skill)
	return paid

static func vault_grid(profile: Dictionary) -> Array:
	## Every skill in the pack, in colour order, as unseen, seen or owned.
	var out: Array = []
	var keys: Array = DeepContent.section("skills").keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = DeepStone.COLOURS.find(str(DeepContent.skill(a).colour))
		var cb: int = DeepStone.COLOURS.find(str(DeepContent.skill(b).colour))
		return ca < cb if ca != cb else a < b)
	for key in keys:
		var state: String = "owned" if profile.vault.has(key) else ("seen" if profile.seen.has(key) else "unseen")
		out.append({"skill": key, "state": state, "stone": profile.vault.get(key, {})})
	return out

# --- loadouts ------------------------------------------------------------------------------

static func loadout(profile: Dictionary, setting_key: String) -> Dictionary:
	## The rail and dice a setting takes down the mine: stone instances from the vault and
	## die instances from the bowl. Missing dice fall back to the setting's defaults.
	var setting: Dictionary = DeepContent.setting(setting_key)
	var record: Dictionary = profile.settings.get(setting_key, {"rail": [], "dice": []})
	var rail: Array = []
	var sockets: Array = setting.get("sockets", [])
	for index in range(sockets.size()):
		var skill: Variant = record.rail[index] if index < record.rail.size() else null
		var stone: Dictionary = owned(profile, str(skill)) if skill is String else {}
		rail.append(stone.duplicate(true) if not stone.is_empty() and DeepStone.fits(stone, str(sockets[index])) else null)
	var dice: Array = []
	for die_id in record.get("dice", []):
		var die: Dictionary = bowl_die(profile, str(die_id))
		if not die.is_empty():
			dice.append(die.duplicate(true))
	var defaults: Array = setting.get("dice", [])
	var index: int = 0
	while dice.size() < 5 and index < defaults.size():
		dice.append(DeepDice.make(str(defaults[index]), DeepContent.die(str(defaults[index])), "fallback%d" % index))
		index += 1
	return {"rail": rail, "dice": dice.slice(0, 5)}

static func bowl_die(profile: Dictionary, die_id: String) -> Dictionary:
	for die in profile.bowl:
		if str(die.id) == die_id:
			return die
	return {}

static func set_rail(profile: Dictionary, setting_key: String, index: int, skill: Variant) -> String:
	## Puts an owned stone (by skill) in a socket, or clears it with null. Returns an error or "".
	var setting: Dictionary = DeepContent.setting(setting_key)
	var record: Dictionary = profile.settings.get(setting_key, {})
	if record.is_empty() or not bool(record.get("unlocked", false)):
		return "that setting is locked"
	var sockets: Array = setting.get("sockets", [])
	if index < 0 or index >= sockets.size():
		return "no such socket"
	while record.rail.size() < sockets.size():
		record.rail.append(null)
	if skill == null:
		record.rail[index] = null
		return ""
	var stone: Dictionary = owned(profile, str(skill))
	if stone.is_empty():
		return "you do not own that stone"
	if not DeepStone.fits(stone, str(sockets[index])):
		return "that socket takes a different colour"
	var cap: int = int(setting.get("carat_max", 0))
	if cap > 0 and int(stone.carat) > cap:
		return "this setting takes nothing heavier than %d carats" % cap
	for i in range(record.rail.size()):
		if i != index and record.rail[i] == str(skill):
			record.rail[i] = null
	record.rail[index] = str(skill)
	return ""

static func set_die(profile: Dictionary, setting_key: String, index: int, die_id: String) -> String:
	var record: Dictionary = profile.settings.get(setting_key, {})
	if record.is_empty():
		return "no such setting"
	if index < 0 or index >= 5:
		return "five dice"
	if bowl_die(profile, die_id).is_empty():
		return "that die is not in your bowl"
	while record.dice.size() < 5:
		record.dice.append("")
	for i in range(record.dice.size()):
		if i != index and str(record.dice[i]) == die_id:
			record.dice[i] = record.dice[index]
	record.dice[index] = die_id
	return ""

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
			for setting_key in DeepContent.section("settings"):
				if not bool(profile.settings[setting_key].get("unlocked", false)):
					if unlock_setting(profile, str(setting_key)):
						unlocked.append({"setting": str(setting_key)})
						break
	profile.mines[mine_key] = mine_record
	profile.records.runs = int(profile.records.runs) + 1
	match str(result.get("outcome", "")):
		"extracted": profile.records.extractions = int(profile.records.extractions) + 1
		"conquered":
			profile.records.conquests = int(profile.records.conquests) + 1
			profile.records.extractions = int(profile.records.extractions) + 1
		"fallen": profile.records.falls = int(profile.records.falls) + 1
	var mine_result: Dictionary = result.get("players", {}).get(player_id, {})
	var brought: Array = []
	for stone in mine_result.get("haul", []):
		var home: Dictionary = stone.duplicate(true)
		home.provenance.date = Time.get_date_string_from_system()
		profile.tray.append(home)
		brought.append(home)
	for die in mine_result.get("dice", []):
		profile.bowl.append(die.duplicate(true))
	profile.history.append({"run_id": str(result.get("run_id", "")), "mine": mine_key, "outcome": str(result.get("outcome", "")),
		"depth": int(result.get("depth", 0)), "stones": brought.size(), "date": Time.get_date_string_from_system()})
	return {"tray": brought, "unlocked": unlocked}

static func decide_tray(profile: Dictionary, stone_id: String, keep_it: bool) -> Dictionary:
	for index in range(profile.tray.size()):
		var stone: Dictionary = profile.tray[index]
		if str(stone.id) != stone_id:
			continue
		profile.tray.remove_at(index)
		if keep_it:
			var kept: Dictionary = keep(profile, stone)
			return {"ok": true, "kept": true, "replaced": kept.replaced, "paid": kept.paid}
		return {"ok": true, "kept": false, "paid": sell(profile, stone)}
	return {"ok": false, "error": "no such stone in the tray"}
