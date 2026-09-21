extends CanvasLayer
## The game menu, opened with Esc or the gear in the corner: resume, settings, the controls,
## and the ways out (abandon the expedition, leave the party, quit to the desktop).
##
## It edits the app's settings dictionary in place and says so with `settings_changed`; the
## app applies and saves them. Everything that ends something asks first.

signal closed
signal settings_changed
signal abandon_requested
signal leave_requested
signal join_requested(lobby_id: String)
signal quit_requested

const QUALITY: Array = [["Auto", 0], ["High", 3], ["Medium", 2], ["Low", 1]]
const SPEEDS: Array = [["1×", 1.0], ["2×", 2.0], ["4×", 4.0]]
const CONTROLS: Array = [
	["Right-click", "Inspect a stone, a die or a creature: its full details and a model to turn"],
	["Drag", "Turn the model in the inspector"],
	["1 – 5", "Pick a die to reroll (or click it)"],
	["R", "Reroll the picked dice"],
	["Space", "Lock in your hand"],
	["F", "Fast fights on or off"],
	["Wheel", "Scroll the map back up the trail"],
	["Esc", "This menu; closes the inspector"],
]

var settings: Dictionary = {}
## {in_run, host, solo, depth, mine}: what the ways out should offer.
var context: Dictionary = {}
var _root: Control
var _body: VBoxContainer
var _panel: PanelContainer
var _page: String = "main"
var _invite: String = ""

func _init() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	_root = Control.new()
	_root.theme = DeepUi.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.01, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	_panel = PanelContainer.new()
	var style := DeepUi.raised(Color(0.045, 0.055, 0.08, 0.98), Color(DeepUi.ACCENT, 0.6), 18, 26, 0.7)
	style.set_border_width_all(2)
	style.shadow_color = Color(DeepUi.ACCENT, 0.18)
	style.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(560, 0)
	centre.add_child(_panel)
	_body = DeepUi.vbox(_panel, 14)

func is_open() -> bool:
	return visible

func open(app_settings: Dictionary, new_context: Dictionary) -> void:
	settings = app_settings
	context = new_context
	visible = true
	DeepAudio.play("ui_open")
	_show("main")
	if DisplayServer.get_name() != "headless":
		_root.modulate.a = 0.0
		var tween := _root.create_tween()
		tween.tween_property(_root, "modulate:a", 1.0, 0.16)
		DeepUi.pop_in(_panel, 0.0, 0.95, 0.22)

func close() -> void:
	if not visible:
		return
	visible = false
	DeepAudio.play("ui_close")
	closed.emit()

func _input(event: InputEvent) -> void:
	## While the menu is up, the keyboard belongs to it: no rerolls behind its back.
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _page == "main":
			close()
		else:
			_show("main")
	get_viewport().set_input_as_handled()

# --- pages -------------------------------------------------------------------------------------

func _show(page: String) -> void:
	_page = page
	DeepUi.clear(_body)
	match page:
		"main": _page_main()
		"settings": _page_settings()
		"controls": _page_controls()
		"abandon": _page_confirm("flag", "Abandon the expedition?", _abandon_text(), "Abandon", DeepUi.BAD, func() -> void:
			close()
			abandon_requested.emit())
		"leave": _page_confirm("door", "Leave the party?", "You drop out of the expedition and go back to your own workshop. Whatever you carry stays down there with them.", "Leave", DeepUi.BAD, func() -> void:
			close()
			leave_requested.emit())
		"quit": _page_confirm("door", "Quit to the desktop?", _quit_text(), "Quit", DeepUi.BAD, func() -> void: quit_requested.emit())
		"invite": _page_confirm("party", "Join a friend's party?", _invite_text(), "Join", DeepUi.ACCENT, func() -> void:
			close()
			join_requested.emit(_invite))

func ask_to_join(lobby_id: String) -> void:
	## A Steam invitation accepted in the middle of an expedition: leaving it is asked first.
	_invite = lobby_id
	_show("invite")

func _focus(button: Button) -> void:
	## Deferred, and the page may have moved on by then.
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()

func _heading(glyph: String, text: String, tone: Color = DeepUi.ACCENT) -> void:
	var row := DeepUi.hbox(_body, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(row, glyph, 30, tone)
	DeepUi.title(row, text, 30, tone.lightened(0.2))

func _page_main() -> void:
	_heading("gear", "Menu")
	var in_run: bool = bool(context.get("in_run", false))
	var where: String = "In the workshop"
	if in_run:
		where = "%s  ·  depth %d" % [str(context.get("mine", "The mine")), int(context.get("depth", 0))]
		where += "  ·  the dig is paused" if bool(context.get("solo", true)) else "  ·  the dig goes on while you are here"
	DeepUi.label(_body, where, 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var list := DeepUi.vbox(_body, 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.custom_minimum_size = Vector2(340, 0)
	var resume := DeepUi.primary(list, "play", "Resume", close, 18)
	_focus.call_deferred(resume)
	DeepUi.icon_button(list, "gear", "Settings", func() -> void: _show("settings"), 16, DeepUi.PAPER)
	DeepUi.icon_button(list, "book", "Controls", func() -> void: _show("controls"), 16, DeepUi.PAPER)
	if in_run:
		if bool(context.get("host", true)):
			var give_up := DeepUi.icon_button(list, "flag", "Abandon expedition", func() -> void: _show("abandon"), 16, DeepUi.BAD)
			give_up.add_theme_color_override("font_color", DeepUi.BAD.lightened(0.2))
			give_up.disabled = str(context.get("phase", "")) in ["salvage", "over"]
		else:
			DeepUi.icon_button(list, "door", "Leave the party", func() -> void: _show("leave"), 16, DeepUi.BAD)
	DeepUi.icon_button(list, "door", "Quit to desktop", func() -> void: _show("quit"), 16, DeepUi.MUTED)
	for child in list.get_children():
		if child is Button:
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
			child.custom_minimum_size.y = 46

func _abandon_text() -> String:
	var text: String = "It counts as a fall. Every raw stone you carry rolls its salvage die, and only the top face brings it home. Stones set in your rail are safe."
	if not bool(context.get("solo", true)):
		text += "\n\nThe whole party climbs out with you."
	return text

func _quit_text() -> String:
	if bool(context.get("in_run", false)):
		if bool(context.get("host", true)):
			return "The expedition is saved at the last tunnel or landing, and picks up from there next time."
		return "You will drop out of the party."
	return "Everything in the workshop is saved."

func _invite_text() -> String:
	var text: String = "You leave this expedition for theirs. " + _quit_text()
	if bool(context.get("host", true)) and not bool(context.get("solo", true)):
		text += "\n\nYour party waits at the last landing until you reopen it."
	return text

func _page_confirm(glyph: String, title: String, text: String, verb: String, tone: Color, act: Callable) -> void:
	_heading(glyph, title, tone)
	var words := DeepUi.wrap(_body, text, 15, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 500)
	words.custom_minimum_size.x = 500
	var row := DeepUi.hbox(_body, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := DeepUi.button(row, "Go back", func() -> void: _show("main"), 16)
	DeepUi.voice(back, "ui_back")
	_focus.call_deferred(back)
	DeepUi.primary(row, glyph, verb, act, 16, tone)

func _page_settings() -> void:
	_heading("gear", "Settings")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	_section(grid, "Display")
	_row(grid, "Fullscreen", _toggle("fullscreen", false))
	_row(grid, "Vertical sync", _toggle("vsync", true))
	_row(grid, "Graphics", _choice("quality", QUALITY, 0), "Auto starts high and eases off if fights run slow.")
	_section(grid, "Sound")
	_row(grid, "Master volume", _slider("master_volume", 0.8))
	_row(grid, "Effects", _slider("sfx_volume", 0.85), "Every sound the game makes is written by the game itself.")
	_section(grid, "Comfort")
	_row(grid, "Screen shake", _slider("shake", 1.0))
	_row(grid, "Fewer flashes", _toggle("reduced_motion", false), "Softens the flashes and colour smears on heavy blows.")
	_section(grid, "Fights")
	_row(grid, "Fight speed", _choice("speed", SPEEDS, 1.0), "How fast a locked-in turn plays out, every animation with it. F toggles 4× mid-fight.")
	var back := DeepUi.button(_body, "Back", func() -> void: _show("main"), 15)
	DeepUi.voice(back, "ui_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _section(grid: GridContainer, text: String) -> void:
	var head := DeepUi.heading(grid, text, 12, DeepUi.ACCENT)
	head.custom_minimum_size.y = 26
	head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var rule := Control.new()
	grid.add_child(rule)

func _row(grid: GridContainer, text: String, control: Control, hint: String = "") -> void:
	var name_label := DeepUi.label(grid, text, 15, DeepUi.PAPER)
	name_label.tooltip_text = hint
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS if not hint.is_empty() else Control.MOUSE_FILTER_IGNORE
	control.tooltip_text = hint
	grid.add_child(control)

func _changed(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()
	## A level you cannot hear is a level you cannot set: every nudge gives you something.
	if key.ends_with("_volume"):
		DeepAudio.play("ui_tap", {"gap": 0.1})

func _toggle(key: String, fallback: bool) -> CheckButton:
	var box := CheckButton.new()
	box.button_pressed = bool(settings.get(key, fallback))
	box.focus_mode = Control.FOCUS_ALL
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	## Just the switch: the button look the theme gives every Button would make it a bar.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		box.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	box.toggled.connect(func(on: bool) -> void:
		DeepAudio.play("ui_toggle")
		_changed(key, on))
	return box

func _slider(key: String, fallback: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = float(settings.get(key, fallback))
	slider.custom_minimum_size = Vector2(190, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := DeepUi.label(row, "%d%%" % int(round(slider.value * 100.0)), 14, DeepUi.MUTED)
	readout.custom_minimum_size.x = 44
	slider.value_changed.connect(func(value: float) -> void:
		readout.text = "%d%%" % int(round(value * 100.0))
		_changed(key, value))
	return row

func _choice(key: String, options: Array, fallback: Variant) -> HBoxContainer:
	## A row of buttons, one lit: for settings with a handful of values.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var current: float = float(settings.get(key, fallback))
	var buttons: Array = []
	for option in options:
		var b := DeepUi.button(row, str(option[0]), Callable(), 14)
		b.custom_minimum_size.x = 62
		buttons.append(b)
		if is_equal_approx(float(option[1]), current):
			DeepUi.selected_style(b)
	for i in range(buttons.size()):
		var value: Variant = options[i][1]
		buttons[i].pressed.connect(func() -> void:
			for other in buttons:
				other.remove_theme_stylebox_override("normal")
				other.remove_theme_stylebox_override("hover")
			DeepUi.selected_style(buttons[i])
			_changed(key, value))
	return row

func _page_controls() -> void:
	_heading("book", "Controls")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)
	for entry in CONTROLS:
		var key := PanelContainer.new()
		var style := DeepUi.flat(Color(DeepUi.LINE, 0.35), DeepUi.LINE_HI, 6, 4)
		style.border_width_bottom = 3
		style.content_margin_left = 10
		style.content_margin_right = 10
		key.add_theme_stylebox_override("panel", style)
		key.size_flags_horizontal = Control.SIZE_SHRINK_END
		grid.add_child(key)
		DeepUi.label(key, str(entry[0]), 14, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		var words := DeepUi.label(grid, str(entry[1]), 14, DeepUi.MUTED)
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var back := DeepUi.button(_body, "Back", func() -> void: _show("main"), 15)
	DeepUi.voice(back, "ui_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
