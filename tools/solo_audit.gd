extends SceneTree
## Reproducible command-driven solo playthroughs. Uses in-memory profiles only.
## Godot --headless --path . --script tools/solo_audit.gd -- build/solo-audit.json
## Optional second argument: limit the number of runs for a quick smoke check.

var report: Dictionary = {"runs": [], "failures": [], "rooms": {}, "oddities": {}, "actions": {}, "refusals": {}, "creatures": {}}
var active: Dictionary = {}
var book: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func setup(seed_value: int, mine: String, character: String, mode: String) -> Dictionary:
	var profile: Dictionary = DeepProfile.new_profile("Audit")
	DeepProfile.unlock_character(profile, character)
	var outfit: Dictionary = DeepProfile.loadout(profile, character)
	var open: int = 3
	if mode in ["experienced", "traversal"]:
		var defs: Dictionary = {"RED": "STRIKE", "BLUE": "GUARD", "GREEN": "MEND", "VIOLET": "VENOM", "GOLD": "TITHE", "WHITE": "CASCADE"}
		outfit.rail = []
		var carat: int = int(DeepContent.mine(mine).carat.soft)
		if mode == "traversal":
			carat = 150
		## One stone of each skill, the rule a player's rail is held to (DeepDescent.rail_duplicate).
		## A second socket of one color takes another skill of that color the mine can hold.
		var used: Array = []
		var spares: Array = ["CLEAVE", "VENOM", "CASCADE", "STRIKE", "GUARD", "MEND", "TITHE"]
		for socket in DeepContent.character(character).sockets:
			var skill: String = str(defs.get(str(socket), ""))
			if skill.is_empty() or used.has(skill):
				var fits: Array = []
				if str(socket) == DeepContent.SOCKET_ANY:
					fits = spares.filter(func(k: String) -> bool: return not used.has(k))
				else:
					fits = DeepForge.skill_pool(DeepContent.mine(mine)).filter(func(k: String) -> bool: return not used.has(k) and str(DeepContent.skill(k).get("color", "")) == str(socket))
				if not fits.is_empty():
					skill = str(fits[0])
			used.append(skill)
			var stone: Dictionary = DeepStone.make(skill, carat, 4 if mode == "traversal" else 3, 3, [], {}, "audit%d" % outfit.rail.size())
			stone.appraised = true
			outfit.rail.append(stone)
		open = outfit.rail.size()
	return {"seed": seed_value, "run_id": "audit_%s_%s_%d" % [mode, mine, seed_value], "mine": mine,
		"players": [{"id": "a", "name": "Audit", "character": character, "rail": outfit.rail, "dice": outfit.dice, "sockets": open}]}

func run() -> void:
	var jobs: Array = []
	for mode in ["novice", "starter_rerolls"]:
		for seed_value in range(1200, 1224):
			jobs.append({"mode": mode, "config": setup(seed_value, "QUARRY", "ARDOR", mode)})
	for mine in DeepContent.mines_in_order():
		for character in DeepContent.section("characters"):
			for seed_value in [2301, 2302]:
				jobs.append({"mode": "experienced", "config": setup(seed_value, str(mine), str(character), "experienced")})
		for seed_value in [3401, 3402]:
			jobs.append({"mode": "traversal", "config": setup(seed_value, str(mine), "ARDOR", "traversal")})
	for day in range(1, 17):
		jobs.append({"mode": "daily", "config": DeepEconomy.daily_config("2026-10-%02d" % day, [{"id": "a", "name": "Audit"}], "audit_daily_%d" % day)})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var limit: int = mini(jobs.size(), int(args[1])) if args.size() > 1 else jobs.size()
	var started: int = Time.get_ticks_msec()
	for index in range(limit):
		var job: Dictionary = jobs[index]
		active = {"mode": job.mode, "seed": int(job.config.seed), "mine": str(job.config.mine), "character": str(job.config.players[0].character), "actions": 0,
			"lift_unaffordable": [], "fights": 0, "turns": 0, "commands": 0, "refusals": 0, "initial_stones": job.config.players[0].rail.size()}
		book = {}
		var state: Dictionary = DeepDescent.new_run(job.config)
		while str(state.phase) != "over" and int(active.actions) < 12000:
			active.actions += 1
			var seq: int = int(state.seq)
			advance(state)
			if int(state.seq) == seq:
				fail("No progress at %s/%s depth %d" % [state.phase, str(state.chamber.get("kind", "")), state.depth])
				break
		active.merge({"outcome": state.outcome, "phase": state.phase, "depth": state.depth, "final_mine": state.mine, "hp": state.players[0].hp,
			"ore": state.players[0].ore, "found": state.records.stones_found, "wardens": state.records.wardens.duplicate(),
			"boss": state.records.boss, "home": DeepDescent.coming_home(state, state.players[0]).size()})
		if str(state.phase) != "over":
			fail("Run did not reach an ending")
		var result: Dictionary = DeepDescent.results(state)
		var profile: Dictionary = DeepProfile.new_profile("Audit result")
		DeepProfile.apply_result(profile, result, "a")
		if int(profile.gold) < 0:
			fail("Negative gold after result")
		report.runs.append(active.duplicate(true))
		print("Solo %d/%d %s %s %s seed=%d => %s depth=%d fights=%d turns=%d home=%d" % [index + 1, limit, active.mode, active.mine, active.character, active.seed, active.outcome, active.depth, active.fights, active.turns, active.home])
		report.elapsed_ms = Time.get_ticks_msec() - started
	var output: String = args[0] if not args.is_empty() else "res://build/solo-audit.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		fail("Cannot write report: " + output)
	print("Solo audit: %d runs, %d failures, %.2fs" % [report.runs.size(), report.failures.size(), float(Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if report.failures.is_empty() else 1)

func fail(message: String) -> void:
	var detail: String = "%s / %s / %s / %d: %s" % [active.mode, active.mine, active.character, active.seed, message]
	report.failures.append(detail)
	printerr("FAIL: " + detail)

func bump(collection: Dictionary, key: String) -> void:
	collection[key] = int(collection.get(key, 0)) + 1

func act(state: Dictionary, kind: String, fields: Dictionary = {}) -> bool:
	var command: Dictionary = fields.duplicate(true)
	command.kind = kind
	var result: Dictionary = DeepDescent.command(state, "a", command)
	active.commands += 1
	if bool(result.ok):
		bump(report.actions, kind)
	else:
		active.refusals += 1
		bump(report.refusals, kind + ": " + str(result.error))
	return bool(result.ok)

func raw_stones(unit: Dictionary) -> Array:
	return unit.haul.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and not DeepStone.is_geode(s))

func advance(state: Dictionary) -> void:
	var unit: Dictionary = state.players[0]
	match str(state.phase):
		"grubstake":
			for offer in unit.temps:
				if int(offer.chosen) < 0:
					act(state, "temporary", {"index": offer.index, "pick": 0})
					return
			for offer in unit.get("dice_offers", []):
				if not bool(offer.get("kept", false)) and int(offer.get("chosen", -1)) < 0:
					act(state, "dice_offer", {"index": offer.index, "pick": 1 if str(active.mode) != "traversal" else -1})
					return
			var offers: Array = state.grubstake.offers.a
			var order: Array = [1, 0, 2] if str(active.mode) == "novice" else [0, 1, 2]
			for index in order:
				if index < offers.size() and act(state, "stake", {"offer": offers[index].id, "payload": {"pick": 0}}):
					return
		"tunnels":
			if try_socket(state):
				return
			var offers: Array = state.offers.duplicate()
			var weights: Dictionary = {"landing": 100, "motherlode": 80, "vein": 60, "merchant": 35, "oddity": 45, "smithy": 40, "carver": 40, "vat": 40, "fight": 20, "elite": 5}
			if str(active.mode) == "traversal":
				weights = {"landing": 100, "fight": 90, "elite": 85, "vein": 60}
			offers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(weights.get(str(a.kind), 30)) > int(weights.get(str(b.kind), 30)))
			var offer: Dictionary = offers[0]
			bump(report.rooms, str(offer.kind))
			act(state, "vote_tunnel", {"offer": offer.id})
		"chamber":
			if DeepDescent.in_battle(state):
				fight(state)
			elif str(state.chamber.kind) in DeepDescent.ROCK_ROOMS:
				var minimum: int = int(float(unit.max_hp) * (0.65 if str(active.mode) == "novice" else 0.45))
				var cost: int = DeepDescent.swing_cost(state, unit)
				if int(unit.hp) - cost >= minimum:
					var spots: Array = state.chamber.vein.spots.filter(func(s: Dictionary) -> bool: return str(s.taken).is_empty() and str(s.get("owner", "a")) == "a")
					spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("struck", 0)) > int(b.get("struck", 0)) if int(a.get("struck", 0)) != int(b.get("struck", 0)) else int(a.index) < int(b.index))
					if not spots.is_empty() and act(state, "strike", {"spot": spots[0].index}):
						return
				act(state, "stop_mining")
			elif str(state.chamber.kind) == "merchant":
				var raw: Array = raw_stones(unit)
				if not raw.is_empty() and int(unit.ore) >= DeepDescent.appraise_cost(state, "a") + DeepDescent.lift_cost(state):
					act(state, "appraise", {"stone_id": raw[0].id})
				else:
					act(state, "leave")
			elif str(state.chamber.kind) == "altar":
				act(state, "altar_leave")
			else:
				oddity(state)
		"landing":
			var cleared: bool = bool(state.landing.get("cleared", false))
			var can_lift: bool = not cleared or DeepDescent.in_boss_hall(state)
			var wish_exit: bool = (str(active.mode) in ["novice", "starter_rerolls"] and (int(unit.hp) < int(unit.max_hp) * 0.65 or unit.haul.size() >= 2 or int(state.depth) >= 8)) or DeepDescent.in_boss_hall(state) or (str(state.mine) == "RIFT" and int(state.depth) >= 12)
			if can_lift and wish_exit and str(unit.respite).is_empty() or DeepDescent.in_boss_hall(state):
				if int(unit.ore) >= DeepDescent.lift_cost(state) and act(state, "choose", {"choice": "lift"}):
					return
				var key: String = "lift_%d_%s" % [int(state.depth), str(state.mine)]
				if not book.has(key):
					book[key] = true
					active.lift_unaffordable.append({"depth": state.depth, "ore": unit.ore, "cost": DeepDescent.lift_cost(state), "hp": unit.hp})
			if not cleared and str(unit.respite).is_empty():
				if not DeepDescent.has_mod(state, "NO_BENCH") and (int(unit.hp) < int(unit.max_hp) - 5 or raw_stones(unit).is_empty()):
					if act(state, "respite", {"choice": "rest"}):
						return
				var raw: Array = raw_stones(unit)
				if not raw.is_empty() and act(state, "respite", {"choice": "appraise", "stone_id": raw[0].id}):
					return
				if act(state, "respite", {"choice": "wish", "ore": 10}):
					return
				for stone in DeepStone.rail_stones(unit):
					if DeepDescent.can_wish(stone) and act(state, "respite", {"choice": "wish", "stone_id": stone.id}):
						return
			if not act(state, "choose", {"choice": "descend"}):
				fail("Landing offers no legal continuation")
				act(state, "abandon")
		"hoard":
			var offers: Array = state.hoard.a.offers
			act(state, "pick_hoard", {"stone_id": offers[2 if DeepDescent.run_is_boss(state, int(state.depth)) else 1].id})
		"salvage":
			act(state, "ready")

func try_socket(state: Dictionary) -> bool:
	var unit: Dictionary = state.players[0]
	for stone in unit.haul:
		if not bool(stone.get("appraised", false)) or DeepStone.is_geode(stone):
			continue
		for index in range(unit.sockets.size()):
			if not DeepStone.fits(stone, str(unit.sockets[index])):
				continue
			var current: Variant = unit.rail[index] if index < unit.rail.size() else null
			if current == null or (str(current.skill) == str(stone.skill) and int(DeepStone.grade(stone).score) > int(DeepStone.grade(current).score)):
				return act(state, "socket", {"stone_id": stone.id, "index": index})
	return false

func oddity(state: Dictionary) -> void:
	var unit: Dictionary = state.players[0]
	var key: String = str(state.chamber.oddity)
	bump(report.oddities, key)
	var choices: Array = DeepContent.oddity(key).choices
	var stone: Dictionary = {}
	var candidates: Array = DeepStone.rail_stones(unit) + unit.haul
	for candidate in candidates:
		if bool(candidate.get("appraised", false)) and not DeepStone.is_geode(candidate):
			stone = candidate
			break
	for choice in choices:
		var needs: String = str(choice.get("needs", ""))
		var payload: Dictionary = {}
		if needs in ["stone", "gem_and_die"] and not stone.is_empty():
			payload.stone_id = str(stone.id)
		if needs in ["die", "die_face", "gem_and_die"] and not unit.dice.is_empty():
			payload.die_id = unit.dice[0].id
			payload.face = unit.dice[0].faces.size() - 1
		if needs == "pattern":
			payload.pattern = "pair"
		if needs == "ore":
			payload.ore = 10
		if needs == "raw_stone" and not raw_stones(unit).is_empty():
			payload.stone_id = raw_stones(unit)[0].id
		if needs in ["inclusion", "two_stones", "raw_stones", "offer"]:
			continue
		if act(state, "oddity", {"choice": choice.id, "payload": payload}):
			return

func score(battle: Dictionary) -> float:
	var unit: Dictionary = battle.players[0]
	var totals: Dictionary = DeepBattle.forecast(battle, "a").totals
	return float(totals.damage) + float(totals.poison) * 2.0 + minf(float(totals.block), 30.0) * 0.6 + minf(float(totals.heal), float(unit.max_hp) - float(unit.hp)) * 1.3 + float(totals.gold) * 0.2

func reroll_choice(battle: Dictionary) -> Array:
	var unit: Dictionary = battle.players[0]
	var allowed: Array = DeepDice.rerollable(unit.hand)
	if allowed.is_empty():
		return []
	var candidates: Array = [allowed]
	var lows: Array = []
	var counts: Dictionary = {}
	for roll in unit.hand:
		bump(counts, str(roll.value))
		if allowed.has(str(roll.die_id)) and int(roll.value) <= 3:
			lows.append(str(roll.die_id))
	if not lows.is_empty():
		candidates.append(lows)
	var unpaired: Array = []
	for roll in unit.hand:
		if allowed.has(str(roll.die_id)) and int(counts.get(str(roll.value), 0)) == 1:
			unpaired.append(str(roll.die_id))
	if not unpaired.is_empty():
		candidates.append(unpaired)
	var best: float = score(battle)
	var wanted: Array = []
	for candidate in candidates:
		var average: float = 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed = int(active.seed) + int(battle.turn) * 191 + int(unit.rerolls) * 17
		for sample in range(3):
			var copy: Dictionary = battle.duplicate(true)
			copy.players[0].hand = DeepDice.reroll(unit.hand, unit.dice, candidate, rng)
			average += score(copy) / 3.0
		if average > best * 1.03:
			best = average
			wanted = candidate
	return wanted

func fight(state: Dictionary) -> void:
	var battle: Dictionary = DeepDescent.battle(state)
	var key: String = "%s_%d" % [state.mine, int(state.depth)]
	if not book.has(key):
		book[key] = true
		active.fights += 1
		for foe in battle.enemies:
			bump(report.creatures, str(foe.key))
	if str(battle.phase) != "planning":
		DeepDescent.step(state)
		return
	var unit: Dictionary = battle.players[0]
	var turn_key: String = key + "_" + str(battle.turn)
	if not book.has(turn_key):
		book[turn_key] = true
		active.turns += 1
		var targets: Array = DeepBattle.targetable(battle.enemies)
		if not targets.is_empty():
			targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hp) < int(b.hp))
			act(state, "target", {"enemy": targets[0].id})
			return
	if str(active.mode) != "novice" and int(unit.rerolls) > 0:
		var dice: Array = reroll_choice(battle)
		if not dice.is_empty() and act(state, "reroll", {"dice": dice}):
			return
	act(state, "lock")
