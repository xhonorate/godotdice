// Writing a gem's rule, and watching it fire.
//
// Two pieces: the editor, which is a typed tree of dropdowns over the same shape the
// engine reads, and the bench, which runs that rule on a hand you can change and shows
// what it would actually do. Neither one knows any rule of its own — the vocabulary comes
// from `rules.js`, which is the studio's copy of the engine's interpreter, and every
// dropdown is filled from it, so the panel cannot offer a term the game would reject.

import { el, clamp, titleCase } from "./dom.js";
import * as Rules from "./rules.js";

const NODE_KINDS = [["const", "a number"], ["term", "something in the hand"], ["rank", "one of the gem's ranks"], ["op", "an operation"]];
const TRIGGER_LABELS = {
	always: "Always", pair: "Any pair", two_pairs: "Two pairs", triple: "Three of a kind",
	full_house: "Full house", straight: "A straight", parity: "Even or odd count",
	distinct: "Distinct values", value: "A particular number", total_at_least: "Total at least",
	total_at_most: "Total at most", high_at_least: "Highest die at least",
};
const EFFECT_LABELS = {
	damage: "Deal damage", block: "Give block", heal: "Heal", gold: "Give ore",
	poison: "Apply poison", stun: "Apply stun", remove_block: "Strip block",
};
const TARGET_LABELS = {
	self: "the caster", enemy: "one enemy", enemies: "several enemies",
	ally: "every living hero", other_allies: "the caster's allies",
};

/**
 * The rule editor. `onChange` is handed the whole rule back, so the caller decides how a
 * change is recorded — the studio funnels it through the same undo stack as every field.
 */
export function ruleEditor(definition, onChange) {
	const rule = definition.rule;
	const write = (mutate) => {
		const next = JSON.parse(JSON.stringify(rule));
		mutate(next);
		onChange(next);
	};
	const errors = Rules.validate(rule);
	return el("div", { class: "rule" }, [
		el("div", { class: "rule-head" }, [
			el("span", { class: "muted small", text: "Starting point" }),
			el("select", {
				onchange: (event) => {
					if (event.target.value) onChange(Rules.template(event.target.value));
				},
			}, [el("option", { value: "" }, "Replace with…"),
				...Rules.TEMPLATE_KEYS.map((key) => el("option", { value: key }, key === "BLANK" ? "An empty rule" : titleCase(key)))]),
			el("div", { class: "grow" }),
			el("button", { class: "ghost small danger", onclick: () => onChange(null) }, "Borrow a rule instead"),
		]),
		el("div", { class: "rule-section" }, [
			el("h4", { text: "Fires when" }),
			triggerEditor(rule.trigger || { kind: "always" }, (trigger) => write((next) => {
				next.trigger = trigger;
			})),
		]),
		el("div", { class: "rule-section" }, [
			el("h4", { text: `Then${(rule.effects || []).length > 1 ? ", in order" : ""}` }),
			...(rule.effects || []).map((effect, index) => effectEditor(effect, index, (rule.effects || []).length, write)),
			(rule.effects || []).length < Rules.MAX_EFFECTS
				? el("button", {
					class: "ghost small",
					onclick: () => write((next) => {
						next.effects = [...(next.effects || []), { kind: "damage", target: "enemy", amount: { rank: "clarity_bonus" } }];
					}),
				}, "+ Add an effect")
				: null,
		]),
		el("div", { class: "rule-reads" }, [
			el("p", { class: "trigger", text: Rules.describeTrigger(rule.trigger) }),
			el("p", { class: "formula", text: Rules.describe(rule) || "—" }),
			el("div", { class: "row-inline wrap tight" }, [
				el("button", {
					class: "ghost small",
					onclick: () => onChange(rule, { trigger: Rules.describeTrigger(rule.trigger), formula: Rules.describe(rule) }),
				}, "Write this into the gem's rules text"),
			]),
		]),
		errors.length
			? el("div", { class: "rule-errors" }, errors.map((error) => el("p", { class: "field-issue", text: error })))
			: null,
	]);
}

function triggerEditor(trigger, onChange) {
	const kind = String(trigger.kind || "always");
	const rows = [el("div", { class: "row-inline wrap" }, [
		el("select", {
			onchange: (event) => onChange(blankTrigger(event.target.value)),
		}, Rules.TRIGGERS.map((option) => el("option", { value: option, selected: option === kind }, TRIGGER_LABELS[option] || option))),
		el("span", { class: "muted small", text: Rules.HINTS[kind] || "" }),
	])];
	const set = (field, value) => onChange({ ...trigger, [field]: value });
	if (kind === "straight")
		rows.push(el("div", { class: "row-inline wrap" }, [
			el("label", { class: "switch" }, [
				el("input", {
					type: "checkbox", checked: trigger.length === "by_clarity",
					onchange: (event) => set("length", event.target.checked ? "by_clarity" : { const: 3 }),
				}),
				el("span", { text: "Clarity shortens it (5 at L1–2, 4 at L3–4, 3 at L5)" }),
			]),
			trigger.length === "by_clarity" ? null : expressionEditor(trigger.length ?? { const: 3 }, (next) => set("length", next), "Length"),
		]));
	if (kind === "parity")
		rows.push(el("div", { class: "row-inline wrap" }, [
			el("select", {
				onchange: (event) => set("parity", event.target.value),
			}, ["even", "odd"].map((option) => el("option", { value: option, selected: option === trigger.parity }, option))),
			expressionEditor(trigger.at_least ?? { const: 3 }, (next) => set("at_least", next), "At least"),
		]));
	if (kind === "distinct")
		rows.push(expressionEditor(trigger.at_least ?? { const: 5 }, (next) => set("at_least", next), "At least"));
	if (kind === "value")
		rows.push(el("label", { class: "rank" }, [
			el("span", { text: "Die value" }),
			el("input", {
				type: "number", min: 1, max: 20, value: trigger.value ?? 7,
				onchange: (event) => set("value", clamp(Math.round(Number(event.target.value)), 1, 20)),
			}),
		]));
	if (["total_at_least", "total_at_most", "high_at_least"].includes(kind))
		rows.push(expressionEditor(trigger.amount ?? { const: 0 }, (next) => set("amount", next), "Threshold"));
	return el("div", { class: "stack" }, rows);
}

function blankTrigger(kind) {
	switch (kind) {
		case "straight": return { kind, length: "by_clarity" };
		case "parity": return { kind, parity: "even", at_least: { const: 3 } };
		case "distinct": return { kind, at_least: { const: 5 } };
		case "value": return { kind, value: 7 };
		case "total_at_least": return { kind, amount: { const: 30 } };
		case "total_at_most": return { kind, amount: { const: 20 } };
		case "high_at_least": return { kind, amount: { const: 13 } };
	}
	return { kind };
}

function effectEditor(effect, index, count, write) {
	const set = (field, value) => write((next) => {
		next.effects[index] = { ...next.effects[index], [field]: value };
	});
	const drop = (field) => write((next) => {
		const copy = { ...next.effects[index] };
		delete copy[field];
		next.effects[index] = copy;
	});
	const kind = String(effect.kind || "damage");
	return el("div", { class: "effect" }, [
		el("div", { class: "row-inline wrap" }, [
			el("span", { class: "effect-number", text: String(index + 1) }),
			el("select", {
				onchange: (event) => set("kind", event.target.value),
			}, Rules.EFFECT_KINDS.map((option) => el("option", { value: option, selected: option === kind }, EFFECT_LABELS[option] || option))),
			el("span", { class: "muted small", text: "to" }),
			el("select", {
				onchange: (event) => set("target", event.target.value),
			}, Rules.EFFECT_TARGETS.map((option) => el("option", { value: option, selected: option === String(effect.target ?? "self") }, TARGET_LABELS[option] || option))),
			el("div", { class: "grow" }),
			count > 1 ? el("button", {
				class: "x", title: "Remove this effect",
				onclick: () => write((next) => {
					next.effects.splice(index, 1);
				}),
			}, "×") : null,
		]),
		el("div", { class: "effect-body" }, [
			expressionEditor(effect.amount ?? { const: 0 }, (next) => set("amount", next), "Amount"),
			el("div", { class: "row-inline wrap tight" }, [
				el("label", { class: "switch small" }, [
					el("input", {
						type: "checkbox", checked: String(effect.scale ?? "carat") === "carat",
						onchange: (event) => set("scale", event.target.checked ? "carat" : "none"),
					}),
					el("span", { text: "Carat multiplies this" }),
				]),
				"repeat" in effect
					? el("span", { class: "sub-field" }, [expressionEditor(effect.repeat, (next) => set("repeat", next), "Repeat"),
						el("button", { class: "x", onclick: () => drop("repeat") }, "×")])
					: el("button", { class: "ghost small", onclick: () => set("repeat", { rank: "cut" }) }, "+ Repeat it"),
				"target_limit" in effect
					? el("span", { class: "sub-field" }, [expressionEditor(effect.target_limit, (next) => set("target_limit", next), "At most"),
						el("button", { class: "x", onclick: () => drop("target_limit") }, "×")])
					: (String(effect.target) === "enemies"
						? el("button", { class: "ghost small", onclick: () => set("target_limit", { op: "+", args: [{ rank: "cut" }, { const: 1 }] }) }, "+ Limit the targets")
						: null),
			]),
		]),
	]);
}

/** One node of the amount tree, and its children under it. */
function expressionEditor(expression, onChange, label = "", depth = 0) {
	const kind = Rules.nodeKind(expression);
	const head = el("div", { class: "expr-head" }, [
		label ? el("span", { class: "expr-label", text: label }) : null,
		el("select", {
			class: "expr-kind",
			onchange: (event) => onChange(Rules.blankNode(event.target.value)),
		}, NODE_KINDS.map(([option, text]) => el("option", { value: option, selected: option === kind }, text))),
	]);
	if (kind === "const")
		head.append(el("input", {
			type: "number", class: "expr-number", value: expression.const ?? 0,
			onchange: (event) => onChange({ const: clamp(Math.round(Number(event.target.value)), -Rules.VALUE_LIMIT, Rules.VALUE_LIMIT) }),
		}));
	if (kind === "rank")
		head.append(el("select", {
			onchange: (event) => onChange({ rank: event.target.value }),
		}, Rules.RANKS.map((option) => el("option", { value: option, selected: option === expression.rank },
			option === "clarity_bonus" ? "Clarity bonus F(L)" : titleCase(option)))));
	if (kind === "term") {
		head.append(el("select", {
			onchange: (event) => onChange(termNode(event.target.value, expression)),
		}, Rules.TERMS.map((option) => el("option", { value: option, selected: option === expression.term }, titleCase(option)))));
		if (expression.term === "count_value")
			head.append(el("input", {
				type: "number", class: "expr-number", min: 1, max: 20, value: expression.value ?? 7,
				onchange: (event) => onChange({ ...expression, value: clamp(Math.round(Number(event.target.value)), 1, 20) }),
			}));
	}
	if (kind === "op")
		head.append(el("select", {
			onchange: (event) => onChange(operatorNode(event.target.value, expression)),
		}, Rules.OPERATORS.map((option) => el("option", { value: option, selected: option === expression.op },
			{ "+": "add", "-": "subtract", "*": "multiply", floor_div: "divide, rounded down", min: "the smaller of", max: "the larger of", by_cut: "× the Cut multiplier" }[option] || option))));
	head.append(el("span", { class: "muted small expr-hint", text: Rules.HINTS[expression.term || expression.rank || expression.op] || "" }));

	const rows = [head];
	if (kind === "term" && ["highest_sum", "lowest_sum"].includes(String(expression.term)))
		rows.push(el("div", { class: "expr-children" }, [
			expressionEditor(expression.count ?? { const: 1 }, (next) => onChange({ ...expression, count: next }), "How many", depth + 1),
		]));
	if (kind === "op") {
		const args = expression.args || [];
		const fixed = ["-", "floor_div"].includes(String(expression.op)) || String(expression.op) === "by_cut";
		rows.push(el("div", { class: "expr-children" }, [
			...args.map((argument, index) => el("div", { class: "expr-arg" }, [
				expressionEditor(argument, (next) => {
					const copy = args.slice();
					copy[index] = next;
					onChange({ ...expression, args: copy });
				}, "", depth + 1),
				!fixed && args.length > 1 ? el("button", {
					class: "x", title: "Remove this part",
					onclick: () => onChange({ ...expression, args: args.filter((_unused, position) => position !== index) }),
				}, "×") : null,
			])),
			!fixed && args.length < 4 && depth < Rules.MAX_DEPTH - 1
				? el("button", {
					class: "ghost small",
					onclick: () => onChange({ ...expression, args: [...args, { const: 1 }] }),
				}, "+ Add a part")
				: null,
		]));
	}
	return el("div", { class: `expr depth-${Math.min(depth, 3)}` }, rows);
}

const termNode = (name, previous) =>
	["highest_sum", "lowest_sum"].includes(name) ? { term: name, count: previous.count ?? { rank: "cut" } }
		: name === "count_value" ? { term: name, value: previous.value ?? 7 } : { term: name };

function operatorNode(operator, previous) {
	const args = (previous.args || []).slice();
	if (operator === "by_cut") return { op: operator, args: [args[0] || { const: 1 }] };
	if (["-", "floor_div"].includes(operator)) return { op: operator, args: [args[0] || { const: 1 }, args[1] || { const: 2 }] };
	return { op: operator, args: args.length ? args : [{ const: 1 }, { const: 1 }] };
}

// --- the bench ----------------------------------------------------------------

/**
 * Runs the rule on a hand you can change. This is the answer to "what does this gem
 * actually do", which no amount of reading the tree gives you.
 */
export function ruleBench(definition, hand, sample, onHand, dicePools = []) {
	const context = Rules.buildContext(hand, { ...sample, block: 12 });
	const result = Rules.evaluate(definition.rule, context);
	const used = new Set(result.selected);
	const inputs = hand.map((value, index) => el("input", {
		type: "number", min: 1, max: 20, value,
		class: `bench-die ${used.has(`d${index}`) ? "used" : ""}`,
		onchange: (event) => {
			const next = hand.slice();
			next[index] = clamp(Math.round(Number(event.target.value)), 1, 20);
			onHand(next);
		},
	}));
	return el("div", {}, [
		el("div", { class: "bench-hand" }, inputs),
		el("div", { class: "row-inline wrap tight" }, [
			el("span", { class: "muted small", text: "Roll:" }),
			...dicePools.map(({ label, faces }) => el("button", {
				class: "ghost small",
				onclick: () => onHand(faces.map((choices) => choices[Math.floor(Math.random() * choices.length)])),
			}, label)),
		]),
		el("p", { class: `bench-verdict ${result.active ? "on" : "off"}` },
			result.active ? `Fires · ${result.selected.length} ${result.selected.length === 1 ? "die" : "dice"} read` : "Does not fire on this hand"),
		result.active
			? el("div", { class: "stack" }, result.effects.map((effect) => el("div", { class: "bench-effect" }, [
				el("span", { class: `dot-kind ${effect.kind}` }),
				el("span", { class: "bench-amount", text: String(effect.amount) }),
				el("span", { class: "small", text: `${EFFECT_LABELS[effect.kind] || effect.kind} → ${TARGET_LABELS[effect.target] || effect.target}${effect.target_limit ? ` (up to ${effect.target_limit})` : ""}` }),
			])))
			: el("p", { class: "muted small", text: Rules.describeTrigger(definition.rule.trigger) }),
		el("p", { class: "muted small", text: `At Carat ${sample.carat}, Cut ${sample.cut}, Clarity ${sample.clarity}. Block is assumed to be 12 where the rule reads it.` }),
	]);
}
