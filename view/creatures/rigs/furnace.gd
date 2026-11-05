extends RefCounted
## The Furnace: the mine of fire and slag.
## Each creature's rig as data (see the gesture language in creature_rigs.gd), keyed by its scene,
## and the moves and idles no table says, written out as functions of the Moves node
## (creature_moves.gd) passed in as `m`. creature_rigs.gd merges every mine's RIGS.
## Pass 2 (November 3, 2026): trope idles, fidgets, heavy blows and ability flourishes for all
## seven (build/rework/ANIM2_BRIEF.md); films in build/anim/p2/furnace/.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {}
## When a move played by a function is wound back furthest (a heavy one holds there).
const CUSTOM_WIND: Dictionary = {}

## The Forge Imp's two hops on the spot (-1 crouched, +1 in the air).
const IMP_HOPS: Array = [[0.0, 0.0], [0.15, -1.0], [0.32, 1.0], [0.5, 0.0], [0.56, -0.6], [0.72, 1.0], [0.9, 0.0], [0.98, -0.4], [1.15, 0.0]]
## The Salamander's tongue of flame flicked out twice, its push-ups (three pumps of its front),
## its crawl on the spot (two diagonal pairs of legs stepping in turn, the body swinging to each).
const SAL_FLICKS: Array = [[0.0, 0.0], [0.55, 0.0], [0.62, 1.0], [0.78, 0.0], [1.0, 0.0], [1.07, 1.0], [1.23, 0.0]]
const SAL_PUMPS: Array = [[0.0, 0.0], [0.3, 1.0], [0.5, 0.25], [0.75, 1.0], [0.95, 0.25], [1.2, 1.0], [1.5, 1.0], [2.0, 0.0]]
const SAL_STEP_A: Array = [[0.0, 0.0], [0.25, 1.0], [0.5, 0.0], [1.1, 0.0], [1.35, 1.0], [1.6, 0.0]]
const SAL_STEP_B: Array = [[0.0, 0.0], [0.55, 0.0], [0.8, 1.0], [1.05, 0.0], [1.65, 0.0], [1.9, 1.0], [2.15, 0.0]]
const SAL_SWING: Array = [[0.0, 0.0], [0.3, 1.0], [0.85, -1.0], [1.4, 1.0], [1.9, -0.5], [2.2, 0.0]]
## The Slag Hound worrying what it bit: its head shaken side to side after the jaws shut.
const HOUND_WORRY: Array = [[0.0, 0.0], [0.32, 0.0], [0.38, 1.0], [0.44, -1.0], [0.5, 1.0], [0.56, -0.7], [0.62, 0.4], [0.72, 0.0]]
## The Ember Crawler's Spit, started early (its lead 0.45): reared up slowly, held, spat.
const CRAWLER_REAR: Array = [[-0.15, 0.0], [0.08, -1.0], [0.2, -1.0], [0.28, 1.0], [0.45, 1.0], [0.95, 0.0]]
## The Smelter's stamp of one pillar leg: +1 lifted, -1 the jolt as it lands.
const SMELT_STOMP: Array = [[0.0, 0.0], [0.6, 1.0], [0.78, 1.0], [0.9, -1.0], [1.05, -0.2], [1.4, 0.0]]
## The Anvil Knight's weight shifted onto one leg and then the other; its hammer lifted and
## thumped down again; its fire guttering as the hammer hisses, then flaring back.
const KNIGHT_SHIFT: Array = [[0.0, 0.0], [0.8, 1.0], [1.5, 1.0], [2.3, -0.8], [2.9, -0.8], [3.5, 0.0]]
const KNIGHT_GRIP: Array = [[0.0, 0.0], [0.45, 1.0], [0.8, 1.0], [0.95, -1.0], [1.15, 0.0]]
const KNIGHT_PLANT: Array = [[0.0, 0.0], [0.18, 1.0], [0.3, -1.0], [0.85, -1.0], [1.2, 0.0]]
const QUENCH: Array =[[0.0, 0.0], [0.18, -1.0], [0.3, -1.0], [0.45, 1.0], [0.85, 1.0], [1.2, 0.0]]
## The Kiln Dragon's tail lashed one way and the other; its claw pressed down and drawn back with
## what it pinned; its tail swept across and back (two hits).
const KILN_LASH: Array = [[0.0, 0.0], [0.4, 1.0], [0.75, -1.0], [1.1, 0.7], [1.45, -0.3], [1.9, 0.0]]
const KILN_PIN: Array = [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.55, 1.0], [0.75, -0.25], [1.1, 0.0]]
const KILN_SWEEP: Array = [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.37, 1.0], [0.48, -1.0], [0.55, -1.0], [1.0, 0.0]]

const RIGS: Dictionary = {
	## An impish smith: it jigs from foot to foot, twirls its hammer like a baton, hops about and
	## cackles fire.
	"FORGE_IMP": {
		"mouth": "Mouth01",
		"idle": "_idle_imp",
		"groups": {"hammer": {"parts": ["ArmR", "Hammer"], "at": "ArmR01"}, "head": {"parts": ["Head", "Jaw", "Mouth"], "at": "Head01"},
			"jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			## The hammer alone, about the fist that holds it (for a baton twirl).
			"haft": {"parts": ["Hammer"], "at": Vector3(-0.37, 0.5, 0.16)},
			"leg_l": {"parts": ["Leg01-04"], "at": "Leg01"}, "leg_r": {"parts": ["Leg05-08"], "at": "Leg05"},
			"tail": {"parts": ["Tail"], "at": "Tail01"}},
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Throws its arm out and twirls the hammer round its fist twice, sparks off the hot face.
			"twirl": {"length": 2.4, "hold": 1.0, "weight": 2.0, "do": [["whirl", "haft", Z, 2.0, "f"], ["turn", "hammer", Z, 0.0, -38.0, "f"],
				["turn", "head", Y, 0.0, -14.0, "f"],
				["fx", 0.9, "sparks", {"from": "Hammer05", "color": "#ffb050", "amount": 10, "speed": 1.8}],
				["fx", 1.3, "sparks", {"from": "Hammer05", "color": "#ffb050", "amount": 10, "speed": 1.8}]]},
			## Cackles to itself: head thrown back, jaw chattering, shoulders shaking, a wisp of smoke.
			"cackle": {"length": 1.8, "hold": 0.8, "weight": 1.5, "do": [["turn", "jaw", X, -4.0, 16.0, "shake"], ["turn", "head", X, 0.0, -16.0, "f"],
				["hop", Vector3(0, 0.015, 0), Vector3(0, 0.025, 0), "shake"],
				["fx", 0.5, "puff", {"from": "Mouth01", "color": "#4a3c36", "amount": 6, "size": 0.35, "rise": 0.5}]]},
			## Hops on the spot twice, knees up, hammer and tail bouncing, landing in puffs of soot.
			"hop": {"length": 1.6, "hold": 0.2, "weight": 1.5, "do": [["turn", "leg_l", X, 0.0, -20.0, IMP_HOPS], ["turn", "leg_r", X, 0.0, -20.0, IMP_HOPS],
				["turn", "hammer", X, 4.0, -10.0, IMP_HOPS], ["turn", "tail", X, 0.0, 25.0, IMP_HOPS],
				["hop", Vector3(0, -0.04, 0), Vector3(0, 0.22, 0), IMP_HOPS],
				["fx", 0.5, "puff", {"from": "feet", "color": "#5a4a40", "amount": 6, "size": 0.4, "rise": 0.3}],
				["fx", 0.9, "puff", {"from": "feet", "color": "#5a4a40", "amount": 6, "size": 0.4, "rise": 0.3}]]},
		},
		"moves": {
			## Leaps with the hammer swung up behind it and smashes it into the floor as it lands.
			"Hammer": [["turn", "hammer", X, -25.0, 140.0, "big"], ["turn", "head", X, -12.0, 14.0, "big"],
				["turn", "leg_l", X, -18.0, 0.0, "big"], ["turn", "leg_r", X, -18.0, 0.0, "big"],
				["hop", Vector3(0, 0.2, -0.04), Vector3(0, -0.02, 0.1), "big"], ["rear", 0.12, "big"],
				["fx", 0.3, "shock", {"from": "Hammer03", "size": 0.7}], ["fx", 0.3, "sparks", {"from": "Hammer03", "color": "#ffb050", "amount": 36, "speed": 4.5}],
				["fx", 0.3, "flash_light", {"from": "Hammer03", "color": "#ffb050", "energy": 3.0}]],
			## Throws its head back cackling, jaw chattering, then leans in and laughs a gout of fire.
			"Cackle": [["turn", "jaw", X, -6.0, 22.0, "shake"], ["turn", "head", X, -20.0, 12.0, "breath"], ["hop", Vector3(0, 0.02, 0), Vector3(0, 0.03, 0), "shake"],
				["turn", "hammer", Z, 0.0, -18.0, "hold"],
				["fx", 0.1, "sparks", {"from": "Mouth01", "color": "#ffb050", "amount": 10, "speed": 1.5}],
				["fx", 0.24, "breath", {"kind": "fire", "seconds": 0.42, "size": 0.55}]],
			## Heats its hammer's face red and taps away at the die, sparks flying at every tap.
			"Heat Treat": [["turn", "hammer", X, 55.0, 108.0, "thrice"], ["turn", "head", X, 0.0, 14.0, "hold"],
				["fx", 0.02, "glow", {"from": "Hammer05", "color": "#ff8a30", "size": 0.35, "seconds": 0.3}],
				["fx", 0.3, "sparks", {"from": "Hammer05", "color": "#ffb050", "amount": 16, "speed": 2.5}],
				["fx", 0.52, "sparks", {"from": "Hammer05", "color": "#ffb050", "amount": 16, "speed": 2.5}],
				["fx", 0.74, "sparks", {"from": "Hammer05", "color": "#ffb050", "amount": 16, "speed": 2.5}]],
		},
	},
	## A fire lizard on its rock: it tastes the air with a flick of flame, does push-ups, crawls on
	## the spot with its body swinging, flares the flames of its mane and swishes its tail.
	"SALAMANDER": {
		"mouth": "Mouth01",
		"groups": {"head": {"parts": ["Head", "Jaw", "Mouth"], "at": "Head01"}, "jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"paw_r": {"parts": ["Leg01", "Leg02", "Leg05-07"], "at": "Leg01"}, "paw_l": {"parts": ["Leg11", "Leg12", "Leg15-17"], "at": "Leg11"},
			"hind_r": {"parts": ["Leg03", "Leg04", "Leg08-10"], "at": "Leg03"}, "hind_l": {"parts": ["Leg13", "Leg14", "Leg18-20"], "at": "Leg13"},
			"mane": {"parts": ["Mane"]}, "chest": {"parts": ["Chest01"]}, "tail": {"parts": ["Tail"], "at": "Tail01"},
			"embers": {"parts": ["Ember"]},
			## Its front half, for the push-ups (the forelegs ride it, turned back to keep their feet down).
			"fore": {"parts": ["Head", "Jaw", "Mouth", "Core03-05", "Chest01", "Mane04-07", "Leg01", "Leg02", "Leg05-07", "Leg11", "Leg12", "Leg15-17"],
				"at": Vector3(0, 0.45, -0.25)},
			## All of it but the rock it stands on and the embers drifting off it.
			"body": {"parts": ["Head", "Jaw", "Mouth", "Core", "Chest", "Mane", "Tail", "Leg"], "at": Vector3(0, 0.4, -0.1)}},
		"idle_gestures": [["breathe", "chest", 0.12, 1.5, 0.0], ["look", "head", 16.0, 6.0, 2.6, 0.5], ["sway", "tail", Y, 10.0, 1.1, 0.0],
			["sway", "body", Y, 1.5, 0.55, 0.4]],
		"fidget_every": [5.0, 9.5],
		"fidgets": {
			## Tastes the air: the jaw flicks open twice, a tongue of flame darting out each time.
			"taste": {"length": 1.8, "hold": 0.9, "weight": 2.0, "idle": 0.0, "do": [["turn", "jaw", X, 0.0, 16.0, SAL_FLICKS],
				["turn", "head", Z, 0.0, 10.0, "f"], ["turn", "head", X, 0.0, -8.0, "f"], ["move", "embers", Vector3.ZERO, Vector3(0, -0.02, 0.16), SAL_FLICKS],
				["fx", 0.6, "glow", {"from": "Mouth01", "color": "#ffb050", "size": 0.25, "seconds": 0.15}],
				["fx", 0.62, "sparks", {"from": "Mouth01", "color": "#ffc070", "amount": 6, "speed": 1.2, "life": 0.35}],
				["fx", 1.05, "glow", {"from": "Mouth01", "color": "#ffb050", "size": 0.25, "seconds": 0.15}],
				["fx", 1.07, "sparks", {"from": "Mouth01", "color": "#ffc070", "amount": 6, "speed": 1.2, "life": 0.35}]]},
			## Lizard push-ups on its rock: the front half pumped up three times, head bobbing.
			"push_up": {"length": 2.2, "weight": 1.5, "idle": 0.0, "do": [["turn", "head", X, 0.0, 8.0, SAL_PUMPS],
				["turn", "paw_r", X, 0.0, 22.0, SAL_PUMPS], ["turn", "paw_l", X, 0.0, 22.0, SAL_PUMPS], ["turn", "fore", X, 0.0, -12.0, SAL_PUMPS]]},
			## Flares its mane: every flame down its spine leaps up, its chest glows, embers stream off.
			"flare": {"length": 2.6, "hold": 1.1, "weight": 1.5, "idle": 0.0, "do": [["each", "mane", 0.0, Vector3(0.2, 0.7, 0.2), "f"],
				["each", "chest", 0.0, 0.25, "f"], ["turn", "head", X, 0.0, -14.0, "f"], ["turn", "tail", X, 0.0, 12.0, "f"],
				["fx", 0.7, "rise", {"from": "Mane04", "color": "#ffb050", "amount": 14, "size": 0.7}],
				["fx", 0.8, "sparks", {"from": "Mane06", "color": "#ffc070", "amount": 14, "speed": 2.0}],
				["fx", 0.75, "flash_light", {"from": "Mane04", "color": "#ff8a30", "energy": 2.5}]]},
			## Crawls on the spot: legs stepping in diagonal pairs, the body swinging to each, the tail
			## swinging against it.
			"crawl": {"length": 2.2, "weight": 1.2, "do": [["turn", "paw_r", X, 0.0, -24.0, SAL_STEP_A], ["turn", "hind_l", Z, 0.0, 18.0, SAL_STEP_A],
				["turn", "paw_l", X, 0.0, -24.0, SAL_STEP_B], ["turn", "hind_r", Z, 0.0, -18.0, SAL_STEP_B],
				["turn", "tail", Y, 14.0, -14.0, SAL_SWING], ["turn", "body", Y, -5.0, 5.0, SAL_SWING]]},
		},
		"moves": {
			## Rears its front off the rock and rakes the right foreclaw down, head swung aside.
			"Scratch": [["turn", "paw_r", X, -70.0, 25.0, "attack"], ["turn", "head", Y, 0.0, 14.0, "attack"], ["turn", "head", X, -8.0, 10.0, "attack"],
				["turn", "fore", X, -8.0, 3.0, "attack"], ["rear", 0.3, "attack"],
				["fx", 0.29, "swipe", {"about": "paw_r", "axis": X, "start": Vector3(0, 1, 0.2), "radius": 0.5, "sweep": 120.0}],
				["fx", 0.3, "sparks", {"from": "Leg05", "color": "#ffb050", "amount": 12, "speed": 2.5}]],
			## Breathes in, chest and mane swelling and its throat gem lit, and spits a stream of embers.
			"Ember": [["each", "mane", 0.0, Vector3(0, 0.6, 0), "breath"], ["each", "chest", 0.2, 0.05, "breath"], ["turn", "jaw", X, 0.0, 25.0, "breath"],
				["turn", "head", X, -25.0, 10.0, "breath"], ["turn", "tail", X, 0.0, 10.0, "breath"],
				["fx", 0.05, "glow", {"from": "Head03", "color": "#ff8a30", "size": 0.3, "seconds": 0.25}],
				["fx", 0.26, "breath", {"kind": "fire", "seconds": 0.4, "size": 0.7}],
				["fx", 0.28, "sparks", {"from": "Mouth01", "color": "#ffb050", "amount": 18, "speed": 3.0}]],
		},
	},
	## A hound of slag and chain: it pants, wags, sniffs the floor, shakes itself like a wet dog,
	## scratches, growls with its fangs bared; it mauls, biting and worrying what it bit.
	"SLAG_HOUND": {
		"mouth": "Mouth01",
		"groups": {"neck": {"parts": ["Neck", "Head", "Jaw", "Mouth", "Drool", "Chain"], "at": "Neck01"},
			"head": {"parts": ["Head", "Jaw", "Mouth", "Drool"], "at": "Head01"}, "jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"paw_r": {"parts": ["Leg01", "Leg02", "Leg05"], "at": "Leg01"}, "crest": {"parts": ["Crest"]}, "tail": {"parts": ["Tail"], "at": "Tail01"},
			"chain": {"parts": ["Chain"], "at": "Chain01"},
			"leg_rb": {"parts": ["Leg03", "Leg04", "Leg06"], "at": "Leg03"},
			## All of it above its legs, to shake.
			"torso": {"parts": ["Neck", "Head", "Jaw", "Mouth", "Drool", "Chain", "Crest", "Tail", "Rock", "Core01"], "at": Vector3(0, 0.8, 0)}},
		"idle_gestures": [["pant", "jaw", X, 9.0, 14.0], ["pant", "head", X, 1.5, 14.0], ["wag", "tail", Y, 16.0, 7.0], ["look", "neck", 9.0, 4.0, 3.2, 1.0]],
		"fidget_every": [5.0, 9.5],
		"fidgets": {
			## Noses along the floor, sniffing this way and that, ash puffing at its nostrils.
			"sniff": {"length": 3.2, "hold": 1.6, "weight": 2.0, "idle": 0.0, "do": [["turn", "jaw", X, 0.0, -10.0, "f"], ["turn", "head", X, 0.0, 4.0, "pant"],
				["gaze", "head", 24.0, 6.0, "f", 3], ["turn", "neck", X, 0.0, 26.0, "f"],
				["fx", 1.0, "puff", {"from": "Mouth01", "color": "#4a4440", "amount": 5, "size": 0.35, "rise": 0.25}],
				["fx", 1.7, "puff", {"from": "Mouth01", "color": "#4a4440", "amount": 5, "size": 0.35, "rise": 0.25}],
				["fx", 2.3, "puff", {"from": "Mouth01", "color": "#4a4440", "amount": 5, "size": 0.35, "rise": 0.25}]]},
			## Growls: head low, fangs bared, the slag down its back bristling, a shiver through it.
			"growl": {"length": 2.4, "hold": 1.0, "weight": 1.5, "idle": 0.0, "do": [["turn", "jaw", X, 0.0, 12.0, "bare"], ["tremble", "head", 0.006, "f"],
				["turn", "head", X, 0.0, 10.0, "f"], ["turn", "neck", X, 0.0, 12.0, "f"], ["each", "crest", 0.0, Vector3(0.15, 0.6, 0.15), "f"],
				["turn", "tail", X, 0.0, 15.0, "f"], ["hop", Vector3.ZERO, Vector3(0, -0.04, -0.05), "f"],
				["fx", 0.6, "glow", {"from": "Mouth01", "color": "#ff7a2a", "size": 0.3, "seconds": 0.6}],
				["fx", 0.7, "puff", {"from": "Mouth01", "color": "#3a3230", "amount": 6, "size": 0.4, "rise": 0.4}]]},
			## Shakes itself like a wet dog, cinders flying off its back and its chain swinging.
			"shake": {"length": 1.8, "hold": 0.6, "weight": 1.2, "idle": 0.0, "do": [["turn", "chain", Z, 0.0, 22.0, "shake"], ["turn", "neck", Z, 0.0, 10.0, "shake"],
				["turn", "tail", Y, 0.0, 18.0, "shake"], ["turn", "torso", Z, 0.0, 4.0, "shake"],
				["fx", 0.6, "sparks", {"from": "centre", "color": "#ff9a40", "amount": 20, "speed": 3.0}],
				["fx", 0.6, "puff", {"from": "centre", "color": "#4a4440", "amount": 8, "size": 0.7, "rise": 0.4}]]},
			## Scratches behind its ear with a hind paw, head cocked down to meet it.
			"scratch": {"length": 2.2, "hold": 1.0, "weight": 1.0, "idle": 0.0, "do": [["turn", "leg_rb", X, 0.0, -10.0, "scrabble"], ["turn", "leg_rb", X, 0.0, -38.0, "f"],
				["turn", "neck", Z, 0.0, 14.0, "f"], ["turn", "neck", Y, 0.0, -12.0, "f"], ["lean", Z, 0.0, -3.0, Vector3.ZERO, "f"]]},
		},
		"moves": {
			## Lunges with the right forepaw raking down, bites, and worries its prey with a shake.
			"Maul": [["turn", "jaw", X, 10.0, -30.0, "snap"], ["turn", "head", Z, -12.0, 12.0, HOUND_WORRY], ["turn", "head", X, -15.0, 15.0, "attack"],
				["turn", "neck", X, -10.0, 18.0, "attack"], ["turn", "paw_r", X, -55.0, 20.0, "attack"], ["rear", 0.45, "attack"],
				["fx", 0.29, "swipe", {"about": "paw_r", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 0.6, "sweep": 120.0}],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ff9a40", "amount": 18, "speed": 3.0}]],
			## Sits back and howls at the roof, the slag down its back bristling, smoke and sparks thrown up.
			"Howl": [["turn", "jaw", X, 0.0, 20.0, "hold"], ["tremble", "head", 0.006, "hold"], ["turn", "head", X, 0.0, -40.0, "hold"], ["turn", "neck", X, 0.0, -15.0, "hold"],
				["each", "crest", 0.0, 0.5, "hold"], ["turn", "tail", X, 0.0, 12.0, "hold"], ["lean", X, 0.0, -6.0, Vector3(0, 0, -0.8), "hold"],
				["fx", 0.3, "ripple", {"from": "Mouth01", "color": "#ff8a30", "radius": 1.5}],
				["fx", 0.45, "ripple", {"from": "Mouth01", "color": "#ff8a30", "radius": 2.2}],
				["fx", 0.32, "jet", {"from": "Mouth01", "color": "#ff9a40", "amount": 16, "speed": 2.5}],
				["fx", 0.3, "puff", {"from": "Mouth01", "color": "#3a3230", "amount": 8, "size": 0.5, "rise": 1.0}]],
		},
	},
	## A centipede of embers: its legs ripple in waves down its length, its antennae feel the air,
	## its pincers clack; it rears up tall to spit molten slag.
	"EMBER_CRAWLER": {
		"mouth": "Mouth01",
		"lead": {"Spit": 0.45},
		"idle": "_idle_crawler",
		"groups": {
			"front": {"chain": [["Neck05", "Neck06", "Leg05", "Leg06"], ["Neck03", "Neck04", "Leg03", "Leg04"], ["Neck01", "Neck02", "Leg01", "Leg02"]],
				"riders": ["Head", "ClawL", "ClawR", "Antenna", "Mouth"]},
			"head": {"parts": ["Head", "ClawL", "ClawR", "Antenna", "Mouth"], "at": "Head01"},
			"claw_l": {"parts": ["ClawL"], "at": "ClawL01"},
			"claw_r": {"parts": ["ClawR"], "at": "ClawR01"},
			"antennae": {"parts": ["Antenna"], "at": "Head01"},
			"legs": {"parts": ["Leg"]},
		},
		"idle_gestures": [["sway", "Antenna01", X, 10.0, 3.1, 0.0], ["sway", "Antenna02", X, 10.0, 3.1, 1.3], ["look", "head", 10.0, 5.0, 2.8, 0.7]],
		"fidget_every": [5.0, 9.5],
		"fidgets": {
			## Raises its front to feel the air, antennae waving, pincers apart, head turning.
			"feel": {"length": 3.4, "hold": 1.6, "weight": 2.0, "idle": 0.0, "do": [["turn", "claw_l", Y, 0.0, 18.0, "f"], ["turn", "claw_r", Y, 0.0, -18.0, "f"],
				["wave_each", "antennae", X, 22.0, 9.0, 1.4, "f"], ["gaze", "head", 30.0, 10.0, "f", 3], ["curl", "front", X, 0.0, -32.0, "f", "tip"]]},
			## A ripple runs down its legs from head to tail, the ember gems flaring one after another.
			"ripple": {"length": 2.4, "hold": 1.0, "weight": 2.0, "do": [["wave_each", "legs", Y, 20.0, 11.0, 0.55, "f"], ["call", "_crawler_glow"],
				["fx", 0.8, "puff", {"from": "Core05", "color": "#5a4a40", "amount": 6, "size": 0.4, "rise": 0.2}],
				["fx", 1.2, "puff", {"from": "Core09", "color": "#5a4a40", "amount": 6, "size": 0.4, "rise": 0.2}]]},
			## Clacks its pincers together twice, head bobbing, sparks spitting between them.
			"clack": {"length": 1.6, "hold": 0.5, "weight": 1.5, "idle": 0.0, "do": [["turn", "claw_l", Y, -10.0, 28.0, "chomp"], ["turn", "claw_r", Y, 10.0, -28.0, "chomp"],
				["turn", "head", X, 4.0, 8.0, "nod"],
				["fx", 0.24, "sparks", {"from": "Mouth01", "color": "#ffb050", "amount": 8, "speed": 1.5}],
				["fx", 0.56, "sparks", {"from": "Mouth01", "color": "#ffb050", "amount": 8, "speed": 1.5}]]},
		},
		"moves": {
			## Rears a little and lunges, pincers snapping shut on the party, embers spitting.
			"Bite": [["turn", "claw_l", Y, 30.0, -12.0, "snap"], ["turn", "claw_r", Y, -30.0, 12.0, "snap"], ["turn", "head", X, -15.0, 15.0, "attack"],
				["curl", "front", X, -16.0, 8.0, "attack", "tip"], ["rear", 0.35, "attack"],
				["fx", 0.29, "sparks", {"from": "Mouth01", "color": "#ffb050", "amount": 14, "speed": 2.5}]],
			## Rears up tall, antennae laid back and legs churning, and spits a gob of molten slag.
			"Spit": [["wave_each", "legs", Y, 14.0, 14.0, 0.5, "hold"], ["turn_each", "antennae", X, -35.0, -10.0, CRAWLER_REAR],
				["turn", "claw_l", Y, 50.0, 15.0, CRAWLER_REAR], ["turn", "claw_r", Y, -50.0, -15.0, CRAWLER_REAR],
				["turn", "head", X, 78.0, 10.0, CRAWLER_REAR],
				["curl", "front", X, -95.0, -20.0, [[-0.15, 0.0], [0.08, -1.0], [0.2, -1.0], [0.28, 1.0], [0.45, 1.0], [1.0, 0.0]], "tip"],
				["fx", 0.09, "glow", {"from": "Mouth01", "color": "#ff8a30", "size": 0.4, "seconds": 0.2}],
				["fx", 0.15, "glow", {"from": "Mouth01", "color": "#ffb050", "size": 0.5, "seconds": 0.15}],
				["fx", 0.2, "spit", {"color": "#ff8a30", "kind": "molten", "flight": 0.12, "size": 1.6}]],
			## Bows its front, pincers wide, and breathes a sheet of fire along the floor.
			"Sear": [["turn_each", "antennae", X, 0.0, -25.0, "breath"], ["turn", "claw_l", Y, 0.0, 30.0, "breath"], ["turn", "claw_r", Y, 0.0, -30.0, "breath"],
				["turn", "head", X, 12.0, 6.0, "breath"], ["curl", "front", X, -25.0, -12.0, "breath", "tip"],
				["fx", 0.26, "breath", {"kind": "fire", "seconds": 0.45, "size": 0.8}],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ffb050", "amount": 14, "speed": 2.5}]],
		},
	},
	## A volcano tortoise: its crater bubbles and vents smoke, it stamps its pillar legs, draws its
	## head into its shell, swings the crucible hung from its beak; it tramples, reared up high.
	"THE_SMELTER": {
		"mouth": "Crucible03",
		"idle": "_idle_smelter",
		"ambient": [{"kind": "bubbling", "at": "Crater01", "color": "#ff7a2a", "size": 1.2}, {"kind": "smoke", "at": "Crater01", "off": Vector3(0, 0.2, 0), "color": "#2a2422", "size": 1.8}],
		"groups": {"rim": {"parts": ["Crater02-07"]}, "lava": {"parts": ["Lava"]}, "vein": {"parts": ["Vein"]}, "flames": {"parts": ["Lava02-05"]},
			"shell": {"parts": ["Shell", "Crater", "Lava", "Ember", "Vein"], "at": "Shell01"},
			"neck": {"parts": ["Neck", "Head", "Beak", "Crucible"], "at": "Neck01"}, "head": {"parts": ["Head", "Beak", "Crucible"], "at": "Head01"},
			"crucible": {"parts": ["Crucible"], "at": Vector3(0, 0.871, 2.295)},
			## The lava in the pot, about its own middle.
			"pot": {"parts": ["Crucible04"], "at": Vector3(0, 0.63, 2.39)},
			"leg_rf": {"parts": ["Leg01-07"], "at": "Leg01"}, "leg_lf": {"parts": ["Leg15-21"], "at": "Leg15"}},
		"idle_gestures": [["sway", "crucible", X, 3.0, 1.25, 0.0], ["sway", "crucible", Z, 2.5, 0.9, 1.0], ["look", "neck", 8.0, 3.0, 4.2, 1.5]],
		"fidget_every": [3.5, 7.0],
		"fidgets": {
			## The crater vents: rim rocks heaving, the flames leaping, a plume of smoke and a spray of embers.
			"vent": {"length": 2.6, "hold": 0.9, "weight": 2.0, "do": [["move", "rim", Vector3.ZERO, Vector3(0, 0.08, 0), "f"],
				["each", "flames", 0.0, Vector3(0.3, 1.0, 0.3), "f"], ["each", "vein", 0.0, 0.3, "f"], ["tremble", "shell", 0.008, "f"],
				["fx", 0.6, "jet", {"from": "Crater01", "color": "#ff8a30", "amount": 26, "speed": 3.2}],
				["fx", 0.55, "puff", {"from": "Crater01", "color": "#2a2422", "amount": 14, "size": 1.3, "rise": 1.6}],
				["fx", 1.0, "puff", {"from": "Crater01", "color": "#3a3230", "amount": 10, "size": 1.2, "rise": 1.4}],
				["fx", 0.6, "flash_light", {"from": "Crater01", "color": "#ff7a2a", "energy": 3.0}]]},
			## Lifts a pillar leg and stamps it down: the ground jolts, the lava jumps, dust puffs.
			"stomp": {"length": 2.0, "weight": 1.5, "do": [["move", "leg_rf", Vector3.ZERO, Vector3(0, 0.3, 0.04), SMELT_STOMP],
				["move", "rim", Vector3(0, 0.07, 0), Vector3.ZERO, SMELT_STOMP], ["each", "flames", Vector3(0.2, 0.9, 0.2), 0.0, SMELT_STOMP],
				["move", "shell", Vector3(0, -0.03, 0), Vector3.ZERO, SMELT_STOMP], ["lean", Z, 0.0, -2.0, Vector3(1.4, 0, 0), SMELT_STOMP],
				["fx", 0.9, "shock", {"from": "Leg05", "size": 0.55}],
				["fx", 0.92, "puff", {"from": "Leg05", "color": "#5a4a40", "amount": 8, "size": 0.6, "rise": 0.4}],
				["fx", 0.95, "jet", {"from": "Crater01", "color": "#ff8a30", "amount": 14, "speed": 2.4}]]},
			## Stretches its neck out of its shell and looks about.
			"look": {"length": 4.2, "hold": 2.4, "weight": 2.0, "do": [["gaze", "neck", 30.0, 10.0, "f", 3],
				["move", "neck", Vector3.ZERO, Vector3(0, 0.04, 0.14), "f"]]},
			## Pulls its head into its shell, sinking down on its legs, and slowly puts it out again.
			"withdraw": {"length": 3.4, "hold": 1.2, "weight": 1.2, "do": [["turn", "neck", X, 0.0, 12.0, "f"], ["move", "neck", Vector3.ZERO, Vector3(0, -0.06, -0.38), "f"],
				["move", "shell", Vector3.ZERO, Vector3(0, -0.05, 0), "f"],
				["fx", 1.1, "puff", {"from": "Crater01", "color": "#2a2422", "amount": 10, "size": 1.1, "rise": 1.2}]]},
			## Swirls the crucible round under its beak, molten drops spitting out of it.
			"swirl": {"length": 3.0, "hold": 1.4, "weight": 1.2, "do": [["call", "_smelter_swirl"], ["turn", "head", X, 0.0, 8.0, "f"],
				["fx", 1.0, "sparks", {"from": "Crucible04", "color": "#ffb050", "amount": 10, "speed": 1.6}],
				["fx", 1.7, "sparks", {"from": "Crucible04", "color": "#ffb050", "amount": 10, "speed": 1.6}]]},
		},
		"moves": {
			## Swings its crucible up from its beak and pours molten metal at the party.
			"Pour": [["turn", "crucible", X, 20.0, -65.0, "big"], ["turn", "neck", X, -8.0, 18.0, "big"], ["move", "rim", Vector3.ZERO, Vector3(0, 0.14, 0), "pulse"],
				["each", "lava", 0.0, Vector3(0.3, 0.8, 0.3), "pulse"], ["fx", 0.27, "erupt", {"from": "Crater01", "color": "#ff7a2a", "size": 1.0}],
				["fx", 0.22, "spit", {"from": "Crucible03", "color": "#ff8a30", "kind": "molten", "flight": 0.08, "size": 1.4, "arc": 0.2}]],
			## The crater boils over and the crucible breathes scalding steam.
			"Scald": [["move", "rim", Vector3.ZERO, Vector3(0, 0.14, 0), "pulse"], ["each", "lava", 0.0, Vector3(0.3, 0.8, 0.3), "pulse"],
				["turn", "crucible", X, 10.0, -20.0, "breath"], ["turn", "head", X, -10.0, 10.0, "breath"],
				["fx", 0.25, "erupt", {"from": "Crater01", "size": 0.9}],
				["fx", 0.28, "breath", {"from": "Crucible03", "kind": "steam", "color": "#e8e0d8", "seconds": 0.5, "size": 1.2}]],
			## Rears its front up on its hind legs, both forefeet high, and stamps down: one foot, then again.
			"Trample": [["move", "leg_rf", Vector3(0, 0.42, 0.1), Vector3(0, -0.02, 0.04), "twice"], ["move", "leg_lf", Vector3(0, 0.42, 0.1), Vector3(0, -0.02, 0.04), "big"],
				["turn", "crucible", X, 22.0, -18.0, "big"], ["turn", "neck", X, -14.0, 10.0, "big"],
				["move", "rim", Vector3(0, 0.04, 0), Vector3(0, 0.16, 0), "pulse"], ["each", "lava", 0.0, Vector3(0.3, 0.9, 0.3), "pulse"],
				["lean", X, -8.0, 3.0, Vector3(0, 0, -1.2), "big"], ["hop", Vector3(0, 0.04, -0.04), Vector3(0, -0.05, 0.06), "big"],
				["fx", 0.3, "shock", {"from": "Leg05", "size": 1.0}], ["fx", 0.3, "shock", {"from": "Leg19", "size": 1.0}],
				["fx", 0.54, "shock", {"from": "Leg05", "size": 0.8}],
				["fx", 0.3, "erupt", {"from": "Crater01", "size": 1.0}], ["fx", 0.32, "dust", {"amount": 70}]],
			## Its crucible shaken white-hot, steam hissing off it.
			"Melt": [["grow", "pot", 0.0, 0.35, "pulse"], ["turn", "crucible", Z, -12.0, 12.0, "shake"], ["turn", "head", X, 0.0, 8.0, "hold"],
				["fx", 0.2, "glow", {"from": "Crucible03", "color": "#ffd890", "size": 0.45, "seconds": 0.4}],
				["fx", 0.28, "puff", {"from": "Crucible03", "color": "#e8e0d8", "amount": 10, "size": 0.8, "rise": 1.0}],
				["fx", 0.3, "sparks", {"from": "Crucible03", "color": "#ffb050", "amount": 12, "speed": 2.0}]],
			## Draws its head into its shell and hunkers: the lava crusts over, the rim rocks bristle.
			"Slag Armour": [["turn", "neck", X, 0.0, 10.0, "hold"], ["move", "neck", Vector3.ZERO, Vector3(0, -0.05, -0.3), "hold"],
				["each", "flames", 0.0, Vector3(0, -0.5, 0), "hold"], ["each", "vein", 0.0, 0.4, "hold"],
				["move", "rim", Vector3.ZERO, Vector3(0, 0.08, 0), "hold"], ["move", "shell", Vector3.ZERO, Vector3(0, -0.06, 0), "hold"],
				["fx", 0.25, "puff", {"from": "Crater01", "color": "#2a2422", "amount": 12, "size": 1.2, "rise": 1.2}],
				["fx", 0.3, "shards", {"from": "Crater01", "color": "#3a2420", "amount": 10, "speed": 2.0}],
				["fx", 0.3, "glow", {"from": "centre", "color": "#ff7a2a", "size": 1.0}]],
			## Stokes itself: drawing a breath that swells its shell, the veins blazing, the crater spitting.
			"Stoke": [["move", "rim", Vector3.ZERO, Vector3(0, 0.08, 0), "twice"], ["each", "lava", 0.0, Vector3(0.2, 0.6, 0.2), "twice"],
				["each", "vein", 0.0, 0.4, "twice"], ["grow", "shell", 0.0, Vector3(0.03, 0.04, 0.03), "twice"],
				["fx", 0.3, "jet", {"from": "Crater01", "color": "#ff8a30", "amount": 30, "speed": 3.0}],
				["fx", 0.55, "jet", {"from": "Crater01", "color": "#ff8a30", "amount": 30, "speed": 3.0}],
				["fx", 0.3, "flash_light", {"from": "Crater01", "color": "#ffb050", "energy": 3.0}]],
		},
		"heavy": {
			## Trample held: reared higher still, the crater boiling and smoking as it strains, and down.
			"Trample": {"at": "Crater01",
				"pose": [["lean", X, 0.0, -4.0, Vector3(0, 0, -1.2), "h"], ["move", "rim", Vector3.ZERO, Vector3(0, 0.1, 0), "h"], ["tremble", "shell", 0.012, "h"]],
				"charge": [["charge_dust", {"seconds": 0.45}], ["glow", {"from": "Crater01", "color": "#ff7a2a", "size": 0.9, "seconds": 0.5}],
					["jet", {"from": "Crater01", "color": "#ff8a30", "amount": 22, "speed": 2.6}],
					["puff", {"from": "Crater01", "color": "#2a2422", "amount": 16, "size": 1.4, "rise": 1.5}],
					["spiral", {"from": "Crater01", "color": "#ffb050", "amount": 26}]],
				"impact": [["shock", {"ahead": 1.5, "size": 1.8}], ["shards", {"from": "Leg05", "color": "#3a2420", "amount": 14, "speed": 5.0}],
					["shards", {"from": "Leg19", "color": "#3a2420", "amount": 14, "speed": 5.0}],
					["flash_light", {"from": "Crater01", "color": "#ff7a2a", "energy": 6.0}]]},
		},
	},
	## A knight of the forge with a pillar of fire for a head: it shoulders its hammer and sets it
	## down again, shifts its stance, tempers the hammer's face in its own flame; its blows fall like
	## a smith's, overhead and with everything behind them.
	"THE_ANVIL_KNIGHT": {
		"mouth": "Head01",
		"groups": {"hammer": {"parts": ["ArmL", "ArmR", "Hammer"], "at": "Hammer01"}, "flames": {"parts": ["Head02-05"]}, "crown": {"parts": ["Crown"], "at": "Crown01"},
			## The hammer alone, about the grip between its gauntlets.
			"haft": {"parts": ["Hammer"], "at": Vector3(0, 1.78, 0.68)},
			"arm_r": {"parts": ["ArmR"], "at": "ArmR01"}, "arm_l": {"parts": ["ArmL"], "at": "ArmL01"},
			"eyes": {"parts": ["Eye"], "at": Vector3(0, 3.1, 0)},
			## Its head: the pillar of fire, the eyes in it and the crown over it.
			"helm": {"parts": ["Head", "Eye", "Crown"], "at": Vector3(0, 2.86, 0)},
			"spikes": {"parts": ["Crystal"]},
			"leg_r": {"parts": ["Leg01-08"], "at": "Leg01"}, "leg_l": {"parts": ["Leg09-16"], "at": "Leg09"},
			## Everything above its hips, to bend into a blow.
			"torso": {"parts": ["Head", "Eye", "Crown", "ArmL", "ArmR", "Hammer", "Cylinder", "Core", "Box", "Flicker", "Rock", "Slab", "Crystal", "Cone"],
				"at": Vector3(0, 1.65, 0)}},
		"idle_gestures": [["sway", "crown", Y, 14.0, 0.45, 0.0], ["look", "eyes", 22.0, 6.0, 3.0, 0.9], ["breathe", "flames", Vector3(0.1, 0.22, 0.1), 1.1, 0.0]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Swings the hammer up and over onto its right shoulder, rests it there, and sets it down.
			"shoulder": {"length": 5.0, "hold": 2.6, "weight": 2.5, "do": [["call", "_knight_shoulder"], ["turn", "helm", Z, 0.0, -5.0, "f"],
				["lean", Z, 0.0, 1.5, Vector3.ZERO, "f"],
				["fx", 1.6, "sparks", {"from": "Hammer04", "color": "#ffb050", "amount": 8, "speed": 1.5}]]},
			## Shifts its weight from one leg to the other, the free leg easing out, hips swaying.
			"shift": {"length": 3.6, "weight": 2.0, "do": [["turn", "leg_l", Z, 0.0, 5.0, KNIGHT_SHIFT], ["turn", "leg_r", Z, -5.0, 0.0, KNIGHT_SHIFT],
				["turn", "torso", Z, 1.5, -1.5, KNIGHT_SHIFT], ["lean", Z, -2.0, 2.0, Vector3.ZERO, KNIGHT_SHIFT]]},
			## Holds the hammer up and bends its fire over the face till it glows, then lets it steam.
			"temper": {"length": 3.8, "hold": 1.6, "weight": 1.5, "do": [["each", "flames", 0.0, Vector3(0.2, 0.5, 0.2), "f"], ["turn", "flames", X, 0.0, 24.0, "f"],
				["turn", "hammer", X, 0.0, -75.0, "f"],
				["fx", 1.1, "glow", {"from": "Hammer04", "color": "#ff8a30", "size": 0.5, "seconds": 1.0}],
				["fx", 1.5, "sparks", {"from": "Hammer04", "color": "#ffb050", "amount": 10, "speed": 1.2}],
				["fx", 2.1, "sparks", {"from": "Hammer05", "color": "#ffb050", "amount": 10, "speed": 1.2}],
				["fx", 2.2, "puff", {"from": "Hammer02", "color": "#e8e0d8", "amount": 12, "size": 1.0, "rise": 1.6}]]},
			## Its broken crown turns a full circle over its fire as the flames flare.
			"crown": {"length": 2.4, "hold": 0.8, "weight": 1.0, "do": [["whirl", "crown", Y, 1.0, "f"], ["move", "crown", Vector3.ZERO, Vector3(0, 0.12, 0), "f"],
				["each", "flames", 0.0, Vector3(0.2, 0.6, 0.2), "f"],
				["fx", 0.9, "sparks", {"from": "Head01", "color": "#ffb050", "amount": 12, "speed": 2.0}]]},
			## Its fire turns to look about the room.
			"look": {"length": 4.0, "hold": 2.2, "weight": 1.5, "do": [["gaze", "helm", 34.0, 8.0, "f", 3]]},
			## Regrips: lifts the hammer a hand's breadth and thumps it down again.
			"grip": {"length": 1.6, "hold": 0.2, "weight": 1.0, "do": [["move", "hammer", Vector3(0, -0.03, 0), Vector3(0, 0.16, 0), KNIGHT_GRIP],
				["hop", Vector3(0, -0.03, 0), Vector3(0, 0.02, 0), KNIGHT_GRIP],
				["fx", 0.95, "shock", {"from": "Hammer02", "size": 0.45}],
				["fx", 0.95, "puff", {"from": "Hammer02", "color": "#5a4a40", "amount": 6, "size": 0.5, "rise": 0.3}]]},
		},
		"moves": {
			## Swings its hammer up over its head and brings it down in front, bending into the blow.
			"Hammer": [["turn", "hammer", X, -150.0, -6.0, "big"], ["turn", "torso", X, -5.0, 7.0, "big"], ["hop", Vector3(0, 0.04, -0.04), Vector3(0, -0.05, 0.06), "big"],
				["fx", 0.3, "shock", {"from": "Hammer02", "size": 1.0}],
				["fx", 0.3, "sparks", {"from": "Hammer02", "color": "#ffb050", "amount": 40, "speed": 5.0}]],
			## Reared back, the hammer high over its head and its fire roaring up, and down with everything.
			"Smite": [["each", "flames", Vector3(0.15, 0.45, 0.15), Vector3(0.1, 0.25, 0.1), "big"], ["turn", "hammer", X, -170.0, -6.0, "big"],
				["turn", "torso", X, -9.0, 10.0, "big"], ["hop", Vector3(0, 0.06, -0.06), Vector3(0, -0.07, 0.1), "big"],
				["fx", 0.3, "shock", {"from": "Hammer02", "size": 1.3}], ["fx", 0.3, "flash_light", {"from": "Hammer02", "color": "#ffb050", "energy": 7.0}],
				["fx", 0.3, "sparks", {"from": "Hammer02", "color": "#ffb050", "amount": 50, "speed": 5.5}], ["fx", 0.32, "dust", {"amount": 70}]],
			## Leaps with the hammer high and comes down so hard the floor flies up in shards.
			"Shatter": [["turn", "hammer", X, -175.0, -4.0, "big"], ["turn", "torso", X, -7.0, 12.0, "big"],
				["turn", "leg_r", X, -10.0, 0.0, "big"], ["turn", "leg_l", X, 6.0, 0.0, "big"],
				["hop", Vector3(0, 0.45, -0.08), Vector3(0, -0.06, 0.14), "big"],
				["fx", 0.3, "shock", {"from": "Hammer02", "size": 1.4}],
				["fx", 0.3, "shards", {"from": "Hammer02", "color": "#e8f0ff", "amount": 18, "speed": 5.5}],
				["fx", 0.3, "shards", {"from": "Hammer02", "color": "#3a2a24", "amount": 12, "speed": 4.0}],
				["fx", 0.3, "flash_light", {"from": "Hammer02", "color": "#e8f0ff", "energy": 6.0}]],
			## Its pillar of fire leans back and roars out at the party.
			"Forge-fire": [["each", "flames", Vector3(0.2, 0.4, 0.2), Vector3(0.4, 1.2, 0.4), "breath"], ["turn", "flames", X, -12.0, 30.0, "breath"],
				["turn", "helm", X, -6.0, 10.0, "breath"],
				["fx", 0.26, "breath", {"from": "Head01", "kind": "fire", "seconds": 0.55, "size": 1.0}],
				["fx", 0.3, "sparks", {"from": "Head01", "color": "#ffb050", "amount": 16, "speed": 3.0}]],
			## Holds the hammer up as its fire gutters with a hiss of steam, then flares back hotter.
			"Quench": [["each", "flames", Vector3(-0.3, -0.5, -0.3), Vector3(0.35, 1.0, 0.35), QUENCH], ["turn", "hammer", X, 0.0, -65.0, "hold"],
				["fx", 0.2, "puff", {"from": "Hammer02", "color": "#e8e0d8", "amount": 18, "size": 1.3, "rise": 1.4}],
				["fx", 0.22, "puff", {"from": "Head01", "color": "#e8e0d8", "amount": 14, "size": 1.0, "rise": 1.6}],
				["fx", 0.45, "sparks", {"from": "Head01", "color": "#ffb050", "amount": 20, "speed": 3.0}]],
			## Raises the hammer straight up over its fire, which roars up it till the face glows.
			"Temper": [["each", "flames", 0.0, Vector3(0.3, 0.9, 0.3), "hold"], ["turn", "hammer", X, 0.0, -160.0, "hold"],
				["fx", 0.25, "glow", {"from": "Hammer02", "color": "#ffb050", "size": 0.6}],
				["fx", 0.3, "sparks", {"from": "Hammer02", "color": "#ffc070", "amount": 24, "speed": 2.5}],
				["fx", 0.3, "flash_light", {"from": "Hammer02", "color": "#ffb050", "energy": 4.0}]],
			## Braces: lifts its hammer and drives it head-down into the floor before it, legs set
			## wide behind it, its spikes bristling, the crown spinning, its fire banked low.
			"Bulwark": [["each", "spikes", 0.0, 0.5, "hold"], ["each", "flames", 0.0, Vector3(-0.2, -0.35, -0.2), "hold"],
				["move", "hammer", Vector3(0, -0.04, 0), Vector3(0, 0.32, 0), KNIGHT_PLANT], ["whirl", "crown", Y, 1.0, "hold"],
				["turn", "leg_l", Z, 0.0, 4.0, "hold"], ["turn", "leg_r", Z, 0.0, -4.0, "hold"], ["hop", Vector3(0, -0.03, 0), Vector3(0, 0.03, 0), KNIGHT_PLANT],
				["fx", 0.3, "shock", {"from": "Hammer02", "size": 0.8}],
				["fx", 0.3, "sparks", {"from": "Hammer02", "color": "#ffb050", "amount": 18, "speed": 2.5}]],
		},
		"heavy": {
			## Smite held: arched further back, the crown lifting off its fire, the hammer's head
			## catching fire overhead, embers drawn into it; and down.
			"Smite": {"at": "Hammer02",
				"pose": [["lean", X, 0.0, -3.0, Vector3.ZERO, "h"], ["move", "crown", Vector3.ZERO, Vector3(0, 0.14, 0), "h"]],
				"charge": [["charge_dust", {"seconds": 0.45}], ["charge_glow", {"from": "Hammer02", "seconds": 0.55}],
					["flames", {"from": "Hammer02", "size": 0.6, "seconds": 0.5}], ["spiral", {"from": "Hammer02", "color": "#ffb050", "amount": 28}],
					["flash_light", {"from": "Head01", "color": "#ff8a30", "energy": 3.5}]],
				"impact": [["shock", {"from": "Hammer02", "size": 1.9}], ["flames", {"from": "Hammer02", "size": 1.1, "seconds": 0.7}],
					["sparks", {"from": "Hammer02", "color": "#ffc070", "amount": 50, "speed": 6.0}],
					["shards", {"from": "Hammer02", "color": "#3a2a24", "amount": 14, "speed": 5.0}]]},
			## Shatter held: hanging at the top of its leap, the hammer white-hot and crackling.
			"Shatter": {"at": "Hammer02",
				"pose": [["hop", Vector3.ZERO, Vector3(0, 0.12, 0), "h"], ["lean", X, 0.0, -3.0, Vector3.ZERO, "h"]],
				"charge": [["puff", {"from": "feet", "color": "#5a4a40", "amount": 10, "size": 1.0, "rise": 0.4}],
					["charge_glow", {"from": "Hammer02", "seconds": 0.55}], ["sparks", {"from": "Hammer02", "color": "#e8f0ff", "amount": 20, "speed": 2.0}],
					["spiral", {"from": "Hammer02", "color": "#e8f0ff", "amount": 26}], ["flash_light", {"from": "Hammer02", "color": "#e8f0ff", "energy": 3.0}]],
				"impact": [["shock", {"from": "Hammer02", "size": 2.0}], ["shards", {"from": "Hammer02", "color": "#e8f0ff", "amount": 22, "speed": 6.5}],
					["ring", {"color": "#ffb050", "radius": 3.2}]]},
		},
	},
	## The Kiln Dragon: it settles and spreads its wings, lashes its tail, draws its neck back in a
	## coil, snorts smoke from its nostrils; fire only when it breathes it.
	"THE_KILN_WYRM": {
		"mouth": "Mouth01",
		"hidden": ["Breath"],
		"ambient": [{"kind": "smoke", "at": "Head03", "color": "#3a3230", "size": 1.0}],
		"groups": {"neck": {"parts": ["Neck", "Head", "Jaw", "Mouth", "Breath", "Throat"], "at": "Neck01"},
			"head": {"parts": ["Head", "Jaw", "Mouth", "Breath", "Throat04"], "at": "Head01"}, "jaw": {"parts": ["Jaw"], "at": "Jaw01"},
			"breath": {"parts": ["Breath"]}, "throat": {"parts": ["Throat"]},
			"wing_l": {"parts": ["WingL"], "at": "WingL01"}, "wing_r": {"parts": ["WingR"], "at": "WingR01"}, "tail": {"parts": ["Tail"], "at": "Tail01"},
			"leg_rf": {"parts": ["Leg01-07"], "at": "Leg01"}, "leg_lf": {"parts": ["Leg15-21"], "at": "Leg15"},
			## Its neck stone by stone, each turning where it meets the one below, the head on the last.
			"neck_c": {"chain": [["Neck01"], ["Neck02", "Throat01", "Crystal01"], ["Neck03", "Neck06", "Throat02"], ["Neck04", "Throat03"], ["Neck05"]],
				"riders": ["Head", "Jaw", "Mouth", "Breath", "Throat04"],
				"joints": [Vector3(0, 1.9, 0.88), Vector3(0, 2.18, 1.1), Vector3(0, 2.52, 1.24), Vector3(0, 2.85, 1.32), Vector3(0, 3.08, 1.4)]},
			"belly": {"parts": ["Core"]}, "tail_tip": {"parts": ["Tail16"]}},
		"idle_gestures": [["look", "head", 12.0, 5.0, 3.6, 1.2], ["curl", "neck_c", X, 4.0, 0.42, 0.0, "even"], ["sway", "tail", Y, 6.0, 0.6, 0.0]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Lifts its wings and settles them again with a couple of shuffles, shedding ash.
			"settle": {"length": 2.0, "hold": 0.4, "weight": 2.0, "do": [["turn", "wing_l", Z, 0.0, 32.0, "settle"], ["turn", "wing_r", Z, 0.0, -32.0, "settle"],
				["hop", Vector3.ZERO, Vector3(0, 0.05, 0), "settle"],
				["fx", 0.75, "puff", {"from": "WingL04", "color": "#3a3230", "amount": 6, "size": 0.7, "rise": 0.3}],
				["fx", 0.75, "puff", {"from": "WingR04", "color": "#3a3230", "amount": 6, "size": 0.7, "rise": 0.3}]]},
			## Lashes its tail one way and the other, the blade's flame flaring, and glances back at it.
			"lash": {"length": 2.0, "weight": 1.5, "idle": 0.0, "do": [["each", "tail_tip", 0.0, 0.6, "f"], ["turn", "tail", Y, -28.0, 34.0, KILN_LASH],
				["turn", "head", Y, 0.0, 22.0, "f"], ["lean", Y, 3.0, -3.0, Vector3.ZERO, KILN_LASH],
				["fx", 0.4, "puff", {"from": "Tail13", "color": "#5a4a40", "amount": 8, "size": 0.7, "rise": 0.3}],
				["fx", 0.95, "puff", {"from": "Tail13", "color": "#5a4a40", "amount": 8, "size": 0.7, "rise": 0.3}]]},
			## Draws its neck back into a coil, looking down its nose, throat gems glowing, and uncoils.
			"coil": {"length": 3.6, "hold": 1.4, "weight": 2.0, "idle": 0.0, "do": [["each", "throat", 0.0, 0.3, "f"], ["turn", "head", X, 0.0, 30.0, "f"],
				["curl", "neck_c", X, 0.0, -42.0, "f", "root"],
				["fx", 1.4, "puff", {"from": "Head03", "color": "#3a3230", "amount": 10, "size": 0.8, "rise": 0.8}]]},
			## Snorts: a toss of the head and two plumes of smoke from its nostrils.
			"smoke": {"length": 2.0, "hold": 0.4, "weight": 1.5, "idle": 0.0, "do": [["turn", "jaw", X, 0.0, -10.0, "f"], ["turn", "head", X, 4.0, -10.0, "nod"],
				["fx", 0.3, "puff", {"from": "Head03", "color": "#2a2422", "amount": 12, "size": 0.9, "rise": 1.0}],
				["fx", 0.45, "puff", {"from": "Head03", "color": "#3a3230", "amount": 10, "size": 1.0, "rise": 1.2}],
				["fx", 0.35, "sparks", {"from": "Head03", "color": "#ff9a40", "amount": 6, "speed": 1.2}]]},
			## Spreads its wings wide and rears its head, jaws open, throat aglow: a roar with no fire.
			"spread": {"length": 3.2, "hold": 1.2, "weight": 1.2, "idle": 0.0, "do": [["each", "throat", 0.0, 0.35, "f"], ["turn", "jaw", X, 0.0, 16.0, "bare"],
				["turn", "head", X, 0.0, -14.0, "f"], ["turn", "neck", X, 0.0, -10.0, "f"],
				["turn", "wing_l", Z, 0.0, 42.0, "f"], ["turn", "wing_r", Z, 0.0, -42.0, "f"],
				["fx", 0.9, "flash_light", {"from": "Throat02", "color": "#ff8a30", "energy": 2.0}],
				["fx", 1.2, "puff", {"from": "Head03", "color": "#2a2422", "amount": 10, "size": 0.9, "rise": 1.0}]]},
			## Turns its long neck to look about the room.
			"look": {"length": 4.0, "hold": 2.2, "weight": 1.5, "do": [["gaze", "neck", 26.0, 8.0, "f", 3]]},
		},
		"moves": {
			"Firebreath": [["show", "breath", 0.24, 0.92], ["each", "breath", 0.0, Vector3(0.3, 0.3, 1.2), "breath"], ["each", "throat", 0.5, 0.3, "breath"],
				["turn", "jaw", X, 0.0, 22.0, "breath"], ["turn", "head", X, -15.0, 8.0, "breath"], ["turn", "neck", X, -22.0, 14.0, "breath"],
				["turn", "wing_l", Z, 0.0, 14.0, "breath"], ["turn", "wing_r", Z, 0.0, -14.0, "breath"],
				["fx", 0.26, "breath", {"kind": "fire", "seconds": 0.6, "size": 1.0}],
				["fx", 0.95, "puff", {"from": "Head03", "color": "#2a2422", "amount": 8, "size": 0.8, "rise": 0.8}]],
			## Lavafall: rears its neck high, wings spread, and pours fire and molten rock down on the party.
			"Lavafall": [["show", "breath", 0.24, 1.0], ["each", "breath", 0.0, Vector3(0.5, 0.5, 1.5), "breath"], ["each", "throat", 0.6, 0.4, "breath"],
				["turn", "jaw", X, 0.0, 26.0, "breath"], ["turn", "head", X, -18.0, 10.0, "breath"], ["turn", "neck", X, -28.0, 18.0, "breath"],
				["turn", "wing_l", Z, 0.0, 25.0, "breath"], ["turn", "wing_r", Z, 0.0, -25.0, "breath"],
				["fx", 0.26, "breath", {"kind": "fire", "seconds": 0.75, "size": 1.3}],
				["fx", 0.3, "spit", {"color": "#ff6a20", "kind": "molten", "flight": 0.18, "size": 2.0, "arc": 1.2}]],
			"Cinder": [["show", "breath", 0.24, 0.7], ["each", "breath", 0.0, Vector3(0.2, 0.2, 0.7), "pulse"], ["turn", "jaw", X, 0.0, 15.0, "attack"],
				["turn", "head", X, -10.0, 6.0, "attack"], ["fx", 0.26, "breath", {"kind": "fire", "seconds": 0.35, "size": 0.8}],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ff9a40", "amount": 40, "speed": 5.0}]],
			"Claw": [["turn", "leg_rf", X, -60.0, 25.0, "attack"], ["turn", "neck", X, -6.0, 8.0, "attack"], ["turn", "wing_r", Z, 0.0, -12.0, "attack"],
				["lean", X, -4.0, 2.0, Vector3(0, 0, -1.4), "attack"], ["rear", 0.3, "attack"],
				["fx", 0.29, "swipe", {"about": "leg_rf", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 1.2, "sweep": 120.0}]],
			## Rears up and rends with one foreclaw and then the other.
			"Rend": [["turn", "leg_rf", X, -60.0, 25.0, "attack"], ["turn", "leg_lf", X, -60.0, 25.0, "second"], ["turn", "neck", X, -8.0, 8.0, "attack"],
				["turn", "wing_l", Z, 0.0, 14.0, "second"], ["turn", "wing_r", Z, 0.0, -14.0, "attack"],
				["lean", X, -6.0, 3.0, Vector3(0, 0, -1.4), "second"], ["rear", 0.35, "second"],
				["fx", 0.29, "swipe", {"about": "leg_rf", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 1.2, "sweep": 120.0}],
				["fx", 0.41, "swipe", {"about": "leg_lf", "axis": X, "start": Vector3(0, 1, 0.3), "radius": 1.2, "sweep": 120.0}]],
			## Slams a claw down on what it wants and drags it back, head low to watch it.
			"Pin": [["turn", "leg_rf", X, -55.0, 18.0, KILN_PIN], ["turn", "head", X, 0.0, 10.0, "hold"], ["turn", "neck", X, -6.0, 10.0, KILN_PIN],
				["fx", 0.3, "shock", {"from": "Leg05", "size": 0.8}],
				["fx", 0.31, "puff", {"from": "Leg05", "color": "#5a4a40", "amount": 8, "size": 0.7, "rise": 0.3}]],
			## A thin white-hot jet of breath, its throat gem lit.
			"Melt": [["show", "breath", 0.22, 0.55], ["each", "breath", 0.0, Vector3(0.1, 0.1, 0.6), "pulse"], ["turn", "jaw", X, 0.0, 15.0, "attack"],
				["turn", "head", X, -10.0, 6.0, "attack"],
				["fx", 0.08, "glow", {"from": "Throat04", "color": "#fff0c0", "size": 0.4, "seconds": 0.3}],
				["fx", 0.26, "breath", {"kind": "fire", "seconds": 0.22, "size": 0.45}]],
			## Sweeps its tail across the party and back again: two hits.
			"Sweep": [["turn", "tail", Y, -45.0, 70.0, KILN_SWEEP], ["lean", Y, 10.0, -16.0, Vector3.ZERO, KILN_SWEEP],
				["fx", 0.29, "swipe", {"about": "tail", "axis": Y, "start": Vector3(-1, 0, -0.3), "radius": 2.2, "sweep": 130.0}],
				["fx", 0.47, "swipe", {"about": "tail", "axis": -Y, "start": Vector3(1, 0, -0.3), "radius": 2.2, "sweep": 130.0}],
				["fx", 0.32, "dust", {"amount": 40}]],
			## Fans the fire in its belly with its wings, gems blazing, smoke at its nostrils.
			"Stir": [["each", "belly", 0.0, 0.3, "hold"], ["each", "throat", 0.0, 0.3, "hold"], ["turn", "wing_l", Z, 0.0, 35.0, "flutter"], ["turn", "wing_r", Z, 0.0, -35.0, "flutter"],
				["turn", "jaw", X, 0.0, 20.0, "hold"], ["turn", "head", X, 0.0, -20.0, "hold"], ["fx", 0.3, "ring", {"color": "#ff7a2a", "radius": 3.0}],
				["fx", 0.2, "puff", {"from": "Head03", "color": "#2a2422", "amount": 10, "size": 0.9, "rise": 1.0}],
				["fx", 0.3, "rise", {"from": "centre", "color": "#ffb050", "amount": 18, "size": 2.0}]],
			## Rears up and stamps both forefeet down, twice: the floor shakes.
			"Quake": [["turn", "leg_rf", X, -40.0, 8.0, "twice"], ["turn", "leg_lf", X, -40.0, 8.0, "twice"], ["lean", X, -5.0, 2.0, Vector3(0, 0, -1.4), "twice"],
				["hop", Vector3(0, 0.3, 0), Vector3(0, -0.05, 0), "twice"],
				["fx", 0.3, "shock", {"size": 1.4}], ["fx", 0.56, "shock", {"size": 1.6}], ["fx", 0.3, "dust", {"amount": 90}]],
		},
		"heavy": {
			## Lavafall held: the neck reared higher, wings spread, throat blazing, smoke pouring from
			## its nostrils and embers drawn into its jaws.
			"Lavafall": {"at": "Mouth01",
				"pose": [["turn", "neck", X, 0.0, -10.0, "h"], ["turn", "wing_l", Z, 0.0, 20.0, "h"], ["turn", "wing_r", Z, 0.0, -20.0, "h"],
					["lean", X, 0.0, -4.0, Vector3(0, 0, -1.4), "h"]],
				"charge": [["charge_dust", {"seconds": 0.45}], ["glow", {"from": "Mouth01", "color": "#ff8a30", "size": 0.5, "seconds": 0.5}],
					["spiral", {"from": "Mouth01", "color": "#ffb050", "amount": 30}],
					["puff", {"from": "Head03", "color": "#2a2422", "amount": 16, "size": 1.0, "rise": 1.0}],
					["flash_light", {"from": "Throat02", "color": "#ff8a30", "energy": 3.0}]],
				"impact": [["shock", {"ahead": 2.2, "size": 1.5}], ["sparks", {"from": "Mouth01", "color": "#ffb050", "amount": 40, "speed": 5.0}],
					["flash_light", {"from": "Mouth01", "color": "#ffb050", "energy": 6.0}]]},
		},
	},
}

# --- the moves and idles no table says ---------------------------------------------------------

static func _idle_smelter(m: Node3D, clock: float, weight: float) -> void:
	## Its volcano bubbling: the lava pool heaving, and every few seconds a blorp that jolts the
	## rim rocks.
	var lava: Array = m._select(["Lava01"])
	var p: float = fmod(clock, 3.4)
	var blorp: float = sin(clampf(p / 0.45, 0.0, 1.0) * PI)
	for part in lava:
		m.swell([part], m.centre_of(part), Vector3(1.0 + 0.12 * blorp, 1.0 + 0.5 * blorp, 1.0 + 0.12 * blorp) * 1.0)
	var rim: Array = m._select(["Crater02-07"])
	m.shift(rim, Vector3(0, 0.035 * blorp * weight, 0))
	m.swell_each(m._select(["Lava02-05"]), Vector3(1.0, 1.0 + 0.6 * blorp * weight, 1.0))

static func _smelter_swirl(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The crucible swung round in a circle under the beak, widest in the middle of it.
	var t: float = float(clip.get("keyed", clip.t))
	var k: float = m._v(clip, "f", t)
	if absf(k) < 0.0001:
		return
	var gr: Dictionary = m.group("crucible")
	var a: float = t * 5.0
	m.turn(gr.parts, gr.joint, X, deg_to_rad(11.0) * sin(a) * k)
	m.turn(gr.parts, gr.joint, Z, deg_to_rad(11.0) * cos(a) * k)

static func _idle_imp(m: Node3D, clock: float, weight: float) -> void:
	## A jig from foot to foot: each foot lifted in turn as the imp rocks onto the other, bobbing up
	## on every step. The rock is the whole body's, about the foot it stands on.
	var step: float = sin(clock * 3.6)
	var up_l: float = maxf(0.0, step)
	var up_r: float = maxf(0.0, -step)
	var leg_l: Dictionary = m.group("leg_l")
	var leg_r: Dictionary = m.group("leg_r")
	m.turn(leg_l.parts, leg_l.joint, X, deg_to_rad(-16.0) * up_l * up_l * weight)
	m.turn(leg_r.parts, leg_r.joint, X, deg_to_rad(-16.0) * up_r * up_r * weight)
	var foot := Vector3(-0.17 if step > 0.0 else 0.17, 0.0, 0.0)
	var rock := Transform3D(Basis.IDENTITY, foot + Vector3(0, 0.025 * step * step * weight, 0)) * Transform3D(Basis(Z, deg_to_rad(4.0) * step * weight), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -foot)
	m._lean = rock * m._lean
	m._leaning = true

static func _idle_crawler(m: Node3D, clock: float, weight: float) -> void:
	## Its legs paddling in a wave that runs down its length, plate by plate.
	var legs: Array = m._select(["Leg"])
	for index in range(legs.size()):
		var plate: float = floorf(float(index) * 0.5)
		var leg: Node3D = legs[index]
		m.turn([leg], (leg.get("_rest") as Transform3D).origin, Y, deg_to_rad(9.0) * sin(clock * 4.2 - plate * 0.8) * weight)

static func _crawler_glow(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The ember gems down its back flaring one after another, head to tail.
	var t: float = float(clip.get("keyed", clip.t))
	var k: float = m._v(clip, "f", t)
	if absf(k) < 0.0001:
		return
	var gems: Array = m._select(["Core"])
	for index in range(gems.size()):
		var x: float = fposmod(t * 1.4 - float(index) * 0.08, 1.0)
		var bump: float = exp(-pow((x - 0.5) / 0.1, 2.0))
		m.swell_each([gems[index]], Vector3.ONE * (1.0 + 0.45 * bump * k))

## The Anvil Knight's hammer on its shoulder: the grip between its gauntlets at rest, its
## shoulders, where its right arm reaches with the hammer shouldered and the point of the
## pauldron the haft lies over.
const KNIGHT_GRIP_AT := Vector3(0, 1.78, 0.68)
const KNIGHT_SHOULDER_R := Vector3(-0.64, 2.6, 0.0)
const KNIGHT_SHOULDER_L := Vector3(0.64, 2.6, 0.0)
const KNIGHT_ARM_DOWN := Vector3(0.3, -0.88, 0.36)
const KNIGHT_REST_ON := Vector3(-0.64, 2.86, -0.05)

static func _knight_shoulder(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Lifts the hammer in its right fist and swings it up and over onto its right shoulder (the
	## head going forward and over the top, not back through its legs), the left hand dropping
	## to its side; `f` carries it there and back.
	var k: float = m._v(clip, "f", float(clip.get("keyed", clip.t)))
	if k <= 0.0001:
		return
	var gauntlets: Array = m._select(["ArmR05"])
	var heads: Array = m._select(["Hammer02"])
	if gauntlets.is_empty() or heads.is_empty():
		return
	var fist: Vector3 = m.centre_of(gauntlets[0])
	var arm0: Vector3 = fist - KNIGHT_SHOULDER_R
	var arm1: Vector3 = KNIGHT_ARM_DOWN.normalized() * arm0.length()
	var lift := Quaternion(arm0.normalized(), arm1.normalized())
	var hand: Vector3 = KNIGHT_SHOULDER_R + arm1
	var want: Vector3 = lift.inverse() * (KNIGHT_REST_ON - hand).normalized()
	var down: Vector3 = (m.centre_of(heads[0]) - KNIGHT_GRIP_AT).normalized()
	## Up and over about its own left-right axis (forward first), then leaned out to the shoulder.
	var over: Vector3 = Vector3(0, want.y, want.z).normalized()
	var swing: float = atan2(over.z, over.y) - atan2(down.z, down.y)
	if swing > 0.0:
		swing -= TAU
	var lean_axis: Vector3 = over.cross(want)
	var lean: float = over.angle_to(want)
	var haft: Array = m.group("haft").parts
	var arm_r: Array = m.group("arm_r").parts
	var arm_l: Array = m.group("arm_l").parts
	m.turn(haft, KNIGHT_GRIP_AT, X, swing * k)
	if lean_axis.length() > 0.0001:
		m.turn(haft, KNIGHT_GRIP_AT, lean_axis.normalized(), lean * k)
	m.shift(haft, (fist - KNIGHT_GRIP_AT) * k)
	if lift.get_angle() > 0.0001:
		m.turn(arm_r + haft, KNIGHT_SHOULDER_R, lift.get_axis(), lift.get_angle() * k)
	m.turn(arm_l, KNIGHT_SHOULDER_L, X, deg_to_rad(28.0) * k)
	m.turn(arm_l, KNIGHT_SHOULDER_L, Z, deg_to_rad(14.0) * k)
