extends SceneTree
## Reproducible rendered workshop review. Uses its own disposable saves.
## godot --path . --script tools/review_visual.gd -- [output_directory]
## Snapshots are fixtures, not evidence of naturally earned progression.

var app: Control
var output: String = "build/review-2026-10-19/screens"
var captures: Array = []

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This audit requires a display.")
		quit(2)
		return
	create_timer(180.0).timeout.connect(func() -> void:
		printerr("Rendered review audit timed out")
		quit(2))
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = str(args[0])
	DirAccess.make_dir_recursive_absolute(output)
	DeepSaveStore.override_directory = "user://review_visual"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	app = load("res://view/app.gd").new()
	root.add_child(app)
	await process_frame
	root.size = Vector2i(1600, 900)
	await create_timer(4.0).timeout
	for tab in ["descend", "delvers", "vault", "market", "bestiary", "profile"]:
		app.home.open(tab)
		await _capture("fresh_" + tab)
	app.home.open("descend", true)
	app.home._party_open = true
	app.home._render()
	await _capture("fresh_party")
	app.home._party_open = false
	for page in ["main", "settings", "controls", "soundtrack", "player_name", "quit"]:
		app.open_menu()
		app.menu._show(page)
		await _capture("menu_" + page)
		app.menu.close()
	_fill()
	app._profile_changed()
	for tab in ["descend", "delvers", "vault", "market", "bestiary", "profile"]:
		app.home.open(tab)
		if tab == "vault":
			app.home._vault_view = "collection"
			app.home._render()
		await _capture("full_" + tab)
	app.home._roster_view = "sockets"
	app.home.open("delvers", true)
	await _capture("full_sockets")
	for page in ["wheel", "oven", "contract"]:
		app.home._market_view = page
		app.home.open("market", true)
		await _capture("market_" + page)
	app.home._vault_view = "unappraised"
	app.home.open("vault", true)
	await _capture("full_unappraised")
	root.size = Vector2i(1024, 640)
	for tab in ["descend", "vault", "market"]:
		app.home.open(tab)
		await _capture("small_" + tab)
	var file := FileAccess.open(output.path_join("workshop_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(captures, "\t"))
	print("REVIEW: %d rendered workshop snapshots" % captures.size())
	app.queue_free()
	await process_frame
	await process_frame
	quit()

func _fill() -> void:
	app.profile.gold = 12400
	for key in DeepContent.characters_in_unlock_order():
		DeepProfile.unlock_character(app.profile, str(key))
	var rng := RandomNumberGenerator.new()
	rng.seed = 19026
	for i in range(90):
		var stone := DeepForge.roll_stone(rng, DeepContent.mine("QUARRY"), 4 + i % 20, 4, {"source": "review"}, "review%d" % i)
		DeepProfile.keep(app.profile, stone)
	for i in range(8):
		app.profile.tray.append(DeepForge.roll_stone(rng, DeepContent.mine("QUARRY"), 10, 4, {"source": "review"}, "review_raw%d" % i))
	for mine in DeepContent.mines_in_order():
		app.profile.mines[str(mine)].unlocked = true
	for key in DeepBestiary.in_mine("QUARRY"):
		app.profile.bestiary[str(key)] = {"met": 5, "slain": 3, "lost": 1, "mines": {"QUARRY": 5}, "first": "2026-10-19", "fresh": true}

func _capture(label: String) -> void:
	await create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var result := picture.save_png(output.path_join(label + ".png"))
	var labels: Array = []
	_read_controls(app, labels)
	captures.append({"name": label, "size": str(picture.get_size()), "save_error": result, "controls": labels})
	print("CAPTURE ", label, " ", picture.get_size(), " error=", result)

func _read_controls(node: Node, labels: Array) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Label or node is BaseButton or node is LineEdit:
		labels.append({"type": node.get_class(), "text": str(node.get("text")), "rect": str((node as Control).get_global_rect())})
	for child in node.get_children():
		_read_controls(child, labels)
