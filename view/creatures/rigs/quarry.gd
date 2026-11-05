extends RefCounted
## The Quarry: the first mine's creatures (and the older scenes that live there: the Rail Rat,
## the Lantern Moth). Its Wardens and its two big beasts (the Foreman, the Drill, the Regent,
## the Glass Wyrm and the Quartz Golem families) are in quarry_wardens.gd.
## Each creature's rig as data (see the gesture language in creature_rigs.gd), keyed by its scene,
## and the moves and idles no table says, written out as functions of the Moves node
## (creature_moves.gd) passed in as `m`. creature_rigs.gd merges every mine's RIGS.
## Pass 2 (November 3, 2026): each creature's trope over its rig, a trope idle, fidgets, heavy
## blows wound up and landed hard, and its own gesture for every ability.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {
	"_mole_erupt": 1.1,
}
## When a move played by a function is wound back furthest (a heavy one holds there): the
## Pit Mole holds under its mound, the dirt already lifting, before it bursts up.
const CUSTOM_WIND: Dictionary = {
	"_mole_erupt": 0.1,
}

## Envelopes only these creatures use ([time, value] keys: -1 wound back, +1 the blow).
## The Rail Rat's quick looks about as it squeaks for help.
const RAT_LOOK: Array = [[0.0, 0.0], [0.3, 1.0], [0.55, -1.0], [0.8, 1.0], [1.05, 0.0]]
## The Cave Tick's front legs waving in the air as it quests, the second a beat behind.
const QUEST_WAVE: Array = [[0.0, 0.0], [0.8, 0.0], [1.1, 1.0], [1.45, -1.0], [1.8, 1.0], [2.15, -1.0], [2.5, 1.0], [2.85, 0.0]]
const QUEST_WAVE2: Array = [[0.0, 0.0], [0.95, 0.0], [1.25, 1.0], [1.6, -1.0], [1.95, 1.0], [2.3, -1.0], [2.65, 1.0], [3.0, 0.0]]
## Its mandibles chewing three times over, and the tug as it latches on and pulls.
const TICK_CHEW: Array = [[0.0, 0.0], [0.25, 1.0], [0.4, -0.3], [0.55, 0.0], [0.8, 1.0], [0.95, -0.3], [1.1, 0.0], [1.35, 1.0], [1.5, -0.3], [1.75, 0.0]]
const TICK_TUG: Array = [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.48, 1.0], [0.58, 0.35], [0.68, 0.9], [0.8, 0.3], [0.9, 0.85], [1.25, 0.0]]
const TICK_SWAY: Array = [[0.0, 0.0], [0.5, 1.0], [0.85, -1.0], [1.2, 1.0], [1.55, -1.0], [1.95, 0.0]]
## Its legs pair by pair, front to back, the two sides out of step: [parts, hip, side].
const TICK_STEPS: Array = [[["Leg01", "Leg02"], Vector3(-0.2, 0.3, 0.42), -1.0], [["Leg09", "Leg10"], Vector3(0.2, 0.3, 0.42), 1.0],
	[["Leg03", "Leg04"], Vector3(-0.2, 0.3, 0.25), -1.0], [["Leg11", "Leg12"], Vector3(0.2, 0.3, 0.25), 1.0],
	[["Leg05", "Leg06"], Vector3(-0.2, 0.3, 0.08), -1.0], [["Leg13", "Leg14"], Vector3(0.2, 0.3, 0.08), 1.0],
	[["Leg07", "Leg08"], Vector3(-0.2, 0.3, -0.09), -1.0], [["Leg15", "Leg16"], Vector3(0.2, 0.3, -0.09), 1.0]]
## The Magpie's two hops (crouch, up, land), and its body turning aside on the first and back.
const HOP2: Array = [[0.0, 0.0], [0.14, -1.0], [0.3, 1.0], [0.44, -0.4], [0.62, 1.0], [0.78, -0.3], [0.95, 0.0]]
const HOP_TURN: Array = [[0.0, 0.0], [0.2, 0.0], [0.34, 1.0], [0.54, 1.0], [0.7, 0.0]]
## Its head cocked to one side, held, then the other.
const COCK: Array = [[0.0, 0.0], [0.35, 1.0], [1.15, 1.0], [1.5, -1.0], [2.35, -1.0], [2.8, 0.0]]
## The Silt Slime's boing: squashed, sprung up, wobbling to rest; the helmet a beat behind.
const JIGGLE: Array = [[0.0, 0.0], [0.28, -1.0], [0.46, 1.0], [0.62, -0.55], [0.78, 0.35], [0.94, -0.2], [1.1, 0.1], [1.3, 0.0]]
const JIGGLE_LATE: Array = [[0.0, 0.0], [0.36, -1.0], [0.54, 1.0], [0.7, -0.55], [0.86, 0.35], [1.02, -0.2], [1.18, 0.1], [1.4, 0.0]]
## A bubble coming up through it and out of its mouth; its eyes rolling one way, then the other.
const BURP: Array = [[0.0, 0.0], [1.0, 0.0], [1.2, 1.0], [1.5, 1.0], [1.8, 0.0]]
const GOOGLY: Array = [[0.0, 0.0], [0.4, 1.0], [0.9, 1.0], [1.2, -1.0], [1.7, -1.0], [2.1, 0.0]]
const CROSS: Array = [[0.0, 0.0], [1.95, 0.0], [2.15, 1.0], [2.4, 1.0], [2.6, 0.0]]
## It melts down flat, then draws itself up, a little past, and settles.
const SAG: Array = [[0.0, 0.0], [0.7, 1.0], [1.5, 1.0], [1.85, -0.35], [2.1, 0.12], [2.3, 0.0]]
## The Pit Mole's claws scraping the dirt, left and right in turn.
const SCRAPE_L: Array = [[0.0, 0.0], [0.3, -1.0], [0.45, 1.0], [0.7, -1.0], [0.85, 1.0], [1.1, -1.0], [1.25, 1.0], [1.6, 0.0]]
const SCRAPE_R: Array = [[0.0, 0.0], [0.5, -1.0], [0.65, 1.0], [0.9, -1.0], [1.05, 1.0], [1.3, -1.0], [1.45, 1.0], [1.8, 0.0]]
## The Lantern Moth's wings raised over its back as it rests them, and settled with two shuffles.
const WING_REST: Array = [[0.0, 0.0], [0.45, 1.0], [1.45, 1.0], [1.75, 0.15], [1.85, 0.45], [2.0, 0.05], [2.1, 0.3], [2.35, 0.0]]
## A Will-o'-Wisp's lamp swung side to side before the party, slow, to draw the eye.
const LURE_SWAY: Array = [[0.0, 0.0], [0.15, 1.0], [0.35, -1.0], [0.55, 1.0], [0.75, -1.0], [0.95, 1.0], [1.15, 0.0]]

const RIGS: Dictionary = {
	## The Rail Rat: a twitchy scavenger of the rails. It sniffs the air in quick bursts, ears
	## flicking, grooms its face with its paws, sits up to look about; it gnaws in fast little
	## nips and rears up on its haunches to bite.
	"RAIL_RAT": {
		"mouth": "Bob01",
		"idle": "_idle_rat",
		"groups": {
			"head": {"parts": ["Bob01", "Cone", "Sphere"], "at": Vector3(0, 0.3, 0.3)},
			"ears": {"parts": ["Cone"], "at": Vector3(0, 0.36, 0.54)},
			"ear_l": {"parts": ["Cone01"], "at": Vector3(0.1, 0.36, 0.54)},
			"ear_r": {"parts": ["Cone02"], "at": Vector3(-0.1, 0.36, 0.54)},
			"tail": {"parts": ["Swing01"], "at": Vector3(0, 0.25, -0.4)},
			"body": {"parts": ["Core01"], "at": Vector3(0, 0.28, 0)},
			"back": {"parts": ["Crystal"]},
			"legs_f": {"parts": ["Cylinder01", "Cylinder02"], "at": Vector3(0, 0.2, 0.25)},
						## Front left, front right, back right, back left: a trot when each is a half beat on.
			"legs": {"parts": ["Cylinder01", "Cylinder02", "Cylinder04", "Cylinder03"]},
		},
		"idle_gestures": [["look", "head", 16.0, 5.0, 2.4, 0.5], ["sway", "tail", Y, 9.0, 1.4, 0.0],
			["breathe", "body", Vector3(0.03, 0.05, 0.02), 6.0, 0.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Sits back and scrubs its face with both front paws, head bobbing into them.
			"groom": {"length": 2.8, "hold": 1.5, "weight": 2.0, "do": [["call", "_rat_hold"], ["turn", "ears", X, 0.0, -12.0, "f"],
				["turn", "head", X, 0.0, 20.0, "f"], ["turn", "head", Y, 9.0, -9.0, "wag"],
				["turn", "legs_f", X, 0.0, -70.0, "f"], ["turn", "legs_f", X, 0.0, -14.0, "chew"],
				["lean", X, 0.0, -16.0, Vector3(0, 0, -0.3), "f"], ["turn", "tail", X, 0.0, 14.0, "f"]]},
			## Sits up tall on its haunches, paws lifted, and sniffs round the room, ears wide.
			"sniff_up": {"length": 3.4, "hold": 2.0, "weight": 2.0, "do": [["call", "_rat_hold"],
				["turn", "ear_l", Z, 0.0, -16.0, "f"], ["turn", "ear_r", Z, 0.0, 16.0, "f"],
				["turn", "head", X, 0.0, -22.0, "f"], ["gaze", "head", 32.0, 8.0, "f", 3], ["tremble", "head", 0.004, "f"],
				["turn", "legs_f", X, 0.0, -42.0, "f"], ["turn", "tail", X, 0.0, 22.0, "f"],
				["lean", X, 0.0, -24.0, Vector3(0, 0, -0.3), "f"]]},
			## Freezes and looks back over its shoulder, ears up, tail swept aside.
			"glance": {"length": 2.2, "hold": 0.9, "weight": 1.5, "do": [["call", "_rat_hold"], ["turn", "ears", X, 0.0, 10.0, "f"],
				["turn", "head", Y, 0.0, 55.0, "f"], ["turn", "tail", Y, 0.0, -24.0, "f"], ["lean", Y, 0.0, 14.0, Vector3.ZERO, "f"]]},
		},
		"moves": {
			## Three fast nips, ears pinned back, the head working at what it bites.
			"Gnaw": [["call", "_rat_hold"], ["turn", "ears", X, -25.0, -25.0, "thrice"],
				["turn", "head", X, -10.0, 18.0, "thrice"], ["move", "head", Vector3(0, 0.02, -0.04), Vector3(0, -0.03, 0.1), "thrice"],
				["turn", "tail", Y, -14.0, 14.0, "thrice"], ["lean", X, -3.0, 5.0, Vector3(0, 0, -0.2), "thrice"], ["rear", 0.2, "thrice"],
				["fx", 0.3, "shards", {"from": "mouth", "off": Vector3(0, -0.03, 0.2), "color": "#d8cbb4", "amount": 3, "speed": 2.0, "size": 0.5}],
				["fx", 0.52, "shards", {"from": "mouth", "off": Vector3(0, -0.03, 0.2), "color": "#d8cbb4", "amount": 3, "speed": 2.0, "size": 0.5}],
				["fx", 0.74, "shards", {"from": "mouth", "off": Vector3(0, -0.03, 0.2), "color": "#d8cbb4", "amount": 3, "speed": 2.0, "size": 0.5}]],
			## Rears up on its haunches, paws off the floor, and comes down snout first in a hard bite.
			"Bite": [["call", "_rat_hold"], ["turn", "ears", X, -35.0, -30.0, "big"],
				["turn", "head", X, -30.0, 20.0, "big"], ["move", "head", Vector3(0, 0.05, -0.06), Vector3(0, -0.04, 0.16), "big"],
				["turn", "tail", X, 25.0, -8.0, "big"], ["turn", "legs_f", X, -35.0, 15.0, "big"],
				["lean", X, -16.0, 9.0, Vector3(0, 0, -0.3), "big"], ["rear", 0.35, "big"],
				["fx", 0.29, "shards", {"from": "mouth", "off": Vector3(0, -0.03, 0.22), "color": "#e8dcc4", "amount": 6, "speed": 3.0, "size": 0.6}],
				["fx", 0.3, "puff", {"from": "feet", "off": Vector3(0, 0.05, -0.2), "color": "#6a5a4a", "amount": 8, "size": 0.7, "rise": 0.4}]],
			"bite": [["call", "_rat_hold"], ["turn", "ears", X, -25.0, -25.0, "attack"], ["turn", "head", X, -12.0, 16.0, "attack"],
				["move", "head", Vector3(0, 0.03, -0.05), Vector3(0, -0.03, 0.12), "attack"], ["rear", 0.25, "attack"]],
			## Sits up and squeaks for the rest of the nest, looking about, paws paddling, tail whipping.
			"Scurry": [["call", "_rat_hold"], ["turn", "ear_l", Z, 0.0, -22.0, "hold"], ["turn", "ear_r", Z, 0.0, 22.0, "hold"],
				["turn", "head", X, 0.0, -28.0, "hold"], ["turn", "head", Y, -18.0, 18.0, RAT_LOOK],
				["wave_each", "legs", X, 26.0, 24.0, PI, "hold"], ["turn", "tail", Y, -22.0, 22.0, "shake"],
				["lean", X, 0.0, -12.0, Vector3(0, 0, -0.3), "hold"], ["hop", Vector3.ZERO, Vector3(0, 0.05, 0), "twice"],
				["fx", 0.3, "ripple", {"from": "mouth", "color": "#f0e2c8", "radius": 0.5, "seconds": 0.45}],
				["fx", 0.3, "puff", {"from": "feet", "color": "#6a5a4a", "amount": 8, "size": 0.6, "rise": 0.3}]],
		},
		"heavy": {
			## Bite held: up on its haunches, higher, tail lashed up, shivering; then down hard.
			"Bite": {"at": "mouth", "pose": [["lean", X, 0.0, -8.0, Vector3(0, 0, -0.3), "h"], ["turn", "tail", X, 0.0, 18.0, "h"],
					["tremble", "head", 0.006, "h"]],
				"charge": [["charge_glow", {"from": "mouth", "seconds": 0.5}], ["charge_dust", {"seconds": 0.45}],
					["puff", {"from": "feet", "off": Vector3(0, 0.04, -0.25), "color": "#6a5a4a", "amount": 10, "size": 0.7, "rise": 0.3}]],
				"impact": [["shock", {"ahead": 0.7, "size": 0.7}],
					["shards", {"from": "mouth", "off": Vector3(0, -0.03, 0.25), "color": "#e8dcc4", "amount": 8, "speed": 3.5, "size": 0.45}]]},
		},
	},
	## The Cave Tick (and the Fire Tick): a fat-bellied crystal tick on eight iron legs. It
	## quests with its front legs raised to the air, works its mandibles, shifts its legs; it
	## latches on and tugs, and swells as it gorges.
	"CAVE_TICK": {
		"mouth": "Mouth01",
		"groups": {
			"head": {"parts": ["Head", "Jaw", "Mouth"], "at": "Head01"},
			"belly": {"parts": ["Body01"], "at": "Body01"},
			"back": {"parts": ["Shell01", "Crystal"], "at": "Shell01"},
			"crystals": {"parts": ["Crystal"]},
			"leg_fl": {"parts": ["Leg09", "Leg10"], "at": Vector3(0.2, 0.3, 0.42)},
			"leg_fr": {"parts": ["Leg01", "Leg02"], "at": Vector3(-0.2, 0.3, 0.42)},
		},
		"idle_gestures": [["sway", "Jaw01", Y, 7.0, 3.1, 0.0], ["sway", "Jaw02", Y, -7.0, 3.1, 0.0], ["look", "head", 9.0, 4.0, 3.0, 0.8],
			["breathe", "belly", Vector3(0.05, 0.04, 0.06), 1.1, 0.0], ["flex", "leg_fl", X, -14.0, 4.6, 0.0], ["flex", "leg_fr", X, -14.0, 5.3, 2.0]],
		"fidget_every": [5.0, 9.5],
		"fidgets": {
			## Questing, as ticks do: rears its front up, mandibles open, front legs raised and waving.
			"quest": {"length": 3.6, "hold": 2.0, "weight": 3.0, "do": [["turn", "Jaw01", Y, 0.0, 16.0, "f"], ["turn", "Jaw02", Y, 0.0, -16.0, "f"],
				["turn", "head", X, 0.0, -14.0, "f"],
				["turn", "leg_fl", X, 0.0, -28.0, "f"], ["turn", "leg_fl", X, 12.0, -12.0, QUEST_WAVE], ["turn", "leg_fl", Z, 0.0, 22.0, "f"],
				["turn", "leg_fr", X, 0.0, -28.0, "f"], ["turn", "leg_fr", X, 12.0, -12.0, QUEST_WAVE2], ["turn", "leg_fr", Z, 0.0, -22.0, "f"],
				["lean", X, 0.0, -9.0, Vector3(0, 0, -0.15), "f"]]},
			## A gulp: its belly swells, the crystals on its back glint, a contented shiver.
			"gulp": {"length": 2.4, "hold": 0.8, "weight": 1.5, "do": [["each", "crystals", 0.0, 0.25, "f"], ["tremble", "back", 0.004, "f"],
				["grow", "belly", 0.0, Vector3(0.12, 0.1, 0.14), "f"], ["turn", "head", X, 0.0, 10.0, "f"]]},
			## Head down, mandibles working three times over at nothing.
			"chew": {"length": 2.0, "hold": 0.8, "weight": 1.5, "do": [["turn", "Jaw01", Y, -8.0, 30.0, TICK_CHEW], ["turn", "Jaw02", Y, 8.0, -30.0, TICK_CHEW],
				["turn", "head", X, 0.0, 12.0, "f"]]},
			## Steps its eight legs in place, one after another, rocking as it shifts its weight.
			"shuffle": {"length": 2.2, "hold": 1.0, "weight": 1.5, "do": [["call", "_tick_shuffle"], ["lean", Z, -2.5, 2.5, Vector3.ZERO, TICK_SWAY]]},
		},
		"moves": {
			## Front legs up as it winds, mandibles wide; it lunges and snaps them shut.
			"Bite": [["turn", "Jaw01", Y, 38.0, -8.0, "snap"], ["turn", "Jaw02", Y, -38.0, 8.0, "snap"],
				["turn", "head", X, -14.0, 12.0, "attack"], ["move", "head", Vector3(0, 0.03, -0.08), Vector3(0, -0.04, 0.18), "attack"],
				["turn", "leg_fl", X, -22.0, 8.0, "attack"], ["turn", "leg_fr", X, -22.0, 8.0, "attack"], ["rear", 0.28, "attack"]],
			## Bites twice, deep, and drinks: the light pulled into it, its belly swelling.
			"Gorge": [["turn", "Jaw01", Y, 42.0, -8.0, "snap2"], ["turn", "Jaw02", Y, -42.0, 8.0, "snap2"],
				["turn", "head", X, -16.0, 14.0, "twice"], ["move", "head", Vector3(0, 0.03, -0.08), Vector3(0, -0.04, 0.2), "twice"],
				["turn", "leg_fl", X, -26.0, 10.0, "twice"], ["turn", "leg_fr", X, -26.0, 10.0, "twice"],
				["grow", "belly", 0.0, 0.3, "late"], ["rear", 0.35, "twice"],
				["fx", 0.44, "drain", {"from": "Mouth01", "color": "#d8404a", "count": 1, "start": 0.55, "halo": 2.5}]],
			## Lunges, clamps its mandibles on, front legs wrapping round, and tugs twice as it drinks.
			"Latch": [["turn", "Jaw01", Y, 40.0, -6.0, "hold"], ["turn", "Jaw02", Y, -40.0, 6.0, "hold"],
				["move", "head", Vector3(0, 0.02, -0.06), Vector3(0, -0.03, 0.2), TICK_TUG],
				["turn", "leg_fl", X, -20.0, 12.0, "hold"], ["turn", "leg_fl", Y, 0.0, -18.0, "hold"],
				["turn", "leg_fr", X, -20.0, 12.0, "hold"], ["turn", "leg_fr", Y, 0.0, 18.0, "hold"],
				["grow", "belly", 0.0, 0.25, "hold"], ["lean", X, 0.0, 3.0, Vector3(0, 0, -0.2), TICK_TUG], ["rear", 0.25, "attack"],
				["fx", 0.4, "spiral", {"from": "Mouth01", "color": "core", "amount": 16, "size": 0.5}]],
			## The Fire Tick: head thrown back, the crystals on its back flaring, and a gout of fire.
			"Ignite": [["turn", "Jaw01", Y, 30.0, 36.0, "breath"], ["turn", "Jaw02", Y, -30.0, -36.0, "breath"],
				["turn", "head", X, -18.0, 6.0, "breath"], ["each", "crystals", 0.0, 0.35, "breath"],
				["lean", X, -6.0, 4.0, Vector3(0, 0, -0.2), "breath"], ["rear", 0.2, "attack"],
				["fx", 0.2, "sparks", {"from": "Shell01", "color": "#ff9a40", "amount": 14, "speed": 2.0}],
				["fx", 0.26, "breath", {"kind": "fire", "seconds": 0.45, "size": 0.6}]],
		},
		"heavy": {
			## Gorge held: reared up on its back legs, front legs spread wide, belly throbbing.
			"Gorge": {"at": "Mouth01", "pose": [["lean", X, 0.0, -10.0, Vector3(0, 0, -0.2), "h"], ["turn", "leg_fl", Z, 0.0, 24.0, "h"],
					["turn", "leg_fr", Z, 0.0, -24.0, "h"], ["grow", "belly", 0.0, 0.08, "h"]],
				"charge": [["charge_glow", {"from": "Mouth01", "seconds": 0.5}], ["charge_dust", {"seconds": 0.45}],
					["sparks", {"from": "Mouth01", "color": "core", "amount": 10, "speed": 1.5}]],
				"impact": [["shock", {"ahead": 0.8, "size": 0.8}], ["shards", {"from": "Mouth01", "color": "core", "amount": 10, "speed": 4.0}],
					["puff", {"from": "feet", "color": "#5a4a3a", "amount": 10, "size": 0.8, "rise": 0.4}]]},
		},
	},
	## The Magpie (and the Glint and Gilded Magpies): a thieving bird. It hops about, flicks its
	## tail, cocks its head at whatever glints, preens, pecks at the floor; it snatches pyrite and
	## flaunts the prize in its beak.
	"MAGPIE": {
		"mouth": "Head04",
		"prize": "Prize01",
		"ground": ["Rock"],
		"idle": "_idle_magpie",
		"groups": {
			"head": {"parts": ["Neck", "Head", "Prize"], "at": "Head01"},
			"skull": {"parts": ["Head", "Prize"], "at": Vector3(0, 0.74, 0.26)},
			"wing_l": {"parts": ["WingL"], "at": "WingL01"},
			"wing_r": {"parts": ["WingR"], "at": "WingR01"},
			"tail": {"parts": ["Tail"], "at": "Tail01"},
			"all": {"parts": ["Body", "Core", "Neck", "Head", "Prize", "Tail", "WingL", "WingR"], "at": Vector3(0, 0.32, 0.04)},
		},
		"fidget_every": [5.0, 9.5],
		"fidgets": {
			## Two little hops, turning aside on the first and back on the second, wings flicking.
			"hop": {"length": 1.6, "weight": 2.5, "idle": 0.0, "do": [["turn", "wing_l", Z, 0.0, -24.0, HOP2], ["turn", "wing_r", Z, 0.0, 24.0, HOP2],
				["turn", "tail", X, 0.0, 22.0, HOP2], ["hop", Vector3(0, -0.03, 0), Vector3(0, 0.14, 0), HOP2], ["lean", Y, 0.0, 24.0, Vector3.ZERO, HOP_TURN]]},
			## Cocks its head to one side at something bright, then to the other.
			"cock": {"length": 3.0, "hold": 1.6, "weight": 2.0, "idle": 0.0, "do": [["turn", "skull", Z, -24.0, 24.0, COCK],
				["turn", "head", X, 0.0, -10.0, "f"], ["turn", "head", Y, -14.0, 14.0, COCK]]},
			## Turns its head back over its shoulder and preens its wing, beak nibbling.
			"preen": {"length": 3.2, "hold": 1.6, "weight": 2.0, "idle": 0.0, "do": [["turn", "skull", X, 0.0, 14.0, "chew"],
				["turn", "head", X, 0.0, 26.0, "f"], ["turn", "head", Y, 0.0, 110.0, "f"],
				["turn", "wing_l", Z, 0.0, 18.0, "f"], ["turn", "tail", X, 0.0, 10.0, "f"]]},
			## Stretches its wings out wide and gives them a shake, tail fanned, chest out.
			"stretch": {"length": 2.6, "hold": 1.0, "weight": 1.5, "idle": 0.0, "do": [["turn", "wing_l", Z, 0.0, -36.0, "f"], ["turn", "wing_r", Z, 0.0, 36.0, "f"],
				["turn", "wing_l", Z, 0.0, 10.0, "flap"], ["turn", "wing_r", Z, 0.0, -10.0, "flap"],
				["turn", "tail", X, 0.0, 26.0, "f"], ["turn", "head", X, 0.0, -12.0, "f"],
				["fx", 1.1, "puff", {"from": "Body01", "color": "#d8c8b8", "amount": 6, "size": 0.5, "rise": 0.3}]]},
		},
		"moves": {
			"peck": [["turn", "wing_l", Z, 0.0, 35.0, "attack"], ["turn", "wing_r", Z, 0.0, -35.0, "attack"],
				["turn", "head", X, -30.0, 62.0, "attack"], ["turn", "all", X, -8.0, 18.0, "attack"], ["rear", 0.35, "attack"],
				["fx", 0.3, "sparks", {"from": "Head04", "color": "#ffe8b0", "amount": 6, "speed": 1.8}]],
			## Darts in, beak first, wings thrown up, and back with what it took: a glint of pyrite.
			"Snatch": [["turn", "wing_l", Z, -15.0, 28.0, "attack"], ["turn", "wing_r", Z, 15.0, -28.0, "attack"],
				["turn", "head", X, -35.0, 55.0, "big"], ["turn", "tail", X, 0.0, -25.0, "big"], ["turn", "all", X, -10.0, 22.0, "big"],
				["rear", 0.5, "big"], ["fx", 0.34, "sparks", {"from": "Head04", "color": "#ffd34a", "amount": 12, "speed": 2.2}]],
			## The Glint Magpie: throws its wings wide and flashes its glinting breast at the party.
			"Dazzle": [["turn", "wing_l", Z, 10.0, -38.0, "hold"], ["turn", "wing_r", Z, -10.0, 38.0, "hold"],
				["turn", "head", X, 0.0, -20.0, "hold"], ["turn", "tail", X, 0.0, 30.0, "hold"], ["turn", "all", X, 0.0, -8.0, "hold"],
				["fx", 0.28, "glow", {"from": "Core01", "color": "accent", "size": 0.9}],
				["fx", 0.3, "sparks", {"from": "Core01", "color": "accent", "amount": 30, "speed": 4.0}],
				["fx", 0.3, "flash_light", {"from": "Core01", "color": "accent", "energy": 5.0}]],
			## Ready to go (its Flee): hops up crowing, wings raised, the prize flashed in its beak.
			"rally": [["turn", "wing_l", Z, -10.0, 45.0, "hold"], ["turn", "wing_r", Z, 10.0, -45.0, "hold"],
				["turn", "head", X, 0.0, -22.0, "hold"], ["turn", "tail", X, 0.0, 25.0, "hold"],
				["hop", Vector3(0, -0.04, 0), Vector3(0, 0.12, 0), "attack"],
				["fx", 0.3, "sparks", {"from": "Head04", "color": "#ffd34a", "amount": 16, "speed": 2.5}]],
			"flee": [["turn", "wing_l", Z, 0.0, 45.0, "flutter"], ["turn", "wing_r", Z, 0.0, -45.0, "flutter"]],
			"*": [["turn", "wing_l", Z, 0.0, 40.0, "flutter"], ["turn", "wing_r", Z, 0.0, -40.0, "flutter"], ["turn", "head", X, 0.0, -15.0, "lift"]],
		},
	},
	## The Silt Slime (and the Spore Slime): a jelly blob in a miner's helmet. It wobbles and
	## jiggles, squashes before it springs, burps up bubbles, its googly eyes rolling; it spits
	## silt and stretches itself out to engulf.
	"SILT_SLIME": {
		"mouth": "Mouth01",
		"idle": "_idle_slime",
		"groups": {
			"blob": {"parts": ["Body", "Eye", "Mouth", "Helmet", "Lamp", "Core", "Crystal", "Bob", "Rock05", "Rock06"], "at": Vector3(0, 0.0, 0)},
			"mouth": {"parts": ["Mouth"], "at": "Mouth01"},
			"helmet": {"parts": ["Helmet", "Lamp"], "at": "Helmet01"},
			"eye_l": {"parts": ["Eye01", "Eye03"], "at": "Eye01"},
			"eye_r": {"parts": ["Eye02", "Eye04"], "at": "Eye02"},
			"bud": {"parts": ["Core"], "at": Vector3(0.32, 0.3, -0.28)},
		},
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Boing: squashes flat, springs up tall and wobbles to rest, the helmet hopping on top.
			"jiggle": {"length": 1.8, "weight": 2.5, "do": [["move", "helmet", Vector3(0, -0.02, 0), Vector3(0, 0.07, 0), JIGGLE_LATE],
				["turn", "helmet", Z, -7.0, 7.0, JIGGLE_LATE], ["grow", "blob", Vector3(0.13, -0.17, 0.13), Vector3(-0.07, 0.15, -0.07), JIGGLE],
				["fx", 0.44, "puff", {"from": "feet", "color": "#8a9a70", "amount": 6, "size": 0.6, "rise": 0.2}]]},
			## A bubble works up through it: the bud on its back swells, eyes squint, and it burps.
			"burp": {"length": 2.4, "hold": 0.6, "weight": 1.5, "do": [["grow", "mouth", 0.0, Vector3(0.5, 1.2, 0.3), BURP],
				["each", "eye_l", 0.0, Vector3(0.1, -0.45, 0.0), BURP], ["each", "eye_r", 0.0, Vector3(0.1, -0.45, 0.0), BURP],
				["each", "bud", 0.0, 0.35, "f"], ["grow", "blob", 0.0, Vector3(0.06, -0.04, 0.06), "f"],
				["fx", 1.22, "bubbles", {"from": "Mouth01", "color": "core", "amount": 12, "size": 0.6}],
				["fx", 1.28, "puff", {"from": "Mouth01", "color": "#a8c890", "amount": 6, "size": 0.5, "rise": 0.5}]]},
			## Its eyes roll each their own way, then cross, the helmet lamp nodding.
			"googly": {"length": 2.6, "hold": 1.4, "weight": 1.5, "do": [["turn", "eye_l", X, 25.0, -30.0, GOOGLY], ["turn", "eye_r", X, -30.0, 25.0, GOOGLY],
				["turn", "eye_l", Y, 0.0, -25.0, CROSS], ["turn", "eye_r", Y, 0.0, 25.0, CROSS], ["turn", "helmet", X, 0.0, 10.0, "f"]]},
			## Melts down flat and wide, then draws itself back up, a little past, and settles.
			"sag": {"length": 2.6, "hold": 0.8, "weight": 1.0, "do": [["turn", "helmet", Z, 0.0, 6.0, "f"],
				["grow", "blob", Vector3(-0.05, 0.08, -0.05), Vector3(0.16, -0.24, 0.16), SAG],
				["fx", 0.6, "puff", {"from": "feet", "color": "#7a8a60", "amount": 8, "size": 0.8, "rise": 0.15}]]},
		},
		"moves": {
			## Squashes down, springs up and spits a glob of silt.
			"Ooze": [["grow", "mouth", Vector3(0.5, 0.9, 0.2), Vector3(0.7, 1.1, 0.3), "throw"],
				["turn", "helmet", X, 12.0, -10.0, "throw"],
				["grow", "blob", Vector3(0.14, -0.16, 0.14), Vector3(-0.08, 0.14, 0.12), "throw"],
				["fx", 0.17, "spit", {"color": "core", "flight": 0.17, "size": 1.3, "kind": "glob"}]],
			## Stretches itself out at the party, mouth gaping wide, bubbling, to swallow them.
			"Engulf": [["grow", "mouth", Vector3(0.4, 0.6, 0.2), Vector3(1.0, 1.4, 0.4), "big"],
				["each", "eye_l", 0.0, 0.12, "big"], ["each", "eye_r", 0.0, 0.12, "big"], ["turn", "helmet", X, 14.0, -14.0, "big"],
				["grow", "blob", Vector3(0.12, -0.14, 0.1), Vector3(0.1, -0.1, 0.5), "big"], ["rear", 0.45, "big"],
				["fx", 0.3, "bubbles", {"from": "Mouth01", "color": "core", "amount": 14, "size": 0.8}]],
			## The Spore Slime: the bud on its back swells and bursts, spores puffed at the party.
			"Spores": [["each", "bud", 0.4, -0.15, "throw"],
				["grow", "blob", Vector3(0.12, -0.12, 0.12), Vector3(-0.06, 0.12, -0.06), "throw"],
				["fx", 0.2, "puff", {"from": "Core01", "color": "accent", "amount": 22, "size": 1.3, "rise": 0.8, "glow": true}],
				["fx", 0.22, "breath", {"kind": "spores", "seconds": 0.35, "size": 0.7, "color": "accent"}]],
		},
	},
	## The Clouder: a cloud of floating cut stones round a lit heart, wisps trailing under it. It
	## drifts and bobs, its stones swirling slowly round the heart, its fog curling off it; it
	## billows out to gust at the party and draws in tight to guard.
	"CLOUDER": {
		"mouth": "Heart01",
		"ambient": [{"kind": "fog", "at": "Heart01", "size": 1.0, "color": "#b8c8e0"}],
		"groups": {
			"all": {"parts": ["Heart", "Eye", "Fog", "Wisp", "Orbit"], "at": Vector3(0, 0.98, 0)},
			"fog": {"parts": ["Fog", "Orbit", "Eye"], "at": "Heart01"},
			"puffs": {"parts": ["Fog", "Orbit", "Eye"], "at": "Heart01"},
			## Every stone but the one its eyes look out of: they wheel round its face.
			"ring": {"parts": ["Fog01-07", "Fog09", "Fog10", "Orbit", "Eye03"], "at": "Heart01"},
			"wisps": {"parts": ["Wisp"]},
			"eyes": {"parts": ["Eye"], "at": "Heart01"},
			"eye1": {"parts": ["Eye01"]},
			"eye2": {"parts": ["Eye02"]},
			"eye3": {"parts": ["Eye03"]},
		},
		"idle_gestures": [["sway", "ring", Y, 9.0, 0.45, 0.0], ["sway_each", "wisps", X, 7.0, 1.3, 0.9],
			["blink", "eye1", Vector3(1, 0.15, 1), 4.2, 0.0], ["blink", "eye2", Vector3(1, 0.15, 1), 4.2, 0.0], ["blink", "eye3", Vector3(1, 0.15, 1), 4.2, 0.0],
			["hover", "all", 0.05, 1.0, 3.5, 0.0]],
		"fidget_every": [5.5, 10.0],
		"fidgets": {
			## Billows out, its stones drifting apart, fog rolling off it, and draws back together.
			"billow": {"length": 2.8, "hold": 1.0, "weight": 2.0, "do": [["turn_each", "wisps", X, 0.0, -20.0, "f"], ["spread", "puffs", 0.0, 0.14, "f"],
				["fx", 0.7, "puff", {"from": "Heart01", "color": "#b8c4dc", "amount": 14, "size": 1.6, "life": 1.6, "rise": 0.25}],
				["fx", 1.3, "puff", {"from": "Heart01", "color": "#b8c4dc", "amount": 10, "size": 1.4, "life": 1.6, "rise": 0.2}]]},
			## Its stones wheel once round its face, fog curling after them.
			"wheel": {"length": 3.2, "hold": 1.4, "weight": 2.0, "do": [["whirl", "ring", Z, 1.0, "f"],
				["fx", 0.9, "puff", {"from": "Heart01", "color": "#c0cce4", "amount": 10, "size": 1.3, "life": 1.4, "rise": 0.15}],
				["fx", 1.7, "puff", {"from": "Heart01", "color": "#c0cce4", "amount": 10, "size": 1.3, "life": 1.4, "rise": 0.15}]]},
			## Drifts off to one side, banking, its wisps trailing, and back.
			"drift": {"length": 3.8, "hold": 1.4, "weight": 1.5, "do": [["turn_each", "wisps", Z, 0.0, -14.0, "f"], ["turn", "all", Z, 0.0, -9.0, "f"],
				["move", "all", Vector3.ZERO, Vector3(0.3, 0.06, 0), "f"],
				["fx", 1.2, "puff", {"from": "Heart01", "off": Vector3(-0.3, 0, 0), "color": "#b0bcd4", "amount": 8, "size": 1.2, "rise": 0.1}]]},
		},
		"moves": {
			## Draws itself in, then bursts out at the party, stones flung wide, in a gust of fog.
			"Puff": [["turn_each", "wisps", X, 25.0, -35.0, "attack"], ["spread", "puffs", -0.06, 0.1, "attack"], ["grow", "fog", -0.22, 0.25, "attack"],
				["lean", X, -8.0, 10.0, Vector3(0, 0.98, 0), "attack"], ["rear", 0.3, "attack"],
				["fx", 0.24, "breath", {"kind": "fog", "seconds": 0.3, "size": 1.0, "color": "#c8d4ea"}]],
			## Swells into a fog bank, eyes glowing through it, and rolls it out at the party.
			"Fog": [["each", "eyes", 0.0, 0.4, "pulse"], ["turn_each", "wisps", X, 0.0, -25.0, "hold"], ["grow", "fog", -0.1, 0.35, "hold"],
				["fx", 0.25, "puff", {"from": "Heart01", "color": "#a8b4cc", "amount": 30, "size": 2.2, "life": 1.8, "rise": 0.2}],
				["fx", 0.3, "breath", {"kind": "fog", "seconds": 0.5, "size": 1.0, "color": "#b0bcd4"}]],
			## Draws its stones in tight, wheeling them round its heart, mist pulled in after.
			"Gather": [["whirl", "ring", Z, 1.0, "hold"], ["turn_each", "wisps", X, 0.0, 25.0, "hold"], ["grow", "fog", 0.0, -0.3, "hold"],
				["fx", 0.2, "spiral", {"from": "Heart01", "color": "#d8e4ff"}]],
		},
	},
	## The Pit Mole: a near-blind digger with a gem nose and gold claws. It lives by its nose
	## (the snout lifts and twitches, whiskers flicking), scrapes at the dirt, rubs its snout,
	## shakes the dirt off; it digs into its mound and erupts from it, and rakes with both claws.
	"PIT_MOLE": {
		"burrow": "dig",
		"ground": ["Mound", "Rubble"],
		"hole": Vector3(0, 0.165, -0.05),
		"mouth": "Head02",
		"idle": "_idle_mole",
		"groups": {
			"head": {"parts": ["Head"], "at": "Head01"},
			"nose": {"parts": ["Head02"], "at": Vector3(0, 0.42, 0.97)},
			"whisk_l": {"parts": ["Head05", "Head07"], "at": Vector3(0.1, 0.43, 0.87)},
			"whisk_r": {"parts": ["Head06", "Head08"], "at": Vector3(-0.1, 0.43, 0.87)},
			"claw_l": {"parts": ["ClawL"], "at": "ClawL01"},
			"claw_r": {"parts": ["ClawR"], "at": "ClawR01"},
			"front": {"parts": ["Head", "ClawL", "ClawR", "Body01"], "at": Vector3(0, 0.3, -0.3)},
			"mound": {"parts": ["Mound01"]},
		},
		"idle_gestures": [["sway", "head", Y, 7.0, 0.9, 0.4]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Lifts its snout high and sniffs round the room, nose pulsing, whiskers flicking.
			"sniff_up": {"length": 3.4, "hold": 2.0, "weight": 3.0, "do": [["grow", "nose", 0.0, 0.3, "chew"],
				["turn", "whisk_l", Y, 10.0, -14.0, "wag"], ["turn", "whisk_r", Y, -10.0, 14.0, "wag"],
				["turn", "head", X, 0.0, -36.0, "f"], ["gaze", "head", 30.0, 8.0, "f", 3], ["turn", "front", X, 0.0, -16.0, "f"],
				["lean", X, 0.0, -5.0, Vector3(0, 0, -0.6), "f"]]},
			## Scrapes at the dirt in front of it, left claw and right in turn, dirt flying.
			"scrape": {"length": 2.4, "weight": 2.0, "do": [["turn", "claw_l", X, -45.0, 22.0, SCRAPE_L], ["turn", "claw_r", X, -45.0, 22.0, SCRAPE_R],
				["turn", "head", X, 0.0, 10.0, "f"], ["turn", "front", X, 0.0, 6.0, "f"],
				["fx", 0.46, "puff", {"from": "feet", "off": Vector3(0.35, 0.05, 0.5), "color": "#6a5a46", "amount": 5, "size": 0.6, "rise": 0.4}],
				["fx", 0.66, "puff", {"from": "feet", "off": Vector3(-0.35, 0.05, 0.5), "color": "#6a5a46", "amount": 5, "size": 0.6, "rise": 0.4}],
				["fx", 1.26, "puff", {"from": "feet", "off": Vector3(0.35, 0.05, 0.5), "color": "#6a5a46", "amount": 5, "size": 0.6, "rise": 0.4}],
				["fx", 1.46, "puff", {"from": "feet", "off": Vector3(-0.35, 0.05, 0.5), "color": "#6a5a46", "amount": 5, "size": 0.6, "rise": 0.4}]]},
			## Rubs its snout with both paws, head dipped into them.
			"groom": {"length": 2.8, "hold": 1.4, "weight": 1.5, "do": [["turn", "claw_l", Y, 0.0, -26.0, "f"], ["turn", "claw_l", X, 0.0, -48.0, "f"],
				["turn", "claw_l", X, 0.0, -12.0, "chew"], ["turn", "claw_r", Y, 0.0, 26.0, "f"], ["turn", "claw_r", X, 0.0, -48.0, "f"],
				["turn", "claw_r", X, 0.0, -12.0, "chew"], ["turn", "head", X, 0.0, 14.0, "f"], ["turn", "head", Y, 0.0, 6.0, "chew"]]},
			## Shakes the dirt off its coat.
			"shake": {"length": 1.5, "hold": 0.5, "weight": 1.0, "do": [["turn", "head", Z, -8.0, 8.0, "wag"], ["lean", Z, -6.0, 6.0, Vector3(0, 0.3, 0), "wag"],
				["fx", 0.45, "puff", {"from": "centre", "color": "#6a5a4a", "amount": 10, "size": 1.0, "rise": 0.3}],
				["fx", 0.55, "shards", {"from": "centre", "color": "#5a4a3a", "amount": 6, "speed": 2.0, "size": 0.6}]]},
		},
		"moves": {
			"Claw": [["turn", "claw_r", X, -75.0, 35.0, "attack"], ["turn", "claw_r", Z, 0.0, 15.0, "attack"],
				["turn", "front", X, -10.0, 10.0, "attack"], ["turn", "head", X, -10.0, 8.0, "attack"], ["rear", 0.3, "attack"],
				["fx", 0.29, "swipe", {"about": "claw_r", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 0.6, "sweep": 120.0}],
				["fx", 0.31, "shards", {"from": "feet", "off": Vector3(-0.3, 0.1, 0.7), "color": "#6a5a46", "amount": 5, "speed": 2.5}]],
			"Rake": [["turn", "claw_r", X, -70.0, 35.0, "attack"], ["turn", "claw_l", X, -70.0, 35.0, "second"],
				["turn", "front", X, -10.0, 10.0, "attack"], ["rear", 0.35, "second"],
				["fx", 0.29, "swipe", {"about": "claw_r", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 0.6, "sweep": 120.0}],
				["fx", 0.41, "swipe", {"about": "claw_l", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 0.6, "sweep": 120.0}]],
			"Dig In": [["turn", "claw_l", X, 0.0, 40.0, "scrabble"], ["turn", "claw_r", X, 0.0, -40.0, "scrabble"], ["turn", "head", X, 0.0, 25.0, "lift"]],
			"erupt": "_mole_erupt",
		},
		"heavy": {
			## Rake held: reared up on its haunches, both gold claws high and shaking, then down.
			"Rake": {"at": "ClawR04", "pose": [["turn", "front", X, 0.0, -14.0, "h"], ["lean", X, 0.0, -6.0, Vector3(0, 0, -0.6), "h"],
					["tremble", "claw_l", 0.008, "h"], ["tremble", "claw_r", 0.008, "h"]],
				"charge": [["charge_dust", {"seconds": 0.45}], ["sparks", {"from": "ClawR04", "color": "#ffd070", "amount": 10, "speed": 1.5}],
					["sparks", {"from": "ClawL04", "color": "#ffd070", "amount": 10, "speed": 1.5}]],
				"impact": [["shock", {"ahead": 0.9, "size": 1.0}],
					["shards", {"from": "feet", "off": Vector3(0, 0.15, 0.7), "color": "#6a5a46", "amount": 14, "speed": 4.5}],
					["puff", {"from": "feet", "off": Vector3(0, 0.1, 0.6), "color": "#6a5a46", "amount": 12, "size": 1.0, "rise": 0.6}]]},
			## Erupt held: the mound shudders over it, dirt lifting, before it bursts up.
			"Erupt": {"at": "feet", "pose": [["tremble", "mound", 0.015, "h"]],
				"charge": [["puff", {"from": "feet", "off": Vector3(0, 0.2, 0), "color": "#6a5a46", "amount": 12, "size": 1.0, "rise": 0.5}],
					["charge_dust", {"seconds": 0.45}], ["shards", {"from": "feet", "off": Vector3(0, 0.15, 0), "color": "#5a4a3a", "amount": 6, "speed": 1.5}]],
				"impact": [["shock", {"size": 1.6}], ["shards", {"from": "feet", "off": Vector3(0, 0.3, 0.1), "color": "#6a5a46", "amount": 16, "speed": 6.0}],
					["puff", {"from": "feet", "off": Vector3(0, 0.3, 0.1), "color": "#6a5a46", "amount": 16, "size": 1.8, "rise": 1.4}]]},
		},
	},
	## The Vein Wraith (and the Mycel Wraith, in its colours): a jellyfish of the deep veins, a
	## stone bell with six crystal tendrils hung from its rim and three shards under its heart. It
	## swims: the bell squeezes as it thrusts up, then it drifts down slow, the crystals trailing
	## behind like flagella and flaring out as the bell opens again.
	"VEIN_WRAITH": {
		"mouth": "Heart01",
		"burrow": "fade",
		"groups": {
			"all": {"parts": ["Body", "Heart", "Eye", "Crest", "Tendril", "Trail", "Orbit"], "at": Vector3(0, 1.05, 0)},
			"tendrils": {"parts": ["Tendril"], "at": Vector3(0, 1.32, 0)},
			"trail": {"parts": ["Trail"], "at": Vector3(0, 0.95, 0)},
			"hood": {"parts": ["Body01", "Crest", "Eye"], "at": Vector3(0, 1.32, 0)},
			"streamers": {"parts": ["Tendril", "Trail"], "at": Vector3(0, 1.32, 0)},
		},
		"idle_gestures": [["swim", {"body": "all", "bell": "hood", "trail": "streamers", "rate": 0.4, "rise": 0.075, "squeeze": 0.09, "flare": 10.0,
				"lag": 0.1, "ripple": 0.02}], ["sway_each", "tendrils", X, 3.0, 1.1, 0.9]],
		"fidget_every": [4.0, 8.0],
		"fidgets": {
			## Swims up in three strong pulses, leaving a wake of motes, and sinks slowly back.
			"swim_up": {"length": 4.6, "weight": 3.0, "idle": 0.0, "do": [["swim", {"body": "all", "bell": "hood", "trail": "streamers", "pulses": 3,
					"beat": 0.8, "rise": 0.18, "sink": 2.0, "squeeze": 0.2, "flare": 22.0, "lag": 0.14, "ripple": 0.03, "start": 0.2}],
				["fx", 0.36, "puff", {"from": "Heart01", "color": "accent", "amount": 6, "size": 0.6, "rise": 0.12, "glow": true}],
				["fx", 1.16, "puff", {"from": "Heart01", "color": "accent", "amount": 6, "size": 0.6, "rise": 0.12, "glow": true}],
				["fx", 1.96, "puff", {"from": "Heart01", "color": "accent", "amount": 6, "size": 0.6, "rise": 0.12, "glow": true}]]},
			## Its crystals ripple one after another round the rim, like flagella beating.
			"flagella": {"length": 2.6, "hold": 1.2, "weight": 2.0, "do": [["wave_each", "tendrils", "out", 16.0, 8.0, 1.05, "f"],
				["wave_each", "trail", X, 10.0, 6.0, 1.3, "f"], ["each", "Heart01", 0.0, 0.2, "f"]]},
			## Turns lazily to look aside, tilting as it goes, its crystals trailing.
			"drift": {"length": 3.4, "hold": 1.2, "weight": 1.5, "do": [["turn", "all", Y, 0.0, 38.0, "f"], ["turn", "all", Z, 0.0, 7.0, "f"],
				["splay", "streamers", 0.0, 8.0, "f"]]},
		},
		"moves": {
			## Reaches its crystals out at the party and drinks, the bell pulsing as it pulls.
			"Drain": [["turn_each", "tendrils", X, 20.0, -45.0, "hold"], ["turn", "all", X, -6.0, 12.0, "attack"], ["rear", 0.25, "attack"],
				["grow", "hood", 0.0, Vector3(-0.08, 0.05, -0.08), "chew"],
				["fx", 0.22, "drain", {"from": "Heart01", "color": "accent", "count": 2, "start": 0.55, "halo": 2.5}]],
			## Squeezes its bell shut in one hard contraction, crystals flung wide, and screams.
			"Wail": [["splay", "streamers", -12.0, 45.0, "attack"], ["grow", "hood", Vector3(0.1, -0.06, 0.1), Vector3(-0.16, 0.1, -0.16), "attack"],
				["turn", "all", X, -14.0, 8.0, "attack"], ["each", "Heart01", 0.0, 0.5, "pulse"],
				["fx", 0.28, "ripple", {"from": "Heart01", "color": "accent", "radius": 1.6}],
				["fx", 0.38, "ripple", {"from": "Heart01", "color": "accent", "radius": 2.2}],
				["fx", 0.48, "ripple", {"from": "Heart01", "color": "accent", "radius": 2.8}]],
			"Fade": [["splay", "tendrils", 0.0, -25.0, "hold"], ["fx", 0.3, "puff", {"from": "Heart01", "color": "tint", "amount": 16, "size": 1.4, "glow": true}]],
			## The Mycel Wraith: draws its crystals up short and grows them out again, green motes rising.
			"Regrow": [["each", "tendrils", Vector3(0, -0.4, 0), Vector3(0, 0.35, 0), "attack"], ["grow", "hood", 0.0, Vector3(0.1, -0.04, 0.1), "pulse"],
				["fx", 0.3, "glow", {"from": "Heart01", "color": "#6fe3b0", "size": 0.9}],
				["fx", 0.32, "rise", {"from": "Heart01", "color": "#6fe3b0", "amount": 14, "size": 1.0}]],
		},
		"heavy": {
			## Its Wail held: it rises, the bell swelling with the breath it is about to let go.
			"Wail": {"pose": [["move", "all", Vector3.ZERO, Vector3(0, 0.14, 0), "h"], ["grow", "hood", 0.0, Vector3(0.12, -0.04, 0.12), "h"],
					["splay", "streamers", 0.0, -10.0, "h"]],
				"impact": [["ripple", {"from": "Heart01", "color": "accent", "radius": 3.4}], ["ring", {"color": "accent", "radius": 3.0}]]},
		},
	},
	## The Lantern Moth (and the Will-o'-Wisp and the Cinder Moth): a crystal moth with a lit gem
	## lamp for a head. It hovers on beating wings, bobbing and tilting, circles round its own
	## light, rests its wings and sinks before it catches itself; it flutters its light at the party.
	"LANTERN_MOTH": {
		"mouth": "Core02",
		"groups": {
			"all": {"parts": ["Core01", "Core02", "Wing01", "Wing02"], "at": Vector3(0, 1.35, 0)},
			## The moth without its lamp: what flies round the light.
			"body": {"parts": ["Core01", "Wing01", "Wing02"], "at": Vector3(0, 1.35, 0)},
			"wing_r": {"parts": ["Wing01"], "at": "Wing01"},
			"wing_l": {"parts": ["Wing02"], "at": "Wing02"},
			"lamp": {"parts": ["Core02"]},
		},
		"idle": "_idle_moth",
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Flies a loop round its own lamp, banking into the turn, the lamp brightening.
			## (Up near its lamp: lower, its wings swept through the light it casts and flared white.)
			"circle": {"length": 3.2, "hold": 1.6, "weight": 2.5, "do": [["turn", "body", Z, 0.0, -12.0, "f"],
				["move", "body", Vector3.ZERO, Vector3(-0.36, 0.2, 0), "f"], ["whirl", "body", Y, -1.0, "f"], ["each", "lamp", 0.0, 0.2, "f"]]},
			## Stops beating, lifts its wings together over its back and sinks a little, settles
			## them with two shuffles and beats on, rising back.
			"settle": {"length": 2.8, "hold": 1.3, "weight": 2.0, "do": [["call", "_wings_still"],
				["turn", "wing_l", Z, 0.0, 55.0, WING_REST], ["turn", "wing_r", Z, 0.0, -55.0, WING_REST],
				["move", "all", Vector3.ZERO, Vector3(0, -0.1, 0), "f"]]},
			## Tips up to gaze at its own light as it swells, sparks of it drifting off.
			"flare": {"length": 2.2, "hold": 0.7, "weight": 1.5, "do": [["grow", "lamp", 0.0, 0.35, "f"], ["move", "lamp", Vector3.ZERO, Vector3(0, 0.08, 0.04), "f"],
				["turn", "body", X, 0.0, -12.0, "f"],
				["fx", 0.8, "puff", {"from": "Core02", "color": "accent", "amount": 6, "size": 0.5, "rise": 0.4, "glow": true}]]},
		},
		"moves": {
			## Darts in on a burst of wingbeats and throws a mote of its light.
			"Flutter": [["turn", "wing_l", Z, 0.0, 35.0, "flutter"], ["turn", "wing_r", Z, 0.0, -35.0, "flutter"],
				["lean", X, -6.0, 10.0, Vector3(0, 1.35, 0), "attack"], ["rear", 0.25, "attack"],
				["fx", 0.15, "bolt", {"from": "Core02", "color": "accent", "flight": 0.15}]],
			## The Will-o'-Wisp: its light gutters on and off, and a mote of it flies.
			"Flicker": [["turn", "wing_l", Z, 0.0, 35.0, "flutter"], ["turn", "wing_r", Z, 0.0, -35.0, "flutter"], ["grow", "lamp", -0.35, 0.4, "shake"],
				["lean", X, -6.0, 8.0, Vector3(0, 1.35, 0), "attack"],
				["fx", 0.15, "bolt", {"from": "Core02", "color": "accent", "flight": 0.15}]],
			## Its lamp flares hot as it rears back, and it throws a burning mote.
			"Singe": [["turn", "wing_l", Z, 0.0, 30.0, "flutter"], ["turn", "wing_r", Z, 0.0, -30.0, "flutter"], ["grow", "lamp", 0.0, 0.5, "attack"],
				["lean", X, -10.0, 8.0, Vector3(0, 1.35, 0), "attack"],
				["fx", 0.15, "bolt", {"from": "Core02", "color": "#ff8a30", "flight": 0.15, "size": 1.3}]],
			## Holds its lamp up high and bright, wings spread round it.
			"Lantern": [["move", "lamp", Vector3.ZERO, Vector3(0, 0.12, 0.05), "hold"], ["grow", "lamp", 0.0, 0.6, "hold"],
				["turn", "wing_l", Z, 0.0, 25.0, "hold"], ["turn", "wing_r", Z, 0.0, -25.0, "hold"], ["turn", "body", X, 0.0, -10.0, "hold"],
				["fx", 0.3, "glow", {"from": "Core02", "color": "accent", "size": 1.1}],
				["fx", 0.3, "flash_light", {"from": "Core02", "color": "accent"}]],
			## The Will-o'-Wisp: swings its lamp slowly side to side before the party, rings of light spreading.
			"Lure": [["move", "lamp", Vector3(-0.12, 0, 0), Vector3(0.12, 0, 0), LURE_SWAY], ["grow", "lamp", 0.0, 0.5, "hold"],
				["fx", 0.25, "ripple", {"from": "Core02", "color": "accent", "radius": 1.4}],
				["fx", 0.4, "ripple", {"from": "Core02", "color": "accent", "radius": 2.0}]],
			## The Cinder Moth: beats its wings hard and a shower of embers blows off them at the party.
			"Embers": [["turn", "wing_l", Z, 0.0, 30.0, "flutter"], ["turn", "wing_r", Z, 0.0, -30.0, "flutter"],
				["lean", X, 6.0, -6.0, Vector3(0, 1.35, 0), "breath"],
				["fx", 0.2, "sparks", {"from": "Core01", "color": "#ff8a30", "amount": 16, "speed": 2.0}],
				["fx", 0.22, "breath", {"from": "Core02", "kind": "fire", "seconds": 0.4, "size": 0.4}]],
		},
	},
}

# --- the moves and idles no table says ---------------------------------------------------------

static func _clock_of(m: Node3D) -> float:
	## The creature's own clock, the one its parts idle by.
	return float(m._creature.get("_clock"))

static func _beat(m: Node3D, clock: float, every: float, salt: int) -> float:
	## Where a creature is in an intermittent beat of about `every` seconds, each beat starting at a
	## time of its own (its noise): the seconds since this beat's start, negative before it.
	var step: int = int(floor(clock / every))
	return clock - float(step) * every - every * 0.25 * (1.0 + m._noise(step * 3 + m.noise_seed + salt))

## The Rail Rat (an older scene): its head bobs on its own, and its ears and eyes are separate
## pieces that stayed put and slid off it. They are carried with it here, its bob softened, every
## frame: by the idle, or by a move's call while the idle is eased out.
static func _rat_carry(m: Node3D) -> void:
	var bob: float = sin(_clock_of(m) * 2.2 + 0.4) * 0.1
	m.shift(m._select("Bob01"), Vector3(0, -0.6 * bob, 0))
	m.shift(m._select(["Cone", "Sphere"]), Vector3(0, 0.4 * bob, 0))

static func _rat_hold(m: Node3D, _clip: Dictionary, _delta: float) -> void:
	if float(m._idle_weight) <= 0.001:
		_rat_carry(m)

static func _idle_rat(m: Node3D, clock: float, weight: float) -> void:
	## Sniffs the air in quick bursts, the snout lifting and twitching; now and then one ear or the
	## other flicks.
	_rat_carry(m)
	var head: Dictionary = m.group("head")
	var local: float = _beat(m, clock, 2.7, 0)
	if local > 0.0 and local < 1.0:
		var up: float = smoothstep(0.0, 0.18, local) * (1.0 - smoothstep(0.75, 1.0, local))
		var twitch: float = sin(local * 34.0) * up
		m.turn(head.parts, head.joint, Vector3.RIGHT, deg_to_rad(-9.0 * up - 3.5 * twitch) * weight)
	var at: float = _beat(m, clock + 1.1, 3.3, 7)
	if at > 0.0 and at < 0.3:
		var flick: float = smoothstep(0.0, 0.05, at) * (1.0 - smoothstep(0.08, 0.3, at))
		var left: bool = m._noise(int(floor((clock + 1.1) / 3.3)) * 11 + m.noise_seed) > 0.0
		var ear: Dictionary = m.group("ear_l" if left else "ear_r")
		m.turn(ear.parts, ear.joint, Vector3.BACK, deg_to_rad(-28.0 if left else 28.0) * flick * weight)

static func _tick_shuffle(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The Cave Tick steps its eight legs in place, one pair after another from the front, the two
	## sides out of step: each leg lifted out from its hip and set down.
	var t: float = float(clip.get("keyed", 0.0))
	var weight: float = float(clip.get("weight", 1.0))
	for index in range(TICK_STEPS.size()):
		var leg: Array = TICK_STEPS[index]
		var x: float = clampf((t - 0.3 - 0.17 * float(index)) / 0.3, 0.0, 1.0)
		var lift: float = sin(x * PI) * weight
		if lift <= 0.0001:
			continue
		m.turn(m._select(leg[0]), leg[1], Vector3.BACK, deg_to_rad(22.0 * float(leg[2])) * lift)

static func _idle_magpie(m: Node3D, clock: float, weight: float) -> void:
	## Every few seconds it bends to the floor and pecks at a nugget there, twice, and looks up;
	## between times it flicks its tail up, as magpies do, and lets it fall, and looks about.
	var all: Dictionary = m.group("all")
	var head: Dictionary = m.group("head")
	var tail: Dictionary = m.group("tail")
	var at: float = _beat(m, clock + 0.9, 2.3, 3)
	if at > 0.0 and at < 0.7:
		var flick: float = smoothstep(0.0, 0.07, at) * (1.0 - smoothstep(0.12, 0.7, at))
		m.turn(tail.parts, tail.joint, Vector3.RIGHT, deg_to_rad(26.0) * flick * weight)
	var p: float = fposmod(clock + 2.5 + float(posmod(int(m.noise_seed), 13)) * 0.5, 6.5)
	var down: float = 0.0
	if p <= 1.7:
		down = smoothstep(0.0, 0.4, p) * (1.0 - smoothstep(1.3, 1.7, p))
		var peck: float = 0.0
		if p > 0.45 and p < 1.25:
			peck = absf(sin((p - 0.45) * PI / 0.4))
		m.turn(tail.parts, tail.joint, Vector3.RIGHT, deg_to_rad(-18.0) * down * weight)
		m.turn(head.parts, head.joint, Vector3.RIGHT, deg_to_rad(52.0 * down + 14.0 * peck) * weight)
	## Looks about between pecks (its head: laid before the whole bird bends).
	m._idle_gesture(["look", "head", 16.0, 6.0, 2.9, 0.45], weight * (1.0 - down))
	if down > 0.0:
		m.turn(all.parts, all.joint, Vector3.RIGHT, deg_to_rad(26.0) * down * weight)

static func _idle_slime(m: Node3D, clock: float, weight: float) -> void:
	## A jelly's wobble: it squats and swells and draws up again, its googly eyes looking about,
	## the helmet riding a beat behind on top.
	m._idle_gesture(["look", "eye_l", 24.0, 12.0, 2.6, 0.45], weight)
	m._idle_gesture(["look", "eye_r", 24.0, 12.0, 2.6, 0.45], weight)
	var helmet: Dictionary = m.group("helmet")
	var lag: float = sin(clock * 2.6 - 1.1)
	m.turn(helmet.parts, helmet.joint, Vector3.BACK, deg_to_rad(3.0 * sin(clock * 1.3 + 0.5)) * weight)
	m.turn(helmet.parts, helmet.joint, Vector3.RIGHT, deg_to_rad(2.5) * lag * weight)
	m.shift(helmet.parts, Vector3(0, 0.012 * lag, 0) * weight)
	var blob: Dictionary = m.group("blob")
	var k: float = (sin(clock * 2.6) * 0.022 + sin(clock * 4.1 + 0.6) * 0.008) * weight
	m.swell(blob.parts, blob.joint, Vector3(1.0 + k * 0.7, 1.0 - k, 1.0 + k * 0.7))

static func _idle_mole(m: Node3D, clock: float, weight: float) -> void:
	## Near blind, it lives by its nose: every couple of seconds the snout lifts and twitches, the
	## gem nose pulsing and the whiskers flicking forward with each sniff.
	var local: float = _beat(m, clock, 2.4, 1)
	if local <= 0.0 or local >= 1.1:
		return
	var up: float = smoothstep(0.0, 0.2, local) * (1.0 - smoothstep(0.8, 1.1, local))
	var sniff: float = maxf(0.0, sin(local * 26.0)) * up * weight
	var nose: Dictionary = m.group("nose")
	var whisk_l: Dictionary = m.group("whisk_l")
	var whisk_r: Dictionary = m.group("whisk_r")
	var head: Dictionary = m.group("head")
	m.swell(nose.parts, nose.joint, Vector3.ONE * (1.0 + 0.25 * sniff))
	m.turn(whisk_l.parts, whisk_l.joint, Vector3.UP, deg_to_rad(-12.0) * sniff)
	m.turn(whisk_r.parts, whisk_r.joint, Vector3.UP, deg_to_rad(12.0) * sniff)
	m.turn(head.parts, head.joint, Vector3.RIGHT, deg_to_rad(-8.0 * up * weight - 3.0 * sniff))

static func _idle_moth(m: Node3D, clock: float, weight: float) -> void:
	## Hovers on its beating wings, bobbing and tilting, its lamp bobbing a beat behind; eased in
	## over its first second or so, as it finds its height (and so a moth just made still wears its
	## wings' authored pose).
	var w: float = weight * smoothstep(0.5, 1.5, clock)
	if w <= 0.0:
		return
	m._idle_gesture(["bob", "lamp", Vector3(0, 0.025, 0), 1.6, -1.2], w)
	m._idle_gesture(["hover", "all", 0.06, 1.6, 6.0, 0.0], w)

static func _wings_still(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its wings stop beating for a while (each turned back against its own beat, so it holds its
	## rest pose), and take the beat up again as the clip lets go: a moth resting them.
	var t: float = float(clip.get("keyed", 0.0))
	var length: float = float(clip.get("length", 2.8))
	var k: float = smoothstep(0.05, 0.35, t) * (1.0 - smoothstep(length - 0.85, length - 0.45, t)) * float(clip.get("weight", 1.0))
	if k <= 0.0001:
		return
	var clock: float = _clock_of(m)
	for part in m._select(["Wing", "WingL", "WingR"]):
		if str(part.get("motion")) != "wing":
			continue
		var beat: float = sin(clock * 11.0 + float(part.get("phase"))) * 0.55 * float(part.get("wing_side"))
		var rest: Transform3D = part.get("_rest")
		var euler: Vector3 = rest.basis.orthonormalized().get_euler()
		var axis: Vector3 = Basis.from_euler(Vector3(euler.x, euler.y, 0.0)) * Vector3.BACK
		m.turn([part], rest.origin, axis, -beat * k)

static func _mole_erupt(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Up out of its crater, snout to the sky and both claws thrown wide, and back to how it
	## stands. Bursts up only when it was under; above ground it rears into the same shape.
	var t: float = float(clip.t)
	if not clip.has("under"):
		clip.under = m._dig_state == "erupting"
		m._dig = 0.0
	var under: Array = m._dig_parts()
	if bool(clip.under):
		var y: float = -1.15
		if t >= 0.12 and t < HIT:
			var x: float = (t - 0.12) / (HIT - 0.12)
			y = lerpf(-1.15, 0.22, 1.0 - (1.0 - x) * (1.0 - x))
		elif t >= HIT:
			y = lerpf(0.22, 0.0, smoothstep(HIT, 0.6, t))
		m.shift(under, Vector3(0, y, 0))
		for part in under:
			part.visible = true
		m._show_hole(1.0 - smoothstep(0.1, 0.25, t))
		if t >= 0.1:
			m._queue(clip, "dirt", "puff", {"from": "feet", "off": Vector3(0, 0.3, 0.1), "color": Color(0.42, 0.34, 0.26), "amount": 16, "size": 1.6, "rise": 1.2})
		if t >= 0.2:
			m._queue(clip, "rocks", "shards", {"from": "feet", "off": Vector3(0, 0.3, 0.1), "color": Color(0.5, 0.42, 0.33), "amount": 14, "speed": 5.0})
	var b: float = smoothstep(0.12, HIT, t) * (1.0 - smoothstep(0.62, 1.05, t))
	var head: Dictionary = m.group("head")
	var claw_l: Dictionary = m.group("claw_l")
	var claw_r: Dictionary = m.group("claw_r")
	var front: Dictionary = m.group("front")
	m.turn(claw_l.parts, claw_l.joint, Vector3.RIGHT, deg_to_rad(-45.0) * b)
	m.turn(claw_l.parts, claw_l.joint, Vector3.BACK, deg_to_rad(75.0) * b)
	m.turn(claw_r.parts, claw_r.joint, Vector3.RIGHT, deg_to_rad(-45.0) * b)
	m.turn(claw_r.parts, claw_r.joint, Vector3.BACK, deg_to_rad(-75.0) * b)
	m.turn(head.parts, head.joint, Vector3.RIGHT, deg_to_rad(-65.0) * b)
	m.turn(front.parts, front.joint, Vector3.RIGHT, deg_to_rad(-18.0) * b)
	if t >= HIT:
		m._queue(clip, "burst", "shock", {"size": 1.2})
	if t >= float(clip.length):
		m._dig_state = "settling"
		m._dig_clock = 0.0
		m._show_hole(0.0)
