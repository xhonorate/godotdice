extends SceneTree
## The Flawless lines as the November 2026 audit left them: each one does its own thing, says when
## it is really on, and tells the screen what to sparkle.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	counted()
	attacks()
	guards()
	green()
	violet()
	fortune()
	hand_and_rail()
	seams()
	opals()
	transcendent()
	pacing()
	print("Flawless lines: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func setup(foes: int = 3, allies: int = 1, character: String = "ARDOR") -> Dictionary:
	var party: Array = []
	for p in range(allies):
		var bowl: Array = []
		for i in range(5):
			bowl.append(DeepDice.make("D20", "p%d_d%d" % [p, i]))
		var unit: Dictionary = DeepBattle.make_player("p%d" % p, "Player", character, [], bowl)
		unit.passive = {}
		unit.birthstone = {}
		unit.hp = 1000
		unit.max_hp = 1000
		unit.ore = 100
		unit.haul = []
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(19, ["dice", "creatures"])
	var keys: Array = []
	keys.resize(foes)
	keys.fill("CAVE_TICK")
	var state: Dictionary = DeepBattle.begin(party, keys, {"depth": 1}, rng.dice, rng.creatures)
	for foe in state.enemies:
		foe.hp = 1000
		foe.max_hp = 1000
		foe.block = 0
	return {"state": state, "player": state.players[0], "foe": state.enemies[0], "rng": rng}

func rolls(f: Dictionary, values: Array) -> void:
	for i in range(f.player.hand.size()):
		var roll: Dictionary = f.player.hand[i]
		roll.value = int(values[i])
		roll.face = int(values[i]) - 1
		roll.kind = "plain"
		roll.top = 20
		roll.held = false
		roll.rerolls = 1

func equip(f: Dictionary, key: String, flawless: bool = false, cut: int = 4, at: int = 0, carat: int = 1) -> void:
	f.player.sockets[at] = "UNLIT"
	f.player.rail[at] = DeepStone.make(key, carat, cut, 5 if flawless else 3, [], {}, "gem%d" % at)

func fire(f: Dictionary, key: String, values: Array, flawless: bool = true, cut: int = 4, carat: int = 1) -> Dictionary:
	equip(f, key, flawless, cut, 0, carat)
	rolls(f, values)
	f.player.firing_target = f.player.target
	return DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)

func fire_held(f: Dictionary, key: String) -> Dictionary:
	## Fired on a hand nobody rerolled, for the gems that read that.
	equip(f, key, true, 4, 0)
	rolls(f, [1, 2, 3, 4, 5])
	for roll in f.player.hand:
		roll.held = true
	f.player.firing_target = f.player.target
	return DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)

func total_of(event: Dictionary, kind: String) -> int:
	var total: int = 0
	for effect in event.get("effects", []):
		if str(effect.get("kind", "")) == kind:
			total += int(effect.get("amount", 0))
	return total

func has_flagged(event: Dictionary) -> bool:
	return event.get("effects", []).any(func(e: Dictionary) -> bool: return bool(e.get("flawless", false)))

func notes(event: Dictionary, what: String) -> int:
	return event.get("flawless_notes", []).filter(func(n: Dictionary) -> bool: return str(n.get("what", "")) == what).size()

func counted() -> void:
	## A line's own multiplier comes last in the count and only when its condition holds.
	var f: Dictionary = setup()
	var low: Dictionary = fire(f, "EMBER", [1, 2, 2, 3, 3])
	var marks: Array = low.tally.mults.map(func(e: Dictionary) -> String: return str(e.what))
	check(marks.has("flawless") and marks[-1] == "flawless", "an all-low Ember lays its Flawless x2 last in the count: %s" % str(marks))
	check(bool(low.flawless.on) and bool(low.flawless.counted) and int(low.flawless.x) == 2, "and the event says so")
	var mixed: Dictionary = fire(f, "EMBER", [1, 2, 2, 19, 19])
	check(not mixed.tally.mults.any(func(e: Dictionary) -> bool: return str(e.what) == "flawless") and not bool(mixed.flawless.on), "a mixed hand is out of the line's condition: no x2, no sparkle")
	check(int(low.tally.amount) == 2 * int(mixed.tally.amount), "and the figure really is double: %d, %d" % [int(low.tally.amount), int(mixed.tally.amount)])
	## The count's arithmetic comes out exact, the floor taken once.
	f = setup()
	var apex: Dictionary = fire(f, "APEX", [20, 1, 2, 3, 4])
	check(int(apex.tally.amount) == 60, "a crowned Flawless Apex is 20 x 1.5 x 2: %d" % int(apex.tally.amount))
	check(apex.tally.adds.is_empty(), "with nothing left over for the count to add")
	f = setup()
	check(total_of(fire(f, "CROSSCUT", [1, 3, 5, 7, 9]), "damage") == 2 * total_of(fire(f, "CROSSCUT", [1, 3, 5, 7, 2]), "damage") * 5 / 4, "an all-odd Crosscut deals double")
	f = setup()
	check(int(fire(f, "TEMPO", [2, 4, 6, 8, 10]).tally.amount) == 30, "an all-even Tempo gains twice as much: 5 x 2 x 1.5 x 2")
	f = setup()
	var miasma: Dictionary = fire(f, "MIASMA", [2, 4, 6, 8, 10])
	check(int(miasma.tally.mults[-1].x) == 2 and int(f.foe.statuses.poison) == 2 * int(fire(setup(), "MIASMA", [2, 4, 6, 8, 11]).effects[0].amount) * 5 / 4, "an all-even Miasma applies double")

func attacks() -> void:
	## Barrage: only a hit past Block rings, and the event tells the screen how much to hold back.
	var f: Dictionary = setup()
	var open: Dictionary = fire(f, "BARRAGE", [1, 2, 3, 4, 5])
	check(int(open.rung) == 5 and int(open.effects[0].get("rang", 0)) == 1, "every hit of a Flawless Barrage rings 1: %d" % int(open.rung))
	check(bool(open.flawless.quiet), "and it sparkles on the hits, not as it fires")
	f = setup()
	f.foe.block = 100000
	check(int(fire(f, "BARRAGE", [1, 2, 3, 4, 5]).rung) == 0, "a hit the Block soaks rings nothing")
	## Flurry: repeats for every pair; a set of four is two identical pairs.
	f = setup()
	check(int(fire(f, "FLURRY", [4, 4, 2, 2, 9]).effects.size()) == 6, "two pair: 4 + 2 hits")
	check(int(fire(f, "FLURRY", [3, 3, 3, 3, 9]).effects.size()) == 6, "four of a kind is two pairs: 3 + 3 hits")
	var one: Dictionary = fire(f, "FLURRY", [4, 4, 1, 2, 9])
	check(int(one.effects.size()) == 4 and not bool(one.flawless.on), "one pair is the gem as printed, and no sparkle")
	## Hone: kills it lands grow it by 3 for the rest of the run.
	f = setup()
	f.foe.hp = 1
	var hone: Dictionary = fire(f, "HONE", [1, 2, 3, 4, 5], true, 4)
	check(notes(hone, "kill") == 1, "a Flawless Hone's kill is noted")
	check(int(f.player.run_counts.get("gem0:kills", 0)) == 1, "and counted for the run")
	var after: Dictionary = fire(f, "HONE", [1, 2, 3, 4, 5], true, 4)
	check(total_of(after, "damage") == int(float(4 + 1 + 3) * 1.5), "4, one fire, one kill's 3: %d" % total_of(after, "damage"))
	## Spall throws its two lowest again, so what comes after reads new dice.
	f = setup()
	var spall: Dictionary = fire(f, "SPALL", [1, 2, 3, 4, 5])
	var thrown: Array = spall.effects.filter(func(e: Dictionary) -> bool: return str(e.kind) == "rethrow")
	check(thrown.size() >= 2 and has_flagged(spall), "a Flawless Spall throws two dice again, after its own blow")
	check(int(f.player.hand[0].get("rethrown", false)) == 1 and int(f.player.hand[1].get("rethrown", false)) == 1, "the two it read")
	## Temper: Strength adds to Block for the fight, and only Flawless.
	f = setup()
	fire(f, "TEMPER", [20, 1, 2, 3, 4])
	var had: int = int(f.player.statuses.strength)
	DeepBattle._apply(f.state, f.player, {"kind": "block", "target": "self", "amount": 10, "repeat": 1}, f.rng.dice)
	check(had > 0 and int(f.player.block) == 10 + had, "a Flawless Temper's Strength goes on Block: %d" % int(f.player.block))
	f = setup()
	fire(f, "TEMPER", [20, 1, 2, 3, 4], false)
	DeepBattle._apply(f.state, f.player, {"kind": "block", "target": "self", "amount": 10, "repeat": 1}, f.rng.dice)
	check(int(f.player.block) == 10, "an ordinary one's does not")
	## Bloodletting: 4 health now, and up to 100% by how much is missing.
	f = setup()
	fire(f, "BLOODLETTING", [2, 4, 6, 8, 10], false)
	check(int(f.player.hp) == 996 and is_equal_approx(float(f.player.amplify), 1.5), "Bloodletting costs 4 now, for 50%")
	f = setup()
	fire(f, "BLOODLETTING", [2, 4, 6, 8, 10], true, 4, 1)
	check(float(f.player.amplify) < 1.6, "at full health a Flawless one is still about 50%%: %f" % float(f.player.amplify))
	f = setup()
	f.player.hp = 1
	f.player.max_hp = 1000
	f.player.hp = 500
	fire(f, "BLOODLETTING", [2, 4, 6, 8, 10], true, 4, 1)
	check(float(f.player.amplify) > 1.7 and float(f.player.amplify) < 1.95, "half gone, about 75%%: %f" % float(f.player.amplify))

func guards() -> void:
	## Guard: Block for every pair.
	var f: Dictionary = setup()
	var guard: Dictionary = fire(f, "GUARD", [5, 5, 3, 3, 9])
	check(total_of(guard, "block") == 12, "two pair: (5 + 3) x 1.5 Block: %d" % total_of(guard, "block"))
	## Anchor: Block for rerolls left over, played after the gem's own.
	f = setup()
	f.player.rerolls = 2
	var anchor: Dictionary = fire_held(f, "ANCHOR")
	check(has_flagged(anchor), "a Flawless Anchor's Block for rerolls is played after its own")
	f.player.rerolls = 0
	check(not bool(fire_held(f, "ANCHOR").flawless.on), "with none left, the line is out")
	## Bastion, Bezel: read what is really there as they land.
	f = setup()
	fire(f, "BASTION", [5, 5, 5, 2, 2])
	check(int(f.player.statuses.get("spikes", 0)) == int(f.player.block) * 10 / 100 * 1 or int(f.player.statuses.get("spikes", 0)) >= 1, "a Flawless Bastion turns the Block it just gave into Spikes")
	f = setup()
	var bezel: Dictionary = fire(f, "BEZEL", [5, 5, 3, 3, 9])
	check(int(f.player.statuses.ward) >= 1 and int(bezel.effects[-1].amount) == 2 * int(f.player.statuses.ward), "a Flawless Bezel gains Block equal to twice its Ward")
	## Hardening grows when Block breaks, whatever laid it.
	f = setup()
	equip(f, "HARDENING", true, 4, 0)
	f.player.block = 5
	var blow: Dictionary = DeepBattle._damage(f.state, f.foe, f.player, 8, f.rng.dice)
	check(int(f.player.run_counts.get("gem0:breaks", 0)) == 1 and blow.has("hp_loss"), "a blow that breaks Block grows a Flawless Hardening")
	f.player.block = 50
	DeepBattle._damage(f.state, f.foe, f.player, 8, f.rng.dice)
	check(int(f.player.run_counts.get("gem0:breaks", 0)) == 1, "one that leaves some standing does not")
	f.player.statuses.burn = 3
	f.player.block = 1
	DeepBattle._burn_tick(f.state, f.player, f.rng.dice)
	check(int(f.player.run_counts.get("gem0:breaks", 0)) == 2, "a Burn that eats the last of it does")
	rolls(f, [1, 2, 3, 4, 5])
	f.player.firing_target = f.player.target
	var hardening: Dictionary = DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	check(total_of(hardening, "block") == int(float(4 + 0 + 4) * 1.5), "and it reads 2 a break: %d" % total_of(hardening, "block"))
	equip(f, "HARDENING", false, 4, 0)
	f.player.block = 1
	f.player.run_counts["gem0:breaks"] = 0
	DeepBattle._damage(f.state, f.foe, f.player, 8, f.rng.dice)
	check(int(f.player.run_counts.get("gem0:breaks", 0)) == 0, "an ordinary one is deaf to it")
	## Mortar: what is left of the Retain lands as the next turn opens.
	f = setup()
	f.player.block = 40
	fire(f, "MORTAR", [2, 4, 1, 3, 5])
	f.player.block = 12
	f.player.statuses.retain = 30
	var hp_before: int = int(f.foe.hp)
	var shot: Dictionary = DeepBattle._fire_mortars(f.state, f.rng.dice)
	check(str(shot.get("kind", "")) == "mortar" and int(shot.amount) == 12 and int(f.foe.hp) == hp_before - 12, "a Flawless Mortar deals what its Retain will keep: %s" % str(shot.get("amount", "")))
	check(DeepBattle._fire_mortars(f.state, f.rng.dice).is_empty(), "once")
	## Rebound: a quarter of the Block just gained.
	f = setup()
	fire(f, "REBOUND", [1, 2, 3, 4, 5])
	hp_before = int(f.foe.hp)
	DeepBattle._apply(f.state, f.player, {"kind": "block", "target": "self", "amount": 40, "repeat": 1}, f.rng.dice)
	check(int(f.foe.hp) == hp_before - 10, "a Flawless Rebound hits for a quarter of 40: %d" % (hp_before - int(f.foe.hp)))
	## Shelter: doubled while poisoned or burning.
	f = setup(3, 2)
	f.state.players[1].hp = 800
	fire(f, "SHELTER", [5, 5, 2, 3, 4])
	var plain: int = int(f.state.players[1].block)
	f.state.players[1].block = 0
	f.player.statuses.burn = 1
	fire(f, "SHELTER", [5, 5, 2, 3, 4])
	check(plain > 0 and int(f.state.players[1].block) == plain * 2, "a Flawless Shelter doubles while its owner burns: %d, %d" % [plain, int(f.state.players[1].block)])

func green() -> void:
	## Mend throws its die again after healing.
	var f: Dictionary = setup()
	var mend: Dictionary = fire(f, "MEND", [1, 2, 3, 4, 5])
	check(has_flagged(mend) and mend.effects.any(func(e: Dictionary) -> bool: return str(e.kind) == "rethrow"), "a Flawless Mend throws a die again")
	## Graft: the lower pair takes the higher pair's number.
	f = setup()
	fire(f, "GRAFT", [5, 5, 2, 2, 9])
	check(f.player.hand.map(func(r: Dictionary) -> int: return int(r.value)) == [5, 5, 5, 5, 9], "a Flawless Graft makes four of a kind: %s" % str(f.player.hand.map(func(r: Dictionary) -> int: return int(r.value))))
	## Overflows.
	f = setup()
	var renewal: Dictionary = fire(f, "RENEWAL", [2, 3, 4, 5, 6])
	check(int(f.player.statuses.get("regeneration", 0)) > 0 and notes(renewal, "overflow") == 1, "a Flawless Renewal's overflow is Regeneration")
	f = setup()
	f.foe.statuses.poison = 50
	var siphon: Dictionary = fire(f, "SIPHON", [1, 2, 3, 4, 5])
	check(int(f.foe.statuses.poison) > 50 and notes(siphon, "overflow") == 1, "a Flawless Siphon's overflow lands as Poison")
	## Lichen ticks its own Regeneration now.
	f = setup()
	f.player.hp = 500
	var lichen: Dictionary = fire_held(f, "LICHEN")
	check(int(f.player.hp) > 500 and lichen.effects.any(func(e: Dictionary) -> bool: return bool(e.get("flawless", false)) and int(e.get("healed", 0)) > 0), "a Flawless Lichen ticks now")
	## Sap counts what was wasted.
	f = setup()
	DeepBattle._apply(f.state, f.player, {"kind": "heal", "target": "self", "amount": 40, "repeat": 1}, f.rng.dice)
	var sap: Dictionary = fire(f, "SAP", [5, 5, 5, 1, 2])
	check(total_of(sap, "damage") > 0, "a Flawless Sap at full health still hits: %d" % total_of(sap, "damage"))
	f = setup()
	DeepBattle._apply(f.state, f.player, {"kind": "heal", "target": "self", "amount": 40, "repeat": 1}, f.rng.dice)
	check(total_of(fire(f, "SAP", [5, 5, 5, 1, 2], false), "damage") == 0, "an ordinary one has nothing to read")

func violet() -> void:
	## Etch's Marks stay.
	var f: Dictionary = setup()
	fire(f, "ETCH", [5, 5, 2, 3, 4])
	var laid: int = int(f.foe.statuses.marked)
	DeepBattle._damage(f.state, f.player, f.foe, 10, f.rng.dice)
	DeepBattle._settle_marks(f.state)
	check(laid >= 2 and int(f.foe.statuses.get("marked", 0)) == laid, "a Flawless Etch's Marks are not spent")
	f.foe.statuses.marked = laid + 3
	DeepBattle._damage(f.state, f.player, f.foe, 10, f.rng.dice)
	DeepBattle._settle_marks(f.state)
	check(int(f.foe.statuses.marked) == laid, "anything else's are")
	## Petrify marks what it stuns.
	f = setup()
	var petrify: Dictionary = fire(f, "PETRIFY", [5, 5, 5, 5, 9])
	check(int(f.foe.statuses.get("marked", 0)) >= 4 and int(f.state.enemies[1].statuses.get("stun", 0)) == 0 and has_flagged(petrify), "a Flawless Petrify stuns one target and Marks it")
	## Confluence: the Poison on a creature that dies goes to every other.
	f = setup()
	f.foe.hp = 1
	f.foe.statuses.poison = 9
	var confluence: Dictionary = fire(f, "CONFLUENCE", [1, 2, 3, 4, 5])
	check(int(f.foe.hp) <= 0 and int(f.state.enemies[1].statuses.get("poison", 0)) == 9 and int(f.state.enemies[2].statuses.get("poison", 0)) == 9, "a Flawless Confluence's dead target poisons the room for 9: %s" % str(f.state.enemies[1].statuses))
	check(notes(confluence, "plague") == 1, "and says so")
	## Ferment grows every affliction, but nothing that takes an action.
	f = setup()
	f.foe.statuses.poison = 10
	f.foe.statuses.curse = 2
	f.foe.statuses.marked = 2
	f.foe.statuses.stun = 1
	fire(f, "FERMENT", [1, 3, 5, 2, 4])
	check(int(f.foe.statuses.poison) > 10 and int(f.foe.statuses.curse) == 3 and int(f.foe.statuses.marked) == 3 and int(f.foe.statuses.stun) == 1, "a Flawless Ferment grows them all: %s" % str(f.foe.statuses))
	## Hemlock: all even, its owner's Poison does not hurt this turn, and still ticks.
	f = setup()
	fire(f, "HEMLOCK", [2, 4, 6, 8, 10])
	var stacks: int = int(f.player.statuses.poison)
	var hp: int = int(f.player.hp)
	DeepBattle._poison_tick(f.state, f.player, f.rng.dice)
	check(int(f.player.hp) == hp and int(f.player.statuses.poison) == stacks - 1, "a Flawless Hemlock's Poison ticks and does not hurt")
	f = setup()
	fire(f, "HEMLOCK", [2, 4, 6, 8, 11])
	hp = int(f.player.hp)
	DeepBattle._poison_tick(f.state, f.player, f.rng.dice)
	check(int(f.player.hp) < hp, "not on a mixed hand")
	## Arsenic reaches Spikes and reflected blows.
	f = setup()
	fire(f, "ARSENIC", [5, 5, 2, 2, 9])
	f.player.statuses.spikes = 5
	DeepBattle._damage(f.state, f.foe, f.player, 8, f.rng.dice)
	check(int(f.foe.statuses.get("poison", 0)) > 0, "a Flawless Arsenic's Spikes poison what hits them")
	f = setup()
	fire(f, "ARSENIC", [5, 5, 2, 2, 9], false)
	f.player.statuses.spikes = 5
	DeepBattle._damage(f.state, f.foe, f.player, 8, f.rng.dice)
	check(int(f.foe.statuses.get("poison", 0)) == 0, "an ordinary one's do not")
	## Shatter hands over what it took.
	f = setup()
	f.foe.block = 12
	var shatter: Dictionary = fire(f, "SHATTER", [5, 5, 5, 2, 2])
	check(int(f.player.block) == 12 and has_flagged(shatter), "a Flawless Shatter gains the Block it removed: %d" % int(f.player.block))
	## Bind's dice come over; Dread's stacks grow the smallest die, for one turn.
	f = setup()
	var bowl_size: int = f.player.dice.size()
	fire(f, "BIND", [5, 5, 3, 3, 9])
	check(not f.player.get("bound_next", []).is_empty(), "a Flawless Bind notes the dice it took")
	var owed: int = f.player.bound_next.size()
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false))).size() == owed and f.player.dice.size() == bowl_size, "and they join the next throw as phantoms: %d" % owed)
	var rethrown: Array = DeepDice.reroll(f.player.hand, f.player.dice, [str(f.player.hand[0].die_id)], f.rng.dice)
	check(rethrown.filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false))).size() == owed, "and a reroll does not throw them away")
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false))).is_empty(), "for that throw only")
	f = setup()
	var tiny: Dictionary = DeepDice.make("D4", "tiny")
	f.player.dice[0] = tiny
	f.player.hand[0].die_id = "tiny"
	fire(f, "DREAD", [1, 2, 3, 4, 5])
	var grown_by: int = int(f.player.get("grow_next", 0))
	check(grown_by >= 1, "a Flawless Dread notes the stacks it landed")
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(DeepDice.top(f.player.dice[0]) > 4, "and the smallest die is bigger next turn: %d" % DeepDice.top(f.player.dice[0]))
	check(DeepDice.top(DeepBattle.dice_after_fight(f.player)[0]) == 4, "a fight that ends then gives the die back at its size")
	f.player.dice[0].faces[0].value = 3
	f.player.dice[0].faces[0].kind = "golden"
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(DeepDice.top(f.player.dice[0]) == 4, "and only that turn")
	check(f.player.dice[0].faces.any(func(face: Dictionary) -> bool: return str(face.get("kind", "")) == "golden"), "and what was worked on it meanwhile stays")
	## Contagion lasts the fight, and one stone never stacks with itself.
	f = setup()
	fire(f, "CONTAGION", [1, 2, 3, 4, 5])
	fire(f, "CONTAGION", [1, 2, 3, 4, 5])
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(f.player.after_fire.is_empty() and f.player.after_fire_fight.size() == 1, "a Flawless Contagion outlasts the turn, once")
	equip(f, "STRIKE", false, 4, 1)
	rolls(f, [5, 5, 5, 5, 5])
	f.foe.statuses.erase("poison")
	f.player.firing_target = f.player.target
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.foe.statuses.get("poison", 0)) >= 1, "and every gem still applies it next turn")
	check(DeepBattle._fire_answers(f.player).size() == 1, "and so does the Birthstone, which reads the same list")

func fortune() -> void:
	## Wager: twice the price in hand pays and deals double.
	var f: Dictionary = setup()
	f.player.ore = 1000
	var rich: Dictionary = fire(f, "WAGER", [20, 1, 2, 3, 4])
	f = setup()
	f.player.ore = 40
	var poor: Dictionary = fire(f, "WAGER", [20, 1, 2, 3, 4])
	check(bool(rich.flawless.on) and not bool(poor.flawless.on) and int(rich.effects[0].amount) == 2 * int(poor.effects[0].amount), "a Flawless Wager doubles with twice the price in hand")
	f = setup()
	f.player.ore = 1000
	f.foe.hp = 1
	var killed: Dictionary = fire(f, "WAGER", [20, 1, 2, 3, 4])
	check(int(killed.effects[0].refund) == 30 * 4, "and pays double on a kill: %d" % int(killed.effects[0].get("refund", 0)))
	## Double Down lets it ride.
	var seen: Dictionary = {}
	for attempt in range(60):
		f = setup()
		f.rng.dice.seed = attempt + 1
		var coin: Dictionary = fire(f, "DOUBLE_DOWN", [1, 1, 2, 3, 4]).effects[0]
		if not bool(coin.won):
			seen.lost = bool(f.player.nullify_next)
		elif bool(coin.won_again):
			seen.twice = float(f.player.amplify)
		else:
			seen.once = float(f.player.amplify)
	check(bool(seen.get("lost", false)), "a lost first toss still empties the next gem")
	check(float(seen.get("twice", 0.0)) in [4.0, 8.0], "two wins is x4, or x8 where its weight doubled the stake: %s" % str(seen.get("twice", "")))
	check(is_equal_approx(float(seen.get("once", 0.0)), 1.0), "a lost second toss and the next gem fires as usual: %s" % str(seen.get("once", "")))
	## Prospect: a Sparkle per distinct roll.
	f = setup()
	fire(f, "PROSPECT", [1, 2, 3, 4, 5])
	check(int(f.player.sparkle) >= 5, "a Flawless Prospect sparkles for five distinct rolls: %d" % int(f.player.sparkle))
	## Stake goes all in.
	f = setup()
	var stake: Dictionary = fire(f, "STAKE", [1, 2, 3, 4, 5])
	check(DeepRules.pyrite(f.player) == 0 and int(stake.effects[0].spent) == 100 and is_equal_approx(float(f.player.amplify), 2.0), "a Flawless Stake spends all 100 for 100%%: %f" % float(f.player.amplify))
	f = setup()
	f.player.ore = 5000
	stake = fire(f, "STAKE", [1, 2, 3, 4, 5])
	check(int(stake.effects[0].spent) == 100 and is_equal_approx(float(f.player.amplify), 2.0), "a one-carat one stakes no more than 100, however rich: %d" % int(stake.effects[0].spent))
	f = setup()
	f.player.ore = 5000
	stake = fire(f, "STAKE", [1, 2, 3, 4, 5], true, 4, 24)
	check(int(stake.effects[0].spent) == 1000 and is_equal_approx(float(f.player.amplify), 11.0), "a 24-carat one stakes 1,000 for 1,000%%: %d, x%f" % [int(stake.effects[0].spent), float(f.player.amplify)])
	f = setup()
	f.player.ore = 300
	stake = fire(f, "STAKE", [1, 2, 3, 4, 5], true, 4, 13)
	check(int(stake.effects[0].spent) == 300 and is_equal_approx(float(f.player.amplify), 4.0), "a 13-carat one (cap 400) stakes the 300 it has, a flat percent each: x%f" % float(f.player.amplify))
	## Tailings starts the rail over on five fizzles, with the count at nothing.
	f = setup()
	for at in range(6):
		f.player.rail.resize(maxi(f.player.rail.size(), at + 1))
		f.player.sockets.resize(maxi(f.player.sockets.size(), at + 1))
		f.player.places.resize(maxi(f.player.places.size(), at + 1))
		f.player.places[at] = {"socket": at, "rider": -1}
		equip(f, "CRUSH", false, 4, at)
	equip(f, "TAILINGS", true, 4, 5)
	f.player.resonance = 7
	f.player.fizzled_sockets = [0, 1, 2, 3, 4]
	f.player.fired_sockets = []
	f.state.queue = [{"kind": "gem", "unit": f.player.id, "socket": 5}, {"kind": "rail_end", "unit": f.player.id}]
	rolls(f, [1, 2, 3, 4, 9])
	var res_before: int = int(f.player.resonance)
	var tailings: Dictionary = DeepBattle.resolve_gem(f.state, f.player, 5, {}, f.rng.dice)
	check(tailings.effects.any(func(e: Dictionary) -> bool: return bool(e.get("restarted", false))), "a Flawless Tailings with five dark restarts the rail")
	check(f.player.fizzled_sockets.is_empty() and int(f.state.queue[0].socket) == 0 and f.state.queue.filter(func(q: Dictionary) -> bool: return str(q.kind) == "gem").size() == 6, "from the first gem, the count of what was dark back at nothing")
	check(int(f.player.resonance) >= res_before, "and the Resonance it built stands")
	check(notes(tailings, "restart_rail") == 1, "with a sparkle")
	## Dividend: a kept hand reads per 5.
	f = setup()
	f.player.ore = 50
	equip(f, "DIVIDEND", true, 4)
	rolls(f, [1, 2, 3, 4, 5])
	for roll in f.player.hand:
		roll.held = true
	var dividend: Dictionary = DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	check(bool(dividend.flawless.on) and int(dividend.effects[0].amount) == 15, "a Flawless Dividend on a kept hand reads 50 per 5, x 1.5: %d" % int(dividend.effects[0].amount))
	## Gilded Armor pays for every blow its Block stops, this turn.
	f = setup()
	var gold_before: int = int(f.player.gold)
	fire(f, "GILDED_ARMOR", [1, 2, 3, 4, 5])
	f.player.block = 100
	var paid: Dictionary = DeepBattle._damage(f.state, f.foe, f.player, 8, f.rng.dice)
	check(int(paid.get("gilded_paid", 0)) == 3 and int(f.player.gold) == gold_before + 3, "a Flawless Gilded Armor pays 2 x 1.5 a blow stopped: %d" % int(paid.get("gilded_paid", 0)))
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	f.player.block = 100
	check(int(DeepBattle._damage(f.state, f.foe, f.player, 8, f.rng.dice).get("gilded_paid", 0)) == 0, "this turn only")

func hand_and_rail() -> void:
	## Refract: a size up, and the next proc starts from the phantom it just made.
	var f: Dictionary = setup()
	f.player.dice = [DeepDice.make("D6", "p0_d0"), DeepDice.make("D6", "p0_d1"), DeepDice.make("D6", "p0_d2"), DeepDice.make("D6", "p0_d3"), DeepDice.make("D6", "p0_d4")]
	equip(f, "REFRACT", true, 4)
	rolls(f, [20, 5, 3, 2, 1])
	f.player.firing_target = f.player.target
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	var first: Array = f.player.refracted
	check(not first.is_empty() and int(first[0].get("faces", []).size()) > 6, "a Flawless Refract's phantom is a size up from a d6: %d" % int(first[0].get("faces", []).size()))
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	check(int(f.player.refracted[-1].get("faces", []).size()) > int(first[0].get("faces", []).size()), "and a second firing goes a size up from that phantom")
	## Polish and Facet: a neighbour with no higher to go gains a carat.
	f = setup()
	equip(f, "STRIKE", false, 4, 0)
	equip(f, "POLISH", true, 4, 1)
	equip(f, "STRIKE", true, 4, 2)
	rolls(f, [1, 2, 3, 19, 19])
	f.player.firing_target = f.player.target
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.player.gem_buffs.gem0.get("clarity", 0)) >= 1, "a Flawless Polish lifts a Clear neighbour")
	check(int(f.player.gem_buffs.gem2.get("carat", 0)) >= 1 and int(f.player.gem_buffs.gem2.get("clarity", 0)) == 0, "and a Flawless one gains a carat instead: %s" % str(f.player.gem_buffs.gem2))
	check(not f.player.gem_buffs.has("gem3"), "only its neighbours")
	f = setup()
	equip(f, "STRIKE", false, 2, 0)
	equip(f, "FACET", true, 4, 1)
	equip(f, "STRIKE", false, 4, 2)
	rolls(f, [20, 2, 3, 4, 5])
	f.player.firing_target = f.player.target
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.player.gem_buffs.gem0.get("cut", 0)) >= 1 and int(f.player.gem_buffs.gem2.get("carat", 0)) >= 1 and int(f.player.gem_buffs.gem2.get("cut", 0)) == 0, "a Flawless Facet's Perfect neighbour gains a carat: %s" % str(f.player.gem_buffs))
	## Cascade: next turn's leftovers carry on, once.
	f = setup()
	fire(f, "CASCADE", [5, 5, 2, 3, 4])
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	var given: int = int(f.player.rerolls)
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(int(f.player.rerolls) == int(f.player.rerolls_max) and int(f.player.rerolls_max) > given - 1, "a Flawless Cascade's unused rerolls carry on: %d after %d" % [int(f.player.rerolls), given])
	var carried: int = int(f.player.rerolls)
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(int(f.player.rerolls) < carried, "and only the once")
	## Prism: Charged equal to what it rang.
	f = setup()
	var prism: Dictionary = fire(f, "PRISM", [1, 2, 3, 4, 5])
	var rung: int = 0
	for effect in prism.effects:
		if str(effect.kind) == "resonance":
			rung += int(effect.amount)
	check(rung > 0 and int(f.player.statuses.charged) == rung, "a Flawless Prism stores what it rang: %d" % rung)
	## Enrich: neighbours a carat heavier for good, and it is gone.
	f = setup()
	equip(f, "STRIKE", false, 4, 0, 3)
	equip(f, "ENRICH", true, 4, 1, 24)
	equip(f, "STRIKE", false, 4, 2, 5)
	rolls(f, [1, 2, 3, 4, 5])
	f.player.firing_target = f.player.target
	var enrich: Dictionary = DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.player.rail[0].carat) == 4 and int(f.player.rail[2].carat) == 6, "a Flawless Enrich adds exactly one carat, however heavy it is")
	check(f.player.rail[1] == null and f.player.shattered == ["gem1"] and int(f.player.enriched.gem0) == 1, "and it is destroyed")
	check(enrich.kind == "gem_fire", "as it fires")
	## Carried home: a run's stones take the carats, and the socket stands empty.
	var unit: Dictionary = {"rail": [{"id": "gem0", "carat": 3}, {"id": "gem1", "carat": 24}, {"id": "gem2", "carat": 5}]}
	DeepDescent._carry_enriched(unit, f.player)
	check(int(unit.rail[0].carat) == 4 and unit.rail[1] == null and int(unit.rail[2].carat) == 6, "and that comes home from the fight")
	## Nothing beside it: it stays.
	f = setup()
	equip(f, "ENRICH", true, 4, 1)
	rolls(f, [1, 2, 3, 4, 5])
	f.player.firing_target = f.player.target
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(f.player.rail[1] is Dictionary, "with no neighbour to give to it stays whole")
	## A Doublet wearing it gives the fight's carat and stays.
	f = setup()
	equip(f, "ENRICH", true, 4, 0)
	equip(f, "DOUBLET", true, 4, 1)
	equip(f, "STRIKE", false, 4, 2, 3)
	f.player.resonance = 9
	rolls(f, [1, 2, 3, 4, 5])
	f.player.firing_target = f.player.target
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(f.player.rail[1] is Dictionary and int(f.player.rail[2].carat) == 3 and int(f.player.gem_buffs.gem2.carat) == 1, "a Doublet wearing a Flawless Enrich gives a fight's carat and stays")
	## A forecast touches nothing.
	f = setup()
	equip(f, "STRIKE", false, 4, 0, 3)
	equip(f, "ENRICH", true, 4, 1)
	rolls(f, [1, 2, 3, 4, 5])
	DeepBattle.resolve_gem(f.state, f.player, 1, {"dry": true}, f.rng.dice)
	check(int(f.player.rail[0].carat) == 3 and f.player.rail[1] is Dictionary, "a forecast Enrich gives nothing")

func seams() -> void:
	## Each Seam's replays add their own instance, read off the Resonance as they fire.
	for spec in [["SEAM_RED", "STRIKE", "damage"], ["SEAM_BLUE", "ANCHOR", "block"], ["SEAM_VIOLET", "VENOM", "poison"], ["SEAM_GOLD", "DIVIDEND", "gold"]]:
		var f: Dictionary = setup()
		f.player.ore = 100
		equip(f, str(spec[1]), false, 4, 0)
		equip(f, str(spec[0]), true, 4, 1)
		rolls(f, [5, 5, 3, 2, 1])
		for roll in f.player.hand:
			roll.held = true
		f.player.firing_target = f.player.target
		f.player.resonance = 9
		f.player.fired_sockets = [0]
		f.state.queue = []
		DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
		check(not f.state.queue.is_empty() and not f.state.queue[0].get("each", {}).is_empty(), "%s hands its replay an instance" % spec[0])
		var step: Dictionary = f.state.queue.pop_front()
		var replay: Dictionary = DeepBattle.resolve_gem(f.state, f.player, int(step.socket), {"retrigger": true, "each": step.each}, f.rng.dice)
		var extras: Array = replay.effects.filter(func(e: Dictionary) -> bool: return bool(e.get("flawless", false)) and str(e.kind) == str(spec[2]))
		var div: int = {"SEAM_VIOLET": 3, "SEAM_GOLD": 2}.get(str(spec[0]), 1)
		check(extras.size() == 1 and int(extras[0].amount) == int(replay.resonance) / div, "%s adds %s of the Resonance as a second instance: %s at %d" % [spec[0], str(spec[2]), str(extras.map(func(e: Dictionary) -> int: return int(e.amount))), int(replay.resonance)])
	## Green: max HP for the fight only.
	var g: Dictionary = setup()
	var hp_cap: int = int(g.player.max_hp)
	var worth: Array = DeepBattle._seam_each(g.state, g.player, {"kind": "max_hp", "target": "self", "for_fight": true}, g.rng.dice)
	check(worth.is_empty(), "with no Resonance there is nothing to add")
	g.player.resonance = 12
	DeepBattle._seam_each(g.state, g.player, {"kind": "max_hp", "target": "self", "for_fight": true}, g.rng.dice)
	check(int(g.player.max_hp) == hp_cap + 12 and int(g.player.fight_max_hp) == 12, "a Green Seam raises max HP by the Resonance, for the fight")
	## White: one more Resonance, flat. Violet and Gold have a floor of 1.
	g.player.resonance = 1
	var low: Array = DeepBattle._seam_each(g.state, g.player, {"kind": "poison", "target": "enemy", "div": 3, "min": 1}, g.rng.dice)
	check(int(low[0].amount) == 1, "a third of 1 Resonance is still at least 1")
	g.player.resonance = 40
	DeepBattle._seam_each(g.state, g.player, {"kind": "resonance", "flat": 1}, g.rng.dice)
	check(int(g.player.resonance) == 41, "a White Seam's replay rings exactly one more")
	## A copy of a copy lasts as long as the Echo that made it says.
	var copied: Dictionary = DeepBattle._void_copy(g.player, {"id": "x", "skill": "STRIKE", "inclusions": [], "echo_turn": true})
	check(not copied.has("echo_turn"), "a copy does not inherit how long the gem it copied lasts")
	## An ordinary Seam adds nothing.
	check(DeepContent.skill("SEAM_RED").effects[0].get("each", {}).is_empty(), "the instance is only on the Flawless line")

func opals() -> void:
	## Fire Opal: one carat always, double in a socket that shows the gem.
	var f: Dictionary = setup()
	equip(f, "STRIKE", false, 4, 0)
	equip(f, "FIRE_OPAL", true, 4, 1)
	equip(f, "GUARD", false, 4, 2)
	f.player.sockets[0] = "RED"
	f.player.sockets[2] = "RED"
	f.player.resonance = 9
	rolls(f, [1, 2, 3, 4, 5])
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.player.gem_buffs.gem0.carat) >= 2 and int(f.player.gem_buffs.gem0.carat) % 2 == 0, "a Flawless Fire Opal gives a lit gem double: %s" % str(f.player.gem_buffs.gem0))
	check(int(f.player.gem_buffs.gem2.carat) == int(f.player.gem_buffs.gem0.carat) / 2, "and an unlit one the plain carat")
	check(not DeepContent.skill("FIRE_OPAL").has("numbers"), "there is no Cut ladder on it now")
	## Echo: its copy goes as the turn does; a Flawless one's stays.
	for flawless in [false, true]:
		var r: Dictionary = DeepRng.streams(7, ["dice", "creatures"])
		var hero: Dictionary = DeepBattle.make_player("a", "A", "ARDOR", [DeepStone.make("STRIKE", 1, 4, 3, [], {}, "s1"), DeepStone.make("ECHO", 1, 4, 5 if flawless else 3, [], {}, "e1")], [])
		hero.passive = {}
		hero.birthstone = {}
		hero.sockets = ["UNLIT", "UNLIT"]
		var state: Dictionary = DeepBattle.begin([hero], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
		var unit: Dictionary = state.players[0]
		for at in range(unit.hand.size()):
			unit.hand[at].value = 5
		var size_before: int = unit.rail.size()
		unit.resonance = 9
		unit.initial_resonance = 9
		DeepBattle.start_resolution(state)
		var made: int = 0
		while DeepBattle.has_steps(state) and str(state.phase) == "resolving":
			var ev: Dictionary = DeepBattle.step(state, r.dice, r.creatures)
			if str(ev.get("kind", "")) == "gem_fire" and str(ev.skill) == "ECHO":
				made = unit.rail.size() - size_before
		check(made >= 1, "the Echo lays a copy")
		if flawless:
			check(unit.rail.size() == size_before + made, "a Flawless Echo's copy is there the next turn")
			check(unit.places.size() == unit.rail.size() and unit.sockets.size() == unit.rail.size(), "with the rail's numbers in step")
		else:
			check(unit.rail.size() == size_before, "an ordinary Echo's copy is gone the next turn: %d" % unit.rail.size())
			check(unit.places.size() == unit.rail.size() and unit.sockets.size() == unit.rail.size(), "with the rail's numbers back in step")
			check(unit.rail.filter(func(s: Variant) -> bool: return s is Dictionary and bool(s.get("echo_turn", false))).is_empty(), "no copy left riding")

func transcendent() -> void:
	## Procession plays twice on a straight of five, once on anything shorter.
	var f: Dictionary = setup()
	var five: Dictionary = fire(f, "PROCESSION", [1, 2, 3, 4, 5])
	f = setup()
	var four: Dictionary = fire(f, "PROCESSION", [1, 2, 3, 4, 19])
	check(bool(five.flawless.on) and not bool(four.flawless.on), "a Flawless Procession's line asks for a straight of five")
	check(five.effects.size() == 2 * four.effects.size(), "and then all of it plays twice: %d, %d" % [five.effects.size(), four.effects.size()])
	## Gemini: neighbours sharing a color go once more.
	f = setup()
	equip(f, "STRIKE", false, 4, 0)
	equip(f, "GEMINI", true, 4, 1)
	equip(f, "CLEAVE", false, 4, 2)
	rolls(f, [5, 5, 1, 2, 3])
	f.state.queue = []
	var gemini: Dictionary = DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(bool(gemini.effects[0].get("twinned", false)) and f.state.queue.size() == 4, "two Red neighbours on one pair: two goes each: %d" % f.state.queue.size())
	f = setup()
	equip(f, "STRIKE", false, 4, 0)
	equip(f, "GEMINI", true, 4, 1)
	equip(f, "GUARD", false, 4, 2)
	rolls(f, [5, 5, 1, 2, 3])
	f.state.queue = []
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(f.state.queue.size() == 2, "a Red and a Blue: one go each: %d" % f.state.queue.size())
	## Certainty: the gems it forces read the highest die.
	f = setup()
	equip(f, "CERTAINTY", true, 4, 0)
	equip(f, "GUARD", false, 0, 1)
	rolls(f, [2, 2, 4, 5, 9])
	f.player.firing_target = f.player.target
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	var forced: Dictionary = DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(total_of(forced, "block") == 9, "a Guard it forces reads the 9, for a pair of nines: %d" % total_of(forced, "block"))
	check(int(f.player.hand[0].value) == 2, "and the dice themselves are untouched")
	f = setup()
	equip(f, "CERTAINTY", false, 4, 0)
	equip(f, "GUARD", false, 0, 1)
	rolls(f, [2, 2, 4, 5, 9])
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	check(total_of(DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice), "block") < 9, "an ordinary Certainty's reads the hand as it lies")
	## Lodestone: a turn begun Charged, the first gem goes twice.
	f = setup()
	equip(f, "LODESTONE", true, 4, 1)
	f.player.initial_resonance = 4
	f.state.queue = []
	var begun: Dictionary = DeepBattle._perform(f.state, {"kind": "rail_begin", "unit": f.player.id}, f.rng.dice, f.rng.creatures)
	check(int(f.player.repeat_next) == 1 and notes(begun, "charged_first") == 1, "a Flawless Lodestone: a Charged turn's first gem goes twice")
	f.player.initial_resonance = 0
	DeepBattle._perform(f.state, {"kind": "rail_begin", "unit": f.player.id}, f.rng.dice, f.rng.creatures)
	check(int(f.player.repeat_next) == 0, "not a turn begun flat")

func pacing() -> void:
	## A line's extra plays after the gem's own, by a beat the pace can close up.
	var f: Dictionary = setup()
	var venom: Dictionary = fire(f, "VENOM", [5, 5, 2, 3, 4])
	var parts: Array = DeepBattle.flawless_parts(venom.effects)
	check(parts[1].size() == 1 and str(parts[1][0].kind) == "damage", "a Flawless Venom's damage is played as its line's")
	var full: float = DeepBattle.effects_span(venom.effects, 1.0)
	var quick: float = DeepBattle.effects_span(venom.effects, 0.5)
	var off: float = DeepBattle.effects_span(venom.effects, 0.0)
	check(full > quick and quick > off, "and its beat answers the pace: %f %f %f" % [full, quick, off])
	check(is_equal_approx(DeepBattle.follow_after(venom.effects, 0.0), 0.0), "at Off, the extra goes with the gem")
	check(DeepBattle.follow_after(venom.effects, 1.0) > DeepBattle.FLAWLESS_BEAT * 0.99, "at Full, after its breath")
	## Strike's second hit is only the line's if there is a neighbour to hit.
	f = setup(1)
	check(not has_flagged(fire(f, "STRIKE", [5, 5, 2, 3, 4])), "a Flawless Strike with nothing beside the target shows nothing extra")
	f = setup(3)
	check(has_flagged(fire(f, "STRIKE", [5, 5, 2, 3, 4])), "with a neighbour, the second hit waits its turn")
	## Every line of the pack says something.
	for key in DeepContent.section("skills"):
		check(not str(DeepContent.skill(str(key)).get("flawless", {}).get("text", "")).is_empty(), "%s has a Flawless line" % str(key))
	## The sparkle has a sound of its own in the bank.
	check(DeepSoundBank.stream("flawless_glint") != null, "the sparkle has its sound")
	## Notes leave on the next event, and only once.
	f = setup()
	DeepBattle._flawless_note(f.state, f.player, "gem0", "kill")
	var carrying: Dictionary = DeepBattle._event(f.state, "skip", {})
	check(carrying.flawless_notes.size() == 1 and not DeepBattle._event(f.state, "skip", {}).has("flawless_notes"), "a note goes out on one event")
