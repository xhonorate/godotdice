extends SceneTree
## Coming home (November 13, 2026; docs/GOLD.md "Coming home"): the haul's fates suggested,
## held to what can happen and carried out; the reading fee as one total; Void never forming
## outside a run; and the table itself played through headless, from the crack to the report.

const HaulTable = preload("res://view/home/haul_table.gd")
const Homecoming = preload("res://view/home/homecoming.gd")

var checks: int = 0
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_suggest()
	_test_normalize()
	_test_costly()
	_test_crack_plan()
	_test_settle()
	_test_records()
	_test_unvoid()
	await _test_table()
	print("Haul: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _profile() -> Dictionary:
	var profile: Dictionary = DeepProfile.new_profile("Haul")
	profile.gold = 1000
	## No commissions unless a test sets one.
	for commission in DeepEconomy.open_commissions(profile):
		commission.done = true
	return profile

func _read(skill: String, carat: int, cut: int, clarity: int, id: String) -> Dictionary:
	var stone: Dictionary = DeepStone.make(skill, carat, cut, clarity, [], {"source": "vein", "mine": "QUARRY"}, id)
	stone.appraised = true
	stone.inclusions_revealed = true
	return stone

func _test_suggest() -> void:
	var profile: Dictionary = _profile()
	## The vault holds a 2 carat Strike, a Guard and a Mend from the start.
	var better: Dictionary = _read("STRIKE", 14, 3, 3, "better")
	var worse: Dictionary = _read("STRIKE", 1, 0, 3, "worse")
	var fresh: Dictionary = _read("EMBER", 9, 3, 3, "fresh")
	var fresh_low: Dictionary = _read("EMBER", 2, 1, 3, "fresh_low")
	var raw: Dictionary = DeepStone.make("CLEAVE", 6, 2, 3, [], {}, "raw")
	var fates: Dictionary = DeepProfile.suggest_fates(profile, [better, worse, fresh, fresh_low, raw])
	check(str(fates.get("better", "")) == "replace", "a finer stone of a kept skill replaces the one kept: %s" % fates)
	check(str(fates.get("worse", "")) == "sell", "a worse one is sold")
	check(str(fates.get("fresh", "")) == "vault" and str(fates.get("fresh_low", "")) == "sell", "the finest of a new skill goes into the vault, another of it is sold")
	check(str(fates.get("raw", "")) == "rough", "a stone nobody read is sold rough")
	## A commission takes what the vault does not want.
	var wanted_profile: Dictionary = _profile()
	var commissions: Array = DeepEconomy.open_commissions(wanted_profile)
	if not commissions.is_empty():
		commissions[0].done = false
		commissions[0].skill = "STRIKE"
		commissions[0].need = {"kind": "pure", "value": 0}
		commissions[0].reward = 500
		var wanted: Dictionary = DeepProfile.suggest_fates(wanted_profile, [better, worse])
		check(str(wanted.get("better", "")) == "replace" and str(wanted.get("worse", "")) == "turnin", "a commission takes the stone not kept: %s" % wanted)
		check(DeepProfile.fates_for(wanted_profile, worse, [better, worse]).has("turnin"), "and Turn in is offered on it")

func _test_normalize() -> void:
	var profile: Dictionary = _profile()
	var a: Dictionary = _read("EMBER", 9, 3, 3, "a")
	var b: Dictionary = _read("EMBER", 2, 1, 3, "b")
	var stones: Array = [a, b]
	## Selling the only keeper of a new skill hands the vault the other.
	var fates: Dictionary = DeepProfile.normalize_fates(profile, stones, {"a": "sell", "b": "sell"}, "a")
	check(str(fates.a) == "sell" and str(fates.b) == "vault", "a skill not kept yet always keeps one: %s" % fates)
	## Two keepers of one skill: the one just chosen wins.
	fates = DeepProfile.normalize_fates(profile, stones, {"a": "vault", "b": "vault"}, "b")
	check(str(fates.b) == "vault" and str(fates.a) == "sell", "the stone just chosen is the one kept: %s" % fates)
	## A first of its skill alone can never be sold.
	check(not DeepProfile.fates_for(profile, a, [a]).has("sell"), "a lone first of its skill is never offered for sale")
	check(DeepProfile.fates_for(profile, a, stones).has("sell"), "but may be sold when another of its skill is kept instead")
	## vault and replace follow whether the skill is kept.
	var kept: Dictionary = _read("STRIKE", 14, 3, 3, "kept_strike")
	fates = DeepProfile.normalize_fates(profile, [kept], {"kept_strike": "vault"})
	check(str(fates.kept_strike) == "replace", "a kept skill's keeper is named Replace yours")

func _test_costly() -> void:
	var profile: Dictionary = _profile()
	var better: Dictionary = _read("STRIKE", 14, 3, 3, "better")
	var worse: Dictionary = _read("STRIKE", 1, 0, 3, "worse")
	var stones: Array = [better, worse]
	check(DeepProfile.costly_fates(profile, stones, {"better": "replace", "worse": "sell"}).is_empty(), "keeping the finest gives nothing up")
	check(DeepProfile.costly_fates(profile, stones, {"better": "sell", "worse": "sell"}).has("better"), "selling the finer stone while the old one stays is flagged")
	check(DeepProfile.costly_fates(profile, stones, {"better": "sell", "worse": "replace"}).has("better"), "keeping the worse in its place flags the finer one sold")
	check(DeepProfile.costly_fates(profile, [worse], {"worse": "replace"}).has("worse"), "letting the kept stone go for a worse one is flagged")

func _test_crack_plan() -> void:
	var profile: Dictionary = _profile()
	var big: Dictionary = DeepStone.make("CLEAVE", 22, 2, 3, [], {}, "big")
	var small: Dictionary = DeepStone.make("CLEAVE", 2, 2, 3, [], {}, "small")
	var read: Dictionary = _read("EMBER", 9, 3, 3, "read")
	var fee_big: int = DeepProfile.appraisal_fee(big)
	var fee_small: int = DeepProfile.appraisal_fee(small)
	var plan: Dictionary = DeepProfile.crack_plan(profile, [big, small, read])
	check(int(plan.fee) == fee_big + fee_small and plan.crack == ["big", "small"] and plan.short.is_empty(), "the fees are summed, the biggest first: %s" % plan)
	profile.gold = fee_big - 1
	plan = DeepProfile.crack_plan(profile, [big, small])
	check(plan.crack == ["small"] and plan.short == ["big"], "short of gold, what the purse covers is read and the rest sell rough: %s" % plan)
	plan = DeepProfile.crack_plan(profile, [big, small], ["small"])
	check(plan.crack.is_empty() and plan.short == ["big"], "a stone set aside to sell rough is left out of the plan")

func _test_settle() -> void:
	var profile: Dictionary = _profile()
	var better: Dictionary = _read("STRIKE", 14, 3, 3, "better")
	var worse: Dictionary = _read("STRIKE", 1, 0, 3, "worse")
	var fresh: Dictionary = _read("EMBER", 9, 3, 3, "fresh")
	var raw: Dictionary = DeepStone.make("CLEAVE", 6, 2, 3, [], {}, "raw")
	profile.tray = [better, worse, fresh, raw]
	profile.history.append({"run_id": "r1", "mine": "QUARRY", "outcome": "extracted", "depth": 5})
	var gold: int = int(profile.gold)
	var fates: Dictionary = DeepProfile.suggest_fates(profile, profile.tray)
	var done: Dictionary = DeepProfile.settle_tray(profile, fates)
	check(profile.tray.is_empty(), "settling clears the tray")
	check(str(DeepProfile.owned(profile, "STRIKE").get("id", "")) == "better" and profile.vault.has("EMBER"), "the keeps are kept")
	check(int(profile.gold) == gold + DeepStone.value(worse) + DeepStone.rough_value(raw), "the sales are paid: %d" % (int(profile.gold) - gold))
	check(done.kept.size() == 2 and done.sold.size() == 2 and int(done.gold) == int(profile.gold) - gold, "the report counts what came of it")
	check(str(done.best.get("id", "")) == "better" or str(done.best.get("id", "")) == "fresh", "the best of the haul is named")
	check(str(profile.get("brought", {}).get("run", "")) == "r1", "the best find is remembered for the party")
	check(done.kept.any(func(e: Dictionary) -> bool: return bool(e.fresh) and str(e.stone.skill) == "EMBER"), "a new skill is marked fresh in the report")

func _test_records() -> void:
	var profile: Dictionary = _profile()
	profile.records.best = {"score": 10, "tier": "ROUGH"}
	profile.records.best_haul = 5
	var fine: Dictionary = _read("PRISM", 9, 4, 5, "prism")
	profile.tray = [fine]
	var done: Dictionary = DeepProfile.settle_tray(profile, {"prism": "vault"})
	var words: Array = done.records.map(func(r: Array) -> String: return str(r[1]))
	check(words.any(func(w: String) -> bool: return w.begins_with("New best grade")), "a better grade than ever is a record: %s" % str(words))
	check(words.any(func(w: String) -> bool: return w.begins_with("Most valuable haul")), "so is the most valuable haul")
	check(int(profile.records.best_haul) >= DeepStone.value(fine), "and the best haul is written down")

func _test_unvoid() -> void:
	var profile: Dictionary = _profile()
	var stone: Dictionary = DeepStone.make("CLEAVE", 9, 3, 1, ["VOID", "STAR"], {"source": "vein", "mine": "QUARRY"}, "voidy")
	var twin: Dictionary = stone.duplicate(true)
	check(DeepStone.is_fragile(stone), "a Void stone is fragile down the mine")
	DeepProfile.appraise(profile, stone)
	check(not DeepStone.is_fragile(stone) and not stone.inclusions.has("VOID") and stone.inclusions.size() == 2 and stone.inclusions.has("STAR"),
		"read at home its Void has grown into another inclusion: %s" % str(stone.inclusions))
	DeepForge.unvoid(twin)
	check(twin.inclusions == stone.inclusions, "and always the same one for the same stone")
	## Coming home: a raw stone carries no Void up, and an old save's tray is mended.
	var raw: Dictionary = DeepStone.make("GUARD", 5, 2, 1, ["VOID"], {"source": "vein", "mine": "QUARRY"}, "raw_void")
	profile.tray = [raw.duplicate(true)]
	DeepProfile.upgrade(profile)
	check(not DeepStone.is_fragile(profile.tray[0]), "an old save's raw Void stone is mended on load")
	## A stone read down the mine keeps its Void, and still shatters at the lift.
	var read: Dictionary = raw.duplicate(true)
	read.appraised = true
	check(DeepStone.known_fragile(read), "a Void read down the mine is still known to be fragile")
	## Nothing bought or cracked at home is ever fragile.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(60):
		var geode: Dictionary = DeepEconomy.roll_run_geode(rng, "QUARRY", {"run": "t"}, "g%d" % i)
		var inside: Dictionary = DeepEconomy.roll_geode_stone(rng, geode.geode, "s%d" % i)
		if DeepStone.is_fragile(inside):
			check(false, "a Geode's stone came out fragile")
			return
	check(true, "no Geode's stone is fragile")

func _test_table() -> void:
	## The table played headless: laid out, cracked in one press, its fates set and changed,
	## settled in one more, the report, and the workshop.
	var app: Control = load("res://view/app.gd").new()
	DeepSaveStore.override_directory = "user://haul_test"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	root.add_child(app)
	await process_frame
	await process_frame
	var profile: Dictionary = app.profile
	profile.gold = 5000
	for commission in DeepEconomy.open_commissions(profile):
		commission.done = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mine: Dictionary = DeepContent.mine("QUARRY").duplicate()
	mine.key = "QUARRY"
	var tray: Array = []
	for i in range(12):
		tray.append(DeepForge.roll_stone(rng, mine, 6 + i, 4, {"run": "t", "source": "vein", "mine": "QUARRY"}, "tray%d" % i))
	tray.append(DeepEconomy.roll_run_geode(rng, "QUARRY", {"run": "t"}, "tgeo"))
	tray.append(_read("STRIKE", 1, 0, 3, "weak_strike"))
	profile.tray = tray
	profile.history.append({"run_id": "t", "mine": "QUARRY", "outcome": "extracted", "depth": 9})
	profile.homecoming = true
	app._profile_changed()
	await process_frame
	var table: Control = app.home.find_child("HaulTable", true, false)
	check(table != null, "coming home lays the haul on the table")
	if table == null:
		return
	check(str(table.phase) == "laid" and table.get("_cards").size() == tray.size(), "every stone lies on it before the crack (%d cards)" % table.get("_cards").size())
	check(str(table.order.back()) == "tgeo" and str(table.order[0]) == "weak_strike", "read stones first, Geodes last")
	var crack: Node = app.home.find_child("CrackAll", true, false)
	check(crack is Button and not (crack as Button).disabled, "Crack all is on the bar")
	var plan: Dictionary = DeepProfile.crack_plan(profile, tray)
	var gold: int = int(profile.gold)
	(crack as Button).pressed.emit()
	await process_frame
	check(int(profile.gold) == gold - int(plan.fee), "one press pays every fee (%d)" % int(plan.fee))
	check(profile.tray.all(func(s: Dictionary) -> bool: return bool(s.get("appraised", false))), "and reads every stone, the Geode cracked")
	check(str(table.phase) == "fates" and table.fates.size() == profile.tray.size(), "every stone wears a fate")
	check(table.fates.get("weak_strike", "") == "sell", "the worse of a kept skill is set to be sold")
	## Changing a fate: a click on another of the pane's buttons, or a number key.
	table.focus_on("weak_strike")
	var suggested: Dictionary = table.fates.duplicate()
	table.set_fate("weak_strike", "replace")
	check(str(table.fates.weak_strike) == "replace", "a fate can be changed")
	check(not DeepProfile.costly_fates(profile, profile.tray, table.fates).is_empty(), "keeping the worse stone flags the finer one given up: %s" % str(table.fates))
	check(app.home.find_child("CostlyWarning", true, false) != null, "and the bar says so")
	table.set_fate("weak_strike", "sell")
	check(table.fates == suggested, "putting it back gives back what it pushed off")
	check(app.home.find_child("CostlyWarning", true, false) == null, "and the warning goes")
	var count: int = profile.tray.size()
	var settle: Node = app.home.find_child("Settle", true, false)
	check(settle is Button, "Settle the haul is on the bar")
	(settle as Button).pressed.emit()
	await process_frame
	check(profile.tray.is_empty(), "one press settles the whole haul")
	check(str(table.phase) == "report" and app.home.find_child("ReportTitle", true, false) != null, "and the report follows")
	check(int(table.report.get("stones", 0)) == count and int(table.report.get("fees", 0)) == int(plan.fee), "the report counts the stones and the fees")
	check(bool(profile.get("homecoming", false)), "the workshop still waits on the report")
	## A redraw keeps the report up (the table is kept between draws).
	app.home._render()
	await process_frame
	check(app.home.find_child("ReportTitle", true, false) != null, "a redraw keeps the report up")
	var go: Node = app.home.find_child("IntoWorkshop", true, false)
	check(go is Button, "Into the workshop is on the report")
	(go as Button).pressed.emit()
	await process_frame
	check(not bool(profile.get("homecoming", false)) and app.home.tab == "descend" and not profile.has("haul") and not profile.has("haul_report"), "and opens the workshop")
	## The vault's Unappraised view uses the same table, without the hold.
	profile.tray = [DeepStone.make("CLEAVE", 6, 2, 3, [], {"source": "vein", "mine": "QUARRY"}, "later")]
	app.home._vault_view = "unappraised"
	app.home.open("vault", true)
	await process_frame
	var vault_table: Node = app.home.find_child("HaulTable", true, false)
	check(vault_table != null and not bool(vault_table.holding), "the vault's Unappraised view lays its stones on the same table")
	## A stone shown on its own (a Geode bought at the Market): its fates as the spotlight's buttons.
	var made: Dictionary = _read("PRISM", 9, 4, 5, "alone")
	profile.tray.append(made)
	var actions: Array = Homecoming.single_actions(app.home, made)
	check(actions.size() == 1 and str(actions[0].fate) == "vault" and bool(actions[0].main), "a first of its skill alone goes into the vault, and nothing else")
	actions[0].call.call()
	check(profile.vault.has("PRISM") and not profile.tray.any(func(s: Dictionary) -> bool: return str(s.id) == "alone"), "and a press keeps it")
	app.queue_free()
	await process_frame
