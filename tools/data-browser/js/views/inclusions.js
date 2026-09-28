// Inclusions: the affixes frozen in a stone, their draw odds and what each does.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import * as Stone from '../sim/stone.js';
import * as Rules from '../sim/rules.js';
import { h, card, stat, table, fmt, fmtPct, note, kv, chip, sortRows, toggleSort, toolbar } from '../ui.js';
import { stacked } from '../charts.js';
import { inclusionImage, colorKeyMark } from '../gemart.js';
import { depthControls, clarityNames, rarityChip, CLARITY_COLORS } from './common.js';

const CLASS_COLORS = { PINPOINT: '#8a93a3', LENS: '#6f9fe0', FEATHER: '#4fae7a', FRACTURE: '#c96a2a', STAR: '#f0c95a' };
const CLASS_TEXT = { PINPOINT: 'Small pure riders: a little more of something when the gem fires.', LENS: 'Change what the gem reads: a low die as high, ones as wild, held dice twice, or another colour.',
	FEATHER: 'Chains between gems: the next gem judged better, a second firing, a copied inclusion, a carat to neighbours.', FRACTURE: 'Double-edged: a big upside paid for somewhere else.', STAR: 'Jackpot-tier: fires on every hand, fires twice, grows with depth, takes any colour.' };
const state = { sort: { key: 'share', dir: -1 } };

function modifierWords(m) {
	switch (m.kind) {
		case 'rider': return `rider: ${(m.effects || []).map((e) => Rules.effectWords(e)).join(', ')} (flat, never scaled)`;
		case 'per_die_damage': return `+${m.amount} damage per die read`;
		case 'magnitude': return `×${m.amount} magnitude`;
		case 'fizzle_on_value': return `fizzles if any die shows ${m.value}`;
		case 'hp_cost': return `lose ${m.amount} HP when it fires`;
		case 'carat': return `${m.amount > 0 ? '+' : ''}${m.amount} carats`;
		case 'carat_mult': return `carats ×${m.amount}`;
		case 'cut_step': return `${m.amount > 0 ? '+' : ''}${m.amount} Cut step`;
		case 'cut_override': return `Cut counts as ${C.cuts()[m.value]?.name || m.value}`;
		case 'locked': return 'cannot leave its socket during a run';
		case 'slotless': return 'takes no socket; rides one';
		case 'fragile': return 'cannot be sold or vaulted; shatters when the run ends';
		case 'lens': return `lens: ${String(m.mode).replace(/_/g, ' ')}`;
		case 'color_also': return `counts as ${C.colorName(m.color)} too`;
		case 'next_cut_step': return `next gem judged ${m.amount} Cut step better`;
		case 'retrigger_if_previous_fired': return 'fires again if the previous gem fired';
		case 'copy_previous_inclusion': return 'carries one inclusion of the previous gem';
		case 'adjacent_carat': return `neighbours of its colour gain ${m.amount} carat`;
		case 'always_fires': return 'fires on every hand';
		case 'fires_twice': return 'fires twice';
		case 'carat_per_depth': return `+${m.amount} carat per depth below ${m.below}`;
		case 'alexandrite': return 'takes the colour of its socket; Flawless line always on';
		case 'resonance_bonus': return `+${m.amount} Resonance when it fires`;
	}
	return `${m.kind} ${JSON.stringify(Object.fromEntries(Object.entries(m).filter(([k]) => k !== 'kind' && k !== 'inclusion')))}`;
}

export default {
	id: 'inclusions', label: 'Inclusions', blurb: 'What can be frozen inside a stone', count: () => C.keys('inclusions').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><path d="m8 9 3 3-2 4M14 8l2 3-3 3"/></svg>',
	render(root, route, ctx) {
		const mine = C.mine(ctx.settings.mine);
		const q = Forge.luck(mine, ctx.settings.depth, 0);
		const clarP = Forge.normalize(Forge.clarityWeights(q));
		const clarN = clarityNames();
		const byClarity = clarN.map((_, k) => Forge.inclusionOdds(Stone.inclusionSlots(k), mine, ''));
		const weights = Forge.inclusionWeights(mine, '');
		const weightTotal = Object.values(weights).reduce((a, b) => a + b, 0) || 1;
		const keys = C.keys('inclusions');
		const rows = keys.map((k) => {
			const d = C.inclusion(k);
			const any = clarP.reduce((s, p, i) => s + p * (byClarity[i][k] || 0), 0);
			return { key: k, name: d.name, class: d.class, rarity: d.rarity, weight: weights[k] ?? 0, share: (weights[k] ?? 0) / weightTotal, any, one: byClarity[C.clarityIndex('INCLUDED')][k] || 0, three: byClarity[0][k] || 0, mods: d.modifiers || [], text: d.text || '', score: Stone.INCLUSION_SCORE[d.rarity] ?? 2 };
		});
		const active = route.key && C.inclusion(route.key).name ? route.key : rows.slice().sort((a, b) => b.share - a.share)[0].key;
		root.append(toolbar(...depthControls(ctx, { showParty: false })));
		const classes = Object.keys(CLASS_COLORS);
		root.append(h('div', { class: 'grid grid-2' },
			card('Share of one draw, by class', h('div', { class: 'col' }, stacked({ segments: classes.map((c) => ({ label: C.title(c), value: rows.filter((r) => r.class === c).reduce((s, r) => s + r.share, 0), color: CLASS_COLORS[c] })) }),
				h('p', { class: 'tiny muted' }, `Class default weights: ${Object.entries(Forge.DEFAULT_CLASS_WEIGHTS).map(([k, v]) => `${C.title(k)} ${v}`).join(' · ')}. An inclusion may write its own weight (Void: 0.25). A stone never draws the same inclusion twice, nor a Zoning of its own colour.`))),
			card(`Slots by clarity at luck ${fmt(q, 1)}`, h('div', { class: 'col' }, stacked({ segments: clarN.map((n, i) => ({ label: `${n} (${Stone.inclusionSlots(i)})`, value: clarP[i], color: CLARITY_COLORS[i] })) }),
				h('div', { class: 'stats' }, stat('Any inclusion', fmtPct(clarP.slice(0, C.clearIndex()).reduce((a, b) => a + b, 0), 1), 'in a stone at this depth'), stat('Two or three', fmtPct(clarP[0] + clarP[1], 1), 'Etched or Intricate'), stat('A Star', fmtPct(rows.filter((r) => r.class === 'STAR').reduce((s, r) => s + r.any, 0), 2), 'in any one stone'))))));
		const grid = h('div', { class: 'grid grid-main-side' });
		root.append(grid);
		const colsDef = [
			{ key: 'name', label: 'Inclusion', sort: (r) => r.name, render: (r) => h('span', { class: 'cell-name' }, inclusionImage(r.key, 34), h('span', {}, h('b', {}, r.name), h('span', { class: 'cell-sub two-line' }, r.text))) },
			{ key: 'class', label: 'Class', sort: (r) => r.class, render: (r) => chip(C.title(r.class), { color: CLASS_COLORS[r.class] }) },
			{ key: 'rarity', label: 'Rarity', sort: (r) => C.RARITIES.indexOf(r.rarity), render: (r) => rarityChip(r.rarity) },
			{ key: 'weight', label: 'Weight', align: 'right', sort: (r) => r.weight, render: (r) => fmt(r.weight, 2) },
			{ key: 'share', label: 'One draw', align: 'right', sort: (r) => r.share, title: 'Share of a single slot draw', render: (r) => fmtPct(r.share, 1) },
			{ key: 'any', label: 'In a stone', align: 'right', sort: (r) => r.any, title: 'Chance any one stone at this depth carries it', render: (r) => fmtPct(r.any, 2) },
			{ key: 'three', label: 'Intricate', align: 'right', sort: (r) => r.three, title: 'Chance an Intricate stone (3 slots) carries it', render: (r) => fmtPct(r.three, 1) },
		];
		const sorted = sortRows(rows, colsDef, state.sort);
		grid.append(h('div', { class: 'card' }, h('div', { class: 'table-wrap', style: { maxHeight: 'calc(100vh - 380px)' } }, table({ columns: colsDef, rows: sorted, sort: state.sort, onSort: (k) => { state.sort = toggleSort(state.sort, k, k === 'name' || k === 'class' ? 1 : -1); ctx.rerender(); }, selectedKey: active, rowKey: (r) => r.key, onRowClick: (r) => ctx.navigate('inclusions', r.key), compact: true }))));
		const r = rows.find((x) => x.key === active);
		const d = C.inclusion(active);
		grid.append(card(null, h('div', { class: 'col' },
			h('div', { class: 'row' }, h('span', { class: 'pic hero' }, inclusionImage(active, 120)), h('div', { class: 'detail-title' }, h('div', { class: 'row tight' }, chip(C.title(r.class), { color: CLASS_COLORS[r.class] }), rarityChip(r.rarity)), h('h2', {}, r.name), h('p', { class: 'lede' }, r.text))),
			h('div', { class: 'section-title' }, 'Modifiers'),
			h('div', { class: 'effect-list' }, r.mods.map((m) => h('div', { class: 'effect' }, h('span', {}, h('span', { class: 'eff-kind' }, modifierWords(m)), h('span', { class: 'eff-sub' }, m.kind.replace(/_/g, ' ')))))),
			h('div', { class: 'section-title' }, 'Odds and scoring'),
			kv([['One slot draw', fmtPct(r.share, 2)], ['In any stone here', fmtPct(r.any, 2)], ['In an Included stone', fmtPct(r.one, 1)], ['In an Intricate stone', fmtPct(r.three, 1)], ['Grade points', `${r.score} (of 15 for inclusions)`], ['Worth', `×${fmt(1 + r.score / 20, 2)}`]]),
			note(CLASS_TEXT[r.class] || '', 'plain'),
			d.modifiers && d.modifiers.some((m) => m.kind === 'color_also') ? h('p', { class: 'small text-2' }, colorKeyMark(Forge.zoningColor(d)), `Never grows in a ${C.colorName(Forge.zoningColor(d)).toLowerCase()} stone.`) : null)));
	},
};
