class_name DeepSaveStore
extends RefCounted
## Every record the game keeps on disk: the profile, the settings, a run checkpoint.
## Writes go to a temporary file and are renamed into place, and the previous good copy is
## kept as `.bak`, so a crash mid-write never costs a vault.

const SCHEMA: int = 1
const MAX_BYTES: int = 8 * 1024 * 1024
const DEFAULT_SETTINGS: Dictionary = {"master_volume": 0.8, "music_volume": 0.6, "sfx_volume": 0.85, "fullscreen": false,
	"speed": 1.0, "reduced_motion": false, "text_scale": 1.0, "vsync": true, "quality": 0, "shake": 1.0, "player_name": "Lapidary", "last_address": "127.0.0.1"}

## Tests point every store at a scratch directory so they never touch a real vault.
static var override_directory: String = ""

var directory: String

func _init(save_directory: String = "user://deepcut") -> void:
	directory = override_directory if not override_directory.is_empty() else save_directory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))

func read(file_name: String) -> Dictionary:
	var path := directory.path_join(file_name)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "nothing saved"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"ok": false, "error": "the save could not be opened"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		var backup := path + ".bak"
		if FileAccess.file_exists(backup):
			var again: Variant = JSON.parse_string(FileAccess.get_file_as_string(backup))
			if again is Dictionary:
				return {"ok": true, "value": again, "recovered": true}
		return {"ok": false, "error": "the save file is damaged"}
	return {"ok": true, "value": parsed}

func write(file_name: String, record: Dictionary) -> Dictionary:
	var bytes := JSON.stringify(record).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return {"ok": false, "error": "the save is too large"}
	var target := directory.path_join(file_name)
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "could not write; check disk space and permissions"}
	file.store_buffer(bytes)
	file.flush()
	var failed: bool = file.get_error() != OK
	file.close()
	if failed:
		return {"ok": false, "error": "the write failed; the previous save was kept"}
	if FileAccess.file_exists(target):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(target + ".bak"))
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target)) != OK:
		return {"ok": false, "error": "could not replace the save; the previous one was kept"}
	return {"ok": true}

func remove(file_name: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path := directory.path_join(file_name + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# --- the records ---------------------------------------------------------------------------

func load_settings() -> Dictionary:
	var out: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	var saved := read("settings.json")
	if saved.ok:
		for key in DEFAULT_SETTINGS:
			if saved.value.has(key):
				out[key] = saved.value[key]
	return out

func save_settings(settings: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	for key in DEFAULT_SETTINGS:
		if settings.has(key):
			out[key] = settings[key]
	return write("settings.json", out)

func load_profile() -> Dictionary:
	var saved := read("profile.json")
	if saved.ok and saved.value.get("profile", null) is Dictionary and int(saved.value.get("schema", 0)) == SCHEMA:
		return saved.value.profile
	return {}

func save_profile(profile: Dictionary) -> Dictionary:
	return write("profile.json", {"schema": SCHEMA, "saved_at": Time.get_datetime_string_from_system(true), "profile": profile})

func save_checkpoint(run: Dictionary, lobby: Dictionary) -> Dictionary:
	return write("run.json", {"schema": SCHEMA, "saved_at": Time.get_datetime_string_from_system(true), "run": run, "lobby": lobby})

func load_checkpoint() -> Dictionary:
	var saved := read("run.json")
	if saved.ok and saved.value.get("run", null) is Dictionary and int(saved.value.get("schema", 0)) == SCHEMA:
		return {"ok": true, "run": saved.value.run, "lobby": saved.value.get("lobby", {}), "saved_at": str(saved.value.get("saved_at", ""))}
	return {"ok": false}

func clear_checkpoint() -> void:
	remove("run.json")
