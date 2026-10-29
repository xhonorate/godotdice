extends RefCounted
## Recipes for tools/creature_bake.gd: the Rift. See tools/creature_bake.gd for the format.
##
## Most of these are the models the owner picked in the four-round model review (October
## 2026), moved in from the review batches in build/options/recipes (geode_rift, r3c, r3d, r4).
## Each keeps its review key as its "seed", so it bakes facet for facet as it was picked: the
## facets of the unseeded rocks, crystals and slabs come from one random stream drawn in part
## order, so neither the parts nor their order may change. The Void Echo, the Riftling Swarm
## and the Collapsar are older models, kept exactly as they were.
##
## The look: low poly and angular, made of crystal and gem. Long bodies are rows of cut
## stones, hoops are bands of boxes or eight-sided rings, every sphere is a five- or six-sided
## gem. Parts an animation moves carry a "name" (the bake names the pivot <Name>01, ...), and
## the pieces of one moving thing share a "joint"; build/options/part_roles/rift.md lists them.

static func recipes() -> Dictionary:
	return {
		"VOID_ECHO": _void_echo(),
		"RIFTLING_SWARM": _riftling_swarm(),
		"COLLAPSAR": _collapsar(),
		"ENTROPY_EYE": _entropy_eye(),
		"NULL_SHADE": _null_shade(),
		"RIFT_SHIFTER": _rift_shifter(),
		"THE_UNMADE": _the_unmade(),
		"HUSH": _hush(),
		"STAR_LEECH": _star_leech(),
		"TIMEGLASS": _timeglass(),
		"PARADOX_MOTH": _paradox_moth()}

## ---- kept as they were ----------------------------------------------------------------------

## The Void Echo: a dim core with six shards circling it. (In a fight an echo wears the scene of
## the creature it copies; this is its own.)
static func _void_echo() -> Dictionary:
	var echo: Array = [{"shape": "sphere", "at": [0, 1.0, 0], "scale": 0.25, "material": "core", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4}]
	for i in range(6):
		var a: float = float(i) * TAU / 6.0
		echo.append({"shape": "shard", "at": [cos(a) * 0.6, 0.9 + sin(a * 1.5) * 0.3, sin(a) * 0.6], "rot": [20, rad_to_deg(a), 30], "scale": 1.8, "material": "body", "motion": "orbit", "phase": a, "size": 0.14})
	return {"style": "shards", "sway": 1.5, "tint": "4a3a8a", "accent": "c8b8ff", "anchor": 1.8, "shadow": 1.8, "parts": echo}

## The Riftling Swarm: a small core in a cloud of sixteen shards circling it at three radii.
static func _riftling_swarm() -> Dictionary:
	var swarm: Array = [{"shape": "sphere", "at": [0, 1.0, 0], "scale": 0.16, "material": "core", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3}]
	for i in range(16):
		var a: float = float(i) * TAU / 16.0 * 3.0
		var r: float = 0.4 + 0.5 * float(i % 3) / 2.0
		swarm.append({"shape": "shard", "at": [cos(a) * r, 0.45 + float(i % 5) * 0.3, sin(a) * r], "rot": [float(i) * 37.0, float(i) * 61.0, 20], "scale": 1.3 + 0.5 * float(i % 2), "material": "accent" if i % 3 == 0 else "body", "motion": "orbit", "phase": a + float(i) * 0.3, "size": 0.12})
	return {"style": "shards", "sway": 2.4, "tint": "5a4ab0", "accent": "ff8ad8", "anchor": 2.1, "shadow": 2.4, "ring": 1.2, "parts": swarm}

## The Collapsar: a dark knot with a lit disc turning round it and splinters falling in.
static func _collapsar() -> Dictionary:
	var collapsar: Array = [
		{"shape": "sphere", "at": [0, 1.3, 0], "scale": 0.5, "material": "body", "motion": "bob", "radius": 1.0, "segments": 10, "rings": 6},
		{"shape": "sphere", "at": [0, 1.3, 0], "scale": 0.2, "material": "core", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "ring", "at": [0, 1.3, 0], "rot": [16, 0, 14], "material": "accent", "motion": "spin", "radius": 0.95, "width": 0.12, "segments": 36},
		{"shape": "ring", "at": [0, 1.3, 0], "rot": [16, 0, 14], "material": "accent", "motion": "spin", "phase": 1.5, "radius": 1.3, "width": 0.05, "segments": 40}]
	for i in range(10):
		var a: float = float(i) * TAU / 10.0
		var r: float = 0.75 + 0.35 * float(i % 3) / 2.0
		collapsar.append({"shape": "shard", "at": [cos(a) * r, 1.3 + sin(a * 2.0) * 0.18, sin(a) * r], "rot": [float(i) * 41.0, rad_to_deg(a), 30], "scale": 1.4,
			"material": "accent" if i % 4 == 0 else "body", "motion": "orbit", "phase": a, "size": 0.12})
	return {"style": "shards", "sway": 0.8, "tint": "2a1a48", "accent": "9a6aff", "anchor": 2.6, "shadow": 2.4, "ring": 1.2, "parts": collapsar}

## ---- picked in the model review -------------------------------------------------------------

## The Entropy Eye (geode_rift B): an iris that opens. The bright eye in a ring of ten dark
## petals spread toward the party like an aperture, some petals tipped with light, a dark mass behind.
static func _entropy_eye() -> Dictionary:
	## The eye (iris gem and pupil) looks round about the iris gem's middle.
	var look := {"name": "eye", "joint": [0, 1.35, 0.1]}
	var b: Array = [
		_rock(Vector3(0, 1.35, -0.25), Vector3(0.5, 0.5, 0.4), "body", 0.1, 602, {"motion": "core"}),
		_rock(Vector3(0, 1.3, -0.52), Vector3(0.42, 0.42, 0.3), "body", 0.2, 601),
		_gem(Vector3(0, 1.35, 0.1), 0.34, "accent", _m({"motion": "core"}, look)),
		_eye(Vector3(0, 1.35, 0.4), 0.14, "body", look.duplicate())]
	b.append_array(_band(Vector3(0, 1.35, 0.12), Vector3.BACK, 0.37, 6, 0.06, 0.1, "core"))
	for k in range(10):
		var ang: float = TAU * float(k) / 10.0 + 0.2
		var radial := Vector3(cos(ang), sin(ang), 0)
		var dir: Vector3 = (radial * 0.85 + Vector3(0, 0, 0.5)).normalized()
		var root: Vector3 = Vector3(0, 1.35, 0.05) + radial * 0.36
		var length: float = 0.55 if k % 2 == 0 else 0.45
		## A petal and the light on its tip, hinged at its root on the ring so it can fold shut.
		var hinge := {"name": "petal", "joint": _v(root), "phase": float(k) * 0.7}
		b.append(_m({"shape": "prism", "at": _v(root + dir * length * 0.5), "rot": _frame(Vector3(-sin(ang), cos(ang), 0), dir), "material": "body", "motion": "crystal", "phase": float(k) * 0.7, "size": [0.26, length, 0.04]}, hinge.duplicate()))
		if k % 3 == 0:
			b.append(_crystal(root + dir * length, root + dir * (length + 0.16), 0.03, "accent", hinge.duplicate()))
	for spec in [[Vector3(0.9, 1.0, 0.2), 0.0], [Vector3(-0.8, 1.8, -0.3), 1.6], [Vector3(0.3, 0.5, -0.7), 3.2], [Vector3(-0.5, 2.2, 0.4), 4.8]]:
		b.append(_shard(spec[0], [30, 40, 20], 1.4, "accent", {"motion": "orbit", "phase": spec[1]}))
	return {"style": "shards", "sway": 1.1, "tint": "2a2048", "accent": "ff5ad8", "anchor": 2.4, "shadow": 2.4, "ring": 1.2, "seed": "ENTROPY_EYE_B", "parts": b}

## The Null Shade (geode_rift A): a hole in the air. A dark crystal hung point-up over three
## precessing rings, one white eye set in a glowing ring in its belly, dark tendrils trailing
## beneath, motes of light drawn in.
static func _null_shade() -> Dictionary:
	## The eye (gem and pupil) looks round about the eye gem's middle; the glowing ring it is set
	## in is its `socket` (named, or the bake would call it Ring01 among the `ring`s below).
	var look := {"name": "eye", "joint": [0, 1.22, 0.36]}
	var a: Array = [
		{"shape": "crystal", "from": [0, 0.8, 0], "to": [0, 2.32, 0], "material": "body", "radius": 0.42, "sides": 6, "motion": "core"},
		{"shape": "spike", "from": [0, 0.84, 0], "to": [0, 0.5, 0], "material": "body", "radius": 0.4, "sides": 6, "lean": 0.0},
		_eye(Vector3(0, 1.22, 0.36), 0.15, "accent", look.duplicate()), _eye(Vector3(0, 1.22, 0.49), 0.06, "body", look.duplicate()),
		_hoop(Vector3(0, 1.22, 0.4), Vector3.BACK, 0.22, 0.05, "core", {"name": "socket"}),
		_rock(Vector3(0, 0.4, 0), Vector3(0.28, 0.08, 0.28), "core", 0.1, 701, {"motion": "core", "phase": 1.0})]
	for spec in [[Vector3(0.15, 0.9, 0.1), Vector3(0.32, 0.4, 0.22), 0.0], [Vector3(-0.18, 0.9, -0.05), Vector3(-0.38, 0.36, -0.1), 1.3], [Vector3(0.02, 0.85, -0.2), Vector3(0.06, 0.45, -0.46), 2.6], [Vector3(-0.08, 0.88, 0.22), Vector3(-0.14, 0.5, 0.4), 3.9]]:
		a.append(_cone(spec[0], spec[1], 0.05, "body", {"name": "tendril", "joint": _v(spec[0]), "motion": "swing", "phase": spec[2]}))
	_rings(a, [0.14, 0.3, 0.46], [0.9, 0.66, 0.44], [[10, 0, 0], [-8, 0, 10], [12, 0, -6]])
	_motes(a, [[Vector3(0.6, 0.8, 0.2), 0.0], [Vector3(-0.5, 1.5, 0.3), 1.3], [Vector3(0.3, 2.0, -0.5), 2.6], [Vector3(-0.65, 1.1, -0.2), 3.9], [Vector3(0.1, 0.7, -0.6), 5.2]], 0.03, 3, {"name": "mote"})
	return {"style": "wings", "sway": 1.0, "tint": "1a1630", "accent": "8b7dff", "anchor": 2.5, "shadow": 2.2, "ring": 1.1, "seed": "NULL_SHADE_A", "parts": a}

## The Rift Shifter (geode_rift A): the ribbon finished. Nine slabs climbing a helix round a lit
## seam and turning as one, a face (eyes and a mouth slit) in the capstone slab at the top, rubble at its foot.
static func _rift_shifter() -> Dictionary:
	## The capstone face, hinged where the seam meets the capstone's underside.
	var face := {"name": "head", "joint": [0, 2.22, 0]}
	var a: Array = [
		## The lit seam turns slowly on itself (it stood still in the review; the first part has to move).
		{"shape": "column", "from": [0, 0.2, 0], "to": [0, 2.2, 0], "material": "accent", "radius": 0.06, "sides": 5, "motion": "spin"},
		{"shape": "column", "from": [0, 0.3, 0], "to": [0, 2.1, 0], "material": "core", "radius": 0.13, "sides": 6, "motion": "core"},
		_slab(Vector3(0, 2.32, 0), Vector3(0.62, 0.2, 0.36), "body", _m({"rot": [0, 0, 8]}, face)),
		_eye(Vector3(0.14, 2.35, 0.19), 0.045, "accent", face.duplicate()), _eye(Vector3(-0.14, 2.33, 0.19), 0.045, "accent", face.duplicate()),
		_box(Vector3(0, 2.26, 0.19), Vector3(0.26, 0.025, 0.02), "accent", {"name": "mouth", "joint": [0, 2.22, 0]}),
		_slab(Vector3(0.5, 0.08, 0.3), Vector3(0.5, 0.14, 0.3), "body", {"rot": [0, 30, 0]}),
		_slab(Vector3(-0.55, 0.07, -0.2), Vector3(0.44, 0.12, 0.3), "body", {"rot": [0, -20, 0]}),
		_slab(Vector3(0.1, 0.06, -0.55), Vector3(0.4, 0.1, 0.26), "body", {"rot": [0, 70, 0]}),
		_shard(Vector3(-0.3, 0.1, 0.55), [20, 30, 40], 1.3, "accent"),
		_shard(Vector3(0.7, 0.08, -0.3), [40, 10, 30], 1.2, "accent")]
	## The ribbon: nine slabs orbiting the seam together (one phase), so they take no joint.
	for i in range(9):
		var ang: float = deg_to_rad(52.0 * float(i))
		var radial := Vector3(cos(ang), 0, sin(ang))
		var along := Vector3(-sin(ang), 0.45, cos(ang)).normalized()
		a.append({"shape": "slab", "at": _v(radial * 0.42 + Vector3(0, 0.35 + 0.21 * float(i), 0)), "rot": _frame(along, radial), "material": "accent" if i % 4 == 2 else "body", "motion": "orbit", "phase": 0.0, "size": [0.6, 0.12, 0.3], "jitter": 0.05, "name": "body"})
	return {"style": "shards", "sway": 1.6, "tint": "4a3a8a", "accent": "4ab8d8", "anchor": 2.6, "shadow": 2.0, "ring": 1.1, "seed": "RIFT_SHIFTER_A", "parts": a}

## The Infinite Void (THE_UNMADE, r3c B): a maelstrom. The black stone at the top of a
## whirlpool: two spiral arms of hot slabs, white shards and rubble winding into it, a ring of
## light hugging it, fed from below by a funnel of rock torn off the floor with light drawn up through it.
static func _the_unmade() -> Dictionary:
	var hub := Vector3(0, 2.5, 0)
	var nb := Vector3(-0.25, 1.0, 0.55).normalized()
	var b: Array = [
		_rock(hub, Vector3(1.0, 1.0, 1.0), "iron", 0.04, 861, {"name": "heart", "motion": "core"}),
		_hoop(hub, nb, 1.08, 0.09, "accent", {"name": "ring", "motion": "core"}),
		_hoop(hub, Vector3(-0.35, 0.2, 1).normalized(), 1.14, 0.07, "accent", {"name": "ring", "motion": "orbit", "phase": 0.0})]
	## The arms turn as one on the hub about the tilted axle `nb` (spin), so they take no joint.
	var spin := {"name": "arm", "motion": "spin", "phase": 0.0}
	for arm in range(2):
		for i in range(12):
			var ang: float = float(arm) * PI + float(i) * 0.4
			var r: float = 1.2 + float(i) * 0.095
			var lift: float = -0.02 * float(i)
			if i < 4:
				b.append(_on_disc(hub, nb, r, ang, lift, _m({"shape": "box", "material": "core", "size": [0.42, 0.08, 0.6]}, spin), Vector3(0, -20, 0)))
			elif i < 8:
				b.append(_on_disc(hub, nb, r, ang, lift, _m({"shape": "slab", "material": "accent", "size": [0.34, 0.05, 0.56], "jitter": 0.05}, spin), Vector3(0, -25, 0)))
			else:
				var s: float = 0.32 - 0.02 * float(i - 8)
				b.append(_on_disc(hub, nb, r, ang, lift, _m({"shape": "rock", "material": "body", "scale": [s, s * 0.7, s * 1.3], "jitter": 0.16, "seed": 870 + i + arm * 20}, spin), Vector3(15, -30, 10)))
	## The funnel: five rings of rock and white shards, narrow at the floor and wide at the top,
	## each ring circling the axis on its own beat.
	var levels: Array = [[0.3, 0.38, 5], [0.68, 0.6, 7], [1.06, 0.84, 8], [1.44, 1.08, 9], [1.8, 1.32, 10]]
	for l in range(levels.size()):
		var y: float = levels[l][0]
		var r: float = levels[l][1]
		var count: int = levels[l][2]
		for i in range(count):
			var ang: float = TAU * float(i) / float(count) + float(l) * 0.5
			var at := Vector3(cos(ang) * r, y + 0.08 * float(i % 2), sin(ang) * r)
			var orbit := {"name": "funnel", "motion": "orbit", "phase": float(l) * 0.8}
			if i % 3 == 0:
				b.append(_m({"shape": "shard", "at": _v(at), "rot": [30.0 * float(i), 70.0 * float(i), 20], "scale": 1.8, "material": "accent", "size": 0.12}, orbit))
			else:
				var s: float = 0.13 + 0.03 * float(l) + 0.03 * float(i % 2)
				b.append(_m(_rock(at, Vector3(s * 1.3, s * 0.7, s), "body", 0.2, 900 + l * 10 + i, {"rot": [20.0 * float(i), 50.0 * float(i), 15]}), orbit))
	## Crystals of light drawn up through the middle of the funnel.
	for i in range(4):
		var ang: float = TAU * float(i) / 4.0
		b.append({"shape": "crystal", "from": _v(Vector3(cos(ang) * 0.2, 0.25 + 0.3 * float(i % 2), sin(ang) * 0.2)), "to": _v(Vector3(cos(ang) * 0.35, 1.2 + 0.3 * float(i % 2), sin(ang) * 0.35)), "material": "accent", "radius": 0.05, "sides": 6, "name": "light", "motion": "orbit", "phase": 0.0})
	## Four pieces of debris whirling high round it. The review batch threw these from an
	## unseeded random stream, so they came out differently on every load; these are the throws
	## in the scene the owner was shown (build/options/scenes/the_unmade_b.tscn).
	var whirl := {"motion": "orbit", "phase": 0.0}
	b.append(_m({"shape": "crystal", "at": [1.72997296, 3.73116922, 0.408697128], "rot": [41.2731905, -126.286387, 27.7228994], "material": "accent", "radius": 0.07, "height": 0.53700453, "sides": 4}, whirl.duplicate()))
	b.append(_m({"shape": "slab", "at": [-0.351925701, 3.5828867, 2.06550431], "rot": [38.1948208, -29.4281876, 43.3865535], "material": "body", "size": [0.47558614, 0.14, 0.32626545], "jitter": 0.05, "seed": 941}, whirl.duplicate()))
	b.append(_m({"shape": "crystal", "at": [-1.70544171, 3.20252728, 0.427354842], "rot": [26.3321295, -14.9467113, 0.623123174], "material": "accent", "radius": 0.07, "height": 0.579979002, "sides": 4}, whirl.duplicate()))
	b.append(_m({"shape": "rock", "at": [-0.368879139, 3.3863163, -1.73648238], "scale": [0.282196224, 0.225756973, 0.282196224], "material": "body", "jitter": 0.18, "seed": 943}, whirl.duplicate()))
	_rubble(b, 960)
	return {"style": "tower", "sway": 0.4, "tint": "0a0818", "accent": "ffffff", "anchor": 3.7, "warden": true, "shadow": 3.8, "ring": 1.9, "seed": "THE_UNMADE_B", "parts": b}

## Hush (r3d C, new): a faceless eel of dark stone coiling up through the air, threading three
## rings of light that turn on its body, crystal fins down its back, one shut eye and no mouth.
static func _hush() -> Dictionary:
	var ctrl: Array = []
	for k in range(9):
		var u: float = float(k) / 8.0
		var ang: float = PI * 0.5 - (1.0 - u) * TAU * 1.05
		ctrl.append(Vector3(cos(ang) * 0.44, 0.34 + 0.86 * u, sin(ang) * 0.44))
	ctrl.append(Vector3(-0.18, 1.3, 0.58))
	var path: Array = _spline(ctrl, 26)
	var c: Array = []
	_run(c, path, 0.06, 0.16, "body", 3021, 0.05)
	## The body swims: each stone hinged at its front end (toward the head), each swaying a
	## beat after the one behind it.
	for i in range(c.size()):
		c[i].merge({"name": "body", "joint": _v(path[i + 1]), "motion": "crystal", "phase": float(i) * 0.5}, true)
	var hd: Vector3 = path[path.size() - 1]
	var hdir: Vector3 = (hd - (path[path.size() - 3] as Vector3)).normalized()
	var hup: Vector3 = (Vector3.UP - hdir * hdir.dot(Vector3.UP)).normalized()
	c.append(_rock(hd + hdir * 0.08, Vector3(0.17, 0.2, 0.15), "body", 0.06, 3040, {"aim": _v(hdir), "name": "head", "joint": _v(hd)}))
	## The shut eye on the head's brow, about its own middle so it can open.
	var lids: Vector3 = hd + hdir * 0.25 + hup * 0.06
	_closed_eye(c, lids, hdir + hup * 0.5, 0.26, {"name": "eye", "joint": _v(lids), "motion": "static"})
	var tail_end: Vector3 = path[0]
	var tdir: Vector3 = (tail_end - (path[1] as Vector3)).normalized()
	var fluke := {"name": "tail", "joint": _v(tail_end), "motion": "static"}
	c.append(_crystal(tail_end, tail_end + tdir * 0.3 + Vector3(0, 0.14, 0), 0.05, "accent", fluke.duplicate()))
	c.append(_crystal(tail_end, tail_end + tdir * 0.26 - Vector3(0, 0.12, 0), 0.04, "body", fluke.duplicate()))
	for i in [5, 9, 13, 17, 21]:
		var p: Vector3 = path[i]
		var t: Vector3 = ((path[i + 1] as Vector3) - (path[i - 1] as Vector3)).normalized()
		var up: Vector3 = (Vector3.UP - t * t.dot(Vector3.UP)).normalized()
		var r: float = lerpf(0.06, 0.16, float(i) / 26.0)
		c.append(_crystal(p + up * r * 0.7, p + up * (r + 0.16) - t * 0.08, 0.035 + 0.01 * float(i % 2), "accent" if i % 8 == 5 else "body", {"name": "fin"}))
	## Three rings of light, each spinning on the body where it passes through.
	for spec in [[7, 0.0], [14, 1.4], [20, 2.8]]:
		var i: int = spec[0]
		var t: Vector3 = ((path[i + 1] as Vector3) - (path[i - 1] as Vector3)).normalized()
		var r: float = lerpf(0.06, 0.16, float(i) / 26.0)
		c.append_array(_band(path[i], t, r + 0.14, 8, 0.065, 0.1, "accent", {"name": "ring", "motion": "spin", "phase": spec[1]}))
	for spec in [[Vector3(0.6, 1.1, 0.3), 0.0], [Vector3(-0.6, 0.5, -0.3), 2.1], [Vector3(0.2, 0.3, 0.6), 4.2]]:
		c.append(_shard(spec[0], [30, 40, 20], 0.8, "accent", {"motion": "orbit", "phase": spec[1]}))
	return {"style": "wings", "sway": 0.9, "tint": "4a3a8a", "accent": "c8b8ff", "anchor": 1.75, "shadow": 1.8, "ring": 1.0, "seed": "NEW_HUSH_C", "parts": c}

## The Star Leech (r4 B, new): a tall cut gem standing upright (a point, a long hex waist, a
## crown and a table), the leech climbing it in two widening turns and rearing over the table.
static func _star_leech() -> Dictionary:
	var b: Array = []
	## The gem pulses as one about its middle.
	_brilliant(b, Vector3(0, 0.3, 0), Vector3.UP, 0.23, 0.15, 0.26, 0.55, "core", "accent", {"name": "gem", "joint": [0, 0.475, 0], "motion": "core", "phase": 0.0}, 0.0, 0.46, "body")
	var hb: Array = []
	var turns_b: float = 2.0
	var steps_b: int = 26
	var end_b: float = deg_to_rad(200.0)
	for i in range(steps_b + 1):
		var u: float = float(i) / float(steps_b)
		var ang: float = end_b - (1.0 - u) * turns_b * TAU
		var y: float = lerpf(0.06, 0.84, u)
		var rad: float = lerpf(0.2, 0.3, minf(u * 3.0, 1.0)) if y < 0.3 else 0.3
		hb.append(Vector3(sin(ang) * rad, y, cos(ang) * rad))
	var last_b: Vector3 = hb[steps_b]
	var lift_b: Array = _spline([last_b, last_b + Vector3(0.0, 0.14, 0.02), Vector3(-0.12, 1.12, 0.12), Vector3(-0.2, 1.18, 0.34)], 4)
	var pb: Array = hb.duplicate()
	pb.append_array(lift_b.slice(1))
	var rb: Array = []
	for i in range(pb.size()):
		rb.append(lerpf(0.035, 0.1, float(i) / float(steps_b)) if i <= steps_b else 0.1 - 0.004 * float(i - steps_b))
	## The coil turns about the gem's axis; the stones that rear up off its top are the head's
	## neck, hinged where the coil ends.
	var neck := {"name": "head", "joint": _v(last_b)}
	_leech_body(b, pb, rb, 4601, {"name": "body", "joint": [0, 0.45, 0]}, steps_b, neck)
	_leech_head(b, pb, 0.095, 0.1, 8, neck)
	## The tail's own sucker, holding to the floor.
	_sucker(b, Vector3(sin(end_b) * 0.2, 0.03, cos(end_b) * 0.2) + Vector3(0.05, 0, 0.0), Vector3(0, -1, 0.3), 0.05, 0)
	_motes(b, [[Vector3(0.45, 0.9, 0.1), 0.0], [Vector3(-0.42, 0.55, -0.25), 1.6], [Vector3(0.2, 1.25, -0.35), 3.2], [Vector3(-0.3, 0.3, 0.45), 4.8]], 0.028, 2)
	## Grown 1.3x from the picked size (the build check): it was a pale speck beside the Rift's other
	## threat-3 creatures.
	return {"style": "low", "sway": 2.0, "tint": "b4aae0", "accent": "eae4ff", "anchor": 1.4, "scale": 1.3, "shadow": 1.4, "ring": 0.85, "seed": "NEW_STAR_LEECH_B", "parts": b}

## The Timeglass (r3d A, new): an hourglass of two hex glass cones tip to tip in an iron frame,
## bright sand rising through the lit neck and grains floating up off it, three jointed crystal legs.
static func _timeglass() -> Dictionary:
	## The glass, its frame and the sand inside turn as one about the neck: at idle a slow
	## half-glance left and right, in a fight the whole glass turning over.
	var glass := {"name": "body", "joint": [0, 0.98, 0], "motion": "block", "phase": 0.0}
	var a: Array = []
	_hourglass(a, Vector3(0, 0.98, 0), Vector3.UP, 0.38, 0.28, glass, {"name": "sand"})
	a.append(_crystal(Vector3(0, 1.42, 0), Vector3(0, 1.66, 0), 0.06, "accent", glass.duplicate()))
	for spec in [[Vector3(0.16, 1.6, 0.06), 0.0], [Vector3(-0.12, 1.74, -0.04), 1.1], [Vector3(0.05, 1.88, 0.1), 2.2]]:
		a.append(_shard(spec[0], [20, 40, 30], 0.35, "accent", {"name": "grain", "motion": "bob", "phase": spec[1]}))
	for k in range(3):
		var ang: float = deg_to_rad(30.0 + 120.0 * float(k))
		var dir := Vector3(cos(ang), 0, -sin(ang))
		_tri_leg(a, Vector3(0, 0.55, 0) + dir * 0.3, Vector3(0, 0.72, 0) + dir * 0.56, dir * 0.78, 0.045, float(k) * 2.1)
	return {"style": "tower", "sway": 1.6, "tint": "5a4ab0", "accent": "8affe0", "anchor": 2.0, "shadow": 1.8, "ring": 1.0, "seed": "NEW_TIMEGLASS_A", "parts": a}

## The Paradox Moth (r3d B, new): wings thrown up in a tall V with the ghost pair reflected below
## them, its lantern on a short swinging chain.
static func _paradox_moth() -> Dictionary:
	var b: Array = [
		_rock(Vector3(0, 1.0, 0.0), Vector3(0.11, 0.14, 0.12), "body", 0.08, 5012, {"motion": "core"}),
		{"shape": "crystal", "from": [0, 0.92, -0.04], "to": [0, 0.68, -0.12], "material": "body", "radius": 0.075, "sides": 6},
		_rod(Vector3(0, 0.88, -0.055), Vector3(0, 0.85, -0.065), 0.075, 0.075, "accent")]
	_moth_head(b, Vector3(0, 1.08, 0.13), 1.0, Vector3(0, 1.07, 0.07))
	for side in [-1.0, 1.0]:
		_wing(b, "wing", Vector3(side * 0.07, 1.04, 0.0), side, 58.0, 0.62, 0.44, "body", 0.0, 0.0, true)
		_wing(b, "wing", Vector3(side * 0.07, 0.98, -0.02), side, 30.0, 0.42, 0.3, "body", 0.9)
		_wing(b, "ghost", Vector3(side * 0.07, 0.94, -0.06), side, -42.0, 0.62, 0.44, "core", PI, -0.03, false, 52.0)
		_wing(b, "ghost", Vector3(side * 0.07, 0.92, -0.06), side, -68.0, 0.42, 0.3, "core", PI + 0.9, -0.03, false, 52.0)
	## The lantern, its chain and its hook swing as one from the tail.
	var hook := Vector3(0, 0.68, -0.12)
	var chain: Array = []
	for i in range(3):
		chain.append(_box(hook - Vector3(0, 0.045 + 0.07 * float(i), 0), Vector3(0.04, 0.08, 0.015), "iron", {"rot": [0, 90.0 * float(i % 2), 0]}))
	var hung: Array = []
	_lantern(hung, hook - Vector3(0, 0.22, 0), hook - Vector3(0, 0.5, 0), 0.09)
	hung.append(_crystal(hook - Vector3(0, 0.2, 0), hook - Vector3(0, 0.12, 0), 0.03, "iron", {"motion": "static"}))
	chain.append_array(hung)
	b.append_array(_hang(chain, hook, "swing", 0.5, "lantern"))
	for spec in [[Vector3(0.5, 0.6, 0.25), 0.0], [Vector3(-0.5, 1.3, -0.2), 2.1]]:
		b.append(_shard(spec[0], [20, 40, 30], 0.3, "accent", {"motion": "orbit", "phase": spec[1]}))
	## Scale 1.05 (it was picked at 0.82): smaller than that, its dark wings were lost in a Rift room.
	return {"style": "wings", "sway": 2.4, "tint": "3a2a6a", "accent": "c8b8ff", "anchor": 1.35, "scale": 1.05, "shadow": 1.4, "ring": 0.8, "seed": "NEW_PARADOX_MOTH_B", "parts": b}

## ---- helpers ----------------------------------------------------------------------------------

static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

static func _m(part: Dictionary, extra: Dictionary) -> Dictionary:
	## `part` with `extra`'s fields laid over it.
	part.merge(extra, true)
	return part

static func _aimed(direction: Vector3) -> Basis:
	## The bake's own rule: upright turned the shortest way round until Y runs along `direction`.
	var up: Vector3 = direction.normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() < 0.0001:
		return Basis() if up.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(up))

static func _rot(basis: Basis) -> Array:
	## Euler degrees (the bake's order) for a basis.
	var e: Vector3 = basis.orthonormalized().get_euler()
	return [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

static func _frame(x_axis: Vector3, y_axis: Vector3) -> Array:
	## Euler degrees for a part whose long axis (Y) runs along `y_axis` and whose width (X)
	## runs along `x_axis`: a plate laid any way round.
	var y := y_axis.normalized()
	var x := (x_axis - y * x_axis.dot(y)).normalized()
	var e := Basis(x, y, x.cross(y)).get_euler()
	return [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

static func _axis_of(rot: Array) -> Vector3:
	## The long (Y) axis of a part turned by `rot` (Euler degrees, the bake's order).
	return Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])), deg_to_rad(float(rot[2])))) * Vector3.UP

static func _perp(dir: Vector3) -> Array:
	## Two axes square to `dir`: for a forward `dir` they are right and up.
	var f := dir.normalized()
	var s: Vector3 = (Vector3.UP.cross(f) if absf(f.y) < 0.9 else Vector3.RIGHT.cross(f)).normalized()
	return [s, f.cross(s).normalized()]

static func _spline(pts: Array, n: int) -> Array:
	## `n + 1` points along a Catmull-Rom curve through `pts`: one smooth run for a body, so the
	## stones laid along it never kink apart.
	var out: Array = []
	var m: int = pts.size() - 1
	for i in range(n + 1):
		var g: float = float(i) / float(n) * float(m)
		var k: int = mini(int(floor(g)), m - 1)
		var t: float = g - float(k)
		var p0: Vector3 = pts[maxi(k - 1, 0)]
		var p1: Vector3 = pts[k]
		var p2: Vector3 = pts[k + 1]
		var p3: Vector3 = pts[mini(k + 2, m)]
		var t2: float = t * t
		var t3: float = t2 * t
		out.append((p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 + (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t3) * 0.5)
	return out

static func _eye(at: Vector3, size: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	## A pentagonal gem: an eye, a stud, a knob, a star.
	return _m({"shape": "sphere", "at": _v(at), "scale": size, "material": material, "radius": 1.0, "segments": 5, "rings": 2}, extra)

static func _gem(at: Vector3, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	## The biggest cut gem allowed (six by three): an iris, a mote of light.
	var s: Variant = _v(size) if size is Vector3 else float(size)
	return _m({"shape": "sphere", "at": _v(at), "scale": s, "material": material, "radius": 1.0, "segments": 6, "rings": 3}, extra)

static func _rock(at: Vector3, size: Vector3, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	## A cut stone (low `jitter`) or a boulder (high), its facets cut from `seed`.
	return _m({"shape": "rock", "at": _v(at), "scale": _v(size), "material": material, "jitter": jitter, "seed": seed}, extra)

static func _box(at: Vector3, size: Vector3, material: String, extra: Dictionary = {}) -> Dictionary:
	return _m({"shape": "box", "at": _v(at), "material": material, "size": _v(size)}, extra)

static func _slab(at: Vector3, size: Vector3, material: String, extra: Dictionary = {}) -> Dictionary:
	## A box with its corners pushed about a little.
	return _m({"shape": "slab", "at": _v(at), "material": material, "size": _v(size), "jitter": 0.04}, extra)

static func _bar(a: Vector3, b: Vector3, thick: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## A square bar from `a` to `b`: a facet edge.
	return _m({"shape": "box", "at": _v((a + b) * 0.5), "aim": _v(b - a), "material": material, "size": [thick, a.distance_to(b), thick]}, extra)

static func _rod(from: Vector3, to: Vector3, r0: float, r1: float, material: String = "body", extra: Dictionary = {}, sides: int = 6) -> Dictionary:
	## A hex stick, `r0` thick at `from`, `r1` at `to`.
	return _m({"shape": "cylinder", "from": _v(from), "to": _v(to), "material": material, "bottom": r0, "top": r1, "sides": sides}, extra)

static func _cone(from: Vector3, to: Vector3, r: float, material: String = "body", extra: Dictionary = {}, sides: int = 5) -> Dictionary:
	## A cone from its base at `from` to its point at `to`.
	return _m({"shape": "cone", "from": _v(from), "to": _v(to), "material": material, "radius": r, "sides": sides}, extra)

static func _crystal(from: Vector3, to: Vector3, r: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	## A crystal grown from `from` to its point at `to`, swaying.
	return _m({"shape": "crystal", "from": _v(from), "to": _v(to), "material": material, "motion": "crystal", "radius": r}, extra)

static func _disc(at: Vector3, normal: Vector3, radius: float, thick: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## A hex plate facing `normal`: a table, an end plate, a sucker's mouth.
	return _m({"shape": "cylinder", "at": _v(at), "aim": _v(normal), "material": material, "top": radius, "bottom": radius, "height": thick, "sides": 6}, extra)

static func _hoop(at: Vector3, normal: Vector3, radius: float, width: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## A flat eight-sided ring facing `normal`.
	return _m({"shape": "ring", "at": _v(at), "aim": _v(normal), "material": material, "radius": radius, "width": width, "segments": 8}, extra)

static func _band(hub: Vector3, axle: Vector3, radius: float, n: int, thick: float, depth: float, material: String, extra: Dictionary = {}) -> Array:
	## A lowpoly hoop in place of a torus: `n` boxes laid end to end round `axle` at `hub`,
	## every one pivoting at the hub, so `spin` turns the band on its axle and `orbit`
	## precesses it. `radius` runs to the middle of the boxes, `thick` is their radial depth,
	## `depth` their size along the axle.
	var out: Array = []
	var length: float = 2.0 * (radius + thick * 0.5) * tan(PI / float(n)) * 1.02
	for i in range(n):
		var ang: float = TAU * float(i) / float(n)
		out.append(_m({"shape": "box", "at": _v(hub), "aim": _v(axle), "offset": [radius * cos(ang), 0, radius * sin(ang)], "mesh_rot": [0, -rad_to_deg(ang), 0], "material": material, "size": [thick, depth, length]}, extra.duplicate()))
	return out

static func _shard(at: Vector3, rot: Array, size: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## A splinter of crystal.
	return _m({"shape": "shard", "at": _v(at), "rot": rot, "scale": size, "material": material, "size": 0.12}, extra)

static func _hang(pieces: Array, joint: Vector3, motion: String, phase: float, name: String = "") -> Array:
	## Every piece hung from one joint, moving as one (and named as one when `name` is given).
	for piece in pieces:
		piece.merge({"joint": _v(joint), "motion": motion, "phase": phase}, true)
		if name != "":
			piece["name"] = name
	return pieces

## ---- the Null Shade ---------------------------------------------------------------------------

static func _rings(out: Array, heights: Array, radii: Array, tilts: Array, material: String = "accent") -> void:
	## Flat eight-sided rings (`ring`) laid under a body, each tilted its own way and
	## precessing on its own beat.
	for i in range(heights.size()):
		out.append(_hoop(Vector3(0, heights[i], 0), _axis_of(tilts[i]), radii[i] + 0.04, 0.08, material, {"name": "ring", "motion": "orbit", "phase": float(i) * 2.1}))

static func _motes(out: Array, specs: Array, size: float = 0.03, rings: int = 3, extra: Dictionary = {}) -> void:
	## Small gems of light, each [where, phase], circling the body. (The Star Leech's stars too.)
	for spec in specs:
		out.append(_m(_gem(spec[0], size, "accent", {"motion": "orbit", "phase": spec[1], "segments": 5, "rings": rings}), extra.duplicate()))

## ---- the Infinite Void ------------------------------------------------------------------------

static func _on_disc(hub: Vector3, axle: Vector3, r: float, ang: float, lift: float, part: Dictionary, twist: Vector3 = Vector3.ZERO) -> Dictionary:
	## A piece pivoting on `hub` and laid `r` out from it in the plane across `axle`, so `spin`
	## turns it round the hub in that plane with every other piece of the same phase: a spiral
	## arm. `twist` turns the piece where it lies.
	part.merge({"at": _v(hub), "aim": _v(axle), "offset": [r * cos(ang), lift, r * sin(ang)], "mesh_rot": [twist.x, -rad_to_deg(ang) + twist.y, twist.z]}, true)
	return part

static func _rubble(out: Array, seed: int) -> void:
	## Broken floor under the hole: slabs heaved up round it, a few stones lifting off.
	for i in range(7):
		var ang: float = TAU * float(i) / 7.0 + 0.3
		var r: float = 1.05 + 0.25 * float(i % 2)
		var out_dir := Vector3(cos(ang), 0, sin(ang))
		out.append({"shape": "slab", "at": _v(out_dir * r + Vector3(0, 0.12, 0)), "rot": _rot(Basis(Vector3.UP, -ang) * Basis(Vector3.BACK, deg_to_rad(28.0 + 10.0 * float(i % 3)))), "material": "body", "size": [0.5, 0.14, 0.42], "jitter": 0.06, "seed": seed + i})
	for spec in [[Vector3(0.35, 0.55, 0.3), 0.12, 0.0], [Vector3(-0.4, 0.85, -0.1), 0.1, 1.4], [Vector3(0.1, 1.1, -0.45), 0.08, 2.8]]:
		out.append(_rock(spec[0], Vector3(spec[1], spec[1] * 0.8, spec[1]), "body", 0.2, seed + 20, {"motion": "bob", "phase": spec[2]}))

## ---- Hush -------------------------------------------------------------------------------------

static func _run(out: Array, pts: Array, r0: float, r1: float, material: String, seed: int, jitter: float = 0.07, extra: Dictionary = {}) -> void:
	## Cut stones laid point to point, each half again as long as its step so neighbours
	## overlap and the run reads as one body with no gaps.
	var n: int = pts.size() - 1
	for i in range(n):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var r: float = lerpf(r0, r1, (float(i) + 0.5) / float(n))
		out.append(_m({"shape": "rock", "at": _v((a + b) * 0.5), "aim": _v(b - a), "scale": [r, maxf(a.distance_to(b) * 1.0, r * 0.85), r], "material": material, "jitter": jitter, "seed": seed + i}, extra.duplicate()))

static func _closed_eye(out: Array, at: Vector3, normal: Vector3, width: float, extra: Dictionary = {}) -> void:
	## A shut eye: a lit crescent of four short bars curving up at its corners, with five
	## crystal lashes hanging from it. The only feature on a faceless thing.
	var fr: Array = _perp(normal)
	var right: Vector3 = fr[0]
	var up: Vector3 = fr[1]
	var f: Vector3 = normal.normalized()
	var pts: Array = []
	for t in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		pts.append(at + right * t * width * 0.5 + up * (t * t * width * 0.22) - f * (t * t * width * 0.12))
	for i in range(4):
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[i + 1]
		out.append(_m({"shape": "box", "at": _v((p + q) * 0.5), "aim": _v(q - p), "material": "accent", "size": [0.032, p.distance_to(q) * 1.18, 0.032]}, extra.duplicate()))
	for t in [-0.7, -0.35, 0.0, 0.35, 0.7]:
		var root: Vector3 = at + right * t * width * 0.5 + up * (t * t * width * 0.22) - f * (t * t * width * 0.12)
		out.append(_crystal(root, root - up * 0.075 + f * 0.035 + right * t * 0.03, 0.012, "accent", extra.duplicate()))

## ---- the Star Leech ---------------------------------------------------------------------------

static func _brilliant(out: Array, girdle: Vector3, axis: Vector3, r: float, crown_h: float, pav_h: float, table_k: float, body: String, edge: String, extra: Dictionary = {}, roll_deg: float = 0.0, waist: float = 0.0, crown_mat: String = "") -> void:
	## A brilliant-cut gem, girdle centre at `girdle`, table up `axis`: a hex pavilion running
	## to a point, (an optional straight hex waist,) a hex crown up to a flat table, and bright
	## edges down every facet ridge and round the girdle so it reads as a cut stone.
	var a: Vector3 = axis.normalized()
	var basis: Basis = _aimed(a)
	var spin := {"mesh_rot": [0, roll_deg, 0]}
	var top: Vector3 = girdle + a * waist
	var point: Vector3 = girdle - a * pav_h
	var table: Vector3 = top + a * crown_h
	out.append(_m(_m(_cone(girdle, point, r, body, {}, 6), spin.duplicate()), extra.duplicate()))
	if waist > 0.0:
		out.append(_m(_m(_rod(girdle, top, r, r, body), spin.duplicate()), extra.duplicate()))
	out.append(_m(_m(_rod(top, table, r, r * table_k, body if crown_mat == "" else crown_mat), spin.duplicate()), extra.duplicate()))
	out.append(_m(_m(_disc(table + a * 0.004, a, r * table_k * 0.99, 0.014, edge), spin.duplicate()), extra.duplicate()))
	var th: float = clampf(r * 0.06, 0.012, 0.05)
	var corners: Array = []
	for k in range(6):
		var ang: float = TAU * float(k) / 6.0 + deg_to_rad(roll_deg)
		corners.append(basis.x * sin(ang) + basis.z * cos(ang))
	for k in range(6):
		var c: Vector3 = corners[k]
		var c2: Vector3 = corners[(k + 1) % 6]
		out.append(_m(_bar(girdle + c * r, point, th, edge), extra.duplicate()))
		out.append(_m(_bar(top + c * r, table + c * r * table_k, th, edge), extra.duplicate()))
		out.append(_m(_bar(girdle + c * r * 1.005, girdle + c2 * r * 1.005, th * 1.2, edge), extra.duplicate()))
		if waist > 0.0:
			out.append(_m(_bar(girdle + c * r, top + c * r, th, edge), extra.duplicate()))

static func _leech_body(out: Array, pts: Array, radii: Array, seed: int, extra: Dictionary = {}, rear: int = -1, rear_extra: Dictionary = {}) -> void:
	## Pale cut stones overlapping point to point, a darker stone pushed up through the back of
	## each so the top is a run of dark facets, white gem stars set in them. The stones from
	## segment `rear` on wear `rear_extra` instead of `extra` (the neck the leech rears on).
	var offs_s: Array = [0.35, -0.4, 0.05, -0.15, 0.45, -0.3, 0.2]
	var offs_t: Array = [-0.2, 0.25, 0.0, 0.3, -0.3]
	for i in range(pts.size() - 1):
		var e: Dictionary = rear_extra if rear >= 0 and i >= rear else extra
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var r: float = (float(radii[i]) + float(radii[i + 1])) * 0.5
		var t: Vector3 = (b - a).normalized()
		var mid: Vector3 = (a + b) * 0.5
		var seg: float = a.distance_to(b)
		out.append(_m({"shape": "rock", "at": _v(mid), "aim": _v(t), "scale": [r, maxf(seg * 0.78, r * 0.8), r], "material": "body", "jitter": 0.07, "seed": seed + i}, e.duplicate()))
		var n: Vector3 = Vector3.UP - t * t.dot(Vector3.UP)
		if n.length() < 0.1:
			n = Vector3.BACK
		n = n.normalized()
		var s: Vector3 = t.cross(n).normalized()
		out.append(_m({"shape": "rock", "at": _v(mid + n * r * 0.42), "aim": _v(t), "scale": [r * 0.72, maxf(seg * 0.6, r * 0.6), r * 0.72], "material": "iron", "jitter": 0.16, "seed": seed + 50 + i}, e.duplicate()))
		var star: Vector3 = mid + n * r * 1.16 + s * r * float(offs_s[i % offs_s.size()]) + t * seg * float(offs_t[i % offs_t.size()])
		out.append(_m(_eye(star, 0.026 if i % 3 != 1 else 0.034), e.duplicate()))
		if i % 2 == 0:
			var star2: Vector3 = mid + n * r * 1.1 - s * r * float(offs_s[(i + 3) % offs_s.size()]) * 0.8 - t * seg * 0.3
			out.append(_m(_eye(star2, 0.018), e.duplicate()))

static func _sucker(out: Array, at: Vector3, dir: Vector3, r: float, teeth: int, extra: Dictionary = {}) -> void:
	## A round toothed sucker facing `dir`: a glowing hex mouth, a pale lip, bright teeth.
	var f := dir.normalized()
	var fr: Array = _perp(f)
	out.append(_disc(at, f, r, 0.04, "core", extra.duplicate()))
	out.append_array(_band(at, f, r + 0.012, 6, 0.045, 0.07, "body", extra))
	out.append(_m(_eye(at + f * 0.02, r * 0.32, "iron"), extra.duplicate()))
	for k in range(teeth):
		var ang: float = TAU * float(k) / float(teeth)
		var radial: Vector3 = fr[0] * cos(ang) + fr[1] * sin(ang)
		out.append(_cone(at + radial * r * 0.82 + f * 0.02, at + radial * r * 0.3 + f * 0.09, 0.022, "accent", extra.duplicate()))

static func _leech_head(out: Array, pts: Array, r: float, mouth_r: float, teeth: int, extra: Dictionary = {}) -> void:
	## The sucker on the end of the body (`mouth`, about its own middle) and two small eye gems
	## on the head behind it (wearing `extra`).
	var tip: Vector3 = pts[pts.size() - 1]
	var dir: Vector3 = (tip - (pts[pts.size() - 2] as Vector3)).normalized()
	var mouth: Vector3 = tip + dir * 0.03
	_sucker(out, mouth, dir, mouth_r, teeth, {"name": "mouth", "joint": _v(mouth)})
	var n: Vector3 = (Vector3.UP - dir * dir.dot(Vector3.UP))
	if n.length() < 0.1:
		n = Vector3.BACK
	n = n.normalized()
	var s: Vector3 = dir.cross(n).normalized()
	var head: Vector3 = tip - dir * 0.05
	out.append(_eye(head + n * r * 0.95 + s * r * 0.45, 0.03, "accent", extra.duplicate()))
	out.append(_eye(head + n * r * 0.95 - s * r * 0.45, 0.03, "accent", extra.duplicate()))

## ---- the Timeglass ----------------------------------------------------------------------------

static func _hourglass(out: Array, centre: Vector3, axis: Vector3, hh: float, r: float, extra: Dictionary = {}, sand: Dictionary = {}) -> void:
	## Two six-sided glass cones tip to tip in a frame: dim glowing glass, the sand that has
	## already run up packed bright under the top plate, the last of it bright in the bottom,
	## a lit neck, hex plates at both ends and three posts with gem knobs. Every piece wears
	## `extra`; the three of sand wear `sand` over it.
	var up: Vector3 = axis.normalized()
	var top: Vector3 = centre + up * hh
	var bot: Vector3 = centre - up * hh
	out.append(_m({"shape": "cone", "from": _v(top), "to": _v(centre), "material": "core", "radius": r, "sides": 6}, extra.duplicate()))
	out.append(_m({"shape": "cone", "from": _v(bot), "to": _v(centre), "material": "core", "radius": r, "sides": 6}, extra.duplicate()))
	out.append(_rod(centre + up * hh * 0.58, top, r * 0.58 + 0.012, r + 0.012, "accent", _m(extra.duplicate(), sand)))
	out.append(_rod(bot, bot + up * hh * 0.2, r + 0.012, r * 0.8 + 0.012, "accent", _m(extra.duplicate(), sand)))
	out.append(_rod(centre - up * 0.05, centre + up * 0.05, r * 0.16, r * 0.16, "accent", _m(extra.duplicate(), sand)))
	out.append(_disc(top + up * 0.03, up, r + 0.08, 0.06, "iron", extra.duplicate()))
	out.append(_disc(bot - up * 0.03, up, r + 0.08, 0.06, "iron", extra.duplicate()))
	var fr: Array = _perp(up)
	for deg in [30.0, 150.0, 270.0]:
		var ang: float = deg_to_rad(deg)
		var off: Vector3 = (fr[0] * cos(ang) - fr[1] * sin(ang)) * (r + 0.05) if absf(up.y) < 0.9 else Vector3(cos(ang), 0, sin(ang)) * (r + 0.05)
		out.append(_m({"shape": "column", "from": _v(bot + off), "to": _v(top + off), "material": "body", "radius": r * 0.11, "sides": 5}, extra.duplicate()))
		out.append(_m(_eye(top + off + up * 0.07, r * 0.13), extra.duplicate()))
		out.append(_m(_eye(bot + off - up * 0.07, r * 0.13), extra.duplicate()))

static func _tri_leg(out: Array, hip: Vector3, knee: Vector3, foot: Vector3, r: float, phase: float) -> void:
	## A crystal leg (`leg`) swinging from its hip: a hex thigh, a cut-stone knee, a crystal
	## shin to its point.
	var extra := {"name": "leg", "joint": _v(hip), "motion": "swing", "phase": phase}
	out.append(_rod(hip, knee, r, r * 0.8, "body", extra.duplicate()))
	out.append(_m({"shape": "rock", "at": _v(knee), "scale": r * 1.4, "material": "body", "jitter": 0.08}, extra.duplicate()))
	out.append(_m({"shape": "crystal", "from": _v(knee), "to": _v(foot), "material": "body", "radius": r * 0.8, "sides": 5}, extra.duplicate()))

## ---- the Paradox Moth -------------------------------------------------------------------------

static func _wing(out: Array, role: String, shoulder: Vector3, side: float, lift: float, length: float, width: float, material: String, phase: float, z_off: float = 0.0, spot: bool = false, sweep: float = 32.0) -> void:
	## A triangular wing of glass hinged at `shoulder`, beating; an eye-spot gem on it when
	## `spot`, laid on the same pivot so it beats with the wing. Named `<role>_l` on the
	## creature's own left (+x), `<role>_r` on its right.
	var base := {"at": _v(shoulder), "rot": [0, side * sweep, side * lift], "motion": "wing", "side": side, "phase": phase, "name": role + ("_l" if side > 0.0 else "_r")}
	out.append(_m({"shape": "prism", "material": material, "mesh_rot": [0, 0, -side * 90.0], "offset": [side * length * 0.5, 0, z_off], "size": [width, length, 0.025]}, base.duplicate()))
	if spot:
		out.append(_m({"shape": "sphere", "material": "accent", "offset": [side * length * 0.3, 0, z_off + 0.02], "scale": [0.06, 0.06, 0.03], "radius": 1.0, "segments": 5, "rings": 2}, base.duplicate()))

static func _lantern(out: Array, top: Vector3, bottom: Vector3, r: float, extra: Dictionary = {}) -> void:
	## A hex lantern from `top` to `bottom`: an iron hood, lit glass, iron bars over the glass,
	## an iron foot and a drop of light under it.
	var ax: Vector3 = (bottom - top).normalized()
	var length: float = top.distance_to(bottom)
	var g0: Vector3 = top + ax * length * 0.2
	var g1: Vector3 = top + ax * length * 0.82
	out.append(_rod(top, g0, r * 0.55, r * 1.12, "iron", extra.duplicate()))
	out.append(_rod(g0, g1, r, r, "accent", _m({"motion": "core"}, extra.duplicate())))
	out.append(_rod(g1, bottom, r * 1.1, r * 0.6, "iron", extra.duplicate()))
	out.append(_m(_eye(bottom + ax * 0.04, r * 0.32), extra.duplicate()))
	var fr: Array = _perp(ax)
	for k in range(6):
		var ang: float = TAU * (float(k) + 0.5) / 6.0
		var off: Vector3 = (fr[0] * cos(ang) + fr[1] * sin(ang)) * r * 0.95
		out.append(_m({"shape": "box", "at": _v((g0 + g1) * 0.5 + off), "aim": _v(ax), "material": "iron", "size": [0.012, length * 0.64, 0.012]}, extra.duplicate()))

static func _moth_head(out: Array, head: Vector3, s: float, neck: Vector3) -> void:
	## A cut-stone head and two gem eyes (`head`, hinged at `neck`), and two feathered crystal
	## antennae (`antenna`, each swaying as one about its root on the head).
	var nod := {"name": "head", "joint": _v(neck)}
	out.append(_rock(head, Vector3(0.09, 0.08, 0.09) * s, "body", 0.08, 5001, nod.duplicate()))
	for side in [-1.0, 1.0]:
		out.append(_eye(head + Vector3(side * 0.065, 0.02, 0.05) * s, 0.042 * s, "accent", nod.duplicate()))
		var root: Vector3 = head + Vector3(side * 0.04, 0.07, 0.03) * s
		var tip: Vector3 = root + Vector3(side * 0.17, 0.22, 0.1) * s
		var feeler := {"name": "antenna", "joint": _v(root), "phase": 0.0 if side > 0.0 else 1.5}
		out.append(_crystal(root, tip, 0.013 * s, "accent", feeler.duplicate()))
		for f in [0.45, 0.75]:
			var p: Vector3 = root.lerp(tip, f)
			out.append(_crystal(p, p + Vector3(side * 0.07, 0.0, -0.03) * s, 0.009 * s, "accent", feeler.duplicate()))
