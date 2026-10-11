// What a hand of rolls contains: a port of sim/hand.gd, field for field.

import { heldForPatterns, preference } from './dice.js';

export function analyze(hand, colors = []) {
	const values = [];
	const idsByValue = new Map();
	const counts = new Map();
	const wilds = [];
	let wildTop = 0;
	const rank = new Map();
	let total = 0, maxTotal = 0, held = 0, rerolled = 0, phantoms = 0, high = 0, low = 0, highPct = 0, odd = 0, even = 0, lowDice = 0, crowns = 0;
	const lowIds = [];
	const crownIds = [];
	let crownTotal = 0;
	const crownValues = new Set();
	for (let index = 0; index < hand.length; index += 1) {
		const roll = hand[index];
		const kind = roll.kind || 'plain';
		const value = roll.value | 0;
		const top = Math.max(1, roll.top ?? value);
		const id = roll.die_id || '';
		// Higher wants it more; the bench order breaks a tie, so a hand reads the same twice.
		rank.set(id, preference(roll, colors) * 1000 - index);
		maxTotal += top;
		if (roll.phantom) phantoms += 1;
		if (heldForPatterns(roll)) held += 1;
		if ((roll.rerolls | 0) > 0) rerolled += 1;
		if (kind === 'wild') {
			wilds.push(id);
			wildTop = Math.max(wildTop, top);
			total += top;
			highPct = 100;
			crowns += 1;
			crownIds.push(id);
			crownTotal += top;
			continue;
		}
		if (kind === 'blank') continue;
		total += value;
		values.push(value);
		high = Math.max(high, value);
		low = low === 0 ? value : Math.min(low, value);
		highPct = Math.max(highPct, Math.floor((value * 100) / top));
		if (value % 2 === 1) odd += 1; else even += 1;
		if (value * 2 <= top) { lowDice += 1; lowIds.push(id); }
		if (value >= top) { crowns += 1; crownIds.push(id); crownTotal += value; crownValues.add(value); }
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
		values, wilds, rank, total, max_total: Math.max(1, maxTotal),
		high: high > 0 ? high : wildTop, low: low > 0 ? low : wildTop, high_pct: highPct,
		held, rerolled, phantoms, dice_count: hand.length,
		groups, best_set: groups.length ? groups[0] : { value: 0, count: 0, dice: [] },
		pairs, straight: straightOf(counts, wilds, idsByValue, hand.length, wildTop),
		odd: odd + wilds.length, even: even + wilds.length, distinct: counts.size + wilds.length,
		odd_values: oddValues + wilds.length, even_values: evenValues + wilds.length,
		low_dice: lowDice, low_ids: lowIds, crowns, crown_ids: crownIds, crown_total: crownTotal,
		high_crown: (high > 0 && crownValues.has(high)) || (high === 0 && wilds.length > 0) ? 1 : 0, ids_by_value: idsByValue,
	};
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
			// A run needs at least length - wilds present values, so only lows near them can work.
			const from = Math.max(1, minPresent - length + 1);
			const to = maxPresent;
			for (let low = from; low <= to; low++) {
				let missing = 0;
				for (let v = low; v < low + length; v++) if (!present.has(v)) missing += 1;
				if (missing <= wilds.length) foundLow = low;
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

// The N highest (or lowest) dice, as {sum, dice}. Wilds read as the hand's high.
export function read(analysis, count, fromHigh) {
	const entries = [];
	for (const [v, ids] of analysis.ids_by_value) for (const id of ids) entries.push({ value: v, id });
	for (const id of analysis.wilds) entries.push({ value: analysis.high, id });
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
