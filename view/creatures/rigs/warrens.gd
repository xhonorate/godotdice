extends RefCounted
## The Warrens: the fungal mine's creatures (and the Puffball).
## Each creature's rig as data (see the gesture language in creature_rigs.gd), keyed by its scene,
## and the moves and idles no table says, written out as functions of the Moves node
## (creature_moves.gd) passed in as `m`. creature_rigs.gd merges every mine's RIGS.
## Part names and joints: build/options/part_roles/warrens.md.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {
	"_tendril_lash": 1.25,
	"_tendril_knit": 1.4,
}
## When a move played by a function is wound back furthest (a heavy one holds there).
const CUSTOM_WIND: Dictionary = {
}

## The Cap Shambler's six root legs round its mass (front-left, front, front-right, back-right,
## back, back-left), each with the axis that lifts its foot off the floor and its place in the
## ripple of a crawl.
const SHAMBLER_LEGS: Array = [["leg1", Vector3(-0.479, 0, 0.878), 0.0], ["leg2", Vector3(-1.0, 0, 0.024), 1.047], ["leg3", Vector3(-0.521, 0, -0.854), 2.094],
	["leg4", Vector3(0.479, 0, -0.878), 3.142], ["leg5", Vector3(1.0, 0, -0.024), 4.189], ["leg6", Vector3(0.521, 0, 0.854), 5.236]]
## The Root Horror's five root legs (front-right, right-back, back, left-back, front-left).
const HORROR_LEGS: Array = [["leg1", Vector3(-0.809, 0, -0.588), 0.0], ["leg2", Vector3(0.309, 0, -0.951), 1.257], ["leg3", Vector3(1.0, 0, 0.0), 2.513],
	["leg4", Vector3(0.309, 0, 0.951), 3.770], ["leg5", Vector3(-0.809, 0, 0.588), 5.027]]
## The Gardener's eight legs, a crab's two alternating sets (a left foot lifts with +z, a right
## with -z).
const GARDENER_LEGS: Array = [["leg_l1", Vector3(0, 0, 1), 0.0], ["leg_r2", Vector3(0, 0, -1), 0.0], ["leg_l3", Vector3(0, 0, 1), 0.0], ["leg_r4", Vector3(0, 0, -1), 0.0],
	["leg_r1", Vector3(0, 0, -1), PI], ["leg_l2", Vector3(0, 0, 1), PI], ["leg_r3", Vector3(0, 0, -1), PI], ["leg_l4", Vector3(0, 0, 1), PI]]

## The Root Horror's arms: the first column, what rides past the elbow, and the elbow at rest.
const HORROR_ELBOW_L := Vector3(0.86, 1.86, 0.36)
const HORROR_ELBOW_R := Vector3(-0.9, 1.5, 0.5)
## The Heartrot's three tendrils: the stem column, the rest of it (column, knuckle, barb), its
## base on the floor, its knuckle at rest, and the axis that tips it out from the heart (+) or in
## over it (-).
const HEARTROT_TENDRILS: Array = [
	["Tendril01", "Tendril02-04", Vector3(1.105, 0.05, 0.467), Vector3(1.336, 1.15, 0.565), Vector3(0.389, 0, -0.921)],
	["Tendril05", "Tendril06-08", Vector3(-0.957, 0.05, 0.724), Vector3(-1.156, 1.15, 0.875), Vector3(0.604, 0, 0.797)],
	["Tendril09", "Tendril10-12", Vector3(-0.149, 0.05, -1.191), Vector3(-0.180, 1.15, -1.439), Vector3(-0.992, 0, 0.124)]]
## The Heartrot's second blow of its Double Rot: the other front tendril rears through the first
## and whips down after it.
const ROT_FIRST: Array = [[0.0, 0.0], [0.22, -1.0], [0.3, 1.0], [0.42, 0.7], [0.8, 0.0]]
const ROT_SECOND: Array = [[0.0, 0.0], [0.22, -0.8], [0.46, -1.0], [0.54, 1.0], [0.66, 0.7], [1.05, 0.0]]

const RIGS: Dictionary = {
	## The Mycel Weaver: a stilt-legged fungal spider standing in its web. A spider waits still,
	## feels its threads with its front legs and plucks them, rears with its fangs spread, weaves
	## with its abdomen, strikes in quick double bites. Its legs are tied into the web, so they
	## only ever tap and lift a little.
	"MYCEL_WEAVER": {
		"mouth": "Mouth01",
		"groups": {"head": {"parts": ["Head", "Jaw", "Mouth"], "at": "Head01"}, "jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"fang_l": {"parts": ["Jaw01"], "at": Vector3(0.06, 0.94, 0.34)}, "fang_r": {"parts": ["Jaw02"], "at": Vector3(-0.06, 0.94, 0.34)},
			"body": {"parts": ["Body", "Head", "Jaw", "Mouth"], "at": "Body01"}, "abdomen": {"parts": ["Body02"], "at": "Body01"},
			"leg_fl": {"parts": ["Leg13-15"], "at": "Leg13"}, "leg_fr": {"parts": ["Leg01-03"], "at": "Leg01"},
			"leg_ml": {"parts": ["Leg16-18", "Leg25-26"], "at": "Leg16"}, "leg_mr": {"parts": ["Leg04-06"], "at": "Leg04"},
			"leg_bl": {"parts": ["Leg22-24"], "at": "Leg22"}, "leg_br": {"parts": ["Leg10-12"], "at": "Leg10"},
			## The web it stands in: every thread, the dew on them, the hub gem and the dragline.
			"web": {"parts": ["Cylinder", "Sphere"], "at": Vector3(0.04, 0.5, -0.06)}, "hub": {"parts": ["Sphere02"]}},
		"idle_gestures": [["sway", "jaw", X, 4.0, 2.3, 0.0], ["look", "head", 10.0, 5.0, 2.6, 0.7],
			["flex", "leg_fl", Z, 3.0, 3.1, 0.0], ["flex", "leg_fr", Z, -3.0, 3.7, 1.6], ["bob", "body", Vector3(0, 0.012, 0), 1.4, 0.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Feels its web: the front legs tap the threads in turn, the web quivering, the head
			## bowed to listen.
			"feel": {"length": 2.4, "hold": 1.3, "weight": 3.0, "do": [
				["turn", "leg_fl", Z, 0.0, 5.5, [[0.0, 0.0], [0.3, 1.0], [0.42, 0.0], [0.75, 1.0], [0.87, 0.0], [1.2, 1.0], [1.32, 0.0]]],
				["turn", "leg_fr", Z, 0.0, -5.5, [[0.4, 0.0], [0.62, 1.0], [0.74, 0.0], [1.05, 1.0], [1.17, 0.0], [1.5, 1.0], [1.62, 0.0]]],
				["tremble", "web", 0.008, [[0.0, 0.0], [0.4, 1.0], [1.7, 1.0], [2.1, 0.0]]],
				["turn", "head", X, 0.0, 9.0, "f"], ["turn", "body", X, 0.0, 4.0, "f"]]},
			## Rears up with its fangs spread wide, venom beading on them, and settles.
			"rear": {"length": 2.6, "hold": 1.0, "weight": 2.0, "do": [
				["turn", "fang_l", Z, 0.0, 24.0, "f"], ["turn", "fang_r", Z, 0.0, -24.0, "f"], ["turn", "jaw", X, 0.0, -14.0, "f"],
				["turn", "head", X, 0.0, -12.0, "f"], ["turn", "body", X, 0.0, -14.0, "f"], ["move", "body", Vector3.ZERO, Vector3(0, 0.03, 0), "f"],
				["turn", "leg_fl", Z, 0.0, 4.0, "f"], ["turn", "leg_fr", Z, 0.0, -4.0, "f"],
				["fx", 1.0, "sparks", {"from": "Mouth01", "color": "#9ad35a", "amount": 4, "speed": 0.4, "life": 0.9}],
				["fx", 1.4, "sparks", {"from": "Mouth01", "color": "#9ad35a", "amount": 3, "speed": 0.3, "life": 0.9}]]},
			## Weaves: the abdomen dips and sways side to side, the hind legs working, the hub
			## glowing as new thread runs along the web.
			"weave": {"length": 2.6, "hold": 1.4, "weight": 2.0, "do": [
				["turn", "abdomen", Y, -10.0, 10.0, [[0.0, 0.0], [0.45, 1.0], [0.9, -1.0], [1.35, 1.0], [1.8, -1.0], [2.3, 0.0]]],
				["turn", "abdomen", X, 0.0, -9.0, "f"],
				["turn", "leg_bl", Z, -2.0, 3.0, [[0.3, 0.0], [0.55, 1.0], [0.8, -1.0], [1.05, 1.0], [1.3, -1.0], [1.55, 1.0], [1.8, 0.0]]],
				["turn", "leg_br", Z, 2.0, -3.0, [[0.4, 0.0], [0.65, -1.0], [0.9, 1.0], [1.15, -1.0], [1.4, 1.0], [1.65, -1.0], [1.9, 0.0]]],
				["each", "hub", 0.0, 0.9, "f"], ["tremble", "web", 0.004, "f"],
				["fx", 0.7, "puff", {"from": "Sphere02", "color": "accent", "amount": 5, "size": 0.35, "rise": 0.15, "glow": true}],
				["fx", 1.4, "puff", {"from": "Sphere02", "color": "accent", "amount": 5, "size": 0.35, "rise": 0.15, "glow": true}]]},
			## Cleans its fangs: they work over each other, the head cocked to one side.
			"groom": {"length": 2.2, "hold": 1.0, "weight": 1.5, "do": [["turn", "fang_l", Z, 0.0, 10.0, "chew"], ["turn", "fang_r", Z, 0.0, -10.0, "chew"],
				["turn", "jaw", X, 0.0, -8.0, "f"], ["turn", "head", Z, 0.0, 11.0, "f"], ["turn", "head", X, 0.0, 5.0, "f"]]},
		},
		"moves": {
			## Rears with its fangs spread and bites twice, venom spraying off them.
			"Fangs": [["turn", "fang_l", Z, 22.0, -6.0, "snap2"], ["turn", "fang_r", Z, -22.0, 6.0, "snap2"],
				["turn", "jaw", X, 18.0, -40.0, "twice"], ["turn", "head", X, -15.0, 22.0, "twice"], ["turn", "body", X, -12.0, 10.0, "twice"],
				["turn", "leg_fl", Z, 4.0, 0.0, "twice"], ["turn", "leg_fr", Z, -4.0, 0.0, "twice"], ["rear", 0.3, "twice"],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#9ad35a", "amount": 8, "speed": 1.5}],
				["fx", 0.54, "sparks", {"from": "Mouth01", "color": "#9ad35a", "amount": 8, "speed": 1.5}]],
			## Rears back and flings a strand of web at a die, its own web shivering.
			"Web": [["turn", "fang_l", Z, 0.0, 18.0, "throw"], ["turn", "fang_r", Z, 0.0, -18.0, "throw"],
				["turn", "head", X, -14.0, 6.0, "throw"], ["turn", "body", X, -16.0, 8.0, "throw"],
				["turn", "leg_fl", Z, 4.0, 0.0, "throw"], ["turn", "leg_fr", Z, -4.0, 0.0, "throw"], ["tremble", "web", 0.01, "hold"],
				["fx", 0.16, "spit", {"color": "#e8e4dc", "kind": "web", "flight": 0.18, "size": 1.4}],
				["fx", 0.17, "puff", {"from": "Mouth01", "color": "#e8e4dc", "amount": 6, "size": 0.4, "rise": 0.1}]],
			## Its fangs work venom up, beading and dripping, and it spits it.
			"Envenom": [["turn", "fang_l", Z, 14.0, -4.0, "throw"], ["turn", "fang_r", Z, -14.0, 4.0, "throw"],
				["turn", "jaw", X, 20.0, -30.0, "throw"], ["turn", "head", X, -18.0, 12.0, "throw"], ["turn", "body", X, -8.0, 6.0, "throw"],
				["fx", 0.02, "glow", {"from": "Mouth01", "color": "#9ad35a", "size": 0.35}],
				["fx", 0.05, "sparks", {"from": "Mouth01", "color": "#9ad35a", "amount": 5, "speed": 0.5, "life": 0.8}],
				["fx", 0.17, "spit", {"color": "#9ad35a", "kind": "glob", "flight": 0.15}]],
		},
	},
	## The Cap Shambler: a walking mushroom, a crowd of caps on crawling root legs. It lumbers,
	## its weight swaying from side to side, the big cap bobbing; it puffs spores, shuffles its
	## roots, shakes its caps; it rears on its back roots to stomp.
	"CAP_SHAMBLER": {
		"mouth": "Mouth01",
		"groups": {"cap": {"parts": ["Head"], "at": "Head01"}, "jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"eyes": {"parts": ["Head11", "Head12"], "at": Vector3(0.05, 1.2, 0.07)},
			"mass": {"parts": ["Core01", "Jaw", "Head", "Column", "Cap", "Crystal", "Sphere01", "Mouth01"], "at": Vector3(0, 0.3, 0)},
			"cap1": {"parts": ["Column01", "Cap01", "Sphere01"], "at": "Column01"}, "cap2": {"parts": ["Column02", "Cap02"], "at": "Column02"},
			"cap3": {"parts": ["Column03", "Cap03"], "at": "Column03"}, "cap4": {"parts": ["Column04", "Cap04"], "at": "Column04"},
			"leg1": {"parts": ["Leg01-03"], "at": "Leg01"}, "leg2": {"parts": ["Leg04-06"], "at": "Leg04"}, "leg3": {"parts": ["Leg07-09"], "at": "Leg07"},
			"leg4": {"parts": ["Leg10-12"], "at": "Leg10"}, "leg5": {"parts": ["Leg13-15"], "at": "Leg13"}, "leg6": {"parts": ["Leg16-18"], "at": "Leg16"}},
		"idle_gestures": [["blink", "eyes", Vector3(1, 0.15, 1), 4.0, 0.0], ["sway", "cap", X, 2.5, 1.1, 0.0], ["sway", "cap", Z, 2.0, 0.8, 1.0],
			["sway", "mass", Z, 2.0, 1.05, 0.5], ["bob", "mass", Vector3(0, -0.012, 0), 2.1, 0.5]],
		"fidget_every": [5.0, 10.0],
		"fidgets": {
			## Squashes its big cap down like a bellows and puffs a cloud of spores from its top.
			"puff": {"length": 2.0, "weight": 3.0, "do": [
				["grow", "cap", Vector3(0.08, -0.13, 0.08), Vector3(-0.03, 0.06, -0.03), [[0.0, 0.0], [0.55, -1.0], [0.66, 1.0], [0.85, -0.2], [1.1, 0.0]]],
				["move", "mass", Vector3(0, -0.03, 0), Vector3.ZERO, [[0.0, 0.0], [0.55, -1.0], [0.7, 0.0]]],
				["fx", 0.66, "puff", {"from": "Head15", "color": "accent", "amount": 12, "size": 0.9, "rise": 0.9, "glow": true}],
				["fx", 0.7, "puff", {"from": "Head13", "color": "accent", "amount": 6, "size": 0.6, "rise": 0.7, "glow": true}]]},
			## Shuffles in place, its roots lifting one after another round its mass, swaying.
			"shuffle": {"length": 2.8, "hold": 1.6, "weight": 2.0, "do": [["call", "_shambler_shuffle"]]},
			## Shakes all its caps like a wet dog, spores shaken loose.
			"shake": {"length": 1.6, "hold": 0.6, "weight": 1.5, "do": [["turn", "cap1", Z, -6.0, 6.0, "shake"], ["turn", "cap2", Z, -6.0, 6.0, "shake"],
				["turn", "cap3", X, -6.0, 6.0, "shake"], ["turn", "cap4", X, -6.0, 6.0, "shake"], ["turn", "cap", Z, -4.0, 4.0, "shake"],
				["turn", "mass", Y, -3.0, 3.0, "shake"],
				["fx", 0.4, "puff", {"from": "Cap01", "color": "accent", "amount": 6, "size": 0.5, "rise": 0.3, "glow": true}],
				["fx", 0.6, "puff", {"from": "Cap02", "color": "accent", "amount": 6, "size": 0.5, "rise": 0.3, "glow": true}],
				["fx", 0.8, "puff", {"from": "Head02", "color": "accent", "amount": 6, "size": 0.6, "rise": 0.4, "glow": true}]]},
			## Peers about from under its brim.
			"look": {"length": 3.4, "hold": 2.2, "weight": 2.0, "do": [["gaze", "cap", 16.0, 8.0, "f", 3], ["turn", "mass", Y, 0.0, 4.0, "f"]]},
		},
		"moves": {
			## Leans back and slams its big cap down at the party, spores bursting off it.
			"Slam": [["turn", "cap", X, -14.0, 22.0, "attack"], ["turn", "mass", X, -6.0, 8.0, "attack"],
				["hop", Vector3(0, 0.15, -0.05), Vector3(0, -0.03, 0.12), "attack"],
				["fx", 0.3, "shock", {"ahead": 0.6}], ["fx", 0.3, "puff", {"from": "Head02", "color": "accent", "amount": 12, "size": 1.0, "glow": true}]],
			## Rears up on its back roots, the front roots lifting clear, and crashes down.
			"Stomp": [["turn", "leg1", Vector3(-0.479, 0, 0.878), 22.0, -2.0, "big"], ["turn", "leg2", Vector3(-1.0, 0, 0.024), 26.0, -2.0, "big"],
				["turn", "leg3", Vector3(-0.521, 0, -0.854), 22.0, -2.0, "big"], ["turn", "cap", X, -10.0, 18.0, "big"],
				["lean", X, -12.0, 2.5, Vector3(0, 0, -0.7), "big"], ["hop", Vector3(0, 0.06, -0.04), Vector3(0, -0.02, 0.06), "big"],
				["fx", 0.3, "shock", {"ahead": 0.5, "size": 1.2}], ["fx", 0.31, "puff", {"from": "Head15", "color": "accent", "amount": 10, "size": 0.8, "rise": 0.8, "glow": true}],
				["fx", 0.32, "dust", {"amount": 40}]],
			## Squeezes its big cap down like a bellows, mouth gaping, and breathes a cloud out.
			"Spore Cloud": [["turn", "jaw", X, 0.0, 28.0, "hold"], ["grow", "cap", Vector3(-0.04, 0.06, -0.04), Vector3(0.08, -0.13, 0.08), "breath"],
				["turn", "mass", X, -5.0, 6.0, "breath"],
				["fx", 0.25, "breath", {"kind": "spores", "color": "#c8d06a", "seconds": 0.5, "size": 1.0}],
				["fx", 0.3, "puff", {"from": "Mouth01", "color": "#b8c84a", "amount": 18, "size": 1.4, "glow": true}],
				["fx", 0.32, "puff", {"from": "Head15", "color": "accent", "amount": 8, "size": 0.8, "rise": 0.8, "glow": true}]],
		},
		"heavy": {
			## Stomp held: it rears higher, the cap squashed down gathering spores, dust lifting under
			## its back roots; it lands in a burst of spores and grit.
			"Stomp": {"at": "Head02",
				"pose": [["grow", "cap", 0.0, Vector3(0.06, -0.09, 0.06), "h"]],
				"charge": [["charge_dust", {"seconds": 0.45}], ["glow", {"from": "Head02", "color": "accent", "size": 0.45, "seconds": 0.55}],
					["puff", {"from": "Head15", "color": "accent", "amount": 10, "size": 0.8, "rise": 0.5, "glow": true}]],
				"impact": [["shock", {"ahead": 0.5, "size": 1.6}], ["puff", {"from": "Head15", "color": "accent", "amount": 14, "size": 1.0, "rise": 1.1, "glow": true}],
					["shards", {"from": "feet", "off": Vector3(0, 0.1, 0.6), "color": "#6a5440", "amount": 12, "speed": 4.0}], ["dust", {"amount": 70}]]},
		},
	},
	## The Root Horror: a walking stump of roots with a split mouth of iron teeth down its trunk
	## and a gem heart inside. Its roots writhe and grip the floor, the split breathes open and
	## shut, it gnashes, stretches its creaking arms; it lashes, and opens its arms wide to crush.
	"ROOT_HORROR": {
		"mouth": "Mouth01",
		"groups": {"arm_l": {"parts": ["ArmL"], "at": "ArmL01"}, "arm_r": {"parts": ["ArmR"], "at": "ArmR01"},
			"jaw_l": {"parts": ["JawL"], "at": "JawL01"}, "jaw_r": {"parts": ["JawR"], "at": "JawR01"},
			"heart": {"parts": ["Heart01"]}, "split": {"parts": ["Mouth01"]},
			"upper": {"parts": ["Core01", "Rock", "Mouth01", "Heart01", "Eye", "JawL", "JawR", "ArmL", "ArmR", "Cap", "Crystal"], "at": Vector3(0, 0.66, 0)},
			"leg1": {"parts": ["Leg01-03"], "at": "Leg01"}, "leg2": {"parts": ["Leg04-06"], "at": "Leg04"}, "leg3": {"parts": ["Leg07-09"], "at": "Leg07"},
			"leg4": {"parts": ["Leg10-12"], "at": "Leg10"}, "leg5": {"parts": ["Leg13-15"], "at": "Leg13"}},
		"idle_gestures": [["pant", "jaw_l", Y, 5.0, 1.4], ["pant", "jaw_r", Y, -5.0, 1.4], ["breathe", "split", Vector3(0.18, 0.03, 0.0), 1.4, 0.0],
			["sway", "leg1", Y, 3.0, 0.9, 0.0], ["sway", "leg2", Y, 3.0, 0.9, 1.3], ["sway", "leg3", Y, 3.0, 0.9, 2.6],
			["sway", "leg4", Y, 3.0, 0.9, 3.9], ["sway", "leg5", Y, 3.0, 0.9, 5.2], ["sway", "upper", Z, 1.2, 0.7, 0.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## The split in its trunk opens and its teeth gnash, the heart inside flaring.
			"gnash": {"length": 2.2, "weight": 3.0, "do": [
				["turn", "jaw_l", Y, -3.0, 42.0, [[0.0, 0.0], [0.5, 1.0], [0.66, 0.1], [0.82, 1.0], [0.98, 0.1], [1.14, 1.0], [1.6, 1.0], [2.0, 0.0]]],
				["turn", "jaw_r", Y, 3.0, -42.0, [[0.0, 0.0], [0.5, 1.0], [0.66, 0.1], [0.82, 1.0], [0.98, 0.1], [1.14, 1.0], [1.6, 1.0], [2.0, 0.0]]],
				["each", "split", 0.0, Vector3(0.45, 0.1, 0.2), [[0.0, 0.0], [0.5, 1.0], [1.6, 1.0], [2.0, 0.0]]],
				["each", "heart", 0.0, 0.35, [[0.0, 0.0], [0.5, 0.6], [0.66, 1.0], [0.98, 1.0], [1.14, 0.6], [2.0, 0.0]]],
				["fx", 0.6, "puff", {"from": "Heart01", "color": "accent", "amount": 6, "size": 0.4, "rise": 0.2, "glow": true}],
				["fx", 0.9, "sparks", {"from": "Heart01", "color": "#e0ff8a", "amount": 4, "speed": 0.5, "life": 0.9}]]},
			## Stretches its root arms up, the elbows creaking, bark dust shaken off.
			"stretch": {"length": 2.8, "hold": 1.0, "weight": 2.0, "do": [["call", "_horror_stretch"],
				["turn", "arm_l", X, 0.0, -28.0, "f"], ["turn", "arm_r", X, 0.0, -34.0, "f"], ["turn", "upper", X, 0.0, -5.0, "f"],
				["fx", 0.9, "puff", {"from": "ArmL03", "color": "#6a5440", "amount": 6, "size": 0.5, "rise": 0.3}],
				["fx", 1.0, "puff", {"from": "ArmR03", "color": "#6a5440", "amount": 6, "size": 0.5, "rise": 0.3}]]},
			## Its roots creep and regrip the floor one after another.
			"creep": {"length": 2.8, "weight": 2.0, "do": [["call", "_horror_creep"]]},
			## Turns its trunk to look about with its knot-hole eyes.
			"look": {"length": 3.4, "hold": 2.0, "weight": 1.5, "do": [["gaze", "upper", 16.0, 4.0, "f", 2]]},
		},
		"moves": {
			## Its low root arm rears and whips down, the forearm lagging and snapping through; the
			## raised one follows.
			"Lash": [["turn", "arm_r", X, -45.0, 45.0, "attack"], ["turn", "arm_l", X, -20.0, 30.0, "second"], ["call", "_horror_lash"],
				["turn", "upper", Y, 8.0, -8.0, "attack"], ["rear", 0.25, "attack"],
				["fx", 0.3, "swipe", {"about": "centre", "axis": X, "start": Vector3(-0.3, 1, 0.2), "radius": 1.3, "sweep": 110.0}]],
			## Throws its arms wide, the split gaping on its glowing heart, and crushes them shut.
			"Squeeze": [["turn", "arm_l", Y, 30.0, -40.0, "big"], ["turn", "arm_l", X, -25.0, 20.0, "big"],
				["turn", "arm_r", Y, -30.0, 40.0, "big"], ["turn", "arm_r", X, -15.0, 18.0, "big"], ["call", "_horror_squeeze"],
				["turn", "jaw_l", Y, 35.0, -2.0, "big"], ["turn", "jaw_r", Y, -35.0, 2.0, "big"], ["each", "split", Vector3(0.6, 0.1, 0.2), 0.0, "big"],
				["turn", "upper", X, -8.0, 8.0, "big"], ["rear", 0.35, "big"],
				["fx", 0.3, "shock", {"ahead": 0.8}], ["fx", 0.31, "shards", {"from": "centre", "off": Vector3(0, 0.3, 0.8), "color": "#6a5232", "amount": 8, "speed": 3.0}]],
			## Sinks onto its roots and drinks the soil: the split opens, sap climbing into the heart.
			"Feed": [["turn", "jaw_l", Y, 0.0, 50.0, "hold"], ["turn", "jaw_r", Y, 0.0, -50.0, "hold"], ["each", "split", 0.0, Vector3(0.6, 0.2, 0.3), "hold"],
				["each", "heart", 0.0, 0.4, "twice"], ["hop", Vector3.ZERO, Vector3(0, -0.06, 0), "hold"],
				["fx", 0.05, "rise", {"from": "feet", "color": "#9ad35a", "amount": 20}], ["fx", 0.15, "spiral", {"from": "Heart01", "color": "#9ad35a", "amount": 24}],
				["fx", 0.35, "glow", {"from": "Heart01", "color": "#9ad35a", "size": 0.5}]],
			## Flexes its arms up, its bark swelling and cracking, the heart pounding.
			"Thicken": [["turn", "arm_l", X, 0.0, -25.0, "hold"], ["turn", "arm_r", X, 0.0, -30.0, "hold"], ["call", "_horror_flex"],
				["each", "heart", 0.0, 0.5, "twice"], ["grow", "upper", 0.0, Vector3(0.06, 0.03, 0.06), "hold"],
				["fx", 0.3, "shards", {"from": "centre", "color": "#6a5232", "amount": 8, "speed": 2.0}],
				["fx", 0.3, "rise", {"from": "centre", "color": "#e0ff8a"}]],
		},
		"heavy": {
			## Squeeze held: arms flung wide and straining, the heart blazing in the gaping split,
			## bark splitting off its elbows; it crushes shut in a spray of splinters and sap.
			"Squeeze": {"at": "Heart01",
				"pose": [["each", "heart", 0.0, 0.4, "h"], ["each", "split", 0.0, Vector3(0.3, 0.05, 0.1), "h"]],
				"charge": [["charge_dust", {"seconds": 0.45}], ["glow", {"from": "Heart01", "color": "accent", "size": 0.5, "seconds": 0.55}],
					["puff", {"from": "Heart01", "color": "accent", "amount": 8, "size": 0.5, "rise": 0.3, "glow": true}],
					["shards", {"from": "ArmL03", "color": "#6a5232", "amount": 4, "speed": 1.2}], ["shards", {"from": "ArmR03", "color": "#6a5232", "amount": 4, "speed": 1.2}]],
				"impact": [["shock", {"ahead": 0.9, "size": 1.5}], ["shards", {"from": "Heart01", "color": "#6a5232", "amount": 14, "speed": 4.5}],
					["puff", {"from": "Heart01", "color": "#a8b860", "amount": 10, "size": 0.7, "rise": 0.6}], ["dust", {"amount": 60}]]},
		},
	},
	## The Tendril: a lone fiddlehead tendril of the Heartrot. It sways, and unfurls before it
	## lashes or knits; while it waits it half unrolls to taste the air, coils tighter, shivers.
	"TENDRIL": {
		"idle": "_idle_tendril",
		"lead": {"Lash": 0.45, "Knit": 0.4},
		"groups": {
			"stalk": {"chain": [["Stalk01", "Stalk34"], ["Stalk02", "Stalk03", "Stalk35", "Stalk36"], ["Stalk04", "Stalk05", "Stalk37"], ["Stalk06"],
				["Stalk07", "Stalk08"], ["Stalk09", "Stalk10"], ["Stalk11", "Stalk12", "Stalk31"], ["Stalk13", "Stalk14"], ["Stalk15", "Stalk16"],
				["Stalk17", "Stalk18", "Stalk32"], ["Stalk19", "Stalk20"], ["Stalk21", "Stalk22"], ["Stalk23", "Stalk24", "Stalk33"],
				["Stalk25", "Stalk26"], ["Stalk27", "Stalk28"], ["Stalk29", "Stalk30"]], "riders": ["Bud01", "Petal"]},
		},
		"fidget_every": [5.0, 10.0],
		"fidgets": {
			## Half unrolls and leans toward the party, its petals opening, tasting the air.
			"taste": {"length": 3.2, "hold": 1.4, "weight": 3.0, "idle": 0.0, "do": [["call", "_tendril_taste"],
				["fx", 1.3, "puff", {"from": "Bud01", "color": "#8cffb8", "amount": 5, "size": 0.35, "rise": 0.2, "glow": true}]]},
			## Coils tighter on itself, the stem bowing back, and loosens again.
			"coil": {"length": 2.6, "hold": 0.9, "weight": 2.0, "idle": 0.0, "do": [["call", "_tendril_coil"]]},
			## A shiver runs up its stalk to the bud, which pulses.
			"shiver": {"length": 2.0, "hold": 0.9, "weight": 1.5, "idle": 0.0, "do": [["call", "_tendril_shiver"],
				["fx", 1.0, "glow", {"from": "Bud01", "color": "#8cffb8", "size": 0.3}]]},
		},
		"moves": {"Lash": "_tendril_lash", "Knit": "_tendril_knit"},
	},
	## The Gardener: a crab tilling a garden on its back, a raised spade-claw and one driven into
	## the soil, eyes on stalks. A crab scuttles sideways, its eyestalks peering every way; a
	## gardener digs, pulls its spade out and knocks the dirt off it, tends the garden on its
	## back; it rams with its shell.
	"THE_GARDENER": {
		"groups": {"spade_l": {"parts": ["ClawL"], "at": "ClawL01"}, "spade_r": {"parts": ["ClawR"], "at": "ClawR01"},
			"stalk_r": {"parts": ["Eyestalk01-02"], "at": "Eyestalk01"}, "stalk_l": {"parts": ["Eyestalk03-04"], "at": "Eyestalk03"},
			"cone_r": {"parts": ["Cone01"], "at": Vector3(-0.12, 0.7, 1.0)}, "cone_l": {"parts": ["Cone02"], "at": Vector3(0.12, 0.7, 1.0)},
			"shell": {"parts": ["Core01", "Rock01", "Core02", "Eyestalk", "Cone", "ClawL", "ClawR", "Crystal"], "at": Vector3(0, 0.82, 0)},
			"garden": {"parts": ["Core02", "Crystal"], "at": "Core02"}, "plants": {"parts": ["Crystal01-08"]}, "sprouts": {"parts": ["Crystal09-12"]},
			"leg_r1": {"parts": ["Leg01-03"], "at": "Leg01"}, "leg_r2": {"parts": ["Leg04-06"], "at": "Leg04"},
			"leg_r3": {"parts": ["Leg07-09"], "at": "Leg07"}, "leg_r4": {"parts": ["Leg10-12"], "at": "Leg10"},
			"leg_l1": {"parts": ["Leg13-15"], "at": "Leg13"}, "leg_l2": {"parts": ["Leg16-18"], "at": "Leg16"},
			"leg_l3": {"parts": ["Leg19-21"], "at": "Leg19"}, "leg_l4": {"parts": ["Leg22-24"], "at": "Leg22"}},
		"idle_gestures": [["sway", "stalk_r", Y, 12.0, 0.7, 0.0], ["sway", "stalk_l", Y, 12.0, 0.7, 2.2],
			["sway", "cone_r", X, 9.0, 3.2, 0.0], ["sway", "cone_l", X, 9.0, 3.2, 1.6], ["sway", "spade_r", X, 1.5, 0.9, 0.0],
			["breathe", "shell", Vector3(0.012, 0.025, 0.012), 1.1, 0.0]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Chops the soil in front of it twice with its raised spade, flicking dirt, its eyes
			## bent down to watch.
			"dig": {"length": 2.4, "hold": 1.4, "weight": 3.0, "do": [["turn", "stalk_r", X, 0.0, 20.0, "f"], ["turn", "stalk_l", X, 0.0, 20.0, "f"],
				["turn", "spade_l", X, -16.0, 27.0, [[0.0, 0.0], [0.5, -1.0], [0.7, 1.0], [0.84, 0.85], [1.15, -1.0], [1.36, 1.0], [1.5, 0.85], [2.1, 0.0]]],
				["fx", 0.71, "puff", {"from": "ClawL05", "color": "#6a5440", "amount": 8, "size": 0.6, "rise": 0.5}],
				["fx", 0.72, "shards", {"from": "ClawL05", "color": "#6a5440", "amount": 5, "speed": 2.0}],
				["fx", 1.37, "puff", {"from": "ClawL05", "color": "#6a5440", "amount": 8, "size": 0.6, "rise": 0.5}],
				["fx", 1.38, "shards", {"from": "ClawL05", "color": "#6a5440", "amount": 5, "speed": 2.0}]]},
			## Its eyestalks peer about the room, each its own way.
			"look": {"length": 4.0, "hold": 2.6, "weight": 2.5, "do": [["gaze", "stalk_r", 35.0, 16.0, "f", 3], ["gaze", "stalk_l", 35.0, 16.0, "f", 3]]},
			## Pulls the spade out of the soil, shakes the dirt off it while its eyes look it over,
			## and drives it back in.
			"pull": {"length": 3.0, "hold": 1.4, "weight": 2.0, "do": [["turn", "spade_r", X, 0.0, -32.0, "f"],
				["turn", "spade_r", Z, -4.0, 4.0, [[0.0, 0.0], [0.9, 0.0], [1.0, 1.0], [1.1, -1.0], [1.2, 1.0], [1.3, -1.0], [1.4, 1.0], [1.5, -1.0], [1.65, 0.0]]],
				["turn", "stalk_r", Y, 0.0, -28.0, "f"], ["turn", "stalk_l", Y, 0.0, -24.0, "f"], ["turn", "stalk_r", X, 0.0, 12.0, "f"],
				["fx", 0.45, "puff", {"from": "ClawR04", "color": "#6a5440", "amount": 8, "size": 0.6, "rise": 0.4}],
				["fx", 1.05, "shards", {"from": "ClawR04", "color": "#6a5440", "amount": 6, "speed": 1.2}],
				["fx", 1.3, "shards", {"from": "ClawR04", "color": "#6a5440", "amount": 5, "speed": 1.2}],
				["fx", 2.6, "puff", {"from": "ClawR04", "color": "#6a5440", "amount": 8, "size": 0.6, "rise": 0.4}]]},
			## Scuttles a step to one side and back, crab fashion.
			"scuttle": {"length": 2.4, "hold": 0.4, "weight": 2.0, "do": [["call", "_gardener_scuttle"],
				["hop", Vector3(0.07, 0, 0), Vector3(-0.07, 0, 0), [[0.0, 0.0], [0.6, 1.0], [0.9, 1.0], [1.5, -1.0], [1.8, -1.0], [2.4, 0.0]]],
				["turn", "stalk_r", Y, 10.0, -10.0, [[0.0, 0.0], [0.6, 1.0], [0.9, 1.0], [1.5, -1.0], [1.8, -1.0], [2.4, 0.0]]],
				["turn", "stalk_l", Y, 10.0, -10.0, [[0.0, 0.0], [0.6, 1.0], [0.9, 1.0], [1.5, -1.0], [1.8, -1.0], [2.4, 0.0]]]]},
			## Tends the garden on its back: the plants glow and sway, spores lifting off them.
			"garden": {"length": 2.6, "hold": 1.2, "weight": 1.5, "do": [["each", "plants", 0.0, 0.25, "f"], ["each", "sprouts", 0.0, 0.4, "f"],
				["turn", "garden", Z, -3.0, 3.0, [[0.0, 0.0], [0.5, 1.0], [1.1, -1.0], [1.7, 1.0], [2.3, 0.0]]], ["turn", "stalk_r", X, 0.0, -18.0, "f"], ["turn", "stalk_l", X, 0.0, -18.0, "f"],
				["fx", 0.6, "puff", {"from": "Core02", "color": "accent", "amount": 8, "size": 0.6, "rise": 0.8, "glow": true}],
				["fx", 1.2, "rise", {"from": "Core02", "color": "#9ad35a", "amount": 10}]]},
		},
		"moves": {
			## Rears back on its hind legs, eyes folded flat, and drives its shell into the party.
			"Ram": [["turn", "stalk_r", X, -35.0, -25.0, "big"], ["turn", "stalk_l", X, -35.0, -25.0, "big"],
				["turn", "spade_l", X, -25.0, 20.0, "big"], ["turn", "spade_r", X, -18.0, 8.0, "big"],
				["lean", X, -8.0, 5.0, Vector3(0, 0, -0.6), "big"], ["rear", 0.6, "big"],
				["fx", 0.3, "shock", {"ahead": 1.4, "size": 1.2}], ["fx", 0.31, "puff", {"from": "Rock01", "color": "#6a5440", "amount": 10, "size": 1.0, "rise": 0.4}]],
			## Snips twice with its spade like shears, peering at what it cuts.
			"Prune": [["turn", "spade_l", X, -32.0, 28.0, "twice"], ["turn", "stalk_r", X, 0.0, 22.0, "hold"], ["turn", "stalk_l", X, 0.0, 22.0, "hold"],
				["fx", 0.29, "swipe", {"about": "spade_l", "axis": X, "start": Vector3(0, 0.5, 1), "radius": 1.0, "sweep": 90.0}],
				["fx", 0.3, "shards", {"from": "ClawL05", "color": "#9ad35a", "amount": 6, "speed": 2.0}],
				["fx", 0.53, "swipe", {"about": "spade_l", "axis": X, "start": Vector3(0, 0.5, 1), "radius": 1.0, "sweep": 90.0}],
				["fx", 0.54, "shards", {"from": "ClawL05", "color": "#9ad35a", "amount": 6, "speed": 2.0}]],
			## Looks over every creature with its eyestalks and pats the soil, its garden glowing and
			## sprinkling motes.
			"Tend": [["gaze", "stalk_r", 30.0, 10.0, "hold", 2], ["gaze", "stalk_l", 30.0, 10.0, "hold", 2],
				["turn", "spade_l", X, -10.0, 12.0, "twice"], ["each", "plants", 0.0, 0.3, "hold"],
				["fx", 0.2, "rise", {"from": "Core02", "color": "#6fe3b0", "amount": 16}],
				["fx", 0.35, "sparks", {"from": "ClawL05", "color": "#9ad35a", "amount": 8, "speed": 0.8, "life": 0.9}]],
			## Digs a hole in front of it, two chops flicking dirt, and something is set in it.
			"Plant": [["turn", "spade_l", X, -28.0, 28.0, "twice"], ["turn", "stalk_r", X, 0.0, 22.0, "hold"], ["turn", "stalk_l", X, 0.0, 22.0, "hold"],
				["fx", 0.3, "puff", {"from": "ClawL05", "color": "#6a5440", "amount": 10, "size": 0.8, "rise": 0.5}],
				["fx", 0.31, "shards", {"from": "ClawL05", "color": "#6a5440", "amount": 6, "speed": 2.2}],
				["fx", 0.54, "puff", {"from": "ClawL05", "color": "#6a5440", "amount": 10, "size": 0.8, "rise": 0.5}],
				["fx", 0.56, "sparks", {"from": "ClawL05", "color": "accent", "amount": 6, "speed": 1.0}]],
			## Drives both spades deep into the soil and the garden on its back glows and breathes
			## out spores.
			"Feed the Soil": [["turn", "spade_l", X, -20.0, 30.0, "hold"], ["turn", "spade_r", X, -10.0, 6.0, "hold"], ["each", "plants", 0.0, 0.35, "pulse"],
				["each", "sprouts", 0.0, 0.5, "pulse"], ["move", "shell", Vector3(0, 0.04, 0), Vector3(0, -0.05, 0), "hold"],
				["fx", 0.3, "puff", {"from": "ClawL05", "color": "#6a5440", "amount": 8, "size": 0.7, "rise": 0.4}],
				["fx", 0.32, "puff", {"from": "Core02", "color": "accent", "amount": 12, "size": 0.9, "rise": 0.9, "glow": true}],
				["fx", 0.35, "rise", {"from": "Core02", "color": "#9ad35a", "amount": 16}]],
			## Wrenches its planted spade out and flings a shower of soil and seed.
			"Sow": [["turn", "spade_r", X, 10.0, -38.0, "throw"], ["turn", "spade_r", Y, 0.0, 18.0, "throw"], ["turn", "stalk_r", Y, 0.0, -20.0, "hold"],
				["fx", 0.1, "puff", {"from": "ClawR04", "color": "#6a5440", "amount": 10, "size": 0.7, "rise": 0.4}],
				["fx", 0.18, "shards", {"from": "ClawR04", "color": "#6a5440", "amount": 12, "speed": 3.5}],
				["fx", 0.2, "sparks", {"from": "ClawR04", "color": "accent", "amount": 10, "speed": 2.5}]],
			## Hunkers down, eyes folded away, its spade raised and the thorns of its garden
			## bristling.
			"Thorns": [["move", "shell", Vector3.ZERO, Vector3(0, -0.07, 0), "hold"], ["turn", "stalk_r", X, 0.0, 30.0, "hold"], ["turn", "stalk_l", X, 0.0, 30.0, "hold"],
				["turn", "spade_l", X, 0.0, -18.0, "hold"], ["each", "sprouts", 0.0, 0.7, "hold"], ["each", "plants", 0.0, 0.2, "hold"],
				["fx", 0.3, "shards", {"from": "Core02", "color": "#9ad35a", "amount": 10, "speed": 2.5}]],
		},
		"heavy": {
			## Ram held: it rears higher, eyes flat, legs scrabbling and kicking dirt up behind, and
			## hits like a falling cart, soil and grit thrown everywhere.
			"Ram": {"at": "Rock01",
				"pose": [["call", "_gardener_scrabble"]],
				"charge": [["charge_dust", {"seconds": 0.5}], ["spiral", {"from": "Rock01", "color": "accent", "amount": 20}],
					["puff", {"from": "feet", "off": Vector3(0, 0.1, -0.9), "color": "#6a5440", "amount": 16, "size": 1.0, "rise": 0.5}],
					["glow", {"from": "Rock01", "color": "accent", "size": 0.45, "seconds": 0.55}]],
				"impact": [["shock", {"ahead": 1.6, "size": 1.8}], ["shards", {"from": "Rock01", "color": "#6a5440", "amount": 14, "speed": 5.0}],
					["puff", {"from": "Rock01", "color": "#6a5440", "amount": 14, "size": 1.2, "rise": 0.6}], ["dust", {"amount": 90}]]},
		},
	},
	## The Spore Mother: a bloated toad crowded with spore sacs, her brood at her feet. A toad
	## sits and breathes, its throat pumping, blinks, croaks with a swelling throat; her brood
	## hop about her, her sacs puff spores; she rears up to stamp.
	"THE_SPORE_MOTHER": {
		"mouth": "Mouth01",
		"groups": {"jaw": {"parts": ["Jaw"], "at": "Jaw01"}, "head": {"parts": ["Head", "Mouth"], "at": "Head01"}, "throat": {"parts": ["Throat01"]},
			"eye_l": {"parts": ["Head07", "Head08"], "at": Vector3(0.56, 1.92, 0.86)}, "eye_r": {"parts": ["Head03", "Head04"], "at": Vector3(-0.56, 1.92, 0.86)},
			"fore_r": {"parts": ["Leg08-12"], "at": "Leg08"}, "fore_l": {"parts": ["Leg20-24"], "at": "Leg20"},
			"sacs": {"parts": ["Core03-09"]},
			"bulk": {"parts": ["Core01", "Head", "Jaw", "Core02", "Throat01", "Core03-09", "Crystal", "Mouth01"], "at": Vector3(0, 0.95, -0.2)},
			## Everything but her hind legs, turned about her hips: rearing up on them.
			"torso": {"parts": ["Core01", "Head", "Jaw", "Core02", "Throat01", "Core03-09", "Crystal", "Mouth01", "Leg08-12", "Leg20-24"], "at": Vector3(0, 0.9, -0.75)},
			"brood1": {"parts": ["Brood01-03"], "at": "Brood01"}, "brood2": {"parts": ["Brood04-06"], "at": "Brood04"}, "brood3": {"parts": ["Brood07-09"], "at": "Brood07"}},
		"idle_gestures": [["blink", "eye_l", Vector3(1, 0.12, 1), 4.5, 0.0], ["blink", "eye_r", Vector3(1, 0.12, 1), 4.5, 0.0],
			["breathe", "throat", Vector3(0.12, 0.14, 0.1), 4.6, 0.0], ["breathe", "bulk", Vector3(0.022, 0.03, 0.022), 1.0, 0.0]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Croaks: her throat swells huge twice, the jaw parting, the sound rolling out.
			"croak": {"length": 2.2, "hold": 1.0, "weight": 3.0, "do": [
				["each", "throat", 0.0, 0.6, [[0.0, 0.0], [0.4, 1.0], [0.6, 0.25], [0.95, 1.0], [1.25, 0.2], [1.7, 0.0]]],
				["move", "throat", Vector3.ZERO, Vector3(0, -0.03, 0), [[0.0, 0.0], [0.4, 1.0], [0.6, 0.25], [0.95, 1.0], [1.25, 0.2], [1.7, 0.0]]],
				["turn", "jaw", X, 0.0, 7.0, [[0.0, 0.0], [0.4, 1.0], [0.6, 0.25], [0.95, 1.0], [1.25, 0.2], [1.7, 0.0]]], ["turn", "head", X, 0.0, -5.0, "f"],
				["fx", 0.42, "ripple", {"from": "Throat01", "color": "accent", "radius": 0.5}], ["fx", 0.97, "ripple", {"from": "Throat01", "color": "accent", "radius": 0.6}]]},
			## Her brood hop about one after another, and she looks down at them.
			"brood": {"length": 2.8, "hold": 1.6, "weight": 2.5, "do": [
				["grow", "brood1", Vector3(0.2, -0.25, 0.2), Vector3(-0.08, 0.12, -0.08), [[0.0, 0.0], [0.15, -1.0], [0.3, 1.0], [0.55, 0.0], [0.62, -0.8], [0.8, 0.0], [1.0, -1.0], [1.15, 1.0], [1.4, 0.0], [1.47, -0.8], [1.65, 0.0]]],
				["move", "brood1", Vector3.ZERO, Vector3(0, 0.22, 0), [[0.0, 0.0], [0.15, 0.0], [0.42, 1.0], [0.6, 0.0], [1.0, 0.0], [1.27, 1.0], [1.45, 0.0]]],
				["grow", "brood2", Vector3(0.2, -0.25, 0.2), Vector3(-0.08, 0.12, -0.08), [[0.35, 0.0], [0.5, -1.0], [0.65, 1.0], [0.9, 0.0], [0.97, -0.8], [1.15, 0.0]]],
				["move", "brood2", Vector3.ZERO, Vector3(0, 0.26, 0), [[0.35, 0.0], [0.5, 0.0], [0.77, 1.0], [0.95, 0.0]]],
				["grow", "brood3", Vector3(0.2, -0.25, 0.2), Vector3(-0.08, 0.12, -0.08), [[0.7, 0.0], [0.85, -1.0], [1.0, 1.0], [1.25, 0.0], [1.32, -0.8], [1.5, 0.0], [1.7, -1.0], [1.85, 1.0], [2.1, 0.0], [2.17, -0.8], [2.35, 0.0]]],
				["move", "brood3", Vector3.ZERO, Vector3(0, 0.2, 0), [[0.7, 0.0], [0.85, 0.0], [1.12, 1.0], [1.3, 0.0], [1.7, 0.0], [1.97, 1.0], [2.15, 0.0]]],
				["turn", "head", X, 0.0, 6.0, "f"]]},
			## The sacs on her back swell and puff spores up one after another, her bulk shivering.
			"spores": {"length": 2.4, "hold": 1.0, "weight": 2.0, "do": [["each", "sacs", 0.0, 0.35, "f"], ["tremble", "bulk", 0.006, "f"],
				["fx", 0.6, "puff", {"from": "Core03", "color": "accent", "amount": 8, "size": 0.5, "rise": 0.9, "glow": true}],
				["fx", 0.9, "puff", {"from": "Core05", "color": "accent", "amount": 8, "size": 0.5, "rise": 0.9, "glow": true}],
				["fx", 1.2, "puff", {"from": "Core04", "color": "accent", "amount": 8, "size": 0.5, "rise": 0.9, "glow": true}]]},
			## Her eyes roll about in their turrets to look one way and the other, and blink.
			"look": {"length": 3.0, "weight": 2.0, "do": [
				["turn", "eye_l", Y, -24.0, 24.0, [[0.0, 0.0], [0.4, 1.0], [1.2, 1.0], [1.6, -1.0], [2.4, -1.0], [2.8, 0.0]]],
				["turn", "eye_r", Y, -24.0, 24.0, [[0.0, 0.0], [0.4, 1.0], [1.2, 1.0], [1.6, -1.0], [2.4, -1.0], [2.8, 0.0]]],
				["turn", "head", Y, -3.0, 3.0, [[0.0, 0.0], [0.5, 1.0], [1.2, 1.0], [1.7, -1.0], [2.4, -1.0], [2.8, 0.0]]]]},
			## Gulps: the throat drawn in and the head bobbing, a swallow.
			"gulp": {"length": 1.8, "hold": 0.4, "weight": 1.5, "do": [["each", "throat", Vector3(-0.18, -0.22, -0.18), 0.3, [[0.0, 0.0], [0.35, -1.0], [0.6, 1.0], [1.0, 0.0]]],
				["turn", "head", X, -4.0, 6.0, [[0.0, 0.0], [0.35, -1.0], [0.6, 1.0], [1.0, 0.0]]], ["turn", "jaw", X, 0.0, -2.0, "f"]]},
		},
		"moves": {
			## Heaves her bulk side to side and flops it forward at the party.
			"Writhe": [["turn", "bulk", Z, -4.0, 4.0, "shake"], ["turn", "bulk", X, -5.0, 6.0, "attack"], ["each", "sacs", 0.0, 0.25, "pulse"],
				["rear", 0.25, "attack"], ["fx", 0.3, "shock", {"ahead": 1.4, "size": 1.0}],
				["fx", 0.32, "puff", {"from": "Core03", "color": "accent", "amount": 8, "size": 0.6, "rise": 0.6, "glow": true}]],
			## Breathes in, throat swelling, and gapes out a cloud of spores.
			"Spore": [["turn", "jaw", X, 0.0, 18.0, "hold"], ["turn", "head", X, 0.0, -10.0, "hold"], ["each", "throat", 0.35, 0.1, "breath"],
				["move", "throat", Vector3(0, -0.03, 0), Vector3(0, -0.06, 0), "breath"], ["each", "sacs", 0.0, 0.2, "pulse"],
				["fx", 0.27, "breath", {"kind": "spores", "color": "#b8c84a", "seconds": 0.55, "size": 1.3}],
				["fx", 0.3, "puff", {"from": "Mouth01", "color": "#c8d06a", "amount": 14, "size": 1.5, "glow": true}]],
			## Coughs twice, her throat pumping, a choking cloud rolling low out of her mouth.
			"Choke": [["turn", "jaw", X, 0.0, 16.0, "twice"], ["turn", "head", X, 5.0, -10.0, "twice"], ["each", "throat", 0.4, 0.05, "twice"],
				["move", "throat", Vector3(0, -0.03, 0), Vector3(0, -0.05, 0), "twice"],
				["fx", 0.27, "breath", {"kind": "spores", "color": "#8a9a4a", "seconds": 0.55, "size": 1.3}],
				["fx", 0.3, "puff", {"from": "Mouth01", "color": "#7a8a3a", "amount": 10, "size": 1.0, "rise": 0.05}],
				["fx", 0.54, "puff", {"from": "Mouth01", "color": "#7a8a3a", "amount": 10, "size": 1.0, "rise": 0.05}]],
			## Gapes wide and belches rot, bubbling at the lips.
			"Rot": [["turn", "jaw", X, 0.0, 22.0, "breath"], ["turn", "head", X, 0.0, -12.0, "breath"], ["each", "throat", 0.4, 0.1, "breath"],
				["move", "throat", Vector3(0, -0.03, 0), Vector3(0, -0.07, 0), "breath"],
				["fx", 0.27, "breath", {"kind": "spores", "color": "#7a6a3a", "seconds": 0.55, "size": 1.3}],
				["fx", 0.3, "bubbles", {"from": "Mouth01", "color": "#8a7a3a", "amount": 14}]],
			## Every sac on her back bursts into bloom at once, spores pouring off her.
			"Bloom": [["each", "throat", 0.0, 0.7, "hold"], ["each", "sacs", 0.0, 0.5, "hold"], ["turn", "jaw", X, 0.0, 20.0, "hold"], ["turn", "head", X, 0.0, -12.0, "hold"],
				["fx", 0.3, "puff", {"from": "centre", "color": "#d8e07a", "amount": 30, "size": 2.2, "rise": 1.2, "glow": true}],
				["fx", 0.3, "breath", {"kind": "spores", "color": "#d8e07a", "seconds": 0.6, "size": 1.8}],
				["fx", 0.34, "puff", {"from": "Core04", "color": "accent", "amount": 10, "size": 0.7, "rise": 1.0, "glow": true}],
				["fx", 0.38, "puff", {"from": "Core05", "color": "accent", "amount": 10, "size": 0.7, "rise": 1.0, "glow": true}]],
			## Rears up on her hind legs, both forefeet lifting high, and slams them down.
			"Stamp": [["turn", "fore_r", X, -40.0, 6.0, "big"], ["turn", "fore_l", X, -40.0, 6.0, "big"], ["turn", "torso", X, -9.0, 4.0, "big"],
				["move", "brood1", Vector3.ZERO, Vector3(0, 0.16, 0), [[0.0, 0.0], [0.3, 0.0], [0.4, 1.0], [0.52, 0.0], [0.58, 0.3], [0.66, 0.0]]],
				["move", "brood2", Vector3.ZERO, Vector3(0, 0.2, 0), [[0.0, 0.0], [0.31, 0.0], [0.41, 1.0], [0.54, 0.0], [0.6, 0.3], [0.68, 0.0]]],
				["move", "brood3", Vector3.ZERO, Vector3(0, 0.16, 0), [[0.0, 0.0], [0.32, 0.0], [0.42, 1.0], [0.55, 0.0], [0.61, 0.3], [0.69, 0.0]]],
				["fx", 0.3, "shock", {"from": "Leg10", "size": 1.0}], ["fx", 0.3, "shock", {"from": "Leg22", "size": 1.0}], ["fx", 0.32, "dust", {"amount": 50}]],
			## Shudders and sheds her old skin, flakes falling away and her sacs puffing clean.
			"Shed": [["tremble", "bulk", 0.012, "hold"], ["each", "sacs", 0.0, 0.3, "pulse"], ["turn", "head", X, 0.0, -6.0, "hold"],
				["fx", 0.25, "shards", {"from": "centre", "off": Vector3(0, 0.4, 0), "color": "#d8d0a0", "amount": 12, "speed": 1.5}],
				["fx", 0.3, "puff", {"from": "centre", "color": "#9ad35a", "amount": 20, "size": 2.0, "glow": true}]],
			## Her brood hop about her excitedly as she lifts her head and croaks for more.
			"Brood": [["move", "brood1", Vector3.ZERO, Vector3(0, 0.35, 0), "twice"], ["move", "brood2", Vector3.ZERO, Vector3(0, 0.35, 0), "second"],
				["move", "brood3", Vector3.ZERO, Vector3(0, 0.35, 0), "twice"], ["each", "throat", 0.0, 0.4, "twice"], ["turn", "head", X, 0.0, -8.0, "hold"],
				["fx", 0.3, "ripple", {"from": "Throat01", "color": "accent", "radius": 0.6}]],
		},
		"heavy": {
			## Stamp held: she rears higher, throat and sacs swelling with the breath she holds, the
			## brood cowering; both forefeet come down like a landslide, spores bursting off her back.
			"Stamp": {"at": "Throat01",
				"pose": [["each", "throat", 0.0, 0.22, "h"], ["each", "sacs", 0.0, 0.3, "h"]],
				"charge": [["charge_dust", {"seconds": 0.5}], ["spiral", {"from": "Throat01", "color": "accent", "amount": 22}],
					["puff", {"from": "Core03", "color": "accent", "amount": 10, "size": 0.5, "rise": 0.6, "glow": true}]],
				"impact": [["shock", {"ahead": 1.2, "size": 1.8}], ["dust", {"amount": 90}],
					["shards", {"from": "Leg10", "color": "#8a7a5a", "amount": 8, "speed": 4.0}], ["shards", {"from": "Leg22", "color": "#8a7a5a", "amount": 8, "speed": 4.0}],
					["puff", {"from": "Core03", "color": "accent", "amount": 14, "size": 0.8, "rise": 1.2, "glow": true}]]},
		},
	},
	## The Heartrot: a rotting gem heart rooted in the floor, three barbed tendrils round it. A
	## heart beats, slow and double; its tendrils writhe, reach out to taste the air and clench
	## in over it; rot oozes from it; it whips its tendrils down at the party.
	"THE_HEARTROT": {
		"idle": "_idle_heartrot",
		## Its tendrils are turned and bent at their knuckles by the functions below (HEARTROT_TENDRILS).
		"groups": {"heart": {"parts": ["Heart"], "at": "Heart01"}, "core": {"parts": ["Heart05"], "at": Vector3(0, 2.15, 0.62)},
			"tendrils": {"parts": ["Tendril"], "at": Vector3.ZERO}, "barb": {"parts": ["Tendril04"]}},
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Its heart pounds hard, twice over, the core gem flaring, its tendrils flinching.
			"throb": {"length": 2.4, "weight": 3.0, "idle": 0.35, "do": [
				["grow", "heart", 0.0, 0.1, [[0.0, 0.0], [0.1, 1.0], [0.24, 0.15], [0.34, 0.75], [0.6, 0.0], [1.1, 1.0], [1.24, 0.15], [1.34, 0.75], [1.6, 0.0]]],
				["grow", "core", 0.0, 0.5, [[0.0, 0.0], [0.1, 1.0], [0.24, 0.15], [0.34, 0.75], [0.6, 0.0], [1.1, 1.0], [1.24, 0.15], [1.34, 0.75], [1.6, 0.0]]],
				["splay", "tendrils", 0.0, -4.0, [[0.0, 0.0], [0.12, 1.0], [0.6, 0.0], [1.12, 1.0], [1.6, 0.0]]],
				["fx", 0.1, "glow", {"from": "Heart05", "color": "accent", "size": 0.45}], ["fx", 1.1, "glow", {"from": "Heart05", "color": "accent", "size": 0.45}],
				["fx", 1.15, "puff", {"from": "Heart05", "color": "#6a7a3a", "amount": 8, "size": 0.6, "rise": 0.4}]]},
			## Its tendrils writhe one after another, curling and uncurling.
			"writhe": {"length": 3.4, "hold": 2.0, "weight": 2.5, "do": [["call", "_heartrot_writhe"]]},
			## The front tendril leans out toward the party, its barb twitching, tasting the air.
			"reach": {"length": 3.0, "hold": 1.4, "weight": 2.0, "do": [["call", "_heartrot_reach"],
				["tremble", "barb", 0.01, [[0.0, 0.0], [1.0, 0.0], [1.2, 1.0], [1.9, 1.0], [2.1, 0.0]]]]},
			## It squeezes, rot oozing and dripping from its hanging point, bubbling on the roots.
			"ooze": {"length": 2.6, "hold": 1.0, "weight": 1.5, "do": [["grow", "heart", 0.0, Vector3(0.04, -0.05, 0.04), "f"],
				["fx", 0.7, "sparks", {"from": "Heart04", "off": Vector3(0, -0.25, 0), "color": "#6a7a2a", "amount": 4, "speed": 0.3, "life": 1.0}],
				["fx", 1.2, "sparks", {"from": "Heart04", "off": Vector3(0, -0.25, 0), "color": "#6a7a2a", "amount": 4, "speed": 0.3, "life": 1.0}],
				["fx", 1.0, "bubbles", {"from": "feet", "off": Vector3(0, 0.1, 0), "color": "#7a8a3a", "amount": 10}]]},
			## Its tendrils clench in over the heart, squeezing it, and let go with a beat.
			"clench": {"length": 2.6, "hold": 0.8, "weight": 1.5, "do": [["call", "_heartrot_clench"],
				["grow", "heart", 0.0, Vector3(-0.05, -0.04, -0.05), "f"],
				["fx", 1.7, "puff", {"from": "Heart05", "color": "#6a7a3a", "amount": 8, "size": 0.7, "rise": 0.5}]]},
		},
		"moves": {
			## The front-left tendril rears back and whips down at the party, its top half lashing
			## through after; the other follows a little.
			"Rot": [["call", "_heartrot_rot"], ["grow", "heart", 0.0, 0.12, "pulse"],
				["fx", 0.3, "swipe", {"about": "centre", "axis": X, "start": Vector3(0, 1, -0.3), "radius": 1.6, "sweep": 100.0}]],
			## Both front tendrils rear back together and whip down one after the other.
			"Double Rot": [["call", "_heartrot_double"], ["grow", "heart", 0.0, 0.12, "twice"],
				["fx", 0.3, "swipe", {"about": "centre", "axis": X, "start": Vector3(0.3, 1, -0.3), "radius": 1.6, "sweep": 100.0}],
				["fx", 0.54, "swipe", {"about": "centre", "axis": X, "start": Vector3(-0.3, 1, -0.3), "radius": 1.6, "sweep": 100.0}],
				["fx", 0.55, "shock", {"ahead": 1.6, "size": 1.0}]],
			## The heart heaves twice, its tendrils thrown open, and breathes out a cloud of rot.
			"Miasma": [["grow", "heart", 0.0, 0.18, "twice"], ["splay", "tendrils", 0.0, -12.0, "hold"],
				["fx", 0.25, "breath", {"from": "Heart05", "kind": "spores", "color": "#6a7a3a", "seconds": 0.5, "size": 1.5}],
				["fx", 0.3, "puff", {"from": "Heart05", "color": "#7a8a3a", "amount": 20, "size": 2.0}],
				["fx", 0.35, "bubbles", {"from": "Heart05", "color": "#8a9a3a", "amount": 14}]],
			## Its tendrils reach down to the floor and the heart pounds: a new one is called up.
			"Regrow": [["call", "_heartrot_regrow"], ["grow", "heart", 0.0, 0.2, "twice"],
				["fx", 0.3, "rise", {"from": "Heart05", "color": "#9ad35a"}],
				["fx", 0.32, "shards", {"from": "feet", "off": Vector3(0, 0.1, 0.8), "color": "#5a7a2a", "amount": 8, "speed": 2.5}]],
		},
		"heavy": {
			## Double Rot held: both front tendrils reared far back, the heart swelling and its core
			## blazing, rot gathering round it; the first lash lands in a burst of rot and grit.
			"Double Rot": {"at": "Heart05", "wind": 0.22,
				"pose": [["grow", "heart", 0.0, 0.08, "h"], ["grow", "core", 0.0, 0.5, "h"]],
				"charge": [["charge_dust", {"seconds": 0.5}], ["spiral", {"from": "Heart05", "color": "accent", "amount": 24}],
					["glow", {"from": "Heart05", "color": "accent", "size": 0.5, "seconds": 0.55}],
					["puff", {"from": "Heart05", "color": "#5a6a2a", "amount": 14, "size": 1.0, "rise": 0.4}]],
				"impact": [["shock", {"ahead": 1.6, "size": 1.6}], ["shards", {"from": "feet", "off": Vector3(0.6, 0.2, 1.8), "color": "#6a7a2a", "amount": 12, "speed": 4.0}],
					["puff", {"from": "feet", "off": Vector3(0.6, 0.3, 1.8), "color": "#5a6a2a", "amount": 14, "size": 1.2, "rise": 0.5}], ["dust", {"amount": 80}]]},
		},
	},
	## The Puffball: a round puffball fungus. It breathes, swelling and settling, wobbles like a
	## jelly, coughs spores, and swells up to burst.
	"PUFFBALL": {
		"groups": {"all": {"parts": ["Core", "Crystal"], "at": Vector3(0, 0.12, 0)}, "sprouts": {"parts": ["Crystal"]}},
		"idle_gestures": [["breathe", "all", Vector3(0.035, 0.05, 0.035), 1.25, 0.0], ["sway", "all", Z, 1.6, 1.7, 0.0], ["sway", "all", X, 1.2, 1.3, 1.0]],
		"fidget_every": [5.0, 10.0],
		"fidgets": {
			## Jiggles like a jelly: squashed and stretched, tipping, settling.
			"wobble": {"length": 1.6, "weight": 3.0, "do": [
				["grow", "all", Vector3(0.07, -0.08, 0.07), Vector3(-0.04, 0.07, -0.04), [[0.0, 0.0], [0.18, -1.0], [0.36, 1.0], [0.54, -0.7], [0.72, 0.5], [0.9, -0.3], [1.08, 0.15], [1.3, 0.0]]],
				["turn", "all", Z, -4.0, 4.0, [[0.0, 0.0], [0.25, 1.0], [0.5, -0.8], [0.75, 0.5], [1.0, -0.25], [1.3, 0.0]]]]},
			## Squeezes itself and coughs a puff of spores from its top.
			"puff": {"length": 1.8, "weight": 2.5, "do": [["grow", "all", Vector3(0.06, -0.1, 0.06), Vector3(-0.03, 0.06, -0.03), [[0.0, 0.0], [0.5, -1.0], [0.62, 1.0], [0.85, -0.2], [1.1, 0.0]]],
				["fx", 0.62, "puff", {"from": "Crystal02", "color": "accent", "amount": 12, "size": 0.8, "rise": 0.8, "glow": true}]]},
			## The crystal sprouts on its top twitch and shine.
			"sprouts": {"length": 2.0, "hold": 0.8, "weight": 1.5, "do": [["each", "sprouts", 0.0, 0.4, "f"], ["turn_each", "sprouts", Z, -6.0, 6.0, "shake"],
				["fx", 0.7, "puff", {"from": "Crystal01", "color": "accent", "amount": 4, "size": 0.3, "rise": 0.3, "glow": true}]]},
		},
		"moves": {
			## Squeezes in, then swells up big and trembling with the spores it holds.
			"Swell": [["grow", "all", Vector3(0.05, -0.06, 0.05), 0.22, [[0.0, 0.0], [0.15, -0.6], [0.3, 1.0], [0.5, 0.75], [0.9, 0.0]]], ["tremble", "all", 0.012, "hold"],
				["each", "sprouts", 0.0, 0.4, "pulse"],
				["fx", 0.3, "puff", {"from": "centre", "color": "#9ad35a", "amount": 10, "size": 0.8, "glow": true}]],
			## Swells and stays swollen, its sprouts shining.
			"Bloat": [["grow", "all", 0.0, 0.18, "hold"], ["each", "sprouts", 0.0, 0.5, "hold"],
				["fx", 0.3, "rise", {"from": "centre", "color": "#6fe3b0"}], ["fx", 0.3, "puff", {"from": "centre", "color": "#9ad35a", "amount": 8, "size": 0.7, "glow": true}]],
			## Swells up fast, shuddering, and bursts in a cloud of spores.
			"Burst": [["grow", "all", Vector3(0.08, -0.1, 0.08), 0.32, "pulse"], ["tremble", "all", 0.018, "attack"],
				["fx", 0.3, "puff", {"from": "centre", "color": "#9ad35a", "amount": 30, "size": 2.0, "glow": true}]],
		},
	},
}

# --- the moves and idles no table says ---------------------------------------------------------

static func _keyed(clip: Dictionary) -> float:
	## Where a played gesture stands in its keys (a heavy blow's held at its wind).
	return float(clip.get("keyed", float(clip.t) - float(clip.get("shift", 0.0))))

static func _swing(v: float, wind: float, strike: float) -> float:
	## An envelope's angle: the wind angle at -1, the strike angle at +1 (degrees in, radians out).
	return deg_to_rad(wind * -v if v < 0.0 else strike * v)

static func _now(m: Node3D, part: Node3D, at: Vector3) -> Vector3:
	## Where a point riding on a part is this frame: its rest place carried by the part's own idle
	## swing and by whatever this frame has laid on it so far. A bend there turns about the knee
	## where it is now, so a swinging arm or tendril never comes apart at its elbow.
	var rest: Transform3D = part.get("_rest")
	var laid: Transform3D = m._offsets.get(part, Transform3D.IDENTITY)
	return laid * (part.transform * (rest.affine_inverse() * at))

static func _bend(m: Node3D, lead: String, tip: String, knee: Vector3, axis: Vector3, angle: float) -> void:
	## What rides past a limb's knee (`tip`) turned about that knee where it is now (`lead` is
	## the part that ends at it).
	if absf(angle) < 0.00001:
		return
	var first: Array = m._select(lead)
	var parts: Array = m._select(tip)
	if first.is_empty() or parts.is_empty():
		return
	m.turn(parts, _now(m, first[0], knee), axis, angle)

static func _crawl(m: Node3D, legs: Array, t: float, rate: float, deg: float, k: float) -> void:
	## A crawl in place: each foot lifted off the floor and set down again, a beat after the one
	## before (about its hip, on its own lift axis), never pushed into the floor; `k` fades it.
	if absf(k) < 0.0001:
		return
	for leg in legs:
		var up: float = maxf(0.0, sin(t * rate - float(leg[2])))
		var gr: Dictionary = m.group(str(leg[0]))
		m.turn(gr.parts, gr.joint, leg[1], deg_to_rad(deg) * up * up * k)

# --- the Cap Shambler ----------------------------------------------------------------------------

static func _shambler_shuffle(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its roots lift one after another round its mass while its weight sways over them.
	var t: float = _keyed(clip)
	var f: float = m._v(clip, "f", t)
	_crawl(m, SHAMBLER_LEGS, t, 6.5, 15.0, f)
	var mass: Dictionary = m.group("mass")
	m.turn(mass.parts, mass.joint, Vector3.BACK, deg_to_rad(3.0) * sin(t * 3.25) * f)
	m.shift(mass.parts, Vector3(0, -0.015 * (0.5 - 0.5 * cos(t * 6.5)), 0) * f)

# --- the Root Horror -----------------------------------------------------------------------------

static func _horror_lash(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The forearms lag behind their shoulders and snap through: the low arm's hardest.
	var t: float = _keyed(clip)
	_bend(m, "ArmR01", "ArmR02-03", HORROR_ELBOW_R, Vector3.RIGHT, _swing(m._v(clip, "attack", t), -25.0, 30.0))
	_bend(m, "ArmL01", "ArmL02-03", HORROR_ELBOW_L, Vector3.RIGHT, _swing(m._v(clip, "second", t), -15.0, 20.0))

static func _horror_squeeze(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The forearms thrown open and then curled in round what they crush.
	var v: float = m._v(clip, "big", _keyed(clip))
	_bend(m, "ArmL01", "ArmL02-03", HORROR_ELBOW_L, Vector3.UP, _swing(v, 15.0, -35.0))
	_bend(m, "ArmR01", "ArmR02-03", HORROR_ELBOW_R, Vector3.UP, _swing(v, -15.0, 35.0))

static func _horror_flex(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Both forearms curled up hard, like a strongman's.
	var v: float = m._v(clip, "hold", _keyed(clip))
	_bend(m, "ArmL01", "ArmL02-03", HORROR_ELBOW_L, Vector3.RIGHT, _swing(v, 0.0, -30.0))
	_bend(m, "ArmR01", "ArmR02-03", HORROR_ELBOW_R, Vector3.RIGHT, _swing(v, 0.0, -35.0))

static func _horror_stretch(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The forearms reach up as it stretches, and creak a little at the top.
	var t: float = _keyed(clip)
	var f: float = m._v(clip, "f", t)
	var creak: float = 1.0 + 0.12 * sin(t * 9.0) * f
	_bend(m, "ArmL01", "ArmL02-03", HORROR_ELBOW_L, Vector3.RIGHT, deg_to_rad(-22.0) * f * creak)
	_bend(m, "ArmR01", "ArmR02-03", HORROR_ELBOW_R, Vector3.RIGHT, deg_to_rad(-26.0) * f * creak)

static func _horror_creep(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Each root leg in turn lifts, creeps round a little and grips the floor again, a puff of
	## dirt as it sets down.
	var t: float = _keyed(clip)
	var weight: float = float(clip.get("weight", 1.0))
	for i in range(HORROR_LEGS.size()):
		var start: float = 0.3 + float(i) * 0.38
		var x: float = clampf((t - start) / 0.55, 0.0, 1.0)
		var up: float = sin(x * PI) * weight
		if up > 0.0001:
			var gr: Dictionary = m.group(str(HORROR_LEGS[i][0]))
			m.turn(gr.parts, gr.joint, Vector3.UP, deg_to_rad(7.0) * up)
			m.turn(gr.parts, gr.joint, HORROR_LEGS[i][1], deg_to_rad(12.0) * up)
		if x >= 1.0:
			m._queue(clip, "dirt%d" % i, "puff", {"from": "Leg%02d" % (i * 3 + 3), "off": Vector3(0, -0.3, 0), "color": "#6a5440", "amount": 4, "size": 0.4, "rise": 0.2})
	var upper: Dictionary = m.group("upper")
	m.turn(upper.parts, upper.joint, Vector3.BACK, deg_to_rad(1.5) * sin(t * 4.0) * m._v(clip, "f", t))

# --- the Gardener ----------------------------------------------------------------------------------

static func _gardener_scuttle(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its legs stepping as it goes, a crab's two sets of four in turn.
	var t: float = _keyed(clip)
	var moving: float = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(2.15, 2.4, t))
	_crawl(m, GARDENER_LEGS, t, 10.0, 9.0, moving * float(clip.get("weight", 1.0)))

static func _gardener_scrabble(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its legs scrabbling at the floor while it holds a heavy Ram back.
	_crawl(m, GARDENER_LEGS, float(clip.t), 24.0, 8.0, m._hold_env(clip))

# --- the Heartrot --------------------------------------------------------------------------------

static func _idle_heartrot(m: Node3D, clock: float, weight: float) -> void:
	## Its slow double heartbeat, and its tendrils writhing: each one's top half curling in over
	## the heart and out again a beat behind its stem.
	_idle_heartbeat(m, clock, weight)
	for i in range(HEARTROT_TENDRILS.size()):
		var s: float = clock * 0.75 + float(i) * 2.1
		_tendril_turn(m, i, HEARTROT_TENDRILS[i][4], deg_to_rad(2.5 * sin(s)) * weight, HEARTROT_TENDRILS[i][4], deg_to_rad(7.0 * sin(s - 0.9)) * weight)

static func _tendril_turn(m: Node3D, i: int, root_axis: Vector3, root: float, knee_axis: Vector3, knee: float) -> void:
	## One of the Heartrot's tendrils turned at its base (radians) and bent at its knuckle.
	var spec: Array = HEARTROT_TENDRILS[i]
	if absf(root) > 0.00001:
		m.turn(m._select([spec[0], spec[1]]), spec[2], root_axis, root)
	_bend(m, spec[0], spec[1], spec[3], knee_axis, knee)

static func _heartrot_rot(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The front-left tendril rears back and whips down at the party, the right one after it.
	var t: float = _keyed(clip)
	var a: float = m._v(clip, "attack", t)
	var b: float = m._v(clip, "second", t)
	_flare(m, 0, 16.0 * maxf(0.0, -a))
	_tendril_turn(m, 0, Vector3.RIGHT, _swing(a, -15.0, 38.0), Vector3.RIGHT, _swing(a, -18.0, 26.0))
	_tendril_turn(m, 1, Vector3.RIGHT, _swing(b, -8.0, 16.0), Vector3.RIGHT, _swing(b, -10.0, 12.0))

static func _flare(m: Node3D, i: int, deg: float) -> void:
	## A tendril swung out from the heart at its base as it winds back, so the party sees it rear.
	if absf(deg) > 0.001:
		var spec: Array = HEARTROT_TENDRILS[i]
		m.turn(m._select([spec[0], spec[1]]), spec[2], spec[4], deg_to_rad(deg))

static func _heartrot_double(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Both front tendrils rear back together; the left whips down, then the right; the one
	## behind rises over the heart on each.
	var t: float = _keyed(clip)
	var a: float = m._v(clip, ROT_FIRST, t)
	var b: float = m._v(clip, ROT_SECOND, t)
	var c: float = m._v(clip, "twice", t)
	_flare(m, 0, 20.0 * maxf(0.0, -a))
	_flare(m, 1, 20.0 * maxf(0.0, -b))
	_tendril_turn(m, 0, Vector3.RIGHT, _swing(a, -18.0, 40.0), Vector3.RIGHT, _swing(a, -22.0, 28.0))
	_tendril_turn(m, 1, Vector3.RIGHT, _swing(b, -18.0, 40.0), Vector3.RIGHT, _swing(b, -22.0, 28.0))
	_tendril_turn(m, 2, HEARTROT_TENDRILS[2][4], _swing(c, 6.0, -10.0), HEARTROT_TENDRILS[2][4], _swing(c, 10.0, -16.0))

static func _heartrot_regrow(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Every tendril reaches out and down to the floor, calling another up.
	var v: float = m._v(clip, "hold", _keyed(clip))
	for i in range(HEARTROT_TENDRILS.size()):
		var out: Vector3 = HEARTROT_TENDRILS[i][4]
		_tendril_turn(m, i, out, _swing(v, 0.0, 16.0), out, _swing(v, 0.0, 34.0))

static func _heartrot_writhe(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Each tendril in turn curls its top half in and out and sways at its base.
	var t: float = _keyed(clip)
	var f: float = m._v(clip, "f", t)
	for i in range(HEARTROT_TENDRILS.size()):
		var out: Vector3 = HEARTROT_TENDRILS[i][4]
		var s: float = t * 3.2 - float(i) * 1.4
		var side: Vector3 = Vector3.UP.cross(out).normalized()
		_tendril_turn(m, i, side, deg_to_rad(6.0 * sin(s * 0.5)) * f, out, deg_to_rad(18.0 * sin(s)) * f)

static func _heartrot_reach(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The front-left tendril leans out at the party, its top half reaching further.
	var t: float = _keyed(clip)
	var f: float = m._v(clip, "f", t)
	var sniff: float = 1.0 + 0.15 * sin(t * 7.0) * smoothstep(0.9, 1.2, t) * (1.0 - smoothstep(1.9, 2.2, t))
	_tendril_turn(m, 0, Vector3.RIGHT, deg_to_rad(14.0) * f, Vector3.RIGHT, deg_to_rad(20.0) * f * sniff)

static func _heartrot_clench(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## All three tendrils curl in over the heart.
	var f: float = m._v(clip, "f", _keyed(clip))
	for i in range(HEARTROT_TENDRILS.size()):
		var out: Vector3 = HEARTROT_TENDRILS[i][4]
		_tendril_turn(m, i, out, deg_to_rad(-8.0) * f, out, deg_to_rad(-22.0) * f)

# --- the Tendril: unfurls before it lashes or knits ----------------------------------------------

## The axis its curl winds about (up x the curl's facing), and how far each curl joint winds:
## straightening it is the same turns backwards, from the stalk top out.
const TENDRIL_AXIS := Vector3(0.766, 0.0, -0.643)

const TENDRIL_CURL: Array = [26.5, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0]

## Each petal opens (tips outward and down) about up x its pointing.
const PETAL_AXES: Array = [Vector3(0.362, 0, -0.855), Vector3(0.56, 0, 0.741), Vector3(-0.921, 0, 0.114)]

static func _tendril_pose(m: Node3D, unfurl: float, bend: float, whip: float, sway: float = 0.0) -> void:
	## Unrolled by `unfurl` (0 curled, 1 standing straight up), the base of the curl first; the
	## stem bent toward the party by `bend` degrees a joint, the unrolled whip by `whip` a joint.
	var chain: Array = m.group("stalk").chain
	if chain.size() < 16:
		return
	var curl: Array = [0.0, 0.0, 0.0]
	for j in range(TENDRIL_CURL.size()):
		var start: float = float(j) / 12.0 * 0.55
		curl.append(deg_to_rad(-float(TENDRIL_CURL[j])) * smoothstep(start, start + 0.45, unfurl) + deg_to_rad(sway * 0.5))
	m.chain_turns(chain, TENDRIL_AXIS, curl)
	var stem: Array = []
	for index in range(16):
		if index < 3:
			stem.append(deg_to_rad(bend + sway))
		else:
			stem.append(deg_to_rad(whip) * unfurl)
	m.chain_turns(chain, Vector3.RIGHT, stem)

static func _idle_tendril(m: Node3D, clock: float, weight: float) -> void:
	## A slight sway, the stem most.
	_tendril_pose(m, 0.0, 0.0, 0.0, 2.2 * sin(clock * 0.9) * weight)
	var chain: Array = m.group("stalk").chain
	if chain.size() >= 3:
		m.chain_turns(chain, Vector3.BACK, [deg_to_rad(1.6 * sin(clock * 0.7 + 1.0)) * weight, deg_to_rad(1.2 * sin(clock * 0.7 + 1.0)) * weight])

static func _tendril_lash(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Unrolls to its full height, rears back and whips down at the party, and curls up again.
	var t: float = float(clip.t)
	var hit: float = HIT + float(clip.shift)
	var unfurl: float = smoothstep(0.0, hit - 0.12, t) * (1.0 - smoothstep(hit + 0.35, hit + 0.8, t))
	var back: float = smoothstep(hit - 0.25, hit - 0.08, t) * (1.0 - smoothstep(hit - 0.08, hit, t))
	var strike: float = smoothstep(hit - 0.08, hit, t) * (1.0 - smoothstep(hit + 0.12, hit + 0.45, t))
	_tendril_pose(m, unfurl, -10.0 * back + 15.0 * strike, -2.0 * back + 3.2 * strike)
	var bud: Array = m._select(["Bud01"])
	if not bud.is_empty():
		m.swell(bud, m.centre_of(bud[0]), Vector3.ONE * (1.0 + 0.5 * smoothstep(0.0, hit, t) * (1.0 - smoothstep(hit, hit + 0.4, t))))
	if t >= hit - 0.01:
		m._queue(clip, "swipe", "swipe", {"about": "centre", "axis": Vector3.RIGHT, "start": Vector3(0, 1, -0.2), "radius": 1.6, "sweep": 100.0})
		m._queue(clip, "shock", "shock", {"ahead": 1.8, "size": 0.8})

static func _tendril_knit(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Half unrolls, the bud blazing and its petals open, mends, and curls up again.
	var t: float = float(clip.t)
	var hit: float = HIT + float(clip.shift)
	var unfurl: float = 0.55 * smoothstep(0.0, hit, t) * (1.0 - smoothstep(hit + 0.5, float(clip.length) - 0.05, t))
	var glow: float = smoothstep(hit - 0.15, hit, t) * (1.0 - smoothstep(hit + 0.4, hit + 0.8, t))
	_petals(m, 35.0 * glow)
	_tendril_pose(m, unfurl, 0.0, 0.0)
	var bud: Array = m._select(["Bud01"])
	if not bud.is_empty():
		m.swell(bud, m.centre_of(bud[0]), Vector3.ONE * (1.0 + 0.6 * glow))
	if t >= hit:
		m._queue(clip, "glow", "glow", {"from": "Bud01", "color": "#8cffb8", "size": 1.2})
		m._queue(clip, "rise", "rise", {"from": "Bud01", "color": "#6fe3b0", "amount": 26})

static func _petals(m: Node3D, deg: float) -> void:
	## The three petals round the bud opened (tipped outward and down) by so many degrees, each
	## about its own base: laid before the stalk's turns, which carry them.
	if absf(deg) < 0.001:
		return
	for i in range(PETAL_AXES.size()):
		var petal: Array = m._select("Petal%02d" % (i + 1))
		if not petal.is_empty():
			m.turn(petal, (petal[0] as Node3D).get("_rest").origin, PETAL_AXES[i], deg_to_rad(deg))

static func _tendril_still(m: Node3D, unfurl: float, bend: float, tight: float, stem: Array, side: float) -> void:
	## A fidget's pose: unrolled by `unfurl`, the curl wound `tight` degrees a joint tighter (or
	## looser), the stem bent toward the party by `bend` (and each stem joint by `stem`), and to
	## its own side by `side`. The idle's sway is laid in as the idle gives way to it, so the
	## stalk is turned once and never comes apart.
	var chain: Array = m.group("stalk").chain
	if chain.size() < 16:
		return
	var rest: float = 1.0 - float(m._idle_weight)
	var sway: float = 2.2 * sin(float(m._clock) * 0.9) * rest
	var sway_z: float = 1.6 * sin(float(m._clock) * 0.7 + 1.0) * rest + side
	var curl: Array = [0.0, 0.0, 0.0]
	for j in range(TENDRIL_CURL.size()):
		var start: float = float(j) / 12.0 * 0.55
		curl.append(deg_to_rad(-float(TENDRIL_CURL[j])) * smoothstep(start, start + 0.45, unfurl) + deg_to_rad(sway * 0.5 + tight))
	m.chain_turns(chain, TENDRIL_AXIS, curl)
	var bends: Array = []
	for index in range(3):
		bends.append(deg_to_rad(bend + sway + (float(stem[index]) if index < stem.size() else 0.0)))
	m.chain_turns(chain, Vector3.RIGHT, bends)
	m.chain_turns(chain, Vector3.BACK, [deg_to_rad(sway_z), deg_to_rad(sway_z * 0.75)])

static func _tendril_bud(m: Node3D, k: float) -> void:
	var bud: Array = m._select(["Bud01"])
	if not bud.is_empty() and absf(k) > 0.0001:
		m.swell(bud, m.centre_of(bud[0]), Vector3.ONE * (1.0 + k))

static func _tendril_taste(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Half unrolls and leans toward the party, petals open, nodding a little as it tastes.
	var t: float = _keyed(clip)
	var f: float = m._v(clip, "f", t)
	var nod: float = 2.0 * sin(t * 5.0) * smoothstep(0.9, 1.3, t) * (1.0 - smoothstep(2.0, 2.4, t)) * f
	_petals(m, 30.0 * f)
	_tendril_bud(m, 0.3 * f)
	_tendril_still(m, 0.36 * f, 8.0 * f + nod, 0.0, [], 0.0)

static func _tendril_coil(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Winds its curl tighter, the stem bowing back from the party, and lets it out.
	var t: float = _keyed(clip)
	var f: float = m._v(clip, "f", t)
	_petals(m, -8.0 * f)
	_tendril_bud(m, -0.1 * f)
	_tendril_still(m, 0.0, -8.0 * f, 8.0 * f, [], 4.0 * f)

static func _tendril_shiver(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## A ripple running up the stem into the curl, the bud pulsing as it gets there.
	var t: float = _keyed(clip)
	var f: float = m._v(clip, "f", t)
	var stem: Array = []
	for index in range(3):
		stem.append(4.0 * sin(t * 9.0 - float(index) * 1.1) * f)
	_petals(m, 12.0 * maxf(0.0, sin(t * 9.0 - 3.3)) * f)
	_tendril_bud(m, 0.25 * maxf(0.0, sin(t * 9.0 - 3.6)) * f)
	_tendril_still(m, 0.06 * f, 0.0, 2.0 * sin(t * 9.0 - 3.3) * f, stem, 0.0)

static func _idle_heartbeat(m: Node3D, clock: float, weight: float) -> void:
	## A slow double thump.
	var p: float = fmod(clock, 1.6)
	var thump: float = exp(-pow((p - 0.1) / 0.06, 2.0)) + 0.7 * exp(-pow((p - 0.36) / 0.06, 2.0))
	var heart: Dictionary = m.group("heart")
	m.swell(heart.parts, heart.joint, Vector3.ONE * (1.0 + 0.07 * thump * weight))
