extends SceneTree
## The run: tunnels, chambers, landings, wardens, salvage, and what comes home.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_open_and_tunnels()
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
		out.append(DeepDice.make(str(keys[index]), DeepContent.die(str(keys[index])), "%s%d" % [prefix, index]))
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
		var expected: Dictionary = DeepForge.roll_stone(expected_rng, DeepDescent.mine_of(state), 5, 3 + mini(stacks, 100), found.provenance, str(found.id))
		check(JSON.stringify(found) == JSON.stringify(expected), "%d stored Sparkle grants the full capped luck bonus on the next find" % stacks)
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
	check(DeepDescent.is_landing(4) and DeepDescent.is_landing(8) and not DeepDescent.is_landing(5), "landings every four depths")
	check(DeepDescent.is_warden_depth(8) and DeepDescent.is_warden_depth(24) and DeepDescent.is_warden_depth(32) and not DeepDescent.is_warden_depth(12), "wardens at 8, 16, 24 and every 8 below")
	## The written depths are only roughly where the Wardens stand: this run's own schedule
	## says which landing each of them guards.
	var guards: Array = state.schedule.wardens
	check(guards.size() == 3 and int(guards[2]) == int(DeepContent.constant("run_depth", 24)), "three Wardens, the last on the bottom floor: %s" % str(guards))
	check(guards.all(func(d: int) -> bool: return state.schedule.landings.has(d)), "and every one of them guards a landing")
	check(DeepDescent.warden_key(state, int(guards[0])) == "THE_FOREMAN" and DeepDescent.warden_key(state, 40) == "THE_DRILL", "warden keys by which landing they guard")

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
	## Lighting the way costs ore; it shows every chamber, dark mouths too.
	var lit: Dictionary = DeepDescent.new_run(config(11, true))
	var a: Dictionary = DeepDescent.player(lit, "a")
	a.ore = 3
	check(not cmd(lit, "a", "light").ok, "three pyrite is not enough to light the way")
	a.ore = 25
	check(cmd(lit, "a", "light").ok and int(a.ore) == 25 - DeepDescent.lantern_cost() and bool(lit.map.lit), "lighting the way is paid in pyrite")
	DeepDescent.player(lit, "b").ore = 25
	check(not cmd(lit, "b", "light").ok, "and needs doing only once a stretch")
	for id in lit.map.nodes:
		check(DeepDescent.revealed(lit, lit.map.nodes[id]), "a lit stretch shows %s" % id)
	## A landing charts the stretch below before anyone chooses to descend.
	var deeper: Dictionary = DeepDescent.new_run(config(101, true))
	var guard: int = 0
	while int(deeper.depth) < 4 and guard < 60 and str(deeper.phase) != "over":
		guard += 1
		_advance_once(deeper)
	if str(deeper.phase) == "landing":
		check(int(deeper.map.from) == 4 and int(deeper.map.to) == 8 and bool(deeper.map.nodes.landing.warden), "the landing charts the way to the warden at 8")
		check(not bool(deeper.map.lit), "a new stretch starts unlit")

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
	check(not cmd(state, "a", "choose", {"choice": "descend"}).ok, "the way down waits on the respite")
	check(cmd(state, "a", "choose", {"choice": "lift"}).ok and str(a.choice) == "lift", "but the cage does not: it is a fourth thing to walk up to")
	a.choice = ""
	check(not cmd(state, "a", "respite", {"choice": "nap"}).ok, "rest, appraise or the wheel, nothing else")
	check(not cmd(state, "a", "respite", {"choice": "appraise", "stone_id": "a_strike"}).ok, "the landing's appraisal is for a raw stone")
	check(cmd(state, "a", "respite", {"choice": "appraise", "stone_id": "raw1"}).ok and bool(raw.appraised) and str(a.respite) == "appraise", "the landing appraises one raw stone free")
	check(not cmd(state, "a", "respite", {"choice": "rest"}).ok, "one respite a landing")
	check(str(state.landing.respites.a.choice) == "appraise", "the landing remembers what each player did")
	check(not cmd(state, "b", "respite", {"choice": "polish", "stone_id": "nothing"}).ok, "the wheel needs a stone you carry")
	var rough: Dictionary = stone("GUARD", 3, 2, 3, "b_rough")
	rough.appraised = true
	b.haul.append(rough)
	## The wheel does not make a cut truer: it draws a new one, which may be worse.
	check(cmd(state, "b", "respite", {"choice": "polish", "stone_id": "b_rough"}).ok and int(rough.cut) >= 0 and int(rough.cut) <= 4, "the wheel cuts a stone again")
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
	a.bag_dice.append(DeepDice.make("D8", DeepContent.die("D8"), "spare"))
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
	check(state.phase == "chamber" and str(state.chamber.kind) == "merchant" and state.chamber.stock.size() == 3, "a merchant lays out three stones")
	check(state.chamber.stock.all(func(i: Dictionary) -> bool: return str(i.kind) == "stone"), "and no dice: dice are never for sale")
	check(state.chamber.stock.filter(func(i: Dictionary) -> bool: return str(i.kind) == "loupe").is_empty(), "and no loupes")
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
	check(DeepDescent.appraise_cost(state, "a") == 12, "the first appraisal at a stall costs twelve")
	check(cmd(state, "a", "appraise", {"stone_id": "raw0"}).ok and bool(raws[0].appraised) and int(a.ore) == 188, "the lens appraises a raw stone for pyrite")
	check(DeepDescent.appraise_cost(state, "a") == 20 and DeepDescent.appraise_cost(state, "b") == 12, "each appraisal costs the asker more, and nobody else")
	check(cmd(state, "a", "appraise", {"stone_id": "raw1"}).ok and int(a.ore) == 168, "the second costs twenty")
	check(not cmd(state, "a", "appraise", {"stone_id": "raw1"}).ok, "not twice")
	var ore_before: int = int(a.ore)
	check(cmd(state, "a", "sell", {"stone_id": "raw1"}).ok and int(a.ore) > ore_before, "an appraised stone sells for pyrite")
	var item: Dictionary = state.chamber.stock[2]
	a.ore = 0
	check(not cmd(state, "a", "buy", {"item_id": item.id}).ok, "no pyrite, no stone")
	a.ore = int(item.price) + 10
	var haul_before: int = a.haul.size()
	check(cmd(state, "a", "buy", {"item_id": item.id}).ok and a.haul.size() == haul_before + 1 and int(a.ore) == 10 and str(item.sold) == "a", "a stone goes to the haul for its price and is marked sold")
	check(a.bag_dice.is_empty(), "and nothing goes to the bag of dice")
	check(not cmd(state, "b", "buy", {"item_id": item.id}).ok, "the other player cannot buy it again")
	check(cmd(state, "a", "swap_die", {"index": 0, "die_id": str(a.dice[1].id)}).ok, "the bench is open at the stall too")
	var unsold: String = str(state.chamber.stock[0].id)
	check(cmd(state, "a", "leave").ok and str(state.phase) == "chamber", "one player leaving waits for the other")
	check(not cmd(state, "a", "leave").ok, "leaving twice is refused")
	check(cmd(state, "b", "leave").ok and str(state.phase) == "tunnels", "when everyone has left, the tunnels open")
	check(DeepDescent.appraise_cost(state, "a") == 12, "the next stall starts its price again")
	check(not cmd(state, "a", "buy", {"item_id": unsold}).ok, "the stall is gone once the party walks on")

func _test_dice_rooms() -> void:
	## A smithy and a carver: one fixed card each, one piece of work a player, and never a die
	## that comes or goes.
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
		if kind == "smithy":
			check(cmd(state, "a", "oddity", {"choice": "hammer", "payload": {"die_id": str(die.id)}}).ok, "the smithy hammers a die")
			check(DeepOddities.SIZES.find(str(a.dice[0].shape)) == DeepOddities.SIZES.find(shape) + 1, "a size bigger (%s to %s)" % [shape, str(a.dice[0].shape)])
		else:
			var low: int = int(a.dice[0].faces[0].value)
			check(cmd(state, "a", "oddity", {"choice": "raise", "payload": {"die_id": str(die.id), "face": 0}}).ok and int(a.dice[0].faces[0].value) == low + 1, "the carver raises a face")
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
	## A strong party digs past the first warden, takes the hoard and rides the lift.
	var state: Dictionary = DeepDescent.new_run(config(202, true))
	var guard: int = 0
	var saw_warden: bool = false
	var saw_hoard: bool = false
	var bench_checked: bool = false
	var mirror: Dictionary = state.duplicate(true)
	while str(state.phase) != "over" and guard < 600:
		guard += 1
		var before: Dictionary = state.duplicate(true)
		if str(state.phase) == "landing" and state.depth == 8 and bool(state.landing.get("cleared", false)):
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
	check(state.outcome == "extracted" and state.depth == 8 and state.records.wardens == [8], "extracted from the warden's landing: %s depth %d wardens %s" % [str(state.outcome), int(state.depth), str(state.records.wardens)])
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
				## after it, so a party that has had enough may leave at once.
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
	## The Warden's pile: three stones read out where they lie, the last of them an opal,
	## a gem nothing else in the mine offers, shown for what it is like the two beside it.
	var state: Dictionary = DeepDescent.new_run(config(414, true))
	state.depth = 8
	DeepDescent._offer_hoard(state)
	var offers: Array = state.hoard.a.offers
	check(offers.size() == 3 and offers.all(func(s: Dictionary) -> bool: return bool(s.appraised) and bool(s.inclusions_revealed)), "all three are read out where they lie")
	var opal: Dictionary = offers[2]
	check(DeepStone.is_opal(opal), "the third is an opal: %s" % str(opal.skill))
	check(DeepStone.fits(opal, "RED") and DeepStone.fits(opal, "GOLD"), "an opal answers to every color, so any socket takes it")
	var picked: Dictionary = cmd(state, "a", "pick_hoard", {"stone_id": str(opal.id)})
	check(picked.ok and not bool(picked.event.raw) and bool(picked.event.stone.appraised),
		"the opal comes off the pile appraised")
	check(DeepDescent.player(state, "a").haul.any(func(s: Dictionary) -> bool: return str(s.id) == str(opal.id) and bool(s.get("appraised", false))),
		"and goes into the haul that way")
	check(DeepDescent.player(state, "a").haul.any(func(s: Dictionary) -> bool: return DeepStone.is_opal(s)), "and the opal goes in the haul")
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
	check(loadout.dice.map(func(d: Dictionary) -> String: return str(d.key)) == ardor_dice, "and the dice are Ardor's own: %s" % str(loadout.dice.map(func(d: Dictionary) -> String: return str(d.key))))
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
	check(DeepProfile.loadout_socket(2) and not DeepProfile.loadout_socket(3), "the third socket is the loadout's last")
	check(DeepProfile.set_rail(profile, "ARDOR", 3, "CLEAVE") != "" and DeepProfile.set_rail(profile, "ARDOR", 4, "CLEAVE") != "", "a stone is refused in a socket only the mine fills")
	check(DeepProfile.set_rail(profile, "ARDOR", 0, "CLEAVE") == "" and profile.characters.ARDOR.rail[0] == "CLEAVE", "a stone set over another replaces it")
	check(DeepProfile.set_rail(profile, "ARDOR", 0, "STRIKE") == "", "and Strike goes back")
	## An old save that set a stone past the third socket: it moves to an empty one it fits.
	profile.characters.ARDOR.rail = [null, "GUARD", "MEND", "STRIKE", null]
	check(DeepProfile.tidy(profile) and profile.characters.ARDOR.rail == ["STRIKE", "GUARD", "MEND", null, null], "a stone in a mine socket moves into the loadout: %s" % str(profile.characters.ARDOR.rail))
	check(not DeepProfile.tidy(profile), "and a tidy rail is left as it is")
	var result: Dictionary = {"run_id": "r1", "mine": "QUARRY", "outcome": "extracted", "depth": 8, "deepest": 8, "wardens": [8],
		"players": {"a": {"haul": [DeepStone.make("VENOM", 4, 2, 2, ["SILK"], {}, "v1"), DeepStone.make("STRIKE", 1, 0, 3, [], {}, "s1")], "dice": [DeepDice.make("D20", DeepContent.die("D20"), "d20x")], "stats": {}, "rail": []}}}
	var applied: Dictionary = DeepProfile.apply_result(profile, result, "a")
	check(profile.tray.size() == 2 and profile.bowl.size() == 11, "two stones wait in the tray; a die joins the bowl alongside a newly unlocked character's five dice (%d)" % profile.bowl.size())
	check(profile.mines.QUARRY.deepest == 8 and profile.mines.QUARRY.wardens == [8] and profile.records.runs == 1 and profile.records.extractions == 1, "records are written")
	check(applied.unlocked.size() == 1 and applied.unlocked[0].get("character", "") == "VESPER" and profile.characters.VESPER.unlocked, "the first warden unlocks Vesper: %s" % str(applied.unlocked))
	## Vesper's two Red sockets: a stone moves between them, and swaps with one already there.
	check(DeepProfile.set_rail(profile, "VESPER", 0, "STRIKE") == "" and DeepProfile.set_rail(profile, "VESPER", 1, "STRIKE") == "" and profile.characters.VESPER.rail.slice(0, 2) == [null, "STRIKE"], "moving a stone empties its old socket")
	check(DeepProfile.set_rail(profile, "VESPER", 0, "CLEAVE") == "" and DeepProfile.set_rail(profile, "VESPER", 0, "STRIKE") == "" and profile.characters.VESPER.rail.slice(0, 2) == ["STRIKE", "CLEAVE"], "a stone moved onto another swaps them: %s" % str(profile.characters.VESPER.rail))
	## Dice are never swapped: whatever an old save put in a slot, the loadout rolls their own.
	profile.characters.VESPER.dice[0] = "d20x"
	check(DeepProfile.loadout(profile, "VESPER").dice.map(func(d: Dictionary) -> String: return str(d.key)) == DeepContent.character("VESPER").get("dice", []), "a lapidary always goes down with their own dice")
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
	## Recut draws a stone's Cut again rather than lifting it: nothing may make a stone truer
	## on purpose, so all the boon promises is a fresh roll somewhere on the ladder.
	var recut: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["RECUT"], ["socket"]), {"socket": 4}, rng)
	var at: int = int(recut.get("socket", -1))
	check(recut.ok and at >= 0 and u.rail[at] is Dictionary and int(u.rail[at].cut) >= 0 and int(u.rail[at].cut) <= 4 and int(recut.changed[0].cut) == int(u.rail[at].cut),
		"Recut cuts a stone drawn from the rail again (socket %d)" % at)
	var sockets_hit: Dictionary = {}
	for _i in range(24):
		var carats: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["HEAVIER"], ["socket"]), {}, rng)
		sockets_hit[int(carats.socket)] = true
	check(sockets_hit.size() > 1 and sockets_hit.keys().all(func(k: int) -> bool: return u.rail[k] is Dictionary), "the socket is drawn at random, from set stones only: %s" % str(sockets_hit.keys()))
	var carats_before: Array = u.rail.map(func(s: Variant) -> int: return int(s.carat) if s is Dictionary else 0)
	var fired: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["HEAVIER"], ["socket"]), {}, rng)
	var fired_at: int = int(fired.socket)
	var heart: Dictionary = u.rail[fired_at]
	check(fired.ok and int(heart.carat) == int(carats_before[fired_at]) and heart.inclusions.size() == DeepStone.inclusion_slots(int(heart.clarity)),
		"Clarified draws a stone's Clarity again and refills what is frozen inside it, and never touches its weight (%d carats)" % int(heart.carat))
	var pinpoint: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["PINPOINT"], ["socket"]), {}, rng)
	var pinned: Dictionary = u.rail[int(pinpoint.socket)]
	check(pinpoint.ok and pinned.inclusions.any(func(k: String) -> bool: return str(DeepContent.inclusion(k).get("class", "")) == "PINPOINT"), "a Pinpoint forms in the stone")
	var bare: Dictionary = u.duplicate(true)
	bare.rail = [null, null, null, null, null]
	check(not DeepBoons.apply(quiet, bare, offer_of.call(["RECUT"], ["socket"]), {}, rng).ok, "an empty rail is refused")
	var haul_before: int = u.haul.size()
	var raw: Dictionary = DeepBoons.apply(quiet, u, offer_of.call(["RAW_STONE"]), {}, rng)
	check(raw.ok and u.haul.size() == haul_before + 1 and not bool(u.haul[u.haul.size() - 1].appraised), "a raw stone joins the haul")
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
