// Creatures: what each one does to the party at a depth, and what a fight at that depth holds.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import * as Patterns from '../sim/patterns.js';
import * as Rules from '../sim/rules.js';
import { traitsFor } from '../sim/simulate.js';
import { h, card, stat, table, fmt, fmtPct, segmented, field, toolbar, note, kv, chip } from '../ui.js';
import { columns, lines, histogram, bars, heatmap } from '../charts.js';
import { creatureImage, dieImage } from '../gemart.js';
import { depthControls, whenReady, tabs, faceRow } from './common.js';

const state = { tab: 'creatures', phase: 0, elite: false, turn: 1, action: 1, emerging: false };
const PARTY_COLORS = ['#f0c95a', '#c9a43e', '#a38434', '#7d652a'];
// A creature's die as written: a shape, or an object carrying the variations it was born with.
const dieKey = (ref) => (ref && typeof ref === 'object' ? String(ref.shape || 'D6') : String(ref));
const diceText = (def) => (def.dice || []).map(dieKey).join(' ');

// What a creature's move waits for, the way the game says it (sim/creatures.gd trigger_words).
export function triggerWords(move) {
	const t = move.trigger || { kind: 'always' };
	const n = Patterns.rung(t, 0);
	const which = 'die' in t ? ` · die ${Number(t.die) + 1}` : '';
	const once = move.once ? ' · once a fight' : '';
	switch (t.kind || 'always') {
		case 'always': return `Every die${which}`;
		case 'odd': return `An odd roll${which}`;
		case 'even': return `An even roll${which}`;
		case 'at_least': return `A roll of ${n}+${which}`;
		case 'at_most': return `A roll of ${n} or less${which}`;
		case 'value': return `A roll of ${(t.values || []).join('/')}${which}`;
		case 'crowns': return `Its top face${which}`;
		case 'each_turn': return `Each action${once}`;
		case 'every_nth_turn': return `Every ${Patterns.ordinal(n)} action${once}`;
		case 'emerge': return `When it comes up${once}`;
		case 'on_death': return 'When it dies';
		case 'pair': case 'triple': case 'quad': case 'quint': return `${Patterns.KIND_NAMES[t.kind]}${n > 1 ? ` of ${n}+` : ''} · once an action${once}`;
		case 'straight': return `${n} in sequence · once an action${once}`;
		case 'all_odd': return `All dice odd (${n}+) · once an action${once}`;
		case 'all_even': return `All dice even (${n}+) · once an action${once}`;
	}
	return `${Patterns.words(t, 0).replace(/\.$/, '')} · once an action${which}${once}`;
}

// A trait in words, with its number where it has one (docs/BESTIARY.md).
const TRAIT_WORDS = {
	steadfast: () => ['Steadfast', 'Cannot be stunned, suppressed, clouded or dreaded'],
	bedrock: (v) => [`Bedrock ${v}%`, `No single hit takes more than ${v}% of its health`],
	backlash: () => ['Backlash', `Every gem after the ${Patterns.ordinal(Number(C.constant('backlash_after', 6)))} to fire in one turn costs its owner 1 health`],
	flee: (v) => [`Flees after ${v} turns`, 'Leaves the fight, and takes what it stole with it'],
	rising: (v) => [`Rising +${v}%/turn`, 'Its damage multiplier grows by this share every action'],
	escalate: (v) => [`Escalating +${v}/turn`, 'A flat point more on every blow for each action spent in this phase'],
	spikes: (v) => [`Spikes ${v}`, 'Retaliates once per attacking ability'],
	regen_with_escorts: (v) => [`Regenerates ${v} with escorts`, 'Heals at turn end while an escort still stands'],
	shielded_by_escorts: (v) => [`Shielded by escorts ${v}%`, 'Takes that much less while an escort still stands'],
	regrow_escorts: (v) => [`Regrows escorts in ${v}`, 'Dead escorts come back that many turns later, if there is room'],
	reroll_drain: (v) => [`Reroll drain ${v}`, 'Each reroll it gifts costs that much'],
	reroll_scorch: (v) => [`Rerolls scorch ${v}`, 'Each reroll it gifts Scorches'],
	punish_straight: () => [`Punishes straights of ${C.constant('punished_straight', 4)}+`, 'A long straight against it is answered'],
	drops_stone: () => ['Drops a raw stone', 'Its killer takes a raw stone'],
	adapt_aura: (v) => [`Adapt aura ${v}%`, 'Each turn it takes that much less from the colour that hurt it most'],
	steal_high_die: () => ['Steals your high die', ''],
	block_from_high: () => ['Blocks from its high roll', ''],
	reflect_zero_resonance: () => ['Reflects at zero Resonance', 'A hit from a player at Resonance 1 or less comes back'],
	cloud_socket: () => ['Clouds a socket when hit', ''],
	split_on_big_hit: () => ['Splits on a big hit', 'A hit for 40% or more of its health splits it'],
	steal_gold: (v) => [`Thief${typeof v === 'number' && v > 1 ? ` ×${v}` : ''}`, 'Its hits take pyrite'],
	gift_rerolls: () => ['Gifts rerolls', 'The party gets a reroll more while it lives'],
	poison_immune: () => ['Poison immune', ''],
	bury_socket: () => ['Buries a socket', ''],
	mirror_last_gem: () => ['Mirrors your last gem', 'Hits harder for half of what the party dealt last turn, up to 6'],
	roll_for_you: () => ['Rolls your dice for you', 'On odd turns'],
	regrow: () => ['Regrows', 'Heals at turn end'],
};

export function traitChips(traits) {
	const out = [];
	for (const [key, value] of Object.entries(traits || {})) {
		if (key === 'aura') {
			for (const [status, amount] of Object.entries(value && typeof value === 'object' ? value : {})) out.push(chip(`Aura: ${C.title(status)} ${amount}`, { class: 'accent', title: `Every player takes ${amount} ${C.title(status)} each turn while it lives` }));
			continue;
		}
		const words = TRAIT_WORDS[key] ? TRAIT_WORDS[key](value) : [C.title(key) + (typeof value === 'number' && value !== 1 ? ` ${value}` : ''), ''];
		out.push(chip(words[0], { class: 'accent', title: words[1] || null }));
	}
	return out;
}

const traitText = (traits) => traitChips(traits).map((c) => c.textContent).join(' · ') || 'none';

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
	const mineKey = ctx.settings.mine;
	const mine = C.mine(mineKey);
	const keys = C.keys('creatures').sort((a, b) => Number(C.creature(a).threat) - Number(C.creature(b).threat) || a.localeCompare(b));
	const active = route.key && C.creature(route.key).name ? route.key : keys[0];
	const def = C.creature(active);
	const depth = ctx.settings.depth, party = ctx.settings.party;
	const phase = Math.min(state.phase, (def.phases || []).length);
	const moves = phase > 0 ? def.phases[phase - 1].moves : def.moves || [];
	const traits = traitsFor(def, phase);
	const canEmerge = moves.some((m) => (m.trigger || {}).kind === 'emerge');
	root.append(toolbar(...depthControls(ctx),
		field('Turn', segmented([[1, '1'], [4, '4'], [7, '7'], [9, '9']], state.turn, (v) => { state.turn = Number(v); ctx.rerender(); }), `Enrage from turn ${C.constant('enrage_turn', 7)}`),
		field('Action', segmented([[1, '1'], [2, '2'], [3, '3'], [4, '4'], [6, '6']], state.action, (v) => { state.action = Number(v); ctx.rerender(); }), 'Which of its own actions this is'),
		(def.phases || []).length ? field('Phase', segmented([[0, 'Opening'], ...(def.phases || []).map((p, i) => [i + 1, `Below ${p.below_hp_pct}% HP`])], state.phase, (v) => { state.phase = Number(v); ctx.rerender(); })) : null,
		canEmerge ? field('Just surfaced', segmented([[false, 'No'], [true, 'Yes']], state.emerging, (v) => { state.emerging = v === 'true' || v === true; ctx.rerender(); }), 'The action after it burrowed') : null));
	const grid = h('div', { class: 'grid grid-side' });
	root.append(grid);
	const list = h('div', { class: 'list' }, keys.map((k) => {
		const d = C.creature(k);
		const tag = d.warden ? 'Warden · ' : d.summon_only ? 'Summoned only · ' : d.echo ? 'Echo · ' : '';
		return h('button', { type: 'button', class: `list-item${k === active ? ' is-active' : ''}`, onClick: () => ctx.navigate('enemies', k) }, creatureImage(k, 40),
			h('span', {}, h('span', { class: 'li-name' }, d.name), h('span', { class: 'li-sub' }, `${tag}threat ${d.threat} · ${diceText(d)}`)), h('span', { class: 'li-right' }, `${Forge.creatureHp(d, depth, party, mine)} hp`));
	}));
	grid.append(h('section', { class: 'card list-panel', style: { maxHeight: 'calc(100vh - 230px)' } }, list, h('div', { class: 'list-count' }, `${keys.length} creatures · HP at depth ${depth}, party ${party}, ${mine.name || mineKey}`)));
	const detail = h('div', { class: 'col' });
	grid.append(detail);
	const escorts = def.escorts || [];
	detail.append(h('div', { class: 'card' }, h('div', { class: 'card-body' }, h('div', { class: 'detail-head' }, h('span', { class: 'pic hero' }, creatureImage(active, 170)),
		h('div', { class: 'detail-title' },
			h('div', { class: 'row tight' }, def.warden ? chip('Warden', { class: 'accent' }) : chip('Creature'), chip(`threat ${def.threat}`), chip(`${def.ward ?? (def.warden ? 1 : 0)} Ward`),
				def.summon_only ? chip('Summoned only', { title: 'Never drawn from a band: it comes in beside another creature' }) : null,
				def.echo ? chip(`Echo of ${(def.echo.mines || []).map((m) => C.mine(m).name || m).join(', ')}`, { title: 'A random non-Warden creature from those mines, over again, with this mine’s scaling' }) : null,
				escorts.length ? chip(`Escorts: ${escortText(escorts)}`, { title: 'Spawned beside it at the start of the fight' }) : null),
			h('div', { class: 'row tight' }, ...traitChips(traits)),
			h('h2', {}, def.name), h('p', { class: 'lede' }, def.text || ''),
			h('div', { class: 'row tight' }, h('span', { class: 'small muted' }, 'Rolls, in order:'), ...(def.dice || []).map((k, i) => h('span', { class: 'row tight', title: `die ${i + 1}` }, dieImage(dieKey(k), 30), h('span', { class: 'small text-2' }, dieKey(k))))))))));
	const job = ctx.engine.run('creatureTurn', { key: active, depth, party, phase, turn: state.turn, action: state.action, mineKey, emerging: canEmerge && state.emerging, samples: 6000 });
	const statsSlot = h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(7, minmax(0,1fr))' } });
	detail.append(statsSlot);
	whenReady(ctx, statsSlot, job, (r) => h('div', { style: { display: 'contents' } },
		stat('Health', String(r.hp), `base ${def.hp} × depth × party × mine`, { class: 'accent' }), stat('Block', String(def.block ?? 0), 'to start'),
		stat('Damage an action', fmt(r.meanDamage, 2), `action ${r.action}, to its target, before block`),
		stat('Damage ×', `${fmt(r.damagePct / 100, 2)}`, `${mine.name || mineKey} ×${fmt(r.damageMult, 2)}${traits.rising ? ` · rising +${traits.rising}%/action` : ''}`),
		stat('Damage bonus', `+${r.damageBonus}`, `depth ÷ ${C.constant('depth_damage_every', 4)}, per die${traits.escalate ? ` · +${traits.escalate} an action in phase` : ''}`),
		stat('Enrage', r.enrage ? `+${r.enrage}` : '—', `from turn ${C.constant('enrage_turn', 7)}`), stat('Threat', String(def.threat), 'against the encounter budget')));
	const g = h('div', { class: 'grid grid-2' });
	detail.append(g);
	const movesSlot = h('div'), histSlot = h('div');
	g.append(card(`Moves · ${phase > 0 ? `below ${def.phases[phase - 1].below_hp_pct}% HP` : 'opening phase'}`, movesSlot, { meta: `fires per action, sampled · action ${state.action}` }));
	g.append(card('Damage in one action', histSlot, { meta: 'to its target, before block' }));
	whenReady(ctx, movesSlot, job, (r) => h('div', { class: 'moves' }, moves.map((m, i) => {
		const s = r.moves[i];
		const right = s.onDeath ? [h('div', { class: 'num' }, 'when it dies'), h('div', { class: 'tiny muted' }, 'fires once, as it falls')]
			: s.spent ? [h('div', { class: 'num' }, 'spent'), h('div', { class: 'tiny muted' }, 'used on its first action')]
			: [h('div', { class: 'num' }, `${fmt(s.fireRate, 2)}× an action`), h('div', { class: 'tiny muted' }, moveNote(s))];
		return h('div', { class: 'move' }, h('span', {}, h('b', {}, m.name), m.dramatic ? chip('dramatic', { class: 'accent' }) : null, m.once ? chip('once a fight') : null,
			h('div', { class: 'move-trig' }, triggerWords(m)), h('div', { class: 'move-eff' }, (m.effects || []).map((e) => Rules.effectWords(e)).join(' · '))),
			h('span', { class: 'right' }, ...right));
	})));
	whenReady(ctx, histSlot, job, (r) => histogram({ bins: r.damageHist, width: 420, height: 190, color: '#e0473c', mean: r.meanDamage, xLabel: 'damage', xFormat: (v) => String(v) }));
	const depths = Array.from({ length: 28 }, (_, i) => i + 1);
	detail.append(h('div', { class: 'grid grid-2' },
		card('Health by depth', lines({ series: [1, 2, 3, 4].map((p, i) => ({ key: p, label: `party of ${p}`, color: PARTY_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.creatureHp(def, d, p, mine) })) })), width: 420, height: 180, xFormat: (d) => String(d), format: (v) => fmt(v, 0), markers: false }), { meta: `+${fmt(Number(C.constant('depth_hp_scale', 0.05)) * 100, 0)}% a depth, +15% a player, ×${fmt(Number(mine.hp_mult ?? 1), 1)} here` }),
		card('Phases, traits and dice', h('div', { class: 'col' }, kv([
			['Phases', (def.phases || []).length ? def.phases.map((p, i) => `below ${p.below_hp_pct}% HP: ${(p.moves || []).map((m) => m.name).join(', ')}${Object.keys(p.traits || {}).length ? ` (traits then: ${traitText(traitsFor(def, i + 1))})` : ''}`).join(' · ') : 'none'],
			['Traits', traitText(traits)],
			['Escorts', escorts.length ? escortText(escorts) : 'none'],
			['Echo', def.echo ? `copies a random ordinary creature from ${(def.echo.mines || []).map((m) => C.mine(m).name || m).join(', ')}` : 'no'],
			['Summoned only', def.summon_only ? 'yes: never drawn from a band' : 'no'],
			['Dice', (def.dice || []).map((k) => `${dieKey(k)} ${faceRowText(dieKey(k))}`).join(' · ')]]),
			...(def.dice || []).map((k) => h('div', { class: 'row' }, h('span', { class: 'small muted', style: { width: '40px' } }, dieKey(k)), faceRow(C.die(dieKey(k))))),
			note('Ordinary moves are judged against each die as it lands (one that names a die reads only that die); combination moves against every die shown so far and fire once an action. All-odd and all-even wait for the last die. Each-action, every-nth-action and emerging moves fire once, before the first die; a move marked once a fight is taken as spent after action 1; a when-it-dies move never fires in an action. Damage is pct(roll, mine × rising) + depth bonus (+ escalation) + rally + enrage.', 'plain')))));
}
const faceRowText = (k) => `(${(C.die(k).faces || []).length} faces)`;
function escortText(escorts) {
	const counts = {};
	for (const k of escorts) counts[k] = (counts[k] || 0) + 1;
	return Object.entries(counts).map(([k, n]) => `${n}× ${C.creature(k).name || k}`).join(', ');
}
function moveNote(s) {
	const parts = [];
	if (s.meanDamage) parts.push(`${fmt(s.meanDamage, 1)} damage${s.meanPiercing ? ' · ignores block' : ''}`);
	if (s.meanRelease) parts.push(`then ${fmt(s.meanRelease, 1)} on release`);
	for (const [k, v] of Object.entries(s.effects)) if (k !== 'damage' && k !== 'charge') parts.push(`${fmt(v, 1)} ${k.replace(/_/g, ' ')}`);
	if (s.nextNth > 1) parts.push(`next in ${s.nextNth} actions`);
	return parts.join(' · ');
}

function encountersPage(root, ctx) {
	const depth = ctx.settings.depth, party = ctx.settings.party;
	const mine = C.mine(ctx.settings.mine);
	root.append(toolbar(...depthControls(ctx), field('Kind', segmented([[false, 'Fight'], [true, 'Elite']], state.elite, (v) => { state.elite = v === 'true' || v === true; ctx.rerender(); }))));
	const job = ctx.engine.run('encounters', { mineKey: ctx.settings.mine, depth, party, elite: state.elite, samples: 5000 });
	const band = Forge.bandFor(mine, depth);
	const total = Object.values(band.creatures || {}).reduce((a, b) => a + Number(b), 0) || 1;
	const statsSlot = h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(6, minmax(0,1fr))' } });
	root.append(statsSlot);
	whenReady(ctx, statsSlot, job, (r) => h('div', { style: { display: 'contents' } }, stat('Threat budget', fmt(r.budget, 1), `(3 + 0.6 × depth) × (0.55 + 0.45 × party)${state.elite ? ' × 1.5' : ''}`, { class: 'accent' }), stat('Creatures', fmt(r.counts.reduce((s, [k, p]) => s + k * p, 0), 2), `mean; at most ${2 + Math.min(4, party)} drawn, ${C.constant('max_creatures', 4)} standing`),
		stat('Total health', fmt(r.meanHp, 0), `mean, at this depth and party in ${mine.name || ctx.settings.mine}`), stat('Damage a turn', fmt(r.meanDamage, 1), `sum of the pack on its first action · ×${fmt(r.damageMult ?? 1, 2)} here`), stat('Threat spent', fmt(r.meanThreat, 1), 'mean'), stat('Band from', `depth ${band.from_depth ?? 1}`, `${Object.keys(band.creatures || {}).length} creatures in the pool`)));
	const g = h('div', { class: 'grid grid-3' });
	root.append(g);
	g.append(card(`Pool at depth ${depth}`, h('div', { class: 'col' }, bars({ rows: Object.entries(band.creatures || {}).sort((a, b) => b[1] - a[1]).map(([k, w]) => ({ key: k, label: C.creature(k).name, value: (Number(w) / total) * 100, note: `weight ${w} · threat ${C.creature(k).threat}${C.creature(k).echo ? ' · echo' : ''}`, color: '#8a93a3' })), format: (v) => `${fmt(v, 0)}%`, labelWidth: 100, onSelect: (r) => { state.tab = 'creatures'; ctx.navigate('enemies', r.key); } }), h('p', { class: 'tiny muted' }, 'Weighted first-pick share. Each pick is bought against the budget; the first is always taken, the rest only while they fit. A Void Echo stands in for a random creature of the first four mines.')), { meta: 'band weights' }));
	const compSlot = h('div'), countSlot = h('div');
	g.append(card('Most common fights', compSlot, { meta: 'share of sampled encounters' }));
	g.append(card('How many creatures, and who shows up', countSlot));
	whenReady(ctx, compSlot, job, (r) => bars({ rows: r.compositions.slice(0, 12).map(([label, p]) => ({ key: label, label: label.split('+').map((k) => C.creature(k).name).join(' + '), value: p * 100, note: `${fmt(r.damageByKey ? label.split('+').reduce((s, k) => s + r.damageByKey[k], 0) : 0, 1)} damage a turn` })), format: (v) => `${fmt(v, 1)}%`, labelWidth: 200, height: 20 }));
	whenReady(ctx, countSlot, job, (r) => h('div', { class: 'col' }, columns({ data: r.counts.map(([k, p]) => ({ label: `${k}`, value: p * 100, key: k, note: 'creatures' })), width: 300, height: 110, format: (v) => `${fmt(v, 0)}%`, valueLabels: 'all', color: '#c0463c' }),
		bars({ rows: Object.entries(r.perCreature).sort((a, b) => b[1] - a[1]).map(([k, n]) => ({ key: k, label: C.creature(k).name, value: n, note: 'expected per fight', color: '#8a93a3' })), format: (v) => fmt(v, 2), labelWidth: 100, height: 18 })));
}

// Who guards the landings, in words: a mine's Wardens at their depths and its boss at the
// bottom, or the Rift's rotation with the Unmade every so often.
export function wardenText(mine) {
	const name = (k) => C.creature(k).name || k;
	if (mine.endless) {
		const every = Number(mine.warden_every ?? C.constant('endless_warden_every', 8));
		const first = Array.from({ length: 10 }, (_, i) => Forge.endlessWarden(mine, i + 1));
		let text = `${mine.name || 'This mine'} has no bottom: a Warden hall every ${every} floors, the remembered bosses in turn (${(mine.wardens || []).map(name).join(', ')})`;
		if (mine.unmade && Number(mine.unmade_every ?? 0) > 0) text += `, and every ${Patterns.ordinal(Number(mine.unmade_every))} Warden is ${name(mine.unmade)} instead, the cycle skipping that slot`;
		text += `. So the first ten halls: ${first.map((k, i) => `${i + 1} ${name(k)}`).join(', ')}.`;
		return text;
	}
	return `Wardens ${(mine.wardens || []).map(name).join(', ')} guard depths ${(mine.warden_depths || []).join(', ')}${mine.boss ? `, and ${name(mine.boss)} the bottom at ${mine.depth}` : ''}.`;
}

function bandsPage(root, ctx) {
	const mine = C.mine(ctx.settings.mine);
	const depths = Array.from({ length: 28 }, (_, i) => i + 1);
	const keys = C.keys('creatures').filter((k) => !C.creature(k).warden && (mine.bands || []).some((b) => k in (b.creatures || {})));
	const values = keys.map((k) => depths.map((d) => { const band = Forge.bandFor(mine, d); const total = Object.values(band.creatures || {}).reduce((a, b) => a + Number(b), 0) || 1; const w = band.creatures?.[k]; return w ? (Number(w) / total) * 100 : null; }));
	root.append(card(`Creature pool by depth · ${mine.name || ctx.settings.mine}`, h('div', { class: 'col' }, heatmap({ rows: keys.map((k) => C.creature(k).name), cols: depths.map(String), values, format: (v) => `${fmt(v, 0)}%`, rowLabelWidth: 110, cellHeight: 28, cellLabels: true }),
		h('p', { class: 'small text-2' }, `Bands begin at depths ${(mine.bands || []).map((b) => b.from_depth).join(', ')}. ${wardenText(mine)}`)), { meta: 'first-pick share of the band' }));
	const budgetSeries = [1, 2, 3, 4].map((p, i) => ({ key: p, label: `party of ${p}`, color: PARTY_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.encounterBudget(d, p, false) })) }));
	root.append(h('div', { class: 'grid grid-2' },
		card('Threat budget by depth', lines({ series: budgetSeries, width: 480, height: 200, xFormat: (d) => String(d), format: (v) => fmt(v, 1), markers: false }), { meta: 'an elite fight has half again' }),
		card('Threat costs', table({ columns: [{ key: 'name', label: 'Creature', render: (r) => h('span', { class: 'cell-name' }, creatureImage(r.key, 28), r.name) }, { key: 'threat', label: 'Threat', align: 'right' }, { key: 'hp', label: 'Base HP', align: 'right' }, { key: 'perThreat', label: 'HP per threat', align: 'right', render: (r) => fmt(r.perThreat, 1) }, { key: 'dice', label: 'Dice' }, { key: 'traits', label: 'Traits' }],
			rows: C.keys('creatures').map((k) => ({ key: k, name: C.creature(k).name, threat: C.creature(k).threat, hp: C.creature(k).hp, perThreat: C.creature(k).hp / Math.max(1, C.creature(k).threat), dice: diceText(C.creature(k)), traits: traitText(traitsFor(C.creature(k), 0)).replace(/^none$/, '') })).sort((a, b) => a.threat - b.threat), compact: true, rowKey: (r) => r.key, onRowClick: (r) => { state.tab = 'creatures'; ctx.navigate('enemies', r.key); } }))));
}
