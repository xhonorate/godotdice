extends Control
## The workshop: four tabs in one frame, and a screen of its own for coming home.
##
## Descend (the mines under the workshop, who goes down and the way down, or the day's seam),
## Delvers (each delver's dossier and their sockets), Vault (the collection, and anything
## waiting on the tray) and Market (Geodes, cut stones, the bench and the commissions). The
## profile chip opens the profile page (records, runs and the showcase); the party sits in the
## top bar. Back from a run with stones on the tray, the tabs give way to the coming-home
## screen until every stone has been read and kept, sold or turned in.
##
## Every page is built by its own script (descend_page, delvers_page, vault_page, market_page,
## profile_page, homecoming), which reads and writes the state kept here. Pages are rebuilt
## whenever the profile or the lobby changes; stones and dice are photographs, so that is
## cheap, and only the one stone a page is about is live 3D. A page only animates in when it
## is opened, never on a rebuild.
##
## Every page fits the screen whole: nothing scrolls but the vault. A tab opens at its start
## page; its sort, filters and view are kept.

const HomeParts = preload("res://view/home/home_parts.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Backdrop = preload("res://view/run/backdrop.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Roster = preload("res://view/home/roster.gd")
const PartyDock = preload("res://view/home/party_dock.gd")
const DescendPage = preload("res://view/home/descend_page.gd")
const DelversPage = preload("res://view/home/delvers_page.gd")
const VaultPage = preload("res://view/home/vault_page.gd")
const MarketPage = preload("res://view/home/market_page.gd")
const ProfilePage = preload("res://view/home/profile_page.gd")
const Homecoming = preload("res://view/home/homecoming.gd")
const Inspector = preload("res://view/inspect/inspector.gd")

signal depart_requested(seed: int)
signal member_changed(fields: Dictionary)
signal mine_chosen(mine: String)
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal steam_host_requested
signal steam_join_requested(lobby_id: String)
signal invite_requested
signal kick_requested(player_id: String)
signal leave_party_requested
signal profile_changed
## Something small changed (a stone looked at, the Market seen): save it, but do not rebuild.
signal profile_touched
signal menu_requested
signal player_name_requested
signal daily_chosen(date: String)

## The tabs, in order: key, word, mark. The number keys open them.
const TABS: Array = [["descend", "Descend", "descend"], ["delvers", "Delvers", "person"], ["vault", "Vault", "chest"], ["market", "Market", "geode"]]
const color_ORDER: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE", "OPAL"]
## The word on a socket the delver has not opened, so the loadout does not fill it.
const MINE_SOCKET: String = "Locked. Buy it with gold to fill it from the vault before every run. Until then it is filled in the mine: below the Quarry with a temporary stone, and anywhere with a stone found on the way down."
## What the lock on a delver's dice says: they are never swapped.
const OWN_DICE: String = "Every delver goes down with their own five dice. Dice are worked in the mine, at a smithy or a carver, never swapped."
## Pip tones: something new to look at, something to act on, something ready to collect.
const PIP_NEW := Color("7fe0ff")
const PIP_ACT := Color("ffb04a")
const PIP_READY := Color("6fe3b0")
## What the session's state means to a player, and the tone it is said in.
const STATUS_WORDS: Dictionary = {"local": ["Playing alone: host or join to play together", DeepUi.MUTED],
	"offline": ["Playing alone: host or join to play together", DeepUi.MUTED], "opening": ["Opening a Steam lobby…", DeepUi.ACCENT],
	"hosting": ["Hosting: friends can join", DeepUi.GOOD], "connecting": ["Connecting to the host…", DeepUi.ACCENT],
	"joined": ["In the party", DeepUi.GOOD], "lost": ["Disconnected", DeepUi.BAD]}

var profile: Dictionary = {}
var lobby: Dictionary = {}
var status: String = "local"
var is_host: bool = true
var local_id: String = "p0"
var can_start: bool = true
var settings: Dictionary = {}
## The Steam lobby's ID while hosting over Steam.
var invite_code: String = ""
var tab: String = "descend"
var _bar: HBoxContainer
var _body: Control
var _overlay: Control
var _backdrop: Control
var _fresh: bool = true
var _shown_tab: String = ""
var _headless: bool = false
var _gold_seen: int = -1
var _cheer: Dictionary = {}
## The pages pass state through here. Delvers: who is looked at, which view, which socket.
var _roster_pick: String = ""
var _roster_view: String = "dossier"
var _bench_socket: int = -1
## Vault: the stone under the lamp and whether the collection or the tray is shown.
var _vault_pick: String = ""
var _vault_view: String = "collection"
var _vault_stage: Control = null
## The stone browser's settings, one set per place it is used (vault, sockets, bench).
var browse: Dictionary = {}
## The tray stone being looked at, at home or in the vault's Unappraised view.
var _appraise_pick: String = ""
## Market: the page shown (main, wheel, oven, contract), and what is on each bench.
var _market_view: String = "main"
var _rework_pick: String = ""
var _contract: Array = []
var _contract_from: String = "all"
var _contract_sure: bool = false
var _odds_open: String = ""
var _commission_sure: String = ""
## The party popover, and whose showcase is open in it.
var _party_open: bool = false
var _showcase_of: String = ""
var _address: LineEdit
var _lobby_field: LineEdit
var _seed: LineEdit
## The page each long list is turned to, by list.
var _pages: Dictionary = {}
## Every drop target on the loadout, so a drag can light the ones that would take it.
var _targets: Array = []

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
	var style := DeepUi.flat(Color(DeepUi.INK, 0.97), Color(0, 0, 0, 0), 0, 10)
	style.border_width_bottom = 1
	style.border_color = Color(DeepUi.ACCENT_DIM, 0.6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	head.add_theme_stylebox_override("panel", style)
	column.add_child(head)
	_bar = DeepUi.hbox(head, 10)
	_bar.custom_minimum_size.y = 46
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)
	## Popovers (the party, a showcase, a Geode's odds) sit over everything on this layer.
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 30
	add_child(_overlay)
	## The build, faint in the corner, inside the body's margin so it never sits on a page.
	## tools/release/deploy.ps1 stamps it into the project settings on every release.
	var version := DeepUi.label(self, "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0")), 11, Color(DeepUi.MUTED, 0.45))
	version.name = "Version"
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _notification(what: int) -> void:
	## While a stone is being dragged, the places it could go are lit and the rest dim.
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		for target in _targets:
			if not is_instance_valid(target.node):
				continue
			var takes: bool = data is Dictionary and bool(target.accepts.call(data))
			target.node.modulate = Color.WHITE if takes else Color(1, 1, 1, 0.4)
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(takes)
	elif what == NOTIFICATION_DRAG_END:
		for target in _targets:
			if is_instance_valid(target.node):
				target.node.modulate = Color.WHITE
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(false)

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

func open(tab_name: String, keep_view: bool = false) -> void:
	## Opens a tab at its start page, unless the caller has just set the page it wants.
	## Older names are still understood (the map, the roster, the shop, the ledger).
	tab_name = {"map": "descend", "roster": "delvers", "lapidaries": "delvers", "shop": "market", "commissions": "market", "ledger": "profile", "appraise": "vault"}.get(tab_name, tab_name)
	if tab_name != tab and not keep_view:
		_reset_views(tab_name)
	if tab_name == "vault" and not keep_view and not profile.get("tray", []).is_empty() and not homecoming():
		_vault_view = "unappraised"
	tab = tab_name
	_party_open = false
	_showcase_of = ""
	_odds_open = ""
	_render()

func _reset_views(tab_name: String) -> void:
	match tab_name:
		"delvers":
			_roster_view = "dossier"
			_roster_pick = ""
			_bench_socket = -1
		"vault":
			_vault_view = "collection"
		"market":
			_market_view = "main"
			_rework_pick = ""
			_contract_sure = false
			_commission_sure = ""

func homecoming() -> bool:
	## Back from a run with stones on the tray: the coming-home screen holds the workshop
	## until every one of them is decided.
	return bool(profile.get("homecoming", false))

# --- the frame ---------------------------------------------------------------------------------

func _render() -> void:
	_fresh = tab != _shown_tab
	_shown_tab = tab
	DeepUi.clear(_bar)
	DeepUi.clear(_overlay)
	var coming_home: bool = homecoming()
	var brand := DeepUi.hbox(_bar, 8)
	DeepUi.icon(brand, "gem", 24, DeepUi.ACCENT)
	DeepUi.title(brand, "DEEP CUT", 22, DeepUi.ACCENT_HI)
	DeepUi.gap(_bar, 10)
	_purse()
	DeepUi.spacer(_bar)
	if coming_home:
		Homecoming.bar(self, _bar)
	else:
		_tabs()
	DeepUi.spacer(_bar)
	PartyDock.dock(self, _bar)
	_profile_chip()
	DeepUi.gear_button(_bar, func() -> void: menu_requested.emit())
	DeepUi.clear(_body)
	_targets = []
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_body.add_child(margin)
	var content := DeepUi.vbox(margin, 14)
	if coming_home:
		Homecoming.build(self, content)
	else:
		match tab:
			"descend": DescendPage.build(self, content)
			"delvers": DelversPage.build(self, content)
			"vault": VaultPage.build(self, content)
			"market": MarketPage.build(self, content)
			"profile": ProfilePage.build(self, content)
	if _party_open:
		PartyDock.popover(self, _overlay)

func _purse() -> void:
	var gold: int = int(profile.get("gold", 0))
	var purse := DeepUi.pill(_bar, "coin", "%d" % gold, DeepUi.ACCENT, 14,
		"Gold: from selling stones, commissions, the assayer at the lift and first conquests. It pays for the loupe, the way down to a deeper mine, insurance, sockets and the market.")
	purse.name = "Purse"
	if _gold_seen >= 0 and gold != _gold_seen and not _headless:
		## Gold coming in counts up, and the purse jingles.
		var value: Label = purse.get_child(0).get_node("Value")
		var from: int = _gold_seen
		value.text = "%d" % from
		DeepAudio.play("ore" if gold > from else "buy", {"delay": 0.15, "volume": 0.7})
		var tween := purse.create_tween()
		tween.tween_interval(0.15)
		tween.tween_method(func(v: float) -> void: value.text = "%d" % int(round(v)), float(from), float(gold), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		## Deferred so the purse has been laid out before the burst is placed on it.
		call_deferred("_cheer_purse", "%+d gold" % (gold - from))
	_gold_seen = gold

func _tabs() -> void:
	var row := DeepUi.hbox(_bar, 6)
	for index in range(TABS.size()):
		var entry: Array = TABS[index]
		var key: String = str(entry[0])
		var button := DeepUi.tab_button(row, str(entry[2]), str(entry[1]), key == tab, func() -> void: open(key), 15)
		button.name = "Tab_" + key
		button.tooltip_text = "%s (%d)" % [str(entry[1]), index + 1]
		var pip: Array = tab_pip(key)
		if not pip.is_empty():
			HomeParts.pin(button, int(pip[0]), pip[1], true)
		if key == "vault" and not _cheer.is_empty():
			call_deferred("_cheer_at", button, str(_cheer.text), _cheer.color, str(_cheer.get("glyph", "chest")))
			_cheer = {}

func tab_pip(key: String) -> Array:
	## What a tab's pip says, as [count, tone], or [] for none. A count is something to act
	## on; a count of nought with a tone is a dot for something new since the player looked.
	match key:
		"descend":
			if DeepEconomy.daily_state(profile) == "fresh" and str(lobby.get("daily", "")).is_empty():
				return [0, PIP_NEW]
		"delvers":
			for record in profile.get("characters", {}).values():
				if bool(record.get("fresh", false)):
					return [0, PIP_NEW]
		"vault":
			var waiting: int = profile.get("tray", []).size()
			if waiting > 0:
				return [waiting, PIP_ACT]
			var fresh: int = DeepProfile.fresh_count(profile)
			if fresh > 0:
				return [fresh, PIP_NEW]
		"market":
			var ready: int = DeepEconomy.ready_count(profile)
			if ready > 0:
				return [ready, PIP_READY]
			if not bool(profile.get("daily", {}).get("market_seen", false)):
				return [0, PIP_ACT]
	return []

func _profile_chip() -> void:
	## The player's own chip: their avatar and name. It opens the profile page, where the name
	## is changed, the records are kept and the showcase is shown.
	var player_name: String = str(profile.get("name", DeepProfile.DEFAULT_NAME))
	var chip := Button.new()
	chip.name = "PlayerName"
	chip.text = player_name
	chip.tooltip_text = "%s · Your profile, records and showcase" % player_name
	chip.clip_text = true
	chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.custom_minimum_size = Vector2(150, 40)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_constant_override("h_separation", 8)
	var rest := DeepUi.button_style(Color(0, 0, 0, 0), Color(DeepUi.LINE, 0.8), 6)
	rest.content_margin_left = 42
	chip.add_theme_stylebox_override("normal", rest)
	var lit := DeepUi.button_style(Color(DeepUi.ACCENT, 0.12), DeepUi.ACCENT if tab == "profile" else DeepUi.LINE_HI, 6)
	lit.content_margin_left = 42
	chip.add_theme_stylebox_override("hover", lit)
	if tab == "profile":
		chip.add_theme_stylebox_override("normal", lit)
	chip.pressed.connect(func() -> void:
		DeepAudio.play("ui_tab")
		open("profile"))
	_bar.add_child(chip)
	var face := HomeParts.Avatar.new(player_name, 30)
	face.position = Vector2(6, 5)
	chip.add_child(face)
	if int(profile.get("records", {}).get("best", {}).get("score", -1)) > int(profile.get("best_seen", -1)) and not profile.get("records", {}).get("best", {}).is_empty():
		HomeParts.pin(chip, 0, PIP_NEW, true)

func _unhandled_key_input(event: InputEvent) -> void:
	## 1 to 4 open the tabs, Q and E change who goes down, Enter sets out, and Escape steps
	## back out of a page inside a tab (the menu takes it when there is nowhere to step back).
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo or Inspector.is_open():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		if _step_back():
			get_viewport().set_input_as_handled()
		return
	if homecoming():
		return
	if key >= KEY_1 and key <= KEY_4:
		open(str(TABS[key - KEY_1][0]))
		get_viewport().set_input_as_handled()
	elif key in [KEY_Q, KEY_E] and tab in ["descend", "delvers"]:
		step_character(-1 if key == KEY_Q else 1)
		get_viewport().set_input_as_handled()
	elif key in [KEY_ENTER, KEY_KP_ENTER] and tab == "descend" and is_host and can_start and not bool(lobby.get("started", false)):
		DeepAudio.play("ui_confirm")
		depart_requested.emit(seed_value())
		get_viewport().set_input_as_handled()

func _step_back() -> bool:
	## One page back inside the tab that is open. False when there is nothing to step back to.
	if _party_open or not _odds_open.is_empty():
		_party_open = false
		_showcase_of = ""
		_odds_open = ""
		_render()
		return true
	if tab == "market" and _market_view != "main":
		_market_view = "main"
		_render()
		return true
	if tab == "delvers" and _roster_view != "dossier":
		_roster_view = "dossier"
		_bench_socket = -1
		_render()
		return true
	if tab == "profile":
		open("descend")
		return true
	return false

func seed_value() -> int:
	return int(_seed.text) if _seed != null and is_instance_valid(_seed) and _seed.text.is_valid_int() else 0

# --- hold Shift to compare -----------------------------------------------------------------------

## The stone under the pointer that Shift would compare, what it is weighed against, and its tile.
var _hover: Dictionary = {}
var _compare: Control = null

func hover_stone(node: Control, stone: Dictionary, against: Dictionary = {}) -> void:
	## A stone tile tells the shell the pointer is on it. Holding Shift then shows it line by
	## line against `against` (by default the stone of its skill already in the vault).
	if against.is_empty():
		against = DeepProfile.owned(profile, str(stone.get("skill", "")))
	if against.get("id", "") == stone.get("id", "x") and str(against.get("skill", "")) == str(stone.get("skill", "")):
		against = {}
	_hover = {"node": node, "stone": stone, "against": against}
	if Input.is_key_pressed(KEY_SHIFT):
		_show_compare()
	node.mouse_exited.connect(func() -> void:
		if not _hover.is_empty() and _hover.node == node:
			_hover = {}
			_hide_compare(), CONNECT_ONE_SHOT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_SHIFT and not event.echo:
		if event.pressed and not _hover.is_empty():
			_show_compare()
		elif not event.pressed:
			_hide_compare()

func _show_compare() -> void:
	_hide_compare()
	if _hover.is_empty() or not is_instance_valid(_hover.node) or not bool(_hover.stone.get("appraised", false)):
		return
	var Appraisal: Script = load("res://view/gems/appraisal.gd")
	var card := DeepUi.card(_overlay, Color(DeepUi.ACCENT, 0.6), 14, Color(DeepUi.INK, 0.97))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := DeepUi.vbox(card, 8)
	DeepUi.section(box, "scales", "This one" + (", and yours" if not _hover.against.is_empty() else ": you keep none of its skill"))
	var sheet: Control = Appraisal.Sheet.new(_hover.stone, _hover.against, {"skill_text": false, "owned_picture": false})
	box.add_child(sheet)
	sheet.call("show_all")
	_compare = card
	## Beside the tile, on whichever side has room.
	var node: Control = _hover.node
	var at: Vector2 = node.global_position - global_position
	card.reset_size()
	var width: float = card.get_combined_minimum_size().x
	var x: float = at.x + node.size.x + 12.0 if at.x + node.size.x + 12.0 + width < size.x else at.x - width - 12.0
	card.position = Vector2(clampf(x, 8.0, maxf(8.0, size.x - width - 8.0)), clampf(at.y - 20.0, 56.0, maxf(56.0, size.y - card.get_combined_minimum_size().y - 8.0)))

func _hide_compare() -> void:
	if _compare != null and is_instance_valid(_compare):
		_compare.queue_free()
	_compare = null

# --- what the pages share ------------------------------------------------------------------------

func choose_character(key: String) -> void:
	## This delver goes down next. Picking one is never more than this.
	if str(profile.get("current_character", "")) == key or not DeepProfile.unlocked_characters(profile).has(key):
		return
	DeepAudio.play("ui_confirm", {"volume": 0.8})
	profile.current_character = key
	if profile.get("characters", {}).has(key):
		profile.characters[key].erase("fresh")
	profile_changed.emit()

func step_character(direction: int) -> void:
	var owned: Array = DeepProfile.unlocked_characters(profile)
	var current: String = str(profile.get("current_character", DeepContent.starter_character()))
	if owned.size() < 2:
		return
	var next: String = str(owned[posmod(owned.find(current) + direction, owned.size())])
	if tab == "delvers":
		_roster_pick = next
		if _roster_view == "sockets":
			choose_character(next)
			return
		DeepAudio.play("ui_tap")
		_render()
		return
	choose_character(next)

func edit_loadout(character_key: String, socket: int = -1) -> void:
	## Opens a delver's sockets. Editing a delver's loadout makes them the one going down.
	_roster_pick = character_key
	_roster_view = "sockets"
	_bench_socket = socket
	if str(profile.get("current_character", "")) != character_key and DeepProfile.unlocked_characters(profile).has(character_key):
		profile.current_character = character_key
		if profile.get("characters", {}).has(character_key):
			profile.characters[character_key].erase("fresh")
		tab = "delvers"
		_shown_tab = ""
		profile_changed.emit()
		return
	open("delvers", true)

func touch() -> void:
	## A small change the player made by looking (a new stone seen, the Market opened): saved,
	## and the tab pips redrawn, without rebuilding the page.
	profile_touched.emit()
	_refresh_pips()

func _refresh_pips() -> void:
	if not is_instance_valid(_bar):
		return
	for entry in TABS:
		var button: Node = _bar.find_child("Tab_" + str(entry[0]), true, false)
		if button == null:
			continue
		for child in button.get_children():
			if child is HomeParts.Pip:
				child.queue_free()
		var pip: Array = tab_pip(str(entry[0]))
		if not pip.is_empty():
			HomeParts.pin(button, int(pip[0]), pip[1], true)

func page(list: String) -> int:
	return int(_pages.get(list, 0))

func turn(list: String, to: int) -> void:
	_pages[list] = to
	DeepAudio.play("ui_tap", {"volume": 0.6})
	_render()

func paged(parent: Node, list: String, items: Array, per_page: int) -> Array:
	## The items of a long list that go on its current page, and the pager under them when
	## there is more than one.
	var count: int = DeepUi.pages(items.size(), per_page)
	var at: int = clampi(page(list), 0, count - 1)
	_pages[list] = at
	if count > 1:
		DeepUi.pager(parent, at, count, func(to: int) -> void: turn(list, to))
	return DeepUi.page_of(items, at, per_page)

func _cheer_purse(text: String) -> void:
	## The gold that just came in or went out, shouted over the purse as it stands now.
	var purse: Node = _bar.get_node_or_null("Purse") if is_instance_valid(_bar) else null
	if purse is Control:
		cheer_at(purse as Control, text, DeepUi.ACCENT, "coin")

func _cheer_at(control: Control, text: String, color: Color, glyph: String) -> void:
	cheer_at(control, text, color, glyph)

func cheer_at(control: Control, text: String, color: Color, _glyph: String = "") -> void:
	## A little celebration where something landed: a burst, a swell and a word.
	if _headless or not is_instance_valid(control) or not control.is_inside_tree():
		return
	DeepUi.pulse(control, 1.3, 0.45)
	var at: Vector2 = control.global_position + Vector2(control.size.x * 0.5, control.size.y + 6.0) - global_position
	DeepUi.burst(self, at, color, 26, 220.0, 0.7, 6.0)
	var label := DeepUi.float_text(self, at, text, color, 20, -40.0, 1.5)
	label.z_index = 40

func cheer(text: String, color: Color, glyph: String = "chest") -> void:
	## Said over the Vault tab once the page has been rebuilt.
	_cheer = {"text": text, "color": color, "glyph": glyph}

func enter(node: Control, delay: float = 0.0) -> void:
	if _fresh:
		DeepUi.pop_in(node, delay)

func empty(content: Control, glyph: String, heading: String, text: String, height: float = 420.0) -> void:
	var holder := DeepUi.center(content)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size.y = height
	var card := DeepUi.card(holder, DeepUi.LINE, 30)
	var box := DeepUi.vbox(card, 10)
	var mark := DeepUi.icon(box, glyph, 64, DeepUi.DIM)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.title(box, heading, 24, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(box, text, 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 440)
	enter(card)

func chosen_mine() -> String:
	## The mine the party is set to go down, which decides how many sockets come down filled.
	var key: String = str(lobby.get("mine", ""))
	return key if not DeepContent.mine(key).is_empty() else DeepContent.starter_mine()

func member_short(member: Dictionary) -> bool:
	## Whether a member of the party cannot pay their own way down to the chosen mine.
	if not str(lobby.get("daily", "")).is_empty():
		return false
	return bool(member.get("connected", true)) and int(member.get("gold", 0)) < DeepEconomy.departure(chosen_mine(), bool(member.get("insured", false)))

func set_insured(on: bool) -> void:
	if not profile.has("outfit"):
		profile.outfit = {}
	profile.outfit.insure = on
	DeepAudio.play("ui_toggle", {"volume": 0.7})
	profile_changed.emit()

func rail_skill(record: Dictionary, index: int) -> String:
	## The skill of the stone a loadout sets in one socket, or "".
	var rail: Array = record.get("rail", [])
	return str(rail[index]) if index >= 0 and index < rail.size() and rail[index] is String else ""

func set_socket(character_key: String, index: int, skill: Variant, sound: String) -> void:
	## Sets a stone (by skill) in one socket of a loadout, or takes it out with null.
	if not DeepProfile.set_rail(profile, character_key, index, skill).is_empty():
		return
	_bench_socket = -1
	if not sound.is_empty():
		DeepAudio.play(sound, {"volume": 0.7})
	profile_changed.emit()

func buy_socket(character_key: String) -> void:
	var bought: Dictionary = DeepEconomy.unlock_socket(profile, character_key)
	if not bool(bought.get("ok", false)):
		return
	## The purse counts the price out on its own; the socket opening is the sound.
	DeepAudio.play("unlock", {"volume": 0.8})
	profile_changed.emit()

func socket_strip(parent: Node, character_key: String, loadout: Dictionary, edge: float, labelled: bool = false, on_click: Callable = Callable()) -> void:
	## A delver's sockets at a glance: the stones their loadout sets, a lock on each socket
	## not yet bought, and the Birthstone at the end. With `on_click`, each socket is a button
	## that is handed its index.
	var sockets: Array = DeepContent.character(character_key).get("sockets", [])
	for index in range(sockets.size()):
		var socket_color: String = str(sockets[index])
		var set_stone: Variant = loadout.rail[index] if index < loadout.rail.size() else null
		var locked: bool = not DeepProfile.fillable_socket(profile, character_key, index)
		var holder: Control = parent
		if labelled:
			holder = DeepUi.vbox(parent, 3)
			(holder as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		var slot: Control = kit_socket(holder, socket_color, set_stone if set_stone is Dictionary else {}, edge, locked)
		if on_click.is_valid():
			var at: int = index
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.tooltip_text = (slot.tooltip_text + "\n" if not slot.tooltip_text.is_empty() else "") + "Click to change it"
			DeepUi.juice(slot, 1.08)
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					DeepAudio.play("ui_tap")
					on_click.call(at))
		if labelled:
			DeepUi.label(holder, "Locked" if locked else ("Any" if socket_color == "ANY" else socket_color.capitalize()), 11, DeepUi.DIM if locked else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var birthstone: Dictionary = DeepStone.birthstone(character_key)
	if birthstone.is_empty():
		return
	var birth_holder: Control = parent
	if labelled:
		birth_holder = DeepUi.vbox(parent, 3)
		(birth_holder as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	kit_socket(birth_holder, "BIRTHSTONE", birthstone, edge)
	if labelled:
		DeepUi.label(birth_holder, "Birthstone", 11, GemMesh.tint(birthstone).lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)

func kit_socket(parent: Node, socket_color: String, stone: Dictionary, edge: float = 40.0, locked: bool = false) -> Control:
	## One socket of the loadout at a glance: its ring, and the stone in it if there is one,
	## or a lock if only the mine fills it.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(edge, edge)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_color, stone.is_empty())
	if socket_color == "BIRTHSTONE":
		ring.birth_tint = GemMesh.tint(stone)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(ring)
	if locked:
		ring.modulate = Color(1, 1, 1, 0.45)
		slot.tooltip_text = MINE_SOCKET
		var lock := DeepUi.icon(slot, "lock", edge * 0.42, DeepUi.MUTED, MINE_SOCKET)
		lock.position = Vector2.ONE * edge * 0.29
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return slot
	if stone.is_empty():
		slot.tooltip_text = "Empty %s socket" % ("any-color" if socket_color == "ANY" else socket_color.capitalize())
		return slot
	var thumb := StoneCard.mini(slot, stone, edge * 0.75, DeepStone.name(stone) if socket_color != "BIRTHSTONE" else "%s, the Birthstone" % str(stone.get("name", "")))
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(edge * 0.125))
	thumb.mouse_filter = Control.MOUSE_FILTER_PASS
	return slot

func wire(control: Control, data: Dictionary, preview: Callable, accepts: Callable, drop: Callable, ring: Control = null) -> void:
	## Make a control something that can be dragged (when `data` is given) and something that
	## can be dropped on (when `accepts` is given), the way the run's bench does.
	var drag_func: Callable = Callable()
	if not data.is_empty():
		drag_func = func(_at: Vector2) -> Variant:
			var shown: Control = preview.call()
			shown.modulate = Color(1, 1, 1, 0.85)
			control.set_drag_preview(DeepUi.held(shown))
			DeepAudio.play("die_pick", {"gap": 0.0, "volume": 0.7})
			return data
	var can_func: Callable = Callable()
	var drop_func: Callable = Callable()
	if accepts.is_valid():
		can_func = func(_at: Vector2, incoming: Variant) -> bool: return incoming is Dictionary and bool(accepts.call(incoming))
		drop_func = func(_at: Vector2, incoming: Variant) -> void: drop.call(incoming)
		_targets.append({"node": control, "accepts": accepts, "ring": ring})
	control.set_drag_forwarding(drag_func, can_func, drop_func)

func faces_row(parent: Node, die: Dictionary, edge: float) -> HBoxContainer:
	var row := DeepUi.hbox(parent, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tone: Color = DiceIcons.die_palette(die).body
	for f in die.get("faces", []):
		row.add_child(DiceIcons.face(edge, int(f.value), tone if str(f.kind) == "plain" else DiceIcons.face_kind_tint(str(f.kind)), str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.value), str(f.kind))))
	return row

func tile_mark(tile: PanelContainer, glyph: String, tone: Color, tip: String) -> void:
	## A small mark in a corner of a stone's tile. The tile's content is lifted into a layer
	## the first time, so marks can sit over it without the container laying them out.
	var layer: Control = tile.get_meta("mark_layer") if tile.has_meta("mark_layer") else null
	if layer == null:
		var tile_content := tile.get_child(0) as Control
		tile.remove_child(tile_content)
		layer = Control.new()
		layer.custom_minimum_size = tile_content.get_combined_minimum_size()
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(layer)
		tile_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(tile_content)
		tile.set_meta("mark_layer", layer)
	## Marks line up from the top-right corner leftwards: the top-left one holds the carat.
	var slot: int = int(layer.get_meta("marks", 0))
	layer.set_meta("marks", slot + 1)
	var mark := DeepUi.icon(layer, glyph, 16, tone, tip)
	mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mark.offset_left = -22 - slot * 18
	mark.offset_right = -6 - slot * 18
	mark.offset_top = 4
	mark.offset_bottom = 20
	mark.mouse_filter = Control.MOUSE_FILTER_PASS
