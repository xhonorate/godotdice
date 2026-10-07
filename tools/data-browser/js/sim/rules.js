// The rule language: a port of sim/rules.gd. Amounts are arithmetic over the hand, effects
// are whole numbers, and a stone's magnitude scales the kinds that can take a multiplier.

import * as Hand from './hand.js';
import * as C from './content.js';

export const OPS = ['+', '-', '*', 'min', 'max', 'floor_div', 'pct', 'if', 'ge', 'eq'];
export const TERMS = ['rolled', 'value', 'second', 'count', 'high', 'low', 'total', 'max_total', 'missing', 'odd', 'even',
	'distinct', 'held', 'rerolled', 'dice', 'count_value', 'count_at_most', 'count_at_least', 'run_high', 'run_length',
	'set_value', 'set_count', 'sum_low', 'sum_high', 'block', 'block_lost', 'healed', 'dealt', 'hp', 'max_hp', 'hp_missing', 'gold',
	'resonance', 'previous_amount', 'carat', 'cut', 'clarity', 'depth', 'turn', 'party', 'crowns', 'low_dice', 'pyrite', 'pot', 'enemy_poison', 'fizzles',
	'swell', 'held_gems', 'biggest_hit', 'party_heaviest_carat', 'party_best_turn', 'party_richest', 'turns_acted', 'living_players', 'strength'];
export const RANKS = ['carat', 'cut', 'clarity'];
export const EFFECT_KINDS = ['damage', 'block', 'heal', 'gold', 'poison', 'stun', 'remove_block', 'cleanse', 'revive',
	'curse', 'amplify_next', 'cut_step_next', 'raise_low', 'raise_high', 'set_match', 'flip_high', 'flip_low',
	'phantom_high', 'grant_reroll', 'retrigger_previous', 'dice_dread', 'die_steal', 'quality_bonus',
	'sparkle', 'coin_flip', 'resonance', 'replay_color', 'replay_fizzled', 'rank_buff', 'repeat_next', 'void_copy',
	'replay_rail', 'tick_poison', 'stone_drop', 'pot', 'dice_upgrade', 'ward', 'retain', 'charged', 'marked',
	'regeneration', 'spikes', 'dulled', 'clouded', 'lifeline', 'max_hp', 'max_hp_loss', 'damage_curse', 'detonate', 'wager', 'stake', 'upgrade_faces', 'gem_rank', 'appraise',
	'mar_die', 'grind_die', 'lock_die', 'break_die', 'downgrade_die', 'break_gem',
	'summon', 'purge', 'burrow', 'festering', 'scorched', 'burn', 'strength', 'die_lock', 'steal_gold',
	'empower_next', 'rally', 'grow_die', 'swell', 'hold_gem', 'bury_socket', 'exhibit', 'charge',
	'reflect', 'mirror', 'absorb_color', 'blank_face', 'roll_again', 'end_action'];
// The creature-only kinds: a skill or an inclusion may not use them.
export const CREATURE_KINDS = ['summon', 'purge', 'burrow', 'festering', 'scorched', 'burn', 'strength', 'die_lock', 'steal_gold',
	'empower_next', 'rally', 'grow_die', 'swell', 'hold_gem', 'bury_socket', 'exhibit', 'charge',
	'reflect', 'mirror', 'absorb_color', 'blank_face', 'roll_again', 'end_action'];
export const SCALED_BY_DEFAULT = ['damage', 'block', 'heal', 'gold', 'poison', 'remove_block', 'retain', 'regeneration', 'spikes', 'lifeline', 'wager', 'detonate'];
export const DEBUFFS = ['poison', 'stun', 'curse', 'dice_dread', 'die_steal', 'clouded', 'dulled', 'marked', 'max_hp_loss',
	'mar_die', 'grind_die', 'lock_die', 'break_die', 'downgrade_die', 'break_gem',
	'festering', 'scorched', 'burn', 'die_lock', 'blank_face', 'hold_gem', 'bury_socket'];
export const HOSTILE = ['damage', 'damage_curse', 'detonate', 'wager', 'poison', 'stun', 'remove_block', 'curse', 'dice_dread', 'die_steal', 'clouded', 'dulled', 'marked', 'max_hp_loss',
	'mar_die', 'grind_die', 'lock_die', 'break_die', 'downgrade_die', 'break_gem',
	'festering', 'scorched', 'burn', 'die_lock', 'blank_face', 'steal_gold', 'hold_gem', 'bury_socket'];
// What a creature's hostile effect means by "the enemy": these are turned on the party.
export const ENEMY_SIDE_TARGETS = ['enemy', 'enemies', 'spread', 'enemy_behind', 'enemy_adjacent', 'hero', 'heroes'];
export const HERO_PICKS = ['hero_least_block', 'hero_most_hp', 'hero_most_gold', 'hero_top_damage', 'hero_top_dealt', 'hero_marked'];
export const TARGETS = ['self', 'ally_low', 'allies', 'allies_other', 'enemy', 'enemies', 'spread', 'enemy_behind', 'enemy_adjacent', 'downed_ally', 'hero', 'heroes', ...HERO_PICKS];
export const EFFECT_OPTIONS = ['chain_on_kill', 'missing_hp_bonus', 'from_result', 'remove_all', 'revive_block', 'scope', 'all_faces', 'refund_mult', 'poison_splash', 'pot_mode',
	'piercing', 'split_party', 'pick', 'creature', 'pct', 'permanent', 'shape', 'cap', 'turns', 'cancel_pct', 'guard_pct', 'store', 'release',
	'hurt', 'add', 'flat'];
// How an effect that works on one die or one gem chooses it, and how an absorb_color picks its colour.
export const PICKS = ['high', 'low', 'random', 'heaviest', 'hardest', 'best', 'usable', 'showing', 'all'];
export const ABSORB_PICKS = ['random', 'most_used'];
export const POT_MODES = ['ante', 'double', 'all', 'lose'];
export const FROM_RESULTS = ['damage', 'gold', 'block', 'removed', 'stolen'];
export const MAX_REPEAT = 100;
export const VALUE_LIMIT = 9999;
export const MAX_PROCS = 10;
export const CURSE_MAX_STACKS = 10;
export const CURSE_PERCENT = 10;

export function pyrite(unit) { return Math.max(0, (unit.ore | 0) + (unit.gold | 0) + (unit.pyrite_delta | 0)); }

export function amount(expr, c) {
	if (typeof expr === 'number') return Math.trunc(expr);
	if (!expr || typeof expr !== 'object') return 0;
	if ('const' in expr) return Math.trunc(expr.const);
	if ('term' in expr) return term(String(expr.term), expr, c);
	if ('rank' in expr) return c[String(expr.rank)] | 0;
	if ('ladder' in expr) {
		const ladder = expr.ladder;
		if (!ladder.length) return 0;
		return Math.trunc(ladder[Math.max(0, Math.min(c.cut | 0, ladder.length - 1))]);
	}
	const op = String(expr.op || '+');
	const values = (expr.args || []).map((a) => amount(a, c));
	if (!values.length) return 0;
	switch (op) {
		case 'if': return values[0] !== 0 ? values[1] | 0 : values[2] | 0;
		case 'ge': return values[0] >= values[1] ? 1 : 0;
		case 'eq': return values[0] === values[1] ? 1 : 0;
		case '+': return values.reduce((s, v) => s + v, 0);
		case '-': return values.slice(1).reduce((s, v) => s - v, values[0]);
		case '*': return values.reduce((s, v) => s * v, 1);
		case 'min': return Math.min(...values);
		case 'max': return Math.max(...values);
		case 'floor_div': return values.length > 1 ? Math.trunc(values[0] / Math.max(1, values[1])) : values[0];
		case 'pct': return values.length > 1 ? Math.floor((values[0] * values[1]) / 100) : values[0];
	}
	return 0;
}

export function term(name, node, c) {
	const a = c.a || {};
	const trig = c.trig || {};
	const unit = c.unit || {};
	switch (name) {
		case 'rolled': return c.rolled | 0;
		case 'value': return trig.value | 0;
		case 'second': return trig.second | 0;
		case 'count': return trig.count | 0;
		case 'high': case 'low': case 'total': case 'max_total': case 'odd': case 'even': case 'distinct': case 'held': case 'rerolled': case 'crowns': case 'low_dice':
			return a[name] | 0;
		case 'missing': return Math.max(0, (a.max_total | 0) - (a.total | 0));
		case 'dice': return a.dice_count | 0;
		case 'count_value': { const w = node.value | 0; return Hand.matching(a, (v) => v === w).length; }
		case 'count_at_most': { const w = node.value | 0; return Hand.matching(a, (v) => v <= w).length; }
		case 'count_at_least': { const w = node.value | 0; return Hand.matching(a, (v) => v >= w).length; }
		case 'run_high': return (a.straight || {}).high | 0;
		case 'run_length': return (a.straight || {}).length | 0;
		case 'set_value': return (a.best_set || {}).value | 0;
		case 'set_count': return (a.best_set || {}).count | 0;
		case 'sum_low': return Hand.read(a, Math.max(1, node.value | 0 || 1), false).sum;
		case 'sum_high': return Hand.read(a, Math.max(1, node.value | 0 || 1), true).sum;
		case 'block': return unit.block | 0;
		case 'block_lost': return unit.block_lost | 0;
		case 'healed': return unit.healed | 0;
		case 'dealt': return unit.dealt | 0;
		case 'hp': return unit.hp | 0;
		case 'max_hp': return unit.max_hp | 0;
		case 'hp_missing': return Math.max(0, (unit.max_hp | 0) - (unit.hp | 0));
		case 'gold': return unit.gold | 0;
		case 'pyrite': return pyrite(unit);
		case 'pot': return unit.pot | 0;
		case 'enemy_poison': return c.enemy_poison | 0;
		case 'fizzles': return c.fizzles | 0;
		// What a creature reads off itself and off the fight (sim/creatures.gd context).
		case 'swell': return unit.swell | 0;
		case 'held_gems': return (unit.held_gems || []).length;
		case 'biggest_hit': return unit.biggest_hit | 0;
		case 'turns_acted': return unit.turns_acted | 0;
		case 'party_heaviest_carat': return c.party_heaviest_carat | 0;
		case 'party_best_turn': return c.party_best_turn | 0;
		case 'party_richest': return c.party_richest | 0;
		case 'strength': return (unit.statuses || {}).strength | 0;
		case 'living_players': return Math.max(1, (c.living_players ?? c.party ?? 1) | 0);
		case 'resonance': return c.resonance | 0;
		case 'previous_amount': return c.previous_amount | 0;
		case 'carat': case 'cut': case 'clarity': case 'depth': case 'turn': case 'party': return c[name] | 0;
	}
	return 0;
}

// A skill's card text with its Cut-dependent numbers written in.
export function fill(text, numbers, cutStep) {
	if (!numbers || !Object.keys(numbers).length || !text.includes('{')) return text;
	const c = { cut: cutStep };
	let out = text;
	for (const key of Object.keys(numbers)) {
		const n = amount(numbers[key], c);
		const marker = `{${key}#`;
		while (out.includes(marker)) {
			const start = out.indexOf(marker);
			const stop = out.indexOf('}', start);
			if (stop < 0) break;
			const noun = out.slice(start + marker.length, stop);
			out = out.slice(0, start) + `${n} ${n === 1 ? noun : noun + 's'}` + out.slice(stop + 1);
		}
		out = out.split(`{${key}}`).join(String(n));
	}
	return out;
}

// How a whole-number effect answers to weight: extra goes, and the chance of one more.
export function caratProcs(magnitude) {
	const steps = Math.max(0, (magnitude - 1) / 3);
	let whole = Math.floor(steps);
	let chance = Math.round((steps - whole) * 100);
	if (chance >= 100) { whole += 1; chance = 0; }
	const procs = Math.max(1, Math.min(1 + whole, MAX_PROCS));
	return { procs, chance: procs >= MAX_PROCS ? 0 : chance };
}

export function defaultTarget(kind, hostileSide = 'enemy') {
	if (HOSTILE.includes(kind)) return hostileSide;
	if (kind === 'revive') return 'downed_ally';
	return 'self';
}

export function resolveEffect(def, c, magnitude, hostileSide = 'enemy') {
	const kind = String(def.kind || 'damage');
	const raw = amount(def.amount ?? { const: 0 }, c);
	const scale = String(def.scale ?? (SCALED_BY_DEFAULT.includes(kind) ? 'carat' : 'none'));
	const final = scale === 'carat' ? Math.floor(raw * magnitude) : raw;
	const repeat = Math.max(0, Math.min(amount(def.repeat ?? { const: 1 }, c), MAX_REPEAT));
	const proc = scale === 'carat' || 'scale' in def ? { procs: 1, chance: 0 } : caratProcs(magnitude);
	const out = { kind, target: String(def.target || defaultTarget(kind, hostileSide)), amount: Math.max(-VALUE_LIMIT, Math.min(VALUE_LIMIT, final)),
		raw, repeat, scaled: scale === 'carat', procs: proc.procs, proc_chance: proc.chance, dice: ((c.trig || {}).dice || []).slice() };
	if ('cost' in def) out.cost = Math.max(0, amount(def.cost, c));
	for (const field of [...EFFECT_OPTIONS, 'splash', 'once', 'win_mult', 'lose_mult', 'text', 'color', 'rank']) if (field in def) out[field] = def[field];
	return out;
}

// What the numbers in a rule mean, in words, for a table cell.
export function amountWords(expr, cutStep = null) {
	if (typeof expr === 'number') return String(Math.trunc(expr));
	if (!expr || typeof expr !== 'object') return '0';
	if ('const' in expr) return String(expr.const);
	if ('term' in expr) {
		const names = { rolled: 'rolled value', value: 'matched value', second: 'second value', count: 'dice matched', high: 'highest die', low: 'lowest die', total: 'dice total',
			sum_low: `sum of lowest ${expr.value || 1}`, sum_high: `sum of highest ${expr.value || 1}`, block: 'current block', block_lost: 'block lost', healed: 'healing done',
			enemy_poison: 'enemy poison', fizzles: 'unpaid fizzles', resonance: 'Resonance', pyrite: 'pyrite', odd: 'odd dice', even: 'even dice', distinct: 'distinct values', held: 'held dice', rerolled: 'rerolled dice',
			swell: 'its swelling', held_gems: 'gems it holds', biggest_hit: 'hardest hit on it this turn', party_heaviest_carat: "heaviest gem's carats",
			party_best_turn: "the party's best turn", party_richest: 'the richest purse', strength: 'its Strength', turns_acted: 'actions taken', living_players: 'players standing', pot: 'the pot', dealt: 'damage dealt', hp: 'health', max_hp: 'max health', hp_missing: 'missing health' };
		return names[expr.term] || expr.term;
	}
	if ('rank' in expr) return expr.rank;
	if ('ladder' in expr) return cutStep === null ? `[${expr.ladder.join(' · ')}]` : String(expr.ladder[Math.max(0, Math.min(cutStep, expr.ladder.length - 1))]);
	const parts = (expr.args || []).map((a) => amountWords(a, cutStep));
	const op = expr.op || '+';
	if (op === 'pct') return `${parts[1]}% of ${parts[0]}`;
	if (op === 'floor_div') return `${parts[0]} ÷ ${parts[1]}`;
	if (op === '*') return parts.join(' × ');
	return parts.join(` ${op} `);
}

// Whom a creature's effect lands on, in words (sim/creatures.gd TARGET_WORDS).
export const TARGET_WORDS = { heroes: 'all players', hero: 'all players', self: 'itself', allies: 'every creature', allies_other: 'every other creature',
	hero_least_block: 'the player with the least block', hero_most_hp: 'the player with the most health', hero_most_gold: 'the player with the most pyrite',
	hero_top_damage: 'whoever hurt it most this turn', hero_top_dealt: 'whoever dealt the most last turn', hero_marked: 'every Marked player',
	spread: 'spread round the party' };
export function targetWords(effect, fallback = 'all players') { return TARGET_WORDS[String(effect.target || 'heroes')] || fallback; }
// The targets worth saying out loud after a label: a creature picking one player, or its own side.
const NAMED_TARGETS = ['allies_other', ...HERO_PICKS];
const FROM_WORDS = { damage: 'damage just dealt', gold: 'pyrite just gained', block: 'block just gained', removed: 'block just removed', stolen: 'pyrite stolen' };
const diceWords = (n) => `${n} ${n === 1 ? 'die' : 'dice'}`;

export function effectWords(effect, cutStep = null) {
	let n = amountWords(effect.amount ?? 0, cutStep);
	if (effect.from_result) n = `${n}% of the ${FROM_WORDS[effect.from_result] || effect.from_result}`;
	const kind = String(effect.kind || '');
	const target = String(effect.target || '');
	const rep = effect.repeat !== undefined ? ` × ${amountWords(effect.repeat, cutStep)}` : '';
	const count = typeof effect.amount === 'number' ? effect.amount : Number((effect.amount || {}).const ?? NaN);
	const pick = String(effect.pick || 'random');
	const atHeroes = ['hero', 'heroes', ...HERO_PICKS].includes(target);
	let damage = `${n} damage${rep}`;
	if (effect.split_party) damage = `${n} damage${rep}, split across the party (rounded up)`;
	if (effect.piercing) damage += ' · ignores block';
	if (effect.flat) damage += ' · plus its Strength, nothing more';
	if (target === 'spread') damage += ' · spread round the party';
	const drunk = String(effect.color || 'random') === 'most_used' ? 'the colour the party uses most' : 'a colour';
	const showing = pick === 'showing';
	const labels = {
		damage, block: `${n} block${rep}`, heal: `heal ${n}${rep}`, gold: atHeroes ? `drops ${n} pyrite` : `${n} pyrite`, poison: `${n} poison${rep}`, stun: target === 'self' ? `stuns itself · ${n} turn` : `stun ${n}`, remove_block: effect.remove_all ? 'removes all your block' : `remove ${n} block`,
		cleanse: n === '99' ? 'sheds every affliction on it' : `cleanse ${n}`, curse: `${n} Curse`, ward: `${n} Ward`, retain: `retain ${n} block`, charged: `${n} Charged`, regeneration: `${n} Regeneration`, spikes: `${n} Spikes`,
		marked: `${n} Marked`, dulled: `${n} Dulled`, clouded: atHeroes || !target ? 'cloud a socket' : `Clouded for ${n} actions · one random ability disabled`, die_steal: `suppress ${n} die`, dice_dread: `${n} Dread`,
		dice_upgrade: `dice +${n} tier${effect.cap ? ` (${String(effect.cap).toLowerCase()} at most)` : ''}`,
		max_hp_loss: `−${n} max HP`, lifeline: `${n} Lifeline`, detonate: `${n} damage per poison consumed`, wager: `wager: ${n} damage`, stake: `stake: amplify next`,
		coin_flip: `${n}% coin flip`, sparkle: `${n} Sparkle`, quality_bonus: `stones +${n}% better`, appraise: `appraise ${n} raw stone`, upgrade_faces: `raise matched faces by ${n}`,
		phantom_high: `${n} phantom of the highest die`, gem_rank: `+${n} ${effect.rank || 'rank'}`, set_match: 'join a die to the strongest set', grant_reroll: `${n} extra reroll`,
		retrigger_previous: `repeat the previous gem at ${n}%`, resonance: `+${n} Resonance`, replay_color: `replay every ${effect.color ? effect.color.toLowerCase() : ''} gem`,
		rank_buff: `+${n} ${effect.rank || 'rank'} to every gem`, replay_fizzled: `fire ${n} dark gem`, repeat_next: `next gem fires ${n} more`, damage_curse: 'damage = Curse stacks',
		void_copy: `${n} Void copy of the last gem that fired`,
		amplify_next: `amplify next gem ${n}%`, revive: 'revive an ally', max_hp: `+${n} max HP`,
		// Elites only, and rare.
		mar_die: 'mars a face of one of your dice (blank or locked)',
		grind_die: showing ? `every face your dice show loses 1${effect.permanent ? ', for good' : ' for the fight'}` : `your ${pick === 'high' ? 'highest die' : 'die'} loses 1 from its top face${effect.permanent ? ' for good' : ' for the fight'}`,
		lock_die: 'locks one of your dice this turn',
		break_die: effect.permanent ? 'destroys one of your dice for the rest of the fight' : 'breaks one of your dice · it grows back next turn',
		downgrade_die: pick === 'all' ? 'every one of your dice shrinks a size for the fight' : `your ${pick === 'high' ? 'highest die' : 'die'} shrinks a size for the fight`,
		blank_face: 'the face one of your dice shows is blank for the rest of the fight',
		break_gem: `melts one of your gems${effect.permanent ? ' for the rest of the fight' : ' until next turn'}`,
		// Creature-only, what the deeper mines fight with (sim/creatures.gd effect_words).
		summon: n === '1' ? `${summonedName(effect)} joins the fight` : `${n} ${summonedName(effect)}s join the fight`,
		purge: `sheds ${n}% of its poison`,
		burrow: 'burrows · cannot be targeted until its next action',
		absorb_color: `drinks ${drunk}${effect.add ? ' as well' : ''} · those gems do it no damage, and what they would give their owner goes to it`,
		reflect: `until its next action, ${n}% of every blow on it goes back to every player`,
		mirror: n === '1' ? 'the next blow on it hits whoever threw it instead' : `the next ${n} blows on it hit whoever threw them instead`,
		festering: `${n} Festering · healing halved`,
		scorched: `${n} Scorched · block gained halved`,
		burn: `${n} Burn · hurts at the end of each turn, block soaks it, one less each turn`,
		strength: `${n} Strength · ${n} more on every blow, for the fight`,
		roll_again: 'throws this die once more',
		end_action: 'its action ends here',
		exhibit: 'fires every gem it holds, as its own',
		die_lock: `locks your ${pick === 'high' ? 'highest die' : pick === 'low' ? 'lowest die' : diceWords(Number.isFinite(count) ? count : 1)} · it comes up the same and cannot be rerolled next turn`,
		steal_gold: (effect.pct ? `takes ${n}% of each player's pyrite` : `takes ${n} pyrite from each player`) + (effect.hurt ? ' · and hits each for what it took' : ''),
		empower_next: `its next attack deals ${n}% more`,
		rally: `every creature deals ${n} more this turn`,
		grow_die: `grows another head: +1 ${String(effect.shape || 'D6').toLowerCase()} (${effect.cap ?? 5} at most)`,
		swell: `swells by ${n} · its burst grows`,
		hold_gem: `takes ${{ hardest: 'the gem that hit it hardest this turn', usable: 'the finest gem it can fire itself' }[String(effect.pick || 'hardest')] || "the party's highest-grade gem"} off a rail until it dies`,
		bury_socket: 'buries the socket holding your heaviest gem',
		charge: chargeWords(effect, cutStep),
	};
	let words = labels[kind] || `${kind.replace(/_/g, ' ')} ${n}`;
	// A creature that names one player, or every other creature, says so.
	if (NAMED_TARGETS.includes(target) && kind !== 'summon') words += ` · ${TARGET_WORDS[target]}`;
	else if (target === 'self' && HOSTILE.includes(kind) && kind !== 'stun' && !CREATURE_KINDS.includes(kind)) words += ' · itself';
	return words;
}

function summonedName(effect) {
	const key = String(effect.creature || '');
	return C.creature(key).name || (key ? C.title(key) : 'creature');
}

function chargeWords(effect, cutStep) {
	const turns = Number(effect.turns ?? 2);
	const winding = effect.store ? 'all the damage it was dealt meanwhile, back at every player' : (effect.release || []).map((e) => effectWords(e, cutStep)).join(' and ');
	let words = `charges for ${turns} ${turns === 1 ? 'action' : 'actions'}, then: ${winding}`;
	if (Number(effect.guard_pct ?? 0) > 0) words += ` · takes ${effect.guard_pct}% less meanwhile`;
	if (Number(effect.cancel_pct ?? 0) > 0) words += ` · losing ${effect.cancel_pct}% of its health meanwhile cancels it`;
	return words;
}
