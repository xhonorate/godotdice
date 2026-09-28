// Lapidaries: each character's setting, bowl, passive and Birthstone, with the odds of every
// Birthstone tier against that character's own dice.

import * as C from '../sim/content.js';
import * as Dice from '../sim/dice.js';
import * as Patterns from '../sim/patterns.js';
import * as Rules from '../sim/rules.js';
import { h, card, stat, table, fmt, fmtPct, note, kv, chip, toolbar, field, segmented } from '../ui.js';
import { heat } from '../charts.js';
import { birthstoneImage, dieImage } from '../gemart.js';
import { whenReady, socketRow, bowlSummary, faceRow } from './common.js';

const state = { rerolls: 2 };

export default {
	id: 'lapidaries', label: 'Lapidaries', blurb: 'Settings, bowls, passives and Birthstones', count: () => C.keys('characters').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/></svg>',
	render(root, route, ctx) {
		const keys = Object.keys(C.section('characters')).sort((a, b) => Number(C.character(a).unlock_order ?? 0) - Number(C.character(b).unlock_order ?? 0));
		root.append(toolbar(field('Rerolls spent chasing each tier', segmented([[0, '0'], [1, '1'], [2, '2'], [3, '3']], state.rerolls, (v) => { state.rerolls = Number(v); ctx.rerender(); }), 'Cadence gets one more from Study')));
		const grid = h('div', { class: 'grid grid-3' });
		root.append(grid);
		const compareRows = [];
		for (const key of keys) {
			const def = C.character(key);
			const bs = def.birthstone || {};
			const tiers = bs.tiers || [];
			const rerolls = state.rerolls + (def.passive?.kind === 'extra_reroll' ? Number(def.passive.amount || 1) : 0);
			const job = ctx.engine.run('triggerOdds', { bowl: def.dice, rerolls, samples: 6000, triggers: tiers.map((t) => t.trigger) });
			const summary = bowlSummary(def.dice);
			const body = h('div', { class: 'col' });
			body.append(h('div', { class: 'row', style: { alignItems: 'flex-start' } }, h('span', { class: 'pic hero' }, birthstoneImage(key, 110)),
				h('div', { class: 'detail-title', style: { gap: '4px' } }, h('h2', { style: { fontSize: '20px' } }, def.name, h('span', { class: 'muted', style: { fontWeight: 400 } }, def.title ? `, ${def.title}` : '')), h('p', { class: 'small text-2' }, def.text || ''),
					h('div', { class: 'row tight' }, def.starter ? chip('starter', { class: 'accent' }) : chip(`unlock ${def.unlock_order}`), chip(`${def.hp} health`), chip(`${(def.sockets || []).length} sockets`)))));
			body.append(h('div', { class: 'row', style: { justifyContent: 'space-between' } }, h('div', { class: 'col', style: { gap: '4px' } }, h('span', { class: 'tiny muted' }, 'Setting'), socketRow(def.sockets || [])),
				h('div', { class: 'col', style: { gap: '4px', alignItems: 'flex-end' } }, h('span', { class: 'tiny muted' }, `Bowl · mean ${fmt(summary.mean, 1)} · max ${summary.maxTotal}`), h('div', { class: 'row tight' }, (def.dice || []).map((k) => h('span', { title: `${C.die(k).name}: ${Dice.facesOf(C.die(k)).map((f) => f.value).join(' ')}` }, dieImage(k, 34)))))));
			body.append(h('div', { class: 'effect' }, h('span', {}, h('span', { class: 'eff-kind' }, def.passive?.name || 'Passive'), h('span', { class: 'eff-sub' }, def.passive?.text || C.title(def.passive?.kind || 'none'))), h('span', { class: 'eff-val small muted' }, 'passive')));
			body.append(h('div', { class: 'section-title' }, `${bs.name || 'Birthstone'} · ${C.title(bs.style || '')} cut`), h('p', { class: 'small text-2' }, bs.text || ''));
			const tierSlot = h('div');
			body.append(tierSlot);
			whenReady(ctx, tierSlot, job, (r) => table({ columns: [
				{ key: 'name', label: 'Tier', render: (t) => h('span', {}, h('b', {}, t.name), h('span', { class: 'cell-sub' }, t.words)) },
				{ key: 'effects', label: 'Does', render: (t) => h('span', { class: 'small text-2' }, t.effects) },
				{ key: 'fire', label: 'Fires', align: 'right', render: (t) => h('span', { class: 'ladder-cell', style: { background: heat(Math.min(1, t.fire * 1.2)), minWidth: '52px', color: t.fire > 0.55 ? '#141414' : 'var(--text)' } }, t.fire < 0.001 && t.fire > 0 ? '<0.1%' : fmtPct(t.fire, t.fire < 0.05 ? 1 : 0)) },
			], rows: tiers.map((t, i) => ({ key: t.name, name: t.name, words: Patterns.words(t.trigger, 0), effects: t.text || (t.effects || []).map((e) => Rules.effectWords(e)).join(' · '), fire: r.results[i].fireRate })), compact: true, rowKey: (t) => t.key }), { min: 80 });
			grid.append(card(null, body));
			compareRows.push({ key, name: def.name, hp: def.hp, sockets: def.sockets, mean: summary.mean, max: summary.maxTotal, dice: def.dice, passive: def.passive?.name || '' });
		}
		root.append(card('Side by side', h('div', { class: 'col' }, table({ columns: [
			{ key: 'name', label: 'Lapidary', render: (r) => h('span', { class: 'cell-name' }, birthstoneImage(r.key, 30), h('b', {}, r.name)) },
			{ key: 'hp', label: 'Health', align: 'right' },
			{ key: 'sockets', label: 'Setting', render: (r) => socketRow(r.sockets) },
			{ key: 'dice', label: 'Bowl', render: (r) => h('span', { class: 'small text-2' }, r.dice.map((k) => C.die(k).name).join(' · ')) },
			{ key: 'mean', label: 'Mean total', align: 'right', render: (r) => fmt(r.mean, 1) },
			{ key: 'max', label: 'Max total', align: 'right' },
			{ key: 'passive', label: 'Passive' },
		], rows: compareRows, compact: true, rowKey: (r) => r.key, onRowClick: (r) => { ctx.setSetting('bowl', r.dice.slice()); ctx.navigate('dice'); } }),
			note('Click a row to make that lapidary’s bowl the one every other page rolls. Birthstone tiers resolve at magnitude 1 whatever their 24 carats; the odds above spend the rerolls chasing each tier’s pattern.', 'plain'))));
	},
};
