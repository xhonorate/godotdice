extends SceneTree
## Development helper: drives the real interface and writes PNGs of each screen.
## Run with a windowed editor build, for example:
##   godot --path . --script tools/screenshot.gd -- --out user://shots
## Screens are written as menu.png, battle.png, route.png (the seam), inventory.png, journal.png,
## one shot of each inspect sheet: inspect_gem.png, inspect_enemy.png, inspect_die.png,
## and the service rooms that are played rather than read: wager_*.png and crucible_*.png.

const Seam = preload("res://scripts/core/seam.gd")
const Profile = preload("res://scripts/core/profile.gd")
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
	load("res://scripts/services/profile_store.gd").directory_override = out_dir.path_join("profile")
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle(24)
	await shoot("menu")
	# The shop and what its objects open.
	ui.hub_view._hover("mine_cart")
	await settle(20)
	await shoot("hub_hover")
	ui.profile_store.transact(func(profile: Dictionary) -> String:
		profile.gold = 4200
		Profile.mark_seen(profile, ["HEAL", "MEND", "VENOM", "STUN", "TITHE", "ECHO", "MULTISTRIKE", "BULWARK"])
		profile.mines.MIRROR_GROTTO.unlocked = true
		profile.encountered.bosses = ["SLIME_KING"]
		profile.mines.QUARRY.boss_defeated = true
		profile.mines.QUARRY.deepest = 17
		return "")
	for screen in ["jewel_bag", "shopkeeper", "commission_board", "armor_stand", "wall_map", "mine_cart", "door"]:
		ui.screens.open(screen)
		await settle(40)
		await shoot("hub_" + screen)
		ui._close_overlay()
	await settle(6)
	ui.offline_hotseat = true
	ui.controlled_id = "shot_hero"
	ui.engine.new_run({"heroes": [
			{"id": "shot_hero", "hero_id": "ARDOR", "name": "Ardor"},
			{"id": "shot_two", "hero_id": "KAIT", "name": "Kait"},
			{"id": "shot_three", "hero_id": "MAX", "name": "Max"}],
		"mine_id": "QUARRY", "seed": 20260909, "autosave": false})
	await settle(12)
	await shoot("route")
	var battle_id: String = ui.snapshot.offers[0].id
	for offer in ui.snapshot.offers:
		if offer.kind == "battle": battle_id = offer.id
	party(func(): ui._command("VoteRoom", {"offer_id": battle_id}))
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

	# Deeper in the seam, with the meter running high and a teammate's vote cast.
	ui.engine.state.room = {}
	ui.engine.state.enemies = []
	Seam.ensure_layers(ui.engine.state.seam, ui.engine.state.seed, ui.engine.state.mine_id, "", 14)
	ui.engine.state.depth = 6
	ui.engine.state.deepest = 6
	ui.engine.state.position = ui.engine.state.seam.layers["6"][0].id
	ui.engine.state.tremor = 820
	ui.engine._route_offers()
	ui.engine.state.votes = {"shot_two": ui.engine.state.offers[0].id}
	ui._state_changed(ui.engine.state)
	await settle(20)
	await shoot("route_deep")

	# The Wager Hall at each of its three states.
	ui.engine._enter_room("wager")
	ui.engine.state.heroes[0].ore = 40
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

	# The end of an expedition: every hero rides up with a haul, then the table and the numbers.
	ui.engine.state.depth = 6
	for hero in ui.engine.state.heroes:
		for stone in ui.engine._roll_gems(4, 6, false):
			stone.owner_id = hero.id
			hero.haul.append(stone)
	ui.engine._enter_room("lift")
	ui._state_changed(ui.engine.state)
	await settle(10)
	await shoot("lift")
	party(func(): ui._command("VoteLift", {"choice": "ride"}))
	await settle(90)
	await shoot("appraisal_table")
	var pending: Dictionary = ui._profile().pending_return
	ui.appraising = str(pending.gems[2].id)
	ui._queue_render()
	await settle(90)
	await shoot("appraisal_selected")
	ui._decide_return(str(pending.gems[0].id), true)
	ui._decide_return(str(pending.gems[1].id), false)
	await settle(90)
	await shoot("appraisal_decided")
	ui._leave_table()
	await settle(20)
	await shoot("statistics")
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
