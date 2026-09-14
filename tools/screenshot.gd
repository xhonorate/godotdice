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
## `--only=reveals` skips straight to the end-of-fight, appraisal and equipment shots.
var only := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	DirAccess.make_dir_recursive_absolute(out_dir)
	load("res://scripts/services/profile_store.gd").directory_override = out_dir.path_join("profile")
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle(24)
	if only == "reveals":
		await reveals()
		quit(0)
		return
	if only == "rooms":
		await rooms()
		quit(0)
		return
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
	await reveals()
	print("screenshots written to ", ProjectSettings.globalize_path(out_dir))
	quit(0)

func rooms() -> void:
	## Every room that is not a fight, in each of the states worth seeing.
	ui.offline_hotseat = true
	ui.controlled_id = "shot_hero"
	ui.engine.new_run({"heroes": [
			{"id": "shot_hero", "hero_id": "ARDOR", "name": "Ardor"},
			{"id": "shot_two", "hero_id": "KAIT", "name": "Kait"}],
		"mine_id": "QUARRY", "seed": 515151, "autosave": false})
	await settle(10)
	ui.engine.state.depth = 5
	for hero in ui.engine.state.heroes:
		hero.ore = 34
		hero.hp = int(hero.max_hp * 0.6)
		for stone in ui.engine._roll_gems(2, 6, false):
			stone.owner_id = hero.id
			hero.haul.append(stone)
		for found in ui.engine._roll_gems(1, 6, true):
			found.owner_id = hero.id
			hero.gems.append(found)
	var room := func(kind: String, tag: String) -> void:
		ui.engine._events = []
		ui.engine._enter_room(kind)
		ui._state_changed(ui.engine.state)
		await wait(2.5)
		await shoot("room_" + tag)
	for kind in ["shop", "workshop", "lapidary", "rest", "crucible", "treasure", "lift"]:
		await room.call(kind, kind)
	for key in ["ABANDONED_CACHE", "FIELD_MEDIC", "ECHO_SHRINE", "JEWEL_BROKER", "STILL_POOL"]:
		ui.engine._events = []
		ui.engine._enter_room("event")
		ui.engine.state.event.key = key
		for hero in ui.engine.state.heroes:
			var gems: Array = []
			if key in ["JEWEL_BROKER", "ABANDONED_CACHE"]:
				gems = ui.engine._roll_gems(3 if key == "JEWEL_BROKER" else 1, 0, true)
			ui.engine.state.event.offers[hero.id] = gems
		ui._state_changed(ui.engine.state)
		await wait(2.0)
		await shoot("room_event_" + key.to_lower())
	await room.call("wager", "wager_stake")
	ui._command("PlaceWager", {"stake": 8})
	await wait(1.5)
	await shoot("room_wager_hand")
	ui._command("SettleWager", {})
	await wait(1.5)
	await shoot("room_wager_settled")
	await room.call("mine", "mine_vote")
	party(func(): ui._command("VoteVein", {"vein": "crystal"}))
	await wait(1.2)
	await shoot("room_mine_digging")
	await wait(6.0)
	await shoot("room_mine_draft")

func reveals() -> void:
	## The moments that are revealed rather than shown: the end of a fight, the loot turned
	## over, a stone named under the loupe, and the sockets they are dragged into.
	ui.profile_store.transact(func(profile: Dictionary) -> String:
		profile.gold = 4200
		Profile.mark_seen(profile, ["HEAL", "MEND", "VENOM", "STUN", "TITHE", "ECHO", "MULTISTRIKE", "BULWARK"])
		return "")
	for screen in ["armor_stand", "jewel_bag", "wall_map"]:
		ui.screens.open(screen)
		await settle(30)
		await shoot("ux_hub_" + screen)
		ui._close_overlay()
	ui.offline_hotseat = true
	ui.controlled_id = "shot_hero"
	ui.engine.new_run({"heroes": [
			{"id": "shot_hero", "hero_id": "ARDOR", "name": "Ardor"},
			{"id": "shot_two", "hero_id": "KAIT", "name": "Kait"}],
		"mine_id": "QUARRY", "seed": 424242, "autosave": false})
	await settle(10)
	ui.engine._events = []
	ui.engine.state.depth = 4
	ui.engine._enter_room("elite")
	ui._state_changed(ui.engine.state)
	await settle(60)
	await shoot("ux_battle")
	party(func(): ui._command("SetReady", {"ready": true}))
	await settle(40)
	await shoot("ux_resolving")
	ui._skip_playback()
	await settle(10)
	var enemy_moves: Array = ui.Combat.enemy_skills(ui.snapshot.enemies[0]) if not ui.snapshot.enemies.is_empty() else []
	if not enemy_moves.is_empty():
		ui._inspect_stage_skill(str(ui.snapshot.enemies[0].id), str(enemy_moves[0].key))
		await settle(20)
		await shoot("ux_enemy_move")
		ui._close_overlay()
	# Win it outright so the spoils have something to turn over.
	if ui.engine.state.phase == "planning":
		for enemy in ui.engine.state.enemies: enemy.hp = 0
		ui.engine.state.battle_outcome = "victory"
		ui.engine._battle_rewards()
		ui._state_changed(ui.engine.state)
	await wait(0.35)
	await shoot("ux_reward_fanfare")
	await wait(1.4)
	await shoot("ux_reward_turning")
	await wait(3.0)
	await shoot("ux_reward_settled")
	var offer: Dictionary = ui.snapshot.reward_offers.get("shot_hero", {})
	if not offer.get("relics", []).is_empty():
		ui._command("ChooseReward", {"kind": "relic", "offer_id": offer.relics[0].id})
		await wait(0.6)
		await shoot("ux_reward_taken")
	# The boss chest.
	ui.engine._events = []
	ui.engine._enter_room("boss")
	for enemy in ui.engine.state.enemies: enemy.hp = 0
	ui.engine.state.battle_outcome = "victory"
	ui.engine.state.heroes[0].ready = false
	ui.engine._battle_rewards()
	ui._state_changed(ui.engine.state)
	await wait(4.0)
	await shoot("ux_boss_chest")
	var chest: Array = ui.snapshot.reward_offers.get("shot_hero", {}).get("gems", [])
	if not chest.is_empty():
		ui._command("ChooseReward", {"kind": "gem", "offer_id": chest[1].id})
		await wait(0.8)
		await shoot("ux_boss_chest_taken")
	# The equipment board, with a spare gem in reserve.
	ui.engine.state.phase = "route"
	for stone in ui.engine._roll_gems(2, 8, true):
		stone.owner_id = "shot_hero"
		ui.engine.state.heroes[0].gems.append(stone)
	ui._state_changed(ui.engine.state)
	await settle(10)
	ui._show_inventory()
	await settle(40)
	await shoot("ux_inventory")
	ui._close_overlay()
	# A loupe held to a stone mid-run.
	var stone: Dictionary = ui.engine._roll_gems(1, 12, false)[0]
	stone.owner_id = "shot_hero"
	ui.engine.state.heroes[0].haul.append(stone)
	ui.engine.state.heroes[0].loupes = 1
	ui._state_changed(ui.engine.state)
	await settle(6)
	ui._command("AppraiseGem", {"gem_id": stone.id, "method": "loupe"})
	await wait(0.5)
	await shoot("ux_spotlight_sealed")
	await wait(2.2)
	await shoot("ux_spotlight_named")
	ui._close_spotlight()
	# A lost fight.
	ui.engine._events = []
	ui.engine._enter_room("battle")
	for hero in ui.engine.state.heroes:
		for found in ui.engine._roll_gems(2, 4, false):
			found.owner_id = hero.id
			hero.haul.append(found)
		hero.hp = 0
	ui.engine._start_salvage()
	ui._state_changed(ui.engine.state)
	await wait(2.0)
	await shoot("ux_defeat")
	ui._command("RevealSalvage", {"gem_id": ""})
	await wait(0.4)
	await shoot("ux_salvage_rolling")
	await wait(1.6)
	await shoot("ux_salvage_landed")
	# Home again: a stone turned under the loupe, then named.
	ui.engine.state.phase = "route"
	for hero in ui.engine.state.heroes:
		hero.hp = hero.max_hp
		for found in ui.engine._roll_gems(3, 10, false):
			found.owner_id = hero.id
			hero.haul.append(found)
	ui.engine._enter_room("lift")
	ui._state_changed(ui.engine.state)
	await settle(10)
	party(func(): ui._command("VoteLift", {"choice": "ride"}))
	await wait(0.6)
	await shoot("ux_appraisal_reading")
	await wait(2.4)
	await shoot("ux_appraisal_named")

func party(action: Callable) -> void:
	## Issues the same command for every seat so the party actually advances.
	var seat: String = ui.controlled_id
	for hero in ui.snapshot.get("heroes", []):
		ui.controlled_id = str(hero.id)
		action.call()
	ui.controlled_id = seat

func wait(seconds: float) -> void:
	## Reveals run on the clock, not on frames, so their shots are timed the same way.
	await create_timer(seconds).timeout

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shoot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(tag + ".png")
	image.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
