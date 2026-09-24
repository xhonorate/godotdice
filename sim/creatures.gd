class_name DeepCreatures
extends RefCounted
## The creatures of the rock: how one is made for a depth and a party, and how it decides
## what it can do. Results are produced one die at a time during its action phase.

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
		"block": int(def.get("block", 0)), "statuses": {"ward": clampi(int(def.get("ward", 1 if bool(def.get("warden", false)) else 0)), 0, 99)}, "dice": dice, "hand": [], "moves": [], "move_states": [], "used_combos": [],
		"acting": false, "beat": "", "rolled_die": {}, "damage_bonus": 0, "enrage_bonus": 0, "next_die": 0, "suppressed": 0, "active_move": -1,
		"gimmick": str(def.get("gimmick", "")), "warden": bool(def.get("warden", false)), "phase": 0,
		"stolen_dice": 0, "dread_turns": 0, "dice_upgrade": 0, "stolen_gold": 0, "stun_streak": 0, "clouded_move": -1, "threat": int(def.get("threat", 1)),
		"text": str(def.get("text", ""))}

static func phase_for(enemy: Dictionary) -> int:
	var definition: Dictionary = DeepContent.creature(str(enemy.get("key", "")))
	var hp_pct: int = int(float(enemy.get("hp", 0)) * 100.0 / float(maxi(1, int(enemy.get("max_hp", 1)))))
	var selected: int = 0
	var phases: Array = definition.get("phases", [])
	for index in range(phases.size()):
		if hp_pct <= int(phases[index].get("below_hp_pct", 0)):
			selected = index + 1
	return selected

static func moves_for(enemy: Dictionary) -> Array:
	var definition: Dictionary = DeepContent.creature(str(enemy.get("key", "")))
	var phase: int = phase_for(enemy)
	return definition.get("phases", [])[phase - 1].get("moves", []) if phase > 0 else definition.get("moves", [])

const TIERS: Array = DeepDice.TIERS
const COMBINATIONS: Array = ["pair", "triple", "quad", "quint", "two_pair", "full_house", "straight", "all_odd", "all_even"]

static func effective_dice(enemy: Dictionary) -> Array:
	var out: Array = []
	var upgrade: int = int(enemy.get("dice_upgrade", 0))
	var dread: int = maxi(0, int(enemy.get("dread_turns", 0)))
	for base in enemy.get("dice", []):
		var index: int = TIERS.find(str(base.get("shape", "D6")))
		var tier: int = maxi(0, clampi(index + upgrade, 0, TIERS.size() - 1) - dread)
		var key: String = str(TIERS[tier])
		out.append(base.duplicate(true) if tier == index else DeepDice.make(key, DeepContent.die(key), str(base.id)))
	return out

static func prepare(enemy: Dictionary) -> void:
	## Public planning information only; this never consumes random numbers.
	enemy.phase = phase_for(enemy)
	enemy.moves = moves_for(enemy).duplicate(true)
	enemy.hand = []
	enemy.rolled_die = {}
	enemy.used_combos = []
	enemy.move_states = []
	enemy.next_die = 0
	enemy.active_move = -1
	enemy.acting = false
	enemy.beat = ""
	enemy.suppressed = 0
	for index in range(enemy.moves.size()):
		enemy.move_states.append("clouded" if move_clouded(enemy, index) else "unrevealed")

static func move_clouded(enemy: Dictionary, index: int) -> bool:
	return int(enemy.get("statuses", {}).get("clouded", 0)) > 0 and index == mini(int(enemy.get("clouded_move", -1)), enemy.get("moves", []).size() - 1)

static func finish(enemy: Dictionary) -> void:
	enemy.acting = false
	enemy.beat = "done"
	enemy.dread_turns = maxi(0, int(enemy.get("dread_turns", 0)) - 1)
	if int(enemy.statuses.get("clouded", 0)) > 0:
		enemy.statuses.clouded = int(enemy.statuses.clouded) - 1
		if int(enemy.statuses.clouded) == 0:
			enemy.clouded_move = -1

static func is_combination(move: Dictionary) -> bool:
	return str(move.get("trigger", {}).get("kind", "always")) in COMBINATIONS

static func activation(move: Dictionary, history: Array, last: bool) -> Dictionary:
	var combo: bool = is_combination(move)
	var read: Array = history if combo else history.slice(-1)
	var a: Dictionary = DeepHand.analyze(read)
	var trigger: Dictionary = move.get("trigger", {"kind": "always"})
	var result: Dictionary = DeepPatterns.evaluate(trigger, 0, a)
	if str(trigger.get("kind", "")) in ["all_odd", "all_even"] and not last:
		result.active = false
	return result

static func can_complete(move: Dictionary, history: Array, remaining: Array) -> bool:
	## Look only at possible faces, never at future RNG. Current content has at most 3 dice.
	if bool(activation(move, history, remaining.is_empty()).active):
		return true
	if remaining.is_empty():
		return false
	var die: Dictionary = remaining[0]
	for face in die.get("faces", []):
		var sample: Dictionary = {"die_id": str(die.id), "value": int(face.value), "kind": str(face.get("kind", "plain")), "top": DeepDice.top(die)}
		if can_complete(move, history + [sample], remaining.slice(1)):
			return true
	return false

static func suspense(enemy: Dictionary, remaining: Array) -> bool:
	if remaining.size() != 1 or enemy.get("hand", []).is_empty():
		return false
	for index in range(enemy.moves.size()):
		if move_clouded(enemy, index):
			continue
		var move: Dictionary = enemy.moves[index]
		if bool(move.get("dramatic", false)) and is_combination(move) and not enemy.used_combos.has(index):
			if can_complete(move, enemy.hand, remaining):
				return true
	return false

static func resolve_roll(enemy: Dictionary, state: Dictionary) -> Array:
	var dice: Array = effective_dice(enemy)
	var available: int = maxi(0, dice.size() - int(enemy.get("suppressed", 0)))
	var remaining: Array = dice.slice(int(enemy.next_die), available)
	var out: Array = []
	for index in range(enemy.moves.size()):
		if move_clouded(enemy, index):
			enemy.move_states[index] = "clouded"
			continue
		var move: Dictionary = enemy.moves[index]
		var combo: bool = is_combination(move)
		if combo and enemy.used_combos.has(index):
			enemy.move_states[index] = "used"
			continue
		var trig: Dictionary = activation(move, enemy.hand, remaining.is_empty())
		if not trig.active:
			enemy.move_states[index] = "pending" if combo and can_complete(move, enemy.hand, remaining) else "missed"
			continue
		enemy.move_states[index] = "activated"
		if combo:
			enemy.used_combos.append(index)
		var a: Dictionary = DeepHand.analyze(enemy.hand if combo else enemy.hand.slice(-1))
		var c: Dictionary = {"a": a, "trig": trig, "unit": enemy, "depth": int(state.get("depth", 1)),
			"turn": int(state.get("turn", 1)), "party": state.get("players", []).size(), "rolled": int(enemy.hand.back().value)}
		var effects: Array = []
		for definition in move.get("effects", []):
			var effect: Dictionary = DeepRules.resolve_effect(definition, c, 1.0, "heroes")
			if str(effect.target) == "hero":
				effect.target = "heroes"
			if str(effect.kind) == "damage":
				effect.amount += int(enemy.get("damage_bonus", 0))
			effects.append(effect)
		out.append({"move": str(move.get("name", "?")), "index": index, "effects": effects,
			"dice": trig.get("dice", []), "combo": combo, "trigger": move.get("trigger", {}), "roll_index": int(enemy.next_die) - 1})
	return out

static func refresh_bonuses(enemy: Dictionary, state: Dictionary) -> void:
	var count: int = maxi(1, enemy.get("dice", []).size())
	enemy.damage_bonus = int(int(state.get("depth", 1)) / maxi(1, int(DeepContent.constant("depth_damage_every", 4)))) / count
	if str(enemy.get("gimmick", "")) == "mirror_last_gem":
		var reflected: int = 0
		for player in state.get("players", []):
			reflected = maxi(reflected, int(player.get("dealt_last_turn", 0)) / 2)
		enemy.damage_bonus += mini(6, reflected) / count
	enemy.enrage_bonus = maxi(0, int(state.get("turn", 1)) - int(DeepContent.constant("enrage_turn", 7)) + 1) * int(DeepContent.constant("enrage_damage", 2))

static func display_moves(enemy: Dictionary, moves: Array = []) -> Array:
	var shown: Array = (enemy.get("moves", []) if moves.is_empty() else moves).duplicate(true)
	var bonus: int = int(enemy.get("damage_bonus", 0)) + int(enemy.get("enrage_bonus", 0))
	for move in shown:
		for effect in move.get("effects", []):
			if str(effect.kind) == "damage":
				if bonus > 0:
					effect.amount = {"op": "+", "args": [effect.get("amount", 0), bonus]}
				var pct: int = DeepRules.outgoing_damage(100, enemy.get("statuses", {}))
				if pct != 100:
					effect.amount = {"op": "pct", "args": [effect.get("amount", 0), pct]}
	return shown

static func trigger_words(move: Dictionary) -> String:
	var t: Dictionary = move.get("trigger", {"kind": "always"})
	var n: int = DeepPatterns.rung(t, 0)
	match str(t.get("kind", "always")):
		"always": return "Every roll"
		"odd": return "Odd roll"
		"even": return "Even roll"
		"at_least": return "Roll %d+" % n
		"at_most": return "Roll ≤%d" % n
		"value": return "Roll " + "/".join(t.get("values", []).map(func(v: Variant) -> String: return str(int(v))))
		"crowns": return "Maximum face"
		"pair", "triple", "quad", "quint":
			var name: String = str({"pair": "Pair", "triple": "Three of a kind", "quad": "Four of a kind", "quint": "Five of a kind"}[str(t.kind)])
			return name + (" (%d+)" % n if n > 1 else "") + " · once/turn"
		"straight": return "%d-value sequence · once/turn" % n
		"all_odd": return "All odd · %d+ dice" % n
		"all_even": return "All even · %d+ dice" % n
	return DeepPatterns.words(t, 0).trim_suffix(".") + " · once/turn"

static func amount_words(expr: Variant) -> String:
	if expr is int or expr is float:
		return str(int(expr))
	if not expr is Dictionary:
		return "0"
	if expr.has("term"):
		return str({"rolled": "Rolled value", "value": "Matched value", "total": "Dice total", "high": "Highest value", "low": "Lowest value"}.get(str(expr.term), str(expr.term)))
	if expr.has("const"):
		return str(int(expr.const))
	var parts: Array = expr.get("args", []).map(func(a: Variant) -> String: return amount_words(a))
	return (" %s " % str(expr.get("op", "+"))).join(parts)

static func effect_words(effect: Dictionary) -> String:
	var n: String = amount_words(effect.get("amount", 0))
	match str(effect.get("kind", "")):
		"damage": return "%s damage · all players" % n
		"block": return "Gain %s block" % n
		"heal": return "Heal %s" % n
		"die_steal": return "Suppress %s die · all players · next turn" % n
		"poison": return "%s poison · all players" % n
		"stun": return "Stun all players · %s turn" % n
		"remove_block": return "Remove %s block · all players" % n
		"curse": return "%s Curse · −10%% dealt / +10%% taken per stack (max 10) · all players" % n
		"clouded": return "Cloud a socket · all players" if str(effect.get("target", "heroes")) in ["hero", "heroes"] else "Clouded for %s actions · one random ability disabled" % n
		"marked": return "%s Marked · next hit +25%% per stack" % n
		"dulled": return "%s Dulled · gems lose one Cut step per stack" % n
		"ward": return "%s Ward · blocks debuff applications (max 99)" % n
		"retain": return "Retain up to %s block at the next reset" % n
		"charged": return "%s Charged · starting Resonance next turn" % n
		"regeneration": return "%s Regeneration · heal at turn end, then lose one stack" % n
		"spikes": return "%s Spikes · retaliate once per attacking ability" % n
		"dice_dread": return "%s Dread · dice lose one tier per stack" % n
		"dice_upgrade": return "Dice +%s tier · this fight" % n
	return str(effect.get("kind", "")).capitalize() + " " + n
