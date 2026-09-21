extends Control
## The workshop: five tabs in one frame. Map (the mines under the workshop, the party and
## the way down), Lapidaries (the roster: who goes down, their dossier and their loadout),
## Vault (one stone per skill), Appraise (what came home, under the loupe), Ledger (records
## and runs).
##
## Tabs are rebuilt whenever the profile or the lobby changes; stones and dice are
## photographs, so that is cheap, and only the one stone a tab is about is live 3D. A tab
## only animates in when it is opened, never on a rebuild.

const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Backdrop = preload("res://view/run/backdrop.gd")
const MineMap = preload("res://view/home/mine_map.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Roster = preload("res://view/home/roster.gd")

signal depart_requested(seed: int)
signal member_changed(fields: Dictionary)
signal mine_chosen(mine: String)
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal steam_host_requested
signal steam_join_requested(lobby_id: String)
signal invite_requested
signal profile_changed
signal menu_requested

const TABS: Array = [["map", "Map", "map"], ["roster", "Lapidaries", "person"], ["vault", "Vault", "chest"], ["appraise", "Appraise", "loupe"], ["ledger", "Ledger", "book"]]
const COLOUR_ORDER: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]

var profile: Dictionary = {}
var lobby: Dictionary = {}
var status: String = "local"
var is_host: bool = true
var local_id: String = "p0"
var can_start: bool = true
var settings: Dictionary = {}
## The Steam lobby's ID while hosting over Steam.
var invite_code: String = ""
var tab: String = "map"
var _bar: HBoxContainer
var _body: Control
var _backdrop: Control
var _vault_pick: String = ""
var _vault_filter: String = ""
var _appraise_pick: String = ""
var _revealed: String = ""
var _bench_socket: int = -1
var _bench_die: int = -1
var _roster_pick: String = ""
var _address: LineEdit
var _lobby_field: LineEdit
var _seed: LineEdit
var _fresh: bool = true
var _shown_tab: String = ""
var _headless: bool = false
var _gold_seen: int = -1
var _cheer: Dictionary = {}
var _page: ScrollContainer = null
## Set by "Edit loadout": the Lapidaries tab opens scrolled down to the rail and the dice.
var _to_loadout: bool = false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_backdrop.show_biome(DeepContent.starter_mine(), 1)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var head := PanelContainer.new()
	var style := DeepUi.flat(Color(0.035, 0.045, 0.065, 0.97), Color(0, 0, 0, 0), 0, 10)
	style.border_width_bottom = 1
	style.border_color = Color(DeepUi.ACCENT_DIM, 0.6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	head.add_theme_stylebox_override("panel", style)
	column.add_child(head)
	_bar = DeepUi.hbox(head, 10)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)

func refresh(new_profile: Dictionary, new_lobby: Dictionary, new_status: String, host: bool, id: String, startable: bool, new_settings: Dictionary, code: String = "") -> void:
	invite_code = code
	profile = new_profile
	lobby = new_lobby
	status = new_status
	is_host = host
	local_id = id
	can_start = startable
	settings = new_settings
	_render()

func open(tab_name: String) -> void:
	tab = tab_name
	_render()

func _render() -> void:
	_fresh = tab != _shown_tab
	_shown_tab = tab
	DeepUi.clear(_bar)
	var brand := DeepUi.hbox(_bar, 8)
	DeepUi.icon(brand, "gem", 24, DeepUi.ACCENT)
	DeepUi.title(brand, "DEEP CUT", 22, DeepUi.ACCENT_HI)
	DeepUi.gap(_bar, 10)
	var gold: int = int(profile.get("gold", 0))
	var purse := DeepUi.pill(_bar, "coin", "%d" % gold, DeepUi.ACCENT, 14, "Gold: from selling stones")
	if _gold_seen >= 0 and gold != _gold_seen and not _headless:
		## Gold coming in counts up, and the purse jingles.
		var value: Label = purse.get_child(0).get_node("Value")
		var from: int = _gold_seen
		value.text = "%d" % from
		DeepAudio.play("ore" if gold > from else "buy", {"delay": 0.15, "volume": 0.7})
		var tween := purse.create_tween()
		tween.tween_interval(0.15)
		tween.tween_method(func(v: float) -> void: value.text = "%d" % int(round(v)), float(from), float(gold), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		call_deferred("_cheer_at", purse, "%+d gold" % (gold - from), DeepUi.ACCENT, "coin")
	_gold_seen = gold
	DeepUi.spacer(_bar)
	for entry in TABS:
		var key: String = str(entry[0])
		var badge: int = profile.get("tray", []).size() if key == "appraise" else 0
		var button := DeepUi.tab_button(_bar, str(entry[2]), str(entry[1]), key == tab, func() -> void: open(key), 15, badge)
		if key == "vault" and not _cheer.is_empty():
			call_deferred("_cheer_at", button, str(_cheer.text), _cheer.colour, "chest")
			_cheer = {}
		if key == "appraise" and badge > 0 and key != tab:
			DeepUi.breathe(button, 0.65, 1.6)
	DeepUi.spacer(_bar)
	DeepUi.stat(_bar, "person", str(profile.get("name", "")), DeepUi.MUTED, 14)
	DeepUi.gear_button(_bar, func() -> void: menu_requested.emit())
	## A page rebuilt in place (a socket picked, a stone set) keeps its scroll, so the vault
	## below the rail does not jump away with every click.
	var kept: int = _page.scroll_vertical if not _fresh and _page != null and is_instance_valid(_page) else 0
	DeepUi.clear(_body)
	var page := ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(page)
	_page = page
	if kept > 0:
		_scroll_after_layout(page, kept)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	page.add_child(margin)
	var content := DeepUi.vbox(margin, 16)
	match tab:
		"map": _map(content)
		"roster": _roster(content)
		"vault": _vault(content)
		"appraise": _appraise(content)
		"ledger": _ledger(content)

func _scroll_after_layout(page: ScrollContainer, value: int) -> void:
	## A new page has no height until it is laid out; it waits a frame, hidden, then scrolls.
	page.modulate.a = 0.0
	await get_tree().process_frame
	if is_instance_valid(page):
		page.scroll_vertical = value
		page.modulate.a = 1.0

func _scroll_to(page: ScrollContainer, target: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(page) and is_instance_valid(target):
		var tween := page.create_tween()
		var goal: int = int(target.global_position.y - page.global_position.y) + page.scroll_vertical - 12
		tween.tween_property(page, "scroll_vertical", goal, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _edit_loadout(character_key: String) -> void:
	_roster_pick = character_key
	_bench_socket = -1
	_bench_die = -1
	_to_loadout = true
	open("roster")

func _cheer_at(control: Control, text: String, colour: Color, glyph: String) -> void:
	## A little celebration where something landed: a burst, a swell and a word.
	if _headless or not is_instance_valid(control) or not control.is_inside_tree():
		return
	DeepUi.pulse(control, 1.3, 0.45)
	var at: Vector2 = control.global_position + Vector2(control.size.x * 0.5, control.size.y + 6.0) - global_position
	DeepUi.burst(self, at, colour, 26, 220.0, 0.7, 6.0)
	var label := DeepUi.float_text(self, at, text, colour, 20, -40.0, 1.5)
	label.z_index = 40

func _enter(node: Control, delay: float = 0.0) -> void:
	if _fresh:
		DeepUi.pop_in(node, delay)

func _empty(content: Control, glyph: String, title: String, text: String) -> void:
	var holder := DeepUi.center(content)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size.y = 420
	var card := DeepUi.card(holder, DeepUi.LINE, 30)
	var box := DeepUi.vbox(card, 10)
	var mark := DeepUi.icon(box, glyph, 64, DeepUi.DIM)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.title(box, title, 24, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(box, text, 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 440)
	_enter(card)

# --- map -------------------------------------------------------------------------------------

func _map(content: VBoxContainer) -> void:
	var columns := DeepUi.hbox(content, 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var keys: Array = DeepContent.section("mines").keys()
	keys.sort()
	var map := MineMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(560, 740)
	columns.add_child(map)
	map.show_mines(keys, profile.get("mines", {}), str(lobby.get("mine", "")), is_host)
	map.chosen.connect(func(key: String) -> void:
		DeepAudio.play("ui_confirm", {"volume": 0.7})
		mine_chosen.emit(key))
	_enter(map)
	var side := DeepUi.vbox(columns, 14)
	side.custom_minimum_size.x = 470
	## The expedition: which mine, wearing what, and the button that goes.
	var chosen_key: String = str(lobby.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(chosen_key)
	var record: Dictionary = profile.get("mines", {}).get(chosen_key, {})
	var trip := DeepUi.card(side, Color(DeepUi.ACCENT, 0.4), 18)
	var trip_box := DeepUi.vbox(trip, 10)
	DeepUi.section(trip_box, "descend", "The expedition")
	DeepUi.title(trip_box, str(mine.get("name", chosen_key)), 28, DeepUi.PAPER)
	DeepUi.wrap(trip_box, str(mine.get("text", "")), 13, DeepUi.MUTED)
	var facts := DeepUi.hbox(trip_box, 8)
	DeepUi.pill(facts, "stairs", "deepest %d" % int(record.get("deepest", 0)), DeepUi.INFO, 12)
	DeepUi.pill(facts, "crown", "%d of 3 Wardens" % record.get("wardens", []).size(), DeepUi.ACCENT, 12)
	DeepUi.pill(facts, "pick", DeepUi.plural(int(record.get("runs", 0)), "run"), DeepUi.MUTED, 12)
	_enter(trip)
	## Who goes down, in brief. The roster tab is where they are chosen and fitted.
	var current: String = str(profile.get("current_character", DeepContent.starter_character()))
	var chosen_character: Dictionary = DeepContent.character(current)
	var wear := DeepUi.card(side, DeepUi.LINE, 16)
	var wear_box := DeepUi.vbox(wear, 10)
	DeepUi.section(wear_box, "person", "Going down as")
	var wear_row := DeepUi.hbox(wear_box, 14)
	wear_row.add_child(Roster.Portrait.new(current, Vector2(86, 102), false, false, true))
	var wear_facts := DeepUi.vbox(wear_row, 5)
	wear_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.title(wear_facts, DeepContent.character_title(current), 20, DeepUi.PAPER)
	var wear_pills := DeepUi.hbox(wear_facts, 6)
	DeepUi.pill(wear_pills, "heart", "%d HP" % int(chosen_character.get("hp", 0)), DeepUi.HP, 11)
	DeepUi.pill(wear_pills, "spark", str(chosen_character.get("passive", {}).get("name", "Passive")), DeepUi.ACCENT, 11, str(chosen_character.get("passive", {}).get("text", "")))
	DeepUi.pill(wear_pills, "gem", str(chosen_character.get("birthstone", {}).get("name", "Birthstone")), DeepUi.INFO, 11, str(chosen_character.get("birthstone", {}).get("text", "")))
	DeepUi.wrap(wear_facts, str(chosen_character.get("text", "")), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 320)
	## What they take down, at a glance: click any of it to change it.
	var loadout: Dictionary = DeepProfile.loadout(profile, current)
	var kit := DeepUi.vbox(wear_box, 6)
	kit.mouse_filter = Control.MOUSE_FILTER_PASS
	kit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	kit.tooltip_text = "Click to change the rail and the dice"
	kit.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			DeepAudio.play("ui_tap")
			_edit_loadout(current))
	var rail_row := DeepUi.hbox(kit, 6)
	rail_row.mouse_filter = Control.MOUSE_FILTER_PASS
	var kit_sockets: Array = chosen_character.get("sockets", [])
	var empty: int = 0
	for index in range(kit_sockets.size()):
		var set_stone: Variant = loadout.rail[index] if index < loadout.rail.size() else null
		if not set_stone is Dictionary:
			empty += 1
		_kit_socket(rail_row, str(kit_sockets[index]), set_stone if set_stone is Dictionary else {})
	var birthstone: Dictionary = DeepStone.birthstone(current)
	if not birthstone.is_empty():
		_kit_socket(rail_row, "BIRTHSTONE", birthstone)
	var dice_row := DeepUi.hbox(kit, 6)
	dice_row.mouse_filter = Control.MOUSE_FILTER_PASS
	for die in loadout.dice:
		var die_thumb := Thumbs.DieThumb.new(die, 32)
		die_thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		dice_row.add_child(die_thumb)
	if empty > 0:
		DeepUi.stat(kit, "gem", "%s empty" % DeepUi.plural(empty, "socket"), DeepUi.ACCENT, 12)
	var wear_buttons := DeepUi.hbox(wear_box, 8)
	DeepUi.icon_button(wear_buttons, "gem", "Edit loadout", func() -> void: _edit_loadout(current), 13, DeepUi.ACCENT)
	DeepUi.icon_button(wear_buttons, "person", "Change lapidary", func() -> void: open("roster"), 13, DeepUi.MUTED)
	_enter(wear, 0.05)
	## The party.
	var party := DeepUi.card(side, DeepUi.LINE, 16)
	var party_box := DeepUi.vbox(party, 8)
	DeepUi.section(party_box, "party", "The party")
	for id in lobby.get("order", []):
		var member: Dictionary = lobby.members.get(id, {})
		var row := DeepUi.hbox(party_box, 10)
		DeepUi.icon(row, "person", 20, DeepUi.PAPER if str(id) == local_id else DeepUi.INFO)
		DeepUi.label(row, str(member.get("name", id)) + (" (you)" if str(id) == local_id else ""), 15, DeepUi.PAPER)
		DeepUi.label(row, DeepContent.character_title(str(member.get("character", ""))), 13, DeepUi.MUTED)
		DeepUi.spacer(row)
		var note: String = "host" if str(id) == str(lobby.get("host", "p0")) else ("ready" if bool(member.get("ready", false)) else "not ready")
		if not bool(member.get("connected", true)):
			note = "away"
		DeepUi.pill(row, "crown" if note == "host" else ("check" if note == "ready" else "hourglass"), note, DeepUi.GOOD if note in ["ready", "host"] else DeepUi.MUTED, 11)
	var me: Dictionary = lobby.members.get(local_id, {})
	if not is_host:
		var ready := DeepUi.primary(party_box, "check", "Unready" if bool(me.get("ready", false)) else "I'm ready", func() -> void: member_changed.emit({"ready": not bool(me.get("ready", false))}), 16, DeepUi.GOOD)
		ready.disabled = status != "joined"
	else:
		var go := DeepUi.primary(party_box, "descend", "Descend", func() -> void:
			depart_requested.emit(int(_seed.text) if _seed != null and _seed.text.is_valid_int() else 0), 20)
		DeepUi.voice(go, "depart")
		go.custom_minimum_size.y = 54
		go.disabled = not can_start or bool(lobby.get("started", false))
		if not go.disabled:
			DeepUi.breathe(go, 0.82, 2.0)
		if not can_start:
			DeepUi.stat(party_box, "hourglass", "Waiting for everyone to be ready.", DeepUi.MUTED, 12)
		var seed_row := DeepUi.hbox(party_box, 8)
		DeepUi.label(seed_row, "Seed", 12, DeepUi.DIM)
		_seed = LineEdit.new()
		_seed.placeholder_text = "blank for a new one"
		_seed.custom_minimum_size = Vector2(170, 0)
		_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seed_row.add_child(_seed)
	_enter(party, 0.1)
	## Co-op over the network.
	var together := DeepUi.card(side, DeepUi.LINE, 16)
	var together_box := DeepUi.vbox(together, 8)
	DeepUi.section(together_box, "wifi", "Play together")
	DeepUi.stat(together_box, "wifi", "Status: %s" % status, DeepUi.MUTED, 12)
	var lan := DeepUi.hbox(together_box, 8)
	DeepUi.icon_button(lan, "crown", "Host on LAN", func() -> void: host_requested.emit(DeepSession.DEFAULT_PORT), 13, DeepUi.ACCENT)
	_address = LineEdit.new()
	_address.text = str(settings.get("last_address", "127.0.0.1"))
	_address.custom_minimum_size = Vector2(150, 0)
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan.add_child(_address)
	DeepUi.icon_button(lan, "play", "Join", func() -> void: join_requested.emit(_address.text, DeepSession.DEFAULT_PORT), 13, DeepUi.INFO)
	var steam := DeepUi.hbox(together_box, 8)
	DeepUi.icon_button(steam, "party", "Host on Steam", func() -> void: steam_host_requested.emit(), 13, DeepUi.ACCENT)
	_lobby_field = LineEdit.new()
	_lobby_field.placeholder_text = "Steam lobby ID"
	_lobby_field.custom_minimum_size = Vector2(150, 0)
	_lobby_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_field.text_submitted.connect(func(text: String) -> void: steam_join_requested.emit(text))
	steam.add_child(_lobby_field)
	DeepUi.icon_button(steam, "play", "Join", func() -> void: steam_join_requested.emit(_lobby_field.text), 13, DeepUi.INFO)
	if not invite_code.is_empty():
		var code := DeepUi.hbox(together_box, 8)
		DeepUi.stat(code, "party", "Lobby %s" % invite_code, DeepUi.PAPER, 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.icon_button(code, "person", "Invite friends", func() -> void: invite_requested.emit(), 13, DeepUi.GOOD)
		var copy := DeepUi.icon_button(code, "copy", "Copy ID", Callable(), 13, DeepUi.MUTED)
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(invite_code)
			_cheer_at(copy, "Copied", DeepUi.GOOD, "copy"))
	DeepUi.wrap(together_box, "Friends join a Steam lobby from the overlay's invite list, from Join Game in the friends list, or by pasting its ID above.", 11, DeepUi.DIM)
	_enter(together, 0.15)

func _kit_socket(parent: Node, socket_colour: String, stone: Dictionary) -> void:
	## One socket of the loadout at a glance: its ring, and the stone in it if there is one.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(40, 40)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_colour, stone.is_empty())
	if socket_colour == "BIRTHSTONE":
		ring.birth_tint = GemMesh.tint(stone)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	if stone.is_empty():
		slot.tooltip_text = "Empty %s socket" % ("any-colour" if socket_colour == "ANY" else socket_colour.capitalize())
		return
	var thumb := StoneCard.mini(slot, stone, 30, DeepStone.name(stone) if socket_colour != "BIRTHSTONE" else "%s, the Birthstone" % str(stone.get("name", "")))
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	thumb.mouse_filter = Control.MOUSE_FILTER_PASS

# --- lapidaries ---------------------------------------------------------------------------------

func _roster(content: VBoxContainer) -> void:
	## The roster strip, the dossier of the one being looked at, and their loadout.
	var order: Array = DeepContent.characters_in_unlock_order()
	var current: String = str(profile.get("current_character", DeepContent.starter_character()))
	if _roster_pick.is_empty() or DeepContent.character(_roster_pick).is_empty():
		_roster_pick = current
	var unlocked_keys: Array = DeepProfile.unlocked_characters(profile)
	var strip_card := DeepUi.card(content, DeepUi.LINE, 16)
	var strip_box := DeepUi.vbox(strip_card, 10)
	var strip_head := DeepUi.hbox(strip_box, 8)
	DeepUi.section(strip_head, "person", "Lapidaries").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.stat(strip_head, "chest", "%d of %d unlocked" % [unlocked_keys.size(), order.size()], DeepUi.MUTED, 13)
	DeepUi.stat(strip_head, "crown", DeepUi.plural(Roster.wardens_beaten(profile), "Warden") + " beaten", DeepUi.MUTED, 13)
	var strip := DeepUi.hbox(strip_box, 12)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	var index: int = 0
	for key in order:
		var record: Dictionary = profile.get("characters", {}).get(str(key), {})
		var unlocked: bool = bool(record.get("unlocked", false))
		var tile := Roster.tile(strip, str(key), str(key) == _roster_pick, str(key) == current, unlocked, bool(record.get("fresh", false)))
		var picked_key: String = str(key)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_tap")
				_roster_pick = picked_key
				_bench_socket = -1
				_bench_die = -1
				if profile.get("characters", {}).has(picked_key):
					profile.characters[picked_key].erase("fresh")
				_render())
		_enter(tile, 0.03 * index)
		index += 1
	var looking_at_unlocked: bool = unlocked_keys.has(_roster_pick)
	_dossier(content, _roster_pick, looking_at_unlocked, _roster_pick == current)
	if looking_at_unlocked:
		_loadout(content, _roster_pick)
	else:
		var locked := DeepUi.card(content, DeepUi.LINE, 18)
		var locked_box := DeepUi.hbox(locked, 12)
		DeepUi.icon(locked_box, "lock", 22, DeepUi.DIM)
		DeepUi.label(locked_box, "%s to set %s's rail and dice." % [Roster.unlock_hint(_roster_pick), str(DeepContent.character(_roster_pick).get("name", ""))], 14, DeepUi.DIM)
		_enter(locked, 0.15)

func _dossier(content: VBoxContainer, key: String, unlocked: bool, chosen: bool) -> void:
	## Everything about one lapidary: portrait, health, dice, sockets, passive, Birthstone.
	var character: Dictionary = DeepContent.character(key)
	var passive: Dictionary = character.get("passive", {})
	var stone: Dictionary = DeepStone.birthstone(key)
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var card := DeepUi.card(content, Color(tint if unlocked else DeepUi.LINE, 0.5), 18)
	var box := DeepUi.vbox(card, 14)
	var columns := DeepUi.hbox(box, 24)
	## The portrait and the words.
	var left := DeepUi.vbox(columns, 8)
	left.custom_minimum_size.x = 250
	left.add_child(Roster.Portrait.new(key, Vector2(250, 290), not unlocked, false, chosen))
	DeepUi.title(left, str(character.get("name", key)), 30, DeepUi.PAPER if unlocked else DeepUi.DIM)
	DeepUi.label(left, str(character.get("title", "")), 15, DeepUi.MUTED)
	DeepUi.wrap(left, str(character.get("text", "")), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 250)
	## The numbers: health, dice, sockets, the passive.
	var middle := DeepUi.vbox(columns, 12)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pills := DeepUi.hbox(middle, 8)
	DeepUi.pill(pills, "heart", "%d health" % int(character.get("hp", 0)), DeepUi.HP, 13)
	DeepUi.pill(pills, "gem", DeepUi.plural(character.get("sockets", []).size(), "socket"), DeepUi.INFO, 13)
	if not unlocked:
		DeepUi.pill(pills, "lock", Roster.unlock_hint(key), DeepUi.DIM, 13)
	DeepUi.section(middle, "die", "Their dice")
	var dice_row := DeepUi.hbox(middle, 10)
	var die_index: int = 0
	for die_key in character.get("dice", []):
		var die: Dictionary = DeepDice.make(str(die_key), DeepContent.die(str(die_key)), "roster_%s_%d" % [key, die_index])
		var holder := DeepUi.vbox(dice_row, 3)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		var thumb := Thumbs.DieThumb.new(die, 46)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(thumb)
		DeepUi.label(holder, str(die.get("name", die_key)), 11, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		_faces_row(holder, die, 12)
		die_index += 1
	DeepUi.section(middle, "gem", "Their sockets")
	var socket_row := DeepUi.hbox(middle, 10)
	for socket in character.get("sockets", []):
		var holder := DeepUi.vbox(socket_row, 3)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		var ring := BattleScreen.SocketRing.new(str(socket), true)
		ring.custom_minimum_size = Vector2(40, 40)
		holder.add_child(ring)
		DeepUi.label(holder, "Any" if str(socket) == "ANY" else str(socket).capitalize(), 10, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var birth_holder := DeepUi.vbox(socket_row, 3)
	birth_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	var birth_ring := BattleScreen.SocketRing.new("BIRTHSTONE", false)
	birth_ring.birth_tint = tint
	birth_ring.custom_minimum_size = Vector2(40, 40)
	birth_holder.add_child(birth_ring)
	DeepUi.label(birth_holder, "Birthstone", 10, tint.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.section(middle, "spark", "Passive")
	var passive_card := DeepUi.card(middle, Color(DeepUi.ACCENT, 0.35), 12)
	var passive_box := DeepUi.vbox(passive_card, 3)
	DeepUi.title(passive_box, str(passive.get("name", "Passive")), 16, DeepUi.ACCENT_HI)
	DeepUi.wrap(passive_box, str(passive.get("text", "")), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 380)
	## The Birthstone, in full.
	var right := DeepUi.vbox(columns, 10)
	right.custom_minimum_size.x = 330
	var birth_card := DeepUi.card(right, Color(tint, 0.6), 14, Color(0.07, 0.06, 0.09, 0.92))
	var birth_box := DeepUi.vbox(birth_card, 10)
	var birth_head := DeepUi.hbox(birth_box, 12)
	if not stone.is_empty():
		var picture := StoneCard.mini(birth_head, stone, 84, str(stone.get("name", "")) + "\n" + str(stone.get("text", "")))
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var birth_names := DeepUi.vbox(birth_head, 2)
	birth_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(birth_names, "Birthstone", 11, DeepUi.DIM)
	DeepUi.title(birth_names, str(stone.get("name", "")), 22, tint.lightened(0.35))
	DeepUi.wrap(birth_names, str(stone.get("text", "")), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 210)
	## Tiers that count more of one die are drawn as five dice, filled as far as each needs.
	var die: String = DiceIcons.ladder_die(stone.get("tiers", []))
	for tier in stone.get("tiers", []):
		var tier_row := DeepUi.hbox(birth_box, 10)
		tier_row.mouse_filter = Control.MOUSE_FILTER_PASS
		var mark := DeepUi.center(tier_row)
		mark.custom_minimum_size.x = 56 if die.is_empty() else 72
		if DiceIcons.ladder_rung(tier, die) > 0:
			DiceIcons.build_ladder(mark, [tier], die, DiceIcons.ladder_rung(tier, die), 14, DeepUi.MUTED, DeepUi.DIM)
		else:
			DiceIcons.build(mark, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 14, DeepUi.MUTED, str(tier.get("text", "")))
		var words := DeepUi.vbox(tier_row, 1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(words, str(tier.get("name", "")), 13, DeepUi.PAPER)
		DeepUi.wrap(words, str(tier.get("text", "")), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 230)
	var face: String = str(character.get("birthstone", {}).get("face", ""))
	if not face.is_empty():
		DeepUi.stat(birth_box, "eye", face, DeepUi.DIM, 11, "The face they pull when the Birthstone fires")
	## The decision.
	var actions := DeepUi.hbox(box, 12)
	actions.alignment = BoxContainer.ALIGNMENT_END
	if not unlocked:
		DeepUi.stat(actions, "lock", "%s. You have beaten %s." % [Roster.unlock_hint(key), DeepUi.plural(Roster.wardens_beaten(profile), "Warden")], DeepUi.DIM, 13)
	elif chosen:
		DeepUi.icon_button(actions, "gem", "Edit loadout", func() -> void: _edit_loadout(key), 14, DeepUi.ACCENT)
		DeepUi.pill(actions, "check", "Going down as %s" % str(character.get("name", key)), DeepUi.GOOD, 14)
	else:
		DeepUi.icon_button(actions, "gem", "Edit loadout", func() -> void: _edit_loadout(key), 14, DeepUi.ACCENT)
		var picked_key: String = key
		DeepUi.primary(actions, "descend", "Play as %s" % str(character.get("name", key)), func() -> void:
			DeepAudio.play("ui_confirm", {"volume": 0.8})
			profile.current_character = picked_key
			profile_changed.emit(), 16)
	_enter(card, 0.1)

# --- loadout ------------------------------------------------------------------------------------

func _loadout(content: VBoxContainer, character_key: String) -> void:
	## The rail and the dice of one unlocked lapidary: click a socket, then a stone; click a
	## slot, then a die.
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters.get(character_key, {"rail": [], "dice": []})
	## The rail: click a socket, then a stone.
	var rail_card := DeepUi.card(content, DeepUi.LINE, 18)
	if _to_loadout:
		_to_loadout = false
		_scroll_to(_page, rail_card)
	var rail_box := DeepUi.vbox(rail_card, 12)
	var rail_head := DeepUi.hbox(rail_box, 8)
	DeepUi.section(rail_head, "gem", "Sockets").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(rail_head, "Pick a socket, then a stone from the vault below." if _bench_socket < 0 else "Choose a stone for socket %d." % (_bench_socket + 1), 13, DeepUi.MUTED if _bench_socket < 0 else DeepUi.ACCENT)
	var rail_row := DeepUi.hbox(rail_box, 14)
	rail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var sockets: Array = character.get("sockets", [])
	for index in range(sockets.size()):
		var socket_colour: String = str(sockets[index])
		var skill: Variant = record.rail[index] if index < record.rail.size() else null
		var stone: Dictionary = DeepProfile.owned(profile, str(skill)) if skill is String else {}
		var slot_card := _socket_slot(rail_row, index, socket_colour, stone, character_key)
		_enter(slot_card, 0.05 + 0.04 * index)
	_enter(BirthstoneCard.new(rail_row, character_key), 0.05 + 0.04 * sockets.size())
	## The vault as a tray to set from.
	var cap: int = int(character.get("carat_max", 0))
	var tray_card := DeepUi.card(content, DeepUi.LINE, 16)
	var tray_box := DeepUi.vbox(tray_card, 10)
	var socket_colour_now: String = str(sockets[_bench_socket]) if _bench_socket >= 0 and _bench_socket < sockets.size() else ""
	DeepUi.section(tray_box, "chest", "From the vault" + ("" if socket_colour_now.is_empty() else (": any stone fits" if socket_colour_now == "ANY" else ": stones that fit a %s socket" % socket_colour_now.capitalize())))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	tray_box.add_child(flow)
	var owned_keys: Array = profile.get("vault", {}).keys()
	owned_keys.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = COLOUR_ORDER.find(DeepStone.colour(profile.vault[a]))
		var cb: int = COLOUR_ORDER.find(DeepStone.colour(profile.vault[b]))
		return ca < cb if ca != cb else a < b)
	if owned_keys.is_empty():
		DeepUi.label(flow, "The vault is empty.", 13, DeepUi.DIM)
	for key in owned_keys:
		var stone: Dictionary = profile.vault[key]
		var fits: bool = socket_colour_now.is_empty() or (DeepStone.fits(stone, socket_colour_now) and (cap <= 0 or int(stone.carat) <= cap))
		var in_rail: bool = record.rail.has(key)
		var tile := StoneCard.tile(flow, stone, 70)
		tile.modulate = Color(1, 1, 1, 1.0 if fits else 0.3)
		if in_rail:
			var mark := DeepUi.icon(tile.get_child(0), "check", 14, DeepUi.GOOD, "Already set")
			mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if fits and _bench_socket >= 0:
			tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			DeepUi.juice(tile, 1.06)
			var chosen_key: String = str(key)
			var socket_index: int = _bench_socket
			tile.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if DeepProfile.set_rail(profile, character_key, socket_index, chosen_key).is_empty():
						_bench_socket = -1
						DeepAudio.play("dice_lock", {"volume": 0.7})
						profile_changed.emit())
	_enter(tray_card, 0.1)
	## The dice.
	var dice_card := DeepUi.card(content, DeepUi.LINE, 16)
	var dice_box := DeepUi.vbox(dice_card, 12)
	var dice_head := DeepUi.hbox(dice_box, 8)
	DeepUi.section(dice_head, "die", "Dice").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(dice_head, "Pick a slot, then a die from the bowl." if _bench_die < 0 else "Choose a die for slot %d." % (_bench_die + 1), 13, DeepUi.MUTED if _bench_die < 0 else DeepUi.ACCENT)
	var dice_row := DeepUi.hbox(dice_box, 12)
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var loadout: Dictionary = DeepProfile.loadout(profile, character_key)
	for index in range(5):
		var die: Dictionary = loadout.dice[index] if index < loadout.dice.size() else {}
		var chosen: bool = index == _bench_die
		var card := DeepUi.card(dice_row, DeepUi.ACCENT if chosen else DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.9))
		card.custom_minimum_size = Vector2(170, 0)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var box := DeepUi.vbox(card, 6)
		if not die.is_empty():
			var thumb := Thumbs.DieThumb.new(die, 52)
			thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(thumb)
			DeepUi.label(box, DeepDice.describe(die), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			_faces_row(box, die, 15)
		else:
			DeepUi.label(box, "empty", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var slot: int = index
		DeepUi.juice(card, 1.04)
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_bench_die = -1 if _bench_die == slot else slot
				_render())
		_enter(card, 0.12 + 0.04 * index)
	var bowl_row := DeepUi.hbox(dice_box, 10)
	DeepUi.stat(bowl_row, "bag", "The bowl (%d)" % profile.get("bowl", []).size(), DeepUi.MUTED, 13)
	var bowl := HFlowContainer.new()
	bowl.add_theme_constant_override("h_separation", 8)
	bowl.add_theme_constant_override("v_separation", 8)
	bowl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bowl_row.add_child(bowl)
	var used: Array = record.get("dice", [])
	for bowl_die in profile.get("bowl", []):
		var thumb := Thumbs.DieThumb.new(bowl_die, 50)
		thumb.modulate = Color(1, 1, 1, 0.45 if used.has(str(bowl_die.id)) else 1.0)
		bowl.add_child(thumb)
		if _bench_die >= 0 and not used.has(str(bowl_die.id)):
			thumb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var die_id: String = str(bowl_die.id)
			var slot: int = _bench_die
			thumb.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if DeepProfile.set_die(profile, character_key, slot, die_id).is_empty():
						_bench_die = -1
						DeepAudio.play("die_settle", {"volume": 0.8})
						profile_changed.emit())
	_enter(dice_card, 0.15)

func _socket_slot(parent: Node, index: int, socket_colour: String, stone: Dictionary, character_key: String) -> PanelContainer:
	var chosen: bool = index == _bench_socket
	var tone: Color = DeepUi.colour(socket_colour) if socket_colour != "ANY" else DeepUi.LINE_HI
	var card := DeepUi.card(parent, DeepUi.ACCENT if chosen else Color(tone, 0.45), 10, Color(0.05, 0.06, 0.085, 0.9))
	card.custom_minimum_size = Vector2(150, 0)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := DeepUi.vbox(card, 6)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_colour, stone.is_empty())
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	if chosen:
		ring.set_ready(true)
	if not stone.is_empty():
		var thumb := StoneCard.mini(slot, stone, 60, DeepStone.name(stone))
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", "")), 14, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		var trigger_row := DeepUi.hbox(box, 0)
		trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
		DiceIcons.build(trigger_row, DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, {}).cut_step)), 15, DeepUi.MUTED)
		var socket_index: int = index
		var remove := DeepUi.icon_button(slot, "cross_out", "", func() -> void:
			DeepProfile.set_rail(profile, character_key, socket_index, null)
			profile_changed.emit(), 10, DeepUi.MUTED)
		DeepUi.voice(remove, "ui_back")
		remove.tooltip_text = "Take the stone out"
		remove.position = Vector2(66, -6)
	else:
		DeepUi.label(box, "Any colour" if socket_colour == "ANY" else socket_colour.capitalize(), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "empty", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.juice(card, 1.04)
	var socket_index: int = index
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_bench_socket = -1 if _bench_socket == socket_index else socket_index
			DeepAudio.play("ui_tap")
			_render())
	return card

func _faces_row(parent: Node, die: Dictionary, edge: float) -> HBoxContainer:
	var row := DeepUi.hbox(parent, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tone: Color = DiceIcons.palette(str(die.get("key", "D6"))).body
	for f in die.get("faces", []):
		row.add_child(DiceIcons.face(edge, int(f.value), tone if str(f.kind) == "plain" else DiceIcons.face_kind_tint(str(f.kind)), str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.value), str(f.kind))))
	return row

# --- vault -----------------------------------------------------------------------------------

func _vault(content: VBoxContainer) -> void:
	var owned: int = profile.get("vault", {}).size()
	var total: int = DeepContent.section("skills").size()
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "chest", 28, DeepUi.ACCENT)
	DeepUi.title(head, "The vault", 30, DeepUi.PAPER)
	DeepUi.pill(head, "gem", "%d of %d skills kept" % [owned, total], DeepUi.ACCENT, 13)
	var meter := DeepUi.bar(head, 10.0, DeepUi.ACCENT, Color(DeepUi.LINE, 0.6))
	meter.custom_minimum_size = Vector2(180, 10)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.set_values(float(owned) / float(maxi(1, total)))
	DeepUi.spacer(head)
	## Filter by colour.
	var all := DeepUi.tab_button(head, "gem", "All", _vault_filter.is_empty(), func() -> void:
		_vault_filter = ""
		_render(), 13)
	for colour in COLOUR_ORDER:
		var key: String = colour
		var button := DeepUi.tab_button(head, "gem", str(DeepContent.colour(colour).get("name", colour)), _vault_filter == colour, func() -> void:
			_vault_filter = key
			_render(), 13)
		button.add_theme_color_override("icon_normal_color", DeepUi.colour(colour))
		button.add_theme_color_override("icon_hover_color", DeepUi.colour(colour).lightened(0.3))
	_enter(head)
	var columns := DeepUi.hbox(content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(grid)
	var side := DeepUi.vbox(columns, 12)
	side.custom_minimum_size = Vector2(440, 0)
	var index: int = 0
	for entry in DeepProfile.vault_grid(profile):
		var skill: Dictionary = DeepContent.skill(str(entry.skill))
		var colour: String = str(skill.get("colour", "WHITE"))
		if not _vault_filter.is_empty() and colour != _vault_filter:
			continue
		var state: String = str(entry.state)
		var key: String = str(entry.skill)
		var tile: Control
		if state == "owned":
			tile = StoneCard.tile(grid, entry.stone, 84)
			if key == _vault_pick:
				var style: StyleBoxFlat = (tile as PanelContainer).get_theme_stylebox("panel").duplicate()
				style.border_color = DeepUi.ACCENT
				style.set_border_width_all(2)
				tile.add_theme_stylebox_override("panel", style)
			tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			DeepUi.juice(tile, 1.06)
			tile.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_vault_pick = key
					_render())
		else:
			tile = _ghost_tile(grid, key, colour, state == "seen")
		_enter(tile, 0.015 * index)
		index += 1
	## The stone under the lamp.
	var shown: Dictionary = DeepProfile.owned(profile, _vault_pick)
	var caption: String = ""
	if shown.is_empty() and not profile.get("records", {}).get("best", {}).is_empty():
		shown = profile.records.best.stone
		caption = "Your best stone"
	if shown.is_empty():
		_empty(side, "chest", "Nothing kept yet", "Stones you keep from the Appraise tab live here, one per skill.")
		return
	var lamp := DeepUi.card(side, Color(DeepUi.tier_colour(str(DeepStone.grade(shown).tier)), 0.5), 16)
	var lamp_box := DeepUi.vbox(lamp, 10)
	if not caption.is_empty():
		DeepUi.section(lamp_box, "star", caption)
	var stage := Showcase.new(shown, 220)
	lamp_box.add_child(stage)
	StoneCard.build(lamp_box, shown, {"picture": false, "provenance": true, "value": true, "text_width": 380})
	_enter(lamp, 0.05)

func _ghost_tile(parent: Node, key: String, colour: String, seen: bool) -> PanelContainer:
	## A skill not kept: its emblem in grey if it has been seen, a dark mark if not.
	var box := PanelContainer.new()
	var style := DeepUi.flat(Color(0.03, 0.035, 0.05, 0.55 if seen else 0.35), Color(DeepUi.colour(colour), 0.25 if seen else 0.08), 12, 8)
	style.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	var column := DeepUi.vbox(box, 4)
	var frame := DeepUi.center(column)
	frame.custom_minimum_size = Vector2(84, 84)
	var skill: Dictionary = DeepContent.skill(key)
	if seen:
		DeepUi.icon(frame, GemIcons.emblem(key), 44, Color(DeepUi.colour(colour), 0.35), "%s: seen, not kept" % str(skill.get("name", key)))
		var l := DeepUi.label(column, str(skill.get("name", key)), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = 84
		l.clip_text = true
	else:
		DeepUi.icon(frame, "question", 26, Color(DeepUi.colour(colour), 0.18), "Not yet found")
		DeepUi.label(column, " ", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	return box

class Showcase extends Control:
	## One stone, live, under a lamp on a velvet pad, turning slowly in its light.
	var _clock: float = 0.0
	var _tone: Color
	func _init(stone: Dictionary, edge: float) -> void:
		custom_minimum_size = Vector2(edge * 1.6, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		_tone = DeepUi.tier_colour(str(DeepStone.grade(stone).tier)) if bool(stone.get("appraised", true)) else DeepUi.colour(DeepStone.colour(stone))
		var view := GemView.new()
		var reach: float = edge * 0.8
		view.anchor_left = 0.5
		view.anchor_right = 0.5
		view.offset_left = -reach * 0.5
		view.offset_right = reach * 0.5
		view.offset_top = edge * 0.06
		view.offset_bottom = edge * 0.06 + reach
		view.set_drift(true)
		view.set_spin(0.35)
		view.inspectable = true
		view.configure(stone)
		view.enable_interaction()
		add_child(view)
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var cx: float = size.x * 0.5
		var cone := PackedVector2Array([Vector2(cx - 30, 0), Vector2(cx + 30, 0), Vector2(cx + 110, size.y * 0.92), Vector2(cx - 110, size.y * 0.92)])
		draw_colored_polygon(cone, Color(_tone, 0.07 + 0.02 * sin(_clock * 1.7)))
		var pad := Vector2(260, 60)
		draw_texture_rect(glow, Rect2(Vector2(cx, size.y * 0.9) - pad * 0.5, pad), false, Color(_tone, 0.45))
		for i in range(8):
			var t: float = fmod(_clock * 0.2 + float(i) / 8.0, 1.0)
			draw_circle(Vector2(cx + sin(float(i) * 1.9 + _clock * 0.3) * 80.0 * t, size.y * 0.9 - t * size.y * 0.8), 1.5, Color(_tone.lightened(0.5), 0.8 * (1.0 - t)))

# --- appraise --------------------------------------------------------------------------------

func _appraise(content: VBoxContainer) -> void:
	var tray: Array = profile.get("tray", [])
	if tray.is_empty():
		_empty(content, "loupe", "The tray is empty", "Stones you bring home wait here to be put under the loupe.")
		return
	var pick: Dictionary = {}
	for stone in tray:
		if str(stone.id) == _appraise_pick:
			pick = stone
	if pick.is_empty():
		pick = tray[0]
		_appraise_pick = str(pick.id)
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "loupe", 28, DeepUi.ACCENT)
	DeepUi.title(head, "Under the loupe", 30, DeepUi.PAPER)
	DeepUi.pill(head, "bag", "%s on the tray" % DeepUi.plural(tray.size(), "stone"), DeepUi.MUTED, 13)
	DeepUi.spacer(head)
	var raw_count: int = tray.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false))).size()
	if raw_count > 1:
		DeepUi.icon_button(head, "loupe", "Appraise all %d" % raw_count, func() -> void:
			var best: Dictionary = {}
			for stone in tray:
				stone.appraised = true
				stone.inclusions_revealed = true
				if best.is_empty() or DeepStone.value(stone) > DeepStone.value(best):
					best = stone
			## One ceremony for the whole tray, for the best thing in it.
			if not best.is_empty():
				DeepAudio.reveal_stone(best)
			profile_changed.emit(), 14, DeepUi.INFO)
	_enter(head)
	var columns := DeepUi.hbox(content, 20)
	## The tray down the left.
	var strip := DeepUi.card(columns, DeepUi.LINE, 12)
	var strip_box := DeepUi.vbox(strip, 8)
	for stone in tray:
		var id: String = str(stone.id)
		var tile := StoneCard.tile(strip_box, stone, 74)
		if id == _appraise_pick:
			var style: StyleBoxFlat = tile.get_theme_stylebox("panel").duplicate()
			style.border_color = DeepUi.ACCENT
			style.set_border_width_all(2)
			tile.add_theme_stylebox_override("panel", style)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(tile, 1.05)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_appraise_pick = id
				_render())
	_enter(strip, 0.05)
	## The loupe table.
	var table := DeepUi.card(columns, Color(DeepUi.ACCENT, 0.35), 18)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var table_box := DeepUi.vbox(table, 12)
	var appraised: bool = bool(pick.get("appraised", false))
	var lens := LoupeTable.new(pick, 250)
	lens.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	table_box.add_child(lens)
	if str(pick.id) == _revealed:
		lens.reveal()
		_revealed = ""
	if not appraised:
		DeepUi.title(table_box, DeepStone.raw_name(pick), 24, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(table_box, "Its colour, size, cut and clarity are there to judge; what it does is not.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var id: String = str(pick.id)
		var go := DeepUi.primary(table_box, "loupe", "Appraise", func() -> void:
			DeepAudio.play("loupe_spin")
			lens.ceremony(func() -> void:
				pick.appraised = true
				pick.inclusions_revealed = true
				_revealed = id
				profile_changed.emit()), 20, DeepUi.INFO)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.custom_minimum_size = Vector2(240, 52)
		DeepUi.breathe(go, 0.8, 1.6)
	else:
		StoneCard.build(table_box, pick, {"picture": false, "provenance": true, "value": true})
		var owned: Dictionary = DeepProfile.owned(profile, str(pick.skill))
		if not owned.is_empty():
			var compare := DeepUi.card(table_box, Color(DeepUi.INFO, 0.4), 12)
			var compare_box := DeepUi.vbox(compare, 8)
			DeepUi.stat(compare_box, "chest", "You already keep one. Keeping this sells the other for %d gold." % DeepStone.value(owned), DeepUi.INFO, 13)
			StoneCard.build(compare_box, owned, {"size": 60, "value": true})
		var buttons := DeepUi.hbox(table_box, 12)
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		var id: String = str(pick.id)
		DeepUi.voice(DeepUi.primary(buttons, "chest", "Keep", func() -> void:
			DeepProfile.decide_tray(profile, id, true)
			_appraise_pick = ""
			_cheer = {"text": "Kept in the vault", "colour": DeepUi.GOOD}
			profile_changed.emit(), 18, DeepUi.GOOD), "keep")
		DeepUi.voice(DeepUi.primary(buttons, "coin", "Sell for %d" % DeepStone.value(pick), func() -> void:
			DeepProfile.decide_tray(profile, id, false)
			_appraise_pick = ""
			profile_changed.emit(), 18, DeepUi.ACCENT), "sell")
	_enter(table, 0.1)

class LoupeTable extends Control:
	## The stone under the jeweller's lens: live, lit from above, ringed by the loupe's rim.
	## Appraising plays a short ceremony: the stone spins up, light floods in, and it is known.
	var stone: Dictionary
	var _view: Control
	var _clock: float = 0.0
	var _flash: float = 0.0
	var _spin: float = 0.0
	var _tone: Color
	func _init(new_stone: Dictionary, edge: float) -> void:
		stone = new_stone
		custom_minimum_size = Vector2(edge * 1.5, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		var appraised: bool = bool(stone.get("appraised", false))
		_tone = DeepUi.tier_colour(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.colour(DeepStone.colour(stone))
		_view = GemView.new()
		var reach: float = edge * 0.78
		_view.anchor_left = 0.5
		_view.anchor_right = 0.5
		_view.anchor_top = 0.5
		_view.anchor_bottom = 0.5
		_view.offset_left = -reach * 0.5
		_view.offset_right = reach * 0.5
		_view.offset_top = -reach * 0.5
		_view.offset_bottom = reach * 0.5
		_view.set_drift(true)
		_view.set_spin(0.4)
		_view.inspectable = true
		_view.configure(stone)
		add_child(_view)
	func ceremony(done: Callable) -> void:
		## The reveal: a quickening spin, a blaze, and then the answer.
		var tween := create_tween()
		tween.tween_method(func(v: float) -> void:
			_spin = v
			if is_instance_valid(_view):
				_view.call("set_spin", 0.4 + v * 14.0), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			_flash = 1.0
			DeepUi.burst(self, size * 0.5, _tone.lightened(0.3), 60, 320.0, 0.9, 7.0))
		tween.tween_interval(0.12)
		tween.tween_callback(done)
	func reveal() -> void:
		## Just appraised: the grade's colour bursts out of the stone.
		DeepAudio.reveal_stone(stone)
		_flash = 1.0
		var tween := create_tween()
		tween.tween_interval(0.05)
		tween.tween_callback(func() -> void:
			DeepUi.burst(self, size * 0.5, _tone, 80, 380.0, 1.1, 8.0)
			DeepUi.pulse(self, 1.08, 0.5))
	func _process(delta: float) -> void:
		_clock += delta
		_flash = maxf(0.0, _flash - delta * 1.2)
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var centre := size * 0.5
		var radius: float = size.y * 0.47
		var pulse: float = 1.0 + 0.03 * sin(_clock * 2.0)
		var halo := Vector2(radius, radius) * 3.0 * pulse * (1.0 + _spin * 0.5 + _flash)
		draw_texture_rect(glow, Rect2(centre - halo * 0.5, halo), false, Color(_tone, 0.25 + 0.3 * _spin + 0.6 * _flash))
		draw_circle(centre, radius, Color(0.02, 0.025, 0.035, 0.85))
		draw_arc(centre, radius, 0, TAU, 72, Color("b8a47a"), 5.0, true)
		draw_arc(centre, radius - 6.0, 0, TAU, 72, Color("5a4a30"), 2.0, true)
		for i in range(24):
			var angle: float = TAU * float(i) / 24.0 + _clock * 0.1
			draw_line(centre + Vector2.from_angle(angle) * (radius + 3.0), centre + Vector2.from_angle(angle) * (radius + 9.0), Color("b8a47a", 0.8), 1.5, true)
		## A glint travelling round the glass.
		var sweep: float = fmod(_clock * 0.4, 1.0) * TAU
		draw_arc(centre, radius - 12.0, sweep, sweep + 0.5, 16, Color(1, 1, 1, 0.25), 3.0, true)
		if _flash > 0.0:
			draw_texture_rect(glow, Rect2(centre - Vector2(radius, radius) * 2.0, Vector2(radius, radius) * 4.0), false, Color(1, 1, 1, 0.6 * _flash))

# --- ledger ----------------------------------------------------------------------------------

func _ledger(content: VBoxContainer) -> void:
	var records: Dictionary = profile.get("records", {})
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "book", 28, DeepUi.ACCENT)
	DeepUi.title(head, "The ledger", 30, DeepUi.PAPER)
	_enter(head)
	var tiles := DeepUi.hbox(content, 12)
	var index: int = 0
	for entry in [["pick", "runs", "Runs"], ["lift", "extractions", "Extractions"], ["crown", "conquests", "Conquests"], ["skull", "falls", "Falls"], ["chest", "stones_kept", "Stones kept"]]:
		var tile := DeepUi.card(tiles, DeepUi.LINE, 14)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := DeepUi.vbox(tile, 2)
		var mark := DeepUi.icon(box, str(entry[0]), 28, DeepUi.ACCENT)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.title(box, str(int(records.get(entry[1], 0))), 32, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, str(entry[2]), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_enter(tile, 0.04 * index)
		index += 1
	var columns := DeepUi.hbox(content, 20)
	var left := DeepUi.vbox(columns, 14)
	left.custom_minimum_size.x = 480
	var best: Dictionary = records.get("best", {})
	var best_card := DeepUi.card(left, Color(DeepUi.tier_colour(str(best.get("tier", "ROUGH"))), 0.5) if not best.is_empty() else DeepUi.LINE, 16)
	var best_box := DeepUi.vbox(best_card, 10)
	DeepUi.section(best_box, "star", "Best stone")
	if best.is_empty():
		DeepUi.label(best_box, "Keep a stone to start the record.", 13, DeepUi.MUTED)
	else:
		best_box.add_child(Showcase.new(best.stone, 180))
		StoneCard.build(best_box, best.stone, {"picture": false, "provenance": true, "value": true, "text_width": 400})
	_enter(best_card, 0.1)
	var mines_card := DeepUi.card(left, DeepUi.LINE, 16)
	var mines_box := DeepUi.vbox(mines_card, 8)
	DeepUi.section(mines_box, "map", "Mines")
	for key in profile.get("mines", {}):
		var record: Dictionary = profile.mines[key]
		var row := DeepUi.hbox(mines_box, 10)
		DeepUi.icon(row, "pick" if bool(record.get("unlocked", false)) else "chest", 18, DeepUi.ACCENT if bool(record.get("unlocked", false)) else DeepUi.DIM)
		DeepUi.label(row, str(DeepContent.mine(str(key)).get("name", key)) if bool(record.get("unlocked", false)) else "A sealed shaft", 15, DeepUi.PAPER)
		DeepUi.spacer(row)
		DeepUi.stat(row, "stairs", str(int(record.get("deepest", 0))), DeepUi.INFO, 13, "Deepest")
		DeepUi.stat(row, "crown", str(record.get("wardens", []).size()), DeepUi.ACCENT, 13, "Wardens beaten")
	_enter(mines_card, 0.15)
	var history_card := DeepUi.card(columns, DeepUi.LINE, 16)
	history_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var history_box := DeepUi.vbox(history_card, 6)
	DeepUi.section(history_box, "hourglass", "Recent runs")
	var history: Array = profile.get("history", [])
	if history.is_empty():
		DeepUi.label(history_box, "No runs yet.", 13, DeepUi.MUTED)
	var shown: int = 0
	for i in range(history.size() - 1, maxi(-1, history.size() - 21), -1):
		var run_record: Dictionary = history[i]
		var outcome: String = str(run_record.get("outcome", ""))
		var tone: Color = DeepUi.BAD if outcome == "fallen" else (DeepUi.ACCENT if outcome == "conquered" else DeepUi.GOOD)
		var row_panel := DeepUi.panel(history_box, Color(1, 1, 1, 0.025 if shown % 2 == 0 else 0.0), Color(0, 0, 0, 0), 6, 6)
		var row := DeepUi.hbox(row_panel, 12)
		DeepUi.icon(row, {"fallen": "skull", "conquered": "crown"}.get(outcome, "lift"), 18, tone, outcome.capitalize())
		DeepUi.label(row, outcome.capitalize(), 14, tone).custom_minimum_size.x = 96
		DeepUi.label(row, str(run_record.get("date", "")), 13, DeepUi.MUTED).custom_minimum_size.x = 100
		DeepUi.label(row, str(DeepContent.mine(str(run_record.get("mine", ""))).get("name", "")), 13, DeepUi.PAPER)
		DeepUi.spacer(row)
		DeepUi.stat(row, "stairs", str(int(run_record.get("depth", 0))), DeepUi.INFO, 13, "Depth reached")
		DeepUi.stat(row, "gem", str(int(run_record.get("stones", 0))), DeepUi.ACCENT, 13, "Stones brought home")
		shown += 1
	_enter(history_card, 0.12)


class BirthstoneCard extends PanelContainer:
	## A character's Birthstone at the end of a rail: the stone, its name, and every tier as
	## a pictograph. It cannot be taken out or swapped, so there is nothing to click.
	## `labelled` mirrors the run bench's socket cards, which carry a heading above the ring
	## and a second line under the name, so the tiers still sit level with their triggers.
	func _init(parent: Node, character_key: String, wide: float = 150.0, labelled: bool = false) -> void:
		var stone: Dictionary = DeepStone.birthstone(character_key)
		var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
		add_theme_stylebox_override("panel", DeepUi.raised(Color(0.07, 0.06, 0.09, 0.92), Color(tint, 0.7), 10, 10, 0.35))
		custom_minimum_size = Vector2(wide, 0)
		mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(self)
		var box := DeepUi.vbox(self, 4 if labelled else 6)
		if stone.is_empty():
			DeepUi.label(box, "No Birthstone", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
			return
		if labelled:
			DeepUi.label(box, "Birthstone", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(76, 76)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(slot)
		var ring := BattleScreen.SocketRing.new("BIRTHSTONE", false)
		ring.birth_tint = tint
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(ring)
		var thumb := StoneCard.mini(slot, stone, 60, str(stone.get("name", "")) + "\n" + str(stone.get("text", "")))
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		DeepUi.label(box, str(stone.get("name", "")), 13 if labelled else 14, tint.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
		if labelled:
			DeepUi.label(box, "Always set", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		## Every tier on one row, the size of a socket's trigger; each names itself on hover.
		var tiers := DeepUi.hbox(box, 4)
		tiers.alignment = BoxContainer.ALIGNMENT_CENTER
		var die: String = DiceIcons.ladder_die(stone.get("tiers", []))
		if not die.is_empty():
			DiceIcons.build_ladder(tiers, stone.get("tiers", []), die, 0, 14 if labelled else 15, DeepUi.MUTED, DeepUi.MUTED)
		for tier in stone.get("tiers", []):
			if DiceIcons.ladder_rung(tier, die) > 0:
				continue
			DiceIcons.build(tiers, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 14 if labelled else 15, DeepUi.MUTED,
				"%s: %s" % [str(tier.get("name", "")), str(tier.get("text", ""))])
		if not labelled:
			DeepUi.label(box, "Birthstone", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
