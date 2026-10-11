extends SceneTree
## The altar and the Transcendent gems: what five gems make, what the made gem is like, where
## altars stand on the map, the room itself, what the vault loses and learns, and each
## Transcendent doing the one thing only it does.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_recipes()
	_test_refusals()
	_test_making()
	_test_never_rolled()
	_test_map()
	_test_room()
	_test_vault_and_secrecy()
	_test_black_opal_absorbs()
	_test_rainbow_seam()
	_test_procession()
	_test_quintessence()
	_test_gemini()
	_test_certainty()
	_test_trigger_swaps()
	print("Altar: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func gem(skill: String, carat: int = 4, cut: int = 2, clarity: int = 3, inclusions: Array = [], id: String = "") -> Dictionary:
	var s: Dictionary = DeepStone.make(skill, carat, cut, clarity, inclusions, {}, id if not id.is_empty() else "%s_%d" % [skill.to_lower(), randi()])
	s.appraised = true
	s.inclusions_revealed = true
	return s

func five(skills: Array, carat: int = 4, cut: int = 2, clarity: int = 3) -> Array:
	return skills.map(func(k: String) -> Dictionary: return gem(k, carat, cut, clarity))

func rngs(seed_value: int) -> Dictionary:
	return DeepRng.streams(seed_value, ["dice", "creatures"])

func dice_of(character: String, prefix: String) -> Array:
	var out: Array = []
	var keys: Array = DeepContent.character(character).dice
	for index in range(keys.size()):
		out.append(DeepForge.die_from(keys[index], "%s%d" % [prefix, index]))
	return out

func player(id: String, rail: Array, character: String = "ARDOR") -> Dictionary:
	return DeepBattle.make_player(id, id.capitalize(), character, rail, dice_of(character, id))

func hand(unit: Dictionary, numbers: Array) -> void:
	var out: Array = []
	for index in range(numbers.size()):
		var die: Dictionary = unit.dice[index % unit.dice.size()]
		out.append({"die_id": str(die.id), "shape": str(die.shape), "material": str(die.get("material", "")), "value": int(numbers[index]), "face": 0, "kind": "plain",
			"top": DeepDice.top(die), "held": false, "rerolls": 0, "locked": false, "explosions": 0, "phantom": false})
	unit.hand = out

func run_turn(state: Dictionary, r: Dictionary) -> Array:
	for unit in state.players:
		unit.locked = true
	var events: Array = [DeepBattle.start_resolution(state)]
	var guard: int = 0
	while DeepBattle.has_steps(state) and guard < 400:
		guard += 1
		var event: Dictionary = DeepBattle.step(state, r.dice, r.creatures)
		if not event.is_empty():
			events.append(event)
	return events

func at_socket(events: Array, socket: int) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "gem_fire" and int(e.get("socket", -1)) == socket)

func effect(event: Dictionary, kind: String) -> Dictionary:
	for e in event.get("effects", []):
		if str(e.get("kind", "")) == kind:
			return e
	return {}

func run_config(seed_value: int, rail_a: Array = []) -> Dictionary:
	return {"seed": seed_value, "mine": "QUARRY", "boons": false, "players": [
		{"id": "a", "name": "Ada", "character": "ARDOR", "rail": rail_a, "dice": dice_of("ARDOR", "a")},
		{"id": "b", "name": "Bo", "character": "VESPER", "rail": [], "dice": dice_of("VESPER", "b")}]}

func into(state: Dictionary, kind: String) -> void:
	## Walks the party into a chamber of this kind, whatever the map offered.
	state.offers = [ {"id": "test_" + kind, "kind": kind, "hidden": false}]
	for unit in state.players:
		DeepDescent.command(state, str(unit.id), {"kind": "vote_tunnel", "offer": "test_" + kind})

# --- what five gems make -------------------------------------------------------------------------

func _test_recipes() -> void:
	var made: Dictionary = DeepAltar.recipe_for(five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE", "EMBER"]))
	check(str(made.get("skill", "")) == "SEAM_RED" and str(made.kind) == "seam", "five Red gems, repeats and all, make the Red Seam")
	check(str(DeepAltar.recipe_for(five(["GLIMMER", "MIRROR", "CASCADE", "FACET", "PRISM"])).get("skill", "")) == "SEAM_WHITE", "five White gems make the White Seam")
	check(str(DeepAltar.recipe_for(five(["BARRAGE", "AEGIS", "RENEWAL", "DREAD", "GILDED_ARMOR"])).get("skill", "")) == "PROCESSION",
		"the five straight gems make Procession, though they are also five colors")
	check(str(DeepAltar.recipe_for(five(["GILDED_ARMOR", "DREAD", "BARRAGE", "RENEWAL", "AEGIS"])).get("skill", "")) == "PROCESSION", "in any order")
	check(str(DeepAltar.recipe_for(five(["SEAM_RED", "SEAM_BLUE", "SEAM_GREEN", "SEAM_GOLD", "SEAM_WHITE"])).get("skill", "")) == "RAINBOW_SEAM",
		"five different Seams make the Rainbow Seam")
	check(DeepAltar.recipe_for(five(["SEAM_RED", "SEAM_RED", "SEAM_GREEN", "SEAM_GOLD", "SEAM_WHITE"])).is_empty(), "five Seams with one twice stay cold")
	check(str(DeepAltar.recipe_for(five(["PINFIRE", "DOUBLET", "MATRIX", "ECHO", "PRELUDE"])).get("skill", "")) == "BLACK_OPAL", "the five other opals make the Black Opal")
	check(str(DeepAltar.recipe_for(five(["FIRE_OPAL", "DOUBLET", "MATRIX", "ECHO", "PRELUDE"])).get("skill", "")) != "BLACK_OPAL", "and Fire Opal is no longer one of them: Pinfire took its place")
	check(str(DeepAltar.recipe_for(five(["LODESTONE", "CRESCENDO", "BARRAGE", "AEGIS", "DREAD"])).get("skill", "")) == "PROCESSION", "Lodestone and Crescendo, straight gems now, can make Procession")
	check(str(DeepAltar.recipe_for(five(["CRUSH", "SAP", "BASTION", "SHATTER", "JACKPOT"])).get("skill", "")) == "QUINTESSENCE", "the three-of-a-kind gems make Quintessence")
	check(str(DeepAltar.recipe_for(five(["CLEAVE", "GUARD", "VENOM", "TITHE", "CASCADE"])).get("skill", "")) == "GEMINI", "the common pair gems make Gemini")
	check(str(DeepAltar.recipe_for(five(["STRIKE", "RIPOSTE", "SIPHON", "MIASMA", "PRISM"])).get("skill", "")) == "CERTAINTY", "the any-hand gems make Certainty")
	var colors: Dictionary = DeepAltar.recipe_for(five(["STRIKE", "GUARD", "MEND", "HEX", "TITHE"]))
	check(str(colors.get("kind", "")) == "opal" and str(colors.skill).is_empty(), "five different colors make an opal still to be drawn")
	check(str(DeepAltar.recipe_for(five(["STRIKE", "GUARD", "MEND", "TITHE", "FIRE_OPAL"])).get("kind", "")) == "opal", "an opal counts as a color of its own")
	check(DeepAltar.recipe_for(five(["STRIKE", "STRIKE", "GUARD", "MEND", "TITHE"])).is_empty(), "two Reds and three others stay cold")
	check(DeepAltar.recipe_for(five(["FIRE_OPAL", "FIRE_OPAL", "DOUBLET", "MATRIX", "ECHO"])).is_empty(), "five opals that are no recipe stay cold")
	check(DeepAltar.recipe_for(five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE"])).is_empty(), "four gems make nothing")
	## A Zoning does not change a gem's color at the altar.
	var zoned: Array = five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE", "EMBER"])
	zoned[0].inclusions = ["ZONING_BLUE"]
	check(str(DeepAltar.recipe_for(zoned).get("skill", "")) == "SEAM_RED", "a Zoning is not a color at the altar")

func _test_refusals() -> void:
	var raw: Dictionary = gem("STRIKE")
	raw.appraised = false
	check(not DeepAltar.refusal(raw).is_empty(), "a stone still in its rock cannot go on the altar")
	var lent: Dictionary = gem("STRIKE")
	lent.temporary = true
	check(not DeepAltar.refusal(lent).is_empty(), "nor can a temporary stone")
	check(not DeepAltar.refusal(gem("PROCESSION")).is_empty(), "nor a Transcendent")
	check(not DeepAltar.refusal(DeepStone.birthstone("ARDOR")).is_empty(), "nor a Birthstone")
	check(DeepAltar.refusal(gem("STRIKE")).is_empty(), "an ordinary read gem can")
	var with_raw: Array = five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE", "EMBER"])
	with_raw[2].appraised = false
	check(DeepAltar.recipe_for(with_raw).is_empty(), "five with a raw one among them stay cold")

# --- the gem that comes out ------------------------------------------------------------------------

func _test_making() -> void:
	var mine: Dictionary = DeepContent.mine("QUARRY")
	var cuts: Dictionary = {}
	var clarities: Dictionary = {}
	var carat_sum: int = 0
	var trials: int = 400
	var in_range: bool = true
	for seed_value in range(trials):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var offered: Array = five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE", "EMBER"], 8, 2, DeepContent.clear_index())
		var made: Dictionary = DeepAltar.make(rng, offered, {"kind": "seam", "skill": "SEAM_RED"}, mine, {"run": "r"}, "st%d" % seed_value)
		cuts[int(made.cut)] = int(cuts.get(int(made.cut), 0)) + 1
		clarities[int(made.clarity)] = int(clarities.get(int(made.clarity), 0)) + 1
		carat_sum += int(made.carat)
		in_range = in_range and int(made.carat) >= 9 and int(made.carat) <= 11
		if seed_value == 0:
			check(str(made.skill) == "SEAM_RED" and bool(made.appraised) and bool(made.inclusions_revealed), "the made gem is the recipe's, already read")
			check(str(made.provenance.get("source", "")) == "altar", "and says it came from an altar")
	check(in_range, "five 8-carat gems make a 9 to 11 carat one: 20-30% more, nudged by one at most")
	var mean: float = float(carat_sum) / float(trials)
	check(mean > 9.5 and mean < 10.5, "and about 10 on average (%.2f)" % mean)
	var fine: int = int(cuts.get(3, 0))
	check(fine > trials * 3 / 4 and cuts.keys().all(func(k: Variant) -> bool: return int(k) >= 2 and int(k) <= 4),
		"five Good gems make a Fine one most of the time, never more than a grade off: %s" % str(cuts))
	var pristine: int = DeepContent.clarity_index("PRISTINE")
	check(int(clarities.get(pristine, 0)) > trials * 3 / 4, "five Clear gems make a Pristine one most of the time: %s" % str(clarities))
	## The top of every ladder holds.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var best: Dictionary = DeepAltar.make(rng, five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE", "EMBER"], 22, 4, DeepContent.clarity_index("FLAWLESS")),
		{"kind": "seam", "skill": "SEAM_RED"}, mine, {}, "best")
	check(int(best.carat) == DeepStone.carat_max() and int(best.cut) >= 3 and int(best.clarity) >= DeepContent.clarity_index("PRISTINE"),
		"five of the very best never make anything past the top of the ladder")
	## Inclusions come from the five first.
	var intricate: int = DeepContent.clarity_index("INTRICATE")
	var carried: Array = five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE", "EMBER"], 4, 2, intricate)
	for stone in carried:
		stone.inclusions = ["SILK", "NEEDLE", "ZONING_BLUE"]
	rng.seed = 11
	var kept: Dictionary = DeepAltar.make(rng, carried, {"kind": "transcendent", "skill": "PROCESSION"}, mine, {}, "kept")
	check(not kept.inclusions.has("ZONING_BLUE"), "a Zoning of a color the new gem already counts as is left behind")
	if DeepStone.inclusion_slots(int(kept.clarity)) >= 2:
		check(kept.inclusions.has("SILK") and kept.inclusions.has("NEEDLE"), "and the rest of what the five carried goes into the new gem")
	check(kept.inclusions.size() <= DeepStone.inclusion_slots(int(kept.clarity)), "never more inclusions than the Clarity has room for")
	## An opal drawn at random is never a Transcendent.
	var drawn: Dictionary = {}
	for seed_value in range(200):
		rng.seed = seed_value
		var opal: Dictionary = DeepAltar.make(rng, five(["STRIKE", "GUARD", "MEND", "HEX", "TITHE"]), {"kind": "opal", "skill": ""}, mine, {}, "o")
		drawn[str(opal.skill)] = true
	check(drawn.keys().all(func(k: Variant) -> bool: return DeepContent.skill(str(k)).color == "OPAL" and not DeepContent.is_transcendent(str(k))),
		"five colors make an ordinary opal, never a Transcendent: %s" % str(drawn.keys()))
	check(drawn.size() > 4, "and any of them")

func _test_never_rolled() -> void:
	for key in DeepContent.section("mines"):
		var pool: Array = DeepForge.skill_pool(DeepContent.mine(str(key)))
		check(not pool.any(func(k: Variant) -> bool: return DeepContent.is_transcendent(str(k))), "no Transcendent in %s's rock" % str(key))
	check(not DeepForge.opal_pool().any(func(k: Variant) -> bool: return DeepContent.is_transcendent(str(k))), "nor in the opals a hoard reaches for")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var found: bool = false
	for _i in range(1500):
		var stone: Dictionary = DeepForge.roll_stone(rng, DeepContent.mine("GEODE"), 30, 10.0)
		found = found or DeepStone.is_transcendent(stone)
	check(not found, "and a thousand and a half stones out of the deep rock hold none")
	check(not DeepEconomy.commission_pool(DeepProfile.new_profile()).any(func(k: Variant) -> bool: return DeepContent.is_transcendent(str(k))), "no commission asks for one")

# --- the map ------------------------------------------------------------------------------------------

func _test_map() -> void:
	var first_stretch: int = 0
	var later: int = 0
	var doubled: bool = false
	for seed_value in range(300):
		var state: Dictionary = DeepDescent.new_run(run_config(seed_value))
		for node in state.map.nodes.values():
			if str(node.kind) == "altar":
				first_stretch += 1
		state.depth = DeepDescent.landing_every()
		DeepDescent._chart(state, DeepDescent.streams_of(state))
		var here: int = state.map.nodes.values().filter(func(n: Dictionary) -> bool: return str(n.kind) == "altar").size()
		later += here
		doubled = doubled or here > 1
	check(first_stretch == 0, "no altar in the first stretch of a mine")
	check(not doubled, "never two in one stretch")
	check(later > 15 and later < 80, "but one in a few stretches below it (%d in 300)" % later)
	check(DeepDescent.glint({"kind": "altar"}) == "strange", "its mouth glints strange")

# --- the room -------------------------------------------------------------------------------------------

func _test_room() -> void:
	var state: Dictionary = DeepDescent.new_run(run_config(42))
	var a: Dictionary = DeepDescent.player(state, "a")
	var b: Dictionary = DeepDescent.player(state, "b")
	for stone in five(["STRIKE", "CLEAVE", "CRUSH", "STRIKE", "EMBER"]):
		a.haul.append(stone)
	var raw: Dictionary = gem("APEX")
	raw.appraised = false
	a.haul.append(raw)
	into(state, "altar")
	check(DeepDescent.at_altar(state), "the party stands at the altar")
	var reds: Array = a.haul.slice(0, 5).map(func(s: Dictionary) -> String: return str(s.id))
	var refused: Dictionary = DeepDescent.command(state, "a", {"kind": "altar", "stone_ids": reds.slice(0, 4)})
	check(not bool(refused.ok), "four gems are refused")
	var with_raw: Array = reds.slice(0, 4) + [str(raw.id)]
	check(not bool(DeepDescent.command(state, "a", {"kind": "altar", "stone_ids": with_raw}).ok), "a raw stone among them is refused")
	check(not bool(DeepDescent.command(state, "a", {"kind": "altar", "stone_ids": reds.slice(0, 4) + [reds[0]]}).ok), "one gem in two sockets is refused")
	check(a.haul.size() == 6, "and a refusal gives nothing up")
	var done: Dictionary = DeepDescent.command(state, "a", {"kind": "altar", "stone_ids": reds})
	check(bool(done.ok) and str(done.event.kind) == "altar_made", "five Reds are given up")
	check(str(done.event.made.skill) == "SEAM_RED" and not bool(done.event.transcendent), "for a Red Seam")
	check(a.haul.size() == 2 and a.haul.any(func(s: Dictionary) -> bool: return str(s.skill) == "SEAM_RED"), "which is in the bag in their place")
	check(not bool(DeepDescent.command(state, "a", {"kind": "altar", "stone_ids": reds}).ok), "and nobody makes two things at one altar")
	check(DeepDescent.at_altar(state), "the room waits for the rest of the party")
	var left: Dictionary = DeepDescent.command(state, "b", {"kind": "altar_leave"})
	check(bool(left.ok) and not bool(left.event.get("finished", false)) and DeepDescent.at_altar(state), "and for whoever made something, until they walk on too")
	left = DeepDescent.command(state, "a", {"kind": "altar_leave"})
	check(bool(left.ok) and bool(left.event.get("finished", false)), "and closes when the last of them walks on")
	check(str(state.phase) == "tunnels", "and the party moves on")

	## A cold set: refused, and nothing changes hands.
	state = DeepDescent.new_run(run_config(43))
	a = DeepDescent.player(state, "a")
	for stone in five(["STRIKE", "STRIKE", "GUARD", "MEND", "TITHE"]):
		a.haul.append(stone)
	into(state, "altar")
	var cold: Dictionary = DeepDescent.command(state, "a", {"kind": "altar", "stone_ids": a.haul.map(func(s: Dictionary) -> String: return str(s.id))})
	check(not bool(cold.ok) and a.haul.size() == 5, "a set the circle does not know is refused and kept")

	## The rail can be given up, and a copy of a vault stone is written down as spent.
	var rail: Array = five(["BARRAGE", "AEGIS", "RENEWAL"])
	state = DeepDescent.new_run(run_config(44, rail))
	a = DeepDescent.player(state, "a")
	for stone in five(["DREAD", "GILDED_ARMOR"]):
		a.haul.append(stone)
	into(state, "altar")
	var ids: Array = DeepStone.rail_stones(a).map(func(s: Dictionary) -> String: return str(s.id)) + a.haul.map(func(s: Dictionary) -> String: return str(s.id))
	var made: Dictionary = DeepDescent.command(state, "a", {"kind": "altar", "stone_ids": ids})
	check(bool(made.ok) and bool(made.event.transcendent) and str(made.event.made.skill) == "PROCESSION", "the straight gems, rail and bag, make Procession")
	check(DeepStone.rail_stones(a).is_empty(), "the rail gave its three up")
	check(a.vault_spent.size() == 3 and a.vault_spent.has("BARRAGE"), "and the three vault copies are written down as spent")
	check(a.transcended.has("PROCESSION"), "and the player is known to have made Procession")
	DeepDescent.command(state, "b", {"kind": "altar_leave"})
	DeepDescent.command(state, "a", {"kind": "altar_leave"})
	var results: Dictionary = DeepDescent.results(state)
	check(results.players.a.vault_spent.has("AEGIS") and results.players.a.transcended.has("PROCESSION"), "the run's results carry both home")

func _test_vault_and_secrecy() -> void:
	var profile: Dictionary = DeepProfile.new_profile("Ada")
	for key in ["BARRAGE", "AEGIS", "STRIKE"]:
		DeepProfile.keep(profile, gem(key))
	var grid: Array = DeepProfile.vault_grid(profile)
	check(not grid.any(func(e: Dictionary) -> bool: return DeepContent.is_transcendent(str(e.skill))), "the vault shows no Transcendent before one is made")
	check(DeepProfile.known_skills(profile).size() == DeepContent.section("skills").size() - DeepContent.transcendents().size(), "nor counts one")
	var absorbed: Dictionary = gem("BLACK_OPAL")
	absorbed.absorbed = ["STRIKE", "GUARD"]
	var result: Dictionary = {"mine": "QUARRY", "outcome": "extracted", "depth": 4, "deepest": 4, "players": {"pa": {
		"home": [gem("PROCESSION"), absorbed], "seen": [], "dice": [], "vault_spent": ["BARRAGE", "AEGIS"], "transcended": ["PROCESSION"], "ore": 0, "earned": 0}}}
	var applied: Dictionary = DeepProfile.apply_result(profile, result, "pa")
	check(not profile.vault.has("BARRAGE") and not profile.vault.has("AEGIS") and profile.vault.has("STRIKE"), "the vault loses what was given up, and only that")
	check(applied.vault_spent.size() == 2, "and says so")
	grid = DeepProfile.vault_grid(profile)
	check(grid.any(func(e: Dictionary) -> bool: return str(e.skill) == "PROCESSION"), "the vault shows Procession once it has been made")
	check(not grid.any(func(e: Dictionary) -> bool: return str(e.skill) == "GEMINI"), "and still no other Transcendent")
	check(str(grid[grid.size() - 1].skill) == "PROCESSION", "in a row of its own after every color")
	check(not profile.tray.any(func(s: Dictionary) -> bool: return s.has("absorbed")), "a Black Opal comes home with nothing it took in down there")

func _test_black_opal_absorbs() -> void:
	var opal: Dictionary = gem("BLACK_OPAL", 4, 4, 3, [], "bo1")
	var state: Dictionary = DeepDescent.new_run(run_config(51, [gem("STRIKE", 4, 4, 3, [], "s1"), opal]))
	var a: Dictionary = DeepDescent.player(state, "a")
	var meal: Dictionary = gem("GUARD", 3, 2, 3, [], "food")
	var raw: Dictionary = gem("APEX", 3, 2, 3, [], "rough")
	raw.appraised = false
	a.haul = [meal, raw]
	into(state, "fight")
	check(DeepDescent.in_battle(state), "a fight opens")
	var on_rail: Dictionary = DeepStone.rail_stones(a)[1]
	check(on_rail.get("absorbed", []) == ["GUARD"], "the Black Opal took the read gem's skill")
	check(a.haul.size() == 1 and str(a.haul[0].id) == "rough", "and the gem is gone, but a raw stone is never taken")
	var fighter: Dictionary = DeepBattle.player(DeepDescent.battle(state), "a")
	check(DeepStone.rail_stones(fighter)[1].get("absorbed", []) == ["GUARD"], "the fight's rail knows what it took")
	## And fires it: a hand with a pair lights the Guard it took in, from its own socket.
	var r: Dictionary = rngs(2)
	var fight: Dictionary = DeepBattle.begin([player("a", [gem("STRIKE", 4, 4, 3, [], "s1"), on_rail.duplicate(true)])], ["THE_REGENT"], {"depth": 2}, r.dice, r.creatures)
	hand(fight.players[0], [4, 4, 5, 5, 5])
	var events: Array = run_turn(fight, r)
	var from_opal: Array = at_socket(events, 1)
	check(from_opal.any(func(e: Dictionary) -> bool: return str(e.get("absorbed", "")) == "GUARD" and str(e.skill) == "GUARD"), "when it fires, the Guard it took fires from its socket")
	## A Flawless one takes two.
	var flawless: Dictionary = gem("BLACK_OPAL", 4, 4, DeepContent.clarity_index("FLAWLESS"), [], "bo2")
	state = DeepDescent.new_run(run_config(52, [flawless]))
	a = DeepDescent.player(state, "a")
	a.haul = [gem("GUARD"), gem("MEND"), gem("HEX")]
	into(state, "fight")
	check(DeepStone.rail_stones(a)[0].get("absorbed", []).size() == 2 and a.haul.size() == 1, "a Flawless Black Opal takes two")

# --- the gems in a fight ---------------------------------------------------------------------------

func _test_rainbow_seam() -> void:
	var r: Dictionary = rngs(9)
	var state: Dictionary = DeepBattle.begin([player("a", [gem("STRIKE", 4, 4, 3, [], "s1"), gem("GUARD", 4, 4, 3, [], "g1"),
		gem("MEND", 1, 4, 3, [], "m1"), gem("RAINBOW_SEAM", 1, 4, 3, [], "rs")])], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [4, 4, 5, 5, 5])
	var events: Array = run_turn(state, r)
	check(at_socket(events, 0).size() == 2 and at_socket(events, 1).size() == 2 and at_socket(events, 2).size() == 2,
		"a Rainbow Seam plays every gem that fired a second time, whatever its color")

func _test_procession() -> void:
	var r: Dictionary = rngs(4)
	var state: Dictionary = DeepBattle.begin([player("a", [gem("PROCESSION", 1, 2, 3, [], "p1")])], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [2, 3, 4, 5, 6])
	var fired: Array = at_socket(run_turn(state, r), 0)
	check(fired.size() == 1, "Procession fires on a straight")
	if fired.size() == 1:
		var e: Dictionary = fired[0]
		var hit: Dictionary = effect(e, "damage")
		check(int(hit.get("raw", hit.get("amount", 0))) == 18 or int(hit.get("amount", 0)) == 18, "300%% of a 6 is 18 damage at Good: %s" % str(hit))
		check(int(effect(e, "block").get("amount", 0)) == 18, "300% of it as Block")
		check(int(effect(e, "heal").get("amount", 0)) == 3, "60% of it healed")
		check(int(effect(e, "poison").get("amount", 0)) == 1, "30% of a 6 is still a Poison, never rounded to nothing")
		check(int(effect(e, "gold").get("amount", 0)) == 1, "and a Pyrite")
	## Poor: a 10% share of a 5 is half a point, and still pays one.
	var def: Dictionary = DeepContent.skill("PROCESSION")
	var low: Dictionary = DeepStone.evaluate(gem("PROCESSION", 1, 0, 3), [{"die_id": "d0", "value": 1, "top": 6}, {"die_id": "d1", "value": 2, "top": 6},
		{"die_id": "d2", "value": 3, "top": 6}, {"die_id": "d3", "value": 4, "top": 6}, {"die_id": "d4", "value": 5, "top": 6}], {})
	check(bool(low.active) and def.effects.size() == 5, "a Poor Procession takes a straight of five")
	for e in low.get("effects", []):
		if str(e.kind) in ["poison", "gold"]:
			check(int(e.amount) == 1, "a tenth of a 5 is one %s, not none" % str(e.kind))
	## Heavier stones: the share is taken after carat.
	var heavy: Dictionary = DeepStone.evaluate(gem("PROCESSION", 10, 2, 3), [{"die_id": "d0", "value": 2, "top": 6}, {"die_id": "d1", "value": 3, "top": 6},
		{"die_id": "d2", "value": 4, "top": 6}, {"die_id": "d3", "value": 5, "top": 6}, {"die_id": "d4", "value": 6, "top": 6}], {})
	for e in heavy.get("effects", []):
		if str(e.kind) == "poison":
			check(int(e.amount) == 5, "a 10-carat Good Procession poisons for 5 off a 6 (30%% after carat), got %d" % int(e.amount))
	## Flawless: the whole party, and Pyrite in every ally's purse.
	state = DeepBattle.begin([player("a", [gem("PROCESSION", 1, 2, DeepContent.clarity_index("FLAWLESS"), [], "p2")]), player("b", [], "VESPER")],
		["RAIL_RAT", "RAIL_RAT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [2, 3, 4, 5, 6])
	hand(state.players[1], [1, 1, 1, 1, 1])
	run_turn(state, r)
	check(int(state.players[1].get("gold", 0)) > 0, "a Flawless Procession puts Pyrite in an ally's purse too")
	check(state.enemies.all(func(f: Dictionary) -> bool: return int(f.statuses.get("poison", 0)) > 0 or int(f.hp) <= 0), "and poisons every enemy")

func _test_quintessence() -> void:
	var r: Dictionary = rngs(5)
	var state: Dictionary = DeepBattle.begin([player("a", [gem("QUINTESSENCE", 10, 0, 3, [], "q1")])], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [5, 5, 5, 5, 5])
	var fired: Array = at_socket(run_turn(state, r), 0)
	check(fired.size() == 1, "Quintessence fires on five of a kind")
	check(int(state.players[0].gem_buffs.get("q1", {}).get("carat", 0)) == 5, "and gains exactly five carats, however heavy it is")
	hand(state.players[0], [5, 5, 5, 5, 4])
	check(at_socket(run_turn(state, r), 0).is_empty(), "four of a kind is not enough")
	var flawless: Dictionary = DeepBattle.begin([player("a", [gem("STRIKE", 1, 4, 3, [], "s1"), gem("QUINTESSENCE", 1, 4, DeepContent.clarity_index("FLAWLESS"), [], "q2")])],
		["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(flawless.players[0], [2, 2, 2, 2, 2])
	run_turn(flawless, r)
	check(int(flawless.players[0].gem_buffs.get("s1", {}).get("carat", 0)) == 5, "a Flawless one gives the rest of the rail five carats too")

func _test_gemini() -> void:
	var r: Dictionary = rngs(6)
	var rail: Array = [gem("STRIKE", 1, 4, 3, [], "s0"), gem("GEMINI", 1, 4, 3, [], "gm"), gem("GUARD", 1, 4, 3, [], "g2")]
	var state: Dictionary = DeepBattle.begin([player("a", rail.duplicate(true))], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [3, 3, 5, 5, 1])
	var events: Array = run_turn(state, r)
	check(at_socket(events, 0).size() == 3, "two pairs: the gem before Gemini fires twice more")
	check(at_socket(events, 2).size() == 3, "and the gem after it twice before its own turn")
	state = DeepBattle.begin([player("a", rail.duplicate(true))], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [6, 6, 6, 6, 1])
	check(at_socket(run_turn(state, r), 0).size() == 3, "four of a kind counts as two pairs")
	state = DeepBattle.begin([player("a", rail.duplicate(true))], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [6, 6, 6, 2, 2])
	check(at_socket(run_turn(state, r), 0).size() == 3, "so does a full house")
	state = DeepBattle.begin([player("a", rail.duplicate(true))], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [6, 6, 4, 3, 1])
	check(at_socket(run_turn(state, r), 0).size() == 2, "one pair, one more go each")
	## Flawless: one more again.
	var bright: Array = rail.duplicate(true)
	bright[1].clarity = DeepContent.clarity_index("FLAWLESS")
	state = DeepBattle.begin([player("a", bright)], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [6, 6, 4, 3, 1])
	check(at_socket(run_turn(state, r), 0).size() == 3, "a Flawless Gemini fires its neighbours once more")
	## Never an opal.
	state = DeepBattle.begin([player("a", [gem("STRIKE", 1, 4, 3, [], "s0"), gem("SEAM_RED", 1, 4, 3, [], "sr"), gem("GEMINI", 1, 4, 3, [], "gm"), gem("GUARD", 1, 4, 3, [], "g3")])],
		["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [6, 6, 4, 3, 1])
	events = run_turn(state, r)
	check(at_socket(events, 1).size() <= 1, "an opal beside Gemini answers only to its Resonance")
	## A phantom die makes a pair like any other.
	state = DeepBattle.begin([player("a", [gem("REFRACT", 1, 4, 3, [], "rf"), gem("GEMINI", 1, 4, 3, [], "gm"), gem("STRIKE", 1, 4, 3, [], "s2")])],
		["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [6, 5, 4, 2, 1])
	events = run_turn(state, r)
	check(not at_socket(events, 1).is_empty(), "a phantom copying the highest die gives Gemini its pair")

func _test_certainty() -> void:
	var r: Dictionary = rngs(7)
	var state: Dictionary = DeepBattle.begin([player("a", [gem("CERTAINTY", 1, 0, 3, [], "c0"), gem("GUARD", 1, 0, 3, [], "g1"), gem("CRUSH", 1, 0, 3, [], "k2")])],
		["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [1, 2, 4, 5, 6])
	var events: Array = run_turn(state, r)
	check(at_socket(events, 1).size() == 1 and bool(at_socket(events, 1)[0].forced), "a Guard with no pair fires anyway after Certainty")
	check(at_socket(events, 2).size() == 1, "and so does a Crush with nothing matched")
	var forecast: Dictionary = DeepBattle.forecast(state, "a")
	hand(state.players[0], [1, 2, 4, 5, 6])
	forecast = DeepBattle.forecast(state, "a")
	check(bool(forecast.sockets[1].active), "the forecast shows them firing too")
	## Without it they stay dark.
	state = DeepBattle.begin([player("a", [gem("GUARD", 1, 0, 3, [], "g1")])], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [1, 2, 4, 5, 6])
	check(at_socket(run_turn(state, r), 0).is_empty(), "the same Guard alone stays dark")
	## Flawless: twice.
	state = DeepBattle.begin([player("a", [gem("CERTAINTY", 1, 0, DeepContent.clarity_index("FLAWLESS"), [], "c0"), gem("GUARD", 1, 0, 3, [], "g1")])],
		["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [1, 2, 4, 5, 6])
	check(at_socket(run_turn(state, r), 1).size() == 2, "a Flawless Certainty fires every gem after it twice")
	## Never the gems before it.
	state = DeepBattle.begin([player("a", [gem("GUARD", 1, 0, 3, [], "g0"), gem("CERTAINTY", 1, 0, 3, [], "c1")])], ["THE_REGENT"], {"depth": 3}, r.dice, r.creatures)
	hand(state.players[0], [1, 2, 4, 5, 6])
	check(at_socket(run_turn(state, r), 0).is_empty(), "a gem before Certainty is not touched")

func _test_trigger_swaps() -> void:
	check(str(DeepContent.skill("BASTION").trigger.kind) == "triple" and str(DeepContent.skill("LIFELINE").trigger.kind) == "full_house",
		"Bastion and Lifeline traded triggers")
	check(str(DeepContent.skill("MORTAR").trigger.kind) == "even" and str(DeepContent.skill("MIASMA").trigger.kind) == "always",
		"Mortar and Miasma traded triggers")
	var ints: Callable = func(ladder: Array) -> Array: return ladder.map(func(v: Variant) -> int: return int(v))
	check(ints.call(DeepContent.skill("BASTION").trigger.ladder) == [6, 5, 4, 3, 2] and ints.call(DeepContent.skill("LIFELINE").trigger.ladder) == [5, 4, 3, 2, 1],
		"each on the other's ladder")
