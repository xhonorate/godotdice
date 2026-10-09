// Balance: what every gem, Cut, Clarity, inclusion, lapidary and pairing is worth in a short
// fight against training dummies, on every lapidary's own bowl. The sweeps behind it run on
// every core (js/sweeps.js) and are kept in build/balance, so they are run once, not per
// visit; tools/data-browser/balance.mjs runs them from the command line.
//
// Every number is a value per turn: the rail's power less the empty rail's on the same bowl,
// where power weighs damage dealt, health saved and pyrite won by the exchange rates set on the
// Method tab. The rates apply as they change; the fight settings need the sweep run again.

import * as C from '../sim/content.js';
import * as Balance from '../sim/balance.js';
import * as Forge from '../sim/forge.js';
import * as Sweeps from '../sweeps.js';
import { h, card, stat, table, fmt, fmtPct, note, chip, field, segmented, select, numberInput, sortRows, toggleSort, progress, tipRow, tipTitle } from '../ui.js';
import { heatmap, heat, bars, SHAPES } from '../charts.js';
import { rangeStrip, matrix, dotColumns, diverge, rampKey } from '../balance-charts.js';
import { gemImage, inclusionImage, birthstoneImage, markColor, colorKeyMark } from '../gemart.js';
import { cutNames, tabs } from './common.js';

const STORE_KEY = 'deepcut.balance';
const TABS = [['gems', 'Gems'], ['cutclarity', 'Cut & Clarity'], ['inclusions', 'Inclusions'], ['lapidaries', 'Lapidaries'], ['pairs', 'Pairings'], ['opals', 'Opals'], ['method', 'Method & settings']];
const SWEEP_OF = { gems: 'gems', cutclarity: 'cutclarity', inclusions: 'inclusions', lapidaries: 'gems', pairs: 'pairs', opals: 'rails' };
const SWEEP_NAMES = { gems: 'Gems alone', cutclarity: 'Cuts and clarities', inclusions: 'Inclusions', pairs: 'Every pair', rails: 'Gems in a rail' };
const MEASURES = { solo: 'Alone', partner: 'Beside a partner', rail: 'In a rail' };
const PLACE_NAMES = ['1st', '2nd', '3rd', '4th', '5th', '6th'];
const CLASS_ORDER = ['PINPOINT', 'LENS', 'FEATHER', 'FRACTURE', 'STAR'];
const CLASS_COLORS = { PINPOINT: '#8a93a3', LENS: '#6f9fe0', FEATHER: '#4fae7a', FRACTURE: '#c96a2a', STAR: '#f0c95a' };

const saved = (() => { try { return JSON.parse(localStorage.getItem(STORE_KEY) || 'null') || {}; } catch { return {}; } })();
const state = {
	settings: { ...Balance.DEFAULTS, ...(saved.settings || {}), samples: { ...Balance.DEFAULTS.samples, ...((saved.settings || {}).samples || {}) } },
	weights: { ...Balance.DEFAULT_WEIGHTS, ...(saved.weights || {}) },
	tab: 'gems', gem: 'STRIKE', opal: 'DOUBLET', measure: 'solo', scale: 'own', lapView: 'relative', bowl: 'ALL', ccMeasure: 'cut', incUnit: 'turn', inclusion: '', lapGem: '', pair: null, pairShow: 'synergy', sort: null,
};
function keep() { try { localStorage.setItem(STORE_KEY, JSON.stringify({ settings: state.settings, weights: state.weights })); } catch { /* private window */ } }

// One listener for the life of the page: progress is drawn in place, a finished sweep redraws.
let hook = null;
let listening = false;
function listen() {
	if (listening) return;
	listening = true;
	let was = null;
	Sweeps.onChange((active) => {
		if (hook && active) hook.progress(active);
		if (was && !active && hook) hook.ctx.rerender();
		was = active;
	});
}

export default {
	id: 'balance', label: 'Balance', blurb: 'Gems, cuts, inclusions, lapidaries and pairings, measured', count: () => '',
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3v18M5 21h14M4 8h16"/><path d="m4 8-2.5 6a3 3 0 0 0 5 0Z"/><path d="m20 8-2.5 6a3 3 0 0 0 5 0Z"/></svg>',
	render(root, route, ctx) {
		listen();
		if (route.params.tab && TABS.some(([k]) => k === route.params.tab)) state.tab = route.params.tab;
		hook = { ctx, progress: () => {} };
		const pending = Balance.SWEEPS.filter((s) => !Sweeps.get(s));
		if (pending.length) Promise.all(pending.map((s) => Sweeps.load(s))).then((loaded) => { if (ctx.alive() && loaded.some(Boolean)) ctx.rerender(); });
		root.append(h('div', { class: 'row between' }, tabs(TABS, state.tab, (t) => ctx.navigate('balance', '', { tab: t })), weightChips(ctx)));
		const body = h('div', { class: 'col', style: { gap: '14px' } });
		root.append(body);
		const views = { gems: gemsTab, cutclarity: cutClarityTab, inclusions: inclusionsTab, lapidaries: lapidariesTab, pairs: pairsTab, opals: opalsTab, method: methodTab };
		views[state.tab](body, ctx);
	},
};

// --- shared pieces ------------------------------------------------------------------------------

const W = () => state.weights;
const turnsOf = (result) => Math.max(1, Number((result && result.settings && result.settings.turns) || state.settings.turns || 1));
const perTurn = (result, v) => v / turnsOf(result);
const bowlName = (k) => C.character(k).name || C.title(k);
const fmtV = (v) => (Number.isFinite(v) ? fmt(v, Math.abs(v) < 10 ? 1 : 0) : '—');
const signed = (v) => (Number.isFinite(v) ? `${v > 0 ? '+' : ''}${fmt(v, Math.abs(v) < 10 ? 1 : 0)}` : '—');
function orderedSkills() {
	return C.keys('skills').sort((a, b) => C.SKILL_COLORS.indexOf(C.skill(a).color) - C.SKILL_COLORS.indexOf(C.skill(b).color) || a.localeCompare(b));
}
function median(values) {
	const s = values.filter(Number.isFinite).sort((a, b) => a - b);
	if (!s.length) return NaN;
	return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
}
function quartiles(values) {
	const s = values.filter(Number.isFinite).sort((a, b) => a - b);
	const q = (p) => (s.length ? s[Math.min(s.length - 1, Math.max(0, Math.round(p * (s.length - 1))))] : NaN);
	return { q1: q(0.25), q3: q(0.75) };
}
function scaleField(ctx) {
	return field('Scale', segmented([['own', 'Per colour'], ['shared', 'Shared']], state.scale, (v) => { state.scale = v; ctx.rerender(); }),
		'Each colour on its own scale, to read a gem against its own kind; one scale to compare across colours');
}
const colorGroups = (fill) => C.SKILL_COLORS.map((color) => ({ key: color, label: C.colorName(color), color: markColor(color), shape: SHAPES[color], items: fill(color) }));

function weightChips(ctx) {
	const w = W();
	return h('div', { class: 'row tight' }, h('span', { class: 'tiny muted' }, 'Power ='),
		chip(`damage ×${fmt(w.damage, 2)}`), chip(`health saved ×${fmt(w.saved, 2)}`), chip(`pyrite ×${fmt(w.gold, 2)}`),
		h('button', { type: 'button', class: 'btn', onClick: () => ctx.navigate('balance', '', { tab: 'method' }) }, 'Change'));
}

// A tab's controls, and the run state of its sweep: progress while it runs, when it was run and
// against what, a button. Only the run state is redrawn as a sweep goes.
function sweepBar(ctx, sweep, controls = []) {
	const result = Sweeps.get(sweep);
	const active = Sweeps.running();
	const bar = h('div', { class: 'sweep-bar' });
	const wrap = h('div', { class: 'toolbar', style: { alignItems: 'center' } }, ...controls, h('span', { class: 'fill' }), bar);
	const draw = () => {
		const now = Sweeps.running();
		bar.replaceChildren();
		if (now) {
			const elapsed = (performance.now() - now.started) / 1000;
			const eta = now.done ? (elapsed / now.done) * (now.total - now.done) : NaN;
			bar.append(h('b', {}, `Playing ${SWEEP_NAMES[now.sweep]}…`), progress(now.done / Math.max(1, now.total)),
				h('span', { class: 'small muted' }, `${now.done}/${now.total} batches · ${fmt(elapsed, 0)}s${Number.isFinite(eta) ? ` · about ${fmt(eta, 0)}s to go` : ''}`),
				h('button', { type: 'button', class: 'btn', onClick: () => Sweeps.cancel() }, 'Cancel'));
			return;
		}
		if (result) {
			const when = new Date(result.created);
			bar.append(h('span', { class: 'small text-2', title: `${result.settings.samples} fights a rail · ${result.settings.turns} turns · took ${fmt(result.seconds || 0, 0)}s` },
				h('b', {}, SWEEP_NAMES[sweep]), ` · ${when.toLocaleDateString([], { month: 'short', day: 'numeric' })} ${when.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`));
			const stale = staleness(sweep, result);
			for (const s of stale) bar.append(h('span', { class: 'flag low', title: s.detail }, s.label));
		} else bar.append(h('span', { class: 'small text-2' }, `${SWEEP_NAMES[sweep]} has not been run yet. About ${estimate(sweep)}.`));
		bar.append(h('button', { type: 'button', class: `btn${result ? '' : ' primary'}`, disabled: Boolean(active),
			onClick: () => runSweep(ctx, sweep) }, result ? 'Run again' : 'Run'));
	};
	hook.progress = draw;
	draw();
	return wrap;
}

function staleness(sweep, result) {
	const out = [];
	if (result.packHash && result.packHash !== Sweeps.packHash()) out.push({ label: 'content changed since', detail: 'content/deep_cut.json has changed since this sweep was run' });
	const now = Balance.sweepSettings(state.settings, sweep);
	const was = result.settings || {};
	const differs = Object.keys(now).filter((k) => JSON.stringify(now[k]) !== JSON.stringify(was[k]));
	if (differs.length) out.push({ label: 'other fight settings', detail: `played with different ${differs.join(', ')}` });
	return out;
}

const estimates = new Map();
function estimate(sweep) {
	const memo = `${sweep}:${JSON.stringify(Balance.sweepSettings(state.settings, sweep))}`;
	if (!estimates.has(memo)) estimates.set(memo, estimateNow(sweep));
	return estimates.get(memo);
}
function estimateNow(sweep) {
	const tasks = Balance.tasksFor(sweep, state.settings, { leads: {} });
	let micros = 0;
	for (const t of tasks) for (const r of t.rails) micros += t.settings.samples * (120 + 60 * r.stones.length) * (t.settings.turns / 4);
	// Logical cores share their silicon: a pool of them goes about a third as fast as its count.
	const seconds = 3 + micros / 1e6 / Math.max(1, 0.3 * (navigator.hardwareConcurrency || 4));
	return seconds < 60 ? `${Math.max(5, Math.round(seconds / 5) * 5)} seconds` : `${Math.round(seconds / 60)} minute${Math.round(seconds / 60) === 1 ? '' : 's'}`;
}

async function runSweep(ctx, sweep) {
	try {
		const context = {};
		if (sweep === 'pairs' || sweep === 'rails') {
			let gems = Sweeps.get('gems') || (await Sweeps.load('gems'));
			if (!gems || staleness('gems', gems).length) gems = await Sweeps.run('gems', state.settings);
			context.leads = Balance.leadsFrom(gems, W());
		}
		await Sweeps.run(sweep, state.settings, context);
	} catch (error) {
		if (String(error.message) !== 'cancelled') console.error(error);
	}
	if (ctx.alive()) ctx.rerender();
}

function needSweep(ctx, body, sweep, text) {
	body.append(card(null, h('div', { class: 'col', style: { alignItems: 'center', padding: '28px 10px', gap: '12px' } },
		h('p', { class: 'text-2', style: { maxWidth: '640px', textAlign: 'center' } }, text),
		h('button', { type: 'button', class: 'btn primary', disabled: Boolean(Sweeps.running()), onClick: () => runSweep(ctx, sweep) }, `Run ${SWEEP_NAMES[sweep].toLowerCase()} · about ${estimate(sweep)}`))));
}

function gemCell(key, size = 20) {
	const d = C.skill(key);
	return h('span', { class: 'cell-name', title: `${C.colorName(d.color)} · ${C.title(d.rarity)}` }, gemImage(key, size), h('b', {}, d.name || key));
}

function gemSelect(ctx, value, onChange) {
	const options = orderedSkills().map((k) => [k, `${C.colorName(C.skill(k).color)} · ${C.skill(k).name}`]);
	return select(options, value, onChange, { style: 'width:180px' });
}

function bowlSelect(value, onChange, allLabel = 'All six bowls') {
	return select([['ALL', allLabel], ...Balance.lapidaries().map((k) => [k, `${bowlName(k)}’s bowl`])], value, onChange, { style: 'width:150px' });
}

// A value over the chosen bowls: one bowl, or the average of all of them.
function overBowls(result, bowl, fn) {
	const bowls = bowl === 'ALL' ? result.bowls : [bowl];
	let sum = 0, n = 0;
	for (const b of bowls) { const v = fn(b); if (Number.isFinite(v)) { sum += v; n += 1; } }
	return n ? sum / n : NaN;
}

// --- Gems ---------------------------------------------------------------------------------------

function soloRow(gems, skill) {
	const vals = gems.bowls.map((b) => perTurn(gems, Balance.value(gems, b, `s|${skill}`, W())));
	return { vals, ...Balance.spread(vals) };
}
function partnerRow(pairs, skill) {
	const vals = pairs.bowls.map((b) => perTurn(pairs, Balance.partnerValue(pairs, b, skill, W())));
	return { vals, ...Balance.spread(vals) };
}
function railRow(rails, skill) {
	const vals = rails.bowls.map((b) => { const r = Balance.railValue(rails, b, skill, W()); return r ? perTurn(rails, r.value) : NaN; });
	return { vals, ...Balance.spread(vals) };
}

function gemsTab(body, ctx) {
	const gems = Sweeps.get('gems');
	const pairs = Sweeps.get('pairs');
	const rails = Sweeps.get('rails');
	if ((state.measure === 'partner' && !pairs) || (state.measure === 'rail' && !rails)) state.measure = 'solo';
	body.append(sweepBar(ctx, 'gems', gems ? [
		field('Value', segmented([['solo', 'Alone'], ['partner', pairs ? 'Beside a partner' : 'Beside a partner (run Pairings)'], ['rail', rails ? 'In a rail' : 'In a rail (run Opals)']], state.measure,
			(v) => { if ((v === 'partner' && !pairs) || (v === 'rail' && !rails)) return; state.measure = v; ctx.rerender(); }),
			'Alone: the gem on its own rail. Beside a partner: what it adds next to another gem, in their better order, averaged over all 65 partners. In a rail: what it adds to a rail of four other gems, averaged over the Opals sweep’s host rails.'),
		scaleField(ctx)] : []));
	if (!gems) { needSweep(ctx, body, 'gems', 'Every gem is played alone, as an 8-carat Good Clear stone, in four-turn fights against two training dummies, on each of the six lapidaries’ bowls with their passives and Birthstones. Its value is what it adds over the bare bowl.'); return; }
	const rowOf = (k) => (state.measure === 'partner' ? partnerRow(pairs, k) : state.measure === 'rail' ? railRow(rails, k) : soloRow(gems, k));
	const rows = Object.fromEntries(orderedSkills().map((k) => [k, rowOf(k)]));
	if (!rows[state.gem]) state.gem = 'STRIKE';
	const prev = Sweeps.getPrevious('gems');
	const comparable = prev && JSON.stringify(prev.settings) === JSON.stringify(gems.settings);
	const prevRows = comparable && state.measure === 'solo' ? Object.fromEntries(orderedSkills().map((k) => [k, soloRow(prev, k)])) : null;

	const groups = colorGroups((color) => orderedSkills().filter((k) => C.skill(k).color === color).map((k) => ({ key: k, label: C.skill(k).name, min: rows[k].min, avg: rows[k].avg, best: rows[k].best,
		note: `best on ${bowlName(gems.bowls[rows[k].bestAt] || '')}’s bowl` })).sort((a, b) => b.avg - a.avg));
	body.append(card(`Value ${MEASURES[state.measure].toLowerCase()} · a turn`, h('div', { class: 'bal-chart' },
		rangeStrip({ groups, width: 1150, height: 220, format: fmtV, selected: state.gem, independent: state.scale === 'own', onSelect: (it) => { state.gem = it.key; ctx.rerender(); } })),
	{ meta: 'a dot is a gem’s average over the six bowls, the whisker its worst bowl to its best, the hairline its colour’s median · click a gem' }));

	const color = C.skill(state.gem).color;
	const inColor = orderedSkills().filter((k) => C.skill(k).color === color);
	const med = median(inColor.map((k) => rows[k].avg));
	const { q1, q3 } = quartiles(inColor.map((k) => rows[k].avg));
	const iqr = q3 - q1;
	const flagOf = (v) => (v > q3 + 1.5 * iqr && v > med + 0.5 ? 'high' : v < q1 - 1.5 * iqr && v < med - 0.5 ? 'low' : '');
	const tableRows = inColor.map((k) => ({ key: k, ...rows[k], bestBowl: gems.bowls[rows[k].bestAt], vsMedian: med ? (rows[k].avg - med) / Math.abs(med) : NaN, flag: flagOf(rows[k].avg),
		delta: prevRows ? rows[k].avg - prevRows[k].avg : NaN }));
	const columns = [
		{ key: 'name', label: 'Gem', sort: (r) => C.skill(r.key).name, render: (r) => gemCell(r.key) },
		{ key: 'min', label: 'Worst', align: 'right', sort: (r) => r.min, render: (r) => fmtV(r.min) },
		{ key: 'avg', label: 'Average', align: 'right', sort: (r) => r.avg, render: (r) => h('b', {}, fmtV(r.avg)) },
		{ key: 'best', label: 'Best', align: 'right', sort: (r) => r.best, render: (r) => fmtV(r.best) },
		{ key: 'bestBowl', label: 'Best bowl', sort: (r) => r.bestBowl || '', render: (r) => h('span', { class: 'small text-2' }, bowlName(r.bestBowl || '')) },
		{ key: 'vsMedian', label: 'vs median', align: 'right', sort: (r) => r.vsMedian, render: (r) => h('span', { class: r.vsMedian > 0 ? 'delta-up' : 'delta-down' }, Number.isFinite(r.vsMedian) ? `${r.vsMedian > 0 ? '+' : ''}${fmtPct(r.vsMedian)}` : '—') },
		{ key: 'flag', label: '', sort: false, render: (r) => (r.flag ? h('span', { class: `flag ${r.flag}`, title: 'More than one and a half times the middle half’s spread from its colour’s middle' }, r.flag === 'high' ? 'outlier, strong' : 'outlier, weak') : '') },
	];
	if (prevRows) columns.push({ key: 'delta', label: 'Since last run', align: 'right', sort: (r) => r.delta, render: (r) => (Math.abs(r.delta) >= 0.05 ? h('span', { class: r.delta > 0 ? 'delta-up' : 'delta-down' }, signed(r.delta)) : h('span', { class: 'muted' }, '·')) });
	const sort = state.sort && state.sort.tab === 'gems' ? state.sort : { tab: 'gems', key: 'avg', dir: -1 };
	const sorted = sortRows(tableRows, columns, sort);
	const split = h('div', { class: 'bal-split' });
	split.append(card(`${C.colorName(color)} gems`, table({ columns, rows: sorted, sort, compact: true, selectedKey: state.gem, rowKey: (r) => r.key, sticky: false,
		onSort: (k) => { state.sort = { tab: 'gems', ...toggleSort(sort, k, k === 'name' || k === 'bestBowl' ? 1 : -1) }; ctx.rerender(); },
		onRowClick: (r) => { state.gem = r.key; ctx.rerender(); } }), { meta: `median ${fmtV(med)} a turn`, pad: false, class: 'dense' }));
	split.append(gemDetail(ctx, gems, pairs, rails, state.gem, rows[state.gem]));
	body.append(split);
}

function gemDetail(ctx, gems, pairs, rails, key, row) {
	const def = C.skill(key);
	const T = turnsOf(gems);
	const at = (b, i) => (gems.data[b] || {})[`s|${key}`] || [];
	const avgOf = (i) => gems.bowls.reduce((s, b) => s + (at(b)[i] || 0), 0) / gems.bowls.length / T;
	const base = (i) => gems.bowls.reduce((s, b) => s + (((gems.data[b] || {})['0'] || [])[i] || 0), 0) / gems.bowls.length / T;
	const solo = soloRow(gems, key);
	const partner = pairs ? partnerRow(pairs, key) : null;
	const inRail = rails ? railRow(rails, key) : null;
	const bowlRows = gems.bowls.map((b, i) => ({ key: b, label: bowlName(b), value: Math.max(0, row.vals[i]), color: markColor(def.color), note: `value a turn on ${bowlName(b)}’s bowl` }));
	return card(null, h('div', { class: 'col', style: { gap: '8px' } },
		h('div', { class: 'row', style: { alignItems: 'flex-start', flexWrap: 'nowrap' } }, gemImage(key, 52), h('div', { class: 'col', style: { gap: '2px' } }, h('h2', { style: { fontSize: '16px' } }, def.name), h('p', { class: 'small text-2 two-line' }, def.text || ''))),
		h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' } },
			stat('Alone', fmtV(solo.avg), `${fmtV(solo.min)} to ${fmtV(solo.best)}`, { class: state.measure === 'solo' ? 'accent' : '' }),
			stat('Beside one', partner ? fmtV(partner.avg) : '—', partner ? `${fmtV(partner.min)} to ${fmtV(partner.best)}` : 'run Pairings', { class: state.measure === 'partner' ? 'accent' : '' }),
			stat('In a rail', inRail ? fmtV(inRail.avg) : '—', inRail ? `${fmtV(inRail.min)} to ${fmtV(inRail.best)}` : 'run Opals', { class: state.measure === 'rail' ? 'accent' : '' })),
		h('p', { class: 'tiny muted' }, `Alone, a turn: fires ${fmt(avgOf(3), 2)} times · ${fmtV(avgOf(0) - base(0))} damage · ${fmtV(avgOf(1) - base(1))} health saved${Math.abs(avgOf(2) - base(2)) >= 0.05 ? ` · ${signed(avgOf(2) - base(2))} pyrite` : ''}`),
		h('div', { class: 'section-title' }, `By bowl · ${MEASURES[state.measure].toLowerCase()}`),
		bars({ rows: bowlRows, format: fmtV, labelWidth: 64, height: 20 })));
}

// --- Cut & Clarity ------------------------------------------------------------------------------

function cutClarityTab(body, ctx) {
	const cc = Sweeps.get('cutclarity');
	if (!cc) { body.append(sweepBar(ctx, 'cutclarity')); needSweep(ctx, body, 'cutclarity', 'Every gem at every Cut, as a Clear, a Pristine and a Flawless stone, played alone on every bowl. Included, Etched and Intricate stones are read from the Inclusions sweep once that has run.'); return; }
	const inc = Sweeps.get('inclusions');
	const cuts = cutNames();
	const clear = Balance.clarityOf('CLEAR'), pristine = Balance.clarityOf('PRISTINE'), flawless = Balance.clarityOf('FLAWLESS');
	const val = (bowl, skill, cut, clarity) => perTurn(cc, Balance.value(cc, bowl, `c|${skill}|${cut}|${clarity}`, W()));
	const key = state.gem;
	const measures = {
		cut: { label: 'Poor → Perfect', text: 'value a turn gained from a Poor to a Perfect cut, Clear', fn: (b, k) => val(b, k, cuts.length - 1, clear) - val(b, k, 0, clear) },
		pristine: { label: 'Clear → Pristine', text: 'value a turn gained by a Pristine stone over a Clear one, Good cut', fn: (b, k) => val(b, k, 2, pristine) - val(b, k, 2, clear) },
		flawless: { label: 'Clear → Flawless', text: 'value a turn gained by a Flawless stone over a Clear one, Good cut', fn: (b, k) => val(b, k, 2, flawless) - val(b, k, 2, clear) },
	};
	const m = measures[state.ccMeasure] || measures.cut;
	body.append(sweepBar(ctx, 'cutclarity', [field('Gem', gemSelect(ctx, key, (v) => { state.gem = v; ctx.rerender(); })), field('Grid shows', bowlSelect(state.bowl, (v) => { state.bowl = v; ctx.rerender(); })),
		field('Strip measures', segmented(Object.entries(measures).map(([k, x]) => [k, x.label]), state.ccMeasure, (v) => { state.ccMeasure = v; ctx.rerender(); })), scaleField(ctx)]));

	// The grid: Cut across, Clarity down, the included grades estimated from single inclusions.
	const rungs = [['Clear', clear], ['Pristine', pristine], ['Flawless', flawless]];
	const values = rungs.map(([, k]) => cuts.map((_, c) => overBowls(cc, state.bowl, (b) => val(b, key, c, k))));
	const labels = rungs.map(([n]) => n);
	if (inc) {
		for (const [name, slots] of [['Included', 1], ['Etched', 2], ['Intricate', 3]]) {
			const uplift = overBowls(inc, state.bowl, (b) => expectedUplift(inc, b, key, slots));
			labels.push(`${name} (est.)`);
			values.push(cuts.map((_, c) => values[0][c] + uplift));
		}
	}
	const top = Math.max(1e-9, ...values.flat().filter(Number.isFinite));
	const low = Math.min(0, ...values.flat().filter(Number.isFinite));
	const grid = h('div', { class: 'col' }, heatmap({ rows: labels, cols: cuts, values, format: fmtV, max: top, min: low, rowLabelWidth: 118, cellHeight: 28 }),
		h('div', { class: 'row between' }, rampKey((v) => heat((v - low) / (top - low || 1)), low, top, fmtV, 'value a turn'), h('span', { class: 'tiny muted' }, inc ? 'Included, Etched, Intricate: Clear plus the average inclusion at the odds a stone of this colour draws them.' : 'Run Inclusions for the included grades.')));
	const split = h('div', { class: 'bal-split-even' });
	split.append(card(`${C.skill(key).name} · Cut × Clarity`, grid, { meta: C.skill(key).color === 'OPAL' ? 'an opal does nothing alone: see the Opals tab' : state.bowl === 'ALL' ? 'average of the six bowls, value a turn' : `${bowlName(state.bowl)}’s bowl, value a turn` }));
	const groups = colorGroups((color) => orderedSkills().filter((k) => C.skill(k).color === color).map((k) => {
		const s = Balance.spread(cc.bowls.map((b) => m.fn(b, k)));
		return { key: k, label: C.skill(k).name, min: s.min, avg: s.avg, best: s.best, note: m.text };
	}).sort((a, b) => b.avg - a.avg));
	split.append(card(`${m.label} · every gem`, h('div', { class: 'bal-chart', style: { height: '230px' } }, rangeStrip({ groups, width: 580, height: 230, format: fmtV, selected: key, independent: state.scale === 'own', onSelect: (it) => { state.gem = it.key; ctx.rerender(); } })),
		{ meta: m.text }));
	body.append(split);

	// Every rung against its neighbour rung, over every gem: how much a step is worth.
	const rungRows = [];
	for (let c = 0; c < cuts.length; c++) {
		if (c === 2) continue;
		rungRows.push(rungRow(`${cuts[c]} cut`, 'against Good, Clear', (k) => overBowls(cc, 'ALL', (b) => val(b, k, c, clear) - val(b, k, 2, clear)), (k) => overBowls(cc, 'ALL', (b) => val(b, k, 2, clear))));
	}
	rungRows.push(rungRow('Pristine', 'against Clear, Good cut', (k) => overBowls(cc, 'ALL', (b) => val(b, k, 2, pristine) - val(b, k, 2, clear)), (k) => overBowls(cc, 'ALL', (b) => val(b, k, 2, clear))));
	rungRows.push(rungRow('Flawless', 'against Clear, Good cut', (k) => overBowls(cc, 'ALL', (b) => val(b, k, 2, flawless) - val(b, k, 2, clear)), (k) => overBowls(cc, 'ALL', (b) => val(b, k, 2, clear))));
	if (inc) for (const [name, slots] of [['Included', 1], ['Etched', 2], ['Intricate', 3]]) rungRows.push(rungRow(name, 'against Clear (estimated)', (k) => overBowls(inc, 'ALL', (b) => expectedUplift(inc, b, k, slots)), (k) => overBowls(cc, 'ALL', (b) => val(b, k, 2, clear))));
	const ladder = cuts.map((name, c) => {
		const s = Balance.spread(cc.bowls.map((b) => val(b, key, c, clear)));
		return { key: c, cut: name, ...s, bestBowl: cc.bowls[s.bestAt], minBowl: cc.bowls[s.minAt] };
	});
	const lower = h('div', { class: 'bal-split-even' });
	lower.append(card(`${C.skill(key).name} · Cut ladder, Clear`, table({ columns: [
		{ key: 'cut', label: 'Cut' }, { key: 'min', label: 'Worst bowl', align: 'right', render: (r) => h('span', {}, fmtV(r.min), h('span', { class: 'inline-sub' }, bowlName(r.minBowl || ''))) },
		{ key: 'avg', label: 'Average', align: 'right', render: (r) => h('b', {}, fmtV(r.avg)) },
		{ key: 'best', label: 'Best bowl', align: 'right', render: (r) => h('span', {}, fmtV(r.best), h('span', { class: 'inline-sub' }, bowlName(r.bestBowl || ''))) },
	], rows: ladder, compact: true, sticky: false, rowKey: (r) => r.key }), { pad: false, meta: 'value a turn, alone', class: 'dense' }));
	lower.append(card('Every rung, over every gem', table({ columns: [
		{ key: 'rung', label: 'Rung', render: (r) => h('span', { title: r.against }, h('b', {}, r.rung)) },
		{ key: 'min', label: 'Least', align: 'right', render: (r) => h('span', {}, signed(r.min), h('span', { class: 'inline-sub' }, r.minGem)) },
		{ key: 'avg', label: 'Average', align: 'right', render: (r) => h('span', {}, h('b', {}, signed(r.avg)), h('span', { class: 'inline-sub' }, Number.isFinite(r.pct) ? `${r.pct > 0 ? '+' : ''}${fmtPct(r.pct)}` : '')) },
		{ key: 'best', label: 'Most', align: 'right', render: (r) => h('span', {}, signed(r.best), h('span', { class: 'inline-sub' }, r.bestGem)) },
	], rows: rungRows, compact: true, sticky: false, rowKey: (r) => r.rung }), { pad: false, meta: 'value a turn over Good Clear, averaged over bowls · opals left out', class: 'dense' }));
	body.append(lower);
}

function rungRow(rung, against, gain, base) {
	const keys = orderedSkills().filter((k) => C.skill(k).color !== 'OPAL');
	const gains = keys.map(gain);
	const s = Balance.spread(gains);
	const baseSum = keys.reduce((sum, k) => sum + (Number.isFinite(base(k)) ? base(k) : 0), 0);
	return { rung, against, ...s, minGem: C.skill(keys[s.minAt] || '').name || '', bestGem: C.skill(keys[s.bestAt] || '').name || '', pct: baseSum ? (s.avg * keys.length) / baseSum : NaN };
}

// What `slots` inclusions add to a gem on a bowl, at the odds a stone of its colour draws them,
// summed one inclusion at a time (an estimate: two inclusions are taken not to meet).
function expectedUplift(inc, bowl, skill, slots) {
	const odds = Balance.inclusionOdds(skill, slots, inc.settings.mine || state.settings.mine);
	let sum = 0;
	for (const [k, p] of Object.entries(odds)) {
		const u = Balance.inclusionUplift(inc, bowl, skill, k, W());
		if (Number.isFinite(u) && p > 0) sum += p * u;
	}
	return perTurn(inc, sum);
}

// --- Inclusions ---------------------------------------------------------------------------------

function inclusionsTab(body, ctx) {
	const inc = Sweeps.get('inclusions');
	if (!inc) { body.append(sweepBar(ctx, 'inclusions')); needSweep(ctx, body, 'inclusions', 'Every gem with every inclusion it can grow, against the same gem bare, on every bowl. Feathers, which act on a neighbour, are judged beside a bare copy of their own gem, before it and after it, in the better place.'); return; }
	const skills = orderedSkills();
	const incs = C.keys('inclusions').sort((a, b) => CLASS_ORDER.indexOf(C.inclusion(a).class) - CLASS_ORDER.indexOf(C.inclusion(b).class) || a.localeCompare(b));
	if (!incs.includes(state.inclusion)) state.inclusion = incs[0];
	const bare = (b, k, i) => perTurn(inc, Balance.railInclusion(i) ? Balance.value(inc, b, `f|${k}||`, W()) : Balance.value(inc, b, `i|${k}|`, W()));
	const upliftOf = (k, i) => {
		if (!Balance.inclusionsFor(k).includes(i)) return NaN;
		return overBowls(inc, state.bowl, (b) => {
			const u = perTurn(inc, Balance.inclusionUplift(inc, b, k, i, W()));
			if (state.incUnit === 'turn') return u;
			const base = bare(b, k, i);
			return base >= 1 ? u / base : NaN;
		});
	};
	const table2 = {};
	for (const i of incs) { table2[i] = {}; for (const k of skills) table2[i][k] = upliftOf(k, i); }
	const avgOver = (i, keys) => { const v = keys.map((k) => table2[i][k]).filter(Number.isFinite); return v.length ? v.reduce((a, b) => a + b, 0) / v.length : NaN; };
	const colors = C.SKILL_COLORS;
	const cols = ['All', ...colors.map((c) => C.colorName(c))];
	const values = incs.map((i) => [avgOver(i, skills), ...colors.map((c) => avgOver(i, skills.filter((k) => C.skill(k).color === c)))]);
	const absMax = Math.max(1e-9, ...values.flat().filter(Number.isFinite).map(Math.abs));
	const fmtU = state.incUnit === 'turn' ? signed : (v) => (Number.isFinite(v) ? `${v > 0 ? '+' : ''}${fmtPct(v)}` : '—');
	body.append(sweepBar(ctx, 'inclusions', [field('Bowls', bowlSelect(state.bowl, (v) => { state.bowl = v; ctx.rerender(); })),
		field('Uplift as', segmented([['turn', 'Value a turn'], ['pct', '% of the bare gem']], state.incUnit, (v) => { state.incUnit = v; ctx.rerender(); }), '% leaves out gems worth under 1 a turn bare, opals among them')]));
	const split = h('div', { class: 'bal-split' });
	split.append(card('What an inclusion adds, by colour', h('div', { class: 'col' },
		heatmap({ rows: incs.map((i) => C.inclusion(i).name || i), cols, values, format: fmtU, min: -absMax, max: absMax, colorFor: (v) => diverge(v / absMax), rowLabelWidth: 128, cellHeight: 14,
			selected: `${incs.indexOf(state.inclusion)}:0`, onSelect: (i) => { state.inclusion = incs[i]; ctx.rerender(); } }),
		h('div', { class: 'row between' }, rampKey((v) => diverge(v / absMax), -absMax, absMax, fmtU, 'uplift'), h('span', { class: 'tiny muted' }, 'Rows run Pinpoint, Lens, Feather, Fracture, Star · click a row'))), { class: 'tight-heat', meta: `an 8-carat Good stone, averaged over each colour’s gems · ${state.bowl === 'ALL' ? 'all six bowls' : `${bowlName(state.bowl)}’s bowl`}` }));
	split.append(inclusionDetail(ctx, inc, state.inclusion, (k) => table2[state.inclusion][k], fmtU));
	body.append(split);
}

function inclusionDetail(ctx, inc, key, upliftFor, fmtU) {
	const def = C.inclusion(key);
	const hosts = orderedSkills().filter((k) => Balance.inclusionsFor(k).includes(key)).map((k) => ({ key: k, value: upliftFor(k) })).filter((r) => Number.isFinite(r.value)).sort((a, b) => b.value - a.value);
	const s = Balance.spread(hosts.map((r) => r.value));
	const helped = hosts.filter((r) => r.value > (state.incUnit === 'turn' ? 0.5 : 0.05)).length;
	const mine = C.mine(inc.settings.mine || state.settings.mine);
	const weights = Forge.inclusionWeights(mine, '');
	const total = Object.values(weights).reduce((a, b) => a + b, 0) || 1;
	const listRow = (r) => h('div', { class: 'bal-list-row clickable', onClick: () => { state.gem = r.key; ctx.navigate('balance', '', { tab: 'gems' }); } },
		colorKeyMark(C.skill(r.key).color, 14), h('span', {}, C.skill(r.key).name), h('span', { class: `v ${r.value > 0 ? 'delta-up' : r.value < 0 ? 'delta-down' : ''}` }, fmtU(r.value)));
	return card(null, h('div', { class: 'col' },
		h('div', { class: 'row', style: { flexWrap: 'nowrap', alignItems: 'flex-start' } }, inclusionImage(key, 56), h('div', { class: 'col', style: { gap: '4px' } },
			h('div', { class: 'row tight' }, chip(C.title(def.class), { color: CLASS_COLORS[def.class] }), chip(C.title(def.rarity))), h('h2', { style: { fontSize: '17px' } }, def.name || key), h('p', { class: 'small text-2' }, def.text || ''))),
		h('div', { class: 'stats' }, stat('Average', fmtU(s.avg), 'over every gem that can hold it', { class: 'accent' }), stat('Helps', `${helped} of ${hosts.length}`, 'gems by a meaningful amount'),
			stat('One draw', fmtPct((weights[key] || 0) / total, 1), 'share of a slot')),
		Balance.railInclusion(key) ? note('Judged beside a bare copy of its own gem, in the better of the two places: a Feather works on its neighbour.', 'plain') : null,
		key === 'FINGERPRINT' ? note('Nothing in sim/ reads copy_previous_inclusion, so a Fingerprint does nothing in a fight yet.', 'warn') : null,
		['ALEXANDRITE', 'ZONING_RED', 'ZONING_BLUE', 'ZONING_GREEN', 'ZONING_VIOLET', 'ZONING_GOLD', 'ZONING_WHITE'].includes(key) ? note('Mostly worth where it lets a stone sit (a coloured socket) and the Harmony it finds beside its new colour, which a lone gem in an Any socket cannot show.', 'plain') : null,
		h('div', { class: 'section-title' }, 'Best hosts'), h('div', { class: 'bal-list' }, hosts.slice(0, 6).map(listRow)),
		h('div', { class: 'section-title' }, 'Worst hosts'), h('div', { class: 'bal-list' }, hosts.slice(-4).reverse().map(listRow))));
}

// --- Lapidaries ---------------------------------------------------------------------------------

function lapidariesTab(body, ctx) {
	const gems = Sweeps.get('gems');
	body.append(sweepBar(ctx, 'gems', gems ? [field('Dots show', segmented([['relative', 'Lift over the gem’s average'], ['value', 'Value a turn']], state.lapView, (v) => { state.lapView = v; ctx.rerender(); }),
		'Lift: how much better or worse a gem does on this bowl than on the six on average, for gems worth 2 a turn or more. Value: what it does here, alone.')] : []));
	if (!gems) { needSweep(ctx, body, 'gems', 'The lapidaries are compared on the Gems sweep: every gem alone on every lapidary’s bowl, with their passive and Birthstone.'); return; }
	const pairs = Sweeps.get('pairs');
	const skills = orderedSkills();
	const v = (b, k) => perTurn(gems, Balance.value(gems, b, `s|${k}`, W()));
	const means = Object.fromEntries(skills.map((k) => [k, gems.bowls.reduce((sum, b) => sum + v(b, k), 0) / gems.bowls.length]));
	const lift = (b, k) => (means[k] >= 2 ? (v(b, k) - means[k]) / means[k] : NaN);
	const relative = state.lapView === 'relative';
	const fmtLift = (x) => (Number.isFinite(x) ? `${x > 0 ? '+' : ''}${fmtPct(x)}` : '—');
	const columns = gems.bowls.map((b) => ({ key: b, label: bowlName(b), points: skills.map((k) => ({ key: k, label: C.skill(k).name, value: relative ? lift(b, k) : v(b, k), color: markColor(C.skill(k).color), shape: SHAPES[C.skill(k).color],
		note: relative ? `over its average of ${fmtV(means[k])} a turn` : 'value a turn, alone' })) }));
	body.append(card(relative ? 'How much each bowl lifts every gem' : 'Every gem on every bowl', h('div', { class: 'bal-chart', style: { height: '270px' } },
		dotColumns({ columns, width: 1150, height: 270, format: relative ? fmtLift : fmtV, clip: relative ? [-1, 1.5] : null, selected: state.lapGem || null, onSelect: (p) => { state.lapGem = state.lapGem === p.key ? '' : p.key; ctx.rerender(); } })),
	{ meta: `a dot a gem, in its colour and shape · the box is the middle half, the line the median · click a dot to follow a gem${relative ? ' · gems worth under 2 a turn are left out' : ''}` }));

	const colors = C.SKILL_COLORS.filter((c) => c !== 'OPAL');
	const heatValues = gems.bowls.map((b) => colors.map((c) => { const ks = skills.filter((k) => C.skill(k).color === c); return ks.reduce((s, k) => s + v(b, k), 0) / ks.length; }));
	const top = Math.max(1e-9, ...heatValues.flat());
	const split = h('div', { class: 'grid', style: { gridTemplateColumns: 'minmax(0, 2fr) minmax(0, 3fr)' } });
	split.append(card('Average gem by colour', h('div', { class: 'col' }, heatmap({ rows: gems.bowls.map(bowlName), cols: colors.map((c) => C.colorName(c)), values: heatValues, format: fmtV, max: top, rowLabelWidth: 80, cellHeight: 28 }),
		rampKey((x) => heat(x / top), 0, top, fmtV, 'value a turn')), { meta: 'opals do nothing alone and are left out' }));
	const rows = gems.bowls.map((b) => {
		const vals = skills.map((k) => v(b, k));
		const bestAt = vals.indexOf(Math.max(...vals));
		const out = { key: b, base: perTurn(gems, Balance.power((gems.data[b] || {})['0'], W())), mean: vals.reduce((a, x) => a + x, 0) / vals.length, median: median(vals), top: skills[bestAt], topV: vals[bestAt],
			lift: median(skills.map((k) => lift(b, k))) };
		if (pairs) {
			let best = null, synergy = 0, n = 0;
			for (let i = 0; i < skills.length; i++) for (let j = i + 1; j < skills.length; j++) {
				const p = Balance.pairValue(pairs, b, skills[i], skills[j], W());
				if (!best || p.value > best.value) best = { ...p };
				if (Number.isFinite(p.synergy)) { synergy += p.synergy; n += 1; }
			}
			out.pair = best; out.synergy = n ? perTurn(pairs, synergy / n) : NaN;
		}
		return out;
	});
	const cols = [
		{ key: 'name', label: 'Lapidary', render: (r) => h('span', { class: 'cell-name', title: `The bowl alone (Birthstone and passive, no gems): ${fmtV(r.base)} a turn, what every value here is measured over` }, birthstoneImage(r.key, 22), h('b', {}, bowlName(r.key))) },
		{ key: 'mean', label: 'Mean gem', align: 'right', render: (r) => h('b', {}, fmtV(r.mean)) },
		{ key: 'lift', label: 'Median lift', align: 'right', title: 'The middle gem’s lift on this bowl over its six-bowl average', render: (r) => h('span', { class: r.lift >= 0 ? 'delta-up' : 'delta-down' }, fmtLift(r.lift)) },
		{ key: 'top', label: 'Best gem', render: (r) => h('span', { class: 'small', style: { whiteSpace: 'nowrap' } }, C.skill(r.top).name, h('span', { class: 'inline-sub' }, fmtV(r.topV))) },
	];
	if (pairs) {
		cols.push({ key: 'pair', label: 'Best pair', render: (r) => h('span', { class: 'small', style: { whiteSpace: 'nowrap' } }, r.pair.order.map((k) => C.skill(k).name).join(' → '), h('span', { class: 'inline-sub' }, fmtV(perTurn(pairs, r.pair.value)))) });
		cols.push({ key: 'synergy', label: 'Synergy', align: 'right', title: 'What a pair does over its two halves, averaged over every pair', render: (r) => h('span', { class: r.synergy >= 0 ? 'delta-up' : 'delta-down' }, signed(r.synergy)) });
	}
	split.append(card('Side by side', table({ columns: cols, rows, compact: true, sticky: false, rowKey: (r) => r.key }), { pad: false, class: 'dense', meta: pairs ? 'value a turn' : 'value a turn · run Pairings for the pair columns' }));
	body.append(split);
}

// --- Pairings -----------------------------------------------------------------------------------

function pairsTab(body, ctx) {
	const pairs = Sweeps.get('pairs');
	if (!pairs) { body.append(sweepBar(ctx, 'pairs')); needSweep(ctx, body, 'pairs', 'Every ordered pair of gems on every bowl, each pair rerolling for the trigger of whichever of the two does more alone, and every gem alone again on the same fights. A pair’s synergy is what it does beyond its two halves; its order is whichever is better. Needs the Gems sweep, which runs first if it has not.'); return; }
	const skills = orderedSkills();
	const index = new Map(skills.map((k, i) => [k, i]));
	const cache = new Map();
	const pairAt = (a, b) => {
		const key = a < b ? `${a}|${b}` : `${b}|${a}`;
		if (cache.has(key)) return cache.get(key);
		const p = { value: 0, synergy: 0, alone: 0, ab: 0, ba: 0 };
		const bowls = state.bowl === 'ALL' ? pairs.bowls : [state.bowl];
		let order = [a, b];
		for (const bowl of bowls) {
			const x = Balance.pairValue(pairs, bowl, a, b, W());
			p.value += x.value; p.synergy += x.synergy; p.alone += x.alone; p.ab += x.ab; p.ba += x.ba;
		}
		for (const k of ['value', 'synergy', 'alone', 'ab', 'ba']) p[k] = perTurn(pairs, p[k] / bowls.length);
		order = p.ab >= p.ba ? [a, b] : [b, a];
		const out = { ...p, order };
		cache.set(key, out);
		return out;
	};
	const metric = state.pairShow;
	const all = [];
	for (let i = 0; i < skills.length; i++) for (let j = i + 1; j < skills.length; j++) all.push({ a: skills[i], b: skills[j], ...pairAt(skills[i], skills[j]) });
	const magnitudes = all.map((p) => Math.abs(p[metric])).filter(Number.isFinite).sort((x, y) => x - y);
	const scale = Math.max(1e-9, magnitudes[Math.floor(magnitudes.length * 0.97)] || 1);
	if (!state.pair || !index.has(state.pair[0]) || !index.has(state.pair[1])) {
		const best = all.slice().sort((x, y) => y.synergy - x.synergy)[0];
		state.pair = [best.a, best.b];
	}
	body.append(sweepBar(ctx, 'pairs', [field('Bowls', bowlSelect(state.bowl, (v) => { state.bowl = v; ctx.rerender(); })),
		field('Cells show', segmented([['synergy', 'Synergy'], ['value', 'Pair value']], metric, (v) => { state.pairShow = v; ctx.rerender(); }), 'Synergy: the pair over its two halves alone. Pair value: what the two do together.'),
		field('Focus on', gemSelect(ctx, state.pair[0], (v) => { const partners = all.filter((p) => p.a === v || p.b === v).sort((x, y) => y.synergy - x.synergy); state.pair = partners.length ? [partners[0].a, partners[0].b] : [v, state.pair[1]]; ctx.rerender(); }))]));

	const rowsOf = skills.map((k) => ({ key: k, label: C.skill(k).name, color: markColor(C.skill(k).color) }));
	const colorFor = metric === 'synergy' ? (v) => diverge(v / scale) : (v) => heat(Math.max(0, Math.min(1, v / scale)));
	const grid = matrix({ rows: rowsOf, cols: rowsOf, value: (i, j) => (i === j ? null : pairAt(skills[i], skills[j])[metric]), colorFor, cell: 8,
		bandOf: (r) => C.skill(r.key).color, selected: [index.get(state.pair[0]), index.get(state.pair[1])],
		tipFor: (i, j) => {
			if (i === j) return [tipTitle(C.skill(skills[i]).name)];
			const p = pairAt(skills[i], skills[j]);
			return [tipTitle(`${C.skill(p.order[0]).name} → ${C.skill(p.order[1]).name}`), tipRow(signed(p.synergy), 'synergy', diverge(p.synergy / scale)), tipRow(fmtV(p.value), 'together'), tipRow(fmtV(p.alone), 'the two alone')];
		},
		onSelect: (i, j) => { if (i !== j) { state.pair = [skills[i], skills[j]]; ctx.rerender(); } } });
	const split = h('div', { class: 'bal-split' });
	split.append(card(metric === 'synergy' ? 'Synergy of every pair' : 'Value of every pair', h('div', { class: 'col' }, h('div', { class: 'bal-matrix' }, grid),
		h('div', { class: 'row between' }, metric === 'synergy' ? rampKey((v) => diverge(v / scale), -scale, scale, signed, 'synergy a turn') : rampKey((v) => heat(v / scale), 0, scale, fmtV, 'value a turn'),
			h('span', { class: 'tiny muted' }, 'Gems run by colour, the strips along the edges are their colours; hover for names.'))),
	{ meta: state.bowl === 'ALL' ? 'average of the six bowls · each pair in its better order' : `${bowlName(state.bowl)}’s bowl` }));

	const [a, b] = state.pair;
	const p = pairAt(a, b);
	const listRow = (x) => h('div', { class: 'bal-list-row clickable', onClick: () => { state.pair = [x.a, x.b]; ctx.rerender(); } },
		colorKeyMark(C.skill(x.order[0]).color, 14), h('span', { class: 'small' }, `${C.skill(x.order[0]).name} → ${C.skill(x.order[1]).name}`), h('span', { class: `v ${x.synergy >= 0 ? 'delta-up' : 'delta-down'}` }, signed(x.synergy)));
	const bySynergy = all.filter((x) => Number.isFinite(x.synergy)).sort((x, y) => y.synergy - x.synergy);
	const partners = all.filter((x) => x.a === a || x.b === a).sort((x, y) => y.synergy - x.synergy);
	const side = h('div', { class: 'col' });
	side.append(card(null, h('div', { class: 'col' },
		h('div', { class: 'row', style: { flexWrap: 'nowrap' } }, gemImage(p.order[0], 40), h('span', { class: 'muted' }, '→'), gemImage(p.order[1], 40),
			h('div', { class: 'col', style: { gap: '0' } }, h('b', {}, `${C.skill(p.order[0]).name} → ${C.skill(p.order[1]).name}`), h('span', { class: 'tiny muted' }, `the other way round: ${fmtV(Math.min(p.ab, p.ba))} a turn`))),
		h('div', { class: 'stats' }, stat('Synergy', signed(p.synergy), 'over the two alone', { class: 'accent' }), stat('Together', fmtV(p.value), `alone ${fmtV(p.alone)}`)))));
	side.append(card(null, h('div', { class: 'col', style: { gap: '6px' } },
		h('div', { class: 'section-title' }, 'Most synergy'), h('div', { class: 'bal-list' }, bySynergy.slice(0, 6).map(listRow)),
		h('div', { class: 'section-title' }, 'Least synergy'), h('div', { class: 'bal-list' }, bySynergy.slice(-4).reverse().map(listRow)),
		h('div', { class: 'section-title' }, `${C.skill(a).name}’s best partners`), h('div', { class: 'bal-list' }, partners.slice(0, 4).map(listRow)))));
	split.append(side);
	body.append(split);
}

// --- Opals --------------------------------------------------------------------------------------

// A gem's rail value over the chosen bowls: what it adds, what changed, where it sat best, and
// what it did in each host, every number a turn.
function railOver(rails, bowl, skill) {
	const bowls = bowl === 'ALL' ? rails.bowls : [bowl];
	const T = turnsOf(rails);
	const changed = new Array(Balance.VECTOR.length).fill(0);
	const places = new Array(Balance.HOST_SIZE + 1).fill(0);
	const hosts = new Map();
	let value = 0, n = 0;
	for (const b of bowls) {
		const r = Balance.railValue(rails, b, skill, W());
		if (!r) continue;
		value += r.value; n += 1;
		r.changed.forEach((x, j) => { changed[j] += x; });
		r.places.forEach((x, j) => { places[j] += x; });
		for (const p of r.perHost) { const at = hosts.get(p.host) || { host: p.host, gems: p.gems, value: 0, n: 0 }; at.value += p.value; at.n += 1; hosts.set(p.host, at); }
	}
	if (!n) return null;
	return { value: value / n / T, changed: changed.map((x) => x / n / T), places, hosts: [...hosts.values()].map((x) => ({ ...x, value: x.value / x.n / T })).sort((a, b) => b.value - a.value) };
}

function opalsTab(body, ctx) {
	const rails = Sweeps.get('rails');
	body.append(sweepBar(ctx, 'rails', rails ? [field('Bowls', bowlSelect(state.bowl, (v) => { state.bowl = v; ctx.rerender(); })), scaleField(ctx)] : []));
	if (!rails) {
		needSweep(ctx, body, 'rails', `An opal does nothing alone: it rings off the Resonance the gems before it build, replays them, copies them or wakes the ones that stayed dark. So every gem is set into ${state.settings.hosts} rails of four other gems (the same rails on every bowl), an opal in each of the five places and anything else first or last, and measured against the same rail without it: damage, block, healing, pyrite and health saved. Needs the Gems sweep, which runs first if it has not.`);
		return;
	}
	const idx = Object.fromEntries(Balance.VECTOR.map((n, i) => [n, i]));
	const skills = orderedSkills();
	const over = Object.fromEntries(skills.map((k) => [k, railOver(rails, state.bowl, k)]));
	const opals = skills.filter((k) => C.skill(k).color === C.OPAL);
	if (!over[state.opal]) state.opal = opals[0];
	const others = skills.filter((k) => C.skill(k).color !== C.OPAL).map((k) => over[k] && over[k].value);
	const typical = median(others);
	const groups = colorGroups((color) => skills.filter((k) => C.skill(k).color === color).map((k) => {
		const row = railRow(rails, k);
		return { key: k, label: C.skill(k).name, min: row.min, avg: row.avg, best: row.best, note: `best on ${bowlName(rails.bowls[row.bestAt] || '')}’s bowl` };
	}).sort((a, b) => b.avg - a.avg));
	body.append(card('What a gem adds to a rail of four · a turn', h('div', { class: 'bal-chart', style: { height: '200px' } },
		rangeStrip({ groups, width: 1150, height: 200, format: fmtV, selected: state.opal, independent: state.scale === 'own', onSelect: (it) => { state.opal = it.key; ctx.rerender(); } })),
	{ meta: `every gem, in its best place, over the same ${rails.hosts.length} host rails · a dot its average over the six bowls, the whisker its worst bowl to its best · click a gem` }));

	const ch = (r, name) => (r ? r.changed[idx[name]] : NaN);
	const usual = (r) => { if (!r) return ''; const best = r.places.indexOf(Math.max(...r.places)); return PLACE_NAMES[best] || ''; };
	const delta = (v) => h('span', { class: Math.abs(v) < 0.05 ? 'muted' : v > 0 ? 'delta-up' : 'delta-down' }, Math.abs(v) < 0.05 ? '·' : signed(v));
	const columns = [
		{ key: 'name', label: 'Opal', render: (k) => gemCell(k) },
		{ key: 'value', label: 'Adds', align: 'right', title: 'Power over the same rail without it, a turn', render: (k) => h('b', {}, fmtV(over[k] && over[k].value)) },
		{ key: 'dealt', label: 'Damage', align: 'right', render: (k) => delta(ch(over[k], 'dealt')) },
		{ key: 'block', label: 'Block', align: 'right', title: 'Block gained (some of it may stand unused)', render: (k) => delta(ch(over[k], 'blockGained')) },
		{ key: 'healed', label: 'Healing', align: 'right', title: 'Health healed: less when the rail takes less to heal', render: (k) => delta(ch(over[k], 'healed')) },
		{ key: 'gold', label: 'Pyrite', align: 'right', render: (k) => delta(ch(over[k], 'gold')) },
		{ key: 'saved', label: 'Health saved', align: 'right', title: 'Blows blocked or prevented and health healed, together', render: (k) => delta(ch(over[k], 'saved')) },
		{ key: 'fires', label: 'Fires', align: 'right', title: 'Gem firings added a turn: its own, and the replays and repeats it causes', render: (k) => delta(ch(over[k], 'fires')) },
		{ key: 'place', label: 'Best place', render: (k) => h('span', { class: 'small text-2' }, usual(over[k])) },
	];
	const rows = opals.slice().sort((a, b) => ((over[b] && over[b].value) || 0) - ((over[a] && over[a].value) || 0));
	const split = h('div', { class: 'bal-split' });
	split.append(card('Opals in a rail', table({ columns, rows, compact: true, sticky: false, selectedKey: state.opal, rowKey: (k) => k, onRowClick: (k) => { state.opal = k; ctx.rerender(); } }),
		{ pad: false, class: 'dense', meta: `what each changes a turn, against the same rail without it · the middle non-opal gem adds ${fmtV(typical)}` }));
	split.append(opalDetail(ctx, rails, state.opal, over[state.opal], idx));
	body.append(split);
}

function opalDetail(ctx, rails, key, r, idx) {
	const def = C.skill(key);
	if (!r) return card(null, note('Not measured.', 'plain'));
	const placeRows = r.places.map((n, i) => ({ key: i, label: `${PLACE_NAMES[i]} of ${Balance.HOST_SIZE + 1}`, value: n, color: markColor(def.color), note: 'hosts where this was its best place' })).filter((x, i) => Balance.placesFor(key).includes(i));
	const hostRow = (x) => h('div', { class: 'bal-list-row', title: x.gems.map((k) => C.skill(k).name).join(' · ') },
		h('span', { class: 'tiny muted' }, `#${x.host + 1}`), h('span', { class: 'small', style: { whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, x.gems.map((k) => C.skill(k).name).join(', ')), h('span', { class: 'v' }, fmtV(x.value)));
	return card(null, h('div', { class: 'col', style: { gap: '8px' } },
		h('div', { class: 'row', style: { alignItems: 'flex-start', flexWrap: 'nowrap' } }, gemImage(key, 48), h('div', { class: 'col', style: { gap: '2px' } }, h('h2', { style: { fontSize: '16px' } }, def.name), h('p', { class: 'small text-2 two-line' }, def.text || ''))),
		h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' } }, stat('Adds', fmtV(r.value), 'a turn', { class: 'accent' }),
			stat('Damage', signed(r.changed[idx.dealt]), 'a turn'), stat('Fires', signed(r.changed[idx.fires]), 'firings a turn')),
		h('div', { class: 'section-title' }, 'Best hosts'), h('div', { class: 'bal-list' }, r.hosts.slice(0, 3).map(hostRow)),
		h('div', { class: 'section-title' }, 'Worst hosts'), h('div', { class: 'bal-list' }, r.hosts.slice(-2).reverse().map(hostRow)),
		placeRows.length > 2 ? h('p', { class: 'tiny muted' }, 'Sat best ', placeRows.filter((x) => x.value > 0).map((x) => `${PLACE_NAMES[x.key]} ${fmtPct(x.value / Math.max(1, placeRows.reduce((t, y) => t + y.value, 0)))}`).join(' · ')) : null));
}

// --- Method & settings --------------------------------------------------------------------------

function methodTab(body, ctx) {
	const s = state.settings;
	const w = state.weights;
	const setW = (k) => (v) => { state.weights = { ...state.weights, [k]: Math.max(0, Number(v) || 0) }; keep(); ctx.rerender(); };
	const setS = (k, lo, hi) => (v) => { state.settings = { ...state.settings, [k]: Math.max(lo, Math.min(hi, Number(v) || 0)) }; keep(); ctx.rerender(); };
	const dieOptions = ['D4', 'D6', 'D8', 'D10', 'D12', 'D20'].map((k) => [k, k.toLowerCase()]);
	const split = h('div', { class: 'grid', style: { gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 2fr)' } });
	split.append(card('Exchange rates', h('div', { class: 'col' },
		h('div', { class: 'row' }, field('Damage dealt', numberInput(w.damage, setW('damage'), { step: 0.1, min: 0, style: 'width:90px' })),
			field('Health saved', numberInput(w.saved, setW('saved'), { step: 0.1, min: 0, style: 'width:90px' }), 'Blows blocked, prevented or healed: the dummies’ throws less what reached the player plus what was healed'),
			field('Pyrite won', numberInput(w.gold, setW('gold'), { step: 0.1, min: 0, style: 'width:90px' }), 'Gold and pyrite won, less what Wager and Stake spent')),
		note('Power = damage × dealt + health saved × saved + pyrite × won. A value is a rail’s power less the bare bowl’s, a turn. These rates apply at once; nothing is played again.', 'plain'),
		h('button', { type: 'button', class: 'btn', onClick: () => { state.weights = { ...Balance.DEFAULT_WEIGHTS }; keep(); ctx.rerender(); } }, 'Back to 1 · 0.7 · 0'))));
	split.append(card('The fight', h('div', { class: 'col' },
		h('div', { class: 'row' }, field('Turns', segmented([[2, '2'], [3, '3'], [4, '4'], [6, '6'], [8, '8']], s.turns, setS('turns', 1, 12))),
			field('Dummies', segmented([[1, '1'], [2, '2'], [3, '3']], s.dummies, setS('dummies', 1, 4))),
			field('Each throws', h('span', { class: 'row tight' }, ...s.dummyDice.map((d, i) => select(dieOptions, d, (v) => { const dice = s.dummyDice.slice(); dice[i] = v; state.settings = { ...state.settings, dummyDice: dice }; keep(); ctx.rerender(); }, { class: 'select small', style: 'width:70px' })))),
			field('Dummy health', segmented([[30, '30'], [60, '60'], [120, '120'], [0, 'Endless']], s.dummyHp, setS('dummyHp', 0, 10000)), 'With health, overkill is wasted, poison dies with its creature and a kill saves the blows it would have thrown. Endless counts everything a gem does, but lets poison and House Money’s pot run away'),
			field('Dummy block', numberInput(s.guard, setS('guard', 0, 99), { style: 'width:70px' }), 'Block each dummy raises as it acts (Shatter needs some to break)')),
		h('div', { class: 'row' }, field('Stone', h('span', { class: 'small text-2' }, `${s.carat} carats · ${cutNames()[s.cut]} · ${C.title(s.clarity)}`)),
			field('Carat', numberInput(s.carat, setS('carat', 1, 24), { style: 'width:70px' })), field('Cut', select(cutNames().map((n, i) => [i, n]), s.cut, setS('cut', 0, 4), { style: 'width:100px' })),
			field('Pyrite carried', numberInput(s.pyrite, setS('pyrite', 0, 999), { style: 'width:80px' }), 'What Wager, Stake, Gilded Armor and House Money read'),
			field('Birthstones', segmented([[true, 'On'], [false, 'Off']], s.birthstone, (v) => { state.settings = { ...state.settings, birthstone: v === true || v === 'true' }; keep(); ctx.rerender(); })),
			field('Passives', segmented([[true, 'On'], [false, 'Off']], s.passive, (v) => { state.settings = { ...state.settings, passive: v === true || v === 'true' }; keep(); ctx.rerender(); }))),
		h('div', { class: 'row' }, field('Host rails', segmented([[12, '12'], [24, '24'], [48, '48']], s.hosts, setS('hosts', 1, 200)), 'How many rails of four other gems the Opals sweep sets every gem into'),
			...Balance.SWEEPS.map((sw) => field(`${SWEEP_NAMES[sw]} · fights`, select([[100, '100'], [150, '150'], [300, '300'], [1000, '1000'], [3000, '3000']], s.samples[sw],
			(v) => { state.settings = { ...state.settings, samples: { ...state.settings.samples, [sw]: Number(v) } }; keep(); ctx.rerender(); }, { style: 'width:90px' })))),
		h('button', { type: 'button', class: 'btn', onClick: () => { state.settings = { ...Balance.DEFAULTS, samples: { ...Balance.DEFAULTS.samples } }; keep(); ctx.rerender(); } }, 'Back to the defaults'))));
	body.append(split);
	const lower = h('div', { class: 'bal-split-even' });
	body.append(lower);
	lower.append(card('Sweeps', table({ columns: [
		{ key: 'name', label: 'Sweep', render: (r) => h('b', {}, SWEEP_NAMES[r.key]) },
		{ key: 'run', label: 'Last run', render: (r) => (r.result ? `${new Date(r.result.created).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })} · took ${fmt(r.result.seconds || 0, 0)}s` : h('span', { class: 'muted' }, 'never')) },
		{ key: 'state', label: 'Against now', render: (r) => {
			if (!r.result) return '';
			const stale = staleness(r.key, r.result);
			return stale.length ? h('span', { class: 'row tight' }, stale.map((x) => h('span', { class: 'flag low', title: x.detail }, x.label))) : h('span', { class: 'flag high' }, 'current');
		} },
		{ key: 'eta', label: 'Takes', render: (r) => `about ${estimate(r.key)}` },
		{ key: 'go', label: '', render: (r) => h('button', { type: 'button', class: 'btn', disabled: Boolean(Sweeps.running()), onClick: () => runSweep(ctx, r.key) }, r.result ? 'Run again' : 'Run') },
	], rows: Balance.SWEEPS.map((k) => ({ key: k, result: Sweeps.get(k) })), compact: true, rowKey: (r) => r.key }), { pad: false, meta: 'kept in build/balance · also: node tools/data-browser/balance.mjs all' }));
	lower.append(card('How it is measured', h('div', { class: 'col small text-2', style: { gap: '6px' } },
		h('p', {}, h('b', {}, 'The fight. '), `Every rail is played ${s.turns} turns against ${s.dummies} training dumm${s.dummies === 1 ? 'y' : 'ies'}, each throwing ${s.dummyDice.join(' and ').toLowerCase()} at the player every action. The player’s half is the game’s own rail, ported to js/sim/fight.js and held to sim/battle.gd by tools/data-browser/parity.mjs: Resonance and Harmony, every gem, the hand White gems change, Opal replays, Echoes and Preludes, the Birthstone, the passives.`),
		h('p', {}, h('b', {}, 'The dummies. '), `They answer stuns, stolen dice, Dread, clouding and Curse the way a creature does, and do nothing else. ${s.dummyHp ? `Each has ${s.dummyHp} health; one that falls misses its action and a fresh one stands up next turn.` : 'Endless ones never die, so poison and House Money’s pot can run away.'} A player never goes down (a blow that would down them counts in full).`),
		h('p', {}, h('b', {}, 'The bowls. '), 'Each of the six lapidaries rolls their own starting dice with their passive (Cadence’s extra reroll, Puck’s parity shift, Ardor’s Second Wind…) and Birthstone. Rerolls chase the trigger of the gem that does most alone; a pair chases its stronger half’s.'),
		h('p', {}, h('b', {}, 'Fair comparisons. '), 'Every rail on a bowl plays the same seeded fights: each die has its own stream of throws, so two rails that make the same choices see the same dice. Values are means; with a few hundred fights a value moves by a few tenths between runs.'),
		h('p', {}, h('b', {}, 'Contexts. '), 'Gems, cuts and clarities are judged alone; a Feather inclusion beside a bare copy of its own gem; a pair in its better order. The Opals tab sets every gem into rails of four other gems (an opal in its best place, anything else first or last) and measures what changes against the same rail without it.'),
		h('p', {}, h('b', {}, 'Known gaps. '), 'Economy (Prospect’s Sparkle, Appraise’s haul, quality bonuses) is not combat and reads as nothing here. Sockets are all Any, so Zoning and Alexandrite only show through Harmony.'))));
}
