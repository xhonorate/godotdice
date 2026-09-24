extends SceneTree
## Stack boundaries, action timing, previews, and host/guest replay for combat statuses.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	ward()
	dread_and_cloud()
	combo_breaker()
	curse_and_marked()
	retain_and_regeneration()
	charged_and_dulled()
	sparkle_cap()
	spikes()
	cleanse_and_content()
	gem_integrations()
	enemy_integrations()
	print("Statuses: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func setup(key: String = "CAVE_TICK", count: int = 1) -> Dictionary:
	var party: Array = []
	for i in range(count):
		var bowl: Array = []
		for j in range(5):
			bowl.append(DeepDice.make("D6", DeepContent.die("D6"), "p%d_d%d" % [i, j]))
		var unit: Dictionary = DeepBattle.make_player("p%d" % i, "Player", "ARDOR", [], bowl)
		unit.birthstone = {}
		unit.passive = {}
		unit.hp = 1000
		unit.max_hp = 1000
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(123, ["dice", "creatures"])
	var state: Dictionary = DeepBattle.begin(party, [key], {"depth": 1}, rng.dice, rng.creatures)
	var foe: Dictionary = state.enemies[0]
	foe.hp = 1000
	foe.max_hp = 1000
	foe.block = 0
	foe.dice = [DeepDice.make("D6", {"shape": "D6", "faces": [1]}, "e0_d0")]
	return {"state": state, "rng": rng, "foe": foe, "player": state.players[0]}

func apply(f: Dictionary, kind: String, amount: int, to_enemy: bool = true) -> Array:
	return DeepBattle._apply(f.state, f.player if to_enemy else f.foe,
		{"kind": kind, "amount": amount, "target": "enemy" if to_enemy else "heroes"}, f.rng.dice)

func turn(f: Dictionary) -> Array:
	var out: Array = [DeepBattle.start_resolution(f.state)]
	while DeepBattle.has_steps(f.state) and out.size() < 200:
		var before: Dictionary = f.state.duplicate(true)
		var event: Dictionary = DeepBattle.step(f.state, f.rng.dice, f.rng.creatures)
		var guest: Dictionary = DeepPatch.apply(before, DeepPatch.diff(before, f.state))
		check(JSON.stringify(guest) == JSON.stringify(f.state), "status state patches identically to a guest")
		out.append(event)
	check(out.size() < 200, "status turn terminates")
	return out

func ward() -> void:
	for key in ["THE_FOREMAN", "THE_REGENT", "THE_DRILL"]:
		check(int(DeepCreatures.make(key, "e", 1, 1).statuses.ward) == 1, "%s starts with one Ward" % key)
	check(int(DeepCreatures.make("CAVE_TICK", "e", 1, 1).statuses.ward) == 0, "ordinary enemies have no default Ward")
	for hostile in DeepRules.DEBUFFS:
		var f: Dictionary = setup()
		apply(f, "ward", 2)
		var before_rng: int = f.rng.dice.state
		var blocked: Dictionary = apply(f, str(hostile), 5)[0]
		check(bool(blocked.get("warded", false)) and int(f.foe.statuses.ward) == 1, "Ward rejects one %s application regardless of potency" % hostile)
		check(f.rng.dice.state == before_rng, "a rejected debuff does not roll random choices")
	var f: Dictionary = setup()
	apply(f, "ward", 500)
	check(int(f.foe.statuses.ward) == 99, "enemy Ward caps at 99")
	apply(f, "ward", 101, false)
	check(int(f.player.statuses.ward) == 99, "player Ward caps at 99")
	f.player.statuses.ward = 1
	apply(f, "poison", 2, false)
	apply(f, "poison", 2, false)
	check(int(f.player.statuses.poison) == 2, "later applications land when Ward runs out")
	f.foe.block = 5
	apply(f, "remove_block", 5)
	apply(f, "damage", 5)
	check(int(f.foe.statuses.ward) == 99 and int(f.foe.hp) == 995, "Ward does not block hits or Block removal")
	for key in ["CLOUDER", "THE_FOREMAN"]:
		var fog: Dictionary = setup(key)
		fog.player.rail[0] = DeepStone.make("STRIKE", 1, 4, 3)
		fog.player.rail[1] = DeepStone.make("GUARD", 1, 4, 3)
		fog.player.statuses.ward = 1
		DeepBattle._begin_turn(fog.state, fog.rng.dice, fog.rng.creatures)
		check(fog.player.clouded.is_empty() and fog.player.buried.is_empty() and int(fog.player.statuses.ward) == 0, "Ward blocks %s socket restriction" % key)
	var immune: Dictionary = setup("VEIN_WRAITH")
	immune.foe.statuses.ward = 1
	check(bool(apply(immune, "poison", 2)[0].get("immune", false)) and int(immune.foe.statuses.ward) == 1, "innate immunity does not waste Ward")

func dread_and_cloud() -> void:
	var f: Dictionary = setup()
	apply(f, "dice_dread", 1)
	apply(f, "dice_dread", 1)
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D3", "two Dread stacks lower d6 two tiers")
	DeepCreatures.finish(f.foe)
	check(int(f.foe.dread_turns) == 1 and str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D4", "each completed action restores one tier")
	DeepCreatures.finish(f.foe)
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D6", "Dread fully restores original dice")
	apply(f, "dice_dread", 100)
	check(str(DeepCreatures.effective_dice(f.foe)[0].shape) == "D2", "Dread can exceed tier count without going below d2")
	f = setup()
	apply(f, "clouded", 2)
	var slot: int = int(f.foe.clouded_move)
	var before_rng: int = f.rng.dice.state
	apply(f, "clouded", 1)
	check(int(f.foe.clouded_move) == slot and int(f.foe.statuses.clouded) == 3 and f.rng.dice.state == before_rng, "reapplying Clouded extends one fixed random skill without rerolling")
	var disabled: String = str(f.foe.moves[slot].name)
	for face in f.foe.dice[0].faces:
		face.value = 6
	var before: String = JSON.stringify(f.state)
	DeepBattle.forecast(f.state, "p0")
	check(JSON.stringify(f.state) == before and int(f.foe.clouded_move) == slot, "forecast never rerolls or mutates the clouded ability")
	var events: Array = turn(f)
	var moves: Array = events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "enemy_move")
	check(moves.size() == 1 and str(moves[0].move) != disabled, "Clouded disables its selected ability while other qualifying abilities still fire")
	check(int(f.foe.statuses.clouded) == 2, "Clouded loses one duration after the complete enemy action")
	f.foe.statuses.stun = 1
	turn(f)
	check(int(f.foe.statuses.clouded) == 1, "Clouded also expires through a stunned action")
	DeepCreatures.finish(f.foe)
	DeepCreatures.prepare(f.foe)
	check(int(f.foe.clouded_move) == -1 and not f.foe.move_states.has("clouded"), "expired Clouded restores the move")

func combo_breaker() -> void:
	for key in ["CAVE_TICK", "THE_FOREMAN"]:
		var f: Dictionary = setup(key)
		f.foe.statuses.ward = 0
		apply(f, "stun", 20)
		for i in range(3):
			var events: Array = turn(f)
			check(not events.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "enemy_roll"), "%s misses stunned turn %d" % [key, i + 1])
		check(int(f.foe.statuses.get("stun", 0)) == 0 and int(f.foe.statuses.get("combo_breaker", 0)) == 1, "third stun clears all excess stacks and grants immunity")
		f.foe.statuses.ward = 1
		check(bool(apply(f, "stun", 100)[0].get("resisted", false)) and int(f.foe.statuses.ward) == 1, "Combo Breaker rejects Stun without spending Ward")
		var fourth: Array = turn(f)
		check(fourth.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "enemy_roll"), "%s must act on the fourth turn" % key)
		check(int(f.foe.statuses.get("combo_breaker", 0)) == 0, "immunity expires after the protected turn")
		f.foe.statuses.ward = 0
		apply(f, "stun", 1)
		check(int(f.foe.statuses.stun) == 1, "Stun can land again after the protected turn")
	var f: Dictionary = setup()
	apply(f, "stun", 2)
	turn(f)
	turn(f)
	turn(f)
	apply(f, "stun", 1)
	turn(f)
	check(int(f.foe.stun_streak) == 1 and int(f.foe.statuses.get("combo_breaker", 0)) == 0, "an ordinary action breaks the consecutive-stun streak")

func curse_and_marked() -> void:
	var f: Dictionary = setup()
	apply(f, "curse", 2)
	apply(f, "curse", 1, false)
	var shown: Array = DeepCreatures.display_moves(f.foe, [{"effects": [{"kind": "damage", "amount": 100}]}])
	check(DeepRules.amount(shown[0].effects[0].amount, {}) == 80, "enemy damage previews use the same ten-percent Curse penalty")
	var hit: Dictionary = apply(f, "damage", 100)[0]
	check(int(hit.raw) == 108, "outgoing and incoming Curse multiply: 100 × .9 × 1.2")
	hit = apply(f, "damage", 100, false)[0]
	check(int(hit.raw) == 88, "Curse works in both directions")
	apply(f, "curse", 9, false)
	hit = apply(f, "damage", 100)[0]
	check(int(hit.raw) == 0 and int(hit.hp_loss) == 0, "ten Curse stacks reduce outgoing damage to zero")
	DeepBattle._tick(f.state)
	check(int(f.player.statuses.curse) == 9 and int(f.foe.statuses.curse) == 1, "Curse loses one stack rather than clearing")
	for stacks in range(11):
		check(DeepRules.outgoing_damage(100, {"curse": stacks}) == 100 - 10 * stacks, "Curse stack %d reduces outgoing damage by exactly 10%% without float rounding loss" % stacks)
	for to_enemy in [true, false]:
		var capped: Dictionary = setup()
		var target: Dictionary = capped.foe if to_enemy else capped.player
		apply(capped, "curse", 7, to_enemy)
		var application: Dictionary = apply(capped, "curse", 8, to_enemy)[0]
		check(int(target.statuses.curse) == 10 and int(application.curse_after) == 10, "Curse additions cap at ten for either side, including the event")
		apply(capped, "curse", 100, to_enemy)
		check(int(target.statuses.curse) == 10, "reapplication discards excess Curse stacks")
		check(int(apply(capped, "damage", 100, to_enemy)[0].raw) == 200, "ten Curse stacks double incoming damage")
		check(int(apply(capped, "damage", 100, not to_enemy)[0].raw) == 0, "capped Curse prevents outgoing hit damage for either side")
		DeepBattle._tick(capped.state)
		check(int(target.statuses.curse) == 9 and int(apply(capped, "damage", 100, not to_enemy)[0].raw) == 10, "decaying from the cap restores exactly ten percent outgoing damage")
		check(int(apply(capped, "damage", 100, to_enemy)[0].raw) == 190, "nine Curse stacks amplify incoming damage by ninety percent")
	f = setup()
	cast(f, "CURSE", true, [1, 1, 1, 1, 1])
	cast(f, "CURSE", true, [1, 1, 1, 1, 1])
	check(int(f.foe.statuses.curse) == 10, "heavy Flawless Curse and repeat firings respect the stack cap")
	f = setup()
	apply(f, "curse", 2)
	apply(f, "marked", 2)
	check(int(apply(f, "damage", 20)[0].raw) == 36, "Curse's 10-percent modifier combines with Marked's 25-percent modifier")
	f = setup()
	apply(f, "marked", 10)
	hit = apply(f, "damage", 20)[0]
	check(int(hit.raw) == 70 and int(hit.marked_spent) == 10, "10 marks make the next hit 350% of normal")
	check(int(apply(f, "damage", 20)[0].raw) == 20, "every mark is consumed on the first hit")
	apply(f, "marked", 1, false)
	f.player.block = 100
	check(int(apply(f, "damage", 20, false)[0].absorbed) == 25 and not f.player.statuses.has("marked"), "player Marked is consumed even by a fully blocked hit")
	apply(f, "marked", 2)
	apply(f, "poison", 1)
	DeepBattle._tick(f.state)
	check(int(f.foe.statuses.marked) == 2, "Poison and end-of-turn ticks do not consume Marked")
	var multi: Array = DeepBattle._apply(f.state, f.player, {"kind": "damage", "target": "enemy", "amount": 20, "repeat": 3}, f.rng.dice)
	check(multi.map(func(e: Dictionary) -> int: return int(e.raw)) == [30, 20, 20], "only the first hit in a multi-hit attack uses Marked")

func retain_and_regeneration() -> void:
	var f: Dictionary = setup()
	f.player.block = 20
	apply(f, "retain", 4, false)
	apply(f, "retain", 3, false)
	f.foe.block = 20
	apply(f, "retain", 8)
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(int(f.player.block) == 7 and not f.player.statuses.has("retain"), "Retain stacks and is consumed at player Block reset")
	DeepBattle.start_resolution(f.state)
	while DeepBattle.has_steps(f.state):
		var event: Dictionary = DeepBattle.step(f.state, f.rng.dice, f.rng.creatures)
		if str(event.get("kind", "")) == "enemy_begin":
			break
	check(int(f.foe.block) == 8 and not f.foe.statuses.has("retain"), "enemy Retain survives the enemy-side Block reset")
	DeepBattle._reset_defenses(f.foe)
	check(int(f.foe.block) == 0, "Retain does not persist past its one reset")
	apply(f, "retain", 100)
	check(int(f.foe.statuses.retain) == 20, "Retain keeps its proposed 20-point cap on either side")
	f = setup()
	f.foe.hp = 990
	f.player.hp = 990
	apply(f, "regeneration", 120)
	apply(f, "regeneration", 5, false)
	apply(f, "regeneration", 2, false)
	DeepBattle._tick(f.state)
	check(int(f.foe.hp) == 1000 and int(f.foe.statuses.regeneration) == 119, "uncapped enemy Regeneration clamps healing to max HP and decays one")
	check(int(f.player.hp) == 997 and int(f.player.statuses.regeneration) == 6, "player Regeneration adds stacks and heals at turn end")
	f.player.hp = 1
	apply(f, "poison", 2, false)
	DeepBattle._tick(f.state)
	check(int(f.player.hp) == 0 and bool(f.player.downed), "Regeneration cannot rescue a player killed by the preceding Poison tick")

func charged_and_dulled() -> void:
	var f: Dictionary = setup()
	var skills: Dictionary = DeepContent.section("skills")
	skills.TEST_BATTERY = {"name": "Battery test", "color": "WHITE", "trigger": {"kind": "always"}, "effects": [{"kind": "charged", "amount": 3}]}
	f.player.rail[0] = DeepStone.make("TEST_BATTERY", 1, 4, 3)
	DeepBattle.forecast(f.state, "p0")
	check(not f.player.statuses.has("charged"), "previewing a Charged gem cannot grant live stacks")
	var charged_turn: Array = turn(f)
	check(int(f.player.initial_resonance) == 3 and charged_turn.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "turn_begin" and e.get("charged", []).size() == 1), "a content-authored Charged gem feeds the following turn's battery event")
	skills.erase("TEST_BATTERY")
	f = setup()
	apply(f, "charged", 80, false)
	apply(f, "charged", 45, false)
	var event: Dictionary = DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(int(f.player.resonance) == 125 and int(f.player.initial_resonance) == 125 and not f.player.statuses.has("charged"), "all uncapped Charged stacks become starting Resonance")
	check(event.charged.size() == 1 and int(event.charged[0].amount) == 125, "turn event supplies the Charged animation amount")
	f.player.rail[0] = DeepStone.make("STRIKE", 1, 4, 3)
	for die in f.player.hand:
		die.value = 6
	var forecast: Dictionary = DeepBattle.forecast(f.state, "p0")
	check(int(forecast.totals.resonance) == 126 and int(f.player.resonance) == 125, "forecast starts with the battery without mutating live Resonance")
	var events: Array = turn(f)
	var fired: Array = events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "gem_fire")
	check(int(fired[0].resonance) == 126, "rail start preserves battery charge")
	check(int(f.player.resonance) == 0 and int(f.player.initial_resonance) == 0, "the following turn has no charge left")
	f = setup()
	f.player.rail[0] = DeepStone.make("STRIKE", 1, 4, 3)
	f.player.rank_buff.cut = 20
	apply(f, "dulled", 3, false)
	apply(f, "dulled", 2, false)
	var preview: Dictionary = DeepBattle.forecast(f.state, "p0")
	check(int(preview.sockets[0].cut_step) == 0, "five Dulled stacks guarantee Poor even with excess positive Cut bonuses")
	DeepBattle._tick(f.state)
	check(int(f.player.statuses.dulled) == 4, "Dulled loses one stack per turn")
	f.player.statuses.dulled = 1
	var context: Dictionary = DeepBattle.rail_context(f.state, f.player, 0, {})
	check(int(DeepStone.effective(f.player.rail[0], context).cut_step) == 3, "Dulled subtracts after clamping the normal Cut ladder")

func sparkle_cap() -> void:
	var f: Dictionary = setup()
	f.player.sparkle = 99
	f.player.rail[0] = DeepStone.make("PROSPECT", 1, 4, 3)
	DeepBattle.forecast(f.state, "p0")
	check(int(f.player.sparkle) == 99, "forecasting Prospect cannot grant live Sparkle")
	cast(f, "PROSPECT")
	check(int(f.player.sparkle) == 100, "Prospect reaches the 100 Sparkle cap")
	var firing: Dictionary = cast(f, "PROSPECT", true)
	check(int(f.player.sparkle) == 100 and firing.effects.all(func(e: Dictionary) -> bool: return int(e.get("total", 0)) == 100), "heavy Flawless Prospect applications stay capped, including event totals")
	f.player.sparkle = 0
	DeepBattle._self_effect(f.state, f.player, {"kind": "sparkle", "amount": 150}, 0, -1, false, f.rng.dice)
	check(int(f.player.sparkle) == 100, "one large Sparkle grant also respects the cap")
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(int(f.player.sparkle) == 100, "Sparkle is retained through turn boundaries")

func spikes() -> void:
	var f: Dictionary = setup()
	apply(f, "spikes", 7)
	f.foe.block = 100
	var hits: Array = DeepBattle._apply(f.state, f.player, {"kind": "damage", "target": "enemy", "amount": 10, "repeat": 3}, f.rng.dice)
	check(int(f.player.hp) == 993 and hits[0].has("spikes") and not hits[1].has("spikes"), "enemy Spikes retaliates once per multi-hit ability, even against blocked hits")
	apply(f, "damage", 10)
	check(int(f.player.hp) == 986, "a separate attack triggers Spikes again")
	apply(f, "spikes", 150, false)
	apply(f, "marked", 10)
	apply(f, "damage", 10, false)
	check(int(f.foe.hp) == 910 and int(f.foe.statuses.marked) == 10, "uncapped player Spikes respects remaining enemy Block, does not consume Marked or recursively retaliate")
	DeepBattle._reset_defenses(f.player)
	check(not f.player.statuses.has("spikes"), "Spikes expires at the owner's Block reset")
	var party: Dictionary = setup("CAVE_TICK", 4)
	party.foe.hp = 1
	party.player.statuses.spikes = 5
	var all: Array = apply(party, "damage", 3, false)
	check(all.size() == 4 and party.state.players.all(func(p: Dictionary) -> bool: return int(p.hp) == 997), "a lethal retaliation still lets the triggering party-wide hit reach every player")
	check(str(party.state.outcome) == "victory", "lethal Spikes settles the battle")

func cleanse_and_content() -> void:
	var f: Dictionary = setup()
	f.foe.statuses = {"poison": 1, "stun": 1, "curse": 1, "marked": 1, "dulled": 1, "clouded": 1, "ward": 2, "regeneration": 4}
	f.foe.dread_turns = 2
	apply(f, "cleanse", 8)
	check(int(f.foe.statuses.ward) == 2 and int(f.foe.statuses.regeneration) == 4, "Cleanse leaves beneficial statuses intact")
	check(int(f.foe.dread_turns) == 0 and not f.foe.move_states.has("clouded"), "Cleanse removes new harmful stacks and restores abilities")
	check(DeepContent.validate().is_empty(), "updated content validates")
	check(int(DeepStone.evaluate(DeepStone.make("CURSE", 1, 4, 3), [{"die_id": "one", "value": 1, "kind": "plain", "top": 6}]).effects[0].amount) == 1, "Curse gem uses stacks instead of old percentage amounts")
	for kind in ["ward", "retain", "charged", "marked", "regeneration", "spikes", "dulled", "clouded"]:
		check(DeepRules.validate_effect({"kind": kind, "amount": 1}, "test").is_empty(), "%s is authorable in content" % kind)

func cast(f: Dictionary, key: String, flawless: bool = false, values: Array = [5, 5, 5, 2, 2]) -> Dictionary:
	f.player.sockets[0] = "ANY"
	f.player.rail[0] = DeepStone.make(key, 5 if flawless else 1, 4, 5 if flawless else 3)
	for i in range(f.player.hand.size()):
		f.player.hand[i].value = int(values[i])
		f.player.hand[i].held = true
	return DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)

func gem_integrations() -> void:
	for key in ["MIST", "ETCH"]:
		check(DeepForge.skill_pool(DeepContent.mine(DeepContent.starter_mine())).has(key), "%s is available in the ordinary mine pool" % key)
		var f: Dictionary = setup()
		cast(f, key, false, [1, 2, 3, 4, 5])
		check(int(f.foe.statuses.get("clouded" if key == "MIST" else "marked", 0)) == 0, "%s requires a pair" % key)
		cast(f, key)
		if key == "MIST":
			check(int(f.foe.statuses.clouded) == 1 and f.foe.move_states.count("clouded") == 1, "Mist disables exactly one enemy ability")
			var slot: int = int(f.foe.clouded_move)
			cast(f, key, true)
			check(int(f.foe.statuses.clouded) in [2, 3] and int(f.foe.clouded_move) == slot, "Flawless Mist applies its base duration to every enemy, retaining an existing slot")
		else:
			check(int(f.foe.statuses.marked) == 2, "Etch applies two Marked without spending them")
			check(int(apply(f, "damage", 20)[0].raw) == 30 and int(apply(f, "damage", 20)[0].raw) == 20, "Etch boosts only the next hit")
			cast(f, key, true)
			check(int(f.foe.statuses.marked) in [3, 6], "Flawless Etch adds the third mark before whole-number scaling")
		f = setup("THE_FOREMAN")
		cast(f, key)
		check(int(f.foe.statuses.ward) == 0 and int(f.foe.statuses.get("clouded" if key == "MIST" else "marked", 0)) == 0, "opening Ward blocks %s" % key)
	for spec in [["AEGIS", "ward", [1, 2]], ["BASTION", "retain", [12]], ["MEND", "regeneration", [6]], ["ANCHOR", "spikes", [6]], ["PRISM", "charged", [2, 4]]]:
		var f: Dictionary = setup("CAVE_TICK", 2)
		var values: Array = [1, 2, 3, 4, 5] if spec[0] == "AEGIS" else [5, 5, 5, 2, 2]
		f.player.hp = 900
		cast(f, str(spec[0]), false, values)
		check(int(f.player.statuses.get(str(spec[1]), 0)) == 0, "%s grants its new buff only when Flawless" % spec[0])
		f.player.block = 0
		f.player.resonance = 0
		f.player.previous_fired = false
		f.player.statuses.poison = 1
		cast(f, str(spec[0]), true, values)
		check(int(f.player.statuses.get(str(spec[1]), 0)) in spec[2], "Flawless %s applies the scaled %s amount" % [spec[0], spec[1]])
		var party_buff: bool = spec[0] in ["AEGIS", "BASTION"]
		check(int(f.state.players[1].statuses.get(str(spec[1]), 0)) == (int(f.player.statuses.get(str(spec[1]), 0)) if party_buff else 0), "%s uses the intended self/party target" % spec[0])
		check(int(f.player.statuses.poison) == 1, "%s does not retain an old cleanse rider" % spec[0])
		match str(spec[0]):
			"ANCHOR": check(int(f.player.block) == 30, "Anchor keeps base held-dice Block and replaces its old bonus with Spikes")
			"MEND": check(int(f.player.block) == 0 and int(f.player.hp) > 900, "Mend keeps direct healing and replaces its old Block rider")
			"PRISM":
				check(int(f.player.resonance) in [8, 13], "Prism keeps its scaled base Resonance without the old immediate bonus")
				var charge: int = int(f.player.statuses.charged)
				var begin: Dictionary = DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
				check(int(f.player.initial_resonance) == charge and int(begin.charged[0].amount) == charge, "Flawless Prism feeds the next turn's battery animation")
	var renewal: Dictionary = setup()
	renewal.player.statuses = {"poison": 2, "curse": 2, "marked": 2}
	cast(renewal, "RENEWAL", false, [1, 2, 3, 4, 5])
	check(int(renewal.player.statuses.poison) == 0 and int(renewal.player.statuses.curse) == 1 and int(renewal.player.statuses.marked) == 2, "Renewal cleanses individual stacks in priority order")

func fixed_content_dice(f: Dictionary, values: Array) -> void:
	f.foe.dice = DeepCreatures.make(str(f.foe.key), str(f.foe.id), 1, 1).dice
	for i in range(values.size()):
		f.foe.dice[i].top = DeepDice.top(f.foe.dice[i])
		for face in f.foe.dice[i].faces:
			face.value = int(values[i])

func enemy_integrations() -> void:
	var golem: Dictionary = setup("QUARTZ_GOLEM")
	fixed_content_dice(golem, [2])
	turn(golem)
	check(int(golem.foe.statuses.retain) == 3, "Harden grants Retain through a real enemy turn")
	DeepBattle._reset_defenses(golem.foe)
	check(int(golem.foe.block) == 3, "Harden carries three Block through the next enemy reset")
	var slime: Dictionary = setup("SILT_SLIME")
	fixed_content_dice(slime, [8])
	slime.foe.hp = 990
	turn(slime)
	check(int(slime.foe.hp) == 992 and int(slime.foe.statuses.regeneration) == 1, "Reknit can activate with the Slime's single die and heals at turn end")
	var wyrm: Dictionary = setup("GLASS_WYRM")
	fixed_content_dice(wyrm, [2, 2, 3])
	turn(wyrm)
	check(int(wyrm.foe.statuses.spikes) == 2, "Coil grants Spikes once when the pair completes")
	var foreman: Dictionary = setup("THE_FOREMAN")
	fixed_content_dice(foreman, [1, 12])
	turn(foreman)
	check(int(foreman.foe.statuses.ward) == 2 and int(foreman.foe.dice_upgrade) == 0, "Shore Up replenishes Ward instead of upgrading dice")
	var omen: Dictionary = setup("VEIN_WRAITH", 2)
	fixed_content_dice(omen, [10])
	turn(omen)
	check(omen.state.players.all(func(p: Dictionary) -> bool: return int(p.statuses.get("marked", 0)) == 1), "Omen marks the whole party after its damage resolves")
	check(int(apply(omen, "damage", 20, false)[0].raw) == 25, "Omen boosts the next enemy attack")
	for key in ["CLOUDER", "THE_DRILL", "THE_REGENT"]:
		var f: Dictionary = setup(key, 2)
		var kind: String = "curse" if key == "THE_REGENT" else "dulled"
		if key == "THE_REGENT":
			f.foe.hp = 300
		fixed_content_dice(f, [16] if key == "THE_REGENT" else ([6, 1] if key == "THE_DRILL" else [6]))
		f.state.players[1].statuses.ward = 1
		turn(f)
		check(int(f.player.statuses.get(kind, 0)) == 1, "%s's fresh %s survives to the next player turn" % [key, kind])
		check(int(f.state.players[1].statuses.get(kind, 0)) == 0 and int(f.state.players[1].statuses.ward) == 0, "Ward protects one player from %s" % key)
		check(f.player.hand.size() == 5, "%s leaves the player's dice intact" % key)
		f.player.rail[0] = DeepStone.make("STRIKE", 1, 4, 3)
		if kind == "dulled":
			check(int(DeepBattle.forecast(f.state, "p0").sockets[0].cut_step) == 3, "%s reduces the next rail's effective Cut" % key)
		else:
			f.foe.block = 0
			check(int(apply(f, "damage", 20)[0].raw) == 18 and int(apply(f, "damage", 20, false)[0].raw) == 22, "Splinter changes both outgoing and incoming damage by ten percent next turn")
		f.player.rail[0] = null
		# Reapplication must not indefinitely postpone decay of an existing stack.
		turn(f)
		check(int(f.player.statuses.get(kind, 0)) == 1, "%s reapplication still decays one existing stack" % key)
		fixed_content_dice(f, [1, 1] if key == "THE_DRILL" else [1])
		turn(f)
		check(int(f.player.statuses.get(kind, 0)) == 0, "%s expires after a full affected turn without reapplication" % kind)
