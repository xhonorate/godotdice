// Pictures of things: the renders `tools/browser_assets.gd` photographed out of the game when
// they exist, and a flat silhouette cut from the same outline the 3D stone is when they do not.

import * as C from './sim/content.js';
import { h } from './ui.js';
import { svg } from './charts.js';

let manifest = null;
export function setManifest(m) { manifest = m; }
export const hasAssets = () => Boolean(manifest);
const ASSETS = 'assets/';

export const CUTS = { RED: 'trilliant', BLUE: 'princess', GREEN: 'heart', VIOLET: 'pear', GOLD: 'dutch_rose', WHITE: 'round', OPAL: 'cabochon' };
export const SHAPE_NAMES = { trilliant: 'trilliant', princess: 'princess', heart: 'heart', pear: 'pear', dutch_rose: 'Dutch rose', round: 'round brilliant', cabochon: 'cabochon',
	shield: 'shield', marquise: 'marquise', step: 'step', briolette: 'briolette', checkerboard: 'checkerboard', heptagon: 'heptagon',
	tower: 'tower', spearhead: 'lance head', cushion: 'cushion', fan: 'fan', dart: 'dart', octagon: 'stepped octagon', pill: 'capsule', drop: 'falling drop', cameo: 'cameo', lozenge: 'lozenge', lucky_star: 'lucky star', card: 'card' };

// Chart marks wear these: the game's hues, stepped where a near-white would vanish on the surface.
export const MARK = { RED: '#e0473c', BLUE: '#3f7fe0', GREEN: '#34a05f', VIOLET: '#8b5fd6', GOLD: '#c9922a', WHITE: '#b8c6d9', OPAL: '#9e83dd' };
export const markColor = (colorKey) => MARK[colorKey] || '#8a93a3';

// --- outlines, ported from view/gems/gem_mesh.gd ------------------------------------------------

const regular = (sides, turn) => Array.from({ length: sides }, (_, i) => { const a = turn + (2 * Math.PI * i) / sides; return [Math.cos(a), Math.sin(a)]; });
const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
function truncated(points, amount) {
	const out = [];
	const n = points.length;
	for (let i = 0; i < n; i++) { out.push(lerp(points[i], points[(i + n - 1) % n], amount)); out.push(lerp(points[i], points[(i + 1) % n], amount)); }
	return out;
}
function unit(points) {
	let peak = 0;
	for (const p of points) peak = Math.max(peak, Math.hypot(p[0], p[1]));
	return peak < 1e-6 ? points : points.map((p) => [p[0] / peak, p[1] / peak]);
}
function marquise(steps, waist) {
	const centre = (waist * waist - 1) / (2 * waist);
	const radius = Math.abs(waist - centre);
	const sweep = Math.atan2(1, -centre);
	const half = Math.max(3, Math.floor(steps / 2));
	const out = [];
	for (let i = 0; i <= half; i++) { const a = -sweep + (2 * sweep * i) / half; out.push([centre + Math.cos(a) * radius, Math.sin(a) * radius]); }
	for (let i = half - 1; i > 0; i--) { const a = -sweep + (2 * sweep * i) / half; out.push([-(centre + Math.cos(a) * radius), Math.sin(a) * radius]); }
	return out;
}
function cushion(steps, squareness, waist) {
	const power = 2 / Math.max(squareness, 0.5);
	return Array.from({ length: steps }, (_, i) => { const a = -Math.PI / 2 + (2 * Math.PI * i) / steps; return [Math.sign(Math.cos(a)) * Math.pow(Math.abs(Math.cos(a)), power) * waist, Math.sign(Math.sin(a)) * Math.pow(Math.abs(Math.sin(a)), power)]; });
}
const oval = (steps, waist) => Array.from({ length: steps }, (_, i) => { const a = -Math.PI / 2 + (2 * Math.PI * i) / steps; return [Math.cos(a) * waist, Math.sin(a)]; });
function heart() {
	const raw = [];
	let peak = 0;
	for (let i = 0; i < 24; i++) {
		const t = (2 * Math.PI * i) / 24;
		const p = [16 * Math.pow(Math.sin(t), 3), 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t)];
		raw.push(p); peak = Math.max(peak, Math.hypot(p[0], p[1]));
	}
	return raw.map((p) => [p[0] / peak, p[1] / peak]);
}
const pear = (taper) => Array.from({ length: 20 }, (_, i) => { const t = (2 * Math.PI * i) / 20; return [Math.sin(t) * Math.pow(Math.sin(t * 0.5), taper), Math.cos(t)]; });
// The variant Birthstones' twelve cuts are built from these (view/gems/gem_mesh.gd, the same names).
const mirrored = (half) => half.concat(half.slice().reverse().map(([x, y]) => [-x, y]));
const tilted = (points, degrees) => { const a = (degrees * Math.PI) / 180; return points.map(([x, y]) => [x * Math.cos(a) - y * Math.sin(a), x * Math.sin(a) + y * Math.cos(a)]); };
function pillow(steps, squareness, waist, pinch) {
	const power = 2 / Math.max(squareness, 0.5);
	return Array.from({ length: steps }, (_, i) => {
		const a = -Math.PI / 2 + (2 * Math.PI * i) / steps;
		const drawn = 1 - pinch * Math.pow(Math.cos(2 * a), 2);
		return [Math.sign(Math.cos(a)) * Math.pow(Math.abs(Math.cos(a)), power) * waist * drawn, Math.sign(Math.sin(a)) * Math.pow(Math.abs(Math.sin(a)), power) * drawn];
	});
}
function fan(spread, leaves, scallop) {
	const half = (spread * Math.PI) / 180;
	const lift = Math.cos(half);
	const steps = leaves * 4;
	const out = [];
	for (let i = 0; i <= steps; i++) {
		const a = half + (-half - half) * (i / steps);
		const reach = 1 - scallop * (1 - Math.sin((Math.PI * (i % 4)) / 4));
		out.push([Math.sin(a) * reach, Math.cos(a) * reach - lift]);
	}
	for (const side of [-1, 1]) out.push([side * Math.sin(half) * 0.08, Math.cos(half) * 0.08 - lift]);
	return out;
}
function stadium(steps, waist) {
	const rise = 1 - waist;
	const out = [[waist, 0]];
	for (let i = 0; i <= steps; i++) { const a = (Math.PI * i) / steps; out.push([Math.cos(a) * waist, rise + Math.sin(a) * waist]); }
	out.push([-waist, 0]);
	for (let i = 0; i <= steps; i++) { const a = Math.PI + (Math.PI * i) / steps; out.push([Math.cos(a) * waist, -rise + Math.sin(a) * waist]); }
	return out;
}
function hookedDrop() {
	const belly = [-0.13, -0.32];
	const radius = 0.62;
	const tip = [0.37, 0.9];
	const out = [];
	for (let i = 0; i < 15; i++) { const a = ((20 + (-210 - 20) * (i / 14)) * Math.PI) / 180; out.push([belly[0] + Math.cos(a) * radius, belly[1] + Math.sin(a) * radius]); }
	const left = out[out.length - 1];
	const right = out[0];
	const full = [left[0] + 0.5 * 0.9, left[1] + 0.866 * 0.9];
	const hollow = [right[0] - 0.342 * 0.6, right[1] + 0.94 * 0.6];
	for (let i = 1; i < 7; i++) { const t = i / 6; out.push(lerp(lerp(left, full, t), lerp(full, tip, t), t)); }
	for (let i = 1; i < 6; i++) { const t = i / 6; out.push(lerp(lerp(tip, hollow, t), lerp(hollow, right, t), t)); }
	return out;
}
function scalloped(beads, waist, depth) {
	const steps = beads * 4;
	return Array.from({ length: steps }, (_, i) => {
		const a = -Math.PI / 2 + (2 * Math.PI * (i - 2)) / steps;
		const swell = Math.sin((Math.PI * (i % 4)) / 4);
		const drawn = 1 - depth * (1 - swell);
		return [Math.cos(a) * waist * drawn, Math.sin(a) * drawn];
	});
}
function starPoints(points, outer, inner) {
	return Array.from({ length: points * 2 }, (_, i) => {
		const a = Math.PI / 2 + (Math.PI * i) / points;
		const r = i % 2 === 0 ? outer : inner;
		return [Math.cos(a) * r, Math.sin(a) * r];
	});
}
function boxed(halfWidth, halfHeight, radius, steps) {
	const out = [];
	for (let corner = 0; corner < 4; corner++) {
		const centre = [(halfWidth - radius) * (corner === 0 || corner === 3 ? 1 : -1), (halfHeight - radius) * (corner < 2 ? 1 : -1)];
		for (let i = 0; i <= steps; i++) { const a = (Math.PI / 2) * (corner + i / steps); out.push([centre[0] + Math.cos(a) * radius, centre[1] + Math.sin(a) * radius]); }
	}
	return out;
}

export function outline(shape) {
	switch (shape) {
		case 'trilliant': return truncated(regular(3, -Math.PI * 0.5), 0.17);
		case 'princess': return truncated(regular(4, Math.PI * 0.25), 0.2);
		case 'heart': return heart();
		case 'pear': return pear(1.55);
		case 'shield': return unit([[-0.82, 1], [0.82, 1], [0.88, 0.52], [0.86, 0.14], [0.74, -0.26], [0.52, -0.62], [0.27, -0.87], [0, -1], [-0.27, -0.87], [-0.52, -0.62], [-0.74, -0.26], [-0.86, 0.14], [-0.88, 0.52]]);
		case 'marquise': return marquise(24, 0.4);
		case 'step': return unit(truncated([[0.74, 1], [0.74, -1], [-0.74, -1], [-0.74, 1]], 0.24));
		case 'briolette': return pear(2.8);
		case 'checkerboard': return unit(cushion(28, 3.1, 0.94));
		case 'heptagon': return truncated(regular(7, -Math.PI * 0.5), 0.1);
		case 'dutch_rose': return regular(6, -Math.PI * 0.5);
		case 'cabochon': return oval(24, 0.76);
		// The delvers' later Birthstones.
		case 'tower': return unit(mirrored([[0.7, -0.9], [0.7, -0.68], [0.58, -0.52], [0.54, 0.26], [0.72, 0.44], [0.72, 0.9], [0.46, 0.9], [0.32, 0.64], [0.2, 0.64], [0.18, 0.9]]));
		case 'spearhead': return unit(tilted(mirrored([[0.22, -0.92], [0.46, -0.34], [0.38, 0.3], [0.05, 1]]), 24));
		case 'cushion': return unit(pillow(32, 5, 0.78, 0.2));
		case 'fan': return unit(fan(58, 5, 0.075));
		case 'dart': return unit(truncated([[0, 1], [0.72, -0.74], [0, -0.3], [-0.72, -0.74]], 0.06));
		case 'octagon': return regular(8, Math.PI * 0.125);
		case 'pill': return unit(tilted(stadium(7, 0.46), -28));
		case 'drop': return unit(hookedDrop());
		case 'cameo': return unit(scalloped(14, 0.78, 0.085));
		case 'lozenge': return unit(mirrored([[0.1, -1], [0.62, -0.1], [0.62, 0.1], [0.1, 1]]));
		case 'lucky_star': return truncated(starPoints(5, 1, 0.62), 0.1);
		case 'card': return unit(tilted(boxed(0.64, 0.92, 0.1, 2), 10));
	}
	return regular(20, -Math.PI * 0.5);
}

let gradientCounter = 0;
// A flat stone: the outline filled with its hue, lit from the upper left, as the game's 2D stand-in.
export function silhouette(colorKey, size = 40, opts = {}) {
	const shape = opts.shape || CUTS[colorKey] || 'round';
	const hue = opts.hue || C.colorHex(colorKey);
	const pts = outline(shape);
	const scale = size * 0.44;
	const points = pts.map(([x, y]) => `${(size / 2 + x * scale).toFixed(2)},${(size / 2 - y * scale).toFixed(2)}`).join(' ');
	const id = `g${++gradientCounter}`;
	const el = svg('svg', { viewBox: `0 0 ${size} ${size}`, width: size, height: size, class: 'silhouette', 'aria-hidden': 'true' });
	const defs = svg('defs', {}, svg('linearGradient', { id, x1: '0', y1: '0', x2: '1', y2: '1' },
		svg('stop', { offset: '0', 'stop-color': '#ffffff', 'stop-opacity': '0.55' }), svg('stop', { offset: '0.5', 'stop-color': hue, 'stop-opacity': '1' }), svg('stop', { offset: '1', 'stop-color': '#000000', 'stop-opacity': '0.35' })));
	el.append(defs);
	el.append(svg('polygon', { points, fill: hue }));
	el.append(svg('polygon', { points, fill: `url(#${id})`, stroke: 'rgba(255,255,255,0.35)', 'stroke-width': 1 }));
	return el;
}

// --- pictures ---------------------------------------------------------------------------------

function picture(path, fallback, size, alt, extraClass = '') {
	const wrap = h('span', { class: `pic ${extraClass}`, style: { width: `${size}px`, height: `${size}px` } });
	if (manifest) {
		const img = h('img', { src: ASSETS + path, alt, width: size, height: size, loading: 'lazy', decoding: 'async' });
		img.addEventListener('error', () => { img.remove(); wrap.append(fallback()); wrap.classList.add('is-fallback'); });
		wrap.append(img);
	} else {
		wrap.append(fallback());
		wrap.classList.add('is-fallback');
	}
	return wrap;
}

export function gemImage(skillKey, size = 64) {
	const def = C.skill(skillKey);
	const colorKey = def.color || 'WHITE';
	return picture(`gems/${skillKey}.png`, () => silhouette(colorKey, size, { hue: def.hue ? `#${def.hue}` : null }), size, `${def.name || skillKey}, a ${C.colorName(colorKey).toLowerCase()} ${SHAPE_NAMES[CUTS[colorKey]] || ''} stone`, 'pic-gem');
}
export function matrixImage(colorKey, cut, clarity, size = 96) {
	return picture(`matrix/${colorKey}_c${cut}_k${clarity}.png`, () => silhouette(colorKey, size), size, `${C.colorName(colorKey)} stone, cut ${cut}, clarity ${clarity}`, 'pic-gem');
}
export function caratImage(colorKey, carat, size = 96) {
	const scale = 0.45 + 0.55 * ((carat - 1) / 23);
	return picture(`carats/${colorKey}_${carat}.png`, () => silhouette(colorKey, Math.round(size * scale)), size, `${carat}-carat ${C.colorName(colorKey)} stone`, 'pic-gem');
}
export function rawImage(colorKey, sizeClass, size = 96) {
	return picture(`raw/${colorKey}_${sizeClass}.png`, () => silhouette(colorKey, size * 0.6, { hue: '#7a7f88' }), size, `a ${sizeClass.toLowerCase()} raw ${C.colorName(colorKey)} stone in its rock`, 'pic-gem');
}
export function inclusionImage(key, size = 72) {
	return picture(`inclusions/${key}.png`, () => silhouette('WHITE', size), size, `${C.inclusion(key).name || key} frozen in a white stone`, 'pic-gem');
}
// `worn` names one of the delver's variant Birthstones: nothing photographs those yet, so a
// variant is drawn flat, in its own hue.
export function birthstoneImage(characterKey, size = 120, worn = '') {
	const bs = C.birthstoneDef(characterKey, worn);
	if (C.birthstoneKey(characterKey, worn)) {
		const wrap = h('span', { class: 'pic pic-gem is-fallback', style: { width: `${size}px`, height: `${size}px` }, title: `${bs.name || 'Birthstone'} of ${C.character(characterKey).name || characterKey}` });
		wrap.append(silhouette('WHITE', size, { shape: bs.style || 'shield', hue: bs.hue ? `#${bs.hue}` : null }));
		return wrap;
	}
	return picture(`birthstones/${characterKey}.png`, () => silhouette('WHITE', size, { shape: bs.style || 'shield', hue: bs.hue ? `#${bs.hue}` : null }), size, `${bs.name || 'Birthstone'} of ${C.character(characterKey).name || characterKey}`, 'pic-gem');
}
export function dieImage(key, size = 56) {
	const def = C.die(key);
	return picture(`dice/${key}.png`, () => dieGlyph(def, size), size, `${def.name || key}`, 'pic-die');
}
export function creatureImage(key, size = 120) {
	const def = C.creature(key);
	return picture(`creatures/${key}.png`, () => creatureGlyph(def, size), size, `${def.name || key}`, 'pic-creature');
}

// --- a creature's action dice (docs/CREATURE_DICE.md) ------------------------------------------

// Each kind of move: its face's colour on the die, and the ink its pips and number are written in.
export const MOVE_FACE = { attack: '#d72d47', guard: '#2c6ae8', meddle: '#7f4dd1', mend: '#3fb57a', ready: '#f1bb25', dud: '#4d5363' };
export const MOVE_INK = { attack: '#ff8f7e', guard: '#7fb0ff', meddle: '#c9a9ff', mend: '#6fd69a', ready: '#f0c860', dud: '#9aa3b8' };
const MARK_IVORY = '#f5e9c8';

// One of a creature's dice, photographed with its moves engraved on the faces; the plain die of
// its shape where tools/browser_assets.gd has not shot it (`creature_dice`).
export function creatureDieImage(key, index, shape, size = 56) {
	const shot = manifest && manifest.creature_dice && (manifest.creature_dice.dice || {})[key];
	if (!shot || !shot.includes(index)) return dieImage(shape, size);
	return picture(`creature_dice/${key}_${index}.png`, () => dieGlyph(C.die(shape), size), size, `${C.creature(key).name || key}'s ${String(shape).toLowerCase()}`, 'pic-die');
}

// A face's mark on its kind's colour, as the die wears it: ivory, slate on a dud. The mark is a
// white-on-clear picture (`marks` in the manifest) used as a mask; without one, its move's
// initial stands in.
export function markChip(mark, kind, size = 26, title = '') {
	const k = MOVE_FACE[kind] ? kind : 'dud';
	const chip = h('span', { class: 'mk', title: title || null, style: { width: `${size}px`, height: `${size}px`, background: MOVE_FACE[k] } });
	const known = manifest && manifest.marks && (manifest.marks.keys || []).includes(mark);
	if (known) {
		const url = `url("${ASSETS}marks/${mark}.png")`;
		chip.append(h('i', { style: { background: k === 'dud' ? MOVE_INK.dud : MARK_IVORY, maskImage: url, webkitMaskImage: url } }));
	} else {
		chip.append(h('b', { style: { color: k === 'dud' ? MOVE_INK.dud : MARK_IVORY, fontSize: `${Math.round(size * 0.5)}px` } }, (title || mark || '?').slice(0, 1).toUpperCase()));
	}
	return chip;
}

// A pip for every face that carries a move, in its kind's ink.
export function pips(count, kind) {
	return h('span', { class: 'pips', title: `${count} ${count === 1 ? 'face' : 'faces'}` }, Array.from({ length: count }, () => h('i', { style: { background: MOVE_INK[kind] || MOVE_INK.dud } })));
}

function dieGlyph(def, size) {
	const faces = (def.faces || []).length || 6;
	const sides = faces <= 4 ? 3 : faces <= 6 ? 4 : faces <= 8 ? 3 : faces <= 12 ? 5 : 6;
	const pts = regular(sides, -Math.PI / 2).map(([x, y]) => `${(size / 2 + x * size * 0.42).toFixed(1)},${(size / 2 - y * size * 0.42).toFixed(1)}`).join(' ');
	const el = svg('svg', { viewBox: `0 0 ${size} ${size}`, width: size, height: size, class: 'silhouette' });
	el.append(svg('polygon', { points: pts, fill: '#e9e1d2', stroke: '#8a7f6c', 'stroke-width': 1.5, 'stroke-linejoin': 'round' }));
	el.append(svg('text', { x: size / 2, y: size / 2 + size * 0.14, 'text-anchor': 'middle', fill: '#1d1a17', 'font-size': size * 0.36, 'font-weight': 700, text: String(faces) }));
	return el;
}
// A creature without a photograph yet: a tile in its side's color wearing its initial, so a
// new entry in the bestiary reads at a glance before tools/browser_assets.gd has been run.
function creatureGlyph(def, size) {
	const name = String(def.name || '?').replace(/^the\s+/i, '').trim();
	const initial = (name[0] || '?').toUpperCase();
	const hue = def.warden ? '#e2b23a' : def.summon_only ? '#9e83dd' : def.echo ? '#8b5fd6' : '#7fd1c4';
	const el = svg('svg', { viewBox: `0 0 ${size} ${size}`, width: size, height: size, class: 'silhouette', role: 'img', 'aria-label': def.name || '' });
	el.append(svg('rect', { x: size * 0.08, y: size * 0.08, width: size * 0.84, height: size * 0.84, rx: size * 0.18, fill: '#1f242c', stroke: hue, 'stroke-width': Math.max(1, size * 0.03) }));
	el.append(svg('path', { d: `M${size * 0.5} ${size * 0.14} L${size * 0.86} ${size * 0.5} L${size * 0.5} ${size * 0.86} L${size * 0.14} ${size * 0.5} Z`, fill: hue, opacity: 0.12 }));
	el.append(svg('text', { x: size / 2, y: size / 2 + size * 0.17, 'text-anchor': 'middle', fill: hue, 'font-size': size * 0.48, 'font-weight': 700, 'font-family': 'system-ui, sans-serif', text: initial }));
	return el;
}

// A small color-and-shape key for a gem color: the mark charts use, beside a label.
export function colorKeyMark(colorKey, size = 12) {
	return h('span', { class: 'ckey', title: C.colorName(colorKey) }, silhouette(colorKey, size, { hue: markColor(colorKey) }));
}
