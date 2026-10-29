extends RefCounted
## Recipes for tools/creature_bake.gd: the Geode. See tools/creature_bake.gd for the format.
##
## Every model here is the owner's pick from the creature review (Oct 2026), moved in with the
## code that built it from its batch in build/options/recipes (r3a, r3d, r4). Each recipe's
## "seed" is the picked option's key there, so the bake cuts every unseeded rock, crystal and
## slab facet for facet as it was picked. They draw from one random stream in part order:
## never reorder the parts or slip a faceted part in among them (markers go at the end).
## The parts an animation moves are named (`claw_r`, `jaw`, `tongue`, `scales`, ...) and hung
## from their hinge (`joint`); build/options/part_roles/geode.md lists them and which way
## each moves. z+ faces the party, y is up, +x is the creature's own left.

static func recipes() -> Dictionary:
	return {
		"CROUPIER_CRAB": _croupier_crab(),
		"GEODE_GOLEM": _geode_golem(),
		"HOARD_MIMIC": _hoard_mimic(),
		"CRYSTAL_HYDRA": _crystal_hydra(),
		"THE_ASSAYER": _assayer(),
		"THE_COLLECTOR": _collector(),
		"THE_HOLLOW_CROWN": _hollow_crown()}

## ---- helpers ----------------------------------------------------------------------------

## A vector as the [x, y, z] a recipe takes.
static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

## A recipe's [x, y, z] (or a vector) back as a vector.
static func _vec(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

## `part` with `extra`'s fields laid over it.
static func _merged(part: Dictionary, extra: Dictionary) -> Dictionary:
	part.merge(extra, true)
	return part

## The bake's own rule: upright turned the shortest way round until Y runs along `direction`.
static func _aimed(direction: Vector3) -> Basis:
	var up: Vector3 = direction.normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() < 0.0001:
		return Basis() if up.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(up))

## A basis as the degrees a part's `rot` takes.
static func _rot(basis: Basis) -> Array:
	var e: Vector3 = basis.orthonormalized().get_euler()
	return [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

## Euler degrees for a part whose long axis (Y) runs along `y_axis` and whose width (X) runs
## along `x_axis`.
static func _frame(x_axis: Vector3, y_axis: Vector3) -> Array:
	var y := y_axis.normalized()
	var x := (x_axis - y * x_axis.dot(y)).normalized()
	return _rot(Basis(x, y, x.cross(y)))

## A frame whose +z runs along `forward` and whose +y stays as near up as it can.
static func _look(forward: Vector3) -> Basis:
	var f: Vector3 = forward.normalized()
	var r: Vector3 = Vector3.UP.cross(f).normalized()
	return Basis(r, f.cross(r), f)

## `n + 1` points along a Catmull-Rom curve through `pts`: one smooth run for a tongue, so the
## stones laid along it never kink apart.
static func _spline(pts: Array, n: int) -> Array:
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

## ---- shapes -------------------------------------------------------------------------------

## A pentagonal gem: an eye, a stud, a knob.
static func _eye(at: Vector3, size: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "sphere", "at": _v(at), "scale": size, "material": material, "radius": 1.0, "segments": 5, "rings": 2}, extra)

## The biggest cut gem allowed: six segments, three rings.
static func _gem(at: Vector3, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	var s: Variant = _v(size) if size is Vector3 else size
	return _merged({"shape": "sphere", "at": _v(at), "scale": s, "material": material, "radius": 1.0, "segments": 6, "rings": 3}, extra)

## The same gem pulsing (r4's gem): a heart, an iris, a jewel on show.
static func _glow_gem(at: Vector3, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	return _gem(at, size, material, _merged({"motion": "core"}, extra))

## A tiny quiet gem where a bite leaves the mouth: a marker for the animation, laid last.
static func _mouth_mark(at: Vector3, extra: Dictionary = {}) -> Dictionary:
	var mark: Dictionary = _eye(at, 0.02, "accent", extra)
	mark["name"] = "mouth"
	return mark

## A cut rock: low `jitter` is a cut stone, high a boulder.
static func _rock(at: Vector3, size: Variant, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	var s: Variant = _v(size) if size is Vector3 else float(size)
	return _merged({"shape": "rock", "at": _v(at), "scale": s, "material": material, "jitter": jitter, "seed": seed}, extra)

## One cut stone aimed along `from` to `to`: a claw's palm.
static func _stone(from: Vector3, to: Vector3, r: float, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "rock", "at": _v((from + to) * 0.5), "aim": _v(to - from), "scale": [r, from.distance_to(to) * 0.6 + r * 0.2, r], "material": material, "jitter": jitter, "seed": seed}, extra)

## One cut stone turned to lie from `from` to `to`, a little flat: a neck, a thigh, a forearm.
static func _limb_stone(from: Vector3, to: Vector3, r: float, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "rock", "at": _v((from + to) * 0.5), "rot": _rot(_aimed(to - from)), "scale": [r, from.distance_to(to) * 0.6 + r * 0.2, r * 0.92], "material": material, "jitter": jitter, "seed": seed}, extra)

## A stick of any shape from `a` to `b`, `r` thick.
static func _stick(shape: String, a: Vector3, b: Vector3, r: float, material: String, extra: Dictionary = {}) -> Dictionary:
	var part: Dictionary = {"shape": shape, "from": _v(a), "to": _v(b), "material": material}
	match shape:
		"cylinder":
			part.merge({"bottom": r, "top": r * 0.8, "sides": 6})
		"cone":
			part.merge({"radius": r, "sides": 5})
		"spike":
			part.merge({"radius": r, "sides": 5, "lean": 0.0})
		_:
			part.merge({"radius": r, "sides": 6})
	return _merged(part, extra)

## A faceted slab (a lid, a brow, a cheek).
static func _slab(at: Vector3, size: Vector3, material: String, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "slab", "at": _v(at), "material": material, "size": _v(size), "jitter": 0.02}, extra)

## A box: a band, a pane, a pupil.
static func _box(at: Vector3, size: Vector3, material: String, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "box", "at": _v(at), "material": material, "size": _v(size)}, extra)

## A square bar from `a` to `b`: a facet edge, a beam, a tear.
static func _bar(a: Vector3, b: Vector3, thick: float, material: String, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "box", "at": _v((a + b) * 0.5), "aim": _v(b - a), "material": material, "size": [thick, a.distance_to(b), thick]}, extra)

## A hex stick, r0 thick at `from`, r1 at `to`.
static func _rod(from: Vector3, to: Vector3, r0: float, r1: float, material: String = "body", extra: Dictionary = {}, sides: int = 6) -> Dictionary:
	return _merged({"shape": "cylinder", "from": _v(from), "to": _v(to), "material": material, "bottom": r0, "top": r1, "sides": sides}, extra)

## An upright hex drum: a pan.
static func _drum(at: Vector3, bottom: float, top: float, height: float, material: String, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "cylinder", "at": _v(at), "material": material, "bottom": bottom, "top": top, "height": height, "sides": 6}, extra)

## A cone from its base at `from` to its point at `to`: a tooth, a claw, a foot.
static func _cone(from: Vector3, to: Vector3, r: float, material: String = "body", extra: Dictionary = {}, sides: int = 5) -> Dictionary:
	return _merged({"shape": "cone", "from": _v(from), "to": _v(to), "material": material, "radius": r, "sides": sides}, extra)

## A crystal from its root at `from` to its point at `to`, swaying. `sides` is written only
## where the r3a batch wrote it (the bake's default is six).
static func _crystal(from: Vector3, to: Vector3, r: float, material: String = "accent", extra: Dictionary = {}, sides: int = 0) -> Dictionary:
	var part: Dictionary = {"shape": "crystal", "from": _v(from), "to": _v(to), "material": material, "motion": "crystal", "radius": r}
	if sides > 0:
		part["sides"] = sides
	return _merged(part, extra)

## A hex crystal column from `from` to `to`: a step of a neck.
static func _column(from: Vector3, to: Vector3, r: float, material: String = "body", extra: Dictionary = {}, sides: int = 6) -> Dictionary:
	return _merged({"shape": "column", "from": _v(from), "to": _v(to), "material": material, "radius": r, "sides": sides}, extra)

## A hex plate facing `normal`: a coin, a socket, a gem's table.
static func _disc(at: Vector3, normal: Vector3, radius: float, thick: float, material: String, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "cylinder", "at": _v(at), "aim": _v(normal), "material": material, "top": radius, "bottom": radius, "height": thick, "sides": 6}, extra)

## A coin: a thin hex plate (the crab's are 0.024 thick, the mimic's 0.022).
static func _coin(at: Vector3, normal: Vector3, radius: float, material: String = "core", thick: float = 0.024) -> Dictionary:
	return _disc(at, normal, radius, thick, material)

## An eight-sided ring facing `normal`: a halo, a lip.
static func _hoop(at: Vector3, normal: Vector3, radius: float, width: float, material: String, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "ring", "at": _v(at), "aim": _v(normal), "material": material, "radius": radius, "width": width, "segments": 8}, extra)

## A small shard: a mote of iron in the air.
static func _shard(at: Vector3, rot: Array, size: float, material: String, extra: Dictionary = {}) -> Dictionary:
	return _merged({"shape": "shard", "at": _v(at), "rot": rot, "scale": size, "material": material, "size": 0.12}, extra)

## A thin triangular panel, apex `a`, base `b`-`c`: a tail, a wing.
static func _tri(a: Vector3, b: Vector3, c: Vector3, material: String, extra: Dictionary = {}, thick: float = 0.045) -> Dictionary:
	var x: Vector3 = (c - b).normalized()
	var mid: Vector3 = (b + c) * 0.5
	var up: Vector3 = a - mid
	up = up - x * up.dot(x)
	var h: float = maxf(up.length(), 0.01)
	var y: Vector3 = up / h
	return _merged({"shape": "prism", "at": _v(mid + y * h * 0.5), "rot": _rot(Basis(x, y, x.cross(y))), "material": material, "size": [b.distance_to(c), h, thick]}, extra)

## ---- groups and frames ------------------------------------------------------------------------

## Every piece hung from one joint, moving as one, and (given a `name`) named for its role.
static func _hang(pieces: Array, joint: Vector3, motion: String, phase: float, name: String = "") -> Array:
	for piece in pieces:
		piece.merge({"joint": _v(joint), "motion": motion, "phase": phase}, true)
		if name != "":
			piece["name"] = name
	return pieces

## Every piece given the same fields.
static func _moving(pieces: Array, extra: Dictionary) -> Array:
	for piece in pieces:
		piece.merge(extra, true)
	return pieces

## Names every part laid since `from` and hangs it from `joint`.
static func _name_since(parts: Array, from: int, name: String, joint: Vector3) -> void:
	for i in range(from, parts.size()):
		var part: Dictionary = parts[i]
		part.merge({"name": name, "joint": _v(joint)}, true)

## A hoop of `n` boxes laid end to end round `normal`: a crown's band.
static func _band(centre: Vector3, normal: Vector3, radius: float, thick: float, depth: float, material: String, n: int = 8, roll: float = 0.0, extra: Dictionary = {}) -> Array:
	var axis: Vector3 = normal.normalized()
	var u: Vector3 = Vector3.UP.cross(axis)
	if u.length() < 0.001:
		u = Vector3.RIGHT
	u = u.normalized()
	var w: Vector3 = axis.cross(u).normalized()
	var length: float = 2.0 * (radius + thick * 0.5) * tan(PI / float(n))
	var out: Array = []
	for i in range(n):
		var ang: float = TAU * float(i) / float(n) + roll
		var radial: Vector3 = (u * cos(ang) + w * sin(ang)).normalized()
		var tangent: Vector3 = axis.cross(radial).normalized()
		out.append(_merged({"shape": "box", "at": _v(centre + radial * radius), "rot": _rot(Basis(radial, tangent, axis)), "material": material, "size": [thick, length, depth]}, extra.duplicate()))
	return out

## A long body as cut stones stepping along `path`, each overlapping the next.
static func _rocks(out: Array, path: Array, widths: Array, material: String, seed_base: int, extra: Dictionary = {}, jitter: float = 0.1, flat: float = 1.0, split: int = 1, reach: float = 0.62) -> void:
	var points: Array = []
	var sizes: Array = []
	for i in range(path.size()):
		points.append(path[i])
		sizes.append(float(widths[i]))
		if i < path.size() - 1:
			for k in range(1, split):
				var t: float = float(k) / float(split)
				points.append((path[i] as Vector3).lerp(path[i + 1], t))
				sizes.append(lerpf(float(widths[i]), float(widths[i + 1]), t))
	var n: int = points.size()
	for i in range(n):
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, n - 1)]
		var step: float = maxf(p.distance_to(prev), p.distance_to(next))
		var w: float = sizes[i]
		out.append(_merged({"shape": "rock", "at": _v(p), "aim": _v(next - prev), "scale": [w, maxf(step * reach, w * 0.7), w * flat], "material": material, "jitter": jitter, "seed": seed_base + i}, extra.duplicate()))

## Cut stones laid point to point, each half again as long as its step so neighbours overlap
## and the run reads as one body with no gaps. `rooted` hangs each stone from its own root
## (where the one before it ends), so the run can curl or unroll stone by stone.
static func _run(out: Array, pts: Array, r0: float, r1: float, material: String, seed: int, jitter: float = 0.07, extra: Dictionary = {}, rooted: bool = false) -> void:
	var n: int = pts.size() - 1
	for i in range(n):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var r: float = lerpf(r0, r1, (float(i) + 0.5) / float(n))
		var part: Dictionary = _merged({"shape": "rock", "at": _v((a + b) * 0.5), "aim": _v(b - a), "scale": [r, maxf(a.distance_to(b) * 1.0, r * 0.85), r], "material": material, "jitter": jitter, "seed": seed + i}, extra.duplicate())
		if rooted:
			part["joint"] = _v(a)
		out.append(part)

## Pieces drawn in their own frame set into the creature at `origin`, turned and grown.
static func _place(out: Array, pieces: Array, origin: Vector3, basis: Basis, s: float, extra: Dictionary = {}) -> void:
	for piece in pieces:
		var q: Dictionary = (piece as Dictionary).duplicate(true)
		if q.has("from"):
			q["from"] = _v(origin + basis * (_vec(q["from"]) * s))
			q["to"] = _v(origin + basis * (_vec(q["to"]) * s))
			for key in ["radius", "top", "bottom"]:
				if q.has(key):
					q[key] = float(q[key]) * s
		else:
			q["at"] = _v(origin + basis * (_vec(q.get("at", [0, 0, 0])) * s))
			var local: Basis = _aimed(_vec(q["aim"])) if q.has("aim") else Basis.from_euler(_vec(q.get("rot", [0, 0, 0])) * (PI / 180.0))
			q.erase("aim")
			q["rot"] = _rot(basis * local)
			var sc: Variant = q.get("scale", 1.0)
			q["scale"] = [float(sc[0]) * s, float(sc[1]) * s, float(sc[2]) * s] if sc is Array else float(sc) * s
		if q.has("joint"):
			q["joint"] = _v(origin + basis * (_vec(q["joint"]) * s))
		q.merge(extra, true)
		out.append(q)

## Turns a whole laid model about `pivot`: points, sticks, joints, aims and rotations.
static func _turned(parts: Array, pivot: Vector3, turn: Basis) -> void:
	for part in parts:
		for key in ["at", "from", "to", "joint"]:
			if part.has(key):
				part[key] = _v(pivot + turn * (_vec(part[key]) - pivot))
		if part.has("aim"):
			part["aim"] = _v(turn * _vec(part["aim"]))
		elif not part.has("from"):
			var r: Array = part.get("rot", [0, 0, 0])
			part["rot"] = _rot(turn * Basis.from_euler(_vec(r) * (PI / 180.0)))

## The whole model flipped left for right. The review stage photographed a creature from its
## own left (-x) side, so a big claw authored on the right was turned to face it.
static func _mirror(parts: Array) -> Array:
	for part in parts:
		for key in ["at", "from", "to", "joint", "aim", "offset"]:
			if part.has(key):
				var p: Array = part[key]
				part[key] = [-float(p[0]), p[1], p[2]]
		for key in ["rot", "mesh_rot"]:
			if part.has(key):
				var r: Array = part[key]
				part[key] = [r[0], -float(r[1]), -float(r[2])]
	return parts

## ---- Croupier Crab ------------------------------------------------------------------------

## A two-piece leg that swings from the hip: a `leg`, hung there.
static func _rod_leg(out: Array, hip: Vector3, knee: Vector3, foot: Vector3, r_hip: float, r_knee: float, r_foot: float, phase: float, material: String = "body") -> void:
	var extra := {"name": "leg", "joint": _v(hip), "motion": "swing", "phase": phase}
	out.append(_rod(hip, knee, r_hip, r_knee, material, extra, 5))
	out.append(_rod(knee, foot, r_knee, r_foot, material, extra, 5))

## The hermit's soft front, coming out of whatever it lives in: a cut-stone `head` with an
## `eye` on each stalk, a big claw (holding up a coin), a small one, and three legs a side
## reaching from inside the vessel to the floor. `c` is the head's middle. Laid before the
## mirror: the big claw drawn at +x ends up on the crab's own right, so it is `claw_r`.
static func _crab(out: Array, c: Vector3, leg_zs: Array, coin_in_claw: bool) -> void:
	out.append(_rock(c, Vector3(0.26, 0.15, 0.22), "body", 0.1, 260, {"name": "head", "joint": _v(c + Vector3(0, 0, -0.2))}))
	for side in [-1.0, 1.0]:
		var base: Vector3 = c + Vector3(side * 0.09, 0.08, 0.12)
		var top: Vector3 = c + Vector3(side * 0.15, 0.32, 0.2)
		out.append_array(_hang([_rod(base, top, 0.03, 0.022, "body", {}, 5), _eye(top + Vector3(0, 0.04, 0), 0.055)], base, "swing", 0.5 if side > 0.0 else 2.0, "eye"))
		for i in range(leg_zs.size()):
			var z: float = leg_zs[i]
			var sp: float = 0.12 - 0.12 * float(i)
			_rod_leg(out, Vector3(side * 0.18, c.y + 0.02, z), Vector3(side * 0.5, c.y + 0.2, z + sp), Vector3(side * 0.66, 0.02, z + 2.0 * sp), 0.04, 0.028, 0.014, float(i) * 1.2 + (0.0 if side > 0.0 else 1.6))
	var big: Vector3 = c + Vector3(0.18, -0.02, 0.1)
	var claw: Array = [
		_rod(big, c + Vector3(0.42, 0.04, 0.26), 0.06, 0.05),
		_stone(c + Vector3(0.42, 0.04, 0.26), c + Vector3(0.4, 0.08, 0.56), 0.14, "body", 0.1, 261),
		_cone(c + Vector3(0.32, 0.04, 0.6), c + Vector3(0.2, 0.08, 0.84), 0.06),
		_cone(c + Vector3(0.44, 0.14, 0.6), c + Vector3(0.3, 0.24, 0.82), 0.05)]
	if coin_in_claw:
		claw.append(_coin(c + Vector3(0.25, 0.2, 0.86), Vector3(0.5, 0.1, 0.86), 0.1, "core"))
	out.append_array(_hang(claw, big, "swing", 0.2, "claw_r"))
	var small: Vector3 = c + Vector3(-0.18, -0.02, 0.1)
	out.append_array(_hang([
		_rod(small, c + Vector3(-0.36, 0.02, 0.26), 0.045, 0.04),
		_stone(c + Vector3(-0.36, 0.02, 0.26), c + Vector3(-0.34, 0.04, 0.46), 0.09, "body", 0.1, 262),
		_cone(c + Vector3(-0.3, 0.02, 0.48), c + Vector3(-0.24, 0.05, 0.64), 0.04),
		_cone(c + Vector3(-0.38, 0.08, 0.48), c + Vector3(-0.34, 0.12, 0.62), 0.035)], small, "swing", 1.8, "claw_l"))

## The Croupier Crab: a hermit in a black iron cauldron with a gold band, tipped on its side,
## stubby feet in the air behind; head, claws and legs out of the mouth, gold heaped in it, a
## coin in the big claw. (r3a CROUPIER_CRAB_A)
static func _croupier_crab() -> Dictionary:
	var tint := "d8a83a"
	var accent := "ffffff"
	var mouth := Vector3(0, 0.5, 0.06)
	var axis := Vector3(0, -0.1, 1).normalized()
	var bottom: Vector3 = mouth - axis * 0.84
	var at := func(t: float) -> Vector3: return bottom + axis * t
	## The cauldron is the hermit's `shell`, rocking a little on its mouth (the batch left it
	## still, but the first part must move).
	var shell := {"name": "shell", "joint": _v(mouth), "motion": "crystal", "phase": 0.0}
	var a: Array = [
		_rod(at.call(0.0), at.call(0.12), 0.22, 0.4, "iron", shell.duplicate()),
		_rod(at.call(0.12), at.call(0.36), 0.4, 0.52, "iron", shell.duplicate()),
		_rod(at.call(0.36), at.call(0.6), 0.52, 0.4, "iron", shell.duplicate()),
		_rod(at.call(0.33), at.call(0.39), 0.54, 0.54, "body", shell.duplicate()),
		_rod(at.call(0.6), at.call(0.74), 0.4, 0.3, "iron", shell.duplicate()),
		_rod(at.call(0.74), at.call(0.84), 0.3, 0.42, "body", shell.duplicate()),
		_disc(at.call(0.845), axis, 0.36, 0.02, "core", {"motion": "core"})]
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0 + PI * 0.5
		var radial := Vector3(cos(ang), sin(ang), 0)
		a.append(_cone(at.call(0.06) + radial * 0.2, at.call(-0.08) + radial * 0.26, 0.06, "iron", shell.duplicate(), 4))
	_crab(a, Vector3(0, 0.24, 0.24), [0.1, -0.02, -0.14], true)
	for spec in [[Vector3(0.1, 0.72, 0.1), Vector3(0.3, 0.4, 1)], [Vector3(-0.14, 0.66, 0.1), Vector3(-0.4, 0.3, 1)], [Vector3(0.02, 0.8, 0.06), Vector3(0, 1, 0.5)]]:
		a.append(_coin(spec[0], spec[1], 0.08, "body"))
	a.append(_rock(Vector3(0.22, 0.6, 0.1), 0.06, "accent", 0.1, 263))
	for spec in [[Vector3(0.42, 0.012, 0.42), 0.08], [Vector3(-0.5, 0.012, 0.5), 0.075], [Vector3(-0.2, 0.012, 0.76), 0.07], [Vector3(0.62, 0.012, 0.0), 0.07]]:
		a.append(_coin(spec[0], Vector3.UP, spec[1], "body"))
	return {"style": "low", "sway": 2.0, "tint": tint, "accent": accent, "anchor": 1.3, "shadow": 2.4, "ring": 1.2, "seed": "CROUPIER_CRAB_A", "parts": _mirror(a)}

## ---- Geode Golem --------------------------------------------------------------------------

## The Geode Golem: today's Quartz Golem stack of four faceted blocks in the Geode colours,
## twelve amethyst crystals poking out of the blocks at odd angles, the third block cracked open
## down its front on the lit amethyst core. (r3d GEODE_GOLEM_R)
static func _geode_golem() -> Dictionary:
	var tint := "5e5650"
	var accent := "c070ff"
	## [middle, size, turn in degrees, phase]: the blocks of view/creatures/scenes/quartz_golem.tscn.
	var blocks: Array = [
		[Vector3(-0.1, 0.35, 0), Vector3(1.19, 0.61, 0.97), 2.0, 0.0],
		[Vector3(-0.09, 0.97, 0), Vector3(1.05, 0.63, 0.9), -10.5, 0.9],
		[Vector3(0.03, 1.59, 0), Vector3(0.9, 0.65, 0.73), 9.3, 1.8],
		[Vector3(-0.09, 2.21, 0), Vector3(0.69, 0.66, 0.69), 5.8, 2.7]]
	var r: Array = []
	for i in range(blocks.size()):
		var spec: Array = blocks[i]
		var at: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		## Each block turns a little on its own middle with every crystal in it: the top one is
		## the `head`, the rest the `body`.
		var move := {"joint": _v(at), "motion": "block", "phase": spec[3], "name": "head" if i == 3 else "body"}
		if i == 2:
			## Cracked in two down the front, the halves leaning apart, amethyst in the cleft:
			## the lit core and its crystals are the `heart`.
			var heart: Dictionary = _merged(move.duplicate(), {"name": "heart"})
			for side in [-1.0, 1.0]:
				var half := Vector3(size.x * 0.44, size.y, size.z)
				r.append(_slab(at + Vector3(side * size.x * 0.29, 0, 0), half, "body", _merged({"rot": [0, spec[2], -side * 6.0], "jitter": 0.05}, move.duplicate())))
			r.append(_rock(at, Vector3(0.1, 0.28, 0.33), "accent", 0.1, 6101, heart.duplicate()))
			r.append(_gem(at + Vector3(0, 0.0, 0.34), 0.15, "accent", heart.duplicate()))
			for cs in [[Vector3(-0.02, -0.18, 0.2), Vector3(0.0, -0.1, 1.0), 0.15, 0.04], [Vector3(0.03, 0.17, 0.22), Vector3(0.2, 0.4, 1.0), 0.17, 0.045], [Vector3(-0.03, 0.12, 0.25), Vector3(-0.4, 0.5, 1.0), 0.12, 0.03], [Vector3(0.02, -0.04, -0.3), Vector3(0.1, 0.2, -1.0), 0.14, 0.04]]:
				var root: Vector3 = at + cs[0]
				r.append(_merged({"shape": "crystal", "from": _v(root), "to": _v(root + (cs[1] as Vector3).normalized() * float(cs[2])), "material": "accent", "radius": cs[3]}, heart.duplicate()))
		else:
			r.append(_slab(at, size, "body", _merged({"rot": [0, spec[2], 0], "jitter": 0.05}, move.duplicate())))
	## Amethyst poking out of the blocks: [block, a point on its surface (a fraction of its
	## half size, one axis at +-1 for the face), direction, length, radius].
	var spikes: Array = [
		[0, Vector3(1, 0.4, 0.5), Vector3(0.8, 0.55, 0.35), 0.52, 0.1],
		[0, Vector3(1, -0.3, -0.4), Vector3(1, 0.1, -0.3), 0.3, 0.065],
		[0, Vector3(-0.6, 0.6, -1), Vector3(-0.5, 0.4, -0.8), 0.44, 0.085],
		[0, Vector3(-1, 0.2, 0.6), Vector3(-0.9, 0.3, 0.4), 0.28, 0.06],
		[1, Vector3(-1, 0.3, 0.5), Vector3(-0.9, 0.45, 0.4), 0.56, 0.095],
		[1, Vector3(0.5, 0.4, -1), Vector3(0.35, 0.5, -0.8), 0.38, 0.075],
		[1, Vector3(0.3, -0.2, 1), Vector3(0.25, -0.3, 1.0), 0.24, 0.055],
		[2, Vector3(1, 0.3, -0.3), Vector3(1, 0.75, -0.2), 0.44, 0.08],
		[2, Vector3(-1, -0.4, -0.5), Vector3(-0.8, -0.1, -0.6), 0.3, 0.06],
		[3, Vector3(0.6, 1, 0.5), Vector3(0.6, 1, 0.5), 0.38, 0.07],
		[3, Vector3(-1, 0.0, -0.4), Vector3(-1, 0.3, -0.3), 0.32, 0.065],
		[3, Vector3(0.2, 0.5, 1), Vector3(0.2, 0.4, 1), 0.2, 0.05]]
	for sp in spikes:
		var blk: Array = blocks[int(sp[0])]
		var dir: Vector3 = (sp[2] as Vector3).normalized()
		var root: Vector3 = (blk[0] as Vector3) + (sp[1] as Vector3) * (blk[1] as Vector3) * 0.5 - dir * 0.04
		r.append({"shape": "crystal", "from": _v(root), "to": _v(root + dir * float(sp[3]) * 1.6), "material": "accent", "radius": float(sp[4]) * 1.3, "joint": _v(blk[0]), "motion": "block", "phase": blk[3], "name": "head" if int(sp[0]) == 3 else "body"})
	## The crystal hanging over the top of the head.
	r.append({"shape": "crystal", "at": [0, 2.62, 0], "material": "body", "motion": "crystal", "radius": 0.14, "height": 0.72, "sides": 6, "name": "crest"})
	return {"style": "stack", "sway": 0.5, "tint": tint, "accent": accent, "anchor": 3.5, "scale": 1.15, "shadow": 2.2, "ring": 1.15, "seed": "GEODE_GOLEM_R", "parts": r}

## ---- Hoard Mimic --------------------------------------------------------------------------

## The chest's lid, thrown open `open_deg` about its back edge `h`: the `lid`, hung there, with
## gold studs on its iron bands and one even row of teeth along its free edge, at the same
## places as the bottom row and pointing straight out of it so the jaws meet; and two big
## glowing gem eyes with dark pupils set in iron sockets, each `eye` (gem and pupil) hung from
## the middle of its gem so it can roll or blink.
static func _mimic_lid(h: Vector3, open_deg: float, size: Vector3, out: Array, xs: Array, teeth_r: float, teeth_len: float) -> void:
	var lid := {"name": "lid", "joint": _v(h)}
	var a: float = deg_to_rad(-open_deg)
	var d := Vector3(0, -sin(a), cos(a))
	var n_out := Vector3(0, cos(a), sin(a))
	var n_in: Vector3 = -n_out
	var centre: Vector3 = h + d * size.z * 0.5 + n_out * size.y * 0.5
	out.append(_slab(centre, size, "body", _merged({"rot": [-open_deg, 0, 0], "jitter": 0.02}, lid.duplicate())))
	for x in [-0.3, 0.3]:
		var band: Vector3 = centre + Vector3(x * size.x, 0, 0)
		out.append(_box(band, Vector3(0.08, size.y + 0.03, size.z + 0.03), "iron", _merged({"rot": [-open_deg, 0, 0]}, lid.duplicate())))
		for k in [-0.32, 0.0, 0.32]:
			out.append(_eye(band + n_out * (size.y * 0.5 + 0.02) + d * size.z * k, 0.022, "accent", lid.duplicate()))
	var at: Vector3 = h + d * size.z * 0.44 + n_in * (size.y * 0.5)
	for side in [-1.0, 1.0]:
		var e: Vector3 = at + Vector3(side * size.x * 0.15, 0, 0)
		var eye := {"name": "eye", "joint": _v(e + n_in * 0.04)}
		out.append(_disc(e + n_in * 0.012, n_in, 0.105, 0.03, "iron", lid.duplicate()))
		out.append(_gem(e + n_in * 0.04, 0.085, "accent", eye.duplicate()))
		out.append(_eye(e + n_in * 0.11, 0.042, "iron", eye.duplicate()))
	var edge: Vector3 = h + d * (size.z * 0.95) + n_in * (size.y * 0.5)
	for x in xs:
		out.append(_cone(edge + Vector3(x, 0, 0), edge + Vector3(x, 0, 0) + n_in * teeth_len, teeth_r, "accent", lid.duplicate()))

## The Hoard Mimic: an iron-banded chest with its lid thrown open, one even row of seven teeth
## on each jaw, meeting; big glowing gem eyes with dark pupils in iron sockets; one continuous
## tongue of stones down the front and along the floor; gold studs, a keyhole, more gems and
## coins. (r3d HOARD_MIMIC_R)
static func _hoard_mimic() -> Dictionary:
	var tint := "8a5a2a"
	var accent := "ffd76a"
	var r: Array = [
		_slab(Vector3(0, 0.32, 0), Vector3(1.0, 0.56, 0.68), "body", {"motion": "core", "jitter": 0.02}),
		_box(Vector3(0.3, 0.32, 0), Vector3(0.08, 0.6, 0.72), "iron"),
		_box(Vector3(-0.3, 0.32, 0), Vector3(0.08, 0.6, 0.72), "iron"),
		_box(Vector3(0, 0.38, 0.355), Vector3(0.18, 0.22, 0.04), "accent"),
		_eye(Vector3(0, 0.41, 0.375), 0.03, "iron"),
		_box(Vector3(0, 0.355, 0.373), Vector3(0.028, 0.07, 0.02), "iron"),
		_rock(Vector3(0, 0.6, -0.02), Vector3(0.42, 0.1, 0.28), "core", 0.1, 217, {"motion": "core"}),
		_crystal(Vector3(0.16, 0.6, -0.12), Vector3(0.24, 0.84, -0.16), 0.05),
		_crystal(Vector3(-0.2, 0.6, -0.16), Vector3(-0.3, 0.8, -0.22), 0.04),
		_crystal(Vector3(0.02, 0.6, -0.06), Vector3(0.05, 0.9, -0.12), 0.06),
		_crystal(Vector3(0.33, 0.6, -0.04), Vector3(0.43, 0.77, 0.0), 0.04),
		_crystal(Vector3(-0.36, 0.6, -0.02), Vector3(-0.44, 0.76, 0.04), 0.035),
		_gem(Vector3(0.24, 0.67, 0.1), 0.05, "accent"),
		_gem(Vector3(-0.06, 0.68, 0.14), 0.045, "accent"),
		_gem(Vector3(0.1, 0.69, -0.2), 0.04, "accent"),
		_gem(Vector3(-0.3, 0.67, 0.08), 0.04, "accent"),
		_coin(Vector3(-0.25, 0.62, 0.22), Vector3(0.2, 1, 0.3), 0.07, "accent", 0.022),
		_coin(Vector3(0.38, 0.63, 0.14), Vector3(-0.2, 1, 0.2), 0.065, "accent", 0.022),
		_coin(Vector3(-0.12, 0.64, -0.2), Vector3(0.3, 1, 0.0), 0.06, "accent", 0.022),
		_coin(Vector3(0.45, 0.012, 0.6), Vector3.UP, 0.075, "accent", 0.022),
		_coin(Vector3(-0.55, 0.012, 0.7), Vector3.UP, 0.075, "body", 0.022),
		_coin(Vector3(0.66, 0.012, 0.2), Vector3.UP, 0.07, "body", 0.022),
		_coin(Vector3(-0.7, 0.012, 0.0), Vector3.UP, 0.07, "accent", 0.022),
		_rock(Vector3(0.2, 0.05, 0.62), Vector3(0.06, 0.05, 0.06), "accent", 0.3, 211),
		_crystal(Vector3(-0.62, 0.0, 0.42), Vector3(-0.72, 0.2, 0.5), 0.05)]
	## Gold studs down the bands, front and back.
	for x in [-0.3, 0.3]:
		for y in [0.12, 0.32, 0.52]:
			for z in [-1.0, 1.0]:
				r.append(_eye(Vector3(x, y, z * 0.365), 0.022))
	## The `tongue`: one smooth curve of overlapping stones, out of the mouth over the lip on the
	## left, down the front and along the floor, the tip curling up; each stone hung from its
	## own root so it can unroll.
	var tongue: Array = _spline([Vector3(0, 0.62, -0.08), Vector3(-0.08, 0.72, 0.14), Vector3(-0.16, 0.8, 0.32), Vector3(-0.19, 0.62, 0.46), Vector3(-0.2, 0.32, 0.48), Vector3(-0.22, 0.09, 0.6), Vector3(-0.17, 0.06, 0.84), Vector3(-0.06, 0.12, 1.02)], 18)
	_run(r, tongue, 0.105, 0.06, "core", 218, 0.06, {"name": "tongue", "motion": "core", "phase": 0.6}, true)
	var xs: Array = []
	for k in range(7):
		xs.append(-0.39 + 0.13 * float(k))
	_mimic_lid(Vector3(0, 0.6, -0.34), 105.0, Vector3(1.02, 0.14, 0.68), r, xs, 0.04, 0.17)
	for x in xs:
		r.append(_cone(Vector3(x, 0.6, 0.29), Vector3(x, 0.77, 0.29), 0.04, "accent"))
	## Four stubby iron feet, each a `leg` hung from where it meets the chest.
	for side in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var hip := Vector3(side * 0.38, 0.1, z * 0.26)
			r.append(_cone(hip, Vector3(side * 0.5, 0.0, z * 0.42), 0.05, "iron", {"name": "leg", "joint": _v(hip)}))
	r.append(_mouth_mark(Vector3(0, 0.7, 0.1)))
	return {"style": "low", "sway": 1.4, "tint": tint, "accent": accent, "anchor": 1.55, "shadow": 2.2, "ring": 1.1, "seed": "HOARD_MIMIC_R", "parts": r}

## ---- Crystal Hydra ------------------------------------------------------------------------

## A head that is a crystal grown teeth: the skull a big hex crystal whose point is the snout,
## a knuckle of stone where it meets the neck, a lower jaw of crystal dropped open on a glowing
## throat, gold gem eyes and two gold horns swept back. The `head` hangs from the top of its
## neck (`base`) and the `jaw` from its own root, both swaying as one on the still neck; its
## `mouth` marker goes in `marks`, to be laid after every other part.
static func _crystal_head(out: Array, marks: Array, base: Vector3, f: Vector3, k: float, phase: float, seed: int) -> void:
	var fwd := f.normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	var up := fwd.cross(right).normalized()
	var hinge: Vector3 = base - up * 0.1 * k - fwd * 0.04 * k
	var head := {"name": "head", "joint": _v(base), "motion": "swing", "phase": phase}
	var jaw := {"name": "jaw", "joint": _v(hinge), "motion": "swing", "phase": phase}
	out.append_array([
		_crystal(base - fwd * 0.12 * k, base + fwd * 0.56 * k, 0.15 * k, "body", head.duplicate(), 6),
		_rock(base - fwd * 0.04 * k, 0.17 * k, "body", 0.1, seed, head.duplicate()),
		_crystal(hinge, base + fwd * 0.42 * k - up * 0.25 * k, 0.085 * k, "body", jaw.duplicate(), 5),
		_eye(base + fwd * 0.14 * k - up * 0.11 * k, 0.06 * k, "core", head.duplicate()),
		_eye(base + fwd * 0.08 * k + up * 0.1 * k + right * 0.12 * k, 0.05 * k, "accent", head.duplicate()),
		_eye(base + fwd * 0.08 * k + up * 0.1 * k - right * 0.12 * k, 0.05 * k, "accent", head.duplicate()),
		_crystal(base + up * 0.1 * k + right * 0.07 * k - fwd * 0.04 * k, base + up * 0.36 * k + right * 0.16 * k - fwd * 0.3 * k, 0.04 * k, "accent", head.duplicate(), 6),
		_crystal(base + up * 0.1 * k - right * 0.07 * k - fwd * 0.04 * k, base + up * 0.36 * k - right * 0.16 * k - fwd * 0.3 * k, 0.04 * k, "accent", head.duplicate(), 6)])
	marks.append(_mouth_mark(base + fwd * 0.42 * k - up * 0.12 * k, head.duplicate()))

## A neck of hex crystal columns stepping from the root through two bends to the head, each a
## little thinner and overlapping the next: a `neck` hung from its root, still while the head
## on it sways.
static func _crystal_neck(out: Array, pts: Array, r: float, phase: float) -> void:
	var pieces: Array = []
	for i in range(pts.size() - 1):
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var dir: Vector3 = (p1 - p0).normalized()
		pieces.append(_column(p0 - dir * 0.03, p1 + dir * 0.05, r * (1.0 - 0.14 * float(i)), "body", {}, 6))
	out.append_array(_hang(pieces, pts[0], "static", phase, "neck"))

## Crystals growing out of a rock: each spec is [direction, length, radius, material]; the root
## sits just inside the rock's skin along that direction.
static func _crust(out: Array, centre: Vector3, size: Vector3, specs: Array) -> void:
	for spec in specs:
		var dir: Vector3 = (spec[0] as Vector3).normalized()
		var root: Vector3 = centre + dir * size * 0.78
		out.append(_crystal(root, root + dir * float(spec[1]), float(spec[2]), str(spec[3]), {"phase": root.x * 5.0}, 6))

## The Crystal Hydra: a great crystal-crusted boulder cracked open on a glowing seam, three
## heads that are big hex crystals grown jaws, on stepped crystal necks: one low and reaching,
## one tall, one reared back looking aside. (r3a CRYSTAL_HYDRA_A)
static func _crystal_hydra() -> Dictionary:
	var tint := "8a5ad8"
	var accent := "ffd76a"
	var body_a := Vector3(0, 0.46, -0.05)
	var size_a := Vector3(0.82, 0.5, 0.74)
	var a: Array = [
		_rock(body_a, size_a, "body", 0.16, 301, {"motion": "core", "name": "body"}),
		_rock(Vector3(0, 0.36, 0.5), Vector3(0.34, 0.2, 0.14), "core", 0.1, 302, {"motion": "core", "phase": 0.7})]
	_crust(a, body_a, size_a, [
		[Vector3(0.9, 0.3, 0.3), 0.46, 0.1, "body"], [Vector3(-0.85, 0.4, 0.2), 0.52, 0.11, "body"],
		[Vector3(0.5, 0.5, -0.7), 0.56, 0.12, "body"], [Vector3(-0.4, 0.6, -0.7), 0.5, 0.1, "accent"],
		[Vector3(0.3, 0.15, 0.95), 0.3, 0.07, "accent"], [Vector3(-0.6, 0.1, 0.75), 0.32, 0.08, "body"],
		[Vector3(0.75, 0.05, -0.6), 0.36, 0.08, "accent"], [Vector3(0, 0.7, -0.7), 0.62, 0.13, "body"]])
	## The heads fan front to back as well as side to side: a low one reaching for the party,
	## the tall one in the middle, one reared back and looking aside. [neck points, facing].
	var necks_a: Array = [
		[[Vector3(-0.26, 0.82, 0.2), Vector3(-0.48, 1.04, 0.36), Vector3(-0.56, 1.24, 0.58), Vector3(-0.48, 1.34, 0.8)], Vector3(0.15, -0.3, 1)],
		[[Vector3(0, 0.9, 0.04), Vector3(0.03, 1.32, 0.0), Vector3(0.0, 1.72, 0.06), Vector3(0, 1.92, 0.26)], Vector3(0, -0.2, 1)],
		[[Vector3(0.2, 0.84, -0.12), Vector3(0.32, 1.14, -0.38), Vector3(0.3, 1.46, -0.56), Vector3(0.18, 1.64, -0.6)], Vector3(-1, -0.2, 0.3)]]
	var marks: Array = []
	for i in range(3):
		_crystal_neck(a, necks_a[i][0], 0.14, float(i) * 1.3)
		_crystal_head(a, marks, necks_a[i][0][3], necks_a[i][1], 1.15, float(i) * 1.3, 310 + i)
	a.append_array(marks)
	return {"style": "stack", "sway": 1.2, "tint": tint, "accent": accent, "anchor": 2.35, "shadow": 2.8, "ring": 1.4, "seed": "CRYSTAL_HYDRA_A", "parts": a}

## ---- The Assayer (Warden) -----------------------------------------------------------------

## A brilliant-cut gem, girdle centre at `girdle`, table up `axis`: a hex pavilion running to a
## point, (an optional straight hex waist,) a hex crown up to a flat table, and bright edges
## down every facet ridge and round the girdle so it reads as a cut stone.
static func _brilliant(out: Array, girdle: Vector3, axis: Vector3, r: float, crown_h: float, pav_h: float, table_k: float, body: String, edge: String, extra: Dictionary = {}, roll_deg: float = 0.0, waist: float = 0.0, crown_mat: String = "") -> void:
	var a: Vector3 = axis.normalized()
	var basis: Basis = _aimed(a)
	var spin := {"mesh_rot": [0, roll_deg, 0]}
	var top: Vector3 = girdle + a * waist
	var point: Vector3 = girdle - a * pav_h
	var table: Vector3 = top + a * crown_h
	out.append(_merged(_merged(_cone(girdle, point, r, body, {}, 6), spin.duplicate()), extra.duplicate()))
	if waist > 0.0:
		out.append(_merged(_merged(_rod(girdle, top, r, r, body), spin.duplicate()), extra.duplicate()))
	out.append(_merged(_merged(_rod(top, table, r, r * table_k, body if crown_mat == "" else crown_mat), spin.duplicate()), extra.duplicate()))
	out.append(_merged(_merged(_disc(table + a * 0.004, a, r * table_k * 0.99, 0.014, edge), spin.duplicate()), extra.duplicate()))
	var th: float = clampf(r * 0.06, 0.012, 0.05)
	var corners: Array = []
	for k in range(6):
		var ang: float = TAU * float(k) / 6.0 + deg_to_rad(roll_deg)
		corners.append(basis.x * sin(ang) + basis.z * cos(ang))
	for k in range(6):
		var c: Vector3 = corners[k]
		var c2: Vector3 = corners[(k + 1) % 6]
		out.append(_merged(_bar(girdle + c * r, point, th, edge), extra.duplicate()))
		out.append(_merged(_bar(top + c * r, table + c * r * table_k, th, edge), extra.duplicate()))
		out.append(_merged(_bar(girdle + c * r * 1.005, girdle + c2 * r * 1.005, th * 1.2, edge), extra.duplicate()))
		if waist > 0.0:
			out.append(_merged(_bar(girdle + c * r, top + c * r, th, edge), extra.duplicate()))

## A hex pan hung on three gold chains from the end of a beam, with what it weighs in it: a
## pan (`name`) hung from the beam's own pivot `joint`, so it rocks with the beam.
static func _balance(out: Array, end: Vector3, drop: float, pan_r: float, joint: Vector3, phase: float, load: Array, name: String) -> void:
	var pan := end + Vector3(0, -drop, 0)
	var pieces: Array = [
		_rod(end, pan + Vector3(-pan_r * 0.75, 0.04, 0.0), 0.016, 0.016, "accent", {}, 4),
		_rod(end, pan + Vector3(pan_r * 0.75, 0.04, 0.0), 0.016, 0.016, "accent", {}, 4),
		_rod(end, pan + Vector3(0, 0.04, -pan_r * 0.75), 0.016, 0.016, "accent", {}, 4),
		_drum(pan, pan_r * 0.78, pan_r, 0.06, "accent")]
	pieces.append_array(load)
	out.append_array(_hang(pieces, joint, "swing", phase, name))

## A heap of gold nuggets and a gold crystal: what the judge has on the scales.
static func _gold_load(at: Vector3, seed: int) -> Array:
	return [
		_rock(at + Vector3(-0.07, 0.07, 0.04), 0.09, "accent", 0.3, seed),
		_rock(at + Vector3(0.08, 0.06, -0.04), 0.08, "accent", 0.3, seed + 1),
		_rock(at + Vector3(0.0, 0.06, 0.09), 0.07, "accent", 0.3, seed + 2),
		_crystal(at + Vector3(0.0, 0.05, -0.02), at + Vector3(0.05, 0.36, -0.04), 0.05, "accent", {"motion": "static"})]

## The party's die, weighed: a dark cube with gold pips.
static func _die_load(at: Vector3) -> Array:
	return [
		_box(at + Vector3(0, 0.1, 0), Vector3(0.18, 0.18, 0.18), "body", {"rot": [0, 25, 0]}),
		_eye(at + Vector3(0.0, 0.195, 0.0), 0.025),
		_eye(at + Vector3(0.05, 0.195, 0.03), 0.022),
		_eye(at + Vector3(-0.05, 0.195, -0.03), 0.022)]

## The balance: a gold beam (`scales`) rocking on `pivot`; gold in the pan on the judge's own
## left (`pan_l`, +x), the party's die in the one on its right (`pan_r`).
static func _scales(out: Array, pivot: Vector3, half: float, drop: float, pan_r: float, seed: int) -> void:
	out.append_array(_hang([
		_box(pivot, Vector3(half * 2.0 + 0.1, 0.07, 0.07), "accent"),
		_glow_gem(pivot, 0.09, "accent", {"motion": "static"}),
		_cone(pivot + Vector3(half, 0, 0), pivot + Vector3(half + 0.14, 0, 0), 0.05, "accent", {}, 4),
		_cone(pivot - Vector3(half, 0, 0), pivot - Vector3(half + 0.14, 0, 0), 0.05, "accent", {}, 4)], pivot, "swing", 0.0, "scales"))
	_balance(out, pivot + Vector3(half, 0, 0), drop, pan_r, pivot, 0.0, _gold_load(pivot + Vector3(half, -drop + 0.03, 0), seed), "pan_l")
	_balance(out, pivot + Vector3(-half, 0, 0), drop, pan_r, pivot, 0.0, _die_load(pivot + Vector3(-half, -drop + 0.02, 0)), "pan_r")

## A horn of hex rods along `path`, a cut knuckle at every bend, a point at its end.
static func _horn(out: Array, path: Array, radii: Array, material: String = "accent", extra: Dictionary = {}) -> void:
	var n: int = path.size()
	for i in range(n - 1):
		out.append(_rod(path[i], path[i + 1], float(radii[i]), float(radii[i + 1]), material, extra.duplicate()))
		if i > 0:
			out.append(_eye(path[i], float(radii[i]) * 1.05, material, extra.duplicate()))
	var last: Vector3 = path[n - 1]
	var prev: Vector3 = path[n - 2]
	out.append(_cone(last, last + (last - prev).normalized() * float(radii[n - 1]) * 5.0, float(radii[n - 1]), material, extra.duplicate(), 6))

## The Assayer (Warden): a floating obsidian brilliant edged in gold, one gold eye on the front
## of its crown and a gold tear down the pavilion, gold horns off the girdle, a halo of gold
## coins turning above, the scales hanging from its point. (r4 THE_ASSAYER_C)
static func _assayer() -> Dictionary:
	var tint := "2c2238"
	var accent := "ffd76a"
	var gc := Vector3(0, 2.05, 0)
	## The stone and everything set in it turn a little about its axis as one `body` (the batch
	## left it still, but the first part must move); the `eye` (gem and pupil) hangs from its
	## own middle so it can roll or blink, and keeps its pulse.
	var body := {"name": "body", "joint": _v(gc), "motion": "block", "phase": 0.0}
	var eye_at: Vector3 = gc + Vector3(0, 0.17, 0.58)
	var c: Array = []
	_brilliant(c, gc, Vector3.UP, 0.82, 0.36, 0.95, 0.56, "body", "accent", body, 30.0)
	c.append(_glow_gem(eye_at, Vector3(0.2, 0.17, 0.12), "accent", {"name": "eye", "joint": _v(eye_at)}))
	c.append(_box(gc + Vector3(0, 0.17, 0.7), Vector3(0.06, 0.26, 0.03), "iron", {"rot": [-30, 0, 0], "name": "eye", "joint": _v(eye_at)}))
	c.append(_slab(gc + Vector3(0, 0.38, 0.52), Vector3(0.5, 0.06, 0.12), "accent", _merged({"rot": [-38, 0, 0]}, body.duplicate())))
	c.append(_bar(gc + Vector3(0, -0.02, 0.73), gc + Vector3(0, -0.6, 0.32), 0.05, "accent", body.duplicate()))
	for side in [-1.0, 1.0]:
		_horn(c, [gc + Vector3(side * 0.74, 0.04, 0), gc + Vector3(side * 1.14, 0.36, -0.06), gc + Vector3(side * 1.3, 0.86, -0.14), gc + Vector3(side * 1.12, 1.28, -0.22)], [0.14, 0.11, 0.08, 0.05], "accent", body)
	## The `halo`: a gold ring and nine coins wheeling over the table as one.
	var halo := gc + Vector3(0, 0.95, 0)
	var wheel := {"name": "halo", "joint": _v(halo), "motion": "orbit", "phase": 0.0}
	c.append(_hoop(halo, Vector3.UP, 0.62, 0.05, "accent", wheel.duplicate()))
	for i in range(9):
		var ang: float = TAU * float(i) / 9.0
		var d := Vector3(sin(ang), 0, cos(ang))
		c.append(_disc(halo + d * 0.66, d, 0.11, 0.03, "accent", wheel.duplicate()))
	var point: Vector3 = gc - Vector3(0, 0.95, 0)
	c.append(_rod(point, point + Vector3(0, -0.2, 0), 0.025, 0.025, "accent", {}, 4))
	_scales(c, point + Vector3(0, -0.22, 0), 1.2, 0.46, 0.27, 2460)
	for i in range(4):
		var ang: float = TAU * float(i) / 4.0 + 0.4
		c.append(_shard(Vector3(sin(ang) * 1.55, 1.8 + 0.4 * float(i % 2), cos(ang) * 1.55), [float(i) * 40.0, float(i) * 70.0, 20.0], 1.0, "iron", {"motion": "orbit", "phase": ang}))
	## It hangs turned a little to the party's right, so its face and the beam of its scales
	## read from the front and from the near side alike.
	_turned(c, Vector3.ZERO, Basis(Vector3.UP, deg_to_rad(-25.0)))
	return {"style": "wings", "sway": 0.5, "tint": tint, "accent": accent, "anchor": 3.5, "warden": true, "shadow": 2.6, "ring": 1.5, "seed": "THE_ASSAYER_C", "parts": c}

## ---- The Collector (Warden) ---------------------------------------------------------------

## A snail's body: a foot of cut stones running back from the head (the `body`, rippling: the
## batch left it still, but the first part must move), a flat sole, the `head` with two short
## feelers, and gold gem eyes on tall jointed stalks, each an `eye` swaying from its root.
static func _snail(out: Array, head: Vector3, seed: int) -> void:
	_rocks(out, [Vector3(0, 0.14, -1.2), Vector3(0, 0.2, -0.5), Vector3(0, 0.24, 0.3), Vector3(0, 0.4, 0.95), head], [0.16, 0.36, 0.42, 0.33, 0.26], "body", seed, {"name": "body", "motion": "core"}, 0.08, 0.72, 2)
	out.append(_rock(Vector3(0, 0.05, -0.1), Vector3(0.52, 0.06, 1.3), "body", 0.1, seed + 20))
	var hd := {"name": "head", "joint": _v(head + Vector3(0, -0.12, -0.14))}
	out.append(_rock(head + Vector3(0, 0.02, 0.06), Vector3(0.28, 0.24, 0.27), "body", 0.08, seed + 21, hd.duplicate()))
	out.append(_slab(head + Vector3(0, -0.13, 0.22), Vector3(0.2, 0.05, 0.08), "iron", hd.duplicate()))
	for side in [-1.0, 1.0]:
		var base: Vector3 = head + Vector3(side * 0.12, 0.17, 0.08)
		var knee: Vector3 = head + Vector3(side * 0.24, 0.6, 0.12)
		var top: Vector3 = head + Vector3(side * 0.34, 0.98, 0.24)
		out.append_array(_hang([
			_rod(base, knee, 0.055, 0.045, "body", {}, 5), _rod(knee, top, 0.045, 0.035, "body", {}, 5),
			_eye(top + Vector3(0, 0.07, 0.02), 0.09)], base, "swing", 0.3 if side > 0.0 else 1.9, "eye"))
		out.append(_cone(head + Vector3(side * 0.13, -0.06, 0.2), head + Vector3(side * 0.24, -0.24, 0.46), 0.05, "body", hd.duplicate()))

## The collector's `cane`, held out on its side of the head by a short arm: dark iron with a
## gold crook, a gold gem for its knob, a gold ferrule tapping the floor; it swings from the
## crook.
static func _cane(out: Array, head: Vector3, side: float, phase: float) -> void:
	var top: Vector3 = head + Vector3(side * 0.44, 0.12, 0.26)
	var tip := Vector3(side * 0.62, 0.02, head.z + 0.62)
	var d: Vector3 = (top - tip).normalized()
	out.append_array(_hang([
		_rod(tip, top, 0.03, 0.035, "iron", {}, 5),
		_rod(top, top + Vector3(0, 0.08, 0.16), 0.04, 0.035, "accent", {}, 5),
		_glow_gem(top, 0.075, "accent", {"motion": "static"}),
		_cone(tip + d * 0.08, tip, 0.04, "accent"),
		_rod(head + Vector3(side * 0.14, -0.1, 0.18), head + Vector3(side * 0.44, 0.02, 0.3), 0.05, 0.035, "body", {}, 5)], top, "swing", phase, "cane"))

## The centre line of a shell's tube `n` turns back from its mouth: a logarithmic spiral
## (shrinking by `W` every turn) rising `rise` along its axis toward the apex.
static func _coil(n: float, o: Dictionary) -> Vector3:
	var g: float = pow(float(o["W"]), -n)
	var ang: float = float(o["end"]) - float(o["hand"]) * n * TAU
	var axis: Vector3 = o["axis"]
	var ref: Vector3 = o["ref"]
	var side: Vector3 = axis.cross(ref)
	return (o["centre"] as Vector3) + axis * float(o["rise"]) * (1.0 - g) + (ref * cos(ang) + side * sin(ang)) * float(o["R"]) * g

## A shell wound as one tube of hex drums, each one a fixed step round the spiral and sized
## smoothly from the apex to the mouth, rolled so their facets line up from drum to drum.
## Returns where every drum lies, for trim and cases.
static func _shell(out: Array, o: Dictionary) -> Array:
	var per: int = int(o["per"])
	var total: int = int(round(float(o["turns"]) * float(per)))
	var axis: Vector3 = o["axis"]
	var centre: Vector3 = o["centre"]
	var flat: float = float(o.get("flat", 1.0))
	var roll: float = float(o.get("roll", 0.0))
	var samples: Array = []
	for i in range(total):
		var n0: float = float(i) / float(per)
		var n1: float = float(i + 1) / float(per)
		var p0: Vector3 = _coil(n0, o)
		var p1: Vector3 = _coil(n1, o)
		var r0: float = float(o["s"]) * float(o["R"]) * pow(float(o["W"]), -n0)
		var r1: float = float(o["s"]) * float(o["R"]) * pow(float(o["W"]), -n1)
		var t: Vector3 = (p0 - p1).normalized()
		var mid: Vector3 = (p0 + p1) * 0.5
		var rm: float = (r0 + r1) * 0.5
		var chord: float = p0.distance_to(p1)
		var x: Vector3 = (axis - t * axis.dot(t)).normalized()
		var length: float = chord + rm * tan(PI / float(per)) * float(o.get("reach", 1.2))
		out.append({"shape": "cylinder", "at": _v(mid), "rot": _frame(x, t), "mesh_rot": [0, roll, 0], "scale": [flat, 1.0, 1.0], "material": str(o.get("mat", "body")), "bottom": r1, "top": r0, "height": length, "sides": 6})
		var on_axis: Vector3 = centre + axis * axis.dot(mid - centre)
		var radial: Vector3 = mid - on_axis
		radial = (radial - t * radial.dot(t) - x * radial.dot(x)).normalized()
		samples.append({"p": mid, "t": t, "r": rm, "x": x, "out": radial, "len": chord, "n": n0, "flat": flat, "a": p0, "b": p1, "ra": r0, "rb": r1, "c": centre, "axis": axis})
	return samples

## A point on a drum's cross-section: `ax` along the coil's axis, `rad` out from it.
static func _on_tube(s: Dictionary, ax: float, rad: float) -> Vector3:
	return (s["p"] as Vector3) + (s["x"] as Vector3) * ax * float(s["r"]) * float(s["flat"]) + (s["out"] as Vector3) * rad * float(s["r"])

## A gold line laid along one ridge of the tube, every `every` drums one straight bar.
static func _suture(out: Array, samples: Array, ax: float, rad: float, upto: float, every: int = 2, material: String = "accent", lift: float = 1.04) -> void:
	var i: int = 0
	while i + every <= samples.size():
		var s0: Dictionary = samples[i]
		var s1: Dictionary = samples[i + every - 1]
		if float(s0["n"]) > upto:
			break
		var a: Dictionary = _at_end(s0, s0["a"], float(s0["ra"]))
		var b: Dictionary = _at_end(s1, s1["b"], float(s1["rb"]))
		var pa: Vector3 = _on_tube(a, ax * lift, rad * lift)
		var pb: Vector3 = _on_tube(b, ax * lift, rad * lift)
		var th: float = clampf(float(s0["r"]) * 0.13, 0.02, 0.05)
		out.append(_merged({"shape": "box", "at": _v((pa + pb) * 0.5), "rot": _frame(s0["x"], pb - pa), "material": material, "size": [th, pa.distance_to(pb) * 1.04, th]}, {}))
		i += every

## A drum's frame moved to one of its ends, turned to face out from the axis there, so a line
## laid from end to end along a ridge meets the next one with no gap.
static func _at_end(s: Dictionary, p: Vector3, r: float) -> Dictionary:
	var e: Dictionary = s.duplicate()
	var axis: Vector3 = s["axis"]
	var x: Vector3 = s["x"]
	var radial: Vector3 = p - ((s["c"] as Vector3) + axis * axis.dot(p - (s["c"] as Vector3)))
	radial = (radial - x * radial.dot(x)).normalized()
	e["p"] = p
	e["out"] = radial
	e["r"] = r
	return e

## A case set flush in a face of the tube whose normal is (`ax`, `rad`) in its cross-section: a
## gold frame round a lit pane with a gem on show (a `case`), or an iron `drawer` with a gold
## knob; each hung from the middle of its face.
static func _case(out: Array, s: Dictionary, ax: float, rad: float, glass: bool, phase: float) -> void:
	var normal: Vector3 = ((s["x"] as Vector3) * ax + (s["out"] as Vector3) * rad).normalized()
	var face: Vector3 = _on_tube(s, ax * 0.866, rad * 0.866)
	var across: Vector3 = (s["t"] as Vector3).cross(normal).normalized()
	var r: float = float(s["r"])
	var along: float = float(s["len"]) * 0.82
	var rot: Array = _frame(across, s["t"])
	var role := {"name": "case" if glass else "drawer", "joint": _v(face)}
	if glass:
		out.append(_box(face + normal * 0.01, Vector3(r * 0.86, along, 0.03), "accent", _merged({"rot": rot}, role.duplicate())))
		out.append(_box(face + normal * 0.025, Vector3(r * 0.66, along * 0.74, 0.03), "core", _merged({"rot": rot, "motion": "core", "phase": phase}, role.duplicate())))
		out.append(_glow_gem(face + normal * (0.04 + r * 0.06), r * 0.16, "accent", _merged({"phase": phase}, role.duplicate())))
	else:
		out.append(_box(face + normal * 0.015, Vector3(r * 0.74, along * 0.8, 0.05), "iron", _merged({"rot": rot}, role.duplicate())))
		out.append(_eye(face + normal * 0.06, maxf(r * 0.08, 0.035), "accent", role.duplicate()))

## A gold lip round the shell's mouth with a soft glow inside it.
static func _shell_mouth(out: Array, samples: Array) -> void:
	var s: Dictionary = samples[0]
	var at: Vector3 = s["a"]
	var t: Vector3 = s["t"]
	var r: float = float(s["r"]) * 1.08
	out.append(_hoop(at + t * 0.02, t, r * 0.98, 0.09, "accent"))
	out.append(_disc(at, t, r * 0.82, 0.04, "core"))

## The Collector (Warden): a snail under a tall open cone spiral of a shell, a corkscrew of hex
## segments with a gold keel line winding round a glowing column up to a gold crystal tip, lit
## cases climbing the lower whorls, an iron drawer by the mouth, a cane in hand.
## (r4 THE_COLLECTOR_B)
static func _collector() -> Dictionary:
	var tint := "6a3a8a"
	var accent := "ffd76a"
	var head := Vector3(0, 0.82, 1.34)
	var b: Array = []
	_snail(b, head, 3600)
	var axis_b := Vector3(0, 0.97, -0.22).normalized()
	var ref_b: Vector3 = (Vector3(0, 0.3, 1) - axis_b * axis_b.dot(Vector3(0, 0.3, 1))).normalized()
	var base_b := Vector3(0, 0.62, -0.4)
	var ob := {"centre": base_b, "axis": axis_b, "ref": ref_b, "end": 0.0, "hand": 1.0, "R": 0.62, "W": 1.36, "s": 0.46, "rise": 3.3, "turns": 3.1, "per": 14, "flat": 1.0, "seed": 3610}
	## The coil and its gold line are the `shell`, hung from where it sits on the foot.
	var shell_from: int = b.size()
	var sb: Array = _shell(b, ob)
	_suture(b, sb, 0.0, 1.0, 3.0, 1, "accent", 1.06)
	_name_since(b, shell_from, "shell", base_b)
	var apex_b: Vector3 = _coil(3.1, ob)
	## The columella the coil winds round, lit from inside like a lamp in a display case, and
	## the gold crystal `tip` on the apex.
	b.append(_cone(base_b - axis_b * 0.1, apex_b + axis_b * 0.1, 0.27, "core", {"motion": "core", "name": "column"}, 6))
	b.append(_crystal(apex_b - axis_b * 0.05, apex_b + axis_b * 0.46, 0.08, "accent", {"name": "tip"}))
	_case(b, sb[4], 0.5, 0.866, true, 0.0)
	_case(b, sb[12], 0.5, 0.866, true, 1.2)
	_case(b, sb[19], 0.5, 0.866, true, 2.4)
	_case(b, sb[8], -0.5, 0.866, false, 0.0)
	var mouth_from: int = b.size()
	_shell_mouth(b, sb)
	_name_since(b, mouth_from, "shell", base_b)
	_cane(b, head, -1.0, 1.2)
	return {"style": "low", "sway": 0.6, "tint": tint, "accent": accent, "anchor": 3.4, "warden": true, "shadow": 3.2, "ring": 1.6, "seed": "THE_COLLECTOR_B", "parts": b}

## ---- The Hollow Crown (boss) --------------------------------------------------------------

## An eight-sided band, a crystal point at every corner (tall and short by turns), and a lit
## jewel on every face between them.
static func _crown(out: Array, centre: Vector3, r: float, points: String, extra: Dictionary = {}, band: String = "accent", jewels: String = "core", tall: float = 1.0, odd: String = "body") -> void:
	var k: float = r / 1.035
	for piece in _band(centre, Vector3.UP, r, 0.23 * k, 0.22 * k, band, 8, PI / 8.0):
		out.append(_merged(piece, extra.duplicate()))
	for i in range(8):
		var ang: float = TAU * float(i) / 8.0
		var mat: String = "accent" if points == "all" else (points if i % 2 == 0 else odd)
		var base := centre + Vector3(cos(ang) * r * 0.97, 0.05 * k, sin(ang) * r * 0.97)
		var tip := centre + Vector3(cos(ang) * r * 1.12, (1.2 if i % 2 == 0 else 0.9) * k * tall, sin(ang) * r * 1.12)
		out.append(_merged(_stick("crystal", base, tip, 0.13 * k, mat), extra.duplicate()))
		var between: float = ang + PI / 8.0
		out.append(_merged(_eye(centre + Vector3(cos(between) * r * 1.13, 0.0, sin(between) * r * 1.13), 0.1 * k, jewels), extra.duplicate()))

## The inside of a split geode: a dark hollow facing `normal`, lined with amethyst crystals (and
## a gold one every third) all pointing out of it, a jagged lip of stone round it.
static func _geode_face(out: Array, centre: Vector3, normal: Vector3, radius: float, count: int, length: float, extra: Dictionary = {}, lip: int = 9) -> void:
	var f: Vector3 = normal.normalized()
	var u: Vector3 = Vector3.UP.cross(f) if absf(f.y) < 0.9 else Vector3.RIGHT.cross(f)
	u = u.normalized()
	var w: Vector3 = f.cross(u).normalized()
	out.append(_merged({"shape": "cylinder", "at": _v(centre - f * 0.03), "aim": _v(f), "material": "iron", "top": radius * 1.02, "bottom": radius * 1.02, "height": 0.06, "sides": 6}, extra.duplicate()))
	var golden: float = PI * (3.0 - sqrt(5.0))
	for i in range(count):
		var t: float = sqrt((float(i) + 0.5) / float(count))
		var ang: float = golden * float(i)
		var radial: Vector3 = u * cos(ang) + w * sin(ang)
		var root: Vector3 = centre + radial * radius * 0.92 * t
		var dir: Vector3 = (f + radial * t * 0.7).normalized()
		var h: float = length * (1.0 - 0.45 * t)
		out.append(_merged(_stick("crystal", root - f * 0.02, root + dir * h, h * 0.22, "accent" if i % 3 == 0 else "core"), extra.duplicate()))
	for i in range(lip):
		var ang: float = TAU * float(i) / float(lip) + 0.2
		var radial: Vector3 = u * cos(ang) + w * sin(ang)
		var s: float = radius * (0.22 + 0.06 * float(i % 3))
		out.append(_merged(_rock(centre + radial * radius * 1.02 + f * 0.02, Vector3(s, s * 0.8, s), "body", 0.2, 700 + i), extra.duplicate()))

## A gilded magpie in its own frame, looking down +z, its gold wings raised `lift`: the `bird`
## hung from its feet so it can peck, each wing hung along its root so it can flutter
## (`bird_wing_l` on the bird's own left, +x, and `bird_wing_r`).
static func _magpie(lift: float = 0.2) -> Array:
	var bird := {"name": "bird", "joint": [0.0, -0.1, 0.0]}
	var p: Array = [
		_rock(Vector3(0, 0, 0), Vector3(0.13, 0.11, 0.22), "iron", 0.08, 721, bird.duplicate()),
		_rock(Vector3(0, 0.1, 0.19), Vector3(0.09, 0.09, 0.09), "iron", 0.08, 722, bird.duplicate()),
		_stick("cone", Vector3(0, 0.09, 0.25), Vector3(0, 0.07, 0.4), 0.03, "accent", bird.duplicate()),
		_eye(Vector3(0.05, 0.13, 0.24), 0.022, "accent", bird.duplicate()), _eye(Vector3(-0.05, 0.13, 0.24), 0.022, "accent", bird.duplicate()),
		_tri(Vector3(0, 0.02, -0.55), Vector3(-0.08, 0.04, -0.12), Vector3(0.08, 0.04, -0.12), "accent", bird.duplicate(), 0.03)]
	for side in [-1.0, 1.0]:
		var wing := {"name": "bird_wing_l" if side > 0.0 else "bird_wing_r", "joint": [side * 0.06, 0.06, -0.02]}
		p.append(_tri(Vector3(side * 0.42, lift, -0.14), Vector3(side * 0.06, 0.06, 0.12), Vector3(side * 0.06, 0.06, -0.16), "accent", wing, 0.03))
	return p

## Four crystals bursting up off a shoulder.
static func _shoulder_crystals(out: Array, sh: Vector3, side: float, reach: float = 1.0) -> void:
	for k in range(4):
		var d := Vector3(side * (0.3 + 0.25 * float(k)), 1.0, -0.3 + 0.25 * float(k % 2)).normalized()
		out.append(_stick("crystal", sh + d * 0.35, sh + d * (0.85 - 0.1 * float(k)) * reach, 0.1, "accent" if k == 1 else "core", {"motion": "crystal"}))

## Clusters of four crystals growing off the back: each spec is [root, direction, size].
static func _back_crystals(out: Array, specs: Array) -> void:
	for spec in specs:
		var root: Vector3 = spec[0]
		var d: Vector3 = (spec[1] as Vector3).normalized()
		var size: float = float(spec[2]) if spec.size() > 2 else 1.0
		for k in range(4):
			var spread := Vector3(cos(float(k) * 1.7), 0.3 * float(k % 2), sin(float(k) * 1.7)) * 0.35
			out.append(_stick("crystal", root, root + (d + spread).normalized() * (0.55 - 0.08 * float(k)) * size, (0.1 - 0.012 * float(k)) * size, "accent" if k == 2 else "core"))

## A great arm of stone: upper arm, forearm, a fist studded with gold, crystals at the elbow.
static func _arm(out: Array, shoulder: Vector3, el: Vector3, fist: Vector3, side: float, seed: int, studs_dir: Vector3, extra: Dictionary = {}) -> void:
	var pieces: Array = [
		_limb_stone(shoulder, el, 0.36, "body", 0.12, seed),
		_limb_stone(el, fist, 0.3, "body", 0.12, seed + 1),
		_rock(fist, Vector3(0.36, 0.3, 0.36), "body", 0.14, seed + 2),
		_stick("crystal", el + Vector3(side * 0.2, 0, -0.05), el + Vector3(side * 0.6, 0.25, -0.2), 0.08, "core"),
		_stick("crystal", el + Vector3(side * 0.18, -0.3, 0.05), el + Vector3(side * 0.5, -0.2, -0.1), 0.06, "core")]
	var sd: Vector3 = studs_dir.normalized()
	var across: Vector3 = sd.cross(Vector3.UP if absf(sd.y) < 0.9 else Vector3.BACK).normalized()
	for k in range(3):
		var base: Vector3 = fist + sd * 0.26 + across * (float(k) - 1.0) * 0.17
		pieces.append(_stick("crystal", base, base + sd * 0.24, 0.05, "accent"))
	out.append_array(_moving(pieces, extra))

## A leg of cut stones, thigh, shin and foot: a `leg` hung from the hip.
static func _stone_leg(out: Array, hip: Vector3, knee: Vector3, foot: Vector3, seed: int) -> void:
	var leg := {"name": "leg", "joint": _v(hip)}
	out.append(_limb_stone(hip, knee, 0.34, "body", 0.12, seed, leg.duplicate()))
	out.append(_limb_stone(knee, foot, 0.28, "body", 0.12, seed + 1, leg.duplicate()))
	out.append(_rock(foot + Vector3(0, 0, 0.15), Vector3(0.3, 0.14, 0.4), "body", 0.14, seed + 2, leg.duplicate()))

## The Hollow Crown (boss): the hunched geode giant knuckling on gold-studded fists, its chest
## split on amethyst round a glowing heart, its head raised clear of the shoulders on a thick
## neck under a bigger crown of alternating gold and amethyst points with a gem in front; gold
## teeth, a larger magpie on the near shoulder. (r4 THE_HOLLOW_CROWN_A)
static func _hollow_crown() -> Dictionary:
	var tint := "5a3a7a"
	var accent := "ffd76a"
	## The head (eyes and brow with it) nods on the top of the neck, the jaw of gold teeth drops
	## from its back, and the crown sits on the head (move it with the head).
	var head := {"name": "head", "joint": [0.0, 2.95, 0.66]}
	var jaw := {"name": "jaw", "joint": [0.0, 2.95, 0.74]}
	var crown := {"name": "crown", "joint": [0.0, 3.44, 0.8]}
	var a: Array = [
		## The torso breathes (the batch left it still, but the first part must move).
		_rock(Vector3(0, 1.8, -0.15), Vector3(1.2, 1.05, 1.0), "body", 0.14, 731, {"rot": [18, 0, 0], "name": "body", "motion": "core"}),
		_limb_stone(Vector3(0, 2.4, 0.2), Vector3(0, 2.95, 0.66), 0.36, "body", 0.1, 760, {"name": "neck", "joint": [0.0, 2.4, 0.2]}),
		_rock(Vector3(0, 3.12, 0.82), Vector3(0.5, 0.4, 0.44), "body", 0.1, 732, head.duplicate()),
		_rock(Vector3(0, 2.86, 1.02), Vector3(0.4, 0.18, 0.32), "body", 0.12, 733, jaw.duplicate()),
		_eye(Vector3(0.18, 3.16, 1.2), 0.085, "accent", head.duplicate()), _eye(Vector3(-0.18, 3.16, 1.2), 0.085, "accent", head.duplicate()),
		_merged({"shape": "slab", "at": [0, 3.28, 1.13], "rot": [-15, 0, 0], "material": "body", "size": [0.66, 0.1, 0.2], "jitter": 0.05}, head.duplicate())]
	for k in range(4):
		var x: float = (float(k) - 1.5) * 0.11
		a.append(_cone(Vector3(x, 2.88, 1.28), Vector3(x, 3.04, 1.32), 0.038, "accent", jaw.duplicate(), 4))
	_crown(a, Vector3(0, 3.44, 0.8), 0.52, "accent", crown, "accent", "core", 1.4, "core")
	## The gem set in the crown's brow rides with the crown, so it no longer pulses.
	a.append(_glow_gem(Vector3(0, 3.56, 1.34), 0.12, "core", _merged({"motion": "static"}, crown.duplicate())))
	_geode_face(a, Vector3(0, 1.8, 0.78), Vector3(0, 0.15, 1), 0.6, 13, 0.4)
	a.append(_glow_gem(Vector3(0, 1.82, 0.9), 0.3, "core", {"name": "heart"}))
	a.append(_eye(Vector3(0, 1.86, 1.16), 0.12, "accent", {"motion": "core", "name": "heart"}))
	for side in [-1.0, 1.0]:
		var sh := Vector3(side * 1.0, 2.38, 0.12)
		a.append(_rock(sh, Vector3(0.55, 0.48, 0.55), "body", 0.14, 734))
		_shoulder_crystals(a, sh, side)
		var shoulder := Vector3(side * 1.12, 2.2, 0.28)
		_arm(a, shoulder, Vector3(side * 1.48, 1.35, 0.6), Vector3(side * 1.35, 0.32, 1.0), side, 735, Vector3(0, 0.3, 1), {"name": "arm_l" if side > 0.0 else "arm_r", "joint": _v(shoulder)})
		_stone_leg(a, Vector3(side * 0.62, 1.1, -0.65), Vector3(side * 0.88, 0.6, -0.35), Vector3(side * 0.88, 0.12, -0.7), 738)
	_back_crystals(a, [[Vector3(0, 2.62, -0.6), Vector3(0, 1, -0.5)], [Vector3(0.6, 2.25, -0.95), Vector3(0.4, 0.7, -1)], [Vector3(-0.55, 2.1, -1.0), Vector3(-0.4, 0.6, -1)]])
	_place(a, _magpie(0.42), Vector3(-1.04, 3.0, 0.12), _look(Vector3(-0.15, 0, 1)), 1.7)
	return {"style": "low", "sway": 0.6, "tint": tint, "accent": accent, "anchor": 4.0, "warden": true, "shadow": 4.0, "ring": 1.9, "seed": "THE_HOLLOW_CROWN_A", "parts": a}
