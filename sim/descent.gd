class_name DeepDescent
extends RefCounted
## A run: the shaft, its chambers and landings, and everything the party carries.
##
## The host owns one run state and drives it with `command()` for every player action and
## `step()` while a fight resolves. Every change returns an event for the screens. The
## shape of a run:
##
##   grubstake (each player takes one stake from the workshop) ─▶
##   tunnels ─pick─▶ chamber (fight | elite | vein | oddity | merchant | smithy | carver | motherlode) ─▶ tunnels …
##   every LANDING_EVERY depths: landing (a respite each: rest, appraise or the well; then up or down)
##   at warden depths the landing's gate is a warden fight; the hoard follows a win
##   the mine's last floor is its final boss: after the hoard, the lift or on into the next mine
##   a wipe → salvage → over (fallen);  the lift → over (extracted | conquered)
##
## Every mine but the last has a bottom. A party that beats a mine's final boss may push on
## into the mine below it with everything it carries: the depth starts again from the top of
## the new mine, but the creatures there are bred for a little deeper (`heat`), and the lift
## fare counts every floor the party has come down since the workshop (`carried`).
##
## Players keep their own haul and ore. Tunnels and the lift are votes. The bench (setting
## stones, swapping dice, giving things away) is open whenever there is no fight on.

const PHASES: Array = ["grubstake", "tunnels", "chamber", "landing", "hoard", "salvage", "over"]
const VEIN_SPOTS: int = 6
## The rock does not run out: the arm does. The first swing at an outcrop is free and every
## one after it costs a point more than the last, so a vein is worked until it stops being
## worth the blood — and clearing one out costs a great deal of it. How many swings a spot
## takes before it gives anything up depends on what is in it: dull rock comes away in one,
## a bright seam can take four.
const VEIN_HP_BASE: int = 1
## A hazardous vug charges this on top of every swing.
const VUG_HP: int = 2
const VEIN_HARDNESS: Dictionary = {"bright": [3, 4], "glint": [2, 3], "ore": [1, 2], "dull": [1, 1], "nothing": [1, 1]}
## A glittering hollow: every lapidary has their own few shining rocks, each with a stone in
## it that one blow breaks out. The first costs a point of health, and each after it a point
## more, so taking all of them is a choice.
const HOLLOW_ROCKS: int = 3
## The rooms whose rock is struck with a pick.
const ROCK_ROOMS: Array = ["vein", "vug", "motherlode"]
const HOARD_OFFERS: int = 3
const MERCHANT_STONES: int = 3
## A merchant also keeps one die for each player, in a size that player already carries.
const MERCHANT_DICE: int = 1
## Where dice are worked: a smithy makes one a size bigger or smaller and stamps patterns, a
## carver recuts and etches its faces, the vat changes what it is made of. Each is a chamber
## holding one fixed card. Whole dice are bought at a merchant, and only swapped size for size.
const DICE_ROOMS: Array = ["smithy", "carver", "vat"]
## Every room that holds one fixed card of its own rather than one drawn at random.
const CARD_ROOMS: Array = ["smithy", "carver", "vat", "well"]
const RESPITES: Array = ["rest", "appraise", "wish"]
## What a player who is down cannot do: anything a room, a stall, a hoard or the way on offers.
const DOWNED_CANNOT: Array = ["oddity", "buy", "sell", "appraise", "pick_hoard", "trade_offer", "trade_accept", "choose", "light", "strike", "respite"]
## What a landing's well will take, and the most of it.
const WISH_LEAST: int = 10
const WISH_MOST: int = 1000

# --- setup -------------------------------------------------------------------------------

static func new_run(config: Dictionary) -> Dictionary:
	## config: seed (int), mine (key), run_id, boons (bool, default true),
	##   players: [{id, name, character, rail: [stones|null], dice: [die instances], last_depth, last_outcome,
	##   sockets (how many the lapidary has open; three by default), insured (bool)}]
	var seed_value: int = int(config.get("seed", randi()))
	var mine_key: String = str(config.get("mine", DeepContent.starter_mine()))
	var mine_def: Dictionary = DeepContent.mine(mine_key)
	var state: Dictionary = {"run_id": str(config.get("run_id", "run%08x" % seed_value)), "seed": seed_value, "mine": mine_key, "from_mine": mine_key,
		"depth": 0, "phase": "tunnels", "outcome": "", "players": [], "offers": [], "chamber": {}, "landing": {},
		"hoard": {}, "salvage": {}, "aftermath": {}, "used_oddities": [], "path": [], "records": {"deepest": 0, "wardens": [], "boss": false, "stones_found": 0, "fights": 0},
		"heat": 0, "carried": 0, "mines_done": [], "rng": {}, "seq": 0, "next_id": 1}
	var streams: Dictionary = DeepRng.streams(seed_value)
	state.schedule = plan_shaft(streams.tunnels, mine_def)
	## Every lapidary goes down with the sockets they have opened filled from the vault, in any
	## mine. A party that starts in a deeper mine rather than fighting down to it is given
	## what the way down would have given it: a purse, a temporary stone for every socket
	## with nothing in it (shut, or bought and left empty), picked at the shaft head and gone
	## when the run ends, and a die to swap each of its own for, as the smithies, carvers and
	## vats above would have offered (`_dice_offers`).
	var deeper: bool = mine_key != DeepContent.starter_mine()
	var temps: RandomNumberGenerator = DeepRng.streams(seed_value, ["temps"]).temps
	var outfit: RandomNumberGenerator = DeepRng.streams(seed_value, ["outfit"]).outfit
	var seat: int = 0
	## The rail goes down as copies of the vault's stones, and the vault keeps the stones
	## themselves: a copy is marked lent, and wherever it ends up it never comes home.
	state.marks_lent = true
	for entry in config.get("players", []):
		var open: int = int(entry.get("sockets", DeepContent.constant("starting_rail_cap", 3)))
		var rail: Array = entry.get("rail", []).duplicate(true)
		for index in range(open, rail.size()):
			rail[index] = null
		for stone in rail:
			if stone is Dictionary:
				stone.lent = true
		var unit: Dictionary = DeepBattle.make_player(str(entry.get("id", "p%d" % seat)), str(entry.get("name", DeepProfile.DEFAULT_NAME)), str(entry.get("character", DeepContent.starter_character())),
			rail, entry.get("dice", []))
		unit.merge({"seat": seat, "haul": [], "bag_dice": [], "ore": int(mine_def.get("start_pyrite", 0)), "vote": "", "seen": [],
			"choice": "", "respite": "", "ready": false, "strikes": 0, "mining": false, "oddity_choice": "", "stake": "", "last_depth": int(entry.get("last_depth", 0)),
			"last_outcome": str(entry.get("last_outcome", "")), "insured": bool(entry.get("insured", false)), "temps": [],
			"stats": {"damage": 0, "healing": 0, "stones": 0, "fights": 0, "ore": 0, "earned": 0}}, true)
		state.players.append(unit)
		if deeper:
			unit.temps = _temporary_offers(state, unit, temps)
			unit.dice_offers = _dice_offers(state, unit, outfit)
		seat += 1
	_unique_rails(state)
	state.rng = DeepRng.save(streams)
	if bool(config.get("boons", true)) and not DeepContent.section("boons").is_empty():
		_offer_grubstake(state, streams)
	else:
		## No shaft head to stand at: every temporary socket takes the first of its three, and
		## every die stays as it is.
		for unit in state.players:
			for offer in unit.temps:
				_set_temporary(unit, offer, 0)
			for offer in unit.get("dice_offers", []):
				offer.kept = true
		_offer_tunnels(state, streams)
	state.rng = DeepRng.save(streams)
	return state

# --- the grubstake -----------------------------------------------------------------------

static func _offer_grubstake(state: Dictionary, streams: Dictionary) -> void:
	## Before the first tunnels, every player is shown their stakes and takes one.
	state.phase = "grubstake"
	state.offers = []
	state.grubstake = {"offers": {}, "chosen": {}}
	for unit in state.players:
		unit.stake = ""
		state.grubstake.offers[str(unit.id)] = DeepBoons.offer(state, unit, streams.boons)

static func _take_stake(state: Dictionary, unit: Dictionary, offer_id: String, payload: Dictionary) -> Dictionary:
	if not str(unit.get("stake", "")).is_empty():
		return _refuse("you have taken your stake")
	if temporary_left(unit) > 0:
		return _refuse("choose your temporary stones first")
	if dice_offers_left(unit) > 0:
		return _refuse("answer for your dice first")
	var chosen: Dictionary = {}
	for offer in state.get("grubstake", {}).get("offers", {}).get(str(unit.id), []):
		if str(offer.get("id", "")) == offer_id:
			chosen = offer
	if chosen.is_empty():
		return _refuse("no such stake")
	var streams: Dictionary = streams_of(state)
	var result: Dictionary = DeepBoons.apply(state, unit, chosen, payload, streams.boons)
	if not result.ok:
		return _refuse(str(result.error))
	state.rng = DeepRng.save(streams)
	unit.stake = offer_id
	for _made in result.get("made", []):
		unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
		state.records.stones_found = int(state.records.stones_found) + 1
	state.grubstake.chosen[str(unit.id)] = {"offer": offer_id, "boons": chosen.get("boons", []).duplicate(), "message": str(result.message),
		"made": result.get("made", []).duplicate(true), "dice": result.get("dice", []).duplicate(true), "changed": result.get("changed", []).duplicate(true)}
	var event: Dictionary = _event(state, "staked", {"unit": unit.id, "offer": offer_id, "boons": chosen.get("boons", []).duplicate(),
		"message": str(result.message), "made": result.get("made", []).duplicate(true), "dice": result.get("dice", []).duplicate(true),
		"changed": result.get("changed", []).duplicate(true), "pick": bool(result.get("pick", false))})
	if _close_grubstake(state):
		event.finished = true
	return {"ok": true, "event": event}

static func _close_grubstake(state: Dictionary) -> bool:
	## The shaft head lets the party go once everyone still in it has taken a stake.
	for other in living(state):
		if str(other.get("stake", "")).is_empty():
			return false
	## Charting the first stretch draws on the tunnels stream, so the streams it drew from are
	## the ones saved: a fresh copy saved instead would hand the same numbers out again later.
	var streams: Dictionary = streams_of(state)
	_offer_tunnels(state, streams)
	state.rng = DeepRng.save(streams)
	return true

static func streams_of(state: Dictionary) -> Dictionary:
	return DeepRng.restore(state.get("rng", {}))

# --- temporary stones ------------------------------------------------------------------------
##
## Below the Quarry a lapidary's sockets do not go down empty: neither the shut ones nor one
## bought and left without a vault stone, which would otherwise be worse than not buying it.
## Each is offered three temporary stones in its own color (an Any socket, three colors),
## already read, and the one taken is set there at the shaft head, before the stakes. A temporary stone is fragile: it
## cannot be kept, sold, turned in or thrown down a well, and it is gone when the run ends.

static func _temporary_offers(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator) -> Array:
	var mine: Dictionary = mine_of(state)
	var sockets: Array = DeepContent.character(str(unit.get("character", ""))).get("sockets", [])
	var depth: int = int(DeepContent.constant("temporary_depth", 20))
	var pool: Array = DeepForge.skill_pool(mine).filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) != DeepContent.OPAL)
	var offers: Array = []
	for index in range(sockets.size()):
		if index < unit.rail.size() and unit.rail[index] is Dictionary:
			continue
		var socket: String = str(sockets[index])
		var colors: Array = [socket, socket, socket]
		if socket == DeepContent.SOCKET_ANY:
			var left: Array = DeepContent.color_KEYS.duplicate()
			colors = []
			for _i in range(3):
				var drawn: String = str(left[rng.randi_range(0, left.size() - 1)])
				left.erase(drawn)
				colors.append(drawn)
		var picks: Array = []
		for color in colors:
			var of_color: Array = pool.filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == str(color))
			picks.append(_temporary_stone(state, unit, mine, depth, rng, of_color if not of_color.is_empty() else pool, picks))
		offers.append({"index": index, "socket": socket, "picks": picks, "chosen": -1})
	return offers

static func _temporary_stone(state: Dictionary, unit: Dictionary, mine: Dictionary, depth: int, rng: RandomNumberGenerator, pool: Array, beside: Array) -> Dictionary:
	## One temporary stone, of a skill the others offered for its socket are not, if the
	## pool runs to it. Never Void: a Void stone would leave its socket for a ride.
	##
	## A temporary stone has to stand comparison with the vault: a player who could just bring
	## their own stones is choosing between one they picked and one they are lent. So it comes
	## out of the rock at the bottom of the mine's luck, with `temporary_luck` on top, and the
	## wheel spins again (a little kinder each time, as a Royal Flush's find does) until it is
	## at least `temporary_min_tier`.
	var fresh: Array = pool.filter(func(k: String) -> bool: return not beside.any(func(s: Dictionary) -> bool: return str(s.get("skill", "")) == k))
	var bonus: float = float(DeepContent.constant("temporary_luck", 4))
	var wanted: int = DeepStone.TIERS.find(str(DeepContent.constant("temporary_min_tier", "PRECIOUS")))
	var provenance: Dictionary = {"run": str(state.get("run_id", "")), "source": "temporary", "finder": str(unit.get("id", ""))}
	var stone_id: String = _id(state, "tmp")
	var stone: Dictionary = {}
	for attempt in range(12):
		var drawn: Dictionary = DeepForge.roll_stone(rng, mine, depth, bonus + attempt * 2.0, provenance, stone_id, fresh if not fresh.is_empty() else pool)
		if DeepStone.is_fragile(drawn):
			continue
		if stone.is_empty() or int(DeepStone.grade(drawn).score) > int(DeepStone.grade(stone).score):
			stone = drawn
		if DeepStone.TIERS.find(str(DeepStone.grade(stone).tier)) >= wanted:
			break
	if stone.is_empty():
		stone = DeepForge.roll_stone(rng, mine, depth, bonus, provenance, stone_id, fresh if not fresh.is_empty() else pool)
	stone.inclusions = stone.inclusions.filter(func(k: Variant) -> bool:
		return not DeepContent.inclusion(str(k)).get("modifiers", []).any(func(m: Dictionary) -> bool: return str(m.get("kind", "")) == "fragile"))
	stone.appraised = true
	stone.inclusions_revealed = true
	stone.fragile = true
	stone.temporary = true
	return stone

static func temporary_left(unit: Dictionary) -> int:
	## How many of a player's empty sockets still wait for their temporary stone.
	return unit.get("temps", []).filter(func(o: Dictionary) -> bool: return int(o.get("chosen", -1)) < 0).size()

static func _set_temporary(unit: Dictionary, offer: Dictionary, pick: int) -> Dictionary:
	var stone: Dictionary = offer.picks[pick].duplicate(true)
	var index: int = int(offer.index)
	while unit.rail.size() <= index:
		unit.rail.append(null)
	unit.rail[index] = stone
	offer.chosen = pick
	return stone

static func _take_temporary(state: Dictionary, unit: Dictionary, index: int, pick: int) -> Dictionary:
	var offer: Dictionary = {}
	for candidate in unit.get("temps", []):
		if int(candidate.get("index", -1)) == index:
			offer = candidate
	if offer.is_empty():
		return _refuse("that socket takes no temporary stone")
	if int(offer.get("chosen", -1)) >= 0:
		return _refuse("that socket has its temporary stone")
	if pick < 0 or pick >= offer.get("picks", []).size():
		return _refuse("no such stone")
	var stone: Dictionary = _set_temporary(unit, offer, pick)
	return {"ok": true, "event": _event(state, "temporary", {"unit": unit.id, "index": index, "stone": stone.duplicate(true), "left": temporary_left(unit)})}

# --- dice offered for a deeper start -------------------------------------------------------
##
## A party fighting down to a deep mine passes smithies, carvers and vats on the way. One that
## starts there instead is offered, at the shaft head and after its temporary stones, a choice
## for every die it carries, one die at a time: three dice to swap it for, or keep it as it is.
## The left one is its size or smaller, the middle one its size and the right one its size or
## bigger, and every one of them differs from it: the middle one always in its pattern, an
## etching or its material. How far the sizes stray and how much else is cut into them grows
## with the mine (`start_dice_offer`): `steps` are the chances, in percent, of a side die
## being at least one, two and three sizes off, and `variation` the chance of each pattern,
## etching or material being cut into a die on top of whatever it must have. Like everything
## else done to a die down the mine, a swap stays down there: the bowl at home is untouched.

const DICE_OFFER_AXES: Array = ["pattern", "etching", "material"]
## How many times a die is drawn again when it comes out the same as one already offered.
const DICE_OFFER_TRIES: int = 6

static func _dice_offers(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator) -> Array:
	var tuning: Dictionary = mine_of(state).get("start_dice_offer", {})
	var offers: Array = []
	for index in range(unit.get("dice", []).size()):
		var die: Dictionary = unit.dice[index]
		var picks: Array = []
		for side in [-1, 0, 1]:
			var offered: Dictionary = {}
			for _try in range(DICE_OFFER_TRIES):
				offered = _offered_die(die, side * _offer_steps(rng, tuning), tuning, rng)
				if not ([die] + picks).any(func(other: Dictionary) -> bool: return same_die(other, offered)):
					break
			picks.append(offered)
		offers.append({"index": index, "die_id": str(die.get("id", "")), "picks": picks, "chosen": -1, "kept": false})
	return offers

static func _offer_steps(rng: RandomNumberGenerator, tuning: Dictionary) -> int:
	## How many sizes a side die strays: one draw read against the chances of at least one,
	## two and three sizes.
	var drawn: float = rng.randf() * 100.0
	var steps: int = 0
	for chance in tuning.get("steps", [30, 1]):
		if drawn < float(chance):
			steps += 1
	return steps

static func _offered_die(original: Dictionary, steps: int, tuning: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## One die to swap `original` for: `steps` sizes off (as far as dice go), with variations
	## cut into it. A die of the same size always gets at least one, so no offer is the die
	## itself.
	var die: Dictionary = original.duplicate(true)
	var at: int = DeepOddities.SIZES.find(str(die.get("shape", "D6")))
	if at >= 0 and steps != 0:
		var wanted: int = clampi(at + steps, 0, DeepOddities.SIZES.size() - 1) - at
		if wanted != 0:
			DeepOddities.resize(die, wanted)
	var varied: int = 0
	for axis in DICE_OFFER_AXES:
		if DeepRng.chance(rng, float(tuning.get("variation", 15))) and _vary_offer(die, axis, rng):
			varied += 1
	if varied == 0 and str(die.get("shape", "")) == str(original.get("shape", "")):
		var axes: Array = DICE_OFFER_AXES.duplicate()
		while not axes.is_empty():
			var axis: String = str(axes.pop_at(rng.randi_range(0, axes.size() - 1)))
			if _vary_offer(die, axis, rng):
				break
	return die

static func _vary_offer(die: Dictionary, axis: String, rng: RandomNumberGenerator) -> bool:
	## One variation cut into an offered die, always a change: a pattern it does not have, an
	## etching on a plain face, a material other than its own. Whether it took.
	match axis:
		"pattern":
			var shape: String = str(die.get("shape", "D6"))
			for _try in range(DICE_OFFER_TRIES):
				var pattern: String = DeepForge.roll_pattern(rng, shape)
				if pattern.is_empty() or pattern == str(die.get("pattern", "")):
					continue
				var stamped: Dictionary = DeepDice.make(shape, str(die.id), {"pattern": pattern, "rng": rng,
					"material": str(die.get("material", "")), "etches": DeepDice.etchings(die), "name": DeepDice.given_name(die)})
				die.clear()
				die.merge(stamped)
				return true
		"etching":
			var plain: Array = []
			for index in range(die.get("faces", []).size()):
				if str(die.faces[index].get("kind", "plain")) == "plain":
					plain.append(index)
			var etching: String = DeepForge.roll_etching(rng)
			if not plain.is_empty() and not etching.is_empty():
				DeepDice.etch(die, int(DeepRng.pick(rng, plain)), etching)
				return true
		"material":
			for _try in range(DICE_OFFER_TRIES):
				var material: String = DeepForge.roll_material(rng)
				if not material.is_empty() and material != str(die.get("material", "")):
					die.material = material
					return true
	return false

static func same_die(a: Dictionary, b: Dictionary) -> bool:
	## Two dice that would throw the same: one shape, pattern and material, and face for face
	## the same numbers and etchings.
	if str(a.get("shape", "")) != str(b.get("shape", "")) or str(a.get("pattern", "")) != str(b.get("pattern", "")) or str(a.get("material", "")) != str(b.get("material", "")):
		return false
	var mine: Array = a.get("faces", [])
	var theirs: Array = b.get("faces", [])
	if mine.size() != theirs.size():
		return false
	for index in range(mine.size()):
		if int(mine[index].get("value", 0)) != int(theirs[index].get("value", 0)) or str(mine[index].get("kind", "plain")) != str(theirs[index].get("kind", "plain")):
			return false
	return true

static func dice_offers_left(unit: Dictionary) -> int:
	## How many of a player's dice still wait for an answer at the shaft head.
	return unit.get("dice_offers", []).filter(func(o: Dictionary) -> bool: return int(o.get("chosen", -1)) < 0 and not bool(o.get("kept", false))).size()

static func _take_dice_offer(state: Dictionary, unit: Dictionary, index: int, pick: int) -> Dictionary:
	## `pick` -1 keeps the die as it is; 0 to 2 swaps it for that one.
	if temporary_left(unit) > 0:
		return _refuse("choose your temporary stones first")
	var offer: Dictionary = {}
	for candidate in unit.get("dice_offers", []):
		if int(candidate.get("index", -1)) == index:
			offer = candidate
	if offer.is_empty():
		return _refuse("that die is offered nothing")
	if int(offer.get("chosen", -1)) >= 0 or bool(offer.get("kept", false)):
		return _refuse("you have answered for that die")
	if pick < -1 or pick >= offer.get("picks", []).size():
		return _refuse("no such die")
	var at: int = -1
	for slot in range(unit.dice.size()):
		if str(unit.dice[slot].get("id", "")) == str(offer.die_id):
			at = slot
	if at < 0:
		return _refuse("that die is gone")
	if pick < 0:
		offer.kept = true
	else:
		unit.dice[at] = offer.picks[pick].duplicate(true)
		offer.chosen = pick
	return {"ok": true, "event": _event(state, "dice_offer", {"unit": unit.id, "index": index, "pick": pick, "die": unit.dice[at].duplicate(true), "left": dice_offers_left(unit)})}

static func mine_of(state: Dictionary) -> Dictionary:
	var mine: Dictionary = DeepContent.mine(str(state.get("mine", "")))
	if not mine.has("key"):
		mine = mine.duplicate()
		mine.key = str(state.get("mine", ""))
	return mine

static func player(state: Dictionary, id: String) -> Dictionary:
	return DeepBattle.player(state, id)

static func living(state: Dictionary) -> Array:
	return state.players.filter(func(p: Dictionary) -> bool: return not bool(p.get("downed", false)) and bool(p.get("connected", true)))

static func landing_every() -> int:
	return maxi(2, int(DeepContent.constant("landing_every", 4)))

static func is_landing(depth: int) -> bool:
	## Where a landing would be if nobody rolled for it. A run under way asks `run_is_landing`.
	return depth > 0 and depth % landing_every() == 0

static func plan_shaft(rng: RandomNumberGenerator, mine: Dictionary = {}) -> Dictionary:
	## Where this run's lifts and Wardens actually stand in a mine. The written depths are
	## only roughly where they are: every landing wanders a floor either way and its Warden
	## goes with it, so nobody can count steps to the next one. That is the whole point — not
	## knowing how far the next lift is makes the lantern, and the ore that lights the way,
	## worth having. The bottom of the mine never moves: its final boss is on the last floor.
	## An endless mine plans nothing: a lift every fourth floor and a Warden every eighth.
	if mine.is_empty():
		mine = DeepContent.mine(DeepContent.starter_mine())
	if bool(mine.get("endless", false)):
		return {"landings": [], "wardens": [], "boss": 0}
	var every: int = landing_every()
	var bottom: int = int(mine.get("depth", 24))
	var landings: Array = []
	var at: int = 0
	var index: int = 0
	while at < bottom:
		index += 1
		var nominal: int = index * every
		if nominal >= bottom:
			landings.append(bottom)
			break
		landings.append(clampi(nominal + rng.randi_range(-1, 1), at + 2, bottom - 2))
		at = int(landings[landings.size() - 1])
	## A Warden guards a landing, so the written Warden depths are read as which landing they
	## are: the second, the fourth, the last, wherever those have ended up.
	var wardens: Array = []
	for written in mine.get("warden_depths", []):
		var which: int = int(round(float(written) / float(every))) - 1
		if which >= 0 and which < landings.size() - 1 and not wardens.has(int(landings[which])):
			wardens.append(int(landings[which]))
	wardens.append(bottom)
	return {"landings": landings, "wardens": wardens, "boss": bottom}

static func run_is_landing(state: Dictionary, depth: int) -> bool:
	## Past the bottom of the charted shaft — the Endless — the plain every-fourth rule is
	## back, because nothing down there was planned in advance.
	var listed: Array = state.get("schedule", {}).get("landings", [])
	if listed.is_empty() or depth > int(listed[listed.size() - 1]):
		return is_landing(depth)
	return DeepPatch.holds(listed, depth)

static func run_is_warden(state: Dictionary, depth: int) -> bool:
	## A Warden or the final boss stands at this landing.
	if bool(mine_of(state).get("endless", false)):
		return is_warden_depth(depth, str(state.get("mine", "")))
	var listed: Array = state.get("schedule", {}).get("wardens", [])
	if listed.is_empty():
		return is_warden_depth(depth, str(state.get("mine", "")))
	return DeepPatch.holds(listed, depth)

static func run_is_boss(state: Dictionary, depth: int) -> bool:
	## The mine's last floor, where its final boss waits.
	var bottom: int = bottom_of(state)
	return bottom > 0 and depth == bottom

static func bottom_of(state: Dictionary) -> int:
	## The last floor of the mine the party is in, or 0 in a mine with no bottom. A run saved
	## before mines had bosses keeps the bottom it was planned with: its last landing.
	var schedule: Dictionary = state.get("schedule", {})
	if schedule.has("boss"):
		return int(schedule.boss)
	var landings: Array = schedule.get("landings", [])
	return int(landings.back()) if not landings.is_empty() else DeepContent.mine_bottom(str(state.get("mine", "")))

static func next_landing(state: Dictionary, depth: int) -> int:
	## The next lift down from here, as this run laid them out.
	for at in state.get("schedule", {}).get("landings", []):
		if int(at) > depth:
			return int(at)
	var every: int = landing_every()
	return (depth / every + 1) * every

static func warden_every(mine: Dictionary) -> int:
	return maxi(1, int(mine.get("warden_every", DeepContent.constant("endless_warden_every", 8))))

static func is_warden_depth(depth: int, mine_key: String = "") -> bool:
	## Where a mine's Wardens and final boss stand as written, before any run moves them.
	var key: String = mine_key if not mine_key.is_empty() else DeepContent.starter_mine()
	var mine: Dictionary = DeepContent.mine(key)
	if depth <= 0:
		return false
	if bool(mine.get("endless", false)):
		return depth % warden_every(mine) == 0
	for d in mine.get("warden_depths", []):
		if int(d) == depth:
			return true
	return depth == DeepContent.mine_bottom(key)

static func warden_key(state: Dictionary, depth: int) -> String:
	## Who guards this landing: the mine's Wardens in order, and at the bottom its final boss.
	## In an endless mine the Wardens take their turns, one every eighth floor.
	var mine: Dictionary = mine_of(state)
	var wardens: Array = mine.get("wardens", [])
	if run_is_boss(state, depth) and not str(mine.get("boss", "")).is_empty():
		return str(mine.boss)
	if wardens.is_empty():
		return str(mine.get("boss", ""))
	if bool(mine.get("endless", false)):
		## The Rift remembers the bosses above it, in order, and every so often (the fifth
		## Warden, the tenth) something of its own stands there instead.
		var nth: int = maxi(1, depth / warden_every(mine))
		var unmade_every: int = int(mine.get("unmade_every", 0))
		if not str(mine.get("unmade", "")).is_empty() and unmade_every > 0 and nth % unmade_every == 0:
			return str(mine.unmade)
		var skipped: int = (nth - 1) / unmade_every if unmade_every > 0 else 0
		return str(wardens[(nth - 1 - skipped) % wardens.size()])
	var listed: Array = state.get("schedule", {}).get("wardens", mine.get("warden_depths", []))
	var index: int = -1
	for i in range(listed.size()):
		if int(listed[i]) == depth:
			index = i
	if index < 0:
		index = wardens.size() - 1
	return str(wardens[mini(index, wardens.size() - 1)])

static func _id(state: Dictionary, prefix: String) -> String:
	## Unique within the run and tagged with it: the vault keeps the ids its stones were found
	## with, and a stone set from it must never share one with a stone found this time down,
	## or moving one of the two would carry off the other with it.
	state.next_id = int(state.get("next_id", 1)) + 1
	return "%s%d_%s" % [prefix, state.next_id, str(state.get("run_id", "")).right(4)]

static func _unique_rails(state: Dictionary) -> void:
	## Stones come down from the vault with the ids they were found with, and older runs
	## handed the same few out again, so two set stones can arrive sharing one. Every stone
	## after the first to carry an id is given a fresh one.
	var seen: Dictionary = {}
	for unit in state.players:
		for stone in DeepStone.rail_stones(unit):
			var id: String = str(stone.get("id", ""))
			if id.is_empty() or seen.has(id):
				stone.id = _id(state, "st")
			seen[str(stone.id)] = true

# --- tunnels -----------------------------------------------------------------------------
##
## Each stretch between landings is charted when the party reaches its head: a lattice of
## chambers, two mouths wide at the top and fanning out a mouth wider every depth, each
## chamber leading on to the two nearest below it so the ways split and rejoin without ever
## crossing. The tunnels offered are the ways on from where the party stands. The lantern
## shows what lies LANTERN_REACH depths ahead: the mouths say what the next floor holds, so
## the chart's worth is the floor past them. A dark mouth
## shows nothing until the party reaches it or pays ore to light that floor. Every stretch holds a merchant somewhere
## below its first depth, and a smithy or a carver on its last.

const MAP_WIDEST: int = 4
const LANTERN_REACH: int = 2
const GLINTS: Dictionary = {"fight": "hostile", "elite": "hostile", "warden": "hostile", "vein": "glittering", "motherlode": "glittering", "oddity": "strange",
	"merchant": "strange", "smithy": "strange", "carver": "strange", "vat": "strange", "well": "strange"}

static func _offer_tunnels(state: Dictionary, streams: Dictionary) -> void:
	state.phase = "tunnels"
	state.chamber = {}
	var next_depth: int = int(state.depth) + 1
	for unit in state.players:
		unit.vote = ""
		unit.ready = false
	if run_is_landing(state, next_depth):
		state.offers = [ {"id": "landing", "kind": "landing", "hidden": false}]
		return
	var map: Dictionary = state.get("map", {})
	if map.is_empty() or next_depth <= int(map.get("from", 0)) or next_depth >= int(map.get("to", 0)):
		_chart(state, streams)
		map = state.map
	var ids: Array = []
	var here: Dictionary = map.nodes.get(str(map.get("at", "")), {})
	if not here.is_empty() and int(here.depth) == int(state.depth):
		ids = here.next
	else:
		ids = row_of(map, next_depth)
	var offers: Array = []
	for id in ids:
		var node: Dictionary = map.nodes[str(id)]
		offers.append({"id": str(node.id), "kind": str(node.kind), "hidden": bool(node.hidden)})
	state.offers = offers

static func _chart(state: Dictionary, streams: Dictionary) -> void:
	## Chart the stretch from here down to the next landing.
	var from: int = int(state.depth)
	var to: int = from + 1
	while not run_is_landing(state, to):
		to += 1
	var mine: Dictionary = mine_of(state)
	var weights: Dictionary = mine.get("chambers", {"fight": 48, "elite": 12, "vein": 18, "oddity": 14, "merchant": 8, "smithy": 6, "carver": 6, "vat": 4, "well": 5})
	var rng: RandomNumberGenerator = streams.tunnels
	var nodes: Dictionary = {}
	var rows: Array = []
	var width: int = 2
	for depth in range(from + 1, to):
		var row: Array = []
		var once: Array = []
		var dark: bool = false
		for index in range(width):
			var table: Dictionary = weights.duplicate()
			if depth <= 2:
				table.erase("elite")
			## Nobody has ore to spend on the first step down.
			if depth <= 1:
				table.erase("merchant")
			for kept in once:
				table.erase(kept)
			var kind: String = DeepRng.weighted_key(rng, table)
			if kind.is_empty():
				kind = "fight"
			if kind == "vein" and DeepRng.chance(rng, float(mine.get("motherlode_pct", 3))):
				kind = "motherlode"
			if kind in ["elite", "oddity", "merchant"] or kind in CARD_ROOMS:
				once.append(kind)
			## Lanes spread evenly across the rock with a little wander, never out of order.
			var lane: float = (float(index) + 0.5) / float(width) + rng.randf_range(-0.28, 0.28) / float(width)
			var id: String = "n%d_%d" % [depth, index]
			## At most one dark mouth a depth: the lantern always has something to show.
			var hidden: bool = depth > 1 and not dark and DeepRng.chance(rng, 22.0)
			dark = dark or hidden
			nodes[id] = {"id": id, "depth": depth, "x": snappedf(clampf(lane, 0.06, 0.94), 0.001), "kind": kind, "hidden": hidden, "next": []}
			row.append(id)
		rows.append(row)
		width = mini(width + 1, MAP_WIDEST)
	## A stretch with no merchant in it gets one: the second depth down trades a fight or a
	## vein for a stall.
	var stalls: Array = nodes.values().filter(func(n: Dictionary) -> bool: return str(n.kind) == "merchant")
	if stalls.is_empty() and rows.size() >= 2:
		var swappable: Array = rows[1].filter(func(id: Variant) -> bool: return str(nodes[str(id)].kind) in ["fight", "vein"])
		if not swappable.is_empty():
			nodes[str(DeepRng.pick(rng, swappable))].kind = "merchant"
	## Nor one with nowhere to work dice: the last depth trades a fight or a vein for a smithy
	## or a carver.
	var benches: Array = nodes.values().filter(func(n: Dictionary) -> bool: return str(n.kind) in DICE_ROOMS)
	if benches.is_empty() and not rows.is_empty():
		var last: Array = rows[rows.size() - 1].filter(func(id: Variant) -> bool: return str(nodes[str(id)].kind) in ["fight", "vein"])
		if not last.is_empty():
			nodes[str(DeepRng.pick(rng, last))].kind = str(DeepRng.pick(rng, DICE_ROOMS))
	## Each chamber leads to a window of the row below; neighbouring windows share an end,
	## so the ways fork and rejoin but never cross.
	for r in range(rows.size() - 1):
		var above: Array = rows[r]
		var below: Array = rows[r + 1]
		var m: int = above.size()
		var n: int = below.size()
		var reach: int = 0
		for i in range(m):
			var lo: int = maxi(reach, int(floor(float(i * (n - 1)) / float(m))))
			var hi: int = maxi(lo, int(ceil(float((i + 1) * (n - 1)) / float(m))))
			for j in range(lo, mini(hi, n - 1) + 1):
				nodes[str(above[i])].next.append(str(below[j]))
			reach = hi
	if not rows.is_empty():
		for id in rows[rows.size() - 1]:
			nodes[str(id)].next.append("landing")
	nodes["landing"] = {"id": "landing", "depth": to, "x": 0.5, "kind": "landing", "hidden": false, "next": [], "warden": run_is_warden(state, to)}
	state.map = {"from": from, "to": to, "nodes": nodes, "rows": rows, "at": "", "lit_to": from}

static func row_of(map: Dictionary, depth: int) -> Array:
	var index: int = depth - int(map.get("from", 0)) - 1
	var rows: Array = map.get("rows", [])
	if index >= 0 and index < rows.size():
		return rows[index]
	if depth == int(map.get("to", -1)):
		return ["landing"]
	return []

static func revealed(state: Dictionary, node: Dictionary) -> bool:
	## Whether the party can see what a charted chamber holds.
	if str(node.get("kind", "")) == "landing":
		return true
	if int(node.get("depth", 0)) <= lit_to(state):
		return true
	if bool(node.get("hidden", false)):
		return false
	return int(node.get("depth", 0)) <= int(state.depth) + LANTERN_REACH

static func lit_to(state: Dictionary) -> int:
	var map: Dictionary = state.get("map", {})
	var lit_to: int = int(map.get("lit_to", int(map.get("from", 0))))
	if bool(map.get("lit", false)):
		lit_to = maxi(lit_to, int(map.get("from", 0)) + 1)
	return lit_to

static func needs_light(state: Dictionary) -> bool:
	var map: Dictionary = state.get("map", {})
	if map.is_empty():
		return false
	var target_depth: int = mini(int(state.get("depth", 0)) + 1, int(map.get("to", 0)))
	if target_depth <= lit_to(state):
		return false
	for id in row_of(map, target_depth):
		var node: Dictionary = map.get("nodes", {}).get(str(id), {})
		if bool(node.get("hidden", false)):
			return true
	return false

static func glint(node: Dictionary) -> String:
	## What an unlit chamber gives away: "hostile", "glittering", "strange", or "dark" for a dark mouth.
	if bool(node.get("hidden", false)):
		return "dark"
	return str(GLINTS.get(str(node.get("kind", "")), "strange"))

static func lantern_cost() -> int:
	return int(DeepContent.constant("lantern_ore_cost", 10))

static func _light(state: Dictionary, unit: Dictionary) -> Dictionary:
	if not str(state.phase) in ["tunnels", "landing"]:
		return _refuse("there is no way ahead to light")
	var map: Dictionary = state.get("map", {})
	if map.is_empty() or int(map.get("to", 0)) <= int(state.depth):
		return _refuse("the way ahead is not charted yet")
	var target_depth: int = mini(int(state.depth) + 1, int(map.get("to", 0)))
	if lit_to(state) >= target_depth:
		return _refuse("the next floor is already lit")
	if not needs_light(state):
		return _refuse("there are no dark mouths on the next floor")
	if int(unit.get("ore", 0)) < lantern_cost():
		return _refuse("not enough pyrite")
	unit.ore = int(unit.ore) - lantern_cost()
	map.lit_to = target_depth
	return {"ok": true, "event": _event(state, "lit", {"unit": unit.id, "method": "ore", "to": target_depth})}

static func _close_vote(state: Dictionary) -> Dictionary:
	## Once everyone still in the party has voted, a way is drawn and the party goes down it.
	## Returns the chamber's own event, or {} while someone has yet to vote.
	for other in living(state):
		if str(other.get("vote", "")).is_empty():
			return {}
	var streams: Dictionary = streams_of(state)
	var winner: String = _tally(state, streams.tunnels)
	state.rng = DeepRng.save(streams)
	for candidate in state.offers:
		if str(candidate.id) == winner:
			streams = streams_of(state)
			var entered: Dictionary = _enter(state, candidate, streams)
			state.rng = DeepRng.save(streams)
			return entered
	return {}

static func _tally(state: Dictionary, rng: RandomNumberGenerator) -> String:
	## Every vote is a ticket in a hat and one is drawn: more votes make a way likelier, and
	## a split party is a coin toss rather than the host's say.
	var tickets: Array = []
	for unit in living(state):
		if not str(unit.get("vote", "")).is_empty():
			tickets.append(str(unit.vote))
	return "" if tickets.is_empty() else str(tickets[rng.randi_range(0, tickets.size() - 1)])

static func _enter(state: Dictionary, offer: Dictionary, streams: Dictionary) -> Dictionary:
	state.depth = int(state.depth) + 1
	state.records.deepest = maxi(int(state.records.deepest), int(state.depth))
	state.offers = []
	state.aftermath = {}
	var kind: String = str(offer.get("kind", "fight"))
	## The way the party came, one entry per depth, for the shaft map.
	if not state.has("path"):
		state.path = []
	var map: Dictionary = state.get("map", {})
	var node: Dictionary = map.get("nodes", {}).get(str(offer.get("id", "")), {})
	var lane: float = float(node.get("x", 0.5))
	if not node.is_empty():
		map.at = str(node.id)
	state.path.append({"depth": int(state.depth), "kind": kind, "hidden": bool(offer.get("hidden", false)), "x": lane, "id": str(node.get("id", ""))})
	if kind == "landing":
		return _arrive_landing(state, streams)
	state.phase = "chamber"
	state.chamber = {"kind": kind, "depth": state.depth, "settled": false}
	match kind:
		"fight", "elite":
			return _start_fight(state, streams, kind == "elite", "")
		"vein":
			_dig_vein(state, streams, false)
		"motherlode":
			_dig_hollow(state)
		"merchant":
			_open_stall(state, streams)
		"oddity", "smithy", "carver", "vat", "well":
			var key: String = room_card(kind)
			if kind == "oddity":
				## The cards that belong to a room of their own never turn up by chance.
				var pool: Array = DeepContent.section("oddities").keys().filter(func(k: Variant) -> bool: return str(DeepContent.oddity(str(k)).get("room", "")).is_empty())
				pool.sort()
				var fresh: Array = pool.filter(func(k: Variant) -> bool: return not state.used_oddities.has(str(k)))
				if fresh.is_empty():
					fresh = pool
				key = str(DeepRng.pick(streams.oddities, fresh))
				state.used_oddities.append(key)
			state.chamber.oddity = key
			state.chamber.results = {}
			## What the card has to have to hand before anybody chooses (the Collector's case),
			## and what it remembers about each player while they work at it (the Idol's grip).
			state.chamber.offer = DeepOddities.offer_for(DeepContent.oddity(key), streams.oddities, mine_of(state), int(state.depth), str(state.run_id))
			state.chamber.tries = {}
			for unit in state.players:
				unit.oddity_choice = ""
	return _event(state, "enter_chamber", {"depth": state.depth, "chamber": state.chamber.duplicate(true)})

# --- fights ------------------------------------------------------------------------------

static func _start_fight(state: Dictionary, streams: Dictionary, elite: bool, warden: String) -> Dictionary:
	var mine: Dictionary = mine_of(state)
	var party: Array = living(state)
	var threat: int = int(state.depth) + int(state.get("heat", 0))
	var keys: Array = [warden] if not warden.is_empty() else DeepForge.encounter(streams.creatures, mine, threat, party.size(), elite)
	var fighters: Array = []
	for unit in state.players:
		var fighter: Dictionary = unit.duplicate(true)
		fighter.gold = 0
		fighter.quality_bonus = 0
		fighter.stone_drops = 0
		fighter.pot = 0
		fighter.gem_buffs = {}
		fighter.rank_buff = {"carat": 0, "cut": 0}
		fighter.pyrite_delta = 0
		fighters.append(fighter)
	## An endless mine's Wardens are remembered bosses: each comes back with one trait more.
	var remembered: bool = not warden.is_empty() and bool(mine.get("endless", false)) and warden != str(mine.get("unmade", ""))
	var battle: Dictionary = DeepBattle.begin(fighters, keys, {"depth": int(state.depth), "threat": threat, "scale": creature_scale(mine, int(state.depth)),
		"elite": elite, "warden": not warden.is_empty(), "remembered": remembered}, streams.dice, streams.creatures)
	## Soft Rock: a staked player's first fights open against creatures already cracked.
	var soft: bool = false
	for unit in state.players:
		if int(unit.get("run_mods", {}).get("soft_rock", 0)) > 0 and not bool(unit.get("downed", false)):
			unit.run_mods.soft_rock = int(unit.run_mods.soft_rock) - 1
			soft = true
	if soft:
		for foe in battle.enemies:
			foe.hp = maxi(1, int(foe.hp) / 2)
	state.chamber.battle = battle
	state.chamber.kind = "warden" if not warden.is_empty() else ("elite" if elite else "fight")
	state.records.fights = int(state.records.fights) + 1
	return _event(state, "battle_begin", {"depth": state.depth, "creatures": keys, "elite": elite, "warden": warden, "soft_rock": soft})

static func creature_scale(mine: Dictionary, depth: int) -> Dictionary:
	## How much tougher a mine breeds its creatures than the Quarry does. An endless mine
	## keeps compounding: its growth is per Warden's worth of floors, counted smoothly.
	var hp: float = float(mine.get("hp_mult", 1.0))
	var damage: float = float(mine.get("damage_mult", 1.0))
	if bool(mine.get("endless", false)):
		var growth: Dictionary = mine.get("growth", {})
		var spans: float = float(maxi(0, depth - 1)) / float(warden_every(mine))
		hp *= pow(float(growth.get("hp", 1.0)), spans)
		damage *= pow(float(growth.get("damage", 1.0)), spans)
	return {"hp": hp, "damage": damage}

static func in_battle(state: Dictionary) -> bool:
	return str(state.get("phase", "")) == "chamber" and state.get("chamber", {}).get("battle", null) is Dictionary and not bool(state.chamber.get("settled", false))

static func battle(state: Dictionary) -> Dictionary:
	return state.chamber.battle if in_battle(state) else {}

static func step(state: Dictionary) -> Dictionary:
	## Advance a resolving fight by one step, and settle the chamber when the fight ends.
	if not in_battle(state):
		return {}
	var streams: Dictionary = streams_of(state)
	var b: Dictionary = state.chamber.battle
	var event: Dictionary = DeepBattle.step(b, streams.dice, streams.creatures)
	state.rng = DeepRng.save(streams)
	if event.is_empty():
		return {}
	_sync_fighters(state)
	var wrapped: Dictionary = _event(state, "battle", {"battle": event})
	if str(event.kind) == "battle_over":
		wrapped.settle = _settle_fight(state, str(b.outcome))
	return wrapped

static func _sync_fighters(state: Dictionary) -> void:
	## HP, block and what the fight earned flow back to the run's players as it goes.
	var b: Dictionary = state.chamber.get("battle", {})
	for fighter in b.get("players", []):
		var unit: Dictionary = player(state, str(fighter.id))
		if unit.is_empty():
			continue
		unit.hp = int(fighter.hp)
		unit.max_hp = int(fighter.max_hp)
		unit.dice = fighter.dice.duplicate(true)
		unit.haul = fighter.get("haul", []).duplicate(true)
		unit.downed = bool(fighter.get("downed", false))
		unit.stats.damage = int(unit.stats.get("damage", 0))

static func _settle_fight(state: Dictionary, outcome: String) -> Dictionary:
	var streams: Dictionary = streams_of(state)
	var b: Dictionary = state.chamber.battle
	var kind: String = str(state.chamber.kind)
	state.chamber.settled = true
	var settle: Dictionary = {"outcome": outcome, "kind": kind, "rewards": {}}
	for fighter in b.players:
		var unit: Dictionary = player(state, str(fighter.id))
		unit.hp = int(fighter.hp)
		unit.max_hp = int(fighter.max_hp)
		## What the creatures did to the bowl for the fight ends with it.
		unit.dice = DeepBattle.dice_after_fight(fighter)
		unit.haul = fighter.get("haul", []).duplicate(true)
		unit.downed = bool(fighter.get("downed", false))
		unit.block = 0
		unit.statuses = {}
		unit.stats.fights = int(unit.stats.get("fights", 0)) + 1
		unit.stats.damage = int(unit.stats.get("damage", 0)) + int(fighter.get("dealt", 0)) + int(fighter.get("dealt_last_turn", 0))
		unit.sparkle = clampi(int(fighter.get("sparkle", 0)), 0, DeepRules.SPARKLE_MAX_STACKS)
		unit.hand = []
		var spending: int = int(fighter.get("pyrite_delta", 0))
		if outcome == "victory":
			## Everything the Gambler had on the table comes back to him for winning the hand.
			## Lose the fight and it stays on it: staking already took it out of the bank, and
			## nothing here puts it back.
			spending += int(fighter.get("pot", 0))
			## A Gambler's Bust can leave the fight's ore in the red; the pit never charges more than it paid.
			var ore: int = maxi(0, int(DeepContent.constant("ore_per_fight", 6)) + int(state.depth) + int(fighter.get("gold", 0)))
			if kind == "elite":
				ore *= 2
			if kind == "warden":
				ore *= 3
			# Prices and refunds stay exact, even in elite/warden encounters.
			ore += spending
			unit.ore = maxi(0, int(unit.ore) + ore)
			unit.stats.ore = int(unit.stats.get("ore", 0)) + ore
			DeepEconomy.earned(unit, ore)
			var reward: Dictionary = {"ore": ore, "stones": []}
			if kind != "warden":
				var drops: Dictionary = DeepContent.constant("stone_drop_pct", {"fight": 55, "elite": 100})
				var chance: float = float(drops.get(kind, 55)) + float(fighter.get("quality_bonus", 0)) / 2.0
				if DeepRng.chance(streams.stones, chance):
					var bonus: int = (int(DeepContent.constant("elite_stone_luck", 3)) if kind == "elite" else 0) + int(fighter.get("quality_bonus", 0)) / 10
					reward.stones.append(_find_stone(state, unit, streams, bonus, kind))
			## A Royal Flush drops a stone of its own, Exquisite or better, warden or not.
			for _drop in range(int(fighter.get("stone_drops", 0))):
				reward.stones.append(_find_stone(state, unit, streams, 8, "birthstone", "EXQUISITE"))
			## A Hoard Mimic's belly: a raw stone for whoever opened it.
			for _drop in range(int(fighter.get("raw_drops", 0))):
				reward.stones.append(_find_stone(state, unit, streams, 2, "mimic"))
			settle.rewards[unit.id] = reward
		else:
			# Unbanked fight earnings are lost; bank-funded spending is still paid.
			unit.ore = maxi(0, int(unit.ore) + mini(0, spending))
	state.rng = DeepRng.save(streams)
	if outcome == "defeat":
		_start_salvage(state)
		settle.salvage = state.salvage.duplicate(true)
		return settle
	if kind == "warden":
		state.records.wardens.append(int(state.depth))
		if run_is_boss(state, int(state.depth)):
			state.records.boss = true
		state.landing.cleared = true
		state.landing.warden_next = false
		_offer_hoard(state)
		settle.hoard = true
		return settle
	state.aftermath = settle.rewards.duplicate(true)
	var onward: Dictionary = streams_of(state)
	_offer_tunnels(state, onward)
	state.rng = DeepRng.save(onward)
	return settle

static func _find_stone(state: Dictionary, unit: Dictionary, streams: Dictionary, bonus: int, source: String, min_tier: String = "") -> Dictionary:
	## One raw stone into a player's haul. All stored Sparkle is spent on this find, at
	## SPARKLE_LUCK a point of luck apiece, so a full hundred stacks is worth eight points.
	## `min_tier` names the lowest grade that will do: the wheel spins again, a dozen times
	## at most, until it lands.
	var extra: float = float(bonus) + float(clampi(int(unit.get("sparkle", 0)), 0, DeepRules.SPARKLE_MAX_STACKS)) * DeepRules.SPARKLE_LUCK
	unit.sparkle = 0
	var provenance: Dictionary = {"run": str(state.run_id), "source": source, "finder": str(unit.id), "seat": int(unit.get("seat", 0))}
	var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine_of(state), int(state.depth), extra, provenance, _id(state, "st"))
	if not min_tier.is_empty():
		var wanted: int = DeepStone.TIERS.find(min_tier)
		var tries: int = 0
		while tries < 12 and DeepStone.TIERS.find(str(DeepStone.grade(stone).tier)) < wanted:
			tries += 1
			var again: Dictionary = DeepForge.roll_stone(streams.stones, mine_of(state), int(state.depth), extra + tries * 4, provenance, str(stone.id))
			if int(DeepStone.grade(again).score) >= int(DeepStone.grade(stone).score):
				stone = again
	unit.haul.append(stone)
	unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
	state.records.stones_found = int(state.records.stones_found) + 1
	return stone

# --- veins -------------------------------------------------------------------------------

static func hollow_cost(swings: int) -> int:
	## What breaking the next of your rocks in a glittering hollow costs.
	return (maxi(0, swings) + 1) * VEIN_HP_BASE

static func swing_cost(state: Dictionary, unit: Dictionary) -> int:
	## What this player's next blow costs in the room they are standing in.
	var vein: Dictionary = state.get("chamber", {}).get("vein", {})
	if bool(vein.get("hollow", false)):
		return hollow_cost(int(unit.get("strikes", 0)))
	return strike_cost(int(unit.get("strikes", 0)), bool(vein.get("hazard", false)))

static func _dig_hollow(state: Dictionary) -> void:
	## Every lapidary standing gets their own shining rocks, a stone in each. Nobody can break
	## anyone else's.
	var spots: Array = []
	for unit in state.players:
		unit.strikes = 0
		unit.mining = not bool(unit.get("downed", false))
		if not bool(unit.mining):
			continue
		for _rock in range(HOLLOW_ROCKS):
			spots.append({"index": spots.size(), "kind": "stone", "glint": "bright", "owner": str(unit.id), "taken": "", "result": {},
				"hardness": 1, "struck": 0})
	state.chamber.vein = {"spots": spots, "hazard": false, "hollow": true}

static func strike_cost(swings: int, hazard: bool) -> int:
	## What the next swing costs, given how many have already been taken at this outcrop: the
	## first is free and each one after it costs a point more, so the question is never
	## whether to swing but how many more times.
	return maxi(0, swings) * VEIN_HP_BASE + (VUG_HP if hazard else 0)

static func spot_hardness(rng: RandomNumberGenerator, kind: String, glint: String) -> int:
	## How many swings the rock over a find takes before it gives it up.
	var band: Array = VEIN_HARDNESS.get(glint if kind == "stone" else kind, [1, 1])
	return rng.randi_range(int(band[0]), int(band[1]))

static func _dig_vein(state: Dictionary, streams: Dictionary, hazard: bool) -> void:
	var rng: RandomNumberGenerator = streams.tunnels
	var spots: Array = []
	for index in range(VEIN_SPOTS):
		var kind: String = DeepRng.weighted_key(rng, {"stone": 42 if not hazard else 60, "ore": 38, "nothing": 20 if not hazard else 10})
		var glint: String = "dull"
		if kind == "stone":
			glint = "bright" if DeepRng.chance(rng, 35.0) else "glint"
		spots.append({"index": index, "kind": kind, "glint": glint, "taken": "", "result": {},
			"hardness": spot_hardness(rng, kind, glint), "struck": 0})
	state.chamber.vein = {"spots": spots, "hazard": hazard}
	for unit in state.players:
		unit.strikes = 0
		unit.mining = not bool(unit.get("downed", false))

static func _vein_settles(state: Dictionary) -> bool:
	## The outcrop is done with when nobody is still swinging at it, or when there is nothing
	## left in it to swing at.
	var spots: Array = state.chamber.get("vein", {}).get("spots", [])
	var open: bool = false
	for s in spots:
		if str(s.get("taken", "")).is_empty():
			open = true
	if not open:
		return true
	for other in living(state):
		if bool(other.get("mining", false)):
			return false
	return true

static func _settle_vein(state: Dictionary, event: Dictionary) -> Dictionary:
	if not _vein_settles(state):
		return {"ok": true, "event": event}
	_close_chamber(state)
	event.finished = true
	return {"ok": true, "event": event}

static func _close_chamber(state: Dictionary) -> void:
	## The room is done with: the ways on open. Charting draws on the tunnels stream, so the
	## streams it drew from are saved.
	state.chamber.settled = true
	var streams: Dictionary = streams_of(state)
	_offer_tunnels(state, streams)
	state.rng = DeepRng.save(streams)

static func _stop_mining(state: Dictionary, unit: Dictionary) -> Dictionary:
	if str(state.chamber.get("kind", "")) not in ROCK_ROOMS or not state.chamber.has("vein"):
		return _refuse("there is no rock to walk away from")
	if not bool(unit.get("mining", false)):
		return _refuse("you have already put the pick down")
	unit.mining = false
	return _settle_vein(state, _event(state, "vein_done", {"unit": unit.id, "swings": int(unit.get("strikes", 0))}))

static func _strike(state: Dictionary, unit: Dictionary, spot_index: int) -> Dictionary:
	if str(state.chamber.get("kind", "")) not in ROCK_ROOMS or not state.chamber.has("vein"):
		return _refuse("there is no rock to strike here")
	if not bool(unit.get("mining", false)):
		return _refuse("you have put the pick down")
	var spots: Array = state.chamber.vein.spots
	if spot_index < 0 or spot_index >= spots.size():
		return _refuse("no such spot")
	var spot: Dictionary = spots[spot_index]
	if not str(spot.get("taken", "")).is_empty():
		return _refuse("someone already struck there")
	if spot.has("owner") and str(spot.owner) != str(unit.id):
		return _refuse("those rocks are someone else's")
	var hollow: bool = bool(state.chamber.vein.get("hollow", false))
	var hazard: bool = bool(state.chamber.vein.get("hazard", false))
	var cost: int = swing_cost(state, unit)
	if int(unit.hp) - cost <= 0:
		return _refuse("another swing would finish you")
	var streams: Dictionary = streams_of(state)
	unit.strikes = int(unit.get("strikes", 0)) + 1
	unit.hp = maxi(1, int(unit.hp) - cost)
	spot.struck = int(spot.get("struck", 0)) + 1
	var through: bool = int(spot.struck) >= int(spot.get("hardness", 1))
	var fields: Dictionary = {"unit": unit.id, "spot": spot_index, "struck": int(spot.struck),
		"hardness": int(spot.get("hardness", 1)), "hp_cost": cost, "swings": int(unit.strikes),
		"next_cost": swing_cost(state, unit), "through": through, "result": {}}
	if not through:
		## The pick bites and the rock holds: nothing comes out of it yet.
		state.rng = DeepRng.save(streams)
		return {"ok": true, "event": _event(state, "vein_strike", fields)}
	spot.taken = str(unit.id)
	var result: Dictionary = {"kind": str(spot.kind)}
	match str(spot.kind):
		"stone":
			result.stone = _find_stone(state, unit, streams, 3 if str(spot.glint) == "bright" else 0, "motherlode" if hollow else "vein")
		"ore":
			var ore: int = 4 + int(state.depth) + streams.tunnels.randi_range(0, 4)
			unit.ore = int(unit.ore) + ore
			unit.stats.ore = int(unit.stats.get("ore", 0)) + ore
			DeepEconomy.earned(unit, ore)
			result.ore = ore
	spot.result = result
	state.rng = DeepRng.save(streams)
	fields.result = result.duplicate(true)
	if hollow and state.chamber.vein.spots.all(func(other: Dictionary) -> bool: return str(other.get("owner", "")) != str(unit.id) or not str(other.get("taken", "")).is_empty()):
		## Every one of their rocks is broken: nothing left for this pick.
		unit.mining = false
	return _settle_vein(state, _event(state, "vein_strike", fields))

# --- oddities, smithies and carvers -------------------------------------------------------
##
## An oddity is a card drawn at random; a smithy and a carver are rooms that always hold the
## same card. Each player makes one choice from the card, and the tunnels open once all have.

static func room_card(kind: String) -> String:
	## The card a room of this kind always holds, or "" when it holds none of its own.
	var keys: Array = DeepContent.section("oddities").keys()
	keys.sort()
	for key in keys:
		if str(DeepContent.oddity(str(key)).get("room", "")) == kind:
			return str(key)
	return ""

static func _choose_oddity(state: Dictionary, unit: Dictionary, choice_id: String, payload: Dictionary) -> Dictionary:
	if not str(state.chamber.get("kind", "")) in ["oddity"] + CARD_ROOMS or str(state.chamber.get("oddity", "")).is_empty():
		return _refuse("there is no oddity here")
	if not str(unit.get("oddity_choice", "")).is_empty():
		return _refuse("you have already chosen")
	var oddity: Dictionary = DeepContent.oddity(str(state.chamber.oddity))
	var choice: Dictionary = {}
	for candidate in oddity.get("choices", []):
		if str(candidate.get("id", "")) == choice_id:
			choice = candidate
	if choice.is_empty():
		return _refuse("no such choice")
	var streams: Dictionary = streams_of(state)
	var result: Dictionary = DeepOddities.apply(choice.get("action", {"kind": "none"}), unit, payload, streams.oddities,
		{"mine": mine_of(state), "depth": int(state.depth), "run": str(state.run_id), "party": state.players.size(),
		"offer": state.chamber.get("offer", {}), "tries": state.chamber.get("tries", {}).get(str(unit.id), {})})
	if not result.ok:
		return _refuse(str(result.error))
	state.rng = DeepRng.save(streams)
	if result.has("tries"):
		if not state.chamber.has("tries"):
			state.chamber.tries = {}
		state.chamber.tries[str(unit.id)] = result.tries
	if bool(result.get("again", false)):
		## The work is not done and the room is not finished with them: no choice is recorded,
		## so the card comes back up with the same hand on it.
		return {"ok": true, "event": _event(state, "oddity_result", {"unit": unit.id, "choice": choice_id, "message": str(result.message),
			"made": [], "lost": [], "changed": [], "dice": [], "again": true, "tries": result.tries.duplicate()})}
	unit.oddity_choice = choice_id
	for made in result.get("made", []):
		unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
		state.records.stones_found = int(state.records.stones_found) + 1
	state.chamber.results[unit.id] = {"choice": choice_id, "message": str(result.message), "made": result.get("made", []), "lost": result.get("lost", []),
		"changed": result.get("changed", []), "dice": result.get("dice", [])}
	var event: Dictionary = _event(state, "oddity_result", {"unit": unit.id, "choice": choice_id, "message": str(result.message),
		"made": result.get("made", []).duplicate(true), "lost": result.get("lost", []), "changed": result.get("changed", []).duplicate(true),
		"dice": result.get("dice", []).duplicate(true)})
	for extra in ["verdict", "well", "revealed", "hp_lost", "bought"]:
		if result.has(extra):
			event[extra] = result[extra]
			state.chamber.results[unit.id][extra] = result[extra]
	if _close_oddity(state):
		event.finished = true
	return {"ok": true, "event": event}

static func _close_oddity(state: Dictionary) -> bool:
	## The card is put away once everyone still in the party has made their choice from it.
	for other in living(state):
		if str(other.get("oddity_choice", "")).is_empty():
			return false
	_close_chamber(state)
	return true

# --- the bench -------------------------------------------------------------------------------
##
## Setting stones, reordering dice and handing stones to an ally happen whenever there is no
## fight on: in the tunnels, in a chamber before or after its business, at a landing.

static func bench_open(state: Dictionary) -> bool:
	return not str(state.get("phase", "")) in ["over", "salvage"] and not in_battle(state)

static func socket_refusal(unit: Dictionary, stone: Dictionary, index: int) -> String:
	## Why this stone cannot go in this socket, or "" when it can. The bench asks the same
	## question to light the sockets a dragged stone would fit.
	##
	## A socket is cut for a colour and it keeps to it, at home and down the mine alike. An
	## ANY socket takes anything, an opal fits only an ANY socket, and Zoning and Alexandrite say
	## for themselves what else a stone counts as. A Void gem takes no socket at all: it
	## rides one, any one of any colour, beside whatever is set there, and fires right after
	## it; so the only things that can refuse it are its weight and a Knot holding it where it
	## is. Two stones of one skill may both be set: down the mine they are two different
	## stones, cut and weighed differently, and which of them is worth a socket is the
	## player's question rather than the rail's.
	var rail: Array = unit.get("rail", [])
	if index < 0 or index >= rail.size():
		return "no such socket"
	if stone.is_empty():
		return "no such stone"
	if not bool(stone.get("appraised", false)):
		return "an unappraised stone cannot be set"
	var riding: bool = DeepStone.is_slotless(stone)
	var sockets: Array = unit.get("sockets", [])
	var socket_color: String = str(sockets[index]) if index < sockets.size() else DeepContent.SOCKET_ANY
	if not riding and not DeepStone.fits(stone, socket_color):
		return "that socket is cut for %s" % str(DeepContent.color(socket_color).get("name", socket_color)).to_lower()
	var character: Dictionary = DeepContent.character(str(unit.get("character", "")))
	var carat_cap: int = int(character.get("carat_max", 0))
	if carat_cap > 0 and int(stone.get("carat", 1)) > carat_cap:
		return "%s takes nothing heavier than %d carats" % [str(character.get("name", "this character")), carat_cap]
	for other in DeepStone.rail_stones(unit):
		if str(other.id) == str(stone.id) and DeepStone.is_locked(other):
			return "a Knot cannot leave its socket"
	var current: Variant = rail[index]
	if not riding and current is Dictionary and str(current.id) != str(stone.id) and DeepStone.is_locked(current):
		return "a Knot cannot leave its socket"
	return ""

static func _rail_event(state: Dictionary, unit: Dictionary) -> Dictionary:
	return {"ok": true, "event": _event(state, "rail_changed", {"unit": unit.id, "rail": unit.rail.duplicate(true), "riders": unit.get("riders", []).duplicate(true)})}

static func _socket(state: Dictionary, unit: Dictionary, stone_id: String, index: int, at: int = -1) -> Dictionary:
	## Set a stone in a socket, or, for a Void gem, ride one: into that socket's line of
	## riders at `at`, or at the end of it when `at` is not given.
	var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
	var refusal: String = socket_refusal(unit, stone, index)
	if not refusal.is_empty():
		return _refuse(refusal)
	if DeepStone.is_slotless(stone):
		## Out of the bag, or off whatever it rode before; a move earlier in its own line
		## lands before the gem it was dropped on, not after it.
		var was: Dictionary = DeepStone.rider_place(unit, stone_id)
		var before: int = DeepStone.riders_of(unit, index).size()
		DeepOddities.remove_stone(unit, stone_id)
		DeepStone.normalize_rail(unit)
		var line: Array = unit.riders[index]
		var to: int = line.size() if at < 0 else clampi(at, 0, before)
		if at >= 0 and not was.is_empty() and int(was.socket) == index and int(was.at) < to:
			to -= 1
		line.insert(clampi(to, 0, line.size()), stone)
		return _rail_event(state, unit)
	var current: Variant = unit.rail[index]
	## Take the stone out of wherever it was.
	var from_socket: int = -1
	for i in range(unit.rail.size()):
		if unit.rail[i] is Dictionary and str(unit.rail[i].id) == stone_id:
			from_socket = i
	if from_socket >= 0:
		## Two sockets simply swap: whatever was here goes to where the stone came from.
		unit.rail[from_socket] = current
	else:
		for i in range(unit.haul.size()):
			if str(unit.haul[i].id) == stone_id:
				unit.haul.remove_at(i)
				break
		if current is Dictionary:
			unit.haul.append(current)
	unit.rail[index] = stone
	return _rail_event(state, unit)

static func _unsocket(state: Dictionary, unit: Dictionary, index: int, stone_id: String = "") -> Dictionary:
	## A stone off the rail and into the bag: the gem in socket `index`, or, by id, any
	## stone on the rail, riding or set.
	if not stone_id.is_empty():
		var place: Dictionary = DeepStone.rider_place(unit, stone_id)
		if not place.is_empty():
			var rider: Dictionary = unit.riders[int(place.socket)][int(place.at)]
			if DeepStone.is_locked(rider):
				return _refuse("a Knot cannot leave its socket")
			unit.riders[int(place.socket)].remove_at(int(place.at))
			unit.haul.append(rider)
			return _rail_event(state, unit)
		index = -1
		for i in range(unit.rail.size()):
			if unit.rail[i] is Dictionary and str(unit.rail[i].id) == stone_id:
				index = i
	if index < 0 or index >= unit.rail.size() or not unit.rail[index] is Dictionary:
		return _refuse("nothing there")
	if DeepStone.is_locked(unit.rail[index]):
		return _refuse("a Knot cannot leave its socket")
	unit.haul.append(unit.rail[index])
	unit.rail[index] = null
	return _rail_event(state, unit)

static func _swap_die(state: Dictionary, unit: Dictionary, index: int, die_id: String) -> Dictionary:
	## Two of the five change places. They are the five a player came down with: dice are
	## worked at a smithy or a carver, never swapped for others.
	if index < 0 or index >= unit.dice.size():
		return _refuse("no such die slot")
	for i in range(unit.dice.size()):
		if str(unit.dice[i].id) == die_id:
			if i == index:
				return _refuse("that die is already there")
			var here: Dictionary = unit.dice[index]
			unit.dice[index] = unit.dice[i]
			unit.dice[i] = here
			return {"ok": true, "event": _event(state, "dice_changed", {"unit": unit.id, "dice": unit.dice.duplicate(true)})}
	return _refuse("only your own five dice change places")

# --- the trading table -----------------------------------------------------------------------
##
## A landing in a party has a table beside the fire, the bench and the well: the one place a
## stone changes hands. Two lapidaries sit down at it, each puts exactly one loose stone from
## their bag on it, and when both have said yes to what the other put down the two stones swap.
## Trading is free: it is not the landing's respite, so it can be done before or after the
## fire, the bench or the well. But each lapidary trades once a landing: one swap, and the
## table is done with them until the next one. Until both have accepted either may take their
## stone back, or change it, which takes back both acceptances.

static func can_trade(state: Dictionary) -> bool:
	## The table stands only where there is someone to trade with, and only at a landing that
	## has its respites: a Warden's hall has none.
	return state.get("players", []).size() > 1 and _has_respites(state)

static func has_traded(state: Dictionary, unit_id: String) -> bool:
	## This lapidary has made their one trade at this landing.
	return not state.get("landing", {}).get("trades", {}).get(unit_id, []).is_empty()

static func trade_table(state: Dictionary) -> Dictionary:
	return state.get("landing", {}).get("trade", {"offers": {}, "accepted": []})

static func trade_partner(state: Dictionary, unit_id: String) -> String:
	## Who else is sitting at the table with this player, or "".
	for id in trade_table(state).get("offers", {}):
		if str(id) != unit_id:
			return str(id)
	return ""

static func _trade_offer(state: Dictionary, unit: Dictionary, stone_id: String) -> Dictionary:
	if has_traded(state, str(unit.id)):
		return _refuse("you have made your trade at this landing")
	var stone: Dictionary = {}
	for held in unit.get("haul", []):
		if str(held.get("id", "")) == stone_id:
			stone = held
	if stone.is_empty():
		return _refuse("only a loose stone from your bag can be put on the table")
	if bool(state.get("marks_lent", false)) and is_lent(state, stone):
		## It would go home with neither of them: the vault it came from keeps the stone itself.
		return _refuse("that is a copy of a stone in your vault: only stones found down here change hands")
	var table: Dictionary = trade_table(state)
	var offers: Dictionary = table.get("offers", {}).duplicate()
	if not offers.has(str(unit.id)) and offers.size() >= 2:
		return _refuse("two are already trading at the table")
	offers[str(unit.id)] = stone_id
	state.landing.trade = {"offers": offers, "accepted": []}
	return {"ok": true, "event": _event(state, "trade_offer", {"unit": unit.id, "stone": stone.duplicate(true)})}

static func _trade_withdraw(state: Dictionary, unit: Dictionary) -> Dictionary:
	var offers: Dictionary = trade_table(state).get("offers", {}).duplicate()
	if not offers.has(str(unit.id)):
		return _refuse("you have nothing on the table")
	offers.erase(str(unit.id))
	state.landing.trade = {"offers": offers, "accepted": []}
	return {"ok": true, "event": _event(state, "trade_withdraw", {"unit": unit.id})}

static func _trade_accept(state: Dictionary, unit: Dictionary) -> Dictionary:
	var table: Dictionary = trade_table(state)
	var offers: Dictionary = table.get("offers", {})
	var partner_id: String = trade_partner(state, str(unit.id))
	if not offers.has(str(unit.id)) or partner_id.is_empty():
		return _refuse("a trade wants a stone from each of you")
	if has_traded(state, str(unit.id)) or has_traded(state, partner_id):
		return _refuse("one trade each at a landing")
	var accepted: Array = table.get("accepted", []).duplicate()
	if not accepted.has(str(unit.id)):
		accepted.append(str(unit.id))
	state.landing.trade = {"offers": offers.duplicate(), "accepted": accepted}
	if not accepted.has(partner_id):
		return {"ok": true, "event": _event(state, "trade_accept", {"unit": unit.id})}
	## Both have said yes: the stones cross the table.
	var partner: Dictionary = player(state, partner_id)
	var mine: Dictionary = _take_from_haul(unit, str(offers[str(unit.id)]))
	var theirs: Dictionary = _take_from_haul(partner, str(offers[partner_id]))
	if mine.is_empty() or theirs.is_empty():
		## One of them is no longer in its bag: put back whatever came out and clear the table.
		if not mine.is_empty():
			unit.haul.append(mine)
		if not theirs.is_empty():
			partner.haul.append(theirs)
		state.landing.trade = {"offers": {}, "accepted": []}
		return _refuse("a stone on the table is no longer in its bag")
	unit.haul.append(theirs)
	partner.haul.append(mine)
	## What each of them did here, for the landing to say back to them.
	if not state.landing.has("trades"):
		state.landing.trades = {}
	for pair in [[unit, theirs, mine], [partner, mine, theirs]]:
		var said: Array = state.landing.trades.get(str(pair[0].id), [])
		said.append("You traded %s for %s." % [_said(pair[2]), _said(pair[1])])
		state.landing.trades[str(pair[0].id)] = said
	state.landing.trade = {"offers": {}, "accepted": []}
	return {"ok": true, "event": _event(state, "traded", {"units": [unit.id, partner.id], "stones": {str(unit.id): mine.duplicate(true), partner_id: theirs.duplicate(true)}})}

static func _said(stone: Dictionary) -> String:
	return DeepStone.name(stone) if bool(stone.get("appraised", false)) else DeepStone.raw_name(stone)

static func _take_from_haul(unit: Dictionary, stone_id: String) -> Dictionary:
	for i in range(unit.get("haul", []).size()):
		if str(unit.haul[i].get("id", "")) == stone_id:
			var stone: Dictionary = unit.haul[i]
			unit.haul.remove_at(i)
			return stone
	return {}

# --- merchants -------------------------------------------------------------------------------
##
## A merchant is a chamber of its own: a stall of appraised stones, a die of their own size,
## a pair of hands that buys an appraised stone for half its worth, and a lens that appraises
## a raw one for ore, dearer each time the same player asks at the same stall. Nothing is
## shared: every player is shown their own stock, so four people at one stall see four
## different stalls. Each leaves when done; the tunnels open once everyone has.

static func _open_stall(state: Dictionary, streams: Dictionary) -> void:
	var mine: Dictionary = mine_of(state)
	var stock: Dictionary = {}
	for unit in state.players:
		var theirs: Array = []
		for _i in range(MERCHANT_STONES):
			var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine, int(state.depth), 2, {"run": str(state.run_id), "source": "merchant"}, _id(state, "st"))
			_reveal(stone)
			theirs.append({"id": _id(state, "item"), "kind": "stone", "stone": stone, "price": DeepStone.value(stone) * 2, "sold": ""})
		## And one die, in a size they already carry: a die they could not swap in is no offer.
		for _i in range(MERCHANT_DICE):
			var sizes: Array = unit.get("dice", []).map(func(d: Dictionary) -> String: return str(d.get("shape", "")))
			var die: Dictionary = DeepForge.roll_die(streams.stones, mine, int(state.depth), _id(state, "die"), sizes)
			theirs.append({"id": _id(state, "item"), "kind": "die", "die": die, "price": DeepForge.die_price(die), "sold": ""})
		stock[str(unit.id)] = theirs
	state.chamber.stock = stock
	state.chamber.appraisals = {}
	for unit in state.players:
		unit.ready = false

static func stall_stock(state: Dictionary, unit_id: String) -> Array:
	## What this player is shown at this stall. Older saves kept one shared list.
	var stock: Variant = state.get("chamber", {}).get("stock", {})
	if stock is Dictionary:
		return stock.get(unit_id, [])
	return stock if stock is Array else []

static func at_stall(state: Dictionary) -> bool:
	return str(state.get("phase", "")) == "chamber" and str(state.get("chamber", {}).get("kind", "")) == "merchant" and not bool(state.chamber.get("settled", false))

static func appraise_cost(state: Dictionary, unit_id: String) -> int:
	## What the lens costs this player at this stall: dearer every time they ask.
	var uses: int = int(state.get("chamber", {}).get("appraisals", {}).get(unit_id, 0))
	return int(DeepContent.constant("appraise_ore_cost", 50)) + uses * int(DeepContent.constant("appraise_cost_step", 50))

static func _reveal(stone: Dictionary) -> void:
	stone.appraised = true
	stone.inclusions_revealed = true

static func _raw_in_haul(unit: Dictionary, stone_id: String) -> Dictionary:
	for stone in unit.get("haul", []):
		if str(stone.get("id", "")) == stone_id:
			return stone if not bool(stone.get("appraised", false)) else {}
	return {}

static func _appraise(state: Dictionary, unit: Dictionary, stone_id: String) -> Dictionary:
	var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
	if stone.is_empty():
		return _refuse("no such stone")
	if bool(stone.get("appraised", false)):
		return _refuse("it is already appraised")
	var cost: int = appraise_cost(state, str(unit.id))
	if int(unit.get("ore", 0)) < cost:
		return _refuse("not enough pyrite")
	unit.ore = int(unit.ore) - cost
	state.chamber.appraisals[str(unit.id)] = int(state.chamber.appraisals.get(str(unit.id), 0)) + 1
	_reveal(stone)
	return {"ok": true, "event": _event(state, "appraised", {"unit": unit.id, "stone": stone.duplicate(true), "method": "ore", "paid": cost,
		"next": appraise_cost(state, str(unit.id))})}

static func _buy(state: Dictionary, unit: Dictionary, item_id: String, payload: Dictionary = {}) -> Dictionary:
	var item: Dictionary = {}
	for candidate in stall_stock(state, str(unit.id)):
		if str(candidate.id) == item_id:
			item = candidate
	if item.is_empty():
		return _refuse("no such item")
	if not str(item.get("sold", "")).is_empty():
		return _refuse("already sold")
	if int(unit.get("ore", 0)) < int(item.price):
		return _refuse("not enough pyrite")
	if str(item.get("kind", "stone")) == "die":
		## A die is swapped, never added: the bowl is always five, and only a die of the same
		## number of faces can take another one place.
		var swap_id: String = str(payload.get("die_id", ""))
		var at: int = -1
		for index in range(unit.get("dice", []).size()):
			if str(unit.dice[index].get("id", "")) == swap_id:
				at = index
		if at < 0:
			return _refuse("choose one of your own dice to trade in")
		if str(unit.dice[at].get("shape", "")) != str(item.die.get("shape", "")):
			return _refuse("a die is only swapped for one of the same size")
		unit.ore = int(unit.ore) - int(item.price)
		item.sold = str(unit.id)
		var bought: Dictionary = item.die.duplicate(true)
		var gone: Dictionary = unit.dice[at]
		unit.dice[at] = bought
		return {"ok": true, "event": _event(state, "bought", {"unit": unit.id, "item": item.duplicate(true), "ore": unit.ore,
			"die": bought.duplicate(true), "traded": gone.duplicate(true), "dice": unit.dice.duplicate(true)})}
	unit.ore = int(unit.ore) - int(item.price)
	item.sold = str(unit.id)
	var stone: Dictionary = item.stone.duplicate(true)
	stone.provenance.finder = str(unit.id)
	unit.haul.append(stone)
	return {"ok": true, "event": _event(state, "bought", {"unit": unit.id, "item": item.duplicate(true), "ore": unit.ore})}

static func _sell(state: Dictionary, unit: Dictionary, stone_id: String) -> Dictionary:
	var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
	if stone.is_empty():
		return _refuse("no such stone")
	if DeepStone.is_fragile(stone):
		return _refuse("fragile stones cannot be sold")
	if DeepStone.is_locked(stone):
		return _refuse("a Knot cannot leave its socket")
	## A stone nobody has read still sells: the buyer pays for its size class and nothing
	## else, which is always the worse end of what it might have been worth.
	var paid: int = DeepStone.sell_value(stone)
	DeepOddities.remove_stone(unit, stone_id)
	unit.ore = int(unit.ore) + paid
	DeepEconomy.earned(unit, paid)
	return {"ok": true, "event": _event(state, "sold", {"unit": unit.id, "stone_id": stone_id, "ore": unit.ore, "paid": paid})}

static func _leave_stall(state: Dictionary, unit: Dictionary) -> Dictionary:
	if bool(unit.get("ready", false)):
		return _refuse("you have already left the stall")
	unit.ready = true
	var event: Dictionary = _event(state, "left_stall", {"unit": unit.id})
	if _close_stall(state):
		event.finished = true
	return {"ok": true, "event": event}

static func _close_stall(state: Dictionary) -> bool:
	## The stall packs up once everyone still in the party has walked away from it.
	for other in living(state):
		if not bool(other.get("ready", false)):
			return false
	_close_chamber(state)
	return true

# --- landings --------------------------------------------------------------------------------
##
## A landing is solid ground and a lift. Each player takes one respite there: rest (a share
## of their health back), appraise (one raw stone from the haul, free), or the well (a stone
## or a measure of pyrite thrown down it, for whatever it cares to send back). Then the party
## votes: up the lift with everything, or on down. A Warden's hall is the one landing with
## none of it: no fire, no bench, no well and no cage was ever sunk there. The hoard is shared out and
## the only way on is down, to the next lift.

static func _arrive_landing(state: Dictionary, streams: Dictionary) -> Dictionary:
	state.phase = "landing"
	state.chamber = {}
	for unit in state.players:
		unit.choice = ""
		unit.via = ""
		unit.respite = ""
		unit.ready = false
		if bool(unit.get("downed", false)):
			unit.downed = false
			unit.hp = maxi(int(unit.hp), int(ceil(float(unit.max_hp) * 0.25)))
	state.landing = {"depth": int(state.depth), "warden_next": run_is_warden(state, int(state.depth)), "cleared": false, "respites": {}}
	## The stretch below is charted now, so the landing can show the way on.
	_chart(state, streams)
	return _event(state, "landing", {"depth": state.depth, "landing": state.landing.duplicate(true)})

static func _has_respites(state: Dictionary) -> bool:
	## A Warden's hall has the hoard and nothing else: nothing to rest at and no cage.
	return not bool(state.get("landing", {}).get("cleared", false))

static func rest_amount(unit: Dictionary) -> int:
	## What resting gives back: a share of the most health, never past it.
	var share: int = int(ceil(float(unit.get("max_hp", 0)) * float(DeepContent.constant("rest_pct", 30)) / 100.0))
	return clampi(int(unit.get("max_hp", 0)) - int(unit.get("hp", 0)), 0, share)

static func can_wish(stone: Dictionary) -> bool:
	## What the landing's well will take: any stone that is yours to give up. A birthstone is
	## not — it came down with you and it goes back up with you — a Knot will not leave its
	## socket, and a fragile stone (a temporary one, a Void, a staked find) was never yours to
	## turn into anything that could come home.
	return not DeepStone.is_birthstone(stone) and not DeepStone.is_locked(stone) and not DeepStone.is_fragile(stone)

static func _respite(state: Dictionary, unit: Dictionary, choice: String, stone_id: String, ore: int = 0) -> Dictionary:
	if not str(unit.get("respite", "")).is_empty():
		return _refuse("you have taken your respite")
	## A stone on the trading table that goes down the well, or under the lens, comes off it:
	## it is no longer the stone the other side said yes to.
	if not stone_id.is_empty() and str(trade_table(state).get("offers", {}).get(str(unit.id), "")) == stone_id:
		_trade_withdraw(state, unit)
	var fields: Dictionary = {"unit": unit.id, "choice": choice}
	match choice:
		"rest":
			var gained: int = rest_amount(unit)
			unit.hp = int(unit.hp) + gained
			fields.healed = gained
			fields.message = "You rest by the lift and recover %d health." % gained
		"appraise":
			var stone: Dictionary = _raw_in_haul(unit, stone_id)
			if stone.is_empty():
				return _refuse("choose a raw stone from your haul")
			_reveal(stone)
			fields.stone = stone.duplicate(true)
			fields.message = "You appraise the stone under the lift's lamp."
		"wish":
			## A well was sunk beside every landing, and it is the same well as the one in the
			## shaft: it weighs what goes down it and answers in kind.
			var streams: Dictionary = streams_of(state)
			var worth: float = 0.0
			var said: String = ""
			if stone_id.is_empty():
				var spent: int = clampi(ore, WISH_LEAST, WISH_MOST)
				if int(unit.get("ore", 0)) < spent:
					return _refuse("you have not the pyrite to throw in")
				unit.ore = int(unit.ore) - spent
				worth = float(spent)
				said = "%d pyrite goes down into the dark." % spent
			else:
				var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
				if stone.is_empty() or not can_wish(stone):
					return _refuse("choose a stone you can part with")
				worth = DeepOddities.well_worth(stone, 0.5, 1.5)
				said = "%s goes down into the water." % (DeepStone.name(stone) if bool(stone.get("appraised", false)) else DeepStone.raw_name(stone))
				fields.stone = stone.duplicate(true)
				DeepOddities.remove_stone(unit, stone_id)
			var rung: int = DeepOddities.well_rung(streams.oddities, worth)
			var prize: Dictionary = DeepOddities.well_prize(streams.oddities, rung, unit, mine_of(state), int(state.depth), str(state.run_id))
			state.rng = DeepRng.save(streams)
			for made in prize.get("made", []):
				unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
				state.records.stones_found = int(state.records.stones_found) + 1
			fields.made = prize.get("made", []).duplicate(true)
			fields.well = DeepOddities.well_summary(rung, worth, prize)
			fields.message = "%s %s" % [said, str(prize.get("message", ""))]
		_:
			return _refuse("rest, appraise or the well")
	unit.respite = choice
	state.landing.respites[str(unit.id)] = fields.duplicate(true)
	return {"ok": true, "event": _event(state, "respite", fields)}

static func lift_cost(state: Dictionary) -> int:
	## What the winch wants to haul the party up from this depth: so much a depth, a share for
	## every living body in the cage. Riding up early is cheap; riding up loaded is not. The
	## rope runs all the way back to the workshop, so a party that has pushed on from one mine
	## into the next pays for every floor of the mines above as well.
	var floors: int = int(state.get("depth", 1)) + int(state.get("carried", 0))
	return roundi(float(DeepContent.constant("lift_ore_per_depth", 10.5)) * maxi(1, floors) * maxi(1, living(state).size()))

static func is_conquered(state: Dictionary) -> bool:
	## A mine is yours if its final boss is dead and you got out with the news: this mine's,
	## or one the party came down through on the way.
	if bool(state.get("records", {}).get("boss", false)):
		return true
	for done in state.get("mines_done", []):
		if bool(done.get("boss", false)):
			return true
	return false

static func in_boss_hall(state: Dictionary) -> bool:
	## The final boss is dead and the party stands in its hall: the one hall with a cage in it,
	## and the one with a way on into the next mine.
	var landing: Dictionary = state.get("landing", {})
	return bool(landing.get("cleared", false)) and run_is_boss(state, int(landing.get("depth", -1))) and int(landing.get("depth", -1)) == int(state.get("depth", 0))

static func next_mine(state: Dictionary) -> String:
	return str(mine_of(state).get("next", ""))

static func _party_ore(state: Dictionary) -> int:
	var total: int = 0
	for unit in living(state):
		total += int(unit.get("ore", 0))
	return total

static func _pay_for_lift(state: Dictionary) -> Dictionary:
	## An even share each, and whatever a light pocket cannot cover comes off whoever still has
	## it. The cage only has to be paid for once, not evenly.
	var riders: Array = living(state)
	var owed: int = lift_cost(state)
	var paid: Dictionary = {}
	var share: int = owed / maxi(1, riders.size())
	for unit in riders:
		var take: int = mini(int(unit.get("ore", 0)), mini(share, owed))
		unit.ore = int(unit.ore) - take
		paid[str(unit.id)] = take
		owed -= take
	for unit in riders:
		if owed <= 0:
			break
		var take: int = mini(int(unit.get("ore", 0)), owed)
		unit.ore = int(unit.ore) - take
		paid[str(unit.id)] = int(paid.get(str(unit.id), 0)) + take
		owed -= take
	return paid

static func _choose_at_landing(state: Dictionary, unit: Dictionary, choice: String, via: String = "") -> Dictionary:
	## A landing asks one question at a time. The cage stands beside the fire, the bench and
	## the well, and any of the four may be walked up to first; but the moment a respite is
	## taken the cage is behind you and the only way left is down. A Warden's hall has no cage
	## in it at all: whatever came out of the hoard has to be carried down to the next landing
	## before it can be ridden home.
	if not choice in ["lift", "descend"]:
		return _refuse("lift or descend")
	var landing: Dictionary = state.get("landing", {})
	var boss_hall: bool = in_boss_hall(state)
	var hall: bool = bool(landing.get("cleared", false)) and not boss_hall
	## A respite is taken at a landing before its Warden is fought. The bottom of a mine is
	## that same landing with the boss dead in it and a cage sunk beside the hoard: the respite
	## taken before the fight does not shut the cage that the fight opened.
	var rested: bool = not str(unit.get("respite", "")).is_empty() and not boss_hall
	if choice == "lift" and hall:
		return _refuse("no cage was ever sunk into a Warden's hall: the way on is down")
	if choice == "descend" and boss_hall and next_mine(state).is_empty():
		return _refuse("this is the bottom of the mine: the only way is up")
	if choice == "descend" and not rested and _has_respites(state):
		return _refuse("take your respite first: the fire, the bench or the well")
	if choice == "lift" and rested:
		return _refuse("you have taken your respite: the way on is down")
	if choice == "lift" and _party_ore(state) < lift_cost(state):
		return _refuse("the winch wants %d pyrite to lift the party from this depth" % lift_cost(state))
	unit.choice = choice
	## Which of the mouths they went down by, if they chose one: only that mouth shows them.
	unit.via = via if choice == "descend" else ""
	var event: Dictionary = _event(state, "landing_choice", {"unit": unit.id, "choice": choice, "via": str(unit.via)})
	_close_landing(state, event)
	return {"ok": true, "event": event}

static func _close_landing(state: Dictionary, event: Dictionary) -> bool:
	## Once everyone still in the party has said up or down, the party goes the way most of
	## them chose (a tie goes the way the first of them did), and `event` says where.
	var lifts: int = 0
	var descends: int = 0
	var party: Array = living(state)
	if party.is_empty():
		return false
	for other in party:
		match str(other.get("choice", "")):
			"": return false
			"lift": lifts += 1
			"descend": descends += 1
	var ride: bool = lifts > descends or (lifts == descends and str(party[0].get("choice", "")) == "lift")
	if ride and _party_ore(state) < lift_cost(state):
		## The winch was affordable when the lift was chosen, but the purse has shrunk since:
		## someone took their pyrite down a well, or left the party with it. Nobody rides on
		## credit. Whoever chose the cage chooses again, and is told why.
		for other in party:
			if str(other.get("choice", "")) == "lift":
				other.choice = ""
		event.lift_short = {"cost": lift_cost(state), "have": _party_ore(state)}
		return false
	var streams: Dictionary = streams_of(state)
	if ride:
		event.paid = _pay_for_lift(state)
		_finish(state, "conquered" if is_conquered(state) else "extracted")
		event.finished = str(state.outcome)
	elif in_boss_hall(state):
		event.next_mine = _push_on(state, streams)
		state.rng = DeepRng.save(streams)
		event.tunnels = true
	elif bool(state.landing.get("warden_next", false)):
		state.phase = "chamber"
		state.chamber = {"kind": "warden", "depth": state.depth, "settled": false}
		var opened: Dictionary = _start_fight(state, streams, false, warden_key(state, int(state.depth)))
		state.rng = DeepRng.save(streams)
		event.battle = opened
	else:
		_offer_tunnels(state, streams)
		state.rng = DeepRng.save(streams)
		event.tunnels = true
	return true

static func _push_on(state: Dictionary, streams: Dictionary) -> String:
	## Down out of a beaten mine and into the one below it. Everything carried comes along —
	## the rail, the haul, the purse, the wounds — and nothing is banked: a fall down here
	## loses both mines' finds. The new mine starts from its own top floor, its creatures
	## bred a little deeper for every mine the party has pushed through. Returns the mine left.
	var leaving: String = str(state.mine)
	state.mines_done.append(mine_record(state))
	state.carried = int(state.get("carried", 0)) + int(state.depth)
	state.heat = int(state.get("heat", 0)) + int(DeepContent.constant("chain_heat", 2))
	state.mine = next_mine(state)
	state.depth = 0
	state.records.deepest = 0
	state.records.wardens = []
	state.records.boss = false
	state.path = []
	state.map = {}
	state.landing = {}
	state.schedule = plan_shaft(streams.tunnels, mine_of(state))
	for unit in state.players:
		unit.choice = ""
		unit.respite = ""
	_offer_tunnels(state, streams)
	return leaving

static func mine_record(state: Dictionary) -> Dictionary:
	## What the party did in the mine it is in: how deep, which Wardens, and the boss.
	var records: Dictionary = state.get("records", {})
	return {"mine": str(state.get("mine", "")), "deepest": int(records.get("deepest", 0)), "wardens": records.get("wardens", []).duplicate(),
		"boss": bool(records.get("boss", false))}

# --- hoard, salvage, endings ---------------------------------------------------------------

static func _offer_hoard(state: Dictionary) -> void:
	## Three stones on their pedestals, and, in the middle of the three, an opal: the only thing in the
	## mine that no vein and no drop ever offers. Every one of them comes out of the Warden's
	## hoard still in its rock, so a pedestal says only a colour and a size class: the choice
	## is three gambles on what is inside, and the loupe settles it afterwards. The opal is
	## the rare colour, not the rich one: it comes out of the rock with less luck behind it
	## than the other two, so it is generally the smaller, rougher stone of the three.
	var streams: Dictionary = streams_of(state)
	state.phase = "hoard"
	state.hoard = {}
	var opals: Array = DeepForge.opal_pool()
	var opal_pct: float = float(DeepContent.constant("opal_hoard_pct", 100))
	var luck: float = float(DeepContent.constant("hoard_luck", 5))
	var opal_luck: float = float(DeepContent.constant("opal_hoard_luck", 0))
	for unit in state.players:
		## Whoever went down in the fight is carried past the pedestals: the hoard is for those
		## still standing, and the one on the floor gets back up at the next landing.
		if bool(unit.get("downed", false)):
			continue
		var offers: Array = []
		for index in range(HOARD_OFFERS):
			var opal: bool = index == HOARD_OFFERS / 2 and not opals.is_empty() and DeepRng.chance(streams.stones, opal_pct)
			var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine_of(state), int(state.depth), opal_luck if opal else luck, {"run": str(state.run_id), "source": "hoard", "finder": str(unit.id)}, _id(state, "st"), opals if opal else [])
			stone.appraised = false
			stone.inclusions_revealed = false
			offers.append(stone)
		state.hoard[unit.id] = {"offers": offers, "chosen": ""}
	state.rng = DeepRng.save(streams)

static func _pick_hoard(state: Dictionary, unit: Dictionary, stone_id: String) -> Dictionary:
	if str(state.phase) != "hoard":
		return _refuse("there is no hoard to pick from")
	if not state.hoard.has(str(unit.id)):
		return _refuse("you were down when the hoard was opened")
	var mine_hoard: Dictionary = state.hoard.get(str(unit.id), {})
	if not str(mine_hoard.get("chosen", "")).is_empty():
		return _refuse("you have chosen")
	for stone in mine_hoard.get("offers", []):
		if str(stone.id) == stone_id:
			mine_hoard.chosen = stone_id
			## Nothing on the pile has been read: it goes into the bag in its rock like any
			## other find, and a stall or a landing opens it.
			var raw: bool = not bool(stone.get("appraised", false))
			unit.haul.append(stone)
			unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
			var event: Dictionary = _event(state, "hoard_pick", {"unit": unit.id, "stone": stone.duplicate(true), "raw": raw})
			if _close_hoard(state):
				event.landing = true
			return {"ok": true, "event": event}
	return _refuse("no such stone in the hoard")

static func _close_hoard(state: Dictionary) -> bool:
	## The pedestals are left behind once everyone still here has taken their stone. Nobody
	## who was down when it opened has any to take.
	for other in state.players:
		if not state.hoard.has(str(other.id)):
			continue
		if str(state.hoard.get(str(other.id), {}).get("chosen", "")).is_empty() and bool(other.get("connected", true)):
			return false
	state.phase = "landing"
	for other in state.players:
		other.choice = ""
		other.via = ""
	return true

static func _start_salvage(state: Dictionary) -> void:
	## A wipe. Every raw stone rolls a die by its grade and only the top face brings it home.
	var streams: Dictionary = streams_of(state)
	var dice: Dictionary = DeepContent.constant("salvage_dice", {"ROUGH": 4, "FINE": 6, "PRECIOUS": 8, "EXQUISITE": 10, "PEERLESS": 12})
	state.phase = "salvage"
	state.salvage = {}
	for unit in state.players:
		_shatter_fragile(unit)
		var rolls: Array = []
		var kept: Array = []
		## Insurance bought at the workshop throws every die twice and keeps the better throw.
		var insured: bool = bool(unit.get("insured", false))
		for stone in unit.haul:
			## A copy of a vault stone was never going home, and the vault's own is safe: there
			## is nothing to roll for, and nothing to show as lost.
			if bool(state.get("marks_lent", false)) and is_lent(state, stone):
				kept.append(stone)
				continue
			var tier: String = DeepStone.grade(stone).tier
			var sides: int = int(dice.get(tier, 6))
			var roll: int = streams.salvage.randi_range(1, sides)
			var first: int = roll
			var second: int = 0
			if insured:
				second = streams.salvage.randi_range(1, sides)
				roll = maxi(first, second)
			var survives: bool = roll == sides
			var entry: Dictionary = {"stone": stone.duplicate(true), "sides": sides, "roll": roll, "kept": survives, "tier": tier}
			if insured:
				entry.insured = true
				entry.first = first
				entry.second = second
			rolls.append(entry)
			if survives:
				kept.append(stone)
		unit.haul = kept
		unit.ready = false
		state.salvage[unit.id] = {"rolls": rolls}
	state.rng = DeepRng.save(streams)

static func _saw(state: Dictionary) -> void:
	## Every skill each player has come to know this run, written down as it happens. A stone
	## read under a lens is known from that moment whatever becomes of it, so one sold at a
	## stall, given away, left in a socket or lost to a wipe still counts towards the vault's
	## record of what the player has laid eyes on. Swept rather than hooked into each of the
	## dozen ways a stone changes hands, so nothing can be added later that forgets to call it.
	for unit in state.get("players", []):
		if not unit.has("seen"):
			unit.seen = []
		for stone in unit.get("haul", []) + DeepStone.rail_stones(unit):
			if not stone is Dictionary or not bool(stone.get("appraised", false)) or DeepStone.is_birthstone(stone):
				continue
			var skill: String = str(stone.get("skill", ""))
			if not skill.is_empty() and not unit.seen.has(skill):
				unit.seen.append(skill)

static func _shatter_fragile(unit: Dictionary) -> void:
	## Unread stones keep their secret until the workshop's loupe reveals it.
	if not unit.has("shattered"):
		unit.shattered = []
	for stone in unit.get("haul", []).duplicate() + DeepStone.rail_stones(unit):
		if stone is Dictionary and DeepStone.known_fragile(stone):
			if bool(stone.get("appraised", false)):
				if not unit.has("seen"):
					unit.seen = []
				if not unit.seen.has(str(stone.skill)):
					unit.seen.append(str(stone.skill))
			## A temporary stone was only ever lent for the run: it goes back without being
			## counted among the losses.
			if not bool(stone.get("temporary", false)):
				unit.shattered.append(stone.duplicate(true))
			DeepOddities.remove_stone(unit, str(stone.id))
	DeepStone.normalize_rail(unit)

static func _finish(state: Dictionary, outcome: String) -> void:
	_saw(state)
	for unit in state.players:
		_shatter_fragile(unit)
	state.phase = "over"
	state.outcome = outcome
	state.offers = []

static func is_lent(state: Dictionary, stone: Dictionary) -> bool:
	## A copy of one of the vault's stones, set on the rail when the run began. A run begun
	## before copies were marked tells them by where they were found: not on this run.
	if bool(state.get("marks_lent", false)):
		return bool(stone.get("lent", false))
	return str(stone.get("provenance", {}).get("run", "")) != str(state.get("run_id", ""))

static func coming_home(state: Dictionary, unit: Dictionary) -> Array:
	## Every stone a player found on this run and still carries comes home: the bag, and
	## whatever they set on the rail or let ride it along the way. A copy of a vault stone
	## never does, wherever it ended up: the vault has the stone itself. A run begun before
	## copies were marked brings its whole bag home, as it always did.
	var marked: bool = bool(state.get("marks_lent", false))
	var out: Array = []
	for stone in unit.get("haul", []):
		if stone is Dictionary and not (marked and is_lent(state, stone)):
			out.append(stone)
	for stone in DeepStone.rail_stones(unit):
		if stone is Dictionary and not is_lent(state, stone):
			out.append(stone)
	return out

static func results(state: Dictionary) -> Dictionary:
	## What each player takes home: the stones they found (`home`: the bag and whatever they
	## set on the rail), the dice, and what is left in the pocket with how much of it was
	## earned down there, for the assayer at the lift to weigh into gold.
	_saw(state)
	var mines: Array = state.get("mines_done", []).duplicate(true)
	mines.append(mine_record(state))
	var out: Dictionary = {"run_id": str(state.run_id), "mine": str(state.mine), "from_mine": str(state.get("from_mine", state.mine)), "outcome": str(state.outcome),
		"depth": int(state.depth), "deepest": int(state.records.deepest), "wardens": state.records.wardens.duplicate(), "mines": mines, "players": {}}
	for unit in state.players:
		out.players[str(unit.id)] = {"haul": unit.haul.duplicate(true), "home": coming_home(state, unit).duplicate(true), "dice": unit.bag_dice.duplicate(true), "stats": unit.stats.duplicate(true),
			"rail": unit.rail.duplicate(true), "riders": unit.get("riders", []).duplicate(true), "seen": unit.get("seen", []).duplicate(), "shattered": unit.get("shattered", []).duplicate(true),
			"ore": int(unit.get("ore", 0)), "earned": int(unit.get("stats", {}).get("earned", 0)), "insured": bool(unit.get("insured", false))}
	return out

# --- commands ----------------------------------------------------------------------------

static func command(state: Dictionary, player_id: String, cmd: Dictionary) -> Dictionary:
	## What everyone can already see is noted before anything moves (see `_saw`). A command
	## that is then refused takes the note back with it: a refusal is never sent to the party,
	## and the host's run would have changed under every guest's mirror without a word, so a
	## guest summing up the run from its mirror missed the skills noted that way.
	var noted: Dictionary = {}
	for unit in state.get("players", []):
		noted[str(unit.get("id", ""))] = unit.get("seen", []).size() if unit.has("seen") else -1
	var result: Dictionary = _command(state, player_id, cmd)
	if bool(result.get("ok", false)):
		for unit in state.get("players", []):
			DeepStone.normalize_rail(unit)
	else:
		for unit in state.get("players", []):
			var was: int = int(noted.get(str(unit.get("id", "")), -1))
			if was < 0:
				unit.erase("seen")
			elif unit.get("seen", []).size() > was:
				unit.seen.resize(was)
	return result

static func _command(state: Dictionary, player_id: String, cmd: Dictionary) -> Dictionary:
	## Every player action. Returns {ok, error} or {ok, event}.
	var unit: Dictionary = player(state, player_id)
	if unit.is_empty():
		return _refuse("no such player")
	## Before anything moves, note what everyone can already see. See `_saw`.
	_saw(state)
	var kind: String = str(cmd.get("kind", ""))
	var phase: String = str(state.get("phase", ""))
	if phase == "over":
		return _refuse("the run is over")
	## The fallen are carried, not consulted: nothing a room offers is theirs to take until a
	## landing has them back on their feet. Their own bench and the chart are still theirs.
	if bool(unit.get("downed", false)) and kind in DOWNED_CANNOT:
		return _refuse("you are down: the party carries you to the next landing")
	match kind:
		"stake":
			if phase != "grubstake":
				return _refuse("the stakes are taken at the shaft head")
			return _take_stake(state, unit, str(cmd.get("offer", "")), cmd.get("payload", {}))
		"temporary":
			if phase != "grubstake":
				return _refuse("temporary stones are taken at the shaft head")
			return _take_temporary(state, unit, int(cmd.get("index", -1)), int(cmd.get("pick", -1)))
		"dice_offer":
			if phase != "grubstake":
				return _refuse("dice are swapped at the shaft head")
			return _take_dice_offer(state, unit, int(cmd.get("index", -1)), int(cmd.get("pick", -1)))
		"vote_tunnel":
			if phase != "tunnels":
				return _refuse("no tunnels to choose")
			if bool(unit.get("downed", false)):
				return _refuse("the fallen do not choose the way")
			var offer: Dictionary = {}
			for candidate in state.offers:
				if str(candidate.id) == str(cmd.get("offer", "")):
					offer = candidate
			if offer.is_empty():
				return _refuse("no such tunnel")
			unit.vote = str(offer.id)
			var event: Dictionary = _event(state, "vote", {"unit": unit.id, "offer": offer.id})
			var entered: Dictionary = _close_vote(state)
			if not entered.is_empty():
				event.entered = entered
			return {"ok": true, "event": event}
		"reroll", "lock", "unlock", "target", "flip":
			if not in_battle(state):
				return _refuse("no fight here")
			var streams: Dictionary = streams_of(state)
			var result: Dictionary = DeepBattle.command(state.chamber.battle, player_id, cmd, streams.dice)
			state.rng = DeepRng.save(streams)
			if not result.ok:
				return result
			var event: Dictionary = _event(state, "battle", {"battle": result.event})
			if DeepBattle.ready_to_resolve(state.chamber.battle):
				event.resolution = DeepBattle.start_resolution(state.chamber.battle)
			return {"ok": true, "event": event}
		"stop_mining":
			if phase != "chamber":
				return _refuse("there is no rock to walk away from")
			return _stop_mining(state, unit)
		"strike":
			if phase != "chamber":
				return _refuse("no rock here")
			return _strike(state, unit, int(cmd.get("spot", -1)))
		"oddity":
			if phase != "chamber":
				return _refuse("no oddity here")
			return _choose_oddity(state, unit, str(cmd.get("choice", "")), cmd.get("payload", {}))
		"appraise":
			if not at_stall(state):
				return _refuse("stones are appraised at a merchant, or once at a landing")
			return _appraise(state, unit, str(cmd.get("stone_id", "")))
		"give":
			## Stones change hands only by trade now, one for one, at a landing's table.
			return _refuse("stones change hands only at a landing's trading table")
		"socket", "unsocket", "swap_die":
			if not bench_open(state):
				return _refuse("the bench waits until the fight is over")
			match kind:
				"socket": return _socket(state, unit, str(cmd.get("stone_id", "")), int(cmd.get("index", -1)), int(cmd.get("at", -1)))
				"unsocket": return _unsocket(state, unit, int(cmd.get("index", -1)), str(cmd.get("stone_id", "")))
			return _swap_die(state, unit, int(cmd.get("index", -1)), str(cmd.get("die_id", "")))
		"buy", "sell", "leave":
			if not at_stall(state):
				return _refuse("there is no merchant here")
			match kind:
				"buy": return _buy(state, unit, str(cmd.get("item_id", "")), cmd)
				"sell": return _sell(state, unit, str(cmd.get("stone_id", "")))
			return _leave_stall(state, unit)
		"respite":
			if phase != "landing":
				return _refuse("a respite is taken at a landing")
			return _respite(state, unit, str(cmd.get("choice", "")), str(cmd.get("stone_id", "")), int(cmd.get("ore", 0)))
		"trade_offer", "trade_withdraw", "trade_accept":
			if phase != "landing" or not can_trade(state):
				return _refuse("stones change hands at the trading table of a landing, in a party")
			match kind:
				"trade_offer": return _trade_offer(state, unit, str(cmd.get("stone_id", "")))
				"trade_withdraw": return _trade_withdraw(state, unit)
			return _trade_accept(state, unit)
		"choose":
			if phase != "landing":
				return _refuse("the lift is at the landing")
			return _choose_at_landing(state, unit, str(cmd.get("choice", "")), str(cmd.get("via", "")))
		"pick_hoard":
			return _pick_hoard(state, unit, str(cmd.get("stone_id", "")))
		"light":
			return _light(state, unit)
		"abandon":
			## Giving up the dig counts as a fall: every raw stone rolls its salvage die.
			if phase == "salvage":
				return _refuse("the dig is already lost")
			_start_salvage(state)
			state.abandoned = true
			state.offers = []
			state.chamber = {}
			return {"ok": true, "event": _event(state, "abandoned", {"unit": unit.id, "depth": int(state.depth)})}
		"ready":
			if phase != "salvage":
				return _refuse("nothing to acknowledge")
			unit.ready = true
			var event: Dictionary = _event(state, "ready", {"unit": unit.id})
			if _close_salvage(state):
				event.finished = "fallen"
			return {"ok": true, "event": event}
	return _refuse("unknown command " + kind)

static func _close_salvage(state: Dictionary) -> bool:
	## The reckoning is over once everyone still here has read theirs.
	for other in state.players:
		if not bool(other.get("ready", false)) and bool(other.get("connected", true)):
			return false
	_finish(state, "fallen")
	return true

static func settle_absent(state: Dictionary) -> Dictionary:
	## Every gate that waits on the whole party is checked when somebody acts. A player who
	## drops out while the rest are already waiting on them never acts again, so whoever
	## takes them out of the party checks the gate once more here: if everyone still in it
	## has done what it waits on, the party moves on without them. Returns the event that
	## says so, or {} while someone present has yet to act. A fight is the session's to start
	## resolving, so a fight in progress is left alone. Each gate counts whom it always has:
	## after a wipe everyone is down, and the reckoning still waits only on those present.
	if not state.get("players", []).any(func(p: Dictionary) -> bool: return bool(p.get("connected", true))):
		return {}
	var fields: Dictionary = {}
	match str(state.get("phase", "")):
		"grubstake":
			if _close_grubstake(state):
				fields.finished = true
		"tunnels":
			var entered: Dictionary = _close_vote(state)
			if not entered.is_empty():
				fields.entered = entered
		"chamber":
			var chamber: Dictionary = state.get("chamber", {})
			if in_battle(state) or bool(chamber.get("settled", false)):
				return {}
			var kind: String = str(chamber.get("kind", ""))
			if kind in ROCK_ROOMS and chamber.has("vein"):
				if _vein_settles(state):
					_close_chamber(state)
					fields.finished = true
			elif kind in ["oddity"] + CARD_ROOMS:
				if not str(chamber.get("oddity", "")).is_empty() and _close_oddity(state):
					fields.finished = true
			elif kind == "merchant":
				if _close_stall(state):
					fields.finished = true
		"landing":
			_close_landing(state, fields)
		"hoard":
			if _close_hoard(state):
				fields.landing = true
		"salvage":
			if _close_salvage(state):
				fields.finished = "fallen"
	if fields.is_empty():
		return {}
	return _event(state, "moved_on", fields)

static func set_connected(state: Dictionary, player_id: String, connected: bool) -> void:
	var unit: Dictionary = player(state, player_id)
	if not unit.is_empty():
		unit.connected = connected
		if in_battle(state):
			var fighter: Dictionary = DeepBattle.player(state.chamber.battle, player_id)
			if not fighter.is_empty():
				fighter.connected = connected

static func _event(state: Dictionary, kind: String, fields: Dictionary) -> Dictionary:
	state.seq = int(state.get("seq", 0)) + 1
	var event: Dictionary = {"kind": kind, "seq": state.seq, "phase": str(state.phase), "depth": int(state.depth)}
	event.merge(fields, true)
	return event

static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error}
