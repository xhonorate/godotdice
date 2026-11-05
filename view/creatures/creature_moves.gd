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
## head turns about the neck). What each creature does is data, one file a mine
## (view/creatures/rigs/<mine>.gd, merged by creature_rigs.gd); the few things no table says (a
## mole digging in, a tendril unfurling, a mimic's tongue) are functions there too, called with
## this node as `m`.
##
## The screen calls `play` 0.3 s before the move lands (`HIT`): every attack is timed to strike
## then. A creature with no named parts, or no gesture for the move, says no and the creature
## falls back on its old lunge or channel.
##
## Pass 2 (November 3, 2026): fidgets, the intermittent things a creature does while it waits
## (the Drill lifting its head to look about), each on its own random clock; trope idles as data
## (a jellyfish's swim, a snake's slither, breathing, looking about, blinking...); and heavy
## blows, a creature's big attack held at its wind pose with a shiver and a charge before it
## lands past its strike pose and freezes there a moment.

const Part = preload("res://view/creatures/creature_part.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")
const Rigs = preload("res://view/creatures/creature_rigs.gd")

const HIT: float = Rigs.HIT
## A clip is let go this long after its last key, so the parts are seen back at rest.
const TAIL: float = 0.05
## A heavy blow (DeepCreatures.heavy_moves) holds its wind pose `heavy` seconds longer (the
## screen starts it that much sooner), winding a little tighter as it holds (DEEPEN); it lands
## past its strike pose (OVERSHOOT) and freezes there a moment (HITSTOP).
const HITSTOP: float = 0.07
const DEEPEN: float = 0.3
const OVERSHOOT: float = 0.3
## Fidgets come on their own only while this is set. The tests clear it, so a creature and a
## twin stepped alongside it stay alike (every creature's noise is then seeded the same, too).
static var lively: bool = true

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
## The mine script (view/creatures/rigs/<mine>.gd) that holds this scene's own functions.
var _owner: Script = null
## Its own random clock: when it next fidgets and which, the targets it looks about at, and the
## seed its idles' noise is salted with, so two of a kind in one room never move in step.
var noise_seed: int = 0
var _rng := RandomNumberGenerator.new()
var _fidget_wait: float = 0.0
## The fidget playing now (a clip like a move's), or empty.
var _fidget: Dictionary = {}
var _last_fidget: String = ""

func _init(creature: Node3D, body: Node3D, scene_key: String) -> void:
	name = "Moves"
	_creature = creature
	_body = body
	looks = scene_key
	for child in body.get_children():
		if child is Part:
			_named[str(child.name)] = child
	_rig = Rigs.rig(scene_key)
	_owner = Rigs.owner_of(scene_key)
	reseed(randi() if lively else 0)
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

func play(anim: String, move: String = "", hostile: bool = true, aim: Vector3 = Vector3.INF, fx: Node = null, heavy: float = 0.0) -> bool:
	## Acts out a move; false when this creature has nothing of its own for it. `heavy` is how
	## much longer a heavy blow holds its wind pose (the screen starts it that much sooner): its
	## rig's own heavy version if it wrote one, its move stretched at the wind otherwise.
	var spec: Variant = _spec_for(anim, move, hostile)
	if spec == null:
		return false
	var big: Dictionary = _heavy_spec(spec, anim, move) if heavy > 0.0 else {}
	if big.has("do"):
		spec = big.do
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
	clip.end = float(clip.length)
	if heavy > 0.0:
		clip.heavy = heavy
		clip.big = big
		clip.wind = float(big.get("wind", _wind_of(clip)))
		clip.end = float(clip.length) + heavy + HITSTOP
	if anim == "erupt" and _dig_state in ["waiting", "under"]:
		_dig_state = "erupting"
		_dig = 0.0
	_strikes += 1
	clip.strike = _strikes
	_clips.append(clip)
	_cut_fidget()
	return true

func _heavy_spec(spec: Variant, anim: String, move: String) -> Dictionary:
	## What a rig wrote for a move's heavy version: on the move itself (`"heavy": {...}` in a move
	## written as a dictionary) or in its `heavy` table by move name or anim. See creature_rigs.gd.
	if spec is Dictionary and (spec as Dictionary).has("heavy"):
		return spec.heavy
	var table: Dictionary = _rig.get("heavy", {})
	move = str(_rig.get("alias", {}).get(move, move))
	if table.has(move):
		return table[move]
	if table.has(anim):
		return table[anim]
	return {}

func _wind_of(clip: Dictionary) -> float:
	## When a move is wound back furthest before its blow (its keys' time): where a heavy one
	## holds. A move with no wind (a breath that only opens) holds just before its blow.
	if clip.has("custom"):
		return float(Rigs.CUSTOM_WIND.get(str(clip.custom), HIT - 0.08))
	var best: float = HIT - 0.1
	var deepest: float = -0.05
	var k: float = 0.04
	while k <= HIT - 0.015:
		var sum: float = 0.0
		for g in clip.gestures:
			var at: int = int(ENVELOPE_AT.get(str(g[0]), -1))
			if at > 0 and g.size() > at:
				sum += minf(0.0, value(g[at], k))
		if sum < deepest - 0.002:
			deepest = sum
			best = k
		elif sum < -0.05 and sum <= deepest + 0.002:
			best = k
		k += 0.01
	return best

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

# --- fidgets ---------------------------------------------------------------------------------

func reseed(n: int) -> void:
	## Its random clock from this seed: the films and tests set one so a take plays the same.
	noise_seed = n
	_rng.seed = n
	var every: Array = _rig.get("fidget_every", [5.0, 10.0])
	_fidget_wait = _rng.randf_range(float(every[0]) * 0.3, float(every[1]))

func fidget_names() -> Array:
	return _rig.get("fidgets", {}).keys()

func fidgeting() -> bool:
	return not _fidget.is_empty()

func fidget(name: String = "") -> bool:
	## Plays one of its fidgets now (one picked by weight when no name is given); false if it has
	## none by that name. A move started across it takes over (see `_cut_fidget`).
	var all: Dictionary = _rig.get("fidgets", {})
	if all.is_empty():
		return false
	if name.is_empty():
		name = _pick_fidget()
	if not all.has(name):
		return false
	var spec: Dictionary = all[name]
	var gestures: Array = spec.get("do", [])
	var length: float = float(spec.get("length", maxf(2.0, _length_of(gestures))))
	var hold: float = clampf(float(spec.get("hold", length * 0.4)), 0.0, length - 0.2)
	var ease: float = (length - hold) * 0.5
	_fidget = {"fidget": name, "anim": "fidget", "move": name, "t": 0.0, "shift": 0.0, "gestures": gestures,
		"length": length, "end": length, "span": length, "f": [[0.0, 0.0], [ease, 1.0], [ease + hold, 1.0], [length, 0.0]],
		"idle": float(spec.get("idle", 1.0)), "weight": 1.0, "fired": {}, "spun": {}, "aim": Vector3.INF,
		"fx": _last_fx, "hostile": false, "strike": 0}
	_last_fidget = name
	return true

func _pick_fidget() -> String:
	## One of its fidgets by weight, not the one it did last if it has others.
	var all: Dictionary = _rig.get("fidgets", {})
	var table: Dictionary = {}
	var total: float = 0.0
	for name in all:
		if str(name) == _last_fidget and all.size() > 1:
			continue
		var weight: float = float(all[name].get("weight", 1.0))
		table[name] = weight
		total += weight
	var roll: float = _rng.randf() * total
	for name in table:
		roll -= float(table[name])
		if roll <= 0.0:
			return str(name)
	return str(table.keys().back()) if not table.is_empty() else ""

func _cut_fidget() -> void:
	## A move (or digging in, or fleeing) cuts across a fidget: it fades out over a quarter of a
	## second instead of popping back, and the next one waits a while.
	if not _fidget.is_empty():
		_fidget.fading = true
	var every: Array = _rig.get("fidget_every", [5.0, 10.0])
	_fidget_wait = maxf(_fidget_wait, float(every[0]) * 0.5)

func _still() -> bool:
	## Fully idle: not acting, stunned, slumped, dug in, faded, buried, charging, fleeing or dying.
	if not _clips.is_empty() or not _creature.visible or bool(_creature.get("_dying")):
		return false
	if float(_creature.get("_slump")) > 0.02 or float(_creature.get("_buried")) > 0.001 or float(_creature.get("_charging")) > 0.0:
		return false
	return _dig <= 0.001 and _dig_state.is_empty() and _fade <= 0.001 and _fade_want <= 0.0

func _schedule(delta: float) -> void:
	## Counts down to its next fidget while it is fully idle, and plays it.
	if not lively or not _fidget.is_empty() or not _rig.has("fidgets") or not _still():
		return
	_fidget_wait -= delta
	if _fidget_wait <= 0.0:
		var every: Array = _rig.get("fidget_every", [5.0, 10.0])
		_fidget_wait = _rng.randf_range(float(every[0]), float(every[1]))
		fidget()

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
	if down:
		_cut_fidget()
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
	_cut_fidget()
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
	## The idle eases out under a move, and to a fidget's own share of it (a jellyfish's swim gives
	## way to the bigger swim of its fidget; a drill's heave goes on as it looks about).
	var idle_want: float = 1.0
	if not _clips.is_empty():
		idle_want = 0.0
	elif not _fidget.is_empty():
		idle_want = float(_fidget.get("idle", 1.0)) if not _fidget.has("fading") else 1.0
	_idle_weight = move_toward(_idle_weight, idle_want, delta * 3.0)
	var idle: String = str(_rig.get("idle", ""))
	if not idle.is_empty() and _idle_weight > 0.001:
		_run(idle, [_clock, _idle_weight])
	for gesture in _rig.get("idle_gestures", []):
		if _idle_weight > 0.001:
			_idle_gesture(gesture, _idle_weight)
	_states(delta)
	_schedule(delta)
	var due: Array = []
	var drove_rear: bool = false
	_rear_held = false
	var playing: Array = _clips.duplicate()
	if not _fidget.is_empty():
		playing.append(_fidget)
	for clip in playing:
		clip.t = float(clip.t) + delta
		var fading: bool = clip.has("fading")
		if fading:
			clip.weight = move_toward(float(clip.get("weight", 1.0)), 0.0, delta * 4.0)
		## A move that starts early (its lead) is laid on as though it started at its lead less
		## HIT: its keys stay written against the blow at HIT. A heavy one's keys are held at its
		## wind and frozen a moment at the blow (`_keyed`).
		var keyed: float = _keyed(clip)
		clip.keyed = keyed
		if clip.has("custom"):
			var real: float = float(clip.t)
			clip.t = keyed + float(clip.get("shift", 0.0))
			_run(str(clip.custom), [clip, delta])
			clip.t = real
		else:
			for gesture in clip.gestures:
				if str(gesture[0]) == "fx":
					if keyed >= float(gesture[1]) and not clip.fired.has(gesture) and not fading:
						clip.fired[gesture] = true
						due.append([clip, gesture[2], gesture[3] if gesture.size() > 3 else {}])
				elif str(gesture[0]) == "rear":
					drove_rear = true
					_gesture(clip, gesture, delta)
				else:
					_gesture(clip, gesture, delta)
		if float(clip.get("heavy", 0.0)) > 0.0:
			_heavy_beat(clip, delta)
		for queued in clip.get("queued", []):
			due.append([clip, queued[0], queued[1]])
		clip.queued = []
		if float(clip.t) >= float(clip.get("end", clip.length)) + TAIL or (fading and float(clip.weight) <= 0.0):
			if clip.has("fidget"):
				_fidget = {}
			else:
				_clips.erase(clip)
				if _clips.is_empty():
					_cut_fidget()
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

# --- heavy blows -------------------------------------------------------------------------------

func _keyed(clip: Dictionary) -> float:
	## Where a move stands in its own keys: its clock less its lead; a heavy blow's held at its
	## wind pose for the hold, then on to the blow, frozen there for HITSTOP, then on.
	var tau: float = float(clip.t) - float(clip.get("shift", 0.0))
	var hold: float = float(clip.get("heavy", 0.0))
	if hold <= 0.0:
		return tau
	var wind: float = float(clip.wind)
	if tau <= wind:
		return tau
	if tau <= wind + hold:
		return wind
	if tau <= HIT + hold:
		return tau - hold
	if tau <= HIT + hold + HITSTOP:
		return HIT
	return tau - hold - HITSTOP

func _hold_env(clip: Dictionary) -> float:
	## The "h" envelope: 0 to 1 as a heavy blow winds back, 1 through its hold, gone as it lets
	## go. A rig's heavy `pose` gestures ride it (a head reared higher while it strains).
	var hold: float = float(clip.get("heavy", 0.0))
	if hold <= 0.0:
		return 0.0
	var tau: float = float(clip.t) - float(clip.get("shift", 0.0))
	var wind: float = float(clip.wind)
	return smoothstep(0.0, maxf(0.05, wind), tau) * (1.0 - smoothstep(wind + hold, wind + hold + 0.06, tau))

func _heavy_beat(clip: Dictionary, delta: float) -> void:
	## A heavy blow's hold: it shivers with the strain and glows hotter, a charge gathering at
	## what it strikes with and dust lifting under it, until it lets go; it flares as it lands.
	var tau: float = float(clip.t) - float(clip.get("shift", 0.0))
	var wind: float = float(clip.wind)
	var hold: float = float(clip.heavy)
	var big: Dictionary = clip.get("big", {})
	for g in big.get("pose", []):
		_gesture(clip, g, delta)
	var strain: float = smoothstep(wind * 0.5, wind + 0.1, tau) * (1.0 - smoothstep(wind + hold - 0.05, wind + hold, tau))
	if strain > 0.001:
		var shiver := Vector3(sin(tau * 61.0), 0.5 * sin(tau * 47.0 + 1.0), sin(tau * 53.0 + 2.0)) * 0.016 * float(big.get("shiver", 1.0)) * strain
		_lean = Transform3D(Basis.IDENTITY, shiver) * _lean
		_leaning = true
		_creature.call("flash", 0.15 + 0.5 * strain)
	if tau >= wind and not clip.fired.has("__charge"):
		clip.fired["__charge"] = true
		if big.has("charge"):
			var index: int = 0
			for item in big.charge:
				_queue(clip, "__charge%d" % index, str(item[0]), item[1] if item.size() > 1 else {})
				index += 1
		else:
			var at: String = _strike_from(clip)
			_queue(clip, "__glow", "charge_glow", {"from": at, "seconds": hold + 0.12})
			_queue(clip, "__dust", "charge_dust", {"seconds": hold})
			if bool(_creature.get("warden")):
				_queue(clip, "__pull", "spiral", {"from": at, "amount": 26})
	if tau >= HIT + hold and not clip.fired.has("__impact"):
		clip.fired["__impact"] = true
		_creature.call("flash", 1.3)
		var index: int = 0
		for item in big.get("impact", []):
			_queue(clip, "__impact%d" % index, str(item[0]), item[1] if item.size() > 1 else {})
			index += 1

func _strike_from(clip: Dictionary) -> String:
	## What a heavy blow strikes with, where its charge gathers: the rig's heavy `at`, the place
	## its blow's own effect leaves from, its mouth, its middle.
	var big: Dictionary = clip.get("big", {})
	if big.has("at"):
		return str(big.at)
	for g in clip.get("gestures", []):
		if str(g[0]) == "fx" and float(g[1]) >= 0.2 and g.size() > 3 and (g[3] as Dictionary).has("from"):
			return str(g[3].from)
	if _rig.has("mouth"):
		return "mouth"
	return "centre"

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
			## Each segment turns about its first part's pivot, or about the joint `joints` gives it
			## (where two drums of an arch meet, not the middle of one).
			var joints: Array = spec.get("joints", [])
			for index in range(spec.chain.size()):
				var parts: Array = _select(spec.chain[index]).duplicate()
				if parts.is_empty():
					continue
				var joint: Vector3 = joints[index] if index < joints.size() else (parts[0] as Node3D).get("_rest").origin
				out.chain.append({"parts": parts, "joint": joint})
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

static func value(keys: Variant, t: float, length: float = WOBBLE) -> float:
	## Where a move stands at time t: -1 is fully wound back, +1 the blow, 0 rest. The keys are
	## [time, value] pairs; a short climb to a blow eases in (it lands fast), the rest smoothly.
	## A few are oscillations instead, over `length` (a fidget's own): a flutter of wings, a
	## shudder, claws scrabbling, a pant, a tail wagging.
	var named: Variant = Rigs.ENV.get(keys, []) if keys is String else keys
	if named is String:
		var bell: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(length - 0.25, length, t))
		match str(named):
			"~flutter":
				return 0.5 * (1.0 + sin(t * 38.0 - PI * 0.5)) * bell
			"~shake":
				return sin(t * 34.0) * bell
			"~scrabble":
				return 0.5 * (1.0 + sin(t * 30.0 - PI * 0.5)) * bell
			"~pant":
				return 0.5 * (1.0 - cos(t * 19.0)) * bell
			"~tremble":
				return sin(t * 47.0) * 0.6 * bell
			"~wag":
				return sin(t * 20.0) * bell
			"~flap":
				return 0.5 * (1.0 + sin(t * 15.0 - PI * 0.5)) * bell
			"~chew":
				return 0.5 * (1.0 - cos(t * 11.0)) * bell
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
	"splay": 4, "whirl": 4, "whirl_own": 4, "spread": 4, "hop": 3, "spin": 3, "rear": 2, "gaze": 4, "tremble": 3, "wave_each": 6}

func _v(clip: Dictionary, keys: Variant, t: float) -> float:
	## An envelope at t for this clip: a fidget's own rise, hold and fall ("f"), a heavy blow's
	## hold ("h"), an oscillation lasting the fidget; a heavy blow's wind deepened as it holds and
	## its blow overshot as it lands; all of it faded by the clip's weight (a fidget a move cut).
	var v: float
	if keys is String and str(keys) == "f":
		v = value(clip.get("f", []), t)
	elif keys is String and str(keys) == "h":
		v = _hold_env(clip)
	elif keys is String and clip.has("span") and Rigs.ENV.get(keys, null) is String:
		v = value(keys, t, float(clip.span))
	else:
		v = value(keys, t)
	var hold: float = float(clip.get("heavy", 0.0))
	if hold > 0.0 and not (keys is String and str(keys) == "h"):
		var tau: float = float(clip.t) - float(clip.get("shift", 0.0))
		if v < 0.0:
			v *= 1.0 + DEEPEN * smoothstep(0.0, float(clip.wind) + hold, tau)
		elif v > 0.0:
			var x: float = (tau - (HIT + hold + HITSTOP * 0.5)) / 0.09
			v *= 1.0 + OVERSHOOT * exp(-x * x)
	return v * float(clip.get("weight", 1.0))

func _turns(clip: Dictionary, g: Array, turns: float, keys: Variant, t: float) -> float:
	## How far round a spin or a whirl is (whole turns at its end): its envelope's share so far,
	## and on a heavy blow some whole turns more through the hold, speeding up as it strains.
	var out: float = turns * _progress(clip, str(g), keys, t)
	var hold: float = float(clip.get("heavy", 0.0))
	if hold > 0.0 and absf(turns) > 0.0:
		var x: float = clampf((float(clip.t) - float(clip.get("shift", 0.0)) - float(clip.wind)) / hold, 0.0, 1.0)
		out += signf(turns) * maxf(1.0, roundf(absf(turns) * hold * 1.5)) * x * x
	return out * float(clip.get("weight", 1.0))


func _progress(clip: Dictionary, key: String, keys: Variant, t: float) -> float:
	## How far through its whole turn a spin is at t: the envelope's area so far over all of it,
	## so it speeds up and runs down with the envelope and ends exactly where it began.
	if not clip.has("areas"):
		clip.areas = {}
	if keys is String and str(keys) == "f":
		keys = clip.get("f", [])
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
			"swim":
				longest = maxf(longest, _swim_length(gesture[1]))
			_:
				if ENVELOPE_AT.has(kind) and gesture.size() > int(ENVELOPE_AT[kind]):
					longest = maxf(longest, _span_of(gesture[int(ENVELOPE_AT[kind])]))
	return longest

func _gesture(clip: Dictionary, g: Array, delta: float) -> void:
	var t: float = float(clip.get("keyed", float(clip.t) - float(clip.get("shift", 0.0))))
	match str(g[0]):
		"turn":
			## ["turn", group, axis, wind degrees, strike degrees, envelope]
			var v: float = _v(clip, g[5], t)
			var angle: float = deg_to_rad(float(g[3]) * -v if v < 0.0 else float(g[4]) * v)
			var gr: Dictionary = group(str(g[1]))
			turn(gr.parts, gr.joint, g[2], angle)
		"turn_each":
			## ["turn_each", group, axis, wind degrees, strike degrees, envelope]: every part about
			## its own pivot (six tendrils, each hung from its own root).
			var v: float = _v(clip, g[5], t)
			var angle: float = deg_to_rad(float(g[3]) * -v if v < 0.0 else float(g[4]) * v)
			for part in group(str(g[1])).parts:
				turn([part], (part as Node3D).get("_rest").origin, g[2], angle)
		"splay":
			## ["splay", group, wind degrees, strike degrees, envelope]: every part about its own
			## pivot, its far end swinging out from the group's joint (a positive angle opens a
			## hanging fringe).
			var v: float = _v(clip, g[4], t)
			var angle: float = deg_to_rad(float(g[2]) * -v if v < 0.0 else float(g[3]) * v)
			splay(group(str(g[1])), angle)
		"move":
			## ["move", group, wind offset, strike offset, envelope]
			var v: float = _v(clip, g[4], t)
			var by: Vector3 = (g[2] as Vector3) * -v if v < 0.0 else (g[3] as Vector3) * v
			shift(group(str(g[1])).parts, by)
		"grow", "each":
			## ["grow", group, wind, strike, envelope]: a swell about the group's joint (a float
			## for all three axes, or a Vector3), "each" about every part's own pivot.
			var v: float = _v(clip, g[4], t)
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
			var v: float = _v(clip, g[5], t)
			var angle: float = deg_to_rad(float(g[3]) * -v if v < 0.0 else float(g[4]) * v)
			curl(group(str(g[1])).chain, g[2], angle, str(g[6]) if g.size() > 6 else "even")
		"spin":
			## ["spin", group, whole turns, envelope]: about each part's own axle (a saw, a drill
			## bit, a wheel), faster where the envelope is high. Whole turns, so nothing jumps
			## when it lets go.
			spin(group(str(g[1])).parts, TAU * _turns(clip, g, float(g[2]), g[3], t))
		"whirl":
			## ["whirl", group, axis, whole turns, envelope]: the group turned about its joint the
			## same way (a halo, a wheel of petals, a ribbon whipped round).
			var gr: Dictionary = group(str(g[1]))
			turn(gr.parts, gr.joint, g[2], TAU * _turns(clip, g, float(g[3]), g[4], t))
		"whirl_own":
			## The same about an axis that turns with the group's own idle (a wheel of petals that
			## yaws as it idles spins about its own face, not the creature's).
			var gr: Dictionary = group(str(g[1]))
			if not gr.parts.is_empty():
				var first: Node3D = gr.parts[0]
				var now: Basis = first.transform.basis.orthonormalized() * ((first.get("_rest") as Transform3D).basis.orthonormalized().inverse())
				turn(gr.parts, gr.joint, now * (g[2] as Vector3), TAU * _turns(clip, g, float(g[3]), g[4], t))
		"spread":
			## ["spread", group, wind, strike, envelope]: each part pushed out from the group's
			## joint (level), by so much.
			var v: float = _v(clip, g[4], t)
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
			var v: float = _v(clip, g[2], t)
			_creature.set("_rear", float(g[1]) * -v)
		"lean":
			## ["lean", axis, wind degrees, strike degrees, pivot, envelope]: the whole body.
			var v: float = _v(clip, g[5], t)
			var angle: float = deg_to_rad(float(g[2]) * -v if v < 0.0 else float(g[3]) * v)
			if absf(angle) > 0.00001:
				var pivot: Vector3 = g[4]
				_lean = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis((g[1] as Vector3).normalized(), angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot) * _lean
				_leaning = true
		"hop":
			## ["hop", wind offset, strike offset, envelope]: the whole body moved.
			var v: float = _v(clip, g[3], t)
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
			_run(str(g[1]), [clip, delta])
		"wave_each":
			## ["wave_each", group, axis or "out", deg, rate, phase step, envelope]: each part about
			## its own pivot back and forth, one a beat behind the last (flagella rippling round a
			## bell, legs paddling); "out" swings each away from the group's joint and back.
			var v: float = _v(clip, g[6], t)
			if absf(v) > 0.00001:
				var gr: Dictionary = group(str(g[1]))
				var index: int = 0
				for part in gr.parts:
					var at: Vector3 = (part as Node3D).get("_rest").origin
					var axis: Vector3 = g[2] if g[2] is Vector3 else Vector3.ZERO
					if not g[2] is Vector3:
						var out: Vector3 = at - (gr.joint as Vector3)
						out.y = 0.0
						axis = out.cross(Vector3.UP) if not out.is_zero_approx() else Vector3.RIGHT
					turn([part], at, axis, deg_to_rad(float(g[3])) * sin(t * float(g[4]) - float(g[5]) * float(index)) * v)
					index += 1
		"gaze":
			## ["gaze", group, yaw deg, pitch deg, envelope, looks]: looks about at `looks` places
			## picked on its own random clock, easing from one to the next (a head raised to look
			## round the room). Pitch is laid first, the yaw over it.
			var v: float = _v(clip, g[4], t)
			if absf(v) > 0.00001:
				var looks: int = maxi(1, int(g[5]) if g.size() > 5 else 1)
				if not clip.has("picks"):
					clip.picks = {}
				var key: String = "gaze:" + str(g[1])
				if not clip.picks.has(key):
					## Off to one side and then the other, mostly level: looking round a room,
					## not nodding at it.
					var picked: Array = []
					var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
					for i in range(looks):
						picked.append(Vector2(side * _rng.randf_range(0.45, 1.0), _rng.randf_range(-1.0, 0.4)))
						side = -side
					clip.picks[key] = picked
				var targets: Array = clip.picks[key]
				var seg: float = maxf(0.2, float(clip.length) / float(looks))
				var k: int = clampi(int(t / seg), 0, looks - 1)
				var x: float = smoothstep(float(k) * seg, float(k) * seg + minf(0.7, seg * 0.45), t) if k > 0 else 1.0
				var dir: Vector2 = (targets[maxi(k - 1, 0)] as Vector2).lerp(targets[k], x)
				var gr: Dictionary = group(str(g[1]))
				turn(gr.parts, gr.joint, Vector3.RIGHT, deg_to_rad(float(g[3])) * dir.y * v)
				turn(gr.parts, gr.joint, Vector3.UP, deg_to_rad(float(g[2])) * dir.x * v)
		"tremble":
			## ["tremble", group, amount, envelope]: a fine shiver, strongest where the envelope is.
			var v: float = absf(_v(clip, g[3], t))
			var c: float = float(clip.t)
			shift(group(str(g[1])).parts, Vector3(sin(c * 53.0), 0.6 * sin(c * 41.0 + 1.0), sin(c * 47.0 + 2.0)) * float(g[2]) * v)
		"swim":
			## ["swim", spec]: a jellyfish swimming up in a few strong pulses and sinking slowly
			## back (see `_swim_clip`).
			_swim_clip(clip, g[1], t)

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
		"breathe":
			## ["breathe", group, swell, rate, phase]: a slow swell and back (a chest, a bell), never
			## smaller than at rest. `swell` is a float for all three axes or a Vector3.
			var gr: Dictionary = group(str(g[1]))
			var k: float = (0.5 - 0.5 * cos(_clock * float(g[3]) + float(g[4]))) * weight
			var amount: Vector3 = (g[2] as Vector3) if g[2] is Vector3 else Vector3.ONE * float(g[2])
			swell(gr.parts, gr.joint, Vector3.ONE + amount * k)
		"look":
			## ["look", group, yaw deg, pitch deg, beat s, ease s]: every beat or so the head picks
			## somewhere new to look (now and then straight ahead again) and eases there over `ease`
			## seconds, then holds; never twitchy. Driven by its own noise, so no two look alike.
			var gr: Dictionary = group(str(g[1]))
			var beat: float = maxf(0.6, float(g[4]))
			var ease: float = clampf(float(g[5]) if g.size() > 5 else 0.8, 0.45, beat)
			var step: int = int(floor(_clock / beat))
			var local: float = _clock - float(step) * beat
			var start: float = (beat - ease) * (0.25 + 0.25 * _noise(step * 5 + noise_seed + 3))
			var x: float = smoothstep(start, start + ease, local)
			var dir: Vector2 = _look_target(step - 1).lerp(_look_target(step), x)
			turn(gr.parts, gr.joint, Vector3.RIGHT, deg_to_rad(float(g[3])) * dir.y * weight)
			turn(gr.parts, gr.joint, Vector3.UP, deg_to_rad(float(g[2])) * dir.x * weight)
		"blink":
			## ["blink", group, shut, every s, phase]: once in about every `every` seconds, at a time
			## of its own, the eyes shut for 0.16 s (now and then twice). `shut` is the scale they
			## close to (a Vector3), or [axis, degrees] for a lid turned down over them. Two eyes
			## with the same `every` and phase blink together.
			var gr: Dictionary = group(str(g[1]))
			var every: float = maxf(0.8, float(g[3]))
			var c: float = _clock + (float(g[4]) if g.size() > 4 else 0.0)
			var step: int = int(floor(c / every))
			var local: float = c - float(step) * every - every * (0.15 + 0.3 * (1.0 + _noise(step * 3 + noise_seed + 11)))
			var b: float = 0.0
			if local > 0.0 and local < 0.16:
				b = sin(local / 0.16 * PI)
			elif local > 0.26 and local < 0.42 and _noise(step * 7 + noise_seed) > 0.5:
				b = sin((local - 0.26) / 0.16 * PI)
			b *= weight
			if b > 0.0:
				if g[2] is Vector3:
					swell(gr.parts, gr.joint, Vector3.ONE.lerp(g[2], b))
				else:
					turn(gr.parts, gr.joint, g[2][0], deg_to_rad(float(g[2][1])) * b)
		"flex":
			## ["flex", group, axis, degrees, every s, phase]: claws (or fingers, or a fan of
			## spines) opening slowly, holding, and snapping shut, about once every `every` seconds.
			var gr: Dictionary = group(str(g[1]))
			var every: float = maxf(1.0, float(g[4]))
			var c: float = _clock + float(g[5])
			var step: int = int(floor(c / every))
			var local: float = c - float(step) * every - every * (0.1 + 0.2 * (1.0 + _noise(step * 5 + noise_seed + 17)))
			var k: float = smoothstep(0.0, 0.4, local) * (1.0 - smoothstep(0.65, 0.78, local)) if local > 0.0 else 0.0
			turn(gr.parts, gr.joint, g[2], deg_to_rad(float(g[3])) * k * weight)
		"pant":
			## ["pant", group, axis, degrees, rate]: a jaw (or a chest) working open and shut fast,
			## never past rest.
			var gr: Dictionary = group(str(g[1]))
			turn(gr.parts, gr.joint, g[2], deg_to_rad(float(g[3])) * (0.5 - 0.5 * cos(_clock * float(g[4]))) * weight)
		"hover":
			## ["hover", group, height, rate, tilt deg, phase]: bobbing in the air, tilting a beat
			## behind the bob and rocking a little side to side.
			var gr: Dictionary = group(str(g[1]))
			var s: float = _clock * float(g[3]) + float(g[5])
			turn(gr.parts, gr.joint, Vector3.RIGHT, deg_to_rad(float(g[4])) * sin(s - 1.1) * weight)
			turn(gr.parts, gr.joint, Vector3.BACK, deg_to_rad(float(g[4])) * 0.6 * sin(s * 0.61 + 0.7) * weight)
			shift(gr.parts, Vector3(0, float(g[2]) * sin(s), 0) * weight)
		"tremble":
			## ["tremble", group, amount, rate]: a fine, constant shiver (a nervous thing, a
			## machine idling rough).
			var c: float = _clock * float(g[3])
			shift(group(str(g[1])).parts, Vector3(sin(c), 0.6 * sin(c * 1.31 + 1.0), sin(c * 0.87 + 2.0)) * float(g[2]) * weight)
		"wag", "slither":
			## ["slither", chain, axis, degrees, rate, wavelength, falloff]: a wave travelling down a
			## chain from its root, each segment `wavelength` radians behind the one before, growing
			## toward the tip ("tip"), the root ("root") or even. ["wag", ...] is the same, quicker
			## and stiffer (a tail); on a group with no chain it sways the group.
			var gr: Dictionary = group(str(g[1]))
			var wave: float = float(g[5]) if g.size() > 5 else (0.35 if str(g[0]) == "wag" else 0.6)
			var falloff: String = str(g[6]) if g.size() > 6 else "tip"
			if gr.chain.is_empty():
				turn(gr.parts, gr.joint, g[2], deg_to_rad(float(g[3])) * sin(_clock * float(g[4])) * weight)
			else:
				var count: int = gr.chain.size()
				var angles: Array = []
				for index in range(count):
					var along: float = float(index) / float(maxi(1, count - 1))
					var w: float = 1.0
					if falloff == "tip":
						w = lerpf(0.35, 1.0, along)
					elif falloff == "root":
						w = lerpf(1.0, 0.35, along)
					angles.append(deg_to_rad(float(g[3])) * w * sin(_clock * float(g[4]) - float(index) * wave) * weight)
				chain_turns(gr.chain, g[2], angles)
		"coil":
			## ["coil", chain, axis or "across", degrees, rate, phase, falloff]: a slow curl in and
			## out again, never past straight (a snake drawing itself up, a tail curling).
			var gr: Dictionary = group(str(g[1]))
			curl(gr.chain, g[2], deg_to_rad(float(g[3])) * (0.5 - 0.5 * cos(_clock * float(g[4]) + float(g[5]))) * weight, str(g[6]) if g.size() > 6 else "tip")
		"swim":
			## ["swim", spec]: a jellyfish (see `_swim_idle`).
			_swim_idle(g[1], weight)

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
			## They start half way out from the lens, not on it: a mote that close is a blur, and a
			## full halo on each reads as soft white balls. A rig may move them (`start`, the share of
			## the way from the party to it) or size the halo (`halo`).
			var out: Vector3 = aim.lerp(from, float(spec.get("start", 0.55)))
			for index in range(int(spec.get("count", 4))):
				var start: Vector3 = out + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3), 0)
				fx.call("projectile", start, from, color, 0.32 + 0.05 * float(index), 0.07, Callable(), 0.4, float(spec.get("halo", 2.5)))
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
		"charge_glow":
			## A heavy blow gathering where it strikes from: a glow that swells through the hold.
			fx.call("glow_burst", from, color.lightened(0.2), 0.55 * size, float(spec.get("seconds", 0.5)))
			fx.call("spiral_in", from, color.lightened(0.3), 0.7 * size, 18, float(spec.get("seconds", 0.5)))
		"charge_dust":
			## Grit lifting off the floor round it as it strains, and pebbles hopping.
			var feet: Vector3 = _creature.global_position + Vector3(0, 0.05, 0)
			fx.call("rise", feet, Color(0.58, 0.5, 0.42), int(spec.get("amount", 16)), 0.5 * size, float(spec.get("seconds", 0.4)) + 0.6)
			fx.call("shards", feet, Color(0.5, 0.44, 0.38), 4, 1.3, 0.05 * size, 0.5)
		"crack":
			fx.call("crack", _creature.global_position, color, 1.0 * size, float(spec.get("seconds", 1.0)))
		"shell":
			fx.call("shell", point(spec.get("from", "centre")), color, 0.9 * size, float(spec.get("seconds", 0.7)))
		"aura":
			fx.call("aura", _creature.global_position, color, maxf(0.8, (_creature.get("anchor") as Vector3).y), float(spec.get("seconds", 0.9)))
		"helix":
			fx.call("helix", _creature.global_position, color, maxf(0.8, (_creature.get("anchor") as Vector3).y), float(spec.get("seconds", 1.0)), 0.5 * size)
		"hex":
			fx.call("hex_bolt", from, aim, color, float(spec.get("flight", 0.3)), Callable())

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

func _run(fn: String, args: Array) -> void:
	## A rig's own function by name: one of the shared ones here, or its mine's (called with
	## this node first, as `m`).
	if has_method(fn):
		callv(fn, args)
	elif _owner != null:
		_owner.callv(fn, [self] + args)

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

static func _noise(n: int) -> float:
	## A steady random number in -1..1 for each whole step.
	var h: int = (n * 73856093) ^ 19349663
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 2001) / 1000.0 - 1.0

var _rear_held: bool = false

func _look_target(step: int) -> Vector2:
	## Where a looking head turns on this beat: somewhere of its own choosing, or (one beat in
	## three or so) straight ahead again.
	if _noise(step * 13 + noise_seed + 5) > 0.45:
		return Vector2.ZERO
	return Vector2(_noise(step * 2 + noise_seed + 101), _noise(step * 2 + noise_seed + 202))

# --- the jellyfish's swim -------------------------------------------------------------------------
## A pulse: the bell squeezes in for the first 30% of it as the body shoots up, then opens a
## little past rest and drifts down slowly; the appendages trail behind it, pulled in on the
## thrust and flaring out on the recovery, each a little later than the one before.

static func _swim_rise(q: float) -> float:
	return smoothstep(0.0, 0.5, q) - smoothstep(0.35, 1.0, q)

static func _swim_squeeze(q: float) -> float:
	return sin(PI * clampf(q / 0.3, 0.0, 1.0)) - 0.35 * sin(PI * clampf((q - 0.3) / 0.7, 0.0, 1.0))

static func _swim_flare(q: float) -> float:
	return -0.6 * sin(PI * clampf(q / 0.3, 0.0, 1.0)) + sin(PI * clampf((q - 0.3) / 0.7, 0.0, 1.0))

func _swim_length(spec: Dictionary) -> float:
	var beat: float = float(spec.get("beat", 0.9))
	return float(spec.get("start", 0.0)) + (float(spec.get("pulses", 3)) - 0.5) * beat + float(spec.get("sink", 1.6))

func _swim_idle(spec: Dictionary, weight: float) -> void:
	## ["swim", {body, bell, trail, rate, rise, squeeze, flare, lag, ripple, phase}] as an idle:
	## one pulse every 1/rate seconds, rising `rise` and sinking back.
	var q: float = fposmod(_clock * float(spec.get("rate", 0.5)) + float(spec.get("phase", 0.0)), 1.0)
	var rise: float = float(spec.get("rise", 0.08))
	var lag: float = float(spec.get("lag", 0.12))
	var ripple: float = float(spec.get("ripple", 0.03))
	var flares: Array = []
	var drops: Array = []
	var count: int = group(str(spec.trail)).parts.size() if spec.has("trail") else 0
	for index in range(count):
		var late: float = fposmod(q - lag - ripple * float(index), 1.0)
		flares.append(_swim_flare(late))
		drops.append(rise * (_swim_rise(late) - _swim_rise(q)))
	_swim_lay(spec, rise * _swim_rise(q), _swim_squeeze(q), flares, drops, weight)

func _swim_clip(clip: Dictionary, spec: Dictionary, t: float) -> void:
	## ["swim", {body, bell, trail, pulses, beat, rise, sink, squeeze, flare, lag, ripple, start}]
	## in a fidget or a move: `pulses` strong pulses `beat` seconds apart, each rising `rise`,
	## then a slow sink over `sink` seconds back to where it hung.
	t -= float(spec.get("start", 0.0))
	if t <= 0.0:
		return
	var pulses: int = maxi(1, int(spec.get("pulses", 3)))
	var beat: float = maxf(0.3, float(spec.get("beat", 0.9)))
	var rise: float = float(spec.get("rise", 0.12))
	var top: float = (float(pulses) - 0.5) * beat
	var sink: float = maxf(0.3, float(spec.get("sink", 1.6)))
	var lag: float = float(spec.get("lag", 0.12))
	var ripple: float = float(spec.get("ripple", 0.03))
	var weight: float = float(clip.get("weight", 1.0))
	var height := func(at: float) -> float:
		if at <= 0.0:
			return 0.0
		var k: int = mini(int(at / beat), pulses - 1)
		var q: float = minf((at - float(k) * beat) / beat, 1.0)
		return rise * (float(k) + smoothstep(0.0, 0.5, q)) * (1.0 - smoothstep(top, top + sink, at))
	var phase := func(at: float) -> float:
		if at <= 0.0 or at >= float(pulses) * beat:
			return 0.0 if at <= 0.0 else 1.0
		var k: int = mini(int(at / beat), pulses - 1)
		return (at - float(k) * beat) / beat
	var y: float = height.call(t)
	var squeeze: float = _swim_squeeze(phase.call(t)) if t < float(pulses) * beat else 0.0
	var flares: Array = []
	var drops: Array = []
	var count: int = group(str(spec.trail)).parts.size() if spec.has("trail") else 0
	for index in range(count):
		var late: float = t - (lag + ripple * float(index)) * beat
		flares.append(_swim_flare(phase.call(late)) if late < float(pulses) * beat else 0.0)
		drops.append(float(height.call(late)) - y)
	_swim_lay(spec, y, squeeze, flares, drops, weight)

func _swim_lay(spec: Dictionary, y: float, squeeze: float, flares: Array, drops: Array, weight: float) -> void:
	## Lays a swim's pose: the bell squeezed about its joint, each appendage flared about its
	## root (in toward the bell's axis or out from it) and dropped behind, then all of it raised.
	var s: float = float(spec.get("squeeze", 0.12)) * squeeze * weight
	if spec.has("bell"):
		var bell: Dictionary = group(str(spec.bell))
		swell(bell.parts, bell.joint, Vector3(1.0 - s, 1.0 + s * 0.6, 1.0 - s))
	if spec.has("trail"):
		var trail: Dictionary = group(str(spec.trail))
		var flare: float = deg_to_rad(float(spec.get("flare", 14.0)))
		var index: int = 0
		for part in trail.parts:
			if index >= flares.size():
				break
			var at: Vector3 = (part as Node3D).get("_rest").origin
			var out: Vector3 = at - (trail.joint as Vector3)
			out.y = 0.0
			if not out.is_zero_approx():
				turn([part], at, out.cross(Vector3.UP), flare * float(flares[index]) * weight)
				## Roots on the rim follow it in as the bell squeezes.
				shift([part], -out * s)
			shift([part], Vector3(0, float(drops[index]) * weight, 0))
			index += 1
	shift(group(str(spec.get("body", "all"))).parts, Vector3(0, y * weight, 0))
