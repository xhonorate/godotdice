// The forge: what luck does to a stone's carat, cut, clarity, inclusions, grade and worth.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import * as Stone from '../sim/stone.js';
import { h, card, stat, table, fmt, fmtPct, select, field, toolbar, note, numberInput, kv } from '../ui.js';
import { columns, lines, histogram, stacked, bars } from '../charts.js';
import { rawImage, markColor, colorKeyMark, gemImage } from '../gemart.js';
import { depthControls, cutNames, clarityNames, whenReady, CUT_COLORS, CLARITY_COLORS, GRADE_COLORS, RARITY_COLORS } from './common.js';

const SOURCES = [['0', 'A fight (+0)'], ['4', 'An elite (+4)'], ['2', 'A merchant’s stall (+2)'], ['-2', 'Seam chips (−2)'], ['3', 'Seam, pried (+3)'], ['8', 'A Royal Flush (+8)'], ['custom', 'Custom…']];
const state = { source: '0', custom: 0 };

const bonusOf = () => (state.source === 'custom' ? state.custom : parseInt(state.source, 10) || 0);

export default {
	id: 'stones', label: 'Stone luck', blurb: 'Carat, Cut, Clarity and grade by depth', count: () => '',
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 14 12 4l8 10-8 6Z"/><path d="M4 14h16M12 4v16"/></svg>',
	render(root, route, ctx) {
		const mine = C.mine(ctx.settings.mine);
		const depth = ctx.settings.depth;
		const bonus = bonusOf();
		const q = Forge.luck(mine, depth, bonus);
		root.append(toolbar(...depthControls(ctx, { showParty: false }), field('Handed over by', select(SOURCES, state.source, (v) => { state.source = v; ctx.rerender(); })),
			state.source === 'custom' ? field('Bonus luck', numberInput(state.custom, (v) => { state.custom = v || 0; ctx.rerender(); })) : null));

		const carats = Forge.caratDistribution(q);
		const caratMean = carats.reduce((s, p, c) => s + p * c, 0);
		const cutP = Forge.normalize(Forge.cutWeights(q));
		const clarP = Forge.normalize(Forge.clarityWeights(q));
		const clarN = clarityNames(), cutN = cutNames();
		const clear = C.clearIndex();
		const classShare = Stone.SIZE_CLASSES.map((cls, i) => { const hi = i + 1 < Stone.SIZE_CLASSES.length ? Stone.SIZE_CLASSES[i + 1].low - 1 : Stone.caratMax(); let p = 0; for (let c = cls.low; c <= hi; c++) p += carats[c] || 0; return { label: cls.name, value: p, color: GRADE_COLORS[i] }; });
		const inclusionByClarity = clarN.map((_, k) => Forge.inclusionOdds(Stone.inclusionSlots(k), mine, ''));
		const anyIncl = (key) => clarP.reduce((s, p, k) => s + p * (inclusionByClarity[k][key] || 0), 0);
		const starKeys = C.keys('inclusions').filter((k) => C.inclusion(k).class === 'STAR');
		const pStar = starKeys.reduce((s, k) => s + anyIncl(k), 0);
		root.append(h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(8, minmax(0,1fr))' } },
			stat('Luck', fmt(q, 1), `mine ${Forge.mineLuck(mine)} · depth ${fmt(Forge.quality(depth), 1)} · source ${bonus >= 0 ? '+' : ''}${bonus}`, { class: 'accent' }),
			stat('Mean carat', fmt(caratMean, 2), `σ ${fmt(Forge.caratParams(q).deviation, 2)} before rounding`),
			stat('Huge stone', fmtPct(classShare[4].value, 1), '20 carats or more'),
			stat('Perfect cut', fmtPct(cutP[4], 1), `Poor ${fmtPct(cutP[0], 1)}`),
			stat('Flawless', fmtPct(clarP[clarN.length - 1], 1), `Intricate ${fmtPct(clarP[0], 1)}`),
			stat('Carries an inclusion', fmtPct(clarP.slice(0, clear).reduce((a, b) => a + b, 0), 1), 'Included or lower'),
			stat('A Star', fmtPct(pStar, 2), 'in any one stone'),
			stat('Void', fmtPct(anyIncl('VOID'), 2), 'a slotless, fragile stone')));

		const g1 = h('div', { class: 'grid grid-2' });
		root.append(g1);
		g1.append(card('Carat', h('div', { class: 'col' },
			histogram({ bins: carats.map((p, c) => [c, p]).filter(([c]) => c >= 1), width: 480, height: 170, color: '#f0c95a', mean: caratMean, xLabel: 'carat', xFormat: (v) => String(v), format: (v) => `${(v * 100).toFixed(1)}%` }),
			stacked({ segments: classShare }),
			h('div', { class: 'row', style: { justifyContent: 'space-around', alignItems: 'flex-end' } }, Stone.SIZE_CLASSES.map((cls, i) => h('div', { class: 'col', style: { alignItems: 'center', gap: '2px' } }, rawImage(['RED', 'BLUE', 'GREEN', 'VIOLET', 'GOLD'][i], cls.key, 56), h('span', { class: 'tiny muted' }, `${cls.name} · ${Stone.sizeClass(cls.low).range}`)))),
			note(`Carat = round(normal(mean ${fmt(Forge.caratParams(q).mean, 2)}, σ ${fmt(Forge.caratParams(q).deviation, 2)})), then ${Forge.JACKPOT_PERCENT}% of stones add 3 to 8, clamped to 1 to ${Stone.caratMax()}. A raw stone shows only its size class.`, 'plain')),
			{ meta: 'exact distribution at this luck' }));
		g1.append(card('Cut and Clarity', h('div', { class: 'col' },
			h('div', { class: 'grid grid-2' },
				columns({ data: cutN.map((n, i) => ({ label: n, value: cutP[i] * 100, color: CUT_COLORS[i], key: i, note: 'of stones' })), width: 240, height: 170, format: (v) => `${fmt(v, 0)}%`, valueLabels: 'all' }),
				columns({ data: clarN.map((n, i) => ({ label: n.slice(0, 5), value: clarP[i] * 100, color: CLARITY_COLORS[i], key: i, note: n })), width: 280, height: 170, format: (v) => `${fmt(v, 0)}%`, valueLabels: 'all' })),
			h('div', { class: 'row', style: { justifyContent: 'space-between' } }, h('span', { class: 'small muted' }, `Cut weights ${C.cuts().map((c) => c.weight).join(' · ')}, each rung tilted by 1 + luck × 0.06 × (rung − 2)`), h('span', { class: 'small muted' }, `Clarity weights ${C.clarities().map((c) => c.weight).join(' · ')}, widened by 1 + luck × 0.025 × distance²`)),
			note('Cut leans toward Perfect as luck rises; Clarity keeps its centre on Clear and widens both tails, so deep stones are stranger, not just better. Nothing anywhere raises a Cut on purpose: the wheel and the oven draw again from this table.', 'plain')),
			{ meta: 'odds at this luck' }));

		const depths = Array.from({ length: 28 }, (_, i) => i + 1);
		const g2 = h('div', { class: 'grid grid-2' });
		root.append(g2);
		g2.append(card('Cut odds by depth', lines({ series: cutN.map((n, i) => ({ key: n, label: n, color: CUT_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.normalize(Forge.cutWeights(Forge.luck(mine, d, bonus)))[i] * 100 })) })), width: 480, height: 200, format: (v) => `${fmt(v, 0)}%`, xFormat: (d) => `${d}`, endLabels: true, markers: false }), { meta: `${mine.name || ctx.settings.mine}, this source; luck caps at depth ${Forge.LUCK_DEPTH_CAP / Forge.LUCK_PER_DEPTH}` }));
		g2.append(card('Clarity odds by depth', lines({ series: clarN.map((n, i) => ({ key: n, label: n, color: CLARITY_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.normalize(Forge.clarityWeights(Forge.luck(mine, d, bonus)))[i] * 100 })) })), width: 480, height: 200, format: (v) => `${fmt(v, 0)}%`, xFormat: (d) => `${d}`, endLabels: false, markers: false }), { meta: 'both tails open as the party goes down' }));

		const g3 = h('div', { class: 'grid grid-3' });
		root.append(g3);
		const stonesJob = ctx.engine.run('stones', { mineKey: ctx.settings.mine, depth, bonus, samples: 8000 });
		const tierSlot = h('div'), valueSlot = h('div');
		g3.append(card('Grade', tierSlot, { meta: 'sampled stones · Peerless should stay under 1%' }));
		g3.append(card('Worth when appraised', valueSlot, { meta: 'gold; the scales pay half' }));
		whenReady(ctx, tierSlot, stonesJob, (r) => h('div', { class: 'col' },
			columns({ data: Stone.TIERS.map((t, i) => ({ label: Stone.TIER_NAMES[t], value: r.tiers[t] * 100, color: GRADE_COLORS[i], key: t, note: 'of stones' })), width: 300, height: 150, format: (v) => `${fmt(v, 1)}%`, valueLabels: 'all' }),
			histogram({ bins: r.scores, width: 300, height: 110, color: '#c9a43e', xLabel: 'grade score', mean: r.meanScore, xFormat: (v) => String(v) }),
			h('p', { class: 'tiny muted' }, `Score = carat/${Stone.caratMax()} × 45 + cut × 20 + clarity distance × 20 + inclusion rarity (≤15) + skill rarity × 8. Thresholds ${Object.entries(C.constant('grade_thresholds', {})).map(([k, v]) => `${C.title(k)} ${v}`).join(', ')}.`)));
		whenReady(ctx, valueSlot, stonesJob, (r) => h('div', { class: 'col' },
			histogram({ bins: r.values, width: 300, height: 150, color: '#e2b23a', xLabel: 'gold', mean: r.meanValue, xFormat: (v) => String(v) }),
			kv([['Mean worth', `${fmt(r.meanValue, 0)} gold`], ['Mean carat (sampled)', fmt(r.meanCarat, 2)], ['Sample', `${r.samples} stones`]]),
			h('p', { class: 'tiny muted' }, 'Worth = (10 + 4 × carat) × (1 + 0.25 × cut) × (1 + 0.3 × clarity distance) × skill rarity (1, 1.5, 2.5, 4, 8) × (1 + inclusion score / 20) each.')));
		const inclRows = C.keys('inclusions').map((k) => ({ key: k, label: C.inclusion(k).name, value: anyIncl(k) * 100, color: { PINPOINT: '#8a93a3', LENS: '#6f9fe0', FEATHER: '#4fae7a', FRACTURE: '#c96a2a', STAR: '#f0c95a' }[C.inclusion(k).class] || '#8a93a3', note: C.title(C.inclusion(k).class) })).sort((a, b) => b.value - a.value);
		g3.append(card('Inclusion in a stone', h('div', { class: 'col' }, bars({ rows: inclRows.slice(0, 14), format: (v) => `${fmt(v, 2)}%`, labelWidth: 100, height: 18, onSelect: (r) => ctx.navigate('inclusions', r.key) }), h('p', { class: 'tiny muted' }, `Chance any one stone at this luck carries it, over every clarity. Zoning of a stone’s own colour is never drawn; this ignores that exclusion. Full list on the Inclusions page.`)), { meta: 'top 14' }));

		const skillTable = Forge.skillTable(mine);
		const total = Object.values(skillTable).reduce((a, b) => a + b, 0) || 1;
		const byColor = C.SKILL_COLORS.map((ck) => ({ label: C.colorName(ck), value: Object.entries(skillTable).filter(([k]) => C.skill(k).color === ck).reduce((s, [, w]) => s + w, 0) / total, color: markColor(ck) })).filter((x) => x.value > 0);
		const byRarity = C.RARITIES.map((r) => ({ label: C.title(r), value: Object.entries(skillTable).filter(([k]) => C.skill(k).rarity === r).reduce((s, [, w]) => s + w, 0) / total, color: RARITY_COLORS[r] })).filter((x) => x.value > 0);
		const topSkills = Object.entries(skillTable).sort((a, b) => b[1] - a[1]);
		root.append(card('Which skill comes out of the rock', h('div', { class: 'grid grid-3' },
			h('div', { class: 'col' }, h('div', { class: 'section-title' }, 'By colour'), stacked({ segments: byColor }), h('p', { class: 'tiny muted' }, `Mine colour weights ${Object.entries(mine.color_weights || {}).map(([k, v]) => `${C.colorName(k)} ${v}`).join(' · ')}`)),
			h('div', { class: 'col' }, h('div', { class: 'section-title' }, 'By rarity'), stacked({ segments: byRarity }), h('p', { class: 'tiny muted' }, `Rarity weights ${C.RARITIES.map((r) => `${C.title(r)} ${C.rarityWeight(r)}`).join(' · ')}. Opals weigh nothing: only a hoard or a hundred-ore well offers one.`)),
			h('div', { class: 'col' }, h('div', { class: 'section-title' }, 'One skill'), h('div', { class: 'row tight' }, topSkills.slice(0, 12).map(([k, w]) => h('button', { type: 'button', class: 'chip', onClick: () => ctx.navigate('skills', k) }, gemImage(k, 18), `${C.skill(k).name} ${fmtPct(w / total, 1)}`))), h('p', { class: 'tiny muted' }, `A common skill is ${fmtPct(C.rarityWeight('COMMON') / total, 2)} of draws, a legendary ${fmtPct(C.rarityWeight('LEGENDARY') / total, 2)}.`)))));
	},
};
