extends SceneTree
## The balance runs' bot (tools/balance/bot.gd): that it plays a run to an end by the rules,
## that one job always plays the same run, that a delver's three stones choose from the same
## vault, that what it writes down adds up, and that playing a hand out to weigh it never
## touches the fight it is weighing.

const Bot: GDScript = preload("res://tools/balance/bot.gd")

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_plays_to_an_end()
	_test_same_job_same_run()
	_test_kits()
	_test_playout()
	print("Delve: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func job(character: String, seed_value: int, more: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"id": "%s.%d" % [character, seed_value], "character": character, "birthstone": "", "mine": "QUARRY", "seed": seed_value}
	out.merge(more, true)
	return out

func played(the_job: Dictionary) -> Dictionary:
	var bot: RefCounted = Bot.new()
	var row: Dictionary = bot.play(the_job)
	row.erase("ms")
	return row

func _test_plays_to_an_end() -> void:
	## Two delvers down the Quarry: each run ends, one way or the other, and says how.
	for character in ["ARDOR", "FLORIN"]:
		var row: Dictionary = played(job(character, 3))
		check(str(row.outcome) in ["conquered", "fallen"], "%s's run ends (%s %s)" % [character, str(row.outcome), str(row.get("stuck", ""))])
		check(float(row.progress) >= 0.0 and float(row.progress) <= 1.0, "progress is a share")
		check((str(row.outcome) == "conquered") == (float(row.progress) >= 1.0), "only a run that beat the boss has all of it")
		check(not row.fights.is_empty(), "it fought")
		check(not row.has("refusals") or row.refusals.size() <= 6, "the rules refused little of what it tried: %s" % str(row.get("refusals", {})))
		for fight in row.fights:
			## Every point of health a fight took is put down to a creature, its poison or the bot's own doing.
			var told: int = int(fight.dot) + int(fight.self)
			for key in fight.by:
				told += int(fight.by[key][2])
			check(told == int(fight.taken), "a fight's health lost adds up (%d told of %d, depth %d)" % [told, int(fight.taken), int(fight.d)])
			check(fight.by.size() >= 1 and int(fight.turns) >= 1, "a fight names who stood in it and how long")
		if str(row.outcome) == "fallen":
			check(row.has("cause") and not bool(row.fights.back().won), "a fallen run says what it fell to")
		## A tier that costs its owner (Florin's Bust) is put down to the stone, not to a creature.
		var own: int = 0
		for fight in row.fights:
			own += int(fight.self)
		check(int(row.birth.hurt) <= own, "what the Birthstone cost is among the bot's own doing")
		check(int(row.birth.hurt) == 0 or int(row.birth.tiers.get("Bust", 0)) > 0, "only a Bust costs the stone's owner health (%s, %d)" % [str(row.birth.tiers), int(row.birth.hurt)])
		if character == "FLORIN":
			check(int(row.birth.tiers.get("Bust", 0)) == 0 or int(row.birth.hurt) > 0, "and Florin's Busts did")
		## The gems' tally: nothing fired more often than the turns it sat.
		for skill in row.gems:
			check(int(row.gems[skill].turns) >= 1, "%s sat on the rail" % str(skill))

func _test_same_job_same_run() -> void:
	var one: Dictionary = played(job("VESPER", 11))
	var two: Dictionary = played(job("VESPER", 11))
	check(JSON.stringify(one) == JSON.stringify(two), "one job plays the same run twice")
	var other: Dictionary = played(job("VESPER", 12))
	check(JSON.stringify(one) != JSON.stringify(other), "another seed plays another")

func _test_kits() -> void:
	## A delver's three stones choose a rail from one vault, with the same stone planted.
	var vaults: Array = []
	var plants: Array = []
	for stone in DeepContent.birthstone_keys("ARDOR"):
		var bot: RefCounted = Bot.new()
		var config: Dictionary = bot.config_for(job("ARDOR", 5, {"birthstone": str(stone), "mine": "WARRENS"}))
		var rail: Array = config.players[0].rail
		var set_skills: Array = rail.filter(func(s: Variant) -> bool: return s is Dictionary).map(func(s: Dictionary) -> String: return str(s.skill))
		var vault: Array = set_skills + bot.kit_notes.left
		vault.sort()
		vaults.append(vault)
		plants.append(str(bot.kit_notes.plant))
		check(set_skills.has(str(bot.kit_notes.plant)), "the planted stone is on the rail")
		check(set_skills.size() <= int(config.players[0].sockets), "no more stones than sockets open")
		var sockets: Array = DeepContent.character("ARDOR").sockets
		for index in range(rail.size()):
			if rail[index] is Dictionary:
				check(DeepStone.fits(rail[index], str(sockets[index])), "%s sits in a socket that shows it" % str(rail[index].skill))
				check(int(rail[index].carat) == int(DeepContent.mine("WARRENS").carat.soft), "at the mine's carats")
		var once: Dictionary = {}
		for skill in set_skills:
			check(not once.has(skill), "one stone of each skill")
			once[skill] = true
	check(vaults[0] == vaults[1] and vaults[1] == vaults[2], "three stones, one vault")
	check(plants[0] == plants[1] and plants[1] == plants[2], "and the same stone planted")
	## A kit written out is the kit, and a plant asked for is planted.
	var bot: RefCounted = Bot.new()
	var written: Dictionary = bot.config_for(job("ARDOR", 5, {"kit": [["STRIKE", 9, 2, 3], null, ["MEND", 4, 1, 3]]}))
	var rail: Array = written.players[0].rail
	check(str(rail[0].skill) == "STRIKE" and int(rail[0].carat) == 9 and rail[1] == null and str(rail[2].skill) == "MEND", "a written kit is set as written")
	bot = Bot.new()
	var planted: Dictionary = bot.config_for(job("ARDOR", 5, {"plant": "TEMPO"}))
	check(planted.players[0].rail.any(func(s: Variant) -> bool: return s is Dictionary and str(s.skill) == "TEMPO"), "a plant asked for is planted")

func _test_playout() -> void:
	## Weighing a hand plays it for real on a copy: the fight itself is not touched, and a
	## blow into a mirror is seen for what it is.
	var bot: RefCounted = Bot.new()
	bot.rng.seed = 7
	var stone: Dictionary = DeepStone.make("STRIKE", 24, 4, 3, [], {}, "s0")
	stone.appraised = true
	var dice: Array = []
	var refs: Array = DeepContent.character("ARDOR").dice
	for index in range(refs.size()):
		dice.append(DeepForge.die_from(refs[index], "d%d" % index))
	var streams: Dictionary = DeepRng.streams(9, ["dice", "creatures"])
	var fighter: Dictionary = DeepBattle.make_player("a", "Test", "ARDOR", [stone, null, null, null, null, null], dice)
	var b: Dictionary = DeepBattle.begin([fighter], ["ECHO_SPRITE"], {"depth": 20, "scale": {"hp": 30.0, "damage": 1.0}}, streams.dice, streams.creatures)
	var foe: Dictionary = b.enemies[0]
	var before: String = JSON.stringify(b)
	var after: Dictionary = bot.play_rail(b, b.players[0].hand, str(foe.id), 0)
	check(JSON.stringify(b) == before, "playing a hand out leaves the fight as it was")
	check(int(after.enemies[0].hp) < int(foe.hp), "the copy took the blow")
	var plain: float = bot.turn_worth(b, after)
	check(plain > 0.0, "a blow that lands is worth something")
	## The same blow into a mirror comes back at whoever threw it.
	foe.mirror = 1
	b.players[0].hp = 20
	after = bot.play_rail(b, b.players[0].hand, str(foe.id), 0)
	check(int(after.players[0].hp) <= 0, "a 24-carat Strike into a mirror is the end of the thrower")
	check(bot.turn_worth(b, after) < -bot.GRAVE * 0.5, "and is weighed as that")
