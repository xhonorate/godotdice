// What a hand has to show before a gem fires: a port of sim/patterns.gd.

import * as Hand from './hand.js';

export const KINDS = ['all_odd', 'all_even', 'always', 'pair', 'two_pair', 'triple', 'full_house', 'quad', 'quint', 'straight',
	'odd', 'even', 'distinct', 'value', 'at_most', 'at_least', 'total_pct_at_least', 'total_pct_at_most',
	'high_pct_at_least', 'held', 'rerolled', 'resonance', 'low_count', 'crowns', 'crowns_at_most', 'skip_straight', 'distinct_dominant', 'pyrite', 'below'];
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

function allDice(a) {
	const dice = [];
	for (const ids of a.ids_by_value.values()) dice.push(...ids);
	dice.push(...a.wilds);
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
	if (a.gem_face && kind !== 'pyrite') {
		result.active = true;
		result.gem_face = true;
		result.dice = allDice(a);
		result.value = a.best_set.value || a.high;
		result.count = Math.max(1, a.best_set.count || 1);
		return result;
	}
	switch (kind) {
		case 'pair': case 'triple': case 'quad': case 'quint':
			for (const group of a.groups) {
				if (group.count >= SET_SIZES[kind] && group.value >= need) {
					result.active = true; result.dice = group.dice.slice(); result.value = group.value; result.count = group.count; break;
				}
			}
			break;
		case 'two_pair': {
			const qualifying = a.pairs.filter((g) => g.value >= need);
			if (qualifying.length >= 2) {
				result.active = true; result.dice = qualifying[0].dice.concat(qualifying[1].dice);
				result.value = qualifying[0].value; result.second = qualifying[1].value; result.count = 4;
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
			if (a.distinct >= need) {
				result.active = true;
				const dice = [];
				for (const ids of a.ids_by_value.values()) dice.push(ids[0]);
				dice.push(...a.wilds);
				result.dice = dice; result.count = a.distinct; result.value = a.distinct;
			}
			break;
		case 'value': {
			const wanted = trigger.values || [7];
			const dice = Hand.matching(a, (v) => wanted.includes(v));
			if (dice.length >= Math.max(1, need)) { result.active = true; result.dice = dice; result.count = dice.length; result.value = wanted.length ? Number(wanted[0]) : 0; }
			break;
		}
		case 'at_most': case 'below': {
			const dice = Hand.matching(a, (v) => (kind === 'below' ? v < need : v <= need));
			if (dice.length >= 1) { result.active = true; result.dice = dice; result.count = dice.length; result.value = need; }
			break;
		}
		case 'at_least':
			if (a.high >= need) { result.active = true; result.dice = Hand.matching(a, (v) => v >= need); result.value = a.high; result.count = result.dice.length; }
			break;
		case 'total_pct_at_least':
			if (a.total * 100 >= a.max_total * need) { result.active = true; result.dice = allDice(a); result.value = a.total; }
			break;
		case 'total_pct_at_most':
			if (a.total * 100 <= a.max_total * need) { result.active = true; result.dice = allDice(a); result.value = a.total; }
			break;
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
			result.active = (context.pyrite | 0) >= need; result.value = context.pyrite | 0;
			break;
		case 'resonance':
			if ((context.resonance | 0) >= need) { result.active = true; result.value = context.resonance | 0; }
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
		case 'below': return `<${need}`;
		case 'at_most': return `≤${need}`;
		case 'at_least': return `≥${need}`;
		case 'total_pct_at_least': case 'high_pct_at_least': return `≥${need}%`;
		case 'total_pct_at_most': return `≤${need}%`;
	}
	return String(need);
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
		case 'two_pair': return `Two pairs${ofAtLeast(need)}.`;
		case 'full_house': return `A full house: three of one value and two of another${need > 1 ? `, the three ${need} or higher` : ''}.`;
		case 'straight': return `A straight of ${need}: ${need} consecutive values in any order.`;
		case 'odd': return `At least ${dice(need)} showing odd values.`;
		case 'even': return `At least ${dice(need)} showing even values.`;
		case 'distinct': return `At least ${dice(need)} with no two alike.`;
		case 'value': return `At least ${need} ${need === 1 ? 'die' : 'dice'} showing a ${(trigger.values || [7]).join(' or ')}.`;
		case 'pyrite': return `At least ${need} Pyrite.`;
		case 'below': return `At least one die showing less than ${need}.`;
		case 'at_most': return `At least one die showing ${need} or less.`;
		case 'at_least': return `Your highest die shows ${need} or more.`;
		case 'total_pct_at_least': return `Your total is at least ${need}% of the most your dice could roll.`;
		case 'total_pct_at_most': return `Your total is at most ${need}% of the most your dice could roll.`;
		case 'high_pct_at_least': return `One die shows at least ${need}% of its own top face.`;
		case 'held': return `At least ${dice(need)} you did not reroll.`;
		case 'rerolled': return `At least ${dice(need)} you rerolled this turn.`;
		case 'resonance': return `Resonance of ${need} or more when this gem is reached.`;
		case 'low_count': return need === 1 ? `At least ${dice(need)} at or below half its own top face.` : `At least ${dice(need)} at or below half their own top face.`;
		case 'crowns': return `At least ${need} ${need === 1 ? 'die' : 'dice'} showing ${need === 1 ? 'its' : 'their'} own top face.`;
		case 'crowns_at_most': return need === 0 ? 'No die on its top face.' : `No more than ${need} dice on their top face.`;
		case 'skip_straight': return `${need} different values, all odd or all even, like 2-4-6-8-10.`;
		case 'distinct_dominant': return `${need} different values, the highest die outrolling the other ${need - 1} combined.`;
	}
	return 'Its trigger.';
}

// A plain-English name for a trigger kind, for tables.
export const KIND_NAMES = {
	always: 'Every hand', pair: 'Pair', two_pair: 'Two pair', triple: 'Three of a kind', full_house: 'Full house', quad: 'Four of a kind', quint: 'Five of a kind',
	straight: 'Straight', odd: 'Odd dice', even: 'Even dice', distinct: 'Distinct values', value: 'Specific value', at_most: 'A low die', below: 'A die below',
	at_least: 'High die', total_pct_at_least: 'Total ≥ % of max', total_pct_at_most: 'Total ≤ % of max', high_pct_at_least: 'Die ≥ % of its top',
	held: 'Held dice', rerolled: 'Rerolled dice', resonance: 'Resonance', low_count: 'Low dice', crowns: 'Crowns', crowns_at_most: 'Few crowns',
	skip_straight: 'Skip straight', distinct_dominant: 'Dominant high die', pyrite: 'Pyrite in hand', all_odd: 'All odd', all_even: 'All even',
};
