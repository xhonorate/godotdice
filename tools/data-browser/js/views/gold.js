// Gold at home (docs/GOLD.md): what each mine charges and pays, set beside what its stones
// are worth, so a price can be judged against the rock it is paid in.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import * as Stone from '../sim/stone.js';
import { makeRng } from '../sim/rng.js';
import { h, card, stat, table, fmt, note } from '../ui.js';

const SAMPLES = 3000;

function minesInOrder() {
	return C.keys('mines').sort((a, b) => (C.mine(a).tier ?? 99) - (C.mine(b).tier ?? 99));
}

// The mean worth of a stone found at a depth, sampled the way the game rolls one.
function meanWorth(mine, depth, seed) {
	const rng = makeRng(seed);
	let total = 0;
	for (let i = 0; i < SAMPLES; i++) total += Stone.value(Forge.rollStone(rng, mine, depth, 0));
	return total / SAMPLES;
}

// What a commission with no requirement pays for each skill an open mine can ask for: 2.5×
// what the least stone of it (3 carats, Fair, Clear) would sell for, rounded to five.
function commissionRange(mine) {
	const mult = Number(C.constant('commission_payout_mult', 2.5));
	const clear = C.clearIndex();
	const pays = Forge.skillPool(mine).filter((k) => C.skill(k).color !== 'OPAL')
		.map((k) => Math.max(5, Math.round((Stone.value(Stone.make(k, 3, 1, clear)) * mult) / 5) * 5));
	return pays.length ? [Math.min(...pays), Math.max(...pays)] : [0, 0];
}

export default {
	id: 'gold', label: 'Gold', blurb: 'Fares, insurance, sockets, the assayer and commissions, against what stones are worth', count: () => '',
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><ellipse cx="12" cy="7" rx="7" ry="3"/><path d="M5 7v5c0 1.7 3.1 3 7 3s7-1.3 7-3V7"/><path d="M5 12v5c0 1.7 3.1 3 7 3s7-1.3 7-3v-5"/></svg>',
	render(root) {
		const rate = Number(C.constant('assay_rate', 5));
		const sockets = C.constant('socket_unlock_gold', []);
		const reroll = Number(C.constant('commission_reroll_gold', 10));
		const step = Number(C.constant('commission_reroll_step', 10));
		root.append(h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(5, minmax(0,1fr))' } },
			stat('Assay rate', `${rate} : 1`, 'pyrite to the gold, earned pyrite only', { class: 'accent' }),
			stat('Sockets', sockets.join(' · '), 'the 4th, 5th and 6th, per lapidary, for good'),
			stat('Commission pay', `×${C.constant('commission_payout_mult', 2.5)}`, 'of the least stone that meets it; never under 1.25× the stone handed in'),
			stat('Rerolls', `free, ${reroll}, ${reroll + step}, …`, 'per day, across all three commissions'),
			stat('Commissions', String(C.constant('commission_slots', 3)), `a day; ${C.constant('commission_requirement_pct', 50)}% ask for one of the four C's too`)));

		const rows = minesInOrder().map((key, i) => {
			const mine = C.mine(key);
			const bottom = mine.endless ? 24 : (mine.depth | 0);
			const [low, high] = commissionRange(mine);
			const purse = mine.start_pyrite | 0;
			return {
				key, name: mine.name || key, fare: mine.fare_gold | 0, insurance: mine.insurance_gold | 0, purse,
				cashed: Math.floor(purse / rate), conquest: mine.first_conquest_gold | 0,
				top: meanWorth(mine, 1, 101 + i), deep: meanWorth(mine, bottom, 202 + i), bottom, commission: `${low}–${high}`,
			};
		});
		root.append(card('By mine', table({
			columns: [
				{ key: 'name', label: 'Mine' },
				{ key: 'fare', label: 'Fare', align: 'right', title: 'Gold each lapidary pays at the shaft head to start here' },
				{ key: 'insurance', label: 'Insurance', align: 'right', title: 'Gold for every salvage die thrown twice if the dig is lost' },
				{ key: 'purse', label: 'Purse', align: 'right', title: 'Pyrite each lapidary starts with' },
				{ key: 'cashed', label: 'Purse if cashed', align: 'right', title: 'What the purse would fetch at the assay if it could be cashed (it cannot): always under the fare', render: (r) => (r.purse ? `${r.cashed} (never)` : '—') },
				{ key: 'conquest', label: 'First conquest', align: 'right', render: (r) => (r.conquest ? fmt(r.conquest, 0) : '—') },
				{ key: 'top', label: 'Stone, top', align: 'right', title: 'Mean sale value of a stone found at depth 1', render: (r) => fmt(r.top, 0) },
				{ key: 'deep', label: 'Stone, bottom', align: 'right', title: 'Mean sale value of a stone found on the bottom floor (depth 24 for the Rift)', render: (r) => `${fmt(r.deep, 0)} (d${r.bottom})` },
				{ key: 'commission', label: 'Commission pays', align: 'right', title: 'Range of what a commission with no requirement pays, over the skills this mine holds' },
				{ key: 'geode', label: 'Geode', align: 'right', title: 'Phase 4: the expected worth of a Geode and its price', render: () => 'phase 4' },
				{ key: 'contract', label: 'Contract', align: 'right', title: 'Phase 5: the expected worth of a contract output', render: () => 'phase 5' },
			],
			rows, compact: true,
		}), { meta: `stone worth sampled from ${SAMPLES} stones per cell; the home scales pay full worth` }));
		root.append(note('The fare buys a purse at 2 pyrite to the gold and the assayer buys back at 5, and only pyrite earned down there, so going down and straight back up never pays. A commission always pays more than selling the stone handed in. tests/test_economy.gd checks both against the pack.', 'plain'));
	},
};
