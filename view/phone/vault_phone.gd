extends RefCounted
## The vault on the phone (docs/PHONE_UI.md, board home-vault, approved November 7, 2026).
## One row of controls; the stones five a row in a grid that scrolls; the stone picked in a
## card beside it with its numbers and three things to do with it. The Unappraised view is
## the tray's bench (homecoming.gd), laid out for the phone there.

const VaultPage = preload("res://view/home/vault_page.gd")
const StoneBrowser = preload("res://view/home/stone_browser.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Homecoming = preload("res://view/home/homecoming.gd")
const Tips = preload("res://view/ui/tips.gd")

## A tile's picture, and the card's width beside the grid.
const TILE_PT: float = 50.0
const CARD_PT: float = 330.0

static func build(home: Control, content: VBoxContainer) -> void:
	var tray: Array = home.profile.get("tray", [])
	if tray.is_empty() and home._vault_view == "unappraised":
		home._vault_view = "collection"
	_head(home, content, tray)
	if home._vault_view == "unappraised":
		Homecoming.bench(home, content, false)
		return
	home.region(DeepUi.hbox(content, 0), "vault_tools", func(holder: Control) -> void:
		StoneBrowser.toolbar_phone(home, holder, "vault", {"rarity": true, "search": true, "ghosts": true}))
	var columns := DeepUi.hbox(content, int(DeepUi.pt(10)))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.set_meta("may_scroll", true)
	columns.add_child(scroller)
	var stones := DeepUi.vbox(scroller, 0)
	stones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.region(stones, "vault_stones", func(holder: Control) -> void: _stones(home, holder))
	var side := DeepUi.vbox(columns, int(DeepUi.pt(6)))
	side.custom_minimum_size.x = DeepUi.pt(CARD_PT)
	home.region(side, "vault_lamp", func(holder: Control) -> void: _card(home, holder))

static func _head(home: Control, content: VBoxContainer, tray: Array) -> void:
	var head := DeepUi.hbox(content, int(DeepUi.pt(8)))
	DeepUi.icon(head, "chest", DeepUi.pt(18), DeepUi.ACCENT)
	DeepUi.title(head, "The vault", 26, DeepUi.PAPER)
	if not tray.is_empty():
		for entry in [["collection", "chest", "Collection"], ["unappraised", "loupe", "Unappraised"]]:
			var view: String = str(entry[0])
			var b := DeepUi.tab_button(head, str(entry[1]), str(entry[2]), home._vault_view == view, func() -> void:
				home._vault_view = view
				home._render(), 12)
			b.custom_minimum_size.y = DeepUi.pt(32)
			if view == "unappraised":
				HomeParts.pin(b, tray.size(), home.PIP_ACT)
	DeepUi.spacer(head)
	var owned: int = home.profile.get("vault", {}).size()
	var total: int = DeepProfile.known_skills(home.profile).size()
	DeepUi.label(head, "%d of %d owned" % [owned, total], 11, DeepUi.MUTED)

static func _stones(home: Control, holder: Control) -> void:
	## The kept stones, and the places of the ones not kept yet, five to a row.
	var settings: Dictionary = StoneBrowser.settings(home, "vault")
	var kept: Array = StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "vault")
	var held: Dictionary = DeepProfile.owned(home.profile, home._vault_pick)
	if not kept.is_empty() and (home._vault_pick.is_empty() or (not held.is_empty() and not StoneBrowser.passes(held, settings))):
		home._vault_pick = str(kept[0].get("skill", ""))
		if home.region_holder("vault_lamp") != null:
			home.redraw(["vault_lamp"])
	var grid := GridContainer.new()
	grid.name = "VaultGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(5)))
	grid.add_theme_constant_override("v_separation", int(DeepUi.pt(5)))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(grid)
	var entries: Array = kept.map(func(stone: Dictionary) -> Dictionary: return {"skill": str(stone.get("skill", "")), "state": "owned", "stone": stone})
	if bool(settings.ghosts) and str(settings.query).strip_edges().is_empty() and str(settings.rarity).is_empty():
		for entry in DeepProfile.vault_grid(home.profile):
			if str(entry.state) == "owned":
				continue
			var color: String = str(DeepContent.skill(str(entry.skill)).get("color", "WHITE"))
			if settings.colors.is_empty() or settings.colors.has(color):
				entries.append(entry)
	if entries.is_empty():
		DeepUi.label(grid, "No stone matches.", 13, DeepUi.DIM)
	for index in range(entries.size()):
		_tile(home, grid, entries[index])

static func _tile(home: Control, grid: GridContainer, entry: Dictionary) -> void:
	var key: String = str(entry.skill)
	var tile: PanelContainer
	if str(entry.state) == "owned":
		var stone: Dictionary = entry.stone
		tile = StoneCard.tile(grid, stone, DeepUi.pt(TILE_PT))
		if bool(stone.get("fresh", false)):
			StoneCard.mark_new(tile, func() -> void:
				if DeepProfile.unfresh(home.profile, key):
					home.touch())
	else:
		tile = _ghost(grid, key, str(DeepContent.skill(key).get("color", "WHITE")), str(entry.state) == "seen")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if DeepProfile.favorites(home.profile).has(key):
		home.tile_mark(tile, "star", DeepUi.ACCENT_HI, "A favorite")
	if key == home._vault_pick:
		var plain: StyleBox = tile.get_theme_stylebox("panel")
		if plain is StyleBoxFlat:
			var style: StyleBoxFlat = plain.duplicate()
			style.border_color = DeepUi.ACCENT
			style.set_border_width_all(int(DeepUi.pt(1.5)))
			tile.add_theme_stylebox_override("panel", style)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not Tips.held(tile):
			DeepAudio.play("ui_tap", {"volume": 0.7})
			home._vault_pick = key
			if not home.redraw(["vault_stones", "vault_lamp"]):
				home._render())

static func _ghost(parent: Node, key: String, color: String, seen: bool) -> PanelContainer:
	## A skill not kept: its emblem in grey if it has been seen, a faint question if not.
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", DeepUi.flat(Color(0.03, 0.035, 0.05, 0.55 if seen else 0.35), Color(DeepUi.color(color), 0.25 if seen else 0.08), 12, int(DeepUi.pt(4))))
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(box)
	var column := DeepUi.vbox(box, 0)
	var frame := DeepUi.center(column)
	frame.custom_minimum_size = Vector2(DeepUi.pt(TILE_PT), DeepUi.pt(TILE_PT))
	var skill: Dictionary = DeepContent.skill(key)
	if seen:
		DeepUi.icon(frame, GemIcons.emblem(key), DeepUi.pt(TILE_PT * 0.5), Color(DeepUi.color(color), 0.35))
		var l := DeepUi.label(column, str(skill.get("name", key)), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.clip_text = true
		l.custom_minimum_size.x = DeepUi.pt(TILE_PT)
		box.tooltip_text = "%s: seen, not kept." % str(skill.get("name", key))
	else:
		DeepUi.icon(frame, "question", DeepUi.pt(16), Color(DeepUi.color(color), 0.18))
		DeepUi.label(column, " ", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		box.tooltip_text = "Not yet found."
	return box

static func _card(home: Control, side: VBoxContainer) -> void:
	## The stone picked: its card, its numbers, whose sockets hold it, and Socket it, Wheel, Oven.
	var shown: Dictionary = DeepProfile.owned(home.profile, home._vault_pick)
	if shown.is_empty() and home.profile.get("seen", []).has(home._vault_pick):
		VaultPage._reference(home, side, home._vault_pick)
		return
	if shown.is_empty() and DeepProfile.known_skills(home.profile).has(home._vault_pick):
		VaultPage._unfound(home, side, home._vault_pick)
		return
	if shown.is_empty():
		DeepUi.label(side, "Stones you keep come here, one per skill.", 13, DeepUi.MUTED)
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_meta("may_scroll", true)
	side.add_child(scroll)
	var column := DeepUi.vbox(scroll, int(DeepUi.pt(5)))
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := StoneCard.build(column, shown, {"size": DeepUi.pt(56), "provenance": true})
	card.add_child(holder)
	## The star sits over the picture's corner: the card's top right holds the grade.
	var star := VaultPage._favorite_star(home, holder, str(shown.get("skill", "")))
	star.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	star.offset_left = 0.0
	star.offset_top = 0.0
	star.offset_right = DeepUi.pt(40)
	star.offset_bottom = DeepUi.pt(40)
	## A finger's room to tap, the mark itself no bigger than the desk's.
	star.add_theme_constant_override("icon_max_width", int(DeepUi.pt(24)))
	_numbers(home, column, shown)
	var skill: String = str(shown.get("skill", ""))
	VaultPage._wearers(home, column, skill)
	var actions := DeepUi.hbox(side, int(DeepUi.pt(6)))
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	var socket := DeepUi.primary(actions, "person", "Socket it", func() -> void:
		home.edit_loadout(current, VaultPage._first_fit(home, current, skill), skill), 12)
	socket.custom_minimum_size.y = DeepUi.pt(34)
	for entry in [["cut", "cut", "Wheel"], ["clarity", "flame", "Oven"]]:
		var kind: String = str(entry[0])
		var b := DeepUi.icon_button(actions, str(entry[1]), str(entry[2]), func() -> void:
			home._rework_pick = skill
			home._market_view = "wheel" if kind == "cut" else "oven"
			home.open("market", true), 12, DeepUi.PAPER)
		DeepUi.ledger_button(b, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 6)
		b.custom_minimum_size.y = DeepUi.pt(34)
		var refusal: String = DeepEconomy.rework_refusal(home.profile, skill, kind)
		b.disabled = not refusal.is_empty() and not refusal.begins_with("That costs")

static func _numbers(home: Control, parent: Node, stone: Dictionary) -> void:
	## Where it stands on every scale it is graded by, a bar each.
	var box := DeepUi.vbox(parent, int(DeepUi.pt(2)))
	DeepUi.section(box, "ladder", "By the numbers", DeepUi.ACCENT, 11)
	var carat: int = int(stone.get("carat", 1))
	var cut: int = int(stone.get("cut", 0))
	var clarity: int = int(stone.get("clarity", DeepContent.clear_index()))
	var grade: Dictionary = DeepStone.grade(stone)
	var worth: int = DeepStone.value(stone)
	var richest: int = 1
	for kept in home.profile.get("vault", {}).values():
		if kept is Dictionary and not DeepStone.is_birthstone(kept):
			richest = maxi(richest, DeepStone.value(kept))
	var rows: Array = [
		["Carat", float(carat) / float(DeepStone.carat_max()), "%d of %d ct" % [carat, DeepStone.carat_max()], DeepUi.ACCENT],
		["Cut", float(cut + 1) / float(DeepContent.cuts().size()), DeepContent.cut_name(cut), StoneCard.TileTags.CUT_TONE],
		["Clarity", float(clarity + 1) / float(DeepContent.clarities().size()), DeepContent.clarity_name(clarity), Color("b58cff")],
		["Grade", float(grade.score) / 100.0, "%s · %d" % [str(grade.name), int(grade.score)], DeepUi.tier_color(str(grade.tier))],
		["Worth", float(worth) / float(richest), "%d" % worth, DeepUi.ACCENT]]
	for row in rows:
		var line := DeepUi.hbox(box, int(DeepUi.pt(6)))
		DeepUi.label(line, str(row[0]), 11, DeepUi.MUTED).custom_minimum_size.x = DeepUi.pt(50)
		var meter := DeepUi.bar(line, DeepUi.pt(5), row[3], Color(DeepUi.LINE, 0.6))
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.set_values(clampf(float(row[1]), 0.0, 1.0))
		var value := DeepUi.label(line, str(row[2]), 11, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
		value.custom_minimum_size.x = DeepUi.pt(78)
