// The Descent: the shaft's shape, what each depth's chambers are likely to be, and what the
// mine charges and pays as the party goes down.

import * as C from '../sim/content.js';
import * as Forge from '../sim/forge.js';
import { makeRng } from '../sim/rng.js';
import { h, card, stat, table, fmt, fmtPct, toolbar, note, kv, field, numberInput } from '../ui.js';
import { lines, stacked, columns } from '../charts.js';
import { depthControls, CHAMBER_COLORS, CUT_COLORS } from './common.js';

const PARTY_COLORS = ['#f0c95a', '#c9a43e', '#a38434', '#7d652a'];

// A port of Descent._chart (sim/descent.gd): charts one stretch, landing to landing, as a
// lattice of chambers two mouths wide at the top and a mouth wider each depth. Distributions
// match the game's; sample order doesn't, since this draws from the browser's own seeded rng.
const CARD_ROOMS = ['smithy', 'carver', 'well'];
const DICE_ROOMS = ['smithy', 'carver'];
const MAP_WIDEST = 4;

// A port of Descent.plan_shaft (sim/descent.gd): every landing wanders a floor either way
// (its Warden goes with it) so nobody can count steps to the next one; the last landing never
// moves, since the last Warden always guards the last floor.
function planShaft(rng) {
	const every = Number(C.constant('landing_every', 4));
	const bottom = Number(C.constant('run_depth', 24));
	const landings = [];
	let at = 0, index = 0;
	while (at < bottom) {
		index += 1;
		const nominal = index * every;
		if (nominal >= bottom) { landings.push(bottom); break; }
		const jittered = nominal + rng.randiRange(-1, 1);
		landings.push(Math.min(bottom - 2, Math.max(at + 2, jittered)));
		at = landings[landings.length - 1];
	}
	const wardenDepths = C.constant('warden_depths', [8, 16, 24]);
	const wardens = [];
	for (const written of wardenDepths) {
		const which = Math.round(Number(written) / every) - 1;
		if (which >= 0 && which < landings.length && !wardens.includes(landings[which])) wardens.push(landings[which]);
	}
	return { landings, wardens };
}

function runIsLanding(schedule, depth) {
	const listed = schedule.landings;
	if (!listed.length || depth > listed[listed.length - 1]) return Forge.isLanding(depth);
	return listed.includes(depth);
}

function runIsWarden(schedule, depth) {
	const listed = schedule.wardens;
	if (!listed.length) return Forge.isWarden(depth);
	if (listed.includes(depth)) return true;
	return depth > Number(C.constant('run_depth', 24)) && Forge.isWarden(depth);
}

function chartStretch(mine, from, to, rng, schedule) {
	const weights = mine.chambers || { fight: 48, elite: 12, vein: 18, oddity: 14, merchant: 8, smithy: 6, carver: 6, well: 5 };
	const nodes = {};
	const rows = [];
	let width = 2;
	for (let depth = from + 1; depth < to; depth++) {
		const row = [];
		const once = [];
		let dark = false;
		for (let index = 0; index < width; index++) {
			const t = { ...weights };
			if (depth <= 2) delete t.elite;
			if (depth <= 1) delete t.merchant;
			for (const kept of once) delete t[kept];
			let kind = rng.weightedKey(t);
			if (!kind) kind = 'fight';
			if (kind === 'vein' && rng.chance(Number(mine.motherlode_pct ?? 3))) kind = 'motherlode';
			if (['elite', 'oddity', 'merchant'].includes(kind) || CARD_ROOMS.includes(kind)) once.push(kind);
			const lane = Math.max(0.06, Math.min(0.94, (index + 0.5) / width + (rng.randf() * 0.56 - 0.28) / width));
			const id = `n${depth}_${index}`;
			const hidden = depth > 1 && !dark && rng.chance(22.0);
			dark = dark || hidden;
			nodes[id] = { id, depth, x: lane, kind, hidden, next: [] };
			row.push(id);
		}
		rows.push(row);
		width = Math.min(width + 1, MAP_WIDEST);
	}
	const stalls = Object.values(nodes).filter((n) => n.kind === 'merchant');
	if (!stalls.length && rows.length >= 2) {
		const swappable = rows[1].filter((id) => ['fight', 'vein'].includes(nodes[id].kind));
		if (swappable.length) nodes[rng.pick(swappable)].kind = 'merchant';
	}
	const benches = Object.values(nodes).filter((n) => DICE_ROOMS.includes(n.kind));
	if (!benches.length && rows.length) {
		const last = rows[rows.length - 1].filter((id) => ['fight', 'vein'].includes(nodes[id].kind));
		if (last.length) nodes[rng.pick(last)].kind = rng.pick(DICE_ROOMS);
	}
	for (let r = 0; r < rows.length - 1; r++) {
		const above = rows[r], below = rows[r + 1];
		const m = above.length, n = below.length;
		let reach = 0;
		for (let i = 0; i < m; i++) {
			const lo = Math.max(reach, Math.floor((i * (n - 1)) / m));
			const hi = Math.max(lo, Math.ceil(((i + 1) * (n - 1)) / m));
			for (let j = lo; j <= Math.min(hi, n - 1); j++) nodes[above[i]].next.push(below[j]);
			reach = hi;
		}
	}
	const landingId = `landing_${to}`;
	if (rows.length) for (const id of rows[rows.length - 1]) nodes[id].next.push(landingId);
	nodes[landingId] = { id: landingId, depth: to, x: 0.5, kind: 'landing', hidden: false, next: [], warden: runIsWarden(schedule, to) };
	return { from, to, nodes, rows };
}

// Charts every stretch from the mouth down to maxDepth, landing after landing, the way a run
// charts each stretch only once the party reaches its head. The landings themselves are laid
// out first (plan_shaft), so their wander is fixed before any stretch between them is drawn.
function buildShaft(mine, maxDepth, rng) {
	const schedule = planShaft(rng);
	const stretches = [];
	let from = 0;
	while (from < maxDepth) {
		let to = from + 1;
		while (!runIsLanding(schedule, to)) to += 1;
		stretches.push(chartStretch(mine, from, to, rng, schedule));
		from = to;
	}
	return stretches;
}

function nodesByDepth(stretches) {
	const byDepth = {};
	for (const st of stretches) for (const id in st.nodes) {
		const n = st.nodes[id];
		(byDepth[n.depth] ||= []).push(n);
	}
	for (const depth in byDepth) byDepth[depth].sort((a, b) => a.x - b.x);
	return byDepth;
}

function findNode(stretches, id) {
	for (const st of stretches) if (st.nodes[id]) return st.nodes[id];
	return null;
}

// What an unlit chamber gives away in-game (Descent.glint): the party can tell a mouth is
// hostile, glittering or strange before they've charted it, or dark if it hides even that.
const GLINTS = { fight: 'hostile', elite: 'hostile', warden: 'hostile', vein: 'glittering', motherlode: 'glittering', oddity: 'strange', merchant: 'strange', smithy: 'strange', carver: 'strange', well: 'strange' };
const CHAMBER_TEXT = {
	fight: 'A fight. Pays ore on a win.', elite: 'An elite fight: a tougher band, double ore, +4 luck on any stone drop.',
	warden: 'The Warden hall at the foot of this stretch: a boss fight guarding the landing, a hoard of three raw stones (the last an opal) on a win.',
	vein: 'A vein: dig for ore, or gamble it for a raw stone.', motherlode: 'A motherlode vein: three raw stones instead of one.',
	oddity: 'An oddity: a one-off event or choice.', merchant: 'A merchant: sells 3 appraised stones, buys scales at half worth.',
	smithy: 'A smithy: work a die.', carver: 'A carver: work a stone.', well: 'A wishing well.', landing: 'A landing: fire, workbench, wheel, lift.',
};
const CHAMBER_ICONS = {
	fight: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 20 20 4M14 4h6v6M4 20l3-3"/></svg>',
	elite: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 20 20 4M14 4h6v6"/><circle cx="12" cy="12" r="9"/></svg>',
	warden: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 18h16M5 18 4 8l5 4 3-7 3 7 5-4-1 10Z"/></svg>',
	vein: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3 21 9l-9 12L3 9Z"/></svg>',
	motherlode: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M8 2 13 7 8 12 3 7Z"/><path d="M15 10 21 15 15 21 9 15Z"/></svg>',
	oddity: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3a9 9 0 1 0 9 9"/><path d="M12 8v4l3 2"/><path d="M19 3v4h-4"/></svg>',
	merchant: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M6 8h12l1 13H5Z"/><path d="M9 8a3 3 0 0 1 6 0"/></svg>',
	smithy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M13 3 21 11l-3 3-8-8Z"/><path d="M10 8 3 15l3 3 7-7"/><path d="M3 18l-1 3 3-1"/></svg>',
	carver: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M5 19 16 8l3 3L8 22Z"/><path d="M16 8l3-3 2 2-3 3"/></svg>',
	well: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3c3 4 5 7 5 10a5 5 0 1 1-10 0c0-3 2-6 5-10Z"/></svg>',
	landing: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 20h16M6 20V9l6-5 6 5v11"/><path d="M10 20v-6h4v6"/></svg>',
};
const iconFor = (n) => CHAMBER_ICONS[n.kind === 'landing' && n.warden ? 'warden' : n.kind] || CHAMBER_ICONS.fight;
const colorFor = (n) => n.kind === 'landing' ? (n.warden ? 'var(--accent)' : 'var(--surface-3)') : CHAMBER_COLORS[n.kind] || '#888';
const labelFor = (n) => n.kind === 'landing' ? (n.warden ? 'Warden hall' : 'Landing') : C.title(n.kind);

function nodeCard(node, stretches) {
	const leadsTo = node.next.map((id) => findNode(stretches, id)).filter(Boolean);
	const rows = [['Glint before charted', node.hidden ? 'dark (nothing shows until lit or reached)' : C.title(GLINTS[node.kind] || 'strange')],
		['Leads to', leadsTo.length ? leadsTo.map((n) => `${labelFor(n)} (depth ${n.depth})`).join(', ') : '—']];
	if (node.kind === 'fight' || node.kind === 'elite' || node.kind === 'warden') rows.push(['Ore on a win', fmt(Forge.fightOre(node.depth, node.kind), 0)]);
	const color = colorFor(node);
	return h('section', { class: 'card', style: { borderLeft: `3px solid ${color}` } },
		h('header', { class: 'card-head' }, h('span', { class: 'chamber-icon', style: { color }, html: iconFor(node) }), h('h3', { class: 'card-title' }, labelFor(node)), node.hidden ? h('span', { class: 'card-meta' }, 'dark mouth') : null),
		h('div', { class: 'card-body' }, kv(rows), h('p', { class: 'small text-2' }, CHAMBER_TEXT[node.kind] || '')));
}

const shaftState = { mine: null, stretches: null, targetDepth: null };

export default {
	id: 'descent', label: 'The Descent', blurb: 'Chambers, landings, Wardens and costs by depth', count: () => C.keys('mines').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3v18M12 21l-4-4M12 21l4-4"/><path d="M5 7h14M7 12h10"/></svg>',
	render(root, route, ctx) {
		const mine = C.mine(ctx.settings.mine);
		const runDepth = Number(C.constant('run_depth', 24));
		if (shaftState.mine !== ctx.settings.mine) { shaftState.mine = ctx.settings.mine; shaftState.stretches = null; if (shaftState.targetDepth == null) shaftState.targetDepth = runDepth + 8; }
		if (shaftState.targetDepth == null) shaftState.targetDepth = runDepth + 8;
		const depths = Array.from({ length: shaftState.targetDepth }, (_, i) => i + 1);
		const targetField = field('Generate to depth', numberInput(shaftState.targetDepth, (v) => {
			shaftState.targetDepth = Math.max(1, Math.min(999, v || 1));
			shaftState.stretches = null;
			ctx.rerender();
		}, { min: 1, max: 999, class: 'input', style: 'width:70px' }));
		const regenBtn = h('button', { type: 'button', class: 'btn', onClick: () => {
			shaftState.stretches = buildShaft(mine, depths[depths.length - 1], makeRng(Math.floor(Math.random() * 1e9) + 1));
			ctx.rerender();
		} }, shaftState.stretches ? 'Regenerate the shaft' : 'Simulate the shaft');
		root.append(toolbar(...depthControls(ctx, { max: Math.max(40, shaftState.targetDepth) }), targetField, regenBtn));
		let shaft;
		const gotoDepth = (d) => ctx.setSetting('depth', Math.max(1, Math.min(depths[depths.length - 1], d)));
		if (shaftState.stretches) {
			const byDepth = nodesByDepth(shaftState.stretches);
			shaft = h('div', { class: 'shaft', style: { gridTemplateColumns: `repeat(${depths.length}, 1fr)` } }, depths.map((d) => {
				const here = byDepth[d] || [];
				const landing = here.some((n) => n.kind === 'landing'), warden = here.some((n) => n.kind === 'landing' && n.warden);
				const titles = here.map((n) => `${labelFor(n)}${n.hidden ? ' (dark mouth)' : ''}`).join(' · ');
				return h('div', { class: `shaft-cell${landing ? ' landing' : ''}${warden ? ' warden' : ''}${d === ctx.settings.depth ? ' is-current' : ''}`, style: { cursor: here.length ? 'pointer' : 'default' }, title: `${d}: ${titles || 'no chambers charted'}`, onClick: () => here.length && gotoDepth(d) },
					h('div', { class: 'node-stack' }, here.map((n) => h('i', { class: `node-dot${n.hidden ? ' hidden' : ''}`, style: { background: colorFor(n) } }))),
					h('span', {}, String(d)));
			}));
		} else {
			shaft = h('div', { class: 'shaft', style: { gridTemplateColumns: `repeat(${depths.length}, 1fr)` } }, depths.map((d) => {
				const landing = Forge.isLanding(d), warden = Forge.isWarden(d);
				const band = Forge.bandFor(mine, d);
				return h('div', { class: `shaft-cell${landing ? ' landing' : ''}${warden ? ' warden' : ''}${d === ctx.settings.depth ? ' is-current' : ''}`, style: { cursor: 'pointer' }, title: `${d}: ${warden ? 'Warden hall (nominal, wanders ±1)' : landing ? 'landing (nominal, wanders ±1)' : 'chambers'} · luck ${fmt(Forge.luck(mine, d), 1)} · band from ${band.from_depth ?? 1}`, onClick: () => gotoDepth(d) },
					h('i', { style: { background: warden ? 'var(--accent)' : landing ? 'var(--surface-3)' : d > runDepth ? '#3a2a44' : `hsl(${220 - (d / runDepth) * 40} 25% ${34 - (d / runDepth) * 14}%)`, opacity: 0.85 } }), h('span', {}, String(d)));
			}));
		}
		root.append(card('The shaft', h('div', { class: 'col' }, shaft, h('div', { class: 'legend' }, h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: 'var(--accent)' } }), 'Warden hall (keeps its cage; a hoard of three raw stones, the last an opal)'), h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: 'var(--surface-3)', outline: '2px solid var(--text-2)' } }), 'Landing: fire, workbench, wheel, lift'), shaftState.stretches ? Object.entries(CHAMBER_COLORS).map(([k, c]) => h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: c } }), C.title(k))) : h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: '#3a2a44' } }), `Endless, below ${runDepth}; a Warden every ${C.constant('endless_warden_every', 8)}`)),
			note(shaftState.stretches ? `An actual chart of this shaft, drawn just now: each column is a depth, each dot a chamber that depth's mouths lead to (a hatched dot is a dark mouth). Every landing (and the Warden guarding it) wandered a floor either way from its nominal spot when this shaft was planned, so the columns marked landing/warden above are this run's real placement, not the nominal one. Click a column to send the Depth field there and see its chambers below. Click "Regenerate the shaft" for another draw.` : `A stretch runs between landings: its chambers fan out two mouths wide at the top and a mouth wider each depth, every chamber leading to the two nearest below. Each stretch holds at least one merchant (the second depth trades a fight or vein for a stall if none was drawn) and a smithy or carver on its last depth. At most one dark mouth a depth (22% each). The landing/Warden columns shown below are only the nominal, unjittered spacing — every real run wanders each landing a floor either way (its Warden goes with it) and pins only the last one. Click "Simulate the shaft" to chart an actual run and see where they really land.`, 'plain')), { meta: `${mine.name || ctx.settings.mine} · landings every ${C.constant('landing_every', 4)} (±1 a run)` }));

		if (shaftState.stretches) {
			const here = (nodesByDepth(shaftState.stretches)[ctx.settings.depth] || []);
			root.append(card(`Chambers at depth ${ctx.settings.depth}`, here.length ? h('div', { class: 'grid grid-3' }, here.map((n) => nodeCard(n, shaftState.stretches))) : note('Not charted at this depth — click a lit column above, or regenerate.', 'plain'), { meta: `${here.length} mouth${here.length === 1 ? '' : 's'}` }));
		}

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
			kv([['Dice in the rock', (mine.dice || []).length ? mine.dice.join(', ') : 'all'], ['Skills in the rock', (mine.skills || []).length ? mine.skills.join(', ') : 'all'], ['Inclusions in the rock', (mine.inclusions || []).length ? mine.inclusions.join(', ') : 'all'], ['A second variation', `${fmt(Forge.secondAxisChance(mine, ctx.settings.depth), 1)}% at depth ${ctx.settings.depth}`]]),
			h('p', { class: 'small text-2' }, mine.text || ''))));
	},
};
