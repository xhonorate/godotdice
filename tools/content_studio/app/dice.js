// Dice: the icon, what one die's faces add up to, and what a hero's five dice roll into.
//
// The trigger names here are the ones skills actually test for — a pair, three of a kind,
// a straight of three, five distinct results — so a hand table read next to a hero tells
// you which gems that hero can realistically fire, before anyone plays a run.

const SHAPES = {
	D4: [[0, -1], [0.93, 0.62], [-0.93, 0.62]],
	D6: [[-0.82, -0.82], [0.82, -0.82], [0.82, 0.82], [-0.82, 0.82]],
	D8: [[0, -1], [0.95, 0], [0, 1], [-0.95, 0]],
	D10: [[0, -1], [0.88, -0.2], [0.55, 0.85], [-0.55, 0.85], [-0.88, -0.2]],
	D12: [[0, -1], [0.95, -0.31], [0.59, 0.81], [-0.59, 0.81], [-0.95, -0.31]],
	D20: [[0, -1], [0.87, -0.5], [0.87, 0.5], [0, 1], [-0.87, 0.5], [-0.87, -0.5]],
};
// The inner edges that make a flat silhouette read as a solid.
const CREASES = {
	D4: [[[0, -1], [0, 0.62]], [[-0.47, -0.02], [0.47, -0.02]]],
	D6: [[[-0.82, -0.3], [0.3, -0.3]], [[0.3, -0.3], [0.3, 0.82]], [[0.3, -0.3], [0.82, -0.82]]],
	D8: [[[-0.95, 0], [0.95, 0]], [[0, -1], [-0.42, 0.42]], [[0, -1], [0.42, 0.42]], [[-0.42, 0.42], [0.42, 0.42]]],
	D10: [[[0, -1], [-0.4, 0.3]], [[0, -1], [0.4, 0.3]], [[-0.4, 0.3], [0, 0.85]], [[0.4, 0.3], [0, 0.85]]],
	D12: [[[0, -0.42], [0, -1]], [[0, -0.42], [0.62, 0.05]], [[0, -0.42], [-0.62, 0.05]], [[0.62, 0.05], [0.36, 0.81]], [[-0.62, 0.05], [-0.36, 0.81]]],
	D20: [[[-0.5, -0.28], [0.5, -0.28]], [[-0.5, -0.28], [0, 0.56]], [[0.5, -0.28], [0, 0.56]], [[-0.5, -0.28], [-0.87, -0.5]], [[0.5, -0.28], [0.87, -0.5]], [[0, 0.56], [0, 1]]],
};

export const SHAPE_KEYS = Object.keys(SHAPES);
export const sidesOf = (shape) => parseInt(String(shape).replace("D", ""), 10) || 6;

export function drawDie(ctx, box, { shape = "D6", value = null, tint = "#e8b661", muted = false }) {
	const points = SHAPES[shape] || SHAPES.D6;
	const radius = (Math.min(box.w, box.h) / 2) * 0.9;
	const cx = box.x + box.w / 2, cy = box.y + box.h / 2;
	const project = ([x, y]) => [cx + x * radius, cy + y * radius];
	ctx.save();
	ctx.beginPath();
	points.forEach((point, index) => {
		const [px, py] = project(point);
		index === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
	});
	ctx.closePath();
	const gradient = ctx.createLinearGradient(cx, cy - radius, cx, cy + radius);
	gradient.addColorStop(0, muted ? "#243044" : "#2c3a52");
	gradient.addColorStop(1, muted ? "#141c2a" : "#161f2f");
	ctx.fillStyle = gradient;
	ctx.fill();
	ctx.strokeStyle = tint;
	ctx.lineWidth = 1.6;
	ctx.stroke();
	ctx.strokeStyle = "rgba(255,255,255,0.13)";
	ctx.lineWidth = 1;
	for (const [from, to] of CREASES[shape] || []) {
		ctx.beginPath();
		const [ax, ay] = project(from), [bx, by] = project(to);
		ctx.moveTo(ax, ay);
		ctx.lineTo(bx, by);
		ctx.stroke();
	}
	if (value !== null && value !== undefined) {
		ctx.fillStyle = "#eef1f7";
		ctx.font = `600 ${Math.round(radius * (String(value).length > 1 ? 0.78 : 0.95))}px ui-monospace, monospace`;
		ctx.textAlign = "center";
		ctx.textBaseline = "middle";
		ctx.fillText(String(value), cx, cy + radius * (shape === "D4" ? 0.22 : 0.04));
	}
	ctx.restore();
}

export function dieCanvas(options, size = 44) {
	const canvas = document.createElement("canvas");
	const ratio = window.devicePixelRatio || 1;
	canvas.width = size * ratio;
	canvas.height = size * ratio;
	canvas.style.width = `${size}px`;
	canvas.style.height = `${size}px`;
	const ctx = canvas.getContext("2d");
	ctx.scale(ratio, ratio);
	drawDie(ctx, { x: 0, y: 0, w: size, h: size }, options);
	return canvas;
}

// --- what one die is worth ----------------------------------------------------

export function faceStats(faces) {
	const values = (faces || []).map(Number).filter((value) => Number.isFinite(value));
	if (!values.length) return { mean: 0, min: 0, max: 0, distinct: 0, counts: new Map(), spread: 0 };
	const counts = new Map();
	for (const value of values) counts.set(value, (counts.get(value) || 0) + 1);
	const mean = values.reduce((sum, value) => sum + value, 0) / values.length;
	const variance = values.reduce((sum, value) => sum + (value - mean) ** 2, 0) / values.length;
	return {
		mean, min: Math.min(...values), max: Math.max(...values),
		distinct: counts.size, counts, spread: Math.sqrt(variance),
	};
}

/** Chance this single die shows each of the listed values, as a fraction. */
export function faceChance(faces, wanted) {
	const values = (faces || []).map(Number);
	if (!values.length) return 0;
	const hits = values.filter((value) => wanted.includes(value)).length;
	return hits / values.length;
}

// --- what five dice roll into -------------------------------------------------

const longestRun = (sorted) => {
	let best = 1, run = 1;
	for (let index = 1; index < sorted.length; index++) {
		if (sorted[index] === sorted[index - 1]) continue;
		run = sorted[index] === sorted[index - 1] + 1 ? run + 1 : 1;
		best = Math.max(best, run);
	}
	return best;
};

/**
 * Monte Carlo over the hand a set of dice produces. 20k samples lands every probability
 * within about half a percentage point, which is far finer than any balance decision.
 */
export function handStats(diceFaces, samples = 20000) {
	const pools = diceFaces.filter((faces) => faces && faces.length);
	const tally = {
		pair: 0, twoPairs: 0, triple: 0, fullHouse: 0, straight3: 0, straight4: 0, straight5: 0,
		threeEven: 0, threeOdd: 0, distinct5: 0, anySeven: 0, totals: [], highs: [],
	};
	if (!pools.length) return { samples: 0, ...tally, meanTotal: 0, meanHigh: 0, chance: () => 0 };
	for (let sample = 0; sample < samples; sample++) {
		const rolled = pools.map((faces) => Number(faces[(Math.random() * faces.length) | 0]));
		const sorted = rolled.slice().sort((a, b) => a - b);
		const counts = new Map();
		for (const value of rolled) counts.set(value, (counts.get(value) || 0) + 1);
		const groups = [...counts.values()].sort((a, b) => b - a);
		const total = rolled.reduce((sum, value) => sum + value, 0);
		const run = longestRun(sorted);
		if (groups[0] >= 2) tally.pair += 1;
		if (groups.filter((size) => size >= 2).length >= 2) tally.twoPairs += 1;
		if (groups[0] >= 3) tally.triple += 1;
		if (groups[0] >= 3 && groups[1] >= 2) tally.fullHouse += 1;
		if (run >= 3) tally.straight3 += 1;
		if (run >= 4) tally.straight4 += 1;
		if (run >= 5) tally.straight5 += 1;
		if (rolled.filter((value) => value % 2 === 0).length >= 3) tally.threeEven += 1;
		if (rolled.filter((value) => value % 2 === 1).length >= 3) tally.threeOdd += 1;
		if (counts.size === rolled.length) tally.distinct5 += 1;
		if (rolled.includes(7)) tally.anySeven += 1;
		tally.totals.push(total);
		tally.highs.push(sorted[sorted.length - 1]);
	}
	const mean = (list) => list.reduce((sum, value) => sum + value, 0) / list.length;
	const sortedTotals = tally.totals.slice().sort((a, b) => a - b);
	return {
		samples,
		meanTotal: mean(tally.totals),
		meanHigh: mean(tally.highs),
		medianTotal: sortedTotals[(sortedTotals.length / 2) | 0],
		lowTotal: sortedTotals[(sortedTotals.length * 0.1) | 0],
		highTotal: sortedTotals[(sortedTotals.length * 0.9) | 0],
		rate: (name) => tally[name] / samples,
		atLeastTotal: (threshold) => tally.totals.filter((value) => value >= threshold).length / samples,
		atMostTotal: (threshold) => tally.totals.filter((value) => value <= threshold).length / samples,
		highAtLeast: (threshold) => tally.highs.filter((value) => value >= threshold).length / samples,
	};
}

/** The trigger each tag stands for, so a skill's odds can be read off a hand table. */
export const TAG_TRIGGERS = {
	pair: "pair", two_pairs: "twoPairs", triple: "triple", full_house: "fullHouse",
	straight: "straight3", even: "threeEven", odd: "threeOdd", distinct: "distinct5", seven: "anySeven",
};
