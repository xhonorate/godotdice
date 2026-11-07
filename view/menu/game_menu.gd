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
signal rejoin_requested(record: Dictionary)
signal rejoin_declined
signal quit_requested
## The host of a party run opens a line for the party to come back on: "lan" or "steam".
signal reopen_requested(kind: String)
signal invite_requested

const QUALITY: Array = [["Auto", 0], ["High", 3], ["Medium", 2], ["Low", 1]]
const SPEEDS: Array = [["1×", 1.0], ["2×", 2.0], ["4×", 4.0]]
const COUNTS: Array = [["Full", 1.0], ["Quick", 0.5], ["Off", 0.0]]
const TEXT_SIZES: Array = [["Standard", 0.0], ["Large", 1.0]]
## How to play on the phone: what a finger does, in place of the keys (board sys-touch).
const TOUCHES: Array = [
	["Tap", "Does what a click does: pick a die to reroll, take a way on, an offer or a stone. A first tap on a tunnel shows where it leads"],
	["Hold", "Anything's card: a stone, a die, a creature, a mark. Details on the card opens the close look"],
	["Drag", "A stone into a socket, a die to a new place; turns a model in the close look"],
	["Tap outside", "Puts away a card, a panel or a close look"],
	["Gear", "This menu: settings, how to play and the way out"],
]
const CONTROLS: Array = [
	["Right-click", "Inspect a stone, a die or a creature: its full details and a model to turn"],
	["Drag", "Turn the model in the inspector"],
	["1 – 5", "Pick a die to reroll (or click it); at the mouths, 1 – 3 picks a way on"],
	["1 – 5", "In the workshop, open its tabs, Descend to Bestiary"],
	["Q / E", "In the workshop, step through your delvers"],
	["Enter", "In the workshop, set out from the Descend tab"],
	["R", "Reroll the picked dice"],
	["Space", "Lock in your hand; while a turn plays out, hurry it (so does a click)"],
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
## The party run a guest was in when their game closed: {kind, address, port | lobby, host, mine}.
var _rejoin: Dictionary = {}
var _name_field: LineEdit = null
## Settings opened straight from You on the phone: Done puts the menu away instead of turning
## back to its first page.
var _direct: bool = false

func _init() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	_root = Control.new()
	DeepUi.use_theme(_root)
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
	var style := DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT, 18, 26, 3, 6)
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

func open_settings(app_settings: Dictionary, new_context: Dictionary) -> void:
	## Straight to the settings (the phone's You page has the button for them).
	open(app_settings, new_context)
	_direct = true
	_show("settings")

func reshow(new_context: Dictionary) -> void:
	## The world behind the menu moved (the line opened, someone came back): the main page
	## says so; any other page is left as it is.
	context = new_context
	if visible and _page == "main":
		_show("main")

func close() -> void:
	if not visible:
		return
	visible = false
	_direct = false
	DeepAudio.play("ui_close")
	closed.emit()

func _input(event: InputEvent) -> void:
	## While the menu is up, the keyboard belongs to it: no rerolls behind its back.
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _page in ["main", "player_name"] or (_direct and _page == "settings"):
			close()
		else:
			_show("settings" if _page == "soundtrack" else "main")
	elif _page == "player_name":
		## Text and navigation keys must reach the editor's controls.
		return
	elif event.keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END,
			KEY_PAGEUP, KEY_PAGEDOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		## Let the focused menu control navigate, activate or change its value. Any key
		## it does not use is caught below, before it can reach the game behind the menu.
		return
	get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

# --- pages -------------------------------------------------------------------------------------

func _show(page: String) -> void:
	_page = page
	DeepUi.clear(_body)
	_name_field = null
	if DeepUi.phone:
		_fit_phone(page)
	match page:
		"main": _page_main()
		"settings": _page_settings()
		"player_name": _page_player_name()
		"soundtrack": _page_soundtrack()
		"controls": _page_controls()
		"abandon": _page_confirm("flag", "Abandon today's dig?" if bool(context.get("daily", false)) else "Abandon the expedition?", _abandon_text(), "Abandon", DeepUi.BAD, func() -> void:
			close()
			abandon_requested.emit())
		"leave": _page_confirm("door", "Leave the party?", "You drop out of the expedition and go back to your own workshop. Whatever you carry stays down there with them.", "Leave", DeepUi.BAD, func() -> void:
			close()
			leave_requested.emit())
		"close_party": _page_confirm("door", "Close the party?", "Everyone goes back to their own workshop.", "Close", DeepUi.BAD, func() -> void:
			close()
			leave_requested.emit())
		"quit": _page_confirm("door", "Quit to the desktop?", _quit_text(), "Quit", DeepUi.BAD, func() -> void: quit_requested.emit())
		"rejoin": _page_rejoin()
		"invite": _page_confirm("party", "Join a friend's party?", _invite_text(), "Join", DeepUi.ACCENT, func() -> void:
			close()
			join_requested.emit(_invite))
	if page in ["settings", "controls"]:
		_focus_first.call_deferred()

func ask_to_join(lobby_id: String) -> void:
	## A Steam invitation accepted in the middle of an expedition: leaving it is asked first.
	_invite = lobby_id
	_show("invite")

func ask_to_rejoin(record: Dictionary) -> void:
	## The game closed under a guest in the middle of a party run: as it starts again, going
	## back is offered. Either answer is final, and the run is not offered again.
	_rejoin = record
	_show("rejoin")

func _page_rejoin() -> void:
	_heading("party", "Rejoin your party?")
	var host: String = str(_rejoin.get("host", ""))
	var mine: String = str(DeepContent.mine(str(_rejoin.get("mine", ""))).get("name", ""))
	var party: String = ("%s's party" % host) if not host.is_empty() else "a party"
	var text: String = "Your game closed while you were on a run with %s%s. If the run is still going, you take your seat again where you left it." % [party, (" in %s" % mine) if not mine.is_empty() else ""]
	var words := DeepUi.wrap(_body, text, 15, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 500)
	words.custom_minimum_size.x = 500
	var row := DeepUi.hbox(_body, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var later := DeepUi.button(row, "Not now", func() -> void:
		close()
		rejoin_declined.emit(), 16)
	DeepUi.voice(later, "ui_back")
	var record: Dictionary = _rejoin
	var go := DeepUi.primary(row, "party", "Rejoin", func() -> void:
		close()
		rejoin_requested.emit(record), 16, DeepUi.ACCENT)
	_focus.call_deferred(go)

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

func _focus_first() -> void:
	if not visible:
		return
	for button in _body.find_children("*", "Button", true, false):
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			_focus(button)
			return

func _heading(glyph: String, text: String, tone: Color = DeepUi.ACCENT) -> void:
	var row := DeepUi.hbox(_body, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(row, glyph, DeepUi.pt(18) if DeepUi.phone else 30.0, tone)
	DeepUi.title(row, text, 27 if DeepUi.phone else 30, tone.lightened(0.2))

func _fit_phone(page: String) -> void:
	## The phone's card for each page: the settings take the whole screen inside its safe
	## edges; every other page is a card in the middle, as narrow as its words let it be.
	var area: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(DeepUi.PHONE_CANVAS)
	var style := DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT, 18, int(DeepUi.pt(10)), 3, 6)
	_panel.add_theme_stylebox_override("panel", style)
	_body.add_theme_constant_override("separation", int(DeepUi.pt(6)))
	match page:
		"settings", "soundtrack":
			_panel.custom_minimum_size = Vector2(area.x - DeepUi.safe_left - DeepUi.safe_right - DeepUi.pt(12), area.y - DeepUi.safe_top - DeepUi.safe_bottom - DeepUi.pt(12))
		"main":
			_panel.custom_minimum_size = Vector2(DeepUi.pt(260), 0)
		_:
			_panel.custom_minimum_size = Vector2(DeepUi.pt(380), 0)

func _page_main() -> void:
	if DeepUi.phone:
		_page_main_phone()
		return
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
	var resume := DeepUi.icon_button(list, "play", "Resume", close, 18, DeepUi.PAPER)
	DeepUi.voice(resume, "ui_confirm")
	## Gold only while the keyboard is on it. Filled for good, it still looked chosen with
	## the focus moved down to Settings, and the menu showed two picks at once.
	resume.focus_entered.connect(func() -> void: _gold(resume, true))
	resume.focus_exited.connect(func() -> void: _gold(resume, false))
	_focus.call_deferred(resume)
	DeepUi.icon_button(list, "gear", "Settings", func() -> void: _show("settings"), 16, DeepUi.PAPER)
	DeepUi.icon_button(list, "book", "Controls", func() -> void: _show("controls"), 16, DeepUi.PAPER)
	if in_run:
		if bool(context.get("host", true)):
			var give_up := DeepUi.icon_button(list, "flag", "Abandon the dig" if bool(context.get("daily", false)) else "Abandon expedition", func() -> void: _show("abandon"), 16, DeepUi.BAD)
			give_up.add_theme_color_override("font_color", DeepUi.BAD.lightened(0.2))
			give_up.disabled = str(context.get("phase", "")) in ["salvage", "over"]
		else:
			DeepUi.icon_button(list, "door", "Leave the party", func() -> void: _show("leave"), 16, DeepUi.BAD)
	elif not bool(context.get("solo", true)):
		## In the workshop with a party: walk out of it, or as its host close it.
		## Closing sends everyone home, so the host is asked first.
		DeepUi.icon_button(list, "door", "Close the party" if bool(context.get("host", true)) else "Leave the party", func() -> void:
			if bool(context.get("host", true)):
				_show("close_party")
			else:
				close()
				leave_requested.emit(), 16, DeepUi.BAD)
	DeepUi.icon_button(list, "door", "Quit to desktop", func() -> void: _show("quit"), 16, DeepUi.MUTED)
	for child in list.get_children():
		if child is Button:
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
			child.custom_minimum_size.y = 46

func _page_main_phone() -> void:
	## The phone's menu (board run-menu): Resume, Settings, How to play and the way out, 40
	## points each. A game on iOS is not quit from inside it; Android's is closed.
	_heading("gear", "Menu")
	var in_run: bool = bool(context.get("in_run", false))
	var where: String = "In the workshop"
	if in_run:
		where = "In the mine · depth %d" % int(context.get("depth", 0))
		if not bool(context.get("solo", true)):
			where += " · the dig goes on"
	DeepUi.label(_body, where, 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if in_run and bool(context.get("host", true)) and context.has("party"):
		_party_card(context.party)
	var list := DeepUi.vbox(_body, int(DeepUi.pt(6)))
	var resume := DeepUi.primary(list, "play", "Resume", close, 14)
	DeepUi.voice(resume, "ui_confirm")
	_focus.call_deferred(resume)
	DeepUi.icon_button(list, "gear", "Settings", func() -> void: _show("settings"), 13, DeepUi.PAPER)
	DeepUi.icon_button(list, "book", "How to play", func() -> void: _show("controls"), 13, DeepUi.PAPER)
	if in_run:
		if bool(context.get("host", true)):
			var give_up := DeepUi.icon_button(list, "flag", "Leave the dig" if bool(context.get("daily", false)) else "Leave the run", func() -> void: _show("abandon"), 13, DeepUi.BAD)
			give_up.add_theme_color_override("font_color", DeepUi.BAD.lightened(0.2))
			give_up.disabled = str(context.get("phase", "")) in ["salvage", "over"]
		else:
			DeepUi.icon_button(list, "door", "Leave the party", func() -> void: _show("leave"), 13, DeepUi.BAD)
	elif not bool(context.get("solo", true)):
		DeepUi.icon_button(list, "door", "Close the party" if bool(context.get("host", true)) else "Leave the party", func() -> void:
			if bool(context.get("host", true)):
				_show("close_party")
			else:
				close()
				leave_requested.emit(), 13, DeepUi.BAD)
	if OS.get_name() != "iOS":
		DeepUi.icon_button(list, "door", "Close the game", func() -> void: _show("quit"), 13, DeepUi.MUTED)
	for child in list.get_children():
		if child is Button:
			child.custom_minimum_size.y = DeepUi.pt(40)
			if child != resume:
				child.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _gold(b: Button, on: bool) -> void:
	## Dresses a menu button as the page's call to action (the accent fill, ink on it) or
	## back as a plain one.
	var states: Array = ["normal", "hover", "pressed"]
	var inked: Array = ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]
	if not on:
		for state in states:
			b.remove_theme_stylebox_override(state)
		for key in inked:
			b.remove_theme_color_override(key)
		b.add_theme_color_override("icon_normal_color", DeepUi.PAPER)
		b.add_theme_color_override("icon_hover_color", DeepUi.PAPER.lightened(0.25))
		return
	## The theme's padding, not the call to action's wider one, so the words do not shift as
	## the focus comes and goes.
	var pressed := DeepUi.button_style(DeepUi.ACCENT.darkened(0.25), DeepUi.ACCENT)
	pressed.shadow_offset = Vector2(1, 1)
	b.add_theme_stylebox_override("normal", DeepUi.button_style(DeepUi.ACCENT, DeepUi.ACCENT.lightened(0.35)))
	b.add_theme_stylebox_override("hover", DeepUi.button_style(DeepUi.ACCENT.lightened(0.15), Color.WHITE))
	b.add_theme_stylebox_override("pressed", pressed)
	for key in inked:
		b.add_theme_color_override(key, DeepUi.INK)

func _party_card(party: Dictionary) -> void:
	## A run with a party in it, as its host sees it from here: who is away, and the line they
	## come back on. A run picked up again from its checkpoint starts with everyone away and no
	## line at all, and this is where the host opens one.
	var card := DeepUi.card(_body, Color(DeepUi.INFO, 0.45), 12)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if not DeepUi.phone else Control.SIZE_FILL
	card.custom_minimum_size.x = 0.0 if DeepUi.phone else 460.0
	var box := DeepUi.vbox(card, 8)
	var away: Array = party.get("away", [])
	if away.is_empty():
		_wrap_stat(DeepUi.stat(box, "party", "Everyone is here.", DeepUi.GOOD, 12 if DeepUi.phone else 13))
	else:
		_wrap_stat(DeepUi.stat(box, "party", "Away: %s" % ", ".join(away), DeepUi.MUTED, 12 if DeepUi.phone else 13))
	match str(party.get("status", "")):
		"local":
			DeepUi.wrap(box, "Open the party and they can come back to their seats, wherever the run has got to.", 12 if DeepUi.phone else 13, DeepUi.PAPER)
			var row := DeepUi.hbox(box, 10)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			## A phone opens the party on its Wi-Fi only: Steam is the desktop game's.
			DeepUi.icon_button(row, "crown", "Open on this Wi-Fi" if DeepUi.phone else "Open on LAN", func() -> void: reopen_requested.emit("lan"), 14, DeepUi.ACCENT)
			if not DeepUi.phone:
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

static func _wrap_stat(row: HBoxContainer) -> void:
	## A stat's words wrapped on the phone's narrow card; the desk's stay on one line.
	if not DeepUi.phone:
		return
	for child in row.get_children():
		if child is Label:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(child as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(child as Label).custom_minimum_size.x = DeepUi.pt(180)

func _abandon_text() -> String:
	var text: String = "It counts as a fall. Every stone in your bag rolls its salvage die, and only the top face brings it home. Stones you found and set on your rail are safe, and your vault is never touched."
	if bool(context.get("daily", false)):
		## A daily keeps nothing and only scores, and a fall scores no pyrite.
		text = "It counts as a fall: the pyrite you carry scores nothing, and only the stones whose salvage die shows its top face count toward today's score. Nothing from a daily dig is kept."
		if str(context.get("phase", "")) == "landing":
			text += "\n\nThe lift is right here: riding it up banks your whole score."
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
	var wide: float = DeepUi.pt(350) if DeepUi.phone else 500.0
	var words := DeepUi.wrap(_body, text, 13 if DeepUi.phone else 15, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER, wide)
	words.custom_minimum_size.x = wide
	var row := DeepUi.hbox(_body, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := DeepUi.button(row, "Go back", func() -> void: _show("main"), 14 if DeepUi.phone else 16)
	DeepUi.voice(back, "ui_back")
	_focus.call_deferred(back)
	var go := DeepUi.primary(row, glyph, verb, act, 14 if DeepUi.phone else 16, tone)
	if DeepUi.phone:
		back.custom_minimum_size = Vector2(DeepUi.pt(120), DeepUi.pt(40))
		go.custom_minimum_size = Vector2(DeepUi.pt(120), DeepUi.pt(40))

func _page_settings() -> void:
	if DeepUi.phone:
		_page_settings_phone()
		return
	_heading("gear", "Settings")
	## Two columns: in one, the page ran off the foot of the screen once Text size and Color
	## marks joined it.
	var columns := DeepUi.hbox(_body, 48)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	var grid := _grid(columns)
	_section(grid, "Display")
	_row(grid, "Fullscreen", _toggle("fullscreen", false))
	_row(grid, "Vertical sync", _toggle("vsync", true))
	_row(grid, "Graphics", _choice("quality", QUALITY, 0), "Auto starts high and eases off if fights run slow.")
	_row(grid, "Soften edges (FXAA)", _toggle("fxaa", false), "Runs a smoothing pass over the room on top of the multisampling: softer ink creases and crystal edges, a softer picture with them. Low graphics always has it.")
	_row(grid, "Ink outlines", _toggle("outlines", true), "Draws the rock and the creatures in line. Off for a few more frames a second.")
	_section(grid, "Sound")
	_row(grid, "Master volume", _slider("master_volume", 0.8))
	_row(grid, "Effects", _slider("sfx_volume", 0.85), "Every sound the game makes is written by the game itself.")
	_row(grid, "Music", _slider("music_volume", 0.6), "The music is written by the game too, from a few lines of score for each piece.")
	## Soundtrack selection is intentionally not exposed in the player menu.
	grid = _grid(columns)
	_section(grid, "Comfort")
	_row(grid, "Screen shake", _slider("shake", 1.0))
	_row(grid, "Fewer flashes", _toggle("reduced_motion", false), "Softens the flashes and color smears on heavy blows.")
	_row(grid, "Rumble", _toggle("rumble", true), "Shakes a gamepad (or a phone) as dice count, gems fire and blows land.")
	_row(grid, "Text size", _choice("text_size", TEXT_SIZES, 0.0), "Large sets the smallest words on every screen at the biggest size the screens still fit. A small window already shows them that size.")
	_row(grid, "Color marks", _marks(), "Marks each color with the shape its stones are cut in: Red a triangle, Blue a square, Green a heart, Violet a pear, Gold a hexagon, White a circle, Opal an oval. On stones, empty sockets and color dots.")
	_section(grid, "Fights")
	_row(grid, "Fight speed", _choice("speed", SPEEDS, 1.0), "How fast a locked-in turn plays out, every animation with it. F toggles 4× mid-fight; a click or Space hurries one turn.")
	_row(grid, "Gem count", _choice("count", COUNTS, 1.0), "How each gem counts its number out before it fires: every die and multiplier (Full), the same twice as fast (Quick), or only the total (Off). In a party, the host's choice.")
	var back := DeepUi.button(_body, "Back", func() -> void: _show("main"), 15)
	DeepUi.voice(back, "ui_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _page_settings_phone() -> void:
	## The phone's settings (board home-you): the whole screen in two columns, a row 34 points
	## tall. No Fullscreen, Vertical sync or Text size (one size on a phone, already large);
	## Rumble is Vibration; the version number lives here.
	var head := DeepUi.hbox(_body, int(DeepUi.pt(8)))
	DeepUi.icon(head, "gear", DeepUi.pt(18), DeepUi.ACCENT)
	DeepUi.title(head, "Settings", 27, DeepUi.ACCENT.lightened(0.2))
	DeepUi.spacer(head)
	var done := DeepUi.icon_button(head, "check", "Done", func() -> void:
		if _direct:
			close()
		else:
			_show("main"), 13, DeepUi.PAPER)
	DeepUi.ledger_button(done, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 8)
	done.custom_minimum_size = Vector2(DeepUi.pt(90), DeepUi.pt(36))
	DeepUi.voice(done, "ui_back")
	var columns := DeepUi.hbox(_body, int(DeepUi.pt(24)))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := _grid(columns)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section(grid, "Sound")
	_row(grid, "Master volume", _slider("master_volume", 0.8))
	_row(grid, "Effects", _slider("sfx_volume", 0.85))
	_row(grid, "Music", _slider("music_volume", 0.6))
	_section(grid, "Fights")
	_row(grid, "Fight speed", _choice("speed", SPEEDS, 1.0))
	_row(grid, "Gem count", _choice("count", COUNTS, 1.0))
	_section(grid, "Picture")
	_row(grid, "Graphics", _choice("quality", QUALITY, 0))
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", int(DeepUi.pt(6)))
	pair.add_child(_toggle("fxaa", false))
	DeepUi.label(pair, "Ink outlines", 13, DeepUi.PAPER).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pair.add_child(_toggle("outlines", true))
	_row(grid, "Soften edges", pair)
	grid = _grid(columns)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section(grid, "Comfort")
	_row(grid, "Screen shake", _slider("shake", 1.0))
	_row(grid, "Fewer flashes", _toggle("reduced_motion", false))
	_row(grid, "Vibration", _toggle("rumble", true))
	_row(grid, "Color marks", _marks())
	_section(grid, "The game")
	var how_label := DeepUi.label(grid, "How to play", 13, DeepUi.PAPER)
	how_label.custom_minimum_size.y = DeepUi.pt(34)
	how_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var how := DeepUi.icon_button(grid, "book", "Open", func() -> void: _show("controls"), 12, DeepUi.PAPER)
	how.custom_minimum_size = Vector2(DeepUi.pt(80), DeepUi.pt(30))
	how.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	how.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.label(grid, "Deep Cut v%s" % str(ProjectSettings.get_setting("application/config/version", "")), 11, DeepUi.MUTED)

func _page_soundtrack() -> void:
	## A piece for each place: click one to make it the one that plays there.
	_heading("pulse", "Soundtrack")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	var picks: Dictionary = settings.get("music_picks", {}) if settings.get("music_picks", {}) is Dictionary else {}
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
			b.tooltip_text = "Play this one here"
			if piece_id == chosen:
				DeepUi.selected_style(b, tone)
	var back := DeepUi.button(_body, "Back", func() -> void: _show("settings"), 15)
	DeepUi.voice(back, "ui_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _choose_piece(place: String, piece_id: String) -> void:
	var picks: Dictionary = settings.get("music_picks", {}) if settings.get("music_picks", {}) is Dictionary else {}
	picks = picks.duplicate()
	picks[place] = piece_id
	settings["music_picks"] = picks
	settings_changed.emit()
	_show("soundtrack")

func _grid(parent: Node) -> GridContainer:
	## One column of the settings: a name and its control on each row.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(10)) if DeepUi.phone else 22)
	grid.add_theme_constant_override("v_separation", int(DeepUi.pt(2)) if DeepUi.phone else 12)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(grid)
	return grid

func _marks() -> HBoxContainer:
	## The color marks' switch, and the marks themselves beside it, so the setting shows what
	## it puts on the screen before it is switched on.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_toggle("color_marks", false))
	DeepUi.gap(row, 4)
	for key in ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE", "OPAL"]:
		var mark := DeepUi.ColorMark.new(str(key), DeepUi.pt(12) if DeepUi.phone else 18.0, true)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		mark.tooltip_text = str(DeepContent.color(str(key)).get("name", key))
		row.add_child(mark)
	return row

func _section(grid: GridContainer, text: String) -> void:
	var head := DeepUi.heading(grid, text, 11 if DeepUi.phone else 12, DeepUi.ACCENT)
	head.custom_minimum_size.y = DeepUi.pt(16) if DeepUi.phone else 26.0
	head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var rule := Control.new()
	grid.add_child(rule)

func _row(grid: GridContainer, text: String, control: Control, hint: String = "") -> void:
	var name_label := DeepUi.label(grid, text, 13 if DeepUi.phone else 15, DeepUi.PAPER)
	## A row 30 points tall on the phone, the name in its middle (the board's 34 ran the left
	## column past the screen's safe foot).
	if DeepUi.phone:
		name_label.custom_minimum_size.y = DeepUi.pt(30)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	## Likewise a rumble switched on is felt at once.
	if key == "rumble" and bool(value):
		DeepAudio.rumble(0.4, 0.5, 0.15)

func _toggle(key: String, fallback: bool) -> CheckButton:
	var box := CheckButton.new()
	box.button_pressed = bool(settings.get(key, fallback))
	if DeepUi.phone:
		box.custom_minimum_size = Vector2(DeepUi.pt(DeepUi.FINGER_LEAST), DeepUi.pt(DeepUi.FINGER_LEAST))
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
	slider.step = 0.05
	slider.value = float(settings.get(key, fallback))
	slider.custom_minimum_size = Vector2(DeepUi.pt(130), DeepUi.pt(30)) if DeepUi.phone else Vector2(190, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	## The engine gives a slider no focus look of its own: the kit's white ring, while the
	## keyboard or a pad is on it (a click leaves it off, as it does on a button).
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", DeepUi.focus_ring(8, 3.0))
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	slider.add_child(ring)
	slider.focus_entered.connect(func() -> void: ring.visible = slider.has_focus(true))
	slider.focus_exited.connect(func() -> void: ring.visible = false)
	var readout := DeepUi.label(row, "%d%%" % int(round(slider.value * 100.0)), 11 if DeepUi.phone else 14, DeepUi.MUTED)
	readout.custom_minimum_size.x = DeepUi.pt(32) if DeepUi.phone else 44.0
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
		var b := DeepUi.button(row, str(option[0]), Callable(), 12 if DeepUi.phone else 14)
		b.custom_minimum_size = Vector2(DeepUi.pt(44), DeepUi.pt(30)) if DeepUi.phone else Vector2(62, 0)
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
	if DeepUi.phone:
		_page_touches()
		return
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

func _page_touches() -> void:
	## How to play on the phone: what a finger does (board sys-touch).
	_heading("book", "How to play")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(10)))
	grid.add_theme_constant_override("v_separation", int(DeepUi.pt(5)))
	_body.add_child(grid)
	for entry in TOUCHES:
		var key := PanelContainer.new()
		var style := DeepUi.flat(Color(DeepUi.LINE, 0.35), DeepUi.LINE_HI, 6, 4)
		style.border_width_bottom = 3
		style.content_margin_left = DeepUi.pt(6)
		style.content_margin_right = DeepUi.pt(6)
		key.add_theme_stylebox_override("panel", style)
		key.size_flags_horizontal = Control.SIZE_SHRINK_END
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(key)
		DeepUi.label(key, str(entry[0]), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.wrap(grid, str(entry[1]) + ".", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, DeepUi.pt(260))
	var back := DeepUi.button(_body, "Back", func() -> void: _show("settings" if _direct else "main"), 13)
	DeepUi.voice(back, "ui_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(DeepUi.pt(120), DeepUi.pt(40))
