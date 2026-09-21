class_name DeepDescent
extends RefCounted
## A run: the shaft, its chambers and landings, and everything the party carries.
##
## The host owns one run state and drives it with `command()` for every player action and
## `step()` while a fight resolves. Every change returns an event for the screens. The
## shape of a run:
##
##   tunnels ─pick─▶ chamber (fight | elite | vein | oddity | motherlode) ─▶ tunnels …
##   every LANDING_EVERY depths: landing (lift, lapidary, merchant, bench, give)
##   at warden depths the landing's gate is a warden fight; the hoard follows a win
##   a wipe → salvage → over (fallen);  the lift → over (extracted | conquered)
##
## Players keep their own haul, ore and loupes. Tunnels and the lift are votes.

const PHASES: Array = ["tunnels", "chamber", "landing", "hoard", "salvage", "over"]
const VEIN_SPOTS: int = 6
const VEIN_STRIKES: int = 2
const HOARD_OFFERS: int = 3
const LANDING_STONES: int = 3
const LANDING_DICE: int = 2

# --- setup -------------------------------------------------------------------------------

static func new_run(config: Dictionary) -> Dictionary:
	## config: seed (int), mine (key), run_id, players: [{id, name, character, rail: [stones|null], dice: [die instances]}]
	var seed_value: int = int(config.get("seed", randi()))
	var mine_key: String = str(config.get("mine", DeepContent.starter_mine()))
	var state: Dictionary = {"run_id": str(config.get("run_id", "run%08x" % seed_value)), "seed": seed_value, "mine": mine_key,
		"depth": 0, "phase": "tunnels", "outcome": "", "players": [], "offers": [], "chamber": {}, "landing": {},
		"hoard": {}, "salvage": {}, "aftermath": {}, "used_oddities": [], "path": [], "records": {"deepest": 0, "wardens": [], "stones_found": 0, "fights": 0},
		"rng": {}, "seq": 0, "next_id": 1}
	var streams: Dictionary = DeepRng.streams(seed_value)
	var seat: int = 0
	for entry in config.get("players", []):
		var unit: Dictionary = DeepBattle.make_player(str(entry.get("id", "p%d" % seat)), str(entry.get("name", "Lapidary")), str(entry.get("character", DeepContent.starter_character())),
			entry.get("rail", []), entry.get("dice", []))
		unit.merge({"seat": seat, "haul": [], "bag_dice": [], "ore": 0, "loupes": int(DeepContent.constant("loupes_per_run", 2)), "vote": "",
			"choice": "", "ready": false, "strikes": 0, "oddity_choice": "", "stats": {"damage": 0, "healing": 0, "stones": 0, "fights": 0, "ore": 0}}, true)
		state.players.append(unit)
		seat += 1
	state.rng = DeepRng.save(streams)
	_offer_tunnels(state, streams)
	state.rng = DeepRng.save(streams)
	return state

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
	return depth > 0 and depth % landing_every() == 0

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
	var listed: Array = DeepContent.constant("warden_depths", [8, 16, 24])
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
## shows what lies LANTERN_REACH depths ahead; past that a chamber is only a glint (hostile,
## glittering, strange), a dark mouth shows nothing at all, and lighting the way (a loupe,
## or ore) shows the whole stretch down to the landing.

const MAP_WIDEST: int = 4
const LANTERN_REACH: int = 2
const GLINTS: Dictionary = {"fight": "hostile", "elite": "hostile", "warden": "hostile", "vein": "glittering", "motherlode": "glittering", "oddity": "strange"}

static func _offer_tunnels(state: Dictionary, streams: Dictionary) -> void:
	state.phase = "tunnels"
	state.chamber = {}
	var next_depth: int = int(state.depth) + 1
	for unit in state.players:
		unit.vote = ""
		unit.ready = false
	if is_landing(next_depth):
		state.offers = [{"id": "landing", "kind": "landing", "hidden": false}]
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
	while not is_landing(to):
		to += 1
	var mine: Dictionary = mine_of(state)
	var weights: Dictionary = mine.get("chambers", {"fight": 55, "elite": 12, "vein": 18, "oddity": 15})
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
			for kept in once:
				table.erase(kept)
			var kind: String = DeepRng.weighted_key(rng, table)
			if kind.is_empty():
				kind = "fight"
			if kind == "vein" and DeepRng.chance(rng, float(mine.get("motherlode_pct", 3))):
				kind = "motherlode"
			if kind in ["elite", "oddity"]:
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
	nodes["landing"] = {"id": "landing", "depth": to, "x": 0.5, "kind": "landing", "hidden": false, "next": [], "warden": is_warden_depth(to)}
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

static func _light(state: Dictionary, unit: Dictionary, method: String) -> Dictionary:
	if not str(state.phase) in ["tunnels", "landing"]:
		return _refuse("there is no way ahead to light")
	var map: Dictionary = state.get("map", {})
	if map.is_empty() or int(map.get("to", 0)) <= int(state.depth):
		return _refuse("the way ahead is not charted yet")
	if bool(map.get("lit", false)):
		return _refuse("the way is already lit")
	if method.is_empty():
		method = "loupe" if int(unit.get("loupes", 0)) > 0 else "ore"
	if method == "loupe":
		if int(unit.get("loupes", 0)) <= 0:
			return _refuse("no loupes left")
		unit.loupes = int(unit.loupes) - 1
	else:
		if int(unit.get("ore", 0)) < lantern_cost():
			return _refuse("not enough ore")
		unit.ore = int(unit.ore) - lantern_cost()
		method = "ore"
	map.lit = true
	return {"ok": true, "event": _event(state, "lit", {"unit": unit.id, "method": method, "to": int(map.to)})}

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
		"oddity":
			var pool: Array = DeepContent.section("oddities").keys()
			pool.sort()
			var fresh: Array = pool.filter(func(k: Variant) -> bool: return not state.used_oddities.has(str(k)))
			if fresh.is_empty():
				fresh = pool
			var key: String = str(DeepRng.pick(streams.oddities, fresh))
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
	state.chamber.battle = battle
	state.chamber.kind = "warden" if not warden.is_empty() else ("elite" if elite else "fight")
	state.records.fights = int(state.records.fights) + 1
	return _event(state, "battle_begin", {"depth": state.depth, "creatures": keys, "elite": elite, "warden": warden})

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
			var reward: Dictionary = {"ore": ore, "stones": [], "dice": []}
			if kind != "warden":
				var drops: Dictionary = DeepContent.constant("stone_drop_pct", {"fight": 55, "elite": 100})
				var chance: float = float(drops.get(kind, 55)) + float(fighter.get("quality_bonus", 0)) / 2.0
				if DeepRng.chance(streams.stones, chance):
					var bonus: int = (4 if kind == "elite" else 0) + int(fighter.get("quality_bonus", 0)) / 10
					reward.stones.append(_find_stone(state, unit, streams, bonus, kind))
				if kind == "elite" and DeepRng.chance(streams.stones, 35.0):
					var die: Dictionary = DeepForge.roll_die(streams.stones, mine_of(state), int(state.depth), _id(state, "die"))
					unit.bag_dice.append(die)
					reward.dice.append(die)
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

static func _dig_vein(state: Dictionary, streams: Dictionary, hazard: bool) -> void:
	var rng: RandomNumberGenerator = streams.tunnels
	var spots: Array = []
	for index in range(VEIN_SPOTS):
		var kind: String = DeepRng.weighted_key(rng, {"stone": 42 if not hazard else 60, "ore": 30, "die": 8, "nothing": 20 if not hazard else 10})
		var glint: String = "dull"
		if kind == "stone":
			glint = "bright" if DeepRng.chance(rng, 35.0) else "glint"
		elif kind == "die":
			glint = "glint"
		spots.append({"index": index, "kind": kind, "glint": glint, "taken": "", "result": {}})
	state.chamber.vein = {"spots": spots, "hazard": hazard}
	for unit in state.players:
		unit.strikes = VEIN_STRIKES if not bool(unit.get("downed", false)) else 0

static func _strike(state: Dictionary, unit: Dictionary, spot_index: int) -> Dictionary:
	if str(state.chamber.get("kind", "")) not in ["vein", "vug"] or not state.chamber.has("vein"):
		return _refuse("there is no rock to strike here")
	if int(unit.get("strikes", 0)) <= 0:
		return _refuse("your arm is spent")
	var spots: Array = state.chamber.vein.spots
	if spot_index < 0 or spot_index >= spots.size():
		return _refuse("no such spot")
	var spot: Dictionary = spots[spot_index]
	if not str(spot.get("taken", "")).is_empty():
		return _refuse("someone already struck there")
	var streams: Dictionary = streams_of(state)
	unit.strikes = int(unit.strikes) - 1
	spot.taken = str(unit.id)
	if bool(state.chamber.vein.get("hazard", false)):
		unit.hp = maxi(1, int(unit.hp) - 3)
	var result: Dictionary = {"kind": str(spot.kind)}
	match str(spot.kind):
		"stone":
			result.stone = _find_stone(state, unit, streams, 3 if str(spot.glint) == "bright" else 0, "vein")
		"ore":
			var ore: int = 4 + int(state.depth) + streams.tunnels.randi_range(0, 4)
			unit.ore = int(unit.ore) + ore
			unit.stats.ore = int(unit.stats.get("ore", 0)) + ore
			result.ore = ore
		"die":
			var die: Dictionary = DeepForge.roll_die(streams.stones, mine_of(state), int(state.depth), _id(state, "die"))
			unit.bag_dice.append(die)
			result.die = die
	spot.result = result
	state.rng = DeepRng.save(streams)
	var finished: bool = true
	for other in living(state):
		if int(other.get("strikes", 0)) > 0:
			finished = false
	var open: bool = false
	for s in spots:
		if str(s.get("taken", "")).is_empty():
			open = true
	var event: Dictionary = _event(state, "vein_strike", {"unit": unit.id, "spot": spot_index, "result": result.duplicate(true), "strikes": unit.strikes})
	if finished or not open:
		state.chamber.settled = true
		_offer_tunnels(state, streams_of(state))
		event.finished = true
	return {"ok": true, "event": event}

# --- oddities ----------------------------------------------------------------------------

static func _choose_oddity(state: Dictionary, unit: Dictionary, choice_id: String, payload: Dictionary) -> Dictionary:
	if str(state.chamber.get("kind", "")) != "oddity":
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
	state.chamber.results[unit.id] = {"choice": choice_id, "message": str(result.message), "made": result.get("made", []), "lost": result.get("lost", [])}
	var event: Dictionary = _event(state, "oddity_result", {"unit": unit.id, "choice": choice_id, "message": str(result.message),
		"made": result.get("made", []).duplicate(true), "lost": result.get("lost", [])})
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

# --- landings ----------------------------------------------------------------------------

static func _arrive_landing(state: Dictionary, streams: Dictionary) -> Dictionary:
	state.phase = "landing"
	state.chamber = {}
	var mine: Dictionary = mine_of(state)
	var stock: Array = []
	for _i in range(LANDING_STONES):
		var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine, int(state.depth), 2, {"run": str(state.run_id), "source": "merchant"}, _id(state, "st"))
		stone.appraised = true
		stone.inclusions_revealed = true
		stock.append({"id": _id(state, "item"), "kind": "stone", "stone": stone, "price": DeepStone.value(stone) * 2, "sold": ""})
	for _i in range(LANDING_DICE):
		var die: Dictionary = DeepForge.roll_die(streams.stones, mine, int(state.depth), _id(state, "die"))
		stock.append({"id": _id(state, "item"), "kind": "die", "die": die, "price": int(DeepContent.die(str(die.key)).get("price", 10)) + int(state.depth) * 2, "sold": ""})
	stock.append({"id": _id(state, "item"), "kind": "loupe", "price": 10 + int(state.depth), "sold": ""})
	for unit in state.players:
		unit.choice = ""
		unit.ready = false
		unit.hp = mini(int(unit.max_hp), int(unit.hp) + int(ceil(float(unit.max_hp) * 0.2)))
		if bool(unit.get("downed", false)):
			unit.downed = false
			unit.hp = maxi(int(unit.hp), int(ceil(float(unit.max_hp) * 0.25)))
	state.landing = {"depth": int(state.depth), "stock": stock, "warden_next": is_warden_depth(int(state.depth)), "cleared": false}
	## The stretch below is charted now, so the landing can show the way on.
	_chart(state, streams)
	return _event(state, "landing", {"depth": state.depth, "landing": state.landing.duplicate(true)})

static func _appraise(state: Dictionary, unit: Dictionary, stone_id: String, method: String) -> Dictionary:
	var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
	if stone.is_empty():
		return _refuse("no such stone")
	if bool(stone.get("appraised", false)):
		return _refuse("it is already appraised")
	if method == "loupe":
		if int(unit.get("loupes", 0)) <= 0:
			return _refuse("no loupes left")
		unit.loupes = int(unit.loupes) - 1
	else:
		var cost: int = int(DeepContent.constant("appraise_ore_cost", 12))
		if int(unit.get("ore", 0)) < cost:
			return _refuse("not enough ore")
		unit.ore = int(unit.ore) - cost
	stone.appraised = true
	stone.inclusions_revealed = true
	return {"ok": true, "event": _event(state, "appraised", {"unit": unit.id, "stone": stone.duplicate(true), "method": method})}

static func _socket(state: Dictionary, unit: Dictionary, stone_id: String, index: int) -> Dictionary:
	if index < 0 or index >= unit.rail.size():
		return _refuse("no such socket")
	var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
	if stone.is_empty():
		return _refuse("no such stone")
	if not bool(stone.get("appraised", false)):
		return _refuse("an unappraised stone cannot be set")
	if not DeepStone.fits(stone, str(unit.sockets[index])):
		return _refuse("that socket takes a different colour")
	var carat_cap: int = int(DeepContent.character(str(unit.get("character", ""))).get("carat_max", 0))
	if carat_cap > 0 and int(stone.carat) > carat_cap:
		return _refuse("%s takes nothing heavier than %d carats" % [str(DeepContent.character(str(unit.get("character", ""))).get("name", "this character")), carat_cap])
	for other in unit.rail:
		if other is Dictionary and str(other.skill) == str(stone.skill) and str(other.id) != stone_id:
			return _refuse("one stone of each skill")
	var current: Variant = unit.rail[index]
	if current is Dictionary and DeepStone.is_locked(current):
		return _refuse("a Knot cannot leave its socket")
	## Take the stone out of wherever it was.
	var from_socket: int = -1
	for i in range(unit.rail.size()):
		if unit.rail[i] is Dictionary and str(unit.rail[i].id) == stone_id:
			from_socket = i
	if from_socket >= 0:
		if DeepStone.is_locked(unit.rail[from_socket]):
			return _refuse("a Knot cannot leave its socket")
		unit.rail[from_socket] = current if current is Dictionary and DeepStone.fits(current, str(unit.sockets[from_socket])) else null
		if from_socket != index and current is Dictionary and unit.rail[from_socket] == null:
			unit.haul.append(current)
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
	if index < 0 or index >= unit.dice.size():
		return _refuse("no such die slot")
	var found: int = -1
	for i in range(unit.bag_dice.size()):
		if str(unit.bag_dice[i].id) == die_id:
			found = i
	if found < 0:
		return _refuse("that die is not in your bag")
	var incoming: Dictionary = unit.bag_dice[found]
	unit.bag_dice.remove_at(found)
	unit.bag_dice.append(unit.dice[index])
	unit.dice[index] = incoming
	return {"ok": true, "event": _event(state, "dice_changed", {"unit": unit.id, "dice": unit.dice.duplicate(true)})}

static func _buy(state: Dictionary, unit: Dictionary, item_id: String) -> Dictionary:
	var item: Dictionary = {}
	for candidate in state.landing.get("stock", []):
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
	match str(item.kind):
		"stone":
			var stone: Dictionary = item.stone.duplicate(true)
			stone.provenance.finder = str(unit.id)
			unit.haul.append(stone)
		"die":
			unit.bag_dice.append(item.die.duplicate(true))
		"loupe":
			unit.loupes = int(unit.get("loupes", 0)) + 1
	return {"ok": true, "event": _event(state, "bought", {"unit": unit.id, "item": item.duplicate(true), "ore": unit.ore})}

static func _sell(state: Dictionary, unit: Dictionary, stone_id: String) -> Dictionary:
	var stone: Dictionary = DeepOddities.find_stone(unit, stone_id)
	if stone.is_empty():
		return _refuse("no such stone")
	if bool(stone.get("appraised", false)) == false:
		return _refuse("appraise it first")
	var paid: int = DeepStone.value(stone) / 2
	DeepOddities.remove_stone(unit, stone_id)
	unit.ore = int(unit.ore) + paid
	return {"ok": true, "event": _event(state, "sold", {"unit": unit.id, "stone_id": stone_id, "ore": unit.ore, "paid": paid})}

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
	for i in range(unit.bag_dice.size()):
		if str(unit.bag_dice[i].id) == item_id:
			var die: Dictionary = unit.bag_dice[i]
			unit.bag_dice.remove_at(i)
			other.bag_dice.append(die)
			return {"ok": true, "event": _event(state, "given", {"from": unit.id, "to": other.id, "die": die.duplicate(true)})}
	return _refuse("only stones in your haul and dice in your bag can be given")

static func _choose_at_landing(state: Dictionary, unit: Dictionary, choice: String) -> Dictionary:
	if not choice in ["lift", "descend"]:
		return _refuse("lift or descend")
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
	var streams: Dictionary = streams_of(state)
	state.phase = "hoard"
	state.hoard = {}
	for unit in state.players:
		var offers: Array = []
		for _i in range(HOARD_OFFERS):
			var stone: Dictionary = DeepForge.roll_stone(streams.stones, mine_of(state), int(state.depth), 6, {"run": str(state.run_id), "source": "hoard", "finder": str(unit.id)}, _id(state, "st"))
			stone.appraised = true
			stone.inclusions_revealed = true
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
			unit.haul.append(stone)
			unit.stats.stones = int(unit.stats.get("stones", 0)) + 1
			var event: Dictionary = _event(state, "hoard_pick", {"unit": unit.id, "stone": stone.duplicate(true)})
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

static func _finish(state: Dictionary, outcome: String) -> void:
	state.phase = "over"
	state.outcome = outcome
	state.offers = []

static func results(state: Dictionary) -> Dictionary:
	## What each player takes home. Ore stays in the mine.
	var out: Dictionary = {"run_id": str(state.run_id), "mine": str(state.mine), "outcome": str(state.outcome), "depth": int(state.depth),
		"deepest": int(state.records.deepest), "wardens": state.records.wardens.duplicate(), "players": {}}
	for unit in state.players:
		out.players[str(unit.id)] = {"haul": unit.haul.duplicate(true), "dice": unit.bag_dice.duplicate(true), "stats": unit.stats.duplicate(true),
			"rail": unit.rail.duplicate(true)}
	return out

# --- commands ----------------------------------------------------------------------------

static func command(state: Dictionary, player_id: String, cmd: Dictionary) -> Dictionary:
	## Every player action. Returns {ok, error} or {ok, event}.
	var unit: Dictionary = player(state, player_id)
	if unit.is_empty():
		return _refuse("no such player")
	var kind: String = str(cmd.get("kind", ""))
	var phase: String = str(state.get("phase", ""))
	if phase == "over":
		return _refuse("the run is over")
	match kind:
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
		"strike":
			if phase != "chamber":
				return _refuse("no rock here")
			return _strike(state, unit, int(cmd.get("spot", -1)))
		"oddity":
			if phase != "chamber":
				return _refuse("no oddity here")
			return _choose_oddity(state, unit, str(cmd.get("choice", "")), cmd.get("payload", {}))
		"appraise":
			if not phase in ["landing", "hoard"]:
				return _refuse("stones are appraised at a landing")
			return _appraise(state, unit, str(cmd.get("stone_id", "")), str(cmd.get("with", "loupe")))
		"socket":
			if phase != "landing":
				return _refuse("the bench is at the landing")
			return _socket(state, unit, str(cmd.get("stone_id", "")), int(cmd.get("index", -1)))
		"unsocket":
			if phase != "landing":
				return _refuse("the bench is at the landing")
			return _unsocket(state, unit, int(cmd.get("index", -1)))
		"swap_die":
			if phase != "landing":
				return _refuse("the bench is at the landing")
			return _swap_die(state, unit, int(cmd.get("index", -1)), str(cmd.get("die_id", "")))
		"buy":
			if phase != "landing":
				return _refuse("the merchant is at the landing")
			return _buy(state, unit, str(cmd.get("item_id", "")))
		"sell":
			if phase != "landing":
				return _refuse("the merchant is at the landing")
			return _sell(state, unit, str(cmd.get("stone_id", "")))
		"give":
			if phase != "landing":
				return _refuse("things change hands at a landing")
			return _give(state, unit, str(cmd.get("to", "")), str(cmd.get("item_id", "")))
		"choose":
			if phase != "landing":
				return _refuse("the lift is at the landing")
			if bool(state.landing.get("warden_next", false)) and str(cmd.get("choice", "")) == "descend" and bool(state.landing.get("cleared", false)) == false:
				pass
			return _choose_at_landing(state, unit, str(cmd.get("choice", "")))
		"pick_hoard":
			return _pick_hoard(state, unit, str(cmd.get("stone_id", "")))
		"light":
			return _light(state, unit, str(cmd.get("with", "")))
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
