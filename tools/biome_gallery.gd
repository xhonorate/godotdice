extends SceneTree
## Renders the battle screen in every biome of the shaft, one picture each, for looking at
## the rooms side by side without playing down to them.
##   godot --path . --script tools/biome_gallery.gd -- build/biomes [depth:kind ...]
## With no depths given it shoots one room per biome band plus a Warden's hall and the Rift.
## Add ":party" to a room (e.g. 14:fight:party) to seat a second player beside you.
## Needs a window.

const BattleScreen = preload("res://view/battle/battle_screen.gd")

const DEFAULT_ROOMS: Array = ["2:fight", "6:fight", "8:warden", "10:elite", "14:fight", "18:fight", "22:fight", "24:warden", "28:fight", "36:fight"]

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var out_dir: String = str(args[0]) if args.size() > 0 else "build/biomes"
	var rooms: Array = args.slice(1) if args.size() > 1 else DEFAULT_ROOMS
	var failsafe := Timer.new()
	failsafe.wait_time = 20.0 * float(rooms.size()) + 20.0
	failsafe.one_shot = true
	failsafe.autostart = true
	failsafe.timeout.connect(func() -> void: quit(1))
	root.add_child(failsafe)
	root.size = Vector2i(1600, 900)
	var holder := Control.new()
	holder.theme = DeepUi.theme()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	var mine: String = DeepContent.starter_mine()
	var character: String = DeepContent.starter_character()
	var profile: Dictionary = DeepProfile.new_profile("Lapidary")
	var loadout: Dictionary = DeepProfile.loadout(profile, character)
	for room in rooms:
		var parts: PackedStringArray = str(room).split(":")
		var depth: int = int(parts[0])
		var kind: String = parts[1] if parts.size() > 1 else "fight"
		var rng := RandomNumberGenerator.new()
		rng.seed = depth * 977
		var keys: Array = []
		if kind == "warden":
			keys = [DeepDescent.warden_key({"mine": mine}, depth)]
		else:
			keys = DeepForge.encounter(rng, DeepContent.mine(mine), depth, 1, kind == "elite")
		var fighters: Array = [DeepBattle.make_player("p0", "Lapidary", character, loadout.rail, loadout.dice)]
		## "depth:kind:party" shoots a room with a second player, to see the ally cards.
		if parts.size() > 2 and parts[2] == "party":
			fighters.append(DeepBattle.make_player("p1", "Ash", character, loadout.rail, loadout.dice))
		var battle: Dictionary = DeepBattle.begin(fighters, keys, {"depth": depth, "elite": kind == "elite", "warden": kind == "warden"}, rng, rng)
		var screen := BattleScreen.new()
		holder.add_child(screen)
		screen.bind("p0")
		screen.show_state(battle, depth, DeepBattle.forecast(battle, "p0"), {"mine": mine, "kind": kind})
		await create_timer(2.6).timeout
		var image: Image = root.get_viewport().get_texture().get_image()
		var path: String = "%s/room_%02d_%s.png" % [out_dir, depth, kind]
		image.save_png(path)
		print("saved ", path)
		screen.queue_free()
		await process_frame
	quit()
