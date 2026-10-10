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
	_test_seam_and_fragile_find()
	_test_geodes()
	_test_contracts()
	_test_no_profit_chains()
	_test_daily_plan()
	_test_daily_run()
	_test_daily_rewards()
	_test_daily_lobby()
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
	## Bo has three sockets open and one stone to set in them, so the two empty open ones
	## are lent stones as well as the three shut ones.
	check(ada.temps.size() == 2 and bo.temps.size() == 5, "a temporary stone is offered for every empty socket, open or shut (%d, %d)" % [ada.temps.size(), bo.temps.size()])
	check(bo.temps.map(func(o: Dictionary) -> int: return int(o.index)) == [1, 2, 3, 4, 5], "in socket order, after the one stone")
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
	## Then each die is answered for (kept, here), as a deeper start asks.
	for offer in ada.dice_offers:
		cmd(state, "a", "dice_offer", {"index": int(offer.index), "pick": -1})
	check(DeepDescent.temporary_left(ada) == 0 and cmd(state, "a", "stake", {"offer": state.grubstake.offers.a[1].id}).ok, "with every one taken, the stake")
	for offer in bo.temps:
		cmd(state, "b", "temporary", {"index": int(offer.index), "pick": 0})
	for offer in bo.dice_offers:
		cmd(state, "b", "dice_offer", {"index": int(offer.index), "pick": -1})
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

func _test_seam_and_fragile_find() -> void:
	## Prying out "the big one" never gives less than a Small stone, even in the Quarry.
	var quarry: Dictionary = DeepContent.mine("QUARRY")
	var pry: Dictionary = {}
	for choice in DeepContent.section("oddities").get("SEAM", {}).get("choices", []):
		if str(choice.get("id", "")) == "pry":
			pry = choice.action
	check(str(pry.get("min_size", "")) == "SMALL", "the seam's pry asks for a Small stone at least")
	var smallest: int = 99
	for seed_value in range(120):
		var unit: Dictionary = DeepBattle.make_player("s", "S", "ARDOR", [], dice("ARDOR", "s"))
		unit.haul = []
		var result: Dictionary = DeepOddities.apply(pry, unit, {}, DeepRng.streams(seed_value).oddities, {"mine": quarry, "depth": 1, "run": "test"})
		smallest = mini(smallest, int(unit.haul[0].carat))
		check(bool(result.get("ok", false)) and int(unit.haul[0].carat) <= int(quarry.carat.cap), "and stays inside the mine's band (seed %d)" % seed_value)
	check(smallest >= DeepStone.size_low("SMALL"), "so the smallest of 120 pries is Small: %d carats" % smallest)
	## A Fragile Find comes from depth 20, or from the bottom of a mine that ends sooner.
	var state: Dictionary = DeepDescent.new_run(config(13, "QUARRY", true))
	var ada: Dictionary = DeepDescent.player(state, "a")
	var out: Dictionary = {"made": []}
	DeepBoons._effect(state, ada, DeepContent.boon("FRAGILE_STONE").effects[0], {}, -1, -1, DeepRng.streams(13).boons, out)
	check(out.made.size() == 1 and int(out.made[0].provenance.depth) == 16, "a Fragile Find in the 16-deep Quarry comes from depth 16: %s" % str(out.made[0].get("provenance", {}) if not out.made.is_empty() else {}))

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
			elif str(state.chamber.kind) in DeepDescent.ROCK_ROOMS:
				for unit in state.players:
					if not bool(unit.get("mining", false)):
						continue
					var struck: bool = false
					for spot in state.chamber.vein.spots:
						if str(spot.taken).is_empty() and str(spot.get("owner", unit.id)) == str(unit.id) and cmd(state, str(unit.id), "strike", {"spot": spot.index}).ok:
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

# --- the shop: Geodes ---------------------------------------------------------------------------

func geode_of(kind: String, theme: String, mine: String) -> Dictionary:
	return {"kind": kind, "theme": theme, "mine": mine}

func _test_geodes() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Shop")
	profile.id = "pf_shop"
	profile.daily = {}
	check(DeepEconomy.roll_day(profile, "2026-10-10"), "a new day stocks the shelf")
	var shelf: Array = DeepEconomy.shelf(profile)
	var kinds: Array = shelf.map(func(g: Dictionary) -> String: return str(g.kind))
	check(shelf.size() == 3 and kinds[0] == "mine" and kinds[1] == "color" and kinds[2] in ["featured", "mine"], "three Geodes a day: a mine's, a color's and the week's set: %s" % str(kinds))
	check(shelf.all(func(g: Dictionary) -> bool: return not bool(g.bought) and int(g.price) > 0 and not g.stone.is_empty()), "each priced, unopened, its stone already inside")
	check(not DeepEconomy.roll_day(profile, "2026-10-10") and DeepEconomy.shelf(profile) == shelf, "the same day changes nothing")
	var twin: Dictionary = DeepProfile.new_profile("Twin")
	twin.id = "pf_shop"
	twin.daily = {}
	DeepEconomy.roll_day(twin, "2026-10-10")
	check(JSON.stringify(DeepEconomy.shelf(twin)) == JSON.stringify(shelf), "a day's shelf is the same however often the game is opened")
	var color: String = str(shelf[1].theme)
	check(DeepStone.is_opal(shelf[1].stone) or DeepStone.color(shelf[1].stone) == color, "a Color Geode holds a stone of its color (or an opal)")
	## A profile from before the shop gets today's shelf on the spot.
	var older: Dictionary = DeepProfile.new_profile("Older")
	older.daily = {"date": "2026-10-10", "rerolls": 0, "seq": 0, "commissions": []}
	check(DeepEconomy.roll_day(older, "2026-10-10") and DeepEconomy.shelf(older).size() == 3, "a save from before the shop is stocked the same day")
	var sealed: Dictionary = DeepProfile.new_profile("Sealed")
	for key in sealed.mines:
		sealed.mines[key].unlocked = false
	sealed.daily = {}
	DeepEconomy.roll_day(sealed, "2026-10-10")
	check(DeepEconomy.shelf(sealed).is_empty(), "with no mine open there is nothing to stock")
	## Tomorrow: a new shelf.
	DeepEconomy.roll_day(profile, "2026-10-11")
	check(DeepEconomy.shelf(profile).size() == 3 and str(DeepEconomy.shelf(profile)[0].id) != str(shelf[0].id), "tomorrow's shelf is a new one")
	## What comes out of a Geode: never Void, as heavy as the band allows, now and then an opal.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var opals: int = 0
	var rolls: int = 0
	for key in ["QUARRY", "SEEPS", "GLASS_VEINS", "GEODE"]:
		var geode: Dictionary = geode_of("mine", key, key)
		var band: Dictionary = DeepEconomy.geode_band(geode)
		var over_cap: int = 0
		for i in range(1500):
			var made: Dictionary = DeepEconomy.roll_geode_stone(rng, geode, "g%d" % i)
			rolls += 1
			if DeepStone.is_fragile(made):
				check(false, "a %s Geode gave up a fragile stone" % key)
			if int(made.carat) < int(band.low) or int(made.carat) > int(band.high):
				check(false, "a %s Geode stone weighs %d, outside %d-%d" % [key, int(made.carat), int(band.low), int(band.high)])
			if int(made.carat) > int(band.cap):
				over_cap += 1
			if DeepStone.is_opal(made):
				opals += 1
		check(over_cap > 0, "a %s Geode now and then holds a stone heavier than the mine ever gives (%d of 1500)" % [key, over_cap])
		check(int(band.low) == int(DeepForge.carat_band(DeepContent.mine(key), 1).soft), "a %s Geode's stones are never lighter than the mine's usual top" % key)
	check(opals > rolls / 300 and opals < rolls / 40, "about one Geode in a hundred holds an opal (%d of %d)" % [opals, rolls])
	## Every Geode on every shelf, in every mine, costs well over what its stone sells for.
	for key in DeepContent.mines_in_order():
		var recipes: Array = [geode_of("mine", str(key), str(key))]
		for each in DeepContent.color_KEYS:
			recipes.append(geode_of("color", str(each), str(key)))
		for set in DeepEconomy.featured_sets():
			recipes.append(geode_of("featured", str(set.key), str(key)))
		for geode in recipes:
			if DeepEconomy.geode_pool(geode).size() < 1:
				continue
			var odds: Dictionary = DeepEconomy.geode_odds(geode)
			var tiers: float = 0.0
			for tier in odds.tiers:
				tiers += float(odds.tiers[tier])
			var shares: float = float(odds.opal)
			for entry in odds.skills:
				shares += float(entry[1])
			if absf(tiers - 1.0) > 0.01 or absf(shares - 1.0) > 0.01:
				check(false, "%s's odds add up (%.3f, %.3f)" % [str(geode), tiers, shares])
			if float(DeepEconomy.geode_price(geode)) < float(odds.worth) * 1.5:
				check(false, "%s costs %d for a stone worth %d on average" % [str(geode), DeepEconomy.geode_price(geode), int(odds.worth)])
	check(true, "every Geode costs at least half again what its stone sells for")
	## Buying one: the gold, the stone on the tray, read; once.
	var buyer: Dictionary = DeepProfile.new_profile("Buyer")
	buyer.daily = {}
	DeepEconomy.roll_day(buyer, "2026-10-10")
	var first: Dictionary = DeepEconomy.shelf(buyer)[0]
	buyer.gold = int(first.price) - 1
	check(not DeepEconomy.open_geode(buyer, str(first.id)).ok and buyer.tray.is_empty(), "a purse short of the price opens nothing")
	buyer.gold = int(first.price) + 5
	var opened: Dictionary = DeepEconomy.open_geode(buyer, str(first.id))
	check(opened.ok and int(buyer.gold) == 5 and bool(first.bought), "cracking one takes its price: %s" % str(opened.get("error", "")))
	var got: Dictionary = buyer.tray.back()
	check(buyer.tray.size() == 1 and bool(got.appraised) and str(got.provenance.source) == "geode" and not str(got.provenance.get("date", "")).is_empty(), "its stone waits on the tray, already read")
	check(str(got.skill) == str(first.stone.skill) and int(got.carat) == int(first.stone.carat), "and it is the stone that was inside all along")
	check(buyer.seen.has(str(got.skill)) and int(buyer.records.geodes) == 1, "its skill is known and the ledger counts it")
	buyer.gold = 99999
	check(not DeepEconomy.open_geode(buyer, str(first.id)).ok and buyer.tray.size() == 1, "an open Geode cannot be bought twice")
	check(not DeepEconomy.open_geode(buyer, "nope").ok, "nor can one that is not on the shelf")

# --- contracts ------------------------------------------------------------------------------------

func graded(skill: String, carat: int, cut: int, clarity: int, id: String, mine: String = "QUARRY", inclusions: Array = []) -> Dictionary:
	var s: Dictionary = stone(skill, carat, cut, clarity, id, inclusions)
	s.provenance = {"mine": mine, "depth": 8}
	return s

func refs_of(stones: Array) -> Array:
	return stones.map(func(s: Dictionary) -> String: return "t:%s" % str(s.id))

func _test_contracts() -> void:
	var clear: int = DeepContent.clear_index()
	var flawless: int = DeepContent.clarities().size() - 1
	## Stones made to a grade: Rough, Fine, Precious, Exquisite, Peerless.
	check(str(DeepStone.grade(graded("STRIKE", 3, 1, clear, "r")).tier) == "ROUGH", "a light, plain stone is Rough")
	check(str(DeepStone.grade(graded("STRIKE", 6, 4, clear, "f")).tier) == "FINE", "a Perfect cut lifts it to Fine")
	check(str(DeepStone.grade(graded("STRIKE", 12, 4, flawless, "p")).tier) == "PRECIOUS", "twelve Flawless carats are Precious")
	check(str(DeepStone.grade(graded("STRIKE", 18, 4, flawless, "e")).tier) == "EXQUISITE", "eighteen are Exquisite")
	check(str(DeepStone.grade(graded("STRIKE", 24, 4, flawless, "x")).tier) == "PEERLESS", "and twenty-four Peerless")
	## What may go in.
	var raw: Dictionary = graded("STRIKE", 3, 1, clear, "raw")
	raw.appraised = false
	check(not DeepEconomy.contract_refusal(raw).is_empty(), "a raw stone's grade is not known yet")
	check(not DeepEconomy.contract_refusal(DeepStone.birthstone("ARDOR")).is_empty(), "a Birthstone cannot go in")
	var lent: Dictionary = graded("STRIKE", 3, 1, clear, "lent")
	lent.fragile = true
	check(not DeepEconomy.contract_refusal(lent).is_empty(), "nor a fragile stone")
	check(not DeepEconomy.contract_refusal(graded("SEAM_RED", 3, 1, clear, "opal")).is_empty(), "nor an opal")
	check(not DeepEconomy.contract_refusal(graded("STRIKE", 24, 4, flawless, "top")).is_empty(), "nor a Peerless stone: there is no grade above it")
	check(DeepEconomy.contract_refusal(graded("STRIKE", 3, 1, clear, "ok")).is_empty(), "a read stone of any other grade can")
	## Five Rough stones: three Red, two Blue.
	var profile: Dictionary = DeepProfile.new_profile("Contracts")
	profile.gold = 500
	var five: Array = [graded("STRIKE", 3, 1, clear, "c1"), graded("CLEAVE", 3, 1, clear, "c2"), graded("CRUSH", 3, 0, clear, "c3"), graded("GUARD", 4, 1, clear, "c4"), graded("TEMPO", 4, 0, clear, "c5")]
	for s in five:
		profile.tray.append(s)
	check(DeepEconomy.contract_stones(profile).size() >= 5, "the tray's read stones are offered for contracts")
	var preview: Dictionary = DeepEconomy.contract_preview(profile, refs_of(five))
	check(bool(preview.ok) and str(preview.tier) == "ROUGH" and str(preview.next) == "FINE" and int(preview.fee) == 20, "five Rough stones make a Fine one, for 20 gold: %s" % str(preview.get("error", "")))
	check(is_equal_approx(float(preview.colors.get("RED", 0.0)), 0.6) and is_equal_approx(float(preview.colors.get("BLUE", 0.0)), 0.4), "its color is three in five Red, two in five Blue: %s" % str(preview.colors))
	check(int(preview.carat) == 3 and str(preview.mine) == "QUARRY" and bool(preview.ready), "it weighs their average, from the Quarry's rock, and can be signed")
	## The odds the bench prints: every skill it could make, likeliest first, adding up to one,
	## each color's share split among its skills the way the rock gives them.
	var odds: Array = DeepEconomy.contract_odds(preview)
	var total: float = 0.0
	var by_color: Dictionary = {}
	var sorted: bool = true
	for i in range(odds.size()):
		total += float(odds[i][1])
		var color: String = str(DeepContent.skill(str(odds[i][0])).get("color", ""))
		by_color[color] = float(by_color.get(color, 0.0)) + float(odds[i][1])
		if i > 0 and float(odds[i][1]) > float(odds[i - 1][1]) + 0.000001:
			sorted = false
	check(not odds.is_empty() and is_equal_approx(total, 1.0) and sorted, "a contract's odds add up to one, likeliest first (%d skills, %.4f)" % [odds.size(), total])
	check(is_equal_approx(float(by_color.get("RED", 0.0)), 0.6) and is_equal_approx(float(by_color.get("BLUE", 0.0)), 0.4), "and each color keeps its share: %s" % str(by_color))
	var pooled: bool = odds.all(func(entry: Array) -> bool:
		return preview.pool.get(str(DeepContent.skill(str(entry[0])).get("color", "")), []).has(str(entry[0])))
	check(pooled, "every skill in them is one the rock can give at the grade promised")
	check(DeepEconomy.contract_odds(DeepEconomy.contract_preview(profile, [])).is_empty(), "an empty bench has no odds")
	var four: Dictionary = DeepEconomy.contract_preview(profile, refs_of(five.slice(0, 4)))
	check(not bool(four.ready) and str(four.reason).contains("1 more"), "four stones are one short: %s" % str(four.reason))
	profile.tray.append(graded("STRIKE", 6, 4, clear, "fine1"))
	var mixed: Dictionary = DeepEconomy.contract_preview(profile, refs_of(five.slice(0, 4)) + ["t:fine1"])
	check(not bool(mixed.ok), "stones of two grades cannot share a contract")
	check(not DeepEconomy.sign_contract(profile, refs_of(five.slice(0, 4)) + ["t:c1"]).ok, "nor can one stone go in twice")
	var poor: Dictionary = profile.duplicate(true)
	poor.gold = 5
	check(not bool(DeepEconomy.contract_preview(poor, refs_of(five)).ready), "a purse short of the fee cannot sign")
	var signed: Dictionary = DeepEconomy.sign_contract(profile, refs_of(five))
	check(signed.ok and int(profile.gold) == 480, "signing takes the fee: %s" % str(signed.get("error", "")))
	var made: Dictionary = signed.get("stone", {})
	check(not profile.tray.any(func(s: Dictionary) -> bool: return str(s.id) in ["c1", "c2", "c3", "c4", "c5"]), "the five are gone")
	check(profile.tray.has(made) and bool(made.appraised) and str(made.provenance.source) == "contract", "the new stone waits on the tray, read")
	check(str(DeepStone.grade(made).tier) == "FINE" and DeepStone.color(made) in ["RED", "BLUE"] and not DeepStone.is_fragile(made), "it is Fine, Red or Blue, and sound: %s" % DeepStone.name(made))
	check(int(profile.records.contracts) == 1, "the ledger counts it")
	## Always the next grade, whatever the seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var wrong: int = 0
	for trial in range(40):
		var trader: Dictionary = DeepProfile.new_profile("T%d" % trial)
		trader.gold = 9999
		var batch: Array = []
		var skills: Array = ["STRIKE", "GUARD", "MEND", "VENOM", "TITHE", "GLIMMER"]
		for i in range(5):
			batch.append(graded(str(skills[rng.randi_range(0, skills.size() - 1)]), rng.randi_range(2, 4), rng.randi_range(0, 2), clear, "t%d_%d" % [trial, i]))
		for s in batch:
			trader.tray.append(s)
		var out: Dictionary = DeepEconomy.sign_contract(trader, refs_of(batch))
		if not bool(out.ok) or str(DeepStone.grade(out.stone).tier) != "FINE":
			wrong += 1
		elif not batch.any(func(s: Dictionary) -> bool: return DeepStone.color(s) == DeepStone.color(out.stone)):
			wrong += 1
	check(wrong == 0, "forty contracts of Rough stones all came out Fine, in one of their colors (%d did not)" % wrong)
	## The deepest of the five decides the rock.
	var deep: Dictionary = DeepProfile.new_profile("Deep")
	deep.gold = 999
	var mix: Array = [graded("STRIKE", 3, 1, clear, "d1"), graded("STRIKE", 3, 1, clear, "d2", "SEEPS"), graded("GUARD", 3, 1, clear, "d3"), graded("GUARD", 3, 1, clear, "d4", "GLASS_VEINS"), graded("MEND", 3, 1, clear, "d5")]
	for s in mix:
		deep.tray.append(s)
	var deep_preview: Dictionary = DeepEconomy.contract_preview(deep, refs_of(mix))
	check(str(deep_preview.mine) == "GLASS_VEINS", "a stone from the Glass Veins puts the contract in the Glass Veins' rock")
	var from_deep: Dictionary = DeepEconomy.sign_contract(deep, refs_of(mix)).get("stone", {})
	check(DeepForge.skill_pool(DeepContent.mine("GLASS_VEINS")).has(str(from_deep.get("skill", ""))), "and its skill comes out of that rock")
	## Carat is capped at the rock's limit, and a promise that cannot be kept is refused.
	var heavy: Dictionary = DeepProfile.new_profile("Heavy")
	heavy.gold = 999
	var light_precious: Array = []
	for i in range(5):
		light_precious.append(graded("STRIKE", 12, 4, flawless, "h%d" % i))
	for s in light_precious:
		heavy.tray.append(s)
	var capped: Dictionary = DeepEconomy.contract_preview(heavy, refs_of(light_precious))
	check(int(capped.carat) == int(DeepForge.carat_band(DeepContent.mine("QUARRY"), 1).cap), "twelve-carat stones from the Quarry make one no heavier than the Quarry's cap (%d)" % int(capped.carat))
	check(not bool(capped.feasible) and not bool(capped.ready) and str(capped.reason).contains("carats"), "and at that weight nothing can be Exquisite: %s" % str(capped.reason))
	## Exquisite into Peerless, when the five are heavy enough.
	var best: Dictionary = DeepProfile.new_profile("Best")
	best.gold = 999
	var exquisite: Array = []
	for i in range(5):
		exquisite.append(graded("STRIKE", 18, 4, flawless, "x%d" % i, "GEODE"))
	for s in exquisite:
		best.tray.append(s)
	var peerless: Dictionary = DeepEconomy.sign_contract(best, refs_of(exquisite))
	check(peerless.ok and str(DeepStone.grade(peerless.stone).tier) == "PEERLESS" and int(best.gold) == 599, "five Exquisite stones make a Peerless one, for 400 gold: %s" % str(peerless.get("error", "")))
	## A vault stone can go in: its skill is no longer kept, and no loadout sets it.
	var keeper: Dictionary = DeepProfile.new_profile("Keeper")
	keeper.gold = 99
	check(str(DeepStone.grade(keeper.vault.STRIKE).tier) == "ROUGH" and keeper.characters.ARDOR.rail.has("STRIKE"), "a new workshop keeps a Rough Strike, set on Ardor's rail")
	var with_vault: Array = [graded("GUARD", 3, 1, clear, "k1"), graded("MEND", 3, 1, clear, "k2"), graded("VENOM", 3, 1, clear, "k3"), graded("TITHE", 3, 1, clear, "k4")]
	for s in with_vault:
		keeper.tray.append(s)
	var vault_preview: Dictionary = DeepEconomy.contract_preview(keeper, refs_of(with_vault) + ["v:STRIKE"])
	check(bool(vault_preview.ready) and vault_preview.vault == ["STRIKE"], "a vault stone is offered, and named as one: %s" % str(vault_preview.get("error", vault_preview.reason)))
	check(DeepEconomy.sign_contract(keeper, refs_of(with_vault) + ["v:STRIKE"]).ok and not keeper.vault.has("STRIKE") and not keeper.characters.ARDOR.rail.has("STRIKE"),
		"signed, the vault no longer keeps a Strike and Ardor's rail lets it go")

func _test_no_profit_chains() -> void:
	## Cracking Geodes to sell what comes out loses gold, and so does putting five of their
	## stones into a contract and selling what that makes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for key in ["QUARRY", "SEEPS", "GLASS_VEINS", "FURNACE", "GEODE"]:
		var geode: Dictionary = geode_of("mine", key, key)
		var price: int = DeepEconomy.geode_price(geode)
		var by_tier: Dictionary = {}
		var sold: int = 0
		for i in range(300):
			var made: Dictionary = DeepEconomy.roll_geode_stone(rng, geode, "np_%s_%d" % [key, i])
			made.appraised = true
			sold += DeepStone.value(made)
			var tier: String = str(DeepStone.grade(made).tier)
			if not by_tier.has(tier):
				by_tier[tier] = []
			if DeepEconomy.contract_refusal(made).is_empty():
				by_tier[tier].append(made)
		check(sold < price * 300, "%s: three hundred Geodes sold on cost more than they fetch (%d against %d)" % [key, sold, price * 300])
		var spent: int = 0
		var fetched: int = 0
		for tier in by_tier:
			var stones: Array = by_tier[tier]
			while stones.size() >= 5:
				var trader: Dictionary = DeepProfile.new_profile("np")
				trader.gold = 99999
				var five: Array = stones.slice(0, 5)
				stones = stones.slice(5)
				for s in five:
					trader.tray.append(s)
				var out: Dictionary = DeepEconomy.sign_contract(trader, refs_of(five))
				if bool(out.ok):
					spent += price * 5 + int(out.paid)
					fetched += DeepStone.value(out.stone)
		check(fetched < spent or spent == 0, "%s: five Geodes' stones traded up and sold fetch less than they cost (%d against %d)" % [key, fetched, spent])

# --- the daily dig --------------------------------------------------------------------------------

func _test_daily_plan() -> void:
	var plan: Dictionary = DeepEconomy.daily_plan("2026-10-10")
	check(JSON.stringify(plan) == JSON.stringify(DeepEconomy.daily_plan("2026-10-10")), "a day's seam is the same wherever it is asked for")
	check(str(plan.mine) == DeepContent.starter_mine(), "it starts in the first mine: %s" % str(plan.mine))
	check(DeepContent.characters_in_unlock_order().has(plan.lapidary), "the whole party goes down as one lapidary: %s" % str(plan.lapidary))
	check(str(DeepEconomy.daily_mod(str(plan.rail)).kind) == "rail", "a rail rule: %s" % str(plan.rail))
	var kinds: Array = plan.mods.map(func(k: String) -> String: return str(DeepEconomy.daily_mod(k).kind))
	check(kinds == ["hazard", "blessing", "twist"], "a hazard, a blessing and a twist: %s" % str(plan.mods))
	## Over half a year of days: never two cards of one group, every card turns up, and the
	## days differ.
	var clashes: int = 0
	var seen: Dictionary = {}
	var differs: bool = false
	for day in range(180):
		var date: String = Time.get_date_string_from_unix_time(1791590400 + day * 86400)
		var other: Dictionary = DeepEconomy.daily_plan(date)
		var groups: Array = []
		for key in [str(other.rail)] + other.mods:
			seen[str(key)] = true
			var group: String = str(DeepEconomy.daily_mod(str(key)).get("group", ""))
			if not group.is_empty():
				if groups.has(group):
					clashes += 1
				groups.append(group)
		differs = differs or other.mods != plan.mods or other.lapidary != plan.lapidary
	check(clashes == 0, "no day deals two cards of one group (%d did)" % clashes)
	check(seen.size() == DeepEconomy.daily_modifiers().size(), "every card turns up in half a year (%d of %d)" % [seen.size(), DeepEconomy.daily_modifiers().size()])
	check(differs, "and another day brings another seam")
	var version: Variant = DeepContent.pack().get("version", 1)
	DeepContent.pack().version = int(version) + 1
	var changed: int = DeepEconomy.daily_seed("2026-10-10")
	DeepContent.pack().version = version
	check(changed != DeepEconomy.daily_seed("2026-10-10"), "a different pack never claims the same seam")
	## The rail each rule lends.
	var character: String = str(plan.lapidary)
	var sockets: Array = DeepContent.character(character).sockets
	for rule in DeepEconomy.daily_modifiers("rail"):
		var ruled: Dictionary = plan.duplicate(true)
		ruled.rail = str(rule)
		ruled.mods = []
		if str(rule) == "ONE_TRICK":
			ruled.trick = DeepEconomy._trick_skill(RandomNumberGenerator.new(), character, str(plan.mine))
		var rail: Array = DeepEconomy.daily_rail(ruled, character, 0)
		var filled: Array = rail.filter(func(s: Variant) -> bool: return s is Dictionary)
		check(rail.size() == sockets.size(), "%s: one place a socket" % str(rule))
		match str(rule):
			"LENT_RAIL":
				var sound: bool = filled.size() == sockets.size()
				for index in range(rail.size()):
					var lent: Variant = rail[index]
					sound = sound and lent is Dictionary and DeepStone.fits(lent, str(sockets[index])) and bool(lent.temporary) and bool(lent.lent) and DeepStone.is_fragile(lent) and bool(lent.appraised) and not lent.inclusions.has("VOID")
				check(sound, "Lent Rail: every socket holds a read, lent stone of its color")
				check(JSON.stringify(rail) == JSON.stringify(DeepEconomy.daily_rail(ruled, character, 0)), "and the same rail every time")
			"ONE_TRICK":
				var one: bool = not filled.is_empty() and filled.all(func(s: Dictionary) -> bool: return str(s.skill) == str(ruled.trick))
				for index in range(rail.size()):
					if rail[index] is Dictionary:
						one = one and DeepStone.fits(rail[index], str(sockets[index]))
				check(one, "One Trick: one skill in every socket that takes it (%d of %d)" % [filled.size(), sockets.size()])
			_:
				check(filled.is_empty(), "%s: the rail starts empty" % str(rule))
	var bags: Dictionary = {}
	for rule in ["SEALED_TRAY", "BIG_HAUL", "LENT_RAIL"]:
		var ruled: Dictionary = plan.duplicate(true)
		ruled.rail = rule
		bags[rule] = DeepEconomy.daily_bag(ruled, character, 0)
	check(bags.SEALED_TRAY.size() == DeepEconomy.SEALED_TRAY_STONES and bags.SEALED_TRAY.all(func(s: Dictionary) -> bool: return bool(s.appraised) and bool(s.lent)), "Sealed Tray: a dozen read, lent stones in the bag")
	check(bags.BIG_HAUL.size() == DeepEconomy.BIG_HAUL_STONES and bags.BIG_HAUL.all(func(s: Dictionary) -> bool: return not bool(s.appraised) and bool(s.lent)), "The Big Haul: a bag of raw, lent stones")
	check(bags.LENT_RAIL.is_empty(), "and every other rule leaves the bag empty")
	var gifts: Dictionary = plan.duplicate(true)
	gifts.rail = "BARE_HANDS"
	gifts.mods = ["HEIRLOOM", "BORROWED_OPAL"]
	var gifted: Array = DeepEconomy.daily_rail(gifts, character, 0).filter(func(s: Variant) -> bool: return s is Dictionary)
	check(gifted.any(func(s: Dictionary) -> bool: return DeepStone.TIERS.find(str(DeepStone.grade(s).tier)) >= DeepStone.TIERS.find("EXQUISITE")), "Heirloom: an Exquisite stone, even on a bare rail")
	check(gifted.any(func(s: Dictionary) -> bool: return DeepStone.is_opal(s)), "A Borrowed Opal: an opal in an Any socket")

func daily_with(mods: Array, rail: String = "LENT_RAIL", seed_value: int = 70, players: int = 2) -> Dictionary:
	## A day's run on the 10th of October with these cards in place of the day's own.
	var seats: Array = [{"id": "a", "name": "Ada"}, {"id": "b", "name": "Bo"}].slice(0, players)
	var plan: Dictionary = DeepEconomy.daily_plan("2026-10-10")
	var config: Dictionary = DeepEconomy.daily_config("2026-10-10", seats, "daily_test%d" % seed_value)
	config.daily.mods = mods
	config.daily.rail = rail
	config.daily.drought = "RED"
	config.daily.birthstone = "FLORIN" if str(plan.lapidary) != "FLORIN" else "ARDOR"
	config.seed = seed_value
	if rail != str(plan.rail) or not mods.is_empty():
		## Rails and bags are dealt by the day's own rules, so a test of another rule asks for them.
		var ruled: Dictionary = plan.duplicate(true)
		ruled.rail = rail
		ruled.mods = mods
		if rail == "ONE_TRICK":
			ruled.trick = DeepEconomy._trick_skill(RandomNumberGenerator.new(), str(plan.lapidary), str(plan.mine))
		for seat in range(config.players.size()):
			config.players[seat].rail = DeepEconomy.daily_rail(ruled, str(plan.lapidary), seat)
			config.players[seat].bag = DeepEconomy.daily_bag(ruled, str(plan.lapidary), seat)
	return DeepDescent.new_run(config)

func fight_of(run: Dictionary, warden: String = "", elite: bool = false, depth: int = 3) -> Dictionary:
	run.phase = "chamber"
	run.depth = depth
	run.chamber = {"kind": "warden" if not warden.is_empty() else ("elite" if elite else "fight"), "depth": depth, "settled": false}
	DeepDescent._start_fight(run, DeepDescent.streams_of(run), elite, warden)
	return run.chamber.battle

func _test_daily_run() -> void:
	var plan: Dictionary = DeepEconomy.daily_plan("2026-10-10")
	var config: Dictionary = DeepEconomy.daily_config("2026-10-10", [{"id": "a", "name": "Ada"}, {"id": "b", "name": "Bo"}])
	check(str(config.run_id).begins_with("daily") and int(config.seed) == int(plan.seed) and str(config.mine) == DeepContent.starter_mine(), "the party digs the day's seed from the top of the first mine")
	var state: Dictionary = DeepDescent.new_run(config)
	check(state.daily.date == "2026-10-10" and state.daily.mods == plan.mods and str(state.daily.rail) == str(plan.rail), "the run knows it is the day's seam, and its cards")
	for seat in range(2):
		var unit: Dictionary = state.players[seat]
		check(str(unit.character) == str(plan.lapidary), "seat %d goes down as the day's lapidary" % seat)
		check(unit.get("dice_offers", []).is_empty(), "with nothing offered for the deep")
	check(DeepEconomy.charge_departure(DeepProfile.new_profile("Free"), state, "a").is_empty(), "the day's seam costs nothing to go down")
	check(DeepDescent.results(state).daily.date == "2026-10-10", "the results say the run was the day's seam")
	## The rail rules, at the shaft head.
	var draft: Dictionary = DeepDescent.player(daily_with([], "DRAFT"), "a")
	check(draft.temps.size() == DeepStone.socket_count(draft) and draft.temps.all(func(o: Dictionary) -> bool: return o.picks.size() == 3), "Draft: three picks for every socket")
	check(DeepDescent.player(daily_with([], "SEALED_TRAY"), "a").haul.size() == DeepEconomy.SEALED_TRAY_STONES, "Sealed Tray: the stones wait in the bag")
	check(DeepDescent.player(daily_with([], "BIG_HAUL"), "a").haul.size() == DeepEconomy.BIG_HAUL_STONES, "The Big Haul: so does the haul")
	check(DeepStone.rail_stones(DeepDescent.player(daily_with([], "BARE_HANDS"), "a")).is_empty(), "Bare Hands: nothing set but the Birthstone")
	## What the cards do to a lapidary before the first floor.
	var plain: Dictionary = daily_with([])
	var ada: Dictionary = DeepDescent.player(plain, "a")
	var air: Dictionary = DeepDescent.player(daily_with(["BAD_AIR"]), "a")
	check(int(air.hp) == int(ceil(float(air.max_hp) * 0.75)) and int(ada.hp) == int(ada.max_hp), "Bad Air: everyone starts a quarter short")
	var hardy: Dictionary = DeepDescent.player(daily_with(["HARDY"]), "a")
	check(int(hardy.max_hp) == int(ceil(float(ada.max_hp) * 1.25)) and int(hardy.hp) == int(hardy.max_hp), "Hardy: a quarter more max health")
	var lungs: Dictionary = daily_with(["GLASS_LUNGS"])
	check(int(DeepDescent.player(lungs, "a").max_hp) == int(ada.max_hp) / 2, "Glass Lungs: half the max health")
	check(int(DeepDescent.player(daily_with(["DEEP_POCKETS"]), "a").ore) == int(ada.ore) + 100, "Deep Pockets: a hundred pyrite")
	var steady: Dictionary = DeepDescent.player(daily_with(["STEADY_HANDS"]), "a")
	check(int(steady.run_mods.extra_rerolls.amount) == 1 and int(steady.run_mods.extra_rerolls.until_depth) == DeepDescent.landing_every(), "Steady Hands: a reroll more down to the first landing")
	check(DeepDescent.player(daily_with(["COLORBLIND"]), "a").sockets.all(func(s: Variant) -> bool: return str(s) == DeepContent.SOCKET_ANY), "Colorblind: every socket takes any stone")
	var borrowed: Dictionary = DeepDescent.player(daily_with(["BORROWED_BIRTHSTONE"]), "a")
	check(str(borrowed.birthstone_of) != str(borrowed.character) and str(DeepStone.birthstone_for(borrowed).character) == str(borrowed.birthstone_of)
		and JSON.stringify(borrowed.birthstone) == JSON.stringify(DeepContent.character(str(borrowed.birthstone_of)).birthstone), "Borrowed Birthstone: another lapidary's, fired and drawn")
	check(DeepDescent.player(daily_with(["EXTRA_DIE"]), "a").dice.size() == ada.dice.size() + 1, "An Extra Die: one more die in the bowl")
	var sizes := func(unit: Dictionary) -> Array: return unit.dice.map(func(d: Dictionary) -> int: return DeepDice.TIERS.find(str(d.shape)))
	var base: Array = sizes.call(ada)
	var big: Array = sizes.call(DeepDescent.player(daily_with(["BIG_BONES"]), "a"))
	var small: Array = sizes.call(DeepDescent.player(daily_with(["SMALL_BONES"]), "a"))
	var grew: bool = true
	var shrank: bool = true
	for i in range(base.size()):
		grew = grew and (int(big[i]) == int(base[i]) + 1 or int(base[i]) == DeepDice.TIERS.size() - 1)
		shrank = shrank and (int(small[i]) == int(base[i]) - 1 or int(base[i]) == 0)
	check(grew and shrank, "Big Bones and Small Bones: every die a size up or down")
	var gamblers: Dictionary = DeepDescent.player(daily_with(["GAMBLERS_BOWL"]), "a")
	check(gamblers.dice.all(func(d: Dictionary) -> bool: return str(d.pattern) == "gamblers" or not DeepDice.pattern_allows("gamblers", str(d.shape))), "Gambler's Bowl: every die that can take it")
	for entry in [["BLANK_FACES", "blank", true], ["FIREWORKS", "exploding", true], ["GOLDEN_FACES", "golden", false], ["TALLY_MARKS", "tally", false]]:
		var dressed: Dictionary = DeepDescent.player(daily_with([entry[0]]), "a")
		var right: bool = true
		for die in dressed.dice:
			var faces: Array = die.faces
			var pick: int = 0
			for index in range(faces.size()):
				var value: int = int(ada.dice[0].faces[0].value)
				if (bool(entry[2]) and int(faces[index].value) > int(faces[pick].value)) or (not bool(entry[2]) and int(faces[index].value) < int(faces[pick].value)):
					pick = index
			right = right and str(faces[pick].kind) == str(entry[1])
		check(right, "%s: every die's %s face is %s" % [str(entry[0]), "highest" if bool(entry[2]) else "lowest", str(entry[1])])
	for key in DeepDescent.DAILY_MATERIAL:
		var made: Dictionary = DeepDescent.player(daily_with([key]), "a")
		check(made.dice.all(func(d: Dictionary) -> bool: return str(d.material) == str(DeepDescent.DAILY_MATERIAL[key])), "%s: every die is %s" % [str(key), str(DeepDescent.DAILY_MATERIAL[key])])
	var wild: Dictionary = DeepDescent.player(daily_with(["WILD_CARD"]), "a")
	var wild_faces: int = 0
	for die in wild.dice:
		wild_faces += die.faces.filter(func(f: Dictionary) -> bool: return str(f.kind) == "wild").size()
	check(wild_faces == 1, "Wild Card: one wild face on the biggest die")
	## What the cards do to the rock.
	var plain_mine: Dictionary = DeepDescent.mine_of(plain)
	check(DeepForge.mine_luck(DeepDescent.mine_of(daily_with(["RICH_SEAMS"]))) == DeepForge.mine_luck(plain_mine) + 1, "Rich Seams: the rock rolls a point luckier")
	check(DeepForge.mine_luck(DeepContent.mine(str(plain.mine))) == DeepForge.mine_luck(plain_mine), "and the pack itself is never touched")
	var heavy_mine: Dictionary = DeepDescent.mine_of(daily_with(["HEAVY_ROCK"]))
	check(int(heavy_mine.carat.cap) == int(plain_mine.carat.cap) + 2 and int(heavy_mine.carat.soft) == int(plain_mine.carat.soft) + 2, "Heavy Rock: the band two carats heavier")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var rolled := func(mine: Dictionary) -> Array:
		var out: Array = []
		for i in range(200):
			out.append(DeepForge.roll_stone(rng, mine, 8, 0.0, {}, "t%d" % i))
		return out
	check(not rolled.call(DeepDescent.mine_of(daily_with(["DROUGHT"]))).any(func(s: Dictionary) -> bool: return DeepStone.color(s) == "RED"), "Drought: two hundred stones and not one of the day's color")
	check(rolled.call(DeepDescent.mine_of(daily_with(["CLEAR_WATER"]))).all(func(s: Dictionary) -> bool: return int(s.clarity) >= DeepContent.clear_index() and s.inclusions.is_empty()), "Clear Water: every stone clear, nothing inside")
	check(rolled.call(DeepDescent.mine_of(daily_with(["FLAWED"]))).all(func(s: Dictionary) -> bool: return not s.inclusions.is_empty()), "Flawed: every stone has something inside")
	var voids: int = rolled.call(DeepDescent.mine_of(daily_with(["VOID_SEASON"]))).filter(func(s: Dictionary) -> bool: return s.inclusions.has("VOID")).size()
	var usual: int = rolled.call(plain_mine).filter(func(s: Dictionary) -> bool: return s.inclusions.has("VOID")).size()
	check(voids > usual * 2 + 2, "Void Season: Void far more often (%d against %d)" % [voids, usual])
	check(rolled.call(DeepDescent.mine_of(daily_with(["LAMPLIGHT"]))).all(func(s: Dictionary) -> bool: return bool(s.get("appraised", false))), "Lamplight: every stone comes out read")
	check(float(DeepDescent.mine_of(daily_with(["MOTHERLODE"])).motherlode_pct) == float(plain_mine.get("motherlode_pct", 3)) * 6.0, "Motherlode: six times the motherlodes")
	## The chart.
	var chart_of := func(run: Dictionary, stretches: int) -> Array:
		var nodes: Array = []
		for stretch in range(stretches):
			run.depth = stretch * 4
			DeepDescent._chart(run, DeepDescent.streams_of(run))
			nodes.append(run.map)
		return nodes
	var road: Array = chart_of.call(daily_with(["ONE_ROAD"]), 3)
	check(road.all(func(m: Dictionary) -> bool: return m.rows.all(func(r: Array) -> bool: return r.size() == 1)), "One Road: one chamber a floor")
	var kinds_in := func(maps: Array, kind: String) -> int:
		var count: int = 0
		for m in maps:
			for id in m.nodes:
				if str(m.nodes[id].kind) == kind:
					count += 1
		return count
	check(kinds_in.call(chart_of.call(daily_with(["CLOSED_STALLS"]), 4), "merchant") == 0, "Closed Stalls: no merchant on four stretches")
	var midas: Array = chart_of.call(daily_with(["MIDAS"]), 4)
	check(kinds_in.call(midas, "smithy") + kinds_in.call(midas, "carver") + kinds_in.call(midas, "vat") == 0, "Midas: no Smithy, Carver or Vat")
	var altars: Array = chart_of.call(daily_with(["ALTAR_LIGHTS"]), 3)
	check(altars.all(func(m: Dictionary) -> bool: return m.nodes.values().any(func(n: Dictionary) -> bool: return str(n.kind) == "altar")), "Altar Lights: an altar in every stretch, the first included")
	check(float(DeepDescent.mine_of(daily_with(["BIG_GAME"])).chambers.elite) == float(plain_mine.chambers.elite) * 2.0, "Big Game: twice the elites")
	check(float(DeepDescent.mine_of(daily_with(["STRANGE_DAY"])).chambers.oddity) == float(plain_mine.chambers.oddity) * 3.0, "Strange Day: three times the oddities")
	## Fights.
	var soft: Dictionary = fight_of(daily_with([], "LENT_RAIL", 71))
	var hard: Dictionary = fight_of(daily_with(["HARD_ROCK"], "LENT_RAIL", 71))
	var tough: float = float(hard.enemies[0].max_hp) / float(soft.enemies[0].max_hp)
	check(tough > 1.15 and tough < 1.35, "Hard Rock: creatures a quarter tougher (%.2f)" % tough)
	var claws: Dictionary = fight_of(daily_with(["SHARP_CLAWS"], "LENT_RAIL", 71))
	check(is_equal_approx(float(claws.enemies[0].damage_mult), float(soft.enemies[0].damage_mult) * 1.25), "Sharp Claws: a quarter more damage")
	var warden: String = DeepDescent.warden_key(plain, 8)
	var calm: Dictionary = fight_of(daily_with([], "LENT_RAIL", 72), warden, false, 8)
	var wrath_run: Dictionary = daily_with(["WARDENS_WRATH"], "LENT_RAIL", 72)
	var wrath: Dictionary = fight_of(wrath_run, warden, false, 8)
	var harder: float = float(wrath.enemies[0].max_hp) / float(calm.enemies[0].max_hp)
	check(harder > 1.4 and harder < 1.6, "Warden's Wrath: Wardens half again as tough (%.2f)" % harder)
	DeepDescent._offer_hoard(wrath_run)
	check(wrath_run.hoard.a.offers.size() == DeepDescent.HOARD_OFFERS + 1, "and one more pedestal in the hoard")
	var hoard: Dictionary = daily_with(["GENEROUS_HOARDS"])
	hoard.depth = 8
	DeepDescent._offer_hoard(hoard)
	check(hoard.hoard.a.offers.size() == DeepDescent.HOARD_OFFERS + 1, "Generous Hoards: a fourth pedestal")
	check(fight_of(daily_with(["TORPOR"], "LENT_RAIL", 71)).enemies.all(func(e: Dictionary) -> bool: return int(e.statuses.get("stun", 0)) >= 1), "Torpor: every creature stunned on its first turn")
	var swarm: Dictionary = fight_of(daily_with(["SWARMS"], "LENT_RAIL", 71))
	var lone: Dictionary = fight_of(daily_with(["LONE_BEASTS"], "LENT_RAIL", 71))
	var pack_hp: int = 0
	for foe in soft.enemies:
		pack_hp += int(foe.max_hp)
	check(swarm.enemies.size() >= soft.enemies.size() + 1 or soft.enemies.size() >= DeepBattle.max_creatures(), "Swarms: one creature more (%d against %d)" % [swarm.enemies.size(), soft.enemies.size()])
	check(lone.enemies.size() == 1 and (soft.enemies.size() == 1 or int(lone.enemies[0].max_hp) == pack_hp), "Lone Beasts: one creature with the group's health")
	var plated_run: Dictionary = daily_with(["PLATED"], "LENT_RAIL", 71)
	var plated: Dictionary = fight_of(plated_run)
	check(plated.players.all(func(p: Dictionary) -> bool: return int(p.block) >= 6), "Plated: six Block as every fight begins")
	var plated_max: int = int(DeepDescent.player(plated_run, "a").max_hp)
	DeepDescent._settle_fight(plated_run, "victory")
	check(int(DeepDescent.player(plated_run, "a").max_hp) == plated_max - 1, "and a point of max health gone after it")
	var shaky: Dictionary = fight_of(daily_with(["SHAKY_HANDS"], "LENT_RAIL", 71))
	check(int(shaky.players[0].rerolls_max) == int(soft.players[0].rerolls_max) - 1, "Shaky Hands: one reroll fewer")
	var short: Dictionary = fight_of(daily_with(["SHORT_HANDED"], "LENT_RAIL", 71))
	check(short.players[0].hand.size() == soft.players[0].hand.size() - 1, "Short-Handed: the smallest die sits the throw out")
	var wind_run: Dictionary = daily_with(["SECOND_WIND"], "LENT_RAIL", 71)
	var wind: Dictionary = fight_of(wind_run)
	check(wind.players.all(func(p: Dictionary) -> bool: return int(p.statuses.get("lifeline", 0)) >= int(ceil(float(p.max_hp) / 2.0))), "Second Wind: ready to get back up")
	wind.players[0].lifeline_used = true
	DeepDescent._settle_fight(wind_run, "victory")
	check(int(DeepDescent.player(wind_run, "a").run_mods.second_wind) == 0, "and spent once it has")
	var cursed_run: Dictionary = daily_with(["CURSED_RUN"], "LENT_RAIL", 72)
	fight_of(cursed_run, warden, false, 8)
	var settled: Dictionary = DeepDescent._settle_fight(cursed_run, "victory")
	var locked: int = 0
	for die in DeepDescent.player(cursed_run, "a").dice:
		locked += die.faces.filter(func(f: Dictionary) -> bool: return str(f.kind) == "locked").size()
	check(locked == 1 and settled.has("cursed"), "Cursed Run: a beaten Warden locks a face")
	var game_run: Dictionary = daily_with(["BIG_GAME"], "LENT_RAIL", 73)
	fight_of(game_run, "", true)
	var game: Dictionary = DeepDescent._settle_fight(game_run, "victory")
	check(game.rewards.a.stones.all(func(s: Dictionary) -> bool: return bool(s.appraised)), "Big Game: what an elite drops comes out read")
	var midas_run: Dictionary = daily_with(["MIDAS"], "LENT_RAIL", 74)
	var usual_run: Dictionary = daily_with([], "LENT_RAIL", 74)
	fight_of(midas_run)
	fight_of(usual_run)
	var paid_midas: int = int(DeepDescent._settle_fight(midas_run, "victory").rewards.a.ore)
	var paid_usual: int = int(DeepDescent._settle_fight(usual_run, "victory").rewards.a.ore)
	check(paid_midas == paid_usual * 2, "Midas: a fight pays twice the pyrite (%d against %d)" % [paid_midas, paid_usual])
	## Veins, floors and landings.
	var picks: Dictionary = daily_with(["BRITTLE_PICKS"])
	var heavy: Dictionary = daily_with(["HEAVY_ROCK"])
	for run in [plain, picks, heavy]:
		run.phase = "chamber"
		run.chamber = {"kind": "vein", "vein": {"spots": [], "hazard": false}}
		DeepDescent.player(run, "a").strikes = 2
	var swing: int = DeepDescent.swing_cost(plain, DeepDescent.player(plain, "a"))
	check(DeepDescent.swing_cost(picks, DeepDescent.player(picks, "a")) == swing * 2, "Brittle Picks: every swing costs twice")
	check(DeepDescent.swing_cost(heavy, DeepDescent.player(heavy, "a")) == int(ceil(float(swing) * 1.5)), "Heavy Rock: and half again on a heavy day")
	var bleeding: Dictionary = daily_with(["BLEEDING"])
	bleeding.offers = [ {"id": "x", "kind": "vein", "hidden": false}]
	var before: int = int(DeepDescent.player(bleeding, "a").hp)
	DeepDescent._enter(bleeding, bleeding.offers[0], DeepDescent.streams_of(bleeding))
	check(int(DeepDescent.player(bleeding, "a").hp) == before - 2, "Bleeding: a floor down costs two health")
	var tolls: Dictionary = daily_with(["TOLLS"])
	DeepDescent.player(tolls, "a").ore = 200
	tolls.depth = 3
	DeepDescent._enter(tolls, {"id": "landing", "kind": "landing", "hidden": false}, DeepDescent.streams_of(tolls))
	check(int(DeepDescent.player(tolls, "a").ore) == 150 and int(tolls.landing.tolls.a) == 50, "Toll Gates: a quarter of the pyrite at the landing")
	var lungs_run: Dictionary = daily_with(["GLASS_LUNGS"])
	DeepDescent.player(lungs_run, "a").hp = 3
	lungs_run.depth = 3
	DeepDescent._enter(lungs_run, {"id": "landing", "kind": "landing", "hidden": false}, DeepDescent.streams_of(lungs_run))
	check(int(DeepDescent.player(lungs_run, "a").hp) == int(DeepDescent.player(lungs_run, "a").max_hp), "Glass Lungs: every landing heals you to full")
	var restless: Dictionary = daily_with(["RESTLESS_ROCK"])
	var skills_before: Array = DeepStone.rail_stones(DeepDescent.player(restless, "a")).map(func(s: Dictionary) -> String: return str(s.skill))
	restless.depth = 3
	DeepDescent._enter(restless, {"id": "landing", "kind": "landing", "hidden": false}, DeepDescent.streams_of(restless))
	var skills_after: Array = DeepStone.rail_stones(DeepDescent.player(restless, "a")).map(func(s: Dictionary) -> String: return str(s.skill))
	check(skills_after != skills_before and not restless.landing.restless.is_empty(), "Restless Rock: the rail's stones turn into other skills at a landing")
	var bench: Dictionary = daily_with(["NO_BENCH"])
	bench.phase = "landing"
	bench.landing = {"depth": 4, "warden_next": false, "cleared": false, "respites": {}}
	check(not bool(DeepDescent._respite(bench, DeepDescent.player(bench, "a"), "rest", "").ok), "No Bench: nobody rests")
	var terrors: Dictionary = daily_with(["NIGHT_TERRORS"])
	terrors.phase = "landing"
	terrors.landing = {"depth": 4, "warden_next": false, "cleared": false, "respites": {}}
	var sleeper: Dictionary = DeepDescent.player(terrors, "a")
	var full: int = int(sleeper.max_hp)
	sleeper.hp = 5
	DeepDescent._respite(terrors, sleeper, "rest", "")
	check(int(sleeper.max_hp) < full and int(sleeper.hp) == int(sleeper.max_hp), "Night Terrors: rested to full, with less to be full of")
	var winch: Dictionary = daily_with(["TIGHT_WINCH"])
	var greased: Dictionary = daily_with(["GREASED_WINCH"])
	for run in [plain, winch, greased]:
		run.depth = 6
	check(DeepDescent.lift_cost(winch) == DeepDescent.lift_cost(plain) * 2 and DeepDescent.lift_cost(greased) == 0, "Tight Winch doubles the lift; the Greased Winch makes it free")
	var last: Dictionary = daily_with(["LAST_LIFT"])
	DeepDescent.player(last, "a").ore = 999
	DeepDescent.player(last, "b").ore = 999
	last.phase = "landing"
	last.depth = 4
	last.landing = {"depth": 4, "warden_next": false, "cleared": false, "respites": {}}
	check(not bool(DeepDescent._choose_at_landing(last, DeepDescent.player(last, "a"), "lift").ok), "Last Lift: no lift from an ordinary landing")
	last.landing.warden_next = true
	check(bool(DeepDescent._choose_at_landing(last, DeepDescent.player(last, "a"), "lift").ok), "but there is one where a Warden waits")
	check(DeepDescent.lantern_reach(daily_with(["SHORT_WICK"])) == DeepDescent.lantern_reach(plain) - 1, "Short Wick: the lantern sees a floor less")
	## Stalls.
	var market: Dictionary = daily_with(["MARKET_DAY"])
	var dear: Dictionary = daily_with([])
	for run in [market, dear]:
		run.phase = "chamber"
		run.depth = 3
		run.chamber = {"kind": "merchant", "depth": 3, "settled": false}
		DeepDescent._open_stall(run, DeepDescent.streams_of(run))
	var cheap: Dictionary = DeepDescent.stall_stock(market, "a")[0]
	check(int(cheap.price) == DeepStone.value(cheap.stone), "Market Day: a stone for its worth, half the usual price")
	var collector: Dictionary = daily_with(["COLLECTORS_DAY"])
	var sold: Dictionary = stone("VENOM", 4, 2, DeepContent.clear_index(), "sold_one")
	sold.appraised = true
	DeepDescent.player(collector, "a").haul.append(sold)
	collector.phase = "chamber"
	collector.chamber = {"kind": "merchant", "depth": 3, "settled": false, "stock": {}, "appraisals": {}}
	var sale: Dictionary = DeepDescent._sell(collector, DeepDescent.player(collector, "a"), "sold_one")
	check(bool(sale.ok) and int(sale.event.paid) == DeepStone.value(sold), "Collector's Day: full worth for a stone")
	## Wells.
	var well_rng := RandomNumberGenerator.new()
	well_rng.seed = 3
	var bright: Dictionary = DeepOddities.apply({"kind": "wishing_well", "mode": "ore"}, {"ore": 200, "stats": {}, "haul": []}, {"ore": 100}, well_rng, {"mine": DeepContent.mine("QUARRY"), "depth": 4, "run": "w", "well_mult": 1.5})
	check(int(bright.get("well", {}).get("worth", 0)) == 150, "Bright Well: an offering weighs half again (%s)" % str(bright.get("well", bright.get("error", ""))))
	var landing: Dictionary = daily_with(["BRIGHT_WELL"])
	landing.phase = "landing"
	landing.landing = {"depth": 4, "warden_next": false, "cleared": false, "respites": {}}
	DeepDescent.player(landing, "a").ore = 500
	var wished: Dictionary = DeepDescent._respite(landing, DeepDescent.player(landing, "a"), "wish", "", 100)
	check(wished.ok and int(wished.event.get("well", {}).get("worth", 0)) == 150, "and so does the well at a landing")

func _test_daily_rewards() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Daily")
	profile.mines.QUARRY.boss = true
	check(DeepEconomy.daily_state(profile, "2026-10-10") == "fresh", "a lapidary who has beaten the Quarry may be paid for the day's seam")
	check(DeepEconomy.daily_state(DeepProfile.new_profile("New"), "2026-10-10") == "locked", "one who has not may not")
	var state: Dictionary = DeepDescent.new_run(DeepEconomy.daily_config("2026-10-10", [{"id": "a", "name": "Ada"}], "daily_one"))
	var first: Dictionary = DeepEconomy.begin_daily(profile, state)
	check(bool(first.eligible) and int(first.best_score) == 0 and int(profile.dig.runs) == 1 and DeepEconomy.daily_state(profile, "2026-10-10") == "played", "the first attempt of the day is written down")
	check(bool(DeepEconomy.begin_daily(profile, state).get("again", false)) and int(profile.dig.runs) == 1, "the same run picked up again is still that attempt")
	## The score: the worth of what came up, and the pyrite, unless the party fell.
	var found: Dictionary = stone("VENOM", 4, 1, 3, "dug")
	var lent: Dictionary = stone("STRIKE", 6, 3, 3, "lent")
	lent.lent = true
	var result: Dictionary = {"run_id": "daily_one", "mine": "QUARRY", "from_mine": "QUARRY", "outcome": "extracted", "depth": 9, "deepest": 9, "wardens": [8],
		"mines": [{"mine": "QUARRY", "deepest": 9, "wardens": [8], "boss": false}], "daily": {"date": "2026-10-10", "rail": "LENT_RAIL", "mods": []},
		"players": {"a": {"haul": [found], "home": [found, lent], "dice": [], "stats": {}, "ore": 140, "earned": 140}}}
	var scored: Dictionary = DeepEconomy.daily_score(result, "a")
	check(int(scored.worth) == DeepStone.value(found) and int(scored.pyrite) == 140 and int(scored.score) == DeepStone.value(found) + 140, "a score is the stones' worth and the pyrite, never a lent stone (%s)" % str(scored.score))
	var fell: Dictionary = result.duplicate(true)
	fell.outcome = "fallen"
	check(int(DeepEconomy.daily_score(fell, "a").score) == DeepStone.value(found), "a fall scores only the stones the salvage saved")
	var knee: int = int(DeepContent.constant("daily_score_knee", 1000))
	var rate: float = float(DeepContent.constant("daily_score_rate", 0.5))
	check(DeepEconomy.daily_payout(400) == int(400 * rate) and DeepEconomy.daily_payout(knee + 400) == int(knee * rate + 400 * rate / 2.0), "a score pays at its rate, and half that past the knee")
	## Paid at home, and nothing kept.
	var runs_before: int = int(profile.records.runs)
	var mines_before: String = JSON.stringify(profile.mines)
	var gold_before: int = int(profile.gold)
	var applied: Dictionary = DeepProfile.apply_result(profile, result, "a")
	var worth: int = DeepEconomy.daily_payout(int(scored.score))
	check(int(applied.daily.paid) == worth and int(profile.gold) == gold_before + worth, "the first dig is paid its score's worth: %d gold" % worth)
	check(profile.tray.is_empty() and profile.bowl.size() == DeepProfile.new_profile("x").bowl.size(), "and nothing it found comes home")
	check(JSON.stringify(profile.mines) == mines_before and int(profile.records.runs) == runs_before and int(profile.records.dailies) == 1, "it opens no mine and writes no mine's records")
	check(bool(profile.history.back().daily) and int(profile.history.back().score) == int(scored.score), "the ledger keeps its score")
	check(int(profile.dig.best_score) == int(scored.score) and int(profile.dig.best_gold) == worth, "and the day's best is raised")
	## Again the same day: only what it adds.
	var again: Dictionary = DeepDescent.new_run(DeepEconomy.daily_config("2026-10-10", [{"id": "a", "name": "Ada"}], "daily_two"))
	DeepEconomy.begin_daily(profile, again)
	check(int(profile.dig.runs) == 2, "a second attempt is written down too")
	var worse: Dictionary = result.duplicate(true)
	worse.run_id = "daily_two"
	worse.players.a.ore = 10
	var gold_then: int = int(profile.gold)
	var worse_paid: Dictionary = DeepProfile.apply_result(profile, worse, "a")
	check(int(worse_paid.daily.paid) == 0 and int(profile.gold) == gold_then and int(profile.dig.best_score) == int(scored.score), "a lower score pays nothing and leaves the best alone")
	var better: Dictionary = result.duplicate(true)
	better.run_id = "daily_three"
	better.players.a.ore = 2400
	var better_score: int = DeepStone.value(found) + 2400
	gold_then = int(profile.gold)
	var better_paid: Dictionary = DeepProfile.apply_result(profile, better, "a")
	check(int(better_paid.daily.paid) == DeepEconomy.daily_payout(better_score) - worth and int(profile.gold) == gold_then + int(better_paid.daily.paid), "a higher one pays the difference")
	check(int(profile.dig.best_score) == better_score, "and becomes the best")
	check(int(profile.records.best_daily) == better_score and profile.records.daily_bests.size() == 1 and int(profile.records.daily_bests[0].score) == better_score, "the Ledger keeps the day's best, one entry a day")
	var newcomer: Dictionary = DeepProfile.new_profile("Newcomer")
	var unpaid: Dictionary = DeepProfile.apply_result(newcomer, result, "a")
	check(int(unpaid.daily.paid) == 0 and int(newcomer.gold) == int(DeepProfile.new_profile("y").gold), "one who has not beaten the Quarry is scored but not paid")

func _test_daily_lobby() -> void:
	var session := DeepSession.new()
	root.add_child(session)
	session.start_local({"name": "Ada", "character": "ARDOR", "rail": [], "dice": [], "gold": 0, "daily_state": "fresh"})
	session.choose_mine("SEEPS")
	check(not session.can_start(), "with no gold the Seeps is out of reach")
	session.choose_daily("2026-10-10")
	check(session.daily_lobby() and session.departure_cost(session.local_member()) == 0 and session.can_start(), "the day's seam costs nothing, so the party can set out")
	check(bool(session.start_run().ok), "and does")
	var plan: Dictionary = DeepEconomy.daily_plan("2026-10-10")
	check(str(session.run.daily.date) == "2026-10-10" and str(session.run.mine) == DeepContent.starter_mine() and str(session.run.players[0].character) == str(plan.lapidary),
		"into the top of the first mine, as the day's lapidary")
	session.free()
	var locked := DeepSession.new()
	root.add_child(locked)
	locked.start_local({"name": "Bo", "character": "ARDOR", "rail": [], "dice": [], "gold": 0, "daily_state": "locked"})
	locked.choose_daily("2026-10-10")
	check(not locked.can_start(), "a host who has not beaten the Quarry cannot take a party down the day's seam")
	locked.choose_daily("")
	check(not locked.daily_lobby() and locked.can_start(), "and back to the map, the Quarry is free as ever")
	locked.free()
