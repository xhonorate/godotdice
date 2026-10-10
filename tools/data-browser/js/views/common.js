// Pieces several pages share: the bowl and depth controls, rank colours, chips, async slots.

import * as C from '../sim/content.js';
import * as Dice from '../sim/dice.js';
import { h, select, segmented, field, numberInput, chip, fmtPct } from '../ui.js';
import { markColor, colorKeyMark, dieImage } from '../gemart.js';

// Ordinal ramps on one hue: Cut (Poor → Perfect) and Grade (Rough → Peerless) brighten as they rise.
export const CUT_COLORS = ['#5a4a22', '#7d652a', '#a38434', '#c9a43e', '#f0c95a'];
export const GRADE_COLORS = ['#4d4d55', '#7d652a', '#a38434', '#c9a43e', '#f0c95a'];
// Clarity diverges from Clear: the included tail warm, the pure tail cool, Clear a neutral grey.
export const CLARITY_COLORS = ['#c96a2a', '#c98a3e', '#b39a6a', '#6f7683', '#6f9fe0', '#3f7fe0'];
export const RARITY_COLORS = { COMMON: '#8a93a3', UNCOMMON: '#4fae7a', RARE: '#4a8fe0', LEGENDARY: '#c98a2a', MYTHIC: '#b98fe6', TRANSCENDENT: '#e9b94a' };
export const CHAMBER_COLORS = { fight: '#c0463c', elite: '#8b2f2a', vein: '#c9a43e', motherlode: '#f0c95a', oddity: '#8b5fd6', merchant: '#3f7fe0', smithy: '#7f8896', carver: '#b4bcc8', well: '#3fb56b' };

export const cutNames = () => C.cuts().map((c) => c.name);
export const clarityNames = () => C.clarities().map((c) => c.name);

export function rarityChip(rarity) { return chip(C.title(rarity), { color: RARITY_COLORS[rarity] || '#8a93a3' }); }
export function colorChip(colorKey) { return h('span', { class: 'chip' }, colorKeyMark(colorKey), C.colorName(colorKey)); }
export function kindChip(text) { return chip(text); }

export const BOWL_PRESETS = () => {
	const out = Object.entries(C.section('characters')).map(([key, def]) => [key, `${def.name}'s bowl`, def.dice]);
	out.push(['FIVE_D6', 'Five d6', ['D6', 'D6', 'D6', 'D6', 'D6']], ['FIVE_D8', 'Five d8', ['D8', 'D8', 'D8', 'D8', 'D8']], ['FIVE_D12', 'Five d12', ['D12', 'D12', 'D12', 'D12', 'D12']], ['FIVE_D20', 'Five d20', ['D20', 'D20', 'D20', 'D20', 'D20']]);
	return out;
};

// The bowl every hand is rolled from, shared by the skills, dice and lapidary pages.
export function bowlControls(ctx, { showRerolls = true, showSamples = false } = {}) {
	const s = ctx.settings;
	const presets = BOWL_PRESETS();
	const current = presets.find((p) => p[2].join() === s.bowl.join());
	const presetSel = select([['CUSTOM', 'Custom bowl'], ...presets.map((p) => [p[0], p[1]])], current ? current[0] : 'CUSTOM', (key) => {
		const p = presets.find((x) => x[0] === key);
		if (p) ctx.setSetting('bowl', p[2].slice());
	});
	const dieOptions = Dice.TIERS.filter((k) => Object.keys(C.die(k)).length).map((k) => [k, C.die(k).name || k]);
	const dieRow = h('div', { class: 'row tight' }, s.bowl.map((key, i) => h('span', { class: 'row tight' }, dieImage(key, 26), select(dieOptions, key, (v) => { const bowl = s.bowl.slice(); bowl[i] = v; ctx.setSetting('bowl', bowl); }, { class: 'select small', style: 'width:104px' }))));
	const items = [field('Bowl', presetSel), field('Dice', dieRow)];
	if (showRerolls) items.push(field('Rerolls', segmented([[0, '0'], [1, '1'], [2, '2'], [3, '3']], s.rerolls, (v) => ctx.setSetting('rerolls', Number(v))), 'Rerolls are spent chasing each gem’s own trigger'));
	if (showSamples) items.push(field('Hands', segmented([[1000, '1k'], [4000, '4k'], [12000, '12k']], s.samples, (v) => ctx.setSetting('samples', Number(v))), 'Sampled hands per estimate'));
	return items;
}

export function depthControls(ctx, { showParty = true, showMine = true, max = 40 } = {}) {
	const s = ctx.settings;
	const items = [];
	if (showMine) items.push(field('Mine', select(C.keys('mines').map((k) => [k, C.mine(k).name || k]), s.mine, (v) => ctx.setSetting('mine', v))));
	items.push(field('Depth', numberInput(s.depth, (v) => ctx.setSetting('depth', Math.max(1, Math.min(max, v || 1))), { min: 1, max })));
	if (showParty) items.push(field('Party', segmented([[1, '1'], [2, '2'], [3, '3'], [4, '4']], s.party, (v) => ctx.setSetting('party', Number(v)))));
	return items;
}

export function bowlSummary(bowl) {
	const dice = bowl.map((k, i) => Dice.dieFrom(k, `d${i}`));
	const maxTotal = dice.reduce((s, d) => s + Dice.top(d), 0);
	const mean = dice.reduce((s, d) => { let m = 0; for (const [v, p] of Dice.faceDistribution(d)) m += (v === 'mirror' ? Dice.top(d) * 0.7 : v) * p; return s + m; }, 0);
	return { maxTotal, mean };
}

// Fill `slot` with the result of a promise, keeping a spinner in it meanwhile and dropping the
// answer if the page has been rebuilt since.
export function whenReady(ctx, slot, promise, build, { min = 60 } = {}) {
	slot.append(h('div', { class: 'loading', style: { minHeight: `${min}px` } }, h('span', { class: 'spinner' }), 'sampling…'));
	promise.then((result) => {
		if (!ctx.alive()) return;
		slot.replaceChildren();
		const built = build(result);
		if (built) slot.append(built);
	}).catch((error) => {
		if (!ctx.alive()) return;
		console.error(error);
		slot.replaceChildren(h('div', { class: 'error' }, String(error.message || error)));
	});
	return slot;
}

export const pct = (v, places = 0) => fmtPct(v, places);
export const cutColorFor = (i) => CUT_COLORS[Math.max(0, Math.min(4, i))];
export const colorOf = (skillKey) => markColor(C.skill(skillKey).color || 'WHITE');

// Tabs with the active one in the route params, so a tab survives a reload.
export function tabs(options, active, onChange) {
	return h('div', { class: 'tabs', role: 'tablist' }, options.map(([key, label]) => h('button', { type: 'button', class: `tab${key === active ? ' is-active' : ''}`, role: 'tab', 'aria-selected': key === active ? 'true' : 'false', onClick: () => onChange(key) }, label)));
}

export function socketRow(sockets) {
	return h('div', { class: 'socket-row' }, sockets.map((s) => h('span', { class: `socket${s === 'ANY' ? ' any' : ''}`, title: s === 'ANY' ? 'Any colour' : C.colorName(s), style: s === 'ANY' ? null : { borderColor: markColor(s), background: `${markColor(s)}22` } }, s === 'ANY' ? h('span', { class: 'tiny muted' }, 'any') : colorKeyMark(s, 14))));
}

// The mark every etched face wears, the same glyphs the game draws.
export const FACE_MARKS = { wild: '★', exploding: '!', shiny: '✦', golden: '¤', tally: '↑', sticky: '▣', twin: '‖', doubled: '²', locked: '⌂', blank: '' };

export function faceRow(def, die = null) {
	const faces = die && die.faces ? die.faces : Dice.facesOf(def);
	return h('div', { class: 'face-row' }, faces.map((f) => {
		const kind = f.kind || 'plain';
		const mark = FACE_MARKS[kind] || '';
		const text = kind === 'blank' ? '·' : kind === 'wild' ? '★' : `${f.value}${mark}`;
		return h('span', { class: `face${kind !== 'plain' ? (kind === 'blank' ? ' blank' : ' special') : ''}`, title: kind !== 'plain' ? `${Dice.etchingName(kind)}: ${C.etching(kind).text || ''}` : null }, text);
	}));
}
