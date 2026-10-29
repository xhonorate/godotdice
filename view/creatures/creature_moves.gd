extends Node3D
## What a creature does with its own parts: the move it acts out (a bite snapping its jaw shut
## as the head lunges, a claw swung down in an arc, a tail flicked up, a breath poured from the
## mouth) and the idle that suits it (a magpie pecking the floor, a mimic's eyes looking about,
## a tendril swaying). The animation pass of October 28, 2026, on the models baked with named
## parts (build/options/PART_ROLES.md).
##
## Everything here is an offset laid over the parts' own idle motions each frame
## (creature_part.gd): a turn of a group of pivots about a joint, a shift, a swell, a spin about
## a part's own axle. Pivots are flat siblings under the body, so a part that rides on another
## (a jaw on a head, a saw on a tail's tip) is listed in that one's group too and is carried by
## its turn; turns are laid on from the leaf to the root (a jaw opens about its hinge before the
## head turns about the neck). What each creature does is data, in creature_rigs.gd; the few
## things no table says (a mole digging in, a tendril unfurling, a mimic's tongue) are written
## out below.
##
## The screen calls `play` 0.3 s before the move lands (`HIT`): every attack is timed to strike
## then. A creature with no named parts, or no gesture for the move, says no and the creature
## falls back on its old lunge or channel.

const Part = preload("res://view/creatures/creature_part.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")
const Rigs = preload("res://view/creatures/creature_rigs.gd")

const HIT: float = Rigs.HIT
## A clip is let go this long after its last key, so the parts are seen back at rest.
const TAIL: float = 0.05

var _creature: Node3D
var _body: Node3D
## The scene's own key (a Glint Magpie wears the Magpie's scene, an echo whatever it copies).
var looks: String = ""
var _rig: Dictionary = {}
var _named: Dictionary = {}
var _groups: Dictionary = {}
## This frame's offsets: part -> a transform laid over its idle pose, in the body's space.
var _offsets: Dictionary = {}
## This frame's extra turn about each part's own axle (a saw, a drill bit, a wheel).
var _spins: Dictionary = {}
var _touched: Array = []
var _clips: Array = []
var _clock: float = 0.0
## The idle eases out while a move plays and back in after it.
var _idle_weight: float = 1.0
## Particle emitters that follow a part: a clouder's fog, a dragon's smoke, an eel's sparks.
var _ambient: Array = []
## A breath still pouring, carried with the mouth it leaves.
var _follow: Array = []
var _lean := Transform3D.IDENTITY
var _leaning: bool = false
var _rear_driven: bool = false
## How many times it has struck: which of a hydra's heads goes next.
var _strikes: int = 0
## States worn on the model for as long as they last.
var _prize: bool = false
var _fade: float = 0.0
var _fade_want: float = 0.0
var _faded_meshes: Array = []
var _dig: float = 0.0
var _dig_state: String = ""
var _dig_clock: float = 0.0
var _hole: MeshInstance3D = null
var _hole_material: StandardMaterial3D = null
## Shown only while a move asks for them (the Kiln Wyrm's breath).
var _hidden_at_rest: Array = []
var _saw_spin: float = 0.0

func _init(creature: Node3D, body: Node3D, scene_key: String) -> void:
	name = "Moves"
	_creature = creature
	_body = body
	looks = scene_key
	for child in body.get_children():
		if child is Part:
			_named[str(child.name)] = child
	_rig = Rigs.rig(scene_key)
	for selector in _rig.get("hidden", []):
		for part in _select(selector):
			part.visible = false
			_hidden_at_rest.append(part)
	if _rig.has("prize"):
		for part in _select(_rig.prize):
			part.visible = false

func _ready() -> void:
	for spec in _rig.get("ambient", []):
		_add_ambient(spec)

# --- what the creature asks ----------------------------------------------------------------

func has_rig() -> bool:
	return not _rig.is_empty()

func handles(anim: String, move: String, hostile: bool) -> bool:
	return _spec_for(anim, move, hostile) != null

func play(anim: String, move: String = "", hostile: bool = true, aim: Vector3 = Vector3.INF, fx: Node = null) -> bool:
	## Acts out a move; false when this creature has nothing of its own for it.
	var spec: Variant = _spec_for(anim, move, hostile)
	if spec == null:
		return false
	var clip: Dictionary = {"anim": anim, "move": move, "t": 0.0, "hostile": hostile, "aim": aim,
		"fx": weakref(fx) if fx != null else null, "fired": {}, "spun": {}, "length": 0.0,
		"shift": lead(anim, move, hostile) - HIT}
	if spec is String:
		clip.custom = spec
		clip.length = float(Rigs.CUSTOM_LENGTH.get(spec, 1.0))
	else:
		var gestures: Array = spec if spec is Array else spec.get("do", [])
		clip.gestures = gestures
		clip.length = float(spec.get("length", 0.0)) if spec is Dictionary else 0.0
		if clip.length <= 0.0:
			clip.length = _length_of(gestures)
		clip.length = float(clip.length) + float(clip.shift)
	if anim == "erupt" and _dig_state in ["waiting", "under"]:
		_dig_state = "erupting"
		_dig = 0.0
	_strikes += 1
	clip.strike = _strikes
	_clips.append(clip)
	return true

func lead(anim: String, move: String, hostile: bool = true) -> float:
	## How long before its blow lands this move wants to start: a tendril unfurls first, an
	## ember crawler rears up. The screen starts it this far ahead (0.3 s unless a rig says).
	var leads: Dictionary = _rig.get("lead", {})
	if leads.has(move):
		return float(leads[move])
	if leads.has(anim):
		return float(leads[anim])
	return HIT

func acting() -> bool:
	return not _clips.is_empty()

func set_prize(on: bool) -> void:
	## The magpie's pyrite in its beak: only once it has stolen some.
	if on == _prize or not _rig.has("prize"):
		return
	_prize = on
	for part in _select(_rig.prize):
		part.visible = on
	if on:
		_clips.append({"anim": "prize", "move": "", "t": 0.0, "custom": "_prize_pop", "length": 0.5, "fired": {}, "spun": {}, "aim": Vector3.INF, "fx": null, "hostile": false})

func burrow_style() -> String:
	## How it leaves reach: "dig" (into its mound), "fade" (see-through) or "" (the old sinking).
	return str(_rig.get("burrow", ""))

func burrow(down: bool) -> void:
	match burrow_style():
		"fade":
			_fade_want = 1.0 if down else 0.0
		"dig":
			if down and _dig_state in ["", "up", "settling"]:
				_dig_state = "digging"
				_dig_clock = 0.0
			elif not down and _dig_state in ["digging", "under"]:
				## Up it comes with its Erupt; if none follows soon, on its own.
				_dig_state = "waiting"
				_dig_clock = 0.0

func faded() -> float:
	return _fade

func faded_last() -> bool:
	## Whether it has just come all the way back from a fade (its shadow to be put back once).
	var was: bool = _was_faded
	_was_faded = _fade > 0.0
	return was and _fade <= 0.0

var _was_faded: bool = false

func flee() -> void:
	## Off with what it took: wings beating hard as it goes. What lies on the floor by it (a
	## magpie's nuggets) stays behind rather than flying off with it.
	for part in _select(_rig.get("ground", [])):
		part.visible = false
	var spec: Variant = _rig.get("moves", {}).get("flee", null)
	if spec != null:
		play("flee", "Flee", false)

# --- the frame -------------------------------------------------------------------------------

func reset() -> void:
	## Before the parts idle: every part moved last frame goes back to its rest, so its idle is
	## laid on clean and nothing it did not set (a turn on a pulsing part) is left behind.
	for part in _touched:
		if is_instance_valid(part):
			part.transform = part._rest
	_touched.clear()

func lean() -> Transform3D:
	return _lean

func leaning() -> bool:
	return _leaning

func apply(delta: float) -> void:
	## After the parts idle: the idle that suits it, the states it wears and the move it is
	## playing, laid over them.
	_clock += delta
	_offsets.clear()
	_spins.clear()
	_lean = Transform3D.IDENTITY
	_leaning = false
	_idle_weight = move_toward(_idle_weight, 0.0 if not _clips.is_empty() else 1.0, delta * 3.0)
	var idle: String = str(_rig.get("idle", ""))
	if not idle.is_empty() and _idle_weight > 0.001:
		call(idle, _clock, _idle_weight)
	for gesture in _rig.get("idle_gestures", []):
		if _idle_weight > 0.001:
			_idle_gesture(gesture, _idle_weight)
	_states(delta)
	var due: Array = []
	var drove_rear: bool = false
	_rear_held = false
	for clip in _clips.duplicate():
		clip.t = float(clip.t) + delta
		if clip.has("custom"):
			call(str(clip.custom), clip, delta)
		else:
			## A move that starts early (its lead) is laid on as though it started at its lead
			## less HIT: its keys stay written against the blow at HIT.
			var keyed: float = float(clip.t) - float(clip.shift)
			for gesture in clip.gestures:
				if str(gesture[0]) == "fx":
					if keyed >= float(gesture[1]) and not clip.fired.has(gesture):
						clip.fired[gesture] = true
						due.append([clip, gesture[2], gesture[3] if gesture.size() > 3 else {}])
				elif str(gesture[0]) == "rear":
					drove_rear = true
					_gesture(clip, gesture, delta)
				else:
					_gesture(clip, gesture, delta)
		for queued in clip.get("queued", []):
			due.append([clip, queued[0], queued[1]])
		clip.queued = []
		if float(clip.t) >= float(clip.length) + TAIL:
			_clips.erase(clip)
	drove_rear = drove_rear or _rear_held
	if _rear_driven and not drove_rear:
		_creature.set("_rear", 0.0)
	_rear_driven = drove_rear
	## Laid on: spins about each part's own axle first, then the turns about the joints.
	for part in _spins:
		part.transform.basis = part.transform.basis * Basis(Vector3.UP, float(_spins[part]))
		_touched.append(part)
	for part in _offsets:
		part.transform = _offsets[part] * part.transform
		if not _spins.has(part):
			_touched.append(part)
	for item in due:
		_fire(item[0], str(item[1]), item[2])
	_carry_followers()
	_carry_ambient()

# --- groups ----------------------------------------------------------------------------------

## Selections already made, by what was asked for: the idles ask every frame.
var _selected: Dictionary = {}

func _select(selectors: Variant) -> Array:
	## Pivots by name: "Head" (every Head pivot), "Head04" (that one) or "Body03-05" (a run).
	var asked: String = str(selectors)
	if _selected.has(asked):
		return _selected[asked]
	var out: Array = _pick(selectors)
	_selected[asked] = out
	return out

func _pick(selectors: Variant) -> Array:
	var out: Array = []
	var list: Array = selectors if selectors is Array else [selectors]
	for raw in list:
		var selector: String = str(raw)
		var dash: int = selector.find("-")
		if dash > 0:
			var stem: String = selector.substr(0, dash - 2)
			var low: int = int(selector.substr(dash - 2, 2))
			var high: int = int(selector.substr(dash + 1))
			for index in range(low, high + 1):
				var named: String = "%s%02d" % [stem, index]
				if _named.has(named) and not out.has(_named[named]):
					out.append(_named[named])
		elif _named.has(selector):
			if not out.has(_named[selector]):
				out.append(_named[selector])
		else:
			for index in range(1, 100):
				var named: String = "%s%02d" % [selector, index]
				if not _named.has(named):
					if index > 1:
						break
					continue
				if not out.has(_named[named]):
					out.append(_named[named])
	return out

func group(name: String) -> Dictionary:
	## A named group of the rig (its parts and the joint they turn about), or a selector.
	if _groups.has(name):
		return _groups[name]
	var spec: Variant = _rig.get("groups", {}).get(name, null)
	var out: Dictionary = {"parts": [], "joint": Vector3.ZERO, "chain": []}
	var at: Variant = null
	if spec is Dictionary:
		if spec.has("chain"):
			for segment in spec.chain:
				var parts: Array = _select(segment).duplicate()
				if parts.is_empty():
					continue
				out.chain.append({"parts": parts, "joint": (parts[0] as Node3D).get("_rest").origin})
				out.parts.append_array(parts)
			for rider in spec.get("attach", []):
				## Riders laid along the chain: each goes with the segment nearest it (a fin on its
				## stone, a ring round the body there).
				for part in _select(rider):
					var best: int = 0
					var near: float = INF
					for index in range(out.chain.size()):
						for seg_part in out.chain[index].parts:
							var d: float = centre_of(seg_part).distance_to(centre_of(part))
							if d < near:
								near = d
								best = index
					if not out.chain.is_empty():
						out.chain[best].parts.append(part)
						out.parts.append(part)
			for rider in spec.get("riders", []):
				## Riders on the last segment: a bud on a tendril's tip, a saw on a tail's.
				var extra: Array = _select(rider)
				if not out.chain.is_empty():
					out.chain[-1].parts.append_array(extra)
				out.parts.append_array(extra)
		else:
			out.parts = _select(spec.get("parts", [name])).duplicate()
		at = spec.get("at", null)
	else:
		out.parts = _select(spec if spec != null else name)
	if at is Vector3:
		out.joint = at
	elif at is String and _named.has(str(at)):
		out.joint = (_named[str(at)] as Node3D).get("_rest").origin
	elif not out.parts.is_empty():
		out.joint = (out.parts[0] as Node3D).get("_rest").origin
	_groups[name] = out
	return out

# --- laying offsets ---------------------------------------------------------------------------

func turn(parts: Array, pivot: Vector3, axis: Vector3, angle: float) -> void:
	## Turns these parts about a joint (body space), on top of whatever turned them before.
	if absf(angle) < 0.00001 or axis.is_zero_approx():
		return
	var about := Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(axis.normalized(), angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	for part in parts:
		_offsets[part] = about * (_offsets.get(part, Transform3D.IDENTITY) as Transform3D)

func shift(parts: Array, by: Vector3) -> void:
	if by.is_zero_approx():
		return
	var moved := Transform3D(Basis.IDENTITY, by)
	for part in parts:
		_offsets[part] = moved * (_offsets.get(part, Transform3D.IDENTITY) as Transform3D)

func swell(parts: Array, centre: Vector3, by: Vector3) -> void:
	## Scales these parts about a point by `by` (1 is no change).
	if by.is_equal_approx(Vector3.ONE):
		return
	var grown := Transform3D(Basis.IDENTITY, centre) * Transform3D(Basis.from_scale(by), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -centre)
	for part in parts:
		_offsets[part] = grown * (_offsets.get(part, Transform3D.IDENTITY) as Transform3D)

func swell_each(parts: Array, by: Vector3) -> void:
	## Each part swells about its own pivot (a flame from its root, a gem from its middle).
	if by.is_equal_approx(Vector3.ONE):
		return
	for part in parts:
		var at: Vector3 = (part as Node3D).get("_rest").origin
		var grown := Transform3D(Basis.IDENTITY, at) * Transform3D(Basis.from_scale(by), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -at)
		_offsets[part] = grown * (_offsets.get(part, Transform3D.IDENTITY) as Transform3D)

func chain_turns(chain: Array, axis: Vector3, angles: Array) -> void:
	## Each segment of a chain turned by its own angle about its joint, carrying every segment
	## after it (a tongue lolling, a tendril unrolling).
	for index in range(mini(chain.size(), angles.size()) - 1, -1, -1):
		var angle: float = float(angles[index])
		if absf(angle) < 0.00001:
			continue
		var carried: Array = []
		for later in range(index, chain.size()):
			carried.append_array(chain[later].parts)
		turn(carried, chain[index].joint, axis, angle)

func splay(gr: Dictionary, angle: float) -> void:
	for part in gr.parts:
		var at: Vector3 = (part as Node3D).get("_rest").origin
		var out: Vector3 = at - (gr.joint as Vector3)
		out.y = 0.0
		if out.is_zero_approx():
			continue
		turn([part], at, out.cross(Vector3.UP), angle)

func centre_of(part: Node3D) -> Vector3:
	## Where a part's shape sits, in the body's space (its pivot may be a joint some way off).
	var rest: Transform3D = part.get("_rest")
	if part.get_child_count() > 0 and part.get_child(0) is Node3D:
		return rest * (part.get_child(0) as Node3D).transform.origin
	return rest.origin

func spin(parts: Array, angle: float) -> void:
	for part in parts:
		_spins[part] = float(_spins.get(part, 0.0)) + angle

func curl(chain: Array, axis: Variant, angle: float, falloff: String = "even") -> void:
	## Bends a chain of segments (root to tip), each about its own joint carrying every segment
	## after it. `axis` is a body-space axis, or "across": square to each segment and level, so
	## a positive angle lifts the tip.
	var count: int = chain.size()
	if count == 0 or absf(angle) < 0.00001:
		return
	var weights: Array = []
	var total: float = 0.0
	for index in range(count):
		var w: float = 1.0
		match falloff:
			"tip":
				w = float(index + 1)
			"root":
				w = float(count - index)
		weights.append(w)
		total += w
	## Leaf first: the tip's own turn, then each joint toward the root carries what is past it.
	for index in range(count - 1, -1, -1):
		var carried: Array = []
		for later in range(index, count):
			carried.append_array(chain[later].parts)
		var joint: Vector3 = chain[index].joint
		var about: Vector3
		if axis is Vector3:
			about = axis
		else:
			var along: Vector3
			if index + 1 < count:
				along = chain[index + 1].joint - joint
			elif index > 0:
				along = joint - chain[index - 1].joint
			else:
				along = Vector3.FORWARD
			along.y = 0.0
			about = along.cross(Vector3.UP) if not along.is_zero_approx() else Vector3.RIGHT
		turn(carried, joint, about, angle * float(weights[index]) / total)

# --- envelopes ---------------------------------------------------------------------------------

## How long the oscillating envelopes run.
const WOBBLE: float = 0.9

static func value(keys: Variant, t: float) -> float:
	## Where a move stands at time t: -1 is fully wound back, +1 the blow, 0 rest. The keys are
	## [time, value] pairs; a short climb to a blow eases in (it lands fast), the rest smoothly.
	## A few are oscillations instead: a flutter of wings, a shudder, claws scrabbling.
	var named: Variant = Rigs.ENV.get(keys, []) if keys is String else keys
	if named is String:
		var bell: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(WOBBLE - 0.25, WOBBLE, t))
		match str(named):
			"~flutter":
				return 0.5 * (1.0 + sin(t * 38.0 - PI * 0.5)) * bell
			"~shake":
				return sin(t * 34.0) * bell
			"~scrabble":
				return 0.5 * (1.0 + sin(t * 30.0 - PI * 0.5)) * bell
		return 0.0
	var list: Array = named
	if list.is_empty():
		return 0.0
	if t <= float(list[0][0]):
		return float(list[0][1])
	for index in range(1, list.size()):
		var b: Array = list[index]
		if t <= float(b[0]):
			var a: Array = list[index - 1]
			var span: float = float(b[0]) - float(a[0])
			var x: float = clampf((t - float(a[0])) / span, 0.0, 1.0) if span > 0.0 else 1.0
			var striking: bool = float(b[1]) > float(a[1]) and float(b[1]) > 0.0 and span <= 0.12
			var eased: float = x * x if striking else x * x * (3.0 - 2.0 * x)
			return lerpf(float(a[1]), float(b[1]), eased)
	return float(list[-1][1])

static func _span_of(keys: Variant) -> float:
	var named: Variant = Rigs.ENV.get(keys, []) if keys is String else keys
	if named is String:
		return WOBBLE
	var list: Array = named
	return float(list[-1][0]) if not list.is_empty() else 0.0

## Where each gesture keeps its envelope.
const ENVELOPE_AT: Dictionary = {"turn": 5, "turn_each": 5, "curl": 5, "lean": 5, "move": 4, "grow": 4, "each": 4,
	"splay": 4, "whirl": 4, "whirl_own": 4, "spread": 4, "hop": 3, "spin": 3, "rear": 2}


func _progress(clip: Dictionary, key: String, keys: Variant, t: float) -> float:
	## How far through its whole turn a spin is at t: the envelope's area so far over all of it,
	## so it speeds up and runs down with the envelope and ends exactly where it began.
	if not clip.has("areas"):
		clip.areas = {}
	if not clip.areas.has(key):
		var span: float = maxf(0.05, _span_of(keys))
		var table: Array = [0.0]
		var total: float = 0.0
		for i in range(1, 61):
			total += absf(value(keys, span * float(i) / 60.0))
			table.append(total)
		clip.areas[key] = {"span": span, "table": table, "total": maxf(total, 0.0001)}
	var area: Dictionary = clip.areas[key]
	var x: float = clampf(t / float(area.span), 0.0, 1.0) * 60.0
	var i: int = mini(int(x), 59)
	return lerpf(float(area.table[i]), float(area.table[i + 1]), x - float(i)) / float(area.total)

func _length_of(gestures: Array) -> float:
	var longest: float = 0.6
	for gesture in gestures:
		var kind: String = str(gesture[0])
		match kind:
			"fx":
				longest = maxf(longest, float(gesture[1]) + 0.1)
			"show":
				longest = maxf(longest, float(gesture[3]))
			_:
				if ENVELOPE_AT.has(kind) and gesture.size() > int(ENVELOPE_AT[kind]):
					longest = maxf(longest, _span_of(gesture[int(ENVELOPE_AT[kind])]))
	return longest

func _gesture(clip: Dictionary, g: Array, delta: float) -> void:
	var t: float = float(clip.t) - float(clip.get("shift", 0.0))
	match str(g[0]):
		"turn":
			## ["turn", group, axis, wind degrees, strike degrees, envelope]
			var v: float = value(g[5], t)
			var angle: float = deg_to_rad(float(g[3]) * -v if v < 0.0 else float(g[4]) * v)
			var gr: Dictionary = group(str(g[1]))
			turn(gr.parts, gr.joint, g[2], angle)
		"turn_each":
			## ["turn_each", group, axis, wind degrees, strike degrees, envelope]: every part about
			## its own pivot (six tendrils, each hung from its own root).
			var v: float = value(g[5], t)
			var angle: float = deg_to_rad(float(g[3]) * -v if v < 0.0 else float(g[4]) * v)
			for part in group(str(g[1])).parts:
				turn([part], (part as Node3D).get("_rest").origin, g[2], angle)
		"splay":
			## ["splay", group, wind degrees, strike degrees, envelope]: every part about its own
			## pivot, its far end swinging out from the group's joint (a positive angle opens a
			## hanging fringe).
			var v: float = value(g[4], t)
			var angle: float = deg_to_rad(float(g[2]) * -v if v < 0.0 else float(g[3]) * v)
			splay(group(str(g[1])), angle)
		"move":
			## ["move", group, wind offset, strike offset, envelope]
			var v: float = value(g[4], t)
			var by: Vector3 = (g[2] as Vector3) * -v if v < 0.0 else (g[3] as Vector3) * v
			shift(group(str(g[1])).parts, by)
		"grow", "each":
			## ["grow", group, wind, strike, envelope]: a swell about the group's joint (a float
			## for all three axes, or a Vector3), "each" about every part's own pivot.
			var v: float = value(g[4], t)
			var amount: Variant = g[2] if v < 0.0 else g[3]
			var k: float = absf(v)
			var by: Vector3 = Vector3.ONE + ((amount as Vector3) if amount is Vector3 else Vector3.ONE * float(amount)) * k
			var gr: Dictionary = group(str(g[1]))
			if str(g[0]) == "grow":
				swell(gr.parts, gr.joint, by)
			else:
				swell_each(gr.parts, by)
		"curl":
			## ["curl", chain group, axis or "across", wind degrees, strike degrees, envelope, falloff]
			var v: float = value(g[5], t)
			var angle: float = deg_to_rad(float(g[3]) * -v if v < 0.0 else float(g[4]) * v)
			curl(group(str(g[1])).chain, g[2], angle, str(g[6]) if g.size() > 6 else "even")
		"spin":
			## ["spin", group, whole turns, envelope]: about each part's own axle (a saw, a drill
			## bit, a wheel), faster where the envelope is high. Whole turns, so nothing jumps
			## when it lets go.
			spin(group(str(g[1])).parts, TAU * float(g[2]) * _progress(clip, str(g), g[3], t))
		"whirl":
			## ["whirl", group, axis, whole turns, envelope]: the group turned about its joint the
			## same way (a halo, a wheel of petals, a ribbon whipped round).
			var gr: Dictionary = group(str(g[1]))
			turn(gr.parts, gr.joint, g[2], TAU * float(g[3]) * _progress(clip, str(g), g[4], t))
		"whirl_own":
			## The same about an axis that turns with the group's own idle (a wheel of petals that
			## yaws as it idles spins about its own face, not the creature's).
			var gr: Dictionary = group(str(g[1]))
			if not gr.parts.is_empty():
				var first: Node3D = gr.parts[0]
				var now: Basis = first.transform.basis.orthonormalized() * ((first.get("_rest") as Transform3D).basis.orthonormalized().inverse())
				turn(gr.parts, gr.joint, now * (g[2] as Vector3), TAU * float(g[3]) * _progress(clip, str(g), g[4], t))
		"spread":
			## ["spread", group, wind, strike, envelope]: each part pushed out from the group's
			## joint (level), by so much.
			var v: float = value(g[4], t)
			var by: float = float(g[2]) * -v if v < 0.0 else float(g[3]) * v
			var gr: Dictionary = group(str(g[1]))
			for part in gr.parts:
				var out: Vector3 = centre_of(part) - (gr.joint as Vector3)
				out.y = 0.0
				if not out.is_zero_approx():
					shift([part], out.normalized() * by)
		"rear":
			## ["rear", amount, envelope]: the whole creature rears back and lunges (the old lunge,
			## smaller, under the parts' own blow).
			var v: float = value(g[2], t)
			_creature.set("_rear", float(g[1]) * -v)
		"lean":
			## ["lean", axis, wind degrees, strike degrees, pivot, envelope]: the whole body.
			var v: float = value(g[5], t)
			var angle: float = deg_to_rad(float(g[2]) * -v if v < 0.0 else float(g[3]) * v)
			if absf(angle) > 0.00001:
				var pivot: Vector3 = g[4]
				_lean = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis((g[1] as Vector3).normalized(), angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot) * _lean
				_leaning = true
		"hop":
			## ["hop", wind offset, strike offset, envelope]: the whole body moved.
			var v: float = value(g[3], t)
			var by: Vector3 = (g[1] as Vector3) * -v if v < 0.0 else (g[2] as Vector3) * v
			if not by.is_zero_approx():
				_lean = Transform3D(Basis.IDENTITY, by) * _lean
				_leaning = true
		"show":
			## ["show", group, from, to]: parts hidden at rest, shown for a while.
			var on: bool = t >= float(g[2]) and t < float(g[3])
			for part in group(str(g[1])).parts:
				part.visible = on
		"call":
			call(str(g[1]), clip, delta)

func _idle_gesture(g: Array, weight: float) -> void:
	## A rig's idle as data: ["sway", group, axis, degrees, rate, phase] turns a group back and
	## forth; ["bob", group, offset, rate, phase] moves it.
	match str(g[0]):
		"sway":
			var gr: Dictionary = group(str(g[1]))
			turn(gr.parts, gr.joint, g[2], deg_to_rad(float(g[3])) * sin(_clock * float(g[4]) + float(g[5])) * weight)
		"bob":
			shift(group(str(g[1])).parts, (g[2] as Vector3) * sin(_clock * float(g[3]) + float(g[4])) * weight)
		"curl":
			var gr: Dictionary = group(str(g[1]))
			curl(gr.chain, g[2], deg_to_rad(float(g[3])) * sin(_clock * float(g[4]) + float(g[5])) * weight, str(g[6]) if g.size() > 6 else "even")
		"sway_each":
			## ["sway_each", group, axis, degrees, rate, phase step]: each part about its own pivot,
			## one beat behind the one before.
			var index: int = 0
			for part in group(str(g[1])).parts:
				turn([part], (part as Node3D).get("_rest").origin, g[2], deg_to_rad(float(g[3])) * sin(_clock * float(g[4]) + float(g[5]) * float(index)) * weight)
				index += 1

# --- effects ---------------------------------------------------------------------------------

func _fx_node(clip: Dictionary) -> Node:
	var held: Variant = clip.get("fx", null)
	if held == null:
		return null
	var node: Variant = (held as WeakRef).get_ref()
	return node if node != null and is_instance_valid(node) and (node as Node).is_inside_tree() else null

func point(at: Variant) -> Vector3:
	## A place on the creature in the room: "mouth", "centre", "feet", "top", or a part (where
	## its shape sits, not its pivot: a mouth marker hangs off the head's joint).
	var name: String = str(at)
	match name:
		"centre":
			return _creature.call("centre")
		"feet":
			return _creature.global_position
		"top":
			return _creature.global_position + Vector3(0, (_creature.get("anchor") as Vector3).y, 0)
		"mouth":
			name = str(_rig.get("mouth", ""))
	if _named.has(name):
		var part: Node3D = _named[name]
		if part.get_child_count() > 0 and part.get_child(0) is Node3D:
			return (part.get_child(0) as Node3D).global_position
		return part.global_position
	if _rig.get("groups", {}).has(name):
		var gr: Dictionary = group(name)
		if not gr.parts.is_empty():
			var part: Node3D = gr.parts[0]
			var offset: Transform3D = _offsets.get(part, Transform3D.IDENTITY)
			return _body.global_transform * (offset * gr.joint)
	## No such part: in front of its middle, where a mouth would be.
	return _creature.call("centre") + _forward() * 0.35 * maxf(0.6, (_creature.get("anchor") as Vector3).y)

func _forward() -> Vector3:
	return _creature.global_transform.basis.z.normalized()

func _aim(clip: Dictionary) -> Vector3:
	var aim: Vector3 = clip.get("aim", Vector3.INF)
	if aim.is_finite():
		return aim
	return _creature.global_position + _forward() * 5.5 + Vector3(0, 1.0, 0)

func _tone(spec: Dictionary, fallback: String = "tint") -> Color:
	var raw: Variant = spec.get("color", _rig.get("tone", fallback))
	if raw is Color:
		return raw
	match str(raw):
		"tint":
			return _creature.get("tint")
		"accent":
			var accent: StandardMaterial3D = _creature.get("accent_material")
			return accent.emission if accent != null else _creature.get("tint")
		"core":
			return (_creature.get("core_material") as StandardMaterial3D).emission
	return Color(str(raw))

func _fire(clip: Dictionary, name: String, spec: Dictionary) -> void:
	var fx: Node = _fx_node(clip)
	var from: Vector3 = point(spec.get("from", "mouth"))
	if spec.has("off"):
		from += _creature.global_transform.basis * (spec.off as Vector3)
	var aim: Vector3 = _aim(clip)
	var color: Color = _tone(spec)
	var size: float = float(spec.get("size", 1.0)) * _creature.scale.x
	## The creature itself reacts even where nothing can draw the effects.
	if spec.has("flash"):
		_creature.call("flash", float(spec.flash))
	if fx == null:
		return
	match name:
		"breath":
			var node: Node3D = fx.call("breath", from, aim, str(spec.get("kind", "fire")), color, float(spec.get("seconds", 0.5)), size)
			if node != null:
				_follow.append({"node": node, "from": spec.get("from", "mouth"), "aim": aim, "until": _clock + float(spec.get("seconds", 0.5)), "off": spec.get("off", Vector3.ZERO)})
		"spit":
			var flight: float = float(spec.get("flight", 0.2))
			var splat: Color = color
			var wet: String = str(spec.get("kind", "glob"))
			var landing := func() -> void:
				if is_instance_valid(fx):
					fx.call("splat", aim, splat, wet)
			fx.call("projectile", from, aim, color, flight, 0.16 * float(spec.get("size", 1.0)), landing, float(spec.get("arc", 0.5)), 3.5)
		"bolt":
			fx.call("projectile", from, aim, color, float(spec.get("flight", 0.22)), 0.13 * float(spec.get("size", 1.0)), Callable(), float(spec.get("arc", 0.25)), 4.0)
		"beam":
			fx.call("beam", from, aim, color, float(spec.get("seconds", 0.4)), float(spec.get("width", 0.14)))
			fx.call("glow_burst", from, color, 0.9 * size, 0.3)
		"zap":
			fx.call("zap", from, aim, color, float(spec.get("seconds", 0.35)))
		"drain":
			## Light pulled out of the party and into it.
			## They start a way out from the lens, not on it: a mote that close is a blur.
			var out: Vector3 = aim.lerp(from, 0.3)
			for index in range(int(spec.get("count", 4))):
				var start: Vector3 = out + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3), 0)
				fx.call("projectile", start, from, color, 0.32 + 0.05 * float(index), 0.07, Callable(), 0.4)
			fx.call("spiral_in", from, color, 0.9 * size, 28, 0.7)
		"shock":
			## A blow on the floor: a ring rolling out and dust thrown up.
			var feet: Vector3 = point(spec.get("from", "feet")) if spec.has("from") else _creature.global_position
			if spec.has("ahead"):
				feet += _forward() * float(spec.ahead) * _creature.scale.x
			feet.y = _creature.global_position.y
			fx.call("ring_wave", feet, color.lerp(Color("c8b8a0"), 0.5), 2.6 * size, 0.55, 0.3)
			fx.call("puff", feet + Vector3(0, 0.2, 0), Color(0.45, 0.4, 0.34), 12, 0.7 * size, 1.1, 0.5)
			fx.call("shards", feet + Vector3(0, 0.1, 0), Color(0.55, 0.5, 0.45), 6, 2.5, 0.08 * size, 0.8)
		"splash":
			fx.call("splash", from, color, int(spec.get("amount", 40)), float(spec.get("speed", 4.0)) * maxf(1.0, size * 0.8), 1.0)
		"sparks":
			fx.call("sparks", from, color, int(spec.get("amount", 24)), float(spec.get("speed", 3.0)), float(spec.get("life", 0.6)), 0.05 * maxf(1.0, size))
		"jet":
			fx.call("jet", from, color, int(spec.get("amount", 30)), float(spec.get("speed", 5.0)) * size, float(spec.get("spread", 20.0)), float(spec.get("life", 0.9)), 0.07 * size)
		"puff":
			fx.call("puff", from, color, int(spec.get("amount", 12)), 0.6 * size, float(spec.get("life", 1.1)), float(spec.get("rise", 0.4)), bool(spec.get("glow", false)))
		"glow":
			fx.call("glow_burst", from, color, 0.8 * size, float(spec.get("seconds", 0.35)))
		"flash_light":
			fx.call("flash", from, color, float(spec.get("energy", 4.0)), 4.0 * size, 0.35, 0.8)
		"shards":
			fx.call("shards", from, color, int(spec.get("amount", 10)), float(spec.get("speed", 3.5)), 0.1 * size, 0.9)
		"spiral":
			fx.call("spiral_in", from, color, 1.2 * size, int(spec.get("amount", 30)), 0.8)
		"rise":
			fx.call("rise", from, color, int(spec.get("amount", 20)), 0.5 * size, 1.0)
		"dust":
			fx.call("dust_fall", int(spec.get("amount", 50)))
		"erupt":
			fx.call("erupt", from, color, size)
		"swipe":
			## The arc a claw or a blade cuts, flashed in the air where it passed.
			var centre: Vector3 = point(spec.get("about", "centre"))
			var axis: Vector3 = _creature.global_transform.basis * (spec.get("axis", Vector3.RIGHT) as Vector3)
			var start: Vector3 = _creature.global_transform.basis * (spec.get("start", Vector3.UP) as Vector3)
			fx.call("swipe", centre, axis.normalized(), start.normalized(), float(spec.get("radius", 0.8)) * _creature.scale.x, float(spec.get("sweep", 120.0)), color)
		"ripple":
			fx.call("ripple", from, aim - from, color, float(spec.get("radius", 1.4)) * size, float(spec.get("seconds", 0.6)))
		"ring":
			var feet: Vector3 = _creature.global_position
			fx.call("ring_wave", feet, color, float(spec.get("radius", 2.0)) * size, 0.6, 0.2)
		"flames":
			fx.call("flames", from, 0.5 * size, float(spec.get("seconds", 0.7)))
		"bubbles":
			fx.call("bubbles", from, color, int(spec.get("amount", 18)), 0.4 * size, 1.0)
		"coins":
			fx.call("coins", aim, from, int(spec.get("amount", 6)))
		"stars":
			fx.call("stars", from, color, 1.0, 0.4 * size)
		"sigil":
			var feet: Vector3 = _creature.global_position
			fx.call("sigil", feet, color, 1.2 * size, 0.8)

func _carry_followers() -> void:
	## A breath still pouring leaves from wherever the mouth has moved to.
	for item in _follow.duplicate():
		var node: Variant = item.node
		if node == null or not is_instance_valid(node) or _clock > float(item.until) + 0.05:
			_follow.erase(item)
			continue
		var from: Vector3 = point(item.from) + _creature.global_transform.basis * (item.off as Vector3)
		var aim: Vector3 = item.aim
		if not from.is_equal_approx(aim):
			(node as Node3D).look_at_from_position(from, aim, BattleFx._up_for(aim - from))

func _add_ambient(spec: Dictionary) -> void:
	var made: GPUParticles3D = BattleFx.haze(str(spec.get("kind", "fog")), _tone(spec), float(spec.get("size", 1.0)))
	if made == null:
		return
	add_child(made)
	_ambient.append({"node": made, "at": spec.get("at", "centre"), "off": spec.get("off", Vector3.ZERO)})
	_carry_ambient()

func _carry_ambient() -> void:
	if _ambient.is_empty() or not is_inside_tree():
		return
	var shown: bool = _creature.visible and _dig < 0.5
	for item in _ambient:
		var node: GPUParticles3D = item.node
		if not is_instance_valid(node):
			continue
		node.global_position = point(item.at) + _creature.global_transform.basis * (item.off as Vector3)
		node.emitting = shown and not bool(_creature.get("_dying"))

# --- states ----------------------------------------------------------------------------------

func _states(delta: float) -> void:
	## See-through while it fades out of reach; dug into its mound and back out.
	if not is_equal_approx(_fade, _fade_want):
		_fade = move_toward(_fade, _fade_want, delta * 2.0)
		_apply_fade()
	elif _fade > 0.0:
		## A faded creature shimmers a little, so it reads as there but out of reach.
		_apply_fade()
	if burrow_style() == "dig":
		_dig_pose(delta)

func _apply_fade() -> void:
	if _faded_meshes.is_empty():
		for node in _body.find_children("*", "GeometryInstance3D", true, false):
			_faded_meshes.append(node)
	var shimmer: float = 0.06 * sin(_clock * 3.1) * _fade
	for node in _faded_meshes:
		if is_instance_valid(node):
			(node as GeometryInstance3D).transparency = clampf(0.8 * _fade + shimmer, 0.0, 0.95)

func _dig_pose(delta: float) -> void:
	## The Pit Mole: digs down into its mound and is gone, a dark hole left in the dirt; comes
	## up out of it with its Erupt, snout to the sky and claws thrown wide, and settles.
	_dig_clock += delta
	var under: Array = _dig_parts()
	match _dig_state:
		"digging":
			## Claws raking fast, sinking as it goes.
			var t: float = _dig_clock
			_dig = smoothstep(0.15, 1.0, t)
			var rake: float = sin(t * 26.0) * 0.6 * (1.0 - _dig * 0.5)
			var claw_l: Dictionary = group("claw_l")
			var claw_r: Dictionary = group("claw_r")
			turn(claw_l.parts, claw_l.joint, Vector3.RIGHT, rake)
			turn(claw_r.parts, claw_r.joint, Vector3.RIGHT, -rake)
			var head: Dictionary = group("head")
			turn(head.parts, head.joint, Vector3.RIGHT, 0.5 * smoothstep(0.0, 0.3, t))
			if int(t * 8.0) != int((t - delta) * 8.0) and t < 1.0:
				_dirt(0.5)
			if t >= 1.1:
				_dig_state = "under"
		"under":
			_dig = 1.0
		"waiting":
			_dig = 1.0
			## Its Erupt is on the way; if it does not come, up it comes anyway.
			if _dig_clock > 2.2:
				play("erupt", "Erupt", true, Vector3.INF, _room_fx())
		"erupting":
			return
		"settling":
			_dig = 0.0
			if _dig_clock > 0.6:
				_dig_state = ""
		_:
			_dig = move_toward(_dig, 0.0, delta * 3.0)
	var hide: bool = _dig >= 0.999
	var drop: float = -1.15 * _dig * _dig
	shift(under, Vector3(0, drop, 0))
	for part in under:
		part.visible = not hide and (not _rig.has("prize") or part not in _select(_rig.prize))
	_show_hole(smoothstep(0.3, 0.9, _dig) if _dig_state != "erupting" else 0.0)

func _dig_parts() -> Array:
	if _groups.has("__under"):
		return _groups["__under"].parts
	var stay: Array = _select(_rig.get("ground", []))
	var out: Array = []
	for part in _named.values():
		if not stay.has(part):
			out.append(part)
	_groups["__under"] = {"parts": out, "joint": Vector3.ZERO, "chain": []}
	return out

func _show_hole(amount: float) -> void:
	if amount <= 0.001 and _hole == null:
		return
	if _hole == null:
		_hole = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.42
		disc.bottom_radius = 0.38
		disc.height = 0.02
		disc.radial_segments = 14
		disc.rings = 1
		_hole.mesh = disc
		_hole_material = StandardMaterial3D.new()
		_hole_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hole_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hole_material.albedo_color = Color(0.02, 0.015, 0.01, 0.0)
		_hole.material_override = _hole_material
		_hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		## Its own child, not the body's: nothing that dresses the body's meshes should find it.
		add_child(_hole)
	if _hole.is_inside_tree():
		_hole.global_transform = _body.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.6 + 0.4 * amount)), _rig.get("hole", Vector3(0, 0.2, 0.05)))
	_hole_material.albedo_color.a = 0.95 * amount
	_hole.visible = amount > 0.01

func _dirt(size: float) -> void:
	var fx: Node = _room_fx()
	if fx == null:
		return
	var at: Vector3 = _body.global_transform * (_rig.get("hole", Vector3(0, 0.2, 0.05)) as Vector3)
	fx.call("puff", at + Vector3(0, 0.15, 0), Color(0.42, 0.34, 0.26), 4, 0.5 * size * _creature.scale.x, 0.9, 0.6)
	fx.call("shards", at + Vector3(0, 0.1, 0), Color(0.5, 0.42, 0.33), 2, 2.4, 0.06 * _creature.scale.x, 0.6)

## The room's effects, for what a creature does on its own (digging in): the last a move was given.
var _last_fx: WeakRef = null

func _room_fx() -> Node:
	for clip in _clips:
		var node: Node = _fx_node(clip)
		if node != null:
			_last_fx = weakref(node)
			return node
	if _last_fx != null:
		var node: Variant = _last_fx.get_ref()
		if node != null and is_instance_valid(node) and (node as Node).is_inside_tree():
			return node
	return null

func remember_fx(fx: Node) -> void:
	if fx != null:
		_last_fx = weakref(fx)

# --- the moves no table says -------------------------------------------------------------------

func _spec_for(anim: String, move: String, hostile: bool) -> Variant:
	var moves: Dictionary = _rig.get("moves", {})
	move = str(_rig.get("alias", {}).get(move, move))
	## A Void Echo throws the moves of what it copies: its Echo is that creature's own blow.
	if str(_creature.get("key")) == "VOID_ECHO" and move == "Echo" and not moves.is_empty():
		return moves[str(_rig.get("signature", moves.keys()[0]))]
	if moves.has(move):
		return moves[move]
	if moves.has(anim):
		return moves[anim]
	if hostile and moves.has("*hostile"):
		return moves["*hostile"]
	if not hostile and moves.has("*"):
		return moves["*"]
	## Nothing of its own for it: the whole body acts it out (a creature with no named parts,
	## or a move its rig does not cover).
	if Rigs.GENERIC.has(anim):
		return Rigs.GENERIC[anim]
	return null

func _queue(clip: Dictionary, key: String, name: String, spec: Dictionary) -> void:
	## An effect a played function sets off, once.
	if clip.fired.has(key):
		return
	clip.fired[key] = true
	if not clip.has("queued"):
		clip.queued = []
	clip.queued.append([name, spec])

func _prize_pop(clip: Dictionary, _delta: float) -> void:
	## The pyrite it just took, flashed in its beak.
	var k: float = 1.0 + 0.6 * sin(clampf(float(clip.t) / 0.5, 0.0, 1.0) * PI)
	for part in _select(_rig.prize):
		swell([part], centre_of(part), Vector3.ONE * k)

func _idle_magpie(clock: float, weight: float) -> void:
	## Every few seconds it bends to the floor and pecks at a nugget there, twice, and looks up.
	var p: float = fmod(clock + 2.5, 6.5)
	if p > 1.7:
		return
	var down: float = smoothstep(0.0, 0.4, p) * (1.0 - smoothstep(1.3, 1.7, p))
	var peck: float = 0.0
	if p > 0.45 and p < 1.25:
		peck = absf(sin((p - 0.45) * PI / 0.4))
	var all: Dictionary = group("all")
	var head: Dictionary = group("head")
	var tail: Dictionary = group("tail")
	turn(tail.parts, tail.joint, Vector3.RIGHT, deg_to_rad(-18.0) * down * weight)
	turn(head.parts, head.joint, Vector3.RIGHT, deg_to_rad(52.0 * down + 14.0 * peck) * weight)
	turn(all.parts, all.joint, Vector3.RIGHT, deg_to_rad(26.0) * down * weight)

func _mole_erupt(clip: Dictionary, _delta: float) -> void:
	## Up out of its crater, snout to the sky and both claws thrown wide, and back to how it
	## stands. Bursts up only when it was under; above ground it rears into the same shape.
	var t: float = float(clip.t)
	if not clip.has("under"):
		clip.under = _dig_state == "erupting"
		_dig = 0.0
	var under: Array = _dig_parts()
	if bool(clip.under):
		var y: float = -1.15
		if t >= 0.12 and t < HIT:
			var x: float = (t - 0.12) / (HIT - 0.12)
			y = lerpf(-1.15, 0.22, 1.0 - (1.0 - x) * (1.0 - x))
		elif t >= HIT:
			y = lerpf(0.22, 0.0, smoothstep(HIT, 0.6, t))
		shift(under, Vector3(0, y, 0))
		for part in under:
			part.visible = true
		_show_hole(1.0 - smoothstep(0.1, 0.25, t))
		if t >= 0.1:
			_queue(clip, "dirt", "puff", {"from": "feet", "off": Vector3(0, 0.3, 0.1), "color": Color(0.42, 0.34, 0.26), "amount": 16, "size": 1.6, "rise": 1.2})
		if t >= 0.2:
			_queue(clip, "rocks", "shards", {"from": "feet", "off": Vector3(0, 0.3, 0.1), "color": Color(0.5, 0.42, 0.33), "amount": 14, "speed": 5.0})
	var b: float = smoothstep(0.12, HIT, t) * (1.0 - smoothstep(0.62, 1.05, t))
	var head: Dictionary = group("head")
	var claw_l: Dictionary = group("claw_l")
	var claw_r: Dictionary = group("claw_r")
	var front: Dictionary = group("front")
	turn(claw_l.parts, claw_l.joint, Vector3.RIGHT, deg_to_rad(-45.0) * b)
	turn(claw_l.parts, claw_l.joint, Vector3.BACK, deg_to_rad(75.0) * b)
	turn(claw_r.parts, claw_r.joint, Vector3.RIGHT, deg_to_rad(-45.0) * b)
	turn(claw_r.parts, claw_r.joint, Vector3.BACK, deg_to_rad(-75.0) * b)
	turn(head.parts, head.joint, Vector3.RIGHT, deg_to_rad(-65.0) * b)
	turn(front.parts, front.joint, Vector3.RIGHT, deg_to_rad(-18.0) * b)
	if t >= HIT:
		_queue(clip, "burst", "shock", {"size": 1.2})
	if t >= float(clip.length):
		_dig_state = "settling"
		_dig_clock = 0.0
		_show_hole(0.0)

## The Drill's eight segments, tail to head, with what rides on each.
const DRILL_SEGMENTS: Array = [["Body01-02"], ["Body03-05"], ["Body06-09", "Smoke01-03"], ["Body10-12"], ["Body13-15"],
	["Body16-19", "Smoke04-06"], ["Body20-22"], ["Body23-25", "Head", "Drill"]]

func _idle_drill(clock: float, weight: float) -> void:
	## A slow heave running down its arch from tail to head, each segment lifting and tipping a
	## little after the one behind it.
	for index in range(DRILL_SEGMENTS.size()):
		var parts: Array = _select(DRILL_SEGMENTS[index])
		if parts.is_empty():
			continue
		var wave: float = clock * 1.4 - float(index) * 0.55
		var at: Vector3 = centre_of(parts[0])
		turn(parts, at, Vector3.RIGHT, deg_to_rad(2.5) * cos(wave) * weight)
		shift(parts, Vector3(0, 0.035 * sin(wave), 0) * weight)

# --- the Tendril: unfurls before it lashes or knits ----------------------------------------------

## The axis its curl winds about (up x the curl's facing), and how far each curl joint winds:
## straightening it is the same turns backwards, from the stalk top out.
const TENDRIL_AXIS := Vector3(0.766, 0.0, -0.643)
const TENDRIL_CURL: Array = [26.5, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0]

func _tendril_pose(unfurl: float, bend: float, whip: float, sway: float = 0.0) -> void:
	## Unrolled by `unfurl` (0 curled, 1 standing straight up), the base of the curl first; the
	## stem bent toward the party by `bend` degrees a joint, the unrolled whip by `whip` a joint.
	var chain: Array = group("stalk").chain
	if chain.size() < 16:
		return
	var curl: Array = [0.0, 0.0, 0.0]
	for j in range(TENDRIL_CURL.size()):
		var start: float = float(j) / 12.0 * 0.55
		curl.append(deg_to_rad(-float(TENDRIL_CURL[j])) * smoothstep(start, start + 0.45, unfurl) + deg_to_rad(sway * 0.5))
	chain_turns(chain, TENDRIL_AXIS, curl)
	var stem: Array = []
	for index in range(16):
		if index < 3:
			stem.append(deg_to_rad(bend + sway))
		else:
			stem.append(deg_to_rad(whip) * unfurl)
	chain_turns(chain, Vector3.RIGHT, stem)

func _idle_tendril(clock: float, weight: float) -> void:
	## A slight sway, the stem most.
	_tendril_pose(0.0, 0.0, 0.0, 2.2 * sin(clock * 0.9) * weight)
	var chain: Array = group("stalk").chain
	if chain.size() >= 3:
		chain_turns(chain, Vector3.BACK, [deg_to_rad(1.6 * sin(clock * 0.7 + 1.0)) * weight, deg_to_rad(1.2 * sin(clock * 0.7 + 1.0)) * weight])

func _tendril_lash(clip: Dictionary, _delta: float) -> void:
	## Unrolls to its full height, rears back and whips down at the party, and curls up again.
	var t: float = float(clip.t)
	var hit: float = HIT + float(clip.shift)
	var unfurl: float = smoothstep(0.0, hit - 0.12, t) * (1.0 - smoothstep(hit + 0.35, hit + 0.8, t))
	var back: float = smoothstep(hit - 0.25, hit - 0.08, t) * (1.0 - smoothstep(hit - 0.08, hit, t))
	var strike: float = smoothstep(hit - 0.08, hit, t) * (1.0 - smoothstep(hit + 0.12, hit + 0.45, t))
	_tendril_pose(unfurl, -10.0 * back + 15.0 * strike, -2.0 * back + 3.2 * strike)
	var bud: Array = _select(["Bud01"])
	if not bud.is_empty():
		swell(bud, centre_of(bud[0]), Vector3.ONE * (1.0 + 0.5 * smoothstep(0.0, hit, t) * (1.0 - smoothstep(hit, hit + 0.4, t))))
	if t >= hit - 0.01:
		_queue(clip, "swipe", "swipe", {"about": "centre", "axis": Vector3.RIGHT, "start": Vector3(0, 1, -0.2), "radius": 1.6, "sweep": 100.0})
		_queue(clip, "shock", "shock", {"ahead": 1.8, "size": 0.8})

func _tendril_knit(clip: Dictionary, _delta: float) -> void:
	## Half unrolls, the bud blazing and its petals open, mends, and curls up again.
	var t: float = float(clip.t)
	var hit: float = HIT + float(clip.shift)
	var unfurl: float = 0.55 * smoothstep(0.0, hit, t) * (1.0 - smoothstep(hit + 0.5, float(clip.length) - 0.05, t))
	_tendril_pose(unfurl, 0.0, 0.0)
	var glow: float = smoothstep(hit - 0.15, hit, t) * (1.0 - smoothstep(hit + 0.4, hit + 0.8, t))
	var bud: Array = _select(["Bud01"])
	if not bud.is_empty():
		swell(bud, centre_of(bud[0]), Vector3.ONE * (1.0 + 0.6 * glow))
	if t >= hit:
		_queue(clip, "glow", "glow", {"from": "Bud01", "color": "#8cffb8", "size": 1.2})
		_queue(clip, "rise", "rise", {"from": "Bud01", "color": "#6fe3b0", "amount": 26})

# --- the Hoard Mimic: eyes that look about, a tongue that lolls -------------------------------

func _idle_mimic(clock: float, weight: float) -> void:
	## Its eyes dart from one thing to the next and blink now and then; its tongue lolls on the
	## floor, the tip curling.
	var beat: float = clock / 1.7
	var step: int = int(floor(beat))
	var ease: float = smoothstep(0.0, 0.18, beat - float(step))
	var was := Vector2(_noise(step - 1), _noise(step + 41))
	var now := Vector2(_noise(step), _noise(step + 42))
	var look: Vector2 = was.lerp(now, ease)
	var blink: float = 0.0
	var b: float = fmod(clock, 4.3)
	if b < 0.16:
		blink = sin(b / 0.16 * PI)
	for side in ["eye_r", "eye_l"]:
		var eye: Dictionary = group(side)
		turn(eye.parts, eye.joint, Vector3.UP, deg_to_rad(28.0) * look.x * weight)
		turn(eye.parts, eye.joint, Vector3.RIGHT, deg_to_rad(14.0) * look.y * weight)
		if blink > 0.0:
			swell(eye.parts, eye.joint, Vector3(1.0, 1.0 - 0.85 * blink * weight, 1.0))
	var chain: Array = group("tongue").chain
	var wag: Array = []
	var curl: Array = []
	for k in range(chain.size()):
		var reach: float = smoothstep(8.0, 16.0, float(k))
		wag.append(deg_to_rad(6.0) * reach * sin(clock * 1.6 - float(k) * 0.45) * weight)
		curl.append(deg_to_rad(-7.0) * smoothstep(13.0, 17.0, float(k)) * (0.5 + 0.5 * sin(clock * 1.1)) * weight)
	chain_turns(chain, Vector3.UP, wag)
	chain_turns(chain, Vector3.RIGHT, curl)

static func _noise(n: int) -> float:
	## A steady random number in -1..1 for each whole step.
	var h: int = (n * 73856093) ^ 19349663
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 2001) / 1000.0 - 1.0

func _mimic_gulp(clip: Dictionary, _delta: float) -> void:
	## Its tongue whips up at the party and back in, and the lid slams on what it caught.
	var t: float = float(clip.t)
	var lick: float = smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.16, 0.3, t))
	var chain: Array = group("tongue").chain
	var lift: Array = []
	for k in range(chain.size()):
		lift.append(deg_to_rad(-16.0) * smoothstep(9.0, 13.0, float(k)) * lick)
	chain_turns(chain, Vector3.RIGHT, lift)
	var shut: float = smoothstep(0.22, 0.3, t) * (1.0 - smoothstep(0.55, 0.95, t))
	var lid: Dictionary = group("lid")
	turn(lid.parts, lid.joint, Vector3.RIGHT, deg_to_rad(100.0) * shut)
	_creature.set("_rear", -0.35 * smoothstep(0.24, 0.3, t) * (1.0 - smoothstep(0.4, 0.8, t)))
	_rear_held = true
	if t >= HIT:
		_queue(clip, "gulp", "puff", {"from": "Mouth01", "color": "#ffd060", "amount": 10, "size": 0.8, "glow": true})

var _rear_held: bool = false

# --- the Seep Eel: swims where it hangs, sparks crawling on it ---------------------------------

## Its spine, tail to head (recipe units).
const EEL_SPINE: Array = [Vector3(-1.25, 0.10, -0.30), Vector3(-0.75, 0.22, 0.10), Vector3(-0.30, 0.36, -0.25), Vector3(0.15, 0.46, 0.15),
	Vector3(0.55, 0.55, -0.15), Vector3(0.85, 0.75, 0.25), Vector3(1.00, 0.95, 0.55), Vector3(1.08, 1.02, 0.70)]

func _swimmers() -> Array:
	## Every part along its body with how far it is from the head and which way is sideways there.
	if _groups.has("__swim"):
		return _groups["__swim"].list
	var out: Array = []
	var lengths: Array = [0.0]
	for i in range(EEL_SPINE.size() - 1, 0, -1):
		lengths.push_front(float(lengths[0]) + (EEL_SPINE[i] as Vector3).distance_to(EEL_SPINE[i - 1]))
	## lengths[i]: distance from pc[i] to the head along the spine.
	for part in _select(["Body", "Spot", "Collar", "Spine", "Tail"]):
		var at: Vector3 = centre_of(part)
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
	_groups["__swim"] = {"list": out, "parts": [], "joint": Vector3.ZERO, "chain": []}
	return out

func _idle_eel(clock: float, weight: float) -> void:
	## A swimming wave running down it from the head to the tail, more as it goes, and the head
	## turning a little into each stroke.
	for item in _swimmers():
		var s: float = float(item[1])
		shift([item[0]], (item[2] as Vector3) * 0.075 * sin(clock * 2.6 - s * 2.4) * clampf(s / 1.2, 0.15, 1.0) * weight)
	var head: Dictionary = group("head")
	turn(head.parts, head.joint, Vector3.UP, deg_to_rad(5.0) * sin(clock * 2.6 + 0.6) * weight)

# --- the Lamprey Knot and the Crystal Hydra: one head of several strikes -----------------------

const LAMPREY_HEADS: Array = [["Head01-04", "Mouth01-07"], ["Head05-08", "Mouth08-14"], ["Head09-12", "Mouth15-21"]]
const LAMPREY_FACING: Array = [Vector3(-0.27, 0.49, -0.83), Vector3(0.85, 0.49, 0.18), Vector3(-0.58, 0.49, 0.65)]

func _lamprey_bite(clip: Dictionary, _delta: float) -> void:
	## The heads that face the party take turns: one swings round at it, lunges, and its sucker
	## flares wide as it lands.
	var which: int = [2, 1][int(clip.strike) % 2]
	var parts: Array = _select(LAMPREY_HEADS[which])
	if parts.is_empty():
		return
	var joint: Vector3 = (parts[0] as Node3D).get("_rest").origin
	var facing: Vector3 = LAMPREY_FACING[which]
	var toward := Vector3(0, -0.15, 1).normalized()
	var axis: Vector3 = facing.cross(toward).normalized()
	var reach: float = minf(facing.angle_to(toward) * 0.65, deg_to_rad(55.0))
	var v: float = value("attack", float(clip.t))
	var mouth: Array = _select(LAMPREY_HEADS[which][1])
	if not mouth.is_empty():
		swell(mouth, (mouth[0] as Node3D).get("_rest").origin, Vector3.ONE * (1.0 + 0.4 * maxf(v, 0.0)))
	turn(parts, joint, axis, deg_to_rad(-18.0) * maxf(-v, 0.0) + reach * maxf(v, 0.0))
	shift(parts, toward * 0.18 * maxf(v, 0.0))
	_creature.set("_rear", -0.25 * maxf(v, 0.0))
	_rear_held = true

func _lamprey_drink(clip: Dictionary, _delta: float) -> void:
	## Every sucker flares and pulls, the braid squeezing as it drinks.
	var t: float = float(clip.t)
	var pull: float = smoothstep(0.1, HIT, t) * (1.0 - smoothstep(0.9, 1.25, t))
	for which in range(3):
		var mouth: Array = _select(LAMPREY_HEADS[which][1])
		if not mouth.is_empty():
			swell(mouth, (mouth[0] as Node3D).get("_rest").origin, Vector3.ONE * (1.0 + (0.25 + 0.12 * sin(t * 18.0 + float(which))) * pull))
	var braid: Array = _select(["Body"])
	swell(braid, Vector3(0, 0.5, 0), Vector3(1.0 - 0.08 * pull, 1.0 + 0.04 * pull, 1.0 - 0.08 * pull))
	if t >= 0.15:
		_queue(clip, "drain", "drain", {"from": "Mouth15", "color": "#ff6a7a", "count": 5})

const HYDRA_HEADS: Array = [
	{"neck": "Neck01-03", "head": "Head01-07", "jaw": "Jaw01", "mouth": "Mouth01", "axis": Vector3(0.99, 0, -0.15)},
	{"neck": "Neck04-06", "head": "Head08-14", "jaw": "Jaw02", "mouth": "Mouth02", "axis": Vector3(1, 0, 0)},
	{"neck": "Neck07-09", "head": "Head15-21", "jaw": "Jaw03", "mouth": "Mouth03", "axis": Vector3(0.29, 0, 0.96)}]

func _hydra_bite(clip: Dictionary, _delta: float) -> void:
	## Its heads take turns: the jaw drops, the head lunges on its neck and snaps shut.
	var spec: Dictionary = HYDRA_HEADS[(int(clip.strike) - 1) % 3]
	_hydra_head(spec, float(clip.t), 1.0)

func _hydra_head(spec: Dictionary, t: float, size: float) -> void:
	var axis: Vector3 = spec.axis
	var jaw: Array = _select(spec.jaw)
	var head: Array = _select([spec.head, spec.jaw, spec.mouth])
	var neck: Array = _select([spec.neck, spec.head, spec.jaw, spec.mouth])
	if jaw.is_empty() or head.is_empty() or neck.is_empty():
		return
	var open: float = value("snap", t)
	turn(jaw, (jaw[0] as Node3D).get("_rest").origin, axis, deg_to_rad(38.0 * maxf(-open, 0.0) - 4.0 * maxf(open, 0.0)) * size)
	var v: float = value("attack", t)
	turn(head, (head[0] as Node3D).get("_rest").origin, axis, deg_to_rad(-22.0 * maxf(-v, 0.0) + 24.0 * maxf(v, 0.0)) * size)
	turn(neck, (neck[0] as Node3D).get("_rest").origin, axis, deg_to_rad(-10.0 * maxf(-v, 0.0) + 16.0 * maxf(v, 0.0)) * size)

func _hydra_roar(clip: Dictionary, _delta: float) -> void:
	## Every head rears and opens its jaws: another grows.
	var t: float = float(clip.t)
	var up: float = smoothstep(0.0, HIT, t) * (1.0 - smoothstep(0.7, 1.1, t))
	for spec in HYDRA_HEADS:
		var jaw: Array = _select(spec.jaw)
		var head: Array = _select([spec.head, spec.jaw, spec.mouth])
		if jaw.is_empty() or head.is_empty():
			continue
		turn(jaw, (jaw[0] as Node3D).get("_rest").origin, spec.axis, deg_to_rad(35.0) * up)
		turn(head, (head[0] as Node3D).get("_rest").origin, spec.axis, deg_to_rad(-25.0) * up)
	if t >= HIT:
		_queue(clip, "sparks", "sparks", {"from": "centre", "color": "#c070ff", "amount": 30, "speed": 3.5})

# --- the Drowned Choir: heads that sing ---------------------------------------------------------

const CHOIR: Array = [
	{"parts": ["Neck01-05", "Head01-03", "Mouth01-02", "Rope"], "head": "Head01", "mouth": "Mouth01", "root": Vector3(-0.60, 0.02, 0.30)},
	{"parts": ["Neck06-10", "Head04-06", "Mouth03-04", "Weed01"], "head": "Head04", "mouth": "Mouth03", "root": Vector3(0.05, 0.02, -0.25)},
	{"parts": ["Neck11-15", "Head07-09", "Mouth05-06"], "head": "Head07", "mouth": "Mouth05", "root": Vector3(0.70, 0.02, 0.20)},
	{"parts": ["Neck16-18", "Head10", "Mouth07-08"], "head": "Head10", "mouth": "Mouth07", "root": Vector3(-0.30, 0.02, 0.85)},
	{"parts": ["Neck19-21", "Head11", "Mouth09-10"], "head": "Head11", "mouth": "Mouth09", "root": Vector3(0.45, 0.02, 0.80)}]
## Which heads sing each of its moves, and in what color the song goes out.
const CHOIR_SONGS: Dictionary = {
	"Dirge": {"voices": [1], "color": "#6ab8e0"}, "Requiem": {"voices": [0, 2], "color": "#8fd0e8"},
	"Requiem Chorus": {"voices": [0, 1, 2], "color": "#c8f0ff", "big": true}, "Lament": {"voices": [3, 4], "color": "#c58bff"},
	"Another Voice": {"voices": [3, 4, 1], "color": "#8fd0e8"}}

func _choir_sing(clip: Dictionary, _delta: float) -> void:
	## The singers whose song it is throw their heads back and open their mouths wide, leaning
	## toward the party as the note lands, and it rolls out of them in rings.
	var song: Dictionary = CHOIR_SONGS.get(str(clip.move), CHOIR_SONGS.Dirge)
	var t: float = float(clip.t)
	var big: bool = bool(song.get("big", false))
	var sing: float = smoothstep(0.05, HIT, t) * (1.0 - smoothstep(0.75 if not big else 1.0, 1.15 if not big else 1.4, t))
	var lean: float = smoothstep(HIT - 0.1, HIT, t) * (1.0 - smoothstep(HIT + 0.2, 0.9, t))
	for index in song.voices:
		var singer: Dictionary = CHOIR[int(index)]
		var whole: Array = _select(singer.parts)
		var head: Array = _select([singer.head, singer.mouth, str(singer.mouth).left(5) + "%02d" % (int(str(singer.mouth).right(2)) + 1)])
		var ring: Array = _select(singer.mouth)
		if whole.is_empty() or head.is_empty() or ring.is_empty():
			continue
		var head_at: Vector3 = centre_of(_named[singer.head])
		var ring_at: Vector3 = centre_of(ring[0])
		swell(ring, ring_at, Vector3.ONE * (1.0 + (0.7 if big else 0.5) * sing))
		turn(head, head_at, Vector3.RIGHT, deg_to_rad(-28.0) * sing)
		turn(whole, singer.root, Vector3.RIGHT, deg_to_rad(7.0) * lean)
		var color: String = str(song.color)
		for wave in range(3 if big else 2):
			if t >= HIT - 0.06 + 0.13 * float(wave):
				_queue(clip, "ring%d_%d" % [int(index), wave], "ripple", {"from": singer.mouth, "color": color, "radius": 1.3 + 0.6 * float(wave), "size": 1.0})

# --- idles of the Furnace and the Warrens ----------------------------------------------------

func _idle_smelter(clock: float, weight: float) -> void:
	## Its volcano bubbling: the lava pool heaving, and every few seconds a blorp that jolts the
	## rim rocks.
	var lava: Array = _select(["Lava01"])
	var p: float = fmod(clock, 3.4)
	var blorp: float = sin(clampf(p / 0.45, 0.0, 1.0) * PI)
	for part in lava:
		swell([part], centre_of(part), Vector3(1.0 + 0.12 * blorp, 1.0 + 0.5 * blorp, 1.0 + 0.12 * blorp) * 1.0)
	var rim: Array = _select(["Crater02-07"])
	shift(rim, Vector3(0, 0.035 * blorp * weight, 0))
	swell_each(_select(["Lava02-05"]), Vector3(1.0, 1.0 + 0.6 * blorp * weight, 1.0))

func _idle_heartbeat(clock: float, weight: float) -> void:
	## A slow double thump.
	var p: float = fmod(clock, 1.6)
	var thump: float = exp(-pow((p - 0.1) / 0.06, 2.0)) + 0.7 * exp(-pow((p - 0.36) / 0.06, 2.0))
	var heart: Dictionary = group("heart")
	swell(heart.parts, heart.joint, Vector3.ONE * (1.0 + 0.07 * thump * weight))

# --- the Entropy Eye: its aperture ------------------------------------------------------------

const ENTROPY_PETALS: Array = [["Petal01", "Petal02"], ["Petal03"], ["Petal04"], ["Petal05", "Petal06"], ["Petal07"], ["Petal08"],
	["Petal09", "Petal10"], ["Petal11"], ["Petal12"], ["Petal13", "Petal14"]]

func _aperture(close: float) -> void:
	## Every petal folds in over the iris about its ring tangent: 1 is shut.
	if absf(close) < 0.0001:
		return
	for k in range(ENTROPY_PETALS.size()):
		var parts: Array = _select(ENTROPY_PETALS[k])
		if parts.is_empty():
			continue
		var a: float = 0.2 + float(k) * deg_to_rad(36.0)
		turn(parts, (parts[0] as Node3D).get("_rest").origin, Vector3(-sin(a), cos(a), 0.0), deg_to_rad(-95.0) * close)

func _entropy_stare(clip: Dictionary, _delta: float) -> void:
	_aperture(0.45 * smoothstep(0.0, HIT, float(clip.t)) * (1.0 - smoothstep(0.7, 1.05, float(clip.t))))

func _entropy_unmake(clip: Dictionary, _delta: float) -> void:
	## The aperture snaps shut on the blow and opens again.
	var t: float = float(clip.t)
	_aperture(smoothstep(HIT - 0.08, HIT, t) * (1.0 - smoothstep(0.55, 1.0, t)) + 0.25 * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.2, HIT, t)))

func _idle_hush(clock: float, weight: float) -> void:
	## A swimming wave running down its body from the head.
	var chain: Array = group("body").chain
	var angles: Array = []
	for index in range(chain.size()):
		angles.append(deg_to_rad(2.4) * sin(clock * 2.0 - float(index) * 0.45) * weight)
	chain_turns(chain, Vector3.UP, angles)

func _timeglass_turn(clip: Dictionary, _delta: float) -> void:
	## Turns itself over, all the way round: time run back.
	var t: float = float(clip.t)
	var spin: float = smoothstep(0.05, 0.75, t)
	var body: Dictionary = group("glass")
	turn(body.parts, body.joint, Vector3.RIGHT, TAU * spin)
	if t >= HIT:
		_queue(clip, "spiral", "spiral", {"from": "Sand03", "color": "#ffe8a0", "amount": 30})
