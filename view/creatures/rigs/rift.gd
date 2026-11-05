extends RefCounted
## The Rift: the endless mine's creatures (and the Collapsar, the Riftling Swarm; a Void Echo
## wears the scene of whatever it copies, and that one's rig with it).
## Each creature's rig as data (see the gesture language in creature_rigs.gd), keyed by its scene,
## and the moves and idles no table says, written out as functions of the Moves node
## (creature_moves.gd) passed in as `m`. creature_rigs.gd merges every mine's RIGS.
##
## Pass 2 (November 3, 2026): every creature here acts its trope. Hovering things hover on the
## whole body (`_hover_body`, laid on the body like a lean, so nothing a move turns is thrown off
## its joints); an aperture, a ring or a wing held still is laid under everything else on its
## parts (`_inner_turn`, `_inner_swell`), as though it came first; what orbits is moved from where
## its orbit has carried it this frame (`_now`), not from where it rests.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

## How long the moves played by a function run.
const CUSTOM_LENGTH: Dictionary = {
	"_timeglass_turn": 1.0,
}
## When a move played by a function is wound back furthest (a heavy one holds there).
const CUSTOM_WIND: Dictionary = {
}

## Envelopes only these creatures use (see creature_rigs.gd ENV).
## The Null Shade's eye flaring as it winds and snuffed out on the blow.
const SNUFF: Array = [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.6, 1.0], [0.95, 0.0]]
## The Rift Shifter's ribbon winding once round as its slabs trade back.
const SHIFT_TURN: Array = [[0.0, 0.0], [0.5, 0.0], [0.75, 1.0], [1.02, 0.0]]
## The Rift Shifter coiling tight, held, and springing loose past where it rests.
const COIL: Array = [[0.0, 0.0], [0.8, 1.0], [1.35, 1.0], [1.65, -0.4], [1.95, 0.15], [2.3, 0.0]]
## Each of its slabs fanned out and back, one after another.
const FAN: Array = [[0.0, 0.0], [0.4, 1.0], [0.9, 1.0], [1.5, 0.0]]
## The Star Leech gulping as it feeds.
const LEECH_GULP: Array = [[0.0, 0.0], [0.15, 1.0], [0.3, 0.15], [0.45, 1.0], [0.6, 0.15], [0.75, 1.0], [0.9, 0.15], [1.2, 0.0]]
## The Timeglass tapping its foot, three times.
const TAP: Array = [[0.0, 0.0], [0.2, 1.0], [0.36, 0.0], [0.58, 1.0], [0.74, 0.0], [0.96, 1.0], [1.12, 0.0]]
## Winding itself up, a ratchet at a time.
const WIND_UP: Array = [[0.0, 0.0], [0.15, 1.0], [0.27, 0.0], [0.45, 1.0], [0.57, 0.0], [0.75, 1.0], [0.87, 0.0], [1.05, 1.0], [1.17, 0.0],
	[1.35, 1.0], [1.47, 0.0], [1.65, 1.0], [1.77, 0.0]]
## The Paradox Moth's lantern swinging after it as it darts, and swung up on its chain.
const DART_SWING: Array = [[0.0, 0.0], [0.45, 0.0], [0.85, 1.0], [1.3, -0.6], [1.75, 0.3], [2.2, 0.0]]
const LANTERN_SWING: Array = [[0.0, 0.0], [0.4, 1.0], [0.9, -1.0], [1.4, 0.7], [1.9, -0.35], [2.4, 0.0]]
## The Entropy Eye squinting to a slit, then flaring wide as it lets go.
const SQUINT: Array = [[0.0, 0.0], [0.7, 0.62], [1.75, 0.62], [2.05, -0.5], [2.3, -0.5], [2.75, 0.0]]
## The Riftling Swarm bursting outward, startled, and gathering again slowly.
const SCATTER: Array = [[0.0, 0.0], [0.12, 1.0], [0.45, 0.9], [2.1, 0.0]]
## The Infinite Void swelling in three jerks, held, and sinking back slowly (a fidget) and
## swelling in three jerks for its Expand.
const LURCH1: Array = [[0.0, 0.0], [0.25, 0.0], [0.31, 1.0], [2.0, 1.0], [2.9, 0.0]]
const LURCH2: Array = [[0.0, 0.0], [0.65, 0.0], [0.71, 1.0], [2.0, 1.0], [2.9, 0.0]]
const LURCH3: Array = [[0.0, 0.0], [1.05, 0.0], [1.11, 1.0], [2.0, 1.0], [2.9, 0.0]]
const EXPAND1: Array = [[0.0, 0.0], [0.1, 0.0], [0.15, 1.0], [0.9, 1.0], [1.3, 0.0]]
const EXPAND2: Array = [[0.0, 0.0], [0.2, 0.0], [0.25, 1.0], [0.9, 1.0], [1.3, 0.0]]
const EXPAND3: Array = [[0.0, 0.0], [0.28, 0.0], [0.33, 1.0], [0.9, 1.0], [1.3, 0.0]]

const RIGS: Dictionary = {
	## The Entropy Eye: a floating eye in an iris of dark petals. It hovers and looks about, the
	## eye darting first and the whole of it turning after; its petals breathe open and shut like
	## an aperture and snap shut for a blink; it peers and squints, unfurls and rolls its iris.
	"ENTROPY_EYE": {
		"mouth": "Eye02",
		"idle": "_idle_entropy",
		"groups": {"eye": {"parts": ["Eye"], "at": "Eye01"}, "pupil": {"parts": ["Eye02"], "at": Vector3(0, 1.35, 0.4)}, "iris": {"parts": ["Eye01"]},
			"all": {"parts": ["Core", "Rock", "Eye", "Box", "Petal", "Orbit"], "at": Vector3(0, 1.35, 0)},
			"ring": {"parts": ["Box", "Petal"], "at": Vector3(0, 1.35, 0.05)}, "shards": {"parts": ["Orbit"]}},
		"idle_gestures": [["look", "eye", 16.0, 10.0, 2.8, 0.45]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Looks hard about the room, the whole of it turning to each place, its iris narrowed.
			"glance": {"length": 3.4, "hold": 2.0, "weight": 2.0, "do": [["call", "_entropy_focus"], ["gaze", "all", 34.0, 14.0, "f", 3]]},
			## Squints to a slit and drifts closer to peer at the party, trembling, then flares wide.
			"squint": {"length": 2.8, "hold": 1.0, "weight": 1.5, "do": [["call", "_entropy_squint"], ["grow", "pupil", 0.0, -0.35, "f"],
				["move", "all", Vector3.ZERO, Vector3(0, -0.04, 0.14), "f"], ["tremble", "all", 0.006, "f"]]},
			## Opens its petals wide and rolls its whole iris round once, the eye swelling, shards
			## of light drifting off it.
			"unfurl": {"length": 3.6, "hold": 1.2, "weight": 1.5, "do": [["call", "_entropy_unfurl"], ["each", "iris", 0.0, 0.08, "f"], ["whirl", "ring", Z, 1.0, "f"],
				["fx", 1.1, "sparks", {"from": "Eye02", "color": "accent", "amount": 12, "speed": 1.4, "life": 0.9}]]},
		},
		"moves": {
			## Draws back with its aperture opened wide, then narrows it to focus as it pours its gaze
			## out at the party in a beam.
			"Gaze": [["call", "_entropy_gaze"], ["grow", "pupil", -0.2, 0.4, "breath"], ["turn", "all", X, -7.0, 4.0, "breath"],
				["move", "all", Vector3(0, 0.03, -0.12), Vector3(0, 0, 0.1), "breath"],
				["fx", 0.08, "spiral", {"from": "Eye02", "color": "accent", "amount": 14, "size": 0.45}],
				["fx", 0.27, "beam", {"from": "Eye02", "color": "accent", "width": 0.18}], ["fx", 0.27, "flash_light", {"from": "Eye02", "color": "accent"}],
				["fx", 0.31, "sparks", {"from": "Eye02", "color": "accent", "amount": 14, "speed": 2.2}]],
			## Fixes the party with a narrowed iris and a pinpoint pupil, leaning in, trembling with it.
			"Stare": {"length": 1.15, "do": [["call", "_entropy_stare"], ["grow", "pupil", 0.0, -0.45, "hold"], ["grow", "eye", 0.0, 0.12, "hold"],
				["move", "all", Vector3.ZERO, Vector3(0, -0.03, 0.16), "hold"], ["tremble", "all", 0.008, "hold"],
				["fx", 0.3, "ripple", {"from": "Eye02", "color": "accent", "radius": 1.3}], ["fx", 0.45, "ripple", {"from": "Eye02", "color": "accent", "radius": 1.9}]]},
			## Draws back with its iris wide, then snaps its aperture shut on the blow (the ring of
			## petals clicking round once) and opens again: a die gone, shards of it scattering.
			"Unmake": {"length": 1.05, "do": [["call", "_entropy_unmake"], ["whirl", "ring", Z, 1.0, "attack"], ["grow", "pupil", 0.3, -0.3, "attack"],
				["move", "all", Vector3(0, 0.02, -0.12), Vector3(0, 0, 0.08), "attack"],
				["fx", 0.3, "flash_light", {"from": "Eye02", "color": "#c070ff", "energy": 5.0}],
				["fx", 0.31, "shards", {"from": "Eye02", "color": "#c070ff", "amount": 12, "speed": 4.0}],
				["fx", 0.33, "puff", {"from": "Eye02", "color": "#3a2050", "amount": 10, "size": 0.8, "rise": 0.2}]]},
		},
	},
	## The Null Shade: a dark crystal that drinks light, hung over turning rings, its one eye
	## roving. It drifts and bobs; the motes of light round it are drawn into its eye and let go,
	## its glow dimming as it drinks; it reaches with the tendrils under it.
	"NULL_SHADE": {
		"mouth": "Eye01",
		"idle": "_idle_shade",
		"groups": {"eye": {"parts": ["Eye"], "at": "Eye01"}, "tendrils": {"parts": ["Tendril"], "at": Vector3(0, 0.9, 0)}, "socket": {"parts": ["Socket01"]},
			"motes": {"parts": ["Mote"], "at": "Eye01"}, "glow": {"parts": ["Core02"]}, "rings": {"parts": ["Ring"], "at": Vector3(0, 0.3, 0)},
			"shade": {"parts": ["Core01", "Spike01", "Eye", "Socket01", "Tendril"], "at": Vector3(0, 1.1, 0)}},
		"idle_gestures": [["look", "eye", 14.0, 8.0, 3.2, 0.8], ["sway_each", "tendrils", X, 6.0, 1.3, 1.2],
			["breathe", "motes", -0.2, 0.7, 0.0], ["breathe", "socket", -0.12, 0.7, 0.0], ["breathe", "glow", -0.3, 0.7, 0.0]],
		"fidget_every": [5.5, 10.0],
		"fidgets": {
			## Reaches its tendrils out toward the party, groping, and leans after them, its eye narrowed.
			"reach": {"length": 3.0, "hold": 1.0, "weight": 2.0, "do": [["turn_each", "tendrils", X, 0.0, -38.0, "f"], ["wave_each", "tendrils", Z, 9.0, 7.0, 1.3, "f"],
				["grow", "eye", 0.0, Vector3(0.08, -0.3, 0.0), "f"], ["turn", "shade", X, 0.0, 9.0, "f"], ["move", "shade", Vector3.ZERO, Vector3(0, -0.03, 0.1), "f"]]},
			## Drinks the light round it: the motes drawn into its eye, its glow sinking and its ring
			## tightening, and lets them go in a soft breath of light.
			"drink": {"length": 3.4, "hold": 1.2, "weight": 2.0, "do": [["grow", "motes", 0.0, -0.65, "f"], ["each", "socket", 0.0, -0.25, "f"], ["grow", "glow", 0.0, -0.55, "f"],
				["move", "shade", Vector3.ZERO, Vector3(0, -0.06, 0), "f"],
				["fx", 0.3, "spiral", {"from": "Eye01", "color": "#b8adff", "amount": 20, "size": 0.6}],
				["fx", 2.4, "glow", {"from": "Eye01", "color": "#b8adff", "size": 0.5}],
				["fx", 2.45, "puff", {"from": "Eye01", "color": "#b8adff", "amount": 8, "size": 0.5, "rise": 0.3, "glow": true}]]},
			## Turns lazily aside as it drifts, tilting, its tendrils trailing after.
			"drift": {"length": 3.6, "hold": 1.2, "weight": 1.5, "do": [["splay", "tendrils", 0.0, 14.0, "f"], ["turn", "shade", Y, 0.0, 32.0, "f"], ["turn", "shade", Z, 0.0, 6.0, "f"]]},
		},
		"moves": {
			## Reaches its tendrils out at the party and drinks, leaning after them, its ring flaring.
			"Drain": [["turn_each", "tendrils", X, 15.0, -45.0, "hold"], ["each", "socket", 0.0, 0.3, "hold"], ["turn", "shade", X, -8.0, 10.0, "attack"],
				["move", "shade", Vector3(0, 0.04, -0.08), Vector3(0, -0.02, 0.12), "attack"], ["rear", 0.2, "attack"],
				["fx", 0.2, "drain", {"from": "Eye01", "color": "#b8adff", "count": 5}], ["fx", 0.3, "flash_light", {"from": "Eye01", "color": "#8b7dff", "energy": 2.5}]],
			## Curls its tendrils up under it and sips the light out of the air, its motes drawn in.
			"Sip": [["splay", "tendrils", 0.0, -18.0, "hold"], ["turn_each", "tendrils", X, 0.0, -14.0, "hold"], ["grow", "motes", 0.0, -0.5, "hold"],
				["each", "socket", 0.0, 0.2, "pulse"], ["move", "shade", Vector3.ZERO, Vector3(0, 0.06, 0), "hold"],
				["fx", 0.15, "drain", {"from": "Eye01", "color": "#b8adff", "count": 3}], ["fx", 0.3, "glow", {"from": "Eye01", "color": "#b8adff", "size": 0.5}]],
			## Flares its eye, then snuffs it out on the blow as a gem goes out: its light gone in a
			## puff of dark, the motes round it drawn in after it.
			"Snuff": [["grow", "eye", 0.35, -0.8, SNUFF], ["each", "socket", 0.4, -0.3, SNUFF], ["grow", "motes", 0.0, -0.5, "hold"],
				["turn", "shade", X, -8.0, 4.0, "attack"],
				["fx", 0.18, "flash_light", {"from": "Eye01", "color": "#8b7dff", "energy": 3.0}],
				["fx", 0.3, "puff", {"from": "Eye01", "color": "#1e1830", "amount": 12, "size": 0.8, "rise": 0.25}],
				["fx", 0.32, "spiral", {"from": "Eye01", "color": "#8b7dff", "amount": 18, "size": 0.5}]],
			## Settles down over its rings like a damper, pressing them flat, its motes drawn in, and
			## lets a slow dark ripple out.
			"Dampen": [["grow", "motes", 0.0, -0.6, "hold"], ["grow", "rings", 0.0, Vector3(0.12, -0.5, 0.12), "hold"],
				["move", "shade", Vector3.ZERO, Vector3(0, -0.12, 0), "hold"], ["grow", "glow", 0.0, -0.4, "hold"],
				["fx", 0.25, "ripple", {"from": "Eye01", "color": "#5a4a8a", "radius": 1.6}], ["fx", 0.4, "ripple", {"from": "Eye01", "color": "#5a4a8a", "radius": 2.4}]],
		},
	},
	## The Rift Shifter: a ribbon of folded stone wound round a lit seam. A ribbon coils and
	## uncoils: a slow twist runs up it, winding the coil tighter and looser, a ripple running out
	## and in along it; its capstone head looks about. It coils tight and springs loose, fans its
	## slabs, folds flat and out of sight; it whips round to lash, and trades its slabs about to shift.
	"RIFT_SHIFTER": {
		"burrow": "fade",
		"mouth": "Mouth01",
		"idle": "_idle_shifter",
		"groups": {"ribbon": {"parts": ["Body"], "at": Vector3(0, 1.2, 0)}, "head": {"parts": ["Head", "Mouth"], "at": "Head01"},
			"slit": {"parts": ["Mouth01"], "at": Vector3(0, 2.26, 0.19)}},
		"idle_gestures": [["look", "head", 18.0, 6.0, 3.0, 1.0]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Winds its ribbon tight round the seam, the head turning with the top of it, and
			## springs loose again past where it rests, static crackling up the seam.
			"coil": {"length": 2.4, "hold": 0.6, "weight": 2.0, "do": [["call", "_shifter_coil"],
				["fx", 1.6, "sparks", {"from": "centre", "color": "accent", "amount": 14, "speed": 2.0}]]},
			## Fans its slabs out from the seam one after another up the ribbon, rearing its head back.
			"fan": {"length": 2.6, "hold": 0.8, "weight": 1.5, "do": [["call", "_shifter_fan"], ["turn", "head", X, 0.0, -14.0, "f"],
				["grow", "slit", 0.0, Vector3(0, 1.4, 0), "f"]]},
			## Looks round the room, its ribbon turning a little after its head.
			"glance": {"length": 3.4, "hold": 1.6, "weight": 1.5, "do": [["gaze", "head", 40.0, 12.0, "f", 3], ["turn", "ribbon", Y, 0.0, 14.0, "f"]]},
			## Half folds out of sight and back: its slabs pressed thin to the seam for a moment, a
			## breath of rift light.
			"flicker": {"length": 2.0, "hold": 0.5, "weight": 1.0, "do": [["call", "_shifter_flicker"],
				["fx", 0.7, "puff", {"from": "centre", "color": "accent", "amount": 8, "size": 0.8, "glow": true, "rise": 0.3}]]},
		},
		"moves": {
			## Coils its ribbon back tight and whips it round at the party, the top slabs flung out
			## wide, its head snapping after.
			"Lash": [["call", "_shifter_lash"], ["whirl", "ribbon", Y, 1.0, "attack"], ["turn", "head", Y, -30.0, 24.0, "attack"], ["turn", "head", X, -14.0, 14.0, "attack"],
				["lean", X, -5.0, 7.0, Vector3.ZERO, "attack"],
				["fx", 0.29, "swipe", {"about": "centre", "axis": Y, "start": Vector3(1, 0, 0.5), "radius": 1.0, "sweep": 150.0}]],
			## Two neighbouring slabs at a time trade places up the ribbon (each pair passing, one out
			## and one in), and trade back as the ribbon winds once round: your gems moved.
			"Shift": {"length": 1.1, "do": [["call", "_shifter_shift"], ["whirl", "ribbon", Y, -1.0, SHIFT_TURN], ["grow", "slit", 0.0, Vector3(0, 1.5, 0), "pulse"],
				["fx", 0.2, "spiral", {"from": "centre", "color": "accent"}], ["fx", 0.32, "sparks", {"from": "Mouth01", "color": "accent", "amount": 14, "speed": 2.0}]]},
			## Folds in on itself, its slabs pressed flat and tight to the seam and its head bowed, and
			## goes out of reach in a breath of rift light.
			"Fold": [["call", "_shifter_fold"], ["whirl", "ribbon", Y, 1.0, "hold"], ["turn", "head", X, 0.0, 22.0, "hold"],
				["fx", 0.3, "puff", {"from": "centre", "color": "accent", "amount": 14, "size": 1.2, "glow": true}], ["fx", 0.3, "ring", {"color": "accent", "radius": 1.3}]],
		},
	},
	## The Infinite Void (the Unmade): a black hole, a whirlpool of slabs and rubble winding into
	## the black stone at its heart, fed by a funnel of rock torn off the floor. Its motion is
	## wrong: the whirl stutters, stops dead and lurches on; pieces drift out of it and snap back;
	## it swells in jerks and sinks back slowly, glitches, turns its whirl on the party to look;
	## light is drawn up the funnel into it and goes out. Consume draws everything in and throws
	## itself open at the party; Halt stops the whole of it dead.
	"THE_UNMADE": {
		"mouth": "Heart01",
		"idle": "_idle_unmade",
		"groups": {"arms": {"parts": ["Arm"]}, "heart": {"parts": ["Heart01"]}, "funnel": {"parts": ["Funnel", "Light"], "at": Vector3(0, 1.0, 0)},
			"disc": {"parts": ["Heart01", "Ring", "Arm"], "at": Vector3(0, 2.5, 0)}, "lights": {"parts": ["Light"]}, "stones": {"parts": ["Bob"]},
			"orbiters": {"parts": ["Funnel", "Light", "Ring02", "Orbit"]},
			"f0": {"parts": ["Funnel01-05"]}, "f1": {"parts": ["Funnel06-12"]}, "f2": {"parts": ["Funnel13-20"]}, "f3": {"parts": ["Funnel21-29"]},
			"f4": {"parts": ["Funnel30-39"]}},
		"fidget_every": [3.5, 7.0],
		"fidgets": {
			## Swells in three jerks, a pulse of the dark at its heart with each, and sinks back slowly.
			"lurch": {"length": 3.0, "hold": 1.0, "weight": 2.0, "do": [["grow", "disc", 0.0, 0.07, LURCH1], ["grow", "disc", 0.0, 0.07, LURCH2],
				["grow", "disc", 0.0, 0.07, LURCH3], ["grow", "funnel", 0.0, Vector3(0.14, 0.0, 0.14), "f"],
				["fx", 0.31, "glow", {"from": "Heart01", "color": "#8b7dff", "size": 0.5}], ["fx", 0.71, "glow", {"from": "Heart01", "color": "#8b7dff", "size": 0.5}],
				["fx", 1.11, "glow", {"from": "Heart01", "color": "#8b7dff", "size": 0.6}],
				["fx", 1.12, "puff", {"from": "Heart01", "color": "#2a1a48", "amount": 12, "size": 1.2, "rise": 0.2}]]},
			## Pieces of its whirl drift out of it, slowly, and hang there, and snap back in all at once.
			"unravel": {"length": 2.8, "hold": 0.6, "weight": 2.0, "do": [["call", "_unmade_unravel"],
				["fx", 2.26, "flash_light", {"from": "Heart01", "color": "#c8b8ff", "energy": 3.0}],
				["fx", 2.26, "spiral", {"from": "Heart01", "color": "#8b7dff", "amount": 24, "size": 0.9}]]},
			## Tilts its whole whirl round to face the party, as though it looked at it, and holds there.
			"regard": {"length": 3.6, "hold": 1.6, "weight": 1.5, "do": [["turn", "disc", X, 0.0, 24.0, "f"], ["turn", "disc", Y, 0.0, -12.0, "f"],
				["fx", 0.8, "spiral", {"from": "Heart01", "color": "#8b7dff", "amount": 20, "size": 0.8}]]},
			## Glitches: jumps between poses a few times as though frames of it went missing, crackling.
			"glitch": {"length": 1.6, "hold": 0.6, "weight": 1.2, "do": [["call", "_unmade_glitch"],
				["fx", 0.45, "sparks", {"from": "Heart01", "color": "#e8e0ff", "amount": 18, "speed": 3.0}],
				["fx", 0.8, "sparks", {"from": "Heart01", "color": "#e8e0ff", "amount": 14, "speed": 3.0}]]},
			## Draws the stones up off the floor through its funnel into its heart, the funnel spinning
			## up and narrowing, grit rising; new stones lift where they were.
			"inhale": {"length": 3.6, "hold": 1.2, "weight": 1.5, "do": [["call", "_unmade_tear"], ["each", "heart", 0.0, 0.1, "f"],
				["grow", "funnel", 0.0, Vector3(-0.18, 0.08, -0.18), "f"], ["whirl", "funnel", Y, 1.0, "f"],
				["fx", 0.4, "rise", {"from": "feet", "color": "#6a5a7a", "amount": 20, "size": 1.6}],
				["fx", 2.2, "glow", {"from": "Heart01", "color": "#c8b8ff", "size": 0.5}]]},
		},
		"moves": {
			## Draws everything in (its arms pulled tight to its heart, the light of the party dragged
			## into it, its heart swelling dark), then throws itself open at the party: the whirl
			## tipping at it and flung wide.
			"Consume": [["spin", "arms", 2.0, "big"], ["each", "heart", 0.12, 0.3, "big"], ["grow", "arms", -0.25, 0.2, "big"], ["turn", "disc", X, -10.0, 16.0, "big"],
				["whirl", "funnel", Y, 1.0, "big"], ["hop", Vector3(0, 0.12, -0.12), Vector3(0, -0.04, 0.16), "big"],
				["fx", 0.04, "spiral", {"from": "Heart01", "color": "#8b7dff", "amount": 40}], ["fx", 0.08, "drain", {"from": "Heart01", "color": "#c8b8ff", "count": 6}],
				["fx", 0.3, "ripple", {"from": "Heart01", "color": "#8b7dff", "radius": 2.2}], ["fx", 0.3, "flash_light", {"from": "Heart01", "color": "#c8b8ff", "energy": 4.0}],
				["fx", 0.31, "shards", {"from": "Heart01", "color": "#e8e0ff", "amount": 16, "speed": 5.0}]],
			## Swells in three jerks as it grows another die, a ripple of the dark with each, and
			## sinks back.
			"Expand": {"length": 1.4, "do": [["grow", "disc", 0.0, 0.08, EXPAND1], ["grow", "disc", 0.0, 0.08, EXPAND2], ["grow", "disc", 0.0, 0.08, EXPAND3],
				["each", "heart", 0.0, 0.2, "hold"], ["grow", "funnel", 0.0, Vector3(0.15, 0.05, 0.15), "hold"],
				["fx", 0.15, "ripple", {"from": "Heart01", "color": "#8b7dff", "radius": 1.4}], ["fx", 0.25, "ripple", {"from": "Heart01", "color": "#8b7dff", "radius": 1.9}],
				["fx", 0.33, "ripple", {"from": "Heart01", "color": "#8b7dff", "radius": 2.4}], ["fx", 0.33, "ring", {"color": "#8b7dff", "radius": 4.0}],
				["fx", 0.33, "flash_light", {"from": "Heart01", "color": "#8b7dff", "energy": 5.0}]]},
			## Shrinks in on itself, its funnel turning backward and its whirl tipped at the party,
			## the dark rolling off it in slow rings: every die of yours shrinks.
			"Dread": [["grow", "disc", 0.0, -0.14, "hold"], ["turn", "disc", X, 0.0, 14.0, "hold"], ["whirl", "funnel", Y, -1.0, "hold"],
				["fx", 0.1, "spiral", {"from": "Heart01", "color": "#3a2a5a", "amount": 30}],
				["fx", 0.25, "ripple", {"from": "Heart01", "color": "#5a3a8a", "radius": 2.0}], ["fx", 0.4, "ripple", {"from": "Heart01", "color": "#5a3a8a", "radius": 2.8}],
				["fx", 0.55, "ripple", {"from": "Heart01", "color": "#5a3a8a", "radius": 3.6}]],
			## Everything in it stops dead (the whirl, the funnel, the light drawn up it) and lurches
			## back into motion after: the party stunned.
			"Halt": {"length": 1.0, "do": [["call", "_unmade_halt"], ["each", "heart", 0.0, -0.08, "hold"],
				["fx", 0.28, "ripple", {"from": "Heart01", "color": "#e8e8ff", "radius": 2.4}], ["fx", 0.3, "flash_light", {"from": "Heart01", "color": "#e8e8ff", "energy": 4.0}]]},
		},
		"heavy": {
			## Consume held: it hangs drawn in, shaking, its whirl pulled tighter round its heart, light
			## and grit dragged in to it from the whole room; then it throws itself open.
			"Consume": {"at": "Heart01", "shiver": 1.3, "pose": [["grow", "arms", 0.0, -0.1, "h"], ["tremble", "disc", 0.025, "h"]],
				"charge": [["spiral", {"from": "Heart01", "color": "#8b7dff", "amount": 44}], ["spiral", {"from": "Heart01", "color": "#c8b8ff", "amount": 24, "size": 1.6}],
					["charge_glow", {"from": "Heart01", "color": "#a898ff", "seconds": 0.5}], ["rise", {"from": "feet", "color": "#6a5a7a", "amount": 24, "size": 1.6}]],
				"impact": [["ring", {"color": "#8b7dff", "radius": 4.0}], ["ripple", {"from": "Heart01", "color": "#c8b8ff", "radius": 3.2}],
					["shards", {"from": "Heart01", "color": "#e8e0ff", "amount": 20, "speed": 6.0}], ["flash_light", {"from": "Heart01", "color": "#c8b8ff", "energy": 6.0}]]},
		},
	},
	## The Hush: a faceless eel of dark stone threading rings of light, a quiet swimmer. A slow
	## swimming wave runs down it from the head as it glides and bobs, its head looking about; it
	## glides in a bigger wave, mutes the room by tightening its rings one after another, lifts its
	## head to look round.
	"HUSH": {
		"burrow": "fade",
		"mouth": "Eye07",
		"idle": "_idle_hush",
		"groups": {
			"body": {"chain": [["Body26"], ["Body25"], ["Body24"], ["Body23"], ["Body22"], ["Body21"], ["Body20"], ["Body19"], ["Body18"], ["Body17"], ["Body16"],
				["Body15"], ["Body14"], ["Body13"], ["Body12"], ["Body11"], ["Body10"], ["Body09"], ["Body08"], ["Body07"], ["Body06"], ["Body05"], ["Body04"],
				["Body03"], ["Body02"], ["Body01"]], "riders": ["Tail"], "attach": ["Fin"]},
			"head": {"parts": ["Head", "Eye"], "at": "Head01"}, "lashes": {"parts": ["Eye05-09"], "at": "Eye01"}, "crescent": {"parts": ["Eye01-04"], "at": "Eye01"},
			"rings": {"parts": ["Ring"]}, "fins": {"parts": ["Fin"]},
		},
		"idle_gestures": [["look", "head", 12.0, 6.0, 3.6, 1.2]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Glides in a bigger swimming wave, its head leading it side to side, its fins rippling.
			"glide": {"length": 3.6, "hold": 1.6, "weight": 2.0, "idle": 0.0, "do": [["wave_each", "fins", X, 14.0, 6.0, 1.0, "f"], ["call", "_hush_glide"]]},
			## Mutes the room: its rings tighten round it one after another, its lashes lowered, the
			## light round it drawn in.
			"mute": {"length": 3.0, "hold": 1.0, "weight": 1.5, "do": [["call", "_hush_mute"], ["turn", "lashes", X, 0.0, 22.0, "f"], ["grow", "crescent", 0.0, -0.3, "f"],
				["fx", 0.6, "spiral", {"from": "Eye07", "color": "#5a5a8a", "amount": 18, "size": 0.6}]]},
			## Lifts its head to look about the room, its eye opening wide.
			"look": {"length": 3.4, "hold": 1.6, "weight": 1.5, "do": [["turn", "lashes", X, 0.0, -18.0, "f"], ["grow", "crescent", 0.0, 0.2, "f"],
				["gaze", "head", 34.0, 16.0, "f", 3]]},
		},
		"moves": {
			## Draws its head back and hums at the party, its lashes lifting and its rings spinning up,
			## the sound rolling out in rings.
			"Hum": [["turn", "lashes", X, 0.0, -25.0, "hold"], ["grow", "crescent", 0.0, 0.25, "hold"], ["turn", "head", X, -14.0, 10.0, "attack"],
				["spin", "rings", 1.0, "hold"],
				["fx", 0.25, "ripple", {"from": "Eye07", "color": "accent", "radius": 1.4}], ["fx", 0.38, "ripple", {"from": "Eye07", "color": "accent", "radius": 2.0}],
				["fx", 0.51, "ripple", {"from": "Eye07", "color": "accent", "radius": 2.6}]],
			## Bows its head and lowers its lashes; its rings close tight about it and the sound of the
			## room is drawn into it.
			"Hush": [["call", "_hush_close"], ["turn", "lashes", X, 0.0, 20.0, "hold"], ["turn", "head", X, 0.0, 10.0, "hold"],
				["fx", 0.1, "spiral", {"from": "Eye07", "color": "#5a5a8a", "amount": 22, "size": 0.7}],
				["fx", 0.3, "ripple", {"from": "Eye07", "color": "#3a3a5a", "radius": 2.0}]],
			## Bows its head and fades out of reach, its rings closing tight about it.
			"Fade": [["call", "_hush_close"], ["turn", "head", X, 0.0, 15.0, "hold"],
				["fx", 0.3, "puff", {"from": "centre", "color": "accent", "amount": 14, "size": 1.2, "glow": true}]],
		},
	},
	## The Star Leech: a pale leech with stars under its skin, wound round a gem and clinging to it.
	## A leech inches: a slow swell runs up its coil while its neck lifts and searches the air, its
	## sucker flaring; it rears up to search, flares its toothed sucker, squeezes its gem, screws
	## itself round it; it strikes to bite, stretches out to cling, and swells as it feeds.
	"STAR_LEECH": {
		"mouth": "Mouth01",
		"idle": "_idle_leech",
		"groups": {"head": {"parts": ["Head", "Mouth"], "at": "Head01"}, "sucker": {"parts": ["Mouth"], "at": "Mouth01"},
			"coil": {"parts": ["Body", "Head", "Mouth"], "at": Vector3(0, 0.45, 0)}, "gem": {"parts": ["Gem"], "at": "Gem01"},
			"body": {"parts": ["Body"], "at": Vector3(0, 0.45, 0)},
			## Its neck stone by stone, from where it leaves the coil to the sucker.
			"neck": {"chain": [["Head01-04"], ["Head05-07"], ["Head08-11"], ["Head12-16", "Mouth"]],
				"joints": [Vector3(-0.103, 0.84, -0.282), Vector3(-0.1, 0.96, -0.21), Vector3(-0.11, 1.08, -0.1), Vector3(-0.14, 1.17, 0.15)]}},
		"idle_gestures": [["breathe", "sucker", 0.12, 1.7, 0.0], ["curl", "neck", X, 6.0, 0.8, 0.0, "tip"], ["look", "head", 14.0, 6.0, 3.2, 1.2]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Rears its neck up high and searches the air, its sucker flaring, a few stars glinting.
			"rear": {"length": 3.4, "hold": 1.4, "weight": 2.0, "idle": 0.0, "do": [["grow", "sucker", 0.0, 0.3, "f"], ["curl", "neck", X, 0.0, -26.0, "f", "even"],
				["gaze", "head", 30.0, 6.0, "f", 3], ["fx", 1.0, "sparks", {"from": "Mouth01", "color": "#ffe8ff", "amount": 10, "speed": 1.2, "life": 0.8}]]},
			## Flares its toothed sucker open twice, showing its teeth.
			"flare": {"length": 2.2, "hold": 0.6, "weight": 1.5, "do": [["grow", "sucker", -0.15, 0.45, "chomp"], ["turn", "head", X, 0.0, -8.0, "f"],
				["fx", 0.18, "sparks", {"from": "Mouth01", "color": "#ffe8ff", "amount": 8, "speed": 1.5}],
				["fx", 0.5, "sparks", {"from": "Mouth01", "color": "#ffe8ff", "amount": 8, "speed": 1.5}]]},
			## Squeezes its coil tight round its gem, which glows under it, stars twinkling.
			"squeeze": {"length": 3.0, "hold": 1.0, "weight": 1.5, "do": [["grow", "gem", 0.0, 0.07, "f"], ["grow", "coil", 0.0, Vector3(-0.07, 0.03, -0.07), "f"],
				["fx", 0.9, "sparks", {"from": "Gem03", "color": "#ffe8ff", "amount": 12, "speed": 1.0, "life": 0.9}],
				["fx", 1.1, "flash_light", {"from": "Gem03", "color": "#ffd0ff", "energy": 2.0}]]},
			## Screws itself a little way round its gem and back.
			"inch": {"length": 3.2, "hold": 0.8, "weight": 1.0, "do": [["turn", "coil", Y, 0.0, -26.0, "f"]]},
		},
		"moves": {
			## Rears its neck back with its sucker flared, and strikes down at the party, clamping shut.
			"Bite": [["grow", "sucker", 0.4, -0.15, "attack"], ["curl", "neck", X, -22.0, 28.0, "attack", "tip"], ["rear", 0.3, "attack"],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ffd0ff", "amount": 12, "speed": 2.5}]],
			## Stretches its neck out at the party and fastens on, its sucker working and its coil
			## tightening round its gem.
			"Cling": {"length": 1.25, "do": [["grow", "sucker", 0.35, -0.08, "twice"], ["curl", "neck", X, -14.0, 20.0, "attack", "tip"],
				["grow", "head", 0.0, Vector3(0, 0, 0.18), "hold"], ["grow", "coil", 0.0, Vector3(-0.05, 0.02, -0.05), "hold"],
				["fx", 0.3, "sparks", {"from": "Mouth01", "color": "#ff9ad8", "amount": 14, "speed": 2.0}]]},
			## Fastens on and drinks in long gulps, its whole coil swelling round its gem as it feeds,
			## stars rising off it.
			"Feed": {"length": 1.3, "do": [["grow", "sucker", 0.0, 0.3, LEECH_GULP], ["curl", "neck", X, 0.0, 9.0, LEECH_GULP, "tip"],
				["grow", "coil", 0.0, Vector3(0.12, 0.07, 0.12), "rise"], ["grow", "gem", 0.0, 0.1, "twice"],
				["fx", 0.15, "drain", {"from": "Mouth01", "color": "#ffd0ff", "count": 5}],
				["fx", 0.7, "rise", {"from": "Gem03", "color": "#ffe8ff", "amount": 12, "size": 0.6}]]},
		},
	},
	## The Timeglass: an hourglass on three crystal legs, a clock that walks. It ticks: every second
	## the glass gives a little jerk one way and then the other, the grains over it hopping and its
	## neck flashing, its sand trickling; it taps a foot, tips its glass to pour, winds itself up,
	## rises on its legs to peer; it turns all the way over to run time back.
	"TIMEGLASS": {
		"mouth": "Sand03",
		"idle": "_idle_timeglass",
		"groups": {"glass": {"parts": ["Body", "Sand"], "at": "Body01"}, "grains": {"parts": ["Grain"], "at": "Body01"},
			"top_sand": {"parts": ["Sand01"], "at": Vector3(0, 1.38, 0)}, "low_sand": {"parts": ["Sand02"], "at": Vector3(0, 0.6, 0)}, "neck": {"parts": ["Sand03"]},
			"leg_l": {"parts": ["Leg01-03"]}, "leg_r": {"parts": ["Leg04-06"]}, "leg_f": {"parts": ["Leg07-09"]}, "legs": {"parts": ["Leg"], "at": Vector3(0, 0.55, 0)}},
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Taps a foot impatiently, three times, leaning off it, a puff of grit at each.
			"tap": {"length": 2.0, "hold": 1.0, "weight": 2.0, "do": [["turn", "leg_l", Vector3(0.5, 0, 0.866), 0.0, 26.0, TAP], ["turn", "glass", Z, 0.0, -3.0, "f"],
				["fx", 0.36, "puff", {"from": "feet", "off": Vector3(0.6, 0.05, -0.35), "color": "#6a5a4a", "amount": 4, "size": 0.4, "rise": 0.2}],
				["fx", 0.74, "puff", {"from": "feet", "off": Vector3(0.6, 0.05, -0.35), "color": "#6a5a4a", "amount": 4, "size": 0.4, "rise": 0.2}],
				["fx", 1.12, "puff", {"from": "feet", "off": Vector3(0.6, 0.05, -0.35), "color": "#6a5a4a", "amount": 4, "size": 0.4, "rise": 0.2}]]},
			## Tips its glass over to one side to pour, the sand running, the grains whirling over it,
			## and rights itself.
			"pour": {"length": 3.0, "hold": 1.0, "weight": 1.5, "do": [["grow", "top_sand", 0.0, Vector3(-0.05, -0.2, -0.05), "f"],
				["grow", "low_sand", 0.0, Vector3(0.05, 0.25, 0.05), "f"], ["turn", "glass", Z, 0.0, 24.0, "f"], ["whirl", "grains", Y, 1.0, "f"],
				["splay", "legs", 0.0, 5.0, "f"]]},
			## Winds itself up: the glass turned once all the way round on its legs, a ratchet at a
			## time, and a tick of light at the end.
			"wind": {"length": 2.6, "hold": 0.6, "weight": 1.0, "do": [["whirl", "glass", Y, 1.0, WIND_UP], ["whirl", "grains", Y, -1.0, "f"], ["tremble", "glass", 0.006, "f"],
				["fx", 2.0, "sparks", {"from": "Sand03", "color": "#ffe8a0", "amount": 14, "speed": 1.8}],
				["fx", 2.0, "flash_light", {"from": "Sand03", "color": "#ffe8a0", "energy": 2.0}]]},
			## Rises up on its legs to peer about the room, and settles back.
			"peer": {"length": 3.2, "hold": 1.4, "weight": 1.5, "do": [["splay", "legs", 0.0, -7.0, "f"], ["gaze", "glass", 30.0, 0.0, "f", 2],
				["hop", Vector3.ZERO, Vector3(0, 0.07, 0), "f"]]},
		},
		"moves": {
			"Rewind": "_timeglass_turn",
			## Winds its glass back and snaps it round like a clock's hand striking, stamping its front
			## foot; a bolt of sand light flies.
			"Tick": [["each", "neck", 0.0, 0.6, "pulse"], ["turn", "glass", Y, -25.0, 30.0, "quick"], ["turn", "leg_f", X, -22.0, 6.0, "quick"],
				["hop", Vector3(0, 0.08, 0), Vector3(0, -0.02, 0), "quick"],
				["fx", 0.27, "bolt", {"from": "Sand03", "color": "#ffe8a0", "flight": 0.15}], ["fx", 0.3, "sparks", {"from": "Sand03", "color": "#ffe8a0", "amount": 16}],
				["fx", 0.3, "puff", {"from": "feet", "off": Vector3(0, 0.05, 0.75), "color": "#6a5a4a", "amount": 6, "size": 0.5, "rise": 0.3}]],
			## Races: the glass whirling round on its legs as they patter, the grains spinning over it,
			## sand light spiralling up.
			"Fast-forward": [["whirl", "grains", Y, 2.0, "hold"], ["whirl", "glass", Y, 2.0, "hold"], ["wave_each", "legs", "out", 14.0, 28.0, 2.1, "hold"],
				["tremble", "glass", 0.01, "hold"],
				["fx", 0.2, "spiral", {"from": "Sand03", "color": "#ffe8a0"}], ["fx", 0.3, "rise", {"from": "Sand03", "color": "#ffe8a0", "amount": 16, "size": 0.6}]],
			## Nothing: its sand stops running, the light in its neck going out, and it sags on its legs.
			"Still": [["each", "neck", 0.0, -0.7, "hold"], ["turn", "glass", Z, -4.0, 4.0, "shake"], ["splay", "legs", 0.0, 6.0, "hold"],
				["hop", Vector3.ZERO, Vector3(0, -0.05, 0), "hold"]],
		},
	},
	## The Paradox Moth: a dark-glass moth with a ghostly second pair of wings beating out of step
	## with the first. A moth flutters and hovers: it bobs and drifts, its reflection lagging a beat
	## behind it; it preens its feelers, holds its real wings still while the ghost wings beat on,
	## darts aside, swings its lantern.
	"PARADOX_MOTH": {
		"mouth": "Head01",
		"idle": "_idle_moth",
		"groups": {"wings_l": {"parts": ["WingL"]}, "wings_r": {"parts": ["WingR"]}, "ghost_l": {"parts": ["GhostL"]}, "ghost_r": {"parts": ["GhostR"]},
			"wings": {"parts": ["WingL", "WingR"]}, "ghosts": {"parts": ["GhostL", "GhostR"]},
			"lantern": {"parts": ["Lantern"], "at": "Lantern01"}, "head": {"parts": ["Head", "Antenna"], "at": "Head01"},
			"ant_r": {"parts": ["Antenna01-03"], "at": "Antenna01"}, "ant_l": {"parts": ["Antenna04-06"], "at": "Antenna04"}},
		"idle_gestures": [["look", "head", 12.0, 8.0, 2.6, 0.7], ["bob", "ghosts", Vector3(0, 0.025, 0), 1.5, -1.6]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Bows its head and combs its feelers forward and back.
			"preen": {"length": 2.8, "hold": 1.2, "weight": 1.5, "do": [["turn", "ant_r", X, 0.0, 38.0, "f"], ["turn", "ant_l", X, 0.0, 38.0, "f"],
				["turn", "ant_r", Z, 0.0, 10.0, "wag"], ["turn", "ant_l", Z, 0.0, -10.0, "wag"], ["turn", "head", X, 0.0, 18.0, "f"]]},
			## Holds its real wings still and wide while the ghost wings go on beating out of step: a
			## moth stopped in time and its reflection not.
			"still": {"length": 3.0, "hold": 1.4, "weight": 2.0, "do": [["call", "_moth_still"], ["turn_each", "wings_l", Z, 0.0, 16.0, "f"],
				["turn_each", "wings_r", Z, 0.0, -16.0, "f"], ["turn_each", "ghost_l", Z, 0.0, -14.0, "flutter"], ["turn_each", "ghost_r", Z, 0.0, 14.0, "flutter"],
				["fx", 1.0, "sparks", {"from": "centre", "color": "accent", "amount": 10, "speed": 0.8, "life": 1.0}]]},
			## Darts aside and back, tilting into it, its lantern swinging after.
			"dart": {"length": 2.4, "hold": 0.4, "weight": 1.5, "do": [["turn", "lantern", Z, -22.0, 22.0, DART_SWING],
				["hop", Vector3.ZERO, Vector3(0.22, 0.1, 0.0), "f"], ["lean", Z, 0.0, -14.0, Vector3(0, 1.0, 0), "f"]]},
			## Swings its lantern up on its chain, its light flaring.
			"swing": {"length": 2.6, "hold": 0.6, "weight": 1.0, "do": [["turn", "lantern", X, 30.0, -30.0, LANTERN_SWING], ["turn", "head", X, 0.0, 14.0, "f"],
				["fx", 0.8, "flash_light", {"from": "Lantern05", "color": "accent", "energy": 2.0}]]},
		},
		"moves": {
			## Beats both pairs of wings hard, out of step, and throws a gust of glittering dust.
			"Flutter": [["turn_each", "wings_l", Z, 0.0, 30.0, "flutter"], ["turn_each", "wings_r", Z, 0.0, -30.0, "flutter"],
				["turn_each", "ghost_l", Z, 0.0, -30.0, "flutter"], ["turn_each", "ghost_r", Z, 0.0, 30.0, "flutter"],
				["hop", Vector3(0, 0.08, -0.05), Vector3(0, 0.02, 0.08), "attack"],
				["fx", 0.2, "breath", {"from": "centre", "kind": "light", "color": "accent", "seconds": 0.35, "size": 0.5}],
				["fx", 0.26, "sparks", {"from": "centre", "color": "accent", "amount": 14, "speed": 2.5}]],
			## Swings its lantern up at the party on its chain, wings thrown open, its light flaring.
			"Lantern": [["turn_each", "wings_l", Z, 0.0, 14.0, "hold"], ["turn_each", "wings_r", Z, 0.0, -14.0, "hold"], ["turn", "lantern", X, 12.0, -40.0, "attack"],
				["fx", 0.28, "glow", {"from": "Lantern05", "color": "accent", "size": 0.6}], ["fx", 0.3, "flash_light", {"from": "Lantern05", "color": "accent"}],
				["fx", 0.32, "sparks", {"from": "Lantern05", "color": "accent", "amount": 12, "speed": 1.6}]],
			## Its ghost wings come away from it and drift out of step, threads of light unravelling
			## between them, and fold back in.
			"Unravel": [["turn_each", "ghost_l", Z, 0.0, -40.0, "hold"], ["turn_each", "ghost_r", Z, 0.0, 40.0, "hold"],
				["turn_each", "wings_l", Z, 0.0, 12.0, "hold"], ["turn_each", "wings_r", Z, 0.0, -12.0, "hold"], ["call", "_moth_unravel"],
				["fx", 0.2, "spiral", {"from": "centre", "color": "#c070ff"}], ["fx", 0.35, "ripple", {"from": "centre", "color": "#c070ff", "radius": 1.8}],
				["fx", 0.3, "sparks", {"from": "centre", "color": "#c070ff", "amount": 16, "speed": 1.5, "life": 1.0}]],
		},
	},
	## The Collapsar: a small collapsing star, a dark knot with a lit disc round it and splinters
	## falling in. A gravity well pulls: its debris is drawn in and let out again, each splinter on
	## its own beat, its disc precessing like a top; it swallows its debris and flings it out, flares,
	## wobbles; Singularity crushes everything to a point, holds it there shaking, and lets it go.
	"COLLAPSAR": {
		"idle": "_idle_collapsar",
		"groups": {"orbit": {"parts": ["Orbit"], "at": "Bob01"}, "core": {"parts": ["Core01", "Spin"]}, "rings": {"parts": ["Spin"], "at": "Bob01"},
			"star": {"parts": ["Bob01"]}},
		"idle_gestures": [["sway", "rings", X, 7.0, 0.55, 0.0], ["sway", "rings", Z, 7.0, 0.55, 1.57]],
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Swallows its debris: every splinter drawn in tight and whirled round, the knot swelling,
			## and flung back out in a spray of starlight.
			"swallow": {"length": 2.8, "hold": 0.6, "weight": 2.0, "do": [["each", "star", 0.0, 0.12, "f"], ["grow", "orbit", 0.0, -0.55, "f"], ["whirl", "orbit", Y, 1.0, "f"],
				["fx", 0.3, "spiral", {"from": "Bob01", "color": "#8b7dff", "amount": 24, "size": 0.7}],
				["fx", 1.9, "sparks", {"from": "Bob01", "color": "#c8b8ff", "amount": 16, "speed": 2.5}]]},
			## Flares: its disc spreads as the knot contracts, a flash and a ring of light.
			"flare": {"length": 2.0, "hold": 0.4, "weight": 1.5, "do": [["grow", "rings", 0.0, 0.22, "f"], ["each", "star", 0.0, -0.1, "f"],
				["fx", 0.7, "flash_light", {"from": "Bob01", "color": "#c8b8ff", "energy": 3.0}], ["fx", 0.7, "sparks", {"from": "Bob01", "color": "#e8e0ff", "amount": 22, "speed": 3.0}],
				["fx", 0.75, "ring", {"color": "#8b7dff", "radius": 1.4}]]},
			## Its disc tips far over like a top knocked aside, the debris tilting with it, and rights itself.
			"wobble": {"length": 3.0, "hold": 0.8, "weight": 1.0, "do": [["turn", "rings", X, 0.0, 32.0, "f"], ["turn", "rings", Z, 0.0, -18.0, "f"],
				["turn", "orbit", X, 0.0, 14.0, "f"]]},
		},
		"moves": {
			## Pulls: its debris drawn in tight, its disc tipping at the party and spinning up, the
			## light of the party dragged in to it.
			"pull": [["grow", "orbit", 0.0, -0.45, "hold"], ["spin", "core", 2.0, "hold"], ["turn", "rings", X, 0.0, 22.0, "hold"],
				["hop", Vector3(0, 0, -0.08), Vector3(0, 0, 0.1), "attack"],
				["fx", 0.05, "spiral", {"from": "Bob01", "color": "#8b7dff", "amount": 50}], ["fx", 0.2, "drain", {"from": "Bob01", "color": "#c8b8ff", "count": 4}]],
			## Collapses in on itself and bursts out at the blow: debris and disc crushed in, then
			## thrown wide in a flash.
			"Collapse": [["each", "star", -0.25, 0.15, "attack"], ["grow", "rings", -0.4, 0.25, "attack"], ["grow", "orbit", -0.45, 0.35, "attack"],
				["fx", 0.3, "flash_light", {"from": "Bob01", "color": "#8b7dff", "energy": 6.0}], ["fx", 0.3, "ring", {"color": "#8b7dff", "radius": 3.0}],
				["fx", 0.31, "shards", {"from": "Bob01", "color": "#c8b8ff", "amount": 12, "speed": 4.5}]],
			## Its field widens: the disc spreading, the debris swung out to a wider orbit, the knot
			## darkening at its middle.
			"Gravity": [["grow", "rings", 0.0, 0.3, "hold"], ["grow", "orbit", 0.0, 0.3, "hold"], ["each", "star", 0.0, -0.1, "hold"],
				["fx", 0.1, "spiral", {"from": "Bob01", "color": "#8b7dff"}], ["fx", 0.3, "ring", {"color": "#8b7dff", "radius": 2.0}]],
			## Both dice on Collapse: everything crushed down to a point, whirling, and let go all at once.
			"Singularity": [["each", "star", -0.4, 0.3, "big"], ["grow", "rings", -0.55, 0.4, "big"], ["grow", "orbit", -0.6, 0.5, "big"], ["whirl", "orbit", Y, 2.0, "big"],
				["hop", Vector3(0, 0.1, -0.1), Vector3(0, -0.02, 0.14), "big"],
				["fx", 0.05, "spiral", {"from": "Bob01", "color": "#8b7dff", "amount": 60}], ["fx", 0.12, "drain", {"from": "Bob01", "color": "#c8b8ff", "count": 6}],
				["fx", 0.3, "flash_light", {"from": "Bob01", "color": "#c8b8ff", "energy": 7.0}], ["fx", 0.3, "ring", {"color": "#8b7dff", "radius": 3.2}],
				["fx", 0.3, "shards", {"from": "Bob01", "color": "#e8e0ff", "amount": 18, "speed": 6.0}],
				["fx", 0.31, "sparks", {"from": "Bob01", "color": "#e8e0ff", "amount": 36, "speed": 6.0}]],
		},
		"heavy": {
			## Singularity held: crushed to its smallest, the disc shaking, starlight dragged in to it;
			## then everything flung out at once in a ring of light.
			"Singularity": {"at": "Bob01", "shiver": 1.2, "pose": [["tremble", "rings", 0.025, "h"], ["grow", "orbit", 0.0, -0.05, "h"]],
				"charge": [["spiral", {"from": "Bob01", "color": "#8b7dff", "amount": 50}], ["charge_glow", {"from": "Bob01", "color": "#b8a8ff", "seconds": 0.5}],
					["spiral", {"from": "Bob01", "color": "#c8b8ff", "amount": 24, "size": 1.5}]],
				"impact": [["ring", {"color": "#8b7dff", "radius": 3.8}], ["ripple", {"from": "Bob01", "color": "#c8b8ff", "radius": 3.0}],
					["shards", {"from": "Bob01", "color": "#e8e0ff", "amount": 16, "speed": 6.0}]]},
		},
	},
	## The Riftling Swarm: a cloud of rift shards round a small core, crackling. A swarm buzzes:
	## every shard jitters and tumbles on its own, the cloud breathing in and out ring by ring as it
	## drifts; it scatters and gathers, whirls into a vortex, streams aside; it darts at the party.
	"RIFTLING_SWARM": {
		"mouth": "Core01",
		"idle": "_idle_swarm",
		"ambient": [{"kind": "crackle", "at": "Core01", "size": 2.2, "color": "accent"}],
		"groups": {"swarm": {"parts": ["Orbit"], "at": "Core01"}, "core": {"parts": ["Core01"]},
			"ring_a": {"parts": ["Orbit01", "Orbit04", "Orbit07", "Orbit10", "Orbit13", "Orbit16"], "at": "Core01"},
			"ring_b": {"parts": ["Orbit02", "Orbit05", "Orbit08", "Orbit11", "Orbit14"], "at": "Core01"},
			"ring_c": {"parts": ["Orbit03", "Orbit06", "Orbit09", "Orbit12", "Orbit15"], "at": "Core01"}},
		"fidget_every": [5.0, 9.0],
		"fidgets": {
			## Startled: the whole cloud bursts outward, the core flickering, and gathers again slowly.
			"scatter": {"length": 2.2, "hold": 0.3, "weight": 2.0, "do": [["call", "_swarm_scatter"], ["each", "core", 0.0, 0.4, "pulse"],
				["fx", 0.12, "sparks", {"from": "Core01", "color": "accent", "amount": 14, "speed": 2.5}]]},
			## Whirls into a tight vortex, its rings of shards turning against each other.
			"swirl": {"length": 2.6, "hold": 0.8, "weight": 1.5, "do": [["grow", "swarm", 0.0, -0.25, "f"], ["whirl", "ring_a", Y, 1.0, "f"],
				["whirl", "ring_b", Y, -1.0, "f"], ["whirl", "ring_c", Y, 1.0, "f"]]},
			## Streams off to one side in a line, one shard after another, and back.
			"stream": {"length": 3.0, "hold": 0.9, "weight": 1.5, "do": [["call", "_swarm_stream"]]},
		},
		"moves": {
			## Darts at the party in a stream, the nearest shards first, and nips.
			"Nibble": {"length": 1.15, "do": [["call", "_swarm_dart"], ["rear", 0.25, "attack"],
				["fx", 0.3, "sparks", {"from": "Core01", "off": Vector3(0, 0, 0.6), "color": "accent", "amount": 10, "speed": 2.0}]]},
			## Another riftling: the swarm swells and whirls, its core flaring, motes rising off it.
			"Swarm": [["grow", "swarm", 0.0, 0.3, "hold"], ["whirl", "swarm", Y, 1.0, "hold"], ["each", "core", 0.0, 0.6, "pulse"],
				["fx", 0.3, "rise", {"from": "Core01", "color": "accent", "amount": 16, "size": 0.7}],
				["fx", 0.3, "sparks", {"from": "Core01", "color": "accent", "amount": 14, "speed": 2.0}]],
			## Crackles with static: every shard shivering hard, the core flickering, sparks jumping off it.
			"Static": [["call", "_swarm_crackle"], ["each", "core", -0.3, 0.5, "shake"],
				["fx", 0.12, "sparks", {"from": "Core01", "color": "#c8b8ff", "amount": 24, "speed": 3.5}],
				["fx", 0.3, "sparks", {"from": "Core01", "color": "#c8b8ff", "amount": 24, "speed": 3.5}],
				["fx", 0.3, "flash_light", {"from": "Core01", "color": "#c8b8ff", "energy": 3.0}]],
		},
	},
}

# --- shared here ---------------------------------------------------------------------------------

static func _t(clip: Dictionary) -> float:
	## Where a played function's clip stands in its own keys (its lead and a heavy hold taken out).
	return float(clip.get("keyed", float(clip.t) - float(clip.get("shift", 0.0))))

static func _about(pivot: Vector3, basis: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) * Transform3D(basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)

static func _inner_turn(m: Node3D, parts: Array, pivot: Vector3, axis: Vector3, angle: float) -> void:
	## A turn about a part's rest-pose joint laid under everything else already on it, as though it
	## came first (leaf first): a petal stays on its hinge however the idle has turned the eye that
	## carries it. Only for parts whose own idle keeps their pivot where it rests.
	if absf(angle) < 0.00001 or axis.is_zero_approx():
		return
	var about: Transform3D = _about(pivot, Basis(axis.normalized(), angle))
	for part in parts:
		m._offsets[part] = (m._offsets.get(part, Transform3D.IDENTITY) as Transform3D) * about

static func _inner_swell(m: Node3D, parts: Array, centre: Vector3, by: Vector3) -> void:
	## A swell about a rest-pose point, laid under everything else on these parts (`_inner_turn`).
	if by.is_equal_approx(Vector3.ONE):
		return
	var grown: Transform3D = _about(centre, Basis.from_scale(by))
	for part in parts:
		m._offsets[part] = (m._offsets.get(part, Transform3D.IDENTITY) as Transform3D) * grown

static func _now(part: Node3D) -> Vector3:
	## Where a part's shape is this frame, as its own idle motion (an orbit, a bob) has carried it,
	## before the moves lay anything on it.
	if part.get_child_count() > 0 and part.get_child(0) is Node3D:
		return part.transform * (part.get_child(0) as Node3D).transform.origin
	return part.transform.origin

static func _push_out(m: Node3D, parts: Array, centre: Vector3, by: float, level: bool = false) -> void:
	## Each part pushed straight away from `centre` (or toward it, by less than nothing) from where
	## it is now: an orbiting shard drifts out from wherever its orbit has carried it.
	if absf(by) < 0.00001:
		return
	for part in parts:
		var out: Vector3 = _now(part) - centre
		if level:
			out.y = 0.0
		if out.length() > 0.001:
			m.shift([part], out.normalized() * by)

static func _lay_body(m: Node3D, xform: Transform3D) -> void:
	## A move of the whole body (crystal_creature.gd lays it like a lean), over any other.
	m._lean = xform * (m._lean as Transform3D)
	m._leaning = true

static func _body_point(m: Node3D, at: Vector3) -> Vector3:
	## A point of the model where the whole body is moved from (its body's resting place).
	var rest: Variant = m._creature.get("_body_rest")
	return (rest as Transform3D) * at if rest is Transform3D else at

static func _hover_body(m: Node3D, clock: float, weight: float, height: float, rate: float, tilt: float, phase: float, pivot: Vector3) -> void:
	## Bobbing in the air with the whole body, tilting a beat behind and rocking a little: the
	## "hover" idle (creature_moves.gd), laid on the body rather than its parts.
	if weight <= 0.0001:
		return
	var s: float = clock * rate + phase
	var basis := Basis(Vector3.RIGHT, deg_to_rad(tilt) * sin(s - 1.1) * weight) * Basis(Vector3.BACK, deg_to_rad(tilt) * 0.6 * sin(s * 0.61 + 0.7) * weight)
	_lay_body(m, Transform3D(Basis.IDENTITY, Vector3(0, height * sin(s) * weight, 0)) * _about(_body_point(m, pivot), basis))

static func _look_body(m: Node3D, yaw: float, pitch: float, beat: float, lead: float, ease: float, weight: float, pivot: Vector3) -> void:
	## The whole body turning after where its eye looks: the engine's "look" (the same places on
	## the same beat as a "look" whose ease is `lead`), eased over `ease` seconds instead, so the
	## eye darts there first and the body follows it.
	if weight <= 0.0001:
		return
	var clock: float = float(m._clock)
	beat = maxf(0.6, beat)
	lead = clampf(lead, 0.45, beat)
	var step: int = int(floor(clock / beat))
	var local: float = clock - float(step) * beat
	var start: float = (beat - lead) * (0.25 + 0.25 * float(m._noise(step * 5 + int(m.noise_seed) + 3)))
	var x: float = smoothstep(start, minf(start + ease, beat - 0.01), local)
	var dir: Vector2 = (m._look_target(step - 1) as Vector2).lerp(m._look_target(step) as Vector2, x)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw) * dir.x * weight) * Basis(Vector3.RIGHT, deg_to_rad(pitch) * dir.y * weight)
	_lay_body(m, _about(_body_point(m, pivot), basis))

# --- the Entropy Eye: its aperture ------------------------------------------------------------

const ENTROPY_PETALS: Array = [["Petal01", "Petal02"], ["Petal03"], ["Petal04"], ["Petal05", "Petal06"], ["Petal07"], ["Petal08"],
	["Petal09", "Petal10"], ["Petal11"], ["Petal12"], ["Petal13", "Petal14"]]

static func _aperture(m: Node3D, close: float) -> void:
	## Every petal folds in over the iris about its ring tangent: 1 is shut, below 0 flared open.
	## Laid under whatever else turns the petals, so each keeps to its hinge.
	if absf(close) < 0.0001:
		return
	for k in range(ENTROPY_PETALS.size()):
		var parts: Array = m._select(ENTROPY_PETALS[k])
		if parts.is_empty():
			continue
		var a: float = 0.2 + float(k) * deg_to_rad(36.0)
		_inner_turn(m, parts, (parts[0] as Node3D).get("_rest").origin, Vector3(-sin(a), cos(a), 0.0), deg_to_rad(-95.0) * close)

static func _blink_shape(x: float) -> float:
	if x <= 0.0 or x >= 0.3:
		return 0.0
	return smoothstep(0.0, 0.07, x) * (1.0 - smoothstep(0.12, 0.3, x))

static func _idle_entropy(m: Node3D, clock: float, weight: float) -> void:
	## Its aperture breathing a little open and shut, the pupil widening as it opens; now and then
	## the petals snap shut for a blink (sometimes twice). The whole eye hovers and turns after
	## where its eye looks.
	var breath: float = 0.5 - 0.5 * cos(clock * 0.85)
	var every: float = 5.2
	var step: int = int(floor(clock / every))
	var local: float = clock - float(step) * every - every * (0.15 + 0.3 * (1.0 + float(m._noise(step * 3 + int(m.noise_seed) + 11))))
	var blink: float = _blink_shape(local)
	if float(m._noise(step * 7 + int(m.noise_seed) + 2)) > 0.3:
		blink = maxf(blink, _blink_shape(local - 0.42))
	_aperture(m, lerpf(0.04 + 0.16 * breath, 1.0, blink) * weight)
	var pupil: Dictionary = m.group("pupil")
	_inner_swell(m, pupil.parts, pupil.joint, Vector3.ONE * (1.0 + (0.1 - 0.25 * breath) * weight))
	_look_body(m, 7.0, 4.0, 2.8, 0.45, 1.4, weight, Vector3(0, 1.35, 0))
	_hover_body(m, clock, weight, 0.06, 1.15, 2.5, 0.0, Vector3(0, 1.35, 0))

static func _entropy_focus(m: Node3D, clip: Dictionary, _delta: float) -> void:
	_aperture(m, 0.25 * float(m._v(clip, "f", _t(clip))))

static func _entropy_squint(m: Node3D, clip: Dictionary, _delta: float) -> void:
	_aperture(m, float(m.value(SQUINT, _t(clip))) * float(clip.get("weight", 1.0)))

static func _entropy_unfurl(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its petals flared wide open, the shards round it drifting out.
	var f: float = float(m._v(clip, "f", _t(clip)))
	_aperture(m, -0.25 * f)
	_push_out(m, m.group("shards").parts, Vector3(0, 1.35, 0), 0.3 * f)

static func _entropy_gaze(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Opened wide as it draws back, narrowed to focus as it pours its beam out.
	var v: float = float(m._v(clip, "breath", _t(clip)))
	_aperture(m, 0.3 * v if v < 0.0 else 0.4 * v)

static func _entropy_stare(m: Node3D, clip: Dictionary, _delta: float) -> void:
	var t: float = _t(clip)
	_aperture(m, 0.45 * smoothstep(0.0, HIT, t) * (1.0 - smoothstep(0.7, 1.05, t)) * float(clip.get("weight", 1.0)))

static func _entropy_unmake(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The aperture opens a little as it draws back, snaps shut on the blow and opens again.
	var t: float = _t(clip)
	var close: float = smoothstep(HIT - 0.08, HIT, t) * (1.0 - smoothstep(0.55, 1.0, t)) - 0.25 * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.2, HIT, t))
	_aperture(m, close * float(clip.get("weight", 1.0)))

# --- the Null Shade -----------------------------------------------------------------------------

static func _idle_shade(m: Node3D, clock: float, weight: float) -> void:
	## Drifting: it bobs over its rings and turns slowly one way and the other.
	_hover_body(m, clock, weight, 0.07, 0.8, 3.0, 0.0, Vector3(0, 1.1, 0))
	_lay_body(m, _about(_body_point(m, Vector3(0, 1.1, 0)), Basis(Vector3.UP, deg_to_rad(9.0) * sin(clock * 0.23) * weight)))

# --- the Rift Shifter: its ribbon ---------------------------------------------------------------

static func _shifter_lay(m: Node3D, angles: Array, outs: Array, lifts: Array, squash: float = 0.0) -> void:
	## Each slab of the ribbon (foot to top) squashed flat by `squash`, pushed out from the seam by
	## its `outs`, lifted by its `lifts` and turned round the seam by its `angles`.
	var slabs: Array = m.group("ribbon").parts
	for k in range(mini(slabs.size(), angles.size())):
		var part: Node3D = slabs[k]
		var at: Vector3 = _now(part)
		if absf(squash) > 0.0001:
			m.swell([part], at, Vector3(1.0, 1.0 - squash, 1.0))
		var out: float = float(outs[k])
		var level := Vector3(at.x, 0.0, at.z)
		if absf(out) > 0.00001 and level.length() > 0.001:
			m.shift([part], level.normalized() * out)
		if absf(float(lifts[k])) > 0.00001:
			m.shift([part], Vector3(0, float(lifts[k]), 0))
		m.turn([part], Vector3.ZERO, Vector3.UP, float(angles[k]))

static func _idle_shifter(m: Node3D, clock: float, weight: float) -> void:
	## A slow twist up the ribbon, winding the coil tighter and looser, with a ripple running out
	## and in along it from the foot; the capstone head turns with the top of it.
	var angles: Array = []
	var outs: Array = []
	var lifts: Array = []
	var wind: float = sin(clock * 0.75)
	for k in range(9):
		var along: float = float(k) / 8.0
		angles.append(deg_to_rad(16.0) * wind * along * weight)
		outs.append(0.035 * sin(clock * 1.1 - float(k) * 0.7) * weight)
		lifts.append(0.025 * sin(clock * 0.9 - float(k) * 0.6) * weight)
	_shifter_lay(m, angles, outs, lifts)
	var head: Dictionary = m.group("head")
	m.turn(head.parts, head.joint, Vector3.UP, float(angles[8]) * 0.6)

static func _shifter_coil(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Wound tight round the seam (the top turned furthest, every slab drawn in), held, and sprung
	## loose past where it rests, its slabs flung out a little as it unwinds.
	var v: float = float(m.value(COIL, _t(clip))) * float(clip.get("weight", 1.0))
	var angles: Array = []
	var outs: Array = []
	var lifts: Array = []
	for k in range(9):
		var along: float = float(k) / 8.0
		angles.append(deg_to_rad(70.0) * v * pow(along, 1.3))
		outs.append((-0.08 * v if v > 0.0 else 0.12 * -v) * along)
		lifts.append(0.0)
	_shifter_lay(m, angles, outs, lifts)
	var head: Dictionary = m.group("head")
	m.turn(head.parts, head.joint, Vector3.UP, float(angles[8]))

static func _shifter_fan(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Each slab fanned out from the seam and back, one after another up the ribbon.
	var t: float = _t(clip)
	var w: float = float(clip.get("weight", 1.0))
	var angles: Array = []
	var outs: Array = []
	var lifts: Array = []
	for k in range(9):
		var v: float = float(m.value(FAN, t - 0.1 * float(k))) * w
		angles.append(0.0)
		outs.append(0.2 * v)
		lifts.append(0.04 * v)
	_shifter_lay(m, angles, outs, lifts)

static func _shifter_fold(m: Node3D, clip: Dictionary, _delta: float) -> void:
	_shifter_flat(m, float(m._v(clip, "hold", _t(clip))), 0.24, 0.45)

static func _shifter_flicker(m: Node3D, clip: Dictionary, _delta: float) -> void:
	_shifter_flat(m, float(m._v(clip, "f", _t(clip))), 0.2, 0.4)

static func _shifter_flat(m: Node3D, v: float, inward: float, squash: float) -> void:
	## Folded in on itself: every slab pressed flat and tight to the seam, drawn toward its middle
	## and wound a little.
	if absf(v) < 0.0001:
		return
	var slabs: Array = m.group("ribbon").parts
	var angles: Array = []
	var outs: Array = []
	var lifts: Array = []
	for k in range(9):
		var along: float = float(k) / 8.0
		var y: float = (slabs[k] as Node3D).get("_rest").origin.y if k < slabs.size() else 1.2
		angles.append(0.6 * v * along)
		outs.append(-inward * v)
		lifts.append((1.2 - y) * 0.35 * v)
	_shifter_lay(m, angles, outs, lifts, squash * v)

static func _shifter_lash(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Coiled back tight as it winds (the top furthest), whipped forward through the blow with the
	## top slabs flung out wide.
	var v: float = float(m._v(clip, "attack", _t(clip)))
	var angles: Array = []
	var outs: Array = []
	var lifts: Array = []
	for k in range(9):
		var along: float = float(k) / 8.0
		var a: float = pow(along, 1.4)
		angles.append(deg_to_rad(50.0 * v if v < 0.0 else 40.0 * v) * a)
		outs.append(0.3 * v * along * along if v > 0.0 else 0.06 * v * along)
		lifts.append(0.0)
	_shifter_lay(m, angles, outs, lifts)

static func _shifter_shift(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Two neighbouring slabs at a time trade places (up the ribbon and round it, one passing
	## outside the other), hold there, and trade back.
	var t: float = _t(clip)
	var s: float = smoothstep(0.1, 0.32, t) * (1.0 - smoothstep(0.62, 0.95, t)) * float(clip.get("weight", 1.0))
	if s <= 0.0001:
		return
	var slabs: Array = m.group("ribbon").parts
	for pair in [[0, 1], [2, 3], [4, 5], [6, 7]]:
		if int(pair[1]) >= slabs.size():
			continue
		var a: Node3D = slabs[int(pair[0])]
		var b: Node3D = slabs[int(pair[1])]
		var pa: Vector3 = (a.get("_rest") as Transform3D).origin
		var pb: Vector3 = (b.get("_rest") as Transform3D).origin
		var phi: float = wrapf(atan2(pb.x, pb.z) - atan2(pa.x, pa.z), -PI, PI)
		var arc: float = 0.22 * sin(PI * s)
		_push_out(m, [a], Vector3.ZERO, arc, true)
		m.shift([a], Vector3(0, (pb.y - pa.y) * s, 0))
		m.turn([a], Vector3.ZERO, Vector3.UP, phi * s)
		_push_out(m, [b], Vector3.ZERO, -arc * 0.6, true)
		m.shift([b], Vector3(0, (pa.y - pb.y) * s, 0))
		m.turn([b], Vector3.ZERO, Vector3.UP, -phi * s)

# --- the Infinite Void --------------------------------------------------------------------------

const UNMADE_HUB := Vector3(0, 2.5, 0)
## What drifts out of its whirl and snaps back: the rubble at the ends of its arms, the debris
## high round it, the top of its funnel.
const UNMADE_DRIFTERS: Array = ["Arm09", "Arm10", "Arm11", "Arm12", "Arm21", "Arm22", "Arm23", "Arm24", "Orbit01", "Orbit02", "Orbit03", "Orbit04",
	"Funnel30", "Funnel33", "Funnel36", "Funnel39"]
## Its funnel's five rings, bottom to top, and their radii.
const UNMADE_FUNNEL: Array = [["f0", 0.38], ["f1", 0.6], ["f2", 0.84], ["f3", 1.08], ["f4", 1.32]]

static func _unmade_freeze(m: Node3D, held: float) -> void:
	## Everything that turns in it held still for `held` seconds of its turning: the arms' spin
	## (creature_part.gd, 2.4 a second) and every orbit (the funnel, its light, the hoop, the
	## debris: 0.7) wound back by as much.
	if absf(held) < 0.00001:
		return
	m.spin(m.group("arms").parts, -2.4 * held)
	m.turn(m.group("orbiters").parts, Vector3.ZERO, Vector3.UP, -0.7 * held)

static func _idle_unmade(m: Node3D, clock: float, weight: float) -> void:
	## Wrong motion. Light drawn up the middle of the funnel into its heart, going out there and
	## coming up again from the floor; the funnel breathing out and in ring by ring up it; now and
	## then a piece drifting out of the whirl and snapping back; its heart swelling slowly; and
	## every so often the whole maelstrom stopping dead for a moment and lurching on.
	if weight <= 0.0001:
		return
	var lights: Array = m.group("lights").parts
	for i in range(lights.size()):
		var part: Node3D = lights[i]
		var q: float = fposmod(clock * 0.28 + float(i) * 0.25, 1.0)
		var s: float = smoothstep(0.0, 0.15, q) * (1.0 - smoothstep(0.7, 1.0, q))
		var at: Vector3 = _now(part)
		m.swell([part], at, Vector3.ONE * lerpf(1.0, maxf(0.001, s), weight))
		m.shift([part], Vector3(-at.x * 0.7 * q, 1.35 * q, -at.z * 0.7 * q) * weight)
	for level in range(UNMADE_FUNNEL.size()):
		var ring: Array = m.group(str(UNMADE_FUNNEL[level][0])).parts
		_push_out(m, ring, Vector3(0, 0, 0), float(UNMADE_FUNNEL[level][1]) * 0.07 * sin(clock * 1.2 - float(level) * 0.9) * weight, true)
	for channel in range(2):
		var beat: float = 2.3 if channel == 0 else 3.1
		var c: float = clock + float(channel) * 1.13
		var step: int = int(floor(c / beat))
		var local: float = c - float(step) * beat - 0.3
		if local <= 0.0 or local >= 1.6:
			continue
		var pick: int = int(absf(float(m._noise(step * 17 + int(m.noise_seed) + channel * 5))) * 997.0) % UNMADE_DRIFTERS.size()
		var k: float = smoothstep(0.0, 1.25, local) * (1.0 - smoothstep(1.5, 1.58, local)) * weight
		for part in m._select(UNMADE_DRIFTERS[pick]):
			var at: Vector3 = _now(part)
			m.turn([part], at, Vector3(0.3, 1.0, 0.2).normalized(), 0.9 * k)
			m.shift([part], ((at - UNMADE_HUB).normalized() * 0.34 + Vector3(0, 0.06, 0)) * k)
	var heart: Dictionary = m.group("heart")
	m.swell(heart.parts, UNMADE_HUB, Vector3.ONE * (1.0 + 0.035 * sin(clock * 0.6) * weight))
	## The stutter: on most beats, at a time of its own, everything stops dead for a moment and
	## lurches back to where it would have been; the heart shudders as it does.
	var every: float = 1.9
	var n: int = int(floor(clock / every))
	var at_beat: float = clock - float(n) * every - every * (0.1 + 0.2 * (1.0 + float(m._noise(n * 7 + int(m.noise_seed) + 31))))
	if float(m._noise(n * 11 + int(m.noise_seed) + 5)) > -0.3 and at_beat > 0.0:
		var freeze: float = 0.16 + 0.12 * (0.5 + 0.5 * float(m._noise(n * 13 + int(m.noise_seed) + 7)))
		var back: float = smoothstep(freeze, freeze + 0.18, at_beat)
		var held: float = minf(at_beat, freeze) * (1.0 - back) * weight
		if held > 0.0:
			_unmade_freeze(m, held)
			var shudder: float = 0.035 * sin(at_beat * 47.0) * (1.0 - back) * weight
			m.swell(heart.parts, UNMADE_HUB, Vector3.ONE * (1.0 + shudder))

static func _unmade_halt(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Stopped dead: its whirl, its funnel and its light held where they were, then let go with a
	## lurch to where they would have been.
	var t: float = _t(clip)
	var held: float = clampf(t - 0.04, 0.0, 0.66) * (1.0 - smoothstep(0.72, 0.9, t)) * float(clip.get("weight", 1.0))
	_unmade_freeze(m, held)

static func _unmade_unravel(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Pieces of its whirl drift out of it one after another, slowly turning over, hang there, and
	## snap back in all at once.
	var t: float = _t(clip)
	var w: float = float(clip.get("weight", 1.0))
	var index: int = 0
	for name in UNMADE_DRIFTERS:
		for part in m._select(name):
			var start: float = 0.05 + 0.12 * float(index % 5)
			var k: float = smoothstep(start, 1.55, t) * (1.0 - smoothstep(2.15, 2.24, t)) * w
			if k > 0.0001:
				var at: Vector3 = _now(part)
				m.turn([part], at, Vector3(cos(float(index)), 0.6, sin(float(index))).normalized(), 1.1 * k)
				m.shift([part], ((at - UNMADE_HUB).normalized() * (0.42 + 0.12 * float(index % 3)) + Vector3(0, 0.08, 0)) * k)
			index += 1

static func _unmade_glitch(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Jumping between poses as though frames of it went missing: on most twelfths of a second its
	## whirl stands a little turned or thrown aside, its funnel knocked out of line.
	var t: float = _t(clip)
	var f: float = float(m._v(clip, "f", t))
	if f <= 0.001:
		return
	var n: int = int(floor(t / 0.075))
	var salt: int = int(m.noise_seed)
	if float(m._noise(n * 19 + salt + 3)) < -0.15:
		return
	var disc: Dictionary = m.group("disc")
	var a := Vector3(float(m._noise(n * 3 + salt + 1)), float(m._noise(n * 5 + salt + 2)), float(m._noise(n * 7 + salt + 3)))
	if a.length() > 0.01:
		m.turn(disc.parts, disc.joint, a.normalized(), deg_to_rad(7.0) * f * minf(1.0, a.length()))
	m.shift(disc.parts, Vector3(float(m._noise(n * 11 + salt + 4)), 0.5 * float(m._noise(n * 13 + salt + 5)), float(m._noise(n * 17 + salt + 6))) * 0.09 * f)
	m.shift(m.group("funnel").parts, Vector3(float(m._noise(n * 23 + salt + 7)), 0.0, float(m._noise(n * 29 + salt + 8))) * 0.07 * f)

static func _unmade_tear(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## The stones by its funnel torn up off the floor one after another, drawn up round it into
	## its heart and gone; new ones swell up out of the floor where they lay.
	var t: float = _t(clip)
	var w: float = float(clip.get("weight", 1.0))
	var length: float = float(clip.get("length", 3.6))
	var stones: Array = m.group("stones").parts
	for i in range(stones.size()):
		var part: Node3D = stones[i]
		var at: Vector3 = _now(part)
		var q: float = clampf((t - 0.3 - 0.25 * float(i)) / 1.5, 0.0, 1.0)
		if q <= 0.0:
			continue
		if q < 1.0:
			var e: float = q * q * (3.0 - 2.0 * q)
			var to: Vector3 = at.lerp(UNMADE_HUB, e).rotated(Vector3.UP, e * 3.5)
			m.swell([part], at, Vector3.ONE * lerpf(1.0, maxf(0.001, 1.0 - smoothstep(0.55, 1.0, q)), w))
			m.turn([part], at, Vector3(1.0, 0.3, 0.5).normalized(), e * 5.0 * w)
			m.shift([part], (to - at) * w)
		else:
			var regrow: float = smoothstep(length - 1.0, length - 0.25, t)
			m.swell([part], at, Vector3.ONE * lerpf(1.0, maxf(0.001, regrow), w))

# --- the Hush: its body -------------------------------------------------------------------------

static func _hush_chain(m: Node3D) -> Array:
	## Its body stone by stone from the neck to the tail, each of its three rings carried whole by
	## the stone it sits round (found by the ring's middle, so a ring never comes apart).
	if m._groups.has("__hush_chain"):
		return m._groups["__hush_chain"].chain
	var chain: Array = []
	for segment in m.group("body").chain:
		chain.append({"parts": (segment.parts as Array).duplicate(), "joint": segment.joint})
	for run in ["Ring01-08", "Ring09-16", "Ring17-24"]:
		var ring: Array = m._select(run)
		if ring.is_empty() or chain.is_empty():
			continue
		var at: Vector3 = (ring[0] as Node3D).get("_rest").origin
		var best: int = 0
		var near: float = INF
		for index in range(chain.size()):
			var d: float = m.centre_of(chain[index].parts[0]).distance_to(at)
			if d < near:
				near = d
				best = index
		chain[best].parts.append_array(ring)
	m._groups["__hush_chain"] = {"parts": [], "joint": Vector3.ZERO, "chain": chain}
	return chain

static func _idle_hush(m: Node3D, clock: float, weight: float) -> void:
	## A swimming wave running down its body from the head, growing toward the tail, as it glides
	## and bobs.
	var chain: Array = _hush_chain(m)
	var angles: Array = []
	for index in range(chain.size()):
		var along: float = float(index) / float(maxi(1, chain.size() - 1))
		angles.append(deg_to_rad(2.4 + 1.0 * along) * sin(clock * 2.0 - float(index) * 0.45) * weight)
	m.chain_turns(chain, Vector3.UP, angles)
	_hover_body(m, clock, weight, 0.05, 0.7, 2.0, 0.0, Vector3(0, 0.85, 0.1))

static func _hush_glide(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## A bigger swimming wave down its body, its head leading it side to side.
	var t: float = _t(clip)
	var f: float = float(m._v(clip, "f", t))
	var chain: Array = _hush_chain(m)
	## Each stone swung side to side and dipped a little after it, in one turn about its joint
	## (two passes down the chain would turn the second about joints the first had moved).
	for index in range(chain.size() - 1, -1, -1):
		var along: float = float(index) / float(maxi(1, chain.size() - 1))
		var wave: float = t * 2.6 - float(index) * 0.4
		var turned := Basis(Vector3.UP, deg_to_rad(8.0 * (0.6 + 0.4 * along)) * sin(wave) * f) * Basis(Vector3.RIGHT, deg_to_rad(3.0) * sin(wave - 1.2) * f)
		var carried: Array = []
		for later in range(index, chain.size()):
			carried.append_array(chain[later].parts)
		var about: Transform3D = _about(chain[index].joint, turned)
		for part in carried:
			m._offsets[part] = about * (m._offsets.get(part, Transform3D.IDENTITY) as Transform3D)
	var head: Dictionary = m.group("head")
	m.turn(head.parts, head.joint, Vector3.UP, deg_to_rad(18.0) * sin(t * 2.6 + 0.6) * f)

static func _hush_rings(m: Node3D, amounts: Array) -> void:
	## Its three rings closed in tight round its body, each by its own amount (1 is a third smaller).
	var index: int = 0
	for run in ["Ring01-08", "Ring09-16", "Ring17-24"]:
		var ring: Array = m._select(run)
		var k: float = float(amounts[index]) if index < amounts.size() else 0.0
		index += 1
		if ring.is_empty() or absf(k) < 0.0001:
			continue
		_inner_swell(m, ring, (ring[0] as Node3D).get("_rest").origin, Vector3.ONE * (1.0 - 0.3 * k))

static func _hush_mute(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its rings tightening one after another, head to tail, and loosening again.
	var t: float = _t(clip)
	var w: float = float(clip.get("weight", 1.0))
	var amounts: Array = []
	for index in range(3):
		var start: float = 0.35 + 0.3 * float(2 - index)
		amounts.append(smoothstep(start, start + 0.3, t) * (1.0 - smoothstep(2.2 + 0.15 * float(2 - index), 2.75, t)) * w)
	_hush_rings(m, amounts)

static func _hush_close(m: Node3D, clip: Dictionary, _delta: float) -> void:
	var k: float = float(m._v(clip, "hold", _t(clip))) * 0.85
	_hush_rings(m, [k, k, k])

# --- the Star Leech -----------------------------------------------------------------------------

static func _idle_leech(m: Node3D, clock: float, weight: float) -> void:
	## Inching: a slow swell running up its coil from its tail to its neck, stone by stone.
	if weight <= 0.0001:
		return
	var body: Array = m.group("body").parts
	var count: int = body.size()
	for index in range(count):
		var along: float = float(index) / float(maxi(1, count - 1))
		var bump: float = pow(maxf(0.0, sin(clock * 1.5 - along * TAU * 1.5)), 3.0) * weight
		if bump < 0.002:
			continue
		var part: Node3D = body[index]
		m.swell([part], m.centre_of(part), Vector3.ONE * (1.0 + 0.1 * bump))

# --- the Timeglass ------------------------------------------------------------------------------

static func _idle_timeglass(m: Node3D, clock: float, weight: float) -> void:
	## Tick, tock: every second the glass snaps a little one way, then the other, the grains over it
	## hop and the light in its neck flashes; and its sand trickles, the top draining slowly into
	## the bottom and (time being what it is here) slowly back.
	if weight <= 0.0001:
		return
	var trickle: float = 0.5 - 0.5 * cos(clock * 0.4)
	var top: Dictionary = m.group("top_sand")
	var low: Dictionary = m.group("low_sand")
	m.swell(top.parts, top.joint, Vector3(1.0 - 0.06 * trickle * weight, 1.0 - 0.22 * trickle * weight, 1.0 - 0.06 * trickle * weight))
	m.swell(low.parts, low.joint, Vector3(1.0 + 0.04 * trickle * weight, 1.0 + 0.25 * trickle * weight, 1.0 + 0.04 * trickle * weight))
	var step: int = int(floor(clock))
	var local: float = clock - float(step)
	var side: float = 1.0 if posmod(step, 2) == 0 else -1.0
	var snap: float = smoothstep(0.0, 0.06, local)
	var wobble: float = sin(local * 40.0) * exp(-local * 9.0) * 0.25
	var neck: Dictionary = m.group("neck")
	m.swell(neck.parts, neck.joint, Vector3.ONE * (1.0 + 0.35 * sin(PI * clampf(local / 0.2, 0.0, 1.0)) * weight))
	var glass: Dictionary = m.group("glass")
	m.turn(glass.parts, glass.joint, Vector3.UP, deg_to_rad(2.2) * side * (2.0 * snap - 1.0 + wobble) * weight)
	m.shift(m.group("grains").parts, Vector3(0, 0.03 * sin(PI * clampf(local / 0.25, 0.0, 1.0)) * weight, 0))

static func _timeglass_turn(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Turns itself over, all the way round: time run back.
	var t: float = float(clip.t)
	var spin: float = smoothstep(0.05, 0.75, t)
	var body: Dictionary = m.group("glass")
	m.turn(body.parts, body.joint, Vector3.RIGHT, TAU * spin)
	if t >= HIT:
		m._queue(clip, "spiral", "spiral", {"from": "Sand03", "color": "#ffe8a0", "amount": 30})

# --- the Paradox Moth ---------------------------------------------------------------------------

static func _idle_moth(m: Node3D, clock: float, weight: float) -> void:
	## Hovering: it bobs and tilts in the air, drifting round a little one way and the other.
	_hover_body(m, clock, weight, 0.07, 1.5, 4.0, 0.0, Vector3(0, 1.0, 0))
	_lay_body(m, _about(_body_point(m, Vector3(0, 1.0, 0)), Basis(Vector3.UP, deg_to_rad(7.0) * sin(clock * 0.31) * weight)))

static func _moth_still(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its real wings held still: each one's own beat (creature_part.gd's `wing`, this frame's)
	## undone under everything else, as far as the fidget is in.
	var k: float = float(m._v(clip, "f", _t(clip)))
	if k <= 0.0001:
		return
	var clock: float = float(m._creature.get("_clock"))
	for part in m.group("wings").parts:
		var beat: float = sin(clock * 11.0 + float(part.get("phase"))) * 0.55 * float(part.get("wing_side"))
		var pose: Transform3D = (part as Node3D).transform
		var undo: Transform3D = pose * Transform3D(Basis(Vector3.BACK, -beat * k), Vector3.ZERO) * pose.affine_inverse()
		m._offsets[part] = (m._offsets.get(part, Transform3D.IDENTITY) as Transform3D) * undo

static func _moth_unravel(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Its ghost wings drawn away from it, down and out to either side, wavering.
	var t: float = _t(clip)
	var v: float = float(m._v(clip, "hold", t))
	if v <= 0.0001:
		return
	var waver: float = 0.02 * sin(t * 13.0)
	m.shift(m.group("ghost_l").parts, Vector3(0.12 + waver, -0.08, -0.04) * v)
	m.shift(m.group("ghost_r").parts, Vector3(-0.12 - waver, -0.08 + waver, -0.04) * v)

# --- the Collapsar ------------------------------------------------------------------------------

static func _idle_collapsar(m: Node3D, clock: float, weight: float) -> void:
	## Falling in: each splinter drawn toward the knot and let out again on a beat of its own.
	if weight <= 0.0001:
		return
	var orbit: Dictionary = m.group("orbit")
	for i in range(orbit.parts.size()):
		var part: Node3D = orbit.parts[i]
		var k: float = (0.5 - 0.5 * cos(clock * 0.8 + float(i) * 1.9)) * weight
		m.shift([part], -(_now(part) - (orbit.joint as Vector3)) * 0.22 * k)

# --- the Riftling Swarm -------------------------------------------------------------------------

static func _swarm_jitter(m: Node3D, clock: float, amount: float, tumble: float) -> void:
	## Every shard buzzing on its own: a fast jitter and a tumble about where it is.
	if amount <= 0.00001 and tumble <= 0.00001:
		return
	var parts: Array = m.group("swarm").parts
	for i in range(parts.size()):
		var part: Node3D = parts[i]
		var c: float = clock + float(i) * 0.37
		var at: Vector3 = _now(part)
		m.turn([part], at, Vector3(sin(float(i) * 1.7), 1.0, cos(float(i) * 2.3)).normalized(), tumble * sin(c * 9.0 + float(i)))
		m.shift([part], Vector3(sin(c * 31.0), sin(c * 27.0 + 1.3), sin(c * 35.0 + 2.1)) * amount)

static func _idle_swarm(m: Node3D, clock: float, weight: float) -> void:
	## Buzzing: every shard jittering and tumbling on its own, the cloud breathing in and out ring by
	## ring, the whole of it drifting about.
	if weight <= 0.0001:
		return
	_swarm_jitter(m, clock, 0.016 * weight, 0.35 * weight)
	var centre: Vector3 = m.group("swarm").joint
	for ring in range(3):
		_push_out(m, m.group(str(["ring_a", "ring_b", "ring_c"][ring])).parts, centre, 0.06 * sin(clock * 1.3 + float(ring) * 2.1) * weight, true)
	_hover_body(m, clock, weight, 0.07, 0.9, 0.0, 0.0, Vector3(0, 1.0, 0))
	_lay_body(m, Transform3D(Basis.IDENTITY, Vector3(0.07 * sin(clock * 0.37), 0.0, 0.04 * sin(clock * 0.29 + 1.0)) * weight))

static func _swarm_scatter(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Startled: every shard thrown out from the core at once, and drifting back.
	var k: float = float(m.value(SCATTER, _t(clip))) * float(clip.get("weight", 1.0))
	_push_out(m, m.group("swarm").parts, m.group("swarm").joint, 0.45 * k)

static func _swarm_stream(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Off to one side in a stream, one shard after another along the same arc, and back.
	var t: float = _t(clip)
	var length: float = float(clip.get("length", 3.0))
	var w: float = float(clip.get("weight", 1.0))
	var parts: Array = m.group("swarm").parts
	var lag: float = 0.04
	var span: float = length - lag * float(parts.size())
	for i in range(parts.size()):
		var local: float = clampf((t - lag * float(i)) / span, 0.0, 1.0) * length
		var v: float = float(m.value(clip.get("f", []), local)) * w
		if absf(v) > 0.0001:
			m.shift([parts[i]], Vector3(0.5 * v, 0.12 * sin(PI * v), 0.12 * v))

static func _swarm_dart(m: Node3D, clip: Dictionary, _delta: float) -> void:
	## Darting at the party, the shards nearest it first and the far ones after.
	var t: float = _t(clip)
	var w: float = float(clip.get("weight", 1.0))
	for part in m.group("swarm").parts:
		var at: Vector3 = _now(part)
		var lag: float = 0.1 * clampf(1.0 - (at.z + 0.9) / 1.8, 0.0, 1.0)
		var v: float = float(m.value("attack", t - lag))
		var by: Vector3 = Vector3(0, -0.05, 0.6) * v if v > 0.0 else Vector3(0, 0.04, -0.12) * -v
		m.shift([part], by * w)

static func _swarm_crackle(m: Node3D, clip: Dictionary, _delta: float) -> void:
	var v: float = float(m._v(clip, "hold", _t(clip)))
	_swarm_jitter(m, float(clip.t), 0.05 * v, 0.9 * v)
