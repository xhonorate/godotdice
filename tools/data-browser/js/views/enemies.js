// Creatures: what each one does to the party at a depth, and what a fight at that depth holds.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import * as Patterns from '../sim/patterns.js';
import * as Rules from '../sim/rules.js';
import { h, card, stat, table, fmt, fmtPct, segmented, field, toolbar, note, kv, chip } from '../ui.js';
import { columns, lines, histogram, bars, heatmap } from '../charts.js';
import { creatureImage, dieImage } from '../gemart.js';
import { depthControls, whenReady, tabs, faceRow } from './common.js';

const state = { tab: 'creatures', phase: 0, elite: false, turn: 1 };
const PARTY_COLORS = ['#f0c95a', '#c9a43e', '#a38434', '#7d652a'];

function triggerWords(move) {
	const t = move.trigger || { kind: 'always' };
	const n = Patterns.rung(t, 0);
	switch (t.kind || 'always') {
		case 'always': return 'Every die';
		case 'odd': return 'An odd roll';
		case 'even': return 'An even roll';
		case 'at_least': return `A roll of ${n}+`;
		case 'at_most': return `A roll of ${n} or less`;
		case 'value': return `A roll of ${(t.values || []).join('/')}`;
		case 'crowns': return 'Its top face';
		case 'pair': case 'triple': case 'quad': case 'quint': return `${Patterns.KIND_NAMES[t.kind]}${n > 1 ? ` of ${n}+` : ''} · once a turn`;
		case 'straight': return `${n} in sequence · once a turn`;
		case 'all_odd': return `All dice odd (${n}+) · once a turn`;
		case 'all_even': return `All dice even (${n}+) · once a turn`;
	}
	return Patterns.words(t, 0);
}

export default {
	id: 'enemies', label: 'Enemies', blurb: 'Creatures, their turns and encounters', count: () => C.keys('creatures').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3 7 9l5 12 5-12Z"/><path d="M7 9h10M4 13l3-4M20 13l-3-4"/></svg>',
	render(root, route, ctx) {
		if (route.params.tab) state.tab = route.params.tab;
		root.append(tabs([['creatures', 'Creatures'], ['encounters', 'Encounters'], ['bands', 'Depth bands']], state.tab, (t) => { state.tab = t; ctx.rerender(); }));
		if (state.tab === 'creatures') creaturesPage(root, route, ctx);
		if (state.tab === 'encounters') encountersPage(root, ctx);
		if (state.tab === 'bands') bandsPage(root, ctx);
	},
};

function creaturesPage(root, route, ctx) {
	const mine = C.mine(ctx.settings.mine);
	const keys = C.keys('creatures').sort((a, b) => Number(C.creature(a).threat) - Number(C.creature(b).threat) || a.localeCompare(b));
	const active = route.key && C.creature(route.key).name ? route.key : keys[0];
	const def = C.creature(active);
	const depth = ctx.settings.depth, party = ctx.settings.party;
	root.append(toolbar(...depthControls(ctx), field('Turn', segmented([[1, '1'], [4, '4'], [7, '7'], [9, '9']], state.turn, (v) => { state.turn = Number(v); ctx.rerender(); }), `Enrage from turn ${C.constant('enrage_turn', 7)}`),
		(def.phases || []).length ? field('Phase', segmented([[0, 'Opening'], ...(def.phases || []).map((p, i) => [i + 1, `Below ${p.below_hp_pct}% HP`])], state.phase, (v) => { state.phase = Number(v); ctx.rerender(); })) : null));
	const grid = h('div', { class: 'grid grid-side' });
	root.append(grid);
	const list = h('div', { class: 'list' }, keys.map((k) => { const d = C.creature(k); return h('button', { type: 'button', class: `list-item${k === active ? ' is-active' : ''}`, onClick: () => ctx.navigate('enemies', k) }, creatureImage(k, 40), h('span', {}, h('span', { class: 'li-name' }, d.name), h('span', { class: 'li-sub' }, `${d.warden ? 'Warden · ' : ''}threat ${d.threat} · ${(d.dice || []).join(' ')}`)), h('span', { class: 'li-right' }, `${Forge.creatureHp(d, depth, party, mine)} hp`)); }));
	grid.append(h('section', { class: 'card list-panel', style: { maxHeight: 'calc(100vh - 230px)' } }, list, h('div', { class: 'list-count' }, `${keys.length} creatures · HP at depth ${depth}, party ${party}`)));
	const phase = Math.min(state.phase, (def.phases || []).length);
	const moves = phase > 0 ? def.phases[phase - 1].moves : def.moves;
	const detail = h('div', { class: 'col' });
	grid.append(detail);
	const hp = Forge.creatureHp(def, depth, party, mine);
	detail.append(h('div', { class: 'card' }, h('div', { class: 'card-body' }, h('div', { class: 'detail-head' }, h('span', { class: 'pic hero' }, creatureImage(active, 170)),
		h('div', { class: 'detail-title' }, h('div', { class: 'row tight' }, def.warden ? chip('Warden', { class: 'accent' }) : chip('Creature'), chip(`threat ${def.threat}`), def.gimmick ? chip(`trick: ${C.title(def.gimmick)}`) : null, chip(`${def.ward ?? (def.warden ? 1 : 0)} Ward`)),
			h('h2', {}, def.name), h('p', { class: 'lede' }, def.text || ''), h('div', { class: 'row tight' }, h('span', { class: 'small muted' }, 'Rolls, in order:'), ...(def.dice || []).map((k) => h('span', { class: 'row tight' }, dieImage(k, 30), h('span', { class: 'small text-2' }, k)))))))));
	const job = ctx.engine.run('creatureTurn', { key: active, depth, party, phase, turn: state.turn, samples: 6000 });
	const statsSlot = h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(6, minmax(0,1fr))' } });
	detail.append(statsSlot);
	whenReady(ctx, statsSlot, job, (r) => h('div', { style: { display: 'contents' } }, stat('Health', String(r.hp), `base ${def.hp} × depth × party`, { class: 'accent' }), stat('Block', String(def.block ?? 0), 'to start'), stat('Damage a turn', fmt(r.meanDamage, 2), 'to every player, before block'),
		stat('Damage bonus', `+${r.damageBonus}`, `depth ÷ ${C.constant('depth_damage_every', 4)}, per die`), stat('Enrage', r.enrage ? `+${r.enrage}` : '—', `from turn ${C.constant('enrage_turn', 7)}`), stat('Threat', String(def.threat), 'against the encounter budget')));
	const g = h('div', { class: 'grid grid-2' });
	detail.append(g);
	const movesSlot = h('div'), histSlot = h('div');
	g.append(card(`Moves · ${phase > 0 ? `below ${def.phases[phase - 1].below_hp_pct}% HP` : 'opening phase'}`, movesSlot, { meta: 'fires per turn, sampled' }));
	g.append(card('Damage in one turn', histSlot, { meta: 'to every living player, before block' }));
	whenReady(ctx, movesSlot, job, (r) => h('div', { class: 'moves' }, moves.map((m, i) => { const s = r.moves[i]; return h('div', { class: 'move' }, h('span', {}, h('b', {}, m.name), m.dramatic ? chip('dramatic', { class: 'accent' }) : null, h('div', { class: 'move-trig' }, triggerWords(m)), h('div', { class: 'move-eff' }, (m.effects || []).map((e) => Rules.effectWords(e)).join(' · '))),
		h('span', { class: 'right' }, h('div', { class: 'num' }, `${fmt(s.fireRate, 2)}× a turn`), h('div', { class: 'tiny muted' }, s.meanDamage ? `${fmt(s.meanDamage, 1)} damage` : Object.entries(s.effects).map(([k, v]) => `${fmt(v, 1)} ${k.replace(/_/g, ' ')}`).join(' · ')))); })));
	whenReady(ctx, histSlot, job, (r) => histogram({ bins: r.damageHist, width: 420, height: 190, color: '#e0473c', mean: r.meanDamage, xLabel: 'damage', xFormat: (v) => String(v) }));
	const depths = Array.from({ length: 28 }, (_, i) => i + 1);
	detail.append(h('div', { class: 'grid grid-2' },
		card('Health by depth', lines({ series: [1, 2, 3, 4].map((p, i) => ({ key: p, label: `party of ${p}`, color: PARTY_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.creatureHp(def, d, p, mine) })) })), width: 420, height: 180, xFormat: (d) => String(d), format: (v) => fmt(v, 0), markers: false }), { meta: `+${fmt(Number(C.constant('depth_hp_scale', 0.05)) * 100, 0)}% a depth, +15% a player` }),
		card('Phases and dice', h('div', { class: 'col' }, kv([['Phases', (def.phases || []).length ? def.phases.map((p) => `below ${p.below_hp_pct}% HP: ${p.moves.map((m) => m.name).join(', ')}`).join(' · ') : 'none'], ['Dice', (def.dice || []).map((k) => `${k} ${faceRowText(k)}`).join(' · ')], ['Trick', def.gimmick ? C.title(def.gimmick) : 'none']]),
			...(def.dice || []).map((k) => h('div', { class: 'row' }, h('span', { class: 'small muted', style: { width: '40px' } }, k), faceRow(C.die(k)))),
			note('Ordinary moves are judged against each die as it lands; combination moves against every die shown so far and fire once a turn. All-odd and all-even wait for the last die.', 'plain')))));
}
const faceRowText = (k) => `(${(C.die(k).faces || []).length} faces)`;

function encountersPage(root, ctx) {
	const depth = ctx.settings.depth, party = ctx.settings.party;
	const mine = C.mine(ctx.settings.mine);
	root.append(toolbar(...depthControls(ctx), field('Kind', segmented([[false, 'Fight'], [true, 'Elite']], state.elite, (v) => { state.elite = v === 'true' || v === true; ctx.rerender(); }))));
	const job = ctx.engine.run('encounters', { mineKey: ctx.settings.mine, depth, party, elite: state.elite, samples: 5000 });
	const band = Forge.bandFor(mine, depth);
	const total = Object.values(band.creatures || {}).reduce((a, b) => a + Number(b), 0) || 1;
	const statsSlot = h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(6, minmax(0,1fr))' } });
	root.append(statsSlot);
	whenReady(ctx, statsSlot, job, (r) => h('div', { style: { display: 'contents' } }, stat('Threat budget', fmt(r.budget, 1), `(3 + 0.6 × depth) × (0.55 + 0.45 × party)${state.elite ? ' × 1.5' : ''}`, { class: 'accent' }), stat('Creatures', fmt(r.counts.reduce((s, [k, p]) => s + k * p, 0), 2), `mean; at most ${2 + Math.min(4, party)}`),
		stat('Total health', fmt(r.meanHp, 0), 'mean, at this depth and party'), stat('Damage a turn', fmt(r.meanDamage, 1), 'sum of the pack, to every player'), stat('Threat spent', fmt(r.meanThreat, 1), 'mean'), stat('Band from', `depth ${band.from_depth ?? 1}`, `${Object.keys(band.creatures || {}).length} creatures in the pool`)));
	const g = h('div', { class: 'grid grid-3' });
	root.append(g);
	g.append(card(`Pool at depth ${depth}`, h('div', { class: 'col' }, bars({ rows: Object.entries(band.creatures || {}).sort((a, b) => b[1] - a[1]).map(([k, w]) => ({ key: k, label: C.creature(k).name, value: (Number(w) / total) * 100, note: `weight ${w} · threat ${C.creature(k).threat}`, color: '#8a93a3' })), format: (v) => `${fmt(v, 0)}%`, labelWidth: 100, onSelect: (r) => { state.tab = 'creatures'; ctx.navigate('enemies', r.key); } }), h('p', { class: 'tiny muted' }, 'Weighted first-pick share. Each pick is bought against the budget; the first is always taken, the rest only while they fit.')), { meta: 'band weights' }));
	const compSlot = h('div'), countSlot = h('div');
	g.append(card('Most common fights', compSlot, { meta: 'share of sampled encounters' }));
	g.append(card('How many creatures, and who shows up', countSlot));
	whenReady(ctx, compSlot, job, (r) => bars({ rows: r.compositions.slice(0, 12).map(([label, p]) => ({ key: label, label: label.split('+').map((k) => C.creature(k).name).join(' + '), value: p * 100, note: `${fmt(r.damageByKey ? label.split('+').reduce((s, k) => s + r.damageByKey[k], 0) : 0, 1)} damage a turn` })), format: (v) => `${fmt(v, 1)}%`, labelWidth: 200, height: 20 }));
	whenReady(ctx, countSlot, job, (r) => h('div', { class: 'col' }, columns({ data: r.counts.map(([k, p]) => ({ label: `${k}`, value: p * 100, key: k, note: 'creatures' })), width: 300, height: 110, format: (v) => `${fmt(v, 0)}%`, valueLabels: 'all', color: '#c0463c' }),
		bars({ rows: Object.entries(r.perCreature).sort((a, b) => b[1] - a[1]).map(([k, n]) => ({ key: k, label: C.creature(k).name, value: n, note: 'expected per fight', color: '#8a93a3' })), format: (v) => fmt(v, 2), labelWidth: 100, height: 18 })));
}

function bandsPage(root, ctx) {
	const mine = C.mine(ctx.settings.mine);
	const depths = Array.from({ length: 28 }, (_, i) => i + 1);
	const keys = C.keys('creatures').filter((k) => !C.creature(k).warden);
	const values = keys.map((k) => depths.map((d) => { const band = Forge.bandFor(mine, d); const total = Object.values(band.creatures || {}).reduce((a, b) => a + Number(b), 0) || 1; const w = band.creatures?.[k]; return w ? (Number(w) / total) * 100 : null; }));
	root.append(card(`Creature pool by depth · ${mine.name || ctx.settings.mine}`, h('div', { class: 'col' }, heatmap({ rows: keys.map((k) => C.creature(k).name), cols: depths.map(String), values, format: (v) => `${fmt(v, 0)}%`, rowLabelWidth: 110, cellHeight: 28, cellLabels: true }),
		h('p', { class: 'small text-2' }, `Bands begin at depths ${(mine.bands || []).map((b) => b.from_depth).join(', ')}. Wardens ${(mine.wardens || []).map((k) => C.creature(k).name).join(', ')} guard depths ${(mine.warden_depths || []).join(', ')}${mine.boss ? `, and ${C.creature(mine.boss).name} the bottom at ${mine.depth}` : ''}.`)), { meta: 'first-pick share of the band' }));
	const budgetSeries = [1, 2, 3, 4].map((p, i) => ({ key: p, label: `party of ${p}`, color: PARTY_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.encounterBudget(d, p, false) })) }));
	root.append(h('div', { class: 'grid grid-2' },
		card('Threat budget by depth', lines({ series: budgetSeries, width: 480, height: 200, xFormat: (d) => String(d), format: (v) => fmt(v, 1), markers: false }), { meta: 'an elite fight has half again' }),
		card('Threat costs', table({ columns: [{ key: 'name', label: 'Creature', render: (r) => h('span', { class: 'cell-name' }, creatureImage(r.key, 28), r.name) }, { key: 'threat', label: 'Threat', align: 'right' }, { key: 'hp', label: 'Base HP', align: 'right' }, { key: 'perThreat', label: 'HP per threat', align: 'right', render: (r) => fmt(r.perThreat, 1) }, { key: 'dice', label: 'Dice' }],
			rows: C.keys('creatures').map((k) => ({ key: k, name: C.creature(k).name, threat: C.creature(k).threat, hp: C.creature(k).hp, perThreat: C.creature(k).hp / Math.max(1, C.creature(k).threat), dice: (C.creature(k).dice || []).join(' ') })).sort((a, b) => a.threat - b.threat), compact: true, rowKey: (r) => r.key, onRowClick: (r) => { state.tab = 'creatures'; ctx.navigate('enemies', r.key); } }))));
}
