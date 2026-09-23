extends Node3D
## A Warden's hoard: three stone pedestals where it fell, a real stone turning over each under
## a beam of its grade's color. One is taken; the others go dark.
##
## In room space, at the arena, facing the party.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")

const SPREAD := 2.6

var _stands: Dictionary = {}
var _clock: float = 0.0

func build(biome: Dictionary, stones: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rock := StandardMaterial3D.new()
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.85
	for index in range(stones.size()):
		var stone: Dictionary = stones[index]
		var x: float = (float(index) - float(stones.size() - 1) * 0.5) * SPREAD
		var stand := Node3D.new()
		stand.position = Vector3(x, 0, 0)
		add_child(stand)
		var column := MeshInstance3D.new()
		column.mesh = Lowpoly.column(rng, Color(biome.rock).lightened(0.2), 8, 0.42, 1.15)
		column.material_override = rock
		stand.add_child(column)
		var cap := MeshInstance3D.new()
		cap.mesh = Lowpoly.slab(Vector3(1.0, 0.12, 1.0), Color(biome.rock).lightened(0.3), rng, 0.02)
		cap.material_override = rock
		cap.position = Vector3(0, 1.2, 0)
		stand.add_child(cap)
		var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier))
		var spinner := Node3D.new()
		spinner.position = Vector3(0, 1.75, 0)
		stand.add_child(spinner)
		var gem: Node3D = GemMesh.solid(stone)
		gem.scale = Vector3.ONE * 1.05 / float(gem.get_meta("extent", 1.0))
		gem.rotation = Vector3(deg_to_rad(-65), 0, 0)
		spinner.add_child(gem)
		var beam := SpotLight3D.new()
		beam.light_color = tone
		beam.light_energy = 5.0
		beam.spot_range = 7.0
		beam.spot_angle = 14.0
		beam.light_volumetric_fog_energy = 4.0
		beam.shadow_enabled = false
		beam.position = Vector3(0, 6.0, 0.3)
		beam.rotation = Vector3(-PI * 0.5, 0, 0)
		stand.add_child(beam)
		var shine := OmniLight3D.new()
		shine.light_color = tone
		shine.light_energy = 1.0
		shine.omni_range = 2.0
		shine.position = Vector3(0, 1.8, 0.6)
		shine.shadow_enabled = false
		stand.add_child(shine)
		_stands[str(stone.get("id", ""))] = {"stand": stand, "spinner": spinner, "beam": beam, "shine": shine, "hover": false, "phase": float(index) * 2.1, "out": false}

func spot(id: String) -> Node3D:
	return _stands[id].spinner if _stands.has(id) and is_instance_valid(_stands[id].spinner) else null

func set_hover(id: String, on: bool) -> void:
	if _stands.has(id):
		_stands[id].hover = on

func take(id: String) -> Node3D:
	## The chosen stone leaves its pedestal (for the stage to send to the bag); the other
	## pedestals' beams go out.
	var taken: Node3D = null
	for key in _stands:
		var entry: Dictionary = _stands[key]
		if key == id:
			var spinner: Node3D = entry.spinner
			## Where it stands in the space it is handed to, worked out locally so it holds even
			## before anything is on screen.
			var at: Transform3D = transform * entry.stand.transform * spinner.transform
			entry.stand.remove_child(spinner)
			get_parent().add_child(spinner)
			spinner.transform = at
			taken = spinner
		entry.out = true
		var beam: SpotLight3D = entry.beam
		var tween := beam.create_tween()
		tween.tween_property(beam, "light_energy", 0.0 if key != id else 0.0, 0.8)
	return taken

func collapse(fx: Node3D) -> float:
	## The hoard is taken: the pedestals sink back into the floor they rose from.
	if fx != null and is_instance_valid(fx):
		for key in _stands:
			fx.puff((_stands[key].stand as Node3D).global_position + Vector3(0, 0.6, 0.4), Color("8a7a66"), 10, 1.0, 1.6, 0.4)
	DeepAudio.play("crumble", {"volume": 0.7})
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 2.6, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
	return 0.8

func settle(chosen: String) -> void:
	## A hoard already chosen from, shown as it was left.
	if chosen.is_empty():
		return
	for key in _stands:
		var entry: Dictionary = _stands[key]
		entry.out = true
		(entry.beam as SpotLight3D).light_energy = 0.0
		if key == chosen and is_instance_valid(entry.spinner):
			entry.spinner.queue_free()

func _process(delta: float) -> void:
	_clock += delta
	for key in _stands:
		var entry: Dictionary = _stands[key]
		if not is_instance_valid(entry.spinner) or entry.spinner.get_parent() != entry.stand:
			continue
		var spinner: Node3D = entry.spinner
		spinner.rotation.y += delta * (1.2 if bool(entry.hover) else 0.5)
		spinner.position.y = 1.75 + sin(_clock * 1.4 + float(entry.phase)) * 0.06 + (0.12 if bool(entry.hover) else 0.0)
		spinner.scale = spinner.scale.lerp(Vector3.ONE * (1.2 if bool(entry.hover) else 1.0), clampf(delta * 8.0, 0.0, 1.0))
		(entry.shine as OmniLight3D).light_energy = (0.3 if bool(entry.out) else 1.0) * (2.0 if bool(entry.hover) else 1.0)
