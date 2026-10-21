extends SceneTree
## Rendered interaction audit. Uses only an isolated review profile.
## godot --path . --script tools/review_menus.gd

const Inspector = preload("res://view/inspect/inspector.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const OUT := "res://build/review-2026-10-19"
var checks: Array = []
var failures: Array = []

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This audit requires a display.")
		quit(2)
		return
	DeepSaveStore.override_directory = "user://review_menus_20261019"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json", "held.json"]:
		scratch.remove(file)
	root.size = Vector2i(1600, 900)
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("Menu audit timed out")
		quit(2))
	var app: Control = load("res://view/app.gd").new()
	root.add_child(app)
	await create_timer(1.0).timeout
	for index in range(app.home.TABS.size()):
		_key(KEY_1 + index)
		await _settle()
		check(app.home.tab == str(app.home.TABS[index][0]), "Fresh profile: shortcut opens " + str(app.home.TABS[index][1]))
	await _click(app.home._bar.get_node("PlayerName"))
	check(app.home.tab == "profile", "Player chip opens Profile")
	await _click_named(app.home, "Change name")
	check(app.menu._page == "player_name", "Profile opens name editor")
	if app.menu._name_field == null:
		quit(1)
		return
	app.menu._name_field.text = "Review Delver"
	_key(KEY_ENTER)
	await _settle()
	check(app.profile.name == "Review Delver" and not app.menu.is_open(), "Name editor submits and closes")
	_key(KEY_ESCAPE)
	await _settle()
	check(app.home.tab == "descend", "Escape leaves Profile")
	_key(KEY_ESCAPE)
	await _settle()
	_key(KEY_TAB)
	_key(KEY_ENTER)
	await _settle()
	check(app.menu._page == "settings", "Menu: Tab and Enter open Settings in a real window")
	check(Rect2(Vector2.ZERO, Vector2(1600, 900)).encloses(app.menu._panel.get_global_rect()), "Settings panel fits the minimum logical canvas")
	_key(KEY_ESCAPE)
	await _settle()
	await _click_named(app.menu, "Controls")
	check(app.menu._page == "controls", "Controls opens by mouse")
	_key(KEY_ESCAPE)
	await _settle()
	await _click_named(app.menu, "Quit to desktop")
	check(app.menu._page == "quit", "Quit asks for confirmation")
	await _click_named(app.menu, "Go back")
	check(app.menu._page == "main", "Quit can be cancelled")
	_key(KEY_ESCAPE)
	await _settle()
	for character in DeepContent.characters_in_unlock_order():
		DeepProfile.unlock_character(app.profile, str(character))
	app.profile.gold = 99999
	app._profile_changed()
	_key(KEY_2)
	await _settle()
	_key(KEY_E)
	_key(KEY_E)
	await _settle()
	check(app.home._roster_pick == "CADENCE", "Repeated E browses through multiple delvers")
	await _click_named(app.home, "Change their sockets")
	check(app.home._roster_view == "sockets" and app.profile.current_character == "CADENCE", "Changing sockets chooses the viewed delver")
	_key(KEY_ESCAPE)
	await _settle()
	check(app.home._roster_view == "dossier" and not app.menu.is_open(), "Escape leaves sockets before opening the menu")
	_key(KEY_3)
	await _settle()
	var search: LineEdit = app.home.find_child("Search_vault", true, false)
	await _click(search)
	search.text = "no stone can match this sentence"
	search.text_changed.emit(search.text)
	await create_timer(0.4).timeout
	check(_find_label(app.home, "No stone matches.") != null, "Vault search shows an explicit empty result")
	check(root.gui_get_focus_owner() == search, "Filtering the vault keeps keyboard focus")
	search.text = ""
	search.text_changed.emit("")
	await create_timer(0.4).timeout
	search.release_focus()
	_key(KEY_4)
	await _settle()
	for entry in [["The Wheel", "wheel"], ["The Oven", "oven"], ["Trade-up contract", "contract"]]:
		var label: Label = _find_label(app.home, str(entry[0]))
		await _click(label)
		check(app.home._market_view == str(entry[1]), "Market opens " + str(entry[0]))
		_key(KEY_ESCAPE)
		await _settle()
		check(app.home._market_view == "main" and not app.menu.is_open(), "Escape returns from " + str(entry[0]))
	var stone: Dictionary = app.profile.vault.values()[0].duplicate(true)
	stone.id = "review_compare"
	stone.carat = int(stone.carat) + 2
	stone.appraised = true
	Inspector.stone(stone)
	await _inspect_pages("appraised stone", app)
	Inspector.stone(DeepStone.make("STRIKE", 3, 1, 3, [], {}, "review_raw"))
	await _inspect_pages("raw stone", app)
	Inspector.stone(DeepStone.birthstone("ARDOR"))
	await _inspect_pages("Birthstone", app)
	Inspector.die(DeepDice.make("D6", "review_die"))
	await _inspect_pages("die", app)
	Inspector.geode(DeepEconomy.shelf(app.profile)[0], {"profile": app.profile})
	await _inspect_pages("Geode odds", app)
	for enemy in ["CAVE_GRUB", "THE_FOREMAN"]:
		if DeepContent.section("creatures").has(enemy):
			Inspector.creature(DeepCreatures.make(enemy, "review_foe", 8, 1))
			await _inspect_pages(enemy, app)
	Inspector.lapidary("VESPER")
	await _inspect_pages("new delver announcement", app)
	# Appraisal runs through the actual animated loupe, then commits its decision.
	var raw: Dictionary = DeepStone.make("STRIKE", 7, 2, 3, [], {}, "review_appraisal")
	app.profile.tray.append(raw)
	app.home._appraise_pick = str(raw.id)
	app.home.open("vault")
	await _settle()
	await _click_named(app.home, "Read it")
	await create_timer(0.3).timeout
	var loupe: Control = _find_property(app.home, "_finished")
	if loupe != null:
		await _click(loupe)
	await _settle()
	check(bool(raw.appraised), "Loupe animation appraises the stone")
	var keep: Button = _find_button(app.home, "Keep it, replace yours")
	if keep != null:
		await _click(keep)
	check(not app.profile.tray.has(raw), "Appraisal Keep decision removes the stone from the tray")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var output := FileAccess.open(OUT.path_join("menu-interaction.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Rendered menu audit: %d checks, %d failures" % [checks.size(), failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	app.queue_free()
	await _settle()
	quit(0 if failures.is_empty() else 1)

func _inspect_pages(kind: String, app: Control) -> void:
	await _settle()
	check(Inspector.is_open(), "Inspector opens: " + kind)
	if not Inspector.is_open():
		return
	var sheet: CanvasLayer = Inspector._sheet
	var pages: Array = sheet._pages
	for index in range(pages.size()):
		check(bool(pages[index].box.visible), "Inspector page: %s / %s" % [kind, str(pages[index].name)])
		_key(KEY_RIGHT)
	var gem: Control = _find_property(sheet._stage, "_manual")
	if gem != null:
		var before: Quaternion = gem._manual
		var at: Vector2 = gem.get_global_rect().get_center()
		_mouse(at, true)
		var motion := InputEventMouseMotion.new()
		motion.position = at + Vector2(80, 30)
		motion.global_position = motion.position
		motion.relative = Vector2(80, 30)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		_mouse(motion.position, false)
		check(not gem._manual.is_equal_approx(before), "Dragging rotates the model: " + kind)
	var previous: float = app.session.speed
	_key(KEY_F)
	check(is_equal_approx(app.session.speed, previous), "Inspector blocks play shortcuts: " + kind)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	await _settle()
	check(not Inspector.is_open() and not app.menu.is_open(), "Closing inspector does not open the pause menu: " + kind)

func _settle() -> void:
	await create_timer(0.35).timeout

func _click(control: Control) -> void:
	if control == null:
		check(false, "Required click target exists")
		return
	var point: Vector2 = control.get_global_rect().get_center()
	_mouse(point, true)
	await process_frame
	_mouse(point, false)
	await _settle()

func _click_named(node: Node, words: String) -> void:
	var button := _find_button(node, words)
	check(button != null, "Visible button exists: " + words)
	await _click(button)

func _mouse(at: Vector2, down: bool) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event, true)

func _key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event)

func _find_button(node: Node, words: String) -> Button:
	if node is Button and node.text == words and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_button(child, words)
		if found != null:
			return found
	return null

func _find_label(node: Node, words: String) -> Label:
	if node is Label and node.text == words and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_label(child, words)
		if found != null:
			return found
	return null

func _find_property(node: Node, property: String) -> Control:
	if node is Control and node.get(property) != null and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_property(child, property)
		if found != null:
			return found
	return null

func check(ok: bool, words: String) -> void:
	checks.append({"pass": ok, "description": words})
	if not ok:
		failures.append(words)
		printerr("AUDIT FAIL: " + words)
