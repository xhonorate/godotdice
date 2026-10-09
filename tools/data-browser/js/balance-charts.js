// The Balance page's charts, in the same hand as charts.js: a range strip (a dot at each
// item's average, a whisker from its worst to its best), a dense pair matrix, columns of dots,
// and a diverging scale for signed values. Hairline grid, text in ink tokens, a tooltip on
// every mark, identity carried by the gem colour's own shape as well as its hue.

import { h, showTip, hideTip, tipRow, tipTitle, fmt } from './ui.js';
import { svg, mark, frame, INK, FONT } from './charts.js';

// Ticks for a range that may run below zero: a nice step, zero always on it.
function rangeTicks(lo, hi, count = 4) {
	lo = Math.min(0, lo);
	// Nothing to scale (a band of zeros): a unit range, so the axis still reads.
	hi = hi - lo < 1e-6 ? lo + 1 : hi;
	const rough = (hi - lo) / count;
	const mag = Math.pow(10, Math.floor(Math.log10(rough)));
	const norm = rough / mag;
	const step = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5 : 10) * mag;
	const ticks = [];
	for (let v = Math.floor(lo / step) * step; v <= hi + step * 0.999; v += step) ticks.push(Number(v.toFixed(10)));
	return ticks;
}

function yAxis(g, f, ticks, py, format, yLabel) {
	for (const t of ticks) {
		g.append(svg('line', { x1: f.x0, x2: f.x0 + f.w, y1: py(t), y2: py(t), stroke: t === 0 ? INK.axis : INK.grid, 'stroke-width': 1 }));
		g.append(svg('text', { x: f.x0 - 6, y: py(t) + 3.5, 'text-anchor': 'end', fill: INK.muted, 'font-size': FONT, text: format(t) }));
	}
	if (yLabel) g.append(svg('text', { x: f.x0 + 4, y: f.y0 - 3, fill: INK.text, 'font-size': FONT, text: yLabel }));
}

// Two poles and a neutral middle for signed values: amber above zero, slate below. `t` in -1..1.
export function diverge(t) {
	const mid = [39, 45, 55], up = [240, 201, 90], down = [111, 143, 224];
	const end = t >= 0 ? up : down;
	const k = Math.pow(Math.min(1, Math.abs(t)), 0.8);
	return `rgb(${[0, 1, 2].map((i) => Math.round(mid[i] + (end[i] - mid[i]) * k)).join(',')})`;
}

// Items grouped into bands (a gem colour each), drawn in the order given: a dot at the
// average, a whisker from worst to best with a tick at the best, the band's median as a
// hairline. groups: [{key, label, color, shape, items: [{key, label, min, avg, best, note}]}].
// `independent` gives every band its own scale (small multiples), so a band is read against
// itself rather than against the loudest item on the chart.
export function rangeStrip({ groups, width = 1000, height = 300, format = (v) => fmt(v, 1), onSelect = null, selected = null, yLabel = '', independent = false }) {
	const pad = { l: independent ? 6 : 48, r: 10, t: 16, b: 30 };
	const f = frame(width, height, pad);
	const g = svg('g');
	const all = groups.flatMap((gr) => gr.items);
	const scaleOf = (items) => {
		const lows = items.map((it) => (Number.isFinite(it.min) ? it.min : it.avg)).filter(Number.isFinite);
		const highs = items.map((it) => (Number.isFinite(it.best) ? it.best : it.avg)).filter(Number.isFinite);
		const ticks = rangeTicks(Math.min(0, ...lows), Math.max(1e-9, ...highs), independent ? 3 : 4);
		const lo = ticks[0], hi = ticks[ticks.length - 1];
		return { ticks, py: (v) => f.y0 + f.hh - ((v - lo) / (hi - lo || 1)) * f.hh };
	};
	const shared = independent ? null : scaleOf(all);
	if (shared) yAxis(g, f, shared.ticks, shared.py, format, yLabel);
	else if (yLabel) g.append(svg('text', { x: f.x0, y: f.y0 - 4, fill: INK.text, 'font-size': FONT, text: yLabel }));
	const gap = 14;
	const axisW = independent ? 30 : 0;
	const unit = (f.w - gap * Math.max(0, groups.length - 1) - axisW * groups.length) / Math.max(1, all.length);
	const hits = svg('g');
	const labels = svg('g');
	let x = f.x0;
	for (const group of groups) {
		x += axisW;
		const bandW = unit * group.items.length;
		const { ticks, py } = shared || scaleOf(group.items);
		if (!shared) {
			for (const t of ticks) {
				g.append(svg('line', { x1: x, x2: x + bandW, y1: py(t), y2: py(t), stroke: t === 0 ? INK.axis : INK.grid, 'stroke-width': 1 }));
				g.append(svg('text', { x: x - 4, y: py(t) + 3.5, 'text-anchor': 'end', fill: INK.muted, 'font-size': 10, text: format(t) }));
			}
		}
		const avgs = group.items.map((it) => it.avg).filter(Number.isFinite).sort((a, b) => a - b);
		if (avgs.length) {
			const n = avgs.length;
			const median = n % 2 ? avgs[(n - 1) / 2] : (avgs[n / 2 - 1] + avgs[n / 2]) / 2;
			g.append(svg('line', { x1: x, x2: x + bandW, y1: py(median), y2: py(median), stroke: INK.muted, 'stroke-width': 1, opacity: 0.9 }));
		}
		g.append(svg('rect', { x, y: f.y0 + f.hh + 4, width: Math.max(1, bandW), height: 3, rx: 1.5, fill: group.color, opacity: 0.85 }));
		g.append(svg('text', { x: x + bandW / 2, y: f.y0 + f.hh + 20, 'text-anchor': 'middle', fill: INK.text, 'font-size': FONT, text: group.label }));
		group.items.forEach((it, i) => {
			const cx = x + unit * i + unit / 2;
			const isSel = selected !== null && it.key === selected;
			const dim = selected !== null && !isSel ? 0.6 : 1;
			if (Number.isFinite(it.min) && Number.isFinite(it.best)) {
				g.append(svg('line', { x1: cx, x2: cx, y1: py(it.min), y2: py(it.best), stroke: group.color, 'stroke-width': 2, 'stroke-linecap': 'round', opacity: 0.45 * dim }));
				const half = Math.min(4, unit * 0.3);
				g.append(svg('line', { x1: cx - half, x2: cx + half, y1: py(it.best), y2: py(it.best), stroke: group.color, 'stroke-width': 2, 'stroke-linecap': 'round', opacity: 0.8 * dim }));
			}
			if (Number.isFinite(it.avg)) g.append(mark(group.shape || 'circle', cx, py(it.avg), isSel ? 5.5 : 4.5, group.color, { opacity: dim }));
			if (isSel && Number.isFinite(it.avg)) {
				// The chosen item, named on top of everything else.
				labels.append(svg('circle', { cx, cy: py(it.avg), r: 10, fill: 'none', stroke: 'var(--text)', 'stroke-width': 1.5 }));
				const right = cx < f.x0 + f.w - 140;
				labels.append(svg('text', { x: right ? cx + 14 : cx - 14, y: py(it.avg) + 4, 'text-anchor': right ? 'start' : 'end', fill: 'var(--text)', 'font-size': 12, 'font-weight': 600,
					stroke: 'var(--surface)', 'stroke-width': 3, 'paint-order': 'stroke', text: it.label }));
			}
			const hit = svg('rect', { x: x + unit * i, y: f.y0, width: unit, height: f.hh, fill: 'transparent', class: onSelect ? 'hit clickable' : 'hit',
				onPointermove: (e) => showTip(hit, [tipTitle(it.label), tipRow(format(it.best), 'best', group.color), tipRow(format(it.avg), 'average', group.color),
					tipRow(format(it.min), 'worst', group.color), it.note ? h('div', { class: 'tip-note' }, it.note) : null], e),
				onPointerleave: hideTip, onClick: onSelect ? () => onSelect(it) : null });
			hits.append(hit);
		});
		x += bandW + gap;
	}
	g.append(labels, hits);
	f.el.append(g);
	return f.el;
}

// A dense square grid (a pair for every row and column) as one SVG with one hover layer.
// rows/cols: [{key, label, color}]; value(i, j) -> number or null; colorFor(v) -> fill;
// bandOf(row) groups rows and columns, with a hairline of the page between groups.
export function matrix({ rows, cols, value, colorFor, cell = 8, onSelect = null, selected = null, tipFor = null, bandOf = null }) {
	const lead = 14;
	const w = lead + cols.length * cell, hgt = lead + rows.length * cell;
	const el = svg('svg', { viewBox: `0 0 ${w} ${hgt}`, class: 'chart', preserveAspectRatio: 'xMidYMid meet' });
	const g = svg('g');
	// The colour strips along the edges stand in for the names; the tooltip carries them.
	cols.forEach((c, j) => g.append(svg('rect', { x: lead + j * cell, y: 2, width: cell - 0.5, height: lead - 5, fill: c.color })));
	rows.forEach((r, i) => g.append(svg('rect', { x: 2, y: lead + i * cell, width: lead - 5, height: cell - 0.5, fill: r.color })));
	rows.forEach((r, i) => cols.forEach((c, j) => {
		const v = value(i, j);
		if (v === null || v === undefined || !Number.isFinite(v)) return;
		g.append(svg('rect', { x: lead + j * cell, y: lead + i * cell, width: cell - 0.6, height: cell - 0.6, fill: colorFor(v) }));
	}));
	if (bandOf) {
		cols.forEach((c, j) => { if (j > 0 && bandOf(cols[j - 1]) !== bandOf(c)) g.append(svg('line', { x1: lead + j * cell - 0.3, x2: lead + j * cell - 0.3, y1: lead, y2: hgt, stroke: 'var(--bg)', 'stroke-width': 1.4 })); });
		rows.forEach((r, i) => { if (i > 0 && bandOf(rows[i - 1]) !== bandOf(r)) g.append(svg('line', { y1: lead + i * cell - 0.3, y2: lead + i * cell - 0.3, x1: lead, x2: w, stroke: 'var(--bg)', 'stroke-width': 1.4 })); });
	}
	const crossH = svg('rect', { x: lead, y: 0, width: cols.length * cell, height: cell, fill: 'none', stroke: 'var(--text)', 'stroke-width': 0.6, opacity: 0, 'pointer-events': 'none' });
	const crossV = svg('rect', { x: 0, y: lead, width: cell, height: rows.length * cell, fill: 'none', stroke: 'var(--text)', 'stroke-width': 0.6, opacity: 0, 'pointer-events': 'none' });
	g.append(crossH, crossV);
	if (selected && selected[0] >= 0 && selected[1] >= 0) {
		g.append(svg('rect', { x: lead + selected[1] * cell - 1, y: lead + selected[0] * cell - 1, width: cell + 1.4, height: cell + 1.4, fill: 'none', stroke: 'var(--text)', 'stroke-width': 1.2, 'pointer-events': 'none' }));
	}
	const at = (e) => {
		const rect = el.getBoundingClientRect();
		const scale = Math.max(w / rect.width, hgt / rect.height);
		const offsetX = (rect.width - w / scale) / 2, offsetY = (rect.height - hgt / scale) / 2;
		const j = Math.floor(((e.clientX - rect.left - offsetX) * scale - lead) / cell);
		const i = Math.floor(((e.clientY - rect.top - offsetY) * scale - lead) / cell);
		return i >= 0 && i < rows.length && j >= 0 && j < cols.length ? [i, j] : null;
	};
	const hit = svg('rect', { x: lead, y: lead, width: cols.length * cell, height: rows.length * cell, fill: 'transparent', class: onSelect ? 'hit clickable' : 'hit',
		onPointermove: (e) => {
			const p = at(e);
			if (!p) { hideTip(); return; }
			crossH.setAttribute('y', lead + p[0] * cell); crossH.setAttribute('opacity', 0.55);
			crossV.setAttribute('x', lead + p[1] * cell); crossV.setAttribute('opacity', 0.55);
			showTip(hit, tipFor ? tipFor(p[0], p[1]) : [tipTitle(`${rows[p[0]].label} · ${cols[p[1]].label}`)], e);
		},
		onPointerleave: () => { crossH.setAttribute('opacity', 0); crossV.setAttribute('opacity', 0); hideTip(); },
		onClick: (e) => { const p = at(e); if (p && onSelect) onSelect(p[0], p[1]); } });
	g.append(hit);
	el.append(g);
	return el;
}

// Columns of dots, a dot an item, each column's middle half a faint box and its median a
// hairline. columns: [{key, label, points: [{key, label, value, color, shape, note}]}].
// `clip` ([low, high]) keeps a few far points from flattening the rest: they sit hollow on the
// edge, their own value in the tooltip.
export function dotColumns({ columns, width = 1000, height = 300, format = (v) => fmt(v, 1), onSelect = null, selected = null, yLabel = '', clip = null }) {
	const pad = { l: 48, r: 10, t: 16, b: 30 };
	const f = frame(width, height, pad);
	const g = svg('g');
	const clamp = (v) => (clip ? Math.max(clip[0], Math.min(clip[1], v)) : v);
	const values = columns.flatMap((c) => c.points.map((p) => clamp(p.value))).filter(Number.isFinite);
	const ticks = rangeTicks(Math.min(0, ...values), Math.max(1e-9, ...values));
	const lo = ticks[0], hi = ticks[ticks.length - 1];
	const py = (v) => f.y0 + f.hh - ((v - lo) / (hi - lo || 1)) * f.hh;
	yAxis(g, f, ticks, py, format, yLabel);
	const slot = f.w / Math.max(1, columns.length);
	const hits = svg('g');
	const ring = svg('g');
	columns.forEach((col, c) => {
		const cx = f.x0 + slot * c + slot / 2;
		const sorted = col.points.map((p) => p.value).filter(Number.isFinite).sort((a, b) => a - b);
		const q = (p) => (sorted.length ? sorted[Math.min(sorted.length - 1, Math.max(0, Math.round(p * (sorted.length - 1))))] : 0);
		const boxW = slot * 0.62;
		if (sorted.length) {
			g.append(svg('rect', { x: cx - boxW / 2, y: py(q(0.75)), width: boxW, height: Math.max(1, py(q(0.25)) - py(q(0.75))), rx: 4, fill: 'var(--surface-3)', opacity: 0.75 }));
			g.append(svg('line', { x1: cx - boxW / 2, x2: cx + boxW / 2, y1: py(q(0.5)), y2: py(q(0.5)), stroke: 'var(--text-2)', 'stroke-width': 1.5 }));
		}
		g.append(svg('text', { x: cx, y: f.y0 + f.hh + 18, 'text-anchor': 'middle', fill: INK.text, 'font-size': FONT, text: col.label }));
		col.points.forEach((p, i) => {
			if (!Number.isFinite(p.value)) return;
			// A fixed spread across the column, so dots of equal value do not hide each other.
			const jitter = (((i * 0.6180339887) % 1) - 0.5) * boxW * 0.9;
			const isSel = selected !== null && p.key === selected;
			const y = py(clamp(p.value));
			const clipped = clamp(p.value) !== p.value;
			g.append(mark(p.shape || 'circle', cx + jitter, y, isSel ? 5 : 3.4, clipped ? 'var(--surface)' : p.color,
				{ opacity: selected !== null && !isSel ? 0.4 : 0.9, stroke: clipped ? p.color : 'var(--surface)', 'stroke-width': clipped ? 1.5 : 2 }));
			if (isSel) ring.append(svg('circle', { cx: cx + jitter, cy: y, r: 9, fill: 'none', stroke: 'var(--text)', 'stroke-width': 1.5 }));
			const hit = svg('circle', { cx: cx + jitter, cy: y, r: 7, fill: 'transparent', class: onSelect ? 'hit clickable' : 'hit',
				onPointermove: (e) => showTip(hit, [tipTitle(`${p.label} · ${col.label}`), tipRow(format(p.value), p.note || '', p.color), clipped ? h('div', { class: 'tip-note' }, 'off the scale, drawn on its edge') : null], e), onPointerleave: hideTip,
				onClick: onSelect ? () => onSelect(p, col) : null });
			hits.append(hit);
		});
	});
	g.append(ring, hits);
	f.el.append(g);
	return f.el;
}

// A key for a colour scale: the ramp as a strip, its two ends named.
export function rampKey(colorFor, lo, hi, format = (v) => fmt(v, 1), label = '') {
	const stops = Array.from({ length: 9 }, (_, i) => colorFor(lo + ((hi - lo) * i) / 8));
	return h('div', { class: 'ramp-key' }, label ? h('span', { class: 'tiny muted' }, label) : null, h('span', { class: 'tiny muted' }, format(lo)),
		h('span', { class: 'ramp-strip', style: { background: `linear-gradient(90deg, ${stops.join(', ')})` } }), h('span', { class: 'tiny muted' }, format(hi)));
}
