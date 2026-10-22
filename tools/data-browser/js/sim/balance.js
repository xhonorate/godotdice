// Balance sweeps: what every gem, Cut, Clarity, inclusion and pairing is worth against training
// dummies (fight.js), on every lapidary's own bowl with their passive and Birthstone. Pure
// functions over the pack, shared by the browser's workers and by tools/data-browser/balance.mjs.
//
// A sweep is a list of rails, each played `samples` times on every bowl. Every rail on a bowl
// plays the same seeded fights (see playFight), so what one rail does better than another is
// the rail and not the dice. Each rail is played in two fights, and comes back as a vector of
// means (VECTOR) over both:
//
//   the ordinary fight  two dummies with a creature's health each: overkill is wasted, poison
//                       dies with its creature and a kill saves the blows it would have thrown;
//   the boss fight      one dummy that never falls, and a kill line at a boss's health. Its
//                       damage is the pace the rail reaches that line at (the line over the turn
//                       it was crossed, read within the turn), so nothing a rail does is ever
//                       capped; a rail that never reaches it is read at what it dealt.
//
// A value is always measured against the empty rail on the same bowl, in the same fight, which
// is what the Birthstone and passive do on their own:
//
//   power  = damage × dealt + saved × (incoming − lost + healed) + gold × pyrite won
//   value  = power(rail) − power(empty rail)
//
// so the exchange rates, and which fight is read, can change on the page without playing
// anything again.
//
// Three sweeps go further than one fight at one weight. `carats` plays the host rails at every
// mine's carats and creature health (BANDS). `hunt` searches whole rails for the strongest
// builds, a few rounds at a time (see the job functions at the end). `growth` plays a run of
// fights that keeps what lasts the run, and one long boss fight, turn by turn.

import * as C from './content.js';
import * as Stone from './stone.js';
import * as Forge from './forge.js';
import { playFight, RAIL_CAP } from './fight.js';
import { policyFor } from './simulate.js';
import { makeRng } from './rng.js';

export const SWEEPS = ['gems', 'cutclarity', 'inclusions', 'pairs', 'rails', 'carats', 'hunt', 'growth'];
export const VECTOR = ['dealt', 'saved', 'gold', 'fires', 'birthstone', 'resonance', 'blockGained', 'healed', 'hpLost', 'downs', 'kills', 'bossDealt', 'bossSaved', 'bossKilled', 'runaway'];
const BOSS_DEALT = VECTOR.indexOf('bossDealt');
const BOSS_SAVED = VECTOR.indexOf('bossSaved');
export const RUNAWAY = VECTOR.indexOf('runaway');
// A rail the game spends (it played RAIL_CAP gems in one turn; fight.js and sim/battle.gd
// both stop it there) is a runaway here: played no further, its numbers what it did until
// then, and `runaway` is 1.
export { RAIL_CAP };
export const FIGHTS = ['mob', 'boss'];
export const DEFAULT_WEIGHTS = { damage: 1, saved: 0.7, gold: 0, fight: 'mob' };
// The fight every sweep is played in. A dummy throws a d8 and a d6 each action and raises a
// little block as it does: two of them come at the player for about what a mid-depth
// encounter does (two creatures, sixteen or so a turn), each with sixty health, about a
// mid-depth creature. The boss is one dummy throwing a d12 and a d8 that never falls, with a
// kill line at The Unmade's health. dummyHp 0 makes the ordinary dummies endless too.
export const DEFAULTS = { turns: 4, dummies: 2, dummyDice: ['D8', 'D6'], dummyHp: 60, guard: 3, bossHp: 400, bossDice: ['D12', 'D8'], bossGuard: 6,
	pyrite: 60, depth: 3, carat: 8, cut: 2, clarity: 'CLEAR', birthstone: true, passive: true, mine: 'QUARRY', seed: 1, hosts: 24,
	caratHosts: 6, huntBands: ['QUARRY', 'GLASS_VEINS', 'FURNACE', 'RIFT@57'], huntStarts: 3, huntPasses: 2, copies: 1, transcendent: 1, opals: 0, opalsApart: false, gemPlays: 0, huntVerify: 300,
	runFights: 12, longTurns: 10,
	samples: { gems: 1000, cutclarity: 300, inclusions: 300, pairs: 300, rails: 150, carats: 40, hunt: 15, growth: 30 } };
// What a fight can only measure with a neighbour: these are judged beside a bare copy of
// their own gem, before it and after it, rather than alone.
export const RAIL_CLASSES = ['FEATHER'];
// The rails sweep sets every gem into rails of this many others (the host): an opal does
// nothing alone, and a single partner never rings the rail loud enough to wake one.
export const HOST_SIZE = 4;
// What the hunt never sets: a Black Opal feeds on the bag, and a training fight has none.
export const HUNT_SKIP = ['BLACK_OPAL'];
const HUNT_STARTS = ['plain', 'random', 'opals'];
const RANDOM_RAILS = 12;
const MAX_RUNAWAYS = 400;
const ACCEPT = 0.01;

// The settings a sweep's numbers depend on (the exchange rates are not among them).
export function sweepSettings(settings, sweep) {
	const s = { ...DEFAULTS, ...settings };
	const out = { turns: s.turns | 0, dummies: s.dummies | 0, dummyDice: s.dummyDice.slice(), dummyHp: s.dummyHp | 0, guard: s.guard | 0,
		bossHp: Math.max(1, s.bossHp | 0), bossDice: (s.bossDice || DEFAULTS.bossDice).slice(), bossGuard: s.bossGuard | 0,
		pyrite: s.pyrite | 0, depth: s.depth | 0, carat: s.carat | 0, cut: s.cut | 0, clarity: s.clarity, birthstone: Boolean(s.birthstone), passive: Boolean(s.passive), mine: s.mine, seed: s.seed | 0,
		samples: typeof s.samples === 'number' ? s.samples : Number((s.samples || {})[sweep] ?? DEFAULTS.samples[sweep]) };
	if (sweep === 'rails') out.hosts = Math.max(1, s.hosts | 0);
	if (sweep === 'carats' || sweep === 'growth') { out.caratHosts = Math.max(1, s.caratHosts | 0); out.hosts = out.caratHosts; }
	if (sweep === 'growth') { out.runFights = Math.max(2, s.runFights | 0); out.longTurns = Math.max(2, s.longTurns | 0); }
	if (sweep === 'hunt') {
		const known = bands().map((b) => b.key);
		out.huntBands = (s.huntBands || []).filter((k) => known.includes(k));
		if (!out.huntBands.length) out.huntBands = DEFAULTS.huntBands.filter((k) => known.includes(k));
		out.huntStarts = Math.max(1, Math.min(HUNT_STARTS.length, s.huntStarts | 0));
		out.huntPasses = Math.max(1, s.huntPasses | 0);
		out.copies = Math.max(1, s.copies | 0);
		out.transcendent = Math.max(0, s.transcendent | 0);
		// The most opals a hunted rail may hold (0: as many as it likes), and whether no opal
		// may reach another (a rule tried here, not the game's: see fight.js `repeatable`).
		out.opals = Math.max(0, s.opals | 0);
		out.opalsApart = Boolean(s.opalsApart);
		// The most times one gem may play in a turn (0: no limit): a rule tried here, not the game's.
		out.gemPlays = Math.max(0, s.gemPlays | 0);
		out.huntVerify = Math.max(50, s.huntVerify | 0);
	}
	return out;
}

// A fingerprint of the content pack, so a saved sweep knows whether the pack has moved on.
export function packHash(pack) {
	const text = JSON.stringify(pack);
	let h = 0x811c9dc5;
	for (let i = 0; i < text.length; i++) { h ^= text.charCodeAt(i); h = Math.imul(h, 0x01000193); }
	return (h >>> 0).toString(16).padStart(8, '0');
}

export const lapidaries = () => C.keys('characters').sort((a, b) => Number(C.character(a).unlock_order ?? 0) - Number(C.character(b).unlock_order ?? 0));
export const skillKeys = () => C.keys('skills');
export const policyOf = (skill) => policyFor(C.skill(skill).trigger || {});
export const clarityOf = (key) => Math.max(0, C.clarityIndex(key));
export const railLength = (bowl) => Math.max(1, (C.character(bowl).sockets || []).length || 6);

// A rail's power in one of the two fights (`w.fight`, the ordinary one unless 'boss').
export function power(v, w = DEFAULT_WEIGHTS) {
	if (!v) return NaN;
	const boss = w.fight === 'boss';
	if (boss && v.length <= BOSS_SAVED) return NaN;
	const dealt = boss ? v[BOSS_DEALT] : v[0];
	const saved = boss ? v[BOSS_SAVED] : v[1];
	return Number(w.damage ?? 1) * dealt + Number(w.saved ?? 0.7) * saved + Number(w.gold ?? 0) * v[2];
}

// How many turns a rail takes to bring the boss down at the pace it set: `wall` is the kill line.
export function killTurns(v, wall, turns) {
	if (!v || v.length <= BOSS_DEALT) return NaN;
	const pace = v[BOSS_DEALT] / Math.max(1, turns);
	return pace > 0 ? wall / pace : Infinity;
}

// --- mines -----------------------------------------------------------------------------------
// A band is a mine as a rail meets it at the mine's boss: the carat a good rail of its stones
// weighs (its carat band's cap there), how much more health its creatures carry and how much
// harder they hit than the Quarry's, and its boss's health, the kill line. An endless mine is
// read twice: three Wardens down and seven, where its band has climbed to the most there is.

const ENDLESS_WARDENS = [3, 7];

export function bands() {
	const mines = C.keys('mines').sort((a, b) => Number(C.mine(a).tier ?? 0) - Number(C.mine(b).tier ?? 0));
	const out = [];
	for (const key of mines) {
		const mine = C.mine(key);
		if (mine.endless) for (const wardens of ENDLESS_WARDENS) out.push(bandAt(key, 1 + wardens * Math.max(1, Number(mine.warden_every ?? 8)), true));
		else out.push(bandAt(key, Math.max(1, Number(mine.depth || 1)), false));
	}
	return out;
}

function bandAt(key, depth, endless) {
	const mine = C.mine(key);
	const carat = Forge.caratBand(mine, depth);
	const scale = Forge.creatureScale(mine, depth);
	const hp = (1 + Number(C.constant('depth_hp_scale', 0.05)) * Math.max(0, depth - 1)) * scale.hp;
	const bossKey = String(mine.boss || mine.unmade || '');
	const boss = C.creature(bossKey);
	return { key: endless ? `${key}@${depth}` : key, mine: key, name: endless ? `${mine.name || C.title(key)}, depth ${depth}` : mine.name || C.title(key), depth,
		carat: carat ? carat.cap : 8, hp, damage: scale.damage, boss: bossKey, bossName: boss.name || C.title(bossKey), bossHp: Math.round(Number(boss.hp || 400) * hp),
		bossDice: (boss.dice || []).length ? boss.dice.slice() : null };
}

export const bandOf = (key) => bands().find((b) => b.key === key) || null;

// The two fights' dummies, as played on their own or at a band.
function fightsFor(s, band) {
	const hit = band ? band.damage : 1;
	const wall = band ? band.bossHp : s.bossHp;
	return {
		mob: { count: s.dummies, dice: s.dummyDice, guard: s.guard, hp: s.dummyHp > 0 ? Math.min(2e9, Math.round(s.dummyHp * (band ? band.hp : 1))) : 0, hit },
		// It never falls: its health is far past the line, so the turn that crosses it is counted whole.
		boss: { count: 1, dice: band && band.bossDice ? band.bossDice : s.bossDice, guard: s.bossGuard, hp: Math.min(2e9, Math.max(1e6, Math.ceil(wall * 4))), hit },
		wall,
	};
}

// --- what is played ---------------------------------------------------------------------------
// A rail travels to a worker as {key, stones: [[skill, carat, cut, clarity, inclusions]], policy}.

const baseline = (prefix = '') => ({ key: `${prefix}0`, stones: [], policy: 'none' });

function gemRails(s) {
	const clarity = clarityOf(s.clarity);
	return [baseline(), ...skillKeys().map((k) => ({ key: `s|${k}`, stones: [[k, s.carat, s.cut, clarity, []]], policy: policyOf(k) }))];
}

// Every gem up the Cut ladder as a Clear stone, and as a Flawless stone at the sweep's own cut,
// to set against the Clear one there: two comparisons, each with the other C held still.
function cutClarityRails(s) {
	const clear = clarityOf('CLEAR');
	const out = [baseline()];
	for (const k of skillKeys()) {
		const rail = (cut, clarity) => ({ key: `c|${k}|${cut}|${clarity}`, stones: [[k, s.carat, cut, clarity, []]], policy: policyOf(k) });
		for (let cut = 0; cut < C.cuts().length; cut++) out.push(rail(cut, clear));
		out.push(rail(s.cut, clarityOf('FLAWLESS')));
	}
	return out;
}

// Inclusions a stone of this color can grow: never a Zoning of its own color.
export function inclusionsFor(skill) {
	const own = String(C.skill(skill).color || '');
	return C.keys('inclusions').filter((k) => Forge.zoningColor(C.inclusion(k)) !== own);
}
export const railInclusion = (key) => RAIL_CLASSES.includes(String(C.inclusion(key).class || ''));

function inclusionRails(s) {
	const clarity = clarityOf(s.clarity);
	const out = [baseline()];
	for (const k of skillKeys()) {
		const policy = policyOf(k);
		const gem = (inc) => [k, s.carat, s.cut, clarity, inc ? [inc] : []];
		out.push({ key: `i|${k}|`, stones: [gem('')], policy });
		out.push({ key: `f|${k}||`, stones: [gem(''), gem('')], policy });
		for (const inc of inclusionsFor(k)) {
			if (railInclusion(inc)) {
				out.push({ key: `f|${k}|${inc}|a`, stones: [gem(inc), gem('')], policy });
				out.push({ key: `f|${k}|${inc}|b`, stones: [gem(''), gem(inc)], policy });
			} else out.push({ key: `i|${k}|${inc}`, stones: [gem(inc)], policy });
		}
	}
	return out;
}

// The host rails: `hosts` rails of HOST_SIZE different gems drawn from everything but the
// opals, the same on every bowl, fixed by the seed. `settings` as sweepSettings leaves them.
export function hostsFor(settings) {
	const s = { ...DEFAULTS, ...settings };
	const pool = skillKeys().filter((k) => C.skill(k).color !== C.OPAL);
	const rng = makeRng(s.seed * 7907 + 101);
	return Array.from({ length: Math.max(1, s.hosts | 0) }, () => {
		const picked = [];
		while (picked.length < HOST_SIZE) { const k = pool[rng.randiRange(0, pool.length - 1)]; if (!picked.includes(k)) picked.push(k); }
		return picked;
	});
}

// Where a gem is tried in a host: an opal in every place (a Seam wants the gems it replays
// before it, a Prelude the gem it repeats after it), anything else first or last.
export const placesFor = (skill) => (C.skill(skill).color === C.OPAL ? Array.from({ length: HOST_SIZE + 1 }, (_, i) => i) : [0, HOST_SIZE]);
// The growth sweep plays a run for every rail, so it tries every gem first and last only.
const growthPlaces = () => [0, HOST_SIZE];

const leadOf = (keys, leads) => keys.reduce((best, k) => ((leads[k] ?? 0) > (leads[best] ?? 0) ? k : best), keys[0]);

// Every host alone, and every gem set into every host in each of its places, at `carat`. A
// rail chases the trigger of whichever of its gems does most alone on this bowl. Keys carry
// `prefix` (a band's, in the carats sweep).
function railRails(s, leads, { carat = s.carat, prefix = '', places = placesFor } = {}) {
	const clarity = clarityOf(s.clarity);
	const stone = (k) => [k, carat, s.cut, clarity, []];
	const out = [baseline(prefix)];
	hostsFor(s).forEach((host, i) => {
		out.push({ key: `${prefix}h|${i}`, stones: host.map(stone), policy: policyOf(leadOf(host, leads)) });
		for (const k of skillKeys()) {
			for (const place of places(k)) {
				const keys = host.slice();
				keys.splice(place, 0, k);
				out.push({ key: `${prefix}r|${k}|${i}|${place}`, stones: keys.map(stone), policy: policyOf(leadOf(keys, leads)) });
			}
		}
	});
	return out;
}

// Every ordered pair, each chasing the trigger of whichever of the two does more alone on this
// bowl (`leads[bowl][skill]`, from the gems sweep), and every gem alone again on the same
// fights so a pair's synergy is read against its own two halves.
function pairRails(s, leads) {
	const clarity = clarityOf(s.clarity);
	const keys = skillKeys();
	const out = gemRails(s);
	for (const a of keys) {
		for (const b of keys) {
			if (a === b) continue;
			const lead = (leads[a] ?? 0) >= (leads[b] ?? 0) ? a : b;
			out.push({ key: `p|${a}|${b}`, stones: [[a, s.carat, s.cut, clarity, []], [b, s.carat, s.cut, clarity, []]], policy: policyOf(lead) });
		}
	}
	return out;
}

// Rails cut into tasks of a second or two each: `weight` is a rail's cost in stone-fights.
function chunk(rails, base, weightOf) {
	const tasks = [];
	let batch = [];
	let weight = 0;
	for (const rail of rails) {
		batch.push(rail);
		weight += weightOf(rail);
		if (weight >= 9000) { tasks.push({ ...base, rails: batch }); batch = []; weight = 0; }
	}
	if (batch.length) tasks.push({ ...base, rails: batch });
	return tasks;
}

// The work of a one-round sweep. `context.leads` is {bowl: {skill: solo power}} for the
// sweeps that set gems beside others.
export function tasksFor(sweep, settings, context = {}) {
	const s = sweepSettings(settings, sweep);
	const tasks = [];
	for (const bowl of lapidaries()) {
		const leads = (context.leads || {})[bowl] || {};
		const base = { sweep, bowl, settings: s };
		if (sweep === 'carats') {
			for (const band of bands()) {
				const rails = railRails(s, leads, { carat: band.carat, prefix: `${band.key}/` });
				tasks.push(...chunk(rails, { ...base, band }, (r) => 2 * s.samples * Math.max(1, r.stones.length)));
			}
			continue;
		}
		if (sweep === 'growth') {
			const rails = railRails(s, leads, { places: growthPlaces });
			const per = s.runFights + s.longTurns / Math.max(1, s.turns);
			tasks.push(...chunk(rails, { ...base, growth: true }, (r) => per * s.samples * Math.max(1, r.stones.length)));
			continue;
		}
		let rails;
		if (sweep === 'gems') rails = gemRails(s);
		else if (sweep === 'cutclarity') rails = cutClarityRails(s);
		else if (sweep === 'inclusions') rails = inclusionRails(s);
		else if (sweep === 'pairs') rails = pairRails(s, leads);
		else if (sweep === 'rails') rails = railRails(s, leads);
		else throw new Error(`${sweep} is not a one-round sweep`);
		tasks.push(...chunk(rails, base, (r) => 2 * s.samples * Math.max(1, r.stones.length)));
	}
	return tasks;
}

// Play one task: every rail in it on its bowl (at its band, if it has one), `samples` fights
// each in the fights it asks for (both unless `task.fights` says). Returns {bowl, results:
// [[key, vector]]}; a growth task's vectors are laid out as growthLayout says.
export function runTask(task) {
	const s = task.settings;
	const band = task.band || null;
	const F = fightsFor(s, band);
	const samples = task.samples ?? s.samples;
	const want = task.fights || FIGHTS;
	const mob = want.includes('mob');
	const boss = want.includes('boss');
	const results = [];
	for (const rail of task.rails) {
		const spec = { character: task.bowl, rail: rail.stones.map((st, i) => Stone.make(st[0], st[1], st[2], st[3], st[4] || [], `g${i}`)), policy: rail.policy, turns: s.turns,
			pyrite: s.pyrite, depth: band ? band.depth : s.depth, birthstone: s.birthstone, passive: s.passive, seed: s.seed + (task.seedOffset | 0), stopOnRunaway: true, stopAtWall: Boolean(task.stopAtWall), opalsApart: Boolean(s.opalsApart), gemPlays: s.gemPlays | 0 };
		if (task.growth) { results.push([rail.key, growthVector(spec, F, s, samples)]); continue; }
		const sums = new Array(VECTOR.length).fill(0);
		let played = 0;
		for (let i = 0; i < samples; i++) {
			played += 1;
			let runaway = false;
			if (mob) {
				const m = playFight({ ...spec, dummies: F.mob }, i);
				sums[0] += m.dealt; sums[1] += m.incoming - m.hpLost + m.healed; sums[2] += m.gold; sums[3] += m.fires; sums[4] += m.birthstone;
				sums[5] += m.resonance; sums[6] += m.blockGained; sums[7] += m.healed; sums[8] += m.hpLost; sums[9] += m.downs; sums[10] += m.kills;
				if (m.runaway) runaway = true;
			}
			if (boss) {
				const b = playFight({ ...spec, dummies: F.boss, wall: F.wall }, i);
				const killed = b.killTurn < Infinity;
				sums[BOSS_DEALT] += killed ? (F.wall / Math.max(1e-9, b.killTurn)) * s.turns : b.dealt;
				sums[BOSS_SAVED] += b.incoming - b.hpLost + b.healed;
				sums[13] += killed ? 1 : 0;
				if (!mob) { sums[2] += b.gold; sums[3] += b.fires; sums[5] += b.resonance; }
				if (b.runaway) runaway = true;
			}
			if (runaway) { sums[RUNAWAY] = played; break; }
		}
		results.push([rail.key, sums.map((v) => round3(v / played))]);
	}
	return { bowl: task.bowl, band: band ? band.key : '', results };
}

const round3 = (v) => Math.round(v * 1000) / 1000;

// A growth rail's vector: for each of the run's fights [dealt, saved, gold], then for each turn
// of the long boss fight [dealt, saved].
export function growthLayout(settings) {
	const fights = Math.max(2, settings.runFights | 0);
	const turns = Math.max(2, settings.longTurns | 0);
	return { fights, turns, length: fights * 3 + turns * 2 + 1, fight: (f) => f * 3, turn: (t) => fights * 3 + t * 2, runaway: fights * 3 + turns * 2 };
}

function growthVector(spec, F, s, samples) {
	const L = growthLayout(s);
	const sums = new Array(L.length).fill(0);
	let played = 0;
	for (let i = 0; i < samples; i++) {
		played += 1;
		let runaway = false;
		// A run: one ordinary fight after another, keeping the dice, the fire counts and the health
		// the rail grew. The player starts each fight whole.
		const carry = {};
		for (let f = 0; f < L.fights; f++) {
			const m = playFight({ ...spec, dummies: F.mob, fight: f + 1 }, i, carry);
			const at = L.fight(f);
			sums[at] += m.dealt; sums[at + 1] += m.incoming - m.hpLost + m.healed; sums[at + 2] += m.gold;
			if (m.runaway) { runaway = true; break; }
		}
		if (!runaway) {
			const long = playFight({ ...spec, turns: L.turns, dummies: F.boss, perTurn: true }, i);
			for (let t = 0; t < long.turnDealt.length; t++) { sums[L.turn(t)] += long.turnDealt[t]; sums[L.turn(t) + 1] += long.turnSaved[t]; }
			if (long.runaway) runaway = true;
		}
		if (runaway) { sums[L.runaway] = played; break; }
	}
	return sums.map((v) => round3(v / played));
}

// Fold the tasks' answers into a sweep: {sweep, settings, bowls, vector, data: {bowl: {key:
// vector}}, leads?}.
export function assemble(sweep, tasks, results, meta = {}) {
	const data = {};
	for (const r of results) {
		const into = data[r.bowl] || (data[r.bowl] = {});
		for (const [key, vector] of r.results) into[key] = vector;
	}
	const settings = tasks.length ? tasks[0].settings : sweepSettings({}, sweep);
	const extra = {};
	if (sweep === 'rails' || sweep === 'carats' || sweep === 'growth') extra.hosts = hostsFor(settings);
	if (sweep === 'carats') extra.bands = bands();
	return { sweep, settings, bowls: lapidaries(), skills: skillKeys(), vector: sweep === 'growth' ? null : VECTOR, data, ...extra, ...meta };
}

// --- reading a sweep --------------------------------------------------------------------------

// A rail's value on a bowl: its power over the empty rail's (`prefix`, a band's, in the carats sweep).
export function value(result, bowl, key, w, prefix = '') {
	const at = (result.data || {})[bowl];
	if (!at || !at[key] || !at[`${prefix}0`]) return NaN;
	return power(at[key], w) - power(at[`${prefix}0`], w);
}

export function spread(values) {
	const ok = values.filter((v) => Number.isFinite(v));
	if (!ok.length) return { min: NaN, avg: NaN, best: NaN, minAt: -1, bestAt: -1 };
	let min = Infinity, best = -Infinity, minAt = -1, bestAt = -1, sum = 0;
	values.forEach((v, i) => { if (!Number.isFinite(v)) return; sum += v; if (v < min) { min = v; minAt = i; } if (v > best) { best = v; bestAt = i; } });
	return { min, avg: sum / ok.length, best, minAt, bestAt };
}

// The solo power of every gem on every bowl, for choosing which half of a pair the rerolls chase.
export function leadsFrom(gems, w = DEFAULT_WEIGHTS) {
	const out = {};
	const ordinary = { ...w, fight: 'mob' };
	for (const bowl of gems.bowls || []) {
		out[bowl] = {};
		for (const k of gems.skills || []) out[bowl][k] = value(gems, bowl, `s|${k}`, ordinary);
	}
	return out;
}

// A pair's best order on a bowl, and what it does over its two halves played alone.
export function pairValue(pairs, bowl, a, b, w) {
	const ab = value(pairs, bowl, `p|${a}|${b}`, w);
	const ba = value(pairs, bowl, `p|${b}|${a}`, w);
	const best = Math.max(ab, ba);
	const alone = value(pairs, bowl, `s|${a}`, w) + value(pairs, bowl, `s|${b}`, w);
	return { value: best, order: ab >= ba ? [a, b] : [b, a], synergy: best - alone, alone, ab, ba };
}

// How much a gem adds beside a partner, averaged over every partner: the pair's best order
// less what the partner does alone.
export function partnerValue(pairs, bowl, skill, w) {
	let sum = 0, n = 0;
	for (const other of pairs.skills || []) {
		if (other === skill) continue;
		const p = pairValue(pairs, bowl, skill, other, w);
		const v = p.value - value(pairs, bowl, `s|${other}`, w);
		if (Number.isFinite(v)) { sum += v; n += 1; }
	}
	return n ? sum / n : NaN;
}

// What a gem adds to the host rails on a bowl, each host in the gem's best place: its value
// (power over the host's), what changed (a VECTOR of differences: damage, health saved,
// pyrite, fires, block gained, healing…), how often each place was the best, and every host.
// `prefix` reads one band of the carats sweep.
export function railValue(result, bowl, skill, w, prefix = '') {
	const at = (result.data || {})[bowl];
	if (!at) return null;
	const places = placesFor(skill);
	const changed = new Array(VECTOR.length).fill(0);
	const placeCounts = new Array(HOST_SIZE + 1).fill(0);
	const perHost = [];
	let sum = 0;
	(result.hosts || []).forEach((host, i) => {
		const base = at[`${prefix}h|${i}`];
		if (!base) return;
		let best = -Infinity, bestPlace = -1, bestVector = null;
		for (const place of places) {
			const v = at[`${prefix}r|${skill}|${i}|${place}`];
			if (!v) continue;
			const value = power(v, w) - power(base, w);
			if (value > best) { best = value; bestPlace = place; bestVector = v; }
		}
		if (bestPlace < 0) return;
		sum += best;
		placeCounts[bestPlace] += 1;
		bestVector.forEach((x, j) => { changed[j] += x - base[j]; });
		perHost.push({ host: i, gems: host, value: best, place: bestPlace, runaway: (bestVector[RUNAWAY] || 0) > 0 });
	});
	const n = perHost.length;
	return n ? { value: sum / n, changed: changed.map((c) => c / n), places: placeCounts, perHost, runaways: perHost.filter((p) => p.runaway).length } : null;
}

// What the host rails do alone on a bowl, over the empty rail, averaged over the hosts.
export function hostValue(result, bowl, w, prefix = '') {
	const at = (result.data || {})[bowl];
	if (!at || !at[`${prefix}0`]) return NaN;
	let sum = 0, n = 0;
	(result.hosts || []).forEach((_, i) => { const v = at[`${prefix}h|${i}`]; if (v) { sum += power(v, w) - power(at[`${prefix}0`], w); n += 1; } });
	return n ? sum / n : NaN;
}

// A gem across the carats sweep's bands on a bowl: what it adds to the hosts at each band, what
// the hosts do alone there, and each band's kill line.
export function caratCurve(result, bowl, skill, w) {
	return (result.bands || []).map((band) => {
		const prefix = `${band.key}/`;
		const r = railValue(result, bowl, skill, w, prefix);
		return { band, value: r ? r.value : NaN, host: hostValue(result, bowl, w, prefix) };
	});
}

// What a gem does over a run and a long fight on a bowl, set into every host in its better
// place (the one better over the whole run): its value in each fight of the run, and in each
// turn of the long fight, over the same host without it.
export function growthValue(result, bowl, skill, w) {
	const at = (result.data || {})[bowl];
	if (!at) return null;
	const L = growthLayout(result.settings);
	const fightPower = (v, f) => Number(w.damage ?? 1) * v[L.fight(f)] + Number(w.saved ?? 0.7) * v[L.fight(f) + 1] + Number(w.gold ?? 0) * v[L.fight(f) + 2];
	const turnPower = (v, t) => Number(w.damage ?? 1) * v[L.turn(t)] + Number(w.saved ?? 0.7) * v[L.turn(t) + 1];
	const fights = new Array(L.fights).fill(0);
	const turns = new Array(L.turns).fill(0);
	let n = 0;
	(result.hosts || []).forEach((_, i) => {
		const base = at[`h|${i}`];
		if (!base) return;
		let best = null, bestTotal = -Infinity;
		for (const place of growthPlaces()) {
			const v = at[`r|${skill}|${i}|${place}`];
			if (!v) continue;
			let total = 0;
			for (let f = 0; f < L.fights; f++) total += fightPower(v, f) - fightPower(base, f);
			if (total > bestTotal) { bestTotal = total; best = v; }
		}
		if (!best) return;
		for (let f = 0; f < L.fights; f++) fights[f] += fightPower(best, f) - fightPower(base, f);
		for (let t = 0; t < L.turns; t++) turns[t] += turnPower(best, t) - turnPower(base, t);
		n += 1;
	});
	if (!n) return null;
	return { fights: fights.map((x) => x / n), turns: turns.map((x) => x / n) };
}

// The chance each inclusion is in a stone with `slots` slots, for this gem's color. Walking
// every draw order is slow for three slots, so each color's answer is kept.
const oddsCache = new Map();
export function inclusionOdds(skill, slots, mineKey) {
	const color = String(C.skill(skill).color || '');
	const key = `${color}|${slots}|${mineKey}`;
	if (!oddsCache.has(key)) oddsCache.set(key, Forge.inclusionOdds(slots, C.mine(mineKey), color));
	return oddsCache.get(key);
}

// What one inclusion adds to a gem on a bowl: alone, or beside a bare copy of itself, in its
// better place. Measured against the same gem bare in the same rail.
export function inclusionUplift(result, bowl, skill, inc, w) {
	if (railInclusion(inc)) {
		const bare = value(result, bowl, `f|${skill}||`, w);
		return Math.max(value(result, bowl, `f|${skill}|${inc}|a`, w), value(result, bowl, `f|${skill}|${inc}|b`, w)) - bare;
	}
	return value(result, bowl, `i|${skill}|${inc}`, w) - value(result, bowl, `i|${skill}|`, w);
}

// --- the hunt ----------------------------------------------------------------------------------
// A search for the strongest whole rails. For every bowl and every hunted band it starts from a
// few rails (the bowl's best gems alone, a random rail, a random rail ending in two opals) and
// walks each one socket at a time: every gem that could sit there and every swap with another
// socket is played in the boss fight on the same seeded fights, and the best of them is kept if
// it beats what is there by more than ACCEPT. A pass is every socket once; a search stops after
// a pass that changed nothing, or after `huntPasses`. Then every rail it found is played again
// on fresh fights, in both fights, beside the gems in it alone, the bowl's best gems alone
// (the plain rail) and a dozen random rails, so what it found is read against what a player
// would otherwise field.

export const huntPool = () => skillKeys().filter((k) => !HUNT_SKIP.includes(k));

function huntAllowed(rail, s) {
	const counts = new Map();
	let transcendent = 0;
	let opals = 0;
	for (const k of rail) {
		counts.set(k, (counts.get(k) || 0) + 1);
		if (counts.get(k) > s.copies) return false;
		if (C.skill(k).rarity === 'TRANSCENDENT') transcendent += 1;
		if (C.skill(k).color === C.OPAL) opals += 1;
	}
	return transcendent <= s.transcendent && (!s.opals || opals <= s.opals);
}

function randomRail(rng, n, pool, s, tail = []) {
	for (let guard = 0; guard < 200; guard++) {
		const rail = Array.from({ length: n - tail.length }, () => pool[rng.randiRange(0, pool.length - 1)]).concat(tail);
		if (huntAllowed(rail, s)) return rail;
	}
	return pool.slice(0, n);
}

// The bowl's best gems alone, strongest first, as many as it has sockets.
export function plainRail(bowl, leads, n) {
	return huntPool().filter((k) => C.skill(k).rarity !== 'TRANSCENDENT').sort((a, b) => (leads[b] ?? -Infinity) - (leads[a] ?? -Infinity)).slice(0, n);
}

function startRail(kind, bowl, band, leads, s, index) {
	const n = railLength(bowl);
	const pool = huntPool();
	const rng = makeRng(s.seed * 104729 + index * 7919 + 17);
	if (kind === 'plain') return plainRail(bowl, leads, n);
	if (kind === 'opals') {
		const opals = pool.filter((k) => C.skill(k).color === C.OPAL);
		const others = pool.filter((k) => C.skill(k).color !== C.OPAL);
		const tail = [];
		while (tail.length < Math.min(2, s.opals || 2)) { const k = opals[rng.randiRange(0, opals.length - 1)]; if (!tail.includes(k) && huntAllowed(tail.concat([k]), s)) tail.push(k); }
		return randomRail(rng, n, others, s, tail);
	}
	return randomRail(rng, n, pool, s);
}

const railKey = (rail) => rail.join(',');

function railSpec(rail, carat, s, leads, key) {
	const clarity = clarityOf(s.clarity);
	return { key, stones: rail.map((k) => [k, carat, s.cut, clarity, []]), policy: policyOf(leadOf(rail, leads)) };
}

function huntCandidates(search, s) {
	const rail = search.rail;
	const p = search.pos;
	const seen = new Set([railKey(rail)]);
	const out = [rail];
	const add = (next) => { const k = railKey(next); if (!seen.has(k) && huntAllowed(next, s)) { seen.add(k); out.push(next); } };
	for (const k of huntPool()) { if (k === rail[p]) continue; const next = rail.slice(); next[p] = k; add(next); }
	for (let q = 0; q < rail.length; q++) { if (q === p || rail[q] === rail[p]) continue; const next = rail.slice(); next[p] = rail[q]; next[q] = rail[p]; add(next); }
	return out;
}

function huntStart(job) {
	const s = job.settings;
	const leadsAll = job.context.leads || {};
	const bandList = s.huntBands.map(bandOf).filter(Boolean);
	job.bands = bandList;
	job.searches = [];
	job.runaways = new Map();
	let index = 0;
	for (const bowl of lapidaries()) {
		for (const band of bandList) {
			for (const start of HUNT_STARTS.slice(0, s.huntStarts)) {
				const rail = startRail(start, bowl, band, leadsAll[bowl] || {}, s, index++);
				job.searches.push({ bowl, band: band.key, start, rail, first: rail.slice(), score: NaN, pos: 0, pass: 0, still: 0, done: false, steps: [] });
			}
		}
	}
	job.phase = 'search';
}

function huntSearchTasks(job) {
	const s = job.settings;
	const leadsAll = job.context.leads || {};
	const groups = new Map();
	job.pending = new Map();
	job.searches.forEach((search, i) => {
		if (search.done) return;
		const band = bandOf(search.band);
		const cands = huntCandidates(search, s);
		job.pending.set(i, cands);
		const key = `${search.bowl}|${search.band}`;
		const group = groups.get(key) || { bowl: search.bowl, band, rails: [] };
		cands.forEach((rail, j) => group.rails.push(railSpec(rail, band.carat, s, leadsAll[search.bowl] || {}, `${i}|${j}`)));
		groups.set(key, group);
	});
	const tasks = [];
	for (const g of groups.values()) tasks.push(...chunk(g.rails, { sweep: 'hunt', bowl: g.bowl, band: g.band, settings: s, fights: ['boss'], stopAtWall: true }, (r) => s.samples * r.stones.length));
	return tasks;
}

function huntTakeSearch(job, results) {
	const s = job.settings;
	const w = { ...job.weights, fight: 'boss' };
	const scores = new Map();
	const loops = new Set();
	for (const r of results) {
		for (const [key, vector] of r.results) {
			if (vector[RUNAWAY] > 0) { loops.add(key); scores.set(key, -Infinity); } else scores.set(key, power(vector, w));
		}
	}
	job.searches.forEach((search, i) => {
		const cands = job.pending.get(i);
		if (!cands) return;
		// A runaway is kept aside, never walked to: it would win every search.
		cands.forEach((rail, j) => {
			if (!loops.has(`${i}|${j}`)) return;
			const key = `${search.bowl}|${search.band}|${railKey(rail)}`;
			if (!job.runaways.has(key) && job.runaways.size < MAX_RUNAWAYS) job.runaways.set(key, { bowl: search.bowl, band: search.band, rail: rail.slice() });
		});
		const current = scores.get(`${i}|0`);
		let best = 0;
		cands.forEach((_, j) => { if ((scores.get(`${i}|${j}`) ?? -Infinity) > (scores.get(`${i}|${best}`) ?? -Infinity)) best = j; });
		const bestScore = scores.get(`${i}|${best}`);
		search.score = current;
		if (best !== 0 && bestScore > current + Math.max(ACCEPT * Math.abs(current), 0.05)) {
			search.steps.push({ pass: search.pass, socket: search.pos, from: search.rail.slice(), to: cands[best].slice(), before: current, after: bestScore });
			search.rail = cands[best].slice();
			search.score = bestScore;
			search.still = 0;
		} else search.still += 1;
		search.pos += 1;
		if (search.pos >= search.rail.length) { search.pos = 0; search.pass += 1; }
		if (search.still >= search.rail.length || search.pass >= s.huntPasses) search.done = true;
	});
	job.round += 1;
	if (job.searches.every((x) => x.done)) job.phase = 'verify';
}

// The rails every hunted bowl and band is read against, and what the hunt found, on fresh fights.
function huntVerifyTasks(job) {
	const s = job.settings;
	const leadsAll = job.context.leads || {};
	const tasks = [];
	for (const bowl of lapidaries()) {
		const leads = leadsAll[bowl] || {};
		const n = railLength(bowl);
		for (const band of job.bands) {
			const found = job.searches.filter((x) => x.bowl === bowl && x.band === band.key);
			const rails = [baseline()];
			const seen = new Set();
			const solos = new Set();
			for (const x of found) {
				const k = railKey(x.rail);
				if (!seen.has(k)) { seen.add(k); rails.push(railSpec(x.rail, band.carat, s, leads, `b|${k}`)); }
				for (const g of x.rail) solos.add(g);
			}
			const plain = plainRail(bowl, leads, n);
			rails.push(railSpec(plain, band.carat, s, leads, `p|${railKey(plain)}`));
			for (const g of plain) solos.add(g);
			const rng = makeRng(s.seed * 15485863 + band.depth * 31 + n);
			for (let j = 0; j < RANDOM_RAILS; j++) rails.push(railSpec(randomRail(rng, n, huntPool(), s), band.carat, s, leads, `x|${j}`));
			for (const g of solos) rails.push(railSpec([g], band.carat, s, leads, `s|${g}`));
			tasks.push(...chunk(rails, { sweep: 'hunt', bowl, band, settings: s, samples: s.huntVerify, seedOffset: 1000003 }, (r) => 2 * s.huntVerify * Math.max(1, r.stones.length)));
		}
	}
	return tasks;
}

function huntFinish(job, results, meta) {
	const s = job.settings;
	const data = {};
	for (const r of results) {
		const at = ((data[r.bowl] || (data[r.bowl] = {}))[r.band] || (data[r.bowl][r.band] = {}));
		for (const [key, vector] of r.results) at[key] = vector;
	}
	const searches = job.searches.map((x) => ({ bowl: x.bowl, band: x.band, start: x.start, first: x.first, rail: x.rail, passes: x.pass + (x.pos ? 1 : 0), steps: x.steps }));
	return { sweep: 'hunt', settings: s, weights: job.weights, bowls: lapidaries(), skills: skillKeys(), bands: job.bands, vector: VECTOR, data, searches, rounds: job.round,
		runaways: [...job.runaways.values()], ...meta };
}

// Everything a hunt measured on a bowl at a band, read with the exchange rates `w`: each rail it
// found (value, its gems alone, synergy over them, the searches that ended there), the plain
// rail, the random rails (their median is "a random rail"), and the empty rail's power.
export function huntReport(result, bowl, bandKey, w) {
	const at = ((result.data || {})[bowl] || {})[bandKey];
	if (!at || !at['0']) return null;
	const base = power(at['0'], w);
	const val = (key) => (at[key] ? power(at[key], w) - base : NaN);
	const solo = (k) => val(`s|${k}`);
	const builds = [];
	for (const key of Object.keys(at)) {
		if (!key.startsWith('b|')) continue;
		const rail = key.slice(2).split(',');
		const parts = rail.reduce((sum, k) => sum + (Number.isFinite(solo(k)) ? solo(k) : 0), 0);
		const v = val(key);
		builds.push({ rail, key, value: v, parts, synergy: v - parts, vector: at[key], starts: (result.searches || []).filter((x) => x.bowl === bowl && x.band === bandKey && railKey(x.rail) === railKey(rail)).map((x) => x.start) });
	}
	builds.sort((a, b) => b.value - a.value);
	const plainKey = Object.keys(at).find((k) => k.startsWith('p|'));
	const plain = plainKey ? { rail: plainKey.slice(2).split(','), value: val(plainKey), vector: at[plainKey] } : null;
	const middle = (xs) => (xs.length ? (xs.length % 2 ? xs[(xs.length - 1) / 2] : (xs[xs.length / 2 - 1] + xs[xs.length / 2]) / 2) : NaN);
	const randomKeys = Object.keys(at).filter((k) => k.startsWith('x|'));
	const random = randomKeys.map((k) => val(k)).filter(Number.isFinite).sort((a, b) => a - b);
	const band = (result.bands || []).find((b) => b.key === bandKey);
	const turns = Math.max(1, Number((result.settings || {}).turns) || 1);
	const randomTurns = band ? middle(randomKeys.map((k) => killTurns(at[k], band.bossHp, turns)).sort((a, b) => a - b)) : NaN;
	return { builds, plain, random, randomMedian: middle(random), randomTurns, empty: at['0'], solo };
}

// What the runaway rails a hunt met have in common: every pair of neighbouring gems, in order,
// with how many of the runaways hold it, most first.
export function runawayCores(result) {
	const rails = (result && result.runaways) || [];
	const counts = new Map();
	for (const x of rails) {
		const seen = new Set();
		for (let i = 0; i + 1 < x.rail.length; i++) {
			const pair = `${x.rail[i]}>${x.rail[i + 1]}`;
			if (seen.has(pair)) continue;
			seen.add(pair);
			counts.set(pair, (counts.get(pair) || 0) + 1);
		}
	}
	return [...counts.entries()].map(([pair, n]) => ({ pair: pair.split('>'), count: n, share: n / Math.max(1, rails.length) })).sort((a, b) => b.count - a.count);
}

// --- running a sweep in rounds -----------------------------------------------------------------
// Every sweep is a job: `nextTasks` hands out a round of tasks (null when there are no more),
// `takeResults` folds that round's answers in, and `finishJob` makes the result to keep. One
// round for most; the hunt's next round depends on the last. `estimateTasks` is a guess at
// how many tasks the whole job will take, for progress bars.

export function startJob(sweep, settings, context = {}, weights = DEFAULT_WEIGHTS) {
	if (!SWEEPS.includes(sweep)) throw new Error(`unknown sweep ${sweep}`);
	const job = { sweep, settings: sweepSettings(settings, sweep), context, weights: { damage: weights.damage, saved: weights.saved, gold: weights.gold }, round: 0, results: [], tasks: [], done: false };
	if (sweep === 'hunt') huntStart(job);
	return job;
}

export function nextTasks(job) {
	if (job.done) return null;
	if (job.sweep !== 'hunt') {
		if (job.round > 0) return null;
		job.tasks = tasksFor(job.sweep, job.settings, job.context);
		return job.tasks;
	}
	if (job.phase === 'search') { const tasks = huntSearchTasks(job); job.lastRound = tasks.length; return tasks; }
	if (job.phase === 'verify') return huntVerifyTasks(job);
	return null;
}

export function takeResults(job, results) {
	if (job.sweep !== 'hunt') { job.results = results; job.round += 1; job.done = true; return; }
	if (job.phase === 'search') { huntTakeSearch(job, results); return; }
	job.results = results;
	job.phase = 'finished';
	job.done = true;
}

export function finishJob(job, meta = {}) {
	if (job.sweep === 'hunt') return huntFinish(job, job.results, meta);
	return assemble(job.sweep, job.tasks, job.results, meta);
}

// How many tasks the job has left, as best it can be told (a search may stop early).
export function estimateTasks(job) {
	if (job.sweep !== 'hunt') return job.round ? 0 : tasksFor(job.sweep, job.settings, job.context).length;
	const s = job.settings;
	const active = job.searches.filter((x) => !x.done);
	if (job.phase !== 'search') return job.phase === 'verify' ? huntVerifyTasks(job).length : 0;
	const perRound = Math.max(1, job.lastRound || Math.ceil((active.length * (huntPool().length + 6) * s.samples * 6) / 9000));
	const left = active.reduce((m, x) => Math.max(m, (s.huntPasses - x.pass) * x.rail.length - x.pos), 0);
	return perRound * left + lapidaries().length * job.bands.length * 2;
}

// Roughly how long a sweep takes on one core, in seconds, for the page's estimates.
export function estimateSeconds(sweep, settings, context = {}) {
	const s = sweepSettings(settings, sweep);
	const fight = (stones, turns = s.turns) => (120 + 60 * stones) * (turns / 4) / 1e6;
	if (sweep === 'hunt') {
		const n = 6;
		const searches = lapidaries().length * s.huntBands.length * s.huntStarts;
		const rounds = Math.min(s.huntPasses, 2) * n + n;
		const search = searches * rounds * (huntPool().length + n) * s.samples * fight(n) * 1.4;
		const verify = lapidaries().length * s.huntBands.length * (s.huntStarts + 1 + RANDOM_RAILS + 3 * n) * s.huntVerify * 2 * fight(n);
		return search + verify;
	}
	let seconds = 0;
	for (const t of tasksFor(sweep, s, context)) {
		for (const r of t.rails) {
			const stones = r.stones.length;
			seconds += t.growth ? s.samples * (s.runFights * fight(stones) + fight(stones, s.longTurns)) : 2 * s.samples * fight(stones);
		}
	}
	return seconds;
}
