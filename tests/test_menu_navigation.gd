extends SceneTree
## Real input dispatch: menus must accept navigation without leaking play shortcuts.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	DeepSaveStore.override_directory = "user://test_menu_navigation"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json", "held.json"]:
		scratch.remove(file)
	root.size = Vector2i(1600, 900)
	var app: Control = load("res://view/app.gd").new()
	root.add_child(app)
	await process_frame
	await process_frame
	app.open_menu()
	await process_frame
	var resume: Control = root.gui_get_focus_owner()
	check(resume is Button and resume.text == "Resume", "opening the menu focuses Resume")
	var focus_stayed: bool = true
	for step in range(app.menu._body.find_children("*", "Button", true, false).size() * 2):
		_key(KEY_TAB)
		var focused: Control = root.gui_get_focus_owner()
		focus_stayed = focus_stayed and focused != null and app.menu._body.is_ancestor_of(focused)
	check(focus_stayed and root.gui_get_focus_owner() == resume, "Tab cycles within the menu and returns to Resume")
	_key(KEY_TAB)
	var next: Control = root.gui_get_focus_owner()
	check(next is Button and next.text == "Settings", "Tab moves from Resume to Settings")
	_key(KEY_ENTER)
	await process_frame
	check(app.menu._page == "settings", "Enter opens the focused Settings button")
	# Continue the other checks even when the first navigation step failed.
	app.menu._show("settings")
	await process_frame
	var first: Control = root.gui_get_focus_owner()
	check(first is CheckButton and app.menu._body.is_ancestor_of(first), "settings starts with a focused toggle")
	var slider: HSlider = _find_slider(app.menu)
	slider.grab_focus()
	var old_volume: float = slider.value
	_key(KEY_LEFT)
	check(slider.value < old_volume and is_equal_approx(float(app.settings.master_volume), slider.value), "arrow keys adjust the focused volume slider")
	var old_speed: float = app.session.speed
	_key(KEY_F)
	check(is_equal_approx(app.session.speed, old_speed), "gameplay shortcuts stay blocked behind the menu")
	var soundtrack: Button = _find_button(app.menu, "Choose music")
	check(soundtrack == null, "Soundtrack selection stays inaccessible from Settings by design")
	_key(KEY_ESCAPE)
	check(app.menu._page == "main" and app.menu.is_open(), "Escape returns from settings to the main menu")
	await process_frame
	_key(KEY_ENTER)
	check(not app.menu.is_open(), "Enter activates the focused Resume button")
	app.menu.close()
	for character in ["VESPER", "CADENCE"]:
		DeepProfile.unlock_character(app.profile, character)
	app.home.open("delvers")
	_key(KEY_E)
	check(app.home._roster_pick == "VESPER", "E browses to Vesper's dossier")
	_key(KEY_E)
	check(app.home._roster_pick == "CADENCE", "a second E advances to Cadence's dossier")
	_key(KEY_Q)
	check(app.home._roster_pick == "VESPER", "Q goes back from the viewed dossier")
	check(app.profile.current_character == "ARDOR", "browsing dossiers leaves the chosen delver unchanged")
	app.home.open("descend")
	app.home._party_open = true
	app.home._render()
	await process_frame
	# Capture the address without starting a network connection from this input regression.
	app.home.join_requested.disconnect(app._join)
	var joins: Array = []
	app.home.join_requested.connect(func(address: String, port: int) -> void: joins.append([address, port]))
	app.home._address.text = "192.168.0.42"
	app.home._address.grab_focus()
	_key(KEY_ENTER)
	check(joins == [["192.168.0.42", DeepSession.DEFAULT_PORT]], "Enter submits the focused LAN address")
	check(not app.session.in_run(), "submitting a LAN address does not start an expedition")
	print("Menu navigation: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _key(keycode: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = down
		root.push_input(event)

func _find_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node
	for child in node.get_children():
		var found := _find_slider(child)
		if found != null:
			return found
	return null

func _find_button(node: Node, words: String) -> Button:
	if node is Button and node.text == words:
		return node
	for child in node.get_children():
		var found := _find_button(child, words)
		if found != null:
			return found
	return null

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
