extends RefCounted
## The vault: one stone per skill, and the one page in the workshop that scrolls (every skill
## in the pack belongs on it at a size worth looking at). The stone browser's row sorts and
## filters it; it can be laid out as a grid of tiles or a list of rows; the stone picked sits
## under the lamp on the right, with a meter for each scale it is graded by and whose sockets
## hold it; the star in its corner makes it a favorite, and it can be sent to a socket, the
## Wheel or the Oven. While anything waits on the tray, the Unappraised view shows it.

const StoneBrowser = preload("res://view/home/stone_browser.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Homecoming = preload("res://view/home/homecoming.gd")
const Roster = preload("res://view/home/roster.gd")

const TILE: int = 84
## About a row of tiles: the grid flows to its width, and fills two of these a frame.
const COLUMNS: int = 9

static func build(home: Control, content: VBoxContainer) -> void:
	var tray: Array = home.profile.get("tray", [])
	if tray.is_empty() and home._vault_view == "unappraised":
		home._vault_view = "collection"
	_head(home, content, tray)
	if home._vault_view == "unappraised":
		Homecoming.bench(home, content, false)
		return
	## The toolbar, the stones and the lamp are each a part of their own (see home.region): a
	## stone picked, a star or a sort redraws only what it changes.
	home.region(DeepUi.hbox(content, 0), "vault_tools", func(holder: Control) -> void:
		StoneBrowser.toolbar(home, holder, "vault", {"layouts": true, "ghosts": true, "rarity": true}).size_flags_horizontal = Control.SIZE_EXPAND_FILL)
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
	var stones := DeepUi.vbox(scroller, 0)
	stones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.region(stones, "vault_stones", func(holder: Control) -> void: _stones(home, holder))
	home.region(side, "vault_lamp", func(holder: Control) -> void: _lamp(home, holder))

static func _stones(home: Control, holder: Control) -> void:
	## The kept stones (and the ones not kept yet), as tiles or as rows.
	var settings: Dictionary = StoneBrowser.settings(home, "vault")
	var kept: Array = StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "vault")
	var held: Dictionary = DeepProfile.owned(home.profile, home._vault_pick)
	if not kept.is_empty() and (home._vault_pick.is_empty() or (not held.is_empty() and not StoneBrowser.passes(held, settings))):
		home._vault_pick = str(kept[0].get("skill", ""))
		## A filter hid the stone under the lamp: the lamp follows the list. On a full render
		## the lamp region is not registered yet and is drawn after this with the new pick.
		if home.region_holder("vault_lamp") != null:
			home.redraw(["vault_lamp"])
	if str(settings.layout) == "list":
		if kept.is_empty():
			DeepUi.label(holder, "No kept stone matches.", 14, DeepUi.DIM)
		StoneBrowser.table(home, holder, kept, {"context": "vault", "picked": home._vault_pick, "on_pick": func(stone: Dictionary) -> void:
			var was: String = home._vault_pick
			home._vault_pick = str(stone.get("skill", ""))
			if DeepProfile.unfresh(home.profile, home._vault_pick):
				home.touch()
			## The lamp drawn again, and only the two rows whose ring moved restyled.
			if not home.redraw(["vault_lamp"]) or not StoneBrowser.repick(home.region_holder("vault_stones"), was, home._vault_pick):
				home._render()})
		return
	## A flow, not a fixed grid: as many tiles a row as the scroller has room for.
	var grid := HFlowContainer.new()
	grid.name = "VaultGrid"
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
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
		DeepUi.label(grid, "No stone matches.", 14, DeepUi.DIM)
	## A frame at a time whenever it is drawn, a sort or a search as much as the tab opening.
	_fill(home, grid, entries, 0, COLUMNS * 2 if not home._headless else entries.size())

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

static func _fill(home: Control, grid: HFlowContainer, entries: Array, from: int, per_frame: int) -> void:
	## The grid `per_frame` tiles at a time, a frame apart, so opening the tab never stalls.
	if not is_instance_valid(grid):
		return
	if not grid.is_inside_tree():
		if from == 0:
			grid.tree_entered.connect(func() -> void: _fill(home, grid, entries, from, per_frame), CONNECT_ONE_SHOT)
		return
	var upto: int = mini(entries.size(), from + maxi(1, per_frame))
	for index in range(from, upto):
		_tile(home, grid, entries[index], index)
	if upto < entries.size():
		## Held weakly: a page rebuilt before the grid is full frees it, and the next frame
		## must find it gone rather than call into a freed capture.
		var held: WeakRef = weakref(grid)
		grid.get_tree().process_frame.connect(func() -> void:
			var still: HFlowContainer = held.get_ref() as HFlowContainer
			if still != null:
				_fill(home, still, entries, upto, per_frame), CONNECT_ONE_SHOT)

static func _tile(home: Control, grid: HFlowContainer, entry: Dictionary, index: int) -> PanelContainer:
	## One place in the grid: a kept stone's tile, or the ghost of one not kept yet.
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
	tile.set_meta("skill", key)
	tile.set_meta("entry", entry)
	if DeepProfile.favorites(home.profile).has(key):
		home.tile_mark(tile, "star", DeepUi.ACCENT_HI, "A favorite: the Market marks anything that could be one")
	## Every place answers a click, one not found yet too: the lamp then says where to dig for it.
	if key == home._vault_pick:
		_ring(tile)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	DeepUi.juice(tile, 1.06)
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			DeepAudio.play("ui_tap", {"volume": 0.7})
			_pick(home, key))
	home.enter(tile, 0.012 * index)
	return tile

static func _pick(home: Control, key: String) -> void:
	## A stone picked from the grid: the ring moves and the lamp shows it. Only those redrawn.
	var was: String = home._vault_pick
	home._vault_pick = key
	if not home.redraw(["vault_lamp"]):
		home._render()
		return
	_retile(home, was)
	_retile(home, key)

static func _retile(home: Control, key: String) -> void:
	## One tile built again in its place: the ring, the star and all.
	var holder: Control = home.region_holder("vault_stones")
	var grid: HFlowContainer = holder.get_node_or_null("VaultGrid") if holder != null else null
	if grid == null or key.is_empty():
		return
	for child in grid.get_children():
		if str(child.get_meta("skill", "")) != key or child.is_queued_for_deletion():
			continue
		var at: int = child.get_index()
		home._fresh = false
		var fresh: PanelContainer = _tile(home, grid, child.get_meta("entry"), at)
		grid.move_child(fresh, at)
		grid.remove_child(child)
		child.queue_free()
		return

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
	## Settings > Comfort > Color marks: the color's shape in the corner a kept stone wears it in.
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(TILE, TILE)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(corner)
	DeepUi.corner_mark(corner, color, 20.0).modulate.a = 0.6 if seen else 0.4
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
		var lead: String = "Not yet found.\nClick for where to look."
		DeepUi.icon(frame, "question", 26, Color(DeepUi.color(color), 0.18), lead)
		DeepUi.label(column, " ", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.tooltip_text = lead
	return box

static func _lamp(home: Control, side: VBoxContainer) -> void:
	## The stone under the lamp, and what can be done with it.
	var shown: Dictionary = DeepProfile.owned(home.profile, home._vault_pick)
	if shown.is_empty() and home.profile.get("seen", []).has(home._vault_pick):
		_reference(home, side, home._vault_pick)
		return
	if shown.is_empty() and DeepProfile.known_skills(home.profile).has(home._vault_pick):
		_unfound(home, side, home._vault_pick)
		return
	if shown.is_empty():
		home.empty(side, "chest", "Nothing kept yet", "Stones you keep come here, one per skill.", 300.0)
		return
	var lamp := DeepUi.card(side, Color(DeepUi.tier_color(str(DeepStone.grade(shown).tier)), 0.5), 14)
	lamp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(lamp, 8)
	var stage := HomeParts.Showcase.new(shown, 190)
	box.add_child(stage)
	_favorite_star(home, stage, str(shown.get("skill", "")))
	StoneCard.build(box, shown, {"picture": false, "provenance": true, "text_width": 360})
	_numbers(home, box, shown)
	DeepUi.spacer(box, false)
	var skill: String = str(shown.get("skill", ""))
	_wearers(home, box, skill)
	var actions := DeepUi.hbox(box, 6)
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	var socket := DeepUi.icon_button(actions, "person", "Socket it", func() -> void:
		home.edit_loadout(current, _first_fit(home, current, skill), skill), 13, DeepUi.PAPER)
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

static func _numbers(home: Control, parent: Node, stone: Dictionary) -> void:
	## Where the stone stands on every scale it is graded by, a meter each: its carat against
	## the heaviest a stone can be, its Cut and its Clarity on their ladders, its grade out of
	## 100, and its worth against the most valuable stone in the vault.
	var box := DeepUi.vbox(parent, 5)
	DeepUi.section(box, "ladder", "By the numbers", DeepUi.ACCENT, 12)
	var carat: int = int(stone.get("carat", 1))
	var cut: int = int(stone.get("cut", 0))
	var clarity: int = int(stone.get("clarity", DeepContent.clear_index()))
	var grade: Dictionary = DeepStone.grade(stone)
	var worth: int = DeepStone.value(stone)
	var richest: int = 1
	for kept in home.profile.get("vault", {}).values():
		if kept is Dictionary and not DeepStone.is_birthstone(kept):
			richest = maxi(richest, DeepStone.value(kept))
	var pure: Color = StoneCard.TileTags.INCLUDED if clarity < DeepContent.clear_index() else StoneCard.TileTags.SPARKLE
	var rows: Array = [
		["carat", "Carat", float(carat) / float(DeepStone.carat_max()), "%d of %d ct" % [carat, DeepStone.carat_max()], DeepUi.ACCENT, "Its carat, against the heaviest a stone can be"],
		["cut", "Cut", float(cut + 1) / float(DeepContent.cuts().size()), DeepContent.cut_name(cut), StoneCard.TileTags.CUT_TONE, "Its Cut, on the ladder from the worst to the best"],
		["clarity", "Clarity", float(clarity + 1) / float(DeepContent.clarities().size()), DeepContent.clarity_name(clarity), pure, "Its Clarity, from the most included to Flawless"],
		["star", "Grade", float(grade.score) / 100.0, "%s · %d of 100" % [str(grade.name), int(grade.score)], DeepUi.tier_color(str(grade.tier)), "Its grade, out of 100"],
		["coin", "Worth", float(worth) / float(richest), "%d" % worth, DeepUi.ACCENT, "What a buyer would pay, in gold, against the most valuable stone in your vault"]]
	for row in rows:
		var line := DeepUi.hbox(box, 8)
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.tooltip_text = str(row[5])
		DeepUi.icon(line, str(row[0]), 15, row[4], str(row[5]))
		DeepUi.label(line, str(row[1]), 13, DeepUi.MUTED).custom_minimum_size.x = 54
		var meter := DeepUi.bar(line, 8.0, row[4], Color(DeepUi.LINE, 0.6))
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.set_values(clampf(float(row[2]), 0.0, 1.0))
		var value := DeepUi.label(line, str(row[3]), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
		value.custom_minimum_size.x = 104

static func _wearers(home: Control, parent: Node, skill: String) -> void:
	## Whose sockets it is set in, by portrait.
	var wearing: Array = []
	for key in DeepProfile.unlocked_characters(home.profile):
		if home.profile.characters[key].get("rail", []).has(skill):
			wearing.append(str(key))
	var row := DeepUi.hbox(parent, 6)
	if wearing.is_empty():
		DeepUi.stat(row, "person", "Not in anyone's sockets", DeepUi.DIM, 12)
		return
	DeepUi.label(row, "In", 12, DeepUi.MUTED)
	for key in wearing:
		var face := Roster.Portrait.new(key, Vector2(24, 24))
		face.tooltip_text = "In %s's sockets" % DeepContent.character_title(key)
		row.add_child(face)
	DeepUi.label(row, ", ".join(wearing.map(func(k: Variant) -> String: return str(DeepContent.character(str(k)).get("name", k)))), 12, DeepUi.MUTED)

static func _favorite_star(home: Control, holder: Control, skill: String) -> Button:
	## The favorite star in the top-right corner of the viewing area: an outline until it is
	## clicked, filled while the skill is a favorite. A favorite's tile wears the star too, and
	## the Market marks anything that could be one.
	var on: bool = DeepProfile.favorites(home.profile).has(skill)
	var star := Button.new()
	star.name = "Favorite"
	## Just the mark: the theme's padding would squeeze the icon to nothing in a box this small.
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		star.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	star.focus_mode = Control.FOCUS_NONE
	star.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	star.icon = GemIcons.texture("star" if on else "star_line", GemIcons.baked_size(48.0))
	star.expand_icon = true
	star.add_theme_color_override("icon_normal_color", DeepUi.ACCENT_HI if on else DeepUi.MUTED)
	star.add_theme_color_override("icon_hover_color", DeepUi.ACCENT_HI)
	star.add_theme_color_override("icon_pressed_color", DeepUi.ACCENT)
	star.add_theme_color_override("icon_focus_color", DeepUi.ACCENT_HI if on else DeepUi.MUTED)
	star.tooltip_text = "A favorite. Click to take the star off." if on else "Make it a favorite: its tile wears a star, and the Market marks anything that could be one."
	star.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	star.offset_left = -36
	star.offset_right = 0
	star.offset_top = 0
	star.offset_bottom = 36
	star.pressed.connect(func() -> void:
		DeepProfile.toggle_favorite(home.profile, skill)
		DeepAudio.play("ui_toggle", {"volume": 0.7})
		## The star under the lamp and on the tile; nothing else on the page shows it.
		home.changed(["vault_lamp"])
		_retile(home, skill))
	holder.add_child(star)
	return star

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
	## The emblem centred in the viewing area, the favorite star in its corner.
	var holder := Control.new()
	holder.custom_minimum_size.y = 190
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	var frame := DeepUi.center(holder)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DeepUi.icon(frame, GemIcons.emblem(key), 104, Color(hue, 0.65))
	_favorite_star(home, holder, key)
	DeepUi.title(column, str(skill.get("name", key)), 22, hue.lightened(0.25))
	var tags := DeepUi.hbox(column, 8)
	StoneCard.rarity_tag(tags, str(skill.get("rarity", "COMMON")), 13)
	DeepUi.pill(tags, "eye", "Seen, not kept", DeepUi.MUTED, 13)
	DiceIcons.build(column, DeepPatterns.describe(skill.get("trigger", {"kind": "always"}), int(stone.cut)), 18, DeepUi.PAPER)
	DeepUi.effect_text(column, DeepStone.text(stone), 13, DeepUi.PAPER, true, 360)
	DeepUi.wrap(column, "At one carat, Poor cut and Clear clarity. The stone you find will have its own qualities.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 360)
	DeepUi.spacer(column, false)
	home.enter(card, 0.05)

static func _unfound(home: Control, side: VBoxContainer, key: String) -> void:
	## A skill never found: something to chase. Its color, its rarity and the mine whose rock
	## it first comes out of; its name and its mark stay hidden until one is found.
	var skill: Dictionary = DeepContent.skill(key)
	var color: String = str(skill.get("color", "WHITE"))
	var hue: Color = DeepUi.color(color)
	var card := DeepUi.card(side, Color(hue, 0.25), 16)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := DeepUi.vbox(card, 10)
	var holder := DeepUi.center(column)
	holder.custom_minimum_size.y = 190
	DeepUi.icon(holder, "question", 96, Color(hue, 0.4))
	DeepUi.title(column, "Not yet found", 22, hue.lightened(0.25))
	var tags := DeepUi.hbox(column, 8)
	StoneCard.rarity_tag(tags, str(skill.get("rarity", "COMMON")), 13)
	var named: Dictionary = DeepContent.color(color)
	DeepUi.pill(tags, "gem", "%s · %s" % [str(named.get("name", color)), str(named.get("domain", ""))], hue, 13)
	var where := DeepUi.vbox(column, 6)
	DeepUi.section(where, "map", "Where to look", DeepUi.ACCENT, 13)
	var mine: String = ""
	for candidate in DeepContent.mines_in_order():
		if DeepContent.mine(str(candidate)).get("batch", []).has(key):
			mine = str(candidate)
			break
	if DeepContent.is_transcendent(key):
		DeepUi.stat(where, "spark", "Made at an altar, never found in the rock.", DeepUi.PAPER, 13)
	elif mine.is_empty():
		DeepUi.stat(where, "pick", "Any mine's rock can hold it.", DeepUi.PAPER, 13)
	else:
		## A mine's own batch comes out of its rock most often, and stays in the rock of every
		## mine below it (DeepForge.skill_pool).
		DeepUi.stat(where, "pick", "First found in %s" % DeepContent.mine_name(mine), DeepUi.PAPER, 13)
		DeepUi.wrap(where, "Most often there, and in the rock of every mine below it.", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 360)
		if not bool(home.profile.get("mines", {}).get(mine, {}).get("unlocked", false)):
			DeepUi.stat(where, "lock", "%s is still sealed." % DeepContent.mine_name(mine), DeepUi.DIM, 12)
	DeepUi.wrap(column, "Its name and its mark are written here the first time one is read.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 360)
	DeepUi.spacer(column, false)
	home.enter(card, 0.05)
