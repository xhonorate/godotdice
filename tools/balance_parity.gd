extends SceneTree
## The balance browser's fight (tools/data-browser/js/sim/fight.js) checked against the real
## rail. Reads the fixtures tools/data-browser/parity.mjs writes, plays each one's rails with
## DeepBattle on fixed hands, and writes down the state after every rail for parity.mjs to
## hold the JavaScript to.
##
##   Godot --headless --path . --script tools/balance_parity.gd -- <fixtures.json> <out.json>
##
## A fixture is a character, a rail of stones, the hands its rails are played on (as face
## indices on the character's own dice, so a face Glimmer raised reads raised next time), and
## the state the fight stands in: the player's health, block and statuses, two creatures'
## block and statuses. "dry" fixtures play the way the forecast does (no coin, no proc roll,
## nothing queued); "live" ones queue replays and retriggers for real, on stones that never
## roll for a proc, so neither side's random numbers are asked for anything that matters.

const ENEMY_HP: int = 1000000

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: --script tools/balance_parity.gd -- <fixtures.json> <out.json>")
		quit(2)
		return
	var fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not fixtures is Array:
		printerr("could not read fixtures from " + args[0])
		quit(2)
		return
	var out: Array = []
	for fixture in fixtures:
		out.append(_run(fixture))
	var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	print("balance parity: %d fixtures played" % out.size())
	quit(0)

func _run(f: Dictionary) -> Dictionary:
	var character: String = str(f.character)
	var refs: Array = DeepContent.character(character).get("dice", [])
	var dice: Array = []
	for index in range(refs.size()):
		dice.append(DeepForge.die_from(refs[index], "p%d" % index))
	var rail: Array = []
	for spec in f.rail:
		if spec == null:
			rail.append(null)
		else:
			rail.append(DeepStone.make(str(spec.skill), int(spec.carat), int(spec.cut), int(spec.clarity), spec.inclusions, {}, str(spec.id)))
	var unit: Dictionary = DeepBattle.make_player("p0", "P0", character, rail, dice)
	unit.ore = int(f.pyrite)
	var streams: Dictionary = DeepRng.streams(int(f.seed), ["dice", "creatures"])
	var keys: Array = []
	for _foe in f.enemies:
		keys.append("RAIL_RAT")
	var state: Dictionary = DeepBattle.begin([unit], keys, {"depth": int(f.depth)}, streams.dice, streams.creatures)
	for index in range(state.enemies.size()):
		var foe: Dictionary = state.enemies[index]
		foe.hp = ENEMY_HP
		foe.max_hp = ENEMY_HP
		foe.block = int(f.enemies[index].block)
		foe.statuses = _ints(f.enemies[index].statuses)
	var a: Dictionary = DeepBattle.player(state, "p0")
	a.hp = int(f.unit.hp)
	a.block = int(f.unit.block)
	a.block_lost = int(f.unit.block_lost)
	a.statuses = _ints(f.unit.statuses)
	a.initial_resonance = int(f.unit.initial_resonance)
	a.rerolls = int(f.unit.rerolls)
	a.target = str(state.enemies[0].id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dry: bool = str(f.mode) == "dry"
	var snaps: Array = []
	for run in f.runs:
		a.hand = _hand(a, run.hand)
		state.phase = "resolving"
		a.firing_target = a.target
		var queue: Array = [{"kind": "rail_begin", "unit": "p0"}]
		for socket in range(a.rail.size()):
			if a.rail[socket] is Dictionary:
				queue.append({"kind": "gem", "unit": "p0", "socket": socket})
		if not a.get("birthstone", {}).is_empty():
			queue.append({"kind": "birthstone", "unit": "p0"})
		queue.append({"kind": "rail_end", "unit": "p0"})
		state.queue = queue
		var events: Array = []
		var guard: int = 0
		while not state.queue.is_empty() and guard < 5000:
			guard += 1
			var s: Dictionary = state.queue.pop_front()
			match str(s.kind):
				"gem":
					events.append(DeepBattle.resolve_gem(state, a, int(s.socket), {"dry": dry, "retrigger": bool(s.get("retrigger", false)),
						"scale": int(s.get("scale", 100)), "replay": bool(s.get("replay", false)), "force": bool(s.get("force", false))}, rng))
				"birthstone":
					events.append(DeepBattle.resolve_birthstone(state, a, {"dry": dry, "replay": bool(s.get("replay", false)), "share": int(s.get("share", 100))}, rng))
				_:
					events.append(DeepBattle._perform(state, s, rng, rng))
		snaps.append(_snapshot(state, a, events))
	return {"id": f.id, "snaps": snaps}

func _hand(unit: Dictionary, spec: Array) -> Array:
	var out: Array = []
	for index in range(mini(spec.size(), unit.dice.size())):
		var die: Dictionary = unit.dice[index]
		var face: int = int(spec[index].face)
		out.append({"die_id": str(die.id), "shape": str(die.shape), "material": str(die.get("material", "")), "value": DeepDice.face_value(die.faces[face]),
			"face": face, "kind": str(die.faces[face].get("kind", "plain")), "top": DeepDice.top(die), "held": bool(spec[index].held),
			"rerolls": int(spec[index].rerolls), "locked": false, "explosions": 0, "phantom": false})
	return out

func _ints(source: Variant, skip: Array = []) -> Dictionary:
	## A dictionary of counts with the zeros left out, so "none" and "0" read the same.
	var out: Dictionary = {}
	if not source is Dictionary:
		return out
	for key in source:
		if skip.has(str(key)) or not (source[key] is int or source[key] is float):
			continue
		if int(source[key]) != 0:
			out[str(key)] = int(source[key])
	return out

func _snapshot(state: Dictionary, a: Dictionary, events: Array) -> Dictionary:
	var foes: Array = []
	for foe in state.enemies:
		foes.append({"hp": int(foe.hp), "max_hp": int(foe.max_hp), "block": int(foe.block), "statuses": _ints(foe.statuses),
			"stolen_dice": int(foe.get("stolen_dice", 0)), "dread_turns": int(foe.get("dread_turns", 0))})
	var hand: Array = []
	for roll in a.hand:
		hand.append([str(roll.die_id), int(roll.value), bool(roll.get("phantom", false))])
	var faces: Array = []
	for die in a.dice:
		var values: Array = []
		for face in die.faces:
			values.append(int(face.value))
		faces.append(values)
	var rail: Array = []
	for stone in a.rail:
		rail.append("" if not stone is Dictionary else str(stone.id))
	var buffs: Dictionary = {}
	for id in a.get("gem_buffs", {}):
		var entry: Dictionary = _ints(a.gem_buffs[id])
		if not entry.is_empty():
			buffs[str(id)] = entry
	var once: Array = a.get("once", {}).keys()
	once.sort()
	var log: Array = []
	for event in events:
		if not event is Dictionary or event.is_empty():
			continue
		match str(event.kind):
			"gem_fire", "gem_fizzle":
				log.append([str(event.kind), int(event.socket), int(event.get("resonance", 0))])
			"birthstone":
				var lit: Array = []
				for tier in event.get("tiers", []):
					lit.append(bool(tier.get("active", false)))
				log.append(["birthstone", bool(event.get("fired", false)), lit])
	return {"unit": {"hp": int(a.hp), "max_hp": int(a.max_hp), "block": int(a.block), "resonance": int(a.resonance), "gold": int(a.get("gold", 0)),
		"pyrite_delta": int(a.get("pyrite_delta", 0)), "pot": int(a.get("pot", 0)), "statuses": _ints(a.statuses), "granted_rerolls": int(a.get("granted_rerolls", 0)),
		"sparkle": int(a.get("sparkle", 0)), "quality_bonus": int(a.get("quality_bonus", 0)), "rank_buff": _ints(a.get("rank_buff", {})), "gem_buffs": buffs,
		"fired": a.get("fired_sockets", []).map(func(x: Variant) -> int: return int(x)), "fizzled": a.get("fizzled_sockets", []).map(func(x: Variant) -> int: return int(x)),
		"rail": rail, "hand": hand, "faces": faces, "amplify": snappedf(float(a.get("amplify", 1.0)), 0.0001), "cut_step_bonus": int(a.get("cut_step_bonus", 0)),
		"nullify_next": bool(a.get("nullify_next", false)), "repeat_next": int(a.get("repeat_next", 0)), "healed": int(a.get("healed", 0)), "dealt": int(a.get("dealt", 0)),
		"once": once}, "enemies": foes, "events": log}
