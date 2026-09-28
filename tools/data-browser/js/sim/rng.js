// A small seeded generator, so every chart in the browser is reproducible from its seed.
// This is not the game's RNG (Godot's is a PCG32 with its own seeding); the distributions
// it feeds are the game's, and only the sample order differs.

export function makeRng(seed = 1) {
	let s = (seed >>> 0) || 0x9e3779b9;
	const next = () => {
		s = (s + 0x6d2b79f5) >>> 0;
		let t = s;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
	let spare = null;
	const rng = {
		randf: next,
		randiRange(low, high) { return low + Math.floor(next() * (high - low + 1)); },
		chance(percent) { return next() * 100 < percent; },
		randfn(mean, deviation) {
			// Box-Muller, the way Godot's randfn works out to.
			if (spare !== null) { const v = spare; spare = null; return mean + deviation * v; }
			let u = 0, v = 0;
			while (u === 0) u = next();
			v = next();
			const mag = Math.sqrt(-2 * Math.log(u));
			spare = mag * Math.sin(2 * Math.PI * v);
			return mean + deviation * mag * Math.cos(2 * Math.PI * v);
		},
		weightedIndex(weights) {
			let total = 0;
			for (const w of weights) total += Math.max(0, w);
			if (total <= 0) return -1;
			let draw = next() * total;
			for (let i = 0; i < weights.length; i++) {
				draw -= Math.max(0, weights[i]);
				if (draw < 0) return i;
			}
			return weights.length - 1;
		},
		weightedKey(table) {
			const keys = Object.keys(table).sort();
			const index = rng.weightedIndex(keys.map((k) => Number(table[k])));
			return index >= 0 ? keys[index] : '';
		},
		pick(values) { return values.length ? values[Math.floor(next() * values.length)] : null; },
	};
	return rng;
}
