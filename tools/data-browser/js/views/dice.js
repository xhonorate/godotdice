// Dice: the bowl's hand odds and total, and every die definition with its distribution.

import * as C from '../sim/content.js';
import * as Dice from '../sim/dice.js';
import * as Forge from '../sim/forge.js';
import { h, card, stat, table, fmt, fmtPct, segmented, field, toolbar, note, kv, chip, select } from '../ui.js';
import { columns, histogram, lines, heat } from '../charts.js';
import { dieImage } from '../gemart.js';
import { bowlControls, whenReady, rarityChip, tabs, faceRow, bowlSummary, RARITY_COLORS } from './common.js';

const state = { tab: 'bowl', copies: 5 };
const PATTERNS = [['pair', 'A pair', 'sets'], ['two_pair', 'Two pair', 'sets'], ['triple', 'Three of a kind', 'sets'], ['full_house', 'Full house', 'sets'], ['quad', 'Four of a kind', 'sets'], ['quint', 'Five of a kind', 'sets'],
	['straight3', 'Straight of 3', 'straight'], ['straight4', 'Straight of 4', 'straight'], ['straight5', 'Straight of 5', 'straight'], ['distinct4', '4 distinct values', 'distinct'], ['distinct5', '5 distinct values', 'distinct'],
	['allOdd', 'All odd', 'odd'], ['allEven', 'All even', 'even'], ['anyCrown', 'A die on its top face', 'high'], ['anyOne', 'A rolled 1', 'low']];

export default {
	id: 'dice', label: 'Dice', blurb: 'The bowl and every die', count: () => C.keys('dice').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="8" cy="8" r="1.3" fill="currentColor"/><circle cx="16" cy="8" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="8" cy="16" r="1.3" fill="currentColor"/><circle cx="16" cy="16" r="1.3" fill="currentColor"/></svg>',
	render(root, route, ctx) {
		if (route.params.tab) state.tab = route.params.tab;
		root.append(tabs([['bowl', 'The bowl'], ['dice', 'Die definitions']], state.tab, (t) => { state.tab = t; ctx.rerender(); }));
		if (state.tab === 'bowl') bowlPage(root, ctx); else dicePage(root, route, ctx);
	},
};

function bowlPage(root, ctx) {
	root.append(toolbar(...bowlControls(ctx, { showRerolls: false })));
	const bowl = ctx.settings.bowl;
	const dice = bowl.map((k, i) => Dice.dieFrom(k, `d${i}`));
	const summary = bowlSummary(bowl);
	const totals = Dice.totalDistribution(dice);
	const totalMean = [...totals].reduce((s, [k, p]) => s + k * p, 0);
	root.append(h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(6, minmax(0,1fr))' } },
		stat('Mean total', fmt(totalMean, 2), 'no rerolls', { class: 'accent' }), stat('Most it can roll', String(summary.maxTotal), 'what % triggers measure against'),
		stat('Tops', dice.map((d) => Dice.top(d)).join(' · '), 'per die'), stat('Faces', dice.map((d) => d.faces.length).join(' · ')), stat('Etched faces', String(dice.reduce((s, d) => s + Dice.etchings(d).length, 0)), Dice.BOON_FACES.concat(Dice.BANE_FACES).join(', ')),
		stat('Materials', dice.filter((d) => d.material).length ? dice.filter((d) => d.material).map((d) => Dice.materialName(d.material)).join(', ') : 'none')));
	const grid = h('div', { class: 'grid grid-2' });
	root.append(grid);
	grid.append(card('Total of the hand', h('div', { class: 'col' }, histogram({ bins: [...totals], width: 480, height: 190, color: '#e2b23a', mean: totalMean, xLabel: 'total', xFormat: (v) => String(v) }),
		h('div', { class: 'row', style: { justifyContent: 'space-between' } }, [70, 75, 80, 85, 90].map((pct) => { let p = 0; for (const [k, q] of totals) if (k * 100 >= summary.maxTotal * pct) p += q; return chip(`≥${pct}% of max: ${fmtPct(p, 1)}`); }), [40, 50, 60].map((pct) => { let p = 0; for (const [k, q] of totals) if (k * 100 <= summary.maxTotal * pct) p += q; return chip(`≤${pct}%: ${fmtPct(p, 1)}`); })),
		note('Exact, before rerolls. Overkill asks for the total at 90% (Poor) to 70% (Perfect) of the maximum; Bulwark for 40% to 60% or less.', 'plain')), { meta: 'exact distribution' }));
	const patternSlot = h('div');
	grid.append(card('Hand patterns · chance with 0, 1 and 2 rerolls', patternSlot, { meta: 'rerolls chase the pattern in the row' }));
	const policies = [...new Set(PATTERNS.map((p) => p[2]))];
	const jobs = [];
	for (const policy of policies) for (const rerolls of [0, 1, 2]) jobs.push(ctx.engine.run('handStats', { bowl, rerolls, policy, samples: 6000 }).then((r) => [policy, rerolls, r]));
	whenReady(ctx, patternSlot, Promise.all(jobs), (results) => {
		const lookup = new Map(results.map(([policy, rerolls, r]) => [`${policy}:${rerolls}`, r]));
		const rows = PATTERNS.map(([key, label, policy]) => ({ key, label, values: [0, 1, 2].map((rr) => lookup.get(`${policy}:${rr}`).patterns[key]) }));
		return table({ columns: [{ key: 'label', label: 'Pattern' }, ...[0, 1, 2].map((rr) => ({ key: `r${rr}`, label: `${rr} rerolls`, align: 'right', render: (r) => h('span', { class: 'ladder-cell', style: { background: heat(r.values[rr] * 0.9), minWidth: '54px', color: r.values[rr] > 0.65 ? '#141414' : 'var(--text)' } }, fmtPct(r.values[rr], 1)) }))], rows, compact: true, rowKey: (r) => r.key });
	});
	const g2 = h('div', { class: 'grid grid-3' });
	root.append(g2);
	const highSlot = h('div'), distinctSlot = h('div'), lowSlot = h('div');
	g2.append(card('Highest die', highSlot, { meta: 'no rerolls' }), card('Distinct values and low dice', distinctSlot, { meta: 'no rerolls' }), card('High die as % of its top', lowSlot, { meta: 'Hex, Refract and Facet read this' }));
	const raw = ctx.engine.run('handStats', { bowl, rerolls: 0, policy: 'none', samples: 8000 });
	whenReady(ctx, highSlot, raw, (r) => histogram({ bins: r.highs, width: 300, height: 150, color: '#6f9fe0', xLabel: 'highest die', xFormat: (v) => String(v) }));
	whenReady(ctx, distinctSlot, raw, (r) => h('div', { class: 'col' }, columns({ data: r.distinct.map(([k, p]) => ({ label: `${k} distinct`, value: p * 100, key: k, note: 'of hands' })), width: 300, height: 90, format: (v) => `${fmt(v, 0)}%`, valueLabels: 'all', color: '#4fae7a' }),
		columns({ data: r.lowDice.map(([k, p]) => ({ label: `${k} low`, value: p * 100, key: k, note: 'dice at or below half their top' })), width: 300, height: 90, format: (v) => `${fmt(v, 0)}%`, valueLabels: 'all', color: '#8b5fd6' })));
	whenReady(ctx, lowSlot, raw, (r) => h('div', { class: 'col' }, columns({ data: r.highPct.map(([k, p]) => ({ label: `${k}`, value: p * 100, key: k, note: `% of its top face` })), width: 300, height: 150, format: (v) => `${fmt(v, 0)}%`, color: '#c9a43e' }), h('p', { class: 'tiny muted' }, 'Hex asks for a die at 95% (Poor) to 70% (Perfect) of its own top; Facet 90% to 0%.')));
}

function dicePage(root, route, ctx) {
	const keys = C.keys('dice');
	const active = route.key && C.die(route.key).name ? route.key : 'D6';
	const grid = h('div', { class: 'grid grid-side-wide' });
	root.append(grid);
	const gallery = h('div', { class: 'gem-grid', style: { gridTemplateColumns: 'repeat(4, 1fr)' } }, keys.map((k) => { const d = C.die(k); return h('button', { type: 'button', class: `gem-tile${k === active ? ' is-active' : ''}`, onClick: () => ctx.navigate('dice', k) }, dieImage(k, 56), h('span', { class: 'tile-name' }, d.name || k), h('span', { class: 'tile-sub' }, `${d.shape} · ${C.title(d.rarity)}`)); }));
	grid.append(h('div', { class: 'card' }, h('div', { class: 'card-body scroll-y', style: { maxHeight: 'calc(100vh - 180px)' } }, gallery)));
	const def = C.die(active);
	const die = Dice.make(active, 'x');
	const dist = Dice.faceDistribution(die);
	const single = [...dist].filter(([k]) => k !== 'mirror').sort((a, b) => a[0] - b[0]);
	const mean = single.reduce((s, [k, p]) => s + k * p, 0);
	const copies = Array.from({ length: state.copies }, (_, i) => Dice.make(active, `c${i}`));
	const totals = Dice.totalDistribution(copies);
	const totalMean = [...totals].reduce((s, [k, p]) => s + k * p, 0);
	const tierIndex = Dice.TIERS.indexOf(def.shape);
	const detail = h('div', { class: 'col' });
	detail.append(h('div', { class: 'card' }, h('div', { class: 'card-body' }, h('div', { class: 'detail-head' }, h('span', { class: 'pic hero' }, dieImage(active, 140)),
		h('div', { class: 'detail-title' }, h('div', { class: 'row tight' }, rarityChip(def.rarity), chip(`${def.shape} solid`), def.price ? chip(`${def.price} pyrite`) : null, def.top ? chip(`judged against a top of ${def.top}`) : null),
			h('h2', {}, def.name || active), def.text ? h('p', { class: 'lede' }, def.text) : null, h('div', { class: 'row' }, faceRow(def, die)),
			h('p', { class: 'small muted' }, `Mean ${fmt(mean, 2)} · top ${Dice.top(die)} · ${die.faces.length} faces${die.faces.some((f) => f.kind !== 'plain') ? ` · special: ${[...new Set(die.faces.filter((f) => f.kind !== 'plain').map((f) => f.kind))].join(', ')}` : ''}`))))));
	detail.append(h('div', { class: 'grid grid-2' },
		card('One die', h('div', { class: 'col' }, columns({ data: single.map(([k, p]) => ({ label: String(k), value: p * 100, key: k, note: 'chance' })), width: 420, height: 160, format: (v) => `${fmt(v, 1)}%`, color: '#e9e1d2', labelEvery: Math.max(1, Math.ceil(single.length / 14)) }),
			die.faces.some((f) => f.kind === 'exploding') ? note('An exploding face rolls again and adds the result, up to three extra times; the long tail above is those.', 'plain') : null), { meta: 'exact' }),
		card(`${state.copies} of them · total`, h('div', { class: 'col' }, h('div', { class: 'row' }, field('Copies', segmented([[1, '1'], [2, '2'], [3, '3'], [4, '4'], [5, '5']], state.copies, (v) => { state.copies = Number(v); ctx.rerender(); }))),
			histogram({ bins: [...totals], width: 420, height: 150, color: '#e2b23a', mean: totalMean, xLabel: 'total', xFormat: (v) => String(v) })), { meta: 'exact' })));
	detail.append(card('Where it sits on the tier ladder', h('div', { class: 'col' }, h('div', { class: 'shaft', style: { gridTemplateColumns: `repeat(${Dice.TIERS.length}, 1fr)` } }, Dice.TIERS.map((t, i) => h('div', { class: `shaft-cell${i === tierIndex ? ' landing' : ''}` }, h('i', { style: { background: i === tierIndex ? 'var(--accent)' : heat(i / Dice.TIERS.length * 0.6) } }), h('span', {}, t)))),
		h('p', { class: 'small text-2' }, tierIndex >= 0 ? `A smithy hammers it to ${Dice.TIERS[tierIndex + 1] || 'nothing bigger'} or files it to ${Dice.TIERS[tierIndex - 1] || 'nothing smaller'}; its pattern is cut again across the new faces and its etchings and material stay. Dread lowers an enemy's die a tier per stack.` : 'Not on the shared ladder.'),
		h('div', { class: 'section-title' }, 'Patterns it can take'), h('div', { class: 'row tight' }, C.keys('patterns').filter((k) => Dice.patternAllows(String(C.pattern(k).key), def.shape)).map((k) => chip(`${C.pattern(k).name}: ${C.pattern(k).text}`, { color: RARITY_COLORS[C.pattern(k).rarity] }))),
		h('div', { class: 'section-title' }, 'Etchings'), h('div', { class: 'row tight' }, C.keys('etchings').map((k) => chip(`${C.etching(k).name}: ${C.etching(k).text}`, { color: RARITY_COLORS[C.etching(k).rarity] }))),
		h('div', { class: 'section-title' }, 'Materials'), h('div', { class: 'row tight' }, C.keys('materials').map((k) => chip(`${C.material(k).name}: ${C.material(k).text}`, { color: RARITY_COLORS[C.material(k).rarity] }))),
		h('div', { class: 'section-title' }, 'What it would cost at a stall'), h('div', { class: 'row tight' },
			chip(`plain: ${Forge.diePrice(die)} pyrite`),
			...C.keys('patterns').filter((k) => Dice.patternAllows(String(C.pattern(k).key), def.shape)).slice(0, 3).map((k) => chip(`${C.pattern(k).name}: ${Forge.diePrice(Dice.make(def.shape, 'p', { pattern: String(C.pattern(k).key) }))}`)),
			chip(`a material: ${Forge.diePrice(Dice.make(def.shape, 'm', { material: 'ruby' }))}`),
			chip(`shiny: ${Forge.diePrice(Dice.make(def.shape, 's', { etches: [{ face: 0, kind: 'shiny' }] }))}`)))));
	grid.append(detail);
}
