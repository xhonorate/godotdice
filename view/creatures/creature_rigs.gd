extends RefCounted
## What every creature does with its named parts (creature_moves.gd plays it): its groups (the
## parts that move together and the joint they turn about), the moves it acts out and the idle
## that suits it. Part names and joints are the bake's (build/options/PART_ROLES.md): creature
## space, y up, the creature facing +z (the party), its own left +x. A turn about +x tips a part
## that reaches toward the party down; -x lifts it. +z raises a part on its left, -z on its right.
##
## A move is a list of gestures, laid on leaf first (a jaw before the head that carries it):
##   ["turn", group, axis, wind deg, strike deg, envelope]   about the group's joint
##   ["turn_each", group, axis, wind deg, strike deg, envelope]   each part about its own pivot
##   ["splay", group, wind deg, strike deg, envelope]   each part out from the group's joint
##   ["move", group, wind offset, strike offset, envelope]
##   ["grow", group, wind, strike, envelope]   a swell about the joint (float or Vector3)
##   ["each", group, wind, strike, envelope]   each part swelling about its own pivot
##   ["curl", chain, axis or "across", wind deg, strike deg, envelope, falloff]
##   ["spin", group, whole turns, envelope]   about each part's own axle, faster where the envelope is
##   ["whirl", group, axis, whole turns, envelope]   the group about its joint, the same way
##   ["spread", group, wind, strike, envelope]   each part pushed out from the joint, level
##   ["rear", amount, envelope]   the whole creature rearing back and lunging (the old lunge)
##   ["lean", axis, wind deg, strike deg, pivot, envelope]   the whole body
##   ["hop", wind offset, strike offset, envelope]   the whole body
##   ["show", group, from s, to s]   parts hidden at rest, shown for a while
##   ["fx", time s, effect, {from, color, kind, size, ...}]   see creature_moves.gd `_fire`
##   ["call", function]   a function run every frame of the move (the mine file's, given `m`)
##   ["gaze", group, yaw deg, pitch deg, envelope, looks]   look about at `looks` places picked
##       on the creature's own random clock, easing from one to the next
##   ["tremble", group, amount, envelope]   a fine shiver
##   ["swim", {body, bell, trail, pulses, beat, rise, sink, squeeze, flare, lag, ripple, start}]
##       a jellyfish swimming up in `pulses` strong pulses and sinking slowly back
## An envelope is a name from ENV or a list of [time, value] keys: -1 wound back (the wind
## angle), +1 the blow (the strike angle), 0 at rest. The blow lands at HIT, 0.3 s in, when the
## screen applies the move. In a fidget "f" is the fidget's own envelope (eases in, holds,
## eases out over its length) and an oscillation (flutter, shake, pant, wag...) lasts the whole
## fidget; in a heavy blow's `pose` "h" is its hold (1 while it strains, 0 once it lets go).
## A move may be a String instead: a function in its mine's file that plays it whole.
##
## IDLE GESTURES (`idle_gestures`, laid on every frame, eased out under a move):
##   ["sway", group, axis, deg, rate, phase]      a turn back and forth
##   ["bob", group, offset, rate, phase]          a move up and down (or along `offset`)
##   ["curl", chain, axis or "across", deg, rate, phase, falloff]   a chain bending both ways
##   ["sway_each", group, axis, deg, rate, phase step]   each part, a beat behind the last
##   ["breathe", group, swell, rate, phase]       a slow chest (or bell) swell, never below rest
##   ["look", group, yaw deg, pitch deg, beat s, ease s]   a head easing to a new place to look
##       every beat or so and holding there (noise driven, its own per creature)
##   ["blink", group, shut, every s, phase]       eyes shut for an instant now and then; `shut`
##       is the scale they close to (Vector3(1, 0.1, 1)) or [axis, deg] for a lid
##   ["flex", group, axis, deg, every s, phase]   claws opening slowly and snapping shut
##   ["pant", group, axis, deg, rate]             a jaw working fast, open and shut
##   ["hover", group, height, rate, tilt deg, phase]   bobbing in the air, tilting a beat behind
##   ["tremble", group, amount, rate]             a constant fine shiver
##   ["slither", chain, axis, deg, rate, wavelength, falloff]   a wave travelling down a chain
##   ["wag", chain or group, axis, deg, rate, wavelength, falloff]   a tail wagging
##   ["coil", chain, axis or "across", deg, rate, phase, falloff]   curling in and out, one way
##   ["swim", {body, bell, trail, rate, rise, squeeze, flare, lag, ripple, phase}]   a jellyfish:
##       the bell squeezes as the body thrusts up, drifts down slowly, the trail lagging behind
##       and flaring out on the recovery
##
## FIDGETS: the intermittent things it does while it waits (looks about, stretches, preens),
## each played on the creature's own random clock, only while it is fully idle:
##   "fidgets": {name: {"do": [gestures, as a move], "length": s, "hold": s, "weight": w, "idle": k}}
##   "fidget_every": [min s, max s]   how long it waits between them
## `weight` is how often it is picked (1), `idle` how much of its idle goes on under it (1),
## `hold` how long the "f" envelope holds at full (40% of the length).
##
## HEAVY BLOWS (sim/creatures.gd `heavy_moves`): any move the sim marks heavy is held at its
## wind pose for DeepCreatures.HEAVY_HOLD more, shivering and charging, and lands past its
## strike pose with a hit-stop. A rig may write its own heavy version of a move:
##   "heavy": {move or anim: {"at": point, "wind": s, "pose": [gestures on "h"],
##       "charge": [[effect, {spec}], ...], "impact": [[effect, {spec}], ...], "do": [gestures]}}
## `at` is where the charge gathers (the blow's own effect source otherwise), `wind` the keyed
## time it holds at (where it is wound furthest otherwise), `pose` laid on while it strains,
## `charge` replaces the glow and dust at the hold, `impact` fires as it lands, `do` replaces
## the move outright for its heavy version.

const HIT: float = 0.3
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

const ENV: Dictionary = {
	"attack": [[0.0, 0.0], [0.22, -1.0], [0.3, 1.0], [0.42, 1.0], [0.95, 0.0]],
	"big": [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.5, 1.0], [1.15, 0.0]],
	"second": [[0.0, 0.0], [0.12, 0.0], [0.34, -1.0], [0.42, 1.0], [0.54, 1.0], [1.05, 0.0]],
	"quick": [[0.0, 0.0], [0.12, 0.0], [0.24, -1.0], [0.3, 1.0], [0.4, 1.0], [0.8, 0.0]],
	"snap": [[0.0, 0.0], [0.23, -1.0], [0.29, 1.0], [0.36, 1.0], [0.6, 0.0]],
	"snap2": [[0.0, 0.0], [0.23, -1.0], [0.29, 1.0], [0.34, 1.0], [0.48, -0.8], [0.56, 1.0], [0.62, 1.0], [0.9, 0.0]],
	"lift": [[0.0, 0.0], [0.3, 1.0], [0.45, 1.0], [0.95, 0.0]],
	"early": [[0.0, 0.0], [0.2, 1.0], [0.45, 1.0], [0.95, 0.0]],
	"throw": [[0.0, 0.0], [0.12, -1.0], [0.18, 1.0], [0.4, 1.0], [0.95, 0.0]],
	"twice": [[0.0, 0.0], [0.22, -1.0], [0.3, 1.0], [0.36, 1.0], [0.46, -0.8], [0.54, 1.0], [0.6, 1.0], [1.05, 0.0]],
	"thrice": [[0.0, 0.0], [0.22, -1.0], [0.3, 1.0], [0.34, 1.0], [0.44, -0.8], [0.52, 1.0], [0.56, 1.0], [0.66, -0.8], [0.74, 1.0], [0.8, 1.0], [1.25, 0.0]],
	"hold": [[0.0, 0.0], [0.25, 1.0], [0.85, 1.0], [1.2, 0.0]],
	"late": [[0.0, 0.0], [0.28, 0.0], [0.4, 1.0], [0.6, 1.0], [1.0, 0.0]],
	"pulse": [[0.0, 0.0], [0.22, 0.0], [0.3, 1.0], [0.45, 0.4], [0.85, 0.0]],
	"windup": [[0.0, 0.0], [0.26, 1.0], [0.3, 0.0]],
	"breath": [[0.0, 0.0], [0.2, -1.0], [0.3, 1.0], [0.8, 1.0], [1.15, 0.0]],
	"rise": [[0.0, 0.0], [0.6, 1.0], [0.8, 1.0], [1.2, 0.0]],
	## Fidget building blocks: a jaw chomping twice (+1 open, -1 clamped), teeth bared and held,
	## a quick flick out and back, a nod, wings lifted and settled with two little shuffles.
	"chomp": [[0.0, 0.0], [0.16, 1.0], [0.24, -0.3], [0.34, 0.0], [0.48, 1.0], [0.56, -0.3], [0.75, 0.0]],
	"bare": [[0.0, 0.0], [0.45, 1.0], [1.3, 1.0], [1.7, 0.0]],
	"flick": [[0.0, 0.0], [0.08, 1.0], [0.3, 0.0]],
	"nod": [[0.0, 0.0], [0.3, 1.0], [0.55, -0.35], [0.85, 0.0]],
	"settle": [[0.0, 0.0], [0.35, 1.0], [0.75, 1.0], [1.0, 0.1], [1.1, 0.35], [1.25, 0.0], [1.35, 0.2], [1.5, 0.0]],
	## Oscillations, made in creature_moves.gd `value`: a flutter of wings, a shudder.
	"flutter": "~flutter",
	"shake": "~shake",
	"scrabble": "~scrabble",
	"pant": "~pant",
	"tremble": "~tremble",
	"wag": "~wag",
	"flap": "~flap",
	"chew": "~chew",
}

static func rig(scene_key: String) -> Dictionary:
	return RIGS.get(scene_key, {})

## What any creature does with its whole body when it has nothing of its own for a move (no
## named parts, or a move its rig leaves out): a guard hunkers down, a mend lifts it, a rally
## rears it up (with the effect vocabulary of view/battle/effect_looks.gd laid over each).
const GENERIC: Dictionary = {
	"guard": [["hop", Vector3.ZERO, Vector3(0, -0.07, -0.04), "hold"], ["lean", X, 0.0, -4.0, Vector3.ZERO, "hold"]],
	"mend": [["hop", Vector3.ZERO, Vector3(0, 0.1, 0), "hold"], ["lean", X, 0.0, -5.0, Vector3.ZERO, "hold"]],
	"rally": [["hop", Vector3(0, -0.06, 0), Vector3(0, 0.14, 0), "attack"], ["lean", X, 6.0, -8.0, Vector3.ZERO, "attack"]],
	"bite": [["rear", 0.75, "attack"], ["lean", X, -6.0, 9.0, Vector3.ZERO, "attack"]],
	"peck": [["rear", 0.6, "quick"], ["lean", X, -10.0, 14.0, Vector3.ZERO, "quick"]],
	"drill": [["rear", 0.7, "attack"], ["lean", X, -6.0, 9.0, Vector3.ZERO, "attack"]],
	"claw": [["rear", 0.6, "attack"], ["lean", Z, -8.0, 10.0, Vector3.ZERO, "attack"],
		["fx", 0.29, "swipe", {"about": "centre", "axis": Z, "start": Vector3(-1, 1, 0), "radius": 0.7, "sweep": 110.0}]],
	"lash": [["rear", 0.5, "attack"], ["lean", Y, 18.0, -22.0, Vector3.ZERO, "attack"],
		["fx", 0.29, "swipe", {"about": "centre", "axis": Y, "start": Vector3(1, 0, 0.4), "radius": 0.9, "sweep": 120.0}]],
	"slam": [["hop", Vector3(0, 0.35, -0.12), Vector3(0, -0.05, 0.18), "big"], ["lean", X, -10.0, 8.0, Vector3.ZERO, "big"],
		["fx", 0.3, "shock", {}]],
	"erupt": [["hop", Vector3(0, -0.2, 0), Vector3(0, 0.3, 0.1), "big"], ["fx", 0.3, "shock", {"size": 1.3}]],
	"breath": [["lean", X, -10.0, 6.0, Vector3.ZERO, "breath"], ["rear", 0.2, "attack"],
		["fx", 0.27, "breath", {"kind": "fire", "seconds": 0.5}]],
	"spit": [["lean", X, -12.0, 6.0, Vector3.ZERO, "throw"], ["fx", 0.17, "spit", {"flight": 0.17}]],
	"cast": [["hop", Vector3(0, 0.18, -0.05), Vector3(0, 0.06, 0.08), "attack"],
		["fx", 0.12, "glow", {"from": "centre"}], ["fx", 0.17, "bolt", {"from": "centre", "flight": 0.15}]],
	"mirror": [["hop", Vector3(0, 0.2, 0), Vector3(0, 0.08, 0.05), "attack"],
		["fx", 0.24, "flash_light", {"from": "centre", "color": "#eef2ff", "energy": 5.0}], ["fx", 0.27, "beam", {"from": "centre", "color": "#eef2ff"}]],
	"pull": [["lean", X, 10.0, -8.0, Vector3.ZERO, "hold"], ["fx", 0.05, "spiral", {"from": "centre", "amount": 40}]],
	"sing": [["lean", X, 0.0, -10.0, Vector3.ZERO, "hold"],
		["fx", 0.2, "ripple", {"from": "centre"}], ["fx", 0.35, "ripple", {"from": "centre", "radius": 2.0}]],
	"drink": [["fx", 0.05, "spiral", {"from": "centre"}], ["fx", 0.3, "glow", {"from": "centre"}]],
	"gather": [["hop", Vector3.ZERO, Vector3(0, 0.15, 0), "hold"], ["fx", 0.05, "spiral", {"from": "centre", "color": "#fff2c0"}]],
	"spores": [["hop", Vector3(0, -0.08, 0), Vector3(0, 0.05, 0), "throw"], ["fx", 0.2, "puff", {"from": "centre", "amount": 24, "size": 1.6, "glow": true}]],
	"burst": [["hop", Vector3.ZERO, Vector3(0, 0.1, 0), "pulse"], ["fx", 0.3, "puff", {"from": "centre", "color": "#9ad35a", "amount": 30, "size": 2.0, "glow": true}]],
	"falter": [["lean", Z, -9.0, 9.0, Vector3.ZERO, "shake"], ["fx", 0.2, "stars", {"from": "top", "color": "#ffe27a"}]],
}

## Every mine's creatures, each in its own file (view/creatures/rigs/<mine>.gd): their RIGS
## merged here by scene key, with the script that holds each one's functions.
const MINES: Array = [preload("res://view/creatures/rigs/quarry.gd"), preload("res://view/creatures/rigs/quarry_wardens.gd"), preload("res://view/creatures/rigs/seeps.gd"),
	preload("res://view/creatures/rigs/glass_veins.gd"), preload("res://view/creatures/rigs/warrens.gd"),
	preload("res://view/creatures/rigs/furnace.gd"), preload("res://view/creatures/rigs/geode.gd"),
	preload("res://view/creatures/rigs/rift.gd")]
static var RIGS: Dictionary = _merged("RIGS")
## How long the moves played by a function run, from every mine.
static var CUSTOM_LENGTH: Dictionary = _merged("CUSTOM_LENGTH")
## When a move played by a function is wound back furthest (its keyed time): where a heavy one
## holds. HIT - 0.08 for any not listed.
static var CUSTOM_WIND: Dictionary = _merged("CUSTOM_WIND")
## The mine script that holds a scene's own functions (its idle, its custom moves).
static var OWNERS: Dictionary = _owners()

static func _merged(what: String) -> Dictionary:
	var out: Dictionary = {}
	for mine in MINES:
		out.merge((mine as Script).get_script_constant_map().get(what, {}))
	return out

static func _owners() -> Dictionary:
	var out: Dictionary = {}
	for mine in MINES:
		for key in (mine as Script).get_script_constant_map().get("RIGS", {}):
			out[key] = mine
	return out

static func owner_of(scene_key: String) -> Script:
	return OWNERS.get(scene_key, null)
