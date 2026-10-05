extends SceneTree
## The deeper mines' creatures and the mechanics they fight with (docs/BESTIARY.md),
## exercised through real battle steps with fixed dice.
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
	return {"state": state, "rng": rng, "foe": state.enemies[0], "player": state.players[0]}

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
	var f: Dictionary = setup(["RAIL_RAT"])
	fixed(f.foe, [2, 2])
	var events: Array = turn(f)
	check(moves_named(events, "Scurry").size() == 1 and f.state.enemies.size() == 2, "a pair of Rail Rat dice calls another rat: %d creatures" % f.state.enemies.size())
	var pup: Dictionary = f.state.enemies[1]
	check(str(pup.key) == "RAIL_RAT" and bool(pup.get("summoned", false)) and str(pup.id) != str(f.foe.id), "the newcomer is a summoned rat with its own id")
	check(int(pup.get("turns_acted", 0)) == 0, "it acts from the next turn")
	var again: Array = turn(f)
	check(of(again, "enemy_begin").size() >= 2, "both rats act the turn after")
	## Four creatures at most.
	var crowded: Dictionary = setup(["RAIL_RAT", "RAIL_RAT", "RAIL_RAT", "RAIL_RAT"])
	fixed(crowded.foe, [2, 2])
	var full: Array = turn(crowded)
	var scurry: Array = moves_named(full, "Scurry")
	check(scurry.size() == 1 and bool(scurry[0].effects[0].get("nothing", false)) and crowded.state.enemies.size() == 4, "a full chamber has no room for a fifth creature")
	## Escorts come with their leader, and shield it while they stand.
	var p: Dictionary = setup(["THE_PRISMARCH"])
	check(p.state.enemies.size() == 4 and p.foe.escorts.size() == 3, "the Prismarch walks in with three prisms")
	check(p.state.enemies[1].escort_of == str(p.foe.id) and str(p.state.enemies[1].key) == "PRISM", "each prism knows its leader")
	p.foe.block = 0
	var shielded: Dictionary = hit(p, 40)
	check(bool(shielded.get("shielded", false)) and int(shielded.hp_loss) == 20, "while a prism floats the Prismarch takes half: %d" % int(shielded.hp_loss))
	for escort in p.state.enemies.slice(1):
		escort.hp = 0
	var bare: Dictionary = hit(p, 40)
	check(not bare.has("shielded") and int(bare.hp_loss) == 40, "with the prisms gone it takes the whole blow")
	## A Heartrot's 10 grows a tendril back, room allowing, and the new one is its escort.
	var h: Dictionary = setup(["THE_HEARTROT"])
	h.state.enemies[1].hp = 0
	fixed(h.foe, [10, 3, 3], [10, 10, 10])
	var grown: Array = turn(h)
	var fresh: Array = h.state.enemies.filter(func(e: Dictionary) -> bool: return str(e.get("summoned_by", "")) == str(h.foe.id))
	check(moves_named(grown, "Grow").size() == 1 and DeepBattle.living(h.state.enemies).size() == 4, "a 10 grows a tendril into the gap: %d standing" % DeepBattle.living(h.state.enemies).size())
	check(fresh.size() == 1 and str(fresh[0].key) == "TENDRIL" and str(fresh[0].escort_of) == str(h.foe.id) and h.foe.escorts.has(str(fresh[0].id)), "the new tendril is one of the heart's escorts")
	fixed(h.foe, [10, 10, 1], [10, 10, 10])
	var no_room: Array = turn(h)
	check(moves_named(no_room, "Grow").all(func(e: Dictionary) -> bool: return bool(e.effects[0].get("nothing", false))) and DeepBattle.living(h.state.enemies).size() == 4, "with all three standing there is no room for more")
	check(moves_named(no_room, "Slough").is_empty() and not DeepContent.creature("THE_HEARTROT").has("phases"), "the Heartrot no longer sloughs its poison or regrows by phase")
	## The Gardener plants on every roll: a Puffball on an even one, a Root Horror on an odd one, and heals everything by the roll.
	var g: Dictionary = setup(["THE_GARDENER"])
	g.foe.hp = 900
	fixed(g.foe, [4], [20])
	var plant: Array = turn(g)
	check(moves_named(plant, "Plant").size() == 1 and g.state.enemies.size() == 2 and str(g.state.enemies[1].key) == "PUFFBALL", "an even roll plants a Puffball")
	check(int(g.foe.hp) == 904, "Tend heals the Gardener itself by the roll: %d" % int(g.foe.hp))
	fixed(g.foe, [7], [20])
	var sow: Array = turn(g)
	check(moves_named(sow, "Sow").size() == 1 and g.state.enemies.any(func(e: Dictionary) -> bool: return str(e.key) == "ROOT_HORROR"), "an odd roll plants a Root Horror")

func burrow_and_emerge() -> void:
	var f: Dictionary = setup(["PIT_MOLE", "RAIL_RAT"], 2)
	fixed(f.foe, [3])
	f.state.players[0].block = 5
	var dig: Array = turn(f)
	check(moves_named(dig, "Dig In").size() == 1 and moves_named(dig, "Claw").is_empty(), "an odd roll digs in")
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
	## Next turn it comes up under whoever has the least block.
	f.state.players[0].block = 0
	f.state.players[1].block = 9
	fixed(f.foe, [4])
	var up: Array = turn(f)
	var begin: Array = of(up, "enemy_begin").filter(func(e: Dictionary) -> bool: return str(e.unit) == str(f.foe.id))
	check(not begin.is_empty() and bool(begin[0].get("emerged", false)) and not bool(f.foe.burrowed), "it emerges as it acts again")
	var erupt: Array = moves_named(up, "Erupt")
	check(erupt.size() == 1 and erupt[0].effects.size() == 1 and str(erupt[0].effects[0].target) == "p0" and int(erupt[0].effects[0].hp_loss) == 8, "Erupt hits the player with the least block for roll + 4: %s" % str(erupt[0].effects if not erupt.is_empty() else []))
	check(moves_named(up, "Claw").size() == 1, "and the even roll claws as well")

func refract_mirror_and_absorb() -> void:
	## A Prism Golem's even roll refracts: until it acts again, half of every blow on it goes
	## back at every player.
	var f: Dictionary = setup(["PRISM_GOLEM"], 2)
	fixed(f.foe, [2], [12])
	turn(f)
	check(int(f.foe.reflect) == 50, "an even roll refracts by half")
	f.foe.block = 0
	for unit in f.state.players:
		unit.block = 0
	var had: Array = f.state.players.map(func(u: Dictionary) -> int: return int(u.hp))
	var struck: Dictionary = hit(f, 20)
	check(int(struck.hp_loss) == 20 and struck.get("reflections", []).size() == 2, "the golem takes the blow and sends half back: %s" % str(struck.get("reflections", [])))
	check(int(f.state.players[0].hp) == int(had[0]) - 10 and int(f.state.players[1].hp) == int(had[1]) - 10, "ten at every player, not only the thrower")
	fixed(f.foe, [1], [12])
	var next: Array = turn(f)
	check(int(f.foe.reflect) == 0 and bool(of(next, "enemy_begin")[0].get("guard_ended", false)), "the refraction ends when it acts again")
	check(int(hit(f, 20).get("reflections", []).size()) == 0, "and blows land plainly again")
	## An Echo Sprite's mirror sends the whole of the next blow back at whoever threw it.
	var e: Dictionary = setup(["ECHO_SPRITE"])
	fixed(e.foe, [5], [6])
	turn(e)
	check(int(e.foe.mirror) == 1, "a 5 holds up a mirror")
	e.foe.block = 0
	e.player.block = 0
	var before: int = int(e.foe.hp)
	var owner_hp: int = int(e.player.hp)
	var mirrored: Dictionary = hit(e, 12)
	check(int(e.foe.hp) == before and mirrored.has("mirrored") and int(e.player.hp) == owner_hp - 12, "the blow goes back whole at its thrower: %s" % str(mirrored))
	var through: Dictionary = hit(e, 12)
	check(int(through.hp_loss) == 12 and int(e.foe.mirror) == 0, "the mirror is spent: the next blow lands")
	fixed(e.foe, [3], [6])
	var twinkle: Array = turn(e)
	check(moves_named(twinkle, "Twinkle").size() == 1 and int(moves_named(twinkle, "Twinkle")[0].effects[0].raw) == 3, "Twinkle hits for its roll")
	## The Kaleidoscope drinks a colour: those gems do it no harm, and what they would give
	## their owner goes to it instead.
	var k: Dictionary = setup(["THE_KALEIDOSCOPE"])
	fixed(k.foe, [1, 2, 3], [6, 6, 12])
	turn(k)
	check(k.foe.absorb.size() == 1 and str(k.foe.absorb[0]) in DeepContent.color_KEYS, "each action it drinks one colour: %s" % str(k.foe.absorb))
	var colour: String = str(k.foe.absorb[0])
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
	fixed(k.foe, [2, 2, 3], [6, 6, 12])
	var turned: Array = turn(k)
	check(moves_named(turned, "Turn").size() == 1 and k.foe.absorb.size() == 2, "a pair makes it drink a second colour: %s" % str(k.foe.absorb))

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
	fixed(f.foe, [1])
	turn(f)
	check(int(f.player.statuses.festering) == 1 and int(f.player.statuses.scorched) == 1, "each counts down one a turn")
	var fresh: Dictionary = setup(["CAP_SHAMBLER"])
	fixed(fresh.foe, [9])
	var cloud: Array = turn(fresh)
	check(moves_named(cloud, "Spore Cloud").size() == 1 and int(fresh.player.statuses.get("festering", 0)) == 2, "a Spore Cloud on 8+ festers the party for 2, and a fresh application survives the tick that follows")
	## A Salamander's even roll sets the party burning for the roll; the tick that ends the turn burns.
	var s: Dictionary = setup(["SALAMANDER"])
	s.player.block = 0
	fixed(s.foe, [8], [12])
	var ember: Array = turn(s)
	check(moves_named(ember, "Ember").size() == 1 and moves_named(ember, "Scratch").is_empty(), "an even roll is an Ember, not a Scratch")
	var ticks: Array = []
	for event in of(ember, "tick"):
		ticks.append_array(event.ticks.filter(func(t: Dictionary) -> bool: return str(t.kind) == "burn"))
	check(not ticks.is_empty() and int(ticks[0].amount) == 8 and int(s.player.statuses.get("burn", 0)) == 7, "Burn 8 hurts 8 at the turn's end and falls to 7: %s" % str(ticks))
	fixed(s.foe, [7], [12])
	var scratch: Array = turn(s)
	check(moves_named(scratch, "Scratch").size() == 1 and int(moves_named(scratch, "Scratch")[0].effects[0].raw) == 7, "an odd roll scratches for the roll")
	## The Kiln Wyrm brings no aura now, and its breath burns.
	var w: Dictionary = setup(["THE_KILN_WYRM"])
	check(not DeepCreatures.traits_for(w.foe).has("aura") and w.player.statuses.is_empty(), "the Kiln Wyrm puts nothing on the party just by being there")
	w.foe.statuses.ward = 0
	w.player.block = 0
	fixed(w.foe, [3, 3, 5], [10, 12, 20])
	var breath: Array = turn(w)
	check(moves_named(breath, "Firebreath").size() == 1 and int(w.player.statuses.get("burn", 0)) == 2, "a pair of 3s burns the party for 3, and one round has burned: %d left" % int(w.player.statuses.get("burn", 0)))
	var lava: Array = DeepContent.creature("THE_KILN_WYRM").phases[0].moves.filter(func(m: Dictionary) -> bool: return str(m.name) == "Lavafall")
	check(lava.size() == 1 and int(lava[0].effects[0].amount) == 20 and str(lava[0].effects[1].kind) == "burn" and int(lava[0].effects[1].amount) == 20, "hurt, its lava falls for 20 and burns for 20")

func steadfast_and_sturdy() -> void:
	var f: Dictionary = setup(["THE_ANVIL_KNIGHT"])
	f.foe.statuses.ward = 0
	var stunned: Array = apply(f, {"kind": "stun", "target": "enemy", "amount": 3})
	check(int(f.foe.statuses.stun) == 2 and bool(stunned[0].get("steadfast", false)), "Steadfast halves a stun, rounded up: %d" % int(f.foe.statuses.stun))
	var bound: Array = apply(f, {"kind": "die_steal", "target": "enemy", "amount": 1})
	check(int(f.foe.stolen_dice) == 1 and bool(bound[0].get("steadfast", false)), "a single bound die still binds one")
	fixed(f.foe, [2, 2])
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
	fixed(g.foe, [6], [12])
	g.foe.block = 0
	turn(g)
	check(int(g.foe.statuses.get("retain", 0)) == 6, "Harden keeps block equal to its roll: retain %d" % int(g.foe.statuses.get("retain", 0)))
	## The Hollow Crown is Sturdy the whole fight.
	var c: Dictionary = setup(["THE_HOLLOW_CROWN"])
	check(DeepCreatures.trait_value(c.foe, "sturdy", 0) == 15, "the Hollow Crown is Sturdy 15%")
	c.foe.hp = int(c.foe.max_hp) / 5
	DeepCreatures.prepare(c.foe)
	check(DeepCreatures.trait_value(c.foe, "sturdy", 0) == 15, "and still is near death")

func backlash_and_damping() -> void:
	## With a Riftling Swarm in the room, every gem that fires costs its owner a point.
	var rail: Array = []
	for i in range(5):
		rail.append(stone("STRIKE", "strike%d" % i))
	var riders: Array = [[], [], [], [], []]
	for i in range(3):
		riders[4].append(DeepStone.make("STRIKE", 1, 4, 3, ["VOID"], {}, "void%d" % i))
	var f: Dictionary = setup(["RIFTLING_SWARM"], 1, {}, rail, riders)
	fixed(f.foe, [1, 1, 1], [4, 4, 4])
	f.player.hp = 100
	f.player.max_hp = 100
	var events: Array = turn(f)
	var fired: Array = of(events, "gem_fire").filter(func(e: Dictionary) -> bool: return str(e.unit) == "p0")
	check(fired.size() == 8, "eight Strikes fire: %d" % fired.size())
	check(fired.all(func(e: Dictionary) -> bool: return int(e.get("backlash", 0)) == 1), "every one of them costs its owner a point, wherever it sits")
	check(int(f.player.hp) == 100 - 8 - 3, "eight points of Backlash and three Nibbles of 1: hp %d" % int(f.player.hp))
	fixed(f.foe, [4, 1, 1], [4, 4, 4])
	turn(f)
	check(f.foe.dice.size() == 4, "a 4 adds another riftling")
	## A Null Shade halves the Resonance a rail builds, carrying the half-points.
	var plain: Dictionary = setup(["CAVE_TICK"], 1, {}, rail.slice(0, 3))
	fixed(plain.foe, [1], [6])
	var free: Array = turn(plain)
	var u: Dictionary = setup(["NULL_SHADE"], 1, {}, rail.slice(0, 3))
	fixed(u.foe, [1], [8])
	var damped: Array = turn(u)
	check(int(of(free, "rail_end")[0].resonance) == 5 and int(of(damped, "rail_end")[0].resonance) == 2, "three Strikes ring 5 without a Shade and 2 with one: %d / %d" % [int(of(free, "rail_end")[0].resonance), int(of(damped, "rail_end")[0].resonance)])
	var drain: Array = moves_named(damped, "Drain")
	check(drain.size() == 1 and drain[0].effects.size() == 2 and str(drain[0].effects[1].kind) == "heal", "the Shade's Drain hits and heals it for the roll")
	fixed(u.foe, [2], [8])
	var snuff: Array = turn(u)
	check(moves_named(snuff, "Snuff").size() == 1 and u.player.rail.filter(func(x: Variant) -> bool: return x is Dictionary).size() == 2, "an even roll snuffs out a gem")
	fixed(u.foe, [1], [8])
	turn(u)
	check(u.player.rail.filter(func(x: Variant) -> bool: return x is Dictionary).size() == 2, "for the rest of the fight")

func locks_and_dread() -> void:
	## A Seep Eel's shock locks the highest die into the next hand.
	var f: Dictionary = setup(["SEEP_EEL"])
	fixed(f.foe, [1, 8])
	for i in range(f.player.hand.size()):
		f.player.hand[i].value = i + 1
	var shock: Array = turn(f)
	check(moves_named(shock, "Shock").size() == 1, "an 8 shocks")
	var locked: Array = f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("locked", false)))
	check(locked.size() == 1 and int(locked[0].value) == 5 and bool(locked[0].get("locked_by_foe", false)), "the highest die came up again as it was, locked: %s" % str(locked.map(func(r: Dictionary) -> int: return int(r.value))))
	check(not DeepDice.rerollable(f.player.hand).has(str(locked[0].die_id)), "and it cannot be rerolled")
	fixed(f.foe, [1, 1])
	turn(f)
	check(f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("locked", false))).is_empty(), "the lock lasts one turn")
	## Dread on a player: the bowl rolls a size smaller next turn.
	var d: Dictionary = setup(["DROWNED_MINER"])
	fixed(d.foe, [4, 4])
	var pull: Array = turn(d)
	check(moves_named(pull, "Pull Under").size() == 1, "a pair pulls under")
	check(d.player.hand.all(func(r: Dictionary) -> bool: return int(r.top) == 4), "the hand after is thrown on d4s: %s" % str(d.player.hand.map(func(r: Dictionary) -> int: return int(r.top))))
	check(not d.player.statuses.has("dread") and d.player.dice.all(func(x: Dictionary) -> bool: return str(x.shape) == "D6"), "the dice themselves are untouched, and the Dread is spent")
	fixed(d.foe, [1, 2])
	turn(d)
	check(d.player.hand.all(func(r: Dictionary) -> bool: return int(r.top) == 6), "the turn after rolls d6s again")

func theft_and_flight() -> void:
	var f: Dictionary = setup(["GILDED_MAGPIE"])
	f.player.gold = 30
	f.player.block = 0
	fixed(f.foe, [2, 3, 1])
	var peck: Array = turn(f)
	check(moves_named(peck, "Peck").size() == 3 and int(f.foe.stolen_gold) == 27 and int(f.player.gold) == 3, "a Gilded Magpie takes nine with every hit that draws blood: %d held" % int(f.foe.stolen_gold))
	check(DeepCreatures.trait_value(f.foe, "flee", 0) == 4 and int(of(peck, "enemy_begin")[0].get("flee_in", 0)) == 4, "it says how long it will stay")
	for _i in range(3):
		fixed(f.foe, [1, 1, 1])
		turn(f)
	check(bool(f.foe.fled) and int(f.foe.hp) == 0 and str(f.state.outcome) == "victory", "after its fourth action it is gone, and the room is clear")
	check(int(f.player.gold) == 0 and int(f.foe.stolen_gold) == 30, "what it stole went with it: %d held, %d left" % [int(f.foe.stolen_gold), int(f.player.gold)])
	## Every Magpie variant flees.
	for key in ["GLINT_MAGPIE", "GILDED_MAGPIE"]:
		check(DeepCreatures.trait_value(setup([key]).foe, "flee", 0) == 4, "%s leaves after its fourth turn" % key)
	## A Lamprey Knot bites for every die it rolls, and every 4 heals it 4.
	var l: Dictionary = setup(["LAMPREY_KNOT"])
	l.foe.hp = 900
	fixed(l.foe, [4, 4, 1], [4, 4, 4])
	var drink: Array = turn(l)
	check(moves_named(drink, "Drink").size() == 2 and int(l.foe.hp) == 908, "two 4s drink twice, 4 each: hp %d" % int(l.foe.hp))
	check(moves_named(drink, "Latch").map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [4, 4, 1], "each Latch bites for its own die")
	check(int(l.foe.stolen_gold) == 0, "and it no longer drinks pyrite")
	## The Assayer's tax is a tenth of each purse, and each player is hit for what it took.
	var a: Dictionary = setup(["THE_ASSAYER"], 2)
	a.state.players[0].ore = 100
	a.state.players[1].ore = 40
	for unit in a.state.players:
		unit.block = 0
	fixed(a.foe, [5, 5], [10, 10])
	var tax: Array = turn(a)
	check(moves_named(tax, "Tax").size() == 1 and int(a.foe.stolen_gold) == 14, "a tenth of 100 and of 40 is 14: %d" % int(a.foe.stolen_gold))
	check(int(a.state.players[0].hp) == 990 and int(a.state.players[1].hp) == 996, "each is hit for what was taken from them: %d / %d" % [int(a.state.players[0].hp), int(a.state.players[1].hp)])
	check(moves_named(tax, "Balance").size() == 2 and int(a.foe.statuses.get("spikes", 0)) == 2, "odd rolls shield it and raise its spikes")
	## Its 10 eats the rich: it heals and grows by the richest player's pyrite.
	var rich: int = DeepRules.pyrite(a.state.players[0])
	var most: int = int(a.foe.max_hp)
	fixed(a.foe, [10, 4], [10, 10])
	var eat: Array = turn(a)
	check(moves_named(eat, "Eat the Rich").size() == 1 and int(a.foe.max_hp) == most + rich, "Eat the Rich grows it by %d: %d" % [rich, int(a.foe.max_hp)])
	check(moves_named(eat, "Weigh").size() == 2 and int(a.foe.statuses.get("strength", 0)) == 2, "each even roll weighs in and makes it stronger")
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
	fixed(f.foe, [10])
	f.player.statuses.stun = 1
	var gulp: Array = turn(f)
	check(moves_named(gulp, "Gulp").size() == 1 and f.foe.held_gems.size() == 1 and f.player.rail[2] == null, "a 10 swallows that gem off the rail")
	check(moves_named(gulp, "Gulp")[0].effects[0].held.stone_id == "c", "the move says which")
	var killed: Dictionary = hit(f, 9999, ["RED"], 0)
	check(f.player.rail[2] is Dictionary and str(f.player.rail[2].id) == "c" and not killed.get("returned_gems", []).is_empty(), "killing the Mimic puts the gem back")
	check(int(f.player.raw_drops) == 1 and bool(killed.get("raw_drop", false)), "and it drops a raw stone for the killer")
	## The Collector walks in with a Strike and a Bulwark of its own, takes a gem it can use
	## on a pair, and fires everything it holds on a 6.
	var c: Dictionary = setup(["THE_COLLECTOR"], 1, {}, rail)
	check(c.foe.held_gems.map(func(h: Dictionary) -> String: return str(h.stone.skill)) == ["STRIKE", "BULWARK"], "the Collector comes holding a Strike and a Bulwark")
	fixed(c.foe, [3, 3, 1], [6, 6, 6])
	c.player.statuses.stun = 1
	var take: Array = turn(c)
	check(moves_named(take, "Acquire").size() == 1 and c.foe.held_gems.size() == 3 and c.player.rail[1] == null, "a pair takes the nine-carat Guard, a gem it can use")
	fixed(c.foe, [6, 2, 1], [6, 6, 6])
	c.player.statuses.stun = 1
	c.player.block = 0
	var had: int = int(c.player.hp)
	var show: Array = turn(c)
	var exhibit: Array = moves_named(show, "Exhibit")
	var kinds: Array = exhibit[0].effects.map(func(e: Dictionary) -> String: return str(e.kind)) if not exhibit.is_empty() else []
	check(exhibit.size() == 1 and kinds.count("damage") == 1 and kinds.count("block") == 2, "a 6 fires the Strike, the Bulwark and the Guard it holds: %s" % str(kinds))
	check(int(c.player.hp) < had and int(c.foe.block) > 0, "the Strike hurts the party and the blocks are the Collector's")
	var returned: Dictionary = hit(c, 9999, ["RED"], 0)
	check(c.player.rail[1] is Dictionary and str(c.player.rail[1].id) == "b" and returned.get("returned_gems", []).size() == 1, "killing it gives back only what it took")
	var lone: Dictionary = setup(["THE_COLLECTOR"], 1, {}, [stone("STRIKE", "only")])
	fixed(lone.foe, [2, 2, 1], [6, 6, 6])
	lone.player.statuses.stun = 1
	var spared: Array = turn(lone)
	check(bool(moves_named(spared, "Acquire")[0].effects[0].get("nothing", false)) and lone.player.rail[0] is Dictionary, "it will not take a rail's only gem")
	## An Entropy Eye buries the socket under the heaviest gem, and its 1 unmakes a die.
	var e: Dictionary = setup(["ENTROPY_EYE"], 1, {}, rail)
	fixed(e.foe, [12])
	e.player.statuses.stun = 1
	var stare: Array = turn(e)
	check(moves_named(stare, "Stare").size() == 1 and int(moves_named(stare, "Gaze")[0].effects[0].raw) == 12, "a crown stares, and the gaze hits for the roll")
	fixed(e.foe, [1], [12])
	DeepBattle.force_lock(e.state)
	check(e.player.buried.is_empty(), "burial clears at the turn start that follows")
	var again: Dictionary = DeepBattle._apply(e.state, e.foe, {"kind": "bury_socket", "target": "heroes", "amount": 1, "pick": "heaviest"}, e.rng.dice)[0]
	check(int(again.get("socket", -1)) == 1 and e.player.buried.has(1), "the nine-carat Guard's socket goes under rubble")
	e.player.statuses.stun = 1
	var unmake: Array = turn(e)
	check(moves_named(unmake, "Unmake").size() == 1 and e.player.dice.size() == 4, "a 1 unmakes one of the five dice")
	fixed(e.foe, [5], [12])
	turn(e)
	check(e.player.dice.size() == 4 and e.player.hand.size() == 4, "it stays gone for the fight")
	check(DeepBattle.dice_after_fight(e.player).size() == 5, "and is back when the fight is over")

func bursts_and_swelling() -> void:
	var f: Dictionary = setup(["PUFFBALL"])
	check(int(DeepContent.creature("PUFFBALL").hp) == 30 and str(DeepContent.creature("PUFFBALL").dice[0]) == "D6", "the Puffball has 30 health and a d6")
	fixed(f.foe, [3], [6])
	turn(f)
	turn(f)
	check(int(f.foe.swell) == 6, "it swells by its roll each action: %d" % int(f.foe.swell))
	fixed(f.foe, [6], [6])
	turn(f)
	check(int(f.foe.swell) == 12 and int(f.foe.statuses.get("regeneration", 0)) >= 5, "a 6 swells it and it regenerates: %s" % str(f.foe.statuses))
	f.foe.block = 0
	var killed: Dictionary = hit(f, 9999)
	check(int(f.player.statuses.get("poison", 0)) == 12 and killed.get("deathburst", [])[0].move == "Burst", "its burst poisons the party for its swelling")
	var s: Dictionary = setup(["SPORE_SLIME"])
	s.foe.statuses.poison = 999
	s.foe.hp = 1
	var tick: Dictionary = DeepBattle._poison_tick(s.state, s.foe)
	check(bool(tick.get("killed", false)) and int(s.player.statuses.get("poison", 0)) == 3, "a Spore Slime that dies to poison still bursts")
	var ooze: Dictionary = setup(["SPORE_SLIME"])
	fixed(ooze.foe, [3], [8])
	var oozed: Array = turn(ooze)
	var ooze_kinds: Array = moves_named(oozed, "Ooze")[0].effects.map(func(e: Dictionary) -> String: return str(e.kind)) if not moves_named(oozed, "Ooze").is_empty() else []
	check(ooze_kinds == ["damage", "poison"], "a Spore Slime's ooze hits and poisons: %s" % str(ooze_kinds))
	var weaver: Dictionary = setup(["MYCEL_WEAVER"])
	fixed(weaver.foe, [3, 1], [4, 4])
	turn(weaver)
	check(int(weaver.player.statuses.get("poison", 0)) == 3, "a Mycel Weaver poisons for each roll, 3 and 1, and the tick takes one: %d" % int(weaver.player.statuses.get("poison", 0)))
	## A Root Horror drinks its poison away, and a pair grows it.
	var r: Dictionary = setup(["ROOT_HORROR"])
	r.foe.statuses.poison = 7
	r.foe.hp = 10
	fixed(r.foe, [4, 1, 2], [4, 4, 4])
	var drink: Array = turn(r)
	check(moves_named(drink, "Drink").size() == 1 and int(r.foe.statuses.poison) == 0 and int(r.foe.hp) == 18, "a 4 heals 8 and sheds every stack of poison")
	var grow: Dictionary = setup(["ROOT_HORROR"])
	fixed(grow.foe, [2, 2, 1], [4, 4, 4])
	var grown: Array = turn(grow)
	check(moves_named(grown, "Grow").size() == 1 and int(grow.foe.max_hp) == 1250 and int(grow.foe.hp) == 1250 and int(grow.foe.statuses.get("strength", 0)) == 2, "a pair of 2s grows it by a quarter and 2 Strength: %d / %s" % [int(grow.foe.max_hp), str(grow.foe.statuses)])
	## The Spore Mother hatches a Weaver on every 1, and sheds everything at half health, once.
	var m: Dictionary = setup(["THE_SPORE_MOTHER"])
	m.foe.statuses.ward = 0
	fixed(m.foe, [1, 3, 2], [6, 6, 6])
	var brood: Array = turn(m)
	check(moves_named(brood, "Brood").size() == 1 and m.state.enemies.size() == 2 and str(m.state.enemies[1].key) == "MYCEL_WEAVER", "a 1 hatches a Mycel Weaver")
	m.foe.statuses.poison = 9
	m.foe.statuses.curse = 3
	m.foe.block = 0
	var half: Dictionary = hit(m, int(m.foe.hp) - int(m.foe.max_hp) / 2)
	check(half.get("thresholds", []).size() == 1 and int(m.foe.statuses.get("poison", 0)) == 0 and int(m.foe.statuses.get("curse", 0)) == 0, "at half health it sheds its poison and its curse at once: %s" % str(m.foe.statuses))
	m.foe.statuses.poison = 4
	check(not hit(m, 10).has("thresholds") and int(m.foe.statuses.poison) == 4, "and only once")
	var h: Dictionary = setup(["THE_HEARTROT"])
	fixed(h.foe, [1, 1, 1], [10, 10, 10])
	turn(h)
	check(h.state.enemies.size() == 4 and int(h.player.statuses.get("festering", 0)) >= 1, "its tendrils came with it, and the party festers")

func charge_and_release() -> void:
	## Near death the Prismarch gathers light every other action: it takes half meanwhile, and
	## throws everything it was dealt back at every player.
	var f: Dictionary = setup(["THE_PRISMARCH"])
	for escort in f.state.enemies.slice(1):
		escort.hp = 0
	f.foe.hp = int(f.foe.max_hp) * 30 / 100
	f.foe.turns_acted = 1
	DeepCreatures.prepare(f.foe)
	fixed(f.foe, [1, 1], [12, 20])
	var gather: Array = turn(f)
	check(moves_named(gather, "Gather Light").size() == 1 and DeepCreatures.charge_turns(f.foe) == 1, "near death it gathers light for an action")
	f.foe.block = 0
	var guarded: Dictionary = hit(f, 40)
	check(int(guarded.hp_loss) == 20 and bool(guarded.get("guarded", false)), "while it gathers it takes half: %d" % int(guarded.hp_loss))
	f.player.block = 0
	var loose: Array = turn(f)
	var release: Array = moves_named(loose, "Prismatic Lance")
	check(release.size() == 1 and bool(release[0].get("release", false)) and int(release[0].effects[0].hp_loss) == 40, "then it throws the whole 40 back: %s" % str(release[0].effects if not release.is_empty() else []))
	check(DeepCreatures.charge_turns(f.foe) == 0 and moves_named(loose, "Gather Light").is_empty(), "and rests an action before it gathers again")
	var lancet: Array = DeepContent.creature("THE_PRISMARCH").phases[0].moves.filter(func(m: Dictionary) -> bool: return str(m.name) == "Lancet")
	check(str(lancet[0].effects[0].target) == "heroes", "its Lancet hits every player")

func strength_heads_and_empowerment() -> void:
	var f: Dictionary = setup(["SLAG_HOUND", "FORGE_IMP"])
	fixed(f.foe, [2, 2])
	fixed(f.state.enemies[1], [1, 3], [4, 4])
	var howl: Array = turn(f)
	check(moves_named(howl, "Howl").size() == 1, "a pair howls")
	check(int(f.foe.statuses.get("strength", 0)) == 1 and int(f.state.enemies[1].statuses.get("strength", 0)) == 1, "the howl makes every creature stronger")
	var cackles: Array = moves_named(howl, "Cackle")
	check(cackles.size() == 2 and cackles.all(func(e: Dictionary) -> bool: return str(e.effects[0].kind) == "burn"), "the imp's Cackle sets the party burning")
	var maul: Array = moves_named(howl, "Maul")
	check(maul.size() == 2 and maul.all(func(e: Dictionary) -> bool: return bool(e.effects[0].get("piercing", false))), "Maul ignores block")
	fixed(f.foe, [1, 2])
	var later: Array = turn(f)
	check(moves_named(later, "Maul").map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [2, 3], "the Strength lasts: every maul hits 1 harder")
	var h: Dictionary = setup(["CRYSTAL_HYDRA"])
	fixed(h.foe, [5, 5, 2])
	turn(h)
	check(h.foe.dice.size() == 4, "a pair grows a fourth head")
	fixed(h.foe, [5, 5, 5, 5])
	turn(h)
	check(h.foe.dice.size() == 5, "and a fifth")
	fixed(h.foe, [5, 5, 5, 5, 5])
	var full: Array = turn(h)
	check(h.foe.dice.size() == 5 and bool(moves_named(full, "Grow a Head")[0].effects[0].get("nothing", false)), "five heads at most")
	var c: Dictionary = setup(["CROUPIER_CRAB"])
	c.player.block = 0
	fixed(c.foe, [20])
	var double: Array = turn(c)
	check(moves_named(double, "Double").size() == 1 and int(c.foe.empowered) == 100 and int(moves_named(double, "Deal")[0].effects[0].raw) == 10, "a 20 empowers the next attack; this one dealt half of 20")
	fixed(c.foe, [10])
	var next: Array = turn(c)
	check(int(moves_named(next, "Deal")[0].effects[0].raw) == 10 and int(c.foe.empowered) == 0, "the next Deal is doubled (5 → 10) and the empowerment spent")
	c.player.gold = 0
	fixed(c.foe, [1])
	var nothing: Array = turn(c)
	check(moves_named(nothing, "Nothing").size() == 1 and int(c.foe.statuses.get("stun", 0)) == 1 and int(c.player.gold) == 10, "a 1 stuns the crab and drops ten pyrite")
	## The Anvil Knight tempers itself on an odd roll: Strength equal to the roll.
	var k: Dictionary = setup(["THE_ANVIL_KNIGHT"])
	fixed(k.foe, [3, 4], [10, 10])
	var temper: Array = turn(k)
	check(moves_named(temper, "Temper").size() == 1 and int(k.foe.statuses.get("strength", 0)) == 3, "a 3 tempers it to Strength 3")
	check(moves_named(temper, "Bulwark").size() == 1 and int(k.foe.block) >= 20, "a 4 raises a 20-block bulwark: %d" % int(k.foe.block))
	fixed(k.foe, [4, 2], [10, 10])
	var hammer: Array = turn(k)
	check(moves_named(hammer, "Hammer").map(func(e: Dictionary) -> int: return int(e.effects[0].raw)) == [7, 5], "and every hammer after hits 3 harder")

func the_refractor_feeds_on_colour() -> void:
	## A Refractor gains a point of Strength the first time it sees each colour fire.
	var f: Dictionary = setup(["REFRACTOR"], 1, {}, [stone("STRIKE", "red"), stone("RIPOSTE", "blue"), stone("STRIKE", "red2")])
	f.player.block = 0
	fixed(f.foe, [3], [12])
	var events: Array = turn(f)
	var fed: Array = []
	for event in of(events, "gem_fire"):
		fed.append_array(event.get("fed", []))
	check(fed.size() == 2 and int(f.foe.statuses.get("strength", 0)) == 2, "red and blue make it 2 stronger, a second red nothing: %s" % str(fed))
	var split: Array = moves_named(events, "Split Light")
	check(split.size() == 1 and split[0].effects.size() == 3 and split[0].effects.all(func(e: Dictionary) -> bool: return int(e.raw) == 3), "a 3 splits into three hits of 1 + its Strength: %s" % str(split[0].effects.map(func(e: Dictionary) -> int: return int(e.raw)) if not split.is_empty() else []))
	f.player.rail = [null, null, null]
	fixed(f.foe, [10], [12])
	f.foe.block = 0
	var wall: Array = turn(f)
	check(moves_named(wall, "Prism Wall").size() == 1 and int(f.foe.block) == 20, "a 10 walls it in ten block for each point of Strength: %d" % int(f.foe.block))

func dice_for_the_fight_and_for_good() -> void:
	## A Forge Imp's heat treatment shrinks a die for the fight; it is itself again after.
	var f: Dictionary = setup(["FORGE_IMP"])
	fixed(f.foe, [2, 2], [4, 4])
	turn(f)
	check(shapes(f.player.dice).count("D4") == 1, "a pair shrinks one of the five dice: %s" % str(shapes(f.player.dice)))
	check(shapes(DeepBattle.dice_after_fight(f.player)) == ["D6", "D6", "D6", "D6", "D6"], "and the fight gives it back")
	## The Infinite Void's dread shrinks every die for the fight.
	var v: Dictionary = setup(["THE_UNMADE"])
	DeepBattle._apply(v.state, v.foe, {"kind": "downgrade_die", "target": "heroes", "amount": 1, "pick": "all"}, v.rng.dice)
	check(shapes(v.player.dice) == ["D4", "D4", "D4", "D4", "D4"], "Existential Dread shrinks every die")
	check(shapes(DeepBattle.dice_after_fight(v.player)) == ["D6", "D6", "D6", "D6", "D6"], "for the fight only")
	## The Smelter burns the face a die shows blank for the fight.
	var s: Dictionary = setup(["THE_SMELTER"])
	s.foe.statuses.ward = 0
	fixed(s.foe, [8, 1], [8, 8])
	var melt: Array = turn(s)
	var blanks: Callable = func(dice: Array) -> int:
		var count: int = 0
		for die in dice:
			count += die.faces.filter(func(x: Dictionary) -> bool: return str(x.get("kind", "plain")) == "blank").size()
		return count
	check(moves_named(melt, "Melt").size() == 1 and int(blanks.call(s.player.dice)) == 1, "an 8 burns one showing face blank")
	check(int(blanks.call(DeepBattle.dice_after_fight(s.player))) == 0, "and the fight gives it back")
	## The Glazier's cut is for good.
	var g: Dictionary = setup(["THE_GLAZIER"])
	g.foe.statuses.ward = 0
	fixed(g.foe, [3, 3], [8, 10])
	turn(g)
	var tops: Array = DeepBattle.dice_after_fight(g.player).map(func(d: Dictionary) -> int: return DeepDice.top(d))
	check(tops.count(5) == 1, "a pair cuts a point off the top of a die, and it stays cut: %s" % str(tops))
	## The Gardener's 20 prunes every face the party's dice show, for good.
	var p: Dictionary = setup(["THE_GARDENER"])
	p.foe.statuses.ward = 0
	fixed(p.foe, [20], [20])
	var showing: Dictionary = {}
	for roll in p.player.hand:
		for die in p.player.dice:
			if str(die.id) == str(roll.die_id):
				showing[str(die.id)] = [int(roll.face), int(die.faces[int(roll.face)].value)]
	var prune: Array = turn(p)
	check(moves_named(prune, "Prune").size() == 1, "a 20 prunes")
	var kept: Array = DeepBattle.dice_after_fight(p.player)
	var ground: bool = true
	for die in kept:
		var was: Array = showing.get(str(die.id), [0, 1])
		if int(die.faces[int(was[0])].value) != maxi(1, int(was[1]) - 1):
			ground = false
	check(ground and kept.size() == 5, "every face that was showing lost a point, and keeps it lost")

func echoes_and_the_remembered() -> void:
	var f: Dictionary = setup(["VOID_ECHO"], 1, {"tough": false})
	check(not str(f.foe.echo_of).is_empty() and str(f.foe.echo_of) != "VOID_ECHO", "a Void Echo copies another creature: %s" % str(f.foe.echo_of))
	var source: Dictionary = DeepContent.creature(str(f.foe.echo_of))
	check(not bool(source.get("warden", false)) and f.foe.dice.size() == source.dice.size() and f.foe.moves.size() == source.moves.size(), "its dice and moves are the original's")
	check(str(f.foe.name).begins_with("Void Echo (") and int(f.foe.max_hp) == int(source.hp), "named for what it echoes, with its health")
	var allowed: Array = []
	for mine_key in ["QUARRY", "SEEPS", "GLASS_VEINS", "WARRENS"]:
		for band in DeepContent.mine(mine_key).bands:
			allowed.append_array(band.creatures.keys())
	check(allowed.has(str(f.foe.echo_of)), "it echoes something from the first four mines")
	var r: Dictionary = setup(["THE_DRILL"], 1, {"remembered": true, "extra_trait": "sturdy", "warden": true})
	check(str(r.foe.name) == "The Remembered The Drill" and DeepCreatures.trait_value(r.foe, "sturdy", 0) == 25 and str(r.foe.remembered) == "sturdy", "a Rift Warden is a boss remembered with one trait more")
	var s: Dictionary = setup(["THE_DRILL"], 1, {"remembered": true, "extra_trait": "steadfast", "warden": true})
	check(DeepCreatures.has_trait(s.foe, "steadfast") and DeepCreatures.has_trait(s.foe, "roll_for_you"), "a remembered trait sits beside its own")
	check(DeepContent.REMEMBERED_TRAITS == ["steadfast", "sturdy", "split_on_big_hit"], "the Remembered are Steadfast, Sturdy or Splitting")
	var split: Dictionary = setup(["THE_DRILL"], 1, {"remembered": true, "extra_trait": "split_on_big_hit", "warden": true})
	split.foe.block = 0
	var halved: Dictionary = hit(split, 450)
	check(not str(halved.get("split", "")).is_empty() and DeepBattle.living(split.state.enemies).size() == 2, "a remembered boss that splits breaks in two under a big blow")
	## The Infinite Void comes with no dice and gains a d20 as each action opens.
	var u: Dictionary = setup(["THE_UNMADE"])
	check(str(u.foe.name) == "The Infinite Void" and u.foe.dice.is_empty(), "the Infinite Void comes with no dice")
	var first: Array = turn(u)
	check(moves_named(first, "Expansion").size() == 1 and u.foe.dice.size() == 1 and of(first, "enemy_roll").size() == 1, "its first action grows a d20 and throws it")
	var second: Array = turn(u)
	check(u.foe.dice.size() == 2 and of(second, "enemy_roll").size() == 2, "its second throws two")
	check(DeepCreatures.has_trait(u.foe, "sturdy") and DeepCreatures.has_trait(u.foe, "backlash") and not DeepCreatures.has_trait(u.foe, "rising"), "Sturdy and Backlash, and no longer Rising")
	for _i in range(5):
		turn(u)
	check(u.foe.dice.size() == 5, "five d20s at most: %d" % u.foe.dice.size())

func the_hollow_crown() -> void:
	var f: Dictionary = setup(["THE_HOLLOW_CROWN"])
	f.foe.statuses.ward = 0
	check(f.foe.dice.size() == 1 and str(f.foe.dice[0].shape) == "D6", "the Hollow Crown rolls one d6")
	fixed(f.foe, [1], [6])
	var stumble: Array = turn(f)
	check(moves_named(stumble, "Stumble").size() == 1 and moves_named(stumble, "Crush").is_empty() and of(stumble, "enemy_roll").size() == 1, "a 1 stuns it: nothing else happens")
	check(int(f.foe.statuses.get("stun", 0)) == 0, "and it does not lose its next action for it")
	fixed(f.foe, [3], [6])
	f.foe.block = 0
	var crush: Array = turn(f)
	check(moves_named(crush, "Crush").size() == 1 and int(f.foe.block) == 3 and moves_named(crush, "Rise").is_empty(), "a 3 hits and shields for 3, and is not high")
	fixed(f.foe, [5], [6])
	var rise: Array = turn(f)
	var rolls: Array = of(rise, "enemy_roll")
	check(moves_named(rise, "Rise").size() >= 1 and int(f.foe.dice_upgrade) >= 1, "a 5 grows its die")
	check(rolls.size() >= 2 and int(rolls[1].roll.top) == 8, "and throws it again, now a d8: %s" % str(rolls.map(func(e: Dictionary) -> int: return int(e.roll.top))))
	check(rolls.size() <= 4 and f.foe.extra_dice.is_empty(), "three throws more at most, and none carried into the next action")
	fixed(f.foe, [6], [6])
	f.foe.dice_upgrade = 0
	f.player.block = 0
	var crowned: Array = turn(f)
	check(moves_named(crowned, "Crowned").size() == 1, "a 6 crowns it")
	## At half health two Gilded Magpies answer its call at once.
	f.foe.hp = int(f.foe.max_hp) * 55 / 100
	f.foe.block = 0
	var called: Dictionary = hit(f, 60)
	check(called.get("thresholds", []).size() == 1 and DeepBattle.living(f.state.enemies).size() == 3, "falling to half calls two Gilded Magpies at once: %d standing" % DeepBattle.living(f.state.enemies).size())
	check(DeepBattle.living(f.state.enemies).slice(1).all(func(e: Dictionary) -> bool: return str(e.key) == "GILDED_MAGPIE"), "and they are Gilded Magpies")

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
