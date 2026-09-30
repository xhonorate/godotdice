extends SceneTree
## Photographs the game's stones, dice and creatures for the data browser.
##
##   /path/to/Godot --path . --script tools/browser_assets.gd -- [out_dir] [set ...]
##
## Sets: gems (one hero picture per skill), matrix (every Cut × Clarity of each colour),
## carats (a carat sweep per colour), inclusions (each inclusion frozen in a stone),
## raw (each size class of each colour still in its rock), birthstones, dice, creatures.
## With no set named, all of them. Out defaults to tools/data-browser/assets.
##
## Uses the real live views (`gem_view.gd`, `dice_view.gd`, `creature_stage.gd`), so the
## pictures are exactly what the game draws. Needs a window: the views are SubViewports.

const GemView = preload("res://view/gems/gem_view.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const CreatureStage = preload("res://view/creatures/creature_stage.gd")

const HERO := 288
const CELL := 160
const DIE := 176
const CREATURE := Vector2i(360, 400)
const SETTLE_FRAMES := 5

var _out: String = "tools/data-browser/assets"
var _sets: Array = []
var _manifest: Dictionary = {}
var _count: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if GemView.headless():
		printerr("browser_assets needs a graphical display.")
		quit(1)
		return
	var args: Array = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = str(args[0])
	_sets = Array(args.slice(1)) if args.size() > 1 else ["gems", "matrix", "carats", "inclusions", "raw", "birthstones", "dice", "creatures"]
	root.size = Vector2i(720, 720)
	var backdrop := ColorRect.new()
	backdrop.color = Color("15181d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var started := Time.get_ticks_msec()
	if "gems" in _sets:
		await _gems()
	if "matrix" in _sets:
		await _matrix()
	if "carats" in _sets:
		await _carats()
	if "inclusions" in _sets:
		await _inclusions()
	if "raw" in _sets:
		await _raw()
	if "birthstones" in _sets:
		await _birthstones()
	if "dice" in _sets:
		await _dice()
	if "creatures" in _sets:
		await _creatures()
	_manifest.generated = Time.get_datetime_string_from_system()
	_manifest.pack_version = DeepContent.pack().get("version", 0)
	var file := FileAccess.open(_out.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "\t"))
	file.close()
	print("browser_assets: %d pictures in %.1fs → %s" % [_count, float(Time.get_ticks_msec() - started) / 1000.0, _out])
	quit(0)

# --- stones ------------------------------------------------------------------------------

func _stone(skill: String, carat: int, cut: int, clarity: int, inclusions: Array = [], appraised: bool = true) -> Dictionary:
	var stone: Dictionary = DeepStone.make(skill, carat, cut, clarity, inclusions, {"source": "browser"}, "browser_%s" % skill)
	stone.appraised = appraised
	stone.inclusions_revealed = appraised
	return stone

func _shoot_gem(stone: Dictionary, path: String, edge: int, slot: float) -> void:
	## One stone, photographed the way the game's thumbnails are: its own transparent
	## viewport, four lights, glow. `slot` is the box the stone is measured against; the
	## viewport grows around heavy stones so nothing is cropped.
	var view := GemView.new()
	view.position = Vector2(16, 16)
	view.size = Vector2(edge, edge)
	view.slot = slot
	view.set_drift(false)
	root.add_child(view)
	await process_frame
	view.configure(stone)
	view.set_spin(0.0)
	view.call("_fit_frame")
	await _capture(view.get("_viewport"), path)
	view.queue_free()
	await process_frame

func _capture(viewport: SubViewport, path: String) -> void:
	if viewport == null:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("nothing rendered for " + path)
		return
	var full: String = _out.path_join(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(full.get_base_dir()))
	var error := image.save_png(full)
	if error != OK:
		printerr("could not save %s: %s" % [full, error_string(error)])
		return
	_count += 1

func _skills_sorted() -> Array:
	var keys: Array = DeepContent.section("skills").keys()
	keys.sort()
	return keys

func _gems() -> void:
	## Every skill as a Good, Clear, eight-carat stone: the picture a skill's page leads with.
	var made: Array = []
	for key in _skills_sorted():
		await _shoot_gem(_stone(str(key), 8, 2, DeepContent.clear_index()), "gems/%s.png" % key, HERO, HERO * 0.9)
		made.append(str(key))
		print("gem ", key)
	_manifest.gems = {"skills": made, "carat": 8, "cut": 2, "clarity": DeepContent.clear_index(), "edge": HERO}

func _sample_skill(color: String) -> String:
	## The first skill of a colour, alphabetically: any stone of that colour is cut alike.
	for key in _skills_sorted():
		if str(DeepContent.skill(str(key)).get("color", "")) == color:
			return str(key)
	return ""

func _matrix() -> void:
	## Cut across, Clarity down, for one stone of every colour, so the page can show what
	## each rank does to the solid: a Poor stone is squat and chipped, a Flawless one is glass.
	var cuts: int = DeepContent.cuts().size()
	var clarities: int = DeepContent.clarities().size()
	var colors: Array = []
	for color in DeepContent.SKILL_COLORS:
		var skill: String = _sample_skill(str(color))
		if skill.is_empty():
			continue
		colors.append(color)
		for cut in cuts:
			for clarity in clarities:
				await _shoot_gem(_stone(skill, 8, cut, clarity, _sample_inclusions(clarity, str(color))), "matrix/%s_c%d_k%d.png" % [color, cut, clarity], CELL, CELL * 0.9)
		print("matrix ", color)
	_manifest.matrix = {"colors": colors, "cuts": cuts, "clarities": clarities, "carat": 8, "edge": CELL}

func _sample_inclusions(clarity: int, color: String) -> Array:
	## A stone of an included grade carries something, so it is photographed carrying the
	## commonest thing of each class in turn: the frozen shapes are what the grade looks like.
	var slots: int = DeepStone.inclusion_slots(clarity)
	var picks: Array = ["NEEDLE", "VEIL", "FEATHER"]
	var out: Array = []
	for index in mini(slots, picks.size()):
		out.append(picks[index])
	return out

const CARAT_SWEEP: Array = [1, 4, 8, 12, 16, 20, 24]

func _carats() -> void:
	## The same stone at seven weights, all in one frame size, so the carat curve is visible.
	var colors: Array = []
	for color in DeepContent.SKILL_COLORS:
		var skill: String = _sample_skill(str(color))
		if skill.is_empty():
			continue
		colors.append(color)
		for carat in CARAT_SWEEP:
			await _shoot_gem(_stone(skill, int(carat), 2, DeepContent.clear_index()), "carats/%s_%d.png" % [color, carat], CELL, CELL / 1.7)
		print("carats ", color)
	_manifest.carats = {"colors": colors, "carats": CARAT_SWEEP, "edge": CELL}

func _inclusions() -> void:
	## Each inclusion frozen alone in a Fine, twelve-carat White stone (Included grade), so
	## what the loupe would see of it is the picture beside its rule.
	var host: String = _sample_skill("WHITE")
	var keys: Array = DeepContent.section("inclusions").keys()
	keys.sort()
	var included: int = DeepContent.clarity_index("INCLUDED")
	for key in keys:
		await _shoot_gem(_stone(host, 12, 3, included, [str(key)]), "inclusions/%s.png" % key, CELL, CELL * 0.9)
	print("inclusions done")
	_manifest.inclusions = {"keys": keys, "host": host, "edge": CELL}

func _raw() -> void:
	## A stone nobody has read yet: half in its rock, drawn at its size class, colour only.
	var colors: Array = []
	var classes: Array = []
	for entry in DeepStone.SIZE_CLASSES:
		classes.append(str(entry.key))
	for color in DeepContent.color_KEYS:
		var skill: String = _sample_skill(str(color))
		if skill.is_empty():
			continue
		colors.append(color)
		for entry in DeepStone.SIZE_CLASSES:
			await _shoot_gem(_stone(skill, int(entry.shown), 2, DeepContent.clear_index(), [], false), "raw/%s_%s.png" % [color, entry.key], CELL, CELL / 1.7)
		print("raw ", color)
	_manifest.raw = {"colors": colors, "classes": classes, "edge": CELL}

func _birthstones() -> void:
	var keys: Array = DeepContent.section("characters").keys()
	keys.sort()
	for key in keys:
		var stone: Dictionary = DeepStone.birthstone(str(key))
		if stone.is_empty():
			continue
		await _shoot_gem(stone, "birthstones/%s.png" % key, HERO, HERO / 1.7)
		print("birthstone ", key)
	_manifest.birthstones = {"characters": keys, "edge": HERO}

# --- dice --------------------------------------------------------------------------------

func _dice() -> void:
	var keys: Array = DeepContent.section("dice").keys()
	keys.sort()
	for key in keys:
		var def: Dictionary = DeepContent.die(str(key))
		var die: Dictionary = DeepDice.make(str(key), "browser_%s" % key)
		## Shown on its best face, tipped to reveal the solid.
		var best: int = 0
		var best_value: int = -1
		for index in range(die.faces.size()):
			var face: Dictionary = die.faces[index]
			if str(face.get("kind", "plain")) != "blank" and int(face.get("value", 0)) > best_value:
				best_value = int(face.get("value", 0))
				best = index
		var view := DiceView.new()
		view.position = Vector2(16, 16)
		view.size = Vector2(DIE, DIE)
		view.live = false
		root.add_child(view)
		await process_frame
		view.configure(die, {"face": best, "value": best_value, "die_id": die.id}, false, false, Color.WHITE)
		view.settle_immediately()
		var pivot: Node3D = view.get("_pivot")
		if pivot != null:
			pivot.quaternion = Quaternion(Vector3.UP, 0.3) * Quaternion(Vector3.RIGHT, -0.2) * view.get("_target")
		await _capture(view.get("_viewport"), "dice/%s.png" % key)
		view.queue_free()
		await process_frame
		print("die ", key)
	_manifest.dice = {"keys": keys, "edge": DIE}

# --- creatures ---------------------------------------------------------------------------

func _creatures() -> void:
	var keys: Array = DeepContent.section("creatures").keys()
	keys.sort()
	for key in keys:
		var def: Dictionary = DeepContent.creature(str(key))
		var stage: Control = CreatureStage.new(str(key), bool(def.get("warden", false)))
		stage.position = Vector2(16, 16)
		stage.size = Vector2(CREATURE)
		root.add_child(stage)
		## Let it rise out of the rock and turn a little towards the lamp.
		await create_timer(1.3).timeout
		stage.set("_spin", 0.0)
		stage.set("_turn", 0.55)
		await _capture(stage.get("_viewport"), "creatures/%s.png" % key)
		stage.queue_free()
		await process_frame
		print("creature ", key)
	_manifest.creatures = {"keys": keys, "width": CREATURE.x, "height": CREATURE.y}
