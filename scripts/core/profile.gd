class_name RogueProfile
extends RefCounted
## What a player keeps between expeditions: gold, the gem collection, each hero's loadout,
## the mines they have opened, the daily shop, and the commission board.
##
## Every function here is a pure rule over a profile Dictionary. Nothing reads the clock or
## the disk: the caller passes today's date, and `ProfileStore` owns saving. A function that
## changes the profile returns an error String (empty on success) or a result Dictionary
## with `ok`, so a store can apply it to a copy and keep the original on failure.
##
## A profile belongs to one player on one machine. In a party each player brings their own
## loadout to the host's expedition and applies their own result back, so nothing here is
## shared or authoritative across the network.
const Catalog = preload("res://scripts/core/catalog.gd")
const RandomSource = preload("res://scripts/core/random_source.gd")

const SCHEMA_VERSION: int = 1
const LOADOUT_SLOTS: int = 6
## A found gem sells for ten times its trade value and the shop charges thirty. The trade
## value is the in-run `Catalog.gem_value`, so the two economies read one number.
const SELL_MULTIPLIER: int = 10
const BUY_MULTIPLIER: int = 30
const REFRESH_COST: int = 1000
const SHOP_SIZE: int = 6
const COMMISSION_SLOTS: int = 3
const SPECIAL_CHANCE_PERCENT: int = 50
const APPLIED_RESULT_MEMORY: int = 64
const OUTCOMES: Array = ["extracted", "fallen", "conquered"]
const COMMISSION_KINDS: Array = ["color_carat", "rarity", "rank", "depth", "boss"]
const SPECIAL_MODIFIERS: Dictionary = {
	"swift_tremors": {"name": "Swift Tremors", "description": "The tremor meter fills half again as fast."},
	"no_camps": {"name": "No Camps", "description": "The seam holds no camps."},
	"elite_depths": {"name": "Elite Depths", "description": "Elite fights are twice as common."},
	"dim_lanterns": {"name": "Dim Lanterns", "description": "You see exact rooms only one layer ahead."}
}
const LIFETIME_FIELDS: Array = ["runs", "extracted", "fallen", "conquered", "deepest", "gems_kept", "gems_sold", "gold_earned", "gold_spent", "commissions"]

# --- creation and loading -------------------------------------------------------

static func create(profile_id: String) -> Dictionary:
	var lifetime: Dictionary = {}
	for field in LIFETIME_FIELDS:
		lifetime[field] = 0
	var profile: Dictionary = {"schema_version": SCHEMA_VERSION, "profile_id": profile_id, "gold": 0,
		"collection": {}, "seen_gems": [], "heroes": {}, "selected_hero": "", "mines": {},
		"encountered": {"enemies": [], "bosses": []}, "shop": {"date": "", "stock": [], "refreshes": 0},
		"commissions": {"board": [], "special": [], "next_id": 1, "special_checked": ""},
		"pending_return": {}, "applied_results": [], "lifetime": lifetime}
	return normalize(profile).profile

static func normalize(source: Variant) -> Dictionary:
	## Checks a loaded profile's shape and fills in whatever this build knows about that the
	## file does not: a hero or mine added to the content since the profile was saved. A new
	## hero arrives unlocked with its starting gems, so an update never locks anyone out.
	Catalog.ensure_loaded()
	if not source is Dictionary:
		return {"ok": false, "error": "The profile is not an object.", "profile": {}}
	var profile: Dictionary = source.duplicate(true)
	if not _is_int(profile.get("schema_version")) or int(profile.schema_version) < 1:
		return {"ok": false, "error": "The profile has no schema version.", "profile": {}}
	if int(profile.schema_version) > SCHEMA_VERSION:
		return {"ok": false, "error": "This profile was saved by a newer version of the game.", "profile": {}}
	if not profile.get("profile_id") is String or str(profile.profile_id).is_empty():
		return {"ok": false, "error": "The profile has no identity.", "profile": {}}
	profile.schema_version = SCHEMA_VERSION
	profile.gold = maxi(0, int(profile.get("gold", 0))) if _is_int(profile.get("gold", 0)) else 0
	for field in ["collection", "heroes", "mines", "encountered", "shop", "commissions", "pending_return", "lifetime"]:
		if not profile.get(field) is Dictionary:
			profile[field] = {}
	for field in ["seen_gems", "applied_results"]:
		if not profile.get(field) is Array:
			profile[field] = []
	var collection: Dictionary = {}
	for key in profile.collection:
		var gem: Variant = profile.collection[key]
		if gem is Dictionary and Catalog.definitions("skills").has(str(key)):
			collection[str(key)] = gem_record(gem)
	profile.collection = collection
	var heroes: Dictionary = Catalog.definitions("heroes")
	for hero_key in heroes:
		if not profile.heroes.get(hero_key) is Dictionary:
			profile.heroes[hero_key] = {"unlocked": true, "loadout": []}
			for starter in heroes[hero_key].get("starting_gems", []):
				var gem: Dictionary = Catalog.gem(str(starter[0]), "", int(starter[1]), int(starter[2]) if starter.size() > 2 else 1, int(starter[3]) if starter.size() > 3 else 1)
				if gem.is_empty():
					continue
				var owned: Dictionary = profile.collection.get(gem.key, {})
				if owned.is_empty() or Catalog.gem_value(owned) < Catalog.gem_value(gem):
					profile.collection[gem.key] = gem_record(gem)
				profile.heroes[hero_key].loadout.append(gem.key)
		var record: Dictionary = profile.heroes[hero_key]
		record.unlocked = bool(record.get("unlocked", true))
		var loadout: Array = []
		for key in record.get("loadout", []) if record.get("loadout", []) is Array else []:
			if profile.collection.has(str(key)) and not str(key) in loadout and loadout.size() < LOADOUT_SLOTS:
				loadout.append(str(key))
		if not "STRIKE" in loadout and profile.collection.has("STRIKE"):
			if loadout.size() >= LOADOUT_SLOTS:
				loadout.pop_back()
			loadout.push_front("STRIKE")
		record.loadout = loadout
	if not profile.get("selected_hero") is String or not heroes.has(profile.selected_hero) or not profile.heroes[profile.selected_hero].unlocked:
		profile.selected_hero = ""
		var keys: Array = heroes.keys()
		keys.sort()
		for hero_key in keys:
			if profile.heroes[hero_key].unlocked:
				profile.selected_hero = hero_key
				break
	for mine_id in Catalog.mine_ids():
		var record: Variant = profile.mines.get(mine_id)
		if not record is Dictionary:
			record = {}
		var starter: bool = bool(Catalog.mine_definition(mine_id).get("starter", false))
		profile.mines[mine_id] = {"unlocked": bool(record.get("unlocked", false)) or starter,
			"boss_defeated": bool(record.get("boss_defeated", false)),
			"deepest": maxi(0, int(record.get("deepest", 0))), "expeditions": maxi(0, int(record.get("expeditions", 0)))}
	for field in ["enemies", "bosses"]:
		if not profile.encountered.get(field) is Array:
			profile.encountered[field] = []
	for field in ["stock"]:
		if not profile.shop.get(field) is Array:
			profile.shop[field] = []
	profile.shop.date = str(profile.shop.get("date", ""))
	profile.shop.refreshes = maxi(0, int(profile.shop.get("refreshes", 0)))
	for field in ["board", "special"]:
		if not profile.commissions.get(field) is Array:
			profile.commissions[field] = []
	profile.commissions.next_id = maxi(1, int(profile.commissions.get("next_id", 1)))
	profile.commissions.special_checked = str(profile.commissions.get("special_checked", ""))
	for field in LIFETIME_FIELDS:
		profile.lifetime[field] = maxi(0, int(profile.lifetime.get(field, 0)))
	for key in profile.collection:
		if not key in profile.seen_gems:
			profile.seen_gems.append(key)
	return {"ok": true, "error": "", "profile": profile}

# --- gems -----------------------------------------------------------------------

static func gem_record(gem: Dictionary) -> Dictionary:
	## The only parts of a gem that persist. An expedition's instance ID, equipped flag and
	## per-encounter charges are expedition state and stay behind.
	return {"key": str(gem.get("key", "")), "carat": clampi(int(gem.get("carat", 1)), 1, 24),
		"cut": clampi(int(gem.get("cut", 1)), 1, 5), "clarity": clampi(int(gem.get("clarity", 1)), 1, 5)}

static func gem_state(profile: Dictionary, key: String) -> String:
	if profile.collection.has(key):
		return "owned"
	return "seen" if key in profile.seen_gems else "unseen"

static func sell_value(gem: Dictionary) -> int:
	return Catalog.gem_value(gem) * SELL_MULTIPLIER

static func buy_price(gem: Dictionary) -> int:
	return Catalog.gem_value(gem) * BUY_MULTIPLIER

static func compare(candidate: Dictionary, owned: Dictionary) -> Dictionary:
	## Rank by rank, what the candidate would change about the owned version. Empty when the
	## player owns nothing to compare against.
	if owned.is_empty():
		return {}
	return {"carat": int(candidate.get("carat", 1)) - int(owned.get("carat", 1)),
		"cut": int(candidate.get("cut", 1)) - int(owned.get("cut", 1)),
		"clarity": int(candidate.get("clarity", 1)) - int(owned.get("clarity", 1)),
		"value": sell_value(candidate) - sell_value(owned)}

static func collection_grid(profile: Dictionary, sort_by: String = "rarity") -> Array:
	## Every gem the content knows, in the order the bag shows them. Unseen entries carry no
	## name so a screen cannot leak one by accident.
	var rows: Array = []
	for key in Catalog.definitions("skills"):
		var definition: Dictionary = Catalog.definitions("skills")[key]
		var state: String = gem_state(profile, key)
		rows.append({"key": key, "state": state, "name": "" if state == "unseen" else str(definition.name),
			"color": str(definition.get("color", "RED")), "rarity": int(definition.get("rarity", 1)),
			"gem": profile.collection.get(key, {}), "value": sell_value(profile.collection[key]) if state == "owned" else 0})
	var color_order: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]
	var state_order: Array = ["owned", "seen", "unseen"]
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: Array
		var right: Array
		match sort_by:
			"color": left = [color_order.find(a.color), a.rarity]; right = [color_order.find(b.color), b.rarity]
			"name": left = [state_order.find(a.state), a.name]; right = [state_order.find(b.state), b.name]
			"owned": left = [state_order.find(a.state), -a.value]; right = [state_order.find(b.state), -b.value]
			_: left = [a.rarity, color_order.find(a.color)]; right = [b.rarity, color_order.find(b.color)]
		left.append(a.key)
		right.append(b.key)
		return _ordered_before(left, right))
	return rows

static func _ordered_before(left: Array, right: Array) -> bool:
	## Arrays have no `<` in GDScript, so sort keys compare field by field.
	for index in range(mini(left.size(), right.size())):
		if left[index] != right[index]:
			return left[index] < right[index]
	return left.size() < right.size()

static func _add_to_collection(profile: Dictionary, gem: Dictionary) -> Dictionary:
	## One copy per skill: the incoming gem takes the slot and the old one is sold for its
	## value. Loadouts name skill keys, so they keep pointing at the replacement.
	var record: Dictionary = gem_record(gem)
	var old: Dictionary = profile.collection.get(record.key, {})
	var gold: int = 0
	if not old.is_empty():
		gold = sell_value(old)
		_earn(profile, gold)
	profile.collection[record.key] = record
	mark_seen(profile, [record.key])
	return {"replaced": old, "gold": gold}

static func mark_seen(profile: Dictionary, keys: Array) -> void:
	for key in keys:
		if Catalog.definitions("skills").has(str(key)) and not str(key) in profile.seen_gems:
			profile.seen_gems.append(str(key))

# --- heroes and loadouts -----------------------------------------------------------

static func set_loadout(profile: Dictionary, hero_key: String, keys: Variant) -> String:
	var record: Dictionary = profile.heroes.get(hero_key, {})
	if record.is_empty() or not record.get("unlocked", false):
		return "That hero is not unlocked."
	if not keys is Array or keys.is_empty() or keys.size() > LOADOUT_SLOTS:
		return "A loadout holds one to %d gems." % LOADOUT_SLOTS
	var seen: Array = []
	for key in keys:
		if not key is String or key in seen:
			return "Each gem may appear once in a loadout."
		if not profile.collection.has(key):
			return "You do not own %s." % key
		seen.append(key)
	if not "STRIKE" in seen:
		return "Strike must stay in every loadout."
	record.loadout = seen
	return ""

static func select_hero(profile: Dictionary, hero_key: String) -> String:
	if not profile.heroes.get(hero_key, {}).get("unlocked", false):
		return "That hero is not unlocked."
	profile.selected_hero = hero_key
	return ""

static func loadout_gems(profile: Dictionary, hero_key: String, id_prefix: String) -> Array:
	## The loadout as expedition gem instances, equipped in order and marked as loadout gems
	## so the expedition knows never to put them at risk.
	var gems: Array = []
	for key in profile.heroes.get(hero_key, {}).get("loadout", []):
		var owned: Dictionary = profile.collection.get(key, {})
		if owned.is_empty():
			continue
		var gem: Dictionary = Catalog.gem(key, "%s-g%d" % [id_prefix, gems.size()], owned.carat, owned.cut, owned.clarity)
		gem.equipped = true
		gem["loadout"] = true
		gems.append(gem)
	return gems

# --- mines ----------------------------------------------------------------------

static func mine_state(profile: Dictionary, mine_id: String) -> String:
	## Unlocked mines are lit. A mine linked from an unlocked one shows as a silhouette.
	## Anything further out is not drawn at all.
	if profile.mines.get(mine_id, {}).get("unlocked", false):
		return "unlocked"
	for other in Catalog.mine_ids():
		if profile.mines.get(other, {}).get("unlocked", false) and mine_id in Catalog.mine_definition(other).get("links", []):
			return "revealed"
	return "hidden"

static func unlocked_mines(profile: Dictionary) -> Array:
	return Catalog.mine_ids().filter(func(key: String) -> bool: return mine_state(profile, key) == "unlocked")

static func shop_quality(profile: Dictionary) -> int:
	## The shopkeeper buys from the best mine the player has opened.
	var best: int = 0
	for mine_id in unlocked_mines(profile):
		best = maxi(best, int(Catalog.mine_definition(mine_id).get("quality_bonus", 0)) + 3)
	return best

# --- the daily shop -------------------------------------------------------------

static func ensure_shop(profile: Dictionary, date: String) -> void:
	if profile.shop.date == date:
		return
	profile.shop = {"date": date, "refreshes": 0, "stock": _roll_stock(profile, date, 0)}

static func refresh_cost(profile: Dictionary) -> int:
	return REFRESH_COST * (int(profile.shop.get("refreshes", 0)) + 1)

static func refresh_shop(profile: Dictionary, date: String) -> String:
	ensure_shop(profile, date)
	var cost: int = refresh_cost(profile)
	if int(profile.gold) < cost:
		return "Refreshing the shop costs %d gold." % cost
	_spend(profile, cost)
	profile.shop.refreshes = int(profile.shop.refreshes) + 1
	profile.shop.stock = _roll_stock(profile, date, int(profile.shop.refreshes))
	return ""

static func buy_offer(profile: Dictionary, offer_id: String, date: String) -> Dictionary:
	if profile.shop.date != date:
		ensure_shop(profile, date)
		return {"ok": false, "error": "The shop has restocked for a new day."}
	var offer: Dictionary = {}
	for candidate in profile.shop.stock:
		if candidate.get("id", "") == offer_id:
			offer = candidate
	if offer.is_empty() or offer.get("sold", false):
		return {"ok": false, "error": "That gem is no longer for sale."}
	if int(profile.gold) < int(offer.price):
		return {"ok": false, "error": "That gem costs %d gold." % int(offer.price)}
	_spend(profile, int(offer.price))
	offer.sold = true
	var added: Dictionary = _add_to_collection(profile, offer.gem)
	return {"ok": true, "error": "", "replaced": added.replaced, "gold": added.gold}

static func _roll_stock(profile: Dictionary, date: String, refresh: int) -> Array:
	## Only gems the player has seen, and never one they already own at equal or better
	## value. The same profile, date and refresh count always make the same stock.
	var rng: RandomNumberGenerator = _rng("%s|shop|%s|%d" % [profile.profile_id, date, refresh])
	var pool: Array = profile.seen_gems.filter(func(key: String) -> bool: return Catalog.definitions("skills").has(key))
	var quality: int = shop_quality(profile)
	var stock: Array = []
	var index: int = 0
	while stock.size() < SHOP_SIZE and not pool.is_empty():
		var gem: Dictionary = Catalog.roll_gem(rng, pool, quality, "shop-%s-%d-%d" % [date, refresh, index])
		index += 1
		if gem.is_empty():
			break
		pool.erase(gem.key)
		var owned: Dictionary = profile.collection.get(gem.key, {})
		if not owned.is_empty() and Catalog.gem_value(owned) >= Catalog.gem_value(gem):
			continue
		var record: Dictionary = gem_record(gem)
		stock.append({"id": gem.id, "gem": record, "price": buy_price(record), "sold": false})
	return stock

# --- expedition results and the return --------------------------------------------

static func apply_result(profile: Dictionary, result: Variant) -> Dictionary:
	## Brings an expedition home: unlocks, discoveries, commission progress, and the haul
	## waiting on the appraisal table. Applying the same result twice does nothing, so a host
	## resending it after a reconnect never pays out again.
	var problem: String = _result_error(result)
	if not problem.is_empty():
		return {"ok": false, "error": problem}
	if result.result_id in profile.applied_results:
		return {"ok": true, "error": "", "duplicate": true, "unlocked": [], "completed": []}
	if not profile.pending_return.is_empty():
		finish_return(profile)
	var mine_id: String = result.mine_id
	var record: Dictionary = profile.mines[mine_id]
	record.expeditions = int(record.expeditions) + 1
	record.deepest = maxi(int(record.deepest), int(result.depth))
	var unlocked: Array = []
	if result.outcome == "conquered":
		record.boss_defeated = true
		for target in [mine_id] + Catalog.mine_definition(mine_id).get("links", []):
			if profile.mines.has(target) and not profile.mines[target].unlocked:
				profile.mines[target].unlocked = true
				unlocked.append(target)
	for field in ["enemies", "bosses"]:
		for key in result.get("encountered", {}).get(field, []):
			if not str(key) in profile.encountered[field]:
				profile.encountered[field].append(str(key))
	var keys: Array = result.get("seen_gems", []).duplicate()
	var gems: Array = []
	for gem in result.haul:
		keys.append(gem.key)
		var entry: Dictionary = gem_record(gem)
		entry["id"] = str(gem.id)
		entry["decision"] = ""
		gems.append(entry)
	mark_seen(profile, keys)
	var completed: Array = _progress_commissions(profile, result)
	profile.pending_return = {"result_id": result.result_id, "mine_id": mine_id, "outcome": result.outcome,
		"depth": int(result.depth), "gems": gems, "unlocked": unlocked}
	profile.lifetime.runs += 1
	profile.lifetime[result.outcome] += 1
	profile.lifetime.deepest = maxi(int(profile.lifetime.deepest), int(result.depth))
	profile.applied_results.append(result.result_id)
	while profile.applied_results.size() > APPLIED_RESULT_MEMORY:
		profile.applied_results.pop_front()
	return {"ok": true, "error": "", "duplicate": false, "unlocked": unlocked, "completed": completed}

static func decide_return_gem(profile: Dictionary, gem_id: String, keep: bool) -> Dictionary:
	## Keep or sell one gem from the appraisal table. A decision is final.
	var entry: Dictionary = _pending_gem(profile, gem_id)
	if entry.is_empty():
		return {"ok": false, "error": "That gem is not on the appraisal table."}
	if not str(entry.decision).is_empty():
		return {"ok": false, "error": "That gem has already been kept or sold."}
	var gold: int = 0
	var replaced: Dictionary = {}
	if keep:
		var added: Dictionary = _add_to_collection(profile, entry)
		gold = added.gold
		replaced = added.replaced
		entry.decision = "kept"
		profile.lifetime.gems_kept += 1
	else:
		gold = sell_value(entry)
		_earn(profile, gold)
		entry.decision = "sold"
		profile.lifetime.gems_sold += 1
	return {"ok": true, "error": "", "gold": gold, "replaced": replaced}

static func finish_return(profile: Dictionary) -> Dictionary:
	## Leaves the table. Anything still undecided is sold rather than lost.
	var gold: int = 0
	var sold: Array = []
	for entry in profile.pending_return.get("gems", []):
		if str(entry.get("decision", "")).is_empty():
			var outcome: Dictionary = decide_return_gem(profile, str(entry.id), false)
			gold += int(outcome.get("gold", 0))
			sold.append(str(entry.id))
	profile.pending_return = {}
	return {"ok": true, "error": "", "gold": gold, "sold": sold}

static func _pending_gem(profile: Dictionary, gem_id: String) -> Dictionary:
	for entry in profile.pending_return.get("gems", []):
		if str(entry.get("id", "")) == gem_id:
			return entry
	return {}

static func _result_error(result: Variant) -> String:
	if not result is Dictionary:
		return "The expedition result is not an object."
	if not result.get("result_id") is String or str(result.result_id).is_empty():
		return "The expedition result has no identity."
	if Catalog.mine_definition(str(result.get("mine_id", ""))).is_empty():
		return "The expedition result names an unknown mine."
	if not str(result.get("outcome", "")) in OUTCOMES:
		return "The expedition result has an unknown ending."
	if not _is_int(result.get("depth")) or int(result.depth) < 0:
		return "The expedition result has no depth."
	if not result.get("haul") is Array:
		return "The expedition result has no haul."
	var ids: Array = []
	for gem in result.haul:
		if not gem is Dictionary or not Catalog.definitions("skills").has(str(gem.get("key", ""))) or str(gem.get("id", "")).is_empty() or str(gem.id) in ids:
			return "The expedition haul contains an invalid gem."
		ids.append(str(gem.id))
	if not result.get("seen_gems", []) is Array or not result.get("encountered", {}) is Dictionary:
		return "The expedition result has malformed discoveries."
	return ""

# --- commissions ----------------------------------------------------------------

static func ensure_commissions(profile: Dictionary, date: String) -> void:
	## Keeps three notes on the board, expires stale special missions, and rolls at most one
	## chance a day for a new special mission.
	var commissions: Dictionary = profile.commissions
	while commissions.board.size() < COMMISSION_SLOTS:
		var note: Dictionary = _roll_commission(profile, commissions.board.map(func(existing: Dictionary) -> String: return str(existing.get("kind", ""))))
		if note.is_empty():
			break
		commissions.board.append(note)
	commissions.special = commissions.special.filter(func(note: Dictionary) -> bool:
		return note.get("status", "") == "complete" or str(note.get("expires", "")) > date)
	if commissions.special_checked != date:
		commissions.special_checked = date
		var rng: RandomNumberGenerator = _rng("%s|special|%s" % [profile.profile_id, date])
		var mines: Array = unlocked_mines(profile)
		if rng.randi_range(1, 100) <= SPECIAL_CHANCE_PERCENT and commissions.special.is_empty() and not mines.is_empty():
			var mine_id: String = mines[rng.randi_range(0, mines.size() - 1)]
			var modifiers: Array = SPECIAL_MODIFIERS.keys()
			modifiers.sort()
			var difficulty: int = int(Catalog.mine_definition(mine_id).get("difficulty", 1))
			commissions.special.append({"id": _commission_id(profile), "kind": "special", "status": "open",
				"mine_id": mine_id, "modifier": modifiers[rng.randi_range(0, modifiers.size() - 1)],
				"expires": next_date(date), "reward": {"gold": 2500 * difficulty,
					"gem": gem_record(Catalog.roll_gem(rng, Catalog.mine_definition(mine_id).get("skill_ids", []), mini(Catalog.MAX_QUALITY, int(Catalog.mine_definition(mine_id).get("quality_bonus", 0)) + 12), "reward"))}})

static func claim_commission(profile: Dictionary, commission_id: String) -> Dictionary:
	for field in ["board", "special"]:
		var notes: Array = profile.commissions[field]
		for note in notes:
			if note.get("id", "") != commission_id:
				continue
			if note.get("status", "") != "complete":
				return {"ok": false, "error": "That commission is not complete yet."}
			var gold: int = int(note.get("reward", {}).get("gold", 0))
			_earn(profile, gold)
			var gem: Dictionary = note.get("reward", {}).get("gem", {})
			var replaced: Dictionary = {}
			if not gem.is_empty():
				var added: Dictionary = _add_to_collection(profile, gem)
				gold += int(added.gold)
				replaced = added.replaced
			notes.erase(note)
			profile.lifetime.commissions += 1
			return {"ok": true, "error": "", "gold": gold, "gem": gem, "replaced": replaced}
	return {"ok": false, "error": "That commission is not on the board."}

static func describe_commission(note: Dictionary) -> String:
	var mine: Dictionary = Catalog.mine_definition(str(note.get("mine_id", "")))
	match str(note.get("kind", "")):
		"color_carat": return "Bring back a %s gem of Carat %d or more." % [str(Catalog.GEM_COLORS.get(note.color, {}).get("name", note.color)), int(note.carat)]
		"rarity": return "Bring back a %s gem or rarer." % ["", "Common", "Uncommon", "Rare", "Legendary"][clampi(int(note.rarity), 1, 4)]
		"rank":
			var names: Array = Catalog.CUT_NAMES if note.property == "cut" else Catalog.CLARITY_NAMES
			return "Bring back a gem of %s %s or better." % [names[clampi(int(note.rank), 1, 5) - 1], "Cut" if note.property == "cut" else "Clarity"]
		"depth": return "Reach depth %d in %s and return alive." % [int(note.depth), str(mine.get("name", "the mine"))]
		"boss": return "Defeat %s in %s." % [str(Catalog.definitions("enemies").get(mine.get("boss_id", ""), {}).get("name", "the boss")), str(mine.get("name", "the mine"))]
		"special": return "%s: defeat %s under %s." % [str(mine.get("name", "The mine")), str(Catalog.definitions("enemies").get(mine.get("boss_id", ""), {}).get("name", "the boss")), str(SPECIAL_MODIFIERS.get(note.get("modifier", ""), {}).get("name", "strange conditions"))]
	return ""

static func commission_met(note: Dictionary, result: Dictionary) -> bool:
	## Delivery notes read the haul that actually came home, after any salvage roll, so a
	## gem recovered from a fallen party still counts. Depth and boss notes need the party
	## to have come back on its feet.
	var haul: Array = result.get("haul", [])
	match str(note.get("kind", "")):
		"color_carat":
			return haul.any(func(gem: Dictionary) -> bool: return Catalog.gem_color(gem.key) == note.color and int(gem.carat) >= int(note.carat))
		"rarity":
			return haul.any(func(gem: Dictionary) -> bool: return int(Catalog.definitions("skills")[gem.key].rarity) >= int(note.rarity))
		"rank":
			return haul.any(func(gem: Dictionary) -> bool: return int(gem.get(note.property, 1)) >= int(note.rank))
		"depth":
			return result.mine_id == note.mine_id and int(result.depth) >= int(note.depth) and result.outcome != "fallen"
		"boss":
			return result.mine_id == note.mine_id and result.outcome == "conquered"
		"special":
			return result.mine_id == note.mine_id and result.outcome == "conquered" and str(result.get("special_id", "")) == str(note.id)
	return false

static func _progress_commissions(profile: Dictionary, result: Dictionary) -> Array:
	var completed: Array = []
	for field in ["board", "special"]:
		for note in profile.commissions[field]:
			if note.get("status", "") == "open" and commission_met(note, result):
				note.status = "complete"
				completed.append(str(note.id))
	return completed

static func _roll_commission(profile: Dictionary, avoid: Array = []) -> Dictionary:
	var id: String = _commission_id(profile)
	var rng: RandomNumberGenerator = _rng("%s|commission|%s" % [profile.profile_id, id])
	var mines: Array = unlocked_mines(profile)
	if mines.is_empty():
		return {}
	var hardest: int = 1
	for mine_id in mines:
		hardest = maxi(hardest, int(Catalog.mine_definition(mine_id).get("difficulty", 1)))
	## A board of three different asks reads better than three versions of one, so kinds
	## already pinned up are skipped while any other kind is left.
	var weights: Array = [3, 2, 2, 3, 1]
	for index in range(COMMISSION_KINDS.size()):
		if COMMISSION_KINDS[index] in avoid:
			weights[index] = 0
	if weights.all(func(weight: int) -> bool: return weight == 0):
		weights = [3, 2, 2, 3, 1]
	var kind: String = COMMISSION_KINDS[RandomSource.weighted_index(rng, weights)]
	var note: Dictionary = {"id": id, "kind": kind, "status": "open", "reward": {}}
	var mine_id: String = mines[rng.randi_range(0, mines.size() - 1)]
	var difficulty: int = int(Catalog.mine_definition(mine_id).get("difficulty", 1))
	match kind:
		"color_carat":
			var colors: Array = Catalog.GEM_COLORS.keys()
			colors.sort()
			note.color = colors[rng.randi_range(0, colors.size() - 1)]
			note.carat = 3 + 3 * hardest + rng.randi_range(0, 2)
			note.reward.gold = 60 * int(note.carat)
		"rarity":
			note.rarity = mini(4, 2 + rng.randi_range(0, mini(2, hardest)))
			note.reward.gold = 150 * int(note.rarity) * int(note.rarity)
		"rank":
			note.property = ["cut", "clarity"][rng.randi_range(0, 1)]
			note.rank = mini(5, 2 + hardest + rng.randi_range(0, 1))
			note.reward.gold = 120 * int(note.rank) * int(note.rank)
		"depth":
			note.mine_id = mine_id
			note.depth = 4 + 3 * difficulty + rng.randi_range(0, 3)
			note.reward.gold = 45 * int(note.depth) * difficulty
		"boss":
			note.mine_id = mine_id
			note.reward.gold = 1500 * difficulty
	return note

static func _commission_id(profile: Dictionary) -> String:
	var id: String = "c%d" % int(profile.commissions.next_id)
	profile.commissions.next_id = int(profile.commissions.next_id) + 1
	return id

# --- helpers --------------------------------------------------------------------

static func next_date(date: String) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix + 86400)

static func _earn(profile: Dictionary, amount: int) -> void:
	profile.gold = int(profile.gold) + maxi(0, amount)
	profile.lifetime.gold_earned = int(profile.lifetime.get("gold_earned", 0)) + maxi(0, amount)

static func _spend(profile: Dictionary, amount: int) -> void:
	profile.gold = maxi(0, int(profile.gold) - amount)
	profile.lifetime.gold_spent = int(profile.lifetime.get("gold_spent", 0)) + maxi(0, amount)

static func _rng(seed_text: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_text.hash()
	return rng

static func _is_int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))
