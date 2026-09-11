// The gem, drawn the way the game cuts it.
//
// This is a port of `scripts/ui/gem_mesh.gd`: the same outlines per Color, the same
// miscut per Cut, the same body colour per Clarity, the same facet hash. It builds the
// same rings of facets and projects them straight down the view axis instead of handing
// them to a renderer, so a stone in this panel is the stone the game will cut — not an
// illustration of one that happens to be the right hue.

export const CUTS = { RED: "trilliant", BLUE: "princess", GREEN: "heart", VIOLET: "pear", GOLD: "dutch_rose", WHITE: "round" };
export const SHAPE_NAMES = { trilliant: "trilliant", princess: "princess", heart: "heart", pear: "pear", dutch_rose: "half Dutch rose", round: "round brilliant" };
// A rose cut is not a brilliant: almost no table, a taller crown, and a flat back.
const SHAPE_TABLE = { dutch_rose: 0.3 };
const SHAPE_CROWN = { dutch_rose: 1.25 };
const SHAPE_PAVILION = { dutch_rose: 0.4 };

const EDGE_STEPS = [1, 1, 1, 1, 1];
const CROWN_BANDS = [1, 1, 1, 1, 1];
const PAVILION_BANDS = [1, 2, 2, 2, 2];
const TABLE_SPAN = [0.72, 0.66, 0.62, 0.59, 0.56];
const CUT_WANDER = [0.16, 0.1, 0.05, 0.04, 0.0];
const CUT_CHIPS = [3, 2, 1, 0, 0];
const CUT_CROWN = [0.55, 0.7, 0.84, 0.93, 1.0];
const CUT_DEPTH = [0.72, 0.82, 0.9, 0.96, 1.0];
const CROWN_HEIGHT = 0.34;
const GIRDLE = 0.055;
const PAVILION_DEPTH = 0.74;
// The shipped values of the two tuning knobs that are baked into the solid.
const GREY_PULL = 0.32;
const FACET_SWING = 1.0;
const FACET_HUE = 0.6;

export const CUT_NAMES = ["Poor", "Fair", "Good", "Great", "Perfect"];
export const CLARITY_NAMES = ["Fractured", "Flawed", "Clean", "Pristine", "Flawless"];

const clamp = (value, low, high) => Math.min(high, Math.max(low, value));
const lerp = (from, to, t) => from + (to - from) * t;

// --- the four properties as numbers ------------------------------------------

export function caratSpan(carat) {
	const t = (clamp(Math.round(carat), 1, 24) - 1) / 23.0;
	return 0.85 + 0.33 * Math.pow(t, 0.62) + 0.47 * Math.pow(t, 8.0);
}
export const brilliance = (clarity) => (clamp(Math.round(clarity), 1, 5) - 1) / 4.0;
export const flawCount = (clarity) => [5, 3, 1, 0, 0][clamp(Math.round(clarity), 1, 5) - 1];

export function facetCount(cut, colorKey) {
	const k = clamp(Math.round(cut), 1, 5);
	const around = silhouette(colorKey).length * EDGE_STEPS[k - 1];
	return around * 2 * (CROWN_BANDS[k - 1] + PAVILION_BANDS[k - 1]) + around;
}

// --- colour ------------------------------------------------------------------

export function hexToRgb(hex) {
	const value = parseInt(String(hex).replace("#", ""), 16);
	return [((value >> 16) & 255) / 255, ((value >> 8) & 255) / 255, (value & 255) / 255];
}
export const rgbToCss = (c, alpha = 1) =>
	`rgba(${Math.round(clamp(c[0], 0, 1) * 255)},${Math.round(clamp(c[1], 0, 1) * 255)},${Math.round(clamp(c[2], 0, 1) * 255)},${alpha})`;

const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
const lightened = (c, amount) => c.map((v) => v + (1 - v) * amount);
const darkened = (c, amount) => c.map((v) => v * (1 - amount));

function rgbToHsv([r, g, b]) {
	const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
	let h = 0;
	if (d > 0) {
		if (max === r) h = ((g - b) / d) % 6;
		else if (max === g) h = (b - r) / d + 2;
		else h = (r - g) / d + 4;
		h /= 6;
		if (h < 0) h += 1;
	}
	return [h, max === 0 ? 0 : d / max, max];
}
function hsvToRgb(h, s, v) {
	const i = Math.floor(h * 6), f = h * 6 - i;
	const p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
	return [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][((i % 6) + 6) % 6];
}

export function bodyColour(hex, clarity) {
	const b = brilliance(clarity);
	return mix(mix(hexToRgb(hex), hexToRgb("6d7280"), lerp(GREY_PULL, 0.0, b)), [0, 0, 0], lerp(0.18, 0.0, b));
}

// --- the engine's own hashes, so the same stone comes out ---------------------

export function godotStringHash(text) {
	// djb2, as String.hash() does it, returned as an unsigned 32-bit value.
	let hash = 5381n;
	for (const char of String(text)) hash = ((hash * 33n) + BigInt(char.codePointAt(0))) & 0xffffffffn;
	// Back to a Number: it fits exactly, and every seed below is a plain integer plus an offset.
	return Number(hash);
}
function hash01(seed) {
	let mixed = ((BigInt(seed) * 1103515245n + 12345n) & 0x7fffffffn);
	mixed = ((mixed ^ (mixed >> 13n)) * 1274126177n) & 0x7fffffffffffffffn;
	return Number((mixed ^ (mixed >> 16n)) & 0xffffn) / 65535.0;
}

// --- outlines ----------------------------------------------------------------

const wound = (points) => {
	let area = 0;
	for (let i = 0; i < points.length; i++) {
		const a = points[i], b = points[(i + 1) % points.length];
		area += a[0] * b[1] - b[0] * a[1];
	}
	return area >= 0 ? points : points.slice().reverse();
};
const regular = (sides, turn) => {
	const built = [];
	for (let i = 0; i < sides; i++) {
		const angle = turn + (Math.PI * 2 * i) / sides;
		built.push([Math.cos(angle), Math.sin(angle)]);
	}
	return built;
};
const pointLerp = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t)];
const truncated = (points, amount) => {
	const built = [], count = points.length;
	for (let i = 0; i < count; i++) {
		built.push(pointLerp(points[i], points[(i + count - 1) % count], amount));
		built.push(pointLerp(points[i], points[(i + 1) % count], amount));
	}
	return built;
};
function heart() {
	const raw = [];
	let peak = 0;
	for (let i = 0; i < 24; i++) {
		const t = (Math.PI * 2 * i) / 24;
		const point = [16 * Math.pow(Math.sin(t), 3),
			13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t)];
		raw.push(point);
		peak = Math.max(peak, Math.hypot(point[0], point[1]));
	}
	return raw.map(([x, y]) => [x / peak, y / peak]);
}
function pear() {
	// The teardrop curve: squaring the half-angle pulls the shoulders in to a point while
	// the belly stays round. The first sample lands exactly on the tip.
	const built = [], steps = 20;
	for (let i = 0; i < steps; i++) {
		const t = (Math.PI * 2 * i) / steps;
		built.push([Math.sin(t) * Math.pow(Math.sin(t * 0.5), 2), Math.cos(t)]);
	}
	return built;
}

export function silhouette(colorKey) {
	switch (CUTS[colorKey] || "round") {
		case "trilliant": return wound(truncated(regular(3, -Math.PI * 0.5), 0.17));
		case "princess": return wound(truncated(regular(4, Math.PI * 0.25), 0.2));
		case "heart": return wound(heart());
		case "pear": return wound(pear());
		// Six segments over one crown band is the twelve-facet dome the cut is named for.
		case "dutch_rose": return wound(regular(6, -Math.PI * 0.5));
	}
	return wound(regular(20, -Math.PI * 0.5));
}

function miscut(points, wander, chips, seed) {
	if (wander <= 0 && chips <= 0) return points;
	const count = points.length, nicked = new Set();
	for (let i = 0; i < chips; i++) nicked.add(Math.trunc(hash01(seed + 419 + i) * count));
	return points.map((point, index) => {
		let pull = 1.0 - wander * (hash01(seed + 233 + index) - 0.32);
		if (nicked.has(index)) pull -= 0.11 + 0.1 * hash01(seed + 601 + index);
		const scale = Math.max(pull, 0.34);
		return [point[0] * scale, point[1] * scale];
	});
}

export function girdle(colorKey, cut, key) {
	const k = clamp(Math.round(cut), 1, 5);
	const seed = godotStringHash(key || "");
	return miscut(silhouette(colorKey), CUT_WANDER[k - 1], CUT_CHIPS[k - 1], seed);
}

// --- the cut solid ------------------------------------------------------------

const ring = (base, span, height, staggered) =>
	base.map((point, index) => {
		const used = staggered ? pointLerp(point, base[(index + 1) % base.length], 0.5) : point;
		return [used[0] * span, used[1] * span, height];
	});

/** Every facet of the stone, as projected triangles with the tone the mesh bakes in. */
export function buildFacets({ colorKey, hex, carat = 1, cut = 1, clarity = 1, key = "" }) {
	const k = clamp(Math.round(cut), 1, 5);
	const l = clamp(Math.round(clarity), 1, 5);
	const seed = godotStringHash(key);
	const base = girdle(colorKey, k, key);
	const count = base.length;
	const shape = CUTS[colorKey] || "round";
	const crown = CROWN_BANDS[k - 1], pavilion = PAVILION_BANDS[k - 1];
	const tableWidth = TABLE_SPAN[k - 1] * (SHAPE_TABLE[shape] ?? 1.0);
	const crownHeight = CROWN_HEIGHT * CUT_CROWN[k - 1] * (SHAPE_CROWN[shape] ?? 1.0);
	const pavilionDepth = PAVILION_DEPTH * CUT_DEPTH[k - 1] * (SHAPE_PAVILION[shape] ?? 1.0);
	const body = bodyColour(hex, l);

	const flawed = new Set();
	for (let i = 0; i < flawCount(l); i++)
		flawed.add(Math.trunc(hash01(seed + 31 + i) * count * (crown + pavilion) * 2));

	const rings = [];
	for (let band = 0; band <= crown; band++) {
		const t = band / crown;
		rings.push(ring(base, lerp(tableWidth, 1.0, t), lerp(crownHeight, 0.0, t), band % 2 === 1 && band < crown));
	}
	rings.push(ring(base, 1.0, -GIRDLE, false));
	for (let band = 1; band <= pavilion; band++) {
		const t = band / pavilion;
		rings.push(ring(base, lerp(1.0, 0.16, t), lerp(-GIRDLE, -pavilionDepth, t), band % 2 === 1 && band < pavilion));
	}

	const faces = [];
	const table = rings[0];
	const middle = [0, 0, crownHeight];
	for (let i = 0; i < count; i++)
		faces.push({ points: [middle, table[i], table[(i + 1) % count]], tone: lightened(body, 0.1), part: "table" });

	let facet = 0;
	for (let band = 0; band < rings.length - 1; band++) {
		const upper = rings[band], lower = rings[band + 1];
		for (let i = 0; i < count; i++) {
			const a = upper[i], b = upper[(i + 1) % count], c = lower[(i + 1) % count], d = lower[i];
			for (const triangle of [[a, d, b], [b, d, c]]) {
				let tone = body;
				const swing = (hash01(seed + facet) - 0.5) * FACET_SWING;
				tone = swing >= 0 ? lightened(tone, swing) : darkened(tone, -swing);
				if (FACET_HUE > 0.001) {
					const [h, s, v] = rgbToHsv(tone);
					tone = hsvToRgb((((h + (hash01(seed + 977 + facet) - 0.5) * FACET_HUE) % 1) + 1) % 1, s, v);
				}
				if (flawed.has(facet)) tone = darkened(tone, 0.55);
				faces.push({ points: triangle, tone, part: band < crown + 1 ? "crown" : "pavilion" });
				facet += 1;
			}
		}
	}
	const last = rings[rings.length - 1];
	const culet = [0, 0, -pavilionDepth];
	for (let i = 0; i < count; i++)
		faces.push({ points: [culet, last[(i + 1) % count], last[i]], tone: darkened(body, 0.28), part: "pavilion" });
	return faces;
}

const LIGHT = (() => {
	const v = [-0.38, -0.62, 0.68];
	const length = Math.hypot(...v);
	return v.map((n) => n / length);
})();

function normalOf([a, b, c]) {
	const u = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
	const v = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
	const n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
	const length = Math.hypot(...n) || 1;
	return n.map((value) => value / length);
}

/**
 * Draws the stone into a 2D context, front on. The pavilion goes down first and the
 * crown over it at less than full alpha, which is how the game's two passes read: what
 * you see through the front of a clean stone is its own back facets.
 */
export function drawGem(ctx, box, gem) {
	const { colorKey, hex, carat = 1, cut = 1, clarity = 1, key = "" } = gem;
	const faces = buildFacets({ colorKey, hex, carat, cut, clarity, key });
	const l = clamp(Math.round(clarity), 1, 5);
	const span = caratSpan(carat) / caratSpan(24);
	const radius = (Math.min(box.w, box.h) / 2) * 0.94 * lerp(0.46, 1.0, span);
	const centre = { x: box.x + box.w / 2, y: box.y + box.h / 2 };
	const project = ([x, y, z]) => [centre.x + x * radius, centre.y - y * radius - z * radius * 0.12];
	const frontAlpha = lerp(0.85, 0.35, brilliance(l));

	ctx.save();
	ctx.lineJoin = "round";
	for (const pass of ["pavilion", "crown", "table"]) {
		for (const face of faces) {
			if (face.part !== pass) continue;
			const normal = normalOf(face.points);
			const facing = normal[2];
			if (pass !== "pavilion" && facing <= 0.001) continue;
			if (pass === "pavilion" && facing >= -0.001 && Math.abs(facing) > 0.9) continue;
			const lambert = Math.max(0, normal[0] * LIGHT[0] + normal[1] * LIGHT[1] + normal[2] * LIGHT[2]);
			const specular = Math.pow(lambert, 26) * lerp(0.35, 0.95, brilliance(l));
			let tone = mix(darkened(face.tone, pass === "pavilion" ? 0.47 : 0.0), [1, 1, 1], 0.12 * lambert + specular);
			tone = mix(tone, lightened(face.tone, 0.25), 0.22 * Math.pow(1 - Math.abs(facing), 2));
			ctx.beginPath();
			const [sx, sy] = project(face.points[0]);
			ctx.moveTo(sx, sy);
			for (const point of face.points.slice(1)) {
				const [px, py] = project(point);
				ctx.lineTo(px, py);
			}
			ctx.closePath();
			ctx.fillStyle = rgbToCss(tone, pass === "pavilion" ? 0.9 : frontAlpha + 0.35);
			ctx.fill();
			ctx.strokeStyle = rgbToCss(darkened(tone, 0.45), 0.5);
			ctx.lineWidth = 0.6;
			ctx.stroke();
		}
	}
	// The girdle, so the widest point reads as an edge rather than where two fills meet.
	const outline = girdle(colorKey, cut, key);
	ctx.beginPath();
	outline.forEach((point, index) => {
		const [px, py] = project([point[0], point[1], -GIRDLE]);
		index === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
	});
	ctx.closePath();
	ctx.strokeStyle = rgbToCss(lightened(bodyColour(hex, l), 0.55), 0.7);
	ctx.lineWidth = 1.3;
	ctx.stroke();
	ctx.restore();
}

/** One stone on its own canvas, sized in CSS pixels and sharp on a high-density screen. */
export function gemCanvas(gem, size = 96) {
	const canvas = document.createElement("canvas");
	const ratio = window.devicePixelRatio || 1;
	canvas.width = size * ratio;
	canvas.height = size * ratio;
	canvas.style.width = `${size}px`;
	canvas.style.height = `${size}px`;
	const ctx = canvas.getContext("2d");
	ctx.scale(ratio, ratio);
	drawGem(ctx, { x: 0, y: 0, w: size, h: size }, gem);
	return canvas;
}
