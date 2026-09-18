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
			sockets: ["RED", "BLUE", "ANY", "ANY", "BLUE", "GREEN"], signature: "UNBREAKABLE_VOW",
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
		defaults: () => ({ name: "New Die", shape: "D6", faces: [1, 2, 3, 4, 5, 6], price: 8, unlock_depth: 1 }),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "shape", label: "Shape", type: "select", from: "shapes", hint: "Decides the face count: a D8 has eight faces, whatever is printed on them." },
			{ key: "faces", label: "Faces", type: "faces" },
			{ key: "price", label: "Shop price", type: "slider", min: 1, max: 60, step: 1 },
			{ key: "unlock_depth", label: "Merchants stock it from depth", type: "slider", min: 0, max: 40, step: 1, hint: "0 means no merchant ever sells it." },
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
			{ key: "max_hp", label: "Base HP", type: "slider", min: 4, max: 200, step: 1, hint: "Grows 6% per layer of depth; a boss multiplies it by the party size and grows at most 60%." },
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
		id: "mines", label: "Mines", singular: "Mine", glyph: "⛏", idExample: "CRYSTAL_DEEP",
		blurb: "An expedition: the boss the tremor meter wakes, what spawns as the party digs deeper, what the rocks give up, and where it sits on the atlas.",
		defaults: () => ({
			name: "New Mine", description: "", difficulty: 1, boss_id: "SLIME_KING", links: [],
			atlas_x: 50, atlas_y: 50, color: "c9a26b", tremor_rate: 100, lift_rate: 100, quality_bonus: 0,
			rooms: { battle: 6, elite: 1, mine: 3, rest: 2, event: 2 },
			bands: [{ from_depth: 1, normal: { SLIME: 1 }, elite: { RED_SLIME: 1 } }],
			skill_ids: ["BLOCK", "HEAL", "STRIKE"], color_weights: {}, relic_ids: [],
		}),
		fields: [
			{ key: "name", label: "Display name", type: "text" },
			{ key: "description", label: "Atlas description", type: "textarea", hint: "What the preview panel on the wall map says about it." },
			{ key: "starter", label: "Starter mine", type: "checkbox", hint: "Unlocked on a brand-new profile. Every other mine has to be reachable from one." },
			{ key: "difficulty", label: "Difficulty", type: "slider", min: 1, max: 5, step: 1, names: ["Gentle", "Steady", "Hard", "Brutal", "Deadly"] },
			{ key: "boss_id", label: "Boss", type: "bossselect", hint: "Breaks through when the tremor meter fills, at whatever depth the party is." },
			{ key: "links", label: "Unlocks", type: "idset", section: "mines", hint: "Killing this mine's boss unlocks these, and shows them on the atlas as silhouettes until then." },
			{ key: "atlas_x", label: "Atlas position ←→", type: "slider", min: 0, max: 100, step: 1 },
			{ key: "atlas_y", label: "Atlas position ↑↓", type: "slider", min: 0, max: 100, step: 1 },
			{ key: "color", label: "Atlas colour", type: "hex" },
			{ key: "tremor_rate", label: "Tremor rate %", type: "slider", min: 10, max: 500, step: 5, hint: "How fast the boss meter fills here, against the standard 100." },
			{ key: "lift_rate", label: "Lift rate %", type: "slider", min: 10, max: 500, step: 5, hint: "How often lifts appear, against the standard 100. Fewer lifts make leaving a gamble." },
			{ key: "quality_bonus", label: "Loot quality bonus", type: "slider", min: 0, max: 30, step: 1, hint: "Added to depth when rolling gems. Quality moves rarity, Carat, Cut and Clarity together." },
			{ key: "rooms", label: "Room weights", type: "weights", from: "mine_rooms", hint: "How often each room kind fills a node. Lifts and the boss lair are placed separately." },
			{ key: "bands", label: "What spawns by depth", type: "bands", hint: "Each band starts at a depth and runs until the next. Weights pick enemies to fill the fight." },
			{ key: "skill_ids", label: "Gem pool", type: "idset", section: "skills" },
			{ key: "color_weights", label: "Colour weights %", type: "weights", from: "colors", fallback: 100, hint: "Leaning the pool toward a colour. 100 is neutral; 0 removes that colour." },
			{ key: "relic_ids", label: "Relic pool", type: "idset", section: "relics" },
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
/** `Catalog.enemy()`: how an enemy's printed health reaches the table at a depth. */
export const enemyHp = (maxHp, depth, partySize, boss) => {
	const level = Math.max(1, depth);
	return boss ? Math.ceil(maxHp * partySize * (1 + Math.min(0.6, 0.03 * (level - 1)))) : Math.ceil(maxHp * (1 + 0.06 * (level - 1)));
};
export const enemyBlock = (block, depth, partySize, boss) =>
	boss ? block * partySize : Math.floor((block * (100 + 3 * (Math.max(1, depth) - 1))) / 100);
