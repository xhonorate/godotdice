extends SceneTree
## The run's own controls, headless, on the owner's 1440 × 810 window (Nov 5, 2026, rounds 2
## and 3): the bag as a column down the right edge, lying over the run dock without moving it
## (it builds empty, light and heavy, turns its pages instead of scrolling, never runs out of
## the window, and keeps its drag targets); the carver's face picker, 32 px faces in rows as
## wide as the screen allows, smaller faces only when even those would not fit above the dock,
## every face shown up to a d100; like faces sharing a chip only past that. The app boots and a run is started so the dock and the ask are the real
## ones. Rendering is skipped; layout and logic are exercised.
##
## The game draws a 1600 × 900 canvas and scales it to the window (project.godot: stretch
## `canvas_items`, aspect `expand`), so the owner's 1440 × 810 window is this canvas at a text
## scale of 0.9; the smallest window (0.64) is tests/test_fit.gd's.

const CANVAS := Vector2i(1600, 900)
const OWNER_SCALE := 1440.0 / 1600.0
const AskSheet = preload("res://view/run/ask_sheet.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const StoneBrowser = preload("res://view/home/stone_browser.gd")
const ThumbsUi = preload("res://view/gems/thumbs.gd")
const BattleUi = preload("res://view/battle/battle_screen.gd")
const ShaftMap = preload("res://view/run/shaft_map.gd")

var checks: int = 0
var failures: Array = []
## The screen everything is drawn into: headless, the window has no real size, so the game
## gets a viewport of its own at exactly the owner's window.
var screen: SubViewport

func _init() -> void:
	DeepUi.text_scale = OWNER_SCALE
	DeepSaveStore.override_directory = "user://test_scratch"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	screen = SubViewport.new()
	screen.size = CANVAS
	root.add_child(screen)
	var app: Control = load("res://view/app.gd").new()
	screen.add_child(app)
	await process_frame
	check(app.get_global_rect().size == Vector2(CANVAS), "the game is drawn on %s (got %s)" % [str(CANVAS), str(app.get_global_rect().size)])
	app._depart(9001)
	await _frames(2)
	var descent: Control = app.descent
	check(descent.visible and descent._run_dock.visible, "departing shows the run with its dock")
	await _bag(app, descent)
	await _close_look(app, descent)
	await _carver(descent)
	await _three_faces(descent)
	await _round5(app, descent)
	await _round6(app, descent)
	print("Run UI: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

# --- the bag column ------------------------------------------------------------------------------

func _bag(app: Control, descent: Control) -> void:
	var dock: Control = descent._run_dock
	var run: Dictionary = app.session.run
	var me: Dictionary = app.session.local_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mine: Dictionary = DeepContent.mine(DeepContent.starter_mine())
	var kept: Array = me.get("haul", []).duplicate()
	## The dock as it stands with the bag shut: the bag opening must not move or redraw it.
	dock.set_drawer(false)
	descent.show_state(run)
	await _frames(2)
	var shut_dock: Array = _dock_shape(dock)
	for count in [0, 3, 20]:
		me.haul = []
		for i in range(count):
			var found: Dictionary = DeepForge.roll_stone(rng, mine, 4 + i % 10, 3, {"run": "ui", "source": "vein"}, "ui_haul%d" % i)
			if i % 3 != 2:
				found.appraised = true
				found.inclusions_revealed = true
			me.haul.append(found)
		dock._pages["bag_page"] = 0
		dock._key = ""
		dock.set_drawer(true)
		descent.show_state(run)
		await _frames(2)
		var column: Control = dock._drawer
		check(dock.is_drawer_open() and column.visible, "the bag opens as a column with %d stones" % count)
		var rect: Rect2 = column.get_global_rect()
		check(rect.position.y >= 0.0 and rect.end.y <= float(CANVAS.y) + 0.5 and rect.end.x <= float(CANVAS.x) + 0.5, "the column with %d stones stays inside the window (%s)" % [count, str(rect)])
		check(rect.size.x >= dock.COLUMN_WIDTH - 0.5 and rect.size.x <= dock.COLUMN_WIDTH + 0.5, "the column is %d wide (got %d)" % [int(dock.COLUMN_WIDTH), int(rect.size.x)])
		var spilled: Array = []
		_scan(column, rect, spilled)
		check(spilled.is_empty(), "everything in the column with %d stones stays inside it: %s" % [count, "; ".join(spilled.slice(0, 4))])
		## The dock is not moved, shrunk or drawn tight for it: the column lies over its right
		## end, drawn after it and its tabs, from under the strip to the foot of the screen.
		var open_dock: Array = _dock_shape(dock)
		check(open_dock == shut_dock, "with %d stones the dock is unchanged when the bag opens (%s, was %s)" % [count, str(open_dock), str(shut_dock)])
		check(column.get_index() > dock._dock.get_index() and column.get_index() > dock._tab_bar.get_index() and dock._pane.get_index() > dock._dock.get_index(), "the column and its plate are drawn above the dock and its tabs")
		## Its foot stands above the dock (the owner, Nov 6: "ends before overlapping the dice
		## area"), and a page still holds four rows of 72 px tiles.
		check(not dock.COLUMN_OVER_DOCK and rect.end.y <= dock._dock.get_global_rect().position.y - dock._tabs_lift() + 0.5 and not rect.intersects(dock._dock.get_global_rect()), "with %d stones the column's foot stands above the dock (%s, dock at %d)" % [count, str(rect), int(dock._dock.get_global_rect().position.y)])
		check(dock.per_page() >= 12, "the column above the dock holds six rows or more (%d a page)" % dock.per_page())
		var tile: float = float(dock.get_meta("bag_tile", 0.0))
		check(tile >= dock.GEM_TILE_LEAST and tile <= dock.GEM_TILE, "the tiles are %d px, between %d and %d" % [int(tile), int(dock.GEM_TILE_LEAST), int(dock.GEM_TILE)])
		if count >= dock.per_page():
			var band: float = _band(dock)
			check(band <= tile * 0.5, "with a full page no more than half a tile of empty column stands under the last row (%d px, tile %d)" % [int(band), int(tile)])
		## It wears the chart's plate.
		var worn: StyleBoxFlat = column.get_theme_stylebox("panel") as StyleBoxFlat
		var chart_plate: StyleBoxFlat = ShaftMap.side_plate(1.0)
		check(worn != null and worn.bg_color == chart_plate.bg_color and worn.border_color == chart_plate.border_color and worn.border_width_left == chart_plate.border_width_left
			and worn.corner_radius_top_left == chart_plate.corner_radius_top_left and worn.shadow_size == chart_plate.shadow_size and worn.shadow_color == chart_plate.shadow_color, "the column wears the chart's plate (ShaftMap.side_plate)")
		var each: int = dock.per_page()
		check(each >= dock.COLUMN_COLUMNS and each % dock.COLUMN_COLUMNS == 0, "a page holds whole rows of two (got %d)" % each)
		var want: int = maxi(1, ceili(float(count) / float(each)))
		check(dock.pages() == want, "%d stones at %d a page make %d pages (got %d)" % [count, each, want, dock.pages()])
		var shown: int = dock._tiles.get_child_count()
		check(shown == mini(count, each), "the first page shows %d tiles (got %d)" % [mini(count, each), shown])
		check(column.find_child("Sort", true, false) is Button and column.find_child("Direction", true, false) is Button, "the sort is a drop-down with its direction beside it")
		check(_count_class(column, LineEdit) == 0, "the bag has no search box")
		## The toggles first, above the sort.
		var toggles: Control = column.find_child("Toggles", true, false)
		var sort_row: Control = column.find_child("SortRow", true, false)
		check(toggles != null and sort_row != null and toggles.get_index() == 0 and toggles.get_global_rect().end.y <= sort_row.get_global_rect().position.y, "the toggles row stands above the sort's drop-down")
		check(toggles != null and toggles.get_child_count() == 3 and column.find_child("Fits", true, false) == null, "the toggles row holds the three counts and no Fits filter")
		## No drop-down: its popup brings a scroller, and the run's screens have none.
		check(descent.find_children("*", "ScrollContainer", true, false).is_empty() and _count_class(column, OptionButton) == 0, "the bag brings nothing that scrolls into the run")
		var dots: int = _count_class(column, StoneBrowser.ColorDot)
		check(dots == StoneBrowser.COLORS.size(), "a dot a color on the toolbar (got %d)" % dots)
		if count > each:
			## Turned to its second page: what did not fit the first is there, and nothing scrolls.
			dock.turn_page(1)
			await _frames(2)
			var second: int = mini(count - each, each)
			check(int(dock._pages.get("bag_page", 0)) == 1 and dock._tiles.get_child_count() == second, "page two shows the next %d tiles (got %d)" % [second, dock._tiles.get_child_count()])
			var rect2: Rect2 = dock._drawer.get_global_rect()
			check(rect2.end.y <= float(CANVAS.y) + 0.5, "page two still fits the window")
			check(_count_class(dock._drawer, ScrollContainer) == 0, "the bag never scrolls")
			dock.turn_page(0)
			await _frames(1)
	## No filter hides a stone: with the toggles as they start (appraised and raw on, Geodes
	## off) every stone but a Geode is shown, whether or not any socket would take it. The Fits
	## filter is gone entirely.
	var unsealed: int = me.haul.filter(func(st: Dictionary) -> bool: return not DeepStone.is_geode(st)).size()
	check(dock._shown_haul(me).size() == unsealed, "every stone but a Geode is shown (%d of %d)" % [dock._shown_haul(me).size(), unsealed])
	check(not ("fits_only" in dock), "the bag has no Fits filter left")
	dock.show_geodes = true
	check(dock._shown_haul(me).size() == me.haul.size(), "with Geodes on, every stone in the bag is shown")
	dock.show_geodes = false
	## The targets: the whole column takes a set stone back and a stall's goods; each socket
	## takes a stone from the bag; a bag stone cannot be dropped back into the bag.
	var set_stone: Variant = me.rail[0] if not me.rail.is_empty() else null
	var bag_target: Dictionary = {}
	var sockets: int = 0
	for target in dock._targets:
		if target.node == dock._drawer:
			bag_target = target
		elif target.get("ring") != null:
			sockets += 1
	check(not bag_target.is_empty(), "the column is a drop target")
	check(sockets >= me.rail.size(), "every socket is a drop target (%d of %d)" % [sockets, me.rail.size()])
	## The column covers none of the dock: every socket is in reach of a stone dragged out of it.
	var open_column: Rect2 = dock._drawer.get_global_rect()
	var reachable: int = 0
	for target in dock._targets:
		if target.get("ring") != null and is_instance_valid(target.node) and not (target.node as Control).get_global_rect().intersects(open_column):
			reachable += 1
	check(reachable == sockets, "every socket stays reachable for a drop (%d of %d)" % [reachable, sockets])
	if not bag_target.is_empty():
		var from_rail: Dictionary = {"kind": "stone", "stone_id": str(set_stone.get("id", "")) if set_stone is Dictionary else "", "from_socket": 0, "appraised": true}
		check(bool(bag_target.accepts.call(from_rail)), "a set stone can be dropped on the column to take it out")
		check(not bool(bag_target.accepts.call({"kind": "stone", "stone_id": str(me.haul[0].id), "from_socket": -1, "appraised": true})), "a bag stone dropped on the column goes nowhere")
		check(bool(bag_target.accepts.call({"kind": "shop_item", "item_kind": "stone", "item_id": "x", "price": 0, "stone": me.haul[0]})), "a stall's stone can be dropped on the column to buy it")
	## A bag stone fits a socket that would take it.
	var loose: Dictionary = me.haul.filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)))[0]
	var takes_any: bool = false
	for target in dock._targets:
		if target.get("ring") != null and bool(target.accepts.call({"kind": "stone", "stone_id": str(loose.id), "from_socket": -1, "appraised": true})):
			takes_any = true
	var any_room: bool = me.rail.has(null) or me.rail.any(func(s: Variant) -> bool: return s is Dictionary and str(s.get("skill", "")) == str(loose.skill))
	check(takes_any or not any_room, "a bag stone can be dropped on a socket")
	## The browser's sort, dots and search drive what the tiles show.
	dock.sort_by = "carat"
	dock._key = ""
	dock.show_run(run)
	var by_carat: Array = dock._shown_haul(me)
	var heaviest: int = me.haul.map(func(s: Dictionary) -> int: return int(s.get("carat", 1))).max()
	check(by_carat.size() == me.haul.size() and int(by_carat[0].get("carat", 1)) == heaviest, "sorted by carat the heaviest stone comes first")
	StoneBrowser.settings(dock, "bag").colors = ["RED"]
	check(dock._shown_haul(me).all(func(s: Dictionary) -> bool: return DeepStone.color(s) == "RED"), "a color dot shows only its stones")
	StoneBrowser.settings(dock, "bag").colors = []
	## The drop-down: its list of the bag's sorts on a plate over everything, a pick sorts by it
	## and puts the list away, a click anywhere else puts it away too; nothing in it scrolls.
	await _frames(2)
	var pick: Button = dock._drawer.find_child("Sort", true, false)
	pick.pressed.emit()
	await _frames(1)
	var menu: Node = screen.find_child("SortMenu", false, false)
	check(menu != null and _count_class(menu, Button) == dock.BAG_SORTS.size(), "the drop-down lists the bag's %d sorts (got %s)" % [dock.BAG_SORTS.size(), str(_count_class(menu, Button)) if menu != null else "no list"])
	check(menu != null and _count_class(menu, ScrollContainer) == 0, "the drop-down's list has nothing that scrolls")
	var plate_rect: Rect2 = (menu.find_child("Sorts", true, false) as Control).get_global_rect() if menu != null else Rect2()
	check(menu != null and Rect2(Vector2.ZERO, Vector2(CANVAS)).grow(1.0).encloses(plate_rect) and plate_rect.position.y >= pick.get_global_rect().end.y, "the list opens under the drop-down, inside the window (%s)" % str(plate_rect))
	if menu != null:
		(menu.find_child("Sort_name", true, false) as Button).pressed.emit()
	await _frames(2)
	check(dock.sort_by == "name" and screen.find_child("SortMenu", false, false) == null, "picking Name sorts by name and puts the list away (sort %s)" % dock.sort_by)
	check(str((dock._drawer.find_child("Sort", true, false) as Button).text) == "Name", "the drop-down names the sort")
	await _frames(2)
	(dock._drawer.find_child("Sort", true, false) as Button).pressed.emit()
	await _frames(1)
	var outside := InputEventMouseButton.new()
	outside.pressed = true
	outside.button_index = MOUSE_BUTTON_LEFT
	var again: Node = screen.find_child("SortMenu", false, false)
	## Noted before the click: once freed, the list compares equal to null.
	var opened: bool = again != null
	if opened:
		(again as Control).gui_input.emit(outside)
	await _frames(1)
	check(opened and screen.find_child("SortMenu", false, false) == null, "a click outside the list puts it away")
	dock.sort_by = "grade"
	## The reading plate stands beside the column while a stone is pointed at, inside the window.
	dock._reading = str(me.haul[0].id)
	dock._key = ""
	dock.show_run(run)
	await _frames(2)
	check(dock._pane.visible, "pointing at a stone opens the reading plate")
	var pane_rect: Rect2 = dock._pane.get_global_rect()
	check(Rect2(Vector2.ZERO, Vector2(CANVAS)).grow(1.5).encloses(pane_rect) and pane_rect.end.x <= dock._drawer.get_global_rect().position.x, "the reading plate stands beside the column, inside the window (%s)" % str(pane_rect))
	check(dock._pane.find_child("Pane", true, false) != null and _count_text(dock._pane, "Look") == 1, "the plate reads the stone with its Look")
	dock._reading = ""
	## Shut, the column and the plate go and the dock is whole again.
	dock.set_drawer(false)
	await _frames(1)
	check(not dock._drawer.visible and not dock._pane.visible and _dock_shape(dock) == shut_dock, "shutting the bag puts the column and the plate away, the dock as it was")
	check(is_equal_approx(dock.height(), dock._height + 28.0 + dock._tabs_lift()), "the dock's height never counts the bag")
	## A long rail (seven sockets and the Birthstone, drawn tight as ever): still the dock as it
	## was, and the column above it.
	var rail_was: Array = me.rail.duplicate()
	var sockets_was: Array = me.get("sockets", []).duplicate()
	while me.rail.size() < 7:
		me.rail.append(null)
		me.sockets.append(DeepContent.SOCKET_RAINBOW)
	dock.set_drawer(false)
	descent.show_state(run)
	await _frames(2)
	var long_shut: Array = _dock_shape(dock)
	dock.set_drawer(true)
	descent.show_state(run)
	await _frames(2)
	check(_dock_shape(dock) == long_shut, "a seven-socket rail's dock is unchanged when the bag opens")
	var long_spill: Array = []
	_scan(dock._drawer, dock._drawer.get_global_rect(), long_spill)
	check(long_spill.is_empty() and dock.per_page() >= 8 and not dock._drawer.get_global_rect().intersects(dock._dock.get_global_rect()), "the column above a long rail still holds its rows (%d a page): %s" % [dock.per_page(), "; ".join(long_spill.slice(0, 3))])
	dock.set_drawer(false)
	me.rail = rail_was
	me.sockets = sockets_was
	await _frames(1)
	## A party of four: the seat tabs stand on the dock, and the column's foot stands above
	## them too, every row of its page inside it.
	var party: Dictionary = run.duplicate(true)
	for i in range(1, 4):
		var other: Dictionary = DeepDescent.player(party, app.session.local_id).duplicate(true)
		other.id = "ui_p%d" % i
		other.name = "Guest With A Long Name %d" % i
		party.players.append(other)
	descent.show_state(party)
	dock.set_drawer(true)
	descent.show_state(party)
	await _frames(3)
	var tabs_top: float = dock._tab_bar.get_global_rect().position.y
	var party_rect: Rect2 = dock._drawer.get_global_rect()
	var party_spill: Array = []
	_scan(dock._drawer, party_rect, party_spill)
	check(dock._tab_bar.visible and party_rect.end.y <= tabs_top + 0.5, "in a party the column's foot stands above the seat tabs (%d, tabs at %d)" % [int(party_rect.end.y), int(tabs_top)])
	check(party_spill.is_empty() and dock.per_page() >= 2, "in a party the column still holds its rows (%d a page): %s" % [dock.per_page(), "; ".join(party_spill.slice(0, 3))])
	var party_tile: float = float(dock.get_meta("bag_tile", 0.0))
	check(me.haul.size() < dock.per_page() or _band(dock) <= party_tile * 0.5, "in a party no more than half a tile of empty column stands under the last row (%d px, tile %d)" % [int(_band(dock)), int(party_tile)])
	_chart_matches(descent, "in a party")
	dock.set_drawer(false)
	descent.show_state(run)
	await _frames(1)
	## Alone, the chart stands as tall as the bag column too.
	dock.set_drawer(true)
	descent.show_state(run)
	await _frames(2)
	_chart_matches(descent, "alone")
	if descent._chart_open:
		descent.toggle_chart()
	dock.set_drawer(false)
	await _frames(1)
	me.haul = kept
	dock._key = ""
	descent.show_state(run)

func _close_look(app: Control, descent: Control) -> void:
	## The close look on a set stone is opened with the rail's context: in it, how often the
	## stone has fired this run, which the inspector says.
	var dock: Control = descent._run_dock
	var me: Dictionary = app.session.local_player()
	var at: int = -1
	for index in range(me.rail.size()):
		if at < 0 and me.rail[index] is Dictionary:
			at = index
	if at < 0:
		check(false, "the starting rail has a set stone to look at")
		return
	me.run_counts = {str(me.rail[at].id): 3}
	var context: Dictionary = dock._rail_context(me, at)
	check(int(context.get("run_fires", -1)) == 3, "the dock's close look carries run_fires (got %s)" % str(context.get("run_fires", null)))
	me.run_counts = {}

# --- the carver's face picker -------------------------------------------------------------------

func _carver(descent: Control) -> void:
	## The layout alone: a d6 one row, a d20 two rows of ten at 32 px, wider rows before smaller
	## faces, and nothing at all in a room too small for the smallest face.
	var roomy: Dictionary = AskSheet.face_layout(20, 1500.0, 400.0)
	check(roomy == {"edge": 32.0, "across": 10, "rows": 2}, "twenty faces in a roomy sheet are two rows of ten at 32 px (got %s)" % str(roomy))
	var low: Dictionary = AskSheet.face_layout(60, 1500.0, 90.0)
	check(not low.is_empty() and float(low.edge) == 32.0 and int(low.rows) == 2 and int(low.across) == 30, "a low room takes wider rows before a smaller face (got %s)" % str(low))
	check(AskSheet.face_layout(100, 300.0, 40.0).is_empty(), "no layout where even the smallest face does not fit")
	var ask: Control = descent._ask
	var dock: Control = descent._run_dock
	for shape in ["D6", "D20", "D30", "D50", "D100"]:
		var die: Dictionary = DeepDice.make(shape, "ui_" + shape)
		_open_carver(ask, die)
		await _frames(2)
		var block: Control = ask._block
		var want: Vector2 = block.get_combined_minimum_size()
		var floor_height: float = dock.height() if dock.visible else 0.0
		check(want.y + 28.0 <= float(CANVAS.y) - floor_height, "the carver's ask with a %s stands clear of the dock (%d tall, %d of room)" % [shape.to_lower(), int(want.y), int(float(CANVAS.y) - floor_height)])
		check(want.x <= float(CANVAS.x) - 2.0 * AskSheet.SIDE_ROOM + 0.5, "the carver's ask with a %s fits the window's width (%d wide)" % [shape.to_lower(), int(want.x)])
		var grid: Node = block.find_child("Faces", true, false)
		check(grid != null and grid.has_meta("layout"), "the %s's faces are laid in rows" % shape.to_lower())
		if grid == null or not grid.has_meta("layout"):
			continue
		var layout: Dictionary = grid.get_meta("layout")
		var edge: float = float(layout.edge)
		var count: int = die.faces.size()
		var faces: Array = []
		_faces(grid, faces)
		check(faces.size() == count, "a %s shows every one of its %d faces (got %d)" % [shape.to_lower(), count, faces.size()])
		check(grid.get_child_count() == int(layout.rows), "a %s stands in %d rows (got %d)" % [shape.to_lower(), int(layout.rows), grid.get_child_count()])
		match shape:
			"D6":
				check(edge == 32.0 and grid.get_child_count() == 1, "a d6 is one row of 32 px faces (%d px, %d rows)" % [int(edge), grid.get_child_count()])
			"D20", "D30", "D50":
				check(edge == 32.0 and grid.get_child_count() <= 3, "a %s is 32 px faces in at most three rows (%d px, %d rows)" % [shape.to_lower(), int(edge), grid.get_child_count()])
			"D100":
				check(grid.get_child_count() <= 4, "a d100 stands in at most four rows (%d px, %d rows)" % [int(edge), grid.get_child_count()])
		var sized: bool = faces.all(func(f: DiceIcons.Face) -> bool: return is_equal_approx(f.custom_minimum_size.x, edge))
		check(sized, "every chip of a %s is %d px" % [shape.to_lower(), int(edge)])
		## At 32 px the face is the picker's own drawing; a smaller one keeps two digits at 10 px
		## or more and three at the picker's floor, none running out of its face's box.
		var drawn_right: Array = faces.filter(func(f: DiceIcons.Face) -> bool:
			if edge >= 32.0:
				return not f.picker
			var drawn: int = f.text_size(edge)
			var wide: float = DeepUi.bold_font().get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, drawn).x
			return f.picker and drawn >= (10 if f.text.length() <= 2 else DiceIcons.Face.PICKER_FLOOR) and wide <= edge)
		check(drawn_right.size() == faces.size(), "every face of a %s is drawn for its %d px (%d of %d)" % [shape.to_lower(), int(edge), drawn_right.size(), faces.size()])
		## The last chip picks its face: a real index of the die.
		var last_row: Node = grid.get_child(grid.get_child_count() - 1)
		var last: Control = last_row.get_child(last_row.get_child_count() - 1)
		_click(last)
		check(int(ask.extras.get("face", -1)) == count - 1, "clicking the last chip of a %s picks face %d (got %s)" % [shape.to_lower(), count - 1, str(ask.extras.get("face", null))])
		check(not ask.payload().is_empty(), "with a face picked the %s's ask has its answer" % shape.to_lower())
		ask.close()
	## Like faces share a chip only where no face fits: a split d40 in a sheet left almost no
	## room (the dock standing nearly to the top) shares its four 1s, and the chip picks one
	## of them by its real index.
	var d40: Dictionary = DeepDice.make("D40", "ui_D40", {"pattern": "split"})
	var groups: Array = AskSheet.face_groups(d40.faces, false, true, true)
	check(groups.size() < d40.faces.size() and int(groups[0].value) == 1 and groups[0].indices.size() == 4, "grouped, a split d40's four 1s share one chip (%d chips)" % groups.size())
	check(AskSheet.face_groups(d40.faces, false, true).size() == d40.faces.size(), "ungrouped, every face of it has a chip")
	check(AskSheet.face_groups(d40.faces, true, true).all(func(g: Dictionary) -> bool: return int(g.value) > 1), "lowering leaves the 1s out of the chips")
	var blanked: Dictionary = d40.duplicate(true)
	DeepDice.etch(blanked, 5, "blank")
	check(AskSheet.face_groups(blanked.faces, false, false).all(func(g: Dictionary) -> bool: return str(g.kind) != "blank"), "with blanks off a blank face has no chip")
	_open_carver(ask, d40)
	await _frames(1)
	## Set after the die is taken (the descent screen sets the floor again whenever the ask
	## changes), and the sheet drawn again in it.
	var floor_was: float = ask.floor_height
	ask.floor_height = float(CANVAS.y) - 120.0
	ask._build()
	await _frames(1)
	var grid40: Node = ask._block.find_child("Faces", true, false)
	var shared: Control = null
	for row in grid40.get_children():
		for chip in row.get_children():
			if shared == null and chip.get_meta("faces", []).size() > 1:
				shared = chip
	check(shared != null, "with no room for every face, the split d40's like faces share chips")
	if shared != null:
		var indices: Array = shared.get_meta("faces")
		_click(shared)
		var picked: Variant = ask.extras.get("face", null)
		check(picked is int and indices.has(picked) and int(picked) >= 0 and int(picked) < d40.faces.size(), "the shared chip picks a real face index of its group (got %s of %s)" % [str(picked), str(indices)])
		check(DeepDice.face_value(d40.faces[int(picked)]) == int(DeepDice.face_value(d40.faces[int(indices[0])])), "the face picked is one of the like faces")
		await _frames(1)
		var again: Control = null
		for row in ask._block.find_child("Faces", true, false).get_children():
			for chip in row.get_children():
				if again == null and chip.get_meta("faces", []) == indices:
					again = chip
		if again != null:
			_click(again)
			check(ask.extras.get("face", null) == picked, "clicking the chosen chip again keeps its face")
			check(_label_count(again, "×4") == 1, "the shared chip says ×4")
	ask.close()
	ask.floor_height = floor_was
	check(not ask.is_open(), "the ask closes")

func _three_faces(descent: Control) -> void:
	## A Smith's Voucher's carver (Nov 5, round 4; docs/DEEP_START.md §4): up to three faces of
	## one die or several, on the same 32 px faces in the same rows, a count of how many are
	## chosen, and the answer sent as {"picks": [{die_id, face}, ...]}.
	var ask: Control = descent._ask
	var dock: Control = descent._run_dock
	var improved: Dictionary = {}
	for choice in DeepContent.oddity("CARVER").get("choices", []):
		if str(choice.get("id", "")) == "raise":
			improved = choice.improved.duplicate(true)
			improved.id = "raise"
			improved.improved = true
	check(str(improved.get("needs", "")) == "die_faces" and int(improved.get("most", 0)) == 3, "the carver's better raise wants up to three faces")
	var d6: Dictionary = DeepDice.make("D6", "ui3_d6")
	var d20: Dictionary = DeepDice.make("D20", "ui3_d20")
	var unit: Dictionary = descent.me().duplicate(true)
	unit.dice = [d6, d20]
	var spec: Dictionary = descent._ask_spec(improved, unit, DeepUi.ACCENT, "CARVER", false)
	check(int(spec.get("faces", {}).get("most", 0)) == 3 and spec.get("build", Callable()).is_valid(), "its ask takes up to three faces and builds the picks")
	ask.open(spec)
	ask.take("die", "ui3_d6")
	await _frames(2)
	var chips: Array = _face_chips(ask)
	check(chips.size() == 6, "a d6's six faces are shown to pick from (got %d)" % chips.size())
	var faces: Array = []
	_faces(ask._block.find_child("Faces", true, false), faces)
	check(faces.all(func(f: DiceIcons.Face) -> bool: return is_equal_approx(f.custom_minimum_size.x, 32.0)), "the three-face picker keeps the 32 px faces")
	_click(chips[0])
	await _frames(1)
	_click(_face_chips(ask)[2])
	await _frames(1)
	check(ask.chosen_faces().size() == 2 and _label_count(ask._block, "2 of 3 chosen") == 1, "two faces picked are counted: 2 of 3 (got %d)" % ask.chosen_faces().size())
	check(not ask.payload().is_empty(), "one face or more is an answer")
	## Another die in the slot keeps the first die's faces and adds one of its own.
	ask.take("die", "ui3_d20")
	await _frames(2)
	check(ask.chosen_faces().size() == 2 and _face_chips(ask).size() == 20, "a second die keeps the first's two faces and shows its own twenty")
	_click(_face_chips(ask)[19])
	await _frames(1)
	_click(_face_chips(ask)[18])
	await _frames(1)
	check(ask.chosen_faces().size() == 3 and _label_count(ask._block, "3 of 3 chosen") == 1, "a fourth face is refused at three (got %d)" % ask.chosen_faces().size())
	var picks: Array = ask.payload().get("picks", [])
	check(picks.size() == 3 and picks[0] == {"die_id": "ui3_d6", "face": 0} and picks[1] == {"die_id": "ui3_d6", "face": 2} and picks[2] == {"die_id": "ui3_d20", "face": 19},
		"the answer is the three faces, each with its die: %s" % str(picks))
	var want: Vector2 = ask._block.get_combined_minimum_size()
	var floor_height: float = dock.height() if dock.visible else 0.0
	check(want.y + 28.0 <= float(CANVAS.y) - floor_height, "the three-face ask with a d20 stands clear of the dock (%d tall)" % int(want.y))
	## A chosen face clicked again is put back, and its chip under the counter does the same.
	_click(_face_chips(ask)[19])
	await _frames(1)
	check(ask.chosen_faces().size() == 2, "a chosen face clicked again is put back")
	var count_row: Node = ask._block.find_child("FaceCount", true, false)
	var put_back: Control = null
	if count_row != null:
		for child in count_row.get_children():
			if child is PanelContainer and put_back == null:
				put_back = child
	if put_back != null:
		_click(put_back)
		await _frames(1)
	check(ask.chosen_faces().size() == 1, "a chosen face's chip under the count puts it back")
	ask.close()

func _round5(app: Control, descent: Control) -> void:
	## Nov 5 round 5, on the owner's window: a Hammered card's charge page stands clear of the
	## dock with a die struck, and an upgraded card's "Upgraded" pill sits on its top right
	## corner over the border, its heading where a plain card's is.
	var run: Dictionary = app.session.run.duplicate(true)
	var me_id: String = app.session.local_id
	var unit: Dictionary = DeepDescent.player(run, me_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	run.phase = "grubstake"
	unit.stake = ""
	unit.temps = []
	unit.erase("dice_offers")
	unit.erase("twin")
	var hammer: Dictionary = DeepBoons._make_offer(run, unit, "kit", ["HAMMERED"], rng, 4)
	hammer.id = "stake0"
	run.grubstake = {"offers": {me_id: [hammer]}, "chosen": {}}
	descent._stake_choosing = "stake0"
	descent.show_state(run)
	descent._charge_hit(hammer, str(unit.dice[0].id))
	await _frames(3)
	var row: Control = descent._page_holder.find_child("ChargeDice", true, false)
	var room: Rect2 = (descent._area as Control).get_global_rect()
	check(row != null and room.encloses(row.get_global_rect()) and row.get_global_rect().size.x <= float(CANVAS.x),
		"the charge page's dice stand in the room above the dock (%s in %s)" % [str(row.get_global_rect() if row != null else Rect2()), str(room)])
	run.phase = "chamber"
	run.chamber = {"kind": "smithy", "oddity": "SMITHY", "results": {}, "depth": 2, "settled": false, "vouchered": [me_id], "offer": {"pattern": "split"}}
	unit.vouchers = 1
	unit.oddity_choice = ""
	unit.downed = false
	descent._stake_choosing = ""
	descent._oddity_step = ""
	descent.show_state(run)
	await _frames(3)
	var pill: Control = descent._page_holder.find_child("UpgradedBadge", true, false)
	var card: Control = pill.get_parent().get_parent() if pill != null else null
	check(pill != null and card is PanelContainer and _label_count(pill, "Upgraded") == 1, "an upgraded card wears an Upgraded pill")
	if pill != null and card != null:
		var at: Rect2 = pill.get_global_rect()
		var edge: Rect2 = card.get_global_rect()
		check(at.position.y < edge.position.y and at.end.y > edge.position.y and at.end.x <= edge.end.x and at.end.x >= edge.end.x - 40.0,
			"the pill sits on the card's top right corner, over its border (%s on %s)" % [str(at), str(edge)])
		var heading: Node = card.get_child(0).get_child(0) if card.get_child_count() > 0 and card.get_child(0).get_child_count() > 0 else null
		var pad: float = card.get_theme_stylebox("panel").get_margin(SIDE_TOP)
		check(heading is HBoxContainer and absf((heading as Control).get_global_rect().position.y - edge.position.y - pad) <= 1.0,
			"the card's heading stands at its top, where a plain card's does")
	descent.show_state(app.session.run)

func _round6(app: Control, descent: Control) -> void:
	## Nov 5 round 6, on the owner's window: choosing a Bag of Gems stone moves nothing (its check
	## rides the card's corner); the Bag of Dice has the bag on top and your dice under it as the
	## dock draws them; the Upgraded pill is padded as the round-4 pill was.
	var run: Dictionary = app.session.run.duplicate(true)
	var me_id: String = app.session.local_id
	run.mine = "WARRENS"
	run.deep_start = 3
	run.phase = "grubstake"
	var unit: Dictionary = DeepDescent.player(run, me_id)
	unit.stake = ""
	unit.temps = []
	unit.erase("dice_offers")
	unit.erase("twin")
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var hand: Array = [DeepBoons._make_deep_offer(run, unit, "BAG_OF_GEMS", rng, 3), DeepBoons._make_deep_offer(run, unit, "BAG_OF_DICE", rng, 3)]
	DeepBoons._number(hand)
	run.grubstake = {"offers": {me_id: hand}, "chosen": {}}
	descent._stake_choosing = "stake0"
	descent.show_state(run)
	await _frames(3)
	var before: Array = _card_rects(descent._page_holder.find_child("GemBag", true, false))
	descent._gem_bag_toggle(hand[0], 1)
	await _frames(3)
	var bag: Node = descent._page_holder.find_child("GemBag", true, false)
	var after: Array = _card_rects(bag)
	check(not before.is_empty() and before == after, "choosing a stone moves no card on the page (%d cards)" % before.size())
	## Round 7: no check at all; the gold rim alone marks the chosen stone.
	var rimmed: int = 0
	if bag != null:
		for row in bag.get_children():
			for card in row.get_children():
				if bool(card.get_meta("chosen", false)):
					rimmed += 1
	check(bag != null and bag.find_child("Chosen", true, false) == null and rimmed == 1, "the chosen stone wears its gold rim and no check (%d rimmed)" % rimmed)
	descent._stake_choosing = "stake1"
	descent.show_state(run)
	await _frames(3)
	var bag_row: Control = descent._page_holder.find_child("BagDice", true, false)
	var plate: Control = descent._page_holder.find_child("HandPlate", true, false)
	var tray: Node = plate.find_child("OwnDice", true, false) if plate != null else null
	check(bag_row != null and plate != null and bag_row.get_global_rect().end.y <= plate.get_global_rect().position.y, "the bag stands over your dice")
	var thumbs: Array = []
	_die_thumbs(tray, thumbs)
	check(tray != null and tray.get_child_count() == unit.dice.size() and thumbs.size() == unit.dice.size() and thumbs.all(func(t: Control) -> bool: return is_equal_approx(t.custom_minimum_size.x, BattleUi.DIE_EDGE)),
		"your dice stand on a plate at the dock's size (%d of %d)" % [thumbs.size(), unit.dice.size()])
	var room: Rect2 = (descent._area as Control).get_global_rect()
	check(plate != null and room.encloses(plate.get_global_rect()), "and the plate stands clear of the dock")
	## Round 9: the plate is its round-7 size (its padding round the dice and nothing more), the
	## dice centred on it; "Your dice" is laid over its top left, inside it, over no die.
	if plate != null and tray is Control:
		var pad: StyleBox = plate.get_theme_stylebox("panel")
		var tall: float = plate.get_global_rect().size.y - (tray as Control).get_global_rect().size.y
		check(is_equal_approx(tall, pad.get_margin(SIDE_TOP) + pad.get_margin(SIDE_BOTTOM)) and is_equal_approx(pad.get_margin(SIDE_TOP), 12.0),
			"the plate is no taller than its padding round the dice (%d px more than the dice)" % int(tall))
		var above: float = (tray as Control).get_global_rect().position.y - plate.get_global_rect().position.y
		var below: float = plate.get_global_rect().end.y - (tray as Control).get_global_rect().end.y
		check(absf(above - below) <= 1.0, "your dice stand centred on their plate (%d over, %d under)" % [int(above), int(below)])
	## Round 10: "Your dice" in a pill on the plate's top border, in the plate's own fill and
	## border, centred on its line, on screen, 8 px at least under the bag's tiles, over no die.
	var named: Control = plate.find_child("HandLabel", true, false) if plate != null else null
	check(named is PanelContainer and _label_count(named, "Your dice") == 1, "the plate wears \"Your dice\" in a pill")
	if named is PanelContainer and plate != null:
		var pill_style: StyleBox = named.get_theme_stylebox("panel")
		var plate_style: StyleBox = plate.get_theme_stylebox("panel")
		check(pill_style is StyleBoxFlat and plate_style is StyleBoxFlat and (pill_style as StyleBoxFlat).border_color == (plate_style as StyleBoxFlat).border_color
			and (pill_style as StyleBoxFlat).border_width_top == (plate_style as StyleBoxFlat).border_width_top and (pill_style as StyleBoxFlat).bg_color == (plate_style as StyleBoxFlat).bg_color,
			"the pill wears the plate's own fill, and its border's colour and width")
	if named != null and plate != null:
		var words: Rect2 = named.get_global_rect()
		var edge: Rect2 = plate.get_global_rect()
		var pad: StyleBox = plate.get_theme_stylebox("panel")
		var line: float = edge.position.y + (float((pad as StyleBoxFlat).border_width_top) * 0.5 if pad is StyleBoxFlat else 1.5)
		check(absf(words.get_center().y - line) <= 1.0, "the legend is centred on the plate's top border (%d from its line)" % int(words.get_center().y - line))
		check(Rect2(Vector2.ZERO, Vector2(CANVAS)).encloses(words), "the legend is on the screen (%s)" % str(words))
		var tiles: Array = bag_row.get_children().filter(func(c: Node) -> bool: return c is Control) if bag_row != null else []
		var clearance: float = INF
		for tile in tiles:
			var over: Rect2 = (tile as Control).get_global_rect()
			if over.position.x < words.end.x and over.end.x > words.position.x:
				clearance = minf(clearance, words.position.y - over.end.y)
		check(not tiles.is_empty() and clearance >= 8.0, "the pill stands clear of the bag's tiles above it (%s px)" % str(clearance))
		check(not thumbs.any(func(t: Control) -> bool: return t.get_global_rect().intersects(words)), "the legend lies over no die (%s)" % str(words))
		check(words.position.x - edge.position.x >= 14.0, "the legend stands clear of the plate's cut corner (%d px in)" % int(words.position.x - edge.position.x))
	check(_label_count(descent._page_holder, "The bag") == 0, "the bag's row has no heading over it")
	run.phase = "chamber"
	run.chamber = {"kind": "smithy", "oddity": "SMITHY", "results": {}, "depth": 2, "settled": false, "vouchered": [me_id], "offer": {"pattern": "split"}}
	unit.vouchers = 1
	unit.oddity_choice = ""
	unit.downed = false
	descent._stake_choosing = ""
	descent._oddity_step = ""
	descent.show_state(run)
	await _frames(3)
	var pill: Control = descent._page_holder.find_child("UpgradedBadge", true, false)
	var pad: float = pill.get_theme_stylebox("panel").get_margin(SIDE_LEFT) if pill != null else 0.0
	check(pill != null and pad >= 9.0 and pill.get_global_rect().size.y >= 24.0, "the Upgraded pill is padded as a pill is (%d px in, %d tall)" % [int(pad), int(pill.get_global_rect().size.y) if pill != null else 0])
	descent.show_state(app.session.run)

func _card_rects(node: Node) -> Array:
	## Where every card in a row of rows stands, on the screen.
	var out: Array = []
	if node == null:
		return out
	for row in node.get_children():
		for card in row.get_children():
			if card is Control:
				out.append((card as Control).get_global_rect())
	return out

func _die_thumbs(node: Node, out: Array) -> void:
	## Every die picture in a subtree.
	if node == null:
		return
	if node is ThumbsUi.DieThumb:
		out.append(node)
	for child in node.get_children():
		_die_thumbs(child, out)

func _face_chips(ask: Control) -> Array:
	## The face picker's chips, in order.
	var out: Array = []
	var grid: Node = ask._block.find_child("Faces", true, false) if ask._block != null else null
	if grid == null:
		return out
	for row in grid.get_children():
		for chip in row.get_children():
			out.append(chip)
	return out

func _open_carver(ask: Control, die: Dictionary) -> void:
	ask.open({"key": "ui_carver", "title": "Raise a face", "text": "Pick a die face and raise it by 1. There's no cap. A blank face becomes a 1. Any etching on it stays.",
		"glyph": "chisel", "tone": DeepUi.ACCENT, "confirm": "Do it",
		"slots": [{"key": "die_id", "kind": "die", "label": "Which die?", "items": [die], "refusals": {}}],
		"faces": {"key": "face", "of": "die_id", "blanks": true, "lowering": false, "label": "Which face?"}})
	ask.take("die", str(die.id))

func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	control.gui_input.emit(event)

# --- helpers ------------------------------------------------------------------------------------

func _chart_matches(descent: Control, where: String) -> void:
	## The chart, opened with the bag, stands from the same top to the same foot as the bag
	## column, clear of the dock and the party's tabs.
	if not descent._chart_open:
		descent.toggle_chart()
	await _frames(2)
	var chart: Rect2 = (descent._map as Control).get_global_rect()
	var column: Rect2 = descent._run_dock._drawer.get_global_rect()
	var dock_rect: Rect2 = descent._run_dock._dock.get_global_rect()
	check(absf(chart.position.y - column.position.y) <= 1.0 and absf(chart.end.y - column.end.y) <= 1.0, "%s the chart stands as tall as the bag column (chart %s, column %s)" % [where, str(chart), str(column)])
	check(not chart.intersects(dock_rect) and (not descent._run_dock._tab_bar.visible or chart.end.y <= descent._run_dock._tab_bar.get_global_rect().position.y + 0.5), "%s the chart's foot clears the dock and the tabs" % where)

func _band(dock: Control) -> float:
	## The empty column between the last row of tiles and the foot: the tiles' room as laid out,
	## less the grid of a full page.
	var room: Control = dock._drawer.find_child("Tiles", true, false)
	if room == null or dock._tiles == null:
		return INF
	return room.size.y - dock._tiles.get_combined_minimum_size().y

func _dock_shape(dock: Control) -> Array:
	## What the bag opening must leave alone: the dock's rect, its content's least size, and
	## the health ring's size and where it stands.
	var ring: Control = dock._ring
	return [dock._dock.get_global_rect(), dock._dock.get_combined_minimum_size(), ring.size if ring != null and is_instance_valid(ring) else Vector2.ZERO,
		ring.get_global_rect().position if ring != null and is_instance_valid(ring) else Vector2.ZERO]

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _faces(node: Node, out: Array) -> void:
	if node is DiceIcons.Face:
		out.append(node)
	for child in node.get_children():
		_faces(child, out)

func _count_class(node: Node, klass: Variant) -> int:
	var count: int = 1 if is_instance_of(node, klass) else 0
	for child in node.get_children():
		count += _count_class(child, klass)
	return count

func _count_text(node: Node, text: String) -> int:
	var count: int = 1 if node is Button and (node as Button).text == text else 0
	for child in node.get_children():
		count += _count_text(child, text)
	return count

func _label_count(node: Node, fragment: String) -> int:
	var count: int = 1 if node is Label and (node as Label).text.contains(fragment) else 0
	for child in node.get_children():
		count += _label_count(child, fragment)
	return count

func _scan(node: Node, bounds: Rect2, found: Array) -> void:
	## Everything a container lays out inside `bounds` stays inside it (tests/test_fit.gd's rule).
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is ScrollContainer:
		found.append("%s scrolls" % node.name)
		return
	if node is Control and (node is Container or node.get_parent() is Container):
		var rect: Rect2 = (node as Control).get_global_rect()
		if rect.size.x > 0.5 and rect.size.y > 0.5 and not bounds.grow(1.5).encloses(rect):
			found.append("%s at %s runs past %s" % [node.name, str(rect), str(bounds)])
			return
	for child in node.get_children():
		_scan(child, bounds, found)
