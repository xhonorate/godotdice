// What the balance runs say (tools/balance/delve.mjs plays them, tools/balance/bot.gd is the
// player). Pure functions over the runs and the content pack: `analyze` makes the summary a
// report is written from, `render` the report as text, `diff` what moved between two summaries.
//
// How each thing is read (docs/BALANCE.md has the long version):
//
//   a mine        how many runs beat its boss, and how far the rest got (progress: the share
//                 of its floors left behind), where they fell and to what.
//   a delver      all three of their stones against the middle stone in the same mines.
//   a Birthstone  its runs against the middle stone in the same mines (edge: progress over
//                 the median of the mine's stones), and against its delver's other two stones on the same
//                 seeds (the same shaft, the same vault to choose from): a paired difference.
//   a gem         planted: every run sets one stone of its vault on the rail whatever the bot
//                 thinks of it, so a gem's runs are set against the others of the same delver,
//                 stone and mine, and the difference is the gem's. Beside that, what it did
//                 while it sat on a rail (fires, damage, block, healing a turn), how often the
//                 bot chose it from the vault, and how often it took it when the mine offered it.
//   a creature    what it took off the bot each fight as a share of the bot's health, how long
//                 it stood, how many runs it ended; each set against the others of its mine.
//   a Warden      how many of the runs that reached it it ended, and what the rest paid.
//
// `flags` is the short list: whatever stands further from its peers than chance would put it
// (two standard errors and a difference worth acting on), each with the numbers that say so.

const WEIGHTS = { damage: 1, block: 0.7, healed: 0.8, debuffs: 1.5, ore: 0.05 };
// What it takes to be flagged. A delver, stone or gem: two standard errors, and this much
// progress. `band`: a gem that only stands out with light kits or with heavy ones needs more.
// `heavy`: the carats a kit is called heavy from. A Warden is a wall when this few of the runs
// that reach it beat it (`wall`), or when it ends this share of all its mine's runs (`ends`).
// A creature is dangerous at `hurtHigh` times its mine's middle creature, or when the runs it
// ended come to this share of the runs played in its mine (`kills`).
const LIMITS = { delver: 0.06, stone: 0.06, gem: 0.06, band: 0.08, gemKits: 8, heavy: 16, outsized: 4, producer: 1, hurtHigh: 2, hurtLow: 0.35, kills: 0.1, met: 30, wall: 0.55, ends: 0.2, walk: 0.97, wardenMet: 12, idle: 0.15, shunned: 0.08, vault: 20 };
const round = (v, d = 3) => (Number.isFinite(v) ? Math.round(v * 10 ** d) / 10 ** d : null);
const mean = (xs) => (xs.length ? xs.reduce((s, x) => s + x, 0) / xs.length : NaN);
function spread(xs) {
	const n = xs.length;
	if (n < 2) return { n, mean: mean(xs), sd: NaN, se: NaN };
	const m = mean(xs);
	const sd = Math.sqrt(xs.reduce((s, x) => s + (x - m) ** 2, 0) / (n - 1));
	return { n, mean: m, sd, se: sd / Math.sqrt(n) };
}
const median = (xs) => { const s = xs.filter(Number.isFinite).sort((a, b) => a - b); return s.length ? (s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2) : NaN; };
const caratMult = (carat) => (carat < 20 ? 1 + (carat - 1) * 0.25 : carat - 14);
const bump = (book, key, by = 1) => { book[key] = (book[key] || 0) + by; };
// A number that may have run away, in words (a flag's line) and in a column's width.
export const inWords = (v) => (Math.abs(v) >= 1e12 ? `${(v / 1e12).toFixed(1)} trillion` : Math.abs(v) >= 1e9 ? `${(v / 1e9).toFixed(1)} billion` : Math.abs(v) >= 1e6 ? `${(v / 1e6).toFixed(1)} million` : Math.round(v).toLocaleString('en-GB'));
export const short = (v, d = 1) => (v === null || v === undefined || !Number.isFinite(v) ? '—' : Math.abs(v) >= 1e12 ? `${(v / 1e12).toFixed(1)}T` : Math.abs(v) >= 1e9 ? `${(v / 1e9).toFixed(1)}B` : Math.abs(v) >= 1e6 ? `${(v / 1e6).toFixed(1)}M` : Math.abs(v) >= 1e4 ? `${(v / 1e3).toFixed(0)}k` : v.toFixed(d));
export const times = (v) => (v === null || v === undefined || !Number.isFinite(v) ? '—' : v >= 1000 ? 'over 1,000×' : `${v.toFixed(1)}×`);
// The mean of each group of a list of [group, value], one figure a group: runs that share a
// seed, a delver and a mine share their vault and their shaft, and are not three readings.
function grouped(pairs) {
	const book = new Map();
	for (const [key, value] of pairs) { if (!book.has(key)) book.set(key, []); book.get(key).push(value); }
	return [...book.values()].map(mean);
}

export function analyze(rows, pack, opts = {}) {
	const mineOrder = Object.keys(pack.mines).sort((a, b) => Number(pack.mines[a].tier ?? 0) - Number(pack.mines[b].tier ?? 0));
	const delverOrder = Object.keys(pack.characters).sort((a, b) => Number(pack.characters[a].unlock_order ?? 0) - Number(pack.characters[b].unlock_order ?? 0));
	const stoneName = (c, w) => (w ? ((pack.characters[c].variants || []).find((v) => v.key === w) || {}).name : (pack.characters[c].birthstone || {}).name) || w || c;
	const creatureName = (key) => (pack.creatures[key] || {}).name || key;
	const won = (r) => (r.outcome === 'conquered' ? 1 : 0);
	// The gems' own pass (delve.mjs GEM_TAG): first stones on seeds of their own, every run a
	// different kit. Those runs are read for the gems and for nothing else.
	const every = rows.filter((r) => r.outcome === 'conquered' || r.outcome === 'fallen');
	const ok = every.filter((r) => !String(r.id).startsWith('g.'));
	const broken = rows.length - every.length;
	const shaft = (r) => `${r.c}|${r.mine}|${r.seed}`;

	// --- strata: every run against the runs of its own delver, stone and mine ---------------------
	const cell = (r) => `${r.c}|${r.w}|${r.mine}`;
	const strata = (list) => {
		const book = new Map();
		for (const r of list) { const k = cell(r); if (!book.has(k)) book.set(k, []); book.get(k).push(r); }
		return new Map([...book].map(([k, of]) => [k, { progress: mean(of.map((r) => r.progress)), clear: mean(of.map(won)), n: of.length }]));
	};
	const cells = strata(ok);
	const cellMean = strata(every);
	const mineMean = {};
	for (const mine of mineOrder) {
		const list = ok.filter((r) => r.mine === mine);
		if (list.length) mineMean[mine] = { progress: mean(list.map((r) => r.progress)), clear: mean(list.map(won)), n: list.length };
	}
	// The middle stone of each mine: the mark every stone and delver is read against. A mean
	// would move with whoever stands furthest from it (one weak delver lifts all the others).
	const mineMid = {};
	for (const mine of mineOrder) {
		const of = [...cells].filter(([k]) => k.endsWith(`|${mine}`)).map(([, v]) => v.progress);
		if (of.length) mineMid[mine] = median(of);
	}

	// --- mines -------------------------------------------------------------------------------------
	const mines = [];
	for (const mine of mineOrder) {
		const list = ok.filter((r) => r.mine === mine);
		if (!list.length) continue;
		const deaths = {};
		const killers = {};
		for (const r of list) {
			if (!r.cause) continue;
			bump(deaths, r.cause.k);
			const lead = r.cause.k === 'warden' || r.cause.k === 'boss' ? r.cause.foes.find((f) => (pack.creatures[f] || {}).warden) || r.cause.foes[0] : r.cause.killer || `(${r.cause.k})`;
			bump(killers, lead);
		}
		const fights = list.flatMap((r) => r.fights);
		const kinds = {};
		for (const kind of ['fight', 'elite', 'warden', 'boss']) {
			const of = fights.filter((f) => f.k === kind);
			if (!of.length) continue;
			kinds[kind] = { n: of.length, won: round(mean(of.map((f) => (f.won ? 1 : 0)))), turns: round(mean(of.map((f) => f.turns)), 2), hurt: round(mean(of.map((f) => f.taken / Math.max(1, f.max)))) };
		}
		const kit = (opts.meta && opts.meta.kits && opts.meta.kits[mine]) || null;
		mines.push({ key: mine, name: pack.mines[mine].name || mine, goal: list[0].goal, runs: list.length, clear: round(mean(list.map(won))), progress: round(mean(list.map((r) => r.progress))),
			fights: round(mean(list.map((r) => r.fights.length)), 1), stones: round(mean(list.map((r) => r.kit.length)), 1),
			kit: kit || (list[0].kit.length ? { name: '', carat: list[0].kit[0][1], cut: list[0].kit[0][2], clarity: list[0].kit[0][3] } : null),
			deaths, killers: Object.entries(killers).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([key, n]) => ({ key, name: creatureName(key), n })), kinds, ms: round(mean(list.map((r) => r.ms)), 0) });
	}

	// --- Birthstones -------------------------------------------------------------------------------
	const byShaft = new Map();
	for (const r of ok) { const k = shaft(r); if (!byShaft.has(k)) byShaft.set(k, []); byShaft.get(k).push(r); }
	const stones = [];
	for (const c of delverOrder) {
		const keys = ['', ...(pack.characters[c].variants || []).map((v) => String(v.key))];
		for (const w of keys) {
			const list = ok.filter((r) => r.c === c && r.w === w);
			if (!list.length) continue;
			const byMine = {};
			const edges = [];
			for (const mine of mineOrder) {
				const of = list.filter((r) => r.mine === mine);
				if (!of.length) continue;
				byMine[mine] = { runs: of.length, clear: round(mean(of.map(won))), progress: round(mean(of.map((r) => r.progress))), edge: round(mean(of.map((r) => r.progress)) - mineMid[mine]) };
				for (const r of of) edges.push(r.progress - mineMid[mine]);
			}
			// Against the delver's other stones, and against their first, seed for seed.
			const gaps = [];
			const wins = [];
			const firstGaps = [];
			for (const r of list) {
				const others = (byShaft.get(shaft(r)) || []).filter((o) => o.w !== w);
				if (others.length) { gaps.push(r.progress - mean(others.map((o) => o.progress))); wins.push(won(r) - mean(others.map(won))); }
				const first = w ? others.find((o) => o.w === '') : null;
				if (first) firstGaps.push(r.progress - first.progress);
			}
			const within = gaps.length ? ((s) => ({ n: s.n, progress: round(s.mean), se: round(s.se), clear: round(mean(wins)) }))(spread(gaps)) : null;
			const paired = firstGaps.length ? ((s) => ({ n: s.n, progress: round(s.mean), se: round(s.se) }))(spread(firstGaps)) : null;
			const turns = list.reduce((s, r) => s + (r.birth.turns || 0), 0);
			const tiers = {};
			for (const r of list) for (const [tier, n] of Object.entries(r.birth.tiers || {})) bump(tiers, tier, n);
			const damage = list.reduce((s, r) => s + r.stats.damage, 0);
			const e = spread(edges);
			const def = w ? (pack.characters[c].variants || []).find((v) => v.key === w) || {} : pack.characters[c].birthstone || {};
			stones.push({ delver: c, key: w, name: stoneName(c, w), price: Number(def.price || 0),
				runs: list.length, clear: round(mean(list.map(won))), progress: round(mean(list.map((r) => r.progress))), edge: round(e.mean), edgeSe: round(e.se), byMine, within, paired,
				fires: round(list.reduce((s, r) => s + (r.birth.fires || 0), 0) / Math.max(1, turns)),
				tiers: (def.tiers || []).map((t) => ({ name: t.name, rate: round((tiers[t.name] || 0) / Math.max(1, turns)) })),
				share: round(list.reduce((s, r) => s + (r.birth.damage || 0), 0) / Math.max(1, damage)), damage: round(list.reduce((s, r) => s + (r.birth.damage || 0), 0) / Math.max(1, turns), 1),
				block: round(list.reduce((s, r) => s + (r.birth.block || 0), 0) / Math.max(1, turns), 1), healed: round(list.reduce((s, r) => s + (r.birth.healed || 0), 0) / Math.max(1, turns), 1),
				// What the stone took off its own delver (a tier that costs: Florin's Bust), as a share of a health bar a fight.
				cost: round(list.reduce((s, r) => s + (r.birth.hurt || 0), 0) / Math.max(1, list.reduce((s, r) => s + r.fights.length * Math.max(1, r.max_hp), 0))) });
		}
	}
	// A delver, across all three stones: one figure a shaft, since the three share it.
	const delvers = delverOrder.filter((c) => stones.some((s) => s.delver === c)).map((c) => {
		const list = ok.filter((r) => r.c === c);
		const e = spread(grouped(list.map((r) => [shaft(r), r.progress - mineMid[r.mine]])));
		const byMine = {};
		for (const mine of mineOrder) { const of = list.filter((r) => r.mine === mine); if (of.length) byMine[mine] = { runs: of.length, clear: round(mean(of.map(won))), progress: round(mean(of.map((r) => r.progress))) }; }
		return { key: c, name: pack.characters[c].name || c, runs: list.length, clear: round(mean(list.map(won))), progress: round(mean(list.map((r) => r.progress))), edge: round(e.mean), edgeSe: round(e.se), byMine };
	});

	// --- gems --------------------------------------------------------------------------------------
	const gem = {};
	const entry = (key) => gem[key] || (gem[key] = { key, name: (pack.skills[key] || {}).name || key, color: (pack.skills[key] || {}).color || '', rarity: (pack.skills[key] || {}).rarity || '',
		plant: [], vault: 0, picked: 0, runs: 0, turns: 0, fights: 0, fires: 0, damage: 0, block: 0, healed: 0, debuffs: 0, ore: 0, cost: 0, power: 0, powerFlat: 0, offered: 0, taken: 0 });
	for (const r of every) {
		const base = cellMean.get(cell(r));
		// Against the others of its cell, itself left out: the cell's mean with this run taken away.
		const others = base.n > 1 ? (base.progress * base.n - r.progress) / (base.n - 1) : base.progress;
		const othersWon = base.n > 1 ? (base.clear * base.n - won(r)) / (base.n - 1) : base.clear;
		const kit = r.kit.map((k) => k[0]);
		const heavy = Number((r.kit[0] || [])[1] || 0) >= LIMITS.heavy;
		for (const skill of [...kit, ...(r.spare || [])]) entry(skill).vault += 1;
		for (const skill of kit) {
			if (skill === r.plant) entry(skill).plant.push({ shaft: shaft(r), gap: r.progress - others, win: won(r) - othersWon, heavy });
			else entry(skill).picked += 1;
		}
		for (const [skill, did] of Object.entries(r.gems || {})) {
			const g = entry(skill);
			g.runs += 1;
			g.turns += did.turns; g.fights += did.fights; g.fires += did.fires;
			for (const key of ['damage', 'block', 'healed', 'debuffs', 'ore']) g[key] += did[key];
			g.cost += did.cost || 0;
			const power = did.damage * WEIGHTS.damage + did.block * WEIGHTS.block + did.healed * WEIGHTS.healed + did.debuffs * WEIGHTS.debuffs + did.ore * WEIGHTS.ore;
			g.power += power;
			// At one carat: what it did, taken down by the weight it did it at.
			g.powerFlat += power / caratMult(Math.max(1, did.carat || 1));
		}
		for (const [skill, n] of Object.entries(r.offered || {})) entry(skill).offered += n;
		for (const [skill, n] of Object.entries(r.taken || {})) entry(skill).taken += n;
	}
	// One reading a kit: a delver's three stones are planted the same stone on the same seed.
	const planted = (list) => {
		const s = spread(grouped(list.map((p) => [p.shaft, p.gap])));
		return { n: list.length, kits: s.n, progress: round(s.mean), se: round(s.se), clear: round(mean(list.map((p) => p.win))) };
	};
	const gems = Object.values(gem).map((g) => {
		const unplanted = g.vault - g.plant.length;
		return { key: g.key, name: g.name, color: g.color, rarity: g.rarity,
			plant: { ...planted(g.plant), light: planted(g.plant.filter((p) => !p.heavy)), heavy: planted(g.plant.filter((p) => p.heavy)) },
			pick: { vault: g.vault, rate: unplanted > 0 ? round(g.picked / unplanted) : null },
			rail: { runs: g.runs, turns: g.turns, fires: round(g.fires / Math.max(1, g.turns)), damage: round(g.damage / Math.max(1, g.turns), 2), block: round(g.block / Math.max(1, g.turns), 2),
				healed: round(g.healed / Math.max(1, g.turns), 2), debuffs: round(g.debuffs / Math.max(1, g.turns), 2), ore: round(g.ore / Math.max(1, g.turns), 2),
				// Health it took off its own owner (a price it asks), a turn.
				cost: round(g.cost / Math.max(1, g.turns), 2),
				power: round(g.power / Math.max(1, g.turns), 2), flat: round(g.powerFlat / Math.max(1, g.turns), 2) },
			loot: { offered: g.offered, taken: g.taken, rate: g.offered ? round(g.taken / g.offered) : null } };
	});
	// What each gem does a turn against the middle gem of its own rarity that does anything a
	// tally shows (a gem that works through another, a reroll or a raised face, shows nothing).
	const byRarity = {};
	for (const g of gems) (byRarity[g.rarity] || (byRarity[g.rarity] = [])).push(g);
	for (const g of gems) {
		const peers = byRarity[g.rarity].filter((p) => p.rail.turns >= 200 && p.rail.flat >= LIMITS.producer).map((p) => p.rail.flat);
		g.rail.peers = peers.length >= 3 ? round(median(peers), 2) : null;
		g.rail.ratio = g.rail.peers > 0 && g.rail.turns >= 100 ? round(g.rail.flat / g.rail.peers, 2) : null;
		const z = (p) => (p.kits >= 2 && p.se > 0 ? round(p.progress / p.se, 2) : null);
		g.z = z(g.plant);
		g.plant.light.z = z(g.plant.light);
		g.plant.heavy.z = z(g.plant.heavy);
	}

	// --- creatures and Wardens ---------------------------------------------------------------------
	const beast = {};
	const beastOf = (key) => beast[key] || (beast[key] = { key, name: creatureName(key), warden: Boolean((pack.creatures[key] || {}).warden), mines: {}, fights: 0, stood: 0, acts: 0, hurt: 0, hurtPct: 0, blocked: 0, turns: 0, hp: 0, kills: 0, lost: 0, depthSum: 0 });
	const wardenFights = {};
	for (const r of ok) {
		for (const f of r.fights) {
			for (const [key, v] of Object.entries(f.by || {})) {
				const b = beastOf(key);
				b.fights += 1; b.stood += v[0]; b.acts += v[1]; b.hurt += v[2]; b.blocked += v[3]; b.turns += v[4]; b.hp += v[5];
				b.hurtPct += v[2] / Math.max(1, f.max);
				b.depthSum += f.d;
				bump(b.mines, r.mine);
				if (!f.won) b.lost += 1;
			}
			if (!f.won && f.killer && beast[f.killer]) beast[f.killer].kills += 1;
			if (f.k === 'warden' || f.k === 'boss') {
				const lead = f.foes.find((k) => (pack.creatures[k] || {}).warden) || f.foes[0];
				const id = `${r.mine}|${lead}|${f.k}`;
				const w = wardenFights[id] || (wardenFights[id] = { mine: r.mine, key: lead, name: creatureName(lead), kind: f.k, n: 0, won: 0, turns: 0, hurt: 0, back: 0, depth: 0, hp0: 0, byDelver: {} });
				w.n += 1; w.won += f.won ? 1 : 0; w.turns += f.turns; w.hurt += f.taken / Math.max(1, f.max); w.back += (f.back || 0) / Math.max(1, f.max); w.depth += f.d; w.hp0 += f.hp0 / Math.max(1, f.max);
				const d = w.byDelver[r.c] || (w.byDelver[r.c] = [0, 0]);
				d[0] += 1; d[1] += f.won ? 1 : 0;
			}
		}
	}
	const creatures = Object.values(beast).map((b) => {
		const home = Object.entries(b.mines).sort((x, y) => y[1] - x[1])[0][0];
		return { key: b.key, name: b.name, warden: b.warden, mine: home, mines: Object.keys(b.mines), fights: b.fights, stood: b.stood, depth: round(b.depthSum / b.fights, 1),
			acts: round(b.acts / Math.max(1, b.stood), 2), turns: round(b.turns / Math.max(1, b.stood), 2), hp: round(b.hp / Math.max(1, b.stood), 0),
			// Health it took off the bot for each one that stood, as a share of the bot's health; and for each action it got.
			hurt: round(b.hurtPct / Math.max(1, b.stood)), hurtAct: round(b.hurt / Math.max(1, b.acts), 2), blockedAct: round(b.blocked / Math.max(1, b.acts), 2),
			kills: b.kills, lost: round(b.lost / b.fights) };
	});
	// Against the ordinary creatures of its own mine.
	for (const mine of mineOrder) {
		const plain = creatures.filter((c) => c.mine === mine && !c.warden && c.stood >= 20);
		const hurt = median(plain.map((c) => c.hurt));
		const turns = median(plain.map((c) => c.turns));
		for (const c of creatures.filter((x) => x.mine === mine && !x.warden)) {
			c.hurtX = hurt > 0 ? round(c.hurt / hurt, 2) : null;
			c.turnsX = turns > 0 ? round(c.turns / turns, 2) : null;
		}
	}
	const wardens = Object.values(wardenFights).map((w) => ({ mine: w.mine, key: w.key, name: w.name, kind: w.kind, n: w.n, reached: round(w.n / Math.max(1, (mineMean[w.mine] || {}).n || 1)), won: round(w.won / w.n), turns: round(w.turns / w.n, 1), hurt: round(w.hurt / w.n), back: round(w.back / w.n),
		depth: round(w.depth / w.n, 0), hp0: round(w.hp0 / w.n), byDelver: Object.fromEntries(Object.entries(w.byDelver).map(([c, [n, v]]) => [c, [n, round(v / n)]])) }))
		.sort((a, b) => mineOrder.indexOf(a.mine) - mineOrder.indexOf(b.mine) || a.depth - b.depth);

	const names = { delvers: Object.fromEntries(delverOrder.map((c) => [c, pack.characters[c].name || c])), mines: Object.fromEntries(mineOrder.map((m) => [m, pack.mines[m].name || m])) };
	const summary = { created: new Date().toISOString(), meta: opts.meta || {}, runs: ok.length, gemRuns: every.length - ok.length, broken, heavy: LIMITS.heavy, mines, delvers, stones, gems, creatures, wardens, names };
	summary.flags = flags(summary);
	return summary;
}

// --- what stands out -------------------------------------------------------------------------------

function flags(s) {
	const out = [];
	const pts = (v) => `${v >= 0 ? '+' : '−'}${Math.abs(Math.round(v * 100))}`;
	const give = (se) => `give or take ${Math.max(1, Math.round(se * 100))}`;
	for (const d of s.delvers) {
		const z = d.edgeSe > 0 ? d.edge / d.edgeSe : 0;
		if (Math.abs(z) >= 2 && Math.abs(d.edge) >= LIMITS.delver) {
			out.push({ kind: 'delver', key: d.key, name: d.name, way: d.edge > 0 ? 'over' : 'under', size: Math.abs(d.edge) * 100,
				why: `${pts(d.edge)} points of progress against the middle stone in the same mines (${give(d.edgeSe)}), all three stones together; ${Math.round(d.clear * 100)}% of their runs beat the boss` });
		}
	}
	for (const st of s.stones) {
		const z = st.edgeSe > 0 ? st.edge / st.edgeSe : 0;
		const who = `${s.names.delvers[st.delver]}'s ${st.name}`;
		if (Math.abs(z) >= 2 && Math.abs(st.edge) >= LIMITS.stone) {
			out.push({ kind: 'stone', key: `${st.delver}|${st.key}`, name: who, way: st.edge > 0 ? 'over' : 'under', size: Math.abs(st.edge) * 100,
				why: `${pts(st.edge)} points of progress against the middle stone in the same mines (${give(st.edgeSe)}); ${Math.round(st.clear * 100)}% of its runs beat the boss${st.cost >= 0.02 ? `; its own penalty tier takes ${Math.round(st.cost * 100)}% of a health bar off its delver every fight` : ''}` });
		}
		if (st.within && st.within.se > 0 && Math.abs(st.within.progress / st.within.se) >= 2 && Math.abs(st.within.progress) >= LIMITS.stone) {
			out.push({ kind: 'sibling', key: `${st.delver}|${st.key}`, name: who, way: st.within.progress > 0 ? 'over' : 'under', size: Math.abs(st.within.progress) * 100,
				why: `${pts(st.within.progress)} points against ${s.names.delvers[st.delver]}'s other two stones on the same seeds (${give(st.within.se)})` });
		}
	}
	for (const g of s.gems) {
		const p = g.plant;
		const stands = (band) => band.kits >= LIMITS.gemKits && band.z !== null && Math.abs(band.z) >= 2;
		if (stands({ ...p, z: g.z }) && Math.abs(p.progress) >= LIMITS.gem) {
			out.push({ kind: 'gem', key: g.key, name: g.name, way: p.progress > 0 ? 'over' : 'under', size: Math.abs(p.progress) * 100,
				why: `${pts(p.progress)} points of progress on the ${p.kits} kits it was planted in (${give(p.se)})` });
		} else {
			// Only with light kits, or only with heavy ones: a gem that scales too well, or not at all.
			for (const [band, words] of [[p.heavy, `heavy kits (${s.heavy} carats and up)`], [p.light, `light kits (under ${s.heavy} carats)`]]) {
				if (stands(band) && Math.abs(band.z) >= 2.5 && Math.abs(band.progress) >= LIMITS.band) {
					out.push({ kind: 'gem', key: g.key, name: g.name, way: band.progress > 0 ? 'over' : 'under', size: Math.abs(band.progress) * 100,
						why: `${pts(band.progress)} points of progress with ${words}, on the ${band.kits} it was planted in (${give(band.se)})` });
					break;
				}
			}
		}
		if (g.rail.ratio !== null && g.rail.ratio >= LIMITS.outsized && g.rail.turns >= 200) {
			const parts = [['damage', g.rail.damage], ['block', g.rail.block], ['healing', g.rail.healed], ['Poison and the like', g.rail.debuffs]].filter(([, v]) => v >= 0.5).sort((a, b) => b[1] - a[1]).slice(0, 2).map(([k, v]) => `${inWords(v)} ${k}`);
			out.push({ kind: 'gem', key: g.key, name: g.name, way: 'outsized', size: Math.min(60, g.rail.ratio * 4),
				why: `does ${times(g.rail.ratio)} what the middle ${g.rarity.toLowerCase()} gem does a turn, carat for carat (${parts.join(', ')} a turn as it was played)${g.rail.ratio >= 1000 ? ': it ran away' : ''}` });
		}
		if (g.rail.turns >= 200 && g.rail.fires <= LIMITS.idle) {
			out.push({ kind: 'gem', key: g.key, name: g.name, way: 'idle', size: 1 + (LIMITS.idle - g.rail.fires) * 10,
				why: `fires on ${Math.round(g.rail.fires * 100)}% of the turns it sits on a rail (${g.rail.turns} turns)` });
		}
		if (g.pick.vault >= LIMITS.vault && g.pick.rate !== null && g.pick.rate <= LIMITS.shunned && !(p.progress > 0.03)) {
			out.push({ kind: 'gem', key: g.key, name: g.name, way: 'shunned', size: 1,
				why: `the bot set it on ${Math.round(g.pick.rate * 100)}% of the rails it could have (${g.pick.vault} vaults): it adds little to a rail as the bot plays it` });
		}
	}
	const mineRuns = Object.fromEntries(s.mines.map((m) => [m.key, m.runs]));
	for (const c of s.creatures) {
		if (c.warden || c.stood < LIMITS.met || c.hurtX === null) continue;
		const killed = c.kills / Math.max(1, mineRuns[c.mine] || 1);
		if (c.hurtX >= LIMITS.hurtHigh || killed >= LIMITS.kills) {
			out.push({ kind: 'creature', key: c.key, name: c.name, mine: c.mine, way: 'over', size: Math.max(c.hurtX * 10, killed * 200),
				why: `ended ${c.kills} runs (one for every ${Math.max(1, Math.round(1 / Math.max(killed, 0.001)))} played in ${s.names.mines[c.mine]}); takes ${(c.hurt * 100).toFixed(1)}% of the bot's health a fight, ${c.hurtX.toFixed(1)}× the middle creature of its mine` });
		} else if (c.hurtX <= LIMITS.hurtLow && (c.turnsX ?? 1) <= 1.05) {
			out.push({ kind: 'creature', key: c.key, name: c.name, mine: c.mine, way: 'under', size: (1 - c.hurtX) * 25,
				why: `takes ${(c.hurt * 100).toFixed(1)}% of the bot's health a fight, ${c.hurtX.toFixed(2)}× the middle creature of ${s.names.mines[c.mine]}, and stands ${c.turns.toFixed(1)} turns` });
		}
	}
	for (const w of s.wardens) {
		if (w.n < LIMITS.wardenMet) continue;
		const what = w.kind === 'boss' ? 'boss' : 'Warden';
		const where = `${what} of ${s.names.mines[w.mine].replace(/^The /, 'the ')}, depth ${w.depth}`;
		const ended = w.reached * (1 - w.won);
		// A mine is played with the kit that beats its boss four times in ten, so its boss ends
		// many runs by the way it was set up; a Warden on the way down that does is a finding.
		if (w.won <= LIMITS.wall || (w.kind !== 'boss' && ended >= LIMITS.ends)) {
			out.push({ kind: 'warden', key: `${w.mine}|${w.key}`, name: w.name, mine: w.mine, way: 'over', size: Math.max((1 - w.won) * 100, ended * 200),
				why: `${where}: beaten by ${Math.round(w.won * 100)}% of the ${w.n} runs that reached it, and the end of ${Math.round(ended * 100)}% of all runs in the mine; the fight cost ${Math.round(w.hurt * 100)}% of a full health bar` });
		} else if (w.won >= LIMITS.walk && w.hurt <= 0.25) {
			out.push({ kind: 'warden', key: `${w.mine}|${w.key}`, name: w.name, mine: w.mine, way: 'under', size: (w.won - LIMITS.walk) * 100 + (0.25 - w.hurt) * 100,
				why: `${where}: beaten by ${Math.round(w.won * 100)}% of the ${w.n} runs that reached it, for ${Math.round(w.hurt * 100)}% of a full health bar` });
		}
	}
	return out.sort((a, b) => b.size - a.size);
}

// --- what moved ------------------------------------------------------------------------------------

export function diff(before, after) {
	const out = { mines: {}, stones: {}, gems: {}, wardens: {}, creatures: {}, same: before.meta && after.meta && JSON.stringify(before.meta.kits || {}) === JSON.stringify(after.meta.kits || {}) };
	for (const m of after.mines) { const was = before.mines.find((x) => x.key === m.key); if (was) out.mines[m.key] = { clear: round(m.clear - was.clear), progress: round(m.progress - was.progress) }; }
	for (const s of after.stones) { const was = before.stones.find((x) => x.delver === s.delver && x.key === s.key); if (was) out.stones[`${s.delver}|${s.key}`] = { clear: round(s.clear - was.clear), progress: round(s.progress - was.progress), edge: round(s.edge - was.edge) }; }
	for (const g of after.gems) { const was = before.gems.find((x) => x.key === g.key); if (was && was.rail.turns && g.rail.turns) out.gems[g.key] = { power: round(g.rail.power - was.rail.power, 2), flat: round(g.rail.flat - was.rail.flat, 2) }; }
	for (const w of after.wardens) { const was = before.wardens.find((x) => x.key === w.key && x.mine === w.mine && x.kind === w.kind); if (was) out.wardens[`${w.mine}|${w.key}|${w.kind}`] = { won: round(w.won - was.won) }; }
	for (const c of after.creatures) { const was = before.creatures.find((x) => x.key === c.key); if (was) out.creatures[c.key] = { hurt: round(c.hurt - was.hurt) }; }
	return out;
}

// --- the report as text ----------------------------------------------------------------------------

const pct = (v, d = 0) => (v === null || v === undefined || !Number.isFinite(v) ? '—' : `${(v * 100).toFixed(d)}%`);
const num = (v, d = 1) => (v === null || v === undefined || !Number.isFinite(v) ? '—' : v.toFixed(d));
const signed = (v, d = 0) => (v === null || v === undefined || !Number.isFinite(v) ? '—' : `${v >= 0 ? '+' : ''}${(v * 100).toFixed(d)}`);
const pad = (s, n) => String(s).padEnd(n);
const lead = (s, n) => String(s).padStart(n);
export const CUTS = ['Poor', 'Fair', 'Good', 'Keen', 'Perfect'];
export const CLARITIES = ['Intricate', 'Etched', 'Included', 'Clear', 'Pristine', 'Flawless'];
export const kitWords = (kit) => (kit ? `${kit.carat}ct ${CUTS[kit.cut] || ''} ${CLARITIES[kit.clarity ?? 3] || ''}`.trim() : '');
// What each kind of flag is called, either way.
export const WAYS = {
	delver: { over: 'strong', under: 'weak' },
	stone: { over: 'strong', under: 'weak' },
	sibling: { over: 'over its siblings', under: 'under its siblings' },
	gem: { over: 'strong', under: 'weak', outsized: 'outsized', idle: 'rarely fires', shunned: 'never chosen' },
	warden: { over: 'a wall', under: 'a walkover' },
	creature: { over: 'dangerous', under: 'harmless' },
};
export const GROUPS = [
	['delver', 'Delvers', 'all three stones together, against the middle stone in the same mines'],
	['stone', 'Birthstones', 'against the middle stone in the same mines'],
	['sibling', 'Birthstones, within a delver', 'against the delver\'s other two stones, seed for seed'],
	['gem', 'Gems', 'planted on a rail whatever the bot thought of them, and what they did there'],
	['warden', 'Wardens and bosses', 'by how many of the runs that reached them they ended'],
	['creature', 'Creatures', 'against the middle creature of their own mine'],
];

export function render(s, moved = null) {
	const out = [];
	const say = (line = '') => out.push(line);
	const was = (book, key, field, d = 0) => (moved && moved[book] && moved[book][key] && Math.abs(moved[book][key][field]) >= 0.005 ? ` (${signed(moved[book][key][field], d)})` : '');
	const band = (p) => (p && p.kits >= 2 ? `${signed(p.progress)} ±${(p.se * 100).toFixed(0)}` : '—');
	// A gem's output a turn is a plain number (and can be billions), not a share: no points.
	const wasGem = (key) => {
		const m = moved && moved.gems && moved.gems[key];
		return m && Number.isFinite(m.flat) && Math.abs(m.flat) >= 0.05 ? ` (${m.flat > 0 ? '+' : '−'}${short(Math.abs(m.flat))})` : '';
	};
	say(`# Balance runs · ${s.runs} runs${s.gemRuns ? ` and ${s.gemRuns} more for the gems` : ''}${s.broken ? ` (${s.broken} never finished and are left out)` : ''}`);
	if (s.meta && s.meta.created) say(`played ${new Date(s.meta.created).toLocaleString()} · pack ${s.meta.packHash || '?'} · ${s.meta.seconds || '?'}s on ${s.meta.workers || '?'} workers · ${(s.meta.args || []).join(' ') || 'defaults'}`);
	if (moved) say(moved.same === false ? '(in brackets: what moved since the run before, which was played with other kits)' : '(in brackets: what moved since the run before)');
	say();
	say('## What stands out');
	for (const [kind, title, how] of GROUPS) {
		const of = s.flags.filter((f) => f.kind === kind);
		if (!of.length) continue;
		say(`${title} (${how}):`);
		for (const f of of.slice(0, 16)) say(`  ${pad((WAYS[kind] || {})[f.way] || f.way, 19)}${pad(f.name, 26)} ${f.why}`);
		if (of.length > 16) say(`  and ${of.length - 16} more in the tables below`);
	}
	if (!s.flags.length) say('Nothing stands further from its peers than chance would put it. More seeds read finer.');
	say();
	say('## Mines');
	say(`${pad('mine', 16)}${lead('runs', 6)}${lead('clear', 7)}${lead('progress', 10)}${lead('fights', 8)}  ${pad('kit', 28)} fell in a fight / to an elite / a Warden / the boss · what ended most`);
	for (const m of s.mines) {
		const d = m.deaths;
		say(`${pad(m.name, 16)}${lead(m.runs, 6)}${lead(pct(m.clear), 7)}${lead(pct(m.progress), 10)}${lead(num(m.fights), 8)}  ${pad(`${num(m.stones, 1)} × ${kitWords(m.kit)}`, 28)} ${d.fight || 0} / ${d.elite || 0} / ${d.warden || 0} / ${d.boss || 0} · ${m.killers.slice(0, 4).map((k) => `${k.name} ${k.n}`).join(', ')}${was('mines', m.key, 'clear')}`);
	}
	say();
	say('## Wardens and bosses');
	say('health lost: what the fight cost, as a share of a full health bar (healing counts, so it can pass 100%). thrown back: the part of that sent back for blows dealt.');
	say(`${pad('mine', 16)}${pad('', 7)}${pad('creature', 22)}${lead('depth', 6)}${lead('met', 6)}${lead('beaten', 8)}${lead('turns', 7)}${lead('health lost', 13)}${lead('thrown back', 13)}  beaten, delver by delver`);
	for (const w of s.wardens) {
		const by = Object.entries(w.byDelver).map(([c, [n, v]]) => `${s.names.delvers[c].slice(0, 3)} ${n >= 3 ? pct(v) : '—'}`).join(' ');
		say(`${pad(s.names.mines[w.mine], 16)}${pad(w.kind, 7)}${pad(w.name, 22)}${lead(w.depth, 6)}${lead(w.n, 6)}${lead(pct(w.won), 8)}${lead(num(w.turns), 7)}${lead(pct(w.hurt), 13)}${lead(pct(w.back), 13)}  ${by}${was('wardens', `${w.mine}|${w.key}|${w.kind}`, 'won')}`);
	}
	say();
	say('## Delvers');
	say(`${pad('delver', 10)}${lead('runs', 6)}${lead('clear', 7)}${lead('progress', 10)}${lead('edge', 8)}${lead('±', 4)}  clear, mine by mine`);
	for (const d of s.delvers) {
		say(`${pad(d.name, 10)}${lead(d.runs, 6)}${lead(pct(d.clear), 7)}${lead(pct(d.progress), 10)}${lead(signed(d.edge), 8)}${lead(d.edgeSe === null ? '' : (d.edgeSe * 100).toFixed(0), 4)}  ${s.mines.map((m) => (d.byMine[m.key] ? pct(d.byMine[m.key].clear) : '—').padStart(5)).join('')}`);
	}
	say();
	say('## Birthstones');
	say('edge: progress over the middle stone in the same mines. vs siblings: against the delver\'s other two stones on the same seeds (± one standard error).');
	say(`${pad('delver', 9)}${pad('stone', 20)}${lead('runs', 6)}${lead('clear', 7)}${lead('progress', 10)}${lead('edge', 8)}${lead('±', 4)}${lead('vs siblings', 13)}${lead('fires', 7)}${lead('dmg share', 11)}  clear, mine by mine`);
	for (const st of s.stones) {
		const mines = s.mines.map((m) => (st.byMine[m.key] ? pct(st.byMine[m.key].clear) : '—').padStart(5)).join('');
		say(`${pad(s.names.delvers[st.delver], 9)}${pad(st.name, 20)}${lead(st.runs, 6)}${lead(pct(st.clear), 7)}${lead(pct(st.progress), 10)}${lead(signed(st.edge), 8)}${lead(st.edgeSe === null ? '' : (st.edgeSe * 100).toFixed(0), 4)}${lead(st.within ? `${signed(st.within.progress)} ±${(st.within.se * 100).toFixed(0)}` : '', 13)}${lead(num(st.fires, 2), 7)}${lead(pct(st.share), 11)}  ${mines}${was('stones', `${st.delver}|${st.key}`, 'progress')}`);
		say(`${pad('', 29)}tiers a turn: ${st.tiers.map((t) => `${t.name} ${num(t.rate, 2)}`).join(' · ')}${st.cost > 0.001 ? ` · costs its delver ${pct(st.cost, 1)} of a health bar a fight` : ''}`);
	}
	say();
	say('## Gems');
	say('planted: progress of the runs it was set on whatever the bot thought, against the same delver, stone and mine (± one standard error; kits: how many).');
	say(`light, heavy: the same with kits under ${s.heavy} carats, and from ${s.heavy} up. chosen: how often the bot set it when it lay in the vault unplanted. taken: how often it took it when the mine offered it.`);
	say('a turn: what it did for each turn it sat on a rail (damage + 0.7 block + 0.8 healing + 1.5 debuffs); x peers: that at one carat, against the middle gem of its rarity that does anything a tally shows.');
	const order = { COMMON: 0, UNCOMMON: 1, RARE: 2, LEGENDARY: 3, MYTHIC: 4, TRANSCENDENT: 5 };
	const sorted = s.gems.slice().sort((a, b) => (order[a.rarity] ?? 9) - (order[b.rarity] ?? 9) || (b.plant.progress ?? -9) - (a.plant.progress ?? -9));
	say(`${pad('gem', 16)}${pad('color', 8)}${pad('rarity', 11)}${lead('planted', 9)}${lead('±', 4)}${lead('kits', 6)}${lead('light', 10)}${lead('heavy', 10)}${lead('chosen', 8)}${lead('taken', 7)}${lead('turns', 8)}${lead('fires', 7)}${lead('a turn', 9)}${lead('x peers', 9)}${lead('dmg', 8)}${lead('blk', 8)}${lead('heal', 7)}`);
	for (const g of sorted) {
		say(`${pad(g.name, 16)}${pad(g.color.toLowerCase(), 8)}${pad(g.rarity.toLowerCase(), 11)}${lead(g.plant.kits >= 2 ? signed(g.plant.progress) : '—', 9)}${lead(g.plant.kits >= 2 ? (g.plant.se * 100).toFixed(0) : '', 4)}${lead(g.plant.kits, 6)}${lead(band(g.plant.light), 10)}${lead(band(g.plant.heavy), 10)}${lead(pct(g.pick.rate), 8)}${lead(pct(g.loot.rate), 7)}${lead(g.rail.turns, 8)}${lead(num(g.rail.fires, 2), 7)}${lead(short(g.rail.power), 9)}${lead(g.rail.ratio === null ? '—' : g.rail.ratio >= 1000 ? '>1000x' : `${g.rail.ratio.toFixed(1)}x`, 9)}${lead(short(g.rail.damage), 8)}${lead(short(g.rail.block), 8)}${lead(short(g.rail.healed), 7)}${wasGem(g.key)}`);
	}
	say();
	say('## Creatures');
	say('hurt: the health one of them took off the bot in a fight, as a share of the bot\'s health; x: that against the middle creature of its mine. stood: turns it lasted.');
	say(`${pad('mine', 16)}${pad('creature', 22)}${lead('depth', 6)}${lead('met', 7)}${lead('hurt', 7)}${lead('x', 6)}${lead('stood', 7)}${lead('x', 6)}${lead('a blow', 8)}${lead('blocked', 9)}${lead('ended', 7)}`);
	for (const mine of s.mines.map((m) => m.key)) {
		for (const c of s.creatures.filter((x) => x.mine === mine && !x.warden).sort((a, b) => (b.hurt ?? 0) - (a.hurt ?? 0))) {
			say(`${pad(s.names.mines[mine], 16)}${pad(c.name, 22)}${lead(num(c.depth, 0), 6)}${lead(c.stood, 7)}${lead(pct(c.hurt, 1), 7)}${lead(num(c.hurtX, 2), 6)}${lead(num(c.turns, 2), 7)}${lead(num(c.turnsX, 2), 6)}${lead(num(c.hurtAct), 8)}${lead(num(c.blockedAct), 9)}${lead(c.kills, 7)}${was('creatures', c.key, 'hurt')}`);
		}
	}
	return out.join('\n');
}
