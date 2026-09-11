// The gem rule language, as the studio understands it.
//
// A port of `scripts/core/gem_rules.gd`, term for term and operator for operator, so the
// panel can show what a rule does on a real hand while you are still writing it. The
// engine remains the authority: `tools/content_studio/rule_probe.mjs` and its GDScript
// twin run both over the same recipes and hands, and any disagreement is a bug here.

export const TRIGGERS = ["always", "pair", "two_pairs", "triple", "full_house", "straight",
	"parity", "distinct", "value", "total_at_least", "total_at_most", "high_at_least"];
export const TERMS = ["high", "low", "total", "pair_value", "triple_value", "run_high",
	"highest_sum", "lowest_sum", "lowest_odd", "count_even", "count_odd", "count_distinct",
	"count_value", "block"];
export const RANKS = ["carat", "cut", "clarity", "clarity_bonus"];
export const OPERATORS = ["+", "-", "*", "floor_div", "min", "max", "by_cut"];
export const EFFECT_KINDS = ["damage", "block", "heal", "gold", "poison", "stun", "remove_block"];
export const EFFECT_TARGETS = ["self", "enemy", "enemies", "ally", "other_allies"];
export const MAX_EFFECTS = 6;
export const MAX_DEPTH = 6;
export const MAX_NODES = 60;
export const MAX_REPEAT = 8;
export const VALUE_LIMIT = 9999;

/** What each piece of the vocabulary means, for the hints beside every dropdown. */
export const HINTS = {
	always: "Fires on any hand.",
	pair: "Two dice showing the same value.",
	two_pairs: "Two different values, each shown twice.",
	triple: "Three or more dice showing one value.",
	full_house: "Three of one value and two of another.",
	straight: "A run of consecutive values.",
	parity: "At least this many even or odd results.",
	distinct: "At least this many different values.",
	value: "At least one die showing a particular number.",
	total_at_least: "The five dice add up to at least this.",
	total_at_most: "The five dice add up to no more than this.",
	high_at_least: "The highest die is at least this.",
	high: "The highest single die.",
	low: "The lowest single die.",
	total: "All five dice added together.",
	pair_value: "The value your highest pair shows, not the two dice added.",
	triple_value: "The value your highest group of three shows.",
	run_high: "The highest value in the straight the trigger found.",
	highest_sum: "The highest N dice, added together.",
	lowest_sum: "The lowest N dice, added together.",
	lowest_odd: "The lowest odd die.",
	count_even: "How many dice came up even.",
	count_odd: "How many dice came up odd.",
	count_distinct: "How many different values are in the hand.",
	count_value: "How many dice show a particular number.",
	block: "The block the caster has when this resolves.",
	carat: "The gem's Carat, 1 to 24.",
	cut: "The gem's Cut, 1 to 5. Usually written K.",
	clarity: "The gem's Clarity, 1 to 5. Usually written L.",
	clarity_bonus: "The flat Clarity bonus, F(L) = 2L.",
	"+": "Adds its parts together.",
	"-": "The first part minus the second.",
	"*": "Multiplies its parts.",
	floor_div: "Divides and rounds down.",
	min: "The smaller of its parts.",
	max: "The larger of its parts.",
	by_cut: "Multiplies by the Cut multiplier, 1.00 to 2.00, and rounds down.",
	damage: "Damage, mitigated by the target's block.",
	block_effect: "Block for the recipient.",
	heal: "Health, capped at the recipient's maximum.",
	gold: "Gold, within the battle allowance.",
	poison: "Poison stacks, capped at 12.",
	stun: "Stun. Bosses resist it through Resolve.",
	remove_block: "Strips block without dealing damage.",
};

const clamp = (value, low, high) => Math.min(high, Math.max(low, value));
const isWhole = (value) => typeof value === "number" && Number.isFinite(value) && Math.floor(value) === value;

export const hasRule = (definition) =>
	Boolean(definition && typeof definition.rule === "object" && definition.rule && Object.keys(definition.rule).length);

// --- validation ---------------------------------------------------------------

export function validate(rule) {
	if (!rule || typeof rule !== "object" || Array.isArray(rule)) return ["rule must be an object"];
	const errors = [];
	for (const field of Object.keys(rule))
		if (!["trigger", "effects"].includes(field)) errors.push(`unknown rule field: ${field}`);
	errors.push(...validateTrigger(rule.trigger || {}));
	if (!Array.isArray(rule.effects) || !rule.effects.length) {
		errors.push("a rule needs at least one effect");
		return errors;
	}
	if (rule.effects.length > MAX_EFFECTS) errors.push(`a rule may carry at most ${MAX_EFFECTS} effects`);
	rule.effects.slice(0, MAX_EFFECTS).forEach((effect, index) => errors.push(...validateEffect(effect, index)));
	if (nodeCount(rule) > MAX_NODES) errors.push(`too many parts; keep it to ${MAX_NODES}`);
	return errors;
}

function validateTrigger(trigger) {
	if (!trigger || typeof trigger !== "object") return ["trigger must be an object"];
	const kind = String(trigger.kind || "");
	if (!TRIGGERS.includes(kind)) return [`unknown trigger: ${kind || "(none)"}`];
	const errors = [];
	if (kind === "straight" && trigger.length !== "by_clarity")
		errors.push(...validateExpression(trigger.length, "trigger length", 1));
	if (kind === "parity") {
		if (!["even", "odd"].includes(String(trigger.parity))) errors.push("trigger parity must be even or odd");
		errors.push(...validateExpression(trigger.at_least, "trigger count", 1));
	}
	if (kind === "distinct") errors.push(...validateExpression(trigger.at_least, "trigger count", 1));
	if (kind === "value" && (!isWhole(trigger.value) || trigger.value < 1 || trigger.value > 20))
		errors.push("trigger value must be a die value from 1 to 20");
	if (["total_at_least", "total_at_most", "high_at_least"].includes(kind))
		errors.push(...validateExpression(trigger.amount, "trigger threshold", 1));
	return errors;
}

function validateEffect(effect, index) {
	const where = `effect ${index + 1}`;
	if (!effect || typeof effect !== "object") return [`${where} must be an object`];
	const errors = [];
	for (const field of Object.keys(effect))
		if (!["kind", "target", "amount", "scale", "repeat", "target_limit"].includes(field))
			errors.push(`${where}: unknown field ${field}`);
	if (!EFFECT_KINDS.includes(String(effect.kind))) errors.push(`${where}: unknown effect kind ${effect.kind ?? "(none)"}`);
	if (!EFFECT_TARGETS.includes(String(effect.target ?? "self"))) errors.push(`${where}: unknown target ${effect.target}`);
	if (!["carat", "none"].includes(String(effect.scale ?? "carat"))) errors.push(`${where}: scale must be carat or none`);
	errors.push(...validateExpression(effect.amount, `${where} amount`, 1));
	if ("repeat" in effect) errors.push(...validateExpression(effect.repeat, `${where} repeat`, 1));
	if ("target_limit" in effect) errors.push(...validateExpression(effect.target_limit, `${where} target limit`, 1));
	return errors;
}

function validateExpression(expression, where, depth) {
	if (depth > MAX_DEPTH) return [`${where}: nested too deeply (limit ${MAX_DEPTH})`];
	if (!expression || typeof expression !== "object" || Array.isArray(expression) || !Object.keys(expression).length)
		return [`${where}: must be a number, a term, a rank or an operation`];
	if ("const" in expression)
		return isWhole(expression.const) && Math.abs(expression.const) <= VALUE_LIMIT ? []
			: [`${where}: a constant must be a whole number within ±${VALUE_LIMIT}`];
	if ("rank" in expression)
		return RANKS.includes(String(expression.rank)) ? [] : [`${where}: unknown rank ${expression.rank}`];
	if ("term" in expression) {
		const term = String(expression.term);
		if (!TERMS.includes(term)) return [`${where}: unknown term ${term}`];
		if (["highest_sum", "lowest_sum"].includes(term)) return validateExpression(expression.count, `${where} count`, depth + 1);
		if (term === "count_value")
			return isWhole(expression.value) && expression.value >= 1 && expression.value <= 20 ? []
				: [`${where}: count_value needs a die value from 1 to 20`];
		return [];
	}
	if ("op" in expression) {
		const operator = String(expression.op);
		if (!OPERATORS.includes(operator)) return [`${where}: unknown operator ${operator}`];
		const args = expression.args;
		if (!Array.isArray(args) || !args.length || args.length > 4) return [`${where}: ${operator} needs one to four arguments`];
		if (operator === "by_cut" && args.length !== 1) return [`${where}: by_cut takes exactly one argument`];
		if (["-", "floor_div"].includes(operator) && args.length !== 2) return [`${where}: ${operator} takes exactly two arguments`];
		return args.flatMap((argument) => validateExpression(argument, where, depth + 1));
	}
	return [`${where}: must be a number, a term, a rank or an operation`];
}

export function nodeCount(expression) {
	if (!expression || typeof expression !== "object") return 0;
	let count = 1;
	for (const argument of expression.args || []) count += nodeCount(argument);
	if (expression.count) count += nodeCount(expression.count);
	if (expression.trigger) count += nodeCount(expression.trigger);
	for (const effect of expression.effects || []) count += nodeCount(effect);
	if (expression.amount) count += nodeCount(expression.amount);
	return count;
}

// --- evaluation ---------------------------------------------------------------

/** The hand, worked out once, in the shape the interpreter reads. */
export function buildContext(values, { carat = 1, cut = 1, clarity = 1, block = 0 } = {}) {
	const hand = values
		.map((value, index) => ({ value: Number(value), die_id: `d${index}` }))
		.filter((roll) => Number.isFinite(roll.value))
		.sort((a, b) => (a.value === b.value ? (a.die_id < b.die_id ? -1 : 1) : a.value - b.value));
	const groups = {};
	let total = 0;
	for (const roll of hand) {
		(groups[roll.value] = groups[roll.value] || []).push(roll.die_id);
		total += roll.value;
	}
	return {
		hand, groups, total,
		high: hand.length ? hand[hand.length - 1].value : 0,
		carat, cut, clarity, block,
		straight_length: 5 - Math.trunc((clarity - 1) / 2),
		selected: [], run: [],
	};
}

export function evaluate(rule, context) {
	const trigger = fire(rule.trigger || {}, context);
	const output = { active: trigger.active, selected: trigger.selected.slice(), effects: [] };
	if (!trigger.active) return output;
	const working = { ...context, run: trigger.run || [], selected: output.selected };
	for (const effect of rule.effects || []) {
		const repeat = clamp(value(effect.repeat ?? { const: 1 }, working), 0, MAX_REPEAT);
		for (let hit = 0; hit < repeat; hit++) {
			const amount = scaled(value(effect.amount ?? { const: 0 }, working), String(effect.scale ?? "carat"), working.carat);
			const built = { kind: String(effect.kind), amount: Math.max(0, amount), target: String(effect.target ?? "self") };
			if ("target_limit" in effect) built.target_limit = Math.max(1, value(effect.target_limit, working));
			output.effects.push(built);
		}
	}
	output.selected = working.selected;
	return output;
}

const scaled = (amount, scale, carat) =>
	scale === "none" ? amount : Math.floor((amount * (clamp(carat, 1, 24) + 7)) / 8);

function matching(groups, count) {
	return Object.keys(groups).map(Number).filter((key) => groups[key].length >= count).sort((a, b) => a - b);
}

function straightRun(groups, length) {
	const distinct = Object.keys(groups).map(Number).sort((a, b) => a - b);
	let chosen = [];
	for (const start of distinct) {
		const candidate = [];
		for (let offset = 0; offset < length; offset++) if (groups[start + offset]) candidate.push(start + offset);
		if (candidate.length === length) chosen = candidate;
	}
	return chosen;
}

function fire(trigger, context) {
	const groups = context.groups || {};
	const kind = String(trigger.kind || "always");
	const all = () => context.hand.map((roll) => roll.die_id);
	switch (kind) {
		case "always":
			return { active: true, selected: [] };
		case "pair":
		case "triple": {
			const wanted = kind === "pair" ? 2 : 3;
			const matches = matching(groups, wanted);
			if (!matches.length) return { active: false, selected: [] };
			return { active: true, selected: groups[matches[matches.length - 1]].slice(0, wanted) };
		}
		case "two_pairs": {
			const pairs = matching(groups, 2);
			if (pairs.length < 2) return { active: false, selected: [] };
			return { active: true, selected: [...groups[pairs[pairs.length - 1]].slice(0, 2), ...groups[pairs[pairs.length - 2]].slice(0, 2)] };
		}
		case "full_house": {
			const triples = matching(groups, 3);
			if (!triples.length) return { active: false, selected: [] };
			const top = triples[triples.length - 1];
			for (const paired of matching(groups, 2))
				if (paired !== top) return { active: true, selected: [...groups[top].slice(0, 3), ...groups[paired].slice(0, 2)] };
			return { active: false, selected: [] };
		}
		case "straight": {
			const length = trigger.length === "by_clarity" ? context.straight_length : value(trigger.length ?? { const: 3 }, context);
			const run = straightRun(groups, clamp(length, 1, 5));
			if (!run.length) return { active: false, selected: [] };
			return { active: true, selected: run.map((found) => groups[found][0]), run };
		}
		case "parity": {
			const wantedOdd = String(trigger.parity ?? "even") === "odd";
			const chosen = context.hand.filter((roll) => (roll.value % 2 === 1) === wantedOdd).map((roll) => roll.die_id);
			return { active: chosen.length >= value(trigger.at_least ?? { const: 3 }, context), selected: chosen };
		}
		case "distinct": {
			const chosen = Object.values(groups).map((ids) => ids[0]);
			return { active: Object.keys(groups).length >= value(trigger.at_least ?? { const: 5 }, context), selected: chosen };
		}
		case "value": {
			const found = groups[Number(trigger.value ?? 7)] || [];
			return { active: Boolean(found.length), selected: found.slice() };
		}
		case "total_at_least":
			return { active: context.total >= value(trigger.amount ?? { const: 0 }, context), selected: all() };
		case "total_at_most":
			return { active: context.total <= value(trigger.amount ?? { const: 0 }, context), selected: all() };
		case "high_at_least":
			return {
				active: context.high >= value(trigger.amount ?? { const: 0 }, context),
				selected: (groups[context.high] || []).slice(0, 1),
			};
	}
	return { active: false, selected: [] };
}

export function value(expression, context, depth = 0) {
	if (depth > MAX_DEPTH || !expression || typeof expression !== "object") return 0;
	if ("const" in expression) return clamp(Math.trunc(expression.const), -VALUE_LIMIT, VALUE_LIMIT);
	if ("rank" in expression) {
		switch (String(expression.rank)) {
			case "carat": return context.carat;
			case "cut": return context.cut;
			case "clarity": return context.clarity;
			case "clarity_bonus": return 2 * context.clarity;
		}
		return 0;
	}
	if ("term" in expression) return term(expression, context, depth);
	if ("op" in expression) {
		const values = (expression.args || []).map((argument) => value(argument, context, depth + 1));
		if (!values.length) return 0;
		switch (String(expression.op)) {
			case "+": return clamp(values.reduce((sum, item) => sum + item, 0), -VALUE_LIMIT, VALUE_LIMIT);
			case "-": return clamp(values[0] - values[1], -VALUE_LIMIT, VALUE_LIMIT);
			case "*": return values.reduce((product, item) => clamp(product * item, -VALUE_LIMIT, VALUE_LIMIT), 1);
			case "floor_div": return values[1] === 0 ? 0 : Math.floor(values[0] / values[1]);
			case "min": return Math.min(...values);
			case "max": return Math.max(...values);
			case "by_cut": return Math.floor((values[0] * (clamp(context.cut, 1, 5) + 3)) / 4);
		}
	}
	return 0;
}

function term(expression, context, depth) {
	const hand = context.hand || [];
	const groups = context.groups || {};
	const selected = context.selected || [];
	switch (String(expression.term)) {
		case "high": return context.high;
		case "low": return hand.length ? hand[0].value : 0;
		case "total": return context.total;
		case "pair_value": {
			const pairs = matching(groups, 2);
			return pairs.length ? pairs[pairs.length - 1] : 0;
		}
		case "triple_value": {
			const triples = matching(groups, 3);
			return triples.length ? triples[triples.length - 1] : 0;
		}
		case "run_high": return (context.run || []).length ? context.run[context.run.length - 1] : 0;
		case "highest_sum":
		case "lowest_sum": {
			const count = clamp(value(expression.count ?? { const: 1 }, context, depth + 1), 0, hand.length);
			const slice = String(expression.term) === "highest_sum" ? hand.slice(hand.length - count) : hand.slice(0, count);
			let sum = 0;
			for (const roll of slice) {
				sum += roll.value;
				if (!selected.includes(roll.die_id)) selected.push(roll.die_id);
			}
			return sum;
		}
		case "lowest_odd": {
			const found = hand.find((roll) => roll.value % 2 === 1);
			return found ? found.value : 0;
		}
		case "count_even": return hand.filter((roll) => roll.value % 2 === 0).length;
		case "count_odd": return hand.filter((roll) => roll.value % 2 === 1).length;
		case "count_distinct": return Object.keys(groups).length;
		case "count_value": return (groups[Number(expression.value ?? 7)] || []).length;
		case "block": return context.block || 0;
	}
	return 0;
}

// --- saying it in words -------------------------------------------------------

export const VERBS = { damage: "Damage", block: "Block", heal: "Heal", gold: "Gain", poison: "Apply", stun: "Apply", remove_block: "Remove" };
const NOUNS = { gold: " gold", poison: " Poison", stun: " stun", remove_block: " block" };
export const WHERE = { self: "self", enemy: "target", enemies: "all enemies", ally: "every living hero", other_allies: "your allies" };
const TERM_WORDS = {
	high: "H", low: "the lowest die", total: "the total", pair_value: "the pair value",
	triple_value: "the triple value", run_high: "the run's highest value", lowest_odd: "the lowest odd die",
	count_even: "the even count", count_odd: "the odd count", count_distinct: "the distinct count", block: "current block",
};

const compound = (expression) =>
	Boolean(expression && typeof expression === "object" && "op" in expression && (expression.args || []).length > 1);

export function say(expression) {
	if (!expression || typeof expression !== "object") return "0";
	if ("const" in expression) return String(Math.trunc(expression.const));
	if ("rank" in expression)
		return { carat: "C", cut: "K", clarity: "L", clarity_bonus: "F(L)" }[String(expression.rank)] || "0";
	if ("term" in expression) {
		const name = String(expression.term);
		if (["highest_sum", "lowest_sum"].includes(name))
			return `the ${name === "highest_sum" ? "highest" : "lowest"} ${say(expression.count ?? { const: 1 })} dice`;
		if (name === "count_value") return `how many ${Number(expression.value ?? 7)}s`;
		return TERM_WORDS[name] || name;
	}
	if ("op" in expression) {
		const parts = (expression.args || []).map((argument) =>
			compound(argument) && String(expression.op) !== "+" ? `(${say(argument)})` : say(argument));
		switch (String(expression.op)) {
			case "+": return parts.join(" + ");
			case "-": return parts.join(" − ");
			case "*": return parts.join(" × ");
			case "floor_div": return parts.length > 1 ? `floor(${parts[0]} / ${parts[1]})` : parts[0];
			case "min": return `the lower of ${parts.join(" and ")}`;
			case "max": return `the higher of ${parts.join(" and ")}`;
			case "by_cut": return `${parts[0]} × M(K)`;
		}
	}
	return "0";
}

export function describe(rule) {
	const sentences = [];
	for (const effect of (rule && rule.effects) || []) {
		if (!effect || typeof effect !== "object") continue;
		let amount = say(effect.amount);
		if (String(effect.scale ?? "carat") === "carat")
			amount = `${compound(effect.amount) ? `(${amount})` : amount} × M(C)`;
		const repeat = "repeat" in effect ? `, ${say(effect.repeat)} times` : "";
		const limit = "target_limit" in effect ? `, up to ${say(effect.target_limit)} of them` : "";
		const target = String(effect.target ?? "self");
		const where = target === "self" ? "" : ` to ${WHERE[target] || target}`;
		sentences.push(`${VERBS[String(effect.kind)] || "Apply"} ${amount}${NOUNS[String(effect.kind)] || ""}${where}${limit}${repeat}.`);
	}
	return sentences.join(" ");
}

export function describeTrigger(trigger) {
	if (!trigger || typeof trigger !== "object") return "Always";
	switch (String(trigger.kind || "always")) {
		case "always": return "Always";
		case "pair": return "Any pair";
		case "two_pairs": return "Two distinct pairs";
		case "triple": return "At least three matching values";
		case "full_house": return "Three of one value and two of another";
		case "straight": return trigger.length === "by_clarity"
			? "Straight: 5 at L1–2; 4 at L3–4; 3 at L5" : `Straight of ${say(trigger.length ?? { const: 3 })}`;
		case "parity": return `At least ${say(trigger.at_least ?? { const: 3 })} ${trigger.parity ?? "even"} results`;
		case "distinct": return `At least ${say(trigger.at_least ?? { const: 5 })} distinct results`;
		case "value": return `At least one ${Number(trigger.value ?? 7)}`;
		case "total_at_least": return `Total ≥ ${say(trigger.amount ?? { const: 0 })}`;
		case "total_at_most": return `Total ≤ ${say(trigger.amount ?? { const: 0 })}`;
		case "high_at_least": return `Highest die ≥ ${say(trigger.amount ?? { const: 0 })}`;
	}
	return "Always";
}

// --- starting points ----------------------------------------------------------

const clone = (value) => JSON.parse(JSON.stringify(value));

/** Shipped rules rewritten in the language, as somewhere to start rather than a blank page. */
const SOURCES = {
	STRIKE: { trigger: { kind: "always" }, effects: [{ kind: "damage", target: "enemy",
		amount: { op: "+", args: [{ term: "highest_sum", count: { rank: "cut" } }, { rank: "clarity_bonus" }] } }] },
	BLOCK: { trigger: { kind: "pair" }, effects: [{ kind: "block", target: "self",
		amount: { op: "+", args: [{ op: "*", args: [{ term: "pair_value" }, { rank: "cut" }] }, { rank: "clarity_bonus" }] } }] },
	HEAL: { trigger: { kind: "always" }, effects: [{ kind: "heal", target: "self",
		amount: { op: "+", args: [{ term: "lowest_sum", count: { rank: "cut" } }, { rank: "clarity_bonus" }] } }] },
	HEAVYSTRIKE: { trigger: { kind: "triple" }, effects: [{ kind: "damage", target: "enemy",
		amount: { op: "+", args: [{ op: "*", args: [{ term: "triple_value" }, { rank: "cut" }] }, { rank: "clarity_bonus" }] } }] },
	INTERPOSE: { trigger: { kind: "pair" }, effects: [{ kind: "block", target: "ally",
		amount: { op: "+", args: [{ term: "pair_value" }, { rank: "cut" }, { const: -1 }, { rank: "clarity_bonus" }] } }] },
	MEND: { trigger: { kind: "parity", parity: "odd", at_least: { const: 3 } }, effects: [{ kind: "heal", target: "ally",
		amount: { op: "+", args: [{ term: "lowest_odd" }, { op: "*", args: [{ const: 2 }, { op: "-", args: [{ rank: "cut" }, { const: 1 }] }] }, { rank: "clarity_bonus" }] } }] },
	SUNDER: { trigger: { kind: "two_pairs" }, effects: [
		{ kind: "remove_block", target: "enemy", amount: { op: "+", args: [{ op: "*", args: [{ const: 2 }, { rank: "cut" }] }, { rank: "clarity_bonus" }] } },
		{ kind: "damage", target: "enemy", amount: { op: "+", args: [{ term: "pair_value" }, { rank: "clarity_bonus" }] } }] },
	ARC_BURST: { trigger: { kind: "straight", length: { const: 3 } }, effects: [{ kind: "damage", target: "enemies",
		amount: { op: "+", args: [{ term: "run_high" }, { rank: "clarity_bonus" }] },
		target_limit: { op: "+", args: [{ rank: "cut" }, { const: 1 }] } }] },
	MULTISTRIKE: { trigger: { kind: "straight", length: "by_clarity" }, effects: [{ kind: "damage", target: "enemy",
		amount: { const: 4 }, repeat: { rank: "cut" } }] },
	BLESSING: { trigger: { kind: "straight", length: { const: 3 } }, effects: [
		{ kind: "gold", target: "self", amount: { const: 3 } },
		{ kind: "heal", target: "self", amount: { op: "+", args: [{ rank: "cut" }, { rank: "clarity_bonus" }] } }] },
	EVEN_TEMPO: { trigger: { kind: "parity", parity: "even", at_least: { const: 3 } }, effects: [
		{ kind: "block", target: "self", amount: { op: "+", args: [{ op: "*", args: [{ term: "count_even" }, { rank: "cut" }] }, { rank: "clarity_bonus" }] } },
		{ kind: "damage", target: "enemy", amount: { op: "+", args: [{ rank: "cut" }, { rank: "clarity_bonus" }] } }] },
	PRECISION: { trigger: { kind: "distinct", at_least: { const: 5 } }, effects: [{ kind: "damage", target: "enemy",
		amount: { op: "+", args: [{ term: "lowest_sum", count: { const: 2 } }, { op: "*", args: [{ const: 2 }, { rank: "cut" }] }, { rank: "clarity_bonus" }] } }] },
	VENOM: { trigger: { kind: "high_at_least", amount: { op: "-", args: [{ const: 13 }, { rank: "clarity" }] } }, effects: [
		{ kind: "damage", target: "enemy", amount: { op: "+", args: [{ op: "floor_div", args: [{ term: "high" }, { const: 2 }] }, { rank: "clarity_bonus" }] } },
		{ kind: "poison", target: "enemy", scale: "none",
			amount: { op: "+", args: [{ rank: "cut" }, { op: "floor_div", args: [{ op: "+", args: [{ rank: "carat" }, { const: 3 }] }, { const: 4 }] }] } }] },
	DRAINSTRIKE: { trigger: { kind: "total_at_least", amount: { op: "-", args: [{ const: 45 }, { op: "*", args: [{ const: 5 }, { rank: "clarity" }] }] } }, effects: [
		{ kind: "damage", target: "enemy", amount: { op: "+", args: [{ op: "floor_div", args: [{ op: "*", args: [{ term: "high" }, { op: "+", args: [{ rank: "cut" }, { const: 1 }] }] }, { const: 2 }] }, { rank: "clarity_bonus" }] } },
		{ kind: "heal", target: "self", amount: { rank: "clarity_bonus" } }] },
	STUN: { trigger: { kind: "high_at_least", amount: { op: "-", args: [{ const: 21 }, { rank: "clarity" }] } }, effects: [
		{ kind: "damage", target: "enemy", amount: { op: "+", args: [{ term: "high" }, { rank: "clarity_bonus" }] } },
		{ kind: "stun", target: "enemy", scale: "none", amount: { const: 1 } }] },
	BLANK: { trigger: { kind: "always" }, effects: [{ kind: "damage", target: "enemy",
		amount: { op: "+", args: [{ term: "high" }, { rank: "clarity_bonus" }] } }] },
};

export const TEMPLATE_KEYS = Object.keys(SOURCES);
export const template = (key) => clone(SOURCES[key] || SOURCES.BLANK);

/** A fresh node of the given kind, for the “add a part” buttons. */
export function blankNode(kind) {
	switch (kind) {
		case "term": return { term: "high" };
		case "rank": return { rank: "clarity_bonus" };
		case "op": return { op: "+", args: [{ term: "high" }, { rank: "clarity_bonus" }] };
	}
	return { const: 1 };
}

export const nodeKind = (expression) =>
	!expression || typeof expression !== "object" ? "const"
		: "op" in expression ? "op" : "term" in expression ? "term" : "rank" in expression ? "rank" : "const";
