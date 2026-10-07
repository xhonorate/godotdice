// The shell: loads the pack, starts the simulation worker, routes #/view/key to a page.

import * as C from './sim/content.js';
import * as Engine from './engine.js';
import { setManifest } from './gemart.js';
import { h, clear } from './ui.js';
import overview from './views/overview.js';
import skills from './views/skills.js';
import stones from './views/stones.js';
import inclusions from './views/inclusions.js';
import dice from './views/dice.js';
import enemies from './views/enemies.js';
import descent from './views/descent.js';
import lapidaries from './views/lapidaries.js';
import oddities from './views/oddities.js';
import music from './views/music.js';
import gold from './views/gold.js';

const VIEWS = [overview, skills, stones, inclusions, dice, enemies, descent, lapidaries, oddities, gold, music];
const GROUPS = [['Analysis', ['overview']], ['Stones', ['skills', 'stones', 'inclusions']], ['The bowl', ['dice', 'lapidaries']], ['The mine', ['enemies', 'descent', 'oddities']], ['The workshop', ['gold']], ['Sound', ['music']]];

const SETTINGS_KEY = 'deepcut.browser.settings';
const defaults = { bowl: ['D6', 'D6', 'D6', 'D8', 'D8'], rerolls: 2, depth: 5, party: 1, mine: 'QUARRY', samples: 4000 };
const settings = { ...defaults, ...(safeParse(localStorage.getItem(SETTINGS_KEY)) || {}) };
function safeParse(text) { try { return JSON.parse(text); } catch { return null; } }
function saveSettings() { localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)); }

const ctx = {
	settings,
	setSetting(key, value) { settings[key] = value; saveSettings(); render(); },
	navigate(view, key = '', params = null) {
		let hash = `#/${view}${key ? '/' + encodeURIComponent(key) : ''}`;
		if (params) hash += '?' + new URLSearchParams(params).toString();
		if (location.hash === hash) render(); else location.hash = hash;
	},
	rerender() { render(); },
	engine: Engine,
};

function route() {
	const raw = location.hash.replace(/^#\/?/, '');
	const [pathPart, query = ''] = raw.split('?');
	const [view = 'overview', key = ''] = pathPart.split('/');
	return { view: VIEWS.some((v) => v.id === view) ? view : 'overview', key: decodeURIComponent(key), params: Object.fromEntries(new URLSearchParams(query)) };
}

let renderToken = 0;
function render() {
	const r = route();
	const view = VIEWS.find((v) => v.id === r.view);
	document.title = `Deep Cut · ${view.label}`;
	document.getElementById('head-title').textContent = view.label;
	document.getElementById('head-crumb').textContent = view.blurb || '';
	document.getElementById('head-context').textContent = `Bowl ${settings.bowl.map((k) => C.die(k).name || k).join(' · ')} · ${settings.rerolls} rerolls · depth ${settings.depth} · party ${settings.party}`;
	buildNav(r.view);
	const content = document.getElementById('content');
	clear(content);
	const rootEl = h('div', { class: `view view-${view.id}` });
	content.append(rootEl);
	content.scrollTop = 0;
	const token = ++renderToken;
	ctx.alive = () => token === renderToken;
	try {
		view.render(rootEl, r, ctx);
	} catch (error) {
		console.error(error);
		rootEl.append(h('div', { class: 'error' }, h('b', {}, 'This page failed to render. '), String(error && error.message || error)));
	}
}

function buildNav(active) {
	const nav = document.getElementById('nav');
	for (const el of [...nav.querySelectorAll('.nav-group, .nav-btn, .nav-foot')]) el.remove();
	for (const [group, ids] of GROUPS) {
		nav.append(h('div', { class: 'nav-group' }, group));
		for (const id of ids) {
			const view = VIEWS.find((v) => v.id === id);
			const count = view.count ? view.count() : '';
			nav.append(h('button', { type: 'button', class: `nav-btn${id === active ? ' is-active' : ''}`, onClick: () => ctx.navigate(id) },
				h('span', { class: 'nav-icon', html: view.icon || '' }), h('span', {}, view.label), h('span', { class: 'nav-count' }, count)));
		}
	}
	const pack = C.getPack();
	nav.append(h('div', { class: 'nav-foot' }, h('span', {}, 'Pack ', h('b', {}, `${pack.pack || 'deep_cut'} v${pack.version ?? '?'}`)), h('span', {}, h('code', {}, 'content/deep_cut.json')),
		h('span', {}, 'Odds follow ', h('b', {}, 'sim/'), ' rules; sampled numbers are seeded and repeatable.')));
}

async function start() {
	try {
		const [packResponse, manifestResponse] = await Promise.all([fetch('data/deep_cut.json'), fetch('assets/manifest.json')]);
		if (!packResponse.ok) throw new Error(`content pack request failed (${packResponse.status})`);
		const pack = await packResponse.json();
		C.setPack(pack);
		if (manifestResponse.ok) setManifest(await manifestResponse.json());
		document.getElementById('pack-version').textContent = `v${pack.version ?? '?'}`;
		await Engine.start(pack);
		Engine.onBusy((n) => document.getElementById('busy').classList.toggle('is-on', n > 0));
		window.addEventListener('hashchange', render);
		render();
	} catch (error) {
		console.error(error);
		document.getElementById('content').replaceChildren(h('div', { class: 'error' }, h('b', {}, 'Could not load the content pack. '), String(error.message || error),
			h('p', {}, 'Start the server from the project root: ', h('code', {}, 'node tools/data-browser/server.mjs'))));
	}
}
start();
