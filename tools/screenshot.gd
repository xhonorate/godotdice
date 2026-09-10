extends SceneTree
## Development helper: drives the real interface and writes PNGs of each screen.
## Run with a windowed editor build, for example:
##   godot --path . --script tools/screenshot.gd -- --out user://shots
## Screens are written as menu.png, battle.png, route.png, inventory.png, journal.png
## and one shot of each inspect sheet: inspect_gem.png, inspect_enemy.png, inspect_die.png.

var ui: Control
var out_dir := "user://shots"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	DirAccess.make_dir_recursive_absolute(out_dir)
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle(24)
	await shoot("menu")
	ui.offline_hotseat = true
	ui.controlled_id = "shot_hero"
	ui.engine.new_run({"heroes": [
			{"id": "shot_hero", "hero_id": "ARDOR", "name": "Ardor"},
			{"id": "shot_two", "hero_id": "KAIT", "name": "Kait"},
			{"id": "shot_three", "hero_id": "MAX", "name": "Max"}],
		"profile": "expedition_18", "seed": 20260909, "autosave": false})
	await settle(12)
	await shoot("route")
	party(func(): ui._command("VoteRoom", {"offer_id": ui.snapshot.offers[0].id}))
	await settle(70)
	await shoot("battle")
	ui._toggle_die(str(ui._hero().dice[0].id))
	ui._toggle_die(str(ui._hero().dice[2].id))
	await settle(10)
	ui._reroll()
	await settle(16)
	await shoot("battle_rolling")
	await settle(70)
	await shoot("battle_settled")
	ui._inspect_gem(ui._hero().gems[0])
	await settle(30)
	await shoot("inspect_gem")
	ui._close_overlay()
	# A well-rolled gem and a multi-effect one: the plain starter shows the least.
	var rich: Dictionary = ui._hero().gems[0]
	rich.carat = 14
	rich.cut = 4
	rich.clarity = 3
	ui._inspect_gem(rich)
	await settle(30)
	await shoot("inspect_gem_rich")
	ui._close_overlay()
	ui._inspect_gem({"id": "shot-bash", "key": "SHIELDBASH", "carat": 9, "cut": 3, "clarity": 5, "revive_charges": 1})
	await settle(30)
	await shoot("inspect_gem_bash")
	ui._close_overlay()
	ui._inspect_gem({"id": "shot-life", "key": "LIFELINE", "carat": 20, "cut": 5, "clarity": 2, "revive_charges": 1})
	await settle(30)
	await shoot("inspect_gem_lifeline")
	ui._close_overlay()
	ui._inspect_unit(ui.snapshot.enemies[0])
	await settle(30)
	await shoot("inspect_enemy")
	ui._close_overlay()
	ui._inspect_die(ui._hero().dice[0], ui._hand_for(ui._hero())[0])
	await settle(40)
	await shoot("inspect_die")
	ui.inspect_view.focus_face(4)
	await settle(40)
	await shoot("inspect_die_turned")
	ui._close_overlay()
	await settle(10)
	party(func(): ui._command("SetReady", {"ready": true}))
	for beat in 4:
		await settle(28)
		await shoot("battle_beat_%d" % beat)
	await settle(70)
	await shoot("battle_after")
	ui._show_menu()
	await settle(14)
	await shoot("menu_pause")
	ui._close_overlay()
	ui._show_inventory()
	await settle(14)
	await shoot("inventory")
	ui._close_overlay()
	ui.journal_tab = "gems"
	ui._show_journal()
	await settle(14)
	await shoot("journal")
	ui.journal_tab = "dice"
	ui._show_journal()
	await settle(70)
	await shoot("journal_dice")
	ui._close_overlay()
	await settle(6)
	print("screenshots written to ", ProjectSettings.globalize_path(out_dir))
	quit(0)

func party(action: Callable) -> void:
	## Issues the same command for every seat so the party actually advances.
	var seat: String = ui.controlled_id
	for hero in ui.snapshot.get("heroes", []):
		ui.controlled_id = str(hero.id)
		action.call()
	ui.controlled_id = seat

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shoot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(tag + ".png")
	image.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
