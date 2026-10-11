// A fight against training dummies, for the balance page. The player's half of sim/battle.gd
// is ported step for step: the rail and its queue (which replays, retriggers, Preludes and
// Echoes ride on), every gem, the hand the White gems change, the Birthstone, the passives,
// statuses and their ticks. The creatures are stand-ins: a dummy throws its dice at the player
// every action, takes whatever it is given, and answers stuns, stolen dice, Dread, clouding and
// Curse the way a creature does (sim/creatures.gd). It has no moves of its own beyond that.
//
// A dummy is endless by default (its health a ledger, not a clock). Given health, it dies like a
// creature, misses the action it would have taken, and a fresh one stands in its place as the
// next turn begins: what overkill and poison on a dying creature waste is then wasted, and a
// kill is worth the blows it saves. In a balance run the player never goes down (a blow that
// would down them is counted in full and they stand at 1), so every turn of the horizon is
// played. What comes out is a ledger, see `playFight`.
//
// The functions keep sim/battle.gd's names so the two can be read side by side, and
// tools/balance_parity.gd checks that they agree.

import * as C from './content.js';
import * as Dice from './dice.js';
import * as Hand from './hand.js';
import * as Patterns from './patterns.js';
import * as Rules from './rules.js';
import * as Stone from './stone.js';
import { makeRng } from './rng.js';
import { rerollIds } from './simulate.js';

export const HAND_KINDS = ['raise_low', 'raise_high', 'set_match', 'flip_low', 'flip_high', 'phantom_high', 'phantom_low'];
export const SELF_KINDS = ['amplify_next', 'cut_step_next', 'grant_reroll', 'retrigger_previous', 'quality_bonus', 'sparkle',
	'coin_flip', 'resonance', 'replay_color', 'replay_fizzled', 'rank_buff', 'repeat_next', 'void_copy', 'gem_rank', 'upgrade_faces', 'stake', 'appraise',
	'fire_neighbours', 'force_after', 'absorbed',
	'phantom_roll', 'rethrow', 'gild', 'soak', 'each_after', 'on_block', 'fire_birthstone', 'spectrum', 'stone_chance',
	'double_resonance', 'keep_phantoms'];
// The six colours and what a Spectrum gives for each, as [effect kind, amount, target].
const SPECTRUM_GIFTS = { RED: ['damage', 3, 'enemy'], BLUE: ['block', 3, 'self'], GREEN: ['heal', 3, 'self'], VIOLET: ['poison', 2, 'enemy'], GOLD: ['gold', 2, 'self'], WHITE: ['resonance', 1, 'self'] };
const DROPS_PER_SIZE = 3;
export const BIRTHSTONE_KINDS = ['replay_rail', 'tick_poison', 'stone_drop', 'pot'];
const PROC_IN_PLACE = ['coin_flip'];
const MAX_RAIL = 24;
const SPARKLE_MAX_STACKS = 100;
const STATUS_KINDS = ['poison', 'stun', 'curse', 'charged', 'marked', 'regeneration', 'spikes', 'dulled', 'lifeline', 'festering', 'scorched', 'burn', 'strength', 'envenom'];
export const DUMMY_HP = 1000000;

// --- units ---------------------------------------------------------------------------------

const living = (units) => units.filter((u) => (u.hp | 0) > 0 && !u.downed);
const targetable = (units) => living(units).filter((u) => !u.burrowed);
const enemyById = (state, id) => state.enemies.find((u) => u.id === id) || null;
const playerById = (state, id) => state.players.find((u) => u.id === id) || null;
const aim = (unit) => String(unit.firing_target ?? unit.target ?? '');
const isEmpty = (o) => !o || !Object.keys(o).length;

// What the hand shows, read once for as long as it stands still. A hand of plain dice reads
// the same whatever colour asks (only materials and boon faces change which die is preferred),
// so one reading serves every gem; anything that changes the hand in place calls touchHand.
function touchHand(unit) { unit.hand_version = (unit.hand_version | 0) + 1; }
function readHand(unit, colors = []) {
	const hand = unit.hand;
	let cache = unit.reading;
	if (!cache || cache.hand !== hand || cache.version !== (unit.hand_version | 0)) {
		cache = { hand, version: unit.hand_version | 0, plain: hand.every((r) => !r.material && !Dice.BOON_FACES.includes(r.kind || 'plain')), by: new Map() };
		unit.reading = cache;
	}
	const key = cache.plain ? '' : colors.join(',');
	let a = cache.by.get(key);
	if (!a) { a = Hand.analyze(hand, colors); cache.by.set(key, a); }
	return a;
}

function cloneStone(stone) { return { ...stone, inclusions: (stone.inclusions || []).slice() }; }
function cloneDie(die) { return { ...die, faces: (die.faces || []).map((f) => ({ ...f })) }; }

// A player for a fight (sim/battle.gd make_player, laid flat). `rail` is stones by socket;
// `opts.sockets` the socket colours (the character's own by default), `opts.pyrite` what they
// carry, `opts.birthstone`/`opts.passive` false to leave either out.
export function makePlayer(id, characterKey, rail, dice, opts = {}) {
	const character = C.character(characterKey);
	const sockets = (opts.sockets || character.sockets || ['ANY']).slice();
	const maxHp = Number(opts.hp ?? character.hp ?? 60);
	const laid = [];
	for (let i = 0; i < sockets.length; i++) laid.push(rail[i] ? cloneStone(rail[i]) : null);
	return {
		id, name: id, side: 'player', character: characterKey, sockets, rail: laid,
		birthstone: opts.birthstone === false ? {} : (character.birthstone || {}),
		passive: opts.passive === false ? { kind: 'none' } : (character.passive || { kind: 'none' }),
		flips: 0, fired_sockets: [], fizzled_sockets: [], tailings_paid: {}, rank_buff: { carat: 0, cut: 0 }, gem_buffs: {}, pyrite_delta: 0, repeat_next: 0, replaying: false,
		stone_drops: 0, pot: 0, hp: maxHp, max_hp: maxHp, block: 0, statuses: {}, dice: dice.map(cloneDie), hand: [], rerolls: 0, rerolls_max: 0, locked: false, target: '',
		resonance: 0, initial_resonance: 0, previous_fired: false, previous_amount: 0, previous_colors: [], previous_socket: -1, amplify: 1, cut_step_bonus: 0, nullify_next: false,
		block_lost: 0, block_lost_accum: 0, healed: 0, dealt: 0, dealt_last_turn: 0, gold: 0, ore: Number(opts.pyrite ?? 0) | 0, once: {}, downed: false,
		buried: [], clouded: [], stolen_dice: 0, granted_rerolls: 0, sparkle: 0, quality_bonus: 0, fired_count: 0, void_copies: 0, haul: [],
	};
}

// A training dummy: `hp` (endless when 0), `dice` to throw at the player every action (each
// die one move: a blow for what it shows) and `guard`, block it raises as it acts.
export function makeDummy(id, spec = {}) {
	const dice = (spec.dice || ['D6', 'D4']).map((k, i) => Dice.dieFrom(k, `${id}_d${i}`));
	const hp = Number(spec.hp || 0) > 0 ? Number(spec.hp) : DUMMY_HP;
	return { id, name: 'Dummy', side: 'enemy', hp, max_hp: hp, block: 0, statuses: {}, dice, guard: Number(spec.guard ?? 0) | 0,
		stolen_dice: 0, dread_turns: 0, clouded_move: -1, stun_streak: 0, turns_acted: 0, hurt_by: {}, hurt_by_color: {}, biggest_hit: 0, gimmick: '', traits: {} };
}

// A dummy that fell is stood up again, fresh, as a turn begins.
export function standDummies(state) {
	for (const foe of state.enemies) {
		if ((foe.hp | 0) > 0) continue;
		Object.assign(foe, { hp: foe.max_hp_start ?? foe.max_hp, block: 0, statuses: {}, stolen_dice: 0, dread_turns: 0, clouded_move: -1, stun_streak: 0, hurt_by: {}, biggest_hit: 0 });
		foe.max_hp = foe.hp;
		state.ledger.kills += 1;
	}
}

// A fight state the way sim/battle.gd begin() leaves one, before the first hand is thrown.
export function makeFight({ players, enemies, depth = 1, noDowns = false }) {
	const state = { turn: 0, phase: 'planning', depth, party: players.length, players, enemies, queue: [], noDowns,
		ledger: { dealt: 0, hpLost: 0, healed: 0, blockGained: 0, fires: 0, fizzles: 0, birthstone: 0, resonance: 0, downs: 0, incoming: 0, kills: 0 } };
	for (const foe of enemies) foe.max_hp_start = foe.max_hp;
	for (const unit of players) {
		unit.initial_rail = unit.rail.map((s) => (s ? cloneStone(s) : null));
		unit.target = enemies.length ? enemies[0].id : '';
		// House Money: the Gambler never sits down at an empty table.
		if (unit.passive.kind === 'pot_share') stake(unit, Math.trunc((Rules.pyrite(unit) * Number(unit.passive.amount ?? 10)) / 100));
	}
	return state;
}

// --- the rail ------------------------------------------------------------------------------

export function railContext(state, unit, socket, opts = {}) {
	const stone = Stone.fingerprinted(unit.rail, socket, unit.rail[socket]);
	const socketColor = String(unit.sockets[socket] ?? C.SOCKET_ANY);
	let caratBonus = 0;
	for (const neighbour of [socket - 1, socket + 1]) {
		if (neighbour < 0 || neighbour >= unit.rail.length || !unit.rail[neighbour]) continue;
		const other = Stone.fingerprinted(unit.rail, neighbour, unit.rail[neighbour]);
		for (const m of Stone.modifiers(other)) {
			if (m.kind !== 'adjacent_carat') continue;
			let shared = true;
			if (m.same_color) {
				shared = false;
				const mine = Stone.colors(stone, socketColor);
				for (const color of Stone.colors(other, String(unit.sockets[neighbour]))) if (mine.includes(color)) shared = true;
			}
			if (shared) caratBonus += Number(m.amount ?? 1) | 0;
		}
	}
	const buff = unit.rank_buff || {};
	const gemBuff = (unit.gem_buffs || {})[String(stone.id)] || {};
	caratBonus += (buff.carat | 0) + (gemBuff.carat | 0);
	const dark = unit.fizzled_sockets || [];
	let unpaid = 0;
	for (let index = (unit.tailings_paid || {})[String(stone.id)] | 0; index < dark.length; index++) if (dark[index] !== socket) unpaid += 1;
	let enemyPoison = 0;
	for (const foe of living(state.enemies)) enemyPoison += foe.statuses.poison | 0;
	return { unit, resonance: unit.resonance | 0, previous_fired: Boolean(unit.previous_fired), previous_amount: unit.previous_amount | 0, amplify: Number(unit.amplify ?? 1),
		cut_step_bonus: (unit.cut_step_bonus | 0) + (buff.cut | 0) + (gemBuff.cut | 0), carat_bonus: caratBonus, clarity_bonus: gemBuff.clarity | 0,
		enemy_poison: enemyPoison, carat_cap: 0, fizzles: unpaid, dulled: unit.statuses.dulled | 0, depth: state.depth | 0, turn: state.turn | 0, party: state.party | 0,
		socket: socketColor, retrigger: Boolean(opts.retrigger), force_fire: Boolean(opts.force), analyze: (colors) => readHand(unit, colors),
		kills: state.turn_kills | 0, run_fires: (unit.run_counts || {})[String(stone.id || '')] | 0 };
}

// What a Doublet at this socket wears: the nearest gem behind it that is not itself an opal.
export function wornSocket(unit, socket) {
	const stone = unit.rail[socket];
	if (!stone || String(Stone.skillOf(stone).wears || '') !== 'prev') return -1;
	for (let behind = socket - 1; behind >= 0; behind--) if (unit.rail[behind] && !Stone.isOpal(unit.rail[behind])) return behind;
	return -1;
}

export function stoneAt(unit, socket) {
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket]) return null;
	const worn = wornSocket(unit, socket);
	const stone = worn < 0 ? unit.rail[socket] : Stone.wearing(unit.rail[socket], unit.rail[worn]);
	return Stone.fingerprinted(unit.rail, socket, stone);
}

// What an opal's repeat may touch: never another opal, unless it is a Doublet wearing a gem.
export function repeatable(unit, socket) {
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket]) return false;
	if (!Stone.isOpal(unit.rail[socket])) return true;
	return wornSocket(unit, socket) >= 0;
}

function resetRail(unit) {
	unit.resonance = unit.initial_resonance | 0;
	unit.previous_fired = false;
	unit.previous_amount = 0;
	unit.previous_colors = [];
	unit.previous_socket = -1;
	unit.amplify = 1;
	unit.nullify_next = false;
	unit.cut_step_bonus = unit.passive.kind === 'first_gem_cut_step' ? Number(unit.passive.amount ?? 1) : 0;
	unit.fired_sockets = [];
	unit.fizzled_sockets = [];
	unit.tailings_paid = {};
	unit.repeat_next = 0;
	unit.replaying = false;
	unit.fired_count = 0;
	unit.force_after = {};
	unit.fired_colors = [];
	unit.resonance_mult = 1;
}

// Queue one player's rail: their gems in socket order, the Birthstone, the close.
export function startRail(state, unit) {
	unit.firing_target = String(unit.target || '');
	const queue = [{ kind: 'rail_begin', unit: unit.id }];
	for (let socket = 0; socket < unit.rail.length; socket++) if (unit.rail[socket]) queue.push({ kind: 'gem', unit: unit.id, socket });
	if (!isEmpty(unit.birthstone)) queue.push({ kind: 'birthstone', unit: unit.id });
	queue.push({ kind: 'rail_end', unit: unit.id });
	state.queue = queue;
}

// Play the queue out. Returns the events, for the parity check and the curious.
export function runQueue(state, rng, keepEvents = false) {
	const events = keepEvents ? [] : null;
	let guard = 0;
	while (state.queue.length && guard++ < 5000) {
		const event = perform(state, state.queue.shift(), rng);
		if (events && event) events.push(event);
	}
	return events;
}

export function perform(state, s, rng) {
	const unit = playerById(state, String(s.unit || ''));
	if (!unit || unit.downed) return null;
	switch (s.kind) {
		case 'rail_begin':
			resetRail(unit);
			return { kind: 'rail_begin', resonance: unit.resonance };
		case 'gem':
			return resolveGem(state, unit, s.socket | 0, { retrigger: Boolean(s.retrigger), scale: s.scale ?? 100, replay: Boolean(s.replay), force: Boolean(s.force), as_skill: String(s.as_skill || '') }, rng);
		case 'birthstone':
			return resolveBirthstone(state, unit, { replay: Boolean(s.replay), share: s.share ?? 100 }, rng);
		case 'rail_end': {
			// Second Wind: the rerolls not spent, each worth the Resonance the rail just built.
			const resonance = unit.resonance | 0;
			// Everything this rail rang goes on the fight's tally, which a Crescendo reads.
			unit.fight_resonance = (unit.fight_resonance | 0) + resonance;
			const unused = unit.rerolls | 0;
			let healed = 0;
			if (unit.passive.kind === 'heal_resonance_per_unused_reroll' && unused > 0 && resonance > 0) healed = heal(state, unit, resonance * unused);
			state.ledger.resonance += resonance;
			return { kind: 'rail_end', resonance, healed };
		}
	}
	return null;
}

// How many times a Certainty earlier on the rail has this socket fire this turn, whatever the dice say.
export function certainTimes(unit, socket, retrigger) {
	const certainty = unit.force_after || {};
	if (retrigger || !('from' in certainty) || socket <= (certainty.from | 0)) return 0;
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket] || Stone.isOpal(unit.rail[socket])) return 0;
	return Math.max(0, certainty.times | 0);
}

export function resolveGem(state, unit, socket, opts, rng) {
	const dry = Boolean(opts.dry);
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket]) return null;
	// A Black Opal fires each skill it absorbed as a stone wearing that skill.
	const stone = opts.as_skill ? Stone.wearing(unit.rail[socket], { skill: opts.as_skill }) : stoneAt(unit, socket);
	const certain = certainTimes(unit, socket, Boolean(opts.retrigger));
	if (certain > 0 && !opts.force) opts = { ...opts, force: true };
	if (unit.buried.includes(socket) || unit.clouded.includes(socket)) {
		unit.previous_fired = false;
		return { kind: 'gem_fizzle', socket, skill: stone.skill, blocked: true, resonance: unit.resonance };
	}
	const context = railContext(state, unit, socket, opts);
	const ev = Stone.evaluate(stone, unit.hand, context);
	for (const effect of ev.effects) {
		if ((effect.cost | 0) > Rules.pyrite(unit)) { ev.active = false; ev.reason = 'Not enough Pyrite.'; }
		// A gem that costs blood never takes the last of it: it stays dark instead.
		if ((effect.hp_cost | 0) > 0 && ev.active && (effect.hp_cost | 0) >= (unit.hp | 0)) { ev.active = false; ev.reason = 'Not enough health.'; }
	}
	const nullified = Boolean(unit.nullify_next);
	// A Prelude hands the next gem to resolve its extra goes, and is spent doing it.
	const promised = unit.repeat_next | 0;
	unit.amplify = 1;
	unit.cut_step_bonus = 0;
	unit.nullify_next = false;
	unit.repeat_next = 0;
	const retrigger = Boolean(opts.retrigger);
	if (nullified && !retrigger) { ev.active = false; ev.reason = 'Double Down came up empty.'; }
	if (!ev.active) {
		let healed = 0;
		if (unit.passive.kind === 'heal_on_fizzle' && !unit.downed) healed = heal(state, unit, Number(unit.passive.amount ?? 2));
		unit.previous_fired = false;
		unit.previous_amount = 0;
		unit.previous_colors = [];
		if (!retrigger && !unit.fizzled_sockets.includes(socket)) unit.fizzled_sockets.push(socket);
		state.ledger.fizzles += 1;
		return { kind: 'gem_fizzle', socket, skill: stone.skill, reason: ev.reason || '', resonance: unit.resonance, healed, cut_step: ev.cut_step | 0 };
	}
	const scale = Number(opts.scale ?? 100);
	// Blood a gem asks for itself (Bloodletting) is paid with whatever an inclusion asks.
	let hpCost = ev.hp_cost | 0;
	for (const effect of ev.effects) hpCost += Math.max(0, effect.hp_cost | 0);
	if (hpCost > 0) {
		const before = unit.hp | 0;
		unit.hp = Math.max(1, before - hpCost);
		state.ledger.hpLost += before - unit.hp;
	}
	let harmony = false;
	if (unit.previous_fired) for (const color of unit.previous_colors) if (ev.colors.includes(color)) harmony = true;
	const gain = ((ev.resonance_gain | 0) + (harmony ? 1 : 0)) * Math.max(1, unit.resonance_mult | 0);
	unit.resonance = (unit.resonance | 0) + gain;
	const results = [];
	const previousSocket = unit.previous_socket ?? -1;
	const reactions = {};
	unit.firing_colors = ev.colors.slice();
	unit.fired_count = (unit.fired_count | 0) + 1;
	// What a Chainmail or a Contagion earlier this turn hands over for this gem: taken now.
	const answers = (unit.after_fire || []).map((x) => ({ ...x }));
	for (const effect of ev.effects) {
		const applied = { ...effect };
		if (scale !== 100 && effect.scaled) applied.amount = Math.floor((effect.amount | 0) * scale / 100);
		if (effect.once) {
			if (unit.once[String(stone.id)]) {
				// Lifeline's second try: the party is healed half of it instead.
				applied.kind = 'heal';
				applied.target = 'allies';
				applied.amount = Math.trunc((applied.amount | 0) / 2);
			} else unit.once[String(stone.id)] = true;
		}
		const kind = applied.kind;
		let procs = applied.procs ?? 1;
		if (!dry && (applied.proc_chance | 0) > 0 && rng.chance(applied.proc_chance)) procs += 1;
		if ('cost' in applied) procs = 1;
		applied.procs = procs;
		if (HAND_KINDS.includes(kind) || SELF_KINDS.includes(kind)) {
			const times = PROC_IN_PLACE.includes(kind) ? 1 : procs;
			for (let p = 0; p < times; p++) results.push(HAND_KINDS.includes(kind) ? mutateHand(unit, applied) : selfEffect(state, unit, applied, socket, previousSocket, dry, rng));
		} else {
			applied.repeat = Math.max(0, Math.min((applied.repeat ?? 1) * procs, Rules.MAX_REPEAT));
			results.push(...apply(state, unit, applied, rng, '', reactions));
		}
	}
	results.push(...answerFire(state, unit, answers, rng));
	delete unit.firing_colors;
	// A gem that grows over the run (Hone, Hardening) counts every fire, replays included.
	if (!dry) { const counts = unit.run_counts || (unit.run_counts = {}); counts[String(stone.id || '')] = (counts[String(stone.id || '')] | 0) + 1; }
	(unit.fired_colors || (unit.fired_colors = [])).push(ev.colors.slice());
	if ((ev.next_cut_step | 0) > 0) unit.cut_step_bonus = (unit.cut_step_bonus | 0) + (ev.next_cut_step | 0);
	unit.previous_fired = true;
	unit.previous_amount = Stone.totalAmount(ev);
	unit.previous_colors = ev.colors;
	unit.previous_socket = socket;
	if (!unit.fired_sockets.includes(socket)) unit.fired_sockets.push(socket);
	// A Tailings collects on every fizzle it read, and none of them pays it again this turn.
	if (String((Stone.skillOf(stone).trigger || {}).kind || '') === 'fizzles') unit.tailings_paid[String(stone.id)] = unit.fizzled_sockets.length;
	if (!dry && !retrigger && (ev.fires | 0) > 1) for (let extra = 0; extra < (ev.fires | 0) - 1; extra++) state.queue.unshift({ kind: 'gem', unit: unit.id, socket, retrigger: true });
	if (!dry && !retrigger && promised > 0) for (let more = 0; more < promised; more++) state.queue.unshift({ kind: 'gem', unit: unit.id, socket, retrigger: true });
	if (!dry && certain > 1) for (let more = 0; more < certain - 1; more++) state.queue.unshift({ kind: 'gem', unit: unit.id, socket, retrigger: true, force: true });
	state.ledger.fires += 1;
	return { kind: 'gem_fire', socket, skill: stone.skill, resonance: unit.resonance, gain, harmony, retrigger, cut_step: ev.cut_step | 0, carat: ev.carat | 0,
		magnitude: ev.magnitude, fires: ev.fires | 0, promised: retrigger ? 0 : promised, effects: results };
}

// --- the Birthstone ------------------------------------------------------------------------

export function resolveBirthstone(state, unit, opts, rng) {
	const def = unit.birthstone;
	if (isEmpty(def)) return null;
	const dry = Boolean(opts.dry);
	const replay = Boolean(opts.replay);
	const promised = unit.repeat_next | 0;
	unit.repeat_next = 0;
	const a = readHand(unit);
	// A Birthright fires it mid-rail at a share of the Resonance so far.
	const resonance = Math.trunc(((unit.resonance | 0) * Math.max(0, opts.share ?? 100)) / 100);
	const defs = def.tiers || [];
	const evaluated = [];
	let exclusiveHit = -1;
	for (let index = 0; index < defs.length; index++) {
		const tier = defs[index];
		const trig = Patterns.evaluate(tier.trigger || { kind: 'always' }, 0, a, { resonance });
		if (replay && trig.active && (tier.effects || []).some((e) => e && e.kind === 'replay_rail')) { trig.active = false; trig.reason = 'Once a turn.'; }
		if (trig.active && tier.exclusive && exclusiveHit < 0) exclusiveHit = index;
		evaluated.push(trig);
	}
	const tiers = [];
	let fired = false;
	for (let index = 0; index < defs.length; index++) {
		const tier = defs[index];
		const trig = evaluated[index];
		const entry = { name: String(tier.name || ''), active: Boolean(trig.active), effects: [] };
		if (exclusiveHit >= 0 && index !== exclusiveHit && entry.active) { entry.active = false; entry.eclipsed = true; }
		if (entry.active) {
			fired = true;
			const tc = { a, trig, unit, resonance, previous_amount: unit.previous_amount | 0, depth: state.depth | 0, turn: state.turn | 0, party: state.party | 0 };
			const reactions = {};
			for (const effectDef of tier.effects || []) {
				if (!effectDef || typeof effectDef !== 'object') continue;
				const applied = Rules.resolveEffect(effectDef, tc, 1.0);
				const kind = applied.kind;
				if (HAND_KINDS.includes(kind)) entry.effects.push(mutateHand(unit, applied));
				else if (SELF_KINDS.includes(kind)) entry.effects.push(selfEffect(state, unit, applied, -1, -1, dry, rng));
				else if (BIRTHSTONE_KINDS.includes(kind)) entry.effects.push(birthstoneEffect(state, unit, applied, dry, replay));
				else entry.effects.push(...apply(state, unit, applied, rng, '', reactions));
			}
		}
		tiers.push(entry);
	}
	if (!dry && !replay && promised > 0) for (let more = 0; more < promised; more++) state.queue.unshift({ kind: 'birthstone', unit: unit.id, replay: true });
	// The Birthstone is a gem that fired, as far as a Chainmail is concerned.
	if (fired) answerFire(state, unit, unit.after_fire || [], rng);
	if (fired) state.ledger.birthstone += 1;
	return { kind: 'birthstone', fired, resonance, replay, tiers };
}

// What a Chainmail or a Contagion earlier this turn gives for one more gem fired.
function answerFire(state, unit, answers, rng) {
	const out = [];
	for (const answer of answers) out.push(...apply(state, unit, { kind: answer.kind, amount: answer.amount | 0, target: answer.target, repeat: 1 }, rng));
	return out;
}

function birthstoneEffect(state, unit, effect, dry, replay) {
	const kind = effect.kind;
	const amount = effect.amount | 0;
	const out = { kind, amount };
	switch (kind) {
		case 'replay_rail': {
			// Encore: every gem that fired plays again, in order, then the Birthstone once more.
			const sockets = unit.fired_sockets.slice().sort((x, y) => x - y);
			out.sockets = sockets;
			if (dry || replay || unit.replaying || !sockets.length) out.nothing = true;
			else {
				unit.replaying = true;
				const again = sockets.map((socket) => ({ kind: 'gem', unit: unit.id, socket, retrigger: true, replay: true }));
				again.push({ kind: 'birthstone', unit: unit.id, replay: true });
				state.queue = again.concat(state.queue);
			}
			break;
		}
		case 'tick_poison': {
			for (const foe of living(state.enemies)) {
				for (let time = 0; time < Math.max(0, amount); time++) {
					if ((foe.statuses.poison | 0) <= 0 || (foe.hp | 0) <= 0) break;
					poisonTick(state, foe);
				}
			}
			break;
		}
		case 'stone_drop':
			if (!dry) unit.stone_drops = (unit.stone_drops | 0) + amount;
			break;
		case 'pot': {
			// What is on the table. Staking moves Pyrite out of the bank in the same breath.
			const mode = String(effect.pot_mode || 'ante');
			const before = unit.pot | 0;
			if (mode === 'lose') { if (!dry) unit.pot = 0; } else {
				const wanted = mode === 'ante' ? amount : mode === 'double' ? before : Rules.pyrite(unit);
				out.moved = dry ? Math.min(Math.max(0, wanted), Rules.pyrite(unit)) : stake(unit, wanted);
			}
			break;
		}
	}
	return out;
}

export function stake(unit, wanted) {
	const moved = Math.max(0, Math.min(wanted, Rules.pyrite(unit)));
	if (moved <= 0) return 0;
	unit.pot = (unit.pot | 0) + moved;
	unit.pyrite_delta = (unit.pyrite_delta | 0) - moved;
	return moved;
}

// --- what gems do to the hand and the rail ---------------------------------------------------

function extreme(rolls, lowest) {
	let found = null;
	for (const roll of rolls) if (!found || (lowest ? roll.value < found.value : roll.value > found.value)) found = roll;
	return found;
}

// White gems change the hand every gem after them reads.
export function mutateHand(unit, effect) {
	const hand = unit.hand;
	const amount = effect.amount | 0;
	const kind = effect.kind;
	const changed = [];
	const real = hand.filter((r) => !['wild', 'blank'].includes(r.kind || 'plain') && !r.phantom);
	let high = 0;
	for (const roll of real) high = Math.max(high, roll.value | 0);
	switch (kind) {
		case 'raise_low': {
			const lowest = extreme(real, true);
			if (lowest) {
				const ceiling = amount >= 99 ? Math.max(high, lowest.top ?? high) : lowest.value + amount;
				lowest.value = Math.min(lowest.value + amount, ceiling);
				changed.push(lowest.die_id);
			}
			break;
		}
		case 'raise_high': {
			const highest = extreme(real, false);
			if (highest) { highest.value = highest.value + amount; changed.push(highest.die_id); }
			break;
		}
		case 'set_match':
			for (let i = 0; i < amount; i++) {
				const best = Hand.analyze(hand).best_set || {};
				const targetValue = best.value ?? high;
				let candidate = null;
				for (const roll of real) {
					if ((best.dice || []).includes(roll.die_id) || changed.includes(roll.die_id)) continue;
					if (!candidate || roll.value < candidate.value) candidate = roll;
				}
				if (!candidate) break;
				candidate.value = targetValue;
				changed.push(candidate.die_id);
			}
			break;
		case 'flip_low': case 'flip_high': {
			const sorted = real.slice().sort((x, y) => (kind === 'flip_low' ? x.value - y.value : y.value - x.value));
			for (let index = 0; index < Math.min(amount, sorted.length); index++) {
				const roll = sorted[index];
				roll.value = Math.max(1, (roll.top ?? 6) + 1 - roll.value);
				changed.push(roll.die_id);
			}
			break;
		}
		case 'phantom_high': case 'phantom_low': {
			const picked = extreme(real, kind === 'phantom_low');
			if (picked) {
				for (let index = 0; index < amount; index++) {
					const ghost = Dice.phantom(picked, `${picked.die_id}_ph${hand.length}_${index}`);
					// A Flawless Sediment's phantom shows a number of its own: a 1.
					if ('shows' in effect) { ghost.value = effect.shows | 0; ghost.kind = 'plain'; delete ghost.shown; delete ghost.counted; delete ghost.base; }
					hand.push(ghost);
					changed.push(ghost.die_id);
				}
			}
			break;
		}
	}
	touchHand(unit);
	return { kind, amount, dice: changed };
}

function voidCopy(unit, source) {
	unit.void_copies = (unit.void_copies | 0) + 1;
	const copy = cloneStone(source);
	copy.id = `${source.id || 'gem'}-void${unit.void_copies}`;
	if (!copy.inclusions.includes('VOID')) copy.inclusions.push('VOID');
	copy.temporary = true;
	return copy;
}

// A gem joins a rail mid-fight: everything that names a place on the rail moves up past it.
function joinRail(state, unit, at, stone) {
	if (at < 1 || at > unit.rail.length) return;
	unit.rail.splice(at, 0, stone);
	unit.sockets.splice(at, 0, C.SOCKET_ANY);
	for (const entry of state.queue) if (entry.unit === unit.id && entry.socket !== undefined && entry.socket >= at) entry.socket += 1;
	for (const field of ['fired_sockets', 'fizzled_sockets', 'buried', 'clouded']) unit[field] = (unit[field] || []).map((p) => (p >= at ? p + 1 : p));
	if ((unit.previous_socket ?? -1) >= at) unit.previous_socket += 1;
	if (unit.force_after && 'from' in unit.force_after && unit.force_after.from >= at) unit.force_after.from += 1;
}

// Whether a die the trigger matched may still be raised: judged by the face it shows now
// against the trigger's line; a wild matched every line and is raised once a firing.
function underLine(roll, line, raised) {
	if ((roll.kind || 'plain') === 'wild') return !raised.includes(roll.die_id);
	if (!line) return true;
	const face = 'base' in roll ? roll.base : roll.value;
	return line.kind === 'below' ? face < line.need : face <= line.need;
}

export function selfEffect(state, unit, effect, socket, previousSocket, dry, rng) {
	const kind = effect.kind;
	const amount = effect.amount | 0;
	const out = { kind, amount };
	switch (kind) {
		case 'gem_rank': {
			const scope = String(effect.scope || 'adjacent');
			const rank = String(effect.rank || 'carat');
			const changed = [];
			for (let at = 0; at < unit.rail.length; at++) {
				if (!unit.rail[at] || (scope === 'adjacent' && Math.abs(at - socket) !== 1) || (scope === 'others' && at === socket) || (scope === 'self' && at !== socket)) continue;
				const id = String(unit.rail[at].id);
				const buff = unit.gem_buffs[id] || (unit.gem_buffs[id] = {});
				buff[rank] = (buff[rank] | 0) + amount;
				changed.push(at);
			}
			out.sockets = changed;
			break;
		}
		case 'upgrade_faces': {
			// Only the first die it matches that still meets the gem's line (see underLine).
			const changed = [];
			const wanted = effect.dice || [];
			const raised = effect.raised || [];
			for (const roll of unit.hand) {
				if (changed.length) break;
				if (roll.phantom || !wanted.includes(roll.die_id)) continue;
				if (!underLine(roll, effect.line, raised)) continue;
				for (const die of unit.dice) {
					if (die.id !== roll.die_id) continue;
					die.faces.forEach((face, index) => { if (effect.all_faces || index === (roll.face ?? -1)) face.value = (face.value | 0) + amount; });
					roll.value = roll.value + amount;
					if ('base' in roll) roll.base = roll.base + amount;
					if ('top' in die) {
						let physical = 0;
						for (const face of die.faces) if ((face.kind || 'plain') !== 'blank') physical = Math.max(physical, face.value | 0);
						die.top = Math.max(die.top | 0, physical);
					}
					roll.top = Dice.top(die);
					changed.push(die.id);
				}
			}
			raised.push(...changed);
			effect.raised = raised;
			out.dice = changed;
			touchHand(unit);
			break;
		}
		case 'stake': {
			const cost = effect.cost | 0;
			if (Rules.pyrite(unit) >= cost) {
				unit.pyrite_delta = (unit.pyrite_delta | 0) - cost;
				unit.amplify = Number(unit.amplify) * (1 + amount / 100);
				out.spent = cost;
			}
			break;
		}
		case 'appraise': {
			// Raw stones in the haul read on the spot, and thrown for what they are worth. A
			// training fight carries no haul.
			const appraised = [];
			let worth = 0;
			for (const stone of unit.haul || []) {
				if (appraised.length >= (effect.stones ?? 1)) break;
				if (stone.appraised) continue;
				stone.appraised = true;
				appraised.push(stone.id);
				worth += Stone.value(stone);
			}
			out.value = worth;
			if (worth > 0) out.hits = apply(state, unit, { kind: 'damage', target: 'enemy', amount: Math.trunc((worth * amount) / 100), repeat: 1 }, rng);
			break;
		}
		case 'replay_color': {
			// A Seam: every gem of one colour that has already fired this turn plays again.
			const want = String(effect.color || '');
			const encore = [];
			const touched = [];
			for (const at of unit.fired_sockets.slice().sort((x, y) => x - y)) {
				if (at === socket || !repeatable(unit, at)) continue;
				if (want !== 'ANY' && !Stone.colors(stoneAt(unit, at), String(unit.sockets[at])).includes(want)) continue;
				touched.push(at);
				for (let time = 0; time < Math.max(1, amount); time++) encore.push({ kind: 'gem', unit: unit.id, socket: at, retrigger: true });
			}
			out.sockets = touched;
			if (dry || !encore.length) out.nothing = true; else state.queue = encore.concat(state.queue);
			break;
		}
		case 'replay_fizzled': {
			// A Matrix: gems that stayed dark this turn fire anyway, earliest first.
			const woken = [];
			const darkSockets = [];
			for (const at of unit.fizzled_sockets.slice().sort((x, y) => x - y)) {
				if (darkSockets.length >= Math.max(1, amount)) break;
				if (at === socket || !repeatable(unit, at)) continue;
				darkSockets.push(at);
				woken.push({ kind: 'gem', unit: unit.id, socket: at, retrigger: true, force: true });
			}
			out.sockets = darkSockets;
			if (dry || !woken.length) out.nothing = true; else state.queue = woken.concat(state.queue);
			break;
		}
		case 'rank_buff': {
			const rank = String(effect.rank || 'carat');
			if (!dry) unit.rank_buff = { ...unit.rank_buff, [rank]: (unit.rank_buff[rank] | 0) + amount };
			break;
		}
		case 'repeat_next':
			if (!dry) unit.repeat_next = (unit.repeat_next | 0) + Math.max(0, amount);
			break;
		case 'void_copy': {
			// An Echo: a Void copy of the last gem that fired joins the rail behind this one.
			const source = previousSocket;
			const copyable = socket >= 0 && source >= 0 && source < unit.rail.length && unit.rail[source] && repeatable(unit, source);
			if (dry || !copyable) { out.nothing = true; break; }
			const made = [];
			for (let copy = 0; copy < Math.max(1, amount); copy++) {
				if (unit.rail.length >= MAX_RAIL) break;
				made.push(socket + 1 + made.length);
				joinRail(state, unit, made[made.length - 1], voidCopy(unit, unit.rail[source]));
			}
			out.sockets = made;
			if (!made.length) out.nothing = true;
			else state.queue = made.map((at) => ({ kind: 'gem', unit: unit.id, socket: at })).concat(state.queue);
			break;
		}
		case 'fire_neighbours': {
			// A Gemini: the gems either side of it fire, once for every pair; never an opal.
			const twins = [];
			const woken = [];
			for (const at of [socket - 1, socket + 1]) {
				if (at === socket || !repeatable(unit, at)) continue;
				twins.push(at);
				for (let time = 0; time < Math.max(0, amount); time++) woken.push({ kind: 'gem', unit: unit.id, socket: at, retrigger: true, force: true });
			}
			out.sockets = twins;
			if (dry || !woken.length) out.nothing = true; else state.queue = woken.concat(state.queue);
			break;
		}
		case 'force_after': {
			// A Certainty: every gem after it fires this turn whatever the dice show (set on a forecast too).
			const standing = unit.force_after || {};
			const from = 'from' in standing ? Math.min(socket, standing.from | 0) : socket;
			unit.force_after = { from, times: Math.max(Math.max(1, amount), standing.times | 0) };
			out.total = unit.force_after.times;
			break;
		}
		case 'absorbed': {
			// A Black Opal: every skill it took in this run fires from its socket.
			const taken = socket >= 0 && unit.rail[socket] ? unit.rail[socket].absorbed || [] : [];
			out.skills = taken.slice();
			if (dry || !taken.length) out.nothing = true;
			else state.queue = taken.map((key) => ({ kind: 'gem', unit: unit.id, socket, retrigger: true, as_skill: String(key) })).concat(state.queue);
			break;
		}
		case 'phantom_roll': {
			// A Tumble or a Contra Luz: a fresh phantom die of its own size, thrown into the hand.
			if (dry) { out.nothing = true; break; }
			const made = Dice.make(String(effect.shape || 'D6'), `${unit.id}_roll${state.turn | 0}_${unit.hand.length}`);
			const ghost = Dice.rollOne(made, rng);
			ghost.phantom = true;
			unit.hand.push(ghost);
			touchHand(unit);
			out.value = ghost.value;
			break;
		}
		case 'rethrow': {
			// A Rattle: the lowest real die it has not yet thrown this firing goes again. A throw,
			// so it pays what a throw pays, but never a reroll.
			const thrown = effect.thrown || [];
			let lowest = -1;
			unit.hand.forEach((roll, index) => {
				if (roll.phantom || ['wild', 'blank'].includes(roll.kind || 'plain') || roll.locked || thrown.includes(roll.die_id)) return;
				if (lowest < 0 || roll.value < unit.hand[lowest].value) lowest = index;
			});
			const die = lowest >= 0 ? unit.dice.find((d) => d.id === unit.hand[lowest].die_id) : null;
			if (dry || !die) { out.nothing = true; break; }
			const was = unit.hand[lowest];
			let best = null;
			for (let time = 0; time < Math.max(1, effect.best_of | 0); time++) {
				const again = Dice.rollOne(die, rng, was.rerolls | 0);
				again.held = Boolean(was.held);
				again.rethrown = true;
				payDues(unit, [again]);
				if (!best || again.value > best.value) best = again;
			}
			unit.hand[lowest] = best;
			thrown.push(die.id);
			effect.thrown = thrown;
			touchHand(unit);
			out.value = best.value;
			break;
		}
		case 'gild': {
			// A Gilding: the face the highest die shows turns Golden for the rest of the run.
			const gilded = effect.gilded || [];
			const changed = [];
			for (const lowest of effect.both_ends ? [false, true] : [false]) {
				let pick = null;
				for (const roll of unit.hand) {
					if (roll.phantom || (roll.kind || 'plain') === 'blank' || gilded.includes(roll.die_id)) continue;
					const owner = unit.dice.find((d) => d.id === roll.die_id);
					const at = roll.face ?? -1;
					if (!owner || at < 0 || at >= owner.faces.length || (owner.faces[at].kind || 'plain') === 'golden') continue;
					if (!pick || (lowest ? roll.value < pick.value : roll.value > pick.value)) pick = roll;
				}
				if (!pick || dry) continue;
				Dice.etch(unit.dice.find((d) => d.id === pick.die_id), pick.face | 0, 'golden');
				gilded.push(pick.die_id);
				changed.push(pick.die_id);
			}
			effect.gilded = gilded;
			if (!changed.length) out.nothing = true;
			break;
		}
		case 'soak': {
			// A Hydrophane: the smallest die drinks a drop; at three it is a size bigger (smaller, Flawless).
			let smallest = null;
			for (const die of unit.dice) if (!smallest || Dice.top(die) < Dice.top(smallest)) smallest = die;
			if (dry || !smallest) { out.nothing = true; break; }
			let drops = (smallest.drops | 0) + 1;
			if (drops >= DROPS_PER_SIZE) drops = Dice.resize(smallest, effect.shrink ? -1 : 1) === '' ? 0 : DROPS_PER_SIZE;
			smallest.drops = drops;
			break;
		}
		case 'each_after':
			(unit.after_fire || (unit.after_fire = [])).push({ kind: String(effect.gift || 'block'), amount, target: String(effect.target || 'self') });
			break;
		case 'on_block':
			(unit.on_block || (unit.on_block = [])).push({ amount, target: String(effect.target || 'enemy') });
			break;
		case 'fire_birthstone':
			if (dry || isEmpty(unit.birthstone)) out.nothing = true;
			else state.queue.unshift({ kind: 'birthstone', unit: unit.id, replay: true, share: amount });
			break;
		case 'spectrum': {
			// One gift for every colour that has fired this turn (every gem, Flawless).
			const tally = {};
			for (const colors of unit.fired_colors || []) for (const color of colors) {
				if (!SPECTRUM_GIFTS[color]) continue;
				tally[color] = effect.every_gem ? (tally[color] | 0) + 1 : 1;
			}
			const given = [];
			for (const color of Object.keys(SPECTRUM_GIFTS)) {
				if (!(color in tally)) continue;
				const [gift, base, target] = SPECTRUM_GIFTS[color];
				const worth = Math.trunc((base * tally[color] * amount) / 100);
				if (worth <= 0) continue;
				if (gift === 'resonance') unit.resonance = (unit.resonance | 0) + worth;
				else given.push(...apply(state, unit, { kind: gift, amount: worth, target, repeat: 1 }, rng));
			}
			out.hits = given;
			break;
		}
		case 'stone_chance': {
			// A Placer: every creature fallen this turn may leave a raw stone.
			const kills = state.turn_kills | 0;
			let found = 0;
			if (!dry) {
				for (let kill = 0; kill < kills; kill++) {
					found += Math.trunc(Math.max(0, amount) / 100);
					if (rng.chance(Math.max(0, amount) % 100)) found += 1;
				}
				const field = effect.elite ? 'placer_elite_drops' : 'placer_drops';
				unit[field] = (unit[field] | 0) + found;
			}
			out.stones = found;
			break;
		}
		case 'double_resonance': unit.resonance_mult = Math.max(2, unit.resonance_mult | 0); break;
		case 'keep_phantoms': unit.keep_phantoms = true; break;
		case 'amplify_next': unit.amplify = Number(unit.amplify) * (1 + amount / 100); break;
		case 'cut_step_next': unit.cut_step_bonus = (unit.cut_step_bonus | 0) + amount; break;
		case 'grant_reroll': unit.granted_rerolls = (unit.granted_rerolls | 0) + amount; break;
		case 'quality_bonus': unit.quality_bonus = (unit.quality_bonus | 0) + amount; break;
		case 'sparkle': unit.sparkle = Math.max(0, Math.min(SPARKLE_MAX_STACKS, (unit.sparkle | 0) + Math.max(0, amount))); break;
		case 'resonance': unit.resonance = (unit.resonance | 0) + amount; break;
		case 'coin_flip': {
			// One toss, however heavy the stone; weight raises the stake instead.
			const won = dry ? true : rng.chance(amount);
			const procs = Math.max(1, effect.procs | 0);
			const mult = won ? Math.pow(Number(effect.win_mult ?? 2), procs) : Number(effect.lose_mult ?? 0);
			out.won = won;
			if (mult <= 0) unit.nullify_next = true; else unit.amplify = Number(unit.amplify) * mult;
			break;
		}
		case 'retrigger_previous':
			if (previousSocket >= 0 && !dry) state.queue.unshift({ kind: 'gem', unit: unit.id, socket: previousSocket, retrigger: true, scale: amount });
			else if (previousSocket < 0) out.nothing = true;
			break;
	}
	return out;
}

// --- the shared effect pipeline --------------------------------------------------------------

function targets(state, source, target, intentTarget = '') {
	const isPlayer = source.side === 'player';
	const friends = isPlayer ? living(state.players) : living(state.enemies);
	const foes = isPlayer ? targetable(state.enemies) : living(state.players);
	switch (target) {
		case 'self': return [source];
		case 'allies': return friends;
		case 'allies_other': return friends.filter((u) => u.id !== source.id);
		case 'heroes': return isPlayer ? friends : foes;
		case 'ally_low': {
			let lowest = source;
			for (const unit of friends) if (unit.hp / Math.max(1, unit.max_hp) < lowest.hp / Math.max(1, lowest.max_hp)) lowest = unit;
			return [lowest];
		}
		case 'enemy': case 'hero': {
			let chosen = isPlayer ? enemyById(state, aim(source)) : playerById(state, intentTarget);
			if (!chosen || (chosen.hp | 0) <= 0 || chosen.downed || (isPlayer && chosen.burrowed)) chosen = foes.length ? foes[0] : null;
			return chosen ? [chosen] : [];
		}
		case 'enemies': return foes;
		case 'enemy_adjacent': {
			let chosen = enemyById(state, aim(source));
			if ((!chosen || chosen.burrowed) && foes.length) chosen = foes[0];
			return adjacentEnemies(state, chosen).slice(0, 1);
		}
		case 'enemy_behind': {
			let chosen = enemyById(state, aim(source));
			if (!chosen || (chosen.hp | 0) <= 0 || chosen.burrowed) chosen = foes.length ? foes[0] : null;
			const index = foes.indexOf(chosen);
			return index >= 0 && index + 1 < foes.length ? [foes[index + 1]] : [];
		}
		case 'downed_ally': return state.players.filter((u) => u.downed).slice(0, 1);
	}
	return [];
}

function adjacentEnemies(state, target) {
	const out = [];
	const index = state.enemies.indexOf(target);
	if (index < 0) return out;
	for (const direction of [1, -1]) {
		for (let at = index + direction; at >= 0 && at < state.enemies.length; at += direction) {
			if ((state.enemies[at].hp | 0) > 0) { out.push(state.enemies[at]); break; }
		}
	}
	return out;
}

export function apply(state, source, effect, rng, intentTarget = '', reactions = {}) {
	const kind = effect.kind;
	const repeat = Math.max(0, effect.repeat ?? 1);
	const results = [];
	let targetKind = String(effect.target || Rules.defaultTarget(kind));
	if (source.side === 'enemy' && Rules.HOSTILE.includes(kind) && Rules.ENEMY_SIDE_TARGETS.includes(targetKind) && targetKind !== 'spread') targetKind = 'heroes';
	if (effect.split_party) {
		const party = Math.max(1, targets(state, source, targetKind, intentTarget).length);
		effect = { ...effect, amount: Math.ceil((effect.amount | 0) / party) };
	}
	if (kind === 'revive' && !targets(state, source, 'downed_ally').length) {
		// Nobody to raise: the party is healed half of it instead.
		return apply(state, source, { ...effect, kind: 'heal', target: 'allies', amount: Math.trunc((effect.amount | 0) / 2) }, rng, intentTarget);
	}
	for (let count = 0; count < repeat; count++) {
		let picked;
		if (targetKind === 'spread') { const foes = targets(state, source, 'enemies'); picked = foes.length ? [foes[count % foes.length]] : []; }
		else picked = targets(state, source, targetKind, intentTarget);
		for (const target of picked) {
			let hit = applyOne(state, source, target, kind, effect.amount | 0, effect, rng, reactions);
			results.push(hit);
			while (effect.chain_on_kill && hit.killed && (source.hp | 0) > 0) {
				const survivors = living(state.enemies);
				if (!survivors.length) break;
				hit = applyOne(state, source, survivors[0], kind, effect.amount | 0, effect, rng, reactions);
				results.push(hit);
			}
		}
	}
	return results;
}

function wardBlocks(target) {
	const ward = target.statuses.ward | 0;
	if (ward <= 0) return false;
	target.statuses.ward = ward - 1;
	return true;
}

function resetDefenses(unit) {
	// Spikes are no longer cleared here: they last the fight.
	unit.block = Math.min(unit.block | 0, Math.max(0, unit.statuses.retain | 0));
	delete unit.statuses.retain;
}

export function applyOne(state, source, target, kind, amount, effect, rng, reactions = {}) {
	if (effect.from_result) amount = Math.trunc(((reactions[`result_${effect.from_result}`] | 0) * amount) / 100);
	// A share of what its owner carries as it lands: a Caltrop's Spikes, a Hemlock's Poison.
	if (effect.of_status) amount = Math.trunc((((source.statuses || {})[effect.of_status] | 0) * amount) / 100);
	const out = { kind, target: target.id, amount };
	if (kind === 'stun' && (target.statuses.combo_breaker | 0) > 0) { out.resisted = true; return out; }
	// Ward turns away what others do to it, never what it does to itself.
	if (Rules.DEBUFFS.includes(kind) && amount > 0 && source.id !== target.id && wardBlocks(target)) { out.warded = true; return out; }
	switch (kind) {
		case 'damage': case 'damage_curse': case 'detonate': case 'wager': {
			const adjacent = adjacentEnemies(state, target);
			let spent = 0, consumed = 0;
			if (kind === 'damage_curse') amount = Math.trunc((amount * (target.statuses.curse | 0)) / 100);
			else if (kind === 'detonate') { consumed = target.statuses.poison | 0; target.statuses.poison = 0; amount *= consumed; }
			else if (kind === 'wager') {
				spent = effect.cost | 0;
				if (Rules.pyrite(source) < spent) { out.unaffordable = true; return out; }
				source.pyrite_delta = (source.pyrite_delta | 0) - spent;
			}
			if (effect.missing_hp_bonus) amount = Math.trunc((amount * (2 * (source.max_hp | 0) - (source.hp | 0))) / Math.max(1, source.max_hp | 0));
			// A player's Strength (Temper) puts a point more on every blow.
			if (kind === 'damage' && amount > 0 && source.side === 'player') amount += Math.max(0, (source.statuses || {}).strength | 0);
			out.kind = 'damage';
			out.amount = amount;
			Object.assign(out, damage(state, source, target, amount, rng, reactions, false, Boolean(effect.piercing)));
			reactions.result_damage = (reactions.result_damage | 0) + (out.hp_loss | 0);
			if (spent > 0 && out.killed) source.pyrite_delta += spent * Number(effect.refund_mult ?? 2);
			const splash = effect.splash | 0;
			if (splash > 0) for (const neighbour of adjacent) damage(state, source, neighbour, Math.trunc((amount * splash) / 100), rng, reactions);
			if (consumed > 0 && (effect.poison_splash | 0) > 0) for (const neighbour of adjacent) applyOne(state, source, neighbour, 'poison', Math.trunc((consumed * effect.poison_splash) / 100), {}, rng, reactions);
			break;
		}
		case 'block':
			if ((target.statuses.scorched | 0) > 0 && amount > 0) amount = Math.ceil(amount / 2);
			target.block = (target.block | 0) + amount;
			if (target.side === 'player') state.ledger.blockGained += amount;
			reactions.result_block = (reactions.result_block | 0) + amount;
			// A Rebound: every time its owner gains block this turn, the target takes a hit.
			if (amount > 0 && target.side === 'player' && (target.on_block || []).length && (target.hp | 0) > 0) {
				for (const answer of target.on_block) apply(state, target, { kind: 'damage', amount: answer.amount | 0, target: answer.target, repeat: 1 }, rng);
			}
			break;
		case 'heal': {
			const healed = heal(state, target, amount);
			out.healed = healed;
			if (source.side === 'player') source.healed = (source.healed | 0) + healed;
			// What would heal past full: block for a Wellspring, a blow for a Flawless Thirst.
			const spill = ((target.statuses.festering | 0) > 0 ? Math.trunc(Math.max(0, amount) / 2) : Math.max(0, amount)) - healed;
			if (effect.overflow && spill > 0 && (target.hp | 0) > 0) {
				if (effect.overflow === 'block') applyOne(state, source, target, 'block', spill, {}, rng, reactions);
				else apply(state, source, { kind: 'damage', amount: spill, target: 'enemy', repeat: 1 }, rng, '', reactions);
			}
			break;
		}
		case 'gold':
			if (source.side === 'player') {
				// Pyrite a gem sends to the party lands in each ally's own purse.
				const purse = target.side === 'player' ? target : source;
				purse.gold = (purse.gold | 0) + amount;
				reactions.result_gold = (reactions.result_gold | 0) + amount;
			}
			else if (target.side === 'player') target.gold = (target.gold | 0) + amount;
			break;
		case 'max_hp':
			target.max_hp = (target.max_hp | 0) + Math.max(0, amount);
			target.hp = (target.hp | 0) + Math.max(0, amount);
			if (target.side === 'player') state.ledger.healed += Math.max(0, amount);
			break;
		case 'max_hp_loss': {
			const before = target.hp | 0;
			target.max_hp = Math.max(1, (target.max_hp | 0) - Math.max(0, amount));
			target.hp = Math.min(target.hp | 0, target.max_hp);
			if (target.side === 'enemy') state.ledger.dealt += before - target.hp;
			break;
		}
		case 'ward': target.statuses.ward = Math.min(99, (target.statuses.ward | 0) + Math.max(0, amount)); break;
		case 'retain': target.statuses.retain = Math.min(20, (target.statuses.retain | 0) + Math.max(0, amount)); break;
		case 'clouded':
			if (target.side === 'enemy') {
				const moves = target.dice.length;
				if (moves > 0 && amount > 0) {
					if ((target.statuses.clouded | 0) <= 0) target.clouded_move = rng.randiRange(0, moves - 1);
					target.statuses.clouded = (target.statuses.clouded | 0) + amount;
				}
			}
			break;
		case 'remove_block': {
			const removed = effect.remove_all ? target.block | 0 : Math.min(target.block | 0, amount);
			target.block = (target.block | 0) - removed;
			out.removed = removed;
			reactions.result_removed = (reactions.result_removed | 0) + removed;
			break;
		}
		case 'cleanse': {
			let cleared = 0;
			for (const status of ['poison', 'burn', 'stun', 'curse', 'marked', 'dulled', 'clouded', 'festering', 'scorched']) {
				while (cleared < amount && (target.statuses[status] | 0) > 0) { target.statuses[status] -= 1; cleared += 1; }
			}
			if (cleared < amount) { const dread = Math.min(amount - cleared, target.dread_turns | 0); target.dread_turns = (target.dread_turns | 0) - dread; cleared += dread; }
			if (cleared < amount) { const bound = Math.min(amount - cleared, target.stolen_dice | 0); target.stolen_dice = (target.stolen_dice | 0) - bound; cleared += bound; }
			out.cleared = cleared;
			break;
		}
		case 'dice_dread':
			if (target.side === 'player') target.statuses.dread = (target.statuses.dread | 0) + Math.max(0, amount);
			else target.dread_turns = (target.dread_turns | 0) + Math.max(0, amount);
			break;
		case 'die_steal': target.stolen_dice = (target.stolen_dice | 0) + amount; break;
		case 'gather_poison': {
			// A Confluence: every other creature's Poison moves onto this one.
			let gathered = 0;
			for (const other of living(state.enemies)) {
				if (other.id === target.id) continue;
				gathered += other.statuses.poison | 0;
				other.statuses.poison = 0;
			}
			target.statuses.poison = (target.statuses.poison | 0) + gathered;
			break;
		}
		case 'poison_tick':
			for (let time = 0; time < Math.max(0, amount); time++) {
				if ((target.statuses.poison | 0) <= 0 || (target.hp | 0) <= 0) break;
				poisonTick(state, target);
			}
			break;
		case 'grow_poison': {
			const had = target.statuses.poison | 0;
			target.statuses.poison = had + Math.trunc((had * Math.max(0, amount)) / 100);
			break;
		}
		default:
			if (STATUS_KINDS.includes(kind)) {
				// Lodestone stores no more than the Resonance there is to store.
				if (kind === 'charged' && effect.resonance_cap) { amount = Math.min(amount, Math.max(0, source.resonance | 0)); out.amount = amount; }
				target.statuses[kind] = (target.statuses[kind] | 0) + Math.max(0, amount);
				if (kind === 'curse') target.statuses.curse = Math.min(Rules.CURSE_MAX_STACKS, target.statuses.curse);
				if (kind === 'lifeline' && effect.revive_block) target.statuses.lifeline_block = (target.statuses.lifeline_block | 0) + amount;
			}
	}
	return out;
}

// One blow, the way sim/battle.gd _damage lands it, without the creature traits a dummy lacks.
function damage(state, source, target, amount, rng, reactions = {}, reactive = false, piercing = false) {
	let raw = Math.max(0, amount);
	if (source.side === 'enemy') {
		const enrageTurn = Number(C.constant('enrage_turn', 7));
		if (state.turn >= enrageTurn) raw += Number(C.constant('enrage_damage', 2)) * (state.turn - enrageTurn + 1);
	}
	const sourceCurse = Math.max(0, Math.min(Rules.CURSE_MAX_STACKS, (source.statuses || {}).curse | 0));
	raw = Math.trunc((raw * (100 - Rules.CURSE_PERCENT * sourceCurse)) / 100);
	const curse = Math.max(0, Math.min(Rules.CURSE_MAX_STACKS, target.statuses.curse | 0));
	const marked = !reactive && amount > 0 ? target.statuses.marked | 0 : 0;
	raw = Math.trunc((raw * (100 + Rules.CURSE_PERCENT * curse) * (100 + 25 * marked)) / 10000);
	if (marked > 0) delete target.statuses.marked;
	const out = { raw };
	const absorbed = piercing ? 0 : Math.min(target.block | 0, raw);
	target.block = (target.block | 0) - absorbed;
	const through = raw - absorbed;
	const loss = Math.min(target.hp | 0, through);
	target.hp = (target.hp | 0) - loss;
	const rescued = lifeline(target);
	Object.assign(out, { absorbed, hp_loss: loss });
	if (target.side === 'player') {
		target.block_lost_accum = (target.block_lost_accum | 0) + absorbed;
		state.ledger.hpLost += state.noDowns ? through : loss;
		if (rescued > 0) state.ledger.healed += rescued;
		if ((target.hp | 0) <= 0) {
			if (state.noDowns) { target.hp = 1; state.ledger.downs += 1; } else { target.downed = true; target.block = 0; out.downed = true; }
		}
	} else {
		state.ledger.dealt += loss;
		source.dealt = (source.dealt | 0) + loss;
		if (source.side === 'player' && !reactive) {
			target.hurt_by[source.id] = (target.hurt_by[source.id] | 0) + loss;
			if (loss > (target.biggest_hit | 0)) target.biggest_hit = loss;
		}
		// Riposte: every hit the Rogue lands raises block worth her Resonance.
		if (source.side === 'player' && (source.passive || {}).kind === 'block_per_hit' && raw > 0) {
			const parry = source.resonance | 0;
			if (parry > 0) { source.block = (source.block | 0) + parry; state.ledger.blockGained += parry; }
		}
		if ((target.hp | 0) <= 0) { out.killed = true; state.turn_kills = (state.turn_kills | 0) + 1; }
	}
	// An Arsenic: every hit that gets past block leaves Poison behind.
	const venom = (source.statuses || {}).envenom | 0;
	if (!reactive && venom > 0 && loss > 0 && target.side === 'enemy' && (target.hp | 0) > 0 && source.side === 'player') applyOne(state, source, target, 'poison', venom, {}, rng, reactions);
	const spikes = target.statuses.spikes | 0;
	if (!reactive && amount > 0 && spikes > 0 && !reactions[target.id] && (source.hp | 0) > 0) {
		reactions[target.id] = true;
		damage(state, target, source, spikes, rng, {}, true);
	}
	return out;
}

function lifeline(unit) {
	const stacks = unit.statuses.lifeline | 0;
	if ((unit.hp | 0) > 0 || stacks <= 0) return 0;
	delete unit.statuses.lifeline;
	unit.hp = Math.min(unit.max_hp | 0, stacks);
	unit.downed = false;
	unit.block = (unit.block | 0) + (unit.statuses.lifeline_block | 0);
	delete unit.statuses.lifeline_block;
	return unit.hp | 0;
}

function heal(state, target, amount) {
	if (target.downed || (target.hp | 0) <= 0) return 0;
	if ((target.statuses.festering | 0) > 0) amount = Math.trunc(Math.max(0, amount) / 2);
	const before = target.hp | 0;
	target.hp = Math.min(target.max_hp | 0, before + Math.max(0, amount));
	const healed = (target.hp | 0) - before;
	if (target.side === 'player') state.ledger.healed += healed;
	return healed;
}

function poisonTick(state, unit) {
	const poison = unit.statuses.poison | 0;
	if (poison <= 0 || (unit.hp | 0) <= 0) return;
	const loss = Math.min(unit.hp | 0, poison);
	unit.hp -= loss;
	unit.statuses.poison = poison - 1;
	if (unit.side === 'player') state.ledger.hpLost += loss; else state.ledger.dealt += loss;
	if (unit.side === 'enemy' && (unit.hp | 0) <= 0) state.turn_kills = (state.turn_kills | 0) + 1;
	if (unit.side === 'enemy' && loss > 0) {
		// Leech: every Apothecary drinks Resonance from the creature that bleeds.
		for (const drinker of living(state.players)) if ((drinker.passive || {}).kind === 'heal_on_poison_tick' && (drinker.resonance | 0) > 0) heal(state, drinker, drinker.resonance | 0);
	}
}

function burnTick(state, unit) {
	const burn = unit.statuses.burn | 0;
	if (burn <= 0 || (unit.hp | 0) <= 0) return;
	const soaked = Math.min(Math.max(0, unit.block | 0), burn);
	unit.block = (unit.block | 0) - soaked;
	const loss = Math.min(unit.hp | 0, burn - soaked);
	unit.hp -= loss;
	unit.statuses.burn = burn - 1;
	if (unit.side === 'player') state.ledger.hpLost += loss; else state.ledger.dealt += loss;
}

export function tick(state) {
	for (const unit of state.players.concat(state.enemies)) {
		if ((unit.hp | 0) <= 0 || unit.downed) continue;
		poisonTick(state, unit);
		burnTick(state, unit);
		const regen = unit.statuses.regeneration | 0;
		if (regen > 0) { heal(state, unit, regen); unit.statuses.regeneration = regen - 1; }
		for (const fading of ['curse', 'dulled', 'combo_breaker', 'festering', 'scorched']) if ((unit.statuses[fading] | 0) > 0) unit.statuses[fading] -= 1;
	}
}

// --- turns -----------------------------------------------------------------------------------

// The player's half of sim/battle.gd _begin_turn: defences fall, Charged becomes Resonance,
// the bowl is thrown, the rerolls are counted. `roll(die, index)` throws one die.
export function beginTurn(state, unit, roll) {
	resetDefenses(unit);
	// What a Chainmail, a Contagion or a Rebound set up lasted the turn that has ended.
	unit.after_fire = [];
	unit.on_block = [];
	// A Contra Luz that fired last turn: its phantoms are still in the hand.
	const carried = unit.keep_phantoms ? unit.hand.filter((r) => r.phantom).map((r) => ({ ...r, held: true, rerolls: 0, kept: true })) : [];
	unit.keep_phantoms = false;
	const charged = unit.statuses.charged | 0;
	delete unit.statuses.charged;
	unit.initial_resonance = charged;
	unit.resonance = charged;
	// A Sticky face that was showing is not thrown again.
	const kept = new Map();
	for (const r of unit.hand) if ((r.kind || 'plain') === 'sticky' && !r.phantom) kept.set(r.die_id, r);
	unit.hand = unit.dice.map((die, index) => (kept.has(die.id) ? { ...kept.get(die.id), held: true, rerolls: 0, phantom: false, climbed: false, shattered: false, carried: true } : roll(die, index)));
	unit.hand.push(...carried);
	payDues(unit, unit.hand);
	unit.flips = unit.passive.kind === 'free_flip' ? Number(unit.passive.amount ?? 1) : 0;
	const extra = unit.passive.kind === 'extra_reroll' ? Number(unit.passive.amount ?? 1) : 0;
	unit.rerolls_max = Number(C.constant('rerolls', 2)) + extra + (unit.granted_rerolls | 0);
	unit.rerolls = unit.rerolls_max;
	unit.granted_rerolls = 0;
	unit.locked = false;
	unit.block_lost = unit.block_lost_accum | 0;
	unit.block_lost_accum = 0;
	unit.dealt_last_turn = unit.dealt | 0;
	unit.dealt = 0;
	unit.healed = 0;
	const foes = living(state.enemies);
	const current = enemyById(state, String(unit.target || ''));
	if ((!current || (current.hp | 0) <= 0) && foes.length) unit.target = foes[0].id;
}

function payDues(unit, rolls) {
	const dues = Dice.throwDues(rolls);
	if (dues.resonance > 0) { unit.initial_resonance += dues.resonance; unit.resonance += dues.resonance; }
	if (dues.pyrite > 0) unit.pyrite_delta = (unit.pyrite_delta | 0) + dues.pyrite;
	if (dues.hp > 0 && !unit.downed) unit.hp = Math.max(1, unit.hp - dues.hp);
}

// Spend the rerolls chasing `policy` (see simulate.js), then Sleight's parity shift if the
// character has one and it helps.
export function plan(unit, policy, roll) {
	while ((unit.rerolls | 0) > 0) {
		if (policy === 'none') break;
		const ids = rerollIds(policy, unit.hand, readHand(unit));
		const allowed = new Set(Dice.rerollable(unit.hand));
		const chosen = [...ids].filter((id) => allowed.has(id));
		if (!chosen.length) break;
		const set = new Set(chosen);
		const byId = new Map(unit.dice.map((d, i) => [d.id, [d, i]]));
		const next = [];
		for (const r of unit.hand) {
			if (r.phantom) continue;
			if (set.has(r.die_id) && !r.locked && byId.has(r.die_id)) { const [die, index] = byId.get(r.die_id); next.push(roll(die, index, (r.rerolls | 0) + 1)); }
			else next.push({ ...r, held: true, climbed: false, shattered: false });
		}
		unit.hand = next;
		unit.rerolls -= 1;
		payDues(unit, unit.hand.filter((r) => set.has(r.die_id)));
	}
	if ((unit.flips | 0) > 0) flipBest(unit, policy);
	unit.locked = true;
}

// How well a hand answers a reroll policy, for choosing what Sleight should shift.
function policyScore(policy, a) {
	if (policy === 'sets') return (a.best_set.count || 0) * 100 + (a.best_set.value || 0) + (a.pairs.length >= 2 ? 50 : 0);
	if (policy === 'straight') return a.straight.length || 0;
	if (policy === 'odd') return a.odd;
	if (policy === 'even') return a.even;
	if (policy === 'distinct') return a.distinct;
	if (policy === 'skip') return Math.max(a.odd_values, a.even_values);
	if (policy.startsWith('value:')) { const wanted = policy.slice(6).split(',').map(Number); let n = 0; for (const w of wanted) n += (a.ids_by_value.get(w) || []).length; return n; }
	if (policy === 'low') return -a.total;
	if (policy === 'high' || policy === 'always') return a.total;
	return null;
}

function flipBest(unit, policy) {
	const base = policyScore(policy, readHand(unit));
	if (base === null) return;
	let best = null, bestScore = base;
	for (const r of unit.hand) {
		if (r.phantom || (r.kind || 'plain') !== 'plain') continue;
		const face = shiftFace(unit, r);
		if (face < 0) continue;
		const was = r.value;
		r.value = shiftedValue(unit, r, face);
		const score = policyScore(policy, Hand.analyze(unit.hand));
		r.value = was;
		if (score > bestScore) { bestScore = score; best = r; }
	}
	if (best) {
		const face = shiftFace(unit, best);
		best.value = shiftedValue(unit, best, face);
		best.face = face;
		delete best.shown;
		delete best.counted;
		best.flipped = true;
		unit.flips -= 1;
		touchHand(unit);
	}
}

// Sleight lands on a plain face of the other parity the die really has: its mirror face, else
// the nearest of the other parity to it. A port of DeepBattle.shift_face.
function shiftFace(unit, roll) {
	const die = (unit.dice || []).find((d) => d.id === roll.die_id);
	const faces = (die && die.faces) || [];
	const previous = roll.value | 0;
	const mirror = Math.max(1, roll.top ?? Dice.top(die || {})) + 1 - previous;
	let best = -1;
	for (let index = 0; index < faces.length; index += 1) {
		if ((faces[index].kind || 'plain') !== 'plain') continue;
		const value = Dice.faceValue(faces[index]);
		if (value <= 0 || value % 2 === previous % 2) continue;
		if (best < 0) { best = index; continue; }
		const held = Dice.faceValue(faces[best]);
		const distance = Math.abs(value - mirror);
		const bestDistance = Math.abs(held - mirror);
		if (distance < bestDistance || (distance === bestDistance && Math.abs(value - previous) < Math.abs(held - previous))) best = index;
	}
	return best;
}

function shiftedValue(unit, roll, face) {
	const die = (unit.dice || []).find((d) => d.id === roll.die_id);
	return Dice.faceValue(die.faces[face]);
}

// --- the dummies' half of a turn -------------------------------------------------------------

const TIERS = Dice.TIERS;

function faceAt(die, u) {
	const faces = die.faces && die.faces.length ? die.faces : [Dice.face(1)];
	return Dice.faceValue(faces[Math.min(faces.length - 1, Math.floor(u * faces.length))]);
}

function shrunk(die, dread) {
	if (dread <= 0) return die;
	const index = TIERS.indexOf(String(die.shape || 'D6'));
	const tier = Math.max(0, index - dread);
	return tier === index ? die : Dice.make(TIERS[tier], die.id);
}

// What a creature's block does as the creatures begin: it stood through one volley of gems.
export function creaturesBegin(state) {
	for (const foe of state.enemies) resetDefenses(foe);
}

// One dummy's action. Every die's throw is drawn first, whether or not it is thrown, so the
// dummies throw the same numbers whatever the rail did to them, and `incoming` is what would
// have come at the player with nothing in the way.
export function dummyAct(state, foe, rng) {
	const target = living(state.players)[0];
	const draws = foe.dice.map(() => rng.randf());
	const enrageTurn = Number(C.constant('enrage_turn', 7));
	const enrage = state.turn >= enrageTurn ? Number(C.constant('enrage_damage', 2)) * (state.turn - enrageTurn + 1) : 0;
	foe.dice.forEach((die, i) => { state.ledger.incoming += faceAt(die, draws[i]) + enrage; });
	if ((foe.hp | 0) <= 0) return;
	const suppressed = Math.min(foe.dice.length, foe.stolen_dice | 0);
	foe.stolen_dice = 0;
	if ((foe.statuses.stun | 0) > 0 || (foe.dice.length && suppressed >= foe.dice.length)) {
		if ((foe.statuses.stun | 0) > 0) {
			foe.statuses.stun -= 1;
			foe.stun_streak = (foe.stun_streak | 0) + 1;
			if (foe.stun_streak >= 3) { foe.statuses.stun = 0; foe.statuses.combo_breaker = 2; foe.stun_streak = 0; }
		} else foe.stun_streak = 0;
		finish(foe);
		return;
	}
	foe.stun_streak = 0;
	if (foe.guard > 0) foe.block = (foe.block | 0) + foe.guard;
	const dread = Math.max(0, foe.dread_turns | 0);
	const clouded = (foe.statuses.clouded | 0) > 0 ? foe.clouded_move : -1;
	for (let i = 0; i < foe.dice.length - suppressed; i++) {
		if (i === clouded || !target) continue;
		damage(state, foe, target, faceAt(shrunk(foe.dice[i], dread), draws[i]), rng);
	}
	finish(foe);
}

function finish(foe) {
	foe.turns_acted = (foe.turns_acted | 0) + 1;
	foe.hurt_by = {};
	foe.biggest_hit = 0;
	foe.dread_turns = Math.max(0, (foe.dread_turns | 0) - 1);
	if ((foe.statuses.clouded | 0) > 0) {
		foe.statuses.clouded -= 1;
		if (foe.statuses.clouded === 0) foe.clouded_move = -1;
	}
}

// --- a whole fight ---------------------------------------------------------------------------

const mix = (a, b, c) => {
	let x = (Math.imul(a | 0, 0x9e3779b1) ^ Math.imul((b | 0) + 0x7f4a7c15, 0x85ebca6b) ^ Math.imul((c | 0) + 0x165667b1, 0xc2b2ae35)) >>> 0;
	x ^= x >>> 16; x = Math.imul(x, 0x7feb352d) >>> 0; x ^= x >>> 15;
	return x >>> 0 || 1;
};

// One seeded fight: `spec` = {character, rail: [stones], sockets?, policy, turns, dummies:
// {count, dice, guard, hp}, pyrite, depth, birthstone, passive, seed}; `sample` picks the fight.
// Every random number comes from a stream named for what it is for, and each die has a
// stream of its own each turn, so two rails played on the same sample throw the same dice
// for as long as they make the same choices: the differences between them are the rails'.
//
// Returns the ledger: dealt (damage the dummies took), kills, incoming (what they threw), hpLost,
// healed, gold (pyrite won: gold, spent and staked), blockGained, fires, fizzles, birthstone
// (rails it fired on), resonance (built, summed over rails), downs, sparkle.
export function playFight(spec, sample) {
	const seed = spec.seed | 0;
	const turns = Math.max(1, spec.turns | 0);
	const character = C.character(spec.character);
	const bowl = (spec.dice || character.dice || []).map((ref, i) => Dice.dieFrom(ref, `p${i}`));
	const unit = makePlayer('p0', spec.character, spec.rail || [], bowl, { sockets: spec.sockets || (spec.rail || []).map(() => C.SOCKET_ANY), pyrite: spec.pyrite ?? 0,
		birthstone: spec.birthstone !== false, passive: spec.passive !== false });
	const dummies = spec.dummies || {};
	const enemies = Array.from({ length: Math.max(1, dummies.count | 0 || 1) }, (_, i) => makeDummy(`e${i}`, dummies));
	const state = makeFight({ players: [unit], enemies, depth: spec.depth | 0 || 1, noDowns: true });
	const misc = makeRng(mix(seed, sample, 1));
	const creatures = makeRng(mix(seed, sample, 2));
	const streams = new Map();
	const roll = (die, index, rerolled = 0) => {
		const key = state.turn * 64 + index;
		let rng = streams.get(key);
		if (!rng) { rng = makeRng(mix(seed, sample, 100 + key)); streams.set(key, rng); }
		return Dice.rollOne(die, rng, rerolled);
	};
	const policy = spec.policy || 'none';
	for (let turn = 1; turn <= turns; turn++) {
		state.turn = turn;
		state.turn_kills = 0;
		standDummies(state);
		beginTurn(state, unit, roll);
		plan(unit, policy, roll);
		startRail(state, unit);
		runQueue(state, misc);
		creaturesBegin(state);
		for (const foe of state.enemies) dummyAct(state, foe, creatures);
		tick(state);
	}
	const L = state.ledger;
	return { dealt: L.dealt, kills: L.kills, incoming: L.incoming, hpLost: L.hpLost, healed: L.healed, gold: (unit.gold | 0) + (unit.pyrite_delta | 0) + (unit.pot | 0), blockGained: L.blockGained,
		fires: L.fires, fizzles: L.fizzles, birthstone: L.birthstone, resonance: L.resonance, downs: L.downs, sparkle: unit.sparkle | 0 };
}
