class_name DeepBoons
extends RefCounted
## The Grubstake: what the workshop stakes a lapidary before the lift goes down.
##
## At the shaft head every player is offered a handful of stakes and takes one. The offer
## is built from the `boons` section of the pack:
##
##   a stone stake      something for the stones in the rail or the haul
##   a kit stake        health, ore, one of your dice worked, softer rock
##   terms              one cost and one bigger reward, drawn together; costs and rewards
##                      list what they will not pair with
##   a long shot        a gamble, offered only to a veteran: someone whose last run reached
##                      the first Warden
##
## A player whose last run fell before the first landing is shown mercy: their kit stake is
## drawn from the stakes tagged for it. Everything a stake changes is for this run only: the
## rail's stones and the five dice are copies of the vault's and the bowl's, and only the
## haul comes home. No stake hands out a die: dice are only ever worked, never added.
##
## A boon is written as effects with a small vocabulary of their own (they act on the run,
## not on a hand), and says what it `needs`: a socket in the rail, which is drawn at random
## from the stones set there when the stake is taken, or a pick from candidates rolled when
## the offer is made, which the player chooses between once they have taken the stake.

const GROUPS: Array = ["stone", "kit", "cost", "reward", "long_shot"]
const NEEDS: Array = ["", "socket", "pick"]
const EFFECT_KINDS: Array = ["cut_step", "carat", "reroll_cut", "reroll_clarity", "inclusion", "raw_stone", "pick_stone", "resize_die",
	"wild_face", "max_hp_pct", "hp_pct", "ore", "soft_rock", "extra_rerolls", "geode", "roll_ore", "coin_hp"]
const OFFER_KINDS: Array = ["stone", "kit", "terms", "long_shot"]
const PICK_TRIES: int = 12

# --- validation ------------------------------------------------------------------------------

static func validate(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	if not str(def.get("group", "")) in GROUPS:
		errors.append("unknown group " + str(def.get("group", "")))
	if not str(def.get("needs", "")) in NEEDS:
		errors.append("unknown needs " + str(def.get("needs", "")))
	if def.has("weight") and (not (def.weight is int or def.weight is float) or float(def.weight) <= 0.0):
		errors.append("weight must be positive")
	for other in def.get("not_with", []):
		if not p.get("boons", {}).has(str(other)):
			errors.append("not_with names an unknown boon " + str(other))
	var effects: Variant = def.get("effects", null)
	if not effects is Array or effects.is_empty():
		errors.append("needs at least one effect")
		return errors
	for index in range(effects.size()):
		var effect: Variant = effects[index]
		var where: String = "effect %d" % (index + 1)
		if not effect is Dictionary:
			errors.append(where + ": must be an object")
			continue
		var kind: String = str(effect.get("kind", ""))
		if not kind in EFFECT_KINDS:
			errors.append(where + ": unknown kind " + kind)
			continue
		match kind:
			"cut_step", "carat", "max_hp_pct", "hp_pct", "ore", "coin_hp":
				if not (effect.get("amount", null) is int or effect.get("amount", null) is float):
					errors.append(where + ": needs an amount")
			"inclusion":
				if not str(effect.get("class", "")) in DeepContent.INCLUSION_CLASSES:
					errors.append(where + ": unknown inclusion class " + str(effect.get("class", "")))
			"pick_stone":
				if int(effect.get("count", 0)) < 1:
					errors.append(where + ": needs a count")
				if str(def.get("needs", "")) != "pick":
					errors.append(where + ": a pick needs the player to pick")
				if effect.has("min_tier") and not str(effect.min_tier) in DeepStone.TIERS:
					errors.append(where + ": unknown tier " + str(effect.min_tier))
			"resize_die":
				if int(effect.get("amount", 0)) == 0:
					errors.append(where + ": needs a non-zero amount of sizes")
			"soft_rock":
				if int(effect.get("fights", 0)) < 1:
					errors.append(where + ": needs fights")
			"extra_rerolls":
				if int(effect.get("amount", 0)) < 1 or int(effect.get("until_depth", 0)) < 1:
					errors.append(where + ": needs an amount and until_depth")
			"roll_ore":
				if int(effect.get("per_point", 0)) < 1:
					errors.append(where + ": needs per_point")
		if kind in ["cut_step", "carat", "inclusion"] and str(def.get("needs", "")) != "socket":
			errors.append(where + ": acts on a socket, so the boon needs one")
	return errors

# --- standing ----------------------------------------------------------------------------------

static func standing(unit: Dictionary) -> Dictionary:
	## What a player's last run earns them here. `last_depth` and `last_outcome` travel in
	## the player's config from their profile's history.
	var last_depth: int = int(unit.get("last_depth", 0))
	var last_outcome: String = str(unit.get("last_outcome", ""))
	var wardens: Array = DeepContent.constant("warden_depths", [8, 16, 24])
	var first_warden: int = int(wardens[0]) if not wardens.is_empty() else 8
	return {"veteran": last_depth >= first_warden, "mercy": last_outcome == "fallen" and last_depth < DeepDescent.landing_every()}

# --- the offer -----------------------------------------------------------------------------------

static func pool(group: String, tag: String = "") -> Array:
	var keys: Array = []
	for key in DeepContent.section("boons"):
		var def: Dictionary = DeepContent.boon(str(key))
		if str(def.get("group", "")) != group:
			continue
		if not tag.is_empty() and not def.get("tags", []).has(tag):
			continue
		keys.append(str(key))
	keys.sort()
	return keys

static func _draw(rng: RandomNumberGenerator, keys: Array) -> String:
	if keys.is_empty():
		return ""
	var table: Dictionary = {}
	for key in keys:
		table[str(key)] = float(DeepContent.boon(str(key)).get("weight", 3))
	return DeepRng.weighted_key(rng, table)

static func _pairs(cost: String, reward: String) -> bool:
	return not DeepContent.boon(cost).get("not_with", []).has(reward) and not DeepContent.boon(reward).get("not_with", []).has(cost)

static func offer(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator) -> Array:
	## The stakes one player is shown: stone, kit, terms, and a long shot for a veteran.
	var offers: Array = []
	var stand: Dictionary = standing(unit)
	var stone_key: String = _draw(rng, pool("stone"))
	if not stone_key.is_empty():
		offers.append(_make_offer(state, unit, "stone", [stone_key], rng))
	var kit_pool: Array = pool("kit", "mercy") if bool(stand.mercy) else pool("kit")
	if kit_pool.is_empty():
		kit_pool = pool("kit")
	var kit_key: String = _draw(rng, kit_pool)
	if not kit_key.is_empty():
		offers.append(_make_offer(state, unit, "kit", [kit_key], rng))
	var cost: String = _draw(rng, pool("cost"))
	if not cost.is_empty():
		var rewards: Array = pool("reward").filter(func(k: String) -> bool: return _pairs(cost, k))
		var reward: String = _draw(rng, rewards)
		if not reward.is_empty():
			offers.append(_make_offer(state, unit, "terms", [cost, reward], rng))
	if bool(stand.veteran):
		var shot: String = _draw(rng, pool("long_shot"))
		if not shot.is_empty():
			offers.append(_make_offer(state, unit, "long_shot", [shot], rng))
	var index: int = 0
	for entry in offers:
		entry.id = "stake%d" % index
		index += 1
	return offers

static func _make_offer(state: Dictionary, unit: Dictionary, kind: String, keys: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"id": "", "kind": kind, "boons": keys.duplicate(), "needs": [], "picks": [], "pick_kind": ""}
	var mine: Dictionary = DeepDescent.mine_of(state)
	for key in keys:
		var def: Dictionary = DeepContent.boon(str(key))
		var needs: String = str(def.get("needs", ""))
		if not needs.is_empty() and not out.needs.has(needs):
			out.needs.append(needs)
		for effect in def.get("effects", []):
			match str(effect.get("kind", "")):
				"pick_stone":
					out.pick_kind = "stone"
					for _i in range(int(effect.get("count", 3))):
						out.picks.append(_appraised_stone(rng, mine, int(effect.get("depth", 4)), int(effect.get("bonus", 0)), str(effect.get("min_tier", "")), str(state.get("run_id", "")), "%s_%s_%d" % [str(unit.id), str(key), out.picks.size()]))
	return out

static func _appraised_stone(rng: RandomNumberGenerator, mine: Dictionary, depth: int, bonus: int, min_tier: String, run_id: String, id: String) -> Dictionary:
	var stone: Dictionary = DeepForge.roll_stone(rng, mine, depth, bonus, {"run": run_id, "source": "grubstake"}, id)
	if not min_tier.is_empty():
		var wanted: int = DeepStone.TIERS.find(min_tier)
		var tries: int = 0
		while tries < PICK_TRIES and DeepStone.TIERS.find(str(DeepStone.grade(stone).tier)) < wanted:
			tries += 1
			var again: Dictionary = DeepForge.roll_stone(rng, mine, depth, bonus + tries * 3, {"run": run_id, "source": "grubstake"}, id)
			if int(DeepStone.grade(again).score) >= int(DeepStone.grade(stone).score):
				stone = again
	stone.appraised = true
	stone.inclusions_revealed = true
	return stone

# --- taking a stake ------------------------------------------------------------------------------

static func apply(state: Dictionary, unit: Dictionary, chosen: Dictionary, payload: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## Resolve one player's stake. A stake on a stone lands on one stone drawn from the rail,
	## every effect of it on the same one; a pick takes the candidate the payload names.
	## Returns {ok, error, message, made: [stones], dice: [dice], changed: [the rail stone], socket}.
	var out: Dictionary = {"ok": true, "error": "", "message": "", "made": [], "dice": [], "changed": [], "socket": -1}
	var pick: int = int(payload.get("pick", -1))
	if chosen.get("needs", []).has("pick"):
		if pick < 0 or pick >= chosen.get("picks", []).size():
			return _refuse("choose one of the three")
	var socket: int = -1
	if chosen.get("needs", []).has("socket"):
		var set_sockets: Array = []
		for index in range(unit.get("rail", []).size()):
			if unit.rail[index] is Dictionary:
				set_sockets.append(index)
		if set_sockets.is_empty():
			return _refuse("your rail is empty")
		socket = int(DeepRng.pick(rng, set_sockets))
		out.socket = socket
	var lines: Array = []
	for key in chosen.get("boons", []):
		var def: Dictionary = DeepContent.boon(str(key))
		for effect in def.get("effects", []):
			var said: String = _effect(state, unit, effect, chosen, socket, pick, rng, out)
			if not said.is_empty():
				lines.append(said)
	if socket >= 0:
		out.changed.append(unit.rail[socket].duplicate(true))
	out.message = " ".join(lines)
	return out

static func _effect(state: Dictionary, unit: Dictionary, effect: Dictionary, chosen: Dictionary, socket: int, pick: int, rng: RandomNumberGenerator, out: Dictionary) -> String:
	var kind: String = str(effect.get("kind", ""))
	var mine: Dictionary = DeepDescent.mine_of(state)
	var amount: int = int(effect.get("amount", 0))
	match kind:
		"cut_step":
			## Only ever downward, and only on a rail stone, which is a copy of the one in the
			## vault: nothing here may make a stone truer for good. See `reroll_cut`.
			var stone: Dictionary = unit.rail[socket]
			stone.cut = clampi(int(stone.get("cut", 0)) + mini(amount, 0), 0, DeepPatterns.STEPS - 1)
			return "%s is now judged %s." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), DeepContent.cut_name(int(stone.cut))]
		"reroll_cut":
			## A fresh draw of the stone's Cut from this mine's table, better or worse. With
			## `best_of` the wheel is kind and the truer of that many rolls is kept.
			var stone: Dictionary = unit.rail[socket]
			var was: int = int(stone.get("cut", 0))
			var best: int = -1
			for _try in range(maxi(1, int(effect.get("best_of", 1)))):
				best = maxi(best, DeepForge.reroll_cut(rng, stone, mine, int(effect.get("depth", 4)), int(effect.get("bonus", 0))))
			stone.cut = best
			return "%s comes off the wheel %s, from %s." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), DeepContent.cut_name(best), DeepContent.cut_name(was)]
		"reroll_clarity":
			var stone: Dictionary = unit.rail[socket]
			var rolled: Dictionary = DeepForge.reroll_clarity(rng, stone, mine, int(effect.get("depth", 4)), int(effect.get("bonus", 0)))
			var named: Array = DeepStone.inclusion_names(stone)
			return "%s is fired again: %s, from %s.%s" % [str(DeepStone.skill_of(stone).get("name", stone.skill)),
				DeepContent.clarity_name(int(rolled.clarity)), DeepContent.clarity_name(int(rolled.was)),
				("" if named.is_empty() else " Inside it now: %s." % ", ".join(named))]
		"carat":
			var stone: Dictionary = unit.rail[socket]
			stone.carat = clampi(int(stone.get("carat", 1)) + amount, 1, DeepStone.carat_max())
			return "%s weighs %d carats now." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), int(stone.carat)]
		"inclusion":
			var stone: Dictionary = unit.rail[socket]
			var rolled: Array = DeepForge.roll_inclusions(rng, 1, mine, str(effect.get("class", "PINPOINT")), DeepStone.color(stone))
			var fresh: Array = rolled.filter(func(k: String) -> bool: return not stone.get("inclusions", []).has(k))
			if fresh.is_empty():
				return "%s already carries everything the rock could give it." % str(DeepStone.skill_of(stone).get("name", stone.skill))
			stone.inclusions.append(str(fresh[0]))
			stone.inclusions_revealed = true
			return "A %s forms inside %s." % [str(DeepContent.inclusion(str(fresh[0])).get("name", fresh[0])), str(DeepStone.skill_of(stone).get("name", stone.skill))]
		"raw_stone":
			var stone: Dictionary = DeepForge.roll_stone(rng, mine, int(effect.get("depth", 4)), int(effect.get("bonus", 0)),
				{"run": str(state.get("run_id", "")), "source": "grubstake", "finder": str(unit.id)}, "%s_stake%08x" % [str(unit.id), rng.randi()])
			unit.haul.append(stone)
			out.made.append(stone)
			return "A %s goes into your haul, unappraised." % DeepStone.raw_name(stone).to_lower()
		"pick_stone":
			var stone: Dictionary = chosen.picks[pick].duplicate(true)
			stone.provenance.finder = str(unit.id)
			unit.haul.append(stone)
			out.made.append(stone)
			return "You take the %s." % DeepStone.name(stone)
		"resize_die":
			## One of the five, drawn from those that can go that way.
			var steps: int = amount if amount != 0 else 1
			var able: Array = unit.get("dice", []).filter(func(d: Dictionary) -> bool: return DeepOddities.resize_refusal(d, steps).is_empty())
			if able.is_empty():
				return "None of your dice can be made any %s." % ("bigger" if steps > 0 else "smaller")
			var die: Dictionary = DeepRng.pick(rng, able)
			var was: String = DeepDice.describe(die)
			DeepOddities.resize(die, steps)
			out.dice.append(die.duplicate(true))
			return "Your %s is a %s now." % [was, DeepDice.describe(die)]
		"wild_face":
			## One of the five, drawn from those with a plain face left: its highest plain face.
			var able: Array = unit.get("dice", []).filter(func(d: Dictionary) -> bool: return d.get("faces", []).any(func(f: Dictionary) -> bool: return str(f.get("kind", "plain")) == "plain"))
			if able.is_empty():
				return "Every face of your dice is something special already."
			var die: Dictionary = DeepRng.pick(rng, able)
			var best: int = -1
			for index in range(die.faces.size()):
				if str(die.faces[index].get("kind", "plain")) == "plain" and (best < 0 or int(die.faces[index].value) > int(die.faces[best].value)):
					best = index
			die.faces[best] = DeepDice.face(int(die.faces[best].value), "wild")
			out.dice.append(die.duplicate(true))
			return "The %d on your %s turns wild." % [int(die.faces[best].value), DeepDice.describe(die)]
		"max_hp_pct":
			return _max_hp(unit, amount)
		"hp_pct":
			var loss: int = int(floor(float(unit.get("hp", 0)) * float(absi(amount)) / 100.0))
			unit.hp = maxi(1, int(unit.get("hp", 0)) - loss)
			return "You start %d health down." % loss
		"ore":
			unit.ore = maxi(0, int(unit.get("ore", 0)) + amount)
			return ("You take %d ore." % amount) if amount >= 0 else ("You give up %d ore." % -amount)
		"soft_rock":
			if not unit.has("run_mods"):
				unit.run_mods = {}
			unit.run_mods.soft_rock = int(unit.run_mods.get("soft_rock", 0)) + int(effect.get("fights", 3))
			return "The rock is soft for your first %d fights." % int(effect.get("fights", 3))
		"extra_rerolls":
			if not unit.has("run_mods"):
				unit.run_mods = {}
			unit.run_mods.extra_rerolls = {"amount": int(effect.get("amount", 1)), "until_depth": int(effect.get("until_depth", 4))}
			return "+%d reroll a turn down to depth %d." % [int(effect.get("amount", 1)), int(effect.get("until_depth", 4))]
		"geode":
			var roll: float = rng.randf() * 100.0
			var three: float = float(effect.get("three", 40))
			var one: float = float(effect.get("one", 40))
			if roll < three:
				for _i in range(3):
					var small: Dictionary = DeepForge.roll_stone(rng, mine, 4, -2, {"run": str(state.get("run_id", "")), "source": "grubstake", "finder": str(unit.id)}, "%s_geode%08x" % [str(unit.id), rng.randi()])
					unit.haul.append(small)
					out.made.append(small)
				return "The geode splits into three small stones."
			if roll < three + one:
				var big: Dictionary = DeepForge.roll_stone(rng, mine, 6, 6, {"run": str(state.get("run_id", "")), "source": "grubstake", "finder": str(unit.id)}, "%s_geode%08x" % [str(unit.id), rng.randi()])
				unit.haul.append(big)
				out.made.append(big)
				return "One heavy stone rolls out of the geode."
			return "The geode is dust inside."
		"roll_ore":
			var hand: Array = DeepDice.roll_hand(unit.get("dice", []), rng)
			var total: int = 0
			for roll in hand:
				total += int(roll.get("value", 0))
			var paid: int = total * int(effect.get("per_point", 3))
			unit.ore = int(unit.get("ore", 0)) + paid
			out.rolled = DeepDice.values(hand)
			return "You roll %s: %d ore." % [", ".join(out.rolled.map(func(v: int) -> String: return str(v))), paid]
		"coin_hp":
			var heads: bool = DeepRng.chance(rng, 50.0)
			out.heads = heads
			return ("Heads. " if heads else "Tails. ") + _max_hp(unit, amount if heads else -amount)
	return ""

static func _max_hp(unit: Dictionary, pct: int) -> String:
	var delta: int = int(round(float(unit.get("max_hp", 60)) * float(pct) / 100.0))
	unit.max_hp = maxi(1, int(unit.get("max_hp", 60)) + delta)
	unit.hp = clampi(int(unit.get("hp", unit.max_hp)) + delta, 1, int(unit.max_hp))
	return ("Your health rises by %d." % delta) if delta >= 0 else ("Your health falls by %d." % -delta)

static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error, "message": "", "made": [], "dice": []}
