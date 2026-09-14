// Content Studio: one panel for every piece of authored content in the game.
//
// The whole pack is held in memory as the JSON the game reads, edited in place, checked
// against a copy of the engine's validator on every keystroke, and written back whole.
// Nothing here knows a rule: what a new gem or enemy is allowed to borrow comes from the
// registry the server reads out of the GDScript itself.

import { SECTIONS, SECTION_BY_ID, CUT_NAMES, CLARITY_NAMES, RARITY_NAMES, caratMultiplier, clarityBonus, cutMultiplier, gemValue, enemyHp, enemyBlock } from "./schema.js";
import { validatePack, referencesTo, ruleProblem } from "./validate.js";
import { el, $, mount, clamp, titleCase } from "./dom.js";
import { ruleEditor, ruleBench } from "./rulebuilder.js";
import { gemCard } from "./gemcard.js";
import { useHints } from "./gemtext.js";
import * as Rules from "./rules.js";
import * as Gem from "./gem.js";
import * as Dice from "./dice.js";

const state = {
	content: null, registry: null, meta: null,
	section: "skills", selected: null, filter: "",
	dirty: false, issues: [], history: [], future: [],
	sample: { carat: 8, cut: 3, clarity: 3 },
	bench: [1, 3, 5, 6, 9],
	handCache: new Map(),
};

const percent = (fraction) => `${(fraction * 100).toFixed(fraction >= 0.995 || fraction === 0 ? 0 : 1)}%`;

// --- loading and saving -------------------------------------------------------

async function boot() {
	const response = await fetch("/api/bootstrap");
	const payload = await response.json();
	if (payload.error) return fail(payload.error);
	state.content = payload.content;
	state.registry = payload.registry;
	state.meta = payload.meta;
	useHints(await fetch("glyphs/hints.json").then((response) => response.json()).catch(() => ({})));
	state.selected = firstId("skills");
	revalidate();
	render();
	window.addEventListener("keydown", onKey);
}

function fail(message) {
	document.body.append(el("div", { class: "fatal", text: message }));
}

function snapshot() {
	state.history.push(JSON.stringify(state.content));
	if (state.history.length > 80) state.history.shift();
	state.future.length = 0;
	state.dirty = true;
	state.handCache.clear();
}

function undo() {
	if (!state.history.length) return;
	state.future.push(JSON.stringify(state.content));
	state.content = JSON.parse(state.history.pop());
	state.dirty = true;
	state.handCache.clear();
	revalidate();
	render();
}

function redo() {
	if (!state.future.length) return;
	state.history.push(JSON.stringify(state.content));
	state.content = JSON.parse(state.future.pop());
	state.dirty = true;
	state.handCache.clear();
	revalidate();
	render();
}

async function save() {
	const blocking = state.issues.filter((issue) => issue.severity === "error");
	if (blocking.length && !confirm(`${blocking.length} error${blocking.length === 1 ? "" : "s"} would stop the game loading this pack.\n\nSave anyway?`)) return;
	setStatus("Saving…");
	const response = await fetch("/api/save", {
		method: "POST", headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ content: state.content }),
	});
	const payload = await response.json();
	if (payload.error) return setStatus(`Save failed: ${payload.error}`, "bad");
	state.dirty = false;
	setStatus(`Saved ${payload.json} and ${payload.tres}.`, "good");
	render();
}

async function validateWithEngine() {
	setStatus("Running the engine's own validator…");
	const response = await fetch("/api/validate", { method: "POST" });
	const payload = await response.json();
	if (payload.skipped) return setStatus(payload.errors[0], "warn");
	if (payload.ok) return setStatus("Godot loaded the pack and every check passed.", "good");
	setStatus(`Godot rejected the pack: ${payload.errors.join(" · ") || "see console"}`, "bad");
	console.warn(payload.output);
}

function setStatus(text, tone = "") {
	const bar = $("#status");
	bar.textContent = text;
	bar.className = tone;
}

function onKey(event) {
	const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
	if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
		event.preventDefault();
		save();
	} else if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "z" && !typing) {
		event.preventDefault();
		event.shiftKey ? redo() : undo();
	} else if (event.key === "/" && !typing) {
		event.preventDefault();
		$("#search")?.focus();
	}
}

window.addEventListener("beforeunload", (event) => {
	if (state.dirty) event.preventDefault();
});

// --- the model ----------------------------------------------------------------

const entries = (section) => state.content[section] || {};
const entry = () => entries(state.section)[state.selected] || null;
const firstId = (section) => Object.keys(entries(section)).sort()[0] || null;
const sectionDef = () => SECTION_BY_ID[state.section];

function revalidate() {
	state.issues = validatePack(state.content, state.registry);
}

function issuesFor(section, id, field = null) {
	return state.issues.filter((issue) => issue.section === section && issue.id === id && (!field || issue.field === field));
}

function change(mutate) {
	snapshot();
	mutate();
	revalidate();
	render();
}

function colorHex(skillKey) {
	const skill = entries("skills")[skillKey];
	const definition = (state.registry.gem_colors || {})[skill?.color || "RED"];
	return definition ? definition.hex : "e2564a";
}

function gemSpec(skillKey, ranks = state.sample) {
	const skill = entries("skills")[skillKey] || {};
	return {
		key: skillKey, colorKey: skill.color || "RED", hex: colorHex(skillKey),
		carat: ranks.carat, cut: ranks.cut, clarity: ranks.clarity,
	};
}

function handStatsFor(dieIds) {
	const cacheKey = dieIds.join(",");
	if (!state.handCache.has(cacheKey)) {
		const faces = dieIds.map((id) => (entries("dice")[id] || {}).faces).filter(Boolean);
		state.handCache.set(cacheKey, Dice.handStats(faces, 12000));
	}
	return state.handCache.get(cacheKey);
}

// --- chrome -------------------------------------------------------------------

function render() {
	renderTopBar();
	renderRail();
	renderList();
	renderEditor();
	renderPreview();
}

function renderTopBar() {
	const errors = state.issues.filter((issue) => issue.severity === "error").length;
	const warnings = state.issues.length - errors;
	mount($("#topbar"), 
		el("div", { class: "brand" }, [
			el("span", { class: "mark", text: "◈" }),
			el("div", {}, [
				el("strong", { text: "Content Studio" }),
				el("span", { class: "sub", text: `${state.content.pack_id} · v${state.content.content_version}` }),
			]),
		]),
		el("div", { class: "grow" }),
		el("button", { class: `chip ${errors ? "bad" : warnings ? "warn" : "good"}`, onclick: () => showIssues() },
			errors ? `${errors} error${errors === 1 ? "" : "s"}` : warnings ? `${warnings} note${warnings === 1 ? "" : "s"}` : "All checks pass"),
		el("button", { class: "ghost", onclick: undo, disabled: !state.history.length, title: "Ctrl+Z" }, "Undo"),
		el("button", { class: "ghost", onclick: validateWithEngine, title: "Load the pack in Godot and run the real validator" }, "Validate in engine"),
		el("button", { class: `primary ${state.dirty ? "" : "quiet"}`, onclick: save, title: "Ctrl+S" },
			state.dirty ? "Save changes" : "Saved"),
	);
}

function renderRail() {
	const rail = $("#rail");
	mount(rail, ...SECTIONS.map((section) => {
		const count = Object.keys(entries(section.id)).length;
		const errors = state.issues.filter((issue) => issue.section === section.id && issue.severity === "error").length;
		return el("button", {
			class: `rail-item ${state.section === section.id ? "on" : ""}`,
			onclick: () => {
				state.section = section.id;
				state.selected = firstId(section.id);
				state.filter = "";
				render();
			},
		}, [
			el("span", { class: "glyph", text: section.glyph }),
			el("span", { class: "label", text: section.label }),
			el("span", { class: "count", text: String(count) }),
			errors ? el("span", { class: "dot bad", title: `${errors} errors` }) : null,
		]);
	}));
	rail.append(
		el("div", { class: "grow" }),
		el("button", {
			class: `rail-item ${state.section === "pack" ? "on" : ""}`,
			onclick: () => {
				state.section = "pack";
				state.selected = null;
				render();
			},
		}, [
			el("span", { class: "glyph", text: "⚙" }),
			el("span", { class: "label", text: "Pack & backups" }),
		]),
	);
}

// --- the list -----------------------------------------------------------------

function renderList() {
	if (state.section === "pack") return renderBackupList();
	const section = sectionDef();
	const ids = Object.keys(entries(section.id)).sort();
	const filtered = ids.filter((id) => {
		const definition = entries(section.id)[id];
		const haystack = `${id} ${definition?.name || ""} ${definition?.description || ""} ${(definition?.tags || []).join(" ")}`.toLowerCase();
		return haystack.includes(state.filter.toLowerCase());
	});
	mount($("#list"), 
		el("div", { class: "list-head" }, [
			el("input", {
				id: "search", type: "search", placeholder: `Search ${section.label.toLowerCase()}  ( / )`, value: state.filter,
				oninput: (event) => {
					state.filter = event.target.value;
					renderList();
				},
			}),
			el("button", { class: "primary small", onclick: () => createEntry(), title: `New ${section.singular.toLowerCase()}` }, `+ ${section.singular}`),
		]),
		el("div", { class: "list-body" }, filtered.length
			? filtered.map((id) => listRow(section, id))
			: [el("p", { class: "empty", text: "Nothing matches that." })]),
	);
}

async function renderBackupList() {
	const list = $("#list");
	mount(list, 
		el("div", { class: "list-head" }, [el("strong", { class: "small", text: "Saved copies" })]),
		el("div", { class: "list-body" }, [el("p", { class: "empty muted small", text: "Loading…" })]),
	);
	const payload = await (await fetch("/api/backups")).json();
	const rows = (payload.backups || []).map((name) => el("button", {
		class: "row",
		onclick: async () => {
			if (!confirm(`Replace everything in the studio with ${name}?\n\nThis writes the pack straight back out, so the current state is itself backed up first.`)) return;
			const restored = await (await fetch("/api/restore", {
				method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }),
			})).json();
			if (restored.error) return setStatus(restored.error, "bad");
			snapshot();
			state.content = restored.content;
			state.dirty = false;
			revalidate();
			render();
			setStatus(`Restored ${name}.`, "good");
		},
	}, [
		el("span", { class: "row-text" }, [
			el("span", { class: "row-name", text: name.replace("full_content-", "").replace(".json", "").replace(/(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/, "$1-$2-$3 $4:$5:$6") }),
			el("span", { class: "row-id", text: "click to restore" }),
		]),
	]));
	mount(list, 
		el("div", { class: "list-head" }, [el("strong", { class: "small", text: `Saved copies (${rows.length})` })]),
		el("div", { class: "list-body" }, rows.length ? rows : [el("p", { class: "empty muted small", text: "No saves yet. One is kept every time you save." })]),
	);
}

function listRow(section, id) {
	const definition = entries(section.id)[id];
	const errors = issuesFor(section.id, id).filter((issue) => issue.severity === "error").length;
	const borrowed = !(state.registry[section.id] || []).includes(id) && section.id !== "dice" && section.id !== "profiles" && section.id !== "mines";
	return el("button", {
		class: `row ${state.selected === id ? "on" : ""}`,
		onclick: () => {
			state.selected = id;
			renderList();
			renderEditor();
			renderPreview();
		},
	}, [
		el("span", { class: "thumb" }, [thumbnail(section.id, id, definition)]),
		el("span", { class: "row-text" }, [
			el("span", { class: "row-name", text: definition?.name || id }),
			el("span", { class: "row-id", text: id }),
		]),
		el("span", { class: "row-tags" }, [
			section.id === "skills" ? el("span", { class: `pill r${definition.rarity}`, text: RARITY_NAMES[definition.rarity] || "?" }) : null,
			section.id === "enemies" && definition.boss ? el("span", { class: "pill boss", text: "Boss" }) : null,
			borrowed ? el("span", { class: "pill new", title: "Authored here: it borrows a registered rule", text: "authored" }) : null,
			errors ? el("span", { class: "pill bad", text: String(errors) }) : null,
		]),
	]);
}

function thumbnail(sectionId, id, definition) {
	if (sectionId === "skills") return Gem.gemCanvas(gemSpec(id, { carat: 6, cut: 4, clarity: 4 }), 34);
	if (sectionId === "dice") return Dice.dieCanvas({ shape: definition.shape, value: null, tint: "#8f9fb5" }, 30);
	if (sectionId === "heroes") return el("span", { class: "seat", style: `background:#${definition.color || "9fd08b"}` });
	if (sectionId === "enemies") return el("span", { class: `seat enemy ${definition.boss ? "boss" : ""}`, text: definition.boss ? "♛" : "☠" });
	if (sectionId === "mines") return el("span", { class: "seat", style: `background:#${definition.color || "c9a26b"}`, text: definition.starter ? "★" : "⛏" });
	return el("span", { class: "seat plain", text: SECTION_BY_ID[sectionId].glyph });
}

function createEntry() {
	const section = sectionDef();
	const suggestion = prompt(`New ${section.singular.toLowerCase()} ID — capitals and underscores, e.g. ${section.idExample}`, "");
	if (!suggestion) return;
	const id = section.lowercaseIds ? suggestion.trim().toLowerCase().replace(/[^a-z0-9_]/g, "_")
		: suggestion.trim().toUpperCase().replace(/[^A-Z0-9_]/g, "_");
	if (!id) return;
	if (entries(section.id)[id]) return alert(`${id} already exists.`);
	change(() => {
		state.content[section.id][id] = section.defaults();
		state.selected = id;
	});
	if (section.codeOnly)
		setStatus(`${id} is data only: ${section.label.toLowerCase()} are pure behaviour, so it needs a rule in the build before the pack will load.`, "warn");
}

// --- the editor ---------------------------------------------------------------

function renderEditor() {
	if (state.section === "pack") return renderPackEditor();
	const section = sectionDef();
	const definition = entry();
	const pane = $("#editor");
	if (!definition) {
		mount(pane, el("div", { class: "blank" }, [
			el("p", { text: `No ${section.singular.toLowerCase()} selected.` }),
			el("p", { class: "muted", text: section.blurb }),
		]));
		return;
	}
	const rule = ruleProblem(section.id, state.selected, definition, state.registry);
	const borrowed = !(state.registry[section.id] || []).includes(state.selected);
	mount(pane, 
		el("header", { class: "editor-head" }, [
			el("div", {}, [
				el("h2", { text: definition.name || state.selected }),
				el("code", { class: "id", text: state.selected }),
			]),
			el("div", { class: "editor-actions" }, [
				el("button", { class: "ghost small", onclick: renameEntry }, "Rename ID"),
				el("button", { class: "ghost small", onclick: duplicateEntry }, "Duplicate"),
				el("button", { class: "ghost small danger", onclick: deleteEntry }, "Delete"),
			]),
		]),
		borrowed && !section.codeOnly && !["dice", "profiles", "mines"].includes(section.id)
			? el("p", { class: `banner ${rule ? "bad" : "info"}` },
				rule ? rule.message : `Authored here. The build has no ${state.selected} of its own, so it runs the rule named below.`)
			: null,
		section.codeOnly && borrowed
			? el("p", { class: "banner bad", text: `${section.label} are behaviour with no data hook. The build has to register ${state.selected} before the game will load this pack.` })
			: null,
		el("div", { class: "fields" }, section.fields.map((field) => renderField(section, field, definition))),
		referenceList(section.id, state.selected),
	);
}

function renderPackEditor() {
	const counts = SECTIONS.map((section) => [section.label, String(Object.keys(entries(section.id)).length)]);
	mount($("#editor"), 
		el("header", { class: "editor-head" }, [
			el("div", {}, [el("h2", { text: "Pack identity" }), el("code", { class: "id", text: state.meta.json })]),
		]),
		el("p", { class: "banner info", text: `Saving writes ${state.meta.json} and regenerates ${state.meta.tres}, which is the file the game loads at startup.` }),
		el("div", { class: "fields" }, [
			el("div", { class: "field" }, [
				el("label", {}, [
					el("span", { class: "field-label", text: "Pack ID" }),
					el("span", { class: "field-hint", text: "A pack called “full” has to carry every ID the rules build registers. Any other name may carry a subset." }),
				]),
				el("input", { type: "text", value: state.content.pack_id, onchange: (event) => set(state.content, "pack_id", event.target.value) }),
			]),
			el("div", { class: "field" }, [
				el("label", {}, [
					el("span", { class: "field-label", text: "Content version" }),
					el("span", { class: "field-hint", text: "Has to match CONTENT_VERSION in catalog.gd, and is what multiplayer peers compare." }),
				]),
				el("input", { type: "text", value: state.content.content_version, onchange: (event) => set(state.content, "content_version", event.target.value) }),
			]),
			el("div", { class: "field" }, [
				el("label", {}, [el("span", { class: "field-label", text: "Contents" })]),
				statGrid(counts),
			]),
			el("div", { class: "field" }, [
				el("label", {}, [
					el("span", { class: "field-label", text: "Registered in the rules build" }),
					el("span", { class: "field-hint", text: "What the GDScript itself implements. Anything else in this pack has to borrow one of these." }),
				]),
				statGrid([
					["Gem rules", (state.registry.evaluators || []).length + " evaluators"],
					["Enemy routines", (state.registry.enemy_ai || []).length + " routines"],
					["Hero traits", (state.registry.traits || []).join(", ")],
					["Godot", state.meta.godot ? "found" : "not found — engine validation off"],
				]),
			]),
		]),
	);
}

function renameEntry() {
	const section = sectionDef();
	const next = prompt("New ID", state.selected);
	if (!next || next === state.selected) return;
	const id = section.lowercaseIds ? next.trim().toLowerCase() : next.trim().toUpperCase();
	if (entries(section.id)[id]) return alert(`${id} already exists.`);
	const uses = referencesTo(state.content, section.id, state.selected);
	change(() => {
		const bucket = state.content[section.id];
		bucket[id] = bucket[state.selected];
		delete bucket[state.selected];
		retarget(section.id, state.selected, id);
		state.selected = id;
	});
	if (uses.length) setStatus(`Renamed, and repointed ${uses.length} reference${uses.length === 1 ? "" : "s"}.`, "good");
}

/** Every place an ID is written down, so a rename does not strand a reference. */
function retarget(sectionId, from, to) {
	const swap = (list) => (list || []).map((value) => (value === from ? to : value));
	if (sectionId === "dice")
		for (const group of ["heroes", "enemies"])
			for (const definition of Object.values(state.content[group] || {})) definition.dice = swap(definition.dice);
	if (sectionId === "skills") {
		for (const definition of Object.values(state.content.heroes || {}))
			definition.starting_gems = (definition.starting_gems || []).map((starter) => (starter[0] === from ? [to, ...starter.slice(1)] : starter));
		for (const definition of Object.values(state.content.profiles || {})) definition.skill_ids = swap(definition.skill_ids);
		for (const definition of Object.values(state.content.mines || {})) definition.skill_ids = swap(definition.skill_ids);
		for (const definition of Object.values(state.content.skills || {}))
			if (definition.evaluator_id === from) definition.evaluator_id = to;
	}
	if (sectionId === "relics")
		for (const definition of [...Object.values(state.content.profiles || {}), ...Object.values(state.content.mines || {})]) definition.relic_ids = swap(definition.relic_ids);
	if (sectionId === "mines")
		for (const definition of Object.values(state.content.mines || {})) definition.links = swap(definition.links);
	if (sectionId === "enemies") {
		for (const definition of Object.values(state.content.enemies || {})) if (definition.ai === from) definition.ai = to;
		for (const definition of Object.values(state.content.profiles || {})) {
			definition.boss_ids = swap(definition.boss_ids);
			if (definition.encounters) definition.encounters = JSON.parse(JSON.stringify(definition.encounters).split(`"${from}"`).join(`"${to}"`));
		}
		for (const definition of Object.values(state.content.mines || {})) {
			if (definition.boss_id === from) definition.boss_id = to;
			if (definition.bands) definition.bands = JSON.parse(JSON.stringify(definition.bands).split(`"${from}"`).join(`"${to}"`));
		}
	}
}

function duplicateEntry() {
	const section = sectionDef();
	const id = `${state.selected}_COPY`.replace(/_COPY_COPY/, "_COPY2");
	change(() => {
		state.content[section.id][section.lowercaseIds ? id.toLowerCase() : id] = JSON.parse(JSON.stringify(entry()));
		state.selected = section.lowercaseIds ? id.toLowerCase() : id;
		const copy = entry();
		copy.name = `${copy.name} copy`;
		// A duplicate of a shipped entry is a new ID with no rule, so point it at the original's.
		if (section.id === "skills" && !copy.evaluator_id) copy.evaluator_id = state.selected.replace(/_COPY2?$/, "");
		if (section.id === "enemies" && !copy.ai) copy.ai = state.selected.replace(/_COPY2?$/, "");
	});
}

function deleteEntry() {
	const uses = referencesTo(state.content, state.section, state.selected);
	const registered = (state.registry[state.section] || []).includes(state.selected);
	const warning = [
		`Delete ${state.selected}?`,
		registered ? "\nThe rules build registers this ID, so a pack called \"full\" will not load without it." : "",
		uses.length ? `\n${uses.length} other entr${uses.length === 1 ? "y" : "ies"} point at it: ${uses.map((use) => use.id).join(", ")}` : "",
	].join("");
	if (!confirm(warning)) return;
	change(() => {
		delete state.content[state.section][state.selected];
		state.selected = firstId(state.section);
	});
}

function referenceList(sectionId, id) {
	const uses = referencesTo(state.content, sectionId, id);
	if (!uses.length) return null;
	return el("section", { class: "uses" }, [
		el("h3", { text: "Used by" }),
		el("div", { class: "use-chips" }, uses.map((use) => el("button", {
			class: "use",
			onclick: () => {
				state.section = use.section;
				state.selected = use.id;
				render();
			},
		}, `${use.id} — ${use.why}`))),
	]);
}

// --- fields -------------------------------------------------------------------

function renderField(section, field, definition) {
	if (field.onlyWhen === "borrowed" && Rules.hasRule(definition)) return null;
	const problems = issuesFor(section.id, state.selected, field.key);
	const control = buildControl(section, field, definition);
	return el("div", { class: `field ${problems.some((issue) => issue.severity === "error") ? "has-error" : ""}` }, [
		el("label", {}, [
			el("span", { class: "field-label", text: field.label }),
			field.hint ? el("span", { class: "field-hint", text: field.hint }) : null,
		]),
		control,
		...problems.map((issue) => el("p", { class: `field-issue ${issue.severity}`, text: issue.message })),
	]);
}

function set(definition, key, value) {
	change(() => {
		definition[key] = value;
	});
}

function buildControl(section, field, definition) {
	const value = definition[field.key];
	switch (field.type) {
		case "text":
			return el("input", { type: "text", value: value ?? "", onchange: (event) => set(definition, field.key, event.target.value) });
		case "textarea":
			return el("textarea", { rows: 3, onchange: (event) => set(definition, field.key, event.target.value) }, [document.createTextNode(value ?? "")]);
		case "checkbox":
			return el("label", { class: "switch" }, [
				el("input", { type: "checkbox", checked: Boolean(value), onchange: (event) => set(definition, field.key, event.target.checked) }),
				el("span", { text: value ? "Yes" : "No" }),
			]);
		case "hex":
			return el("div", { class: "row-inline" }, [
				el("input", { type: "color", value: `#${String(value || "9fd08b").replace("#", "")}`, oninput: (event) => set(definition, field.key, event.target.value.replace("#", "")) }),
				el("input", { type: "text", class: "mono", value: value ?? "", onchange: (event) => set(definition, field.key, event.target.value.replace("#", "")) }),
			]);
		case "select": {
			const options = field.options || state.registry[field.from] || [];
			return el("select", { onchange: (event) => set(definition, field.key, event.target.value) },
				options.map((option) => el("option", { value: option, selected: option === value }, labelFor(field, option))));
		}
		case "slider": {
			const inherited = inheritedValue(section, field);
			return sliderControl(field, value ?? inherited, (next) => set(definition, field.key, next),
				value === undefined && inherited !== undefined ? "inherited from the rules build" : "");
		}
		case "tags": {
			const chosen = Array.isArray(value) ? value : [];
			return el("div", { class: "chips" }, (state.registry[field.from] || []).map((tag) => el("button", {
				class: `chip-toggle ${chosen.includes(tag) ? "on" : ""}`,
				onclick: () => set(definition, field.key, chosen.includes(tag) ? chosen.filter((item) => item !== tag) : [...chosen, tag]),
			}, titleCase(tag))));
		}
		case "faces":
			return facesControl(definition);
		case "dicelist":
			return diceListControl(definition, field);
		case "gems":
			return startingGemsControl(definition);
		case "idlist":
			return idListControl(definition, field);
		case "idset":
			return idSetControl(definition, field);
		case "numbers":
			return numbersControl(definition, field);
		case "encounters":
			return encountersControl(definition);
		case "weights":
			return weightsControl(definition, field);
		case "bands":
			return bandsControl(definition);
		case "bossselect": {
			const bosses = Object.keys(entries("enemies")).filter((id) => entries("enemies")[id].boss).sort();
			return el("select", { onchange: (event) => set(definition, field.key, event.target.value) },
				bosses.map((option) => el("option", { value: option, selected: option === value }, entries("enemies")[option].name)));
		}
		case "rule":
			return ruleControl(definition);
		default:
			return el("code", { text: JSON.stringify(value) });
	}
}

function labelFor(field, option) {
	if (field.from === "colors") {
		const definition = (state.registry.gem_colors || {})[option];
		return definition ? `${definition.name} — ${definition.role}` : option;
	}
	if (field.from === "traits" || field.from === "evaluators" || field.from === "enemy_ai") {
		const home = field.from === "evaluators" ? "skills" : field.from === "enemy_ai" ? "enemies" : null;
		const named = home ? entries(home)[option]?.name : null;
		return named ? `${titleCase(option)} — ${named}'s rule` : titleCase(option);
	}
	return field.from === "targets" || field.from === "loot_generators" ? option : titleCase(option);
}

function inheritedValue(section, field) {
	if (section.id !== "dice") return undefined;
	const fallback = (state.registry.die_unlock || {})[state.selected] || {};
	if (field.key === "unlock_act") return fallback.act ?? 0;
	if (field.key === "unlock_room") return fallback.room ?? 0;
	return undefined;
}

function sliderControl(field, value, commit, note = "") {
	const current = Number.isFinite(value) ? value : field.min;
	const readout = el("output", { class: "readout", text: field.names ? `${current} · ${field.names[current - field.min] ?? current}` : String(current) });
	const input = el("input", {
		type: "range", min: field.min, max: field.max, step: field.step, value: current,
		oninput: (event) => {
			readout.textContent = field.names ? `${event.target.value} · ${field.names[Number(event.target.value) - field.min] ?? event.target.value}` : event.target.value;
		},
		onchange: (event) => commit(Number(event.target.value)),
	});
	const number = el("input", {
		type: "number", class: "spin", min: field.min, max: field.max, step: field.step, value: current,
		onchange: (event) => commit(clamp(Number(event.target.value), field.min, field.max)),
	});
	return el("div", { class: "slider" }, [input, number,
		el("div", {}, [readout, note ? el("span", { class: "muted small block", text: note }) : null])]);
}

function facesControl(definition) {
	const sides = Dice.sidesOf(definition.shape);
	const faces = Array.isArray(definition.faces) ? definition.faces.slice() : [];
	while (faces.length < sides) faces.push(faces.length + 1);
	const grid = el("div", { class: "faces" }, faces.slice(0, sides).map((face, index) => el("div", { class: "face" }, [
		Dice.dieCanvas({ shape: definition.shape, value: face, tint: "#3f5170" }, 40),
		el("input", {
			type: "number", min: 1, max: sides, value: face,
			onchange: (event) => {
				const next = faces.slice(0, sides);
				next[index] = clamp(Math.round(Number(event.target.value)), 1, sides);
				set(definition, "faces", next);
			},
		}),
	])));
	return el("div", {}, [
		grid,
		el("div", { class: "row-inline wrap" }, [
			el("button", { class: "ghost small", onclick: () => set(definition, "faces", Array.from({ length: sides }, (_unused, index) => index + 1)) }, "Standard 1-n"),
			el("button", { class: "ghost small", onclick: () => set(definition, "faces", faces.slice(0, sides).slice().sort((a, b) => a - b)) }, "Sort"),
			el("span", { class: "muted small", text: `${sides} faces · average ${Dice.faceStats(faces.slice(0, sides)).mean.toFixed(2)}` }),
		]),
	]);
}

function diceListControl(definition, field) {
	const list = Array.isArray(definition.dice) ? definition.dice : [];
	const options = Object.keys(entries("dice")).sort();
	const fixed = field.count > 0;
	return el("div", {}, [
		el("div", { class: "die-row" }, list.map((dieId, index) => el("div", { class: "die-slot" }, [
			Dice.dieCanvas({ shape: (entries("dice")[dieId] || {}).shape || "D6", value: null, tint: "#e8b661" }, 40),
			el("select", {
				onchange: (event) => {
					const next = list.slice();
					next[index] = event.target.value;
					set(definition, "dice", next);
				},
			}, options.map((option) => el("option", { value: option, selected: option === dieId }, entries("dice")[option].name))),
			fixed ? null : el("button", {
				class: "x", title: "Remove",
				onclick: () => set(definition, "dice", list.filter((_unused, position) => position !== index)),
			}, "×"),
		]))),
		fixed ? el("p", { class: "muted small", text: `${list.length} of ${field.count} slots filled.` })
			: el("button", { class: "ghost small", onclick: () => set(definition, "dice", [...list, options[0]]) }, "+ Add die"),
		fixed && list.length !== field.count
			? el("button", { class: "ghost small", onclick: () => set(definition, "dice", Array.from({ length: field.count }, (_unused, index) => list[index] || "D6")) }, `Fill to ${field.count}`)
			: null,
	]);
}

function startingGemsControl(definition) {
	const gems = (definition.starting_gems || []).map((starter) => [starter[0], starter[1] ?? 1, starter[2] ?? 1, starter[3] ?? 1]);
	const options = Object.keys(entries("skills")).sort();
	const commit = (next) => set(definition, "starting_gems", next);
	return el("div", { class: "gem-editor" }, [
		...gems.map((starter, index) => {
			const [key, carat, cut, clarity] = starter;
			const update = (position, value) => {
				const next = gems.map((item) => item.slice());
				next[index][position] = value;
				commit(next);
			};
			return el("div", { class: "gem-slot" }, [
				Gem.gemCanvas(gemSpec(key, { carat, cut, clarity }), 62),
				el("div", { class: "gem-slot-fields" }, [
					el("select", { onchange: (event) => update(0, event.target.value) },
						options.map((option) => el("option", { value: option, selected: option === key }, entries("skills")[option].name))),
					el("div", { class: "rank-row" }, [
						rankSpin("Carat", carat, 1, 24, (value) => update(1, value)),
						rankSpin("Cut", cut, 1, 5, (value) => update(2, value), CUT_NAMES),
						rankSpin("Clarity", clarity, 1, 5, (value) => update(3, value), CLARITY_NAMES),
					]),
					el("span", { class: "muted small", text: `Worth ${gemValue(entries("skills")[key]?.rarity || 1, carat, cut, clarity)} gold · ${(entries("skills")[key] || {}).trigger || ""}` }),
				]),
				el("button", { class: "x", onclick: () => commit(gems.filter((_unused, position) => position !== index)) }, "×"),
			]);
		}),
		gems.length < 6 ? el("button", {
			class: "ghost small",
			onclick: () => commit([...gems, [options.find((option) => !gems.some((gem) => gem[0] === option)) || options[0], 1, 1, 1]]),
		}, "+ Add starting gem") : null,
	]);
}

function rankSpin(label, value, low, high, commit, names = null) {
	return el("label", { class: "rank" }, [
		el("span", { text: label }),
		el("input", { type: "number", min: low, max: high, value, onchange: (event) => commit(clamp(Math.round(Number(event.target.value)), low, high)) }),
		names ? el("em", { text: names[value - 1] }) : null,
	]);
}

function idListControl(definition, field) {
	const list = Array.isArray(definition[field.key]) ? definition[field.key] : [];
	const options = Object.keys(entries(field.section)).sort();
	const length = field.perAct ? Number(definition.acts || 1) : list.length;
	const rows = [];
	for (let index = 0; index < length; index++) {
		rows.push(el("div", { class: "row-inline" }, [
			el("span", { class: "act-tag", text: field.perAct ? `Act ${index + 1}` : `${index + 1}` }),
			el("select", {
				onchange: (event) => {
					const next = list.slice();
					next[index] = event.target.value;
					commitLength(next);
				},
			}, options.map((option) => el("option", { value: option, selected: option === list[index] }, entries(field.section)[option].name))),
		]));
	}
	const commitLength = (next) => set(definition, field.key, field.perAct ? next.slice(0, length) : next);
	if (list.length !== length && field.perAct)
		rows.push(el("button", {
			class: "ghost small",
			onclick: () => commitLength(Array.from({ length }, (_unused, index) => list[index] || options[0])),
		}, `Fit to ${length} act${length === 1 ? "" : "s"}`));
	return el("div", { class: "stack" }, rows);
}

function idSetControl(definition, field) {
	const chosen = Array.isArray(definition[field.key]) ? definition[field.key] : [];
	const options = Object.keys(entries(field.section)).filter((id) => field.section !== state.section || id !== state.selected).sort();
	const toggle = (id) => set(definition, field.key,
		(chosen.includes(id) ? chosen.filter((item) => item !== id) : [...chosen, id]).sort());
	return el("div", {}, [
		el("div", { class: "row-inline wrap tight" }, [
			el("button", { class: "ghost small", onclick: () => set(definition, field.key, options.slice()) }, "All"),
			el("button", { class: "ghost small", onclick: () => set(definition, field.key, []) }, "None"),
			el("span", { class: "muted small", text: `${chosen.length} of ${options.length}` }),
		]),
		el("div", { class: "chips grid" }, options.map((id) => {
			const definitionEntry = entries(field.section)[id];
			return el("button", { class: `chip-toggle ${chosen.includes(id) ? "on" : ""}`, onclick: () => toggle(id) }, [
				field.section === "skills" ? Gem.gemCanvas(gemSpec(id, { carat: 4, cut: 4, clarity: 4 }), 20) : null,
				el("span", { text: definitionEntry?.name || id }),
			]);
		})),
	]);
}

function numbersControl(definition, field) {
	const list = Array.isArray(definition[field.key]) ? definition[field.key] : [];
	const length = field.perAct ? Number(definition.acts || 1) : list.length;
	const commit = (next) => set(definition, field.key, next.slice(0, length).map((value) => Number(value) || 0));
	const rows = [];
	for (let index = 0; index < length; index++)
		rows.push(el("label", { class: "rank" }, [
			el("span", { text: field.perAct ? `Act ${index + 1}` : `#${index + 1}` }),
			el("input", {
				type: "number", min: 0, value: list[index] ?? 0,
				onchange: (event) => {
					const next = Array.from({ length }, (_unused, position) => list[position] ?? 0);
					next[index] = Number(event.target.value);
					commit(next);
				},
			}),
		]));
	return el("div", { class: "row-inline wrap" }, rows);
}

function ruleControl(definition) {
	if (!Rules.hasRule(definition))
		return el("div", {}, [
			el("p", { class: "muted small", text: "This gem runs a rule the build implements. Give it one of its own and it becomes data: a trigger, and effects whose amounts are arithmetic over the hand." }),
			el("button", {
				class: "ghost small",
				onclick: () => change(() => {
					definition.rule = Rules.template(Rules.TEMPLATE_KEYS.includes(definition.evaluator_id) ? definition.evaluator_id : "BLANK");
				}),
			}, Rules.TEMPLATE_KEYS.includes(definition.evaluator_id)
				? `Write its own rule, starting from ${titleCase(definition.evaluator_id)}`
				: "Write its own rule"),
		]);
	return ruleEditor(definition, (rule, text = null) => change(() => {
		if (rule === null) {
			delete definition.rule;
			if (!definition.evaluator_id) definition.evaluator_id = "STRIKE";
			return;
		}
		definition.rule = rule;
		if (text) {
			definition.trigger = text.trigger;
			definition.formula = text.formula;
		}
	}));
}

// --- the encounter table ------------------------------------------------------

function encountersControl(definition) {
	const table = definition.encounters && Object.keys(definition.encounters).length ? definition.encounters : null;
	if (!table)
		return el("div", {}, [
			el("p", { class: "muted small", text: "This profile uses the shipped encounter list. Give it its own table to decide what spawns — the only way an authored enemy reaches a room." }),
			el("button", {
				class: "ghost small",
				onclick: () => set(definition, "encounters", starterEncounters(definition)),
			}, "Add an encounter table"),
		]);
	const acts = Number(definition.acts || 1);
	const blocks = [
		el("div", { class: "row-inline" }, [
			el("span", { class: "act-tag", text: "Room 1" }),
			enemyPicker(table.first_room?.[0], (value) => changeTable(definition, (next) => {
				next.first_room = [value];
			})),
			el("span", { class: "muted small", text: "one per hero, as the opening fight" }),
		]),
	];
	for (let act = 1; act <= acts; act++)
		blocks.push(el("div", { class: "enc-act" }, [
			el("h4", { text: `Act ${act} · normal rooms` }),
			...[1, 2, 3, 4].map((party) => enemyGroupRow(`${party} hero${party === 1 ? "" : "es"}`, (table.normal || {})[String(act)]?.[party - 1] || [],
				(group) => changeTable(definition, (next) => {
					next.normal = next.normal || {};
					const list = (next.normal[String(act)] || []).slice();
					while (list.length < 4) list.push([]);
					list[party - 1] = group;
					next.normal[String(act)] = list;
				}))),
		]));
	blocks.push(el("div", { class: "enc-act" }, [
		el("h4", { text: "Elite rooms" }),
		...[1, 2, 3, 4].map((party) => enemyGroupRow(`${party} hero${party === 1 ? "" : "es"}`, (table.elite || [])[party - 1] || [],
			(group) => changeTable(definition, (next) => {
				const list = (next.elite || []).slice();
				while (list.length < 4) list.push([]);
				list[party - 1] = group;
				next.elite = list;
			}))),
	]));
	blocks.push(el("p", { class: "muted small", text: "Bosses come from the act bosses above. Anything left empty falls back to the shipped list." }));
	blocks.push(el("button", { class: "ghost small danger", onclick: () => set(definition, "encounters", {}) }, "Remove the table"));
	return el("div", { class: "stack" }, blocks);
}

function changeTable(definition, mutate) {
	change(() => {
		const next = JSON.parse(JSON.stringify(definition.encounters || {}));
		mutate(next);
		definition.encounters = next;
	});
}

function starterEncounters(definition) {
	const weakest = Object.entries(entries("enemies"))
		.filter(([, enemy]) => !enemy.boss)
		.sort((a, b) => (a[1].max_hp || 0) - (b[1].max_hp || 0))[0]?.[0] || "SLIME";
	const table = { first_room: [weakest], elite: [[weakest], [weakest], [weakest, weakest], [weakest, weakest]], normal: {} };
	for (let act = 1; act <= Number(definition.acts || 1); act++)
		table.normal[String(act)] = [[weakest], [weakest, weakest], [weakest, weakest, weakest], [weakest, weakest, weakest, weakest]];
	return table;
}

function enemyPicker(value, commit) {
	const options = Object.keys(entries("enemies")).sort();
	return el("select", { onchange: (event) => commit(event.target.value) },
		options.map((option) => el("option", { value: option, selected: option === value }, entries("enemies")[option].name)));
}

function enemyGroupRow(label, group, commit) {
	const options = Object.keys(entries("enemies")).sort();
	return el("div", { class: "row-inline wrap tight" }, [
		el("span", { class: "act-tag", text: label }),
		...group.map((id, index) => el("span", { class: "enemy-chip" }, [
			el("span", { text: entries("enemies")[id]?.name || id }),
			el("button", { class: "x", onclick: () => commit(group.filter((_unused, position) => position !== index)) }, "×"),
		])),
		el("select", {
			value: "",
			onchange: (event) => {
				if (event.target.value) commit([...group, event.target.value]);
			},
		}, [el("option", { value: "" }, "+ add"), ...options.map((option) => el("option", { value: option }, entries("enemies")[option].name))]),
	]);
}

// --- mine weights and depth bands ----------------------------------------------

function weightsControl(definition, field) {
	const value = definition[field.key] && typeof definition[field.key] === "object" ? definition[field.key] : {};
	const keys = state.registry[field.from] || [];
	const fallback = field.fallback ?? 0;
	const total = keys.reduce((sum, key) => sum + Number(value[key] ?? fallback), 0);
	return el("div", { class: "stack" }, keys.map((key) => {
		const weight = Number(value[key] ?? fallback);
		const tint = field.from === "colors" ? (state.registry.gem_colors[key] || {}).hex : null;
		return el("div", { class: "bar-row" }, [
			el("span", { class: "bar-label", text: field.from === "colors" ? (state.registry.gem_colors[key] || {}).name || key : roomLabel(key) }),
			el("span", { class: "bar" }, [el("span", { class: "bar-fill", style: `width:${total ? (weight / total) * 100 : 0}%${tint ? `;background:#${tint}` : ""}` })]),
			el("input", {
				type: "number", class: "spin", min: 0, max: 1000, value: weight,
				onchange: (event) => change(() => {
					const next = { ...value };
					const number = clamp(Math.round(Number(event.target.value) || 0), 0, 1000);
					if (field.fallback !== undefined && number === fallback) delete next[key];
					else if (field.fallback === undefined && number === 0) delete next[key];
					else next[key] = number;
					definition[field.key] = next;
				}),
			}),
		]);
	}));
}

const ROOM_LABELS = { mine: "Rock vein", rest: "Camp", shop: "Merchant", event: "Event (?)" };
const roomLabel = (key) => ROOM_LABELS[key] || titleCase(key);

function bandsControl(definition) {
	const bands = Array.isArray(definition.bands) ? definition.bands : [];
	const commit = (mutate) => change(() => {
		const next = JSON.parse(JSON.stringify(bands));
		mutate(next);
		definition.bands = next;
	});
	const ordinary = Object.keys(entries("enemies")).filter((id) => !entries("enemies")[id].boss).sort();
	const group = (index, name) => {
		const pool = bands[index]?.[name] || {};
		return el("div", { class: "row-inline wrap tight" }, [
			el("span", { class: "act-tag", text: name === "normal" ? "Fights" : "Elites" }),
			...Object.entries(pool).map(([id, weight]) => el("span", { class: "enemy-chip" }, [
				el("span", { text: entries("enemies")[id]?.name || id }),
				el("input", {
					type: "number", class: "spin", min: 1, max: 1000, value: weight, title: "Weight",
					onchange: (event) => commit((next) => {
						next[index][name][id] = clamp(Math.round(Number(event.target.value) || 1), 1, 1000);
					}),
				}),
				el("button", { class: "x", onclick: () => commit((next) => delete next[index][name][id]) }, "×"),
			])),
			el("select", {
				onchange: (event) => {
					if (event.target.value) commit((next) => {
						next[index][name] = { ...(next[index][name] || {}), [event.target.value]: 1 };
					});
				},
			}, [el("option", { value: "" }, "+ add"), ...ordinary.filter((id) => !(id in pool)).map((id) => el("option", { value: id }, entries("enemies")[id].name))]),
		]);
	};
	return el("div", { class: "stack" }, [
		...bands.map((band, index) => el("div", { class: "enc-act" }, [
			el("div", { class: "row-inline" }, [
				el("h4", { text: index + 1 < bands.length ? `Depth ${band.from_depth}–${bands[index + 1].from_depth - 1}` : `Depth ${band.from_depth}+` }),
				index > 0 ? el("label", { class: "rank" }, [
					el("span", { text: "From depth" }),
					el("input", {
						type: "number", min: 2, max: 999, value: band.from_depth,
						onchange: (event) => commit((next) => {
							next[index].from_depth = clamp(Math.round(Number(event.target.value) || 2), 2, 999);
						}),
					}),
				]) : null,
				index > 0 ? el("button", { class: "x", title: "Remove band", onclick: () => commit((next) => next.splice(index, 1)) }, "×") : null,
			]),
			group(index, "normal"),
			group(index, "elite"),
		])),
		el("button", {
			class: "ghost small",
			onclick: () => commit((next) => {
				const last = next[next.length - 1] || { from_depth: -3, normal: { SLIME: 1 }, elite: { RED_SLIME: 1 } };
				next.push({ from_depth: last.from_depth + 4, normal: { ...last.normal }, elite: { ...last.elite } });
			}),
		}, "+ Add a deeper band"),
	]);
}

// --- previews -----------------------------------------------------------------

function renderPreview() {
	const pane = $("#preview");
	if (state.section === "pack") return pane.replaceChildren(packPreview());
	const definition = entry();
	if (!definition) return pane.replaceChildren();
	const builders = {
		skills: skillPreview, dice: diePreview, heroes: heroPreview,
		enemies: enemyPreview, profiles: profilePreview, mines: minePreview,
	};
	pane.replaceChildren((builders[state.section] || textPreview)(definition));
}

function previewCard(title, children, extra = "") {
	return el("section", { class: `preview-card ${extra}` }, [el("h3", { text: title }), ...[].concat(children)]);
}

function skillPreview(definition) {
	const { carat, cut, clarity } = state.sample;
	const colorDefinition = (state.registry.gem_colors || {})[definition.color] || {};
	const stage = el("div", { class: "gem-stage" }, [Gem.gemCanvas(gemSpec(state.selected), 190)]);
	const rerender = () => renderPreview();
	const rank = (label, key, high, names) => el("label", { class: "rank wide" }, [
		el("span", { text: `${label} ${names ? `· ${names[state.sample[key] - 1]}` : state.sample[key]}` }),
		el("input", {
			type: "range", min: 1, max: high, value: state.sample[key],
			oninput: (event) => {
				state.sample[key] = Number(event.target.value);
				rerender();
			},
		}),
	]);
	const odds = triggerOdds(definition);
	return el("div", {}, [
		el("section", { class: "preview-card" }, [
			gemCard(state.selected, definition, state.sample, state.registry, colorDefinition, stage),
			el("div", { class: "chips read" }, (definition.tags || []).map((tag) => el("span", { class: "chip-static", text: titleCase(tag) }))),
		]),
		previewCard("This stone", [
			rank("Carat", "carat", 24, null),
			rank("Cut", "cut", 5, CUT_NAMES),
			rank("Clarity", "clarity", 5, CLARITY_NAMES),
			statGrid([
				["Carat multiplier", `×${caratMultiplier(carat).toFixed(3)}`],
				["Clarity bonus", `+${clarityBonus(clarity)}`],
				["Cut multiplier", `×${cutMultiplier(cut).toFixed(2)}`],
				["Sells for", `${gemValue(definition.rarity || 1, carat, cut, clarity)} gold`],
				["Cut shape", CUTS_LABEL[definition.color] || "round"],
				["Facets", String(Gem.facetCount(cut, definition.color))],
				["Inclusions", String(Gem.flawCount(clarity))],
				["Rarity", RARITY_NAMES[definition.rarity] || "—"],
			]),
		]),
		Rules.hasRule(definition)
			? previewCard("Try the rule on a hand", ruleBench(definition, state.bench, state.sample,
				(hand) => {
					state.bench = hand;
					renderPreview();
				}, benchPools()))
			: null,
		odds ? previewCard("Chance each hero can fire it", odds) : null,
	]);
}

function benchPools() {
	// Roll buttons for each hero's actual five dice, so a rule is tried against the hands
	// it will really meet rather than against numbers someone typed.
	return Object.entries(entries("heroes")).map(([id, hero]) => ({
		label: hero.name || id,
		faces: (hero.dice || []).map((dieId) => (entries("dice")[dieId] || {}).faces || [1, 2, 3, 4, 5, 6]),
	}));
}

const CUTS_LABEL = { RED: "trilliant", BLUE: "princess", GREEN: "heart", VIOLET: "pear", GOLD: "half Dutch rose", WHITE: "round brilliant" };

function triggerOdds(definition) {
	const triggers = (definition.tags || []).map((tag) => Dice.TAG_TRIGGERS[tag]).filter(Boolean);
	const heroes = Object.entries(entries("heroes"));
	if (!heroes.length) return null;
	const rows = heroes.map(([id, hero]) => {
		const stats = handStatsFor(hero.dice || []);
		const chance = triggers.length ? Math.min(...triggers.map((name) => stats.rate(name))) : 1;
		return el("div", { class: "bar-row" }, [
			el("span", { class: "bar-label", text: hero.name }),
			el("span", { class: "bar" }, [el("span", { class: "bar-fill", style: `width:${clamp(chance, 0, 1) * 100}%` })]),
			el("span", { class: "bar-value", text: triggers.length ? percent(chance) : "always" }),
		]);
	});
	rows.push(el("p", { class: "muted small", text: triggers.length ? "Per turn, before rerolls, from 12,000 sampled hands of that hero's five dice." : "No trigger tag, so this fires on any hand." }));
	return rows;
}

function diePreview(definition) {
	const stats = Dice.faceStats(definition.faces || []);
	const sides = Dice.sidesOf(definition.shape);
	const histogram = [];
	for (let value = 1; value <= sides; value++) {
		const count = stats.counts.get(value) || 0;
		histogram.push(el("div", { class: "bar-row" }, [
			el("span", { class: "bar-label mono", text: String(value) }),
			el("span", { class: "bar" }, [el("span", { class: `bar-fill ${count ? "" : "empty"}`, style: `width:${(count / (definition.faces || []).length) * 100}%` })]),
			el("span", { class: "bar-value", text: count ? `${count}× · ${percent(count / (definition.faces || []).length)}` : "—" }),
		]));
	}
	return el("div", {}, [
		previewCard(definition.name || state.selected, [
			el("div", { class: "die-stage" }, (definition.faces || []).map((face) => Dice.dieCanvas({ shape: definition.shape, value: face }, 46))),
			statGrid([
				["Average", stats.mean.toFixed(2)],
				["Range", `${stats.min}–${stats.max}`],
				["Distinct faces", `${stats.distinct} of ${sides}`],
				["Spread", stats.spread.toFixed(2)],
				["Price", `${definition.price} gold`],
				["Sold from", (() => {
				const fallback = (state.registry.die_unlock || {})[state.selected] || {};
				const act = definition.unlock_act ?? fallback.act ?? 0;
				const room = definition.unlock_room ?? fallback.room ?? 0;
				return act ? `Act ${act}${room ? ` (or room ${room} in a one-act run)` : ""}` : "Never sold";
			})()],
			]),
		]),
		previewCard("Face distribution", histogram),
		previewCard("Odds this die alone", statGrid([
			["Shows a 7", percent(Dice.faceChance(definition.faces, [7]))],
			["Shows even", percent(Dice.faceChance(definition.faces, (definition.faces || []).filter((face) => face % 2 === 0)))],
			["Shows its best", percent(Dice.faceChance(definition.faces, [stats.max]))],
			["Value per gold", (stats.mean / Math.max(1, definition.price || 1)).toFixed(2)],
		])),
	]);
}

function heroPreview(definition) {
	const stats = handStatsFor(definition.dice || []);
	const gems = (definition.starting_gems || []).map((starter) => [starter[0], starter[1] ?? 1, starter[2] ?? 1, starter[3] ?? 1]);
	const triggerRows = [
		["Any pair", "pair"], ["Two pairs", "twoPairs"], ["Three of a kind", "triple"], ["Full house", "fullHouse"],
		["Straight of 3", "straight3"], ["Straight of 4", "straight4"], ["Straight of 5", "straight5"],
		["Three even", "threeEven"], ["Three odd", "threeOdd"], ["Five distinct", "distinct5"], ["Any 7", "anySeven"],
	].map(([label, key]) => el("div", { class: "bar-row" }, [
		el("span", { class: "bar-label", text: label }),
		el("span", { class: "bar" }, [el("span", { class: "bar-fill", style: `width:${stats.rate(key) * 100}%` })]),
		el("span", { class: "bar-value", text: percent(stats.rate(key)) }),
	]));
	return el("div", {}, [
		previewCard(definition.name || state.selected, [
			el("div", { class: "hero-banner", style: `--seat:#${definition.color || "9fd08b"}` }, [
				el("span", { class: "hp", text: `${definition.max_hp} HP` }),
				el("span", { class: "trait", text: definition.trait_name || titleCase(definition.trait || "") }),
			]),
			el("p", { class: "muted", text: definition.description || "" }),
			el("div", { class: "die-stage" }, (definition.dice || []).map((id) =>
				Dice.dieCanvas({ shape: (entries("dice")[id] || {}).shape || "D6", value: null }, 46))),
			el("p", { class: "muted small centre", text: (definition.dice || []).map((id) => (entries("dice")[id] || {}).name || id).join(" · ") }),
		]),
		previewCard("Starting gems", [
			el("div", { class: "gem-shelf" }, gems.map(([key, carat, cut, clarity]) => el("div", { class: "shelf-gem" }, [
				Gem.gemCanvas(gemSpec(key, { carat, cut, clarity }), 74),
				el("span", { class: "small", text: entries("skills")[key]?.name || key }),
				el("span", { class: "muted small", text: `${CUT_NAMES[cut - 1]} ${CLARITY_NAMES[clarity - 1]} ${carat}` }),
			]))),
			statGrid([
				["Opening gem value", `${gems.reduce((sum, [key, carat, cut, clarity]) => sum + gemValue(entries("skills")[key]?.rarity || 1, carat, cut, clarity), 0)} gold`],
				["Equipped", `${gems.length} of 6`],
			]),
		]),
		previewCard("What these five dice roll", [
			statGrid([
				["Average total", stats.meanTotal.toFixed(1)],
				["Typical spread", `${stats.lowTotal}–${stats.highTotal}`],
				["Average highest die", stats.meanHigh.toFixed(1)],
				["Median total", String(stats.medianTotal)],
			]),
			...triggerRows,
			el("p", { class: "muted small", text: "12,000 sampled hands, before any reroll." }),
		]),
	]);
}

function enemyPreview(definition) {
	const rows = [];
	for (const act of [1, 2, 3])
		for (const party of definition.boss ? [1, 2, 3, 4] : [1]) {
			rows.push([
				definition.boss ? `Act ${act} · ${party} hero${party === 1 ? "" : "es"}` : `Act ${act}`,
				`${enemyHp(definition.max_hp || 0, act, party, definition.boss)} HP · ${enemyBlock(definition.block || 0, act, party, definition.boss)} block`,
			]);
		}
	const stats = (definition.dice || []).length ? handStatsFor(definition.dice) : null;
	return el("div", {}, [
		previewCard(definition.name || state.selected, [
			el("div", { class: `enemy-banner ${definition.boss ? "boss" : ""}` }, [
				el("span", { class: "glyph", text: definition.boss ? "♛" : "☠" }),
				el("div", {}, [
					el("strong", { text: `${definition.max_hp} HP` }),
					el("span", { class: "muted small", text: `${definition.block || 0} starting block · threat ${definition.threat ?? "—"}` }),
				]),
			]),
			el("p", { class: "muted", text: definition.description || "" }),
			el("p", { class: "muted small", text: `Runs the ${titleCase(definition.ai || state.selected)} routine.` }),
		]),
		previewCard("On the table", statGrid(rows)),
		(definition.dice || []).length ? previewCard("Its dice", [
			el("div", { class: "die-stage" }, definition.dice.map((id) =>
				Dice.dieCanvas({ shape: (entries("dice")[id] || {}).shape || "D6", value: null, tint: "#ff7a6b" }, 44))),
			stats ? statGrid([
				["Average total", stats.meanTotal.toFixed(1)],
				["Average high", stats.meanHigh.toFixed(1)],
				["Pair chance", percent(stats.rate("pair"))],
			]) : null,
		]) : null,
	]);
}

function profilePreview(definition) {
	const pool = (definition.skill_ids || []).map((id) => entries("skills")[id]).filter(Boolean);
	const byRarity = [1, 2, 3, 4].map((rarity) => pool.filter((skill) => skill.rarity === rarity).length);
	const byColor = Object.keys(state.registry.gem_colors || {}).map((color) => [color, pool.filter((skill) => skill.color === color).length]);
	const bars = (rows, total) => rows.map(([label, count, tint]) => el("div", { class: "bar-row" }, [
		el("span", { class: "bar-label", text: label }),
		el("span", { class: "bar" }, [el("span", { class: "bar-fill", style: `width:${total ? (count / total) * 100 : 0}%${tint ? `;background:#${tint}` : ""}` })]),
		el("span", { class: "bar-value", text: String(count) }),
	]));
	return el("div", {}, [
		previewCard(state.selected, statGrid([
			["Rooms", String(definition.rooms)],
			["Acts", String(definition.acts)],
			["Rooms per act", (Number(definition.rooms || 0) / Math.max(1, Number(definition.acts || 1))).toFixed(1)],
			["Loot", definition.loot_generator || "—"],
			["Gem pool", `${pool.length} gems`],
			["Relic pool", `${(definition.relic_ids || []).length} relics`],
		])),
		previewCard("Pool by rarity", bars(byRarity.map((count, index) => [RARITY_NAMES[index + 1], count]), pool.length)),
		previewCard("Pool by colour", bars(byColor.map(([color, count]) => [(state.registry.gem_colors[color] || {}).name || color, count, (state.registry.gem_colors[color] || {}).hex]), pool.length)),
		previewCard("Act bosses", el("div", { class: "stack" }, (definition.boss_ids || []).map((id, index) =>
			el("p", { class: "small", text: `Act ${index + 1} — ${entries("enemies")[id]?.name || id} (${entries("enemies")[id]?.max_hp || "?"} HP base)` })))),
	]);
}

function minePreview(definition) {
	const mines = entries("mines");
	const boss = entries("enemies")[definition.boss_id] || {};
	const pool = (definition.skill_ids || []).map((id) => entries("skills")[id]).filter(Boolean);
	const colorWeight = (color) => Number((definition.color_weights || {})[color] ?? 100);
	const byColor = Object.keys(state.registry.gem_colors || {}).map((color) => [color,
		pool.filter((skill) => skill.color === color).length * colorWeight(color)]);
	const colorTotal = byColor.reduce((sum, [, weight]) => sum + weight, 0);
	const rooms = Object.entries(definition.rooms || {}).filter(([, weight]) => weight > 0);
	const roomTotal = rooms.reduce((sum, [, weight]) => sum + weight, 0);
	const bars = (rows, total) => rows.map(([label, count, tint, text]) => el("div", { class: "bar-row" }, [
		el("span", { class: "bar-label", text: label }),
		el("span", { class: "bar" }, [el("span", { class: "bar-fill", style: `width:${total ? (count / total) * 100 : 0}%${tint ? `;background:#${tint}` : ""}` })]),
		el("span", { class: "bar-value", text: text ?? String(count) }),
	]));
	// The atlas as the wall map draws it: every mine, every unlock line, this one ringed.
	const canvas = el("canvas", { width: 320, height: 200, class: "atlas" });
	const context = canvas.getContext("2d");
	context.fillStyle = "#1a1510";
	context.fillRect(0, 0, 320, 200);
	const at = (mine) => [12 + (Number(mine.atlas_x) || 0) * 2.96, 12 + (Number(mine.atlas_y) || 0) * 1.76];
	context.strokeStyle = "#6b5a44";
	context.lineWidth = 2;
	for (const mine of Object.values(mines))
		for (const link of mine.links || []) if (mines[link]) {
			context.beginPath();
			context.moveTo(...at(mine));
			context.lineTo(...at(mines[link]));
			context.stroke();
		}
	for (const [id, mine] of Object.entries(mines)) {
		const [x, y] = at(mine);
		context.fillStyle = `#${mine.color || "c9a26b"}`;
		context.beginPath();
		context.arc(x, y, id === state.selected ? 9 : 6, 0, Math.PI * 2);
		context.fill();
		if (id === state.selected) {
			context.strokeStyle = "#f4e6c8";
			context.stroke();
			context.strokeStyle = "#6b5a44";
		}
		context.fillStyle = "#e8dcc4";
		context.font = "11px sans-serif";
		context.fillText(mine.name || id, x + 11, y + 4);
	}
	const band = (depth) => [...(definition.bands || [])].reverse().find((entry) => depth >= entry.from_depth);
	const names = (group) => Object.entries(group || {}).map(([id, weight]) => `${entries("enemies")[id]?.name || id} ×${weight}`).join(", ") || "—";
	const difficulty = Math.min(5, Math.max(1, Number(definition.difficulty) || 1));
	return el("div", {}, [
		previewCard(definition.name || state.selected, [
			el("p", { class: "muted", text: definition.description || "" }),
			statGrid([
				["Difficulty", `${"◆".repeat(difficulty)}${"◇".repeat(5 - difficulty)}`],
				["Boss", `${boss.name || definition.boss_id} · ${boss.max_hp || "?"} HP per hero`],
				["Tremors", `${definition.tremor_rate}% speed`],
				["Lifts", `${definition.lift_rate}% as common`],
				["Loot quality", `+${definition.quality_bonus}`],
				["Unlocks", (definition.links || []).map((id) => mines[id]?.name || id).join(", ") || "nothing yet"],
			]),
		]),
		previewCard("On the atlas", canvas),
		previewCard("Rooms", bars(rooms.map(([key, weight]) => [roomLabel(key), weight, null, `${Math.round((weight / roomTotal) * 100)}%`]), roomTotal)),
		previewCard("Enemies by depth", el("div", { class: "stack" }, [1, 5, 10, 20].map((depth) => {
			const entry = band(depth);
			return el("p", { class: "small", text: `Depth ${depth}: ${entry ? names(entry.normal) : "—"} · elites ${entry ? names(entry.elite) : "—"}` });
		}))),
		previewCard("Gem odds by colour", bars(byColor.map(([color, weight]) => [(state.registry.gem_colors[color] || {}).name || color, weight, (state.registry.gem_colors[color] || {}).hex, `${colorTotal ? Math.round((weight / colorTotal) * 100) : 0}%`]), colorTotal)),
	]);
}

function packPreview() {
	const authored = [];
	for (const section of SECTIONS) {
		if (["dice", "profiles", "mines"].includes(section.id)) continue;
		for (const id of Object.keys(entries(section.id)))
			if (!(state.registry[section.id] || []).includes(id)) authored.push([section.singular, id]);
	}
	const errors = state.issues.filter((issue) => issue.severity === "error").length;
	return el("div", {}, [
		previewCard("This pack", statGrid([
			["Status", errors ? `${errors} blocking error${errors === 1 ? "" : "s"}` : "loads clean"],
			["Unsaved edits", state.dirty ? "yes" : "no"],
			["Authored entries", String(authored.length)],
			["Schema", `v${state.content.schema_version}`],
		])),
		authored.length ? previewCard("Authored here", el("div", { class: "stack" },
			authored.map(([label, id]) => el("p", { class: "small", text: `${label} · ${id}` })))) : null,
		previewCard("How a new entry runs", [
			el("p", { class: "small muted", text: "Dice are pure data: a new die works the moment you save it." }),
			el("p", { class: "small muted", text: "A new gem, enemy or hero borrows a rule — an evaluator, a routine, a trait — and runs it under its own name, stats and art." }),
			el("p", { class: "small muted", text: "Relics, events and statuses are nothing but a code hook, so those need a rule in the build before the pack will load." }),
		]),
	]);
}

function textPreview(definition) {
	return previewCard(definition.name || state.selected, [
		el("p", { class: "muted", text: definition.description || "" }),
		statGrid(Object.entries(definition).filter(([key]) => !["name", "description"].includes(key)).map(([key, value]) => [titleCase(key), String(value)])),
	]);
}

function statGrid(rows) {
	return el("div", { class: "stat-grid" }, rows.filter(Boolean).map(([label, value]) => el("div", { class: "stat" }, [
		el("span", { class: "stat-label", text: label }),
		el("span", { class: "stat-value", text: value }),
	])));
}

// --- the issue drawer ---------------------------------------------------------

function showIssues() {
	const drawer = $("#issues");
	if (drawer.classList.contains("open")) return drawer.classList.remove("open");
	drawer.classList.add("open");
	mount(drawer, 
		el("header", {}, [
			el("h3", { text: state.issues.length ? `${state.issues.length} thing${state.issues.length === 1 ? "" : "s"} to look at` : "Everything checks out" }),
			el("button", { class: "ghost small", onclick: () => drawer.classList.remove("open") }, "Close"),
		]),
		el("div", { class: "issue-list" }, state.issues.length ? state.issues.map((issue) => el("button", {
			class: `issue ${issue.severity}`,
			onclick: () => {
				drawer.classList.remove("open");
				if (issue.section !== "pack") {
					state.section = issue.section;
					state.selected = issue.id || firstId(issue.section);
				}
				render();
			},
		}, [
			el("span", { class: "issue-where", text: `${issue.section}${issue.id ? ` / ${issue.id}` : ""}` }),
			el("span", { class: "issue-text", text: issue.message }),
		])) : [el("p", { class: "muted", text: "The pack passes every check this panel runs. Use “Validate in engine” to have Godot confirm it." })]),
	);
}

boot();
