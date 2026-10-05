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
## What a landing's well will take, and the most of it.
const WISH_LEAST: int = 10
const WISH_MOST: int = 1000

# --- setup -------------------------------------------------------------------------------

static func new_run(config: Dictionary) -> Dictionary:
	## config: seed (int), mine (key), run_id, boons (bool, default true),
	##   players: [{id, name, character, rail: [stones|null], dice: [die instances], last_depth, last_outcome}]
	var seed_value: int = int(config.get("seed", randi()))
	var mine_key: String = str(config.get("mine", DeepContent.starter_mine()))
	var mine_def: Dictionary = DeepContent.mine(mine_key)
	var state: Dictionary = {"run_id": str(config.get("run_id", "run%08x" % seed_value)), "seed": seed_value, "mine": mine_key, "from_mine": mine_key,
		"depth": 0, "phase": "tunnels", "outcome": "", "players": [], "offers": [], "chamber": {}, "landing": {},
		"hoard": {}, "salvage": {}, "aftermath": {}, "used_oddities": [], "path": [], "records": {"deepest": 0, "wardens": [], "boss": false, "stones_found": 0, "fights": 0},
		"heat": 0, "carried": 0, "mines_done": [], "rng": {}, "seq": 0, "next_id": 1}
	var streams: Dictionary = DeepRng.streams(seed_value)
	state.schedule = plan_shaft(streams.tunnels, mine_def)
	## A party that starts in a deeper mine rather than fighting down to it is given what the
	## way down would have given it: every socket filled from the vault, and a purse.
	var sockets: int = loadout_sockets(mine_key)
	var seat: int = 0
	for entry in config.get("players", []):
		var rail: Array = entry.get("rail", []).duplicate(true)
		for index in range(sockets, rail.size()):
			rail[index] = null
		var unit: Dictionary = DeepBattle.make_player(str(entry.get("id", "p%d" % seat)), str(entry.get("name", "Lapidary")), str(entry.get("character", DeepContent.starter_character())),
			rail, entry.get("dice", []))
		unit.merge({"seat": seat, "haul": [], "bag_dice": [], "ore": int(mine_def.get("start_pyrite", 0)), "vote": "", "seen": [],
			"choice": "", "respite": "", "ready": false, "strikes": 0, "mining": false, "oddity_choice": "", "stake": "", "last_depth": int(entry.get("last_depth", 0)),
			"last_outcome": str(entry.get("last_outcome", "")), "stats": {"damage": 0, "healing": 0, "stones": 0, "fights": 0, "ore": 0}}, true)
		state.players.append(unit)
		seat += 1
	_unique_rails(state)
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
		"changed": result.get("changed", []).duplicate(true), "pick": bool(result.get("pick", false))})
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

static func loadout_sockets(mine_key: String) -> int:
	## How many of a lapidary's sockets are filled from the vault before a run in this mine.
	return int(DeepContent.mine(mine_key).get("loadout_sockets", DeepContent.constant("starting_rail_cap", 3)))

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
	return listed.has(depth)

static func run_is_warden(state: Dictionary, depth: int) -> bool:
	## A Warden or the final boss stands at this landing.
	if bool(mine_of(state).get("endless", false)):
		return is_warden_depth(depth, str(state.get("mine", "")))
	var listed: Array = state.get("schedule", {}).get("wardens", [])
	if listed.is_empty():
		return is_warden_depth(depth, str(state.get("mine", "")))
	return listed.has(depth)

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
## shows what lies LANTERN_REACH depth ahead; the chart shows only that floor. A dark mouth
## shows nothing until the party reaches it or pays ore to light that floor. Every stretch holds a merchant somewhere
## below its first depth, and a smithy or a carver on its last.

const MAP_WIDEST: int = 4
const LANTERN_REACH: int = 1
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
	_offer_tunnels(state, streams_of(state))
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
	## not — it came down with you and it goes back up with you — and a Knot will not leave
	## its socket.
	return not DeepStone.is_birthstone(stone) and not DeepStone.is_locked(stone)

static func _respite(state: Dictionary, unit: Dictionary, choice: String, stone_id: String, ore: int = 0) -> Dictionary:
	if not str(unit.get("respite", "")).is_empty():
		return _refuse("you have taken your respite")
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
	return int(DeepContent.constant("lift_ore_per_depth", 15)) * maxi(1, floors) * maxi(1, living(state).size())

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

static func _choose_at_landing(state: Dictionary, unit: Dictionary, choice: String) -> Dictionary:
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
	var rested: bool = not str(unit.get("respite", "")).is_empty()
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
		event.paid = _pay_for_lift(state)
		_finish(state, "conquered" if is_conquered(state) else "extracted")
		event.finished = str(state.outcome)
	elif boss_hall:
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
	return {"ok": true, "event": event}

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
	## Three stones on their pedestals, and, last of the three, an opal: the only thing in the
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
		var offers: Array = []
		for index in range(HOARD_OFFERS):
			var opal: bool = index == HOARD_OFFERS - 1 and not opals.is_empty() and DeepRng.chance(streams.stones, opal_pct)
			var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine_of(state), int(state.depth), opal_luck if opal else luck, {"run": str(state.run_id), "source": "hoard", "finder": str(unit.id)}, _id(state, "st"), opals if opal else [])
			stone.appraised = false
			stone.inclusions_revealed = false
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
			## Nothing on the pile has been read: it goes into the bag in its rock like any
			## other find, and a stall or a landing opens it.
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
		_shatter_fragile(unit)
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

static func results(state: Dictionary) -> Dictionary:
	## What each player takes home. Ore stays in the mine.
	_saw(state)
	var mines: Array = state.get("mines_done", []).duplicate(true)
	mines.append(mine_record(state))
	var out: Dictionary = {"run_id": str(state.run_id), "mine": str(state.mine), "from_mine": str(state.get("from_mine", state.mine)), "outcome": str(state.outcome),
		"depth": int(state.depth), "deepest": int(state.records.deepest), "wardens": state.records.wardens.duplicate(), "mines": mines, "players": {}}
	for unit in state.players:
		out.players[str(unit.id)] = {"haul": unit.haul.duplicate(true), "dice": unit.bag_dice.duplicate(true), "stats": unit.stats.duplicate(true),
			"rail": unit.rail.duplicate(true), "riders": unit.get("riders", []).duplicate(true), "seen": unit.get("seen", []).duplicate(), "shattered": unit.get("shattered", []).duplicate(true)}
	return out

# --- commands ----------------------------------------------------------------------------

static func command(state: Dictionary, player_id: String, cmd: Dictionary) -> Dictionary:
	var result: Dictionary = _command(state, player_id, cmd)
	if bool(result.get("ok", false)):
		for unit in state.get("players", []):
			DeepStone.normalize_rail(unit)
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
				"socket": return _socket(state, unit, str(cmd.get("stone_id", "")), int(cmd.get("index", -1)), int(cmd.get("at", -1)))
				"unsocket": return _unsocket(state, unit, int(cmd.get("index", -1)), str(cmd.get("stone_id", "")))
				"swap_die": return _swap_die(state, unit, int(cmd.get("index", -1)), str(cmd.get("die_id", "")))
			return _give(state, unit, str(cmd.get("to", "")), str(cmd.get("item_id", "")))
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
