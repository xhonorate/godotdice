extends SceneTree
## Shoots one room under every stylization pass in `view/battle/looks.gd`, plus a contact
## sheet with all of them side by side, so a house style can be chosen by looking at it
## instead of by imagining it.
##   godot --path . --script tools/look_gallery.gd -- build/looks [depth:kind ...] [flags]
## Flags: `--looks off,ink*` picks the set (a trailing star takes a whole family), `--amount`
## and `--scale` override every look's default, `--tune depth_gain=7,edge_lo=0.3` moves one
## knob of it, `--zoom` crops the sheet to the middle of the room at 1:1 instead of shrinking
## the frame, and `--tag lo` keeps a sweep from writing over the last one. With nothing given
## it shoots the crystal veins and the magma seam in every look. Needs a window.

const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Looks = preload("res://view/battle/looks.gd")

const DEFAULT_ROOMS: Array = ["10:fight", "18:fight"]

var _out_dir: String = "build/looks"
var _rooms: Array = []
var _looks: Array = []
var _amount: float = -1.0
var _scale: float = -1.0
var _tune: Dictionary = {}
var _tag: String = ""
## Crops the contact sheet to the middle of the room at 1:1 instead of shrinking the whole
## frame: the only way to judge a line a pixel wide.
var _zoom: bool = false

func _init() -> void:
	_read_args(OS.get_cmdline_user_args())
	var failsafe := Timer.new()
	failsafe.wait_time = 6.0 * float(_rooms.size() * _looks.size()) + 40.0
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out_dir))
	for room in _rooms:
		var shots: Array = await _shoot_room(holder, str(room))
		await _contact_sheet(holder, str(room), shots)
	print("looks: ", ", ".join(PackedStringArray(_looks)))
	quit()

func _read_args(args: Array) -> void:
	var rooms: Array = []
	var i: int = 0
	while i < args.size():
		var arg: String = str(args[i])
		if arg == "--looks" and i + 1 < args.size():
			_looks = str(args[i + 1]).split(",", false)
			i += 1
		elif arg == "--amount" and i + 1 < args.size():
			_amount = float(args[i + 1])
			i += 1
		elif arg == "--scale" and i + 1 < args.size():
			_scale = float(args[i + 1])
			i += 1
		elif arg == "--tune" and i + 1 < args.size():
			for pair in str(args[i + 1]).split(",", false):
				var halves: PackedStringArray = str(pair).split("=")
				if halves.size() == 2:
					_tune[str(halves[0])] = int(halves[1]) if str(halves[0]) == "tint_mode" else float(halves[1])
			i += 1
		elif arg == "--tag" and i + 1 < args.size():
			_tag = "_" + str(args[i + 1])
			i += 1
		elif arg == "--zoom":
			_zoom = true
		elif arg.begins_with("--"):
			pass
		elif i == 0:
			_out_dir = arg
		else:
			rooms.append(arg)
		i += 1
	_rooms = rooms if not rooms.is_empty() else DEFAULT_ROOMS
	if _looks.is_empty():
		_looks = Looks.ORDER.duplicate()
	## A trailing star takes the whole family: `--looks off,ink*` is the nine ink settings
	## with the raw frame in front of them.
	var wanted: Array = []
	for id in _looks:
		if str(id).ends_with("*"):
			var stem: String = str(id).trim_suffix("*")
			wanted.append_array(Looks.ORDER.filter(func(k: String) -> bool: return k.begins_with(stem)))
		elif Looks.LOOKS.has(str(id)):
			wanted.append(str(id))
	_looks = wanted

func _shoot_room(holder: Control, room: String) -> Array:
	## One room built once, then worn through every look: the only thing that changes
	## between two of these pictures is the pass.
	var parts: PackedStringArray = room.split(":")
	var depth: int = int(parts[0])
	var kind: String = parts[1] if parts.size() > 1 else "fight"
	var mine: String = DeepContent.starter_mine()
	var character: String = DeepContent.starter_character()
	var profile: Dictionary = DeepProfile.new_profile("Lapidary")
	var loadout: Dictionary = DeepProfile.loadout(profile, character)
	var rng := RandomNumberGenerator.new()
	rng.seed = depth * 977
	var keys: Array = [DeepDescent.warden_key({"mine": mine}, depth)] if kind == "warden" \
		else DeepForge.encounter(rng, DeepContent.mine(mine), depth, 1, kind == "elite")
	var fighters: Array = [DeepBattle.make_player("p0", "Lapidary", character, loadout.rail, loadout.dice)]
	var battle: Dictionary = DeepBattle.begin(fighters, keys, {"depth": depth, "elite": kind == "elite", "warden": kind == "warden"}, rng, rng)
	var screen := BattleScreen.new()
	holder.add_child(screen)
	screen.bind("p0")
	screen.show_state(battle, depth, DeepBattle.forecast(battle, "p0"), {"mine": mine, "kind": kind})
	## The sweep in and the cards settling: everything after this is the pass alone.
	await create_timer(2.8).timeout
	var shots: Array = []
	for id in _looks:
		screen.stage.look.set_look(str(id))
		screen.stage.look.dial(_amount, _scale)
		if not _tune.is_empty():
			screen.stage.look.tune(_tune)
		await create_timer(0.5).timeout
		var image: Image = root.get_viewport().get_texture().get_image()
		var path: String = "%s/%02d_%s_%s%s.png" % [_out_dir, depth, kind, str(id), _tag]
		image.save_png(path)
		shots.append({"id": str(id), "image": image})
		print("saved ", path)
	screen.queue_free()
	await process_frame
	return shots

func _contact_sheet(holder: Control, room: String, shots: Array) -> void:
	## All of them on one page, named, for the side-by-side that a folder of files is not.
	if shots.is_empty():
		return
	var sheet := PanelContainer.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(sheet)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	sheet.add_child(grid)
	var columns: int = 3 if shots.size() > 4 else maxi(2, shots.size())
	grid.columns = columns
	var rows: int = ceili(float(shots.size()) / float(columns))
	var thumb := Vector2i(1600 / columns - 12, 900 / rows - 34)
	for shot in shots:
		var image: Image = (shot.image as Image).duplicate()
		if _zoom:
			## The middle of the room, the HUD left out of it, at one pixel for one pixel.
			var at := Vector2i(800 - thumb.x / 2, 330 - thumb.y / 2)
			image = image.get_region(Rect2i(at.clamp(Vector2i.ZERO, Vector2i(1600, 900) - thumb), thumb))
		else:
			image.resize(thumb.x, thumb.y, Image.INTERPOLATE_LANCZOS)
		var box := VBoxContainer.new()
		var label := Label.new()
		label.text = "%s  ·  %s" % [str(shot.id), str(Looks.LOOKS[str(shot.id)].name)]
		label.add_theme_font_size_override("font_size", 15)
		box.add_child(label)
		var view := TextureRect.new()
		view.texture = ImageTexture.create_from_image(image)
		box.add_child(view)
		grid.add_child(box)
	await create_timer(0.4).timeout
	var path: String = "%s/sheet_%s%s%s.png" % [_out_dir, room.replace(":", "_"), _tag, "_zoom" if _zoom else ""]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	sheet.queue_free()
	await process_frame
