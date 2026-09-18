extends Control
## The workshop: five tabs in one quiet frame. Map (the party and the way down), Bench
## (settings, sockets, dice), Vault (one stone per skill), Appraise (what came home), Ledger.

const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

signal depart_requested(seed: int)
signal member_changed(fields: Dictionary)
signal mine_chosen(mine: String)
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal profile_changed

const TABS: Array = [["map", "Map"], ["bench", "Bench"], ["vault", "Vault"], ["appraise", "Appraise"], ["ledger", "Ledger"]]

var profile: Dictionary = {}
var lobby: Dictionary = {}
var status: String = "local"
var is_host: bool = true
var local_id: String = "p0"
var can_start: bool = true
var settings: Dictionary = {}
var tab: String = "map"
var _bar: HBoxContainer
var _body: Control
var _vault_pick: String = ""
var _address: LineEdit
var _seed: LineEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var head := DeepUi.panel(column, DeepUi.SLATE_LOW, DeepUi.LINE, 0, 10)
	_bar = DeepUi.hbox(head, 8)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)

func refresh(new_profile: Dictionary, new_lobby: Dictionary, new_status: String, host: bool, id: String, startable: bool, new_settings: Dictionary) -> void:
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
	DeepUi.clear(_bar)
	DeepUi.label(_bar, "DEEP CUT", 18, DeepUi.ACCENT)
	DeepUi.label(_bar, "%d gold" % int(profile.get("gold", 0)), 14, DeepUi.MUTED)
	DeepUi.spacer(_bar)
	for entry in TABS:
		var key: String = str(entry[0])
		var button := DeepUi.button(_bar, str(entry[1]), func() -> void: open(key), 14)
		if key == tab:
			button.add_theme_stylebox_override("normal", DeepUi.flat(DeepUi.ACCENT_DIM, DeepUi.ACCENT, 8, 10))
		if key == "appraise" and not profile.get("tray", []).is_empty():
			button.text = "Appraise (%d)" % profile.tray.size()
	DeepUi.spacer(_bar)
	DeepUi.label(_bar, str(profile.get("name", "")), 14, DeepUi.MUTED)
	DeepUi.clear(_body)
	var page := ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(page)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	page.add_child(margin)
	var content := DeepUi.vbox(margin, 14)
	match tab:
		"map": _map(content)
		"bench": _bench(content)
		"vault": _vault(content)
		"appraise": _appraise(content)
		"ledger": _ledger(content)

# --- map -------------------------------------------------------------------------------------

func _map(content: VBoxContainer) -> void:
	var columns := DeepUi.hbox(content, 24)
	var left := DeepUi.vbox(columns, 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.heading(left, "Mines")
	var keys: Array = DeepContent.section("mines").keys()
	keys.sort()
	for key in keys:
		var mine: Dictionary = DeepContent.mine(str(key))
		var record: Dictionary = profile.get("mines", {}).get(str(key), {})
		var unlocked: bool = bool(record.get("unlocked", false))
		var chosen: bool = str(lobby.get("mine", "")) == str(key)
		var card := DeepUi.panel(left, DeepUi.SLATE, DeepUi.ACCENT if chosen else DeepUi.LINE, 10, 14)
		var box := DeepUi.vbox(card, 6)
		DeepUi.label(box, str(mine.get("name", key)) if unlocked else "A sealed shaft", 16, DeepUi.PAPER if unlocked else DeepUi.DIM)
		if unlocked:
			DeepUi.label(box, str(mine.get("text", "")), 13, DeepUi.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var facts := DeepUi.hbox(box, 8)
			DeepUi.chip(facts, "deepest %d" % int(record.get("deepest", 0)), DeepUi.INFO, 11)
			DeepUi.chip(facts, "%d warden%s" % [record.get("wardens", []).size(), "" if record.get("wardens", []).size() == 1 else "s"], DeepUi.ACCENT, 11)
			DeepUi.chip(facts, "%d run%s" % [int(record.get("runs", 0)), "" if int(record.get("runs", 0)) == 1 else "s"], DeepUi.MUTED, 11)
			if is_host and not chosen:
				var mine_key: String = str(key)
				DeepUi.button(box, "Choose this mine", func() -> void: mine_chosen.emit(mine_key), 13)
	var right := DeepUi.vbox(columns, 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.heading(right, "The party")
	for id in lobby.get("order", []):
		var member: Dictionary = lobby.members.get(id, {})
		var card := DeepUi.panel(right, DeepUi.SLATE, DeepUi.LINE, 10, 10)
		var row := DeepUi.hbox(card, 10)
		DeepUi.label(row, str(member.get("name", id)) + (" (you)" if str(id) == local_id else ""), 14, DeepUi.PAPER)
		DeepUi.label(row, str(DeepContent.setting(str(member.get("setting", ""))).get("name", "")), 13, DeepUi.MUTED)
		DeepUi.spacer(row)
		var note: String = "host" if str(id) == str(lobby.get("host", "p0")) else ("ready" if bool(member.get("ready", false)) else "not ready")
		if not bool(member.get("connected", true)):
			note = "away"
		DeepUi.chip(row, note, DeepUi.GOOD if note in ["ready", "host"] else DeepUi.MUTED, 11)
	var me: Dictionary = lobby.members.get(local_id, {})
	var wear := DeepUi.hbox(right, 8)
	DeepUi.label(wear, "Wearing", 13, DeepUi.MUTED)
	var pick := OptionButton.new()
	var unlocked_settings: Array = []
	for key in DeepContent.section("settings"):
		if bool(profile.get("settings", {}).get(str(key), {}).get("unlocked", false)):
			unlocked_settings.append(str(key))
	unlocked_settings.sort()
	for key in unlocked_settings:
		pick.add_item(str(DeepContent.setting(key).get("name", key)))
		pick.set_item_metadata(pick.item_count - 1, key)
		if key == str(profile.get("current_setting", "")):
			pick.selected = pick.item_count - 1
	pick.item_selected.connect(func(index: int) -> void:
		profile.current_setting = str(pick.get_item_metadata(index))
		profile_changed.emit())
	wear.add_child(pick)
	if not is_host:
		var ready := DeepUi.button(right, "Unready" if bool(me.get("ready", false)) else "Ready", func() -> void: member_changed.emit({"ready": not bool(me.get("ready", false))}))
		ready.disabled = status != "joined"
	else:
		var seed_row := DeepUi.hbox(right, 8)
		DeepUi.label(seed_row, "Seed", 12, DeepUi.DIM)
		_seed = LineEdit.new()
		_seed.placeholder_text = "blank for a new one"
		_seed.custom_minimum_size = Vector2(160, 0)
		seed_row.add_child(_seed)
		var go := DeepUi.button(right, "Descend", func() -> void:
			depart_requested.emit(int(_seed.text) if _seed.text.is_valid_int() else 0), 17)
		go.disabled = not can_start or bool(lobby.get("started", false))
		if not can_start:
			DeepUi.label(right, "Waiting for everyone to be ready.", 12, DeepUi.MUTED)
	DeepUi.rule(right)
	DeepUi.heading(right, "Play together")
	DeepUi.label(right, "Status: %s" % status, 12, DeepUi.MUTED)
	var lan := DeepUi.hbox(right, 8)
	DeepUi.button(lan, "Host on LAN", func() -> void: host_requested.emit(DeepSession.DEFAULT_PORT), 13)
	_address = LineEdit.new()
	_address.text = str(settings.get("last_address", "127.0.0.1"))
	_address.custom_minimum_size = Vector2(160, 0)
	lan.add_child(_address)
	DeepUi.button(lan, "Join", func() -> void: join_requested.emit(_address.text, DeepSession.DEFAULT_PORT), 13)
	DeepUi.label(right, "Steam lobbies arrive with the release transport; LAN and direct IP work now.", 11, DeepUi.DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# --- bench -----------------------------------------------------------------------------------

func _bench(content: VBoxContainer) -> void:
	var setting_key: String = str(profile.get("current_setting", DeepContent.starter_setting()))
	var setting: Dictionary = DeepContent.setting(setting_key)
	var record: Dictionary = profile.settings.get(setting_key, {"rail": [], "dice": []})
	var head := DeepUi.hbox(content, 12)
	DeepUi.heading(head, str(setting.get("name", setting_key)), 16)
	DeepUi.label(head, str(setting.get("text", "")), 13, DeepUi.MUTED)
	DeepUi.spacer(head)
	DeepUi.chip(head, "%d HP" % int(setting.get("hp", 0)), DeepUi.HP, 12)
	DeepUi.label(content, str(setting.get("passive", {}).get("text", "")), 13, DeepUi.ACCENT)
	DeepUi.heading(content, "Sockets", 13)
	var rail_row := DeepUi.hbox(content, 12)
	var sockets: Array = setting.get("sockets", [])
	for index in range(sockets.size()):
		var socket_colour: String = str(sockets[index])
		var card := DeepUi.panel(rail_row, DeepUi.SLATE, DeepUi.ACCENT if socket_colour == "CAPSTONE" else (DeepUi.colour(socket_colour) if socket_colour != "ANY" else DeepUi.LINE), 10, 10)
		card.custom_minimum_size = Vector2(160, 0)
		var box := DeepUi.vbox(card, 6)
		DeepUi.label(box, socket_colour.capitalize(), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var skill: Variant = record.rail[index] if index < record.rail.size() else null
		var stone: Dictionary = DeepProfile.owned(profile, str(skill)) if skill is String else {}
		if not stone.is_empty():
			var pic_row := DeepUi.hbox(box, 0)
			pic_row.alignment = BoxContainer.ALIGNMENT_CENTER
			StoneCard.mini(pic_row, stone, 64, DeepStone.name(stone))
			DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", "")), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			var socket_index: int = index
			DeepUi.button(box, "Remove", func() -> void:
				DeepProfile.set_rail(profile, setting_key, socket_index, null)
				profile_changed.emit(), 12)
		else:
			DeepUi.label(box, "empty", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var fitting: Array = []
		for owned_key in profile.vault:
			var candidate: Dictionary = profile.vault[owned_key]
			if DeepStone.fits(candidate, socket_colour) and (skill == null or str(skill) != str(owned_key)):
				var cap: int = int(setting.get("carat_max", 0))
				if cap <= 0 or int(candidate.carat) <= cap:
					fitting.append(str(owned_key))
		fitting.sort()
		if not fitting.is_empty():
			var pick := OptionButton.new()
			for key in fitting:
				pick.add_item(str(DeepContent.skill(key).get("name", key)))
				pick.set_item_metadata(pick.item_count - 1, key)
			pick.selected = 0
			box.add_child(pick)
			var socket_index: int = index
			DeepUi.button(box, "Set", func() -> void:
				var problem: String = DeepProfile.set_rail(profile, setting_key, socket_index, str(pick.get_item_metadata(pick.selected)))
				if problem.is_empty():
					profile_changed.emit(), 12)
	DeepUi.heading(content, "Dice", 13)
	var dice_row := DeepUi.hbox(content, 12)
	var loadout: Dictionary = DeepProfile.loadout(profile, setting_key)
	for index in range(5):
		var die: Dictionary = loadout.dice[index] if index < loadout.dice.size() else {}
		var card := DeepUi.panel(dice_row, DeepUi.SLATE, DeepUi.LINE, 10, 10)
		card.custom_minimum_size = Vector2(160, 0)
		var box := DeepUi.vbox(card, 6)
		DeepUi.label(box, DeepDice.describe(die) if not die.is_empty() else "empty", 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		if not die.is_empty():
			DeepUi.label(box, " ".join(die.get("faces", []).map(func(f: Dictionary) -> String: return DiceIcons.face_text(int(f.value), str(f.kind)))), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var pick := OptionButton.new()
		for bowl_die in profile.get("bowl", []):
			pick.add_item(DeepDice.describe(bowl_die))
			pick.set_item_metadata(pick.item_count - 1, str(bowl_die.id))
			if not die.is_empty() and str(bowl_die.id) == str(die.id):
				pick.selected = pick.item_count - 1
		box.add_child(pick)
		var slot: int = index
		DeepUi.button(box, "Use", func() -> void:
			if pick.item_count > 0 and DeepProfile.set_die(profile, setting_key, slot, str(pick.get_item_metadata(pick.selected))).is_empty():
				profile_changed.emit(), 12)
	DeepUi.label(content, "The bowl holds %d dice." % profile.get("bowl", []).size(), 12, DeepUi.MUTED)

# --- vault -----------------------------------------------------------------------------------

func _vault(content: VBoxContainer) -> void:
	var columns := DeepUi.hbox(content, 24)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(grid)
	var side := DeepUi.vbox(columns, 10)
	side.custom_minimum_size = Vector2(380, 0)
	for entry in DeepProfile.vault_grid(profile):
		var skill: Dictionary = DeepContent.skill(str(entry.skill))
		var state: String = str(entry.state)
		var tile := DeepUi.panel(grid, DeepUi.SLATE_LOW if state != "owned" else DeepUi.SLATE, Color(DeepUi.colour(str(skill.get("colour", "WHITE"))), 0.5 if state == "owned" else 0.15), 10, 8)
		tile.custom_minimum_size = Vector2(110, 120)
		var box := DeepUi.vbox(tile, 4)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		if state == "owned":
			var pic_row := DeepUi.hbox(box, 0)
			pic_row.alignment = BoxContainer.ALIGNMENT_CENTER
			StoneCard.mini(pic_row, entry.stone, 60, DeepStone.name(entry.stone))
			DeepUi.label(box, str(skill.get("name", entry.skill)), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			var key: String = str(entry.skill)
			var button := DeepUi.button(box, "Look", func() -> void:
				_vault_pick = key
				_render(), 11)
			button.flat = true
		elif state == "seen":
			var pic_row := DeepUi.hbox(box, 0)
			pic_row.alignment = BoxContainer.ALIGNMENT_CENTER
			GemIcons.glyph(pic_row, GemIcons.emblem(str(entry.skill)), 40, DeepUi.DIM)
			DeepUi.label(box, str(skill.get("name", entry.skill)), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var pic_row := DeepUi.hbox(box, 0)
			pic_row.alignment = BoxContainer.ALIGNMENT_CENTER
			GemIcons.glyph(pic_row, "carat", 40, Color(DeepUi.DIM, 0.3))
			DeepUi.label(box, "?", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var owned: int = profile.get("vault", {}).size()
	DeepUi.heading(side, "%d of %d skills kept" % [owned, DeepContent.section("skills").size()])
	var shown: Dictionary = DeepProfile.owned(profile, _vault_pick)
	if shown.is_empty() and not profile.get("records", {}).get("best", {}).is_empty():
		shown = profile.records.best.stone
		DeepUi.label(side, "Your best stone", 12, DeepUi.MUTED)
	if not shown.is_empty():
		StoneCard.build(side, shown, {"size": 110, "provenance": true, "value": true, "drift": true})

# --- appraise --------------------------------------------------------------------------------

func _appraise(content: VBoxContainer) -> void:
	var tray: Array = profile.get("tray", [])
	if tray.is_empty():
		DeepUi.heading(content, "The tray is empty")
		DeepUi.label(content, "Stones you bring home wait here to be put under the loupe.", 14, DeepUi.MUTED)
		return
	DeepUi.heading(content, "%d stone%s under the loupe" % [tray.size(), "" if tray.size() == 1 else "s"])
	for stone in tray:
		var id: String = str(stone.id)
		var card := DeepUi.panel(content, DeepUi.SLATE, DeepUi.LINE, 12, 14)
		var row := DeepUi.hbox(card, 16)
		var left := DeepUi.vbox(row, 8)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not bool(stone.get("appraised", false)):
			StoneCard.build(left, stone, {"size": 96})
			DeepUi.button(left, "Appraise", func() -> void:
				stone.appraised = true
				stone.inclusions_revealed = true
				profile_changed.emit(), 15)
			continue
		StoneCard.build(left, stone, {"size": 110, "provenance": true, "value": true, "drift": true})
		var right := DeepUi.vbox(row, 8)
		right.custom_minimum_size = Vector2(300, 0)
		var owned: Dictionary = DeepProfile.owned(profile, str(stone.skill))
		if not owned.is_empty():
			DeepUi.label(right, "You already keep one. Keeping this sells the other for %d gold." % DeepStone.value(owned), 12, DeepUi.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			StoneCard.build(right, owned, {"size": 64, "value": true})
		var buttons := DeepUi.hbox(right, 8)
		DeepUi.button(buttons, "Keep", func() -> void:
			DeepProfile.decide_tray(profile, id, true)
			profile_changed.emit())
		DeepUi.button(buttons, "Sell for %d" % DeepStone.value(stone), func() -> void:
			DeepProfile.decide_tray(profile, id, false)
			profile_changed.emit())

# --- ledger ----------------------------------------------------------------------------------

func _ledger(content: VBoxContainer) -> void:
	var records: Dictionary = profile.get("records", {})
	DeepUi.heading(content, "Records")
	var facts := DeepUi.hbox(content, 8)
	for entry in [["runs", "runs"], ["extractions", "extractions"], ["conquests", "conquests"], ["falls", "falls"], ["stones_kept", "stones kept"]]:
		DeepUi.chip(facts, "%d %s" % [int(records.get(entry[0], 0)), entry[1]], DeepUi.MUTED, 12)
	if not records.get("best", {}).is_empty():
		DeepUi.heading(content, "Best stone", 13)
		StoneCard.build(content, records.best.stone, {"size": 96, "provenance": true, "value": true})
	DeepUi.heading(content, "History", 13)
	var history: Array = profile.get("history", [])
	if history.is_empty():
		DeepUi.label(content, "No runs yet.", 13, DeepUi.MUTED)
	for index in range(history.size() - 1, maxi(-1, history.size() - 21), -1):
		var run_record: Dictionary = history[index]
		DeepUi.label(content, "%s  ·  %s  ·  depth %d  ·  %s  ·  %d stone%s" % [str(run_record.get("date", "")), str(DeepContent.mine(str(run_record.get("mine", ""))).get("name", "")), int(run_record.get("depth", 0)),
			str(run_record.get("outcome", "")), int(run_record.get("stones", 0)), "" if int(run_record.get("stones", 0)) == 1 else "s"], 13, DeepUi.PAPER)
