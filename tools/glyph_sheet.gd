extends SceneTree
## Development helper: writes a contact sheet of every gem glyph at several sizes so
## the artwork can be judged without launching the game.
##   godot --headless --path . --script tools/glyph_sheet.gd -- --out=user://shots
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const NAMES := ["carat", "clarity", "cut", "high", "low", "pair", "triple", "sum",
	"shield", "hit", "target", "count", "run"]
const SIZES := [14, 20, 32, 64]
var sizes: Array = SIZES.duplicate()
var names: Array = NAMES.duplicate()

var out_dir := "user://shots"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--names="):
			names = argument.trim_prefix("--names=").split(",", false)
		elif argument.begins_with("--sizes="):
			sizes = []
			for piece in argument.trim_prefix("--sizes=").split(",", false):
				sizes.append(int(piece))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var pad := 8
	var span: int = sizes.max()
	var column: int = span + pad * 2
	var sheet := Image.create(column * names.size(), (span + pad * 2) * sizes.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0c111c"))
	for row in range(sizes.size()):
		var edge: int = int(sizes[row])
		for index in range(names.size()):
			var mask: Image = GemIcons.texture(str(names[index]), edge).get_image()
			mask.convert(Image.FORMAT_RGBA8)
			var origin := Vector2i(column * index + pad + (span - edge) / 2, (span + pad * 2) * row + pad + (span - edge) / 2)
			sheet.blend_rect(mask, Rect2i(Vector2i.ZERO, mask.get_size()), origin)
	var path := out_dir.path_join("glyphs.png")
	sheet.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path), " — columns: ", ", ".join(PackedStringArray(names)))
	quit(0)
