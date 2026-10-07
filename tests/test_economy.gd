extends SceneTree
## Gold at home (docs/GOLD.md): fares and insurance, sockets bought for good, temporary
## stones below the Quarry, pyrite assayed at the lift, the first-conquest purse, and the
## commissions the Ledger keeps.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_content()
	_test_upgrade()
	_test_sockets()
	_test_fares()
	_test_lobby()
	_test_temporary()
	_test_loopholes()
	_test_insurance()
	_test_assay()
	_test_coming_home()
	_test_commissions()
	_test_no_profit()
	print("Economy: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func stone(skill: String, carat: int = 3, cut: int = 2, clarity: int = 3, id: String = "", inclusions: Array = []) -> Dictionary:
	var s: Dictionary = DeepStone.make(skill, carat, cut, clarity, inclusions, {}, id if not id.is_empty() else skill.to_lower())
	s.appraised = true
	s.inclusions_revealed = true
	return s

func dice(character: String, prefix: String) -> Array:
	var out: Array = []
	var keys: Array = DeepContent.character(character).dice
	for index in range(keys.size()):
		out.append(DeepForge.die_from(keys[index], "%s%d" % [prefix, index]))
	return out

func config(seed_value: int, mine: String, boons: bool) -> Dictionary:
	return {"seed": seed_value, "mine": mine, "boons": boons, "players": [
		{"id": "a", "name": "Ada", "character": "ARDOR", "rail": [stone("STRIKE", 20, 4, 3, "a_strike"), stone("GUARD", 20, 4, 3, "a_guard"), stone("MEND", 20, 4, 3, "a_mend")], "dice": dice("ARDOR", "a")},
		{"id": "b", "name": "Bo", "character": "FLORIN", "rail": [stone("CLEAVE", 20, 4, 3, "b_cleave")], "dice": dice("FLORIN", "b"), "insured": true}]}

func cmd(state: Dictionary, who: String, kind: String, fields: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"kind": kind}
	c.merge(fields)
	return DeepDescent.command(state, who, c)

# --- the pack ---------------------------------------------------------------------------------

func _test_content() -> void:
	check(DeepContent.validate().is_empty(), "the pack validates: %s" % str(DeepContent.validate().slice(0, 3)))
	check(DeepEconomy.fare("QUARRY") == 0, "the Quarry is free to go down")
	var last: int = 0
	for key in DeepContent.mines_in_order():
		if key == "QUARRY":
			continue
		var fare: int = DeepEconomy.fare(str(key))
		check(fare > last, "%s costs more to go down than the mine above it (%d)" % [key, fare])
		check(fare * 2 == int(DeepContent.mine(str(key)).start_pyrite), "%s's fare is half its purse, the purse valued at 2 pyrite to the gold" % key)
		check(DeepEconomy.insurance(str(key)) > 0, "%s can be insured" % key)
		last = fare
	check(DeepEconomy.conquest_purse("QUARRY") > 0 and DeepEconomy.conquest_purse("RIFT") == 0, "every mine with a bottom pays a first-conquest purse; the Rift has none")
	check(not DeepContent.mine("SEEPS").has("loadout_sockets"), "no mine fills every socket any more")
	var broken: Dictionary = DeepContent.pack().duplicate(true)
	broken.constants.socket_unlock_gold = [300, 200]
	check(not DeepContent.validate(broken).is_empty(), "socket prices must climb")
	broken = DeepContent.pack().duplicate(true)
	broken.mines.QUARRY.fare_gold = 5
	check(not DeepContent.validate(broken).is_empty(), "the starter mine must stay free")

# --- an old save --------------------------------------------------------------------------

func _test_upgrade() -> void:
	var old: Dictionary = DeepProfile.new_profile("Old")
	for field in ["daily", "outfit", "conquest_paid", "charged_run"]:
		old.erase(field)
	old.schema = 2
	old.records.erase("commissions")
	for key in old.characters:
		old.characters[key].erase("sockets")
	old.mines.QUARRY.boss = true
	check(DeepProfile.upgrade(old), "a schema 2 profile is upgraded")
	check(int(old.schema) == DeepProfile.SCHEMA and old.has("daily") and old.outfit == {"insure": false} and old.has("charged_run") and int(old.records.commissions) == 0,
		"it gains the day, the outfit and the commission count")
	check(old.conquest_paid == ["QUARRY"], "a mine already conquered counts as paid: its purse was for a first")
	check(old.characters.values().all(func(c: Dictionary) -> bool: return int(c.sockets) == 3), "every lapidary starts with three sockets open")
	check(not DeepProfile.upgrade(old), "and an upgraded profile is left alone")

# --- sockets ----------------------------------------------------------------------------------

func _test_sockets() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Sockets")
	DeepProfile.unlock_character(profile, "FLORIN")
	check(DeepContent.character("FLORIN").sockets.size() == 6, "Florin has six sockets")
	check(DeepEconomy.socket_price(profile, "FLORIN") == 300, "the fourth socket costs 300")
	check(not DeepEconomy.unlock_socket(profile, "FLORIN").ok and DeepProfile.open_sockets(profile, "FLORIN") == 3, "an empty purse buys nothing")
	profile.gold = 300 + 1200 + 4800 + 7
	var fourth: Dictionary = DeepEconomy.unlock_socket(profile, "FLORIN")
	check(fourth.ok and int(fourth.paid) == 300 and DeepProfile.open_sockets(profile, "FLORIN") == 4 and DeepProfile.open_sockets(profile, "ARDOR") == 3, "a socket is bought for one lapidary only")
	check(DeepEconomy.socket_price(profile, "FLORIN") == 1200, "the fifth costs far more")
	check(DeepEconomy.unlock_socket(profile, "FLORIN").ok and DeepEconomy.socket_price(profile, "FLORIN") == 4800, "and the sixth more again")
	check(DeepEconomy.unlock_socket(profile, "FLORIN").ok and int(profile.gold) == 7 and DeepEconomy.socket_price(profile, "FLORIN") == -1, "with all six open there is nothing left to buy")
	check(not DeepEconomy.unlock_socket(profile, "FLORIN").ok, "and nothing more is sold")
	check(not DeepEconomy.unlock_socket(profile, "CADENCE").ok, "a lapidary not yet met cannot be fitted")
	## What a socket opens is filled from the vault before a run, wherever it goes down.
	DeepProfile.keep(profile, stone("CLEAVE", 4, 2, 3, "cleave_v"))
	check(DeepProfile.set_rail(profile, "FLORIN", 3, "CLEAVE") == "" and DeepProfile.loadout(profile, "FLORIN").rail[3] is Dictionary, "an opened socket takes a stone from the vault")
	check(DeepProfile.set_rail(profile, "ARDOR", 3, "CLEAVE") != "", "a shut one does not")
	var ardor: Dictionary = DeepProfile.new_profile("Five")
	ardor.gold = 2000
	DeepEconomy.unlock_socket(ardor, "ARDOR")
	DeepEconomy.unlock_socket(ardor, "ARDOR")
	check(DeepProfile.open_sockets(ardor, "ARDOR") == 5 and DeepEconomy.socket_price(ardor, "ARDOR") == -1 and int(ardor.gold) == 500, "a five-socket lapidary is done after two")
	## An old save whose loadout used a socket a deeper mine used to fill: it moves in.
	ardor.characters.ARDOR.sockets = 3
	ardor.characters.ARDOR.rail = [null, "GUARD", "MEND", "STRIKE", null]
	check(DeepProfile.tidy(ardor) and ardor.characters.ARDOR.rail == ["STRIKE", "GUARD", "MEND", null, null], "a stone in a shut socket moves into an open one")

# --- the way down -----------------------------------------------------------------------------

func _test_fares() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Fares")
	profile.gold = 200
	var run: Dictionary = DeepDescent.new_run(config(5, "SEEPS", true))
	var bo: Dictionary = DeepEconomy.charge_departure(profile, run, "b")
	check(int(bo.fare) == 60 and int(bo.insurance) == 15 and int(bo.paid) == 75 and int(profile.gold) == 125, "the fare and the insurance bought are taken at the shaft head: %s" % str(bo))
	check(DeepEconomy.charge_departure(profile, run, "b").is_empty() and int(profile.gold) == 125, "once per run: the same run picked up again is not billed again")
	var ada: Dictionary = DeepProfile.new_profile("Ada")
	ada.gold = 100
	check(int(DeepEconomy.charge_departure(ada, run, "a").paid) == 60 and int(ada.gold) == 40, "uninsured, only the fare")
	var quarry: Dictionary = DeepDescent.new_run(config(6, "QUARRY", true))
	var free: Dictionary = DeepProfile.new_profile("Free")
	check(int(DeepEconomy.charge_departure(free, quarry, "a").paid) == 0, "the Quarry is free")
	var under_way: Dictionary = DeepDescent.new_run(config(7, "SEEPS", false))
	under_way.depth = 3
	var late: Dictionary = DeepProfile.new_profile("Late")
	late.gold = 500
	check(DeepEconomy.charge_departure(late, under_way, "a").is_empty() and int(late.gold) == 500, "a run already under way is never billed")
	var broke: Dictionary = DeepProfile.new_profile("Broke")
	broke.gold = 10
	DeepEconomy.charge_departure(broke, DeepDescent.new_run(config(8, "SEEPS", true)), "b")
	check(int(broke.gold) == 0, "a purse never goes below nothing")

func _test_lobby() -> void:
	var session := DeepSession.new()
	root.add_child(session)
	session.start_local({"name": "Ada", "character": "ARDOR", "rail": [], "dice": [], "gold": 50, "insured": false})
	check(session.can_start(), "the Quarry is free, so anyone can set out")
	session.choose_mine("SEEPS")
	check(not session.can_start() and session.short_members() == ["p0"], "fifty gold does not pay the Seeps' fare")
	check(not bool(session.start_run(1).ok), "and the host cannot set out")
	session.update_member({"gold": 60})
	check(session.can_start(), "sixty does")
	session.update_member({"insured": true})
	check(not session.can_start() and session.departure_cost(session.local_member()) == 75, "insurance is added to the bill")
	session.update_member({"gold": 75, "sockets": 4})
	check(session.can_start() and bool(session.start_run(2).ok), "paid up, the party sets out")
	check(bool(session.run.players[0].insured), "and the run knows who is insured")
	session.free()

# --- temporary stones ---------------------------------------------------------------------------

func _test_temporary() -> void:
	var state: Dictionary = DeepDescent.new_run(config(11, "SEEPS", true))
	var ada: Dictionary = DeepDescent.player(state, "a")
	var bo: Dictionary = DeepDescent.player(state, "b")
	check(state.phase == "grubstake", "a deeper run opens at the shaft head")
	check(ada.temps.size() == 2 and bo.temps.size() == 3, "a temporary stone is offered for every shut socket (%d, %d)" % [ada.temps.size(), bo.temps.size()])
	var sockets: Array = DeepContent.character("FLORIN").sockets
	for offer in bo.temps:
		check(offer.picks.size() == 3 and int(offer.chosen) == -1, "three to choose from, none taken")
		var socket: String = str(sockets[int(offer.index)])
		var colors: Array = offer.picks.map(func(s: Dictionary) -> String: return DeepStone.color(s))
		if socket == DeepContent.SOCKET_ANY:
			check(colors[0] != colors[1] and colors[1] != colors[2] and colors[0] != colors[2], "an Any socket is offered three colors: %s" % str(colors))
		else:
			check(colors.all(func(c: String) -> bool: return c == socket), "a %s socket is offered %s stones: %s" % [socket, socket, str(colors)])
		for pick in offer.picks:
			check(bool(pick.temporary) and DeepStone.is_fragile(pick) and bool(pick.appraised) and DeepStone.fits(pick, socket), "each is read, fragile, and fits its socket")
			check(not pick.inclusions.any(func(k: String) -> bool: return k == "VOID"), "and none is Void")
	check(not cmd(state, "a", "stake", {"offer": state.grubstake.offers.a[0].id}).ok, "the stakes wait for the temporary stones")
	check(not cmd(state, "a", "temporary", {"index": 0, "pick": 0}).ok, "an open socket takes no temporary stone")
	var first: Dictionary = cmd(state, "a", "temporary", {"index": int(ada.temps[0].index), "pick": 1})
	check(first.ok and ada.rail[int(ada.temps[0].index)].id == ada.temps[0].picks[1].id and int(first.event.left) == 1, "the one taken is set in its socket")
	check(not cmd(state, "a", "temporary", {"index": int(ada.temps[0].index), "pick": 0}).ok, "and the socket keeps it")
	cmd(state, "a", "temporary", {"index": int(ada.temps[1].index), "pick": 2})
	check(DeepDescent.temporary_left(ada) == 0 and cmd(state, "a", "stake", {"offer": state.grubstake.offers.a[1].id}).ok, "with every one taken, the stake")
	for offer in bo.temps:
		cmd(state, "b", "temporary", {"index": int(offer.index), "pick": 0})
	var staked: Dictionary = cmd(state, "b", "stake", {"offer": state.grubstake.offers.b[1].id})
	check(staked.ok and state.phase == "tunnels", "and the tunnels open")
	## A party that pushed on through the Quarry gets no temporary stones: it brought its rail.
	var quarry: Dictionary = DeepDescent.new_run(config(12, "QUARRY", true))
	check(quarry.players.all(func(p: Dictionary) -> bool: return p.temps.is_empty()), "the Quarry lends nothing")
	## The end of the run: a temporary stone goes back without counting among the losses.
	var done: Dictionary = DeepDescent.new_run(config(13, "SEEPS", false))
	var lent: Dictionary = DeepDescent.player(done, "a").rail[3]
	check(bool(lent.temporary), "with no shaft head, the first of each three is set")
	DeepDescent.player(done, "a").haul.append(lent.duplicate(true))
	DeepDescent._finish(done, "extracted")
	var home: Dictionary = DeepDescent.results(done).players.a
	check(not DeepStone.rail_stones(DeepDescent.player(done, "a")).any(func(s: Dictionary) -> bool: return bool(s.get("temporary", false))), "temporary stones leave the rail when the run ends")
	check(home.haul.is_empty() and home.shattered.is_empty(), "and come home neither as finds nor as losses")
	var profile: Dictionary = DeepProfile.new_profile("Temps")
	DeepProfile.apply_result(profile, DeepDescent.results(done), "a")
	check(not profile.tray.any(func(s: Dictionary) -> bool: return bool(s.get("temporary", false))), "nothing temporary reaches the tray")

func _test_loopholes() -> void:
	var state: Dictionary = DeepDescent.new_run(config(14, "SEEPS", false))
	var ada: Dictionary = DeepDescent.player(state, "a")
	var lent: Dictionary = ada.rail[3]
	check(not DeepDescent.can_wish(lent), "the landing's well will not take a temporary stone")
	check(DeepDescent.can_wish(ada.rail[0]), "it still takes a stone of your own")
	var mine: Dictionary = DeepContent.mine("SEEPS")
	var rng: RandomNumberGenerator = DeepRng.streams(14).oddities
	## A wishing well found in the tunnels refuses it by its own rule as well.
	var action: Dictionary = {"kind": "wishing_well", "mode": "stone"}
	var refused: Dictionary = _apply_action(action, ada, {"stone_id": str(lent.id)}, rng, mine)
	check(not bool(refused.get("ok", true)), "a wishing well in the tunnels refuses a fragile stone: %s" % str(refused))
	## The Crucible: whichever stone survives, a fragile one in the fire makes it fragile.
	for seed_value in range(8):
		var unit: Dictionary = DeepBattle.make_player("c", "C", "ARDOR", [stone("STRIKE", 9, 3, 3, "keep%d" % seed_value)], dice("ARDOR", "c"))
		unit.haul = [lent.duplicate(true)]
		unit.haul[0].id = "feed%d" % seed_value
		var fire: RandomNumberGenerator = DeepRng.streams(seed_value).oddities
		var fused: Dictionary = _apply_action({"kind": "fuse", "carry": 30}, unit, {"keep_id": "keep%d" % seed_value, "feed_id": "feed%d" % seed_value}, fire, mine)
		var made: Array = fused.get("changed", [])
		check(not made.is_empty() and DeepStone.is_fragile(made[0]) and bool(made[0].get("temporary", false)), "a stone fused with a temporary one is temporary too (seed %d)" % seed_value)

func _apply_action(action: Dictionary, unit: Dictionary, payload: Dictionary, rng: RandomNumberGenerator, mine: Dictionary) -> Dictionary:
	## One oddity action on its own, as a card's choice would play it.
	return DeepOddities.apply(action, unit, payload, rng, {"mine": mine, "depth": 5, "run": "test"})

# --- insurance ----------------------------------------------------------------------------------

func _test_insurance() -> void:
	var state: Dictionary = DeepDescent.new_run(config(21, "QUARRY", false))
	for unit in state.players:
		for i in range(30):
			unit.haul.append(stone("STRIKE", 3, 2, 3, "%s_h%d" % [unit.id, i]))
	DeepDescent._start_salvage(state)
	var plain: Array = state.salvage.a.rolls
	var cover: Array = state.salvage.b.rolls
	check(plain.all(func(r: Dictionary) -> bool: return not r.has("insured")), "an uninsured haul rolls once")
	check(cover.all(func(r: Dictionary) -> bool: return bool(r.insured) and int(r.roll) == maxi(int(r.first), int(r.second))), "an insured haul keeps the better of two throws")
	check(cover.any(func(r: Dictionary) -> bool: return bool(r.kept) and int(r.first) != int(r.sides)), "and the second throw sometimes saves a stone the first would have lost")
	var saved_plain: int = plain.filter(func(r: Dictionary) -> bool: return bool(r.kept)).size()
	var saved_cover: int = cover.filter(func(r: Dictionary) -> bool: return bool(r.kept)).size()
	check(saved_cover >= saved_plain, "insurance brings more home (%d against %d)" % [saved_cover, saved_plain])

# --- pyrite at the lift -------------------------------------------------------------------------

func _test_assay() -> void:
	check(DeepEconomy.assay({"ore": 53, "earned": 400}, "extracted") == {"carried": 53, "pyrite": 50, "gold": 10}, "pyrite is weighed in fives")
	check(int(DeepEconomy.assay({"ore": 300, "earned": 40}, "conquered").gold) == 8, "only what was earned down there is paid for")
	check(int(DeepEconomy.assay({"ore": 300, "earned": 300}, "fallen").gold) == 0, "a fall pays nothing")
	## Every way pyrite comes to hand down there is counted; the starting purse is not.
	var state: Dictionary = DeepDescent.new_run(config(31, "SEEPS", false))
	var ada: Dictionary = DeepDescent.player(state, "a")
	check(int(ada.ore) == 120 and int(ada.stats.earned) == 0, "the Seeps' purse is in hand and none of it earned")
	var guard: int = 0
	while int(ada.stats.earned) == 0 and guard < 60:
		guard += 1
		_advance(state)
	check(int(ada.stats.earned) > 0 and int(ada.ore) > 120, "a fight or a vein is counted as earned (%d)" % int(ada.stats.earned))
	var home: Dictionary = DeepDescent.results(state).players.a
	check(int(home.ore) == int(ada.ore) and int(home.earned) == int(ada.stats.earned), "the results carry the pocket and the tally")
	var only_purse: Dictionary = {"ore": 120, "earned": 0}
	check(int(DeepEconomy.assay(only_purse, "extracted").gold) == 0, "the purse a deeper mine hands out is never cashed")
	## A stake's pyrite and an oddity's are earned too.
	var unit: Dictionary = {"ore": 0, "stats": {}}
	DeepEconomy.earned(unit, 40)
	DeepEconomy.earned(unit, -9)
	check(int(unit.stats.earned) == 40, "only gains are written down")

func _advance(state: Dictionary) -> void:
	match str(state.phase):
		"tunnels":
			var offer: Dictionary = state.offers[0]
			for candidate in state.offers:
				if str(candidate.kind) in ["fight", "vein"]:
					offer = candidate
			for unit in state.players:
				if str(unit.get("vote", "")).is_empty():
					cmd(state, str(unit.id), "vote_tunnel", {"offer": offer.id})
		"chamber":
			if DeepDescent.in_battle(state):
				var guard: int = 0
				while DeepDescent.in_battle(state) and guard < 400:
					guard += 1
					var b: Dictionary = DeepDescent.battle(state)
					if str(b.phase) == "planning":
						for unit in b.players:
							if not bool(unit.locked):
								cmd(state, str(unit.id), "lock")
						continue
					if DeepDescent.step(state).is_empty() and not DeepBattle.has_steps(b):
						break
			elif str(state.chamber.kind) in ["vein", "vug"]:
				for unit in state.players:
					if not bool(unit.get("mining", false)):
						continue
					var struck: bool = false
					for spot in state.chamber.vein.spots:
						if str(spot.taken).is_empty() and cmd(state, str(unit.id), "strike", {"spot": spot.index}).ok:
							struck = true
							break
					if not struck:
						cmd(state, str(unit.id), "stop_mining", {})
			elif str(state.chamber.kind) == "merchant":
				for unit in state.players:
					cmd(state, str(unit.id), "leave")
			else:
				var oddity: Dictionary = DeepContent.oddity(str(state.chamber.get("oddity", "")))
				for unit in state.players:
					if str(unit.get("oddity_choice", "")).is_empty() and not oddity.is_empty():
						cmd(state, str(unit.id), "oddity", {"choice": oddity.choices[oddity.choices.size() - 1].id})

# --- coming home --------------------------------------------------------------------------------

func _test_coming_home() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Home")
	var first: Dictionary = stone("VENOM", 4, 2, 3, "venom_first")
	var result: Dictionary = {"run_id": "h1", "mine": "QUARRY", "outcome": "conquered", "depth": 16, "deepest": 16, "wardens": [8, 12, 16],
		"mines": [{"mine": "QUARRY", "deepest": 16, "wardens": [8, 12, 16], "boss": true}],
		"players": {"a": {"haul": [first], "dice": [], "stats": {}, "rail": [], "ore": 237, "earned": 500}}}
	var applied: Dictionary = DeepProfile.apply_result(profile, result, "a")
	check(int(applied.assay.gold) == 47 and int(applied.assay.pyrite) == 235, "the assayer pays for what was carried up: %s" % str(applied.assay))
	check(applied.purses == [{"mine": "QUARRY", "gold": DeepEconomy.conquest_purse("QUARRY")}], "the Quarry's first conquest pays its purse")
	check(int(profile.gold) == 47 + DeepEconomy.conquest_purse("QUARRY"), "both into the purse (%d)" % int(profile.gold))
	check(profile.tray.size() == 1 and not profile.vault.has("VENOM") and applied.kept.is_empty(), "the first stone of its skill waits on the tray to be kept or turned in")
	check(int(profile.history.back().gold) == 47, "and the ledger remembers what the run was assayed for")
	var again: Dictionary = DeepProfile.apply_result(profile, result, "a")
	check(again.purses.is_empty() and profile.conquest_paid == ["QUARRY"], "the purse is paid once")
	var lost: Dictionary = result.duplicate(true)
	lost.outcome = "fallen"
	var gold_before: int = int(profile.gold)
	check(int(DeepProfile.apply_result(profile, lost, "a").assay.gold) == 0 and int(profile.gold) == gold_before, "a fall assays nothing")
	## Asked to sell the first stone of a skill, the vault keeps it: it is never sold.
	var kept: Dictionary = DeepProfile.decide_tray(profile, "venom_first", false)
	check(kept.kept and profile.vault.has("VENOM"), "the first of a skill is never sold")

# --- commissions --------------------------------------------------------------------------------

func _test_commissions() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Commissions")
	profile.id = "pf_fixed"
	check(DeepEconomy.roll_day(profile, "2026-10-07"), "a new day is rolled")
	var today: Array = profile.daily.commissions
	check(today.size() == DeepEconomy.commission_slots(), "three commissions")
	var skills: Array = today.map(func(c: Dictionary) -> String: return str(c.skill))
	var pool: Array = DeepEconomy.commission_pool(profile)
	check(skills.all(func(k: String) -> bool: return pool.has(k)) and skills[0] != skills[1] and skills[1] != skills[2] and skills[0] != skills[2], "three different skills the Quarry holds: %s" % str(skills))
	check(not skills.any(func(k: String) -> bool: return str(DeepContent.skill(k).color) == DeepContent.OPAL), "never an opal")
	check(not DeepEconomy.roll_day(profile, "2026-10-07"), "the same day changes nothing")
	var twin: Dictionary = DeepProfile.new_profile("Twin")
	twin.id = "pf_fixed"
	DeepEconomy.roll_day(twin, "2026-10-07")
	check(JSON.stringify(twin.daily.commissions) == JSON.stringify(today), "a day always offers the same commissions, however often the game is opened")
	for commission in today:
		check(int(commission.reward) > DeepStone.value(DeepEconomy.weakest(str(commission.skill), commission.need)), "%s pays more than the least stone that meets it sells for" % commission.skill)
		check(DeepEconomy.where_found(str(commission.skill)).has("QUARRY"), "and the Quarry holds it")
	## Meeting a commission: its skill, read, and any one of the four C's it asks for.
	var ask: Dictionary = {"id": "x", "skill": "STRIKE", "need": {"kind": "carat", "value": 5}, "reward": 80, "done": false}
	check(DeepEconomy.meets(ask, stone("STRIKE", 5)) and not DeepEconomy.meets(ask, stone("STRIKE", 4)) and not DeepEconomy.meets(ask, stone("GUARD", 9)), "a carat requirement")
	var raw: Dictionary = stone("STRIKE", 9)
	raw.appraised = false
	check(not DeepEconomy.meets(ask, raw), "a raw stone meets nothing: what is in it is not known")
	var lent: Dictionary = stone("STRIKE", 9)
	lent.fragile = true
	check(not DeepEconomy.meets(ask, lent), "nor does a fragile one")
	check(DeepEconomy.meets({"skill": "STRIKE", "need": {"kind": "cut", "value": 2}}, stone("STRIKE", 1, 2)) and not DeepEconomy.meets({"skill": "STRIKE", "need": {"kind": "cut", "value": 2}}, stone("STRIKE", 1, 1)), "a cut requirement")
	check(DeepEconomy.meets({"skill": "STRIKE", "need": {"kind": "pure", "value": 4}}, stone("STRIKE", 1, 0, 4)) and not DeepEconomy.meets({"skill": "STRIKE", "need": {"kind": "pure", "value": 4}}, stone("STRIKE", 1, 0, 3)), "a clarity requirement")
	check(DeepEconomy.meets({"skill": "STRIKE", "need": {"kind": "included", "value": 1}}, stone("STRIKE", 1, 0, 2, "inc", ["SILK"])) and not DeepEconomy.meets({"skill": "STRIKE", "need": {"kind": "included", "value": 1}}, stone("STRIKE")), "an inclusion requirement")
	check(DeepEconomy.need_text({"kind": "carat", "value": 5}) == "5 carats or more" and DeepEconomy.need_text({"kind": "cut", "value": 2}) == "Good cut or better" and DeepEconomy.need_text({}) == "", "requirements read as words")
	## Turning in: the stone is gone, the gold paid, the slot filled until tomorrow.
	var target: Dictionary = today[0]
	var offered: Dictionary = DeepEconomy.weakest(str(target.skill), target.need)
	offered.appraised = true
	offered.id = "offered"
	profile.tray.append(offered)
	check(DeepEconomy.ready_count(profile) >= 1 and DeepEconomy.commission_for(profile, offered).id == target.id, "the tray knows which commission it can fill")
	var gold_before: int = int(profile.gold)
	var handed: Dictionary = DeepEconomy.turn_in(profile, "offered", str(target.id))
	check(handed.ok and int(profile.gold) == gold_before + int(target.reward) and profile.tray.is_empty() and bool(target.done), "turning in pays the commission: %s" % str(handed))
	check(profile.seen.has(str(target.skill)) and int(profile.records.commissions) == 1, "the skill stays seen and the ledger counts it")
	check(not DeepEconomy.turn_in(profile, "offered", str(target.id)).ok, "a filled commission takes nothing more")
	check(DeepEconomy.open_commissions(profile).size() == 2, "two still open")
	## Rerolls: the first of a day free, then dearer each time.
	var open: Array = DeepEconomy.open_commissions(profile)
	check(DeepEconomy.reroll_price(profile) == 0, "the first reroll is free")
	var swapped: Dictionary = DeepEconomy.reroll(profile, str(open[0].id))
	check(swapped.ok and int(swapped.paid) == 0 and str(swapped.commission.skill) != str(open[0].skill), "it swaps the commission for another skill")
	check(DeepEconomy.reroll_price(profile) == 10, "the second costs ten")
	profile.gold = 5
	check(not DeepEconomy.reroll(profile, str(DeepEconomy.open_commissions(profile)[0].id)).ok, "and is refused to an empty purse")
	profile.gold = 100
	check(DeepEconomy.reroll(profile, str(DeepEconomy.open_commissions(profile)[0].id)).ok and int(profile.gold) == 90 and DeepEconomy.reroll_price(profile) == 20, "then twenty")
	check(not DeepEconomy.reroll(profile, str(target.id)).ok, "a filled commission cannot be rerolled")
	## Tomorrow: every slot new again, and the free reroll back.
	check(DeepEconomy.roll_day(profile, "2026-10-08") and DeepEconomy.open_commissions(profile).size() == 3 and DeepEconomy.reroll_price(profile) == 0, "a new day brings three open commissions and a free reroll")
	## The first stone of a skill may be turned in rather than kept: it is never sold, but
	## it is the player's to give.
	var fresh: Dictionary = DeepProfile.new_profile("Fresh")
	fresh.daily = {"date": "2026-10-07", "rerolls": 0, "seq": 0, "commissions": [{"id": "cv", "skill": "VENOM", "need": {}, "reward": 90, "done": false}]}
	fresh.tray.append(stone("VENOM", 2, 1, 3, "first_venom"))
	check(DeepProfile.first_of_skill(fresh, fresh.tray[0]) and DeepEconomy.turn_in(fresh, "first_venom", "cv").ok and not fresh.vault.has("VENOM") and fresh.seen.has("VENOM"),
		"a first stone of its skill can be turned in, and its skill stays seen")
	## A deeper mine opened widens what can be asked for.
	var wide: Dictionary = DeepProfile.new_profile("Wide")
	wide.mines.SEEPS.unlocked = true
	check(DeepEconomy.commission_pool(wide).size() > pool.size() and DeepEconomy.commission_pool(wide).has("APEX"), "the Seeps adds its skills")

# --- no profit ----------------------------------------------------------------------------------

func _test_no_profit() -> void:
	## Turning in always beats selling, and nothing bought with gold comes back as more gold.
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for key in ["QUARRY", "SEEPS", "GLASS_VEINS", "FURNACE"]:
		var mine: Dictionary = DeepContent.mine(key)
		for i in range(200):
			var found: Dictionary = DeepForge.roll_stone(rng, mine, 1 + i % 16, 0.0, {}, "np%d" % i)
			found.appraised = true
			var commission: Dictionary = {"skill": str(found.skill), "need": {}, "reward": DeepEconomy.base_reward(str(found.skill), {})}
			if DeepEconomy.payout(commission, found) <= DeepStone.value(found):
				check(false, "turning in a %s pays less than selling it" % DeepStone.name(found))
		## The fare buys a purse at 2 pyrite to the gold; the assayer buys back at 5, and only
		## what was earned: going down and straight back up can never pay.
		var purse: int = int(mine.get("start_pyrite", 0))
		check(int(DeepEconomy.assay({"ore": purse, "earned": purse}, "extracted").gold) < DeepEconomy.fare(key) or key == "QUARRY", "%s: even a purse cashed whole is worth less than its fare" % key)
	check(true, "turning in beats selling across 800 stones")
