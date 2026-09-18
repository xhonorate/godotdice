extends SceneTree
## The battle step machine: planning, resolution one step at a time, creatures, statuses,
## Resonance, retriggers, the forecast and the patch stream.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_setup_and_planning()
	_test_resolution_flow()
	_test_resonance_and_capstone()
	_test_hand_mutation_and_retriggers()
	_test_creatures_and_statuses()
	_test_forecast_matches()
	_test_patch_stream()
	_test_whole_fights()
	print("Battle: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func rngs(seed_value: int) -> Dictionary:
	return DeepRng.streams(seed_value, ["dice", "creatures"])

func stone(skill: String, carat: int = 1, cut: int = 4, clarity: int = 3, inclusions: Array = [], id: String = "") -> Dictionary:
	return DeepStone.make(skill, carat, cut, clarity, inclusions, {}, id if not id.is_empty() else skill.to_lower())

func dice(keys: Array, prefix: String) -> Array:
	var out: Array = []
	for index in range(keys.size()):
		out.append(DeepDice.make(str(keys[index]), DeepContent.die(str(keys[index])), "%s%d" % [prefix, index]))
	return out

func hand(unit: Dictionary, numbers: Array) -> void:
	## Puts a chosen hand in a player's tray, on their own dice, as if rolled.
	var out: Array = []
	for index in range(numbers.size()):
		var die: Dictionary = unit.dice[index % unit.dice.size()]
		out.append({"die_id": str(die.id), "key": str(die.key), "shape": str(die.shape), "value": int(numbers[index]), "face": 0, "kind": "plain",
			"top": DeepDice.top(die), "held": false, "rerolls": 0, "locked": false, "explosions": 0, "engraving": "", "phantom": false})
	unit.hand = out

func player(id: String, rail: Array, setting: String = "SIGNET") -> Dictionary:
	return DeepBattle.make_player(id, id.capitalize(), setting, rail, dice(DeepContent.setting(setting).dice, id))

func run_turn(state: Dictionary, r: Dictionary) -> Array:
	## Locks everyone, resolves the turn and returns every event it produced.
	for unit in state.players:
		unit.locked = true
	var events: Array = [DeepBattle.start_resolution(state)]
	var guard: int = 0
	while DeepBattle.has_steps(state) and guard < 200:
		guard += 1
		var event: Dictionary = DeepBattle.step(state, r.dice, r.creatures)
		if not event.is_empty():
			events.append(event)
	return events

func kinds(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return str(e.kind))

func fires(events: Array, unit_id: String = "") -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "gem_fire" and (unit_id.is_empty() or str(e.unit) == unit_id))

func damage_dealt(event: Dictionary) -> int:
	var total: int = 0
	for effect in event.get("effects", []):
		if str(effect.get("kind", "")) == "damage":
			total += int(effect.get("hp_loss", 0)) + int(effect.get("absorbed", 0))
	return total

func _test_setup_and_planning() -> void:
	var r: Dictionary = rngs(3)
	var state: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE"), stone("GUARD"), stone("MEND")]), player("b", [stone("CLEAVE")], "GAUNTLET")],
		["CAVE_TICK", "SILT_SLIME"], {"depth": 3}, r.dice, r.creatures)
	check(state.phase == "planning" and state.turn == 1, "a fight opens in planning on turn one")
	check(state.players.size() == 2 and state.enemies.size() == 2, "two players, two creatures")
	var a: Dictionary = DeepBattle.player(state, "a")
	check(a.hand.size() == 5 and a.rerolls == 3, "the Signet rolls five dice and has three rerolls (two plus its passive)")
	check(DeepBattle.player(state, "b").rerolls == 2, "the Gauntlet has the base two")
	check(a.rail.size() == 4 and a.rail[3] == null, "the rail is padded to the setting's sockets")
	check(a.target == "e0", "the first creature is targeted by default")
	var tick: Dictionary = DeepBattle.enemy(state, "e0")
	check(tick.max_hp == int(round(16 * (1.0 + 0.05 * 2) * 1.15)), "creature HP scales with depth and party: %d" % tick.max_hp)
	check(tick.intents.size() >= 1 and not str(tick.intents[0].move).is_empty(), "creatures publish intents: %s" % str(tick.intents[0].move))
	check(tick.intents[0].target in ["a", "b"], "an intent names its target")
	var before: Array = a.hand.duplicate(true)
	var chosen: Array = [before[0].die_id, before[1].die_id]
	var result: Dictionary = DeepBattle.command(state, "a", {"kind": "reroll", "dice": chosen}, r.dice)
	check(result.ok and result.event.kind == "reroll" and a.rerolls == 2, "a reroll spends one and reports")
	check(a.hand[2].held and not a.hand[0].held, "unselected dice are held")
	check(not DeepBattle.command(state, "a", {"kind": "reroll", "dice": []}, r.dice).ok, "an empty reroll is refused")
	check(not DeepBattle.command(state, "zz", {"kind": "lock"}, r.dice).ok, "an unknown player is refused")
	check(not DeepBattle.command(state, "a", {"kind": "target", "enemy": "nope"}, r.dice).ok, "an unknown target is refused")
	check(DeepBattle.command(state, "a", {"kind": "target", "enemy": "e1"}, r.dice).ok and a.target == "e1", "targeting works")
	check(DeepBattle.command(state, "a", {"kind": "lock"}, r.dice).ok and not DeepBattle.ready_to_resolve(state), "one lock is not enough")
	check(not DeepBattle.command(state, "a", {"kind": "reroll", "dice": chosen}, r.dice).ok, "a locked player cannot reroll")
	check(DeepBattle.command(state, "b", {"kind": "lock"}, r.dice).ok and DeepBattle.ready_to_resolve(state), "everyone locked: ready")
	check(DeepBattle.command(state, "b", {"kind": "unlock"}, r.dice).ok and not DeepBattle.ready_to_resolve(state), "unlocking takes it back")
	DeepBattle.command(state, "b", {"kind": "lock"}, r.dice)
	var begin: Dictionary = DeepBattle.start_resolution(state)
	check(begin.kind == "resolution_begin" and state.phase == "resolving", "resolution begins")
	check(not DeepBattle.command(state, "a", {"kind": "lock"}, r.dice).ok, "no commands while resolving")

func _test_resolution_flow() -> void:
	var r: Dictionary = rngs(11)
	var state: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE", 3), stone("GUARD"), stone("MEND")])], ["QUARTZ_GOLEM"], {"depth": 1}, r.dice, r.creatures)
	var a: Dictionary = DeepBattle.player(state, "a")
	hand(a, [3, 3, 5, 5, 5])
	var events: Array = run_turn(state, r)
	var seen: Array = kinds(events)
	check(seen[0] == "resolution_begin" and seen[1] == "rail_begin", "a turn opens with the rail: %s" % str(seen))
	check(seen.count("gem_fire") == 3, "three gems fire on a full house: %s" % str(seen))
	check(seen.find("rail_end") > seen.find("gem_fire"), "the rail closes after its gems")
	check(seen.has("enemy_move") or seen.has("battle_over"), "the creature acts or the fight ends")
	check(seen[seen.size() - 1] in ["turn_begin", "battle_over"], "a turn ends by beginning the next or ending the fight: %s" % seen[seen.size() - 1])
	var strike: Dictionary = fires(events)[0]
	check(strike.skill == "STRIKE" and damage_dealt(strike) == int(floor(15 * 1.75)), "Perfect Strike at carat 3 hits for 15 × 1.75 = 26 (%d)" % damage_dealt(strike))
	check(strike.effects[0].target == "e0" and strike.effects[0].has("hp_after"), "damage names its target and the HP after")
	var guard: Dictionary = fires(events)[1]
	check(guard.skill == "GUARD" and guard.effects[0].kind == "block" and int(guard.effects[0].block_after) > 0, "Guard raises block")
	check(int(guard.resonance) == 2, "Strike then Guard: Resonance 2 without harmony (%d)" % int(guard.resonance))
	if state.phase == "planning":
		check(state.turn == 2 and not a.locked and a.hand.size() == 5, "the next turn rolls a fresh hand and unlocks")

func _test_resonance_and_capstone() -> void:
	var r: Dictionary = rngs(21)
	var state: Dictionary = DeepBattle.begin([player("a", [stone("CLEAVE"), stone("STRIKE"), stone("TITHE"), stone("GUARD")])], ["QUARTZ_GOLEM"], {"depth": 1}, r.dice, r.creatures)
	var a: Dictionary = DeepBattle.player(state, "a")
	hand(a, [4, 4, 6, 6, 2])
	var events: Array = run_turn(state, r)
	var fired: Array = fires(events)
	check(fired.size() == 4, "every gem fires on two pairs")
	check(int(fired[0].resonance) == 1 and not bool(fired[0].harmony), "Cleave opens at 1")
	check(int(fired[1].resonance) == 3 and bool(fired[1].harmony), "Strike after Cleave: same colour, harmony, 3 (%d)" % int(fired[1].resonance))
	check(int(fired[2].resonance) == 4 and not bool(fired[2].harmony), "Tithe is Gold after Red: 4")
	check(int(fired[3].resonance) == 5 and int(fired[3].carat) == 1 + 4, "the Capstone Guard gains the Resonance before it as carats (%d)" % int(fired[3].carat))
	check(int(fired[3].effects[0].amount) == int(floor(6 * (1.0 + 5.0 / 4.0))), "Capstone Guard: pair of sixes × (1 + 5/4) (%d)" % int(fired[3].effects[0].amount))
	## A fizzle in the middle resets the count.
	var r2: Dictionary = rngs(22)
	var state2: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE"), stone("CRUSH"), stone("STRIKE", 1, 4, 3, [], "strike2"), stone("GUARD")])], ["QUARTZ_GOLEM"], {"depth": 1}, r2.dice, r2.creatures)
	hand(DeepBattle.player(state2, "a"), [1, 2, 3, 4, 6])
	var events2: Array = run_turn(state2, r2)
	var seen2: Array = kinds(events2)
	check(seen2.count("gem_fizzle") == 2, "Crush and Guard fizzle on all-distinct: %s" % str(seen2))
	var second_strike: Dictionary = fires(events2)[1]
	check(int(second_strike.resonance) == 1, "the fizzle reset Resonance before the second Strike (%d)" % int(second_strike.resonance))
	## The Chain forgives its first fizzle.
	var r3: Dictionary = rngs(23)
	var state3: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE"), stone("CRUSH"), stone("STRIKE", 1, 4, 3, [], "strike2"), stone("GUARD"), stone("MEND"), stone("TITHE"), stone("MEND", 1, 4, 3, [], "mend2")], "CHAIN")], ["QUARTZ_GOLEM"], {"depth": 1}, r3.dice, r3.creatures)
	hand(DeepBattle.player(state3, "a"), [1, 2, 3, 4, 6])
	var events3: Array = run_turn(state3, r3)
	check(int(fires(events3)[1].resonance) == 2, "the Chain's first fizzle does not reset Resonance (%d)" % int(fires(events3)[1].resonance))

func _test_hand_mutation_and_retriggers() -> void:
	var r: Dictionary = rngs(31)
	var state: Dictionary = DeepBattle.begin([player("a", [stone("GLIMMER", 1, 0), stone("CLEAVE")])], ["QUARTZ_GOLEM"], {"depth": 1}, r.dice, r.creatures)
	var a: Dictionary = DeepBattle.player(state, "a")
	hand(a, [1, 2, 4, 5, 6])
	var events: Array = run_turn(state, r)
	var fired: Array = fires(events)
	check(fired.size() == 2, "Glimmer raises the 1 to a 2 and Cleave finds its pair: %s" % str(kinds(events)))
	check(fired[0].effects[0].kind == "raise_low" and fired[1].trigger_value_or(2) == 2 if false else int(fired[1].effects[0].amount) == int(floor(4 * 1.25)), "Cleave reads the pair of twos: 4 × 1.25 = 5 (%d)" % int(fired[1].effects[0].amount))
	## Echo repeats the previous gem at half strength.
	var r2: Dictionary = rngs(32)
	var state2: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE", 3), stone("ECHO")])], ["QUARTZ_GOLEM"], {"depth": 1}, r2.dice, r2.creatures)
	hand(DeepBattle.player(state2, "a"), [5, 5, 2, 3, 1])
	var events2: Array = run_turn(state2, r2)
	var fired2: Array = fires(events2)
	check(fired2.size() == 3 and fired2[2].skill == "STRIKE" and bool(fired2[2].retrigger) and int(fired2[2].scale) == 50, "Echo re-fires Strike at 50%%: %s" % str(fired2.map(func(e: Dictionary) -> String: return str(e.skill))))
	check(damage_dealt(fired2[2]) == int(floor(float(damage_dealt(fired2[0])) / 2.0)), "the echo does half the damage")
	check(int(fired2[2].resonance) == 3, "a retrigger adds Resonance too (%d)" % int(fired2[2].resonance))
	## Chatoyance fires twice and Refract adds a phantom.
	var r3: Dictionary = rngs(33)
	var state3: Dictionary = DeepBattle.begin([player("a", [stone("REFRACT"), stone("CRUSH", 1, 4, 2, ["CHATOYANCE"])])], ["QUARTZ_GOLEM"], {"depth": 1}, r3.dice, r3.creatures)
	hand(DeepBattle.player(state3, "a"), [6, 6, 2, 3, 1])
	var events3: Array = run_turn(state3, r3)
	var fired3: Array = fires(events3)
	check(fired3.size() == 3, "Refract, then Crush twice: %s" % str(fired3.map(func(e: Dictionary) -> String: return str(e.skill))))
	check(fired3[0].effects[0].kind == "phantom_high" and fired3[0].effects[0].hand.size() == 6, "a phantom six joins the hand")
	check(fired3[1].skill == "CRUSH" and int(fired3[1].effects[0].amount) == int(floor(18 * 1.25)), "the phantom makes a triple of sixes for Crush")
	## Facet passes a Cut step, Double Down can empty the next gem.
	var r4: Dictionary = rngs(34)
	var state4: Dictionary = DeepBattle.begin([player("a", [stone("FACET"), stone("CLEAVE", 1, 0)])], ["QUARTZ_GOLEM"], {"depth": 1}, r4.dice, r4.creatures)
	hand(DeepBattle.player(state4, "a"), [4, 4, 1, 2, 6])
	var fired4: Array = fires(run_turn(state4, r4))
	check(fired4.size() == 2 and int(fired4[1].cut_step) == 1, "Facet lifts Poor Cleave to Fair so a pair of fours fires")

func _test_creatures_and_statuses() -> void:
	var r: Dictionary = rngs(41)
	var state: Dictionary = DeepBattle.begin([player("a", [stone("GUARD", 8)])], ["CAVE_TICK"], {"depth": 1}, r.dice, r.creatures)
	var a: Dictionary = DeepBattle.player(state, "a")
	hand(a, [6, 6, 1, 2, 3])
	var events: Array = run_turn(state, r)
	var moves: Array = events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "enemy_move")
	check(moves.size() >= 1, "the tick moved")
	var hit: Dictionary = moves[0]
	var dmg: Array = hit.effects.filter(func(e: Dictionary) -> bool: return str(e.kind) == "damage")
	if not dmg.is_empty():
		check(int(dmg[0].absorbed) + int(dmg[0].hp_loss) == int(dmg[0].raw), "damage is split between block and HP")
		check(int(dmg[0].absorbed) > 0, "block absorbed some of it")
	check(int(a.block_lost) == int(dmg[0].absorbed) if not dmg.is_empty() else true, "block lost is remembered for Riposte next turn")
	## Poison ticks and stun skips.
	var r2: Dictionary = rngs(42)
	var state2: Dictionary = DeepBattle.begin([player("a", [stone("VENOM", 4), stone("HEX")])], ["QUARTZ_GOLEM"], {"depth": 1}, r2.dice, r2.creatures)
	hand(DeepBattle.player(state2, "a"), [6, 6, 1, 2, 3])
	var events2: Array = run_turn(state2, r2)
	var seen2: Array = kinds(events2)
	var golem: Dictionary = DeepBattle.enemy(state2, "e0")
	check(seen2.has("skip") and not seen2.has("enemy_move"), "a stunned golem skips its move: %s" % str(seen2))
	check(seen2.has("tick"), "poison ticked")
	var tick: Dictionary = events2.filter(func(e: Dictionary) -> bool: return str(e.kind) == "tick")[0]
	check(int(tick.ticks[0].amount) == int(floor(6 * 2.0)) and int(golem.statuses.poison) == int(floor(6 * 2.0)) - 1, "poison hurts for its stacks and loses one (%s)" % str(tick.ticks[0]))
	## Party wipe and victory are both endings.
	var r3: Dictionary = rngs(43)
	var state3: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE", 20)])], ["LANTERN_MOTH"], {"depth": 1}, r3.dice, r3.creatures)
	hand(DeepBattle.player(state3, "a"), [6, 5, 4, 3, 2])
	var events3: Array = run_turn(state3, r3)
	check(state3.phase == "over" and state3.outcome == "victory" and kinds(events3)[kinds(events3).size() - 1] == "battle_over", "a 20-carat Strike ends the moth: %s" % str(kinds(events3)))
	check(bool(fires(events3)[0].effects[0].get("killed", false)), "the killing blow is marked")
	var r4: Dictionary = rngs(44)
	var weak: Dictionary = player("a", [stone("TITHE")])
	weak.hp = 1
	var state4: Dictionary = DeepBattle.begin([weak], ["QUARTZ_GOLEM", "QUARTZ_GOLEM"], {"depth": 10}, r4.dice, r4.creatures)
	hand(DeepBattle.player(state4, "a"), [1, 2, 3, 4, 5])
	var events4: Array = run_turn(state4, r4)
	check(state4.outcome == "defeat" and bool(DeepBattle.player(state4, "a").downed), "one HP against two golems is a wipe: %s" % str(kinds(events4)))
	## Enrage adds damage late.
	var r5: Dictionary = rngs(45)
	var state5: Dictionary = DeepBattle.begin([player("a", [stone("GUARD", 20)])], ["LANTERN_MOTH"], {"depth": 1}, r5.dice, r5.creatures)
	state5.turn = 8
	hand(DeepBattle.player(state5, "a"), [6, 6, 6, 6, 6])
	var events5: Array = run_turn(state5, r5)
	var move5: Array = events5.filter(func(e: Dictionary) -> bool: return str(e.kind) == "enemy_move")
	check(not move5.is_empty() and int(move5[0].effects[0].raw) == 2 + 4, "on turn 8 the moth's 2 becomes 6 with enrage (%s)" % str(move5[0].effects[0] if not move5.is_empty() else {}))

func _test_forecast_matches() -> void:
	var r: Dictionary = rngs(51)
	var state: Dictionary = DeepBattle.begin([player("a", [stone("GLIMMER", 1, 0), stone("CLEAVE", 2), stone("STRIKE", 3), stone("GUARD", 5)])], ["QUARTZ_GOLEM"], {"depth": 4}, r.dice, r.creatures)
	var a: Dictionary = DeepBattle.player(state, "a")
	hand(a, [1, 2, 4, 5, 6])
	var forecast: Dictionary = DeepBattle.forecast(state, "a")
	check(forecast.sockets.size() == 4 and forecast.sockets[1].active and forecast.sockets[3].active, "the forecast sees Cleave and Guard firing after Glimmer")
	check(a.hand[0].value == 1 and state.phase == "planning", "the forecast leaves the real state alone")
	var events: Array = run_turn(state, r)
	var fired: Array = fires(events)
	var actual_damage: int = 0
	var actual_block: int = 0
	for event in fired:
		for effect in event.effects:
			if str(effect.kind) == "damage":
				actual_damage += int(effect.raw)
			if str(effect.kind) == "block":
				actual_block += int(effect.amount)
	check(int(forecast.totals.damage) == actual_damage, "forecast damage equals what happened: %d vs %d" % [int(forecast.totals.damage), actual_damage])
	check(int(forecast.totals.block) == actual_block, "forecast block equals what happened: %d vs %d" % [int(forecast.totals.block), actual_block])
	check(int(forecast.totals.resonance) == int(fired[fired.size() - 1].resonance), "forecast Resonance matches")

func _test_patch_stream() -> void:
	var r: Dictionary = rngs(61)
	var state: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE"), stone("GUARD"), stone("VENOM")]), player("b", [stone("CLEAVE"), stone("MEND")], "PENDANT")],
		["CAVE_TICK", "MAGPIE"], {"depth": 2}, r.dice, r.creatures)
	var mirror: Dictionary = state.duplicate(true)
	for unit in state.players:
		unit.locked = true
	DeepBattle.start_resolution(state)
	var steps: int = 0
	var bytes: int = 0
	while DeepBattle.has_steps(state) and steps < 100:
		var before: Dictionary = state.duplicate(true)
		var event: Dictionary = DeepBattle.step(state, r.dice, r.creatures)
		if event.is_empty():
			continue
		var patch: Variant = DeepPatch.diff(before, state)
		bytes += JSON.stringify(patch).length()
		mirror = DeepPatch.apply(mirror, patch)
		steps += 1
	check(steps > 3, "several steps were streamed")
	check(JSON.stringify(mirror) == JSON.stringify(state), "a mirror fed patches ends identical to the host")
	check(bytes / steps < 12000, "a patch is a few kilobytes at most (%d bytes per step)" % (bytes / steps))
	check(DeepPatch.diff({"a": 1}, {"a": 1.0}) == null, "ints and floats that agree do not patch")
	check(DeepPatch.apply({"x": 1}, DeepPatch.diff({"x": 1}, {"y": [1, 2]})) == {"y": [1, 2]}, "keys are removed and added")

func _test_whole_fights() -> void:
	## A bot that never rerolls plays fights at three depths. Every fight ends, the same seed
	## replays the same events, and deeper fights are harder.
	var wins: Dictionary = {}
	var streams: Array = []
	for depth in [1, 6, 14]:
		var won: int = 0
		for seed_value in range(12):
			var r: Dictionary = rngs(1000 + depth * 100 + seed_value)
			var mine: Dictionary = DeepContent.mine("QUARRY")
			var keys: Array = DeepForge.encounter(r.creatures, mine, depth, 2)
			var state: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE", 4, 2), stone("GUARD", 3, 2), stone("MEND", 2, 2), stone("CLEAVE", 3, 3)]),
				player("b", [stone("BARRAGE", 4, 3), stone("TEMPO", 3, 2), stone("VENOM", 3, 2), stone("BLOOM", 2, 3), stone("CRUSH", 4, 2)], "GAUNTLET")], keys, {"depth": depth}, r.dice, r.creatures)
			var log: Array = []
			var guard: int = 0
			while str(state.phase) != "over" and guard < 60:
				guard += 1
				log.append_array(run_turn(state, r).map(func(e: Dictionary) -> String: return str(e.kind) + ":" + str(e.get("unit", "")) + ":" + str(e.get("effects", []).size())))
			check(state.phase == "over", "a fight at depth %d ends (turn %d)" % [depth, state.turn])
			if state.outcome == "victory":
				won += 1
			if seed_value == 0:
				streams.append(log)
		wins[depth] = won
	check(wins[1] >= wins[14], "depth 14 is not easier than depth 1: %s" % str(wins))
	check(wins[1] >= 6, "a two-player party mostly wins at depth 1: %s" % str(wins))
	var r_a: Dictionary = rngs(1000 + 100)
	var r_b: Dictionary = rngs(1000 + 100)
	var keys_a: Array = DeepForge.encounter(r_a.creatures, DeepContent.mine("QUARRY"), 1, 2)
	var keys_b: Array = DeepForge.encounter(r_b.creatures, DeepContent.mine("QUARRY"), 1, 2)
	var s_a: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE")])], keys_a, {"depth": 1}, r_a.dice, r_a.creatures)
	var s_b: Dictionary = DeepBattle.begin([player("a", [stone("STRIKE")])], keys_b, {"depth": 1}, r_b.dice, r_b.creatures)
	var log_a: Array = []
	var log_b: Array = []
	var guard2: int = 0
	while str(s_a.phase) != "over" and guard2 < 40:
		guard2 += 1
		log_a.append(JSON.stringify(run_turn(s_a, r_a)))
		log_b.append(JSON.stringify(run_turn(s_b, r_b)))
	check(log_a == log_b, "the same seeds replay the same fight")
