// Dice as items and the rolls they make: a port of sim/dice.gd.

export const TIERS = ['D2', 'D3', 'D4', 'D6', 'D8', 'D10', 'D12', 'D16', 'D20', 'D24', 'D30', 'D40', 'D50', 'D60', 'D100'];
export const SHAPES = { D2: 2, D3: 3, D4: 4, D6: 6, D8: 8, D10: 10, D12: 12, D16: 16, D20: 20, D24: 24, D30: 30, D40: 40, D50: 50, D60: 60, D100: 100 };
export const FACE_KINDS = ['plain', 'wild', 'gem', 'exploding', 'locked', 'mirror', 'blank'];
export const MAX_EXPLOSIONS = 3;
export const VALUE_CAP = 100;

export function facesOf(definition) {
	return (definition.faces || []).map((f) => (f && typeof f === 'object' ? { value: Number(f.value || 0), kind: f.kind || 'plain' } : { value: Number(f), kind: 'plain' }));
}

export function make(key, definition, id, engraving = '') {
	const die = { id, key, name: definition.name || key, shape: definition.shape || 'D6', faces: facesOf(definition), engraving: engraving || definition.engraving || '' };
	if (Number(definition.top || 0) > 0) die.top = Number(definition.top);
	return die;
}

export function top(die) {
	if (Number(die.top || 0) > 0) return Math.min(VALUE_CAP, Number(die.top));
	let best = 0;
	for (const f of die.faces || []) if (f.kind !== 'blank') best = Math.max(best, f.value);
	if (die.engraving === 'keen') best += 1;
	return Math.min(VALUE_CAP, best);
}

export function rollOne(die, rng, timesRerolled = 0) {
	const faces = die.faces && die.faces.length ? die.faces : [{ value: 1, kind: 'plain' }];
	const index = rng.randiRange(0, faces.length - 1);
	const chosen = faces[index];
	const kind = chosen.kind || 'plain';
	let value = chosen.value | 0;
	let explosions = 0;
	if (kind === 'exploding') {
		while (explosions < MAX_EXPLOSIONS) {
			const extra = faces[rng.randiRange(0, faces.length - 1)];
			value += extra.value | 0;
			explosions += 1;
			if ((extra.kind || 'plain') !== 'exploding') break;
		}
	}
	const engraving = die.engraving || '';
	if (kind === 'blank') value = 0;
	else {
		if (engraving === 'keen') value += 1;
		if (engraving === 'steady') value = Math.max(value, 2);
	}
	return { die_id: die.id, key: die.key, shape: die.shape, value: Math.min(value, VALUE_CAP), face: index, kind, top: top(die),
		held: false, rerolls: timesRerolled, locked: kind === 'locked', explosions, engraving, phantom: false };
}

export function resolveMirrors(hand) {
	let best = 0;
	for (const roll of hand) if (roll.kind !== 'mirror') best = Math.max(best, roll.value);
	for (const roll of hand) if (roll.kind === 'mirror') roll.value = Math.min(best, VALUE_CAP);
}

export function rollHand(dice, rng) {
	const hand = dice.map((d) => rollOne(d, rng));
	resolveMirrors(hand);
	return hand;
}

export function reroll(hand, dice, dieIds, rng) {
	const byId = new Map(dice.map((d) => [d.id, d]));
	const out = [];
	for (const roll of hand) {
		if (roll.phantom) continue;
		if (dieIds.has(roll.die_id) && !roll.locked && byId.has(roll.die_id)) out.push(rollOne(byId.get(roll.die_id), rng, (roll.rerolls | 0) + 1));
		else { const kept = { ...roll, held: true }; out.push(kept); }
	}
	resolveMirrors(out);
	return out;
}

export function heldForPatterns(roll) {
	if (roll.held || roll.engraving === 'always_held') return true;
	return (roll.rerolls | 0) === 0 && !roll.phantom;
}

// The exact distribution of one die's value, as a Map value -> probability. A mirror face is
// reported under the key 'mirror' because its value depends on the rest of the hand.
export function faceDistribution(die) {
	const faces = die.faces && die.faces.length ? die.faces : [{ value: 1, kind: 'plain' }];
	const out = new Map();
	const add = (value, p) => out.set(value, (out.get(value) || 0) + p);
	const engrave = (value) => {
		let v = value;
		if (die.engraving === 'keen') v += 1;
		if (die.engraving === 'steady') v = Math.max(v, 2);
		return Math.min(v, VALUE_CAP);
	};
	const explode = (value, depth, p) => {
		for (const face of faces) {
			const q = p / faces.length;
			const v = value + (face.value | 0);
			if ((face.kind || 'plain') === 'exploding' && depth < MAX_EXPLOSIONS) explode(v, depth + 1, q);
			else add(engrave(v), q);
		}
	};
	for (const face of faces) {
		const p = 1 / faces.length;
		const kind = face.kind || 'plain';
		if (kind === 'blank') { add(0, p); continue; }
		if (kind === 'mirror') { add('mirror', p); continue; }
		if (kind === 'exploding') { explode(face.value | 0, 1, p); continue; }
		add(engrave(face.value | 0), p);
	}
	return out;
}

// The exact distribution of a bowl's total. Mirrors copy the highest other die; wilds count as
// their die's top for totals, which is how the hand analysis reads them.
export function totalDistribution(dice) {
	let states = new Map([['0|0|0', 1]]);
	for (const die of dice) {
		const dist = faceDistribution(die);
		const t = top(die);
		const next = new Map();
		for (const [state, p] of states) {
			const [sum, high, mirrors] = state.split('|').map(Number);
			for (const [value, q] of dist) {
				let key;
				if (value === 'mirror') key = `${sum}|${high}|${mirrors + 1}`;
				else {
					const face = dieFaceKind(die, value);
					const v = face === 'wild' ? t : value;
					key = `${sum + v}|${Math.max(high, v)}|${mirrors}`;
				}
				next.set(key, (next.get(key) || 0) + p * q);
			}
		}
		states = next;
	}
	const totals = new Map();
	for (const [state, p] of states) {
		const [sum, high, mirrors] = state.split('|').map(Number);
		const total = sum + high * mirrors;
		totals.set(total, (totals.get(total) || 0) + p);
	}
	return new Map([...totals].sort((a, b) => a[0] - b[0]));
}

function dieFaceKind(die, value) {
	for (const f of die.faces || []) if (f.value === value && f.kind === 'wild') return 'wild';
	return 'plain';
}

export function describe(die) {
	const name = die.name || die.key || 'die';
	return die.engraving ? `${name} · ${die.engraving.replace('_', ' ')}` : name;
}
