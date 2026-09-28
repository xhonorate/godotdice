// The content pack, read the way sim/content.gd reads it.

export const COLOR_KEYS = ['RED', 'BLUE', 'GREEN', 'VIOLET', 'GOLD', 'WHITE'];
export const SKILL_COLORS = ['RED', 'BLUE', 'GREEN', 'VIOLET', 'GOLD', 'WHITE', 'OPAL'];
export const OPAL = 'OPAL';
export const SOCKET_ANY = 'ANY';
export const RARITIES = ['COMMON', 'UNCOMMON', 'RARE', 'LEGENDARY', 'MYTHIC'];
export const INCLUSION_CLASSES = ['PINPOINT', 'LENS', 'FEATHER', 'FRACTURE', 'STAR'];
export const CHAMBER_KINDS = ['fight', 'elite', 'vein', 'oddity', 'merchant', 'smithy', 'carver', 'well'];

let pack = {};

export function setPack(loaded) { pack = loaded || {}; }
export function getPack() { return pack; }
export function section(name) { const found = pack[name]; return found && typeof found === 'object' && !Array.isArray(found) ? found : {}; }
export function entry(sectionName, key) { const found = section(sectionName)[key]; return found && typeof found === 'object' ? found : {}; }
export function keys(sectionName) { return Object.keys(section(sectionName)).sort(); }

export const skill = (k) => entry('skills', k);
export const inclusion = (k) => entry('inclusions', k);
export const die = (k) => entry('dice', k);
export const engraving = (k) => entry('engravings', k);
export const character = (k) => entry('characters', k);
export const creature = (k) => entry('creatures', k);
export const mine = (k) => entry('mines', k);
export const oddity = (k) => entry('oddities', k);
export const boon = (k) => entry('boons', k);
export const color = (k) => entry('colors', k);

export function constant(name, fallback) {
	const c = pack.constants;
	return c && Object.prototype.hasOwnProperty.call(c, name) ? c[name] : fallback;
}
export function cuts() { return Array.isArray(pack.cuts) ? pack.cuts : []; }
export function clarities() { return Array.isArray(pack.clarities) ? pack.clarities : []; }
export function clarityIndex(key) { return clarities().findIndex((c) => c.key === key); }
export function clearIndex() { const i = clarityIndex('CLEAR'); return i >= 0 ? i : Math.floor(clarities().length / 2); }
export function clarityEntry(index) { const list = clarities(); return list[Math.max(0, Math.min(list.length - 1, index))] || {}; }
export function cutEntry(index) { const list = cuts(); return list[Math.max(0, Math.min(list.length - 1, index))] || {}; }
export function rarityWeight(r) { return Number(entry('rarities', r).weight ?? 1); }
export function rarityScore(r) { return Number(entry('rarities', r).score ?? 0); }
export function colorHex(k) { return `#${color(k).hue || '9aa59a'}`; }
export function colorName(k) { return color(k).name || title(k); }

export function title(value) {
	return String(value ?? '').toLowerCase().split(/[_\s]+/).filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');
}
