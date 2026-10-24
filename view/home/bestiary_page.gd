extends RefCounted
## The bestiary: every creature in the mines on one list, and the creature picked on the
## right, live on its plinth and turning, with what it is, where it lives, what it does, and
## what the player has made of it so far.
##
## The list is the map's cross-section: one band per mine, top to bottom, each in its own
## rock with the shaft down its left side (lit where the mine is open, a lock where it is
## sealed), and in each band the creatures filed under that mine. It is the one list in the
## workshop besides the vault's that scrolls, so the whole of the mines reads as one descent.
##
## A creature not met yet is only its shadow, with no name and nothing said but where it is
## found. The portraits are pictures baked ahead of time (tools/creature_portraits.gd) and
## read on a worker thread, and the bands are laid in a frame apart, so opening the tab never
## stalls: the picked creature is the one live 3D view on the page. What the player has met
## comes from their profile (DeepBestiary).

const Inspector = preload("res://view/inspect/inspector.gd")
const CreatureStage = preload("res://view/creatures/creature_stage.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const MineMap = preload("res://view/home/mine_map.gd")

const PORTRAITS: String = "res://view/creatures/portraits/"
const TILE: float = 96.0
const COLUMNS: int = 4
## Moves to a page of the picked creature's sheet, as on the inspector's.
const MOVES_PAGE: int = 4
const UNSEEN := Color(0.02, 0.03, 0.07, 0.92)
const ROLE_WORDS: Dictionary = {"warden": ["crown", "Warden", DeepUi.BAD], "boss": ["crown", "Final boss", DeepUi.ACCENT],
	"unmade": ["crown", "The Rift's own", Color("b8a8ff")], "escort": ["copy", "Escort", DeepUi.INFO]}

## Every portrait read so far, by path, so the list opens on pictures already in hand.
static var _pictures: Dictionary = {}

static func portrait(key: String) -> Texture2D:
	## The creature's baked picture, read now, or null for one not baked yet.
	var path: String = PORTRAITS + key.to_lower() + ".png"
	if not _pictures.has(path) and ResourceLoader.exists(path):
		_pictures[path] = load(path)
	return _pictures.get(path, null)

static func show_portrait(picture: TextureRect, key: String) -> void:
	## The picture into `picture`: at once if it has been read, or as soon as a worker thread
	## has read it.
	var path: String = PORTRAITS + key.to_lower() + ".png"
	if _pictures.has(path) or DisplayServer.get_name() == "headless":
		picture.texture = portrait(key)
		return
	if not ResourceLoader.exists(path):
		return
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	picture.add_child(Arrival.new(path))

static func _arrived(path: String) -> Texture2D:
	## A portrait a worker thread was reading, once it has: null while it is still reading.
	if not _pictures.has(path):
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return null
			ResourceLoader.THREAD_LOAD_LOADED:
				_pictures[path] = ResourceLoader.load_threaded_get(path)
			_:
				## Collected by another waiting picture already, or failed: read it here.
				_pictures[path] = load(path)
	return _pictures[path]

class Arrival extends Node:
	## Waits on one portrait's thread and hangs it on the picture it is a child of. Freed with
	## the picture, so a list rebuilt before it arrives never reaches a freed picture.
	var path: String
	func _init(portrait_path: String) -> void:
		path = portrait_path
	func _process(_delta: float) -> void:
		var texture: Texture2D = load("res://view/home/bestiary_page.gd").call("_arrived", path)
		if texture == null:
			return
		(get_parent() as TextureRect).texture = texture
		queue_free()

static func build(home: Control, content: VBoxContainer) -> void:
	var order: Array = DeepBestiary.order()
	if not order.has(home._bestiary_pick) and not order.is_empty():
		home._bestiary_pick = _first_pick(home, order)
		home._bestiary_scroll = -1.0
	_head(home, content, order)
	var columns := DeepUi.hbox(content, 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## The list's frame is the map's: dark, faceted, the strata running to its edges.
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07080b")
	style.set_corner_radius_all(16)
	DeepUi.facet(style)
	style.border_color = Color(DeepUi.LINE_HI, 0.6)
	style.set_border_width_all(1)
	style.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", style)
	frame.clip_contents = true
	columns.add_child(frame)
	var scroller := ScrollContainer.new()
	scroller.name = "BestiaryScroll"
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## The second scrollbar in the workshop, beside the vault's, and here on purpose: the
	## mines read as one descent.
	scroller.set_meta("may_scroll", true)
	frame.add_child(scroller)
	## The theme's scrollbar has no width of its own; this one is given a slim track, so the
	## list shows that it runs on below.
	var track := DeepUi.flat(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 4, 0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	scroller.get_v_scroll_bar().add_theme_stylebox_override("scroll", track)
	scroller.get_v_scroll_bar().value_changed.connect(func(value: float) -> void:
		if bool(scroller.get_meta("settled", false)):
			home._bestiary_scroll = value)
	var list := DeepUi.vbox(scroller, 0)
	list.name = "BestiaryList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.region(list, "bestiary_list", func(holder: Control) -> void: _list(home, holder))
	home.enter(frame, 0.05)
	var detail_card := DeepUi.card(columns, DeepUi.LINE, 16)
	detail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.region(DeepUi.hbox(detail_card, 22), "bestiary_detail", func(holder: Control) -> void: _detail(home, holder))
	home.enter(detail_card, 0.1)

static func _first_pick(home: Control, order: Array) -> String:
	## A new creature first, then the deepest the player has met, then the first of all.
	for key in order:
		if bool(DeepBestiary.entry(home.profile, str(key)).get("fresh", false)):
			return str(key)
	for index in range(order.size() - 1, -1, -1):
		if DeepBestiary.known(home.profile, str(order[index])):
			return str(order[index])
	return str(order[0])

static func pick(home: Control, key: String) -> void:
	## The creature onto the plinth. The list is not built again: the two tiles change their
	## frames in place, so it stays exactly where it was scrolled.
	if home._bestiary_pick == key:
		return
	DeepAudio.play("ui_tap", {"volume": 0.7})
	var was: String = home._bestiary_pick
	home._bestiary_pick = key
	home._bestiary_leaf = 0
	var list: Control = home.region_holder("bestiary_list")
	if list != null:
		_restyle(home, list, was)
		_seen(home, list, key)
		_restyle(home, list, key)
	elif DeepBestiary.unfresh(home.profile, key):
		home.touch()
	if not home.redraw(["bestiary_detail"]):
		home._render()

# --- the head ----------------------------------------------------------------------------------

static func _head(home: Control, content: VBoxContainer, order: Array) -> void:
	var head := DeepUi.hbox(content, 12)
	DeepUi.icon(head, "book", 28, DeepUi.ACCENT)
	DeepUi.title(head, "Bestiary", 30, DeepUi.PAPER)
	DeepUi.gap(head, 6)
	DeepUi.label(head, "Every creature you have met, and where the rest are waiting, from the Quarry down.", 13, DeepUi.DIM)
	DeepUi.spacer(head)
	var met: int = DeepBestiary.known_count(home.profile, order)
	DeepUi.label(head, "%d of %d met" % [met, order.size()], 14, DeepUi.MUTED)
	var meter := DeepUi.bar(head, 8.0, DeepUi.ACCENT, Color(DeepUi.LINE, 0.6))
	meter.custom_minimum_size = Vector2(140, 8)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.set_values(float(met) / float(maxi(1, order.size())))
	home.enter(head)

# --- the list ----------------------------------------------------------------------------------

static func _list(home: Control, holder: Control) -> void:
	var mines: Array = DeepContent.mines_in_order()
	## A band a frame when the tab first opens; all at once when it is only drawn again.
	_fill(home, holder, mines, 0, 1 if home._fresh and not home._headless else mines.size())

static func _fill(home: Control, holder: Control, mines: Array, from: int, per_frame: int) -> void:
	if not is_instance_valid(holder):
		return
	var upto: int = mini(mines.size(), from + maxi(1, per_frame))
	## The first sealed mine has rubble choking the shaft where it begins, as on the map.
	var sealed_above: bool = false
	for index in range(from):
		sealed_above = sealed_above or not _open(home, str(mines[index]))
	for index in range(from, upto):
		var key: String = str(mines[index])
		_stratum(home, holder, key, index, not sealed_above and not _open(home, key))
		sealed_above = sealed_above or not _open(home, key)
	var tree := Engine.get_main_loop() as SceneTree
	var held: WeakRef = weakref(holder)
	if upto < mines.size():
		## Held weakly: a page rebuilt before the list is full frees it, and the next frame
		## must find it gone rather than call into a freed capture.
		tree.process_frame.connect(func() -> void:
			var still: Control = held.get_ref() as Control
			if still != null:
				_fill(home, still, mines, upto, per_frame), CONNECT_ONE_SHOT)
		return
	## Every band is down: back to where the list was, or to the creature picked, once it
	## has been laid out.
	tree.process_frame.connect(func() -> void:
		var still: Control = held.get_ref() as Control
		if still != null:
			_settle(home, still), CONNECT_ONE_SHOT)

static func _settle(home: Control, list: Control) -> void:
	var scroller := list.get_parent() as ScrollContainer
	if scroller == null:
		return
	if home._bestiary_scroll >= 0.0:
		scroller.scroll_vertical = int(home._bestiary_scroll)
	else:
		## The creature picked, in the middle of the list's window.
		var tile: Node = list.find_child("Creature_" + home._bestiary_pick, true, false)
		if tile is Control:
			var down: float = (tile as Control).global_position.y - list.global_position.y
			scroller.scroll_vertical = int(down + (tile as Control).size.y * 0.5 - scroller.size.y * 0.5)
	scroller.set_meta("settled", true)
	home._bestiary_scroll = scroller.scroll_vertical

static func _open(home: Control, mine_key: String) -> bool:
	return bool(home.profile.get("mines", {}).get(mine_key, {}).get("unlocked", false))

static func _stratum(home: Control, list: Control, mine_key: String, index: int, rubble: bool) -> void:
	## One mine's band: its numeral, name and rock, how many of its creatures are met, and
	## the creatures themselves.
	var mine: Dictionary = DeepContent.mine(mine_key)
	var record: Dictionary = home.profile.get("mines", {}).get(mine_key, {})
	var open: bool = _open(home, mine_key)
	var band := Stratum.new(mine_key, index, open, rubble)
	band.name = "Stratum_" + mine_key
	list.add_child(band)
	var box := DeepUi.vbox(band, 10)
	var head := DeepUi.hbox(box, 10)
	head.add_child(Badge.new(MineMap.numeral(mine_key), band.tone, open))
	var names := DeepUi.vbox(head, 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.title(names, str(mine.get("name", mine_key)), 19, DeepUi.PAPER if open else DeepUi.DIM)
	var keys: Array = DeepBestiary.in_mine(mine_key)
	var state: String = "SEALED" if not open else ("BEATEN" if bool(record.get("boss", false)) else "OPEN")
	var words := DeepUi.label(names, "%s  ·  %s  ·  %d OF %d MET" % [str(Biomes.for_depth(mine_key, 1).get("name", "")).to_upper(), state,
		DeepBestiary.known_count(home.profile, keys), keys.size()], 12, Color(band.tone, 0.85 if open else 0.45))
	words.add_theme_font_override("font", DeepUi.caps_font())
	var fresh := DeepUi.chip(head, "0 NEW", home.PIP_NEW, 12)
	fresh.name = "Fresh"
	fresh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count_fresh(home, band)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for key in keys:
		_tile(home, grid, str(key))

static func _count_fresh(home: Control, band: Stratum) -> void:
	## The band's chip for how many of its creatures are new, hidden when none are.
	var chip: Node = band.find_child("Fresh", true, false)
	if not chip is Control:
		return
	var count: int = DeepBestiary.in_mine(band.mine).filter(func(k: Variant) -> bool:
		return bool(DeepBestiary.entry(home.profile, str(k)).get("fresh", false))).size()
	(chip as Control).visible = count > 0
	for label in chip.find_children("*", "Label", true, false):
		(label as Label).text = "%d NEW" % count

static func _tile_style(home: Control, key: String) -> StyleBoxFlat:
	var known: bool = DeepBestiary.known(home.profile, key)
	var role: String = DeepBestiary.role(key)
	var tone: Color = ROLE_WORDS[role][2] if ROLE_WORDS.has(role) else DeepUi.LINE_HI
	var style := DeepUi.raised(Color(DeepUi.SLATE, 0.92), Color(tone, 0.5) if known else Color(DeepUi.LINE, 0.6), 12, 8, 0.3)
	style.border_width_bottom = 3
	if key == home._bestiary_pick:
		style.border_color = DeepUi.ACCENT
		style.set_border_width_all(2)
		style.bg_color = Color(DeepUi.SLATE, 0.92).lerp(DeepUi.ACCENT, 0.14)
	elif bool(DeepBestiary.entry(home.profile, key).get("fresh", false)):
		## New to the bestiary: it glows until the pointer first rests on it, as a new stone
		## in the vault does.
		style.border_color = home.PIP_NEW
		style.set_border_width_all(2)
		style.shadow_color = Color(home.PIP_NEW, 0.4)
		style.shadow_size = 10
		style.shadow_offset = Vector2.ZERO
	return style

static func _restyle(home: Control, list: Control, key: String) -> void:
	var tile: Node = list.find_child("Creature_" + key, true, false)
	if tile is PanelContainer:
		(tile as PanelContainer).add_theme_stylebox_override("panel", _tile_style(home, key))

static func _seen(home: Control, list: Control, key: String) -> void:
	## A new creature looked at: its tag and glow go, and its band's count of new ones drops.
	if not DeepBestiary.unfresh(home.profile, key):
		return
	home.touch()
	var tile: Node = list.find_child("Creature_" + key, true, false)
	if tile == null:
		return
	var tag: Node = tile.find_child("New", true, false)
	if tag != null:
		tag.queue_free()
	_restyle(home, list, key)
	var band: Node = list.find_child("Stratum_" + DeepBestiary.home(key), false, false)
	if band is Stratum:
		_count_fresh(home, band)

static func _tile(home: Control, grid: GridContainer, key: String) -> void:
	var def: Dictionary = DeepContent.creature(key)
	var record: Dictionary = DeepBestiary.entry(home.profile, key)
	var known: bool = int(record.get("met", 0)) > 0
	var role: String = DeepBestiary.role(key)
	var tile := PanelContainer.new()
	tile.name = "Creature_" + key
	tile.add_theme_stylebox_override("panel", _tile_style(home, key))
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	grid.add_child(tile)
	var column := DeepUi.vbox(tile, 4)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(TILE, TILE)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(frame)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	## Drawn well under the size it was baked at: read from its mipmaps, or it shimmers.
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not known:
		picture.self_modulate = UNSEEN
	frame.add_child(picture)
	show_portrait(picture, key)
	if not known:
		var mark := DeepUi.icon(frame, "question", TILE * 0.32, Color(DeepUi.MUTED, 0.55))
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif ROLE_WORDS.has(role):
		var badge := DeepUi.icon(frame, str(ROLE_WORDS[role][0]), 18, ROLE_WORDS[role][2])
		badge.position = Vector2(TILE - 20, 0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(record.get("fresh", false)):
		var tag := DeepUi.chip(frame, "NEW", home.PIP_NEW, 12)
		tag.name = "New"
		tag.position = Vector2(-2, -2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.mouse_entered.connect(func() -> void:
			var list: Control = home.region_holder("bestiary_list")
			if list != null:
				_seen(home, list, key), CONNECT_ONE_SHOT)
	var name: String = str(def.get("name", key)) if known else "???"
	DeepUi.fit_label(column, name, 13, DeepUi.PAPER if known else DeepUi.DIM, TILE)
	tile.tooltip_text = ("%s\nMet %d · Slain %d" % [name, int(record.get("met", 0)), int(record.get("slain", 0))]) if known else "Not met yet"
	DeepUi.juice(tile, 1.04)
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pick(home, key))

class Stratum extends MarginContainer:
	## One mine's band of the list, drawn as the map draws its strata: the mine's own rock
	## (darker while it is sealed) with a ragged top laid over the band above, and the shaft
	## down the left, lit where the mine is open, choked with rubble and locked where the way
	## down stops.
	const SHAFT_X := 24.0
	const SHAFT_WIDTH := 16.0
	var mine: String
	var tone: Color
	var rock: Color
	var open: bool
	var index: int
	var rubble: bool
	var _pebbles: Array = []
	func _init(mine_key: String, at: int, is_open: bool, choked: bool) -> void:
		mine = mine_key
		index = at
		open = is_open
		rubble = choked
		tone = Color(str(DeepContent.mine(mine_key).get("palette", "c9a26b")))
		rock = Color(Biomes.for_depth(mine_key, 1).rock).darkened(0.3 if open else 0.72)
		mouse_filter = Control.MOUSE_FILTER_PASS
		add_theme_constant_override("margin_left", 50)
		add_theme_constant_override("margin_right", 14)
		add_theme_constant_override("margin_top", 14)
		add_theme_constant_override("margin_bottom", 16)
		var rng := RandomNumberGenerator.new()
		rng.seed = 42 + at
		for i in range(16):
			_pebbles.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(1.5, 3.5)])
		resized.connect(queue_redraw)
	func _draw() -> void:
		## The rock, its top edge ragged over the band above (the first band's is flat).
		var steps: int = 14
		var edge := PackedVector2Array()
		for i in range(steps + 1):
			var x: float = size.x * float(i) / float(steps)
			edge.append(Vector2(x, sin(float(i) * 1.7 + float(index)) * 3.0 - 3.0 if index > 0 else 0.0))
		edge.append(Vector2(size.x, size.y))
		edge.append(Vector2(0, size.y))
		draw_colored_polygon(edge, rock)
		for pebble in _pebbles:
			draw_circle(Vector2(SHAFT_X + 20.0 + pebble[0].x * (size.x - SHAFT_X - 24.0), 6.0 + pebble[0].y * maxf(1.0, size.y - 12.0)), pebble[1], rock.lightened(0.08))
		var shaft := Rect2(Vector2(SHAFT_X - SHAFT_WIDTH * 0.5, 0), Vector2(SHAFT_WIDTH, size.y))
		if open:
			draw_rect(shaft, Color(0, 0, 0, 0.7))
			draw_rect(Rect2(shaft.position + Vector2(3, 0), Vector2(SHAFT_WIDTH - 6, size.y)), Color(DeepUi.ACCENT, 0.22))
			draw_line(shaft.position, shaft.position + Vector2(0, size.y), Color(DeepUi.ACCENT, 0.6), 1.5)
			draw_line(shaft.position + Vector2(SHAFT_WIDTH, 0), shaft.position + Vector2(SHAFT_WIDTH, size.y), Color(DeepUi.ACCENT, 0.6), 1.5)
			return
		if rubble:
			var stones := RandomNumberGenerator.new()
			stones.seed = 7 + index
			for i in range(5):
				draw_circle(Vector2(SHAFT_X + stones.randf_range(-6, 6), 2.0 + float(i) * 4.0), stones.randf_range(3, 5), Color("4a4038"))
		var lock_at := Vector2(SHAFT_X, 33)
		draw_circle(lock_at, 13.0, Color(0.03, 0.035, 0.05, 0.9))
		draw_texture_rect(GemIcons.texture("lock", GemIcons.baked_size(21.0)), Rect2(lock_at - Vector2(7, 7), Vector2(14, 14)), false, DeepUi.DIM)

class Badge extends Control:
	## A mine's numeral in a ring of its color, as on the map.
	var numeral: String
	var tone: Color
	var lit: bool
	func _init(text: String, color: Color, is_lit: bool) -> void:
		numeral = text
		tone = color
		lit = is_lit
		custom_minimum_size = Vector2(32, 38)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		draw_circle(centre, 15.0, Color(0, 0, 0, 0.35))
		draw_arc(centre, 15.0, 0, TAU, 28, Color(tone, 1.0 if lit else 0.4), 1.5, true)
		draw_string(DeepUi.caps_font(), centre + Vector2(-15, 4), numeral, HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color(tone, 1.0 if lit else 0.45))

# --- the creature picked ---------------------------------------------------------------------

static func _detail(home: Control, holder: Control) -> void:
	var key: String = home._bestiary_pick
	var def: Dictionary = DeepContent.creature(key)
	if def.is_empty():
		return
	var record: Dictionary = DeepBestiary.entry(home.profile, key)
	var known: bool = int(record.get("met", 0)) > 0
	var role: String = DeepBestiary.role(key)
	var tone: Color = ROLE_WORDS[role][2] if ROLE_WORDS.has(role) else Color("c8a8ff")
	var left := DeepUi.vbox(holder, 6)
	var stage_box := Control.new()
	stage_box.custom_minimum_size = Vector2(320, 500)
	stage_box.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(stage_box)
	var halo := Inspector.Halo.new(tone if known else DeepUi.LINE)
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_box.add_child(halo)
	if known:
		var stage := CreatureStage.new(key, bool(def.get("warden", false)))
		stage.name = "BestiaryStage"
		stage.fit = true
		stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage_box.add_child(stage)
		DeepUi.label(left, "Drag to turn it", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var shadow := TextureRect.new()
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		shadow.self_modulate = UNSEEN
		shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shadow.offset_left = 40
		shadow.offset_right = -40
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_box.add_child(shadow)
		show_portrait(shadow, key)
		var mark := DeepUi.icon(stage_box, "question", 72, Color(DeepUi.MUTED, 0.5))
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right := DeepUi.vbox(holder, 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := DeepUi.hbox(right, 10)
	DeepUi.title(title_row, str(def.get("name", key)) if known else "???", 28, DeepUi.PAPER if known else DeepUi.DIM)
	if ROLE_WORDS.has(role):
		DeepUi.pill(title_row, str(ROLE_WORDS[role][0]), str(ROLE_WORDS[role][1]), tone, 13).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not known:
		_unknown(home, right, key)
		return
	DeepUi.wrap(right, str(def.get("text", "")), 14, DeepUi.MUTED)
	var facts := DeepUi.hbox(right, 8)
	DeepUi.pill(facts, "heart", "%d health" % int(def.get("hp", 0)), DeepUi.BAD, 13,
		"Its health as written. Deeper floors, deeper mines and a bigger party breed it tougher.")
	DeepUi.pill(facts, "skull", "threat %d" % int(def.get("threat", 1)), DeepUi.MUTED, 13,
		"How much of a fight's budget it takes. Fights are made from a budget that grows with depth and the party.")
	if int(def.get("block", 0)) > 0:
		DeepUi.pill(facts, "shield", "%d block" % int(def.block), DeepUi.BLOCK, 13, "The block it starts every fight with.")
	var dice: Array = def.get("dice", [])
	if dice.is_empty():
		DeepUi.pill(facts, "die", "no dice of its own", DeepUi.DIM, 13)
	for die in dice:
		var shape: String = str(die.get("shape", die)) if die is Dictionary else str(die)
		DeepUi.pill(facts, "die", shape, DiceIcons.palette(shape).body, 13, "It rolls its dice in this order, and every move a die qualifies for fires.")
	home.region(DeepUi.vbox(right, 10), "bestiary_leaf", func(box: Control) -> void: _leaves(home, box, key, def, record))

static func _unknown(home: Control, right: VBoxContainer, key: String) -> void:
	## Not met: where to look, and nothing else.
	DeepUi.wrap(right, "Not met yet. Its name, its dice and what it does are written down the first time a fight opens on it.", 14, DeepUi.MUTED)
	var where := DeepUi.vbox(right, 6)
	DeepUi.section(where, "map", "Where to look", DeepUi.ACCENT, 13)
	var said: Array = []
	for haunt in DeepBestiary.haunts(key):
		var line: String = ""
		match str(haunt.kind):
			"band", "warden", "boss", "remembered", "unmade":
				line = "Somewhere in %s" % DeepContent.mine_name(str(haunt.mine))
			"escort":
				line = "Beside %s" % _name_of(home.profile, str(haunt.of))
			"summoned":
				line = "Called in by %s" % _name_of(home.profile, str(haunt.by))
		if not line.is_empty() and not said.has(line):
			said.append(line)
			DeepUi.stat(where, "pick", line, DeepUi.PAPER, 13)

static func _name_of(profile: Dictionary, key: String) -> String:
	## Another creature, by name once the player has met it.
	if not DeepBestiary.known(profile, key):
		return "a creature you have not met"
	return str(DeepContent.creature(key).get("name", key))

static func _leaves(home: Control, box: Control, key: String, def: Dictionary, record: Dictionary) -> void:
	## What is said about it, in pages under tabs: the field notes (where it lives and the
	## player's record against it), its moves four at a time, and each phase's.
	var leaves: Array = [ {"name": "Field notes", "glyph": "map", "draw": func(page: Control) -> void: _notes(home.profile, page, key, record)}]
	var traits: Dictionary = DeepCreatures.traits_for({"key": key, "hp": 1, "max_hp": 1})
	var moves: Array = def.get("moves", [])
	for chunk in range(maxi(1, ceili(float(moves.size()) / float(MOVES_PAGE)))):
		var part: Array = moves.slice(chunk * MOVES_PAGE, (chunk + 1) * MOVES_PAGE)
		var first: bool = chunk == 0
		leaves.append({"name": "Moves" if first else str(chunk + 1), "tip": "Moves · %d" % (chunk + 1), "glyph": "book", "draw": func(page: Control) -> void:
			_moves(page, part, traits if first else {})})
	for phase in def.get("phases", []):
		var below: int = int(phase.get("below_hp_pct", 0))
		var shown: Array = phase.get("moves", [])
		for chunk in range(maxi(1, ceili(float(shown.size()) / float(MOVES_PAGE)))):
			var part: Array = shown.slice(chunk * MOVES_PAGE, (chunk + 1) * MOVES_PAGE)
			var first: bool = chunk == 0
			leaves.append({"name": "Below %d%%" % below if first else str(chunk + 1), "tip": "Below %d%%" % below + ("" if first else " · %d" % (chunk + 1)), "glyph": "crown", "draw": func(page: Control) -> void:
				_phase(page, phase if first else {}, below, part)})
	var at: int = clampi(int(home._bestiary_leaf), 0, leaves.size() - 1)
	var tabs := DeepUi.hbox(box, 6)
	tabs.name = "BestiaryLeaves"
	for index in range(leaves.size()):
		var to: int = index
		## A page that runs on from the one before it is just its number under the same mark,
		## so a creature with many phases keeps its tabs on one row.
		var tab := DeepUi.tab_button(tabs, str(leaves[index].glyph), str(leaves[index].name), index == at, func() -> void:
			home._bestiary_leaf = to
			if not home.redraw(["bestiary_leaf"]):
				home._render(), 13)
		tab.tooltip_text = str(leaves[index].get("tip", ""))
	var page := DeepUi.vbox(box, 12)
	leaves[at].draw.call(page)

static func _notes(profile: Dictionary, page: Control, key: String, record: Dictionary) -> void:
	var tally := DeepUi.vbox(page, 8)
	DeepUi.section(tally, "star", "Your record", DeepUi.ACCENT, 13)
	var row := DeepUi.hbox(tally, 22)
	for entry in [["eye", str(int(record.get("met", 0))), "met", "How many of it you have come up against."],
			["sword", str(int(record.get("slain", 0))), "slain", "How many of it fell in fights you were in."],
			["skull", str(int(record.get("lost", 0))), "fights lost", "Fights you lost with it still standing."],
			["calendar", str(record.get("first", "")), "first met", ""]]:
		var cell := DeepUi.vbox(row, 0)
		cell.tooltip_text = str(entry[3])
		cell.mouse_filter = Control.MOUSE_FILTER_STOP if not str(entry[3]).is_empty() else Control.MOUSE_FILTER_IGNORE
		var value := DeepUi.hbox(cell, 6)
		DeepUi.icon(value, str(entry[0]), 18, DeepUi.ACCENT)
		DeepUi.title(value, str(entry[1]) if not str(entry[1]).is_empty() else "–", 22 if str(entry[0]) != "calendar" else 18, DeepUi.PAPER)
		DeepUi.label(cell, str(entry[2]), 12, DeepUi.DIM)
	var met_in: Array = []
	var mines: Dictionary = record.get("mines", {})
	for mine in DeepContent.mines_in_order():
		if mines.has(str(mine)):
			met_in.append("%s (to depth %d)" % [DeepContent.mine_name(str(mine)), int(mines[str(mine)])])
	if not met_in.is_empty():
		DeepUi.wrap(tally, "Met in " + ", ".join(met_in) + ".", 13, DeepUi.MUTED)
	var lives := DeepUi.vbox(page, 6)
	DeepUi.section(lives, "map", "Where it lives", DeepUi.ACCENT, 13)
	## A mine's bands said as one line, however many stretches of it the creature is drawn in.
	var haunts: Array = []
	for haunt in DeepBestiary.haunts(key):
		var last: Dictionary = haunts.back() if not haunts.is_empty() else {}
		if str(haunt.kind) == "band" and str(last.get("kind", "")) == "band" and str(last.get("mine", "")) == str(haunt.mine):
			last.spans.append(haunt)
		elif str(haunt.kind) == "band":
			haunts.append({"kind": "band", "mine": str(haunt.mine), "spans": [haunt]})
		else:
			haunts.append(haunt)
	for haunt in haunts:
		var line: Array = _haunt_words(profile, haunt)
		Inspector.wrap_stat(DeepUi.stat(lives, str(line[0]), str(line[1]), DeepUi.PAPER, 13))

static func _haunt_words(profile: Dictionary, haunt: Dictionary) -> Array:
	## [glyph, words] for one place it is found.
	var mine: String = DeepContent.mine_name(str(haunt.get("mine", "")))
	match str(haunt.kind):
		"band":
			var stretches: Array = []
			for span in haunt.get("spans", [haunt]):
				var from: int = int(span.from)
				var to: int = int(span.to)
				if to <= 0:
					stretches.append("every floor" if from <= 1 else "depth %d on down" % from)
				else:
					stretches.append("depths %d–%d" % [from, to])
			return ["pick", "%s · %s" % [mine, " and ".join(stretches)]]
		"warden":
			return ["crown", "%s · Warden of the landing near depth %d" % [mine, int(haunt.depth)]]
		"boss":
			return ["crown", "%s · final boss, on the bottom floor (depth %d)" % [mine, int(haunt.depth)]]
		"remembered":
			return ["crown", "%s · comes back as one of its Wardens, with a trait more" % mine]
		"unmade":
			return ["crown", "%s · every %dth floor, in place of a Warden" % [mine, int(haunt.every)]]
		"escort":
			return ["copy", "Walks in beside %s" % _name_of(profile, str(haunt.of))]
		"summoned":
			return ["copy", "Called into fights by %s" % _name_of(profile, str(haunt.by))]
		"echo":
			var names: Array = haunt.get("mines", []).map(func(k: Variant) -> String: return DeepContent.mine_name(str(k)))
			return ["ghost", "Takes the shape of a creature from %s" % (", ".join(names.slice(0, -1)) + " or " + str(names.back()) if names.size() > 1 else ", ".join(names))]
	return ["spark", str(haunt.kind)]

static func _moves(page: Control, moves: Array, traits: Dictionary) -> void:
	var list := DeepUi.vbox(page, 6)
	for move in moves:
		Inspector.move_row(list, move, false, true)
	if traits.is_empty():
		return
	var born := DeepUi.vbox(page, 6)
	DeepUi.section(born, "spark", "What it is", DeepUi.ACCENT, 13)
	var trait_keys: Array = traits.keys()
	trait_keys.sort()
	for trait_key in trait_keys:
		var chip: Dictionary = EffectChips.trait_entry(str(trait_key), traits[trait_key])
		Inspector.wrap_stat(DeepUi.stat(born, str(chip.glyph), "%s: %s" % [str(chip.title), str(chip.text)], Color("c8a8ff"), 12))

static func _phase(page: Control, phase: Dictionary, below: int, moves: Array) -> void:
	var list := DeepUi.vbox(page, 6)
	if not phase.is_empty():
		DeepUi.stat(list, "crown", "Below %d%% health it fights with:" % below, DeepUi.BAD, 13)
		for trait_key in phase.get("traits", {}):
			var value: Variant = phase.traits[trait_key]
			if (value is bool and not value) or ((value is int or value is float) and float(value) <= 0.0):
				DeepUi.stat(list, "cross_out", "Loses %s." % str(trait_key).capitalize(), DeepUi.DIM, 12)
			else:
				var chip: Dictionary = EffectChips.trait_entry(str(trait_key), value)
				Inspector.wrap_stat(DeepUi.stat(list, str(chip.glyph), "%s: %s" % [str(chip.title), str(chip.text)], Color("c8a8ff"), 12))
	for move in moves:
		Inspector.move_row(list, move, false, true)
