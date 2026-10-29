extends SceneTree
## The deeper mines' creatures and the mechanics they fight with (docs/BESTIARY.md,
## docs/CREATURE_DICE.md), exercised through real battle steps with the faces they land.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	turn_triggers()
	summons_and_escorts()
	burrow_and_emerge()
	refract_mirror_and_absorb()
	fester_scorch_and_burn()
	steadfast_and_sturdy()
	backlash_and_damping()
	locks_and_dread()
	theft_and_flight()
	gems_held_and_buried()
	bursts_and_swelling()
	charge_and_release()
	strength_heads_and_empowerment()
	the_refractor_feeds_on_colour()
	dice_for_the_fight_and_for_good()
	echoes_and_the_remembered()
	the_hollow_crown()
	a_bosss_brood_runs()
	scaling_with_the_mine()
	the_identity_pass()
	every_creature_has_a_tip()
	wording_and_content()
	print("Bestiary: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

# --- fixtures ----------------------------------------------------------------------------

func setup(keys: Array, players: int = 1, context: Dictionary = {}, rail: Array = [], riders: Array = []) -> Dictionary:
	var party: Array = []
	for i in range(players):
		var bowl: Array = []
		for j in range(5):
			bowl.append(DeepDice.make("D6", "p%d_d%d" % [i, j]))
		var unit: Dictionary = DeepBattle.make_player("p%d" % i, "Player %d" % i, "ARDOR", rail.duplicate(true), bowl, -1, riders.duplicate(true))
		unit.birthstone = {}
		unit.passive = {}
		unit.hp = 1000
		unit.max_hp = 1000
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(314, ["dice", "creatures"])
	var ctx: Dictionary = {"depth": 1}
	ctx.merge(context, true)
	var state: Dictionary = DeepBattle.begin(party, keys, ctx, rng.dice, rng.creatures)
	## The creatures stand up to a lot here: what is under test is what they do, not how
	## quickly a rail kills them.
	if bool(context.get("tough", true)):
		for foe in state.enemies:
			foe.max_hp = maxi(int(foe.max_hp), 1000)
			foe.hp = int(foe.max_hp)
	## The creature under test is the first one written, wherever its escorts have stood it.
	var leads: Array = state.enemies.filter(func(e: Dictionary) -> bool: return str(e.get("escort_of", "")).is_empty())
	return {"state": state, "rng": rng, "foe": leads[0] if not leads.is_empty() else state.enemies[0], "player": state.players[0]}

func escorts_of(f: Dictionary) -> Array:
	return f.state.enemies.filter(func(e: Dictionary) -> bool: return str(e.get("escort_of", "")) == str(f.foe.id))

func fixed(foe: Dictionary, values: Array, tops: Array = []) -> void:
	## Every die a single face, so an action rolls exactly these values in this order. A
	## single face is its die's top, so every such roll is a crown unless `tops` says the
	## die is bigger than what it shows.
	foe.dice = []
	for i in range(values.size()):
		var die: Dictionary = DeepDice.make("D6", "%s_d%d" % [str(foe.id), i], {"faces": [DeepDice.face(int(values[i]))]})
		if i < tops.size():
			die.top = int(tops[i])
		foe.dice.append(die)

func turn(f: Dictionary, lock_hand: bool = true) -> Array:
	## One whole turn: every player locks as they stand, then every step until the next planning.
	var out: Array = []
	if lock_hand:
		DeepBattle.force_lock(f.state)
	out.append(DeepBattle.start_resolution(f.state))
	while DeepBattle.has_steps(f.state) and out.size() < 300:
		var before: Dictionary = f.state.duplicate(true)
		var event: Dictionary = DeepBattle.step(f.state, f.rng.dice, f.rng.creatures)
		var guest: Dictionary = DeepPatch.apply(before, DeepPatch.diff(before, f.state))
		check(JSON.stringify(guest) == JSON.stringify(f.state), "bestiary state patches identically to a guest")
		out.append(event)
	check(out.size() < 300, "a bestiary turn terminates")
	return out

func of(all: Array, kind: String) -> Array:
	return all.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == kind)

func moves_named(all: Array, name: String) -> Array:
	return of(all, "enemy_move").filter(func(e: Dictionary) -> bool: return str(e.get("move", "")) == name)

func apply(f: Dictionary, effect: Dictionary, from_player: bool = true) -> Array:
	return DeepBattle._apply(f.state, f.player if from_player else f.foe, effect, f.rng.dice)

func hit(f: Dictionary, amount: int, colors: Array = ["RED"], socket: int = 0) -> Dictionary:
	## A player's blow on the first creature, thrown in a colour from a socket.
	f.player.firing_colors = colors
	f.player.firing_stone = {"stone_id": str(f.player.rail[socket].get("id", "")) if socket < f.player.rail.size() and f.player.rail[socket] is Dictionary else "", "socket": socket}
	var out: Dictionary = DeepBattle._damage(f.state, f.player, f.foe, amount, f.rng.dice)
	f.player.erase("firing_colors")
	f.player.erase("firing_stone")
	return out

func stone(skill: String, id: String, carat: int = 1) -> Dictionary:
	return DeepStone.make(skill, carat, 4, 3, [], {}, id)

func with_moves(key: String, moves: Array, body: Callable) -> void:
	## Runs `body` with a creature's moves swapped for `moves`, and puts them back after.
	var def: Dictionary = DeepContent.creature(key)
	var saved: Dictionary = def.duplicate(true)
	def.moves = moves
	def.erase("phases")
	body.call()
	def.clear()
	def.merge(saved)

static func dmg(amount: Variant, target: String = "heroes") -> Dictionary:
	return {"kind": "damage", "target": target, "amount": amount}

func shapes(dice: Array) -> Array:
	return dice.map(func(d: Dictionary) -> String: return str(d.get("shape", "")))

# --- the tests ---------------------------------------------------------------------------

func land(foe: Dictionary, names: Array) -> void:
	## The creature throws one die for each name, its only face that one of its moves: an
	## action die (docs/CREATURE_DICE.md) that lands on that move whatever it throws.
	var moves: Array = DeepCreatures.moves_for(foe)
	foe.dice = []
	for i in range(names.size()):
		var move: Dictionary = DeepCreatures.move_in(moves, str(names[i]))
		check(not move.is_empty(), "%s has a move called %s" % [str(foe.get("key", "")), str(names[i])])
		var die: Dictionary = DeepDice.make("D6", "%s_d%d" % [str(foe.id), i], {"faces": [DeepDice.face(1)]})
		DeepCreatures.dress_face(die.faces[0], move)
		foe.dice.append(die)

func force_faces(foe: Dictionary, at_die: int, name: String) -> void:
	## Every face of one of its own dice carries this move; the die keeps its shape and place.
	var move: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), name)
	check(not move.is_empty(), "%s has a move called %s" % [str(foe.get("key", "")), name])
	for face in foe.dice[at_die].faces:
		DeepCreatures.dress_face(face, move)

func faces_of(foe: Dictionary, name: String, at_die: int = -1) -> int:
	## How many faces of its dice (or of one of them) carry this move.
	var n: int = 0
	for d in range(foe.dice.size()):
		if at_die >= 0 and d != at_die:
			continue
		for face in foe.dice[d].faces:
			if str(face.get("move", "")) == name:
				n += 1
	return n

func amount_of(key: String, move: String, at: int = 0) -> int:
	## A number as the creature's card writes it.
	return int(DeepCreatures.move_in(DeepContent.creature(key).moves, move).effects[at].amount)

func pyrite_of(unit: Dictionary) -> int:
	return DeepRules.pyrite(unit)

func turn_triggers() -> void:
	## Moves read from the action rather than a die: each action, every nth, once a fight,
	## never during an action (on death), and one die in particular.
	with_moves("CAVE_TICK", [
		{"name": "Every", "trigger": {"kind": "each_turn"}, "effects": [{"kind": "block", "target": "self", "amount": 1}]},
		{"name": "Second", "trigger": {"kind": "every_nth_turn", "amount": 2}, "effects": [{"kind": "block", "target": "self", "amount": 10}]},
		{"name": "Once", "trigger": {"kind": "each_turn"}, "once": true, "effects": [{"kind": "block", "target": "self", "amount": 100}]},
		{"name": "Burst", "trigger": {"kind": "on_death"}, "effects": [{"kind": "poison", "target": "heroes", "amount": 3}]},
		{"name": "Second die", "trigger": {"kind": "at_least", "amount": 1, "die": 1}, "effects": [dmg(1)]},
		{"name": "Bite", "trigger": {"kind": "always"}, "effects": [dmg({"term": "rolled"})]}], func() -> void:
		var f: Dictionary = setup(["CAVE_TICK"])
		fixed(f.foe, [3, 4])
		var first: Array = turn(f)
		check(moves_named(first, "Every").size() == 1, "an each_turn move fires once an action, not once a die")
		check(moves_named(first, "Second").is_empty(), "an every-second-action move waits for the second action")
		check(moves_named(first, "Once").size() == 1 and moves_named(first, "Burst").is_empty(), "a once move fires on its first chance; an on_death move never fires in an action")
		check(moves_named(first, "Second die").size() == 1 and moves_named(first, "Bite").size() == 2, "a move that names a die reads only that die; an ordinary move reads them all")
		check(int(f.foe.block) == 101, "the each-action and once moves both landed: block %d" % int(f.foe.block))
		check(f.foe.move_states.has("latent") and f.foe.move_states.has("spent"), "the table shows the death move as latent and the once move as spent: %s" % str(f.foe.move_states))
		var second: Array = turn(f)
		check(moves_named(second, "Second").size() == 1 and moves_named(second, "Once").is_empty(), "the second action fires the every-second move and not the spent one")
		check(DeepCreatures.next_nth_in(f.foe, DeepContent.creature("CAVE_TICK").moves[1]) == 2, "after the second action the next every-second firing is two actions off")
		## Dying sets off the death move, with the creature as its source.
		f.foe.block = 0
		var killing: Dictionary = hit(f, 9999)
		check(bool(killing.get("killed", false)) and not killing.get("deathburst", []).is_empty(), "the killing blow carries the burst")
		check(int(f.player.statuses.get("poison", 0)) == 3, "the burst poisoned the party"))
	## A move that opens the action goes before any die; one that waits for its health to
	## fall goes the moment it falls that far, and only once.
	with_moves("CAVE_TICK", [
		{"name": "Open", "trigger": {"kind": "action_begin"}, "effects": [{"kind": "block", "target": "self", "amount": 7}]},
		{"name": "Halfway", "trigger": {"kind": "hp_below", "amount": 50}, "effects": [{"kind": "block", "target": "self", "amount": 100}]},
		{"name": "Bite", "trigger": {"kind": "always"}, "effects": [dmg({"term": "rolled"})]}], func() -> void:
		var f: Dictionary = setup(["CAVE_TICK"])
		fixed(f.foe, [2])
		var events: Array = turn(f)
		var opened: int = events.find(moves_named(events, "Open")[0]) if not moves_named(events, "Open").is_empty() else -1
		var rolled: int = events.find(of(events, "enemy_roll")[0]) if not of(events, "enemy_roll").is_empty() else -1
		check(opened >= 0 and opened < rolled, "the opening move lands before the first die is thrown: %d / %d" % [opened, rolled])
		check(moves_named(events, "Halfway").is_empty() and str(f.foe.move_states[1]) == "latent", "the health move waits: %s" % str(f.foe.move_states))
		f.foe.block = 0
		var half: Dictionary = hit(f, int(f.foe.hp) - int(f.foe.max_hp) / 2)
		check(half.get("thresholds", []).size() == 1 and int(f.foe.block) == 100, "falling to half sets it off at once: %s" % str(half.get("thresholds", [])))
		f.foe.block = 0
		var lower: Dictionary = hit(f, 10)
		check(not lower.has("thresholds") and int(f.foe.block) == 0, "and only the once")
		DeepCreatures.prepare(f.foe)
		check(str(f.foe.move_states[1]) == "spent", "then it reads as spent"))

func summons_and_escorts() -> void:
	## A Rail Rat's Scurry calls another rat.
	var f: Dictionary = setup(["RAIL_RAT"])
	land(f.foe, ["Scurry"])
	var events: Array = turn(f)
	check(moves_named(events, "Scurry").size() == 1 and f.state.enemies.size() == 2, "a Rail Rat's Scurry calls another rat: %d creatures" % f.state.enemies.size())
	var pup: Dictionary = f.state.enemies[1] if f.state.enemies.size() > 1 else {}
	check(str(pup.get("key", "")) == "RAIL_RAT" and bool(pup.get("summoned", false)) and str(pup.get("id", "")) != str(f.foe.id), "the newcomer is a summoned rat with its own id")
	check(int(pup.get("turns_acted", -1)) == 0, "it acts from the next turn")
	land(f.foe, ["Gnaw"])
	if not pup.is_empty():
		land(pup, ["Gnaw"])
	var again: Array = turn(f)
	check(of(again, "enemy_begin").size() >= 2, "both rats act the turn after")
	## Four creatures at most.
	var crowded: Dictionary = setup(["RAIL_RAT", "RAIL_RAT", "RAIL_RAT", "RAIL_RAT"])
	for rat in crowded.state.enemies:
		land(rat, ["Gnaw"])
	land(crowded.foe, ["Scurry"])
	var full: Array = turn(crowded)
	var scurry: Array = moves_named(full, "Scurry")
	check(scurry.size() == 1 and bool(scurry[0].effects[0].get("nothing", false)) and crowded.state.enemies.size() == 4, "a full chamber has no room for a fifth creature")
	## Escorts come with their leader, and shield it while they stand.
	var p: Dictionary = setup(["THE_PRISMARCH"])
	check(p.state.enemies.size() == 4 and p.foe.escorts.size() == 3, "the Prismarch walks in with three prisms")
	check(escorts_of(p).size() == 3 and escorts_of(p).all(func(e: Dictionary) -> bool: return str(e.key) == "PRISM"), "each prism knows its leader")
	## They stand either side of it in turn, the first on its right, so it holds the middle.
	var row: Array = p.state.enemies.map(func(e: Dictionary) -> String: return str(e.id))
	var mine: Array = p.foe.escorts
	check(row.find(str(p.foe.id)) == 1 and row.find(str(mine[0])) == 2 and row.find(str(mine[1])) == 0 and row.find(str(mine[2])) == 3, "the prisms flank the Prismarch: %s" % str(row))
	check(str(DeepBattle.default_target(DeepBattle.living(p.state.enemies)).id) == str(p.foe.id) and str(p.player.target) == str(p.foe.id), "and the Prismarch is still who blows go at by default")
	p.foe.block = 0
	var shielded: Dictionary = hit(p, 40)
	check(bool(shielded.get("shielded", false)) and int(shielded.hp_loss) == 20, "while a prism floats the Prismarch takes half: %d" % int(shielded.hp_loss))
	for escort in escorts_of(p):
		escort.hp = 0
	var bare: Dictionary = hit(p, 40)
	check(not bare.has("shielded") and int(bare.hp_loss) == 40, "with the prisms gone it takes the whole blow")
	## Its Raise a Prism calls one back, three standing at most.
	land(p.foe, ["Raise a Prism", "Raise a Prism", "Raise a Prism", "Raise a Prism"])
	p.player.statuses.stun = 1
	var raised: Array = moves_named(turn(p), "Raise a Prism")
	var prisms: Array = DeepBattle.living(p.state.enemies).filter(func(e: Dictionary) -> bool: return str(e.key) == "PRISM")
	check(raised.size() == 4 and prisms.size() == 3 and bool(raised[3].effects[0].get("nothing", false)), "Raise a Prism calls a prism, three at most: %d standing" % prisms.size())
	## The Heartrot's Regrow grows a tendril back into the gap, and the new one is its escort.
	var h: Dictionary = setup(["THE_HEARTROT"])
	escorts_of(h)[0].hp = 0
	for tendril in escorts_of(h):
		land(tendril, ["Lash"])
	land(h.foe, ["Regrow"])
	var grown: Array = turn(h)
	var fresh: Array = h.state.enemies.filter(func(e: Dictionary) -> bool: return str(e.get("summoned_by", "")) == str(h.foe.id))
	check(moves_named(grown, "Regrow").size() == 1 and DeepBattle.living(h.state.enemies).size() == 4, "a Regrow grows a tendril into the gap: %d standing" % DeepBattle.living(h.state.enemies).size())
	check(fresh.size() == 1 and str(fresh[0].key) == "TENDRIL" and str(fresh[0].escort_of) == str(h.foe.id) and h.foe.escorts.has(str(fresh[0].id)), "the new tendril is one of the heart's escorts")
	for tendril in escorts_of(h):
		land(tendril, ["Lash"])
	land(h.foe, ["Regrow", "Regrow"])
	var no_room: Array = turn(h)
	check(moves_named(no_room, "Regrow").size() == 2 and moves_named(no_room, "Regrow").all(func(e: Dictionary) -> bool: return bool(e.effects[0].get("nothing", false)))
		and DeepBattle.living(h.state.enemies).size() == 4, "with all three standing there is no room for more")
	## A Tendril's Knit heals the Heartrot it guards.
	var knit: Dictionary = escorts_of(h).filter(func(e: Dictionary) -> bool: return int(e.hp) > 0)[0]
	land(knit, ["Knit"])
	land(h.foe, ["Rot"])
	h.foe.hp = 900
	var knitted: Array = turn(h)
	check(moves_named(knitted, "Knit").size() == 1 and str(moves_named(knitted, "Knit")[0].effects[0].target) == str(h.foe.id) and int(h.foe.hp) == 900 + amount_of("TENDRIL", "Knit"),
		"a Tendril's Knit heals the Heartrot: %d" % int(h.foe.hp))
	## The Gardener: Plant calls a Puffball, Tend heals every creature, Sow calls a Root Horror.
	var g: Dictionary = setup(["THE_GARDENER"])
	g.foe.hp = 900
	land(g.foe, ["Plant", "Tend"])
	var plant: Array = turn(g)
	check(moves_named(plant, "Plant").size() == 1 and g.state.enemies.size() == 2 and str(g.state.enemies[1].key) == "PUFFBALL", "Plant calls a Puffball")
	check(int(g.foe.hp) == 900 + amount_of("THE_GARDENER", "Tend"), "Tend heals the Gardener itself: %d" % int(g.foe.hp))
	var puff: Dictionary = g.state.enemies[1] if g.state.enemies.size() > 1 else {}
	if not puff.is_empty():
		puff.hp = 10
		land(puff, ["Swell"])
	land(g.foe, ["Tend"])
	var tended: Array = turn(g)
	check(moves_named(tended, "Tend").size() == 1 and int(puff.get("hp", 0)) == 10 + amount_of("THE_GARDENER", "Tend"), "and every other creature: the Puffball %d" % int(puff.get("hp", 0)))
	land(g.foe, ["Sow"])
	var sow: Array = turn(g)
	check(moves_named(sow, "Sow").size() == 1 and g.state.enemies.any(func(e: Dictionary) -> bool: return str(e.key) == "ROOT_HORROR"), "Sow calls a Root Horror")
	var prune: Dictionary = DeepCreatures.move_in(DeepContent.creature("THE_GARDENER").moves, "Prune")
	check(not bool(prune.effects[0].get("permanent", false)), "its Prune grinds the faces for the fight, not for good")

func burrow_and_emerge() -> void:
	var f: Dictionary = setup(["PIT_MOLE", "RAIL_RAT"], 2)
	land(f.foe, ["Dig In"])
	land(f.state.enemies[1], ["Gnaw"])
	f.state.players[0].block = 5
	var dig: Array = turn(f)
	check(moves_named(dig, "Dig In").size() == 1 and moves_named(dig, "Claw").is_empty(), "Dig In digs in")
	check(bool(f.foe.burrowed), "the mole is under the floor")
	check(of(dig, "enemy_end").any(func(e: Dictionary) -> bool: return bool(e.get("burrowed", false))), "its turn ends as it burrows")
	## Under the floor it cannot be reached: a gem finds the rat instead.
	var reach: Array = DeepBattle._targets(f.state, f.state.players[0], "enemies")
	check(reach.size() == 1 and str(reach[0].key) == "RAIL_RAT", "gems that hit every creature miss the burrowed one")
	f.state.players[0].target = str(f.foe.id)
	f.state.players[0].firing_target = str(f.foe.id)
	var aimed: Array = DeepBattle._targets(f.state, f.state.players[0], "enemy")
	check(aimed.size() == 1 and str(aimed[0].key) == "RAIL_RAT", "a gem aimed at it hits another creature instead")
	check(DeepBattle.targetable(f.state.enemies).size() == 1, "one creature is targetable")
	## Next turn it comes up with Erupt, at every player, and its face lands as well.
	f.state.players[0].block = 0
	f.state.players[1].block = 3
	land(f.foe, ["Claw"])
	var up: Array = turn(f)
	var begin: Array = of(up, "enemy_begin").filter(func(e: Dictionary) -> bool: return str(e.unit) == str(f.foe.id))
	check(not begin.is_empty() and bool(begin[0].get("emerged", false)) and not bool(f.foe.burrowed), "it emerges as it acts again")
	var erupt: Array = moves_named(up, "Erupt")
	var blow: int = amount_of("PIT_MOLE", "Erupt")
	check(erupt.size() == 1 and erupt[0].effects.size() == 2 and erupt[0].effects.map(func(e: Dictionary) -> String: return str(e.target)) == ["p0", "p1"]
		and erupt[0].effects.all(func(e: Dictionary) -> bool: return int(e.raw) == blow), "Erupt hits every player for %d as it comes up: %s" % [blow, str(erupt[0].effects if not erupt.is_empty() else [])])
	check(moves_named(up, "Claw").size() == 1, "and the face it threw claws as well")

func refract_mirror_and_absorb() -> void:
	## A Prism Golem's Refract: until it acts again, half of every blow on it goes back at
	## every player.
	var f: Dictionary = setup(["PRISM_GOLEM"], 2)
	land(f.foe, ["Refract"])
	turn(f)
	check(int(f.foe.reflect) == 50 and not bool(f.foe.get("reflect_thrower", false)), "Refract turns half of every blow back at the party")
	f.foe.block = 0
	for unit in f.state.players:
		unit.block = 0
	var had: Array = f.state.players.map(func(u: Dictionary) -> int: return int(u.hp))
	var struck: Dictionary = hit(f, 20)
	check(int(struck.hp_loss) == 20 and struck.get("reflections", []).size() == 2, "the golem takes the blow and sends half back: %s" % str(struck.get("reflections", [])))
	check(int(f.state.players[0].hp) == int(had[0]) - 10 and int(f.state.players[1].hp) == int(had[1]) - 10, "ten at every player, not only the thrower")
	land(f.foe, ["Pound"])
	var next: Array = turn(f)
	check(int(f.foe.reflect) == 0 and bool(of(next, "enemy_begin")[0].get("guard_ended", false)), "the refraction ends when it acts again")
	check(int(hit(f, 20).get("reflections", []).size()) == 0, "and blows land plainly again")
	## Every wyrm's Mirror sends half back at whoever threw it, and only them.
	for key in ["GLASS_WYRM", "SHARD_WYRM", "AMETHYST_WYRM"]:
		var w: Dictionary = setup([key], 2)
		land(w.foe, ["Mirror"])
		turn(w)
		w.foe.block = 0
		for unit in w.state.players:
			unit.block = 0
		var before: Array = w.state.players.map(func(u: Dictionary) -> int: return int(u.hp))
		var back: Dictionary = hit(w, 20)
		check(back.get("reflections", []).size() == 1 and int(w.state.players[0].hp) == int(before[0]) - 10 and int(w.state.players[1].hp) == int(before[1]),
			"%s's Mirror sends ten back at the thrower alone" % key)
	## An Echo Sprite's mirror sends the whole of the next blow back at whoever threw it.
	var e: Dictionary = setup(["ECHO_SPRITE"])
	land(e.foe, ["Mirror"])
	turn(e)
	check(int(e.foe.mirror) == 1, "its Mirror holds up a mirror")
	e.foe.block = 0
	e.player.block = 0
	var before_hp: int = int(e.foe.hp)
	var owner_hp: int = int(e.player.hp)
	var mirrored: Dictionary = hit(e, 12)
	check(int(e.foe.hp) == before_hp and mirrored.has("mirrored") and int(e.player.hp) == owner_hp - 12, "the blow goes back whole at its thrower: %s" % str(mirrored))
	var through: Dictionary = hit(e, 12)
	check(int(through.hp_loss) == 12 and int(e.foe.mirror) == 0, "the mirror is spent: the next blow lands")
	land(e.foe, ["Twinkle"])
	var twinkle: Array = turn(e)
	check(moves_named(twinkle, "Twinkle").size() == 1 and int(moves_named(twinkle, "Twinkle")[0].effects[0].raw) == amount_of("ECHO_SPRITE", "Twinkle"), "Twinkle hits for its number")
	## The Kaleidoscope's Drink: those gems do it no harm, and what they would give their owner
	## goes to it instead, until it acts again.
	var k: Dictionary = setup(["THE_KALEIDOSCOPE"], 1, {}, [stone("STRIKE", "k_s1"), stone("STRIKE", "k_s2")])
	k.player.statuses.stun = 1
	land(k.foe, ["Drink", "Glare"])
	turn(k)
	check(k.foe.absorb.size() == 1 and str(k.foe.absorb[0]) in DeepContent.color_KEYS, "Drink drinks one colour: %s" % str(k.foe.absorb))
	var colour: String = str(k.foe.absorb[0]) if not k.foe.absorb.is_empty() else "RED"
	k.foe.block = 0
	var full: int = int(k.foe.hp)
	var drunk: Dictionary = hit(k, 12, [colour])
	check(int(k.foe.hp) == full and str(drunk.get("drunk", "")) == colour and not drunk.has("mirrored"), "a gem of that colour does it no harm: %s" % str(drunk))
	var other: String = "RED" if colour != "RED" else "BLUE"
	check(int(hit(k, 12, [other]).hp_loss) == 12, "other colours land")
	k.player.firing_colors = [colour]
	k.player.block = 0
	k.foe.block = 0
	var gift: Array = DeepBattle._apply(k.state, k.player, {"kind": "block", "target": "self", "amount": 9}, k.rng.dice)
	k.player.erase("firing_colors")
	check(int(k.player.block) == 0 and int(k.foe.block) == 9 and str(gift[0].get("drunk_by", "")) == str(k.foe.id), "the block a gem of that colour would give its owner goes to the Kaleidoscope")
	## Both dice on Drink: it drinks the colour the party fires most as well.
	var strike_colour: String = str(DeepStone.colors(k.player.rail[0], str(k.player.sockets[0]))[0])
	land(k.foe, ["Drink", "Drink"])
	k.player.statuses.stun = 1
	var turned: Array = turn(k)
	check(moves_named(turned, "Drink").size() == 2 and moves_named(turned, "Deep Drink").size() == 1 and k.foe.absorb.size() == 2 and k.foe.absorb.has(strike_colour),
		"two Drinks are a Deep Drink: it drinks the party's own colour too: %s" % str(k.foe.absorb))
	land(k.foe, ["Glare"])
	var ended: Array = turn(k)
	check(k.foe.absorb.is_empty() and bool(of(ended, "enemy_begin")[0].get("guard_ended", false)), "what it drank it lets go as it acts again")

func fester_scorch_and_burn() -> void:
	var f: Dictionary = setup(["CAP_SHAMBLER"])
	f.player.statuses.festering = 2
	f.player.hp = 500
	check(DeepBattle._heal(f.player, 10) == 5, "Festering halves healing")
	f.player.statuses.scorched = 1
	apply(f, {"kind": "block", "target": "self", "amount": 9}, true)
	check(int(f.player.block) == 5, "Scorched halves block gained, rounded up: %d" % int(f.player.block))
	## Burn hurts at the end of the turn like poison, but block soaks it first.
	f.player.statuses.burn = 5
	f.player.block = 3
	var unburnt: int = int(f.player.hp)
	var burnt: Dictionary = DeepBattle._burn_tick(f.state, f.player)
	check(int(burnt.soaked) == 3 and int(burnt.amount) == 2 and int(f.player.hp) == unburnt - 2 and int(f.player.statuses.burn) == 4, "Burn 5 against 3 block: 3 soaked, 2 taken, 4 left: %s" % str(burnt))
	f.player.statuses.erase("burn")
	## Festering and Scorched count down at the tick, except on the turn an enemy applied them.
	f.player.statuses.festering = 2
	f.player.statuses.scorched = 2
	land(f.foe, ["Slam"])
	turn(f)
	check(int(f.player.statuses.festering) == 1 and int(f.player.statuses.scorched) == 1, "each counts down one a turn")
	var fresh: Dictionary = setup(["CAP_SHAMBLER"])
	land(fresh.foe, ["Spore Cloud"])
	var cloud: Array = turn(fresh)
	check(moves_named(cloud, "Spore Cloud").size() == 1 and int(fresh.player.statuses.get("festering", 0)) == amount_of("CAP_SHAMBLER", "Spore Cloud"),
		"a Spore Cloud festers the party, and a fresh application survives the tick that follows")
	## A Salamander's Ember sets the party burning; the tick that ends the turn burns.
	var s: Dictionary = setup(["SALAMANDER"])
	s.player.block = 0
	land(s.foe, ["Ember"])
	var ember: Array = turn(s)
	var burn: int = amount_of("SALAMANDER", "Ember")
	check(moves_named(ember, "Ember").size() == 1 and moves_named(ember, "Scratch").is_empty(), "its Ember is not a Scratch")
	var ticks: Array = []
	for event in of(ember, "tick"):
		ticks.append_array(event.ticks.filter(func(t: Dictionary) -> bool: return str(t.kind) == "burn"))
	check(not ticks.is_empty() and int(ticks[0].amount) == burn and int(s.player.statuses.get("burn", 0)) == burn - 1, "an Ember burns for %d, which hurts %d at the turn's end and falls a stack: %s" % [burn, burn, str(ticks)])
	land(s.foe, ["Scratch"])
	var scratch: Array = turn(s)
	check(moves_named(scratch, "Scratch").size() == 1 and int(moves_named(scratch, "Scratch")[0].effects[0].raw) == amount_of("SALAMANDER", "Scratch"), "a Scratch scratches for its number")
	## The Kiln Dragon brings no aura, its breath burns and its lava goes through block.
	var w: Dictionary = setup(["THE_KILN_WYRM"])
	check(not DeepCreatures.traits_for(w.foe).has("aura") and w.player.statuses.is_empty(), "the Kiln Dragon puts nothing on the party just by being there")
	w.foe.statuses.ward = 0
	w.player.block = 0
	land(w.foe, ["Firebreath"])
	var breath: Array = turn(w)
	var fire: int = amount_of("THE_KILN_WYRM", "Firebreath")
	check(moves_named(breath, "Firebreath").size() == 1 and int(w.player.statuses.get("burn", 0)) == fire - 1, "its Firebreath burns the party for %d, and one round has burned: %d left" % [fire, int(w.player.statuses.get("burn", 0))])
	w.player.statuses.erase("burn")
	w.player.block = 30
	land(w.foe, ["Lavafall"])
	var lava: Array = moves_named(turn(w), "Lavafall")
	check(lava.size() == 1 and int(lava[0].effects[0].hp_loss) == amount_of("THE_KILN_WYRM", "Lavafall") and int(lava[0].effects[0].absorbed) == 0,
		"its Lavafall goes through block: %s" % str(lava[0].effects if not lava.is_empty() else []))

func steadfast_and_sturdy() -> void:
	var f: Dictionary = setup(["THE_ANVIL_KNIGHT"])
	f.foe.statuses.ward = 0
	var stunned: Array = apply(f, {"kind": "stun", "target": "enemy", "amount": 3})
	check(int(f.foe.statuses.stun) == 2 and bool(stunned[0].get("steadfast", false)), "Steadfast halves a stun, rounded up: %d" % int(f.foe.statuses.stun))
	var bound: Array = apply(f, {"kind": "die_steal", "target": "enemy", "amount": 1})
	check(int(f.foe.stolen_dice) == 1 and bool(bound[0].get("steadfast", false)), "a single bound die still binds one")
	land(f.foe, ["Quench", "Hammer"])
	var skipped: Array = turn(f)
	check(of(skipped, "skip").size() == 1 and bool(f.foe.stun_guard), "it sits out one action, and will not be stunned straight after")
	var again: Array = apply(f, {"kind": "stun", "target": "enemy", "amount": 2})
	check(bool(again[0].get("resisted", false)) and int(f.foe.statuses.stun) == 1, "a stun on the heels of a stun is shrugged off")
	f.foe.statuses.stun = 0
	turn(f)
	check(not bool(f.foe.stun_guard), "once it has acted it can be stunned again")
	## Sturdy caps a single hit at a share of its health.
	var g: Dictionary = setup(["GEODE_GOLEM"])
	g.foe.max_hp = 100
	g.foe.hp = 100
	g.foe.block = 0
	var capped: Dictionary = hit(g, 60)
	check(int(capped.hp_loss) == 25 and int(capped.get("capped", 0)) == 35, "no single hit takes more than a quarter off a Geode Golem: %s" % str(capped))
	var small: Dictionary = hit(g, 10)
	check(int(small.hp_loss) == 10 and not small.has("capped"), "a smaller hit lands in full")
	land(g.foe, ["Fortify"])
	g.foe.block = 0
	turn(g)
	check(int(g.foe.statuses.get("retain", 0)) >= DeepRules.CEILING and int(g.foe.block) >= amount_of("GEODE_GOLEM", "Fortify"),
		"its Fortify raises %d block and keeps all of it: block %d" % [amount_of("GEODE_GOLEM", "Fortify"), int(g.foe.block)])
	## The Hollow Crown is Sturdy the whole fight.
	var c: Dictionary = setup(["THE_HOLLOW_CROWN"])
	check(DeepCreatures.trait_value(c.foe, "sturdy", 0) == 15, "the Hollow Crown is Sturdy 15%")
	c.foe.hp = int(c.foe.max_hp) / 5
	DeepCreatures.prepare(c.foe)
	check(DeepCreatures.trait_value(c.foe, "sturdy", 0) == 15, "and still is near death")

func backlash_and_damping() -> void:
	## A Riftling Swarm's Static: through the party's next turn every gem that fires costs its
	## owner a point, wherever it sits.
	var rail: Array = []
	for i in range(5):
		rail.append(stone("STRIKE", "strike%d" % i))
	var riders: Array = [[], [], [], [], []]
	for i in range(3):
		riders[4].append(DeepStone.make("STRIKE", 1, 4, 3, ["VOID"], {}, "void%d" % i))
	var f: Dictionary = setup(["RIFTLING_SWARM"], 1, {}, rail, riders)
	land(f.foe, ["Static", "Nibble"])
	f.player.hp = 100
	f.player.max_hp = 100
	var calm: Array = turn(f)
	var nibble: int = amount_of("RIFTLING_SWARM", "Nibble")
	var before_static: Array = of(calm, "gem_fire").filter(func(e: Dictionary) -> bool: return str(e.unit) == "p0")
	check(before_static.size() == 8 and before_static.all(func(e: Dictionary) -> bool: return int(e.get("backlash", 0)) == 0), "before its Static the eight Strikes fire free")
	check(DeepCreatures.has_trait(f.foe, "backlash") and int(f.player.hp) == 100 - nibble, "Static pins Backlash on it for the party's turn; a Nibble hits for %d" % nibble)
	land(f.foe, ["Swarm", "Nibble"])
	var events: Array = turn(f)
	var fired: Array = of(events, "gem_fire").filter(func(e: Dictionary) -> bool: return str(e.unit) == "p0")
	check(fired.size() == 8, "eight Strikes fire: %d" % fired.size())
	check(fired.all(func(e: Dictionary) -> bool: return int(e.get("backlash", 0)) == 1), "every one of them costs its owner a point, wherever it sits")
	check(int(f.player.hp) == 100 - nibble - 8 - nibble, "eight points of Backlash and two Nibbles: hp %d" % int(f.player.hp))
	check(not DeepCreatures.has_trait(f.foe, "backlash"), "the Static wears off as its next action opens")
	check(f.foe.dice.size() == 3, "its Swarm adds another riftling")
	## A Null Shade's Dampen halves the Resonance a rail builds on the party's next turn,
	## carrying the half-points.
	var u: Dictionary = setup(["NULL_SHADE"], 1, {}, rail.slice(0, 3))
	land(u.foe, ["Dampen"])
	var free: Array = turn(u)
	land(u.foe, ["Sip"])
	u.foe.hp = 900
	var damped: Array = turn(u)
	check(int(of(free, "rail_end")[0].resonance) == 5 and int(of(damped, "rail_end")[0].resonance) == 2, "three Strikes ring 5 before a Dampen and 2 under it: %d / %d" % [int(of(free, "rail_end")[0].resonance), int(of(damped, "rail_end")[0].resonance)])
	var sip: Array = moves_named(damped, "Sip")
	check(sip.size() == 1 and int(sip[0].effects[0].get("healed", 0)) == amount_of("NULL_SHADE", "Sip"), "its Sip heals it: %s" % str(sip[0].effects if not sip.is_empty() else []))
	check(not DeepCreatures.has_trait(u.foe, "resonance_damp"), "the Dampen wears off as its next action opens")
	land(u.foe, ["Snuff"])
	var snuff: Array = turn(u)
	check(moves_named(snuff, "Snuff").size() == 1 and u.player.rail.filter(func(x: Variant) -> bool: return x is Dictionary).size() == 2, "its Snuff melts a gem")
	land(u.foe, ["Drain"])
	turn(u)
	check(u.player.rail.filter(func(x: Variant) -> bool: return x is Dictionary).size() == 2, "for the rest of the fight")

func locks_and_dread() -> void:
	## A Seep Eel's Shock locks the highest die into the next hand.
	var f: Dictionary = setup(["SEEP_EEL"])
	land(f.foe, ["Shock"])
	for i in range(f.player.hand.size()):
		f.player.hand[i].value = i + 1
	var shock: Array = turn(f)
	check(moves_named(shock, "Shock").size() == 1, "it shocks")
	var locked: Array = f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("locked", false)))
	check(locked.size() == 1 and int(locked[0].value) == 5 and bool(locked[0].get("locked_by_foe", false)), "the highest die came up again as it was, locked: %s" % str(locked.map(func(r: Dictionary) -> int: return int(r.value))))
	check(not locked.is_empty() and not DeepDice.rerollable(f.player.hand).has(str(locked[0].die_id)), "and it cannot be rerolled")
	land(f.foe, ["Bite"])
	turn(f)
	check(f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("locked", false))).is_empty(), "the lock lasts one turn")
	## Dread on a player: the bowl rolls a size smaller next turn.
	var d: Dictionary = setup(["DROWNED_MINER"])
	land(d.foe, ["Pull Under"])
	var pull: Array = turn(d)
	check(moves_named(pull, "Pull Under").size() == 1, "it pulls under")
	check(d.player.hand.all(func(r: Dictionary) -> bool: return int(r.top) == 4), "the hand after is thrown on d4s: %s" % str(d.player.hand.map(func(r: Dictionary) -> int: return int(r.top))))
	check(not d.player.statuses.has("dread") and d.player.dice.all(func(x: Dictionary) -> bool: return str(x.shape) == "D6"), "the dice themselves are untouched, and the Dread is spent")
	land(d.foe, ["Pick"])
	turn(d)
	check(d.player.hand.all(func(r: Dictionary) -> bool: return int(r.top) == 6), "the turn after rolls d6s again")

func theft_and_flight() -> void:
	## A Gilded Magpie's Snatch takes from the richest player and turns that face to Flee; when
	## the Flee face lands it leaves with everything it took.
	var f: Dictionary = setup(["GILDED_MAGPIE"])
	f.player.gold = 40
	f.player.block = 0
	land(f.foe, ["Snatch"])
	var snatch: Array = turn(f)
	var take: int = amount_of("GILDED_MAGPIE", "Snatch")
	check(moves_named(snatch, "Snatch").size() == 1 and int(f.foe.stolen_gold) == take and pyrite_of(f.player) == 40 - take, "a Gilded Magpie's Snatch takes %d: %d held" % [take, int(f.foe.stolen_gold)])
	check(str(f.foe.dice[0].faces[0].get("move", "")) == "Flee", "the face it landed is Flee now")
	var gone: Array = turn(f)
	check(moves_named(gone, "Flee").size() == 1 and bool(f.foe.fled) and int(f.foe.hp) == 0 and str(f.state.outcome) == "victory", "the next time that face lands it is gone, and the room is clear")
	check(pyrite_of(f.player) == 40 - take and int(f.foe.stolen_gold) == take, "what it stole went with it: %d held, %d left" % [int(f.foe.stolen_gold), pyrite_of(f.player)])
	## Every Magpie snatches, and every Snatch turns into a Flee.
	for key in ["MAGPIE", "GLINT_MAGPIE", "GILDED_MAGPIE"]:
		var moves: Array = DeepContent.creature(key).moves
		var etch: Array = DeepCreatures.move_in(moves, "Snatch").get("effects", []).filter(func(e: Dictionary) -> bool: return str(e.kind) == "etch")
		var flee: Dictionary = DeepCreatures.move_in(moves, "Flee")
		check(etch.size() == 1 and str(etch[0].get("from", "")) == "self_face" and str(etch[0].get("to", "")) == "Flee" and str(flee.effects[0].kind) == "flee", "%s's Snatch becomes a Flee" % key)
	## A Lamprey Knot's Drink heals it and its Bite bites.
	var l: Dictionary = setup(["LAMPREY_KNOT"])
	l.foe.hp = 900
	land(l.foe, ["Drink", "Drink", "Bite"])
	var drink: Array = turn(l)
	var sip: int = amount_of("LAMPREY_KNOT", "Drink")
	check(moves_named(drink, "Drink").size() == 2 and int(l.foe.hp) == 900 + 2 * sip, "two Drinks heal %d each: hp %d" % [sip, int(l.foe.hp)])
	check(moves_named(drink, "Bite").map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [amount_of("LAMPREY_KNOT", "Bite")], "its Bite bites for its number")
	check(int(l.foe.stolen_gold) == 0, "and it drinks no pyrite")
	## The Assayer's Tax is a tenth of each purse, and each player is hit for what it took.
	var a: Dictionary = setup(["THE_ASSAYER"], 2)
	a.state.players[0].ore = 100
	a.state.players[1].ore = 40
	for unit in a.state.players:
		unit.block = 0
	land(a.foe, ["Tax", "Balance"])
	var tax: Array = turn(a)
	check(moves_named(tax, "Tax").size() == 1 and int(a.foe.stolen_gold) == 14, "a tenth of 100 and of 40 is 14: %d" % int(a.foe.stolen_gold))
	check(int(a.state.players[0].hp) == 990 and int(a.state.players[1].hp) == 996, "each is hit for what was taken from them: %d / %d" % [int(a.state.players[0].hp), int(a.state.players[1].hp)])
	check(moves_named(tax, "Balance").size() == 1 and int(a.foe.statuses.get("spikes", 0)) == amount_of("THE_ASSAYER", "Balance", 1) and int(a.foe.block) >= amount_of("THE_ASSAYER", "Balance"),
		"Balance shields it and raises its spikes: %d block, %d spikes" % [int(a.foe.block), int(a.foe.statuses.get("spikes", 0))])
	## Its Eat the Rich heals and grows it a hundredth of its health for every 10 pyrite the
	## richest player holds; the spikes come down as that action opens.
	var rich: int = pyrite_of(a.state.players[0])
	var most: int = int(a.foe.max_hp)
	land(a.foe, ["Eat the Rich", "Weigh"])
	var eat: Array = turn(a)
	var grew: int = most * (rich / 10) / 100
	check(moves_named(eat, "Eat the Rich").size() == 1 and int(a.foe.max_hp) == most + grew, "Eat the Rich grows it by %d%% (%d): %d" % [rich / 10, grew, int(a.foe.max_hp)])
	check(moves_named(eat, "Weigh").size() == 1 and int(a.foe.statuses.get("spikes", 0)) == 0, "its Weigh hits, and Balance's spikes stood only until this action")
	## Raise the Rate turns every Tax face on its ledger to Heavy Tax, a fifth of each purse.
	var r: Dictionary = setup(["THE_ASSAYER"], 1)
	r.player.ore = 100
	r.player.block = 0
	var taxes: int = faces_of(r.foe, "Tax")
	force_faces(r.foe, 0, "Raise the Rate")
	r.player.statuses.stun = 1
	var rate: Array = turn(r)
	check(moves_named(rate, "Raise the Rate").size() >= 1 and faces_of(r.foe, "Tax") == 0 and faces_of(r.foe, "Heavy Tax") == taxes, "Raise the Rate turns all %d Tax faces to Heavy Tax" % taxes)
	land(r.foe, ["Heavy Tax"])
	r.player.ore = 100
	r.player.gold = 0
	r.player.pyrite_delta = 0
	r.player.statuses.stun = 1
	var heavy_tax: Array = moves_named(turn(r), "Heavy Tax")
	check(heavy_tax.size() == 1 and int(heavy_tax[0].effects[0].get("stolen", 0)) == 20, "a Heavy Tax takes a fifth of 100: %s" % str(heavy_tax[0].effects if not heavy_tax.is_empty() else []))
	## While it stands no gem counts for more than five carats.
	var heavy: Dictionary = setup(["THE_ASSAYER"], 1, {}, [stone("STRIKE", "heavy", 12)])
	var ctx: Dictionary = DeepBattle.rail_context(heavy.state, heavy.player, 0)
	check(int(ctx.carat_cap) == 5 and int(DeepStone.effective(heavy.player.rail[0], ctx).carat) == 5, "a 12-carat Strike counts as 5 while the Assayer stands")
	heavy.foe.hp = 0
	check(int(DeepStone.effective(heavy.player.rail[0], DeepBattle.rail_context(heavy.state, heavy.player, 0)).carat) == 12, "and as 12 once it is dead")

func gems_held_and_buried() -> void:
	var rail: Array = [stone("STRIKE", "a", 2), stone("GUARD", "b", 9), stone("STRIKE", "c", 4)]
	var f: Dictionary = setup(["HOARD_MIMIC"], 1, {}, rail)
	f.foe.block = 0
	hit(f, 5, ["RED"], 0)
	hit(f, 9, ["RED"], 2)
	hit(f, 2, ["RED"], 0)
	check(str(f.foe.hardest_gem.get("stone_id", "")) == "c", "it remembers the gem that hit it hardest")
	land(f.foe, ["Gulp"])
	f.player.statuses.stun = 1
	var gulp: Array = turn(f)
	check(moves_named(gulp, "Gulp").size() == 1 and f.foe.held_gems.size() == 1 and f.player.rail[2] == null, "its Gulp swallows that gem off the rail")
	check(not moves_named(gulp, "Gulp").is_empty() and str(moves_named(gulp, "Gulp")[0].effects[0].held.stone_id) == "c", "the move says which")
	var killed: Dictionary = hit(f, 9999, ["RED"], 0)
	check(f.player.rail[2] is Dictionary and str(f.player.rail[2].id) == "c" and not killed.get("returned_gems", []).is_empty(), "killing the Mimic puts the gem back")
	check(int(f.player.raw_drops) == 1 and bool(killed.get("raw_drop", false)), "and it drops a raw stone for the killer")
	## The Collector walks in with a Strike and a Bulwark of its own, its Acquire takes a gem it
	## can use, and its Exhibit fires everything it holds.
	var c: Dictionary = setup(["THE_COLLECTOR"], 1, {}, rail)
	check(c.foe.held_gems.map(func(h: Dictionary) -> String: return str(h.stone.skill)) == ["STRIKE", "BULWARK"], "the Collector comes holding a Strike and a Bulwark")
	land(c.foe, ["Acquire"])
	c.player.statuses.stun = 1
	var take: Array = turn(c)
	check(moves_named(take, "Acquire").size() == 1 and c.foe.held_gems.size() == 3 and c.player.rail[1] == null, "Acquire takes the nine-carat Guard, a gem it can use")
	land(c.foe, ["Exhibit"])
	c.player.statuses.stun = 1
	c.player.block = 0
	var had: int = int(c.player.hp)
	var show: Array = turn(c)
	var exhibit: Array = moves_named(show, "Exhibit")
	var kinds: Array = exhibit[0].effects.map(func(e: Dictionary) -> String: return str(e.kind)) if not exhibit.is_empty() else []
	check(exhibit.size() == 1 and kinds.count("damage") == 1 and kinds.count("block") == 2, "Exhibit fires the Strike, the Bulwark and the Guard it holds: %s" % str(kinds))
	check(int(c.player.hp) < had and int(c.foe.block) > 0, "the Strike hurts the party and the blocks are the Collector's")
	var returned: Dictionary = hit(c, 9999, ["RED"], 0)
	check(c.player.rail[1] is Dictionary and str(c.player.rail[1].id) == "b" and returned.get("returned_gems", []).size() == 1, "killing it gives back only what it took")
	var lone: Dictionary = setup(["THE_COLLECTOR"], 1, {}, [stone("STRIKE", "only")])
	land(lone.foe, ["Acquire"])
	lone.player.statuses.stun = 1
	var spared: Array = moves_named(turn(lone), "Acquire")
	check(not spared.is_empty() and bool(spared[0].effects[0].get("nothing", false)) and lone.player.rail[0] is Dictionary, "it will not take a rail's only gem")
	## An Entropy Eye's Unmake destroys a die for the fight; it buries no sockets.
	var e: Dictionary = setup(["ENTROPY_EYE"], 1, {}, rail)
	land(e.foe, ["Unmake", "Gaze"])
	e.player.statuses.stun = 1
	var first: Array = turn(e)
	check(moves_named(first, "Unmake").size() == 1 and not moves_named(first, "Gaze").is_empty() and int(moves_named(first, "Gaze")[0].effects[0].raw) == amount_of("ENTROPY_EYE", "Gaze")
		and e.player.dice.size() == 4, "Unmake destroys a die, and the Gaze hits for its number")
	check(e.player.buried.is_empty() and DeepContent.creature("ENTROPY_EYE").moves.all(func(m: Dictionary) -> bool: return m.effects.all(func(x: Dictionary) -> bool: return str(x.kind) != "bury_socket")),
		"it buries nothing: burying is the Foreman's")
	var again: Dictionary = DeepBattle._apply(e.state, e.foe, {"kind": "bury_socket", "target": "heroes", "amount": 1, "pick": "heaviest"}, e.rng.dice)[0]
	check(int(again.get("socket", -1)) == 1 and e.player.buried.has(1), "a bury_socket still finds the nine-carat Guard's socket")
	land(e.foe, ["Unmake"])
	e.player.statuses.stun = 1
	var unmake: Array = turn(e)
	check(moves_named(unmake, "Unmake").size() == 1 and e.player.dice.size() == 3, "a second Unmake destroys another")
	land(e.foe, ["Stare"])
	turn(e)
	check(e.player.dice.size() == 3 and e.player.hand.size() == 3, "they stay gone for the fight")
	check(DeepBattle.dice_after_fight(e.player).size() == 5, "and are back when the fight is over")
	## A die broken this turn (a Glass die that shattered) grows back at the start of the next;
	## a fight that ends before then gives it back all the same.
	var shattered: Dictionary = e.player.dice[0]
	check(DeepBattle.break_die(e.state, e.player, str(shattered.id), "shattered") and e.player.dice.size() == 2, "a shattered die leaves the bowl")
	var after: Array = DeepBattle.dice_after_fight(e.player)
	check(after.size() == 5 and after.any(func(d: Dictionary) -> bool: return str(d.id) == str(shattered.id)), "and is back when the fight ends before the next turn")

func bursts_and_swelling() -> void:
	var f: Dictionary = setup(["PUFFBALL"])
	var puff: Dictionary = DeepContent.creature("PUFFBALL")
	check(int(puff.hp) == 30 and puff.dice.size() == 1 and str(puff.dice[0].shape) == "D4", "the Puffball has 30 health and a d4")
	land(f.foe, ["Swell"])
	turn(f)
	turn(f)
	var swell: int = amount_of("PUFFBALL", "Swell")
	check(int(f.foe.swell) == 2 * swell, "each Swell swells it by %d: %d" % [swell, int(f.foe.swell)])
	land(f.foe, ["Bloat"])
	f.foe.hp = 900
	var tallest: int = int(f.foe.max_hp)
	turn(f)
	var bloat: int = amount_of("PUFFBALL", "Bloat")
	check(int(f.foe.swell) == 2 * swell and int(f.foe.max_hp) == tallest + amount_of("PUFFBALL", "Bloat", 1) and int(f.foe.hp) == 900 + bloat + amount_of("PUFFBALL", "Bloat", 1)
		and int(f.foe.statuses.get("regeneration", 0)) == 0, "Bloat heals it and grows it, swells nothing and does not regenerate: %d / %d" % [int(f.foe.hp), int(f.foe.max_hp)])
	f.foe.block = 0
	var killed: Dictionary = hit(f, 9999)
	check(int(f.player.statuses.get("poison", 0)) == 2 * swell and not killed.get("deathburst", []).is_empty() and killed.deathburst[0].move == "Burst", "its burst poisons the party for its swelling")
	var s: Dictionary = setup(["SPORE_SLIME"])
	s.foe.statuses.poison = 999
	s.foe.hp = 1
	var tick: Dictionary = DeepBattle._poison_tick(s.state, s.foe)
	check(bool(tick.get("killed", false)) and int(s.player.statuses.get("poison", 0)) == 0, "a Spore Slime does not burst: bursting is the Puffball's")
	var big: Dictionary = setup(["SPORE_SLIME"])
	big.foe.block = 0
	var struck: Dictionary = hit(big, int(big.foe.max_hp) / 2)
	check(struck.has("split") and big.state.enemies.size() == 2, "it splits when struck hard, like every slime")
	var ooze: Dictionary = setup(["SPORE_SLIME"])
	land(ooze.foe, ["Ooze", "Spores"])
	var oozed: Array = turn(ooze)
	var ooze_kinds: Array = moves_named(oozed, "Ooze")[0].effects.map(func(e: Dictionary) -> String: return str(e.kind)) if not moves_named(oozed, "Ooze").is_empty() else []
	var spore_kinds: Array = moves_named(oozed, "Spores")[0].effects.map(func(e: Dictionary) -> String: return str(e.kind)) if not moves_named(oozed, "Spores").is_empty() else []
	check(ooze_kinds == ["damage"] and spore_kinds == ["poison"], "a Spore Slime's Ooze hits and its Spores poison: %s / %s" % [str(ooze_kinds), str(spore_kinds)])
	## A Mycel Weaver's Fangs poison for whatever gets past block.
	var weaver: Dictionary = setup(["MYCEL_WEAVER"])
	weaver.player.block = 3
	land(weaver.foe, ["Fangs"])
	var fangs: Array = moves_named(turn(weaver), "Fangs")
	var bites: Array = fangs[0].effects if not fangs.is_empty() else []
	check(bites.size() == 2 and int(bites[0].hp_loss) == 0 and not bites[0].has("envenomed") and int(bites[1].hp_loss) == 1 and int(bites[1].get("envenomed", {}).get("amount", 0)) == 1,
		"Fangs of 2 and 2 against 3 block: the first is soaked, the second gets 1 through and poisons for 1: %s" % str(bites))
	## A Root Horror's Feed heals and grows it; its Thicken makes it stronger.
	var r: Dictionary = setup(["ROOT_HORROR"])
	land(r.foe, ["Feed", "Thicken"])
	var fed: Array = turn(r)
	var grow: int = amount_of("ROOT_HORROR", "Feed", 1)
	check(moves_named(fed, "Feed").size() == 1 and int(r.foe.max_hp) == 1000 + grow and int(r.foe.hp) == 1000 + grow and int(r.foe.statuses.get("strength", 0)) == 1,
		"Feed grows it by %d and Thicken gives it 1 Strength: %d / %s" % [grow, int(r.foe.max_hp), str(r.foe.statuses)])
	## The Spore Mother: Spore and Rot together bloom, and Shed throws off what ails her.
	var m: Dictionary = setup(["THE_SPORE_MOTHER"])
	m.player.statuses.stun = 1
	land(m.foe, ["Spore", "Rot"])
	var bloom: Array = turn(m)
	var spore: int = amount_of("THE_SPORE_MOTHER", "Spore")
	check(moves_named(bloom, "Spore").size() == 1 and moves_named(bloom, "Rot").size() == 1 and moves_named(bloom, "Bloom").size() == 1, "Spore and Rot together bloom")
	var bitten: Array = []
	for name in ["Rot", "Bloom"]:
		for event in moves_named(bloom, name):
			for result in event.effects:
				bitten.append_array(result.get("ticks", []).map(func(t: Dictionary) -> int: return int(t.get("amount", 0))))
	check(bitten == [spore, spore - 1], "her Rot and her Bloom each make the Poison her Spore laid bite at once: %s" % str(bitten))
	m.foe.statuses.poison = 9
	m.foe.statuses.curse = 3
	m.foe.hp = 900
	land(m.foe, ["Shed"])
	m.player.statuses.stun = 1
	turn(m)
	check(int(m.foe.statuses.get("poison", 0)) == 0 and int(m.foe.statuses.get("curse", 0)) == 0 and int(m.foe.hp) == 900 + amount_of("THE_SPORE_MOTHER", "Shed", 1),
		"Shed throws off her poison and her curse and heals her: %s, hp %d" % [str(m.foe.statuses), int(m.foe.hp)])
	land(m.foe, ["Brood", "Choke"])
	m.player.statuses.stun = 1
	var brood: Array = turn(m)
	check(moves_named(brood, "Brood").size() == 1 and m.state.enemies.any(func(e: Dictionary) -> bool: return str(e.key) == "SPORE_SLIME") and int(m.player.statuses.get("festering", 0)) == amount_of("THE_SPORE_MOTHER", "Choke"),
		"Brood calls a Spore Slime and Choke festers the party")
	var h: Dictionary = setup(["THE_HEARTROT"])
	land(h.foe, ["Miasma"])
	turn(h)
	check(h.state.enemies.size() == 4 and int(h.player.statuses.get("festering", 0)) >= 1, "its tendrils came with it, and its Miasma festers the party")

func charge_and_release() -> void:
	## The Prismarch's Gather Light: it takes half until it acts again, then throws everything
	## it was dealt back at every player.
	var f: Dictionary = setup(["THE_PRISMARCH"])
	for escort in escorts_of(f):
		escort.hp = 0
	land(f.foe, ["Gather Light"])
	var gather: Array = turn(f)
	check(moves_named(gather, "Gather Light").size() == 1 and DeepCreatures.charge_turns(f.foe) == 1, "Gather Light winds it up for an action")
	f.foe.block = 0
	var guarded: Dictionary = hit(f, 40)
	check(int(guarded.hp_loss) == 20 and bool(guarded.get("guarded", false)), "while it gathers it takes half: %d" % int(guarded.hp_loss))
	f.player.block = 0
	land(f.foe, ["Brilliance"])
	var loose: Array = turn(f)
	var release: Array = of(loose, "enemy_move").filter(func(e: Dictionary) -> bool: return bool(e.get("release", false)))
	check(release.size() == 1 and int(release[0].effects[0].hp_loss) == 40, "then it throws the whole 40 back: %s" % str(release[0].effects if not release.is_empty() else []))
	check(DeepCreatures.charge_turns(f.foe) == 0 and moves_named(loose, "Gather Light").is_empty() and int(f.foe.statuses.get("strength", 0)) == 1, "the charge is spent, and its Brilliance makes it stronger")
	## Its Lancet goes through block at every player.
	var l: Dictionary = setup(["THE_PRISMARCH"], 2)
	for escort in escorts_of(l):
		escort.hp = 0
	for unit in l.state.players:
		unit.block = 30
	land(l.foe, ["Lancet"])
	var lancet: Array = moves_named(turn(l), "Lancet")
	check(lancet.size() == 1 and lancet[0].effects.size() == 2 and lancet[0].effects.all(func(e: Dictionary) -> bool: return int(e.absorbed) == 0 and int(e.hp_loss) == amount_of("THE_PRISMARCH", "Lancet")),
		"its Lancet hits every player through block: %s" % str(lancet[0].effects if not lancet.is_empty() else []))

func strength_heads_and_empowerment() -> void:
	## A Slag Hound's Howl makes every creature stronger, for the fight.
	var f: Dictionary = setup(["SLAG_HOUND", "FORGE_IMP"])
	var imp: Dictionary = f.state.enemies[1]
	land(f.foe, ["Howl"])
	land(imp, ["Cackle"])
	var howl: Array = turn(f)
	check(moves_named(howl, "Howl").size() == 1, "it howls")
	check(int(f.foe.statuses.get("strength", 0)) == 1 and int(imp.statuses.get("strength", 0)) == 1, "the howl makes every creature stronger")
	var cackles: Array = moves_named(howl, "Cackle")
	check(cackles.size() == 1 and cackles.all(func(e: Dictionary) -> bool: return str(e.effects[0].kind) == "burn"), "the imp's Cackle sets the party burning")
	land(f.foe, ["Maul", "Maul"])
	land(imp, ["Hammer"])
	f.player.block = 50
	var later: Array = turn(f)
	var maul: Array = moves_named(later, "Maul")
	var maul_hit: int = amount_of("SLAG_HOUND", "Maul")
	check(maul.size() == 2 and maul.all(func(e: Dictionary) -> bool: return bool(e.effects[0].get("piercing", false)) and int(e.effects[0].absorbed) == 0), "Maul ignores block")
	check(maul.map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [maul_hit + 1, maul_hit + 1], "the Strength lasts: every Maul hits 1 harder")
	check(moves_named(later, "Hammer").map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [amount_of("FORGE_IMP", "Hammer") + 1], "and the imp's Hammer too")
	## A Croupier Crab's Double doubles its next attack.
	var c: Dictionary = setup(["CROUPIER_CRAB"])
	c.player.block = 0
	land(c.foe, ["Double"])
	turn(c)
	check(int(c.foe.empowered) == 100, "Double empowers the next attack")
	land(c.foe, ["Jackpot"])
	var next: Array = turn(c)
	var jackpot: int = amount_of("CROUPIER_CRAB", "Jackpot")
	check(not moves_named(next, "Jackpot").is_empty() and int(moves_named(next, "Jackpot")[0].effects[0].raw) == 2 * jackpot and int(c.foe.empowered) == 0,
		"the next Jackpot is doubled (%d to %d) and the empowerment spent" % [jackpot, 2 * jackpot])
	c.player.gold = 0
	land(c.foe, ["Fold"])
	var fold: Array = turn(c)
	check(moves_named(fold, "Fold").size() == 1 and int(c.player.gold) == amount_of("CROUPIER_CRAB", "Fold"), "Fold does nothing but drop pyrite: %d" % int(c.player.gold))
	## The Anvil Knight: Quench is Strength 2, Bulwark a wall that hits back and is kept, and
	## Temper turns a Hammer face on its hammer into a Smite.
	var k: Dictionary = setup(["THE_ANVIL_KNIGHT"])
	k.foe.block = 0
	land(k.foe, ["Quench", "Bulwark"])
	var temper: Array = turn(k)
	check(moves_named(temper, "Quench").size() == 1 and int(k.foe.statuses.get("strength", 0)) == 2, "Quench makes it Strength 2")
	check(moves_named(temper, "Bulwark").size() == 1 and int(k.foe.block) >= amount_of("THE_ANVIL_KNIGHT", "Bulwark") and int(k.foe.statuses.get("spikes", 0)) == amount_of("THE_ANVIL_KNIGHT", "Bulwark", 1)
		and int(k.foe.statuses.get("retain", 0)) >= DeepRules.CEILING, "Bulwark raises a wall that hits back, and keeps it: %d block" % int(k.foe.block))
	land(k.foe, ["Hammer", "Smite"])
	var hammer: Array = turn(k)
	check(moves_named(hammer, "Hammer").map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [amount_of("THE_ANVIL_KNIGHT", "Hammer") + 2]
		and moves_named(hammer, "Smite").map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [amount_of("THE_ANVIL_KNIGHT", "Smite") + 2], "and every blow after hits 2 harder")
	check(int(k.foe.statuses.get("spikes", 0)) == 0, "the Bulwark's spikes came down as that action opened")
	var t: Dictionary = setup(["THE_ANVIL_KNIGHT"])
	var smites: int = faces_of(t.foe, "Smite", 1)
	force_faces(t.foe, 0, "Temper")
	t.player.statuses.stun = 1
	turn(t)
	check(faces_of(t.foe, "Smite", 1) == smites + 1 and faces_of(t.foe, "Smite") == smites + 1, "Temper turns one Hammer face on the hammer into a Smite")

func the_refractor_feeds_on_colour() -> void:
	## A Refractor sharpens itself rather than feeding on the colours the party fires.
	var f: Dictionary = setup(["REFRACTOR"], 1, {}, [stone("STRIKE", "red"), stone("RIPOSTE", "blue"), stone("STRIKE", "red2")])
	f.player.block = 0
	land(f.foe, ["Sharpen", "Split Light"])
	var events: Array = turn(f)
	var fed: Array = []
	for event in of(events, "gem_fire"):
		fed.append_array(event.get("fed", []))
	check(fed.is_empty() and int(f.foe.statuses.get("strength", 0)) == 1, "the colours it sees fire feed it nothing; its Sharpen makes it 1 stronger: %s" % str(fed))
	var split: Array = moves_named(events, "Split Light")
	var shard: int = amount_of("REFRACTOR", "Split Light")
	check(split.size() == 1 and split[0].effects.size() == 4 and split[0].effects.all(func(e: Dictionary) -> bool: return int(e.raw) == shard + 1),
		"Split Light is four hits of %d + its Strength: %s" % [shard, str(split[0].effects.map(func(e: Dictionary) -> int: return int(e.raw)) if not split.is_empty() else [])])

func dice_for_the_fight_and_for_good() -> void:
	## A Forge Imp's Heat Treat shrinks a die for the fight; it is itself again after.
	var f: Dictionary = setup(["FORGE_IMP"])
	land(f.foe, ["Heat Treat"])
	turn(f)
	check(shapes(f.player.dice).count("D4") == 1, "Heat Treat shrinks one of the five dice: %s" % str(shapes(f.player.dice)))
	check(shapes(DeepBattle.dice_after_fight(f.player)) == ["D6", "D6", "D6", "D6", "D6"], "and the fight gives it back")
	## The Infinite Void's Dread shrinks every die for the fight.
	var v: Dictionary = setup(["THE_UNMADE"])
	land(v.foe, ["Dread"])
	turn(v)
	check(shapes(v.player.dice) == ["D4", "D4", "D4", "D4", "D4"], "its Dread shrinks every die")
	check(shapes(DeepBattle.dice_after_fight(v.player)) == ["D6", "D6", "D6", "D6", "D6"], "for the fight only")
	## The Smelter's Melt burns the face a die shows blank for the fight.
	var s: Dictionary = setup(["THE_SMELTER"])
	s.foe.statuses.ward = 0
	land(s.foe, ["Melt"])
	var melt: Array = turn(s)
	var blanks: Callable = func(dice: Array) -> int:
		var count: int = 0
		for die in dice:
			count += die.faces.filter(func(x: Dictionary) -> bool: return str(x.get("kind", "plain")) == "blank").size()
		return count
	check(moves_named(melt, "Melt").size() == 1 and int(blanks.call(s.player.dice)) == 1, "Melt burns one showing face blank")
	check(int(blanks.call(DeepBattle.dice_after_fight(s.player))) == 0, "and the fight gives it back")
	## The Glazier's Cut takes a point off every face the party's dice show, for good; the
	## Gardener's Prune the same, for the fight.
	for spec in [["THE_GLAZIER", "Cut", true], ["THE_GARDENER", "Prune", false]]:
		var p: Dictionary = setup([str(spec[0])])
		p.foe.statuses.ward = 0
		land(p.foe, [spec[1]])
		var showing: Dictionary = {}
		for roll in p.player.hand:
			for die in p.player.dice:
				if str(die.id) == str(roll.die_id):
					showing[str(die.id)] = [int(roll.face), int(die.faces[int(roll.face)].value)]
		var prune: Array = turn(p)
		check(moves_named(prune, str(spec[1])).size() == 1, "%s's %s lands" % spec.slice(0, 2))
		var ground: bool = true
		for die in p.player.dice:
			var was: Array = showing.get(str(die.id), [0, 1])
			if int(die.faces[int(was[0])].value) != maxi(1, int(was[1]) - 1):
				ground = false
		check(ground and p.player.dice.size() == 5, "%s: every face that was showing lost a point" % spec[1])
		var kept: Array = DeepBattle.dice_after_fight(p.player)
		var still: bool = true
		var restored: bool = true
		for die in kept:
			var was: Array = showing.get(str(die.id), [0, 1])
			if int(die.faces[int(was[0])].value) != maxi(1, int(was[1]) - 1):
				still = false
			if int(die.faces[int(was[0])].value) != int(was[1]):
				restored = false
		check(kept.size() == 5 and (still if bool(spec[2]) else restored), "%s %s" % [spec[1], "keeps them lost after the fight" if bool(spec[2]) else "gives them back after the fight"])

func echoes_and_the_remembered() -> void:
	var f: Dictionary = setup(["VOID_ECHO"], 1, {"tough": false})
	check(not str(f.foe.echo_of).is_empty() and str(f.foe.echo_of) != "VOID_ECHO", "a Void Echo copies another creature: %s" % str(f.foe.echo_of))
	var source: Dictionary = DeepContent.creature(str(f.foe.echo_of))
	check(not bool(source.get("warden", false)) and f.foe.dice.size() == source.dice.size() and f.foe.moves.size() == source.moves.size() + 1
		and not DeepCreatures.move_in(f.foe.moves, "Echo Anew").is_empty(), "its dice and moves are the original's, and Echo Anew besides")
	check(not f.foe.dice.is_empty() and str(f.foe.dice[0].faces[0].get("move", "")) == "Echo Anew", "one face of its first die is Echo Anew")
	check(str(f.foe.name).begins_with("Void Echo (") and int(f.foe.max_hp) == int(source.hp), "named for what it echoes, with its health")
	var allowed: Array = []
	for mine_key in ["QUARRY", "SEEPS", "GLASS_VEINS", "WARRENS"]:
		for band in DeepContent.mine(mine_key).bands:
			allowed.append_array(band.creatures.keys())
	check(allowed.has(str(f.foe.echo_of)), "it echoes something from the first four mines")
	var r: Dictionary = setup(["THE_DRILL"], 1, {"remembered": true, "extra_trait": "sturdy", "warden": true})
	check(str(r.foe.name) == "The Remembered The Drill" and DeepCreatures.trait_value(r.foe, "sturdy", 0) == 25 and str(r.foe.remembered) == "sturdy", "a Rift Warden is a boss remembered with one trait more")
	var s: Dictionary = setup(["THE_HOLLOW_CROWN"], 1, {"remembered": true, "extra_trait": "steadfast", "warden": true})
	check(DeepCreatures.has_trait(s.foe, "steadfast") and DeepCreatures.trait_value(s.foe, "sturdy", 0) == 15, "a remembered trait sits beside its own")
	check(DeepContent.REMEMBERED_TRAITS == ["steadfast", "sturdy", "split_on_big_hit"], "the Remembered are Steadfast, Sturdy or Splitting")
	var split: Dictionary = setup(["THE_DRILL"], 1, {"remembered": true, "extra_trait": "split_on_big_hit", "warden": true})
	split.foe.block = 0
	var halved: Dictionary = hit(split, 450)
	check(not str(halved.get("split", "")).is_empty() and DeepBattle.living(split.state.enemies).size() == 2, "a remembered boss that splits breaks in two under a big blow")
	## The Infinite Void throws a d12, and its Expand grows another, five at most.
	var u: Dictionary = setup(["THE_UNMADE"])
	check(str(u.foe.name) == "The Infinite Void" and u.foe.dice.size() == 1 and str(u.foe.dice[0].shape) == "D12" and DeepCreatures.is_face_die(u.foe.dice[0]), "the Infinite Void throws one d12")
	force_faces(u.foe, 0, "Expand")
	var first: Array = turn(u)
	check(moves_named(first, "Expand").size() == 1 and u.foe.dice.size() == 2 and of(first, "enemy_roll").size() == 1 and DeepCreatures.is_face_die(u.foe.dice[1]),
		"its first Expand grows another d12 action die, which first throws next action")
	if u.foe.dice.size() > 1:
		force_faces(u.foe, 1, "Consume")
	var second: Array = turn(u)
	check(u.foe.dice.size() == 3 and of(second, "enemy_roll").size() == 2, "its second action throws two")
	check(DeepCreatures.has_trait(u.foe, "sturdy") and not DeepCreatures.has_trait(u.foe, "backlash") and not DeepCreatures.has_trait(u.foe, "rising"), "Sturdy, and neither Backlash nor Rising")
	for _i in range(4):
		for d in range(1, u.foe.dice.size()):
			force_faces(u.foe, d, "Consume")
		turn(u)
	check(u.foe.dice.size() == 5, "five d12s at most: %d" % u.foe.dice.size())

func the_hollow_crown() -> void:
	var f: Dictionary = setup(["THE_HOLLOW_CROWN"])
	f.foe.statuses.ward = 0
	check(f.foe.dice.size() == 1 and str(f.foe.dice[0].shape) == "D6", "the Hollow Crown throws one d6")
	## Stumble ends its action there.
	land(f.foe, ["Stumble", "Crush"])
	var stumble: Array = turn(f)
	check(moves_named(stumble, "Stumble").size() == 1 and moves_named(stumble, "Crush").is_empty() and of(stumble, "enemy_roll").size() == 1, "Stumble ends its action: nothing else happens")
	check(int(f.foe.statuses.get("stun", 0)) == 0, "and it does not lose its next action for it")
	land(f.foe, ["Crush", "Bulwark"])
	f.foe.block = 0
	f.player.block = 0
	var crush: Array = turn(f)
	check(moves_named(crush, "Crush").size() == 1 and int(moves_named(crush, "Crush")[0].effects[0].raw) == amount_of("THE_HOLLOW_CROWN", "Crush")
		and int(f.foe.block) >= amount_of("THE_HOLLOW_CROWN", "Bulwark") and int(f.foe.statuses.get("retain", 0)) >= DeepRules.CEILING, "Crush hits for its number and Bulwark raises block it keeps")
	## Crowned heals it and doubles whichever attack lands next: a Topple of 20 hits for 40.
	land(f.foe, ["Crowned"])
	f.foe.hp = 500
	turn(f)
	check(int(f.foe.hp) == 500 + amount_of("THE_HOLLOW_CROWN", "Crowned") and int(f.foe.empowered) == 100, "Crowned heals it and empowers its next attack")
	land(f.foe, ["Topple"])
	f.player.block = 0
	var topple: Array = moves_named(turn(f), "Topple")
	check(not topple.is_empty() and int(topple[0].effects[0].raw) == 2 * amount_of("THE_HOLLOW_CROWN", "Topple") and int(f.foe.empowered) == 0, "a crowned Topple hits twice as hard")
	## Its Summon face (a Rise grows one) calls two Gilded Magpies at once, either side of it.
	land(f.foe, ["Summon"])
	var called: Array = turn(f)
	check(moves_named(called, "Summon").size() == 1 and DeepBattle.living(f.state.enemies).size() == 3, "Summon calls two Gilded Magpies at once: %d standing" % DeepBattle.living(f.state.enemies).size())
	var standing: Array = DeepBattle.living(f.state.enemies)
	check(standing.filter(func(e: Dictionary) -> bool: return str(e.key) == "GILDED_MAGPIE").size() == 2, "and they are Gilded Magpies")
	check(standing.size() == 3 and standing[1] == f.foe, "one on either side of the boss that called them")

func a_bosss_brood_runs() -> void:
	## A Warden's death ends its brood's fight too (playtest R59): what it called, what those
	## called, and its escorts run; a creature that came in on its own stays.
	var f: Dictionary = setup(["THE_DRILL", "CAVE_TICK"])
	var rats: Array = DeepBattle.summon(f.state, f.foe, "RAIL_RAT", 1, f.rng.creatures)
	var pup: Array = DeepBattle.summon(f.state, DeepBattle.enemy(f.state, str(rats[0])), "RAIL_RAT", 1, f.rng.creatures) if not rats.is_empty() else []
	var tick: Dictionary = f.state.enemies.filter(func(e: Dictionary) -> bool: return str(e.key) == "CAVE_TICK")[0]
	check(rats.size() == 1 and pup.size() == 1, "the Drill calls a rat and the rat calls another")
	if rats.is_empty() or pup.is_empty():
		return
	## A rat dying routs nothing: only a Warden's death does.
	var first: Dictionary = DeepBattle.enemy(f.state, str(rats[0]))
	first.block = 0
	var rat_down: Dictionary = DeepBattle._damage(f.state, f.player, first, 9999, f.rng.dice)
	check(bool(rat_down.get("killed", false)) and not rat_down.has("routed") and int(DeepBattle.enemy(f.state, str(pup[0])).hp) > 0, "a rat's death leaves the rat it called standing")
	f.foe.statuses.ward = 0
	f.foe.block = 0
	f.foe.hp = 5
	var blow: Dictionary = hit(f, 50)
	var routed: Array = blow.get("routed", []).map(func(e: Dictionary) -> String: return str(e.unit))
	check(bool(blow.get("killed", false)) and routed == [str(pup[0])], "the Drill's death routs the rat its dead rat called: %s" % str(routed))
	var runner: Dictionary = DeepBattle.enemy(f.state, str(pup[0]))
	check(bool(runner.fled) and int(runner.hp) == 0 and not bool(first.get("fled", false)), "it flees rather than dies; the rat already dead stays dead")
	check(int(tick.hp) > 0 and not bool(tick.get("fled", false)) and str(f.state.outcome).is_empty(), "a creature that came in on its own stays, and the fight goes on")
	tick.block = 0
	DeepBattle._damage(f.state, f.player, tick, 9999, f.rng.dice)
	check(str(f.state.outcome) == "victory", "then it ends with the last of them")
	## With only its brood beside it, the boss's death ends the fight there and then.
	var lone: Dictionary = setup(["THE_DRILL"])
	DeepBattle.summon(lone.state, lone.foe, "RAIL_RAT", 2, lone.rng.creatures)
	lone.foe.statuses.ward = 0
	lone.foe.block = 0
	lone.foe.hp = 5
	hit(lone, 50)
	check(str(lone.state.outcome) == "victory" and DeepBattle.living(lone.state.enemies).is_empty(), "the Drill dead, its rats gone, the chamber is won")
	## Escorts go with their leader; a thief drops what it took for the blow that did it.
	var p: Dictionary = setup(["THE_PRISMARCH"])
	p.foe.statuses.ward = 0
	p.foe.block = 0
	p.foe.hp = 5
	var prism_blow: Dictionary = hit(p, 500)
	check(prism_blow.get("routed", []).size() == 3 and str(p.state.outcome) == "victory", "the Prismarch's prisms leave with it")
	var c: Dictionary = setup(["THE_HOLLOW_CROWN"])
	var magpies: Array = DeepBattle.summon(c.state, c.foe, "GILDED_MAGPIE", 2, c.rng.creatures)
	DeepBattle.enemy(c.state, str(magpies[0])).stolen_gold = 12
	c.player.gold = 0
	c.foe.statuses.ward = 0
	c.foe.block = 0
	c.foe.hp = 5
	var crown_blow: Dictionary = hit(c, 500)
	check(int(c.player.gold) == 12 and crown_blow.routed.any(func(e: Dictionary) -> bool: return int(e.get("recovered_gold", 0)) == 12), "a fleeing magpie drops its 12 pyrite for the killer: %d" % int(c.player.gold))

func scaling_with_the_mine() -> void:
	## A creature's own numbers carry the weight its mine gives it (October 25, 2026): what it
	## does for itself grows with its health, what it strips or burns grows with its blows.
	var deep: Dictionary = setup(["QUARTZ_GOLEM"], 1, {"depth": 1, "scale": {"hp": 4.0, "damage": 2.5}, "tough": false})
	var golem: Dictionary = deep.foe
	check(DeepCreatures.health_pct(golem) == 400 and int(golem.block) == 24, "a golem bred four times as tough walks in behind four times the block: %d" % int(golem.block))
	var harden: Dictionary = {"kind": "block", "target": "self", "amount": {"term": "rolled"}}
	var resolved: Dictionary = DeepRules.resolve_effect(harden, {"rolled": 5}, 1.0, "heroes")
	DeepCreatures.scale_effect(golem, resolved, harden)
	check(int(resolved.amount) == 20 and int(resolved.get("health_pct", 0)) == 400, "and hardens for four times its roll: %d" % int(resolved.amount))
	var share: Dictionary = {"kind": "max_hp", "target": "self", "amount": {"op": "pct", "args": [{"term": "max_hp"}, 25]}}
	var grown: Dictionary = {"kind": "max_hp", "target": "self", "amount": 50}
	DeepCreatures.scale_effect(golem, grown, share)
	check(int(grown.amount) == 50, "a share of its own health is left as it is")
	var strip: Dictionary = {"kind": "remove_block", "target": "heroes", "amount": 4}
	var stripped: Dictionary = strip.duplicate()
	DeepCreatures.scale_effect(golem, stripped, strip)
	check(int(stripped.amount) == 10, "block it strips carries the weight on its blows: %d" % int(stripped.amount))
	golem.statuses.strength = 2
	check(DeepCreatures.weighted(golem, DeepCreatures.strength(golem)) == 5, "two Strength is five points on a blow at x2.5")
	## Poison and Burn a creature puts on a player hurt for their stacks times the creatures'
	## weight here; a player's own (a Hemlock's) for its stacks.
	DeepBattle._apply(deep.state, golem, {"kind": "poison", "target": "heroes", "amount": 4}, deep.rng.dice)
	DeepBattle._apply(deep.state, golem, {"kind": "burn", "target": "heroes", "amount": 4}, deep.rng.dice)
	deep.player.block = 3
	var poisoned: Dictionary = DeepBattle._poison_tick(deep.state, deep.player)
	var burned: Dictionary = DeepBattle._burn_tick(deep.state, deep.player)
	check(int(poisoned.amount) == 10 and int(deep.player.statuses.poison) == 3, "a creature's Poison 4 hurts 10 at x2.5 and loses one stack: %d" % int(poisoned.amount))
	check(int(burned.soaked) == 3 and int(burned.amount) == 7 and int(deep.player.statuses.burn) == 3, "a creature's Burn 4 hurts 10, block soaking 3 of it: %s" % str(burned))
	DeepBattle._apply(deep.state, deep.player, {"kind": "poison", "target": "self", "amount": 5}, deep.rng.dice)
	var mixed: Dictionary = DeepBattle._poison_tick(deep.state, deep.player)
	check(int(mixed.amount) == 5 + 7, "a Hemlock's own 5 stacks hurt 5 beside the creature's 3 at x2.5 (7): %d" % int(mixed.amount))
	deep.player.statuses.poison = 0
	DeepBattle._apply(deep.state, deep.player, {"kind": "poison", "target": "self", "amount": 4}, deep.rng.dice)
	check(int(DeepBattle._poison_tick(deep.state, deep.player).amount) == 4, "stacks cleansed away take the creature's share with them: a fresh Hemlock 4 hurts 4")
	golem.statuses.poison = 4
	check(int(DeepBattle._poison_tick(deep.state, golem).amount) == 4, "on a creature it is only its stacks")
	## The Quarry is untouched: one player, the first floor, plain weights.
	var plain: Dictionary = setup(["QUARTZ_GOLEM"], 1, {"tough": false})
	check(DeepCreatures.health_pct(plain.foe) == 100 and int(plain.foe.block) == 6 and int(plain.state.creature_damage_pct) == 100, "a Quarry golem on the first floor is as written")
	## What its move table says about a Poison or Burn that will hurt harder here.
	var imp: Dictionary = setup(["FORGE_IMP"], 1, {"scale": {"hp": 1.0, "damage": 2.85}})
	var cackle: Dictionary = DeepCreatures.display_moves(imp.foe)[0].effects[0]
	check(int(cackle.get("weight", 0)) == 285 and DeepCreatures.effect_words(cackle).contains("×2.85"), "an Imp's Cackle says every round hurts ×2.85 here: %s" % DeepCreatures.effect_words(cackle))
	check(not DeepContent.creature("FORGE_IMP").get("tip", "").is_empty(), "and its page says what to remember about it")
	## A golem's Fortify keeps all its block into its next turn, so it piles up.
	var keep: Dictionary = setup(["QUARTZ_GOLEM"])
	keep.foe.block = 0
	keep.player.statuses.stun = 1
	land(keep.foe, ["Fortify"])
	turn(keep)
	var after_one: int = int(keep.foe.block)
	keep.player.statuses.stun = 1
	turn(keep)
	var wall: int = amount_of("QUARTZ_GOLEM", "Fortify")
	check(after_one >= wall and int(keep.foe.block) >= after_one + wall, "Fortify piles its block up: %d then %d" % [after_one, int(keep.foe.block)])

func every_creature_has_a_tip() -> void:
	for key in DeepContent.section("creatures"):
		var tip: String = str(DeepContent.creature(str(key)).get("tip", ""))
		check(not tip.is_empty() and tip.length() <= 110, "%s says what to remember about it, in a line: %s" % [str(key), tip])

func the_identity_pass() -> void:
	## The creatures as the owner reviewed them (October 2026), face by face.
	## The Mirror Regent: Reflection throws back what it took since it last acted, Mirror
	## Image the best die any player shows, Splinter curses.
	var r: Dictionary = setup(["THE_REGENT"])
	r.foe.statuses.ward = 0
	r.foe.block = 0
	r.player.block = 0
	r.foe.hp_at_turn = int(r.foe.hp)
	hit(r, 30)
	land(r.foe, ["Reflection", "Mirror Image", "Splinter"])
	for i in range(r.player.hand.size()):
		r.player.hand[i].value = [2, 6, 5, 1, 6][i]
	var mirrored: Array = turn(r)
	var thrown: Array = moves_named(mirrored, "Reflection").map(func(e: Dictionary) -> int: return int(e.effects[0].raw))
	var image: Array = moves_named(mirrored, "Mirror Image").map(func(e: Dictionary) -> int: return int(e.effects[0].raw))
	check(thrown == [30], "Reflection throws back the 30 it took since its last action: %s" % str(thrown))
	check(image == [6], "Mirror Image throws the best die back: %s" % str(image))
	check(moves_named(mirrored, "Splinter").size() == 1 and int(r.player.statuses.get("curse", 0)) == amount_of("THE_REGENT", "Splinter"), "Splinter curses")
	land(r.foe, ["Reflection"])
	var quiet: Array = moves_named(turn(r), "Reflection")
	check(not quiet.is_empty() and int(quiet[0].effects[0].raw) == 0, "untouched since, it has nothing to throw back")
	## The Drowned Miner gets back up once.
	var d: Dictionary = setup(["DROWNED_MINER"])
	d.foe.block = 0
	var down: Dictionary = hit(d, 9999)
	check(bool(down.get("risen", false)) and int(d.foe.hp) == int(d.foe.max_hp) / 2 and not down.has("killed"), "the first killing blow leaves it standing at half")
	var again: Dictionary = hit(d, 9999)
	check(bool(again.get("killed", false)) and int(d.foe.hp) <= 0, "the second one keeps it down")
	## The Cave Crayfish's Grip holds the best die until it is hurt; its Shell is kept.
	var c: Dictionary = setup(["CAVE_CRAYFISH"])
	c.player.statuses.stun = 1
	for i in range(c.player.hand.size()):
		c.player.hand[i].value = i + 1
	land(c.foe, ["Grip", "Shell"])
	var grip: Array = turn(c)
	var held: String = str(c.player.gripped.keys()[0]) if not c.player.get("gripped", {}).is_empty() else ""
	check(moves_named(grip, "Grip").size() == 1 and held == "p0_d4" and int(c.foe.block) >= amount_of("CAVE_CRAYFISH", "Shell"), "Grip holds the die showing the most and Shell shells it up: %s" % held)
	check(c.player.hand.size() == 4 and not c.player.hand.any(func(r2: Dictionary) -> bool: return str(r2.die_id) == held), "the gripped die sits the throw out")
	c.foe.block = 0
	var freed: Dictionary = hit(c, 5)
	check(not freed.get("released", []).is_empty() and c.player.gripped.is_empty(), "hurting it opens the claw")
	land(c.foe, ["Claw"])
	c.player.statuses.stun = 1
	turn(c)
	check(c.player.hand.size() == 5, "and the die is back for the next throw")
	## The Lock-Keeper's Turn the Wheel etches a Wrench on its gate die into a Sluice, which
	## goes through block; its Flood dulls the party.
	var k: Dictionary = setup(["THE_LOCKKEEPER"])
	k.foe.statuses.ward = 0
	check(not DeepCreatures.has_trait(k.foe, "cloud_socket"), "the Lock-Keeper does not fog sockets")
	var sluices: int = faces_of(k.foe, "Sluice", 1)
	var wrenches: int = faces_of(k.foe, "Wrench", 1)
	force_faces(k.foe, 0, "Turn the Wheel")
	k.player.statuses.stun = 1
	var wheel: Array = turn(k)
	check(moves_named(wheel, "Turn the Wheel").size() == 1 and faces_of(k.foe, "Sluice", 1) == sluices + 1 and faces_of(k.foe, "Wrench", 1) == wrenches - 1,
		"Turn the Wheel etches a Wrench on the gate die into a Sluice: %d Sluices" % faces_of(k.foe, "Sluice", 1))
	k.player.block = 50
	land(k.foe, ["Sluice", "Flood"])
	k.player.statuses.stun = 1
	var sluice: Array = turn(k)
	var opened: Array = moves_named(sluice, "Sluice")
	check(opened.size() == 1 and int(opened[0].effects[0].hp_loss) == amount_of("THE_LOCKKEEPER", "Sluice") and int(opened[0].effects[0].absorbed) == 0,
		"the Sluice hits through block: %s" % str(opened[0].effects if not opened.is_empty() else []))
	check(moves_named(sluice, "Flood").size() == 1 and int(k.player.statuses.get("dulled", 0)) == amount_of("THE_LOCKKEEPER", "Flood", 1), "the Flood dulls the party")
	## The Drowned Choir: Another Voice raises a head, five at most.
	var ch: Dictionary = setup(["THE_DROWNED_CHOIR"])
	ch.foe.statuses.ward = 0
	check(ch.foe.dice.size() == 3, "the Choir sings with three heads")
	land(ch.foe, ["Another Voice", "Another Voice", "Another Voice"])
	var voices: Array = moves_named(turn(ch), "Another Voice")
	check(voices.size() == 3 and ch.foe.dice.size() == 5 and bool(voices[2].effects[0].get("nothing", false)), "Another Voice raises a head, five at most: %d" % ch.foe.dice.size())
	check(DeepCreatures.is_face_die(ch.foe.dice[4]) and faces_of(ch.foe, "Requiem", 4) == 1, "and the new head sings like the first")
	## The Undertow's Drag Under stuns the party; it dives, and surfaces biting.
	var u: Dictionary = setup(["THE_UNDERTOW"], 2)
	u.foe.statuses.ward = 0
	land(u.foe, ["Drag Under"])
	var drag: Array = turn(u)
	var dragged: Array = moves_named(drag, "Drag Under")
	check(dragged.size() == 1 and dragged[0].effects.size() == 2 and dragged[0].effects.all(func(e: Dictionary) -> bool: return str(e.kind) == "stun"), "Drag Under stuns every player")
	land(u.foe, ["Dive"])
	turn(u)
	check(bool(u.foe.burrowed), "it dives out of reach")
	land(u.foe, ["Bite"])
	var up: Array = turn(u)
	var surface: Array = moves_named(up, "Surface")
	check(surface.size() == 1 and surface[0].effects.size() == 2 and moves_named(up, "Bite").size() == 1, "it surfaces with a blow at every player, then bites")
	## A Will-o'-Wisp's Lure marks a player for every reroll they used.
	var w: Dictionary = setup(["WILL_O_WISP"], 2)
	w.state.players[0].rerolled = 1
	## A Lantern's frozen turn (no rerolls handed out) is not a reroll.
	w.state.players[1].rerolls = 0
	land(w.foe, ["Lure"])
	DeepBattle.force_lock(w.state)
	DeepBattle.start_resolution(w.state)
	var lured: Array = []
	while DeepBattle.has_steps(w.state) and lured.size() < 300:
		var event: Dictionary = DeepBattle.step(w.state, w.rng.dice, w.rng.creatures)
		lured.append(event)
		if str(event.get("kind", "")) == "enemy_move" and str(event.get("move", "")) == "Lure":
			break
	var lure: Array = moves_named(lured, "Lure")
	var marked: Array = lure[0].effects.filter(func(e: Dictionary) -> bool: return not bool(e.get("nothing", false))) if not lure.is_empty() else []
	check(lure.size() == 1 and marked.size() == 1 and str(marked[0].target) == "p0" and int(w.state.players[0].statuses.get("marked", 0)) == 1 and int(w.state.players[1].statuses.get("marked", 0)) == 0,
		"Lure marks only the player who rerolled: %s" % str(marked.map(func(e: Dictionary) -> String: return str(e.target))))
	## A Magpie's Snatch takes pyrite from the richest player.
	var m: Dictionary = setup(["MAGPIE"], 2)
	m.state.players[0].ore = 5
	m.state.players[1].ore = 40
	for unit in m.state.players:
		unit.statuses.stun = 1
	land(m.foe, ["Snatch"])
	var snatch: Array = moves_named(turn(m), "Snatch")
	check(snatch.size() == 1 and str(snatch[0].effects[0].target) == "p1" and int(snatch[0].effects[0].stolen) == amount_of("MAGPIE", "Snatch"), "Snatch takes %d from the richest" % amount_of("MAGPIE", "Snatch"))
	## The Rift Shifter swaps two neighbouring gems for the fight.
	var rail: Array = [stone("STRIKE", "s1"), stone("GUARD", "g1"), stone("MEND", "m1")]
	var sh: Dictionary = setup(["RIFT_SHIFTER"], 1, {}, rail)
	var swapped: Array = DeepBattle._apply(sh.state, sh.foe, {"kind": "swap_gems", "target": "heroes", "amount": 1}, sh.rng.dice)
	var order: Array = sh.player.rail.map(func(x: Variant) -> String: return str(x.id) if x is Dictionary else "-")
	check(swapped.size() == 1 and order.slice(0, 3) != ["s1", "g1", "m1"] and order.slice(0, 3).has("s1") and order.slice(0, 3).has("g1") and order.slice(0, 3).has("m1"), "two neighbours change places: %s" % str(order))
	var at: Array = swapped[0].get("swapped", [0, 1])
	check(str(sh.player.initial_rail[int(at[0])].id) == str(sh.player.rail[int(at[0])].id), "and what a broken gem grows back as follows the swap")
	## A Collapsar's Gravity draws every single-target blow into it until it acts again.
	var co: Dictionary = setup(["CAVE_TICK", "COLLAPSAR"])
	var tick: Dictionary = co.state.enemies[0]
	var hole: Dictionary = co.state.enemies[1]
	co.player.target = str(tick.id)
	check(str(DeepBattle._targets(co.state, co.player, "enemy")[0].key) == "CAVE_TICK", "before its Gravity a blow goes where it is aimed")
	land(tick, ["Bite"])
	land(hole, ["Gravity"])
	turn(co)
	co.player.target = str(tick.id)
	var bent: Array = DeepBattle._targets(co.state, co.player, "enemy")
	check(bent.size() == 1 and str(bent[0].key) == "COLLAPSAR", "under its Gravity a blow aimed at the tick bends into the Collapsar")
	check(DeepBattle._targets(co.state, co.player, "enemies").size() == 2, "a blow that hits every creature still does")
	land(hole, ["Pull"])
	turn(co)
	co.player.target = str(tick.id)
	check(str(DeepBattle._targets(co.state, co.player, "enemy")[0].key) == "CAVE_TICK", "the Gravity lets go as its next action opens")
	land(hole, ["Gravity"])
	turn(co)
	hole.hp = 0
	co.player.target = str(tick.id)
	check(str(DeepBattle._targets(co.state, co.player, "enemy")[0].key) == "CAVE_TICK", "and once it falls, aim is free again")
	## The Mycel Weaver's Envenom makes poison bite again at once.
	var wv: Dictionary = setup(["MYCEL_WEAVER"])
	wv.player.statuses.poison = 5
	var webbed: Array = DeepBattle._apply(wv.state, wv.foe, {"kind": "poison_tick", "target": "heroes", "amount": 1}, wv.rng.dice)
	check(webbed.size() == 1 and webbed[0].get("ticks", []).size() == 1 and int(wv.player.statuses.poison) == 4, "its Envenom ticks the party's poison once more")

func wording_and_content() -> void:
	## Every move of every creature reads out without a hole in its sentence.
	for key in DeepContent.section("creatures"):
		var def: Dictionary = DeepContent.creature(str(key))
		var all: Array = def.get("moves", []).duplicate()
		for phase in def.get("phases", []):
			all.append_array(phase.get("moves", []))
		for move in all:
			var when: String = DeepCreatures.trigger_words(move)
			check(not when.is_empty() and not when.contains("%s") and not when.contains("%d"), "%s's %s says when it fires: %s" % [key, move.name, when])
			if not DeepCreatures.once_an_action(move):
				check(not when.contains("once/turn"), "%s's %s fires on every die that qualifies, and does not say once a turn: %s" % [key, move.name, when])
			for effect in move.get("effects", []):
				var what: String = DeepCreatures.effect_words(effect)
				check(not what.is_empty() and not what.contains("%s") and not what.contains("%d"), "%s's %s says what it does: %s" % [key, move.name, what])
	for kind in DeepPatterns.TURN_KINDS:
		check(not DeepPatterns.words({"kind": kind, "amount": 2}, 0).is_empty() and DeepPatterns.words({"kind": kind, "amount": 2}, 0) != "Its trigger.", "%s has words" % kind)
	## What the owner turned down is gone: no creature, effect or trait of it is left.
	check(DeepContent.creature("LENS_BEETLE").is_empty(), "the Lens Beetle is gone")
	for kind in ["adapt", "corroded", "invert_dice", "drain_resonance"]:
		check(not DeepRules.EFFECT_KINDS.has(kind), "%s is no longer an effect" % kind)
	check(not DeepContent.TRAITS.has("bedrock") and DeepContent.TRAITS.has("sturdy") and not DeepContent.TRAITS.has("adapt_aura"), "Bedrock is called Sturdy, and the adapting aura is gone")
	## Variants never share a band with the creature they are based on, or stand within a
	## mine of it or of another variant of it.
	var based: Dictionary = {"PRISM_GOLEM": "QUARTZ_GOLEM", "SHARD_WYRM": "GLASS_WYRM", "GLINT_MAGPIE": "MAGPIE", "WILL_O_WISP": "LANTERN_MOTH", "SPORE_SLIME": "SILT_SLIME",
		"MYCEL_WRAITH": "VEIN_WRAITH", "FIRE_TICK": "CAVE_TICK", "CINDER_MOTH": "LANTERN_MOTH", "GILDED_MAGPIE": "MAGPIE", "GEODE_GOLEM": "QUARTZ_GOLEM", "AMETHYST_WYRM": "GLASS_WYRM"}
	var order: Array = ["QUARRY", "SEEPS", "GLASS_VEINS", "WARRENS", "FURNACE", "GEODE", "RIFT"]
	var where: Dictionary = {}
	for mine_key in order:
		for band in DeepContent.mine(mine_key).bands:
			for creature_key in band.creatures:
				if not where.has(creature_key):
					where[creature_key] = []
				if not where[creature_key].has(order.find(mine_key)):
					where[creature_key].append(order.find(mine_key))
	for variant in based:
		var family: Array = [based[variant]]
		for other in based:
			if other != variant and based[other] == based[variant]:
				family.append(other)
		for at in where.get(variant, []):
			for relative in family:
				for there in where.get(relative, []):
					check(absi(int(at) - int(there)) > 1, "%s (mine %d) stands more than a mine from %s (mine %d)" % [variant, at, relative, there])
	## Every mine has its own Wardens and boss, and summon-only creatures are in no band.
	for mine_key in order:
		var mine: Dictionary = DeepContent.mine(mine_key)
		check(mine.wardens.size() >= 2, "%s has at least two Wardens" % mine_key)
		if not bool(mine.get("endless", false)):
			check(not str(mine.get("boss", "")).is_empty() and not mine.wardens.has(str(mine.boss)), "%s has a boss of its own, not one of its Wardens" % mine_key)
	for key in ["PRISM", "TENDRIL"]:
		check(not where.has(key), "%s is never found on its own" % key)
	check(DeepContent.validate().is_empty(), "the content pack validates")
