extends SceneTree
## The run: tunnels, chambers, landings, wardens, salvage, and what comes home.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_open_and_tunnels()
	_test_unique_ids()
	_test_lantern_map()
	_test_abandon()
	_test_landing_commands()
	_test_merchant()
	_test_dice_rooms()
	_test_bot_runs()
	_test_hoard_opal()
	_test_sparkle()
	_test_salvage()
	_test_grubstake()
	_test_profile()
	_test_mines()
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

func dice(character: String, prefix: String) -> Array:
	var out: Array = []
	var keys: Array = DeepContent.character(character).dice
	for index in range(keys.size()):
		out.append(DeepForge.die_from(keys[index], "%s%d" % [prefix, index]))
	return out

func _test_sparkle() -> void:
	for stacks in [0, 1, 4, 5, 37, 100, 150]:
		var state: Dictionary = DeepDescent.new_run(config(123, false))
		state.depth = 5
		var unit: Dictionary = state.players[0]
		unit.sparkle = stacks
		state.players[1].sparkle = 23
		var streams: Dictionary = DeepDescent.streams_of(state)
		var expected_rng: RandomNumberGenerator = DeepRng.restore(state.rng).stones
		var before: Dictionary = state.duplicate(true)
		var found: Dictionary = DeepDescent._find_stone(state, unit, streams, 3, "vein")
		var expected: Dictionary = DeepForge.roll_stone(expected_rng, DeepDescent.mine_of(state), 5, 3.0 + float(mini(stacks, 100)) * DeepRules.SPARKLE_LUCK, found.provenance, str(found.id))
		check(JSON.stringify(found) == JSON.stringify(expected), "%d stored Sparkle grants SPARKLE_LUCK a luck point each, capped, on the next find" % stacks)
		check(int(unit.sparkle) == 0 and int(state.players[1].sparkle) == 23, "a stone consumes every stack for its finder only, even below five")
		check(JSON.stringify(DeepPatch.apply(before, DeepPatch.diff(before, state))) == JSON.stringify(state), "Sparkle consumption and its stone patch identically for guests")
		var next: Dictionary = DeepDescent._find_stone(state, unit, streams, 3, "vein")
		expected = DeepForge.roll_stone(expected_rng, DeepDescent.mine_of(state), 5, 3, next.provenance, str(next.id))
		check(JSON.stringify(next) == JSON.stringify(expected), "the following stone receives no spent Sparkle bonus")
	var state: Dictionary = DeepDescent.new_run(config(456, false))
	state.depth = 1
	state.phase = "chamber"
	var streams: Dictionary = DeepDescent.streams_of(state)
	DeepDescent._start_fight(state, streams, false, "")
	state.rng = DeepRng.save(streams)
	for fighter in state.chamber.battle.players:
		fighter.quality_bonus = -1000 # Force no random drop in this scenario.
	state.chamber.battle.players[0].sparkle = 37
	DeepDescent._settle_fight(state, "victory")
	check(int(state.players[0].sparkle) == 37 and state.players[0].haul.is_empty(), "a victory with no stone preserves all earned Sparkle")
	state.phase = "chamber"
	DeepDescent._start_fight(state, DeepDescent.streams_of(state), true, "")
	check(int(state.chamber.battle.players[0].sparkle) == 37, "the next fight inherits stored Sparkle")
	var rewards: Dictionary = DeepDescent._settle_fight(state, "victory")
	check(int(state.players[0].sparkle) == 0 and rewards.rewards.a.stones.size() == 1, "the next guaranteed elite stone spends all carried Sparkle")

func _test_unique_ids() -> void:
	## Vault stones keep the ids they were found with, and older runs handed the same few out
	## again. Two set stones that arrive sharing an id are told apart, and nothing found this
	## run can take an id a vault stone came down with.
	var setup: Dictionary = config(515, true)
	setup.players[0].rail[1].id = "st24"
	setup.players[0].rail[2].id = "st24"
	setup.players[1].rail[0].id = "st3"
	var state: Dictionary = DeepDescent.new_run(setup)
	var ids: Dictionary = {}
	for unit in state.players:
		for stone in DeepStone.rail_stones(unit):
			ids[str(stone.id)] = true
	check(ids.size() == 6, "every set stone has an id of its own: %s" % str(ids.keys()))
	for _i in range(40):
		var fresh: String = DeepDescent._id(state, "st")
		check(not ids.has(fresh), "a stone found down here never takes a set stone's id: %s" % fresh)
	## An old save's dice, written down by stock key and without their patterns, come back as
	## the dice their character brings now, and a doubled id is split.
	var profile: Dictionary = DeepProfile.new_profile()
	DeepProfile.unlock_character(profile, "FLORIN")
	var florin: Array = profile.characters.FLORIN.dice
	for index in range(profile.bowl.size()):
		if str(profile.bowl[index].id) == str(florin[0]):
			profile.bowl[index] = {"id": str(florin[0]), "key": "GAMBLERS_D6", "name": "Gambler's Die", "shape": "D6", "engraving": "",
				"faces": [1, 2, 3, 4, 5, 7].map(func(v: int) -> Dictionary: return {"value": v, "kind": "plain"})}
	profile.bowl.append(profile.bowl[0].duplicate(true))
	DeepProfile.migrate(profile)
	var mended: Dictionary = DeepProfile.bowl_die(profile, str(florin[0]))
	check(str(mended.get("pattern", "")) == "gamblers" and not mended.has("key") and DeepDice.describe(mended) != "Gambler's Die",
		"an old Gambler's Die comes back cut to its pattern: %s" % str(mended))
	var bowl_ids: Dictionary = {}
	for die in profile.bowl:
		bowl_ids[str(die.id)] = true
	check(bowl_ids.size() == profile.bowl.size(), "and no two dice in the bowl share an id")

func config(seed_value: int, strong: bool) -> Dictionary:
	var carat: int = 20 if strong else 3
	return {"seed": seed_value, "mine": "QUARRY", "boons": false, "players": [
		{"id": "a", "name": "Ada", "character": "ARDOR", "rail": [stone("STRIKE", carat, 4, 3, "a_strike"), stone("GUARD", carat, 4, 3, "a_guard"), stone("MEND", carat, 4, 3, "a_mend")], "dice": dice("ARDOR", "a")},
		{"id": "b", "name": "Bo", "character": "VESPER", "rail": [stone("CLEAVE", carat, 4, 3, "b_cleave"), stone("CRUSH", carat, 4, 3, "b_crush"), stone("BARRAGE", carat, 4, 3, "b_barrage")], "dice": dice("VESPER", "b")}]}

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
	check(not DeepDescent.player(state, "a").has("loupes") and DeepDescent.player(state, "a").ore == 0, "no loupes, no pyrite")
	check(not cmd(state, "a", "vote_tunnel", {"offer": "nope"}).ok, "an unknown tunnel is refused")
	var first: Dictionary = cmd(state, "a", "vote_tunnel", {"offer": state.offers[0].id})
	check(first.ok and not first.event.has("entered") and state.depth == 0, "one vote waits for the other")
	var second: Dictionary = cmd(state, "b", "vote_tunnel", {"offer": state.offers[0].id})
	check(second.ok and second.event.has("entered") and state.depth == 1, "the second vote enters the chamber")
	check(state.phase == "chamber", "now in a chamber of kind " + str(state.chamber.kind))
	check(not cmd(state, "a", "vote_tunnel", {"offer": "t0"}).ok, "no voting inside a chamber")
	## A split vote is drawn from the hat, not handed to the host: over a handful of runs
	## both ways get taken.
	var took: Dictionary = {}
	for trial in range(24):
		var split: Dictionary = DeepDescent.new_run(config(300 + trial, false))
		var ways: Array = split.offers.map(func(o: Dictionary) -> String: return str(o.id))
		cmd(split, "a", "vote_tunnel", {"offer": ways[0]})
		cmd(split, "b", "vote_tunnel", {"offer": ways[1]})
		took[str(split.path[0].id) == ways[0]] = true
	check(took.has(true) and took.has(false), "a split vote goes either way, not always the host's")
	check(DeepDescent.is_landing(4) and DeepDescent.is_landing(8) and not DeepDescent.is_landing(5), "landings every four depths")
	check(DeepDescent.is_warden_depth(8) and DeepDescent.is_warden_depth(12) and DeepDescent.is_warden_depth(16) and not DeepDescent.is_warden_depth(4) and not DeepDescent.is_warden_depth(24),
		"the Quarry's Wardens at 8 and 12 and its boss on the bottom floor, 16")
	check(DeepDescent.is_warden_depth(8, "RIFT") and DeepDescent.is_warden_depth(40, "RIFT") and not DeepDescent.is_warden_depth(12, "RIFT"), "the Rift has a Warden every eighth floor")
	## The written depths are only roughly where the Wardens stand: this run's own schedule
	## says which landing each of them guards.
	var guards: Array = state.schedule.wardens
	var bottom: int = DeepContent.mine_bottom("QUARRY")
	check(guards.size() == 3 and int(guards[2]) == bottom and int(state.schedule.boss) == bottom, "two Wardens and the boss on the bottom floor: %s" % str(guards))
	check(guards.all(func(d: int) -> bool: return state.schedule.landings.has(d)), "and every one of them guards a landing")
	check(DeepDescent.warden_key(state, int(guards[0])) == "THE_FOREMAN" and DeepDescent.warden_key(state, int(guards[1])) == "THE_REGENT" and DeepDescent.warden_key(state, bottom) == "THE_DRILL",
		"warden keys by which landing they guard, and the boss at the bottom")
	check(DeepDescent.run_is_boss(state, bottom) and not DeepDescent.run_is_boss(state, int(guards[0])), "only the bottom floor is the boss's")

func _test_lantern_map() -> void:
	for seed_value in [3, 7, 19, 44, 90]:
		var state: Dictionary = DeepDescent.new_run(config(seed_value, true))
		var map: Dictionary = state.map
		## The first lift is not always four down: it wanders a floor either way.
		var lift_at: int = int(state.schedule.landings[0])
		check(int(map.from) == 0 and int(map.to) == lift_at and map.rows.size() == lift_at - 1 and lift_at >= 3 and lift_at <= 5,
			"the first stretch is charted from the top down to the first landing (at %d)" % lift_at)
		for r in range(map.rows.size()):
			check(map.rows[r].size() == mini(2 + r, DeepDescent.MAP_WIDEST), "row %d is %d mouths wide" % [r, map.rows[r].size()])
		var offered: Array = state.offers.map(func(o: Dictionary) -> String: return str(o.id))
		check(offered == map.rows[0], "the first tunnels are the top row")
		## Every chamber is reachable, every chamber leads on, and no two ways cross.
		var reached: Dictionary = {}
		for r in range(map.rows.size()):
			var row: Array = map.rows[r]
			for i in range(row.size()):
				var node: Dictionary = map.nodes[str(row[i])]
				check(node.next.size() >= 1, "%s leads on" % node.id)
				## The shaft forks in two while it is still widening. Once it has reached its
				## widest the rows are the same size, and the way nearest the wall runs on
				## alone rather than crossing its neighbour.
				if r < map.rows.size() - 1 and map.rows[r + 1].size() > row.size():
					check(node.next.size() == 2, "%s forks two ways (%d)" % [node.id, node.next.size()])
				for child in node.next:
					reached[str(child)] = true
				if i > 0:
					var left: Dictionary = map.nodes[str(row[i - 1])]
					check(float(left.x) <= float(node.x), "lanes stay in order across a row")
					if r < map.rows.size() - 1:
						var right_most: int = map.rows[r + 1].find(left.next[left.next.size() - 1])
						var left_most: int = map.rows[r + 1].find(node.next[0])
						check(left_most >= right_most, "neighbouring ways never cross")
				if int(node.depth) <= 2:
					check(str(node.kind) != "elite", "no elite in the first two depths")
				if int(node.depth) <= 1:
					check(str(node.kind) != "merchant", "no merchant on the first step down")
			check(row.filter(func(id: Variant) -> bool: return bool(map.nodes[str(id)].hidden)).size() <= 1, "at most one dark mouth a depth")
			for kind in DeepDescent.DICE_ROOMS:
				check(row.filter(func(id: Variant) -> bool: return str(map.nodes[str(id)].kind) == kind).size() <= 1, "at most one %s a depth" % kind)
		for r in range(1, map.rows.size()):
			for id in map.rows[r]:
				check(reached.has(str(id)), "%s can be reached" % id)
		check(reached.has("landing"), "the last row opens onto the landing")
		var stalls: Array = map.nodes.values().filter(func(n: Dictionary) -> bool: return str(n.kind) == "merchant")
		check(stalls.size() >= 1, "every stretch has a merchant in it (seed %d)" % seed_value)
		var benches: Array = map.nodes.values().filter(func(n: Dictionary) -> bool: return str(n.kind) in DeepDescent.DICE_ROOMS)
		check(benches.size() >= 1, "every stretch has a smithy or a carver in it (seed %d)" % seed_value)
		## The lantern shows one depth ahead; past it only glints.
		var deep: Dictionary = map.nodes[str(map.rows[1][0])]
		check(not DeepDescent.revealed(state, deep), "depth 2 is beyond the lantern from the top")
		check(DeepDescent.glint(deep) in ["hostile", "glittering", "strange", "dark"], "but it glints")
		var shallow: Dictionary = map.nodes[str(map.rows[0][0])]
		check(DeepDescent.revealed(state, shallow) != bool(shallow.hidden), "depth 1 is lit unless it is a dark mouth")
		## Walk the first way offered: the offers after it are exactly where it leads.
		var first: String = str(state.offers[0].id)
		for unit in state.players:
			cmd(state, str(unit.id), "vote_tunnel", {"offer": first})
		check(str(state.map.at) == first and int(state.depth) == 1, "the party stands in the chamber it chose")
		var walked: int = 0
		while str(state.phase) != "tunnels" and str(state.phase) != "over" and walked < 60:
			walked += 1
			_advance_once(state)
		if str(state.phase) == "tunnels" and int(state.depth) == 1:
			var ways: Array = state.offers.map(func(o: Dictionary) -> String: return str(o.id))
			check(ways == map.nodes[first].next, "the tunnels on are the ways the chamber leads (%s)" % str(ways))
			check(DeepDescent.revealed(state, deep) != bool(deep.hidden), "one depth down, the lantern reaches depth 3")
	## Lighting the way costs ore; it reveals the next floor's dark mouths only.
	var clear_floor: Dictionary = DeepDescent.new_run(config(10, true))
	DeepDescent.player(clear_floor, "a").ore = 25
	check(not DeepDescent.needs_light(clear_floor) and not cmd(clear_floor, "a", "light").ok,
		"the lantern cannot charge pyrite when the next floor has no dark mouths")
	var lit: Dictionary = DeepDescent.new_run(config(11, true))
	var a: Dictionary = DeepDescent.player(lit, "a")
	for id in lit.map.rows[0]:
		lit.map.nodes[str(id)].hidden = true
	var next_floor: Dictionary = lit.map.nodes[str(lit.map.rows[0][0])]
	var later_floor: Dictionary = lit.map.nodes[str(lit.map.rows[1][0])]
	a.ore = 3
	check(not cmd(lit, "a", "light").ok, "three pyrite is not enough to light the way")
	a.ore = 25
	check(cmd(lit, "a", "light").ok and int(a.ore) == 25 - DeepDescent.lantern_cost() and int(lit.map.lit_to) == 1,
		"lighting the way is paid in pyrite and reaches only the next floor")
	check(DeepDescent.revealed(lit, next_floor) and not DeepDescent.revealed(lit, later_floor), "lighting depth 1 does not reveal depth 2")
	check(not cmd(lit, "b", "light").ok, "the same floor cannot be lit twice")
	lit.depth = 1
	lit.map.at = str(lit.map.rows[0][0])
	for id in lit.map.rows[1]:
		lit.map.nodes[str(id)].hidden = true
	check(DeepDescent.needs_light(lit), "the lantern can be used again when the next floor has dark mouths")
	check(cmd(lit, "a", "light").ok and int(lit.map.lit_to) == 2 and DeepDescent.revealed(lit, later_floor),
		"lighting after moving down reveals the new next floor")
	## A landing charts the stretch below before anyone chooses to descend.
	var deeper: Dictionary = DeepDescent.new_run(config(101, true))
	var guard: int = 0
	while int(deeper.depth) < 4 and guard < 60 and str(deeper.phase) != "over":
		guard += 1
		_advance_once(deeper)
	if str(deeper.phase) == "landing":
		check(int(deeper.map.from) == 4 and int(deeper.map.to) == 8 and bool(deeper.map.nodes.landing.warden), "the landing charts the way to the warden at 8")
		check(DeepDescent.lit_to(deeper) == int(deeper.map.from), "a new stretch starts with no paid lighting")

func _test_abandon() -> void:
	var state: Dictionary = DeepDescent.new_run(config(77, false))
	for unit in state.players:
		unit.haul.append(DeepForge.roll_stone(DeepRng.streams(4).stones, DeepContent.mine("QUARRY"), 3, 0, {}, "%s_raw" % unit.id))
	var rail_before: Array = DeepDescent.player(state, "a").rail.duplicate(true)
	var r: Dictionary = cmd(state, "a", "abandon")
	check(r.ok and str(r.event.kind) == "abandoned" and state.phase == "salvage" and bool(state.abandoned), "abandoning the dig goes to salvage")
	check(state.salvage.a.rolls.size() == 1 and state.salvage.b.rolls.size() == 1, "every raw stone rolls its salvage die")
	check(DeepDescent.player(state, "a").rail == rail_before, "the rail stones are safe")
	check(not cmd(state, "a", "abandon").ok, "not twice")
	cmd(state, "a", "ready")
	cmd(state, "b", "ready")
	check(state.phase == "over" and state.outcome == "fallen", "it ends as a fall")

func _test_landing_commands() -> void:
	var state: Dictionary = DeepDescent.new_run(config(101, true))
	var a: Dictionary = DeepDescent.player(state, "a")
	var b: Dictionary = DeepDescent.player(state, "b")
	## The bench is open before anything has happened: in the tunnels at the top.
	check(cmd(state, "a", "socket", {"stone_id": "a_mend", "index": 3}).ok and a.rail[3].id == "a_mend", "the bench is open in the tunnels: a Green stone fits an Any socket")
	check(cmd(state, "a", "socket", {"stone_id": "a_mend", "index": 2}).ok and a.rail[2].id == "a_mend" and a.rail[3] == null, "and moves back to its Green one")
	check(cmd(state, "a", "swap_die", {"index": 0, "die_id": "a1"}).ok and str(a.dice[0].id) == "a1" and str(a.dice[1].id) == "a0", "two dice in the tray change places")
	check(not cmd(state, "a", "swap_die", {"index": 0, "die_id": "a1"}).ok, "a die cannot swap with itself")
	## Walk a strong party straight to the first landing.
	var guard: int = 0
	while state.depth < 4 and guard < 40 and str(state.phase) != "over":
		guard += 1
		_advance_once(state)
	check(state.phase == "landing" and state.depth == 4, "the party arrives at the landing at depth 4 (phase %s, depth %d)" % [str(state.phase), int(state.depth)])
	check(not state.landing.has("stock"), "a landing keeps no stall: merchants are chambers of their own")
	var raw: Dictionary = DeepForge.roll_stone(DeepRng.streams(1).stones, DeepContent.mine("QUARRY"), 3, 0, {}, "raw1")
	raw.skill = "VENOM"
	a.haul.append(raw)
	check(not cmd(state, "a", "socket", {"stone_id": "raw1", "index": 3}).ok, "a raw stone cannot be set")
	check(not cmd(state, "a", "appraise", {"stone_id": "raw1"}).ok, "there is no paid lens at a landing")
	check(not cmd(state, "a", "sell", {"stone_id": "a_strike"}).ok and not cmd(state, "a", "buy", {"item_id": "x"}).ok, "nor anyone to trade with")
	## The cage stands beside the fire, the bench and the wheel: any of the four may be walked
	## up to first, and a party in a hurry may ride up without taking its respite at all.
	## The winch wants paying first, and it wants more from deeper down: so much a depth for
	## every body in the cage, out of the party's pooled pyrite.
	check(not cmd(state, "a", "choose", {"choice": "descend"}).ok, "the way down waits on the respite")
	var fare: int = DeepDescent.lift_cost(state)
	check(fare == 15 * 4 * 2, "the winch wants fifteen pyrite a depth a head: %d at depth 4 for two" % fare)
	a.ore = 0
	b.ore = 0
	check(not cmd(state, "a", "choose", {"choice": "lift"}).ok, "and no cage moves on empty pockets")
	## One full pocket is enough: the fare is the party's, not each player's.
	a.ore = fare
	check(cmd(state, "a", "choose", {"choice": "lift"}).ok and str(a.choice) == "lift", "but the cage does not: it is a fourth thing to walk up to")
	a.choice = ""
	check(not cmd(state, "a", "respite", {"choice": "nap"}).ok, "rest, appraise or the well, nothing else")
	check(not cmd(state, "a", "respite", {"choice": "appraise", "stone_id": "a_strike"}).ok, "the landing's appraisal is for a raw stone")
	check(cmd(state, "a", "respite", {"choice": "appraise", "stone_id": "raw1"}).ok and bool(raw.appraised) and str(a.respite) == "appraise", "the landing appraises one raw stone free")
	check(not cmd(state, "a", "respite", {"choice": "rest"}).ok, "one respite a landing")
	check(str(state.landing.respites.a.choice) == "appraise", "the landing remembers what each player did")
	check(not cmd(state, "b", "respite", {"choice": "wish", "stone_id": "nothing"}).ok, "the well needs a stone you carry")
	var rough: Dictionary = stone("GUARD", 3, 2, 3, "b_rough")
	rough.appraised = true
	b.haul.append(rough)
	## The landing's well is the shaft's well: the stone goes and something may come back.
	var before_well: int = b.haul.size()
	var wished: Dictionary = cmd(state, "b", "respite", {"choice": "wish", "stone_id": "b_rough"})
	check(wished.ok and DeepOddities.find_stone(b, "b_rough").is_empty(), "the well takes the stone")
	check(wished.event.has("well") and int(wished.event.well.rung) >= 0 and b.haul.size() <= before_well, "and answers with a rung of its ladder")
	## Whatever the well paid out, the fare below is counted from empty pockets.
	b.ore = 0
	a.respite = ""
	a.hp = 10
	var share: int = int(ceil(float(a.max_hp) * 0.3))
	check(cmd(state, "a", "respite", {"choice": "rest"}).ok and int(a.hp) == 10 + share, "resting gives back 30%% of the most health (%d)" % int(a.hp))
	## The bench still works here, and a socket keeps to its colour down the mine as it does
	## at home: a Violet stone has no business in a Red socket.
	raw.appraised = true
	raw.inclusions_revealed = true
	check(not cmd(state, "a", "socket", {"stone_id": "raw1", "index": 0}).ok, "a Violet stone is refused by the Red socket, run or no run")
	check(cmd(state, "a", "socket", {"stone_id": "raw1", "index": 4}).ok and a.rail[4].id == "raw1", "and goes into the Any socket at the end")
	check(cmd(state, "a", "unsocket", {"index": 4}).ok and a.rail[4] == null and a.haul.filter(func(s: Dictionary) -> bool: return str(s.id) == "raw1").size() == 1, "and comes back out into the haul")
	a.bag_dice.append(DeepDice.make("D8", "spare"))
	check(not cmd(state, "a", "swap_die", {"index": 0, "die_id": "spare"}).ok and str(a.dice[0].id) != "spare", "a die from outside the five never takes a slot")
	check(not cmd(state, "a", "give", {"to": "b", "item_id": "spare"}).ok, "nor is a die handed to an ally")
	a.bag_dice.clear()
	check(not cmd(state, "a", "give", {"to": "a", "item_id": "x"}).ok, "not to yourself")
	## Once the respite is taken the cage is behind you: the only way left is down.
	check(not cmd(state, "a", "choose", {"choice": "lift"}).ok, "the lift is gone once a respite is taken")
	a.respite = ""
	b.respite = ""
	check(cmd(state, "a", "choose", {"choice": "lift"}).ok and state.phase == "landing", "one vote for the lift waits")
	a.respite = "rest"
	b.respite = "rest"
	check(cmd(state, "b", "choose", {"choice": "descend"}).ok, "the other votes to descend")
	check(state.phase == "over" and state.outcome == "extracted" and state.depth == 4, "a tie goes to the first seat, who chose the lift: extracted at depth 4")
	check(int(a.ore) == 0 and int(b.ore) == 0, "and the winch took the whole fare, the empty pocket's share off the full one")
	check(not cmd(state, "a", "choose", {"choice": "descend"}).ok, "nothing more once the run is over")
	check(not cmd(state, "a", "unsocket", {"index": 0}).ok, "and the bench is closed")

func _test_merchant() -> void:
	## Walk one step down, then make the next tunnel a stall.
	var state: Dictionary = DeepDescent.new_run(config(131, true))
	var guard: int = 0
	while (str(state.phase) != "tunnels" or int(state.depth) < 1) and guard < 40:
		guard += 1
		_advance_once(state)
	var offer: Dictionary = state.offers[0]
	offer.kind = "merchant"
	for unit in state.players:
		cmd(state, str(unit.id), "vote_tunnel", {"offer": offer.id})
	var stall_a: Array = DeepDescent.stall_stock(state, "a")
	var stall_b: Array = DeepDescent.stall_stock(state, "b")
	check(state.phase == "chamber" and str(state.chamber.kind) == "merchant" and stall_a.size() == 4, "a merchant lays out three stones and a die for each player")
	check(stall_a.filter(func(i: Dictionary) -> bool: return str(i.kind) == "stone").size() == 3 and stall_a.filter(func(i: Dictionary) -> bool: return str(i.kind) == "die").size() == 1, "three stones and one die")
	check(stall_a.map(func(i: Dictionary) -> String: return str(i.id)) != stall_b.map(func(i: Dictionary) -> String: return str(i.id)), "and every player is shown their own stall")
	var offered_die: Dictionary = stall_a.filter(func(i: Dictionary) -> bool: return str(i.kind) == "die")[0]
	var own_shapes: Array = DeepDescent.player(state, "a").dice.map(func(d: Dictionary) -> String: return str(d.shape))
	check(own_shapes.has(str(offered_die.die.shape)), "a die is only offered in a size that player carries")
	var variations: int = (1 if not str(offered_die.die.get("pattern", "")).is_empty() else 0) + (1 if not DeepDice.etchings(offered_die.die).is_empty() else 0) + (1 if not str(offered_die.die.get("material", "")).is_empty() else 0)
	check(variations >= 1 and variations <= 2, "and it carries one variation or two, never none and never all three: %d" % variations)
	check(stall_a.filter(func(i: Dictionary) -> bool: return str(i.kind) == "loupe").is_empty(), "and no loupes")
	var a: Dictionary = DeepDescent.player(state, "a")
	var b: Dictionary = DeepDescent.player(state, "b")
	var raws: Array = []
	for index in range(3):
		var raw: Dictionary = DeepForge.roll_stone(DeepRng.streams(5 + index).stones, DeepContent.mine("QUARRY"), 3, 0, {}, "raw%d" % index)
		a.haul.append(raw)
		raws.append(raw)
	a.ore = 0
	check(not cmd(state, "a", "appraise", {"stone_id": "raw0"}).ok, "no pyrite, no appraisal")
	## A stone nobody has read still sells, for what its size class alone is worth.
	a.haul.append(DeepStone.make("STRIKE", 12, 3, 4, [], {}, "rough_lot"))
	check(cmd(state, "a", "sell", {"stone_id": "rough_lot"}).ok and int(a.ore) == DeepStone.rough_value(DeepStone.make("STRIKE", 12, 3, 4)) and int(a.ore) > 0,
		"a rough stone sells for its size class (%d pyrite)" % int(a.ore))
	check(int(a.ore) < DeepStone.value(DeepStone.make("STRIKE", 12, 3, 4)) / 2, "and for less than the same stone read")
	a.ore = 200
	check(DeepDescent.appraise_cost(state, "a") == 50, "the first appraisal at a stall costs fifty")
	check(cmd(state, "a", "appraise", {"stone_id": "raw0"}).ok and bool(raws[0].appraised) and int(a.ore) == 150, "the lens appraises a raw stone for pyrite")
	check(DeepDescent.appraise_cost(state, "a") == 100 and DeepDescent.appraise_cost(state, "b") == 50, "each appraisal costs the asker fifty more, and nobody else")
	check(cmd(state, "a", "appraise", {"stone_id": "raw1"}).ok and int(a.ore) == 50, "the second costs a hundred")
	check(not cmd(state, "a", "appraise", {"stone_id": "raw1"}).ok, "not twice")
	var ore_before: int = int(a.ore)
	check(cmd(state, "a", "sell", {"stone_id": "raw1"}).ok and int(a.ore) > ore_before, "an appraised stone sells for pyrite")
	var item: Dictionary = DeepDescent.stall_stock(state, "a")[2]
	a.ore = 0
	check(not cmd(state, "a", "buy", {"item_id": item.id}).ok, "no pyrite, no stone")
	a.ore = int(item.price) + 10
	var haul_before: int = a.haul.size()
	check(cmd(state, "a", "buy", {"item_id": item.id}).ok and a.haul.size() == haul_before + 1 and int(a.ore) == 10 and str(item.sold) == "a", "a stone goes to the haul for its price and is marked sold")
	check(a.bag_dice.is_empty(), "and nothing goes to the bag of dice")
	check(not cmd(state, "b", "buy", {"item_id": item.id}).ok, "the other player cannot buy it again")
	check(cmd(state, "a", "swap_die", {"index": 0, "die_id": str(a.dice[1].id)}).ok, "the bench is open at the stall too")
	var unsold: String = str(DeepDescent.stall_stock(state, "a")[0].id)
	check(cmd(state, "a", "leave").ok and str(state.phase) == "chamber", "one player leaving waits for the other")
	check(not cmd(state, "a", "leave").ok, "leaving twice is refused")
	check(cmd(state, "b", "leave").ok and str(state.phase) == "tunnels", "when everyone has left, the tunnels open")
	check(DeepDescent.appraise_cost(state, "a") == 50, "the next stall starts its price again")
	check(not cmd(state, "a", "buy", {"item_id": unsold}).ok, "the stall is gone once the party walks on")

func _test_dice_rooms() -> void:
	## A smithy, a carver and a vat: one fixed card each, one piece of work a player, and
	## never a die that comes or goes — whole dice are bought at a merchant, not here.
	for kind in DeepDescent.DICE_ROOMS:
		var state: Dictionary = DeepDescent.new_run(config(141, true))
		var offer: Dictionary = state.offers[0]
		offer.kind = kind
		for unit in state.players:
			cmd(state, str(unit.id), "vote_tunnel", {"offer": offer.id})
		check(state.phase == "chamber" and str(state.chamber.kind) == kind and str(state.chamber.oddity) == DeepDescent.room_card(kind), "a %s holds its own card" % kind)
		check(state.used_oddities.is_empty(), "and uses up no oddity")
		var a: Dictionary = DeepDescent.player(state, "a")
		var die: Dictionary = a.dice[0]
		var shape: String = str(die.shape)
		var ids: Array = a.dice.map(func(d: Dictionary) -> String: return str(d.id))
		match kind:
			"smithy":
				check(cmd(state, "a", "oddity", {"choice": "hammer", "payload": {"die_id": str(die.id)}}).ok, "the smithy hammers a die")
				check(DeepOddities.SIZES.find(str(a.dice[0].shape)) == DeepOddities.SIZES.find(shape) + 1, "a size bigger (%s to %s)" % [shape, str(a.dice[0].shape)])
			"carver":
				var low: int = int(a.dice[0].faces[0].value)
				check(cmd(state, "a", "oddity", {"choice": "raise", "payload": {"die_id": str(die.id), "face": 0}}).ok and int(a.dice[0].faces[0].value) == low + 1, "the carver raises a face")
			"vat":
				check(str(state.chamber.get("offer", {}).get("material", "")) in DeepDice.MATERIALS, "the vat has something in it before anybody chooses")
				var dipped: Dictionary = cmd(state, "a", "oddity", {"choice": "dip", "payload": {"die_id": str(die.id)}})
				check(dipped.ok and str(a.dice[0].material) == str(state.chamber.offer.material), "the vat makes a die of what is in it")
				check(a.dice[0].faces.size() == int(DeepDice.SHAPES[shape]) and str(a.dice[0].shape) == shape, "and leaves its faces alone")
		check(not cmd(state, "a", "oddity", {"choice": "pass"}).ok, "one piece of work each")
		check(a.dice.map(func(d: Dictionary) -> String: return str(d.id)) == ids and a.bag_dice.is_empty(), "the five are the same five")
		check(cmd(state, "b", "oddity", {"choice": "pass"}).ok and str(state.phase) == "tunnels", "once everyone has chosen the tunnels open")
	## A card drawn by chance is never a room's, and a vein never holds a die.
	var drawn: Dictionary = {}
	for seed_value in range(40):
		var state: Dictionary = DeepDescent.new_run(config(600 + seed_value, true))
		var offer: Dictionary = state.offers[0]
		offer.kind = "oddity" if seed_value % 2 == 0 else "vein"
		for unit in state.players:
			cmd(state, str(unit.id), "vote_tunnel", {"offer": offer.id})
		if str(offer.kind) == "oddity":
			drawn[str(state.chamber.oddity)] = true
		else:
			check(state.chamber.vein.spots.all(func(s: Dictionary) -> bool: return str(s.kind) in ["stone", "ore", "nothing"]), "a vein holds stones, pyrite or dust (seed %d)" % seed_value)
	check(not drawn.has("SMITHY") and not drawn.has("CARVER") and drawn.size() > 5, "chance never draws a room's card (%s)" % ", ".join(drawn.keys()))

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
				## The rock never runs out of swings, only the arm does: swing until the rock
				## refuses the next blow, then put the pick down.
				for unit in state.players:
					if not bool(unit.get("mining", false)):
						continue
					for spot in state.chamber.vein.spots:
						if str(spot.taken).is_empty():
							if cmd(state, str(unit.id), "strike", {"spot": spot.index}).ok:
								return
							break
					cmd(state, str(unit.id), "stop_mining", {})
					return
			elif str(state.chamber.kind) == "merchant":
				for unit in state.players:
					if not bool(unit.get("ready", false)):
						cmd(state, str(unit.id), "leave")
						return
			elif str(state.chamber.kind) in ["oddity"] + DeepDescent.CARD_ROOMS:
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
				if str(unit.get("respite", "")).is_empty():
					cmd(state, str(unit.id), "respite", {"choice": "rest"})
					return
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
	## A strong party digs past the first warden, takes the hoard and carries it on to the next
	## lift: the Warden's hall has no cage of its own to ride up out of.
	var state: Dictionary = DeepDescent.new_run(config(202, true))
	var guard: int = 0
	var saw_warden: bool = false
	var saw_hoard: bool = false
	var bench_checked: bool = false
	var hall_checked: bool = false
	var mirror: Dictionary = state.duplicate(true)
	while str(state.phase) != "over" and guard < 600:
		guard += 1
		var before: Dictionary = state.duplicate(true)
		if str(state.phase) == "landing" and state.depth == 8 and bool(state.landing.get("cleared", false)):
			## The hall the Warden died in has no cage: asking for one is refused, and the only
			## way on is down to the next landing.
			if not hall_checked:
				hall_checked = true
				check(not cmd(state, "a", "choose", {"choice": "lift"}).ok, "a Warden's hall offers no lift")
			_advance_once(state)
		elif str(state.phase) == "landing" and state.depth > 8 and not bool(state.landing.get("cleared", false)) and saw_hoard:
			## The winch is paid out of the party's pocket; this run is about the loop, not the
			## economy, so the fare is simply there.
			state.players[0].ore = int(state.players[0].ore) + DeepDescent.lift_cost(state)
			for unit in state.players:
				cmd(state, str(unit.id), "choose", {"choice": "lift"})
		else:
			_advance_once(state)
		if DeepDescent.in_battle(state) and not bench_checked:
			bench_checked = true
			check(not cmd(state, "a", "unsocket", {"index": 0}).ok, "the bench waits until the fight is over")
		if str(state.chamber.get("kind", "")) == "warden":
			saw_warden = true
		if str(state.phase) == "hoard":
			saw_hoard = true
		mirror = DeepPatch.apply(mirror, DeepPatch.diff(before, state))
	check(state.phase == "over", "the run ends (guard %d)" % guard)
	check(saw_warden and saw_hoard, "the party fought the warden and took the hoard")
	check(state.outcome == "extracted" and state.depth > 8 and state.records.wardens == [8], "extracted from the first landing below the warden: %s depth %d wardens %s" % [str(state.outcome), int(state.depth), str(state.records.wardens)])
	check(JSON.stringify(mirror) == JSON.stringify(state), "a mirror fed patches of every command matches the host")
	check(state.players.all(func(p: Dictionary) -> bool: return p.bag_dice.is_empty() and p.dice.size() == 5), "no die was found, bought or given on the way down")
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
				## Straight into the cage: the lift is walked up to before the respite, not
				## after it, so a party that has had enough may leave at once. The winch's fare
				## comes out of the party's pocket, so it is put there first.
				weak.players[0].ore = int(weak.players[0].ore) + DeepDescent.lift_cost(weak)
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

func _test_hoard_opal() -> void:
	## The Warden's pile: three stones still in their rock, the middle one an opal, a gem
	## nothing else in the mine offers. Nothing on the pedestals has been read, so the choice
	## is three gambles and the loupe settles it afterwards.
	var state: Dictionary = DeepDescent.new_run(config(414, true))
	state.depth = 8
	DeepDescent._offer_hoard(state)
	var offers: Array = state.hoard.a.offers
	check(offers.size() == 3 and offers.all(func(s: Dictionary) -> bool: return not bool(s.appraised) and not bool(s.inclusions_revealed)), "all three lie there unread, in their rock")
	var opal: Dictionary = offers[1]
	check(DeepStone.is_opal(opal), "the middle one is an opal: %s" % str(opal.skill))
	check(not DeepStone.fits(opal, "RED") and not DeepStone.fits(opal, "GOLD") and DeepStone.fits(opal, "ANY"), "an opal answers to none of the six: only an ANY socket takes it")
	var picked: Dictionary = cmd(state, "a", "pick_hoard", {"stone_id": str(opal.id)})
	check(picked.ok and bool(picked.event.raw) and not bool(picked.event.stone.appraised),
		"the opal comes off the pile raw")
	check(DeepDescent.player(state, "a").haul.any(func(s: Dictionary) -> bool: return str(s.id) == str(opal.id) and not bool(s.get("appraised", false))),
		"and goes into the haul that way, for a lens to open later")
	check(DeepDescent.player(state, "a").haul.any(func(s: Dictionary) -> bool: return DeepStone.is_opal(s)), "and the opal goes in the haul")
	## The opal is the rare colour, not the rich one: rolled with less luck, it is generally
	## the smaller stone on the pile.
	var opal_carats: float = 0.0
	var other_carats: float = 0.0
	for trial in range(60):
		var pile: Dictionary = DeepDescent.new_run(config(900 + trial, true))
		pile.depth = 8
		DeepDescent._offer_hoard(pile)
		var stones: Array = pile.hoard.a.offers
		opal_carats += float(stones[1].carat)
		other_carats += (float(stones[0].carat) + float(stones[2].carat)) / 2.0
	check(opal_carats < other_carats, "a hoard's opal runs smaller than its other stones (%.1f vs %.1f carat on average)" % [opal_carats / 60.0, other_carats / 60.0])
	## And nothing else in the mine ever hands one out.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var wild: int = 0
	for _roll in range(400):
		if DeepStone.is_opal(DeepForge.roll_stone(rng, DeepContent.mine("QUARRY"), 20, 8)):
			wild += 1
	check(wild == 0, "no vein, drop or merchant ever cuts an opal (%d of 400)" % wild)

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
	## What the run taught outlives the run. Every gem read down there — the ones set in the
	## rail and the ones the salvage die took away — is in the vault's record of what the
	## player has laid eyes on, so a wipe still fills in the page for a gem they once held.
	var lost: Array = []
	for roll in rolls:
		if not bool(roll.kept) and bool(roll.stone.get("appraised", false)):
			lost.append(str(roll.stone.skill))
	var railed: Array = []
	for item in DeepDescent.player(state, "a").rail:
		if item is Dictionary and bool(item.get("appraised", false)):
			railed.append(str(item.skill))
	check(not railed.is_empty(), "the fallen party went down with gems in the rail")
	var results: Dictionary = DeepDescent.results(state)
	var seen: Array = results.players.a.get("seen", [])
	for skill in railed + lost:
		check(seen.has(skill), "%s was read this run and the run says so" % skill)
	var profile: Dictionary = DeepProfile.new_profile("Fallen")
	profile.vault.clear()
	profile.seen.clear()
	DeepProfile.apply_result(profile, results, "a")
	for skill in railed + lost:
		check(profile.seen.has(skill) and not profile.vault.has(skill), "%s reaches the vault as seen, not as owned, after a loss" % skill)

func _test_profile() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Ada")
	check(profile.vault.has("STRIKE") and profile.vault.has("GUARD") and profile.vault.has("MEND"), "a new profile owns three starter stones")
	check(profile.characters.ARDOR.unlocked and not profile.characters.FLORIN.unlocked and profile.current_character == "ARDOR", "only Ardor is unlocked, and chosen")
	check(profile.bowl.size() == 5, "the bowl holds Ardor's five dice")
	var loadout: Dictionary = DeepProfile.loadout(profile, "ARDOR")
	check(loadout.rail.size() == 5 and loadout.rail[0].skill == "STRIKE" and loadout.rail[1].skill == "GUARD" and loadout.rail[2].skill == "MEND" and loadout.rail[3] == null and loadout.dice.size() == 5, "the loadout is stones and dice ready for a run")
	var ardor_dice: Array = DeepContent.character("ARDOR").get("dice", [])
	check(loadout.dice.map(func(d: Dictionary) -> String: return str(d.shape)) == ardor_dice, "and the dice are Ardor's own: %s" % str(loadout.dice.map(func(d: Dictionary) -> String: return str(d.shape))))
	check(DeepProfile.set_rail(profile, "ARDOR", 3, "STRIKE") != "" and profile.characters.ARDOR.rail[0] == "STRIKE" and profile.characters.ARDOR.rail[3] == null, "the fourth socket is only filled in the mine")
	check(DeepProfile.set_rail(profile, "ARDOR", 1, "MEND") != "", "a Green stone does not fit the Blue socket")
	check(DeepProfile.set_rail(profile, "ARDOR", 2, null) == "" and DeepProfile.set_rail(profile, "ARDOR", 2, "MEND") == "", "a stone comes out and goes back in")
	check(DeepProfile.set_rail(profile, "FLORIN", 0, "STRIKE") != "", "a locked character refuses")
	check(DeepProfile.next_locked_character(profile) == "VESPER", "Vesper is the next unlock")
	var better: Dictionary = DeepStone.make("STRIKE", 9, 3, 4, [], {"source": "test"}, "better")
	var kept: Dictionary = DeepProfile.keep(profile, better)
	check(kept.replaced.carat == 2 and profile.gold == kept.paid and profile.vault.STRIKE.carat == 9, "keeping a second Strike sells the first")
	check(profile.records.best.stone.id == "better", "the best stone is remembered")
	var grid: Array = DeepProfile.vault_grid(profile)
	check(grid.size() == DeepContent.section("skills").size(), "the grid lists every skill")
	check(grid.filter(func(g: Dictionary) -> bool: return str(g.state) == "owned").size() == 3, "three owned")
	## A loadout fills only the first few sockets; the rest are filled in the mine.
	DeepProfile.keep(profile, DeepStone.make("CLEAVE", 4, 2, 2, [], {"source": "test"}, "cleave1"))
	check(DeepProfile.starting_rail_cap() == 3, "a loadout fills three sockets by default")
	check(DeepProfile.fillable_socket(profile, "ARDOR", 2) and not DeepProfile.fillable_socket(profile, "ARDOR", 3), "the third socket is the last one open")
	check(DeepProfile.set_rail(profile, "ARDOR", 3, "CLEAVE") != "" and DeepProfile.set_rail(profile, "ARDOR", 4, "CLEAVE") != "", "a stone is refused in a socket only the mine fills")
	check(DeepProfile.set_rail(profile, "ARDOR", 0, "CLEAVE") == "" and profile.characters.ARDOR.rail[0] == "CLEAVE", "a stone set over another replaces it")
	check(DeepProfile.set_rail(profile, "ARDOR", 0, "STRIKE") == "", "and Strike goes back")
	## An old save that set a stone past the third socket: it moves to an empty one it fits.
	profile.characters.ARDOR.rail = [null, "GUARD", "MEND", "STRIKE", null]
	check(DeepProfile.tidy(profile) and profile.characters.ARDOR.rail == ["STRIKE", "GUARD", "MEND", null, null], "a stone in a mine socket moves into the loadout: %s" % str(profile.characters.ARDOR.rail))
	check(not DeepProfile.tidy(profile), "and a tidy rail is left as it is")
	var result: Dictionary = {"run_id": "r1", "mine": "QUARRY", "outcome": "extracted", "depth": 8, "deepest": 8, "wardens": [8], "mines": [{"mine": "QUARRY", "deepest": 8, "wardens": [8], "boss": false}],
		"players": {"a": {"haul": [DeepStone.make("VENOM", 4, 2, 2, ["SILK"], {}, "v1"), DeepStone.make("STRIKE", 1, 0, 3, [], {}, "s1")], "dice": [DeepDice.make("D20", "d20x")], "stats": {}, "rail": []}}}
	var applied: Dictionary = DeepProfile.apply_result(profile, result, "a")
	check(profile.tray.size() == 2 and profile.bowl.size() == 6, "two stones wait in the tray and a die joins the bowl (%d)" % profile.bowl.size())
	check(profile.mines.QUARRY.deepest == 8 and profile.mines.QUARRY.wardens == [8] and profile.records.runs == 1 and profile.records.extractions == 1, "records are written")
	check(applied.unlocked.is_empty() and not profile.characters.VESPER.unlocked and not profile.mines.SEEPS.unlocked, "the Quarry's Wardens unlock nobody, and its boss still stands: %s" % str(applied.unlocked))
	## A party that beat the Quarry's boss, pushed on into the Seeps and fell past its first
	## Warden: the Seeps opens and Vesper, who is met there, joins, though nobody rode up.
	var pushed: Dictionary = {"run_id": "r2", "mine": "SEEPS", "from_mine": "QUARRY", "outcome": "fallen", "depth": 9, "deepest": 9, "wardens": [8],
		"mines": [{"mine": "QUARRY", "deepest": 16, "wardens": [8, 12, 16], "boss": true}, {"mine": "SEEPS", "deepest": 9, "wardens": [8], "boss": false}],
		"players": {"a": {"haul": [], "dice": [], "stats": {}, "rail": []}}}
	applied = DeepProfile.apply_result(profile, pushed, "a")
	check(applied.unlocked.size() == 2 and applied.unlocked[0].get("mine", "") == "SEEPS" and applied.unlocked[1].get("character", "") == "VESPER", "the boss opens the Seeps and its first Warden brings Vesper: %s" % str(applied.unlocked))
	check(profile.mines.QUARRY.boss and profile.mines.QUARRY.wardens == [8, 12, 16] and profile.mines.SEEPS.unlocked and profile.mines.SEEPS.deepest == 9 and profile.characters.VESPER.unlocked,
		"both mines are written down")
	check(profile.bowl.size() == 11 and profile.records.runs == 2 and profile.records.falls == 1, "Vesper's five dice join the bowl (%d)" % profile.bowl.size())
	check(not DeepProfile.unlocked_mines(profile).has("GLASS_VEINS") and DeepProfile.unlocked_mines(profile).has("SEEPS"), "the Glass Veins stay sealed")
	check(DeepProfile.open_sockets(profile, "VESPER") == 3 and not DeepProfile.fillable_socket(profile, "VESPER", 3),
		"a deeper mine open changes nothing: a lapidary fills only the sockets they have opened, in any mine")
	check(DeepProfile.loadout(profile, "VESPER").rail.slice(3).all(func(s: Variant) -> bool: return s == null), "and the rest go down empty")
	## Vesper's two Red sockets: a stone moves between them, and swaps with one already there.
	check(DeepProfile.set_rail(profile, "VESPER", 0, "STRIKE") == "" and DeepProfile.set_rail(profile, "VESPER", 1, "STRIKE") == "" and profile.characters.VESPER.rail.slice(0, 2) == [null, "STRIKE"], "moving a stone empties its old socket")
	check(DeepProfile.set_rail(profile, "VESPER", 0, "CLEAVE") == "" and DeepProfile.set_rail(profile, "VESPER", 0, "STRIKE") == "" and profile.characters.VESPER.rail.slice(0, 2) == ["STRIKE", "CLEAVE"], "a stone moved onto another swaps them: %s" % str(profile.characters.VESPER.rail))
	## Dice are never swapped: whatever an old save put in a slot, the loadout rolls their own.
	profile.characters.VESPER.dice[0] = "d20x"
	check(DeepProfile.loadout(profile, "VESPER").dice.map(func(d: Dictionary) -> String: return str(d.shape)) == DeepContent.character("VESPER").get("dice", []), "a lapidary always goes down with their own dice")
	## An old profile that wore settings comes across with its unlocks counted.
	var old: Dictionary = {"schema": 1, "id": "pfold", "name": "Old", "gold": 5, "vault": profile.vault.duplicate(true), "seen": [], "bowl": [], "mines": {}, "tray": [],
		"settings": {"SIGNET": {"unlocked": true, "rail": [], "dice": []}, "GAUNTLET": {"unlocked": true, "rail": [], "dice": []}, "CHAIN": {"unlocked": false}}, "current_setting": "GAUNTLET",
		"records": {"runs": 0, "extractions": 0, "falls": 0, "conquests": 0, "stones_kept": 0, "best": {}}, "history": [], "next_id": 1}
	var moved: Dictionary = DeepProfile.migrate(old)
	check(not moved.has("settings") and moved.current_character == "ARDOR" and moved.characters.ARDOR.unlocked and moved.characters.VESPER.unlocked and not moved.characters.CADENCE.unlocked, "one earned setting becomes one earned character")
	check(moved.characters.ARDOR.rail[0] == "STRIKE" and moved.bowl.size() == 10, "the vault is set into Ardor's rail and both characters' dice fill the bowl (%d)" % moved.bowl.size())
	var gold_before: int = profile.gold
	var decided: Dictionary = DeepProfile.decide_tray(profile, "s1", true)
	check(decided.ok and decided.kept and decided.replaced.id == "better" and profile.vault.STRIKE.id == "s1", "the player may keep a worse stone; the better one is sold")
	check(profile.gold > gold_before, "and paid for it")
	## A stone nobody has read is nobody's first: sold rough it goes to a buyer for its size
	## class and teaches the vault nothing, or the vault would be handing out free appraisals.
	var rough_gold: int = int(profile.gold)
	var unread: Dictionary = DeepProfile.decide_tray(profile, "v1", false)
	check(unread.ok and not unread.kept and not profile.vault.has("VENOM") and not profile.seen.has("VENOM"), "an unappraised stone sells rough rather than being forced into the vault")
	check(int(profile.gold) == rough_gold + DeepStone.rough_value(DeepStone.make("VENOM", 4, 2, 2, ["SILK"], {}, "v1")), "and a buyer pays the size class for it")
	## The first stone of a skill, once read, is never sold: asked to sell it, the vault takes it anyway.
	var known: Dictionary = DeepStone.make("VENOM", 4, 2, 2, ["SILK"], {}, "v1b")
	known.appraised = true
	profile.tray.append(known)
	var first: Dictionary = DeepProfile.decide_tray(profile, "v1b", false)
	check(first.ok and first.kept and bool(first.get("forced", false)) and profile.tray.is_empty() and profile.vault.has("VENOM"), "the first stone of a skill is kept whatever is asked")
	## One whose skill is already in the vault can go to a buyer.
	var second: Dictionary = DeepStone.make("VENOM", 1, 0, 3, [], {}, "v2")
	second.appraised = true
	profile.tray.append(second)
	var gold_then: int = int(profile.gold)
	var sold: Dictionary = DeepProfile.decide_tray(profile, "v2", false)
	check(sold.ok and not sold.kept and profile.tray.is_empty() and int(profile.gold) > gold_then and str(profile.vault.VENOM.id) == "v1b", "a second stone of a skill may be sold")
	check(not DeepProfile.decide_tray(profile, "zzz", true).ok, "an unknown tray stone is refused")


func _test_grubstake() -> void:
	## The shaft head: everyone sees three stakes, a fallen lapidary is shown mercy, everyone
	## takes exactly one stake, and the tunnels wait for the party.
	var setup: Dictionary = config(77, false)
	setup.boons = true
	setup.players[0].last_depth = 9
	setup.players[0].last_outcome = "extracted"
	setup.players[1].last_depth = 2
	setup.players[1].last_outcome = "fallen"
	var state: Dictionary = DeepDescent.new_run(setup)
	check(state.phase == "grubstake" and state.offers.is_empty(), "a run opens at the shaft head")
	var a_offers: Array = state.grubstake.offers.a
	var b_offers: Array = state.grubstake.offers.b
	var kinds_a: Array = a_offers.map(func(o: Dictionary) -> String: return str(o.kind))
	check(kinds_a == ["stone", "kit", "terms"], "three stakes and no more, a veteran or not: %s" % str(kinds_a))
	## A pick is three raw stones of three colors, and the one taken is read on the spot.
	var picks_seen: int = 0
	for seed_value in range(30):
		var c: Dictionary = config(300 + seed_value, false)
		c.boons = true
		var s: Dictionary = DeepDescent.new_run(c)
		for o in s.grubstake.offers.a:
			if not o.needs.has("pick"):
				continue
			picks_seen += 1
			var colors: Array = o.picks.map(func(st: Dictionary) -> String: return DeepStone.color(st))
			var distinct: Dictionary = {}
			for color in colors:
				distinct[color] = true
			check(o.picks.size() == 3 and distinct.size() == 3 and not colors.has("OPAL"), "a pick is three raw stones of three colors: %s" % str(colors))
			check(o.picks.all(func(st: Dictionary) -> bool: return not bool(st.appraised)), "none of them read until one is taken")
			var who: Dictionary = DeepDescent.player(s, "a")
			if not str(who.get("stake", "")).is_empty():
				continue
			var took: Dictionary = cmd(s, "a", "stake", {"offer": o.id, "payload": {"pick": 1}})
			check(took.ok and bool(took.event.pick) and took.event.made.size() == 1 and bool(took.event.made[0].appraised) and bool(took.event.made[0].inclusions_revealed), "the one taken is appraised at once: %s" % str(took.get("error", "")))
			check(who.haul.any(func(st: Dictionary) -> bool: return str(st.id) == str(o.picks[1].id) and bool(st.appraised)), "and goes into the haul known")
			check(str(took.event.message).contains("Under the loupe"), "and the words say so: %s" % str(took.event.message))
	check(picks_seen > 0, "some seed offered a pick (%d)" % picks_seen)
	check(b_offers.size() == 3 and DeepContent.boon(str(b_offers[1].boons[0])).get("tags", []).has("mercy"), "a lapidary who fell early is shown mercy: %s" % str(b_offers[1].boons))
	check(a_offers[2].boons.size() == 2 and DeepContent.boon(str(a_offers[2].boons[0])).group == "cost" and DeepContent.boon(str(a_offers[2].boons[1])).group == "reward", "terms are a cost and a reward")
	check(not cmd(state, "a", "vote_tunnel", {"offer": "x"}).ok, "no tunnels before the stake is taken")
	var picked: Array = a_offers.filter(func(o: Dictionary) -> bool: return o.needs.has("pick"))
	if not picked.is_empty():
		check(not cmd(state, "a", "stake", {"offer": picked[0].id, "payload": {}}).ok, "a pick stake needs one of its three")
	var take: Callable = func(who: String, offer: Dictionary) -> Dictionary:
		var payload: Dictionary = {}
		if offer.needs.has("pick"):
			payload.pick = 0
		return cmd(state, who, "stake", {"offer": offer.id, "payload": payload})
	var taken: Dictionary = take.call("a", a_offers[1])
	check(taken.ok and taken.event.kind == "staked" and DeepDescent.player(state, "a").stake == a_offers[1].id, "a stake is taken: %s" % str(taken.get("error", "")))
	check(not take.call("a", a_offers[0]).ok, "only one stake each")
	check(state.phase == "grubstake", "the party waits for everyone")
	var taken_b: Dictionary = take.call("b", b_offers[0])
	check(taken_b.ok and bool(taken_b.event.get("finished", false)) and state.phase == "tunnels" and not state.offers.is_empty(), "when everyone has staked the tunnels open: %s" % str(taken_b.get("error", "")))
	## Every effect, applied directly.
	var quiet: Dictionary = DeepDescent.new_run(config(78, false))
	var u: Dictionary = DeepDescent.player(quiet, "a")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var offer_of: Callable = func(keys: Array, needs: Array = []) -> Dictionary: return {"id": "t", "kind": "kit", "boons": keys, "needs": needs, "picks": [], "pick_kind": ""}
	var before_hp: int = int(u.max_hp)
	check(DeepBoons.apply(quiet, u, offer_of.call(["HARDY"]), {}, rng).ok and int(u.max_hp) == before_hp + int(round(before_hp * 0.12)) and u.hp == u.max_hp, "Hardy raises max and current health (%d to %d)" % [before_hp, int(u.max_hp)])
	check(DeepBoons.apply(quiet, u, offer_of.call(["STAKED"]), {}, rng).ok and int(u.ore) == 40, "Staked pays 40 pyrite")
	## A stake on a stone lands on one drawn at random from the rail, never an empty socket.
	## Everything it does is for the run: the rail is a copy of the vault, so a stake may
	## promise a truer cut or a heavier stone without either ever being farmable.
	var sockets_hit: Dictionary = {}
	for _i in range(24):
		var carats: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["STAKE_CARAT"], ["socket"]), {}, rng)
		sockets_hit[int(carats.socket)] = true
	check(sockets_hit.size() > 1 and sockets_hit.keys().all(func(k: int) -> bool: return u.rail[k] is Dictionary), "the socket is drawn at random, from set stones only: %s" % str(sockets_hit.keys()))
	var carats_before: Array = u.rail.map(func(s: Variant) -> int: return int(s.carat) if s is Dictionary else 0)
	var heavier: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["STAKE_CARAT"], ["socket"]), {}, rng)
	var heavy_at: int = int(heavier.socket)
	var heart: Dictionary = u.rail[heavy_at]
	check(heavier.ok and int(heart.carat) == mini(int(carats_before[heavy_at]) + 2, DeepStone.carat_max()) and int(heart.staked.carat) >= 2,
		"Weighed Heavier adds two carats for the run and marks the stone (%d carats)" % int(heart.carat))
	var cuts_before: Array = u.rail.map(func(s: Variant) -> int: return int(s.cut) if s is Dictionary else 0)
	var truer: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["STAKE_CUT"], ["socket"]), {}, rng)
	var truer_at: int = int(truer.socket)
	check(truer.ok and int(u.rail[truer_at].cut) == mini(int(cuts_before[truer_at]) + 1, DeepPatterns.STEPS - 1) and int(u.rail[truer_at].staked.cut) >= 1,
		"A Truer Set lifts a Cut step for the run and marks the stone")
	## The whole rail at once, and it steps clarity away from Clear on whichever side it leans.
	var whole_before: Array = u.rail.map(func(s: Variant) -> Array: return [int(s.carat), int(s.cut), int(s.clarity)] if s is Dictionary else [])
	var whole: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["REWARD_ALL"]), {}, rng)
	var clear: int = DeepContent.clear_index()
	var all_up: bool = true
	for index in range(u.rail.size()):
		if not u.rail[index] is Dictionary:
			continue
		var was: Array = whole_before[index]
		var now: Dictionary = u.rail[index]
		if int(now.carat) != mini(int(was[0]) + 1, DeepStone.carat_max()) or int(now.cut) != mini(int(was[1]) + 1, DeepPatterns.STEPS - 1):
			all_up = false
		if absi(int(now.clarity) - clear) <= absi(int(was[2]) - clear) and int(was[2]) != 0 and int(was[2]) != DeepContent.clarities().size() - 1:
			all_up = false
	check(whole.ok and all_up and whole.changed.size() >= 1, "The Whole Rail lifts every set stone: %s" % str(whole.get("message", "")))
	var bare: Dictionary = u.duplicate(true)
	bare.rail = [null, null, null, null, null]
	check(not DeepBoons.apply(quiet, bare, offer_of.call(["STAKE_CARAT"], ["socket"]), {}, rng).ok, "an empty rail is refused")
	var haul_before: int = u.haul.size()
	var raw: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["RAW_STONE"]), {}, rng)
	check(raw.ok and u.haul.size() == haul_before + 1 and bool(u.haul[u.haul.size() - 1].appraised), "A Read Stone joins the haul already read")
	var frail: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["FRAGILE_STONE"]), {}, rng)
	var loaned: Dictionary = u.haul[u.haul.size() - 1]
	check(frail.ok and DeepStone.is_fragile(loaned) and DeepStone.known_fragile(loaned) and bool(loaned.appraised),
		"A Fragile Find comes read, and is known to be fragile from the start")
	check(int(loaned.carat) > 0 and not DeepProfile.first_of_skill({"vault": {}}, loaned), "and it can never reach the vault")
	## And nothing a stake lent the rail rides the lift: a boosted stone taken out of its
	## socket and carried up in the haul arrives as the stone that went down.
	var lent: Dictionary = u.rail[heavy_at].duplicate(true)
	var lent_was: Dictionary = lent.staked.was.duplicate(true)
	var back: Dictionary = DeepStone.unstake(lent)
	check(not back.has("staked") and int(back.carat) == int(lent_was.carat) and int(back.cut) == int(lent_was.cut)
		and int(back.clarity) == int(lent_was.clarity) and back.inclusions == lent_was.inclusions,
		"a staked stone carried home comes back the way it went down (%d ct, not %d)" % [int(back.carat), int(u.rail[heavy_at].carat)])
	check(DeepBoons.apply(quiet, u, offer_of.call(["SOFT_ROCK"]), {}, rng).ok and int(u.run_mods.soft_rock) == 3, "Soft Rock is remembered for three fights")
	check(DeepBoons.apply(quiet, u, offer_of.call(["STEADY_HANDS"]), {}, rng).ok and int(u.run_mods.extra_rerolls.until_depth) == 4, "Steady Hands is remembered until the landing")
	var hp_before: int = int(u.hp)
	check(DeepBoons.apply(quiet, u, offer_of.call(["COST_WOUND"]), {}, rng).ok and int(u.hp) == hp_before - int(floor(hp_before * 0.3)), "A Bad Fall costs 30%% of current health (%d to %d)" % [hp_before, int(u.hp)])
	var wild: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["REWARD_WILD"]), {}, rng)
	check(wild.ok and wild.dice.size() == 1 and u.bag_dice.is_empty() and u.dice.any(func(d: Dictionary) -> bool: return d.faces.any(func(f: Dictionary) -> bool: return str(f.kind) == "wild")),
		"a Wild Face turns a face of one of the five wild, and adds no die")
	var shapes_before: Array = u.dice.map(func(d: Dictionary) -> String: return str(d.shape))
	var hammered: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["HAMMERED"]), {}, rng)
	var grown: Array = range(u.dice.size()).filter(func(i: int) -> bool: return str(u.dice[i].shape) != str(shapes_before[i]))
	check(hammered.ok and grown.size() == 1 and u.dice.size() == 5 and u.bag_dice.is_empty(), "Hammered works one of the five and adds no die: %s" % str(hammered.get("message", "")))
	check(not grown.is_empty() and DeepOddities.SIZES.find(str(u.dice[grown[0]].shape)) == DeepOddities.SIZES.find(str(shapes_before[grown[0]])) + 1, "a size bigger")
	check(not DeepBoons.validate({"name": "x", "group": "kit", "effects": [ {"kind": "die", "key": "D6"}]}, DeepContent.pack()).is_empty(), "no stake hands out a die")
	check(DeepContent.section("boons").keys().all(func(k: Variant) -> bool: return str(DeepContent.boon(str(k)).get("group", "")) in DeepBoons.GROUPS), "no long shots are left in the pack")
	## Terms never pair what they exclude, over many seeds.
	var bad_pairs: int = 0
	var terms_seen: int = 0
	for seed_value in range(40):
		var c: Dictionary = config(200 + seed_value, false)
		c.boons = true
		var s: Dictionary = DeepDescent.new_run(c)
		for pid in ["a", "b"]:
			for o in s.grubstake.offers[pid]:
				if str(o.kind) == "terms":
					terms_seen += 1
					if not DeepBoons._pairs(str(o.boons[0]), str(o.boons[1])):
						bad_pairs += 1
	check(terms_seen == 80 and bad_pairs == 0, "terms respect not_with over %d offers (%d bad)" % [terms_seen, bad_pairs])
	## Soft Rock halves the first fight's creatures and Steady Hands adds a reroll at depth 1.
	var fought: bool = false
	for seed_value in range(79, 110):
		var s: Dictionary = DeepDescent.new_run(config(seed_value, false))
		var offer: Dictionary = {}
		for candidate in s.offers:
			if str(candidate.kind) in ["fight", "elite"] and not bool(candidate.get("hidden", false)):
				offer = candidate
		if offer.is_empty():
			continue
		var staker: Dictionary = DeepDescent.player(s, "a")
		staker.run_mods = {"soft_rock": 3, "extra_rerolls": {"amount": 1, "until_depth": 4}}
		cmd(s, "a", "vote_tunnel", {"offer": offer.id})
		cmd(s, "b", "vote_tunnel", {"offer": offer.id})
		if not DeepDescent.in_battle(s):
			continue
		var b: Dictionary = DeepDescent.battle(s)
		var halved: bool = true
		for foe in b.enemies:
			if int(foe.hp) > int(foe.max_hp) / 2:
				halved = false
		check(halved and int(staker.run_mods.soft_rock) == 2, "Soft Rock opens the fight against cracked creatures and is spent by one")
		## A creature that hands rerolls out adds its own on top of the stake's.
		var gifts: int = b.enemies.filter(func(e: Dictionary) -> bool: return str(e.get("gimmick", "")) == "gift_rerolls").size()
		check(int(DeepBattle.player(b, "a").rerolls) == 3 + gifts, "Steady Hands gives Ardor a third reroll at depth 1 (%d, %d gifted)" % [int(DeepBattle.player(b, "a").rerolls), gifts])
		fought = true
		break
	check(fought, "a fight was found to test the run mods against")

func _test_mines() -> void:
	## The mines in order, each opening the next, and only the last without a bottom.
	var order: Array = DeepContent.mines_in_order()
	check(order[0] == "QUARRY" and order[order.size() - 1] == "RIFT" and order.size() == 7, "seven mines, the Quarry first and the Rift last: %s" % str(order))
	for index in range(order.size() - 1):
		check(str(DeepContent.mine(str(order[index])).get("next", "")) == str(order[index + 1]), "%s opens onto %s" % [order[index], order[index + 1]])
		check(DeepContent.mine_bottom(str(order[index])) > 0 and not DeepContent.is_endless(str(order[index])), "%s has a bottom" % order[index])
	check(DeepContent.is_endless("RIFT") and DeepContent.mine_bottom("RIFT") == 0, "the Rift has none")
	## Every skill outside the opals is found in exactly one mine's batch.
	var homes: Dictionary = {}
	for key in order:
		for skill in DeepContent.mine(str(key)).get("batch", []):
			homes[str(skill)] = int(homes.get(str(skill), 0)) + 1
	for skill in DeepContent.section("skills"):
		if str(DeepContent.skill(str(skill)).get("color", "")) == DeepContent.OPAL:
			continue
		check(int(homes.get(str(skill), 0)) == 1, "%s belongs to exactly one mine's batch (%d)" % [skill, int(homes.get(str(skill), 0))])
	## A mine's pool is its own batch and the batches above it.
	var quarry_pool: Array = DeepForge.skill_pool(DeepContent.mine("QUARRY"))
	var seeps_pool: Array = DeepForge.skill_pool(DeepContent.mine("SEEPS"))
	check(quarry_pool.has("STRIKE") and not quarry_pool.has("APEX") and not quarry_pool.has("JACKPOT"), "the Quarry holds only its own batch")
	check(seeps_pool.has("STRIKE") and seeps_pool.has("APEX") and not seeps_pool.has("BARRAGE"), "the Seeps adds its batch to the Quarry's")
	check(DeepForge.skill_pool(DeepContent.mine("RIFT")).has("JACKPOT"), "the Rift holds every batch")
	## Carat stays inside each mine's band, however much luck is piled on.
	var rng: RandomNumberGenerator = DeepRng.streams(77).stones
	for key in order:
		var mine: Dictionary = DeepContent.mine(str(key))
		var band: Dictionary = DeepForge.carat_band(mine, 1)
		var heaviest: int = 0
		var over_soft: int = 0
		var rolls: int = 3000
		for i in range(rolls):
			var carat: int = DeepForge.roll_carat(rng, DeepForge.luck(mine, 24, 18.0), band)
			heaviest = maxi(heaviest, carat)
			if carat > int(band.soft):
				over_soft += 1
		check(heaviest <= int(band.cap), "%s never gives up a stone over %d carats (heaviest %d)" % [key, int(band.cap), heaviest])
		check(float(over_soft) / float(rolls) < 0.12, "%s rarely gives up one over %d, even on maxed luck (%d in %d)" % [key, int(band.soft), over_soft, rolls])
	var quarry: Dictionary = DeepContent.mine("QUARRY")
	var ordinary_over: int = 0
	for i in range(3000):
		if int(DeepForge.roll_stone(rng, quarry, 14, 0.0).carat) > 5:
			ordinary_over += 1
	check(ordinary_over < 90, "an ordinary find deep in the Quarry is over five carats less than one time in thirty (%d in 3000)" % ordinary_over)
	var rift: Dictionary = DeepContent.mine("RIFT")
	check(int(DeepForge.carat_band(rift, 1).cap) == 17 and int(DeepForge.carat_band(rift, 17).cap) == 19 and int(DeepForge.carat_band(rift, 400).cap) == DeepStone.carat_max(),
		"the Rift's cap climbs a carat a Warden, to the most a stone can weigh")
	## Deeper mines breed tougher creatures; the Rift keeps compounding.
	var tick_quarry: Dictionary = DeepCreatures.make("CAVE_TICK", "t", 5, 1, DeepDescent.creature_scale(quarry, 5))
	var tick_seeps: Dictionary = DeepCreatures.make("CAVE_TICK", "t", 5, 1, DeepDescent.creature_scale(DeepContent.mine("SEEPS"), 5))
	check(int(tick_seeps.max_hp) >= int(tick_quarry.max_hp) * 17 / 10 and float(tick_seeps.damage_mult) > 1.0, "a Seeps tick is far tougher than a Quarry one (%d vs %d)" % [int(tick_seeps.max_hp), int(tick_quarry.max_hp)])
	check(float(DeepDescent.creature_scale(rift, 17).hp) > float(DeepDescent.creature_scale(rift, 9).hp) * 1.9, "the Rift doubles its creatures' health every eight floors")
	## A run started in a deeper mine comes down with the sockets each lapidary has opened
	## filled from the vault, a temporary stone in every one still shut, and a purse.
	var cfg: Dictionary = config(31, true)
	for entry in cfg.players:
		entry.rail = entry.rail + [stone("STRIKE", 3, 4, 3, "%s_fourth" % entry.id), stone("TEMPO", 3, 4, 3, "%s_fifth" % entry.id)]
	var quarry_run: Dictionary = DeepDescent.new_run(cfg.duplicate(true))
	check(quarry_run.players[0].rail[3] == null and int(quarry_run.players[0].ore) == 0 and quarry_run.players[0].temps.is_empty(), "a Quarry run fills three sockets, lends nothing and starts with no pyrite")
	var bought: Dictionary = cfg.duplicate(true)
	bought.players[0].sockets = 4
	var opened: Dictionary = DeepDescent.new_run(bought)
	check(str(opened.players[0].rail[3].get("id", "")) == "a_fourth" and opened.players[0].rail[4] == null and opened.players[1].rail[3] == null, "a socket bought fills from the vault, in the Quarry too, for whoever bought it")
	cfg.mine = "SEEPS"
	var seeps_run: Dictionary = DeepDescent.new_run(cfg)
	var lent: Variant = seeps_run.players[0].rail[3]
	check(lent is Dictionary and str(lent.id) != "a_fourth" and bool(lent.get("temporary", false)) and DeepStone.is_fragile(lent) and bool(lent.get("appraised", false)),
		"a Seeps run lends a temporary stone for each shut socket, not the vault's")
	check(int(seeps_run.players[0].ore) == int(DeepContent.mine("SEEPS").start_pyrite), "and starts with a purse")
	check(int(seeps_run.schedule.boss) == DeepContent.mine_bottom("SEEPS") and seeps_run.schedule.wardens.size() == 3, "the Seeps plans its own shaft: %s" % str(seeps_run.schedule))
	## The boss's hall has a cage, and a way on into the next mine.
	var bottom: int = DeepContent.mine_bottom("QUARRY")
	var hall: Dictionary = DeepDescent.new_run(config(32, true))
	hall.phase = "landing"
	hall.depth = bottom
	hall.records.deepest = bottom
	hall.records.wardens = hall.schedule.wardens.duplicate()
	hall.records.boss = true
	hall.landing = {"depth": bottom, "warden_next": true, "cleared": true, "respites": {}}
	check(DeepDescent.in_boss_hall(hall) and DeepDescent.is_conquered(hall), "the party stands in the boss's hall, the mine conquered")
	var ride: Dictionary = hall.duplicate(true)
	ride.players[0].ore = DeepDescent.lift_cost(ride)
	cmd(ride, "a", "choose", {"choice": "lift"})
	cmd(ride, "b", "choose", {"choice": "lift"})
	check(ride.phase == "over" and ride.outcome == "conquered", "the boss's hall has a cage, and riding it up conquers the mine")
	var on: Dictionary = hall.duplicate(true)
	on.players[0].ore = 40
	on.players[0].hp = 7
	on.players[0].haul.append(stone("APEX", 2, 2, 3, "carried_apex"))
	check(cmd(on, "a", "choose", {"choice": "descend"}).ok, "pushing on is a choice at the boss's hall")
	var pushed: Dictionary = cmd(on, "b", "choose", {"choice": "descend"})
	check(pushed.ok and str(pushed.event.get("next_mine", "")) == "QUARRY" and on.mine == "SEEPS" and on.depth == 0 and on.phase == "tunnels" and not on.offers.is_empty(),
		"both pushing on carries the party into the top of the Seeps")
	check(int(on.carried) == bottom and int(on.heat) == int(DeepContent.constant("chain_heat", 2)) and on.mines_done.size() == 1 and bool(on.mines_done[0].boss), "the mine above is carried in the record")
	check(int(on.players[0].ore) == 40 and int(on.players[0].hp) == 7 and on.players[0].haul.size() == 1, "and everything carried comes along: the purse, the wounds, the haul")
	check(int(on.schedule.boss) == DeepContent.mine_bottom("SEEPS") and on.records.wardens.is_empty() and not bool(on.records.boss), "the Seeps keeps its own records")
	on.depth = 2
	check(DeepDescent.lift_cost(on) == int(DeepContent.constant("lift_ore_per_depth", 15)) * (bottom + 2) * 2, "the winch charges for every floor down from the workshop")
	var summary: Dictionary = DeepDescent.results(on)
	check(summary.mines.size() == 2 and summary.mines[0].mine == "QUARRY" and summary.mines[1].mine == "SEEPS" and summary.from_mine == "QUARRY", "the results write a record for each mine")
	## A fight in the pushed-on Seeps is bred for its heat.
	var streams: Dictionary = DeepDescent.streams_of(on)
	on.phase = "chamber"
	on.depth = 3
	on.chamber = {"kind": "fight", "depth": 3, "settled": false}
	DeepDescent._start_fight(on, streams, false, "")
	check(int(on.chamber.battle.threat) == 3 + int(on.heat) and int(on.chamber.battle.depth) == 3, "its creatures are bred for depth %d" % int(on.chamber.battle.threat))
	## The Rift's Wardens take their turns, and there is no bottom to it.
	var deep: Dictionary = DeepDescent.new_run(config(33, true))
	deep.mine = "RIFT"
	deep.schedule = DeepDescent.plan_shaft(DeepRng.streams(33).tunnels, rift)
	check(DeepDescent.run_is_warden(deep, 8) and DeepDescent.run_is_warden(deep, 48) and not DeepDescent.run_is_boss(deep, 48), "a Warden every eighth floor of the Rift, none of them the last")
	check(DeepDescent.warden_key(deep, 8) == "THE_DRILL" and DeepDescent.warden_key(deep, 16) == "THE_UNDERTOW" and DeepDescent.warden_key(deep, 24) == "THE_PRISMARCH"
		and DeepDescent.warden_key(deep, 32) == "THE_HEARTROT" and DeepDescent.warden_key(deep, 48) == "THE_KILN_WYRM" and DeepDescent.warden_key(deep, 56) == "THE_DRILL", "the Rift remembers the bosses above it, in order")
	check(DeepDescent.warden_key(deep, 40) == "THE_UNMADE" and DeepDescent.warden_key(deep, 80) == "THE_UNMADE" and DeepDescent.warden_key(deep, 88) == "THE_HEARTROT", "and every fifth Rift Warden is the Unmade")
