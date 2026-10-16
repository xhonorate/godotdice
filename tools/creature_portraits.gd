extends SceneTree
## Bakes the bestiary's list pictures: every creature on the inspector's turntable, framed to
## its own shape, off its plinth and on a clear ground, one PNG each at
## view/creatures/portraits/<key>.png. The bestiary shows these in its grid and keeps live 3D
## for the one creature picked. Opens a window (it renders):
##
##   /path/to/Godot --path . --script tools/creature_portraits.gd                    # every creature
##   /path/to/Godot --path . --script tools/creature_portraits.gd -- RAIL_RAT PIT_MOLE
##
## Bake again whenever a creature's scene or colours change, then import once
## (`--headless --path . --import`) so the game sees the new pictures. A new picture's
## .import wants `mipmaps/generate=true`, as the others have: the grid draws it far smaller
## than it is baked. tests/test_creatures.gd checks that every creature in the pack has one.

const CreatureStage = preload("res://view/creatures/creature_stage.gd")
const EDGE := 256
## Shot larger than it is kept, then cut down square round the creature.
const SHOT := 400
## How much clear ground is left round the creature, as a share of the picture.
const MARGIN := 0.07
const DIR := "res://view/creatures/portraits/"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("creature_portraits needs a graphical display.")
		quit(1)
		return
	var keys: Array = Array(OS.get_cmdline_user_args()).filter(func(a: Variant) -> bool: return not str(a).begins_with("--"))
	if keys.is_empty():
		keys = DeepContent.section("creatures").keys()
	keys.sort()
	root.size = Vector2i(SHOT + 64, SHOT + 64)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var failed: int = 0
	for key in keys:
		var def: Dictionary = DeepContent.creature(str(key))
		if def.is_empty():
			printerr("no creature ", key)
			failed += 1
			continue
		var stage: Control = CreatureStage.new(str(key), bool(def.get("warden", false)))
		stage.fit = true
		stage.plinth_shown = false
		stage.position = Vector2(16, 16)
		stage.size = Vector2(SHOT, SHOT)
		root.add_child(stage)
		## Let it rise out of the rock and settle, then turn it three-quarters to the lamp.
		await create_timer(1.3).timeout
		stage.set("_spin", 0.0)
		stage.set("_turn", 0.55)
		var viewport: SubViewport = stage.get("_viewport")
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for _i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = viewport.get_texture().get_image()
		if shot == null or shot.is_empty():
			printerr("nothing rendered for ", key)
			failed += 1
		else:
			shot.convert(Image.FORMAT_RGBA8)
			shot = _cropped(shot)
			var path: String = ProjectSettings.globalize_path(DIR + str(key).to_lower() + ".png")
			var error := shot.save_png(path)
			print("portrait ", key, " ", error_string(error))
			if error != OK:
				failed += 1
		stage.queue_free()
		await process_frame
	quit(0 if failed == 0 else 1)

func _cropped(shot: Image) -> Image:
	## Cut square round what is solid in the picture (the faint edge of its shadow does not
	## count), with a little clear ground left round it, and brought down to EDGE.
	var low := Vector2i(shot.get_width(), shot.get_height())
	var high := Vector2i(-1, -1)
	for y in range(shot.get_height()):
		for x in range(shot.get_width()):
			if shot.get_pixel(x, y).a > 0.3:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x < 0:
		shot.resize(EDGE, EDGE, Image.INTERPOLATE_LANCZOS)
		return shot
	var side: int = int(ceil(float(maxi(high.x - low.x, high.y - low.y) + 1) / (1.0 - 2.0 * MARGIN)))
	var centre: Vector2i = (low + high) / 2
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	## The square may run past the shot's edge: only the part inside it is copied, in place.
	var wanted := Rect2i(centre - Vector2i(side, side) / 2, Vector2i(side, side))
	var inside: Rect2i = wanted.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	square.blit_rect(shot, inside, inside.position - wanted.position)
	square.resize(EDGE, EDGE, Image.INTERPOLATE_LANCZOS)
	return square
