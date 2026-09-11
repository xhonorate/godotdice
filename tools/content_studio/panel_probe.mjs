// Half of the cross-check for the gem panel.
//
//   node tools/content_studio/panel_probe.mjs > js.txt
//   godot --headless --path . --script tools/content_studio/panel_probe.gd > gd.txt
//   diff js.txt gd.txt
//
// Every gem in the pack, at five rank spreads: the chain of marked terms and the strip of
// dice that switches it on. `app/gemtext.js` is a port of `scripts/ui/gem_text.gd` and the
// requirement half of `scripts/ui/dice_icons.gd`; a line that differs is a bug in the port.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import * as GemText from "./app/gemtext.js";

const here = dirname(fileURLToPath(import.meta.url));
const content = JSON.parse(readFileSync(join(here, "..", "..", "data", "full_content.json"), "utf8"));
const hints = JSON.parse(readFileSync(join(here, "app", "glyphs", "hints.json"), "utf8"));
GemText.useHints(hints);

// The constants the panel spells out, as the server reads them from the rules build.
const tables = {
	bulwark_block: [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 230, 250, 300],
	bulwark_stun: [3, 2, 2, 1, 0],
	multistrike_hit: 4,
	blessing_gold: 3,
};
const RANKS = [[1, 1, 1], [8, 3, 3], [24, 5, 5], [12, 2, 4], [4, 4, 2]];

const item = (found) => (!found ? "-"
	: `${found.glyph || "_"}:${found.text}${found.factor ? `{${found.factor.glyph}:${found.factor.text}}` : ""}`);
const lines = [];
for (const key of Object.keys(content.skills).sort()) {
	const definition = content.skills[key];
	for (const [carat, cut, clarity] of RANKS) {
		const ranks = { carat, cut, clarity };
		const strip = GemText.requirement(key, definition, ranks);
		lines.push(`${key} C${carat}K${cut}L${clarity} requires lead=${strip.lead || "_"} faces=${strip.faces.map(([value]) => value).join("+") || "_"} note=${strip.note}`);
		for (const row of GemText.blocks(key, definition, ranks, tables))
			lines.push(`${key} C${carat}K${cut}L${clarity} does ${row.verb} [${row.parts.map(item).join(" + ")}] mult=${item(row.mult)} ${row.label} ${row.suffix || "_"} repeat=${item(row.repeat)} note=${row.note || "_"}`);
		for (const found of GemText.titleParts(key, definition, ranks, { name: "X", role: "Y" }))
			lines.push(`${key} C${carat}K${cut}L${clarity} title ${item(found)}`);
	}
}
process.stdout.write(lines.join("\n") + "\n");
