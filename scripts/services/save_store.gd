class_name SaveStore
extends RefCounted

## The authority must persist each accepted transaction before publishing it.
const SCHEMA_VERSION := 1
const RULES_VERSION := "1.0.0"
const CONTENT_VERSION := "1.0.0"
const MAX_SAVE_BYTES := 8 * 1024 * 1024
const DEFAULT_SETTINGS := {
	"master_volume": 0.8, "music_volume": 0.65, "sfx_volume": 0.85,
	"fullscreen": false, "animation_speed": 1.0, "reduced_motion": false,
	"text_scale": 1.0, "player_name": "Adventurer", "last_address": "127.0.0.1",
	"colorblind_symbols": true, "idle_motion": true,
}

var directory: String
var content_validator: Callable

func _init(save_directory: String = "user://saves") -> void:
	directory = save_directory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))

func save_checkpoint(state: Dictionary, command_history: Dictionary = {}) -> Dictionary:
	var validation := validate_state(state)
	if not validation.ok:
		return validation
	var record := {
		"schema_version": SCHEMA_VERSION, "rules_version": RULES_VERSION,
		"content_version": CONTENT_VERSION, "saved_at": Time.get_datetime_string_from_system(true),
		"state": state.duplicate(true), "command_history": command_history.duplicate(true),
	}
	var result := _atomic_write("active_run.json", record)
	if result.ok:
		result["revision"] = state.get("revision", 0)
	return result

func load_checkpoint() -> Dictionary:
	var primary := _load_checkpoint_file("active_run.json")
	if primary.ok:
		return primary
	var backup := _load_checkpoint_file("active_run.json.bak")
	if backup.ok:
		backup["recovered_backup"] = true
		backup["notice"] = "The latest checkpoint was unreadable. Restored the previous valid checkpoint."
		return backup
	return primary

func has_checkpoint() -> bool:
	return load_checkpoint().get("ok", false)

func clear_checkpoint() -> void:
	for file in ["active_run.json", "active_run.json.bak", "active_run.json.tmp"]:
		var path := directory.path_join(file)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _load_checkpoint_file(file_name: String) -> Dictionary:
	var parsed := _read(file_name)
	if not parsed.ok:
		return parsed
	var record: Dictionary = parsed.value
	if record.get("schema_version", -1) != SCHEMA_VERSION:
		return {"ok": false, "error": "This checkpoint uses an incompatible save schema."}
	if record.get("rules_version") != RULES_VERSION or record.get("content_version") != CONTENT_VERSION:
		return {"ok": false, "error": "This checkpoint was made with incompatible rules or content."}
	if not record.get("state") is Dictionary or not record.get("command_history", {}) is Dictionary:
		return {"ok": false, "error": "The checkpoint has no valid run state."}
	var validation := validate_state(record.state)
	if not validation.ok:
		return validation
	return {"ok": true, "state": record.state, "command_history": record.get("command_history", {}), "saved_at": record.get("saved_at", "")}

func validate_state(state: Dictionary) -> Dictionary:
	if state.get("schema_version", -1) != SCHEMA_VERSION:
		return {"ok": false, "error": "Unsupported run schema."}
	if state.get("rules_version") != RULES_VERSION or state.get("content_version") != CONTENT_VERSION:
		return {"ok": false, "error": "Unsupported rules or content version."}
	if not state.get("run_id") is String or str(state.run_id).is_empty():
		return {"ok": false, "error": "Run identity is missing."}
	if not state.get("heroes") is Array or state.heroes.is_empty() or state.heroes.size() > 4:
		return {"ok": false, "error": "The saved party must have one to four heroes."}
	var ids := {}
	for hero in state.heroes:
		if not hero is Dictionary or not hero.get("id") is String or ids.has(hero.id):
			return {"ok": false, "error": "The checkpoint contains an invalid or duplicate player identity."}
		ids[hero.id] = true
		if not str(hero.get("hero_id", hero.get("key", ""))).to_upper() in ["ARDOR", "KAIT", "MAX"]:
			return {"ok": false, "error": "The checkpoint references an unknown hero."}
		for field in ["hp", "max_hp", "block", "gold"]:
			var amount: Variant = hero.get(field)
			if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floor(float(amount)):
				return {"ok": false, "error": "The checkpoint contains a malformed hero resource."}
		if float(hero.get("hp", 0)) < 0 or float(hero.get("hp", 0)) > float(hero.get("max_hp", 0)) or float(hero.get("gold", 0)) < 0 or float(hero.get("block", 0)) < 0:
			return {"ok": false, "error": "The checkpoint contains invalid hero resources."}
	if content_validator.is_valid():
		var checked: Variant = content_validator.call(state)
		if checked is Dictionary and not checked.get("ok", false):
			return checked
		if checked is bool and not checked:
			return {"ok": false, "error": "The checkpoint references unknown content."}
		if checked is String and not checked.is_empty():
			return {"ok": false, "error": checked}
	return {"ok": true, "error": ""}

func load_settings() -> Dictionary:
	var result := DEFAULT_SETTINGS.duplicate(true)
	var saved := _read("settings.json")
	if saved.ok:
		for key in DEFAULT_SETTINGS:
			if saved.value.has(key) and (typeof(saved.value[key]) == typeof(DEFAULT_SETTINGS[key]) or (DEFAULT_SETTINGS[key] is float and saved.value[key] is int)):
				result[key] = saved.value[key]
	for key in ["master_volume", "music_volume", "sfx_volume"]:
		result[key] = clampf(float(result[key]), 0.0, 1.0)
	result.animation_speed = clampf(float(result.animation_speed), 0.0, 4.0)
	result.text_scale = clampf(float(result.text_scale), 0.8, 1.5)
	return result

func save_settings(settings: Dictionary) -> Dictionary:
	var sanitized := DEFAULT_SETTINGS.duplicate(true)
	for key in DEFAULT_SETTINGS:
		if settings.has(key):
			sanitized[key] = settings[key]
	return _atomic_write("settings.json", sanitized)

func load_history() -> Array:
	var record := _read("history.json")
	if record.ok and record.value.get("runs") is Array:
		return record.value.runs.filter(func(value: Variant): return value is Dictionary).slice(0, 100)
	return []

func record_summary(summary: Dictionary) -> Dictionary:
	var history := load_history()
	for previous in history:
		if previous.get("run_id") == summary.get("run_id"):
			return {"ok": true, "duplicate": true}
	history.push_front(summary.duplicate(true))
	if history.size() > 100:
		history.resize(100)
	return _atomic_write("history.json", {"schema_version": SCHEMA_VERSION, "runs": history})

func _read(file_name: String) -> Dictionary:
	var path := directory.path_join(file_name)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No saved run is available."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return {"ok": false, "error": "The save could not be opened or exceeds the size limit."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "The save file is damaged or invalid."}
	return {"ok": true, "value": parser.data}

func _atomic_write(file_name: String, record: Dictionary) -> Dictionary:
	var bytes := JSON.stringify(record).to_utf8_buffer()
	if bytes.size() > MAX_SAVE_BYTES:
		return {"ok": false, "error": "The save exceeds the supported size."}
	var target := directory.path_join(file_name)
	var temporary := target + ".tmp"
	var backup := target + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write a checkpoint. Check free disk space and permissions."}
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "error": "Checkpoint write failed; the previous save was preserved."}
	# Keep the target in place until the fully written replacement is ready.
	# copy_absolute preserves a recovery file; rename is atomic on the same volume.
	var preserve_current := FileAccess.file_exists(target)
	if preserve_current and file_name == "active_run.json":
		preserve_current = _load_checkpoint_file(file_name).get("ok", false)
	if preserve_current:
		var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(backup))
		if copy_error != OK:
			return {"ok": false, "error": "Could not preserve the previous checkpoint."}
	var replace_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	if replace_error != OK:
		return {"ok": false, "error": "Could not replace the checkpoint; the previous save was preserved."}
	return {"ok": true, "error": ""}
