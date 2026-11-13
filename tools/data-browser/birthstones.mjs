// Every Birthstone side by side: what each delver's three stones (their first and the two bought
// with gold) do in the fights the balance sweeps play, on that delver's own bowl with their
// passive.
//
//   node tools/data-browser/birthstones.mjs [--samples 1000] [--turns 4] [--seed 1] [--carat 8] [--json <file>]
//
// Each stone is played four ways, on the same seeded fights as the others (so what one does
// better than another is the stone and not the dice):
//
//   alone             the empty rail, no reroll spent: the gems sweep's rail '0', "Birthstone and
//                     passive alone" (Florin in his first stone throws for crowns, as he does there).
//                     With no gem to ring it the rail's Resonance is nought, so a stone that only
//                     multiplies Resonance does nothing here;
//   alone, chasing    the empty rail with the rerolls spent chasing the stone's own pattern;
//   the plain rail    the bowl's best gems alone (balance.js plainRail, read off the gems sweep),
//                     the rerolls chasing its strongest gem, as the hunt plays it;
//   the plain rail,   the same gems with the rerolls chasing the stone's own pattern instead: what
//   chasing the stone a player who built round the stone would throw for.
//
// A delver with a stone that counts the colors fired (Puck's Patchwork) is also played on two
// rails of six colors: the bowl's best gem of each, and its best gem of each that fires on every
// hand. The plain rail seldom holds three colors.
//
// The fights are the gems sweep's: two dummies with a creature's health, and the boss that never
// falls. A turn's numbers are the fight's over its turns. `adds` is the power (damage + 0.7 x
// health saved, the sweeps' default weights) the stone adds over the same rail with no
// Birthstone at all, and `x first` that against what the delver's first stone adds. The tiers are
// how many times each fires a turn (a replay is a firing). A Renown and a Bloodroot grow over a
// run, so each is also played as it stands some way down: with Trophies taken, with max health
// grown.
//
// It reads the gems sweep for the plain rails, and runs it first when it is missing or was
// played on another pack (as balance.mjs does).

import { spawnSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as C from './js/sim/content.js';
import * as Stone from './js/sim/stone.js';
import * as Balance from './js/sim/balance.js';
import { playFight, TROPHIES } from './js/sim/fight.js';
import { policyFor } from './js/sim/simulate.js';
import * as Store from './balance-store.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const option = (name) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined; };
const number = (name, fallback) => (option(name) === undefined ? fallback : Number(option(name)));

const pack = JSON.parse(await readFile(path.resolve(here, '../../content/deep_cut.json'), 'utf8'));
C.setPack(pack);
const hash = Balance.packHash(pack);
const s = Balance.sweepSettings({ ...Balance.DEFAULTS, turns: number('turns', Balance.DEFAULTS.turns), seed: number('seed', Balance.DEFAULTS.seed), carat: number('carat', Balance.DEFAULTS.carat),
	samples: number('samples', Balance.DEFAULTS.samples.gems) }, 'gems');
const F = Balance.fightsFor(s, null);
const W = Balance.DEFAULT_WEIGHTS;

// What the rerolls chase when a stone is all there is: its first tier's pattern, unless that is
// not the one worth chasing (a Tap is a price; Highs and Lows wants crowns and 1s alike; a
// Blackjack stands on anything from 17 to 21).
const CHASE = { BLOODROOT: 'sets', HIGHS_AND_LOWS: 'faces', BLACKJACK: 'total:17:21' };
const chaseOf = (character, key) => CHASE[key] || policyFor(((C.birthstoneDef(character, key).tiers || [])[0] || {}).trigger || {});
// A stone as it stands some way down a run: what it has grown (playFight's `carry`).
const GROWN = {
	RENOWN: [{ label: '10 Trophies', carry: () => ({ runCounts: { [TROPHIES]: 10 } }) }, { label: '25 Trophies', carry: () => ({ runCounts: { [TROPHIES]: 25 } }) }],
	BLOODROOT: [{ label: '+50 max health', carry: (character) => ({ maxHp: Number(C.character(character).hp) + 50 }) }],
};

let gems = await Store.load('gems');
if (!gems || gems.packHash !== hash || (gems.settings || {}).worn) {
	console.log(gems ? 'the gems sweep was played on another pack: running it again' : 'no gems sweep yet: running it');
	const ran = spawnSync(process.execPath, [path.join(here, 'balance.mjs'), 'gems'], { stdio: 'inherit' });
	if (ran.status !== 0) { console.error('the gems sweep did not run'); process.exit(1); }
	gems = await Store.load('gems');
}
const leadsAll = Balance.leadsFrom(gems);

// One rail in one Birthstone, `samples` fights of each kind: the means a turn. `bare` plays the
// same delver with the stone taken off (still theirs to chase: Florin throws the bowl again for
// the stone he would be wearing), which is what the stone's own work is measured over.
function play(character, rail, policy, worn, { bare = false, carry = null } = {}) {
	const spec = { character, rail: rail.map((k, i) => Stone.make(k, s.carat, s.cut, Balance.clarityOf(s.clarity), [], `g${i}`)), policy, turns: s.turns, pyrite: s.pyrite, depth: s.depth,
		birthstone: !bare, passive: s.passive, worn: worn || '', seed: s.seed, stopOnRunaway: true };
	const sum = { dealt: 0, saved: 0, block: 0, healed: 0, lost: 0, gold: 0, fired: 0, boss: 0, bossSaved: 0, runaway: 0, tiers: [] };
	for (let i = 0; i < s.samples; i++) {
		const m = playFight({ ...spec, dummies: F.mob }, i, carry ? carry(character) : null);
		sum.dealt += m.dealt; sum.saved += m.incoming - m.hpLost + m.healed; sum.block += m.blockGained; sum.healed += m.healed; sum.lost += m.hpLost; sum.gold += m.gold; sum.fired += m.birthstone;
		m.tiers.forEach((n, tier) => { sum.tiers[tier] = (sum.tiers[tier] || 0) + n; });
		const b = playFight({ ...spec, dummies: F.boss, wall: F.wall }, i, carry ? carry(character) : null);
		sum.boss += b.dealt; sum.bossSaved += b.incoming - b.hpLost + b.healed;
		if (m.runaway || b.runaway) sum.runaway += 1;
	}
	const per = s.samples * s.turns;
	const out = { dealt: sum.dealt / per, saved: sum.saved / per, block: sum.block / per, healed: sum.healed / per, lost: sum.lost / per, gold: sum.gold / per, fired: sum.fired / per,
		boss: sum.boss / per, bossSaved: sum.bossSaved / per, runaway: sum.runaway / s.samples, tiers: Array.from(sum.tiers, (n) => (n || 0) / per) };
	out.power = W.damage * out.dealt + W.saved * out.saved;
	out.bossPower = W.damage * out.boss + W.saved * out.bossSaved;
	return out;
}

const fmt = (v, d = 1) => (Number.isFinite(v) ? v.toLocaleString('en-GB', { minimumFractionDigits: d, maximumFractionDigits: d }) : '—');
// One stone's work against the first stone's; no figure when the first stone adds next to
// nothing there (under half a point a turn), since a ratio to that says nothing.
const times = (mine, first) => (Number.isFinite(mine) && Number.isFinite(first) && first >= 0.5 ? `${fmt(mine / first, 2)}x` : '—');
const started = Date.now();
const report = [];
console.log(`Birthstones · ${s.samples} fights of ${s.turns} turns each way · ${s.dummies} dummies (${s.dummyDice.join('+').toLowerCase()}, ${s.dummyHp} health, ${s.guard} block an action) and the boss (${s.bossDice.join('+').toLowerCase()}, never falls)`);
console.log(`plain rails: ${s.carat}-carat ${C.cutEntry(s.cut).name} ${C.clarityEntry(Balance.clarityOf(s.clarity)).name} stones · seed ${s.seed} · pack ${hash}`);
console.log('a turn: dealt (two dummies; overkill is wasted, about 120 a turn is all there is), block gained, healed, health lost, pyrite won, boss (dealt to the boss, never capped)');
console.log('adds / boss adds = power (dealt + 0.7 x health saved) over the same rail, chasing the same pattern, with the stone taken off; x first = that against the first stone\'s\n');
for (const character of Balance.lapidaries()) {
	const def = C.character(character);
	const plain = Balance.plainRail(character, leadsAll[character] || {}, Balance.railLength(character));
	// A stone that reads nothing off the dice (a Patchwork counts colors) leaves the rerolls to the rail's strongest gem.
	const chasing = (gems) => (key) => { const policy = chaseOf(character, key); return policy === 'none' ? Balance.policyOf(gems[0]) : policy; };
	const rails = [
		{ label: 'alone', rail: [], policy: () => 'none' },
		{ label: 'alone, chasing', rail: [], policy: (key) => chaseOf(character, key) },
		{ label: 'the plain rail', rail: plain, policy: () => Balance.policyOf(plain[0]) },
		{ label: 'the plain rail, chasing the stone', rail: plain, policy: chasing(plain) },
	];
	console.log(`${def.name} (${def.title || character}) · ${def.hp} health · ${(def.dice || []).map((d) => (typeof d === 'string' ? d : `${d.pattern || ''} ${d.shape}`.trim())).join(' ').toLowerCase()} · ${def.passive?.name || 'no passive'}`);
	console.log(`  the plain rail: ${plain.map((k) => C.skill(k).name || k).join(', ')} (chasing ${Balance.policyOf(plain[0])})`);
	// A delver with a stone that counts the colors fired is played on two rails of all six as
	// well, strongest gem first: the bowl's best gem of each color, and its best gem of each color
	// that fires on every hand (what a player after Whole Cloth would set). The plain rail seldom
	// holds three colors.
	if (C.birthstoneKeys(character).some((key) => (C.birthstoneDef(character, key).tiers || []).some((tier) => (tier.trigger || {}).kind === 'colors'))) {
		const leads = leadsAll[character] || {};
		const byLead = (a, b) => (leads[b] ?? -Infinity) - (leads[a] ?? -Infinity);
		const best = (color, sure) => Balance.huntPool().filter((k) => C.skill(k).color === color && C.skill(k).rarity !== 'TRANSCENDENT' && (!sure || ((C.skill(k).trigger || {}).kind || 'always') === 'always')).sort(byLead)[0];
		const colored = C.COLOR_KEYS.map((color) => best(color, false)).filter(Boolean).sort(byLead);
		const sure = C.COLOR_KEYS.map((color) => best(color, true) || best(color, false)).filter(Boolean).sort(byLead);
		rails.push({ label: 'a rail of six colors', rail: colored, policy: () => Balance.policyOf(colored[0]) }, { label: 'a rail of six colors that fire on any hand', rail: sure, policy: chasing(sure) });
		const named = (gems) => gems.map((k) => `${C.skill(k).name || k} (${C.colorName(C.skill(k).color).toLowerCase()})`).join(', ');
		console.log(`  a rail of six colors: ${named(colored)} (chasing ${Balance.policyOf(colored[0])})`);
		console.log(`  a rail of six colors that fire on any hand: ${named(sure)} (the rerolls chasing each stone's own pattern; a Patchwork has none, so ${Balance.policyOf(sure[0])})`);
	}
	// Only Florin's rerolls ask which stone he wears; for the rest one bare rail a policy serves every stone.
	const chooses = def.passive?.kind === 'all_or_nothing';
	for (const way of rails) {
		const bares = new Map();
		const bare = (key, policy, grown = null) => {
			const id = `${policy}|${chooses ? key : ''}|${grown ? grown.label : ''}`;
			if (!bares.has(id)) bares.set(id, play(character, way.rail, policy, key, { bare: true, carry: grown ? grown.carry : null }));
			return bares.get(id);
		};
		const rows = [];
		// With no Birthstone at all the rerolls chase what the first stone's rail would.
		rows.push({ name: '(no Birthstone)', key: null, policy: way.policy(''), r: bare('', way.policy('')) });
		for (const key of C.birthstoneKeys(character)) {
			const stone = C.birthstoneDef(character, key);
			const policy = way.policy(key);
			rows.push({ name: `${stone.name}${key ? ` (${fmt(Number(stone.price || 0), 0)} gold)` : ' (first)'}`, key, policy, stone, r: play(character, way.rail, policy, key), base: bare(key, policy) });
			for (const grown of GROWN[key] || []) rows.push({ name: `  ${stone.name}, ${grown.label}`, key, policy, stone, r: play(character, way.rail, policy, key, { carry: grown.carry }), base: bare(key, policy, grown) });
		}
		const first = rows[1];
		const adds = (row) => (row.base ? row.r.power - row.base.power : NaN);
		const bossAdds = (row) => (row.base ? row.r.bossPower - row.base.bossPower : NaN);
		console.log(`\n  ${way.label}`);
		console.log(`  ${'stone'.padEnd(34)}${'chases'.padEnd(13)}${'dealt'.padStart(8)}${'block'.padStart(8)}${'healed'.padStart(8)}${'lost'.padStart(8)}${'pyrite'.padStart(8)}${'boss'.padStart(9)}${'adds'.padStart(9)}${'x first'.padStart(9)}${'boss adds'.padStart(11)}${'x first'.padStart(9)}  tiers fired a turn`);
		for (const row of rows) {
			const tiers = row.stone ? (row.stone.tiers || []).map((tier, at) => `${tier.name} ${fmt(row.r.tiers[at] || 0, 2)}`).join(' · ') : '';
			console.log(`  ${row.name.padEnd(34)}${String(row.policy).padEnd(13)}${fmt(row.r.dealt).padStart(8)}${fmt(row.r.block).padStart(8)}${fmt(row.r.healed).padStart(8)}${fmt(row.r.lost).padStart(8)}${fmt(row.r.gold).padStart(8)}${fmt(row.r.boss).padStart(9)}`
				+ `${(row.key === null ? '' : fmt(adds(row))).padStart(9)}${(row.key === null ? '' : times(adds(row), adds(first))).padStart(9)}${(row.key === null ? '' : fmt(bossAdds(row))).padStart(11)}${(row.key === null ? '' : times(bossAdds(row), bossAdds(first))).padStart(9)}  ${tiers}${row.r.runaway > 0 ? `  · RUNS AWAY in ${fmt(row.r.runaway * 100, 0)}% of fights` : ''}`);
			report.push({ character, way: way.label, stone: row.key === null ? null : row.stone.name, key: row.key, label: row.name.trim(), policy: row.policy, ...row.r, adds: row.key === null ? null : adds(row), bossAdds: row.key === null ? null : bossAdds(row),
				firstAdds: row.key === null ? null : adds(first), firstBossAdds: row.key === null ? null : bossAdds(first) });
		}
	}
	console.log('');
}
console.log(`${((Date.now() - started) / 1000).toFixed(0)}s`);
if (option('json')) await writeFile(path.resolve(option('json')), JSON.stringify({ settings: s, packHash: hash, rows: report }, null, '\t'));
