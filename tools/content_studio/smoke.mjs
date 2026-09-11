// Drives the studio headlessly against the running server: boots it, opens every section,
// selects every entry, and edits one field of each kind. Any throw fails the run.
const BASE = process.env.STUDIO || "http://127.0.0.1:8791";

const ctxStub = () => new Proxy({}, {
	get: (target, key) => {
		if (key === "createLinearGradient") return () => ({ addColorStop() {} });
		if (key === "measureText") return () => ({ width: 10 });
		if (typeof target[key] === "undefined") return () => {};
		return target[key];
	},
	set: () => true,
});

let created = 0;
function makeNode(tag) {
	const node = {
		tag, tagName: tag.toUpperCase(), children: [], attrs: {}, handlers: {}, style: {},
		className: "", textContent: "", innerHTML: "", value: "", checked: false,
		classList: {
			set: new Set(),
			add(name) { this.set.add(name); },
			remove(name) { this.set.delete(name); },
			contains(name) { return this.set.has(name); },
		},
		setAttribute(key, value) { node.attrs[key] = value; if (key === "value") node.value = value; },
		getAttribute(key) { return node.attrs[key]; },
		addEventListener(name, handler) { (node.handlers[name] = node.handlers[name] || []).push(handler); },
		append(...items) { for (const item of items) if (item) node.children.push(typeof item === "string" ? { tag: "#text", textContent: item } : item); },
		replaceChildren(...items) { node.children = items.filter(Boolean).map((item) => (typeof item === "string" ? { tag: "#text", textContent: item } : item)); },
		remove() {},
		focus() {},
		querySelector() { return null; },
		fire(name, event = {}) {
			for (const handler of node.handlers[name] || []) handler({ target: node, preventDefault() {}, ...event });
		},
	};
	if (tag === "canvas") {
		node.getContext = () => ctxStub();
		node.width = 0;
		node.height = 0;
	}
	created += 1;
	return node;
}

const shell = {};
for (const id of ["topbar", "rail", "list", "editor", "preview", "status", "issues"]) shell[id] = makeNode("div");

global.window = {
	devicePixelRatio: 1,
	addEventListener() {},
	matchMedia: () => ({ matches: false, addEventListener() {} }),
};
global.document = {
	createElement: makeNode,
	createTextNode: (text) => ({ tag: "#text", textContent: text }),
	querySelector: (selector) => shell[selector.replace("#", "")] || null,
	activeElement: { tagName: "BODY" },
	body: makeNode("body"),
	addEventListener() {},
};

global.confirm = () => true;
global.alert = (text) => console.log("   alert:", text);
let promptAnswer = "TEST_ENTRY";
global.prompt = () => promptAnswer;
const realFetch = global.fetch;
global.fetch = (path, options) => realFetch(path.startsWith("http") ? path : BASE + (path.startsWith("/") ? path : "/" + path), options);

// --- walking the rendered tree -------------------------------------------------

function walk(node, visit) {
	if (!node || typeof node !== "object") return;
	visit(node);
	for (const child of node.children || []) walk(child, visit);
}
function collect(node, predicate) {
	const found = [];
	walk(node, (item) => {
		if (predicate(item)) found.push(item);
	});
	return found;
}
const text = (node) => {
	let out = node.textContent || "";
	for (const child of node.children || []) out += text(child);
	return out;
};
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const failures = [];
function step(label, action) {
	try {
		action();
		console.log(` ok   ${label}`);
	} catch (error) {
		failures.push(`${label}: ${error.message}`);
		console.log(` FAIL ${label}: ${error.message}\n      ${String(error.stack).split("\n")[1]}`);
	}
}

await import("./app/app.js").catch((error) => {
	console.log("import failed:", error.message);
	process.exit(1);
});
await sleep(700);

step("boots and renders the shell", () => {
	if (!shell.rail.children.length) throw new Error("no rail");
	if (!shell.list.children.length) throw new Error("no list");
	if (!shell.editor.children.length) throw new Error("no editor");
	if (!shell.preview.children.length) throw new Error("no preview");
});

const railButtons = collect(shell.rail, (node) => node.tag === "button");
console.log(`\n${railButtons.length} rail sections, ${created} nodes built so far\n`);

for (const button of railButtons) {
	const label = text(button).replace(/\d+$/, "").trim();
	step(`section “${label}” opens`, () => {
		button.fire("click");
		if (!shell.editor.children.length) throw new Error("editor did not render");
	});
	const rows = collect(shell.list, (node) => node.className?.startsWith("row"));
	step(`  every ${label} entry selects, edits and previews`, () => {
		for (const row of rows.slice(0, 40)) {
			row.fire("click");
			if (!shell.editor.children.length) throw new Error("empty editor");
		}
		// Touch one control of each kind on the last entry.
		for (const input of collect(shell.editor, (node) => node.tag === "input" && node.attrs?.type === "text"))
			input.fire("change", { target: { ...input, value: `${input.value || ""}` } });
		for (const select of collect(shell.editor, (node) => node.tag === "select").slice(0, 3)) {
			const option = collect(select, (node) => node.tag === "option")[0];
			if (option) select.fire("change", { target: { value: option.attrs?.value } });
		}
		for (const range of collect(shell.editor, (node) => node.attrs?.type === "range").slice(0, 2))
			range.fire("change", { target: { value: String(range.attrs?.min ?? 1) } });
		for (const toggle of collect(shell.editor, (node) => node.className === "chip-toggle").slice(0, 2))
			toggle.fire("click");
	});
}

// Creating and deleting an entry in each authorable section.
for (const [index, button] of railButtons.entries()) {
	const label = text(button).replace(/\d+$/, "").trim();
	if (label.includes("Pack")) continue;
	step(`new ${label} entry can be created and deleted`, () => {
		button.fire("click");
		promptAnswer = `SMOKE_${index}`;
		const add = collect(shell.list, (node) => node.tag === "button" && text(node).startsWith("+"))[0];
		if (!add) throw new Error("no add button");
		add.fire("click");
		const del = collect(shell.editor, (node) => node.tag === "button" && text(node) === "Delete")[0];
		if (!del) throw new Error("no delete button");
		del.fire("click");
	});
}

// --- the rule builder ---------------------------------------------------------

const byClass = (root, name) => collect(root, (node) => String(node.className || "").split(" ").includes(name));
const byText = (root, wanted) => collect(root, (node) => node.tag === "button" && text(node).includes(wanted))[0];
const selectsIn = (node) => collect(node, (item) => item.tag === "select");
const openGems = () => {
	railButtons.find((button) => text(button).includes("Gems")).fire("click");
	collect(shell.list, (node) => node.className?.startsWith("row"))[0].fire("click");
};

step("a gem can be given a rule of its own", () => {
	openGems();
	const start = byText(shell.editor, "Write its own rule");
	if (!start) throw new Error("no button to start a rule");
	start.fire("click");
	if (!byClass(shell.editor, "rule").length) throw new Error("the rule editor did not appear");
	if (!byClass(shell.preview, "bench-hand").length) throw new Error("the bench did not appear");
});

step("every trigger can be chosen", () => {
	const kinds = ["always", "pair", "two_pairs", "triple", "full_house", "straight", "parity",
		"distinct", "value", "total_at_least", "total_at_most", "high_at_least"];
	for (const kind of kinds) {
		const section = byClass(shell.editor, "rule-section")[0];
		selectsIn(section)[0].fire("change", { target: { value: kind } });
		if (!byClass(shell.editor, "rule").length) throw new Error(`editor vanished on ${kind}`);
		if (byClass(shell.editor, "rule-errors").length) throw new Error(`${kind} produced a rule the validator rejects`);
	}
});

step("every effect kind and target can be chosen", () => {
	for (const kind of ["damage", "block", "heal", "gold", "poison", "stun", "remove_block"]) {
		const effect = byClass(shell.editor, "effect")[0];
		selectsIn(effect)[0].fire("change", { target: { value: kind } });
	}
	for (const target of ["self", "enemy", "enemies", "ally", "other_allies"]) {
		const effect = byClass(shell.editor, "effect")[0];
		selectsIn(effect)[1].fire("change", { target: { value: target } });
	}
	if (byClass(shell.editor, "rule-errors").length) throw new Error("a legal effect was rejected");
});

step("every kind of amount node can be built", () => {
	for (const kind of ["const", "term", "rank", "op"]) {
		const node = byClass(shell.editor, "expr-kind")[0];
		node.fire("change", { target: { value: kind } });
		if (byClass(shell.editor, "rule-errors").length) throw new Error(`a ${kind} node was rejected`);
	}
	// The tree is an operation now: walk its operators and its terms.
	for (const operator of ["+", "-", "*", "floor_div", "min", "max", "by_cut"]) {
		const heads = byClass(shell.editor, "expr-head");
		const operatorSelect = selectsIn(heads[0])[1];
		operatorSelect.fire("change", { target: { value: operator } });
		if (byClass(shell.editor, "rule-errors").length) throw new Error(`operator ${operator} was rejected`);
	}
	const add = byText(shell.editor, "+ Add a part");
	if (add) add.fire("click");
	const terms = ["high", "low", "total", "pair_value", "triple_value", "run_high", "highest_sum",
		"lowest_sum", "lowest_odd", "count_even", "count_odd", "count_distinct", "count_value", "block"];
	for (const term of terms) {
		const child = byClass(shell.editor, "expr-head")[1];
		selectsIn(child)[0].fire("change", { target: { value: "term" } });
		const withTerm = byClass(shell.editor, "expr-head")[1];
		selectsIn(withTerm)[1].fire("change", { target: { value: term } });
		if (byClass(shell.editor, "rule-errors").length) throw new Error(`term ${term} was rejected`);
	}
});

step("repeats, target limits and extra effects can be added", () => {
	const repeat = byText(shell.editor, "+ Repeat it");
	if (repeat) repeat.fire("click");
	const more = byText(shell.editor, "+ Add an effect");
	if (!more) throw new Error("no way to add an effect");
	more.fire("click");
	if (byClass(shell.editor, "effect").length < 2) throw new Error("the second effect did not appear");
	if (byClass(shell.editor, "rule-errors").length) throw new Error("a second effect was rejected");
});

step("the bench runs the rule on a hand you can change", () => {
	const dice = byClass(shell.preview, "bench-die");
	if (dice.length !== 5) throw new Error(`expected five dice, found ${dice.length}`);
	dice[0].fire("change", { target: { value: "7" } });
	const roll = collect(shell.preview, (node) => node.tag === "button" && text(node) === "Ardor")[0];
	if (roll) roll.fire("click");
	if (!byClass(shell.preview, "bench-verdict").length) throw new Error("the bench reported nothing");
});

step("the rule can write the gem's rules text, then be given back", () => {
	byText(shell.editor, "Write this into the gem").fire("click");
	const borrow = byText(shell.editor, "Borrow a rule instead");
	if (!borrow) throw new Error("no way back to a borrowed rule");
	borrow.fire("click");
	if (byClass(shell.editor, "rule").length) throw new Error("the rule was not removed");
});

step("issue drawer opens", () => {
	const chip = collect(shell.topbar, (node) => node.className?.startsWith("chip"))[0];
	chip.fire("click");
	if (!shell.issues.classList.contains("open")) throw new Error("drawer did not open");
});

console.log(`\n${created} DOM nodes built · ${failures.length} failures`);
process.exit(failures.length ? 1 : 0);
