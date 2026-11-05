extends RefCounted
## The Glass Veins: the mine of glass and light.
## Each creature's rig as data (see the gesture language in creature_rigs.gd), keyed by its scene,
## and the moves and idles no table says, written out as functions of the Moves node
## (creature_moves.gd) passed in as `m`. creature_rigs.gd merges every mine's RIGS.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {}

## The Echo Sprite's dart: off to one side, a hover, across to the other, a hover, back.
const SPRITE_DART: Array = [[0.0, 0.0], [0.16, 1.0], [0.72, 1.0], [0.9, -1.0], [1.5, -1.0], [1.72, 0.0]]
## Its tail motes trailing a beat behind the dart.
const SPRITE_TRAIL: Array = [[0.0, 0.0], [0.24, 1.0], [0.8, 1.0], [1.0, -1.0], [1.58, -1.0], [1.85, 0.0]]

## The Refractor's four rays flaring one after another, one a hit of Split Light.
const RAY_1: Array = [[0.0, 0.0], [0.23, 0.0], [0.27, 1.0], [0.4, 0.0]]
const RAY_2: Array = [[0.0, 0.0], [0.28, 0.0], [0.32, 1.0], [0.45, 0.0]]
const RAY_3: Array = [[0.0, 0.0], [0.33, 0.0], [0.37, 1.0], [0.5, 0.0]]
const RAY_4: Array = [[0.0, 0.0], [0.38, 0.0], [0.42, 1.0], [0.55, 0.0]]
## The same as an idle flourish, slower: each ray flares in turn round the lens.
const FAN_1: Array = [[0.0, 0.0], [0.3, 0.0], [0.55, 1.0], [0.9, 0.0]]
const FAN_2: Array = [[0.0, 0.0], [0.6, 0.0], [0.85, 1.0], [1.2, 0.0]]
const FAN_3: Array = [[0.0, 0.0], [0.9, 0.0], [1.15, 1.0], [1.5, 0.0]]
const FAN_4: Array = [[0.0, 0.0], [1.2, 0.0], [1.45, 1.0], [1.8, 0.0]]

## The Prism running down like a top: a wobble dying away.
const PRISM_WOBBLE: Array = [[0.0, 0.0], [0.15, 1.0], [0.35, -0.8], [0.55, 0.6], [0.75, -0.4], [0.95, 0.2], [1.15, 0.0]]

## The Glazier's right pincer, a beat after the left (the second of Pincers' two hits).
const GLAZIER_SNAP_R: Array = [[0.0, 0.0], [0.35, -1.0], [0.41, 1.0], [0.48, 1.0], [0.72, 0.0]]
## Both pincers raised and clacked twice: -1 opened wide, +1 snapped shut.
const GLAZIER_CLACK: Array = [[0.0, 0.0], [0.6, -1.0], [0.85, -1.0], [0.91, 1.0], [1.05, 1.0], [1.25, -1.0], [1.35, -1.0], [1.41, 1.0], [1.56, 1.0], [2.1, 0.0]]
## A sidestep: off one way, a pause, across the other way, back.
const GLAZIER_STEP: Array = [[0.0, 0.0], [0.5, 1.0], [0.8, 1.0], [1.4, -0.7], [1.65, -0.7], [2.2, 0.0]]
## Eviscerate: reared back, the saw driven in, held there grinding, pulled out.
const GLAZIER_DRIVE: Array = [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.8, 1.0], [1.15, 0.0]]
const GLAZIER_GRIND: Array = [[0.0, 0.0], [0.29, 0.0], [0.32, 1.0], [0.78, 1.0], [0.86, 0.0]]
## Cut: the saw drawn slowly across, scoring a line like a glasscutter's wheel.
const GLAZIER_SCORE: Array = [[0.0, 0.0], [0.16, -1.0], [0.46, 1.0], [0.6, 1.0], [0.95, 0.0]]

## The Kaleidoscope's slow double blink.
const KALEIDO_BLINK: Array = [[0.0, 0.0], [0.3, 1.0], [0.5, 1.0], [0.75, 0.0], [0.95, 0.0], [1.1, 1.0], [1.25, 1.0], [1.55, 0.0]]
## Its tendrils curling up one after another, front first.
const KALEIDO_CURL_1: Array = [[0.0, 0.0], [0.6, 1.0], [1.5, 1.0], [2.2, 0.0]]
const KALEIDO_CURL_2: Array = [[0.0, 0.0], [0.3, 0.0], [0.9, 1.0], [1.7, 1.0], [2.4, 0.0]]
const KALEIDO_CURL_3: Array = [[0.0, 0.0], [0.5, 0.0], [1.1, 1.0], [1.9, 1.0], [2.6, 0.0]]
## Its tendrils flung back by its own glare and swinging still after (and the move long enough
## for its wheel to swing back to its own turning slowly).
const KALEIDO_RECOIL: Array = [[0.0, 0.0], [0.3, 0.0], [0.42, 1.0], [0.8, -0.6], [1.15, 0.3], [1.5, 0.0]]

## The Prismarch's arm raised (1) and held part-lowered at the blow, for Shardfall: the
## sceptre held high (started early: its lead 0.42), then brought down to point at the party.
const PRISMARCH_RAISE: Array = [[-0.12, 0.0], [0.2, 1.0], [0.3, 0.55], [0.62, 0.55], [1.15, 0.0]]
## The sceptre kept upright in its hand as the arm lifts, tipping forward at the blow.
const PRISMARCH_ROD: Array = [[-0.12, 0.0], [0.2, 1.0], [0.3, 0.85], [0.62, 0.85], [1.15, 0.0]]
## Two taps of the sceptre's foot on the floor.
const PRISMARCH_TAP: Array = [[0.0, 0.0], [0.4, 1.0], [0.5, 0.0], [0.62, 0.0], [0.95, 1.0], [1.05, 0.0], [1.6, 0.0]]

const RIGS: Dictionary = {
	## The Echo Sprite: a sprite of light, a little glass fairy. It hovers on a blur of wings,
	## bobbing and tilting, its heart twinkling and its tail of motes trailing; now and then it
	## darts aside and back, twirls, preens a wing, looks about with its antennae up. Twinkle is a
	## dart of light flicked off its wings; Mirror folds its wings before it into a looking glass.
	"ECHO_SPRITE": {
		"mouth": "Heart01",
		"groups": {
			"all": {"parts": ["Body", "Head", "Heart", "Crystal", "Wing", "Tail", "Orbit"], "at": Vector3(0, 0.9, 0)},
			"head": {"parts": ["Head"], "at": "Head01"},
			"antenna_l": {"parts": ["Head05"], "at": Vector3(0.05, 1.3, 0)},
			"antenna_r": {"parts": ["Head03"], "at": Vector3(-0.05, 1.3, 0)},
			"wings_l": {"parts": ["WingL"]},
			"wings_r": {"parts": ["WingR"]},
			"tail": {"parts": ["Tail"], "at": Vector3(0, 0.4, 0)},
			"heart": {"parts": ["Heart01"]},
		},
		"idle_gestures": [["blink", "heart", Vector3(1.8, 1.8, 1.8), 1.7, 0.0], ["sway_each", "tail", X, 10.0, 2.2, 0.8],
			["hover", "all", 0.05, 1.7, 5.0, 0.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Darts off to one side, hangs there humming, darts across to the other and back, its
			## tail of motes swinging behind and a glitter of light left where it was.
			"dart": {"length": 2.0, "hold": 0.6, "weight": 3.0, "do": [["turn_each", "wings_l", Z, 0.0, 14.0, "flutter"], ["turn_each", "wings_r", Z, 0.0, -14.0, "flutter"],
				["turn", "tail", Z, -34.0, 34.0, SPRITE_TRAIL], ["lean", Z, -14.0, 14.0, Vector3(0, 0.9, 0), SPRITE_DART],
				["hop", Vector3(0.34, 0.05, 0.0), Vector3(-0.38, 0.1, 0.05), SPRITE_DART],
				["fx", 0.05, "sparks", {"from": "Heart01", "color": "accent", "amount": 8, "speed": 0.9, "life": 0.7}],
				["fx", 0.8, "sparks", {"from": "Heart01", "color": "accent", "amount": 8, "speed": 0.9, "life": 0.7}]]},
			## A pirouette: it rises and twirls round once, wings raised, scattering glints.
			"twirl": {"length": 2.2, "hold": 0.5, "weight": 2.0, "do": [["turn_each", "wings_l", Z, 0.0, 22.0, "f"], ["turn_each", "wings_r", Z, 0.0, -22.0, "f"],
				["whirl", "all", Y, 1.0, "f"], ["move", "all", Vector3.ZERO, Vector3(0, 0.14, 0), "f"],
				["fx", 0.85, "sparks", {"from": "Heart01", "color": "accent", "amount": 14, "speed": 1.6, "life": 0.7}]]},
			## Preens: brings its left wing forward, looks round at it and shakes it out.
			"preen": {"length": 2.4, "hold": 1.0, "weight": 1.5, "do": [["turn_each", "wings_l", Z, 0.0, 12.0, "shake"], ["turn_each", "wings_l", Y, 0.0, -38.0, "f"],
				["turn", "antenna_l", X, 0.0, 16.0, "f"], ["turn", "antenna_r", X, 0.0, 16.0, "f"],
				["turn", "head", X, 0.0, 14.0, "f"], ["turn", "head", Y, 0.0, 34.0, "f"], ["lean", Z, 0.0, -6.0, Vector3(0, 0.9, 0), "f"]]},
			## Pricks up its antennae and looks about the room.
			"look": {"length": 3.4, "hold": 1.8, "weight": 1.5, "do": [["turn", "antenna_l", X, 0.0, 22.0, "f"], ["turn", "antenna_r", X, 0.0, 22.0, "f"],
				["gaze", "head", 38.0, 14.0, "f", 3]]},
		},
		"moves": {
			## Sweeps its wings back, darts in and flicks a dart of light off them at you.
			"Twinkle": [["turn_each", "wings_l", Y, 26.0, -30.0, "attack"], ["turn_each", "wings_r", Y, -26.0, 30.0, "attack"],
				["each", "heart", 0.0, 0.7, "pulse"], ["turn", "tail", X, 0.0, -28.0, "attack"],
				["lean", X, -8.0, 10.0, Vector3(0, 0.9, 0), "attack"], ["hop", Vector3(0, 0.08, -0.12), Vector3(0, -0.02, 0.18), "attack"],
				["fx", 0.24, "bolt", {"from": "Heart01", "color": "accent", "flight": 0.15, "size": 0.6}],
				["fx", 0.27, "sparks", {"from": "Heart01", "color": "accent", "amount": 16, "speed": 2.2, "life": 0.5}]],
			## Folds its wings forward before it into a looking glass, glinting, and holds them there.
			"Mirror": [["turn_each", "wings_l", Y, 0.0, -48.0, "hold"], ["turn_each", "wings_r", Y, 0.0, 48.0, "hold"], ["each", "heart", 0.0, 0.6, "hold"],
				["turn", "head", X, 0.0, -10.0, "hold"], ["lean", X, 0.0, -6.0, Vector3(0, 0.9, 0), "hold"],
				["fx", 0.28, "flash_light", {"from": "Heart01", "color": "#eef2ff", "energy": 3.0}],
				["fx", 0.3, "sparks", {"from": "Heart01", "color": "#eef2ff", "amount": 12, "speed": 1.4, "life": 0.6}]],
		},
	},
	## The Refractor: a lens-eye in a ring of glass that splits light. Its halo turns and wobbles
	## like a gyroscope, its rays flare and fade, the rim of its lens twists to focus; now and then
	## the halo spins up, tips on edge to show its gems, the rays fan one by one. Split Light fires
	## each ray in turn, each a colour of the spectrum; Sharpen whets its points; Refract spins the
	## halo up and stands it before it like a pane of glass.
	"REFRACTOR": {
		"mouth": "Mouth01",
		"groups": {
			"all": {"parts": ["Body", "Eye", "Ray", "Ring", "Mouth"], "at": Vector3(0, 0.95, 0)},
			"ring": {"parts": ["Ring"], "at": Vector3(0, 0.95, 0)},
			"rays": {"parts": ["Ray"], "at": Vector3(0, 1.0, 0.36)},
			"ray1": {"parts": ["Ray01"], "at": Vector3(0, 1.0, 0.36)},
			"ray2": {"parts": ["Ray02"], "at": Vector3(0, 1.0, 0.36)},
			"ray3": {"parts": ["Ray03"], "at": Vector3(0, 1.0, 0.36)},
			"ray4": {"parts": ["Ray04"], "at": Vector3(0, 1.0, 0.36)},
			"eye": {"parts": ["Eye", "Mouth"], "at": Vector3(0, 1.0, 0.31)},
			"lens": {"parts": ["Eye01"]},
			"rim": {"parts": ["Eye02-07"], "at": Vector3(0, 1.0, 0.31)},
			"spire": {"parts": ["Body01", "Body03"], "at": Vector3(0, 0.95, 0)},
			"collar": {"parts": ["Body04-09"], "at": Vector3(0, 0.95, 0)},
			"shards": {"parts": ["Orbit"], "at": Vector3(0, 0.95, 0)},
		},
		"idle_gestures": [["breathe", "rays", 0.14, 1.3, 0.0], ["sway", "rim", Z, 14.0, 0.5, 0.0], ["blink", "lens", Vector3(1.35, 1.35, 1.35), 3.0, 0.7],
			["sway", "ring", X, 7.0, 0.55, 0.0], ["sway", "ring", Z, 6.0, 0.4, 1.4]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## The halo spins up, tilted, the shards whirling round with it and the rays flaring.
			"spin_up": {"length": 2.6, "hold": 0.8, "weight": 2.0, "do": [["whirl", "ring", Y, 2.0, "f"], ["turn", "ring", X, 0.0, 16.0, "f"],
				["whirl", "shards", Y, 1.0, "f"], ["grow", "rays", 0.0, 0.3, "f"],
				["fx", 1.1, "sparks", {"from": "Ring08", "color": "accent", "amount": 12, "speed": 1.5, "life": 0.6}]]},
			## Focuses: the rim twists, the lens swells and the rays draw in, then a glint.
			"focus": {"length": 2.4, "hold": 0.8, "weight": 2.0, "do": [["turn", "rim", Z, 0.0, 45.0, "f"], ["each", "lens", 0.0, 0.3, "f"], ["grow", "rays", 0.0, -0.4, "f"],
				["fx", 1.1, "flash_light", {"from": "Mouth01", "color": "accent", "energy": 2.0}],
				["fx", 1.1, "sparks", {"from": "Mouth01", "color": "#ffffff", "amount": 8, "speed": 1.2, "life": 0.5}]]},
			## Tips its halo up on edge to show the gems at its corners, turning to look aside.
			"gyre": {"length": 3.0, "hold": 1.2, "weight": 1.5, "do": [["turn", "ring", X, 0.0, 62.0, "f"], ["turn", "all", Y, 0.0, 28.0, "f"]]},
			## Its rays flare one after another round the lens, a glint off each.
			"fan": {"length": 2.0, "hold": 0.6, "weight": 1.5, "do": [["grow", "ray1", 0.0, 0.5, FAN_1], ["grow", "ray2", 0.0, 0.5, FAN_2],
				["grow", "ray3", 0.0, 0.5, FAN_3], ["grow", "ray4", 0.0, 0.5, FAN_4],
				["fx", 0.55, "sparks", {"from": "Ray01", "color": "#ff8aa8", "amount": 6, "speed": 1.0, "life": 0.5}],
				["fx", 0.85, "sparks", {"from": "Ray02", "color": "#ffd27a", "amount": 6, "speed": 1.0, "life": 0.5}],
				["fx", 1.15, "sparks", {"from": "Ray03", "color": "#8affc0", "amount": 6, "speed": 1.0, "life": 0.5}],
				["fx", 1.45, "sparks", {"from": "Ray04", "color": "#8ab8ff", "amount": 6, "speed": 1.0, "life": 0.5}]]},
		},
		"moves": {
			## Draws the light into its lens as the halo whirls, and fires its four rays one by one,
			## each a colour of the split light.
			"Split Light": [["grow", "ray1", 0.0, 0.6, RAY_1], ["grow", "ray2", 0.0, 0.6, RAY_2], ["grow", "ray3", 0.0, 0.6, RAY_3], ["grow", "ray4", 0.0, 0.6, RAY_4],
				["each", "lens", -0.2, 0.45, "attack"], ["whirl", "ring", Y, 1.0, "attack"], ["lean", X, -5.0, 6.0, Vector3(0, 0.95, 0), "attack"],
				["fx", 0.22, "glow", {"from": "Mouth01", "color": "accent", "size": 0.5}],
				["fx", 0.27, "bolt", {"from": "Ray01", "color": "#ff7a9a", "flight": 0.14, "size": 0.7}],
				["fx", 0.32, "bolt", {"from": "Ray02", "color": "#ffd27a", "flight": 0.14, "size": 0.7}],
				["fx", 0.37, "bolt", {"from": "Ray03", "color": "#8affc0", "flight": 0.14, "size": 0.7}],
				["fx", 0.42, "bolt", {"from": "Ray04", "color": "#8ab8ff", "flight": 0.14, "size": 0.7}]],
			## Whets itself: its spire stretches to a finer point, its collar flares, its rays grow
			## long, and it shivers with a ring of sparks off its tip.
			"Sharpen": [["grow", "spire", 0.0, Vector3(-0.12, 0.22, -0.12), "pulse"], ["grow", "collar", 0.0, Vector3(0.25, 0.0, 0.25), "pulse"],
				["grow", "rays", 0.0, 0.5, "pulse"], ["whirl", "ring", Y, 1.0, "hold"], ["tremble", "all", 0.012, "hold"],
				["fx", 0.3, "sparks", {"from": "Body03", "color": "accent", "amount": 22, "speed": 2.4, "life": 0.6}],
				["fx", 0.32, "sparks", {"from": "Ray01", "color": "#ffffff", "amount": 8, "speed": 1.6, "life": 0.5}],
				["fx", 0.32, "sparks", {"from": "Ray03", "color": "#ffffff", "amount": 8, "speed": 1.6, "life": 0.5}]],
			## Spins its halo up and stands it on edge before it like a pane of glass, the shards
			## circling, its rays drawn in and its lens bright.
			"Refract": [["whirl", "ring", Y, 2.0, "hold"], ["turn", "ring", X, 0.0, 80.0, "hold"], ["whirl", "shards", Y, 1.0, "hold"],
				["grow", "rays", 0.0, -0.4, "hold"], ["each", "lens", 0.0, 0.3, "hold"],
				["fx", 0.3, "flash_light", {"from": "Mouth01", "color": "#eef2ff", "energy": 3.0}],
				["fx", 0.32, "sparks", {"from": "Ring08", "color": "#eef2ff", "amount": 14, "speed": 1.6, "life": 0.6}]],
		},
	},
	## A Prism: a summoned prism hung at the Prismarch's side. It floats, turning on its point,
	## and now and then tips to catch the light with a glint, or leans and circles like a top.
	## Glint tips its point at you and flashes a needle of light; Still, it runs down and wobbles.
	"PRISM": {
		"mouth": "Bob01",
		"groups": {
			"prism": {"parts": ["Spin01", "Spin02", "Bob01"], "at": Vector3(0, 0.45, 0)},
		},
		"idle_gestures": [["hover", "prism", 0.05, 1.1, 4.0, 0.0]],
		"fidget_every": [5.0, 10.0],
		"fidgets": {
			## Tips aside to catch the light: a glint runs up it.
			"glint": {"length": 2.2, "hold": 0.6, "weight": 2.0, "do": [["turn", "prism", Z, 0.0, 14.0, "f"], ["turn", "prism", X, 0.0, -8.0, "f"],
				["fx", 0.9, "flash_light", {"from": "Spin01", "off": Vector3(0, 0.5, 0), "color": "#f4eeff", "energy": 1.8}],
				["fx", 0.95, "sparks", {"from": "Spin01", "off": Vector3(0, 0.55, 0), "color": "#ffffff", "amount": 6, "speed": 0.8, "life": 0.5}]]},
			## Leans over and circles once like a spinning top, rising a little.
			"precess": {"length": 3.0, "hold": 1.2, "weight": 1.5, "do": [["turn", "prism", X, 0.0, 10.0, "f"], ["whirl", "prism", Y, 1.0, "f"],
				["move", "prism", Vector3.ZERO, Vector3(0, 0.08, 0), "f"]]},
		},
		"moves": {
			## Rocks back and tips its point at you, flashing a needle of light from it.
			"Glint": [["turn", "prism", X, -12.0, 28.0, "attack"], ["move", "prism", Vector3(0, 0.08, 0), Vector3(0, 0.04, 0.06), "attack"],
				["fx", 0.24, "flash_light", {"from": "Spin01", "off": Vector3(0, 0.5, 0.2), "color": "accent", "energy": 2.5}],
				["fx", 0.27, "beam", {"from": "Spin01", "off": Vector3(0, 0.52, 0.28), "color": "accent", "width": 0.06, "seconds": 0.25, "size": 0.5}],
				["fx", 0.3, "sparks", {"from": "Spin01", "off": Vector3(0, 0.52, 0.28), "color": "#ffffff", "amount": 10, "speed": 1.8, "life": 0.5}]],
			## Runs down like a top: sinks a little and wobbles till it steadies.
			"Still": [["turn", "prism", Z, 0.0, 9.0, PRISM_WOBBLE], ["turn", "prism", X, 0.0, 5.0, PRISM_WOBBLE],
				["move", "prism", Vector3.ZERO, Vector3(0, -0.08, 0), "hold"]],
		},
	},
	## The Glazier: a glass scorpion, a glasscutter. It scuttles on eight legs, clacks its pincers
	## and holds its tail arched over its back with the diamond saw whirring at the tip; now and
	## then it sidesteps, raises its pincers to clack them, revs its saw spitting sparks, swings
	## round to look aside. Its claws pinch, its saw swipes, scores and, on Eviscerate, rears back
	## shrieking and is driven down into you, grinding.
	"THE_GLAZIER": {
		"burrow": "fade",
		"mouth": "Saw04",
		"idle": "_idle_glazier",
		"groups": {
			"saw": {"parts": ["Saw"]},
			"tail": {"chain": [["Tail01"], ["Tail02"], ["Tail03"], ["Tail04"], ["Tail05"]], "riders": ["Saw"]},
			"tail_all": {"parts": ["Tail", "Saw"], "at": "Tail01"},
			"claw_l": {"parts": ["ClawL", "FingerL"], "at": "ClawL01"},
			"claw_r": {"parts": ["ClawR", "FingerR"], "at": "ClawR01"},
			"finger_l": {"parts": ["FingerL"], "at": Vector3(0.95, 0.76, 1.1)},
			"finger_r": {"parts": ["FingerR"], "at": Vector3(-0.95, 0.76, 1.1)},
			## Its legs in two sets of four that step together (front and third on one side, second
			## and back on the other), each leg about its own hip.
			"gait_a": {"parts": ["Leg09-10", "Leg13-14", "Leg03-04", "Leg07-08"]},
			"gait_b": {"parts": ["Leg01-02", "Leg05-06", "Leg11-12", "Leg15-16"]},
			"plates": {"parts": ["Body"]},
		},
		"idle_gestures": [["curl", "tail", X, 3.0, 0.9, 0.0, "tip"], ["sway", "tail_all", Y, 5.0, 0.6, 0.8]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Raises both pincers wide and clacks them twice at you, tail rearing.
			"clack": {"length": 2.6, "hold": 1.1, "weight": 3.0, "do": [["turn", "finger_l", Y, 40.0, -35.0, GLAZIER_CLACK], ["turn", "finger_r", Y, -40.0, 35.0, GLAZIER_CLACK],
				["turn", "claw_l", X, 0.0, -48.0, "f"], ["turn", "claw_l", Y, 0.0, 18.0, "f"], ["turn", "claw_r", X, 0.0, -48.0, "f"], ["turn", "claw_r", Y, 0.0, -18.0, "f"],
				["curl", "tail", X, 0.0, -8.0, "f", "tip"], ["lean", X, 0.0, -3.0, Vector3(0, 0, -0.6), "f"],
				["fx", 0.92, "sparks", {"from": "ClawL03", "color": "accent", "amount": 8, "speed": 1.6, "life": 0.4}],
				["fx", 0.92, "sparks", {"from": "ClawR03", "color": "accent", "amount": 8, "speed": 1.6, "life": 0.4}],
				["fx", 1.42, "sparks", {"from": "ClawL03", "color": "accent", "amount": 8, "speed": 1.6, "life": 0.4}],
				["fx", 1.42, "sparks", {"from": "ClawR03", "color": "accent", "amount": 8, "speed": 1.6, "life": 0.4}]]},
			## Rears its tail and revs the saw, sparks spitting off its teeth.
			"saw_rev": {"length": 2.2, "hold": 0.9, "weight": 2.0, "do": [["spin", "saw", 6.0, "f"], ["curl", "tail", X, 0.0, -14.0, "f", "tip"],
				["tremble", "tail_all", 0.012, "f"],
				["fx", 0.75, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 18, "speed": 2.6, "life": 0.5}],
				["fx", 1.2, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 18, "speed": 2.6, "life": 0.5}]]},
			## Scuttles a few steps sideways, then back across, legs paddling.
			"scuttle": {"length": 2.3, "hold": 0.6, "weight": 2.0, "do": [["turn_each", "gait_a", Y, -18.0, 18.0, "wag"], ["turn_each", "gait_b", Y, 18.0, -18.0, "wag"],
				["hop", Vector3(0.5, 0.0, 0.0), Vector3(-0.65, 0.0, 0.0), GLAZIER_STEP], ["turn", "tail_all", Z, 7.0, -7.0, GLAZIER_STEP],
				["fx", 0.3, "puff", {"from": "feet", "color": "#d8d0f0", "amount": 6, "size": 0.6, "rise": 0.2}],
				["fx", 1.2, "puff", {"from": "feet", "color": "#d8d0f0", "amount": 6, "size": 0.6, "rise": 0.2}]]},
			## Swings its whole body round to look aside, the tail swaying the other way.
			"turn": {"length": 3.2, "hold": 1.2, "weight": 1.5, "do": [["turn_each", "gait_a", Y, -10.0, 10.0, "wag"], ["turn_each", "gait_b", Y, 10.0, -10.0, "wag"],
				["lean", Y, 0.0, 26.0, Vector3(0, 0, -0.2), "f"], ["turn", "tail_all", Y, 0.0, -10.0, "f"]]},
		},
		"moves": {
			## Lunges and pinches, left pincer then right, each snapping shut.
			"Pincers": [["turn", "finger_l", Y, 25.0, -35.0, "snap"], ["turn", "finger_r", Y, -25.0, 35.0, GLAZIER_SNAP_R],
				["turn", "claw_l", X, -30.0, 6.0, "attack"], ["turn", "claw_l", Y, 25.0, -22.0, "attack"],
				["turn", "claw_r", X, -30.0, 6.0, "second"], ["turn", "claw_r", Y, -25.0, 22.0, "second"], ["rear", 0.35, "second"],
				["fx", 0.29, "sparks", {"from": "ClawL03", "color": "accent", "amount": 14, "speed": 2.5}],
				["fx", 0.41, "sparks", {"from": "ClawR03", "color": "accent", "amount": 14, "speed": 2.5}],
				["fx", 0.41, "shards", {"from": "ClawR03", "color": "#e8e0ff", "amount": 5, "speed": 2.0}]],
			## Whips its tail across in front of it, the saw slicing a bright arc.
			"Slice": [["spin", "saw", 8.0, "hold"], ["curl", "tail", X, -12.0, 22.0, "attack", "tip"], ["turn", "tail_all", Y, 32.0, -30.0, "attack"],
				["lean", Y, -8.0, 8.0, Vector3(0, 0, -0.2), "attack"], ["rear", 0.25, "attack"],
				["fx", 0.29, "swipe", {"about": "centre", "axis": Y, "start": Vector3(1, 0, 0.7), "radius": 1.2, "sweep": 110.0}],
				["fx", 0.3, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 36, "speed": 4.5}],
				["fx", 0.31, "shards", {"from": "Saw04", "color": "#e8e0ff", "amount": 6, "speed": 3.0}]],
			## Rears its tail back with the saw shrieking and drives it down into you, the whole
			## scorpion bearing in, and grinds there in a stream of sparks before it pulls out.
			"Eviscerate": [["spin", "saw", 14.0, GLAZIER_DRIVE], ["curl", "tail", X, -20.0, 26.0, GLAZIER_DRIVE, "tip"], ["turn", "tail_all", X, -10.0, 14.0, GLAZIER_DRIVE],
				["tremble", "tail_all", 0.03, GLAZIER_GRIND],
				["turn", "claw_l", X, 0.0, -14.0, GLAZIER_DRIVE], ["turn", "claw_l", Y, 0.0, 20.0, GLAZIER_DRIVE],
				["turn", "claw_r", X, 0.0, -14.0, GLAZIER_DRIVE], ["turn", "claw_r", Y, 0.0, -20.0, GLAZIER_DRIVE],
				["lean", X, -9.0, 6.0, Vector3(0, 0, -0.9), GLAZIER_DRIVE], ["rear", 0.35, "attack"],
				["fx", 0.3, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 40, "speed": 5.0}],
				["fx", 0.42, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 30, "speed": 4.5}],
				["fx", 0.54, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 30, "speed": 4.5}],
				["fx", 0.55, "shards", {"from": "Saw04", "color": "#e8e0ff", "amount": 8, "speed": 3.0}],
				["fx", 0.66, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 30, "speed": 4.5}],
				["fx", 0.76, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 24, "speed": 4.0}]],
			## Draws its spinning saw slowly across like a glasscutter's wheel, scoring a line.
			"Cut": [["spin", "saw", 8.0, "hold"], ["curl", "tail", X, -6.0, 16.0, "attack", "tip"], ["turn", "tail_all", Y, -22.0, 22.0, GLAZIER_SCORE],
				["fx", 0.2, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 14, "speed": 2.0, "life": 0.5}],
				["fx", 0.28, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 14, "speed": 2.0, "life": 0.5}],
				["fx", 0.36, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 14, "speed": 2.0, "life": 0.5}],
				["fx", 0.44, "sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 14, "speed": 2.0, "life": 0.5}]],
			## Scrabbles up the wall in a blur of legs, tilting as it climbs, glass dust kicked up.
			"Skitter": [["turn_each", "gait_a", Y, -20.0, 20.0, "shake"], ["turn_each", "gait_b", Y, 20.0, -20.0, "shake"],
				["hop", Vector3.ZERO, Vector3(-0.35, 0.22, -0.1), "hold"], ["lean", Z, 0.0, 14.0, Vector3.ZERO, "hold"],
				["fx", 0.12, "puff", {"from": "feet", "color": "#d8d0f0", "amount": 10, "size": 0.8, "rise": 0.4}],
				["fx", 0.2, "shards", {"from": "feet", "off": Vector3(0, 0.2, 0), "color": "#e8e0ff", "amount": 6, "speed": 2.0}]],
			## Anneals its glass: draws its pincers in, curls its tail over its back, and its plates
			## glow hot, heat shimmering off them as they set hard.
			"Anneal": [["turn", "claw_l", Y, 0.0, -20.0, "hold"], ["turn", "claw_r", Y, 0.0, 20.0, "hold"], ["curl", "tail", X, 0.0, 16.0, "hold", "tip"],
				["each", "plates", 0.0, 0.06, "pulse"],
				["fx", 0.2, "glow", {"from": "Body02", "color": "#ffb070", "size": 0.8}], ["fx", 0.22, "flash_light", {"from": "Body02", "color": "#ffa060", "energy": 3.0}],
				["fx", 0.25, "rise", {"from": "Body02", "color": "#ffc890", "amount": 18}],
				["fx", 0.32, "sparks", {"from": "Body01", "color": "#ffffff", "amount": 12, "speed": 2.0, "life": 0.5}]],
		},
		"heavy": {
			## Eviscerate held: it rears its front up and back with the tail cocked over it and its
			## pincers raised wide, the saw spinning up to a shriek in a fountain of sparks, and
			## comes down like a guillotine.
			"Eviscerate": {"at": "Saw04",
				"pose": [["turn", "claw_l", X, 0.0, -34.0, "h"], ["turn", "claw_l", Y, 0.0, 16.0, "h"],
					["turn", "claw_r", X, 0.0, -34.0, "h"], ["turn", "claw_r", Y, 0.0, -16.0, "h"],
					["hop", Vector3.ZERO, Vector3(0, 0.0, -0.14), "h"]],
				"charge": [["charge_dust", {"seconds": 0.45}], ["spiral", {"from": "Saw04", "color": "accent", "amount": 24}],
					["sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 30, "speed": 2.5, "life": 0.5}],
					["flash_light", {"from": "Saw04", "color": "#ffe8c0", "energy": 2.5}]],
				"impact": [["shock", {"ahead": 1.6, "size": 1.3}], ["shards", {"from": "Saw04", "color": "#e8e0ff", "amount": 16, "speed": 5.0}],
					["sparks", {"from": "Saw04", "color": "#ffe0a0", "amount": 50, "speed": 6.0}]]},
		},
	},
	## The Kaleidoscope: a great eye of coloured glass in a turning wheel of petals. It looks about,
	## its iris dilating and narrowing, blinks under its brow of crystals, the wheel turning on its
	## face; now and then it gazes round the room, spins its wheel through a whole turn, blinks
	## slowly, curls its tendrils. It glares (its iris pinpoint as it takes aim, then flaring wide),
	## blinds with a white flash, and drinks colour, its wheel turning backward.
	"THE_KALEIDOSCOPE": {
		"mouth": "Mouth01",
		"idle": "_idle_kaleidoscope",
		"groups": {
			"eye": {"parts": ["Eye", "Mouth", "Crest"], "at": "Eye01"},
			"eyeball": {"parts": ["Eye", "Mouth"], "at": Vector3(0, 1.7, 0)},
			"iris": {"parts": ["Eye03", "Eye12-19"], "at": Vector3(0, 1.7, 0.52)},
			"crest": {"parts": ["Crest"], "at": Vector3(0, 1.7, 0)},
			"petals": {"parts": ["Petal"], "at": "Petal01"},
			"t1": {"parts": ["Tendril01-03"], "at": "Tendril01"},
			"t2": {"parts": ["Tendril04-06"], "at": "Tendril04"},
			"t3": {"parts": ["Tendril07-09"], "at": "Tendril07"},
		},
		"idle_gestures": [["blink", "eyeball", Vector3(1.0, 0.12, 1.0), 4.6, 0.0], ["blink", "crest", [X, 12.0], 4.6, 0.0],
			["breathe", "iris", Vector3(0.3, 0.3, 0.0), 0.55, 0.0], ["look", "eye", 20.0, 9.0, 3.2, 1.1],
			["sway", "t1", X, 6.0, 0.9, 0.0], ["sway", "t2", X, 6.0, 0.9, 1.3], ["sway", "t3", X, 6.0, 0.9, 2.6]],
		"fidget_every": [3.5, 7.0],
		"fidgets": {
			## Gazes round the room, its iris narrowing on each thing it looks at.
			"look_round": {"length": 4.4, "hold": 2.6, "weight": 3.0, "do": [["grow", "iris", 0.0, -0.3, "f"], ["gaze", "eye", 40.0, 18.0, "f", 3]]},
			## Turns its wheel through a whole round on its face, the gems glinting in turn, the
			## iris opening wide.
			"kaleido": {"length": 3.0, "hold": 1.0, "weight": 2.5, "do": [["grow", "iris", 0.0, 0.35, "f"], ["whirl_own", "petals", Z, 1.0, "f"], ["call", "_kaleido_face"],
				["fx", 0.8, "sparks", {"from": "Petal02", "color": "#ff8ad0", "amount": 8, "speed": 1.2, "life": 0.5}],
				["fx", 1.2, "sparks", {"from": "Petal06", "color": "#8ad0ff", "amount": 8, "speed": 1.2, "life": 0.5}],
				["fx", 1.6, "sparks", {"from": "Petal10", "color": "#ffe08a", "amount": 8, "speed": 1.2, "life": 0.5}]]},
			## A slow double blink under a lowered brow.
			"blink": {"length": 2.0, "hold": 0.6, "weight": 1.5, "do": [["grow", "eyeball", 0.0, Vector3(0, -0.88, 0), KALEIDO_BLINK],
				["turn", "crest", X, 0.0, 14.0, KALEIDO_BLINK], ["grow", "iris", 0.0, -0.2, "f"]]},
			## Curls its three tendrils up one after another and lets them fall.
			"tendrils": {"length": 2.8, "hold": 0.8, "weight": 1.5, "do": [["turn", "t1", X, 0.0, -38.0, KALEIDO_CURL_1],
				["turn", "t2", Z, 0.0, -32.0, KALEIDO_CURL_2], ["turn", "t3", Z, 0.0, 32.0, KALEIDO_CURL_3], ["turn", "eye", X, 0.0, 10.0, "f"]]},
		},
		"moves": {
			## Its iris shrinks to a pinpoint as it takes aim, the eye drawn back; then the iris
			## flares wide under a lowered brow, the wheel whirls, and the glare lances out.
			"Glare": [["grow", "iris", -0.4, 0.55, "attack"], ["turn", "crest", X, 0.0, 16.0, "attack"], ["turn", "eye", X, -10.0, 6.0, "attack"],
				["whirl_own", "petals", Z, 1.0, "attack"], ["call", "_kaleido_face"], ["grow", "petals", -0.08, 0.12, "attack"], ["rear", 0.25, "attack"],
				["turn", "t1", X, -8.0, 14.0, KALEIDO_RECOIL], ["turn", "t2", Z, 6.0, -10.0, KALEIDO_RECOIL], ["turn", "t3", Z, -6.0, 10.0, KALEIDO_RECOIL],
				["fx", 0.27, "beam", {"from": "Mouth01", "color": "accent", "width": 0.16, "size": 0.6}],
				["fx", 0.29, "flash_light", {"from": "Mouth01", "color": "accent", "energy": 4.0}],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "accent", "amount": 16, "speed": 3.0, "life": 0.5}]],
			## Screws its eye shut under its brow, then flies it wide open in a blinding white flash.
			"Blind": [["grow", "iris", -0.3, 0.7, "attack"], ["grow", "eyeball", Vector3(0.04, -0.8, 0.04), Vector3(0.06, 0.08, 0.06), "attack"],
				["turn", "crest", X, 14.0, -12.0, "attack"], ["grow", "petals", -0.06, 0.12, "attack"], ["whirl_own", "petals", Z, -1.0, "attack"], ["call", "_kaleido_face"],
				["turn", "t1", X, -8.0, 14.0, KALEIDO_RECOIL], ["turn", "t2", Z, 6.0, -10.0, KALEIDO_RECOIL], ["turn", "t3", Z, -6.0, 10.0, KALEIDO_RECOIL],
				["fx", 0.3, "flash_light", {"from": "Mouth01", "color": "#ffffff", "energy": 7.0}], ["fx", 0.3, "glow", {"from": "Mouth01", "color": "#ffffff", "size": 0.9}],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ffffff", "amount": 24, "speed": 4.0}]],
			## Turns its wheel backward and drinks: its iris opens like a mouth, colours spiral into
			## it, its tendrils lift.
			"Drink": [["grow", "iris", 0.0, 0.45, "hold"], ["turn", "eye", X, 0.0, -8.0, "hold"], ["whirl_own", "petals", Z, -1.0, "hold"], ["call", "_kaleido_face"],
				["turn", "t1", X, 0.0, -25.0, "hold"], ["turn", "t2", Z, 0.0, -20.0, "hold"], ["turn", "t3", Z, 0.0, 20.0, "hold"],
				["fx", 0.05, "spiral", {"from": "Mouth01", "color": "#ff8ad0"}], ["fx", 0.3, "spiral", {"from": "Mouth01", "color": "#8ad0ff"}],
				["fx", 0.36, "glow", {"from": "Mouth01", "color": "accent", "size": 0.5}],
				["fx", 1.4, "sparks", {"from": "Mouth01", "color": "accent", "amount": 6, "speed": 0.8, "life": 0.4}]],
			## Both dice on Drink: it drinks deep, the wheel turning back twice and opening wide, three
			## colours pouring into its eye.
			"Deep Drink": [["grow", "iris", 0.0, 0.6, "hold"], ["turn", "eye", X, 0.0, -12.0, "hold"], ["whirl_own", "petals", Z, -2.0, "hold"], ["call", "_kaleido_face"],
				["grow", "petals", 0.0, 0.1, "hold"],
				["turn", "t1", X, 0.0, -32.0, "hold"], ["turn", "t2", Z, 0.0, -26.0, "hold"], ["turn", "t3", Z, 0.0, 26.0, "hold"],
				["fx", 0.05, "spiral", {"from": "Mouth01", "color": "#ff8ad0"}], ["fx", 0.18, "spiral", {"from": "Mouth01", "color": "#8ad0ff"}],
				["fx", 0.3, "spiral", {"from": "Mouth01", "color": "#ffe08a"}],
				["fx", 0.36, "glow", {"from": "Mouth01", "color": "accent", "size": 0.6}],
				["fx", 0.38, "sparks", {"from": "Mouth01", "color": "accent", "amount": 14, "speed": 1.5, "life": 0.6}],
				["fx", 1.4, "sparks", {"from": "Mouth01", "color": "accent", "amount": 8, "speed": 0.8, "life": 0.4}]],
		},
		"heavy": {
			## Glare held: the pinpoint iris holds its aim as the wheel fans open and light pours
			## into the pupil, the gems glinting; then the glare lands with a white flash.
			"Glare": {"at": "Mouth01",
				"pose": [["grow", "petals", 0.0, 0.1, "h"]],
				"charge": [["spiral", {"from": "Mouth01", "color": "accent", "amount": 30}], ["flash_light", {"from": "Mouth01", "color": "accent", "energy": 2.5}],
					["sparks", {"from": "Petal02", "color": "accent", "amount": 6, "speed": 1.0, "life": 0.4}],
					["sparks", {"from": "Petal06", "color": "accent", "amount": 6, "speed": 1.0, "life": 0.4}],
					["sparks", {"from": "Petal10", "color": "accent", "amount": 6, "speed": 1.0, "life": 0.4}],
					["charge_dust", {"seconds": 0.45}]],
				"impact": [["ripple", {"from": "Mouth01", "color": "accent", "radius": 1.5}], ["flash_light", {"from": "Mouth01", "color": "#ffffff", "energy": 6.0}],
					["sparks", {"from": "Mouth01", "color": "#ffffff", "amount": 30, "speed": 5.0}]]},
		},
	},
	## The Prismarch: a crystal monarch, crowned, a sceptre of light in one hand and an orb in the
	## other. It stands regal, its head turning slowly, the orb pulsing with gathered light and the
	## sceptre turning in its grip; now and then it surveys its court, taps its sceptre on the
	## floor, gazes into its orb, raises the sceptre aloft. It pounds the floor with the sceptre,
	## levels it like a lance, raises it high and calls the shards down on you.
	"THE_PRISMARCH": {
		"mouth": "Mouth01",
		"lead": {"Shardfall": 0.42},
		"groups": {
			"sceptre": {"parts": ["ArmL", "Sceptre", "Mouth"], "at": "ArmL01"},
			"rod": {"parts": ["Sceptre", "Mouth"], "at": Vector3(1.1, 1.45, 0.6)},
			"orb": {"parts": ["ArmR", "Orb"], "at": "ArmR01"},
			"orb_gem": {"parts": ["Orb"], "at": Vector3(-0.82, 2.09, 0.84)},
			"head": {"parts": ["Head", "Crown"], "at": "Head01"},
			"crown": {"parts": ["Crown"], "at": Vector3(0, 2.75, 0.05)},
		},
		"idle_gestures": [["breathe", "orb_gem", 0.14, 1.5, 0.0], ["sway", "orb", X, 2.5, 0.6, 0.0], ["sway", "rod", Y, 10.0, 0.45, 0.0],
			["look", "head", 14.0, 5.0, 4.0, 1.5]],
		"fidget_every": [3.5, 7.5],
		"fidgets": {
			## Surveys its court, turning its crowned head slowly from one side to the other.
			"survey": {"length": 4.6, "hold": 2.8, "weight": 3.0, "do": [["gaze", "head", 32.0, 10.0, "f", 3],
				["fx", 1.4, "sparks", {"from": "Crown13", "color": "accent", "amount": 6, "speed": 0.8, "life": 0.5}]]},
			## Taps its sceptre's foot on the floor twice, a chime of light at the spike each time.
			"tap": {"length": 2.0, "hold": 0.6, "weight": 2.0, "do": [["turn", "rod", X, 0.0, 12.0, PRISMARCH_TAP], ["turn", "sceptre", X, 0.0, -12.0, PRISMARCH_TAP],
				["fx", 0.5, "shock", {"from": "Sceptre01", "size": 0.35}], ["fx", 1.05, "shock", {"from": "Sceptre01", "size": 0.35}],
				["fx", 0.5, "sparks", {"from": "Mouth01", "color": "accent", "amount": 6, "speed": 0.8, "life": 0.4}],
				["fx", 1.05, "sparks", {"from": "Mouth01", "color": "accent", "amount": 6, "speed": 0.8, "life": 0.4}]]},
			## Lifts its orb and gazes into it, the light in it swelling.
			"orb_gaze": {"length": 3.6, "hold": 1.6, "weight": 2.0, "do": [["grow", "orb_gem", 0.0, 0.25, "f"], ["turn", "orb", X, 0.0, -40.0, "f"],
				["turn", "head", Y, 0.0, -20.0, "f"], ["turn", "head", X, 0.0, 10.0, "f"],
				["fx", 1.0, "spiral", {"from": "Orb01", "color": "#fff2c0", "amount": 16}],
				["fx", 1.4, "glow", {"from": "Orb01", "color": "#fff2c0", "size": 0.5}]]},
			## Raises its sceptre aloft for a moment, chin up, the spike glinting.
			"raise": {"length": 3.0, "hold": 1.0, "weight": 1.5, "do": [["turn", "rod", X, 0.0, 40.0, "f"], ["turn", "sceptre", X, 0.0, -40.0, "f"],
				["turn", "head", X, 0.0, -8.0, "f"],
				["fx", 1.2, "flash_light", {"from": "Mouth01", "color": "#fff2c0", "energy": 2.5}],
				["fx", 1.2, "sparks", {"from": "Mouth01", "color": "accent", "amount": 10, "speed": 1.2, "life": 0.5}]]},
		},
		"moves": {
			## Lifts its sceptre high and pounds its foot down on the floor: a shockwave and a burst of
			## crystal out of the stone.
			"Crush": [["turn", "rod", X, 35.0, -6.0, "big"], ["turn", "sceptre", X, -35.0, 6.0, "big"], ["turn", "orb", Z, -12.0, 0.0, "big"],
				["turn", "head", X, -8.0, 10.0, "big"], ["lean", X, -3.0, 4.0, Vector3.ZERO, "big"],
				["fx", 0.3, "shock", {"from": "Sceptre01", "size": 1.2}],
				["fx", 0.3, "shards", {"from": "Sceptre01", "off": Vector3(0, -1.3, 0), "color": "accent", "amount": 12, "speed": 4.0}],
				["fx", 0.31, "ring", {"color": "accent", "radius": 2.2}]],
			## Levels its sceptre like a lance and thrusts it, a needle of light lancing from its spike.
			"Lancet": [["turn", "rod", X, -8.0, 90.0, "attack"], ["turn", "sceptre", X, 12.0, -60.0, "attack"], ["lean", Y, 6.0, -8.0, Vector3.ZERO, "attack"],
				["turn", "head", X, 0.0, 6.0, "attack"],
				["fx", 0.26, "flash_light", {"from": "Mouth01", "color": "accent", "energy": 3.0}],
				["fx", 0.28, "beam", {"from": "Mouth01", "color": "accent", "width": 0.08, "size": 0.5}],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "accent", "amount": 12, "speed": 2.5, "life": 0.5}]],
			## Raises its sceptre high overhead, shards of light gathering at the spike, and brings it
			## down to point at you: the shards rain down.
			"Shardfall": [["turn", "rod", X, 0.0, 110.0, PRISMARCH_ROD], ["turn", "sceptre", X, 0.0, -110.0, PRISMARCH_RAISE],
				["turn", "head", X, 0.0, -10.0, PRISMARCH_ROD],
				["fx", 0.29, "shards", {"from": "Mouth01", "color": "accent", "amount": 12, "speed": 3.0}],
				["fx", 0.3, "bolt", {"from": "Mouth01", "color": "accent", "arc": 2.2, "flight": 0.24}],
				["fx", 0.34, "bolt", {"from": "Mouth01", "color": "accent", "arc": 2.8, "flight": 0.24}],
				["fx", 0.38, "bolt", {"from": "Mouth01", "color": "accent", "arc": 2.0, "flight": 0.24}],
				["fx", 0.42, "bolt", {"from": "Mouth01", "color": "accent", "arc": 2.6, "flight": 0.24}],
				["fx", 0.46, "bolt", {"from": "Mouth01", "color": "accent", "arc": 2.4, "flight": 0.24}]],
			## Raises a prism: lifts its sceptre and thumps it once, its orb hand sweeping out to call
			## the prism up out of the floor.
			"Raise a Prism": [["turn", "rod", X, 25.0, -4.0, "attack"], ["turn", "sceptre", X, -25.0, 4.0, "attack"], ["turn", "orb", Z, 0.0, -30.0, "hold"],
				["turn", "head", X, -6.0, 8.0, "attack"],
				["fx", 0.3, "shock", {"from": "Sceptre01", "size": 0.7}], ["fx", 0.3, "ring", {"color": "accent", "radius": 2.6}],
				["fx", 0.32, "glow", {"from": "Orb01", "color": "accent", "size": 0.6}]],
			## Raises its orb before its heart and gathers the light into it, head bowed to it, the
			## orb swelling bright.
			"Gather Light": [["grow", "orb_gem", 0.0, 0.25, "hold"], ["turn", "orb", X, 0.0, -45.0, "hold"], ["each", "Heart01", 0.0, 0.4, "hold"],
				["turn", "head", Y, 0.0, -12.0, "hold"], ["turn", "head", X, 0.0, 10.0, "hold"],
				["fx", 0.05, "spiral", {"from": "Orb01", "color": "#fff2c0"}], ["fx", 0.28, "spiral", {"from": "Orb01", "color": "#fff2c0", "amount": 20}],
				["fx", 0.35, "glow", {"from": "Orb01", "color": "#fff2c0", "size": 0.7}]],
			## Raises its orb aloft, chin up, its crown turning, and the orb blazes gold.
			"Brilliance": [["grow", "orb_gem", 0.0, 0.3, "hold"], ["turn", "orb", X, 0.0, -120.0, "hold"], ["whirl", "crown", Y, 1.0, "hold"],
				["turn", "head", X, 0.0, -12.0, "hold"], ["turn", "sceptre", X, 0.0, -8.0, "hold"], ["turn", "rod", X, 0.0, 8.0, "hold"],
				["fx", 0.3, "flash_light", {"from": "Orb01", "color": "#fff2c0", "energy": 5.0}], ["fx", 0.3, "glow", {"from": "Orb01", "color": "#fff2c0", "size": 0.8}],
				["fx", 0.34, "sparks", {"from": "Crown13", "color": "#ffe08a", "amount": 14, "speed": 1.5, "life": 0.6}]],
		},
		"heavy": {
			## Shardfall held: both arms raised, orb and sceptre aloft, chin up, the light gathering
			## at the spike; then the sceptre swings down and the shards come.
			"Shardfall": {"at": "Mouth01", "wind": 0.2,
				"pose": [["turn", "orb", X, 0.0, -70.0, "h"], ["grow", "orb_gem", 0.0, 0.25, "h"]],
				"charge": [["spiral", {"from": "Mouth01", "color": "accent", "amount": 30}], ["flash_light", {"from": "Mouth01", "color": "#fff2c0", "energy": 3.0}],
					["sparks", {"from": "Mouth01", "color": "accent", "amount": 20, "speed": 1.5, "life": 0.6}], ["charge_dust", {"seconds": 0.45}]],
				"impact": [["shards", {"from": "Mouth01", "color": "accent", "amount": 16, "speed": 4.5}], ["flash_light", {"from": "Mouth01", "color": "#fff2c0", "energy": 5.0}],
					["ring", {"color": "accent", "radius": 2.6}]]},
		},
	},
}

# --- the moves and idles no table says ---------------------------------------------------------

static func _idle_glazier(m: Node3D, clock: float, weight: float) -> void:
	## Now and then a pincer lifts a little, opens wide, clacks shut and opens again, left and
	## right on their own beats; each finger turns about where its wrist is now (the claw swings
	## on its own idle), before the claw that carries it lifts.
	for side in [["finger_l", 1.0, 0.0, 3.7, "claw_l"], ["finger_r", -1.0, 1.9, 4.3, "claw_r"]]:
		var gr: Dictionary = m.group(str(side[0]))
		var claw: Dictionary = m.group(str(side[4]))
		if gr.parts.is_empty() or claw.parts.is_empty():
			continue
		var every: float = float(side[3])
		var c: float = clock + float(side[2])
		var step: int = int(floor(c / every))
		var local: float = c - float(step) * every - every * (0.1 + 0.15 * (1.0 + m._noise(step * 5 + m.noise_seed + int(side[3] * 10.0))))
		var a: float = 0.0
		if local > 0.0 and local < 0.7:
			a = 16.0 * smoothstep(0.0, 0.7, local)
		elif local >= 0.7 and local < 0.76:
			a = lerpf(16.0, -30.0, (local - 0.7) / 0.06)
		elif local >= 0.76 and local < 0.88:
			a = -30.0
		elif local >= 0.88 and local < 1.3:
			a = -30.0 * (1.0 - smoothstep(0.88, 1.3, local))
		if absf(a) < 0.01:
			continue
		var first: Node3D = gr.parts[0]
		var now: Transform3D = first.transform * (first.get("_rest") as Transform3D).affine_inverse()
		m.turn(gr.parts, now * (gr.joint as Vector3), now.basis * Vector3.UP, deg_to_rad(a * float(side[1])) * weight)
		var lift: float = smoothstep(0.0, 0.5, local) * (1.0 - smoothstep(0.95, 1.3, local))
		m.turn(claw.parts, claw.joint, Vector3.RIGHT, deg_to_rad(-12.0) * lift * weight)

static func _idle_kaleidoscope(m: Node3D, clock: float, weight: float) -> void:
	## Its wheel of petals turns slowly on its own face, one way and back, as it yaws.
	var petals: Dictionary = m.group("petals")
	if petals.parts.is_empty():
		return
	var first: Node3D = petals.parts[0]
	var now: Transform3D = first.transform * (first.get("_rest") as Transform3D).affine_inverse()
	m.turn(petals.parts, now * (petals.joint as Vector3), now.basis * Vector3.BACK, deg_to_rad(28.0) * sin(clock * 0.32) * weight)

static func _kaleido_face(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its wheel swung round to face the party for a move (its idle yaws it about, edge on at
	## times), the short way to the nearer face as the move begins, and let go back to its own
	## yaw as the move ends. Laid after a whirl of the wheel on its own face.
	var petals: Dictionary = m.group("petals")
	if petals.parts.is_empty():
		return
	var first: Node3D = petals.parts[0]
	var now: Transform3D = first.transform * (first.get("_rest") as Transform3D).affine_inverse()
	var normal: Vector3 = now.basis * Vector3.BACK
	var yaw: float = atan2(normal.x, normal.z)
	if not clip.has("face_to"):
		clip.face_to = roundf(yaw / PI) * PI
	var t: float = float(clip.get("keyed", clip.t))
	var end: float = float(clip.length) - float(clip.get("shift", 0.0))
	var k: float = smoothstep(-0.12, 0.16, t) * (1.0 - smoothstep(end - 0.85, end - 0.05, t))
	if clip.has("fidget"):
		k = m.value(clip.f, t)
	k *= float(clip.get("weight", 1.0))
	if k > 0.0001:
		m.turn(petals.parts, now.origin, Vector3.UP, -wrapf(yaw - float(clip.face_to), -PI, PI) * k)
