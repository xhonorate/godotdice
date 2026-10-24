// Whole numbers the way sim/rules.gd keeps them. Godot's are 64-bit and this port's are
// doubles, exact up to 2^53, so every count is cut to a whole number with `I` (never `| 0`,
// which wraps at 2^31) and every count that can grow without end stops at CEILING, as the
// game's do (DeepRules.sat_*): a blow, a heal, block, a status's stacks, health, pyrite,
// Resonance. The view writes a count at the ceiling as Infinite.

export const CEILING = 1e15;

// A number cut toward nought, the way `int()` cuts one; nothing (NaN, undefined) is nought,
// and an infinity is the ceiling.
export function I(v) {
	const n = Math.trunc(Number(v));
	if (Number.isFinite(n)) return n;
	return n > 0 ? CEILING : n < 0 ? -CEILING : 0;
}

// A float rounded the way `roundi()` and `round()` round one: halves away from nought
// (Math.round sends -2.5 to -2, Godot to -3).
export const roundi = (f) => Math.sign(f) * Math.round(Math.abs(f));

export const sat = (v) => Math.max(-CEILING, Math.min(CEILING, v));
export const satAdd = (a, b) => sat(sat(a) + sat(b));

// a × b, exact whenever the answer is under the ceiling.
export function satMul(a, b) {
	const f = a * b;
	if (f >= CEILING) return CEILING;
	if (f <= -CEILING) return -CEILING;
	return f;
}

// A float as a whole number, rounded down.
export function satFloor(f) {
	if (Number.isNaN(f)) return 0;
	if (f >= CEILING) return CEILING;
	if (f <= -CEILING) return -CEILING;
	return Math.floor(f);
}

export const satMulDiv = (x, mul, div) => satScale(x, mul, 1, div);

// x × a × b ÷ div, cut toward nought. Exact: past 2^53 the product is worked in BigInt, as
// the game works it in 64-bit whole numbers.
export function satScale(x, a, b, div) {
	if (div === 0) return 0;
	const f = (x * a * b) / div;
	if (f >= CEILING) return CEILING;
	if (f <= -CEILING) return -CEILING;
	const product = x * a * b;
	if (Math.abs(product) < Number.MAX_SAFE_INTEGER) return Math.trunc(product / div);
	return Number((BigInt(x) * BigInt(a) * BigInt(b)) / BigInt(div));
}

export const infinite = (v) => Math.abs(v) >= CEILING;
