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
import { I, satAdd, satMul, satFloor, satMulDiv, satScale } from './numbers.js';
import { rerollIds } from './simulate.js';

export const HAND_KINDS = ['raise_low', 'raise_high', 'set_match', 'flip_low', 'flip_high', 'phantom_high', 'phantom_low'];
export const SELF_KINDS = ['amplify_next', 'cut_step_next', 'grant_reroll', 'retrigger_previous', 'quality_bonus', 'sparkle',
	'coin_flip', 'resonance', 'replay_color', 'replay_fizzled', 'rank_buff', 'repeat_next', 'void_copy', 'gem_rank', 'upgrade_faces', 'stake', 'appraise',
	'fire_neighbours', 'force_after', 'absorbed',
	'phantom_roll', 'rethrow', 'gild', 'soak', 'each_after', 'on_block', 'fire_birthstone', 'spectrum', 'stone_chance',
	'double_resonance', 'keep_phantoms', 'bonus_die', 'double_resonance_next', 'lose_pyrite', 'reflect_blows', 'invert_previous'];
// What an Invert gives back for what the gem before it did, in the order it gives it, as
// [effect kind, what it reads, target] (DeepBattle.INVERTED).
const INVERTED = [['block', ['damage'], 'self'], ['damage', ['block', 'retain'], 'enemy'],
	['poison', ['heal', 'regeneration'], 'enemy'], ['heal', ['poison'], 'self'], ['marked', ['spikes'], 'enemy'],
	['spikes', ['marked'], 'self'], ['curse', ['strength'], 'enemy'], ['strength', ['curse'], 'self']];
const INVERTED_HOSTILE = ['damage', 'poison', 'marked', 'curse'];
// The six colors and what a Spectrum gives for each, as [effect kind, amount, target].
const SPECTRUM_GIFTS = { RED: ['damage', 3, 'enemy'], BLUE: ['block', 3, 'self'], GREEN: ['heal', 3, 'self'], VIOLET: ['poison', 2, 'enemy'], GOLD: ['gold', 2, 'self'], WHITE: ['resonance', 1, 'self'] };
const DROPS_PER_SIZE = 3;
export const BIRTHSTONE_KINDS = ['replay_rail', 'tick_poison', 'stone_drop', 'pot'];
const PROC_IN_PLACE = ['coin_flip'];
const MAX_RAIL = 24;
// The most gems (and Birthstone firings) one rail may play in a turn (DeepBattle.RAIL_CAP).
export const RAIL_CAP = 200;
const SPARKLE_MAX_STACKS = 100;
const STATUS_KINDS = ['poison', 'stun', 'curse', 'charged', 'marked', 'regeneration', 'spikes', 'dulled', 'lifeline', 'festering', 'scorched', 'burn', 'strength', 'envenom'];
export const DUMMY_HP = 1000000;

// --- units ---------------------------------------------------------------------------------

const living = (units) => units.filter((u) => (I(u.hp)) > 0 && !u.downed);
const targetable = (units) => living(units).filter((u) => !u.burrowed);
const enemyById = (state, id) => state.enemies.find((u) => u.id === id) || null;
const playerById = (state, id) => state.players.find((u) => u.id === id) || null;
const aim = (unit) => String(unit.firing_target ?? unit.target ?? '');
const isEmpty = (o) => !o || !Object.keys(o).length;

// What the hand shows, read once for as long as it stands still. A hand of plain dice reads
// the same whatever color asks (only materials and boon faces change which die is preferred),
// so one reading serves every gem; anything that changes the hand in place calls touchHand.
function touchHand(unit) { unit.hand_version = (I(unit.hand_version)) + 1; }
function readHand(unit, colors = []) {
	const hand = unit.hand;
	let cache = unit.reading;
	if (!cache || cache.hand !== hand || cache.version !== (I(unit.hand_version))) {
		cache = { hand, version: I(unit.hand_version), plain: hand.every((r) => !r.material && !Dice.BOON_FACES.includes(r.kind || 'plain')), by: new Map() };
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
// `opts.sockets` the socket colors (the character's own by default), `opts.pyrite` what they
// carry, `opts.birthstone`/`opts.passive` false to leave either out.
export function makePlayer(id, characterKey, rail, dice, opts = {}) {
	const character = C.character(characterKey);
	const sockets = (opts.sockets || character.sockets || [C.SOCKET_RAINBOW]).slice();
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
		block_lost: 0, block_lost_accum: 0, healed: 0, dealt: 0, dealt_last_turn: 0, gold: 0, ore: I(Number(opts.pyrite ?? 0)), once: {}, downed: false,
		buried: [], clouded: [], stolen_dice: 0, granted_rerolls: 0, sparkle: 0, quality_bonus: 0, fired_count: 0, void_copies: 0, haul: [],
		bonus_dice_next: [], double_resonance_next: false, resonance_doubled: false,
		last_face: '', face_shown: '', change: 0, change_now: 0,
	};
}

// --- All or Nothing (DeepBattle.all_or_nothing and friends) ------------------------------------

export const allOrNothing = (unit) => (unit.passive || {}).kind === 'all_or_nothing';

// A die showing its own top face, read the way the hand counts crowns: a wild always is.
export function isCrown(roll) {
	const kind = roll.kind || 'plain';
	if (kind === 'wild') return true;
	if (kind === 'blank') return false;
	return (I(roll.value)) >= Math.max(1, I(roll.top ?? roll.value ?? 1));
}

function crownIds(hand) {
	const out = new Set();
	for (const r of hand) if (isCrown(r)) out.add(r.die_id);
	return out;
}

// Every crown that comes up rings the rail once; in planning it is banked, as Crystal is.
function crownsRolled(unit, rolls, planning) {
	if (!allOrNothing(unit)) return [];
	const crowned = rolls.filter((r) => !r.carried && !r.kept && isCrown(r)).map((r) => r.die_id);
	if (crowned.length) {
		if (planning) unit.initial_resonance = satAdd(I(unit.initial_resonance), crowned.length);
		unit.resonance = satAdd(I(unit.resonance), crowned.length);
	}
	return crowned;
}

// The crowns a gem's turn on the hand brought up, counted the same way.
function crownsChanged(unit, before) {
	if (!allOrNothing(unit)) return [];
	const fresh = unit.hand.filter((r) => isCrown(r) && !before.has(r.die_id)).map((r) => r.die_id);
	if (fresh.length) unit.resonance = satAdd(I(unit.resonance), fresh.length);
	return fresh;
}

// The die in the hand with the most faces; between two as large, the one showing more.
function largestDie(unit) {
	let best = null, bestRoll = null;
	for (const r of unit.hand) {
		if (r.phantom) continue;
		const die = (unit.dice || []).find((d) => d.id === r.die_id);
		if (!die) continue;
		const faces = (die.faces || []).length;
		const bestFaces = best ? (best.faces || []).length : -1;
		if (!best || faces > bestFaces || (faces === bestFaces && (I(r.value)) > (I(bestRoll.value)))) { best = die; bestRoll = r; }
	}
	return best;
}

// A training dummy: `hp` (endless when 0), `dice` to throw at the player every action (each
// die one move: a blow for what it shows), `guard`, block it raises as it acts, and `hit`, what
// every blow is multiplied by (a deeper mine's creatures hit harder).
export function makeDummy(id, spec = {}) {
	const dice = (spec.dice || ['D6', 'D4']).map((k, i) => Dice.dieFrom(k, `${id}_d${i}`));
	const hp = Number(spec.hp || 0) > 0 ? Number(spec.hp) : DUMMY_HP;
	return { id, name: 'Dummy', side: 'enemy', hp, max_hp: hp, block: 0, statuses: {}, dice, guard: I(Number(spec.guard ?? 0)), hit: Number(spec.hit ?? 1) || 1,
		stolen_dice: 0, dread_turns: 0, clouded_move: -1, stun_streak: 0, turns_acted: 0, hurt_by: {}, hurt_by_color: {}, biggest_hit: 0, gimmick: '', traits: {} };
}

// A dummy that fell is stood up again, fresh, as a turn begins.
export function standDummies(state) {
	for (const foe of state.enemies) {
		if ((I(foe.hp)) > 0) continue;
		Object.assign(foe, { hp: foe.max_hp_start ?? foe.max_hp, block: 0, statuses: {}, stolen_dice: 0, dread_turns: 0, clouded_move: -1, stun_streak: 0, hurt_by: {}, biggest_hit: 0 });
		foe.max_hp = foe.hp;
		state.ledger.kills += 1;
	}
}

// A fight state the way sim/battle.gd begin() leaves one, before the first hand is thrown.
export function makeFight({ players, enemies, depth = 1, noDowns = false }) {
	const state = { turn: 0, phase: 'planning', depth, party: players.length, players, enemies, queue: [], noDowns,
		ledger: { dealt: 0, hpLost: 0, healed: 0, blockGained: 0, fires: 0, fizzles: 0, birthstone: 0, resonance: 0, downs: 0, incoming: 0, kills: 0, runaway: 0, maxEvents: 0 } };
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
			if (shared) caratBonus += I(Number(m.amount ?? 1));
		}
	}
	const buff = unit.rank_buff || {};
	const gemBuff = (unit.gem_buffs || {})[String(stone.id)] || {};
	caratBonus += (I(buff.carat)) + (I(gemBuff.carat));
	const dark = unit.fizzled_sockets || [];
	let unpaid = 0;
	for (let index = I((unit.tailings_paid || {})[String(stone.id)]); index < dark.length; index++) if (dark[index] !== socket) unpaid += 1;
	let enemyPoison = 0;
	for (const foe of living(state.enemies)) enemyPoison += I(foe.statuses.poison);
	return { unit, resonance: I(unit.resonance), previous_fired: Boolean(unit.previous_fired), previous_amount: I(unit.previous_amount), amplify: Number(unit.amplify ?? 1),
		cut_step_bonus: (I(unit.cut_step_bonus)) + (I(buff.cut)) + (I(gemBuff.cut)), carat_bonus: caratBonus, clarity_bonus: I(gemBuff.clarity),
		enemy_poison: enemyPoison, carat_cap: 0, fizzles: unpaid, dulled: I(unit.statuses.dulled), depth: I(state.depth), turn: I(state.turn), party: I(state.party),
		socket: socketColor, retrigger: Boolean(opts.retrigger), force_fire: Boolean(opts.force), analyze: (colors) => readHand(unit, colors),
		kills: I(state.turn_kills), run_fires: I((unit.run_counts || {})[String(stone.id || '')]) };
}

// What a Doublet at this socket wears: the nearest gem behind it, opals included, that is not
// itself a Doublet (sim/battle.gd worn_socket).
export function wornSocket(unit, socket) {
	const stone = unit.rail[socket];
	if (!stone || String(Stone.skillOf(stone).wears || '') !== 'prev') return -1;
	for (let behind = socket - 1; behind >= 0; behind--) if (unit.rail[behind] && String(Stone.skillOf(unit.rail[behind]).wears || '') !== 'prev') return behind;
	return -1;
}

export function stoneAt(unit, socket) {
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket]) return null;
	const worn = wornSocket(unit, socket);
	const stone = worn < 0 ? unit.rail[socket] : Stone.wearing(unit.rail[socket], unit.rail[worn]);
	return Stone.fingerprinted(unit.rail, socket, stone);
}

// Whether a replay may touch this socket: a gem stands there. Opals play again like anything
// else (October 29, 2026); a replay only reaches gems earlier on the rail than the gem
// replaying, and an Echo never copies an Echo, so no two replays can point at each other.
export function repeatable(unit, socket) {
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket]) return false;
	// Opals apart (a rule tried here, not the game's): no opal reaches another.
	if (unit.opals_apart && Stone.isOpal(unit.rail[socket])) return wornSocket(unit, socket) >= 0;
	return true;
}

// A gem whose skill lays Void copies: an Echo, or a Doublet wearing one.
export function isEcho(stone) {
	return (Stone.skillOf(stone || {}).effects || []).some((e) => e && e.kind === 'void_copy');
}

// Opals apart, the rule the balance page can try (`spec.opalsApart`): no opal reaches another.
// A Seam, Echo or Matrix never touches a Doublet, whatever it wears (see `repeatable`); a
// Prelude's extra goes pass over an opal to the next gem that is not one; a Fire Opal's carats
// go to no opal. Pinfire's Resonance is every opal's fuel and stays shared. The game itself
// lets all of these through today.

function resetRail(unit) {
	unit.resonance = I(unit.initial_resonance);
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
	unit.rail_plays = 0;
	unit.socket_plays = {};
	unit.force_after = {};
	unit.fired_colors = [];
	unit.gem_results = {};
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

// Play the queue out. Returns the events, for the parity check and the curious. A rail that
// is still queueing gems after `state.eventCap` events (5000 unless set) is a runaway, and may
// never end on its own (a Gemini beside a Doublet wearing it fire each other for ever while the
// hand holds a pair): what is left is dropped and the ledger counts it.
export function runQueue(state, rng, keepEvents = false) {
	const events = keepEvents ? [] : null;
	const cap = state.eventCap || 5000;
	let guard = 0;
	while (state.queue.length && guard++ < cap) {
		const event = perform(state, state.queue.shift(), rng);
		if (events && event) events.push(event);
	}
	if (guard > (I(state.ledger.maxEvents))) state.ledger.maxEvents = guard;
	if (state.queue.length) { state.ledger.runaway = (I(state.ledger.runaway)) + 1; state.queue = []; }
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
			if (spent(unit)) return spendRail(state, unit);
			// A rule the balance page can try (`spec.gemPlays`): no gem plays more than that many
			// times in a turn, its own fire, replays and repeats together. Not the game's.
			if (unit.gem_plays_cap && unit.rail[I(s.socket)]) {
				const id = String(unit.rail[I(s.socket)].id);
				const played = unit.socket_plays || (unit.socket_plays = {});
				if (I(played[id]) >= unit.gem_plays_cap) return null;
				played[id] = I(played[id]) + 1;
			}
			return resolveGem(state, unit, I(s.socket), { retrigger: Boolean(s.retrigger), scale: s.scale ?? 100, replay: Boolean(s.replay), force: Boolean(s.force), as_skill: String(s.as_skill || '') }, rng);
		case 'birthstone':
			if (spent(unit)) return spendRail(state, unit);
			return resolveBirthstone(state, unit, { replay: Boolean(s.replay), share: s.share ?? 100 }, rng);
		case 'rail_end': {
			// Second Wind: the rerolls not spent, each worth the Resonance the rail just built.
			const resonance = I(unit.resonance);
			unit.rail_plays = 0;
			// Everything this rail rang goes on the fight's tally, which a Crescendo reads.
			unit.fight_resonance = satAdd(I(unit.fight_resonance), resonance);
			const unused = I(unit.rerolls);
			let healed = 0;
			if (unit.passive.kind === 'heal_resonance_per_unused_reroll' && unused > 0 && resonance > 0) healed = heal(state, unit, satMul(resonance, unused));
			state.ledger.resonance += resonance;
			return { kind: 'rail_end', resonance, healed };
		}
	}
	return null;
}

// Counts one more play of this rail, and says whether it is past RAIL_CAP.
function spent(unit) {
	unit.rail_plays = I(unit.rail_plays) + 1;
	return unit.rail_plays > RAIL_CAP;
}

// The rail has played all it may this turn: every gem and Birthstone still queued for it is
// dropped; its close stays. The ledger counts it as a runaway.
function spendRail(state, unit) {
	let dropped = 1;
	state.queue = state.queue.filter((q) => {
		const drop = q.unit === unit.id && (q.kind === 'gem' || q.kind === 'birthstone');
		if (drop) dropped += 1;
		return !drop;
	});
	state.ledger.runaway = I(state.ledger.runaway) + 1;
	unit.rail_plays = 0;
	return { kind: 'rail_spent', unit: unit.id, plays: RAIL_CAP, dropped };
}

// How many times a Certainty earlier on the rail has this socket fire this turn, whatever the dice say.
export function certainTimes(unit, socket, retrigger) {
	const certainty = unit.force_after || {};
	if (retrigger || !('from' in certainty) || socket <= (I(certainty.from))) return 0;
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket] || Stone.isOpal(unit.rail[socket])) return 0;
	return Math.max(0, I(certainty.times));
}

export function resolveGem(state, unit, socket, opts, rng) {
	const dry = Boolean(opts.dry);
	if (socket < 0 || socket >= unit.rail.length || !unit.rail[socket]) return null;
	// A Black Opal fires each skill it absorbed as a stone wearing that skill.
	const stone = opts.as_skill ? Stone.wearing(unit.rail[socket], { skill: opts.as_skill }) : stoneAt(unit, socket);
	const certain = certainTimes(unit, socket, Boolean(opts.retrigger));
	if (certain > 0 && !opts.force) opts = { ...opts, force: true };
	if (unit.buried.includes(socket) || unit.clouded.includes(socket)) {
		// What the gem before handed this one is spent here, as on any gem that stays dark.
		unit.amplify = 1;
		unit.cut_step_bonus = 0;
		unit.nullify_next = false;
		unit.repeat_next = 0;
		unit.previous_fired = false;
		return { kind: 'gem_fizzle', socket, skill: stone.skill, blocked: true, resonance: unit.resonance };
	}
	const context = railContext(state, unit, socket, opts);
	const ev = Stone.evaluate(stone, unit.hand, context);
	for (const effect of ev.effects) {
		if ((I(effect.cost)) > Rules.pyrite(unit)) { ev.active = false; ev.reason = 'Not enough Pyrite.'; }
		// A gem that costs blood never takes the last of it: it stays dark instead.
		if ((I(effect.hp_cost)) > 0 && ev.active && (I(effect.hp_cost)) >= (I(unit.hp))) { ev.active = false; ev.reason = 'Not enough health.'; }
		// An Invert with nothing beside it to turn around stays dark, however it was woken.
		if (effect.kind === 'invert_previous' && ev.active && isEmpty(leftResults(unit, socket))) { ev.active = false; ev.reason = 'The gem before it did nothing to turn around.'; }
	}
	const nullified = Boolean(unit.nullify_next);
	// A Prelude hands the next gem to resolve its extra goes, and is spent doing it (an opal,
	// with opals apart, lets them pass to the gem after it).
	const passOver = Boolean(unit.opals_apart) && Stone.isOpal(unit.rail[socket]);
	const promised = passOver ? 0 : I(unit.repeat_next);
	unit.amplify = 1;
	unit.cut_step_bonus = 0;
	unit.nullify_next = false;
	if (!passOver) unit.repeat_next = 0;
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
		return { kind: 'gem_fizzle', socket, skill: stone.skill, reason: ev.reason || '', resonance: unit.resonance, healed, cut_step: I(ev.cut_step) };
	}
	const scale = Number(opts.scale ?? 100);
	// Blood a gem asks for itself (Bloodletting) is paid with whatever an inclusion asks.
	let hpCost = I(ev.hp_cost);
	for (const effect of ev.effects) hpCost += Math.max(0, I(effect.hp_cost));
	if (hpCost > 0) {
		const before = I(unit.hp);
		unit.hp = Math.max(1, before - hpCost);
		state.ledger.hpLost += before - unit.hp;
	}
	let harmony = false;
	if (unit.previous_fired) for (const color of unit.previous_colors) if (ev.colors.includes(color)) harmony = true;
	// A lit socket, one that shows the gem's color, adds a point of Resonance of its own.
	const lit = Stone.shownBy(ev.colors, String(unit.sockets[socket] ?? C.SOCKET_RAINBOW));
	const gain = satMul(I(ev.resonance_gain) + (harmony ? 1 : 0) + (lit ? 1 : 0), Math.max(1, I(unit.resonance_mult)));
	unit.resonance = satAdd(I(unit.resonance), gain);
	const results = [];
	const previousSocket = unit.previous_socket ?? -1;
	const reactions = {};
	unit.firing_colors = ev.colors.slice();
	unit.fired_count = (I(unit.fired_count)) + 1;
	// What this go does, kept for an Invert in the socket after it (see noteResult).
	const outerResults = unit.firing_results;
	unit.firing_results = {};
	// What a Chainmail or a Contagion earlier this turn hands over for this gem: taken now.
	const answers = (unit.after_fire || []).map((x) => ({ ...x }));
	const crownsBefore = allOrNothing(unit) ? crownIds(unit.hand) : null;
	for (const effect of ev.effects) {
		const applied = { ...effect };
		if (scale !== 100 && effect.scaled) applied.amount = satFloor((I(effect.amount)) * scale / 100);
		if (effect.once) {
			if (unit.once[String(stone.id)]) {
				// Lifeline's second try: the party is healed half of it instead.
				applied.kind = 'heal';
				applied.target = 'allies';
				applied.amount = Math.trunc((I(applied.amount)) / 2);
			} else unit.once[String(stone.id)] = true;
		}
		const kind = applied.kind;
		let procs = applied.procs ?? 1;
		if (!dry && (I(applied.proc_chance)) > 0 && rng.chance(applied.proc_chance)) procs += 1;
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
	if (crownsBefore) crownsChanged(unit, crownsBefore);
	results.push(...answerFire(state, unit, answers, rng));
	// Only its most recent go is kept: a replay of it overwrites what the first go did.
	(unit.gem_results || (unit.gem_results = {}))[String(stone.id || '')] = unit.firing_results;
	if (outerResults) unit.firing_results = outerResults; else delete unit.firing_results;
	delete unit.firing_colors;
	// A gem that grows over the run (Hone, Hardening) counts every fire, replays included.
	if (!dry) { const counts = unit.run_counts || (unit.run_counts = {}); counts[String(stone.id || '')] = (I(counts[String(stone.id || '')])) + 1; }
	(unit.fired_colors || (unit.fired_colors = [])).push(ev.colors.slice());
	if ((I(ev.next_cut_step)) > 0) unit.cut_step_bonus = (I(unit.cut_step_bonus)) + (I(ev.next_cut_step));
	unit.previous_fired = true;
	unit.previous_amount = Stone.totalAmount(ev);
	unit.previous_colors = ev.colors;
	unit.previous_socket = socket;
	if (!unit.fired_sockets.includes(socket)) unit.fired_sockets.push(socket);
	// A Tailings collects on every fizzle it read, and none of them pays it again this turn.
	if (String((Stone.skillOf(stone).trigger || {}).kind || '') === 'fizzles') unit.tailings_paid[String(stone.id)] = unit.fizzled_sockets.length;
	if (!dry && !retrigger && (I(ev.fires)) > 1) for (let extra = 0; extra < (I(ev.fires)) - 1; extra++) state.queue.unshift({ kind: 'gem', unit: unit.id, socket, retrigger: true });
	if (!dry && !retrigger && promised > 0) for (let more = 0; more < promised; more++) state.queue.unshift({ kind: 'gem', unit: unit.id, socket, retrigger: true });
	if (!dry && certain > 1) for (let more = 0; more < certain - 1; more++) state.queue.unshift({ kind: 'gem', unit: unit.id, socket, retrigger: true, force: true });
	settleMarks(state);
	state.ledger.fires += 1;
	return { kind: 'gem_fire', socket, skill: stone.skill, resonance: unit.resonance, gain, harmony, lit, retrigger, cut_step: I(ev.cut_step), carat: I(ev.carat),
		magnitude: ev.magnitude, fires: I(ev.fires), promised: retrigger ? 0 : promised, effects: results };
}

// --- the Birthstone ------------------------------------------------------------------------

export function resolveBirthstone(state, unit, opts, rng) {
	const def = unit.birthstone;
	if (isEmpty(def)) return null;
	const dry = Boolean(opts.dry);
	const replay = Boolean(opts.replay);
	const promised = I(unit.repeat_next);
	unit.repeat_next = 0;
	const a = whatifPhantomCrowns(unit, def, readHand(unit));
	// A Birthright fires it mid-rail at a share of the Resonance so far.
	let resonance = satMulDiv(I(unit.resonance), Math.max(0, opts.share ?? 100), 100);
	// On Fire: last turn's High Roller doubled the whole total it reads this turn.
	if (unit.resonance_doubled) resonance = satMul(resonance, 2);
	// The Changing Face (Motley): a face different from last turn's pays double, and every turn
	// the faces keep changing pays one more. The same face twice, or no face, starts it over.
	const face = def.changing_face ? faceOf(a) : '';
	let change = 0;
	if (face && unit.last_face && face !== unit.last_face) change = I(unit.change) + 1;
	if (def.changing_face && !dry) { unit.face_shown = face; unit.change_now = change; }
	const defs = def.tiers || [];
	const evaluated = [];
	let exclusiveHit = -1;
	for (let index = 0; index < defs.length; index++) {
		const tier = defs[index];
		const trig = Patterns.evaluate(tier.trigger || { kind: 'always' }, 0, a, { resonance });
		if (replay && trig.active && (tier.effects || []).some((e) => e && e.kind === 'replay_rail')) { trig.active = false; trig.reason = 'Once a turn.'; }
		// WHAT-IF (balance sweeps only; no tier in the shipped pack has the key): a tier marked
		// `whatif_once_a_turn` pays on the first firing of the turn that reaches it, never again.
		if (trig.active && tier.whatif_once_a_turn) {
			const paid = unit.whatif_tier_paid || (unit.whatif_tier_paid = {});
			if (paid[index] === I(state.turn)) { trig.active = false; trig.reason = 'Once a turn.'; } else if (!dry) paid[index] = I(state.turn);
		}
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
			const tc = { a, trig, unit, resonance, previous_amount: I(unit.previous_amount), depth: I(state.depth), turn: I(state.turn), party: I(state.party) };
			const reactions = {};
			for (const effectDef of tier.effects || []) {
				if (!effectDef || typeof effectDef !== 'object') continue;
				const applied = Rules.resolveEffect(effectDef, tc, 1.0);
				const kind = applied.kind;
				// The Changing Face multiplies what the faces land: the blow, the guard.
				if (change > 0 && TALLY_KINDS.includes(kind) && kind !== 'gold') applied.amount = satMul(I(applied.amount), 1 + change);
				if (HAND_KINDS.includes(kind)) entry.effects.push(mutateHand(unit, applied));
				// A Motif plays the gem before the Birthstone again: the last one that fired.
				else if (SELF_KINDS.includes(kind)) entry.effects.push(selfEffect(state, unit, applied, -1, unit.previous_socket ?? -1, dry, rng));
				else if (BIRTHSTONE_KINDS.includes(kind)) entry.effects.push(birthstoneEffect(state, unit, applied, dry, replay));
				else entry.effects.push(...apply(state, unit, applied, rng, '', reactions));
			}
		}
		tiers.push(entry);
	}
	if (!dry && !replay && promised > 0) for (let more = 0; more < promised; more++) state.queue.unshift({ kind: 'birthstone', unit: unit.id, replay: true });
	// The Birthstone is a gem that fired, as far as a Chainmail is concerned.
	if (fired) answerFire(state, unit, unit.after_fire || [], rng);
	settleMarks(state);
	if (fired) state.ledger.birthstone += 1;
	return { kind: 'birthstone', fired, resonance, replay, tiers, face, change };
}

// WHAT-IF (balance sweeps only; the shipped pack never sets it): a Birthstone with
// `whatif_phantom_crown_pct` reads each phantom die's crown at that percent of a crown, for its
// tier ladder and its `crowns` term alike. Without the key the hand is read as it is.
function whatifPhantomCrowns(unit, def, a) {
	if (def.whatif_phantom_crown_pct === undefined) return a;
	const ghosts = unit.hand.filter((r) => r.phantom && isCrown(r)).length;
	const crowns = Math.max(0, I(a.crowns) - ghosts) + Math.floor((ghosts * Number(def.whatif_phantom_crown_pct)) / 100);
	return { ...a, crowns, crown_ids: (a.crown_ids || []).slice(0, crowns) };
}

// What the tiers land that the Changing Face multiplies (sim/battle.gd TALLY_KINDS).
const TALLY_KINDS = ['damage', 'block', 'heal', 'poison', 'gold', 'spikes', 'regeneration', 'retain'];

// The face a hand wears for Motley: odd when every die is odd, even when every die is even.
function faceOf(a) {
	const count = I(a.dice_count);
	if (count <= 0) return '';
	if (I(a.odd) === count) return 'odd';
	if (I(a.even) === count) return 'even';
	return '';
}

// Marks spent by the gem, Birthstone or move that just finished come off now, so every blow of
// it took them and the next thing to land starts clean.
function settleMarks(state) {
	for (const unit of state.players.concat(state.enemies)) {
		if (unit.mark_spent) { delete unit.mark_spent; delete unit.statuses.marked; }
	}
}

// What a Chainmail or a Contagion earlier this turn gives for one more gem fired.
function answerFire(state, unit, answers, rng) {
	const out = [];
	for (const answer of answers) out.push(...apply(state, unit, { kind: answer.kind, amount: I(answer.amount), target: answer.target, repeat: 1 }, rng));
	return out;
}

function birthstoneEffect(state, unit, effect, dry, replay) {
	const kind = effect.kind;
	const amount = I(effect.amount);
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
					if ((I(foe.statuses.poison)) <= 0 || (I(foe.hp)) <= 0) break;
					poisonTick(state, foe);
				}
			}
			break;
		}
		case 'stone_drop':
			if (!dry) unit.stone_drops = (I(unit.stone_drops)) + amount;
			break;
		case 'pot': {
			// What is on the table. Staking moves Pyrite out of the bank in the same breath.
			const mode = String(effect.pot_mode || 'ante');
			const before = I(unit.pot);
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
	unit.pot = (I(unit.pot)) + moved;
	unit.pyrite_delta = (I(unit.pyrite_delta)) - moved;
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
	const amount = I(effect.amount);
	const kind = effect.kind;
	const changed = [];
	const real = hand.filter((r) => !['wild', 'blank'].includes(r.kind || 'plain') && !r.phantom);
	let high = 0;
	for (const roll of real) high = Math.max(high, I(roll.value));
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
					if ('shows' in effect) { ghost.value = I(effect.shows); ghost.kind = 'plain'; delete ghost.shown; delete ghost.counted; delete ghost.base; }
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
	unit.void_copies = (I(unit.void_copies)) + 1;
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
	unit.sockets.splice(at, 0, C.SOCKET_NONE);
	for (const entry of state.queue) if (entry.unit === unit.id && entry.socket !== undefined && entry.socket >= at) entry.socket += 1;
	for (const field of ['fired_sockets', 'fizzled_sockets', 'buried', 'clouded']) unit[field] = (unit[field] || []).map((p) => (p >= at ? p + 1 : p));
	if ((unit.previous_socket ?? -1) >= at) unit.previous_socket += 1;
	if (unit.force_after && 'from' in unit.force_after && unit.force_after.from >= at) unit.force_after.from += 1;
	// The rail it walked in with moves along too, with nothing in the new place.
	if (unit.initial_rail && at <= unit.initial_rail.length) unit.initial_rail.splice(at, 0, null);
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
	const amount = I(effect.amount);
	const out = { kind, amount };
	switch (kind) {
		case 'gem_rank': {
			const scope = String(effect.scope || 'adjacent');
			const rank = String(effect.rank || 'carat');
			const changed = [];
			for (let at = 0; at < unit.rail.length; at++) {
				if (!unit.rail[at] || (scope === 'adjacent' && Math.abs(at - socket) !== 1) || (scope === 'others' && at === socket) || (scope === 'self' && at !== socket)) continue;
				if (unit.opals_apart && socket >= 0 && Stone.isOpal(unit.rail[socket]) && Stone.isOpal(unit.rail[at])) continue;
				const id = String(unit.rail[at].id);
				const buff = unit.gem_buffs[id] || (unit.gem_buffs[id] = {});
				buff[rank] = satAdd(I(buff[rank]), amount);
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
					die.faces.forEach((face, index) => { if (effect.all_faces || index === (roll.face ?? -1)) face.value = (I(face.value)) + amount; });
					roll.value = roll.value + amount;
					if ('base' in roll) roll.base = roll.base + amount;
					if ('top' in die) {
						let physical = 0;
						for (const face of die.faces) if ((face.kind || 'plain') !== 'blank') physical = Math.max(physical, I(face.value));
						die.top = Math.max(I(die.top), physical);
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
			const cost = I(effect.cost);
			if (Rules.pyrite(unit) >= cost) {
				unit.pyrite_delta = (I(unit.pyrite_delta)) - cost;
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
			// A Seam: every gem of one color earlier on the rail that has already fired this turn plays again.
			const want = String(effect.color || '');
			const encore = [];
			const touched = [];
			for (const at of unit.fired_sockets.slice().sort((x, y) => x - y)) {
				if (at >= socket || !repeatable(unit, at)) continue;
				if (want !== 'ANY' && !Stone.colors(stoneAt(unit, at), String(unit.sockets[at])).includes(want)) continue;
				touched.push(at);
				for (let time = 0; time < Math.max(1, amount); time++) encore.push({ kind: 'gem', unit: unit.id, socket: at, retrigger: true });
			}
			out.sockets = touched;
			if (dry || !encore.length) out.nothing = true; else state.queue = encore.concat(state.queue);
			break;
		}
		case 'replay_fizzled': {
			// A Matrix: gems earlier on the rail that stayed dark this turn fire anyway, earliest first.
			const woken = [];
			const darkSockets = [];
			for (const at of unit.fizzled_sockets.slice().sort((x, y) => x - y)) {
				if (darkSockets.length >= Math.max(1, amount)) break;
				if (at >= socket || !repeatable(unit, at)) continue;
				darkSockets.push(at);
				woken.push({ kind: 'gem', unit: unit.id, socket: at, retrigger: true, force: true });
			}
			out.sockets = darkSockets;
			if (dry || !woken.length) out.nothing = true; else state.queue = woken.concat(state.queue);
			break;
		}
		case 'rank_buff': {
			const rank = String(effect.rank || 'carat');
			if (!dry) unit.rank_buff = { ...unit.rank_buff, [rank]: satAdd(I(unit.rank_buff[rank]), amount) };
			break;
		}
		case 'repeat_next':
			if (!dry) unit.repeat_next = (I(unit.repeat_next)) + Math.max(0, amount);
			break;
		case 'void_copy': {
			// An Echo: a Void copy of the last gem that fired, never another Echo, joins the rail behind this one.
			const source = previousSocket;
			const copyable = socket >= 0 && source >= 0 && source < unit.rail.length && unit.rail[source] && repeatable(unit, source) && !isEcho(stoneAt(unit, source));
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
			// A Gemini: the gems either side of it fire, once for every pair; never an opal, not even
			// a Doublet wearing a gem (beside a Gemini it would wear it and wake it back for ever).
			const twins = [];
			const woken = [];
			for (const at of [socket - 1, socket + 1]) {
				if (at === socket || !repeatable(unit, at) || Stone.isOpal(unit.rail[at])) continue;
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
			const from = 'from' in standing ? Math.min(socket, I(standing.from)) : socket;
			unit.force_after = { from, times: Math.max(Math.max(1, amount), I(standing.times)) };
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
			// A Refract (`of: largest`) throws a copy of the owner's largest die, faces and all.
			const source = effect.of === 'largest' ? largestDie(unit) : null;
			if (dry || (effect.of === 'largest' && !source)) { out.nothing = true; break; }
			for (let n = 0; n < Math.max(1, amount); n++) {
				let made;
				if (!source) made = Dice.make(String(effect.shape || 'D6'), `${unit.id}_roll${I(state.turn)}_${unit.hand.length}`);
				else { made = cloneDie(source); made.id = `${source.id}_ph${I(state.turn)}_${unit.hand.length}`; delete made.bonus; }
				const ghost = Dice.rollOne(made, rng);
				ghost.phantom = true;
				ghost.source_id = source ? source.id : '';
				delete ghost.bonus;
				unit.hand.push(ghost);
				if (n === 0) out.value = ghost.value;
			}
			touchHand(unit);
			break;
		}
		case 'bonus_die': {
			// A Hot Streak: a die of its own joins the next throw, for that turn only.
			const owed = unit.bonus_dice_next || (unit.bonus_dice_next = []);
			for (let n = 0; n < Math.max(1, amount); n++) owed.push({ shape: String(effect.shape || 'D6'), pattern: String(effect.pattern || '') });
			break;
		}
		case 'double_resonance_next': unit.double_resonance_next = true; break;
		case 'lose_pyrite': {
			// A Bust: the bank pays, as much of it as there is.
			const lost = Math.min(Math.max(0, amount), Rules.pyrite(unit));
			if (lost > 0) unit.pyrite_delta = (I(unit.pyrite_delta)) - lost;
			out.lost = lost;
			break;
		}
		case 'reflect_blows': {
			// A Mirror: the next blows a creature lands, until its owner's next turn, are split.
			unit.statuses.reflect = Math.min(99, (I(unit.statuses.reflect)) + Math.max(1, amount));
			unit.statuses.reflect_pct = Math.max(0, Math.min(100, Math.max(I(unit.statuses.reflect_pct), Number(effect.pct ?? 50))));
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
			for (let time = 0; time < Math.max(1, I(effect.best_of)); time++) {
				const again = Dice.rollOne(die, rng, I(was.rerolls));
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
				Dice.etch(unit.dice.find((d) => d.id === pick.die_id), I(pick.face), 'golden');
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
			let drops = (I(smallest.drops)) + 1;
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
			// One gift for every color that has fired this turn (every gem, Flawless).
			const tally = {};
			for (const colors of unit.fired_colors || []) for (const color of colors) {
				if (!SPECTRUM_GIFTS[color]) continue;
				tally[color] = effect.every_gem ? (I(tally[color])) + 1 : 1;
			}
			const given = [];
			for (const color of Object.keys(SPECTRUM_GIFTS)) {
				if (!(color in tally)) continue;
				const [gift, base, target] = SPECTRUM_GIFTS[color];
				const worth = satScale(base, tally[color], amount, 100);
				if (worth <= 0) continue;
				if (gift === 'resonance') unit.resonance = satAdd(I(unit.resonance), worth);
				else given.push(...apply(state, unit, { kind: gift, amount: worth, target, repeat: 1 }, rng));
			}
			out.hits = given;
			break;
		}
		case 'invert_previous': {
			// An Invert: a share of what the gem before it did on its last go, each part turned around.
			const did = leftResults(unit, socket);
			const given = [];
			for (const [gift, reads, target] of INVERTED) {
				let read = 0;
				for (const key of reads) read = satAdd(read, I(did[key]));
				const worth = satMulDiv(read, Math.max(0, amount), 100);
				if (worth <= 0) continue;
				given.push(...apply(state, unit, { kind: gift, amount: worth, target, repeat: 1 }, rng));
			}
			out.hits = given;
			if (!given.length) out.nothing = true;
			break;
		}
		case 'stone_chance': {
			// A Placer: every creature fallen this turn may leave a raw stone.
			const kills = I(state.turn_kills);
			let found = 0;
			if (!dry) {
				for (let kill = 0; kill < kills; kill++) {
					found += Math.trunc(Math.max(0, amount) / 100);
					if (rng.chance(Math.max(0, amount) % 100)) found += 1;
				}
				const field = effect.elite ? 'placer_elite_drops' : 'placer_drops';
				unit[field] = (I(unit[field])) + found;
			}
			out.stones = found;
			break;
		}
		case 'double_resonance': unit.resonance_mult = Math.max(2, I(unit.resonance_mult)); break;
		case 'keep_phantoms': unit.keep_phantoms = true; break;
		case 'amplify_next': unit.amplify = Number(unit.amplify) * (1 + amount / 100); break;
		case 'cut_step_next': unit.cut_step_bonus = (I(unit.cut_step_bonus)) + amount; break;
		case 'grant_reroll': unit.granted_rerolls = (I(unit.granted_rerolls)) + amount; break;
		case 'quality_bonus': unit.quality_bonus = (I(unit.quality_bonus)) + amount; break;
		case 'sparkle': unit.sparkle = Math.max(0, Math.min(SPARKLE_MAX_STACKS, (I(unit.sparkle)) + Math.max(0, amount))); break;
		case 'resonance': unit.resonance = satAdd(I(unit.resonance), amount); break;
		case 'coin_flip': {
			// One toss, however heavy the stone; weight raises the stake instead.
			const won = dry ? true : rng.chance(amount);
			const procs = Math.max(1, I(effect.procs));
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

// What the gem in the socket before this one did on its last go this turn, as an Invert reads
// it: only what came to anything (DeepBattle._left_results).
function leftResults(unit, socket) {
	if (socket <= 0 || socket - 1 >= unit.rail.length || !unit.rail[socket - 1]) return {};
	const did = (unit.gem_results || {})[String(unit.rail[socket - 1].id || '')] || {};
	const out = {};
	for (const [key, value] of Object.entries(did)) if (I(value) > 0) out[key] = I(value);
	return out;
}

// What the gem firing now has really done, for an Invert after it: damage that landed and the
// debuffs that stuck on the other side; the Block, healing and buffs it gave its own side.
function noteResult(source, target, key, amount) {
	if (amount <= 0 || !source.firing_results) return;
	if (INVERTED_HOSTILE.includes(key) === (source.side === target.side)) return;
	source.firing_results[key] = satAdd(I(source.firing_results[key]), amount);
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
			if (!chosen || (I(chosen.hp)) <= 0 || chosen.downed || (isPlayer && chosen.burrowed)) chosen = foes.length ? foes[0] : null;
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
			if (!chosen || (I(chosen.hp)) <= 0 || chosen.burrowed) chosen = foes.length ? foes[0] : null;
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
			if ((I(state.enemies[at].hp)) > 0) { out.push(state.enemies[at]); break; }
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
		effect = { ...effect, amount: Math.ceil((I(effect.amount)) / party) };
	}
	if (kind === 'revive' && !targets(state, source, 'downed_ally').length) {
		// Nobody to raise: the party is healed half of it instead.
		return apply(state, source, { ...effect, kind: 'heal', target: 'allies', amount: Math.trunc((I(effect.amount)) / 2) }, rng, intentTarget);
	}
	for (let count = 0; count < repeat; count++) {
		let picked;
		if (targetKind === 'spread') { const foes = targets(state, source, 'enemies'); picked = foes.length ? [foes[count % foes.length]] : []; }
		else picked = targets(state, source, targetKind, intentTarget);
		for (const target of picked) {
			let hit = applyOne(state, source, target, kind, I(effect.amount), effect, rng, reactions);
			results.push(hit);
			while (effect.chain_on_kill && hit.killed && (I(source.hp)) > 0) {
				const survivors = targetable(state.enemies);
				if (!survivors.length) break;
				hit = applyOne(state, source, survivors[0], kind, I(effect.amount), effect, rng, reactions);
				results.push(hit);
			}
		}
	}
	return results;
}

function wardBlocks(target) {
	const ward = I(target.statuses.ward);
	if (ward <= 0) return false;
	target.statuses.ward = ward - 1;
	return true;
}

function resetDefenses(unit) {
	// Spikes are no longer cleared here: they last the fight.
	unit.block = Math.min(I(unit.block), Math.max(0, I(unit.statuses.retain)));
	delete unit.statuses.retain;
}

export function applyOne(state, source, target, kind, amount, effect, rng, reactions = {}) {
	if (effect.from_result) amount = satMulDiv(I(reactions[`result_${effect.from_result}`]), amount, 100);
	// A share of what its owner carries as it lands: a Caltrop's Spikes, a Hemlock's Poison.
	if (effect.of_status) amount = satMulDiv(I((source.statuses || {})[effect.of_status]), amount, 100);
	const out = { kind, target: target.id, amount };
	if (kind === 'stun' && (I(target.statuses.combo_breaker)) > 0) { out.resisted = true; return out; }
	// Ward turns away what others do to it, never what it does to itself.
	if (Rules.DEBUFFS.includes(kind) && amount > 0 && source.id !== target.id && wardBlocks(target)) { out.warded = true; return out; }
	switch (kind) {
		case 'damage': case 'damage_curse': case 'detonate': case 'wager': {
			const adjacent = adjacentEnemies(state, target);
			let spent = 0, consumed = 0;
			if (kind === 'damage_curse') amount = satMulDiv(amount, I(target.statuses.curse), 100);
			else if (kind === 'detonate') { consumed = I(target.statuses.poison); target.statuses.poison = 0; amount = satMul(amount, consumed); }
			else if (kind === 'wager') {
				spent = I(effect.cost);
				if (Rules.pyrite(source) < spent) { out.unaffordable = true; return out; }
				source.pyrite_delta = (I(source.pyrite_delta)) - spent;
			}
			if (effect.missing_hp_bonus) amount = satMulDiv(amount, 2 * I(source.max_hp) - I(source.hp), Math.max(1, I(source.max_hp)));
			// A player's Strength (Temper) puts a point more on every blow.
			if (kind === 'damage' && amount > 0 && source.side === 'player') amount = satAdd(amount, Math.max(0, I((source.statuses || {}).strength)));
			out.kind = 'damage';
			out.amount = amount;
			Object.assign(out, damage(state, source, target, amount, rng, reactions, false, Boolean(effect.piercing)));
			reactions.result_damage = satAdd(I(reactions.result_damage), I(out.hp_loss));
			if (spent > 0 && out.killed) source.pyrite_delta += spent * Number(effect.refund_mult ?? 2);
			const splash = I(effect.splash);
			if (splash > 0) for (const neighbour of adjacent) damage(state, source, neighbour, satMulDiv(amount, splash, 100), rng, reactions);
			if (consumed > 0 && (I(effect.poison_splash)) > 0) for (const neighbour of adjacent) applyOne(state, source, neighbour, 'poison', satMulDiv(consumed, I(effect.poison_splash), 100), {}, rng, reactions);
			break;
		}
		case 'block':
			if ((I(target.statuses.scorched)) > 0 && amount > 0) amount = Math.ceil(amount / 2);
			target.block = satAdd(I(target.block), amount);
			if (target.side === 'player') state.ledger.blockGained += amount;
			noteResult(source, target, 'block', amount);
			reactions.result_block = satAdd(I(reactions.result_block), amount);
			// A Rebound: every time its owner gains block this turn, the target takes a hit.
			if (amount > 0 && target.side === 'player' && (target.on_block || []).length && (I(target.hp)) > 0) {
				for (const answer of target.on_block) apply(state, target, { kind: 'damage', amount: I(answer.amount), target: answer.target, repeat: 1 }, rng);
			}
			break;
		case 'heal': {
			const healed = heal(state, target, amount);
			out.healed = healed;
			noteResult(source, target, 'heal', healed);
			if (source.side === 'player') source.healed = satAdd(I(source.healed), healed);
			// What would heal past full: block for a Wellspring, a blow for a Flawless Thirst.
			const spill = healReceived(target, amount) - healed;
			if (effect.overflow && spill > 0 && (I(target.hp)) > 0) {
				if (effect.overflow === 'block') applyOne(state, source, target, 'block', spill, {}, rng, reactions);
				else apply(state, source, { kind: 'damage', amount: spill, target: 'enemy', repeat: 1 }, rng, '', reactions);
			}
			break;
		}
		case 'gold':
			if (source.side === 'player') {
				// Pyrite a gem sends to the party lands in each ally's own purse.
				const purse = target.side === 'player' ? target : source;
				purse.gold = satAdd(I(purse.gold), amount);
				reactions.result_gold = (I(reactions.result_gold)) + amount;
			}
			else if (target.side === 'player') target.gold = satAdd(I(target.gold), amount);
			break;
		case 'max_hp':
			target.max_hp = satAdd(I(target.max_hp), Math.max(0, amount));
			target.hp = satAdd(I(target.hp), Math.max(0, amount));
			if (target.side === 'player') state.ledger.healed += Math.max(0, amount);
			break;
		case 'max_hp_loss': {
			const before = I(target.hp);
			target.max_hp = Math.max(1, (I(target.max_hp)) - Math.max(0, amount));
			target.hp = Math.min(I(target.hp), target.max_hp);
			if (target.side === 'enemy') state.ledger.dealt += before - target.hp;
			break;
		}
		case 'ward': target.statuses.ward = Math.min(99, (I(target.statuses.ward)) + Math.max(0, amount)); break;
		case 'retain': {
			const kept = I(target.statuses.retain);
			target.statuses.retain = Math.min(20, kept + Math.max(0, amount));
			noteResult(source, target, 'retain', target.statuses.retain - kept);
			break;
		}
		case 'clouded':
			if (target.side === 'enemy') {
				const moves = target.dice.length;
				if (moves > 0 && amount > 0) {
					if ((I(target.statuses.clouded)) <= 0) target.clouded_move = rng.randiRange(0, moves - 1);
					target.statuses.clouded = (I(target.statuses.clouded)) + amount;
				}
			}
			break;
		case 'remove_block': {
			const removed = effect.remove_all ? I(target.block) : Math.min(I(target.block), amount);
			target.block = (I(target.block)) - removed;
			out.removed = removed;
			reactions.result_removed = (I(reactions.result_removed)) + removed;
			break;
		}
		case 'cleanse': {
			let cleared = 0;
			for (const status of ['poison', 'burn', 'stun', 'curse', 'marked', 'dulled', 'clouded', 'festering', 'scorched']) {
				while (cleared < amount && (I(target.statuses[status])) > 0) { target.statuses[status] -= 1; cleared += 1; }
			}
			if (cleared < amount) { const dread = Math.min(amount - cleared, I(target.dread_turns)); target.dread_turns = (I(target.dread_turns)) - dread; cleared += dread; }
			if (cleared < amount) { const bound = Math.min(amount - cleared, I(target.stolen_dice)); target.stolen_dice = (I(target.stolen_dice)) - bound; cleared += bound; }
			out.cleared = cleared;
			break;
		}
		case 'dice_dread':
			if (target.side === 'player') target.statuses.dread = (I(target.statuses.dread)) + Math.max(0, amount);
			else target.dread_turns = (I(target.dread_turns)) + Math.max(0, amount);
			break;
		case 'die_steal': target.stolen_dice = (I(target.stolen_dice)) + amount; break;
		case 'gather_poison': {
			// A Confluence: every other creature's Poison moves onto this one.
			let gathered = 0;
			for (const other of living(state.enemies)) {
				if (other.id === target.id) continue;
				gathered = satAdd(gathered, I(other.statuses.poison));
				other.statuses.poison = 0;
			}
			target.statuses.poison = satAdd(I(target.statuses.poison), gathered);
			break;
		}
		case 'poison_tick':
			for (let time = 0; time < Math.max(0, amount); time++) {
				if ((I(target.statuses.poison)) <= 0 || (I(target.hp)) <= 0) break;
				poisonTick(state, target);
			}
			break;
		case 'grow_poison': {
			const had = I(target.statuses.poison);
			target.statuses.poison = satAdd(had, satMulDiv(had, Math.max(0, amount), 100));
			noteResult(source, target, 'poison', target.statuses.poison - had);
			break;
		}
		default:
			if (STATUS_KINDS.includes(kind)) {
				// Lodestone stores no more than the Resonance there is to store.
				if (kind === 'charged' && effect.resonance_cap) { amount = Math.min(amount, Math.max(0, I(source.resonance))); out.amount = amount; }
				const had = I(target.statuses[kind]);
				target.statuses[kind] = satAdd(had, Math.max(0, amount));
				if (kind === 'curse') target.statuses.curse = Math.min(Rules.CURSE_MAX_STACKS, target.statuses.curse);
				noteResult(source, target, kind, I(target.statuses[kind]) - had);
				if (kind === 'lifeline' && effect.revive_block) target.statuses.lifeline_block = satAdd(I(target.statuses.lifeline_block), amount);
			}
	}
	return out;
}

// One blow, the way sim/battle.gd _damage lands it, without the creature traits a dummy lacks.
function damage(state, source, target, amount, rng, reactions = {}, reactive = false, piercing = false) {
	let raw = Math.max(0, amount);
	// Enrage hardens a creature's own blows, not what its Spikes or a mirror send back.
	if (source.side === 'enemy' && !reactive) {
		const enrageTurn = Number(C.constant('enrage_turn', 7));
		if (state.turn >= enrageTurn) raw = satAdd(raw, Number(C.constant('enrage_damage', 2)) * (state.turn - enrageTurn + 1));
	}
	const sourceCurse = Math.max(0, Math.min(Rules.CURSE_MAX_STACKS, I((source.statuses || {}).curse)));
	raw = satMulDiv(raw, 100 - Rules.CURSE_PERCENT * sourceCurse, 100);
	const curse = Math.max(0, Math.min(Rules.CURSE_MAX_STACKS, I(target.statuses.curse)));
	const marked = !reactive && amount > 0 ? I(target.statuses.marked) : 0;
	raw = satScale(raw, 100 + Rules.CURSE_PERCENT * curse, 100 + 25 * marked, 10000);
	// Marked is spent by the whole gem (or Birthstone, or move) that lands on it, not by its
	// first blow; the marks come off once it is done (settleMarks).
	if (marked > 0) target.mark_spent = true;
	const out = { raw };
	// A Mirror a delver holds up: the next blow a creature lands is split, its share sent back.
	if (target.side === 'player' && source.side === 'enemy' && !reactive && raw > 0 && (I(target.statuses.reflect)) > 0) {
		const pct = Math.max(0, Math.min(100, I(target.statuses.reflect_pct ?? 50)));
		target.statuses.reflect = (I(target.statuses.reflect)) - 1;
		if (target.statuses.reflect <= 0) { delete target.statuses.reflect; delete target.statuses.reflect_pct; }
		const sent = satMulDiv(raw, pct, 100);
		if (sent > 0) {
			damage(state, target, source, sent, rng, {}, true);
			out.reflected_amount = sent;
			raw -= sent;
			out.raw = raw;
		}
	}
	const absorbed = piercing ? 0 : Math.min(I(target.block), raw);
	target.block = (I(target.block)) - absorbed;
	const through = raw - absorbed;
	const loss = Math.min(I(target.hp), through);
	target.hp = (I(target.hp)) - loss;
	const rescued = lifeline(target);
	Object.assign(out, { absorbed, hp_loss: loss });
	if (!reactive) noteResult(source, target, 'damage', satAdd(absorbed, loss));
	if (target.side === 'player') {
		target.block_lost_accum = (I(target.block_lost_accum)) + absorbed;
		state.ledger.hpLost += state.noDowns ? through : loss;
		if (rescued > 0) state.ledger.healed += rescued;
		if ((I(target.hp)) <= 0) {
			if (state.noDowns) { target.hp = 1; state.ledger.downs += 1; } else { target.downed = true; target.block = 0; out.downed = true; }
		}
	} else {
		state.ledger.dealt += loss;
		source.dealt = satAdd(I(source.dealt), loss);
		if (source.side === 'player' && !reactive) {
			target.hurt_by[source.id] = satAdd(I(target.hurt_by[source.id]), loss);
			if (loss > (I(target.biggest_hit))) target.biggest_hit = loss;
		}
		// Riposte: every hit the Rogue lands raises block worth her Resonance.
		if (source.side === 'player' && (source.passive || {}).kind === 'block_per_hit' && raw > 0) {
			const parry = I(source.resonance);
			if (parry > 0) { source.block = satAdd(I(source.block), parry); state.ledger.blockGained += parry; }
		}
		if ((I(target.hp)) <= 0) { out.killed = true; state.turn_kills = (I(state.turn_kills)) + 1; }
	}
	// An Arsenic: every hit that gets past block leaves Poison behind.
	const venom = I((source.statuses || {}).envenom);
	if (!reactive && venom > 0 && loss > 0 && target.side === 'enemy' && (I(target.hp)) > 0 && source.side === 'player') applyOne(state, source, target, 'poison', venom, {}, rng, reactions);
	const spikes = I(target.statuses.spikes);
	if (!reactive && amount > 0 && spikes > 0 && !reactions[target.id] && (I(source.hp)) > 0) {
		reactions[target.id] = true;
		damage(state, target, source, spikes, rng, {}, true);
	}
	return out;
}

function lifeline(unit) {
	const stacks = I(unit.statuses.lifeline);
	if ((I(unit.hp)) > 0 || stacks <= 0) return 0;
	delete unit.statuses.lifeline;
	unit.hp = Math.min(I(unit.max_hp), stacks);
	unit.downed = false;
	unit.block = (I(unit.block)) + (I(unit.statuses.lifeline_block));
	delete unit.statuses.lifeline_block;
	return I(unit.hp);
}

// How much of a heal reaches its target before full health stops it: Festering halves it, a
// Hazard tier's Festering Air (run_mods.heal_cut) cuts it.
function healReceived(target, amount) {
	if ((I(target.statuses?.festering)) > 0) amount = Math.trunc(Math.max(0, amount) / 2);
	const cut = I(target.run_mods?.heal_cut);
	if (cut > 0) amount = satMulDiv(Math.max(0, amount), 100 - cut, 100);
	return Math.max(0, amount);
}

function heal(state, target, amount) {
	if (target.downed || (I(target.hp)) <= 0) return 0;
	amount = healReceived(target, amount);
	const before = I(target.hp);
	target.hp = Math.min(I(target.max_hp), satAdd(before, Math.max(0, amount)));
	const healed = (I(target.hp)) - before;
	if (target.side === 'player') state.ledger.healed += healed;
	return healed;
}

// What a round of Poison or Burn hurts for (sim/battle.gd tick_amount): the stacks a creature
// put on a player carry the weight its blows carry here; anything else is its stacks.
const tickAmount = (state, unit, stacks, kind) => {
	const pct = I(state.creature_damage_pct) || 100;
	if (unit.side !== 'player' || pct === 100) return stacks;
	const heavy = Math.min(Math.max(0, I((unit.creature_stacks || {})[kind])), Math.max(0, stacks));
	return stacks - heavy + Math.floor(heavy * pct / 100);
};

function poisonTick(state, unit) {
	const poison = I(unit.statuses.poison);
	if (poison <= 0 || (I(unit.hp)) <= 0) return;
	const loss = Math.min(I(unit.hp), tickAmount(state, unit, poison, 'poison'));
	unit.hp -= loss;
	unit.statuses.poison = poison - 1;
	if (unit.side === 'player') state.ledger.hpLost += loss; else state.ledger.dealt += loss;
	if (unit.side === 'enemy' && (I(unit.hp)) <= 0) state.turn_kills = (I(state.turn_kills)) + 1;
	if (unit.side === 'enemy' && loss > 0) {
		// Leech: every Apothecary drinks Resonance from the creature that bleeds.
		for (const drinker of living(state.players)) if ((drinker.passive || {}).kind === 'heal_on_poison_tick' && (I(drinker.resonance)) > 0) heal(state, drinker, I(drinker.resonance));
	}
}

function burnTick(state, unit) {
	const burn = I(unit.statuses.burn);
	if (burn <= 0 || (I(unit.hp)) <= 0) return;
	const hurts = tickAmount(state, unit, burn, 'burn');
	const soaked = Math.min(Math.max(0, I(unit.block)), hurts);
	unit.block = (I(unit.block)) - soaked;
	const loss = Math.min(I(unit.hp), hurts - soaked);
	unit.hp -= loss;
	unit.statuses.burn = burn - 1;
	if (unit.side === 'player') state.ledger.hpLost += loss; else state.ledger.dealt += loss;
}

export function tick(state) {
	settleMarks(state);
	for (const unit of state.players.concat(state.enemies)) {
		if ((I(unit.hp)) <= 0 || unit.downed) continue;
		poisonTick(state, unit);
		burnTick(state, unit);
		const regen = I(unit.statuses.regeneration);
		if (regen > 0) { heal(state, unit, regen); unit.statuses.regeneration = regen - 1; }
		for (const fading of ['curse', 'dulled', 'combo_breaker', 'festering', 'scorched']) if ((I(unit.statuses[fading])) > 0) unit.statuses[fading] -= 1;
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
	// A Hot Streak's bonus die lasts the turn it was thrown for, unless a Contra Luz kept that
	// turn's phantoms; then what last turn's High Roller earned joins the bowl.
	if (!unit.keep_phantoms) unit.dice = unit.dice.filter((d) => !d.bonus);
	unit.keep_phantoms = false;
	(unit.bonus_dice_next || []).forEach((spec, index) => {
		const extra = Dice.make(spec.shape || 'D6', `${unit.id}_bonus${I(state.turn)}_${index}`, spec.pattern ? { pattern: spec.pattern } : {});
		extra.bonus = true;
		unit.dice.push(extra);
	});
	unit.bonus_dice_next = [];
	unit.resonance_doubled = Boolean(unit.double_resonance_next);
	unit.double_resonance_next = false;
	// The Changing Face: the face Motley showed last turn, and how many turns running the faces
	// have changed. A turn that showed no face ends the run.
	unit.last_face = String(unit.face_shown || '');
	unit.change = I(unit.change_now);
	unit.face_shown = '';
	unit.change_now = 0;
	// Mirror's reflection lasts until its owner's next turn, like Block.
	delete unit.statuses.reflect;
	delete unit.statuses.reflect_pct;
	const charged = I(unit.statuses.charged);
	delete unit.statuses.charged;
	unit.initial_resonance = charged;
	unit.resonance = charged;
	// A Sticky face that was showing is not thrown again, nor a die a creature locked.
	const kept = new Map();
	for (const r of unit.hand) if (Dice.carriesOver(r)) kept.set(r.die_id, r);
	unit.hand = unit.dice.map((die, index) => (kept.has(die.id) ? Dice.carried(kept.get(die.id)) : roll(die, index)));
	unit.hand.push(...carried);
	payDues(unit, unit.hand);
	crownsRolled(unit, unit.hand.filter((r) => !r.phantom), true);
	unit.flips = unit.passive.kind === 'free_flip' ? Number(unit.passive.amount ?? 1) : 0;
	const extra = unit.passive.kind === 'extra_reroll' ? Number(unit.passive.amount ?? 1) : 0;
	unit.rerolls_max = Number(C.constant('rerolls', 2)) + extra + (I(unit.granted_rerolls));
	unit.rerolls = unit.rerolls_max;
	unit.granted_rerolls = 0;
	unit.locked = false;
	unit.block_lost = I(unit.block_lost_accum);
	unit.block_lost_accum = 0;
	unit.dealt_last_turn = I(unit.dealt);
	unit.dealt = 0;
	unit.healed = 0;
	const foes = living(state.enemies);
	const current = enemyById(state, String(unit.target || ''));
	if ((!current || (I(current.hp)) <= 0) && foes.length) unit.target = foes[0].id;
}

function payDues(unit, rolls) {
	const dues = Dice.throwDues(rolls);
	if (dues.resonance > 0) { unit.initial_resonance = satAdd(unit.initial_resonance, dues.resonance); unit.resonance = satAdd(unit.resonance, dues.resonance); }
	if (dues.pyrite > 0) unit.pyrite_delta = (I(unit.pyrite_delta)) + dues.pyrite;
	if (dues.hp > 0 && !unit.downed) unit.hp = Math.max(1, unit.hp - dues.hp);
}

// Spend the rerolls chasing `policy` (see simulate.js), then Sleight's parity shift if the
// character has one and it helps.
export function plan(unit, policy, roll) {
	while ((I(unit.rerolls)) > 0) {
		if (policy === 'none' && !allOrNothing(unit)) break;
		const allowed = new Set(Dice.rerollable(unit.hand));
		// All or Nothing: the whole bowl goes again or none of it (see allOrNothingRolls).
		const chosen = allOrNothing(unit) ? (allOrNothingRolls(unit, policy) ? [...allowed] : [])
			: [...rerollIds(policy, unit.hand, readHand(unit))].filter((id) => allowed.has(id));
		if (!chosen.length) break;
		const set = new Set(chosen);
		const byId = new Map(unit.dice.map((d, i) => [d.id, [d, i]]));
		const next = [];
		for (const r of unit.hand) {
			if (r.phantom) continue;
			if (set.has(r.die_id) && !r.locked && byId.has(r.die_id)) { const [die, index] = byId.get(r.die_id); next.push(roll(die, index, (I(r.rerolls)) + 1)); }
			else next.push({ ...r, held: true, climbed: false, shattered: false });
		}
		unit.hand = next;
		unit.rerolls -= 1;
		payDues(unit, unit.hand.filter((r) => set.has(r.die_id)));
		crownsRolled(unit, unit.hand.filter((r) => set.has(r.die_id)), true);
	}
	if ((I(unit.flips)) > 0) flipBest(unit, policy);
	unit.locked = true;
}

// Whether an All or Nothing hand is worth throwing again: never with three crowns showing,
// always with none, and with one or two only when the gem the rail chases is not answered.
// A Gambler who must throw the whole bowl plays the odds, not a pattern.
function allOrNothingRolls(unit, policy) {
	const crowns = unit.hand.filter((r) => isCrown(r)).length;
	if (crowns >= 3) return false;
	if (crowns === 0) return true;
	if (policy === 'none' || policy === 'always') return crowns < 2;
	return rerollIds(policy, unit.hand, readHand(unit)).size > 0 && crowns < 2;
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
	const previous = I(roll.value);
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
	const hit = Number(foe.hit ?? 1) || 1;
	const blow = (die, u) => (hit === 1 ? faceAt(die, u) : Math.round(faceAt(die, u) * hit));
	foe.dice.forEach((die, i) => { state.ledger.incoming += blow(die, draws[i]) + enrage; });
	if ((I(foe.hp)) <= 0) return;
	const suppressed = Math.min(foe.dice.length, I(foe.stolen_dice));
	foe.stolen_dice = 0;
	if ((I(foe.statuses.stun)) > 0 || (foe.dice.length && suppressed >= foe.dice.length)) {
		if ((I(foe.statuses.stun)) > 0) {
			foe.statuses.stun -= 1;
			foe.stun_streak = (I(foe.stun_streak)) + 1;
			if (foe.stun_streak >= 3) { foe.statuses.stun = 0; foe.statuses.combo_breaker = 2; foe.stun_streak = 0; }
		} else foe.stun_streak = 0;
		finish(foe);
		return;
	}
	foe.stun_streak = 0;
	if (foe.guard > 0) foe.block = (I(foe.block)) + foe.guard;
	const dread = Math.max(0, I(foe.dread_turns));
	const clouded = (I(foe.statuses.clouded)) > 0 ? foe.clouded_move : -1;
	for (let i = 0; i < foe.dice.length - suppressed; i++) {
		if (i === clouded || !target) continue;
		damage(state, foe, target, blow(shrunk(foe.dice[i], dread), draws[i]), rng);
	}
	settleMarks(state);
	finish(foe);
}

function finish(foe) {
	foe.turns_acted = (I(foe.turns_acted)) + 1;
	foe.hurt_by = {};
	foe.biggest_hit = 0;
	foe.dread_turns = Math.max(0, (I(foe.dread_turns)) - 1);
	if ((I(foe.statuses.clouded)) > 0) {
		foe.statuses.clouded -= 1;
		if (foe.statuses.clouded === 0) foe.clouded_move = -1;
	}
}

// --- a whole fight ---------------------------------------------------------------------------

const mix = (a, b, c) => {
	let x = (Math.imul(I(a), 0x9e3779b1) ^ Math.imul((I(b)) + 0x7f4a7c15, 0x85ebca6b) ^ Math.imul((I(c)) + 0x165667b1, 0xc2b2ae35)) >>> 0;
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
//
// `spec.wall`: a kill line. The dummies keep standing (give them no health), and `killTurn` is
// when the damage dealt crossed the line, in turns, read within the turn that crossed it (1.5:
// halfway through the second), or Infinity if it never did. Overkill is never lost to it.
// `spec.eventCap`: how many events a rail may play before it counts as a runaway (see runQueue);
// `spec.stopOnRunaway` ends the fight there, and `spec.stopAtWall` ends it once the kill line falls.
// `spec.perTurn`: also return `turnDealt` and `turnSaved`, what each turn added.
// `carry`: what lasts the run, from one fight to the next ({dice, runCounts, maxHp}, filled in
// as the fight ends): the faces a Glimmer raised, a Hydrophane's drops, how often a Hone has
// fired, a Heartwood's health. `spec.fight` numbers the fight in a run, for its own dice.
export function playFight(spec, sample, carry = null) {
	const seed = (I(spec.seed)) + 7919 * (I(spec.fight));
	const turns = Math.max(1, I(spec.turns));
	const character = C.character(spec.character);
	const bowl = carry && carry.dice ? carry.dice : (spec.dice || character.dice || []).map((ref, i) => Dice.dieFrom(ref, `p${i}`));
	const unit = makePlayer('p0', spec.character, spec.rail || [], bowl, { sockets: spec.sockets || (spec.rail || []).map(() => C.SOCKET_ANY), pyrite: spec.pyrite ?? 0,
		birthstone: spec.birthstone !== false, passive: spec.passive !== false, hp: carry && carry.maxHp ? carry.maxHp : undefined });
	if (carry && carry.runCounts) unit.run_counts = { ...carry.runCounts };
	if (spec.opalsApart) unit.opals_apart = true;
	if (spec.gemPlays) unit.gem_plays_cap = I(spec.gemPlays);
	const dummies = spec.dummies || {};
	const enemies = Array.from({ length: Math.max(1, I(dummies.count) || 1) }, (_, i) => makeDummy(`e${i}`, dummies));
	const state = makeFight({ players: [unit], enemies, depth: I(spec.depth) || 1, noDowns: true });
	if (spec.eventCap) state.eventCap = spec.eventCap;
	const misc = makeRng(mix(seed, sample, 1));
	const creatures = makeRng(mix(seed, sample, 2));
	const wall = Number(spec.wall || 0);
	let killTurn = Infinity;
	const turnDealt = spec.perTurn ? [] : null;
	const turnSaved = spec.perTurn ? [] : null;
	const streams = new Map();
	const roll = (die, index, rerolled = 0) => {
		const key = state.turn * 64 + index;
		let rng = streams.get(key);
		if (!rng) { rng = makeRng(mix(seed, sample, 100 + key)); streams.set(key, rng); }
		return Dice.rollOne(die, rng, rerolled);
	};
	const policy = spec.policy || 'none';
	const L = state.ledger;
	for (let turn = 1; turn <= turns; turn++) {
		const before = L.dealt;
		const savedBefore = L.incoming - L.hpLost + L.healed;
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
		if (wall > 0 && killTurn === Infinity && L.dealt >= wall) killTurn = turn - 1 + (wall - before) / Math.max(1e-9, L.dealt - before);
		if (turnDealt) { turnDealt.push(L.dealt - before); turnSaved.push(L.incoming - L.hpLost + L.healed - savedBefore); }
		if (L.runaway && spec.stopOnRunaway) break;
		if (spec.stopAtWall && killTurn < Infinity) break;
	}
	// A Hot Streak's bonus die was only lent for a turn.
	if (carry) { carry.dice = unit.dice.filter((d) => !d.bonus); carry.runCounts = unit.run_counts || {}; carry.maxHp = unit.max_hp; }
	const out = { dealt: L.dealt, kills: L.kills, incoming: L.incoming, hpLost: L.hpLost, healed: L.healed, gold: (I(unit.gold)) + (I(unit.pyrite_delta)) + (I(unit.pot)), blockGained: L.blockGained,
		fires: L.fires, fizzles: L.fizzles, birthstone: L.birthstone, resonance: L.resonance, downs: L.downs, sparkle: I(unit.sparkle), killTurn, runaway: I(L.runaway), maxEvents: I(L.maxEvents) };
	if (turnDealt) { out.turnDealt = turnDealt; out.turnSaved = turnSaved; }
	return out;
}
