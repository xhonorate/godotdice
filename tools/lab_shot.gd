extends SceneTree
## Development helper: captures the gem lab, once at its defaults and once at the top of
## every rank, so a change to the stones can be reviewed without opening the lab by hand.
##   godot --path . --script tools/lab_shot.gd -- --out=user://shots
var ui: Control
var out_dir := "user://shots"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1500, 940))
	# Off the stone, or its tooltip opens and lands in every captured tile.
	Input.warp_mouse(Vector2(1480, 930))
	ui = load("res://scenes/gem_lab.tscn").instantiate()
	root.add_child(ui)
	await shoot("gem_lab")
	ui._cycle(4)
	ui._set_rank("carat", 22)
	ui._set_rank("cut", 5)
	ui._set_rank("clarity", 5)
	await shoot("gem_lab_max")
	# One tile of the stage per ground, side by side, which is the only way to judge the
	# alpha: a stone that reads on the game panel can vanish on paper.
	var stage: Control = ui._stage_back.get_parent()
	# Held still for the sheets: a drifting stone puts every tile at a different angle and
	# the comparison stops being one.
	ui._view.set_drift(false)
	var tiles: Array = []
	for slot in range(ui.BACKDROPS.size()):
		ui._set_backdrop(slot)
		for _beat in 14:
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		# The window stretches the canvas, so Control coordinates are not window pixels.
		var scale: Vector2 = Vector2(frame.get_size()) / root.get_visible_rect().size
		var region := Rect2i((stage.global_position * scale).floor(), (stage.size * scale).floor())
		var tile: Image = frame.get_region(region.intersection(Rect2i(Vector2i.ZERO, frame.get_size())))
		# blit_rect silently does nothing across formats, which is a transparent sheet.
		tile.convert(Image.FORMAT_RGBA8)
		tiles.append(tile)
	var span: Vector2i = tiles[0].get_size()
	var sheet := Image.create(span.x * tiles.size(), span.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0c111c"))
	for slot in range(tiles.size()):
		sheet.blit_rect(tiles[slot], Rect2i(Vector2i.ZERO, span), Vector2i(span.x * slot, 0))
	sheet.save_png(out_dir.path_join("gem_lab_grounds.png"))
	print("grounds: ", ui.BACKDROPS.size(), " tiles")

	# What the two alphas actually do, over squares that make it obvious.
	ui._set_backdrop(3)
	# Refraction writes the fragment opaque, so it has to come off before any alpha means
	# anything. These four tiles are that argument, in order.
	var trials := [
		{"name": "shipped", "set": {}},
		{"name": "no refraction", "set": {"refraction": 0.0}},
		{"name": "front half only", "set": {"refraction": 0.0, "far_pass": 0.0}},
		{"name": "see-through", "set": {"refraction": 0.0,
			"near_alpha_dull": 0.55, "near_alpha_clear": 0.30,
			"far_alpha_dull": 0.18, "far_alpha_clear": 0.34}}]
	var alpha_tiles: Array = []
	for trial: Dictionary in trials:
		ui._reset_tuning()
		for key: String in trial.set:
			ui._set_knob(key, float(trial.set[key]))
		alpha_tiles.append(await crop(stage))
	ui._reset_tuning()
	var alpha_sheet := Image.create(span.x * alpha_tiles.size(), span.y, false, Image.FORMAT_RGBA8)
	alpha_sheet.fill(Color("0c111c"))
	for slot in range(alpha_tiles.size()):
		alpha_sheet.blit_rect(alpha_tiles[slot], Rect2i(Vector2i.ZERO, span), Vector2i(span.x * slot, 0))
	alpha_sheet.save_png(out_dir.path_join("gem_lab_alpha.png"))
	print("alpha: ", " | ".join(trials.map(func(trial: Dictionary) -> String: return str(trial.name))))

	# The prism, swept. Fire is the one setting with no right answer on paper.
	ui._set_backdrop(0)
	ui._set_rank("clarity", 5)
	var fires := [
		{"name": "off", "set": {"fire": 0.0, "facet_hue": 0.0}},
		{"name": "shipped", "set": {}},
		{"name": "0.7", "set": {"fire": 0.7}},
		{"name": "1.2", "set": {"fire": 1.2}},
		{"name": "1.2 broad", "set": {"fire": 1.2, "fire_reach": 0.25, "fire_sharpness": 1.0}}]
	var fire_tiles: Array = []
	for trial: Dictionary in fires:
		ui._reset_tuning()
		for key: String in trial.set:
			ui._set_knob(key, float(trial.set[key]))
		fire_tiles.append(await crop(stage))
	ui._reset_tuning()
	var fire_sheet := Image.create(span.x * fire_tiles.size(), span.y, false, Image.FORMAT_RGBA8)
	fire_sheet.fill(Color("0c111c"))
	for slot in range(fire_tiles.size()):
		fire_sheet.blit_rect(fire_tiles[slot], Rect2i(Vector2i.ZERO, span), Vector2i(span.x * slot, 0))
	fire_sheet.save_png(out_dir.path_join("gem_lab_fire.png"))

	# The Cut ramp: Perfect is the clean solid, and every rank below it is that solid cut
	# worse. One row per shape, because a chip reads differently on a heart and a marquise.
	var shape_rows: Array = []
	for key: String in ["BLOCK", "STRIKE", "MEND", "ARC_BURST", "FOCUS"]:
		if not ui.keys.has(key):
			continue
		ui.index = ui.keys.find(key)
		var row: Array = []
		for k in range(1, 6):
			ui._set_rank("cut", k)
			row.append(await crop(stage))
		shape_rows.append(row)
	var wide: int = span.x * 5
	var cuts := Image.create(wide, span.y * shape_rows.size(), false, Image.FORMAT_RGBA8)
	cuts.fill(Color("0c111c"))
	for y in range(shape_rows.size()):
		for x in range(5):
			cuts.blit_rect(shape_rows[y][x], Rect2i(Vector2i.ZERO, span), Vector2i(span.x * x, span.y * y))
	cuts.save_png(out_dir.path_join("gem_lab_cuts.png"))

	# Clarity 1 to 5, which is where the emblem has to survive: a cloudy stone is nearly
	# solid, and whatever is set inside it only comes through by a fraction.
	ui.index = ui.keys.find("MEND") if ui.keys.has("MEND") else 0
	ui._set_rank("cut", 5)
	var clarity_tiles: Array = []
	for l in range(1, 6):
		ui._set_rank("clarity", l)
		clarity_tiles.append(await crop(stage))
	var clear := Image.create(span.x * 5, span.y, false, Image.FORMAT_RGBA8)
	clear.fill(Color("0c111c"))
	for slot in range(clarity_tiles.size()):
		clear.blit_rect(clarity_tiles[slot], Rect2i(Vector2i.ZERO, span), Vector2i(span.x * slot, 0))
	clear.save_png(out_dir.path_join("gem_lab_clarity.png"))
	print("clarity: 1-5 (Fractured to Flawless, left to right)")

	# Carat, which now runs past the edge of its own slot at the top of the range.
	ui._set_rank("clarity", 4)
	var weights := [1, 8, 14, 19, 22, 24]
	var carat_tiles: Array = []
	for c: int in weights:
		ui._set_rank("carat", c)
		carat_tiles.append(await crop(stage))
	var heavy := Image.create(span.x * weights.size(), span.y, false, Image.FORMAT_RGBA8)
	heavy.fill(Color("0c111c"))
	for slot in range(carat_tiles.size()):
		heavy.blit_rect(carat_tiles[slot], Rect2i(Vector2i.ZERO, span), Vector2i(span.x * slot, 0))
	heavy.save_png(out_dir.path_join("gem_lab_carat.png"))
	print("carat: ", weights)
	ui._view.set_drift(true)
	print("cuts: %d shapes x Cut 1-5 (Poor to Perfect, left to right)" % shape_rows.size())
	print("fire: ", " | ".join(fires.map(func(trial: Dictionary) -> String: return str(trial.name))))
	print("lab shots written to ", ProjectSettings.globalize_path(out_dir))
	quit(0)

func crop(stage: Control) -> Image:
	for _beat in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var scale: Vector2 = Vector2(frame.get_size()) / root.get_visible_rect().size
	var region := Rect2i((stage.global_position * scale).floor(), (stage.size * scale).floor())
	var tile: Image = frame.get_region(region.intersection(Rect2i(Vector2i.ZERO, frame.get_size())))
	tile.convert(Image.FORMAT_RGBA8)
	return tile

func shoot(name: String) -> void:
	for _beat in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
