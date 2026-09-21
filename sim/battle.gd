class_name DeepBattle
extends RefCounted
## A fight, one step at a time.
##
## The host owns a battle state and drives it with three calls: `command()` while players
## plan, `start_resolution()` once every living player has locked, then `step()` until the
## turn ends. Every step resolves exactly one thing (one gem, one creature move, one round of
## poison) and returns the event that describes it, so a screen animates what just happened
## against the state as it now is. Nothing here touches the scene tree and nothing here
## reads content by name: skills, inclusions and creatures come through their data.
##
## Player units carry their rail (stones by socket), their dice and hand, and the rail
## context that gems pass to each other: Resonance, what the previous gem did, a pending
## Cut step or amplifier. After the last socket the character's Birthstone resolves: a fixed
## stone with tiers, every satisfied tier firing on the Resonance the rail built. Enemy
## units carry published intents. Both sides share one damage pipeline.

const BASE_DURATION: Dictionary = {"turn_begin": 0.8, "resolution_begin": 0.4, "rail_begin": 0.3, "gem_fire": 0.9,
	"gem_fizzle": 0.5, "birthstone": 1.1, "rail_end": 0.3, "skip": 0.6, "enemy_move": 0.9, "tick": 0.6, "battle_over": 1.2}
const HAND_KINDS: Array = ["raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high"]
const SELF_KINDS: Array = ["amplify_next", "cut_step_next", "grant_reroll", "retrigger_previous", "quality_bonus", "sparkle",
	"coin_flip", "resonance"]
const BIRTHSTONE_KINDS: Array = ["replay_rail", "tick_poison", "stone_drop"]

# --- setup -------------------------------------------------------------------------------

static func make_player(id: String, name: String, character_key: String, rail: Array, dice: Array, hp: int = -1) -> Dictionary:
	## A player unit for a fight. `rail` is stones by socket (null for empty), `dice` five
	## die instances. HP, sockets, passive and Birthstone come from the character.
	var character: Dictionary = DeepContent.character(character_key)
	var sockets: Array = character.get("sockets", ["ANY"]).duplicate()
	var filled: Array = rail.duplicate(true)
	while filled.size() < sockets.size():
		filled.append(null)
	if filled.size() > sockets.size():
		filled = filled.slice(0, sockets.size())
	var max_hp: int = int(character.get("hp", 60))
	return {"id": id, "name": name, "side": "player", "character": character_key, "sockets": sockets, "rail": filled,
		"birthstone": character.get("birthstone", {}).duplicate(true), "flips": 0, "fired_sockets": [], "replaying": false, "stone_drops": 0,
		"hp": hp if hp >= 0 else max_hp, "max_hp": max_hp, "block": 0, "statuses": {}, "dice": dice.duplicate(true), "hand": [],
		"rerolls": 0, "rerolls_max": 0, "locked": false, "target": "", "passive": character.get("passive", {"kind": "none"}),
		"resonance": 0, "previous_fired": false, "previous_amount": 0, "previous_colours": [], "previous_socket": -1,
		"amplify": 1.0, "cut_step_bonus": 0, "nullify_next": false, "block_lost": 0, "block_lost_accum": 0,
		"healed": 0, "dealt": 0, "dealt_last_turn": 0, "gold": 0, "once": {}, "downed": false, "connected": true,
		"eligible_turn": 1, "buried": [], "clouded": [], "stolen_dice": 0, "granted_rerolls": 0, "sparkle": 0,
		"quality_bonus": 0, "fizzle_free": 0, "run_mods": {}, "skipped_turn": -1}

static func begin(players: Array, creature_keys: Array, context: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	var state: Dictionary = {"turn": 0, "phase": "planning", "outcome": "", "depth": int(context.get("depth", 1)),
		"party": players.size(), "elite": bool(context.get("elite", false)), "warden": bool(context.get("warden", false)),
		"players": players.duplicate(true), "enemies": [], "queue": [], "seq": 0}
	var index: int = 0
	for key in creature_keys:
		state.enemies.append(DeepCreatures.make(str(key), "e%d" % index, state.depth, players.size()))
		index += 1
	_begin_turn(state, rng_dice, rng_creatures)
	return state

# --- planning ----------------------------------------------------------------------------

static func player(state: Dictionary, id: String) -> Dictionary:
	for unit in state.get("players", []):
		if str(unit.id) == id:
			return unit
	return {}

static func enemy(state: Dictionary, id: String) -> Dictionary:
	for unit in state.get("enemies", []):
		if str(unit.id) == id:
			return unit
	return {}

static func living(units: Array) -> Array:
	return units.filter(func(u: Dictionary) -> bool: return int(u.get("hp", 0)) > 0 and not bool(u.get("downed", false)))

static func command(state: Dictionary, player_id: String, cmd: Dictionary, rng_dice: RandomNumberGenerator) -> Dictionary:
	## Rerolls, locking and targeting. Returns {ok, error, event}.
	if str(state.get("phase", "")) != "planning":
		return _refuse("the turn is already resolving")
	var unit: Dictionary = player(state, player_id)
	if unit.is_empty():
		return _refuse("no such player")
	if bool(unit.get("downed", false)):
		return _refuse("a downed player cannot act")
	var kind: String = str(cmd.get("kind", ""))
	match kind:
		"reroll":
			if bool(unit.get("locked", false)):
				return _refuse("you have locked in")
			if int(unit.get("rerolls", 0)) <= 0:
				return _refuse("no rerolls left")
			var wanted: Array = cmd.get("dice", []).map(func(d: Variant) -> String: return str(d))
			var allowed: Array = DeepDice.rerollable(unit.hand)
			var chosen: Array = wanted.filter(func(d: String) -> bool: return allowed.has(d))
			if chosen.is_empty():
				return _refuse("choose dice to reroll")
			unit.hand = DeepDice.reroll(unit.hand, unit.dice, chosen, rng_dice)
			unit.rerolls = int(unit.rerolls) - 1
			var loaded: Array = _loaded(unit, chosen, rng_dice)
			var drain: int = 0
			for foe in living(state.enemies):
				if str(foe.get("gimmick", "")) == "gift_rerolls":
					drain += 1
			if drain > 0:
				unit.hp = maxi(1, int(unit.hp) - drain)
			return {"ok": true, "event": _event(state, "reroll", {"unit": player_id, "dice": chosen, "hand": unit.hand.duplicate(true),
				"rerolls": unit.rerolls, "drain": drain, "loaded": loaded})}
		"flip":
			## The Harlequin's Sleight: one die turns to the other side of its range.
			if bool(unit.get("locked", false)):
				return _refuse("you have locked in")
			if int(unit.get("flips", 0)) <= 0:
				return _refuse("no flip left this turn")
			var wanted_id: String = str(cmd.get("die", ""))
			for roll in unit.hand:
				if str(roll.get("die_id", "")) != wanted_id or bool(roll.get("phantom", false)):
					continue
				if str(roll.get("kind", "plain")) != "plain":
					return _refuse("only a plain face can be flipped")
				var top: int = maxi(1, int(roll.get("top", 6)))
				roll.value = clampi(top + 1 - int(roll.get("value", 1)), 1, DeepDice.VALUE_CAP)
				roll.flipped = true
				unit.flips = int(unit.flips) - 1
				DeepDice.resolve_mirrors(unit.hand)
				return {"ok": true, "event": _event(state, "flip", {"unit": player_id, "die": wanted_id, "value": int(roll.value),
					"hand": unit.hand.duplicate(true), "flips": int(unit.flips)})}
			return _refuse("no such die")
		"lock":
			unit.locked = true
			return {"ok": true, "event": _event(state, "lock", {"unit": player_id})}
		"unlock":
			unit.locked = false
			return {"ok": true, "event": _event(state, "unlock", {"unit": player_id})}
		"target":
			var foe: Dictionary = enemy(state, str(cmd.get("enemy", "")))
			if foe.is_empty() or int(foe.hp) <= 0:
				return _refuse("no such creature")
			unit.target = str(foe.id)
			return {"ok": true, "event": _event(state, "target", {"unit": player_id, "enemy": unit.target})}
	return _refuse("unknown battle command " + kind)

static func ready_to_resolve(state: Dictionary) -> bool:
	if str(state.get("phase", "")) != "planning":
		return false
	for unit in state.get("players", []):
		if bool(unit.get("downed", false)) or not bool(unit.get("connected", true)):
			continue
		if not bool(unit.get("locked", false)):
			return false
	return true

static func force_lock(state: Dictionary) -> void:
	## A disconnected or slow player's hand is locked as it stands.
	for unit in state.get("players", []):
		unit.locked = true

# --- resolution --------------------------------------------------------------------------

static func start_resolution(state: Dictionary) -> Dictionary:
	if str(state.get("phase", "")) != "planning":
		return {}
	state.phase = "resolving"
	var queue: Array = []
	for unit in state.players:
		if bool(unit.get("downed", false)):
			continue
		if int(unit.get("eligible_turn", 1)) > int(state.turn):
			queue.append({"kind": "skip", "unit": unit.id, "why": "revived"})
			continue
		queue.append({"kind": "rail_begin", "unit": unit.id})
		for socket in range(unit.rail.size()):
			if unit.rail[socket] is Dictionary:
				queue.append({"kind": "gem", "unit": unit.id, "socket": socket})
		if not unit.get("birthstone", {}).is_empty():
			queue.append({"kind": "birthstone", "unit": unit.id})
		queue.append({"kind": "rail_end", "unit": unit.id})
	queue.append({"kind": "creatures_begin"})
	for foe in state.enemies:
		if int(foe.hp) <= 0:
			continue
		for index in range(foe.get("intents", []).size()):
			queue.append({"kind": "enemy_move", "unit": foe.id, "intent": index})
	queue.append({"kind": "tick"})
	queue.append({"kind": "turn_end"})
	state.queue = queue
	return _event(state, "resolution_begin", {})

static func done(state: Dictionary) -> bool:
	return str(state.get("phase", "")) == "over"

static func has_steps(state: Dictionary) -> bool:
	## True while `step()` still has something to say: the turn is resolving, or the fight
	## just ended and its closing event has not been sent.
	var phase: String = str(state.get("phase", ""))
	return phase == "resolving" or (phase == "over" and not bool(state.get("announced", false)))

static func step(state: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	## Resolve one thing and describe it. Returns an empty dictionary when there is nothing
	## to resolve (planning, or the fight is over).
	if str(state.get("phase", "")) == "over":
		## The blow that ended the fight carried a battle_over flag; this is the event that
		## closes the fight on its own, sent exactly once.
		if bool(state.get("announced", false)):
			return {}
		state.announced = true
		state.queue = []
		return _event(state, "battle_over", {"outcome": str(state.outcome), "turns": int(state.turn)})
	if str(state.get("phase", "")) != "resolving":
		return {}
	while not state.queue.is_empty():
		var s: Dictionary = state.queue.pop_front()
		var event: Dictionary = _perform(state, s, rng_dice, rng_creatures)
		if not event.is_empty():
			return event
	## The queue ran dry without a turn_end: close the turn anyway.
	return _end_turn(state, rng_dice, rng_creatures)

static func _perform(state: Dictionary, s: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	match str(s.kind):
		"skip":
			return _event(state, "skip", {"unit": s.unit, "why": str(s.get("why", "stun"))})
		"rail_begin":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty() or bool(unit.get("downed", false)):
				_drop_steps(state, str(s.unit))
				return {}
			if int(unit.statuses.get("stun", 0)) > 0:
				unit.statuses.stun = int(unit.statuses.stun) - 1
				_drop_steps(state, str(s.unit))
				return _event(state, "skip", {"unit": unit.id, "why": "stun"})
			unit.resonance = 0
			unit.previous_fired = false
			unit.previous_amount = 0
			unit.previous_colours = []
			unit.previous_socket = -1
			unit.amplify = 1.0
			unit.nullify_next = false
			unit.cut_step_bonus = 0
			unit.fizzle_free = 1 if str(unit.get("passive", {}).get("kind", "")) == "first_fizzle_free" else 0
			unit.fired_sockets = []
			unit.replaying = false
			if str(unit.get("passive", {}).get("kind", "")) == "first_gem_cut_step":
				unit.cut_step_bonus = int(unit.passive.get("amount", 1))
			## Second Wind: the Knight banks the rerolls he did not spend.
			var unused: int = int(unit.get("rerolls", 0))
			var healed: int = 0
			if str(unit.get("passive", {}).get("kind", "")) == "heal_per_unused_reroll" and unused > 0:
				healed = _heal(unit, int(unit.passive.get("amount", 3)) * unused)
			return _event(state, "rail_begin", {"unit": unit.id, "unused_rerolls": unused, "healed": healed})
		"gem":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty() or bool(unit.get("downed", false)) or done(state):
				return {}
			return resolve_gem(state, unit, int(s.socket), {"retrigger": bool(s.get("retrigger", false)), "scale": int(s.get("scale", 100)),
				"replay": bool(s.get("replay", false))}, rng_dice)
		"birthstone":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty() or bool(unit.get("downed", false)) or done(state):
				return {}
			return resolve_birthstone(state, unit, {"replay": bool(s.get("replay", false))}, rng_dice)
		"rail_end":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty():
				return {}
			return _event(state, "rail_end", {"unit": unit.id, "resonance": int(unit.get("resonance", 0))})
		"creatures_begin":
			## A creature's block has stood through one volley of gems; whatever is left of it
			## falls away as the creatures take their turn.
			for foe in state.enemies:
				foe.block = 0
			return {}
		"enemy_move":
			var foe: Dictionary = enemy(state, str(s.unit))
			if foe.is_empty() or int(foe.hp) <= 0 or done(state):
				return {}
			if int(foe.statuses.get("stun", 0)) > 0:
				foe.statuses.stun = int(foe.statuses.stun) - 1
				if bool(foe.get("warden", false)):
					foe.statuses.resolve = 2
				_drop_steps(state, str(s.unit))
				return _event(state, "skip", {"unit": foe.id, "why": "stun"})
			var intents: Array = foe.get("intents", [])
			var index: int = int(s.intent)
			if index >= intents.size():
				return {}
			return _enemy_act(state, foe, intents[index], rng_dice)
		"tick":
			return _tick(state)
		"turn_end":
			return _end_turn(state, rng_dice, rng_creatures)
	return {}

static func _drop_steps(state: Dictionary, unit_id: String) -> void:
	state.queue = state.queue.filter(func(q: Dictionary) -> bool: return str(q.get("unit", "")) != unit_id)

# --- gems --------------------------------------------------------------------------------

static func rail_context(state: Dictionary, unit: Dictionary, socket: int, opts: Dictionary = {}) -> Dictionary:
	## What the rail hands a gem at this socket: the bonuses its neighbours and the run give
	## it, and what the previous gem did.
	var stone: Dictionary = unit.rail[socket]
	var socket_colour: String = str(unit.sockets[socket]) if socket < unit.sockets.size() else "ANY"
	var carat_bonus: int = 0
	for neighbour in [socket - 1, socket + 1]:
		if neighbour < 0 or neighbour >= unit.rail.size() or not unit.rail[neighbour] is Dictionary:
			continue
		var other: Dictionary = unit.rail[neighbour]
		for m in DeepStone.modifiers(other):
			if str(m.get("kind", "")) != "adjacent_carat":
				continue
			var shared: bool = true
			if bool(m.get("same_colour", false)):
				shared = false
				for colour in DeepStone.colours(other, str(unit.sockets[neighbour])):
					if DeepStone.colours(stone, socket_colour).has(colour):
						shared = true
			if shared:
				carat_bonus += int(m.get("amount", 1))
	var shrine: String = str(unit.get("run_mods", {}).get("shrine", ""))
	if not shrine.is_empty() and str(DeepStone.skill_of(stone).get("trigger", {}).get("kind", "")) == shrine:
		carat_bonus += 1
	return {"unit": unit, "resonance": int(unit.get("resonance", 0)), "previous_fired": bool(unit.get("previous_fired", false)),
		"previous_amount": int(unit.get("previous_amount", 0)), "amplify": float(unit.get("amplify", 1.0)),
		"cut_step_bonus": int(unit.get("cut_step_bonus", 0)), "carat_bonus": carat_bonus, "depth": int(state.get("depth", 1)),
		"turn": int(state.get("turn", 1)), "party": int(state.get("party", 1)), "socket": socket_colour,
		"retrigger": bool(opts.get("retrigger", false))}

static func resolve_gem(state: Dictionary, unit: Dictionary, socket: int, opts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## One gem fires or fizzles. `opts.retrigger` marks a repeat, `opts.scale` a percentage
	## an Echo repeats at, `opts.dry` a forecast that must not roll coins or queue repeats.
	var dry: bool = bool(opts.get("dry", false))
	if socket < 0 or socket >= unit.rail.size() or not unit.rail[socket] is Dictionary:
		return {}
	var stone: Dictionary = unit.rail[socket]
	if unit.buried.has(socket) or unit.clouded.has(socket):
		unit.previous_fired = false
		return _event(state, "gem_fizzle", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
			"reason": "The socket is buried." if unit.buried.has(socket) else "The socket is clouded.", "resonance": unit.resonance, "blocked": true})
	var context: Dictionary = rail_context(state, unit, socket, opts)
	var ev: Dictionary = DeepStone.evaluate(stone, unit.hand, context)
	var nullified: bool = bool(unit.get("nullify_next", false))
	unit.amplify = 1.0
	unit.cut_step_bonus = 0
	unit.nullify_next = false
	var retrigger: bool = bool(opts.get("retrigger", false))
	if nullified and not retrigger:
		ev.active = false
		ev.reason = "Double Down came up empty."
	if not ev.active:
		if int(unit.get("fizzle_free", 0)) > 0:
			unit.fizzle_free = int(unit.fizzle_free) - 1
		elif not bool(ev.get("no_reset", false)):
			unit.resonance = 0
		var healed: int = 0
		if str(unit.get("passive", {}).get("kind", "")) == "heal_on_fizzle" and not bool(unit.get("downed", false)):
			healed = _heal(unit, int(unit.passive.get("amount", 2)))
		unit.previous_fired = false
		unit.previous_amount = 0
		unit.previous_colours = []
		return _event(state, "gem_fizzle", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
			"reason": str(ev.get("reason", "")), "resonance": unit.resonance, "dice": ev.get("dice", []), "healed": healed,
			"cut_step": int(ev.get("cut_step", 0))})
	## It fires.
	var scale: int = int(opts.get("scale", 100))
	var hp_cost: int = int(ev.get("hp_cost", 0))
	if hp_cost > 0:
		unit.hp = maxi(1, int(unit.hp) - hp_cost)
	var harmony: bool = false
	if bool(unit.get("previous_fired", false)):
		for colour in unit.get("previous_colours", []):
			if ev.get("colours", []).has(colour):
				harmony = true
	var gain: int = int(ev.get("resonance_gain", 1)) + (1 if harmony else 0)
	unit.resonance = int(unit.get("resonance", 0)) + gain
	var results: Array = []
	var previous_socket: int = int(unit.get("previous_socket", -1))
	for effect in ev.get("effects", []):
		var applied: Dictionary = effect.duplicate(true)
		if scale != 100 and bool(effect.get("scaled", false)):
			applied.amount = int(floor(float(int(effect.amount)) * float(scale) / 100.0))
		if bool(effect.get("once", false)):
			if unit.once.has(str(stone.id)):
				## Lifeline's second try: the party is healed half of it instead.
				applied.kind = "heal"
				applied.target = "allies"
				applied.amount = int(applied.amount) / 2
			else:
				unit.once[str(stone.id)] = true
		var kind: String = str(applied.kind)
		if kind in HAND_KINDS:
			results.append(_mutate_hand(unit, applied))
		elif kind in SELF_KINDS:
			results.append(_self_effect(state, unit, applied, previous_socket, dry, rng))
		else:
			results.append_array(_apply(state, unit, applied, rng))
		if done(state):
			break
	if int(ev.get("next_cut_step", 0)) > 0:
		unit.cut_step_bonus = int(unit.cut_step_bonus) + int(ev.next_cut_step)
	unit.previous_fired = true
	unit.previous_amount = DeepStone.total_amount(ev)
	unit.previous_colours = ev.get("colours", [])
	unit.previous_socket = socket
	if not unit.get("fired_sockets", []).has(socket):
		unit.fired_sockets.append(socket)
	if not dry and not retrigger and int(ev.get("fires", 1)) > 1:
		for _extra in range(int(ev.fires) - 1):
			state.queue.push_front({"kind": "gem", "unit": unit.id, "socket": socket, "retrigger": true})
	_check_outcome(state)
	return _event(state, "gem_fire", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
		"dice": ev.get("dice", []), "effects": results, "resonance": unit.resonance, "gain": gain, "harmony": harmony,
		"magnitude": float(ev.get("magnitude", 1.0)), "carat": int(ev.get("carat", 1)), "cut_step": int(ev.get("cut_step", 0)),
		"retrigger": retrigger, "replay": bool(opts.get("replay", false)), "scale": scale, "hp_cost": hp_cost, "fires": int(ev.get("fires", 1)),
		"duration": BASE_DURATION.gem_fire + 0.15 * results.size()})

# --- the Birthstone ----------------------------------------------------------------------

static func resolve_birthstone(state: Dictionary, unit: Dictionary, opts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## The character's own stone, last in the rail. Every tier the final hand satisfies fires
	## on the Resonance the rail delivered, unless a tier marked exclusive fires and takes the
	## others' place. Tiers do not add Resonance themselves. `opts.replay` is Encore's second
	## pass, on which the tier that asked for the replay stays dark. `opts.dry` is a forecast.
	var def: Dictionary = unit.get("birthstone", {})
	if def.is_empty():
		return {}
	var dry: bool = bool(opts.get("dry", false))
	var replay: bool = bool(opts.get("replay", false))
	var a: Dictionary = DeepHand.analyze(unit.hand)
	var resonance: int = int(unit.get("resonance", 0))
	var defs: Array = def.get("tiers", [])
	var evaluated: Array = []
	var exclusive_hit: int = -1
	for index in range(defs.size()):
		var tier: Dictionary = defs[index]
		var trig: Dictionary = DeepPatterns.evaluate(tier.get("trigger", {"kind": "always"}), 0, a, {"resonance": resonance})
		if replay and trig.active and _has_effect(tier, "replay_rail"):
			trig.active = false
			trig.reason = "Once a turn."
		if trig.active and bool(tier.get("exclusive", false)) and exclusive_hit < 0:
			exclusive_hit = index
		evaluated.append(trig)
	var tiers: Array = []
	var fired: bool = false
	var all_dice: Array = []
	for index in range(defs.size()):
		var tier: Dictionary = defs[index]
		var trig: Dictionary = evaluated[index]
		var entry: Dictionary = {"name": str(tier.get("name", "")), "active": bool(trig.active), "dice": trig.get("dice", []),
			"reason": str(trig.get("reason", "")), "effects": [], "trigger": DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0)}
		if exclusive_hit >= 0 and index != exclusive_hit and entry.active:
			entry.active = false
			entry.eclipsed = true
			entry.reason = "%s takes its place." % str(defs[exclusive_hit].get("name", ""))
		if entry.active:
			fired = true
			for id in entry.dice:
				if not all_dice.has(id):
					all_dice.append(id)
			var tc: Dictionary = {"a": a, "trig": trig, "unit": unit, "resonance": resonance, "previous_amount": int(unit.get("previous_amount", 0)),
				"depth": int(state.get("depth", 0)), "turn": int(state.get("turn", 0)), "party": int(state.get("party", 1))}
			var results: Array = []
			for effect_def in tier.get("effects", []):
				if not effect_def is Dictionary:
					continue
				var applied: Dictionary = DeepRules.resolve_effect(effect_def, tc, 1.0)
				var kind: String = str(applied.kind)
				if kind in HAND_KINDS:
					results.append(_mutate_hand(unit, applied))
				elif kind in SELF_KINDS:
					results.append(_self_effect(state, unit, applied, -1, dry, rng))
				elif kind in BIRTHSTONE_KINDS:
					results.append(_birthstone_effect(state, unit, applied, dry, replay))
				else:
					results.append_array(_apply(state, unit, applied, rng))
				if done(state):
					break
			entry.effects = results
		tiers.append(entry)
		if done(state):
			break
	_check_outcome(state)
	return _event(state, "birthstone", {"unit": unit.id, "name": str(def.get("name", "Birthstone")), "style": str(def.get("style", "")),
		"tiers": tiers, "fired": fired, "dice": all_dice, "resonance": resonance, "replay": replay,
		"duration": BASE_DURATION.birthstone + 0.2 * tiers.filter(func(x: Dictionary) -> bool: return bool(x.active)).size()})

static func _has_effect(tier: Dictionary, kind: String) -> bool:
	for effect in tier.get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == kind:
			return true
	return false

static func _birthstone_effect(state: Dictionary, unit: Dictionary, effect: Dictionary, dry: bool, replay: bool) -> Dictionary:
	var kind: String = str(effect.kind)
	var amount: int = int(effect.amount)
	var out: Dictionary = {"kind": kind, "amount": amount, "target": unit.id}
	match kind:
		"replay_rail":
			## Encore: every gem that fired plays again, in order, then the Birthstone once more.
			var sockets: Array = unit.get("fired_sockets", []).duplicate()
			sockets.sort()
			out.sockets = sockets
			if dry or replay or bool(unit.get("replaying", false)) or sockets.is_empty():
				out.nothing = true
			else:
				unit.replaying = true
				var again: Array = []
				for socket in sockets:
					again.append({"kind": "gem", "unit": unit.id, "socket": int(socket), "retrigger": true, "replay": true})
				again.append({"kind": "birthstone", "unit": unit.id, "replay": true})
				state.queue = again + state.queue
		"tick_poison":
			var ticks: Array = []
			for foe in living(state.enemies):
				for _time in range(maxi(0, amount)):
					if int(foe.statuses.get("poison", 0)) <= 0 or int(foe.hp) <= 0:
						break
					var tick: Dictionary = _poison_tick(state, foe)
					if not tick.is_empty():
						ticks.append(tick)
			out.ticks = ticks
			_check_outcome(state)
		"stone_drop":
			if not dry:
				unit.stone_drops = int(unit.get("stone_drops", 0)) + amount
			out.stone_drops = int(unit.get("stone_drops", 0))
	return out

static func _loaded(unit: Dictionary, ids: Array, rng: RandomNumberGenerator) -> Array:
	## The Gambler's Loaded dice: any die that lands on a 1 is thrown once more, free. `ids`
	## limits it to the dice just thrown; empty means the whole hand. Returns the dice re-thrown.
	if str(unit.get("passive", {}).get("kind", "")) != "free_reroll_value":
		return []
	var unlucky: int = int(unit.passive.get("amount", 1))
	var by_id: Dictionary = {}
	for die in unit.dice:
		by_id[str(die.get("id", ""))] = die
	var thrown: Array = []
	for index in range(unit.hand.size()):
		var roll: Dictionary = unit.hand[index]
		var id: String = str(roll.get("die_id", ""))
		if bool(roll.get("phantom", false)) or (not ids.is_empty() and not ids.has(id)) or not by_id.has(id):
			continue
		if str(roll.get("kind", "plain")) != "plain" or int(roll.get("value", 0)) != unlucky:
			continue
		var again: Dictionary = DeepDice.roll_one(by_id[id], rng, int(roll.get("rerolls", 0)))
		again.held = bool(roll.get("held", false))
		again.loaded = true
		unit.hand[index] = again
		thrown.append(id)
	if not thrown.is_empty():
		DeepDice.resolve_mirrors(unit.hand)
	return thrown

static func _mutate_hand(unit: Dictionary, effect: Dictionary) -> Dictionary:
	## White gems change the hand every gem after them reads.
	var hand: Array = unit.hand
	var amount: int = int(effect.amount)
	var kind: String = str(effect.kind)
	var changed: Array = []
	var real: Array = hand.filter(func(r: Dictionary) -> bool: return not str(r.get("kind", "plain")) in ["wild", "blank"] and not bool(r.get("phantom", false)))
	var high: int = 0
	for roll in real:
		high = maxi(high, int(roll.value))
	match kind:
		"raise_low":
			var lowest: Dictionary = _extreme(real, true)
			if not lowest.is_empty():
				lowest.value = mini(int(lowest.value) + amount, maxi(high, int(lowest.get("top", DeepDice.VALUE_CAP))) if amount >= 99 else mini(int(lowest.value) + amount, DeepDice.VALUE_CAP))
				changed.append(str(lowest.die_id))
		"raise_high":
			var highest: Dictionary = _extreme(real, false)
			if not highest.is_empty():
				highest.value = mini(int(highest.value) + amount, DeepDice.VALUE_CAP)
				changed.append(str(highest.die_id))
		"set_match":
			for _i in range(amount):
				var a: Dictionary = DeepHand.analyze(hand)
				var best: Dictionary = a.get("best_set", {})
				var target_value: int = int(best.get("value", high))
				var candidate: Dictionary = {}
				for roll in real:
					if best.get("dice", []).has(str(roll.die_id)) or changed.has(str(roll.die_id)):
						continue
					if candidate.is_empty() or int(roll.value) < int(candidate.value):
						candidate = roll
				if candidate.is_empty():
					break
				candidate.value = target_value
				changed.append(str(candidate.die_id))
		"flip_low", "flip_high":
			var sorted: Array = real.duplicate()
			sorted.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.value) < int(y.value) if kind == "flip_low" else int(x.value) > int(y.value))
			for index in range(mini(amount, sorted.size())):
				var roll: Dictionary = sorted[index]
				roll.value = clampi(int(roll.get("top", 6)) + 1 - int(roll.value), 1, DeepDice.VALUE_CAP)
				changed.append(str(roll.die_id))
		"phantom_high":
			var highest: Dictionary = _extreme(real, false)
			if not highest.is_empty():
				for index in range(amount):
					var ghost: Dictionary = DeepDice.phantom(highest, "%s_ph%d_%d" % [str(highest.die_id), hand.size(), index])
					hand.append(ghost)
					changed.append(str(ghost.die_id))
	return {"kind": kind, "amount": amount, "dice": changed, "hand": hand.duplicate(true)}

static func _extreme(rolls: Array, lowest: bool) -> Dictionary:
	var found: Dictionary = {}
	for roll in rolls:
		if found.is_empty() or (int(roll.value) < int(found.value) if lowest else int(roll.value) > int(found.value)):
			found = roll
	return found

static func _self_effect(state: Dictionary, unit: Dictionary, effect: Dictionary, previous_socket: int, dry: bool, rng: RandomNumberGenerator) -> Dictionary:
	var kind: String = str(effect.kind)
	var amount: int = int(effect.amount)
	var out: Dictionary = {"kind": kind, "amount": amount, "target": unit.id}
	match kind:
		"amplify_next":
			unit.amplify = float(unit.amplify) * (1.0 + float(amount) / 100.0)
		"cut_step_next":
			unit.cut_step_bonus = int(unit.cut_step_bonus) + amount
		"grant_reroll":
			unit.granted_rerolls = int(unit.get("granted_rerolls", 0)) + amount
		"quality_bonus":
			unit.quality_bonus = int(unit.get("quality_bonus", 0)) + amount
		"sparkle":
			unit.sparkle = int(unit.get("sparkle", 0)) + amount
		"resonance":
			unit.resonance = int(unit.resonance) + amount
		"coin_flip":
			var won: bool = true if dry else DeepRng.chance(rng, float(amount))
			out.won = won
			var mult: float = float(effect.get("win_mult", 2)) if won else float(effect.get("lose_mult", 0))
			if mult <= 0.0:
				unit.nullify_next = true
			else:
				unit.amplify = float(unit.amplify) * mult
		"retrigger_previous":
			if previous_socket >= 0 and not dry:
				state.queue.push_front({"kind": "gem", "unit": unit.id, "socket": previous_socket, "retrigger": true, "scale": amount})
				out.socket = previous_socket
			elif previous_socket < 0:
				out.nothing = true
	return out

# --- the shared effect pipeline -------------------------------------------------------------

static func _targets(state: Dictionary, source: Dictionary, target: String, intent_target: String = "") -> Array:
	var is_player: bool = str(source.get("side", "player")) == "player"
	var friends: Array = living(state.players) if is_player else living(state.enemies)
	var foes: Array = living(state.enemies) if is_player else living(state.players)
	match target:
		"self":
			return [source]
		"allies":
			return friends
		"heroes":
			return foes if not is_player else friends
		"ally_low":
			var lowest: Dictionary = source
			for unit in friends:
				if float(unit.hp) / float(maxi(1, int(unit.max_hp))) < float(lowest.hp) / float(maxi(1, int(lowest.max_hp))):
					lowest = unit
			return [lowest]
		"enemy", "hero":
			var chosen: Dictionary = enemy(state, str(source.get("target", ""))) if is_player else player(state, intent_target)
			if chosen.is_empty() or int(chosen.hp) <= 0 or bool(chosen.get("downed", false)):
				chosen = foes[0] if not foes.is_empty() else {}
			return [chosen] if not chosen.is_empty() else []
		"enemies":
			return foes
		"enemy_behind":
			var chosen: Dictionary = enemy(state, str(source.get("target", "")))
			if chosen.is_empty() or int(chosen.hp) <= 0:
				chosen = foes[0] if not foes.is_empty() else {}
			var index: int = foes.find(chosen)
			return [foes[index + 1]] if index >= 0 and index + 1 < foes.size() else []
		"downed_ally":
			for unit in state.players:
				if bool(unit.get("downed", false)):
					return [unit]
			return []
	return []

static func _apply(state: Dictionary, source: Dictionary, effect: Dictionary, rng: RandomNumberGenerator, intent_target: String = "") -> Array:
	var kind: String = str(effect.kind)
	var repeat: int = maxi(1, int(effect.get("repeat", 1)))
	var results: Array = []
	var target_kind: String = str(effect.target)
	if kind == "revive":
		var downed: Array = _targets(state, source, "downed_ally")
		if downed.is_empty():
			## Nobody to raise: the party is healed half of it instead.
			var fallback: Dictionary = effect.duplicate(true)
			fallback.kind = "heal"
			fallback.target = "allies"
			fallback.amount = int(effect.amount) / 2
			return _apply(state, source, fallback, rng, intent_target)
	for count in range(repeat):
		var targets: Array = []
		if target_kind == "spread":
			var foes: Array = _targets(state, source, "enemies")
			if not foes.is_empty():
				targets = [foes[count % foes.size()]]
		else:
			targets = _targets(state, source, target_kind, intent_target)
		for target in targets:
			results.append(_apply_one(state, source, target, kind, int(effect.amount), effect, rng))
			if done(state):
				return results
	return results

static func _apply_one(state: Dictionary, source: Dictionary, target: Dictionary, kind: String, amount: int, effect: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"kind": kind, "target": str(target.id), "amount": amount}
	match kind:
		"damage":
			out.merge(_damage(state, source, target, amount, rng), true)
			var splash: int = int(effect.get("splash", 0))
			if splash > 0 and str(target.get("side", "")) == "enemy":
				var foes: Array = living(state.enemies)
				var index: int = foes.find(target)
				var splashed: Array = []
				for neighbour in [index - 1, index + 1]:
					if neighbour >= 0 and neighbour < foes.size():
						var hit: Dictionary = _damage(state, source, foes[neighbour], int(floor(float(amount) * float(splash) / 100.0)), rng)
						hit.target = str(foes[neighbour].id)
						splashed.append(hit)
				out.splash = splashed
		"block":
			target.block = int(target.block) + amount
			out.block_after = target.block
		"heal":
			out.healed = _heal(target, amount)
			out.hp_after = target.hp
			if str(source.get("side", "")) == "player":
				source.healed = int(source.get("healed", 0)) + int(out.healed)
		"gold":
			if str(source.get("side", "")) == "player":
				source.gold = int(source.get("gold", 0)) + amount
				out.gold_after = source.gold
		"poison":
			if str(target.get("gimmick", "")) == "poison_immune":
				out.immune = true
			else:
				target.statuses.poison = int(target.statuses.get("poison", 0)) + amount
				out.poison_after = target.statuses.poison
		"stun":
			if bool(target.get("warden", false)) and int(target.statuses.get("resolve", 0)) > 0:
				out.resisted = true
			else:
				target.statuses.stun = int(target.statuses.get("stun", 0)) + amount
				out.stun_after = target.statuses.stun
		"remove_block":
			var removed: int = mini(int(target.block), amount)
			target.block = int(target.block) - removed
			out.removed = removed
			out.block_after = target.block
		"cleanse":
			var cleared: int = 0
			for status in ["poison", "stun", "curse"]:
				while cleared < amount and int(target.statuses.get(status, 0)) > 0:
					target.statuses[status] = int(target.statuses[status]) - 1
					cleared += 1
			out.cleared = cleared
		"revive":
			target.downed = false
			target.hp = clampi(amount, 1, int(target.max_hp))
			target.block = 0
			target.statuses = {}
			target.eligible_turn = int(state.turn) + 1
			out.hp_after = target.hp
		"curse":
			target.statuses.curse = int(target.statuses.get("curse", 0)) + amount
			out.curse_after = target.statuses.curse
		"intent_downgrade":
			target.downgrade = int(target.get("downgrade", 0)) + amount
		"die_steal":
			target.stolen_dice = int(target.get("stolen_dice", 0)) + amount
	return out

static func _damage(state: Dictionary, source: Dictionary, target: Dictionary, amount: int, rng: RandomNumberGenerator) -> Dictionary:
	var raw: int = maxi(0, amount)
	var curse: int = int(target.statuses.get("curse", 0))
	if curse > 0:
		raw = int(floor(float(raw) * (1.0 + float(curse) / 100.0)))
	if str(source.get("side", "")) == "enemy":
		var enrage_turn: int = int(DeepContent.constant("enrage_turn", 7))
		if int(state.turn) >= enrage_turn:
			raw += int(DeepContent.constant("enrage_damage", 2)) * (int(state.turn) - enrage_turn + 1)
	var absorbed: int = mini(int(target.block), raw)
	target.block = int(target.block) - absorbed
	var loss: int = mini(int(target.hp), raw - absorbed)
	target.hp = int(target.hp) - loss
	var out: Dictionary = {"raw": raw, "absorbed": absorbed, "hp_loss": loss, "hp_after": target.hp, "block_after": target.block}
	if str(target.get("side", "")) == "player":
		target.block_lost_accum = int(target.get("block_lost_accum", 0)) + absorbed
		if int(target.hp) <= 0:
			target.downed = true
			target.block = 0
			out.downed = true
		if str(source.get("gimmick", "")) == "steal_gold" and loss > 0:
			var stolen: int = mini(3, int(target.get("gold", 0)))
			target.gold = int(target.gold) - stolen
			source.stolen_gold = int(source.get("stolen_gold", 0)) + stolen
			out.stolen = stolen
	else:
		source.dealt = int(source.get("dealt", 0)) + loss
		if str(source.get("side", "")) == "player" and str(source.get("passive", {}).get("kind", "")) == "block_per_hit" and raw > 0:
			## Riposte: every hit the Rogue lands raises block worth her Resonance.
			var parry: int = int(source.get("resonance", 0))
			if parry > 0:
				source.block = int(source.block) + parry
				out.riposte = parry
		if str(target.get("gimmick", "")) == "cloud_socket" and loss > 0:
			for unit in state.players:
				unit.clouded = []
			out.uncloud = true
		if str(target.get("gimmick", "")) == "reflect_zero_resonance" and loss > 0 and int(source.get("resonance", 0)) <= 1 and str(source.get("side", "")) == "player":
			var back: int = loss / 2
			var absorbed_back: int = mini(int(source.block), back)
			source.block = int(source.block) - absorbed_back
			source.hp = maxi(0, int(source.hp) - (back - absorbed_back))
			if int(source.hp) <= 0:
				source.downed = true
			out.reflected = back
		if str(target.get("gimmick", "")) == "split_on_big_hit" and int(target.hp) > 0 and loss * 100 >= int(target.max_hp) * 40 and state.enemies.size() < 6:
			var half: int = maxi(1, int(target.hp) / 2)
			target.hp = half
			var twin: Dictionary = target.duplicate(true)
			twin.id = "%s_split%d" % [str(target.id), state.enemies.size()]
			twin.hp = half
			twin.max_hp = half
			twin.intents = []
			twin.statuses = {}
			state.enemies.insert(state.enemies.find(target) + 1, twin)
			out.split = twin.id
		if int(target.hp) <= 0:
			out.killed = true
			if int(target.get("stolen_gold", 0)) > 0 and str(source.get("side", "")) == "player":
				source.gold = int(source.get("gold", 0)) + int(target.stolen_gold)
				out.recovered_gold = int(target.stolen_gold)
				target.stolen_gold = 0
	_check_outcome(state)
	return out

static func _heal(target: Dictionary, amount: int) -> int:
	if bool(target.get("downed", false)) or int(target.hp) <= 0:
		return 0
	var before: int = int(target.hp)
	target.hp = mini(int(target.max_hp), before + maxi(0, amount))
	return int(target.hp) - before

# --- creatures ---------------------------------------------------------------------------

static func _enemy_act(state: Dictionary, foe: Dictionary, intent: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var results: Array = []
	for effect in intent.get("effects", []):
		var applied: Dictionary = effect.duplicate(true)
		if str(foe.get("gimmick", "")) == "mirror_last_gem" and str(applied.kind) == "damage":
			var victim: Dictionary = player(state, str(intent.get("target", "")))
			applied.amount = int(applied.amount) + int(victim.get("dealt_last_turn", 0)) / 2
		results.append_array(_apply(state, foe, applied, rng, str(intent.get("target", ""))))
		if done(state):
			break
	return _event(state, "enemy_move", {"unit": foe.id, "move": str(intent.get("move", "")), "target": str(intent.get("target", "")),
		"effects": results, "dice": foe.get("hand", []).map(func(r: Dictionary) -> int: return int(r.value))})

static func _poison_tick(state: Dictionary, unit: Dictionary) -> Dictionary:
	## One round of poison on one unit: it hurts for its stacks and loses one. When a creature
	## is the one bleeding, every Apothecary in the party drinks Resonance from it (Leech).
	var poison: int = int(unit.statuses.get("poison", 0))
	if poison <= 0 or int(unit.hp) <= 0:
		return {}
	var loss: int = mini(int(unit.hp), poison)
	unit.hp = int(unit.hp) - loss
	unit.statuses.poison = poison - 1
	var tick: Dictionary = {"unit": str(unit.id), "kind": "poison", "amount": loss, "hp_after": unit.hp, "remaining": unit.statuses.poison}
	if int(unit.hp) <= 0:
		if str(unit.get("side", "")) == "player":
			unit.downed = true
			unit.block = 0
		tick.killed = true
	if str(unit.get("side", "")) == "enemy" and loss > 0:
		var leeches: Array = []
		for drinker in living(state.players):
			if str(drinker.get("passive", {}).get("kind", "")) == "heal_on_poison_tick" and int(drinker.get("resonance", 0)) > 0:
				var healed: int = _heal(drinker, int(drinker.resonance))
				if healed > 0:
					leeches.append({"unit": str(drinker.id), "amount": healed, "hp_after": drinker.hp})
		if not leeches.is_empty():
			tick.leech = leeches
	return tick

static func _tick(state: Dictionary) -> Dictionary:
	var ticks: Array = []
	for unit in state.players + state.enemies:
		if int(unit.hp) <= 0 or bool(unit.get("downed", false)):
			continue
		var tick: Dictionary = _poison_tick(state, unit)
		if not tick.is_empty():
			ticks.append(tick)
		if str(unit.get("gimmick", "")) == "regrow" and int(unit.hp) > 0:
			var grown: int = _heal(unit, 3)
			if grown > 0:
				ticks.append({"unit": str(unit.id), "kind": "regrow", "amount": grown, "hp_after": unit.hp})
		unit.statuses.erase("curse")
		if int(unit.statuses.get("resolve", 0)) > 0:
			unit.statuses.resolve = int(unit.statuses.resolve) - 1
	_check_outcome(state)
	if ticks.is_empty():
		return {}
	return _event(state, "tick", {"ticks": ticks})

# --- turns -------------------------------------------------------------------------------

static func _end_turn(state: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	state.queue = []
	_check_outcome(state)
	if done(state):
		state.announced = true
		return _event(state, "battle_over", {"outcome": str(state.outcome), "turns": int(state.turn)})
	return _begin_turn(state, rng_dice, rng_creatures)

static func _begin_turn(state: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	state.turn = int(state.get("turn", 0)) + 1
	state.phase = "planning"
	var base_rerolls: int = int(DeepContent.constant("rerolls", 2))
	var gifts: int = 0
	var frozen: bool = false
	for foe in living(state.enemies):
		if str(foe.get("gimmick", "")) == "gift_rerolls":
			gifts += 1
		if str(foe.get("gimmick", "")) == "roll_for_you" and int(state.turn) % 2 == 1:
			frozen = true
	for unit in state.players:
		## Rubble and fog both clear when a new turn is dug: a gimmick may take a socket for
		## one turn, never for the fight.
		unit.buried = []
		unit.clouded = []
		## Block only guards the turn it was raised in: what the creatures did not break falls away.
		unit.block = 0
		if bool(unit.get("downed", false)):
			unit.hand = []
			unit.locked = true
			continue
		var dice: Array = unit.dice.duplicate()
		var stolen: int = int(unit.get("stolen_dice", 0))
		while stolen > 0 and dice.size() > 1:
			dice.pop_back()
			stolen -= 1
		unit.stolen_dice = 0
		unit.hand = DeepDice.roll_hand(dice, rng_dice)
		_loaded(unit, [], rng_dice)
		unit.flips = int(unit.passive.get("amount", 1)) if str(unit.get("passive", {}).get("kind", "")) == "free_flip" else 0
		var extra: int = int(unit.passive.get("amount", 1)) if str(unit.get("passive", {}).get("kind", "")) == "extra_reroll" else 0
		unit.rerolls_max = base_rerolls + extra + gifts + int(unit.get("granted_rerolls", 0))
		unit.rerolls = 0 if frozen else unit.rerolls_max
		unit.granted_rerolls = 0
		unit.locked = false
		unit.block_lost = int(unit.get("block_lost_accum", 0))
		unit.block_lost_accum = 0
		unit.dealt_last_turn = int(unit.get("dealt", 0))
		unit.dealt = 0
		unit.healed = 0
		var foes: Array = living(state.enemies)
		if enemy(state, str(unit.get("target", ""))).get("hp", 0) <= 0 and not foes.is_empty():
			unit.target = str(foes[0].id)
	## The creatures roll and say what they mean to do.
	var high: int = 0
	for unit in living(state.players):
		high = maxi(high, int(DeepHand.analyze(unit.hand).get("high", 0)))
	for foe in state.enemies:
		if int(foe.hp) <= 0:
			foe.intents = []
			continue
		foe.intents = DeepCreatures.intents(foe, state, rng_creatures)
		match str(foe.get("gimmick", "")):
			"block_from_high":
				## The golem hardens to match the party's best die; it does not pile up.
				foe.block = maxi(int(foe.block), high)
			"bury_socket", "cloud_socket":
				var victims: Array = living(state.players)
				if not victims.is_empty():
					var victim: Dictionary = DeepRng.pick(rng_creatures, victims)
					var filled: Array = []
					for socket in range(victim.rail.size()):
						if victim.rail[socket] is Dictionary and not victim.clouded.has(socket) and not victim.buried.has(socket):
							filled.append(socket)
					## Never the last open socket: a rail that cannot fire at all is a stalemate.
					if filled.size() >= 2:
						var socket: int = int(DeepRng.pick(rng_creatures, filled))
						if str(foe.gimmick) == "bury_socket":
							victim.buried.append(socket)
						else:
							victim.clouded.append(socket)
	return _event(state, "turn_begin", {"turn": state.turn, "frozen": frozen,
		"hands": state.players.map(func(u: Dictionary) -> Dictionary: return {"unit": u.id, "hand": u.hand.duplicate(true), "rerolls": u.rerolls}),
		"intents": state.enemies.map(func(e: Dictionary) -> Dictionary: return {"unit": e.id, "intents": e.get("intents", []).duplicate(true)})})

static func _check_outcome(state: Dictionary) -> void:
	if done(state):
		return
	if living(state.players).is_empty():
		state.phase = "over"
		state.outcome = "defeat"
	elif living(state.enemies).is_empty():
		state.phase = "over"
		state.outcome = "victory"

# --- forecast ----------------------------------------------------------------------------

static func forecast(state: Dictionary, player_id: String) -> Dictionary:
	## What the rail would do with the hand as it stands: per socket, and in total. Runs the
	## real gem code on a copy of the fight, with coins landing heads and nothing queued.
	var copy: Dictionary = state.duplicate(true)
	copy.phase = "resolving"
	var unit: Dictionary = player(copy, player_id)
	if unit.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	unit.resonance = 0
	unit.previous_fired = false
	unit.previous_amount = 0
	unit.previous_colours = []
	unit.previous_socket = -1
	unit.amplify = 1.0
	unit.nullify_next = false
	unit.cut_step_bonus = int(unit.passive.get("amount", 1)) if str(unit.get("passive", {}).get("kind", "")) == "first_gem_cut_step" else 0
	unit.fizzle_free = 1 if str(unit.get("passive", {}).get("kind", "")) == "first_fizzle_free" else 0
	unit.fired_sockets = []
	unit.replaying = false
	var sockets: Array = []
	var totals: Dictionary = {"damage": 0, "block": 0, "heal": 0, "gold": 0, "poison": 0, "fires": 0, "fizzles": 0}
	for socket in range(unit.rail.size()):
		if not unit.rail[socket] is Dictionary:
			sockets.append({"socket": socket, "empty": true})
			continue
		var stone: Dictionary = unit.rail[socket]
		var context: Dictionary = rail_context(copy, unit, socket)
		var preview: Dictionary = DeepStone.evaluate(stone, unit.hand, context)
		var fires: int = maxi(1, int(preview.get("fires", 1))) if preview.active else 0
		var event: Dictionary = {}
		for repeat in range(maxi(1, fires)):
			event = resolve_gem(copy, unit, socket, {"dry": true, "retrigger": repeat > 0}, rng)
		var entry: Dictionary = {"socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill), "active": str(event.get("kind", "")) == "gem_fire",
			"reason": str(event.get("reason", "")), "dice": event.get("dice", []), "resonance": int(event.get("resonance", 0)),
			"harmony": bool(event.get("harmony", false)), "cut_step": int(event.get("cut_step", 0)), "fires": fires,
			"effects": event.get("effects", []), "trigger": DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(preview.get("cut_step", 0)))}
		if entry.active:
			totals.fires += fires
			for effect in event.get("effects", []):
				var kind: String = str(effect.get("kind", ""))
				if totals.has(kind):
					var amount: int = int(effect.get("amount", 0))
					if kind == "damage":
						amount = int(effect.get("raw", amount))
					totals[kind] += amount
		else:
			totals.fizzles += 1
		sockets.append(entry)
	totals.resonance = int(unit.resonance)
	var birthstone: Dictionary = {}
	if not unit.get("birthstone", {}).is_empty():
		var preview: Dictionary = resolve_birthstone(copy, unit, {"dry": true}, rng)
		birthstone = {"name": str(preview.get("name", "")), "fired": bool(preview.get("fired", false)), "tiers": preview.get("tiers", []),
			"resonance": int(preview.get("resonance", 0))}
		for tier in preview.get("tiers", []):
			if not bool(tier.get("active", false)):
				continue
			for effect in tier.get("effects", []):
				var kind: String = str(effect.get("kind", ""))
				if totals.has(kind):
					var amount: int = int(effect.get("amount", 0))
					if kind == "damage":
						amount = int(effect.get("raw", amount))
					totals[kind] += amount
	return {"sockets": sockets, "totals": totals, "birthstone": birthstone}

# --- events --------------------------------------------------------------------------------

static func _event(state: Dictionary, kind: String, fields: Dictionary) -> Dictionary:
	state.seq = int(state.get("seq", 0)) + 1
	var event: Dictionary = {"kind": kind, "seq": state.seq, "turn": int(state.get("turn", 0)), "duration": float(BASE_DURATION.get(kind, 0.4))}
	event.merge(fields, true)
	if done(state) and kind != "battle_over":
		event.battle_over = str(state.outcome)
	return event

static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error}
