extends SceneTree
## Development helper: drives the real interface and writes PNGs of each screen.
## Run with a windowed editor build, for example:
##   godot --path . --script tools/screenshot.gd -- --out user://shots
## Screens are written as menu.png, battle.png, route.png, inventory.png, journal.png,
## one shot of each inspect sheet: inspect_gem.png, inspect_enemy.png, inspect_die.png,
## and the service rooms that are played rather than read: wager_*.png and crucible_*.png.

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
	ui.journal_tab = "rooms"
	ui._show_journal()
	await settle(20)
	await shoot("journal_rooms")
	ui._close_overlay()
	await settle(10)

	# A route card carrying the two rooms that are played rather than read.
	ui.engine.state.room = {}
	ui.engine.state.offers = [
		{"id": "shot-wager", "kind": "wager", "name": "The Wager Hall",
			"description": ui.engine._room_description("wager"), "required": false},
		{"id": "shot-crucible", "kind": "crucible", "name": "The Crucible",
			"description": ui.engine._room_description("crucible"), "required": false},
		{"id": "shot-battle", "kind": "battle", "name": "Battle",
			"description": ui.engine._room_description("battle"), "required": false}]
	ui.engine.state.votes = {"shot_two": "shot-crucible"}
	ui.engine.state.phase = "route"
	ui._state_changed(ui.engine.state)
	await settle(20)
	await shoot("route_services")

	# The Wager Hall at each of its three states.
	ui.engine._enter_room("wager")
	ui.engine.state.heroes[0].gold = 40
	ui._state_changed(ui.engine.state)
	await settle(20)
	await shoot("wager_stake")
	ui._command("PlaceWager", {"stake": 8})
	await settle(30)
	var seat: Dictionary = ui.snapshot.room.wager[ui.controlled_id]
	ui._toggle_die(str(seat.hand[0].die_id))
	ui._toggle_die(str(seat.hand[3].die_id))
	await settle(30)
	await shoot("wager_hand")
	ui._command("SettleWager", {})
	await settle(30)
	await shoot("wager_settled")

	# The Crucible, and the before/after it shows before any HP is spent.
	ui.engine._enter_room("crucible")
	ui.engine.state.heroes[0].gems[0].carat = 9
	ui._state_changed(ui.engine.state)
	await settle(30)
	await shoot("crucible")
	ui._crucible_preview(ui._hero().gems[0], "temper", {})
	await settle(30)
	await shoot("crucible_preview")
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
