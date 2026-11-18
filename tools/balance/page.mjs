// The balance runs' report as one page (tools/balance/delve.mjs writes it beside the runs:
// report.html to open from disk, report.page.html the same page without its wrapper, as a
// claude.ai artifact wants it). Everything on it is in the summary `analyze` makes; nothing is
// fetched. Tables are written out whole, so the page reads with scripts off; the script at the
// end only sorts and filters them.

import { CUTS, CLARITIES, GROUPS, inWords, short, times } from './analyze.mjs';

const esc = (v) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const ok = (v) => v !== null && v !== undefined && Number.isFinite(v);
const pct = (v, d = 0) => (ok(v) ? `${(v * 100).toFixed(d)}%` : '—');
const num = (v, d = 1) => (ok(v) ? v.toFixed(d) : '—');
const points = (v) => { if (!ok(v)) return '—'; const p = Math.round(v * 100); return p === 0 ? '0' : `${p > 0 ? '+' : '−'}${Math.abs(p)}`; };
const title = (key) => String(key).toLowerCase().replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
const kitWords = (kit) => (kit ? `${kit.carat} ct · ${CUTS[kit.cut] || ''} · ${CLARITIES[kit.clarity ?? 3] || ''}` : '');

// A share of a whole, as a bar and its figure.
const share = (v, d = 0) => (ok(v) ? `<span class="bar" title="${pct(v, 1)}"><i style="width:${Math.max(0, Math.min(1, v)) * 100}%"></i></span><b>${pct(v, d)}</b>` : '—');
// A difference either side of nought: `span` is the difference that fills half the track.
function swing(v, se, span = 0.3) {
	if (!ok(v)) return '—';
	const half = Math.min(1, Math.abs(v) / span) * 50;
	const side = v >= 0 ? `left:50%;width:${half}%` : `right:50%;width:${half}%`;
	return `<span class="swing ${v >= 0 ? 'up' : 'down'}" title="${points(v)} points${ok(se) ? `, give or take ${(se * 100).toFixed(0)}` : ''}"><i style="${side}"></i></span><b>${points(v)}</b>${ok(se) ? `<small>±${(se * 100).toFixed(0)}</small>` : ''}`;
}
// A difference as a figure alone.
const gap = (p) => (p && p.kits >= 2 && ok(p.progress) ? `${points(p.progress)}<small>±${(p.se * 100).toFixed(0)}</small>` : '<span class="quiet">—</span>');
// A cell of a grid, shaded by its share.
const heat = (v, label = pct(v)) => (ok(v) ? `<td class="heat${v >= 0.55 ? ' deep' : ''}" style="--v:${Math.round(Math.max(0, Math.min(1, v)) * 100)}%" data-v="${v}">${label}</td>` : '<td class="heat none" data-v="-1">—</td>');
const moved = (book, key, field, changes, unit = 100) => {
	const m = changes && changes[book] && changes[book][key];
	if (!m || !ok(m[field]) || Math.abs(m[field] * unit) < 0.5) return '';
	return `<span class="moved ${m[field] > 0 ? 'up' : 'down'}" title="since the run before">${m[field] > 0 ? '▲' : '▼'}${unit === 100 ? Math.abs(m[field] * unit).toFixed(0) : short(Math.abs(m[field] * unit))}</span>`;
};

// A flag's chip: a glyph and a word, so it never rests on its color.
const CHIPS = {
	delver: { over: ['▲', 'Strong'], under: ['▼', 'Weak'] },
	stone: { over: ['▲', 'Strong'], under: ['▼', 'Weak'] },
	sibling: { over: ['▲', 'Over its siblings'], under: ['▼', 'Under its siblings'] },
	gem: { over: ['▲', 'Strong'], under: ['▼', 'Weak'], outsized: ['◆', 'Outsized'], idle: ['◌', 'Rarely fires'], shunned: ['∅', 'Never chosen'] },
	warden: { over: ['▲', 'A wall'], under: ['▼', 'A walkover'] },
	creature: { over: ['▲', 'Dangerous'], under: ['▼', 'Harmless'] },
};
const chip = (f, tip = false) => {
	const [glyph, word] = (CHIPS[f.kind] || {})[f.way] || ['·', f.way];
	return `<span class="chip ${f.way}"${tip ? ` title="${esc(f.why)}"` : ''}><span aria-hidden="true">${glyph}</span> ${esc(word)}</span>`;
};
// A gem can stand out more than one way: its chips, the one that says most first.
const CHIP_ORDER = ['over', 'under', 'outsized', 'idle', 'shunned'];

export function page(s, changes = null, { standalone = false } = {}) {
	const mines = s.mines;
	const delverName = (c) => s.names.delvers[c] || c;
	const mineName = (m) => s.names.mines[m] || m;
	const meta = s.meta || {};
	const when = meta.created ? new Date(meta.created).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' }) : '';
	const heavy = s.heavy || 16;

	// --- what stands out ---
	// The one that stands furthest of each kind: where to start.
	const first = [['delver', 'Delver'], ['sibling', 'Birthstone'], ['gem', 'Gem'], ['warden', 'Warden'], ['creature', 'Creature']]
		.map(([kind, word]) => [word, s.flags.find((f) => f.kind === kind && (kind !== 'gem' || ['over', 'under', 'outsized'].includes(f.way)))])
		.filter(([, f]) => f);
	const start = first.length ? `<ol class="start">${first.map(([word, f]) => `<li><span class="kind">${word}</span><div><strong>${esc(f.name)}</strong> ${chip(f)}<p>${esc(f.why)}</p></div></li>`).join('')}</ol>` : '';
	const flagCards = GROUPS.map(([kind, name, how]) => {
		const of = s.flags.filter((f) => f.kind === kind);
		if (!of.length) return '';
		const rows = of.slice(0, 10).map((f) => `<li>${chip(f)}<div><strong>${esc(f.name)}</strong><p>${esc(f.why)}</p></div></li>`).join('');
		return `<section class="flags"><h3>${esc(name)} <small>${esc(how)}</small></h3><ul>${rows}</ul>${of.length > 10 ? `<p class="more">and ${of.length - 10} more, marked in the tables below</p>` : ''}</section>`;
	}).join('');

	// --- mines ---
	const mineRows = mines.map((m) => {
		const d = m.deaths || {};
		const fell = (d.fight || 0) + (d.elite || 0) + (d.warden || 0) + (d.boss || 0);
		const part = (n) => (fell ? `${Math.round(((n || 0) / fell) * 100)}%` : '—');
		return `<tr><th scope="row">${esc(m.name)}<small>${m.goal} floors</small></th><td class="l">${esc(m.kit && m.kit.name ? title(m.kit.name) : '')}<small>${num(m.stones, 1)} stones · ${esc(kitWords(m.kit))}</small></td><td>${m.runs}</td>
<td class="meter">${share(m.clear)}${moved('mines', m.key, 'clear', changes)}</td><td class="meter">${share(m.progress)}</td><td>${num(m.fights)}</td>
<td>${part(d.fight)}</td><td>${part(d.elite)}</td><td>${part(d.warden)}</td><td>${part(d.boss)}</td>
<td class="l wrap">${m.killers.slice(0, 4).map((k) => `${esc(k.name)} <small>${k.n}</small>`).join(' · ')}</td></tr>`;
	}).join('');

	// --- Wardens ---
	const flaggedWardens = new Map(s.flags.filter((f) => f.kind === 'warden').map((f) => [f.key, f]));
	const wardenRows = s.wardens.map((w) => {
		const f = flaggedWardens.get(`${w.mine}|${w.key}`);
		return `<tr><th scope="row">${esc(w.name)}<small>${esc(mineName(w.mine))} · ${w.kind === 'boss' ? 'boss' : 'Warden'} · depth ${w.depth}</small></th><td class="l">${f ? chip(f, true) : ''}</td>
<td>${w.n}</td><td>${pct(w.reached)}</td><td class="meter">${share(w.won)}${moved('wardens', `${w.mine}|${w.key}|${w.kind}`, 'won', changes)}</td><td>${num(w.turns)}</td><td>${pct(w.hurt)}</td><td>${pct(w.back)}</td>
${s.delvers.map((d) => { const by = w.byDelver[d.key]; return by && by[0] >= 3 ? heat(by[1]) : '<td class="heat none">—</td>'; }).join('')}</tr>`;
	}).join('');
	const delverHeads = s.delvers.map((d) => `<th title="beaten by ${esc(d.name)}">${esc(d.name)}</th>`).join('');

	// --- Birthstones ---
	const stoneCols = 7 + mines.length;
	const flaggedStones = new Map();
	for (const f of s.flags.filter((x) => x.kind === 'sibling' || x.kind === 'stone')) if (!flaggedStones.has(f.key) || f.kind === 'sibling') flaggedStones.set(f.key, f);
	const stoneRows = s.stones.map((st, i) => {
		const opens = i === 0 || s.stones[i - 1].delver !== st.delver;
		const d = s.delvers.find((x) => x.key === st.delver) || {};
		const lead = opens ? `<tr class="group"><th scope="rowgroup" colspan="${stoneCols}">${esc(delverName(st.delver))} <small>all three stones: ${pct(d.clear)} clear, ${points(d.edge)} points against the middle stone${ok(d.edgeSe) ? ` (±${Math.max(1, Math.round(d.edgeSe * 100))})` : ''}</small></th></tr>` : '';
		const tiers = st.tiers.map((t) => `${esc(t.name)} <b>${num(t.rate, 2)}</b>`).join(' · ');
		return `${lead}<tr class="main"><th scope="row" rowspan="2">${esc(st.name)}<small>${st.key ? `${st.price.toLocaleString('en-GB')} gold` : 'first stone'}</small></th><td>${st.runs}</td>
<td class="meter">${share(st.clear)}</td><td class="meter">${swing(st.edge, st.edgeSe)}${moved('stones', `${st.delver}|${st.key}`, 'edge', changes)}</td>
<td class="meter">${st.within ? swing(st.within.progress, st.within.se) : '—'}</td>
<td>${num(st.fires, 2)}</td><td>${pct(st.share)}</td>${mines.map((m) => heat(st.byMine[m.key] ? st.byMine[m.key].clear : null)).join('')}</tr>
<tr class="sub"><td colspan="${stoneCols - 1}" class="l wrap tiers">Lit, a turn: ${tiers}${st.cost > 0.001 ? ` · costs its delver <b>${pct(st.cost, 1)}</b> of a health bar a fight` : ''}</td></tr>`;
	}).join('');

	// --- gems ---
	const rarities = ['COMMON', 'UNCOMMON', 'RARE', 'LEGENDARY', 'MYTHIC', 'TRANSCENDENT'];
	const flaggedGems = new Map();
	for (const f of s.flags.filter((x) => x.kind === 'gem')) { if (!flaggedGems.has(f.key)) flaggedGems.set(f.key, []); flaggedGems.get(f.key).push(f); }
	const gemRows = s.gems.slice().sort((a, b) => rarities.indexOf(a.rarity) - rarities.indexOf(b.rarity) || (b.plant.progress ?? -9) - (a.plant.progress ?? -9)).map((g) => {
		const fs = (flaggedGems.get(g.key) || []).slice().sort((a, b) => CHIP_ORDER.indexOf(a.way) - CHIP_ORDER.indexOf(b.way));
		const did = `${inWords(g.rail.damage)} damage, ${inWords(g.rail.block)} block, ${inWords(g.rail.healed)} healing, ${inWords(g.rail.debuffs)} Poison and the like, a turn${g.rail.cost > 0.05 ? `; it costs its owner ${num(g.rail.cost)} health a turn` : ''}`;
		return `<tr data-name="${esc(g.name.toLowerCase())}" data-rarity="${g.rarity}" data-color="${g.color}" data-flag="${fs.map((f) => f.way).join(' ')}">
<th scope="row" data-v="${esc(g.name)}"><i class="dot ${g.color.toLowerCase()}" aria-hidden="true"></i>${esc(g.name)}<small>${esc(g.color.toLowerCase())} · ${esc(g.rarity.toLowerCase())}</small></th>
<td class="l chips" data-v="${fs.length ? CHIP_ORDER.indexOf(fs[0].way) : 9}">${fs.map((f) => chip(f, true)).join(' ')}</td>
<td class="meter" data-v="${g.plant.kits >= 2 ? g.plant.progress : -9}">${g.plant.kits >= 2 ? swing(g.plant.progress, g.plant.se) : '<span class="quiet">too few</span>'}</td><td data-v="${g.plant.kits}">${g.plant.kits}</td>
<td data-v="${g.plant.light.kits >= 2 ? g.plant.light.progress : -9}" title="${g.plant.light.kits} kits under ${heavy} carats">${gap(g.plant.light)}</td>
<td data-v="${g.plant.heavy.kits >= 2 ? g.plant.heavy.progress : -9}" title="${g.plant.heavy.kits} kits of ${heavy} carats and up">${gap(g.plant.heavy)}</td>
<td data-v="${g.pick.rate ?? -1}" title="${g.pick.vault} vaults">${pct(g.pick.rate)}</td><td data-v="${g.loot.rate ?? -1}" title="offered ${g.loot.offered} times">${pct(g.loot.rate)}</td>
<td data-v="${g.rail.turns}">${g.rail.turns.toLocaleString('en-GB')}</td><td data-v="${g.rail.fires ?? -1}">${g.rail.turns ? num(g.rail.fires, 2) : '—'}</td>
<td data-v="${g.rail.power ?? -1}" title="${esc(did)}">${g.rail.turns ? short(g.rail.power) : '—'}${moved('gems', g.key, 'power', changes, 1)}</td>
<td data-v="${g.rail.ratio ?? -1}" title="${num(g.rail.flat, 2)} a turn at one carat; the middle ${esc(g.rarity.toLowerCase())} gem that does anything does ${num(g.rail.peers, 2)}">${ok(g.rail.ratio) ? times(g.rail.ratio) : '—'}</td></tr>`;
	}).join('');
	const colors = [...new Set(s.gems.map((g) => g.color))].filter(Boolean);

	// --- creatures ---
	const flaggedBeasts = new Map(s.flags.filter((f) => f.kind === 'creature').map((f) => [f.key, f]));
	const most = Math.max(0.01, ...s.creatures.filter((c) => !c.warden).map((c) => c.hurt || 0));
	const creatureRows = mines.map((m) => {
		const of = s.creatures.filter((c) => c.mine === m.key && !c.warden).sort((a, b) => (b.hurt ?? 0) - (a.hurt ?? 0));
		if (!of.length) return '';
		return `<tr class="group"><th scope="rowgroup" colspan="9">${esc(m.name)}</th></tr>` + of.map((c) => {
			const f = flaggedBeasts.get(c.key);
			return `<tr><th scope="row">${esc(c.name)}<small>around depth ${num(c.depth, 0)}</small></th><td class="l">${f ? chip(f, true) : ''}</td>
<td>${c.stood.toLocaleString('en-GB')}</td><td class="meter"><span class="bar" title="${pct(c.hurt, 1)} of the bot's health a fight"><i style="width:${Math.min(1, (c.hurt || 0) / most) * 100}%"></i></span><b>${pct(c.hurt, 1)}</b>${moved('creatures', c.key, 'hurt', changes)}</td>
<td>${ok(c.hurtX) ? `${c.hurtX.toFixed(1)}×` : '—'}</td><td>${num(c.turns)}</td><td>${num(c.hurtAct)}</td><td>${num(c.blockedAct)}</td><td>${c.kills}</td></tr>`;
		}).join('');
	}).join('');

	const kits = mines.map((m) => `<li><b>${esc(m.name)}</b> ${esc(m.kit && m.kit.name ? title(m.kit.name) : 'kit')}: ${num(m.stones, 1)} stones, ${esc(kitWords(m.kit))}</li>`).join('');

	const body = `<title>Deep Cut Balance Runs</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<style>
/* Layout: one column a table wide; a sticky strip of section names; where to start, then what stands out, then the tables it came from. */
:root {
	--ground: #f4f5f7; --surface: #fcfcfd; --sunk: #eceef2; --rule: #d9dce3; --ink: #14171c; --ink-2: #4b5260; --ink-3: #7a8191;
	--up: #2a78d6; --down: #d6453f; --seq: #2a78d6; --seq-ink: #ffffff;
	--red: #d6453f; --blue: #2a78d6; --green: #2e9a4a; --violet: #7a56d6; --gold: #c9930a; --white: #aeb4c2; --opal: #2bb3b0;
	--display: "Barlow Condensed", "Arial Narrow", "Roboto Condensed", sans-serif;
	--text: "IBM Plex Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
	--ground: #101216; --surface: #171a20; --sunk: #20242c; --rule: #2d323c; --ink: #eceef2; --ink-2: #b4bac6; --ink-3: #868d9b;
	--up: #4a93ea; --down: #e25c55; --seq: #3987e5; --seq-ink: #ffffff;
	--red: #e25c55; --blue: #4a93ea; --green: #49b565; --violet: #9a80ea; --gold: #d9a520; --white: #c9ceda; --opal: #3cc7c3; color-scheme: dark } }
:root[data-theme="dark"] {
	--ground: #101216; --surface: #171a20; --sunk: #20242c; --rule: #2d323c; --ink: #eceef2; --ink-2: #b4bac6; --ink-3: #868d9b;
	--up: #4a93ea; --down: #e25c55; --seq: #3987e5; --seq-ink: #ffffff;
	--red: #e25c55; --blue: #4a93ea; --green: #49b565; --violet: #9a80ea; --gold: #d9a520; --white: #c9ceda; --opal: #3cc7c3; color-scheme: dark }
body { background: var(--ground); color: var(--ink); font: 400 14px/1.45 var(--text); font-variant-numeric: tabular-nums; }
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--ground); }
.sheet { max-width: 1240px; margin: 0 auto; padding-block: 28px 64px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); display: flex; flex-direction: column; gap: 36px; }
section { min-width: 0; scroll-margin-top: 56px; }
header h1 { font: 600 44px/1 var(--display); letter-spacing: 0.01em; margin: 0 0 8px; text-wrap: balance; }
header p { margin: 0; color: var(--ink-2); max-width: 72ch; }
header .facts { display: flex; flex-wrap: wrap; gap: 6px 18px; margin-top: 12px; color: var(--ink-3); font-size: 13px; }
header .facts b { color: var(--ink); font-weight: 500; }
nav { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--ground); border-bottom: 1px solid var(--rule); display: flex; gap: 4px 18px; flex-wrap: wrap; padding-block: 10px; margin-block: -12px; }
nav a { font: 600 15px/1 var(--display); letter-spacing: 0.06em; text-transform: uppercase; color: var(--ink-2); text-decoration: none; padding: 4px 0; border-bottom: 2px solid transparent; }
nav a:hover, nav a:focus-visible { color: var(--ink); border-bottom-color: var(--ink); outline: none; }
h2 { font: 600 26px/1.1 var(--display); letter-spacing: 0.02em; margin: 0 0 4px; }
h2 + p, .how { margin: 0 0 14px; color: var(--ink-2); max-width: 78ch; }
h3 { font: 600 17px/1.2 var(--display); letter-spacing: 0.05em; text-transform: uppercase; margin: 0 0 10px; }
h3 small { font: 400 13px/1.2 var(--text); letter-spacing: 0; text-transform: none; color: var(--ink-3); margin-left: 6px; }
small { color: var(--ink-3); font-size: 12px; }
.start { list-style: none; counter-reset: start; margin: 0 0 14px; padding: 6px 16px; background: var(--surface); border: 1px solid var(--rule); border-left: 4px solid var(--ink); border-radius: 6px; }
.start li { counter-increment: start; display: grid; grid-template-columns: 26px 84px 1fr; gap: 10px; align-items: baseline; padding: 10px 0; border-bottom: 1px solid var(--rule); }
.start li:last-child { border-bottom: 0; }
.start li::before { content: counter(start); font: 600 22px/1 var(--display); color: var(--ink-3); }
.start .kind { font: 600 13px/1.2 var(--display); letter-spacing: 0.06em; text-transform: uppercase; color: var(--ink-3); }
.start strong { font-size: 15px; margin-right: 8px; }
.start p { margin: 3px 0 0; color: var(--ink-2); max-width: 86ch; }
.standout { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 14px; }
.flags { background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; padding: 16px 16px 12px; min-width: 0; }
.flags ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 10px; }
.flags li { display: grid; grid-template-columns: 136px 1fr; gap: 10px; align-items: start; }
.flags li .chip { justify-self: start; }
.flags li p { margin: 2px 0 0; color: var(--ink-2); font-size: 13px; }
.flags .more { margin: 10px 0 0; color: var(--ink-3); font-size: 13px; }
.none-out { background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; padding: 16px; color: var(--ink-2); }
.chip { display: inline-flex; align-items: center; gap: 5px; font: 600 13px/1 var(--display); letter-spacing: 0.05em; text-transform: uppercase; padding: 4px 7px 3px; border-radius: 3px; border: 1px solid var(--rule); color: var(--ink-2); background: var(--sunk); white-space: nowrap; }
.chip.over { border-color: var(--up); color: var(--up); background: transparent; }
.chip.under { border-color: var(--down); color: var(--down); background: transparent; }
.chip.outsized { border-color: var(--ink-2); color: var(--ink); background: transparent; }
.scroll { overflow-x: auto; background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { padding: 7px 10px; text-align: right; white-space: nowrap; border-bottom: 1px solid var(--rule); vertical-align: middle; }
thead th { font: 600 13px/1.15 var(--display); letter-spacing: 0.06em; text-transform: uppercase; color: var(--ink-2); background: var(--sunk); border-bottom: 1px solid var(--rule); vertical-align: bottom; position: relative; }
thead th.over { text-align: center; border-bottom-color: var(--ink-3); }
thead th[data-sort] { cursor: pointer; user-select: none; }
thead th[data-sort]:hover, thead th[data-sort]:focus-visible { color: var(--ink); outline: none; }
thead th[aria-sort="ascending"]::after { content: " ▲"; font-size: 9px; }
thead th[aria-sort="descending"]::after { content: " ▼"; font-size: 9px; }
tbody th { text-align: left; font-weight: 500; }
tbody th small, td small { display: block; font-weight: 400; }
td.l, th.l { text-align: left; }
td.wrap { white-space: normal; min-width: 200px; color: var(--ink-2); }
td.wrap small { display: inline; }
td.chips { white-space: normal; min-width: 120px; }
td.chips .chip { margin: 1px 0; }
td.tiers b { color: var(--ink); font-weight: 500; }
tbody tr:hover > * { background: var(--sunk); }
tr.group th { font: 600 15px/1.2 var(--display); letter-spacing: 0.06em; text-transform: uppercase; background: var(--ground); padding-top: 14px; }
tr.group th small { display: inline; font: 400 12px var(--text); letter-spacing: 0; text-transform: none; margin-left: 8px; }
tr.main > td { border-bottom: 0; padding-bottom: 3px; }
tr.sub > td { padding-top: 0; font-size: 12px; }
tbody tr:last-child > * { border-bottom: 0; }
td.meter { text-align: left; }
td.meter b { font-weight: 500; display: inline-block; min-width: 3.2ch; text-align: right; margin-left: 8px; }
td.meter small, td > small:only-of-type { display: inline; margin-left: 4px; }
.bar, .swing { display: inline-block; vertical-align: middle; height: 8px; background: var(--sunk); border-radius: 2px; position: relative; overflow: hidden; }
.bar { width: 72px; }
.bar i { position: absolute; inset: 0 auto 0 0; background: var(--seq); border-radius: 2px; }
.swing { width: 84px; }
.swing::after { content: ""; position: absolute; left: 50%; top: 0; bottom: 0; width: 1px; background: var(--ink-3); }
.swing i { position: absolute; top: 0; bottom: 0; }
.swing.up i { background: var(--up); border-radius: 0 2px 2px 0; }
.swing.down i { background: var(--down); border-radius: 2px 0 0 2px; }
tbody tr:hover .bar, tbody tr:hover .swing { background: var(--rule); }
td.heat { text-align: center; min-width: 46px; background: color-mix(in srgb, var(--seq) var(--v), var(--surface)); border-left: 2px solid var(--surface); }
td.heat.deep { color: var(--seq-ink); }
td.heat.none { background: transparent; color: var(--ink-3); }
tbody tr:hover > td.heat:not(.none) { background: color-mix(in srgb, var(--seq) var(--v), var(--surface)); }
.moved { font-size: 11px; margin-left: 6px; color: var(--ink-3); }
.quiet { color: var(--ink-3); }
.dot { display: inline-block; width: 9px; height: 9px; border-radius: 2px; transform: rotate(45deg); margin: 0 8px 1px 2px; background: var(--white); }
.dot.red { background: var(--red); } .dot.blue { background: var(--blue); } .dot.green { background: var(--green); } .dot.violet { background: var(--violet); }
.dot.gold { background: var(--gold); } .dot.opal { background: var(--opal); }
.filters { display: flex; flex-wrap: wrap; gap: 8px 12px; align-items: center; margin-bottom: 10px; }
.filters input[type="search"], .filters select { font: inherit; color: var(--ink); background: var(--surface); border: 1px solid var(--rule); border-radius: 4px; padding: 6px 8px; min-width: 0; }
.filters input[type="search"] { width: min(240px, 100%); }
.filters label { display: inline-flex; gap: 6px; align-items: center; color: var(--ink-2); }
.filters output { color: var(--ink-3); margin-left: auto; }
:is(input, select):focus-visible { outline: 2px solid var(--up); outline-offset: 1px; }
details { background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; padding: 12px 16px; }
details + details { margin-top: 10px; }
details summary { cursor: pointer; font-weight: 500; }
details ul { margin: 10px 0 0; padding-left: 18px; color: var(--ink-2); max-width: 82ch; display: flex; flex-direction: column; gap: 6px; }
.kits { list-style: none; padding: 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 4px 18px; max-width: none; }
.kits b { color: var(--ink); font-weight: 500; }
@media (max-width: 560px) { header h1 { font-size: 34px; } .flags li { grid-template-columns: 1fr; gap: 4px; } .start li { grid-template-columns: 22px 1fr; } .start .kind { grid-column: 2; } .start li > div { grid-column: 2; } }
</style>
<div class="sheet">
<header>
<h1>Deep Cut Balance Runs</h1>
<p>${s.runs.toLocaleString('en-GB')} whole runs played through the game's own rules by a bot: every Birthstone of every delver down every mine, each on the same seeds${s.gemRuns ? `, and ${s.gemRuns.toLocaleString('en-GB')} more for the gems alone` : ''}. What follows is what those runs say needs a second look.</p>
<div class="facts"><span>Played <b>${esc(when)}</b></span><span>Pack <b>${esc(meta.packHash || '?')}</b></span><span><b>${esc(String(meta.seconds ?? '?'))} s</b> on ${esc(String(meta.workers ?? '?'))} workers</span>${s.broken ? `<span><b>${s.broken}</b> runs never finished and are left out</span>` : ''}${changes ? `<span>▲▼ what moved since the run before${changes.same === false ? ' (played with other kits)' : ''}</span>` : ''}</div>
</header>
<nav aria-label="Sections"><a href="#standout">What stands out</a><a href="#mines">Mines</a><a href="#wardens">Wardens</a><a href="#birthstones">Birthstones</a><a href="#gems">Gems</a><a href="#creatures">Creatures</a><a href="#reading">Reading it</a></nav>

<section id="standout">
<h2>What stands out</h2>
<p>Whatever sits further from its peers than chance would put it: two standard errors, and a difference big enough to act on. Each line carries the numbers that put it here. The list on top is the one that stands furthest of each kind.</p>
${start}
${flagCards ? `<div class="standout">${flagCards}</div>` : '<div class="none-out">Nothing stands further from its peers than chance would put it. More seeds read finer.</div>'}
</section>

<section id="mines">
<h2>Mines</h2>
<p>Clear is the share of runs that beat the mine's boss. Progress is the share of its floors a run left behind, the boss counted. The four columns after say where the runs that fell, fell.</p>
<div class="scroll"><table>
<thead><tr><th class="l" rowspan="2">Mine</th><th class="l" rowspan="2">Kit</th><th rowspan="2">Runs</th><th class="l" rowspan="2">Clear</th><th class="l" rowspan="2">Progress</th><th rowspan="2">Fights</th><th class="over" colspan="4">Where runs fell</th><th class="l" rowspan="2">What ended most</th></tr>
<tr><th>Fight</th><th>Elite</th><th>Warden</th><th>Boss</th></tr></thead>
<tbody>${mineRows}</tbody></table></div>
</section>

<section id="wardens">
<h2>Wardens and bosses</h2>
<p>Met is how many runs reached it. Health lost is what the fight cost, as a share of a full health bar (it can pass 100%: healing counts). Thrown back is the part of that the creature sent back for blows it was dealt. The grid is how often each delver beat it.</p>
<div class="scroll"><table>
<thead><tr><th class="l">Creature</th><th class="l">Stands out</th><th>Met</th><th>Reached by</th><th class="l">Beaten</th><th>Turns</th><th>Health lost</th><th>Thrown back</th>${delverHeads}</tr></thead>
<tbody>${wardenRows}</tbody></table></div>
</section>

<section id="birthstones">
<h2>Birthstones</h2>
<p>Edge is progress over the middle stone in the same mines, in points. Against its siblings is the stone beside its delver's other two on the same seeds: the same shaft and the same vault to choose a rail from, so it reads finer than the edge. Fires is how often any tier lit, a turn; damage is the stone's share of all the delver dealt. The grid is clear, mine by mine.</p>
<div class="scroll"><table>
<thead><tr><th class="l">Stone</th><th>Runs</th><th class="l">Clear</th><th class="l">Edge</th><th class="l">Against its siblings</th><th>Fires</th><th>Damage</th>${mines.map((m) => `<th title="${esc(m.name)}">${esc(m.name.replace(/^The /, ''))}</th>`).join('')}</tr></thead>
<tbody>${stoneRows}</tbody></table></div>
</section>

<section id="gems">
<h2>Gems</h2>
<p>Planted is the one clean reading: every run sets one stone of its vault on the rail whatever the bot thinks of it, and those runs are set against the others of the same delver, stone and mine. Light and heavy split that by the kit: under ${heavy} carats, and from ${heavy} up. Chosen is how often the bot set it when it lay in the vault unplanted; taken, how often it took it when the mine offered it. Fires a turn counts a replay, so it can pass one. Did a turn is what it did for each turn it sat on a rail (damage, 0.7 a point of block, 0.8 of healing, 1.5 a debuff); against peers is that at one carat beside the middle gem of its rarity that does anything a tally shows.</p>
<div class="filters">
<input type="search" id="gem-search" placeholder="Find a gem" aria-label="Find a gem">
<select id="gem-rarity" aria-label="Rarity"><option value="">Every rarity</option>${rarities.filter((r) => s.gems.some((g) => g.rarity === r)).map((r) => `<option value="${r}">${title(r)}</option>`).join('')}</select>
<select id="gem-color" aria-label="Color"><option value="">Every color</option>${colors.map((c) => `<option value="${c}">${title(c)}</option>`).join('')}</select>
<label><input type="checkbox" id="gem-flagged"> Only what stands out</label>
<output id="gem-count" for="gem-search gem-rarity gem-color gem-flagged"></output>
</div>
<div class="scroll"><table id="gem-table">
<thead><tr><th class="l" data-sort="text" tabindex="0">Gem</th><th class="l" data-sort="num" tabindex="0">Stands out</th><th class="l" data-sort="num" tabindex="0">Planted</th><th data-sort="num" tabindex="0">Kits</th><th data-sort="num" tabindex="0">Light kits</th><th data-sort="num" tabindex="0">Heavy kits</th><th data-sort="num" tabindex="0">Chosen</th><th data-sort="num" tabindex="0">Taken</th><th data-sort="num" tabindex="0">Turns set</th><th data-sort="num" tabindex="0" title="times it fired for each turn it sat on a rail; a replay counts">Fires a turn</th><th data-sort="num" tabindex="0" title="what it did for each turn it sat on a rail">Did a turn</th><th data-sort="num" tabindex="0">Against peers</th></tr></thead>
<tbody>${gemRows}</tbody></table></div>
</section>

<section id="creatures">
<h2>Creatures</h2>
<p>Hurt is the health one of them took off the bot in a fight, as a share of the bot's health; the figure after it sets that against the middle creature of the same mine. Stood is how many turns it lasted. A blow and Stopped are what one of its actions took and what block stopped. Ended is the runs it finished.</p>
<div class="scroll"><table>
<thead><tr><th class="l">Creature</th><th class="l">Stands out</th><th>Met</th><th class="l">Hurt</th><th>Against its mine</th><th>Stood</th><th>A blow</th><th>Stopped</th><th>Ended</th></tr></thead>
<tbody>${creatureRows}</tbody></table></div>
</section>

<section id="reading">
<h2>Reading it</h2>
<details open><summary>What the bot is, and what it cannot tell you</summary>
<ul>
<li>It plays the real game: every move is one a player could make, and every number comes out of the rules that run a fight. It weighs a hand, a reroll or a stone by playing it out a turn ahead.</li>
<li>It looks one turn ahead and no further. It does not plan a fight, save for a Warden or build toward a combination it has not been dealt, so a gem that needs a partner is only worth to it what the rail in front of it makes of it.</li>
<li>It leaves the smithy, the carver, the altar and the gambling cards alone, so every delver throws the dice they were made with and no Transcendent gem is ever made.</li>
<li>It hoards pyrite: it buys a stone only when the rail gains by it, and never spends a purse down. Whatever reads the purse (the Assayer's Tax and Eat the Rich, Gilded Armor) sees a fuller one than a player would bring, so read those with that in mind.</li>
<li>Read every number against its neighbours, not on its own. The same bot plays every stone, gem and creature, so what one does beside another is the game's; how far the bot gets at all is partly the bot's.</li>
<li>Each mine is played with the kit below: the lightest at which the first stones beat its boss about four times in ten. A mine nobody beats is played with the heaviest kit there is, and that it takes one is the finding.</li>
</ul></details>
<details><summary>The kit each mine was played with</summary><ul class="kits">${kits}</ul></details>
</section>
</div>
<script>
(() => {
	const table = document.getElementById('gem-table');
	if (!table) return;
	const body = table.tBodies[0];
	const rows = Array.from(body.rows);
	const heads = Array.from(table.tHead.rows[0].cells);
	const sortBy = (at, numeric, down) => {
		const key = (row) => { const v = row.cells[at].dataset.v ?? row.cells[at].textContent; return numeric ? Number(v) : String(v).toLowerCase(); };
		rows.sort((a, b) => { const x = key(a), y = key(b); return (x < y ? -1 : x > y ? 1 : 0) * (down ? -1 : 1); });
		rows.forEach((row) => body.appendChild(row));
	};
	heads.forEach((th, at) => {
		if (!th.dataset.sort) return;
		const go = () => {
			const numeric = th.dataset.sort === 'num';
			const down = th.getAttribute('aria-sort') ? th.getAttribute('aria-sort') === 'ascending' : numeric && at !== 1;
			heads.forEach((h) => h.removeAttribute('aria-sort'));
			th.setAttribute('aria-sort', down ? 'descending' : 'ascending');
			sortBy(at, numeric, down);
		};
		th.addEventListener('click', go);
		th.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); } });
	});
	const search = document.getElementById('gem-search');
	const rarity = document.getElementById('gem-rarity');
	const color = document.getElementById('gem-color');
	const flagged = document.getElementById('gem-flagged');
	const count = document.getElementById('gem-count');
	const filter = () => {
		const q = search.value.trim().toLowerCase();
		let shown = 0;
		rows.forEach((row) => {
			const show = (!q || row.dataset.name.includes(q)) && (!rarity.value || row.dataset.rarity === rarity.value) && (!color.value || row.dataset.color === color.value) && (!flagged.checked || row.dataset.flag);
			row.hidden = !show;
			if (show) shown += 1;
		});
		count.textContent = shown + ' of ' + rows.length + ' gems';
	};
	[search, rarity, color, flagged].forEach((el) => el.addEventListener('input', filter));
	filter();
})();
</script>`;
	if (!standalone) return body;
	return `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n</head>\n<body style="margin:0">\n${body}\n</body>\n</html>\n`;
}
