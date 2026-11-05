extends RefCounted
## The Quarry's Wardens and big beasts: the Foreman, the Drill, the Regent, the Glass Wyrm (and
## the Shard and Amethyst Wyrms) and the Quartz Golem (and the Prism Golem). The rest of the
## Quarry is in quarry.gd. Rigs as data (creature_rigs.gd has the gesture language); the moves
## and idles no table says are functions of the Moves node (creature_moves.gd), passed in as `m`.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {
}
## When a move played by a function is wound back furthest (a heavy one holds there).
const CUSTOM_WIND: Dictionary = {
}

## The Drill's Bore, started early (its lead 0.42): the front rears up slowly, holds, and
## drives down at the blow.
const DRILL_DRIVE: Array = [[-0.12, 0.0], [0.14, -1.0], [0.22, -1.0], [0.3, 1.0], [0.42, 1.0], [0.95, 0.0]]
## The Drill looking round the room: its head swung off to its right (-1), held, swung across to
## its left (+1), held, and home. Its bit leans to its right already, so the swing left is the
## bigger one; it crosses low (DRILL_LIFT dips) so the glowing bit never points into the lens.
const DRILL_LOOK: Array = [[0.0, 0.0], [0.5, 0.0], [1.5, -1.0], [2.5, -1.0], [3.2, 1.0], [4.2, 1.0], [5.2, 0.0]]
const DRILL_LIFT: Array = [[0.0, 0.0], [1.2, 1.0], [2.45, 1.0], [2.85, 0.3], [3.2, 1.0], [4.2, 1.0], [5.2, 0.0]]
## Overdrive rears twice, its head cocked off to its right (-1) and then its left (+1) as it
## rears, so the bit is seen side-on (pointed at the party it blooms into a blob), and centred
## as it drives down.
const DRILL_COCK: Array = [[0.0, 0.0], [0.22, -1.0], [0.3, 0.0], [0.36, 0.0], [0.46, 1.0], [0.54, 0.0], [1.05, 0.0]]
## Venting: the front sags as the steam goes (+1), heaves up after it (-1) and settles.
const DRILL_SIGH: Array = [[0.0, 0.0], [0.5, 1.0], [1.0, 1.0], [1.6, -1.0], [2.0, -1.0], [2.6, 0.0]]

## The Foreman tapping the floor with its pick, twice, listening to the rock.
const FOREMAN_TAP: Array = [[0.0, 0.0], [0.55, -1.0], [0.85, 1.0], [1.05, 0.4], [1.25, 1.0], [1.6, 0.25], [2.6, 0.0]]
const FOREMAN_LEAN: Array = [[0.0, 0.0], [0.7, 1.0], [1.9, 1.0], [2.6, 0.0]]
## Its sidestep: off to its left and back again, the legs scuttling while it moves.
const FOREMAN_SIDESTEP: Array = [[0.0, 0.0], [1.0, 1.0], [1.8, 1.0], [3.0, 0.0]]
const FOREMAN_GAIT: Array = [[0.0, 0.0], [0.2, 1.0], [1.0, 1.0], [1.2, 0.15], [1.7, 0.15], [1.9, 1.0], [2.8, 1.0], [3.0, 0.0]]
## Its hard hat lifted off its brow, held, and set back with two little shuffles.
const FOREMAN_TIP: Array = [[0.0, 0.0], [0.6, 1.0], [1.4, 1.0], [1.75, 0.0], [1.9, 0.25], [2.05, 0.0], [2.2, 0.12], [2.4, 0.0]]
## Bury, started early (lead 0.45): the pick swung up hard into the roof as the hex leaves.
const FOREMAN_ROOF: Array = [[-0.15, 0.0], [-0.05, -1.0], [0.03, 1.0], [0.25, 1.0], [0.75, 0.0]]
const FOREMAN_LOOK_UP: Array = [[-0.15, 0.0], [0.0, 1.0], [0.4, 1.0], [0.8, 0.0]]
## Collapse: the hook reaches out over the party (+1) and yanks back past where it hangs (-0.6).
const FOREMAN_RAKE: Array = [[0.0, 0.0], [0.18, -1.0], [0.3, 1.0], [0.42, 1.0], [0.62, -0.6], [0.85, -0.6], [1.1, 0.0]]

## The Regent's Splinter, started early (lead 0.45): her mirror arm drawn back and flicked at the
## party as the hex leaves it.
const REGENT_FLICK: Array = [[-0.15, 0.0], [-0.02, -1.0], [0.06, 1.0], [0.34, 1.0], [0.9, 0.0]]
## A twirl: once round, easing in and out.
const REGENT_TWIRL: Array = [[0.0, 0.0], [3.6, 1.0]]

## The Amethyst Wyrm's Hex, started early (lead 0.45): its neck weaves (both ways), its jaw
## gapes in a hiss as the hex leaves, and it weaves on after.
const WYRM_WEAVE: Array = [[-0.15, 0.0], [-0.06, 1.0], [0.02, -0.7], [0.12, 0.2], [0.45, 0.6], [0.75, -0.4], [1.05, 0.0]]
const WYRM_HISS: Array = [[-0.15, 0.0], [-0.04, 0.0], [0.04, 1.0], [0.35, 1.0], [0.65, 0.0]]
## Sharpen: its coil ground back and forth against itself.
const WYRM_GRIND: Array = [[0.0, 0.0], [0.15, -1.0], [0.3, 1.0], [0.45, -1.0], [0.6, 1.0], [0.85, 0.0]]
## The neck's sideways axis: square to the neck as it leans up toward the party.
const WYRM_ACROSS := Vector3(0.0, 0.76, -0.65)

## The Golem rocking onto one edge and stomping down, then the other; the stack wobbling after
## each stomp.
const GOLEM_ROCK_L: Array = [[0.0, 0.0], [0.55, 1.0], [0.75, 1.0], [0.81, 0.8], [0.86, 0.0]]
const GOLEM_ROCK_R: Array = [[0.0, 0.0], [1.3, 0.0], [1.85, 1.0], [2.05, 1.0], [2.11, 0.8], [2.16, 0.0]]
const GOLEM_WOBBLE: Array = [[0.0, 0.0], [0.86, 0.0], [0.95, -0.7], [1.07, 0.45], [1.19, -0.2], [1.32, 0.0], [2.16, 0.0],
	[2.25, 0.7], [2.37, -0.45], [2.49, 0.2], [2.62, 0.0]]
## Its blocks lifted apart and dropped back with a thud.
const GOLEM_LIFT: Array = [[0.0, 0.0], [0.8, 1.0], [1.3, 1.0], [1.38, 0.7], [1.44, 0.0], [1.52, 0.12], [1.62, 0.0]]

const RIGS: Dictionary = {
	## The Glass Wyrm (and the Shard and Amethyst Wyrms, in their colours): a glass serpent coiled
	## on the floor. A snake slithers and coils: its neck sways in a wave as it watches, its tail
	## tip curls and rattles, it draws itself up tall to look about and hisses with its throat lit;
	## it rears back in an S and strikes from the coil with its breath.
	"GLASS_WYRM": {
		"mouth": "Mouth01",
		"lead": {"Hex": 0.45},
		"groups": {
			"tail": {"chain": [["Tail04"], ["Tail03"], ["Tail02"], ["Tail01", "Tail05"]]},
			"tail_tip": {"parts": ["Tail01", "Tail05"], "at": "Tail01"},
			"jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"head": {"parts": ["Head", "Jaw", "Mouth", "Throat"], "at": "Head01"},
			"neck": {"chain": [["Neck01"], ["Neck02", "Neck04"], ["Neck03"]], "riders": ["Head", "Jaw", "Mouth", "Throat"]},
			"spines": {"parts": ["Crystal"]},
			"throat": {"parts": ["Throat01"]},
			"coil": {"parts": ["Body", "Crystal", "Tail", "Core"], "at": Vector3(0, 0.1, 0)},
			"all": {"parts": ["Body", "Crystal", "Tail", "Core", "Neck", "Head", "Jaw", "Mouth", "Throat"], "at": Vector3.ZERO},
		},
		"idle_gestures": [["look", "head", 14.0, 6.0, 3.0, 1.0], ["slither", "neck", WYRM_ACROSS, 5.0, 1.5, 0.9, "tip"],
			["curl", "tail", "across", 5.0, 1.3, 0.0, "tip"], ["breathe", "all", Vector3(0.015, 0.03, 0.015), 1.2, 0.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Draws itself up tall on its coil to look about, its spines lifting, and sinks back.
			"rise": {"length": 4.4, "hold": 2.0, "weight": 2.5, "do": [["gaze", "head", 35.0, 14.0, "f", 3], ["turn", "head", X, 0.0, 10.0, "f"],
				["curl", "neck", X, 0.0, -26.0, "f", "even"], ["each", "spines", 0.0, 0.2, "f"],
				["grow", "all", 0.0, Vector3(-0.02, 0.07, -0.02), "f"]]},
			## Lifts the tip of its tail and rattles it, glass chiming, looking round at it.
			"rattle": {"length": 2.6, "hold": 1.2, "weight": 2.0, "do": [["tremble", "tail_tip", 0.02, "f"], ["turn", "tail_tip", Y, 0.0, 14.0, "shake"],
				["curl", "tail", "across", 0.0, 28.0, "f", "tip"], ["turn", "head", Y, 0.0, -18.0, "f"],
				["fx", 0.7, "sparks", {"from": "Tail05", "color": "accent", "amount": 8, "speed": 1.2}],
				["fx", 1.3, "sparks", {"from": "Tail05", "color": "accent", "amount": 6, "speed": 1.0}]]},
			## Draws its head back and hisses, jaw wide and throat lit, its spines bristling.
			"hiss": {"length": 2.8, "hold": 1.1, "weight": 1.5, "do": [["turn", "jaw", X, 0.0, 30.0, "f"], ["each", "throat", 0.0, 0.5, "f"],
				["turn", "head", X, 0.0, -14.0, "f"], ["curl", "neck", X, 0.0, -14.0, "f", "root"], ["each", "spines", 0.0, 0.35, "f"],
				["fx", 1.0, "puff", {"from": "Mouth01", "color": "accent", "amount": 8, "size": 0.5, "rise": 0.2, "glow": true}],
				["fx", 1.1, "sparks", {"from": "Mouth01", "color": "accent", "amount": 10, "speed": 1.5}]]},
			## Shifts round on its coil, showing its flank, its head kept on the party.
			"recoil": {"length": 3.6, "hold": 1.2, "weight": 1.2, "do": [["turn", "head", Y, 0.0, -22.0, "f"], ["turn", "all", Y, 0.0, 30.0, "f"]]},
		},
		"moves": {
			## Flicks its tail up off the coil and whips it down, the coil twisting to throw it.
			"Lash": [["curl", "tail", "across", 70.0, -14.0, "big", "tip"], ["turn", "head", Y, 0.0, -12.0, "big"], ["turn", "all", Y, 10.0, -12.0, "big"],
				["fx", 0.3, "swipe", {"about": "centre", "axis": X, "start": Vector3(0, 1, 0.4), "radius": 1.1, "sweep": 100.0}],
				["fx", 0.31, "shock", {"ahead": 0.9, "size": 0.7}]],
			## Rears back in an S, jaw open and throat glowing, and strikes forward breathing glass. Held
			## heavy: it draws itself up taller still, throat blazing, spines up, tail tip rattling.
			"breath": [["turn", "jaw", X, 10.0, 32.0, "breath"], ["turn", "jaw", X, 0.0, 10.0, "h"],
				["each", "throat", 0.6, 0.3, "breath"], ["each", "throat", 0.0, 0.6, "h"],
				["turn", "head", X, -24.0, 14.0, "breath"], ["turn", "head", X, 0.0, -10.0, "h"],
				["curl", "neck", X, -20.0, 10.0, "breath"],
				["tremble", "tail_tip", 0.03, "h"], ["each", "spines", 0.0, 0.4, "h"],
				["grow", "all", 0.0, Vector3(-0.02, 0.06, -0.02), "h"], ["rear", 0.25, "attack"],
				["fx", 0.27, "breath", {"kind": "crystal", "seconds": 0.55, "size": 1.0, "color": "accent"}],
				["fx", 0.3, "shards", {"from": "Mouth01", "color": "accent", "amount": 10, "speed": 4.0}]],
			## Grinds its coil against itself, spines growing keen, sparks off the glass.
			"Sharpen": [["each", "spines", 0.0, 0.45, "pulse"], ["turn", "head", Z, 0.0, 10.0, "shake"],
				["turn", "coil", Y, -8.0, 10.0, WYRM_GRIND], ["tremble", "all", 0.012, "hold"],
				["fx", 0.18, "sparks", {"from": "Crystal02", "color": "accent", "amount": 12, "speed": 2.0}],
				["fx", 0.3, "sparks", {"from": "centre", "color": "accent", "amount": 30, "speed": 3.0}],
				["fx", 0.45, "sparks", {"from": "Crystal05", "color": "accent", "amount": 12, "speed": 2.0}],
				["fx", 0.6, "sparks", {"from": "Crystal07", "color": "accent", "amount": 12, "speed": 2.0}]],
			## Coils up tight and turns its glassy flank to the party, flashing like a mirror.
			"Mirror": [["each", "throat", 0.0, 0.6, "pulse"], ["turn", "head", Y, 0.0, -20.0, "hold"], ["turn", "head", X, 0.0, -16.0, "hold"],
				["curl", "neck", X, 0.0, -12.0, "hold"], ["turn", "all", Y, 0.0, 22.0, "hold"],
				["grow", "coil", 0.0, Vector3(-0.05, 0.05, -0.05), "hold"],
				["fx", 0.28, "flash_light", {"from": "centre", "color": "#f4eeff", "energy": 4.0}],
				["fx", 0.3, "sparks", {"from": "Crystal03", "color": "#f4eeff", "amount": 10, "speed": 1.5}],
				["fx", 0.34, "sparks", {"from": "Crystal06", "color": "#f4eeff", "amount": 10, "speed": 1.5}]],
			## Weaves its head side to side and hisses the curse out (the hex is thrown for it).
			"Hex": [["turn", "jaw", X, 0.0, 28.0, WYRM_HISS], ["turn", "head", X, 0.0, -10.0, WYRM_HISS],
				["curl", "neck", WYRM_ACROSS, -14.0, 14.0, WYRM_WEAVE, "tip"],
				["fx", 0.0, "puff", {"from": "Mouth01", "color": "accent", "amount": 10, "size": 0.6, "rise": 0.3, "glow": true}],
				["fx", 0.02, "flash_light", {"from": "Mouth01", "color": "accent", "energy": 3.0}],
				["fx", 0.25, "sigil", {"color": "accent"}]],
		},
		"heavy": {
			## Its breath held: the throat blazing, motes pulled into its jaws, grit lifting off the
			## floor round its coil; it lets go in a burst of glass.
			"breath": {"at": "Throat01",
				"charge": [["charge_glow", {"from": "Throat01", "color": "accent", "seconds": 0.5}], ["spiral", {"from": "Mouth01", "color": "accent", "amount": 24}],
					["charge_dust", {"seconds": 0.45}], ["sparks", {"from": "Throat01", "color": "accent", "amount": 12, "speed": 1.5}]],
				"impact": [["shards", {"from": "Mouth01", "color": "accent", "amount": 16, "speed": 6.0}],
					["flash_light", {"from": "Mouth01", "color": "accent", "energy": 5.0}], ["shock", {"ahead": 1.2, "size": 1.0}]]},
		},
	},
	## The Foreman: a rock-crab in a miner's hard hat, a pick in one claw and a lamp on its hook. A
	## crab clacks and sidesteps; its eyestalks swivel about, its feet shift; a foreman taps the rock,
	## holds its lamp up to see the tunnel, tips its hat; it swings its pick down hard.
	"THE_FOREMAN": {
		"mouth": "Lantern03",
		"idle": "_idle_foreman",
		"lead": {"Bury": 0.45},
		"groups": {
			"pick_arm": {"parts": ["ArmL", "Pick"], "at": "ArmL01"},
			"pick": {"parts": ["Pick"], "at": "Pick01"},
			"hook_arm": {"parts": ["ArmR", "Lantern"], "at": "ArmR01"},
			"lantern": {"parts": ["Lantern"], "at": "Lantern01"},
			"stalk_r": {"parts": ["Stalk01-02"], "at": "Stalk01"},
			"stalk_l": {"parts": ["Stalk03-04"], "at": "Stalk03"},
			"shell": {"parts": ["Shell"], "at": "Shell01"},
			## Each side's three legs, turned about the line of their hips (+z lifts the left's tips,
			## -z the right's).
			"legs_l": {"parts": ["Leg10-18"], "at": Vector3(1.15, 0.95, 0.0)},
			"legs_r": {"parts": ["Leg01-09"], "at": Vector3(-1.15, 0.95, 0.0)},
			## All of it but the rubble lying on the floor round it (Rock02-04), for its sidestep.
			"crab": {"parts": ["Body", "Rock01", "Box01", "Shell", "Stalk", "Leg", "ArmL", "ArmR", "Pick", "Lantern", "Crystal"], "at": Vector3(0, 0.95, 0)},
		},
		"idle_gestures": [["look", "stalk_r", 24.0, 12.0, 2.6, 0.9], ["look", "stalk_l", 24.0, 12.0, 2.6, 0.9],
			["sway", "stalk_r", Z, 5.0, 1.3, 0.0], ["sway", "stalk_l", Z, 5.0, 1.1, 1.7]],
		"fidget_every": [3.5, 7.0],
		"fidgets": {
			## Holds its lamp up high and peers round the tunnel, each eyestalk its own way.
			"lamp_up": {"length": 4.0, "hold": 2.0, "weight": 2.5, "do": [["gaze", "stalk_r", 30.0, 16.0, "f", 3], ["gaze", "stalk_l", 30.0, 16.0, "f", 3],
				["turn", "hook_arm", X, 0.0, -42.0, "f"], ["turn", "hook_arm", Z, 0.0, -14.0, "f"], ["turn", "pick_arm", X, 0.0, -8.0, "f"],
				["fx", 1.0, "flash_light", {"from": "Lantern03", "color": "#ffe0a0", "energy": 2.5}],
				["fx", 2.4, "flash_light", {"from": "Shell04", "color": "#ffe8b0", "energy": 2.0}]]},
			## Taps the floor with its pick, twice, both eyes bent to listen to the rock.
			"tap_rock": {"length": 2.6, "weight": 1.5, "do": [["turn", "pick", X, -10.0, 28.0, FOREMAN_TAP], ["turn", "pick_arm", X, -15.0, 40.0, FOREMAN_TAP],
				["turn", "stalk_r", X, 0.0, 18.0, FOREMAN_LEAN], ["turn", "stalk_l", X, 0.0, 18.0, FOREMAN_LEAN],
				["turn", "stalk_r", Y, 0.0, 14.0, FOREMAN_LEAN], ["turn", "stalk_l", Y, 0.0, 20.0, FOREMAN_LEAN],
				["fx", 0.85, "sparks", {"from": "Pick03", "color": "#ffd08a", "amount": 8, "speed": 1.6}],
				["fx", 1.25, "sparks", {"from": "Pick03", "color": "#ffd08a", "amount": 8, "speed": 1.4}],
				["fx", 1.26, "puff", {"from": "Pick03", "color": "#8a7a66", "amount": 6, "size": 0.6, "rise": 0.3}]]},
			## A crab's sidestep: off to its left on scuttling legs, a pause, and back.
			"scuttle": {"length": 3.0, "hold": 0.9, "weight": 1.5, "do": [["call", "_foreman_scuttle"],
				["turn", "stalk_r", Z, 0.0, 10.0, "f"], ["turn", "stalk_l", Z, 0.0, 10.0, "f"],
				["move", "crab", Vector3.ZERO, Vector3(0.45, 0.0, 0.0), FOREMAN_SIDESTEP],
				["fx", 0.5, "puff", {"from": "feet", "color": "#8a7a66", "amount": 8, "size": 0.9, "rise": 0.3}],
				["fx", 2.2, "puff", {"from": "feet", "color": "#8a7a66", "amount": 7, "size": 0.9, "rise": 0.3}]]},
			## Tips its hard hat up off its brow, the eyestalks bobbing, and settles it back.
			"tip_hat": {"length": 2.8, "weight": 1.0, "do": [["turn", "shell", X, 0.0, -14.0, FOREMAN_TIP],
				["move", "shell", Vector3.ZERO, Vector3(0.0, 0.07, 0.02), FOREMAN_TIP],
				["turn", "stalk_r", X, 0.0, 16.0, "nod"], ["turn", "stalk_l", X, 0.0, 16.0, "nod"],
				["fx", 0.55, "puff", {"from": "Shell02", "color": "#8a7a66", "amount": 8, "size": 0.7, "rise": 0.5}],
				["fx", 1.8, "puff", {"from": "Shell02", "color": "#8a7a66", "amount": 6, "size": 0.6, "rise": 0.3}]]},
		},
		"moves": {
			## Swings its pick up and down at the party, the lamp swung back to balance it.
			"Pick": [["turn", "pick", X, -20.0, 25.0, "attack"], ["turn", "pick_arm", X, -55.0, 35.0, "attack"], ["turn", "hook_arm", X, 0.0, -14.0, "attack"],
				["turn", "stalk_r", X, -10.0, 12.0, "attack"], ["turn", "stalk_l", X, -10.0, 12.0, "attack"], ["rear", 0.2, "attack"],
				["fx", 0.3, "shock", {"from": "Pick03", "size": 0.8}], ["fx", 0.3, "sparks", {"from": "Pick03", "color": "#ffd08a"}]],
			## Both claws up over its hat and down on the floor together: the roof shakes.
			"Cave-in": [["turn", "pick", X, -25.0, 30.0, "big"], ["turn", "pick_arm", X, -70.0, 40.0, "big"], ["turn", "hook_arm", X, -50.0, 28.0, "big"],
				["turn", "stalk_r", X, 0.0, -25.0, "big"], ["turn", "stalk_l", X, 0.0, -25.0, "big"],
				["hop", Vector3(0.0, 0.1, -0.04), Vector3(0.0, -0.04, 0.06), "big"], ["rear", 0.3, "big"],
				["fx", 0.3, "shock", {"from": "Pick03", "size": 1.3}], ["fx", 0.32, "dust", {"amount": 80}],
				["fx", 0.31, "shards", {"from": "Pick03", "color": "#8a7a66", "amount": 10, "speed": 3.5}]],
			## Three blasting blows of the pick. Held heavy: the pick raised far back over its hat, the
			## lamp held high to light the fuse, the legs braced and the body sunk low.
			"Blast": [["turn", "pick", X, -15.0, 25.0, "thrice"], ["turn", "pick", X, 0.0, -20.0, "h"],
				["turn", "pick_arm", X, -48.0, 32.0, "thrice"], ["turn", "pick_arm", X, 0.0, -22.0, "h"],
				["turn", "hook_arm", X, 0.0, -20.0, "thrice"], ["turn", "hook_arm", X, 0.0, -30.0, "h"],
				["turn", "stalk_r", X, 0.0, -20.0, "h"], ["turn", "stalk_l", X, 0.0, -20.0, "h"],
				["turn", "legs_l", Z, 0.0, 5.0, "h"], ["turn", "legs_r", Z, 0.0, -5.0, "h"], ["hop", Vector3.ZERO, Vector3(0.0, -0.07, 0.0), "h"],
				["fx", 0.3, "flash_light", {"from": "Pick03", "color": "#ffb050"}], ["fx", 0.3, "sparks", {"from": "Pick03", "color": "#ffb050", "amount": 30, "speed": 5.0}],
				["fx", 0.52, "flash_light", {"from": "Pick03", "color": "#ffb050"}], ["fx", 0.52, "sparks", {"from": "Pick03", "color": "#ffb050", "amount": 30, "speed": 5.0}],
				["fx", 0.74, "flash_light", {"from": "Pick03", "color": "#ffb050"}], ["fx", 0.74, "shock", {"from": "Pick03", "size": 1.0}]],
			## Clamps its hat down, folds its eyestalks, draws its claws in and hunkers on its legs.
			"Shore Up": [["move", "shell", Vector3.ZERO, Vector3(0, -0.08, 0), "hold"], ["turn", "stalk_r", X, 0.0, 30.0, "hold"], ["turn", "stalk_l", X, 0.0, 30.0, "hold"],
				["turn", "pick_arm", Y, 0.0, -16.0, "hold"], ["turn", "hook_arm", Y, 0.0, 16.0, "hold"],
				["turn", "legs_l", Z, 0.0, 5.0, "hold"], ["turn", "legs_r", Z, 0.0, -5.0, "hold"], ["hop", Vector3.ZERO, Vector3(0.0, -0.08, 0.0), "hold"],
				["fx", 0.26, "puff", {"from": "feet", "color": "#8a7a66", "amount": 12, "size": 1.4, "rise": 0.3}],
				["fx", 0.28, "sparks", {"from": "Shell02", "color": "#ffd08a", "amount": 10, "speed": 2.0}]],
			## Swings its pick up into the roof: rock and dust come down (the rubble lands on the rail).
			"Bury": [["turn", "pick", X, 8.0, -28.0, FOREMAN_ROOF], ["turn", "pick_arm", X, 18.0, -70.0, FOREMAN_ROOF],
				["turn", "stalk_r", X, 0.0, -28.0, FOREMAN_LOOK_UP], ["turn", "stalk_l", X, 0.0, -28.0, FOREMAN_LOOK_UP],
				["turn", "hook_arm", X, 0.0, -30.0, FOREMAN_LOOK_UP],
				["fx", 0.04, "sparks", {"from": "Pick02", "color": "#ffd08a", "amount": 16, "speed": 3.0}],
				["fx", 0.05, "shards", {"from": "Pick02", "color": "#8a7a66", "amount": 12, "speed": 2.0}],
				["fx", 0.06, "dust", {"amount": 70}]],
			## Reaches its hook out over the party, snags a die and rakes it back.
			"Collapse": [["turn", "hook_arm", X, -18.0, 28.0, FOREMAN_RAKE], ["turn", "hook_arm", Y, -10.0, 30.0, FOREMAN_RAKE],
				["turn", "stalk_r", X, 0.0, 15.0, "attack"], ["turn", "stalk_l", X, 0.0, 15.0, "attack"], ["turn", "pick_arm", X, 0.0, -15.0, "attack"],
				["rear", 0.2, FOREMAN_RAKE],
				["fx", 0.3, "puff", {"from": "Lantern03", "color": "#8a7a66", "amount": 10, "size": 0.9, "rise": 0.3}],
				["fx", 0.31, "flash_light", {"from": "Lantern03", "color": "#ffe0a0", "energy": 2.5}]],
			## Twirls its pick once round its fist and holds it up, the edge catching the light.
			"Reinforce": [["whirl", "pick", X, -1.0, "hold"], ["turn", "pick_arm", X, 0.0, -38.0, "hold"],
				["turn", "stalk_r", X, 0.0, -22.0, "hold"], ["turn", "stalk_l", X, 0.0, -22.0, "hold"],
				["turn", "stalk_r", Y, 0.0, 15.0, "hold"], ["turn", "stalk_l", Y, 0.0, 22.0, "hold"],
				["fx", 0.3, "flash_light", {"from": "Pick03", "color": "#ffd860", "energy": 3.5}],
				["fx", 0.3, "sparks", {"from": "Pick02", "color": "#ffd860", "amount": 22, "speed": 2.5}],
				["fx", 0.45, "glow", {"from": "Pick03", "color": "#ffd860", "size": 0.5}],
				["fx", 0.6, "sparks", {"from": "Pick03", "color": "#ffd860", "amount": 14, "speed": 2.0}]],
		},
		"heavy": {
			## Blast held: sparks fizzing off the pick like a lit fuse, the lamp flaring, grit lifting;
			## it lands in a burst of rock and a fall of dust from the roof.
			"Blast": {"at": "Pick03", "shiver": 1.3,
				"charge": [["sparks", {"from": "Pick03", "color": "#ffb050", "amount": 26, "speed": 1.8, "life": 0.9}],
					["charge_glow", {"from": "Pick03", "color": "#ffb050", "seconds": 0.5}],
					["flash_light", {"from": "Lantern03", "color": "#ffd890", "energy": 3.0}],
					["charge_dust", {"seconds": 0.45}], ["spiral", {"from": "Pick03", "color": "#ffc070", "amount": 26}]],
				"impact": [["shock", {"from": "Pick03", "size": 1.7}], ["dust", {"amount": 90}],
					["shards", {"from": "Pick03", "color": "#b89a70", "amount": 16, "speed": 5.5}],
					["flash_light", {"from": "Pick03", "color": "#ffb050", "energy": 6.0}]]},
		},
	},
	## The Drill: a boring machine arched over the floor like a worm, its bit driven into the
	## ground at the party. A machine revs, vents and shudders; now and then it lifts its head off
	## the floor to look round the room with its lamps, shows its bit, stretches its arch, blows off
	## steam; it rears its front up to drive the bit down.
	"THE_DRILL": {
		"mouth": "Drill02",
		"idle": "_idle_drill",
		"lead": {"Bore": 0.42},
		"groups": {
			"bit": {"parts": ["Drill"]},
			"front": {"parts": ["Head", "Drill", "Body23-25"], "at": "Head01"},
			"smoke": {"parts": ["Smoke"]},
			## The front half of the arch, drum by drum, each turning where it meets the one behind.
			"arch_front": {"chain": [["Body13-15"], ["Body16-19", "Smoke04-06"], ["Body20-22"], ["Body23-25", "Head", "Drill"]],
				"joints": [Vector3(0.235, 2.0, -0.325), Vector3(0.205, 2.085, 0.02), Vector3(0.13, 1.945, 0.36), Vector3(0.015, 1.59, 0.705)]},
			"neck": {"parts": ["Body20-22", "Body23-25", "Head", "Drill"], "at": Vector3(0.13, 1.945, 0.36)},
			"machine": {"parts": ["Body", "Smoke", "Head", "Drill"], "at": Vector3(-0.1, -0.15, -1.7)},
		},
		"idle_gestures": [["look", "neck", 5.0, 2.0, 3.4, 1.3]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Lifts its head off the floor to look round the room with its lamps, off to one side and
			## then the other, its bit turned side-on (it dips as it swings across, so the bit never
			## points into the party's eyes), and sets it back.
			"look_up": {"length": 5.2, "hold": 3.0, "weight": 3.0, "do": [["gaze", "neck", 8.0, 5.0, "f", 3],
				["turn", "neck", X, 0.0, -8.0, DRILL_LIFT], ["turn", "neck", Y, -50.0, 62.0, DRILL_LOOK],
				["curl", "arch_front", X, 0.0, -30.0, DRILL_LIFT, "even"], ["turn", "machine", Y, -5.0, 7.0, DRILL_LOOK],
				["turn", "machine", X, 0.0, -5.0, DRILL_LIFT],
				["fx", 0.5, "puff", {"from": "Drill02", "color": "#6a5a4a", "amount": 10, "size": 0.9, "rise": 0.6}],
				["fx", 1.3, "flash_light", {"from": "Head02", "color": "#ffe8b0", "energy": 2.5}],
				["fx", 3.4, "flash_light", {"from": "Head04", "color": "#ffe8b0", "energy": 2.5}]]},
			## Revs its bit up hard: smoke from both stacks, the whole machine shuddering.
			"rev": {"length": 1.8, "hold": 0.8, "weight": 1.5, "do": [["spin", "bit", 8.0, "f"], ["tremble", "machine", 0.025, "f"],
				["each", "smoke", 0.0, 0.6, "f"], ["curl", "arch_front", X, 0.0, -10.0, "f", "tip"],
				["fx", 0.35, "puff", {"from": "Smoke02", "color": "#6a625c", "amount": 14, "size": 1.2, "rise": 1.4}],
				["fx", 0.55, "puff", {"from": "Smoke05", "color": "#6a625c", "amount": 14, "size": 1.2, "rise": 1.4}],
				["fx", 0.6, "sparks", {"from": "Drill02", "color": "#ffc070", "amount": 18, "speed": 2.5}]]},
			## Stretches: the whole arch tips back off its bit and the front bows, then settles.
			"arch": {"length": 2.6, "hold": 0.9, "weight": 1.5, "do": [["each", "smoke", 0.0, 0.3, "f"],
				["curl", "arch_front", X, 0.0, 16.0, "f", "tip"], ["turn", "machine", X, 0.0, -7.0, "f"],
				["fx", 0.9, "puff", {"from": "Smoke02", "color": "#6a625c", "amount": 10, "size": 1.0, "rise": 1.0}]]},
			## Blows off steam: its furnace slits flare, both stacks gush white, the front sags with a
			## sigh and heaves back up.
			"vent": {"length": 2.6, "hold": 0.6, "weight": 1.2, "do": [["tremble", "machine", 0.014, "f"], ["each", "smoke", 0.0, 0.8, "f"],
				["curl", "arch_front", X, -10.0, 6.0, DRILL_SIGH, "tip"],
				["fx", 0.45, "glow", {"from": "Body05", "color": "#ffb060", "size": 0.5}], ["fx", 0.5, "glow", {"from": "Body08", "color": "#ffb060", "size": 0.5}],
				["fx", 0.5, "puff", {"from": "Smoke02", "color": "#d8d4ce", "amount": 18, "size": 1.3, "rise": 2.2}],
				["fx", 0.56, "puff", {"from": "Smoke05", "color": "#d8d4ce", "amount": 18, "size": 1.3, "rise": 2.2}],
				["fx", 0.6, "sparks", {"from": "Body08", "color": "#ffc070", "amount": 10, "speed": 2.0}]]},
		},
		"moves": {
			## Rears its front up with the bit screaming, cocked aside, and drives it down into the floor.
			"Bore": [["turn", "neck", Y, -40.0, 0.0, DRILL_DRIVE], ["curl", "arch_front", X, -30.0, 9.0, DRILL_DRIVE, "tip"], ["turn", "machine", X, -4.0, 2.0, DRILL_DRIVE],
				["spin", "bit", 5.0, "hold"],
				["fx", 0.3, "sparks", {"from": "Drill02", "color": "#ffc070", "amount": 40, "speed": 5.0}], ["fx", 0.3, "shock", {"ahead": 1.0, "size": 0.9}],
				["fx", 0.31, "puff", {"from": "Drill02", "color": "#6a5a4a", "amount": 12, "size": 1.0, "rise": 0.8}]],
			## Bore twice over, everything it has, cocked to one side and then the other: smoke pouring,
			## the bit white hot.
			"Overdrive": [["each", "smoke", 0.0, 0.5, "hold"], ["each", "smoke", 0.0, 0.5, "h"], ["turn", "neck", Y, -42.0, 60.0, DRILL_COCK], ["curl", "arch_front", X, -34.0, 10.0, "twice", "tip"], ["turn", "machine", X, -4.0, 2.0, "twice"],
				["spin", "bit", 8.0, "hold"],
				["fx", 0.1, "puff", {"from": "Smoke02", "color": "#6a625c", "amount": 16, "size": 1.2, "rise": 1.2}],
				["fx", 0.3, "sparks", {"from": "Drill02", "color": "#ffc070", "amount": 40, "speed": 5.0}], ["fx", 0.54, "sparks", {"from": "Drill02", "color": "#ffc070", "amount": 40, "speed": 5.0}],
				["fx", 0.3, "shock", {"ahead": 1.0, "size": 1.0}], ["fx", 0.54, "shock", {"ahead": 1.0, "size": 1.2}]],
			## Revs up where it stands, shuddering, the arch lifting: the next blow will be harder.
			"Rev": [["each", "smoke", 0.0, 0.5, "pulse"], ["spin", "bit", 6.0, "hold"], ["tremble", "machine", 0.022, "hold"],
				["curl", "arch_front", X, 0.0, -12.0, "hold", "tip"],
				["fx", 0.25, "puff", {"from": "Smoke02", "color": "#6a625c", "amount": 14, "size": 1.2, "rise": 1.4}],
				["fx", 0.3, "puff", {"from": "Smoke05", "color": "#6a625c", "amount": 14, "size": 1.2, "rise": 1.4}]],
			## Grinds its bit into the floor, a shower of sparks thrown at the party.
			"Grind": [["spin", "bit", 6.0, "hold"], ["curl", "arch_front", X, -8.0, 6.0, "attack", "tip"], ["tremble", "front", 0.02, "hold"],
				["fx", 0.28, "sparks", {"from": "Drill02", "color": "#ffc070", "amount": 36, "speed": 4.5}],
				["fx", 0.3, "puff", {"from": "Drill02", "color": "#6a5a4a", "amount": 12, "size": 1.0, "rise": 0.6}]],
			## Rolls its whole arch side to side, heaving, the bit spinning.
			"Roller": [["each", "smoke", 0.0, 0.4, "pulse"], ["turn", "machine", Z, -5.0, 5.0, "shake"], ["spin", "bit", 4.0, "hold"],
				["fx", 0.3, "puff", {"from": "Smoke05", "color": "#6a625c", "amount": 12, "size": 1.0, "rise": 1.2}]],
			## Bangs its front on the floor twice: something answers from the tunnels.
			"Call the Rats": [["curl", "arch_front", X, -16.0, 6.0, "twice", "tip"], ["fx", 0.25, "flash_light", {"from": "Head02", "color": "#ffe8b0", "energy": 3.0}],
				["fx", 0.3, "shock", {"ahead": 1.0, "size": 0.7}], ["fx", 0.54, "shock", {"ahead": 1.0, "size": 0.7}]],
			"*": [["spin", "bit", 3.0, "hold"], ["each", "smoke", 0.0, 0.4, "pulse"], ["fx", 0.3, "sparks", {"from": "Drill02", "color": "#ffc070", "amount": 26, "speed": 3.0}]],
		},
		"heavy": {
			## Overdrive held: it rears higher still, cocked aside, both stacks pouring smoke (its "h"
			## swell, laid before the arch curls so the stacks stay on their drums), the bit glowing as it
			## spins up, and comes down like a falling tower.
			"Overdrive": {"at": "Drill02",
				"charge": [["charge_dust", {"seconds": 0.45}], ["flash_light", {"from": "Head02", "color": "#ffe8b0", "energy": 3.0}],
					["puff", {"from": "Smoke02", "color": "#4a4440", "amount": 18, "size": 1.4, "rise": 1.6}],
					["puff", {"from": "Smoke05", "color": "#4a4440", "amount": 18, "size": 1.4, "rise": 1.6}],
					["sparks", {"from": "Drill02", "color": "#ffc070", "amount": 24, "speed": 2.0}]],
				"impact": [["shock", {"ahead": 1.1, "size": 1.6}], ["dust", {"amount": 80}],
					["shards", {"from": "Drill02", "color": "#c8b8a0", "amount": 14, "speed": 5.0}]]},
		},
	},
	## The Mirror Regent: a queen of cut glass in a stiff gown, a hand mirror floating at each hand.
	## A queen is poised and vain: she turns her head to survey the room, tilts her mirrors to catch
	## the light, admires herself in one, twirls to show her gown, curtsies; she turns her mirrors on
	## the party to throw their own blows back.
	"THE_REGENT": {
		"mouth": "Bob03",
		"lead": {"Splinter": 0.45},
		"groups": {
			"all": {"parts": ["Bob", "Cylinder", "Torus", "Core", "Crystal", "Block", "Orbit"], "at": Vector3.ZERO},
			"gown": {"parts": ["Cylinder01"], "at": Vector3.ZERO},
			"hem": {"parts": ["Crystal01-06"], "at": Vector3.ZERO},
			## Everything above her waist, which bows and turns about it.
			"upper": {"parts": ["Torus01", "Cylinder02", "Core01", "Cylinder03", "Crystal07-17", "Cylinder04-07", "Block", "Bob"], "at": Vector3(0, 1.52, 0)},
			"chest": {"parts": ["Cylinder02", "Core01"], "at": Vector3(0, 1.86, 0)},
			"gem": {"parts": ["Core01"]},
			"head": {"parts": ["Block"], "at": Vector3(0, 2.3, 0)},
			"collar": {"parts": ["Crystal07-13"], "at": Vector3(0, 2.2, -0.23)},
			## Her right arm (-x) from the shoulder, and its mirror about her hand; the left the same.
			"arm_r": {"parts": ["Cylinder04-05", "Crystal15", "Bob01-06"], "at": Vector3(-0.36, 2.14, 0.0)},
			"mirror_r": {"parts": ["Bob01-06"], "at": Vector3(-0.92, 1.97, 0.22)},
			"arm_l": {"parts": ["Cylinder06-07", "Crystal17", "Bob07-12"], "at": Vector3(0.36, 2.14, 0.0)},
			"mirror_l": {"parts": ["Bob07-12"], "at": Vector3(0.92, 1.97, 0.22)},
		},
		"idle_gestures": [["sway", "mirror_r", Y, 9.0, 0.45, 0.0], ["sway", "mirror_l", Y, -9.0, 0.45, 0.0],
			["look", "head", 16.0, 5.0, 3.6, 1.4], ["breathe", "chest", Vector3(0.025, 0.02, 0.03), 1.1, 0.0],
			["sway", "upper", Y, 2.5, 0.35, 0.6]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Brings her right-hand mirror up before her face and admires herself in it, head tilted.
			"preen": {"length": 4.2, "hold": 1.8, "weight": 2.0, "do": [["turn", "mirror_r", Y, 0.0, 55.0, "f"],
				["turn", "arm_r", Y, 0.0, 52.0, "f"], ["turn", "arm_r", X, 0.0, -25.0, "f"],
				["turn", "head", Y, 0.0, -25.0, "f"], ["turn", "head", X, 0.0, 10.0, "f"], ["turn", "head", Z, 0.0, 7.0, "f"],
				["turn", "upper", Y, 0.0, -8.0, "f"],
				["fx", 1.6, "sparks", {"from": "Bob03", "color": "#f4eeff", "amount": 10, "speed": 1.2, "life": 0.7}],
				["fx", 1.7, "flash_light", {"from": "Bob03", "color": "#f0e8ff", "energy": 2.0}]]},
			## Turns once round on the spot to show her gown, arms lifted, the skirt flaring.
			"twirl": {"length": 3.6, "hold": 1.4, "weight": 1.5, "idle": 0.4, "do": [["turn", "arm_r", Z, 0.0, -14.0, "f"], ["turn", "arm_l", Z, 0.0, 14.0, "f"],
				["splay", "collar", 0.0, 10.0, "f"], ["grow", "gown", 0.0, Vector3(0.07, -0.01, 0.07), "f"], ["spread", "hem", 0.0, 0.06, "f"],
				["lean", Y, 0.0, 360.0, Vector3.ZERO, REGENT_TWIRL],
				["fx", 1.4, "sparks", {"from": "Crystal02", "color": "#f4eeff", "amount": 12, "speed": 1.5}],
				["fx", 1.8, "rise", {"from": "feet", "color": "accent", "amount": 14}]]},
			## Spins each mirror on its own once round, catching the light, glancing from one to the other.
			"mirrors": {"length": 3.2, "hold": 1.2, "weight": 1.5, "do": [["spin", "mirror_r", 1.0, "f"], ["spin", "mirror_l", -1.0, "f"],
				["gaze", "head", 22.0, 6.0, "f", 2],
				["fx", 1.1, "flash_light", {"from": "Bob03", "color": "#f0e8ff", "energy": 2.2}],
				["fx", 1.7, "flash_light", {"from": "Bob09", "color": "#f0e8ff", "energy": 2.2}],
				["fx", 1.6, "sparks", {"from": "Bob03", "color": "#f4eeff", "amount": 8, "speed": 1.0}],
				["fx", 2.0, "sparks", {"from": "Bob09", "color": "#f4eeff", "amount": 8, "speed": 1.0}]]},
			## A slow curtsy: she sinks into her gown and bows her head, mirrors swept low and back.
			"curtsy": {"length": 3.4, "hold": 1.0, "weight": 1.0, "do": [["turn", "mirror_r", X, 0.0, 15.0, "f"], ["turn", "mirror_l", X, 0.0, 15.0, "f"],
				["turn", "arm_r", Z, 0.0, 22.0, "f"], ["turn", "arm_l", Z, 0.0, -22.0, "f"],
				["turn", "arm_r", Y, 0.0, -15.0, "f"], ["turn", "arm_l", Y, 0.0, 15.0, "f"],
				["turn", "head", X, 0.0, 16.0, "f"], ["turn", "upper", X, 0.0, 16.0, "f"], ["move", "upper", Vector3.ZERO, Vector3(0, -0.15, 0), "f"],
				["grow", "gown", 0.0, Vector3(0.06, -0.097, 0.06), "f"]]},
		},
		"moves": {
			## Opens her arms wide to drink in the blows she took, mirrors tipped to the roof, and turns
			## both on the party: two beams of the light thrown back.
			"Reflection": [["turn", "mirror_r", X, -25.0, 0.0, "attack"], ["turn", "mirror_r", Y, 0.0, 14.0, "attack"],
				["turn", "mirror_l", X, -25.0, 0.0, "attack"], ["turn", "mirror_l", Y, 0.0, -14.0, "attack"],
				["turn", "arm_r", Y, -18.0, 28.0, "attack"], ["turn", "arm_r", Z, -14.0, 0.0, "attack"],
				["turn", "arm_l", Y, 18.0, -28.0, "attack"], ["turn", "arm_l", Z, 14.0, 0.0, "attack"],
				["each", "gem", 0.0, 0.6, "pulse"], ["turn", "head", X, -10.0, 6.0, "attack"], ["lean", X, -5.0, 6.0, Vector3.ZERO, "attack"],
				["fx", 0.08, "spiral", {"from": "Core01", "color": "accent", "amount": 30}],
				["fx", 0.26, "flash_light", {"from": "Bob03", "color": "#eef2ff", "energy": 4.0}], ["fx", 0.26, "flash_light", {"from": "Bob09", "color": "#eef2ff", "energy": 4.0}],
				["fx", 0.27, "beam", {"from": "Bob03", "color": "#eef2ff", "width": 0.1}], ["fx", 0.27, "beam", {"from": "Bob09", "color": "#eef2ff", "width": 0.1}],
				["fx", 0.3, "glow", {"from": "Core01", "color": "accent", "size": 0.6}]],
			## Raises both mirrors before her like a shield, glass turned on the party.
			"Mirror": [["turn", "mirror_r", Y, 0.0, -30.0, "hold"], ["turn", "mirror_l", Y, 0.0, 30.0, "hold"],
				["turn", "arm_r", Y, 0.0, 60.0, "hold"], ["turn", "arm_l", Y, 0.0, -60.0, "hold"],
				["turn", "head", X, 0.0, -8.0, "hold"], ["lean", X, 0.0, -3.0, Vector3.ZERO, "hold"],
				["fx", 0.26, "flash_light", {"from": "Bob03", "color": "#eef2ff", "energy": 3.0}], ["fx", 0.3, "flash_light", {"from": "Bob09", "color": "#eef2ff", "energy": 3.0}],
				["fx", 0.3, "sparks", {"from": "Bob03", "color": "#f4eeff", "amount": 12, "speed": 1.5}],
				["fx", 0.32, "sparks", {"from": "Bob09", "color": "#f4eeff", "amount": 12, "speed": 1.5}]],
			## Draws her mirror arm back and flicks a splinter of it at the party (the hex is thrown
			## from the mirror for her).
			"Splinter": [["turn", "mirror_r", X, 0.0, 18.0, REGENT_FLICK], ["turn", "arm_r", Y, -25.0, 32.0, REGENT_FLICK], ["turn", "arm_r", Z, -10.0, 4.0, REGENT_FLICK],
				["turn", "head", Y, 8.0, -6.0, REGENT_FLICK], ["lean", Y, -8.0, 10.0, Vector3.ZERO, REGENT_FLICK],
				["fx", 0.0, "flash_light", {"from": "Bob03", "color": "#eef2ff", "energy": 3.0}],
				["fx", 0.02, "shards", {"from": "Bob03", "color": "accent", "amount": 8, "speed": 2.5}],
				["fx", 0.04, "sparks", {"from": "Bob03", "color": "#f4eeff", "amount": 14, "speed": 3.0}]],
			## Thrusts her left mirror at the party: their own best throw shown back and flung at them.
			"Mirror Image": [["turn", "mirror_l", Y, -10.0, 45.0, "attack"], ["turn", "arm_l", Y, 15.0, -48.0, "attack"], ["turn", "arm_l", X, 0.0, -14.0, "attack"],
				["turn", "head", Z, 0.0, -8.0, "attack"], ["lean", Y, 6.0, -8.0, Vector3.ZERO, "attack"],
				["fx", 0.22, "glow", {"from": "Bob09", "color": "accent", "size": 0.7}],
				["fx", 0.25, "flash_light", {"from": "Bob09", "color": "#eef2ff", "energy": 4.0}],
				["fx", 0.26, "bolt", {"from": "Bob09", "color": "#eef2ff", "flight": 0.12}],
				["fx", 0.3, "sparks", {"from": "Bob09", "color": "#f4eeff", "amount": 16, "speed": 2.5}]],
		},
	},
	## The Quartz Golem (and the Prism Golem, in violet): a pillar of four quartz blocks with a core
	## in its chest. A golem grinds and stomps and is heavy: its blocks grind round on each other,
	## its stack teeters, it rocks onto an edge and stomps down, lifts its blocks and drops them; it
	## bows its whole stack back and brings it down like a hammer.
	"QUARTZ_GOLEM": {
		"mouth": "Core01",
		"groups": {
			## Block on block, each hinged where it sits on the one below.
			"stack": {"chain": [["Block01"], ["Block02"], ["Block03", "Core01"], ["Block04", "Crystal01"]],
				"joints": [Vector3(-0.1, 0.04, 0.0), Vector3(-0.1, 0.66, 0.0), Vector3(-0.03, 1.28, 0.0), Vector3(-0.03, 1.9, 0.0)]},
			"b2": {"parts": ["Block02"], "at": "Block02"},
			"b3": {"parts": ["Block03", "Core01"], "at": "Block03"},
			"b4": {"parts": ["Block04", "Crystal01"], "at": "Block04"},
			"upper": {"parts": ["Block02", "Block03", "Core01", "Block04", "Crystal01"], "at": Vector3(-0.1, 0.66, 0.0)},
			"heart": {"parts": ["Core01"]},
		},
		"idle_gestures": [["look", "b4", 22.0, 0.0, 4.6, 1.8], ["slither", "stack", Z, 1.3, 0.8, 0.7, "tip"]],
		"fidget_every": [6.0, 11.0],
		"fidgets": {
			## Grinds its blocks round on each other, this way and that, grit trickling from the seams.
			"grind": {"length": 3.4, "hold": 1.0, "weight": 2.0, "idle": 0.3, "do": [["turn", "b4", Y, 0.0, -40.0, "f"], ["turn", "b3", Y, 0.0, 30.0, "f"],
				["turn", "b2", Y, 0.0, -16.0, "f"],
				["fx", 0.7, "puff", {"from": "Block03", "off": Vector3(0, 0.31, 0), "color": "#b8ab90", "amount": 6, "size": 0.5, "rise": 0.1}],
				["fx", 1.0, "sparks", {"from": "Block03", "off": Vector3(0, -0.31, 0.2), "color": "#fff0c0", "amount": 6, "speed": 1.0}],
				["fx", 1.4, "puff", {"from": "Block02", "off": Vector3(0, 0.31, 0), "color": "#b8ab90", "amount": 6, "size": 0.5, "rise": 0.1}]]},
			## Rocks onto one edge and stomps down, then the other, the stack wobbling after each.
			"stomp": {"length": 2.9, "weight": 1.5, "idle": 0.3, "do": [["curl", "stack", Z, -2.5, 2.5, GOLEM_WOBBLE, "tip"],
				["lean", Z, 0.0, 7.0, Vector3(-0.42, 0.0, 0.0), GOLEM_ROCK_L], ["lean", Z, 0.0, -7.0, Vector3(0.36, 0.0, 0.0), GOLEM_ROCK_R],
				["fx", 0.86, "shock", {"size": 0.7}], ["fx", 0.87, "puff", {"from": "feet", "color": "#8a7a66", "amount": 10, "size": 1.1, "rise": 0.4}],
				["fx", 2.16, "shock", {"size": 0.75}], ["fx", 2.17, "puff", {"from": "feet", "color": "#8a7a66", "amount": 9, "size": 1.1, "rise": 0.4}]]},
			## Turns its head block right round on its seat to look about, grinding, its crystal glinting.
			"look": {"length": 3.6, "hold": 1.6, "weight": 1.5, "idle": 0.3, "do": [["gaze", "b4", 55.0, 0.0, "f", 2], ["turn", "b3", Y, 0.0, -10.0, "f"],
				["fx", 0.6, "puff", {"from": "Block04", "off": Vector3(0, -0.31, 0), "color": "#b8ab90", "amount": 6, "size": 0.5, "rise": 0.1}],
				["fx", 1.2, "flash_light", {"from": "Crystal01", "color": "tint", "energy": 2.0}],
				["fx", 1.9, "puff", {"from": "Block04", "off": Vector3(0, -0.31, 0), "color": "#b8ab90", "amount": 5, "size": 0.5, "rise": 0.1}]]},
			## Lifts its blocks apart, the core lit in the gaps, and lets them drop back with a thud.
			"settle": {"length": 2.4, "weight": 1.0, "idle": 0.3, "do": [["each", "heart", 0.0, 0.35, GOLEM_LIFT],
				["move", "b4", Vector3.ZERO, Vector3(0, 0.24, 0), GOLEM_LIFT], ["move", "b3", Vector3.ZERO, Vector3(0, 0.16, 0), GOLEM_LIFT],
				["move", "b2", Vector3.ZERO, Vector3(0, 0.08, 0), GOLEM_LIFT],
				["fx", 1.45, "shock", {"size": 0.6}],
				["fx", 1.46, "puff", {"from": "Block03", "off": Vector3(0, -0.31, 0.1), "color": "#b8ab90", "amount": 8, "size": 0.6, "rise": 0.2}]]},
		},
		"moves": {
			## Bows its stack back and pounds it forward, the head block grinding round with the blow.
			"Pound": [["turn", "b4", Y, 6.0, -10.0, "attack"], ["curl", "stack", X, -18.0, 32.0, "attack", "tip"],
				["hop", Vector3(0, 0.06, 0), Vector3(0, -0.03, 0.06), "attack"],
				["fx", 0.3, "shock", {"ahead": 1.0, "size": 1.1}],
				["fx", 0.31, "puff", {"from": "feet", "off": Vector3(0, 0.1, 0.9), "color": "#8a7a66", "amount": 8, "size": 0.9, "rise": 0.4}]],
			## Rears its whole stack back and brings it down like a hammer. Held heavy: its blocks lift
			## apart and grind round as it strains, the core blazing in the gaps.
			"Crush": [["each", "heart", 0.0, 0.5, "h"],
				["turn", "b4", Y, 0.0, 28.0, "h"], ["turn", "b3", Y, 0.0, -22.0, "h"], ["turn", "b2", Y, 0.0, 12.0, "h"],
				["move", "b4", Vector3.ZERO, Vector3(0, 0.12, 0), "h"], ["move", "b3", Vector3.ZERO, Vector3(0, 0.075, 0), "h"],
				["move", "b2", Vector3.ZERO, Vector3(0, 0.035, 0), "h"],
				["curl", "stack", X, -24.0, 40.0, "big", "tip"], ["hop", Vector3(0, 0.1, 0), Vector3(0, -0.04, 0.1), "big"],
				["fx", 0.3, "shock", {"ahead": 1.0, "size": 1.4}], ["fx", 0.32, "dust", {"amount": 60}],
				["fx", 0.31, "shards", {"from": "feet", "off": Vector3(0, 0.2, 1.1), "color": "#d8ccb0", "amount": 10, "speed": 4.0}]],
			## Its blocks grind down into line and it sinks onto its base, core glowing.
			"Fortify": [["each", "heart", 0.0, 0.4, "hold"], ["turn", "b4", Y, 0.0, -14.0, "hold"], ["turn", "b3", Y, 0.0, 10.0, "hold"],
				["move", "upper", Vector3.ZERO, Vector3(0, -0.04, 0), "hold"], ["hop", Vector3.ZERO, Vector3(0, -0.05, 0), "hold"],
				["fx", 0.3, "glow", {"from": "Core01", "color": "core"}],
				["fx", 0.26, "puff", {"from": "feet", "color": "#8a7a66", "amount": 10, "size": 1.1, "rise": 0.3}],
				["fx", 0.28, "sparks", {"from": "Block02", "off": Vector3(0, 0.31, 0.2), "color": "#fff0c0", "amount": 8, "speed": 1.5}]],
			## Turns its blocks to set their facets at odd angles: light split through it like a prism.
			"Refract": [["each", "heart", 0.0, 0.5, "pulse"], ["turn", "b4", Y, 0.0, 45.0, "hold"], ["turn", "b3", Y, 0.0, -35.0, "hold"],
				["turn", "b2", Y, 0.0, 25.0, "hold"],
				["fx", 0.28, "flash_light", {"from": "Core01", "color": "#f4eeff", "energy": 4.0}],
				["fx", 0.3, "sparks", {"from": "Core01", "color": "#e8e0ff", "amount": 20, "speed": 3.0}],
				["fx", 0.3, "ripple", {"from": "Core01", "color": "tint", "radius": 1.2}],
				["fx", 0.32, "glow", {"from": "Core01", "color": "tint", "size": 0.6}]],
			## Its blocks whirl round each other, each its own way, and fling a storm of shards from the
			## core. Held heavy: they lift apart and spin up, the core blazing.
			"Shardstorm": [["each", "heart", 0.0, 0.5, "pulse"], ["each", "heart", 0.0, 0.4, "h"],
				["whirl", "b2", Y, 1.0, "hold"], ["whirl", "b3", Y, -1.0, "hold"], ["whirl", "b4", Y, 1.0, "hold"],
				["move", "b4", Vector3.ZERO, Vector3(0, 0.1, 0), "h"], ["move", "b3", Vector3.ZERO, Vector3(0, 0.06, 0), "h"],
				["move", "b2", Vector3.ZERO, Vector3(0, 0.03, 0), "h"], ["lean", X, -4.0, 6.0, Vector3.ZERO, "attack"],
				["fx", 0.24, "bolt", {"from": "Core01", "color": "core"}],
				["fx", 0.28, "bolt", {"from": "Core01", "color": "core", "arc": 0.8}],
				["fx", 0.32, "bolt", {"from": "Core01", "color": "core", "arc": -0.5}],
				["fx", 0.3, "shards", {"from": "Core01", "color": "core", "amount": 14, "speed": 4.0}]],
		},
		"heavy": {
			## Crush held: grit lifting round its base, the core gathering light, grit sifting from the
			## seams; it lands with a great ring of dust and a spray of quartz off the floor.
			"Crush": {"at": "Core01", "shiver": 1.4,
				"charge": [["charge_dust", {"seconds": 0.5}], ["charge_glow", {"from": "Core01", "color": "core", "seconds": 0.55}],
					["puff", {"from": "Block02", "off": Vector3(0, 0.31, 0), "color": "#b8ab90", "amount": 10, "size": 0.7, "rise": 0.2}],
					["sparks", {"from": "Block03", "color": "core", "amount": 12, "speed": 1.5}]],
				"impact": [["shock", {"ahead": 1.1, "size": 1.8}], ["shards", {"from": "feet", "off": Vector3(0, 0.2, 1.1), "color": "#e0d4b8", "amount": 16, "speed": 5.0}],
					["dust", {"amount": 80}], ["flash_light", {"from": "Core01", "color": "core", "energy": 5.0}]]},
			## Shardstorm held: light spiralling into the core as the blocks spin up, splinters lifting.
			"Shardstorm": {"at": "Core01",
				"charge": [["spiral", {"from": "Core01", "color": "core", "amount": 30}], ["charge_glow", {"from": "Core01", "color": "core", "seconds": 0.5}],
					["charge_dust", {"seconds": 0.45}], ["shards", {"from": "Block03", "color": "core", "amount": 6, "speed": 1.4}]],
				"impact": [["shards", {"from": "Core01", "color": "core", "amount": 18, "speed": 6.0}],
					["flash_light", {"from": "Core01", "color": "core", "energy": 5.0}], ["shock", {"size": 1.1}]]},
		},
	},
}

# --- the moves and idles no table says ---------------------------------------------------------

## The Drill's eight segments, tail to head, with what rides on each.
const DRILL_SEGMENTS: Array = [["Body01-02"], ["Body03-05"], ["Body06-09", "Smoke01-03"], ["Body10-12"], ["Body13-15"],
	["Body16-19", "Smoke04-06"], ["Body20-22"], ["Body23-25", "Head", "Drill"]]

static func _idle_drill(m: Node3D, clock: float, weight: float) -> void:
	## A slow heave running down its arch from tail to head, each segment lifting and tipping a
	## little after the one behind it.
	for index in range(DRILL_SEGMENTS.size()):
		var parts: Array = m._select(DRILL_SEGMENTS[index])
		if parts.is_empty():
			continue
		var wave: float = clock * 1.4 - float(index) * 0.55
		var at: Vector3 = m.centre_of(parts[0])
		m.turn(parts, at, Vector3.RIGHT, deg_to_rad(2.5) * cos(wave) * weight)
		m.shift(parts, Vector3(0, 0.035 * sin(wave), 0) * weight)

## The Foreman's six legs, front to back on its right (-x) and then its left (+x): the side each
## lifts toward (+z raises a part on its left, -z on its right) and which of the two tripods it
## steps with.
const FOREMAN_LEGS: Array = [["Leg01-03", -1.0, 0], ["Leg04-06", -1.0, 1], ["Leg07-09", -1.0, 0],
	["Leg10-12", 1.0, 1], ["Leg13-15", 1.0, 0], ["Leg16-18", 1.0, 1]]

static func _idle_foreman(m: Node3D, clock: float, weight: float) -> void:
	## Now and then one of its six feet lifts and sets down again: a crab shifting its footing.
	var every: float = 1.6
	var step: int = int(floor(clock / every))
	var local: float = clock - float(step) * every
	if local > 0.45:
		return
	var pick: int = int(absf(m._noise(step * 7 + m.noise_seed)) * 997.0) % FOREMAN_LEGS.size()
	var leg: Array = FOREMAN_LEGS[pick]
	var parts: Array = m._select(leg[0])
	if parts.is_empty():
		return
	var hip: Vector3 = (parts[0] as Node3D).get("_rest").origin
	m.turn(parts, hip, Vector3.BACK, deg_to_rad(9.0) * float(leg[1]) * sin(local / 0.45 * PI) * weight)

static func _foreman_scuttle(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its legs scuttling in two tripods while it sidesteps: three lift and swing through while the
	## other three hold, eased in and out with the step (FOREMAN_GAIT).
	var t: float = float(clip.get("keyed", float(clip.t)))
	var k: float = m.value(FOREMAN_GAIT, t) * float(clip.get("weight", 1.0))
	if absf(k) < 0.0001:
		return
	for leg in FOREMAN_LEGS:
		var parts: Array = m._select(leg[0])
		if parts.is_empty():
			continue
		var hip: Vector3 = (parts[0] as Node3D).get("_rest").origin
		var beat: float = t * 11.0 + PI * float(leg[2])
		m.turn(parts, hip, Vector3.BACK, deg_to_rad(14.0) * float(leg[1]) * maxf(0.0, sin(beat)) * k)
		m.turn(parts, hip, Vector3.UP, deg_to_rad(9.0) * cos(beat) * k)
