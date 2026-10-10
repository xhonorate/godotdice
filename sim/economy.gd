class_name DeepEconomy
extends RefCounted
## Gold at home: what the workshop charges and pays between runs (docs/GOLD.md). The fare
## down to a deeper mine and the insurance on a haul, sockets bought for a lapidary for good,
## the pyrite weighed into gold at the lift, a purse for the first conquest of each mine, the
## commissions, the shop's Geodes, contracts that trade five stones up for one, and the daily
## dig everyone plays from the same seed.
##
## Every price is read from the pack. Nothing here makes a kept stone better: gold buys a
## way down, protection, sockets and new chances at stones; a commission takes a stone away
## for its price, and a contract takes five for one.

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
		daily.shelf = []
		changed = true
	if not daily.get("commissions", null) is Array:
		daily.commissions = []
	while daily.commissions.size() < commission_slots():
		var made: Dictionary = _new_commission(profile, date, _taken(daily.commissions))
		if made.is_empty():
			break
		daily.commissions.append(made)
		changed = true
	## The shop's shelf is stocked once a day: a profile from before the shop gets today's on
	## the spot, and so does one with no mine open yet once it has one.
	if not daily.get("shelf", null) is Array or daily.shelf.is_empty():
		daily.shelf = _roll_shelf(profile, date)
		changed = changed or not daily.shelf.is_empty()
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
	## The daily dig costs nothing to go down: the seam, the lapidary and the rail are lent.
	if not fresh_run(run) or not run.get("daily", {}).is_empty():
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

# --- the shop: geodes -------------------------------------------------------------------------
##
## Three Geodes on the shelf a day (docs/GOLD.md §3.3): one of an open mine's rock, one of a
## single color from the deepest open mine, and the week's featured set. Each holds one stone,
## rolled with the shelf, finer than the rock usually gives: heavier, and cut and cleared with
## more luck behind it. Buying one cracks it at once and puts the stone on the tray already
## read, so the reel that shows it is only the showing: quitting half-way loses nothing.

const GEODE_KINDS: Array = ["mine", "color", "featured"]
## A Geode's odds, worked out once a session per recipe: the skills it can hold and how
## likely each is, how its stones grade, and what one is worth on average.
static var _odds: Dictionary = {}

static func shelf(profile: Dictionary) -> Array:
	return profile.get("daily", {}).get("shelf", [])

static func geode_luck() -> float:
	return float(DeepContent.constant("geode_luck", 4))

static func geode_opal_pct() -> float:
	return float(DeepContent.constant("geode_opal_pct", 1))

static func featured_sets() -> Array:
	var found: Variant = DeepContent.section("geodes").get("featured", [])
	return found if found is Array else []

static func day_number(date: String) -> int:
	## Days since the first of January 1970 for a "YYYY-MM-DD" day, the count the weekly
	## featured set and the daily dig turn over on.
	return int(floor(float(Time.get_unix_time_from_datetime_string(date + "T00:00:00")) / 86400.0))

static func featured_set(date: String) -> Dictionary:
	## The week's featured set: the sets take turns, a week each, the same for everyone.
	var sets: Array = featured_sets()
	if sets.is_empty():
		return {}
	return sets[posmod(day_number(date) / 7, sets.size())]

static func featured_days_left(date: String) -> int:
	## How many days the week's featured set has left on the shelf, today included.
	return 7 - posmod(day_number(date), 7)

static func _featured(key: String) -> Dictionary:
	for entry in featured_sets():
		if entry is Dictionary and str(entry.get("key", "")) == key:
			return entry
	return {}

static func geode_mine(geode: Dictionary) -> Dictionary:
	var key: String = str(geode.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(key).duplicate()
	mine.key = key
	return mine

static func geode_pool(geode: Dictionary) -> Array:
	## The skills a Geode can hold, opals aside: its mine's rock, narrowed to one color for a
	## Color Geode and to the week's set for the featured one.
	var pool: Array = DeepForge.skill_pool(geode_mine(geode)).filter(func(k: String) -> bool:
		return str(DeepContent.skill(k).get("color", "")) != DeepContent.OPAL and not DeepContent.is_transcendent(k))
	var theme: String = str(geode.get("theme", ""))
	match str(geode.get("kind", "mine")):
		"color":
			pool = pool.filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == theme)
		"featured":
			var listed: Array = _featured(theme).get("skills", [])
			pool = pool.filter(func(k: String) -> bool: return listed.has(k))
	return pool

static func geode_band(geode: Dictionary) -> Dictionary:
	## The carats a Geode's stone can weigh: from its mine's usual top to past the mine's cap.
	var band: Dictionary = DeepForge.carat_band(geode_mine(geode), 1)
	var low: int = int(band.get("soft", 5))
	var high: int = mini(int(band.get("cap", 7)) + int(DeepContent.constant("geode_carat_over_cap", 2)), DeepStone.carat_max())
	return {"low": low, "high": maxi(low, high), "cap": int(band.get("cap", 7))}

static func roll_geode_carat(rng: RandomNumberGenerator, band: Dictionary) -> int:
	## The mine's usual top at the least, and each carat past it half as likely as the one before.
	var carat: int = int(band.get("low", 1))
	var keep: float = float(DeepContent.constant("geode_carat_keep", 50))
	while carat < int(band.get("high", carat)) and DeepRng.chance(rng, keep):
		carat += 1
	return carat

static func roll_geode_stone(rng: RandomNumberGenerator, geode: Dictionary, stone_id: String) -> Dictionary:
	## One stone out of a Geode: the skill from its pool (or, rarely, an opal), cut and
	## cleared at the bottom of its mine with the Geode's luck on top, never Void, and as
	## heavy as `geode_band` allows.
	var mine: Dictionary = geode_mine(geode)
	var opal: bool = DeepRng.chance(rng, geode_opal_pct()) and not DeepForge.opal_pool().is_empty()
	var pool: Array = DeepForge.opal_pool() if opal else geode_pool(geode)
	var provenance: Dictionary = {"source": "geode", "geode": str(geode.get("kind", "mine")), "mine": str(mine.key)}
	var stone: Dictionary = {}
	for _try in range(12):
		stone = DeepForge.roll_stone(rng, mine, 20, geode_luck(), provenance, stone_id, pool)
		if not DeepStone.is_fragile(stone):
			break
	stone.inclusions = _sound(stone.get("inclusions", []))
	stone.carat = roll_geode_carat(rng, geode_band(geode))
	return stone

static func _sound(inclusions: Array) -> Array:
	## What is frozen inside, less anything that would make the stone too fragile to leave
	## the bench: a Void stone shatters at home.
	return inclusions.filter(func(k: Variant) -> bool:
		return not DeepContent.inclusion(str(k)).get("modifiers", []).any(func(m: Variant) -> bool: return m is Dictionary and str(m.get("kind", "")) == "fragile"))

static func geode_odds(geode: Dictionary) -> Dictionary:
	## What a Geode can hold and how likely each thing is: every skill with its share, the opal
	## chance, the share of each grade (by sampling the Geode four hundred times), the carats,
	## and what one is worth on average. The shelf prints all of it: every gamble shows its odds.
	var key: String = "%s:%s:%s" % [str(geode.get("kind", "")), str(geode.get("theme", "")), str(geode.get("mine", ""))]
	if _odds.has(key):
		return _odds[key]
	var mine: Dictionary = geode_mine(geode)
	var table: Dictionary = DeepForge.skill_table(mine, geode_pool(geode))
	var total: float = 0.0
	for skill in table:
		total += float(table[skill])
	var opal_share: float = geode_opal_pct() / 100.0 if not DeepForge.opal_pool().is_empty() else 0.0
	var skills: Array = []
	for skill in table:
		skills.append([str(skill), (1.0 - opal_share) * float(table[skill]) / maxf(total, 0.0001)])
	skills.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]) if not is_equal_approx(float(a[1]), float(b[1])) else str(a[0]) < str(b[0]))
	var tiers: Dictionary = {}
	for tier in DeepStone.TIERS:
		tiers[tier] = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("odds:" + key)
	var samples: int = 400
	var worth: float = 0.0
	for _i in range(samples):
		var stone: Dictionary = roll_geode_stone(rng, geode, "odds")
		tiers[str(DeepStone.grade(stone).tier)] += 1.0 / float(samples)
		worth += float(DeepStone.value(stone))
	var band: Dictionary = geode_band(geode)
	var out: Dictionary = {"skills": skills, "opals": DeepForge.opal_pool(), "opal": opal_share, "tiers": tiers,
		"worth": worth / float(samples), "carat": [int(band.low), int(band.high)], "cap": int(band.cap)}
	_odds[key] = out
	return out

static func geode_price(geode: Dictionary) -> int:
	## Well over what a Geode's stone sells for on average (`geode_price_mult` of it), so
	## cracking Geodes to sell what is inside always loses gold, and never under the mine's
	## own floor. Rounded to ten.
	var worth: float = float(geode_odds(geode).worth) * float(DeepContent.constant("geode_price_mult", 1.75))
	var floor_price: int = int(DeepContent.mine(str(geode.get("mine", ""))).get("geode_gold", 0))
	return maxi(floor_price, int(ceil(worth / 10.0)) * 10)

static func _roll_shelf(profile: Dictionary, date: String) -> Array:
	## The day's three Geodes, the same however often the game is opened: each one's stone is
	## rolled now and kept with it, so cracking it only shows what was already there.
	var open: Array = DeepProfile.unlocked_mines(profile)
	if open.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:shelf" % [str(profile.get("id", "")), date])
	var deepest: String = str(open.back())
	var any_mine: String = str(open[rng.randi_range(0, open.size() - 1)])
	var color: String = str(DeepContent.color_KEYS[rng.randi_range(0, DeepContent.color_KEYS.size() - 1)])
	var plans: Array = [{"kind": "mine", "theme": any_mine, "mine": any_mine}, {"kind": "color", "theme": color, "mine": deepest}]
	var featured: Dictionary = featured_set(date)
	var third: Dictionary = {"kind": "featured", "theme": str(featured.get("key", "")), "mine": deepest}
	## The week's set is only offered when enough of it is in reach of the mines open.
	if featured.is_empty() or geode_pool(third).size() < 3:
		third = {"kind": "mine", "theme": deepest, "mine": deepest}
	plans.append(third)
	var out: Array = []
	for index in range(plans.size()):
		var geode: Dictionary = plans[index]
		geode.id = "g%s_%d" % [date.replace("-", ""), index]
		geode.stone = roll_geode_stone(rng, geode, "%s_%s" % [str(profile.get("id", "")).right(4), geode.id])
		geode.price = geode_price(geode)
		geode.bought = false
		out.append(geode)
	return out

static func open_geode(profile: Dictionary, geode_id: String) -> Dictionary:
	## Buys a Geode off the shelf and cracks it: the gold is taken, the stone goes on the tray
	## already read, and the Geode stays on the shelf, open, until tomorrow.
	var geode: Dictionary = {}
	for candidate in shelf(profile):
		if str(candidate.get("id", "")) == geode_id:
			geode = candidate
	if geode.is_empty():
		return {"ok": false, "error": "no such Geode on the shelf"}
	if bool(geode.get("bought", false)):
		return {"ok": false, "error": "that Geode is already open"}
	var price: int = int(geode.get("price", 0))
	if int(profile.get("gold", 0)) < price:
		return {"ok": false, "error": "that Geode costs %d gold" % price}
	profile.gold = int(profile.gold) - price
	geode.bought = true
	var stone: Dictionary = geode.get("stone", {}).duplicate(true)
	stone.appraised = true
	stone.inclusions_revealed = true
	if not stone.get("provenance", null) is Dictionary:
		stone.provenance = {}
	stone.provenance.date = today()
	profile.tray.append(stone)
	DeepProfile.saw(profile, str(stone.get("skill", "")))
	if profile.has("records"):
		profile.records.geodes = int(profile.records.get("geodes", 0)) + 1
	return {"ok": true, "paid": price, "stone": stone, "geode": geode}

# --- contracts ---------------------------------------------------------------------------------
##
## Five read stones of one grade go in, one stone of the next grade comes out (docs/GOLD.md
## §3.4). Its color is drawn from the five's colors, its skill from the deepest of their mines'
## rock, its carat is their average, and its Cut, Clarity and inclusions are rolled until the
## grade lands where the contract promised. There is no fail state: the gamble is what comes
## out, never whether something does.

const CONTRACT_TIERS: Array = ["ROUGH", "FINE", "PRECIOUS", "EXQUISITE"]

static func contract_size() -> int:
	return maxi(1, int(DeepContent.constant("contract_inputs", 5)))

static func contract_fee(tier: String) -> int:
	return int(DeepContent.constant("contract_fee", {}).get(tier, 0))

static func next_tier(tier: String) -> String:
	var at: int = DeepStone.TIERS.find(tier)
	return str(DeepStone.TIERS[at + 1]) if at >= 0 and at + 1 < DeepStone.TIERS.size() else ""

static func tier_floor(tier: String) -> int:
	## The least grade a tier takes; 0 for Rough, 101 past Peerless.
	if tier == "ROUGH":
		return 0
	if tier.is_empty():
		return 101
	return int(DeepContent.constant("grade_thresholds", {}).get(tier, 101))

static func contract_refusal(stone: Dictionary) -> String:
	## Why a stone cannot go into a contract, or "".
	if stone.is_empty():
		return "no such stone"
	if not bool(stone.get("appraised", false)):
		return "its grade is not known yet: appraise it first"
	if DeepStone.is_birthstone(stone):
		return "a Birthstone belongs to its lapidary"
	if DeepStone.is_fragile(stone):
		return "a fragile stone cannot be traded"
	if DeepStone.is_transcendent(stone):
		return "a Transcendent is made at an altar, never traded"
	if DeepStone.is_opal(stone):
		return "an opal cannot be traded up"
	if not CONTRACT_TIERS.has(str(DeepStone.grade(stone).tier)):
		return "a Peerless stone is as fine as a grade goes"
	return ""

static func contract_stones(profile: Dictionary) -> Array:
	## Everything that could go into a contract: the tray's read stones, then the vault's, each
	## as {ref, stone, vault}. A ref names a tray stone by its id ("t:...") and a vault stone by
	## its skill ("v:..."), since the vault keeps one of each.
	var out: Array = []
	for stone in profile.get("tray", []):
		if contract_refusal(stone).is_empty():
			out.append({"ref": "t:%s" % str(stone.get("id", "")), "stone": stone, "vault": false})
	var keys: Array = profile.get("vault", {}).keys()
	keys.sort()
	for skill in keys:
		var stone: Dictionary = profile.vault[skill]
		if contract_refusal(stone).is_empty():
			out.append({"ref": "v:%s" % str(skill), "stone": stone, "vault": true})
	return out

static func contract_input(profile: Dictionary, ref: String) -> Dictionary:
	if ref.begins_with("t:"):
		for stone in profile.get("tray", []):
			if "t:%s" % str(stone.get("id", "")) == ref:
				return {"ref": ref, "stone": stone, "vault": false}
	elif ref.begins_with("v:"):
		var stone: Dictionary = profile.get("vault", {}).get(ref.substr(2), {})
		if not stone.is_empty():
			return {"ref": ref, "stone": stone, "vault": true}
	return {}

static func stone_mine(stone: Dictionary) -> String:
	## The mine a stone came out of; the starter mine when it does not say (a starter stone).
	var key: String = str(stone.get("provenance", {}).get("mine", ""))
	return key if not DeepContent.mine(key).is_empty() else DeepContent.starter_mine()

static func best_grade(carat: int, skill: String) -> int:
	## The finest grade a stone of this carat and skill can reach: a Perfect cut and an
	## Intricate clarity full of the rarest inclusions on top of what the carat is worth.
	var probe: Dictionary = DeepStone.make(skill, carat, DeepPatterns.STEPS - 1, DeepContent.clear_index(), [], {}, "probe")
	var breakdown: Dictionary = DeepStone.grade_breakdown(probe)
	return int(round(float(breakdown.carat_pts) + float(breakdown.cut_pts) + 20.0 + 15.0 + float(breakdown.skill_pts)))

static func contract_preview(profile: Dictionary, refs: Array) -> Dictionary:
	## What a contract with these stones in it would do: the grade going in and the one coming
	## out, the odds of each color, the carat, the mine whose rock it is rolled in, the fee, and
	## whether it can be signed (`ready`), and why not (`reason`).
	var out: Dictionary = {"ok": true, "error": "", "count": 0, "needed": contract_size(), "tier": "", "next": "", "colors": {}, "carat": 0,
		"mine": "", "fee": 0, "feasible": true, "reason": "", "vault": [], "pool": {}, "ready": false, "stones": []}
	var stones: Array = []
	for ref in refs:
		var input: Dictionary = contract_input(profile, str(ref))
		if input.is_empty():
			out.ok = false
			out.error = "a stone in the contract is gone"
			return out
		var refusal: String = contract_refusal(input.stone)
		if not refusal.is_empty():
			out.ok = false
			out.error = refusal
			return out
		stones.append(input.stone)
		if bool(input.vault):
			out.vault.append(str(input.stone.get("skill", "")))
	out.count = stones.size()
	out.stones = stones
	if stones.is_empty():
		out.reason = "Put in %d stones of one grade." % contract_size()
		return out
	var tier: String = str(DeepStone.grade(stones[0]).tier)
	for stone in stones:
		if str(DeepStone.grade(stone).tier) != tier:
			out.ok = false
			out.error = "every stone in a contract must be of one grade"
			return out
	out.tier = tier
	out.next = next_tier(tier)
	out.fee = contract_fee(tier)
	## The deepest mine any of the five came out of is the rock the new one is rolled in.
	var mine_key: String = stone_mine(stones[0])
	var depth: int = 1
	for stone in stones:
		var key: String = stone_mine(stone)
		if DeepContent.mine_tier(key) > DeepContent.mine_tier(mine_key):
			mine_key = key
	for stone in stones:
		if stone_mine(stone) == mine_key:
			depth = maxi(depth, int(stone.get("provenance", {}).get("depth", 1)))
	out.mine = mine_key
	var total: int = 0
	var counts: Dictionary = {}
	for stone in stones:
		total += int(stone.get("carat", 1))
		var color: String = DeepStone.color(stone)
		counts[color] = int(counts.get(color, 0)) + 1
	var mine: Dictionary = DeepContent.mine(mine_key).duplicate()
	mine.key = mine_key
	out.carat = mini(int(round(float(total) / float(stones.size()))), DeepForge.carat_cap(mine, depth))
	## Each color's share, from the skills of that color the rock can give that can reach the
	## grade promised at this carat. A color with none of them is struck out.
	var pool: Array = DeepForge.skill_pool(mine).filter(func(k: String) -> bool:
		return str(DeepContent.skill(k).get("color", "")) != DeepContent.OPAL and not DeepContent.is_transcendent(k))
	var need: int = tier_floor(str(out.next))
	var counted: int = 0
	for color in counts:
		var reachable: Array = pool.filter(func(k: String) -> bool:
			return str(DeepContent.skill(k).get("color", "")) == str(color) and best_grade(int(out.carat), k) >= need)
		if reachable.is_empty():
			continue
		out.pool[color] = reachable
		counted += int(counts[color])
	for color in out.pool:
		out.colors[color] = float(counts[color]) / float(maxi(1, counted))
	if out.colors.is_empty():
		out.feasible = false
		out.reason = "At %d carats nothing from these colors can reach %s. Use heavier stones." % [int(out.carat), DeepStone.TIER_NAMES.get(str(out.next), str(out.next))]
	elif stones.size() < contract_size():
		out.reason = "%d more %s %s." % [contract_size() - stones.size(), DeepStone.TIER_NAMES.get(tier, tier), "stone" if contract_size() - stones.size() == 1 else "stones"]
	elif int(profile.get("gold", 0)) < int(out.fee):
		out.reason = "The fee is %d gold." % int(out.fee)
	out.ready = out.ok and out.feasible and stones.size() == contract_size() and int(profile.get("gold", 0)) >= int(out.fee)
	return out

static func contract_odds(preview: Dictionary) -> Array:
	## Every skill a contract could make and the chance of each, likeliest first, as
	## [skill, share]: a color by the five's shares, then a skill of that color the way the
	## rock gives them, exactly as `roll_contract_stone` draws them.
	var mine_key: String = str(preview.get("mine", ""))
	if mine_key.is_empty():
		return []
	var mine: Dictionary = DeepContent.mine(mine_key).duplicate()
	mine.key = mine_key
	var colors: Dictionary = preview.get("colors", {})
	var out: Array = []
	for color in colors:
		var pool: Array = preview.get("pool", {}).get(color, [])
		if pool.is_empty():
			continue
		var table: Dictionary = DeepForge.skill_table(mine, pool)
		var total: float = 0.0
		for key in table:
			total += float(table[key])
		if total <= 0.0:
			continue
		for key in table:
			out.append([str(key), float(colors[color]) * float(table[key]) / total])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[1]), float(b[1])):
			return float(a[1]) > float(b[1])
		return str(a[0]) < str(b[0]))
	return out

static func roll_contract_stone(rng: RandomNumberGenerator, preview: Dictionary, stone_id: String) -> Dictionary:
	## The stone a contract makes: a color drawn by the five's shares, a skill from that color in
	## the rock, the five's carat, and a Cut, Clarity and inclusions drawn again, with more luck
	## each time, until the grade lands in the tier promised. If luck alone never gets there the
	## stone is worked up a step at a time, which the contract's feasibility says is possible.
	var mine_key: String = str(preview.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(mine_key).duplicate()
	mine.key = mine_key
	var colors: Dictionary = preview.get("colors", {})
	var weights: Dictionary = {}
	for color in colors:
		weights[color] = float(colors[color])
	var color: String = DeepRng.weighted_key(rng, weights)
	var skill: String = DeepForge.roll_skill(rng, mine, preview.get("pool", {}).get(color, []))
	var carat: int = int(preview.get("carat", 1))
	var lower: int = tier_floor(str(preview.get("next", "")))
	var upper: int = tier_floor(next_tier(str(preview.get("next", ""))))
	var provenance: Dictionary = {"source": "contract", "mine": mine_key, "depth": 20, "tier": str(preview.get("next", ""))}
	var best: Dictionary = {}
	var best_gap: float = INF
	for attempt in range(48):
		var q: float = DeepForge.luck(mine, 20, float(attempt) * 2.5)
		var clarity: int = DeepForge.roll_clarity(rng, q)
		var stone: Dictionary = DeepStone.make(skill, carat, DeepForge.roll_cut(rng, q), clarity,
			_sound(DeepForge.roll_inclusions(rng, DeepStone.inclusion_slots(clarity), mine, "", color)), provenance, stone_id)
		var score: int = int(DeepStone.grade(stone).score)
		if score >= lower and score < upper:
			return _read(stone)
		## Short of the promise is worse than past it: a stone of the tier above would only be a
		## kinder surprise, and one past it is kept only if nothing lands in the tier itself.
		var gap: float = float(lower - score) * 2.0 if score < lower else float(score - upper + 1)
		if gap < best_gap:
			best_gap = gap
			best = stone
	if int(DeepStone.grade(best).score) < lower:
		best = _worked_up(best, lower, mine)
	return _read(best)

static func _read(stone: Dictionary) -> Dictionary:
	stone.appraised = true
	stone.inclusions_revealed = true
	return stone

static func _worked_up(stone: Dictionary, lower: int, mine: Dictionary) -> Dictionary:
	## A stone raised a step at a time until it reaches `lower`: Cut first, then Clarity out
	## toward Intricate, then the rarest inclusions the rock can freeze into it.
	var own: String = DeepStone.color(stone)
	var best_inclusions: Array = DeepForge.inclusion_pool(mine).filter(func(k: String) -> bool:
		return _sound([k]).size() == 1 and DeepForge.zoning_color(DeepContent.inclusion(k)) != own)
	best_inclusions.sort_custom(func(a: String, b: String) -> bool:
		return float(DeepStone.INCLUSION_SCORE.get(str(DeepContent.inclusion(a).get("rarity", "COMMON")), 2.0)) > float(DeepStone.INCLUSION_SCORE.get(str(DeepContent.inclusion(b).get("rarity", "COMMON")), 2.0)))
	for _step in range(24):
		if int(DeepStone.grade(stone).score) >= lower:
			break
		if int(stone.cut) < DeepPatterns.STEPS - 1:
			stone.cut = int(stone.cut) + 1
			continue
		if int(stone.clarity) != 0:
			## Toward Intricate, the end of the ladder that also has room for inclusions.
			stone.clarity = 0 if int(stone.clarity) > DeepContent.clear_index() else int(stone.clarity) - 1
			var slots: int = DeepStone.inclusion_slots(int(stone.clarity))
			var inside: Array = stone.get("inclusions", []).duplicate()
			for key in best_inclusions:
				if inside.size() >= slots:
					break
				if not inside.has(key):
					inside.append(key)
			stone.inclusions = inside.slice(0, slots)
			continue
		## Intricate already: the plainest thing inside gives way to the rarest one missing.
		var inside: Array = stone.get("inclusions", []).duplicate()
		var swapped: bool = false
		for key in best_inclusions:
			if inside.has(key):
				continue
			var weakest: int = -1
			for i in range(inside.size()):
				if weakest < 0 or float(DeepStone.INCLUSION_SCORE.get(str(DeepContent.inclusion(str(inside[i])).get("rarity", "COMMON")), 2.0)) < float(DeepStone.INCLUSION_SCORE.get(str(DeepContent.inclusion(str(inside[weakest])).get("rarity", "COMMON")), 2.0)):
					weakest = i
			if weakest < 0:
				inside.append(key)
			else:
				inside[weakest] = key
			swapped = true
			break
		stone.inclusions = inside
		if not swapped:
			break
	return stone

static func sign_contract(profile: Dictionary, refs: Array) -> Dictionary:
	## Signs a contract: the fee is taken, the five stones are gone (a vault stone's skill is
	## no longer kept, and every loadout that set it lets it go), and the new stone waits on
	## the tray already read.
	var preview: Dictionary = contract_preview(profile, refs)
	if not bool(preview.ok):
		return {"ok": false, "error": str(preview.error)}
	if not bool(preview.ready):
		return {"ok": false, "error": str(preview.reason)}
	var unique: Dictionary = {}
	for ref in refs:
		unique[str(ref)] = true
	if unique.size() != refs.size():
		return {"ok": false, "error": "a stone can only go into a contract once"}
	var stone_id: String = DeepProfile._id(profile, "st")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:contract:%s" % [str(profile.get("id", "")), stone_id, ",".join(refs)])
	var made: Dictionary = roll_contract_stone(rng, preview, stone_id)
	made.provenance.date = today()
	profile.gold = int(profile.get("gold", 0)) - int(preview.fee)
	var given: Array = []
	for ref in refs:
		var input: Dictionary = contract_input(profile, str(ref))
		given.append(input.stone.duplicate(true))
		if bool(input.vault):
			var skill: String = str(input.stone.get("skill", ""))
			profile.vault.erase(skill)
			for key in profile.get("characters", {}):
				var rail: Array = profile.characters[key].get("rail", [])
				for i in range(rail.size()):
					if rail[i] is String and str(rail[i]) == skill:
						rail[i] = null
		else:
			var tray: Array = profile.get("tray", [])
			for i in range(tray.size() - 1, -1, -1):
				if str(tray[i].get("id", "")) == str(input.stone.get("id", "")):
					tray.remove_at(i)
	profile.tray.append(made)
	DeepProfile.saw(profile, str(made.get("skill", "")))
	if profile.has("records"):
		profile.records.contracts = int(profile.records.get("contracts", 0)) + 1
	return {"ok": true, "stone": made, "given": given, "paid": int(preview.fee), "preview": preview}

# --- the daily dig -----------------------------------------------------------------------------
##
## One seam a day, the same for every player on the same build (docs/GOLD.md §4.2): the seed
## comes from the day and the pack, so nobody needs a server to agree on it. The dig always
## starts at the top of the Quarry and goes on down through every mine into the Rift for as
## long as the party wants. The seed deals the day's cards (a rail rule, a hazard, a blessing
## and a twist, never two cards of one group) and one lapidary for the whole party. Nothing
## found comes home: what each player brings up is scored (their pyrite and the worth of their
## stones) and the score is paid in gold. A later attempt the same day pays only the gold its
## score adds to the day's best.

## Raised whenever what a seed means changes, so two builds that would play a day's seam
## differently never claim to be playing the same one.
const DAILY_RULES: int = 2
## The kinds of card a day is dealt, in the order they are dealt.
const DAILY_KINDS: Array = ["rail", "hazard", "blessing", "twist"]
## How many stones the rail rules that fill the bag put in it.
const SEALED_TRAY_STONES: int = 12
const BIG_HAUL_STONES: int = 15

static func daily_seed(date: String) -> int:
	return hash("deep-cut-daily:%s:%s:%d" % [date, str(DeepContent.pack().get("version", 1)), DAILY_RULES])

static func daily_modifiers(kind: String = "") -> Array:
	## The card keys of one kind ("rail", "hazard", "blessing" or "twist"), sorted, or every one.
	var out: Array = []
	for key in DeepContent.section("daily_modifiers"):
		if kind.is_empty() or str(DeepContent.entry("daily_modifiers", str(key)).get("kind", "")) == kind:
			out.append(str(key))
	out.sort()
	return out

static func daily_mod(key: String) -> Dictionary:
	return DeepContent.entry("daily_modifiers", key)

static func daily_plan(date: String = "") -> Dictionary:
	## What the day's seed decides: {date, seed, mine (the starter mine), lapidary (one for the
	## whole party), rail (the rail rule), mods (the hazard, blessing and twist)}, and what some
	## cards need decided with them: `drought` (the color the rock holds back), `dice` (the bowl
	## on a day of Strangers' Dice), `birthstone` (whose Birthstone is borrowed) and `trick` (the
	## one skill of a One Trick rail).
	if date.is_empty():
		date = today()
	var rng := RandomNumberGenerator.new()
	rng.seed = daily_seed(date)
	var lapidaries: Array = DeepContent.characters_in_unlock_order()
	var lapidary: String = str(lapidaries[rng.randi_range(0, lapidaries.size() - 1)]) if not lapidaries.is_empty() else DeepContent.starter_character()
	var deal: Dictionary = DeepContent.constant("daily_deal", {"rail": 1, "hazard": 1, "blessing": 1, "twist": 1})
	var dealt: Dictionary = {}
	var groups: Array = []
	for kind in DAILY_KINDS:
		var picks: Array = []
		for _n in range(int(deal.get(kind, 0))):
			## Two cards of one group never share a day: they would cancel out or stack into
			## something nobody could dig.
			var table: Dictionary = {}
			for key in daily_modifiers(kind):
				var group: String = str(daily_mod(key).get("group", ""))
				if picks.has(key) or (not group.is_empty() and groups.has(group)):
					continue
				table[key] = maxf(0.0, float(daily_mod(key).get("weight", 1)))
			var picked: String = DeepRng.weighted_key(rng, table)
			if picked.is_empty():
				break
			picks.append(picked)
			var group: String = str(daily_mod(picked).get("group", ""))
			if not group.is_empty():
				groups.append(group)
		dealt[kind] = picks
	var rail: String = str(dealt.rail[0]) if not dealt.get("rail", []).is_empty() else "LENT_RAIL"
	var mods: Array = dealt.get("hazard", []) + dealt.get("blessing", []) + dealt.get("twist", [])
	var plan: Dictionary = {"date": date, "seed": daily_seed(date), "mine": DeepContent.starter_mine(), "lapidary": lapidary, "rail": rail, "mods": mods}
	if mods.has("DROUGHT"):
		plan.drought = str(DeepContent.color_KEYS[rng.randi_range(0, DeepContent.color_KEYS.size() - 1)])
	if mods.has("STRANGERS_DICE"):
		var refs: Array = []
		for key in lapidaries:
			refs.append_array(DeepContent.character(str(key)).get("dice", []))
		var count: int = DeepContent.character(lapidary).get("dice", []).size()
		plan.dice = DeepRng.shuffled(rng, refs).slice(0, maxi(1, count))
	if mods.has("BORROWED_BIRTHSTONE"):
		var others: Array = lapidaries.filter(func(k: Variant) -> bool: return str(k) != lapidary)
		plan.birthstone = str(others[rng.randi_range(0, others.size() - 1)]) if not others.is_empty() else lapidary
	if rail == "ONE_TRICK":
		plan.trick = _trick_skill(rng, lapidary, str(plan.mine))
	return plan

static func _trick_skill(rng: RandomNumberGenerator, lapidary: String, mine_key: String) -> String:
	## The skill a One Trick rail is made of: of the color that fills the most of the lapidary's
	## sockets (an Any socket takes every color), drawn the way the rock draws them.
	var sockets: Array = DeepContent.character(lapidary).get("sockets", [])
	var best: Array = []
	var most: int = -1
	for color in DeepContent.color_KEYS:
		var fits: int = sockets.filter(func(s: Variant) -> bool: return str(s) == str(color) or str(s) == DeepContent.SOCKET_ANY).size()
		if fits > most:
			most = fits
			best = [str(color)]
		elif fits == most:
			best.append(str(color))
	var color: String = str(best[rng.randi_range(0, best.size() - 1)]) if not best.is_empty() else "RED"
	var mine: Dictionary = DeepContent.mine(mine_key).duplicate()
	mine.key = mine_key
	var pool: Array = _lent_pool(mine).filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == color)
	return DeepForge.roll_skill(rng, mine, pool) if not pool.is_empty() else ""

static func daily_lapidary(plan: Dictionary, _seat: int = 0) -> String:
	## Everyone in the party goes down as the day's one lapidary.
	return str(plan.get("lapidary", DeepContent.starter_character()))

static func _lent_pool(mine: Dictionary) -> Array:
	return DeepForge.skill_pool(mine).filter(func(k: String) -> bool:
		return str(DeepContent.skill(k).get("color", "")) != DeepContent.OPAL and not DeepContent.is_transcendent(k))

static func _lent_stone(rng: RandomNumberGenerator, mine: Dictionary, pool: Array, id: String, min_tier: String = "", read: bool = true) -> Dictionary:
	## One stone the day lends: rolled at the bottom of the mine's luck the way a temporary
	## stone is, drawn again until it reaches `min_tier` (Precious unless said otherwise), never
	## fragile in itself, and marked as a loan: fragile, temporary and lent, so it shatters
	## quietly at the end and never scores.
	var depth: int = int(DeepContent.constant("temporary_depth", 20))
	var luck: float = float(DeepContent.constant("temporary_luck", 4))
	var wanted: int = DeepStone.TIERS.find(min_tier if not min_tier.is_empty() else str(DeepContent.constant("temporary_min_tier", "PRECIOUS")))
	var stone: Dictionary = {}
	for attempt in range(16):
		stone = DeepForge.roll_stone(rng, mine, depth, luck + float(attempt) * 2.0, {"source": "daily", "mine": str(mine.get("key", ""))}, id, pool)
		if not DeepStone.is_fragile(stone) and DeepStone.TIERS.find(str(DeepStone.grade(stone).tier)) >= wanted:
			break
	stone.inclusions = _sound(stone.get("inclusions", []))
	stone.appraised = read
	stone.inclusions_revealed = read
	stone.fragile = true
	stone.temporary = true
	stone.lent = true
	return stone

static func daily_rail(plan: Dictionary, character: String, seat: int) -> Array:
	## The rail the day lends a seat, socket by socket (null for an empty one), by the day's rail
	## rule: a lent stone of its color in every socket, the day's one skill wherever it fits, or
	## nothing at all for the rules that fill the bag or offer a draft instead. An Heirloom or a
	## Borrowed Opal is set on top of whatever the rule left.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:rail:%d" % [int(plan.get("seed", 0)), seat])
	var mine_key: String = str(plan.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(mine_key).duplicate()
	mine.key = mine_key
	var pool: Array = _lent_pool(mine)
	var sockets: Array = DeepContent.character(character).get("sockets", [])
	var rail: Array = []
	rail.resize(sockets.size())
	var rule: String = str(plan.get("rail", "LENT_RAIL"))
	var used: Array = []
	for index in range(sockets.size()):
		var socket: String = str(sockets[index])
		var color: String = socket if socket != DeepContent.SOCKET_ANY else str(DeepContent.color_KEYS[rng.randi_range(0, DeepContent.color_KEYS.size() - 1)])
		match rule:
			"LENT_RAIL":
				var of_color: Array = pool.filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == color)
				var fresh: Array = of_color.filter(func(k: String) -> bool: return not used.has(k))
				var choices: Array = fresh if not fresh.is_empty() else (of_color if not of_color.is_empty() else pool)
				rail[index] = _lent_stone(rng, mine, choices, "daily_%d_%d" % [seat, index])
				used.append(str(rail[index].skill))
			"ONE_TRICK":
				var trick: String = str(plan.get("trick", ""))
				if not trick.is_empty() and DeepStone.fits(DeepStone.make(trick, 1, 0, DeepContent.clear_index(), [], {}, "probe"), socket):
					rail[index] = _lent_stone(rng, mine, [trick], "daily_%d_%d" % [seat, index])
	var mods: Array = plan.get("mods", [])
	var any_sockets: Array = []
	for index in range(sockets.size()):
		if str(sockets[index]) == DeepContent.SOCKET_ANY:
			any_sockets.append(index)
	if mods.has("HEIRLOOM") and not sockets.is_empty():
		var at: int = int(any_sockets[0]) if not any_sockets.is_empty() else 0
		var socket: String = str(sockets[at])
		var color: String = socket if socket != DeepContent.SOCKET_ANY else str(DeepContent.color_KEYS[rng.randi_range(0, DeepContent.color_KEYS.size() - 1)])
		var of_color: Array = pool.filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == color)
		rail[at] = _heirloom(rng, mine, of_color if not of_color.is_empty() else pool, "daily_%d_heirloom" % seat)
	if mods.has("BORROWED_OPAL") and not any_sockets.is_empty() and not DeepForge.opal_pool().is_empty():
		var at: int = int(any_sockets[any_sockets.size() - 1])
		rail[at] = _lent_stone(rng, mine, DeepForge.opal_pool(), "daily_%d_opal" % seat, "ROUGH")
	return rail

static func _heirloom(rng: RandomNumberGenerator, mine: Dictionary, pool: Array, id: String) -> Dictionary:
	## An Heirloom: no rock near the top gives up an Exquisite stone, so it is made rather than
	## rolled. A Perfect, Flawless stone of a skill the rock holds, as heavy as Exquisite needs.
	var skill: String = DeepForge.roll_skill(rng, mine, pool)
	var stone: Dictionary = DeepStone.make(skill, 12, DeepPatterns.STEPS - 1, DeepContent.clarities().size() - 1, [], {"source": "daily", "mine": str(mine.get("key", ""))}, id)
	var wanted: int = DeepStone.TIERS.find("EXQUISITE")
	while DeepStone.TIERS.find(str(DeepStone.grade(stone).tier)) < wanted and int(stone.carat) < DeepStone.carat_max():
		stone.carat = int(stone.carat) + 1
	stone.appraised = true
	stone.inclusions_revealed = true
	stone.fragile = true
	stone.temporary = true
	stone.lent = true
	return stone

static func daily_bag(plan: Dictionary, character: String, seat: int) -> Array:
	## What the day puts in a seat's bag before the first floor: a dozen read stones on a day of
	## the Sealed Tray, in the colors of the lapidary's sockets so every socket has a choice; a
	## bag full of raw stones on a day of the Big Haul. All of them lent: none ever scores.
	var rule: String = str(plan.get("rail", ""))
	if not rule in ["SEALED_TRAY", "BIG_HAUL"]:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:bag:%d" % [int(plan.get("seed", 0)), seat])
	var mine_key: String = str(plan.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(mine_key).duplicate()
	mine.key = mine_key
	var pool: Array = _lent_pool(mine)
	var sockets: Array = DeepContent.character(character).get("sockets", [])
	var out: Array = []
	var used: Array = []
	var count: int = SEALED_TRAY_STONES if rule == "SEALED_TRAY" else BIG_HAUL_STONES
	for index in range(count):
		if rule == "BIG_HAUL":
			## Stones as the rock gives them, a little way down: raw, to be read on the way.
			var stone: Dictionary = DeepForge.roll_stone(rng, mine, 12, 2.0, {"source": "daily", "mine": mine_key}, "daily_%d_bag%d" % [seat, index], pool)
			stone.inclusions = _sound(stone.get("inclusions", []))
			stone.appraised = false
			stone.inclusions_revealed = false
			stone.fragile = true
			stone.temporary = true
			stone.lent = true
			out.append(stone)
			continue
		var socket: String = str(sockets[index % sockets.size()]) if not sockets.is_empty() else DeepContent.SOCKET_ANY
		var color: String = socket if socket != DeepContent.SOCKET_ANY else str(DeepContent.color_KEYS[rng.randi_range(0, DeepContent.color_KEYS.size() - 1)])
		var of_color: Array = pool.filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == color)
		var fresh: Array = of_color.filter(func(k: String) -> bool: return not used.has(k))
		var choices: Array = fresh if not fresh.is_empty() else (of_color if not of_color.is_empty() else pool)
		var lent: Dictionary = _lent_stone(rng, mine, choices, "daily_%d_bag%d" % [seat, index], "FINE")
		used.append(str(lent.skill))
		out.append(lent)
	return out

static func daily_dice(plan: Dictionary, character: String, seat: int) -> Array:
	## The bowl a seat goes down with: the lapidary's own dice, or on a day of Strangers' Dice
	## the day's draw from every lapidary's.
	var refs: Array = plan.get("dice", DeepContent.character(character).get("dice", []))
	var dice: Array = []
	for index in range(refs.size()):
		dice.append(DeepForge.die_from(refs[index], "daily_d%d_%d" % [seat, index]))
	return dice

static func daily_config(date: String, players: Array, run_id: String = "") -> Dictionary:
	## The run a party digs today: `players` are lobby members in seat order ({id, name, ...}).
	## Everyone goes down as the day's lapidary, with what the day's rail rule lends and the
	## day's dice, nothing of their own.
	var plan: Dictionary = daily_plan(date)
	var character: String = daily_lapidary(plan)
	var seated: Array = []
	for seat in range(players.size()):
		var member: Dictionary = players[seat]
		seated.append({"id": str(member.get("id", "p%d" % seat)), "name": str(member.get("name", DeepProfile.DEFAULT_NAME)), "character": character,
			"rail": daily_rail(plan, character, seat), "dice": daily_dice(plan, character, seat), "bag": daily_bag(plan, character, seat),
			"sockets": DeepContent.character(character).get("sockets", []).size(), "insured": false, "last_depth": 0, "last_outcome": ""})
	if run_id.is_empty():
		run_id = "daily%s%06x" % [date.replace("-", ""), randi() & 0xffffff]
	var daily: Dictionary = {"date": date, "rail": str(plan.rail), "mods": plan.mods.duplicate()}
	for key in ["drought", "birthstone", "trick"]:
		if plan.has(key):
			daily[key] = plan[key]
	return {"seed": int(plan.seed), "run_id": run_id, "mine": str(plan.mine), "players": seated, "daily": daily}

static func daily_eligible(profile: Dictionary) -> bool:
	## The daily seam pays lapidaries who have beaten the first mine at least once.
	return bool(profile.get("mines", {}).get(DeepContent.starter_mine(), {}).get("boss", false))

static func dig(profile: Dictionary) -> Dictionary:
	## This player's record of their last day at the seam:
	## {date, best_score, best_gold, runs, run_id}.
	var found: Variant = profile.get("dig", {})
	return found if found is Dictionary else {}

static func daily_best(profile: Dictionary, date: String = "") -> Dictionary:
	## The day's best so far: {score, gold, runs}, all nought before the first attempt.
	var record: Dictionary = dig(profile)
	if str(record.get("date", "")) != (date if not date.is_empty() else today()):
		return {"score": 0, "gold": 0, "runs": 0}
	return {"score": int(record.get("best_score", 0)), "gold": int(record.get("best_gold", 0)), "runs": int(record.get("runs", 0))}

static func daily_played(profile: Dictionary, date: String = "") -> bool:
	return int(daily_best(profile, date).runs) > 0

static func daily_state(profile: Dictionary, date: String = "") -> String:
	## "locked" (the Quarry not beaten yet: digging pays nothing), "played" (dug at least once
	## today: another attempt pays only what it adds to the best), or "fresh". What a lobby is
	## told, so the party knows where everyone stands.
	if not daily_eligible(profile):
		return "locked"
	return "played" if daily_played(profile, date) else "fresh"

static func begin_daily(profile: Dictionary, run: Dictionary) -> Dictionary:
	## Each machine notes its own player's attempt when a daily run reaches it, and says what it
	## is up against: {date, again (this run was already noted), eligible, best_score, best_gold}.
	var daily: Dictionary = run.get("daily", {})
	var run_id: String = str(run.get("run_id", ""))
	if daily.is_empty() or run_id.is_empty():
		return {}
	var date: String = str(daily.get("date", ""))
	var record: Dictionary = dig(profile).duplicate()
	if str(record.get("date", "")) != date:
		record = {"date": date, "best_score": 0, "best_gold": 0, "runs": 0, "run_id": ""}
	var again: bool = str(record.get("run_id", "")) == run_id
	if not again:
		record.runs = int(record.get("runs", 0)) + 1
		record.run_id = run_id
	profile.dig = record
	return {"date": date, "again": again, "eligible": daily_eligible(profile), "best_score": int(record.get("best_score", 0)), "best_gold": int(record.get("best_gold", 0))}

static func daily_score(result: Dictionary, player_id: String) -> Dictionary:
	## What one player brought up from the day's seam: the worth of every stone of theirs that
	## came up (never a lent one, never a fragile one) and, unless the party fell, the pyrite in
	## their pocket. A fall scores only what the salvage dice saved.
	var brought: Dictionary = result.get("players", {}).get(player_id, {})
	var fell: bool = str(result.get("outcome", "")) == "fallen"
	var stones: Array = []
	var worth: int = 0
	for stone in brought.get("home", brought.get("haul", [])):
		if not stone is Dictionary or DeepStone.is_fragile(stone) or bool(stone.get("lent", false)):
			continue
		stones.append(stone)
		worth += DeepStone.value(stone)
	var pyrite: int = 0 if fell else maxi(0, int(brought.get("ore", 0)))
	return {"stones": stones, "worth": worth, "pyrite": pyrite, "score": worth + pyrite, "fell": fell}

static func daily_payout(score: int) -> int:
	## The gold a score is worth: `daily_score_rate` of it, and half that rate past
	## `daily_score_knee`, so a very deep run still pays well without paying without end.
	var rate: float = float(DeepContent.constant("daily_score_rate", 0.5))
	var knee: int = int(DeepContent.constant("daily_score_knee", 1000))
	var points: int = maxi(0, score)
	return int(floor(float(mini(points, knee)) * rate + float(maxi(0, points - knee)) * rate * 0.5))

## How many days of daily bests the Ledger keeps.
const DAILY_BESTS_KEPT: int = 30

static func _note_daily_best(profile: Dictionary, date: String, score: int, gold: int) -> void:
	## The Ledger's record of the day's best: one entry a day, the latest month of them, and
	## the best score of all.
	if not profile.has("records"):
		return
	var bests: Array = profile.records.get("daily_bests", []).filter(func(e: Variant) -> bool: return e is Dictionary and str(e.get("date", "")) != date)
	bests.append({"date": date, "score": score, "gold": gold})
	bests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.date) < str(b.date))
	profile.records.daily_bests = bests.slice(maxi(0, bests.size() - DAILY_BESTS_KEPT))
	profile.records.best_daily = maxi(int(profile.records.get("best_daily", 0)), score)

static func settle_daily(profile: Dictionary, scored: Dictionary, date: String) -> Dictionary:
	## Pays a finished attempt at the day's seam: the gold its score is worth less what the
	## day's best already paid, to a lapidary who may be paid at all. The best is raised when the
	## score beats it. Returns the score's parts with {gold, paid, best_score, best_gold,
	## improved, eligible}.
	var record: Dictionary = dig(profile).duplicate()
	if str(record.get("date", "")) != date:
		record = {"date": date, "best_score": 0, "best_gold": 0, "runs": 1, "run_id": ""}
	var out: Dictionary = scored.duplicate()
	var gold: int = daily_payout(int(scored.get("score", 0)))
	var best_gold: int = int(record.get("best_gold", 0))
	var eligible: bool = daily_eligible(profile)
	var paid: int = maxi(0, gold - best_gold) if eligible else 0
	var improved: bool = int(scored.get("score", 0)) > int(record.get("best_score", 0))
	if improved:
		record.best_score = int(scored.get("score", 0))
		_note_daily_best(profile, date, int(record.best_score), maxi(best_gold, gold))
	record.best_gold = maxi(best_gold, gold)
	profile.dig = record
	profile.gold = int(profile.get("gold", 0)) + paid
	out.merge({"gold": gold, "paid": paid, "best_score": int(record.best_score), "best_gold": int(record.best_gold), "improved": improved, "eligible": eligible}, true)
	return out
