extends RefCounted
## The stone browser: the one way stones are sorted, filtered and found, wherever a stone is
## chosen (the vault, a delver's sockets, the Wheel and the Oven, the contract bench). One row
## of controls: the sort and its direction, a dot for each color, the rarity, and a search box
## that matches a skill's name, its color, its rarity, what is frozen inside it, the mine it
## came from and the words of what it does ("star", "poison", "Seeps"). The sort is shared by
## every place the browser is used; the filters are each place's own.
##
## `home` is whoever keeps the settings: the workshop, or down the mine the run dock's bag
## (view/run/run_dock.gd). It provides `browse` (a Dictionary the settings live in), `_pages`
## (page numbers by list, reset when the sort or a filter changes), `redraw(keys) -> bool`
## (draws just those parts again, or false) and `_render()` (draws the whole page again).

const StoneCard = preload("res://view/gems/stone_card.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Roster = preload("res://view/home/roster.gd")

const SORTS: Array = [["grade", "Grade"], ["carat", "Carat"], ["cut", "Cut"], ["clarity", "Clarity"], ["worth", "Worth"], ["rarity", "Rarity"],
	["color", "Color"], ["name", "Name"], ["found", "Date found"], ["mine", "Mine found in"]]
const RARITIES: Array = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY", "MYTHIC", "TRANSCENDENT"]
const COLORS: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE", "OPAL"]

static func settings(home: Control, context: String) -> Dictionary:
	## This place's filters, with the sort every place shares.
	if not home.browse.has("_sort"):
		home.browse["_sort"] = {"sort": "grade", "desc": true}
	if not home.browse.has(context):
		home.browse[context] = {"colors": [], "rarity": "", "query": "", "layout": "grid", "ghosts": true}
	var out: Dictionary = home.browse[context]
	out.sort = str(home.browse["_sort"].sort)
	out.desc = bool(home.browse["_sort"].desc)
	return out

static func _change(home: Control, context: String, key: String, value: Variant) -> void:
	if key in ["sort", "desc"]:
		home.browse["_sort"][key] = value
	else:
		settings(home, context)[key] = value
	home._pages[context + "_page"] = 0
	DeepAudio.play("ui_tap", {"volume": 0.6})
	## Where the place laid its toolbar and its stones out as parts of their own (the vault),
	## only those are drawn again.
	if not home.redraw([context + "_tools", context + "_stones"]):
		home._render()

# --- the controls --------------------------------------------------------------------------------

static func toolbar(home: Control, parent: Node, context: String, opts: Dictionary = {}) -> HBoxContainer:
	## The browser's one row of controls. `opts`: `layouts` (offer grid and list), `ghosts`
	## (offer showing skills not yet kept), `rarity` (offer the rarity filter), `compact`,
	## `sorts` (only these sort keys, in this order; every sort by default).
	var s: Dictionary = settings(home, context)
	var compact: bool = bool(opts.get("compact", false))
	var row := DeepUi.hbox(parent, 6)
	_sorter(home, row, context, s, compact, opts.get("sorts", []))
	_direction(home, row, context, s)
	DeepUi.gap(row, 2)
	_dots(home, row, context, s)
	if bool(opts.get("rarity", true)):
		var rarity := OptionButton.new()
		rarity.focus_mode = Control.FOCUS_NONE
		rarity.add_item("Any rarity", 0)
		for index in range(RARITIES.size()):
			rarity.add_item(str(RARITIES[index]).capitalize(), index + 1)
			if str(RARITIES[index]) == str(s.rarity):
				rarity.select(index + 1)
		DeepUi.set_text_size(rarity, 13)
		rarity.item_selected.connect(func(index: int) -> void:
			DeepAudio.play("ui_tap")
			_change(home, context, "rarity", "" if index == 0 else str(RARITIES[index - 1])))
		row.add_child(rarity)
	_search(home, row, context, s, compact)
	if bool(opts.get("ghosts", false)):
		var ghosts := CheckButton.new()
		ghosts.text = "Unfound"
		ghosts.tooltip_text = "Show the skills you have not kept yet"
		ghosts.button_pressed = bool(s.ghosts)
		ghosts.focus_mode = Control.FOCUS_NONE
		DeepUi.set_text_size(ghosts, 13)
		ghosts.toggled.connect(func(on: bool) -> void: _change(home, context, "ghosts", on))
		row.add_child(ghosts)
	if bool(opts.get("layouts", false)):
		for entry in [["grid", "gem", "Grid"], ["list", "ladder", "List"]]:
			var layout: String = str(entry[0])
			var b := DeepUi.tab_button(row, str(entry[1]), "", str(s.layout) == layout, func() -> void: _change(home, context, "layout", layout), 13)
			b.tooltip_text = str(entry[2])
	return row

static func toolbar_phone(home: Control, parent: Node, context: String, opts: Dictionary = {}) -> HBoxContainer:
	## The phone's toolbar (docs/PHONE_UI.md): the sort as a drop-down and its direction, the
	## color dots, then (asked for in `opts`) rarity, a loupe for the search, and Unfound.
	var s: Dictionary = settings(home, context)
	var row := DeepUi.hbox(parent, int(DeepUi.pt(4)))
	var pick: Button = _sort_dropdown(home, row, context, s, opts.get("sorts", []))
	pick.custom_minimum_size = Vector2(DeepUi.pt(74), DeepUi.pt(30))
	var way := _direction(home, row, context, s)
	way.focus_mode = Control.FOCUS_NONE
	DeepUi.ledger_button(way, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 4)
	way.custom_minimum_size = Vector2(DeepUi.pt(30), DeepUi.pt(30))
	var dots := DeepUi.hbox(row, int(DeepUi.pt(2)))
	_dots(home, dots, context, s)
	if bool(opts.get("rarity", false)):
		var rarity := DeepUi.button(row, "Any rarity" if str(s.rarity).is_empty() else str(s.rarity).capitalize(), Callable(), 11)
		rarity.focus_mode = Control.FOCUS_NONE
		DeepUi.ledger_button(rarity, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 4)
		rarity.custom_minimum_size.y = DeepUi.pt(30)
		rarity.pressed.connect(func() -> void:
			## Round the rarities, a tap a step: Any, Common, ... Transcendent, Any.
			var at: int = RARITIES.find(str(s.rarity))
			_change(home, context, "rarity", "" if at + 1 >= RARITIES.size() else str(RARITIES[at + 1])))
	if bool(opts.get("search", false)):
		var loupe := DeepUi.icon_button(row, "loupe", "" if str(s.query).is_empty() else str(s.query), func() -> void: _search_panel(home, context), 11, DeepUi.ACCENT if not str(s.query).is_empty() else DeepUi.PAPER)
		loupe.focus_mode = Control.FOCUS_NONE
		DeepUi.ledger_button(loupe, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 4)
		loupe.custom_minimum_size = Vector2(DeepUi.pt(30), DeepUi.pt(30))
		loupe.tooltip_text = "Find a stone: a skill, an inclusion, a mine, a word"
	if bool(opts.get("ghosts", false)):
		var ghosts := CheckButton.new()
		ghosts.text = "Unfound"
		ghosts.tooltip_text = "Show the skills you have not kept yet"
		ghosts.button_pressed = bool(s.ghosts)
		ghosts.focus_mode = Control.FOCUS_NONE
		DeepUi.set_text_size(ghosts, 11)
		ghosts.toggled.connect(func(on: bool) -> void: _change(home, context, "ghosts", on))
		row.add_child(ghosts)
	return row

static func _search_panel(home: Control, context: String) -> void:
	## The search, on the phone: a field over the page, the keyboard up, the stones narrowed as
	## the words are typed; a tap off it (or Done) puts it away and keeps the words.
	var view: Viewport = home.get_viewport()
	if view == null:
		return
	var layer := Control.new()
	layer.name = "SearchPanel"
	layer.theme = DeepUi.shared_theme()
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	view.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT_DIM, 10, int(DeepUi.pt(8)), int(DeepUi.pt(1.5)), 4))
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	plate.custom_minimum_size.x = DeepUi.pt(420)
	plate.position = Vector2((layer.get_viewport_rect().size.x - DeepUi.pt(420)) * 0.5, DeepUi.pt(16))
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(plate)
	var row := DeepUi.hbox(plate, int(DeepUi.pt(6)))
	DeepUi.icon(row, "loupe", DeepUi.pt(16), DeepUi.ACCENT)
	var field := LineEdit.new()
	field.placeholder_text = "a skill, an inclusion, a mine, a word"
	field.text = str(settings(home, context).query)
	field.clear_button_enabled = true
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.y = DeepUi.pt(36)
	DeepUi.set_text_size(field, 14)
	row.add_child(field)
	var close := func() -> void:
		if not is_instance_valid(layer):
			return
		settings(home, context).query = field.text
		home._pages[context + "_page"] = 0
		layer.queue_free()
		if not home.redraw([context + "_tools", context + "_stones"]):
			home._render()
	var done := DeepUi.button(row, "Done", close, 13)
	DeepUi.ledger_primary(done)
	done.custom_minimum_size.y = DeepUi.pt(36)
	field.text_submitted.connect(func(_text: String) -> void: close.call())
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close.call())
	field.call_deferred("grab_focus")

static func toolbar_narrow(home: Control, parent: Node, context: String, opts: Dictionary = {}) -> VBoxContainer:
	## The same controls stacked for a place a tile or two wide (the run dock's bag column): the
	## sort as a drop-down with its direction beside it, then the color dots. No search box: the
	## owner took it out of the bag (November 6, 2026). `opts`: `sorts`.
	var s: Dictionary = settings(home, context)
	var rows := DeepUi.vbox(parent, 4)
	rows.name = "Browser"
	var top := DeepUi.hbox(rows, 4)
	top.name = "SortRow"
	var pick: Button = _sort_dropdown(home, top, context, s, opts.get("sorts", []))
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var way := _direction(home, top, context, s)
	way.name = "Direction"
	way.focus_mode = Control.FOCUS_NONE
	DeepUi.ledger_button(way, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 4)
	var dots := DeepUi.hbox(rows, 2)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots(home, dots, context, s)
	return rows

static func _sort_dropdown(home: Control, row: Node, context: String, s: Dictionary, only: Array) -> Button:
	## The sort as a drop-down: a button naming the sort, with a chevron, that opens the list of
	## sorts on a plate under it (`_open_sorts`). Not an OptionButton: its list is a PopupMenu,
	## which brings a ScrollContainer with it, and the run's screens have none (tests/test_fit.gd).
	var offered: Array = SORTS.filter(func(entry: Array) -> bool: return only.is_empty() or only.has(str(entry[0])))
	var named: String = "Sort"
	for entry in offered:
		if str(entry[0]) == str(s.sort):
			named = str(entry[1])
	var b := DeepUi.button(row, named, Callable(), 13)
	b.name = "Sort"
	b.tooltip_text = "Sort by"
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	DeepUi.ledger_button(b, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 4)
	## Room on the right for the chevron.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = b.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).content_margin_right = 26
	var mark := Chevron.new()
	mark.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	mark.offset_left = -24
	mark.offset_right = -8
	b.add_child(mark)
	b.pressed.connect(func() -> void: _open_sorts(home, b, context, offered))
	return b

static func _open_sorts(home: Control, b: Button, context: String, offered: Array) -> void:
	## The list of sorts on a plate under the button, over everything on the screen: a click on
	## one sorts by it, a click anywhere else puts the list away. It goes when the toolbar does.
	var view: Viewport = b.get_viewport()
	if view == null:
		return
	var layer := Control.new()
	layer.name = "SortMenu"
	layer.theme = DeepUi.theme()
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	view.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			layer.queue_free())
	## Bound to the list's own method, not a lambda holding it: once the list has gone (a pick, a
	## click outside) the engine drops this connection, so the toolbar's rebuild calls nothing.
	b.tree_exiting.connect(layer.queue_free, CONNECT_ONE_SHOT)
	var plate := PanelContainer.new()
	plate.name = "Sorts"
	plate.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT_DIM, 8, 4, 2, 4))
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(plate)
	var list := DeepUi.vbox(plate, 0)
	var current: String = str(settings(home, context).sort)
	for entry in offered:
		var key: String = str(entry[0])
		var on: bool = key == current
		var item := DeepUi.button(list, str(entry[1]), func() -> void:
			if is_instance_valid(layer):
				layer.queue_free()
			if key != str(settings(home, context).sort):
				_change(home, context, "sort", key), 13)
		item.name = "Sort_" + key
		item.focus_mode = Control.FOCUS_NONE
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var rest := DeepUi.flat(Color(DeepUi.ACCENT, 0.16) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 4)
		var lit := DeepUi.flat(DeepUi.SLATE_HI, Color(0, 0, 0, 0), 4, 4)
		for style in [rest, lit]:
			style.content_margin_left = 10
			style.content_margin_right = 10
		for state in ["normal", "focus", "disabled"]:
			item.add_theme_stylebox_override(state, rest)
		for state in ["hover", "pressed", "hover_pressed"]:
			item.add_theme_stylebox_override(state, lit)
		item.add_theme_color_override("font_color", DeepUi.ACCENT_HI if on else DeepUi.PAPER)
		item.add_theme_color_override("font_hover_color", Color.WHITE)
		item.add_theme_font_override("font", DeepUi.bold_font())
	## Under the button and at least as wide; over it where the screen has no room under it.
	var at: Rect2 = b.get_global_rect()
	var want: Vector2 = plate.get_combined_minimum_size()
	want.x = maxf(want.x, at.size.x)
	plate.size = want
	var screen: Vector2 = layer.get_viewport_rect().size
	var y: float = at.end.y + 4.0
	if y + want.y > screen.y:
		y = at.position.y - want.y - 4.0
	plate.position = Vector2(clampf(at.position.x, 0.0, maxf(0.0, screen.x - want.x)), maxf(0.0, y)).round()
	if not DeepUi.headless():
		DeepUi.pop_in(plate, 0.0, 0.97, 0.12)

class Chevron extends Control:
	## The mark on a drop-down: a small V pointing down to the list it opens.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		draw_polyline(PackedVector2Array([centre + Vector2(-4.5, -2.0), centre + Vector2(0.0, 2.5), centre + Vector2(4.5, -2.0)]), DeepUi.MUTED, 2.0, true)

static func _sorter(home: Control, row: Node, context: String, s: Dictionary, compact: bool, only: Array) -> OptionButton:
	## The sort, as a drop-down. `only` names the sorts offered (every one when empty).
	var sorter := OptionButton.new()
	sorter.name = "Sort"
	sorter.focus_mode = Control.FOCUS_NONE
	sorter.tooltip_text = "Sort by"
	var offered: Array = SORTS.filter(func(entry: Array) -> bool: return only.is_empty() or only.has(str(entry[0])))
	for index in range(offered.size()):
		sorter.add_item(("Sort: " if not compact else "") + str(offered[index][1]), index)
		if str(offered[index][0]) == str(s.sort):
			sorter.select(index)
	DeepUi.set_text_size(sorter, 13)
	sorter.item_selected.connect(func(index: int) -> void:
		DeepAudio.play("ui_tap")
		_change(home, context, "sort", str(offered[index][0])))
	row.add_child(sorter)
	return sorter

static func _direction(home: Control, row: Node, context: String, s: Dictionary) -> Button:
	var way := DeepUi.icon_button(row, "fall" if bool(s.desc) else "rise", "", func() -> void: _change(home, context, "desc", not bool(s.desc)), 13, DeepUi.PAPER)
	way.tooltip_text = "Highest first" if bool(s.desc) else "Lowest first"
	return way

static func _dots(home: Control, row: Node, context: String, s: Dictionary) -> void:
	## A dot a color: click one to see only its stones, Shift-click to add another, click a
	## picked one to show every color again.
	for color in COLORS:
		var dot := ColorDot.new(color, s.colors.is_empty() or s.colors.has(color), s.colors.has(color))
		dot.tooltip_text = "Only %s stones" % str(DeepContent.color(color).get("name", color.capitalize())) if not s.colors.has(color) else "Show every color again"
		row.add_child(dot)
		var key: String = color
		dot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_toggle", {"volume": 0.6})
				var now: Array = s.colors.duplicate()
				if now.has(key):
					now.erase(key)
				elif Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
					now.append(key)
				else:
					now = [key]
				_change(home, context, "colors", now))

static func _search(home: Control, row: Node, context: String, s: Dictionary, compact: bool) -> LineEdit:
	## The search box: it waits a beat after the last keystroke, then draws the stones again
	## and keeps its focus.
	var search := LineEdit.new()
	search.name = "Search_" + context
	search.placeholder_text = "Find a stone" if compact else "Find: a skill, an inclusion, a mine, a word…"
	search.text = str(s.query)
	search.clear_button_enabled = true
	search.custom_minimum_size.x = 150 if compact else 250
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not compact else Control.SIZE_SHRINK_BEGIN
	DeepUi.set_text_size(search, 13)
	row.add_child(search)
	var wait := Timer.new()
	wait.one_shot = true
	wait.wait_time = 0.3
	search.add_child(wait)
	wait.timeout.connect(func() -> void:
		settings(home, context).query = search.text
		home._pages[context + "_page"] = 0
		## Only the stones, where they are a part of their own: the box keeps its focus.
		if home.redraw([context + "_stones"]):
			return
		home.set_meta("browse_focus", context)
		home._render())
	search.text_changed.connect(func(_text: String) -> void: wait.start())
	if str(home.get_meta("browse_focus", "")) == context:
		home.remove_meta("browse_focus")
		search.call_deferred("grab_focus")
		search.set_deferred("caret_column", search.text.length())
	return search

class ColorDot extends Control:
	## One color's dot in the browser's row: lit when its stones are shown, ringed when it is
	## the filter.
	const REACH := Vector2(3, 7)
	var color: String
	var lit: bool
	var picked: bool
	func _init(key: String, shown: bool, chosen: bool) -> void:
		color = key
		lit = shown
		picked = chosen
		## On the phone a dot is drawn larger (k), and answers a finger in a 44 point square.
		custom_minimum_size = Vector2(20, 20) * _k()
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_to_group(DeepUi.MARKED_GROUP)
	static func _k() -> float:
		return 1.7 if DeepUi.phone else 1.0
	func _has_point(point: Vector2) -> bool:
		## A click counts well past the dot: 34 tall, and half the gap to each neighbour wide,
		## so the dots share the whole strip between them. The dot is drawn as it always was.
		var reach: Vector2 = REACH * _k() if not DeepUi.phone else Vector2(DeepUi.pt(3), (DeepUi.TOUCH - size.y) * 0.5)
		return Rect2(-reach, size + reach * 2.0).has_point(point)
	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var alpha: float = 1.0 if lit else 0.28
		var k: float = _k()
		if DeepUi.color_marks:
			## Settings > Comfort > Color marks: the dot takes its color's shape.
			DeepUi.draw_color_mark(self, centre, 8.0 * k, color, false, false, alpha)
		elif color == DeepContent.OPAL:
			for i in range(12):
				draw_arc(centre, 4.0 * k, TAU * float(i) / 12.0, TAU * float(i + 1) / 12.0, 4, Color(DeepUi.rainbow_at(float(i) / 11.0, 0.62), alpha), 7.0 * k)
		else:
			draw_circle(centre, 7.0 * k, Color(DeepUi.color(color), alpha))
		if picked:
			draw_arc(centre, 9.5 * k, 0, TAU, 24, DeepUi.ACCENT_HI, 2.0 * k, true)

# --- sorting and finding ----------------------------------------------------------------------------

static func sorted(home: Control, stones: Array, context: String) -> Array:
	## The stones that pass this place's filters, in its sort.
	var s: Dictionary = settings(home, context)
	var key: String = str(s.sort)
	var desc: bool = bool(s.desc)
	## Each stone's place worked out once, not at every comparison: a grade or a worth is not cheap.
	var keyed: Array = []
	for stone in stones:
		if passes(stone, s):
			keyed.append([sort_value(stone, key), DeepUi.skill_name(stone), stone])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] == b[0]:
			return a[1] < b[1]
		return (a[0] > b[0]) if desc else (a[0] < b[0]))
	return keyed.map(func(entry: Array) -> Dictionary: return entry[2])

static func passes(stone: Dictionary, s: Dictionary) -> bool:
	var color: String = DeepStone.color(stone)
	if not s.get("colors", []).is_empty() and not s.colors.has(color):
		return false
	if not str(s.get("rarity", "")).is_empty() and str(DeepStone.skill_of(stone).get("rarity", "COMMON")) != str(s.rarity):
		return false
	return matches(stone, str(s.get("query", "")))

static func matches(stone: Dictionary, query: String) -> bool:
	## Every word of the search has to be found somewhere in what the stone is.
	var words: PackedStringArray = query.strip_edges().to_lower().split(" ", false)
	if words.is_empty():
		return true
	var hay: String = haystack(stone)
	for word in words:
		if not hay.contains(word):
			return false
	return true

static func haystack(stone: Dictionary) -> String:
	var skill: Dictionary = DeepStone.skill_of(stone)
	var parts: Array = [str(skill.get("name", "")), str(DeepContent.color(DeepStone.color(stone)).get("name", "")), str(skill.get("rarity", "")), str(skill.get("text", ""))]
	if bool(stone.get("appraised", false)):
		parts.append(DeepContent.cut_name(int(stone.get("cut", 0))))
		parts.append(DeepContent.clarity_name(int(stone.get("clarity", 0))))
		parts.append(str(DeepStone.TIER_NAMES.get(str(DeepStone.grade(stone).tier), "")))
		for key in stone.get("inclusions", []):
			parts.append(str(DeepContent.inclusion(str(key)).get("name", key)))
	var provenance: Variant = stone.get("provenance", {})
	if provenance is Dictionary and not str(provenance.get("mine", "")).is_empty():
		parts.append(DeepContent.mine_name(str(provenance.mine)))
	return " ".join(parts).to_lower()

static func sort_value(stone: Dictionary, key: String) -> Variant:
	match key:
		"grade": return int(DeepStone.grade(stone).score)
		"carat": return int(stone.get("carat", 0))
		"cut": return int(stone.get("cut", 0))
		"clarity": return int(stone.get("clarity", 0))
		"worth": return DeepStone.value(stone)
		"rarity": return RARITIES.find(str(DeepStone.skill_of(stone).get("rarity", "COMMON")))
		"color": return -COLORS.find(DeepStone.color(stone))
		"name": return DeepUi.skill_name(stone).to_lower()
		"found": return str(stone.get("provenance", {}).get("date", "")) if stone.get("provenance", null) is Dictionary else ""
		"mine":
			var provenance: Variant = stone.get("provenance", {})
			return DeepContent.mine_tier(str(provenance.get("mine", ""))) if provenance is Dictionary else 0
	return 0

# --- the list view ----------------------------------------------------------------------------------

static func table(home: Control, parent: Node, stones: Array, opts: Dictionary = {}) -> VBoxContainer:
	## The stones as rows, one column per thing they are sorted by; a column's heading sorts by
	## it. `picked` rings a row, `on_pick` is handed a row's stone when it is clicked,
	## `context` is whose sort the headings change.
	var context: String = str(opts.get("context", "vault"))
	var s: Dictionary = settings(home, context)
	var box := DeepUi.vbox(parent, 2)
	box.name = "StoneTable"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var widths: Array = [["name", "Stone", 200], ["grade", "Grade", 104], ["carat", "Carat", 56], ["cut", "Cut", 124], ["clarity", "Clarity", 100], ["worth", "Worth", 56], ["", "Inside", 0], ["mine", "Found", 130], ["found", "When", 84], ["", "In", 76]]
	## The headings sit in a pad as deep as a row's, so they line up over their columns.
	var head_pad := DeepUi.panel(box, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 4)
	var head := DeepUi.hbox(head_pad, 10)
	for column in widths:
		var key: String = str(column[0])
		var words: String = str(column[1]).to_upper() + (("  ↓" if bool(s.desc) else "  ↑") if key == str(s.sort) else "")
		var cell: Control
		if key.is_empty():
			cell = DeepUi.label(head, words, 11, DeepUi.DIM)
		else:
			var b := Button.new()
			b.text = words
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			DeepUi.set_text_size(b, 11)
			b.add_theme_color_override("font_color", DeepUi.ACCENT_HI if key == str(s.sort) else DeepUi.DIM)
			b.pressed.connect(func() -> void:
				DeepAudio.play("ui_tap")
				if key == str(s.sort):
					_change(home, context, "desc", not bool(s.desc))
				else:
					home.browse["_sort"].sort = key
					_change(home, context, "desc", true))
			head.add_child(b)
			cell = b
		cell.custom_minimum_size.x = float(column[2])
		if int(column[2]) == 0:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wearing: Dictionary = _wearers(home)
	var index: int = 0
	for stone in stones:
		var skill: String = str(stone.get("skill", ""))
		var picked: bool = skill == str(opts.get("picked", ""))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _row_style(picked, index))
		panel.set_meta("skill", skill)
		panel.set_meta("row", index)
		box.add_child(panel)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var row := DeepUi.hbox(panel, 10)
		var name_cell := DeepUi.hbox(row, 8)
		name_cell.custom_minimum_size.x = 200
		StoneCard.mini(name_cell, stone, 34)
		var name_label := DeepUi.label(name_cell, DeepUi.skill_name(stone), 14, DeepUi.PAPER)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if bool(stone.get("fresh", false)):
			DeepUi.chip(name_cell, "NEW", StoneCard.PIP_NEW, 10).name = "New"
		var grade: Dictionary = DeepStone.grade(stone)
		DeepUi.label(row, "%s · %d" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(grade.score)], 13, DeepUi.tier_color(str(grade.tier))).custom_minimum_size.x = 104
		DeepUi.label(row, "%d ct" % int(stone.get("carat", 1)), 14, DeepUi.PAPER).custom_minimum_size.x = 56
		var cut_cell := DeepUi.hbox(row, 6)
		cut_cell.custom_minimum_size.x = 124
		cut_cell.add_child(StoneCard.Pips.new(int(stone.get("cut", 0)) + 1, DeepContent.cuts().size(), 6.0, StoneCard.TileTags.CUT_TONE))
		DeepUi.label(cut_cell, DeepContent.cut_name(int(stone.get("cut", 0))), 13, DeepUi.MUTED)
		DeepUi.label(row, DeepContent.clarity_name(int(stone.get("clarity", 0))), 13, DeepUi.MUTED).custom_minimum_size.x = 100
		## Worth is a sort, so it is a column too: a list sorted by it shows what it was sorted on.
		DeepUi.label(row, "%d" % DeepStone.value(stone), 13, DeepUi.ACCENT).custom_minimum_size.x = 56
		var inside: Array = stone.get("inclusions", []).map(func(k: Variant) -> String: return str(DeepContent.inclusion(str(k)).get("name", k)))
		var inside_label := DeepUi.label(row, ", ".join(inside) if not inside.is_empty() else "–", 12, DeepUi.MUTED)
		inside_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inside_label.clip_text = true
		inside_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var provenance: Dictionary = stone.get("provenance", {}) if stone.get("provenance", null) is Dictionary else {}
		var where: String = DeepContent.mine_name(str(provenance.get("mine", ""))) if not str(provenance.get("mine", "")).is_empty() else "–"
		## A Geode or a contract stone was rolled at a depth's luck, not found on that floor.
		if int(provenance.get("depth", 0)) > 0 and not str(provenance.get("source", "")) in ["geode", "contract"]:
			where += " · %d" % int(provenance.depth)
		if int(provenance.get("hazard", 0)) > 0:
			where += " · H%d" % int(provenance.hazard)
		var where_label := DeepUi.label(row, where, 12, DeepUi.MUTED)
		where_label.custom_minimum_size.x = 130
		where_label.clip_text = true
		where_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		DeepUi.label(row, str(provenance.get("date", "–")), 12, DeepUi.DIM).custom_minimum_size.x = 84
		var in_cell := DeepUi.hbox(row, 3)
		in_cell.custom_minimum_size.x = 76
		for character in wearing.get(skill, []):
			var face := Roster.Portrait.new(str(character), Vector2(22, 22), false, false, false, Roster.worn_stone(home.profile, str(character)))
			face.tooltip_text = "In %s's sockets" % DeepContent.character_title(str(character))
			in_cell.add_child(face)
		var on_pick: Callable = opts.get("on_pick", Callable())
		if on_pick.is_valid():
			var picked_stone: Dictionary = stone
			panel.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					on_pick.call(picked_stone))
		index += 1
	return box

static func _row_style(picked: bool, index: int) -> StyleBoxFlat:
	return DeepUi.flat(Color(DeepUi.ACCENT, 0.12) if picked else Color(1, 1, 1, 0.025 if index % 2 == 0 else 0.0), DeepUi.ACCENT if picked else Color(0, 0, 0, 0), 6, 4)

static func repick(holder: Node, was: String, now: String) -> bool:
	## A row picked in the list: the old row and the new one restyled where they stand, the
	## rest left alone. False when there is no list here to do it in.
	var box: Node = holder.get_node_or_null("StoneTable") if holder != null else null
	if box == null:
		return false
	for row in box.get_children():
		if not row is PanelContainer or not row.has_meta("row"):
			continue
		var skill: String = str(row.get_meta("skill", ""))
		if skill != was and skill != now:
			continue
		(row as PanelContainer).add_theme_stylebox_override("panel", _row_style(skill == now, int(row.get_meta("row"))))
		## Looked at, it is not new any more.
		var mark: Node = row.find_child("New", true, false) if skill == now else null
		if mark != null:
			mark.queue_free()
	return true

static func _wearers(home: Control) -> Dictionary:
	## skill -> the delvers whose loadouts set it.
	var out: Dictionary = {}
	for key in home.profile.get("characters", {}):
		var record: Dictionary = home.profile.characters[key]
		if not bool(record.get("unlocked", false)):
			continue
		for skill in record.get("rail", []):
			if skill is String:
				if not out.has(skill):
					out[skill] = []
				out[skill].append(str(key))
	return out
