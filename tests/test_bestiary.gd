extends SceneTree
## The deeper mines' creatures and the mechanics they fight with (docs/BESTIARY.md),
## exercised through real battle steps with fixed dice.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	turn_triggers()
	summons_and_escorts()
	burrow_and_emerge()
	adapt_and_mirror()
	fester_corrode_scorch()
	steadfast_and_bedrock()
	backlash_and_unmake()
	locks_inversion_dread()
	theft_and_flight()
	gems_held_and_buried()
	bursts_and_swelling()
	charge_and_release()
	rally_heads_and_empowerment()
	echoes_and_the_remembered()
	the_hollow_crown_reads_one_die()
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

func adapt_and_mirror() -> void:
	var f: Dictionary = setup(["PRISM_GOLEM"])
	f.foe.block = 0
	hit(f, 10, ["RED"])
	hit(f, 4, ["BLUE"])
	fixed(f.foe, [2])
	var events: Array = turn(f)
	var refract: Array = moves_named(events, "Refract")
	check(refract.size() == 1 and str(refract[0].effects[0].get("color", "")) == "RED", "Refract learns the colour that hurt it most this turn: %s" % str(refract[0].effects if not refract.is_empty() else []))
	check(str(f.foe.adapt.get("color", "")) == "RED" and int(f.foe.adapt.get("pct", 0)) == 50, "it has adapted to Red by half")
	check(f.foe.hurt_by_color.is_empty(), "what hurt it this turn is forgotten once it has acted")
	var red: Dictionary = hit(f, 20, ["RED"])
	var blue: Dictionary = hit(f, 20, ["BLUE"])
	check(int(red.hp_loss) == 10 and str(red.get("adapted", "")) == "RED" and int(blue.hp_loss) == 20, "Red hits for half, Blue in full: %d / %d" % [int(red.hp_loss), int(blue.hp_loss)])
	fixed(f.foe, [1])
	var next: Array = turn(f)
	check(f.foe.adapt.is_empty() and of(next, "enemy_begin")[0].get("adapt_ended", false), "the adaptation ends when it acts again")
	## A mirror sends the colour back at its owner and takes nothing.
	var k: Dictionary = setup(["THE_KALEIDOSCOPE"])
	fixed(k.foe, [1, 2, 3])
	turn(k)
	check(bool(k.foe.adapt.get("reflect", false)) and str(k.foe.adapt.get("color", "")) in DeepContent.color_KEYS, "each action the Kaleidoscope shows a colour and mirrors it")
	var colour: String = str(k.foe.adapt.color)
	var before: int = int(k.foe.hp)
	var had: int = int(k.player.hp)
	k.player.block = 0
	var mirrored: Dictionary = hit(k, 12, [colour])
	check(int(k.foe.hp) == before and mirrored.has("mirrored") and int(mirrored.mirrored.hp_loss) == 12 and int(k.player.hp) == had - 12, "a gem of the mirrored colour hits its owner instead: %s" % str(mirrored))
	var other: String = "RED" if colour != "RED" else "BLUE"
	var through: Dictionary = hit(k, 12, [other])
	check(int(through.hp_loss) == 12, "other colours land")

func fester_corrode_scorch() -> void:
	var f: Dictionary = setup(["CAP_SHAMBLER"])
	f.player.statuses.festering = 2
	f.player.hp = 500
	check(DeepBattle._heal(f.player, 10) == 5, "Festering halves healing")
	f.player.statuses.scorched = 1
	apply(f, {"kind": "block", "target": "self", "amount": 9}, true)
	check(int(f.player.block) == 5, "Scorched halves block gained, rounded up: %d" % int(f.player.block))
	## Corroded takes half of the block kept at turn start, Retain included.
	f.player.statuses.corroded = 1
	f.player.statuses.retain = 20
	f.player.block = 10
	f.player.statuses.erase("scorched")
	var opened: Dictionary = DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(int(f.player.block) == 5 and opened.afflicted.any(func(a: Dictionary) -> bool: return str(a.kind) == "corroded" and int(a.amount) == 5), "Corroded loses half the kept block as the turn opens: %d" % int(f.player.block))
	## They count down at the tick, except on the turn an enemy applied them.
	f.player.statuses.festering = 2
	f.player.statuses.corroded = 2
	f.player.statuses.scorched = 2
	fixed(f.foe, [1])
	turn(f)
	check(int(f.player.statuses.festering) == 1 and int(f.player.statuses.corroded) == 1 and int(f.player.statuses.scorched) == 1, "each counts down one a turn")
	var fresh: Dictionary = setup(["CAP_SHAMBLER"])
	fixed(fresh.foe, [9])
	var cloud: Array = turn(fresh)
	check(moves_named(cloud, "Spore Cloud").size() == 1 and int(fresh.player.statuses.get("festering", 0)) == 2, "a Spore Cloud on 8+ festers the party for 2, and a fresh application survives the tick that follows")
	## A Kiln Wyrm's heat is on everyone at the start of every turn while it lives.
	var w: Dictionary = setup(["THE_KILN_WYRM"])
	check(int(w.player.statuses.get("corroded", 0)) == 1, "the Kiln Wyrm's aura corrodes the party from the first turn")
	w.foe.hp = int(w.foe.max_hp) / 2
	DeepCreatures.prepare(w.foe)
	w.player.statuses.erase("corroded")
	DeepBattle._begin_turn(w.state, w.rng.dice, w.rng.creatures)
	check(int(w.player.statuses.get("corroded", 0)) == 0, "hurt below 60%, it gives up the aura")

func steadfast_and_bedrock() -> void:
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
	## Bedrock caps a single hit at a share of its health.
	var g: Dictionary = setup(["GEODE_GOLEM"])
	g.foe.max_hp = 100
	g.foe.hp = 100
	g.foe.block = 0
	var capped: Dictionary = hit(g, 60)
	check(int(capped.hp_loss) == 25 and int(capped.get("capped", 0)) == 35, "no single hit takes more than a quarter off a Geode Golem: %s" % str(capped))
	var small: Dictionary = hit(g, 10)
	check(int(small.hp_loss) == 10 and not small.has("capped"), "a smaller hit lands in full")
	## The Hollow Crown's Bedrock is a trait of its opening phase only.
	var c: Dictionary = setup(["THE_HOLLOW_CROWN"])
	check(DeepCreatures.trait_value(c.foe, "bedrock", 0) == 15, "above 60% the Hollow Crown is Bedrock 15%")
	c.foe.hp = int(c.foe.max_hp) / 2
	DeepCreatures.prepare(c.foe)
	check(DeepCreatures.trait_value(c.foe, "bedrock", 0) == 0, "cracked open, it loses its Bedrock")

func backlash_and_unmake() -> void:
	## With a Riftling Swarm in the room, every gem after the sixth to fire costs a point.
	var rail: Array = []
	for i in range(5):
		rail.append(stone("STRIKE", "strike%d" % i))
	var riders: Array = [[], [], [], [], []]
	for i in range(3):
		riders[4].append(DeepStone.make("STRIKE", 1, 4, 3, ["VOID"], {}, "void%d" % i))
	var f: Dictionary = setup(["RIFTLING_SWARM"], 1, {}, rail, riders)
	fixed(f.foe, [1, 1, 1, 1])
	f.player.hp = 100
	f.player.max_hp = 100
	var events: Array = turn(f)
	var fired: Array = of(events, "gem_fire").filter(func(e: Dictionary) -> bool: return str(e.unit) == "p0")
	check(fired.size() == 8, "eight Strikes fire: %d" % fired.size())
	var bitten: Array = fired.filter(func(e: Dictionary) -> bool: return int(e.get("backlash", 0)) > 0)
	check(bitten.size() == 2 and int(bitten[0].fired_count) == 7, "the seventh and eighth gems cost their owner a point each: %d" % bitten.size())
	check(int(f.player.hp) == 100 - 2 - 4, "two points of Backlash and four Nibbles: hp %d" % int(f.player.hp))
	## Unmade: Resonance held at nothing through the next rail.
	var u: Dictionary = setup(["ENTROPY_EYE"], 1, {}, rail.slice(0, 3))
	fixed(u.foe, [11])
	var eye: Array = turn(u)
	check(moves_named(eye, "Unmake").size() == 1 and int(u.player.statuses.get("unmade", 0)) == 1 and int(u.player.resonance) == 0, "an 11 on the Eye unmakes the party")
	fixed(u.foe, [1], [12])
	var held: Array = turn(u)
	var dark: Array = of(held, "gem_fire").filter(func(e: Dictionary) -> bool: return str(e.unit) == "p0")
	check(dark.size() == 3 and dark.all(func(e: Dictionary) -> bool: return int(e.resonance) == 0 and bool(e.get("unmade", false))), "every gem fires but the chain counts for nothing")
	check(int(of(held, "rail_end")[0].resonance) == 0 and int(u.player.statuses.get("unmade", 0)) == 0, "the rail closes at nothing, and the Unmaking is spent")
	var free: Array = turn(u)
	check(int(of(free, "rail_end")[0].resonance) == 5, "the rail after builds Resonance again: three Strikes in harmony are 5, got %d" % int(of(free, "rail_end")[0].resonance))

func locks_inversion_dread() -> void:
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
	## A Salamander's lick inverts the two highest dice next turn.
	var s: Dictionary = setup(["SALAMANDER"])
	fixed(s.foe, [3])
	var lick: Array = turn(s)
	check(moves_named(lick, "Invert").size() == 1 and s.player.get("inverted_dice", []).size() == 2, "two dice shifted parity: %s" % str(s.player.get("inverted_dice", [])))
	for roll in s.player.hand:
		if s.player.inverted_dice.has(str(roll.die_id)):
			check(bool(roll.get("inverted", false)), "an inverted die says so")
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
	## A Lamprey Knot drinks from the purse itself.
	var l: Dictionary = setup(["LAMPREY_KNOT"])
	l.player.ore = 50
	fixed(l.foe, [4, 4, 4])
	var drink: Array = turn(l)
	check(moves_named(drink, "Drink").size() == 1 and int(l.foe.stolen_gold) == 5 and DeepRules.pyrite(l.player) == 45, "a triple drinks five pyrite out of the party's purse")
	l.foe.block = 0
	var killed: Dictionary = hit(l, 9999)
	check(int(killed.get("recovered_gold", 0)) == 5 and int(l.player.gold) == 5, "killing it gets the pyrite back")
	## The Assayer's tax is a tenth of each purse, and the Hollow Crown heals by what it takes.
	var a: Dictionary = setup(["THE_ASSAYER"], 2)
	a.state.players[0].ore = 100
	a.state.players[1].ore = 40
	fixed(a.foe, [5, 5])
	var tax: Array = turn(a)
	check(moves_named(tax, "Tax").size() == 1 and int(a.foe.stolen_gold) == 14, "a tenth of 100 and of 40 is 14: %d" % int(a.foe.stolen_gold))
	var weigh: Array = moves_named(tax, "Weigh")
	check(weigh.size() == 2 and int(weigh[0].effects[0].raw) == 0, "with no gems on any rail the Assayer's Weigh finds nothing to weigh")

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
	## The Collector takes the finest gem on any rail; a rail's last gem is never taken.
	var c: Dictionary = setup(["THE_COLLECTOR"], 1, {}, rail)
	fixed(c.foe, [6, 1], [6, 12])
	c.player.statuses.stun = 1
	var take: Array = turn(c)
	check(moves_named(take, "Acquire").size() == 1 and c.foe.held_gems.size() == 1 and c.player.rail[1] == null, "a crown takes the nine-carat Guard, its own Ward notwithstanding")
	fixed(c.foe, [3, 3], [8, 12])
	c.player.statuses.stun = 1
	var show: Array = turn(c)
	var exhibit: Array = moves_named(show, "Exhibit")
	check(exhibit.size() == 1 and int(exhibit[0].effects[0].amount) == 5, "Exhibit is five block for the one gem it holds: %s" % str(exhibit[0].effects if not exhibit.is_empty() else []))
	var lone: Dictionary = setup(["THE_COLLECTOR"], 1, {}, [stone("STRIKE", "only")])
	fixed(lone.foe, [6, 1], [6, 12])
	lone.player.statuses.stun = 1
	var spared: Array = turn(lone)
	check(bool(moves_named(spared, "Acquire")[0].effects[0].get("nothing", false)) and lone.player.rail[0] is Dictionary, "it will not take a rail's only gem")
	## An Entropy Eye buries the socket under the heaviest gem.
	var e: Dictionary = setup(["ENTROPY_EYE"], 1, {}, rail)
	fixed(e.foe, [12])
	e.player.statuses.stun = 1
	var stare: Array = turn(e)
	check(moves_named(stare, "Stare").size() == 1, "a crown stares")
	fixed(e.foe, [1])
	DeepBattle.force_lock(e.state)
	check(e.player.buried.is_empty(), "burial clears at the turn start that follows")
	var again: Dictionary = DeepBattle._apply(e.state, e.foe, {"kind": "bury_socket", "target": "heroes", "amount": 1, "pick": "heaviest"}, e.rng.dice)[0]
	check(int(again.get("socket", -1)) == 1 and e.player.buried.has(1), "the nine-carat Guard's socket goes under rubble")

func bursts_and_swelling() -> void:
	var f: Dictionary = setup(["PUFFBALL"])
	fixed(f.foe, [1])
	turn(f)
	turn(f)
	check(int(f.foe.swell) == 4, "two actions of Swell: %d" % int(f.foe.swell))
	f.foe.block = 0
	var killed: Dictionary = hit(f, 9999)
	check(int(f.player.statuses.get("poison", 0)) == 4 and killed.get("deathburst", [])[0].move == "Burst", "its burst poisons the party for its swelling")
	var s: Dictionary = setup(["SPORE_SLIME"])
	s.foe.statuses.poison = 999
	s.foe.hp = 1
	var tick: Dictionary = DeepBattle._poison_tick(s.state, s.foe)
	check(bool(tick.get("killed", false)) and int(s.player.statuses.get("poison", 0)) == 3, "a Spore Slime that dies to poison still bursts")
	## A Root Horror drinks its poison away.
	var r: Dictionary = setup(["ROOT_HORROR"])
	r.foe.statuses.poison = 7
	r.foe.hp = 10
	fixed(r.foe, [12])
	var drink: Array = turn(r)
	check(moves_named(drink, "Drink").size() == 1 and int(r.foe.statuses.poison) == 0 and int(r.foe.hp) == 18, "a crown heals 8 and sheds every stack of poison")
	var h: Dictionary = setup(["THE_HEARTROT"])
	h.foe.statuses.poison = 8
	fixed(h.foe, [1, 1])
	turn(h)
	turn(h)
	var third: Array = turn(h)
	check(moves_named(third, "Slough").size() == 1 and int(h.foe.statuses.poison) == 2, "every third action the Heartrot sloughs off half its poison: %d" % int(h.foe.statuses.poison))
	check(h.state.enemies.size() == 4 and int(h.player.statuses.get("festering", 0)) >= 1, "its tendrils came with it, and the party festers")

func charge_and_release() -> void:
	var f: Dictionary = setup(["THE_PRISMARCH"])
	for escort in f.state.enemies.slice(1):
		escort.hp = 0
	f.foe.hp = int(f.foe.max_hp) * 30 / 100
	DeepCreatures.prepare(f.foe)
	f.state.party_best_turn = 40
	f.player.block = 100
	fixed(f.foe, [1, 1])
	var gather: Array = turn(f)
	check(moves_named(gather, "Gather Light").size() == 1 and DeepCreatures.charge_turns(f.foe) == 2, "near death it gathers light for two actions")
	var wait: Array = turn(f)
	check(int(of(wait, "enemy_begin")[0].get("charge", {}).get("turns", 0)) == 1 and DeepCreatures.charge_turns(f.foe) == 1, "one action nearer")
	var loose: Array = turn(f)
	var release: Array = moves_named(loose, "Prismatic Lance")
	check(release.size() == 1 and bool(release[0].get("release", false)) and int(release[0].effects[0].hp_loss) == 20 and int(release[0].effects[0].absorbed) == 0, "then half the party's best turn, through block: %s" % str(release[0].effects if not release.is_empty() else []))
	check(DeepCreatures.charge_turns(f.foe) == 2, "and it begins gathering again")
	## Taking a quarter off it meanwhile breaks the charge.
	f.foe.block = 0
	hit(f, int(f.foe.max_hp) / 4 + 1)
	var broken: Array = turn(f)
	check(bool(of(broken, "enemy_begin")[0].get("charge", {}).get("broken", false)), "a quarter of its health lost breaks the charge")

func rally_heads_and_empowerment() -> void:
	var f: Dictionary = setup(["SLAG_HOUND", "FORGE_IMP"])
	fixed(f.foe, [2, 2])
	fixed(f.state.enemies[1], [1, 3])
	var howl: Array = turn(f)
	check(moves_named(howl, "Howl").size() == 1, "a pair howls")
	var cackles: Array = moves_named(howl, "Cackle")
	check(cackles.size() == 2 and cackles.all(func(e: Dictionary) -> bool: return int(e.effects[0].raw) == 4), "the imp's Cackle deals 2 more after the howl: %s" % str(cackles.map(func(e: Dictionary) -> int: return int(e.effects[0].raw))))
	var maul: Array = moves_named(howl, "Maul")
	check(maul.size() == 2 and maul.all(func(e: Dictionary) -> bool: return bool(e.effects[0].get("piercing", false))), "Maul ignores block")
	fixed(f.foe, [1, 2])
	turn(f)
	check(int(f.foe.rally_bonus) == 0 and int(f.state.enemies[1].rally_bonus) == 0, "the rally lasts one turn")
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
	var r: Dictionary = setup(["THE_DRILL"], 1, {"remembered": true, "extra_trait": "bedrock", "warden": true})
	check(str(r.foe.name) == "The Remembered The Drill" and DeepCreatures.trait_value(r.foe, "bedrock", 0) == 25 and str(r.foe.remembered) == "bedrock", "a Rift Warden is a boss remembered with one trait more")
	var s: Dictionary = setup(["THE_DRILL"], 1, {"remembered": true, "extra_trait": "steadfast", "warden": true})
	check(DeepCreatures.has_trait(s.foe, "steadfast") and DeepCreatures.has_trait(s.foe, "roll_for_you"), "a remembered trait sits beside its own")
	var u: Dictionary = setup(["THE_UNMADE"])
	check(DeepCreatures.damage_pct(u.foe) == 100, "the Unmade starts at its mine's strength")
	u.foe.turns_acted = 2
	check(DeepCreatures.damage_pct(u.foe) == 156, "and deals a quarter more every action it has taken: %d%%" % DeepCreatures.damage_pct(u.foe))

func the_hollow_crown_reads_one_die() -> void:
	var f: Dictionary = setup(["THE_HOLLOW_CROWN"])
	f.foe.hp = int(f.foe.max_hp) / 2
	f.foe.statuses.ward = 0
	fixed(f.foe, [2, 16])
	var favour: Array = turn(f)
	check(moves_named(favour, "Favour").size() == 1 and moves_named(favour, "Stumble").is_empty(), "with 2 then 16, only the d20 is read: Favour, no Stumble")
	fixed(f.foe, [16, 2])
	var stumble: Array = turn(f)
	check(moves_named(stumble, "Favour").is_empty() and moves_named(stumble, "Stumble").size() == 1 and int(f.foe.statuses.get("stun", 0)) == 1, "with 16 then 2 it stumbles and stuns itself")

func wording_and_content() -> void:
	## Every move of every creature reads out without a hole in its sentence.
	for key in DeepContent.section("creatures"):
		var def: Dictionary = DeepContent.creature(str(key))
		var all: Array = def.get("moves", []).duplicate()
		for phase in def.get("phases", []):
			all.append_array(phase.get("moves", []))
		for move in all:
			var when: String = DeepCreatures.trigger_words(move)
			check(not when.is_empty() and not when.contains("%"), "%s's %s says when it fires: %s" % [key, move.name, when])
			for effect in move.get("effects", []):
				var what: String = DeepCreatures.effect_words(effect)
				check(not what.is_empty() and not what.contains("%s") and not what.contains("%d"), "%s's %s says what it does: %s" % [key, move.name, what])
	for kind in DeepPatterns.TURN_KINDS:
		check(not DeepPatterns.words({"kind": kind, "amount": 2}, 0).is_empty() and DeepPatterns.words({"kind": kind, "amount": 2}, 0) != "Its trigger.", "%s has words" % kind)
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
