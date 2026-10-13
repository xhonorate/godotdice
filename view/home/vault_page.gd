extends RefCounted
## The vault: one stone per skill, and the one page in the workshop that scrolls (every skill
## in the pack belongs on it at a size worth looking at). The stone browser's row sorts and
## filters it; it can be laid out as a grid of tiles or a list of rows; the stone picked sits
## under the lamp on the right, where it can be starred as wanted or sent to a socket, the
## Wheel or the Oven. While anything waits on the tray, the Unappraised view shows it.

const StoneBrowser = preload("res://view/home/stone_browser.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Homecoming = preload("res://view/home/homecoming.gd")

const TILE: int = 84
const COLUMNS: int = 9

static func build(home: Control, content: VBoxContainer) -> void:
	var tray: Array = home.profile.get("tray", [])
	if tray.is_empty() and home._vault_view == "unappraised":
		home._vault_view = "collection"
	_head(home, content, tray)
	if home._vault_view == "unappraised":
		Homecoming.bench(home, content, false)
		return
	StoneBrowser.toolbar(home, content, "vault", {"layouts": true, "ghosts": true, "rarity": true})
	var columns := DeepUi.hbox(content, 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## The one scrollbar in the workshop, and it is here on purpose.
	scroller.set_meta("may_scroll", true)
	columns.add_child(scroller)
	var side := DeepUi.vbox(columns, 12)
	side.custom_minimum_size = Vector2(420, 0)
	var settings: Dictionary = StoneBrowser.settings(home, "vault")
	var kept: Array = StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "vault")
	if home._vault_pick.is_empty() and not kept.is_empty():
		home._vault_pick = str(kept[0].get("skill", ""))
	if str(settings.layout) == "list":
		var list_holder := DeepUi.vbox(scroller, 0)
		list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if kept.is_empty():
			DeepUi.label(list_holder, "No kept stone matches.", 14, DeepUi.DIM)
		StoneBrowser.table(home, list_holder, kept, {"context": "vault", "picked": home._vault_pick, "on_pick": func(stone: Dictionary) -> void:
			home._vault_pick = str(stone.get("skill", ""))
			if DeepProfile.unfresh(home.profile, home._vault_pick):
				home.touch()
			home._render()})
	else:
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.add_child(grid)
		var entries: Array = kept.map(func(stone: Dictionary) -> Dictionary: return {"skill": str(stone.get("skill", "")), "state": "owned", "stone": stone})
		if bool(settings.ghosts) and str(settings.query).strip_edges().is_empty() and str(settings.rarity).is_empty():
			for entry in DeepProfile.vault_grid(home.profile):
				if str(entry.state) == "owned":
					continue
				var color: String = str(DeepContent.skill(str(entry.skill)).get("color", "WHITE"))
				if settings.colors.is_empty() or settings.colors.has(color):
					entries.append(entry)
		if entries.is_empty():
			DeepUi.label(grid, "No stone matches.", 14, DeepUi.DIM)
		_fill(home, grid, entries, 0, COLUMNS * 2 if home._fresh and not home._headless else entries.size())
	_lamp(home, side)

static func _head(home: Control, content: VBoxContainer, tray: Array) -> void:
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "chest", 28, DeepUi.ACCENT)
	DeepUi.title(head, "The vault", 30, DeepUi.PAPER)
	DeepUi.gap(head, 8)
	var views: Array = [["collection", "chest", "Collection"]]
	if not tray.is_empty():
		views.append(["unappraised", "loupe", "Unappraised"])
	if views.size() > 1:
		for entry in views:
			var view: String = str(entry[0])
			var b := DeepUi.tab_button(head, str(entry[1]), str(entry[2]), home._vault_view == view, func() -> void:
				home._vault_view = view
				home._render(), 14)
			if view == "unappraised":
				HomeParts.pin(b, tray.size(), home.PIP_ACT)
	DeepUi.spacer(head)
	var owned: int = home.profile.get("vault", {}).size()
	var total: int = DeepProfile.known_skills(home.profile).size()
	DeepUi.label(head, "%d of %d gems owned" % [owned, total], 14, DeepUi.MUTED)
	var meter := DeepUi.bar(head, 8.0, DeepUi.ACCENT, Color(DeepUi.LINE, 0.6))
	meter.custom_minimum_size = Vector2(140, 8)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.set_values(float(owned) / float(maxi(1, total)))
	home.enter(head)

static func _fill(home: Control, grid: GridContainer, entries: Array, from: int, per_frame: int) -> void:
	## The grid `per_frame` tiles at a time, a frame apart, so opening the tab never stalls.
	if not is_instance_valid(grid):
		return
	if not grid.is_inside_tree():
		if from == 0:
			grid.tree_entered.connect(func() -> void: _fill(home, grid, entries, from, per_frame), CONNECT_ONE_SHOT)
		return
	var upto: int = mini(entries.size(), from + maxi(1, per_frame))
	var wanted: Array = DeepProfile.wanted(home.profile)
	for index in range(from, upto):
		var entry: Dictionary = entries[index]
		var key: String = str(entry.skill)
		var tile: PanelContainer
		if str(entry.state) == "owned":
			var stone: Dictionary = entry.stone
			tile = StoneCard.tile(grid, stone, TILE)
			if bool(stone.get("fresh", false)):
				StoneCard.mark_new(tile, func() -> void:
					if DeepProfile.unfresh(home.profile, key):
						home.touch())
			tile.mouse_entered.connect(func() -> void: home.hover_stone(tile, stone, {}))
		else:
			tile = _ghost_tile(grid, key, str(DeepContent.skill(key).get("color", "WHITE")), str(entry.state) == "seen")
		if wanted.has(key):
			home.tile_mark(tile, "star", DeepUi.ACCENT_HI, "Wanted: the Market marks anything that could be one")
		if str(entry.state) in ["owned", "seen"]:
			if key == home._vault_pick:
				_ring(tile)
			tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			DeepUi.juice(tile, 1.06)
			tile.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					DeepAudio.play("ui_tap", {"volume": 0.7})
					home._vault_pick = key
					home._render())
		home.enter(tile, 0.012 * index)
	if upto < entries.size():
		## Held weakly: a page rebuilt before the grid is full frees it, and the next frame
		## must find it gone rather than call into a freed capture.
		var held: WeakRef = weakref(grid)
		grid.get_tree().process_frame.connect(func() -> void:
			var still: GridContainer = held.get_ref() as GridContainer
			if still != null:
				_fill(home, still, entries, upto, per_frame), CONNECT_ONE_SHOT)

static func _ring(tile: PanelContainer) -> void:
	var plain: StyleBox = tile.get_theme_stylebox("panel")
	if not plain is StyleBoxFlat:
		return
	var style: StyleBoxFlat = plain.duplicate()
	style.border_color = DeepUi.ACCENT
	style.set_border_width_all(2)
	tile.add_theme_stylebox_override("panel", style)

static func _ghost_tile(parent: Node, key: String, color: String, seen: bool) -> PanelContainer:
	## A skill not kept: its emblem in grey if it has been seen, a dark mark if not.
	var box := PanelContainer.new()
	var style := DeepUi.flat(Color(0.03, 0.035, 0.05, 0.55 if seen else 0.35), Color(DeepUi.color(color), 0.25 if seen else 0.08), 12, 8)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	var column := DeepUi.vbox(box, 4)
	var frame := DeepUi.center(column)
	frame.custom_minimum_size = Vector2(TILE, TILE)
	var skill: Dictionary = DeepContent.skill(key)
	if seen:
		var hint: String = "%s: seen, not kept.\nClick for a summary." % str(skill.get("name", key))
		DeepUi.icon(frame, GemIcons.emblem(key), int(TILE * 0.52), Color(DeepUi.color(color), 0.35), hint)
		var l := DeepUi.label(column, str(skill.get("name", key)), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = TILE
		l.clip_text = true
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.tooltip_text = hint
	else:
		DeepUi.icon(frame, "question", 26, Color(DeepUi.color(color), 0.18), "Not yet found")
		DeepUi.label(column, " ", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	return box

static func _lamp(home: Control, side: VBoxContainer) -> void:
	## The stone under the lamp, and what can be done with it.
	var shown: Dictionary = DeepProfile.owned(home.profile, home._vault_pick)
	if shown.is_empty() and home.profile.get("seen", []).has(home._vault_pick):
		_reference(home, side, home._vault_pick)
		return
	if shown.is_empty():
		home.empty(side, "chest", "Nothing kept yet", "Stones you keep come here, one per skill.", 300.0)
		return
	var lamp := DeepUi.card(side, Color(DeepUi.tier_color(str(DeepStone.grade(shown).tier)), 0.5), 14)
	lamp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(lamp, 8)
	var stage := HomeParts.Showcase.new(shown, 190)
	box.add_child(stage)
	StoneCard.build(box, shown, {"picture": false, "provenance": true, "value": true, "text_width": 360})
	DeepUi.spacer(box, false)
	var skill: String = str(shown.get("skill", ""))
	var actions := DeepUi.hbox(box, 6)
	_want_button(home, actions, skill)
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	var socket := DeepUi.icon_button(actions, "person", "Socket it", func() -> void:
		home.edit_loadout(current, _first_fit(home, current, skill)), 13, DeepUi.PAPER)
	socket.tooltip_text = "Open %s's sockets with this stone ready to set" % DeepContent.character_title(current)
	for entry in [["cut", "cut", "Wheel"], ["clarity", "flame", "Oven"]]:
		var kind: String = str(entry[0])
		var b := DeepUi.icon_button(actions, str(entry[1]), str(entry[2]), func() -> void:
			home._rework_pick = skill
			home._market_view = "wheel" if kind == "cut" else "oven"
			home.open("market", true), 13, DeepUi.PAPER)
		var refusal: String = DeepEconomy.rework_refusal(home.profile, skill, kind)
		b.disabled = not refusal.is_empty() and not refusal.begins_with("That costs")
		b.tooltip_text = refusal if b.disabled else ("Recut it on the Wheel" if kind == "cut" else "Fire it in the Oven")
	home.enter(lamp, 0.05)

static func _want_button(home: Control, parent: Node, skill: String) -> void:
	var wanted: bool = DeepProfile.wanted(home.profile).has(skill)
	var b := DeepUi.icon_button(parent, "star", "Wanted" if wanted else "Want", func() -> void:
		DeepProfile.toggle_wanted(home.profile, skill)
		DeepAudio.play("ui_toggle", {"volume": 0.7})
		home.profile_changed.emit(), 13, DeepUi.ACCENT_HI if wanted else DeepUi.MUTED)
	b.tooltip_text = "The Market marks Geodes, cut stones and commissions that could give you this skill." if not wanted else "Take the star off"
	if wanted:
		DeepUi.selected_style(b, DeepUi.ACCENT)

static func _first_fit(home: Control, character: String, skill: String) -> int:
	## The socket a stone would go in: the first open one it fits, empty sockets first.
	var sockets: Array = DeepContent.character(character).get("sockets", [])
	var record: Dictionary = home.profile.get("characters", {}).get(character, {})
	var fallback: int = -1
	for index in range(sockets.size()):
		if not DeepProfile.fillable_socket(home.profile, character, index):
			continue
		if not DeepProfile.rail_refusal(home.profile, character, index, skill).is_empty():
			continue
		if home.rail_skill(record, index).is_empty():
			return index
		if fallback < 0:
			fallback = index
	return fallback

static func _reference(home: Control, side: VBoxContainer, key: String) -> void:
	## Only the skill is remembered; there is no kept stone to model or value.
	var stone: Dictionary = DeepStone.reference_stone(key)
	var skill: Dictionary = DeepContent.skill(key)
	var hue: Color = DeepUi.color(DeepStone.color(stone))
	var card := DeepUi.card(side, Color(hue, 0.35), 16)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := DeepUi.vbox(card, 10)
	var frame := DeepUi.center(column)
	frame.custom_minimum_size.y = 190
	DeepUi.icon(frame, GemIcons.emblem(key), 104, Color(hue, 0.65))
	DeepUi.title(column, str(skill.get("name", key)), 22, hue.lightened(0.25))
	var tags := DeepUi.hbox(column, 8)
	StoneCard.rarity_tag(tags, str(skill.get("rarity", "COMMON")), 13)
	DeepUi.pill(tags, "eye", "Seen, not kept", DeepUi.MUTED, 13)
	DiceIcons.build(column, DeepPatterns.describe(skill.get("trigger", {"kind": "always"}), int(stone.cut)), 18, DeepUi.PAPER)
	DeepUi.effect_text(column, DeepStone.text(stone), 13, DeepUi.PAPER, true, 360)
	DeepUi.wrap(column, "At one carat, Poor cut and Clear clarity. The stone you find will have its own qualities.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 360)
	DeepUi.spacer(column, false)
	_want_button(home, column, key)
	home.enter(card, 0.05)
