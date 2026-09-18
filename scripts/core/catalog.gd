class_name RogueCatalog
extends RefCounted
## Immutable, versioned content and instance factories. Runtime objects are deep copies.
const RandomSource = preload("res://scripts/core/random_source.gd")
const ContentPack = preload("res://scripts/core/content_pack.gd")
const CONTENT_VERSION: String = "1.0.0"
static var _content_pack: Resource = null
const STANDARD_DICE: Array = ["D4", "D6", "D8", "D10", "D12", "D20"]
const BULWARK_BLOCK: Array = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 230, 250, 300]
const BULWARK_STUN: Array = [3, 2, 2, 1, 0]
## The four C's. Color is a fixed property of the skill definition; Carat, Cut and Clarity
## are rolled per gem instance. Color names the category of a gem's effects and is never
## generated, upgraded or sold; it exists so a build can be read at a glance.
const GEM_COLORS: Dictionary = {
	"RED": {"name": "Red", "hex": "e2564a", "role": "Damage"},
	"BLUE": {"name": "Blue", "hex": "5a8fd8", "role": "Block"},
	"GREEN": {"name": "Green", "hex": "6fbf73", "role": "Healing and revival"},
	"VIOLET": {"name": "Violet", "hex": "a97fe0", "role": "Control: stun and poison"},
	"GOLD": {"name": "Gold", "hex": "e0b64a", "role": "Fortune: ore and luck"},
	"WHITE": {"name": "White", "hex": "c6d4e8", "role": "Mastery: rerolls, dice and gems"}
}
const CUT_NAMES: Array = ["Poor", "Fair", "Good", "Great", "Perfect"]
const CLARITY_NAMES: Array = ["Fractured", "Flawed", "Clean", "Pristine", "Flawless"]
## Every hero is built around six gem sockets, and each socket takes one Color of gem — or,
## for a prismatic socket, any Color at all. The first is always Red and the second always
## Blue, so every hero can carry an attack and a defence; the rest are the hero's own. Only
## the first `LOADOUT_CARRY` sockets can be filled at home: the others open once the party is
## underground, for the stones it finds there.
const SOCKET_ANY: String = "ANY"
const SOCKET_COUNT: int = 6
const LOADOUT_CARRY: int = 3
const DEFAULT_SOCKETS: Array = ["RED", "BLUE", "ANY", "ANY", "BLUE", "GREEN"]
## A hero has a passive trait, always working, and a signature: one very hard hand that does
## something enormous. Both are registered rules, so an authored hero borrows them by ID.
const TRAITS: Array = ["STAND_FIRM", "CALCULATED_RISK", "SECOND_THOUGHT"]
const SIGNATURES: Dictionary = {
	"UNBREAKABLE_VOW": {"name": "Unbreakable Vow", "description": "Every living hero gains 20 block. Then deal 12 + twice the matched value damage to every enemy."},
	"LONG_ODDS": {"name": "Long Odds", "description": "Deal damage equal to your total to your target twice, then stun it."},
	"MASTER_PLAN": {"name": "Master Plan", "description": "Deal 10 + the top of your run damage to every enemy and stun each of them."}
}
const HEROES: Dictionary = {
	"ARDOR": {"name": "Ardor", "max_hp": 100, "dice": ["D6", "D6", "D6", "D8", "D8"], "trait": "STAND_FIRM", "trait_name": "Stand Firm", "description": "Gain 2 block at the start of your turn when your final hand contains a pair.", "starting_gems": [["STRIKE", 1], ["BLOCK", 2], ["INTERPOSE", 1]], "color": "ec9d62",
		"sockets": ["RED", "BLUE", "ANY", "BLUE", "GREEN", "ANY"], "signature": "UNBREAKABLE_VOW"},
	"KAIT": {"name": "Kait", "max_hp": 70, "dice": ["D4", "D4", "D4", "D4", "D20"], "trait": "CALCULATED_RISK", "trait_name": "Calculated Risk", "description": "Gain 3 block when a die finishes at least 4 higher than its initial value this turn.", "starting_gems": [["STRIKE", 2], ["BLOCK", 1], ["SUNDER", 1]], "color": "9fd08b",
		"sockets": ["RED", "BLUE", "RED", "VIOLET", "GOLD", "ANY"], "signature": "LONG_ODDS"},
	"MAX": {"name": "Max", "max_hp": 80, "dice": ["D4", "D6", "D6", "D8", "D12"], "trait": "SECOND_THOUGHT", "trait_name": "Second Thought", "description": "Once per encounter, reroll one die without spending your normal reroll.", "starting_gems": [["STRIKE", 1], ["BLOCK", 1], ["ARC_BURST", 1]], "color": "9dabed",
		"sockets": ["RED", "BLUE", "RED", "WHITE", "ANY", "GREEN"], "signature": "MASTER_PLAN"}
}
## Formula text uses M(C) = (C+7)/8 as the Carat multiplier and F(L) = 2L as the flat
## Clarity bonus. Cut multiplies whatever the dice contribute. Every amount floors once.
const SKILLS: Dictionary = {
	"STRIKE": {"name": "Strike", "rarity": 1, "color": "RED", "tags": ["attack"], "trigger": "Always", "formula": "Damage (highest K dice + F(L)) × M(C).", "target": "enemy"},
	"BLOCK": {"name": "Block", "rarity": 1, "color": "BLUE", "tags": ["pair", "block"], "trigger": "Any pair", "formula": "Self block (highest pair value × K + F(L)) × M(C).", "target": "self"},
	"HEAL": {"name": "Heal", "rarity": 2, "color": "GREEN", "tags": ["heal"], "trigger": "Always", "formula": "Self heal (lowest K dice + F(L)) × M(C).", "target": "self"},
	"MULTISTRIKE": {"name": "Multistrike", "rarity": 2, "color": "RED", "tags": ["straight", "attack"], "trigger": "Straight: 5 at L1–2; 4 at L3–4; 3 at L5", "formula": "K hits of 4 × M(C) damage. Clarity shortens the straight instead of adding F(L). Target stays fixed for this skill.", "target": "enemy"},
	"LUCKYSTRIKE": {"name": "Lucky Strike", "rarity": 3, "color": "GOLD", "tags": ["seven", "attack", "gold"], "trigger": "At least one 7", "formula": "Each 7: 7 × M(K) × M(C) damage, then C × J ore. Three or more sevens: J=L+1 (7 at L5); otherwise J=1. The jackpot multiplies ore only.", "target": "enemy"},
	"HEAVYSTRIKE": {"name": "Heavy Strike", "rarity": 1, "color": "RED", "tags": ["triple", "attack"], "trigger": "At least three matching values", "formula": "Damage (highest triple value × K + F(L)) × M(C).", "target": "enemy"},
	"BLESSING": {"name": "Blessing", "rarity": 3, "color": "GOLD", "tags": ["straight", "heal", "gold"], "trigger": "Straight of 3", "formula": "Gain 3 × M(C) ore, then self heal (K + F(L)) × M(C).", "target": "self"},
	"SHIELDBASH": {"name": "Shield Bash", "rarity": 2, "color": "BLUE", "tags": ["full_house", "attack", "block"], "trigger": "Three of one value and two of another", "formula": "Gain F(L) × M(C) block, then damage floor(current block × (K+1)/2). At L5, apply 1 stun.", "target": "enemy"},
	"STUN": {"name": "Stun", "rarity": 4, "color": "VIOLET", "tags": ["high", "attack", "stun"], "trigger": "Highest die ≥ 21−L", "formula": "Damage (H + F(L)) × M(C), then 1 stun (2 at K5). K2–4 do not improve duration.", "target": "enemy"},
	"BULWARK": {"name": "Bulwark", "rarity": 3, "color": "BLUE", "tags": ["low", "block"], "trigger": "Total ≤ 18+2L (20/22/24/26/28)", "formula": "Carat reads a fixed 10–300 block table instead of M(C); self-stun at Cut 1–5: 3/2/2/1/0. Clarity only eases the trigger.", "target": "self"},
	"DRAINSTRIKE": {"name": "Drain Strike", "rarity": 4, "color": "RED", "tags": ["high", "attack", "heal"], "trigger": "Total ≥ 45−5L", "formula": "Damage (floor(H × (K+1)/2) + F(L)) × M(C), then self heal F(L) × M(C).", "target": "enemy"},
	"INTERPOSE": {"name": "Interpose", "rarity": 1, "color": "BLUE", "tags": ["pair", "support", "block"], "trigger": "Any pair", "formula": "Party block (highest pair value + K−1 + F(L)) × M(C) to every living hero.", "target": "ally"},
	"MEND": {"name": "Mend", "rarity": 1, "color": "GREEN", "tags": ["odd", "support", "heal"], "trigger": "At least three odd results", "formula": "Party heal (lowest odd + 2(K−1) + F(L)) × M(C) to every living hero.", "target": "ally"},
	"SUNDER": {"name": "Sunder", "rarity": 2, "color": "RED", "tags": ["two_pairs", "attack"], "trigger": "Two distinct pairs", "formula": "Remove up to (2K + F(L)) × M(C) block; damage (highest pair value + F(L)) × M(C).", "target": "enemy"},
	"ARC_BURST": {"name": "Arc Burst", "rarity": 2, "color": "RED", "tags": ["straight", "attack", "group"], "trigger": "Straight of 3", "formula": "Damage (highest value of chosen straight + F(L)) × M(C) to up to K+1 distinct enemies. Extra targets do not add hits on a single boss.", "target": "enemies"},
	"VENOM": {"name": "Venom", "rarity": 2, "color": "VIOLET", "tags": ["high", "attack", "poison"], "trigger": "Highest die ≥ 13−L", "formula": "Damage (floor(H/2) + F(L)) × M(C); apply K+ceil(C/4) Poison (12 stack cap).", "target": "enemy"},
	"EVEN_TEMPO": {"name": "Even Tempo", "rarity": 2, "color": "BLUE", "tags": ["even", "attack", "block"], "trigger": "At least three even results", "formula": "Self block (even result count × K + F(L)) × M(C); damage (K + F(L)) × M(C).", "target": "enemy"},
	"PRECISION": {"name": "Precision", "rarity": 3, "color": "RED", "tags": ["distinct", "attack"], "trigger": "Five distinct results", "formula": "Damage (lowest two dice + 2K + F(L)) × M(C).", "target": "enemy"},
	"LIFELINE": {"name": "Lifeline", "rarity": 4, "color": "GREEN", "tags": ["straight", "support", "heal", "revive"], "trigger": "Straight: 5 at L1–2; 4 at L3–4; 3 at L5", "formula": "Once per encounter revive a downed ally for (3K + F(L)) × M(C) HP; otherwise heal every living hero (K + F(L)) × M(C). Revived allies act next turn.", "target": "revive"},
	"GLIMMER": {"name": "Glimmer", "rarity": 1, "color": "WHITE", "tags": ["low", "support"], "trigger": "Always", "formula": "Raise your lowest die by (K + F(L)) × M(C), to a maximum of 20. Every gem equipped after this one reads the raised hand.", "target": "self"},
	"REFRACT": {"name": "Refract", "rarity": 3, "color": "WHITE", "tags": ["high", "support"], "trigger": "Always", "formula": "Raise your highest die by (H + 2(K−1) + F(L)) × M(C), to a maximum of 20 — enough to at least double it. Every gem equipped after this one reads the raised hand.", "target": "self"},
	"SECOND_SIGHT": {"name": "Second Sight", "rarity": 2, "color": "WHITE", "tags": ["support", "block"], "trigger": "Always", "formula": "Raise your rerolls per turn to 2 + floor(C/8) for the rest of this battle, +1 at K5, up to 4. It sets the allowance rather than adding to it. Then gain F(L) × M(C) block.", "target": "self"},
	"ECHO": {"name": "Echo", "rarity": 3, "color": "WHITE", "tags": ["pair", "support", "group"], "trigger": "Any pair", "formula": "Repeat the last gem before this one that landed an amount, at (25 + 5(K−1) + F(L)) × M(C) percent of it, up to 200%. It repeats damage, block, healing, ore and statuses only.", "target": "self"},
	"FACET": {"name": "Facet", "rarity": 4, "color": "WHITE", "tags": ["distinct", "support"], "trigger": "At least 5 distinct results (4 at L3–4; 3 at L5)", "formula": "Once per encounter, permanently raise the Carat of your lowest-Carat other equipped gem by ceil(K/2), never past this gem's own Carat of C.", "target": "self"},
	"QUARTET": {"name": "Quartet", "rarity": 3, "color": "RED", "tags": ["triple", "attack"], "trigger": "At least four matching values (three at L5)", "formula": "Damage (matched value × 2K + F(L)) × M(C). Clarity buys the trigger down to a triple instead of adding its flat bonus at L5.", "target": "enemy"},
	"BASTION": {"name": "Bastion", "rarity": 3, "color": "BLUE", "tags": ["low", "block", "support", "stun"], "trigger": "Total ≤ 18+2L (20/22/24/26/28)", "formula": "Party block (3K + F(L)) × M(C) to every living hero, then clear 1 stun (2 at L5) from every living hero.", "target": "ally"},
	"PURGE": {"name": "Purge", "rarity": 2, "color": "GREEN", "tags": ["even", "heal", "support", "poison"], "trigger": "At least three even results", "formula": "Clear K + ceil(C/8) Poison from every living hero, then party heal F(L) × M(C).", "target": "ally"},
	"GRAFT": {"name": "Graft", "rarity": 3, "color": "GREEN", "tags": ["two_pairs", "heal"], "trigger": "Two distinct pairs", "formula": "Self heal (both pair values + 2(K−1) + F(L)) × M(C).", "target": "self"},
	"HEXBOLT": {"name": "Hex Bolt", "rarity": 2, "color": "VIOLET", "tags": ["odd", "attack", "stun"], "trigger": "At least three odd results", "formula": "Damage (odd result count × K + F(L)) × M(C). At L5, apply 1 stun.", "target": "enemy"},
	"MIASMA": {"name": "Miasma", "rarity": 3, "color": "VIOLET", "tags": ["even", "poison", "group"], "trigger": "At least three even results", "formula": "Apply K+ceil(C/6) Poison to up to K+1 distinct enemies, then damage F(L) × M(C) to the same enemies (12 stack cap).", "target": "enemies"},
	"ENERVATE": {"name": "Enervate", "rarity": 4, "color": "VIOLET", "tags": ["triple", "poison", "attack"], "trigger": "At least three matching values", "formula": "Remove up to (2K + F(L)) × M(C) block, then apply floor(matched value / 2) + K Poison (12 stack cap).", "target": "enemy"},
	"TITHE": {"name": "Tithe", "rarity": 1, "color": "GOLD", "tags": ["pair", "gold"], "trigger": "Any pair", "formula": "Gain (K + F(L)) × M(C) ore.", "target": "self"},
	"MINT": {"name": "Mint", "rarity": 2, "color": "GOLD", "tags": ["distinct", "gold", "block"], "trigger": "At least 5 distinct results (4 at L3–4; 3 at L5)", "formula": "Gain (2K + F(L)) × M(C) ore, then self block (K + F(L)) × M(C).", "target": "self"},
	"WAGER": {"name": "Wager", "rarity": 4, "color": "GOLD", "tags": ["low", "gold", "attack"], "trigger": "Total ≤ 18+2L (20/22/24/26/28)", "formula": "Gain 3 × M(C) ore, then damage (24 − total + 2K + F(L)) × M(C). The less the hand gave you, the harder this lands.", "target": "enemy"}
}
const DICE: Dictionary = {
	"D4": {"name": "D4", "shape": "D4", "faces": [1, 2, 3, 4], "price": 4},
	"D6": {"name": "D6", "shape": "D6", "faces": [1, 2, 3, 4, 5, 6], "price": 6},
	"D8": {"name": "D8", "shape": "D8", "faces": [1, 2, 3, 4, 5, 6, 7, 8], "price": 8},
	"D10": {"name": "D10", "shape": "D10", "faces": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "price": 10},
	"D12": {"name": "D12", "shape": "D12", "faces": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "price": 12},
	"D20": {"name": "D20", "shape": "D20", "faces": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], "price": 16},
	"PAIRED_D6": {"name": "Paired Die", "shape": "D6", "faces": [1, 1, 2, 5, 6, 6], "price": 8, "unlock_depth": 1},
	"ODD_D6": {"name": "Odd Die", "shape": "D6", "faces": [1, 1, 3, 5, 5, 6], "price": 8, "unlock_depth": 1},
	"EVEN_D6": {"name": "Even Die", "shape": "D6", "faces": [1, 2, 4, 4, 4, 6], "price": 8, "unlock_depth": 1},
	"SEVEN_D8": {"name": "Seven Die", "shape": "D8", "faces": [1, 2, 3, 4, 5, 7, 7, 7], "price": 14, "unlock_depth": 5},
	"SPLIT_D12": {"name": "Split Die", "shape": "D12", "faces": [1, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 12], "price": 16, "unlock_depth": 6},
	"SPLIT_D20": {"name": "Rift Die", "shape": "D20", "faces": [1, 2, 3, 4, 5, 5, 6, 6, 7, 7, 14, 14, 15, 15, 16, 16, 17, 18, 19, 20], "price": 22, "unlock_depth": 12}
}
const RELICS: Dictionary = {
	"MATCHBOX": {"name": "Matchbox", "description": "Your Block gem grants +2 block once per actor turn."},
	"STEADY_HAND": {"name": "Steady Hand", "description": "Strike deals +2 raw damage when no die was rerolled this turn."},
	"FIELD_DRESSING": {"name": "Field Dressing", "description": "Your first positive ordinary heal to an injured recipient each turn gains +2 healing."},
	"MINERS_LANTERN": {"name": "Miner's Lantern", "description": "Gain 2 extra mining energy while alive, and see exact rooms one layer further down the seam."},
	"FOCUSING_PRISM": {"name": "Focusing Prism", "description": "Straight skills use +1 effective Clarity, up to 5."},
	"MERCHANT_SEAL": {"name": "Merchant's Seal", "description": "Gain +3 ore from each normal or elite battle."},
	"TINKERS_BELT": {"name": "Tinker's Belt", "description": "Your first Workshop service each expedition is free. One service per visit."},
	"LASTING_AEGIS": {"name": "Lasting Aegis", "description": "Carry up to 6 remaining block from a won battle into the next. Unequipping discards stored block."}
}
const ENEMIES: Dictionary = {
	"SLIME": {"name": "Slime", "max_hp": 20, "block": 0, "dice": ["D10", "D10"], "threat": 1, "description": "Strike, then Heal every turn."},
	"RED_SLIME": {"name": "Red Slime", "max_hp": 30, "block": 10, "dice": ["D10", "D10", "D10"], "threat": 2, "description": "Stronger Strike, then Heal every turn."},
	"STONE_CRAB": {"name": "Stone Crab", "max_hp": 26, "block": 6, "dice": ["D6", "D6"], "threat": 1, "description": "Alternates Shell Up (block) and Claw (attack)."},
	"GEM_CULTIST": {"name": "Gem Cultist", "max_hp": 22, "block": 0, "dice": ["D8", "D8"], "threat": 1, "description": "Restores the ally missing most HP when at least 5 HP is missing; otherwise attacks."},
	"DARTLING": {"name": "Dartling", "max_hp": 16, "block": 0, "dice": ["D4", "D4", "D4"], "threat": 1, "description": "Barbed Dart adds 2 Poison if its hand has a pair."},
	"IRON_WARDEN": {"name": "Iron Warden", "max_hp": 48, "block": 12, "dice": ["D6", "D8", "D10"], "threat": 2, "description": "Alternates Fortify (self and group block) and Hammer."},
	"MIRROR_WISP": {"name": "Mirror Wisp", "max_hp": 18, "block": 0, "dice": ["D6", "D6"], "threat": 1, "description": "Reflection deals +4 if the target keeps its marked value."},
	"RIFT_HOUND": {"name": "Rift Hound", "max_hp": 28, "block": 0, "dice": ["D4", "D8", "D12"], "threat": 1, "description": "Alternates Track and Pounce, targeting the hero with least block."},
	"SLIME_KING": {"name": "Slime King", "max_hp": 60, "block": 0, "dice": [], "boss": true, "description": "Slam → Fortify → Absorb. Resolve: after a stun skip, immune to external stun for two slots."},
	"MIRROR_REGENT": {"name": "Mirror Regent", "max_hp": 75, "block": 8, "dice": [], "boss": true, "description": "Refraction → Shatter → Mending Glass. Below half HP: Refraction → Shatter. Resolve protects two slots after a stun skip."},
	"RIFT_SOVEREIGN": {"name": "Rift Sovereign", "max_hp": 100, "block": 0, "dice": [], "boss": true, "description": "High Tide → Low Tide → Eclipse. At 40% HP: High Tide and Low Tide each turn; safe total 19–23. Has Resolve."}
}
const EVENTS: Dictionary = {
	"ABANDONED_CACHE": {"name": "Abandoned Cache", "description": "Take 6 ore, or lose 8 HP for the displayed gem with +2 Carat. Requires more than 8 HP."},
	"FIELD_MEDIC": {"name": "Field Medic", "description": "Take 4 ore, or pay 8 ore to recover 20% maximum HP (rounded up)."},
	"ECHO_SHRINE": {"name": "Echo Shrine", "description": "Take 5 ore, or replace one D6's faces with Paired, Odd, or Even faces."},
	"JEWEL_BROKER": {"name": "Jewel Broker", "description": "Take 4 ore, or trade one found gem for one of three appraised gems."},
	"STILL_POOL": {"name": "Still Pool", "description": "Take 4 ore, or sit by the water a while: the tremor meter settles by 12%. The water only calms once."}
}
## The mine atlas. Each mine is a whole expedition: its boss arrives when the tremor meter
## fills, its bands decide what spawns as the party digs deeper, and its gem pool and colour
## weights decide what the rocks give up. Links are one-way unlocks, opened by killing the
## mine's boss. Rates are whole percentages so the pack never has to carry a float.
const MINES: Dictionary = {
	"QUARRY": {"name": "The Quarry", "starter": true, "difficulty": 1, "boss_id": "SLIME_KING",
		"description": "Old galleries under the town. Slimes and stone crabs, lifts every few layers, and a Slime King that wakes slowly.",
		"links": ["MIRROR_GROTTO", "RIFT_HOLLOW"], "atlas_x": 50, "atlas_y": 58, "color": "c9a26b",
		"tremor_rate": 100, "lift_rate": 100, "quality_bonus": 0,
		"rooms": {"battle": 8, "elite": 1, "mine": 2, "rest": 2, "treasure": 1, "shop": 1, "lapidary": 1, "crucible": 1, "workshop": 1, "wager": 1, "event": 2},
		"bands": [
			{"from_depth": 1, "normal": {"SLIME": 4, "STONE_CRAB": 1}, "elite": {"RED_SLIME": 1}},
			{"from_depth": 4, "normal": {"SLIME": 2, "STONE_CRAB": 3, "GEM_CULTIST": 1}, "elite": {"RED_SLIME": 1, "IRON_WARDEN": 1}},
			{"from_depth": 9, "normal": {"SLIME": 1, "STONE_CRAB": 3, "GEM_CULTIST": 2, "DARTLING": 2}, "elite": {"RED_SLIME": 1, "IRON_WARDEN": 2}}],
		"skill_ids": ["ARC_BURST", "BLOCK", "BULWARK", "GLIMMER", "GRAFT", "HEAL", "HEAVYSTRIKE", "HEXBOLT", "INTERPOSE", "MEND", "MINT", "MULTISTRIKE", "PRECISION", "PURGE", "QUARTET", "SHIELDBASH", "STRIKE", "STUN", "SUNDER", "TITHE"],
		"color_weights": {"RED": 100, "BLUE": 100, "GREEN": 100, "VIOLET": 100, "GOLD": 100, "WHITE": 100},
		"relic_ids": ["FIELD_DRESSING", "MATCHBOX", "MINERS_LANTERN", "STEADY_HAND"]},
	"MIRROR_GROTTO": {"name": "Mirror Grotto", "difficulty": 2, "boss_id": "MIRROR_REGENT",
		"description": "Crystal caverns where the walls look back. Mirror Wisps and cultists, more strange encounters, and White and Blue stones running thick.",
		"links": [], "atlas_x": 26, "atlas_y": 30, "color": "9fd3f0",
		"tremor_rate": 115, "lift_rate": 85, "quality_bonus": 4,
		"rooms": {"battle": 7, "elite": 2, "mine": 1, "rest": 1, "treasure": 1, "shop": 1, "lapidary": 2, "crucible": 1, "workshop": 1, "wager": 1, "event": 3},
		"bands": [
			{"from_depth": 1, "normal": {"MIRROR_WISP": 3, "SLIME": 2, "GEM_CULTIST": 1}, "elite": {"RED_SLIME": 1}},
			{"from_depth": 4, "normal": {"MIRROR_WISP": 3, "DARTLING": 2, "GEM_CULTIST": 2}, "elite": {"RED_SLIME": 1, "IRON_WARDEN": 1}},
			{"from_depth": 9, "normal": {"MIRROR_WISP": 3, "DARTLING": 2, "GEM_CULTIST": 2, "STONE_CRAB": 1}, "elite": {"IRON_WARDEN": 2}}],
		"skill_ids": ["BASTION", "BLESSING", "BLOCK", "BULWARK", "ECHO", "EVEN_TEMPO", "FACET", "GLIMMER", "HEAL", "INTERPOSE", "LIFELINE", "LUCKYSTRIKE", "MEND", "MINT", "MULTISTRIKE", "PRECISION", "REFRACT", "SECOND_SIGHT", "SHIELDBASH", "STRIKE", "TITHE", "WAGER"],
		"color_weights": {"RED": 80, "BLUE": 140, "GREEN": 80, "VIOLET": 80, "GOLD": 120, "WHITE": 160},
		"relic_ids": ["FOCUSING_PRISM", "LASTING_AEGIS", "MATCHBOX", "MERCHANT_SEAL", "MINERS_LANTERN", "TINKERS_BELT"]},
	"RIFT_HOLLOW": {"name": "Rift Hollow", "difficulty": 3, "boss_id": "RIFT_SOVEREIGN",
		"description": "A split in the deep rock that is still opening. Rift Hounds hunt in packs, lifts are few, and the Rift Sovereign stirs fast. Red and Violet stones.",
		"links": [], "atlas_x": 76, "atlas_y": 32, "color": "b07cf0",
		"tremor_rate": 135, "lift_rate": 65, "quality_bonus": 8,
		"rooms": {"battle": 8, "elite": 3, "mine": 2, "rest": 1, "treasure": 1, "shop": 1, "lapidary": 1, "crucible": 2, "workshop": 1, "wager": 1, "event": 2},
		"bands": [
			{"from_depth": 1, "normal": {"RIFT_HOUND": 3, "DARTLING": 2, "STONE_CRAB": 1}, "elite": {"IRON_WARDEN": 1, "RED_SLIME": 1}},
			{"from_depth": 4, "normal": {"RIFT_HOUND": 3, "MIRROR_WISP": 2, "DARTLING": 2}, "elite": {"IRON_WARDEN": 2}},
			{"from_depth": 9, "normal": {"RIFT_HOUND": 4, "MIRROR_WISP": 2, "GEM_CULTIST": 1, "DARTLING": 1}, "elite": {"IRON_WARDEN": 1}}],
		"skill_ids": ["ARC_BURST", "DRAINSTRIKE", "ENERVATE", "GRAFT", "HEAL", "HEAVYSTRIKE", "HEXBOLT", "LIFELINE", "LUCKYSTRIKE", "MIASMA", "MULTISTRIKE", "PRECISION", "PURGE", "QUARTET", "REFRACT", "STRIKE", "STUN", "SUNDER", "VENOM", "WAGER"],
		"color_weights": {"RED": 150, "BLUE": 70, "GREEN": 100, "VIOLET": 150, "GOLD": 70, "WHITE": 70},
		"relic_ids": ["FIELD_DRESSING", "FOCUSING_PRISM", "LASTING_AEGIS", "MATCHBOX", "MERCHANT_SEAL", "MINERS_LANTERN", "STEADY_HAND", "TINKERS_BELT"]}
}

static func canonical_key(key: String) -> String:
	return "BULWARK" if key == "BULLWARK" else key

static func gem(key: String, id: String, carat: int = 1, cut: int = 1, clarity: int = 1) -> Dictionary:
	key = canonical_key(key)
	if not definitions("skills").has(key):
		return {}
	return {"id": id, "key": key, "carat": clampi(carat, 1, 24), "cut": clampi(cut, 1, 5), "clarity": clampi(clarity, 1, 5), "equipped": false, "revive_charges": 1, "upgrade_charges": 1}

static func die(key: String, id: String) -> Dictionary:
	if not definitions("dice").has(key):
		return {}
	var definition: Dictionary = definitions("dice")[key]
	var faces: Array = []
	for index in range(definition.faces.size()):
		faces.append({"id": id + "-f" + str(index), "value": definition.faces[index]})
	return {"id": id, "key": key, "name": definition.name, "shape": definition.shape, "sides": definition.faces.size(), "faces": faces, "price": definition.price}

static func relic(key: String, id: String) -> Dictionary:
	if not RELICS.has(key):
		return {}
	return {"id": id, "key": key, "equipped": false, "stored_block": 0, "used_act": 0}

static func hero(key: String, id: String, seat: int = 0) -> Dictionary:
	key = key.to_upper()
	if not definitions("heroes").has(key):
		return {}
	var definition: Dictionary = definitions("heroes")[key]
	var unit: Dictionary = _unit(key, id, "hero", definition.max_hp, 0)
	unit.merge({"seat": seat, "trait": definition.trait , "trait_charges": 1 if str(definition.get("trait", "")) == "SECOND_THOUGHT" else 0, "ore": 0, "rerolls": 1, "max_rerolls": 1, "base_rerolls": 1, "reserve_dice": [], "relics": [], "combat_ore": 0, "preferred_target": "", "connected": true,
		"sockets": hero_sockets(key), "signature": str(definition.get("signature", ""))})
	for index in range(definition.dice.size()):
		unit.dice.append(die(definition.dice[index], id + "-d" + str(index)))
	for index in range(definition.starting_gems.size()):
		var starting: Array = definition.starting_gems[index]
		var item: Dictionary = gem(starting[0], id + "-g" + str(index), starting[1], starting[2] if starting.size() > 2 else 1, starting[3] if starting.size() > 3 else 1)
		var socket: int = open_socket(unit.sockets, unit.gems, str(item.key), LOADOUT_CARRY)
		if socket < 0:
			continue
		item.equipped = true
		item.socket = socket
		unit.gems.append(item)
	sort_sockets(unit)
	return unit

# --- sockets ------------------------------------------------------------------------

static func hero_sockets(key: String) -> Array:
	## The six socket Colors of a hero, left to right. A pack that names none, or names them
	## badly, gets the default layout rather than a hero who can socket nothing.
	var named: Variant = definitions("heroes").get(key.to_upper(), {}).get("sockets", null)
	if not named is Array or named.size() != SOCKET_COUNT:
		return DEFAULT_SOCKETS.duplicate()
	var sockets: Array = []
	for entry in named:
		sockets.append(str(entry) if str(entry) == SOCKET_ANY or GEM_COLORS.has(str(entry)) else SOCKET_ANY)
	return sockets

static func socket_fits(socket_color: String, gem_key: String) -> bool:
	return socket_color == SOCKET_ANY or socket_color == gem_color(gem_key)

static func socket_name(socket_color: String) -> String:
	if socket_color == SOCKET_ANY:
		return "Prismatic"
	return str(GEM_COLORS.get(socket_color, {}).get("name", socket_color))

static func open_socket(sockets: Array, gems: Array, gem_key: String, limit: int = SOCKET_COUNT) -> int:
	## The first empty socket this gem's Color fits, among the first `limit`. A socket of the
	## gem's own Color is preferred over a prismatic one, so a find never takes the one socket
	## that could hold anything while a socket made for it stands open.
	var taken: Dictionary = {}
	for item in gems:
		if item is Dictionary and item.get("equipped", false):
			taken[int(item.get("socket", -1))] = true
	var fallback: int = -1
	for index in range(mini(limit, sockets.size())):
		if taken.has(index) or not socket_fits(str(sockets[index]), gem_key):
			continue
		if str(sockets[index]) != SOCKET_ANY:
			return index
		if fallback < 0:
			fallback = index
	return fallback

static func sort_sockets(unit: Dictionary) -> void:
	## Equipped gems resolve left to right, so the array every rule walks is kept in socket
	## order with the reserve after it. Nothing else has to know sockets exist.
	var equipped: Array = []
	var reserve: Array = []
	for item in unit.get("gems", []):
		if item is Dictionary and item.get("equipped", false):
			equipped.append(item)
		else:
			reserve.append(item)
	equipped.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("socket", 0)) < int(b.get("socket", 0)))
	unit.gems = equipped + reserve

static func _unit(key: String, id: String, side: String, hp: int, block: int) -> Dictionary:
	var definition: Dictionary = definitions("heroes")[key] if side == "hero" else definitions("enemies")[key]
	return {"id": id, "key": key, "name": definition.name, "side": side, "hp": hp, "max_hp": hp, "block": block, "statuses": {"stun": 0, "poison": 0, "resolve": 0}, "dice": [], "hand": [], "initial_hand": [], "gems": [], "ready": false, "action_eligible_from_turn": 1, "rerolled": false, "relic_flags": {}}

static func enemy(key: String, id: String, depth: int = 1, party_size: int = 1) -> Dictionary:
	## Enemies grow with depth rather than by act: more health and harder hits the further
	## down the seam they are met. A boss scales with the party instead, and gains only a
	## capped share of the depth bonus so a meter that fills early is not a death sentence.
	if not definitions("enemies").has(key):
		return {}
	var definition: Dictionary = definitions("enemies")[key]
	var boss: bool = definition.get("boss", false)
	var level: int = maxi(1, depth)
	var hp: int = ceili(float(definition.max_hp) * party_size * (1.0 + minf(BOSS_DEPTH_CAP, BOSS_DEPTH_STEP * (level - 1)))) if boss else ceili(float(definition.max_hp) * (1.0 + HP_DEPTH_STEP * (level - 1)))
	var support_scale: int = 100 + SUPPORT_DEPTH_PERCENT * (level - 1)
	var block: int = int(definition.block) * party_size if boss else floori(float(definition.block) * support_scale / 100.0)
	var unit: Dictionary = _unit(key, id, "enemy", hp, block)
	## An authored enemy names a registered routine through `ai`; shipped ones are their own.
	unit.merge({"ai": str(definition.get("ai", key)), "boss": boss, "depth": level, "party_size": party_size,
		"damage_bonus": 0 if boss else floori(level / float(DAMAGE_DEPTH_STEP)), "support_scale": 100 if boss else support_scale,
		"intents": [], "boss_phase": "normal", "phase_turn": 0, "description": definition.description})
	for index in range(definition.dice.size()):
		unit.dice.append(die(definition.dice[index], id + "-d" + str(index)))
	var ai: String = str(unit.ai)
	if ai in ["SLIME", "RED_SLIME"]:
		var c: int = 2 if ai == "RED_SLIME" else 1
		unit.gems = [gem("STRIKE", id + "-strike", c), gem("HEAL", id + "-heal", c)]
		for item in unit.gems:
			item.equipped = true
	return unit

## Depth scaling for ordinary enemies: +6% health per layer, +1 damage per hit every four
## layers, +3% block and healing per layer. Bosses take 3% health per layer up to +60%.
const HP_DEPTH_STEP: float = 0.06
const DAMAGE_DEPTH_STEP: int = 4
const SUPPORT_DEPTH_PERCENT: int = 3
const BOSS_DEPTH_STEP: float = 0.03
const BOSS_DEPTH_CAP: float = 0.6
const MAX_ENEMIES: int = 4

static func depth_band(mine_id: String, depth: int) -> Dictionary:
	var found: Dictionary = {}
	for band in mine_definition(mine_id).get("bands", []):
		if band is Dictionary and int(band.get("from_depth", 1)) <= depth:
			found = band
	return found

static func mine_encounter(mine_id: String, kind: String, depth: int, party_size: int, rng: RandomNumberGenerator, prefix: String) -> Array:
	## Fills a threat budget from the depth band: one point per hero for a fight, two for an
	## elite, and a little more as the party digs. An elite always leads with one of the band's
	## elites. Weights are read in sorted order so the draw depends on the band, not its layout.
	var mine: Dictionary = mine_definition(mine_id)
	var count: int = clampi(party_size, 1, MAX_ENEMIES)
	if kind == "boss":
		return [enemy(str(mine.get("boss_id", "SLIME_KING")), prefix + "-boss", depth, count)]
	var band: Dictionary = depth_band(mine_id, depth)
	var keys: Array = []
	var budget: int = count + floori((depth - 1) / 6.0)
	if kind == "elite":
		budget = 2 * count + floori(depth / 8.0)
		var elite: String = _weighted_key(rng, band.get("elite", {}), 999)
		if not elite.is_empty():
			keys.append(elite)
			budget -= threat(elite)
	while keys.size() < MAX_ENEMIES and budget > 0:
		var picked: String = _weighted_key(rng, band.get("normal", {}), budget)
		if picked.is_empty():
			break
		keys.append(picked)
		budget -= threat(picked)
	if keys.is_empty():
		var fallback: String = _weighted_key(rng, band.get("normal", {}), 999)
		keys.append(fallback if not fallback.is_empty() else "SLIME")
	var units: Array = []
	for index in range(keys.size()):
		units.append(enemy(keys[index], "%s-enemy%d" % [prefix, index], depth, count))
	return units

static func threat(key: String) -> int:
	return maxi(1, int(definitions("enemies").get(key, {}).get("threat", 1)))

static func _weighted_key(rng: RandomNumberGenerator, weights: Variant, budget: int) -> String:
	if not weights is Dictionary:
		return ""
	var keys: Array = weights.keys().filter(func(key: Variant) -> bool:
		return definitions("enemies").has(str(key)) and int(weights[key]) > 0 and threat(str(key)) <= budget)
	keys.sort()
	if keys.is_empty():
		return ""
	var index: int = RandomSource.weighted_index(rng, keys.map(func(key: Variant) -> int: return int(weights[key])))
	return str(keys[maxi(0, index)])

static func gem_value(item: Dictionary) -> int:
	var key: String = canonical_key(str(item.get("key", "")))
	if not definitions("skills").has(key):
		return 0
	return int(definitions("skills")[key].rarity) * (int(item.get("carat", 1)) + 2 * (int(item.get("cut", 1)) - 1) + 2 * (int(item.get("clarity", 1)) - 1))

static func gem_color(key: String) -> String:
	## Color is read from the skill definition, never from the gem instance.
	key = canonical_key(key)
	return str(definitions("skills").get(key, {}).get("color", "RED"))

static func color_definition(key: String) -> Dictionary:
	return GEM_COLORS.get(gem_color(key), GEM_COLORS.RED)

static func cut_name(rank: int) -> String:
	return CUT_NAMES[clampi(rank, 1, 5) - 1]

static func clarity_name(rank: int) -> String:
	return CLARITY_NAMES[clampi(rank, 1, 5) - 1]

static func die_value(item: Dictionary) -> int:
	return int(item.get("price", DICE.get(item.get("key", "D6"), DICE.D6).price))

static func has_relic(unit: Dictionary, key: String) -> bool:
	for item in unit.get("relics", []):
		if item.get("key", "") == key and item.get("equipped", false):
			return true
	return false

static func mine_skills(mine_id: String, party_size: int = 1) -> Array:
	## The mine's gem pool, sorted so the loot stream depends on the set and never on the order
	## it was authored in. Lifeline revives an ally, so a solo expedition never finds one.
	var keys: Array = []
	for key in mine_definition(mine_id).get("skill_ids", []):
		if definitions("skills").has(str(key)) and not str(key) in keys:
			keys.append(str(key))
	if party_size <= 1:
		keys.erase("LIFELINE")
	keys.sort()
	return keys

static func mine_relics(mine_id: String) -> Array:
	var keys: Array = []
	for key in mine_definition(mine_id).get("relic_ids", []):
		if definitions("relics").has(str(key)) and not str(key) in keys:
			keys.append(str(key))
	keys.sort()
	return keys

static func merchant_dice(depth: int) -> Array:
	## Dice a merchant may stock at this depth: every die whose `unlock_depth` has been
	## reached. Zero means never sold. Shipped dice come first in their shipped order, then
	## authored ones by name, so adding a die never reshuffles the old stream.
	var shipped: Array = DICE.keys()
	var ranked: Array = []
	for key in definitions("dice"):
		var unlock: int = int(definitions("dice")[key].get("unlock_depth", 0))
		if unlock <= 0 or unlock > depth:
			continue
		var order: int = shipped.find(key)
		ranked.append([99 if order < 0 else order, str(key)])
	ranked.sort()
	return ranked.map(func(entry: Array) -> String: return entry[1])

static func validate_content() -> Array:
	var errors: Array = []
	if _content_pack == null:
		errors.append_array(load_content_pack())
	if SKILLS.size() != 34 or RELICS.size() != 8 or HEROES.size() != 3:
		errors.append("Incomplete content catalog")
	for key in DICE:
		var definition: Dictionary = DICE[key]
		var sides: int = int(str(definition.shape).trim_prefix("D"))
		if definition.faces.size() != sides:
			errors.append(key + ": invalid face count")
		for face in definition.faces:
			if int(face) < 1 or int(face) > sides:
				errors.append(key + ": invalid face value")
	for key in HEROES:
		if HEROES[key].dice.size() != 5:
			errors.append(key + ": must have five dice")
		for die_id in HEROES[key].dice:
			if not DICE.has(die_id):
				errors.append(key + ": missing die " + die_id)
		for entry in HEROES[key].starting_gems:
			if not SKILLS.has(entry[0]):
				errors.append(key + ": missing gem " + entry[0])
	return errors

static func ensure_loaded() -> void:
	## Anything that reads content before a run has started — a profile being created on the
	## title screen, say — has to see the authored pack, not the compiled fallbacks.
	if _content_pack == null:
		load_content_pack()

static func definitions(section: String) -> Dictionary:
	if _content_pack != null:
		var data: Variant = _content_pack.get(section)
		if data is Dictionary:
			return data
	match section:
		"heroes": return HEROES
		"skills": return SKILLS
		"dice": return DICE
		"relics": return RELICS
		"enemies": return ENEMIES
		"events": return EVENTS
		"mines": return MINES
	return {}

static func mine_definition(mine_id: String) -> Dictionary:
	var entry: Variant = definitions("mines").get(mine_id, {})
	return entry if entry is Dictionary else {}

static func mine_ids() -> Array:
	var keys: Array = definitions("mines").keys()
	keys.sort()
	return keys

static func starter_mines() -> Array:
	return mine_ids().filter(func(key: String) -> bool: return bool(mine_definition(key).get("starter", false)))

## --- Quality-rolled gems ---------------------------------------------------------
## One number, 0-30, stands for how good a find should be: the mine's bonus plus how deep
## the party dug, or the best mine a shopkeeper can buy from. It moves rarity, Carat and
## both ranks together, so a deep find is better across the board without any one table.

const MAX_QUALITY: int = 30

static func quality_rarity_weights(quality: int) -> Array:
	var q: int = clampi(quality, 0, MAX_QUALITY)
	return [maxi(8, 60 - 2 * q), 30 + floori(q / 3.0), 8 + q, maxi(0, floori(q * 2 / 3.0) - 1)]

static func roll_gem_ranks(rng: RandomNumberGenerator, quality: int) -> Array:
	## [carat, cut, clarity]. Carat spans 1-4 at quality 0 and 11-24 at 30; the ranks centre
	## on 1 at quality 0 and walk up to 5 at 30.
	var q: int = clampi(quality, 0, MAX_QUALITY)
	var carat: int = clampi(rng.randi_range(1 + floori(q / 3.0), 4 + floori(q * 2 / 3.0)), 1, 24)
	var center: float = 1.0 + float(q) / 7.5
	var weights: Array = []
	for rank in range(1, 6):
		weights.append(maxf(0.0, 10.0 - absf(float(rank) - center) * 4.0))
	return [carat, RandomSource.weighted_index(rng, weights) + 1, RandomSource.weighted_index(rng, weights) + 1]

static func roll_gem(rng: RandomNumberGenerator, keys: Array, quality: int, id: String, color_weights: Dictionary = {}) -> Dictionary:
	## One gem from `keys`: a rarity bucket by quality, then a skill in that bucket weighted by
	## its colour. Keys are sorted first so the draw depends on the set, never the order.
	var pool: Array = keys.filter(func(key: Variant) -> bool: return definitions("skills").has(str(key)))
	pool.sort()
	if pool.is_empty():
		return {}
	var buckets: Array = [[], [], [], []]
	for key in pool:
		buckets[clampi(int(definitions("skills")[key].rarity), 1, 4) - 1].append(key)
	var rarity_weights: Array = quality_rarity_weights(quality)
	for index in range(4):
		if buckets[index].is_empty():
			rarity_weights[index] = 0
	var bucket: Array = buckets[maxi(0, RandomSource.weighted_index(rng, rarity_weights))]
	var skill_weights: Array = []
	for key in bucket:
		skill_weights.append(int(color_weights.get(gem_color(key), 100)))
	var chosen: String = bucket[maxi(0, RandomSource.weighted_index(rng, skill_weights))]
	var ranks: Array = roll_gem_ranks(rng, quality)
	return gem(chosen, id, ranks[0], ranks[1], ranks[2])

static func default_content_pack() -> Resource:
	var pack: Resource = ContentPack.new()
	pack.content_version = CONTENT_VERSION
	pack.heroes = HEROES.duplicate(true)
	pack.skills = SKILLS.duplicate(true)
	pack.dice = DICE.duplicate(true)
	pack.relics = RELICS.duplicate(true)
	pack.enemies = ENEMIES.duplicate(true)
	pack.events = EVENTS.duplicate(true)
	for key in pack.skills:
		pack.skills[key]["evaluator_id"] = key
	pack.mines = MINES.duplicate(true)
	pack.statuses = {
		"stun": {"name": "Stun", "description": "Skip the next actor slot; ticks before the skill batch. Self-stun affects future slots.", "hook": "start_slot", "cap": - 1},
		"poison": {"name": "Poison", "description": "End-slot damage bypasses block, including a stunned slot. Lose one stack after ticking.", "hook": "end_slot", "cap": 12},
		"resolve": {"name": "Resolve", "description": "Bosses reject external stun for two slots after a stun skip.", "hook": "end_slot", "cap": 2}
	}
	return pack

static func load_content_pack(path: String = "res://content/full_content.tres") -> Array:
	var pack: Resource
	if path.ends_with(".json"):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return ["Cannot read content pack: " + path]
		var imported: Dictionary = ContentPack.from_json(file.get_as_text())
		if not imported.errors.is_empty():
			return imported.errors
		pack = imported.pack
	else:
		if not ResourceLoader.exists(path):
			return ["Missing content pack: " + path]
		pack = load(path)
	if not pack is ContentPack:
		return ["Content asset has the wrong Resource type"]
	var errors: Array = pack.validate({"heroes": HEROES, "skills": SKILLS, "dice": DICE, "relics": RELICS, "enemies": ENEMIES})
	if pack.content_version != CONTENT_VERSION:
		errors.append("Content version does not match this rules build")
	if errors.is_empty():
		_content_pack = pack
	return errors

static func export_content_pack(path: String, use_defaults: bool = false) -> Error:
	var pack: Resource = default_content_pack() if use_defaults or _content_pack == null else _content_pack
	if path.ends_with(".json"):
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(pack.to_json() + "\n")
		return OK
	return ResourceSaver.save(pack, path)
