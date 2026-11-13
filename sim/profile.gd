class_name DeepProfile
extends RefCounted
## The player's own record: gold, the vault (one stone per skill), the bowl of dice, the
## characters they have unlocked, how each is loaded and how many sockets they have opened,
## the day's commissions, the creatures they have met (DeepBestiary), and what they have done.
##
## Only stones, dice and gold cross from a run into a profile. Stones come only through the
## tray on the Appraise tab: every stone that comes home waits there until the player keeps it
## (into the vault, in place of any stone of the same skill, which is let go for nothing),
## sells it, or turns it in for a commission (DeepEconomy). A run pays gold only as the purse
## for a mine's first conquest and the daily dig's score: pyrite never comes up.

const SCHEMA: int = 3
const DEFAULT_NAME: String = "Player"
const NAME_LIMIT: int = 24
## How many of the latest runs keep their whole tally (and their party's) in the history.
## Older ones keep the line the ledger shows; the save is written often and a tally is long.
const HISTORY_STATS_KEPT: int = 10
## The stones every profile starts with, one of each starter color: skill, carat, cut, clarity.
## A starter color the vault runs out of is given back as a 1 carat spare (`spare_starters`).
const STARTERS: Array = [["STRIKE", 2, 1, 3], ["GUARD", 1, 1, 3], ["MEND", 1, 0, 3]]

static func seat_names(names: Array) -> Array:
	## The names a party goes by, in seat order. Everyone keeps their own, but two who share
	## one (two new players are both "Player") are told apart by their seat: "Player 1" and
	## "Player 2". Every warning, tab and table that names a member reads it from here.
	var counts: Dictionary = {}
	for name in names:
		var key: String = str(name).strip_edges().to_lower()
		counts[key] = int(counts.get(key, 0)) + 1
	var out: Array = []
	for seat in range(names.size()):
		var name: String = str(names[seat])
		out.append("%s %d" % [name, seat + 1] if int(counts[name.strip_edges().to_lower()]) > 1 else name)
	return out

static func new_profile(name: String = DEFAULT_NAME) -> Dictionary:
	var profile: Dictionary = {"schema": SCHEMA, "id": "pf%08x" % randi(), "name": name, "gold": 0, "vault": {}, "seen": [],
		"bowl": [], "characters": {}, "current_character": DeepContent.starter_character(), "mines": {}, "tray": [],
		"records": {"runs": 0, "extractions": 0, "falls": 0, "conquests": 0, "stones_kept": 0, "commissions": 0, "best": {}}, "history": [], "next_id": 1,
		"daily": {}, "weekly": {}, "favorites": [], "outfit": {"insure": false}, "conquest_paid": [], "warden_paid": [], "charged_run": "", "bestiary": {}}
	for key in DeepContent.section("characters"):
		var character: Dictionary = DeepContent.character(str(key))
		var unlocked: bool = bool(character.get("starter", false))
		profile.characters[str(key)] = {"unlocked": unlocked, "rail": [], "dice": [], "sockets": starting_rail_cap()}
		if unlocked:
			_fit_default(profile, str(key))
	ensure_mines(profile)
	## Everyone starts with a Strike and a Guard, ordinary stones, so the first rail is never empty.
	for starter in STARTERS:
		keep(profile, DeepStone.make(str(starter[0]), int(starter[1]), int(starter[2]), int(starter[3]), [], {"source": "starter"}, _id(profile, "st")))
	var starter: Dictionary = profile.characters[str(profile.current_character)]
	starter.rail = []
	for socket in DeepContent.character(str(profile.current_character)).get("sockets", []):
		starter.rail.append(null)
	for skill in ["STRIKE", "GUARD", "MEND"]:
		for index in range(starter.rail.size()):
			if starter.rail[index] == null and set_rail(profile, str(profile.current_character), index, skill).is_empty():
				break
	## The starting stones were there from the first day: nothing in the vault is new yet.
	unfresh(profile)
	return profile

static func upgrade(profile: Dictionary) -> bool:
	## A profile from before gold had uses at home (schema 2) gains what it is missing: the
	## day's commissions, the outfit it last went down in, the mines whose first-conquest purse
	## is paid (a mine already conquered counts as paid: that purse belongs to a first), and
	## three open sockets for every lapidary. True if anything was added.
	var changed: bool = false
	## The stars in the vault were once a "wanted" list; they are favorites now.
	if profile.has("wanted"):
		if not profile.has("favorites"):
			profile.favorites = profile.wanted
		profile.erase("wanted")
		changed = true
	for field in [["daily", {}], ["weekly", {}], ["favorites", []], ["outfit", {"insure": false}], ["conquest_paid", []], ["charged_run", ""], ["bestiary", {}]]:
		if not profile.has(field[0]):
			profile[field[0]] = field[1].duplicate() if field[1] is Dictionary or field[1] is Array else field[1]
			changed = true
	if int(profile.get("schema", 0)) < SCHEMA:
		for key in profile.get("mines", {}):
			if bool(profile.mines[key].get("boss", false)) and not profile.conquest_paid.has(str(key)):
				profile.conquest_paid.append(str(key))
		profile.schema = SCHEMA
		changed = true
	## Wardens have paid a purse of their own since October 2026. One beaten before then counts
	## as paid, as a mine conquered before the conquest purse did: the purse is for a first.
	if not profile.get("warden_paid", null) is Array:
		profile.warden_paid = []
		for key in profile.get("mines", {}):
			for depth in profile.mines[key].get("wardens", []):
				var index: int = DeepEconomy.warden_index(str(key), int(depth))
				if index >= 0 and not profile.warden_paid.has(warden_mark(str(key), index)):
					profile.warden_paid.append(warden_mark(str(key), index))
		changed = true
	if profile.has("records") and not profile.records.has("commissions"):
		profile.records.commissions = 0
		changed = true
	## A lapidary joins when the boss above their mine falls (until October 2026 they waited
	## at their own mine's first Warden), so a boss beaten under the old rule brings them now.
	if profile.has("characters") and profile.has("bowl"):
		for key in profile.get("mines", {}):
			if bool(profile.mines[key].get("boss", false)) and unlock_character(profile, str(DeepContent.mine(str(DeepContent.mine(str(key)).get("next", ""))).get("lapidary", ""))):
				changed = true
	for key in profile.get("characters", {}):
		if not profile.characters[key].has("sockets"):
			profile.characters[key].sockets = starting_rail_cap()
			changed = true
	## The Hazard ladder came after some had already reached the Rift: they start on tier 1.
	if hazard_top(profile) == 0 and reached_rift(profile.get("mines", {})):
		_ensure_hazard(profile)
		profile.hazard.top = 1
		changed = true
	if forget_removed(profile):
		changed = true
	return changed

static func forget_removed(profile: Dictionary) -> bool:
	## A skill taken out of the pack (Windfall, September 2026) leaves nothing behind: its
	## stone goes from the vault and the tray, and its name from the record of what was seen,
	## the stars, the Transcendents made and every loadout. True if anything went.
	var skills: Dictionary = DeepContent.section("skills")
	var gone := func(skill: Variant) -> bool: return skill is String and not str(skill).is_empty() and not skills.has(str(skill))
	var changed: bool = false
	var vault: Variant = profile.get("vault", {})
	if vault is Dictionary:
		for key in vault.keys():
			if gone.call(str(key)) or (vault[key] is Dictionary and gone.call(vault[key].get("skill", ""))):
				lose(profile, str(key))
				changed = true
	var tray: Variant = profile.get("tray", [])
	if tray is Array:
		## An older save's raw stone may still hide a Void, which never forms at home any more.
		for stone in tray:
			if stone is Dictionary and not bool(stone.get("appraised", false)) and not DeepForge.unvoid(stone).is_empty():
				changed = true
		var kept: Array = tray.filter(func(s: Variant) -> bool: return not (s is Dictionary and gone.call(s.get("skill", ""))))
		if kept.size() != tray.size():
			profile.tray = kept
			changed = true
	for field in ["seen", "favorites", "transcended"]:
		var names: Variant = profile.get(field, [])
		if names is Array and names.any(gone):
			profile[field] = names.filter(func(s: Variant) -> bool: return not gone.call(s))
			changed = true
	for key in profile.get("characters", {}):
		var rail: Array = profile.characters[key].get("rail", [])
		for index in range(rail.size()):
			if gone.call(rail[index]):
				rail[index] = null
				changed = true
	## The best stone on record is weighed again from what is left.
	var best: Variant = profile.get("records", {}).get("best", {})
	if best is Dictionary and best.get("stone", null) is Dictionary and gone.call(best.stone.get("skill", "")):
		profile.records.best = {}
		for key in profile.get("vault", {}):
			regrade(profile, profile.vault[key])
		changed = true
	return changed

static func new_mine_record(key: String) -> Dictionary:
	return {"unlocked": bool(DeepContent.mine(key).get("starter", false)), "deepest": 0, "wardens": [], "boss": false, "runs": 0}

static func ensure_mines(profile: Dictionary) -> void:
	## Every mine in the pack has a record, sealed unless it is the starter. A profile from
	## when the Quarry ran to depth 24 and the third Warden there was its last has beaten the
	## Quarry if it ever killed that Warden, and the mine below is open to it.
	if not profile.has("mines"):
		profile.mines = {}
	var fresh: bool = not bool(profile.get("mines_v2", false))
	for key in DeepContent.mines_in_order():
		if not profile.mines.has(str(key)):
			profile.mines[str(key)] = new_mine_record(str(key))
		var record: Dictionary = profile.mines[str(key)]
		if not record.has("boss"):
			record.boss = false
		if fresh and not record.wardens.is_empty() and record.wardens.map(func(d: Variant) -> int: return int(d)).max() >= 24:
			record.boss = true
		if bool(record.boss):
			_open_next(profile, str(key))
	profile.mines_v2 = true

static func _open_next(profile: Dictionary, mine_key: String) -> String:
	## Unseals the mine below this one. Returns its key if it was sealed until now.
	return _open_next_in(profile.mines, mine_key)

static func _open_next_in(records: Dictionary, mine_key: String) -> String:
	## The same, in one tier's records.
	var next_key: String = str(DeepContent.mine(mine_key).get("next", ""))
	if next_key.is_empty():
		return ""
	if not records.has(next_key):
		records[next_key] = new_mine_record(next_key)
	if bool(records[next_key].get("unlocked", false)):
		return ""
	records[next_key].unlocked = true
	return next_key

static func unlocked_mines(profile: Dictionary) -> Array:
	return DeepContent.mines_in_order().filter(func(k: Variant) -> bool: return bool(profile.get("mines", {}).get(str(k), {}).get("unlocked", false)))

# --- the Hazard ladder (docs/HAZARDS.md) ---------------------------------------------------

static func hazard_top(profile: Dictionary) -> int:
	## The highest Hazard tier this lapidary may go down on: 0 until the Rift is reached, then
	## one more each time the Rift is reached on the highest.
	var record: Variant = profile.get("hazard", {})
	return clampi(int(record.get("top", 0)), 0, DeepContent.hazard_max()) if record is Dictionary else 0

static func _ensure_hazard(profile: Dictionary) -> void:
	if not profile.get("hazard", null) is Dictionary:
		profile.hazard = {"top": 0, "tiers": {}}
	if not profile.hazard.get("tiers", null) is Dictionary:
		profile.hazard.tiers = {}

static func mine_records(profile: Dictionary, tier: int) -> Dictionary:
	## The mines' records on a tier. Tier 0 is the profile's own map. Every tier above it is a
	## ladder of its own: only the starter mine is open until its boss falls on that tier.
	if tier <= 0:
		if not profile.has("mines"):
			profile.mines = {}
		return profile.mines
	_ensure_hazard(profile)
	var key: String = str(tier)
	if not profile.hazard.tiers.get(key, null) is Dictionary:
		var mines: Dictionary = {}
		for mine_key in DeepContent.mines_in_order():
			mines[str(mine_key)] = new_mine_record(str(mine_key))
		profile.hazard.tiers[key] = {"mines": mines}
	return profile.hazard.tiers[key].mines

static func open_mines(profile: Dictionary, tier: int) -> Array:
	## The mines a run on this tier may start in.
	var records: Dictionary = mine_records(profile, tier)
	return DeepContent.mines_in_order().filter(func(k: Variant) -> bool: return bool(records.get(str(k), {}).get("unlocked", false)))

static func reached_rift(records: Dictionary) -> bool:
	## Whether these records have the mine with no bottom open.
	for key in DeepContent.mines_in_order():
		if DeepContent.is_endless(str(key)) and bool(records.get(str(key), {}).get("unlocked", false)):
			return true
	return false

static func _raise_hazard(profile: Dictionary, tier: int) -> int:
	## Reaching the Rift on the highest tier opens the next one. Returns the tier opened, or 0.
	_ensure_hazard(profile)
	if tier < hazard_top(profile) or tier >= DeepContent.hazard_max():
		return 0
	profile.hazard.top = tier + 1
	return tier + 1

static func migrate(profile: Dictionary) -> Dictionary:
	## An older profile wore settings. It keeps its vault, bowl and records, and its unlocks
	## carry over by count: the starter plus one character for every setting it had earned.
	ensure_mines(profile)
	if profile.has("characters") and not profile.has("settings"):
		_renew_dice(profile)
		return profile
	var earned: int = -1
	for key in profile.get("settings", {}):
		if bool(profile.settings[key].get("unlocked", false)):
			earned += 1
	profile.characters = {}
	for key in DeepContent.section("characters"):
		profile.characters[str(key)] = {"unlocked": bool(DeepContent.character(str(key)).get("starter", false)), "rail": [], "dice": [], "sockets": starting_rail_cap()}
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
	_renew_dice(profile)
	return profile

static func _renew_dice(profile: Dictionary) -> void:
	## Dice from before a die carried its own pattern were written down by a stock "key"
	## (GAMBLERS_D6, PHIAL) with the faces of that day and no pattern: a Gambler's d6 that
	## was not Gambler's at all, and a Phial that rolled to the wrong ceiling. Each is made
	## again as the character it belongs to would bring it now, keeping its id. The same old
	## saves handed some ids out twice; every die after the first to carry one gets its own.
	var refs: Dictionary = {}
	for key in profile.get("characters", {}):
		var own: Array = profile.characters[key].get("dice", [])
		var defaults: Array = DeepContent.character(str(key)).get("dice", [])
		for index in range(mini(own.size(), defaults.size())):
			refs[str(own[index])] = defaults[index]
	var seen: Dictionary = {}
	for index in range(profile.get("bowl", []).size()):
		var die: Dictionary = profile.bowl[index]
		if die.has("key"):
			var made: Dictionary = DeepForge.die_from(refs.get(str(die.get("id", "")), str(die.get("shape", "D6"))), str(die.get("id", "")))
			if str(made.shape) != str(die.get("shape", "")):
				made = DeepForge.die_from(str(die.get("shape", "D6")), str(die.get("id", "")))
			profile.bowl[index] = made
			die = made
		if seen.has(str(die.id)):
			die.id = _id(profile, "die")
		seen[str(die.id)] = true

static func _id(profile: Dictionary, prefix: String) -> String:
	profile.next_id = int(profile.get("next_id", 1)) + 1
	return "%s_%s%d" % [prefix, str(profile.get("id", "")).right(4), profile.next_id]

static func _fit_default(profile: Dictionary, character_key: String) -> void:
	## A newly unlocked character brings their own five dice into the bowl, already loaded.
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters[character_key]
	record.dice = []
	for die_ref in character.get("dice", []):
		var die: Dictionary = DeepForge.die_from(die_ref, _id(profile, "die"))
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
	fit_from_vault(profile, character_key)
	return true

static func fit_from_vault(profile: Dictionary, character_key: String) -> int:
	## A delver who joins sets their open sockets from the vault, as the first delver's were
	## set, so nobody new goes down with a rail that does nothing. Every rail draws on the same
	## vault, so no other delver loses a stone. The colored sockets first, then the Rainbow
	## ones, so a Rainbow socket never takes the one stone a colored socket could hold. In each, a
	## starter (Strike, Guard, Mend) where it fits, else the vault's best stone that fits.
	## Returns how many sockets were filled.
	var record: Dictionary = profile.get("characters", {}).get(character_key, {})
	if record.is_empty() or not bool(record.get("unlocked", false)):
		return 0
	var sockets: Array = DeepContent.character(character_key).get("sockets", [])
	var stones: Array = profile.get("vault", {}).values().filter(func(s: Variant) -> bool: return s is Dictionary and not DeepStone.is_birthstone(s))
	stones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(DeepStone.grade(a).score) > int(DeepStone.grade(b).score))
	var order: Array = STARTERS.map(func(s: Array) -> String: return str(s[0])) + stones.map(func(s: Dictionary) -> String: return str(s.get("skill", "")))
	var filled: int = 0
	for any_pass in [false, true]:
		for index in range(open_sockets(profile, character_key)):
			if index >= sockets.size() or DeepContent.is_rainbow(str(sockets[index])) != any_pass:
				continue
			if index < record.rail.size() and record.rail[index] != null:
				continue
			for skill in order:
				if not record.rail.has(skill) and not owned(profile, str(skill)).is_empty() and set_rail(profile, character_key, index, str(skill)).is_empty():
					filled += 1
					break
	return filled

static func next_locked_character(profile: Dictionary) -> String:
	## The next character still to be met, in the pack's unlock order.
	for key in DeepContent.characters_in_unlock_order():
		if not bool(profile.get("characters", {}).get(str(key), {}).get("unlocked", false)):
			return str(key)
	return ""

static func lapidary_mine(character_key: String) -> String:
	## The mine a lapidary belongs to, the one under the boss whose fall brings them; "" for
	## the starter.
	for key in DeepContent.mines_in_order():
		if str(DeepContent.mine(str(key)).get("lapidary", "")) == character_key:
			return str(key)
	return ""

static func lapidary_boss_mine(character_key: String) -> String:
	## The mine whose final boss brings this lapidary: the one above the mine they belong to.
	var home: String = lapidary_mine(character_key)
	for key in DeepContent.mines_in_order():
		if not home.is_empty() and str(DeepContent.mine(str(key)).get("next", "")) == home:
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
	## Puts a stone in the vault. Any stone of the same skill already there is let go, and
	## pays nothing: only a stone sold instead of kept is paid for.
	if DeepStone.is_fragile(stone):
		shatter(profile, stone)
		return {"replaced": {}, "shattered": true}
	var skill: String = str(stone.get("skill", ""))
	var replaced: Dictionary = owned(profile, skill)
	var kept: Dictionary = stone.duplicate(true)
	kept.appraised = true
	kept.inclusions_revealed = true
	## New in the vault until the player has looked at it (see `unfresh`).
	kept.fresh = true
	profile.vault[skill] = kept
	saw(profile, skill)
	profile.records.stones_kept = int(profile.records.stones_kept) + 1
	regrade(profile, kept)
	return {"replaced": replaced}

static func regrade(profile: Dictionary, stone: Dictionary) -> void:
	## A kept stone's grade is weighed against the best on record, after it is kept or reworked.
	var grade: Dictionary = DeepStone.grade(stone)
	if not profile.has("records"):
		return
	if int(grade.score) > int(profile.records.get("best", {}).get("score", -1)):
		profile.records.best = {"score": grade.score, "tier": grade.tier, "stone": stone.duplicate(true)}

static func lose(profile: Dictionary, skill: String) -> Dictionary:
	## A vault stone gone for good (broken on the Wheel, given up for a contract or a
	## commission): out of the vault and out of every loadout that set it. Its skill stays seen.
	var gone: Dictionary = profile.get("vault", {}).get(skill, {})
	profile.get("vault", {}).erase(skill)
	for key in profile.get("characters", {}):
		var rail: Array = profile.characters[key].get("rail", [])
		for i in range(rail.size()):
			if rail[i] is String and str(rail[i]) == skill:
				rail[i] = null
	return gone

static func fresh_count(profile: Dictionary) -> int:
	## Stones kept since the player last looked at them in the vault.
	var count: int = 0
	for key in profile.get("vault", {}):
		if bool(profile.vault[key].get("fresh", false)):
			count += 1
	return count

static func unfresh(profile: Dictionary, skill: String = "") -> bool:
	## The player has seen one stone (or, with no skill, every stone): it is no longer new.
	var changed: bool = false
	for key in profile.get("vault", {}):
		if (skill.is_empty() or str(key) == skill) and bool(profile.vault[key].get("fresh", false)):
			profile.vault[key].erase("fresh")
			changed = true
	return changed

static func showcase(profile: Dictionary, count: int = 5) -> Array:
	## The player's kept stones as they show them: the ones starred in the vault first, then the
	## rest, each highest grade first. What the profile page and the party see. Birthstones are
	## not kept, so never shown.
	var stones: Array = profile.get("vault", {}).values().filter(func(s: Variant) -> bool: return s is Dictionary and not DeepStone.is_birthstone(s))
	var starred: Array = favorites(profile)
	stones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: bool = starred.has(str(a.get("skill", "")))
		var sb: bool = starred.has(str(b.get("skill", "")))
		if sa != sb:
			return sa
		var ga: int = int(DeepStone.grade(a).score)
		var gb: int = int(DeepStone.grade(b).score)
		return ga > gb if ga != gb else str(a.get("skill", "")) < str(b.get("skill", "")))
	return stones.slice(0, count)

static func favorites(profile: Dictionary) -> Array:
	## The skills the player has starred in the vault: their tiles carry the star, and the
	## Market marks whatever could be one.
	var found: Variant = profile.get("favorites", [])
	return found if found is Array else []

static func toggle_favorite(profile: Dictionary, skill: String) -> bool:
	## Stars a skill, or takes its star off. True if it is a favorite now.
	if not DeepContent.section("skills").has(skill):
		return false
	if not profile.get("favorites", null) is Array:
		profile.favorites = []
	if profile.favorites.has(skill):
		profile.favorites.erase(skill)
		return false
	profile.favorites.append(skill)
	return true

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

static func clear_shattered(profile: Dictionary) -> Array:
	## Every stone on the tray already known to be fragile breaks: none of them can be kept
	## or sold. Returns what broke. (A first stone of its skill is no longer kept without
	## asking: it waits on the tray to be kept, or turned in for a commission.)
	var broke: Array = []
	for stone in profile.get("tray", []).duplicate():
		if DeepStone.known_fragile(stone):
			shatter(profile, stone)
			broke.append(stone)
	return broke

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
	## Puts a tray stone under the loupe for gold (a Geode is cracked open for the same fee).
	## False if the purse is short.
	if bool(stone.get("appraised", false)):
		return false
	var fee: int = appraisal_fee(stone)
	if int(profile.get("gold", 0)) < fee:
		return false
	profile.gold = int(profile.gold) - fee
	## Void only forms down the mine: read at home, it has grown into something else.
	DeepForge.unvoid(stone)
	stone.appraised = true
	stone.inclusions_revealed = true
	## Cracking a Geode brought up from a mine: the rock comes away and the stone inside is an
	## ordinary one from here on. The caller keeps the recipe if it wants to show the crack.
	if DeepStone.is_geode(stone):
		stone.erase("geode")
		if profile.has("records"):
			profile.records.geodes = int(profile.records.get("geodes", 0)) + 1
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
	## a color the list has never heard of would otherwise land.
	var found: int = DeepStone.colorS.find(color)
	return found if found >= 0 else DeepStone.colorS.size()

static func made_transcendent(profile: Dictionary, skill: String) -> bool:
	## Writes down that this player has made a Transcendent. Until then the game does not
	## admit it exists: no Vault slot, no count, no page. True the first time.
	if not DeepContent.is_transcendent(skill):
		return false
	if not profile.has("transcended"):
		profile.transcended = []
	saw(profile, skill)
	if profile.transcended.has(skill):
		return false
	profile.transcended.append(skill)
	return true

static func knows(profile: Dictionary, skill: String) -> bool:
	## Whether the game may show this skill to this player at all. Everything but a
	## Transcendent, and a Transcendent once they have made one or hold it.
	if not DeepContent.is_transcendent(skill):
		return true
	return profile.get("transcended", []).has(skill) or profile.get("vault", {}).has(skill)

static func known_skills(profile: Dictionary) -> Array:
	return DeepContent.section("skills").keys().filter(func(k: Variant) -> bool: return knows(profile, str(k)))

static func vault_grid(profile: Dictionary) -> Array:
	## Every skill in the pack the player may know of, in color order, as unseen, seen or
	## owned, and a Transcendent row after them once one has been made.
	var out: Array = []
	var keys: Array = known_skills(profile)
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = _color_place(str(DeepContent.skill(a).color)) + (100 if DeepContent.is_transcendent(a) else 0)
		var cb: int = _color_place(str(DeepContent.skill(b).color)) + (100 if DeepContent.is_transcendent(b) else 0)
		return ca < cb if ca != cb else a < b)
	for key in keys:
		var state: String = "owned" if profile.vault.has(key) else ("seen" if profile.seen.has(key) else "unseen")
		out.append({"skill": key, "state": state, "stone": profile.vault.get(key, {})})
	return out

# --- loadouts ------------------------------------------------------------------------------

static func loadout(profile: Dictionary, character_key: String) -> Dictionary:
	## The rail and dice a character takes down the mine: stone instances from the vault in
	## the sockets the lapidary has open (the rest go down empty, to be filled in the mine),
	## and the character's own five dice, which are never swapped.
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters.get(character_key, {"rail": [], "dice": []})
	var rail: Array = []
	var sockets: Array = character.get("sockets", [])
	var cap: int = open_sockets(profile, character_key)
	for index in range(sockets.size()):
		var skill: Variant = record.rail[index] if index < cap and index < record.rail.size() else null
		var stone: Dictionary = owned(profile, str(skill)) if skill is String else {}
		rail.append(stone.duplicate(true) if not stone.is_empty() and DeepStone.fits(stone, str(sockets[index])) else null)
	## The dice they were unlocked with, in the bowl. Every variation a die picks up is cut
	## down the mine and stays there, so a bowl is matched on the one thing that never
	## changes at home: the shape of each of the five.
	var dice: Array = []
	var own: Array = record.get("dice", [])
	var defaults: Array = character.get("dice", [])
	for index in range(mini(defaults.size(), 5)):
		var wanted: Dictionary = DeepForge.die_from(defaults[index], "fallback%d" % index)
		var die: Dictionary = bowl_die(profile, str(own[index])) if index < own.size() else {}
		if die.is_empty() or str(die.get("shape", "")) != str(wanted.shape):
			die = wanted
		dice.append(die.duplicate(true))
	return {"rail": rail, "dice": dice}

# --- Birthstones ------------------------------------------------------------------------------
##
## A delver's first Birthstone is theirs from the day they join. The variants are bought with
## gold (`DeepEconomy.unlock_birthstone`) and kept in `characters.<key>.birthstones`; the one
## they go down in is `characters.<key>.birthstone` ("" for the first). A profile from before
## the variants has neither field, and reads as owning none and wearing the first.

static func owned_birthstones(profile: Dictionary, character_key: String) -> Array:
	## The variants bought for this delver, in the pack's order.
	var record: Dictionary = profile.get("characters", {}).get(character_key, {})
	var bought: Variant = record.get("birthstones", [])
	var out: Array = []
	for key in DeepContent.birthstone_keys(character_key):
		if not str(key).is_empty() and bought is Array and bought.has(str(key)):
			out.append(str(key))
	return out

static func owns_birthstone(profile: Dictionary, character_key: String, key: String) -> bool:
	return key.is_empty() or owned_birthstones(profile, character_key).has(key)

static func worn_birthstone(profile: Dictionary, character_key: String) -> String:
	## The key of the stone this delver goes down in: "" for their first, or a variant they own.
	var worn: String = str(profile.get("characters", {}).get(character_key, {}).get("birthstone", ""))
	return worn if not worn.is_empty() and owns_birthstone(profile, character_key, worn) else ""

static func wear_birthstone(profile: Dictionary, character_key: String, key: String) -> String:
	## Puts a stone the delver owns on them for the runs to come. Returns why not, or "".
	var record: Dictionary = profile.get("characters", {}).get(character_key, {})
	if record.is_empty() or not bool(record.get("unlocked", false)):
		return "that delver has not joined the workshop"
	if not key.is_empty() and DeepContent.birthstone_key(character_key, key).is_empty():
		return "that is not one of their Birthstones"
	if not owns_birthstone(profile, character_key, key):
		return "that Birthstone is not unlocked yet"
	record.birthstone = key
	return ""

static func stone_mark(character_key: String, key: String) -> String:
	## How the records name a Birthstone: its delver and its key ("ARDOR:" is Rally).
	return "%s:%s" % [character_key, key]

static func stone_conquests(profile: Dictionary, character_key: String, key: String) -> Array:
	## The mines whose final boss has fallen to this delver wearing this stone.
	var kept: Variant = profile.get("stone_conquests", {}).get(stone_mark(character_key, key), [])
	return kept.duplicate() if kept is Array else []

static func note_stone_conquest(profile: Dictionary, character_key: String, key: String, mine_key: String) -> bool:
	## True when this is the first time this stone has beaten this mine.
	if character_key.is_empty() or DeepContent.character(character_key).is_empty() or DeepContent.mine(mine_key).is_empty():
		return false
	if not profile.get("stone_conquests", null) is Dictionary:
		profile.stone_conquests = {}
	var mark: String = stone_mark(character_key, DeepContent.birthstone_key(character_key, key))
	if not profile.stone_conquests.get(mark, null) is Array:
		profile.stone_conquests[mark] = []
	if profile.stone_conquests[mark].has(mine_key):
		return false
	profile.stone_conquests[mark].append(mine_key)
	return true

static func bowl_die(profile: Dictionary, die_id: String) -> Dictionary:
	for die in profile.bowl:
		if str(die.id) == die_id:
			return die
	return {}

static func starting_rail_cap() -> int:
	## How many sockets every lapidary has open from the start: the ones a loadout fills from
	## the vault before any run, in any mine.
	return int(DeepContent.constant("starting_rail_cap", 3))

static func open_sockets(profile: Dictionary, character_key: String) -> int:
	## How many of a lapidary's sockets are filled from the vault before a run: the first
	## three, and every one bought for them since (DeepEconomy.unlock_socket). The rest go down
	## empty and are filled in the mine; below the Quarry, with temporary stones.
	var total: int = DeepContent.character(character_key).get("sockets", []).size()
	var record: Dictionary = profile.get("characters", {}).get(character_key, {})
	return clampi(int(record.get("sockets", starting_rail_cap())), 0, total)

static func fillable_socket(profile: Dictionary, character_key: String, index: int) -> bool:
	## Whether the loadout may hold a stone in this socket: it is one of the lapidary's open
	## ones. The rest of the rail is only ever filled in the mine.
	return index >= 0 and index < open_sockets(profile, character_key)

static func rail_refusal(profile: Dictionary, character_key: String, index: int, skill: String) -> String:
	## Why an owned stone (by skill) cannot go into a socket of a loadout, or "".
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters.get(character_key, {})
	if record.is_empty() or not bool(record.get("unlocked", false)):
		return "that character is locked"
	var sockets: Array = character.get("sockets", [])
	if index < 0 or index >= sockets.size():
		return "no such socket"
	if not fillable_socket(profile, character_key, index):
		return "that socket is locked: unlock it to fill it before a run"
	var stone: Dictionary = owned(profile, skill)
	if stone.is_empty():
		return "you do not own that stone"
	if not DeepStone.fits(stone, str(sockets[index])):
		return "that socket shows %s, not this stone's color" % DeepContent.socket_name(str(sockets[index])).to_lower()
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
	## A save from when more sockets were filled before a run (every socket below the Quarry,
	## before sockets were bought): a stone sitting in a socket the lapidary has not opened
	## moves to an empty open one it fits, or comes out. True if anything moved.
	var moved: bool = false
	for key in profile.get("characters", {}):
		var record: Dictionary = profile.characters[key]
		var rail: Array = record.get("rail", [])
		for index in range(rail.size()):
			if fillable_socket(profile, str(key), index) or rail[index] == null:
				continue
			var skill: String = str(rail[index])
			rail[index] = null
			moved = true
			for slot in range(open_sockets(profile, str(key))):
				if slot < rail.size() and rail[slot] == null and set_rail(profile, str(key), slot, skill).is_empty():
					break
	return moved

# --- what comes home -----------------------------------------------------------------------

static func apply_result(profile: Dictionary, result: Dictionary, player_id: String) -> Dictionary:
	## Hauls go to the tray, dice to the bowl, records are written, unlocks granted. A run
	## that pushed on through several mines writes a record in each. A mine's final boss opens
	## the mine below and brings that mine's lapidary into the workshop; both hold whether or
	## not the party lived to ride up, because the news was carried further down instead.
	var mine_key: String = str(result.get("mine", ""))
	var visited: Array = result.get("mines", [])
	if visited.is_empty():
		visited = [ {"mine": mine_key, "deepest": int(result.get("deepest", 0)), "wardens": result.get("wardens", []), "boss": false}]
	## The daily dig is a seam of its own: it opens no mine, brings nobody into the workshop,
	## writes no mine's records and brings nothing home. What came up is scored and paid for.
	var daily: Dictionary = result.get("daily", {})
	## How far down the seam went, for the map of today's dig.
	var dug_through: Array = visited if not daily.is_empty() else []
	if not daily.is_empty():
		visited = []
	## A run on a Hazard tier writes that tier's records and opens that tier's mines; reaching
	## the Rift on the highest tier opens the next.
	var tier: int = clampi(int(result.get("hazard", 0)), 0, DeepContent.hazard_max())
	var records: Dictionary = mine_records(profile, tier) if not visited.is_empty() else {}
	var unlocked: Array = []
	var purses: Array = []
	for entry in visited:
		var key: String = str(entry.get("mine", ""))
		if not records.has(key):
			records[key] = new_mine_record(key)
		var mine_record: Dictionary = records[key]
		mine_record.unlocked = true
		mine_record.runs = int(mine_record.get("runs", 0)) + 1
		mine_record.deepest = maxi(int(mine_record.get("deepest", 0)), int(entry.get("deepest", 0)))
		for depth in entry.get("wardens", []):
			if not DeepPatch.holds(mine_record.wardens, int(depth)):
				mine_record.wardens.append(int(depth))
			## The first time each Warden falls it pays a purse of its own, once on any tier,
			## whether the party rode up afterwards or fell further down.
			var paid: int = _pay_warden(profile, key, int(depth))
			if paid > 0:
				var index: int = DeepEconomy.warden_index(key, int(depth))
				purses.append({"mine": key, "gold": paid, "warden": index, "depth": int(DeepContent.mine(key).get("warden_depths", [])[index])})
		if bool(entry.get("boss", false)):
			## Granted already the moment the boss fell (view/app.gd), unless this lapidary
			## was not there to see it; whatever is still new is new now.
			unlocked.append_array(grant_conquest(profile, key, tier))
			## The first conquest of a mine pays a purse, once, whether the party rode up with
			## the news or carried it further down.
			if not profile.get("conquest_paid", []).has(key):
				if not profile.has("conquest_paid"):
					profile.conquest_paid = []
				profile.conquest_paid.append(key)
				var purse: int = DeepEconomy.conquest_purse(key)
				if purse > 0:
					profile.gold = int(profile.get("gold", 0)) + purse
					purses.append({"mine": key, "gold": purse})
	if daily.is_empty():
		profile.records.runs = int(profile.records.runs) + 1
		match str(result.get("outcome", "")):
			"extracted": profile.records.extractions = int(profile.records.extractions) + 1
			"conquered":
				profile.records.conquests = int(profile.records.conquests) + 1
				profile.records.extractions = int(profile.records.extractions) + 1
			"fallen": profile.records.falls = int(profile.records.falls) + 1
	else:
		profile.records.dailies = int(profile.records.get("dailies", 0)) + 1
	## Every creature the party met goes in the bestiary, the day's seam's as much as any.
	var first_met: Array = DeepBestiary.merge(profile, result.get("bestiary", {}))
	var mine_result: Dictionary = result.get("players", {}).get(player_id, {})
	## Every mine whose boss fell goes on the record of the Birthstone this player wore (a stone
	## the day lent from another delver keeps no record).
	if str(mine_result.get("birthstone_of", "")).is_empty():
		for entry in visited:
			if bool(entry.get("boss", false)):
				note_stone_conquest(profile, str(mine_result.get("character", "")), str(mine_result.get("birthstone", "")), str(entry.get("mine", "")))
	var scored: Dictionary = {}
	if not daily.is_empty():
		## The day's seam: what came up is scored, and then the run is remembered and nothing
		## else is kept.
		scored = DeepEconomy.daily_score(result, player_id)
		mine_result = {"seen": mine_result.get("seen", []), "transcended": mine_result.get("transcended", [])}
	## What the run taught, whatever came of the stones themselves: a gem read under a lens
	## down there is in the vault's record even if the party never came back up with it.
	for skill in mine_result.get("seen", []):
		saw(profile, str(skill))
	## A Transcendent made down there is known from then on, wherever the stone itself ended up.
	for skill in mine_result.get("transcended", []):
		made_transcendent(profile, str(skill))
	## A vault stone whose copy was given up for something down there (an altar, a well, the
	## Prospector, a sale) is given up for good.
	var spent: Array = []
	for skill in mine_result.get("vault_spent", []):
		if profile.vault.has(str(skill)):
			profile.vault.erase(str(skill))
			spent.append(str(skill))
	var brought: Array = []
	var shattered: Array = mine_result.get("shattered", []).duplicate(true)
	## Every stone found on the run that is still carried: the bag, and anything found and set
	## on the rail. Copies of the vault's own stones never come home; see DeepDescent.coming_home.
	for stone in mine_result.get("home", mine_result.get("haul", [])):
		if DeepStone.known_fragile(stone):
			shattered.append(stone.duplicate(true))
			if bool(stone.get("appraised", false)):
				saw(profile, str(stone.get("skill", "")))
			continue
		var home: Dictionary = DeepStone.unstake(stone.duplicate(true))
		## A stone nobody read down there is read at home, where Void never forms (DeepForge.unvoid):
		## it comes up already sound, so a rough sale or a reading can never shatter it.
		if not bool(home.get("appraised", false)):
			DeepForge.unvoid(home)
		home.erase("lent")
		## What a Black Opal took in down there is gone with the run, and so is the Hollow's Void.
		home.erase("absorbed")
		home.erase("voided")
		if not home.has("provenance"):
			home.provenance = {}
		home.provenance.date = Time.get_date_string_from_system()
		profile.tray.append(home)
		brought.append(home)
	## Stones came home: the workshop opens on them, and stays there until each is decided. A
	## table left half-worked in the vault starts over as part of this haul.
	if not brought.is_empty():
		profile.homecoming = true
		profile.erase("haul")
		profile.erase("haul_report")
	for die in mine_result.get("dice", []):
		profile.bowl.append(die.duplicate(true))
	## The day's seam pays its score's worth in gold, less what the day's best already paid.
	var dug: Dictionary = {}
	if not daily.is_empty():
		dug = DeepEconomy.settle_daily(profile, scored, str(daily.get("date", DeepEconomy.today())), tier)
		dug.erase("stones")
		DeepEconomy.note_daily_reach(profile, str(daily.get("date", DeepEconomy.today())), dug_through)
	var entry: Dictionary = {"run_id": str(result.get("run_id", "")), "mine": mine_key, "outcome": str(result.get("outcome", "")),
		"depth": int(result.get("depth", 0)), "stones": brought.size(), "date": Time.get_date_string_from_system(), "gold": int(dug.get("paid", 0))}
	if tier > 0:
		entry.hazard = tier
	## The variant Birthstone worn, where one was: the ledger names it beside the delver.
	if not str(mine_result.get("birthstone", "")).is_empty() and daily.is_empty():
		entry.birthstone = str(mine_result.birthstone)
	if not daily.is_empty():
		entry.daily = true
		entry.score = int(dug.get("score", 0))
		entry.deepest_mine = str(result.get("mine", mine_key))
	## The run's tally stays with its record, and in a party, everyone's.
	var tallies: Dictionary = result.get("players", {})
	if tallies.get(player_id, {}).has("stats"):
		entry.stats = tallies[player_id].stats.duplicate(true)
	if tallies.size() > 1:
		var party: Array = []
		for id in tallies:
			var took: Dictionary = tallies[id]
			party.append({"id": str(id), "name": str(took.get("name", "")), "character": str(took.get("character", "")), "seat": int(took.get("seat", 0)),
				"stats": took.get("stats", {}).duplicate(true)})
		party.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.seat) < int(y.seat))
		entry.party = party
	profile.history.append(entry)
	var history: Array = profile.history
	for index in range(maxi(0, history.size() - HISTORY_STATS_KEPT)):
		if history[index] is Dictionary:
			history[index].erase("stats")
			for took in history[index].get("party", []):
				if took is Dictionary:
					took.erase("stats")
	## A stone that came home already read and is the first of its skill waits on the tray
	## with everything else: it is never sold, but whether it is kept or turned in for a
	## commission is the player's to say. Anything on the tray already known to be fragile
	## (an older save's) breaks now.
	clear_shattered(profile)
	return {"tray": brought, "unlocked": unlocked, "kept": [], "shattered": shattered, "purses": purses, "vault_spent": spent, "daily": dug, "first_met": first_met}

static func grant_conquest(profile: Dictionary, mine_key: String, tier: int) -> Array:
	## A mine's final boss is dead: the mine below opens on this tier, the Rift's opening
	## raises the Hazard ladder, and the mine below's lapidary comes to the workshop. All of it
	## holds whether or not the party lives to ride up, so it is granted the moment the boss
	## falls, and again (finding it done) when the run comes home. Returns what was new:
	## {mine, hazard?}, {tier}, {character}, as apply_result reports them.
	tier = clampi(tier, 0, DeepContent.hazard_max())
	var records: Dictionary = mine_records(profile, tier)
	if not records.has(mine_key):
		records[mine_key] = new_mine_record(mine_key)
	records[mine_key].unlocked = true
	records[mine_key].boss = true
	var unlocked: Array = []
	var opened: String = _open_next_in(records, mine_key)
	if not opened.is_empty():
		unlocked.append({"mine": opened, "hazard": tier} if tier > 0 else {"mine": opened})
		if DeepContent.is_endless(opened):
			var raised: int = _raise_hazard(profile, tier)
			if raised > 0:
				unlocked.append({"tier": raised})
	var lapidary: String = str(DeepContent.mine(str(DeepContent.mine(mine_key).get("next", ""))).get("lapidary", ""))
	if not lapidary.is_empty() and unlock_character(profile, lapidary):
		unlocked.append({"character": lapidary})
	return unlocked

static func warden_mark(mine_key: String, index: int) -> String:
	## How `warden_paid` names a Warden whose purse is paid: the mine and the Warden's place in
	## its `warden_depths` ("QUARRY:0" is The Foreman).
	return "%s:%d" % [mine_key, index]

static func warden_purse_due(profile: Dictionary, mine_key: String, depth: int) -> int:
	## What beating the Warden at this depth of a mine still pays this player: its purse the
	## first time, 0 once paid, or for a depth that is no Warden's.
	var index: int = DeepEconomy.warden_index(mine_key, depth)
	if index < 0 or profile.get("warden_paid", []).has(warden_mark(mine_key, index)):
		return 0
	return DeepEconomy.warden_purse(mine_key, index)

static func _pay_warden(profile: Dictionary, mine_key: String, depth: int) -> int:
	## Pays a Warden's first-time purse into the purse, once. Returns what was paid.
	var due: int = warden_purse_due(profile, mine_key, depth)
	if due <= 0:
		return 0
	if not profile.get("warden_paid", null) is Array:
		profile.warden_paid = []
	profile.warden_paid.append(warden_mark(mine_key, DeepEconomy.warden_index(mine_key, depth)))
	profile.gold = int(profile.get("gold", 0)) + due
	return due

static func spare_starters(profile: Dictionary) -> Array:
	## A starter color (Red, Blue, Green) the vault holds no stone of any more, given up down
	## the mine or at the bench, gets a plain 1 carat starter of that color back from the
	## workshop, so the first mine's sockets of that color never go down empty for good. The
	## spare goes back into every delver's empty open socket of its own color. Returns the
	## stones given.
	var given: Array = []
	for starter in STARTERS:
		var skill: String = str(starter[0])
		var hue: String = str(DeepContent.skill(skill).get("color", ""))
		if profile.get("vault", {}).values().any(func(s: Variant) -> bool: return s is Dictionary and DeepStone.colors(s).has(hue)):
			continue
		var spare: Dictionary = DeepStone.make(skill, 1, int(starter[2]), int(starter[3]), [], {"source": "starter"}, _id(profile, "st"))
		keep(profile, spare)
		given.append(profile.vault[skill])
		for key in unlocked_characters(profile):
			var rail: Array = profile.characters[key].get("rail", [])
			var sockets: Array = DeepContent.character(str(key)).get("sockets", [])
			if rail.has(skill):
				continue
			for index in range(mini(open_sockets(profile, str(key)), sockets.size())):
				if str(sockets[index]) == hue and (index >= rail.size() or rail[index] == null) and set_rail(profile, str(key), index, skill).is_empty():
					break
	return given

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
			return {"ok": true, "kept": true, "replaced": kept.replaced, "paid": 0, "forced": forced}
		return {"ok": true, "kept": false, "paid": sell(profile, stone)}
	return {"ok": false, "error": "no such stone in the tray"}

# --- the haul: every stone on the tray decided at once ---------------------------------------
## Coming home (November 13, 2026; docs/GOLD.md "Coming home"): the tray is laid out as one
## table, read with one press, and settled with one more. Each stone has a fate: into the vault
## (a skill not kept yet), in place of the one kept, sold, turned in for a commission, or sold
## rough without being read. What follows suggests them, holds them to what can happen, says
## which would give up the finer stone, and carries them out.

const FATES: Array = ["vault", "replace", "sell", "turnin", "rough"]
## The vault sizes a report calls out when a haul carries the collection past them.
const VAULT_MILESTONES: Array = [25, 50, 75, 100]

static func better_stone(a: Dictionary, b: Dictionary) -> bool:
	## Whether `a` is the finer of two stones of a skill: the higher grade, and on a tie the one
	## worth more. Anything is finer than nothing.
	if b.is_empty():
		return not a.is_empty()
	if a.is_empty():
		return false
	var ga: int = int(DeepStone.grade(a).score)
	var gb: int = int(DeepStone.grade(b).score)
	return ga > gb or (ga == gb and DeepStone.value(a) > DeepStone.value(b))

static func crack_plan(profile: Dictionary, stones: Array, rough: Array = []) -> Dictionary:
	## What reading the haul costs and what the purse covers: every raw stone and Geode not set
	## aside to be sold rough, the biggest first, as many as the gold pays for (a smaller one
	## still goes in after a bigger one the purse could not meet). {crack: ids, short: ids,
	## fee: what the cracked ones cost, total: what all of them would}.
	var waiting: Array = stones.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and not rough.has(str(s.get("id", ""))))
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return DeepStone.rough_value(a) > DeepStone.rough_value(b))
	var purse: int = int(profile.get("gold", 0))
	var out: Dictionary = {"crack": [], "short": [], "fee": 0, "total": 0}
	for stone in waiting:
		var fee: int = appraisal_fee(stone)
		out.total = int(out.total) + fee
		if int(out.fee) + fee <= purse:
			out.crack.append(str(stone.id))
			out.fee = int(out.fee) + fee
		else:
			out.short.append(str(stone.id))
	return out

static func _open_commission(profile: Dictionary, stone: Dictionary, claimed: Dictionary) -> Dictionary:
	## The best-paying open commission this stone meets that no other stone of the haul has.
	var best: Dictionary = {}
	for commission in DeepEconomy.open_commissions(profile):
		if claimed.has(str(commission.get("id", ""))) or not DeepEconomy.meets(commission, stone):
			continue
		if best.is_empty() or DeepEconomy.payout(commission, stone) > DeepEconomy.payout(best, stone):
			best = commission
	return best

static func _haul_groups(stones: Array) -> Dictionary:
	## The read stones of a haul by skill, the finest of each first.
	var groups: Dictionary = {}
	for stone in stones:
		if not bool(stone.get("appraised", false)) or DeepStone.is_fragile(stone) or str(stone.get("skill", "")).is_empty():
			continue
		var skill: String = str(stone.skill)
		if not groups.has(skill):
			groups[skill] = []
		groups[skill].append(stone)
	for skill in groups:
		groups[skill].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return better_stone(a, b))
	return groups

static func suggest_fates(profile: Dictionary, stones: Array) -> Dictionary:
	## The fate each stone of a haul is given unless the player says otherwise: the finest of a
	## skill not kept yet goes into the vault, the finest of one kept goes in its place if it is
	## finer, a commission takes what it wants of the rest, and the rest is sold. A stone nobody
	## read is sold rough. Returns {id: fate}.
	var out: Dictionary = {}
	var claimed: Dictionary = {}
	for stone in stones:
		if not bool(stone.get("appraised", false)):
			out[str(stone.id)] = "rough"
	var groups: Dictionary = _haul_groups(stones)
	for skill in groups:
		var list: Array = groups[skill]
		var kept: Dictionary = owned(profile, str(skill))
		for index in range(list.size()):
			var stone: Dictionary = list[index]
			var id: String = str(stone.id)
			if index == 0 and kept.is_empty():
				out[id] = "vault"
			elif index == 0 and better_stone(stone, kept):
				out[id] = "replace"
			else:
				var wanted: Dictionary = _open_commission(profile, stone, claimed)
				if not wanted.is_empty():
					out[id] = "turnin"
					claimed[str(wanted.id)] = true
				else:
					out[id] = "sell"
	return out

static func fates_for(profile: Dictionary, stone: Dictionary, stones: Array) -> Array:
	## What one stone of the haul can be given, in the order they are offered. A stone not read
	## can only be sold rough; a first of its skill is never sold unless another of its skill in
	## the haul could be the first kept instead.
	if not bool(stone.get("appraised", false)):
		return ["rough"]
	if DeepStone.is_fragile(stone):
		return []
	var out: Array = []
	if owned(profile, str(stone.get("skill", ""))).is_empty():
		out.append("vault")
		if stones.any(func(s: Dictionary) -> bool: return str(s.get("id", "")) != str(stone.id) and str(s.get("skill", "")) == str(stone.skill) and bool(s.get("appraised", false)) and not DeepStone.is_fragile(s)):
			out.append("sell")
	else:
		out.append_array(["replace", "sell"])
	if not DeepEconomy.commission_for(profile, stone).is_empty():
		out.append("turnin")
	return out

static func normalize_fates(profile: Dictionary, stones: Array, fates: Dictionary, changed: String = "") -> Dictionary:
	## Holds a haul's fates to what can happen: one commission one stone (the one just chosen
	## first), one stone of a skill kept at most (the one just chosen wins, the others are sold),
	## and a skill not kept yet always keeps one, the finest left, since a first is never sold.
	## "vault" and "replace" are named for whether a stone of the skill is kept already.
	var out: Dictionary = fates.duplicate()
	var claimed: Dictionary = {}
	var order: Array = stones.duplicate()
	if not changed.is_empty():
		var first: Array = order.filter(func(s: Dictionary) -> bool: return str(s.get("id", "")) == changed)
		order = first + order.filter(func(s: Dictionary) -> bool: return str(s.get("id", "")) != changed)
	for stone in order:
		var id: String = str(stone.get("id", ""))
		if str(out.get(id, "")) != "turnin":
			continue
		var wanted: Dictionary = _open_commission(profile, stone, claimed)
		if wanted.is_empty():
			out[id] = "sell"
		else:
			claimed[str(wanted.id)] = true
	var groups: Dictionary = _haul_groups(stones)
	for skill in groups:
		var list: Array = groups[skill]
		var kept_now: bool = not owned(profile, str(skill)).is_empty()
		var keepers: Array = list.filter(func(s: Dictionary) -> bool: return str(out.get(str(s.id), "")) in ["vault", "replace"])
		if keepers.size() > 1:
			var winner: Dictionary = keepers[0]
			for stone in keepers:
				if str(stone.id) == changed:
					winner = stone
			for stone in keepers:
				if stone != winner:
					out[str(stone.id)] = "sell"
		for stone in list:
			if str(out.get(str(stone.id), "")) in ["vault", "replace"]:
				out[str(stone.id)] = "replace" if kept_now else "vault"
		if not kept_now and not list.any(func(s: Dictionary) -> bool: return str(out.get(str(s.id), "")) == "vault"):
			## The finest left keeps the skill, passing over the one the player just let go.
			var heir: Dictionary = {}
			for stone in list:
				if str(out.get(str(stone.id), "sell")) != "sell" or str(stone.id) == changed:
					continue
				heir = stone
				break
			## Only the stone just let go is left: it stays, since a first is never sold.
			if heir.is_empty():
				for stone in list:
					if str(out.get(str(stone.id), "sell")) == "sell":
						heir = stone
						break
			if not heir.is_empty():
				out[str(heir.id)] = "vault"
	return out

static func costly_fates(profile: Dictionary, stones: Array, fates: Dictionary) -> Dictionary:
	## The stones whose fate gives up the finest stone of their skill (one sold or turned in
	## while a worse one is kept, or the kept one let go for a worse): {id: true}.
	var out: Dictionary = {}
	var groups: Dictionary = _haul_groups(stones)
	for skill in groups:
		var list: Array = groups[skill]
		var kept_now: Dictionary = owned(profile, str(skill))
		var ends: Dictionary = kept_now
		for stone in list:
			if str(fates.get(str(stone.id), "")) in ["vault", "replace"]:
				ends = stone
		var finest: Dictionary = kept_now
		for stone in list:
			if better_stone(stone, finest):
				finest = stone
		if finest.is_empty() or finest == ends:
			continue
		if finest == kept_now:
			for stone in list:
				if str(fates.get(str(stone.id), "")) == "replace":
					out[str(stone.id)] = true
		else:
			out[str(finest.id)] = true
	return out

static func haul_worth(stones: Array) -> int:
	## What a haul is worth: every read stone at its worth, a raw one at its rough price.
	var sum: int = 0
	for stone in stones:
		if DeepStone.is_fragile(stone):
			continue
		sum += DeepStone.value(stone) if bool(stone.get("appraised", false)) else DeepStone.rough_value(stone)
	return sum

static func _owned_of_color(profile: Dictionary, color: String) -> Array:
	## [kept, known] counts of the skills of a color: how many are in the vault, of how many.
	var known: Array = known_skills(profile).filter(func(k: Variant) -> bool: return str(DeepContent.skill(str(k)).get("color", "")) == color)
	var kept: int = known.filter(func(k: Variant) -> bool: return profile.get("vault", {}).has(str(k))).size()
	return [kept, known.size()]

static func haul_snapshot(profile: Dictionary) -> Dictionary:
	## What the report's records are measured against, taken before the haul is settled.
	var best: Dictionary = profile.get("records", {}).get("best", {})
	var colors: Dictionary = {}
	for color in DeepStone.colorS:
		colors[str(color)] = _owned_of_color(profile, str(color))
	return {"best": int(best.get("score", -1)), "tier": str(best.get("tier", "")), "owned": profile.get("vault", {}).size(),
		"opal": profile.get("vault", {}).values().any(func(s: Variant) -> bool: return s is Dictionary and DeepStone.is_opal(s)),
		"colors": colors, "best_haul": int(profile.get("records", {}).get("best_haul", 0))}

static func haul_records(profile: Dictionary, before: Dictionary, kept: Array, worth: int) -> Array:
	## The firsts a settled haul set, each [glyph, words, kind]: a best grade, a first Exquisite
	## or Peerless, a first opal, a color's every skill kept, a vault milestone, the most
	## valuable haul brought up. The record of the best haul is moved on here too.
	var out: Array = []
	var top: Dictionary = {}
	for entry in kept:
		if top.is_empty() or better_stone(entry.stone, top):
			top = entry.stone
	if not top.is_empty():
		var grade: Dictionary = DeepStone.grade(top)
		if int(before.best) >= 0 and int(grade.score) > int(before.best):
			out.append(["crown", "New best grade · %d (was %d)" % [int(grade.score), int(before.best)], "best"])
		var had: int = DeepStone.TIERS.find(str(before.tier))
		for tier in ["PEERLESS", "EXQUISITE"]:
			var rank: int = DeepStone.TIERS.find(tier)
			if had < rank and DeepStone.TIERS.find(str(grade.tier)) >= rank:
				out.append(["star", "First %s" % str(DeepStone.TIER_NAMES.get(tier, tier.capitalize())), tier])
				break
	if not bool(before.opal) and kept.any(func(e: Dictionary) -> bool: return DeepStone.is_opal(e.stone)):
		out.append(["rainbow_star", "First opal", "OPAL"])
	var colors_done: Dictionary = {}
	for entry in kept:
		var color: String = str(DeepContent.skill(str(entry.stone.get("skill", ""))).get("color", ""))
		if colors_done.has(color) or not before.colors.has(color):
			continue
		colors_done[color] = true
		var now: Array = _owned_of_color(profile, color)
		var was: Array = before.colors[color]
		if int(now[1]) > 0 and int(now[0]) >= int(now[1]) and int(was[0]) < int(was[1]):
			out.append(["gem", "Every %s skill owned" % str(DeepContent.color(color).get("name", color.capitalize())), color])
	var owned_now: int = profile.get("vault", {}).size()
	for mark in VAULT_MILESTONES:
		if int(before.owned) < int(mark) and owned_now >= int(mark):
			out.append(["chest", "Vault milestone · %d" % int(mark), "milestone"])
	if profile.has("records"):
		if int(before.best_haul) > 0 and worth > int(before.best_haul):
			out.append(["coins", "Most valuable haul · %s" % _thousands(worth), "haul"])
		profile.records.best_haul = maxi(int(before.best_haul), worth)
	return out

static func _thousands(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

static func settle_tray(profile: Dictionary, fates: Dictionary) -> Dictionary:
	## Carries out a haul's fates, every stone on the tray named in `fates`: the keeps first, so
	## a first of its skill is kept before another of it is sold; then the commissions; then the
	## sales. Returns what came of it for the report: {kept: [{stone, was, fresh}], sold: [{stone,
	## paid, rough}], turned: [{stone, paid}], gold, worth, best (the finest stone of the haul,
	## whatever its fate), records}. The finest is remembered as `brought`, for the party.
	var before: Dictionary = haul_snapshot(profile)
	var by_id: Dictionary = {}
	for stone in profile.get("tray", []):
		if fates.has(str(stone.get("id", ""))):
			by_id[str(stone.id)] = stone
	var stones: Array = by_id.values()
	var worth: int = haul_worth(stones)
	var best: Dictionary = {}
	for stone in stones:
		if bool(stone.get("appraised", false)) and not DeepStone.is_fragile(stone) and better_stone(stone, best):
			best = stone.duplicate(true)
	var out: Dictionary = {"kept": [], "sold": [], "turned": [], "gold": 0, "worth": worth, "best": best}
	for fate in ["vault", "replace", "turnin", "sell", "rough"]:
		for id in fates:
			if str(fates[id]) != fate or not by_id.has(str(id)):
				continue
			var stone: Dictionary = by_id[str(id)]
			var skill: String = str(stone.get("skill", ""))
			if fate == "turnin":
				var wanted: Dictionary = DeepEconomy.commission_for(profile, stone)
				var handed: Dictionary = DeepEconomy.turn_in(profile, str(id), str(wanted.get("id", ""))) if not wanted.is_empty() else {}
				if bool(handed.get("ok", false)):
					out.turned.append({"stone": stone.duplicate(true), "paid": int(handed.paid)})
					out.gold = int(out.gold) + int(handed.paid)
					continue
			var was: Dictionary = owned(profile, skill).duplicate(true)
			var gold_before: int = int(profile.get("gold", 0))
			var done: Dictionary = decide_tray(profile, str(id), fate in ["vault", "replace"])
			if not bool(done.get("ok", false)):
				continue
			if bool(done.get("kept", false)):
				out.kept.append({"stone": owned(profile, skill).duplicate(true), "was": was, "fresh": was.is_empty()})
			elif not bool(done.get("shattered", false)):
				var paid: int = int(profile.get("gold", 0)) - gold_before
				out.sold.append({"stone": stone.duplicate(true), "paid": paid, "rough": not bool(stone.get("appraised", false))})
				out.gold = int(out.gold) + paid
	out.records = haul_records(profile, before, out.kept, worth)
	if not best.is_empty():
		var history: Array = profile.get("history", [])
		profile.brought = {"run": str(history.back().get("run_id", "")) if not history.is_empty() else "", "skill": str(best.get("skill", "")),
			"score": int(DeepStone.grade(best).score), "tier": str(DeepStone.grade(best).tier), "carat": int(best.get("carat", 1)), "at": Time.get_unix_time_from_system()}
	return out
