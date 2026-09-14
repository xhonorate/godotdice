// What a gem says about itself, in the game's own words.
//
// A port of `scripts/ui/gem_text.gd` and the requirement strip from `scripts/ui/dice_icons.gd`.
// The chain it builds — terms that add up, one Carat multiplier over them, then the word for
// what they do — is the same structure `gem_panel.gd` lays out on the battlefield, branch for
// branch, so a gem judged in the studio reads exactly as it will read in a run. Nothing that
// contributes zero appears: Carat 1 multiplies by one and is dropped, Cut 1 likewise.

import { CUT_NAMES, CLARITY_NAMES, caratMultiplier, clarityBonus, cutMultiplier } from "./schema.js";
import * as Rules from "./rules.js";

const clamp = (value, low, high) => Math.min(high, Math.max(low, value));

/** Whole numbers stay whole; a multiplier keeps three decimals, as `GemText.number()` does. */
export function number(value) {
	return Math.abs(value - Math.round(value)) < 1e-9 ? String(Math.round(value)) : value.toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
}

const count = (amount, word, plural = "") => `${amount} ${amount === 1 ? word : plural || `${word}s`}`;

export const part = (glyph, text, tip, factor = null) => ({ glyph, text, tip, factor });

const cutFactor = (k) => (k <= 1 ? null : {
	glyph: "cut", text: `×${k}`,
	tip: `Cut ${k} (${CUT_NAMES[k - 1]}) multiplies the dice this reads.`,
});
const cutRatio = (k, value, note) => (Math.abs(value - 1) < 1e-9 ? null : {
	glyph: "cut", text: `×${number(value)}`,
	tip: `Cut ${k} (${CUT_NAMES[k - 1]}) ${note}.`,
});
const cutFlat = (k, value, note) => (value <= 0 ? null
	: part("cut", String(value), `Cut ${k} (${CUT_NAMES[k - 1]}) ${note}.`));

function clarityPart(stored, effective) {
	const bonus = clarityBonus(effective);
	let tip = `Clarity ${effective} (${CLARITY_NAMES[effective - 1]}) adds a flat ${bonus}, whatever you roll.`;
	if (effective !== stored) tip += ` A Focusing Prism is raising this gem from Clarity ${stored}.`;
	return part("clarity", String(bonus), tip);
}

const caratMark = (c) => (c <= 1 ? null : {
	glyph: "carat", text: `×${number(caratMultiplier(c))}`,
	tip: `Carat ${c} multiplies everything above by ${number(caratMultiplier(c))}.`,
});

const TONES = { damage: "RED", block: "BLUE", heal: "GREEN", gold: "GOLD", poison: "VIOLET", stun: "VIOLET", strip: "AMBER", revive: "GREEN",
	reroll: "WHITE", amplify: "WHITE", echo: "WHITE", upgrade: "WHITE", cleanse: "GREEN" };

const block = (verb, kind, label, parts, carat, suffix = "") => ({
	verb, kind, label, tone: TONES[kind] || "PAPER",
	parts: parts.filter(Boolean), mult: caratMark(carat), suffix, repeat: null, note: "",
});
const fixed = (verb, kind, label, text, tip, glyph = "", suffix = "") => ({
	verb, kind, label, tone: TONES[kind] || "PAPER",
	parts: [part(glyph, text, tip)], mult: null, suffix, repeat: null, note: "",
});

/** The rule a gem resolves through: its own written one, the one it borrows, or its key. */
export const ruleOf = (key, definition) =>
	Rules.hasRule(definition) ? "__rule__" : String((definition || {}).evaluator_id || key);

/**
 * One entry per effect the gem produces, in the order the engine resolves them.
 * @param tables the constants the rules build owns, handed over from the registry.
 */
export function blocks(key, definition, { carat = 1, cut = 1, clarity = 1, effective = 0 } = {}, tables = {}) {
	if (!definition) return [];
	const c = clamp(Math.round(carat), 1, 24);
	const k = clamp(Math.round(cut), 1, 5);
	const stored = clamp(Math.round(clarity), 1, 5);
	const l = effective > 0 ? clamp(effective, 1, 5) : stored;
	const flat = clarityPart(stored, l);
	const cutName = CUT_NAMES[k - 1];
	const hit = tables.multistrike_hit ?? 4;
	const blessing = tables.blessing_gold ?? 3;
	const wagerCeiling = tables.wager_ceiling ?? 24;
	const built = [];
	if (Rules.hasRule(definition)) return authored(definition.rule, c, k, stored, l);

	switch (ruleOf(key, definition)) {
		case "STRIKE":
			built.push(block("Deal", "damage", "damage", [
				part("high", k === 1 ? "highest die" : `highest ${k} dice`,
					k === 1 ? "Your single highest die." : `Your ${k} highest dice, added together.`),
				flat], c, "to your target"));
			break;
		case "BLOCK":
			built.push(block("Gain", "block", "block", [
				part("pair", "pair value", hint("pair"), cutFactor(k)), flat], c));
			break;
		case "INTERPOSE":
			built.push(block("Give every living hero", "block", "block", [
				part("pair", "pair value", hint("pair")),
				cutFlat(k, k - 1, "adds a little here: this gem reads one pair whatever its Cut"),
				flat], c));
			break;
		case "HEAL":
			built.push(block("Heal yourself for", "heal", "health", [
				part("low", k === 1 ? "lowest die" : `lowest ${k} dice`,
					k === 1 ? "Your single lowest die." : `Your ${k} lowest dice, added together.`),
				flat], c));
			break;
		case "MEND":
			built.push(block("Heal every living hero for", "heal", "health", [
				part("low", "lowest odd die", "The lowest odd result in your hand."),
				cutFlat(k, 2 * (k - 1), "adds a flat bonus here"),
				flat], c));
			break;
		case "MULTISTRIKE": {
			const multi = block("Deal", "damage", "damage", [
				part("", String(hit), `Every hit starts from a fixed ${hit}.`)], c, k === 1 ? "" : "per hit");
			multi.repeat = { glyph: "hit", text: count(k, "hit"),
				tip: `Cut ${k} (${cutName}) sets how many hits land. They all strike one fixed target.` };
			multi.note = "Clarity shortens the run this needs instead of adding a flat bonus.";
			built.push(multi);
			break;
		}
		case "LUCKYSTRIKE": {
			built.push(block("Deal", "damage", "damage", [
				part("", "7", "Every 7 in your hand strikes separately.", cutRatio(k, cutMultiplier(k), "multiplies each seven"))],
				c, "for every 7 you rolled"));
			const jackpot = l === 5 ? 7 : l + 1;
			const gold = fixed("Gain", "gold", "ore", String(c), `Carat ${c} sets the ore each 7 pays.`, "carat", "for every 7 you rolled");
			gold.note = `Three or more sevens multiply the ore by ${jackpot} at Clarity ${l} (${CLARITY_NAMES[l - 1]}). The damage is unaffected.`;
			built.push(gold);
			break;
		}
		case "HEAVYSTRIKE":
			built.push(block("Deal", "damage", "damage", [
				part("triple", "match value", hint("triple"), cutFactor(k)), flat], c, "to your target"));
			break;
		case "BLESSING":
			built.push(block("Gain", "gold", "ore", [
				part("", String(blessing), `A fixed ${blessing} before Carat.`)], c));
			built.push(block("Heal yourself for", "heal", "health", [
				cutFlat(k, k, "adds its rank straight into this heal"), flat], c));
			break;
		case "SHIELDBASH": {
			built.push(block("First gain", "block", "block", [flat], c));
			const bash = block("Then deal", "damage", "damage", [
				part("shield", "your block", hint("shield"), cutRatio(k, (k + 1) / 2, "multiplies the block you are standing behind"))],
				1, "to your target");
			bash.note = "Carat already grew the block above, so it is not applied a second time.";
			built.push(bash);
			if (l === 5) built.push(fixed("Apply", "stun", "stun", "1",
				"Flawless Clarity adds a stun this gem does not otherwise have.", "clarity"));
			break;
		}
		case "STUN":
			built.push(block("Deal", "damage", "damage", [part("high", "highest die", hint("high")), flat], c, "to your target"));
			built.push(fixed("Apply", "stun", "stun", k === 5 ? "2" : "1",
				k < 5 ? "Only a Perfect Cut lengthens this to two slots." : "A Perfect Cut doubles the skip.", "cut"));
			break;
		case "BULWARK": {
			const table = (tables.bulwark_block || [])[c - 1] ?? 0;
			const wall = fixed("Gain", "block", "block", String(table),
				`Bulwark reads a fixed Carat table instead of the usual multiplier. Carat ${c} grants ${table}.`, "carat");
			wall.note = "Clarity only widens the low total this needs; it adds nothing to the block.";
			built.push(wall);
			const selfStun = (tables.bulwark_stun || [])[k - 1] ?? 0;
			if (selfStun > 0) built.push(fixed("Then stun yourself for", "stun", selfStun === 1 ? "turn" : "turns",
				String(selfStun), `Cut ${k} (${cutName}) buys this down. A Perfect Cut removes it entirely.`, "cut"));
			break;
		}
		case "DRAINSTRIKE":
			built.push(block("Deal", "damage", "damage", [
				part("high", "highest die", hint("high"), cutRatio(k, (k + 1) / 2, "multiplies the high die")), flat], c, "to your target"));
			built.push(block("Heal yourself for", "heal", "health", [flat], c));
			break;
		case "SUNDER":
			built.push(block("Strip", "strip", "block", [
				cutFlat(k, 2 * k, "doubles into the block you tear off"), flat], c, "from your target"));
			built.push(block("Then deal", "damage", "damage", [
				part("pair", "pair value", hint("pair")), flat], c, "to your target"));
			break;
		case "ARC_BURST": {
			const arc = block("Deal", "damage", "damage", [part("run", "top of the run", hint("run")), flat], c, "each");
			arc.repeat = { glyph: "target", text: `to ${count(k + 1, "enemy", "enemies")}`,
				tip: `Cut ${k} (${cutName}) buys reach, not damage. Against a lone boss the extra targets are wasted.` };
			built.push(arc);
			break;
		}
		case "VENOM":
			built.push(block("Deal", "damage", "damage", [
				part("high", "half the highest die", "Half your highest die, rounded down."), flat], c, "to your target"));
			built.push(fixed("Apply", "poison", "poison", String(k + Math.ceil(c / 4)),
				`Cut ${k} (${cutName}) plus a quarter of Carat ${c}. Poison bypasses block and caps at 12 stacks.`, "cut"));
			break;
		case "EVEN_TEMPO":
			built.push(block("Gain", "block", "block", [
				part("count", "even dice", "How many of your five dice came up even.", cutFactor(k)), flat], c));
			built.push(block("Then deal", "damage", "damage", [
				cutFlat(k, k, "adds its rank straight into this hit"), flat], c, "to your target"));
			break;
		case "PRECISION":
			built.push(block("Deal", "damage", "damage", [
				part("low", "lowest two dice", "Your two lowest dice, added together."),
				cutFlat(k, 2 * k, "doubles into this hit"), flat], c, "to your target"));
			break;
		case "LIFELINE":
			built.push(block("Revive a downed hero at", "revive", "health", [
				cutFlat(k, 3 * k, "triples into the health a revival restores"), flat], c, "once per battle"));
			built.push(block("Otherwise heal every living hero for", "heal", "health", [
				cutFlat(k, k, "adds its rank straight into this heal"), flat], c));
			break;
		case "QUARTET": {
			const wanted = l === 5 ? 3 : 4;
			const quad = block("Deal", "damage", "damage", [
				part("triple", "match value", `The value shown by your ${wanted} matching dice.`,
					cutRatio(k, 2 * k, "doubles into the matched value")), flat], c, "to your target");
			quad.note = "Clarity buys this trigger down to a triple at Flawless instead of adding more to the hit.";
			built.push(quad);
			break;
		}
		case "BASTION":
			built.push(block("Give every living hero", "block", "block", [
				cutFlat(k, 3 * k, "triples into the wall this raises"), flat], c));
			built.push(fixed("Then clear", "cleanse", "stun from every living hero", l === 5 ? "2" : "1",
				l < 5 ? "Only Flawless Clarity clears a second slot of stun."
					: "Flawless Clarity clears both slots of a doubled stun.", "clarity"));
			break;
		case "PURGE":
			built.push(fixed("Clear", "cleanse", "Poison from every living hero",
				String(k + Math.ceil(c / 8)),
				`Cut ${k} (${cutName}) plus an eighth of Carat ${c}. Poison is the one status that bypasses block.`, "cut"));
			built.push(block("Then heal every living hero for", "heal", "health", [flat], c));
			break;
		case "GRAFT":
			built.push(block("Heal yourself for", "heal", "health", [
				part("pair", "both pair values", "Your two highest pairs, added together — the values, not the four dice."),
				cutFlat(k, 2 * (k - 1), "adds a flat bonus here"), flat], c));
			break;
		case "HEXBOLT":
			built.push(block("Deal", "damage", "damage", [
				part("count", "odd dice", "How many of your five dice came up odd.", cutFactor(k)),
				flat], c, "to your target"));
			if (l === 5) built.push(fixed("Apply", "stun", "stun", "1",
				"Flawless Clarity adds a stun this gem does not otherwise have.", "clarity"));
			break;
		case "MIASMA": {
			const fumes = fixed("Apply", "poison", "Poison", String(k + Math.ceil(c / 6)),
				`Cut ${k} (${cutName}) plus a sixth of Carat ${c}. Poison bypasses block and caps at 12 stacks.`, "cut");
			fumes.repeat = { glyph: "target", text: `to ${count(k + 1, "enemy", "enemies")}`,
				tip: `Cut ${k} (${cutName}) buys reach here as well as stacks.` };
			built.push(fumes);
			built.push(block("Then deal", "damage", "damage", [flat], c, "to the same enemies"));
			break;
		}
		case "ENERVATE":
			built.push(block("Strip", "strip", "block", [
				cutFlat(k, 2 * k, "doubles into the block you tear off"), flat], c, "from your target"));
			built.push(fixed("Then apply", "poison", "Poison", String(k),
				`Cut ${k} (${cutName}), plus half the matched value your triple showed. Caps at 12 stacks.`,
				"cut", "plus half the match value"));
			break;
		case "TITHE":
			built.push(block("Gain", "gold", "ore", [
				cutFlat(k, k, "adds its rank straight into the take"), flat], c));
			break;
		case "MINT":
			built.push(block("Gain", "gold", "ore", [
				cutFlat(k, 2 * k, "doubles into the take"), flat], c));
			built.push(block("Then gain", "block", "block", [
				cutFlat(k, k, "adds its rank straight into this block"), flat], c));
			break;
		case "WAGER": {
			built.push(block("Gain", "gold", "ore", [
				part("", String(blessing), `A fixed ${blessing} before Carat.`)], c));
			const bet = block("Then deal", "damage", "damage", [
				part("sum", `${wagerCeiling} − your total`,
					`What the hand did not give you: ${wagerCeiling} less the five dice added up.`),
				cutFlat(k, 2 * k, "doubles into this hit"), flat], c, "to your target");
			bet.note = "Clarity widens the low total this needs as well as adding its flat bonus, so a Flawless Wager fires on quiet hands a Fractured one would miss.";
			built.push(bet);
			break;
		}
		case "GLIMMER": {
			const polish = block("Raise your lowest die by", "amplify", "pips", [
				cutFlat(k, k, "adds its rank straight into the lift"), flat], c, "to a maximum of 20");
			polish.note = "The hand itself changes, so every gem equipped after this one reads the raised die.";
			built.push(polish);
			break;
		}
		case "REFRACT": {
			const lift = block("Raise your highest die by", "amplify", "pips", [
				part("high", "highest die", hint("high")),
				cutFlat(k, 2 * (k - 1), "doubles into the lift"), flat], c, "to a maximum of 20");
			lift.note = "Adding the die to itself is what doubles it. Every gem equipped after this one reads the raised hand.";
			built.push(lift);
			break;
		}
		case "SECOND_SIGHT": {
			const allowance = Math.min(4, 2 + Math.floor(c / 8) + (k === 5 ? 1 : 0));
			const sight = fixed("Reroll up to", "reroll", "times a turn", String(allowance),
				`Carat ${c} sets the allowance${k === 5 ? ", and a Perfect Cut adds one" : ""}.`,
				"reroll", "for the rest of this battle");
			sight.note = "It sets the allowance rather than adding to it, so casting it twice in one battle is no better than once.";
			built.push(sight);
			built.push(block("Gain", "block", "block", [flat], c));
			break;
		}
		case "ECHO": {
			const repeat = block("Repeat the last gem that landed an amount at", "echo", "per cent of it", [
				part("", "25", "A quarter of it before your ranks are counted."),
				cutFlat(k, 5 * (k - 1), "adds five points of repeat a rank"), flat], c, "up to 200%");
			repeat.note = "It repeats damage, block, healing, ore and statuses. A gem that only changed your dice is skipped over rather than repeated.";
			built.push(repeat);
			break;
		}
		case "FACET": {
			const recut = fixed("Permanently add", "upgrade", "Carat to another gem",
				String(Math.ceil(k / 2)),
				`Cut ${k} (${cutName}) sets how many ranks this cuts into the other stone.`,
				"cut", "once per battle");
			recut.note = `It takes your lowest-Carat other equipped gem, and never lifts it past Carat ${c} — this gem's own size.`;
			built.push(recut);
			break;
		}
	}
	return built;
}

// --- a rule written as data ----------------------------------------------------

const RULE_GLYPHS = {
	high: "high", highest_sum: "high", low: "low", lowest_sum: "low", lowest_odd: "low",
	total: "sum", pair_value: "pair", triple_value: "triple", run_high: "run",
	count_even: "count", count_odd: "count", count_distinct: "count", count_value: "count", block: "shield",
};
const LABELS = { damage: "damage", block: "block", remove_block: "block", heal: "health", gold: "ore", poison: "Poison", stun: "stun" };

function authored(rule, c, k, stored, l) {
	const built = [];
	for (const effect of rule.effects || []) {
		if (!effect || typeof effect !== "object") continue;
		const kind = String(effect.kind || "damage");
		const scaled = String(effect.scale ?? "carat") === "carat";
		const parts = addends(effect.amount).map((addend) => authoredPart(addend, k, stored, l)).filter(Boolean);
		let suffix = Rules.WHERE[String(effect.target ?? "self")] || "self";
		suffix = suffix === "self" ? "" : `to ${suffix}`;
		if ("target_limit" in effect) suffix += ` (up to ${Rules.say(effect.target_limit)} of them)`;
		const entry = block(Rules.VERBS[kind] || "Apply", kind === "remove_block" ? "strip" : kind,
			LABELS[kind] || kind, parts, scaled ? c : 1, suffix);
		if ("repeat" in effect)
			entry.repeat = { glyph: "hit", text: `×${Rules.say(effect.repeat)}`, tip: "Separate hits against one fixed target." };
		built.push(entry);
	}
	return built;
}

function addends(expression) {
	if (expression && typeof expression === "object" && String(expression.op || "") === "+")
		return (expression.args || []).flatMap(addends);
	return [expression];
}

function authoredPart(expression, k, stored, l) {
	if (!expression || typeof expression !== "object") return null;
	if ("rank" in expression) {
		switch (String(expression.rank)) {
			case "clarity_bonus": return clarityPart(stored, l);
			case "cut": return cutFlat(k, k, "adds its rank straight into this");
			case "clarity": return part("clarity", String(l), `Clarity ${l} (${CLARITY_NAMES[l - 1]}).`);
			case "carat": return part("carat", "", "Carat.");
		}
	}
	if ("const" in expression) {
		const value = Math.trunc(expression.const);
		return value === 0 ? null : part("", String(value), `A flat ${value}, whatever you roll.`);
	}
	if ("term" in expression) {
		const glyph = RULE_GLYPHS[String(expression.term)] || "";
		return part(glyph, Rules.say(expression), hint(glyph) || Rules.HINTS[String(expression.term)] || "");
	}
	if ("op" in expression) {
		const args = expression.args || [];
		if (String(expression.op) === "*" && args.length === 2) {
			for (const [first, second] of [[0, 1], [1, 0]])
				if (args[second] && String(args[second].rank || "") === "cut" && args[first] && "term" in args[first]) {
					const term = authoredPart(args[first], k, stored, l);
					if (term) term.factor = cutFactor(k);
					return term;
				}
		}
		return part("", Rules.say(expression), "This part of the rule, worked out from your hand.");
	}
	return null;
}

// --- the name line -------------------------------------------------------------

export function titleParts(key, definition, { carat = 1, cut = 1, clarity = 1 } = {}, color = {}) {
	const c = clamp(Math.round(carat), 1, 24);
	const k = clamp(Math.round(cut), 1, 5);
	const l = clamp(Math.round(clarity), 1, 5);
	return [
		part("cut", CUT_NAMES[k - 1], `Cut ${k} of 5 — ${CUT_NAMES[k - 1]}. ${hint("cut")}`),
		part("clarity", CLARITY_NAMES[l - 1], `Clarity ${l} of 5 — ${CLARITY_NAMES[l - 1]}. ${hint("clarity")}`),
		part("carat", String(c), `Carat ${c} of 24 — multiplies this gem by ${number(caratMultiplier(c))}. ${hint("carat")}`),
		part("", String((definition || {}).name || key), `${color.name || "Red"} gem — ${color.role || "Damage"}.`),
	];
}

// --- the requirement strip ------------------------------------------------------

const MATCH_TONE = "#ffcf7a";
const OTHER_TONE = "#76b6ff";
const RUN_TONE = "#6fe3b0";
const PLAIN_TONE = "#d8dce6";

const same = (howMany, value, tone = MATCH_TONE) => Array.from({ length: howMany }, () => [value, tone]);
const run = (length) => Array.from({ length }, (_unused, index) => [index + 1, RUN_TONE]);
const spec = (faces, lead, note) => ({ faces, lead, note });

/** The dice that would switch this gem on, as `dice_icons.gd` draws them. */
export function requirement(key, definition, { clarity = 1, cut = 1, carat = 1 } = {}) {
	const l = clamp(Math.round(clarity), 1, 5);
	const length = 5 - Math.trunc((l - 1) / 2);
	if (Rules.hasRule(definition)) return fromTrigger(definition.rule.trigger || {}, l, cut, carat);
	switch (ruleOf(key, definition)) {
		case "BLOCK": case "INTERPOSE": case "TITHE": return spec(same(2, 4), "", "Any two dice sharing a value.");
		case "HEAVYSTRIKE": case "ENERVATE": return spec(same(3, 5), "", "Any three dice sharing a value.");
		case "SHIELDBASH": return spec([...same(3, 5), ...same(2, 2, OTHER_TONE)], "", "Three dice of one value and two of another.");
		case "SUNDER": case "GRAFT": return spec([...same(2, 2), ...same(2, 5, OTHER_TONE)], "", "Two pairs of different values.");
		case "MULTISTRIKE": case "LIFELINE": return spec(run(length), "", `A run of ${length} consecutive values, in any order.`);
		case "BLESSING": case "ARC_BURST": return spec(run(3), "", "A run of three consecutive values, in any order.");
		case "LUCKYSTRIKE": return spec([[7, MATCH_TONE]], "", "At least one die showing 7.");
		case "MEND": case "HEXBOLT": return spec([[1, RUN_TONE], [3, RUN_TONE], [5, RUN_TONE]], "", "At least three odd results.");
		case "EVEN_TEMPO": case "PURGE": case "MIASMA": return spec([[2, RUN_TONE], [4, RUN_TONE], [6, RUN_TONE]], "", "At least three even results.");
		case "PRECISION": return spec([[3, PLAIN_TONE], [1, PLAIN_TONE], [6, PLAIN_TONE], [2, PLAIN_TONE], [5, PLAIN_TONE]], "≠",
			"All five dice showing different values.");
		case "ECHO": return spec(same(2, 4), "", "Any two dice sharing a value.");
		case "QUARTET": {
			const alike = l === 5 ? 3 : 4;
			return spec(same(alike, 4), "", `Any ${alike} dice sharing a value.`);
		}
		// The same easing a straight gets, counted in distinct values rather than a run.
		case "FACET": case "MINT": return spec([[3, PLAIN_TONE], [1, PLAIN_TONE], [6, PLAIN_TONE], [2, PLAIN_TONE], [5, PLAIN_TONE]].slice(0, length), "≠",
			`At least ${length} dice with no two of them alike.`);
		case "STUN": return spec([[21 - l, MATCH_TONE]], "≥", `The highest die is at least ${21 - l}.`);
		case "VENOM": return spec([[13 - l, MATCH_TONE]], "≥", `The highest die is at least ${13 - l}.`);
		case "BULWARK": case "BASTION": case "WAGER": return spec([], `Σ ≤ ${18 + 2 * l}`, `The whole hand totals ${18 + 2 * l} or less.`);
		case "DRAINSTRIKE": return spec([], `Σ ≥ ${45 - 5 * l}`, `The whole hand totals ${45 - 5 * l} or more.`);
	}
	return spec([], "ANY HAND", "No condition: this skill fires on every hand.");
}

function fromTrigger(trigger, l, cut, carat) {
	const at = (expression, fallback) => (expression && typeof expression === "object"
		? Rules.value(expression, { carat, cut, clarity: l, hand: [], groups: {}, total: 0, high: 0, block: 0, selected: [], run: [] })
		: fallback);
	switch (String(trigger.kind || "always")) {
		case "pair": return spec(same(2, 4), "", "Any two dice sharing a value.");
		case "two_pairs": return spec([...same(2, 2), ...same(2, 5, OTHER_TONE)], "", "Two pairs of different values.");
		case "triple": return spec(same(3, 5), "", "Any three dice sharing a value.");
		case "full_house": return spec([...same(3, 5), ...same(2, 2, OTHER_TONE)], "", "Three dice of one value and two of another.");
		case "straight": {
			const length = clamp(trigger.length === "by_clarity" ? 5 - Math.trunc((l - 1) / 2) : at(trigger.length, 3), 1, 5);
			return spec(run(length), "", `A run of ${length} consecutive values, in any order.`);
		}
		case "parity": {
			const odd = String(trigger.parity ?? "even") === "odd";
			const wanted = clamp(at(trigger.at_least, 3), 1, 5);
			return spec(Array.from({ length: wanted }, (_unused, index) => [(odd ? 1 : 2) + index * 2, RUN_TONE]), "",
				`At least ${wanted} ${odd ? "odd" : "even"} results.`);
		}
		case "distinct": {
			const wanted = clamp(at(trigger.at_least, 5), 1, 5);
			return spec(Array.from({ length: wanted }, (_unused, index) => [[3, 1, 6, 2, 5][index % 5], PLAIN_TONE]), "≠",
				`At least ${wanted} dice showing different values.`);
		}
		case "value": {
			const wanted = Number(trigger.value ?? 7);
			return spec([[wanted, MATCH_TONE]], "", `At least one die showing ${wanted}.`);
		}
		case "total_at_least": {
			const least = at(trigger.amount, 0);
			return spec([], `Σ ≥ ${least}`, `The whole hand totals ${least} or more.`);
		}
		case "total_at_most": {
			const most = at(trigger.amount, 0);
			return spec([], `Σ ≤ ${most}`, `The whole hand totals ${most} or less.`);
		}
		case "high_at_least": {
			const least = at(trigger.amount, 0);
			return spec([[least, MATCH_TONE]], "≥", `The highest die is at least ${least}.`);
		}
	}
	return spec([], "ANY HAND", "No condition: this skill fires on every hand.");
}

// --- glyph hover text -----------------------------------------------------------

let HINTS = {};
export function useHints(table) {
	HINTS = table || {};
}
export const hint = (glyph) => HINTS[glyph] || "";
