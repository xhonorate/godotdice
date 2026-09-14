class_name RogueSeam
extends RefCounted
## The mine as a cross-section: layers of chambers joined by tunnels, dug one layer at a time.
##
## A layer is generated from the run seed, the mine and its depth alone, and the tunnels
## between two layers from those same three things, so any layer comes out identical however
## far ahead of the party it happens to be generated. There is no bottom. The party stands on
## one node and only ever moves down a tunnel to the layer below.
##
## Nothing here reads a stream or the clock, which keeps the whole seam out of the saved RNG
## state and lets a preview, a test or a replay ask for layer 40 without disturbing a fight.
const Catalog = preload("res://scripts/core/catalog.gd")
const RandomSource = preload("res://scripts/core/random_source.gd")

const COLUMNS: int = 7
## Conditions a special mission can impose on the seam. The profile names and describes them;
## this list is what the engine will accept.
const MODIFIERS: Array = ["dim_lanterns", "elite_depths", "no_camps", "swift_tremors"]
## Layers kept generated below the party. The lantern never reaches this far, but lift
## beacons do, and a party deciding whether to dig on needs to see the next one.
const LOOKAHEAD: int = 8
const SIGHT: int = 2
const SURFACE: String = "surface"
## The tremor meter counts to a thousand so small, depth-scaled steps stay whole numbers.
const TREMOR_FULL: int = 1000
## What a room costs the meter on top of the walk there: a long rest, a noisy dig or a hard
## fight all give the boss more time.
const ROOM_TREMOR: Dictionary = {"elite": 20, "mine": 30, "rest": 20}
## How a room reads beyond the lantern's reach.
const SILHOUETTES: Dictionary = {"battle": "hostile", "elite": "hostile", "boss": "hostile",
	"mine": "glint", "treasure": "glint", "rest": "service", "shop": "service", "lapidary": "service",
	"crucible": "service", "workshop": "service", "wager": "service", "event": "unknown", "lift": "lift"}

static func node_id(depth: int, column: int) -> String:
	return "d%dc%d" % [depth, column]

static func ensure_layers(seam: Dictionary, seed_text: String, mine_id: String, modifier: String, through_depth: int) -> void:
	## Grows `seam` = {"layers": {"1": [...], ...}, "deepest": n} until it reaches the depth.
	if not seam.get("layers") is Dictionary:
		seam["layers"] = {}
	seam["deepest"] = int(seam.get("deepest", 0))
	while int(seam.deepest) < through_depth:
		var depth: int = int(seam.deepest) + 1
		seam.layers[str(depth)] = layer(seed_text, mine_id, depth, modifier)
		if depth > 1:
			link(seam.layers[str(depth - 1)], seam.layers[str(depth)], seed_text, mine_id, depth - 1)
		seam.deepest = depth

static func layer(seed_text: String, mine_id: String, depth: int, modifier: String) -> Array:
	var rng: RandomNumberGenerator = _rng(seed_text, mine_id, depth, "layer")
	var mine: Dictionary = Catalog.mine_definition(mine_id)
	var columns: Array = range(COLUMNS)
	for index in range(columns.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, index)
		var held: int = columns[index]
		columns[index] = columns[swap]
		columns[swap] = held
	var count: int = rng.randi_range(3, 5)
	var chosen: Array = columns.slice(0, count)
	chosen.sort()
	var weights: Dictionary = room_weights(mine, depth, modifier)
	var kinds: Array = weights.keys()
	kinds.sort()
	var values: Array = kinds.map(func(kind: String) -> int: return int(weights[kind]))
	var nodes: Array = []
	for column in chosen:
		var index: int = RandomSource.weighted_index(rng, values)
		nodes.append({"id": node_id(depth, column), "depth": depth, "column": column,
			"kind": kinds[index] if index >= 0 else "battle", "links": []})
	var extra_lift: int = floori(maxi(0, 30 - 2 * depth) * int(mine.get("lift_rate", 100)) / 100.0)
	if depth > 1 and (depth in lift_layers(mine, depth) or rng.randi_range(1, 100) <= extra_lift):
		nodes[rng.randi_range(0, nodes.size() - 1)].kind = "lift"
	return nodes

static func room_weights(mine: Dictionary, depth: int, modifier: String) -> Dictionary:
	## The mine's weights with the depth rules applied: the first layer is only fights and
	## rock, services open from the second, and elites and camps wait for the third.
	var weights: Dictionary = {}
	var authored: Dictionary = mine.get("rooms", {}) if mine.get("rooms", {}) is Dictionary else {}
	for kind in authored:
		var weight: int = maxi(0, int(authored[kind]))
		if depth <= 1 and not kind in ["battle", "mine"]:
			weight = 0
		elif depth <= 2 and kind in ["elite", "rest"]:
			weight = 0
		if kind == "rest" and modifier == "no_camps":
			weight = 0
		if kind == "elite" and modifier == "elite_depths":
			weight *= 2
		if weight > 0:
			weights[kind] = weight
	if weights.is_empty():
		weights["battle"] = 1
	return weights

static func lift_layers(mine: Dictionary, up_to: int) -> Array:
	## Depths that always carry a lift. Gaps widen as the party digs and stretch further in a
	## mine with a low lift rate: 2, 5, 8, 12, 17, 23 in the Quarry.
	var rate: float = float(clampi(int(mine.get("lift_rate", 100)), 10, 500))
	var found: Array = []
	var at: int = 0
	while true:
		at += clampi(roundi((2.0 + at / 4.0) * 100.0 / rate), 2, 14)
		if at > up_to:
			break
		found.append(at)
	return found

static func link(upper: Array, lower: Array, seed_text: String, mine_id: String, upper_depth: int) -> void:
	## Tunnels from one layer to the next. A staircase walk pairs the two layers left to right
	## so every node gets a way in and a way out and no two tunnels cross; a few extra
	## branches are then added wherever they still cross nothing.
	var rng: RandomNumberGenerator = _rng(seed_text, mine_id, upper_depth, "links")
	var edges: Array = [[0, 0]]
	var i: int = 0
	var j: int = 0
	while i < upper.size() - 1 or j < lower.size() - 1:
		if i == upper.size() - 1:
			j += 1
		elif j == lower.size() - 1:
			i += 1
		else:
			var step_up: int = absi(int(upper[i + 1].column) - int(lower[j].column))
			var step_down: int = absi(int(upper[i].column) - int(lower[j + 1].column))
			var both: int = absi(int(upper[i + 1].column) - int(lower[j + 1].column))
			if both <= step_up and both <= step_down:
				i += 1
				j += 1
			elif step_up < step_down or (step_up == step_down and rng.randi_range(0, 1) == 0):
				i += 1
			else:
				j += 1
		edges.append([i, j])
	for a in range(upper.size()):
		for b in range(lower.size()):
			if _has_edge(edges, a, b) or absi(int(upper[a].column) - int(lower[b].column)) > 2:
				continue
			if rng.randi_range(1, 100) > 35 or _crosses(edges, a, b):
				continue
			edges.append([a, b])
	for node in upper:
		node.links = []
	for edge in edges:
		var target: String = lower[edge[1]].id
		if not target in upper[edge[0]].links:
			upper[edge[0]].links.append(target)
	for node in upper:
		node.links.sort_custom(func(left: String, right: String) -> bool: return _column_of(left) < _column_of(right))

static func next_nodes(seam: Dictionary, position: String) -> Array:
	if position == SURFACE:
		return seam.get("layers", {}).get("1", []).duplicate()
	var node: Dictionary = find_node(seam, position)
	var found: Array = []
	for id in node.get("links", []):
		var target: Dictionary = find_node(seam, id)
		if not target.is_empty():
			found.append(target)
	return found

static func find_node(seam: Dictionary, id: String) -> Dictionary:
	var parts: PackedStringArray = id.trim_prefix("d").split("c")
	if parts.size() != 2 or not parts[0].is_valid_int():
		return {}
	for node in seam.get("layers", {}).get(parts[0], []):
		if node.get("id", "") == id:
			return node
	return {}

static func silhouette(kind: String) -> String:
	return str(SILHOUETTES.get(kind, "unknown"))

static func sight(modifier: String, lantern: bool) -> int:
	return maxi(1, SIGHT + (1 if lantern else 0) - (1 if modifier == "dim_lanterns" else 0))

static func tremor_for_move(mine: Dictionary, depth: int, modifier: String) -> int:
	return _scaled(25.0 + 2.0 * depth, mine, modifier)

static func tremor_for_turn(mine: Dictionary, depth: int, modifier: String) -> int:
	return _scaled(6.0 + depth / 2.0, mine, modifier)

static func _scaled(amount: float, mine: Dictionary, modifier: String) -> int:
	var rate: float = float(clampi(int(mine.get("tremor_rate", 100)), 10, 500)) / 100.0
	return roundi(amount * rate * (1.5 if modifier == "swift_tremors" else 1.0))

static func _has_edge(edges: Array, a: int, b: int) -> bool:
	for edge in edges:
		if edge[0] == a and edge[1] == b:
			return true
	return false

static func _crosses(edges: Array, a: int, b: int) -> bool:
	for edge in edges:
		if (edge[0] < a and edge[1] > b) or (edge[0] > a and edge[1] < b):
			return true
	return false

static func _column_of(id: String) -> int:
	return int(id.get_slice("c", 1))

static func _rng(seed_text: String, mine_id: String, depth: int, purpose: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ("%s|%s|%d|%s" % [seed_text, mine_id, depth, purpose]).hash()
	return rng
