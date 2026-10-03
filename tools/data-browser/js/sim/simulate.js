// Monte Carlo over hands, creature turns, encounters and stones. Pure functions over the pack;
// the worker runs them off the main thread and the engine caches their answers.

import * as C from './content.js';
import * as Dice from './dice.js';
import * as Hand from './hand.js';
import * as Patterns from './patterns.js';
import * as Rules from './rules.js';
import * as Stone from './stone.js';
import * as Forge from './forge.js';
import { makeRng } from './rng.js';

// A bowl from what the browser is set to: each entry is a shape, or an object carrying the
// variations that die was made with.
export function buildBowl(keys, variations = []) {
	return keys.map((key, i) => {
		const extra = variations[i] || {};
		if (key && typeof key === 'object') return Dice.dieFrom(key, `d${i}`);
		return Dice.make(String(key), `d${i}`, extra);
	});
}

// --- reroll policies -----------------------------------------------------------------------
// Which dice a player chasing a trigger would throw again. Each returns the ids to reroll.

const keepIds = (hand, keep) => new Set(hand.filter((r) => !keep.has(r.die_id) && r.kind !== 'wild' && r.kind !== 'gem' && !r.locked).map((r) => r.die_id));

export function policyFor(trigger) {
	const kind = trigger.kind || 'always';
	switch (kind) {
		case 'pair': case 'triple': case 'quad': case 'quint': case 'two_pair': case 'full_house': return 'sets';
		case 'straight': return 'straight';
		case 'odd': case 'all_odd': return 'odd';
		case 'even': case 'all_even': return 'even';
		case 'distinct': case 'distinct_dominant': return 'distinct';
		case 'skip_straight': return 'skip';
		case 'value': return `value:${(trigger.values || [7]).join(',')}`;
		case 'at_most': case 'below': return 'low';
		case 'low_count': case 'total_pct_at_most': return 'low';
		case 'at_least': case 'high_pct_at_least': case 'total_pct_at_least': return 'high';
		case 'crowns': return 'high';
		case 'crowns_at_most': return 'low';
		case 'held': return 'none';
		case 'rerolled': return 'all';
		case 'always': {
			const read = trigger.read;
			const lowAtAnyCut = Array.isArray(read) ? read.includes('low') : read === 'low';
			return lowAtAnyCut ? 'always' : 'high';
		}
		default: return 'none';
	}
}

export function rerollIds(policy, hand, a, cutHint = 4) {
	if (policy === 'none') return new Set();
	if (policy === 'all') return new Set(hand.filter((r) => !r.locked).map((r) => r.die_id));
	const keep = new Set();
	if (policy === 'sets') {
		const groups = a.groups;
		if (groups.length && groups[0].count >= 2) {
			for (const id of groups[0].dice) keep.add(id);
			if (groups.length > 1 && groups[1].count >= 2) for (const id of groups[1].dice) keep.add(id);
		} else {
			// Nothing paired yet: keep the highest die and fish for its twin.
			let best = null;
			for (const r of hand) if (r.kind !== 'blank' && (!best || r.value > best.value)) best = r;
			if (best) keep.add(best.die_id);
		}
	} else if (policy === 'straight') {
		for (const id of a.straight.dice) keep.add(id);
	} else if (policy === 'odd' || policy === 'even') {
		const wantOdd = policy === 'odd';
		for (const r of hand) if (r.kind !== 'blank' && (r.value % 2 === 1) === wantOdd) keep.add(r.die_id);
	} else if (policy === 'distinct') {
		for (const ids of a.ids_by_value.values()) keep.add(ids[0]);
	} else if (policy === 'skip') {
		const wantOdd = a.odd_values >= a.even_values;
		for (const [v, ids] of a.ids_by_value) if ((v % 2 === 1) === wantOdd) keep.add(ids[0]);
	} else if (policy.startsWith('value:')) {
		const wanted = policy.slice(6).split(',').map(Number);
		for (const r of hand) if (wanted.includes(r.value)) keep.add(r.die_id);
	} else if (policy === 'low') {
		for (const r of hand) if (r.kind !== 'blank' && r.value * 2 <= Math.max(1, r.top)) keep.add(r.die_id);
	} else if (policy === 'high') {
		for (const r of hand) if (r.kind !== 'blank' && r.value * 2 > Math.max(1, r.top)) keep.add(r.die_id);
	} else if (policy === 'always') {
		// A stone that reads the low end at bad cuts and the high end at good ones: chase the
		// end the reference cut reads.
		for (const r of hand) if (r.kind !== 'blank' && r.value * 2 > Math.max(1, r.top)) keep.add(r.die_id);
	}
	return keepIds(hand, keep);
}

// Roll a hand and spend up to `rerolls` rerolls chasing `policy`.
export function playHand(dice, rng, policy, rerolls) {
	let hand = Dice.rollHand(dice, rng);
	for (let r = 0; r < rerolls; r++) {
		const a = Hand.analyze(hand);
		const ids = rerollIds(policy, hand, a);
		if (!ids.size) break;
		hand = Dice.reroll(hand, dice, ids, rng);
	}
	return hand;
}

// --- skills ----------------------------------------------------------------------------------

export function headlineKind(skill) {
	const first = (skill.effects || [])[0];
	return first ? String(first.kind || 'damage') : '';
}

// Fire rate and expected effect of a set of skills, per Cut, against one bowl. `stone` names
// the carat, clarity and inclusions every skill is judged as; `context` is the rail context.
export function skillStats({ bowl, variations = [], rerolls = 2, samples = 4000, seed = 7, skills, stone = {}, context = {} }, report = null) {
	const dice = buildBowl(bowl, variations);
	const carat = stone.carat ?? 8;
	const clarity = stone.clarity ?? C.clearIndex();
	const inclusions = stone.inclusions || [];
	const ctx = { resonance: context.resonance | 0, previous_amount: context.previous_amount | 0, previous_fired: Boolean(context.previous_fired), enemy_poison: context.enemy_poison | 0,
		depth: context.depth | 0, turn: context.turn | 0, party: context.party | 0 || 1,
		unit: { block: context.block | 0, block_lost: context.block_lost | 0, healed: context.healed | 0, dealt: context.dealt | 0, hp: context.hp | 0, max_hp: context.max_hp | 0, ore: context.pyrite | 0 } };
	const groups = new Map();
	for (const key of skills) {
		const def = C.skill(key);
		if (!Object.keys(def).length) continue;
		const policy = policyFor(def.trigger || {});
		if (!groups.has(policy)) groups.set(policy, []);
		groups.get(policy).push(key);
	}
	const out = {};
	let done = 0;
	const total = groups.size;
	for (const [policy, keys] of groups) {
		const rng = makeRng(seed * 7919 + policy.length);
		const stats = {};
		for (const key of keys) {
			stats[key] = Array.from({ length: Patterns.STEPS }, () => ({ fired: 0, sum: 0, sumFired: 0, kinds: {}, hist: new Map(), procsSum: 0, resonanceSum: 0 }));
		}
		const stones = Object.fromEntries(keys.map((key) => [key, Array.from({ length: Patterns.STEPS }, (_, cut) => Stone.make(key, carat, cut, clarity, inclusions))]));
		const hasLens = keys.some((key) => Stone.modifiers(stones[key][0]).some((m) => m.kind === 'lens'));
		for (let i = 0; i < samples; i++) {
			const hand = playHand(dice, rng, policy, rerolls);
			const analysis = hasLens ? null : Hand.analyze(hand);
			for (const key of keys) {
				const def = C.skill(key);
				const headline = headlineKind(def);
				for (let cut = 0; cut < Patterns.STEPS; cut++) {
					const ev = evaluateWith(stones[key][cut], hand, ctx, analysis);
					const s = stats[key][cut];
					if (!ev.active) continue;
					s.fired += 1;
					const totals = Stone.totals(ev);
					for (const kind in totals) s.kinds[kind] = (s.kinds[kind] || 0) + totals[kind] * Math.max(1, ev.fires);
					const head = (totals[headline] || 0) * Math.max(1, ev.fires);
					s.sum += head;
					s.sumFired += head;
					s.resonanceSum += ev.resonance_gain * Math.max(1, ev.fires);
					const bucket = Math.round(head);
					s.hist.set(bucket, (s.hist.get(bucket) || 0) + 1);
				}
			}
		}
		for (const key of keys) {
			const def = C.skill(key);
			out[key] = { policy, headline: headlineKind(def), cuts: stats[key].map((s) => ({
				fireRate: s.fired / samples,
				ev: s.sum / samples,
				evFired: s.fired ? s.sumFired / s.fired : 0,
				kinds: Object.fromEntries(Object.entries(s.kinds).map(([k, v]) => [k, v / samples])),
				resonance: s.resonanceSum / samples,
				hist: [...s.hist].sort((a, b) => a[0] - b[0]).map(([v, n]) => [v, n / samples]),
			})) };
		}
		done += 1;
		if (report) report(done / total);
	}
	return { samples, rerolls, bowl, skills: out };
}

// Stone.evaluate, given an analysis already worked out for this hand when no lens is in play.
function evaluateWith(stone, hand, c, analysis) {
	if (!analysis) return Stone.evaluate(stone, hand, c);
	const skill = Stone.skillOf(stone);
	const eff = Stone.effective(stone, c);
	const mods = eff.modifiers;
	const trigger = skill.trigger || { kind: 'always' };
	const trig = Patterns.evaluate(trigger, eff.cut_step, analysis, { resonance: c.resonance | 0, pyrite: Rules.pyrite(c.unit || {}) });
	if (!trig.active && Stone.hasModifier(mods, 'always_fires')) {
		trig.active = true; trig.forced = true; trig.dice = Hand.matching(analysis, () => true);
		trig.value = analysis.best_set.value || analysis.high; trig.count = Math.max(1, analysis.best_set.count || 1);
	}
	for (const m of mods) if (m.kind === 'fizzle_on_value' && trig.active && analysis.ids_by_value.has(Number(m.value ?? 1))) trig.active = false;
	const result = { active: Boolean(trig.active), trigger: trig, effects: [], fires: trig.active ? 1 : 0, resonance_gain: 0, magnitude: eff.magnitude };
	if (!trig.active) return result;
	const tc = { a: analysis, trig, unit: c.unit || {}, resonance: c.resonance | 0, previous_amount: c.previous_amount | 0, carat: eff.carat, cut: eff.cut_step, clarity: eff.clarity,
		enemy_poison: c.enemy_poison | 0, depth: c.depth | 0, turn: c.turn | 0, party: c.party | 0 || 1 };
	let defs = skill.effects || [];
	if (eff.flawless && skill.flawless && typeof skill.flawless === 'object') defs = Stone.applyFlawless(defs, skill.flawless);
	for (const def of defs) if (def && typeof def === 'object') result.effects.push(Rules.resolveEffect(def, tc, eff.magnitude));
	const perDie = Stone.modifierSum(mods, 'per_die_damage');
	if (perDie > 0) for (const effect of result.effects) if (effect.kind === 'damage') effect.amount += perDie * (trig.dice || []).length;
	for (const m of mods) if (m.kind === 'rider') for (const def of m.effects || []) if (def && typeof def === 'object') result.effects.push(Rules.resolveEffect(def, tc, eff.magnitude));
	result.resonance_gain = Math.round((1 + Stone.modifierSum(mods, 'resonance_bonus')) * eff.resonance_mult);
	if (Stone.hasModifier(mods, 'fires_twice')) result.fires += 1;
	if (Stone.hasModifier(mods, 'retrigger_if_previous_fired') && c.previous_fired) result.fires += 1;
	return result;
}

// How often bare triggers fire against a bowl: {kind, amount|ladder, values} each, judged at
// `cut`. Used for Birthstone tiers, creature-style patterns and the dice page.
export function triggerOdds({ bowl, variations = [], rerolls = 2, samples = 4000, seed = 13, triggers, cut = 0, chase = true }) {
	const dice = buildBowl(bowl, variations);
	const out = triggers.map(() => ({ fired: 0, valueSum: 0, countSum: 0 }));
	const groups = new Map();
	triggers.forEach((t, i) => { const p = chase ? policyFor(t) : 'none'; if (!groups.has(p)) groups.set(p, []); groups.get(p).push(i); });
	for (const [policy, indices] of groups) {
		const rng = makeRng(seed * 811 + policy.length * 3 + rerolls);
		for (let s = 0; s < samples; s++) {
			const hand = playHand(dice, rng, policy, rerolls);
			const a = Hand.analyze(hand);
			for (const i of indices) {
				const trig = Patterns.evaluate(triggers[i], cut, a, {});
				if (trig.active) { out[i].fired += 1; out[i].valueSum += trig.value | 0; out[i].countSum += trig.count | 0; }
			}
		}
	}
	return { samples, rerolls, results: out.map((o) => ({ fireRate: o.fired / samples, meanValue: o.fired ? o.valueSum / o.fired : 0, meanCount: o.fired ? o.countSum / o.fired : 0 })) };
}

// --- hands -----------------------------------------------------------------------------------

// What a bowl tends to show: pattern odds and the shape of its totals and high dice.
export function handStats({ bowl, variations = [], rerolls = 0, policy = 'sets', samples = 6000, seed = 11 }) {
	const dice = buildBowl(bowl, variations);
	const rng = makeRng(seed * 104729 + rerolls);
	const patterns = { pair: 0, two_pair: 0, triple: 0, full_house: 0, quad: 0, quint: 0, straight3: 0, straight4: 0, straight5: 0, distinct5: 0, distinct4: 0, allOdd: 0, allEven: 0, anyCrown: 0, anyOne: 0 };
	const totals = new Map(), highs = new Map(), lows = new Map(), distinct = new Map(), odd = new Map(), lowDice = new Map(), crowns = new Map(), highPct = new Map(), totalPct = new Map();
	const bump = (m, k) => m.set(k, (m.get(k) || 0) + 1);
	for (let i = 0; i < samples; i++) {
		const hand = playHand(dice, rng, policy, rerolls);
		const a = Hand.analyze(hand);
		const best = a.best_set.count || 0;
		if (best >= 2) patterns.pair += 1;
		if (best >= 3) patterns.triple += 1;
		if (best >= 4) patterns.quad += 1;
		if (best >= 5) patterns.quint += 1;
		if (a.pairs.length >= 2) patterns.two_pair += 1;
		if (a.groups.length >= 2 && a.groups[0].count >= 3 && a.groups[1].count >= 2) patterns.full_house += 1;
		if (a.straight.length >= 3) patterns.straight3 += 1;
		if (a.straight.length >= 4) patterns.straight4 += 1;
		if (a.straight.length >= 5) patterns.straight5 += 1;
		if (a.distinct >= 4) patterns.distinct4 += 1;
		if (a.distinct >= 5) patterns.distinct5 += 1;
		if (a.odd === a.dice_count) patterns.allOdd += 1;
		if (a.even === a.dice_count) patterns.allEven += 1;
		if (a.crowns > 0) patterns.anyCrown += 1;
		if (a.ids_by_value.has(1)) patterns.anyOne += 1;
		bump(totals, a.total); bump(highs, a.high); bump(lows, a.low); bump(distinct, a.distinct); bump(odd, a.odd); bump(lowDice, a.low_dice); bump(crowns, a.crowns);
		bump(highPct, Math.floor(a.high_pct / 5) * 5); bump(totalPct, Math.floor((a.total * 100) / a.max_total / 5) * 5);
	}
	const dist = (m) => [...m].sort((a, b) => a[0] - b[0]).map(([k, n]) => [k, n / samples]);
	for (const k in patterns) patterns[k] /= samples;
	return { samples, rerolls, policy, patterns, totals: dist(totals), highs: dist(highs), lows: dist(lows), distinct: dist(distinct), odd: dist(odd), lowDice: dist(lowDice), crowns: dist(crowns), highPct: dist(highPct), totalPct: dist(totalPct),
		maxTotal: dice.reduce((s, d) => s + Dice.top(d), 0) };
}

// --- creatures -------------------------------------------------------------------------------

const COMBINATIONS = ['pair', 'triple', 'quad', 'quint', 'two_pair', 'full_house', 'straight', 'all_odd', 'all_even'];
const isCombination = (move) => COMBINATIONS.includes(((move.trigger || {}).kind) || 'always');
const isTurnMove = (move) => Patterns.TURN_KINDS.includes(((move.trigger || {}).kind) || 'always');

export function creatureMoves(def, phase = 0) {
	const phases = def.phases || [];
	return phase > 0 && phases[phase - 1] ? phases[phase - 1].moves || [] : def.moves || [];
}

// Everything a creature is in a phase (sim/creatures.gd traits_for): its written traits, its
// old-style gimmick read as one, and whatever the phase adds or takes away (0 or false removes).
export function traitsFor(def, phase = 0) {
	const out = { ...(def.traits || {}) };
	const gimmick = String(def.gimmick || '');
	if (gimmick && !(gimmick in out)) out[gimmick] = true;
	const phases = def.phases || [];
	if (phase > 0 && phases[phase - 1]) Object.assign(out, phases[phase - 1].traits || {});
	for (const key of Object.keys(out)) {
		const value = out[key];
		if (value === false || (typeof value === 'number' && value <= 0)) delete out[key];
	}
	return out;
}

export function traitValue(traits, name, fallback = 0) {
	const value = traits ? traits[name] : undefined;
	if (value === undefined || value === null) return fallback;
	if (typeof value === 'boolean') return value ? 1 : 0;
	return Math.trunc(Number(value) || 0);
}

// The mine's damage multiplier as a whole percentage, grown by a Rising creature's share for
// every action it has taken (sim/creatures.gd damage_pct).
export function damagePct(damageMult, traits, turnsActed) {
	let pct = Number(damageMult || 1) * 100;
	const rising = traitValue(traits, 'rising');
	if (rising > 0) pct *= Math.pow(1 + rising / 100, Math.max(0, turnsActed));
	return Math.round(pct);
}

// For a move that fires every nth action: how many actions away the next one is, counting the
// action about to come as 1 (sim/creatures.gd next_nth_in).
export function nextNthIn(move, action) {
	const every = Number(((move.trigger || {}).amount) || 0);
	if (every <= 0) return 0;
	const wait = (every - (action % every)) % every;
	return wait + 1;
}

// One creature's action, many times over: how often each move fires and what it does to the
// party. `action` is which of its actions this is (1 = its first), `mineKey` the mine whose
// damage multiplier it fights with, `emerging` whether it has just come up out of the floor.
// Damage per move follows sim/creatures.gd resolved_move: pct(raw, damage_pct) + damage_bonus
// + rally, with the enrage the fight adds on top; `once` moves are taken as spent after action 1
// and an Escalating creature as having spent every earlier action in this phase.
export function creatureTurn({ key, depth = 1, party = 1, phase = 0, turn = 1, action = 1, mineKey = '', emerging = false, samples = 6000, seed = 3 }) {
	const def = C.creature(key);
	const mine = mineKey ? C.mine(mineKey) : null;
	phase = Math.max(0, Math.min(phase | 0, (def.phases || []).length));
	action = Math.max(1, action | 0);
	const moves = creatureMoves(def, phase);
	const traits = traitsFor(def, phase);
	const dice = (def.dice || []).map((k, i) => Dice.dieFrom(k, `${key}_d${i}`));
	const rng = makeRng(seed * 31 + depth * 7 + party + action * 101);
	const scale = Forge.creatureScale(mine, depth);
	const turnsActed = action - 1;
	const pct = damagePct(scale.damage, traits, turnsActed);
	let damageBonus = Forge.creatureDamageBonus(def, depth);
	const escalate = traitValue(traits, 'escalate');
	if (escalate > 0) damageBonus += escalate * turnsActed;
	const enrageTurn = Number(C.constant('enrage_turn', 7));
	const enrage = Math.max(0, turn - enrageTurn + 1) * Number(C.constant('enrage_damage', 2));
	const living = Math.max(1, Math.min(4, party));
	const perMove = moves.map(() => ({ fired: 0, damage: 0, piercing: 0, release: 0, effects: {} }));
	const damageHist = new Map();
	let damageSum = 0;
	const hit = (effect, rally) => {
		let amount = Rules.amount({ op: 'pct', args: [effect.amount, pct] }, {}) + damageBonus + rally + enrage;
		if (effect.split_party) amount = Math.ceil(amount / living);
		return amount * Math.max(1, effect.repeat);
	};
	for (let i = 0; i < samples; i++) {
		const history = [];
		const used = new Set();
		let rally = 0;
		let turnDamage = 0;
		for (let d = 0; d < dice.length; d++) {
			const roll = Dice.rollOne(dice[d], rng);
			history.push(roll);
			const last = d === dice.length - 1;
			const ctx = { first_roll: d === 0, roll_index: d, turns_acted: action, emerging: Boolean(emerging), dying: false, turn, party, living_players: living, party_heaviest_carat: 0, party_best_turn: 0, depth };
			for (let m = 0; m < moves.length; m++) {
				const move = moves[m];
				const trigger = move.trigger || { kind: 'always' };
				const kind = trigger.kind || 'always';
				if (kind === 'on_death') continue;
				if (move.once && action !== 1) continue;
				const combo = isCombination(move);
				const turnMove = isTurnMove(move);
				if ((combo || turnMove) && used.has(m)) continue;
				const read = combo ? history : [roll];
				const a = Hand.analyze(read);
				const trig = Patterns.evaluate(trigger, 0, a, ctx);
				if ((kind === 'all_odd' || kind === 'all_even') && !last) trig.active = false;
				// A move that reads one die in particular ignores the others.
				if ('die' in trigger && !combo && !turnMove && d !== Number(trigger.die)) trig.active = false;
				if (!trig.active) continue;
				if (combo || turnMove) used.add(m);
				perMove[m].fired += 1;
				const c = { ...ctx, a, trig, rolled: roll.value, unit: { turns_acted: turnsActed, swell: 0, held_gems: [], biggest_hit: 0 } };
				for (const definition of move.effects || []) {
					const effect = Rules.resolveEffect(definition, c, 1, 'heroes');
					let amount = effect.amount * Math.max(1, effect.repeat);
					if (effect.kind === 'damage') {
						amount = hit(effect, rally);
						turnDamage += amount;
						perMove[m].damage += amount;
						if (effect.piercing) perMove[m].piercing += amount;
					} else if (effect.kind === 'charge') {
						// What the charge lets go is written down now, in this action's numbers.
						for (const sub of effect.release || []) {
							const ready = Rules.resolveEffect(sub, c, 1, 'heroes');
							if (ready.kind === 'damage') perMove[m].release += hit(ready, 0);
						}
					} else if (effect.kind === 'rally') {
						rally += effect.amount;
					}
					perMove[m].effects[effect.kind] = (perMove[m].effects[effect.kind] || 0) + amount;
				}
			}
		}
		damageSum += turnDamage;
		damageHist.set(turnDamage, (damageHist.get(turnDamage) || 0) + 1);
	}
	return {
		key, depth, party, phase, turn, action, mineKey, emerging: Boolean(emerging), samples, hp: Forge.creatureHp(def, depth, party, mine),
		damageBonus, damagePct: pct, damageMult: scale.damage, enrage, traits,
		escorts: (def.escorts || []).slice(), echo: def.echo ? { ...def.echo } : null, summonOnly: Boolean(def.summon_only),
		meanDamage: damageSum / samples,
		damageHist: [...damageHist].sort((a, b) => a[0] - b[0]).map(([v, n]) => [v, n / samples]),
		moves: moves.map((move, m) => {
			const trigger = move.trigger || { kind: 'always' };
			const kind = trigger.kind || 'always';
			return { name: move.name, fireRate: perMove[m].fired / samples, meanDamage: perMove[m].damage / samples, meanPiercing: perMove[m].piercing / samples, meanRelease: perMove[m].release / samples,
				effects: Object.fromEntries(Object.entries(perMove[m].effects).map(([k, v]) => [k, v / samples])),
				combo: isCombination(move), turnMove: isTurnMove(move), onDeath: kind === 'on_death', once: Boolean(move.once), spent: Boolean(move.once) && action !== 1,
				die: 'die' in trigger ? Number(trigger.die) : null, nextNth: kind === 'every_nth_turn' ? nextNthIn(move, action) : 0, dramatic: Boolean(move.dramatic) };
		}),
	};
}

// --- encounters ------------------------------------------------------------------------------

export function encounters({ mineKey, depth = 1, party = 1, elite = false, samples = 5000, seed = 5 }) {
	const mine = C.mine(mineKey);
	const rng = makeRng(seed * 977 + depth * 13 + party + (elite ? 100 : 0));
	const compositions = new Map();
	const counts = new Map();
	const perCreature = {};
	let hpSum = 0, threatSum = 0;
	const damageByKey = {};
	for (let i = 0; i < samples; i++) {
		const picked = Forge.encounter(rng, mine, depth, party, elite);
		const label = picked.slice().sort().join('+');
		compositions.set(label, (compositions.get(label) || 0) + 1);
		counts.set(picked.length, (counts.get(picked.length) || 0) + 1);
		for (const key of picked) {
			perCreature[key] = (perCreature[key] || 0) + 1;
			const def = C.creature(key);
			hpSum += Forge.creatureHp(def, depth, party, mine);
			threatSum += Number(def.threat ?? 1);
		}
	}
	for (const key of Object.keys(perCreature)) damageByKey[key] = creatureTurn({ key, depth, party, mineKey, samples: 1500, seed }).meanDamage;
	let damageSum = 0;
	for (const [label, n] of compositions) if (label) for (const key of label.split('+')) damageSum += damageByKey[key] * n;
	return {
		mineKey, depth, party, elite, samples, budget: Forge.encounterBudget(depth, party, elite),
		band: Forge.bandFor(mine, depth), damageMult: Forge.creatureScale(mine, depth).damage,
		compositions: [...compositions].sort((a, b) => b[1] - a[1]).map(([label, n]) => [label, n / samples]),
		counts: [...counts].sort((a, b) => a[0] - b[0]).map(([k, n]) => [k, n / samples]),
		perCreature: Object.fromEntries(Object.entries(perCreature).map(([k, n]) => [k, n / samples])),
		meanHp: hpSum / samples, meanThreat: threatSum / samples, meanDamage: damageSum / samples, damageByKey,
	};
}

// --- stones ----------------------------------------------------------------------------------

export function stones({ mineKey, depth = 1, bonus = 0, samples = 8000, seed = 9, pool = [] }) {
	const mine = C.mine(mineKey);
	const rng = makeRng(seed * 4099 + depth * 17 + bonus);
	const tiers = Object.fromEntries(Stone.TIERS.map((t) => [t, 0]));
	const scores = new Map();
	const values = new Map();
	const inclusionCounts = {};
	const classCounts = {};
	let valueSum = 0, scoreSum = 0, caratSum = 0;
	const carats = new Array(Stone.caratMax() + 1).fill(0);
	const cuts = new Array(C.cuts().length).fill(0);
	const clarities = new Array(C.clarities().length).fill(0);
	let withInclusion = 0;
	for (let i = 0; i < samples; i++) {
		const stone = Forge.rollStone(rng, mine, depth, bonus, pool);
		const g = Stone.grade(stone);
		tiers[g.tier] += 1;
		scores.set(Math.floor(g.score / 5) * 5, (scores.get(Math.floor(g.score / 5) * 5) || 0) + 1);
		const v = Stone.value(stone);
		values.set(Math.floor(v / 20) * 20, (values.get(Math.floor(v / 20) * 20) || 0) + 1);
		valueSum += v; scoreSum += g.score; caratSum += stone.carat;
		carats[stone.carat] += 1; cuts[stone.cut] += 1; clarities[stone.clarity] += 1;
		if (stone.inclusions.length) withInclusion += 1;
		for (const key of stone.inclusions) {
			inclusionCounts[key] = (inclusionCounts[key] || 0) + 1;
			const cls = C.inclusion(key).class || 'PINPOINT';
			classCounts[cls] = (classCounts[cls] || 0) + 1;
		}
	}
	const dist = (m) => [...m].sort((a, b) => a[0] - b[0]).map(([k, n]) => [k, n / samples]);
	return {
		mineKey, depth, bonus, samples, luck: Forge.luck(mine, depth, bonus),
		tiers: Object.fromEntries(Object.entries(tiers).map(([k, n]) => [k, n / samples])),
		scores: dist(scores), values: dist(values), meanValue: valueSum / samples, meanScore: scoreSum / samples, meanCarat: caratSum / samples,
		carats: carats.map((n) => n / samples), cuts: cuts.map((n) => n / samples), clarities: clarities.map((n) => n / samples),
		inclusions: Object.fromEntries(Object.entries(inclusionCounts).map(([k, n]) => [k, n / samples])),
		classes: Object.fromEntries(Object.entries(classCounts).map(([k, n]) => [k, n / samples])), withInclusion: withInclusion / samples,
	};
}
