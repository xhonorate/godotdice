extends SceneTree
## Engine-side check for the Content Studio: loads the authored pack exactly as the game
## does and prints whatever the real validator says.
##   godot --headless --path . --script tools/content_studio/validate_pack.gd
const Catalog = preload("res://scripts/core/catalog.gd")

func _init() -> void:
	var errors: Array = Catalog.load_content_pack("res://data/full_content.json")
	if errors.is_empty():
		errors = Catalog.load_content_pack("res://content/full_content.tres")
		for error in errors:
			print("CONTENT-ERROR: content/full_content.tres: ",error)
	else:
		for error in errors:
			print("CONTENT-ERROR: ",error)
	if errors.is_empty():
		print("CONTENT-OK: both the JSON source and the exported Resource load and validate.")
	quit(0 if errors.is_empty() else 1)
