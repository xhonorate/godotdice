extends Control
## The workshop: seven tabs in one frame. Map (the mines under the workshop, the party, the
## way down and the day's seam), Lapidaries (the roster: who goes down, their dossier and
## their loadout), Vault (one stone per skill), Appraise (what came home, under the loupe),
## Shop (the day's Geodes, and contracts that trade five stones up for one), Commissions (the
## day's requests), Ledger (records and runs).
##
## Tabs are rebuilt whenever the profile or the lobby changes; stones and dice are
## photographs, so that is cheap, and only the one stone a tab is about is live 3D. A tab
## only animates in when it is opened, never on a rebuild.
##
## Every tab fits the screen whole: nothing here scrolls. What will not fit on one page is
## split into views (the map's side column, a lapidary's dossier and their sockets) or turned
## a page at a time (the vault tray, the Appraise tray, the ledger's runs).

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
const Appraisal = preload("res://view/gems/appraisal.gd")
const Geode = preload("res://view/gems/geode.gd")

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
signal menu_requested
signal player_name_requested
signal daily_chosen(date: String)

const TABS: Array = [["map", "Map", "map"], ["roster", "Lapidaries", "person"], ["vault", "Vault", "chest"], ["appraise", "Appraise", "loupe"], ["shop", "Shop", "geode"], ["commissions", "Commissions", "flag"], ["ledger", "Ledger", "book"]]
const color_ORDER: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE", "OPAL"]
## How wide a skill tile is in the vault grid, and how many go in a row. The vault is the
## one page in the workshop that scrolls: every skill in the pack belongs on it at a size
## worth looking at, and shrinking the tiles to fit a growing pack would cost the stones
## the picture rather than cost the page a scrollbar.
const VAULT_TILE: int = 84
const VAULT_COLUMNS: int = 10
## The word on a socket the lapidary has not opened, so the loadout does not fill it.
const MINE_SOCKET: String = "Locked. Buy it with gold to fill it from the vault before every run. Until then it is filled in the mine: below the Quarry with a temporary stone, and anywhere with a stone found on the way down."
## What the lock on a lapidary's dice says: they are never swapped.
const OWN_DICE: String = "Every lapidary goes down with their own five dice. Dice are worked in the mine, at a smithy or a carver, never swapped."
## How much of a long list goes on one page: three rows of the vault tray, two columns of the
## Appraise tray, and the ledger's runs.
const TRAY_PAGE: int = 45
const APPRAISE_PAGE: int = 10
const LEDGER_PAGE: int = 12
## How many stones the contract bench's picker shows a page: four rows of five.
const CONTRACT_PAGE: int = 20
## The size of a place on the contract bench.
const CONTRACT_SLOT := Vector2(150, 176)
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
var tab: String = "map"
var _bar: HBoxContainer
var _body: Control
var _backdrop: Control
var _vault_pick: String = ""
## The vault's tiles by skill and the column the lamp stands in, so picking a stone can
## redo just those rather than the whole page.
var _vault_tiles: Dictionary = {}
var _vault_side: VBoxContainer = null
## The live stone under the lamp, kept from one pick to the next: a new one is a new 3D
## world, sky and lights, and building those was most of what a click in the vault cost.
var _vault_stage: Showcase = null
var _vault_filter: String = ""
var _appraise_pick: String = ""
var _bench_socket: int = -1
var _roster_pick: String = ""
var _address: LineEdit
var _lobby_field: LineEdit
var _seed: LineEdit
var _fresh: bool = true
var _shown_tab: String = ""
var _headless: bool = false
var _gold_seen: int = -1
var _cheer: Dictionary = {}
## The map's side column: the expedition itself, the day's seam, or the party and how to play together.
var _side: String = "expedition"
## The day's seam the lobby was last seen set to, so a guest's side column follows the host there.
var _daily_seen: String = ""
## The Shop tab: the day's Geodes, or the contract bench.
var _shop_view: String = "geodes"
## The stones on the contract bench, by reference (DeepEconomy.contract_input), and which of
## the picker's lists is showing.
var _contract: Array = []
var _contract_from: String = "all"
## A contract that gives up vault stones asks twice.
var _contract_sure: bool = false
## The Lapidaries tab: the roster and a dossier, or the picked lapidary's sockets.
var _roster_view: String = "dossier"
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
	## A guest's side column follows the host to the day's seam and back.
	var daily: String = str(lobby.get("daily", ""))
	if daily != _daily_seen:
		_daily_seen = daily
		if not is_host:
			_side = "daily" if not daily.is_empty() else ("expedition" if _side == "daily" else _side)
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
	var purse := DeepUi.pill(_bar, "coin", "%d" % gold, DeepUi.ACCENT, 14,
		"Gold: from selling stones, commissions, the assayer at the lift and first conquests. It pays for the loupe, the way down to a deeper mine, insurance and sockets.")
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
		## Deferred so the purse has been laid out before the burst is placed on it. It is
		## found again by name rather than held onto: a second change in the same frame
		## rebuilds the bar, and the cheer belongs on whichever purse is on the page by then.
		call_deferred("_cheer_purse", "%+d gold" % (gold - from))
	_gold_seen = gold
	DeepUi.spacer(_bar)
	for entry in TABS:
		var key: String = str(entry[0])
		## The tray's count on Appraise; on Commissions, the requests a stone on the tray
		## could fill right now.
		var badge: int = 0
		match key:
			"appraise": badge = profile.get("tray", []).size()
			"commissions": badge = DeepEconomy.ready_count(profile)
		var button := DeepUi.tab_button(_bar, str(entry[2]), str(entry[1]), key == tab, func() -> void: open(key), 15, badge)
		if key == "vault" and not _cheer.is_empty():
			call_deferred("_cheer_at", button, str(_cheer.text), _cheer.color, str(_cheer.get("glyph", "chest")))
			_cheer = {}
		if key in ["appraise", "commissions"] and badge > 0 and key != tab:
			DeepUi.breathe(button, 0.65, 1.6)
	DeepUi.spacer(_bar)
	var player_name: String = str(profile.get("name", DeepProfile.DEFAULT_NAME))
	var name_button := DeepUi.icon_button(_bar, "person", player_name, func() -> void: player_name_requested.emit(), 14, DeepUi.MUTED)
	name_button.name = "PlayerName"
	name_button.tooltip_text = "%s · Change player name" % player_name
	name_button.clip_text = true
	name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_button.custom_minimum_size.x = 160
	name_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_button.add_theme_stylebox_override("normal", DeepUi.button_style(Color(0, 0, 0, 0), Color(DeepUi.LINE, 0.7), 8))
	DeepUi.gear_button(_bar, func() -> void: menu_requested.emit())
	DeepUi.clear(_body)
	_targets = []
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_body.add_child(margin)
	var content := DeepUi.vbox(margin, 16)
	match tab:
		"map": _map(content)
		"roster": _roster(content)
		"vault": _vault(content)
		"appraise": _appraise(content)
		"shop": _shop(content)
		"commissions": _commissions(content)
		"ledger": _ledger(content)

func _edit_loadout(character_key: String, view: String = "sockets") -> void:
	_roster_pick = character_key
	_roster_view = view
	_bench_socket = -1
	open("roster")

func _page(list: String) -> int:
	return int(_pages.get(list, 0))

func _turn(list: String, page: int) -> void:
	_pages[list] = page
	DeepAudio.play("ui_tap", {"volume": 0.6})
	_render()

func _paged(parent: Node, list: String, items: Array, per_page: int) -> Array:
	## The items of a long list that go on its current page, and the pager under them when
	## there is more than one.
	var count: int = DeepUi.pages(items.size(), per_page)
	var page: int = clampi(_page(list), 0, count - 1)
	_pages[list] = page
	if count > 1:
		DeepUi.pager(parent, page, count, func(to: int) -> void: _turn(list, to))
	return DeepUi.page_of(items, page, per_page)

func _cheer_purse(text: String) -> void:
	## The gold that just came in or went out, shouted over the purse as it stands now.
	var purse: Node = _bar.get_node_or_null("Purse") if is_instance_valid(_bar) else null
	if purse is Control:
		_cheer_at(purse as Control, text, DeepUi.ACCENT, "coin")

func _cheer_at(control: Control, text: String, color: Color, glyph: String) -> void:
	## A little celebration where something landed: a burst, a swell and a word.
	if _headless or not is_instance_valid(control) or not control.is_inside_tree():
		return
	DeepUi.pulse(control, 1.3, 0.45)
	var at: Vector2 = control.global_position + Vector2(control.size.x * 0.5, control.size.y + 6.0) - global_position
	DeepUi.burst(self, at, color, 26, 220.0, 0.7, 6.0)
	var label := DeepUi.float_text(self, at, text, color, 20, -40.0, 1.5)
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
	var keys: Array = DeepContent.mines_in_order()
	var map := MineMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(560, 740)
	columns.add_child(map)
	map.show_mines(keys, profile.get("mines", {}), str(lobby.get("mine", "")), is_host, DeepProfile.unlocked_characters(profile))
	map.chosen.connect(func(key: String) -> void:
		DeepAudio.play("ui_confirm", {"volume": 0.7})
		## Picking a mine is picking the expedition over the day's seam.
		if _side == "daily":
			_side = "expedition"
			daily_chosen.emit("")
		mine_chosen.emit(key))
	_enter(map)
	## The side column is three views: the expedition (where, as whom, and the way down), the
	## day's seam (everyone's same daily dig), and the party (who is coming, and how friends
	## join). The way down is at hand in all three. For the host, choosing between the
	## expedition and the day's seam is choosing which one the party goes down.
	var side := DeepUi.vbox(columns, 14)
	side.custom_minimum_size.x = 470
	var views := DeepUi.hbox(side, 8)
	var members: int = lobby.get("order", []).size()
	for entry in [["expedition", "descend", "Expedition", 0], ["daily", "calendar", "Daily", 0], ["party", "party", "Party", members if members > 1 else 0]]:
		var key: String = str(entry[0])
		var button := DeepUi.tab_button(views, str(entry[1]), str(entry[2]), _side == key, func() -> void:
			_side = key
			if is_host and key in ["expedition", "daily"]:
				daily_chosen.emit(DeepEconomy.today() if key == "daily" else "")
			_render(), 14, int(entry[3]))
		## The views share the row evenly whatever their words, so the row never shifts.
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = (side.custom_minimum_size.x - 16) / 3.0
		button.clip_text = true
		if key == "daily" and DeepEconomy.daily_state(profile) == "fresh" and _side != "daily":
			DeepUi.breathe(button, 0.7, 1.8)
	if _side == "party":
		_party_view(side)
	elif _side == "daily":
		_daily_view(side)
	else:
		_expedition_view(side)
	var go_card := DeepUi.card(side, Color(DeepUi.ACCENT, 0.3), 16)
	_go(DeepUi.vbox(go_card, 8))
	_enter(go_card, 0.1)

func _chosen_mine() -> String:
	## The mine the party is set to go down, which decides how many sockets come down filled.
	var key: String = str(lobby.get("mine", ""))
	return key if not DeepContent.mine(key).is_empty() else DeepContent.starter_mine()

func _expedition_view(side: VBoxContainer) -> void:
	## The expedition: which mine, and who goes down wearing what.
	var chosen_key: String = str(lobby.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(chosen_key)
	var record: Dictionary = profile.get("mines", {}).get(chosen_key, {})
	var trip := DeepUi.card(side, Color(DeepUi.ACCENT, 0.4), 18)
	## A little tighter than the other cards: the Quarry's twenty-odd skill marks take two
	## rows here, and a full party's way down still has to fit under it on one page.
	var trip_box := DeepUi.vbox(trip, 6)
	DeepUi.section(trip_box, "descend", "The expedition  ·  stratum %s" % MineMap.numeral(chosen_key))
	DeepUi.title(trip_box, str(mine.get("name", chosen_key)), 28, DeepUi.PAPER)
	DeepUi.wrap(trip_box, str(mine.get("text", "")), 13, DeepUi.MUTED)
	var facts := DeepUi.hbox(trip_box, 8)
	DeepUi.pill(facts, "stairs", "deepest %d" % int(record.get("deepest", 0)), DeepUi.INFO, 12)
	if DeepContent.is_endless(chosen_key):
		DeepUi.pill(facts, "crown", "endless", DeepUi.ACCENT, 12, "A Warden every %d floors, and no bottom." % DeepDescent.warden_every(mine))
	else:
		var crowns: int = mine.get("warden_depths", []).size() + 1
		DeepUi.pill(facts, "crown", "%d of %d crowns" % [mini(record.get("wardens", []).size(), crowns), crowns], DeepUi.ACCENT, 12,
			"%d Wardens and the final boss at depth %d" % [crowns - 1, DeepContent.mine_bottom(chosen_key)])
	DeepUi.pill(facts, "pick", DeepUi.plural(int(record.get("runs", 0)), "run"), DeepUi.MUTED, 12)
	## Who is met down here, by name; the rest is said on hover.
	var lapidary: String = str(mine.get("lapidary", ""))
	if not lapidary.is_empty():
		var met: bool = bool(profile.get("characters", {}).get(lapidary, {}).get("unlocked", false))
		DeepUi.pill(facts, "person", str(DeepContent.character(lapidary).get("name", lapidary)), DeepUi.GOOD if met else DeepUi.MUTED, 12,
			("%s was met here" if met else "%s joins when the boss above this mine falls") % DeepContent.character_title(lapidary))
	## What the rock here gives up and, below the Quarry, what a lapidary is handed for
	## starting this deep. What it costs is on the Descend button: each pays their own fare.
	var band: Dictionary = DeepForge.carat_band(mine, 1)
	var deeper: bool = chosen_key != DeepContent.starter_mine()
	if not band.is_empty():
		var rock: String = "Stones usually up to %d carats, never over %d" % [int(band.soft), int(band.cap)]
		if deeper:
			rock += "; %d pyrite to start" % int(mine.get("start_pyrite", 0))
		DeepUi.stat(trip_box, "gem", rock, DeepUi.PAPER, 13, ("Starting here costs a fare of %d gold, paid by each lapidary at the shaft head. Each starts with %d pyrite, never cashed at the lift, and every socket not bought is offered three temporary stones that shatter when the run ends."
			% [DeepEconomy.fare(chosen_key), int(mine.get("start_pyrite", 0))]) if deeper else "")
	var batch: Array = mine.get("batch", [])
	if not batch.is_empty():
		var found: Array = batch.filter(func(k: Variant) -> bool: return profile.get("vault", {}).has(str(k)) or profile.get("seen", []).has(str(k)))
		## A row that wraps: in one long line a mine's twenty-odd marks widened the whole column,
		## and the map beside it jumped every time the side was switched to the party and back.
		var skills := HFlowContainer.new()
		skills.add_theme_constant_override("h_separation", 3)
		skills.add_theme_constant_override("v_separation", 3)
		skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trip_box.add_child(skills)
		DeepUi.label(skills, "%d skills first found here  ·  %d found" % [batch.size(), found.size()], 12, DeepUi.MUTED)
		DeepUi.gap(skills, 4)
		for key in batch:
			var def: Dictionary = DeepContent.skill(str(key))
			var known: bool = found.has(key)
			DeepUi.icon(skills, GemIcons.emblem(str(key)), 15, DeepUi.color(str(def.get("color", ""))) if known else DeepUi.DIM,
				str(def.get("name", key)) if known else "Not found yet")
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
	kit.tooltip_text = "Click to change the stones they bring"
	kit.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			DeepAudio.play("ui_tap")
			_edit_loadout(current))
	var rail_row := DeepUi.hbox(kit, 6)
	rail_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_socket_strip(rail_row, current, loadout, 40.0)
	var dice_row := DeepUi.hbox(kit, 6)
	dice_row.mouse_filter = Control.MOUSE_FILTER_PASS
	for die in loadout.dice:
		var die_thumb := Thumbs.DieThumb.new(die, 32)
		die_thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		dice_row.add_child(die_thumb)
	var empty: int = 0
	for index in range(DeepProfile.open_sockets(profile, current)):
		if index < loadout.rail.size() and not loadout.rail[index] is Dictionary:
			empty += 1
	if empty > 0:
		DeepUi.gap(dice_row, 8)
		DeepUi.stat(dice_row, "gem", "%s empty" % DeepUi.plural(empty, "socket"), DeepUi.ACCENT, 12)
	var wear_buttons := DeepUi.hbox(wear_box, 8)
	DeepUi.icon_button(wear_buttons, "gem", "Edit loadout", func() -> void: _edit_loadout(current), 13, DeepUi.ACCENT)
	DeepUi.icon_button(wear_buttons, "person", "Change lapidary", func() -> void: _edit_loadout(current, "dossier"), 13, DeepUi.MUTED)
	_enter(wear, 0.05)

const DAILY_KIND_WORDS: Dictionary = {"rail": "Rail rule", "hazard": "Hazard", "blessing": "Blessing", "twist": "Twist"}

func _daily_tone(kind: String) -> Color:
	match kind:
		"hazard": return DeepUi.BAD
		"blessing": return DeepUi.GOOD
		"twist": return Color("c58bff")
	return DeepUi.INFO

func _daily_view(side: VBoxContainer) -> void:
	## The day's seam: the same for everyone on this build today. Its four cards, how it is
	## scored and paid, where this lapidary stands today, and what it lends the party.
	var date: String = str(lobby.get("daily", ""))
	if date.is_empty():
		date = DeepEconomy.today()
	var plan: Dictionary = DeepEconomy.daily_plan(date)
	var mine_key: String = str(plan.mine)
	var mine: Dictionary = DeepContent.mine(mine_key)
	var palette: String = str(mine.get("palette", ""))
	var tone: Color = Color(palette).lightened(0.15) if not palette.is_empty() else DeepUi.ACCENT
	var seam := DeepUi.card(side, Color(tone, 0.45), 16)
	var box := DeepUi.vbox(seam, 6)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "calendar", "The daily dig", tone).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left: int = DeepEconomy.seconds_to_tomorrow()
	DeepUi.stat(head, "hourglass", "%dh %02dm left" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 12, "A new seam opens every day at midnight UTC.")
	var title := DeepUi.title(box, "%s, and on down" % str(mine.get("name", mine_key)), 24, DeepUi.PAPER)
	title.tooltip_text = "It starts at the top of the Quarry and goes on through every mine, as deep as you want to go."
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	DeepUi.label(box, "The same seam for everyone today.", 12, DeepUi.MUTED)
	## The day's four cards: the rail rule, then the hazard, the blessing and the twist.
	var keys: Array = [str(plan.rail)] + plan.get("mods", [])
	for key in keys:
		var mod: Dictionary = DeepEconomy.daily_mod(str(key))
		var kind: String = str(mod.get("kind", "hazard"))
		var hue: Color = _daily_tone(kind)
		var line := DeepUi.hbox(box, 8)
		DeepUi.icon(line, str(mod.get("glyph", "spark")), 20, hue, str(DAILY_KIND_WORDS.get(kind, ""))).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var words := DeepUi.vbox(line, 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name: String = str(mod.get("name", key))
		if str(key) == "DROUGHT" and plan.has("drought"):
			name = "%s: no %s" % [name, str(DeepContent.color(str(plan.drought)).get("name", plan.drought))]
		if str(key) == "BORROWED_BIRTHSTONE" and plan.has("birthstone"):
			name = "%s: %s's" % [name, DeepContent.character_title(str(plan.birthstone)).get_slice(",", 0)]
		var title_line := DeepUi.hbox(words, 6)
		DeepUi.label(title_line, name, 14, hue.lightened(0.1))
		DeepUi.label(title_line, str(DAILY_KIND_WORDS.get(kind, "")), 11, DeepUi.DIM)
		DeepUi.wrap(words, str(mod.get("text", "")), 12, DeepUi.MUTED)
	## How it is scored and paid, and where this lapidary stands today.
	var knee: int = int(DeepContent.constant("daily_score_knee", 1000))
	DeepUi.stat(box, "coin", "Paid in gold for your score", DeepUi.ACCENT, 13,
		"Your score is the worth of the stones you bring up plus the pyrite you carry. A fall scores only what the salvage dice save. A score pays %d gold at %d, and half the rate past that. Nothing you find is kept." % [DeepEconomy.daily_payout(knee), knee])
	var best: Dictionary = DeepEconomy.daily_best(profile, date)
	match DeepEconomy.daily_state(profile, date):
		"locked":
			DeepUi.pill(box, "lock", "Beat the Quarry's final boss to be paid for it", DeepUi.DIM, 12)
		"played":
			DeepUi.pill(box, "star", "Best today: %d, paid %d gold" % [int(best.score), int(best.gold)], DeepUi.GOOD, 12, "Another dig today pays only the gold its score adds to this.")
		_:
			DeepUi.pill(box, "star", "Not dug yet today", DeepUi.ACCENT, 12)
	_enter(seam)
	## Who the party goes down as: lent for the day, with what the rail rule gives them.
	var seat: int = maxi(0, lobby.get("order", []).find(local_id))
	var character: String = DeepEconomy.daily_lapidary(plan)
	var lent := DeepUi.card(side, DeepUi.LINE, 14)
	var lent_box := DeepUi.vbox(lent, 8)
	DeepUi.section(lent_box, "person", "Lent for the day")
	var row := DeepUi.hbox(lent_box, 12)
	row.add_child(Roster.Portrait.new(character, Vector2(72, 86), false, false, true))
	var facts := DeepUi.vbox(row, 4)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.title(facts, DeepContent.character_title(character), 18, DeepUi.PAPER)
	DeepUi.wrap(facts, "The whole party goes down as this lapidary, with the stones and dice the day lends. Nothing of yours goes down.", 12, DeepUi.MUTED)
	var rail := DeepUi.hbox(lent_box, 6)
	var stones: Array = DeepEconomy.daily_rail(plan, character, seat)
	var sockets: Array = DeepContent.character(character).get("sockets", [])
	for index in range(sockets.size()):
		var stone: Variant = stones[index] if index < stones.size() else null
		_kit_socket(rail, str(sockets[index]), stone if stone is Dictionary else {}, 40.0)
	var carried: String = str(plan.get("birthstone", character)) if plan.get("mods", []).has("BORROWED_BIRTHSTONE") else character
	_kit_socket(rail, "BIRTHSTONE", DeepStone.birthstone(carried), 40.0)
	_enter(lent, 0.05)

func _member_short(member: Dictionary) -> bool:
	## Whether a member of the party cannot pay their own way down to the chosen mine.
	return bool(member.get("connected", true)) and int(member.get("gold", 0)) < DeepEconomy.departure(_chosen_mine(), bool(member.get("insured", false)))

func _set_insured(on: bool) -> void:
	if not profile.has("outfit"):
		profile.outfit = {}
	profile.outfit.insure = on
	DeepAudio.play("ui_toggle", {"volume": 0.7})
	profile_changed.emit()

func _go(box: VBoxContainer) -> void:
	## The way down, or for a guest, the word that they are ready; and how ready the party is.
	## Over it, what this lapidary will pay at the shaft head and the insurance on their haul.
	var me: Dictionary = lobby.members.get(local_id, {})
	var order: Array = lobby.get("order", [])
	if not str(lobby.get("daily", "")).is_empty():
		_go_daily(box, me, order)
		return
	var insured: bool = bool(profile.get("outfit", {}).get("insure", false))
	var cost: int = DeepEconomy.departure(_chosen_mine(), insured)
	var purse: int = int(profile.get("gold", 0))
	var short: Array = order.filter(func(id: Variant) -> bool: return _member_short(lobby.members.get(id, {})))
	if order.size() > 1:
		var ready_count: int = order.filter(func(id: Variant) -> bool:
			return str(id) == str(lobby.get("host", "p0")) or bool(lobby.members.get(id, {}).get("ready", false))).size()
		var summary := DeepUi.hbox(box, 8)
		DeepUi.stat(summary, "party", "A party of %d" % order.size(), DeepUi.PAPER, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.pill(summary, "check", "%d of %d ready" % [ready_count, order.size()], DeepUi.GOOD if ready_count == order.size() else DeepUi.MUTED, 11)
	if not is_host:
		var guest_row := DeepUi.hbox(box, 8)
		var ready := DeepUi.primary(guest_row, "check", "Unready" if bool(me.get("ready", false)) else ("I'm ready · %d gold" % cost if cost > 0 else "I'm ready"),
			func() -> void: member_changed.emit({"ready": not bool(me.get("ready", false))}), 16, DeepUi.GOOD)
		ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ready.disabled = status != "joined" or (purse < cost and not bool(me.get("ready", false)))
		_insurance_toggle(guest_row, insured)
		if purse < cost:
			DeepUi.stat(box, "coin", "You need %d gold for the way down." % cost, DeepUi.BAD, 12)
		return
	var typed: String = _seed.text if _seed != null and is_instance_valid(_seed) else ""
	## What this lapidary pays at the shaft head is said on the button that spends it.
	var go := DeepUi.primary(box, "descend", "Descend · %d gold" % cost if cost > 0 else "Descend", func() -> void:
		depart_requested.emit(int(_seed.text) if _seed != null and is_instance_valid(_seed) and _seed.text.is_valid_int() else 0), 20)
	go.tooltip_text = ("Taken from your purse at the shaft head: the fare%s." % (" and the insurance" if insured else "")) if cost > 0 else "The Quarry costs nothing to go down."
	DeepUi.voice(go, "depart")
	go.custom_minimum_size.y = 54
	go.disabled = not can_start or bool(lobby.get("started", false))
	if not go.disabled:
		DeepUi.breathe(go, 0.82, 2.0)
	if short.size() == 1 and str(short[0]) == local_id and insured and purse >= DeepEconomy.fare(_chosen_mine()):
		## Only the insurance is out of reach (remembered on from a fuller purse): say how to go.
		DeepUi.stat(box, "coin", "Your %d gold can't cover the insurance: turn it off to go down." % purse, DeepUi.BAD, 12)
	elif not short.is_empty():
		var names: Array = short.map(func(id: Variant) -> String: return "you" if str(id) == local_id else str(lobby.members.get(id, {}).get("name", id)))
		DeepUi.stat(box, "coin", "Short of the way down: %s" % ", ".join(names), DeepUi.BAD, 12)
	elif not can_start:
		DeepUi.stat(box, "hourglass", "Waiting for everyone to be ready.", DeepUi.MUTED, 12)
	var seed_row := DeepUi.hbox(box, 8)
	_insurance_toggle(seed_row, insured)
	DeepUi.gap(seed_row, 4)
	DeepUi.label(seed_row, "Seed", 12, DeepUi.DIM)
	_seed = LineEdit.new()
	_seed.placeholder_text = "blank for a new one"
	_seed.text = typed
	_seed.custom_minimum_size = Vector2(130, 0)
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed)

func _go_daily(box: VBoxContainer, me: Dictionary, order: Array) -> void:
	## The way down the day's seam: nothing to pay and nothing to insure. Whether it pays is
	## each lapidary's own question, said beside the button.
	var state: String = DeepEconomy.daily_state(profile, str(lobby.get("daily", "")))
	var best: Dictionary = DeepEconomy.daily_best(profile, str(lobby.get("daily", "")))
	if order.size() > 1:
		var ready_count: int = order.filter(func(id: Variant) -> bool:
			return str(id) == str(lobby.get("host", "p0")) or bool(lobby.members.get(id, {}).get("ready", false))).size()
		var summary := DeepUi.hbox(box, 8)
		DeepUi.stat(summary, "party", "A party of %d, down today's seam" % order.size(), DeepUi.PAPER, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.pill(summary, "check", "%d of %d ready" % [ready_count, order.size()], DeepUi.GOOD if ready_count == order.size() else DeepUi.MUTED, 11)
	var pays: String = {"fresh": "Your first dig today is paid in full.", "played": "Your best today is %d. This dig pays only what it adds." % int(best.score),
		"locked": "You have not beaten the Quarry: digging pays you nothing."}.get(state, "")
	if not is_host:
		var ready := DeepUi.primary(box, "check", "Unready" if bool(me.get("ready", false)) else "I'm ready", func() -> void: member_changed.emit({"ready": not bool(me.get("ready", false))}), 16, DeepUi.GOOD)
		ready.disabled = status != "joined"
		DeepUi.stat(box, "calendar", "The host is taking the party down today's seam. " + pays, DeepUi.MUTED, 12)
		return
	var words: String = "Dig today's seam" if state == "fresh" else ("Dig it again" if state == "played" else "Beat the Quarry first")
	var go := DeepUi.primary(box, "calendar", words, func() -> void: depart_requested.emit(0), 20)
	go.tooltip_text = "Down the day's seam as the lapidary it lends, with its stones and dice. Nothing of yours goes down, and nothing found comes home: it is scored and paid for."
	DeepUi.voice(go, "depart")
	go.custom_minimum_size.y = 54
	go.disabled = not can_start or bool(lobby.get("started", false))
	if not go.disabled:
		DeepUi.breathe(go, 0.82, 2.0)
	if state != "locked" and not can_start:
		DeepUi.stat(box, "hourglass", "Waiting for everyone to be ready.", DeepUi.MUTED, 12)
	else:
		DeepUi.stat(box, "calendar", pays if state != "locked" else "The daily seam is for lapidaries who have beaten the Quarry.", DeepUi.GOOD if state == "fresh" else DeepUi.MUTED, 12)

func _insurance_toggle(parent: Node, insured: bool) -> Button:
	## Insurance on the haul, remembered from one run to the next until turned off.
	var price: int = DeepEconomy.insurance(_chosen_mine())
	var cover := DeepUi.icon_button(parent, "check" if insured else "split_shield", ("Insured · %d gold" if insured else "Insure · %d gold") % price,
		func() -> void: _set_insured(not insured), 13, DeepUi.GOOD if insured else DeepUi.MUTED)
	cover.tooltip_text = "Insurance: if the dig is lost, every salvage die is thrown twice and the better throw kept. Paid at the shaft head, every run, until you turn it off."
	if insured:
		DeepUi.selected_style(cover, DeepUi.GOOD)
	elif int(profile.get("gold", 0)) < DeepEconomy.departure(_chosen_mine(), true):
		## Not offered on a purse that cannot pay for it, the same as a socket or a reroll:
		## insured on an empty purse, the way down would only refuse to open.
		cover.disabled = true
		cover.tooltip_text = "You have %d gold. Insurance costs %d on top of the way down." % [int(profile.get("gold", 0)), price]
	return cover

func _party_view(side: VBoxContainer) -> void:
	## The party: who is coming and whether they are ready, and how friends join.
	var party := DeepUi.card(side, DeepUi.LINE, 16)
	var party_box := DeepUi.vbox(party, 8)
	DeepUi.section(party_box, "party", "The party")
	for id in lobby.get("order", []):
		var member: Dictionary = lobby.members.get(id, {})
		var row := DeepUi.hbox(party_box, 10)
		DeepUi.icon(row, "person", 20, DeepUi.PAPER if str(id) == local_id else DeepUi.INFO)
		var who := DeepUi.label(row, str(member.get("name", id)) + (" (you)" if str(id) == local_id else ""), 15, DeepUi.PAPER)
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(row, DeepContent.character_title(str(member.get("character", ""))), 13, DeepUi.MUTED)
		var note: String = "host" if str(id) == str(lobby.get("host", "p0")) else ("ready" if bool(member.get("ready", false)) else "not ready")
		if not bool(member.get("connected", true)):
			note = "away"
		if _member_short(member):
			DeepUi.pill(row, "coin", "short", DeepUi.BAD, 11, "Cannot pay the way down to %s" % DeepContent.mine_name(_chosen_mine()))
		DeepUi.pill(row, "crown" if note == "host" else ("check" if note == "ready" else "hourglass"), note, DeepUi.GOOD if note in ["ready", "host"] else DeepUi.MUTED, 11)
		if is_host and str(id) != local_id:
			var member_id: String = str(id)
			var kick := DeepUi.icon_button(row, "cross_out", "", func() -> void: kick_requested.emit(member_id), 12, DeepUi.BAD)
			kick.tooltip_text = "Send %s back to their own workshop" % str(member.get("name", id))
	## Out of the party: a guest goes home, a host closes it and sends everyone home.
	if status not in ["local", "offline"]:
		var hosting: bool = is_host
		var out := DeepUi.icon_button(party_box, "prev", "Close the party" if hosting else "Leave the party", func() -> void: leave_party_requested.emit(), 13, DeepUi.MUTED)
		out.size_flags_horizontal = Control.SIZE_SHRINK_END
		out.tooltip_text = "Everyone goes back to their own workshop." if hosting else "Back to a workshop of your own."
	_enter(party)
	## Co-op over the network.
	var together := DeepUi.card(side, DeepUi.LINE, 16)
	var together_box := DeepUi.vbox(together, 8)
	DeepUi.section(together_box, "wifi", "Play together")
	var said: Array = STATUS_WORDS.get(status, [status.capitalize(), DeepUi.MUTED])
	DeepUi.stat(together_box, "wifi", str(said[0]), said[1], 12)
	## Hosting on the LAN: the address a friend types into Join, ready to copy.
	var lan_ip: String = DeepSession.lan_address() if is_host and status == "hosting" and invite_code.is_empty() else ""
	if not lan_ip.is_empty():
		var at := DeepUi.hbox(together_box, 8)
		DeepUi.stat(at, "crown", "Friends on your network join %s" % lan_ip, DeepUi.PAPER, 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var copy_ip := DeepUi.icon_button(at, "copy", "Copy", Callable(), 13, DeepUi.MUTED)
		copy_ip.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(lan_ip)
			_cheer_at(copy_ip, "Copied", DeepUi.GOOD, "copy"))
	## With anyone else in the party, hosting or joining afresh would quietly break it up and
	## send them home without a word: that is what Close or Leave the party is for.
	var in_party: bool = lobby.get("order", []).size() > 1
	var first: String = ("Close the party first." if is_host else "Leave the party first.") if in_party else ""
	var lan := DeepUi.hbox(together_box, 8)
	var host_lan := DeepUi.icon_button(lan, "crown", "Host on LAN", func() -> void: host_requested.emit(DeepSession.DEFAULT_PORT), 13, DeepUi.ACCENT)
	_address = LineEdit.new()
	_address.text = str(settings.get("last_address", "127.0.0.1"))
	_address.custom_minimum_size = Vector2(150, 0)
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan.add_child(_address)
	var join_lan := DeepUi.icon_button(lan, "play", "Join", func() -> void: join_requested.emit(_address.text, DeepSession.DEFAULT_PORT), 13, DeepUi.INFO)
	var steam := DeepUi.hbox(together_box, 8)
	var host_steam := DeepUi.icon_button(steam, "party", "Host on Steam", func() -> void: steam_host_requested.emit(), 13, DeepUi.ACCENT)
	_lobby_field = LineEdit.new()
	_lobby_field.placeholder_text = "Steam lobby ID"
	_lobby_field.custom_minimum_size = Vector2(150, 0)
	_lobby_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_field.text_submitted.connect(func(text: String) -> void:
		if not in_party:
			steam_join_requested.emit(text))
	steam.add_child(_lobby_field)
	var join_steam := DeepUi.icon_button(steam, "play", "Join", func() -> void: steam_join_requested.emit(_lobby_field.text), 13, DeepUi.INFO)
	for button in [host_lan, join_lan, host_steam, join_steam]:
		button.disabled = in_party
		if in_party:
			button.tooltip_text = first
	if not invite_code.is_empty():
		var code := DeepUi.hbox(together_box, 8)
		DeepUi.stat(code, "party", "Lobby %s" % invite_code, DeepUi.PAPER, 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.icon_button(code, "person", "Invite friends", func() -> void: invite_requested.emit(), 13, DeepUi.GOOD)
		var copy := DeepUi.icon_button(code, "copy", "Copy ID", Callable(), 13, DeepUi.MUTED)
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(invite_code)
			_cheer_at(copy, "Copied", DeepUi.GOOD, "copy"))
	DeepUi.wrap(together_box, "Friends join a Steam lobby from the overlay's invite list, from Join Game in the friends list, or by pasting its ID above.", 11, DeepUi.DIM)
	_enter(together, 0.05)

func _socket_strip(parent: Node, character_key: String, loadout: Dictionary, edge: float, labelled: bool = false) -> void:
	## A lapidary's sockets at a glance: the stones their loadout sets, a lock on each socket
	## not yet bought, and the Birthstone at the end.
	var sockets: Array = DeepContent.character(character_key).get("sockets", [])
	for index in range(sockets.size()):
		var socket_color: String = str(sockets[index])
		var set_stone: Variant = loadout.rail[index] if index < loadout.rail.size() else null
		var locked: bool = not DeepProfile.fillable_socket(profile, character_key, index)
		if not labelled:
			_kit_socket(parent, socket_color, set_stone if set_stone is Dictionary else {}, edge, locked)
			continue
		var holder := DeepUi.vbox(parent, 3)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		_kit_socket(holder, socket_color, set_stone if set_stone is Dictionary else {}, edge, locked)
		DeepUi.label(holder, "Locked" if locked else ("Any" if socket_color == "ANY" else socket_color.capitalize()), 10, DeepUi.DIM if locked else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var birthstone: Dictionary = DeepStone.birthstone(character_key)
	if birthstone.is_empty():
		return
	if not labelled:
		_kit_socket(parent, "BIRTHSTONE", birthstone, edge)
		return
	var birth_holder := DeepUi.vbox(parent, 3)
	birth_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	_kit_socket(birth_holder, "BIRTHSTONE", birthstone, edge)
	DeepUi.label(birth_holder, "Birthstone", 10, GemMesh.tint(birthstone).lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)

func _kit_socket(parent: Node, socket_color: String, stone: Dictionary, edge: float = 40.0, locked: bool = false) -> void:
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
	slot.add_child(ring)
	if locked:
		ring.modulate = Color(1, 1, 1, 0.45)
		slot.tooltip_text = MINE_SOCKET
		var lock := DeepUi.icon(slot, "lock", edge * 0.42, DeepUi.MUTED, MINE_SOCKET)
		lock.position = Vector2.ONE * edge * 0.29
		return
	if stone.is_empty():
		slot.tooltip_text = "Empty %s socket" % ("any-color" if socket_color == "ANY" else socket_color.capitalize())
		return
	var thumb := StoneCard.mini(slot, stone, edge * 0.75, DeepStone.name(stone) if socket_color != "BIRTHSTONE" else "%s, the Birthstone" % str(stone.get("name", "")))
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(edge * 0.125))
	thumb.mouse_filter = Control.MOUSE_FILTER_PASS

# --- lapidaries ---------------------------------------------------------------------------------

func _roster(content: VBoxContainer) -> void:
	## Two views of one lapidary, each a page of its own: the roster strip over the dossier of
	## the one being looked at, and (once unlocked) their sockets.
	var order: Array = DeepContent.characters_in_unlock_order()
	var current: String = str(profile.get("current_character", DeepContent.starter_character()))
	if _roster_pick.is_empty() or DeepContent.character(_roster_pick).is_empty():
		_roster_pick = current
	var unlocked_keys: Array = DeepProfile.unlocked_characters(profile)
	var looking_at_unlocked: bool = unlocked_keys.has(_roster_pick)
	if not looking_at_unlocked:
		_roster_view = "dossier"
	if _roster_view != "dossier":
		_loadout_head(content, _roster_pick, _roster_pick == current)
		_sockets_view(content, _roster_pick)
		return
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
				if profile.get("characters", {}).has(picked_key):
					profile.characters[picked_key].erase("fresh")
				_render())
		_enter(tile, 0.03 * index)
		index += 1
	_dossier(content, _roster_pick, looking_at_unlocked, _roster_pick == current)

func _loadout_head(content: VBoxContainer, key: String, chosen: bool) -> void:
	## Over a lapidary's sockets: the way back to the roster, who they are, and the dice
	## they always take down, which are theirs and not for swapping.
	var character: Dictionary = DeepContent.character(key)
	var head := DeepUi.card(content, DeepUi.LINE, 12)
	var row := DeepUi.hbox(head, 14)
	var left_slot := DeepUi.hbox(row, 0)
	left_slot.custom_minimum_size.x = 190
	left_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := DeepUi.icon_button(left_slot, "prev", "Lapidaries", func() -> void: _edit_loadout(key, "dossier"), 14, DeepUi.MUTED)
	DeepUi.voice(back, "ui_back")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var center_slot := CenterContainer.new()
	center_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center_slot)
	var navigation := DeepUi.hbox(center_slot, 10)
	var owned := DeepProfile.unlocked_characters(profile)
	var previous := DeepUi.icon_button(navigation, "prev", "", func() -> void: _step_loadout(key, -1), 14, DeepUi.MUTED)
	previous.tooltip_text = "Previous lapidary"
	previous.disabled = owned.size() < 2
	previous.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	navigation.add_child(Roster.Portrait.new(key, Vector2(48, 56), false, false, chosen))
	var names := DeepUi.vbox(navigation, 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.title(names, DeepContent.character_title(key), 22, DeepUi.PAPER)
	var dice := DeepUi.hbox(names, 6)
	dice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dice.mouse_filter = Control.MOUSE_FILTER_PASS
	dice.tooltip_text = OWN_DICE
	for die in DeepProfile.loadout(profile, key).dice:
		var die_thumb := Thumbs.DieThumb.new(die, 34)
		die_thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		dice.add_child(die_thumb)
	var next := DeepUi.icon_button(navigation, "next", "", func() -> void: _step_loadout(key, 1), 14, DeepUi.MUTED)
	next.tooltip_text = "Next lapidary"
	next.disabled = owned.size() < 2
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right_slot := DeepUi.hbox(row, 0)
	right_slot.custom_minimum_size.x = 190
	right_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_slot.alignment = BoxContainer.ALIGNMENT_END
	if not chosen:
		var play := DeepUi.primary(right_slot, "descend", "Play as %s" % str(character.get("name", key)), func() -> void:
			DeepAudio.play("ui_confirm", {"volume": 0.8})
			profile.current_character = key
			profile_changed.emit(), 15)
		play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_enter(head)

func _step_loadout(key: String, direction: int) -> void:
	var owned: Array = DeepProfile.unlocked_characters(profile)
	var index: int = owned.find(key)
	if owned.size() < 2 or index < 0:
		return
	var next_index: int = posmod(index + direction, owned.size())
	_edit_loadout(str(owned[next_index]))

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
	left.add_child(Roster.Portrait.new(key, Vector2(250, 250), not unlocked, false, chosen))
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
	var dice_head := DeepUi.section(middle, "die", "Their dice")
	DeepUi.stat(dice_head, "lock", "always their own", DeepUi.DIM, 11, OWN_DICE)
	var dice_row := DeepUi.hbox(middle, 10)
	var die_index: int = 0
	for die_key in character.get("dice", []):
		var die: Dictionary = DeepForge.die_from(die_key, "roster_%s_%d" % [key, die_index])
		var holder := DeepUi.vbox(dice_row, 3)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		var thumb := Thumbs.DieThumb.new(die, 46)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(thumb)
		DeepUi.label(holder, DeepDice.describe(die), 11, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		_faces_row(holder, die, 12)
		die_index += 1
	## The sockets as the loadout has them: the stones it sets, the ones only the mine fills,
	## and the Birthstone. Click them to change what goes in.
	DeepUi.section(middle, "gem", "Their sockets")
	var socket_row := DeepUi.hbox(middle, 10)
	socket_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_socket_strip(socket_row, key, DeepProfile.loadout(profile, key), 46.0, true)
	if unlocked:
		socket_row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		socket_row.tooltip_text = "Click to change the stones they bring"
		socket_row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_tap")
				_edit_loadout(key))
	DeepUi.section(middle, "spark", "Passive")
	var passive_card := DeepUi.card(middle, Color(DeepUi.ACCENT, 0.35), 12)
	var passive_box := DeepUi.vbox(passive_card, 3)
	DeepUi.title(passive_box, str(passive.get("name", "Passive")), 16, DeepUi.ACCENT_HI)
	DeepUi.wrap(passive_box, str(passive.get("text", "")), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 380)
	## The Birthstone, in full.
	var right := DeepUi.vbox(columns, 10)
	right.custom_minimum_size.x = 330
	var birth_card := DeepUi.card(right, Color(tint, 0.6), 14, Color(0.07, 0.06, 0.09, 0.92))
	## Tiers sit close: a Birthstone with many of them must still fit the page at the smallest
	## text the game sets.
	var birth_box := DeepUi.vbox(birth_card, 5)
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
		var where: String = DeepProfile.lapidary_boss_mine(key)
		var sealed: bool = not where.is_empty() and not bool(profile.get("mines", {}).get(where, {}).get("unlocked", false))
		DeepUi.stat(actions, "lock", "%s.%s" % [Roster.unlock_hint(key), " That mine is still sealed." if sealed else ""], DeepUi.DIM, 13)
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

func _sockets_view(content: VBoxContainer, character_key: String) -> void:
	## The rail of one unlocked lapidary. The sockets they have opened are filled from the
	## vault: drag a stone onto one (or click a socket, then a stone), drag a set stone onto
	## another socket to move it, or back into the vault to take it out. The rest of the rail
	## wears a lock, and the next of them is for sale here, for good. Until it is bought a
	## locked socket is filled in the mine, where any stone fits any socket regardless of its
	## color.
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = profile.characters.get(character_key, {"rail": [], "dice": []})
	var sockets: Array = character.get("sockets", [])
	var rail_cap: int = DeepProfile.open_sockets(profile, character_key)
	if not DeepProfile.fillable_socket(profile, character_key, _bench_socket) or _bench_socket >= sockets.size():
		_bench_socket = -1
	var filled: int = 0
	for index in range(rail_cap):
		if _rail_skill(record, index) != "":
			filled += 1
	var rail_card := DeepUi.card(content, DeepUi.LINE, 18)
	var rail_box := DeepUi.vbox(rail_card, 12)
	var rail_head := DeepUi.hbox(rail_box, 8)
	DeepUi.section(rail_head, "gem", "Sockets").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var price: int = DeepEconomy.socket_price(profile, character_key)
	var cap_words: String = "every socket open" if price < 0 else "the locked sockets are filled in the mine until bought"
	DeepUi.label(rail_head, "%d of %d set; %s" % [filled, rail_cap, cap_words], 13, DeepUi.GOOD if filled >= rail_cap else DeepUi.MUTED)
	DeepUi.gap(rail_head, 10)
	DeepUi.label(rail_head, "Drag a stone onto a socket, or click a socket, then a stone." if _bench_socket < 0 else "Choose a stone for socket %d." % (_bench_socket + 1), 13, DeepUi.MUTED if _bench_socket < 0 else DeepUi.ACCENT)
	var rail_row := DeepUi.hbox(rail_box, 14)
	rail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in range(sockets.size()):
		var skill: String = _rail_skill(record, index)
		var stone: Dictionary = DeepProfile.owned(profile, skill) if DeepProfile.fillable_socket(profile, character_key, index) and skill != "" else {}
		_enter(_socket_slot(rail_row, index, str(sockets[index]), stone, character_key), 0.05 + 0.04 * index)
	_enter(BirthstoneCard.new(rail_row, character_key), 0.05 + 0.04 * sockets.size())
	## The vault as a tray to set from, a page at a time; a set stone dropped on it comes out.
	var tray_card := DeepUi.card(content, DeepUi.LINE, 16)
	tray_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tray_box := DeepUi.vbox(tray_card, 10)
	var tray_head := DeepUi.hbox(tray_box, 8)
	var socket_color_now: String = str(sockets[_bench_socket]) if _bench_socket >= 0 else ""
	var suffix: String = ""
	if socket_color_now == "ANY":
		suffix = ": any stone fits"
	elif not socket_color_now.is_empty():
		suffix = ": stones that fit a %s socket" % socket_color_now.capitalize()
	DeepUi.section(tray_head, "chest", "From the vault" + suffix).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wire(tray_card, {}, Callable(), func(data: Dictionary) -> bool:
		return str(data.get("kind", "")) == "loadout_stone" and int(data.get("from_socket", -1)) >= 0,
		func(data: Dictionary) -> void:
			_set_socket.call_deferred(character_key, int(data.from_socket), null, "ui_back"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	tray_box.add_child(flow)
	var owned_keys: Array = profile.get("vault", {}).keys()
	owned_keys.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = color_ORDER.find(DeepStone.color(profile.vault[a]))
		var cb: int = color_ORDER.find(DeepStone.color(profile.vault[b]))
		return ca < cb if ca != cb else a < b)
	if owned_keys.is_empty():
		DeepUi.label(flow, "The vault is empty.", 13, DeepUi.DIM)
	for key in _paged(tray_head, "vault_tray", owned_keys, TRAY_PAGE):
		var stone: Dictionary = profile.vault[key]
		var chosen_key: String = str(key)
		var in_rail: bool = false
		for index in range(rail_cap):
			in_rail = in_rail or _rail_skill(record, index) == chosen_key
		var fits: bool = _bench_socket < 0 or DeepProfile.rail_refusal(profile, character_key, _bench_socket, chosen_key).is_empty()
		var tile := StoneCard.tile(flow, stone, 70)
		tile.modulate = Color(1, 1, 1, 1.0 if fits else 0.3)
		tile.mouse_default_cursor_shape = Control.CURSOR_DRAG
		if in_rail:
			var tile_content := tile.get_child(0) as Control
			tile.remove_child(tile_content)
			var tile_layer := Control.new()
			tile_layer.custom_minimum_size = tile_content.get_combined_minimum_size()
			tile.add_child(tile_layer)
			tile_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tile_layer.add_child(tile_content)
			var mark := DeepUi.icon(tile_layer, "check", 14, DeepUi.GOOD, "Already set")
			mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			mark.offset_left = -22
			mark.offset_top = 5
			mark.offset_right = -5
			mark.offset_bottom = 22
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wire(tile, {"kind": "loadout_stone", "skill": chosen_key, "from_socket": - 1}, func() -> Control: return Thumbs.GemThumb.new(stone, 64), Callable(), Callable())
		if fits and _bench_socket >= 0:
			tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			DeepUi.juice(tile, 1.06)
			var socket_index: int = _bench_socket
			## It answers the release, so a press that turns into a drag never rebuilds the
			## page under it.
			tile.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_set_socket(character_key, socket_index, chosen_key, "dice_lock"))
	_enter(tray_card, 0.1)

func _buy_socket(character_key: String) -> void:
	var bought: Dictionary = DeepEconomy.unlock_socket(profile, character_key)
	if not bool(bought.get("ok", false)):
		return
	## The purse counts the price out on its own; the socket opening is the sound.
	DeepAudio.play("unlock", {"volume": 0.8})
	profile_changed.emit()

func _rail_skill(record: Dictionary, index: int) -> String:
	## The skill of the stone a loadout sets in one socket, or "".
	var rail: Array = record.get("rail", [])
	return str(rail[index]) if index >= 0 and index < rail.size() and rail[index] is String else ""

func _set_socket(character_key: String, index: int, skill: Variant, sound: String) -> void:
	## Sets a stone (by skill) in one socket of a loadout, or takes it out with null.
	if not DeepProfile.set_rail(profile, character_key, index, skill).is_empty():
		return
	_bench_socket = -1
	if not sound.is_empty():
		DeepAudio.play(sound, {"volume": 0.7})
	profile_changed.emit()

func _socket_slot(parent: Node, index: int, socket_color: String, stone: Dictionary, character_key: String) -> PanelContainer:
	## One socket of the loadout, as a card to click, drag from and drop on; or, past the
	## sockets the lapidary has opened, a locked one, the next of them with its price.
	var locked: bool = not DeepProfile.fillable_socket(profile, character_key, index)
	var chosen: bool = index == _bench_socket
	var tone: Color = DeepUi.color(socket_color) if socket_color != "ANY" else DeepUi.LINE_HI
	var border: Color = DeepUi.LINE if locked else (DeepUi.ACCENT if chosen else Color(tone, 0.45))
	var card := DeepUi.card(parent, border, 10, Color(0.04, 0.045, 0.06, 0.8) if locked else Color(0.05, 0.06, 0.085, 0.9))
	card.custom_minimum_size = Vector2(150, 0)
	var box := DeepUi.vbox(card, 6)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_color, stone.is_empty())
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	if locked:
		card.tooltip_text = MINE_SOCKET
		ring.modulate = Color(1, 1, 1, 0.45)
		var lock := DeepUi.icon(slot, "lock", 30, DeepUi.MUTED, MINE_SOCKET)
		lock.position = Vector2(23, 23)
		DeepUi.label(box, "Any color" if socket_color == "ANY" else socket_color.capitalize(), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		## Sockets are bought in order: only the next one is for sale.
		if index == DeepProfile.open_sockets(profile, character_key):
			var price: int = DeepEconomy.socket_price(profile, character_key)
			var buy := DeepUi.icon_button(box, "lock_open", "%d gold" % price, func() -> void: _buy_socket(character_key), 13, DeepUi.ACCENT)
			buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			buy.disabled = int(profile.get("gold", 0)) < price
			buy.tooltip_text = ("Open this socket for good: it is filled from the vault before every run, in every mine." if not buy.disabled
				else "You have %d gold. This socket costs %d." % [int(profile.get("gold", 0)), price])
			DeepUi.voice(buy, "buy")
		else:
			DeepUi.label(box, "open socket %d first" % (DeepProfile.open_sockets(profile, character_key) + 1), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return card
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if chosen:
		ring.set_ready(true)
	var socket_index: int = index
	var data: Dictionary = {}
	if not stone.is_empty():
		var thumb := StoneCard.mini(slot, stone, 60, DeepStone.name(stone))
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", "")), 14, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		var trigger_row := DeepUi.hbox(box, 0)
		trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
		DiceIcons.build(trigger_row, DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, {}).cut_step)), 15, DeepUi.MUTED)
		var remove := DeepUi.icon_button(slot, "cross_out", "", func() -> void: _set_socket(character_key, socket_index, null, ""), 10, DeepUi.MUTED)
		DeepUi.voice(remove, "ui_back")
		remove.tooltip_text = "Take the stone out"
		remove.position = Vector2(66, -6)
		data = {"kind": "loadout_stone", "skill": str(stone.get("skill", "")), "from_socket": index}
	else:
		DeepUi.label(box, "Any color" if socket_color == "ANY" else socket_color.capitalize(), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "empty", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.juice(card, 1.04)
	var here: String = str(stone.get("skill", ""))
	_wire(card, data, func() -> Control: return Thumbs.GemThumb.new(stone, 64),
		func(incoming: Dictionary) -> bool:
			var skill: String = str(incoming.get("skill", ""))
			return str(incoming.get("kind", "")) == "loadout_stone" and skill != here and DeepProfile.rail_refusal(profile, character_key, socket_index, skill).is_empty(),
		func(incoming: Dictionary) -> void:
			_set_socket.call_deferred(character_key, socket_index, str(incoming.skill), "dice_lock"),
		ring)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_bench_socket = -1 if _bench_socket == socket_index else socket_index
			DeepAudio.play("ui_tap")
			_render.call_deferred())
	return card

func _wire(control: Control, data: Dictionary, preview: Callable, accepts: Callable, drop: Callable, ring: Control = null) -> void:
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

func _faces_row(parent: Node, die: Dictionary, edge: float) -> HBoxContainer:
	var row := DeepUi.hbox(parent, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tone: Color = DiceIcons.die_palette(die).body
	for f in die.get("faces", []):
		row.add_child(DiceIcons.face(edge, int(f.value), tone if str(f.kind) == "plain" else DiceIcons.face_kind_tint(str(f.kind)), str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.value), str(f.kind))))
	return row

# --- vault -----------------------------------------------------------------------------------

func _vault(content: VBoxContainer) -> void:
	var owned: int = profile.get("vault", {}).size()
	## Out of what the player may know of: a Transcendent nobody has made is not counted.
	var total: int = DeepProfile.known_skills(profile).size()
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
	_enter(head)
	## Filter by color. Seven of them and an All no longer fit beside the title, so they
	## take a line of their own rather than crowd the head off the side of the page.
	var filters := DeepUi.hbox(content, 8)
	DeepUi.spacer(filters)
	var all := DeepUi.tab_button(filters, "gem", "All", _vault_filter.is_empty(), func() -> void:
		_vault_filter = ""
		_render(), 13)
	for color in color_ORDER:
		var key: String = color
		var rainbow: bool = DeepUi.is_rainbow(color)
		var button := DeepUi.tab_button(filters, "gem", str(DeepContent.color(color).get("name", color)), _vault_filter == color, func() -> void:
			_vault_filter = key
			_render(), 13, 0, rainbow)
		if not rainbow:
			button.add_theme_color_override("icon_normal_color", DeepUi.color(color))
			button.add_theme_color_override("icon_hover_color", DeepUi.color(color).lightened(0.3))
	## The Transcendent row has a filter of its own, once the player has made one.
	if not profile.get("transcended", []).is_empty():
		var lifted := DeepUi.tab_button(filters, "spark", "Transcendent", _vault_filter == DeepContent.TRANSCENDENT, func() -> void:
			_vault_filter = DeepContent.TRANSCENDENT
			_render(), 13)
		lifted.add_theme_color_override("icon_normal_color", DeepUi.TRANSCENDENT_TONE)
		lifted.add_theme_color_override("icon_hover_color", DeepUi.TRANSCENDENT_TONE.lightened(0.3))
	_enter(filters)
	var columns := DeepUi.hbox(content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## The one scrollbar in the workshop, and it is here on purpose: see VAULT_TILE.
	scroller.set_meta("may_scroll", true)
	columns.add_child(scroller)
	var grid := GridContainer.new()
	grid.columns = VAULT_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(grid)
	var side := DeepUi.vbox(columns, 12)
	side.custom_minimum_size = Vector2(440, 0)
	_vault_side = side
	_vault_tiles = {}
	_vault_lamp(side)
	var entries: Array = []
	for entry in DeepProfile.vault_grid(profile):
		var color: String = str(DeepContent.skill(str(entry.skill)).get("color", "WHITE"))
		## A Transcendent sits in its own row, under All and its own filter, never a color's.
		var lifted: bool = DeepContent.is_transcendent(str(entry.skill))
		if _vault_filter.is_empty() or (lifted and _vault_filter == DeepContent.TRANSCENDENT) or (not lifted and color == _vault_filter):
			entries.append(entry)
	## Freshly opened, the tiles pop in on a stagger, which hides them arriving a couple of
	## rows a frame; anything else gets the whole grid at once.
	_vault_fill(grid, entries, 0, VAULT_COLUMNS * 2 if _fresh and not _headless else entries.size())

func _vault_fill(grid: GridContainer, entries: Array, from: int, per_frame: int) -> void:
	## The grid `per_frame` tiles at a time, a frame apart. All at once, sixty-odd tiles were
	## forty milliseconds in the frame the tab opened.
	if not is_instance_valid(grid) or not grid.is_inside_tree():
		return
	var upto: int = mini(entries.size(), from + maxi(1, per_frame))
	for index in range(from, upto):
		var entry: Dictionary = entries[index]
		var key: String = str(entry.skill)
		var color: String = str(DeepContent.skill(key).get("color", "WHITE"))
		var state: String = str(entry.state)
		var tile: Control
		if state == "owned":
			tile = StoneCard.tile(grid, entry.stone, VAULT_TILE)
		else:
			tile = _ghost_tile(grid, key, color, state == "seen", VAULT_TILE)
		if state in ["owned", "seen"]:
			_vault_tiles[key] = tile
			tile.set_meta("plain_style", (tile as PanelContainer).get_theme_stylebox("panel"))
			_ring_vault_tile(tile, key == _vault_pick)
			tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			DeepUi.juice(tile, 1.06)
			tile.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_pick_vault(key))
		_enter(tile, 0.015 * index)
	if upto < entries.size():
		get_tree().process_frame.connect(_vault_fill.bind(grid, entries, upto, per_frame), CONNECT_ONE_SHOT)

func _ring_vault_tile(tile: Control, picked: bool) -> void:
	var plain: StyleBox = tile.get_meta("plain_style")
	if not picked:
		tile.add_theme_stylebox_override("panel", plain)
		return
	var style: StyleBoxFlat = plain.duplicate()
	style.border_color = DeepUi.ACCENT
	style.set_border_width_all(2)
	tile.add_theme_stylebox_override("panel", style)

func _pick_vault(key: String) -> void:
	## Picking a stone changes the lamp and which tile is ringed, and nothing else, so only
	## those are redone. Rebuilding the page cost a stall per click and lost the grid's scroll.
	var tile: Variant = _vault_tiles.get(key, null)
	if not is_instance_valid(_vault_side) or not is_instance_valid(tile):
		_vault_pick = key
		_render()
		return
	var was: Variant = _vault_tiles.get(_vault_pick, null)
	if is_instance_valid(was):
		_ring_vault_tile(was, false)
	_vault_pick = key
	_ring_vault_tile(tile, true)
	## The lit stone is lifted out before the lamp is cleared away, to be set back under it.
	if is_instance_valid(_vault_stage) and _vault_stage.get_parent() != null:
		_vault_stage.get_parent().remove_child(_vault_stage)
	DeepUi.clear(_vault_side)
	_vault_lamp(_vault_side)

func _vault_lamp(side: VBoxContainer) -> void:
	## The stone under the lamp.
	var kept: Showcase = _vault_stage if is_instance_valid(_vault_stage) and not _vault_stage.is_queued_for_deletion() else null
	_vault_stage = null
	var shown: Dictionary = DeepProfile.owned(profile, _vault_pick)
	if shown.is_empty() and profile.get("seen", []).has(_vault_pick):
		if kept != null and kept.get_parent() == null:
			kept.queue_free()
		_vault_reference(side, _vault_pick)
		return
	var caption: String = ""
	if shown.is_empty() and not profile.get("records", {}).get("best", {}).is_empty():
		shown = profile.records.best.stone
		caption = "Your best stone"
	if shown.is_empty():
		if kept != null and kept.get_parent() == null:
			kept.queue_free()
		_empty(side, "chest", "Nothing kept yet", "Stones you keep from the Appraise tab live here, one per skill.")
		return
	var lamp := DeepUi.card(side, Color(DeepUi.tier_color(str(DeepStone.grade(shown).tier)), 0.5), 16)
	var lamp_box := DeepUi.vbox(lamp, 10)
	if not caption.is_empty():
		DeepUi.section(lamp_box, "star", caption)
	var stage: Showcase = kept if kept != null and kept.get_parent() == null else Showcase.new(shown, 220)
	stage.show_stone(shown)
	lamp_box.add_child(stage)
	_vault_stage = stage
	StoneCard.build(lamp_box, shown, {"picture": false, "provenance": true, "value": true, "text_width": 380})
	_enter(lamp, 0.05)

func _vault_reference(parent: Node, key: String) -> void:
	## Only the skill is remembered; there is no kept stone to model or value.
	var stone: Dictionary = DeepStone.reference_stone(key)
	var skill: Dictionary = DeepContent.skill(key)
	var color: String = DeepStone.color(stone)
	var hue: Color = DeepUi.color(color)
	var card := DeepUi.card(parent, Color(hue, 0.35), 16)
	var column := DeepUi.vbox(card, 10)
	var frame := DeepUi.center(column)
	frame.custom_minimum_size.y = 220
	DeepUi.icon(frame, GemIcons.emblem(key), 112, Color(hue, 0.65))
	DeepUi.title(column, str(skill.get("name", key)), 22, hue.lightened(0.25))
	var tags := DeepUi.hbox(column, 8)
	var rarity: String = str(skill.get("rarity", "COMMON"))
	StoneCard.rarity_tag(tags, rarity, 13)
	DeepUi.pill(tags, "eye", "Seen, not kept", DeepUi.MUTED, 13)
	var described: Dictionary = DeepPatterns.describe(skill.get("trigger", {"kind": "always"}), int(stone.cut))
	DiceIcons.build(column, described, 18, DeepUi.PAPER)
	DeepUi.effect_text(column, DeepStone.text(stone), 13, DeepUi.PAPER, true, 380)
	StoneCard.carat_lines(column, stone)
	DeepUi.wrap(column, "At one carat, Poor cut and Clear clarity. The stone you find will have its own qualities.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 380)
	_enter(card, 0.05)

func _ghost_tile(parent: Node, key: String, color: String, seen: bool, span: int = 84) -> PanelContainer:
	## A skill not kept: its emblem in grey if it has been seen, a dark mark if not. A seen
	## one can be selected for a summary; full inspection belongs to owned stones.
	var box := PanelContainer.new()
	var style := DeepUi.flat(Color(0.03, 0.035, 0.05, 0.55 if seen else 0.35), Color(DeepUi.color(color), 0.25 if seen else 0.08), 12, 8)
	style.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	var column := DeepUi.vbox(box, 4)
	var frame := DeepUi.center(column)
	frame.custom_minimum_size = Vector2(span, span)
	var skill: Dictionary = DeepContent.skill(key)
	if seen:
		var hint: String = "%s: seen, not kept.\nClick for a summary." % str(skill.get("name", key))
		DeepUi.icon(frame, GemIcons.emblem(key), int(span * 0.52), Color(DeepUi.color(color), 0.35),
			hint)
		var l := DeepUi.label(column, str(skill.get("name", key)), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = span
		l.clip_text = true
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.tooltip_text = hint
	else:
		DeepUi.icon(frame, "question", 26, Color(DeepUi.color(color), 0.18), "Not yet found")
		DeepUi.label(column, " ", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	return box

class Showcase extends Control:
	## One stone, live, under a lamp on a velvet pad, turning slowly in its light.
	var _clock: float = 0.0
	var _tone: Color
	var _view: Control
	func _init(stone: Dictionary, edge: float) -> void:
		custom_minimum_size = Vector2(edge * 1.6, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		_tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if bool(stone.get("appraised", true)) else DeepUi.color(DeepStone.color(stone))
		var view := GemView.new()
		_view = view
		var reach: float = edge * 0.8
		view.anchor_left = 0.5
		view.anchor_right = 0.5
		view.offset_left = - reach * 0.5
		view.offset_right = reach * 0.5
		view.offset_top = edge * 0.06
		view.offset_bottom = edge * 0.06 + reach
		view.set_drift(true)
		view.set_spin(0.35)
		view.inspectable = true
		view.configure(stone)
		view.enable_interaction()
		add_child(view)
	func show_stone(stone: Dictionary) -> void:
		## Another stone under the same lamp, in the same light.
		_tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if bool(stone.get("appraised", true)) else DeepUi.color(DeepStone.color(stone))
		_view.call("configure", stone)
		queue_redraw()
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
	var raw: Array = tray.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
	if raw.size() > 1:
		var whole_fee: int = 0
		for stone in raw:
			whole_fee += DeepProfile.appraisal_fee(stone)
		var afford: bool = int(profile.get("gold", 0)) >= whole_fee
		var all_button := DeepUi.icon_button(head, "loupe", "Appraise all %d · %d gold" % [raw.size(), whole_fee], func() -> void:
			var best: Dictionary = {}
			var shattered: Array = []
			for stone in raw:
				if not DeepProfile.appraise(profile, stone):
					continue
				if DeepStone.is_fragile(stone):
					shattered.append(stone)
					continue
				if best.is_empty() or DeepStone.value(stone) > DeepStone.value(best):
					best = stone
			## One ceremony for the whole tray, for the best thing in it.
			if not best.is_empty():
				DeepAudio.reveal_stone(best)
			## A first stone of its skill is never sold, but whether it is kept or turned in is
			## asked: the table opens on the first of them, marked new.
			var fresh: Array = profile.get("tray", []).filter(func(s: Dictionary) -> bool: return DeepProfile.first_of_skill(profile, s))
			if not fresh.is_empty():
				_appraise_pick = str(fresh[0].id)
				DeepAudio.play("unlock", {"delay": 0.4, "volume": 0.8})
			if not shattered.is_empty():
				_appraise_pick = ""
				_cheer = {"text": "%s shattered: Fragile" % DeepUi.plural(shattered.size(), "stone"), "color": DeepUi.BAD}
				Appraisal.open(shattered[0], {"shatter": true, "shattered_count": shattered.size()})
			profile_changed.emit(), 14, DeepUi.INFO)
		all_button.disabled = not afford
		all_button.tooltip_text = "Every rough stone on the tray, under the loupe at once." if afford else "You have %d gold. The whole tray costs %d." % [int(profile.get("gold", 0)), whole_fee]
	_enter(head)
	var columns := DeepUi.hbox(content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## The tray down the left, two abreast and a page at a time.
	var strip := DeepUi.card(columns, DeepUi.LINE, 12)
	var strip_box := DeepUi.vbox(strip, 8)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	strip_box.add_child(grid)
	DeepUi.spacer(strip_box, false)
	for stone in _paged(strip_box, "tray", tray, APPRAISE_PAGE):
		var id: String = str(stone.id)
		var tile := StoneCard.tile(grid, stone, 74)
		if id == _appraise_pick:
			var style: StyleBoxFlat = tile.get_theme_stylebox("panel").duplicate()
			style.border_color = DeepUi.ACCENT
			style.set_border_width_all(2)
			tile.add_theme_stylebox_override("panel", style)
		## A first stone of its skill wears a star; one a commission wants, a flag.
		if DeepProfile.first_of_skill(profile, stone):
			_tile_mark(tile, "star", DeepUi.ACCENT_HI, "New skill: the first %s you have found" % str(DeepStone.skill_of(stone).get("name", "")), true)
		if not DeepEconomy.commission_for(profile, stone).is_empty():
			_tile_mark(tile, "flag", DeepUi.GOOD, "A commission wants this stone", false)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(tile, 1.05)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_appraise_pick = id
				_render())
	_enter(strip, 0.05)
	## The loupe table: a raw stone sits in its rock under the lens with the one button; a
	## known one sits beside the stone of its skill already kept, line against line, and the
	## choice is which of the two to keep.
	var table := DeepUi.card(columns, Color(DeepUi.ACCENT, 0.35), 18)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var appraised: bool = bool(pick.get("appraised", false))
	if not appraised:
		var table_box := DeepUi.vbox(table, 12)
		table_box.alignment = BoxContainer.ALIGNMENT_CENTER
		var lens := LoupeTable.new(pick, 250)
		lens.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		table_box.add_child(lens)
		DeepUi.title(table_box, DeepStone.raw_name(pick), 24, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(table_box, "Still raw. You can see its color and rough size. Appraise it to learn the rest.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var facts := DeepUi.hbox(table_box, 14)
		facts.alignment = BoxContainer.ALIGNMENT_CENTER
		StoneCard.size_stat(facts, pick, 14)
		## The whole of the tray is this one question: pay to find out, or take the little a
		## buyer gives for a stone nobody has read and never learn what was in it.
		var fee: int = DeepProfile.appraisal_fee(pick)
		var rough: int = DeepStone.rough_value(pick)
		var purse: int = int(profile.get("gold", 0))
		DeepUi.stat(facts, "coin", "%d gold in the purse" % purse, DeepUi.ACCENT if purse >= fee else DeepUi.BAD, 14,
			"Appraising costs gold. Selling a stone raw is the cheap way to clear the tray.")
		var choices := DeepUi.hbox(table_box, 14)
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		var go := DeepUi.primary(choices, "loupe", "Appraise · %d gold" % fee, func() -> void: _appraise_stone(pick), 20, DeepUi.INFO)
		go.custom_minimum_size = Vector2(250, 52)
		go.disabled = purse < fee
		go.tooltip_text = "Put it under the loupe and learn what it is." if purse >= fee else "You have %d gold. This one costs %d to read." % [purse, fee]
		if purse >= fee:
			DeepUi.breathe(go, 0.8, 1.6)
		var off := DeepUi.icon_button(choices, "coin", "Sell rough · +%d gold" % rough, func() -> void: _sell_rough(pick), 16, DeepUi.ACCENT)
		off.custom_minimum_size = Vector2(220, 52)
		off.tooltip_text = "Sells for what its color and size class are worth. You never find out what it was."
	else:
		var owned: Dictionary = DeepProfile.owned(profile, str(pick.skill))
		var comparing: bool = not owned.is_empty()
		## With a rival in the vault the table is a balance: the found stone on one side, the
		## kept one on the other, the same size and lit the same way, and the sheet's two
		## columns between them lining up under each. Alone, the stone takes the left and the
		## sheet has the rest of the table.
		var table_row := DeepUi.hbox(table, 20 if comparing else 24)
		table_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_lens_column(table_row, pick, 165.0 if comparing else 230.0)
		var right := DeepUi.vbox(table_row, 14)
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		var wanted: Dictionary = DeepEconomy.commission_for(profile, pick)
		var skill_name: String = str(DeepStone.skill_of(pick).get("name", "stone"))
		if comparing:
			DeepUi.stat(right, "chest", "Only one of each skill can be kept. Which %s goes in the vault?" % skill_name, DeepUi.INFO, 14)
		else:
			## The first of its skill: a moment of its own, and never a sale.
			var fanfare := DeepUi.hbox(right, 10)
			var star := DeepUi.pill(fanfare, "star", "New skill", DeepUi.ACCENT_HI, 15)
			if _fresh and not _headless:
				DeepUi.breathe(star, 0.7, 1.4)
			DeepUi.wrap(fanfare, "Your first %s. A first stone is never sold: it lights up its place in the vault%s." % [skill_name, ", or it can be turned in for a commission" if not wanted.is_empty() else ""],
				14, DeepUi.GOOD, HORIZONTAL_ALIGNMENT_LEFT, 460)
		if not wanted.is_empty():
			DeepUi.stat(right, "flag", "A commission wants this %s: %d gold" % [skill_name, DeepEconomy.payout(wanted, pick)], DeepUi.GOOD, 14)
		var sheet := Appraisal.Sheet.new(pick, owned, {"skill_text": true, "owned_picture": not comparing})
		right.add_child(sheet)
		sheet.show_all()
		Appraisal.choices(right, _tray_actions(pick))
		if comparing:
			_lens_column(table_row, owned, 165.0)
	_enter(table, 0.1)

func _tile_mark(tile: PanelContainer, glyph: String, tone: Color, tip: String, left: bool) -> void:
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
	var mark := DeepUi.icon(layer, glyph, 16, tone, tip)
	mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if left else Control.PRESET_TOP_RIGHT)
	mark.offset_left = 4 if left else -22
	mark.offset_right = 20 if left else -6
	mark.offset_top = 4
	mark.offset_bottom = 20
	mark.mouse_filter = Control.MOUSE_FILTER_PASS

func _lens_column(parent: Node, stone: Dictionary, edge: float) -> VBoxContainer:
	## One stone on the loupe table with its full name under it, at whatever size the table
	## has room for. Both sides of a comparison are built by this, so neither can drift.
	var column := DeepUi.vbox(parent, 8)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lens := LoupeTable.new(stone, edge)
	column.add_child(lens)
	var named := DeepUi.wrap(column, DeepStone.name(stone), 14, DeepUi.tier_color(str(DeepStone.grade(stone).tier)), HORIZONTAL_ALIGNMENT_CENTER)
	named.custom_minimum_size.x = lens.custom_minimum_size.x
	return column

func _sell_rough(pick: Dictionary) -> void:
	## Off the tray unread, for what a buyer gives on a size class. The vault learns nothing
	## from it, because nobody ever found out what it was.
	var raw: Dictionary = pick.duplicate(true)
	var result: Dictionary = DeepProfile.decide_tray(profile, str(pick.id), false)
	_appraise_pick = ""
	if bool(result.get("shattered", false)):
		_cheer = {"text": "Shattered: Fragile", "color": DeepUi.BAD}
		Appraisal.open(raw, {"shatter": true})
	else:
		_cheer = {"text": "Sold rough, +%d gold" % int(result.get("paid", 0)), "color": DeepUi.ACCENT}
	profile_changed.emit()

func _appraise_stone(pick: Dictionary) -> void:
	## The loupe goes on, and it is paid for. The stone is known from the moment the fee is
	## taken, so skipping the ceremony, closing the window or quitting half-way through never
	## loses what was bought.
	var raw: Dictionary = pick.duplicate(true)
	if not DeepProfile.appraise(profile, pick):
		return
	if DeepStone.is_fragile(pick):
		_appraise_pick = ""
		_cheer = {"text": "Shattered: Fragile", "color": DeepUi.BAD}
		Appraisal.open(raw, {"shatter": true})
		profile_changed.emit()
		return
	var owned: Dictionary = DeepProfile.owned(profile, str(pick.skill))
	var actions: Array = _tray_actions(pick)
	var opts: Dictionary = {}
	if owned.is_empty():
		## Nothing to weigh it against: the first of its skill. The ceremony ends on its own
		## fanfare, and the choice is keeping it or, if a commission wants it, turning it in.
		opts.new_skill = true
	else:
		## One of its skill is already in the vault, so the reading is only half the question.
		## Rather than deciding it off a column of figures under the lamp, the ceremony hands
		## straight over to the loupe table, where both stones stand at full size and turn.
		owned = {}
		actions = [ {"label": "Weigh them against each other", "glyph": "scales", "tone": DeepUi.INFO, "primary": true, "dismiss": true,
			"caption": "You already keep one of this skill"}]
	opts.owned = owned
	opts.actions = actions
	Appraisal.open(raw, opts)
	profile_changed.emit()

func _tray_actions(pick: Dictionary) -> Array:
	## What can be done with a known stone on the tray. With one of its skill already kept the
	## choice is which of the two to keep; otherwise it is keep or sell. At the end of an
	## appraisal, Escape leaves it on the tray; there is no button for putting it off.
	var id: String = str(pick.id)
	if DeepStone.is_fragile(pick):
		return []
	var owned: Dictionary = DeepProfile.owned(profile, str(pick.skill))
	var keep := func() -> void:
		DeepProfile.decide_tray(profile, id, true)
		_appraise_pick = ""
		_cheer = {"text": "Kept in the vault", "color": DeepUi.GOOD}
		profile_changed.emit()
	var sell := func() -> void:
		DeepProfile.decide_tray(profile, id, false)
		_appraise_pick = ""
		profile_changed.emit()
	var out: Array = []
	if owned.is_empty():
		## The first stone of a skill is never sold: it goes into the vault, or to a commission.
		out.append({"label": "Into the vault", "glyph": "chest", "tone": DeepUi.GOOD,
			"caption": "The first of its skill is never sold", "call": keep, "sound": "keep"})
	else:
		out.append({"label": "Keep the new one", "glyph": "chest", "tone": DeepUi.GOOD, "caption": "Sells your old one for %d gold" % DeepStone.value(owned), "call": keep, "sound": "keep"})
		out.append({"label": "Keep your old one", "glyph": "coin", "tone": DeepUi.ACCENT, "caption": "Sells this one for %d gold" % DeepStone.value(pick), "call": sell, "sound": "sell"})
	var wanted: Dictionary = DeepEconomy.commission_for(profile, pick)
	if not wanted.is_empty():
		var paid: int = DeepEconomy.payout(wanted, pick)
		var commission_id: String = str(wanted.id)
		var turn_in := func() -> void:
			if bool(DeepEconomy.turn_in(profile, id, commission_id).get("ok", false)):
				_appraise_pick = ""
				profile_changed.emit()
		out.append({"label": "Turn it in", "glyph": "flag", "tone": DeepUi.INFO, "caption": "A commission pays %d gold for it" % paid, "sound": "sell", "call": turn_in})
	return out

class LoupeTable extends Control:
	## The stone under the jeweller's lens: live, lit from above, ringed by the loupe's rim.
	## A raw one sits there in its rock; the appraisal itself is its own sheet.
	var stone: Dictionary
	var _view: Control
	var _clock: float = 0.0
	var _tone: Color
	func _init(new_stone: Dictionary, edge: float) -> void:
		stone = new_stone
		custom_minimum_size = Vector2(edge * 1.5, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		var appraised: bool = bool(stone.get("appraised", false))
		_tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
		_view = GemView.new()
		var reach: float = edge * 0.78
		_view.anchor_left = 0.5
		_view.anchor_right = 0.5
		_view.anchor_top = 0.5
		_view.anchor_bottom = 0.5
		_view.offset_left = - reach * 0.5
		_view.offset_right = reach * 0.5
		_view.offset_top = - reach * 0.5
		_view.offset_bottom = reach * 0.5
		_view.set_drift(true)
		_view.set_spin(0.4)
		_view.inspectable = true
		_view.configure(stone)
		add_child(_view)
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var centre := size * 0.5
		var radius: float = size.y * 0.47
		var pulse: float = 1.0 + 0.03 * sin(_clock * 2.0)
		var halo := Vector2(radius, radius) * 3.0 * pulse
		draw_texture_rect(glow, Rect2(centre - halo * 0.5, halo), false, Color(_tone, 0.25))
		draw_circle(centre, radius, Color(0.02, 0.025, 0.035, 0.85))
		draw_arc(centre, radius, 0, TAU, 72, Color("b8a47a"), 5.0, true)
		draw_arc(centre, radius - 6.0, 0, TAU, 72, Color("5a4a30"), 2.0, true)
		for i in range(24):
			var angle: float = TAU * float(i) / 24.0 + _clock * 0.1
			draw_line(centre + Vector2.from_angle(angle) * (radius + 3.0), centre + Vector2.from_angle(angle) * (radius + 9.0), Color("b8a47a", 0.8), 1.5, true)
		## A glint travelling round the glass.
		var sweep: float = fmod(_clock * 0.4, 1.0) * TAU
		draw_arc(centre, radius - 12.0, sweep, sweep + 0.5, 16, Color(1, 1, 1, 0.25), 3.0, true)

# --- shop ------------------------------------------------------------------------------------

func _shop(content: VBoxContainer) -> void:
	## Two views, each a page of its own: the day's Geodes, and the contract bench.
	content.add_theme_constant_override("separation", 14)
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "geode", 28, DeepUi.ACCENT)
	DeepUi.title(head, "The shop", 30, DeepUi.PAPER)
	DeepUi.gap(head, 16)
	for entry in [["geodes", "geode", "Geodes"], ["contracts", "contract", "Contracts"]]:
		var key: String = str(entry[0])
		DeepUi.tab_button(head, str(entry[1]), str(entry[2]), _shop_view == key, func() -> void:
			_shop_view = key
			_contract_sure = false
			_render(), 14)
	DeepUi.spacer(head)
	var records: Dictionary = profile.get("records", {})
	if _shop_view == "contracts":
		DeepUi.stat(head, "contract", "%s signed" % DeepUi.plural(int(records.get("contracts", 0)), "contract"), DeepUi.ACCENT, 13)
	else:
		var left: int = DeepEconomy.seconds_to_tomorrow()
		DeepUi.stat(head, "hourglass", "New Geodes in %dh %02dm" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 13, "The shelf is stocked afresh every day at midnight UTC.")
		DeepUi.stat(head, "geode", "%d cracked" % int(records.get("geodes", 0)), DeepUi.ACCENT, 13)
	_enter(head)
	if _shop_view == "contracts":
		_contracts(content)
	else:
		_geodes(content)

func _geodes(content: VBoxContainer) -> void:
	## The shelf: three Geodes, each with everything it could hold and the odds of it.
	var shelf: Array = DeepEconomy.shelf(profile)
	DeepUi.wrap(content, "Three Geodes a day, each holding one stone, heavier and better cut than the rock usually gives. What is inside was decided when the shelf was stocked; every card shows its odds. Cracked, the stone goes to the Appraise tray, already read.",
		14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 1200)
	if shelf.is_empty():
		_empty(content, "geode", "The shelf is bare", "Geodes come from the mines you have opened.")
		return
	var row := DeepUi.hbox(content, 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var index: int = 0
	for geode in shelf:
		var card := _geode_card(row, geode)
		_enter(card, 0.05 + 0.07 * index)
		index += 1

func _geode_card(parent: Node, geode: Dictionary) -> PanelContainer:
	var tone: Color = Geode.theme_tone(geode)
	var bought: bool = bool(geode.get("bought", false))
	var price: int = int(geode.get("price", 0))
	var purse: int = int(profile.get("gold", 0))
	var odds: Dictionary = DeepEconomy.geode_odds(geode)
	var card := DeepUi.card(parent, Color(tone, 0.2 if bought else 0.5), 16, DeepUi.GLASS if not bought else Color(0.05, 0.06, 0.085, 0.8))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(card, 8)
	## What kind of Geode it is, in small capitals; the week's set says how long it has left.
	var tag := DeepUi.hbox(box, 8)
	var kinds: Dictionary = {"mine": "A mine's Geode", "color": "A color's Geode", "featured": "The week's Geode"}
	DeepUi.heading(tag, str(kinds.get(str(geode.get("kind", "mine")), "A Geode")), 12, tone if not bought else DeepUi.DIM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if str(geode.get("kind", "")) == "featured":
		var days: int = DeepEconomy.featured_days_left(DeepEconomy.today())
		DeepUi.stat(tag, "hourglass", DeepUi.plural(days, "day") + " left", DeepUi.MUTED, 12, "A new set takes the week's place on the shelf every seven days.")
	## The rock takes whatever height the card has to spare. Every card is laid out alike
	## below it, so the three rocks come out the same size.
	var art := Geode.Art.new(geode, tone)
	art.custom_minimum_size = Vector2(0, 170)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.open = bought
	box.add_child(art)
	DeepUi.title(box, Geode.geode_name(geode), 25, tone.lightened(0.2) if not bought else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.label(box, Geode.geode_line(geode), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	## What sets a Geode's stone above the rock's, as marks.
	var facts := DeepUi.hbox(box, 8)
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	var carats: Array = odds.get("carat", [1, 1])
	DeepUi.pill(facts, "carat", "%d to %d carats" % [int(carats[0]), int(carats[1])], DeepUi.ACCENT, 12,
		"Never lighter than this rock's usual best, and now and then heavier than the rock itself ever gives up (it stops at %d)." % int(odds.get("cap", carats[1])))
	DeepUi.pill(facts, "cut", "Kinder cut", DeepUi.INFO, 12, "Cut and clarity are rolled with more luck behind them than a stone found in the rock.")
	if float(odds.get("opal", 0.0)) > 0.0:
		DeepUi.pill(facts, "spark", "%s opal" % Geode.percent(float(odds.opal)), DeepUi.OPAL_TONE, 12, "Any Geode might hold one of the opals instead: the rarest stones there are.", true)
	## What it can hold: the share of each rarity, and every skill it might be.
	DeepUi.section(box, "gem", "What it can hold", DeepUi.MUTED, 12)
	var rarity_parts: Array = []
	var shares: Dictionary = Geode.rarity_shares(geode)
	for rarity in Geode.RARITIES:
		if float(shares.get(rarity, 0.0)) > 0.0:
			rarity_parts.append({"label": "Opal" if rarity == "MYTHIC" else rarity.capitalize(), "share": float(shares[rarity]), "color": Geode.rarity_tone(rarity), "rainbow": rarity == "MYTHIC"})
	box.add_child(OddsBar.new(rarity_parts))
	var marks: Array = []
	for entry in odds.get("skills", []):
		var key: String = str(entry[0])
		var def: Dictionary = DeepContent.skill(key)
		var known: bool = profile.get("vault", {}).has(key) or profile.get("seen", []).has(key)
		marks.append({"glyph": GemIcons.emblem(key), "color": DeepUi.color(str(def.get("color", ""))), "known": known, "name": str(def.get("name", key)),
			"tip": "%s · %s · %s%s" % [str(def.get("name", key)), str(def.get("rarity", "COMMON")).capitalize(), Geode.percent(float(entry[1])), "" if known else "\nNever found yet"]})
	box.add_child(MarkRows.new(marks))
	## How its stones grade: measured, not written down.
	DeepUi.section(box, "star", "How its stones grade", DeepUi.MUTED, 12)
	var tier_parts: Array = []
	for tier in DeepStone.TIERS:
		var share: float = float(odds.get("tiers", {}).get(tier, 0.0))
		if share > 0.0:
			tier_parts.append({"label": str(DeepStone.TIER_NAMES.get(tier, tier)), "share": share, "color": DeepUi.tier_color(tier)})
	box.add_child(OddsBar.new(tier_parts))
	var foot := DeepUi.hbox(box, 10)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	if bought:
		## Open: what it held, and the shelf restocks tomorrow.
		var held: Dictionary = geode.get("stone", {}).duplicate(true)
		held.appraised = true
		StoneCard.mini(foot, held, 46)
		var said := DeepUi.vbox(foot, 0)
		DeepUi.label(said, "Opened today", 12, DeepUi.DIM)
		DeepUi.label(said, DeepStone.name(held), 14, DeepUi.tier_color(str(DeepStone.grade(held).tier)))
		return card
	var crack := DeepUi.primary(foot, "geode", "Crack it open · %d gold" % price, func() -> void: _crack_geode(geode), 17)
	crack.custom_minimum_size = Vector2(300, 52)
	DeepUi.voice(crack, "reel_lever")
	crack.disabled = purse < price
	crack.tooltip_text = "Opens it here and now: the drum spins, and the stone goes to your tray, read." if purse >= price else "You have %d gold. This Geode costs %d." % [purse, price]
	## The shell answers the pointer: the seam brightens while the button is under it.
	crack.mouse_entered.connect(func() -> void:
		if not crack.disabled:
			art.create_tween().tween_property(art, "hover", 1.0, 0.2))
	crack.mouse_exited.connect(func() -> void: art.create_tween().tween_property(art, "hover", 0.0, 0.3))
	return card

func _crack_geode(geode: Dictionary) -> void:
	## Pays for a Geode and cracks it: the stone is on the tray before the drum starts.
	var opened: Dictionary = DeepEconomy.open_geode(profile, str(geode.get("id", "")))
	if not bool(opened.get("ok", false)):
		return
	var made: Dictionary = opened.stone
	var opts: Dictionary = {"actions": _found_actions(made), "new_skill": DeepProfile.first_of_skill(profile, made)}
	var wanted: Dictionary = DeepEconomy.commission_for(profile, made)
	if not wanted.is_empty():
		opts.wanted = "A commission wants this %s: %d gold" % [DeepUi.skill_name(made), DeepEconomy.payout(wanted, made)]
	profile_changed.emit()
	Geode.open(opened.geode, made, opts)

func _found_actions(made: Dictionary) -> Array:
	## What can be done with a stone out of a Geode or a contract, the moment it is read: the
	## tray's own choices, or for a skill already kept, the loupe table to weigh the two.
	var id: String = str(made.get("id", ""))
	var out: Array = []
	if DeepProfile.owned(profile, str(made.get("skill", ""))).is_empty():
		out = _tray_actions(made)
	else:
		out.append({"label": "Weigh it against yours", "glyph": "scales", "tone": DeepUi.INFO, "caption": "You already keep one of this skill",
			"call": func() -> void:
				_appraise_pick = id
				open("appraise")})
		for action in _tray_actions(made):
			if str(action.get("label", "")) == "Turn it in":
				out.append(action)
	out.append({"label": "Back to the shop", "glyph": "geode", "primary": false, "dismiss": true, "caption": "It waits on the tray",
		"call": func() -> void: open("shop")})
	return out

func _contracts(content: VBoxContainer) -> void:
	## The contract bench: five stones of one grade in, one of the next grade out. The bench
	## down the left, its five places running down to the one they make and what that one
	## could be; the stones it could take on the right.
	_contract = _contract.filter(func(ref: Variant) -> bool: return not DeepEconomy.contract_input(profile, str(ref)).is_empty())
	var preview: Dictionary = DeepEconomy.contract_preview(profile, _contract)
	if not bool(preview.ok):
		## A bench left holding stones of two grades (the tray changed under it) starts again.
		_contract = []
		preview = DeepEconomy.contract_preview(profile, _contract)
	var columns := DeepUi.hbox(content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tier: String = str(preview.get("tier", ""))
	var next: String = str(preview.get("next", ""))
	var tone: Color = DeepUi.tier_color(next) if not next.is_empty() else DeepUi.ACCENT
	var bench := DeepUi.card(columns, Color(tone, 0.45), 18)
	bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(bench, 10)
	## The promise: this grade in, the next one out.
	var promise := DeepUi.hbox(box, 14)
	promise.alignment = BoxContainer.ALIGNMENT_CENTER
	if tier.is_empty():
		DeepUi.pill(promise, "gem", "Five of one grade", DeepUi.MUTED, 16)
		DeepUi.icon(promise, "next", 26, DeepUi.DIM)
		DeepUi.pill(promise, "star", "One of the next", DeepUi.MUTED, 16)
	else:
		DeepUi.pill(promise, "gem", "5 × %s" % str(DeepStone.TIER_NAMES.get(tier, tier)), DeepUi.tier_color(tier), 16)
		DeepUi.icon(promise, "next", 26, tone)
		DeepUi.pill(promise, "star", str(DeepStone.TIER_NAMES.get(next, next)), tone, 16)
	DeepUi.wrap(box, "Its color is drawn from theirs, it weighs their average, and it is cut from the deepest of their mines' rock, with a grade one step up.",
		13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER).custom_minimum_size.x = 700
	var slots := DeepUi.hbox(box, 14)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	var stones: Array = preview.get("stones", [])
	for index in range(DeepEconomy.contract_size()):
		_contract_slot(slots, index, stones[index] if index < stones.size() else {})
	## The five places' lines run down to the one they make.
	var signable: bool = bool(preview.get("ready", false))
	var flow := Funnel.new(stones.size(), DeepEconomy.contract_size(), DeepUi.tier_color(tier) if not tier.is_empty() else DeepUi.DIM, signable, CONTRACT_SLOT.x + 14.0)
	flow.custom_minimum_size = Vector2(0, 54)
	box.add_child(flow)
	DeepUi.center(box).add_child(Outcome.new(tone if not next.is_empty() else DeepUi.DIM, float(stones.size()) / float(DeepEconomy.contract_size()), signable))
	_contract_forecast(box, preview)
	DeepUi.spacer(box, false)
	## The way to sign it, and why not yet.
	if not preview.get("vault", []).is_empty():
		var names: Array = preview.vault.map(func(k: Variant) -> String: return str(DeepContent.skill(str(k)).get("name", k)))
		DeepUi.stat(box, "chest", "From your vault: %s. Signed, %s no longer kept." % [", ".join(names), "it is" if names.size() == 1 else "they are"], DeepUi.BAD, 13).alignment = BoxContainer.ALIGNMENT_CENTER
	var sign_row := DeepUi.hbox(box, 12)
	sign_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var giving_up: bool = not preview.get("vault", []).is_empty()
	var words: String = "Sign the contract"
	if bool(preview.get("ready", false)):
		words = ("Sign it, vault stones and all · %d gold" if giving_up and _contract_sure else "Sign the contract · %d gold") % int(preview.fee)
	var sign := DeepUi.primary(sign_row, "contract", words, func() -> void:
		if giving_up and not _contract_sure:
			_contract_sure = true
			DeepAudio.play("ui_deny", {"volume": 0.6})
			_render()
			return
		_sign_contract(), 17, DeepUi.BAD if giving_up and _contract_sure else tone)
	sign.custom_minimum_size = Vector2(320, 52)
	DeepUi.voice(sign, "ui_tap" if giving_up and not _contract_sure else "contract_seal")
	sign.disabled = not bool(preview.get("ready", false))
	if bool(preview.get("ready", false)) and not sign.disabled:
		DeepUi.breathe(sign, 0.82, 1.8)
	var reason: String = str(preview.get("reason", ""))
	if not reason.is_empty():
		DeepUi.label(box, reason, 13, DeepUi.BAD if not bool(preview.get("feasible", true)) else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	elif giving_up and not _contract_sure:
		DeepUi.label(box, "Signing gives up stones from your vault: it asks twice.", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(bench, 0.05)
	_contract_picker(columns, preview)

func _contract_slot(parent: Node, index: int, stone: Dictionary) -> void:
	## One place on the bench: empty, or a stone that a click takes back off.
	var empty: bool = stone.is_empty()
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if not empty else DeepUi.LINE
	var slot := DeepUi.card(parent, Color(tone, 0.6) if not empty else DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.9) if not empty else Color(0.03, 0.035, 0.05, 0.6))
	slot.custom_minimum_size = CONTRACT_SLOT
	var box := DeepUi.vbox(slot, 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(96, 96)
	stand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stand)
	var ring := BattleScreen.SocketRing.new("ANY", empty)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stand.add_child(ring)
	if empty:
		var plus := DeepUi.icon(stand, "gem", 34, Color(DeepUi.DIM, 0.6))
		plus.position = Vector2(31, 31)
		DeepUi.label(box, "Stone %d" % (index + 1), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "pick from the right", 12, Color(DeepUi.DIM, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var thumb := StoneCard.mini(stand, stone, 80, DeepStone.name(stone))
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	thumb.mouse_filter = Control.MOUSE_FILTER_PASS
	DeepUi.fit_label(box, DeepUi.skill_name(stone), 14, DeepUi.PAPER, 130)
	var marks := DeepUi.hbox(box, 6)
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.stat(marks, "carat", str(int(stone.get("carat", 1))), DeepUi.ACCENT, 12, "%d carats" % int(stone.get("carat", 1)))
	var ref: String = str(_contract[index]) if index < _contract.size() else ""
	if ref.begins_with("v:"):
		DeepUi.icon(marks, "chest", 15, DeepUi.BAD, "From your vault")
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.tooltip_text = "%s\nClick to take it back off the bench" % DeepStone.name(stone)
	DeepUi.juice(slot, 1.04)
	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_contract.erase(ref)
			_contract_sure = false
			DeepAudio.play("die_drop", {"volume": 0.7})
			_render.call_deferred())

func _contract_forecast(box: VBoxContainer, preview: Dictionary) -> void:
	## What the contract would make, under the place it comes out: its grade, weight and rock on
	## one line, then the odds of each color and every skill it might be, with the odds of each.
	## Before the first stone, how contracts climb.
	var line := DeepUi.hbox(box, 22)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	var next: String = str(preview.get("next", ""))
	if next.is_empty():
		DeepUi.label(line, "Five Rough make a Fine, five Fine a Precious, five Precious an Exquisite, and five Exquisite a Peerless.", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	DeepUi.stat(line, "star", "A %s stone" % str(DeepStone.TIER_NAMES.get(next, next)), DeepUi.tier_color(next), 15, "Its Cut, Clarity and inclusions are rolled until its grade lands in this tier.")
	DeepUi.stat(line, "carat", "%d carats" % int(preview.get("carat", 1)), DeepUi.ACCENT, 15, "The average of the stones on the bench, never past the cap of the rock it is cut from.")
	var mine_key: String = str(preview.get("mine", ""))
	var palette: String = str(DeepContent.mine(mine_key).get("palette", ""))
	DeepUi.stat(line, "pick", "%s's rock" % DeepContent.mine_name(mine_key), Color(palette).lightened(0.2) if not palette.is_empty() else DeepUi.PAPER, 15,
		"The deepest mine any of the stones came from. The new one's skill is one that rock can hold.")
	var row := DeepUi.hbox(box, 26)
	var colors_box := DeepUi.vbox(row, 6)
	colors_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colors_box.size_flags_stretch_ratio = 0.8
	DeepUi.section(colors_box, "prism", "Its color", DeepUi.MUTED, 12)
	var parts: Array = []
	var colors: Dictionary = preview.get("colors", {})
	for key in DeepContent.SKILL_COLORS:
		if float(colors.get(key, 0.0)) > 0.0:
			parts.append({"label": str(DeepContent.color(key).get("name", key)), "share": float(colors[key]), "color": DeepUi.color(key)})
	if parts.is_empty():
		DeepUi.wrap(colors_box, "No color can make the grade at this weight.", 13, DeepUi.BAD)
	else:
		colors_box.add_child(OddsBar.new(parts))
	var can := DeepUi.vbox(row, 6)
	can.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.section(can, "gem", "It could become", DeepUi.MUTED, 12)
	var marks: Array = []
	for entry in DeepEconomy.contract_odds(preview):
		var key: String = str(entry[0])
		var def: Dictionary = DeepContent.skill(key)
		var known: bool = profile.get("vault", {}).has(key) or profile.get("seen", []).has(key)
		marks.append({"glyph": GemIcons.emblem(key), "color": DeepUi.color(str(def.get("color", ""))), "known": known, "name": str(def.get("name", key)),
			"tip": "%s · %s · %s%s" % [str(def.get("name", key)), str(def.get("rarity", "COMMON")).capitalize(), Geode.percent(float(entry[1])), "" if known else "\nNever found yet"]})
	if marks.is_empty():
		DeepUi.label(can, "Nothing, at this weight.", 13, DeepUi.DIM)
	else:
		can.add_child(MarkRows.new(marks))

func _contract_picker(columns: Node, preview: Dictionary) -> void:
	## The stones that could go on the bench, a page at a time: the tray's read stones and the
	## vault's. Once the first is on, only stones of its grade can follow.
	var picker := DeepUi.card(columns, DeepUi.LINE, 14)
	picker.custom_minimum_size.x = 540
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(picker, 10)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "chest", "Your stones").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [["all", "All"], ["tray", "Tray"], ["vault", "Vault"]]:
		var key: String = str(entry[0])
		DeepUi.tab_button(head, {"all": "gem", "tray": "bag", "vault": "chest"}[key], str(entry[1]), _contract_from == key, func() -> void:
			_contract_from = key
			_pages["contract"] = 0
			_render(), 13)
	var everything: Array = DeepEconomy.contract_stones(profile)
	var listed: Array = everything.filter(func(e: Dictionary) -> bool:
		return _contract_from == "all" or (_contract_from == "vault") == bool(e.vault))
	var tier: String = str(preview.get("tier", ""))
	var hint: String = "Pick five stones of one grade; the first sets the grade." if tier.is_empty() else "Only %s stones can join these." % str(DeepStone.TIER_NAMES.get(tier, tier))
	DeepUi.label(box, hint, 13, DeepUi.MUTED)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	if listed.is_empty():
		DeepUi.label(grid, "Nothing here can go into a contract yet.", 13, DeepUi.DIM)
	var full: bool = _contract.size() >= DeepEconomy.contract_size()
	for entry in _paged(box, "contract", listed, CONTRACT_PAGE):
		var stone: Dictionary = entry.stone
		var ref: String = str(entry.ref)
		var placed: bool = _contract.has(ref)
		var fits: bool = tier.is_empty() or str(DeepStone.grade(stone).tier) == tier
		var tile := StoneCard.tile(grid, stone, 72)
		if bool(entry.vault):
			_tile_mark(tile, "chest", DeepUi.INFO, "In your vault: put in a contract, its skill is no longer kept", true)
		if placed:
			_tile_mark(tile, "check", DeepUi.GOOD, "On the bench", false)
			tile.modulate = Color(1, 1, 1, 0.45)
			continue
		if not fits or full:
			tile.modulate = Color(1, 1, 1, 0.28)
			tile.tooltip_text = ("Not %s: a contract takes stones of one grade" % str(DeepStone.TIER_NAMES.get(tier, tier))) if not fits else "The bench is full"
			continue
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(tile, 1.06)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_contract.append(ref)
				_contract_sure = false
				DeepAudio.play("die_pick", {"volume": 0.7})
				_render.call_deferred())
	DeepUi.spacer(box, false)
	DeepUi.wrap(box, "Raw stones need reading first. Birthstones, opals, fragile stones and Peerless stones cannot go in.", 12, DeepUi.DIM)
	if not _contract.is_empty():
		var clear := DeepUi.icon_button(box, "cross_out", "Clear the bench", func() -> void:
			_contract = []
			_contract_sure = false
			_render(), 13, DeepUi.MUTED)
		clear.size_flags_horizontal = Control.SIZE_SHRINK_END
	_enter(picker, 0.1)

func _sign_contract() -> void:
	## Signs the bench's contract: the fee and the stones are gone, the new stone is on the
	## tray, and the bench plays the five going in and the one coming out.
	var signed: Dictionary = DeepEconomy.sign_contract(profile, _contract)
	if not bool(signed.get("ok", false)):
		return
	_contract = []
	_contract_sure = false
	var made: Dictionary = signed.stone
	var opts: Dictionary = {"actions": _found_actions(made), "new_skill": DeepProfile.first_of_skill(profile, made)}
	var wanted: Dictionary = DeepEconomy.commission_for(profile, made)
	if not wanted.is_empty():
		opts.wanted = "A commission wants this %s: %d gold" % [DeepUi.skill_name(made), DeepEconomy.payout(wanted, made)]
	profile_changed.emit()
	Geode.fuse(signed.given, made, opts)

class OddsBar extends Control:
	## Shares as one bar: a segment each, in its own color, the larger ones named under the bar
	## and every one named on hover. What a Geode prints its odds with, and a contract its colors.
	var parts: Array = []
	const BAR: float = 12.0

	func _init(list: Array) -> void:
		parts = list
		custom_minimum_size = Vector2(120, 32)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = " "

	func _get_tooltip(at: Vector2) -> String:
		var x: float = 0.0
		for part in parts:
			var width: float = size.x * float(part.share)
			if at.x >= x and at.x <= x + width:
				return "%s: %s" % [str(part.label), Geode.percent(float(part.share))]
			x += width
		return ""

	func _draw() -> void:
		var back := StyleBoxFlat.new()
		back.bg_color = Color(DeepUi.LINE, 0.5)
		back.set_corner_radius_all(int(BAR * 0.5))
		back.anti_aliasing = true
		draw_style_box(back, Rect2(Vector2.ZERO, Vector2(size.x, BAR)))
		var x: float = 0.0
		var font: Font = DeepUi.bold_font()
		for index in range(parts.size()):
			var part: Dictionary = parts[index]
			var width: float = size.x * float(part.share)
			if width <= 0.5:
				continue
			var segment := StyleBoxFlat.new()
			segment.bg_color = part.color
			segment.corner_radius_top_left = int(BAR * 0.5) if index == 0 else 0
			segment.corner_radius_bottom_left = int(BAR * 0.5) if index == 0 else 0
			segment.corner_radius_top_right = int(BAR * 0.5) if index == parts.size() - 1 else 0
			segment.corner_radius_bottom_right = int(BAR * 0.5) if index == parts.size() - 1 else 0
			segment.anti_aliasing = true
			var rect := Rect2(Vector2(x, 0), Vector2(width, BAR))
			draw_style_box(segment, rect)
			if bool(part.get("rainbow", false)):
				## A rainbow segment: the wheel run along it, in thin strips.
				var strips: int = maxi(2, int(width / 3.0))
				for s in range(strips):
					draw_rect(Rect2(Vector2(x + width * float(s) / float(strips), 0), Vector2(width / float(strips) + 0.5, BAR)), DeepUi.rainbow_at(float(s) / float(strips), 0.55))
			draw_line(Vector2(x, 1), Vector2(x + width, 1), Color(1, 1, 1, 0.22), 1.0)
			## Named under the bar where it is wide enough to carry the words.
			var words: String = "%s %s" % [str(part.label), Geode.percent(float(part.share))]
			var measured: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if measured > width - 2.0:
				words = Geode.percent(float(part.share))
				measured = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if measured <= width + 6.0:
				var tint: Color = part.color if not bool(part.get("rainbow", false)) else DeepUi.OPAL_TONE
				draw_string(font, Vector2(x + (width - measured) * 0.5, BAR + 15.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.15))
			x += width

class MarkRows extends Control:
	## Every skill a Geode might hold, each as its mark in its gem color, in as many to a row
	## as the card is wide; past the last row the rest are counted. Each names itself on hover
	## with its rarity and its odds, and says so if it has never been found (those are dimmed).
	var marks: Array = []
	var _hover: int = -1
	const MARK: float = 24.0
	const GAP: float = 5.0
	const ROWS: int = 2

	func _init(list: Array) -> void:
		marks = list
		custom_minimum_size = Vector2(120, MARK * ROWS + GAP * (ROWS - 1))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = " "
		mouse_exited.connect(func() -> void:
			_hover = -1
			queue_redraw())

	func _per_row() -> int:
		return maxi(1, int((size.x + GAP) / (MARK + GAP)))

	func _shown() -> int:
		## All of them if they fit; otherwise one cell short, for the count of the rest.
		var room: int = _per_row() * ROWS
		return marks.size() if marks.size() <= room else room - 1

	func _cell(index: int) -> Rect2:
		return Rect2(Vector2(float(index % _per_row()), float(index / _per_row())) * (MARK + GAP), Vector2(MARK, MARK))

	func _at(point: Vector2) -> int:
		## The mark under a point, or -2 over the count of the rest, or -1 over nothing.
		if point.x < 0.0 or point.y < 0.0:
			return -1
		var column: int = int(point.x / (MARK + GAP))
		var row: int = int(point.y / (MARK + GAP))
		if column >= _per_row() or row >= ROWS:
			return -1
		var index: int = row * _per_row() + column
		if index < _shown():
			return index
		return -2 if index == _shown() and _shown() < marks.size() else -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var index: int = _at(event.position)
			if index != _hover:
				_hover = index
				queue_redraw()

	func _get_tooltip(at: Vector2) -> String:
		var index: int = _at(at)
		if index >= 0:
			return str(marks[index].tip)
		if index == -2:
			var rest: Array = []
			for i in range(_shown(), marks.size()):
				rest.append(str(marks[i].name))
			return "And %s" % ", ".join(rest)
		return ""

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var shown: int = _shown()
		for index in range(shown):
			var mark: Dictionary = marks[index]
			var cell: Rect2 = _cell(index)
			var tint: Color = mark.color
			if index == _hover:
				var halo: float = MARK * 2.4
				draw_texture_rect(glow, Rect2(cell.get_center() - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(tint, 0.45))
			draw_texture_rect(GemIcons.texture(str(mark.glyph), GemIcons.baked_size(MARK)), cell, false, tint if bool(mark.known) else Color(tint, 0.42))
		if shown < marks.size():
			var cell: Rect2 = _cell(shown)
			var font: Font = DeepUi.bold_font()
			var words: String = "+%d" % (marks.size() - shown)
			draw_string(font, Vector2(cell.position.x, cell.get_center().y + 5.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DeepUi.PAPER if _hover == -2 else DeepUi.MUTED)

class Funnel extends Control:
	## The contract bench's lines from its places down to the one they make: faint and dotted
	## while a place is empty, lit in the grade's color once a stone is on it, and once the
	## contract can be signed, light running down every line toward the middle.
	var filled: int = 0
	var count: int = 5
	var tone: Color
	var signable: bool = false
	var pitch: float = 164.0
	var _clock: float = 0.0

	func _init(on: int, places: int, color: Color, can_sign: bool, apart: float) -> void:
		filled = on
		count = places
		tone = color
		signable = can_sign
		pitch = apart
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _point(index: int, t: float) -> Vector2:
		## A line leaves its place straight down and curves in to the middle.
		var top := Vector2(size.x * 0.5 + (float(index) - float(count - 1) * 0.5) * pitch, 0.0)
		var bottom := Vector2(size.x * 0.5, size.y)
		return top.bezier_interpolate(top + Vector2(0, size.y * 0.75), bottom - Vector2(0, size.y * 0.4), bottom, t)

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		for index in range(count):
			var points := PackedVector2Array()
			for step in range(21):
				points.append(_point(index, float(step) / 20.0))
			if index >= filled:
				for step in range(0, 20, 2):
					draw_line(points[step], points[step + 1], Color(DeepUi.LINE_HI, 0.9), 2.0, true)
				continue
			draw_polyline(points, Color(tone, 0.22), 7.0, true)
			draw_polyline(points, Color(tone.lightened(0.2), 0.85), 2.0, true)
			if signable:
				var t: float = fposmod(_clock * 0.9 + float(index) * 0.17, 1.0)
				var spot: float = 24.0
				draw_texture_rect(glow, Rect2(_point(index, t) - Vector2(spot, spot) * 0.5, Vector2(spot, spot)), false, Color(tone.lightened(0.4), 0.9 * sin(t * PI)))
		draw_circle(Vector2(size.x * 0.5, size.y), 4.0, Color(tone, 0.9) if filled > 0 else DeepUi.LINE_HI)

class Outcome extends Control:
	## Where the one comes out of a contract: a brass ring lit round a fifth at a time as the
	## bench fills, in the grade it promises, a stone's shape inside with a question for a
	## heart. Once the contract can be signed, it breathes.
	var tone: Color
	var fill: float = 0.0
	var signable: bool = false
	var _clock: float = 0.0

	func _init(color: Color, share: float, can_sign: bool) -> void:
		tone = color
		fill = clampf(share, 0.0, 1.0)
		signable = can_sign
		custom_minimum_size = Vector2(150, 132)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.42
		var breath: float = 0.5 + 0.5 * sin(_clock * 2.4) if signable else 0.0
		var halo: float = radius * (3.0 + 0.35 * breath)
		draw_texture_rect(glow, Rect2(centre - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(tone, 0.1 + 0.25 * fill + 0.15 * breath))
		draw_circle(centre, radius, Color(0.02, 0.025, 0.035, 0.92))
		draw_arc(centre, radius, 0, TAU, 72, Color("b8a47a"), 4.0, true)
		draw_arc(centre, radius - 6.0, 0, TAU, 72, Color("5a4a30"), 2.0, true)
		if fill > 0.0:
			draw_arc(centre, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 64, Color(tone, 0.95), 3.0, true)
		var mark: float = radius * 1.15
		draw_texture_rect(GemIcons.texture("gem", GemIcons.baked_size(mark)), Rect2(centre - Vector2(mark, mark) * 0.5, Vector2(mark, mark)), false, Color(tone, 0.22 + 0.45 * fill + 0.2 * breath))
		var font: Font = DeepUi.display_font()
		var size_px: int = int(radius * 0.62)
		var width: float = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(font, centre + Vector2(-width * 0.5, size_px * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(DeepUi.PAPER, 0.45 + 0.5 * fill))

# --- ledger and commissions ------------------------------------------------------------------

func _ledger(content: VBoxContainer) -> void:
	content.add_theme_constant_override("separation", 12)
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "book", 28, DeepUi.ACCENT)
	DeepUi.title(head, "The ledger", 30, DeepUi.PAPER)
	DeepUi.spacer(head)
	_enter(head)
	_records(content)

func _commissions(content: VBoxContainer) -> void:
	## The day's commissions: a skill each, sometimes with one of the four C's, and what it
	## pays. A stone that meets one is turned in from the Appraise tab.
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "flag", 28, DeepUi.ACCENT)
	DeepUi.title(head, "Commissions", 30, DeepUi.PAPER)
	DeepUi.spacer(head)
	_enter(head)
	var daily: Dictionary = profile.get("daily", {})
	var list: Array = daily.get("commissions", [])
	var about := DeepUi.hbox(content, 14)
	DeepUi.wrap(about, "Bring home the stone a commission names and turn it in on the Appraise tab, instead of keeping or selling it. A first stone of its skill can be turned in too.",
		14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 860)
	DeepUi.spacer(about)
	var left: int = DeepEconomy.seconds_to_tomorrow()
	DeepUi.stat(about, "hourglass", "New commissions in %dh %02dm" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 13, "Commissions turn over every day at midnight UTC.")
	DeepUi.stat(about, "flag", "%d turned in" % int(profile.get("records", {}).get("commissions", 0)), DeepUi.ACCENT, 13)
	_enter(about)
	if list.is_empty():
		_empty(content, "flag", "No commissions today", "Commissions ask for stones from the mines you have opened.")
		return
	var row := DeepUi.hbox(content, 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var index: int = 0
	for commission in list:
		_commission_card(row, commission)
		_enter(row.get_child(row.get_child_count() - 1), 0.05 + 0.06 * index)
		index += 1

func _commission_card(parent: Node, commission: Dictionary) -> void:
	var skill_key: String = str(commission.get("skill", ""))
	var skill: Dictionary = DeepContent.skill(skill_key)
	var color: String = str(skill.get("color", "WHITE"))
	var hue: Color = DeepUi.color(color)
	var done: bool = bool(commission.get("done", false))
	var fits: Array = profile.get("tray", []).filter(func(s: Dictionary) -> bool: return DeepEconomy.meets(commission, s))
	var card := DeepUi.card(parent, Color(DeepUi.GOOD if not fits.is_empty() and not done else hue, 0.5 if not done else 0.2), 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := DeepUi.vbox(card, 10)
	var known: String = "owned" if profile.get("vault", {}).has(skill_key) else ("seen" if profile.get("seen", []).has(skill_key) else "unseen")
	var frame := DeepUi.center(box)
	frame.custom_minimum_size.y = 120
	DeepUi.icon(frame, GemIcons.emblem(skill_key), 96, Color(hue, 0.9 if known != "unseen" else 0.45), str(skill.get("text", "")))
	DeepUi.title(box, str(skill.get("name", skill_key)), 24, hue.lightened(0.25) if not done else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var tags := DeepUi.hbox(box, 8)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	var rarity: String = str(skill.get("rarity", "COMMON"))
	DeepUi.pill(tags, "spark", rarity.capitalize(), StoneCard._rarity_color(rarity), 12)
	DeepUi.pill(tags, "chest" if known == "owned" else ("eye" if known == "seen" else "question"),
		{"owned": "In your vault", "seen": "Seen, not kept", "unseen": "Never found"}[known], DeepUi.MUTED, 12)
	var need: String = DeepEconomy.need_text(commission.get("need", {}))
	DeepUi.stat(box, "gem", "Any %s" % str(skill.get("name", skill_key)) if need.is_empty() else "%s, %s" % [str(skill.get("name", skill_key)), need], DeepUi.PAPER, 15).alignment = BoxContainer.ALIGNMENT_CENTER
	var where: Array = DeepEconomy.where_found(skill_key)
	var where_text: String = DeepContent.mine_name(str(where[0])) + (" and every mine below" if where.size() > 1 else "")
	DeepUi.stat(box, "pick", "Found in %s" % where_text, DeepUi.MUTED, 12, ", ".join(where.map(func(k: Variant) -> String: return DeepContent.mine_name(str(k))))).alignment = BoxContainer.ALIGNMENT_CENTER
	var pay := DeepUi.stat(box, "coins", ("Paid %d gold" % int(commission.get("paid", 0))) if done else "%d gold or more" % int(commission.get("reward", 0)), DeepUi.ACCENT if not done else DeepUi.GOOD, 20,
		"Pays %d gold, or a quarter more than the stone would sell for if it is finer than that." % int(commission.get("reward", 0)))
	pay.alignment = BoxContainer.ALIGNMENT_CENTER
	var foot := DeepUi.hbox(box, 8)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	if done:
		DeepUi.pill(foot, "check", "Filled. A new one tomorrow", DeepUi.GOOD, 13)
		return
	if not fits.is_empty():
		var pick_id: String = str(fits[0].id)
		DeepUi.primary(foot, "flag", "Turn in from the tray", func() -> void:
			_appraise_pick = pick_id
			open("appraise"), 14, DeepUi.GOOD)
	var price: int = DeepEconomy.reroll_price(profile)
	var commission_id: String = str(commission.get("id", ""))
	var reroll := DeepUi.icon_button(foot, "reroll", "Reroll · free" if price == 0 else "Reroll · %d gold" % price, func() -> void:
		if bool(DeepEconomy.reroll(profile, commission_id).get("ok", false)):
			DeepAudio.play("ui_confirm", {"volume": 0.7})
			profile_changed.emit(), 13, DeepUi.MUTED)
	reroll.disabled = int(profile.get("gold", 0)) < price
	reroll.tooltip_text = "Swap this commission for another skill. The first swap each day is free; each after it costs more." if not reroll.disabled else "You have %d gold. Another commission costs %d." % [int(profile.get("gold", 0)), price]

func _records(content: VBoxContainer) -> void:
	var records: Dictionary = profile.get("records", {})
	var tiles := DeepUi.hbox(content, 12)
	var index: int = 0
	for entry in [["pick", "runs", "Runs"], ["lift", "extractions", "Extractions"], ["crown", "conquests", "Conquests"], ["skull", "falls", "Falls"], ["chest", "stones_kept", "Stones kept"], ["flag", "commissions", "Commissions"],
			["calendar", "best_daily", "Best daily score"]]:
		var tile := DeepUi.card(tiles, DeepUi.LINE, 14)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if str(entry[1]) == "best_daily":
			## The daily bests, the latest days first, said on hover.
			var bests: Array = records.get("daily_bests", []).duplicate()
			bests.reverse()
			var said: Array = ["Your best score on each day's seam:"]
			for best_day in bests.slice(0, 10):
				said.append("%s: %d (%d gold)" % [str(best_day.get("date", "")), int(best_day.get("score", 0)), int(best_day.get("gold", 0))])
			tile.tooltip_text = "\n".join(said) if not bests.is_empty() else "No daily digs yet."
			tile.mouse_filter = Control.MOUSE_FILTER_STOP
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
	var best_card := DeepUi.card(left, Color(DeepUi.tier_color(str(best.get("tier", "ROUGH"))), 0.5) if not best.is_empty() else DeepUi.LINE, 16)
	var best_box := DeepUi.vbox(best_card, 10)
	DeepUi.section(best_box, "star", "Best stone")
	if best.is_empty():
		DeepUi.label(best_box, "Keep a stone to start the record.", 13, DeepUi.MUTED)
	else:
		best_box.add_child(Showcase.new(best.stone, 180))
		StoneCard.build(best_box, best.stone, {"picture": false, "provenance": true, "value": true, "text_width": 400})
	_enter(best_card, 0.1)
	var mines_card := DeepUi.card(left, DeepUi.LINE, 16)
	var mines_box := DeepUi.vbox(mines_card, 6)
	DeepUi.section(mines_box, "map", "Mines")
	## Two to a row, so every mine in the pack fits beside the best stone.
	var mine_grid := GridContainer.new()
	mine_grid.columns = 2
	mine_grid.add_theme_constant_override("h_separation", 18)
	mine_grid.add_theme_constant_override("v_separation", 2)
	mines_box.add_child(mine_grid)
	for key in DeepContent.mines_in_order():
		var record: Dictionary = profile.get("mines", {}).get(str(key), {})
		var open: bool = bool(record.get("unlocked", false))
		var row := DeepUi.hbox(mine_grid, 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.icon(row, ("crown" if bool(record.get("boss", false)) else "pick") if open else "lock", 16, DeepUi.ACCENT if open else DeepUi.DIM)
		## A sealed mine is still named, as the Map names it, dimmed and tagged.
		var named := DeepUi.label(row, DeepContent.mine_name(str(key)), 13, DeepUi.PAPER if open else DeepUi.DIM)
		named.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not open:
			DeepUi.label(row, "Sealed", 12, DeepUi.DIM)
		if open:
			DeepUi.stat(row, "stairs", str(int(record.get("deepest", 0))), DeepUi.INFO, 12, "Deepest")
			DeepUi.stat(row, "crown", str(record.get("wardens", []).size()), DeepUi.ACCENT, 12, "Wardens and bosses beaten")
	_enter(mines_card, 0.15)
	var history_card := DeepUi.card(columns, DeepUi.LINE, 16)
	history_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var history_box := DeepUi.vbox(history_card, 6)
	var history_head := DeepUi.hbox(history_box, 8)
	DeepUi.section(history_head, "hourglass", "Recent runs").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var history: Array = profile.get("history", []).duplicate()
	history.reverse()
	if history.is_empty():
		DeepUi.label(history_box, "No runs yet.", 13, DeepUi.MUTED)
	var shown: int = 0
	for run_record in _paged(history_head, "ledger", history, LEDGER_PAGE):
		var outcome: String = str(run_record.get("outcome", ""))
		var tone: Color = DeepUi.BAD if outcome == "fallen" else (DeepUi.ACCENT if outcome == "conquered" else DeepUi.GOOD)
		var row_panel := DeepUi.panel(history_box, Color(1, 1, 1, 0.025 if shown % 2 == 0 else 0.0), Color(0, 0, 0, 0), 6, 6)
		var row := DeepUi.hbox(row_panel, 12)
		DeepUi.icon(row, {"fallen": "skull", "conquered": "crown"}.get(outcome, "lift"), 18, tone, outcome.capitalize())
		DeepUi.label(row, outcome.capitalize(), 14, tone).custom_minimum_size.x = 96
		DeepUi.label(row, str(run_record.get("date", "")), 13, DeepUi.MUTED).custom_minimum_size.x = 100
		var daily: bool = bool(run_record.get("daily", false))
		if daily:
			DeepUi.stat(row, "calendar", "Daily dig", DeepUi.ACCENT, 13, "The day's seam, as deep as %s" % DeepContent.mine_name(str(run_record.get("deepest_mine", run_record.get("mine", "")))))
		else:
			DeepUi.label(row, str(DeepContent.mine(str(run_record.get("mine", ""))).get("name", "")), 13, DeepUi.PAPER)
		DeepUi.spacer(row)
		DeepUi.stat(row, "stairs", str(int(run_record.get("depth", 0))), DeepUi.INFO, 13, "Depth reached")
		if daily:
			DeepUi.stat(row, "star", str(int(run_record.get("score", 0))), DeepUi.PAPER, 13, "Score: the worth of the stones brought up and the pyrite carried")
		else:
			DeepUi.stat(row, "gem", str(int(run_record.get("stones", 0))), DeepUi.ACCENT, 13, "Stones brought home")
		if int(run_record.get("gold", 0)) > 0:
			DeepUi.stat(row, "coin", str(int(run_record.gold)), DeepUi.ACCENT, 13, "Gold paid for the day's seam" if daily else "Gold from the assayer at the lift")
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
		## A Bust rides the dice it is about rather than standing beside them.
		var bust: int = DiceIcons.ladder_penalty(stone.get("tiers", []), die)
		if not die.is_empty():
			var tip: String = ""
			if bust >= 0:
				var penalty: Dictionary = stone.get("tiers", [])[bust]
				tip = "%s: %s" % [str(penalty.get("name", "")), str(penalty.get("text", ""))]
			DiceIcons.build_ladder(tiers, stone.get("tiers", []), die, 0, 14 if labelled else 15, DeepUi.MUTED, DeepUi.MUTED, [], tip)
		for index in range(stone.get("tiers", []).size()):
			var tier: Dictionary = stone.get("tiers", [])[index]
			if DiceIcons.ladder_rung(tier, die) > 0 or index == bust:
				continue
			DiceIcons.build(tiers, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 14 if labelled else 15, DeepUi.MUTED,
				"%s: %s" % [str(tier.get("name", "")), str(tier.get("text", ""))])
		if not labelled:
			DeepUi.label(box, "Birthstone", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
