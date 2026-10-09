// Balance sweeps: what every gem, Cut, Clarity, inclusion and pairing is worth in a short
// fight against training dummies (fight.js), on every lapidary's own bowl with their passive
// and Birthstone. Pure functions over the pack, shared by the browser's workers and by
// tools/data-browser/balance.mjs.
//
// A sweep is a list of rails, each played `samples` times on every bowl. Every rail on a bowl
// plays the same seeded fights (see playFight), so what one rail does better than another is
// the rail and not the dice. Each rail comes back as a vector of means (VECTOR); a value is
// always measured against the empty rail on the same bowl, which is what the Birthstone and
// passive do on their own:
//
//   power  = damage × dealt + saved × (incoming − lost + healed) + gold × pyrite won
//   value  = power(rail) − power(empty rail)
//
// so the exchange rates can change on the page without playing anything again.

import * as C from './content.js';
import * as Stone from './stone.js';
import * as Forge from './forge.js';
import { playFight } from './fight.js';
import { policyFor } from './simulate.js';
import { makeRng } from './rng.js';

export const SWEEPS = ['gems', 'cutclarity', 'inclusions', 'pairs', 'rails'];
export const VECTOR = ['dealt', 'saved', 'gold', 'fires', 'birthstone', 'resonance', 'blockGained', 'healed', 'hpLost', 'downs', 'kills'];
export const DEFAULT_WEIGHTS = { damage: 1, saved: 0.7, gold: 0 };
// The fight every sweep is played in. A dummy throws a d8 and a d6 each action and raises a
// little block as it does: two of them come at the player for about what a mid-depth
// encounter does (two creatures, sixteen or so a turn), each with sixty health, about a
// mid-depth creature: overkill is wasted, poison dies with its creature and a kill saves the
// blows it would have thrown. dummyHp 0 makes them endless, which counts everything a gem
// does but lets anything that feeds on itself (poison, House Money's pot) run away.
export const DEFAULTS = { turns: 4, dummies: 2, dummyDice: ['D8', 'D6'], dummyHp: 60, guard: 3, pyrite: 60, depth: 3, carat: 8, cut: 2, clarity: 'CLEAR',
	birthstone: true, passive: true, mine: 'QUARRY', seed: 1, hosts: 24, samples: { gems: 1000, cutclarity: 300, inclusions: 300, pairs: 300, rails: 150 } };
export const CLARITY_RUNGS = ['CLEAR', 'PRISTINE', 'FLAWLESS'];
// What a fight can only measure with a neighbour: these are judged beside a bare copy of
// their own gem, before it and after it, rather than alone.
export const RAIL_CLASSES = ['FEATHER'];
// The rails sweep sets every gem into rails of this many others (the host): an opal does
// nothing alone, and a single partner never rings the rail loud enough to wake one.
export const HOST_SIZE = 4;

// The settings a sweep's numbers depend on (the exchange rates are not among them).
export function sweepSettings(settings, sweep) {
	const s = { ...DEFAULTS, ...settings };
	const out = { turns: s.turns | 0, dummies: s.dummies | 0, dummyDice: s.dummyDice.slice(), dummyHp: s.dummyHp | 0, guard: s.guard | 0, pyrite: s.pyrite | 0, depth: s.depth | 0, carat: s.carat | 0,
		cut: s.cut | 0, clarity: s.clarity, birthstone: Boolean(s.birthstone), passive: Boolean(s.passive), mine: s.mine, seed: s.seed | 0,
		samples: typeof s.samples === 'number' ? s.samples : Number((s.samples || {})[sweep] ?? DEFAULTS.samples[sweep]) };
	if (sweep === 'rails') out.hosts = Math.max(1, s.hosts | 0);
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

export function power(v, w = DEFAULT_WEIGHTS) {
	if (!v) return NaN;
	return Number(w.damage ?? 1) * v[0] + Number(w.saved ?? 0.7) * v[1] + Number(w.gold ?? 0) * v[2];
}

// --- what is played ---------------------------------------------------------------------------
// A rail travels to a worker as {key, stones: [[skill, carat, cut, clarity, inclusions]], policy}.

const baseline = () => ({ key: '0', stones: [], policy: 'none' });

function gemRails(s) {
	const clarity = clarityOf(s.clarity);
	return [baseline(), ...skillKeys().map((k) => ({ key: `s|${k}`, stones: [[k, s.carat, s.cut, clarity, []]], policy: policyOf(k) }))];
}

function cutClarityRails(s) {
	const out = [baseline()];
	for (const k of skillKeys()) {
		for (let cut = 0; cut < C.cuts().length; cut++) {
			for (const rung of CLARITY_RUNGS) out.push({ key: `c|${k}|${cut}|${clarityOf(rung)}`, stones: [[k, s.carat, cut, clarityOf(rung), []]], policy: policyOf(k) });
		}
	}
	return out;
}

// Inclusions a stone of this colour can grow: never a Zoning of its own colour.
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
// opals, the same on every bowl, fixed by the seed.
export function hostsFor(settings) {
	const s = sweepSettings(settings, 'rails');
	const pool = skillKeys().filter((k) => C.skill(k).color !== C.OPAL);
	const rng = makeRng(s.seed * 7907 + 101);
	return Array.from({ length: s.hosts }, () => {
		const picked = [];
		while (picked.length < HOST_SIZE) { const k = pool[rng.randiRange(0, pool.length - 1)]; if (!picked.includes(k)) picked.push(k); }
		return picked;
	});
}

// Where a gem is tried in a host: an opal in every place (a Seam wants the gems it replays
// before it, a Prelude the gem it repeats after it), anything else first or last.
export const placesFor = (skill) => (C.skill(skill).color === C.OPAL ? Array.from({ length: HOST_SIZE + 1 }, (_, i) => i) : [0, HOST_SIZE]);

// Every host alone, and every gem set into every host in each of its places. A rail chases
// the trigger of whichever of its gems does most alone on this bowl.
function railRails(s, leads) {
	const clarity = clarityOf(s.clarity);
	const stone = (k) => [k, s.carat, s.cut, clarity, []];
	const leadOf = (keys) => keys.reduce((best, k) => ((leads[k] ?? 0) > (leads[best] ?? 0) ? k : best), keys[0]);
	const out = [baseline()];
	hostsFor(s).forEach((host, i) => {
		out.push({ key: `h|${i}`, stones: host.map(stone), policy: policyOf(leadOf(host)) });
		for (const k of skillKeys()) {
			for (const place of placesFor(k)) {
				const keys = host.slice();
				keys.splice(place, 0, k);
				out.push({ key: `r|${k}|${i}|${place}`, stones: keys.map(stone), policy: policyOf(leadOf(keys)) });
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

// The work of a sweep, cut into tasks of a second or two each. `context.leads` is
// {bowl: {skill: solo power}} for the pairs sweep.
export function tasksFor(sweep, settings, context = {}) {
	const s = sweepSettings(settings, sweep);
	const tasks = [];
	for (const bowl of lapidaries()) {
		let rails;
		if (sweep === 'gems') rails = gemRails(s);
		else if (sweep === 'cutclarity') rails = cutClarityRails(s);
		else if (sweep === 'inclusions') rails = inclusionRails(s);
		else if (sweep === 'pairs') rails = pairRails(s, (context.leads || {})[bowl] || {});
		else if (sweep === 'rails') rails = railRails(s, (context.leads || {})[bowl] || {});
		else throw new Error(`unknown sweep ${sweep}`);
		let chunk = [];
		let weight = 0;
		for (const rail of rails) {
			chunk.push(rail);
			weight += s.samples * Math.max(1, rail.stones.length);
			if (weight >= 9000) { tasks.push({ sweep, bowl, rails: chunk, settings: s }); chunk = []; weight = 0; }
		}
		if (chunk.length) tasks.push({ sweep, bowl, rails: chunk, settings: s });
	}
	return tasks;
}

// Play one task: every rail in it on its bowl, `samples` fights each. Returns {bowl, results:
// [[key, vector]]}.
export function runTask(task) {
	const s = task.settings;
	const results = [];
	for (const rail of task.rails) {
		const spec = { character: task.bowl, rail: rail.stones.map((st, i) => Stone.make(st[0], st[1], st[2], st[3], st[4] || [], `g${i}`)), policy: rail.policy, turns: s.turns,
			dummies: { count: s.dummies, dice: s.dummyDice, guard: s.guard, hp: s.dummyHp }, pyrite: s.pyrite, depth: s.depth, birthstone: s.birthstone, passive: s.passive, seed: s.seed };
		const sums = new Array(VECTOR.length).fill(0);
		for (let i = 0; i < s.samples; i++) {
			const m = playFight(spec, i);
			sums[0] += m.dealt; sums[1] += m.incoming - m.hpLost + m.healed; sums[2] += m.gold; sums[3] += m.fires; sums[4] += m.birthstone;
			sums[5] += m.resonance; sums[6] += m.blockGained; sums[7] += m.healed; sums[8] += m.hpLost; sums[9] += m.downs; sums[10] += m.kills;
		}
		results.push([rail.key, sums.map((v) => Math.round((v / s.samples) * 1000) / 1000)]);
	}
	return { bowl: task.bowl, results };
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
	return { sweep, settings, bowls: lapidaries(), skills: skillKeys(), vector: VECTOR, data, ...(sweep === 'rails' ? { hosts: hostsFor(settings) } : {}), ...meta };
}

// --- reading a sweep --------------------------------------------------------------------------

// A rail's value on a bowl: its power over the empty rail's.
export function value(result, bowl, key, w) {
	const at = (result.data || {})[bowl];
	if (!at || !at[key] || !at['0']) return NaN;
	return power(at[key], w) - power(at['0'], w);
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
	for (const bowl of gems.bowls || []) {
		out[bowl] = {};
		for (const k of gems.skills || []) out[bowl][k] = value(gems, bowl, `s|${k}`, w);
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
export function railValue(result, bowl, skill, w) {
	const at = (result.data || {})[bowl];
	if (!at) return null;
	const places = placesFor(skill);
	const changed = new Array(VECTOR.length).fill(0);
	const placeCounts = new Array(HOST_SIZE + 1).fill(0);
	const perHost = [];
	let sum = 0;
	(result.hosts || []).forEach((host, i) => {
		const base = at[`h|${i}`];
		if (!base) return;
		let best = -Infinity, bestPlace = -1, bestVector = null;
		for (const place of places) {
			const v = at[`r|${skill}|${i}|${place}`];
			if (!v) continue;
			const value = power(v, w) - power(base, w);
			if (value > best) { best = value; bestPlace = place; bestVector = v; }
		}
		if (bestPlace < 0) return;
		sum += best;
		placeCounts[bestPlace] += 1;
		bestVector.forEach((x, j) => { changed[j] += x - base[j]; });
		perHost.push({ host: i, gems: host, value: best, place: bestPlace });
	});
	const n = perHost.length;
	return n ? { value: sum / n, changed: changed.map((c) => c / n), places: placeCounts, perHost } : null;
}

// The chance each inclusion is in a stone with `slots` slots, for this gem's colour. Walking
// every draw order is slow for three slots, so each colour's answer is kept.
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
