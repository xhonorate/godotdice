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
## units carry visible movesets and sequential roll progress. Both sides share one damage pipeline.

## How long each event holds the clock at 1×. A fizzle, or a Birthstone that stays dark, only
## needs long enough to be seen; a gem that fires waits for its bolts to land.
const BASE_DURATION: Dictionary = {"turn_begin": 0.8, "resolution_begin": 0.4, "rail_begin": 0.3, "gem_fire": 0.65,
	"gem_fizzle": 0.2, "birthstone": 0.9, "rail_end": 0.3, "skip": 0.6, "enemy_begin": 0.25, "enemy_roll": 1.1, "enemy_ability": 0.7, "enemy_move": 0.5, "enemy_end": 0.2, "tick": 0.6, "battle_over": 1.2}
const HAND_KINDS: Array = ["raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high"]
const SELF_KINDS: Array = ["amplify_next", "cut_step_next", "grant_reroll", "retrigger_previous", "quality_bonus", "sparkle",
	"coin_flip", "resonance", "replay_color", "replay_fizzled", "rank_buff", "repeat_next", "gem_rank", "upgrade_faces", "stake", "appraise"]
const BIRTHSTONE_KINDS: Array = ["replay_rail", "tick_poison", "stone_drop"]

# --- setup -------------------------------------------------------------------------------

static func make_player(id: String, name: String, character_key: String, rail: Array, dice: Array, hp: int = -1, riders: Array = []) -> Dictionary:
	## A player unit for a fight. `rail` is stones by socket (null for empty), `riders` the
	## Void gems riding each socket, `dice` five die instances. HP, sockets, passive and
	## Birthstone come from the character. The rail is kept by socket here; `begin` lays it
	## flat for the fight.
	var character: Dictionary = DeepContent.character(character_key)
	var sockets: Array = character.get("sockets", ["ANY"]).duplicate()
	var max_hp: int = int(character.get("hp", 60))
	var unit: Dictionary = {"id": id, "name": name, "side": "player", "character": character_key, "sockets": sockets, "rail": rail.duplicate(true), "riders": riders.duplicate(true),
		"birthstone": character.get("birthstone", {}).duplicate(true), "flips": 0, "fired_sockets": [], "fizzled_sockets": [],
		"rank_buff": {"carat": 0, "cut": 0}, "gem_buffs": {}, "pyrite_delta": 0, "repeat_next": 0, "replaying": false, "stone_drops": 0,
		"hp": hp if hp >= 0 else max_hp, "max_hp": max_hp, "block": 0, "statuses": {}, "dice": dice.duplicate(true), "hand": [],
		"rerolls": 0, "rerolls_max": 0, "locked": false, "target": "", "passive": character.get("passive", {"kind": "none"}),
		"resonance": 0, "initial_resonance": 0, "previous_fired": false, "previous_amount": 0, "previous_colors": [], "previous_socket": - 1,
		"amplify": 1.0, "cut_step_bonus": 0, "nullify_next": false, "block_lost": 0, "block_lost_accum": 0,
		"healed": 0, "dealt": 0, "dealt_last_turn": 0, "gold": 0, "once": {}, "downed": false, "connected": true,
		"eligible_turn": 1, "buried": [], "clouded": [], "stolen_dice": 0, "granted_rerolls": 0, "sparkle": 0,
		"quality_bonus": 0, "run_mods": {}, "skipped_turn": - 1}
	DeepStone.normalize_rail(unit)
	return unit

static func begin(players: Array, creature_keys: Array, context: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	var state: Dictionary = {"turn": 0, "phase": "planning", "outcome": "", "depth": int(context.get("depth", 1)),
		"party": players.size(), "elite": bool(context.get("elite", false)), "warden": bool(context.get("warden", false)),
		"players": players.duplicate(true), "enemies": [], "queue": [], "seq": 0}
	## Each rail is laid flat for the fight: a socket's gem, then the Void gems riding it.
	for unit in state.players:
		DeepStone.flatten_rail(unit)
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

static func aim(unit: Dictionary) -> String:
	## Who this player's gems are firing at. Through a resolution that is the creature they
	## were locked in against, whatever has been clicked since: a turn already thrown cannot
	## be redirected halfway.
	return str(unit.get("firing_target", unit.get("target", "")))

static func command(state: Dictionary, player_id: String, cmd: Dictionary, rng_dice: RandomNumberGenerator) -> Dictionary:
	## Rerolls, locking and targeting. Returns {ok, error, event}.
	## Targeting is the one thing that answers while a turn resolves: it names who the NEXT
	## turn goes at, which is worth choosing while watching this one land, and it cannot
	## reach the blows already in the air.
	if str(state.get("phase", "")) != "planning" and str(cmd.get("kind", "")) != "target":
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
				for victim in living(state.players):
					victim.hp = maxi(1, int(victim.hp) - drain)
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
		## Whoever each player is pointed at as the turn begins is who their gems fire at,
		## and nothing clicked between here and the end of it moves that.
		unit.firing_target = str(unit.get("target", ""))
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
		queue.append({"kind": "enemy_begin", "unit": foe.id})
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
			unit.resonance = int(unit.get("initial_resonance", 0))
			unit.previous_fired = false
			unit.previous_amount = 0
			unit.previous_colors = []
			unit.previous_socket = -1
			unit.amplify = 1.0
			unit.nullify_next = false
			unit.cut_step_bonus = 0
			unit.fired_sockets = []
			unit.fizzled_sockets = []
			unit.repeat_next = 0
			unit.replaying = false
			if str(unit.get("passive", {}).get("kind", "")) == "first_gem_cut_step":
				unit.cut_step_bonus = int(unit.passive.get("amount", 1))
			## Second Wind: the Knight banks the rerolls he did not spend.
			var unused: int = int(unit.get("rerolls", 0))
			var healed: int = 0
			if str(unit.get("passive", {}).get("kind", "")) == "heal_per_unused_reroll" and unused > 0:
				healed = _heal(unit, int(unit.passive.get("amount", 3)) * unused)
			return _event(state, "rail_begin", {"unit": unit.id, "unused_rerolls": unused, "healed": healed, "resonance": int(unit.resonance)})
		"gem":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty() or bool(unit.get("downed", false)) or done(state):
				return {}
			return resolve_gem(state, unit, int(s.socket), {"retrigger": bool(s.get("retrigger", false)), "scale": int(s.get("scale", 100)),
				"replay": bool(s.get("replay", false)), "force": bool(s.get("force", false))}, rng_dice)
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
				_reset_defenses(foe)
			return {}
		"enemy_begin":
			var foe: Dictionary = enemy(state, str(s.unit))
			if foe.is_empty() or int(foe.hp) <= 0 or done(state):
				return {}
			DeepCreatures.prepare(foe)
			DeepCreatures.refresh_bonuses(foe, state)
			foe.acting = true
			foe.beat = "begin"
			foe.suppressed = mini(foe.dice.size(), int(foe.get("stolen_dice", 0)))
			foe.stolen_dice = 0
			if int(foe.statuses.get("stun", 0)) > 0 or int(foe.suppressed) >= foe.dice.size():
				var why: String = "bound"
				if int(foe.statuses.get("stun", 0)) > 0:
					why = "stun"
					foe.statuses.stun = int(foe.statuses.stun) - 1
					foe.stun_streak = int(foe.get("stun_streak", 0)) + 1
					if int(foe.stun_streak) >= 3:
						foe.statuses.stun = 0
						foe.statuses.combo_breaker = 2
						foe.stun_streak = 0
				else:
					foe.stun_streak = 0
				DeepCreatures.finish(foe)
				return _event(state, "skip", {"unit": foe.id, "why": why, "combo_breaker": int(foe.statuses.get("combo_breaker", 0)) == 2})
			foe.stun_streak = 0
			state.queue.push_front({"kind": "enemy_roll", "unit": foe.id})
			return _event(state, "enemy_begin", {"unit": foe.id})
		"enemy_roll":
			var foe: Dictionary = enemy(state, str(s.unit))
			if foe.is_empty() or int(foe.hp) <= 0 or done(state):
				return {}
			var dice: Array = DeepCreatures.effective_dice(foe)
			var available: int = maxi(0, dice.size() - int(foe.suppressed))
			var index: int = int(foe.next_die)
			if index >= available:
				DeepCreatures.finish(foe)
				return _event(state, "enemy_end", {"unit": foe.id})
			var tense: bool = DeepCreatures.suspense(foe, dice.slice(index, available))
			var roll: Dictionary = DeepDice.roll_one(dice[index], rng_creatures)
			roll.turn_tag = int(state.turn)
			foe.rolled_die = dice[index].duplicate(true)
			foe.hand.append(roll)
			foe.next_die = index + 1
			foe.beat = "roll"
			foe.active_move = -1
			var moves: Array = DeepCreatures.resolve_roll(foe, state)
			state.queue.push_front({"kind": "enemy_roll", "unit": foe.id})
			for move_index in range(moves.size() - 1, -1, -1):
				state.queue.push_front({"kind": "enemy_move", "unit": foe.id, "move": moves[move_index]})
				state.queue.push_front({"kind": "enemy_ability", "unit": foe.id, "move": moves[move_index]})
			return _event(state, "enemy_roll", {"unit": foe.id, "die": dice[index].duplicate(true), "roll": roll.duplicate(true),
				"roll_index": index, "states": foe.move_states.duplicate(), "suspense": tense, "duration": 2.0 if tense else 1.1})
		"enemy_ability":
			var foe: Dictionary = enemy(state, str(s.unit))
			if foe.is_empty() or int(foe.hp) <= 0 or done(state):
				return {}
			var move: Dictionary = s.move
			foe.beat = "ability"
			foe.active_move = int(move.index)
			foe.move_states[int(move.index)] = "resolving"
			var shown: Array = move.effects.duplicate(true)
			for effect in shown:
				if str(effect.kind) == "damage" and int(state.turn) >= int(DeepContent.constant("enrage_turn", 7)):
					effect.amount += int(DeepContent.constant("enrage_damage", 2)) * (int(state.turn) - int(DeepContent.constant("enrage_turn", 7)) + 1)
				if str(effect.kind) == "damage":
					effect.amount = DeepRules.outgoing_damage(int(effect.amount), foe.statuses)
			return _event(state, "enemy_ability", {"unit": foe.id, "move": move.move, "index": move.index,
				"dice": move.dice, "combo": move.combo, "trigger": move.trigger, "effects": shown, "duration": 1.0 if bool(move.combo) else 0.7})
		"enemy_move":
			var foe: Dictionary = enemy(state, str(s.unit))
			if foe.is_empty() or int(foe.hp) <= 0 or done(state):
				return {}
			return _enemy_act(state, foe, s.move, rng_dice)
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
	var socket_color: String = str(unit.sockets[socket]) if socket < unit.sockets.size() else "ANY"
	var carat_bonus: int = 0
	for neighbour in [socket - 1, socket + 1]:
		if neighbour < 0 or neighbour >= unit.rail.size() or not unit.rail[neighbour] is Dictionary:
			continue
		var other: Dictionary = unit.rail[neighbour]
		for m in DeepStone.modifiers(other):
			if str(m.get("kind", "")) != "adjacent_carat":
				continue
			var shared: bool = true
			if bool(m.get("same_color", false)):
				shared = false
				for color in DeepStone.colors(other, str(unit.sockets[neighbour])):
					if DeepStone.colors(stone, socket_color).has(color):
						shared = true
			if shared:
				carat_bonus += int(m.get("amount", 1))
	var shrine: String = str(unit.get("run_mods", {}).get("shrine", ""))
	if not shrine.is_empty() and str(DeepStone.skill_of(stone).get("trigger", {}).get("kind", "")) == shrine:
		carat_bonus += 1
	## What a Fire Opal has put on the whole rail this fight rides on top of all of it.
	var buff: Dictionary = unit.get("rank_buff", {})
	var gem_buff: Dictionary = unit.get("gem_buffs", {}).get(str(stone.get("id", "")), {})
	carat_bonus += int(buff.get("carat", 0)) + int(gem_buff.get("carat", 0))
	var enemy_poison: int = 0
	for foe in living(state.enemies):
		enemy_poison += int(foe.statuses.get("poison", 0))
	return {"unit": unit, "resonance": int(unit.get("resonance", 0)), "previous_fired": bool(unit.get("previous_fired", false)),
		"previous_amount": int(unit.get("previous_amount", 0)), "amplify": float(unit.get("amplify", 1.0)),
		"cut_step_bonus": int(unit.get("cut_step_bonus", 0)) + int(buff.get("cut", 0)) + int(gem_buff.get("cut", 0)), "carat_bonus": carat_bonus,
		"clarity_bonus": int(gem_buff.get("clarity", 0)), "enemy_poison": enemy_poison,
		"dulled": int(unit.get("statuses", {}).get("dulled", 0)),
		"depth": int(state.get("depth", 1)),
		"turn": int(state.get("turn", 1)), "party": int(state.get("party", 1)), "socket": socket_color,
		"retrigger": bool(opts.get("retrigger", false)), "force_fire": bool(opts.get("force", false))}

static func worn_socket(unit: Dictionary, socket: int) -> int:
	## What a Doublet at this socket wears: the nearest gem after it that is not itself an
	## opal. Skipping opals is what makes a Doublet terminate — it can never end up wearing
	## a skill that would send it looking again — and it lets two Doublets share one gem.
	##
	## How far it can see is what its Cut buys: a Poor slice wears whatever lies in the very
	## next socket or nothing at all, a Perfect one reaches five along, past empty sockets
	## and past other opals.
	if not unit.rail[socket] is Dictionary or str(DeepStone.skill_of(unit.rail[socket]).get("wears", "")) != "next":
		return -1
	var reach: int = int(DeepStone.effective(unit.rail[socket], {"dulled": int(unit.get("statuses", {}).get("dulled", 0))}).cut_step) + 1
	for ahead in range(socket + 1, mini(unit.rail.size(), socket + 1 + reach)):
		if unit.rail[ahead] is Dictionary and not DeepStone.is_opal(unit.rail[ahead]):
			return ahead
	return -1

static func stone_at(unit: Dictionary, socket: int) -> Dictionary:
	## The stone this socket fires as. Everything but a Doublet is simply itself.
	if socket < 0 or socket >= unit.rail.size() or not unit.rail[socket] is Dictionary:
		return {}
	var worn: int = worn_socket(unit, socket)
	if worn < 0:
		return unit.rail[socket]
	return DeepStone.wearing(unit.rail[socket], unit.rail[worn])

static func repeatable(unit: Dictionary, socket: int) -> bool:
	## What an opal's repeat is allowed to touch. Never another opal: that one rule is the
	## whole of why two opals can never call each other for ever. A Doublet wearing another
	## gem's skill is no longer opal work, so it plays again like anything else.
	if socket < 0 or socket >= unit.rail.size() or not unit.rail[socket] is Dictionary:
		return false
	if not DeepStone.is_opal(unit.rail[socket]):
		return true
	return worn_socket(unit, socket) >= 0

static func resolve_gem(state: Dictionary, unit: Dictionary, socket: int, opts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## One gem fires or fizzles. `opts.retrigger` marks a repeat, `opts.scale` a percentage
	## an Echo repeats at, `opts.force` a Matrix waking a gem the hand never asked for, and
	## `opts.dry` a forecast that must not roll coins or queue repeats.
	var dry: bool = bool(opts.get("dry", false))
	if socket < 0 or socket >= unit.rail.size() or not unit.rail[socket] is Dictionary:
		return {}
	## A Doublet fires as the gem it wears; everything else is simply itself. The id, the
	## four C's and the inclusions stay the socket's own either way.
	var stone: Dictionary = stone_at(unit, socket)
	if unit.buried.has(socket) or unit.clouded.has(socket):
		unit.previous_fired = false
		return _event(state, "gem_fizzle", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
			"reason": "The socket is buried." if unit.buried.has(socket) else "The socket is clouded.", "resonance": unit.resonance, "blocked": true})
	var context: Dictionary = rail_context(state, unit, socket, opts)
	var ev: Dictionary = DeepStone.evaluate(stone, unit.hand, context)
	for effect in ev.get("effects", []):
		if int(effect.get("cost", 0)) > DeepRules.pyrite(unit):
			ev.active = false
			ev.reason = "Not enough Pyrite."
	var nullified: bool = bool(unit.get("nullify_next", false))
	## A Prelude hands the next gem to resolve its extra goes, and is spent doing it.
	var promised: int = int(unit.get("repeat_next", 0))
	unit.amplify = 1.0
	unit.cut_step_bonus = 0
	unit.nullify_next = false
	unit.repeat_next = 0
	var retrigger: bool = bool(opts.get("retrigger", false))
	if nullified and not retrigger:
		ev.active = false
		ev.reason = "Double Down came up empty."
	if not ev.active:
		## A gem that stays dark costs the rail its turn, not its Resonance: the count keeps
		## whatever the gems before it built and the gems after it carry on from there.
		var healed: int = 0
		if str(unit.get("passive", {}).get("kind", "")) == "heal_on_fizzle" and not bool(unit.get("downed", false)):
			healed = _heal(unit, int(unit.passive.get("amount", 2)))
		unit.previous_fired = false
		unit.previous_amount = 0
		unit.previous_colors = []
		## A gem that stayed dark is one a Matrix can still wake. Its own second try is not
		## a fresh disappointment, so a retrigger never lists it twice.
		if not retrigger and not unit.get("fizzled_sockets", []).has(socket):
			unit.fizzled_sockets.append(socket)
		return _event(state, "gem_fizzle", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
			"reason": str(ev.get("reason", "")), "resonance": unit.resonance, "dice": ev.get("dice", []), "healed": healed,
			"cut_step": int(ev.get("cut_step", 0)), "worn": str(stone.get("worn_from", ""))})
	## It fires.
	var scale: int = int(opts.get("scale", 100))
	var hp_cost: int = int(ev.get("hp_cost", 0))
	if hp_cost > 0:
		unit.hp = maxi(1, int(unit.hp) - hp_cost)
	var harmony: bool = false
	if bool(unit.get("previous_fired", false)):
		for color in unit.get("previous_colors", []):
			if ev.get("colors", []).has(color):
				harmony = true
	var gain: int = int(ev.get("resonance_gain", 1)) + (1 if harmony else 0)
	unit.resonance = int(unit.get("resonance", 0)) + gain
	var results: Array = []
	var previous_socket: int = int(unit.get("previous_socket", -1))
	var reactions: Dictionary = {}
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
		## Weight on a whole-number effect buys procs, not a bigger number: so many for
		## certain, and a roll for one more. A forecast takes only what is certain.
		var procs: int = int(applied.get("procs", 1))
		if not dry and int(applied.get("proc_chance", 0)) > 0 and DeepRng.chance(rng, float(applied.get("proc_chance", 0))):
			procs += 1
		if applied.has("cost"):
			procs = 1
		applied.procs = procs
		if kind in HAND_KINDS or kind in SELF_KINDS:
			for _proc in range(1 if kind in DeepRules.PROC_IN_PLACE else procs):
				results.append(_mutate_hand(unit, applied) if kind in HAND_KINDS else _self_effect(state, unit, applied, socket, previous_socket, dry, rng))
				if done(state):
					break
		else:
			applied.repeat = clampi(int(applied.get("repeat", 1)) * procs, 0, DeepRules.MAX_REPEAT)
			results.append_array(_apply(state, unit, applied, rng, "", reactions))
		if done(state):
			break
	if int(ev.get("next_cut_step", 0)) > 0:
		unit.cut_step_bonus = int(unit.cut_step_bonus) + int(ev.next_cut_step)
	unit.previous_fired = true
	unit.previous_amount = DeepStone.total_amount(ev)
	unit.previous_colors = ev.get("colors", [])
	unit.previous_socket = socket
	if not unit.get("fired_sockets", []).has(socket):
		unit.fired_sockets.append(socket)
	if not dry and not retrigger and int(ev.get("fires", 1)) > 1:
		for _extra in range(int(ev.fires) - 1):
			state.queue.push_front({"kind": "gem", "unit": unit.id, "socket": socket, "retrigger": true})
	if not dry and not retrigger and promised > 0:
		for _more in range(promised):
			state.queue.push_front({"kind": "gem", "unit": unit.id, "socket": socket, "retrigger": true})
	_check_outcome(state)
	return _event(state, "gem_fire", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
		"dice": ev.get("dice", []), "effects": results, "resonance": unit.resonance, "gain": gain, "harmony": harmony,
		"magnitude": float(ev.get("magnitude", 1.0)), "carat": int(ev.get("carat", 1)), "cut_step": int(ev.get("cut_step", 0)),
		"retrigger": retrigger, "replay": bool(opts.get("replay", false)), "scale": scale, "hp_cost": hp_cost, "fires": int(ev.get("fires", 1)),
		"forced": bool(opts.get("force", false)), "promised": promised if not retrigger else 0, "worn": str(stone.get("worn_from", "")),
		"duration": BASE_DURATION.gem_fire + 0.1 * results.size()})

# --- the Birthstone ----------------------------------------------------------------------

static func resolve_birthstone(state: Dictionary, unit: Dictionary, opts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## The character's own stone, last in the rail. Every tier the final hand satisfies fires
	## on the Resonance the rail delivered, unless a tier marked exclusive fires and takes the
	## others' place. Tiers do not add Resonance themselves. `opts.replay` is Encore's second
	## pass, on which the tier that asked for the replay stays dark. `opts.dry` is a forecast.
	##
	## A Prelude in the last socket has nothing after it but this, so this is what goes
	## again: the second pass is marked a replay, which is what keeps an Encore tier from
	## sending the whole rail round twice.
	var def: Dictionary = unit.get("birthstone", {})
	if def.is_empty():
		return {}
	var dry: bool = bool(opts.get("dry", false))
	var replay: bool = bool(opts.get("replay", false))
	var promised: int = int(unit.get("repeat_next", 0))
	unit.repeat_next = 0
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
	var reactions: Dictionary = {}
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
					results.append(_self_effect(state, unit, applied, -1, -1, dry, rng))
				elif kind in BIRTHSTONE_KINDS:
					results.append(_birthstone_effect(state, unit, applied, dry, replay))
				else:
					results.append_array(_apply(state, unit, applied, rng, "", reactions))
				if done(state):
					break
			entry.effects = results
		tiers.append(entry)
		if done(state):
			break
	if not dry and not replay and promised > 0:
		for _more in range(promised):
			state.queue.push_front({"kind": "birthstone", "unit": unit.id, "replay": true})
	_check_outcome(state)
	return _event(state, "birthstone", {"unit": unit.id, "name": str(def.get("name", "Birthstone")), "style": str(def.get("style", "")),
		"tiers": tiers, "fired": fired, "dice": all_dice, "resonance": resonance, "replay": replay, "promised": promised,
		"duration": (BASE_DURATION.birthstone + 0.2 * tiers.filter(func(x: Dictionary) -> bool: return bool(x.active)).size()) if fired else BASE_DURATION.gem_fizzle})

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

static func _self_effect(state: Dictionary, unit: Dictionary, effect: Dictionary, socket: int, previous_socket: int, dry: bool, rng: RandomNumberGenerator) -> Dictionary:
	var kind: String = str(effect.kind)
	var amount: int = int(effect.amount)
	var out: Dictionary = {"kind": kind, "amount": amount, "target": unit.id}
	match kind:
		"gem_rank":
			var scope: String = str(effect.get("scope", "adjacent"))
			var rank: String = str(effect.get("rank", "carat"))
			if not unit.has("gem_buffs"):
				unit.gem_buffs = {}
			var changed: Array = []
			for at in range(unit.rail.size()):
				if not unit.rail[at] is Dictionary or (scope == "adjacent" and absi(at - socket) != 1) or (scope == "others" and at == socket):
					continue
				var id: String = str(unit.rail[at].id)
				if not unit.gem_buffs.has(id):
					unit.gem_buffs[id] = {}
				unit.gem_buffs[id][rank] = int(unit.gem_buffs[id].get(rank, 0)) + amount
				changed.append(at)
			out.sockets = changed
			out.rank = rank
		"upgrade_faces":
			var changed: Array = []
			for roll in unit.hand:
				if bool(roll.get("phantom", false)) or not effect.get("dice", []).has(str(roll.die_id)) or changed.has(str(roll.die_id)):
					continue
				for die in unit.dice:
					if str(die.id) != str(roll.die_id):
						continue
					for face_index in range(die.faces.size()):
						if bool(effect.get("all_faces", false)) or face_index == int(roll.get("face", -1)):
							die.faces[face_index].value = mini(DeepDice.VALUE_CAP, int(die.faces[face_index].value) + amount)
					roll.value = mini(DeepDice.VALUE_CAP, int(roll.value) + amount)
					if die.has("top"):
						var physical_top: int = 0
						for face in die.faces:
							if str(face.get("kind", "plain")) != "blank":
								physical_top = maxi(physical_top, int(face.value))
						die.top = mini(DeepDice.VALUE_CAP, maxi(int(die.top), physical_top))
					roll.top = DeepDice.top(die)
					changed.append(str(die.id))
			DeepDice.resolve_mirrors(unit.hand)
			out.dice = changed
			out.hand = unit.hand.duplicate(true)
		"stake":
			var cost: int = int(effect.get("cost", 0))
			if DeepRules.pyrite(unit) >= cost:
				unit.pyrite_delta = int(unit.get("pyrite_delta", 0)) - cost
				unit.amplify = float(unit.amplify) * (1.0 + float(amount) / 100.0)
				out.spent = cost
				out.pyrite_after = DeepRules.pyrite(unit)
		"appraise":
			var appraised: Array = []
			var worth: int = 0
			for stone in unit.get("haul", []):
				if appraised.size() >= amount:
					break
				if bool(stone.get("appraised", false)):
					continue
				stone.appraised = true
				stone.inclusions_revealed = true
				appraised.append(str(stone.id))
				worth += DeepStone.value(stone)
			out.appraised = appraised
			out.value = worth
			out.hits = _apply(state, unit, {"kind": "damage", "target": "enemy", "amount": worth}, rng) if worth > 0 else []

		"replay_color":
			## A Seam: every gem of one color that has already fired this turn plays again,
			## in rail order. Never another opal — see `repeatable()`.
			var want: String = str(effect.get("color", ""))
			var encore: Array = []
			var touched: Array = []
			var played: Array = unit.get("fired_sockets", []).duplicate()
			played.sort()
			for other in played:
				var at: int = int(other)
				if at == socket or not repeatable(unit, at):
					continue
				if not DeepStone.colors(stone_at(unit, at), str(unit.sockets[at])).has(want):
					continue
				touched.append(at)
				for _time in range(maxi(1, amount)):
					encore.append({"kind": "gem", "unit": unit.id, "socket": at, "retrigger": true})
			out.color = want
			out.sockets = touched
			if dry or encore.is_empty():
				out.nothing = true
			else:
				state.queue = encore + state.queue
		"replay_fizzled":
			## A Matrix: gems that stayed dark this turn fire anyway, whatever the hand
			## shows. The amount is how many of them it can wake, earliest first, which is
			## what its Cut buys. Never another opal, so no two Matrices wake each other.
			var woken: Array = []
			var dark_sockets: Array = []
			var dark: Array = unit.get("fizzled_sockets", []).duplicate()
			dark.sort()
			for other in dark:
				var at: int = int(other)
				if dark_sockets.size() >= maxi(1, amount):
					break
				if at == socket or not repeatable(unit, at):
					continue
				dark_sockets.append(at)
				woken.append({"kind": "gem", "unit": unit.id, "socket": at, "retrigger": true, "force": true})
			out.sockets = dark_sockets
			if dry or woken.is_empty():
				out.nothing = true
			else:
				state.queue = woken + state.queue
		"rank_buff":
			## A Fire Opal: the whole rail grows, and stays grown until the fight is over.
			var rank: String = str(effect.get("rank", "carat"))
			var buff: Dictionary = unit.get("rank_buff", {"carat": 0, "cut": 0}).duplicate()
			if not dry:
				buff[rank] = int(buff.get(rank, 0)) + amount
				unit.rank_buff = buff
			out.rank = rank
			out.total = int(buff.get(rank, 0))
		"repeat_next":
			## A Prelude: the next thing to resolve goes again, the Birthstone included.
			if not dry:
				unit.repeat_next = int(unit.get("repeat_next", 0)) + maxi(0, amount)
			out.total = int(unit.get("repeat_next", 0))
		"amplify_next":
			unit.amplify = float(unit.amplify) * (1.0 + float(amount) / 100.0)
		"cut_step_next":
			unit.cut_step_bonus = int(unit.cut_step_bonus) + amount
		"grant_reroll":
			unit.granted_rerolls = int(unit.get("granted_rerolls", 0)) + amount
		"quality_bonus":
			unit.quality_bonus = int(unit.get("quality_bonus", 0)) + amount
		"sparkle":
			unit.sparkle = clampi(int(unit.get("sparkle", 0)) + maxi(0, amount), 0, DeepRules.SPARKLE_MAX_STACKS)
			out.total = int(unit.sparkle)
		"resonance":
			unit.resonance = int(unit.resonance) + amount
		"coin_flip":
			## One toss, however heavy the stone: a second could only lose what the first
			## won. Weight raises the stake instead, doubling again for every proc.
			var won: bool = true if dry else DeepRng.chance(rng, float(amount))
			out.won = won
			out.procs = maxi(1, int(effect.get("procs", 1)))
			var mult: float = pow(float(effect.get("win_mult", 2)), float(out.procs)) if won else float(effect.get("lose_mult", 0))
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
			var chosen: Dictionary = enemy(state, aim(source)) if is_player else player(state, intent_target)
			if chosen.is_empty() or int(chosen.hp) <= 0 or bool(chosen.get("downed", false)):
				chosen = foes[0] if not foes.is_empty() else {}
			return [chosen] if not chosen.is_empty() else []
		"enemies":
			return foes
		"enemy_adjacent":
			var chosen: Dictionary = enemy(state, aim(source))
			if chosen.is_empty() and not foes.is_empty():
				chosen = foes[0]
			return _adjacent_enemies(state, chosen).slice(0, 1)

		"enemy_behind":
			var chosen: Dictionary = enemy(state, aim(source))
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

static func _adjacent_enemies(state: Dictionary, target: Dictionary) -> Array:
	var out: Array = []
	var index: int = state.enemies.find(target)
	if index < 0:
		return out
	for direction in [1, -1]:
		var at: int = index + direction
		while at >= 0 and at < state.enemies.size():
			if int(state.enemies[at].hp) > 0:
				out.append(state.enemies[at])
				break
			at += direction
	return out

static func _apply(state: Dictionary, source: Dictionary, effect: Dictionary, rng: RandomNumberGenerator, intent_target: String = "", reactions: Dictionary = {}) -> Array:
	var kind: String = str(effect.kind)
	var repeat: int = maxi(0, int(effect.get("repeat", 1)))
	var results: Array = []
	var target_kind: String = str(effect.target)
	if str(source.get("side", "")) == "enemy" and kind in DeepRules.HOSTILE:
		target_kind = "heroes"
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
			var hit: Dictionary = _apply_one(state, source, target, kind, int(effect.amount), effect, rng, reactions)
			results.append(hit)
			while bool(effect.get("chain_on_kill", false)) and bool(hit.get("killed", false)) and int(source.get("hp", 0)) > 0:
				var survivors: Array = living(state.enemies)
				if survivors.is_empty():
					break
				hit = _apply_one(state, source, survivors[0], kind, int(effect.amount), effect, rng, reactions)
				results.append(hit)
		## A party-wide hit reaches all victims before retaliation can settle the fight.
		_check_outcome(state)
		if done(state):
			return results
	return results

static func _ward_blocks(target: Dictionary) -> bool:
	var ward: int = int(target.get("statuses", {}).get("ward", 0))
	if ward <= 0:
		return false
	target.statuses.ward = ward - 1
	return true

static func _reset_defenses(unit: Dictionary) -> void:
	unit.block = mini(int(unit.get("block", 0)), maxi(0, int(unit.statuses.get("retain", 0))))
	unit.statuses.erase("retain")
	unit.statuses.erase("spikes")

static func _apply_one(state: Dictionary, source: Dictionary, target: Dictionary, kind: String, amount: int, effect: Dictionary, rng: RandomNumberGenerator, reactions: Dictionary = {}) -> Dictionary:
	if effect.has("from_result"):
		amount = int(reactions.get("result_" + str(effect.from_result), 0)) * amount / 100
	var out: Dictionary = {"kind": kind, "target": str(target.id), "amount": amount}
	if kind == "poison" and str(target.get("gimmick", "")) == "poison_immune":
		out.immune = true
		return out
	if kind == "stun" and int(target.statuses.get("combo_breaker", 0)) > 0:
		out.resisted = true
		return out
	if kind in DeepRules.DEBUFFS and amount > 0 and _ward_blocks(target):
		out.warded = true
		out.ward_after = int(target.statuses.ward)
		return out
	match kind:
		"damage", "damage_curse", "detonate", "wager":
			var adjacent: Array = _adjacent_enemies(state, target)
			var spent: int = 0
			var consumed: int = 0
			if kind == "damage_curse":
				amount *= int(target.statuses.get("curse", 0))
			elif kind == "detonate":
				consumed = int(target.statuses.get("poison", 0))
				target.statuses.poison = 0
				amount *= consumed
				out.poison_consumed = consumed
			elif kind == "wager":
				spent = int(effect.get("cost", 0))
				if DeepRules.pyrite(source) < spent:
					out.unaffordable = true
					return out
				source.pyrite_delta = int(source.get("pyrite_delta", 0)) - spent
				out.spent = spent
			if bool(effect.get("missing_hp_bonus", false)):
				amount = amount * (2 * int(source.max_hp) - int(source.hp)) / maxi(1, int(source.max_hp))
			out.kind = "damage"
			out.amount = amount
			out.merge(_damage(state, source, target, amount, rng, false, reactions), true)
			reactions.result_damage = int(reactions.get("result_damage", 0)) + int(out.hp_loss)
			if spent > 0 and bool(out.get("killed", false)):
				out.refund = spent * int(effect.get("refund_mult", 2))
				source.pyrite_delta = int(source.pyrite_delta) + int(out.refund)
			if kind == "wager":
				out.pyrite_after = DeepRules.pyrite(source)
			var splash: int = int(effect.get("splash", 0))
			if splash > 0:
				var splashed: Array = []
				for neighbour in adjacent:
					var hit: Dictionary = _damage(state, source, neighbour, amount * splash / 100, rng, false, reactions)
					hit.target = str(neighbour.id)
					splashed.append(hit)
				out.splash = splashed
			if consumed > 0 and int(effect.get("poison_splash", 0)) > 0:
				var spread: Array = []
				for neighbour in adjacent:
					spread.append(_apply_one(state, source, neighbour, "poison", consumed * int(effect.poison_splash) / 100, {}, rng, reactions))
				out.poison_spread = spread
		"block":
			target.block = int(target.block) + amount
			out.block_after = target.block
			reactions.result_block = int(reactions.get("result_block", 0)) + amount
		"heal":
			out.healed = _heal(target, amount)
			out.hp_after = target.hp
			if str(source.get("side", "")) == "player":
				source.healed = int(source.get("healed", 0)) + int(out.healed)
		"gold":
			if str(source.get("side", "")) == "player":
				source.gold = int(source.get("gold", 0)) + amount
				out.gold_after = source.gold
				reactions.result_gold = int(reactions.get("result_gold", 0)) + amount
		"poison", "stun", "curse", "charged", "marked", "regeneration", "spikes", "dulled", "lifeline":
			# A new late enemy debuff must reach the player's next rail before decaying.
			# Reapplying an existing stack does not postpone its ordinary decay.
			if kind in ["curse", "dulled"] and amount > 0 and int(target.statuses.get(kind, 0)) == 0 and str(target.get("side", "")) == "player" and bool(source.get("acting", false)):
				if not target.has("deferred_decay"):
					target.deferred_decay = {}
				target.deferred_decay[kind] = true
			target.statuses[kind] = int(target.statuses.get(kind, 0)) + maxi(0, amount)
			if kind == "curse":
				target.statuses[kind] = mini(DeepRules.CURSE_MAX_STACKS, int(target.statuses[kind]))
			if kind == "lifeline" and bool(effect.get("revive_block", false)):
				target.statuses.lifeline_block = int(target.statuses.get("lifeline_block", 0)) + amount
			out[kind + "_after"] = target.statuses[kind]
		"max_hp":
			target.max_hp = int(target.max_hp) + maxi(0, amount)
			target.hp = int(target.hp) + maxi(0, amount)
			out.max_hp_after = int(target.max_hp)
			out.hp_after = int(target.hp)
		"max_hp_loss":
			target.max_hp = maxi(1, int(target.max_hp) - maxi(0, amount))
			target.hp = mini(int(target.hp), int(target.max_hp))
			out.max_hp_after = int(target.max_hp)
			out.hp_after = int(target.hp)

		"ward":
			target.statuses.ward = mini(99, int(target.statuses.get("ward", 0)) + maxi(0, amount))
			out.ward_after = target.statuses.ward
		"retain":
			target.statuses.retain = mini(20, int(target.statuses.get("retain", 0)) + maxi(0, amount))
			out.retain_after = target.statuses.retain
		"clouded":
			if str(target.get("side", "")) == "enemy":
				var moves: Array = DeepCreatures.moves_for(target)
				if not moves.is_empty() and amount > 0:
					if int(target.statuses.get("clouded", 0)) <= 0:
						target.clouded_move = rng.randi_range(0, moves.size() - 1)
					target.statuses.clouded = int(target.statuses.get("clouded", 0)) + amount
					out.clouded_move = int(target.clouded_move)
					out.clouded_after = int(target.statuses.clouded)
					if not bool(target.get("acting", false)):
						DeepCreatures.prepare(target)
			else:
				var available: Array = []
				for socket in range(target.rail.size()):
					if target.rail[socket] is Dictionary and not target.buried.has(socket) and not target.clouded.has(socket):
						available.append(socket)
				if available.size() >= 2:
					target.clouded.append(DeepRng.pick(rng, available))
		"remove_block":
			var removed: int = int(target.block) if bool(effect.get("remove_all", false)) else mini(int(target.block), amount)
			target.block = int(target.block) - removed
			out.removed = removed
			reactions.result_removed = int(reactions.get("result_removed", 0)) + removed
			out.block_after = target.block
		"cleanse":
			var cleared: int = 0
			for status in ["poison", "stun", "curse", "marked", "dulled", "clouded"]:
				while cleared < amount and int(target.statuses.get(status, 0)) > 0:
					target.statuses[status] = int(target.statuses[status]) - 1
					cleared += 1
			if cleared < amount:
				var dread: int = mini(amount - cleared, int(target.get("dread_turns", 0)))
				target.dread_turns = int(target.get("dread_turns", 0)) - dread
				cleared += dread
			if str(target.get("side", "")) == "enemy" and not bool(target.get("acting", false)):
				DeepCreatures.prepare(target)
			out.cleared = cleared
		"revive":
			target.downed = false
			target.hp = clampi(amount, 1, int(target.max_hp))
			target.block = 0
			target.statuses = {}
			target.erase("deferred_decay")
			target.eligible_turn = int(state.turn) + 1
			out.hp_after = target.hp
		"dice_dread":
			target.dread_turns = int(target.get("dread_turns", 0)) + maxi(0, amount)
		"dice_upgrade":
			target.dice_upgrade = mini(DeepCreatures.TIERS.size() - 1, int(target.get("dice_upgrade", 0)) + amount)
		"die_steal":
			target.stolen_dice = int(target.get("stolen_dice", 0)) + amount
	return out

static func _damage(state: Dictionary, source: Dictionary, target: Dictionary, amount: int, rng: RandomNumberGenerator, settle: bool = true, reactions: Dictionary = {}, reactive: bool = false) -> Dictionary:
	var raw: int = maxi(0, amount)
	if str(source.get("side", "")) == "enemy":
		var enrage_turn: int = int(DeepContent.constant("enrage_turn", 7))
		if int(state.turn) >= enrage_turn:
			raw += int(DeepContent.constant("enrage_damage", 2)) * (int(state.turn) - enrage_turn + 1)
	raw = DeepRules.outgoing_damage(raw, source.get("statuses", {}))
	var curse: int = clampi(int(target.statuses.get("curse", 0)), 0, DeepRules.CURSE_MAX_STACKS)
	var marked: int = int(target.statuses.get("marked", 0)) if not reactive and amount > 0 else 0
	raw = raw * (100 + DeepRules.CURSE_PERCENT * curse) * (100 + 25 * marked) / 10000
	if marked > 0:
		target.statuses.erase("marked")
	var absorbed: int = mini(int(target.block), raw)
	target.block = int(target.block) - absorbed
	var loss: int = mini(int(target.hp), raw - absorbed)
	target.hp = int(target.hp) - loss
	var rescued: int = _lifeline(target)
	var out: Dictionary = {"raw": raw, "absorbed": absorbed, "hp_loss": loss, "hp_after": target.hp, "block_after": target.block}
	if rescued > 0:
		out.lifeline = rescued
	if marked > 0:
		out.marked_spent = marked
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
		if not reactive and str(target.get("gimmick", "")) == "reflect_zero_resonance" and loss > 0 and int(source.get("resonance", 0)) <= 1 and str(source.get("side", "")) == "player":
			var back: int = loss / 2
			var reflections: Array = []
			for victim in living(state.players):
				var hit: Dictionary = _damage(state, target, victim, back, rng, false, {}, true)
				hit.target = str(victim.id)
				hit.kind = "damage"
				reflections.append(hit)
			out.reflections = reflections

		if str(target.get("gimmick", "")) == "split_on_big_hit" and int(target.hp) > 0 and loss * 100 >= int(target.max_hp) * 40 and state.enemies.size() < 6:
			var half: int = maxi(1, int(target.hp) / 2)
			target.hp = half
			var twin: Dictionary = target.duplicate(true)
			twin.id = "%s_split%d" % [str(target.id), state.enemies.size()]
			twin.hp = half
			twin.max_hp = half
			DeepCreatures.prepare(twin)
			for index in range(twin.dice.size()):
				twin.dice[index].id = "%s_d%d" % [str(twin.id), index]
			twin.statuses = {}
			twin.stun_streak = 0
			twin.clouded_move = -1
			state.enemies.insert(state.enemies.find(target) + 1, twin)
			out.split = twin.id
		if int(target.hp) <= 0:
			out.killed = true
			if int(target.get("stolen_gold", 0)) > 0 and str(source.get("side", "")) == "player":
				source.gold = int(source.get("gold", 0)) + int(target.stolen_gold)
				out.recovered_gold = int(target.stolen_gold)
				target.stolen_gold = 0
	var spikes: int = int(target.statuses.get("spikes", 0))
	if not reactive and amount > 0 and spikes > 0 and not reactions.has(str(target.id)) and int(source.get("hp", 0)) > 0:
		reactions[str(target.id)] = true
		var retaliation: Dictionary = _damage(state, target, source, spikes, rng, false, {}, true)
		retaliation.target = str(source.id)
		retaliation.kind = "damage"
		out.spikes = retaliation
	if settle:
		_check_outcome(state)
	return out

static func _lifeline(unit: Dictionary) -> int:
	var stacks: int = int(unit.statuses.get("lifeline", 0))
	if int(unit.hp) > 0 or stacks <= 0:
		return 0
	unit.statuses.erase("lifeline")
	unit.hp = mini(int(unit.max_hp), stacks)
	unit.downed = false
	unit.block = int(unit.get("block", 0)) + int(unit.statuses.get("lifeline_block", 0))
	unit.statuses.erase("lifeline_block")
	return int(unit.hp)

static func _heal(target: Dictionary, amount: int) -> int:
	if bool(target.get("downed", false)) or int(target.hp) <= 0:
		return 0
	var before: int = int(target.hp)
	target.hp = mini(int(target.max_hp), before + maxi(0, amount))
	return int(target.hp) - before

# --- creatures ---------------------------------------------------------------------------

static func _enemy_act(state: Dictionary, foe: Dictionary, move: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var results: Array = []
	var reactions: Dictionary = {}
	for effect in move.get("effects", []):
		results.append_array(_apply(state, foe, effect, rng, "", reactions))
		if done(state):
			break
	foe.beat = "impact"
	foe.move_states[int(move.index)] = "used" if bool(move.get("combo", false)) else "resolved"
	return _event(state, "enemy_move", {"unit": foe.id, "move": str(move.get("move", "")), "index": int(move.index),
		"effects": results, "dice": move.get("dice", [])})

static func _poison_tick(state: Dictionary, unit: Dictionary) -> Dictionary:
	## One round of poison on one unit: it hurts for its stacks and loses one. When a creature
	## is the one bleeding, every Apothecary in the party drinks Resonance from it (Leech).
	var poison: int = int(unit.statuses.get("poison", 0))
	if poison <= 0 or int(unit.hp) <= 0:
		return {}
	var loss: int = mini(int(unit.hp), poison)
	unit.hp = int(unit.hp) - loss
	unit.statuses.poison = poison - 1
	var rescued: int = _lifeline(unit)
	var tick: Dictionary = {"unit": str(unit.id), "kind": "poison", "amount": loss, "hp_after": unit.hp, "remaining": unit.statuses.poison}
	if rescued > 0:
		tick.lifeline = rescued
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
		var regen: int = int(unit.statuses.get("regeneration", 0))
		if regen > 0:
			var healed: int = _heal(unit, regen)
			unit.statuses.regeneration = regen - 1
			if healed > 0:
				ticks.append({"unit": str(unit.id), "kind": "regeneration", "amount": healed, "hp_after": unit.hp, "remaining": regen - 1})
		for fading in ["curse", "dulled", "combo_breaker"]:
			if int(unit.statuses.get(fading, 0)) > 0 and not unit.get("deferred_decay", {}).has(fading):
				unit.statuses[fading] = int(unit.statuses[fading]) - 1
		unit.erase("deferred_decay")
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
	var batteries: Array = []
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
		## Retain preserves part of the unspent Block once; Spikes expires here too.
		_reset_defenses(unit)
		if bool(unit.get("downed", false)):
			unit.hand = []
			unit.locked = true
			continue
		var charged: int = int(unit.statuses.get("charged", 0))
		unit.statuses.erase("charged")
		unit.initial_resonance = charged
		unit.resonance = charged
		if charged > 0:
			batteries.append({"unit": str(unit.id), "amount": charged, "resonance": charged})
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
		var staked: Dictionary = unit.get("run_mods", {}).get("extra_rerolls", {})
		if staked is Dictionary and not staked.is_empty() and int(state.get("depth", 1)) <= int(staked.get("until_depth", 0)):
			## Steady Hands from the Grubstake: a reroll more until the first landing.
			extra += int(staked.get("amount", 1))
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
		unit.firing_target = str(unit.get("target", ""))
	## Refresh public movesets without rolling any enemy dice.
	var high: int = 0
	for unit in living(state.players):
		high = maxi(high, int(DeepHand.analyze(unit.hand).get("high", 0)))
	for foe in state.enemies:
		DeepCreatures.prepare(foe)
		DeepCreatures.refresh_bonuses(foe, state)
		if int(foe.hp) <= 0:
			continue
		match str(foe.get("gimmick", "")):
			"block_from_high":
				## The golem hardens to match the party's best die; it does not pile up.
				foe.block = maxi(int(foe.block), high)
			"bury_socket", "cloud_socket":
				var victims: Array = living(state.players)
				for victim in victims:
					var filled: Array = []
					for socket in range(victim.rail.size()):
						if victim.rail[socket] is Dictionary and not victim.clouded.has(socket) and not victim.buried.has(socket):
							filled.append(socket)
					## Never the last open socket: a rail that cannot fire at all is a stalemate.
					if filled.size() >= 2:
						if _ward_blocks(victim):
							continue
						var socket: int = int(DeepRng.pick(rng_creatures, filled))
						if str(foe.gimmick) == "bury_socket":
							victim.buried.append(socket)
						else:
							victim.clouded.append(socket)
	return _event(state, "turn_begin", {"turn": state.turn, "frozen": frozen, "charged": batteries,
		"hands": state.players.map(func(u: Dictionary) -> Dictionary: return {"unit": u.id, "hand": u.hand.duplicate(true), "rerolls": u.rerolls})})

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
	unit.firing_target = str(unit.get("target", ""))
	unit.resonance = int(unit.get("initial_resonance", 0))
	unit.previous_fired = false
	unit.previous_amount = 0
	unit.previous_colors = []
	unit.previous_socket = -1
	unit.amplify = 1.0
	unit.nullify_next = false
	unit.cut_step_bonus = int(unit.passive.get("amount", 1)) if str(unit.get("passive", {}).get("kind", "")) == "first_gem_cut_step" else 0
	unit.fired_sockets = []
	unit.fizzled_sockets = []
	unit.repeat_next = 0
	unit.replaying = false
	var starting_pyrite: int = DeepRules.pyrite(unit)
	var sockets: Array = []
	var totals: Dictionary = {"damage": 0, "block": 0, "heal": 0, "gold": 0, "poison": 0, "fires": 0, "fizzles": 0}
	for socket in range(unit.rail.size()):
		if not unit.rail[socket] is Dictionary:
			sockets.append({"socket": socket, "empty": true})
			continue
		var stone: Dictionary = stone_at(unit, socket)
		var context: Dictionary = rail_context(copy, unit, socket)
		var preview: Dictionary = DeepStone.evaluate(stone, unit.hand, context)
		var fires: int = maxi(1, int(preview.get("fires", 1))) if preview.active else 0
		var event: Dictionary = {}
		for repeat in range(maxi(1, fires)):
			event = resolve_gem(copy, unit, socket, {"dry": true, "retrigger": repeat > 0}, rng)
		var entry: Dictionary = {"socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill), "worn": str(stone.get("worn_from", "")),
			"active": str(event.get("kind", "")) == "gem_fire",
			"reason": str(event.get("reason", "")), "dice": event.get("dice", []), "resonance": int(event.get("resonance", 0)),
			"harmony": bool(event.get("harmony", false)), "cut_step": int(event.get("cut_step", 0)), "fires": fires,
			"effects": event.get("effects", []), "trigger": DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(preview.get("cut_step", 0)))}
		if entry.active:
			totals.fires += fires
			for effect in event.get("effects", []):
				if str(effect.get("kind", "")) == "appraise":
					for hit in effect.get("hits", []):
						totals.damage += int(hit.get("raw", 0))
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
	totals.gold = DeepRules.pyrite(unit) - starting_pyrite
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
