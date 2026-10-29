extends RefCounted
## Recipes for tools/creature_bake.gd: the Warrens. See tools/creature_bake.gd for the format.
## The Warrens are fungal: caps, gills, spores, roots, rot, mycelium threads and glowing fungus,
## built low poly and angular out of cut stones, crystals and gems.
##
## Seven of these are the owner's picks from the creature model review (Oct 28), moved in from
## build/options/recipes/ (r3d, r3c and warrens). Each keeps its review key as its "seed", so
## its unseeded rocks, crystals and slabs are cut facet for facet as picked: do not add, drop
## or reorder their parts (the facets are drawn from one random stream in part order). The
## parts an animation moves carry a "name" (and a "joint" where they turn);
## build/options/part_roles/warrens.md says which way each one moves. The Puffball is today's
## model, untouched.
##
## z+ faces the party, y is up, +x is the creature's own left. Wardens are authored 2.5-3.9
## units tall and scaled 1.5x by the bake.

static func recipes() -> Dictionary:
	return {
		"CAP_SHAMBLER": _cap_shambler(),
		"MYCEL_WEAVER": _mycel_weaver(),
		"PUFFBALL": _puffball(),
		"ROOT_HORROR": _root_horror(),
		"TENDRIL": _tendril(),
		"THE_GARDENER": _gardener(),
		"THE_HEARTROT": _heartrot(),
		"THE_SPORE_MOTHER": _spore_mother()}

## ---- Mycel Weaver -------------------------------------------------------------------------

static func _mycel_weaver() -> Dictionary:
	## A spider-like stilt weaver standing in its web: eight threads from a hub under the body to
	## each shin at different heights, three uneven rounds of cross thread with a few strands
	## broken, dew gems. (The review's MYCEL_WEAVER_R in r3d.)
	var tint := "4a6a3a"
	var accent := "c8ff6a"
	## The body (thorax, abdomen, cap) breathes as one about the thorax; the head and its fangs
	## sit in front of it.
	var body := {"name": "body", "joint": [0, 1.1, 0.04], "motion": "core", "phase": 0.0}
	var head := {"name": "head", "joint": [0, 1.05, 0.18]}
	var jaw := {"name": "jaw", "joint": [0, 0.94, 0.34]}
	var c: Array = [
		{"shape": "rock", "at": [0, 1.1, 0.04], "scale": [0.24, 0.2, 0.24], "material": "body", "jitter": 0.1, "seed": 15}.merged(body),
		_gem(Vector3(0, 1.06, -0.26), Vector3(0.24, 0.2, 0.28), "core", body),
		{"shape": "cap", "at": [0, 1.22, -0.12], "rot": [-10, 0, 6], "material": "accent", "radius": 0.34, "height": 0.16, "sides": 7}.merged(body),
		_stone(Vector3(0, 1.02, 0.28), 0.14, "body", head.merged({"seed": 27})),
		_eye(Vector3(0.07, 1.08, 0.4), 0.045, head), _eye(Vector3(-0.07, 1.08, 0.4), 0.045, head),
		_stick("cone", Vector3(0.06, 0.94, 0.34), Vector3(0.04, 0.74, 0.4), 0.03, 0.03, "iron", jaw.merged({"sides": 4})),
		_stick("cone", Vector3(-0.06, 0.94, 0.34), Vector3(-0.04, 0.74, 0.4), 0.03, 0.03, "iron", jaw.merged({"sides": 4})),
		_stick("cylinder", Vector3(0, 0.92, -0.48), Vector3(0.05, 0.05, -0.36), 0.01, 0.01, "core", {"sides": 3}),
		_eye(Vector3(0.05, 0.04, -0.36), 0.045)]
	var hips: Dictionary = {}
	var knees: Dictionary = {}
	var feet: Dictionary = {}
	var spreads_c: Array = [0.42, 0.15, -0.14, -0.42]
	for side in [-1.0, 1.0]:
		for leg in range(4):
			var hip := Vector3(side * 0.14, 1.08, 0.16 - 0.1 * float(leg))
			var spread: float = spreads_c[leg]
			var knee := Vector3(side * 0.56, 1.5 - 0.05 * float(leg), hip.z + spread)
			var foot := Vector3(side * 0.82, 0.02, hip.z + spread * 1.7)
			var limb := {"name": "leg", "joint": _v(hip)}
			c.append(_stick("column", hip, knee, 0.044, 0.034, "body", limb))
			c.append(_stone(knee, 0.05, "body", limb))
			c.append(_stick("crystal", knee, foot, 0.032, 0.032, "body", limb))
			hips["%d_%d" % [int(side), leg]] = hip
			knees["%d_%d" % [int(side), leg]] = knee
			feet["%d_%d" % [int(side), leg]] = foot
	## The web. Legs in order round the hub; each thread meets its shin at its own height.
	var ring_order: Array = ["1_0", "1_1", "1_2", "1_3", "-1_3", "-1_2", "-1_1", "-1_0"]
	var heights: Dictionary = {"1_0": 0.34, "1_1": 0.22, "1_2": 0.4, "1_3": 0.27, "-1_3": 0.36, "-1_2": 0.2, "-1_1": 0.42, "-1_0": 0.28}
	var hub := Vector3(0.04, 0.5, -0.06)
	var anchors: Array = []
	for key in ring_order:
		var knee: Vector3 = knees[key]
		var foot: Vector3 = feet[key]
		var t: float = (float(heights[key]) - foot.y) / (knee.y - foot.y)
		anchors.append(foot.lerp(knee, t))
	var thread := {"sides": 3}
	for p in anchors:
		c.append(_stick("cylinder", hub, p, 0.009, 0.009, "core", thread))
	c.append(_stick("cylinder", hub, Vector3(0.0, 0.94, 0.02), 0.008, 0.008, "core", thread))
	c.append(_gem(hub, 0.03, "accent"))
	## Three rounds of cross thread, each strand at its own reach along its two radials, some
	## strands missing; dew on a few.
	var rounds: Array = [[0.3, 0.26, 0.34, 0.28, 0.32, 0.25, 0.33, 0.29], [0.58, 0.52, 0.62, 0.55, 0.6, 0.5, 0.64, 0.56], [0.84, 0.8, 0.88, 0.82, 0.86, 0.78, 0.9, 0.83]]
	var broken: Array = ["1_3", "2_5", "2_0", "1_6"]
	var dew: Array = ["0_2", "1_1", "1_4", "2_3", "2_6", "1_7"]
	for ri in range(rounds.size()):
		var reach: Array = rounds[ri]
		for i in range(8):
			if broken.has("%d_%d" % [ri, i]):
				continue
			var j: int = (i + 1) % 8
			var p: Vector3 = hub.lerp(anchors[i], float(reach[i]))
			var q: Vector3 = hub.lerp(anchors[j], float(reach[j]))
			c.append(_stick("cylinder", p, q, 0.007, 0.007, "core", thread))
			if dew.has("%d_%d" % [ri, i]):
				c.append(_eye(p.lerp(q, 0.45), 0.024))
	## Two caps grown on knees ride with their legs.
	_mushroom(c, Vector3(0.56, 1.44, 0.21), Vector3(0.3, 1, 0), 0.12, 0.02, 0.08, 0.045, "core", "accent", {"name": "leg", "joint": _v(hips["1_1"])})
	_mushroom(c, Vector3(-0.56, 1.39, -0.18), Vector3(-0.3, 1, 0), 0.1, 0.018, 0.07, 0.04, "core", "accent", {"name": "leg", "joint": _v(hips["-1_2"])})
	c.append(_mouth(Vector3(0, 0.92, 0.4), {"joint": head["joint"]}))
	return {"style": "low", "sway": 2.4, "tint": tint, "accent": accent, "anchor": 1.85, "shadow": 2.6, "ring": 1.3, "seed": "MYCEL_WEAVER_R", "parts": c}

## ---- Cap Shambler -------------------------------------------------------------------------

static func _cap_shambler() -> Dictionary:
	## The cap cluster: one root-mass on six crawling root-legs with a crowd of caps of every
	## size grown out of it, the biggest with a gill ring and eyes under its brim, a toothed mouth
	## low in the mass, young glowing caps and crystal sprouts at the edges.
	var tint := "c85a8a"
	var accent := "c8ff6a"
	## The toothed mouth: an iron lip with two fangs, hinged behind it in the mass.
	var jaw := {"name": "jaw", "joint": [0, 0.5, 0.45]}
	## The big cap is the head: its stalk, gill ring, the eyes under its brim and the spots on it.
	var head := {"name": "head", "joint": [0.05, 0.8, -0.05]}
	var b: Array = [
		{"shape": "rock", "at": [0, 0.52, 0], "scale": [0.64, 0.42, 0.56], "material": "body", "motion": "core", "jitter": 0.22, "seed": 31},
		{"shape": "box", "at": [0, 0.5, 0.6], "rot": [0, 0, 4], "material": "iron", "size": [0.34, 0.04, 0.06]}.merged(jaw),
		_stick("cone", Vector3(0.1, 0.5, 0.6), Vector3(0.1, 0.4, 0.64), 0.025, 0.025, "iron", jaw.merged({"sides": 4})),
		_stick("cone", Vector3(-0.08, 0.5, 0.6), Vector3(-0.08, 0.41, 0.64), 0.025, 0.025, "iron", jaw.merged({"sides": 4}))]
	for i in range(6):
		var ang: float = TAU * float(i) / 6.0 + 0.5
		var out_dir := Vector3(cos(ang), 0, sin(ang))
		_leg(b, out_dir * 0.4 + Vector3(0, 0.3, 0), out_dir * 0.68 + Vector3(0, 0.26, 0), out_dir * 0.8 + Vector3(0, 0.02, 0), 0.1, 0.09, float(i) * 1.1)
	_mushroom(b, Vector3(0.05, 0.8, -0.05), Vector3(0.05, 1, -0.05), 0.55, 0.15, 0.62, 0.3, "body", "body", head.merged({"seed": 32}))
	_mushroom(b, Vector3(0.34, 0.7, 0.3), Vector3(0.45, 1, 0.35), 0.42, 0.1, 0.38, 0.2, "body", "body", {"seed": 33})
	_mushroom(b, Vector3(-0.36, 0.72, 0.1), Vector3(-0.5, 1, 0.1), 0.4, 0.09, 0.34, 0.18, "body", "body", {"seed": 34})
	_mushroom(b, Vector3(-0.1, 0.78, -0.42), Vector3(-0.2, 1, -0.6), 0.3, 0.06, 0.24, 0.13, "body", "accent", {"seed": 35})
	_mushroom(b, Vector3(-0.22, 0.66, 0.44), Vector3(-0.2, 0.9, 0.7), 0.22, 0.05, 0.2, 0.1, "body", "accent", {"seed": 36})
	_hoop(b, Vector3(0.07, 1.33, -0.07), Vector3(0.05, 1, -0.05), 0.4, 0.07, 8, "core", head)
	b.append(_eye(Vector3(0.13, 1.2, 0.07), 0.045, head))
	b.append(_eye(Vector3(-0.03, 1.2, 0.07), 0.045, head))
	b.append(_eye(Vector3(0.47, 0.92, 0.47), 0.04))
	for spec in [[Vector3(0.25, 1.55, 0.1), 0.06], [Vector3(-0.2, 1.52, -0.3), 0.055], [Vector3(0.0, 1.66, -0.02), 0.05]]:
		b.append(_eye(spec[0], spec[1], head))
	for spec in [[Vector3(0.52, 0.62, -0.28), Vector3(0.22, 0.34, -0.14)], [Vector3(-0.5, 0.5, -0.25), Vector3(-0.2, 0.3, -0.1)], [Vector3(0.2, 0.66, 0.5), Vector3(0.1, 0.3, 0.14)]]:
		b.append(_stick("crystal", spec[0], spec[0] + spec[1], 0.05, 0.05, "accent", {"motion": "crystal"}))
	_spores(b, [[Vector3(0.7, 1.4, 0.4), 0.035], [Vector3(-0.75, 1.1, 0.2), 0.03], [Vector3(0.2, 1.85, -0.5), 0.03], [Vector3(-0.3, 1.0, 0.85), 0.035]])
	b.append(_mouth(Vector3(0, 0.46, 0.66)))
	return {"style": "cluster", "sway": 1.2, "tint": tint, "accent": accent, "anchor": 1.9, "shadow": 2.4, "ring": 1.2, "seed": "CAP_SHAMBLER_B", "parts": b}

## ---- Root Horror --------------------------------------------------------------------------

static func _root_horror() -> Dictionary:
	## The walking stump: a hex trunk up on five arching root legs with crystal feet, a vertical
	## split down its front glowing from the heart inside and lined with teeth, knot-hole eyes,
	## two crystal-tipped root arms raised, bracket fungus up the bark.
	var tint := "6a5232"
	var accent := "e0ff8a"
	var b: Array = [
		_stick("column", Vector3(0, 0.55, 0), Vector3(0.04, 1.75, 0.0), 0.42, 0.42, "body", {"motion": "core"}),
		{"shape": "rock", "at": [0.04, 1.76, 0], "scale": [0.47, 0.14, 0.47], "material": "body", "jitter": 0.3, "seed": 54},
		{"shape": "rock", "at": [0.38, 1.2, -0.25], "scale": [0.2, 0.3, 0.2], "material": "body", "jitter": 0.25, "seed": 55},
		{"shape": "rock", "at": [-0.3, 0.9, -0.32], "scale": [0.22, 0.26, 0.2], "material": "body", "jitter": 0.25, "seed": 56},
		{"shape": "box", "at": [0, 1.2, 0.36], "material": "core", "motion": "core", "size": [0.24, 0.72, 0.16], "name": "mouth"},
		_gem(Vector3(0, 1.2, 0.34), 0.15, "accent", {"motion": "core", "phase": 0.6, "name": "heart"}),
		_eye(Vector3(0.2, 1.62, 0.37), 0.05, {"name": "eye"}), _eye(Vector3(-0.2, 1.62, 0.37), 0.05, {"name": "eye"})]
	## The teeth down each side of the split: each row opens like a door on its own hinge.
	for y in [0.92, 1.1, 1.28, 1.46]:
		for side in [-1.0, 1.0]:
			var row := {"name": "jaw_l" if side > 0.0 else "jaw_r", "joint": [side * 0.17, 1.2, 0.42], "sides": 4}
			b.append(_stick("cone", Vector3(side * 0.17, y, 0.42), Vector3(side * 0.05, y + 0.03, 0.47), 0.03, 0.03, "iron", row))
	for i in range(5):
		var ang: float = TAU * float(i) / 5.0 + PI / 2.0 + PI / 5.0
		var out_dir := Vector3(cos(ang), 0, sin(ang))
		_leg(b, out_dir * 0.34 + Vector3(0, 0.66, 0), out_dir * 0.8 + Vector3(0, 0.44, 0), out_dir * 1.05 + Vector3(0, 0.02, 0), 0.12, 0.1, float(i) * 1.3)
	## The root arms: the one at +x (its own left) raised high, the one at -x reaching forward.
	var root_l := Vector3(0.4, 1.52, 0.1)
	_chain(b, [root_l, Vector3(0.86, 1.86, 0.36), Vector3(0.8, 2.24, 0.72)], 0.09, 0.05, "body", {"name": "arm_l", "joint": _v(root_l), "motion": "swing", "phase": 0.6})
	var root_r := Vector3(-0.4, 1.42, 0.14)
	_chain(b, [root_r, Vector3(-0.9, 1.5, 0.5), Vector3(-1.1, 1.18, 0.92)], 0.09, 0.05, "body", {"name": "arm_r", "joint": _v(root_r), "motion": "swing", "phase": 2.0})
	b.append({"shape": "cap", "at": [0.42, 1.38, -0.05], "rot": [0, 0, -25], "material": "accent", "radius": 0.2, "height": 0.07, "sides": 6})
	b.append({"shape": "cap", "at": [-0.4, 1.05, 0.2], "rot": [0, 0, 25], "material": "accent", "radius": 0.17, "height": 0.06, "sides": 6})
	b.append({"shape": "cap", "at": [0.15, 1.0, -0.4], "rot": [25, 0, -5], "material": "accent", "radius": 0.16, "height": 0.06, "sides": 6})
	_mushroom(b, Vector3(0.1, 1.82, 0.05), Vector3(0.2, 1, 0.1), 0.22, 0.035, 0.15, 0.08, "core", "accent", {"motion": "crystal", "phase": 0.0})
	_mushroom(b, Vector3(-0.18, 1.8, -0.15), Vector3(-0.3, 1, -0.2), 0.16, 0.03, 0.11, 0.06, "core", "accent", {"motion": "crystal", "phase": 1.2})
	return {"style": "stack", "sway": 1.0, "tint": tint, "accent": accent, "anchor": 2.45, "shadow": 2.8, "ring": 1.4, "seed": "ROOT_HORROR_B", "parts": b}

## ---- Tendril ------------------------------------------------------------------------------

static func _tendril() -> Dictionary:
	## The fiddlehead: the stalk curls in on itself like a young fern, buds swelling along the
	## curl, a glowing bud with petals of light at its heart.
	var tint := "5a7a2a"
	var accent := "ff5ab0"
	var b: Array = []
	_root_mat(b, Vector3(0, 0.07, 0), Vector3(0.6, 0.09, 0.6), 92, 4, 0.2, 0.6, 0.07, 0.9)
	## The mat turns a little so the first part moves; the stalk is still until the animation
	## sways and unfurls it (a swing on every segment would pull the curl apart).
	var mat: Dictionary = b[0]
	mat["motion"] = "block"
	var h := Vector3(cos(deg_to_rad(50.0)), 0, sin(deg_to_rad(50.0)))
	var stem_top := Vector3(0.04, 1.4, 0.0)
	var stem: Array = [Vector3(0, 0.05, 0), Vector3(0.02, 0.5, -0.03), Vector3(0.03, 0.95, -0.02), stem_top]
	var first: int = b.size()
	_chain(b, stem, 0.18, 0.12, "body", {}, false)
	var centre: Vector3 = stem_top + h * 0.34
	var sp: Array = [stem_top]
	var turns: int = 13
	for k in range(1, turns + 1):
		var th: float = float(k) / float(turns) * 1.85 * TAU
		var r: float = lerpf(0.34, 0.08, float(k) / float(turns))
		sp.append(centre + (-h * cos(th) + Vector3.UP * sin(th)) * r)
	_chain(b, sp, 0.1, 0.035, "body", {}, false)
	## One stalk from the floor to the bud, jointed at every link so it can uncurl in turn.
	_segments(b, first, "stalk")
	var bud: Vector3 = sp[turns]
	b.append(_gem(bud, 0.09, "core", {"name": "bud", "joint": _v(bud)}))
	for k in range(3):
		var ang: float = TAU * float(k) / 3.0 + 0.4
		var petal: Vector3 = Vector3(cos(ang), 0.4, sin(ang)).normalized()
		b.append(_stick("crystal", bud + petal * 0.04, bud + petal * 0.18, 0.03, 0.03, "accent", {"name": "petal", "joint": _v(bud + petal * 0.04), "motion": "swing", "phase": 0.3}))
	## The buds swelling along the curl and the thorns on the stem ride with their segments.
	for k in [3, 6, 9]:
		var p: Vector3 = sp[k]
		b.append(_eye(p + (p - centre).normalized() * 0.08, 0.035, {"name": "stalk", "joint": _v(p)}))
	for i in range(4):
		var p := Vector3(0.02, 0.3 + 0.28 * float(i), -0.02)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var seg: int = 0 if p.y < 0.5 else (1 if p.y < 0.95 else 2)
		b.append(_stick("crystal", p, p + Vector3(side * 0.16, 0.08, 0.04 * side), 0.03, 0.03, "body", {"sides": 4, "name": "stalk", "joint": _v(stem[seg])}))
	return {"style": "long", "sway": 1.3, "tint": tint, "accent": accent, "anchor": 2.0, "shadow": 1.6, "ring": 0.8, "seed": "TENDRIL_B", "parts": b}

## ---- Puffball (today's model) -------------------------------------------------------------

static func _puffball() -> Dictionary:
	## A swollen puffball on a squat foot, lit from inside, glowing spots and crystal spines.
	var puffball: Array = [
		{"shape": "rock", "at": [0, 0.5, 0], "scale": 0.55, "material": "body", "motion": "core", "jitter": 0.12, "seed": 61},
		{"shape": "sphere", "at": [0, 0.5, 0.0], "scale": 0.5, "material": "core", "motion": "core", "phase": 0.6, "radius": 1.0, "segments": 8, "rings": 4},
		{"shape": "cylinder", "at": [0, 0.12, 0], "material": "body", "top": 0.3, "bottom": 0.42, "height": 0.25, "sides": 7}]
	for i in range(6):
		var a: float = float(i) * TAU / 6.0 + 0.3
		puffball.append({"shape": "sphere", "at": [cos(a) * 0.46, 0.62 + sin(a * 1.7) * 0.2, sin(a) * 0.46], "scale": 0.07, "material": "accent", "motion": "core", "phase": a, "radius": 1.0, "segments": 5, "rings": 3})
		if i % 2 == 0:
			puffball.append({"shape": "crystal", "at": [cos(a) * 0.3, 0.95, sin(a) * 0.3], "rot": [cos(a) * 30.0, 0, -sin(a) * 30.0], "material": "accent", "motion": "crystal", "phase": a, "radius": 0.03, "height": 0.22})
	return {"style": "puff", "sway": 1.3, "tint": "e8e0a0", "accent": "a8c84a", "anchor": 1.3, "shadow": 1.6, "ring": 0.8, "parts": puffball}

## ---- The Gardener (Warden) ----------------------------------------------------------------

static func _gardener() -> Dictionary:
	## The crab tiller: a broad flat carapace with a hump of glowing soil planted in rows, eyes on
	## stalks, eight jointed legs, two arms ending in iron spade-claws (one raised to dig, one
	## driven into turned soil).
	var tint := "5a7a3a"
	var accent := "ffb0e0"
	var hump := Vector3(0, 1.32, -0.12)
	var hump_r := Vector3(0.72, 0.36, 0.56)
	var c: Array = [
		{"shape": "rock", "at": [0, 0.95, 0], "scale": [1.1, 0.38, 0.86], "material": "body", "motion": "core", "jitter": 0.1, "seed": 81},
		{"shape": "rock", "at": [0, 0.82, 0.78], "scale": [0.72, 0.26, 0.3], "material": "body", "jitter": 0.1, "seed": 82},
		{"shape": "rock", "at": _v(hump), "scale": _v(hump_r), "material": "core", "motion": "core", "phase": 0.5, "jitter": 0.2, "seed": 83}]
	for side in [-1.0, 1.0]:
		var base_e := Vector3(side * 0.3, 1.05, 0.88)
		var look := {"name": "eyestalk", "joint": _v(base_e), "motion": "block", "phase": 0.0 if side > 0.0 else 1.0}
		c.append(_stick("cylinder", base_e, Vector3(side * 0.42, 1.45, 1.02), 0.05, 0.04, "body", look.merged({"sides": 5}, true)))
		c.append(_eye(Vector3(side * 0.43, 1.5, 1.04), 0.1, look))
		c.append(_stick("cone", Vector3(side * 0.12, 0.7, 1.0), Vector3(side * 0.05, 0.56, 1.2), 0.04, 0.04, "iron", {"sides": 4}))
		for k in range(4):
			var z: float = 0.4 - 0.3 * float(k)
			var spread: float = 0.22 - 0.15 * float(k)
			var hip := Vector3(side * 0.95, 0.82, z)
			var knee := Vector3(side * 1.5, 1.16 - 0.06 * float(k), z + spread * 0.5)
			var foot := Vector3(side * 1.82, 0.03, z + spread * 1.8)
			_leg(c, hip, knee, foot, 0.08, 0.06, float(k) * 1.1 + (0.0 if side > 0.0 else 1.6))
	## The spade-claw at +x (its own left), raised to dig, swinging from the shoulder.
	var sh_l := Vector3(0.82, 0.92, 0.62)
	var el_l := Vector3(1.38, 1.5, 0.92)
	var wr_l := Vector3(1.5, 1.12, 1.38)
	var dir_l: Vector3 = (wr_l - el_l).normalized()
	for piece in [
		_stick("column", sh_l, el_l, 0.15, 0.13, "body"),
		_stone(el_l, 0.16, "body", {"seed": 95}),
		_stick("column", el_l, wr_l, 0.13, 0.11, "body"),
		{"shape": "box", "at": _v(wr_l + dir_l * 0.28), "aim": _v(dir_l), "material": "iron", "size": [0.44, 0.5, 0.07]},
		_stick("cone", wr_l + dir_l * 0.5, wr_l + dir_l * 0.72, 0.2, 0.2, "iron", {"sides": 4})]:
		piece.merge({"name": "claw_l", "joint": _v(sh_l), "motion": "swing", "phase": 0.6}, true)
		c.append(piece)
	## The spade-claw at -x (its own right), driven into the turned soil.
	var sh_r := Vector3(-0.82, 0.92, 0.62)
	var el_r := Vector3(-1.32, 1.0, 1.05)
	var wr_r := Vector3(-1.42, 0.5, 1.38)
	var dir_r := Vector3(-0.05, -0.85, 0.5).normalized()
	var claw_r := {"name": "claw_r", "joint": _v(sh_r)}
	c.append(_stick("column", sh_r, el_r, 0.15, 0.13, "body", claw_r))
	c.append(_stone(el_r, 0.16, "body", claw_r.merged({"seed": 96})))
	c.append(_stick("column", el_r, wr_r, 0.13, 0.11, "body", claw_r))
	c.append({"shape": "box", "at": _v(wr_r + dir_r * 0.25), "aim": _v(dir_r), "material": "iron", "size": [0.44, 0.5, 0.07]}.merged(claw_r))
	c.append({"shape": "rock", "at": [-1.2, 0.08, 1.75], "scale": 0.12, "material": "core", "jitter": 0.3, "seed": 84})
	c.append({"shape": "rock", "at": [-1.7, 0.07, 1.6], "scale": 0.1, "material": "core", "jitter": 0.3, "seed": 85})
	var plots: Array = [[Vector3(0.3, 1, 0.1), 0.4, 0.055, 0.28, 0.14], [Vector3(-0.4, 1, -0.3), 0.34, 0.05, 0.24, 0.12], [Vector3(0.1, 1, -0.7), 0.26, 0.04, 0.2, 0.1], [Vector3(-0.1, 1, 0.5), 0.22, 0.04, 0.18, 0.09]]
	for i in range(plots.size()):
		var plot: Array = plots[i]
		_mushroom(c, _on(hump, hump_r, plot[0], 0.95), plot[0], plot[1], plot[2], plot[3], plot[4], "core", "accent", {"motion": "crystal", "phase": float(i) * 1.2})
	for x in [-0.45, -0.15, 0.15, 0.45]:
		var root: Vector3 = _on(hump, hump_r, Vector3(x, 0.5, 0.15), 0.95)
		c.append(_stick("crystal", root, root + Vector3(0.04 * x, 0.3, 0.0), 0.035, 0.035, "core", {"motion": "crystal"}))
	return {"style": "low", "sway": 0.8, "tint": tint, "accent": accent, "anchor": 2.5, "warden": true, "shadow": 3.8, "ring": 1.8, "seed": "THE_GARDENER_C", "parts": c}

## ---- The Spore Mother (Warden) ------------------------------------------------------------

static func _spore_mother() -> Dictionary:
	## The toad mother, squatting: a bloated toad with its mouth lit pink corner to corner, a gem
	## throat sac, gem eyes with slit pupils on raised turrets, a warty back of puffball sacs and
	## spore caps, crystal toes, three of the brood at her feet. (The review's
	## THE_SPORE_MOTHER_A in r3c.)
	var tint := "b8c84a"
	var accent := "ff8ae0"
	## The head (and the eyes on it) lifts at the back of the skull; the lower jaw drops from its
	## back edge below the lit mouth; the throat sac swells under it.
	var head := {"name": "head", "joint": [0, 1.3, 0.2]}
	var a: Array = [
		_rock(Vector3(0, 1.0, -0.2), Vector3(1.35, 0.9, 1.2), "body", 0.1, 791, {"rot": [-10, 0, 0], "motion": "core"}),
		_rock(Vector3(0, 1.42, 0.78), Vector3(1.1, 0.48, 0.72), "body", 0.08, 792, head),
		{"shape": "slab", "at": [0, 0.88, 0.98], "rot": [5, 0, 0], "material": "body", "size": [1.6, 0.2, 0.85], "jitter": 0.04, "seed": 793, "name": "jaw", "joint": [0, 0.96, 0.56]},
		{"shape": "box", "at": [0, 1.04, 1.0], "material": "accent", "motion": "core", "size": [1.4, 0.1, 0.72]},
		_gem(Vector3(0, 0.6, 1.12), Vector3(0.5, 0.34, 0.4), "accent", {"motion": "core", "name": "throat"})]
	for side in [-1.0, 1.0]:
		var start: int = a.size()
		_toad_eye(a, Vector3(side * 0.56, 1.92, 0.86), 0.21, Vector3(side * 0.3, 0, 1))
		_tag(a, start, head)
		start = a.size()
		_toad_leg(a, Vector3(side * 0.95, 0.9, -0.75), Vector3(side * 1.5, 0.82, 0.1), Vector3(side * 1.55, 0.22, -0.62), Vector3(side * 1.62, 0.08, 0.18), 0.36, 795)
		_tag(a, start, {"name": "leg", "joint": [side * 0.95, 0.9, -0.75]})
		var fore := {"name": "leg", "joint": [side * 0.8, 0.9, 0.75]}
		a.append(_long_stone(Vector3(side * 0.8, 0.9, 0.75), Vector3(side * 1.12, 0.5, 0.98), 0.18, "body", 0.1, 798, fore))
		a.append(_stick("column", Vector3(side * 1.12, 0.5, 0.98), Vector3(side * 1.02, 0.08, 1.25), 0.11, 0.11, "body", fore))
		start = a.size()
		_toes(a, Vector3(side * 1.02, 0.06, 1.25), Vector3(side * 0.2, 0, 1), 3, 0.3)
		_tag(a, start, fore)
	var centre := Vector3(0, 1.0, -0.2)
	var radii := Vector3(1.35, 0.9, 1.2)
	var puffs: Array = [[Vector3(0.1, 1, -0.3), 0.32], [Vector3(-0.55, 0.9, 0.0), 0.24], [Vector3(0.6, 0.85, -0.1), 0.22], [Vector3(0.35, 0.8, -0.8), 0.2], [Vector3(-0.45, 0.7, -0.75), 0.26], [Vector3(-0.85, 0.5, 0.3), 0.16], [Vector3(0.9, 0.45, -0.45), 0.18]]
	for i in range(puffs.size()):
		var d: Vector3 = (puffs[i][0] as Vector3).normalized()
		a.append(_gem(centre + d * radii * 0.88, puffs[i][1], "core", {"motion": "core", "phase": float(i) * 0.9}))
	for spec in [[Vector3(-0.2, 1, -0.6), 0.5, 0.26], [Vector3(0.45, 1, 0.3), 0.36, 0.2], [Vector3(-0.7, 0.8, -0.3), 0.3, 0.18], [Vector3(0.75, 0.7, -0.75), 0.28, 0.17]]:
		var d: Vector3 = (spec[0] as Vector3).normalized()
		_spore_cap(a, centre + d * radii * 0.82, d + Vector3(0, 0.6, 0), spec[1], 0.06, spec[2], {"motion": "crystal"})
	for spec in [[Vector3(0.4, 2.4, -0.3), 0.0], [Vector3(-0.5, 2.6, -0.5), 1.3], [Vector3(0.0, 2.9, -0.1), 2.6], [Vector3(-0.2, 2.2, 0.2), 3.9]]:
		a.append({"shape": "shard", "at": _v(spec[0]), "rot": [spec[1] * 30.0, spec[1] * 50.0, 20], "material": "accent", "size": 0.06, "motion": "bob", "phase": spec[1]})
	_slime(a, Vector3(1.35, 0.0, 1.6), 0.2, 0.0)
	_slime(a, Vector3(-0.45, 0.0, 1.8), 0.16, 1.4)
	_slime(a, Vector3(-1.6, 0.0, 1.25), 0.18, 2.8)
	a.append(_mouth(Vector3(0, 1.04, 1.4), {"joint": head["joint"]}))
	return {"style": "blob", "sway": 0.8, "tint": tint, "accent": accent, "anchor": 2.6, "warden": true, "scale": 1.3, "shadow": 3.8, "ring": 1.9, "seed": "THE_SPORE_MOTHER_A", "parts": a}

## ---- The Heartrot (Warden) ----------------------------------------------------------------

static func _heartrot() -> Dictionary:
	## The heart finished: a gem heart of two six-sided lobes and a hanging crystal point, veined,
	## with cut vessels standing from its top and a pulsing core in the cleft, rooted into the
	## floor by six thick crystal-tipped roots, three barbed tendrils rising round it, bracket
	## caps on it.
	var tint := "5a7a2a"
	var accent := "ff5ab0"
	var a: Array = []
	var centre := Vector3(0, 1.75, 0)
	_heart(a, centre, 1.0, 3, 2)
	## The whole heart (lobes, point, veins, vessels) beats as one about its centre.
	_tag(a, 0, {"name": "heart", "joint": _v(centre), "motion": "core", "phase": 0.0})
	a.append({"shape": "rock", "at": [0, 0.08, 0], "scale": [0.95, 0.1, 0.95], "material": "body", "jitter": 0.3, "seed": 121})
	for i in range(6):
		var ang: float = TAU * float(i) / 6.0 + 0.25
		var out_dir := Vector3(cos(ang), 0, sin(ang))
		_chain(a, [out_dir * 0.35 + Vector3(0, 0.95, 0), out_dir * 0.9 + Vector3(0, 0.38, 0), out_dir * 1.5 + Vector3(0, 0.03, 0)], 0.16, 0.1, "body")
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0 + 0.4
		var out_dir := Vector3(cos(ang), 0, sin(ang))
		var base: Vector3 = out_dir * 1.2 + Vector3(0, 0.05, 0)
		var tip: Vector3 = out_dir * 1.2 + Vector3(0, 2.2, 0)
		var sway := {"name": "tendril", "joint": _v(base), "motion": "swing", "phase": float(i) * 1.4}
		_chain(a, [base, out_dir * 1.45 + Vector3(0, 1.15, 0), tip], 0.1, 0.07, "body", sway, false)
		a.append(_stick("crystal", tip, tip + (Vector3(0, 0.9, 0) - out_dir * 0.5).normalized() * 0.32, 0.06, 0.06, "accent", sway))
	var lobe_r := Vector3(0.78, 0.82, 0.74)
	a.append({"shape": "cap", "at": _v(_on(Vector3(0.5, 2.05, 0), lobe_r, Vector3(0.9, 0.3, 0.3), 1.0)), "aim": [0.6, 0.8, 0.2], "material": "accent", "radius": 0.2, "height": 0.07, "sides": 6})
	a.append({"shape": "cap", "at": _v(_on(Vector3(-0.5, 2.05, 0), lobe_r, Vector3(-0.8, 0.1, -0.5), 1.0)), "aim": [-0.5, 0.8, -0.3], "material": "accent", "radius": 0.17, "height": 0.06, "sides": 6})
	_mushroom(a, Vector3(0.3, 1.3, 0.5), Vector3(0.5, 0.6, 0.8), 0.22, 0.04, 0.16, 0.08, "body", "accent", {"motion": "crystal", "phase": 0.0})
	_mushroom(a, Vector3(-0.35, 1.1, -0.25), Vector3(-0.7, 0.5, -0.5), 0.2, 0.035, 0.14, 0.07, "body", "accent", {"motion": "crystal", "phase": 1.3})
	return {"style": "blob", "sway": 1.2, "tint": tint, "accent": accent, "anchor": 3.35, "warden": true, "shadow": 3.8, "ring": 1.9, "seed": "THE_HEARTROT_A", "parts": a}

## ---- Shapes -------------------------------------------------------------------------------

static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

static func _eye(at: Vector3, size: float, extra: Dictionary = {}) -> Dictionary:
	## A pentagonal gem: an eye, a spot on a cap, a drop of light.
	var eye := {"shape": "sphere", "at": _v(at), "scale": size, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2}
	eye.merge(extra, true)
	return eye

static func _gem(at: Vector3, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	## A cut gem: a six-sided, three-ringed sphere, the faceted stand-in for every ball.
	var gem := {"shape": "sphere", "at": _v(at), "scale": _v(size) if size is Vector3 else float(size), "material": material, "radius": 1.0, "segments": 6, "rings": 3}
	gem.merge(extra, true)
	return gem

static func _stone(at: Vector3, size: Variant, material: String, extra: Dictionary = {}, jitter: float = 0.08) -> Dictionary:
	## A cut stone: an icosahedron barely knocked about.
	var stone := {"shape": "rock", "at": _v(at), "scale": _v(size) if size is Vector3 else float(size), "material": material, "jitter": jitter}
	stone.merge(extra, true)
	return stone

static func _rock(at: Vector3, size: Vector3, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	## A rock cut from its own seed: a body, a head, a turret.
	return {"shape": "rock", "at": _v(at), "scale": _v(size), "material": material, "jitter": jitter, "seed": seed}.merged(extra, true)

static func _long_stone(from: Vector3, to: Vector3, r: float, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	## One cut stone laid from `from` to `to`: a thigh, a forearm, a knuckle.
	return {"shape": "rock", "at": _v((from + to) * 0.5), "rot": _rot(_aimed(to - from)), "scale": [r, from.distance_to(to) * 0.6 + r * 0.2, r * 0.92], "material": material, "jitter": jitter, "seed": seed}.merged(extra, true)

static func _stick(shape: String, a: Vector3, b: Vector3, r_a: float, r_b: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## A shape laid between two points: a hex drum r_a thick at `a` and r_b at `b`, a six-sided
	## cone r_a at `a` tapering to `b`, or a crystal, spike or column of radius r_a.
	var part := {"shape": shape, "from": _v(a), "to": _v(b), "material": material, "sides": 6}
	match shape:
		"cylinder":
			part.merge({"bottom": r_a, "top": r_b}, true)
		_:
			part.merge({"radius": r_a}, true)
	part.merge(extra, true)
	return part

static func _chain(out: Array, points: Array, r0: float, r1: float, material: String, extra: Dictionary = {}, pointed: bool = true) -> void:
	## Columns laid point to point, thinning from r0 to r1, a cut stone filling every bend; the
	## last one a crystal that comes to a point when `pointed`.
	var n: int = points.size() - 1
	for i in range(n):
		var ra: float = lerpf(r0, r1, float(i) / float(n))
		var rb: float = lerpf(r0, r1, float(i + 1) / float(n))
		if pointed and i == n - 1:
			out.append(_stick("crystal", points[i], points[i + 1], ra, ra, material, extra))
		else:
			out.append(_stick("column", points[i], points[i + 1], (ra + rb) * 0.5, rb, material, extra))
		if i > 0:
			out.append(_stone(points[i], ra * 1.05, material, extra))

static func _frame(axis: Vector3) -> Array:
	## The axis and two directions square to it.
	var f: Vector3 = axis.normalized()
	var s: Vector3 = (Vector3.UP.cross(f) if absf(f.y) < 0.9 else Vector3.RIGHT.cross(f)).normalized()
	return [f, s, f.cross(s).normalized()]

static func _hoop(out: Array, centre: Vector3, axis: Vector3, radius: float, thick: float, n: int, material: String, extra: Dictionary = {}, turn: float = 0.0) -> void:
	## A band of `n` boxes laid end to end round `axis`: the lowpoly stand-in for every torus
	## (a lip of a mouth, the gill ring under a cap, the wrap round a bundle, a shell's lip).
	var frame: Array = _frame(axis)
	var s: Vector3 = frame[1]
	var u: Vector3 = frame[2]
	var span: float = TAU * radius / float(n) * 1.12
	for i in range(n):
		var ang: float = turn + TAU * (float(i) + 0.5) / float(n)
		var radial: Vector3 = s * cos(ang) + u * sin(ang)
		var tangent: Vector3 = -s * sin(ang) + u * cos(ang)
		var part := {"shape": "box", "at": _v(centre + radial * radius), "aim": _v(tangent), "material": material, "size": [thick, span, thick]}
		part.merge(extra, true)
		out.append(part)

static func _mushroom(out: Array, base: Vector3, dir: Vector3, stem_h: float, stem_r: float, cap_r: float, cap_h: float, stem_mat: String, cap_mat: String, extra: Dictionary = {}, sides: int = 7) -> void:
	## A column of a stalk from `base` along `dir` with a seven-sided cap on top.
	var up: Vector3 = dir.normalized()
	var top: Vector3 = base + up * stem_h
	out.append(_stick("column", base, top, stem_r, stem_r, stem_mat, extra))
	var cap := {"shape": "cap", "at": _v(top - up * cap_h * 0.1), "aim": _v(up), "material": cap_mat, "radius": cap_r, "height": cap_h, "sides": sides}
	cap.merge(extra, true)
	out.append(cap)

static func _spore_cap(out: Array, base: Vector3, dir: Vector3, stem_h: float, stem_r: float, cap_r: float, extra: Dictionary = {}) -> void:
	## The Spore Mother's spore cap: a column stalk and a seven-sided cap half as tall as it is
	## wide, in the accent colour.
	var up: Vector3 = dir.normalized()
	var top: Vector3 = base + up * stem_h
	out.append(_stick("column", base, top, stem_r, stem_r, "body", extra.duplicate()))
	out.append({"shape": "cap", "at": _v(top - up * cap_r * 0.05), "aim": _v(up), "material": "accent", "radius": cap_r, "height": cap_r * 0.5, "sides": 7}.merged(extra, true))

static func _leg(out: Array, hip: Vector3, knee: Vector3, foot: Vector3, r_hip: float, r_knee: float, phase: float, material: String = "body") -> void:
	## A jointed leg swinging from its hip: a column to the knee, a cut stone at the knee, a
	## crystal from the knee to its point on the floor. Named `leg`, jointed at the hip.
	var extra := {"name": "leg", "joint": _v(hip), "motion": "swing", "phase": phase}
	out.append(_stick("column", hip, knee, r_hip, r_knee, material, extra))
	out.append(_stone(knee, r_hip * 1.1, material, extra))
	out.append(_stick("crystal", knee, foot, r_knee, r_knee, material, extra))

static func _spores(out: Array, specs: Array, motion: String = "bob") -> void:
	## Spores on the air: small shards of light drifting.
	for i in range(specs.size()):
		var spec: Array = specs[i]
		out.append({"shape": "shard", "at": _v(spec[0]), "rot": [20.0 * float(i % 3), 50.0 * float(i), 15.0 * float(i % 2)], "material": "accent", "size": float(spec[1]) * 1.1, "motion": motion, "phase": float(i) * 1.3})

static func _root_mat(out: Array, at: Vector3, size: Vector3, seed: int, roots: int, inner: float, outer: float, r: float = 0.07, turn: float = 0.0) -> void:
	## A flat mat of mycelium with roots running out over the floor.
	out.append({"shape": "rock", "at": _v(at), "scale": _v(size), "material": "body", "jitter": 0.3, "seed": seed})
	for i in range(roots):
		var ang: float = TAU * float(i) / float(roots) + turn
		var dir := Vector3(cos(ang), 0, sin(ang))
		var start := Vector3(at.x + dir.x * inner, at.y + 0.04, at.z + dir.z * inner)
		var end := Vector3(at.x + dir.x * outer, 0.02, at.z + dir.z * outer)
		out.append(_stick("cone", start, end, r, r, "body", {"sides": 5}))

static func _on(centre: Vector3, radii: Vector3, dir: Vector3, lift: float = 1.02) -> Vector3:
	## A point on (or just off) the surface of an ellipsoid, in the direction `dir`.
	return centre + dir.normalized() * radii * lift

static func _heart(out: Array, centre: Vector3, s: float, veins: int, tubes: int) -> void:
	## A gem heart: two six-sided gems for lobes, a crystal hanging to the point below, a
	## smaller gem blending them, arteries of thin columns laid over the lobes, a pentagonal gem
	## pulsing in the cleft and cut vessels of hex drum standing from the top.
	var lobe_r := Vector3(0.78, 0.82, 0.74) * s
	for side in [-1.0, 1.0]:
		out.append(_gem(centre + Vector3(side * 0.56 * s, 0.3 * s, 0), lobe_r, "core", {"motion": "core", "phase": 0.0 if side > 0.0 else 0.4}))
	out.append(_stick("crystal", centre + Vector3(0, 0.08 * s, 0.02 * s), centre + Vector3(0, -1.27 * s, 0.02 * s), 0.8 * s, 0.8 * s, "core", {"motion": "core", "phase": 0.8}))
	out.append(_gem(centre + Vector3(0, -0.08 * s, 0), Vector3(0.7, 0.48, 0.68) * s, "core", {"motion": "core", "phase": 0.6}))
	out.append(_eye(centre + Vector3(0, 0.4 * s, 0.62 * s), 0.26 * s, {"motion": "core", "phase": 1.2}))
	var paths: Array = [[1.0, [Vector3(0.1, 1, 0.3), Vector3(0.6, 0.6, 0.6), Vector3(0.95, 0.0, 0.5)]],
		[-1.0, [Vector3(-0.15, 1, 0.2), Vector3(-0.7, 0.5, 0.5), Vector3(-0.9, -0.1, 0.55)]],
		[1.0, [Vector3(0.0, 0.9, -0.5), Vector3(0.5, 0.5, -0.8), Vector3(0.7, -0.2, -0.75)]]]
	for p in range(mini(veins, paths.size())):
		var lobe: Vector3 = centre + Vector3(float(paths[p][0]) * 0.5 * s, 0.3 * s, 0)
		var dirs: Array = paths[p][1]
		for i in range(dirs.size() - 1):
			out.append(_stick("column", _on(lobe, lobe_r, dirs[i], 1.06), _on(lobe, lobe_r, dirs[i + 1], 1.06), 0.04 * s, 0.04 * s, "accent", {"sides": 4}))
	var vessels: Array = [[Vector3(0.05, 0.9, -0.1), Vector3(0.15, 1.38, -0.22), 0.2], [Vector3(-0.22, 0.95, 0.1), Vector3(-0.48, 1.28, 0.3), 0.15], [Vector3(0.28, 0.9, 0.2), Vector3(0.55, 1.18, 0.38), 0.12]]
	for t in range(mini(tubes, vessels.size())):
		var v: Array = vessels[t]
		var a: Vector3 = centre + v[0] * s
		var b: Vector3 = centre + v[1] * s
		var axis: Vector3 = (b - a).normalized()
		out.append(_stick("cylinder", a, b, float(v[2]) * s * 1.2, float(v[2]) * s, "body"))
		out.append(_stick("cylinder", b - axis * 0.02 * s, b + axis * 0.02 * s, float(v[2]) * s * 0.8, float(v[2]) * s * 0.8, "accent"))

## ---- The Spore Mother's toad parts --------------------------------------------------------

static func _aimed(direction: Vector3) -> Basis:
	## The bake's own rule: upright turned the shortest way round until Y runs along `direction`.
	var up: Vector3 = direction.normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() < 0.0001:
		return Basis() if up.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(up))

static func _rot(basis: Basis) -> Array:
	## A basis as the recipe's "rot" (degrees).
	var e: Vector3 = basis.orthonormalized().get_euler()
	return [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

static func _look(forward: Vector3) -> Basis:
	## A frame whose +z runs along `forward` and whose +y stays as near up as it can.
	var f: Vector3 = forward.normalized()
	var r: Vector3 = Vector3.UP.cross(f).normalized()
	return Basis(r, f.cross(r), f)

static func _toad_eye(out: Array, at: Vector3, s: float, look: Vector3) -> void:
	## A great gem eye on a stone turret, a slit pupil of dark iron across it, a brow over it.
	var f: Vector3 = look.normalized()
	out.append(_rock(at - Vector3(0, s * 0.5, 0) - f * s * 0.3, Vector3(s * 1.4, s * 1.1, s * 1.4), "body", 0.1, 781))
	out.append(_gem(at, s, "accent", {"motion": "static"}))
	out.append({"shape": "box", "at": _v(at + f * s * 0.9), "rot": _rot(_look(f)), "material": "iron", "size": [s * 0.28, s * 1.1, s * 0.2]})
	out.append({"shape": "slab", "at": _v(at + Vector3(0, s * 0.85, -s * 0.1)), "rot": _rot(_look(f) * Basis(Vector3.RIGHT, -0.3)), "material": "body", "size": [s * 1.8, s * 0.35, s * 1.3], "jitter": 0.05})

static func _toad_leg(out: Array, hip: Vector3, knee: Vector3, ankle: Vector3, toes_at: Vector3, thick: float, seed: int) -> void:
	## A folded hind leg: a heavy thigh forward to the knee, the shin back down to the ankle, the
	## long foot forward again, crystal toes fanned at its end.
	out.append(_long_stone(hip, knee, thick, "body", 0.1, seed))
	out.append(_long_stone(knee, ankle, thick * 0.66, "body", 0.1, seed + 1))
	out.append(_long_stone(ankle, toes_at, thick * 0.4, "body", 0.1, seed + 2))
	_toes(out, toes_at, toes_at - ankle, 4, thick * 1.0)

static func _toes(out: Array, at: Vector3, forward: Vector3, count: int, length: float) -> void:
	## Crystal toes fanned out along the floor from `at`, the way `forward` points.
	var f: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
	var side: Vector3 = Vector3.UP.cross(f).normalized()
	for i in range(count):
		var spread: float = (float(i) - float(count - 1) * 0.5) * 0.5
		var d: Vector3 = (f + side * spread).normalized()
		out.append(_stick("crystal", at + Vector3(0, 0.03, 0), at + d * length + Vector3(0, 0.0, 0), length * 0.2, length * 0.2, "core"))

static func _slime(out: Array, at: Vector3, s: float, phase: float) -> void:
	## One of the brood: a cut gem of a slime with two lit eyes, bobbing, named `brood` and
	## jointed where it sits on the floor.
	var bob := {"name": "brood", "joint": _v(at), "motion": "bob", "phase": phase}
	out.append(_gem(at + Vector3(0, s * 0.65, 0), Vector3(s, s * 0.75, s), "core", bob.duplicate()))
	out.append(_eye(at + Vector3(s * 0.35, s * 0.85, s * 0.82), s * 0.18, bob.duplicate()))
	out.append(_eye(at + Vector3(-s * 0.35, s * 0.85, s * 0.82), s * 0.18, bob.duplicate()))

## ---- Naming the parts an animation moves --------------------------------------------------

static func _tag(out: Array, start: int, extra: Dictionary) -> void:
	## Gives every part laid since `start` the same fields: the name and joint of the one piece
	## they move as (a head, a leg, the heart).
	for i in range(start, out.size()):
		(out[i] as Dictionary).merge(extra, true)

static func _segments(out: Array, start: int, name: String) -> void:
	## Names every part laid since `start` as one chain that bends at each link: a column is
	## jointed at its own base (`from`), a knuckle stone at its own centre (the base of the
	## column laid just before it), so an animation can curl or uncurl it a segment at a time.
	for i in range(start, out.size()):
		var part: Dictionary = out[i]
		var base: Array = part["from"] if part.has("from") else part["at"]
		part["name"] = name
		part["joint"] = base.duplicate()

static func _mouth(at: Vector3, extra: Dictionary = {}) -> Dictionary:
	## A gem too small to see where a bite lands or spores leave: the `mouth` an animation throws
	## its effect from. Laid last, it draws no random numbers.
	return {"shape": "sphere", "at": _v(at), "scale": 0.02, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2, "name": "mouth"}.merged(extra, true)
