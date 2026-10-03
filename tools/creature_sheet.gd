extends SceneTree
## A contact sheet of creatures: each one on the inspector's turntable, photographed and
## laid out in a grid with its name, so a new model can be looked at without a run. Opens a
## window (it renders), writes one PNG:
##
##   /path/to/Godot --path . --script tools/creature_sheet.gd -- build/creatures.png            # every creature
##   /path/to/Godot --path . --script tools/creature_sheet.gd -- build/quarry.png RAIL_RAT PIT_MOLE THE_DRILL

const CreatureStage = preload("res://view/creatures/creature_stage.gd")
const CELL := Vector2i(300, 340)
const COLUMNS: int = 6

var _out: String = "build/creatures.png"
var _keys: Array = []

func _init() -> void:
	var args: Array = Array(OS.get_cmdline_user_args()).filter(func(a: Variant) -> bool: return not str(a).begins_with("--"))
	if not args.is_empty():
		_out = str(args[0])
	_keys = args.slice(1) if args.size() > 1 else DeepContent.section("creatures").keys()
	_keys.sort()
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var columns: int = mini(COLUMNS, _keys.size())
	var rows: int = int(ceil(float(_keys.size()) / float(columns)))
	var sheet := Image.create(columns * CELL.x, rows * CELL.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("14161e"))
	var font: Font = ThemeDB.fallback_font
	var index: int = 0
	for key in _keys:
		var def: Dictionary = DeepContent.creature(str(key))
		var stage: Control = CreatureStage.new(str(key), bool(def.get("warden", false)))
		stage.position = Vector2(16, 16)
		stage.size = Vector2(CELL.x, CELL.y - 40)
		root.add_child(stage)
		await create_timer(1.1).timeout
		stage.set("_spin", 0.0)
		stage.set("_turn", 0.55)
		var viewport: SubViewport = stage.get("_viewport")
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for _i in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = viewport.get_texture().get_image()
		if shot != null and not shot.is_empty():
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(CELL.x, CELL.y - 40)
			var at := Vector2i((index % columns) * CELL.x, (index / columns) * CELL.y)
			sheet.blend_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), at)
			_label(sheet, font, "%s · %d hp · threat %s" % [str(def.get("name", key)), int(def.get("hp", 0)), str(def.get("threat", "?"))], at + Vector2i(8, CELL.y - 30))
		stage.queue_free()
		await process_frame
		print("shot ", key)
		index += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.get_base_dir()))
	var error := sheet.save_png(_out)
	print("sheet: ", _out, " (", error_string(error), ")")
	quit(0 if error == OK else 1)

func _label(sheet: Image, font: Font, text: String, at: Vector2i) -> void:
	## Text drawn through a tiny viewport, since Image has no text of its own.
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL.x - 8, 28)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("e8e2d4"))
	label.position = Vector2(2, 4)
	vp.add_child(label)
	root.add_child(vp)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	vp.queue_free()
