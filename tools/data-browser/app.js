const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const title = (value) => String(value ?? '').toLowerCase().split(/[_\s]+/).filter(Boolean).map((word) => word[0].toUpperCase() + word.slice(1)).join(' ');
const fmt = (value, places = 1) => Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: places });
let pack;
let current = 'overview';
const selected = {};
const navItems = [['overview','Overview',''],['skills','Skill gems','skills'],['lapidaries','Lapidaries','characters'],['inclusions','Inclusions','inclusions'],['rooms','Rooms & mines','mines'],['enemies','Enemies','creatures'],['dice','Dice & rolls','dice'],['luck','Stone luck',''],['rules','Boons & rules','boons']];

function records(section) { return Object.entries(pack[section] || {}).sort(([a],[b]) => a.localeCompare(b)); }
function color(key) { return `#${pack.colors?.[key]?.hue || '9aa59a'}`; }
function options(section, chosen, label = (key, item) => item.name || title(key)) {
	return records(section).map(([key,item]) => `<option value="${esc(key)}" ${key === chosen ? 'selected' : ''}>${esc(label(key,item))}</option>`).join('');
}
function field(id, label, content) { return `<div class="field"><label for="${id}">${label}</label>${content}</div>`; }
function picker(id, label, section, chosen, labelFn) { return field(id,label,`<select id="${id}">${options(section,chosen,labelFn)}</select>`); }
function panel(label, body, meta = '') { return `<section class="panel"><div class="panel-title"><span>${label}</span>${meta ? `<small>${meta}</small>` : ''}</div>${body}</section>`; }
function metric(label, value, note = '') { return `<div class="metric"><div class="metric-label">${esc(label)}</div><div class="metric-value">${esc(value)}</div>${note ? `<div class="metric-note">${esc(note)}</div>` : ''}</div>`; }
function head(kicker, titleText, copy, tools = '') { return `<div class="view-head"><div><p class="eyebrow">${kicker}</p><h1>${titleText}</h1><p class="subtitle">${copy}</p></div>${tools ? `<div class="head-tools">${tools}</div>` : ''}</div>`; }
function bar(label, pct, max = 100) { return `<div class="bar-row"><span class="bar-label">${esc(label)}</span><div class="bar-track"><div class="bar-fill" style="width:${Math.max(pct > 0 ? 1 : 0,pct / max * 100)}%"></div></div><span class="bar-value">${fmt(pct,2)}%</span></div>`; }
function triggerText(trigger = {}) {
	const kind = trigger.kind || 'always';
	if (kind === 'always') return 'Every hand';
	if (kind === 'odd' || kind === 'even') return `${title(kind)} roll`;
	if (kind === 'value') return `Roll ${(trigger.values || []).join(' / ')}`;
	if (kind === 'at_least') return `At least ${trigger.amount ?? '?'}`;
	if (kind === 'at_most') return `At most ${trigger.amount ?? '?'}`;
	return title(kind.replaceAll('_',' '));
}
function amountText(value) {
	if (typeof value === 'number') return String(value);
	if (!value || typeof value !== 'object') return '0';
	if (value.term) return title(value.term);
	if (value.const !== undefined) return String(value.const);
	return (value.args || []).map(amountText).join(` ${value.op || '+'} `);
}
function effectText(effect = {}) {
	const amount = amountText(effect.amount);
	const labels = {damage:`${amount} damage`,block:`${amount} block`,heal:`Heal ${amount}`,poison:`${amount} Poison`,stun:`Stun ${amount}`,curse:`${amount} Curse`,die_steal:`Suppress ${amount} die`,ward:`${amount} Ward`,marked:`${amount} Marked`,dulled:`${amount} Dulled`,retain:`Retain ${amount} block`,charged:`${amount} starting Resonance`,regeneration:`${amount} Regeneration`,spikes:`${amount} Spikes`,dice_upgrade:`Dice +${amount} tier`,dice_dread:`${amount} Dread`,remove_block:`Remove ${amount} block`,clouded:'Cloud a socket'};
	return labels[effect.kind] || `${title(effect.kind)} ${amount}`;
}
function buildNavigation() {
	$('#navigation').innerHTML = navItems.map(([id,label,section],i) => `<button class="nav-button ${current === id ? 'active' : ''}" data-view="${id}"><span class="nav-number">0${i+1}</span><span>${label}</span><span class="nav-count">${section ? records(section).length : ''}</span></button>`).join('');
	$$('.nav-button').forEach((button) => button.addEventListener('click', () => render(button.dataset.view)));
	$('#mobile-section').innerHTML = navItems.map(([id,label]) => `<option value="${id}" ${id===current?'selected':''}>${label}</option>`).join('');
	$('#mobile-section').addEventListener('change', (event) => render(event.target.value));
}
function defaultKey(view) {
	const section = ({skills:'skills',lapidaries:'characters',inclusions:'inclusions',rooms:'mines',enemies:'creatures',dice:'dice',luck:'mines',rules:'boons'})[view];
	return section ? records(section)[0]?.[0] || '' : '';
}
function render(viewName = current) {
	current = viewName;
	if (selected[current] === undefined) selected[current] = defaultKey(current);
	buildNavigation();
	$('#crumb-current').textContent = navItems.find(([id]) => id === current)?.[1].toUpperCase() || 'OVERVIEW';
	const builders = {overview:overviewView,skills:skillsView,lapidaries:lapidaryView,inclusions:inclusionView,rooms:roomView,enemies:enemyView,dice:diceView,luck:luckView,rules:rulesView};
	$('#app').innerHTML = builders[current]();
	wire();
}

function overviewView() {
	const c = pack.constants || {};
	const counts = [['Skill gems','skills'],['Lapidaries','characters'],['Inclusions','inclusions'],['Dice definitions','dice'],['Creatures','creatures'],['Mines','mines']];
	return `${head('The reference desk','Field guide','A working index of the content pack, mine tables and the rules that shape a run.')}
	<div class="overview-grid"><section class="panel overview-art"><div><p class="eyebrow">${esc(pack.pack)} / VERSION ${esc(pack.version)}</p><h2>Everything the rock can give you.</h2><p>Browse written content and inspect the math behind its rolls. Tables are read from the live pack; calculated odds follow simulation rules.</p></div><div class="overview-meta"><span>RUN DEPTH <b>${c.run_depth ?? '—'}</b></span><span>WARDENS <b>${(c.warden_depths || []).join(' · ')}</b></span><span>REROLLS <b>${c.rerolls ?? '—'}</b></span></div></section><div class="count-grid">${counts.map(([label,section]) => `<div class="count-card"><strong>${records(section).length}</strong><span>${label.toUpperCase()}</span></div>`).join('')}</div></div>
	<div class="grid-2" style="margin-top:14px"><div>${panel('The four C’s',`<div class="cards" style="padding:10px">${[['Color','Sets domain and cut shape.'],['Carat','Scales magnitude; ramps at 20.'],['Cut','Changes the trigger ladder.'],['Clarity','Sets inclusions and special lines.']].map(([a,b])=>`<div class="mini-card"><strong>${a}</strong><p>${b}</p></div>`).join('')}</div>`)}</div><div>${panel('Run constants',`<div style="padding:3px 13px">${[['Carat cap',c.carat_max],['Landing cadence',c.landing_every],['Depth HP scale',`${fmt((c.depth_hp_scale||0)*100,0)}% / floor`],['Fight stone drop',`${c.stone_drop_pct?.fight ?? '—'}%`],['Elite stone drop',`${c.stone_drop_pct?.elite ?? '—'}%`]].map(([a,b])=>`<div class="split-line"><span>${a}</span><b>${b ?? '—'}</b></div>`).join('')}</div>`)}</div></div>`;
}

function skillsView() {
	const key = selected.skills;
	const def = pack.skills[key] || {};
	const pane = selected.skillPane || 'scaling';
	const cuts = pack.cuts || [];
	const ladder = def.trigger?.ladder || [];
	const read = (def.trigger?.read || []).map(title).join(' / ') || '—';
	const tabs=`<div class="segmented">${[['scaling','Scaling'],['effects','Effects']].map(([id,label])=>`<button class="segment ${pane===id?'active':''}" data-pane="${id}">${label}</button>`).join('')}</div>`;
	const scaling=`<div class="section-label">Cut scaling · trigger ladder</div><div class="rank-row"><div class="rank-head row-label">Rank</div>${cuts.map(item=>`<div class="rank-head">${esc(item.name)}</div>`).join('')}<div class="rank-head">Read</div><div class="row-label">Value</div>${cuts.map((_,i)=>`<div><span class="rank-value">${esc(ladder[i] ?? '—')}</span></div>`).join('')}<div><span class="rank-value">${esc(read)}</span></div></div><div class="metric-row">${metric('Trigger',triggerText(def.trigger))}${metric('Color domain',pack.colors?.[def.color]?.domain||title(def.color))}${metric('Socket cut',pack.colors?.[def.color]?.cut||'—')}${metric('Effects',(def.effects||[]).length)}</div><div class="section-label">Carat magnitude</div><div class="stat-line"><span>1 ct <b>1.00×</b></span><span>5 ct <b>2.00×</b></span><span>10 ct <b>3.25×</b></span><span>15 ct <b>4.50×</b></span><span>20 ct <b>6.00×</b></span><span>${pack.constants.carat_max||24} ct <b>${fmt((pack.constants.carat_max||24)-14,2)}×</b></span></div>`;
	const effects=`<div class="section-label">Effect definitions</div><div class="cards">${(def.effects||[]).map(effect=>`<div class="mini-card"><strong>${esc(effectText(effect))}</strong><p>${esc(title(effect.target||'Self'))} · ${esc(JSON.stringify(effect.amount??''))}</p></div>`).join('')||'<div class="mini-card"><strong>No direct effects</strong></div>'}</div>${def.flawless?`<div class="section-label">Flawless line</div><div class="note green">${esc(def.flawless.text||(def.flawless.effects||[]).map(effectText).join(' · '))}</div>`:''}`;
	return `${head('Stone index','Skill gems',`${records('skills').length} skills · five cut rungs · trigger rules and effect definitions from the pack.`,picker('skill-select','Select skill','skills',key,(k,v)=>`${v.name} · ${title(v.color)} · ${title(v.rarity)}`))}
	<div class="single-view">${panel('Skill record',`${tabs}<div class="detail"><div class="detail-top"><div><p class="eyebrow" style="color:${color(def.color)}">${esc(title(def.color))} · ${esc(title(def.rarity))}</p><h2>${esc(def.name || title(key))}</h2><p class="detail-copy">${esc(def.text || (def.effects||[]).map(effectText).join(' · '))}</p><div class="badges">${(def.tags||[]).map(tag=>`<span class="badge">${esc(title(tag))}</span>`).join('')}<span class="badge">Trigger: ${esc(triggerText(def.trigger))}</span></div></div><span class="swatch" style="--tone:${color(def.color)};width:19px;height:19px"></span></div>${pane==='effects'?effects:scaling}</div>`)}</div>`;
}

function lapidaryView() {
	const key = selected.lapidaries;
	const def = pack.characters[key] || {};
	const pane = selected.lapidaryPane || 'setting';
	const passive = def.passive || {};
	const birthstone = def.birthstone || {};
	const tabs=`<div class="segmented">${[['setting','Setting'],['passive','Passive & unlock']].map(([id,label])=>`<button class="segment ${pane===id?'active':''}" data-pane="${id}">${label}</button>`).join('')}</div>`;
	const setting=`<div class="section-label">Socket colors</div><div class="chip-row">${(def.sockets||[]).map(c=>`<span class="socket"><i class="swatch" style="--tone:${c==='ANY'?'#c1d87b':color(c)}"></i>${esc(title(c))}</span>`).join('')||'<span class="badge">No sockets listed</span>'}</div>${birthstone.name?`<div class="section-label">Birthstone</div><div class="mini-card"><strong>${esc(birthstone.name)}</strong><p>${esc(title(birthstone.style||''))} cut · ${esc(birthstone.hue||'')}</p></div>`:''}<div class="section-label">Starting dice</div><div class="chip-row">${(def.dice||[]).map((die,i)=>`<span class="socket"><span class="nav-number">0${i+1}</span>${esc(pack.dice[die]?.name||die)}</span>`).join('')}</div>`;
	const passivePane=`<div class="section-label">Passive ability</div><div class="note green">${esc(def.passive_text||passive.text||title(passive.kind||'No passive'))}${passive.amount!==undefined?` · ${esc(passive.amount)}`:''}</div><div class="section-label">Unlock</div><p class="detail-copy">${esc(def.unlock||def.unlock_text||(def.starter?'Available from the beginning.':`Unlock order ${def.unlock_order??'not specified'} in pack.`))}</p>`;
	return `${head('Workshop index','Lapidaries',`${records('characters').length} playable profiles · sockets, starting dice and passive rules.`,picker('lapidary-select','Select lapidary','characters',key,(k,v)=>`${v.name}${v.title?`, ${v.title}`:''}`))}
	<div class="single-view">${panel('Lapidary profile',`${tabs}<div class="detail"><div class="detail-top"><div><p class="eyebrow">${def.starter?'STARTER LAPIDARY':`UNLOCK ${def.unlock_order??'—'}`}</p><h2>${esc(`${def.name||title(key)}${def.title?`, ${def.title}`:''}`)}</h2><p class="detail-copy">${esc(def.text||def.description||'Character profile from the content pack.')}</p></div><span class="badge accent">${esc(key)}</span></div><div class="metric-row">${metric('Health',def.hp??'—','starting health')}${metric('Sockets',(def.sockets||[]).length)}${metric('Starting dice',(def.dice||[]).length)}${metric('Passive',title(passive.kind||'none'))}</div>${pane==='passive'?passivePane:setting}</div>`)}</div>`;
}

function inclusionView() {
	const key = selected.inclusions;
	const def = pack.inclusions[key] || {};
	const mods = def.modifiers || [];
	return `${head('Stone index','Inclusions',`${records('inclusions').length} modifiers · rolled into clarity slots and frozen inside a stone.`,picker('inclusion-select','Select inclusion','inclusions',key,(k,v)=>`${v.name||title(k)} · ${title(v.class||v.rarity)}`))}
	<div class="single-view">${panel('Inclusion record',`<div class="detail"><div class="detail-top"><div><p class="eyebrow">${esc(title(def.class||def.rarity||'INCLUSION'))}</p><h2>${esc(def.name||title(key))}</h2><p class="detail-copy">${esc(def.text||def.description||'No flavor text in pack.')}</p></div><span class="badge accent">WEIGHT ${esc(def.weight??'—')}</span></div><div class="metric-row">${metric('Class',title(def.class||'—'))}${metric('Weight',def.weight??'—','within inclusion pool')}${metric('Modifiers',mods.length)}${metric('Duplicates','Excluded per stone')}</div><div class="section-label">Modifiers</div><div class="cards">${mods.map(mod=>`<div class="mini-card"><strong>${esc(title(mod.kind))}${mod.amount!==undefined?` ${esc(mod.amount)}`:''}</strong><p>${esc(mod.color?title(mod.color):JSON.stringify(mod))}</p></div>`).join('')||'<div class="mini-card"><strong>No modifiers</strong></div>'}</div><div class="section-label">Clarity slot count</div><div class="chip-row">${(pack.clarities||[]).map(item=>`<span class="socket">${esc(item.name)} · ${item.inclusions}</span>`).join('')}</div><div class="section-label">Roll context</div><div class="note">Clarity defines inclusion slots. A single stone cannot roll the same inclusion twice.</div></div>`)}</div>`;
}

function roomView() {
	const key = selected.rooms;
	const mine = pack.mines[key] || {};
	const depth = Number(selected.roomDepth||3);
	const pane = selected.roomPane || 'chambers';
	const raw = mine.chambers || {};
	const available = {...raw};
	if(depth<=2) delete available.elite;
	if(depth<=1) delete available.merchant;
	const sum=Object.values(available).reduce((a,b)=>a+Number(b),0)||1;
	const rawSum=Object.values(raw).reduce((a,b)=>a+Number(b),0)||1;
	const descriptions={fight:'Standard encounter from the active depth band.',elite:'Higher-budget encounter; elite room weighting applies.',vein:`Mine ore and raw stones. Motherlode chance: ${mine.motherlode_pct??3}%.`,motherlode:'Rare vein variant, chosen when a vein is generated.',oddity:'Random oddity room and one drawn card.',merchant:'Trade stones and appraise finds.',smithy:'Work a die one tier up or down.',carver:'Change a die face or recut its value.',well:'A wishing well with a room card.'};
	const oddityKey=selected.oddity||records('oddities')[0]?.[0]||'';
	const oddity=pack.oddities[oddityKey]||{};
	const band=bandAt(mine,depth),creatures=band.creatures||{},bandTotal=Object.values(creatures).reduce((a,b)=>a+Number(b),0)||1;
	const tabs=`<div class="segmented">${[['chambers','Chambers'],['oddities','Oddities'],['bands','Depth bands']].map(([id,label])=>`<button class="segment ${pane===id?'active':''}" data-pane="${id}">${label}</button>`).join('')}</div>`;
	let content='';
	if(pane==='chambers') content=`<div class="metric-row">${metric('Mine luck',mine.luck??mine.quality??0)}${metric('Motherlode',`${mine.motherlode_pct??3}%`,'per vein')}${metric('Room types',Object.keys(raw).length)}${metric('Weight total',sum,'after depth filters')}</div><div class="cards room-cards">${Object.keys(raw).map(kind=>`<article class="mini-card"><div class="room-card-top"><strong>${esc(title(kind))}</strong><span class="mono">${available[kind]?`${fmt(available[kind]/sum*100,1)}%`:'OFF'}</span></div><p>Weight ${raw[kind]} · base ${fmt(raw[kind]/rawSum*100,1)}%</p><p>${esc(descriptions[kind]||'Room type from this mine pool.')}</p></article>`).join('')}</div><div class="note" style="margin-top:12px">${depth<=1?'Elite and merchant rooms are excluded at depth 1. ':depth<=2?'Elite rooms are excluded through depth 2. ':''}These are normalized per-draw weights before uniqueness and stretch guarantees. A stretch guarantees a merchant and a smithy or carver when possible.</div>`;
	if(pane==='oddities') content=`${picker('oddity-select','Oddity card','oddities',oddityKey,(k,v)=>`${v.name||title(k)} · ${title(v.room||'random')}`)}<div class="detail"><p class="eyebrow">${esc(title(oddity.room||'RANDOM ROOM'))}</p><h2>${esc(oddity.name||title(oddityKey))}</h2><p class="detail-copy">${esc(oddity.text||oddity.description||oddity.summary||'Oddity record from the content pack.')}</p><div class="section-label">Record</div><div class="table-wrap"><table><tbody>${Object.entries(oddity).filter(([k])=>!['name','text','description','summary'].includes(k)).map(([k,v])=>`<tr><th>${esc(title(k))}</th><td>${esc(Array.isArray(v)?v.map(x=>typeof x==='object'?JSON.stringify(x):x).join(' · '):typeof v==='object'?JSON.stringify(v):v)}</td></tr>`).join('')}</tbody></table></div></div>`;
	if(pane==='bands') content=`<div class="detail"><div class="detail-top"><div><p class="eyebrow">${esc(mine.name||title(key))}</p><h2>Creature pool at depth ${depth}</h2><p class="detail-copy">Band begins at depth ${band.from_depth??1}. Weights form the creature selection pool before encounter threat-budget checks.</p></div><span class="badge accent">${bandTotal} TOTAL WEIGHT</span></div><div class="cards">${Object.entries(creatures).map(([enemy,weight])=>`<article class="mini-card"><strong>${esc(pack.creatures[enemy]?.name||title(enemy))}</strong><p>Weight ${weight} · ${fmt(Number(weight)/bandTotal*100,1)}% first-pick share</p><p>Base HP ${pack.creatures[enemy]?.hp??'—'} · threat ${pack.creatures[enemy]?.threat??1}</p></article>`).join('')}</div><div class="section-label">Band thresholds</div><div class="chip-row">${(mine.bands||[]).map(item=>`<span class="socket">Depth ${item.from_depth}+ · ${Object.keys(item.creatures||{}).length} creatures</span>`).join('')}</div></div>`;
	return `${head('Descent atlas','Rooms & mines','Inspect room weights, oddity cards and depth-specific creature pools. Generator guarantees are called out separately.',picker('mine-select','Mine','mines',key,(k,v)=>v.name||title(k))+field('room-depth','Depth',`<input id="room-depth" type="number" min="1" max="99" value="${depth}" style="width:84px">`))}<div class="single-view">${panel(`${esc(mine.name||title(key))} · Mine atlas`,`${tabs}<div class="detail">${content}</div>`)}</div>`;
}

function bandAt(mine,depth) { return (mine.bands||[]).filter(b=>Number(b.from_depth||1)<=depth).at(-1)||(mine.bands||[])[0]||{creatures:{}}; }
function enemyHp(def,depth,party) { return Math.max(1,Math.round(Number(def.hp||10)*(1+Number(pack.constants.depth_hp_scale||.05)*Math.max(0,depth-1))*(1+.15*(Math.min(4,Math.max(1,party))-1)))); }
function enemyView() {
	const key=selected.enemies;
	const def=pack.creatures[key]||{};
	const mineKey=selected.enemyMine||records('mines')[0]?.[0];
	const mine=pack.mines[mineKey]||{};
	const depth=Number(selected.enemyDepth||1),party=Number(selected.enemyParty||1);
	const band=bandAt(mine,depth),pool=band.creatures||{};
	const total=Object.values(pool).reduce((a,b)=>a+Number(b),0)||1;
	const controls=picker('enemy-mine','Mine','mines',mineKey,(k,v)=>v.name||title(k))+field('enemy-depth','Depth','<input id="enemy-depth" type="number" min="1" max="99" value="'+depth+'" style="width:84px">')+field('enemy-party','Party size',`<select id="enemy-party">${[1,2,3,4].map(n=>`<option value="${n}" ${n===party?'selected':''}>${n}</option>`).join('')}</select>`);
	const allMoves=[...(def.moves||[]),...(def.phases||[]).flatMap(p=>p.moves||[])];
	const moves=[...new Map(allMoves.map(move=>[move.name,move])).values()];
	return `${head('Bestiary','Enemies','Depth bands weight the creature pool. Encounter generation spends a threat budget; the shown chance is the weighted first pick, not full-fight appearance chance.',controls)}
	<div class="grid-2"><div>${panel(`Band at depth ${depth}`,`<div class="detail"><div class="stat-line"><span>Band begins <b>${band.from_depth??1}</b></span><span>Weight total <b>${total}</b></span></div>${Object.entries(pool).sort((a,b)=>b[1]-a[1]).map(([enemy,weight])=>bar(pack.creatures[enemy]?.name||title(enemy),Number(weight)/total*100)).join('')||'<div class="note">No creature band defined.</div>'}</div>`)}</div>
	<div>${panel('Creature record',`<div class="detail"><div class="detail-top"><div><p class="eyebrow">${def.warden?'WARDEN':'CREATURE'} · ${esc(key)}</p><h2>${esc(def.name||title(key))}</h2><p class="detail-copy">${esc(def.text||'No flavor text in pack.')}</p></div><span class="badge accent">THREAT ${def.threat??1}</span></div><div class="metric-row">${metric('Base health',def.hp??'—')}${metric(`Health · depth ${depth}`,enemyHp(def,depth,party),`${party}-player party`)}${metric('Block',def.block??0)}${metric('Dice',(def.dice||[]).length)}</div>
	<div class="section-label">Encounter kit</div><div class="stat-line"><span>Dice <b>${(def.dice||[]).map(d=>pack.dice[d]?.name||d).map(esc).join(' · ')||'—'}</b></span><span>Gimmick <b>${esc(title(def.gimmick||'None'))}</b></span><span>Ward <b>${def.ward||(def.warden?1:0)}</b></span></div><div class="section-label">Moves</div><div class="cards">${moves.map(move=>`<div class="mini-card"><strong>${esc(move.name||'Move')}</strong><p>${esc(triggerText(move.trigger))} · ${(move.effects||[]).map(effectText).map(esc).join(' · ')}</p></div>`).join('')||'<div class="mini-card"><strong>No moves listed</strong></div>'}</div>
	${(def.phases||[]).length?`<div class="section-label">Phase thresholds</div><div class="table-wrap"><table><thead><tr><th>Phase</th><th>At or below</th><th>Moves</th></tr></thead><tbody>${def.phases.map((p,i)=>`<tr><td>${i+2}</td><td class="mono">${p.below_hp_pct}% HP</td><td>${(p.moves||[]).map(m=>esc(m.name)).join(', ')}</td></tr>`).join('')}</tbody></table></div>`:''}
	<div class="note" style="margin-top:13px">HP = round(base × [1 + depth scale × (depth − 1)] × [1 + 0.15 × extra players]). Enemy damage bonuses and turn enrage are not included.</div></div>`)}</div></div>`;
}

function faceDistribution(def) {
	const faces=def.faces||[];
	if(!faces.length)return new Map([[1,1]]);
	const out=new Map();
	const add=(value,p)=>{const result=typeof value==='number'?Math.min(100,value):value;out.set(result,(out.get(result)||0)+p);};
	const rollExplosions=(value,depth,probability)=>{for(const raw of faces){const face=typeof raw==='object'?raw:{value:raw};const p=probability/faces.length;if(face.kind==='exploding'&&depth<3)rollExplosions(Number(value)+Number(face.value||0),depth+1,p);else add(Number(value)+Number(face.value||0),p);}};
	for(const raw of faces){const face=typeof raw==='object'?raw:{value:raw};const p=1/faces.length;const kind=face.kind||'plain';let value=Number(face.value||0);if(kind==='blank'){add(0,p);continue;}if(kind==='exploding'){rollExplosions(value,1,p);continue;}if(kind==='mirror'){add('__mirror__',p);continue;}if(def.engraving==='keen')value++;if(def.engraving==='steady')value=Math.max(value,2);add(value,p);}
	return out;
}
function rollTotals(dice) {
	let states=new Map([['0|0|0',1]]);
	for(const die of dice){const dist=faceDistribution(die),next=new Map();for(const [state,p] of states){const [sum,high,mirrors]=state.split('|').map(Number);for(const [value,q] of dist){const mirror=value==='__mirror__';const k=mirror?`${sum}|${high}|${mirrors+1}`:`${sum+Number(value)}|${Math.max(high,Number(value))}|${mirrors}`;next.set(k,(next.get(k)||0)+p*q);}}states=next;}
	const totals=new Map();for(const [state,p] of states){const [sum,high,mirrors]=state.split('|').map(Number);const total=sum+high*mirrors;totals.set(total,(totals.get(total)||0)+p);}return totals;
}
function diceView() {
	const key=selected.dice,def=pack.dice[key]||{},qty=Number(selected.diceQty||5);
	const pane=selected.dicePane||'distribution';
	const dist=rollTotals(Array.from({length:qty},()=>def));
	const sorted=[...dist].sort((a,b)=>a[0]-b[0]);
	const mean=sorted.reduce((sum,[total,p])=>sum+total*p,0),peak=Math.max(...sorted.map(([,p])=>p));
	const stride=Math.max(1,Math.ceil(sorted.length/42)),groups=[];
	for(let i=0;i<sorted.length;i+=stride)groups.push(sorted.slice(i,i+stride).reduce((a,b)=>[a[0],a[1]+b[1]],[sorted[i][0],0]));
	const top=def.top||Math.max(0,...(def.faces||[]).map(f=>Number(typeof f==='object'?f.value:f)));
	const faces=(def.faces||[]).map(f=>typeof f==='object'?`${f.value}${f.kind&&f.kind!=='plain'?` ${title(f.kind)}`:''}`:f).join(' · ');
	const tools=picker('die-select','Die definition','dice',key,(k,v)=>`${v.name||title(k)} · ${v.shape||'custom'}`)+field('dice-qty','Dice',`<select id="dice-qty">${[1,2,3,4,5].map(n=>`<option value="${n}" ${n===qty?'selected':''}>${n}</option>`).join('')}</select>`);
	const tabs=`<div class="segmented">${[['distribution','Roll distribution'],['definition','Die definition']].map(([id,label])=>`<button class="segment ${pane===id?'active':''}" data-pane="${id}">${label}</button>`).join('')}</div>`;
	const definition=`<div class="detail"><div class="detail-top"><div><p class="eyebrow">${esc(title(def.rarity||'DIE'))} · ${esc(def.shape||'CUSTOM')}</p><h2>${esc(def.name||title(key))}</h2><p class="detail-copy">${esc(def.text||def.description||'Die definition from the content pack.')}</p></div><span class="badge accent">${esc(key)}</span></div><div class="metric-row">${metric('Shape',def.shape||'Custom')}${metric('Faces',(def.faces||[]).length)}${metric('Top',top)}${metric('Engraving',title(def.engraving||'None'))}</div><div class="section-label">Face table</div><div class="note">${esc(faces||'No faces listed')}</div>${def.engraving?`<div class="section-label">Engraving effect</div><div class="note green">${esc(pack.engravings?.[def.engraving]?.text||title(def.engraving))}</div>`:''}<div class="section-label">Probability model</div><div class="note">${qty} copies of this die · equal chance per listed face · up to three extra rolls on an exploding face. Mirror faces copy the highest non-mirror result.</div></div>`;
	const distribution=`<div class="detail"><div class="detail-top"><div><p class="eyebrow">${qty} × ${esc(def.shape||'DIE')}</p><div class="big-number">${fmt(mean,2)}</div><p class="detail-copy">Expected value · exact distribution across ${fmt(sorted.length,0)} distinct totals.</p></div><span class="badge accent">${qty} DICE</span></div><div class="distribution" style="margin-top:13px"><div><div class="histogram">${groups.map(([total,p])=>`<div class="hist-bar ${p===peak?'peak':''}" title="Total ${total}: ${fmt(p*100,3)}%" style="height:${Math.max(2,p/peak*100)}%"></div>`).join('')}</div><div class="hist-labels"><span>${sorted[0]?.[0]??0}</span><span>SUM</span><span>${sorted.at(-1)?.[0]??0}</span></div></div><div>${metric('Minimum',sorted[0]?.[0]??0)}${metric('Maximum',sorted.at(-1)?.[0]??0)}${metric('Mean',fmt(mean,3))}${metric('Distinct totals',sorted.length)}</div></div><div class="section-label">Most likely totals</div><div class="compact-table"><table><thead><tr><th>Total</th><th>Chance</th></tr></thead><tbody>${[...sorted].sort((a,b)=>b[1]-a[1]).slice(0,4).map(([total,p])=>`<tr><td class="mono">${total}</td><td class="mono">${fmt(p*100,3)}%</td></tr>`).join('')}</tbody></table></div></div>`;
	return `${head('Probability bench','Dice & rolls','Inspect any die, then calculate the exact total distribution for one to five copies.',tools)}<div class="single-view">${panel(`${esc(def.name||title(key))} · Dice lab`,`${tabs}${pane==='definition'?definition:distribution}`)}</div>`;
}

function normalCdf(x) {
	const sign=x<0?-1:1;x=Math.abs(x)/Math.sqrt(2);const t=1/(1+.3275911*x);
	const erf=1-(((((1.061405429*t-1.453152027)*t+1.421413741)*t-.284496736)*t+.254829592)*t)*Math.exp(-x*x);
	return .5*(1+sign*erf);
}
function caratOdds(luck) {
	const mean=Math.max(1,1.5+luck*.5),sd=Math.max(1,1.6+luck*.08),cap=Number(pack.constants.carat_max||24),p=Array(cap+1).fill(0);
	for(let c=1;c<=cap;c++){
		const base=normalCdf((c+.5-mean)/sd)-normalCdf((c-.5-mean)/sd);
		let jackpot=0;for(let bonus=3;bonus<=8;bonus++)jackpot+=(normalCdf((c-bonus+.5-mean)/sd)-normalCdf((c-bonus-.5-mean)/sd))/6;
		p[c]=.98*base+.02*jackpot;
	}
	const below=normalCdf((.5-mean)/sd),over=1-normalCdf((cap-.5-mean)/sd);
	const jackpotBelow=[3,4,5,6,7,8].reduce((s,b)=>s+normalCdf((.5-b-mean)/sd)/6,0);
	const jackpotOver=[3,4,5,6,7,8].reduce((s,b)=>s+(1-normalCdf((cap-b-.5-mean)/sd))/6,0);
	p[1]+=.98*below+.02*jackpotBelow;p[cap]+=.98*over+.02*jackpotOver;
	const sum=p.reduce((a,b)=>a+b,0);return p.map(v=>v/sum);
}
function luckView() {
	const key=selected.luck,mine=pack.mines[key]||{},depth=Number(selected.luckDepth||1),bonus=Number(selected.luckBonus||0);
	const pane=selected.luckPane||'carat';
	const luck=Math.min(depth*.5,10)+Number(mine.luck??mine.quality??0)+bonus;
	const cuts=(pack.cuts||[]).map((item,i)=>Number(item.weight||1)*Math.max(.08,1+luck*.06*(i-2)));
	const cutSum=cuts.reduce((a,b)=>a+b,0)||1;
	const clarities=pack.clarities||[],clear=Math.max(0,clarities.findIndex(item=>item.key==='CLEAR'));
	const clarityWeights=clarities.map((item,i)=>Number(item.weight||1)*Math.max(.06,1+luck*.025*Math.abs(i-clear)**2));
	const claritySum=clarityWeights.reduce((a,b)=>a+b,0)||1;
	const carats=caratOdds(luck),mean=carats.reduce((sum,p,c)=>sum+p*c,0),peak=Math.max(...carats);
	const tools=picker('luck-mine','Mine','mines',key,(k,v)=>`${v.name||title(k)} · Luck ${v.luck??v.quality??0}`)+field('luck-depth','Depth',`<input id="luck-depth" type="number" min="0" max="100" value="${depth}" style="width:84px">`)+field('luck-bonus','Bonus luck',`<input id="luck-bonus" type="number" value="${bonus}" style="width:92px">`);
	const tabs=`<div class="segmented">${[['carat','Carat'],['grades','Cut & clarity']].map(([id,label])=>`<button class="segment ${pane===id?'active':''}" data-pane="${id}">${label}</button>`).join('')}</div>`;
	const caratPanel=`<div class="detail"><div class="detail-top"><div><p class="eyebrow">ROUNDED NORMAL + 2% JACKPOT</p><div class="big-number">${fmt(mean,2)} <span style="color:var(--muted);font-size:12px">ct mean</span></div><p class="detail-copy">Chance for each carat count after rounding, jackpot and cap.</p></div><span class="badge accent">CAP ${pack.constants.carat_max||24} CT</span></div><div class="distribution" style="margin-top:14px"><div><div class="histogram">${carats.map((p,c)=>({p,c})).filter(x=>x.p>.001).map(({p,c})=>`<div class="hist-bar ${p===peak?'peak':''}" title="${c} ct: ${fmt(p*100,2)}%" style="height:${Math.max(2,p/peak*100)}%"></div>`).join('')}</div><div class="hist-labels"><span>1</span><span>CARATS</span><span>${carats.length-1}</span></div></div><div class="carat-metrics">${metric('Mean',`${fmt(mean,3)} ct`)}${metric('Luck',fmt(luck,1))}${metric('Jackpot chance','2%')}${metric('Carat cap',`${carats.length-1} ct`)}</div></div><div class="section-label">Most likely carats</div><div class="compact-table"><table><thead><tr><th>Carat</th><th>Chance</th></tr></thead><tbody>${carats.map((p,c)=>({p,c})).filter(x=>x.p>=.005).sort((a,b)=>b.p-a.p).slice(0,8).map(({p,c})=>`<tr><td class="mono">${c} ct</td><td class="mono">${fmt(p*100,2)}%</td></tr>`).join('')}</tbody></table></div><div class="note" style="margin-top:11px">Carat mean = max(1, 1.5 + luck × 0.5); deviation = max(1, 1.6 + luck × 0.08). A 2% jackpot adds 3–8 carats. This approximates DeepRng.normal; it does not predict a seeded roll.</div></div>`;
	const gradePanel=`<div class="detail"><div class="metric-row">${metric('Total luck',fmt(luck,1))}${metric('Mine luck',mine.luck??mine.quality??0)}${metric('Depth bonus',fmt(Math.min(depth*.5,10),1),'0.5 / depth, capped 10')}${metric('Source bonus',bonus)}</div><div class="grade-grid"><section><div class="section-label">Cut probability</div>${(pack.cuts||[]).map((item,i)=>bar(item.name,cuts[i]/cutSum*100)).join('')}</section><section><div class="section-label">Clarity probability</div>${clarities.map((item,i)=>bar(item.name,clarityWeights[i]/claritySum*100)).join('')}</section></div><div class="note" style="margin-top:13px">Luck = min(depth × 0.5, 10) + mine luck + source bonus. Cut leans toward higher ranks; clarity widens at both ends. Percentages use the exact adjusted pack weights.</div></div>`;
	return `${head('Forge model','Stone luck','Inspect mine, depth and source luck against the carat, cut and clarity distributions.',tools)}<div class="single-view">${panel('Luck model',`${tabs}${pane==='grades'?gradePanel:caratPanel}`,`MINE: ${esc(key)}`)}</div>`;
}

function rulesView() {
	const pane=selected.rulesPane||'boons';
	const boonKey=selected.rules||records('boons')[0]?.[0]||'';
	const boon=pack.boons[boonKey]||{};
	const tabs=`<div class="segmented">${[['boons','Boons'],['tables','Pack tables'],['constants','Run constants']].map(([id,label])=>`<button class="segment ${pane===id?'active':''}" data-pane="${id}">${label}</button>`).join('')}</div>`;
	const boonHead=picker('boon-select','Stake / boon','boons',boonKey,(k,v)=>`${v.name||title(k)} · ${title(v.group)}`);
	if(pane==='boons') return `${head('Run reference','Boons & rules',`${records('boons').length} stakes and boons · effect and eligibility data from the content pack.`,boonHead)}<div class="single-view">${panel('Boon index',`${tabs}<div class="detail"><div class="detail-top"><div><p class="eyebrow">${esc(title(boon.group||'BOON'))} · ${esc(title(boon.needs||'NO REQUIREMENT'))}</p><h2>${esc(boon.name||title(boonKey))}</h2><p class="detail-copy">${esc(boon.text||boon.description||'Boon record from the pack.')}</p></div><span class="badge accent">${esc(boonKey)}</span></div><div class="metric-row">${metric('Group',title(boon.group||'—'))}${metric('Requires',title(boon.needs||'None'))}${metric('Effects',(boon.effects||[]).length)}${metric('Eligibility',boon.unique===false?'Repeatable':'Pack-defined')}</div><div class="section-label">Effects</div><div class="cards">${(boon.effects||[]).map(effect=>`<div class="mini-card"><strong>${esc(title(effect.kind||'Effect'))}</strong><p>${esc(Object.entries(effect).filter(([k])=>k!=='kind').map(([k,v])=>`${title(k)}: ${typeof v==='object'?JSON.stringify(v):v}`).join(' · ')||'No parameters')}</p></div>`).join('')||'<div class="mini-card"><strong>No effects listed</strong></div>'}</div></div>`)}</div>`;
	if(pane==='tables') {
		const tablePane=selected.tablePane||'grades';
		const tableTabs=`<div class="segmented">${[['rarity','Rarity'],['grades','Cut & clarity'],['colors','Colors'],['engravings','Engravings']].map(([id,label])=>`<button class="segment ${tablePane===id?'active':''}" data-pane="${id}">${label}</button>`).join('')}</div>`;
		let tableBody='';
		if(tablePane==='rarity') tableBody=`<div class="detail"><p class="detail-copy">Rarity weights determine skill and die selection. MYTHIC has zero ordinary pool weight; score feeds quality scoring.</p><div class="compact-table"><table><thead><tr><th>Rarity</th><th>Weight</th><th>Score</th></tr></thead><tbody>${Object.entries(pack.rarities||{}).map(([key,item])=>`<tr><td>${esc(title(key))}</td><td class="mono">${item.weight}</td><td class="mono">${item.score}</td></tr>`).join('')}</tbody></table></div></div>`;
		if(tablePane==='grades') tableBody=`<div class="detail"><div class="table-wrap"><table><thead><tr><th>Cut</th><th>Weight</th><th>Clarity</th><th>Slots</th><th>Weight</th></tr></thead><tbody>${Math.max(pack.cuts?.length||0,pack.clarities?.length||0)===0?'':Array.from({length:Math.max(pack.cuts?.length||0,pack.clarities?.length||0)},(_,i)=>`<tr><td>${esc(pack.cuts?.[i]?.name||'—')}</td><td class="mono">${pack.cuts?.[i]?.weight??'—'}</td><td>${esc(pack.clarities?.[i]?.name||'—')}</td><td class="mono">${pack.clarities?.[i]?.inclusions??'—'}</td><td class="mono">${pack.clarities?.[i]?.weight??'—'}</td></tr>`).join('')}</tbody></table></div><div class="note" style="margin-top:10px">Clarity bonuses such as Pristine resonance and Flawless magnitude/line are shown with each inclusion and skill record.</div></div>`;
		if(tablePane==='colors') tableBody=`<div class="detail"><div class="table-wrap"><table><thead><tr><th>Color</th><th>Domain</th><th>Default cut</th><th>Hue</th></tr></thead><tbody>${Object.entries(pack.colors||{}).map(([key,item])=>`<tr><td><i class="swatch" style="--tone:#${esc(item.hue||'999999')};display:inline-block;vertical-align:middle;margin-right:7px"></i>${esc(item.name||title(key))}</td><td>${esc(title(item.domain||''))}</td><td>${esc(title(item.cut||''))}</td><td class="mono">#${esc(item.hue||'')}</td></tr>`).join('')}</tbody></table></div></div>`;
		if(tablePane==='engravings') tableBody=`<div class="detail"><div class="table-wrap"><table><thead><tr><th>Engraving</th><th>Key</th><th>Rarity</th><th>Effect</th></tr></thead><tbody>${records('engravings').map(([key,item])=>`<tr><td>${esc(item.name||title(key))}</td><td class="mono">${esc(item.key||key)}</td><td>${esc(title(item.rarity||''))}</td><td>${esc(item.text||'')}</td></tr>`).join('')}</tbody></table></div></div>`;
		return `${head('Run reference','Boons & rules','Pack-wide weights and identity tables used by stone, skill, die and inclusion generation.')}${tabs}<div class="single-view">${panel('Pack tables',`${tableTabs}${tableBody}`)}</div>`;
	}
	const groups=[['Run cadence',['starting_rail_cap','rerolls','landing_every','warden_depths','endless_warden_every','run_depth','lantern_ore_cost']],['Combat',['depth_hp_scale','depth_damage_every','enrage_turn','enrage_damage','ore_per_fight']],['Workshop & lift',['appraise_ore_cost','appraise_gold_min','appraise_gold_mult','appraise_cost_step','rest_pct','lift_ore_per_depth']],['Drops & salvage',['carat_max','opal_hoard_pct','stone_drop_pct','salvage_dice','grade_thresholds']]];
	const format=(value)=>Array.isArray(value)?value.join(' · '):value&&typeof value==='object'?Object.entries(value).map(([k,v])=>`${title(k)} ${v}`).join(' · '):String(value);
	return `${head('Run reference','Boons & rules','The simulation constants that govern descent cadence, combat scaling, appraisal, drops and salvage.')}${tabs}<div class="rule-grid constants-grid">${groups.map(([group,keys])=>panel(group,`<div style="padding:4px 12px">${keys.map(key=>`<div class="split-line"><span>${esc(title(key))}</span><b>${esc(format(pack.constants?.[key]??'—'))}</b></div>`).join('')}</div>`)).join('')}</div>`;
}

function wire() {
	const bind=(id,key)=>{const el=$(`#${id}`);if(el)el.addEventListener('change',()=>{selected[key]=el.value;render();});};
	const bindNumber=(id,key)=>bind(id,key);
	bind('skill-select','skills');bind('inclusion-select','inclusions');
	bind('lapidary-select','lapidaries');
	bind('mine-select','rooms');bindNumber('room-depth','roomDepth');
	bind('enemy-mine','enemyMine');bindNumber('enemy-depth','enemyDepth');bind('enemy-party','enemyParty');
	bind('die-select','dice');bind('dice-qty','diceQty');
	bind('oddity-select','oddity');bind('luck-mine','luck');bindNumber('luck-depth','luckDepth');bindNumber('luck-bonus','luckBonus');
	bind('boon-select','rules');
	$$('.segment').forEach(button=>button.addEventListener('click',()=>{if(current==='rooms')selected.roomPane=button.dataset.pane;if(current==='luck')selected.luckPane=button.dataset.pane;if(current==='dice')selected.dicePane=button.dataset.pane;if(current==='skills')selected.skillPane=button.dataset.pane;if(current==='lapidaries')selected.lapidaryPane=button.dataset.pane;if(current==='rules'){if(['boons','tables','constants'].includes(button.dataset.pane))selected.rulesPane=button.dataset.pane;else selected.tablePane=button.dataset.pane;}render();}));
}
async function start() {
	try {
		const response=await fetch('/data/deep_cut.json');
		if(!response.ok)throw new Error(`Content pack request failed (${response.status})`);
		pack=await response.json();
		$('#pack-version').textContent=`V${pack.version}`;$('#version-short').textContent=pack.version;
		render('overview');
	} catch(error) {
		$('#app').innerHTML=`<div class="error"><strong>Could not load the content pack.</strong><p>${esc(error.message)}</p><p>Start from the project root with <code>node tools/data-browser/server.mjs</code>.</p></div>`;
	}
}
start();