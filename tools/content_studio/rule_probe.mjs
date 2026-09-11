// Half of the cross-check that keeps the studio's rule interpreter honest.
//
//   node tools/content_studio/rule_probe.mjs                     # writes the cases, prints the JS answers
//   godot --headless --path . --script tools/content_studio/rule_probe.gd
//
// Diff the two outputs. They are the same interpreter written twice — one for the panel and
// one for the game — so any line that differs is a bug in `app/rules.js`.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import * as Rules from "./app/rules.js";

const HANDS = [
	[1, 3, 5, 6, 9], [2, 2, 4, 6, 8], [3, 4, 5, 6, 7], [1, 1, 1, 4, 4],
	[2, 4, 6, 8, 14], [7, 7, 7, 2, 3], [1, 2, 3, 4, 5], [5, 5, 5, 5, 5],
	[1, 1, 2, 2, 3], [12, 14, 16, 18, 20], [1, 1, 1, 1, 2], [4, 4, 7, 9, 11],
];
const RANKS = [[1, 1, 1], [8, 3, 3], [24, 5, 5], [12, 2, 4], [4, 4, 2]];
const BLOCK = 11;

const cases = { hands: HANDS, ranks: RANKS, block: BLOCK, recipes: {} };
for (const key of Rules.TEMPLATE_KEYS) cases.recipes[key] = Rules.template(key);

const here = dirname(fileURLToPath(import.meta.url));
writeFileSync(join(here, "rule_probe_cases.json"), JSON.stringify(cases, null, "\t"), "utf8");

const lines = [];
for (const key of Rules.TEMPLATE_KEYS) {
	const rule = cases.recipes[key];
	lines.push(`${key} trigger: ${Rules.describeTrigger(rule.trigger)}`);
	lines.push(`${key} formula: ${Rules.describe(rule)}`);
	lines.push(`${key} errors: ${Rules.validate(rule).join(" | ") || "none"}`);
	for (const [carat, cut, clarity] of RANKS)
		for (const hand of HANDS) {
			const result = Rules.evaluate(rule, Rules.buildContext(hand, { carat, cut, clarity, block: BLOCK }));
			const effects = result.effects.map((effect) =>
				`${effect.kind}:${effect.amount}>${effect.target}${effect.target_limit ? `x${effect.target_limit}` : ""}`).join(",");
			lines.push(`${key} C${carat}K${cut}L${clarity} ${hand.join("-")} active=${result.active ? 1 : 0} dice=${result.selected.slice().sort().join("+")} ${effects}`);
		}
}
process.stdout.write(lines.join("\n") + "\n");
