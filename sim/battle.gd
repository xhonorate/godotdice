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
const BASE_DURATION: Dictionary = {"turn_begin": 0.8, "resolution_begin": 0.4, "rail_begin": 0.3, "gem_fire": 0.4,
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
## The beat a gem's own arithmetic is counted out on before what it does leaves the socket
## (see `tally_of`): each die it read hops and sends its number to the gem, TALLY_FLIGHT after
## it the number lands; each step that makes the sum into the gem's number (a ×2 its skill
## puts on it, the stone's weight, a Ruby die) is laid on one after another; then the two
## are fused into what flies. Like the blows, the dice and the steps close up as they pile on,
## so five dice and five multipliers still fit. The battle screen plays exactly this beat.
## At 1x every figure stays up long enough to be read: each die's number, each multiplier
## and the box it lands in, the fused figure before it flies. The weight in carats is held
## longest (TALLY_CARAT), since it is the step a stone is chosen for. Quick (a count pace of
## a half) plays all of it in half the time; the fight speed shortens it again.
const TALLY_DIE: float = 0.14
const TALLY_DICE: float = 0.6
const TALLY_FLIGHT: float = 0.2
const TALLY_STEP: float = 0.26
const TALLY_STEPS: float = 1.1
const TALLY_CARAT: float = 1.5
const TALLY_FUSE: float = 0.36
## With the counts off, how long the figure alone is shown before it flies.
const TALLY_GLANCE: float = 0.2
## A blow on a lapidary that block takes part of: what came in, the block flying off it, what
## was left to bleed, counted at the health bar before the next thing happens.
const SOAK_SPAN: float = 0.6
## A Birthstone's lit tiers, and Second Wind, are counted out one after another the way a gem
## is (see `birth_count`): the tier's name called out large and standing alone for BIRTH_CALL,
## the number Resonance multiplies, then Resonance itself streaming out of its counter into a
## box of its own for BIRTH_FLOW, then the figure fused and flown; what it does lands before
## the next tier is called (BIRTH_LAND at the least). With the counts off a tier shows its name
## and figure together for BIRTH_GLANCE. The stone lights for BIRTH_LEAD before the first.
const BIRTH_CALL: float = 0.5
const BIRTH_FLOW: float = 0.7
const BIRTH_GLANCE: float = 0.45
const BIRTH_LAND: float = 0.3
const BIRTH_LEAD: float = 0.25
## The effects whose number a tally counts out: one that swells with weight and lands as a
## figure. The first of them a gem fires is its headline.
const TALLY_KINDS: Array = ["damage", "block", "heal", "poison", "gold", "spikes", "regeneration", "retain"]
const HAND_KINDS: Array = ["raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high", "phantom_low"]
const SELF_KINDS: Array = ["amplify_next", "cut_step_next", "grant_reroll", "retrigger_previous", "quality_bonus", "sparkle",
	"coin_flip", "resonance", "replay_color", "replay_fizzled", "rank_buff", "repeat_next", "void_copy", "gem_rank", "upgrade_faces", "stake", "appraise",
	"fire_neighbours", "force_after", "absorbed",
	"phantom_roll", "rethrow", "gild", "soak", "each_after", "on_block", "fire_birthstone", "spectrum", "stone_chance",
	"double_resonance", "keep_phantoms", "bonus_die", "double_resonance_next", "lose_pyrite", "reflect_blows", "invert_previous"]
## What an Invert gives back for what the gem before it did, in the order it gives it, as
## [effect kind, what it reads, target]. Retain is Block that stays; Regeneration is healing to come.
const INVERTED: Array = [["block", ["damage"], "self"], ["damage", ["block", "retain"], "enemy"],
	["poison", ["heal", "regeneration"], "enemy"], ["heal", ["poison"], "self"], ["marked", ["spikes"], "enemy"],
	["spikes", ["marked"], "self"], ["curse", ["strength"], "enemy"], ["strength", ["curse"], "self"]]
## What a gem does to the other side, as an Invert reads it; everything else it reads is given to its own.
const INVERTED_HOSTILE: Array = ["damage", "poison", "marked", "curse"]
## The six colors and what a Spectrum gives for each of them, as [effect kind, amount, target].
const SPECTRUM_GIFTS: Dictionary = {"RED": ["damage", 3, "enemy"], "BLUE": ["block", 3, "self"], "GREEN": ["heal", 3, "self"],
	"VIOLET": ["poison", 2, "enemy"], "GOLD": ["gold", 2, "self"], "WHITE": ["resonance", 1, "self"]}
## A Hydrophane's drops to a size.
const DROPS_PER_SIZE: int = 3
## How long a rail may grow mid-fight. An Echo adds a gem a turn and nothing else does, so
## this is only there to keep a very long fight from laying out a rail no screen can hold.
const MAX_RAIL: int = 24
## The most gems (and Birthstone firings) one player's rail may play in a turn. Replays,
## Preludes, Geminis and Echoes can set a rail firing on and on; a few rails would never stop
## at all. Past this the rail is spent: what is still queued for it is dropped, its close still
## plays, and the turn goes on. The strongest rails a search can find play about 150.
const RAIL_CAP: int = 200
## A rail that keeps firing plays out faster and faster (see `rush`): not at all for its first
## RUSH_FROM plays, then RUSH_STEP faster for every play past them, with no ceiling short of
## RUSH_MOST. Fifty plays run at about 10×, the cap at about 48×.
const RUSH_FROM: int = 12
const RUSH_STEP: float = 0.25
const RUSH_MOST: float = 64.0
## What the party's half of a turn is made of. Once the last creature falls these still play
## out, the rail that was firing and every rail queued after it, so a heal, a shield or a
## purse on a later rail is not lost because an ally's gem got there first; nothing else does.
const RUNG_STEPS: Array = ["rail_begin", "gem", "birthstone", "rail_end", "skip"]
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
		"quality_bonus": 0, "run_mods": {}, "skipped_turn": - 1, "fired_count": 0, "raw_drops": 0, "damp_carry": 0,
		"bonus_dice_next": [], "double_resonance_next": false, "resonance_doubled": false, "streak": 0, "streak_next": 0,
		"last_face": "", "face_shown": "", "change": 0, "change_now": 0, "stats": fresh_stats()}
	DeepStone.normalize_rail(unit)
	return unit

# --- the run's tally -----------------------------------------------------------------------
##
## What a player did, kept on the unit through every fight of the run and read out at the
## lift (the stats screen): running totals and bests, never a log of blows. `gems` keeps the
## same by stone id, for the Crown Jewel. A creature's `stacked_by` names whoever put the last
## Poison or Burn on it, so a tick's damage and its kill are theirs. The fighter carries the
## run's tally into a fight and the run takes it back when the fight settles.

static func fresh_stats() -> Dictionary:
	return {"damage": 0, "overkill": 0, "block": 0, "blocked": 0, "healed": 0, "overheal": 0, "ore": 0, "spent": 0,
		"slain": 0, "slain_wardens": 0, "taken": 0, "downs": 0, "revives": 0, "debuffs": {}, "buffs": {},
		"best_hit": {}, "best_turn": {}, "hands": {}, "rerolls": 0, "rerolls_given": 0, "birthstone": 0, "resonance": 0,
		"turns": 0, "fights": 0, "elites": 0, "wardens": 0, "stones": 0, "gems": {}}

static func stats_of(unit: Dictionary) -> Dictionary:
	## A unit's tally, made whole: a run begun before the tally was kept has only part of it.
	if unit.get("stats", null) is Dictionary and unit.stats.has("gems"):
		return unit.stats
	var whole: Dictionary = fresh_stats()
	if unit.get("stats", null) is Dictionary:
		whole.merge(unit.stats, true)
	unit.stats = whole
	return whole

static func tally_add(unit: Dictionary, key: String, amount: int) -> void:
	## One of the tally's running numbers. Creatures keep no tally.
	if amount == 0 or str(unit.get("side", "")) != "player":
		return
	var tally: Dictionary = stats_of(unit)
	tally[key] = DeepRules.sat_add(int(tally.get(key, 0)), amount)

static func tally_kind(unit: Dictionary, key: String, kind: String, amount: int) -> void:
	## One of the tally's dictionaries (debuffs, buffs, hands), by kind.
	if amount == 0 or kind.is_empty() or str(unit.get("side", "")) != "player":
		return
	var tally: Dictionary = stats_of(unit)
	if not tally.get(key, null) is Dictionary:
		tally[key] = {}
	tally[key][kind] = DeepRules.sat_add(int(tally[key].get(kind, 0)), amount)

static func gem_tally(unit: Dictionary, key: String, amount: int) -> void:
	## The same for the gem firing now, by stone id (see `firing_stone`, which is taken off
	## the unit when the gem is done, so nothing a creature does afterwards is the gem's).
	var id: String = str(unit.get("firing_stone", {}).get("stone_id", ""))
	if amount == 0 or id.is_empty() or str(unit.get("side", "")) != "player":
		return
	var gems: Dictionary = stats_of(unit).gems
	if not gems.has(id):
		gems[id] = {"damage": 0, "block": 0, "healed": 0, "debuffs": 0, "ore": 0, "fires": 0, "best": 0}
	gems[id][key] = DeepRules.sat_add(int(gems[id].get(key, 0)), amount)

static func _note_turn(state: Dictionary, unit: Dictionary) -> void:
	## The turn just played against the tally's bests: the most damage in one turn, and the
	## highest Resonance so far.
	if str(unit.get("side", "")) != "player":
		return
	var tally: Dictionary = stats_of(unit)
	var dealt: int = int(unit.get("dealt", 0))
	if dealt > int(tally.get("best_turn", {}).get("amount", 0)):
		tally.best_turn = {"amount": dealt, "creature": headline(state), "depth": int(state.get("depth", 0)), "turn": int(state.get("turn", 0))}
	tally.resonance = maxi(int(tally.get("resonance", 0)), int(unit.get("resonance", 0)))

static func _note_outcome(state: Dictionary) -> void:
	for unit in state.get("players", []):
		_note_turn(state, unit)

static func headline(state: Dictionary) -> String:
	## The creature a fight is remembered by: its Warden, else the biggest thing in it.
	var best: Dictionary = {}
	for foe in state.get("enemies", []):
		if bool(foe.get("warden", false)):
			return str(foe.get("name", ""))
		if best.is_empty() or int(foe.get("max_hp", 0)) > int(best.get("max_hp", 0)):
			best = foe
	return str(best.get("name", ""))

static func hand_name(a: Dictionary) -> String:
	## The best thing a hand shows, for the tally: five of a kind down to a pair, a straight
	## of five between four of a kind and a full house, all different, or nothing.
	var groups: Array = a.get("groups", [])
	var top: int = int(groups[0].get("count", 0)) if not groups.is_empty() else 0
	var second: int = int(groups[1].get("count", 0)) if groups.size() > 1 else 0
	if top >= 5:
		return "quint"
	if top >= 4:
		return "quad"
	if int(a.get("straight", {}).get("length", 0)) >= 5:
		return "straight"
	if top >= 3 and second >= 2:
		return "full_house"
	if top >= 3:
		return "triple"
	if top >= 2 and second >= 2:
		return "two_pair"
	if top >= 2:
		return "pair"
	if int(a.get("distinct", 0)) >= 5:
		return "distinct"
	return "nothing"

static func begin(players: Array, creature_keys: Array, context: Dictionary, rng_dice: RandomNumberGenerator, rng_creatures: RandomNumberGenerator) -> Dictionary:
	## `threat` is the depth the creatures are bred for, which a run that has pushed on from
	## one mine into the next finds a little deeper than the floor it stands on.
	var state: Dictionary = {"turn": 0, "phase": "planning", "outcome": "", "depth": int(context.get("depth", 1)),
		"threat": int(context.get("threat", context.get("depth", 1))),
		"party": players.size(), "elite": bool(context.get("elite", false)), "warden": bool(context.get("warden", false)),
		"players": players.duplicate(true), "enemies": [], "queue": [], "seq": 0}
	## Early Enrage: a Hazard tier's creatures enrage sooner and harder.
	if context.has("enrage_turn"):
		state.enrage_turn = int(context.enrage_turn)
		state.enrage_damage = int(context.get("enrage_damage", DeepContent.constant("enrage_damage", 2)))
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
		extra = _remembered(str(context.get("extra_trait", "")), rng_creatures)
	## Crown's Court: the boss at this place in the row is one the Rift remembers.
	var court: int = int(context.get("court", -1))
	state.next_enemy = 0
	for index in range(creature_keys.size()):
		var key: String = str(creature_keys[index])
		var own: Dictionary = extra if index == 0 else {}
		if index == court:
			own = _remembered("", rng_creatures)
		var foe: Dictionary = DeepCreatures.make(key, _enemy_id(state), state.threat, players.size(), context.get("scale", {}), rng_creatures, own)
		if not own.is_empty():
			foe.remembered = str(own.get("remembered", ""))
		state.enemies.append(foe)
		_bring_escorts(state, foe, rng_creatures)
	_begin_turn(state, rng_dice, rng_creatures)
	return state

static func _remembered(chosen: String, rng: RandomNumberGenerator) -> Dictionary:
	## What a boss the Rift remembers comes back with: one trait more, picked by the seed
	## before the fight so every guest sees the same creature.
	var remembered: String = chosen
	if remembered.is_empty():
		remembered = str(DeepRng.pick(rng, DeepContent.REMEMBERED_TRAITS))
	return {"name_prefix": "The Remembered ", "traits": {remembered: 25 if remembered == "sturdy" else true}, "remembered": remembered}

static func enrage_turn(state: Dictionary) -> int:
	## The turn a fight's creatures enrage on: the pack's, or sooner under Early Enrage.
	return int(state.get("enrage_turn", DeepContent.constant("enrage_turn", 7)))

static func enrage_step(state: Dictionary) -> int:
	## How much harder every blow lands for each turn of enrage.
	return int(state.get("enrage_damage", DeepContent.constant("enrage_damage", 2)))

static func _enemy_id(state: Dictionary) -> String:
	var id: String = "e%d" % int(state.get("next_enemy", 0))
	state.next_enemy = int(state.get("next_enemy", 0)) + 1
	return id

static func _bring_escorts(state: Dictionary, leader: Dictionary, rng: RandomNumberGenerator) -> void:
	## The creatures written in beside it: a Prismarch's prisms, a Heartrot's tendrils. They
	## stand either side of it in turn, the first on its right (as a summons does), so the
	## leader holds the middle of the row; they are bred to the same depth, and the leader
	## knows them by id.
	var right: Array = []
	var left: Array = []
	for key in DeepCreatures.definition(leader).get("escorts", []):
		var escort: Dictionary = DeepCreatures.make(str(key), _enemy_id(state), int(leader.get("depth", state.threat)), state.players.size(), leader.get("scale", {}), rng)
		escort.escort_of = str(leader.id)
		escort.summoned = true
		(right if right.size() <= left.size() else left).append(escort)
		leader.escorts.append(str(escort.id))
	if right.is_empty():
		return
	## The first on the left stands nearest the leader.
	left.reverse()
	var at: int = state.enemies.find(leader)
	state.enemies = state.enemies.slice(0, at) + left + [leader] + right + state.enemies.slice(at + 1)

static func default_target(foes: Array) -> Dictionary:
	## Who a hero's blows go at when they have not chosen: the Warden when one stands, since
	## its escorts stand either side of it, else the first creature in the row.
	for foe in foes:
		if bool(foe.get("warden", false)):
			return foe
	return foes[0] if not foes.is_empty() else {}

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
		## Either side of the caller in turn, the first on its right, so a boss that calls two
		## rats stands between them instead of at the end of a line.
		var at: int = state.enemies.find(source)
		if at < 0:
			state.enemies.append(foe)
		else:
			var left: int = 0
			var right: int = 0
			for index in range(state.enemies.size()):
				if str(state.enemies[index].get("summoned_by", "")) == str(source.id) and int(state.enemies[index].get("hp", 0)) > 0:
					if index < at:
						left += 1
					elif index > at:
						right += 1
			state.enemies.insert(at + 1 if right <= left else at, foe)
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
			## All or Nothing: the Gambler throws the whole bowl again or none of it.
			if all_or_nothing(unit):
				chosen = allowed.duplicate()
			if chosen.is_empty():
				return _refuse("choose dice to reroll")
			unit.hand = DeepDice.reroll(unit.hand, unit.dice, chosen, rng_dice)
			unit.rerolls = int(unit.rerolls) - 1
			tally_add(unit, "rerolls", 1)
			var loaded: Array = _loaded(unit, chosen, rng_dice)
			var dues: Dictionary = _pay_dues(state, unit, chosen)
			var crowned: Array = _crowns_rolled(unit, unit.hand.filter(func(r: Dictionary) -> bool: return chosen.has(str(r.get("die_id", "")))), true)
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
				"rerolls": unit.rerolls, "drain": drain, "scorch": scorch, "loaded": loaded, "dues": dues, "resonance": int(unit.resonance), "crowned": crowned})}
		"flip":
			## Sleight turns a die over onto a face of the opposite parity. See `shift_face`.
			if bool(unit.get("locked", false)):
				return _refuse("you have locked in")
			if int(unit.get("flips", 0)) <= 0:
				return _refuse("no parity shift left this turn")
			var wanted_id: String = str(cmd.get("die", ""))
			for roll in unit.hand:
				if str(roll.get("die_id", "")) != wanted_id or bool(roll.get("phantom", false)):
					continue
				var refusal: String = shift_refusal(unit, roll)
				if not refusal.is_empty():
					return _refuse(refusal)
				var face: int = shift_face(unit, roll)
				var die: Dictionary = _die_of(unit, wanted_id)
				roll.value = DeepDice.face_value(die.faces[face])
				roll.face = face
				roll.erase("shown")
				roll.erase("counted")
				roll.flipped = true
				unit.flips = int(unit.flips) - 1
				return {"ok": true, "event": _event(state, "flip", {"unit": player_id, "die": wanted_id, "value": int(roll.value),
					"hand": unit.hand.duplicate(true), "flips": int(unit.flips)})}
			return _refuse("no such die")
		"lock":
			unit.locked = true
			return {"ok": true, "event": _event(state, "lock", {"unit": player_id})}
		"unlock":
			## Locking in can be taken back only while there is still something to do with the
			## hand: a reroll or a shift left to spend. With neither, the dice are as they will be.
			if int(unit.get("rerolls", 0)) <= 0 and int(unit.get("flips", 0)) <= 0:
				return _refuse("nothing left to change: no rerolls or shifts")
			unit.locked = false
			return {"ok": true, "event": _event(state, "unlock", {"unit": player_id})}
		"target":
			var foe: Dictionary = enemy(state, str(cmd.get("enemy", "")))
			if foe.is_empty() or int(foe.hp) <= 0:
				return _refuse("no such creature")
			unit.target = str(foe.id)
			return {"ok": true, "event": _event(state, "target", {"unit": player_id, "enemy": unit.target})}
	return _refuse("unknown battle command " + kind)

## Sleight (Puck's shift) turns one die over onto a face of the other parity: the face whose
## number mirrors the one it shows (a 2 on a d6 to its 5, as a real die's opposite sides add
## up) when the die has that face, else the nearest number of the other parity it does have.
## It only ever lands on a plain face the die really carries, so the die is shown turned over
## rather than reading a number it has no face for, and a die whose faces are all odd or all
## even (an Even or Odd pattern, a Stretched die) cannot be shifted at all.

static func _die_of(unit: Dictionary, die_id: String) -> Dictionary:
	for die in unit.get("dice", []):
		if str(die.get("id", "")) == die_id:
			return die
	return {}

static func shift_face(unit: Dictionary, roll: Dictionary) -> int:
	## The face Sleight would turn this roll onto, or -1 when there is none.
	var die: Dictionary = _die_of(unit, str(roll.get("die_id", "")))
	var faces: Array = die.get("faces", [])
	var previous: int = int(roll.get("value", 1))
	var mirror: int = maxi(1, int(roll.get("top", DeepDice.top(die)))) + 1 - previous
	var best: int = -1
	for index in range(faces.size()):
		if str(faces[index].get("kind", "plain")) != "plain":
			continue
		var value: int = DeepDice.face_value(faces[index])
		if value <= 0 or value % 2 == previous % 2:
			continue
		var distance: int = absi(value - mirror)
		var best_distance: int = absi(DeepDice.face_value(faces[best]) - mirror) if best >= 0 else 0
		## Nearest the mirror; between two as near, the one nearer what it showed.
		if best < 0 or distance < best_distance or (distance == best_distance and absi(value - previous) < absi(DeepDice.face_value(faces[best]) - previous)):
			best = index
	return best

static func shift_refusal(unit: Dictionary, roll: Dictionary) -> String:
	## Why Sleight cannot shift this roll, or "".
	if bool(roll.get("phantom", false)):
		return "a phantom die cannot be shifted"
	if str(roll.get("kind", "plain")) != "plain":
		return "only a plain face can be shifted"
	if _die_of(unit, str(roll.get("die_id", ""))).is_empty():
		return "no such die"
	if shift_face(unit, roll) < 0:
		return "that die has no face of the other parity to turn to"
	return ""

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
			unit.rail_plays = 0
			unit.damp_carry = 0
			unit.force_after = {}
			unit.fired_colors = []
			unit.gem_results = {}
			unit.resonance_mult = 1
			if str(unit.get("passive", {}).get("kind", "")) == "first_gem_cut_step":
				unit.cut_step_bonus = int(unit.passive.get("amount", 1))
			## Second Wind is paid at rail_end, on the Resonance the rail built; the rerolls it
			## banks are already counted here, because planning is over.
			tally_kind(unit, "hands", hand_name(DeepHand.analyze(unit.hand)), 1)
			return _event(state, "rail_begin", {"unit": unit.id, "unused_rerolls": int(unit.get("rerolls", 0)), "healed": 0, "resonance": int(unit.resonance)})
		"gem":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty() or bool(unit.get("downed", false)) or done(state):
				return {}
			if _spent(unit):
				return _spend_rail(state, unit)
			return resolve_gem(state, unit, int(s.socket), {"retrigger": bool(s.get("retrigger", false)), "scale": int(s.get("scale", 100)),
				"replay": bool(s.get("replay", false)), "force": bool(s.get("force", false)), "as_skill": str(s.get("as_skill", ""))}, rng_dice)
		"birthstone":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty() or bool(unit.get("downed", false)) or done(state):
				return {}
			if _spent(unit):
				return _spend_rail(state, unit)
			return resolve_birthstone(state, unit, {"replay": bool(s.get("replay", false)), "share": int(s.get("share", 100))}, rng_dice)
		"rail_end":
			var unit: Dictionary = player(state, str(s.unit))
			if unit.is_empty():
				return {}
			## Second Wind: the Knight banks the rerolls he did not spend, each one worth the
			## Resonance his rail just built. It is paid here because at rail_begin there is
			## no Resonance yet to pay it with.
			var resonance: int = int(unit.get("resonance", 0))
			## The rail has closed: its plays are no longer hurrying anything (see `rush`).
			unit.rail_plays = 0
			## Everything this rail rang goes on the fight's tally, which a Crescendo reads.
			unit.fight_resonance = DeepRules.sat_add(int(unit.get("fight_resonance", 0)), resonance)
			var unused: int = int(unit.get("rerolls", 0))
			var healed: int = 0
			## Counted out like a Birthstone's tier: the rerolls left, times the Resonance.
			var count: Dictionary = {}
			if str(unit.get("passive", {}).get("kind", "")) == "heal_resonance_per_unused_reroll" and unused > 0 and resonance > 0:
				healed = _heal(unit, DeepRules.sat_mul(resonance, unused))
				count = {"name": str(unit.passive.get("name", "Second Wind")), "line": "%d unspent %s" % [unused, "reroll" if unused == 1 else "rerolls"],
					"pace": count_pace(state), "kind": "heal", "target": str(unit.id), "repeat": 1, "res": resonance, "coef": unused,
					"coef_what": "rerolls", "amount": DeepRules.sat_mul(resonance, unused), "healed": healed, "adds": [], "also": []}
			## The last rail of the turn has had its say since the last creature fell: now the
			## fight is won. An ally's rail still queued after this one fires first.
			if bool(state.get("cleared", false)) and not _rail_firing(state):
				_close_cleared(state)
			return _event(state, "rail_end", {"unit": unit.id, "resonance": resonance, "unused_rerolls": unused, "healed": healed, "count": count,
				"duration": BASE_DURATION.rail_end + (birth_span(count) + BIRTH_LAND if not count.is_empty() else 0.0)})
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
			## sending back, the colors it was drinking.
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
				_tick_charge(state, foe, true)
				return _event(state, "skip", {"unit": foe.id, "why": why, "combo_breaker": int(foe.statuses.get("combo_breaker", 0)) == 2})
			foe.stun_streak = 0
			foe.stun_guard = false
			## A blow it has been winding up: another action closer, or let go now.
			var charge: Dictionary = _tick_charge(state, foe)
			if not charge.is_empty():
				fields.charge = charge
				if charge.has("release"):
					var release: Dictionary = {"move": str(charge.get("name", "Release")), "index": - 1, "effects": charge.release, "dice": [],
						"combo": true, "trigger": {"kind": "each_turn"}, "roll_index": - 1, "release": true}
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
				if str(effect.kind) == "damage" and int(state.turn) >= enrage_turn(state):
					effect.amount += enrage_step(state) * (int(state.turn) - enrage_turn(state) + 1)
				if str(effect.kind) == "damage":
					effect.amount = DeepRules.outgoing_damage(int(effect.amount), foe.statuses)
			var counted: Dictionary = creature_tally(state, foe, move, shown)
			return _event(state, "enemy_ability", {"unit": foe.id, "move": move.move, "index": move.index,
				"dice": move.dice, "combo": move.combo, "trigger": move.trigger, "effects": shown, "tally": counted,
				"duration": (1.0 if bool(move.combo) else 0.7) + tally_span(counted)})
		"enemy_move":
			var foe: Dictionary = enemy(state, str(s.unit))
			if foe.is_empty() or int(foe.hp) <= 0 or done(state):
				return {}
			return _enemy_act(state, foe, s.move, rng_dice)
		"tick":
			return _tick(state, rng_creatures)
		"turn_end":
			return _end_turn(state, rng_dice, rng_creatures)
	return {}

static func _drop_steps(state: Dictionary, unit_id: String) -> void:
	state.queue = state.queue.filter(func(q: Dictionary) -> bool: return str(q.get("unit", "")) != unit_id)

static func rush(plays: int) -> float:
	## How many times faster a rail plays out once it has played `plays` gems this turn. An
	## ordinary rail never notices; one that keeps firing is played faster with every gem, and
	## the faster it has gone, the faster it may go, up to RUSH_MOST.
	return minf(1.0 + RUSH_STEP * float(maxi(0, plays - RUSH_FROM)), RUSH_MOST)

static func rail_plays(state: Dictionary) -> int:
	## How many gems the rail firing now has played this turn (0 while none is).
	var most: int = 0
	for unit in state.get("players", []):
		most = maxi(most, int(unit.get("rail_plays", 0)))
	return most

static func _spent(unit: Dictionary) -> bool:
	## Counts one more play of this rail, and says whether it is past RAIL_CAP.
	unit.rail_plays = int(unit.get("rail_plays", 0)) + 1
	return int(unit.rail_plays) > RAIL_CAP

static func _spend_rail(state: Dictionary, unit: Dictionary) -> Dictionary:
	## The rail has played all it may this turn: every gem and Birthstone still queued for it
	## is dropped. Its close stays, so what the rail rang is still counted.
	var dropped: int = 1
	var kept: Array = []
	for q in state.queue:
		if str(q.get("unit", "")) == str(unit.id) and str(q.get("kind", "")) in ["gem", "birthstone"]:
			dropped += 1
		else:
			kept.append(q)
	state.queue = kept
	## It fires no more, so it hurries nothing: the turn slows back down to be read.
	unit.rail_plays = 0
	return _event(state, "rail_spent", {"unit": unit.id, "plays": RAIL_CAP, "dropped": dropped, "duration": 1.2})

# --- gems --------------------------------------------------------------------------------

static func _under_line(roll: Dictionary, line: Dictionary, raised: Array) -> bool:
	## Whether a die the trigger matched is still one an upgrade may raise. A die judged by a
	## line ("below 6") is judged by the face it shows now, so a raise that carried it past
	## the line ends its turn; a wild matched every line and is raised once a firing.
	if str(roll.get("kind", "plain")) == "wild":
		return not raised.has(str(roll.get("die_id", "")))
	if line.is_empty():
		return true
	var face: int = int(roll.get("base", roll.get("value", 0)))
	var need: int = int(line.get("need", 0))
	return face < need if str(line.get("kind", "")) == "below" else face <= need

static func rail_context(state: Dictionary, unit: Dictionary, socket: int, opts: Dictionary = {}) -> Dictionary:
	## What the rail hands a gem at this socket: the bonuses its neighbours and the run give
	## it, and what the previous gem did.
	var stone: Dictionary = DeepStone.fingerprinted(unit.rail, socket, unit.rail[socket])
	var socket_color: String = str(unit.sockets[socket]) if socket < unit.sockets.size() else "ANY"
	var carat_bonus: int = 0
	for neighbour in [socket - 1, socket + 1]:
		if neighbour < 0 or neighbour >= unit.rail.size() or not unit.rail[neighbour] is Dictionary:
			continue
		var other: Dictionary = DeepStone.fingerprinted(unit.rail, neighbour, unit.rail[neighbour])
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
		## Dull Vault: a Hazard tier judges every stone that came down from the vault a Cut lower.
		"dulled": int(unit.get("statuses", {}).get("dulled", 0)) + (int(unit.get("run_mods", {}).get("dull_vault", 0)) if bool(stone.get("lent", false)) and not bool(stone.get("temporary", false)) else 0),
		## What a Fingerprint here is carrying, for the close look to name.
		"fingerprint": DeepStone.fingerprint_words(unit.rail, socket),
		"depth": int(state.get("depth", 1)),
		"turn": int(state.get("turn", 1)), "party": int(state.get("party", 1)), "socket": socket_color,
		## Creatures fallen this turn (a Placer's trigger) and this stone's fires this run (a Hone's count).
		"kills": int(state.get("turn_kills", 0)), "run_fires": int(unit.get("run_counts", {}).get(str(stone.get("id", "")), 0)),
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
	var stone: Dictionary = unit.rail[socket] if worn < 0 else DeepStone.wearing(unit.rail[socket], unit.rail[worn])
	## A Fingerprint carries an inclusion of the gem before it for as long as it fights there.
	return DeepStone.fingerprinted(unit.rail, socket, stone)

static func repeatable(unit: Dictionary, socket: int) -> bool:
	## What an opal's repeat is allowed to touch. Never another opal: that one rule is the
	## whole of why two opals can never call each other for ever. A Doublet wearing another
	## gem's skill is no longer opal work, so it plays again like anything else.
	if socket < 0 or socket >= unit.rail.size() or not unit.rail[socket] is Dictionary:
		return false
	if not DeepStone.is_opal(unit.rail[socket]):
		return true
	return worn_socket(unit, socket) >= 0

static func certain_times(unit: Dictionary, socket: int, retrigger: bool) -> int:
	## How many times a Certainty earlier on the rail has this socket fire this turn, whatever
	## the dice say: 0 when none stands before it. A replay is not the gem's own turn and an
	## opal still answers only to Resonance, so neither is touched.
	var certainty: Dictionary = unit.get("force_after", {})
	if retrigger or certainty.is_empty() or socket <= int(certainty.get("from", 0)):
		return 0
	if socket < 0 or socket >= unit.rail.size() or not unit.rail[socket] is Dictionary or DeepStone.is_opal(unit.rail[socket]):
		return 0
	return maxi(0, int(certainty.get("times", 0)))

static func resolve_gem(state: Dictionary, unit: Dictionary, socket: int, opts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## One gem fires or fizzles. `opts.retrigger` marks a repeat, `opts.scale` a percentage
	## an Echo repeats at, `opts.force` a Matrix waking a gem the hand never asked for, and
	## `opts.dry` a forecast that must not roll coins or queue repeats.
	var dry: bool = bool(opts.get("dry", false))
	if socket < 0 or socket >= unit.rail.size() or not unit.rail[socket] is Dictionary:
		return {}
	## A Doublet fires as the gem it wears; everything else is simply itself. The id, the
	## four C's and the inclusions stay the socket's own either way. A Black Opal fires each
	## skill it has absorbed the same way, as a stone wearing it (`opts.as_skill`).
	var stone: Dictionary = stone_at(unit, socket)
	if not str(opts.get("as_skill", "")).is_empty():
		stone = DeepStone.wearing(unit.rail[socket], {"skill": str(opts.as_skill)})
	## A Certainty earlier on the rail: this gem fires whatever the dice say, and as often as
	## it was told to. Only its own turn on the rail counts, never a replay of it.
	var certain: int = certain_times(unit, socket, bool(opts.get("retrigger", false)))
	if certain > 0 and not bool(opts.get("force", false)):
		opts = opts.duplicate()
		opts.force = true
	if unit.buried.has(socket) or unit.clouded.has(socket):
		## What the gem before handed this one is spent here, as on any gem that stays dark.
		unit.amplify = 1.0
		unit.cut_step_bonus = 0
		unit.nullify_next = false
		unit.repeat_next = 0
		unit.previous_fired = false
		return _event(state, "gem_fizzle", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
			"reason": "The socket is buried." if unit.buried.has(socket) else "The socket is clouded.", "resonance": unit.resonance, "blocked": true})
	var context: Dictionary = rail_context(state, unit, socket, opts)
	var ev: Dictionary = DeepStone.evaluate(stone, unit.hand, context)
	for effect in ev.get("effects", []):
		if int(effect.get("cost", 0)) > DeepRules.pyrite(unit):
			ev.active = false
			ev.reason = "Not enough Pyrite."
		## A gem that costs blood never takes the last of it: it stays dark instead.
		if int(effect.get("hp_cost", 0)) > 0 and ev.active and int(effect.hp_cost) >= int(unit.hp):
			ev.active = false
			ev.reason = "Not enough health."
		## An Invert with nothing beside it to turn around stays dark, however it was woken.
		if str(effect.get("kind", "")) == "invert_previous" and ev.active and _left_results(unit, socket).is_empty():
			ev.active = false
			ev.reason = "The gem before it did nothing to turn around."
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
	## Blood a gem asks for itself (Bloodletting), paid as it fires: block does not soak it.
	for effect in ev.get("effects", []):
		hp_cost += maxi(0, int(effect.get("hp_cost", 0)))
	if hp_cost > 0:
		unit.hp = maxi(1, int(unit.hp) - hp_cost)
	var harmony: bool = false
	if bool(unit.get("previous_fired", false)):
		for color in unit.get("previous_colors", []):
			if ev.get("colors", []).has(color):
				harmony = true
	var gain: int = DeepRules.sat_mul(int(ev.get("resonance_gain", 1)) + (1 if harmony else 0), maxi(1, int(unit.get("resonance_mult", 1))))
	## A Null Shade in the room: the rail rings for only part of what it should. What is lost
	## is carried in hundredths, so two gems at half each still make one.
	var damp: int = 0
	for foe in living(state.enemies):
		damp = maxi(damp, DeepCreatures.trait_value(foe, "resonance_damp", 0))
	if damp > 0:
		var pooled: int = DeepRules.sat_add(DeepRules.sat_mul(gain, 100 - clampi(damp, 0, 100)), int(unit.get("damp_carry", 0)))
		gain = pooled / 100
		unit.damp_carry = pooled % 100
	unit.resonance = DeepRules.sat_add(int(unit.get("resonance", 0)), gain)
	## The Strength every blow of this gem will carry, as it fires, for the count to show.
	var strength: int = maxi(0, int(unit.get("statuses", {}).get("strength", 0)))
	var results: Array = []
	var previous_socket: int = int(unit.get("previous_socket", -1))
	var reactions: Dictionary = {}
	## Who is throwing, and in what color: a creature that drinks a color, holds the
	## gem that hit it hardest or answers whoever hurt it most reads these off every blow.
	unit.firing_colors = ev.get("colors", []).duplicate()
	unit.firing_stone = {"stone_id": str(stone.get("id", "")), "socket": socket}
	unit.firing_hit = 0
	## What a Chainmail or a Contagion earlier this turn hands over for this gem: taken now,
	## so the one that sets it up is not paid for itself.
	var answers: Array = unit.get("after_fire", []).duplicate(true)
	unit.fired_count = int(unit.get("fired_count", 0)) + 1
	## What this go does, kept for an Invert in the socket after it (see `_note_result`).
	var outer_results: Variant = unit.get("firing_results", null)
	unit.firing_results = {}
	## Backlash: with a Riftling Swarm in the room, every gem that fires costs its owner a point
	## of blood, wherever it sits on the rail. Never the last point.
	var backlash: int = 0
	if not dry:
		for foe in living(state.enemies):
			if DeepCreatures.has_trait(foe, "backlash"):
				backlash = 1
		if backlash > 0:
			unit.hp = maxi(1, int(unit.hp) - backlash)
	var crowns_before: Dictionary = _crown_ids(unit.hand) if all_or_nothing(unit) else {}
	for effect in ev.get("effects", []):
		var applied: Dictionary = effect.duplicate(true)
		if scale != 100 and bool(effect.get("scaled", false)):
			applied.amount = DeepRules.sat_floor(float(int(effect.amount)) * float(scale) / 100.0)
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
	var crowned: Array = _crowns_changed(unit, crowns_before) if all_or_nothing(unit) else []
	if not done(state):
		results.append_array(_answer_fire(state, unit, answers, rng))
	## Only its most recent go is kept: a replay of it overwrites what the first go did.
	if not unit.has("gem_results"):
		unit.gem_results = {}
	unit.gem_results[str(stone.get("id", ""))] = unit.firing_results
	if outer_results is Dictionary:
		unit.firing_results = outer_results
	else:
		unit.erase("firing_results")
	if not dry:
		## The tally: one more fire for the stone, and what this one did against its best and
		## the run's biggest hit.
		gem_tally(unit, "fires", 1)
		var hit: int = int(unit.get("firing_hit", 0))
		if hit > 0:
			var id: String = str(stone.get("id", ""))
			var kept: Dictionary = stats_of(unit).gems.get(id, {})
			kept.best = maxi(int(kept.get("best", 0)), hit)
			if hit > int(stats_of(unit).get("best_hit", {}).get("amount", 0)):
				var struck: Dictionary = enemy(state, str(unit.get("firing_target", "")))
				stats_of(unit).best_hit = {"amount": hit, "stone_id": id, "skill": str(stone.get("skill", "")), "socket": socket,
					"creature": str(struck.get("name", "")) if not struck.is_empty() else headline(state), "depth": int(state.get("depth", 0))}
	unit.erase("firing_hit")
	unit.erase("firing_colors")
	unit.erase("firing_stone")
	## A gem that grows over the run (Hone, Hardening) counts every fire, replays included.
	if not dry:
		var counts: Dictionary = unit.get("run_counts", {})
		counts[str(stone.get("id", ""))] = int(counts.get(str(stone.get("id", "")), 0)) + 1
		unit.run_counts = counts
	## The colors that have fired this turn, fire by fire, for a Spectrum to read.
	if not unit.has("fired_colors"):
		unit.fired_colors = []
	unit.fired_colors.append(ev.get("colors", []).duplicate())
	## A Refractor grows a point stronger for every color of gem it sees fired, once a color.
	var fed: Array = []
	if not dry:
		for foe in living(state.enemies):
			if not DeepCreatures.has_trait(foe, "color_strength"):
				continue
			for color in ev.get("colors", []):
				if not foe.get("seen_colors", []).has(color):
					foe.seen_colors.append(color)
					foe.statuses.strength = int(foe.statuses.get("strength", 0)) + 1
					fed.append({"unit": str(foe.id), "color": str(color), "strength": int(foe.statuses.strength)})
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
	if not dry and certain > 1:
		for _more in range(certain - 1):
			state.queue.push_front({"kind": "gem", "unit": unit.id, "socket": socket, "retrigger": true, "force": true})
	_settle_marks(state)
	_check_outcome(state)
	var tally: Dictionary = tally_of(ev, scale, strength)
	if not tally.is_empty():
		tally.pace = count_pace(state)
	return _event(state, "gem_fire", {"unit": unit.id, "socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill),
		"dice": ev.get("dice", []), "effects": results, "resonance": unit.resonance, "gain": gain, "harmony": harmony, "tally": tally,
		"magnitude": float(ev.get("magnitude", 1.0)), "carat": int(ev.get("carat", 1)), "cut_step": int(ev.get("cut_step", 0)),
		"die_boost": float(ev.get("die_boost", 1.0)), "materials": DeepDice.matching_materials(DeepStone.rolls_of(unit.hand, ev.get("dice", [])), ev.get("colors", [])),
		"retrigger": retrigger, "replay": bool(opts.get("replay", false)), "scale": scale, "hp_cost": hp_cost, "fires": int(ev.get("fires", 1)),
		"forced": bool(opts.get("force", false)), "promised": promised if not retrigger else 0, "worn": str(stone.get("worn_from", "")),
		"absorbed": str(opts.get("as_skill", "")), "certain": certain,
		"backlash": backlash, "fired_count": int(unit.get("fired_count", 0)), "damped": damp > 0, "fed": fed, "crowned": crowned,
		"duration": BASE_DURATION.gem_fire + tally_span(tally) + maxf(0.1 * float(results.size()), hits_span(results))})

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
	## A Birthright fires it mid-rail at a share of the Resonance so far.
	var resonance: int = DeepRules.sat_muldiv(int(unit.get("resonance", 0)), maxi(0, int(opts.get("share", 100))), 100)
	## On Fire: last turn's High Roller doubled the whole total it reads this turn.
	var doubled: bool = bool(unit.get("resonance_doubled", false))
	if doubled:
		resonance = DeepRules.sat_mul(resonance, 2)
	## The Changing Face (Motley): a face different from last turn's pays double, and every
	## turn the faces keep changing pays one more, ×2, ×3, ×4. The same face twice running, or
	## a hand that shows none, starts it over. The face is the hand's parity, every die.
	var face: String = face_of(a) if bool(def.get("changing_face", false)) else ""
	var change: int = 0
	if not face.is_empty() and not str(unit.get("last_face", "")).is_empty() and face != str(unit.get("last_face", "")):
		change = int(unit.get("change", 0)) + 1
	if bool(def.get("changing_face", false)) and not dry:
		unit.face_shown = face
		unit.change_now = change
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
	## The Strength every blow carries, for the counts to show on top.
	var strength: int = maxi(0, int(unit.get("statuses", {}).get("strength", 0)))
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
			## Each effect as it was resolved, by the def it came from, and what it did: the
			## count reads these, since a pot term means something else once the pot has moved.
			var resolved: Array = []
			for effect_def in tier.get("effects", []):
				if not effect_def is Dictionary:
					continue
				var applied: Dictionary = DeepRules.resolve_effect(effect_def, tc, 1.0)
				var kind: String = str(applied.kind)
				## The Changing Face multiplies what the faces land: the blow, the guard.
				if change > 0 and kind in TALLY_KINDS and kind != "gold":
					applied.amount = DeepRules.sat_mul(int(applied.get("amount", 0)), 1 + change)
				var did: Array = []
				if kind in HAND_KINDS:
					did = [_mutate_hand(unit, applied)]
				elif kind in SELF_KINDS:
					## A Motif plays the gem before the Birthstone again: the last one that fired.
					did = [_self_effect(state, unit, applied, -1, int(unit.get("previous_socket", -1)), dry, rng)]
				elif kind in BIRTHSTONE_KINDS:
					did = [_birthstone_effect(state, unit, applied, dry, replay, rng)]
				else:
					did = _apply(state, unit, applied, rng, "", reactions)
				results.append_array(did)
				resolved.append([effect_def, applied, did])
				if done(state):
					break
			entry.effects = results
			entry.count = birth_count(str(entry.name), entry.trigger, resolved, resonance, a, strength, count_pace(state))
			if change > 0 and entry.count.has("amount"):
				## The count shows the multiplied figure: the tier's own three, twice.
				entry.count.change = 1 + change
				if entry.count.has("coef"):
					entry.count.coef = int(entry.count.coef) * (1 + change)
				elif entry.count.has("base"):
					entry.count.base = int(entry.count.base) * (1 + change)
		tiers.append(entry)
		if done(state):
			break
	if not dry and not replay and promised > 0:
		for _more in range(promised):
			state.queue.push_front({"kind": "birthstone", "unit": unit.id, "replay": true})
	## How hot a streak next turn rides on, for the screens to wear: a reroll earned (1), a die
	## (2), doubled Resonance (3). The highest any firing this turn reached.
	if not dry:
		var streak: int = 0
		for entry in tiers:
			if not bool(entry.get("active", false)):
				continue
			for effect in entry.get("effects", []):
				match str(effect.get("kind", "")):
					"grant_reroll": streak = maxi(streak, 1)
					"bonus_die": streak = maxi(streak, 2)
					"double_resonance_next": streak = maxi(streak, 3)
		unit.streak_next = maxi(int(unit.get("streak_next", 0)), streak)
	## The Birthstone is a gem that fired, as far as a Chainmail is concerned.
	var answered: Array = []
	if fired and not dry:
		tally_add(unit, "birthstone", 1)
	if fired and not done(state):
		answered = _answer_fire(state, unit, unit.get("after_fire", []), rng)
	_settle_marks(state)
	_check_outcome(state)
	## The lit tiers are counted and land one after another, so the step holds all of them:
	## a Thousand Cuts is one tier throwing twenty bolts, a Rally three tiers in a row.
	var played: float = 0.0
	for entry in tiers:
		if bool(entry.active):
			played += tier_span(entry)
	return _event(state, "birthstone", {"unit": unit.id, "name": str(def.get("name", "Birthstone")), "style": str(def.get("style", "")),
		"tiers": tiers, "fired": fired, "dice": all_dice, "resonance": resonance, "replay": replay, "promised": promised, "answers": answered, "doubled": doubled,
		"face": face, "change": change,
		"duration": (BASE_DURATION.birthstone + played) if fired else BASE_DURATION.gem_fizzle})

static func face_of(a: Dictionary) -> String:
	## The face a hand wears for Motley: "odd" when every die is odd, "even" when every die is
	## even, "" when it is mixed. A hand with no dice wears none.
	var count: int = int(a.get("dice_count", 0))
	if count <= 0:
		return ""
	if int(a.get("odd", 0)) == count:
		return "odd"
	if int(a.get("even", 0)) == count:
		return "even"
	return ""

static func next_face_pays(unit: Dictionary) -> int:
	## What the Changing Face would multiply a face by this turn, if it is the other face from
	## last turn's: 2 the first time the faces change, 3 the next, and so on. 1 with no run on.
	if str(unit.get("last_face", "")).is_empty():
		return 1
	return 2 + int(unit.get("change", 0))

static func tier_span(entry: Dictionary) -> float:
	## One lit tier on screen: its count, then what it does landing (at the least BIRTH_LAND,
	## for a guard, a heal or a stun to be seen).
	return birth_span(entry.get("count", {})) + maxf(BIRTH_LAND, hits_span(entry.get("effects", [])))

static func birth_count(name: String, trigger: Dictionary, resolved: Array, resonance: int, a: Dictionary, strength: int, pace: float) -> Dictionary:
	## What one lit tier is seen to add up to, for the screen to count out before it lands:
	## its name, called out; the number Resonance multiplies (the tier's own three, or the
	## crowns showing, which hop); Resonance itself; what the pot held and what the bank put
	## in; the Strength every blow carries; and the figure each blow lands with, so many times.
	## `resolved` is [def, applied, results] for each effect the tier fired. A tier with no
	## figure (a cleanse, an Encore, the poison ticking) is only called out. Nothing reads this
	## back: it says what the rules already did. `trigger` is the tier's, as described.
	var count: Dictionary = {"name": name, "line": str(trigger.get("words", "")), "pace": pace,
		"trigger": {"kind": str(trigger.get("kind", "")), "need": int(trigger.get("need", 0))}}
	var headline: int = -1
	for index in range(resolved.size()):
		var applied: Dictionary = resolved[index][1]
		if str(applied.get("kind", "")) in TALLY_KINDS and str(applied.get("kind", "")) != "gold":
			headline = index
			break
	for entry in resolved:
		var applied: Dictionary = entry[1]
		if str(applied.get("kind", "")) == "pot" and not entry[2].is_empty():
			var moved: Dictionary = entry[2][0]
			count.pot = {"mode": str(moved.get("mode", "")), "was": int(moved.get("was", 0)), "moved": int(moved.get("moved", 0)), "total": int(moved.get("total", 0))}
		elif str(applied.get("kind", "")) == "gold" and headline >= 0:
			## All In pays him what the pot took off them.
			var paid: int = 0
			for result in entry[2]:
				paid += int(result.get("amount", 0)) if result is Dictionary else 0
			count.payout = paid
	if headline < 0:
		return count
	var def: Dictionary = resolved[headline][0]
	var headline_applied: Dictionary = resolved[headline][1]
	var kind: String = str(headline_applied.kind)
	var amount: int = int(headline_applied.get("amount", 0))
	count.kind = kind
	count.target = str(headline_applied.get("target", ""))
	count.repeat = maxi(1, int(headline_applied.get("repeat", 1)))
	var expr: Variant = def.get("amount", null)
	var other: Array = _resonance_factor(expr)
	if not other.is_empty():
		## Resonance times something: the something is the base, Resonance its multiplier.
		count.res = resonance
		var by: Variant = other[0]
		if by == null:
			count.coef = 1
		else:
			count.coef = DeepRules.amount(by, {"a": a})
			if by is Dictionary and str(by.get("term", "")) == "crowns":
				count.coef_what = "crowns"
				count.coef_dice = a.get("crown_ids", []).duplicate()
	elif _reads_pot(expr):
		## The pot is the figure: what it held, then what the bank matched (a Raise, All In),
		## or half of it (a Bust).
		count.half = _halves(expr)
		count.base = int(count.get("pot", {}).get("was", amount * (2 if bool(count.half) else 1)))
	else:
		count.base = amount
	## A blow thrown once for every point on the highest die: that die says how many.
	var times: Variant = def.get("repeat", null)
	if times is Dictionary and str(times.get("term", "")) == "high":
		var showing: Array = a.get("ids_by_value", {}).get(int(a.get("high", 0)), [])
		count.repeat_die = str(showing[0]) if not showing.is_empty() else ""
	var adds: Array = []
	if kind == "damage" and amount > 0 and strength > 0 and count.target != "self":
		adds.append({"what": "strength", "by": strength})
		amount += strength
	count.adds = adds
	count.amount = amount
	## Anything else the tier lands with its figure (Full Motley's guard beside its blow).
	var also: Array = []
	for index in range(resolved.size()):
		var applied: Dictionary = resolved[index][1]
		if index != headline and str(applied.get("kind", "")) in TALLY_KINDS and str(applied.get("kind", "")) != "gold" and int(applied.get("amount", 0)) > 0:
			also.append({"kind": str(applied.kind), "amount": int(applied.amount)})
	count.also = also
	return count

static func _resonance_factor(expr: Variant) -> Array:
	## [the other factor] when an amount is Resonance times something ([null] when it is
	## Resonance alone); [] when it is not written on Resonance.
	if not expr is Dictionary:
		return []
	if str(expr.get("term", "")) == "resonance":
		return [null]
	if str(expr.get("op", "")) != "*" or expr.get("args", []).size() != 2:
		return []
	for index in range(2):
		var arg: Variant = expr.args[index]
		if arg is Dictionary and str(arg.get("term", "")) == "resonance":
			return [expr.args[1 - index]]
	return []

static func _reads_pot(expr: Variant) -> bool:
	if not expr is Dictionary:
		return false
	if str(expr.get("term", "")) == "pot":
		return true
	for arg in expr.get("args", []):
		if _reads_pot(arg):
			return true
	return false

static func _halves(expr: Variant) -> bool:
	## Half of something, floored: a Bust's half of the pot.
	if not expr is Dictionary or str(expr.get("op", "")) != "floor_div":
		return false
	var args: Array = expr.get("args", [])
	return args.size() == 2 and (args[1] is int or args[1] is float) and int(args[1]) == 2

static func birth_span(count: Dictionary) -> float:
	## How long a tier's count takes on screen, from its name being called to its figure
	## leaving, at the pace the host chose: all of it at Full, half at Quick, and at Off the
	## name and the figure together, for a moment.
	if count.is_empty():
		return 0.0
	var pace: float = clampf(float(count.get("pace", 1.0)), 0.0, 1.0)
	if pace <= 0.0:
		return BIRTH_GLANCE
	var span: float = BIRTH_CALL
	if count.has("amount"):
		var dice: int = count.get("coef_dice", []).size()
		if dice > 0:
			span += tally_die_gap(dice) * float(dice - 1) + TALLY_FLIGHT
		elif int(count.get("coef", 1)) != 1 or count.has("base"):
			span += TALLY_STEP
		if count.has("res"):
			span += BIRTH_FLOW
		if str(count.get("pot", {}).get("mode", "")) in ["double", "all"] and count.has("base"):
			span += TALLY_STEP
		if bool(count.get("half", false)):
			span += TALLY_STEP
		span += TALLY_FUSE
		if not str(count.get("repeat_die", "")).is_empty():
			span += TALLY_STEP
		span += TALLY_STEP * float(count.get("adds", []).size())
	return span * pace

static func _has_effect(tier: Dictionary, kind: String) -> bool:
	for effect in tier.get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == kind:
			return true
	return false

static func _answer_fire(state: Dictionary, unit: Dictionary, answers: Array, rng: RandomNumberGenerator) -> Array:
	## What a Chainmail or a Contagion earlier this turn gives for one more gem fired: its
	## block, spikes or poison, through the same pipeline as anything else, so a Rebound
	## answers the block and Ward turns the poison away.
	var out: Array = []
	for answer in answers:
		var hits: Array = _apply(state, unit, {"kind": str(answer.kind), "amount": int(answer.amount), "target": str(answer.target), "repeat": 1}, rng)
		for hit in hits:
			hit.answer = true
		out.append_array(hits)
		if done(state):
			break
	return out

static func _birthstone_effect(state: Dictionary, unit: Dictionary, effect: Dictionary, dry: bool, replay: bool, rng: RandomNumberGenerator = null) -> Dictionary:
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
					var tick: Dictionary = _poison_tick(state, foe, rng)
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

static func all_or_nothing(unit: Dictionary) -> bool:
	## Florin's All or Nothing: he throws the whole bowl or none of it.
	return str(unit.get("passive", {}).get("kind", "")) == "all_or_nothing"

static func _largest_die(unit: Dictionary) -> Dictionary:
	## The die in the hand with the most faces; between two as large, the one showing more.
	var best: Dictionary = {}
	var best_roll: Dictionary = {}
	for roll in unit.get("hand", []):
		if bool(roll.get("phantom", false)):
			continue
		var die: Dictionary = _die_of(unit, str(roll.get("die_id", "")))
		if die.is_empty():
			continue
		var faces: int = die.get("faces", []).size()
		var best_faces: int = best.get("faces", []).size() if not best.is_empty() else -1
		if best.is_empty() or faces > best_faces or (faces == best_faces and int(roll.get("value", 0)) > int(best_roll.get("value", 0))):
			best = die
			best_roll = roll
	return best

static func is_crown(roll: Dictionary) -> bool:
	## A die showing its own top face, read the way DeepHand counts crowns: a wild always is.
	var kind: String = str(roll.get("kind", "plain"))
	if kind == "wild":
		return true
	if kind == "blank":
		return false
	return int(roll.get("value", 0)) >= maxi(1, int(roll.get("top", roll.get("value", 1))))

static func _crown_ids(hand: Array) -> Dictionary:
	var out: Dictionary = {}
	for roll in hand:
		if is_crown(roll):
			out[str(roll.get("die_id", ""))] = true
	return out

static func _crowns_rolled(unit: Dictionary, rolls: Array, planning: bool) -> Array:
	## All or Nothing: every crown that comes up rings the rail once. In planning it is banked
	## the way a Crystal die's Resonance is, so the rail starts from it. Returns the die ids.
	if not all_or_nothing(unit):
		return []
	var crowned: Array = []
	for roll in rolls:
		if bool(roll.get("carried", false)) or bool(roll.get("kept", false)):
			continue
		if is_crown(roll):
			crowned.append(str(roll.get("die_id", "")))
	if not crowned.is_empty():
		if planning:
			unit.initial_resonance = DeepRules.sat_add(int(unit.get("initial_resonance", 0)), crowned.size())
		unit.resonance = DeepRules.sat_add(int(unit.get("resonance", 0)), crowned.size())
	return crowned

static func _crowns_changed(unit: Dictionary, before: Dictionary) -> Array:
	## The crowns a gem's turn on the hand brought up: a phantom thrown or copied onto a top
	## face, a die turned or raised onto one. All or Nothing counts each of them too.
	if not all_or_nothing(unit):
		return []
	var fresh: Array = []
	for roll in unit.hand:
		var id: String = str(roll.get("die_id", ""))
		if is_crown(roll) and not before.has(id):
			fresh.append(id)
	if not fresh.is_empty():
		unit.resonance = DeepRules.sat_add(int(unit.get("resonance", 0)), fresh.size())
	return fresh

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
		unit.initial_resonance = DeepRules.sat_add(int(unit.get("initial_resonance", 0)), int(dues.resonance))
		unit.resonance = DeepRules.sat_add(int(unit.get("resonance", 0)), int(dues.resonance))
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
	for entry in unit.get("broken_dice", []):
		var die: Dictionary = _regrown_die(unit, entry)
		unit.dice.insert(clampi(int(entry.get("at", 0)), 0, unit.get("dice", []).size()), die)
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

static func _regrown_die(unit: Dictionary, entry: Dictionary) -> Dictionary:
	## What a broken die grows back as: the hero's starting die for that slot, plain.
	var refs: Array = DeepContent.character(str(unit.get("character", ""))).get("dice", [])
	var slot: int = int(entry.get("at", 0))
	return DeepForge.die_from(refs[slot] if slot >= 0 and slot < refs.size() else "D6", str(entry.get("id", "")))

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
				die.faces[index].value = int(die.faces[index].get("value", 0)) + 1
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
				## An amount of 99 or more means "up to the top": as high as the hand goes, or the die can.
				lowest.value = mini(int(lowest.value) + amount, maxi(high, int(lowest.get("top", high)))) if amount >= 99 else int(lowest.value) + amount
				changed.append(str(lowest.die_id))
		"raise_high":
			var highest: Dictionary = _extreme(real, false)
			if not highest.is_empty():
				highest.value = int(highest.value) + amount
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
				roll.value = maxi(1, int(roll.get("top", 6)) + 1 - int(roll.value))
				changed.append(str(roll.die_id))
		"phantom_high", "phantom_low":
			var picked: Dictionary = _extreme(real, kind == "phantom_low")
			if not picked.is_empty():
				for index in range(amount):
					var ghost: Dictionary = DeepDice.phantom(picked, "%s_ph%d_%d" % [str(picked.die_id), hand.size(), index])
					## A Flawless Sediment's phantom shows a number of its own: a 1.
					if effect.has("shows"):
						ghost.value = int(effect.shows)
						ghost.kind = "plain"
						ghost.erase("shown")
						ghost.erase("counted")
						ghost.erase("base")
					hand.append(ghost)
					changed.append(str(ghost.die_id))
	## No copy of the hand rides along: the screens read the unit's own, and a copy per proc
	## was the whole hand again for every phantom.
	return {"kind": kind, "amount": amount, "dice": changed}

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
		elif str(effect.get("kind", "")) == "invert_previous":
			count += blows(effect.get("hits", []))
	return count

static func hit_pace(effects: Array) -> float:
	## How much of one blow's screen time each blow in this batch gets: all of it up to a
	## handful, then less and less, so the run of them always fits HIT_SPAN.
	var span: float = HIT_STEP * float(blows(effects))
	return 1.0 if span <= HIT_SPAN else HIT_SPAN / span

static func hits_span(effects: Array) -> float:
	## How long these effects take to play, once they have closed up.
	return minf(HIT_STEP * float(blows(effects)), HIT_SPAN)

static func tally_of(ev: Dictionary, scale: int = 100, strength: int = 0) -> Dictionary:
	## What a gem that fires is seen to add up, for the screen to count out before anything
	## leaves the socket: the dice it read and what each showed; how their sum became the
	## skill's own number; every multiplier laid on that number, each from where it comes (a
	## die of the gem's own color, the stone's weight, a Flawless clarity, an inclusion, a
	## Double Down, an Echo's share); whatever is added after; and what it all came to.
	## Only a gem with a figure to land (its first effect that swells with weight) has the
	## number half; one that rerolls a die or calls a phantom shows only the dice that woke
	## it. Nothing reads this back: it says what the rules already did, in an order a player
	## can follow. `strength` is the thrower's Strength as the gem fired, which every blow
	## carries on top.
	var colors: Array = ev.get("colors", [])
	var dice: Array = []
	var sum: int = 0
	for read in ev.get("read", []):
		var material: String = str(read.get("material", ""))
		dice.append({"id": str(read.get("id", "")), "value": int(read.get("value", 0)),
			"material": material if DeepDice.material_matches(material, colors) else ""})
		sum += int(read.get("value", 0))
	var out: Dictionary = {"dice": dice}
	var headline: Dictionary = {}
	for effect in ev.get("effects", []):
		if not effect is Dictionary or not str(effect.get("kind", "")) in TALLY_KINDS or not bool(effect.get("scaled", false)) or int(effect.get("raw", 0)) <= 0:
			continue
		## A figure the rules reshape as it lands (a share of something, what an earlier blow
		## did, the health its thrower is missing) is not one the count could honestly finish.
		if not (effect.has("share") or effect.has("from_result") or effect.has("of_status") \
				or bool(effect.get("missing_hp_bonus", false)) or bool(effect.get("split_party", false))):
			headline = effect
		break
	if headline.is_empty():
		return out
	var base: int = int(headline.raw)
	## How the dice became the skill's number, said only as far as it is known: the dice
	## added up as they are (a Strike's, a Cleave's pair); the face of a set taken so many
	## times over, as its card says (a Crush is five times the matched value); or a number
	## of the skill's own the dice only woke (a Block of 3 on any pair, a Guard's pair
	## value), and then they carry no figure and the number is simply shown.
	var link: Dictionary = {}
	var face: int = int(ev.get("trigger", {}).get("value", 0))
	var times: int = _times_value(_headline_amount(ev, headline))
	if not dice.is_empty() and base == sum:
		link = {}
	elif face > 0 and times > 1 and face * times == base:
		link = {"op": "x", "by": times, "from": face}
	else:
		link = {"op": "=", "from": base}
	var mults: Array = []
	for die in dice:
		if not str(die.material).is_empty():
			mults.append({"what": "material", "x": DeepDice.STRENGTH_STEP, "die": str(die.id), "material": str(die.material)})
	var parts: Dictionary = ev.get("parts", {})
	for part in ["carat", "clarity", "inclusions", "amplify"]:
		var x: float = float(parts.get(part, 1.0))
		if absf(x - 1.0) > 0.001:
			var entry: Dictionary = {"what": part, "x": x}
			if part == "carat":
				entry.weight = float(parts.get("weight", ev.get("carat", 1)))
			mults.append(entry)
	var magnitude: float = float(ev.get("magnitude", 1.0))
	var amount: int = int(headline.get("amount", 0))
	var expected: int = DeepRules.sat_floor(float(base) * magnitude)
	if scale != 100:
		mults.append({"what": "echo", "x": float(scale) / 100.0})
		amount = DeepRules.sat_floor(float(amount) * float(scale) / 100.0)
		expected = DeepRules.sat_floor(float(expected) * float(scale) / 100.0)
	var adds: Array = []
	if amount != expected:
		## Something the stone adds once its weight is counted (an inclusion's damage a die).
		adds.append({"what": "bonus", "by": amount - expected})
	if str(headline.kind) == "damage" and amount > 0 and strength > 0:
		adds.append({"what": "strength", "by": strength})
		amount += strength
	out.merge({"kind": str(headline.kind), "target": str(headline.get("target", "")), "base": base, "sum": sum, "link": link,
		"mults": mults, "adds": adds, "amount": amount, "repeat": maxi(1, int(headline.get("repeat", 1)))})
	return out

static func tally_die_gap(dice: int) -> float:
	## How far apart the dice of one count hop.
	return minf(TALLY_DIE, TALLY_DICE / float(maxi(1, dice)))

static func _headline_amount(ev: Dictionary, headline: Dictionary) -> Variant:
	## The amount a gem's headline effect is written with on its card: the first effect of
	## that kind in the skill (the Flawless line can only add to these, never reorder them).
	var skill: Dictionary = DeepContent.skill(str(ev.get("skill", "")))
	for def in skill.get("effects", []):
		if def is Dictionary and str(def.get("kind", "damage")) == str(headline.get("kind", "")):
			return def.get("amount", null)
	return null

static func _times_value(expr: Variant) -> int:
	## k, when an amount is written as the trigger's value times k (or k times it); else 0.
	if not expr is Dictionary or str(expr.get("op", "")) != "*" or expr.get("args", []).size() != 2:
		return 0
	var args: Array = expr.args
	for index in range(2):
		var other: Variant = args[1 - index]
		if args[index] is Dictionary and str(args[index].get("term", "")) == "value" and (other is int or other is float):
			return int(other)
	return 0

static func tally_weight(entry: Dictionary) -> float:
	## How many beats a step between the dice and the fuse is given: the carat step more.
	return TALLY_CARAT if str(entry.get("what", "")) == "carat" else 1.0

static func tally_weights(tally: Dictionary) -> float:
	## Every step's beats added up: the skill's own, each multiplier, each addition.
	if not tally.has("amount"):
		return 0.0
	var total: float = 1.0 if str(tally.get("link", {}).get("op", "")) == "x" else 0.0
	for entry in tally.get("mults", []):
		total += tally_weight(entry)
	return total + float(tally.get("adds", []).size())

static func tally_step_gap(weights: float) -> float:
	## One beat of the steps: TALLY_STEP, closing up once there are enough to pass TALLY_STEPS.
	return minf(TALLY_STEP, TALLY_STEPS / maxf(1.0, weights))

static func tally_span(tally: Dictionary) -> float:
	## How long the count takes on screen, from the gem lighting to the fused number leaving,
	## at the pace the host chose: all of it at Full, half at Quick, and at Off only the fused
	## figure, shown for a moment before it flies.
	if tally.is_empty():
		return 0.0
	var pace: float = clampf(float(tally.get("pace", 1.0)), 0.0, 1.0)
	if pace <= 0.0:
		return TALLY_GLANCE if tally.has("amount") else 0.0
	var dice: int = tally.get("dice", []).size()
	var span: float = 0.0
	if dice > 0:
		span += tally_die_gap(dice) * float(dice - 1) + TALLY_FLIGHT
	if tally.has("amount"):
		var weights: float = tally_weights(tally)
		span += tally_step_gap(weights) * weights + TALLY_FUSE
	return span * pace

static func count_pace(state: Dictionary) -> float:
	## How fully the counts are played: 1 is all of it, 0.5 twice as fast, 0 only the figure.
	## The host's choice, written on the fight, so every screen and the host's clock agree.
	return clampf(float(state.get("count_pace", 1.0)), 0.0, 1.0)

static func creature_tally(state: Dictionary, foe: Dictionary, move: Dictionary, shown: Array) -> Dictionary:
	## What a creature's blow is seen to add up to before it lands, counted the way a gem's is:
	## the dice it rolled for it, the mine's weight on it (and an Empowered creature's), then
	## what every blow of its carries on top: the depth's bonus, a Howl's rallying, Strength,
	## the turn's enrage, and a Curse taking its share back off. Only a blow whose pieces were
	## written down when it was rolled (see `DeepCreatures.resolved_move`) is counted.
	var effect: Dictionary = {}
	for candidate in shown:
		if candidate is Dictionary and str(candidate.get("kind", "")) == "damage" and candidate.has("scaled"):
			effect = candidate
			break
	if effect.is_empty():
		return {}
	var dice: Array = []
	var sum: int = 0
	for id in move.get("dice", []):
		for roll in foe.get("hand", []):
			if str(roll.get("die_id", "")) == str(id):
				dice.append({"id": str(id), "value": int(roll.get("value", 0)), "material": ""})
				sum += int(roll.get("value", 0))
				break
	var base: int = int(effect.get("raw", effect.get("scaled", 0)))
	var scaled: int = int(effect.scaled)
	var link: Dictionary = {}
	if dice.is_empty() or base != sum:
		link = {"op": "=", "from": base}
	var mults: Array = []
	var depth_pct: int = int(effect.get("depth_pct", 100))
	if effect.has("depth_pct") and depth_pct != 100:
		mults.append({"what": "depth", "x": float(depth_pct) / 100.0})
	if int(effect.get("empowered", 0)) > 0:
		mults.append({"what": "empowered", "x": float(100 + int(effect.empowered)) / 100.0})
	var adds: Array = []
	var running: int = scaled
	for entry in effect.get("adds", []):
		if int(entry[1]) != 0:
			adds.append({"what": str(entry[0]), "by": int(entry[1])})
			running += int(entry[1])
	if int(state.get("turn", 0)) >= enrage_turn(state):
		var enraged: int = enrage_step(state) * (int(state.turn) - enrage_turn(state) + 1)
		adds.append({"what": "enrage", "by": enraged})
		running += enraged
	if int(effect.amount) != running:
		adds.append({"what": "curse", "by": int(effect.amount) - running})
	return {"dice": dice, "kind": "damage", "target": str(effect.get("target", "")), "base": base, "sum": sum, "link": link,
		"mults": mults, "adds": adds, "amount": int(effect.amount), "repeat": maxi(1, int(effect.get("repeat", 1))), "pace": count_pace(state)}

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
	var certainty: Dictionary = unit.get("force_after", {})
	if not certainty.is_empty() and int(certainty.get("from", -1)) >= at:
		certainty.from = int(certainty.from) + 1
	if int(unit.get("firing_stone", {}).get("socket", -1)) >= at:
		unit.firing_stone.socket = int(unit.firing_stone.socket) + 1
	## The rail it walked in with moves along too, with nothing in the new place: a broken
	## gem grows back as its own stone, and the newcomer, which is the fight's, does not.
	var was: Array = unit.get("initial_rail", [])
	if at <= was.size():
		was.insert(at, null)
	for entry in unit.get("broken_gems", []):
		if int(entry.get("at", -1)) >= at:
			entry.at = int(entry.at) + 1
	for foe in state.get("enemies", []):
		for held in foe.get("held_gems", []):
			if str(held.get("unit", "")) == str(unit.id) and int(held.get("socket", -1)) >= at:
				held.socket = int(held.socket) + 1
		var hardest: Dictionary = foe.get("hardest_gem", {})
		if str(hardest.get("unit", "")) == str(unit.id) and int(hardest.get("socket", -1)) >= at:
			hardest.socket = int(hardest.socket) + 1

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
				if not unit.rail[at] is Dictionary or (scope == "adjacent" and absi(at - socket) != 1) or (scope == "others" and at == socket) or (scope == "self" and at != socket):
					continue
				var id: String = str(unit.rail[at].id)
				if not unit.gem_buffs.has(id):
					unit.gem_buffs[id] = {}
				unit.gem_buffs[id][rank] = DeepRules.sat_add(int(unit.gem_buffs[id].get(rank, 0)), amount)
				changed.append(at)
			out.sockets = changed
			out.rank = rank
			_credit_buff(unit, rank, socket)
		"upgrade_faces":
			## Only the first die it matches, in the order they sit in the hand, that still meets
			## the gem's line: a proc after the first finds the face it raised past the line and
			## raises the next one instead, or nothing when none is left (see `_under_line`).
			var changed: Array = []
			var raised: Array = effect.get("raised", [])
			for roll in unit.hand:
				if not changed.is_empty():
					break
				if bool(roll.get("phantom", false)) or not effect.get("dice", []).has(str(roll.die_id)):
					continue
				if not _under_line(roll, effect.get("line", {}), raised):
					continue
				for die in unit.dice:
					if str(die.id) != str(roll.die_id):
						continue
					for face_index in range(die.faces.size()):
						if bool(effect.get("all_faces", false)) or face_index == int(roll.get("face", -1)):
							die.faces[face_index].value = int(die.faces[face_index].value) + amount
					roll.value = int(roll.value) + amount
					if roll.has("base"):
						roll.base = int(roll.base) + amount
					if die.has("top"):
						var physical_top: int = 0
						for face in die.faces:
							if str(face.get("kind", "plain")) != "blank":
								physical_top = maxi(physical_top, int(face.value))
						die.top = maxi(int(die.top), physical_top)
					roll.top = DeepDice.top(die)
					changed.append(str(die.id))
			raised.append_array(changed)
			effect.raised = raised
			out.dice = changed
		"stake":
			var cost: int = int(effect.get("cost", 0))
			if DeepRules.pyrite(unit) >= cost:
				unit.pyrite_delta = int(unit.get("pyrite_delta", 0)) - cost
				unit.amplify = float(unit.amplify) * (1.0 + float(amount) / 100.0)
				out.spent = cost
				out.pyrite_after = DeepRules.pyrite(unit)
		"appraise":
			## How many stones it reads is exact; what they are thrown for swells with weight.
			var appraised: Array = []
			var worth: int = 0
			for stone in unit.get("haul", []):
				if appraised.size() >= int(effect.get("stones", 1)):
					break
				## A Geode stays sealed until the workshop cracks it.
				if bool(stone.get("appraised", false)) or DeepStone.is_geode(stone):
					continue
				stone.appraised = true
				stone.inclusions_revealed = true
				appraised.append(str(stone.id))
				worth += DeepStone.value(stone)
			out.appraised = appraised
			out.value = worth
			out.hits = _apply(state, unit, {"kind": "damage", "target": "enemy", "amount": worth * amount / 100}, rng) if worth > 0 else []

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
				## A Rainbow Seam asks for no color at all: everything that fired plays again.
				if want != "ANY" and not DeepStone.colors(stone_at(unit, at), str(unit.sockets[at])).has(want):
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
				buff[rank] = DeepRules.sat_add(int(buff.get(rank, 0)), amount)
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
		"fire_neighbours":
			## A Gemini: the gems either side of it fire, once for every pair in the hand, the
			## one before it first. Never an opal, which answers only to its Resonance: not even a
			## Doublet wearing a gem, which beside a Gemini would wear it and wake it back for ever.
			var twins: Array = []
			var woken: Array = []
			for at in [socket - 1, socket + 1]:
				if at == socket or not repeatable(unit, at) or DeepStone.is_opal(unit.rail[at]):
					continue
				twins.append(at)
				for _time in range(maxi(0, amount)):
					woken.append({"kind": "gem", "unit": unit.id, "socket": at, "retrigger": true, "force": true})
			out.sockets = twins
			if dry or woken.is_empty():
				out.nothing = true
			else:
				state.queue = woken + state.queue
		"force_after":
			## A Certainty: every gem after it this turn fires whatever the dice show, and that
			## many times over. Set on a forecast too: the forecast plays on a copy of the fight,
			## and the gems after it should read as firing there as they will in earnest.
			var standing: Dictionary = unit.get("force_after", {})
			var from: int = socket if standing.is_empty() else mini(socket, int(standing.get("from", socket)))
			unit.force_after = {"from": from, "times": maxi(maxi(1, amount), int(standing.get("times", 0)))}
			out.total = int(unit.force_after.times)
		"absorbed":
			## A Black Opal: every skill it has taken in this run fires from its socket, each as
			## a stone wearing that skill at the Black Opal's own four C's, in the order it took
			## them. Each one reads the hand the way the gem it came from would have.
			var taken: Array = unit.rail[socket].get("absorbed", []) if socket >= 0 and socket < unit.rail.size() and unit.rail[socket] is Dictionary else []
			out.skills = taken.duplicate()
			if dry or taken.is_empty():
				out.nothing = true
			else:
				var fired: Array = []
				for key in taken:
					fired.append({"kind": "gem", "unit": unit.id, "socket": socket, "retrigger": true, "as_skill": str(key)})
				state.queue = fired + state.queue
		"phantom_roll":
			## A Tumble or a Contra Luz: a fresh phantom die of its own size, thrown into the hand.
			## A Refract (`of: largest`) throws a copy of the owner's largest die, its faces and
			## all: the most faces, and between two as large the one showing more.
			var source: Dictionary = _largest_die(unit) if str(effect.get("of", "")) == "largest" else {}
			if dry or (str(effect.get("of", "")) == "largest" and source.is_empty()):
				out.nothing = true
			else:
				var thrown_ids: Array = []
				var values: Array = []
				for _each in range(maxi(1, amount)):
					var made: Dictionary
					if source.is_empty():
						made = DeepDice.make(str(effect.get("shape", "D6")), "%s_roll%d_%d" % [str(unit.id), int(state.get("turn", 0)), unit.hand.size()])
					else:
						made = source.duplicate(true)
						made.id = "%s_ph%d_%d" % [str(source.id), int(state.get("turn", 0)), unit.hand.size()]
						made.erase("bonus")
					var ghost: Dictionary = DeepDice.roll_one(made, rng)
					ghost.phantom = true
					ghost.source_id = str(source.get("id", ""))
					ghost.erase("bonus")
					unit.hand.append(ghost)
					thrown_ids.append(str(ghost.die_id))
					values.append(int(ghost.value))
				out.dice = thrown_ids
				out.value = int(values[0])
				out.values = values
		"bonus_die":
			## A Hot Streak: a die of its own joins the next throw, for that turn only.
			var owed: Array = unit.get("bonus_dice_next", [])
			for _each in range(maxi(1, amount)):
				owed.append({"shape": str(effect.get("shape", "D6")), "pattern": str(effect.get("pattern", ""))})
			unit.bonus_dice_next = owed
			out.count = unit.get("bonus_dice_next", []).size()
		"double_resonance_next":
			## On Fire: next turn the Birthstone reads twice the whole total.
			unit.double_resonance_next = true
		"lose_pyrite":
			## A Bust: the bank pays, as much of it as there is.
			var lost: int = mini(maxi(0, amount), DeepRules.pyrite(unit))
			if lost > 0:
				unit.pyrite_delta = int(unit.get("pyrite_delta", 0)) - lost
			out.lost = lost
		"reflect_blows":
			## A Mirror: the next blows a creature lands on its owner, until their next turn,
			## are split, `pct` percent sent back at whoever threw them. Every firing adds blows.
			unit.statuses.reflect = mini(99, int(unit.statuses.get("reflect", 0)) + maxi(1, amount))
			unit.statuses.reflect_pct = clampi(maxi(int(unit.statuses.get("reflect_pct", 0)), int(effect.get("pct", 50))), 0, 100)
			out.blows = int(unit.statuses.get("reflect", 0))
			out.pct = int(unit.statuses.get("reflect_pct", effect.get("pct", 50)))
		"rethrow":
			## A Rattle: the lowest real die it has not yet thrown this firing goes again. It is
			## a throw, so it pays what a throw pays, but never a reroll: Fury and Anchor are blind to it.
			var thrown: Array = effect.get("thrown", [])
			var lowest: int = -1
			for index in range(unit.hand.size()):
				var roll: Dictionary = unit.hand[index]
				if bool(roll.get("phantom", false)) or str(roll.get("kind", "plain")) in ["wild", "blank"] or bool(roll.get("locked", false)) or thrown.has(str(roll.get("die_id", ""))):
					continue
				if lowest < 0 or int(roll.value) < int(unit.hand[lowest].value):
					lowest = index
			var die: Dictionary = _die_of(unit, str(unit.hand[lowest].get("die_id", ""))) if lowest >= 0 else {}
			if dry or die.is_empty():
				out.nothing = true
			else:
				var was: Dictionary = unit.hand[lowest]
				var best: Dictionary = {}
				var dues: Array = []
				for _throw in range(maxi(1, int(effect.get("best_of", 1)))):
					var again: Dictionary = DeepDice.roll_one(die, rng, int(was.get("rerolls", 0)))
					again.held = bool(was.get("held", false))
					again.rethrown = true
					unit.hand[lowest] = again
					dues.append(_pay_dues(state, unit, [str(die.id)]))
					if lowest >= unit.hand.size() or str(unit.hand[lowest].get("die_id", "")) != str(die.id):
						## The throw broke it (Glass): there is nothing left to keep.
						best = {}
						break
					if best.is_empty() or int(again.value) > int(best.value):
						best = again
				if not best.is_empty():
					unit.hand[lowest] = best
				thrown.append(str(die.id))
				effect.thrown = thrown
				out.dice = [str(die.id)]
				out.was = int(was.get("value", 0))
				out.value = int(best.get("value", 0))
				out.dues = dues
		"gild":
			## A Gilding: the face the highest die shows turns Golden for the rest of the run,
			## whatever was etched on it. A face already Golden is passed over for the next die.
			var gilded: Array = effect.get("gilded", [])
			var sides: Array = [false, true] if bool(effect.get("both_ends", false)) else [false]
			var changed: Array = []
			for lowest in sides:
				var pick: Dictionary = {}
				for roll in unit.hand:
					if bool(roll.get("phantom", false)) or str(roll.get("kind", "plain")) == "blank" or gilded.has(str(roll.get("die_id", ""))):
						continue
					var owner: Dictionary = _die_of(unit, str(roll.get("die_id", "")))
					var at: int = int(roll.get("face", -1))
					if owner.is_empty() or at < 0 or at >= owner.get("faces", []).size() or str(owner.faces[at].get("kind", "plain")) == "golden":
						continue
					if pick.is_empty() or (int(roll.value) < int(pick.value) if lowest else int(roll.value) > int(pick.value)):
						pick = roll
				if pick.is_empty() or dry:
					continue
				var owner: Dictionary = _die_of(unit, str(pick.die_id))
				DeepDice.etch(owner, int(pick.face), "golden")
				gilded.append(str(pick.die_id))
				changed.append({"die": str(pick.die_id), "face": int(pick.face), "value": int(pick.value)})
			effect.gilded = gilded
			out.faces = changed
			if changed.is_empty():
				out.nothing = true
		"soak":
			## A Hydrophane: the smallest die drinks a drop, and at three it is a size bigger for
			## the rest of the run (smaller, on a Flawless stone, down to a d2). The drops are
			## kept on the die, so they carry from fight to fight.
			var smallest: Dictionary = {}
			for die in unit.dice:
				if smallest.is_empty() or DeepDice.top(die) < DeepDice.top(smallest):
					smallest = die
			if dry or smallest.is_empty():
				out.nothing = true
			else:
				var steps: int = -1 if bool(effect.get("shrink", false)) else 1
				var drops: int = int(smallest.get("drops", 0)) + 1
				out.die = str(smallest.id)
				if drops >= DROPS_PER_SIZE:
					var refusal: String = DeepOddities.resize(smallest, steps)
					if refusal.is_empty():
						drops = 0
						out.resized = str(smallest.get("shape", ""))
					else:
						drops = DROPS_PER_SIZE
				smallest.drops = drops
				out.drops = drops
		"each_after":
			## A Chainmail or a Contagion: for the rest of the turn every gem after it gives this.
			if not unit.has("after_fire"):
				unit.after_fire = []
			unit.after_fire.append({"kind": str(effect.get("gift", "block")), "amount": amount, "target": str(effect.get("target", "self"))})
			out.gift = str(effect.get("gift", "block"))
		"on_block":
			## A Rebound: for the rest of the turn, every time its owner gains block, a hit.
			if not unit.has("on_block"):
				unit.on_block = []
			unit.on_block.append({"amount": amount, "target": str(effect.get("target", "enemy"))})
		"fire_birthstone":
			## A Birthright: the Birthstone fires now as well, at a share of the Resonance so far.
			## It goes as a replay, so an Encore tier on it stays dark and the rail is not sent round.
			if dry or unit.get("birthstone", {}).is_empty():
				out.nothing = true
			else:
				state.queue.push_front({"kind": "birthstone", "unit": unit.id, "replay": true, "share": amount})
		"spectrum":
			## A Spectrum: one gift for every color that has fired this turn (every gem, Flawless).
			var tally: Dictionary = {}
			for colors in unit.get("fired_colors", []):
				for color in colors:
					if not SPECTRUM_GIFTS.has(str(color)):
						continue
					tally[str(color)] = int(tally.get(str(color), 0)) + 1 if bool(effect.get("every_gem", false)) else 1
			var given: Array = []
			for color in SPECTRUM_GIFTS:
				if not tally.has(color):
					continue
				var gift: Array = SPECTRUM_GIFTS[color]
				var worth: int = DeepRules.sat_scale(int(gift[1]), int(tally[color]), amount, 100)
				if worth <= 0:
					continue
				if str(gift[0]) == "resonance":
					unit.resonance = DeepRules.sat_add(int(unit.resonance), worth)
					given.append({"kind": "resonance", "amount": worth, "target": str(unit.id), "color": color})
				else:
					for hit in _apply(state, unit, {"kind": str(gift[0]), "amount": worth, "target": str(gift[2]), "repeat": 1}, rng):
						hit.color = color
						given.append(hit)
				if done(state):
					break
			out.colors = tally
			out.hits = given
			if given.is_empty():
				out.nothing = true
		"invert_previous":
			## An Invert: a share of what the gem before it did on its last go, each part turned around.
			var did: Dictionary = _left_results(unit, socket)
			var given: Array = []
			for turn in INVERTED:
				var read: int = 0
				for key in turn[1]:
					read = DeepRules.sat_add(read, int(did.get(key, 0)))
				var worth: int = DeepRules.sat_muldiv(read, maxi(0, amount), 100)
				if worth <= 0:
					continue
				given.append_array(_apply(state, unit, {"kind": str(turn[0]), "amount": worth, "target": str(turn[2]), "repeat": 1}, rng))
				if done(state):
					break
			out.read = did
			out.hits = given
			if given.is_empty():
				out.nothing = true
		"stone_chance":
			## A Placer: every creature fallen this turn may leave a raw stone. Past a sure
			## stone, what is left is the chance of a second.
			var kills: int = int(state.get("turn_kills", 0))
			var found: int = 0
			if not dry:
				for _kill in range(kills):
					found += maxi(0, amount) / 100
					if DeepRng.chance(rng, float(maxi(0, amount) % 100)):
						found += 1
				var field: String = "placer_elite_drops" if bool(effect.get("elite", false)) else "placer_drops"
				unit[field] = int(unit.get(field, 0)) + found
			out.kills = kills
			out.stones = found
		"double_resonance":
			## A Flawless Pinfire: every gem after it this turn rings twice as loud.
			unit.resonance_mult = maxi(2, int(unit.get("resonance_mult", 1)))
		"keep_phantoms":
			## A Contra Luz: this turn's phantoms stay in the hand into the next.
			unit.keep_phantoms = true
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
			unit.resonance = DeepRules.sat_add(int(unit.resonance), amount)
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

static func _left_results(unit: Dictionary, socket: int) -> Dictionary:
	## What the gem in the socket before this one did on its last go this turn, as an Invert
	## reads it: only what came to anything. Empty if that socket is empty or never fired.
	if socket <= 0 or socket - 1 >= unit.rail.size() or not unit.rail[socket - 1] is Dictionary:
		return {}
	var did: Dictionary = unit.get("gem_results", {}).get(str(unit.rail[socket - 1].get("id", "")), {})
	var out: Dictionary = {}
	for key in did:
		if int(did[key]) > 0:
			out[key] = int(did[key])
	return out

static func _note_result(source: Dictionary, target: Dictionary, key: String, amount: int) -> void:
	## What the gem firing now has really done, for an Invert after it: damage that landed
	## (Block knocked off included) and the debuffs that stuck on the other side; the Block,
	## healing and buffs it gave its own side.
	if amount <= 0 or not source.get("firing_results", null) is Dictionary:
		return
	if (key in INVERTED_HOSTILE) == (str(source.get("side", "")) == str(target.get("side", ""))):
		return
	source.firing_results[key] = DeepRules.sat_add(int(source.firing_results.get(key, 0)), amount)

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
				chosen = default_target(foes)
			return [chosen] if not chosen.is_empty() else []
		"enemies":
			return foes
		"enemy_adjacent":
			var chosen: Dictionary = enemy(state, aim(source))
			if (chosen.is_empty() or bool(chosen.get("burrowed", false))) and not foes.is_empty():
				chosen = default_target(foes)
			return _adjacent_enemies(state, chosen).slice(0, 1)

		"enemy_behind":
			var chosen: Dictionary = enemy(state, aim(source))
			if chosen.is_empty() or int(chosen.hp) <= 0 or bool(chosen.get("burrowed", false)):
				chosen = default_target(foes)
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
	## A Kaleidoscope drinking this gem's color takes what the gem would give its owner.
	var drinker: Dictionary = _color_drinker(state, source) if kind in ABSORBED_GIFTS and target_kind in ["self", "allies", "ally_low"] else {}
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
				var survivors: Array = targetable(state.enemies)
				if survivors.is_empty():
					break
				hit = _apply_one(state, source, survivors[0], kind, int(effect.amount), effect, rng, reactions)
				results.append(hit)
		## A party-wide hit reaches all victims before retaliation can settle the fight.
		_check_outcome(state)
		if done(state):
			return results
	return results

## What a gem gives its owner that a creature drinking its color takes instead.
const ABSORBED_GIFTS: Array = ["block", "heal", "retain", "regeneration", "ward", "spikes", "max_hp"]

static func _color_drinker(state: Dictionary, source: Dictionary) -> Dictionary:
	## The creature drinking a color this gem is thrown in, if there is one.
	if str(source.get("side", "")) != "player":
		return {}
	var colors: Array = source.get("firing_colors", [])
	if colors.is_empty():
		return {}
	for foe in living(state.enemies):
		for color in foe.get("absorb", []):
			if colors.has(color):
				return foe
	return {}

static func _ward_blocks(target: Dictionary) -> bool:
	var ward: int = int(target.get("statuses", {}).get("ward", 0))
	if ward <= 0:
		return false
	target.statuses.ward = ward - 1
	return true

static func _reset_defenses(unit: Dictionary) -> void:
	## Spikes are no longer cleared here: they last the fight, for players and creatures alike.
	unit.block = mini(int(unit.get("block", 0)), maxi(0, int(unit.statuses.get("retain", 0))))
	unit.statuses.erase("retain")

static func _apply_one(state: Dictionary, source: Dictionary, target: Dictionary, kind: String, amount: int, effect: Dictionary, rng: RandomNumberGenerator, reactions: Dictionary = {}) -> Dictionary:
	if effect.has("from_result"):
		amount = DeepRules.sat_muldiv(int(reactions.get("result_" + str(effect.from_result), 0)), amount, 100)
	## A share of what its owner carries as it lands: a Caltrop's Spikes, a Hemlock's Poison.
	if effect.has("of_status"):
		amount = DeepRules.sat_muldiv(int(source.get("statuses", {}).get(str(effect.of_status), 0)), amount, 100)
	var out: Dictionary = {"kind": kind, "target": str(target.id), "amount": amount}
	if kind == "poison" and str(target.get("gimmick", "")) == "poison_immune":
		out.immune = true
		return out
	if kind == "stun" and int(target.statuses.get("combo_breaker", 0)) > 0:
		out.resisted = true
		return out
	if kind in ["poison", "gather_poison", "grow_poison"] and str(target.get("side", "")) == "enemy" and DeepCreatures.has_trait(target, "poison_immune"):
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
				amount = DeepRules.sat_muldiv(amount, int(target.statuses.get("curse", 0)), 100)
			elif kind == "detonate":
				consumed = int(target.statuses.get("poison", 0))
				target.statuses.poison = 0
				amount = DeepRules.sat_mul(amount, consumed)
				out.poison_consumed = consumed
			elif kind == "wager":
				spent = int(effect.get("cost", 0))
				if DeepRules.pyrite(source) < spent:
					out.unaffordable = true
					return out
				source.pyrite_delta = int(source.get("pyrite_delta", 0)) - spent
				out.spent = spent
			if bool(effect.get("missing_hp_bonus", false)):
				amount = DeepRules.sat_muldiv(amount, 2 * int(source.max_hp) - int(source.hp), maxi(1, int(source.max_hp)))
			## A player's Strength (Temper) puts a point more on every blow, as a creature's does.
			if kind == "damage" and amount > 0 and str(source.get("side", "")) == "player":
				amount = DeepRules.sat_add(amount, maxi(0, int(source.get("statuses", {}).get("strength", 0))))
			out.kind = "damage"
			out.amount = amount
			out.merge(_damage(state, source, target, amount, rng, false, reactions, false, bool(effect.get("piercing", false))), true)
			reactions.result_damage = DeepRules.sat_add(int(reactions.get("result_damage", 0)), int(out.hp_loss))
			if spent > 0 and bool(out.get("killed", false)):
				out.refund = spent * int(effect.get("refund_mult", 2))
				source.pyrite_delta = int(source.pyrite_delta) + int(out.refund)
			if kind == "wager":
				out.pyrite_after = DeepRules.pyrite(source)
			var splash: int = int(effect.get("splash", 0))
			if splash > 0:
				var splashed: Array = []
				for neighbour in adjacent:
					var hit: Dictionary = _damage(state, source, neighbour, DeepRules.sat_muldiv(amount, splash, 100), rng, false, reactions)
					hit.target = str(neighbour.id)
					splashed.append(hit)
				out.splash = splashed
			if consumed > 0 and int(effect.get("poison_splash", 0)) > 0:
				var spread: Array = []
				for neighbour in adjacent:
					spread.append(_apply_one(state, source, neighbour, "poison", DeepRules.sat_muldiv(consumed, int(effect.poison_splash), 100), {}, rng, reactions))
				out.poison_spread = spread
		"block":
			## Scorched: block gained is halved, rounded up.
			if int(target.statuses.get("scorched", 0)) > 0 and amount > 0:
				amount = int(ceil(float(amount) / 2.0))
				out.scorched = true
				out.amount = amount
			target.block = DeepRules.sat_add(int(target.block), amount)
			out.block_after = target.block
			tally_add(target, "block", amount)
			_note_result(source, target, "block", amount)
			if str(source.get("side", "")) == "player":
				gem_tally(source, "block", amount)
			reactions.result_block = DeepRules.sat_add(int(reactions.get("result_block", 0)), amount)
			## A Rebound: every time its owner gains block this turn, the target takes a hit.
			if amount > 0 and str(target.get("side", "")) == "player" and not target.get("on_block", []).is_empty() and int(target.get("hp", 0)) > 0:
				var rebounds: Array = []
				for answer in target.on_block:
					rebounds.append_array(_apply(state, target, {"kind": "damage", "amount": int(answer.amount), "target": str(answer.target), "repeat": 1}, rng))
					if done(state):
						break
				out.rebound = rebounds
		"heal":
			out.healed = _heal(target, amount)
			out.hp_after = target.hp
			_note_result(source, target, "heal", int(out.healed))
			if str(source.get("side", "")) == "player":
				source.healed = DeepRules.sat_add(int(source.get("healed", 0)), int(out.healed))
			## What would heal past full: block for a Wellspring, a blow for a Flawless Thirst.
			var spill: int = _heal_received(target, amount) - int(out.healed)
			if str(source.get("side", "")) == "player":
				tally_add(source, "healed", int(out.healed))
				tally_add(source, "overheal", maxi(0, spill))
				gem_tally(source, "healed", int(out.healed))
			if effect.has("overflow") and spill > 0 and int(target.get("hp", 0)) > 0:
				if str(effect.overflow) == "block":
					out.overflow = _apply_one(state, source, target, "block", spill, {}, rng, reactions)
				else:
					out.overflow_hits = _apply(state, source, {"kind": "damage", "amount": spill, "target": "enemy", "repeat": 1}, rng, "", reactions)
		"gold":
			if str(source.get("side", "")) == "player":
				## Pyrite a gem sends to the party lands in each ally's own purse; anything
				## else a player's gem makes is theirs.
				var purse: Dictionary = target if str(target.get("side", "")) == "player" else source
				purse.gold = DeepRules.sat_add(int(purse.get("gold", 0)), amount)
				gem_tally(source, "ore", amount)
				out.gold_after = purse.gold
				reactions.result_gold = DeepRules.sat_add(int(reactions.get("result_gold", 0)), amount)
			elif str(target.get("side", "")) == "player":
				## A creature dropping pyrite: it lands in the player's fight earnings.
				target.gold = DeepRules.sat_add(int(target.get("gold", 0)), amount)
				out.gold_after = target.gold
		"poison", "stun", "curse", "charged", "marked", "regeneration", "spikes", "dulled", "lifeline", "festering", "scorched", "burn", "strength", "envenom":
			## Lodestone stores no more than the Resonance there is to store.
			if kind == "charged" and bool(effect.get("resonance_cap", false)):
				amount = mini(amount, maxi(0, int(source.get("resonance", 0))))
				out.amount = amount
			if str(source.get("side", "")) == "player" and amount > 0:
				## The tally: what a player puts on creatures, and on the party.
				if str(target.get("side", "")) == "enemy" and kind in DeepRules.DEBUFFS:
					tally_kind(source, "debuffs", kind, amount)
					gem_tally(source, "debuffs", amount)
					if kind in ["poison", "burn"]:
						if not target.get("stacked_by", null) is Dictionary:
							target.stacked_by = {}
						target.stacked_by[kind] = str(source.get("id", ""))
				elif str(target.get("side", "")) == "player" and not kind in DeepRules.DEBUFFS:
					tally_kind(source, "buffs", kind, amount)
			# A new late enemy debuff must reach the player's next rail before decaying.
			# Reapplying an existing stack does not postpone its ordinary decay.
			if kind in DEFERRED_DECAY and amount > 0 and int(target.statuses.get(kind, 0)) == 0 and str(target.get("side", "")) == "player" and bool(source.get("acting", false)):
				if not target.has("deferred_decay"):
					target.deferred_decay = {}
				target.deferred_decay[kind] = true
			var had: int = int(target.statuses.get(kind, 0))
			target.statuses[kind] = DeepRules.sat_add(had, maxi(0, amount))
			if kind == "curse":
				target.statuses[kind] = mini(DeepRules.CURSE_MAX_STACKS, int(target.statuses[kind]))
			_note_result(source, target, kind, int(target.statuses[kind]) - had)
			if kind == "lifeline" and bool(effect.get("revive_block", false)):
				target.statuses.lifeline_block = DeepRules.sat_add(int(target.statuses.get("lifeline_block", 0)), amount)
			out[kind + "_after"] = target.statuses[kind]
		"gather_poison":
			## A Confluence: every other creature's Poison moves onto this one.
			var gathered: int = 0
			for other in living(state.enemies):
				if str(other.id) == str(target.id):
					continue
				gathered = DeepRules.sat_add(gathered, int(other.statuses.get("poison", 0)))
				other.statuses.poison = 0
			target.statuses.poison = DeepRules.sat_add(int(target.statuses.get("poison", 0)), gathered)
			out.gathered = gathered
			out.poison_after = int(target.statuses.poison)
		"poison_tick":
			## Its Poison ticks now, as it would at the end of the turn, that many times.
			var ticks: Array = []
			for _time in range(maxi(0, amount)):
				if int(target.statuses.get("poison", 0)) <= 0 or int(target.hp) <= 0:
					break
				var tick: Dictionary = _poison_tick(state, target, rng)
				if not tick.is_empty():
					ticks.append(tick)
			out.ticks = ticks
			if ticks.is_empty():
				out.nothing = true
		"grow_poison":
			## A Ferment: the Poison already on it grows by a share of itself.
			var had: int = int(target.statuses.get("poison", 0))
			target.statuses.poison = DeepRules.sat_add(had, DeepRules.sat_muldiv(had, maxi(0, amount), 100))
			out.poison_after = int(target.statuses.poison)
			_note_result(source, target, "poison", int(target.statuses.poison) - had)
		"max_hp":
			target.max_hp = DeepRules.sat_add(int(target.max_hp), maxi(0, amount))
			target.hp = DeepRules.sat_add(int(target.hp), maxi(0, amount))
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
			var kept: int = int(target.statuses.get("retain", 0))
			target.statuses.retain = mini(20, kept + maxi(0, amount))
			out.retain_after = target.statuses.retain
			_note_result(source, target, "retain", int(target.statuses.retain) - kept)
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
			if str(source.get("side", "")) == "player" and str(source.get("id", "")) != str(target.get("id", "")):
				tally_add(source, "revives", 1)
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
	## It drinks a color until its next action: one at random, or the one the party has set
	## most that it is not drinking already. With `add` it keeps the ones it had.
	var had: Array = target.get("absorb", []).duplicate() if bool(effect.get("add", false)) else []
	var color: String = ""
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
				color = str(key)
	if color.is_empty():
		var left: Array = DeepContent.color_KEYS.filter(func(c: String) -> bool: return not had.has(c))
		if left.is_empty():
			return {"nothing": true, "reason": "It drinks every color already."}
		color = str(DeepRng.pick(rng, left))
	had.append(color)
	target.absorb = had
	return {"color": color, "colors": had.duplicate()}

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

static func _tick_charge(state: Dictionary, foe: Dictionary, stunned: bool = false) -> Dictionary:
	## A blow wound up over turns: one action nearer each time it acts, cancelled if the party
	## takes enough off it meanwhile, let go when the count runs out. A stunned action still
	## counts, but cannot let the blow go: it waits for the next action the creature takes.
	var charge: Dictionary = foe.get("charging", {})
	if charge.is_empty():
		return {}
	var lost: int = int(charge.get("hp_at", foe.hp)) - int(foe.hp)
	if int(charge.get("cancel_pct", 0)) > 0 and lost * 100 >= int(foe.max_hp) * int(charge.cancel_pct):
		foe.charging = {}
		return {"broken": true, "lost": lost}
	if stunned and int(charge.get("turns", 1)) <= 1:
		charge.turns = 1
		return {"turns": 1}
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
	## A die broken this turn (a Glass die that shattered) would have grown back at the start
	## of the next one, and a fight that ends first does not get to keep it.
	## A Hot Streak's bonus die was only lent for a turn.
	var dice: Array = unit.get("dice", []).filter(func(d: Dictionary) -> bool: return not bool(d.get("bonus", false))).duplicate(true)
	for entry in unit.get("broken_dice", []):
		dice.insert(clampi(int(entry.get("at", 0)), 0, dice.size()), _regrown_die(unit, entry))
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
	## Enrage hardens a creature's own blows, not what its Spikes or a mirror send back.
	if str(source.get("side", "")) == "enemy" and not reactive:
		var enraged_on: int = enrage_turn(state)
		if int(state.turn) >= enraged_on:
			raw = DeepRules.sat_add(raw, enrage_step(state) * (int(state.turn) - enraged_on + 1))
	raw = DeepRules.outgoing_damage(raw, source.get("statuses", {}))
	var curse: int = clampi(int(target.statuses.get("curse", 0)), 0, DeepRules.CURSE_MAX_STACKS)
	var marked: int = int(target.statuses.get("marked", 0)) if not reactive and amount > 0 else 0
	raw = DeepRules.sat_scale(raw, 100 + DeepRules.CURSE_PERCENT * curse, 100 + 25 * marked, 10000)
	## Marked is spent by the whole gem (or Birthstone, or creature's move) that lands on it,
	## not by its first blow: every blow of a Thousand Cuts takes the mark. The marks come off
	## once that gem is done (`_settle_marks`).
	if marked > 0:
		target.mark_spent = true
	var out: Dictionary = {"raw": raw}
	## A Mirror a delver holds up: the next blow a creature lands is split, its share sent
	## straight back at whoever threw it and the rest landing as it would.
	if str(target.get("side", "")) == "player" and str(source.get("side", "")) == "enemy" and not reactive and raw > 0 and int(target.statuses.get("reflect", 0)) > 0:
		var pct: int = clampi(int(target.statuses.get("reflect_pct", 50)), 0, 100)
		target.statuses.reflect = int(target.statuses.reflect) - 1
		if int(target.statuses.reflect) <= 0:
			target.statuses.erase("reflect")
			target.statuses.erase("reflect_pct")
		var sent: int = DeepRules.sat_muldiv(raw, pct, 100)
		if sent > 0:
			var back: Dictionary = _damage(state, target, source, sent, rng, false, {}, true)
			back.target = str(source.id)
			back.kind = "damage"
			out.reflected = back
			out.reflected_amount = sent
			raw -= sent
			out.raw = raw
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
		## A color it is drinking does it no harm.
		var colors: Array = source.get("firing_colors", [])
		for color in target.get("absorb", []):
			if colors.has(color):
				out.merge({"absorbed": 0, "hp_loss": 0, "hp_after": target.hp, "block_after": target.block, "drunk": str(color)}, true)
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
			charging.stored = DeepRules.sat_add(int(charging.get("stored", 0)), raw)
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
	if not reactive:
		_note_result(source, target, "damage", DeepRules.sat_add(absorbed, loss))
	if piercing:
		out.piercing = true
	if rescued > 0:
		out.lifeline = rescued
	if marked > 0:
		out.marked_spent = marked
	if str(target.get("side", "")) == "player":
		target.block_lost_accum = int(target.get("block_lost_accum", 0)) + absorbed
		tally_add(target, "taken", loss)
		tally_add(target, "blocked", absorbed)
		if int(target.hp) <= 0:
			target.downed = true
			target.block = 0
			out.downed = true
			tally_add(target, "downs", 1)
		## A thief takes with every hit that draws blood: three pyrite, or three times that
		## for a Gilded one.
		var thieving: int = DeepCreatures.trait_value(source, "steal_gold", 0) if str(source.get("side", "")) == "enemy" else 0
		if thieving > 0 and loss > 0:
			var stolen: int = mini(3 * thieving, int(target.get("gold", 0)))
			target.gold = int(target.gold) - stolen
			source.stolen_gold = int(source.get("stolen_gold", 0)) + stolen
			out.stolen = stolen
	else:
		source.dealt = DeepRules.sat_add(int(source.get("dealt", 0)), loss)
		tally_add(source, "damage", loss)
		tally_add(source, "overkill", maxi(0, raw - loss))
		if not reactive:
			gem_tally(source, "damage", loss)
			if source.has("firing_stone"):
				source.firing_hit = DeepRules.sat_add(int(source.get("firing_hit", 0)), loss)
		if str(source.get("side", "")) == "player" and not reactive:
			## What this turn did to it, and who did it: read back by the creatures that
			## answer their hardest hit, their worst color or the hand that hurt them most.
			target.hurt_by[str(source.id)] = DeepRules.sat_add(int(target.get("hurt_by", {}).get(str(source.id), 0)), loss)
			for color in source.get("firing_colors", []):
				target.hurt_by_color[str(color)] = DeepRules.sat_add(int(target.get("hurt_by_color", {}).get(str(color), 0)), loss)
			if loss > int(target.get("biggest_hit", 0)):
				target.biggest_hit = loss
				var firing: Dictionary = source.get("firing_stone", {})
				if not firing.is_empty():
					target.hardest_gem = {"unit": str(source.id), "socket": int(firing.get("socket", -1)), "stone_id": str(firing.get("stone_id", ""))}
		if str(source.get("side", "")) == "player" and str(source.get("passive", {}).get("kind", "")) == "block_per_hit" and raw > 0:
			## Riposte: every hit the Rogue lands raises block worth her Resonance.
			var parry: int = int(source.get("resonance", 0))
			if parry > 0:
				source.block = DeepRules.sat_add(int(source.block), parry)
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
	## An Arsenic: every hit that gets past block leaves Poison behind.
	var venom: int = int(source.get("statuses", {}).get("envenom", 0))
	if not reactive and venom > 0 and int(out.get("hp_loss", 0)) > 0 and is_enemy_target and int(target.hp) > 0 and str(source.get("side", "")) == "player":
		out.envenom = _apply_one(state, source, target, "poison", venom, {}, rng, reactions)
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
	unit.lifeline_used = true
	unit.hp = mini(int(unit.max_hp), stacks)
	unit.downed = false
	unit.block = int(unit.get("block", 0)) + int(unit.statuses.get("lifeline_block", 0))
	unit.statuses.erase("lifeline_block")
	return int(unit.hp)

static func _heal(target: Dictionary, amount: int) -> int:
	if bool(target.get("downed", false)) or int(target.hp) <= 0:
		return 0
	amount = _heal_received(target, amount)
	var before: int = int(target.hp)
	target.hp = mini(int(target.max_hp), DeepRules.sat_add(before, maxi(0, amount)))
	return int(target.hp) - before

static func _heal_received(target: Dictionary, amount: int) -> int:
	## How much of a heal reaches its target before full health stops it.
	## Festering: what would heal only half does.
	if int(target.get("statuses", {}).get("festering", 0)) > 0:
		amount = maxi(0, amount) / 2
	## Festering Air: a Hazard tier cuts every heal a lapidary receives, all run long.
	var cut: int = int(target.get("run_mods", {}).get("heal_cut", 0))
	if cut > 0:
		amount = maxi(0, amount) * (100 - cut) / 100
	return maxi(0, amount)

static func _on_enemy_death(state: Dictionary, dead: Dictionary, killer: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## What a creature leaves behind: the turn it fell on (for whatever might grow it back),
	## the gems it was holding, a raw stone for a Hoard Mimic's killer, and the moves that
	## waited for this (a Puffball's burst), fired with the dead creature as their source.
	var out: Dictionary = {}
	dead.death_turn = int(state.turn)
	_note_kill(dead, killer)
	## How many have fallen this turn, for a Placer.
	state.turn_kills = int(state.get("turn_kills", 0)) + 1
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
	_settle_marks(state)
	foe.beat = "impact"
	if int(move.index) >= 0 and int(move.index) < foe.move_states.size():
		foe.move_states[int(move.index)] = "used" if bool(move.get("combo", false)) else "resolved"
	## A blow that block took part of is counted at the health bar, and the step waits for it.
	var soaked: bool = results.any(func(r: Dictionary) -> bool:
		return str(r.get("kind", "")) == "damage" and int(r.get("absorbed", 0)) > 0 and not player(state, str(r.get("target", ""))).is_empty())
	return _event(state, "enemy_move", {"unit": foe.id, "move": str(move.get("move", "")), "index": int(move.index),
		"effects": results, "dice": move.get("dice", []), "burrowed": bool(foe.get("burrowed", false)), "release": bool(move.get("release", false)),
		"pace": count_pace(state), "duration": BASE_DURATION.enemy_move + (SOAK_SPAN * count_pace(state) if soaked else 0.0)})

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
		_settle_marks(state)
		out.append({"move": name, "unit": str(foe.id), "effects": results})
	if not out.is_empty() and not bool(foe.get("acting", false)):
		DeepCreatures.prepare(foe)
	return out

static func _settle_marks(state: Dictionary) -> void:
	## Marks spent by the gem, Birthstone or move that just finished come off now, so every
	## blow of it took them and the next thing to land starts clean.
	for unit in state.players + state.enemies:
		if bool(unit.get("mark_spent", false)):
			unit.erase("mark_spent")
			unit.statuses.erase("marked")

static func _poison_tick(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	## One round of poison on one unit: it hurts for its stacks and loses one. When a creature
	## is the one bleeding, every Apothecary in the party drinks Resonance from it (Leech).
	var poison: int = int(unit.statuses.get("poison", 0))
	if poison <= 0 or int(unit.hp) <= 0:
		return {}
	var loss: int = mini(int(unit.hp), poison)
	unit.hp = int(unit.hp) - loss
	unit.statuses.poison = poison - 1
	_note_tick(state, unit, "poison", loss)
	var tick: Dictionary = {"unit": str(unit.id), "kind": "poison", "amount": loss, "hp_after": unit.hp, "remaining": unit.statuses.poison}
	_tick_wound(state, unit, tick, rng)
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

static func _note_tick(state: Dictionary, unit: Dictionary, kind: String, loss: int) -> void:
	## A tick's damage in the tally: taken by a player, or dealt by whoever's stacks they were.
	if str(unit.get("side", "")) == "player":
		tally_add(unit, "taken", loss)
	else:
		tally_add(player(state, str(unit.get("stacked_by", {}).get(kind, ""))), "damage", loss)

static func _burn_tick(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
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
	_note_tick(state, unit, "burn", loss)
	tally_add(unit, "blocked", soaked)
	var tick: Dictionary = {"unit": str(unit.id), "kind": "burn", "amount": loss, "soaked": soaked, "hp_after": unit.hp, "block_after": int(unit.block), "remaining": unit.statuses.burn}
	_tick_wound(state, unit, tick, rng)
	return tick

static func _note_kill(dead: Dictionary, killer: Dictionary) -> void:
	## The tally's kills: the blow's, or for a tick, whoever's stacks they were.
	if killer.is_empty() or str(killer.get("side", "")) != "player":
		return
	tally_add(killer, "slain", 1)
	if bool(dead.get("warden", false)):
		tally_add(killer, "slain_wardens", 1)

static func _tick_wound(state: Dictionary, unit: Dictionary, tick: Dictionary, rng: RandomNumberGenerator = null) -> void:
	## What a round of poison or burning leaves: a Lifeline spent, a player down, a creature
	## dead (and its burst), or a creature hurt past the point it was waiting for. The burst
	## and the moves it wakes draw on the fight's own generator, so a replay plays the same.
	if rng == null:
		rng = RandomNumberGenerator.new()
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
			tick.merge(_on_enemy_death(state, unit, {}, rng), true)
			_note_kill(unit, player(state, str(unit.get("stacked_by", {}).get(str(tick.get("kind", "")), ""))))
	elif str(unit.get("side", "")) == "enemy":
		var crossed: Array = _thresholds(state, unit, rng)
		if not crossed.is_empty():
			tick.thresholds = crossed

static func _tick(state: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var ticks: Array = []
	_settle_marks(state)
	for unit in state.players + state.enemies:
		if int(unit.hp) <= 0 or bool(unit.get("downed", false)):
			continue
		var tick: Dictionary = _poison_tick(state, unit, rng)
		if not tick.is_empty():
			ticks.append(tick)
		var burning: Dictionary = _burn_tick(state, unit, rng)
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
		## A Regenerating champion knits a share of itself back every turn.
		var knits: int = DeepCreatures.trait_value(unit, "regenerating", 0) if str(unit.get("side", "")) == "enemy" and int(unit.hp) > 0 else 0
		if knits > 0:
			var knit: int = _heal(unit, knits)
			if knit > 0:
				ticks.append({"unit": str(unit.id), "kind": "regeneration", "amount": knit, "hp_after": unit.hp, "remaining": 0})
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
	state.turn_kills = 0
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
		var aura: Dictionary = DeepCreatures.traits_for(foe).get("aura", {})
		for status in aura:
			auras[str(status)] = maxi(int(auras.get(str(status), 0)), int(aura[status]))
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
		## Retain preserves part of the unspent Block once. Spikes stay for the fight.
		_reset_defenses(unit)
		## What a Chainmail, a Contagion or a Rebound set up lasted the turn that has ended.
		unit.after_fire = []
		unit.on_block = []
		## A Contra Luz that fired last turn: its phantoms are still in the hand.
		var carried_phantoms: Array = []
		## A Hot Streak's bonus die lasts the turn it was thrown for, unless a Contra Luz kept
		## that turn's phantoms: then it stays in the bowl for one more.
		var keep_bonus: bool = bool(unit.get("keep_phantoms", false))
		if bool(unit.get("keep_phantoms", false)):
			for roll in unit.get("hand", []):
				if bool(roll.get("phantom", false)):
					var kept: Dictionary = roll.duplicate(true)
					kept.held = true
					kept.rerolls = 0
					kept.kept = true
					carried_phantoms.append(kept)
		unit.keep_phantoms = false
		if not keep_bonus:
			unit.dice = unit.dice.filter(func(d: Dictionary) -> bool: return not bool(d.get("bonus", false)))
		## What last turn's High Roller earned for this one: a bonus die, double Resonance.
		var earned: Array = unit.get("bonus_dice_next", [])
		for index in range(earned.size()):
			var spec: Dictionary = earned[index]
			var extra_die: Dictionary = DeepDice.make(str(spec.get("shape", "D6")), "%s_bonus%d_%d" % [str(unit.id), int(state.turn), index],
				{"pattern": str(spec.get("pattern", ""))} if not str(spec.get("pattern", "")).is_empty() else {})
			extra_die.bonus = true
			unit.dice.append(extra_die)
		unit.bonus_dice_next = []
		unit.resonance_doubled = bool(unit.get("double_resonance_next", false))
		unit.double_resonance_next = false
		unit.streak = int(unit.get("streak_next", 0))
		unit.streak_next = 0
		## The Changing Face: the face Motley showed last turn, and how many turns running the
		## faces have changed. A turn that showed no face (a mixed hand, a stun) ends the run.
		unit.last_face = str(unit.get("face_shown", ""))
		unit.change = int(unit.get("change_now", 0))
		unit.face_shown = ""
		unit.change_now = 0
		## Mirror's reflection lasts until its owner's next turn, like Block.
		unit.statuses.erase("reflect")
		unit.statuses.erase("reflect_pct")
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
		## A daily dig's Short-Handed: the smallest die sits this throw out.
		if bool(unit.get("run_mods", {}).get("short_handed", false)) and dice.size() > 1:
			var smallest: int = 0
			for index in range(dice.size()):
				if DeepDice.top(dice[index]) < DeepDice.top(dice[smallest]):
					smallest = index
			dice.remove_at(smallest)
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
				var steps: int = - mini(dread, maxi(0, at))
				if steps < 0:
					DeepOddities.resize(copy, steps)
				shrunk.append(copy)
			dice = shrunk
			unit.statuses.dread = dread - 1
			if int(unit.statuses.dread) <= 0:
				unit.statuses.erase("dread")
		unit.hand = DeepDice.roll_hand(dice, rng_dice, unit.get("hand", []))
		unit.hand.append_array(carried_phantoms)
		_loaded(unit, [], rng_dice)
		unit.regrown = regrown
		unit.dues = _pay_dues(state, unit)
		unit.crowned = _crowns_rolled(unit, unit.hand.filter(func(r: Dictionary) -> bool: return not bool(r.get("phantom", false))), true)
		unit.flips = int(unit.passive.get("amount", 1)) if str(unit.get("passive", {}).get("kind", "")) == "free_flip" else 0
		var extra: int = int(unit.passive.get("amount", 1)) if str(unit.get("passive", {}).get("kind", "")) == "extra_reroll" else 0
		var staked: Dictionary = unit.get("run_mods", {}).get("extra_rerolls", {})
		if staked is Dictionary and not staked.is_empty() and int(state.get("depth", 1)) <= int(staked.get("until_depth", 0)):
			## Steady Hands from the Grubstake: a reroll more until the first landing.
			extra += int(staked.get("amount", 1))
		## A daily dig's Shaky Hands takes one away, and Cold Start one more on a fight's first turn.
		extra += int(unit.get("run_mods", {}).get("reroll_shift", 0))
		if int(state.turn) == 1:
			extra += int(unit.get("run_mods", {}).get("first_turn_rerolls", 0))
		unit.rerolls_max = maxi(0, base_rerolls + extra + gifts + int(unit.get("granted_rerolls", 0)))
		unit.rerolls = 0 if frozen else unit.rerolls_max
		tally_add(unit, "rerolls_given", int(unit.rerolls))
		tally_add(unit, "turns", 1)
		unit.granted_rerolls = 0
		unit.locked = false
		unit.block_lost = int(unit.get("block_lost_accum", 0))
		unit.block_lost_accum = 0
		_note_turn(state, unit)
		unit.dealt_last_turn = int(unit.get("dealt", 0))
		unit.dealt = 0
		unit.healed = 0
		var foes: Array = living(state.enemies)
		if enemy(state, str(unit.get("target", ""))).get("hp", 0) <= 0 and not foes.is_empty():
			unit.target = str(default_target(foes).id)
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
			"crowned": u.get("crowned", []), "doubled": bool(u.get("resonance_doubled", false)),
			"locked": u.hand.filter(func(r: Dictionary) -> bool: return bool(r.get("locked_by_foe", false))).map(func(r: Dictionary) -> String: return str(r.die_id))})})

static func _check_outcome(state: Dictionary) -> void:
	if done(state):
		return
	if living(state.players).is_empty():
		state.erase("cleared")
		state.phase = "over"
		state.outcome = "defeat"
		_note_outcome(state)
	elif living(state.enemies).is_empty():
		## The last creature is down, but a rail still firing finishes its rung: the gems
		## after the killing blow may heal, shield or pay, and they are the player's.
		if _rail_firing(state):
			state.cleared = true
			return
		state.erase("cleared")
		state.phase = "over"
		state.outcome = "victory"
		_note_outcome(state)

static func _rail_firing(state: Dictionary) -> bool:
	## Whether the party's half of the turn is still playing: the next thing queued is part of
	## a rail (this player's next gem, or the next player's rail), not the creatures' turn.
	if str(state.get("phase", "")) != "resolving":
		return false
	var queue: Array = state.get("queue", [])
	return not queue.is_empty() and str(queue[0].get("kind", "")) in RUNG_STEPS

static func _close_cleared(state: Dictionary) -> void:
	state.erase("cleared")
	state.phase = "over"
	state.outcome = "victory"
	_note_outcome(state)

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
	unit.force_after = {}
	unit.fired_colors = []
	unit.gem_results = {}
	unit.resonance_mult = 1
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
		## A Certainty earlier on the rail has every gem after it firing whatever the hand says,
		## its repeats as well as its first go, the way the fight queues them.
		var certain: int = certain_times(unit, socket, false)
		fires = maxi(fires, certain)
		var event: Dictionary = {}
		var fired_effects: Array = []
		var activations: int = 0
		for repeat in range(maxi(1, fires)):
			var resolved: Dictionary = resolve_gem(copy, unit, socket, {"dry": true, "retrigger": repeat > 0, "force": repeat > 0 and repeat < certain}, rng)
			## Chatoyance and Certainty can fire a socket more than once. The socket's
			## count shows one activation; the rail's totals include every activation.
			## If the first changes the hand so the second fizzles, keep the first count.
			if str(resolved.get("kind", "")) == "gem_fire":
				activations += 1
				fired_effects.append_array(resolved.get("effects", []))
				event = resolved
			elif event.is_empty():
				event = resolved
		var entry: Dictionary = {"socket": socket, "stone_id": str(stone.id), "skill": str(stone.skill), "worn": str(stone.get("worn_from", "")),
			"active": activations > 0,
			"reason": str(event.get("reason", "")), "dice": event.get("dice", []), "resonance": int(event.get("resonance", 0)),
			"harmony": bool(event.get("harmony", false)), "cut_step": int(event.get("cut_step", 0)), "fires": activations,
			"effects": event.get("effects", []), "tally": event.get("tally", {}),
			"trigger": DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(preview.get("cut_step", 0)))}
		if entry.active:
			totals.fires += activations
			for effect in fired_effects:
				if str(effect.get("kind", "")) == "appraise":
					for hit in effect.get("hits", []):
						totals.damage += int(hit.get("raw", 0))
				if str(effect.get("kind", "")) == "invert_previous":
					for hit in effect.get("hits", []):
						var turned: String = str(hit.get("kind", ""))
						if totals.has(turned):
							totals[turned] += int(hit.get("raw", 0)) if turned == "damage" else int(hit.get("amount", 0))
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
