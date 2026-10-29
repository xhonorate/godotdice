// Creatures: what each one does to the party at a depth, and what a fight at that depth holds.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import * as Patterns from '../sim/patterns.js';
import * as Rules from '../sim/rules.js';
import { traitsFor, faceNames } from '../sim/simulate.js';
import { h, card, stat, table, fmt, fmtPct, segmented, field, toolbar, note, kv, chip } from '../ui.js';
import { columns, lines, histogram, bars, heatmap } from '../charts.js';
import { creatureImage, creatureDieImage, markChip, pips, MOVE_INK } from '../gemart.js';
import { depthControls, whenReady, tabs } from './common.js';

const state = { tab: 'creatures', elite: false, turn: 1, action: 1, emerging: false };
const PARTY_COLORS = ['#f0c95a', '#c9a43e', '#a38434', '#7d652a'];
// A creature's die as written: a shape, or an object carrying the variations it was born with.
const dieKey = (ref) => (ref && typeof ref === 'object' ? String(ref.shape || 'D6') : String(ref));
const diceText = (def) => (def.dice || []).map(dieKey).join(' ');

// What a creature's move waits for, the way the game says it (sim/creatures.gd trigger_words):
// its faces, the faces it needs together, or what the fight calls it by.
export function triggerWords(move, def = null) {
	const t = move.trigger || { kind: 'face' };
	switch (t.kind || 'face') {
		case 'face': {
			let count = 0, total = 0;
			for (const ref of (def && def.dice) || []) {
				const names = faceNames(ref) || [];
				total += names.length;
				count += names.filter((n) => n === move.name).length;
			}
			return total ? `${count} of ${total} faces` : 'Its face';
		}
		case 'match': {
			const faces = (t.faces || []).map(String);
			return Number(t.count || 0) > 0 && faces.length ? `${t.count} dice on ${faces[0]} · once an action` : `${faces.join(' and ')} together · once an action`;
		}
		case 'emerge': return 'When it comes up';
		case 'on_death': return 'When it dies';
		case 'action_begin': return 'As each action opens';
	}
	return String(t.kind);
}

// A move's own words with its numbers written in as the content has them (`{0}` is its first
// effect's amount); the game writes the number this creature deals where it stands instead.
const PLACE = /\{(\d+|n)\}/g;
const amountText = (expr) => (typeof expr === 'number' ? String(expr) : expr && typeof expr === 'object' && 'const' in expr ? String(expr.const) : '?');
export function moveWords(move) {
	const text = String(move.text || '');
	if (!text) return (move.effects || []).map((e) => Rules.effectWords(e)).join(' · ');
	return text.replace(PLACE, (all, at) => {
		const effect = (move.effects || [])[at === 'n' ? 0 : Number(at)];
		return effect ? amountText(effect.amount) : all;
	});
}
// The number on its pill: the first figure its words carry, or none.
function moveNumber(move) {
	const found = String(move.text || '').match(/\{(\d+|n)\}/);
	if (!found) return '';
	const effect = (move.effects || [])[found[1] === 'n' ? 0 : Number(found[1])];
	return effect ? amountText(effect.amount) : '';
}

// The words a reader may not know, with their meaning on hover (the review page's list).
const KEYWORDS = {
	Marked: 'Every hit of the next gem, Birthstone or creature move to land deals +25% per stack.',
	Drink: 'It drinks a colour of gem: those gems do it no damage, and what they would give their owner goes to it.',
	Poison: 'Hurts at the end of each round, then drops by 1. Bypasses block.',
	Burn: 'Hurts at the end of each turn (block soaks it), then drops by 1.',
	Curse: "Your gems' hits deal 10% less a stack, and you take 10% more.",
	Dulled: 'Your gems lose a Cut step a stack while it lasts.',
	Festering: 'Healing is halved while it lasts.',
	Strength: 'Every hit does that much more.',
	Stun: 'Skips the next action.',
	'Acid Armour': 'Whoever hits it takes that much Poison.',
	Sturdy: 'No single hit takes more than that share of its health.',
	Steadfast: 'Stun, Bound and Clouded last half as long on it, and it cannot be stunned two actions in a row.',
	Waterlogged: 'The first time it dies, it gets back up at half its health.',
};
const KEYWORD_RE = new RegExp(`\\b(${Object.keys(KEYWORDS).sort((a, b) => b.length - a.length).join('|')})\\w*`, 'g');
function keywords(text) {
	const out = [];
	let at = 0;
	for (const found of String(text).matchAll(KEYWORD_RE)) {
		if (found.index > at) out.push(text.slice(at, found.index));
		out.push(h('span', { class: 'kw', title: KEYWORDS[found[1]] }, found[0]));
		at = found.index + found[0].length;
	}
	out.push(String(text).slice(at));
	return out;
}

// A creature's dice as written, like ones side by side taken as one: [{index, count, shape, label, names}].
function diceGroups(def) {
	const out = [];
	(def.dice || []).forEach((ref, index) => {
		const names = faceNames(ref) || [];
		const shape = dieKey(ref);
		const label = ref && typeof ref === 'object' ? String(ref.label || '') : '';
		const last = out[out.length - 1];
		if (last && last.shape === shape && last.label === label && last.names.join() === names.join()) { last.count += 1; return; }
		out.push({ index, count: 1, shape, label, names });
	});
	return out;
}
const dieCaption = (g) => `${g.label ? g.label.charAt(0).toUpperCase() + g.label.slice(1) + ' die · ' : ''}${g.shape.toLowerCase()}${g.count > 1 ? ` ×${g.count}` : ''} · ${g.names.length} faces${g.count > 1 ? ' each' : ''}`;
// Where a move on no face comes from: the move that etches a face to it, or grows a die with it.
function etchedBy(def, name) {
	for (const move of def.moves || []) for (const e of move.effects || []) if ((e.kind === 'etch' && e.to === name) || (e.kind === 'grow_faces' && (e.faces || []).includes(name))) return move.name;
	return '';
}
// A trait in words, with its number where it has one (docs/BESTIARY.md).
const TRAIT_WORDS = {
	steadfast: () => ['Steadfast', 'Cannot be stunned, suppressed, clouded or dreaded'],
	sturdy: (v) => [`Sturdy ${v}%`, `No single hit takes more than ${v}% of its health`],
	backlash: () => ['Backlash', 'Every gem that fires costs its owner 1 health'],
	flee: (v) => [`Flees after ${v} turns`, 'Leaves the fight, and takes what it stole with it'],
	rising: (v) => [`Rising +${v}%/turn`, 'Its damage multiplier grows by this share every action'],
	escalate: (v) => [`Escalating +${v}/turn`, 'A point more on every blow for each action spent in this phase, weighed like the roll'],
	spikes: (v) => [`Spikes ${v}`, 'Retaliates once per attacking ability'],
	regen_with_escorts: (v) => [`Regenerates ${v} with escorts`, 'Heals at turn end while an escort still stands'],
	shielded_by_escorts: (v) => [`Shielded by escorts ${v}%`, 'Takes that much less while an escort still stands'],
	regrow_escorts: (v) => [`Regrows escorts in ${v}`, 'Dead escorts come back that many turns later, if there is room'],
	reroll_drain: (v) => [`Reroll drain ${v}`, 'Each reroll it gifts costs that much'],
	reroll_scorch: (v) => [`Rerolls scorch ${v}`, 'Each reroll it gifts Scorches'],
	punish_straight: () => [`Punishes straights of ${C.constant('punished_straight', 4)}+`, 'A long straight against it is answered'],
	drops_stone: () => ['Drops a raw stone', 'Its killer takes a raw stone'],
	carat_cap: (v) => [`Gems count ${v} carats at most`, 'While it stands no gem counts for more'],
	resonance_damp: (v) => [`Dampens Resonance ${v}%`, 'Your gems ring for that much less while it lives'],
	color_strength: () => ['Feeds on color', 'Gains 1 Strength the first time it sees each color of gem fire'],
	waterlogged: () => ['Waterlogged', 'The first time it dies it gets back up at half health'],
	hydra: (v) => [`Heads every ${v}%`, 'Every share of its health lost cuts a head off; each grows back as two as it next acts (six at most)'],
	countdown_reset: (v) => [`Held back at ${v}%`, 'A turn that takes this share of its health starts its countdown again'],
	taunt: () => ['Gravity', 'Gems aimed at one creature hit it instead while it stands'],
	regenerating: (v) => [`Regenerating ${v}`, 'Heals that much at the end of every turn'],
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
	const moves = def.moves || [];
	const traits = traitsFor(def, 0);
	const canEmerge = moves.some((m) => (m.trigger || {}).kind === 'emerge');
	root.append(toolbar(...depthControls(ctx),
		field('Turn', segmented([[1, '1'], [4, '4'], [7, '7'], [9, '9']], state.turn, (v) => { state.turn = Number(v); ctx.rerender(); }), `Enrage from turn ${C.constant('enrage_turn', 7)}`),
		field('Action', segmented([[1, '1'], [2, '2'], [3, '3'], [4, '4'], [6, '6']], state.action, (v) => { state.action = Number(v); ctx.rerender(); }), 'Which of its own actions this is'),
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
	const groups = diceGroups(def);
	detail.append(h('div', { class: 'card' }, h('div', { class: 'card-body' }, h('div', { class: 'detail-head' }, h('span', { class: 'pic hero' }, creatureImage(active, 170)),
		h('div', { class: 'detail-title' },
			h('div', { class: 'row tight' }, def.warden ? chip('Warden', { class: 'accent' }) : chip('Creature'), chip(`threat ${def.threat}`), chip(`${def.ward ?? (def.warden ? 1 : 0)} Ward`),
				def.summon_only ? chip('Summoned only', { title: 'Never drawn from a band: it comes in beside another creature' }) : null,
				def.echo ? chip(`Echo of ${(def.echo.mines || []).map((m) => C.mine(m).name || m).join(', ')}`, { title: 'A random non-Warden creature from those mines, over again, with this mine’s scaling' }) : null,
				escorts.length ? chip(`Escorts: ${escortText(escorts)}`, { title: 'Spawned beside it at the start of the fight' }) : null),
			h('div', { class: 'row tight' }, ...traitChips(traits)),
			h('h2', {}, def.name), h('p', { class: 'lede' }, ...keywords(def.text || '')), def.tip ? h('p', { class: 'lede' }, h('strong', {}, 'Remember: '), def.tip) : null,
			h('div', { class: 'row tight' }, h('span', { class: 'small muted' }, 'Throws, in order:'), ...groups.map((g) => h('span', { class: 'row tight', title: dieCaption(g) },
				creatureDieImage(active, g.index, g.shape, 44), h('span', { class: 'small text-2' }, `${g.label ? g.label + ' ' : ''}${g.shape.toLowerCase()}${g.count > 1 ? ` ×${g.count}` : ''}`)))))))));
	const job = ctx.engine.run('creatureTurn', { key: active, depth, party, turn: state.turn, action: state.action, mineKey, emerging: canEmerge && state.emerging, samples: 6000 });
	const statsSlot = h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(7, minmax(0,1fr))' } });
	detail.append(statsSlot);
	whenReady(ctx, statsSlot, job, (r) => h('div', { style: { display: 'contents' } },
		stat('Health', String(r.hp), `base ${def.hp} × depth × party × mine`, { class: 'accent' }), stat('Block', String(def.block ?? 0), 'to start'),
		stat('Damage an action', fmt(r.meanDamage, 2), `action ${r.action}, to its target, before block`),
		stat('Damage ×', `${fmt(r.damagePct / 100, 2)}`, `${mine.name || mineKey} ×${fmt(r.damageMult, 2)}${traits.rising ? ` · rising +${traits.rising}%/action` : ''}`),
		stat('Damage bonus', `+${r.damageBonus}`, `depth ÷ ${C.constant('depth_damage_every', 4)}, per die${traits.escalate ? ` · +${traits.escalate} an action` : ''}`),
		stat('Enrage', r.enrage ? `+${r.enrage}` : '—', `from turn ${C.constant('enrage_turn', 7)}`), stat('Threat', String(def.threat), 'against the encounter budget')));
	const g = h('div', { class: 'grid grid-2' });
	detail.append(g);
	const movesSlot = h('div'), histSlot = h('div');
	g.append(card('Dice and faces', movesSlot, { meta: `a move a face · fires per action, sampled · action ${state.action}` }));
	g.append(card('Damage in one action', histSlot, { meta: 'to its target, before block' }));
	whenReady(ctx, movesSlot, job, (r) => h('div', { class: 'moves' }, ...facesView(def, active, groups, r)));
	whenReady(ctx, histSlot, job, (r) => histogram({ bins: r.damageHist, width: 420, height: 190, color: '#e0473c', mean: r.meanDamage, xLabel: 'damage', xFormat: (v) => String(v) }));
	const depths = Array.from({ length: 28 }, (_, i) => i + 1);
	detail.append(h('div', { class: 'grid grid-2' },
		card('Health by depth', lines({ series: [1, 2, 3, 4].map((p, i) => ({ key: p, label: `party of ${p}`, color: PARTY_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.creatureHp(def, d, p, mine) })) })), width: 420, height: 180, xFormat: (d) => String(d), format: (v) => fmt(v, 0), markers: false }), { meta: `+${fmt(Number(C.constant('depth_hp_scale', 0.05)) * 100, 0)}% a depth, × the party's size, ×${fmt(Number(mine.hp_mult ?? 1), 1)} here` }),
		card('Traits and dice', h('div', { class: 'col' }, kv([
			['Traits', traitText(traits)],
			['Escorts', escorts.length ? escortText(escorts) : 'none'],
			['Echo', def.echo ? `copies a random ordinary creature from ${(def.echo.mines || []).map((m) => C.mine(m).name || m).join(', ')}` : 'no'],
			['Summoned only', def.summon_only ? 'yes: never drawn from a band' : 'no'],
			['Dice', groups.map(dieCaption).join(' · ') || 'none']]),
			...groups.map((gr) => h('div', { class: 'row' }, h('span', { class: 'small muted', style: { width: '64px' } }, `${gr.label || 'die'} ${gr.shape.toLowerCase()}`),
				h('div', { class: 'mark-row' }, gr.names.map((name, i) => { const m = moves.find((x) => x.name === name) || {}; return markChip(m.mark || '', m.kind || 'dud', 24, `face ${i + 1}: ${name}`); })))),
			note("Every face of its dice is one of its moves: each die lands on a face, and that face's move fires. A match fires once an action when its faces land together; a move on no face waits for a face to be etched to it, and a called one for the fight (coming up, dying). Damage is pct(amount, mine × rising) + depth bonus (+ escalation) + rally + enrage; the words show the numbers as written.", 'plain')))));
}

// Every die's moves as rows (mark, name and number, words, a pip a face, how often it fires),
// then the matches, the moves on no face, and the moves the fight calls.
function facesView(def, key, groups, r) {
	const moves = def.moves || [];
	const sampled = (name) => r.moves[moves.findIndex((m) => m.name === name)] || null;
	const rate = (s) => (s ? [h('div', { class: 'fm-rate' }, `${fmt(s.fireRate, s.fireRate > 0 && s.fireRate < 0.1 ? 3 : 2)}× an action`), moveNote(s) ? h('div', { class: 'tiny muted' }, moveNote(s)) : null] : []);
	const row = (move, right, extra = '') => {
		const kind = move.kind || 'attack';
		const n = moveNumber(move);
		return h('div', { class: 'face-move' }, markChip(move.mark || '', kind, 30, move.name),
			h('div', {}, h('div', { class: 'fm-head' }, h('b', { style: kind === 'dud' ? { color: MOVE_INK.dud } : null }, move.name), n ? h('span', { class: 'fm-num', style: { color: MOVE_INK[kind] } }, n) : null,
				move.dramatic ? chip('dramatic', { class: 'accent' }) : null, extra ? h('span', { class: 'fm-note' }, `· ${extra}`) : null),
			h('div', { class: 'fm-words' }, ...keywords(moveWords(move)))),
			h('div', { class: 'fm-right' }, ...right));
	};
	const out = [];
	const onFaces = new Set();
	for (const g of groups) {
		out.push(h('div', { class: 'die-head' }, creatureDieImage(key, g.index, g.shape, 36), h('span', { class: 'die-cap' }, dieCaption(g))));
		const order = [];
		for (const name of g.names) if (!order.includes(name)) order.push(name);
		for (const name of order) {
			onFaces.add(name);
			const move = moves.find((m) => m.name === name);
			if (!move) continue;
			const count = g.names.filter((n) => n === name).length;
			out.push(row(move, [pips(count, move.kind || 'attack'), h('div', { class: 'tiny muted' }, `${count} of ${g.names.length}${g.count > 1 ? ` ×${g.count}` : ''}`), ...rate(sampled(name))]));
		}
	}
	const matches = moves.filter((m) => (m.trigger || {}).kind === 'match');
	const waiting = moves.filter((m) => ((m.trigger || {}).kind || 'face') === 'face' && !onFaces.has(m.name));
	const called = moves.filter((m) => !['face', 'match'].includes((m.trigger || {}).kind || 'face'));
	if (matches.length) out.push(h('div', { class: 'face-sub' }, 'Faces together'));
	for (const move of matches) {
		const t = move.trigger || {};
		const wanted = Number(t.count || 0) > 0 ? Array.from({ length: Number(t.count) }, () => String((t.faces || [])[0])) : (t.faces || []).map(String);
		const needs = h('span', { class: 'fm-needs', title: `Fires when these land together: ${wanted.join(', ')}` }, wanted.map((n) => { const m = moves.find((x) => x.name === n) || {}; return markChip(m.mark || '', m.kind || 'dud', 18, n); }));
		out.push(row(move, [needs, ...rate(sampled(move.name))]));
	}
	if (waiting.length) out.push(h('div', { class: 'face-sub' }, 'Not on a face yet'));
	for (const move of waiting) {
		const from = etchedBy(def, move.name);
		out.push(row(move, [h('div', { class: 'tiny muted' }, 'on no face')], from ? `from ${from}` : ''));
	}
	if (called.length) out.push(h('div', { class: 'face-sub' }, 'Called by the fight'));
	for (const move of called) out.push(row(move, rate(sampled(move.name)), triggerWords(move, def).toLowerCase()));
	return out;
}
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
	whenReady(ctx, statsSlot, job, (r) => h('div', { style: { display: 'contents' } }, stat('Threat budget', fmt(r.budget, 1), `3 + 0.6 × depth${state.elite ? ', × 1.5' : ''}, any party`, { class: 'accent' }), stat('Creatures', fmt(r.counts.reduce((s, [k, p]) => s + k * p, 0), 2), `mean; at most ${Forge.ENCOUNTER_MOST} drawn, ${C.constant('max_creatures', 4)} standing`),
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
// bottom, or the Rift's rotation with the Infinite Void every so often.
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
	const budgetSeries = [[false, 'a fight'], [true, 'an elite']].map(([elite, label], i) => ({ key: label, label, color: PARTY_COLORS[i], points: depths.map((d) => ({ x: d, y: Forge.encounterBudget(d, 1, elite) })) }));
	root.append(h('div', { class: 'grid grid-2' },
		card('Threat budget by depth', lines({ series: budgetSeries, width: 480, height: 200, xFormat: (d) => String(d), format: (v) => fmt(v, 1), markers: false }), { meta: `any party: at most ${Forge.ENCOUNTER_MOST} creatures, each with health × the party` }),
		card('Threat costs', table({ columns: [{ key: 'name', label: 'Creature', render: (r) => h('span', { class: 'cell-name' }, creatureImage(r.key, 28), r.name) }, { key: 'threat', label: 'Threat', align: 'right' }, { key: 'hp', label: 'Base HP', align: 'right' }, { key: 'perThreat', label: 'HP per threat', align: 'right', render: (r) => fmt(r.perThreat, 1) }, { key: 'dice', label: 'Dice' }, { key: 'traits', label: 'Traits' }],
			rows: C.keys('creatures').map((k) => ({ key: k, name: C.creature(k).name, threat: C.creature(k).threat, hp: C.creature(k).hp, perThreat: C.creature(k).hp / Math.max(1, C.creature(k).threat), dice: diceText(C.creature(k)), traits: traitText(traitsFor(C.creature(k), 0)).replace(/^none$/, '') })).sort((a, b) => a.threat - b.threat), compact: true, rowKey: (r) => r.key, onRowClick: (r) => { state.tab = 'creatures'; ctx.navigate('enemies', r.key); } }))));
}
