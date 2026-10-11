extends SceneTree
## The October 2026 gems: each one fired for real, against the rules it was approved with.
var checks: int = 0
var failures: Array = []

func _init() -> void:
	blue()
	green()
	violet()
	red()
	white()
	gold()
	opals()
	print("New gems: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func setup(foes: int = 3, character: String = "ARDOR", keep_birthstone: bool = false) -> Dictionary:
	var party: Array = []
	for p in range(2):
		var bowl: Array = []
		for i in range(5):
			bowl.append(DeepDice.make("D20", "p%d_d%d" % [p, i]))
		var unit: Dictionary = DeepBattle.make_player("p%d" % p, "Player", character, [], bowl)
		unit.passive = {}
		if not keep_birthstone:
			unit.birthstone = {}
		unit.hp = 1000
		unit.max_hp = 1000
		unit.ore = 100
		unit.haul = []
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(23, ["dice", "creatures"])
	var keys: Array = []
	keys.resize(foes)
	keys.fill("CAVE_TICK")
	var state: Dictionary = DeepBattle.begin(party, keys, {"depth": 1}, rng.dice, rng.creatures)
	for foe in state.enemies:
		foe.hp = 1000
		foe.max_hp = 1000
		foe.block = 0
		foe.statuses = {}
	var player: Dictionary = state.players[0]
	player.target = str(state.enemies[0].id)
	player.firing_target = player.target
	player.resonance = 0
	player.statuses = {}
	player.block = 0
	return {"state": state, "player": player, "foe": state.enemies[0], "rng": rng}

func rolls(f: Dictionary, values: Array, held: bool = false) -> void:
	while f.player.hand.size() > values.size():
		f.player.hand.pop_back()
	for i in range(f.player.hand.size()):
		var roll: Dictionary = f.player.hand[i]
		roll.value = int(values[i])
		roll.face = int(values[i]) - 1
		roll.kind = "plain"
		roll.top = 20
		roll.held = held
		roll.rerolls = 0 if held else 1
		roll.phantom = false

func equip(f: Dictionary, key: String, at: int = 0, flawless: bool = false, carat: int = 1, cut: int = 4) -> void:
	while f.player.rail.size() <= at:
		f.player.rail.append(null)
		f.player.sockets.append("ANY")
	f.player.sockets[at] = "ANY"
	f.player.rail[at] = DeepStone.make(key, carat, cut, 5 if flawless else 3, [], {}, "gem%d" % at)

func fire(f: Dictionary, key: String, values: Array = [], flawless: bool = false, carat: int = 1, held: bool = false) -> Dictionary:
	equip(f, key, 0, flawless, carat)
	if not values.is_empty():
		rolls(f, values, held)
	return DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)

func fired(event: Dictionary) -> bool:
	return str(event.get("kind", "")) == "gem_fire"

# --- Blue -----------------------------------------------------------------------------------------

func blue() -> void:
	var f: Dictionary = setup()
	check(fired(fire(f, "CALTROP", [1, 3, 5, 2, 4])) and int(f.player.statuses.get("spikes", 0)) == 3, "Caltrop: a Spikes for every odd die")
	DeepBattle._reset_defenses(f.player)
	check(int(f.player.statuses.get("spikes", 0)) == 3, "and they last past the Block reset")
	f = setup()
	fire(f, "CALTROP", [1, 3, 5, 2, 4], true)
	check(int(f.player.statuses.spikes) == 4 and int(f.player.block) == 4, "Flawless Caltrop gains Block equal to all its Spikes, the new ones included")

	f = setup()
	check(fired(fire(f, "BEZEL", [5, 5, 3, 3, 1])) and int(f.player.block) == 8, "Bezel: Block equal to both pair values")
	check(int(f.player.statuses.get("ward", 0)) == 1 and int(f.state.players[1].statuses.get("ward", 0)) == 1, "and every ally gains a Ward")

	f = setup()
	fire(f, "HARDENING", [1, 2, 3, 4, 5])
	var first: int = int(f.player.block)
	fire(f, "HARDENING", [1, 2, 3, 4, 5])
	check(first == 4 and int(f.player.block) == 4 + 5, "Hardening: 4 Block, then a point more for every fire")
	check(int(f.player.run_counts.get("gem0", 0)) == 2, "its fires are counted on the unit for the run")

	f = setup()
	f.player.block = 40
	check(fired(fire(f, "BASH", [20, 1, 2, 3, 4])) and int(f.foe.hp) == 980 and int(f.player.block) == 40, "Bash: half your Block as damage, the Block kept")

	f = setup()
	f.player.block = 40
	check(fired(fire(f, "FORTIFY", [5, 5, 5, 2, 2])) and int(f.player.block) == 60, "Fortify: half your Block again")

	f = setup()
	equip(f, "CHAINMAIL", 0)
	equip(f, "STRIKE", 1)
	rolls(f, [5, 5, 3, 2, 1])
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	check(int(f.player.block) == 0, "Chainmail does not pay for itself")
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.player.block) == 2, "Chainmail: the gem after it gives 2 Block")
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(f.player.get("after_fire", []).is_empty(), "and it ends with the turn")

	f = setup()
	equip(f, "REBOUND", 0)
	equip(f, "GUARD", 1)
	rolls(f, [1, 2, 3, 4, 5])
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	DeepBattle._apply(f.state, f.player, {"kind": "block", "target": "self", "amount": 5}, f.rng.dice)
	check(int(f.foe.hp) == 997, "Rebound: every Block gained this turn hits the target for 3")
	DeepBattle._apply(f.state, f.state.players[1], {"kind": "block", "target": "allies", "amount": 5}, f.rng.dice)
	check(int(f.foe.hp) == 994, "Block an ally gives counts too")

# --- Green ----------------------------------------------------------------------------------------

func green() -> void:
	var f: Dictionary = setup()
	check(fired(fire(f, "LICHEN", [1, 2, 3, 4, 5], false, 1, true)) and int(f.player.statuses.get("regeneration", 0)) == 2, "Lichen: 2 Regeneration for kept dice")
	f = setup()
	fire(f, "LICHEN", [1, 2, 3, 4, 5], true, 1, true)
	check(int(f.player.statuses.get("regeneration", 0)) == 3 + 7, "Flawless Lichen: a point more for every die kept")

	f = setup()
	f.player.hp = 990
	check(fired(fire(f, "WELLSPRING", [20, 20, 20, 20, 20])) and int(f.player.hp) == 1000 and int(f.player.block) == 40, "Wellspring: half the total healed, what spills past full becomes Block")

	f = setup()
	f.player.hp = 500
	f.player.dealt = 100
	check(fired(fire(f, "THIRST", [1, 2, 3, 4, 5])) and int(f.player.hp) == 530, "Thirst: 30% of the damage dealt this turn, at Perfect")
	f = setup()
	f.player.dealt = 100
	fire(f, "THIRST", [1, 2, 3, 4, 5], true)
	check(int(f.foe.hp) == 1000 - 45, "Flawless Thirst: healing past full health is dealt to the target")

	f = setup()
	check(fired(fire(f, "HEARTWOOD", [5, 5, 5, 5, 1])) and int(f.player.max_hp) == 1003 and int(f.player.hp) == 1003, "Heartwood: 3 max HP, and healed as much")
	check(not fired(fire(f, "HEARTWOOD", [5, 5, 5, 1, 2])), "and only on four of a kind")
	f = setup()
	fire(f, "HEARTWOOD", [5, 5, 5, 5, 1], true)
	check(int(f.foe.hp) == 1000 - 150, "Flawless Heartwood: a blow worth a tenth of the max health it had")

# --- Violet ---------------------------------------------------------------------------------------

func violet() -> void:
	var f: Dictionary = setup()
	check(fired(fire(f, "PETRIFY", [7, 7, 7, 7, 1])) and int(f.foe.hp) == 972 and int(f.foe.statuses.get("stun", 0)) == 1, "Petrify: the four dice as damage, and a stun")

	f = setup()
	f.state.enemies[1].statuses.poison = 5
	f.state.enemies[2].statuses.poison = 6
	check(fired(fire(f, "CONFLUENCE", [1, 2, 3, 4, 5])), "Confluence fires on low dice")
	check(int(f.state.enemies[1].statuses.poison) == 0 and int(f.state.enemies[2].statuses.poison) == 0, "every other creature's Poison is gathered")
	check(int(f.foe.hp) == 989 and int(f.foe.statuses.poison) == 10, "onto the target, which ticks once")

	f = setup()
	f.foe.statuses.poison = 20
	check(fired(fire(f, "FERMENT", [1, 3, 5, 7, 9])) and int(f.foe.statuses.poison) == 26, "Ferment: 30% more Poison on the target")

	f = setup()
	check(fired(fire(f, "HEMLOCK", [20, 2, 4, 6, 8])), "Hemlock fires on even dice")
	check(int(f.player.statuses.get("poison", 0)) == 20, "you take Poison equal to your highest die, unswollen")
	check(f.state.enemies.all(func(e: Dictionary) -> bool: return int(e.statuses.get("poison", 0)) == 40), "every enemy takes twice your Poison")

	f = setup()
	fire(f, "ARSENIC", [5, 5, 3, 3, 1])
	check(int(f.player.statuses.get("envenom", 0)) == 1, "Arsenic: one stack for the fight")
	DeepBattle._apply(f.state, f.player, {"kind": "damage", "target": "enemy", "amount": 10, "repeat": 3}, f.rng.dice)
	check(int(f.foe.statuses.get("poison", 0)) == 3, "every hit past Block poisons")
	f.foe.block = 100
	DeepBattle._apply(f.state, f.player, {"kind": "damage", "target": "enemy", "amount": 10}, f.rng.dice)
	check(int(f.foe.statuses.get("poison", 0)) == 3, "a hit the Block took does not")

	f = setup()
	equip(f, "CONTAGION", 0)
	equip(f, "GUARD", 1)
	rolls(f, [1, 5, 5, 6, 7])
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.foe.statuses.get("poison", 0)) == 1, "Contagion: the gem after it poisons the target")

# --- Red ------------------------------------------------------------------------------------------

func red() -> void:
	var f: Dictionary = setup()
	check(fired(fire(f, "CREST", [20, 20, 3, 4, 5])) and int(f.foe.hp) == 1000 - 160, "Crest: four times the crowns' total at Perfect")
	f = setup()
	fire(f, "CREST", [20, 20, 3, 4, 5], true)
	check(int(f.player.gold) >= 40, "Flawless Crest: every crown pays its value in Pyrite")

	f = setup()
	f.player.hp = 600
	check(fired(fire(f, "GRUDGE", [1, 2, 3, 4, 5])) and int(f.foe.hp) == 1000 - 320, "Grudge: 80% of the missing health at Perfect")

	f = setup()
	fire(f, "HONE", [1, 2, 3, 4, 5])
	fire(f, "HONE", [1, 2, 3, 4, 5])
	check(int(f.foe.hp) == 1000 - 4 - 5, "Hone: 4, then a point more every fire")

	f = setup()
	var flurry: Dictionary = fire(f, "FLURRY", [5, 5, 1, 2, 3])
	check(fired(flurry) and int(f.foe.hp) == 990 and flurry.effects.size() == 5, "Flurry: five hits of 2 for a pair of 5s")

	f = setup()
	check(fired(fire(f, "TEMPER", [12, 1, 2, 3, 4])) and int(f.player.statuses.get("strength", 0)) == 1, "Temper: Strength for a high die")
	DeepBattle._apply(f.state, f.player, {"kind": "damage", "target": "enemy", "amount": 10, "repeat": 2}, f.rng.dice)
	check(int(f.foe.hp) == 1000 - 22, "and every blow deals a point more")
	check(not fired(fire(f, "TEMPER", [11, 1, 2, 3, 4])), "a Perfect Temper needs a 12")

	f = setup()
	check(fired(fire(f, "BLOODLETTING", [2, 4, 6, 8, 10])) and int(f.player.hp) == 997 and is_equal_approx(float(f.player.amplify), 1.5), "Bloodletting: 3 health for 50% on the next gem")
	f.player.hp = 3
	var dark: Dictionary = fire(f, "BLOODLETTING", [2, 4, 6, 8, 10])
	check(not fired(dark) and str(dark.get("reason", "")) == "Not enough health." and int(f.player.hp) == 3, "and never the last of it")

	f = setup()
	f.player.fight_resonance = 40
	check(fired(fire(f, "CRESCENDO", [1, 2, 3, 4, 5])) and int(f.foe.hp) == 980, "Crescendo: half of the fight's Resonance at Perfect")
	f = setup()
	var rail: Dictionary = {"kind": "rail_end", "unit": f.player.id}
	f.player.resonance = 7
	DeepBattle._perform(f.state, rail, f.rng.dice, f.rng.creatures)
	check(int(f.player.fight_resonance) == 7, "every rail's Resonance goes on the fight's tally")

# --- White ----------------------------------------------------------------------------------------

func white() -> void:
	var f: Dictionary = setup()
	fire(f, "SEDIMENT", [9, 4, 12, 15, 18])
	check(f.player.hand.size() == 6 and bool(f.player.hand[5].phantom) and int(f.player.hand[5].value) == 4, "Sediment: a phantom of the lowest die")
	f = setup()
	fire(f, "SEDIMENT", [9, 4, 12, 15, 18], true)
	check(int(f.player.hand[5].value) == 1, "Flawless Sediment's phantom shows a 1")

	f = setup()
	fire(f, "OVERTURN", [1, 14, 12, 15, 18])
	check(int(f.player.hand[0].value) == 20, "Overturn: a 1 on a d20 is turned to its 20")

	f = setup()
	f.player.resonance = 10
	check(fired(fire(f, "LODESTONE", [1, 2, 3, 4, 9])) and int(f.player.statuses.get("charged", 0)) == 3, "Lodestone: 30% of the Resonance stored at Perfect")
	f = setup()
	f.player.resonance = 10
	fire(f, "LODESTONE", [1, 2, 3, 4, 9], false, 24)
	check(int(f.player.statuses.get("charged", 0)) <= 11, "never more than the Resonance there is: %d" % int(f.player.statuses.get("charged", 0)))

	f = setup(3, "ARDOR", true)
	f.player.resonance = 10
	fire(f, "BIRTHRIGHT", [1, 2, 3, 4, 5])
	var queued: Array = f.state.queue.filter(func(q: Dictionary) -> bool: return str(q.get("kind", "")) == "birthstone")
	check(queued.size() == 1 and int(queued[0].get("share", 0)) == 100 and bool(queued[0].get("replay", false)), "Birthright: the Birthstone queued now, at its share, as a replay")

	f = setup()
	check(fired(fire(f, "TUMBLE", [1, 2, 3, 4, 5])) and f.player.hand.size() == 6 and bool(f.player.hand[5].phantom) and str(f.player.hand[5].shape) == "D6", "Tumble: a phantom d6 on a poor throw")
	check(not fired(fire(f, "TUMBLE", [20, 20, 20, 20, 20])), "and not on a good one")

	f = setup()
	f.player.fired_colors = [["RED"], ["BLUE"], ["RED"]]
	fire(f, "SPECTRUM", [1, 2, 3, 4, 5])
	check(int(f.foe.hp) == 997 and int(f.player.block) == 3, "Spectrum: one gift a colour that fired")
	f = setup()
	f.player.fired_colors = [["RED"], ["BLUE"], ["RED"]]
	fire(f, "SPECTRUM", [1, 2, 3, 4, 5], true)
	check(int(f.foe.hp) == 1000 - 9, "Flawless Spectrum counts every gem: two Reds, twice the damage, swollen by Flawless")

# --- Gold -----------------------------------------------------------------------------------------

func gold() -> void:
	var f: Dictionary = setup()
	check(not fired(fire(f, "PLACER", [1, 2, 3, 4, 5])), "Placer stays dark until something has died")
	f.state.turn_kills = 2
	fire(f, "PLACER", [1, 2, 3, 4, 5], false, 24)
	check(int(f.player.get("placer_drops", 0)) == 8, "a heavy Placer finds stones for every kill: %d" % int(f.player.get("placer_drops", 0)))
	f = setup()
	f.foe.hp = 5
	DeepBattle._apply(f.state, f.player, {"kind": "damage", "target": "enemy", "amount": 50}, f.rng.dice)
	check(int(f.state.get("turn_kills", 0)) == 1, "a creature falling is counted for the turn")
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(int(f.state.get("turn_kills", 0)) == 0, "and the count starts over each turn")

	f = setup()
	check(fired(fire(f, "DIVIDEND", [1, 2, 3, 4, 5], false, 1, true)) and int(f.player.gold) == 10, "Dividend: a Pyrite for every 10 carried, up to 10")

	f = setup()
	fire(f, "GILDING", [20, 1, 2, 3, 4])
	check(str(f.player.dice[0].faces[19].get("kind", "")) == "golden", "Gilding: the face the highest die shows is Golden")
	fire(f, "GILDING", [20, 1, 2, 3, 4])
	check(str(f.player.dice[1].faces[0].get("kind", "")) != "golden", "a face already Golden passes to the next highest die")

	f = setup()
	var rattle: Dictionary = fire(f, "RATTLE", [1, 12, 13, 14, 15])
	check(fired(rattle) and bool(f.player.hand[0].get("rethrown", false)) and int(f.player.hand[0].rerolls) == 1, "Rattle: the lowest die is thrown again, no reroll counted")

# --- Opals ----------------------------------------------------------------------------------------

func opals() -> void:
	var f: Dictionary = setup()
	f.player.resonance = 6
	check(fired(fire(f, "PINFIRE", [1, 2, 3, 4, 5])) and int(f.player.resonance) == 6 + 1 + 6, "Pinfire: as much Resonance again as the rail had")
	f = setup()
	f.player.resonance = 6
	equip(f, "PINFIRE", 0, true)
	equip(f, "STRIKE", 1)
	rolls(f, [1, 2, 3, 4, 5])
	DeepBattle.resolve_gem(f.state, f.player, 0, {}, f.rng.dice)
	var before: int = int(f.player.resonance)
	DeepBattle.resolve_gem(f.state, f.player, 1, {}, f.rng.dice)
	check(int(f.player.resonance) - before == 2, "Flawless Pinfire: every gem after it rings twice as loud")

	f = setup()
	f.player.resonance = 6
	check(fired(fire(f, "CONTRA_LUZ", [1, 2, 3, 4, 5])) and f.player.hand.size() == 6, "Contra Luz: a phantom d6")
	var kept: int = int(f.player.hand[5].value)
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	var carried: Array = f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false)))
	check(carried.size() == 1 and int(carried[0].value) == kept, "its phantoms stay into the next turn, showing what they showed")
	f.player.hand = DeepDice.reroll(f.player.hand, f.player.dice, ["p0_d0", "p0_d1"], f.rng.dice)
	check(f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false))).size() == 1, "a reroll leaves the kept phantom in the hand")
	DeepBattle._begin_turn(f.state, f.rng.dice, f.rng.creatures)
	check(f.player.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false))).is_empty(), "and go when it did not fire again")

	f = setup()
	f.player.dice[2] = DeepDice.make("D6", "small")
	for _time in range(3):
		f.player.resonance = 6
		fire(f, "HYDROPHANE", [1, 2, 3, 4, 5])
	check(str(f.player.dice[2].shape) == "D8" and int(f.player.dice[2].get("drops", 0)) == 0, "Hydrophane: three drops and the smallest die grows a size")
	f = setup()
	f.player.dice[2] = DeepDice.make("D6", "small")
	for _time in range(3):
		f.player.resonance = 6
		fire(f, "HYDROPHANE", [1, 2, 3, 4, 5], true)
	check(str(f.player.dice[2].shape) == "D4", "Flawless Hydrophane shrinks it instead")
