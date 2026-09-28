// The Descent: the shaft's shape, what each depth's chambers are likely to be, and what the
// mine charges and pays as the party goes down.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import { h, card, stat, table, fmt, fmtPct, toolbar, note, kv } from '../ui.js';
import { lines, stacked, columns } from '../charts.js';
import { depthControls, CHAMBER_COLORS, CUT_COLORS } from './common.js';

const PARTY_COLORS = ['#f0c95a', '#c9a43e', '#a38434', '#7d652a'];

export default {
	id: 'descent', label: 'The Descent', blurb: 'Chambers, landings, Wardens and costs by depth', count: () => C.keys('mines').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3v18M12 21l-4-4M12 21l4-4"/><path d="M5 7h14M7 12h10"/></svg>',
	render(root, route, ctx) {
		const mine = C.mine(ctx.settings.mine);
		const runDepth = Number(C.constant('run_depth', 24));
		const depths = Array.from({ length: runDepth + 8 }, (_, i) => i + 1);
		root.append(toolbar(...depthControls(ctx)));
		const shaft = h('div', { class: 'shaft', style: { gridTemplateColumns: `repeat(${depths.length}, 1fr)` } }, depths.map((d) => {
			const landing = Forge.isLanding(d), warden = Forge.isWarden(d);
			const band = Forge.bandFor(mine, d);
			return h('div', { class: `shaft-cell${landing ? ' landing' : ''}${warden ? ' warden' : ''}`, title: `${d}: ${warden ? 'Warden hall' : landing ? 'landing' : 'chambers'} · luck ${fmt(Forge.luck(mine, d), 1)} · band from ${band.from_depth ?? 1}` },
				h('i', { style: { background: warden ? 'var(--accent)' : landing ? 'var(--surface-3)' : d > runDepth ? '#3a2a44' : `hsl(${220 - (d / runDepth) * 40} 25% ${34 - (d / runDepth) * 14}%)`, opacity: d === ctx.settings.depth ? 1 : 0.85, outline: d === ctx.settings.depth ? '2px solid var(--text)' : null } }), h('span', {}, String(d)));
		}));
		root.append(card('The shaft', h('div', { class: 'col' }, shaft, h('div', { class: 'legend' }, h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: 'var(--accent)' } }), 'Warden hall (keeps its cage; a hoard of three raw stones, the last an opal)'), h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: 'var(--surface-3)', outline: '2px solid var(--text-2)' } }), 'Landing: fire, workbench, wheel, lift'), h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: '#3a2a44' } }), `Endless, below ${runDepth}; a Warden every ${C.constant('endless_warden_every', 8)}`)),
			note(`A stretch runs between landings: its chambers fan out two mouths wide at the top and a mouth wider each depth, every chamber leading to the two nearest below. Each stretch holds at least one merchant (the second depth trades a fight or vein for a stall if none was drawn) and a smithy or carver on its last depth. At most one dark mouth a depth (22% each).`, 'plain')), { meta: `${mine.name || ctx.settings.mine} · landings every ${C.constant('landing_every', 4)}` }));

		const g = h('div', { class: 'grid grid-2' });
		root.append(g);
		const chamberRows = [[1, 'Depth 1 (no elite, no merchant)'], [2, 'Depth 2 (no elite)'], [3, 'Depth 3 and below']].map(([d, label]) => { const t = Forge.chamberTable(mine, d); const total = Object.values(t).reduce((a, b) => a + b, 0) || 1; return { label, segments: Object.entries(t).map(([k, w]) => ({ label: C.title(k), value: w / total, color: CHAMBER_COLORS[k] || '#888' })) }; });
		g.append(card('What a mouth leads to', h('div', { class: 'col' }, chamberRows.map((r) => h('div', { class: 'col', style: { gap: '4px' } }, h('span', { class: 'small text-2' }, r.label), stacked({ segments: r.segments, legend: false }))),
			h('div', { class: 'legend' }, Object.entries(Forge.chamberTable(mine, 3)).map(([k, w]) => h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: CHAMBER_COLORS[k] } }), `${C.title(k)} ${w}`))),
			note(`Weights before the once-a-depth rule: an elite, an oddity, a merchant, a smithy, a carver or a well drawn on a depth is removed from the table for the rest of that depth's mouths. A vein is a motherlode ${mine.motherlode_pct ?? 3}% of the time.`, 'plain')), { meta: 'per-draw chamber weights' }));
		const kinds = [['fight', 'a fight'], ['elite', 'an elite'], ['warden', 'a Warden']];
		g.append(card('Ore paid for a won fight', lines({ series: kinds.map(([k, label], i) => ({ key: k, label, color: ['#c0463c', '#8b2f2a', '#e2b23a'][i], points: depths.map((d) => ({ x: d, y: Forge.fightOre(d, k) })) })), width: 480, height: 190, xFormat: (d) => String(d), format: (v) => fmt(v, 0), markers: false }), { meta: `${C.constant('ore_per_fight', 6)} + depth, ×2 elite, ×3 Warden, before Gold gems` }));
		const g2 = h('div', { class: 'grid grid-3' });
		root.append(g2);
		g2.append(card('The winch', lines({ series: [1, 2, 3, 4].map((p, i) => ({ key: p, label: `${p} riding`, color: PARTY_COLORS[i], points: depths.filter((d) => d <= runDepth).map((d) => ({ x: d, y: Forge.liftCost(d, p) })) })), width: 320, height: 180, xFormat: (d) => String(d), format: (v) => fmt(v, 0), markers: false }), { meta: `${C.constant('lift_ore_per_depth', 15)} ore a depth a rider, from the party's pool` }));
		g2.append(card('Pressure on the party', lines({ series: [{ key: 'hp', label: 'enemy HP ×', color: '#e0473c', points: depths.map((d) => ({ x: d, y: 1 + Number(C.constant('depth_hp_scale', 0.05)) * Math.max(0, d - 1) })) }, { key: 'luck', label: 'stone luck', color: '#f0c95a', shape: 'hexagon', points: depths.map((d) => ({ x: d, y: Forge.luck(mine, d) })) }, { key: 'dmg', label: 'enemy damage bonus (1 die)', color: '#8b5fd6', shape: 'drop', points: depths.map((d) => ({ x: d, y: Math.trunc(d / Number(C.constant('depth_damage_every', 4))) })) }], width: 320, height: 180, xFormat: (d) => String(d), format: (v) => fmt(v, 1), markers: false }), { meta: 'health scales every depth; luck caps at 10' }));
		const c = C.getPack().constants || {};
		g2.append(card('Landings and the bench', kv([['Rest', `heals ${c.rest_pct}% of health`], ['Appraisal at a landing', 'one, free'], ['Appraisal at a stall', `${c.appraise_ore_cost} ore, +${c.appraise_cost_step} each time at the same stall`], ['Appraisal at home', `max(${c.appraise_gold_min}, worth × ${c.appraise_gold_mult}) gold`], ['Lantern', `${c.lantern_ore_cost} ore lights a floor`], ['Merchant', '3 appraised stones, scales that pay half worth'], ['Motherlode', `3 raw stones; ${mine.motherlode_pct ?? 3}% of veins`], ['Stone drops', `fight ${c.stone_drop_pct?.fight}% · elite ${c.stone_drop_pct?.elite}% (+4 luck) · vein ${c.stone_drop_pct?.vein}%`], ['Salvage dice', Object.entries(c.salvage_dice || {}).map(([k, v]) => `${C.title(k)} d${v}`).join(' · ')]])));
		root.append(card(`${mine.name || ctx.settings.mine}`, h('div', { class: 'grid grid-3' }, kv([['Luck', String(Forge.mineLuck(mine))], ['Starter', mine.starter ? 'yes' : 'no'], ['Wardens', (mine.wardens || []).map((k) => C.creature(k).name).join(', ')], ['Bands from', (mine.bands || []).map((b) => b.from_depth).join(', ')]]),
			kv([['Dice in the rock', (mine.dice || []).length ? mine.dice.join(', ') : 'all'], ['Skills in the rock', (mine.skills || []).length ? mine.skills.join(', ') : 'all'], ['Inclusions in the rock', (mine.inclusions || []).length ? mine.inclusions.join(', ') : 'all'], ['Engraved die', `${fmt(Forge.engravingChance(mine, ctx.settings.depth), 1)}% at depth ${ctx.settings.depth}`]]),
			h('p', { class: 'small text-2' }, mine.text || ''))));
	},
};
