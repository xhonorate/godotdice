extends SceneTree
## Writes every generated sprite to res://assets/sprites so the shipped art is a set of
## ordinary PNGs an artist can open and repaint. The runtime prefers those files, so
## after a bake the procedural painter never runs in the game.
##
##   godot --headless --path . --script tools/bake_sprites.gd
##   godot --headless --path . --import      # regenerate the .import files
##
## Gems are not baked: their picture depends on the four properties of a gem instance,
## so `gem_render.gd` paints each stone at runtime. Anything already sitting in
## assets/sprites/gems is unused and can be deleted.
##
## Re-run it after changing scripts/ui/sprite_forge.gd. Files you have hand-painted are
## overwritten, so keep authored art somewhere else, or pass --keep to skip existing files.

const Forge = preload("res://scripts/ui/sprite_forge.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

const ROOMS := ["battle", "elite", "boss", "shop", "rest", "event", "mine", "workshop", "lapidary", "wager", "crucible"]
const PROPS := ["sigil", "gold", "heart", "shield", "skull", "sword", "bolt", "shieldbreak"]

var keep_existing := false
var written := 0
var skipped := 0

func _initialize() -> void:
	keep_existing = OS.get_cmdline_user_args().has("--keep")
	var work: Array = []
	for key in Catalog.HEROES:
		work.append(["heroes", str(key), [], 1])
	for key in Catalog.ENEMIES:
		work.append(["enemies", str(key), [], 1])
	for key in Catalog.RELICS:
		work.append(["relics", str(key), [], 1])
	for kind in ROOMS:
		work.append(["rooms", kind, [], 1])
	for prop_name in PROPS:
		work.append(["props", prop_name, [], 1])

	var started := Time.get_ticks_msec()
	for job in work:
		_write(str(job[0]), str(job[1]), job[2], int(job[3]))
	print("Baked %d sprites (%d kept) in %d ms into res://assets/sprites" % [written, skipped, Time.get_ticks_msec() - started])
	if written > 0:
		print("Run: godot --headless --path . --import")
	quit(0)

func _write(category: String, key: String, tags: Array, rarity: int) -> void:
	var directory := "res://assets/sprites/" + category
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%s/%s.png" % [directory, key.to_lower()]
	if keep_existing and FileAccess.file_exists(path):
		skipped += 1
		return
	var image: Image = Forge.bake(category, key, tags, rarity)
	if image == null:
		push_error("No painter for %s/%s" % [category, key])
		return
	var status := image.save_png(path)
	if status != OK:
		push_error("Could not write %s (error %d)" % [path, status])
		return
	written += 1
