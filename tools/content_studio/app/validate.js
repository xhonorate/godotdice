// The same checks `scripts/core/content_pack.gd` runs, in the browser and as you type.
//
// Keeping a copy here is a deliberate duplication: the engine still owns the verdict, and
// the Validate button runs the real thing. What this buys is the error appearing on the
// field that caused it, in the same keystroke, instead of after a save and a launch.

import * as Rules from "./rules.js";

const REQUIRED_SECTIONS = ["heroes", "skills", "dice", "relics", "enemies"];

const isInteger = (value) => typeof value === "number" && Number.isFinite(value) && Math.floor(value) === value;
const isPositive = (value) => isInteger(value) && value > 0;

/**
 * @returns {Array<{section, id, field, message, severity}>} every problem, worst first.
 */
export function validatePack(content, registry) {
	const issues = [];
	const add = (severity, section, id, field, message) => issues.push({ severity, section, id, field, message });

	if (content.schema_version !== 1 || !String(content.content_version || "") || !String(content.pack_id || ""))
		add("error", "pack", "", "pack_id", "The pack needs a schema version of 1, a content version and a pack ID.");

	for (const section of REQUIRED_SECTIONS) {
		const entries = content[section] || {};
		if (!Object.keys(entries).length) add("error", section, "", "", `Section ${section} is empty.`);
		if (content.pack_id === "full") {
			for (const registered of registry[section] || [])
				if (!entries[registered])
					add("error", section, registered, "", `The build registers ${registered}, so a pack called "full" has to carry it. Deleting it will stop the game loading.`);
		}
	}

	for (const [section, entries] of Object.entries(content)) {
		if (typeof entries !== "object" || Array.isArray(entries) || !registryFor(section)) continue;
		for (const [id, entry] of Object.entries(entries)) {
			if (typeof entry !== "object" || Array.isArray(entry)) {
				add("error", section, id, "", "Definition must be an object.");
				continue;
			}
			if (!entry.name || typeof entry.name !== "string")
				add("error", section, id, "name", "Needs a display name.");
			const rule = ruleProblem(section, id, entry, registry);
			if (rule) add("error", section, id, rule.field, rule.message);
		}
	}

	for (const [id, entry] of Object.entries(content.skills || {})) {
		if (!isPositive(entry.rarity) || entry.rarity > 4) add("error", "skills", id, "rarity", "Rarity is 1 to 4.");
		if (!(registry.targets || []).includes(entry.target)) add("error", "skills", id, "target", `Unknown target policy ${entry.target}.`);
		if (!(registry.colors || []).includes(entry.color)) add("error", "skills", id, "color", `Unknown gem colour ${entry.color}.`);
		if (!Array.isArray(entry.tags)) add("error", "skills", id, "tags", "Tags must be a list.");
		else for (const tag of entry.tags)
			if (!(registry.tags || []).includes(tag)) add("error", "skills", id, "tags", `Unknown trigger tag ${tag}.`);
		for (const problem of Rules.hasRule(entry) ? Rules.validate(entry.rule) : [])
			add("error", "skills", id, "rule", problem);
		if (Rules.hasRule(entry) && !Rules.validate(entry.rule).length) {
			// The policy decides whether the player is asked to pick a target at all, so a
			// rule that never touches an enemy should not be asking for one.
			const targets = (entry.rule.effects || []).map((effect) => String(effect.target ?? "self"));
			const hostile = targets.some((target) => ["enemy", "enemies"].includes(target));
			if (hostile && !["enemy", "enemies"].includes(entry.target))
				add("warn", "skills", id, "target", `The rule hits enemies, but the targeting policy is “${entry.target}”, so the player is never asked which one.`);
			if (!hostile && ["enemy", "enemies"].includes(entry.target))
				add("warn", "skills", id, "target", "The targeting policy asks the player to pick an enemy, but no effect in the rule reaches one.");
		}
		if (!String(entry.trigger || "")) add("warn", "skills", id, "trigger", "No trigger text: the player is told nothing about when this fires.");
		if (!String(entry.formula || "")) add("warn", "skills", id, "formula", "No formula text: the gem panel will be blank.");
	}

	for (const [id, entry] of Object.entries(content.dice || {})) {
		if (!isPositive(entry.price)) add("error", "dice", id, "price", "Price must be a positive whole number.");
		const shape = String(entry.shape || "");
		if (!(registry.shapes || []).includes(shape)) {
			add("error", "dice", id, "shape", `Unknown die shape ${shape || "(none)"}.`);
			continue;
		}
		const sides = parseInt(shape.replace("D", ""), 10);
		if (!Array.isArray(entry.faces) || entry.faces.length !== sides)
			add("error", "dice", id, "faces", `A ${shape} needs exactly ${sides} faces; this has ${Array.isArray(entry.faces) ? entry.faces.length : 0}.`);
		else for (const face of entry.faces)
			if (!isInteger(face) || face < 1 || face > sides) {
				add("error", "dice", id, "faces", `Every face has to be a whole number from 1 to ${sides}.`);
				break;
			}
		if (entry.unlock_act !== undefined && (!isInteger(entry.unlock_act) || entry.unlock_act < 0 || entry.unlock_act > 3))
			add("error", "dice", id, "unlock_act", "Shop unlock act is 0 (never sold) to 3.");
		if (entry.unlock_room !== undefined && (!isInteger(entry.unlock_room) || entry.unlock_room < 0))
			add("error", "dice", id, "unlock_room", "Shop unlock room cannot be negative.");
	}

	for (const [id, entry] of Object.entries(content.heroes || {})) {
		if (!isPositive(entry.max_hp)) add("error", "heroes", id, "max_hp", "Maximum HP must be a positive whole number.");
		if (!Array.isArray(entry.dice) || entry.dice.length !== 5)
			add("error", "heroes", id, "dice", "A hero rolls exactly five dice.");
		else for (const die of entry.dice)
			if (!(content.dice || {})[die]) add("error", "heroes", id, "dice", `No such die: ${die}.`);
		const starters = entry.starting_gems;
		if (!Array.isArray(starters) || !starters.length || starters.length > 6) {
			add("error", "heroes", id, "starting_gems", "Between one and six starting gems.");
		} else {
			const seen = [];
			for (const starter of starters) {
				if (!Array.isArray(starter) || starter.length < 2 || starter.length > 4 || !(content.skills || {})[starter[0]]
					|| !isPositive(starter[1]) || starter[1] > 24) {
					add("error", "heroes", id, "starting_gems", "Each starting gem is [gem, carat] or [gem, carat, cut, clarity], with carat 1-24.");
					continue;
				}
				if ((starter.length > 2 && (!isPositive(starter[2]) || starter[2] > 5)) || (starter.length > 3 && (!isPositive(starter[3]) || starter[3] > 5)))
					add("error", "heroes", id, "starting_gems", "Cut and clarity are 1 to 5.");
				else if (seen.includes(starter[0])) add("error", "heroes", id, "starting_gems", `${starter[0]} is equipped twice.`);
				else seen.push(starter[0]);
			}
			if (!seen.includes("STRIKE")) add("error", "heroes", id, "starting_gems", "Every hero starts with Strike equipped.");
		}
		if (!(registry.traits || []).includes(entry.trait)) add("error", "heroes", id, "trait", `Unknown trait ${entry.trait}.`);
		if (!String(entry.trait_name || "")) add("warn", "heroes", id, "trait_name", "The trait has no name to show on the hero's banner.");
	}

	for (const [id, entry] of Object.entries(content.enemies || {})) {
		if (!isPositive(entry.max_hp)) add("error", "enemies", id, "max_hp", "Maximum HP must be a positive whole number.");
		if (!isInteger(entry.block) || entry.block < 0) add("error", "enemies", id, "block", "Starting block must be zero or more.");
		if (!Array.isArray(entry.dice)) add("error", "enemies", id, "dice", "Dice must be a list.");
		else for (const die of entry.dice)
			if (!(content.dice || {})[die]) add("error", "enemies", id, "dice", `No such die: ${die}.`);
		if (!entry.boss && !Array.isArray(entry.dice)) continue;
		if (!entry.boss && Array.isArray(entry.dice) && !entry.dice.length)
			add("warn", "enemies", id, "dice", "No dice: this enemy rolls nothing, so a routine that reads its hand has nothing to read.");
	}

	for (const [id, entry] of Object.entries(content.profiles || {})) {
		if (typeof entry !== "object" || !Array.isArray(entry.skill_ids)) {
			add("error", "profiles", id, "skill_ids", "A profile needs a gem pool.");
			continue;
		}
		for (const skill of entry.skill_ids)
			if (!(content.skills || {})[skill]) add("error", "profiles", id, "skill_ids", `No such gem: ${skill}.`);
		for (const relic of entry.relic_ids || [])
			if (!(content.relics || {})[relic]) add("error", "profiles", id, "relic_ids", `No such relic: ${relic}.`);
		for (const boss of entry.boss_ids || [])
			if (!(content.enemies || {})[boss]) add("error", "profiles", id, "boss_ids", `No such enemy: ${boss}.`);
		if (!(registry.loot_generators || []).includes(entry.loot_generator))
			add("error", "profiles", id, "loot_generator", `Unregistered loot generator ${entry.loot_generator}.`);
		const acts = Number(entry.acts || 1);
		if ((entry.boss_ids || []).length < acts) add("error", "profiles", id, "boss_ids", `${acts} acts need ${acts} bosses.`);
		if ((entry.combat_gold_cap || []).length < acts) add("error", "profiles", id, "combat_gold_cap", `${acts} acts need ${acts} gold allowances.`);
		if (!entry.skill_ids.includes("STRIKE")) add("warn", "profiles", id, "skill_ids", "Strike is missing from the pool, so no drop can ever replace a lost one.");
		issues.push(...encounterIssues(id, entry.encounters, content));
	}

	for (const id of Object.keys(content.statuses || {}))
		if (!(registry.statuses || []).includes(id))
			add("error", "statuses", id, "", `Only ${(registry.statuses || []).join(", ")} are tracked by the rules build.`);

	for (const profileId of ["short_9", "expedition_18"])
		if (content.pack_id === "full" && !(content.profiles || {})[profileId])
			add("error", "profiles", profileId, "", `A pack called "full" has to carry the ${profileId} profile.`);

	return issues.sort((a, b) => (a.severity === b.severity ? 0 : a.severity === "error" ? -1 : 1));
}

function registryFor(section) {
	return ["heroes", "skills", "dice", "relics", "enemies", "events", "statuses"].includes(section) ? section : null;
}

/** Whether this entry has a rule to run, and what it is missing if not. */
export function ruleProblem(section, id, entry, registry) {
	if (section === "dice" || section === "profiles") return null;
	if ((registry[section] || []).includes(id)) return null;
	switch (section) {
		case "skills":
			if (Rules.hasRule(entry)) return Rules.validate(entry.rule).length ? { field: "rule", message: "This gem's own rule does not hold together yet." } : null;
			return (registry.evaluators || []).includes(String(entry.evaluator_id || "")) ? null
				: { field: "rule", message: "A gem the build does not register needs a rule of its own, or has to borrow a registered one." };
		case "enemies":
			return (registry.enemy_ai || []).includes(String(entry.ai || "")) ? null
				: { field: "ai", message: "An enemy the build does not register has to borrow a registered routine through “Routine it runs”." };
		case "heroes":
			return (registry.traits || []).includes(String(entry.trait || "")) ? null
				: { field: "trait", message: "A hero the build does not register has to borrow a registered trait." };
		default:
			return { field: "", message: `${section} are behaviour with no data hook, so this ID has to be registered in the rules build before the pack can carry it.` };
	}
}

function encounterIssues(profileId, table, content) {
	const issues = [];
	const add = (field, message, severity = "error") => issues.push({ severity, section: "profiles", id: profileId, field, message });
	if (!table || typeof table !== "object" || !Object.keys(table).length) return issues;
	for (const group of Object.keys(table))
		if (!["first_room", "normal", "elite", "boss"].includes(group))
			add("encounters", `Unknown encounter group “${group}”.`);
	const known = (key) => Boolean((content.enemies || {})[key]);
	for (const field of ["first_room", "boss"])
		if (table[field] !== undefined) {
			if (!Array.isArray(table[field])) add("encounters", `${field} must be a list of enemy IDs.`);
			else for (const key of table[field]) if (!known(key)) add("encounters", `${field}: no such enemy ${key}.`);
		}
	const groups = (list, label) => {
		if (!Array.isArray(list)) return add("encounters", `${label} must be a list of groups, one per party size.`);
		list.forEach((group, index) => {
			if (!Array.isArray(group)) return add("encounters", `${label}: entry ${index + 1} must be a list of enemy IDs.`);
			for (const key of group) if (!known(key)) add("encounters", `${label}: no such enemy ${key}.`);
		});
		if (list.length < 4) add("encounters", `${label} covers ${list.length} of 4 party sizes; the largest listed group is reused above that.`, "warn");
	};
	if (table.elite !== undefined) groups(table.elite, "elite");
	if (table.normal !== undefined) {
		if (typeof table.normal !== "object" || Array.isArray(table.normal)) add("encounters", "normal must be an object keyed by act.");
		else for (const [act, list] of Object.entries(table.normal)) {
			if (!["1", "2", "3"].includes(String(act))) add("encounters", `normal: act ${act} is outside 1-3.`);
			else groups(list, `normal/act ${act}`);
		}
	}
	return issues;
}

/** Everything that would break if this entry disappeared. */
export function referencesTo(content, section, id) {
	const found = [];
	if (section === "dice") {
		for (const group of ["heroes", "enemies"])
			for (const [key, entry] of Object.entries(content[group] || {}))
				if ((entry.dice || []).includes(id)) found.push({ section: group, id: key, why: "rolls this die" });
	}
	if (section === "skills") {
		for (const [key, entry] of Object.entries(content.heroes || {}))
			if ((entry.starting_gems || []).some((starter) => starter[0] === id)) found.push({ section: "heroes", id: key, why: "starts with this gem" });
		for (const [key, entry] of Object.entries(content.profiles || {}))
			if ((entry.skill_ids || []).includes(id)) found.push({ section: "profiles", id: key, why: "has it in the gem pool" });
		for (const [key, entry] of Object.entries(content.skills || {}))
			if (key !== id && entry.evaluator_id === id) found.push({ section: "skills", id: key, why: "borrows its rule" });
	}
	if (section === "relics")
		for (const [key, entry] of Object.entries(content.profiles || {}))
			if ((entry.relic_ids || []).includes(id)) found.push({ section: "profiles", id: key, why: "has it in the relic pool" });
	if (section === "enemies") {
		for (const [key, entry] of Object.entries(content.profiles || {})) {
			if ((entry.boss_ids || []).includes(id)) found.push({ section: "profiles", id: key, why: "uses it as an act boss" });
			if (JSON.stringify(entry.encounters || {}).includes(`"${id}"`)) found.push({ section: "profiles", id: key, why: "spawns it in an encounter" });
		}
		for (const [key, entry] of Object.entries(content.enemies || {}))
			if (key !== id && entry.ai === id) found.push({ section: "enemies", id: key, why: "borrows its routine" });
	}
	return found;
}
