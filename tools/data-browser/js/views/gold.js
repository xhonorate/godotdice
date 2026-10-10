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

// A mine's Geode (DeepEconomy.roll_geode_stone): a skill from the rock (or, one time in a
// hundred, an opal), cut and cleared at the bottom of the mine with the Geode's luck on top,
// never fragile, and as heavy as the band allows: the mine's usual top at the least, each carat
// past it half as likely as the one before, up to a little past the mine's cap.
function geodeBand(mine) {
	const band = Forge.caratBand(mine, 1) || { soft: 5, cap: 7 };
	const low = band.soft;
	const high = Math.min(band.cap + Number(C.constant('geode_carat_over_cap', 2)), Stone.caratMax());
	return { low, high: Math.max(low, high), cap: band.cap };
}
const fragile = (stone) => Stone.hasModifier(Stone.modifiers(stone), 'fragile');
const sound = (inclusions) => inclusions.filter((k) => !(C.inclusion(k).modifiers || []).some((m) => m && m.kind === 'fragile'));
function rollGeodeStone(rng, mine) {
	const opals = C.keys('skills').filter((k) => C.skill(k).color === C.OPAL && C.skill(k).rarity !== 'TRANSCENDENT');
	const opal = opals.length > 0 && rng.chance(Number(C.constant('geode_opal_pct', 1)));
	const pool = opal ? opals : Forge.skillPool(mine).filter((k) => C.skill(k).color !== C.OPAL && C.skill(k).rarity !== 'TRANSCENDENT');
	let stone = null;
	for (let i = 0; i < 12; i++) {
		stone = Forge.rollStone(rng, mine, 20, Number(C.constant('geode_luck', 4)), pool);
		if (!fragile(stone)) break;
	}
	stone.inclusions = sound(stone.inclusions || []);
	const band = geodeBand(mine);
	const keep = Number(C.constant('geode_carat_keep', 50));
	stone.carat = band.low;
	while (stone.carat < band.high && rng.chance(keep)) stone.carat++;
	return stone;
}
// What a mine's Geode's stone is worth on average, and the price the shelf asks for it: so
// much over that worth, never under the mine's own floor, rounded up to ten.
function geodeWorth(mine, seed) {
	const rng = makeRng(seed);
	let total = 0;
	for (let i = 0; i < SAMPLES; i++) total += Stone.value(rollGeodeStone(rng, mine));
	const worth = total / SAMPLES;
	const price = Math.max(mine.geode_gold | 0, Math.ceil((worth * Number(C.constant('geode_price_mult', 1.75))) / 10) * 10);
	return { worth, price };
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
		root.append(h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(4, minmax(0,1fr))' } },
			stat('Geode price', `×${C.constant('geode_price_mult', 1.75)}`, 'of what its stone sells for on average, never under the mine\'s floor', { class: 'accent' }),
			stat('Geode stones', `luck +${C.constant('geode_luck', 4)}`, `rolled at depth 20; ${C.constant('geode_opal_pct', 1)}% are opals; up to ${C.constant('geode_carat_over_cap', 2)} carats past the cap`),
			stat('Contract', `${C.constant('contract_inputs', 5)} → 1`, 'stones of one grade in, one of the next grade out'),
			stat('Daily dig', `score × ${C.constant('daily_score_rate', 0.5)}`, `gold for the worth of the stones and pyrite brought up, half the rate past ${C.constant('daily_score_knee', 1000)}; a later dig pays only what it adds`)));

		const rows = minesInOrder().map((key, i) => {
			const mine = C.mine(key);
			const bottom = mine.endless ? 24 : (mine.depth | 0);
			const [low, high] = commissionRange(mine);
			const purse = mine.start_pyrite | 0;
			const geode = geodeWorth(mine, 303 + i);
			return {
				key, name: mine.name || key, fare: mine.fare_gold | 0, insurance: mine.insurance_gold | 0, purse,
				cashed: Math.floor(purse / rate), conquest: mine.first_conquest_gold | 0,
				top: meanWorth(mine, 1, 101 + i), deep: meanWorth(mine, bottom, 202 + i), bottom, commission: `${low}–${high}`,
				geode: geode.price, geodeWorth: geode.worth, floor: mine.geode_gold | 0,
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
				{ key: 'geodeWorth', label: 'Geode stone', align: 'right', title: 'Mean sale value of the stone in this mine\'s Geode', render: (r) => fmt(r.geodeWorth, 0) },
				{ key: 'geode', label: 'Geode price', align: 'right', title: 'What the shelf asks: the stone\'s mean worth times the price multiplier, rounded up to ten, never under the floor (sampled here, so within ten of the game\'s own figure)', render: (r) => `${fmt(r.geode, 0)}${r.geode <= r.floor ? ' (floor)' : ''}` },
			],
			rows, compact: true,
		}), { meta: `stone worth sampled from ${SAMPLES} stones per cell; the home scales pay full worth` }));
		root.append(note('The fare buys a purse at 2 pyrite to the gold and the assayer buys back at 5, and only pyrite earned down there, so going down and straight back up never pays. A commission always pays more than selling the stone handed in. tests/test_economy.gd checks both against the pack.', 'plain'));
		const fees = C.constant('contract_fee', {});
		const ladder = ['ROUGH', 'FINE', 'PRECIOUS', 'EXQUISITE'].map((tier, i, all) => ({
			key: tier, step: `${Stone.TIER_NAMES[tier]} → ${Stone.TIER_NAMES[all[i + 1] || 'PEERLESS']}`, fee: Number(fees[tier] || 0),
		}));
		root.append(card('Contracts', table({
			columns: [
				{ key: 'step', label: 'Five of', title: 'The grade going in and the one coming out' },
				{ key: 'fee', label: 'Fee', align: 'right', title: 'Gold to sign it', render: (r) => fmt(r.fee, 0) },
			],
			rows: ladder, compact: true,
		}), { meta: 'its color drawn from the five, its carat their average, its skill from the deepest of their mines' }));
		root.append(note('A Geode always costs more than its stone sells for, and five stones are always worth more than the one a contract makes of them, fee included, so neither can be chained into gold. tests/test_economy.gd checks both.', 'plain'));
	},
};
