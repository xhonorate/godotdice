extends RefCounted
## Recipes for tools/creature_bake.gd: the Seeps, the flooded workings. See tools/creature_bake.gd
## for the format.
##
## Built to the owner's look (Oct 28): low poly and angular, made of crystals and gems. Long
## bodies are rows of cut stones or slabs stepping along a curve with a crystal for the tail;
## necks and limbs are columns; hoops and coils are bands of boxes or 8-segment rings; eyes,
## lamps and spots are pentagonal gems. Every creature here but the Cave Crayfish was picked in
## the model review (build/options/recipes/seeps.gd) and names its review key as its "seed", so
## it bakes facet for facet as it was picked. Parts an animation moves carry a "name" (head, jaw,
## mouth, tail, wheel, gate, ...): build/options/part_roles/seeps.md says how each one moves.

static func recipes() -> Dictionary:
	return {
		"SEEP_EEL": _seep_eel(),
		"DROWNED_MINER": _drowned_miner(),
		"LAMPREY_KNOT": _lamprey_knot(),
		"CAVE_CRAYFISH": _cave_crayfish(),
		"THE_LOCKKEEPER": _lockkeeper(),
		"THE_DROWNED_CHOIR": _drowned_choir(),
		"THE_UNDERTOW": _undertow()}

static func _seep_eel() -> Dictionary:
	## A lightning eel coming at the party in a rising S: a slab body banded with lit hex collars
	## like a stack of cells, a row of crystal spines down the back, two horns with an arc between.
	var c: Array = []
	var pc: Array = [Vector3(-1.25, 0.1, -0.3), Vector3(-0.75, 0.22, 0.1), Vector3(-0.3, 0.36, -0.25), Vector3(0.15, 0.46, 0.15),
		Vector3(0.55, 0.55, -0.15), Vector3(0.85, 0.75, 0.25), Vector3(1.0, 0.95, 0.55), Vector3(1.08, 1.02, 0.7)]
	var rc: Array = [0.04, 0.1, 0.15, 0.18, 0.2, 0.2, 0.2, 0.19]
	_chain(c, pc, rc, "body", "core", true, 0.0, _runs(6), "slab")
	_spots(c, pc, rc, 0.05, 2)
	for i in [1, 3, 5]:
		## Lit hex collars round the body, a stack of cells.
		var seg: Vector3 = pc[i + 1] - pc[i - 1]
		c.append({"shape": "cylinder", "at": _v(pc[i]), "aim": _v(seg), "material": "accent", "motion": "core", "phase": float(i) * 0.55, "top": float(rc[i]) * 1.14, "bottom": float(rc[i]) * 1.14, "height": 0.08, "sides": 6, "name": "collar"})
	var hc := Vector3(1.12, 1.0, 0.92)
	var neck: Vector3 = pc[7]
	var mouth: Vector3 = _jaws(c, hc, Vector3(0.25, -0.1, 1.0), neck, 0.52, 3, 1.0, 1.0, false)
	for i in range(1, 7):
		var seg: Vector3 = pc[i + 1] - pc[i - 1]
		var up: Vector3 = _up(seg)
		var base: Vector3 = pc[i] + up * float(rc[i]) * 0.8
		c.append({"shape": "crystal", "from": _v(base), "to": _v(base + up * (0.2 + 0.07 * float(i % 3)) - seg.normalized() * 0.08), "material": "accent", "motion": "flicker", "phase": float(i) * 0.7, "radius": 0.04, "name": "spine"})
	for side in [-1.0, 1.0]:
		## The horns ride with the head; the arc crackles between their tips; a fin each side of the neck.
		var horn_base: Vector3 = hc + Vector3(side * 0.12, 0.2, -0.08)
		var horn_tip: Vector3 = hc + Vector3(side * 0.32, 0.52, -0.22)
		c.append({"shape": "crystal", "from": _v(horn_base), "to": _v(horn_tip), "material": "accent", "motion": "bob", "phase": 1.0, "radius": 0.045, "name": "horn", "joint": _v(neck)})
		c.append({"shape": "cylinder", "from": _v(horn_tip), "to": _v(hc + Vector3(0, 0.64, -0.26)), "material": "accent", "motion": "flicker", "phase": 2.0 + side, "top": 0.014, "bottom": 0.02, "sides": 3, "name": "arc"})
		c.append({"shape": "prism", "at": _v(hc + Vector3(side * 0.28, -0.14, -0.16)), "rot": [0, side * 40.0, side * -55.0], "material": "body", "motion": "swing", "phase": 1.0 + side, "joint": _v(hc + Vector3(side * 0.14, -0.12, -0.16)), "size": [0.34, 0.16, 0.03], "name": "fin_l" if side > 0.0 else "fin_r"})
	_ripple(c, pc[0], 0.26, 0.0, "accent")
	_ripple(c, pc[2], 0.3, 1.0)
	_ripple(c, pc[4], 0.34, 2.0)
	c.append(_mouth(mouth, {"joint": _v(neck), "motion": "bob", "phase": 1.0}))
	return {"style": "long", "sway": 1.4, "tint": "2f7f86", "accent": "7affe0", "anchor": 1.9, "shadow": 3.0, "ring": 1.4, "seed": "SEEP_EEL_C", "parts": c}

static func _drowned_miner() -> Dictionary:
	## A heap of drowned gear held together by seep-water: a dark mass over a pale puddle, a cart
	## wheel half sunk and turning, rope wound round, the hard hat on top with its lamp lit, a
	## water tendril holding the pick up, a lantern on the side.
	## The tendril and the pick it holds are one arm, swung from where the tendril leaves the mass.
	var shoulder: Array = [-0.35, 0.65, 0.2]
	var b: Array = [
		{"shape": "rock", "at": [0, 0.08, 0], "scale": [0.95, 0.1, 0.8], "material": "core", "motion": "core", "jitter": 0.3, "seed": 62},
		{"shape": "rock", "at": [0, 0.5, 0], "scale": [0.6, 0.52, 0.5], "material": "body", "motion": "core", "phase": 0.6, "jitter": 0.22, "seed": 63, "name": "body"},
		_stone(Vector3(0.05, 0.88, 0.1), 0.24, "core", 0.12, {"motion": "flicker", "name": "heart"}),
		{"shape": "box", "at": [0.6, 0.45, -0.12], "aim": [1, 0, 0.25], "material": "iron", "motion": "spin", "phase": 0.0, "size": [0.72, 0.05, 0.06], "name": "wheel"},
		{"shape": "box", "at": [0.6, 0.45, -0.12], "aim": [1, 0, 0.25], "material": "iron", "motion": "spin", "phase": 0.0, "mesh_rot": [0, 90, 0], "size": [0.72, 0.05, 0.06], "name": "wheel"},
		{"shape": "cylinder", "from": [0.51, 0.45, -0.1425], "to": [0.69, 0.45, -0.0975], "material": "iron", "top": 0.08, "bottom": 0.08, "sides": 6, "name": "wheel"},
		{"shape": "slab", "at": [0.3, 0.1, 0.5], "rot": [0, 25, 0], "material": "iron", "size": [0.18, 0.16, 0.34], "jitter": 0.02},
		{"shape": "slab", "at": [-0.22, 0.1, 0.55], "rot": [0, -20, 0], "material": "iron", "size": [0.18, 0.16, 0.34], "jitter": 0.02},
		{"shape": "column", "from": [-0.35, 0.65, 0.2], "to": [-0.72, 1.1, 0.3], "material": "core", "radius": 0.07, "sides": 5, "name": "arm_r", "joint": shoulder},
		_stone(Vector3(-0.72, 1.1, 0.3), 0.08, "core", 0.12, {"name": "arm_r", "joint": shoulder}),
		{"shape": "crystal", "from": [0.32, 0.66, 0.3], "to": [0.46, 0.92, 0.42], "material": "accent", "motion": "crystal", "radius": 0.04},
		{"shape": "crystal", "from": [-0.2, 0.72, -0.3], "to": [-0.3, 1.0, -0.42], "material": "accent", "motion": "crystal", "phase": 1.2, "radius": 0.035}]
	_disc(b, Vector3(0.6, 0.45, -0.12), Vector3(1, 0, 0.25), 0.42, 0.1, "iron", {"motion": "spin", "phase": 0.0, "name": "wheel"})
	_band(b, Vector3(0, 0.34, 0), Vector3(0.1, 1, 0.2), 0.55, 0.1, 8, "body")
	_band(b, Vector3(0.02, 0.6, 0.02), Vector3(-0.3, 1, 0.15), 0.46, 0.08, 8, "body")
	_helmet(b, Vector3(0.05, 1.04, 0.12), "bob", 0.2)
	_pick(b, Vector3(-0.78, 0.7, 0.3), Vector3(-0.66, 1.6, 0.3), {"name": "pick", "joint": shoulder})
	_weed(b, Vector3(0.3, 1.06, 0.3), Vector3(0.44, 0.7, 0.42), 0.4)
	_weed(b, Vector3(-0.25, 1.06, -0.1), Vector3(-0.38, 0.68, -0.2), 1.5)
	_weed(b, Vector3(0.0, 0.85, -0.38), Vector3(0.1, 0.5, -0.56), 2.4)
	for spout in [[Vector3(-0.2, 0.9, 0.2), 0.0], [Vector3(0.3, 0.95, -0.15), 1.2], [Vector3(-0.1, 0.8, -0.3), 2.3]]:
		b.append({"shape": "cone", "from": _v(spout[0]), "to": _v(spout[0] + Vector3(0, 0.32, 0)), "material": "core", "motion": "flicker", "phase": spout[1], "radius": 0.06, "sides": 5})
	for bubble in [[Vector3(0.55, 0.9, 0.3), 0.0], [Vector3(-0.5, 1.3, 0.2), 2.0], [Vector3(0.2, 1.55, -0.3), 4.0]]:
		b.append(_gem(bubble[0], 0.04, "accent", {"motion": "orbit", "phase": bubble[1]}))
	for lamp in [
		{"shape": "cylinder", "from": [0.62, 0.75, 0.3], "to": [0.66, 0.6, 0.34], "material": "iron", "top": 0.02, "bottom": 0.02, "sides": 4},
		{"shape": "cone", "at": [0.66, 0.56, 0.34], "material": "iron", "radius": 0.12, "height": 0.1, "sides": 6},
		{"shape": "cylinder", "at": [0.66, 0.43, 0.34], "material": "accent", "top": 0.08, "bottom": 0.08, "height": 0.18, "sides": 6},
		{"shape": "cylinder", "at": [0.66, 0.32, 0.34], "material": "iron", "top": 0.11, "bottom": 0.11, "height": 0.05, "sides": 6}]:
		lamp.merge({"joint": [0.62, 0.75, 0.3], "motion": "swing", "phase": 1.4, "name": "lantern"})
		b.append(lamp)
	return {"style": "low", "sway": 1.1, "tint": "4c6e72", "accent": "ffe08a", "anchor": 1.9, "shadow": 2.4, "ring": 1.2, "seed": "DROWNED_MINER_B", "parts": b}

static func _lamprey_knot() -> Dictionary:
	## The knot stood up: the three bodies braid round each other into a column, heads fanned out
	## at the top like a flower of open mouths, tails splayed on the floor.
	var b: Array = []
	for i in range(3):
		var start: float = TAU * float(i) / 3.0
		var pts: Array = []
		for k in range(4):
			var t: float = float(k) / 3.0
			var ang: float = start + t * 4.4
			pts.append(Vector3(cos(ang) * 0.15, 0.1 + t * 0.62, sin(ang) * 0.15))
		var tail_dir := Vector3(cos(start), 0, sin(start))
		pts.insert(0, tail_dir * 0.52 + Vector3(0, 0.04, 0))
		var top_ang: float = start + 4.4
		var out := Vector3(cos(top_ang), 0, sin(top_ang))
		var neck: Vector3 = Vector3(0, 0.74, 0) + out * 0.28 + Vector3(0, 0.12, 0)
		pts.append(neck)
		_chain(b, pts, [0.03, 0.06, 0.085, 0.1, 0.11, 0.11], "body", "core", true, float(i) * 1.1, _runs(4), "column", 5)
		_lamprey_head(b, neck, (out * 0.8 + Vector3(0, 0.45, 0)).normalized(), 1.0, float(i) * 0.9)
	return {"style": "blob", "sway": 2.4, "tint": "b08a94", "accent": "ff7a8a", "anchor": 1.35, "shadow": 1.8, "ring": 0.9, "seed": "LAMPREY_KNOT_B", "parts": b}

static func _cave_crayfish() -> Dictionary:
	## A blue crayfish low on the floor: a shell of two stones, a fan tail, two slab claws, long
	## feelers and three thin legs a side. (Today's model, not from the review.)
	var crayfish: Array = [
		{"shape": "rock", "at": [0, 0.32, -0.1], "scale": [0.5, 0.26, 0.7], "material": "body", "motion": "core", "jitter": 0.14, "seed": 11},
		{"shape": "rock", "at": [0, 0.3, -0.75], "scale": [0.36, 0.18, 0.4], "material": "body", "motion": "swing", "jitter": 0.14, "seed": 12},
		{"shape": "prism", "at": [0, 0.3, -1.15], "rot": [90, 0, 0], "material": "body", "motion": "swing", "phase": 0.6, "size": [0.6, 0.4, 0.05]},
		{"shape": "slab", "at": [0.5, 0.3, 0.6], "rot": [0, -20, 0], "material": "body", "motion": "swing", "phase": 1.0, "size": [0.32, 0.22, 0.55], "jitter": 0.06},
		{"shape": "slab", "at": [-0.5, 0.3, 0.6], "rot": [0, 20, 0], "material": "body", "motion": "swing", "phase": 2.0, "size": [0.32, 0.22, 0.55], "jitter": 0.06},
		{"shape": "cone", "at": [0.55, 0.3, 0.98], "rot": [90, 0, 0], "scale": [0.1, 0.3, 0.08], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4},
		{"shape": "cone", "at": [-0.55, 0.3, 0.98], "rot": [90, 0, 0], "scale": [0.1, 0.3, 0.08], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4},
		{"shape": "cylinder", "at": [0.12, 0.42, 0.55], "rot": [-50, 0, 15], "material": "accent", "motion": "swing", "phase": 0.2, "top": 0.015, "bottom": 0.02, "height": 0.9, "sides": 4},
		{"shape": "cylinder", "at": [-0.12, 0.42, 0.55], "rot": [-50, 0, -15], "material": "accent", "motion": "swing", "phase": 1.7, "top": 0.015, "bottom": 0.02, "height": 0.9, "sides": 4},
		{"shape": "sphere", "at": [0.14, 0.46, 0.5], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.14, 0.46, 0.5], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3}]
	for side in [-1.0, 1.0]:
		for leg in range(3):
			crayfish.append({"shape": "cylinder", "at": [side * 0.5, 0.14, 0.25 - float(leg) * 0.3], "rot": [0, 0, side * 55.0], "material": "body", "top": 0.03, "bottom": 0.03, "height": 0.4, "sides": 4})
	return {"style": "low", "sway": 1.8, "tint": "3a6a8a", "accent": "bfefff", "anchor": 1.0, "shadow": 2.4, "parts": crayfish}

static func _lockkeeper() -> Dictionary:
	## A great sluice-snail: a long flat foot with a head, eyestalks and feelers at the front, the
	## shell three cut stones hooped in iron bands with crystals grown on it, its gate at the
	## opening and the valve wheel on top, water spilling from the gate.
	var neck: Array = [0, 0.5, 0.95]
	## The gate hangs from its top edge: its centre [0, 1.05, 0.42] plus half its height up its
	## face, tilted back 32 degrees. Its two iron bands and lit window lie on its face (the picked
	## model had them standing 0.18 off it).
	var hinge: Array = [0, 1.45, 0.17]
	var c: Array = [
		_stone(Vector3(0, 0.36, -0.35), Vector3(0.62, 0.36, 0.92), "body", 0.08, {"motion": "core", "name": "body"}),
		_stone(Vector3(0, 0.38, 0.6), Vector3(0.56, 0.36, 0.56), "body", 0.08, {"motion": "core", "phase": 0.4, "name": "body"}),
		_stone(Vector3(0, 0.52, 1.28), Vector3(0.4, 0.34, 0.42), "body", 0.1, {"motion": "bob", "phase": 0.3, "name": "head", "joint": neck}),
		{"shape": "ring", "at": [0, 0.42, 1.66], "aim": [0, -0.3, 1], "material": "iron", "motion": "bob", "phase": 0.3, "radius": 0.15, "width": 0.08, "segments": 6, "name": "head", "joint": neck},
		_stone(Vector3(0, 1.68, -0.42), Vector3(1.05, 1.0, 0.86), "body", 0.08, {"motion": "block", "name": "shell"}),
		_stone(Vector3(0.0, 2.1, -1.0), Vector3(0.62, 0.6, 0.55), "body", 0.08, {"motion": "block", "name": "shell"}),
		_stone(Vector3(0.0, 2.38, -1.38), 0.36, "body", 0.1, {"motion": "block", "name": "shell"}),
		{"shape": "slab", "at": [0, 1.05, 0.42], "rot": [-32, 0, 0], "material": "body", "size": [1.15, 0.95, 0.14], "jitter": 0.03, "name": "gate", "joint": hinge},
		{"shape": "box", "at": [0, 1.2, 0.461], "rot": [-32, 0, 0], "material": "iron", "size": [1.25, 0.12, 0.1], "name": "gate", "joint": hinge},
		{"shape": "box", "at": [0, 0.759, 0.737], "rot": [-32, 0, 0], "material": "iron", "size": [1.25, 0.12, 0.1], "name": "gate", "joint": hinge},
		{"shape": "box", "at": [0, 0.987, 0.572], "rot": [-32, 0, 0], "material": "core", "size": [0.5, 0.3, 0.06], "name": "gate", "joint": hinge},
		{"shape": "crystal", "from": [0.3, 2.5, -0.5], "to": [0.42, 2.92, -0.62], "material": "accent", "motion": "crystal", "radius": 0.09, "name": "shell"},
		{"shape": "crystal", "from": [-0.48, 2.4, -0.3], "to": [-0.66, 2.78, -0.26], "material": "accent", "motion": "crystal", "phase": 1.0, "radius": 0.08, "name": "shell"},
		{"shape": "crystal", "from": [0.12, 2.6, -1.0], "to": [0.18, 2.98, -1.14], "material": "accent", "motion": "crystal", "phase": 2.0, "radius": 0.07, "name": "shell"}]
	_band(c, Vector3(0, 1.68, -0.42), Vector3(0, 0, 1), 1.08, 0.12, 8, "iron", {"name": "shell"})
	_band(c, Vector3(0, 1.68, -0.42), Vector3(0.42, 0.1, 1), 1.06, 0.12, 8, "iron", {"name": "shell"})
	_band(c, Vector3(0, 1.68, -0.42), Vector3(0, 1, 0), 1.1, 0.12, 8, "iron", {"name": "shell"})
	for side in [-1.0, 1.0]:
		var stalk: Array = [side * 0.2, 0.74, 1.36]
		var feeler: Array = [side * 0.3, 0.44, 1.6]
		c.append({"shape": "cylinder", "from": [side * 0.2, 0.74, 1.36], "to": [side * 0.42, 1.32, 1.5], "material": "body", "motion": "bob", "phase": 0.5 + side, "top": 0.045, "bottom": 0.06, "sides": 5, "name": "stalk", "joint": stalk})
		c.append(_gem(Vector3(side * 0.44, 1.38, 1.52), 0.12, "accent", {"motion": "bob", "phase": 0.5 + side, "name": "stalk", "joint": stalk}))
		c.append({"shape": "cylinder", "from": [side * 0.3, 0.44, 1.6], "to": [side * 0.68, 0.34, 1.9], "material": "body", "motion": "bob", "phase": 0.3, "top": 0.02, "bottom": 0.035, "sides": 4, "name": "feeler", "joint": feeler})
		c.append({"shape": "cone", "from": [side * 0.5, 0.78, 0.72], "to": [side * 1.15, 0.1, 1.0], "material": "core", "motion": "flicker", "phase": 1.0 + side, "radius": 0.1, "sides": 5, "name": "spill"})
		_band(c, Vector3(side * 1.12, 1.3, -0.4), Vector3(1, 0, 0), 0.1, 0.05, 6, "iron", {"name": "shell"})
		_weed(c, Vector3(side * 0.95, 1.1, 0.1), Vector3(side * 1.1, 0.7, 0.25), 1.0 + side)
	_wheel(c, Vector3(0, 2.72, -0.1), Vector3(0, 0.75, 1), 0.5)
	_ripple(c, Vector3(0, 0, 0.3), 1.5, 0.0)
	return {"style": "tower", "sway": 0.6, "tint": "3a7a80", "accent": "ffd06a", "anchor": 3.5, "warden": true, "shadow": 3.8, "ring": 1.8, "seed": "THE_LOCKKEEPER_C", "parts": c}

static func _drowned_choir() -> Dictionary:
	## No mound: the heads rise straight out of a dark pool on long tangled necks like reeds, two
	## young heads lower among them, rope round a neck, a drowned lamp post with its lantern lit.
	var first := Vector3(-0.6, 0.02, 0.3)
	var tallest := Vector3(0.05, 0.02, -0.25)
	var b: Array = [
		{"shape": "cylinder", "at": [0, 0.04, 0], "material": "body", "motion": "core", "top": 1.35, "bottom": 1.35, "height": 0.07, "sides": 6},
		{"shape": "ring", "at": [0, 0.09, 0], "material": "core", "motion": "core", "phase": 1.0, "radius": 1.0, "width": 0.12, "segments": 8},
		{"shape": "cylinder", "from": [0.45, 0.0, -0.65], "to": [0.35, 2.5, -0.75], "material": "iron", "top": 0.06, "bottom": 0.08, "sides": 6},
		{"shape": "box", "at": [0.6, 2.46, -0.75], "material": "iron", "size": [0.55, 0.08, 0.08]},
		{"shape": "crystal", "from": [0.9, 0.05, 0.6], "to": [1.05, 0.5, 0.72], "material": "accent", "motion": "crystal", "radius": 0.07},
		{"shape": "crystal", "from": [-0.95, 0.05, -0.5], "to": [-1.12, 0.42, -0.6], "material": "accent", "motion": "crystal", "phase": 1.2, "radius": 0.06}]
	## The rope is wound round the first neck, so it sways with that neck.
	_band(b, Vector3(-0.78, 1.1, 0.45), Vector3(-0.2, 1, 0.1), 0.2, 0.08, 6, "body", {"name": "rope", "joint": _v(first), "motion": "swing", "phase": 0.0})
	_lantern(b, Vector3(0.84, 2.42, -0.75), 0.8)
	_singer(b, first, [Vector3(-0.75, 0.9, 0.45), Vector3(-1.0, 1.8, 0.5)], Vector3(-0.95, 2.65, 0.5), Vector3(-0.4, 0.55, 0.75), 1.0, 0.0)
	_singer(b, tallest, [Vector3(0.2, 1.1, -0.35), Vector3(0.05, 2.3, -0.3)], Vector3(0.12, 3.3, -0.2), Vector3(0.0, 0.6, 0.8), 1.0, 1.4)
	_singer(b, Vector3(0.7, 0.02, 0.2), [Vector3(0.95, 1.0, 0.25), Vector3(1.1, 1.9, 0.3)], Vector3(0.95, 2.8, 0.4), Vector3(0.45, 0.5, 0.75), 1.0, 2.6)
	_singer(b, Vector3(-0.3, 0.02, 0.85), [Vector3(-0.4, 0.9, 0.9)], Vector3(-0.35, 1.65, 0.95), Vector3(-0.2, 0.5, 0.85), 0.55, 3.5, false, 0.16)
	_singer(b, Vector3(0.45, 0.02, 0.8), [Vector3(0.55, 0.7, 0.9)], Vector3(0.5, 1.35, 0.95), Vector3(0.3, 0.5, 0.8), 0.5, 4.6, false, 0.16)
	## The weed is caught on the tallest head, so it sways with that neck.
	_weed(b, Vector3(0.25, 3.15, -0.45), Vector3(0.45, 2.5, -0.7), 1.3, {"joint": _v(tallest), "phase": 1.4})
	_ripple(b, Vector3(0, 0, 0), 1.65, 0.0, "accent")
	return {"style": "tower", "sway": 0.7, "tint": "5fa8a0", "accent": "d8fff4", "anchor": 3.75, "warden": true, "shadow": 3.4, "ring": 1.6, "seed": "THE_DROWNED_CHOIR_B", "parts": b}

static func _undertow() -> Dictionary:
	## Rearing: a serpent of cut boulders lying in one great coil on the water, the front half
	## standing up out of it, the head high over the party with jaws open and crests swept back,
	## the tail fluke out front.
	var b: Array = []
	var pb: Array = [Vector3(1.35, 0.1, 0.9)]
	for k in range(7):
		var t: float = float(k) / 6.0
		var ang: float = 0.3 - t * 5.2
		pb.append(Vector3(cos(ang) * 0.85, 0.3 + 0.12 * t, sin(ang) * 0.85 - 0.1))
	pb.append_array([Vector3(0.55, 0.9, -0.5), Vector3(0.4, 1.6, -0.55), Vector3(0.1, 2.3, -0.35), Vector3(-0.1, 2.85, 0.05)])
	var rb: Array = [0.06, 0.2, 0.3, 0.36, 0.4, 0.42, 0.42, 0.42, 0.4, 0.38, 0.36, 0.34]
	_chain(b, pb, rb, "body", "core", true, 0.0, _runs(7, 3), "rock")
	var neck: Vector3 = pb[11]
	var mouth: Vector3 = _jaws(b, Vector3(-0.1, 3.15, 0.45), Vector3(0, -0.55, 0.85), neck, 1.0, 4, 1.0)
	_fins(b, pb, rb, 7, 11, 0.4)
	for i in [2, 4, 6]:
		var seg: Vector3 = pb[i + 1] - pb[i - 1]
		var base: Vector3 = pb[i] + Vector3(0, float(rb[i]) * 0.85, 0)
		b.append({"shape": "crystal", "from": _v(base), "to": _v(base + Vector3(0, 0.32, 0) - seg.normalized() * 0.1), "material": "accent", "motion": "crystal", "phase": float(i), "radius": 0.08, "name": "spine"})
	_spots(b, pb, rb, 0.09, 2)
	for side in [-1.0, 1.0]:
		b.append({"shape": "prism", "at": [0.4 + side * 0.55, 1.55, -0.55], "rot": [0, side * -35.0, side * -55.0], "material": "body", "motion": "swing", "phase": 1.0 + side, "joint": [0.4 + side * 0.28, 1.6, -0.55], "size": [0.65, 0.3, 0.04], "name": "fin_l" if side > 0.0 else "fin_r"})
	## The tail fluke breaking the water out front, beyond the tip.
	b.append({"shape": "prism", "at": [1.5, 0.3, 1.05], "rot": [0, -40, 0], "material": "body", "motion": "swing", "phase": 2.0, "joint": [1.5, 0.0, 1.05], "size": [0.45, 0.55, 0.05], "name": "tail"})
	_ripple(b, Vector3(0, 0, -0.1), 1.3, 0.0)
	_ripple(b, Vector3(1.4, 0, 1.0), 0.45, 1.5)
	b.append(_mouth(mouth, {"joint": _v(neck), "motion": "bob", "phase": 1.0}))
	return {"style": "long", "sway": 0.6, "tint": "1f5f66", "accent": "7affe0", "anchor": 4.1, "warden": true, "shadow": 3.6, "ring": 1.8, "seed": "THE_UNDERTOW_B", "parts": b}

static func _v(point: Vector3) -> Array:
	## A point as the [x, y, z] a recipe takes.
	return [point.x, point.y, point.z]

static func _face(f: Vector3) -> Array:
	## Euler degrees that turn a shape's +z toward `f` (and its +y up), roll free.
	var d: Vector3 = f.normalized()
	return [rad_to_deg(-asin(clampf(d.y, -1.0, 1.0))), rad_to_deg(atan2(d.x, d.z)), 0.0]

static func _along(d: Vector3) -> Array:
	## Euler degrees that lay a prism's, slab's or rock's long +x axis along `d`, its +y the up-normal.
	var n: Vector3 = d.normalized()
	return [0.0, rad_to_deg(atan2(-n.z, n.x)), rad_to_deg(asin(clampf(n.y, -1.0, 1.0)))]

static func _side(f: Vector3) -> Vector3:
	## The level axis square across `f` (x when `f` runs straight up or down).
	var s: Vector3 = Vector3.UP.cross(f.normalized())
	return s.normalized() if s.length() > 0.001 else Vector3.RIGHT

static func _up(f: Vector3) -> Vector3:
	## The up-normal of a run along `f`: square to it and to its side.
	return f.normalized().cross(_side(f)).normalized()

static func _gem(at: Vector3, size: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	## A pentagonal gem: an eye, a lamp, a lit spot.
	var part: Dictionary = {"shape": "sphere", "at": _v(at), "scale": size, "material": material, "radius": 1.0, "segments": 5, "rings": 2}
	part.merge(extra)
	return part

static func _stone(at: Vector3, size: Variant, material: String = "body", jitter: float = 0.1, extra: Dictionary = {}) -> Dictionary:
	## A cut stone: an icosahedron barely knocked about.
	var part: Dictionary = {"shape": "rock", "at": _v(at), "scale": _v(size) if size is Vector3 else size, "material": material, "jitter": jitter}
	part.merge(extra)
	return part

static func _mouth(at: Vector3, extra: Dictionary = {}) -> Dictionary:
	## A tiny quiet marker where a bite lands or a breath leaves; it draws no random numbers.
	var part: Dictionary = {"shape": "sphere", "at": _v(at), "scale": 0.02, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2, "name": "mouth"}
	part.merge(extra)
	return part

static func _runs(body: int, neck: int = 0) -> Array:
	## Names for a chain's runs, tail first: the tail crystal, `body` runs, then `neck` runs.
	var out: Array = ["tail"]
	for _i in range(body):
		out.append("body")
	for _i in range(neck):
		out.append("neck")
	return out

static func _chain(parts: Array, points: Array, radii: Array, material: String, motion: String, tail: bool = true, phase0: float = 0.0, names: Array = [], kind: String = "column", sides: int = 6) -> void:
	## A body laid along `points`, thinning along `radii`, from faceted pieces. `column` runs a
	## column (of `sides`) from point to point, `slab` lays a jittered slab on each run, `rock`
	## steps cut stones along it; every interior point gets a cut stone to fill the bend. The
	## first run is a crystal when `tail`, so the tail comes to a faceted point. `names[i]` names
	## the pieces of run i (the run from points[i] to points[i + 1]).
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg: Vector3 = b - a
		var r: float = (float(radii[i]) + float(radii[i + 1])) * 0.5
		var phase: float = phase0 + float(i) * 0.55
		var run: Array = []
		if i == 0 and tail:
			run.append({"shape": "crystal", "from": _v(b), "to": _v(a), "material": material, "radius": float(radii[1]) * 0.95, "sides": sides})
		elif kind == "slab":
			run.append({"shape": "slab", "at": _v((a + b) * 0.5), "rot": _along(seg), "material": material, "size": [seg.length() * 1.04, r * 1.8, r * 2.0], "jitter": r * 0.12})
		elif kind == "rock":
			var n: int = maxi(1, int(round(seg.length() / (r * 1.5))) - 1)
			for j in range(n):
				var t: float = float(j + 1) / float(n + 1)
				var rr: float = lerpf(float(radii[i]), float(radii[i + 1]), t)
				run.append({"shape": "rock", "at": _v(a + seg * t), "rot": _along(seg), "scale": [rr * 1.15, rr, rr], "material": material, "jitter": 0.1})
		else:
			run.append({"shape": "column", "from": _v(a), "to": _v(b), "material": material, "radius": r, "sides": sides})
		if i > 0:
			run.append({"shape": "rock", "at": _v(a), "scale": float(radii[i]) * 1.04, "material": material, "jitter": 0.1})
		for part in run:
			if motion != "":
				part["motion"] = motion
				part["phase"] = phase
			if i < names.size() and str(names[i]) != "":
				part["name"] = names[i]
			parts.append(part)

static func _band(parts: Array, centre: Vector3, normal: Vector3, radius: float, tube: float, n: int, material: String, extra: Dictionary = {}) -> void:
	## A hoop, a coil of rope or a chain link: a band of `n` boxes round `normal`.
	var f: Vector3 = normal.normalized()
	var s: Vector3 = _side(f)
	var u: Vector3 = _up(f)
	var span: float = TAU * radius / float(n) * 1.14
	for i in range(n):
		var ang: float = TAU * (float(i) + 0.5) / float(n)
		var out: Vector3 = s * cos(ang) * radius + u * sin(ang) * radius
		var tangent: Vector3 = (-s * sin(ang) * radius + u * cos(ang) * radius).normalized()
		var part: Dictionary = {"shape": "box", "at": _v(centre + out), "aim": _v(tangent), "material": material, "size": [tube, span, tube]}
		part.merge(extra)
		parts.append(part)

static func _disc(parts: Array, centre: Vector3, normal: Vector3, radius: float, width: float, material: String, extra: Dictionary = {}) -> void:
	## An octagonal ring seen from both sides: two 8-segment rings laid back to back.
	var f: Vector3 = normal.normalized()
	for side in [1.0, -1.0]:
		var part: Dictionary = {"shape": "ring", "at": _v(centre + f * side * 0.004), "aim": _v(f * side), "material": material, "radius": radius, "width": width, "segments": 8}
		part.merge(extra)
		parts.append(part)

static func _ripple(parts: Array, at: Vector3, radius: float, phase: float, material: String = "core") -> void:
	## An octagonal ring of water on the floor where a body breaks the surface.
	parts.append({"shape": "ring", "at": [at.x, 0.035, at.z], "material": material, "motion": "core", "phase": phase, "radius": radius, "width": radius * 0.14, "segments": 8})

static func _spots(parts: Array, points: Array, radii: Array, k: float, every: int = 1, phase0: float = 0.0) -> void:
	## Lit gem spots down the flank, one side then the other.
	for i in range(1, points.size() - 1, every):
		var seg: Vector3 = points[i + 1] - points[i - 1]
		var s: Vector3 = _side(seg) if absf(seg.normalized().y) < 0.95 else Vector3.RIGHT
		var side: float = 1.0 if i % 2 == 0 else -1.0
		parts.append(_gem(points[i] + s * side * float(radii[i]) * 0.95, k, "accent", {"motion": "core", "phase": phase0 + float(i) * 0.55, "name": "spot"}))

static func _fins(parts: Array, points: Array, radii: Array, first: int, last: int, height: float, phase0: float = 0.0) -> void:
	## A dorsal fin: a prism (a sawtooth crest) stood on each run of the body from `first` to `last`.
	for i in range(first, last):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg: Vector3 = b - a
		var r: float = (float(radii[i]) + float(radii[i + 1])) * 0.5
		var up: Vector3 = _up(seg) if absf(seg.normalized().y) < 0.95 else Vector3.BACK
		parts.append({"shape": "prism", "at": _v((a + b) * 0.5 + up * (r * 0.8 + height * 0.4)), "rot": _along(seg), "material": "body", "motion": "core", "phase": phase0 + float(i) * 0.55, "size": [seg.length() * 1.08, height, 0.035], "name": "fin"})

static func _jaws(parts: Array, centre: Vector3, facing: Vector3, neck: Vector3, k: float, teeth: int, phase: float, snout: float = 1.0, crest: bool = true) -> Vector3:
	## A proper head: a cut-stone skull, an upper jaw and a lower jaw hung open, rows of crystal
	## teeth, two gem eyes and, when asked, two crests swept back off the brow. `k` is its size (1
	## for the Undertow, about 0.5 for a Seep Eel), `snout` stretches the jaws. The skull, upper
	## jaw, upper teeth, eyes and crests are `head`, turning at `neck`; the lower jaw and its teeth
	## are `jaw`, on their hinge. Returns the gape, where a bite lands.
	var f: Vector3 = facing.normalized()
	var s: Vector3 = _side(f)
	var u: Vector3 = _up(f)
	var low: Vector3 = (f * cos(deg_to_rad(32.0)) - u * sin(deg_to_rad(32.0))).normalized()
	var u_low: Vector3 = low.cross(s).normalized()
	var hinge: Vector3 = centre - u * 0.2 * k + f * 0.1 * k
	var head_at: Array = _v(neck)
	var jaw_at: Array = _v(hinge)
	parts.append({"shape": "rock", "at": _v(centre), "rot": _face(f), "scale": [0.5 * k, 0.42 * k, 0.55 * k], "material": "body", "motion": "bob", "phase": phase, "jitter": 0.08, "name": "head", "joint": head_at})
	parts.append({"shape": "slab", "at": _v(centre + f * 0.5 * k * snout + u * 0.04 * k), "rot": _face(f), "material": "body", "motion": "bob", "phase": phase, "size": [0.76 * k, 0.24 * k, 0.8 * k * snout], "jitter": 0.02, "name": "head", "joint": head_at})
	parts.append({"shape": "slab", "at": _v(hinge + low * 0.42 * k * snout), "rot": _face(low), "material": "body", "motion": "bob", "phase": phase + 0.6, "size": [0.68 * k, 0.15 * k, 0.74 * k * snout], "jitter": 0.02, "name": "jaw", "joint": jaw_at})
	for t in range(teeth):
		var b: float = lerpf(-0.26, 0.26, float(t) / maxf(1.0, float(teeth) - 1.0)) * k
		var along: float = (0.86 - 0.16 * float(t % 2)) * k * snout
		var top: Vector3 = centre + f * along + s * b - u * 0.08 * k
		parts.append({"shape": "cone", "from": _v(top), "to": _v(top - u * 0.2 * k), "material": "accent", "motion": "bob", "phase": phase, "radius": 0.045 * k, "sides": 4, "name": "head", "joint": head_at})
		var bottom: Vector3 = hinge + low * (along - 0.08 * k) + s * b + u_low * 0.07 * k
		parts.append({"shape": "cone", "from": _v(bottom), "to": _v(bottom + u_low * 0.2 * k), "material": "accent", "motion": "bob", "phase": phase + 0.6, "radius": 0.045 * k, "sides": 4, "name": "jaw", "joint": jaw_at})
	for side in [-1.0, 1.0]:
		parts.append(_gem(centre + f * 0.22 * k + s * side * 0.32 * k + u * 0.26 * k, 0.11 * k, "accent", {"motion": "bob", "phase": phase, "name": "head", "joint": head_at}))
		if crest:
			parts.append({"shape": "crystal", "from": _v(centre + s * side * 0.2 * k + u * 0.36 * k - f * 0.1 * k), "to": _v(centre + s * side * 0.3 * k + u * 0.62 * k - f * 0.42 * k), "material": "accent", "motion": "bob", "phase": phase, "radius": 0.06 * k, "name": "head", "joint": head_at})
	return hinge + (f * cos(deg_to_rad(16.0)) - u * sin(deg_to_rad(16.0))) * 0.7 * k * snout

static func _sucker(parts: Array, mouth: Vector3, d: Vector3, k: float, phase: float) -> void:
	## A lamprey's round mouth: a six-sided lip, a ring of crystal teeth leaning in, a gem gullet;
	## all `mouth`, pivoting at the mouth's centre.
	var f: Vector3 = d.normalized()
	var s: Vector3 = _side(f)
	var u: Vector3 = _up(f)
	var at: Array = _v(mouth)
	parts.append({"shape": "ring", "at": _v(mouth), "aim": _v(f), "material": "body", "motion": "bob", "phase": phase, "radius": 0.145 * k, "width": 0.07 * k, "segments": 6, "name": "mouth", "joint": at})
	for t in range(5):
		var ang: float = TAU * float(t) / 5.0
		var out: Vector3 = s * cos(ang) + u * sin(ang)
		parts.append({"shape": "cone", "from": _v(mouth + out * 0.085 * k + f * 0.02 * k), "to": _v(mouth + out * 0.015 * k + f * 0.07 * k), "material": "accent", "motion": "bob", "phase": phase, "radius": 0.024 * k, "sides": 4, "name": "mouth", "joint": at})
	parts.append(_gem(mouth - f * 0.02 * k, 0.055 * k, "accent", {"motion": "bob", "phase": phase, "name": "mouth", "joint": at}))

static func _lamprey_head(parts: Array, neck: Vector3, d: Vector3, k: float, phase: float) -> void:
	## A cut-stone head from the neck, the sucker on its end, two gem eyes behind the mouth and a
	## crystal crest on the brow; the head, eyes and crest are `head`, turning at the neck.
	var f: Vector3 = d.normalized()
	var s: Vector3 = _side(f)
	var u: Vector3 = _up(f)
	var head: Vector3 = neck + f * 0.16 * k
	var at: Array = _v(neck)
	parts.append({"shape": "rock", "at": _v(head), "rot": _face(f), "scale": [0.13 * k, 0.12 * k, 0.21 * k], "material": "body", "motion": "bob", "phase": phase, "jitter": 0.08, "name": "head", "joint": at})
	_sucker(parts, head + f * 0.19 * k, f, k, phase)
	for side in [-1.0, 1.0]:
		parts.append(_gem(head + f * 0.08 * k + s * side * 0.11 * k + u * 0.08 * k, 0.032 * k, "accent", {"motion": "bob", "phase": phase, "name": "head", "joint": at}))
	parts.append({"shape": "crystal", "from": _v(head + u * 0.1 * k - f * 0.04 * k), "to": _v(head + u * 0.27 * k - f * 0.16 * k), "material": "accent", "motion": "bob", "phase": phase, "radius": 0.03 * k, "name": "head", "joint": at})

static func _helmet(parts: Array, at: Vector3, motion: String, phase: float, k: float = 1.0) -> void:
	## A miner's hard hat (an eight-sided cap on a hex brim) with its lamp lit on the front: the
	## lamp is the eye of the thing. All `head`, turning where the hat sits.
	var seat: Array = _v(at)
	parts.append({"shape": "cap", "at": _v(at), "material": "iron", "motion": motion, "phase": phase, "radius": 0.3 * k, "height": 0.22 * k, "sides": 8, "seed": 61, "name": "head", "joint": seat})
	parts.append({"shape": "cylinder", "at": _v(at + Vector3(0, 0.02, 0.03) * k), "material": "iron", "motion": motion, "phase": phase, "top": 0.38 * k, "bottom": 0.38 * k, "height": 0.04 * k, "sides": 6, "name": "head", "joint": seat})
	parts.append({"shape": "box", "at": _v(at + Vector3(0, 0.1, 0.27) * k), "material": "iron", "motion": motion, "phase": phase, "size": [0.12 * k, 0.1 * k, 0.08 * k], "name": "head", "joint": seat})
	parts.append(_gem(at + Vector3(0, 0.1, 0.34) * k, 0.085 * k, "accent", {"motion": motion, "phase": phase, "name": "head", "joint": seat}))

static func _pick(parts: Array, grip: Vector3, head_at: Vector3, extra: Dictionary = {}, k: float = 1.0) -> void:
	## A pick: an iron haft from `grip` to `head_at`, the point and the blade across it; `extra`
	## (a name, a joint) goes on every piece.
	var haft: Vector3 = (head_at - grip).normalized()
	var across: Vector3 = _side(haft) if absf(haft.y) < 0.9 else Vector3.RIGHT
	var swing_up: Vector3 = haft.cross(across).normalized()
	for piece in [
		{"shape": "cylinder", "from": _v(grip), "to": _v(head_at + haft * 0.08 * k), "material": "iron", "top": 0.035 * k, "bottom": 0.04 * k, "sides": 6},
		{"shape": "cylinder", "from": _v(head_at - haft * 0.08 * k), "to": _v(head_at + haft * 0.08 * k), "material": "iron", "top": 0.07 * k, "bottom": 0.07 * k, "sides": 6},
		{"shape": "cone", "from": _v(head_at), "to": _v(head_at + (swing_up - haft * 0.3).normalized() * 0.5 * k), "material": "iron", "radius": 0.07 * k, "sides": 5},
		{"shape": "cone", "from": _v(head_at), "to": _v(head_at - (swing_up + haft * 0.3).normalized() * 0.36 * k), "material": "iron", "radius": 0.065 * k, "sides": 4}]:
		piece.merge(extra)
		parts.append(piece)

static func _weed(parts: Array, from: Vector3, to: Vector3, phase: float, extra: Dictionary = {}) -> void:
	## A strand of drowned weed hung from `from`, swinging from there; `extra` re-hangs it (a
	## strand caught on a swaying neck sways with that neck).
	var part: Dictionary = {"shape": "cone", "from": _v(from), "to": _v(to), "material": "body", "motion": "swing", "phase": phase, "joint": _v(from), "radius": 0.03, "sides": 4, "name": "weed"}
	part.merge(extra, true)
	parts.append(part)

static func _wheel(parts: Array, centre: Vector3, axle: Vector3, radius: float, phase: float = 0.0) -> void:
	## A valve wheel turning on its axle: an octagonal bright rim, two spokes, a hex iron hub.
	var n: Vector3 = axle.normalized()
	_disc(parts, centre, n, radius, radius * 0.22, "accent", {"motion": "spin", "phase": phase, "name": "wheel"})
	parts.append({"shape": "box", "at": _v(centre), "aim": _v(n), "material": "accent", "motion": "spin", "phase": phase, "size": [radius * 1.75, radius * 0.13, radius * 0.13], "name": "wheel"})
	parts.append({"shape": "box", "at": _v(centre), "aim": _v(n), "material": "accent", "motion": "spin", "phase": phase, "mesh_rot": [0, 90, 0], "size": [radius * 1.75, radius * 0.13, radius * 0.13], "name": "wheel"})
	parts.append({"shape": "cylinder", "from": _v(centre - n * radius * 0.4), "to": _v(centre + n * radius * 0.18), "material": "iron", "top": radius * 0.18, "bottom": radius * 0.2, "sides": 6, "name": "wheel"})

static func _lantern(parts: Array, hook: Vector3, phase: float, k: float = 1.0) -> void:
	## A hand lantern hung from `hook`, swinging there.
	for piece in [
		{"shape": "cylinder", "from": _v(hook), "to": _v(hook + Vector3(0, -0.14, 0) * k), "material": "iron", "top": 0.02 * k, "bottom": 0.02 * k, "sides": 4},
		{"shape": "cone", "at": _v(hook + Vector3(0, -0.18, 0) * k), "material": "iron", "radius": 0.13 * k, "height": 0.1 * k, "sides": 6},
		{"shape": "cylinder", "at": _v(hook + Vector3(0, -0.32, 0) * k), "material": "accent", "top": 0.09 * k, "bottom": 0.09 * k, "height": 0.2 * k, "sides": 6},
		{"shape": "cylinder", "at": _v(hook + Vector3(0, -0.44, 0) * k), "material": "iron", "top": 0.12 * k, "bottom": 0.12 * k, "height": 0.05 * k, "sides": 6}]:
		piece.merge({"joint": _v(hook), "motion": "swing", "phase": phase, "name": "lantern"})
		parts.append(piece)

static func _singer(parts: Array, root: Vector3, mids: Array, head: Vector3, facing: Vector3, k: float, phase: float, eyes: bool = true, neck_r: float = 0.16) -> void:
	## A drowned head on a neck: the neck (`neck`) hex columns from `root` through `mids` to
	## `head` with a cut stone at every bend, the head (`head`) a cut stone with pale gem eyes,
	## its mouth (`mouth`) a six-sided ring held open in song toward `facing` with a gem throat
	## behind it. Everything hangs from the root and sways there as one.
	var f: Vector3 = facing.normalized()
	var s: Vector3 = _side(f)
	var u: Vector3 = _up(f)
	var pts: Array = [root]
	pts.append_array(mids)
	pts.append(head)
	var pieces: Array = []
	for i in range(pts.size() - 1):
		var r: float = neck_r * k * (1.0 - 0.12 * float(i))
		pieces.append({"shape": "column", "from": _v(pts[i]), "to": _v(pts[i + 1]), "material": "body", "radius": r, "sides": 6, "name": "neck"})
		if i > 0:
			pieces.append(_stone(pts[i], r * 1.08, "body", 0.1, {"name": "neck"}))
	pieces.append(_stone(head, 0.32 * k, "body", 0.1, {"name": "head"}))
	pieces.append({"shape": "ring", "at": _v(head + f * 0.3 * k), "aim": _v(f), "material": "accent", "radius": 0.17 * k, "width": 0.08 * k, "segments": 6, "name": "mouth"})
	pieces.append(_gem(head + f * 0.24 * k, 0.1 * k, "core", {"name": "mouth"}))
	if eyes:
		for side in [-1.0, 1.0]:
			pieces.append(_gem(head + f * 0.24 * k + s * side * 0.15 * k + u * 0.14 * k, 0.05 * k, "accent", {"name": "head"}))
	for piece in pieces:
		piece.merge({"joint": _v(root), "motion": "swing", "phase": phase})
		parts.append(piece)
