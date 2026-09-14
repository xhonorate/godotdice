extends SceneTree
## The persistent profile: collection, loadouts, mines, the daily shop, the return table and
## commissions, plus the store that saves it and the mine content that feeds it.
const Catalog = preload("res://scripts/core/catalog.gd")
const Profile = preload("res://scripts/core/profile.gd")
const ProfileStore = preload("res://scripts/services/profile_store.gd")
const TEST_DIR := "user://profile_test"
var checks: int = 0
var failures: Array = []

func _init() -> void:
	var errors: Array = Catalog.validate_content()
	check(errors.is_empty(), "The shipped pack validates: " + str(errors))
	_test_new_profile()
	_test_loadouts()
	_test_mines()
	_test_shop()
	_test_return()
	_test_commissions()
	_test_quality_rolls()
	_test_mine_validation()
	_test_store()
	print("Profile: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func fresh() -> Dictionary:
	return Profile.create("tester")

func result(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {"result_id": "r1", "mine_id": "QUARRY", "outcome": "extracted", "depth": 6,
		"haul": [], "seen_gems": [], "encountered": {"enemies": ["SLIME"], "bosses": []}}
	base.merge(overrides, true)
	return base

func _test_new_profile() -> void:
	var profile: Dictionary = fresh()
	check(int(profile.gold) == 0, "A new profile starts with no gold")
	for hero in ["ARDOR", "KAIT", "MAX"]:
		check(profile.heroes[hero].unlocked, "%s starts unlocked" % hero)
		check("STRIKE" in profile.heroes[hero].loadout, "%s's loadout holds Strike" % hero)
	check(profile.collection.has("STRIKE") and int(profile.collection.STRIKE.carat) == 2, "The collection keeps the best starting Strike (Kait's Carat 2)")
	for starter in Catalog.definitions("heroes").ARDOR.starting_gems:
		check(profile.collection.has(starter[0]), "Ardor's starting gem %s is owned" % starter[0])
	check(Profile.gem_state(profile, "STRIKE") == "owned", "Owned gems read as owned")
	check(Profile.gem_state(profile, "LIFELINE") == "unseen", "Gems never found read as unseen")
	var grid: Array = Profile.collection_grid(profile)
	check(grid.size() == Catalog.definitions("skills").size(), "The grid lists every gem in the content")
	check(grid.all(func(row: Dictionary) -> bool: return row.state != "unseen" or row.name.is_empty()), "Unseen grid rows carry no name")
	var by_owned: Array = Profile.collection_grid(profile, "owned")
	check(by_owned[0].state == "owned" and by_owned[-1].state == "unseen", "Sorting by owned puts owned gems first")
	check(profile.selected_hero == "ARDOR", "The first unlocked hero is selected")
	var normalized: Dictionary = Profile.normalize(profile)
	check(normalized.ok and normalized.profile == profile, "Normalizing a valid profile changes nothing")
	var newer: Dictionary = profile.duplicate(true)
	newer.schema_version = Profile.SCHEMA_VERSION + 1
	check(not Profile.normalize(newer).ok, "A profile from a newer build is refused")

func _test_loadouts() -> void:
	var profile: Dictionary = fresh()
	check(not Profile.set_loadout(profile, "ARDOR", ["BLOCK"]).is_empty(), "A loadout without Strike is refused")
	check(not Profile.set_loadout(profile, "ARDOR", ["STRIKE", "LIFELINE"]).is_empty(), "An unowned gem is refused")
	check(not Profile.set_loadout(profile, "ARDOR", ["STRIKE", "STRIKE"]).is_empty(), "A duplicate gem is refused")
	check(not Profile.set_loadout(profile, "ARDOR", ["STRIKE", "BLOCK", "SUNDER", "ARC_BURST", "PRECISION", "INTERPOSE", "HEAL"]).is_empty(), "More than six gems is refused")
	check(Profile.set_loadout(profile, "ARDOR", ["STRIKE", "SUNDER"]).is_empty(), "A valid loadout from the shared collection is accepted")
	check(Profile.set_loadout(profile, "KAIT", ["STRIKE", "SUNDER"]).is_empty(), "Two heroes may use the same collection gem")
	var gems: Array = Profile.loadout_gems(profile, "ARDOR", "p1")
	check(gems.size() == 2 and gems[0].key == "STRIKE" and gems[0].equipped and gems[0].loadout, "Loadout gems arrive equipped and marked as loadout")
	check(int(gems[0].carat) == 2 and gems[0].id != gems[1].id, "Loadout gems carry collection ranks and distinct IDs")
	profile.heroes.MAX.unlocked = false
	check(not Profile.set_loadout(profile, "MAX", ["STRIKE"]).is_empty(), "A locked hero's loadout cannot be edited")
	check(not Profile.select_hero(profile, "MAX").is_empty(), "A locked hero cannot be selected")

func _test_mines() -> void:
	var profile: Dictionary = fresh()
	check(Profile.mine_state(profile, "QUARRY") == "unlocked", "The starter mine is unlocked")
	check(Profile.mine_state(profile, "MIRROR_GROTTO") == "revealed", "A mine linked from an unlocked one is revealed")
	check(Profile.unlocked_mines(profile) == ["QUARRY"], "Only the starter is unlocked at first")
	var outcome: Dictionary = Profile.apply_result(profile, result({"result_id": "win", "outcome": "conquered", "depth": 9, "encountered": {"enemies": ["SLIME"], "bosses": ["SLIME_KING"]}}))
	check(outcome.ok and outcome.unlocked.size() == 2, "Defeating the Quarry boss unlocks both linked mines")
	check(profile.mines.QUARRY.boss_defeated and int(profile.mines.QUARRY.deepest) == 9, "The mine records its boss and deepest layer")
	check("SLIME_KING" in profile.encountered.bosses, "Encountered bosses are remembered")
	check(Profile.shop_quality(profile) == int(Catalog.MINES.RIFT_HOLLOW.quality_bonus) + 3, "The shop buys from the best unlocked mine")
	var guest: Dictionary = fresh()
	Profile.apply_result(guest, result({"result_id": "guest", "mine_id": "RIFT_HOLLOW", "outcome": "conquered"}))
	check(guest.mines.RIFT_HOLLOW.unlocked, "A guest who conquers a mine they had not unlocked unlocks it")

func _test_shop() -> void:
	var profile: Dictionary = fresh()
	Profile.mark_seen(profile, ["HEAL", "MEND", "VENOM", "LIFELINE", "STUN", "TITHE", "ECHO"])
	Profile.ensure_shop(profile, "2026-09-14")
	var stock: Array = profile.shop.stock
	check(not stock.is_empty() and stock.size() <= Profile.SHOP_SIZE, "The shop stocks up to six gems")
	check(stock.all(func(offer: Dictionary) -> bool: return offer.gem.key in profile.seen_gems), "The shop only offers seen gems")
	check(stock.all(func(offer: Dictionary) -> bool: return not profile.collection.has(offer.gem.key) or Catalog.gem_value(profile.collection[offer.gem.key]) < Catalog.gem_value(offer.gem)), "The shop never offers a gem no better than the owned one")
	var twin: Dictionary = fresh()
	Profile.mark_seen(twin, ["HEAL", "MEND", "VENOM", "LIFELINE", "STUN", "TITHE", "ECHO"])
	Profile.ensure_shop(twin, "2026-09-14")
	check(twin.shop.stock == stock, "The same profile and date make the same stock")
	Profile.ensure_shop(profile, "2026-09-14")
	check(profile.shop.stock == stock, "Visiting again the same day keeps the stock")
	check(Profile.refresh_cost(profile) == 1000, "The first refresh costs 1000 gold")
	check(not Profile.refresh_shop(profile, "2026-09-14").is_empty(), "A refresh without gold is refused")
	profile.gold = 5000
	check(Profile.refresh_shop(profile, "2026-09-14").is_empty() and int(profile.gold) == 4000, "A refresh spends 1000 gold")
	check(Profile.refresh_cost(profile) == 2000, "The next refresh costs 2000")
	check(Profile.refresh_shop(profile, "2026-09-14").is_empty() and int(profile.gold) == 2000 and Profile.refresh_cost(profile) == 3000, "Refresh costs climb by 1000 each time")
	Profile.ensure_shop(profile, "2026-09-15")
	check(int(profile.shop.refreshes) == 0 and Profile.refresh_cost(profile) == 1000, "A new day resets the refresh cost")
	var offer: Dictionary = profile.shop.stock[0]
	profile.gold = int(offer.price) - 1
	check(not Profile.buy_offer(profile, offer.id, "2026-09-15").ok, "Buying without enough gold is refused")
	profile.gold = int(offer.price) + 10
	var bought: Dictionary = Profile.buy_offer(profile, offer.id, "2026-09-15")
	check(bought.ok and profile.collection.has(offer.gem.key) and offer.sold, "Buying adds the gem and marks the offer sold")
	check(int(profile.gold) == 10 + int(bought.gold), "Buying spends the price (and sells any replaced version)")
	check(not Profile.buy_offer(profile, offer.id, "2026-09-15").ok, "A sold offer cannot be bought twice")
	check(not Profile.buy_offer(profile, profile.shop.stock[-1].id, "2026-09-16").ok, "Yesterday's offer cannot be bought after the restock")

func _test_return() -> void:
	var profile: Dictionary = fresh()
	var better_strike: Dictionary = {"id": "h1", "key": "STRIKE", "carat": 9, "cut": 3, "clarity": 2}
	var new_heal: Dictionary = {"id": "h2", "key": "HEAL", "carat": 3, "cut": 1, "clarity": 1}
	var third: Dictionary = {"id": "h3", "key": "VENOM", "carat": 5, "cut": 2, "clarity": 2}
	var outcome: Dictionary = Profile.apply_result(profile, result({"haul": [better_strike, new_heal, third], "seen_gems": ["MEND"]}))
	check(outcome.ok and not outcome.duplicate, "A valid result applies")
	check(Profile.gem_state(profile, "HEAL") == "seen" and Profile.gem_state(profile, "MEND") == "seen", "Hauled and appraised-in-run gems become seen")
	check(profile.pending_return.gems.size() == 3, "The haul waits on the appraisal table")
	check(Profile.apply_result(profile, result({"haul": [better_strike]})).duplicate and profile.pending_return.gems.size() == 3, "Re-applying the same result does nothing")
	var old_strike: Dictionary = profile.collection.STRIKE.duplicate()
	var kept: Dictionary = Profile.decide_return_gem(profile, "h1", true)
	check(kept.ok and int(profile.collection.STRIKE.carat) == 9, "Keeping a gem puts it in the collection")
	check(kept.replaced == old_strike and int(profile.gold) == Profile.sell_value(old_strike), "Keeping a duplicate sells the old version")
	check(not Profile.decide_return_gem(profile, "h1", false).ok, "A decision is final")
	var gold_before: int = int(profile.gold)
	var sold: Dictionary = Profile.decide_return_gem(profile, "h2", false)
	check(sold.ok and int(profile.gold) == gold_before + Profile.sell_value(new_heal) and not profile.collection.has("HEAL"), "Selling pays the sell value and keeps nothing")
	check(Profile.sell_value(new_heal) == Catalog.gem_value(new_heal) * 10, "Sell value is ten times trade value")
	var finished: Dictionary = Profile.finish_return(profile)
	check(finished.sold == ["h3"] and profile.pending_return.is_empty(), "Leaving the table sells undecided gems")
	check(int(profile.lifetime.gems_kept) == 1 and int(profile.lifetime.gems_sold) == 2 and int(profile.lifetime.runs) == 1, "Lifetime counts runs, keeps and sales")
	var second: Dictionary = fresh()
	Profile.apply_result(second, result({"result_id": "a", "haul": [new_heal]}))
	Profile.apply_result(second, result({"result_id": "b", "haul": [third]}))
	check(second.pending_return.result_id == "b" and int(second.gold) == Profile.sell_value(new_heal), "A new result sells an abandoned table before laying out its own")
	check(not Profile.apply_result(fresh(), result({"outcome": "won"})).ok, "An unknown ending is refused")
	check(not Profile.apply_result(fresh(), result({"mine_id": "NOWHERE"})).ok, "An unknown mine is refused")
	check(not Profile.apply_result(fresh(), result({"haul": [{"id": "x", "key": "NOT_A_GEM"}]})).ok, "An unknown hauled gem is refused")
	check(not Profile.apply_result(fresh(), result({"haul": [new_heal, new_heal]})).ok, "Duplicate hauled gem IDs are refused")

func _test_commissions() -> void:
	var profile: Dictionary = fresh()
	Profile.ensure_commissions(profile, "2026-09-14")
	check(profile.commissions.board.size() == Profile.COMMISSION_SLOTS, "The board fills to three notes")
	check(profile.commissions.board.all(func(note: Dictionary) -> bool: return not Profile.describe_commission(note).is_empty()), "Every note has readable text")
	var twin: Dictionary = fresh()
	Profile.ensure_commissions(twin, "2026-09-14")
	check(twin.commissions == profile.commissions, "Commissions roll the same for the same profile and date")
	var note: Dictionary = {"id": "t1", "kind": "color_carat", "status": "open", "color": "RED", "carat": 8, "reward": {"gold": 400}}
	profile.commissions.board = [note]
	check(not Profile.claim_commission(profile, "t1").ok, "An open note cannot be claimed")
	Profile.apply_result(profile, result({"result_id": "miss", "haul": [{"id": "g1", "key": "STRIKE", "carat": 7, "cut": 1, "clarity": 1}]}))
	check(note.status == "open", "A gem below the requirement does not complete the note")
	var applied: Dictionary = Profile.apply_result(profile, result({"result_id": "hit", "outcome": "fallen", "haul": [{"id": "g2", "key": "SUNDER", "carat": 8, "cut": 1, "clarity": 1}]}))
	check(note.status == "complete" and applied.completed == ["t1"], "A salvaged gem that meets the note completes it")
	var gold: int = int(profile.gold)
	var claimed: Dictionary = Profile.claim_commission(profile, "t1")
	check(claimed.ok and int(profile.gold) == gold + 400 and profile.commissions.board.is_empty(), "Claiming pays the reward and removes the note")
	Profile.ensure_commissions(profile, "2026-09-14")
	check(profile.commissions.board.size() == 3, "A claimed note is replaced")
	var depth: Dictionary = {"kind": "depth", "mine_id": "QUARRY", "depth": 8}
	check(not Profile.commission_met(depth, result({"depth": 9, "outcome": "fallen"})), "A depth note needs the party to come back alive")
	check(Profile.commission_met(depth, result({"depth": 9})), "Extracting past the depth meets a depth note")
	check(Profile.commission_met({"kind": "boss", "mine_id": "QUARRY"}, result({"outcome": "conquered"})), "Conquering meets a boss note")
	check(Profile.commission_met({"kind": "rank", "property": "clarity", "rank": 4}, result({"haul": [{"id": "z", "key": "HEAL", "carat": 1, "cut": 1, "clarity": 4}]})), "A clarity note reads clarity")
	var special_found := false
	var probe: Dictionary = fresh()
	var date := "2026-01-01"
	for day in range(20):
		Profile.ensure_commissions(probe, date)
		if not probe.commissions.special.is_empty():
			special_found = true
			var special: Dictionary = probe.commissions.special[0]
			check(special.expires == Profile.next_date(date), "A special mission lasts one day")
			check(Profile.SPECIAL_MODIFIERS.has(special.modifier) and not special.reward.gem.key.is_empty(), "A special mission has a known modifier and a gem reward")
			Profile.ensure_commissions(probe, special.expires)
			Profile.ensure_commissions(probe, Profile.next_date(special.expires))
			check(probe.commissions.special.is_empty() or probe.commissions.special[0].id != special.id, "An unclaimed special mission expires")
			break
		date = Profile.next_date(date)
	check(special_found, "Special missions appear within twenty days")
	check(Profile.next_date("2026-12-31") == "2027-01-01", "Dates roll over the year")

func _test_quality_rolls() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var low_value := 0
	var high_value := 0
	for index in range(300):
		low_value += Catalog.gem_value(Catalog.roll_gem(rng, Catalog.MINES.QUARRY.skill_ids, 0, "l"))
		high_value += Catalog.gem_value(Catalog.roll_gem(rng, Catalog.MINES.QUARRY.skill_ids, 30, "h"))
	check(high_value > low_value * 4, "Quality 30 gems are worth far more than quality 0 gems (%d vs %d)" % [high_value, low_value])
	for quality in [0, 15, 30]:
		for index in range(50):
			var ranks: Array = Catalog.roll_gem_ranks(rng, quality)
			check(ranks[0] >= 1 and ranks[0] <= 24 and ranks[1] >= 1 and ranks[1] <= 5 and ranks[2] >= 1 and ranks[2] <= 5, "Rolled ranks stay in bounds at quality %d" % quality)
	check(Catalog.quality_rarity_weights(0)[3] == 0, "Quality 0 never rolls a Legendary")
	var only_red: int = 0
	for index in range(200):
		var gem: Dictionary = Catalog.roll_gem(rng, ["STRIKE", "BLOCK"], 0, "c", {"RED": 100, "BLUE": 0})
		if gem.key == "STRIKE": only_red += 1
	check(only_red == 200, "A zero colour weight removes that colour from the draw")
	check(Catalog.roll_gem(rng, [], 10, "x").is_empty(), "An empty pool rolls nothing")

func _test_mine_validation() -> void:
	var cases: Array = [
		["an unknown boss", func(mines: Dictionary) -> void: mines.QUARRY.boss_id = "SLIME"],
		["a link to nowhere", func(mines: Dictionary) -> void: mines.QUARRY.links = ["NOWHERE"]],
		["an unreachable mine", func(mines: Dictionary) -> void: mines.QUARRY.links = ["MIRROR_GROTTO"]],
		["no starter", func(mines: Dictionary) -> void: mines.QUARRY.erase("starter")],
		["a boss in a spawn band", func(mines: Dictionary) -> void: mines.QUARRY.bands[0].normal = {"SLIME_KING": 1}],
		["bands that do not start at 1", func(mines: Dictionary) -> void: mines.QUARRY.bands[0].from_depth = 2],
		["an unknown room", func(mines: Dictionary) -> void: mines.QUARRY.rooms["lift"] = 3],
		["no battles", func(mines: Dictionary) -> void: mines.QUARRY.rooms.battle = 0],
		["an unknown gem", func(mines: Dictionary) -> void: mines.QUARRY.skill_ids = ["NOPE"]],
		["a float rate", func(mines: Dictionary) -> void: mines.QUARRY.tremor_rate = 1.5]]
	for case in cases:
		var pack: Resource = Catalog.default_content_pack()
		var mines: Dictionary = pack.mines
		case[1].call(mines)
		var errors: Array = pack.validate({"heroes": Catalog.HEROES, "skills": Catalog.SKILLS, "dice": Catalog.DICE, "relics": Catalog.RELICS, "enemies": Catalog.ENEMIES})
		check(errors.any(func(error: String) -> bool: return error.begins_with("mines")), "Mine validation rejects " + case[0] + ": " + str(errors))
	var clean: Resource = Catalog.default_content_pack()
	check(clean.validate({"heroes": Catalog.HEROES, "skills": Catalog.SKILLS, "dice": Catalog.DICE, "relics": Catalog.RELICS, "enemies": Catalog.ENEMIES}).is_empty(), "The default pack's mines validate")

func _test_store() -> void:
	_clear_dir()
	var store: ProfileStore = ProfileStore.new(TEST_DIR)
	var loaded: Dictionary = store.load_or_create()
	check(loaded.ok and loaded.created and not store.profile.is_empty(), "A missing profile is created")
	var id: String = store.profile.profile_id
	var denied: Dictionary = store.transact(func(profile: Dictionary) -> String: return Profile.set_loadout(profile, "ARDOR", ["BLOCK"]))
	check(not denied.ok and "STRIKE" in store.profile.heroes.ARDOR.loadout, "A refused transaction leaves the profile unchanged")
	var accepted: Dictionary = store.transact(func(profile: Dictionary) -> String:
		profile.gold = 1234
		return "")
	check(accepted.ok and int(store.profile.gold) == 1234, "An accepted transaction updates the profile")
	var reopened: ProfileStore = ProfileStore.new(TEST_DIR)
	check(reopened.load_or_create().ok and reopened.profile.profile_id == id and int(reopened.profile.gold) == 1234, "The profile survives a reload")
	store.transact(func(profile: Dictionary) -> String:
		profile.gold = 99
		return "")
	var file: FileAccess = FileAccess.open(TEST_DIR.path_join("profile.json"), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	var recovered: ProfileStore = ProfileStore.new(TEST_DIR)
	var outcome: Dictionary = recovered.load_or_create()
	check(outcome.ok and outcome.recovered and recovered.profile.profile_id == id and int(recovered.profile.gold) == 1234, "A damaged profile recovers from its backup")
	for name in ["profile.json", "profile.json.bak"]:
		var broken: FileAccess = FileAccess.open(TEST_DIR.path_join(name), FileAccess.WRITE)
		broken.store_string("{ not json")
		broken.close()
	var replaced: ProfileStore = ProfileStore.new(TEST_DIR)
	var fallback: Dictionary = replaced.load_or_create()
	check(fallback.ok and fallback.created and replaced.profile.profile_id != id, "With both copies damaged a new profile is created")
	check(not str(fallback.get("moved_aside", "")).is_empty() and FileAccess.file_exists(fallback.moved_aside), "The damaged file is moved aside, not overwritten")
	_clear_dir()

func _clear_dir() -> void:
	var path: String = ProjectSettings.globalize_path(TEST_DIR)
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
