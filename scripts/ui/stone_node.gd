extends RefCounted
## A gem as a free-standing 3D node, for scenes that hold many stones at once — the
## appraisal table — rather than one stone per viewport the way `GemView` does.
##
## It is built from the same meshes and materials `GemView` uses, in the same order: the far
## half first, the near half over it, the emblem set inside the crown. The crown faces +Z, so
## a stone meant to lie on a table is turned by whoever places it.

const GemMesh = preload("res://scripts/ui/gem_mesh.gd")
const Tuning = preload("res://scripts/ui/gem_tuning.gd")

static func build(gem: Dictionary) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Stone"
	var mesh := GemMesh.build(gem)
	var shell := MeshInstance3D.new()
	shell.mesh = mesh
	shell.material_override = GemMesh.interior_material(gem)
	shell.visible = Tuning.flag("far_pass")
	pivot.add_child(shell)
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = GemMesh.body_material(gem)
	body.material_overlay = GemMesh.fire_material(gem)
	pivot.add_child(body)
	if not (gem.has("appraised") and not bool(gem.appraised)):
		var etch := MeshInstance3D.new()
		etch.mesh = GemMesh.etch_plate(gem)
		etch.material_override = GemMesh.etch_material(gem)
		body.add_child(etch)
	# On a table every stone shares one space, so the full span is the size, uncapped.
	pivot.scale = Vector3.ONE * GemMesh.carat_span(int(gem.get("carat", 1)))
	return pivot
