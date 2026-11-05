extends RefCounted
## The Geode: the mine of hoards and gamblers. The Croupier Crab, the Geode Golem, the Hoard
## Mimic, the Crystal Hydra and the Hollow's Wardens (the Assayer, the Collector, the Hollow
## Crown). Each creature's rig as data (see the gesture language in creature_rigs.gd), keyed by
## its scene, and the moves and idles no table says, written out as functions of the Moves node
## (creature_moves.gd) passed in as `m`. creature_rigs.gd merges every mine's RIGS.
##
## Several of these parts swing on their own (the crab's claws and eye stalks, the Collector's
## stalks and cane, the Assayer's balance: creature_part.gd "swing", up to 12 degrees). Anything
## turned about a part's own pivot is fine; anything squashed or flipped about a point on such a
## part is done here, about where that point is this frame (`_blink_now`, `_crab_coin`,
## `_hang_pans`), not where it rests.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {
	"_mimic_gulp": 1.0,
	"_hydra_bite": 1.0,
	"_hydra_roar": 1.2,
}
## When a move played by a function is wound back furthest (a heavy one holds there).
const CUSTOM_WIND: Dictionary = {
}

## Envelopes only these creatures use ([time s, value] keys, as creature_rigs.gd ENV).
## The crab's coin tossed up off its claw and caught (in its flip fidget's own time).
const COIN_TOSS: Array = [[0.0, 0.0], [0.78, 0.0], [1.02, 1.0], [1.28, 0.0]]
## Both claws clacked together twice (+1 shut on each other, -1 spread).
const CLACK: Array = [[0.0, 0.0], [0.55, -0.5], [0.72, 1.0], [0.86, -0.4], [1.04, 1.0], [1.35, 0.0]]
## The mimic's lid chomping twice, teeth clashing (+1 flung open, -1 clamped shut).
const MIMIC_CHOMP: Array = [[0.0, 0.0], [0.3, 1.0], [0.42, -1.0], [0.52, -1.0], [0.7, 0.6], [0.82, -1.0], [0.92, -1.0], [1.3, 0.0]]
## The chest hopping on its iron feet, twice and a little third.
const MIMIC_HOPS: Array = [[0.0, 0.0], [0.3, 1.0], [0.45, 0.0], [0.62, 0.7], [0.78, 0.0], [0.9, 0.25], [1.0, 0.0]]
## The golem grinding its blocks round one way, back the other, and home.
const GRIND: Array = [[0.0, 0.0], [0.6, 1.0], [1.25, -0.8], [1.85, 0.55], [2.4, 0.0]]
## A boulder rocking on its base, less each time.
const ROCK: Array = [[0.0, 0.0], [0.6, 1.0], [1.2, -0.7], [1.7, 0.4], [2.1, -0.15], [2.5, 0.0]]
## The Assayer's balance: weighing (the gold dips, bobbles, settles and comes back level) ...
const WEIGH: Array = [[0.0, 0.0], [0.8, 1.0], [1.05, 0.6], [1.3, 0.92], [1.55, 0.75], [2.3, 0.82], [3.2, 0.0]]
## ... tipped hard and rocking to level, less each time ...
const TIP: Array = [[0.0, 0.0], [0.35, 1.0], [0.75, -0.6], [1.1, 0.36], [1.45, -0.2], [1.8, 0.1], [2.3, 0.0]]
## ... its gem lifted and dropped on its chain, tap, tap, tap, the beam jolting at each.
const TAPS: Array = [[0.0, 0.0], [0.35, 1.0], [0.47, 0.0], [0.7, 1.0], [0.82, 0.0], [1.05, 1.0], [1.17, 0.0], [2.0, 0.0]]
const TAP_JOLT: Array = [[0.0, 0.0], [0.47, 0.0], [0.52, 1.0], [0.62, 0.0], [0.82, 0.0], [0.87, 1.0], [0.97, 0.0], [1.17, 0.0], [1.22, 1.0], [1.32, 0.0], [2.0, 0.0]]
## Its eye reading the party from one side to the other.
const AUDIT_SCAN: Array = [[0.0, 0.0], [0.15, -1.0], [0.5, 1.0], [0.72, 1.0], [1.0, 0.0]]
## The Collector's cane tapped twice, impatient.
const CANE_TAPS: Array = [[0.0, 0.0], [0.45, 1.0], [0.62, -0.1], [0.75, 0.0], [1.05, 1.0], [1.22, -0.1], [1.35, 0.0], [2.4, 0.0]]
## Its cases lit one after another as it rummages (a fidget's time) or shows them off (a move's).
const CASE_A: Array = [[0.0, 0.0], [0.7, 0.0], [0.85, 1.0], [1.25, 0.0]]
const CASE_B: Array = [[0.0, 0.0], [1.0, 0.0], [1.15, 1.0], [1.55, 0.0]]
const CASE_C: Array = [[0.0, 0.0], [1.3, 0.0], [1.45, 1.0], [1.85, 0.0]]
const SHOW_A: Array = [[0.0, 0.0], [0.12, 0.0], [0.22, 1.0], [0.5, 0.0]]
const SHOW_B: Array = [[0.0, 0.0], [0.22, 0.0], [0.32, 1.0], [0.6, 0.0]]
const SHOW_C: Array = [[0.0, 0.0], [0.32, 0.0], [0.42, 1.0], [0.7, 0.0]]
## The cane held up through a sweep, swept under it.
const SWEEP_LIFT: Array = [[0.0, 0.0], [0.18, 1.0], [0.8, 1.0], [1.25, 0.0]]
## The Hollow Crown: an arm raised and kept up through a blow it brings down from overhead
## (laid under the blow's own turn) ...
const OVERHEAD: Array = [[0.0, 0.0], [0.2, 1.0], [0.5, 1.0], [1.15, 0.0]]
## ... a stride: one foot lifted slowly and stamped down ...
const STOMP: Array = [[0.0, 0.0], [0.8, 1.0], [1.2, 1.0], [1.34, -0.2], [1.55, 0.0], [2.8, 0.0]]
## ... its crown slipping askew, wobbling, and set straight by its hand ...
const CROWN_SLIP: Array = [[0.0, 0.0], [0.5, 1.0], [0.75, 0.8], [1.0, 1.0], [1.25, 0.9], [2.1, 0.9], [2.45, 0.0], [3.6, 0.0]]
const HAND_UP: Array = [[0.0, 0.0], [0.9, 0.0], [1.8, 1.0], [2.5, 1.0], [3.4, 0.0], [3.6, 0.0]]
## ... the bird fluttering up off its shoulder and back, the giant turning to watch it ...
const BIRD_HOP: Array = [[0.0, 0.0], [0.3, 0.0], [0.6, 1.0], [1.3, 1.0], [1.7, 0.0], [3.0, 0.0]]
const BIRD_LOOK: Array = [[0.0, 0.0], [0.5, 0.0], [1.0, 1.0], [2.2, 1.0], [3.0, 0.0]]
const WINGBEATS: Array = [[0.0, 0.0], [0.25, 0.0], [0.33, 1.0], [0.41, 0.0], [0.49, 1.0], [0.57, 0.0], [0.65, 1.0], [0.73, 0.0], [0.81, 1.0],
	[0.89, 0.0], [1.4, 0.0], [1.48, 0.7], [1.56, 0.0], [1.64, 0.7], [1.72, 0.0], [3.0, 0.0]]
## ... and lurching as it stumbles.
const LURCH: Array = [[0.0, 0.0], [0.2, 1.0], [0.45, -0.6], [0.7, 0.3], [1.0, 0.0]]

## The Assayer's balance tips about this axis (+ lifts the gold pan's end), its pans hung from
## these hooks at the beam's ends.
const BEAM := Vector3(-0.42, 0, 0.91)
const PAN_HOOKS: Dictionary = {"PanL": Vector3(1.09, 0.88, 0.51), "PanR": Vector3(-1.09, 0.88, -0.51)}

const RIGS: Dictionary = {
	## The Croupier Crab: a hermit crab in an iron cauldron, dealing in pyrite. A crab clacks its
	## claws, sidesteps and scuttles, its eyes on stalks looking every way; a croupier flips its
	## coin, riffles the pot and rakes the table in.
	"CROUPIER_CRAB": {
		"idle": "_idle_crab",
		"groups": {"big": {"parts": ["ClawR"], "at": "ClawR01"}, "small": {"parts": ["ClawL"], "at": "ClawL01"},
			"pot": {"parts": ["Shell", "Core01"], "at": "Shell01"}, "front": {"parts": ["Head", "Eye", "ClawR", "ClawL"], "at": "Head01"},
			"eye_l": {"parts": ["Eye01-02"], "at": "Eye01"}, "eye_r": {"parts": ["Eye03-04"], "at": "Eye03"}, "floor": {"parts": ["Cylinder04-07"]}},
		"idle_gestures": [["look", "eye_l", 26.0, 14.0, 2.3, 0.5], ["look", "eye_r", 26.0, 14.0, 2.9, 0.5], ["flex", "small", X, -16.0, 3.4, 0.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Scuttles a step to its left and back, claws up, the cauldron rolling on its side.
			"sidestep": {"length": 2.4, "hold": 0.5, "weight": 2.0, "do": [["call", "_crab_scuttle"], ["turn", "big", X, 0.0, -12.0, "f"],
				["turn", "small", X, 0.0, -16.0, "f"], ["turn", "pot", Z, 0.0, -4.0, "f"], ["hop", Vector3.ZERO, Vector3(0.26, 0.0, 0.0), "f"],
				["move", "floor", Vector3.ZERO, Vector3(-0.26, 0.0, 0.0), "f"],
				["fx", 0.5, "puff", {"from": "feet", "color": "#8a7a66", "amount": 5, "size": 0.5, "rise": 0.2}],
				["fx", 1.9, "puff", {"from": "feet", "color": "#8a7a66", "amount": 5, "size": 0.5, "rise": 0.2}]]},
			## Flips its coin off the big claw, end over end, eyes following it up, and catches it.
			"flip": {"length": 2.2, "hold": 0.7, "weight": 2.0, "do": [["call", "_crab_coin"], ["turn", "big", X, 0.0, -30.0, "f"],
				["turn", "eye_l", X, 0.0, -16.0, "f"], ["turn", "eye_r", X, 0.0, -16.0, "f"],
				["fx", 1.02, "sparks", {"from": "ClawR05", "color": "#fff0b0", "amount": 8, "speed": 1.2}],
				["fx", 1.3, "sparks", {"from": "ClawR05", "color": "#ffd060", "amount": 6, "speed": 1.0}]]},
			## Raises both claws and clacks them together, twice.
			"clack": {"length": 2.0, "hold": 0.6, "weight": 1.5, "do": [["turn", "big", Y, -10.0, 26.0, CLACK], ["turn", "small", Y, 10.0, -28.0, CLACK],
				["turn", "big", X, 0.0, -18.0, "f"], ["turn", "small", X, 0.0, -24.0, "f"],
				["fx", 0.72, "sparks", {"from": "ClawR03", "color": "#ffd060", "amount": 8, "speed": 1.6}],
				["fx", 1.04, "sparks", {"from": "ClawR03", "color": "#ffd060", "amount": 8, "speed": 1.6}]]},
			## Riffles the pyrite with its small claw, tap tap tap, peering down at it.
			"shuffle": {"length": 2.6, "hold": 1.4, "weight": 1.5, "do": [["turn", "small", X, 0.0, 9.0, "chew"], ["turn", "small", Y, 0.0, -12.0, "f"],
				["turn", "eye_l", X, 0.0, 14.0, "f"], ["turn", "eye_r", X, 0.0, 14.0, "f"], ["turn", "front", X, 0.0, 5.0, "f"],
				["fx", 0.86, "shards", {"from": "ClawL03", "color": "#c8902a", "amount": 3, "speed": 1.2}],
				["fx", 1.43, "shards", {"from": "ClawL03", "color": "#c8902a", "amount": 3, "speed": 1.2}],
				["fx", 1.43, "sparks", {"from": "ClawL03", "color": "#fff0b0", "amount": 5, "speed": 1.0}],
				["fx", 2.0, "shards", {"from": "ClawL03", "color": "#c8902a", "amount": 3, "speed": 1.2}]]},
		},
		"moves": {
			## The big claw drawn back and snapped shut on the party, legs pattering as it lunges.
			"Pinch": [["turn", "big", Y, -22.0, 22.0, "attack"], ["turn", "big", X, -42.0, 12.0, "attack"], ["turn", "small", X, 0.0, -18.0, "attack"],
				["turn", "eye_l", X, 0.0, 14.0, "attack"], ["turn", "eye_r", X, 0.0, 14.0, "attack"], ["turn", "front", X, -6.0, 8.0, "attack"],
				["call", "_crab_patter"], ["rear", 0.35, "attack"],
				["fx", 0.3, "sparks", {"from": "ClawR03", "color": "#ffd060", "amount": 12}]],
			## The coin raised high over its head, swelling gold, and brought down like a hammer:
			## coins everywhere.
			"Jackpot": [["call", "_crab_coin"], ["turn", "big", Y, -10.0, 16.0, "big"], ["turn", "big", X, -80.0, 26.0, "big"], ["turn", "big", Z, 24.0, 0.0, "big"],
				["turn", "small", X, -40.0, 14.0, "big"], ["turn", "eye_l", X, -22.0, 16.0, "big"], ["turn", "eye_r", X, -22.0, 16.0, "big"],
				["turn", "front", X, -10.0, 10.0, "big"], ["call", "_crab_patter"], ["call", "_coins"], ["rear", 0.3, "big"],
				["fx", 0.3, "shock", {"ahead": 0.7, "size": 1.1}], ["fx", 0.3, "sparks", {"from": "ClawR05", "color": "#ffd060", "amount": 40, "speed": 4.5}],
				["fx", 0.3, "flash_light", {"from": "ClawR05", "color": "#ffd060"}]],
			## Double or nothing: both claws thrown up, the coin spun on show, the cauldron rocking.
			"Double": [["call", "_crab_coin"], ["turn", "big", X, 0.0, -55.0, "hold"], ["turn", "big", Z, 0.0, 30.0, "hold"],
				["turn", "small", X, 0.0, -62.0, "hold"], ["turn", "small", Z, 0.0, -34.0, "hold"],
				["turn", "eye_l", X, 0.0, -14.0, "hold"], ["turn", "eye_r", X, 0.0, -14.0, "hold"], ["turn", "pot", Z, 4.0, -4.0, "shake"],
				["hop", Vector3.ZERO, Vector3(0, 0.06, 0), "pulse"],
				["fx", 0.3, "flash_light", {"from": "ClawR05", "color": "#ffd060", "energy": 3.0}],
				["fx", 0.3, "sparks", {"from": "ClawR05", "color": "#ffd060", "amount": 20, "speed": 2.5}],
				["fx", 0.55, "sparks", {"from": "ClawL03", "color": "#ffd060", "amount": 12, "speed": 2.0}]],
			## Reaches out wide and rakes the table in: the party's pyrite hops into its pot.
			"Rake": [["turn", "big", X, -22.0, 10.0, "attack"], ["turn", "big", Y, -45.0, 40.0, "attack"], ["turn", "front", Y, -8.0, 8.0, "attack"],
				["call", "_crab_patter"], ["call", "_coins"], ["rear", 0.25, "attack"],
				["fx", 0.29, "swipe", {"about": "big", "axis": Y, "start": Vector3(-1, 0, 0.6), "radius": 0.8, "sweep": 90.0}],
				["fx", 0.6, "sparks", {"from": "Core01", "color": "#ffd060", "amount": 12, "speed": 1.5}]],
			## Folds: claws down, eyes drooping, the cauldron wobbling; it pays out to the table.
			"Fold": [["turn", "big", X, 0.0, 22.0, "hold"], ["turn", "small", X, 0.0, 22.0, "hold"], ["turn", "eye_l", X, 0.0, 35.0, "hold"],
				["turn", "eye_r", X, 0.0, 35.0, "hold"], ["turn", "front", X, 0.0, 6.0, "hold"], ["turn", "pot", Z, -10.0, 10.0, "shake"], ["call", "_coins"]],
		},
		"heavy": {
			## Jackpot held: the coin swelling gold high over its head, the crab crouched back on its
			## legs, scrabbling, and down it comes in a burst of gold.
			"Jackpot": {"at": "ClawR05", "pose": [["hop", Vector3.ZERO, Vector3(0, -0.05, -0.08), "h"]],
				"charge": [["charge_glow", {"from": "ClawR05", "color": "#ffd060", "seconds": 0.55}],
					["sparks", {"from": "ClawR05", "color": "#fff0b0", "amount": 14, "speed": 1.4}], ["charge_dust", {"seconds": 0.4}]],
				"impact": [["shock", {"ahead": 0.8, "size": 1.6}], ["shards", {"from": "ClawR05", "color": "#ffd060", "amount": 18, "speed": 5.0}],
					["flash_light", {"from": "ClawR05", "color": "#ffd060", "energy": 5.0}]]},
		},
	},
	## The Geode Golem: three grey blocks stacked on a cracked heart of amethyst. A golem grinds
	## its stones against each other and pounds the floor; its crack opens and closes like a slow
	## breath, the heart glowing in the cleft, and it bows its whole stack to slam.
	"GEODE_GOLEM": {
		"groups": {"stack": {"chain": [["Body01", "Body05-08"], ["Body02", "Body09-11"], ["Body03", "Body04", "Body12-13", "Heart"], ["Head", "Crest"]]},
			"half_r": {"parts": ["Body03", "Body13"], "at": Vector3(0.0, 1.3, 0)}, "half_l": {"parts": ["Body04", "Body12"], "at": Vector3(0.06, 1.3, 0)},
			"heart": {"parts": ["Heart"], "at": "Heart01"}, "head": {"parts": ["Head", "Crest"], "at": "Head01"}, "crest": {"parts": ["Crest01"], "at": "Crest01"}},
		"idle_gestures": [["pant", "half_r", Z, 3.0, 1.0], ["pant", "half_l", Z, -3.0, 1.0], ["breathe", "heart", 0.1, 1.0, 0.0],
			["hover", "crest", 0.05, 1.4, 5.0, 0.0], ["slither", "stack", Y, 2.5, 0.9, 0.9, "even"]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Grinds its blocks round on each other one way and back, grit sifting from the joints.
			"grind": {"length": 2.6, "hold": 0.8, "weight": 2.0, "do": [["curl", "stack", Y, -10.0, 10.0, GRIND, "even"], ["tremble", "stack", 0.008, "f"],
				["fx", 0.5, "shards", {"from": "Body02", "off": Vector3(0, 0.3, 0.3), "color": "#8a8278", "amount": 4, "speed": 0.8}],
				["fx", 1.2, "shards", {"from": "Body03", "off": Vector3(0, 0.3, 0.3), "color": "#8a8278", "amount": 4, "speed": 0.8}],
				["fx", 1.2, "puff", {"from": "Body02", "off": Vector3(0, 0.3, 0.3), "color": "#8a8278", "amount": 5, "size": 0.5, "rise": 0.1}]]},
			## Its crack opens wide on the heart, which flares, glints, and closes with a grind.
			"crack": {"length": 3.0, "hold": 1.0, "weight": 2.0, "do": [["turn", "half_r", Z, 0.0, 16.0, "f"], ["turn", "half_l", Z, 0.0, -16.0, "f"],
				["grow", "heart", 0.0, 0.25, "f"], ["tremble", "stack", 0.006, "f"],
				["fx", 0.5, "shards", {"from": "Body03", "color": "#8a8278", "amount": 4, "speed": 1.0}],
				["fx", 1.1, "glow", {"from": "Heart02", "color": "accent", "size": 0.5}],
				["fx", 1.15, "sparks", {"from": "Heart02", "color": "accent", "amount": 14, "speed": 1.8}],
				["fx", 1.15, "flash_light", {"from": "Heart02", "color": "accent", "energy": 2.0}]]},
			## Swivels its head block to look about the room, stone grinding on stone.
			"look": {"length": 3.6, "hold": 1.8, "weight": 1.5, "do": [["gaze", "head", 38.0, 8.0, "f", 2],
				["fx", 0.4, "puff", {"from": "Head01", "off": Vector3(0, -0.25, 0.25), "color": "#8a8278", "amount": 5, "size": 0.5, "rise": 0.1}],
				["fx", 0.4, "shards", {"from": "Head01", "off": Vector3(0, -0.25, 0.25), "color": "#8a8278", "amount": 3, "speed": 0.8}]]},
			## Rocks on its base like a boulder settling, dust kicked up round it.
			"rock": {"length": 2.5, "weight": 1.0, "do": [["lean", Z, -4.0, 4.0, Vector3.ZERO, ROCK],
				["fx", 0.6, "puff", {"from": "feet", "color": "#8a7a66", "amount": 6, "size": 0.7, "rise": 0.2}],
				["fx", 1.2, "puff", {"from": "feet", "color": "#8a7a66", "amount": 6, "size": 0.7, "rise": 0.2}]]},
		},
		"moves": {
			## Bows its whole stack back and slams it forward, the crack snapping shut.
			"Pound": [["turn", "half_r", Z, 3.0, -4.0, "attack"], ["turn", "half_l", Z, -3.0, 4.0, "attack"], ["curl", "stack", X, -18.0, 32.0, "attack", "tip"],
				["hop", Vector3(0, 0.06, -0.04), Vector3(0, -0.03, 0.06), "attack"],
				["fx", 0.3, "shock", {"ahead": 1.0, "size": 1.1}],
				["fx", 0.31, "shards", {"from": "feet", "off": Vector3(0, 0.3, 1.0), "color": "#8a8278", "amount": 8, "speed": 3.0}]],
			## Rears back with its crack opening on the glowing heart, and crashes down.
			"Crush": [["turn", "half_r", Z, 9.0, -4.0, "big"], ["turn", "half_l", Z, -9.0, 4.0, "big"], ["grow", "heart", 0.3, 0.0, "big"],
				["curl", "stack", X, -26.0, 42.0, "big", "tip"], ["hop", Vector3(0, 0.12, -0.08), Vector3(0, -0.04, 0.1), "big"],
				["fx", 0.3, "shock", {"ahead": 1.0, "size": 1.4}], ["fx", 0.32, "dust", {"amount": 50}],
				["fx", 0.31, "shards", {"from": "feet", "off": Vector3(0, 0.3, 1.0), "color": "#8a8278", "amount": 12, "speed": 4.0}]],
			## Closes up: the crack grinds shut over its heart, the crest settles, the blocks lock.
			"Fortify": [["turn", "half_r", Z, 0.0, -6.0, "hold"], ["turn", "half_l", Z, 0.0, 6.0, "hold"], ["grow", "heart", 0.0, -0.15, "hold"],
				["move", "crest", Vector3.ZERO, Vector3(0, -0.12, 0), "hold"], ["curl", "stack", Y, 0.0, 8.0, "hold", "even"],
				["hop", Vector3.ZERO, Vector3(0, -0.05, 0), "hold"], ["tremble", "stack", 0.01, "pulse"],
				["fx", 0.28, "puff", {"from": "feet", "color": "#8a8278", "amount": 10, "size": 1.0, "rise": 0.3}]],
			## Its crack bursts open three times, each a volley of amethyst flung from the heart.
			"Shardstorm": [["turn", "half_r", Z, -4.0, 12.0, "thrice"], ["turn", "half_l", Z, 4.0, -12.0, "thrice"], ["grow", "heart", -0.1, 0.35, "thrice"],
				["lean", X, 4.0, -6.0, Vector3.ZERO, "thrice"],
				["fx", 0.23, "bolt", {"from": "Heart02", "color": "accent", "size": 1.1, "flight": 0.1}],
				["fx", 0.45, "bolt", {"from": "Heart02", "color": "accent", "size": 1.1, "flight": 0.1, "arc": 0.6}],
				["fx", 0.67, "bolt", {"from": "Heart02", "color": "accent", "size": 1.1, "flight": 0.1, "arc": 0.9}],
				["fx", 0.3, "shards", {"from": "Heart02", "color": "accent", "amount": 12, "speed": 4.0}],
				["fx", 0.52, "shards", {"from": "Heart02", "color": "accent", "amount": 10, "speed": 4.0}],
				["fx", 0.74, "shards", {"from": "Heart02", "color": "accent", "amount": 10, "speed": 4.0}]],
		},
		"heavy": {
			## Crush held: its crack yawning on the blazing heart, the crest lifting off its head and
			## shivering, then the whole stack comes down and the floor breaks.
			"Crush": {"at": "Heart02", "pose": [["move", "crest", Vector3.ZERO, Vector3(0, 0.16, 0), "h"], ["tremble", "crest", 0.02, "h"]],
				"charge": [["charge_glow", {"from": "Heart02", "color": "accent", "seconds": 0.55}], ["charge_dust", {"seconds": 0.45}],
					["sparks", {"from": "Heart02", "color": "accent", "amount": 16, "speed": 1.6}]],
				"impact": [["shock", {"ahead": 1.1, "size": 1.9}], ["shards", {"from": "feet", "off": Vector3(0, 0.4, 1.1), "color": "#8a8278", "amount": 18, "speed": 5.0}],
					["shards", {"from": "Heart02", "color": "accent", "amount": 10, "speed": 4.0}], ["dust", {"amount": 70}]]},
			## Shardstorm held: the heart drinking light into the clenched crack, the crest lifting.
			"Shardstorm": {"at": "Heart02", "pose": [["move", "crest", Vector3.ZERO, Vector3(0, 0.2, 0), "h"], ["tremble", "crest", 0.025, "h"]],
				"charge": [["charge_glow", {"from": "Heart02", "color": "accent", "seconds": 0.55}], ["spiral", {"from": "Heart02", "color": "accent", "amount": 30}],
					["charge_dust", {"seconds": 0.4}]],
				"impact": [["shards", {"from": "Heart02", "color": "accent", "amount": 18, "speed": 5.0}], ["ring", {"color": "accent", "radius": 2.4}]]},
		},
	},
	## The Hoard Mimic: a treasure chest with teeth. A big mouth chomps and bares its teeth; a
	## mimic's eyes dart about from inside its lid and its tongue lolls on the floor; a hoard
	## rattles when it hops.
	"HOARD_MIMIC": {
		"mouth": "Mouth01",
		"idle": "_idle_mimic",
		"groups": {"lid": {"parts": ["Lid", "Eye"], "at": "Lid01"}, "eye_r": {"parts": ["Eye01-02"], "at": "Eye01"}, "eye_l": {"parts": ["Eye03-04"], "at": "Eye03"},
			"tongue": {"chain": [["Tongue01"], ["Tongue02"], ["Tongue03"], ["Tongue04"], ["Tongue05"], ["Tongue06"], ["Tongue07"], ["Tongue08"], ["Tongue09"],
				["Tongue10"], ["Tongue11"], ["Tongue12"], ["Tongue13"], ["Tongue14"], ["Tongue15"], ["Tongue16"], ["Tongue17"], ["Tongue18"]]},
			"tongue_all": {"parts": ["Tongue"], "at": Vector3(0, 0.62, -0.08)},
			"hoard": {"parts": ["Crystal01-05", "Sphere02-05", "Cylinder01-03"], "at": Vector3(0, 0.6, 0)},
			"all": {"parts": ["Core", "Box", "Sphere", "Cone", "Cylinder01-03", "Crystal01-05", "Leg", "Lid", "Eye", "Tongue", "Mouth"], "at": Vector3.ZERO}},
		"idle_gestures": [["pant", "lid", X, 4.0, 1.25]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Chomps at nothing, twice, teeth clashing, the hoard jumping in it.
			"chomp": {"length": 1.8, "weight": 2.0, "do": [["turn", "lid", X, 95.0, -15.0, MIMIC_CHOMP],
				["move", "hoard", Vector3(0, -0.15, 0), Vector3.ZERO, MIMIC_CHOMP],
				["fx", 0.42, "sparks", {"from": "Mouth01", "color": "#ffd060", "amount": 8, "speed": 1.6}],
				["fx", 0.82, "sparks", {"from": "Mouth01", "color": "#ffd060", "amount": 8, "speed": 1.6}]]},
			## Bares its teeth: the lid lowered to a snarl and held, shivering, its eyes narrowed.
			"bare": {"length": 2.6, "hold": 1.2, "weight": 1.5, "do": [["grow", "eye_r", 0.0, Vector3(0.1, -0.5, 0.1), "f"],
				["grow", "eye_l", 0.0, Vector3(0.1, -0.5, 0.1), "f"], ["turn", "lid", X, 0.0, 42.0, "f"], ["tremble", "lid", 0.008, "f"]]},
			## Hops on its iron feet, the hoard inside rattling, gold glinting and spilling.
			"rattle": {"length": 2.0, "weight": 1.5, "do": [["hop", Vector3.ZERO, Vector3(0, 0.07, 0), MIMIC_HOPS], ["tremble", "hoard", 0.02, "f"],
				["turn", "lid", X, 0.0, -10.0, MIMIC_HOPS],
				["fx", 0.45, "shards", {"from": "Mouth01", "color": "#ffd060", "amount": 5, "speed": 1.8}],
				["fx", 0.45, "sparks", {"from": "Mouth01", "color": "#fff0b0", "amount": 8, "speed": 1.2}],
				["fx", 0.78, "shards", {"from": "Mouth01", "color": "#ffd060", "amount": 4, "speed": 1.6}]]},
			## Licks its lips: the tongue's tip lifts off the floor and sweeps across and back, its
			## eyes half shut, pleased with itself.
			"lick": {"length": 2.6, "hold": 0.8, "weight": 1.5, "idle": 0.0, "do": [["call", "_mimic_lick"]]},
		},
		"moves": {
			## The lid flung back and slammed shut on the party, the hoard jumping.
			"Snap": [["turn", "lid", X, -18.0, 100.0, "attack"], ["move", "hoard", Vector3.ZERO, Vector3(0, -0.15, 0), "attack"], ["rear", 0.4, "attack"],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ffd060", "amount": 16}]],
			## Two great bites, eyes bulging as it gapes.
			"Chomp": [["grow", "eye_r", 0.4, 0.0, "twice"], ["grow", "eye_l", 0.4, 0.0, "twice"], ["turn", "lid", X, -28.0, 100.0, "twice"],
				["move", "hoard", Vector3.ZERO, Vector3(0, -0.15, 0), "twice"], ["rear", 0.45, "twice"],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ffd060", "amount": 12}], ["fx", 0.54, "sparks", {"from": "Mouth01", "color": "#ffd060", "amount": 12}],
				["fx", 0.31, "shards", {"from": "Mouth01", "color": "#ffd060", "amount": 6, "speed": 2.5}]],
			"Gulp": "_mimic_gulp",
			## Slams shut and stays shut, the tongue whipped in first, the chest hunkered down.
			"Shut": [["grow", "tongue_all", 0.0, -0.7, "hold"], ["turn", "lid", X, 0.0, 100.0, "hold"], ["move", "hoard", Vector3.ZERO, Vector3(0, -0.15, 0), "hold"],
				["hop", Vector3.ZERO, Vector3(0, -0.04, 0), "hold"],
				["fx", 0.26, "sparks", {"from": "Mouth01", "color": "#ffd060", "amount": 10, "speed": 1.5}],
				["fx", 0.27, "puff", {"from": "feet", "color": "#8a7a66", "amount": 8, "size": 0.8, "rise": 0.25}]],
		},
		"heavy": {
			## Chomp held: gaping wide, crouched back on its feet, the lid shivering, gold glowing in
			## its throat; then the double bite.
			"Chomp": {"at": "Mouth01", "pose": [["hop", Vector3.ZERO, Vector3(0, -0.05, -0.08), "h"], ["tremble", "lid", 0.012, "h"]],
				"charge": [["charge_glow", {"from": "Mouth01", "color": "#ffd060", "seconds": 0.5}], ["charge_dust", {"seconds": 0.4}],
					["sparks", {"from": "Mouth01", "color": "#ffe08a", "amount": 14, "speed": 1.4}]],
				"impact": [["shock", {"ahead": 0.7, "size": 1.3}], ["shards", {"from": "Mouth01", "color": "#ffd060", "amount": 14, "speed": 4.5}],
					["flash_light", {"from": "Mouth01", "color": "#ffd060", "energy": 4.0}]]},
		},
	},
	## The Crystal Hydra: a geode grown three crystal heads on long necks. A hydra's heads weave
	## like snakes, each in its own time, hiss and snap at the air and at each other, and take
	## turns to strike; together they rear and roar.
	"CRYSTAL_HYDRA": {
		"mouth": "Mouth02",
		"idle": "_idle_hydra",
		"groups": {"body": {"parts": ["Body01", "Crystal", "Core01"], "at": Vector3(0, 0.3, -0.05)}},
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## All three heads weave in big slow figures, like snakes to a charmer's pipe.
			"weave": {"length": 3.6, "hold": 1.6, "weight": 2.0, "idle": 0.0, "do": [["call", "_hydra_charm"]]},
			## They squabble: each head snaps at the air in turn, at the one beside it.
			"squabble": {"length": 2.4, "hold": 1.2, "weight": 2.0, "idle": 0.0, "do": [["call", "_hydra_squabble"]]},
			## The tall head rears up and roars; the others hiss and pull away.
			"roar": {"length": 2.6, "hold": 1.0, "weight": 1.0, "idle": 0.0, "do": [["call", "_hydra_bellow"],
				["fx", 0.9, "ripple", {"from": "Mouth02", "color": "#c890ff", "radius": 0.8}],
				["fx", 1.0, "puff", {"from": "Mouth02", "color": "#c890ff", "amount": 8, "size": 0.45, "rise": 0.5, "glow": true}]]},
		},
		"moves": {"Bite": "_hydra_bite", "Sprout": "_hydra_roar"},
	},
	## The Assayer: a floating obsidian brilliant with a gold eye, over a balance. A judge of
	## weights: its balance tips and rocks to level, its pans hanging plumb, it weighs the gold,
	## taps its point, and its eye narrows and reads you; it drops the weights.
	"THE_ASSAYER": {
		"mouth": "Eye01",
		"idle": "_idle_assayer",
		"groups": {"all": {"parts": ["Body", "Eye", "Halo", "Scales", "PanL", "PanR", "Cylinder01", "Orbit"], "at": Vector3(0, 2.05, 0)},
			"gem": {"parts": ["Body", "Eye"], "at": Vector3(0, 2.05, 0)}, "lifted": {"parts": ["Body", "Eye", "Halo", "Orbit"], "at": Vector3(0, 2.05, 0)},
			"eye": {"parts": ["Eye"], "at": "Eye01"}, "halo": {"parts": ["Halo"], "at": "Halo01"}, "orbit": {"parts": ["Orbit"], "at": Vector3(0, 2.0, 0)},
			"scales": {"parts": ["Scales", "PanL", "PanR"], "at": "Scales01"}},
		"idle_gestures": [["blink", "eye", Vector3(1, 0.12, 1), 4.8, 0.0], ["look", "eye", 24.0, 10.0, 3.1, 1.0]],
		"fidget_every": [3.5, 7.0],
		"fidgets": {
			## Weighs its gold: the pan dips, bobbles and settles, its eye on it, a glint of coin.
			"weigh": {"length": 3.2, "weight": 2.0, "do": [["call", "_assayer_scales"], ["turn", "eye", X, 0.0, 12.0, WEIGH], ["turn", "eye", Y, 0.0, 18.0, WEIGH],
				["fx", 0.8, "sparks", {"from": "PanL06", "color": "#ffd060", "amount": 8, "speed": 1.2}],
				["fx", 1.3, "sparks", {"from": "PanL06", "color": "#fff0b0", "amount": 6, "speed": 1.0}]]},
			## Its balance tips hard to the die's side and rocks itself level, its eye following.
			"tip": {"length": 2.4, "weight": 1.5, "do": [["call", "_assayer_scales"], ["turn", "eye", Y, 12.0, -12.0, TIP],
				["fx", 0.35, "sparks", {"from": "PanR05", "color": "#e8e8ff", "amount": 8, "speed": 1.4}]]},
			## Narrows its eye and reads the party from one side to the other, leaning in.
			"squint": {"length": 3.0, "hold": 1.4, "weight": 1.5, "do": [["call", "_assayer_scales"], ["grow", "eye", 0.0, Vector3(0.12, -0.55, 0.12), "f"],
				["gaze", "eye", 30.0, 8.0, "f", 3], ["turn", "gem", X, 0.0, 7.0, "f"],
				["fx", 1.0, "flash_light", {"from": "Eye01", "color": "#ffd060", "energy": 1.6}]]},
			## Taps its point on its chain, tap, tap, tap, impatient; the beam jolts at each.
			"tap": {"length": 2.0, "weight": 1.5, "do": [["call", "_assayer_scales"], ["move", "lifted", Vector3.ZERO, Vector3(0, 0.07, 0), TAPS],
				["fx", 0.47, "sparks", {"from": "Cylinder01", "off": Vector3(0, 0.35, 0), "color": "#ffd060", "amount": 5, "speed": 1.0}],
				["fx", 0.82, "sparks", {"from": "Cylinder01", "off": Vector3(0, 0.35, 0), "color": "#ffd060", "amount": 5, "speed": 1.0}],
				["fx", 1.17, "sparks", {"from": "Cylinder01", "off": Vector3(0, 0.35, 0), "color": "#ffd060", "amount": 5, "speed": 1.0}]]},
			## Turns to show its facets, the halo tilting, a glint running over the stone.
			"preen": {"length": 3.4, "hold": 1.2, "weight": 1.0, "do": [["call", "_assayer_scales"], ["turn", "gem", Y, 0.0, 38.0, "f"], ["turn", "halo", X, 0.0, 10.0, "f"],
				["fx", 1.4, "sparks", {"from": "Body02", "color": "#ffffff", "amount": 10, "speed": 0.8}]]},
		},
		"moves": {
			## The gold pan swung up and slammed down on the floor like a hammer.
			"Weigh": [["call", "_assayer_scales"], ["each", "Eye01", 0.0, 0.3, "pulse"], ["lean", BEAM, 2.0, -4.0, Vector3(0, 2.05, 0), "attack"],
				["fx", 0.3, "shock", {"from": "PanL04", "size": 0.9}], ["fx", 0.3, "sparks", {"from": "PanL04", "color": "#ffd060", "amount": 20}],
				["fx", 0.31, "shards", {"from": "PanL04", "color": "#ffd060", "amount": 6, "speed": 2.5}]],
			## The gold pan hauled high, and every weight on it dropped at once.
			"Drop the Weights": [["call", "_assayer_scales"], ["whirl", "halo", Y, 1.0, "big"], ["each", "Eye01", 0.0, 0.4, "big"],
				["lean", BEAM, 3.0, -5.0, Vector3(0, 2.05, 0), "big"],
				["fx", 0.3, "shock", {"from": "PanL04", "size": 1.3}], ["fx", 0.32, "dust", {"amount": 60}],
				["fx", 0.3, "sparks", {"from": "PanL04", "color": "#ffd060", "amount": 24, "speed": 4.0}]],
			## Its balance shaken level and locked, the iron shards round it standing out like thorns.
			"Balance": [["call", "_assayer_scales"], ["grow", "orbit", 0.0, Vector3(0.45, 0.0, 0.45), "hold"], ["whirl", "halo", Y, 1.0, "hold"],
				["fx", 0.3, "sparks", {"from": "centre", "color": "#c8c8d8", "amount": 16, "speed": 2.5}],
				["fx", 0.32, "flash_light", {"from": "Eye01", "color": "#ffd060", "energy": 2.0}]],
			## The richest player's pyrite pours into its pan, which sinks; the stone swells on it.
			"Eat the Rich": [["call", "_assayer_scales"], ["call", "_coins"], ["grow", "gem", 0.0, 0.08, "pulse"], ["whirl", "halo", Y, 1.0, "hold"],
				["fx", 0.35, "rise", {"from": "centre", "color": "#ffd060"}], ["fx", 0.36, "sparks", {"from": "PanL04", "color": "#ffd060", "amount": 12, "speed": 1.5}]],
			## Its eye flares; a tithe of pyrite drops into the gold pan.
			"Tax": [["call", "_assayer_scales"], ["call", "_coins"], ["each", "Eye01", 0.0, 0.35, "pulse"], ["whirl", "halo", Y, 1.0, "hold"],
				["fx", 0.3, "glow", {"from": "Eye01", "color": "#ffd060", "size": 0.5}]],
			"Heavy Tax": [["call", "_assayer_scales"], ["call", "_coins"], ["each", "Eye01", 0.0, 0.45, "pulse"], ["whirl", "halo", Y, 2.0, "hold"],
				["fx", 0.3, "glow", {"from": "Eye01", "color": "#ffd060", "size": 0.6}],
				["fx", 0.32, "sparks", {"from": "Halo01", "color": "#ffd060", "amount": 18, "speed": 2.0}]],
			## A die taken as collateral: its pan sinks under the weight, the die there glinting.
			"Seize": [["call", "_assayer_scales"], ["each", "Eye01", 0.0, 0.3, "pulse"],
				["fx", 0.32, "sparks", {"from": "PanR05", "color": "#e8e8ff", "amount": 12, "speed": 1.6}],
				["fx", 0.32, "flash_light", {"from": "PanR05", "color": "#ffd060", "energy": 2.0}]],
			## Its eye narrows and reads the party across, the stone leaning in to the ledger.
			"Audit": [["call", "_assayer_scales"], ["grow", "eye", 0.0, Vector3(0.15, -0.5, 0.15), "hold"], ["turn", "eye", Y, 25.0, -25.0, AUDIT_SCAN],
				["turn", "gem", X, 0.0, 6.0, "hold"], ["fx", 0.22, "ripple", {"from": "Eye01", "color": "#ffd060", "radius": 0.9}],
				["fx", 0.3, "flash_light", {"from": "Eye01", "color": "#ffd060", "energy": 2.0}]],
			## The halo of coins rises, widens and spins: the rate goes up.
			"Raise the Rate": [["call", "_assayer_scales"], ["grow", "halo", 0.0, Vector3(0.35, 0.0, 0.35), "hold"], ["whirl", "halo", Y, 2.0, "hold"],
				["move", "halo", Vector3.ZERO, Vector3(0, 0.25, 0), "hold"], ["each", "Eye01", 0.0, 0.3, "pulse"],
				["fx", 0.3, "sparks", {"from": "Halo01", "color": "#ffd060", "amount": 30}], ["fx", 0.3, "glow", {"from": "Halo01", "color": "#ffd060", "size": 0.6}]],
		},
		"heavy": {
			## Drop the Weights held: the whole of it lifts into the air, the gold pan hauled high,
			## the halo spinning, motes pulled into the weights; released, it all comes down.
			"Drop the Weights": {"at": "PanL04", "pose": [["move", "all", Vector3.ZERO, Vector3(0, 0.3, 0), "h"], ["tremble", "all", 0.01, "h"]],
				"charge": [["charge_glow", {"from": "PanL04", "color": "#ffd060", "seconds": 0.55}], ["spiral", {"from": "PanL04", "color": "#ffd060", "amount": 26}],
					["flash_light", {"from": "Eye01", "color": "#ffd060", "energy": 3.0}], ["charge_dust", {"seconds": 0.45}]],
				"impact": [["shock", {"from": "PanL04", "size": 2.0}], ["shards", {"from": "PanL04", "color": "#ffd060", "amount": 16, "speed": 5.0}],
					["ring", {"color": "#ffd060", "radius": 3.0}], ["dust", {"amount": 80}]]},
		},
	},
	## The Collector: a snail whose shell is a cabinet of lit cases, with a cane. A snail's eyes
	## on stalks peer and pull in, its foot ripples; a collector polishes, examines its finds
	## through its stalks, rummages its drawer, taps its cane impatiently, and raps and smashes.
	"THE_COLLECTOR": {
		"mouth": "Case05",
		"idle": "_idle_collector",
		"groups": {"cane": {"parts": ["Cane"], "at": "Cane01"}, "head": {"parts": ["Head", "Eye"], "at": "Head01"},
			"eye_r": {"parts": ["Eye01-03"], "at": "Eye01"}, "eye_l": {"parts": ["Eye04-06"], "at": "Eye04"},
			"shell": {"parts": ["Shell", "Column", "Tip", "Case", "Drawer"], "at": "Shell01"}, "cases": {"parts": ["Case"]},
			"case_a": {"parts": ["Case01-03"], "at": "Case01"}, "case_b": {"parts": ["Case04-06"], "at": "Case04"}, "case_c": {"parts": ["Case07-09"], "at": "Case07"},
			"drawer": {"parts": ["Drawer"]}},
		"idle_gestures": [["look", "eye_r", 18.0, 12.0, 2.7, 0.9], ["look", "eye_l", 18.0, 12.0, 3.3, 0.9], ["flex", "cane", X, -7.0, 4.2, 0.0],
			["sway", "shell", Z, 1.2, 0.5, 0.0]],
		"fidget_every": [3.5, 7.0],
		"fidgets": {
			## Stretches its stalks out to peer at the party, close, a glint in each eye.
			"examine": {"length": 3.6, "hold": 1.6, "weight": 2.5, "do": [["grow", "eye_r", 0.0, 0.16, "f"], ["grow", "eye_l", 0.0, 0.16, "f"],
				["turn", "eye_r", X, 0.0, 24.0, "f"], ["turn", "eye_l", X, 0.0, 24.0, "f"], ["turn", "eye_r", Z, 0.0, -8.0, "f"], ["turn", "eye_l", Z, 0.0, 8.0, "f"],
				["turn", "head", X, 0.0, -8.0, "f"], ["move", "head", Vector3.ZERO, Vector3(0, 0.03, 0.08), "f"],
				["fx", 1.3, "flash_light", {"from": "Eye03", "color": "#fff4d0", "energy": 1.5}],
				["fx", 1.4, "sparks", {"from": "Eye06", "color": "#ffffff", "amount": 5, "speed": 0.6}]]},
			## Draws its cane in and polishes the knob, rubbing, till it shines.
			"polish": {"length": 3.2, "hold": 1.6, "weight": 2.0, "do": [["move", "cane", Vector3.ZERO, Vector3(0.12, -0.03, 0), "f"],
				["turn", "head", Y, 0.0, -22.0, "f"], ["turn", "head", X, 0.0, 8.0, "f"], ["turn", "head", Y, 0.0, 5.0, "chew"],
				["fx", 1.0, "sparks", {"from": "Cane03", "color": "#ffffff", "amount": 6, "speed": 1.0}],
				["fx", 1.4, "sparks", {"from": "Cane03", "color": "#ffffff", "amount": 6, "speed": 1.0}],
				["fx", 1.8, "sparks", {"from": "Cane03", "color": "#ffffff", "amount": 6, "speed": 1.0}],
				["fx", 2.0, "flash_light", {"from": "Cane03", "color": "#ffffff", "energy": 2.0}]]},
			## Taps its cane twice on the floor, impatient, nodding with it.
			"tap": {"length": 2.4, "weight": 1.5, "do": [["turn", "cane", X, 10.0, -18.0, CANE_TAPS], ["turn", "head", X, -3.0, 4.0, CANE_TAPS],
				["fx", 0.62, "puff", {"from": "Cane04", "color": "#8a7a66", "amount": 4, "size": 0.4, "rise": 0.2}],
				["fx", 0.62, "sparks", {"from": "Cane04", "color": "#ffd060", "amount": 5, "speed": 1.2}],
				["fx", 1.22, "puff", {"from": "Cane04", "color": "#8a7a66", "amount": 4, "size": 0.4, "rise": 0.2}],
				["fx", 1.22, "sparks", {"from": "Cane04", "color": "#ffd060", "amount": 5, "speed": 1.2}]]},
			## Rummages its collection: the drawer slides out, the cases light one after another, its
			## stalks turned back to look, and the drawer shuts.
			"rummage": {"length": 3.4, "hold": 1.4, "weight": 1.5, "do": [["move", "drawer", Vector3.ZERO, Vector3(0.1, 0.0, -0.22), "f"],
				["each", "case_a", 0.0, 0.22, CASE_A], ["each", "case_b", 0.0, 0.22, CASE_B], ["each", "case_c", 0.0, 0.22, CASE_C],
				["turn", "shell", Z, 0.0, -3.0, "f"], ["turn", "eye_r", X, 0.0, -16.0, "f"], ["turn", "eye_l", X, 0.0, -16.0, "f"],
				["fx", 0.85, "glow", {"from": "Case02", "color": "accent", "size": 0.45}], ["fx", 1.15, "glow", {"from": "Case05", "color": "accent", "size": 0.45}],
				["fx", 1.45, "glow", {"from": "Case08", "color": "accent", "size": 0.45}],
				["fx", 3.1, "puff", {"from": "Drawer01", "color": "#8a7a66", "amount": 4, "size": 0.4, "rise": 0.1}]]},
			## Pulls its head and stalks in, as snails do, and peeks out again.
			"retract": {"length": 2.8, "hold": 0.8, "weight": 1.0, "do": [["grow", "eye_r", 0.0, -0.45, "f"], ["grow", "eye_l", 0.0, -0.45, "f"],
				["move", "head", Vector3.ZERO, Vector3(0, -0.05, -0.16), "f"], ["hop", Vector3.ZERO, Vector3(0, -0.03, 0), "f"]]},
		},
		"moves": {
			## A sharp rap of the cane on the floor.
			"Rap": [["turn", "cane", X, -34.0, 12.0, "attack"], ["move", "cane", Vector3(0, 0.1, 0), Vector3.ZERO, "attack"], ["turn", "head", X, -6.0, 6.0, "attack"],
				["rear", 0.2, "attack"],
				["fx", 0.3, "shock", {"from": "Cane04", "size": 0.6}], ["fx", 0.3, "sparks", {"from": "Cane04", "color": "#ffd060", "amount": 16}]],
			## The cane hauled high and brought down like a hammer on a case: glass everywhere.
			"Smash": [["turn", "cane", X, -125.0, 12.0, "big"], ["move", "cane", Vector3(0.05, 0.32, -0.1), Vector3(0, -0.03, 0.05), "big"],
				["turn", "head", X, -14.0, 10.0, "big"], ["lean", X, -5.0, 4.0, Vector3(0, 0, -0.4), "big"], ["rear", 0.3, "big"],
				["fx", 0.3, "shock", {"from": "Cane04", "size": 1.2}], ["fx", 0.3, "shards", {"from": "Cane04", "color": "#e8f0ff", "amount": 10}],
				["fx", 0.3, "sparks", {"from": "Cane04", "color": "#ffd060", "amount": 18}]],
			## The cane held out level and swept across the party three times.
			"Sweep": [["turn", "cane", X, 0.0, -60.0, SWEEP_LIFT], ["turn", "cane", Y, 40.0, -45.0, "thrice"], ["turn", "head", Y, 8.0, -10.0, "thrice"],
				["lean", Y, 3.0, -4.0, Vector3.ZERO, "thrice"],
				["fx", 0.29, "swipe", {"about": "cane", "axis": Vector3(0, -1, 0), "start": Vector3(0.7, -0.1, 0.7), "radius": 0.9, "sweep": 90.0}],
				["fx", 0.51, "swipe", {"about": "cane", "axis": Vector3(0, -1, 0), "start": Vector3(0.7, -0.1, 0.7), "radius": 0.9, "sweep": 90.0}],
				["fx", 0.73, "swipe", {"about": "cane", "axis": Vector3(0, -1, 0), "start": Vector3(0.7, -0.1, 0.7), "radius": 0.9, "sweep": 90.0}]],
			## Its drawer slides out to receive, its stalks reaching for what it wants.
			"Acquire": [["move", "drawer", Vector3.ZERO, Vector3(0.12, 0, -0.25), "hold"], ["each", "cases", 0.0, 0.15, "pulse"],
				["grow", "eye_r", 0.0, 0.12, "hold"], ["grow", "eye_l", 0.0, 0.12, "hold"], ["turn", "eye_r", X, 0.0, 22.0, "hold"], ["turn", "eye_l", X, 0.0, 22.0, "hold"],
				["move", "head", Vector3.ZERO, Vector3(0, 0.02, 0.1), "hold"],
				["fx", 0.1, "spiral", {"from": "Drawer01", "color": "#ffd060"}], ["fx", 0.45, "glow", {"from": "Case05", "color": "accent", "size": 0.5}]],
			## Shows off its collection: the cases flare one after another, the curator bowing.
			"Exhibit": [["each", "case_a", 0.0, 0.25, SHOW_A], ["each", "case_b", 0.0, 0.25, SHOW_B], ["each", "case_c", 0.0, 0.25, SHOW_C],
				["turn", "head", X, 0.0, 12.0, "hold"], ["turn", "cane", X, 0.0, -24.0, "hold"], ["lean", X, 0.0, -4.0, Vector3(0, 0, -0.4), "hold"],
				["fx", 0.22, "glow", {"from": "Case02", "color": "accent", "size": 0.5}], ["fx", 0.32, "glow", {"from": "Case05", "color": "accent", "size": 0.5}],
				["fx", 0.42, "glow", {"from": "Case08", "color": "accent", "size": 0.5}],
				["fx", 0.42, "sparks", {"from": "Case05", "color": "#ffffff", "amount": 12, "speed": 1.5}]],
			## Pulls into its cabinet: head and stalks drawn in, the cane held across.
			"Case": [["grow", "eye_r", 0.0, -0.45, "hold"], ["grow", "eye_l", 0.0, -0.45, "hold"], ["move", "head", Vector3.ZERO, Vector3(0, -0.05, -0.18), "hold"],
				["turn", "cane", X, 0.0, -18.0, "hold"], ["turn", "cane", Y, 0.0, 18.0, "hold"], ["hop", Vector3.ZERO, Vector3(0, -0.05, 0), "hold"],
				["fx", 0.28, "puff", {"from": "feet", "color": "#8a7a66", "amount": 8, "size": 0.9, "rise": 0.25}]],
			## Polishes its cane's knob gem, rubbing, and holds it up shining.
			"Polish": [["turn", "head", Y, 0.0, -20.0, "hold"], ["turn", "head", X, 0.0, 8.0, "hold"], ["turn", "head", Y, 0.0, 5.0, "chew"],
				["move", "cane", Vector3.ZERO, Vector3(0.1, 0.06, 0), "hold"],
				["fx", 0.2, "sparks", {"from": "Cane03", "color": "#ffffff", "amount": 8, "speed": 1.2}],
				["fx", 0.4, "sparks", {"from": "Cane03", "color": "#ffffff", "amount": 8, "speed": 1.2}],
				["fx", 0.5, "flash_light", {"from": "Cane03", "color": "#ffffff", "energy": 3.0}]],
		},
		"heavy": {
			## Smash held: the cane high over its head, the knob gem blazing, the cases lit, light
			## pulled into the gem; then down on the floor.
			"Smash": {"at": "Cane03", "pose": [["each", "cases", 0.0, 0.2, "h"]],
				"charge": [["charge_glow", {"from": "Cane03", "color": "accent", "seconds": 0.55}], ["flash_light", {"from": "Cane03", "color": "#fff0d0", "energy": 2.5}],
					["spiral", {"from": "Cane03", "color": "accent", "amount": 24}], ["charge_dust", {"seconds": 0.45}]],
				"impact": [["shock", {"from": "Cane04", "size": 1.7}], ["shards", {"from": "Cane04", "color": "#e8f0ff", "amount": 16, "speed": 5.0}],
					["shards", {"from": "Cane04", "color": "#ffd060", "amount": 8, "speed": 4.0}], ["dust", {"amount": 70}]]},
			## Sweep held: the cane drawn back across its body, the snail coiled back on its foot.
			"Sweep": {"at": "Cane04", "pose": [["lean", X, 0.0, -4.0, Vector3(0, 0, -0.4), "h"]],
				"charge": [["charge_glow", {"from": "Cane04", "color": "accent", "seconds": 0.5}], ["sparks", {"from": "Cane04", "color": "#ffd060", "amount": 12, "speed": 1.4}],
					["charge_dust", {"seconds": 0.4}]],
				"impact": [["swipe", {"about": "cane", "axis": Vector3(0, -1, 0), "start": Vector3(0.7, -0.1, 0.7), "radius": 1.3, "sweep": 110.0}],
					["shock", {"ahead": 1.0, "size": 1.3}], ["sparks", {"from": "Cane04", "color": "#ffd060", "amount": 24, "speed": 4.0}]]},
		},
	},
	## The Hollow Crown: a crowned geode colossus with a magpie on its shoulder. A colossus heaves
	## as it breathes, strides and stamps, swings its fists down from overhead and topples on you;
	## a king's crown wobbles and is set straight; its bird bobs, flutters and calls.
	"THE_HOLLOW_CROWN": {
		"groups": {"arm_r": {"parts": ["ArmR"], "at": "ArmR01"}, "arm_l": {"parts": ["ArmL"], "at": "ArmL01"},
			"leg_r": {"parts": ["Leg01-03"], "at": "Leg01"}, "leg_l": {"parts": ["Leg04-06"], "at": "Leg04"},
			"neck": {"parts": ["Neck", "Head", "Jaw", "Crown"], "at": "Neck01"}, "head": {"parts": ["Head", "Jaw", "Crown"], "at": "Head01"},
			"jaw": {"parts": ["Jaw"], "at": "Jaw01"}, "crown": {"parts": ["Crown"], "at": "Crown01"}, "heart": {"parts": ["Heart"]},
			"bird": {"parts": ["Bird", "BirdWingL", "BirdWingR"], "at": "Bird01"}, "bird_l": {"parts": ["BirdWingL"], "at": "BirdWingL01"},
			"bird_r": {"parts": ["BirdWingR"], "at": "BirdWingR01"},
			"upper": {"parts": ["ArmR", "ArmL", "Neck", "Head", "Jaw", "Crown", "Bird", "BirdWingL", "BirdWingR", "Rock10-11", "Crystal14-21"]}},
		"idle_gestures": [["sway", "bird_l", Z, 10.0, 6.0, 0.0], ["sway", "bird_r", Z, -10.0, 6.0, 0.0], ["sway", "bird", Vector3(0.99, 0, 0.15), 10.0, 1.3, 0.0],
			["sway", "crown", Z, 1.6, 1.1, 0.0], ["sway", "crown", X, 1.0, 0.8, 1.0], ["pant", "jaw", X, 3.0, 0.9],
			["sway", "arm_r", X, 2.0, 0.9, 0.0], ["sway", "arm_l", X, 2.0, 0.9, 1.4], ["bob", "upper", Vector3(0, 0.022, 0), 0.9, 0.0]],
		"fidget_every": [3.5, 7.0],
		"fidgets": {
			## A heavy stride on the spot: its weight shifts, one foot lifts and stamps, dust falls.
			"stomp": {"length": 2.8, "weight": 2.0, "do": [["turn", "leg_r", X, 4.0, -24.0, STOMP], ["turn", "arm_r", X, -4.0, 8.0, STOMP],
				["turn", "arm_l", X, 0.0, -8.0, STOMP], ["lean", Z, 2.0, -4.0, Vector3(0.88, 0, -0.55), STOMP],
				["fx", 1.34, "shock", {"from": "Leg03", "size": 0.8}], ["fx", 1.34, "puff", {"from": "Leg03", "color": "#8a7a66", "amount": 10, "size": 1.0, "rise": 0.3}],
				["fx", 1.4, "dust", {"amount": 20}]]},
			## Its crown slips askew and wobbles; its hand comes up and sets it straight.
			"crown": {"length": 3.6, "weight": 2.0, "do": [["turn", "crown", Z, 0.0, 13.0, CROWN_SLIP], ["turn", "head", Z, 0.0, 5.0, CROWN_SLIP],
				["turn", "arm_l", X, 0.0, -145.0, HAND_UP], ["turn", "arm_l", Z, 0.0, 25.0, HAND_UP],
				["fx", 2.2, "sparks", {"from": "Crown25", "color": "#ffd060", "amount": 10, "speed": 1.2}]]},
			## The bird flutters up off its shoulder and settles; the giant turns its head to it.
			"bird": {"length": 3.0, "weight": 2.0, "do": [["turn", "bird_l", Z, 0.0, 45.0, WINGBEATS], ["turn", "bird_r", Z, 0.0, -45.0, WINGBEATS],
				["move", "bird", Vector3.ZERO, Vector3(0, 0.28, 0.06), BIRD_HOP], ["turn", "head", Y, 0.0, -24.0, BIRD_LOOK], ["turn", "head", X, 0.0, -8.0, BIRD_LOOK],
				["fx", 0.35, "sparks", {"from": "Bird01", "color": "#fff0c0", "amount": 6, "speed": 1.2}],
				["fx", 1.75, "puff", {"from": "Bird01", "color": "#c8c0b0", "amount": 4, "size": 0.4, "rise": 0.1}]]},
			## Throws its head back in a silent roar, arms flexed, heart blazing; the bird flaps.
			"roar": {"length": 2.8, "hold": 1.0, "weight": 1.5, "do": [["turn", "jaw", X, 0.0, 28.0, "f"], ["turn", "head", X, 0.0, -16.0, "f"],
				["turn", "neck", X, 0.0, -6.0, "f"], ["tremble", "head", 0.012, "f"], ["turn", "arm_r", Z, 0.0, -12.0, "f"], ["turn", "arm_l", Z, 0.0, 12.0, "f"],
				["each", "heart", 0.0, 0.25, "f"], ["turn", "bird_l", Z, 0.0, 40.0, "flap"], ["turn", "bird_r", Z, 0.0, -40.0, "flap"],
				["fx", 1.0, "ripple", {"from": "Jaw01", "color": "accent", "radius": 1.6}], ["fx", 1.05, "dust", {"amount": 25}],
				["fx", 1.0, "glow", {"from": "Heart02", "color": "accent", "size": 0.6}]]},
			## Surveys its hall: the head turns slowly to one side and the other.
			"survey": {"length": 4.2, "hold": 2.6, "weight": 1.5, "do": [["gaze", "head", 34.0, 10.0, "f", 3], ["turn", "neck", X, 0.0, -4.0, "f"],
				["fx", 0.8, "flash_light", {"from": "Head02", "color": "#ffe0b0", "energy": 1.4}]]},
		},
		"moves": {
			## Its right fist raised overhead and brought down on the floor before it.
			"Crush": [["turn", "arm_r", X, 0.0, -60.0, OVERHEAD], ["turn", "arm_r", X, -85.0, 44.0, "big"], ["turn", "head", X, -10.0, 12.0, "big"],
				["lean", X, -4.0, 7.0, Vector3(0, 0, -0.6), "big"], ["rear", 0.2, "big"],
				["fx", 0.3, "shock", {"from": "ArmR03", "size": 1.3}], ["fx", 0.31, "shards", {"from": "ArmR03", "color": "#8a7a66", "amount": 12, "speed": 4.0}],
				["fx", 0.32, "dust", {"amount": 40}]],
			## Both fists overhead, leaning back, and the whole colossus falls forward on them.
			"Topple": [["turn", "crown", Z, 0.0, 15.0, "big"], ["turn", "arm_r", X, 0.0, -60.0, OVERHEAD], ["turn", "arm_r", X, -85.0, 36.0, "big"],
				["turn", "arm_l", X, 0.0, -60.0, OVERHEAD], ["turn", "arm_l", X, -85.0, 36.0, "big"],
				["lean", X, -7.0, 13.0, Vector3(0, 0, -0.6), "big"], ["hop", Vector3(0, 0.1, 0), Vector3(0, -0.06, 0.1), "big"],
				["fx", 0.3, "shock", {"ahead": 1.5, "size": 1.8}], ["fx", 0.32, "dust", {"amount": 90}],
				["fx", 0.31, "shards", {"from": "feet", "off": Vector3(0, 0.3, 1.6), "color": "#8a7a66", "amount": 14, "speed": 4.5}]],
			## A knee buckles; it lurches, arms flung out, crown askew, dust at its feet.
			"Stumble": [["turn", "crown", Z, -14.0, 14.0, "shake"], ["turn", "leg_r", X, 0.0, 10.0, "hold"], ["turn", "arm_r", Z, 0.0, -18.0, "hold"],
				["turn", "arm_l", Z, 0.0, 22.0, "hold"], ["lean", Z, -6.0, 6.0, Vector3.ZERO, LURCH], ["hop", Vector3.ZERO, Vector3(0, -0.06, 0), "hold"],
				["fx", 0.3, "puff", {"from": "feet", "color": "#8a7a66", "amount": 12, "size": 1.2, "rise": 0.3}]],
			## Arms crossed before it, head down, braced.
			"Bulwark": [["turn", "arm_r", X, 0.0, -55.0, "hold"], ["turn", "arm_r", Y, 0.0, 25.0, "hold"], ["turn", "arm_l", X, 0.0, -55.0, "hold"],
				["turn", "arm_l", Y, 0.0, -25.0, "hold"], ["turn", "head", X, 0.0, 10.0, "hold"], ["hop", Vector3.ZERO, Vector3(0, -0.06, 0), "hold"],
				["fx", 0.28, "puff", {"from": "feet", "color": "#8a7a66", "amount": 10, "size": 1.2, "rise": 0.3}]],
			## Rises to its full height, arms spread, head back, crown and heart blazing.
			"Rise": [["hop", Vector3(0, -0.12, 0), Vector3(0, 0.16, 0), "big"], ["turn", "head", X, 0.0, -18.0, "hold"],
				["turn", "arm_r", Z, 0.0, -42.0, "hold"], ["turn", "arm_l", Z, 0.0, 42.0, "hold"], ["each", "heart", 0.0, 0.3, "pulse"],
				["fx", 0.3, "glow", {"from": "Crown25", "color": "#ffd060", "size": 0.7}], ["fx", 0.3, "flash_light", {"from": "Crown25", "color": "#ffd060", "energy": 3.0}],
				["fx", 0.32, "rise", {"from": "centre", "color": "#ffd060", "amount": 24}], ["fx", 0.3, "ring", {"color": "accent", "radius": 2.6}]],
			## Its crown lifts off its head, turns once in a blaze of gold, and settles.
			"Crowned": [["whirl", "crown", Y, 1.0, "hold"], ["move", "crown", Vector3.ZERO, Vector3(0, 0.22, 0), "hold"], ["turn", "head", X, 0.0, -10.0, "hold"],
				["each", "heart", 0.0, 0.25, "pulse"],
				["fx", 0.3, "rise", {"from": "Crown25", "color": "#ffd060"}], ["fx", 0.3, "glow", {"from": "Crown25", "color": "#ffd060", "size": 0.6}],
				["fx", 0.35, "sparks", {"from": "Crown25", "color": "#ffd060", "amount": 18, "speed": 2.0}]],
			## Its bird calls, wings beating, and the giant raises its arm to the tunnels.
			"Summon": [["turn", "bird_l", Z, 0.0, 45.0, "flutter"], ["turn", "bird_r", Z, 0.0, -45.0, "flutter"], ["turn", "bird", Vector3(0.99, 0, 0.15), 0.0, -18.0, "hold"],
				["move", "bird", Vector3.ZERO, Vector3(0, 0.12, 0), "pulse"], ["turn", "head", Y, 0.0, -16.0, "hold"],
				["turn", "arm_r", X, 0.0, -35.0, "hold"], ["turn", "arm_r", Z, 0.0, -15.0, "hold"],
				["fx", 0.25, "ripple", {"from": "Bird03", "color": "#ffd04a", "radius": 0.8}], ["fx", 0.3, "sparks", {"from": "Bird02", "color": "#ffd04a", "amount": 14, "speed": 2.0}],
				["fx", 0.3, "ring", {"color": "#ffd04a", "radius": 3.0}]],
		},
		"heavy": {
			## Topple held: both fists high, leaning back, jaw open in a roar, the chest's heart
			## blazing and gold rising off the crown; then the whole of it comes down.
			"Topple": {"at": "Heart02", "pose": [["turn", "jaw", X, 0.0, 26.0, "h"], ["turn", "head", X, 0.0, -18.0, "h"], ["tremble", "upper", 0.01, "h"]],
				"charge": [["charge_glow", {"from": "Heart02", "color": "accent", "seconds": 0.55}], ["flash_light", {"from": "Crown25", "color": "#ffd060", "energy": 3.0}],
					["rise", {"from": "Crown25", "color": "#ffd060", "amount": 18}], ["spiral", {"from": "Heart02", "color": "accent", "amount": 30}],
					["charge_dust", {"seconds": 0.45}]],
				"impact": [["shock", {"ahead": 1.8, "size": 2.4}], ["shards", {"from": "feet", "off": Vector3(0, 0.3, 1.8), "color": "#8a7a66", "amount": 20, "speed": 5.5}],
					["shards", {"from": "feet", "off": Vector3(0, 0.3, 1.8), "color": "accent", "amount": 10, "speed": 4.5}],
					["ring", {"color": "accent", "radius": 3.4}], ["dust", {"amount": 110}]]},
		},
	},
}

# --- shared helpers ------------------------------------------------------------------------------

static func _blink_now(m: Node3D, selector: String, clock: float, every: float, by: Vector3, weight: float) -> void:
	## Eyes shut an instant now and then (now and then twice), squashed about where they are this
	## frame: they ride stalks that swing on their own, so not about where they rest.
	var step: int = int(floor(clock / every))
	var local: float = clock - float(step) * every - every * (0.2 + 0.25 * (1.0 + float(m._noise(step * 3 + int(m.noise_seed) + 11))))
	var b: float = 0.0
	if local > 0.0 and local < 0.16:
		b = sin(local / 0.16 * PI)
	elif local > 0.26 and local < 0.42 and float(m._noise(step * 7 + int(m.noise_seed))) > 0.5:
		b = sin((local - 0.26) / 0.16 * PI)
	b *= weight
	if b <= 0.0:
		return
	for part in m._select(selector):
		var node: Node3D = part
		if node.get_child_count() == 0 or not node.get_child(0) is Node3D:
			continue
		var at: Vector3 = node.transform * (node.get_child(0) as Node3D).transform.origin
		m.swell([node], at, Vector3.ONE.lerp(by, b))

static func _steady(m: Node3D, selector: String, share: float) -> void:
	## These parts' own idle turn (creature_part.gd: a swing about their pivot) undone by `share`.
	if share <= 0.0001:
		return
	for part in m._select(selector):
		var node: Node3D = part
		var rest: Transform3D = node.get("_rest")
		var own: Quaternion = (node.transform.basis.orthonormalized() * rest.basis.orthonormalized().inverse()).get_rotation_quaternion()
		var undo: Quaternion = Quaternion.IDENTITY.slerp(own.inverse(), clampf(share, 0.0, 1.0))
		if undo.get_angle() > 0.00001:
			m.turn([node], node.transform.origin, undo.get_axis(), undo.get_angle())

## Coins a move or fidget tosses (a `["call", "_coins"]`), by scene and move: [time s, from, to,
## how many]. A place is a part, "floor:d" (the floor d m before it) or "party" (a way short of
## the party, so nothing lands on the lens).
const COINS: Dictionary = {
	"CROUPIER_CRAB/Jackpot": [[0.3, "ClawR05", "floor:1.5", 10]],
	"CROUPIER_CRAB/Rake": [[0.3, "floor:1.2", "Core01", 7]],
	"CROUPIER_CRAB/Fold": [[0.32, "Core01", "party", 6]],
	"THE_ASSAYER/Eat the Rich": [[0.08, "party", "PanL04", 10]],
	"THE_ASSAYER/Tax": [[0.05, "party", "PanL04", 6]],
	"THE_ASSAYER/Heavy Tax": [[0.05, "party", "PanL04", 10]],
}

static func _coins(m: Node3D, clip: Dictionary, _delta: float) -> void:
	var list: Array = COINS.get(str(m.looks) + "/" + str(clip.get("move", "")), [])
	var t: float = float(clip.get("keyed", clip.t))
	for index in range(list.size()):
		var spec: Array = list[index]
		var key: String = "coins%d" % index
		if t < float(spec[0]) or clip.fired.has(key) or clip.has("fading"):
			continue
		clip.fired[key] = true
		var fx: Node = m._fx_node(clip)
		if fx != null:
			fx.call("coins", _place(m, clip, str(spec[1])), _place(m, clip, str(spec[2])), int(spec[3]))

static func _place(m: Node3D, clip: Dictionary, where: String) -> Vector3:
	var creature: Node3D = m._creature
	if where.begins_with("floor:"):
		return creature.global_position + m._forward() * float(where.substr(6)) * creature.scale.x + Vector3(0, 0.08, 0)
	if where == "party":
		var near: Vector3 = (m._aim(clip) as Vector3).lerp(m.point("centre"), 0.45)
		near.y = maxf(0.3, near.y - 0.4)
		return near
	return m.point(where)

# --- the Croupier Crab: legs that patter, a coin that flips --------------------------------------

## Its six legs, each two stones hung from its hip: [selector, side (+1 its left), beat]. Two sets
## of three step together, as a crab's do.
const CRAB_LEGS: Array = [["Leg01-02", 1.0, 0.0], ["Leg03-04", 1.0, PI], ["Leg05-06", 1.0, 0.0],
	["Leg07-08", -1.0, PI], ["Leg09-10", -1.0, 0.0], ["Leg11-12", -1.0, PI]]

static func _crab_legs(m: Node3D, phase: float, lift: float, swing: float) -> void:
	## Each leg lifted from its hip on its forward stroke and swung, its set a half beat apart.
	for spec in CRAB_LEGS:
		var parts: Array = m._select(spec[0])
		if parts.is_empty():
			continue
		var hip: Vector3 = (parts[0] as Node3D).get("_rest").origin
		var s: float = phase + float(spec[2])
		m.turn(parts, hip, Vector3.BACK, deg_to_rad(lift) * maxf(0.0, sin(s)) * float(spec[1]))
		m.turn(parts, hip, Vector3.UP, deg_to_rad(swing) * cos(s))

static func _idle_crab(m: Node3D, clock: float, weight: float) -> void:
	## Its legs never quite still, and every few seconds a quick shuffle of steps on the spot; its
	## eyes on their stalks blink now and then.
	_crab_legs(m, clock * 1.6, 1.5 * weight, 1.2 * weight)
	var p: float = fposmod(clock + 2.0, 5.2)
	var burst: float = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(1.0, 1.4, p)) * weight
	if burst > 0.001:
		_crab_legs(m, clock * 9.0, 9.0 * burst, 5.0 * burst)
	_blink_now(m, "Eye02", clock, 4.2, Vector3(1, 0.2, 1), weight)
	_blink_now(m, "Eye04", clock, 4.2, Vector3(1, 0.2, 1), weight)

static func _crab_scuttle(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its legs scuttling fast while it is on the move (the fidget's rise and fall), still while it
	## stands.
	var t: float = float(clip.get("keyed", clip.t))
	var v: float = clampf(m._v(clip, "f", t), 0.0, 1.0)
	var a: float = 4.0 * v * (1.0 - v)
	_crab_legs(m, t * 17.0, 16.0 * a, 11.0 * a)

static func _crab_patter(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its legs pattering as it lunges (scrabbling on through a heavy blow's hold).
	var t: float = float(clip.get("keyed", clip.t))
	var a: float = sin(PI * clampf(t / 0.75, 0.0, 1.0)) * float(clip.get("weight", 1.0))
	_crab_legs(m, float(clip.t) * 19.0, 12.0 * a, 7.0 * a)

## What its coin does in a move or fidget: "spin" [whole turns, envelope] end over end, "grow"
## [wind, strike, envelope] a swell as it gleams, "toss" [height, envelope] up off the claw.
const CRAB_COIN: Dictionary = {
	"flip": {"spin": [2.0, COIN_TOSS], "toss": [0.42, COIN_TOSS]},
	"Jackpot": {"grow": [0.6, 0.15, "big"], "spin": [1.0, "big"]},
	"Double": {"spin": [2.0, "hold"], "grow": [0.0, 0.35, "hold"]},
}

static func _crab_coin(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The coin in its big claw, about where it is this frame (the claw swings it about on its
	## own): laid before the claw's own turns, which carry it.
	var spec: Dictionary = CRAB_COIN.get(str(clip.get("move", "")), {})
	var parts: Array = m._select("ClawR05")
	if spec.is_empty() or parts.is_empty():
		return
	var coin: Node3D = parts[0]
	if coin.get_child_count() == 0 or not coin.get_child(0) is Node3D:
		return
	var at: Vector3 = coin.transform * (coin.get_child(0) as Node3D).transform.origin
	var t: float = float(clip.get("keyed", clip.t))
	if spec.has("grow"):
		var v: float = m._v(clip, spec.grow[2], t)
		var k: float = (float(spec.grow[0]) if v < 0.0 else float(spec.grow[1])) * absf(v)
		m.swell([coin], at, Vector3.ONE * (1.0 + k))
	if spec.has("spin"):
		var turns: float = float(spec.spin[0]) * float(m._progress(clip, "coin", spec.spin[1], t)) * float(clip.get("weight", 1.0))
		m.turn([coin], at, Vector3.RIGHT, TAU * turns)
	if spec.has("toss"):
		m.shift([coin], Vector3(0, float(spec.toss[0]) * m._v(clip, spec.toss[1], t), 0))

# --- the Hoard Mimic: eyes that look about, a tongue that lolls ---------------------------------

static func _tongue_lay(chain: Array, m: Node3D, side: Array, lift: Array) -> void:
	## Each stone of the tongue turned about its own root, across and up in one pass from the tip,
	## carrying every stone after it (two passes would turn about roots the first had moved).
	for index in range(chain.size() - 1, -1, -1):
		var carried: Array = []
		for later in range(index, chain.size()):
			carried.append_array(chain[later].parts)
		if index < side.size():
			m.turn(carried, chain[index].joint, Vector3.UP, float(side[index]))
		if index < lift.size():
			m.turn(carried, chain[index].joint, Vector3.RIGHT, float(lift[index]))

static func _idle_mimic(m: Node3D, clock: float, weight: float) -> void:
	## Its eyes dart from one thing to the next and blink now and then; its tongue lolls on the
	## floor, the tip curling.
	var beat: float = clock / 1.7
	var step: int = int(floor(beat))
	var ease: float = smoothstep(0.0, 0.18, beat - float(step))
	var was := Vector2(m._noise(step - 1), m._noise(step + 41))
	var now := Vector2(m._noise(step), m._noise(step + 42))
	var look: Vector2 = was.lerp(now, ease)
	var blink: float = 0.0
	var b: float = fmod(clock, 4.3)
	if b < 0.16:
		blink = sin(b / 0.16 * PI)
	for side in ["eye_r", "eye_l"]:
		var eye: Dictionary = m.group(side)
		if blink > 0.0:
			m.swell(eye.parts, eye.joint, Vector3(1.0, 1.0 - 0.85 * blink * weight, 1.0))
		m.turn(eye.parts, eye.joint, Vector3.UP, deg_to_rad(28.0) * look.x * weight)
		m.turn(eye.parts, eye.joint, Vector3.RIGHT, deg_to_rad(14.0) * look.y * weight)
	var chain: Array = m.group("tongue").chain
	var wag: Array = []
	var curl: Array = []
	for k in range(chain.size()):
		var reach: float = smoothstep(8.0, 16.0, float(k))
		wag.append(deg_to_rad(6.0) * reach * sin(clock * 1.6 - float(k) * 0.45) * weight)
		curl.append(deg_to_rad(-7.0) * smoothstep(13.0, 17.0, float(k)) * (0.5 + 0.5 * sin(clock * 1.1)) * weight)
	_tongue_lay(chain, m, wag, curl)

static func _mimic_lick(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## It licks its lips: the tongue's far end lifts off the floor and sweeps across and back, and
	## lies down again; its eyes half shut and roll up, pleased with itself.
	var t: float = float(clip.get("keyed", clip.t))
	var k: float = m._v(clip, "f", t)
	var sweep: float = sin(t * 4.2) * k
	for side in ["eye_r", "eye_l"]:
		var eye: Dictionary = m.group(side)
		m.swell(eye.parts, eye.joint, Vector3(1.0, 1.0 - 0.45 * k, 1.0))
		m.turn(eye.parts, eye.joint, Vector3.RIGHT, deg_to_rad(-12.0) * k)
	var chain: Array = m.group("tongue").chain
	var side_turns: Array = []
	var lift: Array = []
	for index in range(chain.size()):
		var reach: float = smoothstep(9.0, 15.0, float(index))
		side_turns.append(deg_to_rad(6.5) * reach * sweep)
		lift.append(deg_to_rad(-8.5) * reach * k)
	_tongue_lay(chain, m, side_turns, lift)

static func _mimic_gulp(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its tongue whips up at the party and back in, the lid slams on what it caught, and the whole
	## chest heaves as it swallows it down.
	var t: float = float(clip.t)
	var lick: float = smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.16, 0.3, t))
	var chain: Array = m.group("tongue").chain
	var lift: Array = []
	for k in range(chain.size()):
		lift.append(deg_to_rad(-16.0) * smoothstep(9.0, 13.0, float(k)) * lick)
	m.chain_turns(chain, Vector3.RIGHT, lift)
	var shut: float = smoothstep(0.22, 0.3, t) * (1.0 - smoothstep(0.55, 0.95, t))
	var lid: Dictionary = m.group("lid")
	m.turn(lid.parts, lid.joint, Vector3.RIGHT, deg_to_rad(100.0) * shut)
	## The hoard sinks under the shut lid, or its crystals would poke through it.
	m.shift(m.group("hoard").parts, Vector3(0, -0.15 * shut, 0))
	var gulp: float = sin(PI * clampf((t - 0.34) / 0.32, 0.0, 1.0))
	if gulp > 0.0:
		var all: Dictionary = m.group("all")
		m.swell(all.parts, all.joint, Vector3(1.0 + 0.06 * gulp, 1.0 - 0.08 * gulp, 1.0 + 0.06 * gulp))
	m._creature.set("_rear", -0.35 * smoothstep(0.24, 0.3, t) * (1.0 - smoothstep(0.4, 0.8, t)))
	m._rear_held = true
	if t >= HIT:
		m._queue(clip, "gulp", "puff", {"from": "Mouth01", "color": "#ffd060", "amount": 8, "size": 0.5, "glow": true})
	if t >= 0.45:
		m._queue(clip, "down", "sparks", {"from": "Mouth01", "color": "#ffd060", "amount": 10, "speed": 1.4})

# --- the Crystal Hydra: heads that weave, snap in turns and roar ------------------------------

const HYDRA_HEADS: Array = [
	{"neck": "Neck01-03", "head": "Head01-07", "jaw": "Jaw01", "mouth": "Mouth01", "axis": Vector3(0.99, 0, -0.15)},
	{"neck": "Neck04-06", "head": "Head08-14", "jaw": "Jaw02", "mouth": "Mouth02", "axis": Vector3(1, 0, 0)},
	{"neck": "Neck07-09", "head": "Head15-21", "jaw": "Jaw03", "mouth": "Mouth03", "axis": Vector3(0.29, 0, 0.96)}]

static func _hydra_lay(m: Node3D, spec: Dictionary, jaw_deg: float, head_deg: float, neck_deg: float, yaw_deg: float, shake: Vector3 = Vector3.ZERO) -> void:
	## One head laid leaf first: its jaw about its hinge (+ opens), the head about the neck's top
	## (+ lunges), the neck about its root (+ forward, along the head's own sideways axis), then the
	## whole neck turned about up (+ toward its left).
	var jaw: Array = m._select(spec.jaw)
	var head: Array = m._select([spec.head, spec.jaw, spec.mouth])
	var neck: Array = m._select([spec.neck, spec.head, spec.jaw, spec.mouth])
	if jaw.is_empty() or head.is_empty() or neck.is_empty():
		return
	var axis: Vector3 = spec.axis
	var root: Vector3 = (neck[0] as Node3D).get("_rest").origin
	m.turn(jaw, (jaw[0] as Node3D).get("_rest").origin, axis, deg_to_rad(jaw_deg))
	m.turn(head, (head[0] as Node3D).get("_rest").origin, axis, deg_to_rad(head_deg))
	m.turn(neck, root, axis, deg_to_rad(neck_deg))
	m.turn(neck, root, Vector3.UP, deg_to_rad(yaw_deg))
	if not shake.is_zero_approx():
		m.shift(head, shake)

static func _hydra_weave(clock: float, index: int, size: float) -> Array:
	## Where a head's slow weave has it: [jaw, head, neck, yaw] degrees, its head a beat behind its
	## neck like a snake's, now and then a hiss.
	var c: float = clock + float(index) * 2.1
	var hiss: float = pow(maxf(0.0, sin(clock * 0.37 + float(index) * 2.3)), 8.0)
	return [9.0 * hiss * size, 5.0 * sin(c * 1.2 - 0.7) * size, 3.5 * sin(c * 1.2) * size, 7.0 * sin(c * 0.75) * size]

static func _idle_hydra(m: Node3D, clock: float, weight: float) -> void:
	## Its three heads weaving on their necks, each in its own time.
	for index in range(HYDRA_HEADS.size()):
		var w: Array = _hydra_weave(clock, index, weight)
		_hydra_lay(m, HYDRA_HEADS[index], w[0], w[1], w[2], w[3])

static func _hydra_charm(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## All three heads swaying in big slow figures, a beat apart, like snakes to a charmer's pipe.
	var t: float = float(clip.get("keyed", clip.t))
	var k: float = m._v(clip, "f", t)
	for index in range(HYDRA_HEADS.size()):
		var w: Array = _hydra_weave(float(m._clock), index, k)
		var c: float = t * 1.9 + float(index) * 1.2
		_hydra_lay(m, HYDRA_HEADS[index], w[0] + 6.0 * k, w[1] + 9.0 * sin(c - 0.8) * k, w[2] + 7.0 * sin(c + 1.3) * k, w[3] + 18.0 * sin(c) * k)

static func _hydra_squabble(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Each head in turn snaps at the air beside it (at its neighbour), the others weaving on.
	var t: float = float(clip.get("keyed", clip.t))
	var k: float = m._v(clip, "f", t)
	var weight: float = float(clip.get("weight", 1.0))
	var toward: Array = [14.0, -10.0, -14.0]
	for index in range(HYDRA_HEADS.size()):
		var w: Array = _hydra_weave(float(m._clock), index, k)
		var local: float = t - (0.35 + 0.5 * float(index))
		var open: float = m.value("snap", local) * weight if local > 0.0 else 0.0
		var v: float = m.value("attack", local) * weight if local > 0.0 else 0.0
		var aside: float = smoothstep(0.0, 0.2, local) * (1.0 - smoothstep(0.5, 0.9, local)) * weight if local > 0.0 else 0.0
		_hydra_lay(m, HYDRA_HEADS[index], w[0] + 30.0 * maxf(-open, 0.0) - 3.0 * maxf(open, 0.0), w[1] - 14.0 * maxf(-v, 0.0) + 16.0 * maxf(v, 0.0),
			w[2] + 6.0 * maxf(v, 0.0), w[3] + float(toward[index]) * aside)
		if local >= HIT:
			m._queue(clip, "snap%d" % index, "sparks", {"from": HYDRA_HEADS[index].mouth, "color": "#c890ff", "amount": 6, "speed": 1.6})

static func _hydra_bellow(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The tall head rears up and roars, jaw wide and shaking; the other two hiss and pull away.
	var t: float = float(clip.get("keyed", clip.t))
	var k: float = m._v(clip, "f", t)
	for index in range(HYDRA_HEADS.size()):
		var w: Array = _hydra_weave(float(m._clock), index, k * 0.5)
		if index == 1:
			var shake := Vector3(sin(t * 47.0), 0.6 * sin(t * 41.0 + 1.0), sin(t * 53.0 + 2.0)) * 0.008 * k
			_hydra_lay(m, HYDRA_HEADS[index], w[0] + 40.0 * k, w[1] - 28.0 * k, w[2] - 10.0 * k, w[3], shake)
		else:
			_hydra_lay(m, HYDRA_HEADS[index], w[0] + 14.0 * k, w[1] - 8.0 * k, w[2] - 4.0 * k, w[3] + (12.0 if index == 2 else -12.0) * k)

static func _hydra_bite(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its heads take turns: the striking one rears, its jaw dropping, lunges on its neck and
	## snaps shut; the other two draw back and hiss.
	var t: float = float(clip.t)
	var striker: int = (int(clip.strike) - 1) % HYDRA_HEADS.size()
	var bell: float = smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(0.5, 0.95, t))
	for index in range(HYDRA_HEADS.size()):
		if index == striker:
			var open: float = m.value("snap", t)
			var v: float = m.value("attack", t)
			_hydra_lay(m, HYDRA_HEADS[index], 38.0 * maxf(-open, 0.0) - 4.0 * maxf(open, 0.0), -22.0 * maxf(-v, 0.0) + 24.0 * maxf(v, 0.0),
				-10.0 * maxf(-v, 0.0) + 16.0 * maxf(v, 0.0), 0.0)
		else:
			_hydra_lay(m, HYDRA_HEADS[index], 14.0 * bell, -7.0 * bell, -3.0 * bell, 0.0)
	if t >= HIT:
		m._queue(clip, "snap", "sparks", {"from": HYDRA_HEADS[striker].mouth, "color": "#c890ff", "amount": 12, "speed": 2.5})

static func _hydra_roar(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Sprout: every head rears and roars, spreading apart, shaking; the geode it grows from swells
	## and crystal bursts from it where another head is coming.
	var t: float = float(clip.t)
	var up: float = smoothstep(0.0, HIT, t) * (1.0 - smoothstep(0.7, 1.1, t))
	var quake: float = smoothstep(0.25, 0.32, t) * (1.0 - smoothstep(0.6, 0.85, t))
	for index in range(HYDRA_HEADS.size()):
		var shake := Vector3(sin(t * 47.0 + float(index)), 0.6 * sin(t * 41.0 + 1.0), sin(t * 53.0 + 2.0 * float(index))) * 0.012 * quake
		_hydra_lay(m, HYDRA_HEADS[index], 35.0 * up, -25.0 * up, -8.0 * up, float(index - 1) * 12.0 * up, shake)
	var body: Dictionary = m.group("body")
	m.swell(body.parts, body.joint, Vector3.ONE * (1.0 + 0.07 * quake))
	if t >= HIT:
		m._queue(clip, "sparks", "sparks", {"from": "centre", "color": "#c890ff", "amount": 30, "speed": 3.5})
		m._queue(clip, "burst", "shards", {"from": "Body01", "color": "#c890ff", "amount": 16, "speed": 3.5})
		m._queue(clip, "roar", "ripple", {"from": "Mouth02", "color": "#c890ff", "radius": 1.4})

# --- the Assayer: a balance whose pans hang plumb -----------------------------------------------

## How far a move or fidget tips its balance: [envelope, wind deg, strike deg] (+ lifts the gold
## pan's end, - drops it).
const ASSAYER_TIPS: Dictionary = {
	"Weigh": ["attack", 14.0, -20.0],
	"Drop the Weights": ["big", 24.0, -16.0],
	"Balance": ["shake", 6.0, -6.0],
	"Eat the Rich": ["hold", 0.0, -12.0],
	"Tax": ["hold", 0.0, -10.0],
	"Heavy Tax": ["hold", 0.0, -16.0],
	"Seize": ["hold", 0.0, 12.0],
	"Raise the Rate": ["pulse", 0.0, -6.0],
	"weigh": [WEIGH, 0.0, -14.0],
	"tip": [TIP, -16.0, 16.0],
	"tap": [TAP_JOLT, 0.0, 3.0],
}

static func _tilt(m: Node3D, pivot: Vector3, x_deg: float, z_deg: float) -> void:
	## The whole creature tipped a little about `pivot`, laid on its body as a move's lean is (so
	## every part's own turn stays true under it).
	var b := Basis(Vector3.RIGHT, deg_to_rad(x_deg)) * Basis(Vector3.BACK, deg_to_rad(z_deg))
	m._lean = Transform3D(Basis.IDENTITY, pivot) * Transform3D(b, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot) * (m._lean as Transform3D)
	m._leaning = true

static func _hang_pans(m: Node3D, share: float, lag: float, tip: float) -> void:
	## Its pans kept hanging plumb from the beam's ends, the beam's own rocking undone on them by
	## `share` and `lag` radians of a pendulum's swing behind it; then the whole balance tipped
	## `tip` radians about its pivot, the pans turned back by as much so they still hang true.
	var scales: Dictionary = m.group("scales")
	if scales.parts.is_empty():
		return
	for side in PAN_HOOKS:
		var parts: Array = m._select(side)
		if parts.is_empty():
			continue
		var first: Node3D = parts[0]
		var rest: Transform3D = first.get("_rest")
		var hook: Vector3 = first.transform * (rest.affine_inverse() * (PAN_HOOKS[side] as Vector3))
		if share > 0.0001:
			var own: Quaternion = (first.transform.basis.orthonormalized() * rest.basis.orthonormalized().inverse()).get_rotation_quaternion()
			var undo: Quaternion = Quaternion.IDENTITY.slerp(own.inverse(), clampf(share, 0.0, 1.0))
			if undo.get_angle() > 0.00001:
				m.turn(parts, hook, undo.get_axis(), undo.get_angle())
		m.turn(parts, hook, BEAM, lag - tip)
	m.turn(scales.parts, scales.joint, BEAM, tip)

static func _idle_assayer(m: Node3D, clock: float, weight: float) -> void:
	## Hanging in the air it tilts a little, a beat behind its own rise and fall; its balance rocks
	## and its pans hang plumb from the beam, swinging a little behind it.
	_tilt(m, Vector3(0, 2.05, 0), 1.4 * sin(clock * 0.7 - 1.1) * weight, 1.0 * sin(clock * 0.43 + 0.7) * weight)
	_hang_pans(m, weight, deg_to_rad(4.0) * sin(clock * 1.6 - 0.9) * weight, 0.0)

static func _assayer_scales(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its balance in a move or fidget: tipped as ASSAYER_TIPS says, its pans still hanging plumb
	## (the share the idle hands over while a move holds it off).
	var tip: float = 0.0
	var spec: Array = ASSAYER_TIPS.get(str(clip.get("move", "")), [])
	if not spec.is_empty():
		var v: float = m._v(clip, spec[0], float(clip.get("keyed", clip.t)))
		tip = deg_to_rad(float(spec[1]) * -v if v < 0.0 else float(spec[2]) * v)
	_hang_pans(m, 1.0 - float(m._idle_weight), 0.0, tip)

# --- the Collector: eyes on swinging stalks -------------------------------------------------------

static func _idle_collector(m: Node3D, clock: float, weight: float) -> void:
	## Its cane stays planted where it stands (the scene's own swing of it mostly undone, so the
	## ferrule does not slide about the floor) and only taps; the gems at the tips of its stalks
	## blink together now and then.
	_steady(m, "Cane", 0.85 * weight)
	_blink_now(m, "Eye03", clock, 5.0, Vector3(1, 0.15, 1), weight)
	_blink_now(m, "Eye06", clock, 5.0, Vector3(1, 0.15, 1), weight)
