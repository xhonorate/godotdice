// Oddities, boons and the pack's small tables.

import * as C from '../sim/content.js';
import { h, card, table, fmt, chip, note, kv } from '../ui.js';
import { columns } from '../charts.js';
import { colorKeyMark, CUTS, SHAPE_NAMES, silhouette } from '../gemart.js';
import { tabs, rarityChip, RARITY_COLORS } from './common.js';

const state = { tab: 'oddities' };
const NEEDS = { stone: 'a stone', two_stones: 'two stones', inclusion: 'a stone and one of its inclusions', raw_stone: 'a raw stone', die: 'a die', die_face: 'a die and a face', die_face_pair: 'two faces of one die', die_engraving: 'a die and an engraving', pattern: 'a pattern', copy_inclusion: 'an inclusion and a stone with room', ore: 'pyrite', socket: 'a socketed stone', pick: 'a choice of three' };

function actionChips(action) {
	if (!action) return [];
	return Object.entries(action).filter(([k]) => k !== 'kind').map(([k, v]) => chip(`${k.replace(/_/g, ' ')} ${Array.isArray(v) ? v.join(', ') : v}${/pct|shatter|success|crack|survive|three|one/.test(k) ? '%' : ''}`));
}

export default {
	id: 'oddities', label: 'Oddities & boons', blurb: 'Gambles in the rock, stakes at the top, pack tables', count: () => C.keys('oddities').length + C.keys('boons').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3a9 9 0 1 0 9 9"/><path d="M12 8v4l3 2"/><path d="M19 3v4h-4"/></svg>',
	render(root, route, ctx) {
		if (route.params.tab) state.tab = route.params.tab;
		root.append(tabs([['oddities', 'Oddities'], ['boons', 'Stakes & boons'], ['tables', 'Pack tables']], state.tab, (t) => { state.tab = t; ctx.rerender(); }));
		if (state.tab === 'oddities') {
			const grid = h('div', { class: 'grid grid-3' });
			for (const key of C.keys('oddities')) {
				const d = C.oddity(key);
				grid.append(card(d.name || C.title(key), h('div', { class: 'col' }, h('p', { class: 'small text-2' }, d.text || ''),
					h('div', { class: 'effect-list' }, (d.choices || []).filter((c) => c.action && c.action.kind !== 'none').map((c) => h('div', { class: 'effect', style: { gridTemplateColumns: '1fr' } }, h('span', {}, h('span', { class: 'eff-kind' }, c.label || c.id), c.needs ? h('span', { class: 'muted small' }, ` · needs ${NEEDS[c.needs] || c.needs}`) : null, h('span', { class: 'eff-sub' }, c.text || ''), h('div', { class: 'row tight', style: { marginTop: '4px' } }, chip(String(c.action.kind).replace(/_/g, ' '), { class: 'accent' }), ...actionChips(c.action)))))))));
			}
			root.append(grid);
			return;
		}
		if (state.tab === 'boons') {
			const groups = ['stone', 'kit', 'cost', 'reward'];
			const titles = { stone: 'Stone stakes', kit: 'Kit stakes', cost: 'Costs (the Grubstake asks for one)', reward: 'Rewards (what a cost buys)' };
			root.append(note('The Grubstake: before a run the party stakes a boon or two and may take a cost for a reward. Everything here lasts the run.', 'plain'));
			const grid = h('div', { class: 'grid grid-2' });
			for (const g of groups) {
				const rows = C.keys('boons').filter((k) => C.boon(k).group === g).map((k) => ({ key: k, ...C.boon(k) }));
				grid.append(card(titles[g] || C.title(g), table({ columns: [
					{ key: 'name', label: 'Boon', render: (r) => h('span', {}, h('b', {}, r.name), h('span', { class: 'cell-sub' }, r.text)) },
					{ key: 'needs', label: 'Needs', render: (r) => r.needs ? chip(NEEDS[r.needs] || r.needs) : h('span', { class: 'muted' }, '—') },
					{ key: 'effects', label: 'Effect', render: (r) => h('span', { class: 'row tight' }, (r.effects || []).map((e) => chip(`${e.kind.replace(/_/g, ' ')} ${Object.entries(e).filter(([k]) => k !== 'kind').map(([k, v]) => `${k.replace(/_/g, ' ')} ${v}`).join(', ')}`))) },
				], rows, compact: true, rowKey: (r) => r.key }), { meta: `${rows.length}` }));
			}
			root.append(grid);
			return;
		}
		const pack = C.getPack();
		root.append(h('div', { class: 'grid grid-3' },
			card('Colours and their cuts', table({ columns: [
				{ key: 'name', label: 'Colour', render: (r) => h('span', { class: 'row tight' }, colorKeyMark(r.key, 16), r.name) },
				{ key: 'domain', label: 'Domain', render: (r) => C.title(r.domain) },
				{ key: 'cut', label: 'Cut', render: (r) => h('span', { class: 'row tight' }, silhouette(r.key, 22), SHAPE_NAMES[r.cut] || r.cut) },
				{ key: 'hue', label: 'Hue', render: (r) => h('span', { class: 'row tight' }, h('i', { class: 'dot', style: { background: `#${r.hue}` } }), h('code', {}, `#${r.hue}`)) },
				{ key: 'skills', label: 'Skills', align: 'right' },
			], rows: Object.entries(pack.colors || {}).map(([key, c]) => ({ key, ...c, skills: C.keys('skills').filter((k) => C.skill(k).color === key).length })), compact: true, rowKey: (r) => r.key })),
			card('Rarity', h('div', { class: 'col' }, columns({ data: C.RARITIES.map((r) => ({ label: C.title(r), value: C.rarityWeight(r), color: RARITY_COLORS[r], key: r, note: 'draw weight' })), width: 320, height: 150, format: (v) => String(v), valueLabels: 'all' }),
				table({ columns: [{ key: 'name', label: 'Rarity', render: (r) => rarityChip(r.key) }, { key: 'weight', label: 'Weight', align: 'right' }, { key: 'score', label: 'Grade points', align: 'right' }, { key: 'value', label: 'Worth ×', align: 'right' }], rows: C.RARITIES.map((r) => ({ key: r, weight: C.rarityWeight(r), score: C.rarityScore(r), value: { COMMON: 1, UNCOMMON: 1.5, RARE: 2.5, LEGENDARY: 4, MYTHIC: 8 }[r] })), compact: true, rowKey: (r) => r.key }))),
			card('Engravings', table({ columns: [{ key: 'name', label: 'Engraving', render: (r) => h('b', {}, r.name) }, { key: 'rarity', label: 'Rarity', render: (r) => rarityChip(r.rarity) }, { key: 'text', label: 'Effect' }], rows: C.keys('engravings').map((k) => ({ key: k, ...C.engraving(k) })), compact: true, rowKey: (r) => r.key }))));
		root.append(h('div', { class: 'grid grid-2' },
			card('Cut ladder', table({ columns: [{ key: 'name', label: 'Cut' }, { key: 'weight', label: 'Base weight', align: 'right' }, { key: 'index', label: 'Step', align: 'right' }], rows: C.cuts().map((c, i) => ({ key: c.key, ...c, index: i })), compact: true, rowKey: (r) => r.key })),
			card('Clarity ladder', table({ columns: [{ key: 'name', label: 'Clarity' }, { key: 'inclusions', label: 'Slots', align: 'right' }, { key: 'weight', label: 'Base weight', align: 'right' }, { key: 'bonus', label: 'Bonus', render: (r) => [r.resonance_mult ? `×${r.resonance_mult} Resonance` : '', r.magnitude ? `×${r.magnitude} magnitude` : '', r.flawless_line ? 'the Flawless line' : ''].filter(Boolean).join(' · ') || '—' }], rows: C.clarities().map((c) => ({ key: c.key, ...c })), compact: true, rowKey: (r) => r.key }))));
	},
};
