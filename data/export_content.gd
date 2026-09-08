extends SceneTree
## Authoring utility: export registered default content into the editable pack.
## Run with: godot --headless --path . --script data/export_content.gd
const Catalog = preload("res://scripts/core/catalog.gd")

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://content")
	var resource_error: Error = Catalog.export_content_pack("res://content/full_content.tres",true)
	var json_error: Error = Catalog.export_content_pack("res://data/full_content.json",true)
	if resource_error != OK or json_error != OK:
		printerr("Content export failed: ",resource_error," / ",json_error)
		quit(1)
		return
	print("Exported full content Resource and data-only JSON.")
	quit(0)
