extends SceneTree
## Renders the battle screen in every biome of every mine, one picture each, for looking at
## the rooms side by side without playing down to them.
##   godot --path . --script tools/biome_gallery.gd -- build/biomes [MINE:stretch:kind ...]
## With no rooms given it shoots every stretch of every mine (three each, one per Warden
## passed) and the Quarry's first Warden's hall. A room is a mine, which stretch of it (0, 1
## or 2) and what kind of room; add ":party" (QUARRY:0:fight:party) to seat a second player.
## Needs a window.

const BattleScreen = preload("res://view/battle/battle_screen.gd")

static func default_rooms() -> Array:
	var out: Array = []
	for mine in DeepContent.mines_in_order():
		for stretch in range(3):
			out.append("%s:%d:fight" % [mine, stretch])
	out.append("QUARRY:0:warden")
	return out

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var out_dir: String = str(args[0]) if args.size() > 0 else "build/biomes"
	var rooms: Array = args.slice(1) if args.size() > 1 else default_rooms()
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
	var character: String = DeepContent.starter_character()
	var profile: Dictionary = DeepProfile.new_profile("Lapidary")
	var loadout: Dictionary = DeepProfile.loadout(profile, character)
	for room in rooms:
		var parts: PackedStringArray = str(room).split(":")
		var mine: String = parts[0]
		var stretch: int = int(parts[1]) if parts.size() > 1 else 0
		var kind: String = parts[2] if parts.size() > 2 else "fight"
		## A depth inside that stretch: just past the Warden that opens it.
		var opens: Array = [0] + DeepContent.mine(mine).get("warden_depths", [])
		var depth: int = (int(opens[mini(stretch, opens.size() - 1)]) + 2) if not DeepContent.is_endless(mine) else stretch * 8 + 2
		if kind == "warden" and not DeepContent.is_endless(mine) and stretch + 1 < opens.size():
			depth = int(opens[stretch + 1])
		var rng := RandomNumberGenerator.new()
		rng.seed = depth * 977
		var keys: Array = []
		if kind == "warden":
			keys = [DeepDescent.warden_key({"mine": mine}, depth)]
		else:
			keys = DeepForge.encounter(rng, DeepContent.mine(mine), depth, 1, kind == "elite")
		var fighters: Array = [DeepBattle.make_player("p0", "Lapidary", character, loadout.rail, loadout.dice)]
		## "depth:kind:party" shoots a room with a second player, to see the ally cards.
		if parts.size() > 3 and parts[3] == "party":
			fighters.append(DeepBattle.make_player("p1", "Ash", character, loadout.rail, loadout.dice))
		var battle: Dictionary = DeepBattle.begin(fighters, keys, {"depth": depth, "elite": kind == "elite", "warden": kind == "warden"}, rng, rng)
		var screen := BattleScreen.new()
		holder.add_child(screen)
		screen.bind("p0")
		screen.show_state(battle, depth, DeepBattle.forecast(battle, "p0"), {"mine": mine, "kind": kind, "phase": stretch})
		await create_timer(2.6).timeout
		var image: Image = root.get_viewport().get_texture().get_image()
		var path: String = "%s/%s_%d_%s.png" % [out_dir, mine.to_lower(), stretch, kind]
		image.save_png(path)
		print("saved ", path)
		screen.queue_free()
		await process_frame
	quit()
