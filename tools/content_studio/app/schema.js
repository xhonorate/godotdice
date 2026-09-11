// What each section of the pack is made of.
//
// One descriptor per field: what it is called, what kind of control edits it, and the
// bounds the engine's validator will hold it to. The editor, the new-entry defaults and
// the shape of every form come from here, so adding a field to the game means adding a
// line to this file rather than touching the panel.

export const SECTIONS = [
	{
		id: "heroes", label: "Heroes", singular: "Hero", glyph: "◆", idExample: "NEW_HERO",
		blurb: "A playable character: five dice, a trait, and the gems they start equipped with.",
		defaults: () => ({
			name: "New Hero", max_hp: 80, dice: ["D6", "D6", "D6", "D8", "D8"],
			trait: "STAND_FIRM", trait_name: "Stand Firm", description: "",
			starting_gems: [["STRIKE", 1, 1, 1], ["BLOCK", 1, 1, 1]], color: "9fd08b",
		}),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "color", label: "Seat colour", type: "hex", hint: "Tints this hero's seat, dice and banner." },
			{ key: "max_hp", label: "Maximum HP", type: "slider", min: 20, max: 200, step: 5 },
			{ key: "description", label: "Trait rules text", type: "textarea", hint: "What the player is told the trait does." },
			{ key: "trait", label: "Trait rule", type: "select", from: "traits", hint: "The registered behaviour that runs. A new hero has to borrow one of these." },
			{ key: "trait_name", label: "Trait name", type: "text" },
			{ key: "dice", label: "Starting dice", type: "dicelist", count: 5, hint: "Exactly five. Repeats are fine." },
			{ key: "starting_gems", label: "Starting gems", type: "gems", hint: "Equipped from the first room. One of them has to be Strike." },
		],
	},
	{
		id: "skills", label: "Gems", singular: "Gem", glyph: "◈", idExample: "NEW_GEM",
		blurb: "A skill a gem carries. Colour decides the cut and the category; the evaluator decides what it does.",
		defaults: () => ({
			name: "New Gem", color: "RED", rarity: 2, tags: ["attack"], target: "enemy",
			trigger: "Always", formula: "Damage (highest K dice + F(L)) × M(C).", evaluator_id: "STRIKE",
		}),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "color", label: "Colour", type: "select", from: "colors", hint: "The fourth C. It sets the stone's cut and the category of its effects." },
			{ key: "rule", label: "Rule", type: "rule", hint: "Write what this gem does, or borrow a rule the build already implements." },
			{ key: "evaluator_id", label: "Rule it borrows", type: "select", from: "evaluators", onlyWhen: "borrowed", hint: "Which registered formula resolves this gem." },
			{ key: "rarity", label: "Rarity", type: "slider", min: 1, max: 4, step: 1, names: ["", "Common", "Uncommon", "Rare", "Legendary"] },
			{ key: "target", label: "Target policy", type: "select", from: "targets" },
			{ key: "tags", label: "Trigger tags", type: "tags", from: "tags", hint: "What the hand has to contain. Drives the odds shown in the preview." },
			{ key: "trigger", label: "Trigger text", type: "text" },
			{ key: "formula", label: "Formula text", type: "textarea", hint: "Player-facing wording. M(C) is the Carat multiplier, F(L) the flat Clarity bonus, K the Cut." },
		],
	},
	{
		id: "dice", label: "Dice", singular: "Die", glyph: "▦", idExample: "NEW_D6",
		blurb: "A die shape and the faces printed on it. Faces may repeat and may skip values.",
		defaults: () => ({ name: "New Die", shape: "D6", faces: [1, 2, 3, 4, 5, 6], price: 8, unlock_act: 1 }),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "shape", label: "Shape", type: "select", from: "shapes", hint: "Decides the face count: a D8 has eight faces, whatever is printed on them." },
			{ key: "faces", label: "Faces", type: "faces" },
			{ key: "price", label: "Shop price", type: "slider", min: 1, max: 60, step: 1 },
			{ key: "unlock_act", label: "Reaches the shop in act", type: "slider", min: 0, max: 3, step: 1, names: ["Never sold", "Act 1", "Act 2", "Act 3"] },
			{ key: "unlock_room", label: "…or from room", type: "slider", min: 0, max: 18, step: 1, hint: "Single-act profiles only, where there is no later act to wait for. 0 disables it." },
		],
	},
	{
		id: "relics", label: "Relics", singular: "Relic", glyph: "✦", idExample: "NEW_RELIC",
		blurb: "A passive the hero equips. The effect itself lives in the rules build, so a relic ID has to be registered before the pack can carry it.",
		codeOnly: true,
		defaults: () => ({ name: "New Relic", description: "" }),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "description", label: "Rules text", type: "textarea" },
		],
	},
	{
		id: "enemies", label: "Enemies", singular: "Enemy", glyph: "☠", idExample: "NEW_ENEMY",
		blurb: "Health, block, dice and the routine that picks its intents each turn.",
		defaults: () => ({ name: "New Enemy", max_hp: 24, block: 0, dice: ["D6", "D6"], threat: 1, description: "", ai: "SLIME" }),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "description", label: "Intent summary", type: "textarea", hint: "What the player is told to expect from its turns." },
			{ key: "ai", label: "Routine it runs", type: "select", from: "enemy_ai", hint: "Which registered enemy's intent pattern this one uses." },
			{ key: "max_hp", label: "Base HP", type: "slider", min: 4, max: 200, step: 1, hint: "Act 2 and 3 scale this; a boss multiplies it by the party size instead." },
			{ key: "block", label: "Starting block", type: "slider", min: 0, max: 40, step: 1 },
			{ key: "threat", label: "Threat", type: "slider", min: 0, max: 3, step: 1, hint: "How the encounter builder weighs it. Bosses leave this out." },
			{ key: "boss", label: "Boss", type: "checkbox", hint: "Bosses scale with party size, keep Resolve, and roll no dice of their own." },
			{ key: "dice", label: "Dice", type: "dicelist", count: 0, hint: "What it rolls each turn. Bosses use a fixed script, so they usually have none." },
		],
	},
	{
		id: "events", label: "Events", singular: "Event", glyph: "❖", idExample: "NEW_EVENT",
		blurb: "A room with a choice. The branch logic lives in the rules build, so an event ID has to be registered first.",
		codeOnly: true,
		defaults: () => ({ name: "New Event", description: "" }),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "description", label: "Choice text", type: "textarea" },
		],
	},
	{
		id: "profiles", label: "Run profiles", singular: "Profile", glyph: "▤", idExample: "new_run",
		blurb: "A campaign: how long it runs, what drops in it, and what it sends at the party.",
		lowercaseIds: true,
		defaults: () => ({
			rooms: 9, acts: 1, loot_generator: "depth_luck_v1", combat_gold_cap: [8],
			skill_ids: ["STRIKE", "BLOCK", "HEAL"], relic_ids: ["MATCHBOX"], boss_ids: ["SLIME_KING"],
		}),
		fields: [
			{ key: "rooms", label: "Rooms", type: "slider", min: 3, max: 40, step: 1 },
			{ key: "acts", label: "Acts", type: "slider", min: 1, max: 3, step: 1 },
			{ key: "loot_generator", label: "Loot generator", type: "select", from: "loot_generators", hint: "depth_luck_v1 rolls against luck; act_tier_v1 uses fixed per-act tables." },
			{ key: "combat_gold_cap", label: "Battle gold allowance", type: "numbers", perAct: true, hint: "One per act: how much gold a single battle can pay out." },
			{ key: "boss_ids", label: "Act bosses", type: "idlist", section: "enemies", perAct: true },
			{ key: "skill_ids", label: "Gem pool", type: "idset", section: "skills" },
			{ key: "relic_ids", label: "Relic pool", type: "idset", section: "relics" },
			{ key: "encounters", label: "Encounter table", type: "encounters", hint: "Optional. Without one, this profile uses the shipped encounter list." },
		],
	},
	{
		id: "statuses", label: "Statuses", singular: "Status", glyph: "✧", idExample: "poison",
		blurb: "The three tracked conditions. Their hooks are compiled in; the wording and the stack cap are yours.",
		codeOnly: true, lowercaseIds: true, fixedIds: ["stun", "poison", "resolve"],
		defaults: () => ({ name: "New Status", description: "", hook: "end_slot", cap: 1 }),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "description", label: "Rules text", type: "textarea" },
			{ key: "hook", label: "Ticks at", type: "select", options: ["start_slot", "end_slot"] },
			{ key: "cap", label: "Stack cap", type: "slider", min: -1, max: 24, step: 1, hint: "-1 is uncapped." },
		],
	},
];

export const SECTION_BY_ID = Object.fromEntries(SECTIONS.map((section) => [section.id, section]));

/** Rank labels the whole panel shares with the game. */
export const CUT_NAMES = ["Poor", "Fair", "Good", "Great", "Perfect"];
export const CLARITY_NAMES = ["Fractured", "Flawed", "Clean", "Pristine", "Flawless"];
export const RARITY_NAMES = ["", "Common", "Uncommon", "Rare", "Legendary"];

/** The two rank curves, straight out of `combat.gd`. */
export const caratMultiplier = (carat) => (Math.min(24, Math.max(1, carat)) + 7) / 8;
export const clarityBonus = (clarity) => 2 * Math.min(5, Math.max(1, clarity));
export const cutMultiplier = (cut) => (Math.min(5, Math.max(1, cut)) + 3) / 4;
/** `Catalog.gem_value()`: what a gem sells and trades for. */
export const gemValue = (rarity, carat, cut, clarity) =>
	rarity * (carat + 2 * (cut - 1) + 2 * (clarity - 1));
/** `Catalog.enemy()`: how an enemy's printed health reaches the table. */
export const enemyHp = (maxHp, act, partySize, boss) =>
	boss ? maxHp * partySize : Math.ceil(maxHp * [1.0, 1.35, 1.75][Math.min(3, Math.max(1, act)) - 1]);
export const enemyBlock = (block, act, partySize, boss) =>
	boss ? block * partySize : Math.trunc(block * [1.0, 1.2, 1.4][Math.min(3, Math.max(1, act)) - 1]);
