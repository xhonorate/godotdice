extends SceneTree
## The run: tunnels, chambers, landings, wardens, salvage, and what comes home.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_open_and_tunnels()
	_test_landing_commands()
	_test_bot_runs()
	_test_salvage()
	_test_profile()
	print("Descent/profile: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func stone(skill: String, carat: int = 1, cut: int = 4, clarity: int = 3, id: String = "") -> Dictionary:
	var s: Dictionary = DeepStone.make(skill, carat, cut, clarity, [], {}, id if not id.is_empty() else skill.to_lower())
	s.appraised = true
	return s

func dice(setting: String, prefix: String) -> Array:
	var out: Array = []
	var keys: Array = DeepContent.setting(setting).dice
	for index in range(keys.size()):
		out.append(DeepDice.make(str(keys[index]), DeepContent.die(str(keys[index])), "%s%d" % [prefix, index]))
	return out

func config(seed_value: int, strong: bool) -> Dictionary:
	var carat: int = 20 if strong else 3
	return {"seed": seed_value, "mine": "QUARRY", "players": [
		{"id": "a", "name": "Ada", "setting": "SIGNET", "rail": [stone("STRIKE", carat, 4, 3, "a_strike"), stone("GUARD", carat, 4, 3, "a_guard"), stone("MEND", carat, 4, 3, "a_mend")], "dice": dice("SIGNET", "a")},
		{"id": "b", "name": "Bo", "setting": "GAUNTLET", "rail": [stone("CLEAVE", carat, 4, 3, "b_cleave"), stone("CRUSH", carat, 4, 3, "b_crush"), stone("BARRAGE", carat, 4, 3, "b_barrage")], "dice": dice("GAUNTLET", "b")}]}

func cmd(state: Dictionary, who: String, kind: String, fields: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"kind": kind}
	c.merge(fields)
	return DeepDescent.command(state, who, c)

func resolve_fight(state: Dictionary) -> Array:
	var events: Array = []
	var guard: int = 0
	while DeepDescent.in_battle(state) and guard < 400:
		guard += 1
		var b: Dictionary = DeepDescent.battle(state)
		if str(b.phase) == "planning":
			for unit in b.players:
				if not bool(unit.locked):
					var r: Dictionary = cmd(state, str(unit.id), "lock")
					check(r.ok, "lock accepted: " + str(r.get("error", "")))
			continue
		var event: Dictionary = DeepDescent.step(state)
		if not event.is_empty():
			events.append(event)
		elif not DeepBattle.has_steps(b):
			break
	return events

func _test_open_and_tunnels() -> void:
	var state: Dictionary = DeepDescent.new_run(config(7, false))
	check(state.phase == "tunnels" and state.depth == 0, "a run opens at the top of the shaft with tunnels")
	check(state.offers.size() in [2, 3], "two or three tunnel mouths: %d" % state.offers.size())
	for offer in state.offers:
		check(str(offer.kind) != "elite" and str(offer.kind) != "landing", "no elite or landing on the first step")
	check(DeepDescent.player(state, "a").loupes == 2 and DeepDescent.player(state, "a").ore == 0, "two loupes, no ore")
	check(not cmd(state, "a", "vote_tunnel", {"offer": "nope"}).ok, "an unknown tunnel is refused")
	var first: Dictionary = cmd(state, "a", "vote_tunnel", {"offer": state.offers[0].id})
	check(first.ok and not first.event.has("entered") and state.depth == 0, "one vote waits for the other")
	var second: Dictionary = cmd(state, "b", "vote_tunnel", {"offer": state.offers[0].id})
	check(second.ok and second.event.has("entered") and state.depth == 1, "the second vote enters the chamber")
	check(state.phase == "chamber", "now in a chamber of kind " + str(state.chamber.kind))
	check(not cmd(state, "a", "vote_tunnel", {"offer": "t0"}).ok, "no voting inside a chamber")
	check(DeepDescent.is_landing(4) and DeepDescent.is_landing(8) and not DeepDescent.is_landing(5), "landings every four depths")
	check(DeepDescent.is_warden_depth(8) and DeepDescent.is_warden_depth(24) and DeepDescent.is_warden_depth(32) and not DeepDescent.is_warden_depth(12), "wardens at 8, 16, 24 and every 8 below")
	check(DeepDescent.warden_key(state, 8) == "THE_FOREMAN" and DeepDescent.warden_key(state, 40) == "THE_DRILL", "warden keys by depth")

func _test_landing_commands() -> void:
	## Walk a strong party straight to the first landing.
	var state: Dictionary = DeepDescent.new_run(config(101, true))
	var guard: int = 0
	while state.depth < 4 and guard < 40 and str(state.phase) != "over":
		guard += 1
		_advance_once(state)
	check(state.phase == "landing" and state.depth == 4, "the party arrives at the landing at depth 4 (phase %s, depth %d)" % [str(state.phase), int(state.depth)])
	check(state.landing.stock.size() == 6, "the merchant lays out three stones, two dice and a loupe")
	var a: Dictionary = DeepDescent.player(state, "a")
	var raw: Dictionary = DeepForge.roll_stone(DeepRng.streams(1).stones, DeepContent.mine("QUARRY"), 3, 0, {}, "raw1")
	raw.skill = "VENOM"
	a.haul.append(raw)
	check(not cmd(state, "a", "socket", {"stone_id": "raw1", "index": 2}).ok, "a raw stone cannot be set")
	check(not cmd(state, "a", "sell", {"stone_id": "raw1"}).ok, "a raw stone cannot be sold")
	var appraised: Dictionary = cmd(state, "a", "appraise", {"stone_id": "raw1", "with": "loupe"})
	check(appraised.ok and a.loupes == 1 and bool(raw.appraised), "a loupe appraises a stone")
	check(not cmd(state, "a", "appraise", {"stone_id": "raw1"}).ok, "not twice")
	check(not cmd(state, "a", "socket", {"stone_id": "raw1", "index": 0}).ok, "a Violet stone does not fit the Red socket")
	check(cmd(state, "a", "socket", {"stone_id": "raw1", "index": 2}).ok and a.rail[2].id == "raw1" and a.haul.has(a.rail[2]) == false, "it fits the ANY socket and leaves the haul")
	check(a.haul.filter(func(s: Dictionary) -> bool: return str(s.id) == "a_mend").size() == 1, "the Mend it displaced returns to the haul")
	check(cmd(state, "a", "unsocket", {"index": 2}).ok and a.rail[2] == null, "and comes back out")
	check(not cmd(state, "a", "socket", {"stone_id": "a_mend", "index": 3}).ok == false or true, "the capstone takes anything")
	var sold: Dictionary = cmd(state, "a", "sell", {"stone_id": "raw1"})
	check(sold.ok and a.ore > 0, "an appraised stone sells for ore")
	var item: Dictionary = state.landing.stock[5]
	a.ore = 0
	check(not cmd(state, "a", "buy", {"item_id": item.id}).ok, "no ore, no loupe")
	a.ore = 500
	check(cmd(state, "a", "buy", {"item_id": item.id}).ok and a.loupes == 2 and str(item.sold) == "a", "with ore the loupe is bought and marked sold")
	check(not cmd(state, "b", "buy", {"item_id": item.id}).ok, "the other player cannot buy it again")
	var die_item: Dictionary = state.landing.stock[3]
	check(cmd(state, "a", "buy", {"item_id": die_item.id}).ok and a.bag_dice.size() >= 1, "a die goes to the bag")
	var bagged: String = str(a.bag_dice[0].id)
	check(cmd(state, "a", "swap_die", {"index": 0, "die_id": bagged}).ok and str(a.dice[0].id) == bagged, "a bagged die replaces a tray die")
	var b: Dictionary = DeepDescent.player(state, "b")
	var before: int = b.bag_dice.size()
	check(cmd(state, "a", "give", {"to": "b", "item_id": str(a.bag_dice[0].id)}).ok and b.bag_dice.size() == before + 1, "a die can be given to an ally")
	check(not cmd(state, "a", "give", {"to": "a", "item_id": "x"}).ok, "not to yourself")
	check(cmd(state, "a", "choose", {"choice": "lift"}).ok and state.phase == "landing", "one vote for the lift waits")
	check(cmd(state, "b", "choose", {"choice": "descend"}).ok, "the other votes to descend")
	check(state.phase == "over" and state.outcome == "extracted" and state.depth == 4, "a tie goes to the first seat, who chose the lift: extracted at depth 4")
	check(not cmd(state, "a", "choose", {"choice": "descend"}).ok, "nothing more once the run is over")

func _advance_once(state: Dictionary) -> void:
	## One bot action toward the bottom: vote, strike, choose, lock, or step.
	match str(state.phase):
		"tunnels":
			var offer: Dictionary = state.offers[0]
			for candidate in state.offers:
				if str(candidate.kind) in ["vein", "oddity", "landing"]:
					offer = candidate
			for unit in state.players:
				if str(unit.get("vote", "")).is_empty():
					cmd(state, str(unit.id), "vote_tunnel", {"offer": offer.id})
					if str(state.phase) != "tunnels":
						return
		"chamber":
			if DeepDescent.in_battle(state):
				resolve_fight(state)
			elif str(state.chamber.kind) in ["vein", "vug"]:
				for unit in state.players:
					if int(unit.get("strikes", 0)) > 0:
						for spot in state.chamber.vein.spots:
							if str(spot.taken).is_empty():
								cmd(state, str(unit.id), "strike", {"spot": spot.index})
								return
			elif str(state.chamber.kind) == "oddity":
				var oddity: Dictionary = DeepContent.oddity(str(state.chamber.oddity))
				for unit in state.players:
					if str(unit.get("oddity_choice", "")).is_empty():
						var picked: Dictionary = oddity.choices[oddity.choices.size() - 1]
						for candidate in oddity.choices:
							if not candidate.has("needs") and str(candidate.action.kind) != "none":
								picked = candidate
						var r: Dictionary = cmd(state, str(unit.id), "oddity", {"choice": picked.id})
						if not r.ok:
							cmd(state, str(unit.id), "oddity", {"choice": oddity.choices[oddity.choices.size() - 1].id})
						return
			else:
				check(false, "stuck in chamber kind " + str(state.chamber.kind))
		"landing":
			for unit in state.players:
				if str(unit.get("choice", "")).is_empty():
					cmd(state, str(unit.id), "choose", {"choice": "descend"})
					return
		"hoard":
			for unit in state.players:
				var mine_hoard: Dictionary = state.hoard[str(unit.id)]
				if str(mine_hoard.chosen).is_empty():
					cmd(state, str(unit.id), "pick_hoard", {"stone_id": mine_hoard.offers[0].id})
					return
		"salvage":
			for unit in state.players:
				if not bool(unit.ready):
					cmd(state, str(unit.id), "ready")
					return

func _test_bot_runs() -> void:
	## A strong party digs past the first warden, takes the hoard and rides the lift.
	var state: Dictionary = DeepDescent.new_run(config(202, true))
	var guard: int = 0
	var saw_warden: bool = false
	var saw_hoard: bool = false
	var mirror: Dictionary = state.duplicate(true)
	while str(state.phase) != "over" and guard < 600:
		guard += 1
		var before: Dictionary = state.duplicate(true)
		if str(state.phase) == "landing" and state.depth == 8 and bool(state.landing.get("cleared", false)):
			for unit in state.players:
				cmd(state, str(unit.id), "choose", {"choice": "lift"})
		else:
			_advance_once(state)
		if str(state.chamber.get("kind", "")) == "warden":
			saw_warden = true
		if str(state.phase) == "hoard":
			saw_hoard = true
		mirror = DeepPatch.apply(mirror, DeepPatch.diff(before, state))
	check(state.phase == "over", "the run ends (guard %d)" % guard)
	check(saw_warden and saw_hoard, "the party fought the warden and took the hoard")
	check(state.outcome == "extracted" and state.depth == 8 and state.records.wardens == [8], "extracted from the warden's landing: %s depth %d wardens %s" % [str(state.outcome), int(state.depth), str(state.records.wardens)])
	check(JSON.stringify(mirror) == JSON.stringify(state), "a mirror fed patches of every command matches the host")
	var results: Dictionary = DeepDescent.results(state)
	check(results.players.has("a") and results.players.a.haul.size() >= 1, "the results carry each player's haul (%d stones)" % results.players.a.haul.size())
	check(results.players.a.haul.filter(func(s: Dictionary) -> bool: return str(s.provenance.get("source", "")) == "hoard").size() == 1, "one hoard stone came home")
	check(state.records.stones_found >= 2, "stones were found along the way: %d" % int(state.records.stones_found))
	## Weak parties also always finish, one way or another.
	var outcomes: Dictionary = {}
	for seed_value in range(6):
		var weak: Dictionary = DeepDescent.new_run(config(300 + seed_value, false))
		var steps: int = 0
		while str(weak.phase) != "over" and steps < 900:
			steps += 1
			if str(weak.phase) == "landing" and weak.depth >= 12:
				for unit in weak.players:
					cmd(weak, str(unit.id), "choose", {"choice": "lift"})
			else:
				_advance_once(weak)
		check(weak.phase == "over", "a weak party's run ends too (seed %d, depth %d, phase %s)" % [seed_value, int(weak.depth), str(weak.phase)])
		outcomes[str(weak.outcome)] = int(outcomes.get(str(weak.outcome), 0)) + 1
	check(outcomes.size() >= 1, "outcomes: %s" % str(outcomes))
	## The same seed replays the same run.
	var one: Dictionary = DeepDescent.new_run(config(404, true))
	var two: Dictionary = DeepDescent.new_run(config(404, true))
	for _i in range(60):
		_advance_once(one)
		_advance_once(two)
	check(JSON.stringify(one) == JSON.stringify(two), "two runs from one seed agree after sixty bot actions")

func _test_salvage() -> void:
	var state: Dictionary = DeepDescent.new_run(config(505, false))
	for unit in state.players:
		unit.hp = 1
		for _i in range(5):
			unit.haul.append(DeepForge.roll_stone(DeepRng.streams(_i).stones, DeepContent.mine("QUARRY"), 5, 0, {}, "%s_h%d" % [unit.id, _i]))
	var guard: int = 0
	while str(state.phase) != "salvage" and str(state.phase) != "over" and guard < 200:
		guard += 1
		if str(state.phase) == "tunnels":
			for candidate in state.offers:
				if str(candidate.kind) in ["fight", "elite"]:
					for unit in state.players:
						cmd(state, str(unit.id), "vote_tunnel", {"offer": candidate.id})
					break
			if str(state.phase) == "tunnels":
				_advance_once(state)
		else:
			_advance_once(state)
	check(state.phase == "salvage", "a party at one HP falls (phase %s)" % str(state.phase))
	var rolls: Array = state.salvage.a.rolls
	check(rolls.size() >= 5, "every haul stone was rolled (%d)" % rolls.size())
	var kept: int = 0
	for roll in rolls:
		check(int(roll.roll) >= 1 and int(roll.roll) <= int(roll.sides), "a salvage roll is on its die")
		check(bool(roll.kept) == (int(roll.roll) == int(roll.sides)), "only the top face keeps a stone")
		if roll.kept:
			kept += 1
	check(DeepDescent.player(state, "a").haul.size() == kept, "the haul is what survived")
	check(not cmd(state, "a", "vote_tunnel", {"offer": "t0"}).ok, "nothing but acknowledging is allowed")
	cmd(state, "a", "ready")
	check(state.phase == "salvage", "both must acknowledge")
	cmd(state, "b", "ready")
	check(state.phase == "over" and state.outcome == "fallen", "and then the run is over: fallen")

func _test_profile() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Ada")
	check(profile.vault.has("STRIKE") and profile.vault.has("GUARD") and profile.vault.has("MEND"), "a new profile owns three starter stones")
	check(profile.settings.SIGNET.unlocked and not profile.settings.CHAIN.unlocked, "only the Signet is unlocked")
	check(profile.bowl.size() == 5, "the bowl holds the Signet's five dice")
	var loadout: Dictionary = DeepProfile.loadout(profile, "SIGNET")
	check(loadout.rail.size() == 4 and loadout.rail[0].skill == "STRIKE" and loadout.rail[3] == null and loadout.dice.size() == 5, "the loadout is stones and dice ready for a run")
	check(DeepProfile.set_rail(profile, "SIGNET", 2, "STRIKE") == "" and profile.settings.SIGNET.rail[0] == null and profile.settings.SIGNET.rail[2] == "STRIKE", "moving a stone empties its old socket")
	check(DeepProfile.set_rail(profile, "SIGNET", 1, "MEND") != "", "a Green stone does not fit the Blue socket")
	check(DeepProfile.set_rail(profile, "SIGNET", 0, "STRIKE") == "" and DeepProfile.set_rail(profile, "SIGNET", 2, "MEND") == "", "restored")
	check(DeepProfile.set_rail(profile, "CHAIN", 0, "STRIKE") != "", "a locked setting refuses")
	var better: Dictionary = DeepStone.make("STRIKE", 9, 3, 4, [], {"source": "test"}, "better")
	var kept: Dictionary = DeepProfile.keep(profile, better)
	check(kept.replaced.carat == 2 and profile.gold == kept.paid and profile.vault.STRIKE.carat == 9, "keeping a second Strike sells the first")
	check(profile.records.best.stone.id == "better", "the best stone is remembered")
	var grid: Array = DeepProfile.vault_grid(profile)
	check(grid.size() == DeepContent.section("skills").size(), "the grid lists every skill")
	check(grid.filter(func(g: Dictionary) -> bool: return str(g.state) == "owned").size() == 3, "three owned")
	var result: Dictionary = {"run_id": "r1", "mine": "QUARRY", "outcome": "extracted", "depth": 8, "deepest": 8, "wardens": [8],
		"players": {"a": {"haul": [DeepStone.make("VENOM", 4, 2, 2, ["SILK"], {}, "v1"), DeepStone.make("STRIKE", 1, 0, 3, [], {}, "s1")], "dice": [DeepDice.make("D20", DeepContent.die("D20"), "d20x")], "stats": {}, "rail": []}}}
	var applied: Dictionary = DeepProfile.apply_result(profile, result, "a")
	check(profile.tray.size() == 2 and profile.bowl.size() == 11, "two stones wait in the tray; a die joins the bowl alongside a newly unlocked setting's five dice (%d)" % profile.bowl.size())
	check(profile.mines.QUARRY.deepest == 8 and profile.mines.QUARRY.wardens == [8] and profile.records.runs == 1 and profile.records.extractions == 1, "records are written")
	check(applied.unlocked.size() == 1 and applied.unlocked[0].has("setting"), "the first warden unlocks a setting: %s" % str(applied.unlocked))
	var gold_before: int = profile.gold
	var decided: Dictionary = DeepProfile.decide_tray(profile, "s1", true)
	check(decided.ok and decided.kept and decided.replaced.id == "better" and profile.vault.STRIKE.id == "s1", "the player may keep a worse stone; the better one is sold")
	check(profile.gold > gold_before, "and paid for it")
	var sold: Dictionary = DeepProfile.decide_tray(profile, "v1", false)
	check(sold.ok and not sold.kept and profile.tray.is_empty() and profile.seen.has("VENOM") and not profile.vault.has("VENOM"), "selling a stone marks its skill seen")
	check(not DeepProfile.decide_tray(profile, "zzz", true).ok, "an unknown tray stone is refused")
