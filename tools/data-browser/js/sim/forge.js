// Where stones, dice and encounters come out of the rock: a port of sim/forge.gd, plus the
// exact distributions behind its rolls so the browser can chart odds without sampling.

import * as C from './content.js';
import * as Dice from './dice.js';
import * as Stone from './stone.js';

export const DEFAULT_CLASS_WEIGHTS = { PINPOINT: 10, LENS: 6, FEATHER: 4, FRACTURE: 3, STAR: 0.3 };
export const JACKPOT_PERCENT = 2;
export const LUCK_PER_DEPTH = 0.5;
// A mine's carat band (sim/forge.gd): luck levels off below the usual top, each carat past it
// holds BAND_KEEP_PERCENT of the time, and nothing comes out over the cap.
export const BAND_SPREAD = 1.2;
export const BAND_LUCK_SPAN = 8;
export const BAND_KEEP_PERCENT = 35;
export const HOME_BATCH_WEIGHT = 2;
export const LUCK_DEPTH_CAP = 10;

export const mineLuck = (mine) => Number(mine.luck ?? mine.quality ?? 0);
export const quality = (depth, bonus = 0) => Math.min(depth * LUCK_PER_DEPTH, LUCK_DEPTH_CAP) + bonus;
export const luck = (mine, depth, bonus = 0) => quality(depth, mineLuck(mine) + bonus);

export function caratParams(q) {
	return { mean: Math.max(1, 1.5 + q * 0.5), deviation: Math.max(1, 1.6 + q * 0.08) };
}

function normalCdf(x) {
	// Abramowitz-Stegun 7.1.26, good to ~1e-7.
	const sign = x < 0 ? -1 : 1;
	const z = Math.abs(x) / Math.SQRT2;
	const t = 1 / (1 + 0.3275911 * z);
	const erf = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-z * z);
	return 0.5 * (1 + sign * erf);
}

// {soft, cap} for a mine at a depth, or null for a mine that writes no band. An endless
// mine's band climbs with every Warden stationed above the depth.
export function caratBand(mine, depth) {
	const band = mine.carat || null;
	if (!band) return null;
	let soft = Number(band.soft ?? Stone.caratMax());
	let cap = Number(band.cap ?? Stone.caratMax());
	if (mine.endless) {
		const climbed = Math.trunc(Math.max(0, depth - 1) / Math.max(1, Number(mine.warden_every ?? 8))) * Number(mine.carat_per_warden ?? 0);
		soft += climbed;
		cap += climbed;
	}
	cap = Math.max(1, Math.min(cap, Stone.caratMax()));
	return { soft: Math.max(1, Math.min(soft, cap)), cap };
}

function rawCarats(mean, deviation, max) {
	// A rounded normal with a 2% jackpot of +1..2, before any clamping: [{k, p}].
	const lowK = Math.floor(mean - 8 * deviation) - 1;
	const highK = Math.ceil(mean + 8 * deviation) + 1;
	const out = new Map();
	const add = (k, p) => out.set(k, (out.get(k) || 0) + p);
	for (let k = lowK; k <= highK; k++) {
		let p = normalCdf((k + 0.5 - mean) / deviation) - normalCdf((k - 0.5 - mean) / deviation);
		if (k === lowK) p = normalCdf((k + 0.5 - mean) / deviation);
		if (k === highK) p = 1 - normalCdf((k - 0.5 - mean) / deviation);
		if (p <= 0) continue;
		add(k, p * (1 - JACKPOT_PERCENT / 100));
		for (let bonus = 1; bonus <= 2; bonus++) add(k + bonus, (p * (JACKPOT_PERCENT / 100)) / 2);
	}
	return out;
}

// The exact chance of each carat count at luck q, inside a mine's band when it has one.
export function caratDistribution(q, band = null) {
	const max = Stone.caratMax();
	if (band) {
		const top = Math.max(1.5, band.soft - 0.5);
		const mean = 1.5 + (top - 1.5) * (1 - Math.exp(-Math.max(q, 0) / BAND_LUCK_SPAN));
		const out = new Array(max + 1).fill(0);
		const keep = BAND_KEEP_PERCENT / 100;
		for (const [k, p] of rawCarats(mean, BAND_SPREAD, max)) {
			if (k <= band.soft) { out[Math.max(1, Math.min(band.cap, k))] += p; continue; }
			// Each carat past the soft line holds with `keep`; the first that does not stops it.
			let reach = band.soft;
			let still = p;
			while (reach < k) {
				out[Math.min(band.cap, reach)] += still * (1 - keep);
				still *= keep;
				reach += 1;
			}
			out[Math.min(band.cap, k)] += still;
		}
		const sum = out.reduce((a, b) => a + b, 0);
		return out.map((p) => p / sum);
	}
	const { mean, deviation } = caratParams(q);
	const out = new Array(max + 1).fill(0);
	const clamp = (k) => Math.max(1, Math.min(max, k));
	for (const [k, p] of rawCarats(mean, deviation, max)) out[clamp(k)] += p;
	const sum = out.reduce((a, b) => a + b, 0);
	return out.map((p) => p / sum);
}

export function cutWeights(q) {
	return C.cuts().map((cut, index) => Number(cut.weight ?? 1) * Math.max(0.08, 1 + q * 0.06 * (index - 2)));
}
export function clarityWeights(q) {
	const clear = C.clearIndex();
	return C.clarities().map((clarity, index) => { const d = Math.abs(index - clear); return Number(clarity.weight ?? 1) * Math.max(0.06, 1 + q * 0.025 * d * d); });
}
export const normalize = (weights) => { const s = weights.reduce((a, b) => a + b, 0) || 1; return weights.map((w) => w / s); };

// What the rock here can hold: a list the mine writes in full, or else its own batch and the
// batches of every mine above it. A skill in no batch is in every pool.
export function batchTiers() {
	const out = {};
	for (const key of C.keys('mines')) {
		const def = C.mine(key);
		for (const skill of def.batch || []) out[skill] = Number(def.tier ?? 1);
	}
	return out;
}
export function skillPool(mine) {
	const listed = mine.skills || [];
	if (listed.length) return listed.map(String);
	const keys = C.keys('skills');
	const batched = batchTiers();
	if (!Object.keys(batched).length) return keys;
	const tier = Number(mine.tier ?? 1);
	return keys.filter((k) => !(k in batched) || batched[k] <= tier);
}
export function inclusionPool(mine) {
	const listed = mine.inclusions || [];
	return listed.length ? listed.map(String) : C.keys('inclusions');
}

// {skill: weight} for the rock's ordinary table. Opals weigh nothing here.
export function skillTable(mine, pool = []) {
	const keys = pool.length ? pool : skillPool(mine);
	const colorWeights = mine.color_weights || {};
	const table = {};
	for (const key of keys) {
		const skill = C.skill(key);
		if (!Object.keys(skill).length) continue;
		let weight = C.rarityWeight(skill.rarity || 'COMMON');
		weight *= Number(colorWeights[skill.color] ?? 100) / 100;
		if ((mine.batch || []).includes(key)) weight *= HOME_BATCH_WEIGHT;
		table[key] = weight;
	}
	let total = 0;
	for (const k in table) total += table[k];
	if (total <= 0) for (const k in table) table[k] = 1;
	return table;
}

export function zoningColor(def) {
	for (const m of def.modifiers || []) if (m && m.kind === 'color_also') return String(m.color || '');
	return '';
}

// The weight each inclusion carries in the draw, after the class defaults and the own-colour rule.
export function inclusionWeights(mine, ownColor = '', forcedClass = '') {
	const table = {};
	for (const key of inclusionPool(mine)) {
		const def = C.inclusion(key);
		if (!Object.keys(def).length) continue;
		const cls = String(def.class || 'PINPOINT');
		if (forcedClass && cls !== forcedClass) continue;
		if (ownColor && zoningColor(def) === ownColor) continue;
		table[key] = Number(def.weight ?? DEFAULT_CLASS_WEIGHTS[cls] ?? 1);
	}
	return table;
}

// The exact chance each inclusion ends up in a stone with `slots` slots: sequential draws
// without replacement from the weighted table.
export function inclusionOdds(slots, mine, ownColor = '') {
	const table = inclusionWeights(mine, ownColor);
	const keys = Object.keys(table);
	const odds = Object.fromEntries(keys.map((k) => [k, 0]));
	if (slots <= 0 || !keys.length) return odds;
	const walk = (taken, probability, depth) => {
		if (depth >= slots) return;
		let total = 0;
		for (const k of keys) if (!taken.has(k)) total += table[k];
		if (total <= 0) return;
		for (const k of keys) {
			if (taken.has(k)) continue;
			const p = (probability * table[k]) / total;
			odds[k] += p;
			if (depth + 1 < slots) { taken.add(k); walk(taken, p, depth + 1); taken.delete(k); }
		}
	};
	walk(new Set(), 1, 0);
	return odds;
}

export function rollCarat(rng, q, band = null) {
	if (!band) {
		const { mean, deviation } = caratParams(q);
		let carat = Math.round(rng.randfn(mean, deviation));
		if (rng.chance(JACKPOT_PERCENT)) carat += rng.randiRange(1, 2);
		return Math.max(1, Math.min(carat, Stone.caratMax()));
	}
	const top = Math.max(1.5, band.soft - 0.5);
	const mean = 1.5 + (top - 1.5) * (1 - Math.exp(-Math.max(q, 0) / BAND_LUCK_SPAN));
	let drawn = Math.round(rng.randfn(mean, BAND_SPREAD));
	if (rng.chance(JACKPOT_PERCENT)) drawn += rng.randiRange(1, 2);
	if (drawn > band.soft) {
		let held = band.soft;
		while (held < drawn && rng.chance(BAND_KEEP_PERCENT)) held += 1;
		drawn = held;
	}
	return Math.max(1, Math.min(drawn, band.cap));
}
export const rollCut = (rng, q) => Math.max(0, rng.weightedIndex(cutWeights(q)));
export const rollClarity = (rng, q) => Math.max(0, rng.weightedIndex(clarityWeights(q)));

export function rollInclusions(rng, count, mine, forcedClass = '', ownColor = '') {
	const out = [];
	const pool = inclusionPool(mine);
	for (let slot = 0; slot < count; slot++) {
		const table = {};
		for (const key of pool) {
			if (out.includes(key)) continue;
			const def = C.inclusion(key);
			if (!Object.keys(def).length) continue;
			const cls = String(def.class || 'PINPOINT');
			if (forcedClass && cls !== forcedClass) continue;
			if (ownColor && zoningColor(def) === ownColor) continue;
			table[key] = Number(def.weight ?? DEFAULT_CLASS_WEIGHTS[cls] ?? 1);
		}
		const picked = rng.weightedKey(table);
		if (!picked) break;
		out.push(picked);
	}
	return out;
}

export function rollStone(rng, mine, depth, bonus = 0, pool = []) {
	const q = luck(mine, depth, bonus);
	const skill = rng.weightedKey(skillTable(mine, pool));
	const carat = rollCarat(rng, q, caratBand(mine, depth));
	const cut = rollCut(rng, q);
	const clarity = rollClarity(rng, q);
	const inclusions = rollInclusions(rng, Stone.inclusionSlots(clarity), mine, '', String(C.skill(skill).color || ''));
	return Stone.make(skill, carat, cut, clarity, inclusions);
}

// A die is a shape and one or two variations, never none and never all three.
export const ONE_AXIS_PERCENT = 60;
export const AXIS_WEIGHTS = { pattern: 45, etching: 35, material: 20 };
export const PATTERN_MULT = 1.25;
export const ETCH_MULT = 1.5;
export const BANE_MULT = 0.6;
export const MATERIAL_MULT = 2;
export const PATTERN_PRICE = { stretched: 1.4 };
export const MATERIAL_PRICE = { glass: 1.75, opal: 3 };
// How much likelier a second variation gets the deeper the die is found.
export const secondAxisChance = (mine, depth) => luck(mine, depth);

export function dieTable(mine, shapes = []) {
	const narrowed = shapes.filter((k) => Dice.SHAPES[String(k)]);
	const pool = narrowed.length ? narrowed.map(String) : shapePool(mine);
	const table = {};
	for (const key of pool) { const def = C.die(key); table[key] = Object.keys(def).length ? C.rarityWeight(def.rarity || 'COMMON') : 1; }
	return table;
}

export function shapePool(mine) {
	const pool = (mine.dice || []).map(String).filter((k) => Dice.SHAPES[k]);
	return pool.length ? pool : Dice.TIERS.slice();
}

function rarityTable(section, allow = null) {
	const table = {};
	for (const key of C.keys(section)) {
		const def = C.entry(section, key);
		const written = String(def.key || '');
		if (!written || (allow && !allow(written, def))) continue;
		table[written] = C.rarityWeight(def.rarity || 'COMMON');
	}
	return table;
}

export const patternTable = (shape) => rarityTable('patterns', (key) => Dice.patternAllows(key, shape));
export const etchingTable = (bane = false) => rarityTable('etchings', (_key, def) => Boolean(def.bane) === bane);
export const materialTable = () => rarityTable('materials');

export function rollPattern(rng, shape) {
	const table = patternTable(shape);
	return Object.keys(table).length ? rng.weightedKey(table) : '';
}

export function rollEtching(rng, bane = false) {
	const table = etchingTable(bane);
	return Object.keys(table).length ? rng.weightedKey(table) : '';
}

export function rollMaterial(rng) {
	const table = materialTable();
	return Object.keys(table).length ? rng.weightedKey(table) : '';
}

export function rollAxes(rng) {
	const wanted = rng.randf() * 100 < ONE_AXIS_PERCENT ? 1 : 2;
	const table = { ...AXIS_WEIGHTS };
	const picked = [];
	while (picked.length < wanted && Object.keys(table).length) {
		const axis = rng.weightedKey(table);
		picked.push(axis);
		delete table[axis];
	}
	return picked;
}

export function vary(die, axes, rng) {
	for (const axis of axes) {
		if (axis === 'pattern') {
			const pattern = rollPattern(rng, die.shape);
			if (pattern) {
				const made = Dice.make(die.shape, die.id, { pattern, rng, material: die.material || '', etches: Dice.etchings(die) });
				for (const key of Object.keys(die)) delete die[key];
				Object.assign(die, made);
			}
		} else if (axis === 'etching') {
			const kind = rollEtching(rng);
			if (kind && (die.faces || []).length) Dice.etch(die, rng.randiRange(0, die.faces.length - 1), kind);
		} else if (axis === 'material') {
			die.material = rollMaterial(rng);
		}
	}
	return die;
}

export function rollDie(rng, mine, depth, id = 'die', shapes = []) {
	const shape = rng.weightedKey(dieTable(mine, shapes));
	const die = Dice.make(shape, id, { rng });
	const axes = rollAxes(rng);
	if (axes.length === 1 && rng.randf() * 100 < secondAxisChance(mine, depth)) {
		for (const extra of rollAxes(rng)) if (!axes.includes(extra)) { axes.push(extra); break; }
	}
	return vary(die, axes, rng);
}

export function diePrice(die) {
	let base = Number(C.die(String(die.shape || 'D6')).price ?? 10);
	if (die.pattern) base *= Number(PATTERN_PRICE[die.pattern] ?? PATTERN_MULT);
	for (const entry of Dice.etchings(die)) base *= Dice.BANE_FACES.includes(entry.kind) ? BANE_MULT : ETCH_MULT;
	if (die.material) base *= Number(MATERIAL_PRICE[die.material] ?? MATERIAL_MULT);
	return Math.max(1, Math.round(base));
}

export function bandFor(mine, depth) {
	let chosen = null;
	for (const band of mine.bands || []) if (Number(band.from_depth ?? 1) <= depth) chosen = band;
	if (!chosen && (mine.bands || []).length) chosen = mine.bands[0];
	return chosen || { creatures: {} };
}

export function encounterBudget(depth, party, elite) {
	let budget = (3 + depth * 0.6) * (0.55 + 0.45 * Math.max(1, Math.min(4, party)));
	if (elite) budget *= 1.5;
	return budget;
}

export function encounter(rng, mine, depth, party, elite = false) {
	const band = bandFor(mine, depth);
	const table = {};
	for (const key in band.creatures || {}) table[key] = Number(band.creatures[key]);
	if (!Object.keys(table).length) return [];
	let budget = encounterBudget(depth, party, elite);
	const most = 2 + Math.max(1, Math.min(4, party));
	const picked = [];
	let guard = 0;
	while (picked.length < most && guard < 20) {
		guard += 1;
		const key = rng.weightedKey(table);
		const threat = Number(C.creature(key).threat ?? 1);
		if (!picked.length || threat <= budget) { picked.push(key); budget -= threat; }
		else break;
	}
	return picked;
}

// How much tougher a mine breeds its creatures than the Quarry (sim/descent.gd creature_scale).
export function creatureScale(mine, depth) {
	let hp = Number(mine?.hp_mult ?? 1);
	let damage = Number(mine?.damage_mult ?? 1);
	if (mine?.endless) {
		const spans = Math.max(0, depth - 1) / Math.max(1, Number(mine.warden_every ?? 8));
		hp *= Math.pow(Number(mine.growth?.hp ?? 1), spans);
		damage *= Math.pow(Number(mine.growth?.damage ?? 1), spans);
	}
	return { hp, damage };
}

export function creatureHp(def, depth, party, mine = null) {
	let scale = 1 + Number(C.constant('depth_hp_scale', 0.05)) * Math.max(0, depth - 1);
	scale *= 1 + 0.15 * (Math.max(1, Math.min(4, party)) - 1);
	scale *= creatureScale(mine, depth).hp;
	return Math.max(1, Math.round(Number(def.hp ?? 10) * scale));
}

// A creature's flat damage bonus at a depth: depth ÷ depth_damage_every, spread over its dice.
export function creatureDamageBonus(def, depth) {
	const count = Math.max(1, (def.dice || []).length);
	return Math.trunc(Math.trunc(depth / Math.max(1, Number(C.constant('depth_damage_every', 4)))) / count);
}

// Chamber weights at a depth, after the depth rules: no elite through depth 2, no merchant at depth 1.
export function chamberTable(mine, depth) {
	const weights = { ...(mine.chambers || { fight: 48, elite: 12, vein: 18, oddity: 14, merchant: 8, smithy: 6, carver: 6, well: 5 }) };
	if (depth <= 2) delete weights.elite;
	if (depth <= 1) delete weights.merchant;
	return weights;
}

// Ore paid out for a won fight, before gold effects: ore_per_fight + depth, doubled for an
// elite and tripled for a Warden.
export function fightOre(depth, kind = 'fight') {
	let ore = Number(C.constant('ore_per_fight', 6)) + depth;
	if (kind === 'elite') ore *= 2;
	if (kind === 'warden') ore *= 3;
	return ore;
}

export const liftCost = (depth, riders) => Number(C.constant('lift_ore_per_depth', 15)) * depth * riders;
export const isLanding = (depth) => depth > 0 && depth % Number(C.constant('landing_every', 4)) === 0;
// The last floor of a mine, where its final boss waits; 0 for one with no bottom.
export const mineBottom = (mine) => (mine?.endless ? 0 : Number(mine?.depth ?? 24));
export function isWarden(depth, mine = null) {
	if (depth <= 0) return false;
	if (mine?.endless) return depth % Math.max(1, Number(mine.warden_every ?? C.constant('endless_warden_every', 8))) === 0;
	if ((mine?.warden_depths || []).includes(depth)) return true;
	return depth === mineBottom(mine);
}
