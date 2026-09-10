extends SceneTree
## Development helper: writes contact sheets of the runtime gem renderer so each of the
## four C's can be checked in isolation — one row per property, varying only that one.
##   godot --headless --path . --script tools/gem_sheet.gd -- --out=user://shots
const GemRender = preload("res://scripts/ui/gem_render.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

var out_dir := "user://shots"
var cell := 128

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--cell="):
			cell = int(argument.trim_prefix("--cell="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_axes()
	_every_skill()
	quit(0)

func _sheet(rows: Array, path: String, note: String) -> void:
	var columns := 0
	for row in rows:
		columns = maxi(columns, (row as Array).size())
	var sheet := Image.create(cell * columns, cell * rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0c111c"))
	for y in range(rows.size()):
		var row: Array = rows[y]
		for x in range(row.size()):
			var picture: Image = GemRender.texture(row[x], cell).get_image()
			picture.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), Vector2i(cell * x, cell * y))
	var full := out_dir.path_join(path)
	sheet.save_png(full)
	print("wrote ", ProjectSettings.globalize_path(full), " — ", note)

func _gem(key: String, carat: int, cut: int, clarity: int) -> Dictionary:
	return Catalog.gem(key, "sheet", carat, cut, clarity)

func _axes() -> void:
	var rows: Array = []
	# One row per Color: the cut outline and hue that a category always wears.
	var colours: Array = []
	for key in ["STRIKE", "BLOCK", "HEAL", "STUN", "LUCKYSTRIKE"]:
		colours.append(_gem(key, 14, 3, 4))
	rows.append(colours)
	# Carat only: size, on its curve.
	var carats: Array = []
	for c in [1, 4, 8, 12, 18, 24]:
		carats.append(_gem("STRIKE", c, 3, 3))
	rows.append(carats)
	# Cut only: faceting.
	var cuts: Array = []
	for k in range(1, 6):
		cuts.append(_gem("BLOCK", 16, k, 3))
	rows.append(cuts)
	# Clarity only: brilliance, flaws, saturation.
	var clarities: Array = []
	for l in range(1, 6):
		clarities.append(_gem("HEAL", 16, 3, l))
	rows.append(clarities)
	_sheet(rows, "gems_axes.png", "rows: Color, Carat 1-24, Cut 1-5, Clarity 1-5")

func _every_skill() -> void:
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
	_sheet(rows, "gems_emblems.png", "every skill at Carat 15 / Cut 4 / Clarity 4: " + ", ".join(PackedStringArray(keys)))
