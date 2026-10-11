// A stone and what it does: a port of the parts of sim/stone.gd the browser reads.

import * as C from './content.js';
import * as Hand from './hand.js';
import * as Patterns from './patterns.js';
import * as Rules from './rules.js';
import * as Dice from './dice.js';
import { heldForPatterns } from './dice.js';

export const TIERS = ['ROUGH', 'FINE', 'PRECIOUS', 'EXQUISITE', 'PEERLESS'];
export const TIER_NAMES = { ROUGH: 'Rough', FINE: 'Fine', PRECIOUS: 'Precious', EXQUISITE: 'Exquisite', PEERLESS: 'Peerless' };
export const INCLUSION_SCORE = { COMMON: 2, UNCOMMON: 4, RARE: 7, LEGENDARY: 15 };
export const RARITY_VALUE = { COMMON: 1, UNCOMMON: 1.5, RARE: 2.5, LEGENDARY: 4, MYTHIC: 8, TRANSCENDENT: 16 };
export const SIZE_CLASSES = [
	{ key: 'TINY', name: 'Tiny', low: 1, shown: 3 }, { key: 'SMALL', name: 'Small', low: 5, shown: 7 }, { key: 'MEDIUM', name: 'Medium', low: 10, shown: 12 },
	{ key: 'LARGE', name: 'Large', low: 15, shown: 17 }, { key: 'HUGE', name: 'Huge', low: 20, shown: 24 }];

export function make(skill, carat, cut, clarity, inclusions = [], id = '') {
	return { id: id || `st_${skill}_${carat}_${cut}_${clarity}`, skill, carat, cut, clarity, inclusions: inclusions.slice(), appraised: true, inclusions_revealed: true };
}

export const skillOf = (stone) => C.skill(stone.skill || '');
export const caratMax = () => Number(C.constant('carat_max', 24));

// 1x at one carat, +0.25x a carat to 19, then +1x a carat from 20 on.
export function caratMultiplier(carat) {
	if (carat < 20) return 1 + (carat - 1) * 0.25;
	return carat - 14;
}

export const isFlawless = (stone) => Boolean(C.clarityEntry(stone.clarity | 0).flawless_line);
export const inclusionSlots = (clarity) => Number(C.clarityEntry(clarity).inclusions || 0);
export const color = (stone) => String(skillOf(stone).color || 'WHITE');
export const isOpal = (stone) => color(stone) === C.OPAL;

// Every colour the stone counts as: its skill's, any colour a Zoning adds, and the socket's
// own colour for an Alexandrite. An opal answers to none of the six unless something says so.
export function colors(stone, socket = '') {
	const out = [color(stone)];
	// A gem made from several colors counts as all of them.
	for (const also of skillOf(stone).colors || []) if (!out.includes(String(also))) out.push(String(also));
	for (const m of modifiers(stone)) {
		if (m.kind === 'color_also' && !out.includes(String(m.color))) out.push(String(m.color));
		else if (m.kind === 'alexandrite' && C.COLOR_KEYS.includes(socket) && !out.includes(socket)) out.push(socket);
	}
	return out;
}

export function fits(stone, socket) {
	return socket === C.SOCKET_ANY || colors(stone, socket).includes(socket);
}

// This stone with another's skill on it: what a Doublet is. Its four C's, inclusions and id
// stay its own.
export function wearing(stone, other) {
	return { ...stone, inclusions: (stone.inclusions || []).slice(), skill: String(other.skill || ''), worn_from: String(other.id || '') };
}

// The modifiers of every inclusion, each tagged with the inclusion it came from. A stone's
// inclusions never change in a fight, so the list is remembered per stone object and key.
const modifierCache = new WeakMap();
// Every modifier of every inclusion, and of the one a Fingerprint carries in a fight (copied).
export function modifiers(stone) {
	const keys = [...(stone.inclusions || [])];
	if (stone.copied) keys.push(stone.copied);
	const key = keys.join('|');
	const cached = modifierCache.get(stone);
	if (cached && cached.key === key) return cached.out;
	const out = [];
	for (const inclusion of keys) {
		const def = C.inclusion(inclusion);
		for (const m of def.modifiers || []) if (m && typeof m === 'object') out.push({ ...m, inclusion });
	}
	modifierCache.set(stone, { key, out });
	return out;
}
export const hasModifier = (mods, kind) => mods.some((m) => m.kind === kind);

// Inclusions a Fingerprint never takes up: another Fingerprint, and a Void.
export const FINGERPRINT_SKIPS = ['FINGERPRINT', 'VOID'];

// What a Fingerprint at index carries from the gem before it: { inclusion, from }, inclusion ''
// when there is nothing to carry, and null for a stone with no Fingerprint.
export function fingerprintSource(rail, index) {
	const stone = rail[index];
	if (!stone || !(stone.inclusions || []).includes('FINGERPRINT')) return null;
	const before = index > 0 ? rail[index - 1] : null;
	if (!before) return { inclusion: '', from: null };
	const found = (before.inclusions || []).find((k) => !FINGERPRINT_SKIPS.includes(k));
	return { inclusion: found || '', from: before };
}

// The stone as it fights from index of this rail: carrying its Fingerprint's inclusion, on a copy.
export function fingerprinted(rail, index, stone) {
	const source = fingerprintSource(rail, index);
	if (!source || !source.inclusion) return stone;
	return { ...stone, copied: source.inclusion };
}
export const modifierSum = (mods, kind, field = 'amount') => mods.reduce((s, m) => (m.kind === kind ? s + (Number(m[field]) | 0) : s), 0);

export function sizeClass(carat) {
	let found = 0;
	for (let i = 0; i < SIZE_CLASSES.length; i++) if (carat >= SIZE_CLASSES[i].low) found = i;
	const entry = { ...SIZE_CLASSES[found], index: found };
	const high = found + 1 < SIZE_CLASSES.length ? SIZE_CLASSES[found + 1].low - 1 : -1;
	entry.range = high > 0 ? `${entry.low} to ${high} carats` : `${entry.low} carats or more`;
	return entry;
}

export function gradeBreakdown(stone) {
	const caratPts = ((stone.carat | 0) / caratMax()) * 45;
	const cutPts = ((stone.cut | 0) / (Patterns.STEPS - 1)) * 20;
	const clear = C.clearIndex();
	const clarityIndex = stone.clarity ?? clear;
	const reach = Math.max(1, clarityIndex > clear ? C.clarities().length - 1 - clear : clear);
	const clarityPts = (Math.abs(clarityIndex - clear) / reach) * 20;
	let inclusionPts = 0;
	for (const key of stone.inclusions || []) inclusionPts += INCLUSION_SCORE[C.inclusion(key).rarity || 'COMMON'] ?? 2;
	inclusionPts = Math.min(15, inclusionPts);
	const skillPts = (C.rarityScore(skillOf(stone).rarity || 'COMMON') / 28) * 8;
	return { carat_pts: caratPts, cut_pts: cutPts, clarity_pts: clarityPts, inclusion_pts: inclusionPts, skill_pts: skillPts, total: caratPts + cutPts + clarityPts + inclusionPts + skillPts };
}

export function grade(stone) {
	const breakdown = gradeBreakdown(stone);
	const score = Math.max(0, Math.min(100, Math.round(breakdown.total)));
	const thresholds = C.constant('grade_thresholds', { FINE: 30, PRECIOUS: 55, EXQUISITE: 72, PEERLESS: 85 });
	let tier = 'ROUGH';
	for (const candidate of ['FINE', 'PRECIOUS', 'EXQUISITE', 'PEERLESS']) if (score >= Number(thresholds[candidate] ?? 999)) tier = candidate;
	return { score, tier, name: TIER_NAMES[tier], index: TIERS.indexOf(tier), breakdown };
}

export function value(stone) {
	const clear = C.clearIndex();
	let base = 10 + (stone.carat | 0) * 4;
	base *= 1 + (stone.cut | 0) * 0.25;
	base *= 1 + 0.3 * Math.abs((stone.clarity ?? clear) - clear);
	base *= RARITY_VALUE[skillOf(stone).rarity || 'COMMON'] ?? 1;
	for (const key of stone.inclusions || []) base *= 1 + (INCLUSION_SCORE[C.inclusion(key).rarity || 'COMMON'] ?? 2) / 20;
	return Math.max(1, Math.round(base));
}

export function roughValue(stone) {
	const entry = sizeClass(stone.carat | 0);
	return Math.max(1, Math.round(6 + entry.low * 2.2));
}

export function name(stone) {
	const skill = skillOf(stone);
	const cut = C.cutEntry(stone.cut | 0).name || '';
	const clarity = C.clarityEntry(stone.clarity | 0).name || '';
	return `${cut} ${clarity} ${stone.carat | 0}-carat ${skill.name || stone.skill}`;
}

// The ranks the stone really has once its inclusions and the rail context speak.
export function effective(stone, c = {}) {
	const mods = modifiers(stone);
	const clarityCount = C.clarities().length;
	const clarity = Math.max(0, Math.min(clarityCount - 1, (stone.clarity | 0) + (c.clarity_bonus | 0)));
	const clarityEntry = C.clarityEntry(clarity);
	let carat = (stone.carat | 0) + modifierSum(mods, 'carat') + (c.carat_bonus | 0);
	const depth = c.depth | 0;
	let caratMult = 1, magnitudeMult = 1;
	let cutStep = stone.cut | 0;
	for (const m of mods) {
		switch (m.kind) {
			case 'carat_per_depth': if (depth > (m.below | 0)) carat += (depth - (m.below | 0)) * (Number(m.amount ?? 1) | 0); break;
			case 'carat_mult': caratMult *= Number(m.amount ?? 1); break;
			case 'magnitude': magnitudeMult *= Number(m.amount ?? 1); break;
			case 'cut_override': cutStep = m.value | 0; break;
		}
	}
	cutStep += (clarityEntry.cut_step | 0) + modifierSum(mods, 'cut_step') + (c.cut_step_bonus | 0);
	const dulled = Math.max(0, c.dulled | 0);
	if (dulled > 0) cutStep = Math.max(0, Math.min(Patterns.STEPS - 1, cutStep) - dulled);
	// An Assayer in the room weighs every gem at no more than its limit, however it got there.
	let weight = carat * caratMult;
	const caratCap = c.carat_cap | 0;
	if (caratCap > 0) { carat = Math.min(carat, caratCap); weight = Math.min(weight, caratCap); }
	const magnitude = caratMultiplier(weight) * Number(clarityEntry.magnitude ?? 1) * magnitudeMult * Number(c.amplify ?? 1);
	return { clarity, flawless: Boolean(clarityEntry.flawless_line), carat, cut_step: Math.max(0, cutStep), magnitude, modifiers: mods, resonance_mult: Number(clarityEntry.resonance_mult ?? 1) };
}

export function procs(stone, c = {}) { return Rules.caratProcs(effective(stone, c).magnitude); }

function scaledDefs(stone) {
	const skill = skillOf(stone);
	const defs = (skill.effects || []).slice();
	if (isFlawless(stone) && skill.flawless && typeof skill.flawless === 'object') defs.push(...(skill.flawless.effects || []));
	return defs;
}
export function procsMatter(stone) {
	return scaledDefs(stone).some((d) => d && typeof d === 'object' && !('scale' in d) && !Rules.SCALED_BY_DEFAULT.includes(String(d.kind || 'damage')));
}
export function magnitudeMatters(stone) {
	if (stone.birthstone) return false;
	return scaledDefs(stone).some((d) => d && typeof d === 'object' && String(d.scale ?? (Rules.SCALED_BY_DEFAULT.includes(String(d.kind || 'damage')) ? 'carat' : 'none')) === 'carat');
}

export function text(stone, c = {}) {
	const skill = skillOf(stone);
	return Rules.fill(String(skill.text || ''), skill.numbers || {}, effective(stone, c).cut_step);
}
export function flawlessText(stone, c = {}) {
	const skill = skillOf(stone);
	if (!skill.flawless || typeof skill.flawless !== 'object') return '';
	return Rules.fill(String(skill.flawless.text || ''), skill.numbers || {}, effective(stone, c).cut_step);
}

export function applyLens(hand, mode) {
	const out = hand.map((r) => ({ ...r }));
	switch (mode) {
		case 'low_as_high': {
			let lowIndex = -1, high = 0;
			for (let i = 0; i < out.length; i++) {
				const roll = out[i];
				if (roll.kind === 'wild' || roll.kind === 'blank') continue;
				high = Math.max(high, roll.value);
				if (lowIndex < 0 || roll.value < out[lowIndex].value) lowIndex = i;
			}
			if (lowIndex >= 0) out[lowIndex].value = high;
			break;
		}
		case 'ones_wild': for (const roll of out) if ((roll.value | 0) === 1 && (roll.kind || 'plain') === 'plain') roll.kind = 'wild'; break;
		case 'held_twice': for (const roll of out) if (heldForPatterns(roll)) roll.twinned = true; break;
	}
	return out;
}

export function applyFlawless(defs, flawless) {
	const out = defs.map((d) => JSON.parse(JSON.stringify(d)));
	for (const change of flawless.modify || []) {
		if (!change || typeof change !== 'object') continue;
		const index = change.effect | 0;
		if (index < 0 || index >= out.length) continue;
		const def = out[index];
		for (const field of [...Rules.EFFECT_OPTIONS, 'amount', 'repeat']) if (field in change) def[field] = change[field];
		if ('target' in change) def.target = String(change.target);
		if ('kind' in change) def.kind = String(change.kind);
		if ('scale' in change) def.scale = String(change.scale);
		if ('mult' in change) def.amount = { op: '*', args: [def.amount ?? { const: 0 }, { const: change.mult | 0 }] };
		if ('add' in change) def.amount = { op: '+', args: [def.amount ?? { const: 0 }, { const: change.add | 0 }] };
		if ('repeat_add' in change) def.repeat = { op: '+', args: [def.repeat ?? { const: 1 }, { const: change.repeat_add | 0 }] };
		if ('splash' in change) def.splash = change.splash | 0;
	}
	for (const extra of flawless.effects || []) if (extra && typeof extra === 'object') out.push(JSON.parse(JSON.stringify(extra)));
	return out;
}

// What this stone does to this hand. `c` is the rail context: unit, resonance, previous_fired,
// previous_amount, amplify, cut_step_bonus, carat_bonus, depth, turn, party, force_fire.
// The rolls behind a list of die ids, each one only once however often it was named.
export function rollsOf(hand, ids) {
	const seen = new Set();
	const out = [];
	for (const id of ids) {
		if (seen.has(id)) continue;
		const roll = hand.find((r) => r.die_id === id);
		if (roll) { seen.add(id); out.push(roll); }
	}
	return out;
}

export function evaluate(stone, hand, c = {}) {
	const skill = skillOf(stone);
	if (!skill || !Object.keys(skill).length) return { active: false, reason: 'unknown skill', dice: [], effects: [], fires: 0 };
	const eff = effective(stone, c);
	const mods = eff.modifiers;
	let working = hand;
	for (const m of mods) if (m.kind === 'lens') working = applyLens(working, String(m.mode || ''));
	// The hand is read for this gem in particular: the dice that would do it the most good
	// come first in everything the trigger picks from.
	const wearing = colors(stone, String(c.socket || ''));
	// A fight may hand in its own reading of the hand (`c.analyze`), remembered while the hand
	// stands still; it is only ever asked about the hand itself, never a lens's copy.
	const a = c.analyze && working === hand ? c.analyze(wearing) : Hand.analyze(working, wearing);
	const trigger = skill.trigger || { kind: 'always' };
	const trig = Patterns.evaluate(trigger, eff.cut_step, a, { resonance: c.resonance | 0, pyrite: Rules.pyrite(c.unit || {}), fizzles: c.fizzles | 0, kills: c.kills | 0 });
	if (!trig.active && (hasModifier(mods, 'always_fires') || c.force_fire)) {
		trig.active = true; trig.forced = true;
		trig.dice = Hand.matching(a, () => true);
		trig.value = a.best_set.value || a.high;
		trig.count = Math.max(1, a.best_set.count || 1);
		delete trig.reason;
	}
	for (const m of mods) {
		if (m.kind === 'fizzle_on_value' && trig.active) {
			const forbidden = Number(m.value ?? 1);
			if (a.ids_by_value.has(forbidden)) { trig.active = false; trig.reason = `${C.inclusion(m.inclusion).name || 'Fracture'}: a ${forbidden} showed.`; }
		}
	}
	const result = { active: Boolean(trig.active), reason: trig.reason || '', dice: trig.dice || [], trigger: trig, cut_step: eff.cut_step, carat: eff.carat,
		magnitude: eff.magnitude, analysis: a, effects: [], fires: trig.active ? 1 : 0, hp_cost: 0, resonance_gain: 0, next_cut_step: modifierSum(mods, 'next_cut_step'),
		skill: stone.skill, stone_id: String(stone.id || ''), colors: wearing, die_boost: 1 };
	if (!trig.active) return result;
	// What the dice themselves are made of. A material that answers to this gem colour is
	// half again as strong, and they multiply.
	const fired = rollsOf(working, trig.dice || []);
	const boost = Dice.strength(fired, wearing);
	const magnitude = eff.magnitude * boost;
	result.die_boost = boost;
	result.magnitude = magnitude;
	const tc = { a, trig, unit: c.unit || {}, resonance: c.resonance | 0, previous_amount: c.previous_amount | 0, carat: eff.carat, cut: eff.cut_step,
		clarity: eff.clarity, enemy_poison: c.enemy_poison | 0, fizzles: c.fizzles | 0, depth: c.depth | 0, turn: c.turn | 0, party: c.party | 0 || 1,
		run_fires: c.run_fires | 0 };
	// resolveEffect only reads a definition, so the pack's own are used as they stand.
	let defs = skill.effects || [];
	if (eff.flawless && skill.flawless && typeof skill.flawless === 'object') defs = applyFlawless(defs, skill.flawless);
	for (const def of defs) if (def && typeof def === 'object') result.effects.push(Rules.resolveEffect(def, tc, magnitude));
	const perDie = modifierSum(mods, 'per_die_damage');
	if (perDie > 0) for (const effect of result.effects) if (effect.kind === 'damage') effect.amount += perDie * (trig.dice || []).length;
	for (const m of mods) {
		if (m.kind === 'rider') for (const def of m.effects || []) if (def && typeof def === 'object') { const rider = Rules.resolveEffect(def, tc, magnitude); rider.inclusion = m.inclusion; result.effects.push(rider); }
	}
	result.hp_cost = modifierSum(mods, 'hp_cost');
	// A Shiny face rings once more for every gem it helped light.
	result.resonance_gain = Math.round((1 + modifierSum(mods, 'resonance_bonus') + Dice.shinyCount(fired)) * eff.resonance_mult);
	if (!c.retrigger) {
		if (hasModifier(mods, 'fires_twice')) result.fires += 1;
		if (hasModifier(mods, 'retrigger_if_previous_fired') && c.previous_fired) result.fires += 1;
	}
	return result;
}

// The headline number of an evaluation: what an Echo repeats and the forecast sums.
export function totalAmount(evaluation, kinds = ['damage', 'block', 'heal']) {
	let total = 0;
	for (const effect of evaluation.effects || []) if (kinds.includes(effect.kind)) total += (effect.amount | 0) * Math.max(1, effect.repeat | 0);
	return total;
}

// The headline number of an evaluation, per kind: amount × repeat × expected procs.
export function totals(evaluation) {
	const out = {};
	for (const effect of evaluation.effects || []) {
		const expectedProcs = effect.scaled ? 1 : effect.procs + effect.proc_chance / 100;
		const amount = effect.amount * Math.max(1, effect.repeat | 0) * expectedProcs;
		out[effect.kind] = (out[effect.kind] || 0) + amount;
	}
	return out;
}
