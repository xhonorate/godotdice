// Where stones, dice and encounters come out of the rock: a port of sim/forge.gd, plus the
// exact distributions behind its rolls so the browser can chart odds without sampling.

import * as C from './content.js';
import * as Stone from './stone.js';

export const DEFAULT_CLASS_WEIGHTS = { PINPOINT: 10, LENS: 6, FEATHER: 4, FRACTURE: 3, STAR: 0.3 };
export const JACKPOT_PERCENT = 2;
export const LUCK_PER_DEPTH = 0.5;
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

// The exact chance of each carat count at luck q: a rounded normal, a 2% jackpot of +3..8,
// clamped to 1..carat_max.
export function caratDistribution(q) {
	const { mean, deviation } = caratParams(q);
	const max = Stone.caratMax();
	const lowK = Math.floor(mean - 8 * deviation) - 1;
	const highK = Math.ceil(mean + 8 * deviation) + 1;
	const out = new Array(max + 1).fill(0);
	const clamp = (k) => Math.max(1, Math.min(max, k));
	for (let k = lowK; k <= highK; k++) {
		let p = normalCdf((k + 0.5 - mean) / deviation) - normalCdf((k - 0.5 - mean) / deviation);
		if (k === lowK) p = normalCdf((k + 0.5 - mean) / deviation);
		if (k === highK) p = 1 - normalCdf((k - 0.5 - mean) / deviation);
		if (p <= 0) continue;
		out[clamp(k)] += p * (1 - JACKPOT_PERCENT / 100);
		for (let bonus = 3; bonus <= 8; bonus++) out[clamp(k + bonus)] += (p * (JACKPOT_PERCENT / 100)) / 6;
	}
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

export function skillPool(mine) {
	const listed = mine.skills || [];
	return listed.length ? listed.map(String) : C.keys('skills');
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

export function rollCarat(rng, q) {
	const { mean, deviation } = caratParams(q);
	let carat = Math.round(rng.randfn(mean, deviation));
	if (rng.chance(JACKPOT_PERCENT)) carat += rng.randiRange(3, 8);
	return Math.max(1, Math.min(carat, Stone.caratMax()));
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
	const carat = rollCarat(rng, q);
	const cut = rollCut(rng, q);
	const clarity = rollClarity(rng, q);
	const inclusions = rollInclusions(rng, Stone.inclusionSlots(clarity), mine, '', String(C.skill(skill).color || ''));
	return Stone.make(skill, carat, cut, clarity, inclusions);
}

export const engravingChance = (mine, depth) => 6 + luck(mine, depth) * 0.5;

export function dieTable(mine) {
	const pool = (mine.dice || []).length ? mine.dice.map(String) : C.keys('dice');
	const table = {};
	for (const key of pool) { const def = C.die(key); if (Object.keys(def).length) table[key] = C.rarityWeight(def.rarity || 'COMMON'); }
	return table;
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

export function creatureHp(def, depth, party) {
	let scale = 1 + Number(C.constant('depth_hp_scale', 0.05)) * Math.max(0, depth - 1);
	scale *= 1 + 0.15 * (Math.max(1, Math.min(4, party)) - 1);
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
export function isWarden(depth) {
	const wardens = C.constant('warden_depths', [8, 16, 24]);
	if (wardens.includes(depth)) return true;
	const runDepth = Number(C.constant('run_depth', 24));
	const every = Number(C.constant('endless_warden_every', 8));
	return depth > runDepth && (depth - runDepth) % every === 0;
}
