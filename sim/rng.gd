class_name DeepRng
extends RefCounted
## Every gameplay draw comes from a named stream the host owns and saves.
##
## Streams are seeded from the run seed and a name, so the dice, the loot and the tunnels
## never steal each other's numbers: skipping an animation, or a guest joining late, cannot
## change what the rock gives up. Cosmetic randomness in the view uses its own RNG and is
## never saved.

const STREAMS: Array = ["dice", "creatures", "stones", "tunnels", "oddities", "salvage"]

static func streams(seed_value: int, names: Array = STREAMS) -> Dictionary:
	var out: Dictionary = {}
	for name in names:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(seed_value) + ":" + str(name))
		out[str(name)] = rng
	return out

static func save(streams_by_name: Dictionary) -> Dictionary:
	## RNG states are 64-bit and JSON only keeps doubles, so they travel as decimal strings.
	var out: Dictionary = {}
	for name in streams_by_name:
		var rng: RandomNumberGenerator = streams_by_name[name]
		out[str(name)] = {"seed": str(rng.seed), "state": str(rng.state)}
	return out

static func restore(saved: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for name in saved:
		var rng := RandomNumberGenerator.new()
		var record: Dictionary = saved[name]
		rng.seed = int(str(record.get("seed", "0")))
		rng.state = int(str(record.get("state", "0")))
		out[str(name)] = rng
	return out

static func weighted_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0.0
	for weight in weights:
		total += maxf(0.0, float(weight))
	if total <= 0.0:
		return -1
	var draw: float = rng.randf() * total
	for index in range(weights.size()):
		draw -= maxf(0.0, float(weights[index]))
		if draw < 0.0:
			return index
	return weights.size() - 1

static func weighted_key(rng: RandomNumberGenerator, table: Dictionary) -> String:
	## Picks a key from {key: weight}. Keys are visited in sorted order so the same table
	## and the same RNG state always answer the same way, whatever order the JSON came in.
	var keys: Array = table.keys()
	keys.sort()
	var weights: Array = []
	for key in keys:
		weights.append(float(table[key]))
	var index: int = weighted_index(rng, weights)
	return str(keys[index]) if index >= 0 else ""

static func pick(rng: RandomNumberGenerator, values: Array) -> Variant:
	if values.is_empty():
		return null
	return values[rng.randi_range(0, values.size() - 1)]

static func shuffled(rng: RandomNumberGenerator, values: Array) -> Array:
	var out: Array = values.duplicate()
	for index in range(out.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, index)
		var held: Variant = out[index]
		out[index] = out[swap]
		out[swap] = held
	return out

static func normal(rng: RandomNumberGenerator, mean: float, deviation: float) -> float:
	return rng.randfn(mean, deviation)

static func chance(rng: RandomNumberGenerator, percent: float) -> bool:
	return rng.randf() * 100.0 < percent
