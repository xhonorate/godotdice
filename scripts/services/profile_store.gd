class_name ProfileStore
extends RefCounted
## Owns the local player's profile on disk. Every change is a transaction: the rule runs on
## a copy, the copy is saved, and only then does it replace the profile in memory. A failed
## rule or a failed write leaves both the file and the in-memory profile as they were.
##
## `--instance=guest2` on the command line gives a separate profile, matching the separate
## LAN identity `Session` keeps for local multiplayer testing.

const Profile = preload("res://scripts/core/profile.gd")
const SaveStore = preload("res://scripts/services/save_store.gd")
const FILE_NAME := "profile.json"

signal changed(profile: Dictionary)

var store: SaveStore
var profile: Dictionary = {}

func _init(directory: String = "") -> void:
	store = SaveStore.new(directory if not directory.is_empty() else default_directory())

static func default_directory() -> String:
	var instance := "default"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--instance="):
			instance = argument.trim_prefix("--instance=").validate_filename().left(48)
	return "user://profiles/" + instance

func load_or_create() -> Dictionary:
	## Reads the profile, falling back to its backup. A file that exists but cannot be read
	## is moved aside rather than overwritten, so a damaged save can still be recovered by hand.
	var primary := _load_file(FILE_NAME)
	if primary.ok:
		profile = primary.profile
		changed.emit(profile)
		return {"ok": true, "error": "", "created": false, "recovered": false}
	var backup := _load_file(FILE_NAME + ".bak")
	if backup.ok:
		profile = backup.profile
		var restored := _save(profile)
		changed.emit(profile)
		return {"ok": restored.ok, "error": restored.error, "created": false, "recovered": true,
			"notice": "Your profile could not be read, so the previous save was restored."}
	var path := store.directory.path_join(FILE_NAME)
	var moved_aside := ""
	if FileAccess.file_exists(path):
		moved_aside = path + ".damaged-%d" % Time.get_unix_time_from_system()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(moved_aside))
	profile = Profile.create(Crypto.new().generate_random_bytes(8).hex_encode())
	var saved := _save(profile)
	changed.emit(profile)
	return {"ok": saved.ok, "error": saved.error, "created": true, "recovered": false, "moved_aside": moved_aside}

func transact(action: Callable) -> Dictionary:
	## `action` receives a working copy and returns an error String or a result Dictionary.
	if profile.is_empty():
		return {"ok": false, "error": "No profile is loaded."}
	var working := profile.duplicate(true)
	var outcome: Variant = action.call(working)
	var result: Dictionary = outcome if outcome is Dictionary else {"ok": str(outcome).is_empty(), "error": str(outcome)}
	if not result.get("ok", false):
		return result
	var checked := Profile.normalize(working)
	if not checked.ok:
		return {"ok": false, "error": checked.error}
	var saved := _save(checked.profile)
	if not saved.ok:
		return {"ok": false, "error": saved.error}
	profile = checked.profile
	changed.emit(profile)
	return result

func _save(value: Dictionary) -> Dictionary:
	var record := {"schema_version": Profile.SCHEMA_VERSION, "saved_at": Time.get_datetime_string_from_system(true), "profile": value}
	var written := store.write_record(FILE_NAME, record)
	return {"ok": written.get("ok", false), "error": str(written.get("error", ""))}

func _load_file(file_name: String) -> Dictionary:
	var read := store.read_record(file_name)
	if not read.ok:
		return {"ok": false, "error": read.error}
	var checked := Profile.normalize(read.value.get("profile"))
	return {"ok": checked.ok, "error": checked.error, "profile": checked.profile}
