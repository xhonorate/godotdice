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
## The beat a run of blows is played on: one bolt every BOLT_GAP, a breath after each effect,
## and the whole run squeezed into HIT_SPAN once there are enough of them to run past it. A
## gem that lands twenty times over (Thousand Cuts) played every blow at a single blow's pace,
## which outlasted the step it belonged to and left the turn moving on underneath it. The
## battle screen paces itself by exactly these, so what is reserved here is what is drawn.
const BOLT_GAP: float = 0.085
const HIT_BREATH: float = 0.16
const HIT_STEP: float = BOLT_GAP + HIT_BREATH
const HIT_SPAN: float = 1.2
const HAND_KINDS: Array = ["raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high"]
const SELF_KINDS: Array = ["amplify_next", "cut_step_next", "grant_reroll", "retrigger_previous", "quality_bonus", "sparkle",
	"coin_flip", "resonance", "replay_color", "replay_fizzled", "rank_buff", "repeat_next", "void_copy", "gem_rank", "upgrade_faces", "stake", "appraise"]
## How long a rail may grow mid-fight. An Echo adds a gem a turn and nothing else does, so
## this is only there to keep a very long fight from laying out a rail no screen can hold.
const MAX_RAIL: int = 24
## What a rail's rung is made of: once the last creature falls, these still play out to the
## end of the rail that was firing, and nothing else does.
const RUNG_STEPS: Array = ["gem", "birthstone", "rail_end"]
const BIRTHSTONE_KINDS: Array = ["replay_rail", "tick_poison", "stone_drop", "pot"]

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
		"birthstone": character.get("birthstone", {}).duplicate(true), "flips": 0, "fired_sockets": [], "fizzled_sockets": [], "tailings_paid": {},
		"rank_buff": {"carat": 0, "cut": 0}, "gem_buffs": {}, "buff_sources": {}, "pyrite_delta": 0, "repeat_next": 0, "replaying": false, "stone_drops": 0, "pot": 0,
		"hp": hp if hp >= 0 else max_hp, "max_hp": max_hp, "block": 0, "statuses": {}, "dice": dice.duplicate(true), "hand": [],
		"rerolls": 0, "rerolls_max": 0, "locked": false, "target": "", "passive": character.get("passive", {"kind": "none"}),
		"resonance": 0, "initial_resonance": 0, "previous_fired": false, "previous_amount": 0, "previous_colors": [], "previous_socket": - 1,
		"amplify": 1.0, "cut_step_bonus": 0, "nullify_next": false, "block_lost": 0, "block_lost_accum": 0,
		"healed": 0, "dealt": 0, "dealt_last_turn": 0, "gold": 0, "once": {}, "downed": false, "connected": true,
		"eligible_turn": 1, "buried": [], "clouded": [], "stolen_dice": 0, "granted_rerolls": 0, "sparkle": 0,
		"quality_bonus": 0, "run_mods": {}, "skipped_turn": - 1, "fired_count": 0, "raw_drops": 0, "damp_carry": 0}
	DeepStone.normalize_rail(unit)
	return unit

static func begin(players: Array, creature_keys: Array, context: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	## `threat` is the depth the creatures are bred for, which a run that has pushed on from
	## one mine into the next finds a little deeper than the floor it stands on.
	var state: Dictionary = {"turn": 0, "phase": "planning", "outcome": "", "depth": int(context.get("depth", 1)),
		"threat": int(context.get("threat", context.get("depth", 1))),
		"party": players.size(), "elite": bool(context.get("elite", false)), "warden": bool(context.get("warden", false)),
		"players": players.duplicate(true), "enemies": [], "queue": [], "seq": 0}
	## Each rail is laid flat for the fight: a socket's gem, then the Void gems riding it.
	for unit in state.players:
		DeepStone.flatten_rail(unit)
		## What a broken gem grows back as: the rail this hero walked in with.
		unit.initial_rail = unit.rail.duplicate(true)
		## House Money: the Gambler never sits down at an empty table. A share of what he
		## owns is on it before the first die falls, and like everything else staked it has
		## left the bank already — it comes back only if he wins.
		if str(unit.get("passive", {}).get("kind", "")) == "pot_share":
			stake(unit, DeepRules.pyrite(unit) * int(unit.passive.get("amount", 10)) / 100)
	## A Rift Warden is one of the earlier bosses remembered with one trait more, picked by
	## the seed before the fight so every guest sees the same creature.
	var extra: Dictionary = {}
	if bool(context.get("remembered", false)):
		var remembered: String = str(context.get("extra_trait", ""))
		if remembered.is_empty():
			remembered = str(DeepRng.pick(rng_creatures, DeepContent.REMEMBERED_TRAITS))
		extra = {"name_prefix": "The Remembered ", "traits": {remembered: 25 if remembered == "sturdy" else true}, "remembered": remembered}
	state.next_enemy = 0
	for key in creature_keys:
		var foe: Dictionary = DeepCreatures.make(str(key), _enemy_id(state), state.threat, players.size(), context.get("scale", {}), rng_creatures, extra)
		if not extra.is_empty():
			foe.remembered = str(extra.get("remembered", ""))
		state.enemies.append(foe)
		_bring_escorts(state, foe, rng_creatures)
	_begin_turn(state, rng_dice, rng_creatures)
	return state

static func _enemy_id(state: Dictionary) -> String:
	var id: String = "e%d" % int(state.get("next_enemy", 0))
	state.next_enemy = int(state.get("next_enemy", 0)) + 1
	return id

static func _bring_escorts(state: Dictionary, leader: Dictionary, rng: RandomNumberGenerator) -> void:
	## The creatures written in beside it: a Prismarch's prisms, a Heartrot's tendrils. They
	## stand after it and are bred to the same depth; the leader knows them by id.
	for key in DeepCreatures.definition(leader).get("escorts", []):
		var escort: Dictionary = DeepCreatures.make(str(key), _enemy_id(state), int(leader.get("depth", state.threat)), state.players.size(), leader.get("scale", {}), rng)
		escort.escort_of = str(leader.id)
		escort.summoned = true
		state.enemies.append(escort)
		leader.escorts.append(str(escort.id))

static func targetable(units: Array) -> Array:
	## The creatures a gem can reach: alive, and not under the floor.
	return living(units).filter(func(u: Dictionary) -> bool: return not bool(u.get("burrowed", false)))

static func max_creatures() -> int:
	return int(DeepContent.constant("max_creatures", 4))

static func summon(state: Dictionary, source: Dictionary, key: String, count: int, rng: RandomNumberGenerator) -> Array:
	## Creatures called into the fight beside the caller, as many as there is room for: a
	## fight never holds more than `max_creatures` standing. They act from the next turn.
	var made: Array = []
	for _each in range(maxi(0, count)):
		if living(state.enemies).size() >= max_creatures():
			break
		var foe: Dictionary = DeepCreatures.make(key, _enemy_id(state), int(source.get("depth", state.get("threat", 1))), state.players.size(), source.get("scale", {}), rng)
		foe.summoned = true
		foe.summoned_by = str(source.id)
		## A Heartrot growing a tendril: what it grows is one of its escorts, and feeds it.
		if DeepCreatures.definition(source).get("escorts", []).has(key):
			foe.escort_of = str(source.id)
			source.escorts.append(str(foe.id))
		DeepCreatures.prepare(foe)
		DeepCreatures.refresh_bonuses(foe, state)
		var at: int = state.enemies.find(source)
		state.enemies.insert(at + 1 if at >= 0 else state.enemies.size(), foe)
		made.append(str(foe.id))
	return made

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
			var dues: Dictionary = _pay_dues(state, unit, chosen)
			## A lantern's price: every creature that gifts rerolls takes blood for each one
			## spent (a Will-o'-Wisp twice as much), and a Cinder Moth scorches instead.
			var drain: int = 0
			var scorch: int = 0
			for foe in living(state.enemies):
				if DeepCreatures.has_trait(foe, "gift_rerolls"):
					var burns: int = DeepCreatures.trait_value(foe, "reroll_scorch", 0)
					drain += DeepCreatures.trait_value(foe, "reroll_drain", 0 if burns > 0 else 1)
					scorch += burns
			if drain > 0:
				for victim in living(state.players):
					victim.hp = maxi(1, int(victim.hp) - drain)
			if scorch > 0:
				for victim in living(state.players):
					victim.statuses.scorched = int(victim.statuses.get("scorched", 0)) + scorch
			return {"ok": true, "event": _event(state, "reroll", {"unit": player_id, "dice": chosen, "hand": unit.hand.duplicate(true),
				"rerolls": unit.rerolls, "drain": drain, "scorch": scorch, "loaded": loaded, "dues": dues, "resonance": int(unit.resonance)})}
		"flip":
			## Sleight shifts a die to the opposite parity, using its range complement when possible.
			if bool(unit.get("locked", false)):
				return _refuse("you have locked in")
			if int(unit.get("flips", 0)) <= 0:
				return _refuse("no parity shift left this turn")
			var wanted_id: String = str(cmd.get("die", ""))
			for roll in unit.hand:
				if str(roll.get("die_id", "")) != wanted_id or bool(roll.get("phantom", false)):
					continue
				if str(roll.get("kind", "plain")) != "plain":
					return _refuse("only a plain face can be shifted")
				var top: int = maxi(1, int(roll.get("top", 6)))
				var previous: int = int(roll.get("value", 1))
				var shifted: int = clampi(top + 1 - previous, 1, DeepDice.VALUE_CAP)
				if shifted % 2 == previous % 2 and top > 1:
					shifted = previous + 1 if previous < top else previous - 1
				roll.value = shifted
				roll.flipped = true
				unit.flips = int(unit.flips) - 1
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
		if bool(state.get("cleared", false)) and not str(s.get("kind", "")) in RUNG_STEPS:
			## The last creature fell while a rail was firing and that rail has run out:
			## nothing else in the turn is played, and the fight ends here.
			_close_cleared(state)
			return step(state, rng_dice, rng_creatures)
		var event: Dictionary = _perform(state, s, rng_dice, rng_creatures)
		if not event.is_empty():
			return event
	if bool(state.get("cleared", false)):
		_close_cleared(state)
		return step(state, rng_dice, rng_creatures)
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
			unit.tailings_paid = {}
			unit.repeat_next = 0
			unit.replaying = false
			unit.fired_count = 0
			unit.damp_carry = 0
			if str(unit.get("passive", {}).get("kind", "")) == "first_gem_cut_step":
				unit.cut_step_bonus = int(unit.passive.get("amount", 1))
			## Second Wind is paid at rail_end, on the Resonance the rail built; the rerolls it
			## banks are already counted here, because planning is over.
			return _event(state, "rail_begin", {"unit": unit.id, "unused_rerolls": int(unit.get("rerolls", 0)), "healed": 0, "resonance": int(unit.resonance)})
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
			## Second Wind: the Knight banks the rerolls he did not spend, each one worth the
			## Resonance his rail just built. It is paid here because at rail_begin there is
			## no Resonance yet to pay it with.
			var resonance: int = int(unit.get("resonance", 0))
			var unused: int = int(unit.get("rerolls", 0))
			var healed: int = 0
			if str(unit.get("passive", {}).get("kind", "")) == "heal_resonance_per_unused_reroll" and unused > 0 and resonance > 0:
				healed = _heal(unit, resonance * unused)
			## The rail that killed the last creature has had its say: now the fight is won.
			if bool(state.get("cleared", false)):
				_close_cleared(state)
			return _event(state, "rail_end", {"unit": unit.id, "resonance": resonance, "unused_rerolls": unused, "healed": healed})
		"creatures_begin":
			## A creature's block has stood through one volley of gems; whatever is left of it
			## falls away as the creatures take their turn.
			for foe in state.enemies:
				_reset_defenses(foe)
				foe.rally_bonus = 0
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
			var fields: Dictionary = {"unit": foe.id}
			## Up out of the floor: it can be hit again, and its first die may bring it up biting.
			if bool(foe.get("burrowed", false)):
				foe.burrowed = false
				foe.emerging = true
				fields.emerged = true
			## What it did to itself last turn wears off as it acts again: the blows it was
			## sending back, the colours it was drinking.
			if int(foe.get("reflect", 0)) > 0 or not foe.get("absorb", []).is_empty():
				foe.reflect = 0
				foe.absorb = []
				fields.guard_ended = true
			## A Warden that answers every blow with a Spikes aura has them up again for the next rail.
			var spikes: int = DeepCreatures.trait_value(foe, "spikes", 0)
			if spikes > 0:
				foe.statuses.spikes = maxi(int(foe.statuses.get("spikes", 0)), spikes)
			## Tendrils grow back for a Heartrot that has not been pruned all at once.
			var regrown: Array = _regrow_escorts(state, foe, rng_creatures)
			if not regrown.is_empty():
				fields.regrown = regrown
			## A creature with no dice of its own yet (the Infinite Void) is not bound: it grows one first.
			if int(foe.statuses.get("stun", 0)) > 0 or (not foe.dice.is_empty() and int(foe.suppressed) >= foe.dice.size()):
				var why: String = "bound"
				if int(foe.statuses.get("stun", 0)) > 0:
					why = "stun"
					foe.statuses.stun = int(foe.statuses.stun) - 1
					foe.stun_streak = int(foe.get("stun_streak", 0)) + 1
					## Steadfast: a stun never lands two actions running.
					if DeepCreatures.has_trait(foe, "steadfast"):
						foe.stun_guard = true
					if int(foe.stun_streak) >= 3:
						foe.statuses.stun = 0
						foe.statuses.combo_breaker = 2
						foe.stun_streak = 0
				else:
					foe.stun_streak = 0
				DeepCreatures.finish(foe)
				_tick_charge(state, foe)
				return _event(state, "skip", {"unit": foe.id, "why": why, "combo_breaker": int(foe.statuses.get("combo_breaker", 0)) == 2})
			foe.stun_streak = 0
			foe.stun_guard = false
			## A blow it has been winding up: another action closer, or let go now.
			var charge: Dictionary = _tick_charge(state, foe)
			if not charge.is_empty():
				fields.charge = charge
				if charge.has("release"):
					var release: Dictionary = {"move": str(charge.get("name", "Release")), "index": -1, "effects": charge.release, "dice": [],
						"combo": true, "trigger": {"kind": "each_turn"}, "roll_index": -1, "release": true}
					state.queue.push_front({"kind": "enemy_move", "unit": foe.id, "move": release})
					state.queue.push_front({"kind": "enemy_ability", "unit": foe.id, "move": release})
			state.queue.push_front({"kind": "enemy_roll", "unit": foe.id})
			## What it does as its action opens, before any die: the Infinite Void's Expansion.
			var opening: Array = []
			var begin_ctx: Dictionary = DeepCreatures.context(foe, state, -1)
			begin_ctx.action_begin = true
			for called in DeepCreatures.moves_called(foe, "action_begin"):
				var index: int = int(called.index)
				if DeepCreatures.move_clouded(foe, index):
					continue
				var trig: Dictionary = DeepPatterns.evaluate(called.move.get("trigger", {}), 0, DeepHand.analyze([]), begin_ctx)
				if not bool(trig.get("active", false)):
					continue
				foe.used_combos.append(index)
				foe.move_states[index] = "activated"
				opening.append(DeepCreatures.resolved_move(foe, state, called.move, index, trig, true, -1))
			for move_index in range(opening.size() - 1, -1, -1):
				state.queue.push_front({"kind": "enemy_move", "unit": foe.id, "move": opening[move_index]})
				state.queue.push_front({"kind": "enemy_ability", "unit": foe.id, "move": opening[move_index]})
			## A countdown it shows: the Flee it is leaving on, the lavafall it is bringing down.
			var flee: int = DeepCreatures.trait_value(foe, "flee", 0)
			if flee > 0:
				fields.flee_in = maxi(0, flee - int(foe.get("turns_acted", 0)))
			return _event(state, "enemy_begin", fields)
		"enemy_roll":
			var foe: Dictionary = enemy(state, str(s.unit))
			if foe.is_empty() or int(foe.hp) <= 0 or done(state):
				return {}
			var dice: Array = DeepCreatures.effective_dice(foe)
			var available: int = maxi(0, dice.size() - int(foe.suppressed))
			var index: int = int(foe.next_die)
			if index >= available or bool(foe.get("burrowed", false)) or bool(foe.get("stopped", false)):
				## Its dice are spent, or it has gone under the floor or stumbled, and left the rest unrolled.
				DeepCreatures.finish(foe)
				var closing: Dictionary = {"unit": foe.id, "burrowed": bool(foe.get("burrowed", false))}
				var flee: int = DeepCreatures.trait_value(foe, "flee", 0)
				if flee > 0 and int(foe.get("turns_acted", 0)) >= flee and int(foe.hp) > 0:
					## It has what it came for: off into the dark with everything it took.
					foe.fled = true
					foe.hp = 0
					closing.fled = true
					closing.stolen = int(foe.get("stolen_gold", 0))
					_return_gems(state, foe)
					_check_outcome(state)
				return _event(state, "enemy_end", closing)
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
			if int(move.index) >= 0 and int(move.index) < foe.move_states.size():
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
	## What a Tailings here has still to be paid for: every gem that stayed dark this turn
	## since this stone last collected, never counting its own socket. Keyed by the stone, so
	## a replay finds the fizzles it already took and a Doublet wearing it collects its own.
	var dark: Array = unit.get("fizzled_sockets", [])
	var unpaid: int = 0
	for index in range(int(unit.get("tailings_paid", {}).get(str(stone.get("id", "")), 0)), dark.size()):
		if int(dark[index]) != socket:
			unpaid += 1
	var enemy_poison: int = 0
	var carat_cap: int = 0
	for foe in living(state.enemies):
		enemy_poison += int(foe.statuses.get("poison", 0))
		## An Assayer in the room weighs every gem at no more than its limit.
		var limit: int = DeepCreatures.trait_value(foe, "carat_cap", 0)
		if limit > 0:
			carat_cap = limit if carat_cap <= 0 else mini(carat_cap, limit)
	return {"unit": unit, "resonance": int(unit.get("resonance", 0)), "previous_fired": bool(unit.get("previous_fired", false)),
		"previous_amount": int(unit.get("previous_amount", 0)), "amplify": float(unit.get("amplify", 1.0)),
		"cut_step_bonus": int(unit.get("cut_step_bonus", 0)) + int(buff.get("cut", 0)) + int(gem_buff.get("cut", 0)), "carat_bonus": carat_bonus,
		"clarity_bonus": int(gem_buff.get("clarity", 0)), "enemy_poison": enemy_poison, "carat_cap": carat_cap, "fizzles": unpaid,
		## Only what was won mid-fight, apart from everything else folded into the bonuses
		## above, so the close look can name the ranks that were raised and what raised them.
		"fight_buffs": {"carat": int(buff.get("carat", 0)) + int(gem_buff.get("carat", 0)),
			"cut": int(buff.get("cut", 0)) + int(gem_buff.get("cut", 0)), "clarity": int(gem_buff.get("clarity", 0))},
		"buff_sources": unit.get("buff_sources", {}),
		"dulled": int(unit.get("statuses", {}).get("dulled", 0)),
		"depth": int(state.get("depth", 1)),
		"turn": int(state.get("turn", 1)), "party": int(state.get("party", 1)), "socket": socket_color,
		"retrigger": bool(opts.get("retrigger", false)), "force_fire": bool(opts.get("force", false))}

static func worn_socket(unit: Dictionary, socket: int) -> int:
	## What a Doublet at this socket wears: the nearest gem behind it that is not itself an
	## opal. Skipping opals is what makes a Doublet terminate — it can never end up wearing
	## a skill that would send it looking again — and it lets two Doublets share one gem.
	## It looks as far back along the rail as it must, past empty sockets and past other
	## opals; with nothing behind it to wear it is a thin slice and only rings.
	if not unit.rail[socket] is Dictionary or str(DeepStone.skill_of(unit.rail[socket]).get("wears", "")) != "prev":
		return -1
	for behind in range(socket - 1, -1, -1):
		if unit.rail[behind] is Dictionary and not DeepStone.is_opal(unit.rail[behind]):
			return behind
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
	## A Null Shade in the room: the rail rings for only part of what it should. What is lost
	## is carried in hundredths, so two gems at half each still make one.
	var damp: int = 0
	for foe in living(state.enemies):
		damp = maxi(damp, DeepCreatures.trait_value(foe, "resonance_damp", 0))
	if damp > 0:
		var pooled: int = gain * (100 - clampi(damp, 0, 100)) + int(unit.get("damp_carry", 0))
		gain = pooled / 100
		unit.damp_carry = pooled % 100
	unit.resonance = int(unit.get("resonance", 0)) + gain
	var results: Array = []
	var previous_socket: int = int(unit.get("previous_socket", -1))
	var reactions: Dictionary = {}
	## Who is throwing, and in what colour: a creature that drinks a colour, holds the
	## gem that hit it hardest or answers whoever hurt it most reads these off every blow.
	unit.firing_colors = ev.get("colors", []).duplicate()
	unit.firing_stone = {"stone_id": str(stone.get("id", "")), "socket": socket}
	unit.fired_count = int(unit.get("fired_count", 0)) + 1
	## Backlash: with a Riftling Swarm in the room, every gem that fires costs its owner a point
	## of blood, wherever it sits on the rail. Never the last point.
	var backlash: int = 0
	if not dry:
		for foe in living(state.enemies):
			if DeepCreatures.has_trait(foe, "backlash"):
				backlash = 1
		if backlash > 0:
			unit.hp = maxi(1, int(unit.hp) - backlash)
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
	unit.erase("firing_colors")
	unit.erase("firing_stone")
	## A Refractor grows a point stronger for every colour of gem it sees fired, once a colour.
	var fed: Array = []
	if not dry:
		for foe in living(state.enemies):
			if not DeepCreatures.has_trait(foe, "colour_strength"):
				continue
			for colour in ev.get("colors", []):
				if not foe.get("seen_colors", []).has(colour):
					foe.seen_colors.append(colour)
					foe.statuses.strength = int(foe.statuses.get("strength", 0)) + 1
					fed.append({"unit": str(foe.id), "color": str(colour), "strength": int(foe.statuses.strength)})
	if int(ev.get("next_cut_step", 0)) > 0:
		unit.cut_step_bonus = int(unit.cut_step_bonus) + int(ev.next_cut_step)
	unit.previous_fired = true
	unit.previous_amount = DeepStone.total_amount(ev)
	unit.previous_colors = ev.get("colors", [])
	unit.previous_socket = socket
	if not unit.get("fired_sockets", []).has(socket):
		unit.fired_sockets.append(socket)
	## A Tailings collects on every fizzle it read, and none of them pays it again this turn.
	if str(DeepStone.skill_of(stone).get("trigger", {}).get("kind", "")) == "fizzles":
		if not unit.has("tailings_paid"):
			unit.tailings_paid = {}
		unit.tailings_paid[str(stone.id)] = unit.get("fizzled_sockets", []).size()
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
		"die_boost": float(ev.get("die_boost", 1.0)), "materials": DeepDice.matching_materials(DeepStone.rolls_of(unit.hand, ev.get("dice", [])), ev.get("colors", [])),
		"retrigger": retrigger, "replay": bool(opts.get("replay", false)), "scale": scale, "hp_cost": hp_cost, "fires": int(ev.get("fires", 1)),
		"forced": bool(opts.get("force", false)), "promised": promised if not retrigger else 0, "worn": str(stone.get("worn_from", "")),
		"backlash": backlash, "fired_count": int(unit.get("fired_count", 0)), "damped": damp > 0, "fed": fed,
		"duration": BASE_DURATION.gem_fire + maxf(0.1 * float(results.size()), hits_span(results))})

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
			## Each tier reads its own results and no one else's, the way a gem does: All In
			## is paid for the blow All In landed, not for what Raise took off them first.
			var reactions: Dictionary = {}
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
	## Each tier's blows are animated on their own beat, so the longest of them is what the
	## step has to hold: a Thousand Cuts is one tier throwing twenty bolts.
	var longest: float = 0.0
	for entry in tiers:
		if bool(entry.active):
			longest = maxf(longest, hits_span(entry.effects))
	return _event(state, "birthstone", {"unit": unit.id, "name": str(def.get("name", "Birthstone")), "style": str(def.get("style", "")),
		"tiers": tiers, "fired": fired, "dice": all_dice, "resonance": resonance, "replay": replay, "promised": promised,
		"duration": (BASE_DURATION.birthstone + 0.2 * tiers.filter(func(x: Dictionary) -> bool: return bool(x.active)).size() + longest) if fired else BASE_DURATION.gem_fizzle})

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
		"pot":
			## What is on the table. Staking moves Pyrite out of the bank in the same breath,
			## so what the Gambler owns is the ceiling on what he can ever have riding, and a
			## Bust leaves the lot behind.
			var mode: String = str(effect.get("pot_mode", "ante"))
			var before: int = int(unit.get("pot", 0))
			var moved: int = 0
			if mode == "lose":
				if not dry:
					unit.pot = 0
			else:
				var wanted: int = amount if mode == "ante" else (before if mode == "double" else DeepRules.pyrite(unit))
				moved = stake(unit, wanted) if not dry else mini(maxi(0, wanted), DeepRules.pyrite(unit))
			out.mode = mode
			out.was = before
			out.moved = moved
			out.total = int(unit.get("pot", 0)) if not dry else before + moved
	return out

static func stake(unit: Dictionary, wanted: int) -> int:
	## Move Pyrite from the bank onto the table, as much of `wanted` as there is to move.
	## Returns what actually went in. Spending rides on `pyrite_delta` the way Wager and
	## Stake do, so the bank reads right for everything else that asks it mid-fight.
	var moved: int = clampi(wanted, 0, DeepRules.pyrite(unit))
	if moved <= 0:
		return 0
	unit.pot = int(unit.get("pot", 0)) + moved
	unit.pyrite_delta = int(unit.get("pyrite_delta", 0)) - moved
	return moved

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
	return thrown

static func _pay_dues(state: Dictionary, unit: Dictionary, ids: Array = []) -> Dictionary:
	## What a throw owed the table, paid out: Crystal rings, Fool's Gold and a Golden face
	## pay pyrite, Blood takes its price for being thrown again, and the Glass that broke is
	## gone. `ids` limits it to the dice just thrown; empty means the whole hand.
	var thrown: Array = []
	for roll in unit.get("hand", []):
		if ids.is_empty() or ids.has(str(roll.get("die_id", ""))):
			thrown.append(roll)
	var dues: Dictionary = DeepDice.throw_dues(thrown)
	if int(dues.resonance) > 0:
		## Planning is before the rail begins, and the rail begins from what was banked, so
		## a Crystal die has to put its Resonance in both hands or the throw is forgotten.
		unit.initial_resonance = int(unit.get("initial_resonance", 0)) + int(dues.resonance)
		unit.resonance = int(unit.get("resonance", 0)) + int(dues.resonance)
	if int(dues.pyrite) > 0:
		unit.pyrite_delta = int(unit.get("pyrite_delta", 0)) + int(dues.pyrite)
	if int(dues.hp) > 0 and not bool(unit.get("downed", false)):
		unit.hp = maxi(1, int(unit.hp) - int(dues.hp))
	for id in dues.shattered:
		break_die(state, unit, str(id), "shattered")
	dues.hp_after = int(unit.hp)
	return dues

static func break_die(_state: Dictionary, unit: Dictionary, die_id: String, reason: String = "broken") -> bool:
	## A die is gone: out of the bowl and out of the hand at once. The slot it held is
	## remembered, and at the start of the next turn the hero has that die back the way they
	## came down with it — no pattern they cut into it, no etching, no material.
	var at: int = -1
	for index in range(unit.get("dice", []).size()):
		if str(unit.dice[index].get("id", "")) == die_id:
			at = index
			break
	if at < 0:
		return false
	if str(unit.dice[at].get("material", "")) == "granite":
		return false
	if not unit.has("broken_dice"):
		unit.broken_dice = []
	unit.broken_dice.append({"at": at, "id": die_id, "reason": reason})
	unit.dice.remove_at(at)
	for index in range(unit.get("hand", []).size() - 1, -1, -1):
		if str(unit.hand[index].get("die_id", "")) == die_id:
			unit.hand.remove_at(index)
	return true

static func break_gem(_state: Dictionary, unit: Dictionary, socket: int) -> bool:
	## A gem is destroyed. The socket stands empty for a turn, and then the stone this hero
	## walked in with is in it again.
	if socket < 0 or socket >= unit.get("rail", []).size() or not unit.rail[socket] is Dictionary:
		return false
	if not unit.has("broken_gems"):
		unit.broken_gems = []
	unit.broken_gems.append({"at": socket, "stone_id": str(unit.rail[socket].get("id", ""))})
	unit.rail[socket] = null
	return true

static func _regrow(unit: Dictionary) -> Dictionary:
	## The start of a turn: what was broken last turn comes back. A die returns as the one
	## its hero went down with; a gem returns as the one that was in that socket.
	var out: Dictionary = {"dice": [], "sockets": []}
	var character: Dictionary = DeepContent.character(str(unit.get("character", "")))
	for entry in unit.get("broken_dice", []):
		var at: int = clampi(int(entry.get("at", 0)), 0, unit.get("dice", []).size())
		var refs: Array = character.get("dice", [])
		var ref: Variant = refs[int(entry.get("at", 0))] if int(entry.get("at", 0)) < refs.size() else "D6"
		var die: Dictionary = DeepForge.die_from(ref, str(entry.get("id", "")))
		unit.dice.insert(at, die)
		out.dice.append(die.duplicate(true))
	unit.broken_dice = []
	for entry in unit.get("broken_gems", []):
		var socket: int = int(entry.get("at", -1))
		var was: Array = unit.get("initial_rail", [])
		if socket >= 0 and socket < unit.get("rail", []).size() and socket < was.size() and was[socket] is Dictionary:
			unit.rail[socket] = was[socket].duplicate(true)
			out.sockets.append(socket)
	unit.broken_gems = []
	return out

static func _blood_feeds(state: Dictionary, dead: Dictionary) -> void:
	## Something died where a Blood die could see it. The face it is showing climbs by one,
	## on the die itself, for the rest of the run.
	if str(dead.get("side", "")) != "enemy":
		return
	for unit in state.get("players", []):
		for roll in unit.get("hand", []):
			if str(roll.get("material", "")) != "blood" or bool(roll.get("phantom", false)):
				continue
			for die in unit.get("dice", []):
				if str(die.get("id", "")) != str(roll.get("die_id", "")):
					continue
				var index: int = int(roll.get("face", -1))
				if index < 0 or index >= die.get("faces", []).size():
					continue
				die.faces[index].value = mini(DeepDice.VALUE_CAP, int(die.faces[index].get("value", 0)) + 1)
				roll.value = DeepDice.face_value(die.faces[index])
				roll.top = DeepDice.top(die)
				roll.fed = true

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

static func blows(effects: Array) -> int:
	## How many bolts these effects throw: one a hit, one more for every repeat and every
	## creature the blow splashes onto.
	var count: int = 0
	for effect in effects:
		if str(effect.get("kind", "")) == "damage":
			count += maxi(1, int(effect.get("repeat", 1))) * (1 + effect.get("splash", []).size())
	return count

static func hit_pace(effects: Array) -> float:
	## How much of one blow's screen time each blow in this batch gets: all of it up to a
	## handful, then less and less, so the run of them always fits HIT_SPAN.
	var span: float = HIT_STEP * float(blows(effects))
	return 1.0 if span <= HIT_SPAN else HIT_SPAN / span

static func hits_span(effects: Array) -> float:
	## How long these effects take to play, once they have closed up.
	return minf(HIT_STEP * float(blows(effects)), HIT_SPAN)

static func _credit_buff(unit: Dictionary, rank: String, socket: int) -> void:
	## Which skill raised this rank on the rail this fight. The rail carries the numbers; this
	## carries the reason, so the close look can say where a gem's extra weight came from
	## rather than leaving the player to guess which of five gems did it.
	var skill: String = "BIRTHSTONE" if socket < 0 else str(unit.rail[socket].get("skill", "")) if unit.rail[socket] is Dictionary else ""
	if skill.is_empty():
		return
	var sources: Dictionary = unit.get("buff_sources", {})
	var named: Array = sources.get(rank, [])
	if not named.has(skill):
		named.append(skill)
	sources[rank] = named
	unit.buff_sources = sources

static func _void_copy(unit: Dictionary, source: Dictionary) -> Dictionary:
	## An Echo's copy of a gem: the same skill at the same four C's, with Void worked into
	## it so it rides a socket rather than taking one. It is made inside a fight and never
	## leaves it — nothing a fight settles carries the rail home — so it is no stone anybody
	## owns, and its id is its own so the buffs and once-a-fights of the gem it copies are
	## not also its.
	var copy: Dictionary = source.duplicate(true)
	unit.void_copies = int(unit.get("void_copies", 0)) + 1
	copy.id = "%s-void%d" % [str(source.get("id", "gem")), int(unit.void_copies)]
	var inclusions: Array = copy.get("inclusions", []).duplicate()
	if not inclusions.has("VOID"):
		inclusions.append("VOID")
	copy.inclusions = inclusions
	copy.appraised = true
	copy.inclusions_revealed = true
	copy.temporary = true
	return copy

static func _join_rail(state: Dictionary, unit: Dictionary, at: int, stone: Dictionary) -> void:
	## A gem joins a rail already laid flat, in the middle of a fight. Every number that
	## names a place on that rail — what is still queued, what has fired, what stayed dark,
	## what is buried or clouded — is counted on past the new one, so nothing afterwards
	## lights or wakes the wrong gem.
	DeepStone.ride_rail(unit, at, stone)
	for entry in state.get("queue", []):
		if str(entry.get("unit", "")) == str(unit.id) and int(entry.get("socket", -1)) >= at:
			entry.socket = int(entry.socket) + 1
	for field in ["fired_sockets", "fizzled_sockets", "buried", "clouded"]:
		var places: Array = unit.get(field, [])
		for index in range(places.size()):
			if int(places[index]) >= at:
				places[index] = int(places[index]) + 1
	if int(unit.get("previous_socket", -1)) >= at:
		unit.previous_socket = int(unit.previous_socket) + 1

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
			_credit_buff(unit, rank, socket)
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
			## shows. The amount is how many of them it can wake, earliest first — two, or
			## all of them when it is Flawless. Never another opal, so no two Matrices wake
			## each other.
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
				_credit_buff(unit, rank, socket)
			out.rank = rank
			out.total = int(buff.get(rank, 0))
		"repeat_next":
			## A Prelude: the next thing to resolve goes again, the Birthstone included.
			if not dry:
				unit.repeat_next = int(unit.get("repeat_next", 0)) + maxi(0, amount)
			out.total = int(unit.get("repeat_next", 0))
		"void_copy":
			## An Echo: a Void copy of the last gem that fired joins the rail riding this
			## socket, and fires right after it for the rest of the fight. Never a copy of
			## another opal — that one rule is what keeps two Echoes from filling a rail
			## with each other. The copy is the fight's own: nothing carries it out, so it
			## is gone the moment the fight is.
			var source_socket: int = previous_socket
			var copyable: bool = socket >= 0 and source_socket >= 0 and source_socket < unit.rail.size() \
				and unit.rail[source_socket] is Dictionary and repeatable(unit, source_socket)
			if dry or not copyable:
				out.nothing = true
			else:
				var source: Dictionary = unit.rail[source_socket]
				out.stone_id = str(source.get("id", ""))
				var made: Array = []
				for _copy in range(maxi(1, amount)):
					if unit.rail.size() >= MAX_RAIL:
						break
					made.append(socket + 1 + made.size())
					_join_rail(state, unit, int(made[-1]), _void_copy(unit, source))
				out.sockets = made
				if made.is_empty():
					out.nothing = true
				else:
					## They stand after the gem that made them and the rail has not reached
					## them yet, so they play this turn as well as every turn after it.
					var fresh: Array = []
					for at in made:
						fresh.append({"kind": "gem", "unit": unit.id, "socket": int(at)})
					state.queue = fresh + state.queue
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
	## A burrowed creature is under the floor: a gem finds another, or waits.
	var foes: Array = targetable(state.enemies) if is_player else living(state.players)
	match target:
		"self":
			return [source]
		"allies":
			return friends
		"allies_other":
			return friends.filter(func(u: Dictionary) -> bool: return str(u.id) != str(source.id))
		"heroes":
			return foes if not is_player else friends
		"hero_least_block", "hero_most_hp", "hero_most_gold", "hero_top_damage", "hero_top_dealt":
			## One player, picked by what the creature is after.
			var party: Array = living(state.players) if not is_player else friends
			if party.is_empty():
				return []
			var pick: Dictionary = party[0]
			for unit in party:
				var better: bool = false
				match target:
					"hero_least_block": better = int(unit.block) < int(pick.block)
					"hero_most_hp": better = int(unit.hp) > int(pick.hp)
					"hero_most_gold": better = DeepRules.pyrite(unit) > DeepRules.pyrite(pick)
					"hero_top_damage": better = int(source.get("hurt_by", {}).get(str(unit.id), 0)) > int(source.get("hurt_by", {}).get(str(pick.id), 0))
					"hero_top_dealt": better = int(unit.get("dealt_last_turn", 0)) > int(pick.get("dealt_last_turn", 0))
				if better:
					pick = unit
			return [pick]
		"hero_marked":
			var party: Array = living(state.players) if not is_player else friends
			return party.filter(func(u: Dictionary) -> bool: return int(u.get("statuses", {}).get("marked", 0)) > 0)
		"ally_low":
			var lowest: Dictionary = source
			for unit in friends:
				if float(unit.hp) / float(maxi(1, int(unit.max_hp))) < float(lowest.hp) / float(maxi(1, int(lowest.max_hp))):
					lowest = unit
			return [lowest]
		"enemy", "hero":
			var chosen: Dictionary = enemy(state, aim(source)) if is_player else player(state, intent_target)
			if chosen.is_empty() or int(chosen.hp) <= 0 or bool(chosen.get("downed", false)) or (is_player and bool(chosen.get("burrowed", false))):
				chosen = foes[0] if not foes.is_empty() else {}
			return [chosen] if not chosen.is_empty() else []
		"enemies":
			return foes
		"enemy_adjacent":
			var chosen: Dictionary = enemy(state, aim(source))
			if (chosen.is_empty() or bool(chosen.get("burrowed", false))) and not foes.is_empty():
				chosen = foes[0]
			return _adjacent_enemies(state, chosen).slice(0, 1)

		"enemy_behind":
			var chosen: Dictionary = enemy(state, aim(source))
			if chosen.is_empty() or int(chosen.hp) <= 0 or bool(chosen.get("burrowed", false)):
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
	## A creature's hostile effect is turned on the party, unless it names one player (or
	## itself: a Croupier Crab stuns itself on a 1).
	## A creature's `spread` keeps its meaning: its hits go round the party one at a time.
	if str(source.get("side", "")) == "enemy" and kind in DeepRules.HOSTILE and target_kind in DeepRules.ENEMY_SIDE_TARGETS and target_kind != "spread":
		target_kind = "heroes"
	## Split Light: the roll divided across the party, rounded up.
	if bool(effect.get("split_party", false)):
		var party: int = maxi(1, _targets(state, source, target_kind, intent_target).size())
		effect = effect.duplicate()
		effect.amount = int(ceil(float(int(effect.amount)) / float(party)))
	## A Kaleidoscope drinking this gem's colour takes what the gem would give its owner.
	var drinker: Dictionary = _colour_drinker(state, source) if kind in ABSORBED_GIFTS and target_kind in ["self", "allies", "ally_low"] else {}
	if not drinker.is_empty():
		var taken: Array = []
		for _count in range(repeat):
			var gift: Dictionary = _apply_one(state, drinker, drinker, kind, int(effect.amount), effect, rng, reactions)
			gift.drunk_by = str(drinker.id)
			taken.append(gift)
		return taken
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

## What a gem gives its owner that a creature drinking its colour takes instead.
const ABSORBED_GIFTS: Array = ["block", "heal", "retain", "regeneration", "ward", "spikes", "max_hp"]

static func _colour_drinker(state: Dictionary, source: Dictionary) -> Dictionary:
	## The creature drinking a colour this gem is thrown in, if there is one.
	if str(source.get("side", "")) != "player":
		return {}
	var colours: Array = source.get("firing_colors", [])
	if colours.is_empty():
		return {}
	for foe in living(state.enemies):
		for colour in foe.get("absorb", []):
			if colours.has(colour):
				return foe
	return {}

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
	if kind == "poison" and str(target.get("side", "")) == "enemy" and DeepCreatures.has_trait(target, "poison_immune"):
		out.immune = true
		return out
	## Steadfast: it shrugs off half of any stun, binding or clouding, and a stun never
	## lands two actions running.
	if str(target.get("side", "")) == "enemy" and DeepCreatures.has_trait(target, "steadfast") and kind in ["stun", "die_steal", "clouded", "dice_dread"]:
		if kind == "stun" and bool(target.get("stun_guard", false)):
			out.resisted = true
			out.steadfast = true
			return out
		amount = maxi(1, int(ceil(float(amount) / 2.0)))
		out.amount = amount
		out.steadfast = true
	## Ward turns away what others do to it, never what it does to itself.
	if kind in DeepRules.DEBUFFS and amount > 0 and str(source.get("id", "")) != str(target.get("id", "")) and _ward_blocks(target):
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
			out.merge(_damage(state, source, target, amount, rng, false, reactions, false, bool(effect.get("piercing", false))), true)
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
			## Scorched: block gained is halved, rounded up.
			if int(target.statuses.get("scorched", 0)) > 0 and amount > 0:
				amount = int(ceil(float(amount) / 2.0))
				out.scorched = true
				out.amount = amount
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
			elif str(target.get("side", "")) == "player":
				## A creature dropping pyrite: it lands in the player's fight earnings.
				target.gold = int(target.get("gold", 0)) + amount
				out.gold_after = target.gold
		"poison", "stun", "curse", "charged", "marked", "regeneration", "spikes", "dulled", "lifeline", "festering", "scorched", "burn", "strength":
			# A new late enemy debuff must reach the player's next rail before decaying.
			# Reapplying an existing stack does not postpone its ordinary decay.
			if kind in DEFERRED_DECAY and amount > 0 and int(target.statuses.get(kind, 0)) == 0 and str(target.get("side", "")) == "player" and bool(source.get("acting", false)):
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
			for status in ["poison", "burn", "stun", "curse", "marked", "dulled", "clouded", "festering", "scorched"]:
				while cleared < amount and int(target.statuses.get(status, 0)) > 0:
					target.statuses[status] = int(target.statuses[status]) - 1
					cleared += 1
			if cleared < amount:
				var dread: int = mini(amount - cleared, int(target.get("dread_turns", 0)))
				target.dread_turns = int(target.get("dread_turns", 0)) - dread
				cleared += dread
			if cleared < amount:
				var bound: int = mini(amount - cleared, int(target.get("stolen_dice", 0)))
				target.stolen_dice = int(target.get("stolen_dice", 0)) - bound
				cleared += bound
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
			if str(target.get("side", "")) == "player":
				## Dread on a player: next turn the whole bowl rolls a size smaller a stack.
				target.statuses.dread = int(target.statuses.get("dread", 0)) + maxi(0, amount)
				out.dread_after = int(target.statuses.dread)
			else:
				target.dread_turns = int(target.get("dread_turns", 0)) + maxi(0, amount)
		"dice_upgrade":
			var most: int = DeepCreatures.TIERS.size() - 1
			if effect.has("cap") and not target.get("dice", []).is_empty():
				## No bigger than the cap: a d6 told to stop at a d20 climbs five sizes at most.
				most = maxi(0, DeepCreatures.TIERS.find(str(effect.cap)) - DeepCreatures.TIERS.find(str(target.dice[0].get("shape", "D6"))))
			var was: int = int(target.get("dice_upgrade", 0))
			target.dice_upgrade = maxi(was, mini(most, was + amount))
			out.upgraded = int(target.dice_upgrade) > was
			if not bool(out.upgraded):
				out.nothing = true
		"die_steal":
			target.stolen_dice = int(target.get("stolen_dice", 0)) + amount
		"mar_die", "grind_die", "lock_die", "break_die", "downgrade_die", "break_gem", "blank_face":
			out.merge(_spoil(state, target, kind, effect, rng), true)
		"summon":
			out.summoned = summon(state, source, str(effect.get("creature", "")), amount, rng)
			if out.summoned.is_empty():
				out.nothing = true
				out.reason = "No room in the chamber."
		"purge":
			var had: int = int(target.statuses.get("poison", 0))
			var shed: int = had if amount >= 100 else had * clampi(amount, 0, 100) / 100
			target.statuses.poison = had - shed
			out.purged = shed
			out.poison_after = int(target.statuses.poison)
		"burrow":
			target.burrowed = true
			out.burrowed = true
		"reflect":
			target.reflect = clampi(maxi(int(target.get("reflect", 0)), amount), 0, 100)
			out.reflect = int(target.reflect)
		"mirror":
			target.mirror = maxi(int(target.get("mirror", 0)), maxi(1, amount))
			out.mirror = int(target.mirror)
		"absorb_color":
			out.merge(_absorb_color(state, target, effect, rng), true)
		"roll_again":
			## The die it just threw goes again this action, on whatever size it now is. Three
			## goes more at most, so a lucky chain cannot run on for ever.
			var extra: Array = target.get("extra_dice", [])
			var at: int = clampi(int(effect.get("die", 0)), 0, maxi(0, target.get("dice", []).size() - 1))
			if extra.size() >= 3 or target.get("dice", []).is_empty():
				out.nothing = true
			else:
				var again: Dictionary = target.dice[at].duplicate(true)
				again.id = "%s_x%d" % [str(target.id), extra.size()]
				extra.append(again)
				target.extra_dice = extra
				out.again = extra.size()
		"end_action":
			target.stopped = true
			out.stopped = true
		"die_lock":
			out.merge(_lock_dice(target, str(effect.get("pick", "random")), amount, rng), true)
		"steal_gold":
			var purse: int = DeepRules.pyrite(target)
			var taken: int = mini(purse, purse * clampi(amount, 0, 100) / 100 if bool(effect.get("pct", false)) else amount)
			taken = maxi(0, taken)
			target.pyrite_delta = int(target.get("pyrite_delta", 0)) - taken
			source.stolen_gold = int(source.get("stolen_gold", 0)) + taken
			out.stolen = taken
			out.pyrite_after = DeepRules.pyrite(target)
			reactions.result_stolen = int(reactions.get("result_stolen", 0)) + taken
			## The Assayer's tax: each player is hit for what was taken from them.
			if bool(effect.get("hurt", false)) and taken > 0:
				var hurt: Dictionary = _damage(state, source, target, taken, rng, false, reactions)
				hurt.kind = "damage"
				hurt.target = str(target.id)
				out.hurt = hurt
		"empower_next":
			target.empowered = int(target.get("empowered", 0)) + maxi(0, amount)
			out.empowered_after = int(target.empowered)
		"rally":
			var rallied: Array = []
			for foe in living(state.enemies):
				foe.rally_bonus = int(foe.get("rally_bonus", 0)) + amount
				rallied.append(str(foe.id))
			out.rallied = rallied
		"grow_die":
			var cap: int = int(effect.get("cap", 5))
			if target.get("dice", []).size() < cap:
				var grown: Dictionary = DeepDice.make(str(effect.get("shape", "D6")), "%s_d%d" % [str(target.id), target.dice.size()])
				target.dice.append(grown)
				out.die = grown.duplicate(true)
			else:
				out.nothing = true
			out.heads = target.get("dice", []).size()
		"swell":
			target.swell = int(target.get("swell", 0)) + maxi(0, amount)
			out.swell_after = int(target.swell)
		"hold_gem":
			out.merge(_hold_gem(state, source, str(effect.get("pick", "hardest"))), true)
		"exhibit":
			## Expanded into the gems' own effects when the move was read; nothing is left to do.
			out.nothing = true
		"bury_socket":
			out.merge(_bury_heaviest(target), true)
		"charge":
			## Already winding up: the charge keeps its count rather than starting over.
			if not target.get("charging", {}).is_empty():
				out.nothing = true
				out.turns = int(target.charging.get("turns", 0))
			else:
				var turns: int = maxi(1, int(effect.get("turns", 2)))
				target.charging = {"turns": turns, "cancel_pct": int(effect.get("cancel_pct", 0)), "guard_pct": int(effect.get("guard_pct", 0)),
					"store": bool(effect.get("store", false)), "stored": 0, "release": effect.get("release", []).duplicate(true),
					"hp_at": int(target.hp), "name": str(effect.get("text", "Release"))}
				out.turns = turns
	return out

## Statuses an enemy puts on a player late in the turn, which must survive the tick that
## follows so they reach the player's next rail.
const DEFERRED_DECAY: Array = ["curse", "dulled", "festering", "scorched"]

static func _absorb_color(state: Dictionary, target: Dictionary, effect: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## It drinks a colour until its next action: one at random, or the one the party has set
	## most that it is not drinking already. With `add` it keeps the ones it had.
	var had: Array = target.get("absorb", []).duplicate() if bool(effect.get("add", false)) else []
	var colour: String = ""
	if str(effect.get("color", "random")) == "most_used":
		var counts: Dictionary = {}
		for unit in living(state.players):
			for socket in range(unit.get("rail", []).size()):
				if not unit.rail[socket] is Dictionary:
					continue
				for c in DeepStone.colors(unit.rail[socket], str(unit.sockets[socket]) if socket < unit.sockets.size() else "ANY"):
					counts[str(c)] = int(counts.get(str(c), 0)) + 1
		var best: int = 0
		var keys: Array = counts.keys()
		keys.sort()
		for key in keys:
			if int(counts[key]) > best and not had.has(str(key)) and str(key) in DeepContent.color_KEYS:
				best = int(counts[key])
				colour = str(key)
	if colour.is_empty():
		var left: Array = DeepContent.color_KEYS.filter(func(c: String) -> bool: return not had.has(c))
		if left.is_empty():
			return {"nothing": true, "reason": "It drinks every colour already."}
		colour = str(DeepRng.pick(rng, left))
	had.append(colour)
	target.absorb = had
	return {"color": colour, "colors": had.duplicate()}

static func _lock_dice(target: Dictionary, pick: String, count: int, rng: RandomNumberGenerator) -> Dictionary:
	## A creature's lock: the die comes up next turn showing what it shows now, and refuses
	## to be thrown again. The highest, the lowest, or whichever.
	var out: Dictionary = {"dice": []}
	if str(target.get("side", "")) != "player":
		return out
	var real: Array = target.get("hand", []).filter(func(r: Dictionary) -> bool: return not bool(r.get("phantom", false)) and not bool(r.get("lock_next", false)))
	if real.is_empty():
		out.nothing = true
		return out
	match pick:
		"high": real.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.value) > int(y.value))
		"low": real.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.value) < int(y.value))
		_: real = DeepRng.shuffled(rng, real)
	for roll in real.slice(0, maxi(1, count)):
		roll.lock_next = true
		out.dice.append(str(roll.die_id))
	out.hand = target.hand.duplicate(true)
	return out

static func _hold_gem(state: Dictionary, holder: Dictionary, pick: String) -> Dictionary:
	## A gem comes off a rail and into the creature's keeping until it dies: the one that
	## hit it hardest this turn, or the finest on any rail. Never a rail's last gem.
	var chosen_unit: Dictionary = {}
	var chosen_socket: int = -1
	if pick == "hardest":
		var hardest: Dictionary = holder.get("hardest_gem", {})
		var unit: Dictionary = player(state, str(hardest.get("unit", "")))
		var socket: int = int(hardest.get("socket", -1))
		if not unit.is_empty() and socket >= 0 and socket < unit.get("rail", []).size() and unit.rail[socket] is Dictionary and str(unit.rail[socket].get("id", "")) == str(hardest.get("stone_id", "")):
			chosen_unit = unit
			chosen_socket = socket
	else:
		## The finest gem on any rail; asked for one it can use, the finest of those that
		## would hurt the party or help it, and only the finest of all if there are none.
		var best: int = -1
		for wanted_usable in ([true, false] if pick == "usable" else [false]):
			for unit in living(state.players):
				for socket in range(unit.get("rail", []).size()):
					if not unit.rail[socket] is Dictionary or (wanted_usable and not DeepCreatures.gem_usable(unit.rail[socket])):
						continue
					if DeepStone.value(unit.rail[socket]) > best and unit.rail.filter(func(x: Variant) -> bool: return x is Dictionary).size() >= 2:
						best = DeepStone.value(unit.rail[socket])
						chosen_unit = unit
						chosen_socket = socket
			if chosen_socket >= 0:
				break
	if chosen_unit.is_empty() or chosen_socket < 0:
		return {"nothing": true, "reason": "Nothing to take."}
	var filled: int = chosen_unit.rail.filter(func(x: Variant) -> bool: return x is Dictionary).size()
	if filled < 2:
		return {"nothing": true, "reason": "It will not take a rail's last gem."}
	var stone: Dictionary = chosen_unit.rail[chosen_socket]
	chosen_unit.rail[chosen_socket] = null
	holder.held_gems.append({"unit": str(chosen_unit.id), "socket": chosen_socket, "stone": stone})
	return {"held": {"unit": str(chosen_unit.id), "socket": chosen_socket, "stone_id": str(stone.get("id", "")), "skill": str(stone.get("skill", ""))}, "held_count": holder.held_gems.size()}

static func _return_gems(state: Dictionary, holder: Dictionary) -> Array:
	## Everything it was holding goes back where it was taken from.
	var returned: Array = []
	for held in holder.get("held_gems", []):
		var unit: Dictionary = player(state, str(held.get("unit", "")))
		var socket: int = int(held.get("socket", -1))
		if unit.is_empty() or socket < 0 or socket >= unit.get("rail", []).size():
			continue
		if unit.rail[socket] == null:
			unit.rail[socket] = held.stone
		else:
			## The socket was filled meanwhile (a regrown gem): the stone rides it instead.
			_join_rail(state, unit, socket + 1, held.stone)
		returned.append({"unit": str(unit.id), "socket": socket, "stone_id": str(held.stone.get("id", ""))})
	holder.held_gems = []
	return returned

static func _bury_heaviest(target: Dictionary) -> Dictionary:
	## The socket under the heaviest gem goes under rubble for the turn. Never the last open one.
	if str(target.get("side", "")) != "player":
		return {}
	var open: Array = []
	for socket in range(target.get("rail", []).size()):
		if target.rail[socket] is Dictionary and not target.buried.has(socket) and not target.clouded.has(socket):
			open.append(socket)
	if open.size() < 2:
		return {"nothing": true}
	var heaviest: int = int(open[0])
	for socket in open:
		if int(target.rail[socket].get("carat", 1)) > int(target.rail[heaviest].get("carat", 1)):
			heaviest = int(socket)
	target.buried.append(heaviest)
	return {"socket": heaviest}

static func _tick_charge(state: Dictionary, foe: Dictionary) -> Dictionary:
	## A blow wound up over turns: one action nearer each time it acts, cancelled if the party
	## takes enough off it meanwhile, let go when the count runs out.
	var charge: Dictionary = foe.get("charging", {})
	if charge.is_empty():
		return {}
	var lost: int = int(charge.get("hp_at", foe.hp)) - int(foe.hp)
	if int(charge.get("cancel_pct", 0)) > 0 and lost * 100 >= int(foe.max_hp) * int(charge.cancel_pct):
		foe.charging = {}
		return {"broken": true, "lost": lost}
	charge.turns = int(charge.get("turns", 1)) - 1
	if int(charge.turns) <= 0:
		foe.charging = {}
		var release: Array = charge.get("release", []).duplicate(true)
		## A charge that stores lets go exactly what it was dealt while it gathered.
		if bool(charge.get("store", false)):
			for effect in release:
				if str(effect.get("kind", "")) == "damage":
					effect.amount = int(charge.get("stored", 0))
		return {"release": release, "name": str(charge.get("name", "Release")), "stored": int(charge.get("stored", 0))}
	return {"turns": int(charge.turns)}

static func _regrow_escorts(state: Dictionary, leader: Dictionary, rng: RandomNumberGenerator) -> Array:
	## A Heartrot's tendrils grow back two turns after they die, unless all of them died
	## within two turns of each other: pruned together, they stay pruned.
	var within: int = DeepCreatures.trait_value(leader, "regrow_escorts", 0)
	if within <= 0 or leader.get("escorts", []).is_empty() or bool(leader.get("escorts_broken", false)):
		return []
	var dead: Array = []
	for id in leader.escorts:
		var escort: Dictionary = enemy(state, str(id))
		if not escort.is_empty() and int(escort.hp) <= 0:
			dead.append(escort)
	if dead.size() == leader.escorts.size():
		var earliest: int = 999
		var latest: int = 0
		for escort in dead:
			earliest = mini(earliest, int(escort.get("death_turn", 0)))
			latest = maxi(latest, int(escort.get("death_turn", 0)))
		if latest - earliest <= within:
			leader.escorts_broken = true
			return []
	var regrown: Array = []
	for escort in dead:
		if int(state.turn) - int(escort.get("death_turn", 0)) >= within and living(state.enemies).size() < max_creatures():
			escort.hp = int(escort.max_hp)
			escort.block = 0
			escort.statuses = {}
			escort.fled = false
			escort.death_turn = 0
			DeepCreatures.prepare(escort)
			DeepCreatures.refresh_bonuses(escort, state)
			regrown.append(str(escort.id))
	return regrown

static func _spoil(state: Dictionary, target: Dictionary, kind: String, effect: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## What a creature does to a hero bowl. A face blanked or locked over, a face ground down,
	## a die held shut, a die broken, a die filed a size smaller, a gem destroyed. Granite
	## answers none of it. Whatever is done to a die for the fight is put right when the fight
	## is (see `dice_after_fight`); only what is marked `permanent` on a die outlives it.
	var out: Dictionary = {"dice": [], "sockets": []}
	if str(target.get("side", "")) != "player" or bool(target.get("downed", false)):
		return out
	var permanent: bool = bool(effect.get("permanent", false))
	var pool: Array = target.get("dice", []).filter(func(d: Dictionary) -> bool: return str(d.get("material", "")) != "granite")
	if kind == "break_gem":
		var filled: Array = []
		for socket in range(target.get("rail", []).size()):
			if target.rail[socket] is Dictionary:
				filled.append(socket)
		## Never the last gem on the rail: a hero with nothing to fire is not a fight.
		if filled.size() < 2:
			return out
		var chosen: int = int(DeepRng.pick(rng, filled))
		if break_gem(state, target, chosen):
			out.sockets.append(chosen)
			## Melted for the rest of the fight: it does not grow back next turn.
			if permanent:
				target.broken_gems.pop_back()
				out.permanent = true
		return out
	if pool.is_empty() or (kind == "break_die" and target.get("dice", []).size() < 2):
		out.granite = true
		return out
	var pick: String = str(effect.get("pick", "random"))
	var amount: int = maxi(1, int(effect.get("amount", 1)))
	## Every die at once (the Infinite Void's dread), or the face every die lies on (the
	## Gardener's pruning): the same work, die by die.
	if (kind == "downgrade_die" and pick == "all") or (kind == "grind_die" and pick == "showing"):
		for die in pool:
			if kind == "downgrade_die":
				if DeepDice.TIERS.find(str(die.get("shape", ""))) <= DeepDice.TIERS.find("D4"):
					continue
				_remember_die(target, die)
				DeepOddities.resize(die, -1)
			else:
				var at: int = _showing_face(target, die)
				if at < 0:
					continue
				_grind(die, at)
				if permanent:
					var kept: Dictionary = target.get("fight_dice", {}).get(str(die.id), {})
					if not kept.is_empty():
						_grind(kept.was, at)
				else:
					_remember_die(target, die)
			out.dice.append(die.duplicate(true))
		out.permanent = permanent
		out.hand = target.get("hand", []).duplicate(true)
		return out
	## Which die: whichever, or the biggest (a Glazier scores your best die).
	var die: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	if pick in ["high", "low"]:
		for candidate in pool:
			if (DeepDice.top(candidate) > DeepDice.top(die)) == (pick == "high") and DeepDice.top(candidate) != DeepDice.top(die):
				die = candidate
	match kind:
		"mar_die":
			_remember_die(target, die)
			var faces: Array = die.get("faces", [])
			for _once in range(mini(amount, faces.size())):
				var at: int = rng.randi_range(0, faces.size() - 1)
				DeepDice.etch(die, at, "blank" if DeepRng.chance(rng, 50.0) else "locked")
			out.dice.append(die.duplicate(true))
		"blank_face":
			## The face it is showing now burns off: blank until the fight is over.
			var rolls: Array = target.get("hand", []).filter(func(r: Dictionary) -> bool: return not bool(r.get("phantom", false)) and str(r.get("kind", "plain")) != "blank" and int(r.get("face", -1)) >= 0)
			rolls = rolls.filter(func(r: Dictionary) -> bool: return pool.any(func(d: Dictionary) -> bool: return str(d.id) == str(r.get("die_id", ""))))
			if rolls.is_empty():
				out.nothing = true
				return out
			var roll: Dictionary = DeepRng.pick(rng, rolls)
			for candidate in pool:
				if str(candidate.id) == str(roll.die_id):
					die = candidate
			_remember_die(target, die)
			DeepDice.etch(die, int(roll.face), "blank")
			out.face = int(roll.face)
			out.dice.append(die.duplicate(true))
		"grind_die":
			if not permanent:
				_remember_die(target, die)
			var faces: Array = die.get("faces", [])
			for _once in range(mini(amount, faces.size())):
				var at: int = rng.randi_range(0, faces.size() - 1)
				if pick == "high":
					## The top face, ground down a point.
					at = 0
					for index in range(faces.size()):
						if int(faces[index].get("value", 0)) > int(faces[at].get("value", 0)):
							at = index
				_grind(die, at)
				if permanent:
					var kept: Dictionary = target.get("fight_dice", {}).get(str(die.id), {})
					if not kept.is_empty():
						_grind(kept.was, at)
			out.permanent = permanent
			out.dice.append(die.duplicate(true))
		"lock_die":
			for roll in target.get("hand", []):
				if str(roll.get("die_id", "")) == str(die.get("id", "")):
					roll.locked = true
			out.dice.append(die.duplicate(true))
		"break_die":
			## Broken for the rest of the fight: it is kept aside, not grown back next turn.
			if permanent:
				_remember_die(target, die)
			if break_die(state, target, str(die.get("id", "")), "broken"):
				out.dice.append(die.duplicate(true))
				out.broken = str(die.get("id", ""))
				if permanent:
					target.broken_dice.pop_back()
					out.permanent = true
		"downgrade_die":
			## Never below a d4: a bowl can be worn down, not emptied out.
			var at_tier: int = DeepDice.TIERS.find(str(die.get("shape", "")))
			if at_tier <= DeepDice.TIERS.find("D4"):
				return out
			_remember_die(target, die)
			DeepOddities.resize(die, -1)
			out.dice.append(die.duplicate(true))
	out.hand = target.get("hand", []).duplicate(true)
	return out

static func _showing_face(unit: Dictionary, die: Dictionary) -> int:
	## The face this die lies on in the hand, or -1.
	for roll in unit.get("hand", []):
		if str(roll.get("die_id", "")) == str(die.get("id", "")) and not bool(roll.get("phantom", false)):
			return int(roll.get("face", -1))
	return -1

static func _grind(die: Dictionary, at: int) -> void:
	## One face a point lower, never below 1, and the die's top with it.
	var faces: Array = die.get("faces", [])
	if at < 0 or at >= faces.size():
		return
	faces[at].value = maxi(1, int(faces[at].get("value", 1)) - 1)
	if die.has("top"):
		var physical_top: int = 0
		for face in faces:
			if str(face.get("kind", "plain")) != "blank":
				physical_top = maxi(physical_top, int(face.value))
		die.top = mini(int(die.top), maxi(1, physical_top))

static func _remember_die(unit: Dictionary, die: Dictionary) -> void:
	## A die as it was before the fight first laid a hand on it, kept to be given back.
	if not unit.has("fight_dice"):
		unit.fight_dice = {}
	var id: String = str(die.get("id", ""))
	if unit.fight_dice.has(id):
		return
	var at: int = 0
	for index in range(unit.get("dice", []).size()):
		if str(unit.dice[index].get("id", "")) == id:
			at = index
	unit.fight_dice[id] = {"was": die.duplicate(true), "at": at}

static func dice_after_fight(unit: Dictionary) -> Array:
	## The bowl a hero walks out of a fight with: every die the fight shrank, blanked, ground
	## or destroyed for the fight is back as it was. What was done for good stays done.
	var dice: Array = unit.get("dice", []).duplicate(true)
	var kept: Dictionary = unit.get("fight_dice", {})
	var ids: Array = kept.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(kept[a].get("at", 0)) < int(kept[b].get("at", 0)))
	for id in ids:
		var was: Dictionary = kept[id].get("was", {}).duplicate(true)
		var found: bool = false
		for index in range(dice.size()):
			if str(dice[index].get("id", "")) == str(id):
				dice[index] = was
				found = true
		if not found:
			dice.insert(clampi(int(kept[id].get("at", dice.size())), 0, dice.size()), was)
	return dice

static func _damage(state: Dictionary, source: Dictionary, target: Dictionary, amount: int, rng: RandomNumberGenerator, settle: bool = true, reactions: Dictionary = {}, reactive: bool = false, piercing: bool = false) -> Dictionary:
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
	var out: Dictionary = {"raw": raw}
	var is_enemy_target: bool = str(target.get("side", "")) == "enemy"
	if is_enemy_target and str(source.get("side", "")) == "player" and not reactive:
		## A mirror held up: the next blow on it goes straight back at whoever threw it.
		if int(target.get("mirror", 0)) > 0 and raw > 0:
			target.mirror = int(target.mirror) - 1
			var back: Dictionary = _damage(state, target, source, raw, rng, false, {}, true)
			back.target = str(source.id)
			back.kind = "damage"
			out.merge({"absorbed": 0, "hp_loss": 0, "hp_after": target.hp, "block_after": target.block, "mirrored": back}, true)
			if settle:
				_check_outcome(state)
			return out
		## A colour it is drinking does it no harm.
		var colours: Array = source.get("firing_colors", [])
		for colour in target.get("absorb", []):
			if colours.has(colour):
				out.merge({"absorbed": 0, "hp_loss": 0, "hp_after": target.hp, "block_after": target.block, "drunk": str(colour)}, true)
				if settle:
					_check_outcome(state)
				return out
		## Its escorts stand between it and the blow.
		var shielding: int = DeepCreatures.trait_value(target, "shielded_by_escorts", 0)
		if shielding > 0 and target.get("escorts", []).any(func(id: Variant) -> bool: return int(enemy(state, str(id)).get("hp", 0)) > 0):
			raw = raw * (100 - shielding) / 100
			out.shielded = true
			out.raw = raw
	## Gathering a blow: it keeps count of everything dealt to it, and takes only part of it.
	if is_enemy_target and not target.get("charging", {}).is_empty() and raw > 0:
		var charging: Dictionary = target.charging
		if bool(charging.get("store", false)):
			charging.stored = int(charging.get("stored", 0)) + raw
		var guard: int = int(charging.get("guard_pct", 0))
		if guard > 0:
			raw = raw * (100 - clampi(guard, 0, 100)) / 100
			out.guarded = true
			out.raw = raw
	var absorbed: int = 0 if piercing else mini(int(target.block), raw)
	target.block = int(target.block) - absorbed
	var loss: int = mini(int(target.hp), raw - absorbed)
	## Sturdy: no single blow takes more than its share of the creature's health.
	if is_enemy_target:
		var sturdy: int = DeepCreatures.trait_value(target, "sturdy", 0)
		if sturdy > 0:
			var cap: int = maxi(1, int(ceil(float(target.max_hp) * float(sturdy) / 100.0)))
			if loss > cap:
				out.capped = loss - cap
				loss = cap
	target.hp = int(target.hp) - loss
	var rescued: int = _lifeline(target)
	out.merge({"absorbed": absorbed, "hp_loss": loss, "hp_after": target.hp, "block_after": target.block}, true)
	if piercing:
		out.piercing = true
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
		## A thief takes with every hit that draws blood: three pyrite, or three times that
		## for a Gilded one.
		var thieving: int = DeepCreatures.trait_value(source, "steal_gold", 0) if str(source.get("side", "")) == "enemy" else 0
		if thieving > 0 and loss > 0:
			var stolen: int = mini(3 * thieving, int(target.get("gold", 0)))
			target.gold = int(target.gold) - stolen
			source.stolen_gold = int(source.get("stolen_gold", 0)) + stolen
			out.stolen = stolen
	else:
		source.dealt = int(source.get("dealt", 0)) + loss
		if str(source.get("side", "")) == "player" and not reactive:
			## What this turn did to it, and who did it: read back by the creatures that
			## answer their hardest hit, their worst colour or the hand that hurt them most.
			target.hurt_by[str(source.id)] = int(target.get("hurt_by", {}).get(str(source.id), 0)) + loss
			for colour in source.get("firing_colors", []):
				target.hurt_by_color[str(colour)] = int(target.get("hurt_by_color", {}).get(str(colour), 0)) + loss
			if loss > int(target.get("biggest_hit", 0)):
				target.biggest_hit = loss
				var firing: Dictionary = source.get("firing_stone", {})
				if not firing.is_empty():
					target.hardest_gem = {"unit": str(source.id), "socket": int(firing.get("socket", -1)), "stone_id": str(firing.get("stone_id", ""))}
		if str(source.get("side", "")) == "player" and str(source.get("passive", {}).get("kind", "")) == "block_per_hit" and raw > 0:
			## Riposte: every hit the Rogue lands raises block worth her Resonance.
			var parry: int = int(source.get("resonance", 0))
			if parry > 0:
				source.block = int(source.block) + parry
				out.riposte = parry
		if DeepCreatures.has_trait(target, "cloud_socket") and loss > 0:
			for unit in state.players:
				unit.clouded = []
			out.uncloud = true
		if not reactive and DeepCreatures.has_trait(target, "reflect_zero_resonance") and loss > 0 and int(source.get("resonance", 0)) <= 1 and str(source.get("side", "")) == "player":
			var back: int = loss / 2
			var reflections: Array = []
			for victim in living(state.players):
				var hit: Dictionary = _damage(state, target, victim, back, rng, false, {}, true)
				hit.target = str(victim.id)
				hit.kind = "damage"
				reflections.append(hit)
			out.reflections = reflections
		## Refracting: part of every blow it takes goes back at the whole party.
		var reflect: int = int(target.get("reflect", 0))
		if not reactive and reflect > 0 and loss > 0 and str(source.get("side", "")) == "player":
			var back: int = loss * reflect / 100
			if back > 0:
				var thrown: Array = out.get("reflections", [])
				for victim in living(state.players):
					var hit: Dictionary = _damage(state, target, victim, back, rng, false, {}, true)
					hit.target = str(victim.id)
					hit.kind = "damage"
					thrown.append(hit)
				out.reflections = thrown

		## It splits, room allowing: a fight never holds more than `max_creatures` standing.
		if DeepCreatures.has_trait(target, "split_on_big_hit") and int(target.hp) > 0 and loss * 100 >= int(target.max_hp) * 40 and living(state.enemies).size() < max_creatures():
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
			## What it holds stays with the original: a split never doubles a stolen gem or purse.
			twin.held_gems = []
			twin.stolen_gold = 0
			twin.charging = {}
			state.enemies.insert(state.enemies.find(target) + 1, twin)
			out.split = twin.id
		if int(target.hp) > 0:
			var crossed: Array = _thresholds(state, target, rng)
			if not crossed.is_empty():
				out.thresholds = crossed
		if int(target.hp) <= 0:
			out.killed = true
			_blood_feeds(state, target)
			if int(target.get("stolen_gold", 0)) > 0 and str(source.get("side", "")) == "player":
				source.gold = int(source.get("gold", 0)) + int(target.stolen_gold)
				out.recovered_gold = int(target.stolen_gold)
				target.stolen_gold = 0
			out.merge(_on_enemy_death(state, target, source, rng), true)
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
	## Festering: what would heal only half does.
	if int(target.get("statuses", {}).get("festering", 0)) > 0:
		amount = maxi(0, amount) / 2
	var before: int = int(target.hp)
	target.hp = mini(int(target.max_hp), before + maxi(0, amount))
	return int(target.hp) - before

static func _on_enemy_death(state: Dictionary, dead: Dictionary, killer: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## What a creature leaves behind: the turn it fell on (for whatever might grow it back),
	## the gems it was holding, a raw stone for a Hoard Mimic's killer, and the moves that
	## waited for this (a Puffball's burst), fired with the dead creature as their source.
	var out: Dictionary = {}
	dead.death_turn = int(state.turn)
	var returned: Array = _return_gems(state, dead)
	if not returned.is_empty():
		out.returned_gems = returned
	if DeepCreatures.has_trait(dead, "drops_stone") and str(killer.get("side", "")) == "player":
		killer.raw_drops = int(killer.get("raw_drops", 0)) + 1
		out.raw_drop = true
	var burst: Array = []
	for move in DeepCreatures.death_moves(dead):
		var trig: Dictionary = {"active": true, "dice": [], "kind": "on_death", "value": 0, "count": 0}
		var resolved: Dictionary = DeepCreatures.resolved_move(dead, state, move, -1, trig, false, -1)
		var results: Array = []
		var reactions: Dictionary = {}
		for effect in resolved.effects:
			results.append_array(_apply(state, dead, effect, rng, "", reactions))
		burst.append({"move": str(move.get("name", "")), "effects": results})
	if not burst.is_empty():
		out.deathburst = burst
	return out

# --- creatures ---------------------------------------------------------------------------

static func _enemy_act(state: Dictionary, foe: Dictionary, move: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var results: Array = []
	var reactions: Dictionary = {}
	for effect in move.get("effects", []):
		results.append_array(_apply(state, foe, effect, rng, "", reactions))
		if done(state):
			break
	foe.beat = "impact"
	if int(move.index) >= 0 and int(move.index) < foe.move_states.size():
		foe.move_states[int(move.index)] = "used" if bool(move.get("combo", false)) else "resolved"
	return _event(state, "enemy_move", {"unit": foe.id, "move": str(move.get("move", "")), "index": int(move.index),
		"effects": results, "dice": move.get("dice", []), "burrowed": bool(foe.get("burrowed", false)), "release": bool(move.get("release", false))})

static func _thresholds(state: Dictionary, foe: Dictionary, rng: RandomNumberGenerator) -> Array:
	## The moves that wait for its health to fall: each fires once, the moment its health first
	## reaches its share, with the creature as its source (the Hollow Crown calling its magpies).
	var out: Array = []
	if str(foe.get("side", "")) != "enemy" or int(foe.get("hp", 0)) <= 0:
		return out
	for called in DeepCreatures.moves_called(foe, "hp_below"):
		var move: Dictionary = called.move
		var name: String = str(move.get("name", ""))
		if foe.get("used_once", []).has(name) or int(foe.hp) * 100 > int(foe.max_hp) * int(move.get("trigger", {}).get("amount", 0)):
			continue
		foe.used_once.append(name)
		var trig: Dictionary = {"active": true, "dice": [], "kind": "hp_below", "value": 0, "count": 0}
		var resolved: Dictionary = DeepCreatures.resolved_move(foe, state, move, int(called.index), trig, false, -1)
		var results: Array = []
		var reactions: Dictionary = {}
		for effect in resolved.effects:
			results.append_array(_apply(state, foe, effect, rng, "", reactions))
		out.append({"move": name, "unit": str(foe.id), "effects": results})
	if not out.is_empty() and not bool(foe.get("acting", false)):
		DeepCreatures.prepare(foe)
	return out

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
	_tick_wound(state, unit, tick)
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

static func _burn_tick(state: Dictionary, unit: Dictionary) -> Dictionary:
	## One round of burning on one unit: it hurts for its stacks and loses one, the way poison
	## does, except that block soaks it first.
	var burn: int = int(unit.statuses.get("burn", 0))
	if burn <= 0 or int(unit.hp) <= 0:
		return {}
	var soaked: int = mini(maxi(0, int(unit.get("block", 0))), burn)
	unit.block = int(unit.get("block", 0)) - soaked
	var loss: int = mini(int(unit.hp), burn - soaked)
	unit.hp = int(unit.hp) - loss
	unit.statuses.burn = burn - 1
	var tick: Dictionary = {"unit": str(unit.id), "kind": "burn", "amount": loss, "soaked": soaked, "hp_after": unit.hp, "block_after": int(unit.block), "remaining": unit.statuses.burn}
	_tick_wound(state, unit, tick)
	return tick

static func _tick_wound(state: Dictionary, unit: Dictionary, tick: Dictionary) -> void:
	## What a round of poison or burning leaves: a Lifeline spent, a player down, a creature
	## dead (and its burst), or a creature hurt past the point it was waiting for.
	var rescued: int = _lifeline(unit)
	if rescued > 0:
		tick.lifeline = rescued
	if int(unit.hp) <= 0:
		if str(unit.get("side", "")) == "player":
			unit.downed = true
			unit.block = 0
		tick.killed = true
		_blood_feeds(state, unit)
		if str(unit.get("side", "")) == "enemy":
			tick.merge(_on_enemy_death(state, unit, {}, RandomNumberGenerator.new()), true)
	elif str(unit.get("side", "")) == "enemy":
		var crossed: Array = _thresholds(state, unit, RandomNumberGenerator.new())
		if not crossed.is_empty():
			tick.thresholds = crossed

static func _tick(state: Dictionary) -> Dictionary:
	var ticks: Array = []
	for unit in state.players + state.enemies:
		if int(unit.hp) <= 0 or bool(unit.get("downed", false)):
			continue
		var tick: Dictionary = _poison_tick(state, unit)
		if not tick.is_empty():
			ticks.append(tick)
		var burning: Dictionary = _burn_tick(state, unit)
		if not burning.is_empty():
			ticks.append(burning)
		if str(unit.get("side", "")) == "enemy" and DeepCreatures.has_trait(unit, "regrow") and int(unit.hp) > 0:
			var grown: int = _heal(unit, 3)
			if grown > 0:
				ticks.append({"unit": str(unit.id), "kind": "regrow", "amount": grown, "hp_after": unit.hp})
		## A heart fed by its tendrils: while any stands, it knits itself back together.
		if str(unit.get("side", "")) == "enemy" and int(unit.hp) > 0:
			var fed: int = DeepCreatures.trait_value(unit, "regen_with_escorts", 0)
			if fed > 0 and unit.get("escorts", []).any(func(id: Variant) -> bool: return int(enemy(state, str(id)).get("hp", 0)) > 0):
				var knit: int = _heal(unit, fed)
				if knit > 0:
					ticks.append({"unit": str(unit.id), "kind": "regrow", "amount": knit, "hp_after": unit.hp, "escorts": true})
		var regen: int = int(unit.statuses.get("regeneration", 0))
		if regen > 0:
			var healed: int = _heal(unit, regen)
			unit.statuses.regeneration = regen - 1
			if healed > 0:
				ticks.append({"unit": str(unit.id), "kind": "regeneration", "amount": healed, "hp_after": unit.hp, "remaining": regen - 1})
		for fading in ["curse", "dulled", "combo_breaker", "festering", "scorched"]:
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
	var auras: Dictionary = {}
	for foe in living(state.enemies):
		if DeepCreatures.has_trait(foe, "gift_rerolls"):
			gifts += 1
		if DeepCreatures.has_trait(foe, "roll_for_you") and int(state.turn) % 2 == 1:
			frozen = true
		## What a creature's presence alone puts on the party, every turn: a Heartrot's rot,
		## a Kiln Wyrm's heat. It is kept up to the amount, never stacked.
		for status in DeepCreatures.traits_for(foe).get("aura", {}):
			auras[str(status)] = maxi(int(auras.get(str(status), 0)), int(DeepCreatures.traits_for(foe).aura[status]))
	## The party's best turn so far, which a Prismarch's charge throws back at them.
	var party_turn: int = 0
	for unit in state.players:
		party_turn += int(unit.get("dealt", 0))
	state.party_best_turn = maxi(int(state.get("party_best_turn", 0)), party_turn)
	var afflicted: Array = []
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
		for status in auras:
			if int(unit.statuses.get(status, 0)) < int(auras[status]):
				unit.statuses[status] = int(auras[status])
				afflicted.append({"unit": str(unit.id), "kind": str(status), "amount": int(auras[status]), "aura": true})
		var charged: int = int(unit.statuses.get("charged", 0))
		unit.statuses.erase("charged")
		unit.initial_resonance = charged
		unit.resonance = charged
		if charged > 0:
			batteries.append({"unit": str(unit.id), "amount": charged, "resonance": charged})
		## Whatever was broken last turn is back in the bowl before anything is thrown.
		var regrown: Dictionary = _regrow(unit)
		var dice: Array = unit.dice.duplicate()
		var stolen: int = int(unit.get("stolen_dice", 0))
		while stolen > 0 and dice.size() > 1:
			dice.pop_back()
			stolen -= 1
		unit.stolen_dice = 0
		## Dread on a player: the bowl is thrown a size smaller a stack this turn. The dice
		## themselves are untouched; only this throw is.
		var dread: int = int(unit.statuses.get("dread", 0))
		if dread > 0:
			var shrunk: Array = []
			for die in dice:
				var copy: Dictionary = die.duplicate(true)
				var at: int = DeepDice.TIERS.find(str(copy.get("shape", "D6")))
				var steps: int = -mini(dread, maxi(0, at))
				if steps < 0:
					DeepOddities.resize(copy, steps)
				shrunk.append(copy)
			dice = shrunk
			unit.statuses.dread = dread - 1
			if int(unit.statuses.dread) <= 0:
				unit.statuses.erase("dread")
		unit.hand = DeepDice.roll_hand(dice, rng_dice, unit.get("hand", []))
		_loaded(unit, [], rng_dice)
		unit.regrown = regrown
		unit.dues = _pay_dues(state, unit)
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
		var traits: Dictionary = DeepCreatures.traits_for(foe)
		if traits.has("block_from_high"):
			## The golem hardens to match the party's best die; it does not pile up.
			foe.block = maxi(int(foe.block), high)
		for trick in ["bury_socket", "cloud_socket"]:
			if not traits.has(trick):
				continue
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
					if trick == "bury_socket":
						victim.buried.append(socket)
					else:
						victim.clouded.append(socket)
		## A Prismarch punishes a straight: whoever holds one has their highest die locked.
		if traits.has("punish_straight"):
			for victim in living(state.players):
				var run: int = int(DeepHand.analyze(victim.hand).get("straight", {}).get("length", 0))
				if run >= int(DeepContent.constant("punished_straight", 4)):
					var locked: Dictionary = _lock_dice(victim, "high", 1, rng_creatures)
					if not locked.get("dice", []).is_empty():
						afflicted.append({"unit": str(victim.id), "kind": "die_lock", "dice": locked.dice, "by": str(foe.id)})
	return _event(state, "turn_begin", {"turn": state.turn, "frozen": frozen, "charged": batteries, "afflicted": afflicted,
		"hands": state.players.map(func(u: Dictionary) -> Dictionary: return {"unit": u.id, "hand": u.hand.duplicate(true), "rerolls": u.rerolls,
			"dues": u.get("dues", {}), "regrown": u.get("regrown", {}), "resonance": int(u.get("resonance", 0)),
			"locked": u.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("locked_by_foe", false))).map(func(r: Dictionary) -> String: return str(r.die_id))})})

static func _check_outcome(state: Dictionary) -> void:
	if done(state):
		return
	if living(state.players).is_empty():
		state.erase("cleared")
		state.phase = "over"
		state.outcome = "defeat"
	elif living(state.enemies).is_empty():
		## The last creature is down, but a rail still firing finishes its rung: the gems
		## after the killing blow may heal, shield or pay, and they are the player's.
		if _rail_firing(state):
			state.cleared = true
			return
		state.erase("cleared")
		state.phase = "over"
		state.outcome = "victory"

static func _rail_firing(state: Dictionary) -> bool:
	## Whether the queue is partway through one player's rail: nothing but that player's
	## gems (and Birthstone) stand between here and their rail_end.
	if str(state.get("phase", "")) != "resolving":
		return false
	var owner: String = ""
	for q in state.get("queue", []):
		var kind: String = str(q.get("kind", ""))
		if not kind in RUNG_STEPS:
			return false
		if owner.is_empty():
			owner = str(q.get("unit", ""))
		elif str(q.get("unit", "")) != owner:
			return false
		if kind == "rail_end":
			return true
	return false

static func _close_cleared(state: Dictionary) -> void:
	state.erase("cleared")
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
	unit.tailings_paid = {}
	unit.repeat_next = 0
	unit.replaying = false
	unit.fired_count = 0
	unit.damp_carry = 0
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
