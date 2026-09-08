extends Control
## Snapshot-only desktop presentation. The authority owns all rules and randomness.
const EngineScript = preload("res://scripts/core/run_engine.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const SessionScript = preload("res://scripts/services/session.gd")
const Art = preload("res://scripts/ui/rune_art.gd")
const PlaceholderAudio = preload("res://scripts/ui/placeholder_audio.gd")
const INK := Color("10171f")
const PANEL := Color("19232d")
const LINE := Color("36434b")
const GOLD := Color("d6ac67")
const PAPER := Color("e7e4dc")
const MUTED := Color("a3b1b8")
const GREEN := Color("83c7ad")
const RED := Color("e29389")
const BLUE := Color("91b4dc")
const HERO_KEYS := ["ardor", "kait", "max"]
const ACTION_DEFAULTS := {"rd_reroll": KEY_R, "rd_ready": KEY_SPACE, "rd_inspect": KEY_I, "rd_target": KEY_TAB, "rd_back": KEY_ESCAPE, "rd_toggle_die": KEY_T, "rd_skip": KEY_F}

var engine: RefCounted
var session: Node
var snapshot: Dictionary = {}
var root_box: VBoxContainer
var page: Control
var overlay: PanelContainer
var toast: Label
var controlled_id := ""
var selected_dice: Array[String] = []
var menu_heroes: Array[String] = ["ardor"]
var menu_names: Array[String] = ["Player 1", "Player 2", "Player 3", "Player 4"]
var profile := "short_9"
var seed_text := ""
var player_name := "Adventurer"
var server_address := "127.0.0.1"
var steam_lobby_text := ""
var menu_page := "home"
var settings := {"text_scale": 1.0, "reduced_motion": false, "playback_speed": 1.0, "fullscreen": false, "bindings": {}, "sound_volume": 0.6}
var pending_render := false
var rebind_action := ""
var last_phase := ""
var journal_tab := "guide"
var selected_active_die := ""
var selected_reserve_gem := ""
var offline_hotseat := false
var command_counter := 0
var observed_revision := -1
var playback_label: Label
var playback_paused := false
var playback_events: Array = []
var playback_index := 0
var playback_timer := 0.0
var history: Array = []
var last_hands: Dictionary = {}
var die_buttons: Dictionary = {}
var sound_player: AudioStreamPlayer
var click_sound: AudioStreamWAV
var dice_sound: AudioStreamWAV
var mine_playback_label: Label
var mine_playback_index := 0
var mine_playback_timer := 0.0
var mine_playback_room := ""
var provisional: Dictionary = {}
var provisional_commands: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_settings()
	_install_input()
	_apply_theme()
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	click_sound = PlaceholderAudio.tone(680, 0.055, 0.12)
	dice_sound = PlaceholderAudio.tone(170, 0.16, 0.24)
	engine = EngineScript.new()
	engine.changed.connect(_state_changed)
	session = SessionScript.new()
	add_child(session)
	session.command_received.connect(_receive_command)
	session.snapshot_received.connect(_receive_snapshot)
	session.lobby_changed.connect(func(_lobby: Dictionary): _queue_render())
	session.connection_changed.connect(func(status: String): _notify(status); _queue_render())
	session.error_received.connect(_notify)
	session.command_result.connect(func(result: Dictionary):
		if not result.get("ok", false): _notify(str(result.get("error", "Command rejected"))))
	session.controller_connection_changed.connect(func(id: String, connected: bool):
		if session.is_host and not snapshot.is_empty(): engine.set_controller_connected(id, connected))
	session.recovery_required.connect(_show_recovery)
	session.invite_received.connect(_accept_steam_invite)
	session.fallback_requested.connect(func(id: String):
		if not _find_hero(id).get("fallback", false): _show_fallback(id))
	if session.has_signal("party_ping"):
		session.connect("party_ping", func(id: String, _subject: String, label: String): _notify(_unit_name(id) + " pings " + label))
	_render()

func _apply_theme() -> void:
	var t := Theme.new()
	t.default_font_size = int(16 * float(settings.text_scale))
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("77838c"))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("font_color", "RichTextLabel", PAPER)
	t.set_stylebox("normal", "Button", _style(Color("26333d"), LINE, 7, 12))
	t.set_stylebox("hover", "Button", _style(Color("354450"), GOLD, 7, 12))
	t.set_stylebox("pressed", "Button", _style(Color("3e4137"), GOLD, 7, 12))
	t.set_stylebox("disabled", "Button", _style(Color("172129"), Color("293640"), 7, 12))
	t.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD, 7, 0, 2))
	t.set_stylebox("normal", "LineEdit", _style(Color("101820"), LINE, 6, 10))
	t.set_stylebox("focus", "LineEdit", _style(Color("101820"), GOLD, 6, 10))
	t.set_stylebox("panel", "PopupMenu", _style(PANEL, LINE, 6, 12))
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_stylebox("background", "ProgressBar", _style(Color("0e151b"), Color("29353c"), 4, 0))
	t.set_stylebox("fill", "ProgressBar", _style(GREEN, GREEN, 4, 0))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 10)
	t.set_constant("v_separation", "GridContainer", 10)
	t.set_stylebox("panel", "TooltipPanel", _style(Color("222e38"), GOLD, 7, 14))
	t.set_color("font_color", "TooltipLabel", PAPER)
	theme = t

func _style(bg: Color, border: Color, radius: int = 8, padding: int = 16, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func _queue_render() -> void:
	if pending_render:
		return
	pending_render = true
	_render.call_deferred()

func _render() -> void:
	pending_render = false
	var focus_tag := ""
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused):
		focus_tag = str(focused.get_meta("focus_tag", ""))
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	move_child(page, 0)
	var bg := ColorRect.new()
	bg.color = INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(bg)
	var texture := Art.new()
	texture.kind = "background"
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(texture)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22 if edge != "bottom" else 12)
	page.add_child(margin)
	root_box = _vbox(margin, 14)
	_header()
	if snapshot.is_empty():
		if menu_page == "lobby":
			_lobby()
		else:
			_menu()
	else:
		_run_screen()
	_footer()
	if not focus_tag.is_empty():
		_restore_focus(page, focus_tag)

func _restore_focus(node: Node, tag: String) -> bool:
	if node is Control and str(node.get_meta("focus_tag", "")) == tag:
		node.grab_focus()
		return true
	for child in node.get_children():
		if _restore_focus(child, tag):
			return true
	return false

func _header() -> void:
	var row := _hbox(root_box)
	var logo := Art.new()
	logo.custom_minimum_size = Vector2(45, 45)
	row.add_child(logo)
	var title_col := _vbox(row, 0)
	_label(title_col, "ROGUE DICE", 24, GOLD)
	_label(title_col, "A SHARED HAND.  A DIFFERENT FATE.", 10, MUTED)
	_spacer(row)
	if not snapshot.is_empty():
		var depth := int(snapshot.get("room_index", 1))
		_label(row, "%s  /  %02d OF %02d" % ["THE EXPEDITION" if snapshot.get("profile") == "expedition_18" else "THE QUARRY", depth, 18 if snapshot.get("profile") == "expedition_18" else 9], 13, GOLD)
		_button(row, "Inventory  [I]", _show_inventory)
	_button(row, "Journal", _show_journal)
	_button(row, "Settings", _show_settings)
	if not snapshot.is_empty():
		_button(row, "Save & menu", _return_menu)

func _footer() -> void:
	var row := _hbox(root_box)
	_label(row, "MOUSE  ·  KEYBOARD  ·  CONTROLLER", 10, MUTED)
	_spacer(row)
	if snapshot.is_empty():
		_label(row, "GODOT REBUILD  /  PLACEHOLDER ART EDITION", 10, MUTED)
	else:
		_label(row, "SEED  %s   ·   %s   ·   SEAT %d" % [str(snapshot.get("seed", "")), str(snapshot.get("phase", "")).to_upper().replace("_", " "), _seat() + 1], 10, MUTED)

func _menu() -> void:
	var scroll := _scroll(root_box)
	var content := _vbox(scroll, 18)
	var mast := _panel(content, Color("18242c"), Color("4b4a3c"))
	var mast_row := _hbox(mast)
	var art := Art.new()
	art.kind = "die"
	art.custom_minimum_size = Vector2(160, 150)
	mast_row.add_child(art)
	var intro := _vbox(mast_row, 6)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(intro, "Fortune favors a well-kept pair.", 30, PAPER)
	_label(intro, "Roll five dice. Keep what matters. Every equipped gem draws power from the same hand.", 16, MUTED, true)
	_label(intro, "A cooperative expedition for 1–4 heroes • Local play and online parties", 13, GREEN)
	var row := _hbox(content)
	var setup := _panel(row)
	setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup.size_flags_stretch_ratio = 1.7
	_label(setup, "01   ASSEMBLE YOUR PARTY", 12, GOLD)
	var count_row := _hbox(setup)
	_label(count_row, "Local heroes", 14, MUTED)
	for count in range(1, 5):
		var b := _button(count_row, str(count), func():
			while menu_heroes.size() < count:
				menu_heroes.append(HERO_KEYS[menu_heroes.size() % 3])
			menu_heroes.resize(count)
			_queue_render())
		b.toggle_mode = true
		b.button_pressed = menu_heroes.size() == count
	for seat in range(menu_heroes.size()):
		var seat_row := _hbox(setup)
		_label(seat_row, "%02d" % (seat + 1), 16, GOLD)
		var names := LineEdit.new()
		names.text = menu_names[seat]
		names.placeholder_text = "Hero name"
		names.max_length = 24
		names.custom_minimum_size.x = 140
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.text_changed.connect(func(value: String): menu_names[seat] = value)
		seat_row.add_child(names)
		var choices := OptionButton.new()
		choices.custom_minimum_size.x = 150
		for key in HERO_KEYS:
			choices.add_item(key.capitalize())
		choices.selected = HERO_KEYS.find(menu_heroes[seat])
		choices.item_selected.connect(func(index: int): menu_heroes[seat] = HERO_KEYS[index]; _queue_render())
		seat_row.add_child(choices)
		var hero: Dictionary = Catalog.HEROES.get(menu_heroes[seat], Catalog.HEROES.get(menu_heroes[seat].to_upper(), {}))
		_label(setup, "%s  ·  %s HP  ·  %s" % [str(hero.get("trait_name", "")), hero.get("max_hp", 100), _join_values(hero.get("dice", []))], 13, GREEN, true)
		_label(setup, str(hero.get("description", "")), 12, MUTED, true)
		var starter_names: Array = []
		for starter in hero.get("starting_gems", []): starter_names.append(str(Catalog.SKILLS.get(starter[0], {}).get("name", starter[0])))
		_label(setup, "Starting gems: " + " · ".join(starter_names), 12, GOLD, true)
	var expedition := _panel(row)
	expedition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(expedition, "02   CHOOSE YOUR JOURNEY", 12, GOLD)
	var prof := OptionButton.new()
	prof.add_item("The Quarry · 9 rooms")
	prof.add_item("The Expedition · 18 rooms")
	prof.selected = 1 if profile == "expedition_18" else 0
	prof.item_selected.connect(func(index: int): profile = "short_9" if index == 0 else "expedition_18"; _queue_render())
	expedition.add_child(prof)
	_label(expedition, "One act. An elite at room 4, a camp at room 8, and the Slime King at room 9." if profile == "short_9" else "Three acts. The Quarry, Mirror Sanctum, and Rift. Each act ends with a distinct boss.", 14, MUTED, true)
	_label(expedition, "Optional numeric seed", 12, GOLD)
	var seed_edit := LineEdit.new()
	seed_edit.text = seed_text
	seed_edit.placeholder_text = "Leave blank for a new expedition"
	seed_edit.text_changed.connect(func(value: String): seed_text = value)
	expedition.add_child(seed_edit)
	_button(expedition, "Begin expedition  →", _begin_local, true)
	_button(expedition, "Continue saved run", _resume)
	var online := _panel(content)
	var network_row := _hbox(online)
	_label(network_row, "GATHER ONLINE", 12, GOLD)
	var name_edit := LineEdit.new()
	name_edit.text = player_name
	name_edit.placeholder_text = "Display name"
	name_edit.custom_minimum_size.x = 170
	name_edit.text_changed.connect(func(value: String): player_name = value)
	network_row.add_child(name_edit)
	_button(network_row, "Host LAN / direct", func(): menu_page = "lobby"; session.host_enet(player_name); _queue_render())
	var addr := LineEdit.new()
	addr.text = server_address
	addr.placeholder_text = "Host IP address"
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr.text_changed.connect(func(value: String): server_address = value)
	network_row.add_child(addr)
	_button(network_row, "Join", func(): menu_page = "lobby"; session.join_enet(server_address, player_name); _queue_render())
	var steam_row := _hbox(online)
	_label(steam_row, "STEAM", 12, BLUE)
	_button(steam_row, "Host Steam lobby", func(): menu_page = "lobby"; session.host_steam(player_name); _queue_render())
	var steam_edit := LineEdit.new()
	steam_edit.text = steam_lobby_text
	steam_edit.placeholder_text = "Steam lobby ID / invitation"
	steam_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steam_edit.text_changed.connect(func(value: String): steam_lobby_text = value)
	steam_row.add_child(steam_edit)
	_button(steam_row, "Join Steam", func(): menu_page = "lobby"; session.join_steam(steam_lobby_text, player_name); _queue_render())
	_label(online, "LAN uses port 24567. Steam lobbies require the compatible GodotSteam extension and the Steam client.", 12, MUTED, true)

func _lobby() -> void:
	var panel := _panel(_scroll(root_box))
	_label(panel, "THE PARTY TABLE", 28, GOLD)
	_label(panel, "Choose your hero, then mark ready. The host begins when every hero is ready.", 15, MUTED, true)
	var lobby: Dictionary = session.lobby
	_label(panel, "Transport: %s  ·  %s" % [str(lobby.get("transport", "offline")).to_upper(), str(session.status)], 13, GREEN)
	if lobby.has("lobby_id"):
		_label(panel, "Steam lobby ID: %s" % lobby.lobby_id, 14, GOLD)
	for member in lobby.get("members", []):
		var row := _hbox(panel)
		_label(row, "%02d   %s" % [int(member.get("seat", 0)) + 1, str(member.get("name", "Hero"))], 18)
		_label(row, "HOST" if member.get("player_id") == session.host_player_id else "GUEST", 11, GOLD)
		_spacer(row)
		_label(row, str(member.get("hero_id", "ardor")).capitalize(), 15, BLUE)
		_label(row, "READY" if member.get("ready", false) else "PLANNING", 12, GREEN if member.get("ready", false) else MUTED)
	var controls := _hbox(panel)
	var choices := OptionButton.new()
	for key in HERO_KEYS:
		choices.add_item(key.capitalize())
	choices.item_selected.connect(func(index: int): session.choose_hero(HERO_KEYS[index]))
	controls.add_child(choices)
	_button(controls, "Ready / unready", func():
		var ready := false
		for member in session.lobby.get("members", []):
			if str(member.get("player_id")) == str(session.local_player_id):
				ready = bool(member.get("ready", false))
		session.set_lobby_ready(not ready))
	if session.is_host:
		_button(controls, "Begin expedition", _begin_network, true).disabled = not session.can_start()
		_button(controls, "Reopen saved party", _resume_network)
		if session.transport_kind == "steam": _button(controls, "Invite friends", func(): session.invite_friends())
	_button(controls, "Leave lobby", func(): session.leave(); menu_page = "home"; _queue_render())

func _begin_local() -> void:
	if not seed_text.is_empty() and not seed_text.is_valid_int():
		_notify("Enter a whole-number seed, or leave it blank for a new expedition.")
		return
	session.start_offline(menu_names[0], menu_heroes[0])
	offline_hotseat = true
	var party: Array = []
	for i in range(menu_heroes.size()):
		party.append({"id": str(session.local_player_id) if i == 0 else "local_%d" % (i + 1), "hero_id": menu_heroes[i], "name": menu_names[i]})
	controlled_id = str(party[0].id)
	var result: Dictionary = engine.new_run({"heroes": party, "profile": profile, "seed": seed_text if not seed_text.is_empty() else str(Time.get_unix_time_from_system()), "host_id": controlled_id, "session_id": session.session_id})
	if result.has("error") and not result.get("ok", true):
		_notify(str(result.error))
	else:
		_state_changed(engine.state)

func _begin_network() -> void:
	if not seed_text.is_empty() and not seed_text.is_valid_int():
		_notify("Enter a whole-number seed, or leave it blank for a new expedition.")
		return
	var members: Array = session.start_run()
	if members.is_empty():
		_notify("Every hero must be ready before departure.")
		return
	offline_hotseat = false
	var party: Array = []
	for member in members:
		party.append({"id": member.get("player_id", member.get("id", "")), "name": member.get("name", "Hero"), "hero_id": member.get("hero_id", "ardor")})
	controlled_id = str(session.local_player_id)
	engine.new_run({"heroes": party, "profile": profile, "seed": seed_text if not seed_text.is_empty() else str(Time.get_unix_time_from_system()), "host_id": str(session.host_player_id), "session_id": session.session_id})
	_state_changed(engine.state)
	session.broadcast_snapshot(snapshot)

func _resume() -> void:
	var loaded: Dictionary = engine.save_store.load_checkpoint()
	if not loaded.get("ok", false):
		_notify(str(loaded.get("error", "No saved expedition was found.")))
		return
	var restored: Dictionary = loaded.state.duplicate(true)
	restored.paused = false
	for hero in restored.get("heroes", []):
		hero.connected = true
		hero.fallback = false
		hero.erase("disconnect_time")
	offline_hotseat = true
	var result: Dictionary = engine.restore(restored, loaded.get("command_history", {}))
	if result.has("ok") and not result.ok:
		_notify(str(result.get("error", "No saved expedition was found.")))
		return
	if engine.state.is_empty():
		_notify("No saved expedition was found.")
		return
	offline_hotseat = true
	controlled_id = str(engine.state.get("heroes", [{}])[0].get("id", ""))
	session.start_offline(player_name)
	_state_changed(engine.state)

func _state_changed(state: Dictionary) -> void:
	if snapshot.get("run_id", "") != state.get("run_id", ""):
		last_hands.clear()
		provisional.clear()
		provisional_commands.clear()
		observed_revision = -1
	for hero in state.get("heroes", []):
		if not hero.get("hand", []).is_empty(): last_hands[hero.id] = hero.hand.duplicate(true)
	snapshot = state.duplicate(true)
	if not snapshot.get("mine", {}).get("events", []).is_empty() and mine_playback_room != str(snapshot.get("room", {}).get("id", "")):
		mine_playback_room = str(snapshot.room.id)
		mine_playback_index = 0
		mine_playback_timer = 0.0
	if controlled_id.is_empty() and not snapshot.get("heroes", []).is_empty():
		controlled_id = str(snapshot.heroes[0].id)
	var phase := str(snapshot.get("phase", ""))
	if phase != last_phase:
		selected_dice.clear()
		_close_overlay()
		last_phase = phase
	var revision := int(snapshot.get("revision", 0))
	if revision != observed_revision:
		playback_events = snapshot.get("last_events", []).duplicate(true)
		playback_index = 0
		playback_timer = 0.0
	observed_revision = revision
	_queue_render()
	if is_instance_valid(session) and session.is_host and not offline_hotseat:
		session.broadcast_snapshot(snapshot)

func _receive_snapshot(state: Dictionary) -> void:
	offline_hotseat = false
	controlled_id = str(session.local_player_id)
	engine.state = state.duplicate(true)
	_state_changed(state)

func _receive_command(player_id: String, envelope: Dictionary) -> void:
	var result: Dictionary = engine.execute(player_id, envelope)
	session.reply_command(player_id, result)
	if not result.get("ok", false):
		_notify(str(result.get("error", "Command rejected")))

func _command(kind: String, payload: Dictionary = {}) -> void:
	if snapshot.is_empty():
		return
	var envelope: Dictionary = engine.make_envelope(controlled_id, kind, payload)
	if offline_hotseat or session.is_host:
		var result: Dictionary = engine.execute(controlled_id, envelope)
		if not result.get("ok", false):
			_notify(str(result.get("error", "That action is not available.")))
	else:
		session.send_command(envelope)

func _hero() -> Dictionary:
	for hero in snapshot.get("heroes", []):
		if str(hero.get("id")) == controlled_id:
			return hero
	return snapshot.get("heroes", [{}])[0] if not snapshot.get("heroes", []).is_empty() else {}

func _seat() -> int:
	return int(_hero().get("seat", 0))

func _run_screen() -> void:
	var body := _hbox(root_box, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_scroll := _scroll(body)
	side_scroll.custom_minimum_size.x = 240
	side_scroll.size_flags_horizontal = 0
	var side := _vbox(side_scroll, 10)
	_label(side, "PARTY ORDER", 11, GOLD)
	for hero in snapshot.get("heroes", []):
		_party_card(side, hero)
	_label(side, "ACT %d   ·   ROOM %d" % [int(snapshot.get("act", 1)), int(snapshot.get("room_index", 1))], 12, GOLD)
	_progress_track(side)
	var central_scroll := _scroll(body)
	central_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center := _vbox(central_scroll, 14)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var phase: String = str(snapshot.get("phase", "route"))
	match phase:
		"planning", "resolution", "combat": _battle(center)
		"route": _route(center)
		"support": _support(center)
		"mine_vote": _mine_vote(center)
		"mine_draft": _mine_draft(center)
		"reward": _rewards(center)
		"summary": _summary(center)
		_: _label(center, phase.capitalize(), 30, GOLD); _ready_button(center)

func _party_card(parent: Node, hero: Dictionary) -> void:
	var mine := str(hero.get("id")) == controlled_id
	var card := _panel(parent, Color("23323c") if mine else PANEL, GOLD if mine else LINE, 12)
	var row := _hbox(card, 6)
	_label(row, "%02d" % (int(hero.get("seat", 0)) + 1), 12, GOLD)
	_label(row, str(hero.get("player_name", hero.get("name", hero.get("key", "Hero")))), 17)
	_spacer(row)
	_label(row, "●" if hero.get("ready", false) else "○", 16, GREEN if hero.get("ready", false) else MUTED)
	_label(card, str(hero.get("key", "")).capitalize() + ("  ·  YOUR HAND" if mine else ""), 11, BLUE)
	var bar := ProgressBar.new()
	bar.max_value = int(hero.get("max_hp", 1))
	bar.value = int(hero.get("hp", 0))
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	card.add_child(bar)
	_label(card, "%d / %d HP   ·   %d BLOCK" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 1)), int(hero.get("block", 0))], 12, PAPER)
	_label(card, "%d GOLD   ·   %s" % [int(hero.get("gold", 0)), "DOWNED" if int(hero.get("hp", 0)) <= 0 else ("READY" if hero.get("ready", false) else "PLANNING")], 11, GOLD)
	var statuses := _status_text(hero)
	if not statuses.is_empty():
		_label(card, statuses, 12, RED, true)
	if snapshot.get("phase") == "planning":
		_label(card, "Enemy → " + _unit_name(str(hero.get("preferred_target", ""))), 11, MUTED, true)
		_label(card, "Ally → " + _unit_name(str(hero.get("friendly_target", hero.get("id", "")))), 11, MUTED, true)
		var mini_hand: Array = []
		for die in hero.get("hand", []):
			mini_hand.append(str(die.get("value", "?")))
		_label(card, "  ·  ".join(mini_hand), 18, GREEN)
		if not mine:
			var active_names: Array = []
			for gem in hero.get("gems", []):
				if gem.get("equipped", false):
					var preview: Dictionary = Combat.preview(hero, gem, hero.get("hand", []), snapshot)
					if preview.get("active", false): active_names.append(str(preview.get("name", gem.get("key", ""))))
			_label(card, "Ready gems: " + ", ".join(active_names), 11, GREEN, true)
	if offline_hotseat and not mine:
		_button(card, "Control this hero", func(): controlled_id = str(hero.id); selected_dice.clear(); _queue_render())
	elif not offline_hotseat and not bool(hero.get("connected", true)):
		_label(card, "DISCONNECTED · %ds grace remaining" % _grace_remaining(hero), 11, RED, true)
		if session.is_host:
			_button(card, "Recovery options", func(): _show_fallback(str(hero.id)))

func _progress_track(parent: Node) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 5)
	parent.add_child(row)
	var total := 18 if snapshot.get("profile") == "expedition_18" else 9
	for i in range(1, total + 1):
		var completed := i < int(snapshot.get("room_index", 1))
		var is_boss := (i % 6 == 0) if total == 18 else (i == 9)
		var label := _label(row, "◆" if is_boss else ("■" if completed else "□"), 17, GOLD if i == int(snapshot.get("room_index", 1)) else (GREEN if completed else LINE))
		label.tooltip_text = "Room %d%s" % [i, " · Boss" if is_boss else ""]

func _battle(parent: Node) -> void:
	die_buttons.clear()
	var heading := _hbox(parent)
	_label(heading, str(snapshot.get("room", {}).get("name", "Battle")), 27, GOLD)
	_spacer(heading)
	var turn := int(snapshot.get("turn", 1))
	_label(heading, "TURN %02d" % turn, 14, PAPER)
	_button(heading, "Preview this turn", _show_forecast)
	if turn >= 7:
		_label(parent, "ENRAGE  +%d raw damage to each enemy hit" % (2 * (turn - 6)), 13, RED)
	var enemies := HFlowContainer.new()
	enemies.add_theme_constant_override("h_separation", 10)
	enemies.add_theme_constant_override("v_separation", 10)
	parent.add_child(enemies)
	for enemy in snapshot.get("enemies", []):
		_enemy_card(enemies, enemy)
	var hand_panel := _panel(parent)
	var hand_heading := _hbox(hand_panel)
	_label(hand_heading, "YOUR SHARED HAND", 12, GOLD)
	_spacer(hand_heading)
	_label(hand_heading, "%d REROLL LEFT" % int(_hero().get("rerolls", 0)), 12, GREEN)
	_label(hand_panel, "Selected dice reroll. Unselected dice stay. Every active gem uses the complete final hand.", 13, MUTED, true)
	var dice_row := _hbox(hand_panel, 12)
	var hero := _hero()
	for i in range(hero.get("dice", []).size()):
		_die_button(dice_row, hero.dice[i], i)
	var action_row := _hbox(hand_panel)
	var reroll := _button(action_row, "Reroll selected  [%s]" % _binding_name("rd_reroll"), _reroll, true)
	reroll.disabled = selected_dice.is_empty() or int(hero.get("rerolls", 0)) <= 0 or hero.get("ready", false) or int(hero.get("hp", 0)) <= 0
	if str(hero.get("key", "")).to_lower() == "max":
		var extra := _button(action_row, "Second Thought  ·  %d charge" % int(hero.get("trait_charges", 0)), func():
			if selected_dice.size() == 1:
				_command("UseHeroTrait", {"die_id": selected_dice[0]})
				selected_dice.clear())
		extra.disabled = selected_dice.size() != 1 or int(hero.get("trait_charges", 0)) <= 0 or hero.get("ready", false)
	_spacer(action_row)
	_ready_button(action_row)
	var targets := _hbox(hand_panel)
	_label(targets, "Friendly target", 12, MUTED)
	for ally in snapshot.get("heroes", []):
		var b := _button(targets, str(ally.get("player_name", ally.get("name", "Hero"))), func(): _command("SetFriendlyTarget", {"unit_id": ally.id}))
		b.toggle_mode = true
		b.button_pressed = str(hero.get("friendly_target", hero.get("id"))) == str(ally.id)
		b.disabled = hero.get("ready", false)
	var allowance := 8 + 4 * (int(snapshot.get("act", 1)) - 1)
	_label(hand_panel, "Combat gold allowance: %d / %d remaining. Room rewards are separate." % [maxi(0, allowance - int(hero.get("combat_gold", 0))), allowance], 11, MUTED)
	var gem_header := _hbox(parent)
	_label(gem_header, "GEMS  /  EXECUTE IN THIS ORDER", 12, GOLD)
	_spacer(gem_header)
	_label(gem_header, "Hover or inspect for trigger, effects, targets, and dice.", 11, MUTED)
	var grid := GridContainer.new()
	grid.columns = 3
	parent.add_child(grid)
	var ordinal := 0
	var ordered_previews: Array = Combat.preview_loadout(hero, snapshot)
	for gem in hero.get("gems", []):
		if not gem.get("equipped", false): continue
		ordinal += 1
		var preview: Dictionary = ordered_previews[ordinal - 1] if ordinal <= ordered_previews.size() else Combat.preview(hero, gem, hero.get("hand", []), snapshot)
		var active: bool = preview.get("active", false)
		var card := _panel(grid, Color("1e302e") if active else PANEL, GREEN if active else LINE, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := _hbox(card)
		_label(top, "%02d   %s" % [ordinal, _gem_name(gem)], 16, PAPER)
		_spacer(top)
		_label(top, "ACTIVE" if active else "DORMANT", 10, GREEN if active else MUTED)
		_label(card, _gem_stats(gem), 11, GOLD)
		_label(card, str(preview.get("summary", "")) if active else str(preview.get("reason", preview.get("trigger", ""))), 13, GREEN if active else MUTED, true)
		_button(card, "Inspect gem", func(): _inspect_gem(gem))
		card.tooltip_text = _preview_text(gem)
		card.mouse_entered.connect(func(): _highlight_dice(preview.get("contributing_dice", [])))
		card.mouse_exited.connect(func(): _highlight_dice([]))
	_log_preview(parent)

func _enemy_card(parent: Node, enemy: Dictionary) -> void:
	var living := int(enemy.get("hp", 0)) > 0
	var targeted := str(_hero().get("preferred_target", "")) == str(enemy.get("id"))
	var card := _panel(parent, Color("2b2729") if targeted else PANEL, GOLD if targeted else LINE, 10)
	card.get_parent().size_flags_horizontal = 0
	card.custom_minimum_size.x = 260
	card.add_theme_constant_override("separation", 5)
	var head := _hbox(card, 6)
	var art := Art.new()
	art.kind = str(enemy.get("key", "enemy"))
	art.tint = GREEN if art.kind.to_lower().contains("slime") else RED
	art.custom_minimum_size = Vector2(48, 48)
	head.add_child(art)
	var info := _vbox(head, 4)
	_label(info, str(enemy.get("name", "Enemy")), 15, PAPER)
	_label(info, "%d / %d HP" % [int(enemy.get("hp", 0)), int(enemy.get("max_hp", 1))], 12, RED if living else MUTED)
	_label(info, "%d BLOCK" % int(enemy.get("block", 0)), 11, BLUE)
	var status := _status_text(enemy)
	if not status.is_empty(): _label(card, status, 11, RED, true)
	if bool(enemy.get("boss", false)):
		_label(card, "Resolve: after 1 stun skip, immune for 2 slots.", 10, GOLD, true)
	_label(card, "INTENT" + (" · WILL BE SKIPPED" if int(enemy.get("statuses", {}).get("stun", 0)) > 0 else ""), 10, GOLD)
	for intent in enemy.get("intents", []):
		_label(card, str(intent.get("name", intent.get("key", ""))) + "  →  " + _intent_target(enemy, intent), 12, PAPER, true)
		_label(card, str(intent.get("summary", "")), 11, MUTED, true)
	var enemy_buttons := _hbox(card, 6)
	var b := _button(enemy_buttons, "◎ Targeted" if targeted else "Target", func(): _command("SetPreferredTarget", {"unit_id": enemy.id}))
	b.disabled = not living or _hero().get("ready", false)
	_button(enemy_buttons, "Inspect / ping", func(): _inspect_unit(enemy))

func _die_button(parent: Node, die: Dictionary, index: int) -> void:
	var value := "—"
	for roll in _hero().get("hand", []):
		if str(roll.get("die_id")) == str(die.get("id")):
			value = str(roll.get("value", "?"))
	var selected := selected_dice.has(str(die.id))
	var button := _button(parent, "%s\n%s  ·  %d\n%s" % [value, str(die.get("shape", "D6")), index + 1, "REROLL" if selected else "KEEP"], func(): _toggle_die(str(die.id)))
	button.custom_minimum_size = Vector2(100, 106)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 19)
	button.toggle_mode = true
	button.button_pressed = selected
	button.set_meta("focus_tag", "die_" + str(index))
	die_buttons[str(die.id)] = button
	button.tooltip_text = "%s\nFaces: %s\nEvery physical face has equal probability.\nSelected means reroll. Press %d to toggle." % [_die_name(die), _faces_text(die), index + 1]
	button.disabled = bool(_hero().get("ready", false)) or int(_hero().get("hp", 0)) <= 0
	if selected:
		button.add_theme_stylebox_override("normal", _style(Color("494133"), GOLD, 8, 10, 2))
		button.add_theme_stylebox_override("pressed", _style(Color("494133"), GOLD, 8, 10, 2))

func _toggle_die(id: String) -> void:
	if _hero().get("ready", false): return
	if selected_dice.has(id): selected_dice.erase(id)
	else: selected_dice.append(id)
	_queue_render()

func _reroll() -> void:
	if selected_dice.is_empty(): return
	_play_sound(dice_sound)
	_command("RerollDice", {"die_ids": selected_dice.duplicate()})
	selected_dice.clear()

func _route(parent: Node) -> void:
	_label(parent, "Choose the next room.", 30, GOLD)
	_label(parent, "The party votes together. Ties follow the host’s vote. Change equipment before committing.", 14, MUTED, true)
	var offers: Array = snapshot.get("offers", [])
	for offer in offers:
		var panel := _panel(parent)
		var row := _hbox(panel)
		var art := Art.new()
		art.kind = "die" if str(offer.get("kind", "")) in ["battle", "elite", "boss"] else "gem"
		art.custom_minimum_size = Vector2(70, 70)
		row.add_child(art)
		var text := _vbox(row, 5)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(text, str(offer.get("name", "Room")), 22, PAPER)
		_label(text, str(offer.get("description", "")), 14, MUTED, true)
		if offer.get("kind") == "rest":
			_label(text, "Your recovery: +%d HP (downed heroes revive)." % mini(int(_hero().get("max_hp", 0)) / 3, int(_hero().get("max_hp", 0)) - int(_hero().get("hp", 0))), 13, GREEN)
		_button(row, "Vote to enter  →", func(): _command("VoteRoom", {"offer_id": offer.id}), true)
		_button(row, "Ping", func(): _ping("room", str(offer.id), str(offer.get("name", "Room"))))
		var votes: Array = []
		for hero in snapshot.get("heroes", []):
			if str(snapshot.get("votes", {}).get(hero.get("id", ""), "")) == str(offer.id): votes.append(str(hero.get("player_name", hero.get("name", "Hero"))))
		if not votes.is_empty(): _label(panel, "Votes: " + ", ".join(votes), 12, GREEN)
	_label(parent, "Milestones: elite 4 · camp 8 · boss 9" if snapshot.get("profile") == "short_9" else "Each act: battle · route · elite · route · camp · boss", 13, BLUE)
	_button(parent, "Review equipment", _show_inventory)

func _support(parent: Node) -> void:
	var room: Dictionary = snapshot.get("room", {})
	_label(parent, str(room.get("name", "A quiet moment")), 30, GOLD)
	match str(room.get("kind", "")):
		"shop": _shop(parent)
		"workshop": _workshop(parent)
		"lapidary": _lapidary(parent)
		"rest":
			_label(parent, "The fire burns low. Your party has recovered one third of maximum HP; fallen heroes return to their feet.", 16, MUTED, true)
			_label(parent, "Prepare your dice and gems before the road continues.", 14, GREEN)
			_button(parent, "Manage equipment", _show_inventory)
		"event": _event(parent)
		"mine": _mine_draft(parent)
	_ready_button(parent)

func _shop(parent: Node) -> void:
	_label(parent, "Personal stock • One purchase per offer • Sell reserve gear from inventory", 14, MUTED, true)
	var stock: Dictionary = snapshot.get("shop", {}).get(controlled_id, {})
	for offer in stock.get("gems", []):
		var gem: Dictionary = offer.get("gem", {})
		var panel := _panel(parent)
		var row := _hbox(panel)
		_gem_details(row, gem)
		_button(row, "Sold" if offer.get("claimed", false) else "Buy  ·  %d gold" % int(offer.get("price", 0)), func(): _command("BuyGem", {"offer_id": offer.id}), true).disabled = offer.get("claimed", false) or _hero().get("ready", false) or int(_hero().get("gold", 0)) < int(offer.get("price", 0))
	for offer in stock.get("dice", []):
		var die: Dictionary = offer.get("die", {})
		var panel := _panel(parent)
		var row := _hbox(panel)
		var info := _vbox(row)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(info, _die_name(die), 18, BLUE)
		_label(info, "Faces: " + _faces_text(die), 13, MUTED, true)
		_button(row, "Sold" if offer.get("claimed", false) else "Buy die  ·  %d gold" % int(offer.get("price", 0)), func(): _command("BuyDie", {"offer_id": offer.id}), true).disabled = offer.get("claimed", false) or _hero().get("ready", false) or int(_hero().get("gold", 0)) < int(offer.get("price", 0))
	_button(parent, "Inventory / sell items", _show_inventory)

func _workshop(parent: Node) -> void:
	_label(parent, "One service per hero per visit · 5 gold · Tinker’s Belt may cover the first service this act", 14, MUTED, true)
	_label(parent, "Changing shape restores standard faces and removes all engravings. Engraving changes one physical face.", 13, GOLD, true)
	if snapshot.get("room", {}).get("services", {}).get(controlled_id, false):
		_label(parent, "Your workshop service is complete.", 16, GREEN)
		return
	var shapes := ["D4", "D6", "D8", "D10", "D12", "D20"]
	for die in _hero().get("dice", []) + _hero().get("reserve_dice", []):
		var panel := _panel(parent)
		_label(panel, _die_name(die) + "  ·  " + _faces_text(die), 17, BLUE, true)
		var row := _hbox(panel)
		var shape_i := shapes.find(str(die.get("shape", "D6")))
		for offset in [-1, 1]:
			var next: int = shape_i + int(offset)
			if next >= 0 and next < shapes.size():
				_button(row, "Replace with " + shapes[next], func(): _confirm_shape(die, shapes[next]))
		_button(row, "Engrave a face…", func(): _engrave(die))

func _confirm_shape(die: Dictionary, shape: String) -> void:
	var box := _modal("Replace " + str(die.get("shape", "die")) + " with " + shape)
	_label(box, "Before: " + _faces_text(die), 15, MUTED, true)
	var faces: Array = []
	for n in range(1, int(shape.trim_prefix("D")) + 1): faces.append(str(n))
	_label(box, "After: " + ", ".join(faces), 15, GREEN, true)
	_label(box, "All previous face engravings are removed. Price: 5 gold, or the available Tinker’s Belt service.", 14, GOLD, true)
	_button(box, "Confirm replacement", func(): _close_overlay(); _command("ModifyDie", {"die_id": die.id, "service": "shape", "shape": shape}), true)

func _engrave(die: Dictionary) -> void:
	var box := _modal("Engrave " + _die_name(die))
	_label(box, "Select one face and its new value. Every physical face remains equally likely.", 15, MUTED, true)
	var face_choice := OptionButton.new()
	var faces: Array = die.get("faces", [])
	for i in range(faces.size()):
		var face = faces[i]
		face_choice.add_item("Face %d · currently %s" % [i + 1, str(face.get("value", 0) if face is Dictionary else face)])
	box.add_child(face_choice)
	var value := SpinBox.new()
	value.min_value = 1
	value.max_value = int(str(die.get("shape", "D6")).trim_prefix("D"))
	value.step = 1
	value.value = 1
	box.add_child(value)
	_label(box, "Price: 5 gold, or an available Tinker’s Belt service. One service per visit.", 13, GOLD, true)
	_button(box, "Confirm engraving", func():
		var selected := face_choice.selected
		var new_value := int(value.value)
		_close_overlay()
		_command("ModifyDie", {"die_id": die.id, "service": "face", "face_index": selected, "value": new_value}), true)

func _lapidary(parent: Node) -> void:
	_label(parent, "Improve one gem per visit. Cut and Clarity cost 5 × the new rank; Carat is found on your travels.", 14, MUTED, true)
	for gem in _hero().get("gems", []):
		var panel := _panel(parent)
		_gem_details(panel, gem)
		var row := _hbox(panel)
		for property in ["cut", "clarity"]:
			var rank := int(gem.get(property, 1))
			var b := _button(row, "%s %d → %d · %d gold" % [property.capitalize(), rank, mini(5, rank + 1), 5 * (rank + 1)], func(): _upgrade_preview(gem, property))
			b.disabled = rank >= 5 or _hero().get("ready", false) or snapshot.get("room", {}).get("services", {}).get(controlled_id, false)

func _upgrade_preview(gem: Dictionary, property: String) -> void:
	var box := _modal("Improve " + _gem_name(gem))
	var improved := gem.duplicate(true)
	improved[property] = int(gem.get(property, 1)) + 1
	_label(box, "BEFORE  ·  " + _gem_stats(gem), 13, GOLD)
	_label(box, _preview_text(gem), 14, MUTED, true)
	_label(box, "AFTER  ·  " + _gem_stats(improved), 13, GREEN)
	_label(box, _preview_text(improved), 14, PAPER, true)
	_label(box, "Using your last combat hand: %s. This compares gem properties, not a prediction of future rolls. Changes to dice will change future probabilities." % _hand_values(_preview_hand()), 12, MUTED, true)
	var cost := int(improved[property]) * 5
	_button(box, "Improve %s · %d gold" % [property.capitalize(), cost], func(): _close_overlay(); _command("UpgradeGem", {"gem_id": gem.id, "property": property}), true).disabled = int(_hero().get("gold", 0)) < cost

func _event(parent: Node) -> void:
	if snapshot.get("room", {}).get("services", {}).get(controlled_id, false):
		_label(parent, "Your event choice is settled. Mark Done when your equipment is ready.", 16, GREEN, true)
		return
	var event: Dictionary = snapshot.get("event", {})
	var key := str(event.get("key", "ABANDONED_CACHE"))
	var options: Array = {
		"ABANDONED_CACHE": ["Take 6 gold", "Lose 8 HP for the shown gem (+2 Carat). You must have more than 8 HP."],
		"FIELD_MEDIC": ["Take 4 gold", "Pay 8 gold to heal %d HP" % int(ceil(float(_hero().get("max_hp", 0)) * 0.2))],
		"ECHO_SHRINE": ["Take 5 gold", "Replace an owned D6 with a Paired, Odd, or Even D6. Current engravings are lost."],
		"JEWEL_BROKER": ["Take 4 gold", "Exchange one reserve gem for one of the offers below."]
	}.get(key, ["Take gold", "Choose the offered trade"])
	_label(parent, str(options[0]), 18, GOLD, true)
	_button(parent, "Accept gold", func(): _command("EventChoice", {"option": "a"}))
	_label(parent, str(options[1]), 16, MUTED, true)
	var offers: Array = event.get("offers", {}).get(controlled_id, [])
	for offer in offers:
		var gem: Dictionary = offer.get("gem", offer)
		var panel := _panel(parent)
		_gem_details(panel, gem)
		if key == "JEWEL_BROKER":
			for owned in _hero().get("gems", []):
				if not owned.get("equipped", false):
					_button(panel, "Trade " + _gem_name(owned) + " for this", func(): _command("EventChoice", {"option": "b", "gem_id": owned.id, "offer_id": offer.get("id", gem.get("id", ""))}))
	if key == "ECHO_SHRINE":
		for die in _hero().get("dice", []) + _hero().get("reserve_dice", []):
			if die.get("shape") != "D6": continue
			var row := _hbox(parent)
			_label(row, _die_name(die) + " (" + _faces_text(die) + ")", 13, BLUE, true)
			for variant in ["PAIRED_D6", "ODD_D6", "EVEN_D6"]:
				var b := _button(row, variant.trim_suffix("_D6").capitalize(), func(): _command("EventChoice", {"option": "b", "die_id": die.id, "variant": variant}))
				b.tooltip_text = "New faces: " + _join_values(Catalog.DICE.get(variant, {}).get("faces", [])) + "\nPrevious engraving is lost."
	elif key != "JEWEL_BROKER":
		_button(parent, "Accept the trade", func(): _command("EventChoice", {"option": "b"}), true)
	_button(parent, "Leave without a transaction", func(): _command("EventChoice", {"option": "leave"}))

func _mine_vote(parent: Node) -> void:
	_label(parent, "Choose a vein.", 30, GOLD)
	_label(parent, "The party chooses together. Mining is automatic: fixed energy, round-robin hits, shared gold, and a personal gem draft.", 15, MUTED, true)
	var row := _hbox(parent)
	for key in ["coin", "crystal"]:
		var box := _panel(row)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(box, "Coin Vein" if key == "coin" else "Crystal Vein", 24, GOLD if key == "coin" else BLUE)
		_label(box, "More short rocks and direct currency." if key == "coin" else "More work per rock, with more gem-bearing rocks.", 14, MUTED, true)
		_label(box, "Small / Medium / Large / Gold / Shiny\n4 / 4 / 2 / 2 / 0" if key == "coin" else "Small / Medium / Large / Gold / Shiny\n1 / 3 / 4 / 0 / 2", 13, PAPER, true)
		_label(box, "These are rock weights, not a guaranteed yield.", 12, MUTED, true)
		_button(box, "Vote for " + key.capitalize(), func(): _command("VoteVein", {"vein": key}), true)
	for hero in snapshot.get("heroes", []):
		var energy := 10
		for relic in hero.get("relics", []):
			if relic.get("key") == "MINERS_LANTERN" and relic.get("equipped", false): energy += 2
		if int(hero.get("hp", 0)) <= 0: energy = 0
		_label(parent, "%s · %d energy" % [str(hero.get("player_name", hero.get("name", "Hero"))), energy], 14, GREEN)

func _mine_draft(parent: Node) -> void:
	var mine: Dictionary = snapshot.get("mine", {})
	_label(parent, "The mine’s yield", 28, GOLD)
	_label(parent, "Gold found: %s · Divided among every hero. Extra coins rotate by party seat." % str(mine.get("gold", 0)), 15, GREEN, true)
	var rocks: Array = mine.get("rocks", [])
	if not rocks.is_empty():
		var row := HFlowContainer.new()
		parent.add_child(row)
		for rock in rocks:
			_label(row, "%s  %s   " % [str(rock.get("name", rock.get("kind", rock.get("key", "Rock")))), "✓" if rock.get("broken", false) else "◇"], 12, GREEN if rock.get("broken", false) else MUTED)
	mine_playback_label = _label(parent, "", 14, BLUE, true)
	_button(parent, "Skip playback  [F]", _skip_playback)
	var pool: Array = mine.get("pool", [])
	if pool.is_empty():
		_label(parent, "No unclaimed gems remain. Even an empty result completes the visit.", 16, MUTED, true)
		_ready_button(parent)
		return
	var picker := str(mine.get("picker_id", ""))
	_label(parent, "Next pick: " + _unit_name(picker), 18, GOLD)
	for claim in pool:
		var panel := _panel(parent)
		_gem_details(panel, claim.get("gem", {}))
		_button(panel, "Claim this gem", func(): _command("DraftGem", {"claim_id": claim.claim_id}), true).disabled = picker != controlled_id

func _rewards(parent: Node) -> void:
	_label(parent, "The spoils are yours.", 30, GOLD)
	_label(parent, "Every hero has personal offers. New items go to reserve; equip them before the next battle.", 14, MUTED, true)
	var reward: Dictionary = snapshot.get("reward_offers", {}).get(controlled_id, {})
	if not reward.get("gem_done", true):
		_label(parent, "CHOOSE ONE GEM", 12, GOLD)
		for offer in reward.get("gems", []):
			var gem: Dictionary = offer.get("gem", offer)
			var panel := _panel(parent)
			var row := _hbox(panel)
			_gem_details(row, gem)
			_button(row, "Take gem", func(): _command("ChooseReward", {"kind": "gem", "offer_id": offer.get("id", gem.get("id", ""))}), true)
		_button(parent, "Decline gems · gain 3 gold", func(): _command("ChooseReward", {"kind": "gem", "offer_id": ""}))
	if not reward.get("relic_done", true):
		_label(parent, "CHOOSE ONE RELIC", 12, GOLD)
		for offer in reward.get("relics", []):
			var relic: Dictionary = offer.get("relic", offer)
			var definition: Dictionary = Catalog.RELICS.get(relic.get("key", ""), {})
			var panel := _panel(parent)
			_label(panel, str(definition.get("name", relic.get("key", "Relic"))), 20, GOLD)
			_label(panel, str(definition.get("description", "")), 14, MUTED, true)
			_button(panel, "Take relic", func(): _command("ChooseReward", {"kind": "relic", "offer_id": offer.get("id", relic.get("id", ""))}), true)
		_button(parent, "Decline relic", func(): _command("ChooseReward", {"kind": "relic", "offer_id": ""}))
	if reward.get("gem_done", true) and reward.get("relic_done", true):
		_label(parent, "Your rewards are settled.", 18, GREEN)
		_button(parent, "Prepare your equipment", _show_inventory)
		_ready_button(parent)

func _summary(parent: Node) -> void:
	var victory := str(snapshot.get("outcome", snapshot.get("result", ""))) in ["victory", "won"]
	_label(parent, "THE PARTY PREVAILS" if victory else "THE EXPEDITION ENDS", 34, GOLD)
	_label(parent, "Every kept pair, every shared shield, every final roll brought you here." if victory else "The dice rest. A different hand awaits the next expedition.", 17, MUTED, true)
	_label(parent, "Profile: %s   ·   Seed: %s   ·   Room %d" % [str(snapshot.get("profile", "")), str(snapshot.get("seed", "")), int(snapshot.get("room_index", 1))], 14, BLUE, true)
	for hero in snapshot.get("heroes", []):
		var box := _panel(parent)
		_label(box, "%s  ·  %d gold  ·  %d / %d HP" % [str(hero.get("player_name", hero.get("name", "Hero"))), int(hero.get("gold", 0)), int(hero.get("hp", 0)), int(hero.get("max_hp", 1))], 18, GOLD)
		var names: Array = []
		for gem in hero.get("gems", []):
			if gem.get("equipped", false): names.append(_gem_name(gem))
		_label(box, "Equipped: " + ", ".join(names), 13, MUTED, true)
	_button(parent, "Read the combat record", _show_log)
	_button(parent, "Return to the table", _return_menu, true)

func _ready_button(parent: Node) -> Button:
	var ready: bool = _hero().get("ready", false)
	var combat := str(snapshot.get("phase", "")) == "planning"
	var text := "Unlock hand" if ready else ("Lock in hand" if combat else "Done / ready")
	var b := _button(parent, text + "  [%s]" % _binding_name("rd_ready"), func(): _command("SetReady", {"ready": not ready}), not ready)
	b.set_meta("focus_tag", "ready")
	if combat and int(_hero().get("hp", 0)) <= 0: b.disabled = true
	return b

func _process(delta: float) -> void:
	if is_instance_valid(mine_playback_label):
		var hits: Array = snapshot.get("mine", {}).get("events", [])
		if not hits.is_empty():
			mine_playback_timer += delta * float(settings.playback_speed)
			if settings.reduced_motion or float(settings.playback_speed) >= 100.0: mine_playback_index = hits.size()
			elif mine_playback_timer >= 0.25:
				mine_playback_index = mini(hits.size(), mine_playback_index + 1)
				mine_playback_timer = 0.0
			var step := clampi(mine_playback_index, 1, hits.size())
			var hit: Dictionary = hits[step - 1]
			mine_playback_label.text = "Hit %d/%d · %s · Rock %d/%d%s" % [step, hits.size(), _unit_name(str(hit.get("actor_id", ""))), int(hit.get("progress", 0)), int(hit.get("hits", 1)), " · BROKEN" if hit.get("broken", false) else ""]
	if not is_instance_valid(playback_label) or playback_events.is_empty(): return
	if settings.reduced_motion or float(settings.playback_speed) >= 100.0:
		playback_index = playback_events.size()
	playback_timer += delta * float(settings.playback_speed)
	if playback_timer >= 0.55 and playback_index < playback_events.size():
		playback_index += 1
		playback_timer = 0.0
	var shown := clampi(playback_index, 1, playback_events.size())
	playback_label.text = "[%d / %d] %s" % [shown, playback_events.size(), _log_text(playback_events[shown - 1])]

func _intent_target(actor: Dictionary, intent: Dictionary) -> String:
	var labels: Array = []
	for effect in intent.get("effects", []):
		var target: String = str(effect.get("target", "enemy"))
		var caption := ""
		match target:
			"self": caption = str(actor.get("name", "Self"))
			"allies": caption = "All allies"
			"enemies": caption = "All heroes"
			"ally": caption = _unit_name(str(intent.get("friendly_target_id", actor.get("id", ""))))
			_: caption = _unit_name(str(intent.get("target_id", "")))
		if not labels.has(caption): labels.append(caption)
	return ", ".join(labels)

func _find_hero(id: String) -> Dictionary:
	for hero in snapshot.get("heroes", []):
		if str(hero.get("id", "")) == id: return hero
	return {}

func _grace_remaining(hero: Dictionary) -> int:
	for member in session.lobby.get("members", []):
		if str(member.get("player_id", "")) == str(hero.get("id", "")):
			return int(member.get("grace_remaining", 0))
	return maxi(0, 60 - int(Time.get_unix_time_from_system() - float(hero.get("disconnect_time", Time.get_unix_time_from_system()))))

func _log_preview(parent: Node) -> void:
	var box := _panel(parent, Color("121c24"), LINE, 12)
	var row := _hbox(box)
	_label(row, "BATTLE RECORD", 11, GOLD)
	_spacer(row)
	_button(row, "Full log", _show_log)
	_button(row, "Skip playback [F]", _skip_playback)
	playback_label = _label(box, "", 13, GREEN, true)
	var entries: Array = snapshot.get("log", [])
	if entries.is_empty():
		_label(box, "Enemy intentions are published. Set targets, select rerolls, then lock in.", 12, MUTED, true)
	else:
		for entry in entries.slice(maxi(0, entries.size() - 3)):
			_label(box, _log_text(entry), 12, MUTED, true)

func _show_inventory() -> void:
	if snapshot.is_empty(): return
	var planning := str(snapshot.get("phase", "")) == "planning"
	var can_plan := planning and int(_hero().get("hp", 0)) <= 0
	var inventory_hero: Dictionary = _hero()
	if can_plan:
		if not provisional.has(controlled_id):
			provisional[controlled_id] = _hero().duplicate(true)
			provisional_commands[controlled_id] = []
		inventory_hero = provisional[controlled_id]
	var box := _modal("%s’s equipment" % str(inventory_hero.get("player_name", inventory_hero.get("name", "Hero"))))
	var locked := (planning and not can_plan) or bool(inventory_hero.get("ready", false))
	_label(box, "Six gem slots · One of each skill · Strike stays equipped · Three relic slots · Five active dice", 13, GOLD, true)
	if can_plan:
		_label(box, "PROVISIONAL PLAN · You are downed. These edits stay local and do not change combat. Apply the plan between rooms after rally.", 14, GREEN, true)
	elif provisional_commands.get(controlled_id, []).size() > 0:
		_label(box, "Your provisional loadout is ready to review. It applies only in this between-room equipment window.", 14, GREEN, true)
		var plan_row := _hbox(box)
		_button(plan_row, "Apply planned changes", _commit_provisional, true).disabled = locked
		_button(plan_row, "Discard plan", func(): provisional.erase(controlled_id); provisional_commands.erase(controlled_id); _show_inventory())
	if locked:
		_label(box, "Equipment is frozen while fighting or ready. You can inspect every item.", 14, MUTED, true)
	_label(box, "EQUIPPED GEMS / EXECUTION ORDER", 12, GOLD)
	var equipped: Array = []
	for gem in inventory_hero.get("gems", []):
		if gem.get("equipped", false): equipped.append(gem)
	for i in range(equipped.size()):
		var gem: Dictionary = equipped[i]
		var card := _panel(box)
		var row := _hbox(card)
		_label(row, "%02d" % (i + 1), 16, GOLD)
		_gem_details(row, gem)
		var controls := _vbox(row, 5)
		_button(controls, "↑ Earlier", func(): _reorder(equipped, i, -1)).disabled = locked or i == 0
		_button(controls, "↓ Later", func(): _reorder(equipped, i, 1)).disabled = locked or i == equipped.size() - 1
		_button(controls, "Unequip", func(): _inventory_command("EquipGem", {"gem_id": gem.id})).disabled = locked or gem.get("key") == "STRIKE"
	_label(box, "RESERVE GEMS", 12, GOLD)
	var reserves := 0
	for gem in inventory_hero.get("gems", []):
		if gem.get("equipped", false): continue
		reserves += 1
		var card := _panel(box)
		_gem_details(card, gem)
		var row := _hbox(card)
		var replacement := ""
		for active in equipped:
			if active.get("key") == gem.get("key"): replacement = str(active.id)
		_button(row, "Replace equipped copy" if not replacement.is_empty() else "Equip gem", func(): _inventory_command("EquipGem", {"gem_id": gem.id, "replace_id": replacement})).disabled = locked or (equipped.size() >= 6 and replacement.is_empty())
		if equipped.size() >= 6 and replacement.is_empty():
			for active in equipped:
				if active.get("key") != "STRIKE":
					_button(row, "Replace " + _gem_name(active), func(): _inventory_command("EquipGem", {"gem_id": gem.id, "replace_id": active.id})).disabled = locked
		if snapshot.get("room", {}).get("kind") == "shop" and snapshot.get("phase") == "support":
			_button(row, "Sell · %d gold" % (Catalog.gem_value(gem) / 2), func(): _inventory_command("SellGem", {"gem_id": gem.id})).disabled = locked
	if reserves == 0: _label(box, "Your reserve is empty. Battle rewards and merchants offer new gems.", 13, MUTED, true)
	_label(box, "DICE / SELECT AN ACTIVE SLOT, THEN A RESERVE DIE TO SWAP", 12, GOLD)
	for die in inventory_hero.get("dice", []):
		var b := _button(box, ("SELECTED  ·  " if selected_active_die == str(die.id) else "") + _die_name(die) + "  |  " + _faces_text(die), func(): selected_active_die = str(die.id); _show_inventory())
		b.tooltip_text = "One physical face is sampled uniformly. Repeated values increase their probability."
	for die in inventory_hero.get("reserve_dice", []):
		var row := _hbox(box)
		_label(row, _die_name(die) + "  |  " + _faces_text(die), 14, BLUE, true)
		_button(row, "Swap into selected slot", func(): _inventory_command("SwapDie", {"active_id": selected_active_die, "reserve_id": die.id})).disabled = locked or selected_active_die.is_empty()
		if snapshot.get("room", {}).get("kind") == "shop" and snapshot.get("phase") == "support":
			var price := int(Catalog.DICE.get(die.get("key", die.get("shape", "D6")), {}).get("price", 6)) / 2
			_button(row, "Sell · %d gold" % price, func(): _inventory_command("SellDie", {"die_id": die.id})).disabled = locked
	_label(box, "RELICS", 12, GOLD)
	if inventory_hero.get("relics", []).is_empty(): _label(box, "Elite and boss victories offer personal relic choices.", 13, MUTED)
	var equipped_relics: Array = []
	for relic in inventory_hero.get("relics", []):
		if relic.get("equipped", false): equipped_relics.append(relic)
	for relic in inventory_hero.get("relics", []):
		var def: Dictionary = Catalog.RELICS.get(relic.get("key", ""), {})
		var card := _panel(box)
		_label(card, str(def.get("name", relic.get("key", ""))) + ("  ·  EQUIPPED" if relic.get("equipped", false) else "  ·  RESERVE"), 17, GOLD)
		_label(card, str(def.get("description", "")), 13, MUTED, true)
		_button(card, "Unequip relic" if relic.get("equipped", false) else "Equip relic", func(): _inventory_command("EquipRelic", {"relic_id": relic.id})).disabled = locked or (not relic.get("equipped", false) and equipped_relics.size() >= 3)
		if not relic.get("equipped", false) and equipped_relics.size() >= 3:
			for active in equipped_relics:
				_button(card, "Replace " + str(Catalog.RELICS.get(active.get("key"), {}).get("name", active.get("key"))), func(): _inventory_command("EquipRelic", {"relic_id": relic.id, "replace_id": active.id})).disabled = locked

func _reorder(gems: Array, index: int, direction: int) -> void:
	var ids: Array = []
	for gem in gems: ids.append(gem.id)
	var swap = ids[index]
	ids[index] = ids[index + direction]
	ids[index + direction] = swap
	_inventory_command("ReorderGems", {"gem_ids": ids})

func _inventory_command(kind: String, payload: Dictionary) -> void:
	if str(snapshot.get("phase", "")) == "planning" and int(_hero().get("hp", 0)) <= 0:
		_plan_equipment(kind, payload)
	else:
		_command(kind, payload)
	_show_inventory.call_deferred()

func _inspect_gem(gem: Dictionary) -> void:
	var box := _modal(_gem_name(gem))
	_label(box, _gem_stats(gem), 16, GOLD)
	_label(box, _preview_text(gem), 16, PAPER, true)
	var preview: Dictionary = Combat.preview(_hero(), gem, _preview_hand(), snapshot)
	var contributors: Array = preview.get("contributing_dice", [])
	var indices: Array = []
	for i in range(_hero().get("dice", []).size()):
		if str(_hero().dice[i].id) in contributors: indices.append(str(i + 1))
	if not indices.is_empty(): _label(box, "Contributing die slots: " + ", ".join(indices), 14, GREEN)
	_label(box, "Target: " + str(Catalog.SKILLS.get(gem.get("key", ""), {}).get("target", "self")) + "\nPreferred enemy: " + _unit_name(str(_hero().get("preferred_target", ""))) + "\nPreferred ally: " + _unit_name(str(_hero().get("friendly_target", _hero().get("id", "")))), 14, BLUE, true)
	_label(box, "Dice are never consumed. Each equipped gem evaluates independently in visible order. Amounts are floored once; healing uses the recipient’s maximum HP.", 13, MUTED, true)
	_button(box, "Ping this gem", func(): _ping("gem", str(gem.get("id", "")), _gem_name(gem)))

func _inspect_unit(unit: Dictionary) -> void:
	var box := _modal(str(unit.get("name", "Unit")))
	_label(box, "%d / %d HP · %d block · %s" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0)), int(unit.get("block", 0)), _status_text(unit)], 15, GOLD, true)
	var def: Dictionary = Catalog.ENEMIES.get(unit.get("key", ""), {})
	_label(box, str(def.get("description", "")), 16, PAPER, true)
	for intent in unit.get("intents", []):
		_label(box, str(intent.get("name", "")) + " → " + _intent_target(unit, intent), 17, RED, true)
		_label(box, str(intent.get("summary", "")), 15, MUTED, true)
	for die in unit.get("dice", []):
		_label(box, _die_name(die) + ": " + _faces_text(die), 13, BLUE, true)
	if unit.get("boss", false):
		_label(box, "Boss Resolve: external stun queues at most one skipped slot. After that skip, the next two slots reject external stun. Damage still applies. Poison ticks once at each living actor’s slot end.", 14, GOLD, true)
	_button(box, "Ping this enemy", func(): _ping("enemy", str(unit.get("id", "")), str(unit.get("name", "Enemy"))))

func _ping(_kind: String, id: String, title: String) -> void:
	if session.has_method("send_ping") and not offline_hotseat:
		session.send_ping(id, title)
	_notify("Ping: " + title)

func _preview_text(gem: Dictionary) -> String:
	var def: Dictionary = Catalog.SKILLS.get(gem.get("key", ""), {})
	var result := "Trigger: " + str(def.get("trigger", "")) + "\n" + str(def.get("formula", ""))
	if not snapshot.is_empty():
		var preview: Dictionary = Combat.preview(_hero(), gem, _preview_hand(), snapshot)
		result += "\n\nThis hand: " + (str(preview.get("summary", "")) if preview.get("active", false) else str(preview.get("reason", "Dormant")))
		if int(preview.get("effective_clarity", gem.get("clarity", 1))) != int(gem.get("clarity", 1)):
			result += "\nEffective Clarity: %d (includes Focusing Prism)" % int(preview.effective_clarity)
	return result

func _gem_details(parent: Node, gem: Dictionary) -> void:
	var box := _vbox(parent, 5)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(box, _gem_name(gem), 18, PAPER)
	_label(box, _gem_stats(gem), 12, GOLD)
	var def: Dictionary = Catalog.SKILLS.get(gem.get("key", ""), {})
	_label(box, str(def.get("trigger", "")), 13, GREEN, true)
	_label(box, str(def.get("formula", "")), 12, MUTED, true)
	box.tooltip_text = _preview_text(gem)

func _gem_name(gem: Dictionary) -> String:
	return str(Catalog.SKILLS.get(gem.get("key", ""), {}).get("name", gem.get("key", "Gem")))

func _gem_stats(gem: Dictionary) -> String:
	return "CARAT %d  ·  CUT %d  ·  CLARITY %d" % [int(gem.get("carat", 1)), int(gem.get("cut", 1)), int(gem.get("clarity", 1))]

func _die_name(die: Dictionary) -> String:
	return str(Catalog.DICE.get(die.get("key", die.get("shape", "D6")), {}).get("name", die.get("shape", "Die")))

func _faces_text(die: Dictionary) -> String:
	var values: Array = []
	for face in die.get("faces", []):
		values.append(str(face.get("value", 0) if face is Dictionary else face))
	return ", ".join(values)

func _unit_name(id: String) -> String:
	for unit in snapshot.get("heroes", []) + snapshot.get("enemies", []):
		if str(unit.get("id", "")) == id: return str(unit.get("player_name", unit.get("name", id)))
	return "First valid target" if id.is_empty() else id

func _status_text(unit: Dictionary) -> String:
	var parts: Array = []
	var statuses: Dictionary = unit.get("statuses", {})
	for key in ["stun", "poison", "resolve"]:
		if int(statuses.get(key, 0)) > 0: parts.append("%s %d" % [key.to_upper(), int(statuses[key])])
	return " · ".join(parts)

func _log_text(entry: Variant) -> String:
	if entry is String: return entry
	if not entry is Dictionary: return str(entry)
	var result := str(entry.get("message", entry.get("text", "")))
	if result.is_empty():
		result = "%s · %s → %s" % [_unit_name(str(entry.get("actor_id", ""))), str(entry.get("skill", entry.get("kind", entry.get("type", "event")))), _unit_name(str(entry.get("target_id", "")))]
	var details: Array = []
	for key in ["raw", "absorbed", "hp_loss", "healing", "applied", "removed"]:
		if entry.has(key): details.append("%s %s" % [key.replace("_", " "), str(entry[key])])
	if not details.is_empty(): result += "  [" + "; ".join(details) + "]"
	return result

func _show_log() -> void:
	var box := _modal("The combat record")
	_label(box, "Authority events in execution order. Animation controls change only presentation.", 13, MUTED, true)
	for entry in snapshot.get("log", []):
		_label(box, _log_text(entry), 13, PAPER, true)

func _show_journal() -> void:
	var box := _modal("The expedition journal")
	var tabs := _hbox(box)
	for tab in ["guide", "heroes", "gems", "dice", "relics", "enemies", "history"]:
		var b := _button(tabs, tab.capitalize(), func(): journal_tab = tab; _show_journal())
		b.toggle_mode = true
		b.button_pressed = journal_tab == tab
	match journal_tab:
		"guide":
			var entries := [
				["ONE HAND, MANY SKILLS", "Roll five active dice. Select dice you want to reroll; the others stay. You normally have one reroll. Lock in when you are satisfied. There is no automatic lock-in timer."],
				["A PAIR CAN DO MORE", "With [2, 2, 4, 6, 8], Strike C1/K1/L1 deals 9 damage and Block C2/K1/L1 grants 4 block. Both use the same hand; dice are neither assigned nor spent."],
				["YOUR BUILD", "Equip six unique skill gems including Strike. Carat (C), Cut (K), and Clarity (L) vary independently. M(L) is 1 / 1.25 / 1.5 / 1.75 / 2. Equip, replace, and reorder between rooms before ready. Skills resolve in their visible order."],
				["TARGETS AND TURN ORDER", "Choose a preferred enemy and friendly target. A skill fixes its target as it begins; later hostile hits fizzle if that target dies. The next skill can retarget. Heroes act in party seat order, then enemies. Enemy intents are public before planning."],
				["BLOCK, STUN, POISON", "Block persists through turns, then clears after combat. Stun skips an actor’s next slot. Poison bypasses block at the end of a living actor’s slot, then loses one stack; it still ticks when stunned. Boss Resolve prevents repeated stun locking."],
				["FALLING AND RECOVERY", "Downed heroes do not roll or act. Victory rallies them to 10% HP; a party wipe ends the run. Lifeline can revive during a fight, but the revived hero acts next turn. Rest heals one third of maximum HP."],
				["THE LONG FIGHT", "Enrage starts on turn 7: enemies add +2 raw damage per hit, then +2 more each turn. Combat skill/relic gold is capped at 8 / 12 / 16 per hero in acts 1 / 2 / 3. Room rewards are separate."],
				["ROOMS AND LOOT", "Routes use party votes; ties follow the host. Shops have personal stock. Workshop modifies one die; Lapidary improves one gem. Mining uses fixed energy and shared gold, then a rotating gem draft. Choose one event transaction or leave."],
				["CONTROLS", "Click dice or press 1–5. R rerolls, Space readies, Tab cycles enemy targets, I inspects equipment, Escape closes a panel. Controller focus uses the directional pad, accept, and back. Remap actions in Settings."]
			]
			for entry in entries:
				_label(box, entry[0], 14, GOLD)
				_label(box, entry[1], 15, PAPER, true)
		"heroes":
			for key in Catalog.HEROES:
				var def: Dictionary = Catalog.HEROES[key]
				_label(box, "%s · %d HP · %s" % [def.name, def.max_hp, _join_values(def.dice)], 20, GOLD)
				_label(box, str(def.trait_name) + ": " + str(def.description), 15, PAPER, true)
		"gems":
			for key in Catalog.SKILLS:
				var def: Dictionary = Catalog.SKILLS[key]
				_label(box, "%s · Rarity %d" % [def.name, def.rarity], 19, GOLD)
				_label(box, str(def.trigger) + "\n" + str(def.formula), 15, PAPER, true)
		"dice":
			for key in Catalog.DICE:
				var def: Dictionary = Catalog.DICE[key]
				_label(box, "%s · %d gold" % [def.name, def.price], 18, BLUE)
				_label(box, "Faces: " + _join_values(def.faces), 15, PAPER, true)
		"relics":
			for key in Catalog.RELICS:
				var def: Dictionary = Catalog.RELICS[key]
				_label(box, str(def.name), 19, GOLD)
				_label(box, str(def.description), 15, PAPER, true)
		"enemies":
			for key in Catalog.ENEMIES:
				var def: Dictionary = Catalog.ENEMIES[key]
				_label(box, str(def.name), 19, RED)
				_label(box, str(def.get("description", "")), 15, PAPER, true)
		"history":
			var records: Array = engine.save_store.load_history()
			if records.is_empty(): _label(box, "Completed expeditions will be recorded here.", 16, MUTED)
			for record in records:
				_label(box, "%s · %s · seed %s" % [str(record.get("outcome", "Expedition")), str(record.get("profile", "")), str(record.get("seed", ""))], 17, GOLD)
				_label(box, str(record.get("completed_at", record.get("saved_at", ""))), 13, MUTED)

func _show_settings() -> void:
	var pending_binding := rebind_action
	var box := _modal("Settings & accessibility")
	rebind_action = pending_binding
	_label(box, "DISPLAY AND PLAYBACK", 12, GOLD)
	var scale_row := _hbox(box)
	_label(scale_row, "Text scale", 15, PAPER)
	var scale := OptionButton.new()
	for text in ["90%", "100%", "110%", "125%", "140%"]: scale.add_item(text)
	var scales := [0.9, 1.0, 1.1, 1.25, 1.4]
	scale.selected = scales.find(float(settings.text_scale))
	scale.item_selected.connect(func(index: int): settings.text_scale = scales[index]; _save_settings(); _apply_theme(); _queue_render(); _show_settings.call_deferred())
	scale_row.add_child(scale)
	var motion := CheckButton.new()
	motion.text = "Reduced motion"
	motion.button_pressed = settings.reduced_motion
	motion.toggled.connect(func(value: bool): settings.reduced_motion = value; _save_settings())
	box.add_child(motion)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Full screen"
	fullscreen.button_pressed = settings.fullscreen
	fullscreen.toggled.connect(func(value: bool): settings.fullscreen = value; DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED); _save_settings())
	box.add_child(fullscreen)
	var speed_row := _hbox(box)
	_label(speed_row, "Playback speed", 15, PAPER)
	var speed := OptionButton.new()
	for text in ["0.5×", "1×", "2×", "4×", "Instant"]: speed.add_item(text)
	var speeds := [0.5, 1.0, 2.0, 4.0, 100.0]
	speed.selected = speeds.find(float(settings.playback_speed))
	speed.item_selected.connect(func(index: int): settings.playback_speed = speeds[index]; _save_settings())
	speed_row.add_child(speed)
	var volume_row := _hbox(box)
	_label(volume_row, "Sound volume", 15, PAPER)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = float(settings.sound_volume)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value_changed.connect(func(value: float): settings.sound_volume = value; _save_settings())
	volume_row.add_child(volume)
	_label(box, "REMAPPABLE ACTIONS", 12, GOLD)
	_label(box, "Select an action, then press a keyboard key or controller button. Escape cancels a binding.", 13, MUTED, true)
	for action in ACTION_DEFAULTS:
		var row := _hbox(box)
		_label(row, str(action).trim_prefix("rd_").replace("_", " ").capitalize(), 15, PAPER)
		_spacer(row)
		_button(row, "Press a key / button…" if rebind_action == action else _binding_name(action), func(): rebind_action = action; _show_settings())
	_button(box, "Restore default bindings", func(): settings.bindings = {}; _install_input(); _save_settings(); _show_settings())
	_label(box, "Die selection also uses keys 1–5. Status names and keep/reroll labels remain visible independently of color.", 13, MUTED, true)

func _install_input() -> void:
	for action in ACTION_DEFAULTS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var binding: Dictionary = settings.get("bindings", {}).get(action, {})
		if binding.get("type", "key") == "joy":
			var joy := InputEventJoypadButton.new()
			joy.button_index = int(binding.get("button", JOY_BUTTON_A))
			InputMap.action_add_event(action, joy)
		else:
			var key := InputEventKey.new()
			key.physical_keycode = int(binding.get("key", ACTION_DEFAULTS[action]))
			InputMap.action_add_event(action, key)
	var gamepad_defaults := {"rd_reroll": JOY_BUTTON_X, "rd_ready": JOY_BUTTON_Y, "rd_inspect": JOY_BUTTON_BACK, "rd_back": JOY_BUTTON_B, "rd_target": JOY_BUTTON_RIGHT_SHOULDER, "rd_skip": JOY_BUTTON_START}
	for action in gamepad_defaults:
		if settings.get("bindings", {}).has(action): continue
		var joy := InputEventJoypadButton.new()
		joy.button_index = gamepad_defaults[action]
		InputMap.action_add_event(action, joy)

func _binding_name(action: String) -> String:
	var bindings := InputMap.action_get_events(action)
	if bindings.is_empty(): return "Unbound"
	return bindings[0].as_text().replace(" (Physical)", "").replace(" - Physical", "")

func _input(event: InputEvent) -> void:
	if not rebind_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode != KEY_ESCAPE: settings.bindings[rebind_action] = {"type": "key", "key": event.physical_keycode}
			rebind_action = ""
			_install_input()
			_save_settings()
			_show_settings()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			settings.bindings[rebind_action] = {"type": "joy", "button": event.button_index}
			rebind_action = ""
			_install_input()
			_save_settings()
			_show_settings()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("rd_back"):
		if is_instance_valid(overlay): _close_overlay()
		else: _show_settings()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(overlay) or snapshot.is_empty(): return
	if event.is_action_pressed("rd_inspect"):
		_show_inventory()
	elif event.is_action_pressed("rd_skip"):
		_skip_playback()
	elif event.is_action_pressed("rd_ready"):
		_command("SetReady", {"ready": not _hero().get("ready", false)})
	elif snapshot.get("phase") == "planning":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			var i := int(event.physical_keycode - KEY_1)
			if i < _hero().get("dice", []).size(): _toggle_die(str(_hero().dice[i].id))
		elif event.is_action_pressed("rd_reroll"): _reroll()
		elif event.is_action_pressed("rd_target"): _cycle_target()
		elif event.is_action_pressed("rd_toggle_die"):
			var focused := get_viewport().gui_get_focus_owner()
			if is_instance_valid(focused) and str(focused.get_meta("focus_tag", "")).begins_with("die_"):
				var index := int(str(focused.get_meta("focus_tag")).trim_prefix("die_"))
				_toggle_die(str(_hero().dice[index].id))
		else: return
	else: return
	get_viewport().set_input_as_handled()

func _cycle_target() -> void:
	var candidates: Array = []
	for enemy in snapshot.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: candidates.append(str(enemy.id))
	if candidates.is_empty(): return
	var current := candidates.find(str(_hero().get("preferred_target", "")))
	_command("SetPreferredTarget", {"unit_id": candidates[(current + 1) % candidates.size()]})

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://interface.cfg") == OK:
		for key in settings.keys(): settings[key] = cfg.get_value("ui", key, settings[key])
	if settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings: cfg.set_value("ui", key, settings[key])
	cfg.save("user://interface.cfg")

func _skip_playback() -> void:
	playback_index = playback_events.size()
	mine_playback_index = snapshot.get("mine", {}).get("events", []).size()
	_notify("Playback skipped. The authoritative outcome is unchanged.")

func _return_menu() -> void:
	_close_overlay()
	session.leave()
	snapshot = {}
	controlled_id = ""
	selected_dice.clear()
	menu_page = "home"
	_queue_render()

func _show_recovery(_state: Dictionary) -> void:
	var box := _modal("The host has departed")
	_label(box, "Progress has stopped. Your party snapshot is preserved for inspection. The original host must reopen the canonical checkpoint and invite the party to resume.", 16, MUTED, true)
	_label(box, "There is no automatic host promotion. Reconnect to the original host when their lobby is available.", 14, GOLD, true)
	_button(box, "Reconnect", func(): session.reconnect())
	_button(box, "Return to table", _return_menu)

func _accept_steam_invite(lobby_id: String) -> void:
	var id := lobby_id.strip_edges()
	if not id.is_valid_int() or int(id) <= 0:
		_notify("The Steam invitation does not contain a valid lobby ID.")
		return
	if snapshot.is_empty():
		_join_invited_lobby(id)
		return
	var box := _modal("Steam party invitation")
	_label(box, "Join Steam lobby %s?" % id, 18, GOLD, true)
	_label(box, "You currently have an active expedition. Joining leaves this party. Your last committed checkpoint remains available to resume.", 16, PAPER, true)
	if session.is_host and not offline_hotseat:
		_label(box, "You are hosting. The current party will pause until you reopen its checkpoint.", 14, MUTED, true)
	var row := _hbox(box)
	_button(row, "Stay in this run", _close_overlay, true)
	_button(row, "Leave saved run & join invitation", func(): _join_invited_lobby(id))

func _join_invited_lobby(lobby_id: String) -> void:
	_close_overlay()
	session.leave()
	snapshot = {}
	controlled_id = ""
	selected_dice.clear()
	offline_hotseat = false
	steam_lobby_text = lobby_id
	menu_page = "lobby"
	var result: Dictionary = session.join_steam(lobby_id, player_name)
	if not result.get("ok", false):
		_notify(str(result.get("error", "The Steam lobby could not be joined.")))
	_queue_render()

func _resume_network() -> void:
	var loaded: Dictionary = engine.save_store.load_checkpoint()
	if not loaded.get("ok", false):
		_notify(str(loaded.get("error", "No saved checkpoint is available.")))
		return
	var result: Dictionary = session.restore_party(loaded.state)
	if not result.get("ok", false):
		_notify(str(result.get("error", "Only the original host can resume this party.")))
		return
	offline_hotseat = false
	controlled_id = str(session.local_player_id)
	result = engine.restore(loaded.state, loaded.get("command_history", {}), str(session.session_id))
	if not result.get("ok", false):
		_notify(str(result.get("error", "Checkpoint could not be restored.")))
		return
	session.host_epoch = int(engine.state.get("host_epoch", 1))
	session.broadcast_snapshot(engine.state)

func _show_fallback(id: String) -> void:
	var box := _modal("A hero is disconnected")
	_label(box, _unit_name(id) + " can reconnect to their existing seat. Planning pauses for a 60-second recovery window.", 16, MUTED, true)
	_label(box, "After that window, the host may enable the declared fallback: keep the existing hand, use deterministic reward choices, and continue without changing encounter difficulty.", 14, GOLD, true)
	_button(box, "Resume with fallback", func():
		var host := str(snapshot.get("host_id", controlled_id))
		var result: Dictionary = engine.execute(host, engine.make_envelope(host, "ResumeDisconnected", {"player_id": id}))
		if not result.get("ok", false): _notify(str(result.get("error", "Recovery window is still active.")))
		else:
			session.resume_disconnected(id)
			_close_overlay(), true)
	_button(box, "Keep waiting", _close_overlay)

func _modal(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", _style(Color(0.025, 0.04, 0.055, 0.96), Color(0, 0, 0, 0), 0, 24))
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 55)
	margin.add_theme_constant_override("margin_right", 55)
	overlay.add_child(margin)
	var outer := _vbox(margin, 14)
	var top := _hbox(outer)
	_label(top, title, 28, GOLD)
	_spacer(top)
	_button(top, "Close  [Esc]", _close_overlay)
	var scroll := _scroll(outer)
	var box := _vbox(scroll, 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box

func _close_overlay() -> void:
	rebind_action = ""
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null

func _notify(message: String) -> void:
	if not is_inside_tree(): return
	if is_instance_valid(toast): toast.queue_free()
	toast = Label.new()
	toast.text = message
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", GOLD)
	toast.add_theme_stylebox_override("normal", _style(Color("26333e"), GOLD, 8, 14))
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 90
	toast.offset_right = -90
	toast.offset_top = -90
	toast.offset_bottom = -40
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	var current := toast
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(current): current.queue_free())

func _panel(parent: Node, color: Color = PANEL, border: Color = LINE, padding: int = 16) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, border, 9, padding))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := _vbox(panel, 9)
	return box

func _vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _hbox(parent: Node, separation: int = 10) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _label(parent: Node, text: String, size_px: int = 16, color: Color = PAPER, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(size_px * float(settings.text_scale)))
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): _play_sound(click_sound); callback.call())
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("494135"), Color("967b50"), 7, 12))
		button.add_theme_color_override("font_color", Color("f1d3a1"))
	parent.add_child(button)
	return button

func _scroll(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	return scroll

func _spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _join_values(values: Array) -> String:
	var strings: Array = []
	for value in values: strings.append(str(value))
	return ", ".join(strings)

func _preview_hand() -> Array:
	var current: Array = _hero().get("hand", [])
	return current if not current.is_empty() else last_hands.get(controlled_id, [])

func _hand_values(hand: Array) -> String:
	var values: Array = []
	for face in hand: values.append(str(face.get("value", 0)))
	return "[" + ", ".join(values) + "]" if not values.is_empty() else "No combat hand yet"

func _play_sound(stream: AudioStreamWAV) -> void:
	if not is_instance_valid(sound_player) or stream == null or float(settings.sound_volume) <= 0.0: return
	sound_player.stream = stream
	sound_player.volume_db = linear_to_db(float(settings.sound_volume))
	sound_player.play()

func _highlight_dice(ids: Array) -> void:
	for id in die_buttons:
		var button: Button = die_buttons[id]
		if not is_instance_valid(button): continue
		button.modulate = Color("fff0b9") if id in ids else Color.WHITE
		if id in ids: button.add_theme_stylebox_override("normal", _style(Color("393c32"), GOLD, 8, 10, 2))
		elif not id in selected_dice: button.remove_theme_stylebox_override("normal")

func _plan_equipment(kind: String, payload: Dictionary) -> void:
	var hero: Dictionary = provisional.get(controlled_id, {})
	if hero.is_empty(): return
	match kind:
		"EquipGem", "EquipRelic":
			var is_gem := kind == "EquipGem"
			var items: Array = hero.get("gems" if is_gem else "relics", [])
			var id := str(payload.get("gem_id" if is_gem else "relic_id", ""))
			var found: Dictionary = {}
			for item in items:
				if str(item.id) == id: found = item
			if found.is_empty(): return
			for item in items:
				if str(item.id) == str(payload.get("replace_id", "")): item.equipped = false
			found.equipped = not found.get("equipped", false)
		"ReorderGems":
			var ordered: Array = []
			for id in payload.get("gem_ids", []):
				for item in hero.gems:
					if item.id == id: ordered.append(item)
			for item in hero.gems:
				if not item.get("equipped", false): ordered.append(item)
			hero.gems = ordered
		"SwapDie":
			var active_i := -1
			var reserve_i := -1
			for i in hero.dice.size():
				if hero.dice[i].id == payload.get("active_id"): active_i = i
			for i in hero.reserve_dice.size():
				if hero.reserve_dice[i].id == payload.get("reserve_id"): reserve_i = i
			if active_i < 0 or reserve_i < 0: return
			var prior: Dictionary = hero.dice[active_i]
			hero.dice[active_i] = hero.reserve_dice[reserve_i]
			hero.reserve_dice[reserve_i] = prior
		_: return
	provisional_commands[controlled_id].append({"type": kind, "payload": payload.duplicate(true)})

func _commit_provisional() -> void:
	if str(snapshot.get("phase", "")) == "planning" or _hero().get("ready", false): return
	var commands: Array = provisional_commands.get(controlled_id, [])
	for command in commands:
		_command(str(command.type), command.payload)
	provisional.erase(controlled_id)
	provisional_commands.erase(controlled_id)
	_show_inventory.call_deferred()

func _show_forecast() -> void:
	if snapshot.get("phase") != "planning": return
	var forecast: Dictionary = Combat.forecast_turn(snapshot)
	var box := _modal("If everyone locks these hands")
	_label(box, "A forecast using the current targets, gem order, and published enemy intents. Teammates may still change their plans. This preview does not roll dice or change the run.", 14, MUTED, true)
	for hero in forecast.get("state", {}).get("heroes", []):
		_label(box, "%s → %d HP · %d block · %s" % [str(hero.get("player_name", hero.get("name", "Hero"))), int(hero.get("hp", 0)), int(hero.get("block", 0)), _status_text(hero)], 16, GREEN, true)
	for entry in forecast.get("events", []):
		_label(box, _log_text(entry), 13, PAPER, true)
