extends SceneTree
## How the mine and the Geodes are drawn, headless: the stage's viewport is cut to the
## window's pixels (`MineStage.physical_size`), FXAA goes over the room only where there is
## no multisampling or the player asked for it (`MineStage.screen_aa`), and a Geode's rind is
## a lump of flat facets, the same lump every time for the same Geode (November 6, 2026).
## Pure functions and plain arrays: nothing here draws.

const MineStage = preload("res://view/run/mine_stage.gd")
const GeodeMesh = preload("res://view/gems/geode_mesh.gd")

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_viewport_pixels()
	_screen_aa()
	_geode_facets()
	print("Render: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _viewport_pixels() -> void:
	## The 1600×900 canvas over the dev window (0.9), 1080p (1.2) and 1440p (1.6).
	check(MineStage.physical_size(Vector2(1600, 841), Vector2(0.9, 0.9)) == Vector2i(1440, 757), "the dev window's stage is 1440×757 pixels (got %s)" % MineStage.physical_size(Vector2(1600, 841), Vector2(0.9, 0.9)))
	check(MineStage.physical_size(Vector2(1600, 842), Vector2(1.2, 1.2)) == Vector2i(1920, 1011), "a 1080p stage is 1920×1011 pixels (got %s)" % MineStage.physical_size(Vector2(1600, 842), Vector2(1.2, 1.2)))
	check(MineStage.physical_size(Vector2(1600, 842), Vector2(1.6, 1.6)) == Vector2i(2560, 1348), "a 1440p stage is 2560×1348 pixels (got %s)" % MineStage.physical_size(Vector2(1600, 842), Vector2(1.6, 1.6)))
	## Rounded up, so the frame never falls a sliver short of the stage's edge.
	check(MineStage.physical_size(Vector2(1000.5, 500.2), Vector2.ONE) == Vector2i(1001, 501), "a part pixel is a whole one")

func _screen_aa() -> void:
	var fxaa: int = Viewport.SCREEN_SPACE_AA_FXAA
	var none: int = Viewport.SCREEN_SPACE_AA_DISABLED
	check(MineStage.screen_aa(1, false) == fxaa, "low graphics, no multisampling: FXAA over the room")
	check(MineStage.screen_aa(2, false) == none and MineStage.screen_aa(3, false) == none, "medium and high multisample, and no FXAA goes over that")
	check(MineStage.screen_aa(2, true) == fxaa and MineStage.screen_aa(3, true) == fxaa, "Soften edges puts FXAA back over the multisampling")

func _geode_facets() -> void:
	var tone := Color("c070ff")
	for mine in GeodeMesh.BY_MINE:
		var geode: Dictionary = {"mine": mine, "id": "render_" + str(mine).to_lower()}
		var made: Dictionary = GeodeMesh.cut(geode, tone)
		var rind_tris: int = 0
		var flat: bool = true
		var corners: Dictionary = {}
		for part in made.parts:
			var rind = (part as Dictionary).get("rind", null)
			if rind == null:
				continue
			var points: PackedVector3Array = rind.points
			var normals: PackedVector3Array = rind.normals
			for t in range(0, points.size(), 3):
				rind_tris += 1
				## One normal a facet, and it is the facet's own: no smoothing across corners.
				var facet: Vector3 = (points[t + 1] - points[t]).cross(points[t + 2] - points[t]).normalized()
				if not (normals[t].is_equal_approx(normals[t + 1]) and normals[t].is_equal_approx(normals[t + 2]) and absf(absf(facet.dot(normals[t])) - 1.0) < 0.001):
					flat = false
				for k in range(3):
					corners[Vector3i((points[t + k] * 1000.0).round())] = true
		check(flat, "%s: the rind is flat-shaded, one normal a facet" % mine)
		## Low poly: a few hundred facets at most, where the smooth ellipsoid had 2,300. (The
		## Warrens' fungus caps are cut into the same surface, nine sides to a cap.)
		var ceiling: int = 1000 if GeodeMesh.LOOKS[GeodeMesh.look_of(geode)].has("caps") else 400
		check(rind_tris > 60 and rind_tris < ceiling, "%s: the rind is a lump of %d facets" % [mine, rind_tris])
		check(made.seam.size() == GeodeMesh.FRONT + 1, "%s: the seam's front is sampled as before" % mine)
		## The same Geode is the same lump; another Geode is another lump.
		var again: Dictionary = GeodeMesh.cut(geode, tone)
		check((again.parts[0].rind.points as PackedVector3Array) == (made.parts[0].rind.points as PackedVector3Array), "%s: the same Geode is cut the same every time" % mine)
		var other: Dictionary = GeodeMesh.cut({"mine": mine, "id": "render_other"}, tone)
		check((other.parts[0].rind.points as PackedVector3Array) != (made.parts[0].rind.points as PackedVector3Array), "%s: another Geode is another lump" % mine)
	check(GeodeMesh.FACETS >= 8 and GeodeMesh.FACETS <= 12 and 2 * GeodeMesh.RINGS - 1 >= 5 and 2 * GeodeMesh.RINGS - 1 <= 7, "8 to 12 facets a ring, 5 to 7 rings")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
