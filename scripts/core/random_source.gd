class_name RogueRandom
extends RefCounted
## All simulation randomness comes from the authority's single saved RNG.

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

static func skew_pick(rng: RandomNumberGenerator, values: Array, skew: float) -> Variant:
	if values.is_empty():
		return null
	return values[mini(int(pow(rng.randf(), skew) * values.size()), values.size() - 1)]

static func luck_weights(luck: int) -> Array:
	var depth: int = clampi(luck, 0, 20)
	var starts: Array = [-4, 0, 1, 4, 7]
	var ends: Array = [20, 21, 22, 27, 99]
	var factors: Array = [5.0, 4.0, 2.5, 1.5, 1.0]
	var weights: Array = []
	for index in range(5):
		weights.append(factors[index] * maxi(0, mini(ends[index] - depth, depth - starts[index])))
	return weights

static func rarity(rng: RandomNumberGenerator, luck: int) -> int:
	return weighted_index(rng, luck_weights(luck)) + 1
