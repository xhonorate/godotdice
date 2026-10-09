// SVG charts, hand-built: bars, lines, histograms, a scatter, a heatmap and a stacked bar.
// Thin marks, hairline grid, a legend for two or more series, hover tooltips on every mark,
// text in ink tokens and never in the series colour.

import { h, showTip, hideTip, tipRow, tipTitle, fmt } from './ui.js';

const NS = 'http://www.w3.org/2000/svg';
export function svg(tag, attrs = {}, ...children) {
	const el = document.createElementNS(NS, tag);
	for (const [key, value] of Object.entries(attrs)) {
		if (value === null || value === undefined || value === false) continue;
		if (key.startsWith('on') && typeof value === 'function') el.addEventListener(key.slice(2).toLowerCase(), value);
		else if (key === 'text') el.textContent = value;
		else el.setAttribute(key, value);
	}
	for (const child of children.flat(Infinity)) if (child) el.append(child);
	return el;
}

export const INK = { text: 'var(--text-2)', muted: 'var(--muted)', grid: 'var(--grid)', axis: 'var(--axis)', surface: 'var(--surface)' };
export const FONT = 11;

function niceTicks(max, count = 4) {
	if (max <= 0) return [0];
	const rough = max / count;
	const mag = Math.pow(10, Math.floor(Math.log10(rough)));
	const norm = rough / mag;
	const step = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5 : 10) * mag;
	const ticks = [];
	for (let v = 0; v <= max + 1e-9; v += step) ticks.push(Number(v.toFixed(10)));
	if (ticks[ticks.length - 1] < max) ticks.push(Number((ticks[ticks.length - 1] + step).toFixed(10)));
	return ticks;
}

// The mark shape for a gem colour, so identity never rides on hue alone.
export const SHAPES = { RED: 'triangle', BLUE: 'square', GREEN: 'heart', VIOLET: 'drop', GOLD: 'hexagon', WHITE: 'circle', OPAL: 'oval', DEFAULT: 'circle' };
export function markPath(shape, cx, cy, r) {
	switch (shape) {
		case 'triangle': return `M${cx} ${cy - r * 1.15} L${cx + r * 1.1} ${cy + r * 0.75} L${cx - r * 1.1} ${cy + r * 0.75} Z`;
		case 'square': return `M${cx - r * 0.9} ${cy - r * 0.9} h${r * 1.8} v${r * 1.8} h${-r * 1.8} Z`;
		case 'heart': return `M${cx} ${cy + r} C${cx - r * 1.6} ${cy - r * 0.2} ${cx - r * 0.9} ${cy - r * 1.3} ${cx} ${cy - r * 0.45} C${cx + r * 0.9} ${cy - r * 1.3} ${cx + r * 1.6} ${cy - r * 0.2} ${cx} ${cy + r} Z`;
		case 'drop': return `M${cx} ${cy - r * 1.2} C${cx + r * 1.2} ${cy} ${cx + r * 0.95} ${cy + r} ${cx} ${cy + r} C${cx - r * 0.95} ${cy + r} ${cx - r * 1.2} ${cy} ${cx} ${cy - r * 1.2} Z`;
		case 'hexagon': { let d = ''; for (let i = 0; i < 6; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 3; d += `${i ? 'L' : 'M'}${cx + r * 1.05 * Math.cos(a)} ${cy + r * 1.05 * Math.sin(a)} `; } return d + 'Z'; }
		case 'oval': return `M${cx} ${cy - r * 1.15} A${r * 0.8} ${r * 1.15} 0 1 1 ${cx} ${cy + r * 1.15} A${r * 0.8} ${r * 1.15} 0 1 1 ${cx} ${cy - r * 1.15} Z`;
		default: return `M${cx - r} ${cy} A${r} ${r} 0 1 0 ${cx + r} ${cy} A${r} ${r} 0 1 0 ${cx - r} ${cy} Z`;
	}
}
export function mark(shape, cx, cy, r, fill, extra = {}) { return svg('path', { d: markPath(shape, cx, cy, r), fill, stroke: INK.surface, 'stroke-width': 2, 'paint-order': 'stroke', ...extra }); }

export function frame(width, height, pad) {
	const el = svg('svg', { viewBox: `0 0 ${width} ${height}`, width: '100%', height: '100%', class: 'chart', preserveAspectRatio: 'xMidYMid meet', style: `aspect-ratio:${width}/${height}` });
	return { el, x0: pad.l, y0: pad.t, w: width - pad.l - pad.r, hh: height - pad.t - pad.b };
}

function yAxis(g, f, max, format, ticks) {
	for (const t of ticks) {
		const y = f.y0 + f.hh - (t / max) * f.hh;
		g.append(svg('line', { x1: f.x0, x2: f.x0 + f.w, y1: y, y2: y, stroke: t === 0 ? INK.axis : INK.grid, 'stroke-width': 1 }));
		g.append(svg('text', { x: f.x0 - 6, y: y + 3.5, 'text-anchor': 'end', fill: INK.muted, 'font-size': FONT, text: format(t) }));
	}
}

// Columns for categories. data: [{label, value, color, shape, key, note}]. A single series takes
// one colour unless each item names its own (entity colours, never a value ramp).
export function columns({ data, width = 480, height = 200, format = (v) => fmt(v, 1), max = null, color = 'var(--accent)', onSelect = null, selected = null, labelEvery = 1, valueLabels = 'ends', yLabel = '' }) {
	const pad = { l: 44, r: 8, t: 10, b: 30 };
	const f = frame(width, height, pad);
	const top = max ?? Math.max(1e-9, ...data.map((d) => d.value));
	const ticks = niceTicks(top);
	const yMax = ticks[ticks.length - 1] || 1;
	const g = svg('g');
	yAxis(g, f, yMax, format, ticks);
	const slot = f.w / Math.max(1, data.length);
	const bw = Math.min(24, slot * 0.62);
	let peak = -1, peakIndex = -1;
	data.forEach((d, i) => { if (d.value > peak) { peak = d.value; peakIndex = i; } });
	data.forEach((d, i) => {
		const x = f.x0 + slot * i + (slot - bw) / 2;
		const hgt = Math.max(d.value > 0 ? 1 : 0, (d.value / yMax) * f.hh);
		const y = f.y0 + f.hh - hgt;
		const fill = d.color || color;
		const isSel = selected !== null && d.key === selected;
		const bar = svg('path', { d: roundedTop(x, y, bw, hgt, 4), fill, opacity: selected !== null && !isSel ? 0.45 : 1, class: 'mark' });
		const hit = svg('rect', { x: f.x0 + slot * i, y: f.y0, width: slot, height: f.hh, fill: 'transparent', class: onSelect ? 'hit clickable' : 'hit',
			onPointermove: (e) => { bar.setAttribute('opacity', 1); showTip(hit, [tipTitle(d.label), tipRow(format(d.value), d.note || (yLabel || 'value'), fill)], e); },
			onPointerleave: () => { bar.setAttribute('opacity', selected !== null && !isSel ? 0.45 : 1); hideTip(); },
			onClick: onSelect ? () => onSelect(d) : null });
		g.append(bar, hit);
		if (isSel) g.append(svg('rect', { x: x - 2, y: y - 2, width: bw + 4, height: hgt + 2, fill: 'none', stroke: 'var(--text)', 'stroke-width': 1.5, rx: 3 }));
		if (i % labelEvery === 0) g.append(svg('text', { x: f.x0 + slot * i + slot / 2, y: f.y0 + f.hh + 16, 'text-anchor': 'middle', fill: INK.text, 'font-size': FONT, text: d.label }));
		if (valueLabels === 'all' || (valueLabels === 'ends' && (i === peakIndex || isSel))) g.append(svg('text', { x: x + bw / 2, y: y - 4, 'text-anchor': 'middle', fill: INK.text, 'font-size': FONT, text: format(d.value) }));
	});
	f.el.append(g);
	return f.el;
}

function roundedTop(x, y, w, hgt, r) {
	const rr = Math.min(r, w / 2, hgt);
	return `M${x} ${y + hgt} V${y + rr} Q${x} ${y} ${x + rr} ${y} H${x + w - rr} Q${x + w} ${y} ${x + w} ${y + rr} V${y + hgt} Z`;
}

// Horizontal bars with labels: rows [{label, value, color, note, key, sub}].
export function bars({ rows, format = (v) => fmt(v, 1), max = null, color = 'var(--accent)', labelWidth = 120, height = 22, onSelect = null, selected = null, showValues = true }) {
	const top = max ?? Math.max(1e-9, ...rows.map((r) => r.value));
	const wrap = h('div', { class: 'hbars' });
	for (const r of rows) {
		const fill = r.color || color;
		const isSel = selected !== null && r.key === selected;
		const row = h('div', { class: `hbar${onSelect ? ' clickable' : ''}${isSel ? ' is-selected' : ''}`, style: { height: `${height}px`, gridTemplateColumns: `${labelWidth}px 1fr ${showValues ? '58px' : '0'}` }, tabindex: onSelect ? 0 : null,
			onClick: onSelect ? () => onSelect(r) : null, onKeydown: onSelect ? (e) => { if (e.key === 'Enter') onSelect(r); } : null,
			onPointermove: (e) => showTip(row, [tipTitle(r.label), tipRow(format(r.value), r.note || '', fill)], e), onPointerleave: hideTip },
		h('span', { class: 'hbar-label', title: r.label }, r.label),
		h('span', { class: 'hbar-track' }, h('span', { class: 'hbar-fill', style: { width: `${Math.max(r.value > 0 ? 0.6 : 0, (r.value / top) * 100)}%`, background: fill } })),
		showValues ? h('span', { class: 'hbar-value' }, format(r.value)) : null);
		wrap.append(row);
	}
	return wrap;
}

// A histogram over numeric bins: bins [[x, p]], drawn as touching columns with a 2px gap.
export function histogram({ bins, width = 480, height = 160, color = 'var(--accent)', format = (v) => `${(v * 100).toFixed(1)}%`, xFormat = (v) => String(v), mean = null, xLabel = '', highlight = null, minBins = 0 }) {
	const pad = { l: 44, r: 8, t: 12, b: 28 };
	const f = frame(width, height, pad);
	const g = svg('g');
	if (!bins.length) { f.el.append(g); return f.el; }
	const xs = bins.map((b) => b[0]);
	const xMin = Math.min(...xs), xMax = Math.max(...xs, xMin + minBins);
	const step = bins.length > 1 ? Math.min(...bins.slice(1).map((b, i) => b[0] - bins[i][0]).filter((d) => d > 0)) || 1 : 1;
	const n = Math.round((xMax - xMin) / step) + 1;
	const top = Math.max(1e-9, ...bins.map((b) => b[1]));
	const ticks = niceTicks(top, 3);
	const yMax = ticks[ticks.length - 1] || 1;
	yAxis(g, f, yMax, format, ticks);
	const slot = f.w / n;
	const bw = Math.max(1, slot - 2);
	const byX = new Map(bins);
	for (let i = 0; i < n; i++) {
		const x = xMin + i * step;
		const p = byX.get(x) || 0;
		const hgt = (p / yMax) * f.hh;
		const px = f.x0 + slot * i + 1;
		const py = f.y0 + f.hh - hgt;
		const isHi = highlight !== null && x === highlight;
		if (p > 0) g.append(svg('path', { d: roundedTop(px, py, bw, hgt, Math.min(3, bw / 2)), fill: color, opacity: isHi ? 1 : 0.85, class: 'mark' }));
		const hit = svg('rect', { x: f.x0 + slot * i, y: f.y0, width: slot, height: f.hh, fill: 'transparent', class: 'hit',
			onPointermove: (e) => showTip(hit, [tipTitle(`${xLabel ? xLabel + ' ' : ''}${xFormat(x)}`), tipRow(format(p), 'chance', color)], e), onPointerleave: hideTip });
		g.append(hit);
	}
	const labelEvery = Math.max(1, Math.ceil(n / Math.floor(f.w / 34)));
	for (let i = 0; i < n; i += labelEvery) g.append(svg('text', { x: f.x0 + slot * i + slot / 2, y: f.y0 + f.hh + 15, 'text-anchor': 'middle', fill: INK.muted, 'font-size': FONT, text: xFormat(xMin + i * step) }));
	if (mean !== null && Number.isFinite(mean)) {
		const mx = f.x0 + ((mean - xMin) / step + 0.5) * slot;
		g.append(svg('line', { x1: mx, x2: mx, y1: f.y0, y2: f.y0 + f.hh, stroke: 'var(--text)', 'stroke-width': 1, 'stroke-dasharray': '3 3' }));
		g.append(svg('text', { x: mx + 4, y: f.y0 + 9, fill: INK.text, 'font-size': FONT, text: `mean ${fmt(mean, 2)}` }));
	}
	f.el.append(g);
	return f.el;
}

// Lines over an ordinal or numeric x. series: [{key, label, color, shape, points: [{x, y}]}].
// One crosshair, one tooltip listing every series at that x; a legend when there are two or more.
export function lines({ series, width = 520, height = 220, xLabels = null, format = (v) => fmt(v, 1), xFormat = (v) => String(v), max = null, min = 0, legend = true, endLabels = true, yLabel = '', markers = true, area = false }) {
	const pad = { l: 44, r: endLabels && series.length <= 4 ? 70 : 12, t: 12, b: 30 };
	const f = frame(width, height, pad);
	const g = svg('g');
	const xsAll = [...new Set(series.flatMap((s) => s.points.map((p) => p.x)))].sort((a, b) => a - b);
	if (!xsAll.length) { f.el.append(g); return h('div', { class: 'chart-wrap' }, f.el); }
	const xMin = xsAll[0], xMax = xsAll[xsAll.length - 1];
	const top = max ?? Math.max(1e-9, ...series.flatMap((s) => s.points.map((p) => p.y)));
	const ticks = niceTicks(top);
	const yMax = ticks[ticks.length - 1] || 1;
	yAxis(g, f, yMax, format, ticks);
	const px = (x) => (xMax === xMin ? f.x0 + f.w / 2 : f.x0 + ((x - xMin) / (xMax - xMin)) * f.w);
	const py = (y) => f.y0 + f.hh - ((y - min) / (yMax - min)) * f.hh;
	const labelEvery = Math.max(1, Math.ceil(xsAll.length / Math.floor(f.w / 40)));
	xsAll.forEach((x, i) => { if (i % labelEvery === 0 || i === xsAll.length - 1) g.append(svg('text', { x: px(x), y: f.y0 + f.hh + 16, 'text-anchor': 'middle', fill: INK.text, 'font-size': FONT, text: xLabels ? xLabels[x] ?? xFormat(x) : xFormat(x) })); });
	for (const s of series) {
		const pts = s.points.slice().sort((a, b) => a.x - b.x);
		const d = pts.map((p, i) => `${i ? 'L' : 'M'}${px(p.x)} ${py(p.y)}`).join(' ');
		if (area && pts.length) g.append(svg('path', { d: `${d} L${px(pts[pts.length - 1].x)} ${py(min)} L${px(pts[0].x)} ${py(min)} Z`, fill: s.color, opacity: 0.1 }));
		g.append(svg('path', { d, fill: 'none', stroke: s.color, 'stroke-width': 2, 'stroke-linejoin': 'round', 'stroke-linecap': 'round', opacity: s.dim ? 0.35 : 1 }));
		if (markers) for (const p of pts) g.append(mark(s.shape || 'circle', px(p.x), py(p.y), 4, s.color, { opacity: s.dim ? 0.35 : 1 }));
		if (endLabels && series.length <= 4 && pts.length) g.append(svg('text', { x: px(pts[pts.length - 1].x) + 8, y: py(pts[pts.length - 1].y) + 3.5, fill: INK.text, 'font-size': FONT, text: s.label }));
	}
	// Crosshair: a hairline that snaps to the nearest x, and one tooltip for every series.
	const cross = svg('line', { x1: 0, x2: 0, y1: f.y0, y2: f.y0 + f.hh, stroke: INK.axis, 'stroke-width': 1, opacity: 0 });
	g.append(cross);
	const hit = svg('rect', { x: f.x0, y: f.y0, width: f.w, height: f.hh, fill: 'transparent',
		onPointermove: (e) => {
			const rect = f.el.getBoundingClientRect();
			const scale = width / rect.width;
			const mx = (e.clientX - rect.left) * scale;
			let best = xsAll[0];
			for (const x of xsAll) if (Math.abs(px(x) - mx) < Math.abs(px(best) - mx)) best = x;
			cross.setAttribute('x1', px(best)); cross.setAttribute('x2', px(best)); cross.setAttribute('opacity', 1);
			const rows = series.map((s) => { const p = s.points.find((q) => q.x === best); return p ? tipRow(format(p.y), s.label, s.color) : null; }).filter(Boolean);
			showTip(hit, [tipTitle(xLabels ? xLabels[best] ?? xFormat(best) : xFormat(best)), ...rows], e);
		}, onPointerleave: () => { cross.setAttribute('opacity', 0); hideTip(); } });
	g.append(hit);
	f.el.append(g);
	const wrap = h('div', { class: 'chart-wrap' }, f.el);
	if (legend && series.length >= 2) wrap.append(legendFor(series.map((s) => ({ label: s.label, color: s.color, shape: s.shape, kind: 'line' }))));
	return wrap;
}

export function legendFor(items) {
	return h('div', { class: 'legend' }, items.map((it) => h('span', { class: 'legend-item' },
		it.kind === 'line' ? h('i', { class: 'legend-line', style: { background: it.color } }) : h('i', { class: 'dot', style: { background: it.color } }),
		it.label)));
}

// A scatter: points [{x, y, color, shape, label, key, size}]. Every point gets a hit area well
// beyond its mark, and the selected point is ringed.
export function scatter({ points, width = 560, height = 300, xLabel = '', yLabel = '', xFormat = (v) => fmt(v, 0), yFormat = (v) => fmt(v, 1), onSelect = null, selected = null, xMax = null, yMax = null, labels = 'selected' }) {
	const pad = { l: 46, r: 14, t: 12, b: 34 };
	const f = frame(width, height, pad);
	const g = svg('g');
	const xt = niceTicks(xMax ?? Math.max(1e-9, ...points.map((p) => p.x)));
	const yt = niceTicks(yMax ?? Math.max(1e-9, ...points.map((p) => p.y)));
	const xM = xt[xt.length - 1] || 1, yM = yt[yt.length - 1] || 1;
	yAxis(g, f, yM, yFormat, yt);
	for (const t of xt) {
		const x = f.x0 + (t / xM) * f.w;
		g.append(svg('line', { x1: x, x2: x, y1: f.y0, y2: f.y0 + f.hh, stroke: t === 0 ? INK.axis : INK.grid }));
		g.append(svg('text', { x, y: f.y0 + f.hh + 15, 'text-anchor': 'middle', fill: INK.muted, 'font-size': FONT, text: xFormat(t) }));
	}
	if (xLabel) g.append(svg('text', { x: f.x0 + f.w, y: f.y0 + f.hh + 29, 'text-anchor': 'end', fill: INK.text, 'font-size': FONT, text: xLabel }));
	if (yLabel) g.append(svg('text', { x: f.x0 + 4, y: f.y0 + 9, fill: INK.text, 'font-size': FONT, text: yLabel }));
	const px = (x) => f.x0 + (x / xM) * f.w, py = (y) => f.y0 + f.hh - (y / yM) * f.hh;
	const marks = svg('g');
	const hits = svg('g');
	for (const p of points) {
		const isSel = selected !== null && p.key === selected;
		const r = p.size || 5;
		const m = mark(p.shape || 'circle', px(p.x), py(p.y), r, p.color, { opacity: selected !== null && !isSel ? 0.55 : 0.95, class: 'mark' });
		marks.append(m);
		if (isSel) marks.append(svg('circle', { cx: px(p.x), cy: py(p.y), r: r + 6, fill: 'none', stroke: 'var(--text)', 'stroke-width': 1.5 }));
		if (labels === 'all' || (labels === 'selected' && isSel)) marks.append(svg('text', { x: px(p.x) + r + 5, y: py(p.y) + 3.5, fill: INK.text, 'font-size': FONT, text: p.label }));
		const hit = svg('circle', { cx: px(p.x), cy: py(p.y), r: 12, fill: 'transparent', class: onSelect ? 'hit clickable' : 'hit',
			onPointermove: (e) => { m.setAttribute('opacity', 1); showTip(hit, [tipTitle(p.label), tipRow(xFormat(p.x), xLabel, p.color), tipRow(yFormat(p.y), yLabel, p.color), p.note ? h('div', { class: 'tip-note' }, p.note) : null], e); },
			onPointerleave: () => { m.setAttribute('opacity', selected !== null && !isSel ? 0.55 : 0.95); hideTip(); },
			onClick: onSelect ? () => onSelect(p) : null });
		hits.append(hit);
	}
	g.append(marks, hits);
	f.el.append(g);
	return f.el;
}

// A heatmap: rows × cols of values on one hue, brighter for more on this dark surface.
export function heatmap({ rows, cols, values, format = (v) => fmt(v, 1), max = null, min = 0, onSelect = null, selected = null, cellLabels = true, rowLabelWidth = 110, colorFor = null, cellHeight = 26 }) {
	const top = max ?? Math.max(1e-9, ...values.flat().filter((v) => v !== null && v !== undefined));
	const grid = h('div', { class: 'heat', style: { gridTemplateColumns: `${rowLabelWidth}px repeat(${cols.length}, minmax(0, 1fr))` } });
	grid.append(h('div'));
	for (const c of cols) grid.append(h('div', { class: 'heat-col' }, c));
	rows.forEach((r, i) => {
		grid.append(h('div', { class: 'heat-row', title: r }, r));
		cols.forEach((c, j) => {
			const v = values[i][j];
			const t = v === null || v === undefined ? null : Math.max(0, Math.min(1, (v - min) / ((top - min) || 1)));
			const bg = t === null ? 'transparent' : colorFor ? colorFor(v, t) : heat(t);
			const key = `${i}:${j}`;
			const cell = h('div', { class: `heat-cell${onSelect ? ' clickable' : ''}${selected === key ? ' is-selected' : ''}`, style: { background: bg, height: `${cellHeight}px`, color: t !== null && t > 0.6 ? '#141414' : 'var(--text)' }, tabindex: onSelect ? 0 : null,
				onPointermove: (e) => showTip(cell, [tipTitle(`${r} · ${c}`), tipRow(v === null || v === undefined ? '—' : format(v), '', bg)], e), onPointerleave: hideTip,
				onClick: onSelect ? () => onSelect(i, j) : null }, cellLabels && t !== null ? format(v) : '');
			grid.append(cell);
		});
	});
	return grid;
}

// One-hue sequential ramp for the dark surface: surface at nothing, bright amber at most.
export function heat(t) {
	const a = [33, 38, 47], b = [240, 201, 90];
	const mix = (i) => Math.round(a[i] + (b[i] - a[i]) * Math.pow(t, 0.85));
	return `rgb(${mix(0)},${mix(1)},${mix(2)})`;
}

// A stacked bar for part-to-whole: segments [{label, value, color}] in a fixed order.
export function stacked({ segments, height = 18, format = (v) => `${(v * 100).toFixed(0)}%`, legend = true }) {
	const total = segments.reduce((s, x) => s + x.value, 0) || 1;
	const bar = h('div', { class: 'stack', style: { height: `${height}px` } });
	for (const s of segments) {
		if (s.value <= 0) continue;
		const seg = h('div', { class: 'stack-seg', style: { flex: `${s.value} 0 0`, background: s.color }, onPointermove: (e) => showTip(seg, [tipTitle(s.label), tipRow(format(s.value / total), 'share', s.color)], e), onPointerleave: hideTip });
		bar.append(seg);
	}
	const wrap = h('div', { class: 'stack-wrap' }, bar);
	if (legend) wrap.append(h('div', { class: 'legend' }, segments.filter((s) => s.value > 0).map((s) => h('span', { class: 'legend-item' }, h('i', { class: 'dot', style: { background: s.color } }), `${s.label} ${format(s.value / total)}`))));
	return wrap;
}

// A tiny inline sparkline of values, one series, for table cells.
export function sparkline(values, { width = 70, height = 18, color = 'var(--accent)', max = null } = {}) {
	const top = max ?? Math.max(1e-9, ...values);
	const el = svg('svg', { viewBox: `0 0 ${width} ${height}`, width, height, class: 'spark' });
	const step = values.length > 1 ? (width - 8) / (values.length - 1) : 0;
	const d = values.map((v, i) => `${i ? 'L' : 'M'}${4 + i * step} ${height - 3 - (v / top) * (height - 6)}`).join(' ');
	el.append(svg('path', { d, fill: 'none', stroke: color, 'stroke-width': 1.5, 'stroke-linejoin': 'round' }));
	values.forEach((v, i) => el.append(svg('circle', { cx: 4 + i * step, cy: height - 3 - (v / top) * (height - 6), r: 2, fill: color })));
	return el;
}

// Five small cells for a Cut ladder, brighter as the value rises, with the number in each.
export function ladderCells(values, { format = (v) => String(v), max = null, better = 'high' } = {}) {
	const nums = values.map(Number);
	const top = max ?? Math.max(1e-9, ...nums);
	const low = Math.min(...nums);
	return h('div', { class: 'ladder' }, nums.map((v, i) => {
		const t = top === low ? 0.5 : better === 'high' ? (v - low) / (top - low) : (top - v) / (top - low);
		return h('span', { class: 'ladder-cell', style: { background: heat(t * 0.8), color: t > 0.7 ? '#141414' : 'var(--text)' }, title: `Cut ${i}` }, format(values[i]));
	}));
}
