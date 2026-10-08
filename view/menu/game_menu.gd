extends CanvasLayer
## The game menu, opened with Esc or the gear in the corner: resume, settings, the controls,
## and the ways out (abandon the expedition, leave the party, quit to the desktop).
##
## It edits the app's settings dictionary in place and says so with `settings_changed`; the
## app applies and saves them. Everything that ends something asks first.

signal closed
signal settings_changed
signal player_name_changed(player_name: String)
signal abandon_requested
signal leave_requested
signal join_requested(lobby_id: String)
signal quit_requested
## The host of a party run opens a line for the party to come back on: "lan" or "steam".
signal reopen_requested(kind: String)
signal invite_requested

const QUALITY: Array = [["Auto", 0], ["High", 3], ["Medium", 2], ["Low", 1]]
const SPEEDS: Array = [["1×", 1.0], ["2×", 2.0], ["4×", 4.0]]
const CONTROLS: Array = [
	["Right-click", "Inspect a stone, a die or a creature: its full details and a model to turn"],
	["Drag", "Turn the model in the inspector"],
	["1 – 5", "Pick a die to reroll (or click it); at the mouths, 1 – 3 picks a way on"],
	["R", "Reroll the picked dice"],
	["Space", "Lock in your hand"],
	["F", "Fast fights on or off (the Harlequin shifts the picked die instead)"],
	["B", "Open the bag; the whole bench when the bag is not at hand"],
	["M", "Fold out the chart of the stretch"],
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
var _name_field: LineEdit = null
## The Soundtrack page: the mood a piece is auditioned in, and the line saying what plays.
var _audition: String = "explore"
var _now_playing: Label = null

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

func reshow(new_context: Dictionary) -> void:
	## The world behind the menu moved (the line opened, someone came back): the main page
	## says so; any other page is left as it is.
	context = new_context
	if visible and _page == "main":
		_show("main")

func close() -> void:
	if not visible:
		return
	DeepMusic.end_preview()
	visible = false
	DeepAudio.play("ui_close")
	closed.emit()

func _input(event: InputEvent) -> void:
	## While the menu is up, the keyboard belongs to it: no rerolls behind its back.
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _page in ["main", "player_name"]:
			close()
		else:
			_show("settings" if _page == "soundtrack" else "main")
	elif _page == "player_name":
		## Text and navigation keys must reach the editor's controls.
		return
	get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

# --- pages -------------------------------------------------------------------------------------

func _show(page: String) -> void:
	_page = page
	DeepUi.clear(_body)
	_now_playing = null
	_name_field = null
	if page != "soundtrack":
		DeepMusic.end_preview()
	match page:
		"main": _page_main()
		"settings": _page_settings()
		"player_name": _page_player_name()
		"soundtrack": _page_soundtrack()
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

func edit_player_name() -> void:
	_show("player_name")

func _page_player_name() -> void:
	_heading("person", "Player name")
	DeepUi.label(_body, "The name other players see in your party.", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_name_field = LineEdit.new()
	_name_field.max_length = DeepProfile.NAME_LIMIT
	_name_field.text = str(context.get("player_name", DeepProfile.DEFAULT_NAME))
	_name_field.placeholder_text = DeepProfile.DEFAULT_NAME
	_name_field.custom_minimum_size.y = 44
	_body.add_child(_name_field)
	DeepUi.label(_body, "Up to %d characters." % DeepProfile.NAME_LIMIT, 13, DeepUi.MUTED)
	var row := DeepUi.hbox(_body, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.button(row, "Cancel", close, 16)
	var save := DeepUi.primary(row, "check", "Save", _save_player_name, 16)
	save.name = "SavePlayerName"
	save.disabled = _name_field.text.strip_edges().is_empty()
	_name_field.text_changed.connect(func(value: String) -> void: save.disabled = value.strip_edges().is_empty())
	_name_field.text_submitted.connect(func(_value: String) -> void: _save_player_name())
	_focus_name.call_deferred(_name_field)

func _focus_name(field: LineEdit) -> void:
	if visible and is_instance_valid(field) and field.is_inside_tree():
		field.grab_focus()
		field.select_all()

func _save_player_name() -> void:
	var player_name: String = _name_field.text.strip_edges()
	if player_name.is_empty():
		return
	player_name_changed.emit(player_name)
	close()

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
	if in_run and bool(context.get("host", true)) and context.has("party"):
		_party_card(context.party)
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
	elif not bool(context.get("solo", true)):
		## In the workshop with a party: walk out of it, or as its host close it.
		DeepUi.icon_button(list, "door", "Close the party" if bool(context.get("host", true)) else "Leave the party", func() -> void:
			close()
			leave_requested.emit(), 16, DeepUi.BAD)
	DeepUi.icon_button(list, "door", "Quit to desktop", func() -> void: _show("quit"), 16, DeepUi.MUTED)
	for child in list.get_children():
		if child is Button:
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
			child.custom_minimum_size.y = 46

func _party_card(party: Dictionary) -> void:
	## A run with a party in it, as its host sees it from here: who is away, and the line they
	## come back on. A run picked up again from its checkpoint starts with everyone away and no
	## line at all, and this is where the host opens one.
	var card := DeepUi.card(_body, Color(DeepUi.INFO, 0.45), 12)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size.x = 460
	var box := DeepUi.vbox(card, 8)
	var away: Array = party.get("away", [])
	if away.is_empty():
		DeepUi.stat(box, "party", "Everyone is here.", DeepUi.GOOD, 13)
	else:
		DeepUi.stat(box, "party", "Away: %s" % ", ".join(away), DeepUi.MUTED, 13)
	match str(party.get("status", "")):
		"local":
			DeepUi.wrap(box, "Open the party and they can come back to their seats, wherever the run has got to.", 13, DeepUi.PAPER)
			var row := DeepUi.hbox(box, 10)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			DeepUi.icon_button(row, "crown", "Open on LAN", func() -> void: reopen_requested.emit("lan"), 14, DeepUi.ACCENT)
			DeepUi.icon_button(row, "party", "Open on Steam", func() -> void: reopen_requested.emit("steam"), 14, DeepUi.ACCENT)
		"opening":
			DeepUi.stat(box, "hourglass", "Opening a Steam lobby…", DeepUi.ACCENT, 13)
		_:
			var code: String = str(party.get("invite_code", ""))
			var lan: String = str(party.get("lan", ""))
			var row := DeepUi.hbox(box, 10)
			if not code.is_empty():
				DeepUi.stat(row, "party", "Steam lobby %s" % code, DeepUi.PAPER, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				DeepUi.icon_button(row, "copy", "Copy", func() -> void: DisplayServer.clipboard_set(code), 13, DeepUi.MUTED)
				DeepUi.icon_button(row, "person", "Invite", func() -> void: invite_requested.emit(), 13, DeepUi.GOOD)
			elif not lan.is_empty():
				DeepUi.stat(row, "crown", "Friends rejoin at %s" % lan, DeepUi.PAPER, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				DeepUi.icon_button(row, "copy", "Copy", func() -> void: DisplayServer.clipboard_set(lan), 13, DeepUi.MUTED)
			else:
				DeepUi.stat(row, "check", "The party is open.", DeepUi.GOOD, 13)

func _abandon_text() -> String:
	var text: String = "It counts as a fall. Every stone in your bag rolls its salvage die, and only the top face brings it home. Stones you found and set on your rail are safe, and your vault is never touched."
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
	_row(grid, "Ink outlines", _toggle("outlines", true), "Draws the rock and the creatures in line. Off for a few more frames a second.")
	_section(grid, "Sound")
	_row(grid, "Master volume", _slider("master_volume", 0.8))
	_row(grid, "Effects", _slider("sfx_volume", 0.85), "Every sound the game makes is written by the game itself.")
	_row(grid, "Music", _slider("music_volume", 0.6), "The music is written by the game too, note by note, when it is first needed.")
	DeepUi.label(grid, "Soundtrack", 15, DeepUi.PAPER)
	var pieces := DeepUi.icon_button(grid, "pulse", "Choose and listen", func() -> void: _show("soundtrack"), 14, DeepUi.PAPER)
	pieces.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pieces.tooltip_text = "Pick the music for the workshop and for each mine."
	_section(grid, "Comfort")
	_row(grid, "Screen shake", _slider("shake", 1.0))
	_row(grid, "Fewer flashes", _toggle("reduced_motion", false), "Softens the flashes and color smears on heavy blows.")
	_section(grid, "Fights")
	_row(grid, "Fight speed", _choice("speed", SPEEDS, 1.0), "How fast a locked-in turn plays out, every animation with it. F toggles 4× mid-fight.")
	var back := DeepUi.button(_body, "Back", func() -> void: _show("main"), 15)
	DeepUi.voice(back, "ui_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _page_soundtrack() -> void:
	## A piece for each place: click one to choose it and hear it, and the moods underneath
	## play it as it sounds on a walk, in a fight or in a Warden's hall.
	_heading("pulse", "Soundtrack")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	var picks: Dictionary = settings.get("music_picks", {}) if settings.get("music_picks", {}) is Dictionary else {}
	var playing: Dictionary = DeepMusic.previewing()
	for place in DeepScore.PLACES:
		var tone: Color = DeepUi.ACCENT if place == DeepScore.HOME else Color(str(DeepContent.mine(place).get("palette", "c9a26b")))
		var name_label := DeepUi.label(grid, DeepScore.place_name(place), 15, tone.lightened(0.25))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var row := DeepUi.hbox(grid, 6)
		var chosen: String = DeepScore.pick(place, picks)
		for id in DeepScore.tracks_for(place):
			var piece_id: String = str(id)
			var b := DeepUi.button(row, str(DeepScore.track(piece_id).get("name", piece_id)), func() -> void: _choose_piece(place, piece_id), 13)
			b.custom_minimum_size.x = 150
			b.tooltip_text = "Choose and play"
			if piece_id == chosen:
				DeepUi.selected_style(b, tone)
			if piece_id == str(playing.get("track", "")):
				b.add_theme_color_override("font_color", DeepUi.ACCENT_HI)
	var moods := DeepUi.hbox(_body, 6)
	moods.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.label(moods, "Hear it", 14, DeepUi.MUTED)
	for entry in DeepMusic.PREVIEWS:
		var mood: String = str(entry[1])
		var b := DeepUi.button(moods, str(entry[0]), func() -> void:
			_audition = mood
			var now: Dictionary = DeepMusic.previewing()
			if not now.is_empty():
				DeepMusic.preview(str(now.place), str(now.track), mood)
			_show("soundtrack"), 13)
		b.custom_minimum_size.x = 84
		if mood == _audition:
			DeepUi.selected_style(b)
	_now_playing = DeepUi.label(_body, "", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_say_playing()
	var back := DeepUi.button(_body, "Back", func() -> void: _show("settings"), 15)
	DeepUi.voice(back, "ui_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _choose_piece(place: String, piece_id: String) -> void:
	var picks: Dictionary = settings.get("music_picks", {}) if settings.get("music_picks", {}) is Dictionary else {}
	picks = picks.duplicate()
	picks[place] = piece_id
	settings["music_picks"] = picks
	settings_changed.emit()
	DeepMusic.preview(place, piece_id, _audition)
	_show("soundtrack")

func _say_playing() -> void:
	if _now_playing == null or not is_instance_valid(_now_playing):
		return
	var now: Dictionary = DeepMusic.previewing()
	if now.is_empty():
		_now_playing.text = "Click a piece to hear it."
		return
	var title: String = str(DeepScore.track(str(now.track)).get("name", ""))
	var mood: String = ""
	for entry in DeepMusic.PREVIEWS:
		if str(entry[1]) == str(now.mood):
			mood = str(entry[0]).to_lower()
	if DeepMusic.ready_to_play(str(now.track)):
		_now_playing.text = "Playing %s, %s." % [title, mood]
	else:
		_now_playing.text = "Writing %s… (a few seconds, the first time)" % title

func _process(_delta: float) -> void:
	if visible and _page == "soundtrack":
		_say_playing()

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
