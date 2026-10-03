extends SceneTree
## Validates the content pack headlessly and prints every error, one a line:
##   /path/to/Godot --headless --path . --script tools/validate_content.gd

func _init() -> void:
	var errors: Array = DeepContent.validate()
	if errors.is_empty():
		print("Content: %d creatures, %d skills, %d mines; no errors" % [DeepContent.section("creatures").size(), DeepContent.section("skills").size(), DeepContent.section("mines").size()])
	for error in errors:
		printerr("CONTENT: " + str(error))
	quit(0 if errors.is_empty() else 1)
