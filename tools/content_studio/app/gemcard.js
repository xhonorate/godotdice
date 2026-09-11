// The gem, laid out the way the game lays it out.
//
// `scripts/ui/gem_panel.gd` places a gem as a name line of ranks, the dice that switch it
// on, and its rule as a chain of marked terms — each mark a pictograph with the sentence
// that explains it on hover. This is that panel in the browser, using the very glyphs the
// game draws: `bake_glyphs.gd` writes them out as alpha masks and CSS tints them, so the
// symbol beside a term here is the symbol beside it in a run.

import { el } from "./dom.js";
import { blocks, titleParts, requirement, hint } from "./gemtext.js";

/** The tint each rolled property keeps wherever it appears, from `gem_panel.gd`. */
const PROPERTY_TINTS = { carat: "#e8b661", cut: "#9fd8ff", clarity: "#d8c2ff" };
const TONES = { RED: "#ff7a6b", BLUE: "#76b6ff", GREEN: "#6fe3b0", GOLD: "#e8b661", VIOLET: "#b98bff", AMBER: "#ffcf7a", WHITE: "#cfe4ff", PAPER: "#eef1f7" };

const tint = (glyph, fallback) => PROPERTY_TINTS[glyph] || fallback;

/** One pictograph, masked from the baked art so a single file serves every colour. */
export function glyph(name, size, color, tip = "") {
	if (!name) return null;
	return el("span", {
		class: "gmark",
		title: tip || hint(name),
		style: `--glyph:url("glyphs/${name}.png");width:${size}px;height:${size}px;background:${color}`,
	});
}

function word(text, size, color, tip = "") {
	return el("span", { class: "gword", title: tip, style: `font-size:${size}px;color:${color}` }, String(text));
}

/** A term of the sum, boxed so the eye can count terms without reading them. */
function termChip(item, size) {
	const color = tint(item.glyph, TONES.PAPER);
	return el("span", { class: "gchip", title: item.tip || "" }, [
		glyph(item.glyph, size * 1.25, color, item.tip),
		word(item.text, size, color),
		item.factor ? word(item.factor.text, size, tint(item.factor.glyph, TONES.AMBER), item.factor.tip) : null,
		item.factor ? glyph(item.factor.glyph, size * 1.15, tint(item.factor.glyph, TONES.AMBER), item.factor.tip) : null,
	]);
}

/** A number and the mark saying which property produced it, hovering as one unit. */
function marked(item, size, color) {
	return el("span", { class: "gmarked", title: item.tip || "" }, [
		word(item.text, size, color),
		glyph(item.glyph, size * 1.2, color, item.tip),
	]);
}

/** The rule as a chain: terms added, multiplied once by Carat, then named by what they do. */
export function formulaRows(key, definition, ranks, tables, size = 14) {
	const rows = blocks(key, definition, ranks, tables);
	if (!rows.length)
		return [el("p", { class: "muted small", text: String((definition || {}).formula || "No rule to draw.") })];
	const built = [];
	for (const row of rows) {
		const line = el("div", { class: "grow-row" }, [word(row.verb, size, "#8f9fb5")]);
		row.parts.forEach((item, index) => {
			if (index > 0) line.append(word("+", size, "rgba(143,159,181,0.8)"));
			line.append(termChip(item, size));
		});
		if (row.mult) line.append(marked(row.mult, size, PROPERTY_TINTS.carat));
		if (row.label) line.append(word(row.label, size + 1, TONES[row.tone] || TONES.PAPER));
		if (row.suffix) line.append(word(row.suffix, size - 1, "#8f9fb5"));
		if (row.repeat) line.append(marked(row.repeat, size, TONES.AMBER));
		built.push(line);
		if (row.note) built.push(el("p", { class: "gnote", text: row.note }));
	}
	return built;
}

/** The dice that would switch the gem on, drawn as faces with the trigger's wording. */
export function requirementStrip(key, definition, ranks, size = 26) {
	const found = requirement(key, definition, ranks);
	const strip = el("div", { class: "greq", title: `${(definition || {}).trigger || ""}\n${found.note}`.trim() });
	if (found.lead) strip.append(el("span", { class: "glead", text: found.lead }));
	for (const [value, tone] of found.faces)
		strip.append(el("span", { class: "gface", style: `--tone:${tone}`, text: String(value) }));
	return strip;
}

/**
 * The whole card: name, the ranks a player says out loud, what it needs, and what it does.
 * The same four things, in the same order, as the gem sheet in the game.
 */
export function gemCard(key, definition, ranks, tables, color, stage) {
	const size = 14;
	const name = String(definition.name || key);
	return el("div", { class: "gcard" }, [
		stage || null,
		el("h2", { class: "gname", style: `color:${`#${color.hex || "e2564a"}`}`, text: name }),
		el("div", { class: "grow-row" }, titleParts(key, definition, ranks, color).map((item, index, all) =>
			marked(item, index === all.length - 1 ? size + 2 : size - 1,
				index === all.length - 1 ? TONES.PAPER : tint(item.glyph, TONES.GOLD)))),
		el("p", { class: "muted small", text: `${color.name || "Red"} gem — ${color.role || "Damage"}.` }),
		el("h4", { class: "gsection", text: "Requires" }),
		requirementStrip(key, definition, ranks),
		el("p", { class: "gtrigger", text: String(definition.trigger || "") }),
		el("h4", { class: "gsection", text: "Does" }),
		...formulaRows(key, definition, ranks, tables, size),
		el("h4", { class: "gsection", text: "Targets" }),
		el("p", { class: "gtarget", text: targetText(String(definition.target || "self")) }),
	]);
}

function targetText(target) {
	switch (target) {
		case "self": return "Yourself";
		case "ally": case "allies": return "Every living hero";
		case "enemy": return "Your preferred enemy, or the first living one";
		case "enemies": return "Several enemies, beginning with your preferred target";
		case "revive": return "The first downed hero, otherwise every living hero";
	}
	return target;
}
