// What a hand has to show before a gem fires: a port of sim/patterns.gd.

import * as Hand from './hand.js';
import { I } from './numbers.js';

export const KINDS = ['all_odd', 'all_even', 'always', 'pair', 'two_pair', 'triple', 'full_house', 'quad', 'quint', 'straight',
	'odd', 'even', 'distinct', 'value', 'at_most', 'at_least', 'total_pct_at_least', 'total_pct_at_most',
	'high_pct_at_least', 'held', 'rerolled', 'resonance', 'low_count', 'crowns', 'crowns_at_most', 'skip_straight', 'distinct_dominant', 'pyrite', 'fizzles', 'below', 'kills',
	'each_turn', 'every_nth_turn', 'emerge', 'on_death', 'hp_below', 'action_begin', 'countdown'];
// The kinds a creature reads from the turn rather than from a die: each fires at most once an
// action, on its first die (on_death never during an action: it fires when the creature dies;
// hp_below the moment its health first falls that far; action_begin as its action opens).
export const TURN_KINDS = ['each_turn', 'every_nth_turn', 'emerge', 'on_death', 'hp_below', 'action_begin', 'countdown'];
// The turn kinds the fight calls itself, never on a die the creature throws.
export const CALLED_KINDS = ['on_death', 'hp_below', 'action_begin'];
export const isTurnKind = (kind) => TURN_KINDS.includes(kind);
export const SET_SIZES = { pair: 2, triple: 3, quad: 4, quint: 5 };
export const STEPS = 5;

export function rung(trigger, cutStep) {
	const ladder = trigger.ladder || [];
	if (!ladder.length) return Number(trigger.amount ?? 0);
	return Number(ladder[Math.max(0, Math.min(cutStep, ladder.length - 1))]);
}

export function readSide(trigger, cutStep) {
	const read = trigger.read ?? 'high';
	if (Array.isArray(read) && read.length) return String(read[Math.max(0, Math.min(cutStep, read.length - 1))]);
	return String(read);
}

export function unconditional(kind, need) {
	switch (kind) {
		case 'always': return true;
		case 'high_pct_at_least': case 'total_pct_at_least': case 'low_count': case 'held': case 'rerolled': case 'crowns': case 'resonance': return need <= 0;
		case 'distinct': return need <= 1;
		case 'total_pct_at_most': return need >= 100;
	}
	return false;
}

// A set of `size` at or above `need` with every wild joining it, the most dice and then the
// highest value first; the wilds alone make one at their top. Null when none can.
function wildSet(a, size, need) {
	const wilds = a.wilds || [];
	if (!wilds.length) return null;
	let best = null;
	for (const group of a.plain_groups || []) {
		const count = group.count + wilds.length;
		if (group.value >= need && count >= size && (!best || count > best.count || (count === best.count && group.value > best.value))) {
			best = { value: group.value, count, dice: group.dice.concat(wilds) };
		}
	}
	const top = wildTopOf(a);
	if (!best && wilds.length >= size && top >= need) best = { value: top, count: wilds.length, dice: wilds.slice() };
	return best;
}

// Two sets of different values, `first` and `second` dice big, with the wilds placed where they
// complete them; the highest values first. The first must reach `need`, and so must the second
// unless `highOnly` (two pairs: the higher; a full house: its three).
function wildSets(a, first, second, need, highOnly) {
	const wilds = a.wilds || [];
	if (!wilds.length) return null;
	const counts = new Map();
	const diceOf = new Map();
	for (const group of a.plain_groups || []) { counts.set(group.value, group.count); diceOf.set(group.value, group.dice); }
	// A value no die shows can be made of wilds alone: the two highest under their top will do.
	const values = [...counts.keys()];
	let spare = 0;
	for (let v = wildTopOf(a); v > 0 && spare < 2; v--) if (!counts.has(v)) { values.push(v); spare += 1; }
	const symmetric = first === second;
	let best = null;
	for (const x of values) {
		for (const y of values) {
			if (x === y || (symmetric && x < y)) continue;
			const usedX = Math.max(0, first - (counts.get(x) || 0));
			const cost = usedX + Math.max(0, second - (counts.get(y) || 0));
			if (cost > wilds.length) continue;
			if (x < need || (symmetric && !highOnly && y < need)) continue;
			if (best && (x < best.value || (x === best.value && y <= best.second))) continue;
			const dice = (diceOf.get(x) || []).concat(wilds.slice(0, usedX), diceOf.get(y) || [], wilds.slice(usedX, cost));
			best = { value: x, second: y, dice };
		}
	}
	return best;
}

function wildTopOf(a) {
	let top = 0;
	for (const id of a.wilds || []) top = Math.max(top, a.wild_tops?.get(id) || 0);
	return top;
}

function allDice(a) {
	const dice = [];
	if (a.ids_by_value) for (const ids of a.ids_by_value.values()) dice.push(...ids);
	dice.push(...(a.wilds || []));
	return dice;
}

export function evaluate(trigger, cutStep, a, context = {}) {
	const kind = trigger.kind || 'always';
	const need = rung(trigger, cutStep);
	const result = { active: false, dice: [], kind, need, value: 0, count: 0 };
	if (kind === 'always') {
		const picked = Hand.read(a, Math.max(1, need), readSide(trigger, cutStep) !== 'low');
		result.active = true;
		result.dice = picked.dice;
		result.value = picked.sum;
		result.count = picked.dice.length;
		return result;
	}
	if (TURN_KINDS.includes(kind)) {
		// The fight tells a creature which action this is; nothing on the dice does.
		const first = Boolean(context.first_roll);
		const acted = I(context.turns_acted);
		switch (kind) {
			case 'each_turn': result.active = first; break;
			case 'every_nth_turn': result.active = first && need > 0 && acted % need === 0; break;
			// A countdown fires on the action it reaches 0 (the fight keeps the count): read as every nth.
			case 'countdown': result.active = first && (context.countdown_due !== undefined ? Boolean(context.countdown_due) : (need > 0 && acted % need === 0)); break;
			case 'emerge': result.active = first && Boolean(context.emerging); break;
			case 'on_death': result.active = Boolean(context.dying); break;
			case 'hp_below': result.active = Boolean(context.crossing); break;
			case 'action_begin': result.active = Boolean(context.action_begin); break;
		}
		result.value = I(a.total);
		if (result.active) result.dice = allDice(a);
		else result.reason = { on_death: 'Only when it dies.', hp_below: 'Only as its health falls that far.', action_begin: 'Only as its action opens.' }[kind] || 'Not this action.';
		return result;
	}
	switch (kind) {
		case 'pair': case 'triple': case 'quad': case 'quint':
			for (const group of a.groups) {
				if (group.count >= SET_SIZES[kind] && group.value >= need) {
					result.active = true; result.dice = group.dice.slice(); result.value = group.value; result.count = group.count; break;
				}
			}
			if (!result.active) {
				// The wilds went to the largest set, which was too low: they may lift another.
				const lifted = wildSet(a, SET_SIZES[kind], need);
				if (lifted) { result.active = true; result.dice = lifted.dice; result.value = lifted.value; result.count = lifted.count; }
			}
			break;
		case 'two_pair': {
			// `high_pair`: only the higher of the two pairs has to clear the rung (Mirror's).
			let qualifying = a.pairs.filter((g) => g.value >= need);
			if (trigger.high_pair) {
				qualifying = a.pairs.slice().sort((x, y) => y.value - x.value);
				if (qualifying.length >= 2 && qualifying[0].value < need) qualifying = [];
			}
			if (qualifying.length >= 2) {
				result.active = true; result.dice = qualifying[0].dice.concat(qualifying[1].dice);
				result.value = qualifying[0].value; result.second = qualifying[1].value; result.count = 4;
			} else {
				// All the wilds joined one set; split between two they may make both.
				const both = wildSets(a, 2, 2, need, Boolean(trigger.high_pair));
				if (both) { result.active = true; result.dice = both.dice; result.value = both.value; result.second = both.second; result.count = 4; }
			}
			break;
		}
		case 'full_house': {
			let triple = null;
			for (const group of a.groups) if (group.count >= 3 && group.value >= need) { triple = group; break; }
			if (triple) {
				for (const group of a.groups) {
					if (group.value !== triple.value && group.count >= 2) {
						result.active = true; result.dice = triple.dice.concat(group.dice); result.value = triple.value; result.second = group.value; result.count = 5; break;
					}
				}
			}
			if (!result.active) {
				const house = wildSets(a, 3, 2, need, false);
				if (house) { result.active = true; result.dice = house.dice; result.value = house.value; result.second = house.second; result.count = 5; }
			}
			break;
		}
		case 'straight': {
			const run = a.straight;
			if ((run.length || 0) >= need) { result.active = true; result.dice = run.dice.slice(); result.value = run.high; result.count = run.length; }
			break;
		}
		case 'all_odd': case 'all_even': {
			const parity = kind === 'all_odd' ? a.odd : a.even;
			result.active = a.dice_count >= Math.max(2, need) && parity === a.dice_count;
			result.dice = allDice(a); result.value = a.total; result.count = parity;
			break;
		}
		case 'odd': case 'even': {
			const wantedOdd = kind === 'odd';
			const have = wantedOdd ? a.odd : a.even;
			if (have >= need) {
				result.active = true; result.dice = Hand.matching(a, (v) => (v % 2 === 1) === wantedOdd); result.count = have; result.value = have;
			}
			break;
		}
		case 'distinct':
			// `high_crown`: the highest die has to be on its top face as well (Clean Kill's).
			if (a.distinct >= need && (!trigger.high_crown || I(a.high_crown) > 0)) {
				result.active = true;
				const dice = [];
				for (const ids of a.ids_by_value.values()) dice.push(ids[0]);
				dice.push(...a.wilds);
				result.dice = dice; result.count = a.distinct; result.value = a.distinct;
			}
			break;
		case 'value': {
			// Read off the faces: "showing 1" is a die that landed on its 1, Doubled or not.
			const wanted = (trigger.values || [7]).map(Number);
			const dice = Hand.matchingShown(a, (v) => wanted.includes(v));
			if (dice.length >= Math.max(1, need)) { result.active = true; result.dice = dice; result.count = dice.length; result.value = wanted.length ? Number(wanted[0]) : 0; }
			break;
		}
		case 'at_most': case 'below': {
			const judge = (v) => (kind === 'below' ? v < need : v <= need);
			const dice = kind === 'below' ? Hand.matchingFaces(a, judge) : Hand.matching(a, judge);
			if (dice.length >= 1) { result.active = true; result.dice = dice; result.count = dice.length; result.value = need; }
			break;
		}
		case 'at_least':
			if (a.high >= need) { result.active = true; result.dice = Hand.matching(a, (v) => v >= need); result.value = a.high; result.count = result.dice.length; }
			break;
		case 'total_pct_at_least':
			if (a.total * 100 >= a.max_total * need) { result.active = true; result.dice = allDice(a); result.value = a.total; }
			break;
		case 'total_pct_at_most': {
			// A wild is any value, so a gem that wants a low total reads it as a 1.
			const lowTotal = a.total - I(a.wild_total) + (a.wilds || []).length;
			if (lowTotal * 100 <= a.max_total * need) { result.active = true; result.dice = allDice(a); result.value = a.total; }
			break;
		}
		case 'high_pct_at_least':
			if (a.high_pct >= need) { result.active = true; result.dice = Hand.matching(a, (v) => v >= a.high); result.value = a.high; }
			break;
		case 'held':
			if (a.held >= need) { result.active = true; result.count = a.held; result.value = a.held; }
			break;
		case 'rerolled':
			if (a.rerolled >= need) { result.active = true; result.count = a.rerolled; result.value = a.rerolled; }
			break;
		case 'pyrite':
			result.active = (I(context.pyrite)) >= need; result.value = I(context.pyrite);
			break;
		case 'fizzles':
			// Gems that stayed dark earlier this turn and have not yet paid this stone.
			result.active = (I(context.fizzles)) >= need; result.count = I(context.fizzles); result.value = I(context.fizzles);
			break;
		case 'kills':
			// Creatures fallen this turn, before this gem: the fight counts them, not the dice.
			result.active = (I(context.kills)) >= Math.max(1, need); result.count = I(context.kills); result.value = I(context.kills);
			break;
		case 'resonance':
			if ((I(context.resonance)) >= need) { result.active = true; result.value = I(context.resonance); }
			break;
		case 'low_count':
			if (a.low_dice >= need) { result.active = true; result.dice = a.low_ids.slice(); result.count = a.low_dice; result.value = a.low_dice; }
			break;
		case 'crowns':
			if (a.crowns >= need) { result.active = true; result.dice = a.crown_ids.slice(); result.count = a.crowns; result.value = a.crowns; }
			break;
		case 'crowns_at_most':
			if (a.crowns <= need) { result.active = true; result.count = a.crowns; result.value = a.crowns; }
			break;
		case 'skip_straight': {
			const oddValues = a.odd_values, evenValues = a.even_values;
			if (Math.max(oddValues, evenValues) >= need) {
				result.active = true;
				const wantOdd = oddValues >= evenValues;
				const dice = [];
				for (const [v, ids] of a.ids_by_value) if ((v % 2 === 1) === wantOdd) dice.push(ids[0]);
				dice.push(...a.wilds);
				result.dice = dice; result.count = Math.max(oddValues, evenValues); result.value = a.high; result.odd = wantOdd;
			}
			break;
		}
		case 'distinct_dominant':
			if (a.distinct >= need && a.high * 2 > a.total) {
				result.active = true;
				const dice = [];
				for (const ids of a.ids_by_value.values()) dice.push(ids[0]);
				dice.push(...a.wilds);
				result.dice = dice; result.count = a.distinct; result.value = a.high;
			}
			break;
	}
	if (!result.active) result.reason = words(trigger, cutStep);
	return result;
}

export function label(trigger, cutStep) {
	// The short label the game draws beside the trigger mark.
	const kind = trigger.kind || 'always';
	const need = rung(trigger, cutStep);
	if (kind !== 'always' && unconditional(kind, need)) return 'any hand';
	switch (kind) {
		case 'always': return `${readSide(trigger, cutStep) === 'low' ? 'low' : 'high'} ×${Math.max(1, need)}`;
		case 'pair': case 'triple': case 'quad': case 'quint': case 'full_house': case 'two_pair': return need > 1 ? `${need}+` : 'any';
		case 'straight': case 'odd': case 'even': case 'distinct': case 'held': case 'rerolled': case 'resonance': case 'low_count': case 'crowns': case 'skip_straight': case 'distinct_dominant': return `×${need}`;
		case 'crowns_at_most': return `≤${need}`;
		case 'value': { const wanted = (trigger.values || [7]).join('/'); return need > 1 ? `${wanted} ×${need}` : wanted; }
		case 'pyrite': return `≥${need} pyrite`;
		case 'fizzles': case 'kills': return need > 1 ? `×${need}` : '';
		case 'below': return `<${need}`;
		case 'each_turn': return 'each action';
		case 'every_nth_turn': return `÷${need}`;
		case 'countdown': return `${need}…0`;
		case 'emerge': return 'emerging';
		case 'on_death': return 'on death';
		case 'hp_below': return `≤${need}% health`;
		case 'action_begin': return 'action opens';
		case 'at_most': return `≤${need}`;
		case 'at_least': return `≥${need}`;
		case 'total_pct_at_least': case 'high_pct_at_least': return `≥${need}%`;
		case 'total_pct_at_most': return `≤${need}%`;
	}
	return String(need);
}

// The mark the game draws for a trigger (sim/patterns.gd describe): the hourglass and skull
// are the creature-only turn kinds.
export function mark(trigger, cutStep) {
	const kind = trigger.kind || 'always';
	const need = rung(trigger, cutStep);
	if (kind !== 'always' && unconditional(kind, need)) return 'read_high';
	if (kind === 'always') return readSide(trigger, cutStep) !== 'low' ? 'read_high' : 'read_low';
	if (kind === 'each_turn' || kind === 'emerge' || kind === 'every_nth_turn' || kind === 'action_begin' || kind === 'countdown') return 'hourglass';
	if (kind === 'on_death' || kind === 'hp_below') return 'skull';
	return kind;
}

export function ordinal(n) {
	switch (n) {
		case 1: return 'first';
		case 2: return 'second';
		case 3: return 'third';
		case 4: return 'fourth';
		case 5: return 'fifth';
	}
	return `${n}th`;
}

const dice = (n) => `${n} ${n === 1 ? 'die' : 'dice'}`;
const ofAtLeast = (n) => (n > 1 ? ` of ${n}s or higher` : '');

export function words(trigger, cutStep) {
	const kind = trigger.kind || 'always';
	const need = rung(trigger, cutStep);
	if (kind !== 'always' && unconditional(kind, need)) return 'Fires on every hand.';
	switch (kind) {
		case 'always': {
			const count = Math.max(1, need);
			const side = readSide(trigger, cutStep) === 'low' ? 'lowest' : 'highest';
			return count === 1 ? `Fires on every hand and reads your ${side} die.` : `Fires on every hand and reads your ${side} ${count} dice.`;
		}
		case 'all_odd': return `All dice odd (${Math.max(2, need)} or more).`;
		case 'all_even': return `All dice even (${Math.max(2, need)} or more).`;
		case 'pair': return `A pair${ofAtLeast(need)}.`;
		case 'triple': return `Three of a kind${ofAtLeast(need)}.`;
		case 'quad': return `Four of a kind${ofAtLeast(need)}.`;
		case 'quint': return `Five of a kind${ofAtLeast(need)}.`;
		case 'two_pair': return trigger.high_pair && need > 1 ? `Two pairs, the higher one ${need} or more.` : `Two pairs${ofAtLeast(need)}.`;
		case 'full_house': return `A full house: three of one value and two of another${need > 1 ? `, the three ${need} or higher` : ''}.`;
		case 'straight': return `A straight of ${need}: ${need} consecutive values in any order.`;
		case 'odd': return `At least ${dice(need)} showing odd values.`;
		case 'even': return `At least ${dice(need)} showing even values.`;
		case 'distinct': return trigger.high_crown ? `At least ${dice(need)} with no two alike, the highest a crown.` : `At least ${dice(need)} with no two alike.`;
		case 'value': return `At least ${need} ${need === 1 ? 'die' : 'dice'} showing a ${(trigger.values || [7]).join(' or ')}.`;
		case 'pyrite': return `At least ${need} Pyrite.`;
		case 'fizzles': return `At least ${need} ${need === 1 ? 'gem' : 'gems'} fizzled earlier this turn.`;
		case 'kills': return `At least ${Math.max(1, need)} ${Math.max(1, need) === 1 ? 'creature has' : 'creatures have'} died this turn.`;
		case 'below': return `At least one die showing less than ${need}.`;
		case 'at_most': return `At least one die showing ${need} or less.`;
		case 'at_least': return `Your highest die shows ${need} or more.`;
		case 'total_pct_at_least': return `Your total is at least ${need}% of the most your dice could roll.`;
		case 'total_pct_at_most': return `Your total is at most ${need}% of the most your dice could roll.`;
		case 'high_pct_at_least': return `One die showing at least ${need}% of its size (a 6 on a d6 is 100%).`;
		case 'held': return `At least ${dice(need)} you did not reroll.`;
		case 'rerolled': return `At least ${dice(need)} you rerolled this turn.`;
		case 'resonance': return `Resonance of ${need} or more when this gem is reached.`;
		case 'low_count': return need === 1 ? 'At least one die in the low half of its size (1-3 on a d6).' : `At least ${dice(need)} in the low half of their size (1-3 on a d6).`;
		case 'crowns': return `At least ${need} ${need === 1 ? 'crown' : 'crowns'}: ${need === 1 ? 'a die' : 'dice'} on ${need === 1 ? 'its' : 'their'} own top face.`;
		case 'crowns_at_most': return need === 0 ? 'No crowns: no die on its top face.' : `No more than ${need} ${need === 1 ? 'crown' : 'crowns'}.`;
		case 'skip_straight': return `${need} different values, all odd or all even, like 2-4-6-8-10.`;
		case 'distinct_dominant': return `${need} different values, the highest die outrolling the other ${need - 1} combined.`;
		case 'each_turn': return 'Every action, once, before its dice.';
		case 'every_nth_turn': return `Every ${ordinal(need)} action, once, before its dice.`;
		case 'countdown': return `When its countdown from ${need} reaches 0, once, before its dice.`;
		case 'emerge': return 'The action after it burrowed, once, before its dice.';
		case 'on_death': return 'When it dies.';
		case 'hp_below': return `Once, the moment its health falls to ${need}%.`;
		case 'action_begin': return 'Every action, as it opens, before any die is thrown.';
	}
	return 'Its trigger.';
}

// A plain-English name for a trigger kind, for tables.
export const KIND_NAMES = {
	always: 'Every hand', pair: 'Pair', two_pair: 'Two pair', triple: 'Three of a kind', full_house: 'Full house', quad: 'Four of a kind', quint: 'Five of a kind',
	straight: 'Straight', odd: 'Odd dice', even: 'Even dice', distinct: 'Distinct values', value: 'Specific value', at_most: 'A low die', below: 'A die below',
	at_least: 'High die', total_pct_at_least: 'Total ≥ % of max', total_pct_at_most: 'Total ≤ % of max', high_pct_at_least: 'Die ≥ % of its top',
	held: 'Held dice', rerolled: 'Rerolled dice', resonance: 'Resonance', low_count: 'Low dice', crowns: 'Crowns', crowns_at_most: 'Few crowns',
	skip_straight: 'Skip straight', distinct_dominant: 'Dominant high die', pyrite: 'Pyrite in hand', fizzles: 'Earlier fizzles', kills: 'Kills this turn', all_odd: 'All odd', all_even: 'All even',
	each_turn: 'Each action', every_nth_turn: 'Every nth action', emerge: 'When it comes up', on_death: 'When it dies',
	hp_below: 'Health falls to', action_begin: 'Action opens', countdown: 'Countdown',
};
