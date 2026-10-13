extends RefCounted
## The party, in the top bar: everyone in it as a small portrait marked with where they stand
## (ready, waiting, away, or short of the fare), and the way to bring friends in. A click
## opens the popover: who is in the party and how ready, a showcase for each of them, and how
## to host or join a party over the network.

const Roster = preload("res://view/home/roster.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")

## The marks a member's portrait carries: [glyph, tone, words].
static func standing(home: Control, id: String) -> Array:
	var member: Dictionary = home.lobby.get("members", {}).get(id, {})
	if not bool(member.get("connected", true)):
		return ["hourglass", DeepUi.BAD, "away"]
	if home.member_short(member):
		return ["coin", Color("ffb04a"), "can't pay the fare"]
	if id == str(home.lobby.get("host", "p0")):
		return ["crown", DeepUi.ACCENT, "host"]
	if bool(member.get("ready", false)):
		return ["check", DeepUi.GOOD, "ready"]
	return ["hourglass", DeepUi.MUTED, "not ready"]

static func dock(home: Control, bar: HBoxContainer) -> void:
	var holder := PanelContainer.new()
	var rest := DeepUi.flat(Color(0, 0, 0, 0), Color(DeepUi.LINE, 0.8) if not home._party_open else DeepUi.ACCENT, 8, 4)
	rest.content_margin_left = 6
	rest.content_margin_right = 6
	holder.add_theme_stylebox_override("panel", rest)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.tooltip_text = "The party: who is in it, and how friends join"
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(holder)
	var row := DeepUi.hbox(holder, 6)
	var order: Array = home.lobby.get("order", [])
	for id in order.slice(0, 4):
		var member: Dictionary = home.lobby.members.get(id, {})
		var mark: Array = standing(home, str(id))
		var face := Control.new()
		face.custom_minimum_size = Vector2(32, 32)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
		face.add_child(Roster.Portrait.new(str(member.get("character", DeepContent.starter_character())), Vector2(32, 32)))
		var dot := DeepUi.icon(face, str(mark[0]), 13, mark[1])
		dot.position = Vector2(20, 19)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if order.size() > 4:
		DeepUi.label(row, "+%d" % (order.size() - 4), 13, DeepUi.MUTED)
	var alone: bool = order.size() <= 1
	DeepUi.stat(row, "party", "Play together" if alone else "%d of %d ready" % [_ready_count(home), order.size()], DeepUi.MUTED if alone else DeepUi.PAPER, 13)
	holder.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			DeepAudio.play("ui_open" if not home._party_open else "ui_back", {"volume": 0.7})
			home._party_open = not home._party_open
			home._showcase_of = ""
			home._render())

static func _ready_count(home: Control) -> int:
	return home.lobby.get("order", []).filter(func(id: Variant) -> bool:
		return str(id) == str(home.lobby.get("host", "p0")) or bool(home.lobby.members.get(id, {}).get("ready", false))).size()

static func popover(home: Control, overlay: Control) -> void:
	## The party, opened from the dock: over the page, closed by a click anywhere else.
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			home._party_open = false
			home._showcase_of = ""
			home._render())
	overlay.add_child(catcher)
	var column := HBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.position = Vector2(-24, 62)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(column)
	if not home._showcase_of.is_empty():
		_showcase_panel(home, column)
	var card := DeepUi.card(column, Color(DeepUi.ACCENT, 0.5), 16, Color(DeepUi.INK, 0.97))
	card.custom_minimum_size.x = 470
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := DeepUi.vbox(card, 10)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "party", "The party").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var said: Array = home.STATUS_WORDS.get(home.status, [home.status.capitalize(), DeepUi.MUTED])
	DeepUi.pill(head, "wifi", str(said[0]).get_slice(":", 0), said[1], 12, str(said[0]))
	for id in home.lobby.get("order", []):
		_member_row(home, box, str(id))
	if not str(home.lobby.get("mine", "")).is_empty() and home.lobby.get("order", []).size() > 1:
		var short: Array = home.lobby.get("order", []).filter(func(id: Variant) -> bool: return home.member_short(home.lobby.members.get(id, {})))
		if not short.is_empty():
			DeepUi.stat(box, "coin", "Short of the fare to %s: the way down waits for a mine everyone can afford." % DeepContent.mine_name(home.chosen_mine()), Color("ffb04a"), 12)
	DeepUi.rule(box, Color(DeepUi.LINE, 0.7))
	_play_together(home, box)
	DeepUi.pop_in(card, 0.0, 0.96, 0.2)

static func _member_row(home: Control, box: VBoxContainer, id: String) -> void:
	var member: Dictionary = home.lobby.members.get(id, {})
	var row := DeepUi.hbox(box, 10)
	var character: String = str(member.get("character", DeepContent.starter_character()))
	row.add_child(Roster.Portrait.new(character, Vector2(40, 40)))
	var words := DeepUi.vbox(row, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var named := DeepUi.label(words, str(member.get("name", id)) + (" (you)" if id == home.local_id else ""), 15, DeepUi.PAPER)
	named.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	named.custom_minimum_size.x = 150
	DeepUi.label(words, DeepContent.character_title(character), 12, DeepUi.MUTED)
	var mark: Array = standing(home, id)
	DeepUi.pill(row, str(mark[0]), str(mark[2]), mark[1], 11)
	var shown: Array = DeepProfile.showcase(home.profile) if id == home.local_id else member.get("showcase", [])
	var look := DeepUi.icon_button(row, "star", "", func() -> void:
		home._showcase_of = "" if home._showcase_of == id else id
		home._party_open = true
		home._render(), 13, DeepUi.ACCENT if home._showcase_of == id else DeepUi.MUTED)
	look.tooltip_text = "Their showcase"
	look.disabled = shown.is_empty()
	if home.is_host and id != home.local_id:
		var kick := DeepUi.icon_button(row, "cross_out", "", func() -> void: home.kick_requested.emit(id), 12, DeepUi.BAD)
		kick.tooltip_text = "Send %s back to their own workshop" % str(member.get("name", id))

static func _showcase_panel(home: Control, column: HBoxContainer) -> void:
	## Another member's best stones, as they showed them to the party.
	var id: String = home._showcase_of
	var member: Dictionary = home.lobby.members.get(id, {})
	var stones: Array = DeepProfile.showcase(home.profile) if id == home.local_id else member.get("showcase", [])
	var card := DeepUi.card(column, DeepUi.LINE_HI, 16, Color(DeepUi.INK, 0.97))
	card.custom_minimum_size.x = 360
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := DeepUi.vbox(card, 10)
	DeepUi.section(box, "star", "%s's showcase" % str(member.get("name", id)))
	if stones.is_empty():
		DeepUi.label(box, "Nothing kept yet.", 13, DeepUi.DIM)
	for stone in stones:
		if not stone is Dictionary:
			continue
		var row := DeepUi.hbox(box, 10)
		StoneCard.mini(row, stone, 44)
		var words := DeepUi.vbox(row, 0)
		DeepUi.label(words, DeepUi.skill_name(stone), 14, DeepUi.PAPER)
		var grade: Dictionary = DeepStone.grade(stone)
		DeepUi.label(words, "%s · %d ct · %s · %s" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 0)))], 12, DeepUi.tier_color(str(grade.tier)))
	DeepUi.pop_in(card, 0.0, 0.96, 0.2)

static func _play_together(home: Control, box: VBoxContainer) -> void:
	## Co-op over the network: host or join on a LAN or over Steam, invite, and leave.
	var in_party: bool = home.lobby.get("order", []).size() > 1
	var first: String = ("Close the party first." if home.is_host else "Leave the party first.") if in_party else ""
	if not home.invite_code.is_empty():
		var code := DeepUi.hbox(box, 8)
		DeepUi.stat(code, "party", "Lobby %s" % home.invite_code, DeepUi.PAPER, 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.icon_button(code, "person", "Invite friends", func() -> void: home.invite_requested.emit(), 13, DeepUi.GOOD)
		var copy := DeepUi.icon_button(code, "copy", "Copy ID", Callable(), 13, DeepUi.MUTED)
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(home.invite_code)
			home.cheer_at(copy, "Copied", DeepUi.GOOD))
	var lan_ip: String = DeepSession.lan_address() if home.is_host and home.status == "hosting" and home.invite_code.is_empty() else ""
	if not lan_ip.is_empty():
		var at := DeepUi.hbox(box, 8)
		DeepUi.stat(at, "crown", "Friends on your network join %s" % lan_ip, DeepUi.PAPER, 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var copy_ip := DeepUi.icon_button(at, "copy", "Copy", Callable(), 13, DeepUi.MUTED)
		copy_ip.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(lan_ip)
			home.cheer_at(copy_ip, "Copied", DeepUi.GOOD))
	if home.status in ["local", "offline", "lost"] or not in_party:
		var steam := DeepUi.hbox(box, 8)
		var host_steam := DeepUi.icon_button(steam, "party", "Host on Steam", func() -> void: home.steam_host_requested.emit(), 13, DeepUi.ACCENT)
		home._lobby_field = LineEdit.new()
		home._lobby_field.placeholder_text = "Steam lobby ID"
		home._lobby_field.custom_minimum_size = Vector2(140, 0)
		home._lobby_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		home._lobby_field.text_submitted.connect(func(text: String) -> void:
			if not in_party:
				home.steam_join_requested.emit(text))
		steam.add_child(home._lobby_field)
		var join_steam := DeepUi.icon_button(steam, "play", "Join", func() -> void: home.steam_join_requested.emit(home._lobby_field.text), 13, DeepUi.INFO)
		var lan := DeepUi.hbox(box, 8)
		var host_lan := DeepUi.icon_button(lan, "crown", "Host on LAN", func() -> void: home.host_requested.emit(DeepSession.DEFAULT_PORT), 13, DeepUi.ACCENT)
		home._address = LineEdit.new()
		home._address.text = str(home.settings.get("last_address", "127.0.0.1"))
		home._address.custom_minimum_size = Vector2(140, 0)
		home._address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lan.add_child(home._address)
		var join_lan := DeepUi.icon_button(lan, "play", "Join", func() -> void: home.join_requested.emit(home._address.text, DeepSession.DEFAULT_PORT), 13, DeepUi.INFO)
		for button in [host_lan, join_lan, host_steam, join_steam]:
			button.disabled = in_party
			if in_party:
				button.tooltip_text = first
		DeepUi.wrap(box, "Friends join a Steam lobby from the overlay's invite list, from Join Game in the friends list, or by pasting its ID above.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 430)
	if home.status not in ["local", "offline"]:
		var hosting: bool = home.is_host
		var out := DeepUi.icon_button(box, "prev", "Close the party" if hosting else "Leave the party", func() -> void: home.leave_party_requested.emit(), 13, DeepUi.MUTED)
		out.size_flags_horizontal = Control.SIZE_SHRINK_END
		out.tooltip_text = "Everyone goes back to their own workshop." if hosting else "Back to a workshop of your own."

