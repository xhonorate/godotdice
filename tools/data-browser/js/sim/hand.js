// What a hand of rolls contains: a port of sim/hand.gd, field for field.

import { heldForPatterns, preference, sizeOf, TIERS } from './dice.js';
import { I } from './numbers.js';

// Besides what sim/hand.gd lists: `sizes` (die id to how many faces a plain die of its shape
// has), `one_ids` (the dice whose face shows a 1; a wild is not one of them) and `scale`
// ({length, dice, values, total}: the longest climb across the dice from the smallest die to the
// largest, each showing more than the one before, for an Arpeggio).
export function analyze(hand, colors = []) {
	const values = [];
	const idsByValue = new Map();
	const bases = new Map();
	const showing = new Map();
	const counts = new Map();
	const sizes = new Map();
	const oneIds = [];
	const notes = [];
	const wilds = [];
	let wildTop = 0, wildTotal = 0;
	const wildTops = new Map();
	const rank = new Map();
	let total = 0, maxTotal = 0, held = 0, rerolled = 0, phantoms = 0, high = 0, low = 0, highPct = 0, odd = 0, even = 0, lowDice = 0, crowns = 0;
	const lowIds = [];
	const crownIds = [];
	let crownTotal = 0;
	const crownValues = new Set();
	for (let index = 0; index < hand.length; index += 1) {
		const roll = hand[index];
		const kind = roll.kind || 'plain';
		const value = I(roll.value);
		const top = Math.max(1, roll.top ?? value);
		// Low and high are judged against the plain die's size, never its faces: filing, carving
		// or raising a face does not move the line (1-3 low on a d6, 4-6 high). A roll with no
		// shape falls back to its top. Crowns and max_total still read top.
		const faces = roll.shape ? sizeOf(roll.shape) : top;
		const id = roll.die_id || '';
		// Higher wants it more; the bench order breaks a tie, so a hand reads the same twice.
		rank.set(id, preference(roll, colors) * 1000 - index);
		sizes.set(id, faces);
		maxTotal += top;
		if (roll.phantom) phantoms += 1;
		if (heldForPatterns(roll)) held += 1;
		if ((I(roll.rerolls)) > 0) rerolled += 1;
		if (kind === 'wild') {
			// Any value at all: its top for the high end, and low for a gem that wants low dice.
			wilds.push(id);
			wildTop = Math.max(wildTop, top);
			wildTops.set(id, top);
			wildTotal += top;
			total += top;
			highPct = 100;
			crowns += 1;
			crownIds.push(id);
			crownTotal += top;
			lowDice += 1;
			lowIds.push(id);
			notes.push({ id, value: top, size: faces, index });
			continue;
		}
		if (kind === 'blank') continue;
		notes.push({ id, value, size: faces, index });
		total += value;
		if (kind === 'exploding' && 'base' in roll) bases.set(id, I(roll.base));
		values.push(value);
		high = Math.max(high, value);
		low = low === 0 ? value : Math.min(low, value);
		highPct = Math.max(highPct, Math.floor((value * 100) / faces));
		if (value % 2 === 1) odd += 1; else even += 1;
		if (value * 2 <= faces) { lowDice += 1; lowIds.push(id); }
		if (value >= top) { crowns += 1; crownIds.push(id); crownTotal += value; crownValues.add(value); }
		// A gem may have changed the roll since it was thrown; then what it shows is what it is.
		const shown = 'shown' in roll && value === I(roll.counted ?? -1) ? I(roll.shown) : value;
		if (!showing.has(shown)) showing.set(shown, []);
		showing.get(shown).push(id);
		if (shown === 1) oneIds.push(id);
		counts.set(value, (counts.get(value) || 0) + (kind === 'twin' || roll.twinned ? 2 : 1));
		if (!idsByValue.has(value)) idsByValue.set(value, []);
		idsByValue.get(value).push(id);
	}
	const prefer = (ids) => ids.sort((a, b) => (rank.get(b) || 0) - (rank.get(a) || 0));
	for (const ids of idsByValue.values()) prefer(ids);
	prefer(wilds);
	// Sets. The wilds go to the largest group, or make one of their own.
	let bestValue = 0, bestCount = 0;
	for (const [v, c] of counts) {
		if (c > bestCount || (c === bestCount && v > bestValue)) { bestValue = v; bestCount = c; }
	}
	const sets = new Map(counts);
	if (wilds.length > 0) {
		if (bestCount === 0) { bestValue = wildTop; sets.set(wildTop, wilds.length); }
		else sets.set(bestValue, bestCount + wilds.length);
	}
	// The sets the numbers make before any wild joins one: a trigger that wants two sets
	// places the wilds itself (patterns.js), since the largest set is not always where they help.
	const plainGroups = [];
	for (const [value, count] of counts) plainGroups.push({ value, count, dice: (idsByValue.get(value) || []).slice() });
	plainGroups.sort((a, b) => (a.count !== b.count ? b.count - a.count : b.value - a.value));
	const groups = [];
	for (const [value, count] of sets) {
		const dice = (idsByValue.get(value) || []).slice();
		if (value === bestValue && wilds.length > 0) dice.push(...wilds);
		groups.push({ value, count, dice });
	}
	groups.sort((a, b) => (a.count !== b.count ? b.count - a.count : b.value - a.value));
	const pairs = groups.filter((g) => g.count >= 2);
	let oddValues = 0, evenValues = 0;
	for (const v of counts.keys()) { if (v % 2 === 1) oddValues += 1; else evenValues += 1; }
	return {
		values, wilds, wild_tops: wildTops, wild_total: wildTotal, rank, total, max_total: Math.max(1, maxTotal),
		high: Math.max(high, wildTop), low: low > 0 ? low : wildTop, high_pct: highPct,
		held, rerolled, phantoms, dice_count: hand.length,
		groups, plain_groups: plainGroups, best_set: groups.length ? groups[0] : { value: 0, count: 0, dice: [] },
		pairs, straight: straightOf(counts, wilds, idsByValue, hand.length, wildTop),
		odd: odd + wilds.length, even: even + wilds.length, distinct: counts.size + wilds.length,
		odd_values: oddValues + wilds.length, even_values: evenValues + wilds.length,
		low_dice: lowDice, low_ids: lowIds, crowns, crown_ids: crownIds, crown_total: crownTotal,
		high_crown: (wilds.length > 0 && wildTop >= high) || (high > 0 && crownValues.has(high)) ? 1 : 0, ids_by_value: idsByValue,
		bases, showing, sizes, one_ids: oneIds, scale: scaleOf(notes),
	};
}

// The longest climb across the dice from the smallest die to the largest, each showing more than
// the one before it. Dice of one size keep their bench order. Between two climbs as long, the one
// that adds up to more. A wild reads as its die's top, as `high` reads it.
function scaleOf(notes) {
	const order = notes.slice().sort((x, y) => (x.size !== y.size ? x.size - y.size : x.index - y.index));
	const length = [];
	const total = [];
	const before = [];
	for (let i = 0; i < order.length; i++) {
		length.push(1);
		total.push(order[i].value);
		before.push(-1);
		for (let j = 0; j < i; j++) {
			if (order[j].value >= order[i].value) continue;
			const longer = length[j] + 1;
			const more = total[j] + order[i].value;
			if (longer > length[i] || (longer === length[i] && more > total[i])) { length[i] = longer; total[i] = more; before[i] = j; }
		}
	}
	let best = -1;
	for (let i = 0; i < order.length; i++) if (best < 0 || length[i] > length[best] || (length[i] === length[best] && total[i] > total[best])) best = i;
	const dice = [];
	const values = [];
	for (let at = best; at >= 0; at = before[at]) { dice.unshift(String(order[at].id)); values.unshift(order[at].value); }
	return { length: dice.length, dice, values, total: best >= 0 ? total[best] : 0 };
}

// How many sizes over a d4 these dice are, added up: a d6 is one, a d8 two, a d10 three.
export function sizeSteps(analysis, ids) {
	let steps = 0;
	for (const id of ids || []) {
		const faces = I(analysis.sizes?.has(String(id)) ? analysis.sizes.get(String(id)) : 4);
		for (const key of TIERS) { const size = sizeOf(key); if (size > 4 && size <= faces) steps += 1; }
	}
	return steps;
}

function straightOf(counts, wilds, idsByValue, diceTotal, wildTop = 0) {
	// The longest run of consecutive values, wilds filling gaps, preferring the highest run.
	// Faces have no ceiling: a run of nothing but wilds tops out at the best top among them.
	const present = counts;
	let best = { length: 0, high: 0, low: 0, dice: [] };
	const longest = Math.min(diceTotal, present.size + wilds.length);
	let minPresent = Infinity, maxPresent = -Infinity;
	for (const v of present.keys()) { if (v < minPresent) minPresent = v; if (v > maxPresent) maxPresent = v; }
	for (let length = longest; length >= 1; length--) {
		let foundLow = -1;
		if (present.size === 0) foundLow = Math.max(1, wildTop - length + 1);
		else {
			// A run needs at least one value showing, so only the lows within a run's length of the
			// values present can work. Between two of them what a run holds stays the same, so the
			// highest low that works is always one just before a value comes in or goes out (or the
			// highest value itself): faces can be far apart, and the lows between need no trying.
			const floorLow = Math.max(1, minPresent - length + 1);
			const lows = [maxPresent];
			for (const v of present.keys()) lows.push(v, v - length);
			for (const low of lows) {
				if (low < floorLow || low > maxPresent || low <= foundLow) continue;
				let held = 0;
				for (const v of present.keys()) if (v >= low && v < low + length) held += 1;
				if (length - held <= wilds.length) foundLow = low;
			}
		}
		if (foundLow > 0) {
			const dice = [];
			let usedWilds = 0;
			for (let v = foundLow; v < foundLow + length; v++) {
				if (present.has(v)) dice.push(idsByValue.get(v)[0]);
				else dice.push(wilds[usedWilds++]);
			}
			best = { length, high: foundLow + length - 1, low: foundLow, dice };
			break;
		}
	}
	return best;
}

// The N highest (or lowest) dice, as {sum, dice}. Wilds read as the die's top.
export function read(analysis, count, fromHigh) {
	const entries = [];
	for (const [v, ids] of analysis.ids_by_value) for (const id of ids) entries.push({ value: v, id });
	for (const id of analysis.wilds) entries.push({ value: analysis.wild_tops?.has(id) ? analysis.wild_tops.get(id) : analysis.high, id });
	const rank = analysis.rank || new Map();
	entries.sort((a, b) => (a.value !== b.value ? (fromHigh ? b.value - a.value : a.value - b.value) : (rank.get(b.id) || 0) - (rank.get(a.id) || 0)));
	let sum = 0;
	const dice = [];
	for (let i = 0; i < Math.min(count, entries.length); i++) { sum += entries[i].value; dice.push(entries[i].id); }
	return { sum, dice };
}

// Die ids whose value satisfies the predicate, plus every wild.
export function matching(analysis, predicate) {
	const dice = [];
	for (const [v, ids] of analysis.ids_by_value) if (predicate(v)) dice.push(...ids);
	dice.push(...analysis.wilds);
	return dice;
}

// Like `matching`, but an exploding die is judged by the face it landed on rather than by
// everything that face threw again: a 2 that went off into a 19 is still a 2 to a gem that
// wants low faces.
export function matchingFaces(analysis, predicate) {
	const bases = analysis.bases || new Map();
	const dice = [];
	for (const [v, ids] of analysis.ids_by_value) for (const id of ids) if (predicate(bases.has(id) ? bases.get(id) : v)) dice.push(id);
	dice.push(...analysis.wilds);
	return dice;
}

// Die ids whose face shows a number the predicate wants, plus every wild: a Doubled 1 is
// showing a 1, whatever it counts for. An analysis without `showing` reads the counted values.
export function matchingShown(analysis, predicate) {
	if (!analysis.showing) return matching(analysis, predicate);
	const dice = [];
	for (const [v, ids] of analysis.showing) if (predicate(v)) dice.push(...ids);
	const rank = analysis.rank || new Map();
	dice.sort((a, b) => (rank.get(b) || 0) - (rank.get(a) || 0));
	dice.push(...analysis.wilds);
	return dice;
}
