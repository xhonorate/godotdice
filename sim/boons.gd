class_name DeepBoons
extends RefCounted
## The Grubstake: what the workshop stakes a lapidary before the lift goes down.
##
## At the shaft head every player is offered a handful of stakes and takes one. The offer
## is built from the `boons` section of the pack:
##
##   a stone stake      something for the stones in the rail or the haul
##   a kit stake        health, ore, loupes, dice, softer rock
##   terms              one cost and one bigger reward, drawn together; costs and rewards
##                      list what they will not pair with
##   a long shot        a gamble, offered only to a veteran: someone whose last run reached
##                      the first Warden
##
## A player whose last run fell before the first landing is shown mercy: their kit stake is
## drawn from the stakes tagged for it. Everything a stake changes is for this run only: the
## rail's stones are copies of the vault's, and only the haul and the bag come home.
##
## A boon is written as effects with a small vocabulary of their own (they act on the run,
## not on a hand), and says what it `needs` from the player: a socket in the rail, or a
## pick from candidates rolled when the offer is made so the player sees what is on offer.

const GROUPS: Array = ["stone", "kit", "cost", "reward", "long_shot"]
const NEEDS: Array = ["", "socket", "pick"]
const EFFECT_KINDS: Array = ["cut_step", "carat", "inclusion", "raw_stone", "pick_stone", "pick_die", "die", "max_hp_pct", "hp_pct",
	"ore", "loupes", "soft_rock", "extra_rerolls", "geode", "roll_ore", "coin_hp"]
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
			"cut_step", "carat", "max_hp_pct", "hp_pct", "ore", "loupes", "coin_hp":
				if not (effect.get("amount", null) is int or effect.get("amount", null) is float):
					errors.append(where + ": needs an amount")
			"inclusion":
				if not str(effect.get("class", "")) in DeepContent.INCLUSION_CLASSES:
					errors.append(where + ": unknown inclusion class " + str(effect.get("class", "")))
			"pick_stone", "pick_die":
				if int(effect.get("count", 0)) < 1:
					errors.append(where + ": needs a count")
				if str(def.get("needs", "")) != "pick":
					errors.append(where + ": a pick needs the player to pick")
				if effect.has("min_tier") and not str(effect.min_tier) in DeepStone.TIERS:
					errors.append(where + ": unknown tier " + str(effect.min_tier))
			"die":
				if not p.get("dice", {}).has(str(effect.get("key", ""))):
					errors.append(where + ": unknown die " + str(effect.get("key", "")))
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
				"pick_die":
					out.pick_kind = "die"
					var seen: Array = []
					for _i in range(int(effect.get("count", 3))):
						var die: Dictionary = DeepForge.roll_die(rng, mine, int(effect.get("depth", 4)), "%s_%s_%d" % [str(unit.id), str(key), out.picks.size()])
						var tries: int = 0
						while seen.has(str(die.key)) and tries < PICK_TRIES:
							tries += 1
							die = DeepForge.roll_die(rng, mine, int(effect.get("depth", 4)), str(die.id))
						seen.append(str(die.key))
						out.picks.append(die)
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
	## Resolve one player's stake. Returns {ok, error, message, made: [stones], dice: [dice]}.
	var out: Dictionary = {"ok": true, "error": "", "message": "", "made": [], "dice": []}
	var socket: int = int(payload.get("socket", -1))
	var pick: int = int(payload.get("pick", -1))
	if chosen.get("needs", []).has("socket"):
		if socket < 0 or socket >= unit.get("rail", []).size() or not unit.rail[socket] is Dictionary:
			return _refuse("choose a socket with a stone in it")
	if chosen.get("needs", []).has("pick"):
		if pick < 0 or pick >= chosen.get("picks", []).size():
			return _refuse("choose one of the three")
	var lines: Array = []
	for key in chosen.get("boons", []):
		var def: Dictionary = DeepContent.boon(str(key))
		for effect in def.get("effects", []):
			var said: String = _effect(state, unit, effect, chosen, socket, pick, rng, out)
			if not said.is_empty():
				lines.append(said)
	out.message = " ".join(lines)
	return out

static func _effect(state: Dictionary, unit: Dictionary, effect: Dictionary, chosen: Dictionary, socket: int, pick: int, rng: RandomNumberGenerator, out: Dictionary) -> String:
	var kind: String = str(effect.get("kind", ""))
	var mine: Dictionary = DeepDescent.mine_of(state)
	var amount: int = int(effect.get("amount", 0))
	match kind:
		"cut_step":
			var stone: Dictionary = unit.rail[socket]
			stone.cut = clampi(int(stone.get("cut", 0)) + amount, 0, DeepPatterns.STEPS - 1)
			return "%s is now judged %s." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), DeepContent.cut_name(int(stone.cut))]
		"carat":
			var stone: Dictionary = unit.rail[socket]
			stone.carat = clampi(int(stone.get("carat", 1)) + amount, 1, DeepStone.carat_max())
			return "%s weighs %d carats now." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), int(stone.carat)]
		"inclusion":
			var stone: Dictionary = unit.rail[socket]
			var rolled: Array = DeepForge.roll_inclusions(rng, 1, mine, str(effect.get("class", "PINPOINT")))
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
			return "A %s goes into your haul, unappraised." % DeepStone.raw_name(stone)
		"pick_stone":
			var stone: Dictionary = chosen.picks[pick].duplicate(true)
			stone.provenance.finder = str(unit.id)
			unit.haul.append(stone)
			out.made.append(stone)
			return "You take the %s." % DeepStone.name(stone)
		"pick_die":
			var die: Dictionary = chosen.picks[pick].duplicate(true)
			unit.bag_dice.append(die)
			out.dice.append(die)
			return "A %s goes into your bag." % DeepDice.describe(die)
		"die":
			var die: Dictionary = DeepDice.make(str(effect.get("key", "D6")), DeepContent.die(str(effect.get("key", "D6"))), "%s_stakedie%08x" % [str(unit.id), rng.randi()])
			unit.bag_dice.append(die)
			out.dice.append(die)
			return "A %s goes into your bag." % DeepDice.describe(die)
		"max_hp_pct":
			return _max_hp(unit, amount)
		"hp_pct":
			var loss: int = int(floor(float(unit.get("hp", 0)) * float(absi(amount)) / 100.0))
			unit.hp = maxi(1, int(unit.get("hp", 0)) - loss)
			return "You start %d health down." % loss
		"ore":
			unit.ore = maxi(0, int(unit.get("ore", 0)) + amount)
			return ("You take %d ore." % amount) if amount >= 0 else ("You give up %d ore." % -amount)
		"loupes":
			var before: int = int(unit.get("loupes", 0))
			unit.loupes = maxi(0, before + amount)
			return ("You pocket %d loupes." % amount) if amount >= 0 else ("Your %d loupes stay on the bench." % before)
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
