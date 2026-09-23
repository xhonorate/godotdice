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
##   every LANDING_EVERY depths: landing (a respite each: rest, appraise or the wheel; then up or down)
##   at warden depths the landing's gate is a warden fight; the hoard follows a win
##   a wipe → salvage → over (fallen);  the lift → over (extracted | conquered)
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
const HOARD_OFFERS: int = 3
const MERCHANT_STONES: int = 3
## Dice are never bought or swapped down the mine, only worked: a smithy makes one a size
## bigger or smaller, a carver recuts its faces. Each is a chamber holding one fixed card.
const DICE_ROOMS: Array = ["smithy", "carver"]
## Every room that holds one fixed card of its own rather than one drawn at random.
const CARD_ROOMS: Array = ["smithy", "carver", "well"]
const RESPITES: Array = ["rest", "appraise", "polish"]

# --- setup -------------------------------------------------------------------------------

static func new_run(config: Dictionary) -> Dictionary:
	## config: seed (int), mine (key), run_id, boons (bool, default true),
	##   players: [{id, name, character, rail: [stones|null], dice: [die instances], last_depth, last_outcome}]
	var seed_value: int = int(config.get("seed", randi()))
	var mine_key: String = str(config.get("mine", DeepContent.starter_mine()))
	var state: Dictionary = {"run_id": str(config.get("run_id", "run%08x" % seed_value)), "seed": seed_value, "mine": mine_key,
		"depth": 0, "phase": "tunnels", "outcome": "", "players": [], "offers": [], "chamber": {}, "landing": {},
		"hoard": {}, "salvage": {}, "aftermath": {}, "used_oddities": [], "path": [], "records": {"deepest": 0, "wardens": [], "stones_found": 0, "fights": 0},
		"rng": {}, "seq": 0, "next_id": 1}
	var streams: Dictionary = DeepRng.streams(seed_value)
	state.schedule = plan_shaft(streams.tunnels)
	var seat: int = 0
	for entry in config.get("players", []):
		var unit: Dictionary = DeepBattle.make_player(str(entry.get("id", "p%d" % seat)), str(entry.get("name", "Lapidary")), str(entry.get("character", DeepContent.starter_character())),
			entry.get("rail", []), entry.get("dice", []))
		unit.merge({"seat": seat, "haul": [], "bag_dice": [], "ore": 0, "vote": "", "seen": [],
			"choice": "", "respite": "", "ready": false, "strikes": 0, "mining": false, "oddity_choice": "", "stake": "", "last_depth": int(entry.get("last_depth", 0)),
			"last_outcome": str(entry.get("last_outcome", "")), "stats": {"damage": 0, "healing": 0, "stones": 0, "fights": 0, "ore": 0}}, true)
		state.players.append(unit)
		seat += 1
	state.rng = DeepRng.save(streams)
	if bool(config.get("boons", true)) and not DeepContent.section("boons").is_empty():
		_offer_grubstake(state, streams)
	else:
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
		"changed": result.get("changed", []).duplicate(true)})
	var everyone: bool = true
	for other in living(state):
		if str(other.get("stake", "")).is_empty():
			everyone = false
	if everyone:
		_offer_tunnels(state, streams_of(state))
		state.rng = DeepRng.save(streams_of(state))
		event.finished = true
	return {"ok": true, "event": event}

static func streams_of(state: Dictionary) -> Dictionary:
	return DeepRng.restore(state.get("rng", {}))

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

static func plan_shaft(rng: RandomNumberGenerator) -> Dictionary:
	## Where this run's lifts and Wardens actually stand. The written depths are only roughly
	## where they are: every landing wanders a floor either way and its Warden goes with it,
	## so nobody can count steps to the next one. That is the whole point — not knowing how
	## far the next lift is makes the lantern, and the ore that lights the way, worth having.
	## The bottom of the mine never moves: the last Warden is on the last floor.
	var every: int = landing_every()
	var bottom: int = int(DeepContent.constant("run_depth", 24))
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
	for written in DeepContent.constant("warden_depths", [8, 16, 24]):
		var which: int = int(round(float(written) / float(every))) - 1
		if which >= 0 and which < landings.size() and not wardens.has(int(landings[which])):
			wardens.append(int(landings[which]))
	return {"landings": landings, "wardens": wardens}

static func run_is_landing(state: Dictionary, depth: int) -> bool:
	## Past the bottom of the charted shaft — the Endless — the plain every-fourth rule is
	## back, because nothing down there was planned in advance.
	var listed: Array = state.get("schedule", {}).get("landings", [])
	if listed.is_empty() or depth > int(listed[listed.size() - 1]):
		return is_landing(depth)
	return listed.has(depth)

static func run_is_warden(state: Dictionary, depth: int) -> bool:
	var listed: Array = state.get("schedule", {}).get("wardens", [])
	if listed.is_empty():
		return is_warden_depth(depth)
	if listed.has(depth):
		return true
	return depth > int(DeepContent.constant("run_depth", 24)) and is_warden_depth(depth)

static func next_landing(state: Dictionary, depth: int) -> int:
	## The next lift down from here, as this run laid them out.
	for at in state.get("schedule", {}).get("landings", []):
		if int(at) > depth:
			return int(at)
	var every: int = landing_every()
	return (depth / every + 1) * every

static func is_warden_depth(depth: int) -> bool:
	var listed: Array = DeepContent.constant("warden_depths", [8, 16, 24])
	for d in listed:
		if int(d) == depth:
			return true
	var run_depth: int = int(DeepContent.constant("run_depth", 24))
	var every: int = maxi(1, int(DeepContent.constant("endless_warden_every", 8)))
	return depth > run_depth and (depth - run_depth) % every == 0

static func warden_key(state: Dictionary, depth: int) -> String:
	var wardens: Array = mine_of(state).get("wardens", [])
	if wardens.is_empty():
		return ""
	var listed: Array = state.get("schedule", {}).get("wardens", DeepContent.constant("warden_depths", [8, 16, 24]))
	var index: int = -1
	for i in range(listed.size()):
		if int(listed[i]) == depth:
			index = i
	if index < 0:
		index = wardens.size() - 1
	return str(wardens[mini(index, wardens.size() - 1)])

static func _id(state: Dictionary, prefix: String) -> String:
	state.next_id = int(state.get("next_id", 1)) + 1
	return "%s%d" % [prefix, state.next_id]

# --- tunnels -----------------------------------------------------------------------------
##
## Each stretch between landings is charted when the party reaches its head: a lattice of
## chambers, two mouths wide at the top and fanning out a mouth wider every depth, each
## chamber leading on to the two nearest below it so the ways split and rejoin without ever
## crossing. The tunnels offered are the ways on from where the party stands. The lantern
## shows what lies LANTERN_REACH depth ahead; past that a chamber is only a glint (hostile,
## glittering, strange), a dark mouth shows nothing at all, and lighting the way (paid in
## ore) shows the whole stretch down to the landing. Every stretch holds a merchant somewhere
## below its first depth, and a smithy or a carver on its last.

const MAP_WIDEST: int = 4
const LANTERN_REACH: int = 1
const GLINTS: Dictionary = {"fight": "hostile", "elite": "hostile", "warden": "hostile", "vein": "glittering", "motherlode": "glittering", "oddity": "strange",
	"merchant": "strange", "smithy": "strange", "carver": "strange", "well": "strange"}

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
	var weights: Dictionary = mine.get("chambers", {"fight": 48, "elite": 12, "vein": 18, "oddity": 14, "merchant": 8, "smithy": 6, "carver": 6, "well": 5})
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
	state.map = {"from": from, "to": to, "nodes": nodes, "rows": rows, "at": "", "lit": false}

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
	if bool(state.get("map", {}).get("lit", false)):
		return true
	if bool(node.get("hidden", false)):
		return false
	return int(node.get("depth", 0)) <= int(state.depth) + LANTERN_REACH

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
	if bool(map.get("lit", false)):
		return _refuse("the way is already lit")
	if int(unit.get("ore", 0)) < lantern_cost():
		return _refuse("not enough ore")
	unit.ore = int(unit.ore) - lantern_cost()
	map.lit = true
	return {"ok": true, "event": _event(state, "lit", {"unit": unit.id, "method": "ore", "to": int(map.to)})}

static func _tally(state: Dictionary) -> String:
	## Plurality; a tie goes to the lowest seat that voted.
	var counts: Dictionary = {}
	for unit in living(state):
		if not str(unit.get("vote", "")).is_empty():
			counts[str(unit.vote)] = int(counts.get(str(unit.vote), 0)) + 1
	var best: String = ""
	var best_count: int = 0
	for unit in living(state):
		var vote: String = str(unit.get("vote", ""))
		if not vote.is_empty() and int(counts[vote]) > best_count:
			best = vote
			best_count = int(counts[vote])
	return best

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
			for unit in living(state):
				var made: Array = []
				for _i in range(3):
					made.append(_find_stone(state, unit, streams, 3, "motherlode"))
				state.aftermath[unit.id] = {"stones": made, "ore": 0}
			state.chamber.settled = true
			_offer_tunnels(state, streams)
			var found: Dictionary = state.aftermath.duplicate(true)
			return _event(state, "motherlode", {"depth": state.depth, "rewards": found})
		"merchant":
			_open_stall(state, streams)
		"oddity", "smithy", "carver", "well":
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
			for unit in state.players:
				unit.oddity_choice = ""
	return _event(state, "enter_chamber", {"depth": state.depth, "chamber": state.chamber.duplicate(true)})

# --- fights ------------------------------------------------------------------------------

static func _start_fight(state: Dictionary, streams: Dictionary, elite: bool, warden: String) -> Dictionary:
	var mine: Dictionary = mine_of(state)
	var party: Array = living(state)
	var keys: Array = [warden] if not warden.is_empty() else DeepForge.encounter(streams.creatures, mine, int(state.depth), party.size(), elite)
	var fighters: Array = []
	for unit in state.players:
		var fighter: Dictionary = unit.duplicate(true)
		fighter.gold = 0
		fighter.quality_bonus = 0
		fighter.stone_drops = 0
		fighters.append(fighter)
	var battle: Dictionary = DeepBattle.begin(fighters, keys, {"depth": int(state.depth), "elite": elite, "warden": not warden.is_empty()}, streams.dice, streams.creatures)
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
		unit.downed = bool(fighter.get("downed", false))
		unit.block = 0
		unit.statuses = {}
		unit.stats.fights = int(unit.stats.get("fights", 0)) + 1
		unit.stats.damage = int(unit.stats.get("damage", 0)) + int(fighter.get("dealt", 0)) + int(fighter.get("dealt_last_turn", 0))
		unit.sparkle = int(fighter.get("sparkle", 0))
		unit.hand = []
		if outcome == "victory":
			## A Gambler's Bust can leave the fight's ore in the red; the pit never charges more than it paid.
			var ore: int = maxi(0, int(DeepContent.constant("ore_per_fight", 6)) + int(state.depth) + int(fighter.get("gold", 0)))
			if kind == "elite":
				ore *= 2
			if kind == "warden":
				ore *= 3
			unit.ore = int(unit.ore) + ore
			unit.stats.ore = int(unit.stats.get("ore", 0)) + ore
			var reward: Dictionary = {"ore": ore, "stones": []}
			if kind != "warden":
				var drops: Dictionary = DeepContent.constant("stone_drop_pct", {"fight": 55, "elite": 100})
				var chance: float = float(drops.get(kind, 55)) + float(fighter.get("quality_bonus", 0)) / 2.0
				if DeepRng.chance(streams.stones, chance):
					var bonus: int = (4 if kind == "elite" else 0) + int(fighter.get("quality_bonus", 0)) / 10
					reward.stones.append(_find_stone(state, unit, streams, bonus, kind))
			## A Royal Flush drops a stone of its own, Exquisite or better, warden or not.
			for _drop in range(int(fighter.get("stone_drops", 0))):
				reward.stones.append(_find_stone(state, unit, streams, 8, "birthstone", "EXQUISITE"))
			settle.rewards[unit.id] = reward
	state.rng = DeepRng.save(streams)
	if outcome == "defeat":
		_start_salvage(state)
		settle.salvage = state.salvage.duplicate(true)
		return settle
	if kind == "warden":
		state.records.wardens.append(int(state.depth))
		state.landing.cleared = true
		state.landing.warden_next = false
		_offer_hoard(state)
		settle.hoard = true
		return settle
	state.aftermath = settle.rewards.duplicate(true)
	_offer_tunnels(state, streams_of(state))
	return settle

static func _find_stone(state: Dictionary, unit: Dictionary, streams: Dictionary, bonus: int, source: String, min_tier: String = "") -> Dictionary:
	## One raw stone into a player's haul. Five Sparkles buy a grade. `min_tier` names the
	## lowest grade that will do: the wheel spins again, a dozen times at most, until it lands.
	var extra: int = bonus
	if int(unit.get("sparkle", 0)) >= 5:
		unit.sparkle = int(unit.sparkle) - 5
		extra += 5
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
	state.chamber.settled = true
	_offer_tunnels(state, streams_of(state))
	event.finished = true
	return {"ok": true, "event": event}

static func _stop_mining(state: Dictionary, unit: Dictionary) -> Dictionary:
	if str(state.chamber.get("kind", "")) not in ["vein", "vug"] or not state.chamber.has("vein"):
		return _refuse("there is no rock to walk away from")
	if not bool(unit.get("mining", false)):
		return _refuse("you have already put the pick down")
	unit.mining = false
	return _settle_vein(state, _event(state, "vein_done", {"unit": unit.id, "swings": int(unit.get("strikes", 0))}))

static func _strike(state: Dictionary, unit: Dictionary, spot_index: int) -> Dictionary:
	if str(state.chamber.get("kind", "")) not in ["vein", "vug"] or not state.chamber.has("vein"):
		return _refuse("there is no rock to strike here")
	if not bool(unit.get("mining", false)):
		return _refuse("you have put the pick down")
	var spots: Array = state.chamber.vein.spots
	if spot_index < 0 or spot_index >= spots.size():
		return _refuse("no such spot")
	var spot: Dictionary = spots[spot_index]
	if not str(spot.get("taken", "")).is_empty():
		return _refuse("someone already struck there")
	var hazard: bool = bool(state.chamber.vein.get("hazard", false))
	var cost: int = strike_cost(int(unit.get("strikes", 0)), hazard)
	if int(unit.hp) - cost <= 0:
		return _refuse("another swing would finish you")
	var streams: Dictionary = streams_of(state)
	unit.strikes = int(unit.get("strikes", 0)) + 1
	unit.hp = maxi(1, int(unit.hp) - cost)
	spot.struck = int(spot.get("struck", 0)) + 1
	var through: bool = int(spot.struck) >= int(spot.get("hardness", 1))
	var fields: Dictionary = {"unit": unit.id, "spot": spot_index, "struck": int(spot.struck),
		"hardness": int(spot.get("hardness", 1)), "hp_cost": cost, "swings": int(unit.strikes),
		"next_cost": strike_cost(int(unit.strikes), hazard), "through": through, "result": {}}
	if not through:
		## The pick bites and the rock holds: nothing comes out of it yet.
		state.rng = DeepRng.save(streams)
		return {"ok": true, "event": _event(state, "vein_strike", fields)}
	spot.taken = str(unit.id)
	var result: Dictionary = {"kind": str(spot.kind)}
	match str(spot.kind):
		"stone":
			result.stone = _find_stone(state, unit, streams, 3 if str(spot.glint) == "bright" else 0, "vein")
		"ore":
			var ore: int = 4 + int(state.depth) + streams.tunnels.randi_range(0, 4)
			unit.ore = int(unit.ore) + ore
			unit.stats.ore = int(unit.stats.get("ore", 0)) + ore
			result.ore = ore
	spot.result = result
	state.rng = DeepRng.save(streams)
	fields.result = result.duplicate(true)
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
		{"mine": mine_of(state), "depth": int(state.depth), "run": str(state.run_id), "party": state.players.size()})
	if not result.ok:
		return _refuse(str(result.error))
	state.rng = DeepRng.save(streams)
	unit.oddity_choice = choice_id
	for made in result.get("made", []):
		unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
		state.records.stones_found = int(state.records.stones_found) + 1
	state.chamber.results[unit.id] = {"choice": choice_id, "message": str(result.message), "made": result.get("made", []), "lost": result.get("lost", []),
		"changed": result.get("changed", []), "dice": result.get("dice", [])}
	var event: Dictionary = _event(state, "oddity_result", {"unit": unit.id, "choice": choice_id, "message": str(result.message),
		"made": result.get("made", []).duplicate(true), "lost": result.get("lost", []), "changed": result.get("changed", []).duplicate(true),
		"dice": result.get("dice", []).duplicate(true)})
	if bool(result.get("vug", false)):
		state.chamber.kind = "vug"
		_dig_vein(state, streams_of(state), true)
		state.rng = DeepRng.save(streams_of(state))
		event.vug = true
		return {"ok": true, "event": event}
	var everyone: bool = true
	for other in living(state):
		if str(other.get("oddity_choice", "")).is_empty():
			everyone = false
	if everyone:
		state.chamber.settled = true
		_offer_tunnels(state, streams_of(state))
		event.finished = true
	return {"ok": true, "event": event}

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
	## ANY socket takes anything, an opal fits every socket, and Zoning and Alexandrite say
	## for themselves what else a stone counts as.
	var rail: Array = unit.get("rail", [])
	if index < 0 or index >= rail.size():
		return "no such socket"
	if stone.is_empty():
		return "no such stone"
	if not bool(stone.get("appraised", false)):
		return "an unappraised stone cannot be set"
	var sockets: Array = unit.get("sockets", [])
	var socket_color: String = str(sockets[index]) if index < sockets.size() else DeepContent.SOCKET_ANY
	if not DeepStone.fits(stone, socket_color):
		return "that socket is cut for %s" % str(DeepContent.color(socket_color).get("name", socket_color)).to_lower()
	var character: Dictionary = DeepContent.character(str(unit.get("character", "")))
	var carat_cap: int = int(character.get("carat_max", 0))
	if carat_cap > 0 and int(stone.get("carat", 1)) > carat_cap:
		return "%s takes nothing heavier than %d carats" % [str(character.get("name", "this character")), carat_cap]
	for other in rail:
		if other is Dictionary and str(other.skill) == str(stone.skill) and str(other.id) != str(stone.id):
			return "one stone of each skill"
	var current: Variant = rail[index]
	if current is Dictionary and str(current.id) != str(stone.id) and DeepStone.is_locked(current):
		return "a Knot cannot leave its socket"
	for other in rail:
		if other is Dictionary and str(other.id) == str(stone.id) and DeepStone.is_locked(other):
			return "a Knot cannot leave its socket"
	return ""

static func _socket(state: Dictionary, unit: Dictionary, stone_id: String, index: int) -> Dictionary:
	var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
	var refusal: String = socket_refusal(unit, stone, index)
	if not refusal.is_empty():
		return _refuse(refusal)
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
	return {"ok": true, "event": _event(state, "rail_changed", {"unit": unit.id, "rail": unit.rail.duplicate(true)})}

static func _unsocket(state: Dictionary, unit: Dictionary, index: int) -> Dictionary:
	if index < 0 or index >= unit.rail.size() or not unit.rail[index] is Dictionary:
		return _refuse("nothing there")
	if DeepStone.is_locked(unit.rail[index]):
		return _refuse("a Knot cannot leave its socket")
	unit.haul.append(unit.rail[index])
	unit.rail[index] = null
	return {"ok": true, "event": _event(state, "rail_changed", {"unit": unit.id, "rail": unit.rail.duplicate(true)})}

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

static func _give(state: Dictionary, unit: Dictionary, to_id: String, item_id: String) -> Dictionary:
	var other: Dictionary = player(state, to_id)
	if other.is_empty() or str(other.id) == str(unit.id):
		return _refuse("choose another player")
	for i in range(unit.haul.size()):
		if str(unit.haul[i].id) == item_id:
			var stone: Dictionary = unit.haul[i]
			unit.haul.remove_at(i)
			other.haul.append(stone)
			return {"ok": true, "event": _event(state, "given", {"from": unit.id, "to": other.id, "stone": stone.duplicate(true)})}
	return _refuse("only stones in your haul can be given")

# --- merchants -------------------------------------------------------------------------------
##
## A merchant is a chamber of its own: a stall of appraised stones (never dice), a pair of
## hands that buys an appraised stone for half its worth, and a lens that appraises a raw one
## for ore, dearer each time the same player asks at the same stall. Each player leaves when
## done; the tunnels open once everyone has.

static func _open_stall(state: Dictionary, streams: Dictionary) -> void:
	var mine: Dictionary = mine_of(state)
	var stock: Array = []
	for _i in range(MERCHANT_STONES):
		var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine, int(state.depth), 2, {"run": str(state.run_id), "source": "merchant"}, _id(state, "st"))
		_reveal(stone)
		stock.append({"id": _id(state, "item"), "kind": "stone", "stone": stone, "price": DeepStone.value(stone) * 2, "sold": ""})
	state.chamber.stock = stock
	state.chamber.appraisals = {}
	for unit in state.players:
		unit.ready = false

static func at_stall(state: Dictionary) -> bool:
	return str(state.get("phase", "")) == "chamber" and str(state.get("chamber", {}).get("kind", "")) == "merchant" and not bool(state.chamber.get("settled", false))

static func appraise_cost(state: Dictionary, unit_id: String) -> int:
	## What the lens costs this player at this stall: dearer every time they ask.
	var uses: int = int(state.get("chamber", {}).get("appraisals", {}).get(unit_id, 0))
	return int(DeepContent.constant("appraise_ore_cost", 12)) + uses * int(DeepContent.constant("appraise_cost_step", 8))

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
		return _refuse("not enough ore")
	unit.ore = int(unit.ore) - cost
	state.chamber.appraisals[str(unit.id)] = int(state.chamber.appraisals.get(str(unit.id), 0)) + 1
	_reveal(stone)
	return {"ok": true, "event": _event(state, "appraised", {"unit": unit.id, "stone": stone.duplicate(true), "method": "ore", "paid": cost,
		"next": appraise_cost(state, str(unit.id))})}

static func _buy(state: Dictionary, unit: Dictionary, item_id: String) -> Dictionary:
	var item: Dictionary = {}
	for candidate in state.chamber.get("stock", []):
		if str(candidate.id) == item_id:
			item = candidate
	if item.is_empty():
		return _refuse("no such item")
	if not str(item.get("sold", "")).is_empty():
		return _refuse("already sold")
	if int(unit.get("ore", 0)) < int(item.price):
		return _refuse("not enough ore")
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
	if DeepStone.is_locked(stone):
		return _refuse("a Knot cannot leave its socket")
	## A stone nobody has read still sells: the buyer pays for its size class and nothing
	## else, which is always the worse end of what it might have been worth.
	var paid: int = DeepStone.value(stone) / 2 if bool(stone.get("appraised", false)) else DeepStone.rough_value(stone)
	DeepOddities.remove_stone(unit, stone_id)
	unit.ore = int(unit.ore) + paid
	return {"ok": true, "event": _event(state, "sold", {"unit": unit.id, "stone_id": stone_id, "ore": unit.ore, "paid": paid})}

static func _leave_stall(state: Dictionary, unit: Dictionary) -> Dictionary:
	if bool(unit.get("ready", false)):
		return _refuse("you have already left the stall")
	unit.ready = true
	var event: Dictionary = _event(state, "left_stall", {"unit": unit.id})
	for other in living(state):
		if not bool(other.get("ready", false)):
			return {"ok": true, "event": event}
	state.chamber.settled = true
	var streams: Dictionary = streams_of(state)
	_offer_tunnels(state, streams)
	state.rng = DeepRng.save(streams)
	event.finished = true
	return {"ok": true, "event": event}

# --- landings --------------------------------------------------------------------------------
##
## A landing is solid ground and a lift. Each player takes one respite there: rest (a share
## of their health back), appraise (one raw stone from the haul, free), or the wheel (one
## stone you have read is cut again from scratch, better or worse). Then the party votes: up
## the lift with everything, or on down.

static func _arrive_landing(state: Dictionary, streams: Dictionary) -> Dictionary:
	state.phase = "landing"
	state.chamber = {}
	for unit in state.players:
		unit.choice = ""
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
	## A Warden's hall has the cage and the hoard and nothing to rest at.
	return not bool(state.get("landing", {}).get("cleared", false))

static func rest_amount(unit: Dictionary) -> int:
	## What resting gives back: a share of the most health, never past it.
	var share: int = int(ceil(float(unit.get("max_hp", 0)) * float(DeepContent.constant("rest_pct", 30)) / 100.0))
	return clampi(int(unit.get("max_hp", 0)) - int(unit.get("hp", 0)), 0, share)

static func can_polish(stone: Dictionary) -> bool:
	## Any stone that has been read can go back on the wheel, a Perfect one included: the
	## wheel does not improve a cut, it draws a new one, and a Perfect stone has everything
	## to lose by it.
	return bool(stone.get("appraised", false)) and not DeepStone.is_birthstone(stone)

static func _respite(state: Dictionary, unit: Dictionary, choice: String, stone_id: String) -> Dictionary:
	if not str(unit.get("respite", "")).is_empty():
		return _refuse("you have taken your respite")
	var fields: Dictionary = {"unit": unit.id, "choice": choice}
	match choice:
		"rest":
			var gained: int = rest_amount(unit)
			unit.hp = int(unit.hp) + gained
			fields.healed = gained
			fields.message = "You sit with your back to the lift cage and get %d health back." % gained
		"appraise":
			var stone: Dictionary = _raw_in_haul(unit, stone_id)
			if stone.is_empty():
				return _refuse("choose a raw stone from your haul")
			_reveal(stone)
			fields.stone = stone.duplicate(true)
			fields.message = "Under the lift's lamp the stone shows what it is."
		"polish":
			var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
			if stone.is_empty() or not can_polish(stone):
				return _refuse("choose a stone you have read")
			var streams: Dictionary = streams_of(state)
			var was: int = int(stone.get("cut", 0))
			var now: int = DeepForge.reroll_cut(streams.oddities, stone, mine_of(state), int(state.depth))
			state.rng = DeepRng.save(streams)
			fields.stone = stone.duplicate(true)
			fields.message = "An hour at the wheel. It went on %s and comes off %s." % [DeepContent.cut_name(was), DeepContent.cut_name(now)]
		_:
			return _refuse("rest, appraise or polish")
	unit.respite = choice
	state.landing.respites[str(unit.id)] = fields.duplicate(true)
	return {"ok": true, "event": _event(state, "respite", fields)}

static func _choose_at_landing(state: Dictionary, unit: Dictionary, choice: String) -> Dictionary:
	## A landing asks one question at a time. The cage stands beside the fire, the bench and
	## the wheel, and any of the four may be walked up to first; but the moment a respite is
	## taken the cage is behind you and the only way left is down. The one exception is a
	## Warden's hall, where the hoard has just been shared out and riding up with it is the
	## whole point of having come this far.
	if not choice in ["lift", "descend"]:
		return _refuse("lift or descend")
	var landing: Dictionary = state.get("landing", {})
	var hall: bool = bool(landing.get("cleared", false))
	var rested: bool = not str(unit.get("respite", "")).is_empty()
	if choice == "descend" and not rested and _has_respites(state):
		return _refuse("take your respite first: the fire, the bench or the wheel")
	if choice == "lift" and rested and not hall:
		return _refuse("you have taken your respite: the way on is down")
	unit.choice = choice
	var event: Dictionary = _event(state, "landing_choice", {"unit": unit.id, "choice": choice})
	var lifts: int = 0
	var descends: int = 0
	for other in living(state):
		match str(other.get("choice", "")):
			"": return {"ok": true, "event": event}
			"lift": lifts += 1
			"descend": descends += 1
	var ride: bool = lifts > descends or (lifts == descends and str(living(state)[0].get("choice", "")) == "lift")
	var streams: Dictionary = streams_of(state)
	if ride:
		var conquered: bool = int(state.depth) >= int(DeepContent.constant("run_depth", 24)) and bool(state.landing.get("cleared", false))
		_finish(state, "conquered" if conquered else "extracted")
		event.finished = str(state.outcome)
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
	return {"ok": true, "event": event}

# --- hoard, salvage, endings ---------------------------------------------------------------

static func _offer_hoard(state: Dictionary) -> void:
	## Two stones read out on their pedestals, and, last of the three, one still in its
	## rock: an opal, the only thing in the mine that no vein and no drop ever offers. The
	## pile says that much and no more. Its carat, its cut and its clarity are rolled like
	## any other stone's, so taking it means giving up two known stones for one that is as
	## likely to be a small dull thing as it is to be the gem the run is remembered for.
	var streams: Dictionary = streams_of(state)
	state.phase = "hoard"
	state.hoard = {}
	var opals: Array = DeepForge.opal_pool()
	var sealed_pct: float = float(DeepContent.constant("opal_hoard_pct", 100))
	for unit in state.players:
		var offers: Array = []
		for index in range(HOARD_OFFERS):
			var raw: bool = index == HOARD_OFFERS - 1 and not opals.is_empty() and DeepRng.chance(streams.stones, sealed_pct)
			var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine_of(state), int(state.depth), 6, {"run": str(state.run_id), "source": "hoard", "finder": str(unit.id)}, _id(state, "st"), opals if raw else [])
			stone.appraised = not raw
			stone.inclusions_revealed = not raw
			offers.append(stone)
		state.hoard[unit.id] = {"offers": offers, "chosen": ""}
	state.rng = DeepRng.save(streams)

static func _pick_hoard(state: Dictionary, unit: Dictionary, stone_id: String) -> Dictionary:
	if str(state.phase) != "hoard":
		return _refuse("there is no hoard to pick from")
	var mine_hoard: Dictionary = state.hoard.get(str(unit.id), {})
	if not str(mine_hoard.get("chosen", "")).is_empty():
		return _refuse("you have chosen")
	for stone in mine_hoard.get("offers", []):
		if str(stone.id) == stone_id:
			mine_hoard.chosen = stone_id
			## A sealed stone comes off the pile sealed. Taking it is the gamble; what it
			## turns out to be is the loupe's to say, at a stall or at home, like any other
			## stone that came out of the rock.
			var raw: bool = not bool(stone.get("appraised", false))
			unit.haul.append(stone)
			unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
			var event: Dictionary = _event(state, "hoard_pick", {"unit": unit.id, "stone": stone.duplicate(true), "raw": raw})
			var everyone: bool = true
			for other in state.players:
				if str(state.hoard.get(str(other.id), {}).get("chosen", "")).is_empty() and bool(other.get("connected", true)):
					everyone = false
			if everyone:
				state.phase = "landing"
				for other in state.players:
					other.choice = ""
				event.landing = true
			return {"ok": true, "event": event}
	return _refuse("no such stone in the hoard")

static func _start_salvage(state: Dictionary) -> void:
	## A wipe. Every raw stone rolls a die by its grade and only the top face brings it home.
	var streams: Dictionary = streams_of(state)
	var dice: Dictionary = DeepContent.constant("salvage_dice", {"ROUGH": 4, "FINE": 6, "PRECIOUS": 8, "EXQUISITE": 10, "PEERLESS": 12})
	state.phase = "salvage"
	state.salvage = {}
	for unit in state.players:
		var rolls: Array = []
		var kept: Array = []
		for stone in unit.haul:
			var tier: String = DeepStone.grade(stone).tier
			var sides: int = int(dice.get(tier, 6))
			var roll: int = streams.salvage.randi_range(1, sides)
			var survives: bool = roll == sides
			rolls.append({"stone": stone.duplicate(true), "sides": sides, "roll": roll, "kept": survives, "tier": tier})
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
		for stone in unit.get("haul", []) + unit.get("rail", []):
			if not stone is Dictionary or not bool(stone.get("appraised", false)) or DeepStone.is_birthstone(stone):
				continue
			var skill: String = str(stone.get("skill", ""))
			if not skill.is_empty() and not unit.seen.has(skill):
				unit.seen.append(skill)

static func _finish(state: Dictionary, outcome: String) -> void:
	state.phase = "over"
	state.outcome = outcome
	state.offers = []

static func results(state: Dictionary) -> Dictionary:
	## What each player takes home. Ore stays in the mine.
	_saw(state)
	var out: Dictionary = {"run_id": str(state.run_id), "mine": str(state.mine), "outcome": str(state.outcome), "depth": int(state.depth),
		"deepest": int(state.records.deepest), "wardens": state.records.wardens.duplicate(), "players": {}}
	for unit in state.players:
		out.players[str(unit.id)] = {"haul": unit.haul.duplicate(true), "dice": unit.bag_dice.duplicate(true), "stats": unit.stats.duplicate(true),
			"rail": unit.rail.duplicate(true), "seen": unit.get("seen", []).duplicate()}
	return out

# --- commands ----------------------------------------------------------------------------

static func command(state: Dictionary, player_id: String, cmd: Dictionary) -> Dictionary:
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
	match kind:
		"stake":
			if phase != "grubstake":
				return _refuse("the stakes are taken at the shaft head")
			return _take_stake(state, unit, str(cmd.get("offer", "")), cmd.get("payload", {}))
		"vote_tunnel":
			if phase != "tunnels":
				return _refuse("no tunnels to choose")
			var offer: Dictionary = {}
			for candidate in state.offers:
				if str(candidate.id) == str(cmd.get("offer", "")):
					offer = candidate
			if offer.is_empty():
				return _refuse("no such tunnel")
			unit.vote = str(offer.id)
			var event: Dictionary = _event(state, "vote", {"unit": unit.id, "offer": offer.id})
			for other in living(state):
				if str(other.get("vote", "")).is_empty():
					return {"ok": true, "event": event}
			var winner: String = _tally(state)
			for candidate in state.offers:
				if str(candidate.id) == winner:
					var streams: Dictionary = streams_of(state)
					var entered: Dictionary = _enter(state, candidate, streams)
					state.rng = DeepRng.save(streams)
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
		"socket", "unsocket", "swap_die", "give":
			if not bench_open(state):
				return _refuse("the bench waits until the fight is over")
			match kind:
				"socket": return _socket(state, unit, str(cmd.get("stone_id", "")), int(cmd.get("index", -1)))
				"unsocket": return _unsocket(state, unit, int(cmd.get("index", -1)))
				"swap_die": return _swap_die(state, unit, int(cmd.get("index", -1)), str(cmd.get("die_id", "")))
			return _give(state, unit, str(cmd.get("to", "")), str(cmd.get("item_id", "")))
		"buy", "sell", "leave":
			if not at_stall(state):
				return _refuse("there is no merchant here")
			match kind:
				"buy": return _buy(state, unit, str(cmd.get("item_id", "")))
				"sell": return _sell(state, unit, str(cmd.get("stone_id", "")))
			return _leave_stall(state, unit)
		"respite":
			if phase != "landing":
				return _refuse("a respite is taken at a landing")
			return _respite(state, unit, str(cmd.get("choice", "")), str(cmd.get("stone_id", "")))
		"choose":
			if phase != "landing":
				return _refuse("the lift is at the landing")
			return _choose_at_landing(state, unit, str(cmd.get("choice", "")))
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
			for other in state.players:
				if not bool(other.get("ready", false)) and bool(other.get("connected", true)):
					return {"ok": true, "event": event}
			_finish(state, "fallen")
			event.finished = "fallen"
			return {"ok": true, "event": event}
	return _refuse("unknown command " + kind)

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
