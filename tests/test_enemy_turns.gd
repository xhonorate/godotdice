extends SceneTree
## Enemy turns exercised through real battle steps and deterministic face sets.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	planning_and_repeats()
	combinations()
	controls()
	party_effects()
	content_coverage()
	print("Enemy turns: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func setup(key: String = "CAVE_TICK", players: int = 2) -> Dictionary:
	var party: Array = []
	for i in range(players):
		var dice: Array = []
		for j in range(5):
			dice.append(DeepDice.make("D6", DeepContent.die("D6"), "p%d_d%d" % [i, j]))
		var player: Dictionary = DeepBattle.make_player("p%d" % i, "Player", "ARDOR", [], dice)
		player.birthstone = {}
		party.append(player)
	var rng: Dictionary = DeepRng.streams(127, ["dice", "creatures"])
	var state: Dictionary = DeepBattle.begin(party, [key], {"depth": 1}, rng.dice, rng.creatures)
	return {"state": state, "rng": rng, "foe": state.enemies[0]}

func fixed(foe: Dictionary, values: Array) -> void:
	foe.dice = []
	for i in range(values.size()):
		foe.dice.append(DeepDice.make("D6", {"shape": "D6", "faces": [int(values[i])]}, "e0_d%d" % i))

func events(fixture: Dictionary) -> Array:
	DeepBattle.start_resolution(fixture.state)
	var out: Array = []
	var copy: Dictionary = fixture.state.duplicate(true)
	while DeepBattle.has_steps(fixture.state) and out.size() < 120:
		var before: Dictionary = fixture.state.duplicate(true)
		var event: Dictionary = DeepBattle.step(fixture.state, fixture.rng.dice, fixture.rng.creatures)
		copy = DeepPatch.apply(copy, DeepPatch.diff(before, fixture.state))
		check(JSON.stringify(copy) == JSON.stringify(fixture.state), "each enemy event patches identically on a guest")
		out.append(event)
	return out

func select(all: Array, kind: String) -> Array:
	return all.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == kind)

func planning_and_repeats() -> void:
	var f: Dictionary = setup()
	check(f.foe.hand.is_empty() and not f.foe.has("intents"), "planning contains no future rolls or prepared intents")
	var untouched: Dictionary = DeepRng.streams(127, ["dice", "creatures"])
	check(f.rng.creatures.state == untouched.creatures.state, "enemy RNG is untouched during ordinary planning")
	fixed(f.foe, [6, 2])
	f.state.players[0].block = 4
	DeepBattle.start_resolution(f.state)
	var order: Array = []
	var rolls: Array = []
	var moves: Array = []
	while DeepBattle.has_steps(f.state):
		var hp: int = int(f.state.players[0].hp)
		var event: Dictionary = DeepBattle.step(f.state, f.rng.dice, f.rng.creatures)
		order.append(str(event.kind))
		if str(event.kind) == "enemy_roll":
			rolls.append(event)
			check(f.foe.hand.size() == rolls.size(), "only the current die has been generated")
			check(int(f.state.players[0].hp) == hp, "rolling does not apply damage")
		if str(event.kind) == "enemy_ability":
			check(int(f.state.players[0].hp) == hp, "power-up does not apply damage before impact")
		if str(event.kind) == "enemy_move":
			moves.append(event)
	check(moves.map(func(e: Dictionary) -> String: return str(e.move)) == ["Bite", "Latch", "Bite"], "every qualifying move fires in list order, before the next die")
	check(int(moves[0].effects[0].amount) == 6 and int(moves[2].effects[0].amount) == 2, "ordinary amounts read only the current die")
	check(moves[0].effects.size() == 2 and int(moves[0].effects[0].hp_loss) == 2 and int(moves[0].effects[1].hp_loss) == 6, "one attack uses each player's own block")
	check(moves[1].effects.size() == 2 and f.state.players.all(func(p: Dictionary) -> bool: return p.hand.size() == 4), "Latch suppresses a die for every player's next turn")
	check(f.foe.hand.is_empty(), "next planning clears old results")
	var dead: Dictionary = setup()
	dead.foe.hp = 0
	check(select(events(dead), "enemy_roll").is_empty(), "dead enemies never roll")

func combinations() -> void:
	var base: Dictionary = DeepContent.creature("MAGPIE")
	var saved: Dictionary = base.duplicate(true)
	base.moves = [
		{"name": "Tap", "trigger": {"kind": "always"}, "effects": [{"kind": "damage", "amount": {"term": "rolled"}}]},
		{"name": "Pair", "trigger": {"kind": "pair", "amount": 1}, "effects": [{"kind": "block", "amount": 1}]},
		{"name": "Triple", "trigger": {"kind": "triple", "amount": 1}, "dramatic": true, "effects": [{"kind": "block", "amount": 3}]}]
	var f: Dictionary = setup("MAGPIE")
	fixed(f.foe, [3, 3, 3])
	var out: Array = events(f)
	check(select(out, "enemy_move").map(func(e: Dictionary) -> String: return str(e.move)) == ["Tap", "Tap", "Pair", "Tap", "Triple"], "pair fires once at die two and triple at die three")
	var rolls: Array = select(out, "enemy_roll")
	check(str(rolls[0].states[1]) == "pending" and str(rolls[0].states[2]) == "pending", "incomplete possible combinations wait")
	check(bool(rolls[2].suspense), "a major triple's last die builds suspense")
	var suspense_foe: Dictionary = DeepCreatures.make("MAGPIE", "x", 1, 1)
	DeepCreatures.prepare(suspense_foe)
	suspense_foe.hand = [{"die_id": "a", "value": 3}, {"die_id": "b", "value": 3}]
	var d4: Dictionary = DeepDice.make("D4", DeepContent.die("D4"), "last")
	check(DeepCreatures.suspense(suspense_foe, [d4]), "suspense only reads revealed dice and possible faces")
	suspense_foe.hand[1].value = 2
	check(not DeepCreatures.suspense(suspense_foe, [d4]), "no suspense for an impossible triple")
	var sequence: Dictionary = {"trigger": {"kind": "straight", "amount": 3}}
	var history: Array = [{"die_id": "a", "value": 4}, {"die_id": "b", "value": 2}, {"die_id": "c", "value": 3}]
	check(bool(DeepCreatures.activation(sequence, history, true).active), "sequences accept any rolling order")
	var odd: Dictionary = {"trigger": {"kind": "all_odd", "amount": 2}}
	history = [{"die_id": "a", "value": 3}, {"die_id": "b", "value": 5}]
	check(not DeepCreatures.activation(odd, history, false).active and DeepCreatures.activation(odd, history, true).active, "all odd waits until the final die")
	check(not DeepCreatures.activation(odd, history.slice(0, 1), true).active, "suppression cannot turn a combination into a one-die bonus")
	base.clear()
	base.merge(saved)

func controls() -> void:
	var f: Dictionary = setup()
	f.foe.stolen_dice = 1
	f.foe.dread_turns = 2
	var before_rng: int = f.rng.creatures.state
	var out: Array = events(f)
	check(select(out, "enemy_roll").is_empty() and select(out, "enemy_move").is_empty(), "Bind can suppress the last die")
	check(f.rng.creatures.state == before_rng and int(f.foe.dread_turns) == 1, "skipped action consumes duration without consuming RNG")
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D4", "Dread lowers a d6 to d4")
	DeepBattle._apply(f.state, f.state.players[0], {"kind": "dice_dread", "target": "enemy", "amount": 3}, f.rng.dice)
	check(int(f.foe.dread_turns) == 3 and str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D4", "Dread refreshes duration without stacking tier penalties")
	DeepBattle._apply(f.state, f.foe, {"kind": "dice_upgrade", "target": "self", "amount": 1}, f.rng.dice)
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D6", "upgrade and Dread combine without mutating base dice")
	f.foe.dread_turns = 1
	DeepCreatures.finish(f.foe)
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D8" and str(f.foe.dice[0].shape) == "D6", "Dread expiration preserves upgrades")
	f.foe.dice_upgrade = 99
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D100", "tier upgrades stop at d100")
	f.foe.dread_turns = 1
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D60", "Dread lowers capped upgraded dice instead of spending invisible tiers")
	f = setup("MAGPIE")
	f.foe.statuses.stun = 1
	check(select(events(f), "enemy_roll").is_empty(), "stun skips all dice of a multi-die enemy")
	f = setup()
	fixed(f.foe, [1, 2, 3])
	f.foe.stolen_dice = 1
	out = events(f)
	check(select(out, "enemy_roll").map(func(e: Dictionary) -> int: return int(e.roll.value)) == [1, 2], "Bind suppresses the last die in order")

	var upgraded: Dictionary = setup("THE_FOREMAN")
	upgraded.foe.hp = 30
	for face in upgraded.foe.dice[0].faces:
		face.value = 6
	var upgraded_rolls: Array = select(events(upgraded), "enemy_roll")
	check(upgraded_rolls.size() == 2 and str(upgraded_rolls[0].die.shape) == "D6" and str(upgraded_rolls[1].die.shape) == "D16", "a buff changes the next unrolled die while preserving the previous roll")

	var durations: Array = []
	for carat in [1, 8]:
		var casting: Dictionary = setup()
		var caster: Dictionary = casting.state.players[0]
		caster.rail[3] = DeepStone.make("DREAD", carat, 4, 3)
		for i in range(caster.hand.size()):
			caster.hand[i].value = i + 1
		DeepBattle.resolve_gem(casting.state, caster, 3, {}, casting.rng.dice)
		durations.append(int(casting.foe.dread_turns))
	check(int(durations[0]) > 0 and int(durations[1]) > int(durations[0]), "heavier Dread stones increase duration while lowering only one tier")

func party_effects() -> void:
	var f: Dictionary = setup("CAVE_TICK", 4)
	for kind in ["poison", "stun", "curse", "die_steal", "remove_block"]:
		var result: Array = DeepBattle._apply(f.state, f.foe, {"kind": kind, "target": "hero", "amount": 1}, f.rng.dice)
		check(result.size() == 4, "%s reaches every living player even through legacy hero targeting" % kind)
	for p in f.state.players:
		p.hp = 1
	var hits: Array = DeepBattle._apply(f.state, f.foe, {"kind": "damage", "target": "heroes", "amount": 10}, f.rng.dice)
	check(hits.size() == 4 and f.state.outcome == "defeat", "a lethal party attack resolves all four victims")

	var reflected: Dictionary = setup("GLASS_WYRM", 4)
	reflected.foe.block = 0
	reflected.state.players[0].resonance = 0
	var rebound: Dictionary = DeepBattle._damage(reflected.state, reflected.state.players[0], reflected.foe, 4, reflected.rng.dice)
	check(rebound.get("reflections", []).size() == 4, "passive enemy reflection damages every player")
	var fog: Dictionary = setup("CLOUDER", 4)
	for p in fog.state.players:
		p.rail[0] = DeepStone.make("STRIKE", 1, 4, 3)
		p.rail[1] = DeepStone.make("GUARD", 1, 4, 3)
	DeepBattle._begin_turn(fog.state, fog.rng.dice, fog.rng.creatures)
	check(fog.state.players.all(func(p: Dictionary) -> bool: return p.clouded.size() == 1), "passive fog affects every player's rail")
	var moth: Dictionary = setup("LANTERN_MOTH", 4)
	var before: Array = moth.state.players.map(func(p: Dictionary) -> int: return int(p.hp))
	DeepBattle.command(moth.state, "p0", {"kind": "reroll", "dice": ["p0_d0"]}, moth.rng.dice)
	for i in range(4):
		check(int(moth.state.players[i].hp) == int(before[i]) - 1, "the moth's reroll drain reaches player %d" % i)

	var simultaneous: Dictionary = setup("GLASS_WYRM", 4)
	simultaneous.foe.hp = 4
	simultaneous.foe.block = 0
	for p in simultaneous.state.players:
		p.hp = 1
	DeepBattle._damage(simultaneous.state, simultaneous.state.players[0], simultaneous.foe, 4, simultaneous.rng.dice)
	check(simultaneous.state.outcome == "defeat" and DeepBattle.living(simultaneous.state.players).is_empty(), "lethal reflection settles after every victim, including when the enemy also dies")

func content_coverage() -> void:
	for key in DeepContent.section("creatures"):
		var definition: Dictionary = DeepContent.creature(str(key))
		for phase in [definition] + definition.get("phases", []):
			for shape in DeepCreatures.TIERS:
				for value in range(1, int(DeepDice.SHAPES[shape]) + 1):
					var history: Array = [{"die_id": "x", "value": value, "top": int(DeepDice.SHAPES[shape])}]
					var covered: bool = false
					for move in phase.moves:
						if not DeepCreatures.is_combination(move) and DeepCreatures.activation(move, history, true).active:
							covered = true
					check(covered, "%s %s face %d has an ordinary action" % [key, shape, value])
