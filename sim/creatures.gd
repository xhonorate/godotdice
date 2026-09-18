class_name DeepCreatures
extends RefCounted
## The creatures of the rock: how one is made for a depth and a party, and how it decides
## what it will do. Intents are published before the players roll, in the same pictograph
## language the players' own gems use.

static func make(key: String, id: String, depth: int, party: int) -> Dictionary:
	var def: Dictionary = DeepContent.creature(key)
	var hp_scale: float = 1.0 + float(DeepContent.constant("depth_hp_scale", 0.05)) * float(maxi(0, depth - 1))
	hp_scale *= 1.0 + 0.15 * float(clampi(party, 1, 4) - 1)
	var hp: int = maxi(1, int(round(float(def.get("hp", 10)) * hp_scale)))
	var dice: Array = []
	var index: int = 0
	for die_key in def.get("dice", []):
		dice.append(DeepDice.make(str(die_key), DeepContent.die(str(die_key)), "%s_d%d" % [id, index]))
		index += 1
	return {"id": id, "key": key, "name": str(def.get("name", key)), "side": "enemy", "hp": hp, "max_hp": hp,
		"block": int(def.get("block", 0)), "statuses": {}, "dice": dice, "hand": [], "intents": [],
		"gimmick": str(def.get("gimmick", "")), "warden": bool(def.get("warden", false)), "phase": 0,
		"stolen_dice": 0, "downgrade": 0, "cycle": 0, "stolen_gold": 0, "threat": int(def.get("threat", 1)),
		"text": str(def.get("text", ""))}

static func moves_for(enemy: Dictionary) -> Array:
	## A warden below a phase threshold fights from that phase's list instead.
	var def: Dictionary = DeepContent.creature(str(enemy.get("key", "")))
	var moves: Array = def.get("moves", [])
	var hp_pct: int = int(float(enemy.get("hp", 0)) * 100.0 / float(maxi(1, int(enemy.get("max_hp", 1)))))
	var phase_index: int = 0
	var phases: Array = def.get("phases", [])
	for index in range(phases.size()):
		if hp_pct <= int(phases[index].get("below_hp_pct", 0)):
			moves = phases[index].get("moves", moves)
			phase_index = index + 1
	enemy.phase = phase_index
	return moves

static func roll(enemy: Dictionary, rng: RandomNumberGenerator) -> Array:
	## Bind takes dice away for one turn: the last ones in the row stay in the creature's paw.
	var dice: Array = enemy.get("dice", []).duplicate()
	var stolen: int = int(enemy.get("stolen_dice", 0))
	while stolen > 0 and dice.size() > 1:
		dice.pop_back()
		stolen -= 1
	enemy.stolen_dice = 0
	return DeepDice.roll_hand(dice, rng)

static func intents(enemy: Dictionary, state: Dictionary, rng: RandomNumberGenerator) -> Array:
	var def: Dictionary = DeepContent.creature(str(enemy.get("key", "")))
	enemy.hand = roll(enemy, rng)
	var a: Dictionary = DeepHand.analyze(enemy.hand)
	var moves: Array = moves_for(enemy)
	if moves.is_empty():
		return []
	var active: Array = []
	for index in range(moves.size()):
		var trig: Dictionary = DeepPatterns.evaluate(moves[index].get("trigger", {"kind": "always"}), 0, a)
		if trig.active:
			active.append(index)
	var chosen: Array = []
	match str(def.get("policy", "best")):
		"all":
			chosen = active if not active.is_empty() else [0]
		"cycle":
			var index: int = int(enemy.get("cycle", 0)) % moves.size()
			enemy.cycle = int(enemy.get("cycle", 0)) + 1
			chosen = [index] if active.has(index) else [0]
		_:
			chosen = [active[active.size() - 1]] if not active.is_empty() else [0]
	if int(enemy.get("downgrade", 0)) > 0 and not chosen.is_empty():
		## Dread: the strongest move it meant to make is weakened by a step.
		chosen[chosen.size() - 1] = maxi(0, int(chosen[chosen.size() - 1]) - 1)
		enemy.downgrade = int(enemy.downgrade) - 1
	var living: Array = state.get("players", []).filter(func(p: Dictionary) -> bool: return not bool(p.get("downed", false)))
	var out: Array = []
	var depth: int = int(state.get("depth", 1))
	var bonus: int = int(depth / maxi(1, int(DeepContent.constant("depth_damage_every", 4))))
	for index in chosen:
		var move: Dictionary = moves[index]
		var trig: Dictionary = DeepPatterns.evaluate(move.get("trigger", {"kind": "always"}), 0, a)
		var target: Dictionary = DeepRng.pick(rng, living) if not living.is_empty() else {}
		var tc: Dictionary = {"a": a, "trig": trig, "unit": enemy, "depth": depth, "turn": int(state.get("turn", 1)), "party": living.size()}
		var effects: Array = []
		for effect_def in move.get("effects", []):
			var effect: Dictionary = DeepRules.resolve_effect(effect_def, tc, 1.0, "hero")
			if str(effect.kind) == "damage":
				effect.amount += bonus
			effects.append(effect)
		out.append({"move": str(move.get("name", "?")), "index": index, "target": str(target.get("id", "")), "effects": effects,
			"trigger": DeepPatterns.describe(move.get("trigger", {"kind": "always"}), 0), "dice": trig.get("dice", [])})
	return out
