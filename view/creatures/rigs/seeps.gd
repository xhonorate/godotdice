extends RefCounted
## The Seeps: the flooded mine's creatures (and the Cave Crayfish).
## Each creature's rig as data (see the gesture language in creature_rigs.gd), keyed by its scene,
## and the moves and idles no table says, written out as functions of the Moves node
## (creature_moves.gd) passed in as `m`. creature_rigs.gd merges every mine's RIGS.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {
	"_lamprey_drink": 1.3,
	"_choir_sing": 1.45,
}
## When a move played by a function is wound back furthest (a heavy one holds there): the
## Choir's Requiem Chorus holds with every head thrown back, mouths wide, drawing breath.
const CUSTOM_WIND: Dictionary = {
	"_choir_sing": 0.22,
}

## The Seep Eel's side axis at its head (+ pitches the snout down, the jaw open) and the way it faces.
const EEL_S := Vector3(0.97, 0, -0.24)
const EEL_FACING := Vector3(0.24, -0.10, 0.97)
## The axis each lamprey head tips down about (a negative turn lifts it), square to its facing.
const LIFT_1 := Vector3(-0.83, 0, 0.27)
const LIFT_2 := Vector3(0.18, 0, -0.85)
const LIFT_3 := Vector3(0.65, 0, 0.58)
## The Lock-Keeper's gate thrown open: shut tight first, then flung up as the water goes.
const GATE_BURST: Array = [[0.0, 0.0], [0.18, -1.0], [0.27, 1.0], [0.85, 1.0], [1.2, 0.0]]
## Water colours of the Seeps.
const WATER := "#8fd0e8"
const DEEP := "#6ab8e0"
const DROP := "#bfe8ff"

const RIGS: Dictionary = {
	## The Seep Eel: an electric eel hanging in the water in a rising S. An eel swims where it
	## hangs (a wave running down it, the gills working, the jaw gaping slowly like a moray's),
	## current crackling along its spines; it strikes from the S, and its arc discharges.
	"SEEP_EEL": {
		"mouth": "Mouth01",
		"idle": "_idle_eel",
		"ambient": [{"kind": "crackle", "at": "Spine02", "color": "#9fe8ff"}, {"kind": "crackle", "at": "Spine05", "color": "#9fe8ff"},
			{"kind": "crackle", "at": "Arc01", "color": "#d8f8ff", "size": 1.3}],
		"groups": {
			"head": {"parts": ["Head", "Jaw", "Horn", "Arc", "FinR", "FinL", "Mouth"], "at": "Head01"},
			"jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"arc": {"parts": ["Arc"]},
			"spines": {"parts": ["Spine"]},
			"fins": {"parts": ["FinR", "FinL"], "at": "Head01"},
		},
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## A current runs down its spines from the tail, each bristling in turn, and jumps the arc
			## between its horns with a snap.
			"crackle": {"length": 2.4, "weight": 2.0, "do": [
				["each", "Spine01", 0.0, 0.45, [[0.0, 0.0], [0.25, 0.0], [0.35, 1.0], [0.6, 0.0]]],
				["each", "Spine02", 0.0, 0.45, [[0.0, 0.0], [0.38, 0.0], [0.48, 1.0], [0.73, 0.0]]],
				["each", "Spine03", 0.0, 0.45, [[0.0, 0.0], [0.51, 0.0], [0.61, 1.0], [0.86, 0.0]]],
				["each", "Spine04", 0.0, 0.45, [[0.0, 0.0], [0.64, 0.0], [0.74, 1.0], [0.99, 0.0]]],
				["each", "Spine05", 0.0, 0.45, [[0.0, 0.0], [0.77, 0.0], [0.87, 1.0], [1.12, 0.0]]],
				["each", "Spine06", 0.0, 0.45, [[0.0, 0.0], [0.9, 0.0], [1.0, 1.0], [1.25, 0.0]]],
				["each", "arc", 0.0, 0.7, [[0.0, 0.0], [1.0, 0.0], [1.1, 1.0], [1.5, 0.0]]],
				["tremble", "head", 0.012, [[0.0, 0.0], [1.0, 0.0], [1.08, 1.0], [1.45, 0.0]]],
				["fx", 0.35, "sparks", {"from": "Spine01", "color": "#d8f8ff", "amount": 8, "speed": 1.5, "life": 0.35}],
				["fx", 0.61, "sparks", {"from": "Spine03", "color": "#d8f8ff", "amount": 8, "speed": 1.5, "life": 0.35}],
				["fx", 0.87, "sparks", {"from": "Spine05", "color": "#d8f8ff", "amount": 8, "speed": 1.5, "life": 0.35}],
				["fx", 1.06, "flash_light", {"from": "Arc01", "color": "#9fe8ff", "energy": 2.5}],
				["fx", 1.08, "sparks", {"from": "Arc01", "color": "#e8fcff", "amount": 22, "speed": 3.0}]]},
			## A moray's gape: it lifts its snout and opens its jaw wide to show its teeth, fins
			## flared, holds it, and shuts.
			"gape": {"length": 3.2, "hold": 1.3, "weight": 1.5, "do": [["turn", "jaw", EEL_S, 0.0, 34.0, "f"], ["splay", "fins", 0.0, 28.0, "f"],
				["turn", "head", EEL_S, 0.0, -12.0, "f"], ["turn", "head", Y, 0.0, -8.0, "f"],
				["fx", 1.0, "bubbles", {"from": "Mouth01", "color": "#9fe8ff", "amount": 8}],
				["fx", 1.5, "sparks", {"from": "Mouth01", "color": "#d8f8ff", "amount": 10, "speed": 1.5, "life": 0.4}]]},
			## Swims hard for a few strokes where it hangs, head sweeping side to side to look about.
			"surge": {"length": 3.0, "hold": 1.0, "weight": 2.0, "do": [["gaze", "head", 22.0, 8.0, "f", 2], ["call", "_eel_surge"],
				["fx", 0.9, "bubbles", {"from": "Tail01", "color": "#9fe8ff", "amount": 10}]]},
		},
		"moves": {
			## Coils its S tighter and draws its head back with the jaw wide, then strikes along its
			## facing, the front of its body thrown after the head, teeth crackling.
			"Bite": [["turn", "jaw", EEL_S, 42.0, -5.0, "snap"], ["turn", "head", EEL_S, -22.0, 26.0, "attack"], ["call", "_eel_bite_body"],
				["rear", 0.3, "attack"], ["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#d8f8ff", "amount": 14, "speed": 2.5}]],
			## A current runs up its spines from the tail to the arc and it jolts as it lets go.
			"Shock": [
				["each", "Spine01", 0.0, 0.5, [[0.0, 0.0], [0.02, 0.0], [0.07, 1.0], [0.22, 0.0]]],
				["each", "Spine02", 0.0, 0.5, [[0.0, 0.0], [0.065, 0.0], [0.115, 1.0], [0.265, 0.0]]],
				["each", "Spine03", 0.0, 0.5, [[0.0, 0.0], [0.11, 0.0], [0.16, 1.0], [0.31, 0.0]]],
				["each", "Spine04", 0.0, 0.5, [[0.0, 0.0], [0.155, 0.0], [0.205, 1.0], [0.355, 0.0]]],
				["each", "Spine05", 0.0, 0.5, [[0.0, 0.0], [0.2, 0.0], [0.25, 1.0], [0.4, 0.0]]],
				["each", "Spine06", 0.0, 0.5, [[0.0, 0.0], [0.245, 0.0], [0.295, 1.0], [0.445, 0.0]]],
				["each", "arc", 0.0, 0.6, "pulse"], ["turn", "jaw", EEL_S, 0.0, 22.0, "attack"], ["turn", "head", EEL_S, -14.0, 6.0, "attack"],
				["call", "_eel_shock_body"], ["tremble", "head", 0.014, [[0.0, 0.0], [0.27, 0.0], [0.31, 1.0], [0.6, 0.0]]],
				["fx", 0.07, "sparks", {"from": "Spine01", "color": "#d8f8ff", "amount": 6, "speed": 1.5, "life": 0.3}],
				["fx", 0.16, "sparks", {"from": "Spine03", "color": "#d8f8ff", "amount": 6, "speed": 1.5, "life": 0.3}],
				["fx", 0.25, "sparks", {"from": "Spine05", "color": "#d8f8ff", "amount": 6, "speed": 1.5, "life": 0.3}],
				["fx", 0.26, "flash_light", {"from": "Arc01", "color": "#9fe8ff", "energy": 3.0}],
				["fx", 0.27, "zap", {"from": "Arc01", "color": "#9fe8ff"}], ["fx", 0.3, "sparks", {"from": "Arc01", "color": "#d8f8ff", "amount": 26, "speed": 4.0}]],
			## Lightning down the line: three jabs of its head, a bolt off a horn tip with each.
			"Arc": [["each", "spines", 0.0, 0.35, "thrice"], ["each", "arc", 0.0, 0.6, "thrice"], ["turn", "jaw", EEL_S, 0.0, 26.0, "thrice"],
				["turn", "head", EEL_S, -20.0, 8.0, "thrice"], ["call", "_eel_arc_body"],
				["fx", 0.28, "flash_light", {"from": "Arc01", "color": "#9fe8ff", "energy": 3.0}],
				["fx", 0.29, "zap", {"from": "Horn01", "color": "#9fe8ff"}], ["fx", 0.3, "sparks", {"from": "Arc01", "color": "#d8f8ff", "amount": 24, "speed": 4.0}],
				["fx", 0.51, "zap", {"from": "Horn02", "color": "#9fe8ff"}], ["fx", 0.52, "sparks", {"from": "Arc01", "color": "#d8f8ff", "amount": 24, "speed": 4.0}],
				["fx", 0.72, "flash_light", {"from": "Arc01", "color": "#9fe8ff", "energy": 3.0}],
				["fx", 0.73, "zap", {"from": "Arc01", "color": "#d8f8ff"}], ["fx", 0.74, "sparks", {"from": "Arc01", "color": "#d8f8ff", "amount": 30, "speed": 4.5}]],
		},
		"heavy": {
			## Its Arc held: coiled back hard, every spine bristling as the charge crawls up them from
			## the tail to the arc, which swells white; then it lets the whole charge go.
			"Arc": {"at": "Arc01",
				"pose": [["each", "spines", 0.0, 0.45, "h"], ["each", "arc", 0.0, 0.5, "h"], ["call", "_eel_charge"]],
				"charge": [["charge_glow", {"from": "Arc01", "color": "#9fe8ff", "seconds": 0.5}], ["flash_light", {"from": "Arc01", "color": "#9fe8ff", "energy": 2.5}],
					["bubbles", {"from": "centre", "color": "#9fe8ff", "amount": 14}]],
				"impact": [["flash_light", {"from": "Arc01", "color": "#e8fcff", "energy": 4.0}], ["sparks", {"from": "Arc01", "color": "#e8fcff", "amount": 50, "speed": 6.0}],
					["ripple", {"from": "Arc01", "color": "#9fe8ff", "radius": 1.1}]]},
		},
	},
	## The Lamprey Knot: three lampreys braided into one. Their heads weave like snakes about the
	## braid, the round toothed suckers working open and shut as they rasp, the tails twitching on
	## the floor; a head lunges and latches on, all three latch to drink.
	"LAMPREY_KNOT": {
		"mouth": "Mouth15",
		"groups": {
			"h1": {"parts": ["Head01-04", "Mouth01-07"], "at": "Head01"},
			"h2": {"parts": ["Head05-08", "Mouth08-14"], "at": "Head05"},
			"h3": {"parts": ["Head09-12", "Mouth15-21"], "at": "Head09"},
			"m1": {"parts": ["Mouth01-07"], "at": "Mouth01"},
			"m2": {"parts": ["Mouth08-14"], "at": "Mouth08"},
			"m3": {"parts": ["Mouth15-21"], "at": "Mouth15"},
			"tails": {"parts": ["Tail"]},
		},
		"idle_gestures": [["breathe", "m1", 0.16, 2.3, 0.0], ["breathe", "m2", 0.16, 2.0, 1.3], ["breathe", "m3", 0.16, 2.6, 2.6],
			["sway", "h1", X, 6.0, 1.2, 0.0], ["sway", "h1", Y, 10.0, 0.7, 0.5],
			["sway", "h2", Z, 6.0, 1.3, 0.9], ["sway", "h2", Y, 10.0, 0.8, 2.0],
			["sway", "h3", X, 6.0, 1.1, 1.8], ["sway", "h3", Y, 10.0, 0.75, 3.1],
			["sway_each", "tails", Y, 9.0, 2.3, 1.9]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## The front head rears up and its sucker flares wide, the ring of teeth rasping.
			"rasp": {"length": 2.8, "hold": 1.1, "weight": 2.0, "do": [["grow", "m3", 0.0, 0.4, "f"], ["grow", "m3", 0.0, 0.1, "chew"],
				["turn", "h3", LIFT_3, 0.0, -26.0, "f"], ["turn", "h3", Y, 0.0, -10.0, "f"],
				["fx", 0.9, "bubbles", {"from": "Mouth15", "color": "#ffb0c0", "amount": 8}]]},
			## The same with the head on its left.
			"rasp_left": {"length": 2.8, "hold": 1.1, "weight": 1.5, "do": [["grow", "m2", 0.0, 0.4, "f"], ["grow", "m2", 0.0, 0.1, "chew"],
				["turn", "h2", LIFT_2, 0.0, -26.0, "f"], ["turn", "h2", Y, 0.0, -14.0, "f"],
				["fx", 0.9, "bubbles", {"from": "Mouth08", "color": "#ffb0c0", "amount": 8}]]},
			## All three heads writhe round the braid one after another, tails lashing.
			"writhe": {"length": 3.4, "hold": 1.4, "weight": 1.5, "do": [["grow", "m1", 0.0, 0.15, "f"], ["grow", "m2", 0.0, 0.15, "f"], ["grow", "m3", 0.0, 0.15, "f"],
				["turn", "h1", Y, -18.0, 18.0, [[0.0, 0.0], [0.5, 1.0], [1.2, -1.0], [1.9, 1.0], [2.6, -1.0], [3.4, 0.0]]],
				["turn", "h2", Y, -18.0, 18.0, [[0.0, 0.0], [0.75, 1.0], [1.45, -1.0], [2.15, 1.0], [2.85, -0.6], [3.4, 0.0]]],
				["turn", "h3", Y, -18.0, 18.0, [[0.0, 0.0], [0.25, -0.5], [1.0, 1.0], [1.7, -1.0], [2.4, 1.0], [3.4, 0.0]]],
				["turn_each", "tails", Y, -14.0, 14.0, "wag"]]},
			## The heads lift and look about, tasting the water, suckers half open.
			"taste": {"length": 4.0, "hold": 2.2, "weight": 1.5, "do": [["grow", "m1", 0.0, 0.2, "f"], ["grow", "m2", 0.0, 0.2, "f"], ["grow", "m3", 0.0, 0.2, "f"],
				["gaze", "h1", 28.0, 14.0, "f", 3], ["gaze", "h2", 28.0, 14.0, "f", 3], ["gaze", "h3", 28.0, 14.0, "f", 2],
				["turn", "h3", LIFT_3, 0.0, -10.0, "f"], ["turn", "h2", LIFT_2, 0.0, -10.0, "f"]]},
		},
		"moves": {"Bite": "_lamprey_bite", "Drink": "_lamprey_drink"},
	},
	## The Drowned Miner: a heap of drowned gear held together by seep water. A drowned thing is
	## waterlogged: it sways slowly as if in a current, drips, sags; its lamp searches the dark; it
	## swings its pick down overhead like a miner at the face.
	"DROWNED_MINER": {
		"ambient": [{"kind": "drip", "at": "Pick02", "color": DROP}, {"kind": "drip", "at": "Head02", "color": DROP},
			{"kind": "drip", "at": "Lantern04", "color": DROP}],
		"groups": {
			"pick_arm": {"parts": ["ArmR", "Pick"], "at": "ArmR01"},
			"head": {"parts": ["Head", "Weed01-02"], "at": "Head01"},
			"wheel": {"parts": ["Wheel01-02", "Wheel04-05"]},
			"lantern": {"parts": ["Lantern"], "at": "Lantern01"},
			"mass": {"parts": ["Body", "Heart", "Head", "Weed", "ArmR", "Pick", "Lantern", "Box", "Crystal", "Wheel", "Flicker", "Orbit"], "at": Vector3(0, 0.1, 0)},
		},
		"idle_gestures": [["look", "head", 16.0, 6.0, 4.2, 1.6], ["sway", "pick_arm", X, 3.0, 0.55, 0.6],
			["sway", "mass", Z, 2.2, 0.5, 0.0], ["sway", "mass", X, 1.6, 0.37, 1.3]],
		"fidget_every": [5.5, 10.0],
		"fidgets": {
			## Lifts its lamp and sweeps the dark with it, turning a little to follow.
			"lamp_sweep": {"length": 4.4, "hold": 2.6, "weight": 2.0, "do": [["gaze", "head", 36.0, 14.0, "f", 3], ["turn", "mass", Y, 0.0, 6.0, "f"],
				["fx", 0.8, "flash_light", {"from": "Head04", "color": "#ffe8b0", "energy": 1.8}]]},
			## Shudders like a wet dog, water flung off it.
			"shake_off": {"length": 1.8, "hold": 0.6, "weight": 1.5, "do": [["turn", "head", Z, 0.0, 10.0, "shake"], ["turn", "mass", Z, 0.0, 5.0, "shake"],
				["tremble", "mass", 0.008, "f"],
				["fx", 0.5, "sparks", {"from": "Head02", "color": DROP, "amount": 22, "speed": 2.6, "life": 0.7, "size": 1.6}],
				["fx", 0.65, "sparks", {"from": "centre", "color": DROP, "amount": 24, "speed": 2.8, "life": 0.7, "size": 1.6}]]},
			## Sags under its own wet weight, head hanging and the pick drooping, water squeezed out
			## of it, and heaves itself up again.
			"sag": {"length": 3.4, "hold": 1.2, "weight": 1.5, "do": [["turn", "head", X, 0.0, 12.0, "f"], ["turn", "pick_arm", X, 0.0, 18.0, "f"],
				["grow", "mass", 0.0, Vector3(0.05, -0.09, 0.05), "f"],
				["fx", 0.7, "bubbles", {"from": "centre", "color": WATER, "amount": 14}],
				["fx", 1.0, "sparks", {"from": "feet", "off": Vector3(0, 0.3, 0.3), "color": DROP, "amount": 10, "speed": 1.2, "life": 0.5}]]},
		},
		"moves": {
			## Winds the pick far back over its head, leaning back, and swings it down hard into the
			## floor before it, leaning in.
			"Pick": [["turn", "pick_arm", X, -62.0, 66.0, "attack"], ["turn", "head", X, -8.0, 10.0, "attack"], ["turn", "mass", X, -6.0, 8.0, "attack"],
				["rear", 0.2, "attack"], ["fx", 0.3, "shock", {"from": "Pick03", "size": 0.8}],
				["fx", 0.3, "shards", {"from": "Pick03", "color": "#8a8a84", "amount": 10, "speed": 3.5}],
				["fx", 0.31, "sparks", {"from": "Pick03", "color": DROP, "amount": 16, "speed": 3.0}]],
			## Reaches out low and hauls back, sinking into its own water, the wheel spinning: a
			## whirlpool turns at its feet.
			"Pull Under": [["spin", "wheel", 3.0, "hold"], ["turn", "lantern", Z, -15.0, 15.0, "shake"], ["turn", "head", X, 0.0, 14.0, "hold"],
				["turn", "pick_arm", X, -20.0, 45.0, [[0.0, 0.0], [0.18, 1.0], [0.3, 1.0], [0.6, -1.0], [0.9, -0.6], [1.25, 0.0]]],
				["move", "mass", Vector3.ZERO, Vector3(0, -0.1, 0), "hold"],
				["fx", 0.1, "spiral", {"from": "centre", "color": DEEP}], ["fx", 0.2, "ring", {"color": DEEP, "radius": 1.6}],
				["fx", 0.38, "ring", {"color": DEEP, "radius": 1.1}],
				["fx", 0.3, "bubbles", {"from": "feet", "off": Vector3(0, 0.2, 0.5), "color": WATER, "amount": 20}]],
			## Slumps low and rises up tall again, water surging up through it.
			"Rise": [["turn", "head", X, 10.0, -16.0, "big"], ["turn", "pick_arm", X, 20.0, -30.0, "big"],
				["grow", "mass", Vector3(0.1, -0.25, 0.1), Vector3(-0.04, 0.1, -0.04), "big"], ["hop", Vector3(0, -0.12, 0), Vector3(0, 0.1, 0), "big"],
				["fx", 0.2, "splash", {"from": "feet", "color": WATER, "amount": 40}], ["fx", 0.28, "bubbles", {"from": "centre", "color": WATER, "amount": 24}],
				["fx", 0.3, "rise", {"from": "centre", "color": "#6fe3b0"}]],
		},
	},
	## The Lock-Keeper: a great sluice-snail, a lock machine on a snail's foot. A machine turns
	## its valve wheel, cranks its gate and clanks; a snail peers about on its eyestalks and pulls
	## them in. Its water drips from the gate; its Sluice and Flood strain the gate before it
	## bursts.
	"THE_LOCKKEEPER": {
		"mouth": "Head02",
		"ambient": [{"kind": "drip", "at": "Gate03", "color": DROP}, {"kind": "drip", "at": "Head02", "color": DROP}],
		"groups": {
			"gate": {"parts": ["Gate"], "at": "Gate01"},
			"spill": {"parts": ["Spill"]},
			"wheel": {"parts": ["Wheel01-04"]},
			"head": {"parts": ["Head", "Stalk", "Feeler"], "at": "Head01"},
			"stalk_r": {"parts": ["Stalk01-02"], "at": "Stalk01"},
			"stalk_l": {"parts": ["Stalk03-04"], "at": "Stalk03"},
			"eye_r": {"parts": ["Stalk02"], "at": Vector3(-0.44, 1.38, 1.52)},
			"eye_l": {"parts": ["Stalk04"], "at": Vector3(0.44, 1.38, 1.52)},
			"feeler_r": {"parts": ["Feeler01"], "at": "Feeler01"},
			"feeler_l": {"parts": ["Feeler02"], "at": "Feeler02"},
			"crystals": {"parts": ["Shell04-06"]},
			"shell": {"parts": ["Shell", "Gate", "Spill", "Wheel", "Weed"], "at": Vector3(0, 1.68, -0.42)},
			"spout": {"parts": ["Body01"], "at": Vector3(0, 1.05, 0.55)},
		},
		"idle_gestures": [["blink", "eye_r", Vector3(0.45, 0.45, 0.45), 5.0, 0.0], ["blink", "eye_l", Vector3(0.45, 0.45, 0.45), 5.0, 0.0],
			["sway", "Feeler01", Y, 14.0, 2.1, 0.0], ["sway", "Feeler02", Y, -14.0, 2.1, 1.2],
			["sway", "stalk_r", Y, 10.0, 0.7, 0.0], ["sway", "stalk_l", Y, 10.0, 0.7, 2.0], ["look", "head", 9.0, 4.0, 4.6, 1.6],
			["breathe", "shell", Vector3(0.012, 0.02, 0.012), 1.0, 0.0]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Cranks its valve wheel round hard, eyes turned up to watch it: the gate winches up a
			## little and drops back with a clank.
			"crank": {"length": 3.0, "hold": 0.8, "weight": 2.5, "do": [["spin", "wheel", 3.0, "f"],
				["turn", "gate", X, 0.0, -14.0, [[0.0, 0.0], [0.4, 0.0], [1.8, 1.0], [2.0, 1.0], [2.1, 0.0], [2.2, 0.1], [2.35, 0.0]]],
				["each", "spill", 0.0, Vector3(0.3, 0.6, 0.3), [[0.0, 0.0], [0.4, 0.0], [1.8, 1.0], [2.0, 1.0], [2.3, 0.0]]],
				["tremble", "shell", 0.012, [[0.0, 0.0], [2.05, 0.0], [2.1, 1.0], [2.5, 0.0]]],
				["turn", "stalk_r", X, 0.0, -20.0, "f"], ["turn", "stalk_l", X, 0.0, -20.0, "f"],
				["fx", 0.6, "puff", {"from": "Wheel05", "color": "#d8e8f0", "amount": 6, "size": 0.8, "rise": 0.8}],
				["fx", 2.08, "sparks", {"from": "Gate03", "color": "#ffd08a", "amount": 14, "speed": 2.5}],
				["fx", 2.1, "bubbles", {"from": "spout", "color": WATER, "amount": 12}]]},
			## Stretches its eyestalks up and peers about, each eye its own way.
			"peer": {"length": 4.4, "hold": 2.4, "weight": 2.0, "do": [["grow", "stalk_r", 0.0, Vector3(0, 0.3, 0), "f"], ["grow", "stalk_l", 0.0, Vector3(0, 0.3, 0), "f"],
				["gaze", "stalk_r", 35.0, 20.0, "f", 3], ["gaze", "stalk_l", 35.0, 20.0, "f", 3], ["turn", "head", X, 0.0, -8.0, "f"]]},
			## Pulls its eyes and feelers in and draws its head back under the gate, as a snail
			## does, then eases out again.
			"retract": {"length": 3.6, "hold": 1.2, "weight": 1.5, "do": [["grow", "stalk_r", 0.0, Vector3(-0.55, -0.55, -0.55), "f"],
				["grow", "stalk_l", 0.0, Vector3(-0.55, -0.55, -0.55), "f"], ["grow", "feeler_r", 0.0, -0.5, "f"], ["grow", "feeler_l", 0.0, -0.5, "f"],
				["move", "head", Vector3.ZERO, Vector3(0, -0.03, -0.16), "f"], ["move", "shell", Vector3.ZERO, Vector3(0, -0.05, 0), "f"],
				["fx", 0.9, "bubbles", {"from": "Head02", "color": WATER, "amount": 10}]]},
			## Opens its gate a crack and lets a gush run out over its foot, steam off the valve.
			"vent": {"length": 3.2, "hold": 1.0, "weight": 1.5, "do": [["turn", "gate", X, 0.0, -22.0, "f"], ["each", "spill", 0.0, Vector3(0.4, 0.8, 0.4), "f"],
				["turn", "head", X, 0.0, 6.0, "f"],
				["fx", 0.8, "jet", {"from": "spout", "color": WATER, "amount": 18, "speed": 2.0, "spread": 35.0, "life": 0.8}],
				["fx", 1.25, "jet", {"from": "spout", "color": WATER, "amount": 14, "speed": 1.8, "spread": 35.0, "life": 0.8}],
				["fx", 1.0, "bubbles", {"from": "spout", "color": WATER, "amount": 16}],
				["fx", 1.4, "puff", {"from": "Wheel05", "color": "#d8e8f0", "amount": 8, "size": 0.9, "rise": 0.8}]]},
			## Turns its whole bulk aside on its foot to show its shell and wheel, eyes still on the
			## party, and turns back.
			"turn_about": {"length": 4.4, "hold": 1.8, "weight": 2.0, "do": [["gaze", "stalk_r", 25.0, 10.0, "f", 2], ["gaze", "stalk_l", 25.0, 10.0, "f", 2],
				["turn", "head", Y, 0.0, -10.0, "f"], ["lean", Y, 0.0, 24.0, Vector3(0, 0, 0.3), "f"], ["spin", "wheel", 1.0, "f"],
				["fx", 1.4, "puff", {"from": "feet", "color": "#8a8478", "amount": 8, "size": 1.0, "rise": 0.2}]]},
			## Rocks its shell side to side and settles it with a clank.
			"rock": {"length": 2.6, "hold": 0.6, "weight": 1.0, "do": [["lean", Z, -3.0, 3.0, Vector3(0, 0, 0.3), [[0.0, 0.0], [0.5, 1.0], [1.0, -1.0], [1.4, 0.6], [1.7, 0.0]]],
				["tremble", "shell", 0.01, [[0.0, 0.0], [1.65, 0.0], [1.72, 1.0], [2.1, 0.0]]],
				["fx", 1.7, "puff", {"from": "feet", "color": "#8a8478", "amount": 10, "size": 1.2, "rise": 0.2}]]},
		},
		"moves": {
			## Shuts its gate tight while the wheel races, then flings it up and the sluice blasts out.
			"Sluice": [["turn", "gate", X, 6.0, -52.0, GATE_BURST], ["each", "spill", 0.0, Vector3(0.3, 0.45, 0.3), "hold"], ["spin", "wheel", 2.0, "hold"],
				["turn", "stalk_r", X, 0.0, 30.0, "hold"], ["turn", "stalk_l", X, 0.0, 30.0, "hold"], ["turn", "head", X, -10.0, 4.0, "attack"],
				["lean", X, -3.0, 2.0, Vector3.ZERO, "attack"],
				["fx", 0.24, "breath", {"from": "spout", "kind": "water", "color": WATER, "seconds": 0.5, "size": 1.3}],
				["fx", 0.3, "splash", {"from": "spout", "color": WATER, "amount": 50, "speed": 5.0}]],
			## Everything it holds back: the gate flung all the way up and a wall of water poured out.
			"Flood": [["turn", "gate", X, 8.0, -64.0, GATE_BURST], ["each", "spill", 0.0, Vector3(0.4, 0.6, 0.4), "hold"], ["spin", "wheel", 3.0, "hold"],
				["turn", "stalk_r", X, 0.0, 35.0, "hold"], ["turn", "stalk_l", X, 0.0, 35.0, "hold"], ["turn", "head", X, -12.0, 6.0, "attack"],
				["lean", X, -4.0, 3.0, Vector3.ZERO, "attack"],
				["fx", 0.22, "breath", {"from": "spout", "kind": "water", "color": WATER, "seconds": 0.7, "size": 1.8}],
				["fx", 0.3, "splash", {"from": "spout", "color": WATER, "amount": 70, "speed": 6.0}], ["fx", 0.35, "ring", {"color": DEEP, "radius": 4.0}],
				["fx", 0.4, "splash", {"from": "feet", "off": Vector3(0, 0.2, 1.2), "color": WATER, "amount": 40, "speed": 3.0}]],
			## Eyes folded back, it butts the party with its head, the shell rocking behind it.
			"Wrench": [["turn", "stalk_r", X, 0.0, 30.0, "attack"], ["turn", "stalk_l", X, 0.0, 30.0, "attack"], ["turn", "head", X, -22.0, 26.0, "attack"],
				["move", "head", Vector3(0, 0.05, -0.12), Vector3(0, -0.03, 0.28), "attack"], ["turn", "shell", X, -5.0, 5.0, "attack"], ["spin", "wheel", 1.0, "attack"],
				["rear", 0.3, "attack"], ["fx", 0.3, "shock", {"ahead": 1.6}], ["fx", 0.3, "sparks", {"from": "Head02", "color": "#ffd08a", "amount": 18, "speed": 3.0}]],
			## Turns its valve wheel hard, eyes up to watch it: the gate winches up a notch and clanks.
			"Turn the Wheel": [["spin", "wheel", 4.0, "hold"], ["turn", "stalk_r", X, 0.0, -30.0, "hold"], ["turn", "stalk_l", X, 0.0, -30.0, "hold"],
				["turn", "head", X, 0.0, -6.0, "hold"], ["tremble", "shell", 0.01, "hold"],
				["turn", "gate", X, 0.0, -10.0, [[0.0, 0.0], [0.3, 0.0], [0.6, 1.0], [0.7, 1.0], [0.78, 0.0], [1.2, 0.0]]],
				["fx", 0.3, "sparks", {"from": "Wheel05", "color": "#ffd08a", "amount": 22, "speed": 3.0}],
				["fx", 0.4, "puff", {"from": "Wheel05", "color": "#d8e8f0", "amount": 8, "size": 0.9, "rise": 0.8}],
				["fx", 0.78, "sparks", {"from": "Gate03", "color": "#ffd08a", "amount": 14, "speed": 2.5}]],
			## Lifts its gate and slams it shut: the die is locked in.
			"Lock": [["turn", "gate", X, 4.0, -18.0, [[0.0, 0.0], [0.15, 1.0], [0.24, 1.0], [0.3, -0.3], [0.36, 0.0], [0.8, 0.0]]],
				["tremble", "shell", 0.014, [[0.0, 0.0], [0.28, 0.0], [0.31, 1.0], [0.6, 0.0]]],
				["turn", "stalk_r", X, 0.0, 25.0, "hold"], ["turn", "stalk_l", X, 0.0, 25.0, "hold"], ["spin", "wheel", -1.0, "attack"],
				["fx", 0.3, "sparks", {"from": "Gate03", "color": "#ffd08a", "amount": 18, "speed": 3.0}],
				["fx", 0.3, "shards", {"from": "Gate03", "color": "#9a9aa4", "amount": 6, "speed": 2.0}]],
			## Pulls in its eyes and head and hunkers its shell down on its foot.
			"Brace": [["grow", "stalk_r", 0.0, Vector3(-0.5, -0.5, -0.5), "hold"], ["grow", "stalk_l", 0.0, Vector3(-0.5, -0.5, -0.5), "hold"],
				["move", "head", Vector3.ZERO, Vector3(0, -0.03, -0.14), "hold"], ["move", "shell", Vector3.ZERO, Vector3(0, -0.1, 0), "hold"],
				["fx", 0.3, "puff", {"from": "feet", "color": "#8a8478", "amount": 10, "size": 1.3, "rise": 0.2}]],
			## Presses its gate shut against the water and bristles the crystals on its shell.
			"Dam": [["turn", "gate", X, 0.0, 6.0, "hold"], ["each", "crystals", 0.0, 0.45, "hold"], ["grow", "stalk_r", 0.0, Vector3(-0.4, -0.4, -0.4), "hold"],
				["grow", "stalk_l", 0.0, Vector3(-0.4, -0.4, -0.4), "hold"], ["move", "shell", Vector3.ZERO, Vector3(0, -0.06, 0), "hold"],
				["fx", 0.3, "shards", {"from": "Shell04", "color": "#9fd8ff", "amount": 8, "speed": 2.0}],
				["fx", 0.3, "bubbles", {"from": "spout", "color": WATER, "amount": 14}]],
			"guard": [["grow", "stalk_r", 0.0, Vector3(-0.5, -0.5, -0.5), "hold"], ["grow", "stalk_l", 0.0, Vector3(-0.5, -0.5, -0.5), "hold"],
				["move", "head", Vector3.ZERO, Vector3(0, -0.03, -0.14), "hold"], ["move", "shell", Vector3.ZERO, Vector3(0, -0.1, 0), "hold"]],
		},
		"heavy": {
			## The Sluice held: the gate strains shut against the water, spraying round its edges,
			## the shell heaving back, until it bursts.
			"Sluice": {"at": "spout",
				"pose": [["tremble", "gate", 0.012, "h"], ["each", "spill", 0.0, Vector3(0.2, 0.3, 0.2), "h"], ["turn", "shell", X, 0.0, -4.0, "h"]],
				"charge": [["jet", {"from": "Spill01", "color": DROP, "amount": 14, "speed": 2.5, "spread": 25.0}],
					["jet", {"from": "Spill02", "color": DROP, "amount": 14, "speed": 2.5, "spread": 25.0}],
					["bubbles", {"from": "spout", "color": WATER, "amount": 18}], ["charge_glow", {"from": "Gate04", "color": WATER, "seconds": 0.5}],
					["charge_dust", {"seconds": 0.45}]],
				"impact": [["splash", {"from": "spout", "color": WATER, "amount": 60, "speed": 6.5}], ["ring", {"color": DEEP, "radius": 3.2}]]},
			## The Flood held: the wheel screaming round, the gate bulging, water jetting from every
			## seam and the whole shell reared back; then everything at once.
			"Flood": {"at": "spout",
				"pose": [["tremble", "gate", 0.016, "h"], ["each", "spill", 0.0, Vector3(0.25, 0.35, 0.25), "h"], ["turn", "shell", X, 0.0, -6.0, "h"],
					["move", "head", Vector3.ZERO, Vector3(0, 0.0, -0.08), "h"]],
				"charge": [["jet", {"from": "Spill01", "color": DROP, "amount": 18, "speed": 3.0, "spread": 25.0}],
					["jet", {"from": "Spill02", "color": DROP, "amount": 18, "speed": 3.0, "spread": 25.0}],
					["puff", {"from": "Wheel05", "color": "#d8e8f0", "amount": 10, "size": 1.0, "rise": 1.0}],
					["bubbles", {"from": "spout", "color": WATER, "amount": 24}], ["spiral", {"from": "spout", "color": WATER, "amount": 30}],
					["charge_glow", {"from": "Gate04", "color": WATER, "seconds": 0.5}], ["charge_dust", {"seconds": 0.45}]],
				"impact": [["splash", {"from": "spout", "color": WATER, "amount": 80, "speed": 7.0}], ["ring", {"color": DEEP, "radius": 4.5}],
					["splash", {"from": "feet", "off": Vector3(0, 0.2, 1.6), "color": WATER, "amount": 50, "speed": 4.0}]]},
		},
	},
	## The Drowned Choir: drowned heads on long necks singing out of a dark pool. A choir sways
	## and keeps time, its mouths humming open and shut; heads turn to one another, one bows like a
	## conductor, the young ones duck under; a song rolls out of them in rings of sound.
	"THE_DROWNED_CHOIR": {
		## Its one curse (Lament) is sung by the young heads: its hex is lit at the front one.
		"mouth": "Mouth07",
		"idle": "_idle_choir",
		"ambient": [{"kind": "drip", "at": "Head04", "color": DROP}, {"kind": "drip", "at": "Head01", "color": DROP},
			{"kind": "drip", "at": "Head07", "color": DROP}],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## A phrase hummed down the line, left to right, each mouth opening as the last closes.
			"hum": {"length": 3.0, "hold": 0.0, "weight": 2.5, "do": [["call", "_choir_hum"],
				["fx", 0.75, "ripple", {"from": "Mouth01", "color": WATER, "radius": 0.7, "size": 0.7}],
				["fx", 1.03, "ripple", {"from": "Mouth03", "color": WATER, "radius": 0.7, "size": 0.7}],
				["fx", 1.31, "ripple", {"from": "Mouth05", "color": WATER, "radius": 0.7, "size": 0.7}],
				["fx", 1.59, "ripple", {"from": "Mouth07", "color": WATER, "radius": 0.6, "size": 0.7}],
				["fx", 1.87, "ripple", {"from": "Mouth09", "color": WATER, "radius": 0.6, "size": 0.7}]]},
			## The two tall outer singers turn to the middle one and lean in, harmonising.
			"turn_to": {"length": 3.6, "hold": 1.6, "weight": 1.5, "do": [["call", "_choir_turn"],
				["fx", 1.3, "ripple", {"from": "Mouth03", "color": WATER, "radius": 0.9, "size": 0.7}]]},
			## The tall middle singer bows low over the pool like a conductor; the others lean back.
			"bow": {"length": 3.4, "hold": 1.2, "weight": 1.5, "do": [["call", "_choir_bow"],
				["fx", 1.2, "bubbles", {"from": "feet", "off": Vector3(0, 0.1, 0.2), "color": WATER, "amount": 12}]]},
			## The young front-left singer shakes the water off its head.
			"shake": {"length": 1.6, "hold": 0.6, "weight": 1.0, "do": [["call", "_choir_shake"],
				["fx", 0.45, "sparks", {"from": "Head10", "color": DROP, "amount": 12, "speed": 2.0, "life": 0.6}],
				["fx", 0.85, "sparks", {"from": "Head10", "color": DROP, "amount": 10, "speed": 2.0, "life": 0.6}]]},
			## The two young singers duck under the pool, blowing bubbles, and come up again.
			"sink": {"length": 3.6, "hold": 1.0, "weight": 1.0, "do": [["call", "_choir_sink"],
				["fx", 0.7, "bubbles", {"from": "feet", "off": Vector3(-0.3, 0.1, 0.85), "color": WATER, "amount": 12}],
				["fx", 1.4, "bubbles", {"from": "feet", "off": Vector3(0.45, 0.1, 0.8), "color": WATER, "amount": 12}],
				["fx", 2.5, "splash", {"from": "feet", "off": Vector3(0.1, 0.2, 0.85), "color": WATER, "amount": 16, "speed": 2.0}]]},
		},
		"moves": {"Dirge": "_choir_sing", "Requiem": "_choir_sing", "Requiem Chorus": "_choir_sing", "Lament": "_choir_sing", "Another Voice": "_choir_sing"},
		"heavy": {
			## The chorus held: every head drawn back with its mouth wide, the pool boiling and the
			## song gathering at the tallest mouth, then all of it at once.
			"Requiem Chorus": {"at": "Mouth03",
				"charge": [["spiral", {"from": "Mouth03", "color": "#c8f0ff", "amount": 30}], ["spiral", {"from": "Mouth01", "color": "#c8f0ff", "amount": 16}],
					["spiral", {"from": "Mouth05", "color": "#c8f0ff", "amount": 16}], ["charge_glow", {"from": "Mouth03", "color": "#c8f0ff", "seconds": 0.5}],
					["bubbles", {"from": "feet", "color": WATER, "amount": 24}]],
				"impact": [["ripple", {"from": "Mouth03", "color": "#c8f0ff", "radius": 2.2}], ["ring", {"color": "#c8f0ff", "radius": 3.5}],
					["flash_light", {"from": "Mouth03", "color": "#c8f0ff", "energy": 4.0}]]},
		},
	},
	## The Undertow: a sea serpent of cut boulders, one coil on the water and its front reared up
	## over the party. A serpent's neck sways in a slow S and draws itself up and down; it rears to
	## look about, bares its teeth, chomps, coils to look back at itself; its fluke slaps the
	## water; it surfaces and slams down hard.
	"THE_UNDERTOW": {
		"mouth": "Mouth01",
		"idle": "_idle_undertow",
		"ambient": [{"kind": "drip", "at": "Jaw03", "color": DROP}, {"kind": "drip", "at": "Head04", "color": DROP}],
		"groups": {
			"jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"head": {"parts": ["Head", "Jaw", "Mouth"], "at": "Head01"},
			"neck": {"chain": [["Neck02"], ["Neck01", "Fin02"], ["Neck04", "FinR01", "FinL01", "Spot05"], ["Neck03", "Fin03"], ["Neck06"], ["Neck05", "Fin04"]],
				"riders": ["Head", "Jaw", "Mouth"]},
			"fluke": {"parts": ["Tail02", "Tail01"], "at": "Tail02"},
		},
		"idle_gestures": [["sway", "fluke", Y, 10.0, 1.1, 0.0]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Draws itself up tall and looks round the room, then settles back over the party.
			"rise_look": {"length": 5.0, "hold": 2.8, "weight": 2.5, "idle": 0.0, "do": [["gaze", "head", 34.0, 12.0, "f", 3],
				["curl", "neck", X, 0.0, -14.0, "f", "tip"], ["turn", "fluke", Y, 0.0, 14.0, "f"],
				["fx", 0.8, "bubbles", {"from": "feet", "color": WATER, "amount": 10}]]},
			## Bares its teeth: the jaw drawn slowly open and held, the head low and shivering.
			"bare": {"length": 2.6, "hold": 1.0, "weight": 2.0, "idle": 0.0, "do": [["turn", "jaw", X, 0.0, 34.0, "bare"], ["tremble", "jaw", 0.006, "bare"],
				["turn", "head", X, 0.0, 10.0, "bare"], ["curl", "neck", X, 0.0, 6.0, "bare", "tip"],
				["fx", 0.5, "bubbles", {"from": "Mouth01", "color": WATER, "amount": 10}],
				["fx", 1.2, "sparks", {"from": "Mouth01", "color": DROP, "amount": 10, "speed": 1.2, "life": 0.6}]]},
			## Chomps its jaws twice at nothing, water spraying from its teeth.
			"chomp": {"length": 1.6, "hold": 0.3, "weight": 2.0, "idle": 0.0, "do": [["turn", "jaw", X, -4.0, 40.0, "chomp"], ["turn", "head", X, 8.0, -10.0, "chomp"],
				["curl", "neck", X, 4.0, -5.0, "chomp", "tip"],
				["fx", 0.24, "sparks", {"from": "Mouth01", "color": DROP, "amount": 12, "speed": 2.0, "life": 0.5}],
				["fx", 0.56, "sparks", {"from": "Mouth01", "color": DROP, "amount": 12, "speed": 2.0, "life": 0.5}]]},
			## Its fluke rears out of the water and slaps it down.
			"slap": {"length": 2.0, "hold": 0.2, "weight": 1.5, "do": [["turn", "fluke", X, -30.0, 55.0, [[0.0, 0.0], [0.5, -1.0], [0.62, -1.0], [0.75, 1.0], [0.9, 0.8], [1.6, 0.0]]],
				["fx", 0.76, "splash", {"from": "Tail02", "color": WATER, "amount": 30, "speed": 3.0}],
				["fx", 0.8, "bubbles", {"from": "Tail02", "color": WATER, "amount": 10}]]},
			## Leans its neck over and turns its head down to look back along its own coil.
			"coil": {"length": 4.0, "hold": 1.6, "weight": 1.5, "idle": 0.0, "do": [["turn", "head", X, 0.0, 22.0, "f"], ["turn", "head", Y, 0.0, -35.0, "f"],
				["curl", "neck", Z, 0.0, 16.0, "f", "tip"], ["turn", "fluke", Y, 0.0, -20.0, "f"]]},
		},
		"moves": {
			"bite": [["turn", "jaw", X, 42.0, -4.0, "snap"], ["turn", "head", X, -18.0, 22.0, "attack"], ["curl", "neck", X, -14.0, 22.0, "attack", "tip"],
				["fx", 0.29, "sparks", {"from": "Mouth01", "color": DROP, "amount": 12, "speed": 2.5}]],
			"Crunch": [["turn", "jaw", X, 42.0, -4.0, "snap2"], ["turn", "head", X, -18.0, 22.0, "twice"], ["curl", "neck", X, -14.0, 22.0, "twice", "tip"],
				["fx", 0.29, "shards", {"from": "Mouth01", "color": "#c8b8a8", "amount": 8, "speed": 3.0}],
				["fx", 0.55, "shards", {"from": "Mouth01", "color": "#c8b8a8", "amount": 8, "speed": 3.0}]],
			## Its fluke lashes one way and the other, the water thrown up with each.
			"Thrash": [["turn", "fluke", Y, -40.0, 40.0, "twice"], ["turn", "fluke", X, 0.0, -20.0, "lift"], ["curl", "neck", Z, -4.0, 4.0, "twice", "tip"],
				["fx", 0.3, "splash", {"from": "Tail02", "color": WATER, "amount": 30}], ["fx", 0.54, "splash", {"from": "Tail02", "color": WATER, "amount": 30}]],
			## Rears high and brings its head down on the floor before the party like a falling tower.
			"Slam": [["turn", "jaw", X, 0.0, 20.0, "big"], ["turn", "head", X, -15.0, 25.0, "big"], ["curl", "neck", X, -28.0, 38.0, "big", "tip"],
				["fx", 0.3, "splash", {"from": "Mouth01", "color": WATER, "amount": 60, "speed": 5.0}], ["fx", 0.3, "shock", {"ahead": 1.5, "size": 1.4}]],
			## Plunges head first and is gone, the fluke going up last.
			"Dive": [["turn", "head", X, 0.0, 30.0, "hold"], ["curl", "neck", X, -10.0, 30.0, "hold", "tip"],
				["turn", "fluke", X, 0.0, -40.0, [[0.0, 0.0], [0.3, 0.0], [0.6, 1.0], [1.2, 0.0]]],
				["fx", 0.35, "splash", {"from": "centre", "color": WATER, "amount": 60}], ["fx", 0.45, "bubbles", {"from": "feet", "color": WATER, "amount": 20}],
				["fx", 0.6, "splash", {"from": "Tail02", "color": WATER, "amount": 20, "speed": 2.0}]],
			## Bursts up out of the water with its jaws open and comes down on the party.
			"Surface": [["turn", "jaw", X, 35.0, -4.0, "snap"], ["turn", "head", X, -25.0, 20.0, "big"], ["curl", "neck", X, -30.0, 22.0, "big", "tip"],
				["fx", 0.05, "splash", {"from": "feet", "color": WATER, "amount": 70, "speed": 6.0}],
				["fx", 0.3, "splash", {"from": "Mouth01", "color": WATER, "amount": 30, "speed": 3.0}]],
			"erupt": [["turn", "jaw", X, 35.0, -4.0, "snap"], ["turn", "head", X, -25.0, 20.0, "big"], ["curl", "neck", X, -30.0, 22.0, "big", "tip"],
				["fx", 0.05, "splash", {"from": "feet", "color": WATER, "amount": 70, "speed": 6.0}],
				["fx", 0.3, "splash", {"from": "Mouth01", "color": WATER, "amount": 30, "speed": 3.0}]],
			## Rears, lunges down at the party and drags back and under: a whirlpool turns before it.
			"Drag Under": [["turn", "jaw", X, 30.0, -4.0, [[0.0, 0.0], [0.15, -1.0], [0.3, 1.0], [0.42, 1.0], [0.7, 0.3], [1.2, 0.0]]],
				["turn", "head", X, -10.0, 24.0, [[0.0, 0.0], [0.15, -1.0], [0.3, 1.0], [0.42, 1.0], [0.7, -0.6], [1.2, 0.0]]],
				["curl", "neck", X, -12.0, 26.0, [[0.0, 0.0], [0.15, -1.0], [0.3, 1.0], [0.42, 1.0], [0.7, -0.6], [1.2, 0.0]], "tip"],
				["fx", 0.45, "spiral", {"from": "feet", "off": Vector3(0, 0.3, 1.0), "color": DEEP, "amount": 30}],
				["fx", 0.5, "ring", {"color": DEEP, "radius": 2.5}], ["fx", 0.55, "bubbles", {"from": "feet", "color": WATER, "amount": 18}]],
			## Snatches with its jaws and yanks its head back with what it took.
			"Drag Down": [["turn", "jaw", X, 36.0, -4.0, "snap"],
				["turn", "head", X, -14.0, 24.0, [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.38, 1.0], [0.6, -0.5], [1.0, 0.0]]],
				["curl", "neck", X, -10.0, 22.0, [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.38, 1.0], [0.6, -0.5], [1.0, 0.0]], "tip"],
				["fx", 0.5, "bubbles", {"from": "Mouth01", "color": WATER, "amount": 12}]],
			"cast": [["turn", "jaw", X, 0.0, 30.0, "hold"], ["turn", "head", X, -10.0, 20.0, "attack"], ["curl", "neck", X, -8.0, 15.0, "attack", "tip"],
				["fx", 0.18, "spiral", {"from": "Mouth01", "color": DEEP}], ["fx", 0.26, "breath", {"kind": "water", "color": WATER, "seconds": 0.4}]],
			## Throws its head back and calls, slapping the water with its fluke: rings roll out.
			"Call the Eels": [["turn", "jaw", X, 0.0, 35.0, "hold"], ["turn", "head", X, 0.0, -30.0, "hold"], ["curl", "neck", X, 0.0, -12.0, "hold", "tip"],
				["turn", "fluke", X, -25.0, 45.0, [[0.0, 0.0], [0.25, -1.0], [0.36, 1.0], [0.5, 0.6], [1.0, 0.0]]],
				["fx", 0.3, "ripple", {"from": "Mouth01", "color": DEEP, "radius": 2.0}], ["fx", 0.45, "ripple", {"from": "Mouth01", "color": DEEP, "radius": 3.0}],
				["fx", 0.36, "splash", {"from": "Tail02", "color": WATER, "amount": 24, "speed": 2.5}],
				["fx", 0.3, "ring", {"color": DEEP, "radius": 3.0}], ["fx", 0.45, "ring", {"color": DEEP, "radius": 4.0}]],
		},
		"heavy": {
			## Surfacing held: the water boiling round it, the jaws gaping and the head thrown back,
			## before it comes down.
			"Surface": {"at": "Mouth01",
				"do": [["turn", "jaw", X, 0.0, 10.0, "h"], ["turn", "jaw", X, 35.0, -4.0, "snap"], ["turn", "head", X, 0.0, -8.0, "h"], ["turn", "head", X, -25.0, 20.0, "big"],
					["curl", "neck", X, -30.0, 22.0, "big", "tip"],
					["fx", 0.05, "splash", {"from": "feet", "color": WATER, "amount": 70, "speed": 6.0}],
					["fx", 0.3, "splash", {"from": "Mouth01", "color": WATER, "amount": 30, "speed": 3.0}]],
				"charge": [["splash", {"from": "feet", "off": Vector3(0, 0.3, 0.4), "color": WATER, "amount": 30, "speed": 3.0}],
					["bubbles", {"from": "feet", "color": WATER, "amount": 26}], ["charge_glow", {"from": "Mouth01", "color": DROP, "seconds": 0.5}]],
				"impact": [["splash", {"from": "Mouth01", "color": WATER, "amount": 50, "speed": 5.0}], ["ring", {"color": DEEP, "radius": 4.0}],
					["shock", {"ahead": 1.4, "size": 1.4}]]},
			## The Crunch held: jaws wide, every tooth bared, the head drawn back on its neck.
			"Crunch": {"at": "Mouth01",
				"do": [["turn", "jaw", X, 0.0, 8.0, "h"], ["turn", "jaw", X, 42.0, -4.0, "snap2"], ["turn", "head", X, 0.0, -8.0, "h"], ["turn", "head", X, -18.0, 22.0, "twice"],
					["curl", "neck", X, -14.0, 22.0, "twice", "tip"],
					["fx", 0.29, "shards", {"from": "Mouth01", "color": "#c8b8a8", "amount": 8, "speed": 3.0}],
					["fx", 0.55, "shards", {"from": "Mouth01", "color": "#c8b8a8", "amount": 8, "speed": 3.0}]],
				"charge": [["charge_glow", {"from": "Mouth01", "color": DROP, "seconds": 0.5}], ["bubbles", {"from": "Mouth01", "color": WATER, "amount": 14}],
					["spiral", {"from": "Mouth01", "color": WATER, "amount": 24}],
					["splash", {"from": "feet", "off": Vector3(0, 0.3, 0.8), "color": WATER, "amount": 24, "speed": 2.0}]],
				"impact": [["shards", {"from": "Mouth01", "color": "#c8b8a8", "amount": 14, "speed": 5.0}], ["sparks", {"from": "Mouth01", "color": DROP, "amount": 24, "speed": 4.0}]]},
			## The Slam held: reared all the way up with its jaws open, then down like a falling tower.
			"Slam": {"at": "Mouth01",
				"do": [["turn", "jaw", X, 0.0, 24.0, "h"], ["turn", "jaw", X, 0.0, 20.0, "big"], ["turn", "head", X, 0.0, -10.0, "h"], ["turn", "head", X, -15.0, 25.0, "big"],
					["curl", "neck", X, -28.0, 38.0, "big", "tip"],
					["fx", 0.3, "sparks", {"from": "Mouth01", "color": DROP, "amount": 30, "speed": 4.0, "life": 0.7}], ["fx", 0.3, "shock", {"ahead": 1.5, "size": 1.4}]],
				"charge": [["spiral", {"from": "Mouth01", "color": WATER, "amount": 28}], ["bubbles", {"from": "feet", "color": WATER, "amount": 24}],
					["charge_glow", {"from": "Mouth01", "color": DROP, "seconds": 0.5}]],
				"impact": [["shock", {"ahead": 1.6, "size": 1.8}], ["splash", {"from": "feet", "off": Vector3(0, 0.2, 1.6), "color": WATER, "amount": 70, "speed": 6.0}],
					["shards", {"from": "feet", "off": Vector3(0, 0.2, 1.6), "color": "#a89888", "amount": 16, "speed": 5.0}], ["dust", {"amount": 60}]]},
		},
	},
	## The Cave Crayfish: a pale crayfish. A crayfish waves its antennae, flexes and clacks its
	## claws, flicks its tail to dart backward and scuttles on its legs; it rears its claws to
	## threaten, pinches hard and hunkers behind them in its shell.
	"CAVE_CRAYFISH": {
		"groups": {
			"claw_l": {"parts": ["Swing03", "Cone01"], "at": "Swing03"}, "claw_r": {"parts": ["Swing04", "Cone02"], "at": "Swing04"},
			"tail": {"parts": ["Swing01", "Swing02"], "at": "Swing01"}, "fan": {"parts": ["Swing02"], "at": "Swing02"},
			"feeler_l": {"parts": ["Swing05"], "at": "Swing05"}, "feeler_r": {"parts": ["Swing06"], "at": "Swing06"},
			"legs": {"parts": ["Cylinder"], "at": Vector3(0, 0.14, -0.05)},
		},
		"idle_gestures": [["sway", "feeler_l", Y, 12.0, 0.9, 0.0], ["sway", "feeler_r", Y, -12.0, 0.8, 1.3],
			["sway", "feeler_l", X, 5.0, 1.7, 0.4], ["sway", "feeler_r", X, 5.0, 1.5, 2.1],
			["flex", "claw_l", Y, 12.0, 3.4, 0.0], ["flex", "claw_r", Y, -12.0, 3.9, 1.6], ["sway", "tail", X, 3.0, 1.0, 0.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Raises both claws and clacks them together twice.
			"clack": {"length": 2.0, "hold": 0.8, "weight": 2.0, "do": [
				["turn", "claw_l", Y, 18.0, -16.0, [[0.0, 0.0], [0.4, -0.6], [0.62, -0.6], [0.7, 1.0], [0.78, 0.2], [1.0, -0.6], [1.08, 1.0], [1.16, 0.2], [1.6, 0.0]]],
				["turn", "claw_r", Y, -18.0, 16.0, [[0.0, 0.0], [0.4, -0.6], [0.62, -0.6], [0.7, 1.0], [0.78, 0.2], [1.0, -0.6], [1.08, 1.0], [1.16, 0.2], [1.6, 0.0]]],
				["turn", "claw_l", X, 0.0, -22.0, "f"], ["turn", "claw_r", X, 0.0, -22.0, "f"],
				["fx", 0.7, "sparks", {"from": "Cone01", "color": "#e8f4ff", "amount": 6, "speed": 1.5, "life": 0.3}],
				["fx", 0.7, "sparks", {"from": "Cone02", "color": "#e8f4ff", "amount": 6, "speed": 1.5, "life": 0.3}],
				["fx", 1.08, "sparks", {"from": "Cone01", "color": "#e8f4ff", "amount": 6, "speed": 1.5, "life": 0.3}],
				["fx", 1.08, "sparks", {"from": "Cone02", "color": "#e8f4ff", "amount": 6, "speed": 1.5, "life": 0.3}]]},
			## Flicks its tail under and darts back, then creeps forward again.
			"flick": {"length": 1.6, "hold": 0.2, "weight": 1.5, "do": [["turn", "fan", X, 0.0, -30.0, [[0.0, 0.0], [0.1, 1.0], [0.3, 1.0], [0.7, 0.0]]],
				["turn", "tail", X, 0.0, -18.0, [[0.0, 0.0], [0.1, 1.0], [0.3, 1.0], [0.7, 0.0]]],
				["hop", Vector3.ZERO, Vector3(0, 0.04, -0.16), [[0.0, 0.0], [0.12, 1.0], [0.4, 1.0], [1.5, 0.0]]],
				["fx", 0.12, "puff", {"from": "Swing02", "color": "#8a8478", "amount": 8, "size": 0.7, "rise": 0.3}]]},
			## Sweeps its antennae out wide and forward, legs paddling as it shuffles aside and back.
			"probe": {"length": 3.0, "hold": 1.2, "weight": 1.5, "do": [["turn", "feeler_l", Y, 0.0, 22.0, "f"], ["turn", "feeler_r", Y, 0.0, -22.0, "f"],
				["turn", "feeler_l", X, 0.0, -10.0, "f"], ["turn", "feeler_r", X, 0.0, -10.0, "f"], ["wave_each", "legs", "out", 10.0, 9.0, 1.1, "f"],
				["hop", Vector3.ZERO, Vector3(0.1, 0, 0.04), "f"]]},
		},
		"moves": {
			## Rears its right claw up and brings it down across the party.
			"Claw": [["turn", "claw_r", X, -40.0, 12.0, "attack"], ["turn", "claw_r", Y, 0.0, -18.0, "attack"], ["rear", 0.4, "attack"],
				["fx", 0.29, "swipe", {"about": "claw_r", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 0.6, "sweep": 110.0}],
				["fx", 0.3, "shock", {"ahead": 0.9, "size": 0.6}]],
			## Both claws thrown wide and raised, the tail up, and snapped shut on the party.
			"Pinch": [["turn", "claw_l", Y, 22.0, -26.0, "snap"], ["turn", "claw_r", Y, -22.0, 26.0, "snap"], ["turn", "claw_l", X, -24.0, 6.0, "snap"],
				["turn", "claw_r", X, -24.0, 6.0, "snap"], ["turn", "tail", X, 12.0, -6.0, "snap"], ["rear", 0.35, "attack"],
				["fx", 0.29, "sparks", {"from": "Cone01", "color": "#e8f4ff", "amount": 12, "speed": 2.5}],
				["fx", 0.29, "sparks", {"from": "Cone02", "color": "#e8f4ff", "amount": 12, "speed": 2.5}], ["fx", 0.3, "shock", {"ahead": 1.0, "size": 0.7}]],
			## Reaches out with its left claw, clamps and holds on, straining.
			"Grip": [["turn", "claw_l", X, -30.0, 10.0, [[0.0, 0.0], [0.22, -1.0], [0.3, 1.0], [0.85, 1.0], [1.2, 0.0]]],
				["turn", "claw_l", Y, 15.0, -22.0, [[0.0, 0.0], [0.22, -1.0], [0.3, 1.0], [0.85, 1.0], [1.2, 0.0]]], ["rear", 0.3, "attack"],
				["tremble", "claw_l", 0.008, [[0.0, 0.0], [0.3, 0.0], [0.36, 1.0], [0.85, 1.0], [1.1, 0.0]]],
				["fx", 0.3, "sparks", {"from": "Cone01", "color": "#e8f4ff", "amount": 8, "speed": 2.0}]],
			## Tucks its tail under, folds its claws before its face and hunkers down in its shell.
			"Shell": [["turn", "fan", X, 0.0, -20.0, "hold"], ["turn", "tail", X, 0.0, -24.0, "hold"], ["turn", "claw_l", Y, 0.0, -24.0, "hold"],
				["turn", "claw_r", Y, 0.0, 24.0, "hold"], ["turn", "claw_l", X, 0.0, -10.0, "hold"], ["turn", "claw_r", X, 0.0, -10.0, "hold"],
				["turn", "feeler_l", Y, 0.0, -18.0, "hold"], ["turn", "feeler_r", Y, 0.0, 18.0, "hold"], ["hop", Vector3.ZERO, Vector3(0, -0.06, 0), "hold"],
				["fx", 0.3, "puff", {"from": "feet", "color": "#8a8478", "amount": 10, "size": 1.2, "rise": 0.2}]],
		},
		"heavy": {
			## Its Pinch held: claws flung wider and higher, tail cocked over its back, body lifted on
			## its legs, glinting at the claw tips; then they slam shut.
			"Pinch": {"at": "Cone01",
				"pose": [["turn", "claw_l", Y, 0.0, 10.0, "h"], ["turn", "claw_r", Y, 0.0, -10.0, "h"], ["turn", "tail", X, 0.0, 14.0, "h"],
					["hop", Vector3.ZERO, Vector3(0, 0.05, -0.05), "h"]],
				"charge": [["charge_glow", {"from": "Cone01", "color": "#e8f4ff", "seconds": 0.5}], ["charge_glow", {"from": "Cone02", "color": "#e8f4ff", "seconds": 0.5}],
					["charge_dust", {"seconds": 0.45}]],
				"impact": [["shards", {"from": "Cone01", "color": "#bcd8f0", "amount": 10, "speed": 4.0}], ["shards", {"from": "Cone02", "color": "#bcd8f0", "amount": 10, "speed": 4.0}],
					["shock", {"ahead": 1.1, "size": 1.1}]]},
		},
	},
}

# --- the moves and idles no table says ---------------------------------------------------------

# --- the Seep Eel: swims where it hangs, sparks crawling on it ---------------------------------

## Its spine, tail to head (recipe units).
const EEL_SPINE: Array = [Vector3(-1.25, 0.10, -0.30), Vector3(-0.75, 0.22, 0.10), Vector3(-0.30, 0.36, -0.25), Vector3(0.15, 0.46, 0.15),
	Vector3(0.55, 0.55, -0.15), Vector3(0.85, 0.75, 0.25), Vector3(1.00, 0.95, 0.55), Vector3(1.08, 1.02, 0.70)]

static func _swimmers(m: Node3D) -> Array:
	## Every part along its body with how far it is from the head and which way is sideways there.
	if m._groups.has("__swim"):
		return m._groups["__swim"].list
	var out: Array = []
	var lengths: Array = [0.0]
	for i in range(EEL_SPINE.size() - 1, 0, -1):
		lengths.push_front(float(lengths[0]) + (EEL_SPINE[i] as Vector3).distance_to(EEL_SPINE[i - 1]))
	## lengths[i]: distance from pc[i] to the head along the spine.
	for part in m._select(["Body", "Spot", "Collar", "Spine", "Tail"]):
		var at: Vector3 = m.centre_of(part)
		var best: float = INF
		var s: float = 0.0
		var side := Vector3.RIGHT
		for i in range(EEL_SPINE.size() - 1):
			var a: Vector3 = EEL_SPINE[i]
			var b: Vector3 = EEL_SPINE[i + 1]
			var run: Vector3 = b - a
			var k: float = clampf((at - a).dot(run) / run.length_squared(), 0.0, 1.0)
			var d: float = at.distance_to(a + run * k)
			if d < best:
				best = d
				s = lerpf(float(lengths[i]), float(lengths[i + 1]), k)
				var flat := Vector3(run.x, 0.0, run.z).normalized()
				side = Vector3(-flat.z, 0.0, flat.x)
		out.append([part, s, side])
	m._groups["__swim"] = {"list": out, "parts": [], "joint": Vector3.ZERO, "chain": []}
	return out

static func _idle_eel(m: Node3D, clock: float, weight: float) -> void:
	## A swimming wave running down it from the head to the tail, more as it goes, and the head
	## turning a little into each stroke; its jaw gapes slowly open and shut, as a moray breathes.
	var jaw: Dictionary = m.group("jaw")
	m.turn(jaw.parts, jaw.joint, EEL_S, deg_to_rad(6.0) * (0.5 - 0.5 * cos(clock * 1.7)) * weight)
	for item in _swimmers(m):
		var s: float = float(item[1])
		m.shift([item[0]], (item[2] as Vector3) * 0.075 * sin(clock * 2.6 - s * 2.4) * clampf(s / 1.2, 0.15, 1.0) * weight)
	var head: Dictionary = m.group("head")
	m.turn(head.parts, head.joint, Vector3.UP, deg_to_rad(5.0) * sin(clock * 2.6 + 0.6) * weight)

static func _eel_reach(m: Node3D, clip: Dictionary, keys: Variant, back: float, out: float, coil: float) -> void:
	## Its head drawn back as the S behind it tightens, then thrown along its facing with the front
	## of its body going after it (less of it toward the tail).
	var t: float = float(clip.get("keyed", float(clip.t) - float(clip.get("shift", 0.0))))
	var v: float = m._v(clip, keys, t)
	if absf(v) < 0.00001:
		return
	var facing: Vector3 = EEL_FACING.normalized()
	var by: Vector3 = (facing * -back + Vector3(0, back * 0.4, 0)) * -v if v < 0.0 else (facing * out + Vector3(0, -out * 0.1, 0)) * v
	var head: Dictionary = m.group("head")
	m.shift(head.parts, by)
	for item in _swimmers(m):
		var s: float = float(item[1])
		var k: float = pow(clampf(1.0 - s / 1.9, 0.0, 1.0), 1.5)
		var bend: Vector3 = (item[2] as Vector3) * coil * sin(s * 2.8) * maxf(-v, 0.0) * clampf(s / 0.6, 0.0, 1.0)
		m.shift([item[0]], by * k + bend)

static func _eel_bite_body(m: Node3D, clip: Dictionary, _delta: float) -> void:
	_eel_reach(m, clip, "attack", 0.12, 0.28, 0.07)

static func _eel_shock_body(m: Node3D, clip: Dictionary, _delta: float) -> void:
	_eel_reach(m, clip, "attack", 0.06, 0.1, 0.05)

static func _eel_arc_body(m: Node3D, clip: Dictionary, _delta: float) -> void:
	_eel_reach(m, clip, "thrice", 0.1, 0.12, 0.06)

static func _eel_surge(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## A few hard strokes where it hangs: the swimming wave, bigger and quicker, over its idle one.
	var t: float = float(clip.get("keyed", clip.t))
	var v: float = m._v(clip, "f", t)
	if absf(v) < 0.00001:
		return
	for item in _swimmers(m):
		var s: float = float(item[1])
		m.shift([item[0]], (item[2] as Vector3) * 0.08 * sin(t * 5.2 - s * 2.4) * clampf(s / 1.2, 0.15, 1.0) * v)

static func _eel_charge(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its Arc's charge crawling up its spines from the tail to the arc through the hold.
	var tau: float = float(clip.t) - float(clip.get("shift", 0.0))
	var wind: float = float(clip.get("wind", HIT))
	var hold: float = float(clip.get("heavy", 0.0))
	for index in range(6):
		if tau >= wind + hold * float(index) / 6.0:
			m._queue(clip, "eel_charge%d" % index, "sparks", {"from": "Spine%02d" % (index + 1), "color": "#d8f8ff", "amount": 8, "speed": 1.6, "life": 0.35})

# --- the Lamprey Knot: one head of three strikes --------------------------------------------------

const LAMPREY_HEADS: Array = [["Head01-04", "Mouth01-07"], ["Head05-08", "Mouth08-14"], ["Head09-12", "Mouth15-21"]]

const LAMPREY_MOUTHS: Array = ["Mouth01", "Mouth08", "Mouth15"]

const LAMPREY_FACING: Array = [Vector3(-0.27, 0.49, -0.83), Vector3(0.85, 0.49, 0.18), Vector3(-0.58, 0.49, 0.65)]

static func _lamprey_reach(which: int, toward: Vector3) -> Array:
	## The axis a head swings about to reach toward the party, and how far it can go.
	var facing: Vector3 = LAMPREY_FACING[which]
	var axis: Vector3 = facing.cross(toward).normalized()
	return [axis, minf(facing.angle_to(toward) * 0.65, deg_to_rad(55.0))]

static func _lamprey_bite(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The heads that face the party take turns: one swings round at it, lunges, and its sucker
	## flares wide as it lands and rasps while it holds on; the tails lash on the floor.
	var which: int = [2, 1][int(clip.strike) % 2]
	var parts: Array = m._select(LAMPREY_HEADS[which])
	if parts.is_empty():
		return
	var t: float = float(clip.t)
	var joint: Vector3 = (parts[0] as Node3D).get("_rest").origin
	var toward := Vector3(0, -0.15, 1).normalized()
	var reach: Array = _lamprey_reach(which, toward)
	var v: float = m.value("attack", t)
	var mouth: Array = m._select(LAMPREY_HEADS[which][1])
	if not mouth.is_empty():
		var rasp: float = 0.08 * sin(t * 30.0) * smoothstep(HIT, HIT + 0.05, t) * (1.0 - smoothstep(0.42, 0.75, t))
		m.swell(mouth, (mouth[0] as Node3D).get("_rest").origin, Vector3.ONE * (1.0 + 0.4 * maxf(v, 0.0) + rasp))
	m.turn(parts, joint, reach[0], deg_to_rad(-18.0) * maxf(-v, 0.0) + float(reach[1]) * maxf(v, 0.0))
	m.shift(parts, toward * 0.18 * maxf(v, 0.0))
	for tail in m._select("Tail"):
		m.turn([tail], (tail as Node3D).get("_rest").origin, Vector3.UP, deg_to_rad(14.0) * v)
	m._creature.set("_rear", -0.25 * maxf(v, 0.0))
	m._rear_held = true
	if t >= HIT:
		m._queue(clip, "spatter", "sparks", {"from": LAMPREY_MOUTHS[which], "color": "#ff9aa8", "amount": 10, "speed": 2.0, "life": 0.4})

static func _lamprey_drink(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The two heads that face the party reach out and latch on, every sucker flaring and pulling,
	## the braid squeezing in gulps as it drinks.
	var t: float = float(clip.t)
	var pull: float = smoothstep(0.1, HIT, t) * (1.0 - smoothstep(0.9, 1.25, t))
	for which in range(3):
		var mouth: Array = m._select(LAMPREY_HEADS[which][1])
		if not mouth.is_empty():
			m.swell(mouth, (mouth[0] as Node3D).get("_rest").origin, Vector3.ONE * (1.0 + (0.25 + 0.12 * sin(t * 18.0 + float(which))) * pull))
	var toward := Vector3(0, -0.15, 1).normalized()
	for which in [1, 2]:
		var parts: Array = m._select(LAMPREY_HEADS[which])
		if parts.is_empty():
			continue
		var reach: Array = _lamprey_reach(which, toward)
		m.turn(parts, (parts[0] as Node3D).get("_rest").origin, reach[0], float(reach[1]) * 0.55 * pull)
	var braid: Array = m._select(["Body"])
	var gulp: float = 1.0 + 0.4 * sin(t * 12.0)
	m.swell(braid, Vector3(0, 0.5, 0), Vector3(1.0 - 0.08 * pull * gulp, 1.0 + 0.04 * pull, 1.0 - 0.08 * pull * gulp))
	## What it drinks is pulled into the suckers that latched on (not flown out of the party: a
	## drink heals it and takes nothing from them).
	if t >= 0.12:
		m._queue(clip, "drink3", "spiral", {"from": "Mouth15", "color": "#ff6a7a", "amount": 18, "size": 0.6})
		m._queue(clip, "drink2", "spiral", {"from": "Mouth08", "color": "#ff6a7a", "amount": 18, "size": 0.6})
	if t >= 0.45:
		m._queue(clip, "gulp", "bubbles", {"from": "Mouth15", "color": "#ff9aa8", "amount": 8})

# --- the Drowned Choir: heads that sing ---------------------------------------------------------

## Each singer: all of it (jointed at its root on the pool floor, swinging there), its face (head
## stone, eyes, mouth ring and throat gem, and what hangs off it), its head stone and mouth ring.
const CHOIR: Array = [
	{"parts": ["Neck01-05", "Head01-03", "Mouth01-02", "Rope"], "face": ["Head01-03", "Mouth01-02"], "head": "Head01", "mouth": "Mouth01", "root": Vector3(-0.60, 0.02, 0.30)},
	{"parts": ["Neck06-10", "Head04-06", "Mouth03-04", "Weed01"], "face": ["Head04-06", "Mouth03-04", "Weed01"], "head": "Head04", "mouth": "Mouth03", "root": Vector3(0.05, 0.02, -0.25)},
	{"parts": ["Neck11-15", "Head07-09", "Mouth05-06"], "face": ["Head07-09", "Mouth05-06"], "head": "Head07", "mouth": "Mouth05", "root": Vector3(0.70, 0.02, 0.20)},
	{"parts": ["Neck16-18", "Head10", "Mouth07-08"], "face": ["Head10", "Mouth07-08"], "head": "Head10", "mouth": "Mouth07", "root": Vector3(-0.30, 0.02, 0.85)},
	{"parts": ["Neck19-21", "Head11", "Mouth09-10"], "face": ["Head11", "Mouth09-10"], "head": "Head11", "mouth": "Mouth09", "root": Vector3(0.45, 0.02, 0.80)}]

## Which heads sing each of its moves, and in what color the song goes out. Another Voice's young
## heads (`rise`) duck under the pool and come up out of it singing.
const CHOIR_SONGS: Dictionary = {
	"Dirge": {"voices": [1], "color": "#6ab8e0"}, "Requiem": {"voices": [0, 2], "color": "#8fd0e8"},
	"Requiem Chorus": {"voices": [0, 1, 2], "color": "#c8f0ff", "big": true}, "Lament": {"voices": [3, 4], "color": "#c58bff"},
	"Another Voice": {"voices": [3, 4, 1], "color": "#8fd0e8", "rise": [3, 4]}}

static func _now(part: Node3D) -> Vector3:
	## Where a part's shape is this frame, after its own idle swing, in the body's space. The
	## singers swing about their roots, so a head is turned about where it is, not where it rests.
	var at: Transform3D = part.transform
	if part.get_child_count() > 0 and part.get_child(0) is Node3D:
		return at * (part.get_child(0) as Node3D).transform.origin
	return at.origin

static func _singer(m: Node3D, index: int) -> Dictionary:
	var key: String = "__singer%d" % index
	if m._groups.has(key):
		return m._groups[key]
	var singer: Dictionary = CHOIR[index]
	var out: Dictionary = {"whole": m._select(singer.parts), "face": m._select(singer.face), "ring": m._select(singer.mouth),
		"head": m._named.get(singer.head, null), "parts": [], "joint": singer.root, "chain": []}
	m._groups[key] = out
	return out

static func _sing_pose(m: Node3D, index: int, mouth: float, tilt: float, yaw: float, lean: float, side: float, drop: float) -> void:
	## One singer's pose, leaf first: its mouth ring flared, its face tilted back (a negative
	## `tilt`) and turned about the head, the whole of it leant about its root (+`lean` toward the
	## party, +`side` to its right) and sunk `drop` into the pool.
	var s: Dictionary = _singer(m, index)
	if s.whole.is_empty() or s.head == null:
		return
	if absf(mouth) > 0.0001 and not s.ring.is_empty():
		m.swell(s.ring, _now(s.ring[0]), Vector3.ONE * (1.0 + mouth))
	if absf(tilt) > 0.00001 or absf(yaw) > 0.00001:
		var at: Vector3 = _now(s.head)
		m.turn(s.face, at, Vector3.RIGHT, deg_to_rad(tilt))
		m.turn(s.face, at, Vector3.UP, deg_to_rad(yaw))
	var root: Vector3 = CHOIR[index].root
	m.turn(s.whole, root, Vector3.RIGHT, deg_to_rad(lean))
	m.turn(s.whole, root, Vector3.BACK, deg_to_rad(side))
	if absf(drop) > 0.00001:
		m.shift(s.whole, Vector3(0, -drop, 0))

static func _idle_choir(m: Node3D, clock: float, weight: float) -> void:
	## The choir hums as it waits: each mouth opening and closing on its own breath, and every head
	## nodding to one slow beat together, as a choir keeps time.
	var nod: float = 4.0 * sin(clock * 1.25) * weight
	for index in range(CHOIR.size()):
		var hum: float = 0.14 * (0.5 - 0.5 * cos(clock * 1.9 + float(index) * 1.3)) * weight
		_sing_pose(m, index, hum, nod, 0.0, 0.0, 0.0, 0.0)

static func _bump(t: float, start: float, span: float) -> float:
	## 0 before `start`, up to 1 and back down over `span`.
	return sin(PI * clampf((t - start) / span, 0.0, 1.0))

static func _choir_hum(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## A phrase hummed down the line, left to right: each singer lifts its face and opens its mouth
	## as the one before it closes.
	var t: float = float(clip.get("keyed", clip.t))
	var w: float = float(clip.get("weight", 1.0))
	var order: Array = [0, 3, 1, 4, 2]
	for i in range(order.size()):
		var k: float = _bump(t, 0.35 + 0.28 * float(i), 0.8) * w
		_sing_pose(m, int(order[i]), 0.45 * k, -14.0 * k, 0.0, 2.0 * k, 0.0, 0.0)

static func _choir_turn(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The two tall outer singers turn their faces to the middle one and lean in; it bows to them.
	var v: float = m._v(clip, "f", float(clip.get("keyed", clip.t)))
	_sing_pose(m, 0, 0.25 * v, -6.0 * v, 35.0 * v, 0.0, -5.0 * v, 0.0)
	_sing_pose(m, 2, 0.25 * v, -6.0 * v, -35.0 * v, 0.0, 5.0 * v, 0.0)
	_sing_pose(m, 1, 0.2 * v, 10.0 * v, 0.0, 0.0, 0.0, 0.0)

static func _choir_bow(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The tall middle singer bows low over the pool like a conductor; the rest lean back.
	var v: float = m._v(clip, "f", float(clip.get("keyed", clip.t)))
	_sing_pose(m, 1, 0.2 * v, 20.0 * v, 0.0, 14.0 * v, 0.0, 0.0)
	for index in [0, 2, 3, 4]:
		_sing_pose(m, index, 0.0, -8.0 * v, 0.0, -5.0 * v, 0.0, 0.0)

static func _choir_shake(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The young front-left singer shakes the water off its head.
	var t: float = float(clip.get("keyed", clip.t))
	var v: float = m._v(clip, "f", t)
	var shake: float = m._v(clip, "shake", t)
	_sing_pose(m, 3, 0.1 * v, -6.0 * v, 22.0 * shake, 0.0, 4.0 * shake, 0.0)

static func _choir_sink(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The two young singers duck under the pool, mouths to the water, and come up again.
	var t: float = float(clip.get("keyed", clip.t))
	var w: float = float(clip.get("weight", 1.0))
	var first: float = smoothstep(0.2, 1.0, t) * (1.0 - smoothstep(1.9, 2.7, t)) * w
	var second: float = smoothstep(0.6, 1.4, t) * (1.0 - smoothstep(2.3, 3.1, t)) * w
	_sing_pose(m, 3, 0.2 * first, 10.0 * first, 0.0, 0.0, 0.0, 1.1 * first)
	_sing_pose(m, 4, 0.2 * second, 10.0 * second, 0.0, 0.0, 0.0, 0.9 * second)

static func _strain(clip: Dictionary, delta: float) -> float:
	## How hard a heavy song strains through its hold (0 before, 1 through it, gone as it lets go),
	## on the move's own clock: the clock a played function is handed stands still through the hold.
	clip["clock"] = float(clip.get("clock", 0.0)) + delta
	var hold: float = float(clip.get("heavy", 0.0))
	if hold <= 0.0:
		return 0.0
	var tau: float = float(clip.clock) - float(clip.get("shift", 0.0))
	var wind: float = float(clip.get("wind", HIT))
	return smoothstep(0.0, maxf(0.05, wind), tau) * (1.0 - smoothstep(wind + hold, wind + hold + 0.06, tau))

static func _choir_sing(m: Node3D, clip: Dictionary, delta: float) -> void:
	## The singers whose song it is throw their heads back and open their mouths wide, leaning
	## toward the party as the note lands, and it rolls out of them in rings; the rest lean back
	## from it. Held heavy, every head draws back with its mouth wide, drawing breath.
	var song: Dictionary = CHOIR_SONGS.get(str(clip.move), CHOIR_SONGS.Dirge)
	var t: float = float(clip.t)
	var big: bool = bool(song.get("big", false))
	var sing: float = smoothstep(0.05, HIT, t) * (1.0 - smoothstep(0.75 if not big else 1.0, 1.15 if not big else 1.4, t))
	var lean: float = smoothstep(HIT - 0.1, HIT, t) * (1.0 - smoothstep(HIT + 0.2, 0.9, t))
	var strain: float = _strain(clip, delta)
	var rising: Array = song.get("rise", [])
	## Another Voice: the young heads duck under, then come up out of the pool past where they
	## stood and settle.
	var dip: float = 0.6 * smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.15, 0.4, t)) - 0.18 * _bump(t, 0.32, 0.5)
	var color: String = str(song.color)
	for index in range(CHOIR.size()):
		var voice: bool = (song.voices as Array).has(index)
		var drop: float = dip if rising.has(index) else 0.0
		if voice:
			_sing_pose(m, index, (0.7 if big else 0.5) * sing + 0.3 * strain, -28.0 * sing - 12.0 * strain, 0.0,
				(10.0 if big else 7.0) * lean - 7.0 * strain, 0.0, drop)
		else:
			_sing_pose(m, index, 0.12 * strain, -6.0 * strain, 0.0, -3.0 * lean - 7.0 * strain, 0.0, drop)
		if not voice:
			continue
		for wave in range(3 if big else 2):
			if t >= HIT - 0.06 + 0.13 * float(wave):
				m._queue(clip, "ring%d_%d" % [index, wave], "ripple", {"from": CHOIR[index].mouth, "color": color, "radius": 1.3 + 0.6 * float(wave), "size": 1.0})
	if not rising.is_empty():
		if t >= 0.05:
			m._queue(clip, "under", "bubbles", {"from": "feet", "off": Vector3(0.05, 0.1, 0.85), "color": WATER, "amount": 16})
		if t >= 0.3:
			m._queue(clip, "surface", "splash", {"from": "feet", "off": Vector3(0.05, 0.2, 0.85), "color": WATER, "amount": 24, "speed": 2.5})

# --- the Undertow: a serpent's neck ---------------------------------------------------------------

static func _idle_undertow(m: Node3D, clock: float, weight: float) -> void:
	## Leaf first: its jaw working slowly as it breathes and its head looking about, then the neck
	## that carries them, a slow S running up it from the water and the whole of it drawing up and
	## sinking back over the party.
	m._idle_gesture(["pant", "jaw", X, 3.0, 1.3], weight)
	m._idle_gesture(["look", "head", 12.0, 6.0, 3.8, 1.5], weight)
	var chain: Array = m.group("neck").chain
	var count: int = chain.size()
	for index in range(count - 1, -1, -1):
		var carried: Array = []
		for later in range(index, count):
			carried.append_array(chain[later].parts)
		var w: float = lerpf(0.35, 1.0, float(index) / float(maxi(1, count - 1))) * weight
		var joint: Vector3 = chain[index].joint
		m.turn(carried, joint, Vector3.BACK, deg_to_rad(3.0) * w * sin(clock * 0.9 - float(index) * 0.55))
		m.turn(carried, joint, Vector3.RIGHT, deg_to_rad(-2.0) * w * (0.5 - 0.5 * cos(clock * 0.45)))
