extends RefCounted
## Descend on the phone (docs/PHONE_UI.md, board home-descend, approved November 7, 2026).
## The mines as a list down the left, a row each in its rock's color; the chosen mine's card,
## who goes down and the way down on the right, Descend in the bottom right corner where the
## right thumb rests. The day's seam puts its rules where the list stands. The desktop's
## cross-section (mine_map.gd) is not drawn here; what it says is said in rows and capsules.

const DescendPage = preload("res://view/home/descend_page.gd")
const MineMap = preload("res://view/home/mine_map.gd")
const Roster = preload("res://view/home/roster.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const Tips = preload("res://view/ui/tips.gd")
const Swipe = preload("res://view/ui/swipe.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")

## The mine list's width: 300 points.
const LEFT: float = 600.0

static func build(home: Control, content: VBoxContainer) -> void:
	var daily: bool = not str(home.lobby.get("daily", "")).is_empty()
	var columns := DeepUi.hbox(content, int(DeepUi.pt(10)))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := DeepUi.vbox(columns, int(DeepUi.pt(3)))
	left.custom_minimum_size.x = LEFT
	_mode_switch(home, left, daily)
	var tier: int = int(home.lobby.get("hazard", 0))
	if daily:
		_daily_rules(home, left)
	else:
		if DeepProfile.hazard_top(home.profile) > 0:
			_hazard_row(home, left, tier)
		var records: Dictionary = DeepProfile.mine_records(home.profile, tier)
		var rows := DeepUi.vbox(left, int(DeepUi.pt(3)))
		rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
		## Seven rows fill the column: shorter when the Hazard row takes a row's room.
		var tall: float = DeepUi.pt(35) if DeepProfile.hazard_top(home.profile) > 0 else DeepUi.pt(39)
		for key in DeepContent.mines_in_order():
			_mine_row(home, rows, str(key), records, tier, tall)
	home.enter(left)
	var right := DeepUi.vbox(columns, int(DeepUi.pt(6)))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if daily:
		_daily_side(home, right)
	else:
		_stratum(home, right, tier)
		_going_down(home, right)
	DeepUi.spacer(right, false)
	_actions(home, right, daily)

# --- the left column -------------------------------------------------------------------------------

static func _mode_switch(home: Control, parent: VBoxContainer, daily: bool) -> void:
	## Expedition or the day's seam, as two halves of one switch. The host chooses.
	var row := DeepUi.hbox(parent, int(DeepUi.pt(3)))
	## A sideways flick over the page turns between them too (view/ui/swipe.gd).
	row.set_meta("swipe_tabs", true)
	for entry in [["", "descend", "Expedition"], ["daily", "calendar", "Daily dig"]]:
		var mode: String = str(entry[0])
		var on: bool = (mode == "daily") == daily
		var button := DeepUi.tab_button(row, str(entry[1]), str(entry[2]), on, func() -> void:
			if home.is_host:
				home.daily_chosen.emit(DeepEconomy.today() if mode == "daily" else ""), 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = DeepUi.pt(34)
		if not home.is_host and not on:
			button.disabled = true
			button.tooltip_text = "The host chooses where the party goes."
		if mode == "daily" and not daily and DeepEconomy.daily_state(home.profile) == "fresh":
			HomeParts.pin(button, 0, home.PIP_NEW, true)

static func _row_style(tone: Color, on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tone.darkened(0.68)
	style.bg_color.a = 0.92
	style.border_color = DeepUi.ACCENT if on else Color(1, 1, 1, 0.05)
	style.set_border_width_all(int(DeepUi.pt(1.5)) if on else 1)
	style.set_corner_radius_all(int(DeepUi.pt(5)))
	style.content_margin_left = DeepUi.pt(8)
	style.content_margin_right = DeepUi.pt(8)
	style.content_margin_top = DeepUi.pt(3)
	style.content_margin_bottom = DeepUi.pt(3)
	if on:
		style.shadow_color = Color(DeepUi.ACCENT, 0.25)
		style.shadow_size = int(DeepUi.pt(5))
	return style

static func _mine_row(home: Control, parent: VBoxContainer, key: String, records: Dictionary, tier: int, tall: float) -> void:
	## One mine: its numeral in a ring of its color, its name, where the player stands in it,
	## and what its stones weigh. A sealed mine is dimmed and locked. Tap to choose it.
	var mine: Dictionary = DeepContent.mine(key)
	var record: Dictionary = records.get(key, {})
	var open: bool = bool(record.get("unlocked", false))
	var chosen: bool = key == str(home.lobby.get("mine", DeepContent.starter_mine()))
	var tone: Color = Color(str(mine.get("palette", "c9a26b")))
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style(tone, chosen))
	row.custom_minimum_size.y = tall
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	if not open:
		row.modulate = Color(1, 1, 1, 0.66)
	parent.add_child(row)
	var line := DeepUi.hbox(row, int(DeepUi.pt(8)))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_Numeral.new(MineMap.numeral(key), tone, open))
	var words := DeepUi.vbox(line, -4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var named := DeepUi.label(words, str(mine.get("name", key)), 14, DeepUi.PAPER if open else DeepUi.MUTED)
	named.add_theme_font_override("font", DeepUi.bold_font())
	var under: String
	if not open:
		under = "Sealed · " + MineMap.sealed_hint(key, tier).trim_prefix("Beat the bottom of ").trim_suffix(" to break it open.").replace(" on Hazard", " · Hazard")
		under = "Sealed · beat " + under.trim_prefix("Sealed · ") if under.begins_with("Sealed · The") or under.begins_with("Sealed · the") else under
	elif DeepContent.is_endless(key):
		under = "Endless · deepest %d" % int(record.get("deepest", 0))
	elif bool(record.get("boss", false)):
		under = "Beaten · deepest %d of %d" % [int(record.get("deepest", 0)), DeepContent.mine_bottom(key)]
	else:
		under = "Open · deepest %d of %d" % [int(record.get("deepest", 0)), DeepContent.mine_bottom(key)]
	var sub := DeepUi.label(words, under, 11, Color("c9b48a") if open else DeepUi.DIM)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not open:
		DeepUi.icon(line, "lock", DeepUi.pt(11), DeepUi.MUTED).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := DeepUi.pill(line, "gem", MineMap.carat_words(key, tier).replace(" ct", " ct"), tone.lightened(0.3), 11)
	band.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = "%s\n%s" % [str(mine.get("name", key)), str(mine.get("text", "")) if open else MineMap.sealed_hint(key, tier)]
	if open and home.is_host and not chosen:
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(event: InputEvent) -> void:
			## Not the lift that ends a flick across the page (it turns the page's tabs).
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not Tips.held(row) and not Swipe.flicked():
				DeepAudio.play("ui_confirm", {"volume": 0.7})
				home.mine_chosen.emit(key))

class _Numeral extends Control:
	## A mine's numeral in a ring of its color, as the cross-section draws it.
	var text: String = ""
	var tone: Color = Color.WHITE
	var lit: bool = true
	func _init(numeral: String, color: Color, open: bool) -> void:
		text = numeral
		tone = color
		lit = open
		custom_minimum_size = Vector2(DeepUi.pt(26), DeepUi.pt(26))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(centre, r, Color(0, 0, 0, 0.35))
		draw_arc(centre, r, 0, TAU, 32, Color(tone, 1.0 if lit else 0.45), DeepUi.pt(1.2), true)
		var font: Font = DeepUi.caps_font()
		var px: int = DeepUi.caps_size(10)
		var wide: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font, Vector2(centre.x - wide * 0.5, centre.y + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(tone, 1.0 if lit else 0.5))

static func _hazard_row(home: Control, parent: VBoxContainer, tier: int) -> void:
	## The Hazard tier the party goes down on, its newest rule and its pips; a tap opens the
	## ladder (a panel down the right side) to pick another.
	var row := PanelContainer.new()
	var style := _row_style(Color("8a2a2a") if tier > 0 else DeepUi.LINE, false)
	style.border_color = DeepUi.BAD if tier > 0 else DeepUi.LINE
	style.set_border_width_all(int(DeepUi.pt(1)))
	row.add_theme_stylebox_override("panel", style)
	row.custom_minimum_size.y = DeepUi.pt(36)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(row)
	var line := DeepUi.hbox(row, int(DeepUi.pt(6)))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DeepUi.icon(line, "flame", DeepUi.pt(15), DeepUi.BAD if tier > 0 else DeepUi.MUTED).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := DeepUi.vbox(line, -4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var named := DeepUi.label(words, "Hazard %d" % tier if tier > 0 else "No hazards", 13, Color("ff8f7a") if tier > 0 else DeepUi.PAPER)
	named.add_theme_font_override("font", DeepUi.bold_font())
	var newest: String = str(DeepContent.hazard_tier(tier).get("name", "")) if tier > 0 else "Hazard 0"
	var said := DeepUi.label(words, ("%s +%d" % [newest, tier - 1]) if tier > 1 else newest, 11, DeepUi.MUTED)
	said.clip_text = true
	said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var pips := _Pips.new(DeepProfile.hazard_top(home.profile), tier)
	line.add_child(pips)
	DeepUi.icon(line, "next", DeepUi.pt(10), DeepUi.MUTED).mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = MineMap.hazard_list(tier)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not Tips.held(row) and not Swipe.flicked():
			DeepAudio.play("ui_open")
			_hazard_sheet(home, tier))

class _Pips extends Control:
	## The tiers as small diamonds, the ones the party carries lit, the top one ringed.
	var top: int = 0
	var tier: int = 0
	func _init(top_tier: int, now: int) -> void:
		top = top_tier
		tier = now
		custom_minimum_size = Vector2(DeepUi.pt(8.5) * float(maxi(1, top)), DeepUi.pt(12))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var half: float = DeepUi.pt(3.2)
		for index in range(top):
			var centre := Vector2(DeepUi.pt(8.5) * (float(index) + 0.5), size.y * 0.5)
			var points := PackedVector2Array([centre + Vector2(0, -half), centre + Vector2(half, 0), centre + Vector2(0, half), centre + Vector2(-half, 0)])
			var lit: bool = index < tier
			draw_colored_polygon(points, DeepUi.BAD if lit else Color(DeepUi.ACCENT_DIM, 0.4))
			if index == tier - 1:
				points.append(points[0])
				draw_polyline(points, DeepUi.ACCENT_HI, 2.0, true)

static func _hazard_sheet(home: Control, tier: int) -> void:
	## Every tier, newest rule each, the party's lit; a tap picks one (the host's choice).
	var panel := _side_panel(home, "flame", "Hazard", DeepUi.BAD)
	var box: VBoxContainer = panel.get_meta("box")
	DeepUi.wrap(box, "Each tier adds one rule to every mine. Reach the Rift's bottom to open the next.", 12, DeepUi.MUTED)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_meta("may_scroll", true)
	box.add_child(scroll)
	var list := DeepUi.vbox(scroll, int(DeepUi.pt(4)))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top: int = DeepProfile.hazard_top(home.profile)
	var cap: int = DescendPage.party_cap(home.lobby)
	for index in range(0, DeepContent.hazard_max() + 1):
		var entry: Dictionary = DeepContent.hazard_tier(index) if index > 0 else {"name": "No hazards", "text": "The mines as they were before the Rift."}
		var open: bool = index <= top
		var pickable: bool = open and index <= cap and home.is_host
		var card := PanelContainer.new()
		var style := _row_style(Color("8a2a2a") if index > 0 else DeepUi.LINE, index == tier)
		card.add_theme_stylebox_override("panel", style)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		if not open:
			card.modulate = Color(1, 1, 1, 0.5)
		list.add_child(card)
		var line := DeepUi.hbox(card, int(DeepUi.pt(8)))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var number := DeepUi.label(line, str(index), 15, Color("ff8f7a") if index > 0 else DeepUi.MUTED)
		number.add_theme_font_override("font", DeepUi.bold_font())
		number.custom_minimum_size.x = DeepUi.pt(16)
		var words := DeepUi.vbox(line, 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var named := DeepUi.label(words, str(entry.get("name", "")) if open else "Locked", 13, DeepUi.PAPER)
		named.add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.wrap(words, str(entry.get("text", "")) if open else "Reach the Rift's bottom on Hazard %d." % (index - 1), 11, DeepUi.MUTED)
		if pickable and index != tier:
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var picked: int = index
			card.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
					DeepAudio.play("ui_confirm", {"volume": 0.7})
					home.hazard_chosen.emit(picked))

static func _side_panel(home: Control, glyph: String, title: String, tone: Color) -> PanelContainer:
	## A panel down the right side of the workshop, the screen's full height, over the page; a
	## tap anywhere off it (or Close) puts it away. The panel's column is its "box" meta.
	var overlay: Control = home._overlay
	DeepUi.clear(overlay)
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			DeepUi.clear(overlay))
	overlay.add_child(catcher)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DeepUi.LEDGER_FILL
	style.border_color = DeepUi.ACCENT_DIM
	style.border_width_left = int(DeepUi.pt(1.5))
	style.content_margin_left = DeepUi.pt(10)
	style.content_margin_right = DeepUi.safe_right + DeepUi.pt(8)
	style.content_margin_top = DeepUi.pt(8)
	style.content_margin_bottom = DeepUi.safe_bottom + DeepUi.pt(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -(DeepUi.pt(300) + DeepUi.safe_right)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	var box := DeepUi.vbox(panel, int(DeepUi.pt(6)))
	var head := DeepUi.hbox(box, int(DeepUi.pt(6)))
	DeepUi.section(head, glyph, title, tone, 11).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shut := DeepUi.icon_button(head, "cross_out", "", func() -> void: DeepUi.clear(overlay), 13, DeepUi.PAPER)
	shut.custom_minimum_size = Vector2(DeepUi.pt(36), DeepUi.pt(30))
	panel.set_meta("box", box)
	return panel

# --- the right column: the expedition --------------------------------------------------------------

static func _card(parent: Node, edge: Color) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := DeepUi.ledger(DeepUi.LEDGER_FILL, edge, 10, int(DeepUi.pt(7)), int(DeepUi.pt(1.5)), 4)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(card)
	return DeepUi.vbox(card, int(DeepUi.pt(3)))

static func _stratum(home: Control, parent: VBoxContainer, tier: int) -> void:
	## The chosen mine: its stratum, its name, what it is, its crowns along the track of its
	## depth with what each pays, and how the player stands in it.
	var key: String = str(home.lobby.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(key)
	var record: Dictionary = DeepProfile.mine_records(home.profile, tier).get(key, {})
	var box := _card(parent, Color(DeepUi.ACCENT, 0.55))
	DeepUi.section(box, "descend", "Stratum %s" % MineMap.numeral(key), DeepUi.ACCENT, 11)
	DeepUi.title(box, str(mine.get("name", key)), 20, DeepUi.PAPER)
	DeepUi.wrap(box, str(mine.get("text", "")), 12, DeepUi.MUTED)
	if not DeepContent.is_endless(key):
		box.add_child(_Track.new(home.profile, key, record))
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", int(DeepUi.pt(3)))
	facts.add_theme_constant_override("v_separation", int(DeepUi.pt(3)))
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(facts)
	DeepUi.pill(facts, "stairs", "deepest %d" % int(record.get("deepest", 0)), DeepUi.INFO, 11)
	if DeepContent.is_endless(key):
		DeepUi.pill(facts, "crown", "endless", DeepUi.ACCENT, 11, "A Warden every %d floors, and no bottom." % DeepDescent.warden_every(mine))
	else:
		var crowns: int = mine.get("warden_depths", []).size() + 1
		DeepUi.pill(facts, "crown", "%d of %d" % [mini(record.get("wardens", []).size(), crowns), crowns], DeepUi.ACCENT, 11)
	DeepUi.pill(facts, "pick", DeepUi.plural(int(record.get("runs", 0)), "run"), DeepUi.MUTED, 11)
	var band: Dictionary = DeepForge.carat_band(DeepForge.at_hazard(mine, tier), 1)
	if not band.is_empty():
		DeepUi.pill(facts, "gem", "up to %d ct" % int(band.cap), DeepUi.PAPER, 11)
	if key != DeepContent.starter_mine():
		DeepUi.pill(facts, "ore", "%d pyrite" % int(mine.get("start_pyrite", 0)), DeepUi.ORE, 11,
			"Starting here costs a fare of %d gold, paid by each delver at the shaft head." % DeepEconomy.fare(key))
	home.enter(box.get_parent())

class _Track extends Control:
	## The mine's depth as a line, the deepest reached lit along it, a crown at each Warden and
	## at the boss (gold once beaten, red until), and what each still pays over it.
	var profile: Dictionary = {}
	var key: String = ""
	var record: Dictionary = {}
	func _init(p: Dictionary, mine_key: String, r: Dictionary) -> void:
		profile = p
		key = mine_key
		record = r
		custom_minimum_size = Vector2(0, DeepUi.pt(30))
		mouse_filter = Control.MOUSE_FILTER_PASS
		var mine: Dictionary = DeepContent.mine(key)
		var lines: Array = []
		var depths: Array = mine.get("warden_depths", []).duplicate()
		depths.append(DeepContent.mine_bottom(key))
		for index in range(depths.size()):
			lines.append("Depth %d: %s" % [int(depths[index]), "the final boss" if index == depths.size() - 1 else "a Warden"])
		tooltip_text = "\n".join(lines)
	func _draw() -> void:
		var mine: Dictionary = DeepContent.mine(key)
		var bottom: int = maxi(1, DeepContent.mine_bottom(key))
		var deepest: int = int(record.get("deepest", 0))
		var beaten: Array = record.get("wardens", [])
		var y: float = size.y - DeepUi.pt(9)
		var left: float = DeepUi.pt(10)
		var width: float = size.x - DeepUi.pt(20)
		draw_rect(Rect2(Vector2(left, y - DeepUi.pt(2)), Vector2(width, DeepUi.pt(4))), Color("2a2f40"))
		if deepest > 0:
			draw_rect(Rect2(Vector2(left, y - DeepUi.pt(2)), Vector2(width * clampf(float(deepest) / float(bottom), 0.0, 1.0), DeepUi.pt(4))), DeepUi.ACCENT)
		var crowns: Array = mine.get("warden_depths", []).duplicate()
		crowns.append(bottom)
		for index in range(crowns.size()):
			var boss: bool = index == crowns.size() - 1
			var depth: int = int(crowns[index])
			var won: bool = bool(record.get("boss", false)) if boss else beaten.any(func(d: Variant) -> bool: return absi(int(d) - depth) <= 1)
			var at := Vector2(left + width * float(depth) / float(bottom), y)
			var r: float = DeepUi.pt(9 if boss else 8)
			draw_circle(at, r, Color("1a1f2e"))
			draw_arc(at, r, 0, TAU, 32, DeepUi.ACCENT if won else DeepUi.BAD, DeepUi.pt(1.2), true)
			var glyph: Texture2D = DeepUi.GemIcons.texture("crown", DeepUi.GemIcons.baked_size(r * 1.6))
			draw_texture_rect(glyph, Rect2(at - Vector2.ONE * r * 0.55, Vector2.ONE * r * 1.1), false, DeepUi.ACCENT if won else DeepUi.BAD)
			var purse: int = 0
			if boss:
				purse = 0 if profile.get("conquest_paid", []).has(key) else DeepEconomy.conquest_purse(key)
			else:
				purse = 0 if profile.get("warden_paid", []).has(DeepProfile.warden_mark(key, index)) else DeepEconomy.warden_purse(key, index)
			var words: String = ("+%d" % purse) if purse > 0 else ("✓" if won else "")
			if words.is_empty():
				continue
			var font: Font = DeepUi.bold_font()
			var px: int = DeepUi.readable(11)
			var wide: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var tag := Rect2(Vector2(at.x - wide * 0.5 - DeepUi.pt(5), at.y - r - DeepUi.pt(17)), Vector2(wide + DeepUi.pt(10), DeepUi.pt(14)))
			tag.position.x = clampf(tag.position.x, 0.0, size.x - tag.size.x)
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.12, 0.10, 0.05)
			box.border_color = Color(DeepUi.ACCENT, 0.7)
			box.set_border_width_all(1)
			box.set_corner_radius_all(int(DeepUi.pt(7)))
			draw_style_box(box, tag)
			draw_string(font, Vector2(tag.position.x + DeepUi.pt(5), tag.position.y + tag.size.y * 0.5 + px * 0.36), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, DeepUi.ACCENT_HI)

static func _going_down(home: Control, parent: VBoxContainer) -> void:
	## Who goes down: a face for every delver (a tap picks one, a hold opens their page), the
	## chosen one's name, health and passive, and their rail drawn small (a tap opens it).
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	var character: Dictionary = DeepContent.character(current)
	var box := _card(parent, DeepUi.LINE)
	var head := DeepUi.hbox(box, int(DeepUi.pt(6)))
	DeepUi.section(head, "person", "Going down as", DeepUi.ACCENT, 11).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var seed := DeepUi.button(head, "Seed", func() -> void: _seed_panel(home), 11)
	DeepUi.ledger_button(seed, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 6)
	seed.custom_minimum_size = Vector2(DeepUi.pt(50), DeepUi.pt(DeepUi.FINGER_LEAST))
	seed.tooltip_text = "Go down a seed of your own: the same mine, the same rooms and stones."
	var faces := DeepUi.hbox(box, int(DeepUi.pt(5)))
	for key in DeepContent.characters_in_unlock_order():
		var unlocked: bool = bool(home.profile.get("characters", {}).get(str(key), {}).get("unlocked", false))
		var portrait := Roster.Portrait.new(str(key), Vector2(DeepUi.pt(34), DeepUi.pt(34)), not unlocked, str(key) == current, false)
		portrait.tooltip_text = DeepContent.character_title(str(key)) if unlocked else "Locked. " + Roster.unlock_hint(str(key)) + "."
		faces.add_child(portrait)
		if unlocked:
			portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var picked: String = str(key)
			var their_page := func() -> void:
				DeepAudio.play("ui_tap")
				home._roster_pick = picked
				home._roster_view = "dossier"
				home._bench_socket = -1
				home.open("delvers", true)
			Tips.hold(portrait, their_page)
			portrait.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and picked != current and not Tips.held(portrait):
					home.choose_character(picked))
		if bool(home.profile.get("characters", {}).get(str(key), {}).get("fresh", false)):
			HomeParts.pin(portrait, 0, home.PIP_NEW, true)
	var named := DeepUi.hbox(box, int(DeepUi.pt(5)))
	var title := DeepUi.label(named, DeepContent.character_title(current), 14, DeepUi.PAPER)
	title.add_theme_font_override("font", DeepUi.bold_font())
	DeepUi.pill(named, "heart", "%d" % int(character.get("hp", 0)), DeepUi.HP, 11)
	DeepUi.pill(named, "spark", str(character.get("passive", {}).get("name", "Passive")), DeepUi.ACCENT, 11, str(character.get("passive", {}).get("text", "")))
	var rail := DeepUi.hbox(box, int(DeepUi.pt(3)))
	var loadout: Dictionary = DeepProfile.loadout(home.profile, current)
	home.socket_strip(rail, current, loadout, DeepUi.pt(26), false, func(index: int) -> void: home.edit_loadout(current, index))
	DeepUi.spacer(rail)
	var light: float = DescendPage._loadout_luck(home, current)
	var empty: int = 0
	for index in range(DeepProfile.open_sockets(home.profile, current)):
		if index < loadout.rail.size() and not loadout.rail[index] is Dictionary:
			empty += 1
	if light != 0.0:
		DeepUi.stat(rail, "gem", "%+d luck" % int(light), DeepUi.GOOD if light > 0.0 else DeepUi.BAD, 11, MineMap.luck_words(light).strip_edges())
	elif empty > 0:
		DeepUi.stat(rail, "gem", "%d empty" % empty, DeepUi.ACCENT, 11)
	else:
		DeepUi.label(rail, "Tap to change ›", 11, DeepUi.MUTED)
	home.enter(box.get_parent(), 0.05)

static func _seed_panel(home: Control) -> void:
	## The seed, typed on a panel of its own: kept until the next run starts.
	var panel := _side_panel(home, "spark", "Seed", DeepUi.ACCENT)
	var box: VBoxContainer = panel.get_meta("box")
	DeepUi.wrap(box, "A seed of your own: the same mine, the same rooms and the same stones for anyone who goes down it. Leave it empty for a new one.", 12, DeepUi.MUTED)
	var typed: String = home._seed.text if home._seed != null and is_instance_valid(home._seed) else ""
	home._seed = LineEdit.new()
	home._seed.placeholder_text = "blank for a new one"
	home._seed.text = typed
	home._seed.custom_minimum_size.y = DeepUi.pt(36)
	home._seed.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	DeepUi.set_text_size(home._seed, 14)
	box.add_child(home._seed)

# --- the daily dig -----------------------------------------------------------------------------------

static func _daily_rules(home: Control, parent: VBoxContainer) -> void:
	## The day's rules where the mine list stands: its rail rule, hazard, blessing and twist.
	var date: String = str(home.lobby.get("daily", ""))
	if date.is_empty():
		date = DeepEconomy.today()
	var plan: Dictionary = DeepEconomy.daily_plan(date)
	var mine: Dictionary = DeepContent.mine(str(plan.mine))
	var box := _card(parent, Color(DeepUi.ACCENT, 0.4))
	box.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := DeepUi.hbox(box, int(DeepUi.pt(6)))
	DeepUi.section(head, "calendar", "The daily dig", DeepUi.ACCENT, 11).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left: int = DeepEconomy.seconds_to_tomorrow()
	DeepUi.stat(head, "hourglass", "%dh %02dm" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 11, "A new seam opens every day at midnight UTC.")
	DeepUi.title(box, "%s, and on down" % str(mine.get("name", plan.mine)), 17, DeepUi.PAPER)
	DeepUi.label(box, "The same seam for everyone today.", 11, DeepUi.MUTED)
	for key in [str(plan.rail)] + plan.get("mods", []):
		var mod: Dictionary = DeepEconomy.daily_mod(str(key))
		var kind: String = str(mod.get("kind", "hazard"))
		var hue: Color = DescendPage._daily_tone(kind)
		var line := DeepUi.hbox(box, int(DeepUi.pt(5)))
		DeepUi.icon(line, str(mod.get("glyph", "spark")), DeepUi.pt(14), hue).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var words := DeepUi.vbox(line, -2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name: String = str(mod.get("name", key))
		if str(key) == "DROUGHT" and plan.has("drought"):
			name = "%s: no %s" % [name, str(DeepContent.color(str(plan.drought)).get("name", plan.drought))]
		var title_line := DeepUi.hbox(words, int(DeepUi.pt(4)))
		var named := DeepUi.label(title_line, name, 12, hue.lightened(0.1))
		named.add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.label(title_line, str(DescendPage.DAILY_KIND_WORDS.get(kind, "")), 11, DeepUi.DIM)
		DeepUi.wrap(words, str(mod.get("text", "")), 11, DeepUi.MUTED)

static func _daily_side(home: Control, parent: VBoxContainer) -> void:
	## The delver the day lends, and how the day pays.
	var date: String = str(home.lobby.get("daily", ""))
	if date.is_empty():
		date = DeepEconomy.today()
	var plan: Dictionary = DeepEconomy.daily_plan(date)
	var seat: int = maxi(0, home.lobby.get("order", []).find(home.local_id))
	var character: String = DeepEconomy.daily_lapidary(plan)
	var box := _card(parent, DeepUi.LINE)
	DeepUi.section(box, "person", "Lent for the day", DeepUi.ACCENT, 11)
	var row := DeepUi.hbox(box, int(DeepUi.pt(8)))
	row.add_child(Roster.Portrait.new(character, Vector2(DeepUi.pt(48), DeepUi.pt(48))))
	var facts := DeepUi.vbox(row, 0)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := DeepUi.label(facts, DeepContent.character_title(character), 14, DeepUi.PAPER)
	title.add_theme_font_override("font", DeepUi.bold_font())
	DeepUi.wrap(facts, "The whole party goes down as this delver, with the stones and dice the day lends. Nothing of yours goes down.", 11, DeepUi.MUTED)
	var rail := DeepUi.hbox(box, int(DeepUi.pt(3)))
	var stones: Array = DeepEconomy.daily_rail(plan, character, seat)
	var sockets: Array = DeepContent.character(character).get("sockets", [])
	for index in range(sockets.size()):
		var stone: Variant = stones[index] if index < stones.size() else null
		home.kit_socket(rail, str(sockets[index]), stone if stone is Dictionary else {}, DeepUi.pt(26))
	var carried: String = str(plan.get("birthstone", character)) if plan.get("mods", []).has("BORROWED_BIRTHSTONE") else character
	home.kit_socket(rail, "BIRTHSTONE", DeepStone.birthstone(carried), DeepUi.pt(26))
	var pays := _card(parent, DeepUi.LINE)
	var standing := DeepUi.hbox(pays, int(DeepUi.pt(6)))
	var tier: int = int(home.lobby.get("hazard", 0))
	DeepUi.stat(standing, "coin", "Paid in gold for your score" if tier <= 0 else "Score paid ×%s on Hazard %d" % [String.num(DeepEconomy.daily_gold_mult(tier), 2), tier], DeepUi.ACCENT, 11).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var best: Dictionary = DeepEconomy.daily_best(home.profile, date)
	match DeepEconomy.daily_state(home.profile, date):
		"locked":
			DeepUi.pill(standing, "lock", "Unpaid until the Quarry falls", DeepUi.DIM, 11)
		"played":
			DeepUi.pill(standing, "star", "Best today %d" % int(best.score), DeepUi.GOOD, 11)
		_:
			DeepUi.pill(standing, "star", "Not dug yet today", DeepUi.ACCENT, 11)

# --- the way down ------------------------------------------------------------------------------------

static func _actions(home: Control, parent: VBoxContainer, daily: bool) -> void:
	## The way down in the bottom right corner (48 points), Insure beside it; for a guest, Ready.
	## What would stop the party is said over it.
	var lobby: Dictionary = home.lobby
	var me: Dictionary = lobby.members.get(home.local_id, {})
	var order: Array = lobby.get("order", [])
	if order.size() > 1:
		var ready_count: int = order.filter(func(id: Variant) -> bool:
			return str(id) == str(lobby.get("host", "p0")) or bool(lobby.members.get(id, {}).get("ready", false))).size()
		DeepUi.stat(parent, "party", "A party of %d · %d ready" % [order.size(), ready_count], DeepUi.GOOD if ready_count == order.size() else DeepUi.MUTED, 11)
	var row := DeepUi.hbox(parent, int(DeepUi.pt(6)))
	if daily:
		var date: String = str(lobby.get("daily", ""))
		var state: String = DeepEconomy.daily_state(home.profile, date)
		if not home.is_host:
			var ready := DeepUi.primary(row, "check", "Unready" if bool(me.get("ready", false)) else "I'm ready", func() -> void: home.member_changed.emit({"ready": not bool(me.get("ready", false))}), 15, DeepUi.GOOD)
			ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ready.custom_minimum_size.y = DeepUi.pt(44)
			ready.disabled = home.status != "joined"
			return
		var words: String = "Dig today's seam" if state == "fresh" else ("Dig it again" if state == "played" else "Dig today's seam (unpaid)")
		var go := DeepUi.primary(row, "calendar", words, func() -> void: home.depart_requested.emit(0), 16)
		go.name = "Descend"
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.custom_minimum_size.y = DeepUi.pt(48)
		DeepUi.voice(go, "depart")
		go.disabled = not home.can_start or bool(lobby.get("started", false))
		return
	var who: String = str(DeepContent.character(str(home.profile.get("current_character", ""))).get("name", "you"))
	var tier: int = int(lobby.get("hazard", 0))
	var insured: bool = bool(home.profile.get("outfit", {}).get("insure", false))
	var cost: int = DeepEconomy.departure(home.chosen_mine(), insured)
	var purse: int = int(home.profile.get("gold", 0))
	var short: Array = order.filter(func(id: Variant) -> bool: return home.member_short(lobby.members.get(id, {})))
	if not short.is_empty():
		var names: Array = short.map(func(id: Variant) -> String: return "You" if str(id) == home.local_id else home.member_name(str(id)))
		_warn(parent, "coin", "%s can't pay the fare to %s." % [" and ".join(names), DeepContent.mine_name(home.chosen_mine())])
	elif not DescendPage._hazard_blocked(home).is_empty():
		_warn(parent, "lock", "Not everyone has %s open on Hazard %d." % [DeepContent.mine_name(home.chosen_mine()), tier])
	elif not home.can_start and home.is_host:
		DeepUi.stat(parent, "hourglass", "Waiting for everyone to be ready.", DeepUi.MUTED, 11)
	parent.move_child(row, parent.get_child_count() - 1)
	var cover := DescendPage._insurance_toggle(home, row, insured)
	cover.custom_minimum_size.y = DeepUi.pt(48)
	if not home.is_host:
		var ready := DeepUi.primary(row, "check", "Unready" if bool(me.get("ready", false)) else "Ready as %s" % who,
			func() -> void: home.member_changed.emit({"ready": not bool(me.get("ready", false))}), 15, DeepUi.GOOD)
		if cost > 0 and not bool(me.get("ready", false)):
			DeepUi.priced(ready, str(cost))
		ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ready.custom_minimum_size.y = DeepUi.pt(48)
		ready.disabled = home.status != "joined"
		if purse < cost:
			_warn(parent, "coin", "You can't pay the %d gold fare. The host needs to pick a mine you can afford." % cost)
		return
	var go := DeepUi.primary(row, "descend", "Descend as %s" % who + (" · Hazard %d" % tier if tier > 0 else ""), func() -> void:
		home.depart_requested.emit(home.seed_value()), 16, DeepUi.GOOD)
	if cost > 0:
		DeepUi.priced(go, str(cost), 13)
	go.name = "Descend"
	DeepUi.voice(go, "depart")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size.y = DeepUi.pt(48)
	## A long name and a Hazard tier are cut short rather than pushing the page wider.
	go.clip_text = true
	go.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	go.disabled = not home.can_start or bool(lobby.get("started", false))
	if not go.disabled:
		DeepUi.breathe(go, 0.82, 2.0)

static func _warn(parent: Node, glyph: String, text: String) -> void:
	var row := DeepUi.stat(parent, glyph, text, Color("ffb04a"), 11)
	var words: Label = row.get_node("Value")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
