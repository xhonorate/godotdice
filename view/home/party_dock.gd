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
		## Lit by the Birthstone they go down in: two of one delver in a party are told apart.
		face.add_child(Roster.Portrait.new(str(member.get("character", DeepContent.starter_character())), Vector2(32, 32), false, false, false, _stone_of(home, str(id))))
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

static func _stone_of(home: Control, id: String) -> Dictionary:
	## The Birthstone a member goes down in: their own word for it, and for this player what
	## the workshop has on the delver now (the lobby hears of a change a moment later).
	var member: Dictionary = home.lobby.get("members", {}).get(id, {})
	if id == home.local_id and str(member.get("character", "")) == str(home.profile.get("current_character", "")):
		return Roster.worn_stone(home.profile, str(member.get("character", "")))
	return Roster.member_stone(member)

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
	if DeepUi.phone:
		## The phone's party: a panel down the right side, the screen's full height.
		column.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		column.offset_right = 0.0
		column.offset_top = 0.0
		column.offset_bottom = 0.0
		column.add_theme_constant_override("separation", int(DeepUi.pt(6)))
	overlay.add_child(column)
	if not home._showcase_of.is_empty():
		_showcase_panel(home, column)
	var card := DeepUi.card(column, Color(DeepUi.ACCENT, 0.5), 16, Color(DeepUi.INK, 0.97))
	card.custom_minimum_size.x = 470
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if DeepUi.phone:
		var side := StyleBoxFlat.new()
		side.bg_color = DeepUi.LEDGER_FILL
		side.border_color = DeepUi.ACCENT_DIM
		side.border_width_left = int(DeepUi.pt(1.5))
		side.content_margin_left = DeepUi.pt(10)
		side.content_margin_right = DeepUi.safe_right + DeepUi.pt(8)
		side.content_margin_top = DeepUi.pt(8)
		side.content_margin_bottom = DeepUi.safe_bottom + DeepUi.pt(6)
		card.add_theme_stylebox_override("panel", side)
		card.custom_minimum_size.x = DeepUi.pt(310) + DeepUi.safe_right
	var box := DeepUi.vbox(card, int(DeepUi.pt(6)) if DeepUi.phone else 10)
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
	if not DeepUi.phone:
		DeepUi.pop_in(card, 0.0, 0.96, 0.2)

static func _member_row(home: Control, box: VBoxContainer, id: String) -> void:
	var member: Dictionary = home.lobby.members.get(id, {})
	var row := DeepUi.hbox(box, 10)
	var character: String = str(member.get("character", DeepContent.starter_character()))
	## The Birthstone they go down in lights their plate and, when it is not their first, is
	## named after them ("Ardor · Rampart"): two Ardors in a party read as two delvers.
	var stone: Dictionary = _stone_of(home, id)
	row.add_child(Roster.Portrait.new(character, Vector2(DeepUi.pt(28), DeepUi.pt(28)) if DeepUi.phone else Vector2(40, 40), false, false, false, stone))
	var words := DeepUi.vbox(row, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Named as the party sees them ("Player 2" when two share a name), your own marked YOU
	## before it, as on the seat tabs in a run.
	var line := DeepUi.hbox(words, 6)
	if id == home.local_id:
		DeepUi.you_badge(line)
	var named := DeepUi.label(line, home.member_name(id), 15, DeepUi.PAPER)
	named.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	named.custom_minimum_size.x = 110
	named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wears: bool = not Roster.is_first(character, stone)
	var going := DeepUi.label(words, Roster.named(character, stone), 12, Roster.stone_tone(stone) if wears else DeepUi.MUTED)
	going.name = "GoingAs"
	if wears:
		going.mouse_filter = Control.MOUSE_FILTER_PASS
		going.tooltip_text = "%s, wearing %s\n%s" % [DeepContent.character_title(character), str(stone.get("name", "")), str(stone.get("text", ""))]
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
		kick.tooltip_text = "Send %s back to their own workshop" % home.member_name(id)

static func _showcase_panel(home: Control, column: HBoxContainer) -> void:
	## Another member's best stones, as they showed them to the party.
	var id: String = home._showcase_of
	var member: Dictionary = home.lobby.members.get(id, {})
	var stones: Array = DeepProfile.showcase(home.profile) if id == home.local_id else member.get("showcase", [])
	var card := DeepUi.card(column, DeepUi.LINE_HI, 16, Color(DeepUi.INK, 0.97))
	card.custom_minimum_size.x = DeepUi.pt(240) if DeepUi.phone else 360.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := DeepUi.vbox(card, 10)
	DeepUi.section(box, "star", "%s's showcase" % home.member_name(id))
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
	if (home.status in ["local", "offline", "lost"] or not in_party) and DeepUi.phone:
		## No Steam on a phone: the party is found on the same Wi-Fi.
		DeepUi.section(box, "wifi", "Play on this Wi-Fi", DeepUi.ACCENT, 11)
		var host := DeepUi.icon_button(box, "crown", "Host a party here", func() -> void: home.host_requested.emit(DeepSession.DEFAULT_PORT), 13, DeepUi.ACCENT)
		DeepUi.ledger_button(host, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 9)
		host.custom_minimum_size.y = DeepUi.pt(40)
		var lan := DeepUi.hbox(box, int(DeepUi.pt(6)))
		home._address = LineEdit.new()
		home._address.text = str(home.settings.get("last_address", "127.0.0.1"))
		home._address.custom_minimum_size.y = DeepUi.pt(36)
		home._address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		home._address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
		DeepUi.set_text_size(home._address, 13)
		lan.add_child(home._address)
		var join := DeepUi.primary(lan, "play", "Join", func() -> void: home.join_requested.emit(home._address.text, DeepSession.DEFAULT_PORT), 13)
		join.custom_minimum_size.y = DeepUi.pt(36)
		for button in [host, join]:
			button.disabled = in_party
		if home.is_host and home.status == "hosting":
			host.disabled = true
		DeepUi.wrap(box, "Friends on the same Wi-Fi see your party and join it. Steam lobbies are on the desktop game only.", 11, DeepUi.DIM)
	elif home.status in ["local", "offline", "lost"] or not in_party:
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
		home._address.text_submitted.connect(func(text: String) -> void:
			if not in_party:
				home.join_requested.emit(text, DeepSession.DEFAULT_PORT))
		lan.add_child(home._address)
		var join_lan := DeepUi.icon_button(lan, "play", "Join", func() -> void: home.join_requested.emit(home._address.text, DeepSession.DEFAULT_PORT), 13, DeepUi.INFO)
		for button in [host_lan, join_lan, host_steam, join_steam]:
			button.disabled = in_party
			if in_party:
				button.tooltip_text = first
		## Hosting alone already: hosting the same way again would only reopen the same lobby.
		## Join stays, to go to a friend's party instead.
		if home.is_host and home.status == "hosting" and home.invite_code.is_empty():
			host_lan.disabled = true
			host_lan.tooltip_text = "You are already hosting on your network."
		if home.is_host and (home.status == "opening" or not home.invite_code.is_empty()):
			host_steam.disabled = true
			host_steam.tooltip_text = "You are already hosting a Steam lobby."
		DeepUi.wrap(box, "Friends join a Steam lobby from the overlay's invite list, from Join Game in the friends list, or by pasting its ID above.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 430)
	if home.status not in ["local", "offline"]:
		var hosting: bool = home.is_host
		## A door in warning red, like the menu's, so it does not read as closing this popup.
		var out := DeepUi.icon_button(box, "door", "Close the party" if hosting else "Leave the party", Callable(), 13, DeepUi.BAD)
		out.size_flags_horizontal = Control.SIZE_SHRINK_END
		out.tooltip_text = "Everyone goes back to their own workshop." if hosting else "Back to a workshop of your own."
		## A host with friends in the party clicks twice: the first click only asks.
		var ask_first: bool = hosting and in_party
		if ask_first:
			out.tooltip_text = "Everyone goes back to their own workshop. Click twice to close."
		out.pressed.connect(func() -> void:
			if ask_first and not bool(out.get_meta("armed", false)):
				out.set_meta("armed", true)
				out.text = "Close it for everyone?"
				out.get_tree().create_timer(3.0).timeout.connect(func() -> void:
					if is_instance_valid(out):
						out.set_meta("armed", false)
						out.text = "Close the party")
				return
			home.leave_party_requested.emit())
