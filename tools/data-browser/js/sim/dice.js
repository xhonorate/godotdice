// Dice as items and the rolls they make: a port of sim/dice.gd.
//
// A die is a shape, at most one pattern, any number of etched faces and at most one
// material. See docs/DICE.md.

import * as C from './content.js';

export const TIERS = ['D2', 'D3', 'D4', 'D6', 'D8', 'D10', 'D12', 'D16', 'D20', 'D24', 'D30', 'D40', 'D50', 'D60', 'D100'];
export const SHAPES = { D2: 2, D3: 3, D4: 4, D6: 6, D8: 8, D10: 10, D12: 12, D16: 16, D20: 20, D24: 24, D30: 30, D40: 40, D50: 50, D60: 60, D100: 100 };
export const FACE_KINDS = ['plain', 'wild', 'exploding', 'shiny', 'golden', 'tally', 'sticky', 'twin', 'doubled', 'locked', 'blank'];
export const BOON_FACES = ['wild', 'exploding', 'shiny', 'golden', 'tally', 'sticky', 'twin', 'doubled'];
export const BANE_FACES = ['locked', 'blank'];
export const PATTERNS = ['even', 'odd', 'split', 'gamblers', 'paired', 'stretched', 'shallow'];
export const MATERIALS = ['ruby', 'sapphire', 'emerald', 'amethyst', 'citrine', 'diamond', 'opal', 'glass', 'crystal', 'iron', 'cloud', 'fools_gold', 'granite', 'blood'];
// Thrown twice, keeping one of the two faces: Iron the higher, Cloud the lower. A tie keeps the first.
export const THROWN_TWICE = { iron: 1, cloud: -1 };
export const MATERIAL_COLORS = { ruby: 'RED', sapphire: 'BLUE', emerald: 'GREEN', amethyst: 'VIOLET', citrine: 'GOLD', diamond: 'WHITE' };
export const ANY_COLOR_MATERIALS = ['opal', 'glass'];
export const MAX_EXPLOSIONS = 3;
export const STRENGTH_STEP = 1.5;
export const GLASS_SHATTER_PCT = 10;
export const CRYSTAL_RESONANCE = 1;
export const FOOLS_GOLD_PYRITE = 2;
export const GOLDEN_FACE_PYRITE = 2;
export const BLOOD_HP = 2;

export const sizeOf = (shape) => Number(SHAPES[shape] || 6);

export function face(value, kind = 'plain') {
	return { value: Number(value) | 0, kind };
}

export function facesOf(definition) {
	return (definition.faces || []).map((f) => (f && typeof f === 'object' ? face(f.value || 0, f.kind || 'plain') : face(f)));
}

// --- patterns ---------------------------------------------------------------------------

export function patternAllows(pattern, shape) {
	const n = sizeOf(shape);
	switch (pattern) {
		case '': return true;
		case 'even': case 'odd': return n >= 4 && n % 2 === 0;
		case 'split': case 'paired': case 'shallow': return n >= 6;
		case 'gamblers': return n >= 6 && n <= 12;
		case 'stretched': return n >= 4;
		default: return false;
	}
}

export const splitDoublings = (n) => (n < 20 ? 1 : n < 40 ? 2 : 3);

export function pairedValues(n, rng = null) {
	const half = Math.max(1, Math.floor(n / 2));
	const pool = [];
	for (let value = 1; value <= n; value += 1) pool.push(value);
	const picked = [];
	if (!rng) {
		for (let index = 0; index < half; index += 1) picked.push(pool[Math.min(pool.length - 1, index * 2)]);
		return picked;
	}
	for (let i = 0; i < half; i += 1) picked.push(...pool.splice(rng.randiRange(0, pool.length - 1), 1));
	picked.sort((a, b) => a - b);
	return picked;
}

export function patternFaces(shape, pattern = '', rng = null) {
	const n = sizeOf(shape);
	const values = [];
	switch (pattern) {
		case 'even':
			for (let i = 1; i <= n / 2; i += 1) values.push(i * 2, i * 2);
			break;
		case 'odd':
			for (let i = 1; i <= n / 2; i += 1) values.push(i * 2 - 1, i * 2 - 1);
			break;
		case 'split': {
			const t = splitDoublings(n);
			const goneFrom = n / 2 - t + 1;
			const goneTo = n / 2 + t;
			for (let i = 0; i < t; i += 1) values.push(1);
			for (let value = 1; value <= n; value += 1) if (value < goneFrom || value > goneTo) values.push(value);
			for (let i = 0; i < t; i += 1) values.push(n);
			break;
		}
		case 'gamblers':
			for (let value = 1; value <= n; value += 1) values.push(value === 6 || value === 8 ? 7 : value);
			break;
		case 'paired':
			for (const value of pairedValues(n, rng)) values.push(value, value);
			break;
		case 'stretched':
			for (let value = 1; value <= n; value += 1) values.push(value * 2);
			break;
		case 'shallow':
			for (let value = 1; value <= n; value += 1) values.push(Math.ceil(value / 2));
			break;
		default:
			for (let value = 1; value <= n; value += 1) values.push(value);
	}
	return values.map((v) => face(v));
}

export const patternTop = (shape, pattern) => (pattern === 'shallow' ? sizeOf(shape) : 0);

// --- materials --------------------------------------------------------------------------

export const materialColor = (material) => MATERIAL_COLORS[material] || '';

export function materialMatches(material, colors = []) {
	if (!material) return false;
	if (ANY_COLOR_MATERIALS.includes(material)) return true;
	const wanted = materialColor(material);
	return !!wanted && colors.includes(wanted);
}

export function strength(rolls, colors = []) {
	let boost = 1;
	for (const roll of rolls) if (materialMatches(roll.material || '', colors)) boost *= STRENGTH_STEP;
	return boost;
}

export function matchingMaterials(rolls, colors = []) {
	return rolls.filter((r) => materialMatches(r.material || '', colors)).map((r) => r.material);
}

export const shinyCount = (rolls) => rolls.filter((r) => (r.kind || 'plain') === 'shiny').length;

export function preference(roll, colors = []) {
	let score = 0;
	const material = roll.material || '';
	if (materialMatches(material, colors)) score += 4;
	if (BOON_FACES.includes(roll.kind || 'plain')) score += 2;
	if (material) score += 1;
	return score;
}

// --- making a die -----------------------------------------------------------------------

export function make(shape, id, opts = {}) {
	const key = SHAPES[shape] ? shape : 'D6';
	let pattern = opts.pattern || '';
	if (pattern && !patternAllows(pattern, key)) pattern = '';
	const faces = (opts.faces && opts.faces.length ? opts.faces.map((f) => face(f.value, f.kind || 'plain')) : patternFaces(key, pattern, opts.rng || null));
	const die = { id, shape: key, pattern, faces, material: opts.material || '', name: opts.name || '' };
	for (const entry of etchList(opts.etches)) etch(die, Number(entry.face), String(entry.kind));
	// As sim/dice.gd reads it: a `top` that is given at all (die_from always gives one, 0 when
	// the ref has none) wins over the pattern's, so a starting Phial is judged as a d3.
	const override = Number('top' in opts ? opts.top : patternTop(key, pattern));
	if (override > 0) die.top = override;
	return die;
}

function etchList(etches) {
	if (!etches) return [];
	if (Array.isArray(etches)) return etches.filter((e) => e && typeof e === 'object');
	return Object.entries(etches).map(([at, kind]) => ({ face: Number(at), kind: String(kind) }));
}

export function etch(die, index, kind) {
	const faces = die.faces || [];
	if (index < 0 || index >= faces.length || !FACE_KINDS.includes(kind)) return false;
	faces[index] = face(faces[index].value | 0, kind);
	return true;
}

// The die, in place, `steps` sizes bigger or smaller (sim/oddities.gd resize): it keeps its id,
// material and every etching that still has a face, and a face worked past the pattern stays.
export function resize(die, steps) {
	const at = TIERS.indexOf(die.shape);
	if (at < 0 || at + steps < 0 || at + steps >= TIERS.length) return 'that die cannot change size that far';
	const had = (die.faces || []).map((f) => ({ ...f }));
	const own = String(die.name || '');
	const made = make(TIERS[at + steps], die.id, { pattern: die.pattern || '', material: die.material || '', name: own && !SHAPES[own.toUpperCase()] ? own : '' });
	for (let index = 0; index < Math.min(had.length, made.faces.length); index++) {
		made.faces[index].kind = had[index].kind || 'plain';
		made.faces[index].value = Math.max(made.faces[index].value | 0, had[index].value | 0);
	}
	for (const key of Object.keys(die)) delete die[key];
	Object.assign(die, made);
	return '';
}

export function etchings(die) {
	return (die.faces || []).map((f, index) => ({ face: index, kind: f.kind || 'plain' })).filter((e) => e.kind !== 'plain');
}

export function reset(die) {
	die.pattern = '';
	die.faces = patternFaces(die.shape || 'D6');
	delete die.top;
}

export function faceValue(f) {
	const kind = f.kind || 'plain';
	if (kind === 'blank') return 0;
	const value = f.value | 0;
	return kind === 'doubled' ? value * 2 : value;
}

export function top(die) {
	if (Number(die.top || 0) > 0) return Number(die.top);
	let best = 0;
	for (const f of die.faces || []) best = Math.max(best, faceValue(f));
	return best;
}

// --- rolling ----------------------------------------------------------------------------

export function rollOne(die, rng, timesRerolled = 0) {
	const faces = die.faces && die.faces.length ? die.faces : [face(1)];
	const material = die.material || '';
	let index = rng.randiRange(0, faces.length - 1);
	if (material in THROWN_TWICE) {
		const other = rng.randiRange(0, faces.length - 1);
		const lean = THROWN_TWICE[material];
		if (lean * faceValue(faces[other]) > lean * faceValue(faces[index])) index = other;
	}
	const chosen = faces[index];
	const kind = chosen.kind || 'plain';
	let climbed = false;
	if (kind === 'tally') {
		chosen.value = (chosen.value | 0) + 1;
		climbed = true;
	}
	let value = faceValue(chosen);
	let explosions = 0;
	if (kind === 'exploding') {
		while (explosions < MAX_EXPLOSIONS) {
			const extra = faces[rng.randiRange(0, faces.length - 1)];
			value += faceValue(extra);
			explosions += 1;
			if ((extra.kind || 'plain') !== 'exploding') break;
		}
	}
	const dieTop = top(die);
	const shattered = material === 'glass' && rng.randf() * 100 < GLASS_SHATTER_PCT;
	return { die_id: die.id, shape: die.shape, material, value, face: index, kind, top: dieTop,
		held: false, rerolls: timesRerolled, locked: kind === 'locked', explosions, climbed, shattered, phantom: false };
}

export function rollHand(dice, rng, previous = []) {
	const kept = new Map();
	for (const roll of previous) if ((roll.kind || 'plain') === 'sticky' && !roll.phantom) kept.set(roll.die_id, roll);
	return dice.map((die) => {
		if (!kept.has(die.id)) return rollOne(die, rng);
		return { ...kept.get(die.id), held: true, rerolls: 0, phantom: false, climbed: false, shattered: false, carried: true };
	});
}

export function reroll(hand, dice, dieIds, rng) {
	const byId = new Map(dice.map((d) => [d.id, d]));
	const out = [];
	for (const roll of hand) {
		// A phantom a Contra Luz carried over stays as it is; any other belonged to the hand that is going.
		if (roll.phantom) { if (roll.kept) out.push({ ...roll }); continue; }
		if (dieIds.has(roll.die_id) && !roll.locked && byId.has(roll.die_id)) out.push(rollOne(byId.get(roll.die_id), rng, (roll.rerolls | 0) + 1));
		else out.push({ ...roll, held: true, climbed: false, shattered: false });
	}
	return out;
}

export function throwDues(rolls) {
	const out = { resonance: 0, pyrite: 0, hp: 0, climbed: [], shattered: [] };
	for (const roll of rolls) {
		if (roll.phantom || roll.carried) continue;
		const material = roll.material || '';
		const kind = roll.kind || 'plain';
		if (material === 'crystal') out.resonance += CRYSTAL_RESONANCE;
		if (material === 'fools_gold') out.pyrite += FOOLS_GOLD_PYRITE;
		if (kind === 'golden') out.pyrite += GOLDEN_FACE_PYRITE;
		if (material === 'blood' && (roll.rerolls | 0) > 0) out.hp += BLOOD_HP;
		if (roll.climbed) out.climbed.push({ die: roll.die_id, value: roll.value | 0 });
		if (roll.shattered) out.shattered.push(roll.die_id);
	}
	return out;
}

// The dice in a hand a reroll may touch: nothing locked, no phantom.
export function rerollable(hand) {
	return hand.filter((r) => !r.locked && !r.phantom).map((r) => r.die_id);
}

// A copy of a roll that exists only for the gems after the one that made it.
export function phantom(source, id) {
	return { ...source, die_id: id, phantom: true, held: false, rerolls: 0, locked: false, climbed: false, shattered: false };
}

export function heldForPatterns(roll) {
	if (roll.held) return true;
	return (roll.rerolls | 0) === 0 && !roll.phantom;
}

// The exact distribution of one die's value, as a Map value -> probability.
export function faceDistribution(die) {
	const faces = die.faces && die.faces.length ? die.faces : [face(1)];
	const out = new Map();
	const add = (value, p) => out.set(value, (out.get(value) || 0) + p);
	// How likely each face is to be the one the die keeps: 1/n, or for a die thrown twice the
	// chance it wins (or ties first) against a second throw.
	const n = faces.length;
	const lean = THROWN_TWICE[die.material || ''] || 0;
	const kept = faces.map((f) => {
		if (!lean) return 1 / n;
		const mine = lean * faceValue(f);
		const notBeaten = faces.filter((g) => lean * faceValue(g) <= mine).length;
		const beats = faces.filter((g) => lean * faceValue(g) < mine).length;
		return (notBeaten + beats) / (n * n);
	});
	const explode = (value, depth, p) => {
		for (const f of faces) {
			const q = p / faces.length;
			const v = value + faceValue(f);
			if ((f.kind || 'plain') === 'exploding' && depth < MAX_EXPLOSIONS) explode(v, depth + 1, q);
			else add(v, q);
		}
	};
	faces.forEach((f, i) => {
		const p = kept[i];
		const kind = f.kind || 'plain';
		if (kind === 'blank') { add(0, p); return; }
		if (kind === 'exploding') { explode(f.value | 0, 1, p); return; }
		add(faceValue(f), p);
	});
	return out;
}

// The exact distribution of a bowl's total. Wilds count as their die's top for totals,
// which is how the hand analysis reads them.
export function totalDistribution(dice) {
	let states = new Map([['0', 1]]);
	for (const die of dice) {
		const dist = faceDistribution(die);
		const t = top(die);
		const next = new Map();
		for (const [state, p] of states) {
			const sum = Number(state);
			for (const [value, q] of dist) {
				const v = dieFaceKind(die, value) === 'wild' ? t : value;
				const key = String(sum + v);
				next.set(key, (next.get(key) || 0) + p * q);
			}
		}
		states = next;
	}
	const totals = new Map();
	for (const [state, p] of states) totals.set(Number(state), (totals.get(Number(state)) || 0) + p);
	return new Map([...totals].sort((a, b) => a[0] - b[0]));
}

function dieFaceKind(die, value) {
	for (const f of die.faces || []) if (faceValue(f) === value && f.kind === 'wild') return 'wild';
	return 'plain';
}

// --- saying what a die is ---------------------------------------------------------------

export const patternName = (pattern) => (pattern ? String(C.entry('patterns', pattern.toUpperCase()).name || pattern) : '');
export const materialName = (material) => (material ? String(C.entry('materials', material.toUpperCase()).name || material) : '');
export const etchingName = (kind) => (kind && kind !== 'plain' ? String(C.entry('etchings', kind.toUpperCase()).name || kind) : '');

export function describe(die) {
	if (die.name) return die.name;
	const words = [];
	if (die.material) words.push(materialName(die.material));
	if (die.pattern) words.push(patternName(die.pattern));
	words.push(String(die.shape || 'D6').toLowerCase());
	const marks = [...new Set(etchings(die).map((e) => etchingName(e.kind)))];
	const text = words.join(' ');
	return marks.length ? `${text} · ${marks.join(', ').toLowerCase()}` : text;
}

export function dieFrom(ref, id) {
	if (ref && typeof ref === 'object') {
		return make(String(ref.shape || 'D6'), id, { pattern: ref.pattern || '', material: ref.material || '', etches: ref.etches || [], name: ref.name || '', top: Number(ref.top || 0) });
	}
	return make(String(ref), id);
}
