extends SceneTree
## Bosses that rise and the named traits (owner, November 18, 2026; docs/BESTIARY.md): a mine's
## final boss has more than one bar, falls to 1 health when one runs out and gets back up at
## its next action; the Rift rolls its remembered Wardens a named trait and three bars; and
## Venomous, Molten, Wrathful and Leeching do what their cards say.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	content()
	bars_and_the_fall()
	the_rise()
	a_tick_fells_it()
	it_dies_on_its_last_bar()
	the_undertow_dives()
	the_hollow_crown()
	the_infinite_void()
	riders()
	wrathful()
	leeching()
	the_rift_remembers()
	the_rift_wardens()
	champions()
	the_bestiary()
	down_a_run()
	print("Phases: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

# --- fixtures ----------------------------------------------------------------------------

func stone(skill: String, id: String) -> Dictionary:
	return DeepStone.make(skill, 1, 4, 3, [], {}, id)

func setup(keys: Array, context: Dictionary = {}, players: int = 1, seed_value: int = 271) -> Dictionary:
	var party: Array = []
	for i in range(players):
		var bowl: Array = []
		for j in range(5):
			bowl.append(DeepDice.make("D6", "p%d_d%d" % [i, j]))
		var unit: Dictionary = DeepBattle.make_player("p%d" % i, "Player %d" % i, "ARDOR", [stone("STRIKE", "p%d_s0" % i)], bowl)
		unit.birthstone = {}
		unit.passive = {}
		unit.hp = 100000
		unit.max_hp = 100000
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(seed_value, ["dice", "creatures"])
	var ctx: Dictionary = {"depth": 1}
	ctx.merge(context, true)
	var state: Dictionary = DeepBattle.begin(party, keys, ctx, rng.dice, rng.creatures)
	var leads: Array = state.enemies.filter(func(e: Dictionary) -> bool: return str(e.get("escort_of", "")).is_empty())
	return {"state": state, "rng": rng, "foe": leads[0] if not leads.is_empty() else state.enemies[0], "unit": state.players[0]}

func turn(f: Dictionary) -> Array:
	var out: Array = []
	DeepBattle.force_lock(f.state)
	out.append(DeepBattle.start_resolution(f.state))
	while DeepBattle.has_steps(f.state) and out.size() < 600:
		var event: Dictionary = DeepBattle.step(f.state, f.rng.dice, f.rng.creatures)
		if not event.is_empty():
			out.append(event)
	return out

func of_kind(events: Array, kind: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == kind)

func hit(f: Dictionary, amount: int) -> Dictionary:
	return DeepBattle._damage(f.state, f.unit, f.foe, amount, f.rng.dice)

func force(foe: Dictionary, at_die: int, move_name: String) -> void:
	## One die of the creature lands on this move every time: it is given a single face.
	var move: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), move_name)
	var die: Dictionary = DeepDice.make("D6", "%s_d%d" % [str(foe.id), at_die], {"faces": [DeepDice.face(1)]})
	DeepCreatures.dress_face(die.faces[0], move)
	while foe.dice.size() <= at_die:
		foe.dice.append(die.duplicate(true))
	foe.dice[at_die] = die

func only_die(foe: Dictionary, move_name: String) -> void:
	foe.dice = []
	force(foe, 0, move_name)

# --- content -----------------------------------------------------------------------------

func content() -> void:
	check(DeepContent.validate().is_empty(), "the pack is valid: %s" % str(DeepContent.validate().slice(0, 3)))
	var bars: Dictionary = {"QUARRY": 2, "SEEPS": 2, "GLASS_VEINS": 2, "WARRENS": 2, "FURNACE": 2, "GEODE": 3}
	for mine_key in bars:
		var mine: Dictionary = DeepContent.mine(mine_key)
		var boss: Dictionary = DeepContent.creature(str(mine.boss))
		check(boss.get("rising", {}).get("rises", []).size() == int(bars[mine_key]) - 1, "%s has %d bars" % [str(mine.boss), int(bars[mine_key])])
		for warden in mine.wardens:
			check(not DeepContent.creature(str(warden)).has("rising"), "%s, a Warden, has one bar" % str(warden))
	check(DeepContent.creature("THE_UNMADE").rising.rises.size() == 2, "the Infinite Void has three bars")
	check(int(DeepContent.creature("THE_DRILL").rising.health_pct) == 60 and int(DeepContent.creature("THE_HOLLOW_CROWN").rising.health_pct) == 50, "two bars of 60%, three of 50%")
	var hosts: Dictionary = {"THE_FOREMAN": "wrathful", "THE_GLAZIER": "jagged", "THE_GARDENER": "venomous", "THE_SMELTER": "molten", "THE_SPORE_MOTHER": "split_on_big_hit"}
	for key in hosts:
		check(DeepContent.creature(key).get("traits", {}).has(hosts[key]), "%s is %s" % [key, str(hosts[key])])
	check(DeepContent.REMEMBERED_TRAITS == ["steadfast", "sturdy", "split_on_big_hit", "jagged", "venomous", "molten", "wrathful", "leeching"], "the named traits are eight")
	for key in DeepContent.REMEMBERED_TRAITS:
		check(DeepContent.REMEMBERED_NAMES.has(key) and DeepContent.REMEMBERED_VALUES.has(key) and DeepContent.TRAITS.has(key), "%s has a name and a worth" % str(key))

# --- the fall ----------------------------------------------------------------------------

func bars_and_the_fall() -> void:
	var f: Dictionary = setup(["THE_DRILL"], {"warden": true})
	var foe: Dictionary = f.foe
	check(int(foe.bars) == 2 and int(foe.bar) == 1 and foe.rises.size() == 1 and int(foe.max_hp) == 120, "the Drill has two bars of 60%% of its 200 health: %d" % int(foe.max_hp))
	check(not bool(foe.get("bars_shown", false)), "a boss nobody has watched get up shows one bar")
	foe.block = 0
	foe.statuses.erase("ward")
	var blow: Dictionary = hit(f, 99999)
	check(int(foe.hp) == 1 and bool(foe.fallen) and bool(blow.get("fell", false)) and not blow.has("killed"), "its health runs out: it stays on 1, and no kill is counted")
	check(int(f.state.get("turn_kills", 0)) == 0 and not DeepBattle.done(f.state) and not bool(f.state.get("cleared", false)), "the fight goes on")
	var more: Dictionary = hit(f, 99999)
	check(int(foe.hp) == 1 and int(more.get("hp_loss", -1)) == 0 and bool(more.get("standing", false)), "nothing takes its last point until it gets up")
	DeepBattle._apply_one(f.state, f.unit, foe, "poison", 9, {}, f.rng.dice)
	check(int(foe.statuses.get("poison", 0)) == 9, "afflictions still land on it")
	var lost: Dictionary = DeepBattle._damage(f.state, f.unit, foe, 50, f.rng.dice, true, {}, false, true, true)
	check(int(foe.hp) == 1 and bool(lost.get("standing", false)), "health lost outright does not take it either")
	## A creature with one bar dies as it always did.
	var w: Dictionary = setup(["THE_FOREMAN"], {"warden": true})
	w.foe.block = 0
	var dead: Dictionary = hit(w, 99999)
	check(int(w.foe.hp) == 0 and bool(dead.get("killed", false)) and int(w.foe.bars) == 1, "a Warden with one bar dies the first time")
	## Splits: the half that splits off has no bars of its own.
	var s: Dictionary = setup(["THE_DRILL"], {"warden": true, "remembered": true, "extra_trait": "split_on_big_hit", "bars": 3})
	s.foe.block = 0
	var half: Dictionary = hit(s, int(s.foe.max_hp) / 2)
	var twin: Dictionary = DeepBattle.enemy(s.state, str(half.get("split", "")))
	check(not twin.is_empty() and int(twin.bars) == 1 and twin.rises.is_empty() and int(s.foe.bars) == 3 and s.foe.rises.size() == 2, "a Remembered boss that splits keeps its bars; its twin has none")

func the_rise() -> void:
	var f: Dictionary = setup(["THE_DRILL"], {"warden": true})
	var foe: Dictionary = f.foe
	foe.block = 0
	foe.statuses.erase("ward")
	foe.statuses.strength = 2
	hit(f, 99999)
	DeepBattle._apply_one(f.state, f.unit, foe, "poison", 9, {}, f.rng.dice)
	DeepBattle._apply_one(f.state, f.unit, foe, "stun", 2, {}, f.rng.dice)
	f.unit.rail = []
	var events: Array = turn(f)
	var rises: Array = of_kind(events, "enemy_rise")
	check(rises.size() == 1 and str(rises[0].unit) == str(foe.id) and int(rises[0].bar) == 2 and str(rises[0].name) == "Redline" and bool(rises[0].acts), "it gets back up as its action opens: %s" % str(rises.size()))
	check(rises.size() == 1 and rises[0].shed.has("poison") and rises[0].shed.has("stun") and rises[0].traits == ["molten"], "shedding what was on it and taking Molten")
	check(int(foe.max_hp) == 120 and not bool(foe.fallen) and int(foe.bar) == 2 and foe.rises.is_empty() and str(foe.bar_name) == "Redline", "on its second bar")
	check(int(foe.statuses.get("poison", 0)) == 0 and int(foe.statuses.get("stun", 0)) == 0 and int(foe.statuses.get("strength", 0)) == 2, "afflictions gone, its Strength kept")
	check(DeepCreatures.trait_value(foe, "molten", 0) == 25 and bool(foe.get("bars_shown", false)), "Molten for the rest of the fight, and its bars are shown now")
	var rats: Array = f.state.enemies.filter(func(e: Dictionary) -> bool: return str(e.key) == "RAIL_RAT")
	check(rats.size() == 2, "two Rail Rats join as it rises: %d" % rats.size())
	var at: int = events.find(rises[0]) if not rises.is_empty() else -1
	var rolled: Array = events.slice(at).filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "enemy_roll" and str(e.get("unit", "")) == str(foe.id))
	check(not rolled.is_empty(), "and then it takes its action")
	check(f.state.get("rose", []).has("THE_DRILL"), "the fight notes that it rose")
	## The bar it got up with: full, with the block it walked in behind.
	check(int(rises[0].hp_after) == 120 and int(rises[0].block_after) == int(DeepContent.creature("THE_DRILL").block), "a full bar and its opening block: %d" % int(rises[0].block_after))
	## Its Bore lays Burn now, and says so.
	var bore: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), "Bore")
	check(bore.effects.size() == 2 and str(bore.effects[1].kind) == "burn" and int(bore.effects[1].amount) == 2 and DeepCreatures.move_text(foe, bore).contains("2 Burn"), "Bore 5 lays 2 Burn: %s" % DeepCreatures.move_text(foe, bore))
	var over: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), "Overdrive")
	check(int(over.effects[1].amount) == 5, "Overdrive 30 lays 5, the most a face lays")

func a_tick_fells_it() -> void:
	var f: Dictionary = setup(["THE_DRILL"], {"warden": true})
	var foe: Dictionary = f.foe
	foe.block = 0
	foe.statuses.erase("ward")
	foe.hp = 3
	foe.statuses.poison = 10
	f.unit.rail = []
	var events: Array = turn(f)
	var ticks: Array = of_kind(events, "tick")
	var fell: bool = ticks.any(func(e: Dictionary) -> bool: return e.ticks.any(func(t: Dictionary) -> bool: return bool(t.get("fell", false))))
	var rises: Array = of_kind(events, "enemy_rise")
	check(fell and rises.size() == 1 and not bool(rises[0].acts), "Poison takes its last health at the end of the turn: it falls, and gets up before the next")
	check(int(foe.hp) == int(foe.max_hp) and int(foe.bar) == 2 and not bool(foe.fallen) and str(f.state.phase) == "planning", "the next turn opens on a full second bar")
	check(events.find(rises[0]) > events.find(ticks[0]), "after the tick")

func it_dies_on_its_last_bar() -> void:
	var f: Dictionary = setup(["THE_DRILL"], {"warden": true})
	var foe: Dictionary = f.foe
	foe.block = 0
	foe.statuses.erase("ward")
	hit(f, 99999)
	f.unit.rail = []
	turn(f)
	foe.block = 0
	var last: Dictionary = hit(f, 99999)
	check(int(foe.hp) == 0 and bool(last.get("killed", false)) and int(f.state.get("turn_kills", 0)) == 1, "its second bar is its last: it dies, and that is the kill")
	check(DeepBattle.done(f.state) and str(f.state.outcome) == "victory", "and the fight is won (its rats run)")

func the_undertow_dives() -> void:
	var f: Dictionary = setup(["THE_UNDERTOW"], {"warden": true})
	var foe: Dictionary = f.foe
	foe.block = 0
	foe.statuses.erase("ward")
	hit(f, 99999)
	check(bool(foe.fallen) and bool(foe.burrowed), "the Undertow goes under as it falls")
	f.unit.rail = []
	var events: Array = turn(f)
	var surfaced: Array = events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "enemy_move" and str(e.get("move", "")) == "Surface")
	check(of_kind(events, "enemy_rise").size() == 1 and not surfaced.is_empty() and not bool(foe.burrowed), "and comes up biting as it rises")
	check(DeepCreatures.trait_value(foe, "wrathful", 0) == 1 and str(foe.bar_name) == "Riptide", "Wrathful on its second bar")

func the_hollow_crown() -> void:
	var f: Dictionary = setup(["THE_HOLLOW_CROWN"], {"warden": true})
	var foe: Dictionary = f.foe
	check(int(foe.bars) == 3 and int(foe.max_hp) == 170 and DeepCreatures.trait_value(foe, "sturdy", 0) == 25, "three bars of half its 340 health, Sturdy at a quarter")
	foe.block = 0
	foe.statuses.erase("ward")
	foe.traits.sturdy = 0
	f.unit.rail = []
	hit(f, 99999)
	var first: Array = of_kind(turn(f), "enemy_rise")
	check(first.size() == 1 and str(first[0].name) == "Risen" and str(foe.dice[0].shape) == "D12" and foe.dice[0].faces.size() == 12, "Risen: its die is a d12 at once: %s" % str(foe.dice[0].shape))
	var faces: Array = foe.dice[0].faces.map(func(face: Dictionary) -> String: return str(face.get("move", "")))
	check(faces.count("Topple") == 3 and faces.count("Summon") == 3 and DeepCreatures.trait_value(foe, "jagged", 0) == 1, "with three Topple and three Summon faces, and Jagged")
	foe.block = 0
	hit(f, 99999)
	check(bool(foe.fallen) and int(foe.bar) == 2, "it falls a second time")
	var second: Array = of_kind(turn(f), "enemy_rise")
	check(second.size() == 1 and str(second[0].name) == "Last Reign" and foe.dice.size() == 2 and foe.dice[1].faces.size() == foe.dice[0].faces.size(), "Last Reign: a second die, a copy of the first")
	check(DeepCreatures.trait_value(foe, "wrathful", 0) == 1 and int(foe.bar) == 3 and foe.rises.is_empty(), "Wrathful on its last bar")
	foe.block = 0
	var last: Dictionary = hit(f, 99999)
	check(bool(last.get("killed", false)), "and the third time it dies")

func the_infinite_void() -> void:
	var f: Dictionary = setup(["THE_UNMADE"], {"warden": true})
	var foe: Dictionary = f.foe
	check(int(foe.bars) == 3 and int(foe.max_hp) == 200, "the Infinite Void: three bars of half its 400 health")
	var rolled: Array = []
	for rise in foe.rises:
		rolled.append_array(rise.traits.keys())
		check(rise.traits.size() == 1 and not str(rise.name).is_empty(), "each rise is one rolled trait, and named after it: %s" % str(rise.name))
	check(not rolled.has("sturdy") and rolled[0] != rolled[1], "never the Sturdy it has, never the same twice: %s" % str(rolled))
	foe.block = 0
	foe.statuses.erase("ward")
	foe.traits.sturdy = 0
	f.unit.rail = []
	var dice: int = foe.dice.size()
	hit(f, 99999)
	turn(f)
	check(foe.dice.size() >= dice + 1 and DeepCreatures.has_trait(foe, str(rolled[0])), "it rises with another d12 and that trait")

# --- the traits --------------------------------------------------------------------------

func riders() -> void:
	var f: Dictionary = setup(["THE_SMELTER"], {"warden": true})
	var moves: Array = DeepCreatures.moves_for(f.foe)
	var pour: Dictionary = DeepCreatures.move_in(moves, "Pour")
	var scald: Dictionary = DeepCreatures.move_in(moves, "Scald")
	var trample: Dictionary = DeepCreatures.move_in(moves, "Trample")
	check(pour.effects.size() == 2 and str(pour.effects[1].kind) == "burn" and int(pour.effects[1].amount) == 2, "the Smelter is Molten: Pour 6 lays 2 Burn")
	check(int(trample.effects[1].amount) == 2 and int(scald.effects[0].amount) == 10 and scald.effects.size() == 1, "Trample 8 lays 2, and Scald's 5 Burn is 10")
	check(DeepContent.creature("THE_SMELTER").moves[0].effects.size() == 1, "the pack's own moves are left as written")
	check(DeepCreatures.move_text(f.foe, pour).contains("and 2 Burn"), "the face says so: %s" % DeepCreatures.move_text(f.foe, pour))
	check(DeepCreatures.move_in(moves, "Stoke").effects.size() == 1, "a face that deals no damage lays nothing")
	only_die(f.foe, "Pour")
	f.unit.rail = []
	f.unit.block = 0
	turn(f)
	check(int(f.unit.statuses.get("burn", 0)) >= 1 and int(f.unit.get("creature_stacks", {}).get("burn", 0)) >= 1, "and a Pour that lands leaves Burn on the player, weighed like any creature's")
	var g: Dictionary = setup(["THE_GARDENER"], {"warden": true})
	var ram: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(g.foe), "Ram")
	check(ram.effects.size() == 2 and str(ram.effects[1].kind) == "poison" and int(ram.effects[1].amount) == 2, "the Gardener is Venomous: Ram 5 lays 2 Poison")
	## The cap: a face lays five at most, counted once however many hits it is.
	var c: Dictionary = setup(["THE_FOREMAN"], {"warden": true, "remembered": true, "extra_trait": "molten"})
	var crab: Array = DeepCreatures.moves_for(c.foe)
	check(int(DeepCreatures.move_in(crab, "Pick").effects[1].amount) == 1 and int(DeepCreatures.move_in(crab, "Cave-in").effects[1].amount) == 2 and int(DeepCreatures.move_in(crab, "Blast").effects[1].amount) == 5, "Pick 4 lays 1, Cave-in 7 lays 2, Blast's three hits of 10 lay 5")
	check(str(c.foe.name) == "The Molten Crabman", "and it is called after it: %s" % str(c.foe.name))
	## The Regent's blows have no written number: nothing rides them.
	var r: Dictionary = setup(["THE_REGENT"], {"warden": true, "remembered": true, "extra_trait": "venomous"})
	check(DeepCreatures.move_in(DeepCreatures.moves_for(r.foe), "Reflection").effects.size() == 1, "a blow with no written size carries nothing")

func wrathful() -> void:
	var f: Dictionary = setup(["THE_FOREMAN"], {"warden": true})
	f.foe.block = 500
	var first: Dictionary = hit(f, 3)
	hit(f, 3)
	hit(f, 3)
	check(int(f.foe.statuses.get("strength", 0)) == 3 and int(first.get("wrath", {}).get("strength", 0)) == 1, "the Crabman is Wrathful: three blows, three Strength, block or no block")
	DeepBattle._damage(f.state, f.unit, f.foe, 3, f.rng.dice, true, {}, false, true, true)
	check(int(f.foe.statuses.get("strength", 0)) == 3, "health lost outright is no blow")
	var pick: Dictionary = DeepCreatures.display_moves(f.foe, [DeepCreatures.move_in(DeepCreatures.moves_for(f.foe), "Pick")])[0]
	check(int(DeepRules.amount(pick.effects[0].amount, {"unit": f.foe})) >= 4 + 3, "and its Pick hits that much harder")

func leeching() -> void:
	var f: Dictionary = setup(["THE_FOREMAN"], {"warden": true, "remembered": true, "extra_trait": "leeching"})
	check(str(f.foe.name) == "The Leeching Crabman" and DeepCreatures.has_trait(f.foe, "leeching"), "a Leeching Crabman")
	f.foe.hp = 10
	f.unit.block = 0
	var blow: Dictionary = DeepBattle._damage(f.state, f.foe, f.unit, 8, f.rng.creatures)
	check(int(blow.get("leeched", {}).get("amount", 0)) == 8 and int(f.foe.hp) == 18, "it heals for the health its blow took: %s" % str(blow.get("leeched", {})))
	f.unit.block = 100
	var soaked: Dictionary = DeepBattle._damage(f.state, f.foe, f.unit, 8, f.rng.creatures)
	check(not soaked.has("leeched") and int(f.foe.hp) == 18, "and for nothing when block takes it")

# --- the Rift ----------------------------------------------------------------------------

func the_rift_remembers() -> void:
	var f: Dictionary = setup(["THE_DRILL"], {"warden": true, "remembered": true, "extra_trait": "jagged", "bars": 3})
	var foe: Dictionary = f.foe
	check(str(foe.name) == "The Jagged Drill" and str(foe.remembered) == "jagged" and DeepCreatures.trait_value(foe, "jagged", 0) == 1, "the Rift remembers the Drill Jagged, and calls it that: %s" % str(foe.name))
	check(int(foe.bars) == 3 and int(foe.max_hp) == 120 and str(foe.rises[0].name) == "Redline", "with three bars, the second its own from upstairs")
	var third: Array = foe.rises[1].traits.keys()
	check(third.size() == 1 and not ["jagged", "molten"].has(third[0]) and not str(foe.rises[1].name).is_empty(), "and the third one more rolled trait: %s" % str(third))
	## Never a trait it has, or is written to take.
	var seen: Dictionary = {}
	for seed_value in range(60):
		var u: Dictionary = setup(["THE_UNDERTOW"], {"warden": true, "remembered": true, "bars": 3}, 1, 900 + seed_value)
		seen[str(u.foe.remembered)] = true
		var all: Array = [str(u.foe.remembered)] + u.foe.rises[0].traits.keys() + u.foe.rises[1].traits.keys()
		check(all.size() == 3 and all[0] != all[2] and all[1] != all[2], "three different traits down the Undertow's bars: %s" % str(all))
	check(not seen.has("steadfast") and not seen.has("wrathful") and seen.size() >= 4, "the Undertow is never rolled Steadfast (it is) or Wrathful (its second bar): %s" % str(seen.keys()))
	## A Warden the Rift remembers has one bar and one trait.
	var w: Dictionary = setup(["THE_REGENT"], {"warden": true, "remembered": true, "bars": 3})
	check(int(w.foe.bars) == 1 and not str(w.foe.remembered).is_empty() and str(w.foe.name).begins_with("The ") and str(w.foe.name).ends_with("Mirror Regent") and str(w.foe.name) != "The Mirror Regent", "a remembered Warden: one bar, one trait: %s" % str(w.foe.name))
	## Crown's Court: the guest has one bar, at its whole health.
	var court: Dictionary = setup(["THE_HOLLOW_CROWN", "THE_DRILL"], {"warden": true, "court": 1})
	var guest: Dictionary = court.state.enemies.filter(func(e: Dictionary) -> bool: return str(e.key) == "THE_DRILL")[0]
	check(int(guest.bars) == 1 and int(guest.max_hp) == 200 and not str(guest.get("remembered", "")).is_empty(), "the Crown's guest has one bar and its trait")

func the_rift_wardens() -> void:
	check(DeepDescent.is_warden_depth(4, "RIFT") and DeepDescent.is_warden_depth(8, "RIFT") and DeepDescent.is_warden_depth(12, "RIFT") and not DeepDescent.is_warden_depth(6, "RIFT"), "a Warden at every landing of the Rift")
	var deep: Dictionary = {"mine": "RIFT"}
	check(DeepDescent.warden_key(deep, 4) == "THE_FOREMAN" and DeepDescent.warden_key(deep, 12) == "THE_REGENT" and DeepDescent.warden_key(deep, 20) == "THE_LOCKKEEPER", "the smaller Wardens in order, between the bosses")
	check(DeepDescent.warden_key(deep, 8) == "THE_DRILL" and DeepDescent.warden_key(deep, 16) == "THE_UNDERTOW" and DeepDescent.warden_key(deep, 40) == "THE_UNMADE", "the bosses where they were")
	check(DeepDescent.warden_key(deep, 76) == "THE_ANVIL_KNIGHT" and DeepDescent.warden_key(deep, 84) == "THE_FOREMAN", "and round again")
	var remembered: Array = DeepContent.mine("RIFT").remembered_wardens
	check(remembered.size() == 10 and not remembered.has("THE_ASSAYER") and not remembered.has("THE_COLLECTOR"), "ten of them: the Hollow's two stay out")
	check(not DeepDescent.is_warden_depth(4, "QUARRY") and not DeepDescent.is_third_warden({"mine": "RIFT"}, 4), "no other mine, and no third Warden's hoard for them")

func champions() -> void:
	for key in DeepContent.REMEMBERED_TRAITS:
		check(DeepDescent.CHAMPION_TRAITS.has(key), "a Champion may be %s" % str(key))
	check(DeepDescent.CHAMPION_TRAITS.has("spikes") and DeepDescent.CHAMPION_TRAITS.has("regenerating") and DeepDescent.CHAMPION_TRAITS.has("warded"), "or Spiked, Regenerating or Warded")
	check(DeepCreatures.titled("Slag Hound", "Molten") == "Molten Slag Hound" and DeepCreatures.titled("The Drill", "Splits") == "The Splitting Drill", "and is called after it")

func run_config(seed_value: int, mine: String, seen: Array = []) -> Dictionary:
	var bowl: Array = []
	for i in range(5):
		bowl.append(DeepDice.make("D6", "a_d%d" % i))
	return {"seed": seed_value, "mine": mine, "boons": false, "players": [
		{"id": "a", "name": "Ada", "character": "ARDOR", "rail": [stone("STRIKE", "a_strike")], "dice": bowl, "seen_rise": seen}]}

func down_a_run() -> void:
	## The run hands the fight what it needs: three bars and a rolled trait in the Rift, a
	## smaller Warden between its bosses, and whose bars are shown.
	var deep: Dictionary = DeepDescent.new_run(run_config(51, "RIFT", ["THE_DRILL"]))
	check(deep.seen_rise == ["THE_DRILL"], "a run starts knowing who its party has watched get up")
	var streams: Dictionary = DeepDescent.streams_of(deep)
	deep.phase = "chamber"
	deep.depth = 8
	deep.chamber = {"kind": "warden", "depth": 8, "settled": false}
	DeepDescent._start_fight(deep, streams, false, DeepDescent.warden_key(deep, 8))
	var drill: Dictionary = deep.chamber.battle.enemies.filter(func(e: Dictionary) -> bool: return str(e.key) == "THE_DRILL")[0]
	check(int(drill.bars) == 3 and not str(drill.get("remembered", "")).is_empty() and str(drill.name) != "The Drill" and str(drill.name).ends_with("Drill") and bool(drill.bars_shown),
		"the Rift's Drill: three bars, a rolled trait in its name, its bars shown: %s" % str(drill.name))
	deep.depth = 4
	deep.chamber = {"kind": "warden", "depth": 4, "settled": false}
	DeepDescent._start_fight(deep, streams, false, DeepDescent.warden_key(deep, 4))
	var crab: Dictionary = deep.chamber.battle.enemies[0]
	check(str(crab.key) == "THE_FOREMAN" and int(crab.bars) == 1 and not str(crab.get("remembered", "")).is_empty() and str(crab.name).ends_with("Crabman") and str(crab.name) != "The Crabman",
		"a remembered Crabman at the Rift's fourth floor, one bar, one trait: %s" % str(crab.name))
	check(DeepCreatures.named_traits(crab).has("wrathful") and DeepCreatures.named_traits(crab).size() == 2, "its own Wrathful and the one the Rift rolled: %s" % str(DeepCreatures.named_traits(crab)))
	## Upstairs: the Quarry's Drill has two bars, hidden from a party that has not seen it rise.
	var run: Dictionary = DeepDescent.new_run(run_config(52, "QUARRY"))
	var bottom: int = DeepDescent.bottom_of(run)
	run.phase = "chamber"
	run.depth = bottom
	run.chamber = {"kind": "warden", "depth": bottom, "settled": false}
	DeepDescent._start_fight(run, DeepDescent.streams_of(run), false, DeepDescent.warden_key(run, bottom))
	var boss: Dictionary = run.chamber.battle.enemies[0]
	check(str(boss.key) == "THE_DRILL" and int(boss.bars) == 2 and not bool(boss.bars_shown) and str(boss.name) == "The Drill" and str(boss.get("remembered", "")).is_empty(), "the Quarry's own Drill: two bars, not shown, no rolled trait")
	## It falls and rises in the run's own fight, and the run remembers.
	boss.block = 0
	boss.statuses.erase("ward")
	var b: Dictionary = run.chamber.battle
	DeepBattle._damage(b, b.players[0], boss, 999999, DeepRng.streams(1, ["dice"]).dice)
	check(bool(boss.fallen), "it falls")
	var rng: Dictionary = DeepRng.streams(9, ["dice", "creatures"])
	DeepBattle._rise(b, boss, rng.creatures, false)
	DeepDescent._settle_fight(run, "defeat")
	check(run.seen_rise.has("THE_DRILL") and int(run.bestiary.THE_DRILL.get("risen", 0)) == 1, "the run notes it for the Bestiary and for the next time it is met")

func the_bestiary() -> void:
	var f: Dictionary = setup(["THE_DRILL"], {"warden": true, "seen_rise": ["THE_DRILL"]})
	check(bool(f.foe.bars_shown), "a boss someone has watched get up shows its bars from the start")
	var run: Dictionary = {"mine": "QUARRY", "depth": 16}
	f.foe.bar = 2
	DeepBestiary.settled(run, [f.foe], "victory")
	check(int(run.bestiary.THE_DRILL.get("risen", 0)) == 1, "the run notes that it rose")
	var profile: Dictionary = {"bestiary": {}}
	DeepBestiary.merge(profile, run.bestiary)
	check(DeepBestiary.seen_rising(profile, "THE_DRILL") and DeepBestiary.risers(profile) == ["THE_DRILL"], "and the profile keeps it")
