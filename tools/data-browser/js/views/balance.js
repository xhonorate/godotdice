// Balance: what every gem, Cut, Clarity, inclusion, lapidary and pairing is worth in a short
// fight against training dummies, on every lapidary's own bowl. The sweeps behind it run on
// every core (js/sweeps.js) and are kept in build/balance, so they are run once, not per
// visit; tools/data-browser/balance.mjs runs them from the command line.
//
// Every number is a value per turn: the rail's power less the empty rail's on the same bowl,
// where power weighs damage dealt, health saved and pyrite won by the exchange rates set on the
// Method tab, in the ordinary fight or the boss fight (the toggle by the rates). The rates and
// the fight apply as they change; the fight settings need the sweep run again.

import * as C from '../sim/content.js';
import * as Balance from '../sim/balance.js';
import * as Forge from '../sim/forge.js';
import * as Stone from '../sim/stone.js';
import * as Patterns from '../sim/patterns.js';
import * as Rules from '../sim/rules.js';
import * as Sweeps from '../sweeps.js';
import { h, card, stat, table, fmt, fmtPct, note, chip, field, segmented, select, numberInput, sortRows, toggleSort, progress, tipRow, tipTitle } from '../ui.js';
import { heatmap, heat, bars, lines, sparkline, SHAPES } from '../charts.js';
import { rangeStrip, matrix, dotColumns, diverge, rampKey } from '../balance-charts.js';
import { gemImage, inclusionImage, birthstoneImage, markColor, colorKeyMark } from '../gemart.js';
import { cutNames, tabs, rarityChip, CUT_COLORS, CLARITY_COLORS } from './common.js';

const STORE_KEY = 'deepcut.balance';
const TABS = [['gems', 'Gems'], ['cutclarity', 'Cut & Clarity'], ['inclusions', 'Inclusions'], ['lapidaries', 'Lapidaries'], ['pairs', 'Pairings'], ['opals', 'Opals'],
	['carats', 'Carat bands'], ['hunt', 'Combo hunt'], ['growth', 'Growth'], ['method', 'Method & settings']];
const SWEEP_OF = { gems: 'gems', cutclarity: 'cutclarity', inclusions: 'inclusions', lapidaries: 'gems', pairs: 'pairs', opals: 'rails', carats: 'carats', hunt: 'hunt', growth: 'growth' };
const SWEEP_NAMES = { gems: 'Gems alone', cutclarity: 'Cuts and clarities', inclusions: 'Inclusions', pairs: 'Every pair', rails: 'Gems in a rail', carats: 'Carat bands', hunt: 'Combo hunt', growth: 'Runs and long fights' };
// Sweeps that set gems beside others read which gem a rail's rerolls chase from the gems sweep.
const NEEDS_LEADS = ['pairs', 'rails', 'carats', 'hunt', 'growth'];
// The gate's line (balance.mjs check): a hunted rail this many times its bowl's plain rail.
const HUNT_LIMIT = 4;
const MEASURES = { solo: 'Alone', partner: 'Beside a partner', rail: 'In a rail' };
const PLACE_NAMES = ['1st', '2nd', '3rd', '4th', '5th', '6th'];
const CLASS_ORDER = ['PINPOINT', 'LENS', 'FEATHER', 'FRACTURE', 'STAR'];
const CLASS_COLORS = { PINPOINT: '#8a93a3', LENS: '#6f9fe0', FEATHER: '#4fae7a', FRACTURE: '#c96a2a', STAR: '#f0c95a' };

const saved = (() => { try { return JSON.parse(localStorage.getItem(STORE_KEY) || 'null') || {}; } catch { return {}; } })();
const state = {
	settings: { ...Balance.DEFAULTS, ...(saved.settings || {}), samples: { ...Balance.DEFAULTS.samples, ...((saved.settings || {}).samples || {}) } },
	weights: { ...Balance.DEFAULT_WEIGHTS, ...(saved.weights || {}) },
	tab: 'gems', gem: 'STRIKE', opal: 'DOUBLET', measure: 'solo', scale: 'own', lapView: 'relative', bowl: 'ALL', ccCompare: 'cut', ccShow: 'level', incUnit: 'turn', inclusion: '', lapGem: '', pair: null, pairShow: 'synergy', sort: null,
	huntBand: '', huntBuild: '', growthView: 'run',
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
		// A link may name the fight (?fight=boss); the toggle still changes it after.
		if (Balance.FIGHTS.includes(route.params.fight) && route.params.fight !== state.linkedFight) { state.linkedFight = route.params.fight; state.weights = { ...state.weights, fight: route.params.fight }; }
		hook = { ctx, progress: () => {} };
		const pending = Balance.SWEEPS.filter((s) => !Sweeps.get(s));
		if (pending.length) Promise.all(pending.map((s) => Sweeps.load(s))).then((loaded) => { if (ctx.alive() && loaded.some(Boolean)) ctx.rerender(); });
		root.append(h('div', { class: 'row between' }, tabs(TABS, state.tab, (t) => ctx.navigate('balance', '', { tab: t })), weightChips(ctx)));
		const body = h('div', { class: 'col', style: { gap: '14px' } });
		root.append(body);
		const views = { gems: gemsTab, cutclarity: cutClarityTab, inclusions: inclusionsTab, lapidaries: lapidariesTab, pairs: pairsTab, opals: opalsTab, carats: caratsTab, hunt: huntTab, growth: growthTab, method: methodTab };
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
// A strong or a weak outlier among `values`: past one and a half times the middle half's spread
// from the middle half, and at least `floor` from the median.
function outlierOf(values, floor) {
	const med = median(values);
	const { q1, q3 } = quartiles(values);
	const iqr = q3 - q1;
	return (v) => (v > q3 + 1.5 * iqr && v > med + floor ? 'high' : v < q1 - 1.5 * iqr && v < med - floor ? 'low' : '');
}
const flagCell = (flag) => (flag ? h('span', { class: `flag ${flag}`, title: 'More than one and a half times the middle half’s spread from its color’s middle' }, flag === 'high' ? 'outlier, strong' : 'outlier, weak') : '');
function scaleField(ctx) {
	return field('Scale', segmented([['own', 'Per color'], ['shared', 'Shared']], state.scale, (v) => { state.scale = v; ctx.rerender(); }),
		'Each color on its own scale, to read a gem against its own kind; one scale to compare across colors');
}
const colorGroups = (fill) => C.SKILL_COLORS.map((color) => ({ key: color, label: C.colorName(color), color: markColor(color), shape: SHAPES[color], items: fill(color) }));

function weightChips(ctx) {
	const w = W();
	const fight = segmented([['mob', 'Ordinary fight'], ['boss', 'Boss fight']], w.fight === 'boss' ? 'boss' : 'mob', (v) => { state.weights = { ...state.weights, fight: v }; keep(); ctx.rerender(); });
	fight.title = 'Ordinary: two dummies with a creature’s health, overkill wasted. Boss: one that never falls, read at the pace a rail brings down a boss’s health, so nothing is capped.';
	return h('div', { class: 'row tight' }, fight, h('span', { class: 'tiny muted' }, 'Power ='),
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
				h('span', { class: 'small muted' }, `${now.sweep === 'hunt' ? `round ${now.round + 1} · ` : ''}${now.done}/${now.total} batches · ${fmt(elapsed, 0)}s${Number.isFinite(eta) ? ` · about ${fmt(eta, 0)}s to go` : ''}`),
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
	if (sweep !== 'growth' && (result.vector || []).length !== Balance.VECTOR.length) out.push({ label: 'older format', detail: 'played before the boss fight was measured: run it again for the boss numbers' });
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
	const single = Balance.estimateSeconds(sweep, state.settings, { leads: {} });
	// Logical cores share their silicon: a pool of them goes about a third as fast as its count.
	const seconds = 3 + single / Math.max(1, 0.3 * (navigator.hardwareConcurrency || 4));
	return seconds < 60 ? `${Math.max(5, Math.round(seconds / 5) * 5)} seconds` : `${Math.round(seconds / 60)} minute${Math.round(seconds / 60) === 1 ? '' : 's'}`;
}

async function runSweep(ctx, sweep) {
	try {
		const context = {};
		if (NEEDS_LEADS.includes(sweep)) {
			let gems = Sweeps.get('gems') || (await Sweeps.load('gems'));
			if (!gems || staleness('gems', gems).length) gems = await Sweeps.run('gems', state.settings);
			context.leads = Balance.leadsFrom(gems, W());
		}
		await Sweeps.run(sweep, state.settings, context, W());
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
	{ meta: 'a dot is a gem’s average over the six bowls, the whisker its worst bowl to its best, the hairline its color’s median · click a gem' }));

	const color = C.skill(state.gem).color;
	const inColor = orderedSkills().filter((k) => C.skill(k).color === color);
	const med = median(inColor.map((k) => rows[k].avg));
	const flagOf = outlierOf(inColor.map((k) => rows[k].avg), 0.5);
	const tableRows = inColor.map((k) => ({ key: k, ...rows[k], bestBowl: gems.bowls[rows[k].bestAt], vsMedian: med ? (rows[k].avg - med) / Math.abs(med) : NaN, flag: flagOf(rows[k].avg),
		delta: prevRows ? rows[k].avg - prevRows[k].avg : NaN }));
	const columns = [
		{ key: 'name', label: 'Gem', sort: (r) => C.skill(r.key).name, render: (r) => gemCell(r.key) },
		{ key: 'min', label: 'Worst', align: 'right', sort: (r) => r.min, render: (r) => fmtV(r.min) },
		{ key: 'avg', label: 'Average', align: 'right', sort: (r) => r.avg, render: (r) => h('b', {}, fmtV(r.avg)) },
		{ key: 'best', label: 'Best', align: 'right', sort: (r) => r.best, render: (r) => fmtV(r.best) },
		{ key: 'bestBowl', label: 'Best bowl', sort: (r) => r.bestBowl || '', render: (r) => h('span', { class: 'small text-2' }, bowlName(r.bestBowl || '')) },
		{ key: 'vsMedian', label: 'vs median', align: 'right', sort: (r) => r.vsMedian, render: (r) => h('span', { class: r.vsMedian > 0 ? 'delta-up' : 'delta-down' }, Number.isFinite(r.vsMedian) ? `${r.vsMedian > 0 ? '+' : ''}${fmtPct(r.vsMedian)}` : '—') },
		{ key: 'flag', label: '', sort: false, render: (r) => flagCell(r.flag) },
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
// Two comparisons, each with the other C held still: a gem up the Cut ladder from Poor to
// Perfect as a Clear stone, and a Clear stone against a Flawless one (half as hard again, and
// its Flawless line) at the sweep's cut. A gain is the top rung over the bottom one as a share
// of the bottom one, so every gem is read against itself.

const CC_COMPARES = { cut: 'Poor → Perfect cut', clarity: 'Clear → Flawless' };
// A gem worth less than this a turn on its bottom rung has no gain to speak of.
const CC_FLOOR = 1;
const fmtGain = (v) => (Number.isFinite(v) ? `${v > 0 ? '+' : ''}${fmtPct(v)}` : '—');
const orLast = (v) => (Number.isFinite(v) ? v : -Infinity);
const listed = (names) => (names.length > 1 ? `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}` : names.join(''));

// The rungs a comparison reads, bottom first, as the sweep played them.
function ccRungs(cc, compare) {
	const clear = Balance.clarityOf('CLEAR');
	const at = Number((cc.settings || {}).cut ?? Balance.DEFAULTS.cut);
	if (compare === 'clarity') return [{ label: 'Clear', cut: at, clarity: clear }, { label: 'Flawless', cut: at, clarity: Balance.clarityOf('FLAWLESS') }];
	return cutNames().map((label, cut) => ({ label, cut, clarity: clear }));
}

// A gem's value a turn at every rung over the chosen bowls, every rung's gain over the bottom
// one, and the top rung's gain bowl by bowl.
function ccRow(cc, rungs, skill) {
	const val = (b, r) => perTurn(cc, Balance.value(cc, b, `c|${skill}|${r.cut}|${r.clarity}`, W()));
	const gainOf = (base, v) => (base >= CC_FLOOR ? v / base - 1 : NaN);
	const levels = rungs.map((r) => overBowls(cc, state.bowl, (b) => val(b, r)));
	const gains = levels.map((v) => gainOf(levels[0], v));
	const bowls = cc.bowls.map((b) => {
		const base = val(b, rungs[0]), top = val(b, rungs[rungs.length - 1]);
		return { bowl: b, base, top, gain: gainOf(base, top) };
	});
	const s = Balance.spread(bowls.map((b) => b.gain));
	return { key: skill, levels, gains, top: levels[levels.length - 1], gain: gains[gains.length - 1], bowls, worst: s.min, worstBowl: cc.bowls[s.minAt], best: s.best, bestBowl: cc.bowls[s.bestAt] };
}

function flawlessLine(cc, skill) {
	const stone = Stone.make(skill, Number(cc.settings.carat ?? Balance.DEFAULTS.carat), Number(cc.settings.cut ?? Balance.DEFAULTS.cut), Balance.clarityOf('FLAWLESS'));
	return Stone.flawlessText(stone);
}

function cutClarityTab(body, ctx) {
	const cc = Sweeps.get('cutclarity');
	if (!cc) { body.append(sweepBar(ctx, 'cutclarity')); needSweep(ctx, body, 'cutclarity', 'Every gem up the Cut ladder from Poor to Perfect as a Clear stone, and as a Flawless stone beside the Clear one at Good cut, played alone on every bowl.'); return; }
	const compare = CC_COMPARES[state.ccCompare] ? state.ccCompare : 'cut';
	const gain = state.ccShow === 'gain';
	const rungs = ccRungs(cc, compare);
	const bottom = rungs[0].label, top = rungs[rungs.length - 1].label;
	const heldCut = cutNames()[ccRungs(cc, 'clarity')[0].cut] || 'Good';
	const keys = orderedSkills().filter((k) => C.skill(k).color !== C.OPAL);
	const rows = Object.fromEntries(keys.map((k) => [k, ccRow(cc, rungs, k)]));
	if (!rows[state.gem]) state.gem = 'STRIKE';
	const bowls = state.bowl === 'ALL' ? 'average of the six bowls' : `${bowlName(state.bowl)}’s bowl`;
	body.append(sweepBar(ctx, 'cutclarity', [
		field('Compare', segmented(Object.entries(CC_COMPARES), compare, (v) => { state.ccCompare = v; ctx.rerender(); }),
			`Cut: every Cut, the stone Clear. Clarity: a Clear stone against a Flawless one, both ${heldCut} cut; a Flawless stone hits half as hard again and carries its Flawless line.`),
		field('Show', segmented([['level', 'Value a turn'], ['gain', 'Gain %']], gain ? 'gain' : 'level', (v) => { state.ccShow = v; ctx.rerender(); }),
			`Gain: every rung over the bottom one, as a share of it. Gems worth under ${CC_FLOOR} a turn on the bottom rung are left out.`),
		field('Bowls', bowlSelect(state.bowl, (v) => { state.bowl = v; ctx.rerender(); })),
		scaleField(ctx)]));

	// Every gem as a ladder of its rungs, sorted within its color by its top rung.
	const groups = colorGroups((color) => keys.filter((k) => C.skill(k).color === color).map((k) => {
		const r = rows[k];
		const vals = gain ? r.gains : r.levels;
		return { key: k, label: C.skill(k).name, avg: vals[vals.length - 1],
			rungs: rungs.map((rung, i) => ({ label: rung.label, value: vals[i], tip: `${fmtV(r.levels[i])}${i && Number.isFinite(r.gains[i]) ? ` · ${fmtGain(r.gains[i])}` : ''}` })) };
	}).filter((it) => Number.isFinite(it.avg)).sort((a, b) => b.avg - a.avg)).filter((g) => g.key !== C.OPAL);
	const between = rungs.slice(1, -1).map((r) => r.label);
	const ticks = between.length ? `, a tick at ${listed(between)}` : '';
	const marks = gain ? `a stem from no gain up to ${top}${ticks}` : `hollow mark ${bottom}${ticks}, filled ${top}`;
	const held = compare === 'clarity' ? `${heldCut} cut` : 'Clear';
	body.append(card(`${CC_COMPARES[compare]}, ${held} · ${gain ? `gain over ${bottom}` : 'value a turn'}`, h('div', { class: 'bal-chart', style: { height: '240px' } },
		rangeStrip({ groups, width: 1150, height: 240, format: gain ? fmtGain : fmtV, selected: state.gem, independent: state.scale === 'own', baseMark: !gain, onSelect: (it) => { state.gem = it.key; ctx.rerender(); } })),
	{ meta: `${marks} · hairline, its color’s median · ${bowls} · click a gem` }));

	const color = C.skill(state.gem).color;
	const inColor = keys.filter((k) => C.skill(k).color === color);
	const flagOf = outlierOf(inColor.map((k) => rows[k].gain), 0.1);
	const tableRows = inColor.map((k) => ({ ...rows[k], flag: flagOf(rows[k].gain) }));
	const columns = [
		{ key: 'name', label: 'Gem', sort: (r) => C.skill(r.key).name, render: (r) => gemCell(r.key) },
		...rungs.map((rung, i) => ({ key: `r${i}`, label: rung.label, align: 'right', sort: (r) => orLast(r.levels[i]), render: (r) => (i === rungs.length - 1 ? h('b', {}, fmtV(r.levels[i])) : fmtV(r.levels[i])) })),
		{ key: 'gain', label: 'Gain', align: 'right', title: `${top} over ${bottom}, as a share of ${bottom}`, sort: (r) => orLast(r.gain), render: (r) => h('b', { class: r.gain > 0 ? 'delta-up' : r.gain < 0 ? 'delta-down' : '' }, fmtGain(r.gain)) },
	];
	// The bowls' names make room for the Flawless line beside a clarity, and stay in the tooltip.
	const bowlCell = (v, bowl) => h('span', { title: `${bowlName(bowl || '')}’s bowl` }, fmtGain(v), compare === 'cut' ? h('span', { class: 'inline-sub' }, bowlName(bowl || '')) : null);
	columns.push({ key: 'worst', label: 'Worst bowl', align: 'right', sort: (r) => orLast(r.worst), render: (r) => bowlCell(r.worst, r.worstBowl) },
		{ key: 'best', label: 'Best bowl', align: 'right', sort: (r) => orLast(r.best), render: (r) => bowlCell(r.best, r.bestBowl) });
	if (compare === 'clarity') columns.push({ key: 'line', label: 'Flawless line', sort: (r) => flawlessLine(cc, r.key), render: (r) => h('span', { class: 'small text-2' }, flawlessLine(cc, r.key)) });
	columns.push({ key: 'flag', label: '', sort: false, render: (r) => flagCell(r.flag) });
	const sortTab = `cutclarity:${compare}`;
	const sort = state.sort && state.sort.tab === sortTab ? state.sort : { tab: sortTab, key: gain ? 'gain' : `r${rungs.length - 1}`, dir: -1 };
	const split = h('div', { class: 'bal-split' });
	split.append(card(`${C.colorName(color)} gems`, table({ columns, rows: sortRows(tableRows, columns, sort), sort, compact: true, selectedKey: state.gem, rowKey: (r) => r.key, sticky: false,
		onSort: (k) => { state.sort = { tab: sortTab, ...toggleSort(sort, k, k === 'name' || k === 'line' ? 1 : -1) }; ctx.rerender(); },
		onRowClick: (r) => { state.gem = r.key; ctx.rerender(); } }), { meta: `median gain ${fmtGain(median(inColor.map((k) => rows[k].gain)))} · value a turn, ${bowls} · worst and best of the six bowls`, pad: false, class: 'dense' }));
	split.append(ccDetail(cc, compare, state.gem));
	body.append(split);
}

function ccDetail(cc, compare, key) {
	const def = C.skill(key);
	const cut = ccRow(cc, ccRungs(cc, 'cut'), key);
	const clarity = ccRow(cc, ccRungs(cc, 'clarity'), key);
	const rungs = ccRungs(cc, compare);
	const shown = compare === 'clarity' ? clarity : cut;
	const flawless = C.clarityEntry(Balance.clarityOf('FLAWLESS'));
	const also = [flawless.magnitude ? `×${flawless.magnitude} magnitude` : '', flawless.resonance_mult ? `×${flawless.resonance_mult} Resonance` : ''].filter(Boolean).join(', ');
	const line = flawlessLine(cc, key);
	// What every Cut asks of the hand, the card's numbers at that Cut when they move with it, and
	// what the Clear stone is worth there.
	const trigger = def.trigger || { kind: 'always' };
	const texts = cutNames().map((_, i) => Rules.fill(def.text || '', def.numbers || {}, i));
	const textMoves = new Set(texts).size > 1;
	const heldCut = ccRungs(cc, 'clarity')[0].cut;
	const ladder = cutNames().map((name, i) => ({ key: i, cut: name, words: Patterns.words(trigger, i), text: texts[i], value: cut.levels[i] }));
	return card(null, h('div', { class: 'col', style: { gap: '8px' } },
		h('div', { class: 'row', style: { alignItems: 'flex-start', flexWrap: 'nowrap' } }, gemImage(key, 52), h('div', { class: 'col', style: { gap: '2px' } }, h('h2', { style: { fontSize: '16px' } }, def.name), h('p', { class: 'small text-2 two-line' }, texts[heldCut] || ''))),
		line ? h('p', { class: 'small text-2' }, h('b', { style: { color: CLARITY_COLORS[5] } }, 'Flawless: '), line, also ? h('span', { class: 'inline-sub' }, `with ${also}`) : null) : null,
		h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' } },
			stat(`${cutNames()[ccRungs(cc, 'clarity')[0].cut] || 'Good'}, Clear`, fmtV(clarity.levels[0]), 'value a turn'),
			stat('Cut gain', fmtGain(cut.gain), `${fmtV(cut.levels[0])} → ${fmtV(cut.top)}`, { class: compare === 'cut' ? 'accent' : '' }),
			stat('Flawless gain', fmtGain(clarity.gain), `${fmtV(clarity.levels[0])} → ${fmtV(clarity.top)}`, { class: compare === 'clarity' ? 'accent' : '' })),
		h('div', { class: 'section-title' }, `Cut ladder · ${Patterns.KIND_NAMES[trigger.kind] || C.title(trigger.kind || 'always')}`),
		table({ columns: [
			{ key: 'cut', label: 'Cut', render: (r) => h('span', { class: 'row tight', style: { flexWrap: 'nowrap' } }, h('i', { class: 'dot', style: { background: CUT_COLORS[r.key] } }), r.cut) },
			{ key: 'words', label: 'Asks for', render: (r) => h('span', { class: 'small text-2' }, r.words, textMoves ? h('span', { class: 'cell-sub' }, r.text) : null) },
			{ key: 'value', label: 'Clear', align: 'right', render: (r) => fmtV(r.value) },
		], rows: ladder, compact: true, sticky: false, rowKey: (r) => r.key, selectedKey: compare === 'clarity' ? heldCut : null }),
		h('div', { class: 'section-title' }, `By bowl · ${rungs[0].label} → ${rungs[rungs.length - 1].label}`),
		table({ columns: [
			{ key: 'bowl', label: 'Bowl', render: (b) => bowlName(b.bowl) },
			{ key: 'base', label: rungs[0].label, align: 'right', render: (b) => fmtV(b.base) },
			{ key: 'top', label: rungs[rungs.length - 1].label, align: 'right', render: (b) => h('b', {}, fmtV(b.top)) },
			{ key: 'gain', label: 'Gain', align: 'right', render: (b) => h('span', { class: b.gain > 0 ? 'delta-up' : b.gain < 0 ? 'delta-down' : '' }, fmtGain(b.gain)) },
		], rows: shown.bowls, compact: true, sticky: false, rowKey: (b) => b.bowl })), { class: 'dense' });
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
	split.append(card('What an inclusion adds, by color', h('div', { class: 'col' },
		heatmap({ rows: incs.map((i) => C.inclusion(i).name || i), cols, values, format: fmtU, min: -absMax, max: absMax, colorFor: (v) => diverge(v / absMax), rowLabelWidth: 128, cellHeight: 14,
			selected: `${incs.indexOf(state.inclusion)}:0`, onSelect: (i) => { state.inclusion = incs[i]; ctx.rerender(); } }),
		h('div', { class: 'row between' }, rampKey((v) => diverge(v / absMax), -absMax, absMax, fmtU, 'uplift'), h('span', { class: 'tiny muted' }, 'Rows run Pinpoint, Lens, Feather, Fracture, Star · click a row'))), { class: 'tight-heat', meta: `an 8-carat Good stone, averaged over each color’s gems · ${state.bowl === 'ALL' ? 'all six bowls' : `${bowlName(state.bowl)}’s bowl`}` }));
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
		['ALEXANDRITE', 'ZONING_RED', 'ZONING_BLUE', 'ZONING_GREEN', 'ZONING_VIOLET', 'ZONING_GOLD', 'ZONING_WHITE'].includes(key) ? note('Mostly worth where it lets a stone sit (a colored socket) and the Harmony it finds beside its new color, which a lone gem in an Any socket cannot show.', 'plain') : null,
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
	{ meta: `a dot a gem, in its color and shape · the box is the middle half, the line the median · click a dot to follow a gem${relative ? ' · gems worth under 2 a turn are left out' : ''}` }));

	const colors = C.SKILL_COLORS.filter((c) => c !== 'OPAL');
	const heatValues = gems.bowls.map((b) => colors.map((c) => { const ks = skills.filter((k) => C.skill(k).color === c); return ks.reduce((s, k) => s + v(b, k), 0) / ks.length; }));
	const top = Math.max(1e-9, ...heatValues.flat());
	const split = h('div', { class: 'grid', style: { gridTemplateColumns: 'minmax(0, 2fr) minmax(0, 3fr)' } });
	split.append(card('Average gem by color', h('div', { class: 'col' }, heatmap({ rows: gems.bowls.map(bowlName), cols: colors.map((c) => C.colorName(c)), values: heatValues, format: fmtV, max: top, rowLabelWidth: 80, cellHeight: 28 }),
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
			h('span', { class: 'tiny muted' }, 'Gems run by color, the strips along the edges are their colors; hover for names.'))),
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
	let value = 0, n = 0, runaways = 0;
	for (const b of bowls) {
		const r = Balance.railValue(rails, b, skill, W());
		if (!r) continue;
		value += r.value; n += 1;
		r.changed.forEach((x, j) => { changed[j] += x; });
		r.places.forEach((x, j) => { places[j] += x; });
		for (const p of r.perHost) { const at = hosts.get(p.host) || { host: p.host, gems: p.gems, value: 0, n: 0 }; at.value += p.value; at.n += 1; hosts.set(p.host, at); }
		runaways += r.runaways || 0;
	}
	if (!n) return null;
	return { value: value / n / T, changed: changed.map((x) => x / n / T), places, runaways, hosts: [...hosts.values()].map((x) => ({ ...x, value: x.value / x.n / T })).sort((a, b) => b.value - a.value) };
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
		{ key: 'loops', label: '', render: (k) => (over[k] && over[k].runaways ? h('span', { class: 'flag high', title: `Spent at ${Balance.RAIL_CAP} gems in a turn in ${over[k].runaways} host rail${over[k].runaways === 1 ? '' : 's'}, over the bowls: its numbers there are what it did until then` }, 'runs away') : '') },
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

// --- Carat bands --------------------------------------------------------------------------------

const fmtShare = (v) => (Number.isFinite(v) ? fmtPct(v) : '—');
const fmtTimes = (v) => (Number.isFinite(v) ? `${fmt(v, v < 10 ? 1 : 0)}×` : '—');
const bandShort = (b) => `${b.carat}c · ${C.mine(b.mine).name || C.title(b.mine)}${b.key.includes('@') ? ` ${b.depth}` : ''}`;

// A gem across the bands, over the chosen bowls: what it adds to the host rails at each band
// (a turn), what the hosts do alone there, the first as a share of the second, and how much
// that share grows from the first band to the last.
function caratRow(res, skill) {
	const bands = res.bands || [];
	const bowls = state.bowl === 'ALL' ? res.bowls : [state.bowl];
	const value = bands.map(() => 0);
	const host = bands.map(() => 0);
	let n = 0;
	for (const b of bowls) {
		const curve = Balance.caratCurve(res, b, skill, W());
		if (!curve.length) continue;
		curve.forEach((c, i) => { value[i] += c.value; host[i] += c.host; });
		n += 1;
	}
	if (!n) return null;
	const T = turnsOf(res);
	const v = value.map((x) => x / n / T);
	const hv = host.map((x) => x / n / T);
	const share = v.map((x, i) => (hv[i] > 0 ? x / hv[i] : NaN));
	const first = share[0], last = share[share.length - 1];
	const growth = Number.isFinite(first) && Number.isFinite(last) ? last / Math.max(first, 0.05) : NaN;
	return { value: v, host: hv, share, first, last, growth, flag: growth >= 2 && last >= 0.1 ? 'outgrows' : last >= 1 ? 'doubles' : '' };
}

function caratsTab(body, ctx) {
	const res = Sweeps.get('carats');
	body.append(sweepBar(ctx, 'carats', res ? [field('Gem', gemSelect(ctx, state.gem, (v) => { state.gem = v; ctx.rerender(); })), field('Bowls', bowlSelect(state.bowl, (v) => { state.bowl = v; ctx.rerender(); }))] : []));
	if (!res) {
		needSweep(ctx, body, 'carats', `Every gem set into ${state.settings.caratHosts} rails of four other gems (the same rails on every bowl) at every mine’s carats: the cap of the mine’s carat band at its boss, with its creatures’ health and blows (the Rift twice, three Wardens down and seven, where it reaches 24 carats). What a gem adds is read as a share of what the host rail does alone at the same band, so a gem whose share climbs with the carats is one the rail cannot keep up with. Needs the Gems sweep, which runs first if it has not.`);
		return;
	}
	const bands = res.bands || [];
	const skills = orderedSkills();
	const rows = Object.fromEntries(skills.map((k) => [k, caratRow(res, k)]));
	if (!rows[state.gem]) state.gem = 'STRIKE';
	const growers = skills.filter((k) => rows[k] && Number.isFinite(rows[k].growth)).sort((a, b) => rows[b].growth - rows[a].growth).slice(0, 24);
	const shares = growers.flatMap((k) => rows[k].share).filter(Number.isFinite).sort((a, b) => a - b);
	const shareCap = Math.max(0.5, shares.length ? shares[Math.floor((shares.length - 1) * 0.97)] : 0);
	body.append(card('The fastest growers · what a gem adds, as a share of its host rail', h('div', { class: 'col' },
		heatmap({ rows: growers.map((k) => `${C.skill(k).name} ${fmtTimes(rows[k].growth)}`), cols: bands.map(bandShort), values: growers.map((k) => rows[k].share), format: fmtShare, max: shareCap, min: 0,
			rowLabelWidth: 150, cellHeight: 18, selected: growers.includes(state.gem) ? `${growers.indexOf(state.gem)}:0` : null, onSelect: (i) => { state.gem = growers[i]; ctx.rerender(); } }),
		h('div', { class: 'row between' }, rampKey((v) => heat(v / shareCap), 0, shareCap, fmtShare, 'share of the host rail'),
			h('span', { class: 'tiny muted' }, 'The 24 gems whose share grows most from the first band to the last (the × by the name) · click a row'))),
	{ class: 'tight-heat', meta: `${state.bowl === 'ALL' ? 'average of the six bowls' : `${bowlName(state.bowl)}’s bowl`} · ${state.weights.fight === 'boss' ? 'boss fight' : 'ordinary fight'} · each gem in its best place over ${res.hosts.length} hosts` }));

	const color = C.skill(state.gem).color;
	const inColor = skills.filter((k) => C.skill(k).color === color && rows[k]);
	const columns = [
		{ key: 'name', label: 'Gem', sort: (k) => C.skill(k).name, render: (k) => gemCell(k) },
		...bands.map((b, i) => ({ key: `b${i}`, label: `${b.carat}c`, align: 'right', title: b.name, sort: (k) => rows[k].share[i], render: (k) => h('span', { class: 'small' }, fmtShare(rows[k].share[i])) })),
		{ key: 'growth', label: 'Grows', align: 'right', title: 'Its share at the last band over its share at the first', sort: (k) => rows[k].growth, render: (k) => h('b', {}, fmtTimes(rows[k].growth)) },
		{ key: 'flag', label: '', sort: false, render: (k) => (rows[k].flag ? h('span', { class: 'flag high', title: rows[k].flag === 'outgrows' ? 'Its share of the rail at least doubles from the first band to the last' : 'Adds more than the rest of the rail does at the last band' }, rows[k].flag === 'outgrows' ? 'outgrows the rail' : 'doubles the rail') : '') },
	];
	const sort = state.sort && state.sort.tab === 'carats' ? state.sort : { tab: 'carats', key: 'growth', dir: -1 };
	const split = h('div', { class: 'bal-split' });
	split.append(card(`${C.colorName(color)} gems · share of the host rail`, table({ columns, rows: sortRows(inColor, columns, sort), sort, compact: true, sticky: false, selectedKey: state.gem, rowKey: (k) => k,
		onSort: (k) => { state.sort = { tab: 'carats', ...toggleSort(sort, k, k === 'name' ? 1 : -1) }; ctx.rerender(); }, onRowClick: (k) => { state.gem = k; ctx.rerender(); } }), { pad: false, class: 'dense' }));
	const r = rows[state.gem];
	const medianShare = bands.map((_, i) => median(skills.map((k) => rows[k] && rows[k].share[i])));
	const series = [
		{ label: C.skill(state.gem).name, color: markColor(color), shape: SHAPES[color], points: r.share.map((y, x) => ({ x, y: Number.isFinite(y) ? y : 0 })) },
		{ label: 'median gem', color: 'var(--muted)', points: medianShare.map((y, x) => ({ x, y: Number.isFinite(y) ? y : 0 })), dim: true },
	];
	split.append(card(null, h('div', { class: 'col', style: { gap: '8px' } },
		h('div', { class: 'row', style: { alignItems: 'flex-start', flexWrap: 'nowrap' } }, gemImage(state.gem, 48), h('div', { class: 'col', style: { gap: '2px' } }, h('h2', { style: { fontSize: '16px' } }, C.skill(state.gem).name), h('p', { class: 'small text-2 two-line' }, C.skill(state.gem).text || ''))),
		h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' } }, stat('First band', fmtShare(r.first), `${fmtBig(r.value[0])} a turn`), stat('Last band', fmtShare(r.last), `${fmtBig(r.value[r.value.length - 1])} a turn`, { class: 'accent' }), stat('Grows', fmtTimes(r.growth), 'its share, first to last')),
		h('div', { class: 'section-title' }, 'Share of the host rail, band by band'),
		lines({ series, width: 520, height: 200, xLabels: Object.fromEntries(bands.map((b, i) => [i, `${b.carat}c`])), format: fmtShare, legend: false }),
		h('p', { class: 'tiny muted' }, `The host rails alone: ${bands.map((b, i) => fmtBig(r.host[i])).join(' → ')} a turn.`))));
	body.append(split);

	body.append(card('The bands', table({ columns: [
		{ key: 'name', label: 'Mine', render: (b) => h('b', {}, b.name) },
		{ key: 'carat', label: 'Carats', align: 'right', render: (b) => String(b.carat) },
		{ key: 'hp', label: 'Creature health', align: 'right', render: (b) => fmtTimes(b.hp) },
		{ key: 'damage', label: 'Blows', align: 'right', render: (b) => fmtTimes(b.damage) },
		{ key: 'boss', label: 'Boss · kill line', render: (b) => h('span', { class: 'small' }, `${b.bossName} · ${fmt(b.bossHp, 0)} health`) },
	], rows: bands, compact: true, sticky: false, rowKey: (b) => b.key }), { pad: false, class: 'dense', meta: 'each mine at its boss: the cap of its carat band there, its creatures against the Quarry’s, and its boss’s health' }));
}

// --- Combo hunt ---------------------------------------------------------------------------------

const fmtTurns = (v) => (!Number.isFinite(v) ? 'never' : v < 0.1 ? 'under 0.1' : fmt(v, v < 10 ? 1 : 0));
// A value a hunt can find: anything from a few points a turn to millions, kept short.
const fmtBig = (v) => (!Number.isFinite(v) ? '—' : Math.abs(v) >= 1e6 ? `${fmt(v / 1e6, 1)}M` : Math.abs(v) >= 1e4 ? `${fmt(v / 1e3, 0)}k` : fmtV(v));
const signedBig = (v) => (Number.isFinite(v) ? `${v > 0 ? '+' : ''}${fmtBig(v)}` : '—');

function huntTab(body, ctx) {
	const hunt = Sweeps.get('hunt');
	const bandsHunted = hunt ? hunt.bands || [] : [];
	if (hunt && !bandsHunted.some((b) => b.key === state.huntBand)) state.huntBand = (bandsHunted[0] || {}).key || '';
	body.append(sweepBar(ctx, 'hunt', hunt ? [field('Band', select(bandsHunted.map((b) => [b.key, `${b.name} · ${b.carat} carats`]), state.huntBand, (v) => { state.huntBand = v; state.huntBuild = ''; ctx.rerender(); }, { style: 'width:230px' })),
		field('Bowls', bowlSelect(state.bowl, (v) => { state.bowl = v; state.huntBuild = ''; ctx.rerender(); }))] : []));
	if (!hunt) {
		needSweep(ctx, body, 'hunt', `A search for the strongest whole rails. On every bowl, at each hunted band, it starts from the bowl’s best gems alone, a random rail and a random rail ending in two opals, and walks each one socket by socket: every gem that could sit there and every swap is played in the boss fight, and the best is kept. Then what it found is played again on fresh fights beside the plain rail (the bowl’s best gems alone) and a dozen random rails. Rails that never stop firing are kept aside and listed. Needs the Gems sweep, which runs first if it has not.`);
		return;
	}
	const T = turnsOf(hunt);
	const w = W();
	const name = (k) => C.skill(k).name || k;
	if (w.fight !== 'boss') body.append(note('Read in the ordinary fight, where no rail can deal more than the dummies’ health: the hunt searched in the boss fight, and the Boss fight toggle above shows what it found uncapped. The kill turns are the boss fight’s either way.', 'plain'));
	const bowls = state.bowl === 'ALL' ? hunt.bowls : [state.bowl];
	const reports = {};
	for (const band of bandsHunted) for (const bowl of hunt.bowls) reports[`${bowl}|${band.key}`] = Balance.huntReport(hunt, bowl, band.key, w);
	const turnsFor = (vector, band) => Balance.killTurns(vector, band.bossHp, T);

	// Every band: the strongest rail on any bowl, against that bowl's plain rail.
	const summary = bandsHunted.map((band) => {
		let best = null;
		for (const bowl of bowls) {
			const r = reports[`${bowl}|${band.key}`];
			if (!r || !r.builds.length) continue;
			const top = r.builds[0];
			const ratio = r.plain && r.plain.value > 0 ? top.value / r.plain.value : NaN;
			if (!best || !(best.ratio >= ratio)) best = { key: band.key, band, bowl, top, plain: r.plain, ratio, r };
		}
		return best || { key: band.key, band, r: null };
	});
	const loopsIn = (bandKey) => (hunt.runaways || []).filter((x) => x.band === bandKey && bowls.includes(x.bowl)).length;
	body.append(card('Every hunted band · the strongest rail found', table({ columns: [
		{ key: 'band', label: 'Band', render: (x) => h('span', { class: 'cell-name' }, h('b', {}, x.band.name), h('span', { class: 'inline-sub' }, `${x.band.carat} carats`)) },
		{ key: 'boss', label: 'Kill line', render: (x) => h('span', { class: 'small text-2' }, `${x.band.bossName} · ${fmt(x.band.bossHp, 0)}`) },
		{ key: 'rail', label: 'Strongest rail', render: (x) => (x.top ? h('span', { class: 'small', title: x.top.rail.map(name).join(' → ') }, h('b', {}, `${bowlName(x.bowl)}: `), x.top.rail.map(name).join(', ')) : '—') },
		{ key: 'turns', label: 'Kills it in', align: 'right', title: 'Turns to bring the boss down, at the pace it set in the boss fight', render: (x) => (x.top ? h('b', {}, fmtTurns(turnsFor(x.top.vector, x.band))) : '—') },
		{ key: 'plain', label: 'Plain rail', align: 'right', title: 'The same bowl’s best gems alone', render: (x) => (x.plain ? fmtTurns(turnsFor(x.plain.vector, x.band)) : '—') },
		{ key: 'random', label: 'Random rail', align: 'right', title: 'The middle of a dozen random rails', render: (x) => (x.r ? fmtTurns(x.r.randomTurns) : '—') },
		{ key: 'ratio', label: '× plain', align: 'right', title: 'Its value over the plain rail’s, in the fight shown', render: (x) => (Number.isFinite(x.ratio) ? h('span', { class: x.ratio > HUNT_LIMIT ? 'flag high' : '' }, fmtTimes(x.ratio)) : '—') },
		{ key: 'loops', label: 'Runaways', align: 'right', render: (x) => (loopsIn(x.key) ? h('span', { class: 'flag high' }, String(loopsIn(x.key))) : h('span', { class: 'muted' }, '·')) },
	], rows: summary, compact: true, sticky: false, selectedKey: state.huntBand, rowKey: (x) => x.key, onRowClick: (x) => { state.huntBand = x.key; state.huntBuild = ''; ctx.rerender(); } }),
	{ pad: false, class: 'dense', meta: `${state.bowl === 'ALL' ? 'the bowl where it beats its plain rail most' : `${bowlName(state.bowl)}’s bowl`} · flagged over ${HUNT_LIMIT}× the plain rail, the gate’s line · ${hunt.rounds} rounds, ${fmt(hunt.seconds || 0, 0)}s` }));

	const band = bandsHunted.find((b) => b.key === state.huntBand);
	if (!band) return;
	const builds = [];
	for (const bowl of bowls) {
		const r = reports[`${bowl}|${band.key}`];
		if (!r) continue;
		r.builds.forEach((b, i) => builds.push({ ...b, bowl, rank: i + 1, id: `${bowl}|${b.key}`, plain: r.plain, turns: turnsFor(b.vector, band), runaway: (b.vector[Balance.RUNAWAY] || 0) > 0, r }));
	}
	builds.sort((a, b) => b.value - a.value);
	if (!builds.some((b) => b.id === state.huntBuild)) state.huntBuild = (builds[0] || {}).id || '';
	const railCell = (rail) => h('span', { class: 'row tight', style: { flexWrap: 'nowrap', gap: '2px' }, title: rail.map(name).join(' → ') }, rail.map((k) => gemImage(k, 18)));
	const split = h('div', { class: 'bal-split' });
	split.append(card(`${band.name} · every rail the hunt ended on`, table({ columns: [
		{ key: 'bowl', label: 'Bowl', render: (b) => h('span', { class: 'small' }, bowlName(b.bowl)) },
		{ key: 'rail', label: 'Rail', render: (b) => railCell(b.rail) },
		{ key: 'value', label: 'Value', align: 'right', title: 'A turn, over the empty rail, in the fight shown', render: (b) => h('b', {}, fmtBig(perTurn(hunt, b.value))) },
		{ key: 'ratio', label: '× plain', align: 'right', render: (b) => (b.plain && b.plain.value > 0 ? fmtTimes(b.value / b.plain.value) : '—') },
		{ key: 'synergy', label: 'Synergy', align: 'right', title: 'A turn: the rail over its gems played alone, summed', render: (b) => h('span', { class: b.synergy >= 0 ? 'delta-up' : 'delta-down' }, signedBig(perTurn(hunt, b.synergy))) },
		{ key: 'turns', label: 'Kills in', align: 'right', render: (b) => fmtTurns(b.turns) },
		{ key: 'flag', label: '', render: (b) => (b.runaway ? h('span', { class: 'flag high', title: `On the fresh fights the game spent it at ${Balance.RAIL_CAP} gems in a turn` }, 'runs away') : '') },
	], rows: builds, compact: true, sticky: false, selectedKey: state.huntBuild, rowKey: (b) => b.id, onRowClick: (b) => { state.huntBuild = b.id; ctx.rerender(); } }),
	{ pad: false, class: 'dense', meta: `${band.carat}-carat Good Clear stones · ${band.bossName}, ${fmt(band.bossHp, 0)} health · creatures ${fmtTimes(band.hp)} health, ${fmtTimes(band.damage)} blows` }));
	const pick = builds.find((b) => b.id === state.huntBuild);
	split.append(pick ? huntDetail(hunt, band, pick, T) : card(null, note('Nothing found on this bowl at this band.', 'plain')));
	body.append(split);

	const loops = (hunt.runaways || []).filter((x) => bowls.includes(x.bowl));
	if (loops.length) {
		const cores = Balance.runawayCores({ runaways: loops }).slice(0, 5);
		body.append(card(`Runaways · ${loops.length} rail${loops.length === 1 ? '' : 's'} spent at ${Balance.RAIL_CAP} gems in a turn`, h('div', { class: 'col', style: { gap: '8px' } },
			note(`These rails played ${Balance.RAIL_CAP} gems in a single turn, where the game spends a rail: what is still queued for it is dropped and the turn goes on. Some would have stopped a little later, some never (two Geminis side by side wake each other for ever while the hand holds a pair). The hunt walks around them, so the rails above are what it found without them.`, 'warn'),
			h('div', { class: 'section-title' }, 'Neighbours most of them share'),
			h('div', { class: 'bal-list' }, cores.map((c) => h('div', { class: 'bal-list-row' }, gemImage(c.pair[0], 16), h('span', { class: 'small' }, `${name(c.pair[0])} → ${name(c.pair[1])}`), h('span', { class: 'v' }, fmtPct(c.share))))),
			h('div', { class: 'section-title' }, 'Some of them'),
			h('div', { class: 'bal-list' }, loops.slice(0, 5).map((x) => h('div', { class: 'bal-list-row', style: { gridTemplateColumns: '96px auto minmax(0, 1fr)' }, title: x.rail.map(name).join(' → ') }, h('span', { class: 'tiny muted' }, `${bowlName(x.bowl)} · ${(bandsHunted.find((b) => b.key === x.band) || {}).carat || ''}c`), railCell(x.rail), h('span', { class: 'small' }, x.rail.map(name).join(', '))))))));
	}
}

function huntDetail(hunt, band, b, T) {
	const name = (k) => C.skill(k).name || k;
	const searches = (hunt.searches || []).filter((x) => x.bowl === b.bowl && x.band === band.key && x.rail.join(',') === b.rail.join(','));
	const START_NAMES = { plain: 'the bowl’s best gems alone', random: 'a random rail', opals: 'a random rail ending in two opals' };
	const stepRow = (s) => {
		const changed = s.to.map((k, i) => (k !== s.from[i] ? i : -1)).filter((i) => i >= 0);
		const text = changed.length === 2 && s.to[changed[0]] === s.from[changed[1]] ? `swap sockets ${changed[0] + 1} and ${changed[1] + 1}` : changed.map((i) => `${name(s.from[i])} → ${name(s.to[i])}`).join(', ');
		return h('div', { class: 'bal-list-row', style: { gridTemplateColumns: '104px minmax(0, 1fr) auto' } }, h('span', { class: 'tiny muted' }, `pass ${s.pass + 1} · socket ${s.socket + 1}`), h('span', { class: 'small' }, text), h('span', { class: 'v delta-up' }, `+${fmtPct(s.after / Math.max(1e-9, Math.abs(s.before)) - 1)}`));
	};
	return card(null, h('div', { class: 'col', style: { gap: '8px' } },
		h('div', { class: 'row', style: { flexWrap: 'wrap', gap: '6px' } }, h('b', {}, `${bowlName(b.bowl)}’s bowl`), b.runaway ? h('span', { class: 'flag high' }, 'runs away') : null),
		h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(4, minmax(0, 1fr))' } },
			stat('Value', fmtBig(perTurn(hunt, b.value)), 'a turn', { class: 'accent' }), stat('Kills the boss in', fmtTurns(b.turns), 'turns'), stat('Synergy', signedBig(perTurn(hunt, b.synergy)), 'over its gems alone'),
			stat('Fires', fmtV(perTurn(hunt, b.vector[3])), 'gems a turn')),
		h('div', { class: 'section-title' }, 'In socket order, and each gem alone'),
		h('div', { class: 'bal-list' }, b.rail.map((k, i) => h('div', { class: 'bal-list-row' }, h('span', { class: 'tiny muted' }, String(i + 1)), h('span', { class: 'cell-name' }, gemImage(k, 18), h('span', { class: 'small' }, name(k)), rarityChip(C.skill(k).rarity)),
			h('span', { class: 'v' }, fmtBig(perTurn(hunt, b.r.solo(k))))))),
		h('div', { class: 'section-title' }, searches.length ? `Found from ${searches.map((x) => START_NAMES[x.start] || x.start).join(' and from ')}` : 'How it was found'),
		h('div', { class: 'bal-list' }, (searches[0] ? searches[0].steps : []).slice(-8).map(stepRow)),
		h('p', { class: 'tiny muted' }, `The plain rail here: ${b.plain ? b.plain.rail.map(name).join(', ') : '—'}, ${b.plain ? fmtBig(perTurn(hunt, b.plain.value)) : '—'} a turn.`)));
}

// --- Growth ---------------------------------------------------------------------------------------

// A gem over a run and over one long fight, on the chosen bowls: its value in each fight of the
// run and in each turn of the long fight (a turn, over its host), early against late.
function growthRow(res, skill) {
	const bowls = state.bowl === 'ALL' ? res.bowls : [state.bowl];
	const L = Balance.growthLayout(res.settings);
	const fights = new Array(L.fights).fill(0);
	const turns = new Array(L.turns).fill(0);
	let n = 0;
	for (const b of bowls) {
		const g = Balance.growthValue(res, b, skill, W());
		if (!g) continue;
		g.fights.forEach((v, i) => { fights[i] += v; });
		g.turns.forEach((v, i) => { turns[i] += v; });
		n += 1;
	}
	if (!n) return null;
	const T = turnsOf(res);
	const run = fights.map((v) => v / n / T);
	const fight = turns.map((v) => v / n);
	const late = (xs) => xs.slice(-3).reduce((a, x) => a + x, 0) / Math.min(3, xs.length);
	const read = (xs) => {
		const early = xs[0], end = late(xs);
		return { series: xs, early, late: end, gain: end - early, ratio: end / Math.max(Math.abs(early), 0.5) };
	};
	return { run: read(run), fight: read(fight) };
}

function growthTab(body, ctx) {
	const res = Sweeps.get('growth');
	const view = state.growthView === 'fight' ? 'fight' : 'run';
	body.append(sweepBar(ctx, 'growth', res ? [field('Over', segmented([['run', `A run of ${res.settings.runFights} fights`], ['fight', `One ${res.settings.longTurns}-turn fight`]], view, (v) => { state.growthView = v; ctx.rerender(); }),
		'A run: the ordinary fight again and again, keeping what lasts the run. A long fight: the boss fight, turn by turn.'),
	field('Gem', gemSelect(ctx, state.gem, (v) => { state.gem = v; ctx.rerender(); })), field('Bowls', bowlSelect(state.bowl, (v) => { state.bowl = v; ctx.rerender(); }))] : []));
	if (!res) {
		needSweep(ctx, body, 'growth', `What a gem is worth when it is kept. Every gem is set into ${state.settings.caratHosts} host rails, first and last, and plays a run of ${state.settings.runFights} ordinary fights one after another, keeping what lasts the run: the faces a Glimmer raised, a Hydrophane’s drops, how often a Hone has fired, a Heartwood’s health. Then one ${state.settings.longTurns}-turn boss fight, turn by turn, for what grows within a fight (Temper, Fire Opal, Echo, Arsenic). Needs the Gems sweep, which runs first if it has not.`);
		return;
	}
	const skills = orderedSkills();
	const rows = Object.fromEntries(skills.map((k) => [k, growthRow(res, k)]));
	if (!rows[state.gem]) state.gem = 'GLIMMER';
	const of = (k) => rows[k] && rows[k][view];
	const unit = view === 'run' ? 'fight' : 'turn';
	const n = view === 'run' ? res.settings.runFights : res.settings.longTurns;
	const growers = skills.filter((k) => of(k) && Number.isFinite(of(k).gain)).sort((a, b) => of(b).gain - of(a).gain);
	const listRow = (k) => h('div', { class: 'bal-list-row clickable', onClick: () => { state.gem = k; ctx.rerender(); } }, colorKeyMark(C.skill(k).color, 14), h('span', { class: 'small' }, C.skill(k).name),
		h('span', { class: 'row tight', style: { flexWrap: 'nowrap' } }, sparkline(of(k).series.map((v) => Math.max(0, v)), { color: markColor(C.skill(k).color) }), h('span', { class: `v ${of(k).gain >= 0 ? 'delta-up' : 'delta-down'}` }, signed(of(k).gain))));
	const color = C.skill(state.gem).color;
	const inColor = skills.filter((k) => C.skill(k).color === color && of(k));
	const columns = [
		{ key: 'name', label: 'Gem', sort: (k) => C.skill(k).name, render: (k) => gemCell(k) },
		{ key: 'early', label: view === 'run' ? 'Fight 1' : 'Turn 1', align: 'right', sort: (k) => of(k).early, render: (k) => fmtV(of(k).early) },
		{ key: 'late', label: view === 'run' ? `Fights ${n - 2}–${n}` : `Turns ${n - 2}–${n}`, align: 'right', sort: (k) => of(k).late, render: (k) => h('b', {}, fmtV(of(k).late)) },
		{ key: 'gain', label: 'Gain', align: 'right', title: 'Late less early, a turn', sort: (k) => of(k).gain, render: (k) => h('span', { class: of(k).gain >= 0 ? 'delta-up' : 'delta-down' }, signed(of(k).gain)) },
		{ key: 'curve', label: `Every ${unit}`, sort: false, render: (k) => sparkline(of(k).series.map((v) => Math.max(0, v)), { color: markColor(C.skill(k).color) }) },
		{ key: 'flag', label: '', sort: false, render: (k) => (of(k).gain >= 1 && of(k).ratio >= 1.5 ? h('span', { class: 'flag high', title: 'Worth at least half as much again late as early, and a point a turn more' }, 'keeps growing') : '') },
	];
	const sort = state.sort && state.sort.tab === 'growth' ? state.sort : { tab: 'growth', key: 'gain', dir: -1 };
	const top = h('div', { class: 'bal-split' });
	top.append(card(`${C.colorName(color)} gems · value a turn, ${view === 'run' ? 'fight by fight' : 'turn by turn'}`, table({ columns, rows: sortRows(inColor, columns, sort), sort, compact: true, sticky: false, selectedKey: state.gem, rowKey: (k) => k,
		onSort: (k) => { state.sort = { tab: 'growth', ...toggleSort(sort, k, k === 'name' ? 1 : -1) }; ctx.rerender(); }, onRowClick: (k) => { state.gem = k; ctx.rerender(); } }),
	{ pad: false, class: 'dense', meta: `${state.bowl === 'ALL' ? 'average of the six bowls' : `${bowlName(state.bowl)}’s bowl`} · each gem in its better place over ${res.hosts.length} hosts, against the host alone` }));
	top.append(card(null, h('div', { class: 'col', style: { gap: '6px' } },
		h('div', { class: 'section-title' }, `Gains the most ${view === 'run' ? 'over the run' : 'over the fight'}`), h('div', { class: 'bal-list' }, growers.slice(0, 8).map(listRow)),
		h('div', { class: 'section-title' }, 'Fades the most'), h('div', { class: 'bal-list' }, growers.slice(-4).reverse().map(listRow)))));
	body.append(top);

	const r = rows[state.gem][view];
	const med = Array.from({ length: n }, (_, i) => median(skills.map((k) => of(k) && of(k).series[i])));
	const series = [
		{ label: C.skill(state.gem).name, color: markColor(color), shape: SHAPES[color], points: r.series.map((y, i) => ({ x: i + 1, y })) },
		{ label: 'median gem', color: 'var(--muted)', points: med.map((y, i) => ({ x: i + 1, y: Number.isFinite(y) ? y : 0 })), dim: true },
	];
	const low = Math.min(0, ...r.series, ...med.filter(Number.isFinite));
	body.append(card(`${C.skill(state.gem).name} · ${view === 'run' ? 'value a turn in each fight of the run' : 'value in each turn of the long fight'}`, h('div', { class: 'col' },
		lines({ series, width: 1150, height: 220, min: low, format: fmtV, xFormat: (x) => `${view === 'run' ? 'fight' : 'turn'} ${x}` }),
		h('div', { class: 'stats', style: { gridTemplateColumns: 'repeat(4, minmax(0, 1fr))' } }, stat(view === 'run' ? 'Fight 1' : 'Turn 1', fmtV(r.early), 'a turn'), stat('Late', fmtV(r.late), `the last three ${unit}s`, { class: 'accent' }),
			stat('Gain', signed(r.gain), 'a turn'), stat('Late ÷ early', fmtTimes(r.ratio), ''))),
	{ meta: view === 'run' ? `${res.settings.turns}-turn ordinary fights; the dice, fire counts and health a gem grew are kept from one to the next, and the player starts each whole` : 'the boss fight, played on past the usual turns; creatures enrage from turn 7' }));
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
			h('div', { class: 'row' }, field('Boss health', numberInput(s.bossHp, setS('bossHp', 1, 1e7), { style: 'width:90px' }), 'The boss fight’s kill line for the sweeps played at one carat (the bands use each mine’s boss)'),
			field('Boss throws', h('span', { class: 'row tight' }, ...s.bossDice.map((d, i) => select(dieOptions, d, (v) => { const dice = s.bossDice.slice(); dice[i] = v; state.settings = { ...state.settings, bossDice: dice }; keep(); ctx.rerender(); }, { class: 'select small', style: 'width:70px' })))),
			field('Boss block', numberInput(s.bossGuard, setS('bossGuard', 0, 99), { style: 'width:70px' }))),
		h('div', { class: 'row' }, field('Host rails', segmented([[12, '12'], [24, '24'], [48, '48']], s.hosts, setS('hosts', 1, 200)), 'How many rails of four other gems the Opals sweep sets every gem into'),
			field('Carat and growth hosts', segmented([[4, '4'], [6, '6'], [12, '12']], s.caratHosts, setS('caratHosts', 1, 48)), 'How many of those rails the Carat bands and Growth sweeps use'),
			...Balance.SWEEPS.map((sw) => field(`${SWEEP_NAMES[sw]} · fights`, select([10, 15, 20, 30, 40, 60, 100, 150, 300, 1000, 3000].map((x) => [x, String(x)]), s.samples[sw],
			(v) => { state.settings = { ...state.settings, samples: { ...state.settings.samples, [sw]: Number(v) } }; keep(); ctx.rerender(); }, { style: 'width:90px' })))),
		h('div', { class: 'row' }, field('Hunted bands', h('span', { class: 'row tight' }, ...Balance.bands().map((b) => {
			const on = (s.huntBands || []).includes(b.key);
			return h('button', { type: 'button', class: `btn${on ? ' primary' : ''}`, title: b.name, onClick: () => { const now = new Set(s.huntBands || []); if (on) now.delete(b.key); else now.add(b.key); state.settings = { ...state.settings, huntBands: Balance.bands().map((x) => x.key).filter((k) => now.has(k)) }; keep(); ctx.rerender(); } }, `${b.carat}c`);
		})), 'The mines the hunt searches at; each one adds about a quarter to its time'),
			field('Starts', segmented([[1, '1'], [2, '2'], [3, '3']], s.huntStarts, setS('huntStarts', 1, 3)), 'Rails each search starts from: the bowl’s best gems alone, then a random rail, then a random rail ending in two opals'),
			field('Passes', segmented([[1, '1'], [2, '2'], [3, '3']], s.huntPasses, setS('huntPasses', 1, 5)), 'How many times a search may walk every socket'),
			field('Copies', segmented([[1, '1'], [2, '2'], [3, '3']], s.copies, setS('copies', 1, 7)), 'The most of one gem a hunted rail may hold'),
			field('Transcendent', segmented([[0, '0'], [1, '1'], [2, '2']], s.transcendent, setS('transcendent', 0, 7)), 'The most Transcendent gems a hunted rail may hold'),
			field('Checked over', select([150, 300, 600, 1000].map((x) => [x, `${x} fights`]), s.huntVerify, (v) => { state.settings = { ...state.settings, huntVerify: Number(v) }; keep(); ctx.rerender(); }, { style: 'width:110px' }), 'Fresh fights every rail the hunt found is played again on')),
		h('div', { class: 'row' }, field('A run', segmented([[6, '6 fights'], [12, '12'], [20, '20']], s.runFights, setS('runFights', 2, 60)), 'The Growth sweep’s run of ordinary fights'),
			field('The long fight', segmented([[8, '8 turns'], [10, '10'], [16, '16']], s.longTurns, setS('longTurns', 2, 40)), 'The Growth sweep’s boss fight, turn by turn')),
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
		h('p', {}, h('b', {}, 'Two fights. '), `Every rail is played twice. The ordinary fight is the dummies above: overkill is wasted, so no rail can show more damage than they have health. The boss fight is one dummy throwing ${s.bossDice.join(' and ').toLowerCase()} that never falls, with a kill line at ${fmt(s.bossHp, 0)} health: its damage is the pace the rail reaches that line at, read within the turn that crosses it, so nothing is capped and a rail that kills on the first turn shows all it did. The toggle by the exchange rates picks the fight every tab reads.`),
		h('p', {}, h('b', {}, 'Carat bands. '), 'Each mine at its boss: the cap of its carat band there, its creatures’ health and blows against the Quarry’s, its boss’s health as the kill line. The Rift is read three Wardens down and seven, where its band reaches 24 carats. A gem’s value at a band is read as a share of what its host rail does alone there.'),
		h('p', {}, h('b', {}, 'The hunt. '), 'For every bowl and hunted band, searches start from a few rails and walk them a socket at a time, keeping the best gem or swap in the boss fight on the same seeded fights. What they end on is played again on fresh fights beside the bowl’s best gems alone (the plain rail) and a dozen random rails. node tools/data-browser/balance.mjs check is the gate: it flags a band whose strongest rail beats its bowl’s plain rail more than four times over.'),
		h('p', {}, h('b', {}, 'Growth. '), 'A run plays the ordinary fight again and again, keeping the dice (Glimmer, Gilding, Hydrophane), how often each gem has fired (Hone, Hardening) and the health the rail grew (Heartwood). The long fight is the boss fight played on, turn by turn.'),
		h('p', {}, h('b', {}, 'Runaways. '), `The game spends a rail once it has played ${Balance.RAIL_CAP} gems in a turn (sim/battle.gd RAIL_CAP): what is still queued for it is dropped and the turn goes on. Here such a rail is a runaway: played no further, flagged wherever it shows, and the hunt walks around it. Every count in a fight also stops at a ceiling of a thousand million million, which the game shows as Infinite.`),
		h('p', {}, h('b', {}, 'The bowls. '), 'Each of the six lapidaries rolls their own starting dice with their passive (Cadence’s extra reroll, Puck’s parity shift, Ardor’s Second Wind…) and Birthstone. Rerolls chase the trigger of the gem that does most alone; a pair chases its stronger half’s.'),
		h('p', {}, h('b', {}, 'Fair comparisons. '), 'Every rail on a bowl plays the same seeded fights: each die has its own stream of throws, so two rails that make the same choices see the same dice. Values are means; with a few hundred fights a value moves by a few tenths between runs.'),
		h('p', {}, h('b', {}, 'Contexts. '), 'Gems, cuts and clarities are judged alone; a Feather inclusion beside a bare copy of its own gem; a pair in its better order. The Opals tab sets every gem into rails of four other gems (an opal in its best place, anything else first or last) and measures what changes against the same rail without it.'),
		h('p', {}, h('b', {}, 'Known gaps. '), 'Economy (Prospect’s Sparkle, Appraise’s haul, quality bonuses) is not combat and reads as nothing here. Sockets are all Any, so Zoning and Alexandrite only show through Harmony. Every band rolls the lapidary’s starting dice, though a deeper player carries bigger ones. A run starts every fight whole and with the same pyrite. A Black Opal has no bag to feed on, so the hunt leaves it out.'))));
}
