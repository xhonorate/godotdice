// Skill gems: a filterable list, and for the chosen skill its odds by Cut against the bowl,
// its rules with the numbers filled in, its carat curve, and how its stone looks.

import * as C from '../sim/content.js';
import * as Patterns from '../sim/patterns.js';
import * as Rules from '../sim/rules.js';
import * as Stone from '../sim/stone.js';
import { h, card, stat, table, fmt, fmtPct, segmented, field, toolbar, note, stepper, numberInput, select, chip, kv, sortRows, toggleSort } from '../ui.js';
import { columns, lines, histogram, heatmap, ladderCells, SHAPES } from '../charts.js';
import { gemImage, matrixImage, caratImage, markColor, colorKeyMark, CUTS, SHAPE_NAMES } from '../gemart.js';
import { bowlControls, cutNames, clarityNames, whenReady, rarityChip, colorChip, CUT_COLORS, CLARITY_COLORS, tabs, colorOf } from './common.js';

const state = { search: '', colors: new Set(), rarity: '', sort: { key: 'name', dir: 1 }, cut: 2, clarity: null, carat: 8, inclusions: [], tab: 'odds', mode: 'detail',
	context: { resonance: 3, pyrite: 60, block: 8, block_lost: 6, healed: 6, enemy_poison: 6 } };

const CONTEXT_FIELDS = [['resonance', 'Resonance', 'Read by Seams and Resonance triggers'], ['pyrite', 'Pyrite', 'Wager and Stake spend it'], ['block', 'Block', 'Mortar, Thrive, Gilded Armor read it'],
	['block_lost', 'Block lost', 'Riposte reads it'], ['healed', 'Healed this turn', 'Sap reads it'], ['enemy_poison', 'Enemy poison', 'Siphon and Detonate read it']];

function filtered() {
	const q = state.search.trim().toLowerCase();
	return C.keys('skills').filter((k) => {
		const d = C.skill(k);
		if (state.colors.size && !state.colors.has(d.color)) return false;
		if (state.rarity && d.rarity !== state.rarity) return false;
		if (q && !(`${d.name} ${k} ${d.text} ${(d.tags || []).join(' ')} ${d.trigger.kind}`.toLowerCase().includes(q))) return false;
		return true;
	});
}

export default {
	id: 'skills', label: 'Skill gems', blurb: 'Every skill, its ladder and its odds', count: () => C.keys('skills').length,
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3 21 10l-3.5 11h-11L3 10Z"/><path d="M3 10h18M12 3v18"/></svg>',
	render(root, route, ctx) {
		if (state.clarity === null) state.clarity = C.clearIndex();
		if (route.params.tab) state.tab = route.params.tab;
		if (route.params.mode) state.mode = route.params.mode;
		const keys = filtered();
		let key = route.key && C.skill(route.key).name ? route.key : keys[0] || C.keys('skills')[0];
		const allKeys = C.keys('skills');
		const params = { bowl: ctx.settings.bowl, rerolls: ctx.settings.rerolls, samples: ctx.settings.samples, skills: allKeys, stone: { carat: state.carat, clarity: state.clarity, inclusions: state.inclusions }, context: state.context };
		const promise = ctx.engine.run('skillStats', params);

		root.append(toolbar(...bowlControls(ctx, { showSamples: true }), field('View', segmented([['detail', 'One skill'], ['compare', 'Compare table']], state.mode, (v) => { state.mode = v; ctx.rerender(); }))));
		if (state.mode === 'compare') { root.append(compareTable(ctx, keys, promise, key)); return; }

		const grid = h('div', { class: 'grid grid-side' });
		root.append(grid);
		grid.append(listPanel(ctx, keys, key, promise));
		grid.append(detail(ctx, key, promise));
	},
};

function listPanel(ctx, keys, active, promise) {
	const panel = h('section', { class: 'card list-panel', style: { maxHeight: 'calc(100vh - 190px)' } });
	const search = h('input', { class: 'search', type: 'search', placeholder: 'Search skills…', value: state.search, onInput: (e) => { state.search = e.target.value; refresh(); } });
	const colorRow = h('div', { class: 'row tight' }, C.SKILL_COLORS.map((ck) => h('button', { type: 'button', class: `btn${state.colors.has(ck) ? ' is-active' : ''}`, title: C.colorName(ck), style: { padding: '0 7px' },
		onClick: () => { if (state.colors.has(ck)) state.colors.delete(ck); else state.colors.add(ck); ctx.rerender(); } }, colorKeyMark(ck, 14))));
	const raritySel = select([['', 'Any rarity'], ...C.RARITIES.map((r) => [r, C.title(r)])], state.rarity, (v) => { state.rarity = v; ctx.rerender(); });
	const sortSel = select([['name', 'Name'], ['fire', `Fire rate at ${cutNames()[state.cut]}`], ['ev', `Effect / turn at ${cutNames()[state.cut]}`], ['rarity', 'Rarity']], state.sort.key, (v) => { state.sort = { key: v, dir: v === 'name' ? 1 : -1 }; ctx.rerender(); });
	panel.append(h('div', { class: 'list-tools' }, search, h('div', { class: 'row between' }, colorRow, raritySel), sortSel));
	const list = h('div', { class: 'list' });
	panel.append(list, h('div', { class: 'list-count' }, `${keys.length} of ${C.keys('skills').length} skills`));
	let stats = ctx.engine.cached('skillStats', { bowl: ctx.settings.bowl, rerolls: ctx.settings.rerolls, samples: ctx.settings.samples, skills: C.keys('skills'), stone: { carat: state.carat, clarity: state.clarity, inclusions: state.inclusions }, context: state.context });
	const draw = () => {
		list.replaceChildren();
		let rows = filtered().map((k) => { const d = C.skill(k); const s = stats && stats.skills[k] ? stats.skills[k].cuts[state.cut] : null; return { key: k, name: d.name, color: d.color, rarity: d.rarity, fire: s ? s.fireRate : -1, ev: s ? s.ev : -1, headline: stats && stats.skills[k] ? stats.skills[k].headline : '' }; });
		const dir = state.sort.dir;
		rows.sort((a, b) => state.sort.key === 'name' ? a.name.localeCompare(b.name) * dir : state.sort.key === 'rarity' ? (C.RARITIES.indexOf(a.rarity) - C.RARITIES.indexOf(b.rarity)) * dir || a.name.localeCompare(b.name) : (a[state.sort.key] - b[state.sort.key]) * dir);
		for (const r of rows) {
			list.append(h('button', { type: 'button', class: `list-item${r.key === active ? ' is-active' : ''}`, onClick: () => ctx.navigate('skills', r.key) },
				gemImage(r.key, 38), h('span', {}, h('span', { class: 'li-name' }, r.name), h('span', { class: 'li-sub' }, `${C.colorName(r.color)} · ${C.title(r.rarity)} · ${Patterns.KIND_NAMES[C.skill(r.key).trigger.kind] || ''}`)),
				h('span', { class: 'li-right' }, r.fire >= 0 ? [fmtPct(r.fire), h('span', { class: 'cell-sub' }, `${fmt(r.ev, 1)} ${r.headline.replace(/_/g, ' ')}`)] : '…')));
		}
		const activeEl = list.querySelector('.is-active');
		if (activeEl) activeEl.scrollIntoView({ block: 'nearest' });
	};
	const refresh = () => { draw(); panel.querySelector('.list-count').textContent = `${filtered().length} of ${C.keys('skills').length} skills`; };
	draw();
	promise.then((result) => { if (!ctx.alive()) return; stats = result; draw(); });
	return panel;
}

function currentStone(key) { return Stone.make(key, state.carat, state.cut, state.clarity, state.inclusions); }

function detail(ctx, key, promise) {
	const def = C.skill(key);
	const wrap = h('div', { class: 'col' });
	const stone = currentStone(key);
	const eff = Stone.effective(stone);
	const trigger = def.trigger || { kind: 'always' };
	const head = h('div', { class: 'card' }, h('div', { class: 'card-body' }, h('div', { class: 'detail-head' },
		h('span', { class: 'pic hero' }, gemImage(key, 150)),
		h('div', { class: 'detail-title' },
			h('div', { class: 'row tight' }, colorChip(def.color), rarityChip(def.rarity), chip(Patterns.KIND_NAMES[trigger.kind] || trigger.kind, { title: 'Trigger kind' }), ...(def.tags || []).map((t) => chip(C.title(t))), chip(`${SHAPE_NAMES[CUTS[def.color]] || ''} cut`)),
			h('h2', {}, def.name),
			h('p', { class: 'lede' }, Stone.text(stone)),
			def.flawless && def.flawless.text ? h('p', { class: 'small text-2' }, h('b', { style: { color: CLARITY_COLORS[5] } }, 'Flawless: '), Stone.flawlessText(stone)) : null,
			h('p', { class: 'small muted' }, `Trigger at ${cutNames()[eff.cut_step]}: ${Patterns.words(trigger, eff.cut_step)}`)))));
	wrap.append(head);

	// The stone under the loupe: its Cut, Clarity, carat and what is frozen inside it.
	const inclusionOptions = [['', '+ inclusion…'], ...C.keys('inclusions').filter((k) => !state.inclusions.includes(k)).map((k) => [k, `${C.inclusion(k).name} (${C.title(C.inclusion(k).class)})`])];
	wrap.append(toolbar(
		field('Cut', stepper(cutNames(), state.cut, (i) => { state.cut = i; ctx.rerender(); }, CUT_COLORS)),
		field('Clarity', stepper(clarityNames(), state.clarity, (i) => { state.clarity = i; ctx.rerender(); }, CLARITY_COLORS)),
		field('Carat', h('span', { class: 'row tight' }, numberInput(state.carat, (v) => { state.carat = Math.max(1, Math.min(Stone.caratMax(), v || 1)); ctx.rerender(); }, { min: 1, max: Stone.caratMax() }), h('span', { class: 'small muted' }, `×${fmt(eff.magnitude, 2)} magnitude`))),
		field('Inclusions', h('span', { class: 'row tight' }, state.inclusions.map((k) => h('button', { type: 'button', class: 'chip', title: 'Remove', onClick: () => { state.inclusions = state.inclusions.filter((x) => x !== k); ctx.rerender(); } }, `${C.inclusion(k).name} ×`)),
			state.inclusions.length < 3 ? select(inclusionOptions, '', (v) => { if (v) { state.inclusions = [...state.inclusions, v]; ctx.rerender(); } }, { style: 'width:150px' }) : null)),
		h('span', { class: 'fill' }),
		field('Section', tabs([['odds', 'Odds'], ['rules', 'Rules & carat'], ['look', 'Look'], ['context', 'Rail context']], state.tab, (t) => { state.tab = t; ctx.rerender(); }))));

	if (state.tab === 'odds') wrap.append(oddsSection(ctx, key, stone, promise));
	if (state.tab === 'rules') wrap.append(rulesSection(ctx, key, stone));
	if (state.tab === 'look') wrap.append(lookSection(ctx, key, stone));
	if (state.tab === 'context') wrap.append(contextSection(ctx));
	return wrap;
}

function oddsSection(ctx, key, stone, promise) {
	const def = C.skill(key);
	const wrap = h('div', { class: 'col' });
	const statsRow = h('div', { class: 'stats' });
	wrap.append(statsRow);
	const grid = h('div', { class: 'grid grid-2' });
	wrap.append(grid);
	const fireSlot = h('div'), evSlot = h('div'), histSlot = h('div'), ladderSlot = h('div');
	grid.append(card('Fire rate by Cut', fireSlot, { meta: 'share of hands the stone fires on' }), card('Expected effect by Cut', evSlot, { meta: 'headline effect per turn, fires × amount' }));
	wrap.append(h('div', { class: 'grid grid-2' }, card(`What it does when it fires · ${cutNames()[state.cut]}`, histSlot, { meta: 'distribution of the headline amount' }), card('The ladder', ladderSlot, { meta: 'what each rung asks of the hand' })));
	const eff = Stone.effective(stone);
	const procs = Stone.procs(stone);
	whenReady(ctx, statsRow, promise, (result) => {
		const s = result.skills[key];
		if (!s) return null;
		const c = s.cuts[state.cut];
		const g = Stone.grade(stone);
		const items = [stat('Fires on', fmtPct(c.fireRate), `${cutNames()[state.cut]} cut, ${result.rerolls} rerolls`, { class: 'accent' }), stat(`${C.title(s.headline).toLowerCase()} / turn`, fmt(c.ev, 1), 'expected, fizzles included'),
			stat('when it fires', fmt(c.evFired, 1), `mean ${s.headline.replace(/_/g, ' ')}`), stat('Magnitude', `×${fmt(eff.magnitude, 2)}`, Stone.magnitudeMatters(stone) ? 'scales its amounts' : Stone.procsMatter(stone) ? `${procs.procs}× certain, ${procs.chance}% one more` : 'no scaled effect'),
			stat('Resonance', fmt(c.resonance, 2), 'added to the rail per turn'), stat('Grade', `${g.score} ${g.name}`, `sells for ${Stone.value(stone)} gold`)];
		return h('div', { class: 'stats', style: { display: 'contents' } }, items);
	});
	whenReady(ctx, fireSlot, promise, (result) => {
		const s = result.skills[key];
		return columns({ data: s.cuts.map((c, i) => ({ label: cutNames()[i], value: c.fireRate * 100, color: CUT_COLORS[i], key: i, note: 'of hands' })), width: 420, height: 190, format: (v) => `${fmt(v, 0)}%`, max: 100, valueLabels: 'all', selected: state.cut, onSelect: (d) => { state.cut = d.key; ctx.rerender(); } });
	});
	whenReady(ctx, evSlot, promise, (result) => {
		const s = result.skills[key];
		const kinds = [...new Set(s.cuts.flatMap((c) => Object.keys(c.kinds)))];
		const series = kinds.map((kind, i) => ({ key: kind, label: kind.replace(/_/g, ' '), color: kind === s.headline ? colorOf(key) : ['#8a93a3', '#b4bcc8', '#6f7683', '#5a6270'][i % 4], shape: kind === s.headline ? SHAPES[def.color] : 'circle', points: s.cuts.map((c, x) => ({ x, y: c.kinds[kind] || 0 })) }));
		if (!series.length) return note('This skill has no numeric effect to add up; see its fire rate.', 'plain');
		return lines({ series, width: 420, height: 190, xLabels: cutNames(), format: (v) => fmt(v, 1), endLabels: false });
	});
	whenReady(ctx, histSlot, promise, (result) => {
		const s = result.skills[key];
		const c = s.cuts[state.cut];
		if (!c.hist.length) return note('Never fired in the sample at this cut.', 'plain');
		const fired = c.fireRate || 1;
		const bins = c.hist.map(([v, p]) => [v, p / fired]);
		return histogram({ bins, width: 420, height: 170, color: colorOf(key), mean: c.evFired, xLabel: s.headline.replace(/_/g, ' '), format: (v) => `${(v * 100).toFixed(1)}%`, minBins: 4 });
	});
	whenReady(ctx, ladderSlot, promise, (result) => {
		const s = result.skills[key];
		const trigger = def.trigger || {};
		const rows = cutNames().map((name, i) => ({ key: i, cut: name, rung: Patterns.label(trigger, i), words: Patterns.words(trigger, i), fire: s.cuts[i].fireRate, ev: s.cuts[i].ev, text: Rules.fill(def.text || '', def.numbers || {}, i) }));
		return table({ columns: [
			{ key: 'cut', label: 'Cut', render: (r) => h('span', { class: 'row tight' }, h('i', { class: 'dot', style: { background: CUT_COLORS[r.key] } }), r.cut) },
			{ key: 'rung', label: 'Rung', render: (r) => h('span', { class: 'mono' }, r.rung) },
			{ key: 'words', label: 'Asks for', render: (r) => h('span', { class: 'small text-2' }, r.words, Object.keys(def.numbers || {}).length ? h('span', { class: 'cell-sub' }, r.text) : null) },
			{ key: 'fire', label: 'Fires', align: 'right', render: (r) => fmtPct(r.fire) },
			{ key: 'ev', label: '/ turn', align: 'right', render: (r) => fmt(r.ev, 1) },
		], rows, compact: true, selectedKey: state.cut, rowKey: (r) => r.key, onRowClick: (r) => { state.cut = r.key; ctx.rerender(); } });
	});
	return wrap;
}

function rulesSection(ctx, key, stone) {
	const def = C.skill(key);
	const eff = Stone.effective(stone);
	const wrap = h('div', { class: 'grid grid-2' });
	const cutStep = eff.cut_step;
	let defs = (def.effects || []).map((d) => JSON.parse(JSON.stringify(d)));
	if (eff.flawless && def.flawless) defs = Stone.applyFlawless(defs, def.flawless);
	const effects = h('div', { class: 'effect-list' }, defs.map((e) => {
		const scale = e.scale ?? (Rules.SCALED_BY_DEFAULT.includes(e.kind) ? 'carat' : 'none');
		const procs = scale === 'carat' || 'scale' in e ? null : Rules.caratProcs(eff.magnitude);
		return h('div', { class: 'effect' }, h('span', {}, h('span', { class: 'eff-kind' }, Rules.effectWords(e, cutStep)), h('span', { class: 'eff-sub' }, `target ${(e.target || Rules.defaultTarget(e.kind)).replace(/_/g, ' ')} · amount ${Rules.amountWords(e.amount ?? 0)}${e.repeat !== undefined ? ` · repeat ${Rules.amountWords(e.repeat)}` : ''}${Object.keys(e).filter((k) => !['kind', 'target', 'amount', 'repeat', 'scale'].includes(k)).map((k) => ` · ${k} ${JSON.stringify(e[k])}`).join('')}`)),
			h('span', { class: 'eff-val' }, scale === 'carat' ? h('span', {}, `×${fmt(eff.magnitude, 2)}`, h('span', { class: 'cell-sub' }, 'scaled by carat')) : procs ? h('span', {}, `${procs.procs}×`, h('span', { class: 'cell-sub' }, procs.chance ? `+${procs.chance}% one more` : 'whole number')) : h('span', {}, 'flat', h('span', { class: 'cell-sub' }, 'written flat'))));
	}));
	const numbers = Object.entries(def.numbers || {});
	wrap.append(card('Effects at this stone', h('div', { class: 'col' }, effects,
		numbers.length ? h('div', {}, h('div', { class: 'section-title' }, 'Numbers written into the card'), h('div', { class: 'col' }, numbers.map(([name, expr]) => h('div', { class: 'row' }, h('code', {}, `{${name}}`), expr.ladder ? ladderCells(expr.ladder) : h('span', {}, Rules.amountWords(expr)))))) : null,
		h('div', {}, h('div', { class: 'section-title' }, 'Trigger ladder'), h('div', { class: 'row' }, def.trigger.ladder ? ladderCells(def.trigger.ladder, { better: ['pair', 'triple', 'quad', 'quint', 'two_pair', 'full_house', 'straight', 'odd', 'even', 'distinct', 'value', 'at_least', 'total_pct_at_least', 'high_pct_at_least', 'held', 'rerolled', 'resonance', 'low_count', 'crowns', 'pyrite'].includes(def.trigger.kind) ? 'low' : 'high' }) : h('span', { class: 'muted' }, 'no ladder'), def.trigger.read ? h('span', { class: 'small muted' }, `reads ${Array.isArray(def.trigger.read) ? def.trigger.read.join(' → ') : def.trigger.read}`) : null)),
		def.flawless ? h('div', {}, h('div', { class: 'section-title' }, 'Flawless line'), h('p', { class: 'small text-2' }, Rules.fill(def.flawless.text || '', def.numbers || {}, cutStep)), def.flawless.modify ? h('p', { class: 'tiny muted' }, `modifies: ${JSON.stringify(def.flawless.modify)}`) : null, def.flawless.effects ? h('p', { class: 'tiny muted' }, `adds: ${def.flawless.effects.map((e) => Rules.effectWords(e, cutStep)).join(' · ')}`) : null) : null,
		note(`Magnitude ×${fmt(eff.magnitude, 2)} = carat curve ${fmt(Stone.caratMultiplier(eff.carat), 2)} × clarity ${fmt(Number(C.clarityEntry(eff.clarity).magnitude ?? 1), 2)}${eff.modifiers.some((m) => m.kind === 'magnitude') ? ' × inclusions' : ''}. Effective carat ${eff.carat}, cut step ${eff.cut_step}${eff.modifiers.length ? `, inclusions: ${eff.modifiers.map((m) => `${C.inclusion(m.inclusion).name} (${m.kind})`).join(', ')}` : ''}.`, 'plain'))));

	const caratPoints = Array.from({ length: Stone.caratMax() }, (_, i) => ({ x: i + 1, y: Stone.caratMultiplier(i + 1) }));
	const procPoints = caratPoints.map((p) => ({ x: p.x, y: Rules.caratProcs(p.y).procs + Rules.caratProcs(p.y).chance / 100 }));
	wrap.append(card('The carat curve', h('div', { class: 'col' },
		lines({ series: [{ key: 'm', label: 'magnitude ×', color: '#f0c95a', points: caratPoints }, { key: 'p', label: 'expected goes (whole-number effects)', color: '#6f9fe0', shape: 'square', points: procPoints }], width: 460, height: 210, format: (v) => `×${fmt(v, 1)}`, xFormat: (v) => `${v}ct`, endLabels: false, markers: false }),
		h('div', { class: 'stats' }, [1, 8, 13, 19, 20, 24].map((ct) => { const m = Stone.caratMultiplier(ct); const p = Rules.caratProcs(m); return stat(`${ct} ct`, `×${fmt(m, 2)}`, `${p.procs}× certain${p.chance ? ` +${p.chance}%` : ''}`, { class: ct === state.carat ? 'accent' : '' }); })),
		note('1× at one carat, +0.25× a carat to 19, then +1× a carat from 20: the biggest stones spike. An effect that cannot be a fraction happens more often instead: (magnitude − 1) ÷ 3 extra goes, the remainder a chance of one more.', 'plain'))));
	return wrap;
}

function lookSection(ctx, key, stone) {
	const def = C.skill(key);
	const colorKey = def.color;
	const wrap = h('div', { class: 'col' });
	const cutN = cutNames(), clarN = clarityNames();
	const matrix = h('div', { class: 'matrix', style: { gridTemplateColumns: `100px repeat(${cutN.length}, minmax(0, 1fr))` } });
	matrix.append(h('div'));
	for (const c of cutN) matrix.append(h('div', { class: 'mx-head' }, c));
	clarN.forEach((name, k) => {
		matrix.append(h('div', { class: 'mx-row' }, h('i', { class: 'dot', style: { background: CLARITY_COLORS[k], marginRight: '6px' } }), name));
		cutN.forEach((_, c) => {
			const cell = h('button', { type: 'button', class: `gem-tile${c === state.cut && k === state.clarity ? ' is-active' : ''}`, style: { padding: '2px' }, title: `${cutN[c]} ${name}`, onClick: () => { state.cut = c; state.clarity = k; ctx.rerender(); } }, matrixImage(colorKey, c, k, 92));
			matrix.append(cell);
		});
	});
	wrap.append(card(`How a ${C.colorName(colorKey).toLowerCase()} stone looks · Cut across, Clarity down`, matrix, { meta: 'eight-carat stone of this colour; a Poor cut is squat and chipped, an included grade carries its flaws, a Flawless one is glass · click a cell to judge the skill as that stone' }));
	wrap.append(h('div', { class: 'grid grid-2' },
		card('Carat', h('div', { class: 'row', style: { alignItems: 'flex-end', justifyContent: 'space-around' } }, [1, 4, 8, 12, 16, 20, 24].map((ct) => h('div', { class: 'col', style: { alignItems: 'center', gap: '2px' } }, caratImage(colorKey, ct, 64), h('span', { class: 'tiny muted' }, `${ct}ct`)))), { meta: 'drawn in one frame; past about 19 carats a stone spills over its socket' }),
		card('This stone', h('div', { class: 'row' }, gemImage(key, 96), kv([['Name', Stone.name(stone)], ['Shape', SHAPE_NAMES[CUTS[colorKey]]], ['Body hue', h('span', { class: 'row tight' }, h('i', { class: 'dot', style: { background: `#${def.hue || C.color(colorKey).hue}` } }), `#${def.hue || C.color(colorKey).hue}`)], ['Grade', `${Stone.grade(stone).score} · ${Stone.grade(stone).name}`], ['Worth', `${Stone.value(stone)} gold appraised · ${Stone.roughValue(stone)} rough`]])))));
	return wrap;
}

function contextSection(ctx) {
	const wrap = h('div', { class: 'grid grid-2' });
	wrap.append(card('Rail context the sample assumes', h('div', { class: 'col' },
		h('div', { class: 'row' }, CONTEXT_FIELDS.map(([k, label, hint]) => field(label, numberInput(state.context[k], (v) => { state.context = { ...state.context, [k]: Math.max(0, v || 0) }; ctx.rerender(); }, { min: 0 }), hint))),
		note('Skills that read the rail rather than the hand (Resonance triggers, Riposte, Wager, Siphon, Thrive…) take these numbers as given every turn. Set them to what a mid-fight rail plausibly has.', 'plain'))));
	wrap.append(card('How the sample is made', h('div', { class: 'col small text-2' },
		h('p', {}, 'Each estimate rolls the bowl, then spends the rerolls chasing the skill’s own trigger: a pair skill keeps its best set and throws the rest, a straight skill keeps its run, a parity skill keeps its parity, a low-die skill keeps low dice, and so on. Held dice count as held, rerolled dice as rerolled.'),
		h('p', {}, 'Every skill is judged as the same stone (the carat, clarity and inclusions above) so its rungs and rivals are comparable. Fire rate is the share of hands on which the stone fires; expected effect multiplies each fire by its resolved amounts, with the carat multiplier on scaled kinds and the proc curve on whole-number kinds, and sums across a turn (a Chatoyance stone fires twice).'),
		h('p', {}, 'Samples are seeded, so the same settings always give the same numbers. Raise the hand count for tighter estimates on rare triggers.'))));
	return wrap;
}

function compareTable(ctx, keys, promise, active) {
	const slot = h('div');
	whenReady(ctx, slot, promise, (result) => {
		const cutN = cutNames();
		const rows = keys.map((k) => { const d = C.skill(k); const s = result.skills[k]; return { key: k, name: d.name, color: d.color, rarity: d.rarity, kind: d.trigger.kind, headline: s ? s.headline : '', fire: s ? s.cuts.map((c) => c.fireRate) : [], ev: s ? s.cuts.map((c) => c.ev) : [], text: d.text }; });
		const colsDef = [
			{ key: 'name', label: 'Skill', sort: (r) => r.name, render: (r) => h('span', { class: 'cell-name' }, gemImage(r.key, 30), h('span', {}, h('b', {}, r.name), h('span', { class: 'cell-sub' }, `${C.colorName(r.color)} · ${C.title(r.rarity)}`))) },
			{ key: 'kind', label: 'Trigger', sort: (r) => r.kind, render: (r) => h('span', { class: 'small text-2' }, Patterns.KIND_NAMES[r.kind] || r.kind) },
			{ key: 'headline', label: 'Effect', sort: (r) => r.headline, render: (r) => h('span', { class: 'small text-2' }, r.headline.replace(/_/g, ' ')) },
			...cutN.map((name, i) => ({ key: `f${i}`, label: `${name} fires`, align: 'right', sort: (r) => r.fire[i] ?? -1, render: (r) => h('span', { class: 'ladder-cell', style: { background: heatCell(r.fire[i] ?? 0), minWidth: '44px', color: (r.fire[i] ?? 0) > 0.6 ? '#141414' : 'var(--text)' } }, r.fire.length ? fmtPct(r.fire[i]) : '—') })),
			...cutN.map((name, i) => ({ key: `e${i}`, label: `${name} / turn`, align: 'right', sort: (r) => r.ev[i] ?? -1, render: (r) => h('span', { class: 'mono' }, r.ev.length ? fmt(r.ev[i], 1) : '—') })),
		];
		const sorted = sortRows(rows, colsDef, state.compareSort || { key: 'name', dir: 1 });
		return h('div', { class: 'card' }, h('div', { class: 'table-wrap', style: { maxHeight: 'calc(100vh - 210px)' } }, table({ columns: colsDef, rows: sorted, sort: state.compareSort || { key: 'name', dir: 1 }, onSort: (k) => { state.compareSort = toggleSort(state.compareSort, k, k === 'name' ? 1 : -1); ctx.rerender(); }, selectedKey: active, rowKey: (r) => r.key, onRowClick: (r) => { state.mode = 'detail'; ctx.navigate('skills', r.key); }, compact: true })));
	}, { min: 200 });
	return slot;
}

function heatCell(t) {
	const a = [33, 38, 47], b = [240, 201, 90];
	const mix = (i) => Math.round(a[i] + (b[i] - a[i]) * Math.pow(t, 0.85));
	return `rgb(${mix(0)},${mix(1)},${mix(2)})`;
}
