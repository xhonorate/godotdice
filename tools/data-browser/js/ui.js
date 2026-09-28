// Small DOM helpers and the controls every page is built from. Everything is textContent:
// nothing from the pack is ever written as HTML.

export function h(tag, attrs = {}, ...children) {
	const el = document.createElement(tag);
	for (const [key, value] of Object.entries(attrs || {})) {
		if (value === null || value === undefined || value === false) continue;
		if (key === 'class') el.className = value;
		else if (key === 'style' && typeof value === 'object') Object.assign(el.style, value);
		else if (key.startsWith('on') && typeof value === 'function') el.addEventListener(key.slice(2).toLowerCase(), value);
		else if (key === 'dataset') Object.assign(el.dataset, value);
		else if (key === 'text') el.textContent = value;
		else if (key === 'html') el.innerHTML = value; // only ever used with our own markup
		else el.setAttribute(key, value === true ? '' : value);
	}
	append(el, children);
	return el;
}
export function append(el, children) {
	for (const child of children.flat(Infinity)) {
		if (child === null || child === undefined || child === false) continue;
		el.append(child instanceof Node ? child : document.createTextNode(String(child)));
	}
	return el;
}
export const clear = (el) => { while (el.firstChild) el.removeChild(el.firstChild); return el; };

export const fmt = (value, places = 1) => Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: places, minimumFractionDigits: 0 });
export const fmtPct = (value, places = 0) => `${(Number(value || 0) * 100).toFixed(places)}%`;
export const fmtSigned = (value, places = 1) => (value > 0 ? '+' : '') + fmt(value, places);
export const title = (value) => String(value ?? '').toLowerCase().split(/[_\s]+/).filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');

// --- controls ---------------------------------------------------------------------------------

export function segmented(options, value, onChange, attrs = {}) {
	const wrap = h('div', { class: 'seg', role: 'tablist', ...attrs });
	for (const opt of options) {
		const [key, label, hint] = Array.isArray(opt) ? opt : [opt, title(opt)];
		wrap.append(h('button', { type: 'button', class: `seg-btn${key === value ? ' is-active' : ''}`, role: 'tab', 'aria-selected': key === value ? 'true' : 'false', title: hint || null, onClick: () => onChange(key) }, label));
	}
	return wrap;
}

export function select(options, value, onChange, attrs = {}) {
	const el = h('select', { class: 'select', ...attrs, onChange: (e) => onChange(e.target.value) });
	for (const opt of options) {
		const [key, label] = Array.isArray(opt) ? opt : [opt, title(opt)];
		el.append(h('option', { value: key, selected: String(key) === String(value) ? true : null }, label));
	}
	return el;
}

export function numberInput(value, onChange, attrs = {}) {
	return h('input', { class: 'input', type: 'number', value, ...attrs, onChange: (e) => onChange(Number(e.target.value)) });
}

export function field(label, control, hint = '') {
	return h('label', { class: 'field', title: hint || null }, h('span', { class: 'field-label' }, label), control);
}

export function toolbar(...items) { return h('div', { class: 'toolbar' }, ...items); }

// A stepper for a small ordinal value with named steps (Cut, Clarity).
export function stepper(labels, value, onChange, colors = null) {
	const wrap = h('div', { class: 'stepper', role: 'radiogroup' });
	labels.forEach((label, i) => {
		const btn = h('button', { type: 'button', class: `step${i === value ? ' is-active' : ''}`, role: 'radio', 'aria-checked': i === value ? 'true' : 'false', onClick: () => onChange(i) },
			colors ? h('i', { class: 'step-dot', style: { background: colors[i] } }) : null, label);
		wrap.append(btn);
	});
	return wrap;
}

// --- surfaces ---------------------------------------------------------------------------------

export function card(titleText, body, opts = {}) {
	const head = titleText === null ? null : h('header', { class: 'card-head' }, h('h3', { class: 'card-title' }, titleText), opts.meta ? h('span', { class: 'card-meta' }, opts.meta) : null, opts.tools || null);
	return h('section', { class: `card${opts.class ? ' ' + opts.class : ''}`, style: opts.style || null }, head, h('div', { class: `card-body${opts.pad === false ? ' no-pad' : ''}` }, body));
}

export function stat(label, value, note = '', opts = {}) {
	return h('div', { class: `stat${opts.class ? ' ' + opts.class : ''}` }, h('div', { class: 'stat-label' }, label), h('div', { class: 'stat-value' }, value), note ? h('div', { class: 'stat-note' }, note) : null);
}

export function kv(rows) {
	return h('dl', { class: 'kv' }, rows.map(([k, v]) => [h('dt', {}, k), h('dd', {}, v)]));
}

export function chip(text, opts = {}) {
	return h('span', { class: `chip${opts.class ? ' ' + opts.class : ''}`, title: opts.title || null }, opts.color ? h('i', { class: 'dot', style: { background: opts.color } }) : null, text);
}

export function swatch(color, size = 10) { return h('i', { class: 'dot', style: { background: color, width: `${size}px`, height: `${size}px` } }); }

export function note(text, kind = '') { return h('p', { class: `note${kind ? ' ' + kind : ''}` }, text); }

export function empty(text) { return h('div', { class: 'empty' }, text); }

export function progress(fraction) {
	return h('div', { class: 'progress' }, h('div', { class: 'progress-fill', style: { width: `${Math.round(fraction * 100)}%` } }));
}

// A meter: a fraction of a limit, drawn as a filled track.
export function meter(fraction, color = 'var(--accent)', label = '') {
	return h('div', { class: 'meter', title: label || null }, h('div', { class: 'meter-fill', style: { width: `${Math.max(0, Math.min(100, fraction * 100))}%`, background: color } }));
}

// --- tables -----------------------------------------------------------------------------------
// columns: [{key, label, align, render(row), sort(row) -> number|string, width, title}]

export function table({ columns, rows, sort = null, onSort = null, selectedKey = null, rowKey = (r) => r.key, onRowClick = null, compact = false, sticky = true, footer = null }) {
	const t = h('table', { class: `table${compact ? ' compact' : ''}${onRowClick ? ' clickable' : ''}${sticky ? ' sticky' : ''}` });
	const thead = h('thead', {}, h('tr', {}, columns.map((col) => {
		const active = sort && sort.key === col.key;
		return h('th', { class: `${col.align ? 'al-' + col.align : ''}${onSort && col.sort !== false ? ' sortable' : ''}${active ? ' is-sorted' : ''}`, style: col.width ? { width: col.width } : null, title: col.title || null,
			'aria-sort': active ? (sort.dir > 0 ? 'ascending' : 'descending') : null,
			onClick: onSort && col.sort !== false ? () => onSort(col.key) : null },
		col.label, active ? h('span', { class: 'sort-mark' }, sort.dir > 0 ? '▲' : '▼') : null);
	})));
	const tbody = h('tbody');
	for (const row of rows) {
		const key = rowKey(row);
		const tr = h('tr', { class: selectedKey !== null && key === selectedKey ? 'is-selected' : null, tabindex: onRowClick ? 0 : null, onClick: onRowClick ? () => onRowClick(row) : null,
			onKeydown: onRowClick ? (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onRowClick(row); } } : null });
		for (const col of columns) tr.append(h('td', { class: col.align ? 'al-' + col.align : null }, col.render ? col.render(row) : row[col.key]));
		tbody.append(tr);
	}
	t.append(thead, tbody);
	if (footer) t.append(h('tfoot', {}, footer));
	return t;
}

export function sortRows(rows, columns, sort) {
	if (!sort) return rows;
	const col = columns.find((c) => c.key === sort.key);
	if (!col) return rows;
	const val = col.sort || ((r) => r[col.key]);
	return rows.slice().sort((a, b) => {
		const x = val(a), y = val(b);
		if (typeof x === 'number' && typeof y === 'number') return (x - y) * sort.dir;
		return String(x).localeCompare(String(y)) * sort.dir;
	});
}

// Sort state: click a column to sort, again to flip.
export function toggleSort(sort, key, defaultDir = -1) {
	if (sort && sort.key === key) return { key, dir: -sort.dir };
	return { key, dir: defaultDir };
}

// --- tooltip ----------------------------------------------------------------------------------

let tip = null;
export function showTip(target, content, event = null) {
	if (!tip) { tip = h('div', { class: 'tip', role: 'tooltip' }); document.body.append(tip); }
	clear(tip);
	append(tip, [content]);
	tip.classList.add('is-on');
	const rect = target.getBoundingClientRect ? target.getBoundingClientRect() : null;
	const x = event ? event.clientX : rect.left + rect.width / 2;
	const y = event ? event.clientY : rect.top;
	const w = tip.offsetWidth, hh = tip.offsetHeight;
	let left = x + 14, top = y - hh - 10;
	if (left + w > window.innerWidth - 8) left = x - w - 14;
	if (top < 8) top = y + 18;
	tip.style.left = `${Math.max(8, left)}px`;
	tip.style.top = `${top}px`;
}
export function hideTip() { if (tip) tip.classList.remove('is-on'); }

// A row in a tooltip: value first, label after, keyed by a short stroke of the series colour.
export function tipRow(value, label, color = null) {
	return h('div', { class: 'tip-row' }, color ? h('i', { class: 'tip-key', style: { background: color } }) : null, h('b', {}, value), h('span', {}, label));
}
export function tipTitle(text) { return h('div', { class: 'tip-title' }, text); }
