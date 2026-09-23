extends SceneTree
## Renders the walk from one room to the next at every biome seam, a few pictures down each
## tunnel, so the way rock, light and air turn from one biome to the next can be looked at
## without playing down to it.
##   godot --path . --script tools/tunnel_gallery.gd -- build/tunnels [from_depth ...]
## With no depths given it walks out of every landing that ends a band (4, 8, 12, 16, 20,
## 24) into the depth below it. Needs a window.

const MineStage = preload("res://view/run/mine_stage.gd")

const DEFAULT_SEAMS: Array = [4, 8, 12, 16, 20, 24]
const MOMENTS: Array = [0.3, 0.5, 0.68, 0.84]

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var out_dir: String = str(args[0]) if args.size() > 0 else "build/tunnels"
	var seams: Array = args.slice(1).map(func(a: String) -> int: return int(a)) if args.size() > 1 else DEFAULT_SEAMS
	var failsafe := Timer.new()
	failsafe.wait_time = 12.0 * float(seams.size()) + 20.0
	failsafe.one_shot = true
	failsafe.autostart = true
	failsafe.timeout.connect(func() -> void: quit(1))
	root.add_child(failsafe)
	root.size = Vector2i(1600, 900)
	var holder := Control.new()
	holder.theme = DeepUi.theme()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var stage: Control = MineStage.new()
	holder.add_child(stage)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	var mine: String = DeepContent.starter_mine()
	for depth in seams:
		var from: Dictionary = {"key": "%s|%d|landing" % [mine, depth], "mine": mine, "depth": depth, "kind": "landing", "exits": 2, "drop": 2.5}
		var to: Dictionary = {"key": "%s|%d|fight" % [mine, depth + 1], "mine": mine, "depth": depth + 1, "kind": "fight", "exits": 2, "drop": 2.5}
		stage.show_room(from, true)
		await create_timer(0.8).timeout
		_save("%s/seam_%02d_a_room.png" % [out_dir, depth])
		stage.walk(to, 0)
		stage.frozen = true
		while not stage._pending.is_empty():
			(stage._pending.pop_front() as Callable).call()
		for moment in MOMENTS:
			stage._travel.t = float(moment)
			stage._advance(0.0)
			await create_timer(0.35).timeout
			_save("%s/seam_%02d_b_%02d.png" % [out_dir, depth, int(float(moment) * 100.0)])
		stage.frozen = false
		stage.hurry()
		await create_timer(0.8).timeout
		_save("%s/seam_%02d_c_room.png" % [out_dir, depth])
		print("seam %d -> %d" % [depth, depth + 1])
	quit()

func _save(path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(path)
