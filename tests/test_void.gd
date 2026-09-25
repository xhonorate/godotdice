extends SceneTree
## Void gems ride a socket instead of taking one: the rail's shape, their place in the firing
## order, co-op patches, and the irreversible losses at home.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_rail()
	_battle()
	_endings()
	_workshop()
	_rarity()
	print("Void: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func gem(key: String, id: String, fragile: bool = true, appraised: bool = true) -> Dictionary:
	var stone: Dictionary = DeepStone.make(key, 1, 4, 2 if fragile else 3, ["VOID"] if fragile else [], {}, id)
	stone.appraised = appraised
	stone.inclusions_revealed = appraised
	return stone

func run_state() -> Dictionary:
	var profile: Dictionary = DeepProfile.new_profile()
	var loadout: Dictionary = DeepProfile.loadout(profile, "ARDOR")
	return DeepDescent.new_run({"seed": 923, "boons": false, "mine": "QUARRY", "players": [
		{"id": "a", "name": "Ada", "character": "ARDOR", "rail": loadout.rail, "dice": loadout.dice},
		{"id": "b", "name": "Ben", "character": "ARDOR", "rail": loadout.rail, "dice": loadout.dice}]})

func ids(line: Array) -> Array:
	return line.map(func(s: Dictionary) -> String: return str(s.id))

func _rail() -> void:
	var run: Dictionary = run_state()
	var unit: Dictionary = run.players[0]
	var count: int = DeepStone.socket_count(unit)
	check(unit.rail.size() == count and unit.riders.size() == count and unit.riders.all(func(l: Variant) -> bool: return l is Array and l.is_empty()), "a fresh rail has one place and one empty line of riders per socket")
	for index in range(count):
		unit.rail[index] = gem(["STRIKE", "GUARD", "MEND", "VENOM", "GLIMMER"][index], "normal%d" % index, false)
	var before: Array = unit.rail.duplicate(true)
	var first: Dictionary = gem("CLEAVE", "void_a")
	var second: Dictionary = gem("FURY", "void_b")
	var third: Dictionary = gem("ECHO", "void_c")
	unit.haul.append_array([first, second, third])
	var guest: Dictionary = run.duplicate(true)
	check(DeepDescent.command(run, "a", {"kind": "socket", "stone_id": first.id, "index": 1}).ok, "a Void gem rides a full socket of another color")
	check(unit.rail == before and ids(unit.riders[1]) == ["void_a"] and unit.haul.size() == 2, "riding leaves every socket as it was and takes the gem out of the bag")
	check(DeepDescent.command(run, "a", {"kind": "socket", "stone_id": second.id, "index": 1}).ok and ids(unit.riders[1]) == ["void_a", "void_b"], "a second rider joins the end of the line")
	check(DeepDescent.command(run, "a", {"kind": "socket", "stone_id": third.id, "index": 1, "at": 0}).ok and ids(unit.riders[1]) == ["void_c", "void_a", "void_b"], "a rider can be put at the head of the line")
	check(unit.rail.size() == count and unit.sockets.size() == count, "riders never lengthen the rail")
	var patched: Dictionary = DeepPatch.apply(guest, DeepPatch.diff(guest, run))
	check(JSON.stringify(patched) == JSON.stringify(run), "riders reach co-op guests exactly")
	unit.haul.append(gem("CLEAVE", "duplicate"))
	check(not DeepDescent.command(run, "a", {"kind": "socket", "stone_id": "duplicate", "index": 3}).ok, "Void preserves the one-stone-per-skill rule against a rider")
	check(not DeepDescent.command(run, "a", {"kind": "socket", "stone_id": "normal0", "index": 1}).ok or unit.rail[1].id == "normal0", "an ordinary gem still cannot ride: it swaps sockets")
	unit.rail[0] = before[0]
	unit.rail[1] = before[1]
	check(not DeepDescent.socket_refusal(unit, gem("CROSSCUT", "ordinary", false), count).is_empty(), "there is no place past the sockets")
	check(DeepDescent.command(run, "a", {"kind": "socket", "stone_id": first.id, "index": 1, "at": 3}).ok and ids(unit.riders[1]) == ["void_c", "void_b", "void_a"], "a rider moved later lands where it was dropped")
	check(DeepDescent.command(run, "a", {"kind": "socket", "stone_id": first.id, "index": 1, "at": 1}).ok and ids(unit.riders[1]) == ["void_c", "void_a", "void_b"], "a rider moved earlier lands ahead of the one it was dropped on")
	check(DeepDescent.command(run, "a", {"kind": "socket", "stone_id": second.id, "index": 4}).ok and ids(unit.riders[1]) == ["void_c", "void_a"] and ids(unit.riders[4]) == ["void_b"], "a rider moves to another socket")
	check(DeepDescent.command(run, "a", {"kind": "unsocket", "stone_id": third.id}).ok and ids(unit.riders[1]) == ["void_a"] and unit.haul.has(third), "a rider taken out by id goes back to the bag")
	check(DeepDescent.command(run, "a", {"kind": "unsocket", "index": 4}).ok and unit.rail[4] == null and ids(unit.riders[4]) == ["void_b"], "taking out a socket's gem leaves its riders riding")
	check(DeepDescent.command(run, "a", {"kind": "socket", "stone_id": "normal4", "index": 4}).ok and unit.rail[4].id == "normal4" and ids(unit.riders[4]) == ["void_b"], "a socket with riders still takes an ordinary gem")
	DeepDescent.command(run, "a", {"kind": "give", "to": "b", "item_id": third.id})
	check(run.players[1].haul.has(third) and not unit.haul.has(third), "a Void gem can be passed to an ally from the bag")
	## Working Void away or in.
	second.inclusions.clear()
	DeepStone.normalize_rail(unit)
	check(unit.riders[4].is_empty() and unit.haul.has(second), "a rider that loses Void with its socket full returns to the bag")
	unit.rail[4] = null
	var freed: Dictionary = DeepOddities.find_stone(unit, "void_b")
	DeepOddities.remove_stone(unit, "void_b")
	unit.riders[4].append(freed)
	DeepStone.normalize_rail(unit)
	check(unit.rail[4] == freed and unit.riders[4].is_empty(), "a rider that loses Void takes its empty socket when it fits")
	unit.rail[0].inclusions = ["VOID"]
	DeepStone.normalize_rail(unit)
	check(unit.rail[0] == null and ids(unit.riders[0]) == ["normal0"], "adding Void to a set gem frees its socket and it rides there instead")
	## Knots and merchants.
	var locked: Dictionary = unit.riders[1][0]
	locked.inclusions.append("KNOT")
	check(not DeepDescent.command(run, "a", {"kind": "unsocket", "stone_id": locked.id}).ok and not DeepDescent.command(run, "a", {"kind": "socket", "stone_id": locked.id, "index": 2}).ok, "a knotted rider stays where it is")
	run.phase = "chamber"
	run.chamber = {"kind": "merchant", "settled": false}
	var ore: int = unit.ore
	check(not DeepDescent.command(run, "a", {"kind": "sell", "stone_id": locked.id}).ok and unit.ore == ore, "merchants never buy fragile gems")
	var sale: Dictionary = DeepOddities.apply({"kind": "collector_sell"}, unit, {"stone_id": locked.id}, DeepRng.streams(1).oddities, {})
	check(not sale.ok and unit.ore == ore, "the collector cannot turn a fragile gem into pyrite")
	var order: Array = ids(DeepStone.rail_stones(unit))
	check(order == ["normal0", "normal1", "void_a", "normal2", "normal3", "void_b"], "the rail's stones are read in firing order, riders after their socket's gem: %s" % str(order))

func _battle() -> void:
	var run: Dictionary = run_state()
	var unit: Dictionary = run.players[0]
	var count: int = DeepStone.socket_count(unit)
	unit.haul.append_array([gem("CLEAVE", "ride_a"), gem("FURY", "ride_b")])
	DeepDescent.command(run, "a", {"kind": "socket", "stone_id": "ride_a", "index": 0})
	DeepDescent.command(run, "a", {"kind": "socket", "stone_id": "ride_b", "index": 0})
	var rebuilt: Dictionary = DeepBattle.make_player("a", "Ada", "ARDOR", unit.rail, unit.dice, -1, unit.riders)
	check(rebuilt.rail.size() == count and rebuilt.riders[0].size() == 2, "building a fighter keeps the rail by socket with its riders")
	var streams: Dictionary = DeepDescent.streams_of(run)
	var battle: Dictionary = DeepBattle.begin([rebuilt], ["CAVE_TICK"], {"depth": 1}, streams.dice, streams.creatures)
	var fighter: Dictionary = battle.players[0]
	check(fighter.rail.size() == count + 2 and fighter.places.size() == fighter.rail.size() and fighter.sockets.size() == fighter.rail.size() and not fighter.has("riders"), "a fight lays the rail flat: every gem and rider has a place and a socket color")
	check(fighter.rail[0].id == unit.rail[0].id and fighter.rail[1].id == "ride_a" and fighter.rail[2].id == "ride_b" and fighter.rail[3].id == unit.rail[1].id, "riders stand right after their socket's gem in the firing order")
	check(fighter.places[1].socket == 0 and fighter.places[1].rider == 0 and fighter.places[3].socket == 1 and fighter.places[3].rider == -1, "places fold the flat rail back onto the sockets")
	check(DeepStone.flat_index(fighter, 0) == 0 and DeepStone.flat_index(fighter, 0, 1) == 2 and DeepStone.flat_index(fighter, 1) == 3 and DeepStone.flat_index(fighter, 1, 0) == -1, "a socket or a rider can be found in the flat rail")
	check(str(fighter.sockets[1]) == DeepContent.SOCKET_ANY and DeepStone.socket_count(fighter) == count, "a rider fires in no color, and the fighter still has its character's sockets")
	for roll in fighter.hand:
		roll.value = 5
		roll.kind = "plain"
	var before: String = JSON.stringify(battle)
	var forecast: Dictionary = DeepBattle.forecast(battle, "a")
	check(forecast.sockets.size() == fighter.rail.size() and JSON.stringify(battle) == before, "the forecast covers riders without mutating the fight")
	var event: Dictionary = DeepBattle.resolve_gem(battle, fighter, 1, {"dry": true}, streams.dice)
	check(event.kind == "gem_fire" and str(event.stone_id) == "ride_a", "a rider fires against the actual hand")
	fighter.locked = true
	DeepBattle.start_resolution(battle)
	var order: Array = []
	for step in battle.queue:
		if str(step.get("kind", "")) == "gem" and str(step.get("unit", "")) == "a":
			order.append(int(step.socket))
		if str(step.get("kind", "")) == "birthstone":
			order.append(-1)
	check(order.slice(0, 3) == [0, 1, 2] and order.back() == -1, "the socket's gem, then its riders, then the rest, then the Birthstone: %s" % str(order))
	check(DeepStone.rail_stones(fighter).size() == DeepStone.rail_stones(unit).size(), "the flat rail holds exactly the stones the run's rail does")

func _endings() -> void:
	for outcome in ["extracted", "conquered", "fallen"]:
		var run: Dictionary = run_state()
		var unit: Dictionary = run.players[0]
		unit.haul.append_array([gem("CLEAVE", "equipped"), gem("FURY", "bag"), gem("VENOM", "raw", true, false), gem("CROSSCUT", "safe", false)])
		DeepDescent.command(run, "a", {"kind": "socket", "stone_id": "equipped", "index": 2})
		DeepDescent._finish(run, outcome)
		check(unit.shattered.size() == 2 and DeepStone.rider_count(unit) == 0 and unit.rail.size() == DeepStone.socket_count(unit), "%s shatters riding and bagged known Void gems" % outcome)
		check(unit.haul.size() == 2 and not DeepOddities.find_stone(unit, "raw").is_empty(), "%s leaves unopened stones for the loupe" % outcome)
		DeepDescent._finish(run, outcome)
		check(unit.shattered.size() == 2, "repeating the ending cannot duplicate shattered stones")
		var profile: Dictionary = DeepProfile.new_profile()
		var result: Dictionary = DeepProfile.apply_result(profile, DeepDescent.results(run), "a")
		check(result.shattered.size() == 2 and not profile.vault.has("CLEAVE") and not profile.vault.has("FURY") and profile.seen.has("CLEAVE"), "shattered gems reach only the seen record, never the vault")
	var abandoned: Dictionary = run_state()
	abandoned.players[0].haul.append(gem("CLEAVE", "lost"))
	DeepDescent.command(abandoned, "a", {"kind": "abandon"})
	check(abandoned.players[0].shattered.size() == 1 and abandoned.salvage.a.rolls.is_empty(), "known fragile gems cannot survive via a salvage roll")

func _workshop() -> void:
	for key in ["STRIKE", "CLEAVE"]:
		var profile: Dictionary = DeepProfile.new_profile()
		profile.gold = 1000
		var vault: Dictionary = profile.vault.duplicate(true)
		var raw: Dictionary = gem(key, "home_raw", true, false)
		profile.tray.append(raw)
		var fee: int = DeepProfile.appraisal_fee(raw)
		check(DeepProfile.appraise(profile, raw), "fragile raw %s can be appraised" % key)
		check(profile.tray.is_empty() and profile.gold == 1000 - fee and profile.seen.has(key), "appraisal pays its fee and immediately removes the fragile gem")
		check(profile.vault == vault and DeepProfile.auto_keep(profile).is_empty(), "neither a first skill nor a rival displaces a vault stone")
		check(not DeepProfile.decide_tray(profile, raw.id, true).ok, "a skipped ceremony cannot rescue its shattered gem")
		for keep_it in [true, false]:
			profile.tray.append(gem(key, "forced", true, false))
			var money: int = profile.gold
			var decided: Dictionary = DeepProfile.decide_tray(profile, "forced", keep_it)
			check(decided.shattered and not decided.kept and decided.paid == 0 and profile.gold == money and profile.tray.is_empty(), "direct keep and rough-sale paths cannot cash out fragile gems")
		DeepProfile.keep(profile, gem(key, "direct"))
		check(profile.vault == vault, "direct keep also preserves the existing vault")
	var profile: Dictionary = DeepProfile.new_profile()
	profile.tray = [gem("CLEAVE", "loaded")]
	DeepProfile.auto_keep(profile)
	check(profile.tray.is_empty() and not profile.vault.has("CLEAVE"), "bulk keeping cannot retain an already revealed fragile stone")

func _rarity() -> void:
	check(DeepContent.validate().is_empty(), "Void's modifiers and content validate")
	var rng := RandomNumberGenerator.new()
	rng.seed = 917
	var found: int = 0
	for _i in range(6000):
		if DeepForge.roll_inclusions(rng, 1, DeepContent.mine("QUARRY")).has("VOID"):
			found += 1
	check(found > 0 and found < 60, "Void rolls naturally but rarely (%d of 6000 inclusion draws)" % found)
