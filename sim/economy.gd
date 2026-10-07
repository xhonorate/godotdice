class_name DeepEconomy
extends RefCounted
## Gold at home: what the workshop charges and pays between runs (docs/GOLD.md). The fare
## down to a deeper mine and the insurance on a haul, sockets bought for a lapidary for good,
## the pyrite weighed into gold at the lift, a purse for the first conquest of each mine, and
## the commissions the Ledger keeps.
##
## Every price is read from the pack. Nothing here makes a kept stone better: gold buys a
## way down, protection and sockets, and a commission takes a stone away for its price.

# --- the day --------------------------------------------------------------------------------

static func today() -> String:
	## The day everything daily turns over on: the calendar day in UTC, the same for every
	## player wherever they are.
	return Time.get_date_string_from_system(true)

static func seconds_to_tomorrow() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return maxi(1, 86400 - (int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second)))

static func roll_day(profile: Dictionary, date: String = "") -> bool:
	## Turns the workshop over to a new day: every commission still open is replaced, every
	## slot filled yesterday gets a new one, and the free reroll comes back. A day already
	## begun only tops up empty slots (a profile that had no mine to draw a skill from yet).
	## True if anything changed.
	if date.is_empty():
		date = today()
	if not profile.get("daily", null) is Dictionary:
		profile.daily = {}
	var daily: Dictionary = profile.daily
	var changed: bool = false
	if str(daily.get("date", "")) != date:
		daily.date = date
		daily.rerolls = 0
		daily.commissions = []
		daily.seq = 0
		changed = true
	if not daily.get("commissions", null) is Array:
		daily.commissions = []
	while daily.commissions.size() < commission_slots():
		var made: Dictionary = _new_commission(profile, date, _taken(daily.commissions))
		if made.is_empty():
			break
		daily.commissions.append(made)
		changed = true
	return changed

# --- the way down -----------------------------------------------------------------------------

static func fare(mine_key: String) -> int:
	## What the cage costs to lower a lapidary to the top of a mine. The Quarry is free.
	return maxi(0, int(DeepContent.mine(mine_key).get("fare_gold", 0)))

static func insurance(mine_key: String) -> int:
	## What it costs to have every salvage die thrown twice if the dig is lost.
	return maxi(0, int(DeepContent.mine(mine_key).get("insurance_gold", 0)))

static func departure(mine_key: String, insured: bool) -> int:
	return fare(mine_key) + (insurance(mine_key) if insured else 0)

static func fresh_run(run: Dictionary) -> bool:
	## A run nobody has set foot in yet: still at the shaft head or the first mouths.
	return int(run.get("depth", 0)) == 0 and run.get("path", []).is_empty() and str(run.get("phase", "")) in ["grubstake", "tunnels"]

static func charge_departure(profile: Dictionary, run: Dictionary, player_id: String) -> Dictionary:
	## Takes this player's fare (and insurance, if they bought it) once per run. Each machine
	## bills its own profile when the run reaches it. A run picked up again from a checkpoint
	## was paid for when it began, and one already under way is never billed.
	var unit: Dictionary = DeepDescent.player(run, player_id)
	var run_id: String = str(run.get("run_id", ""))
	if unit.is_empty() or run_id.is_empty() or str(profile.get("charged_run", "")) == run_id:
		return {}
	profile.charged_run = run_id
	if not fresh_run(run):
		return {}
	var mine_key: String = str(run.get("from_mine", run.get("mine", "")))
	var owed_fare: int = fare(mine_key)
	var owed_insurance: int = insurance(mine_key) if bool(unit.get("insured", false)) else 0
	var paid: int = mini(int(profile.get("gold", 0)), owed_fare + owed_insurance)
	profile.gold = int(profile.get("gold", 0)) - paid
	return {"fare": owed_fare, "insurance": owed_insurance, "paid": paid}

# --- sockets ----------------------------------------------------------------------------------

static func socket_price(profile: Dictionary, character_key: String) -> int:
	## What this lapidary's next socket costs, or -1 when every socket is already open. Each
	## costs more than the last; a socket past the end of the written prices costs four times
	## the one before it.
	var total: int = DeepContent.character(character_key).get("sockets", []).size()
	var open: int = DeepProfile.open_sockets(profile, character_key)
	if open >= total:
		return -1
	var prices: Array = DeepContent.constant("socket_unlock_gold", [300, 1200, 4800])
	var step: int = maxi(0, open - DeepProfile.starting_rail_cap())
	if prices.is_empty():
		return -1
	if step < prices.size():
		return int(prices[step])
	return int(prices.back()) * int(pow(4.0, float(step - prices.size() + 1)))

static func unlock_socket(profile: Dictionary, character_key: String) -> Dictionary:
	## Buys this lapidary's next socket, for good.
	var record: Dictionary = profile.get("characters", {}).get(character_key, {})
	if record.is_empty() or not bool(record.get("unlocked", false)):
		return {"ok": false, "error": "that lapidary has not joined the workshop"}
	var price: int = socket_price(profile, character_key)
	if price < 0:
		return {"ok": false, "error": "every socket is already open"}
	if int(profile.get("gold", 0)) < price:
		return {"ok": false, "error": "the next socket costs %d gold" % price}
	profile.gold = int(profile.gold) - price
	record.sockets = DeepProfile.open_sockets(profile, character_key) + 1
	return {"ok": true, "paid": price, "sockets": int(record.sockets)}

# --- coming up --------------------------------------------------------------------------------

static func earned(unit: Dictionary, amount: int) -> void:
	## Writes pyrite a player came by down the mine (a fight, a vein, a sale, an oddity, a well,
	## a stake) into the tally the assayer weighs at the lift. The purse a deeper mine hands
	## out at the start is never written here.
	if amount <= 0:
		return
	if not unit.get("stats", null) is Dictionary:
		unit.stats = {}
	unit.stats.earned = int(unit.stats.get("earned", 0)) + amount

static func assay_rate() -> int:
	return maxi(1, int(DeepContent.constant("assay_rate", 5)))

static func assay(player_result: Dictionary, outcome: String) -> Dictionary:
	## What the assayer at the lift weighs out of a player's pocket and pays for it. Only a
	## party that rides up is paid, and only for pyrite earned down there: the purse a deeper
	## mine hands out at the start is never cashed, however little of it was spent.
	var carried: int = maxi(0, int(player_result.get("ore", 0)))
	if not outcome in ["extracted", "conquered"]:
		return {"carried": carried, "pyrite": 0, "gold": 0}
	var weighed: int = mini(carried, maxi(0, int(player_result.get("earned", 0))))
	var gold: int = weighed / assay_rate()
	return {"carried": carried, "pyrite": gold * assay_rate(), "gold": gold}

static func conquest_purse(mine_key: String) -> int:
	## The one-off purse for beating a mine's final boss the first time.
	return maxi(0, int(DeepContent.mine(mine_key).get("first_conquest_gold", 0)))

# --- commissions ------------------------------------------------------------------------------

const NEEDS: Array = ["carat", "cut", "pure", "included"]

static func commission_slots() -> int:
	return maxi(0, int(DeepContent.constant("commission_slots", 3)))

static func commission_pool(profile: Dictionary) -> Array:
	## Every skill the rock of an open mine can hold, opals aside: what a commission may ask
	## for, whether or not the player has ever seen one.
	var found: Dictionary = {}
	for key in DeepProfile.unlocked_mines(profile):
		for skill in DeepForge.skill_pool(DeepContent.mine(str(key))):
			if str(DeepContent.skill(str(skill)).get("color", "")) != DeepContent.OPAL:
				found[str(skill)] = true
	var out: Array = found.keys()
	out.sort()
	return out

static func where_found(skill: String) -> Array:
	## The mines whose rock holds a skill: the mine whose batch it is in and every mine below.
	var tier: int = int(DeepForge.batch_tiers().get(skill, 1))
	return DeepContent.mines_in_order().filter(func(k: Variant) -> bool: return DeepContent.mine_tier(str(k)) >= tier)

static func _taken(list: Array) -> Array:
	return list.map(func(c: Dictionary) -> String: return str(c.get("skill", "")))

static func _new_commission(profile: Dictionary, date: String, taken: Array) -> Dictionary:
	## One commission, drawn from a stream of its own for this player and this day, so a day
	## always offers the same ones however often the game is opened.
	var pool: Array = commission_pool(profile).filter(func(k: String) -> bool: return not taken.has(k))
	if pool.is_empty():
		pool = commission_pool(profile)
	if pool.is_empty():
		return {}
	var daily: Dictionary = profile.daily
	daily.seq = int(daily.get("seq", 0)) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%d" % [str(profile.get("id", "")), date, int(daily.seq)])
	var skill: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	var need: Dictionary = {}
	if rng.randf() * 100.0 < float(DeepContent.constant("commission_requirement_pct", 50)):
		var kind: String = str(NEEDS[rng.randi_range(0, NEEDS.size() - 1)])
		match kind:
			"carat":
				var band: Dictionary = DeepForge.carat_band(DeepContent.mine(str(where_found(skill)[0])), 1)
				var soft: int = int(band.get("soft", 5))
				need = {"kind": "carat", "value": rng.randi_range(maxi(2, soft - 2), maxi(2, soft))}
			"cut":
				need = {"kind": "cut", "value": rng.randi_range(1, 3)}
			"pure":
				need = {"kind": "pure", "value": DeepContent.clear_index() + 1}
			"included":
				need = {"kind": "included", "value": 1}
	return {"id": "c%s_%d" % [date.replace("-", ""), int(daily.seq)], "skill": skill, "need": need, "reward": base_reward(skill, need), "done": false}

static func weakest(skill: String, need: Dictionary) -> Dictionary:
	## The least stone that would meet a commission: what its price is reckoned from.
	var clear: int = DeepContent.clear_index()
	var carat: int = 3
	var cut: int = 1
	var clarity: int = clear
	match str(need.get("kind", "")):
		"carat": carat = int(need.value)
		"cut": cut = int(need.value)
		"pure": clarity = int(need.value)
		"included": clarity = clear - 1
	return DeepStone.make(skill, carat, cut, clarity, [], {}, "weakest")

static func base_reward(skill: String, need: Dictionary) -> int:
	## A commission pays well over what the least stone that meets it would sell for.
	var worth: float = float(DeepStone.value(weakest(skill, need))) * float(DeepContent.constant("commission_payout_mult", 2.5))
	return maxi(5, int(round(worth / 5.0)) * 5)

static func payout(commission: Dictionary, stone: Dictionary) -> int:
	## What turning this stone in pays: the commission's price, or a quarter more than the
	## stone would sell for if it is finer than that. Turning in always beats selling.
	return maxi(int(commission.get("reward", 0)), int(ceil(float(DeepStone.value(stone)) * 1.25)))

static func meets(commission: Dictionary, stone: Dictionary) -> bool:
	if bool(commission.get("done", false)) or stone.is_empty():
		return false
	if not bool(stone.get("appraised", false)) or DeepStone.is_fragile(stone) or DeepStone.is_birthstone(stone):
		return false
	if str(stone.get("skill", "")) != str(commission.get("skill", "")):
		return false
	var need: Dictionary = commission.get("need", {})
	match str(need.get("kind", "")):
		"carat": return int(stone.get("carat", 0)) >= int(need.value)
		"cut": return int(stone.get("cut", 0)) >= int(need.value)
		"pure": return int(stone.get("clarity", 0)) >= int(need.value)
		"included": return not stone.get("inclusions", []).is_empty()
	return true

static func need_text(need: Dictionary) -> String:
	match str(need.get("kind", "")):
		"carat": return "%d carats or more" % int(need.value)
		"cut": return "%s cut or better" % DeepContent.cut_name(int(need.value))
		"pure": return "%s or purer" % DeepContent.clarity_name(int(need.value))
		"included": return "with at least one inclusion"
	return ""

static func open_commissions(profile: Dictionary) -> Array:
	return profile.get("daily", {}).get("commissions", []).filter(func(c: Dictionary) -> bool: return not bool(c.get("done", false)))

static func commission_for(profile: Dictionary, stone: Dictionary) -> Dictionary:
	## The best-paying open commission this stone meets, or {}.
	var best: Dictionary = {}
	for commission in open_commissions(profile):
		if meets(commission, stone) and (best.is_empty() or payout(commission, stone) > payout(best, stone)):
			best = commission
	return best

static func ready_count(profile: Dictionary) -> int:
	## How many open commissions a stone on the tray could fill right now.
	var count: int = 0
	for commission in open_commissions(profile):
		if profile.get("tray", []).any(func(s: Dictionary) -> bool: return meets(commission, s)):
			count += 1
	return count

static func turn_in(profile: Dictionary, stone_id: String, commission_id: String) -> Dictionary:
	## Hands a stone from the tray over for a commission. The stone is gone; its skill stays
	## seen; the slot stays filled until tomorrow.
	var stone: Dictionary = {}
	var at: int = -1
	var tray: Array = profile.get("tray", [])
	for index in range(tray.size()):
		if str(tray[index].get("id", "")) == stone_id:
			stone = tray[index]
			at = index
	if stone.is_empty():
		return {"ok": false, "error": "no such stone on the tray"}
	var commission: Dictionary = {}
	for candidate in open_commissions(profile):
		if str(candidate.get("id", "")) == commission_id:
			commission = candidate
	if commission.is_empty():
		return {"ok": false, "error": "no such commission open"}
	if not meets(commission, stone):
		return {"ok": false, "error": "that stone does not meet the commission"}
	var paid: int = payout(commission, stone)
	tray.remove_at(at)
	profile.gold = int(profile.get("gold", 0)) + paid
	commission.done = true
	commission.paid = paid
	DeepProfile.saw(profile, str(stone.get("skill", "")))
	if profile.has("records"):
		profile.records.commissions = int(profile.records.get("commissions", 0)) + 1
	return {"ok": true, "paid": paid, "stone": stone}

static func reroll_price(profile: Dictionary) -> int:
	## The first reroll of a day is free; each after it costs more than the last.
	var used: int = int(profile.get("daily", {}).get("rerolls", 0))
	if used <= 0:
		return 0
	return int(DeepContent.constant("commission_reroll_gold", 10)) + int(DeepContent.constant("commission_reroll_step", 10)) * (used - 1)

static func reroll(profile: Dictionary, commission_id: String) -> Dictionary:
	## Swaps an open commission for a new one, for a different skill.
	var list: Array = profile.get("daily", {}).get("commissions", [])
	var at: int = -1
	for index in range(list.size()):
		if str(list[index].get("id", "")) == commission_id and not bool(list[index].get("done", false)):
			at = index
	if at < 0:
		return {"ok": false, "error": "no such commission open"}
	var price: int = reroll_price(profile)
	if int(profile.get("gold", 0)) < price:
		return {"ok": false, "error": "a new commission costs %d gold" % price}
	var made: Dictionary = _new_commission(profile, str(profile.daily.get("date", today())), _taken(list))
	if made.is_empty():
		return {"ok": false, "error": "there is nothing else to ask for"}
	profile.gold = int(profile.gold) - price
	profile.daily.rerolls = int(profile.daily.get("rerolls", 0)) + 1
	list[at] = made
	return {"ok": true, "paid": price, "commission": made}
