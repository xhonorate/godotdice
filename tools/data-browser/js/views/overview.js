// The dashboard: where every skill sits on fire-rate against expected effect for the current
// bowl, the shape of the pack, and the ladders that do not do their job.

import * as C from '../sim/content.js';
import * as Patterns from '../sim/patterns.js';
import { h, card, stat, table, fmt, fmtPct, segmented, field, toolbar, note } from '../ui.js';
import { scatter, heatmap, SHAPES, bars } from '../charts.js';
import { gemImage, markColor, colorKeyMark } from '../gemart.js';
import { bowlControls, cutNames, whenReady, RARITY_COLORS, CUT_COLORS } from './common.js';

const state = { cut: 2, yKind: 'ev' };

export default {
	id: 'overview', label: 'Overview', blurb: 'The whole pack at a glance',
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></svg>',
	render(root, route, ctx) {
		const pack = C.getPack();
		const skills = C.keys('skills');
		const counts = [['Skill gems', skills.length, 'skills'], ['Inclusions', C.keys('inclusions').length, 'inclusions'], ['Dice', C.keys('dice').length, 'dice'], ['Creatures', C.keys('creatures').length, 'enemies'],
			['Lapidaries', C.keys('characters').length, 'lapidaries'], ['Oddities', C.keys('oddities').length, 'oddities'], ['Boons', C.keys('boons').length, 'oddities'], ['Mines', C.keys('mines').length, 'descent']];
		root.append(h('div', { class: 'stats', style: { gridTemplateColumns: `repeat(${counts.length}, minmax(0, 1fr))` } }, counts.map(([label, value, view]) => {
			const s = stat(label, String(value));
			s.classList.add('clickable'); s.style.cursor = 'pointer'; s.addEventListener('click', () => ctx.navigate(view));
			return s;
		})));

		root.append(toolbar(...bowlControls(ctx), field('Judged at Cut', segmented(cutNames().map((n, i) => [i, n]), state.cut, (v) => { state.cut = Number(v); ctx.rerender(); })),
			field('Vertical axis', segmented([['ev', 'Expected effect / turn'], ['evFired', 'Effect when it fires']], state.yKind, (v) => { state.yKind = v; ctx.rerender(); }))));

		const grid = h('div', { class: 'grid grid-main-side' });
		root.append(grid);
		const scatterSlot = h('div');
		grid.append(card('Every skill · fire rate against effect', scatterSlot, { meta: `${cutNames()[state.cut]} cut · 8-carat Clear stone · bowl ${ctx.settings.bowl.map((k) => C.die(k).name).join(' ')} · ${ctx.settings.rerolls} rerolls` }));
		const params = { bowl: ctx.settings.bowl, rerolls: ctx.settings.rerolls, samples: ctx.settings.samples, skills, stone: { carat: 8 }, context: { resonance: 3, pyrite: 60, block: 8, block_lost: 6, healed: 6, enemy_poison: 6 } };
		const promise = ctx.engine.run('skillStats', params);
		whenReady(ctx, scatterSlot, promise, (result) => {
			const points = skills.map((key) => {
				const def = C.skill(key);
				const s = result.skills[key];
				if (!s) return null;
				const c = s.cuts[state.cut];
				return { key, label: def.name, x: c.fireRate * 100, y: state.yKind === 'ev' ? c.ev : c.evFired, color: markColor(def.color), shape: SHAPES[def.color] || 'circle',
					note: `${C.colorName(def.color)} · ${C.title(def.rarity)} · ${s.headline.replace(/_/g, ' ')}`, size: ['LEGENDARY', 'MYTHIC', 'TRANSCENDENT'].includes(def.rarity) ? 6.5 : 5 };
			}).filter(Boolean);
			const wrap = h('div', { class: 'col' });
			wrap.append(scatter({ points, width: 760, height: 360, xLabel: 'fires on this % of hands', yLabel: state.yKind === 'ev' ? 'headline effect per turn' : 'headline effect when it fires', xMax: 100,
				xFormat: (v) => `${fmt(v, 0)}%`, yFormat: (v) => fmt(v, 1), onSelect: (p) => ctx.navigate('skills', p.key), labels: 'none' }));
			wrap.append(h('div', { class: 'legend' }, C.SKILL_COLORS.map((ck) => h('span', { class: 'legend-item' }, colorKeyMark(ck, 12), C.colorName(ck))),
				h('span', { class: 'legend-item muted' }, 'Larger marks are Legendary or Mythic. Click a mark to open the skill.')));
			wrap.append(note('The headline effect is the skill’s first effect (damage, block, heal, poison…), with carat magnitude and Flawless bonuses applied, summed over every fire in a turn. Rerolls are spent chasing each skill’s own trigger, so this is the ceiling a player building for that gem sees, not what a mixed rail gets.', 'plain'));
			return wrap;
		}, { min: 380 });

		const side = h('div', { class: 'col' });
		grid.append(side);
		const colorsList = C.SKILL_COLORS;
		const rarities = C.RARITIES;
		const values = colorsList.map((ck) => rarities.map((r) => skills.filter((k) => C.skill(k).color === ck && C.skill(k).rarity === r).length || null));
		side.append(card('Skills by colour and rarity', heatmap({ rows: colorsList.map((c) => C.colorName(c)), cols: rarities.map((r) => C.title(r).slice(0, 4)), values, format: (v) => String(v), rowLabelWidth: 70, cellHeight: 24 })));
		const kinds = {};
		for (const k of skills) { const kind = C.skill(k).trigger.kind; kinds[kind] = (kinds[kind] || 0) + 1; }
		const kindRows = Object.entries(kinds).sort((a, b) => b[1] - a[1]);
		side.append(card('Skills by trigger', h('div', { class: 'scroll-y', style: { maxHeight: '300px' } }, bars({ rows: kindRows.map(([k, n]) => ({ key: k, label: Patterns.KIND_NAMES[k] || k, value: n, note: 'skills', color: '#8a93a3' })), format: (v) => String(v), labelWidth: 120, height: 18 })), { meta: `${kindRows.length} kinds` }));

		const laddersSlot = h('div');
		root.append(card('Ladder health · rungs that change nothing for this bowl', laddersSlot, { meta: 'Every Cut step is meant to change how a stone behaves' }));
		whenReady(ctx, laddersSlot, promise, (result) => {
			const rows = [];
			for (const key of skills) {
				const s = result.skills[key];
				if (!s) continue;
				const fire = s.cuts.map((c) => c.fireRate);
				const ev = s.cuts.map((c) => c.ev);
				const flat = [];
				for (let i = 1; i < 5; i++) if (Math.abs(fire[i] - fire[i - 1]) < 0.005 && Math.abs(ev[i] - ev[i - 1]) < 0.02 * Math.max(1, ev[i])) flat.push(i);
				const never = fire.every((f) => f < 0.005);
				const always = fire.every((f) => f > 0.995);
				if (flat.length || never) rows.push({ key, name: C.skill(key).name, color: C.skill(key).color, kind: C.skill(key).trigger.kind, fire, ev, flat, never, always });
			}
			if (!rows.length) return note('Every skill’s five rungs behave differently against this bowl.', 'plain');
			const cutN = cutNames();
			return h('div', { class: 'table-wrap', style: { maxHeight: '320px' } }, table({
				columns: [
					{ key: 'name', label: 'Skill', render: (r) => h('span', { class: 'cell-name' }, gemImage(r.key, 28), h('span', {}, h('b', {}, r.name), h('span', { class: 'cell-sub' }, `${C.colorName(r.color)} · ${Patterns.KIND_NAMES[r.kind] || r.kind}`))) },
					{ key: 'fire', label: 'Fire rate by cut', render: (r) => h('span', { class: 'row tight' }, r.fire.map((f, i) => h('span', { class: 'chip', style: { borderColor: CUT_COLORS[i] } }, `${cutN[i].slice(0, 4)} ${fmtPct(f)}`))) },
					{ key: 'ev', label: 'Effect / turn', render: (r) => h('span', { class: 'mono small' }, r.ev.map((v) => fmt(v, 1)).join(' · ')) },
					{ key: 'flag', label: 'Finding', render: (r) => r.never ? h('span', { class: 'chip bad' }, 'never fires with this bowl') : h('span', { class: 'row tight' }, r.flat.map((i) => h('span', { class: 'chip' }, `${cutN[i - 1]} → ${cutN[i]} identical`))) },
				], rows, compact: true, onRowClick: (r) => ctx.navigate('skills', r.key), rowKey: (r) => r.key,
			}));
		});

		const c = pack.constants || {};
		root.append(h('div', { class: 'grid grid-4' },
			card('Run', h('dl', { class: 'kv' }, [['Mines', C.keys('mines').map((k) => `${C.mine(k).name} ${C.mine(k).endless ? '∞' : C.mine(k).depth}`).join(' · ')], ['Landing every', `${c.landing_every} depths`], ['Endless Warden every', c.endless_warden_every], ['Rerolls a turn', c.rerolls], ['Starting rail cap', c.starting_rail_cap]].flatMap(([k, v]) => [h('dt', {}, k), h('dd', {}, String(v ?? '—'))]))),
			card('Fights', h('dl', { class: 'kv' }, [['Enemy HP scale', `+${fmt((c.depth_hp_scale || 0) * 100, 0)}% a depth`], ['Enemy damage', `+1 every ${c.depth_damage_every} depths`], ['Enrage from turn', `${c.enrage_turn} (+${c.enrage_damage} a turn)`], ['Ore a fight', `${c.ore_per_fight} + depth`], ['Stone drop', `fight ${c.stone_drop_pct?.fight}% · elite ${c.stone_drop_pct?.elite}%`]].flatMap(([k, v]) => [h('dt', {}, k), h('dd', {}, String(v ?? '—'))]))),
			card('Stones', h('dl', { class: 'kv' }, [['Carat cap', c.carat_max], ['Grade tiers', Object.entries(c.grade_thresholds || {}).map(([k, v]) => `${C.title(k)} ${v}`).join(' · ')], ['Opal in a hoard', `${c.opal_hoard_pct}%`], ['Appraisal', `${c.appraise_ore_cost} ore, +${c.appraise_cost_step} a time`]].flatMap(([k, v]) => [h('dt', {}, k), h('dd', {}, String(v ?? '—'))]))),
			card('The lift and the fire', h('dl', { class: 'kv' }, [['Lift', `${c.lift_ore_per_depth} ore a depth a rider`], ['Rest heals', `${c.rest_pct}%`], ['Lantern', `${c.lantern_ore_cost} ore a floor`], ['Salvage dice', Object.entries(c.salvage_dice || {}).map(([k, v]) => `${C.title(k)} d${v}`).join(' · ')]].flatMap(([k, v]) => [h('dt', {}, k), h('dd', {}, String(v ?? '—'))])))));
	},
};
