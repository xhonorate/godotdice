extends SceneTree
## Writes the gem pictographs the game draws into the studio, so the panel marks a term
## with exactly the symbol the player will see rather than an approximation of it.
##   godot --headless --path . --script tools/content_studio/bake_glyphs.gd
##
## They are alpha masks, white throughout, which is what lets one file serve every tint:
## the studio paints them with CSS `mask-image` and its own colour.
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const NAMES: Array = ["carat", "clarity", "cut", "high", "low", "pair", "triple", "sum",
	"shield", "hit", "target", "count", "run", "reroll"]
const EDGE: int = 96
const OUT: String = "res://tools/content_studio/app/glyphs"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var hints: Dictionary = {}
	for name in NAMES:
		var texture: ImageTexture = GemIcons.texture(name, EDGE)
		if texture == null:
			printerr("No glyph: ", name)
			continue
		var error: Error = texture.get_image().save_png(OUT + "/" + name + ".png")
		if error != OK:
			printerr("Could not write ", name, ": ", error)
			quit(1)
			return
		hints[name] = GemIcons.hint(name)
	## The hover text travels with the art: the studio says the same sentence the game does.
	var file: FileAccess = FileAccess.open(OUT + "/hints.json", FileAccess.WRITE)
	if file == null:
		printerr("Could not write the hint table.")
		quit(1)
		return
	file.store_string(JSON.stringify(hints, "\t", true) + "\n")
	GemIcons.release()
	print("Baked %d glyphs at %dpx into %s" % [hints.size(), EDGE, OUT])
	quit(0)
