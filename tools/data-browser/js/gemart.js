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
	shield: 'shield', marquise: 'marquise', step: 'step', briolette: 'briolette', checkerboard: 'checkerboard', heptagon: 'heptagon' };

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
export function birthstoneImage(characterKey, size = 120) {
	const bs = C.character(characterKey).birthstone || {};
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

function dieGlyph(def, size) {
	const faces = (def.faces || []).length || 6;
	const sides = faces <= 4 ? 3 : faces <= 6 ? 4 : faces <= 8 ? 3 : faces <= 12 ? 5 : 6;
	const pts = regular(sides, -Math.PI / 2).map(([x, y]) => `${(size / 2 + x * size * 0.42).toFixed(1)},${(size / 2 - y * size * 0.42).toFixed(1)}`).join(' ');
	const el = svg('svg', { viewBox: `0 0 ${size} ${size}`, width: size, height: size, class: 'silhouette' });
	el.append(svg('polygon', { points: pts, fill: '#e9e1d2', stroke: '#8a7f6c', 'stroke-width': 1.5, 'stroke-linejoin': 'round' }));
	el.append(svg('text', { x: size / 2, y: size / 2 + size * 0.14, 'text-anchor': 'middle', fill: '#1d1a17', 'font-size': size * 0.36, 'font-weight': 700, text: String(faces) }));
	return el;
}
function creatureGlyph(def, size) {
	const el = svg('svg', { viewBox: `0 0 ${size} ${size}`, width: size, height: size, class: 'silhouette' });
	const hue = def.warden ? '#e2b23a' : '#7fd1c4';
	el.append(svg('path', { d: `M${size * 0.5} ${size * 0.12} L${size * 0.72} ${size * 0.55} L${size * 0.5} ${size * 0.9} L${size * 0.28} ${size * 0.55} Z`, fill: hue, opacity: 0.85 }));
	el.append(svg('path', { d: `M${size * 0.3} ${size * 0.4} L${size * 0.42} ${size * 0.62} L${size * 0.3} ${size * 0.82} L${size * 0.18} ${size * 0.62} Z`, fill: hue, opacity: 0.6 }));
	el.append(svg('ellipse', { cx: size * 0.5, cy: size * 0.9, rx: size * 0.36, ry: size * 0.06, fill: '#2a2f3a' }));
	return el;
}

// A small colour-and-shape key for a gem colour: the mark charts use, beside a label.
export function colorKeyMark(colorKey, size = 12) {
	return h('span', { class: 'ckey', title: C.colorName(colorKey) }, silhouette(colorKey, size, { hue: markColor(colorKey) }));
}
