// The rule language: a port of sim/rules.gd. Amounts are arithmetic over the hand, effects
// are whole numbers, and a stone's magnitude scales the kinds that can take a multiplier.

import * as Hand from './hand.js';

export const SCALED_BY_DEFAULT = ['damage', 'block', 'heal', 'gold', 'poison', 'remove_block', 'retain', 'regeneration', 'spikes', 'lifeline', 'wager', 'detonate'];
export const DEBUFFS = ['poison', 'stun', 'curse', 'dice_dread', 'die_steal', 'clouded', 'dulled', 'marked', 'max_hp_loss'];
export const HOSTILE = ['damage', 'damage_curse', 'detonate', 'wager', 'poison', 'stun', 'remove_block', 'curse', 'dice_dread', 'die_steal', 'clouded', 'dulled', 'marked', 'max_hp_loss'];
export const EFFECT_OPTIONS = ['chain_on_kill', 'missing_hp_bonus', 'from_result', 'remove_all', 'revive_block', 'scope', 'all_faces', 'refund_mult', 'poison_splash'];
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
		case 'enemy_poison': return c.enemy_poison | 0;
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
			enemy_poison: 'enemy poison', resonance: 'Resonance', pyrite: 'pyrite', odd: 'odd dice', even: 'even dice', distinct: 'distinct values', held: 'held dice', rerolled: 'rerolled dice' };
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

export function effectWords(effect, cutStep = null) {
	const n = amountWords(effect.amount ?? 0, cutStep);
	const kind = String(effect.kind || '');
	const rep = effect.repeat !== undefined ? ` × ${amountWords(effect.repeat, cutStep)}` : '';
	const labels = {
		damage: `${n} damage${rep}`, block: `${n} block${rep}`, heal: `heal ${n}${rep}`, gold: `${n} pyrite`, poison: `${n} poison${rep}`, stun: `stun ${n}`, remove_block: `remove ${n} block`,
		cleanse: `cleanse ${n}`, curse: `${n} Curse`, ward: `${n} Ward`, retain: `retain ${n} block`, charged: `${n} Charged`, regeneration: `${n} Regeneration`, spikes: `${n} Spikes`,
		marked: `${n} Marked`, dulled: `${n} Dulled`, clouded: 'cloud a socket', die_steal: `suppress ${n} die`, dice_dread: `${n} Dread`, dice_upgrade: `dice +${n} tier`,
		max_hp_loss: `−${n} max HP`, lifeline: `${n} Lifeline`, detonate: `${n} damage per poison consumed`, wager: `wager: ${n} damage`, stake: `stake: amplify next`,
		coin_flip: `${n}% coin flip`, sparkle: `${n} Sparkle`, quality_bonus: `stones +${n}% better`, appraise: `appraise ${n} raw stone`, upgrade_faces: `raise matched faces by ${n}`,
		phantom_high: `${n} phantom of the highest die`, gem_rank: `+${n} ${effect.rank || 'rank'}`, set_match: 'join a die to the strongest set', grant_reroll: `${n} extra reroll`,
		retrigger_previous: `repeat the previous gem at ${n}%`, resonance: `+${n} Resonance`, replay_color: `replay every ${effect.color ? effect.color.toLowerCase() : ''} gem`,
		rank_buff: `+${n} ${effect.rank || 'rank'} to every gem`, replay_fizzled: `fire ${n} dark gem`, repeat_next: `next gem fires ${n} more`, damage_curse: 'damage = Curse stacks',
		void_copy: `${n} Void copy of the last gem that fired`,
		amplify_next: `amplify next gem ${n}%`, revive: 'revive an ally', max_hp: `+${n} max HP`,
	};
	return labels[kind] || `${kind.replace(/_/g, ' ')} ${n}`;
}
