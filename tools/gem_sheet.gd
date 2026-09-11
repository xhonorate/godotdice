extends SceneTree
## Development helper: lays every gem out in a grid, renders it and writes contact sheets,
## so each of the four C's can be judged in isolation — one row per property, varying only
## that one. Gems are real 3D now, so this needs a window; it cannot run headless.
##
##   godot --path . --script tools/gem_sheet.gd -- --out=user://shots
##
## Writes gems_axes.png (Color / Carat / Cut / Clarity) and gems_emblems.png (all skills).

const GemView = preload("res://scripts/ui/gem_view.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

var out_dir := "user://shots"
var cell := 132
var page: Control

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--cell="):
			cell = int(argument.trim_prefix("--cell="))
	call_deferred("run")

func run() -> void:
	if GemView.headless():
		printerr("Gems are 3D: run this with a windowed build, without --headless.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _sheet(_axis_rows(), "gems_axes.png", "rows: Color, Carat 1-24, Cut 1-5, Clarity 1-5")
	await _sheet(_emblem_rows(), "gems_emblems.png", "every skill at Carat 15 / Cut 4 / Clarity 4")
	print("contact sheets written to ", ProjectSettings.globalize_path(out_dir))
	quit(0)

func _gem(key: String, carat: int, cut: int, clarity: int) -> Dictionary:
	return Catalog.gem(key, "sheet", carat, cut, clarity)

func _axis_rows() -> Array:
	var rows: Array = []
	var colours: Array = []
	for key in ["STRIKE", "BLOCK", "HEAL", "STUN", "LUCKYSTRIKE", "GLIMMER"]:
		colours.append(_gem(key, 14, 3, 4))
	rows.append(colours)
	var carats: Array = []
	for c in [1, 4, 8, 12, 18, 24]:
		carats.append(_gem("STRIKE", c, 3, 3))
	rows.append(carats)
	var cuts: Array = []
	for k in range(1, 6):
		cuts.append(_gem("BLOCK", 16, k, 3))
	rows.append(cuts)
	var clarities: Array = []
	for l in range(1, 6):
		clarities.append(_gem("HEAL", 16, 3, l))
	rows.append(clarities)
	return rows

func _emblem_rows() -> Array:
	var keys: Array = Catalog.SKILLS.keys()
	keys.sort()
	var rows: Array = []
	var row: Array = []
	for key in keys:
		row.append(_gem(str(key), 15, 4, 4))
		if row.size() == 7:
			rows.append(row)
			row = []
	if not row.is_empty():
		rows.append(row)
	return rows

func _sheet(rows: Array, path: String, note: String) -> void:
	var columns := 0
	for row in rows:
		columns = maxi(columns, (row as Array).size())
	DisplayServer.window_set_size(Vector2i(cell * columns, cell * rows.size()))
	if is_instance_valid(page):
		page.queue_free()
		await process_frame
	page = ColorRect.new()
	page.color = Color("0c111c")
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	for y in range(rows.size()):
		var row: Array = rows[y]
		for x in range(row.size()):
			var view := GemView.new()
			view.position = Vector2(cell * x, cell * y)
			view.custom_minimum_size = Vector2(cell, cell)
			view.size = Vector2(cell, cell)
			page.add_child(view)
			view.configure(row[x])
	# One frame to lay out, several more for every SubViewport to take its single shot.
	for _beat in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	var full := out_dir.path_join(path)
	shot.save_png(full)
	print("wrote ", ProjectSettings.globalize_path(full), " — ", note)
